// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";
import {IB20} from "base-std/interfaces/IB20.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {IPolicyRegistry} from "base-std/interfaces/IPolicyRegistry.sol";
import {B20Constants} from "base-std/lib/B20Constants.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";

/// Stand-in for PangoVault: pulls stock in with transferFrom, holds it, sends it out with transfer.
contract VaultProbe {
    function pull(IB20 t, address from, uint256 amount) external {
        t.transferFrom(from, address(this), amount);
    }

    function send(IB20 t, address to, uint256 amount) external {
        t.transfer(to, amount);
    }
}

/// Spike S2: can a freshly deployed contract receive, hold and send our B20 test stock under transfer policies?
contract S2Test is Test {
    bytes32 constant B20_ASSET_FEATURE = 0xcdcc772fe4cbdb1029f822861176d09e646db96723d4c1e82ddfdeb8163ef54c;
    IPolicyRegistry constant REG = StdPrecompiles.POLICY_REGISTRY;

    IB20 t;
    VaultProbe vault;
    address alice = makeAddr("alice"); // the owner
    address bob = makeAddr("bob");

    function setUp() public {
        assertTrue(StdPrecompiles.ACTIVATION_REGISTRY.isActivated(B20_ASSET_FEATURE), "not on live precompiles");

        bytes[] memory init = new bytes[](2);
        init[0] = B20FactoryLib.encodeGrantRole(B20Constants.MINT_ROLE, address(this));
        init[1] = B20FactoryLib.encodeGrantRole(B20Constants.SEIZE_ROLE, address(this));
        t = IB20(
            StdPrecompiles.B20_FACTORY.createB20(
                IB20Factory.B20Variant.ASSET,
                keccak256("pango-s2-tNVDA"),
                B20FactoryLib.encodeAssetCreateParams("Test NVDA", "tNVDA", address(this), 18),
                init
            )
        );
        vault = new VaultProbe();
        t.mint(alice, 10e18);
    }

    /// Our own test stock with default policies: the vault can pull, hold and send.
    function test_defaultPolicies_vaultHoldsAndMoves() public {
        bytes32[4] memory scopes = [
            B20Constants.TRANSFER_SENDER_POLICY,
            B20Constants.TRANSFER_RECEIVER_POLICY,
            B20Constants.TRANSFER_EXECUTOR_POLICY,
            B20Constants.MINT_RECEIVER_POLICY
        ];
        for (uint256 i; i < scopes.length; i++) {
            assertEq(t.policyId(scopes[i]), 0, "unset slot = 0 (always allow)");
        }
        console2.log("policyExists(0):", REG.policyExists(0));
        console2.log("isAuthorized(0, vault):", REG.isAuthorized(0, address(vault)));
        assertTrue(REG.isAuthorized(0, address(vault)));

        vm.prank(alice);
        t.approve(address(vault), 4e18);
        vault.pull(t, alice, 4e18); // owner deposits stock (vault is the executor)
        assertEq(t.balanceOf(address(vault)), 4e18);

        vault.send(t, bob, 1e18); // vault pays out (e.g. to a swap pool)
        assertEq(t.balanceOf(address(vault)), 3e18);
        assertEq(t.balanceOf(bob), 1e18);

        t.mint(address(vault), 1e18); // direct mint into a contract also works
        assertEq(t.balanceOf(address(vault)), 4e18);
    }

    /// A real-stock-style allowlist blocks the vault until the issuer adds it.
    function test_allowlist_blocksVaultUntilListed() public {
        address[] memory listed = new address[](2);
        listed[0] = alice;
        listed[1] = bob;
        uint64 id = REG.createPolicyWithAccounts(address(this), IPolicyRegistry.PolicyType.ALLOWLIST, listed);
        t.updatePolicy(B20Constants.TRANSFER_RECEIVER_POLICY, id);
        console2.log("allowlist policyExists:", REG.policyExists(id));
        console2.log("isAuthorized(id, vault) before:", REG.isAuthorized(id, address(vault)));
        assertFalse(REG.isAuthorized(id, address(vault)));

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(IB20.PolicyForbids.selector, B20Constants.TRANSFER_RECEIVER_POLICY, id));
        t.transfer(address(vault), 1e18);

        address[] memory add = new address[](1);
        add[0] = address(vault);
        REG.updateAllowlist(id, true, add);
        assertTrue(REG.isAuthorized(id, address(vault)));

        vm.prank(alice);
        t.transfer(address(vault), 1e18);
        assertEq(t.balanceOf(address(vault)), 1e18);
    }

    /// Default: SEIZE_EXEMPT_POLICY = 0 (always allow) exempts everyone, so even SEIZE_ROLE cannot seize.
    /// Once the issuer points SEIZE_EXEMPT_POLICY at a blocklist naming the vault, it can move stock out
    /// of the vault without the vault's consent.
    function test_issuerSeize_onlyAfterPolicyChange() public {
        t.mint(address(vault), 2e18);
        assertEq(t.policyId(B20Constants.SEIZE_EXEMPT_POLICY), 0);

        vm.expectRevert(abi.encodeWithSelector(IB20.AccountNotSeizable.selector, address(vault)));
        t.seizeWithMemo(address(vault), bob, 2e18, bytes32("compliance"));

        address[] memory blocked = new address[](1);
        blocked[0] = address(vault);
        uint64 id = REG.createPolicyWithAccounts(address(this), IPolicyRegistry.PolicyType.BLOCKLIST, blocked);
        t.updatePolicy(B20Constants.SEIZE_EXEMPT_POLICY, id);

        t.seizeWithMemo(address(vault), bob, 2e18, bytes32("compliance"));
        assertEq(t.balanceOf(address(vault)), 0, "issuer seize bypasses vault rules");
        assertEq(t.balanceOf(bob), 2e18);
    }
}
