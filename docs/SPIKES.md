# Phase 0 spike report

| Spike | Verdict | One line |
| --- | --- | --- |
| S1 B20 multiplier | PASS (local) · Sepolia tx hashes pending | Pending split is readable from a contract; Sepolia supports it |
| S2 Vault holds B20 | not started | |
| S3 Fair-value units | not started | |
| S4 Revert decode | not started | |
| S5 Weight math | not started | |

## S1 — B20 asset token, scheduled split, read from a contract

**Verdict:** PASS on base-anvil (live Rust precompiles). Sepolia supports every call used (verified by `eth_call`); the two broadcast tx hashes the brief asks for still need a funded deployer.

**What we did**

- `spikes/s1-b20-multiplier/S1.t.sol`, run with `cd spikes && base-forge test -vv` (2/2 pass).
- `setUp` asserts the `B20_ASSET` feature is active and the token is initialized, so a run on mocks cannot pass silently.
- Created `tNVDA` (18 decimals) via the factory with our test contract as admin, minter and operator; minted 1 share to `PendingProbe` (a stand-in for the vault); scheduled a 10x split 30 min ahead; warped past it.

**Exact interfaces used** (from `base/base-std` v1.1.0, Cobalt)

| Purpose | Call |
| --- | --- |
| Create token | `IB20Factory.createB20(B20Variant.ASSET, salt, B20FactoryLib.encodeAssetCreateParams(name, symbol, admin, 18), initCalls)` at `0xB20f000000000000000000000000000000000000` |
| Roles at creation | `B20FactoryLib.buildRoleGrants(B20AssetRoleHolders{minter, operator, ...})` as `initCalls` |
| Schedule split | `updateUIMultiplier(uint256 newMultiplier, uint256 effectiveAt)` — needs `OPERATOR_ROLE`; 10x = `10e18` |
| Read pending (for the vault) | `effectiveAt()`, `newUIMultiplier()`; **pending ⇔ `effectiveAt() > block.timestamp`** |
| Shares / raw | `balanceOfUI(account)`, `balanceOf(account)`, `uiMultiplier()` |
| Feature gate | `IActivationRegistry.isActivated(bytes32)` at `0x8453…0001`; `B20_ASSET` id `0xcdcc772f…f54c` |

**Measured**

- Before `effectiveAt`: pending = true, `uiMultiplier` = 1e18, shares = 1.0.
- At `effectiveAt`: pending = false, `uiMultiplier` = 10e18, shares = 10.0, raw balance unchanged (1e18).
- Gas to read pending state from another contract: **~4.0k**.
- Base Sepolia (chain 84532): `isActivated(B20_ASSET)` = true, `isActivated(POLICY_REGISTRY)` = true; `eth_call` of `createB20` with an `updateUIMultiplier(10e18, now+30min)` init call succeeds from an arbitrary address → **token creation is permissionless on Sepolia and Cobalt is live there**.

**Surprises**

1. **Toolchain:** base-anvil v1.1.0 (what `base-foundryup` installed by default) has no Cobalt functions; calls revert with the selector as the error. Fixed by `base-foundryup --install v1.5.1`. Pin this version.
2. **`effectiveAt()` keeps its old value** after a split matures. Checking `effectiveAt() != 0` would block trading forever after the first split.
3. **There is no "open announcement window".** `announce()` emits `Announcement` and `EndAnnouncement` in the same transaction; only `isAnnouncementIdUsed(id)` remains. The scheduled multiplier is the only corporate-action state a contract needs to read.
4. Base-std pins solc 0.8.30; we compile with 0.8.35. No issue so far (interfaces use `>=0.8.20 <0.9.0`).

**Recommended SRD changes**

- Section 5 *Known limit* — replace "a contract cannot read past events, so an open `Announcement` window is only enforced if B20 exposes it through a view function…" with: "B20 announcements are atomic (no open window exists); the vault enforces corporate actions through the scheduled multiplier: pending ⇔ `effectiveAt() > block.timestamp`."
- Section 10 open question "Does B20 expose an open `Announcement` window…" → answered: no window exists; not needed.
- Check step 5 and FR-V4: name the real calls — `effectiveAt()` / `newUIMultiplier()`, never `effectiveAt() != 0`.
- Section 7 runbook step 1 and the README: pin Base's Foundry build to **v1.5.1**.

**Still to do for S1 (deferred by choice, Nov 16):** broadcast token creation and the split schedule on Sepolia to record two tx hashes. Needs a funded deployer address; the `eth_call` simulation above already shows both calls succeed on Sepolia.
