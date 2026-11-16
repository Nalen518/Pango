// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {IB20Asset} from "base-std/interfaces/IB20Asset.sol";
import {B20Constants} from "base-std/lib/B20Constants.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";
import {WeightMath, MockUSDC, MockFeed, MockSwap, MiniVault} from "./S5Lib.sol";

/// Spike S5: weight math across USDC (6), feeds (8) and B20 UI units (token decimals), checked by
/// check_weights.py against exact rationals; plus gas of a buy that runs the target check.
contract S5Test is Test {
    bytes32 constant B20_ASSET_FEATURE = 0xcdcc772fe4cbdb1029f822861176d09e646db96723d4c1e82ddfdeb8163ef54c;
    uint256 constant SEED = 0x5EED5;
    string constant CSV = "s5-weight-math/states.csv";

    IB20Asset tA; // 18 decimals
    IB20Asset tB; // 18 decimals
    IB20Asset tC; // 6 decimals

    function setUp() public {
        assertTrue(StdPrecompiles.ACTIVATION_REGISTRY.isActivated(B20_ASSET_FEATURE), "not on live precompiles");
        tA = _create("tNVDA", 18);
        tB = _create("tAAPL", 18);
        tC = _create("tSIX", 6);
    }

    function _create(string memory sym, uint8 dec) internal returns (IB20Asset) {
        bytes[] memory init = new bytes[](2);
        init[0] = B20FactoryLib.encodeGrantRole(B20Constants.MINT_ROLE, address(this));
        init[1] = B20FactoryLib.encodeGrantRole(B20Constants.OPERATOR_ROLE, address(this));
        return IB20Asset(
            StdPrecompiles.B20_FACTORY.createB20(
                IB20Factory.B20Variant.ASSET,
                keccak256(bytes(sym)),
                B20FactoryLib.encodeAssetCreateParams(sym, sym, address(this), dec),
                init
            )
        );
    }

    function _rand(uint256 i, uint256 k, uint256 lo, uint256 hi) internal pure returns (uint256) {
        return lo + uint256(keccak256(abi.encode(SEED, i, k))) % (hi - lo + 1);
    }

    function _multiplier(uint256 i, uint256 k) internal pure returns (uint256) {
        uint256 pick = _rand(i, k, 0, 4);
        if (pick == 0) return 1e18;
        if (pick == 1) return 10e18; // 10-for-1 split
        if (pick == 2) return 1.0123e18; // dividend-style adjustment
        if (pick == 3) return 0.5e18; // 1-for-2 reverse split
        return _rand(i, k + 100, 0.5e18, 20e18);
    }

    struct State {
        uint256 i;
        IB20Asset s1;
        IB20Asset s2;
        uint256 raw1;
        uint256 raw2;
        uint256 m1;
        uint256 m2;
        uint256 p1;
        uint256 p2;
        uint256 usdc6;
    }

    /// Writes one CSV row: holds raw amounts, sets multipliers, reads balanceOfUI from the real B20,
    /// then computes values and weights with WeightMath.
    function _row(State memory st) internal {
        address holder = address(uint160(0x10000 + st.i));
        if (st.raw1 > 0) st.s1.mint(holder, st.raw1);
        if (st.raw2 > 0) st.s2.mint(holder, st.raw2);
        st.s1.updateMultiplier(st.m1);
        st.s2.updateMultiplier(st.m2);
        uint256 ui1 = st.s1.balanceOfUI(holder);
        uint256 ui2 = st.s2.balanceOfUI(holder);
        uint256[3] memory v = [
            WeightMath.stockValue18(ui1, st.s1.decimals(), st.p1),
            WeightMath.stockValue18(ui2, st.s2.decimals(), st.p2),
            WeightMath.usdcValue18(st.usdc6)
        ];
        uint256 total = v[0] + v[1] + v[2];
        string memory line = string.concat(
            vm.toString(st.i), ",", vm.toString(st.s1.decimals()), ",", vm.toString(st.raw1), ",", vm.toString(st.m1)
        );
        line = string.concat(line, ",", vm.toString(ui1), ",", vm.toString(st.p1), ",", vm.toString(st.s2.decimals()));
        line = string.concat(line, ",", vm.toString(st.raw2), ",", vm.toString(st.m2), ",", vm.toString(ui2));
        line = string.concat(line, ",", vm.toString(st.p2), ",", vm.toString(st.usdc6));
        for (uint256 k; k < 3; k++) {
            line = string.concat(line, ",", vm.toString(WeightMath.weightBps(v[k], total)));
        }
        vm.writeLine(CSV, string.concat(line, ",", vm.toString(total)));
    }

    function test_writeStates() public {
        if (vm.exists(CSV)) vm.removeFile(CSV);
        vm.writeLine(CSV, "i,dec1,raw1,mult1,ui1,price1,dec2,raw2,mult2,ui2,price2,usdc6,w1,w2,wu,total18");
        for (uint256 i; i < 50; i++) {
            IB20Asset s2 = i % 5 == 0 ? tC : tB; // every 5th state uses the 6-decimal token
            uint256 raw1 = _rand(i, 1, 0, 1_000_000) * 10 ** 18 + _rand(i, 2, 0, 1e18 - 1);
            uint256 raw2 = _rand(i, 3, 0, 1_000_000) * 10 ** s2.decimals() + _rand(i, 4, 0, 10 ** s2.decimals() - 1);
            _row(State(i, tA, s2, raw1, raw2, _multiplier(i, 5), _multiplier(i, 6), _rand(i, 7, 1e8, 5000e8),
                _rand(i, 8, 1e8, 5000e8), _rand(i, 9, 0, 1e9 * 1e6)));
        }
        // Edge cases
        _row(State(50, tA, tB, 0, 0, 1e18, 1e18, 100e8, 200e8, 500e6)); // all USDC
        _row(State(51, tA, tB, 0, 0, 1e18, 1e18, 100e8, 200e8, 0)); // empty portfolio → weights 0, no revert
        _row(State(52, tA, tB, 5e18, 0, 1e18, 1e18, 150e8, 200e8, 0)); // one stock only → 100%
        _row(State(53, tA, tB, 1, 1, 0.5e18, 1.0123e18, 1e8, 1e8, 1)); // dust
        // huge balances: overflow headroom
        _row(State(54, tA, tB, 1e12 * 1e18, 1e12 * 1e18, 20e18, 20e18, 100_000e8, 100_000e8, 1e15 * 1e6));
    }

    /// A 10x split with the feed ÷10 must leave every weight unchanged (AT-05, AT-17 rely on this).
    function test_splitInvariance() public {
        address holder = address(0xBEEF);
        tA.mint(holder, 3e18);
        tB.mint(holder, 2e18);
        uint256 pA = 180e8;
        uint256 pB = 230e8;
        uint256 usdc6 = 400e6;
        (uint256 wA0, uint256 wB0) = _weights(holder, pA, pB, usdc6);
        tA.updateUIMultiplier(10e18, block.timestamp + 1);
        vm.warp(block.timestamp + 1);
        (uint256 wA1, uint256 wB1) = _weights(holder, pA / 10, pB, usdc6);
        console2.log("weights before split (bps):", wA0, wB0);
        console2.log("weights after split  (bps):", wA1, wB1);
        assertEq(tA.balanceOfUI(holder), 30e18, "shares x10");
        assertEq(wA1, wA0, "tNVDA weight unchanged");
        assertEq(wB1, wB0, "tAAPL weight unchanged");
    }

    function _weights(address h, uint256 pA, uint256 pB, uint256 usdc6) internal view returns (uint256, uint256) {
        uint256 vA = WeightMath.stockValue18(tA.balanceOfUI(h), 18, pA);
        uint256 vB = WeightMath.stockValue18(tB.balanceOfUI(h), 18, pB);
        uint256 total = vA + vB + WeightMath.usdcValue18(usdc6);
        return (WeightMath.weightBps(vA, total), WeightMath.weightBps(vB, total));
    }

    // ---------------- gas ----------------

    MockUSDC usdc;
    MockSwap swap;
    MiniVault vault;
    MockFeed fA;
    MockFeed fB;

    function _deployVault() internal {
        usdc = new MockUSDC();
        swap = new MockSwap(usdc);
        vault = new MiniVault(usdc, swap);
        fA = new MockFeed();
        fB = new MockFeed();
        fA.set(180e8, block.timestamp);
        fB.set(230e8, block.timestamp);
        swap.setPrice(address(tA), 180e8);
        swap.setPrice(address(tB), 230e8);
        tA.mint(address(swap), 1_000e18);
        tB.mint(address(swap), 1_000e18);
        vault.addStock(address(tA), fA, 4000, 5e18);
        vault.addStock(address(tB), fB, 4000, 5e18);
        usdc.mint(address(vault), 500e6);
        vault.setResearchHash(keccak256("research report v1")); // target check runs, not skipped
    }

    /// Run with --isolate so the buy is costed as its own transaction (cold storage).
    function test_gas_buyWithTargetCheck() public {
        _deployVault();
        uint256 g = gasleft();
        vault.buy(address(tA), 20e6);
        uint256 used = g - gasleft();
        console2.log("gas: buy 20 USDC tNVDA, all checks incl. target:", used);
        console2.log("weight after (bps):", vault.weightOf(address(tA)));
        assertLt(used, 300_000, "buy under 300k gas");
    }

    function test_gas_revertAboveFairValue() public {
        _deployVault();
        swap.setPremium(400); // +4% weekend premium
        uint256 g = gasleft();
        (bool ok, bytes memory ret) = address(vault).call(abi.encodeCall(MiniVault.buy, (address(tA), 20e6)));
        uint256 used = g - gasleft();
        assertFalse(ok);
        assertEq(bytes4(ret), MiniVault.AboveFairValue.selector);
        console2.log("gas: buy reverting AboveFairValue after the swap:", used);
    }
}
