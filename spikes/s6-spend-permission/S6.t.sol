// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Spike S6 (Base Sepolia fork, nothing broadcast): can a PangoGuard-style contract pull USDC and a B20 stock
// out of a user's Coinbase Smart Wallet through Coinbase's SpendPermissionManager, check the caller is that
// account's agent, and hand the tokens straight back to the user?

import {Test, console2} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {IB20Asset} from "base-std/interfaces/IB20Asset.sol";
import {B20Constants} from "base-std/lib/B20Constants.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";
import {MockUSDC} from "../s5-weight-math/S5Lib.sol";

/// Minimal interface copied from coinbase/spend-permissions src/SpendPermissionManager.sol (commit e0004e6).
interface ISpendPermissionManager {
    struct SpendPermission {
        address account;
        address spender;
        address token;
        uint160 allowance;
        uint48 period;
        uint48 start;
        uint48 end;
        uint256 salt;
        bytes extraData;
    }

    error InvalidSender(address sender, address expected);
    error UnauthorizedSpendPermission();
    error ExceededSpendPermission(uint256 value, uint256 allowance);

    function approve(SpendPermission calldata spendPermission) external returns (bool);
    function revoke(SpendPermission calldata spendPermission) external;
    function spend(SpendPermission memory spendPermission, uint160 value) external;
    function isValid(SpendPermission memory spendPermission) external view returns (bool);
}

/// createAccount(bytes[],uint256) as used in the spend-permissions tests; factory verified on Sepolia.
interface ISmartWalletFactory {
    function createAccount(bytes[] calldata owners, uint256 nonce) external payable returns (address);
}

/// Stand-in for PangoGuard: one guard for many accounts; each account names its own agent.
contract GuardProbe {
    ISpendPermissionManager public immutable spm;
    mapping(address account => address agent) public agentOf;

    error NotAgentOf(address caller, address account);
    error WrongSpender(address spender);

    constructor(ISpendPermissionManager s) {
        spm = s;
    }

    function setAgent(address agent) external {
        agentOf[msg.sender] = agent; // called by the user's smart wallet
    }

    /// Pull `value` of the permission's token into the guard, then return it to the account
    /// (stands in for "swap, then deliver the output to the user").
    function pullAndReturn(ISpendPermissionManager.SpendPermission calldata p, uint160 value) external {
        if (msg.sender != agentOf[p.account]) revert NotAgentOf(msg.sender, p.account);
        if (p.spender != address(this)) revert WrongSpender(p.spender);
        uint256 before = IERC20(p.token).balanceOf(address(this));
        spm.spend(p, value);
        require(IERC20(p.token).balanceOf(address(this)) - before == value, "guard did not receive");
        IERC20(p.token).transfer(p.account, value);
    }
}

