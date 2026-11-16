// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2, Vm} from "forge-std/Test.sol";
import {StdPrecompiles} from "base-std/StdPrecompiles.sol";
import {IB20Factory} from "base-std/interfaces/IB20Factory.sol";
import {IB20Asset} from "base-std/interfaces/IB20Asset.sol";
import {B20FactoryLib} from "base-std/lib/B20FactoryLib.sol";

/// Stand-in for the future PangoVault: reads corporate-action state of a B20 asset from another contract.
contract PendingProbe {
    function pending(IB20Asset t) external view returns (bool isPending, uint256 effectiveAt, uint256 newMultiplier) {
        effectiveAt = t.effectiveAt();
        newMultiplier = t.newUIMultiplier();
        // effectiveAt() keeps its past value after the update matures, so never test `!= 0`.
        isPending = effectiveAt > block.timestamp;
    }

    function shares(IB20Asset t) external view returns (uint256) {
        return t.balanceOfUI(address(this));
    }
}

/// Spike S1: create our own B20 asset, schedule a 10x split, read it from a contract.
contract S1Test is Test {
    // Feature id copied from base-std test/lib/mocks/ActivationRegistryFeatureList.sol
    bytes32 constant B20_ASSET_FEATURE = 0xcdcc772fe4cbdb1029f822861176d09e646db96723d4c1e82ddfdeb8163ef54c;

    IB20Asset t;
    PendingProbe probe;

    function setUp() public {
        // Fail loudly if we are not on the real Rust precompiles (a green run on nothing proves nothing).
        assertTrue(
            StdPrecompiles.ACTIVATION_REGISTRY.isActivated(B20_ASSET_FEATURE), "B20 asset feature not active"
        );

        bytes[] memory roles = B20FactoryLib.buildRoleGrants(
            B20FactoryLib.B20AssetRoleHolders({
                minter: address(this),
                burner: address(0),
                burnBlocker: address(0),
                pauser: address(0),
                unpauser: address(0),
                metadataAdmin: address(0),
                operator: address(this)
            })
        );
        address token = StdPrecompiles.B20_FACTORY.createB20(
            IB20Factory.B20Variant.ASSET,
            keccak256("pango-s1-tNVDA"),
            B20FactoryLib.encodeAssetCreateParams("Test NVDA", "tNVDA", address(this), 18),
            roles
        );
        assertTrue(StdPrecompiles.B20_FACTORY.isB20Initialized(token), "token not initialized");
        t = IB20Asset(token);
        probe = new PendingProbe();
    }

    function test_pendingSplitReadableFromContract() public {
        assertEq(t.uiMultiplier(), 1e18, "starts at 1x");
        t.mint(address(probe), 1e18); // 1 share

        uint256 eff = block.timestamp + 30 minutes;
        t.updateUIMultiplier(10e18, eff); // schedule a 10x split

        (bool p, uint256 e, uint256 m) = probe.pending(t);
        assertTrue(p, "pending before effectiveAt");
        assertEq(e, eff);
        assertEq(m, 10e18);
        assertEq(t.uiMultiplier(), 1e18, "still 1x before effectiveAt");
        assertEq(probe.shares(t), 1e18);

        uint256 g = gasleft();
        probe.pending(t);
        console2.log("gas: probe.pending()", g - gasleft());

        vm.warp(eff);
        (p, e,) = probe.pending(t);
        assertFalse(p, "not pending once effective");
        assertEq(e, eff, "effectiveAt keeps its past value");
        assertEq(t.uiMultiplier(), 10e18, "10x after effectiveAt");
        assertEq(probe.shares(t), 10e18, "shares x10");
        assertEq(t.balanceOf(address(probe)), 1e18, "raw balance unchanged");
    }

    function test_announcementIsAtomic() public {
        bytes[] memory calls = new bytes[](1);
        calls[0] = B20FactoryLib.encodeUpdateUIMultiplier(2e18, block.timestamp + 1 hours);

        vm.recordLogs();
        t.announce(calls, "split-2026-001", "2-for-1 split", "https://example.com/split");
        Vm.Log[] memory logs = vm.getRecordedLogs();

        bool opened;
        bool closed;
        for (uint256 i; i < logs.length; i++) {
            if (logs[i].topics[0] == IB20Asset.Announcement.selector) opened = true;
            if (logs[i].topics[0] == IB20Asset.EndAnnouncement.selector) closed = true;
        }
        assertTrue(opened && closed, "Announcement and EndAnnouncement in the same tx");
        assertTrue(t.isAnnouncementIdUsed("split-2026-001"));
        (bool p,,) = probe.pending(t);
        assertTrue(p, "the split scheduled inside the announcement is what stays readable");
    }
}