contract S6Test is Test {
    ISpendPermissionManager constant SPM = ISpendPermissionManager(0xf85210B21cC50302F477BA56686d2019dC9b67Ad);
    ISmartWalletFactory constant WALLET_FACTORY = ISmartWalletFactory(0x0BA5ED0c6AA8c49038F819E587E2633c4A9F428a);

    address user = makeAddr("user"); // the wallet's human owner key
    address agent = makeAddr("agent");
    address otherAgent = makeAddr("otherAgent");
    address wallet;
    GuardProbe guard;
    MockUSDC usdc;
    IB20Asset stock;

    function setUp() public {
        vm.createSelectFork(vm.envOr("BASE_SEPOLIA_RPC_URL", string("https://sepolia.base.org")));
        assertEq(block.chainid, 84532, "Base Sepolia fork only");
        assertGt(address(SPM).code.length, 0, "SpendPermissionManager missing");

        bytes[] memory owners = new bytes[](2);
        owners[0] = abi.encode(user);
        owners[1] = abi.encode(address(SPM)); // the manager must be a wallet owner to move funds
        wallet = WALLET_FACTORY.createAccount(owners, uint256(keccak256("pango-s6")));

        guard = new GuardProbe(SPM);
        usdc = new MockUSDC();
        usdc.mint(wallet, 500e6);

        bytes[] memory init = new bytes[](1);
        init[0] = B20FactoryLib.encodeGrantRole(B20Constants.MINT_ROLE, address(this));
        stock = IB20Asset(
            StdPrecompiles.B20_FACTORY.createB20(
                IB20Factory.B20Variant.ASSET,
                keccak256(abi.encode("pango-s6-tNVDA", block.number)),
                B20FactoryLib.encodeAssetCreateParams("Pango Test NVDA", "tNVDA", address(this), 18),
                init
            )
        );
        stock.mint(wallet, 2e18);

        vm.prank(wallet);
        guard.setAgent(agent);
    }

    function _perm(address token, uint160 allowance) internal view returns (ISpendPermissionManager.SpendPermission memory) {
        return ISpendPermissionManager.SpendPermission({
            account: wallet,
            spender: address(guard),
            token: token,
            allowance: allowance,
            period: 1 days,
            start: uint48(block.timestamp),
            end: type(uint48).max,
            salt: 0,
            extraData: ""
        });
    }

    function _approve(ISpendPermissionManager.SpendPermission memory p) internal {
        vm.prank(wallet); // the user approving from their wallet (the SDK does this via a signature)
        assertTrue(SPM.approve(p));
    }

    /// Buy path: USDC leaves the user's wallet only through the guard, then comes back.
    function test_buyPath_usdc() public {
        ISpendPermissionManager.SpendPermission memory p = _perm(address(usdc), 100e6);
        _approve(p);
        uint256 g = gasleft();
        vm.prank(agent);
        guard.pullAndReturn(p, 20e6);
        console2.log("gas: spend 20 USDC via permission + return:", g - gasleft());
        assertEq(usdc.balanceOf(wallet), 500e6, "funds back in the user's wallet");
        assertEq(usdc.balanceOf(address(guard)), 0, "guard holds nothing");
    }

    /// Sell path: a B20 stock moves through the permission (manager is the transferFrom executor).
    function test_sellPath_b20Stock() public {
        ISpendPermissionManager.SpendPermission memory p = _perm(address(stock), 1e18);
        _approve(p);
        vm.prank(agent);
        guard.pullAndReturn(p, 0.5e18);
        assertEq(stock.balanceOf(wallet), 2e18);
        assertEq(stock.balanceOf(address(guard)), 0);
    }

    /// The per-period allowance is an outer ceiling enforced by Coinbase's contract.
    function test_allowanceCeiling() public {
        ISpendPermissionManager.SpendPermission memory p = _perm(address(usdc), 100e6);
        _approve(p);
        vm.startPrank(agent);
        guard.pullAndReturn(p, 60e6);
        vm.expectRevert(abi.encodeWithSelector(ISpendPermissionManager.ExceededSpendPermission.selector, 110e6, 100e6));
        guard.pullAndReturn(p, 50e6);
        vm.stopPrank();
        vm.warp(block.timestamp + 1 days); // new period
        vm.prank(agent);
        guard.pullAndReturn(p, 50e6);
    }

    /// Another account's agent (or anyone) cannot use this user's permission through the guard,
    /// and nobody but the guard can call the manager with it.
    function test_onlyThisAccountsAgent() public {
        ISpendPermissionManager.SpendPermission memory p = _perm(address(usdc), 100e6);
        _approve(p);
        vm.prank(otherAgent);
        vm.expectRevert(abi.encodeWithSelector(GuardProbe.NotAgentOf.selector, otherAgent, wallet));
        guard.pullAndReturn(p, 1e6);

        vm.prank(agent);
        vm.expectRevert(abi.encodeWithSelector(ISpendPermissionManager.InvalidSender.selector, agent, address(guard)));
        SPM.spend(p, 1e6);
    }

    /// The user revokes from their wallet; the agent is cut off immediately.
    function test_revokeCutsOff() public {
        ISpendPermissionManager.SpendPermission memory p = _perm(address(usdc), 100e6);
        _approve(p);
        vm.prank(wallet);
        SPM.revoke(p);
        assertFalse(SPM.isValid(p));
        vm.prank(agent);
        vm.expectRevert(ISpendPermissionManager.UnauthorizedSpendPermission.selector);
        guard.pullAndReturn(p, 1e6);
    }
}
