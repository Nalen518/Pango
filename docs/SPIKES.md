# Phase 0 spike report

| Spike | Verdict | One line |
| --- | --- | --- |
| S1 B20 multiplier | PASS (local) · Sepolia tx hashes pending | Pending split is readable from a contract; Sepolia supports it |
| S2 Vault holds B20 | PASS (local) · Sepolia tx hashes deferred | A contract can pull, hold and send our test stock; allowlists and issuer seizure behave as documented |
| S3 Fair-value units | PARTIAL · rest deferred (API blocked, public RPC rate-limited) | Feeds read: 8 decimals, ~50 h weekend freeze; units and real-token checks need the Coinbase API |
| S4 Revert decode | PASS (local) · Sepolia tx hash deferred | web3.py decodes custom errors from eth_call and can broadcast the reverting tx |
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

**S1 Sepolia step deferred by choice (Nov 16):** broadcast token creation and the split schedule on Sepolia to record two tx hashes. Needs a funded deployer address; the `eth_call` simulation above already shows both calls succeed on Sepolia.

## S2 — Can the vault (a contract) receive, hold and send B20 stock?

**Verdict:** PASS on base-anvil (live Rust precompiles), 3/3 tests in `spikes/s2-vault-holds-b20/S2.t.sol`. Sepolia tx hashes deferred (same funded-deployer step as S1).

**What we did**

- `VaultProbe` contract (stand-in for PangoVault) with `pull` (`transferFrom` owner → vault, vault is the executor) and `send` (`transfer` vault → anyone).
- Test 1, default policies: owner approves, vault pulls 4 shares, sends 1 out, receives a direct mint.
- Test 2, real-stock-style allowlist: issuer sets `TRANSFER_RECEIVER_POLICY` to an allowlist without the vault → transfer to the vault reverts; issuer adds the vault → it works.
- Test 3, issuer seizure: `seizeWithMemo` from the vault.

**Exact interfaces used**

| Purpose | Call |
| --- | --- |
| Policy slot of a token | `IB20.policyId(bytes32 scope)`; scopes `TRANSFER_SENDER_POLICY`, `TRANSFER_RECEIVER_POLICY`, `TRANSFER_EXECUTOR_POLICY`, `MINT_RECEIVER_POLICY`, `SEIZE_EXEMPT_POLICY`, `SEIZE_RECEIVER_POLICY` (`keccak256` of the name, in `B20Constants`) |
| Set a slot (token admin) | `IB20.updatePolicy(bytes32 scope, uint64 policyId)` |
| Registry (`0x8453…0002`) | `policyExists(uint64)`, `isAuthorized(uint64, address)`, `createPolicyWithAccounts(admin, PolicyType, address[])`, `updateAllowlist(uint64, bool, address[])` |
| Blocked transfer error | `PolicyForbids(bytes32 policyScope, uint64 policyId)` |
| Issuer clawback | `seizeWithMemo(from, to, amount, memo)` — needs `SEIZE_ROLE`; error `AccountNotSeizable(account)` |

**Measured**

- Every unset slot reads `0` = built-in always-allow. `policyExists(0)` = true, `isAuthorized(0, vault)` = true.
- Allowlist without the vault: `isAuthorized(id, vault)` = false and `transfer` → `PolicyForbids(TRANSFER_RECEIVER_POLICY, id)`; after `updateAllowlist(id, true, [vault])` the transfer succeeds.
- `transferFrom` by the vault is checked against `TRANSFER_EXECUTOR_POLICY` (vault is `msg.sender`), `TRANSFER_SENDER_POLICY` (owner) and `TRANSFER_RECEIVER_POLICY` (vault). A real stock could block the vault at any of the three.

**Surprises**

1. **Seizure is off by default.** `SEIZE_EXEMPT_POLICY = 0` (always allow) makes every account exempt, so even a `SEIZE_ROLE` holder gets `AccountNotSeizable`. Only after the issuer points `SEIZE_EXEMPT_POLICY` at a blocklist naming the vault can it move stock out of the vault, without the vault's consent.
2. Policies are live: changing a slot takes effect on the next transfer, so an issuer can freeze a vault at any time (not just at deposit).

**Recommended SRD changes**

- Section 8 *Invariant* — "Funds leave the vault only to the owner or into a swap at fair value" → add "…except by the token issuer's `seizeWithMemo` or a policy freeze, which no holder contract can prevent; for our test stocks we hold that role and never use it." Keep the invariant test on our own tokens with default policies.
- NFR-8 "what is not real yet" panel — add: "Real tokenized stocks are subject to the issuer's transfer policies and clawback; the vault works only if Coinbase's policy authorizes its address (spike S3 checks this on mainnet)."
- FR-V6 / sell path — map `PolicyForbids(scope, id)` to a plain-English receipt line: "The stock's issuer does not allow this transfer right now."
- Runbook (section 7): no allowlist setup is needed for tNVDA/tAAPL; default policies let the vault and StockSwap hold them.

## S3 — Fair-value units, weekend staleness, real-stock policy, corporate actions (mainnet, read-only)

**Verdict:** PARTIAL. Feed half done; the half that needs `api.coinbase.com` is blocked on this network.

**Blocker:** the ISP (Telkomsel "Internet Baik" filter) resolves `api.coinbase.com` to `202.3.218.139` and serves a certificate for `internetbaik.telkomsel.com`. Every request to the Tokenized Stocks API fails TLS (PowerShell, WSL curl and the web-fetch agent alike). Base mainnet RPC (`mainnet.base.org`) and docs.base.org are reachable. Base's docs do not list the token addresses; only the API does.

**What we did** — `spikes/s3-fair-value-units/feeds.sh` (read-only `base-cast call`, no wallet) on Base mainnet, Mon Nov 16 2026 02:46 UTC.

| Feed (Base mainnet) | Address | Decimals | Latest answer | updatedAt (UTC) |
| --- | --- | --- | --- | --- |
| Coinbase NVDA | `0x04689a41629776563E6822F76f2e57D148d28513` | 8 | 163.79831928 | Mon Nov 16 02:40 |
| Coinbase AAPL | `0x787f13dEa48Db0897CbCDD985de77809D837F988` | 8 | 357.72827323 | Mon Nov 16 01:00 |

Feed addresses from https://docs.base.org/build-on-base/integrate-defi/list-tokenized-stocks. Interface: Chainlink `AggregatorV3Interface` (`description`, `decimals`, `latestRoundData`, `getRoundData`).

**Measured (last 40 rounds each)**

- **Weekend gap:** NVDA 49 h (Fri Nov 13 23:36 → Mon Nov 16 01:00 UTC); AAPL 51 h (Nov 13–16) and 53 h (Nov 6–9). Updates resume Monday ~01:00 UTC (Sunday 8 pm ET), so the feed follows 24/5 trading, not just regular hours.
- **Longest weekday gap:** AAPL ~20 h (Mon Nov 9 15:27 → Tue Nov 10 12:26 UTC). NVDA updates every few minutes in session.
- **Weekend reopen jump:** NVDA 160.77 → 164.86 (+2.5%) across the weekend — a real example of the gap the fair-value band guards.
- **Thresholds check:** `maxStaleness = 26 h` puts every weekend in stale mode and no normal weekday in it; `hardStaleLimit = 72 h` stays clear of a 53 h weekend but a US holiday weekend (e.g. Thanksgiving Thu Nov 26) could approach it — not measured.

**Units (open):** Base's docs say Coinbase feeds report "Total Return Values" and "Token Price = Underlying Equity Market Price × Multiplier". That implies the feed is the price **per raw token**, so value = `balanceOf` × feed, not `balanceOfUI` × feed (what the SRD says now). Confirming needs one real token's `uiMultiplier()` (≠ 1 after any dividend) — needs its address from the API.

**Onchain route (tried Nov 16, no API):**

- Feed aggregators are standard Chainlink OCR2 contracts: NVDA `0xF72B1eB5932800F3d2a5EeC5f99e6cD586479675`, AAPL `0xc37B6F754e90D4Cca1f533F5a08f7d532b3d0d9D`.
- Coinbase oracle registry `0x3f3E…5CaD` (1.5 kB, not a proxy) exposes `getOracleParams(address)`, `setOraclePaused(address,bool)`, `multiplier()`, `PAUSER_ROLE()` and AccessControl (names from the public 4byte database). `getOracleParams` reverts for both feed and aggregator addresses, so it is most likely keyed by the token address.
- Finding the token addresses from the factory's `B20Created` events (`topic0 0xfd9bf273…ba0d`) is possible, but the public `mainnet.base.org` RPC rate-limits `eth_getLogs` (`-32011 request limit reached`). Needs a provider RPC URL (Alchemy, CDP or similar) in `.env` as `BASE_MAINNET_RPC_URL`.

**Not done (needs the API, or a provider RPC for the onchain route):**

1. Real NVDA/AAPL token addresses on Base (`contract_address` in `GET /`), `multiplier`, `nav_price`, `nav_price_updated_at` → compare feed vs NAV vs a DEX quote within ~1%.
2. Policy check: `policyId(TRANSFER_RECEIVER_POLICY)` etc. on the real token, then `isAuthorized(id, <a plain contract address>)` on the policy registry.
3. Corporate-action lead times: `GET /corporate-actions/{id}`, and the token's `effectiveAt()` history.
4. Aerodrome pool address and quote (not in Base docs).

**Recommended SRD changes so far**

- Keep `maxStaleness = 26 h`; note the measured 49–53 h weekend gap next to `hardStaleLimit = 72 h` and add a holiday check to the runbook.
- Our `MockAggregatorV3` should copy real behaviour: 8 decimals, frequent updates in session, ~50 h weekend freeze, updates resuming Sunday 8 pm ET.
- Hold the units change (FR-V5, FR-V12: feed per UI share vs per raw token) until item 1 is answered. For the testnet demo this is our choice: our `MockAggregatorV3` reports USDC per UI share, as the SRD says, labelled in the UI.

**Deferred (Nov 16):** items 1–4 wait for a provider RPC URL in `.env` (`BASE_MAINNET_RPC_URL`) or a network where `api.coinbase.com` loads. Nothing in the testnet demo depends on them.

## S4 — Can the agent decode custom errors and broadcast a reverting tx?

**Verdict:** PASS on a local base-anvil node (chain 31337). Sepolia tx hash deferred (same funded-wallet step as S1/S2).

**What we did** — `spikes/s4-revert-decode/Reverter.sol` (reverts with `AboveFairValue(uint256,uint256)`, `CorporateActionPending(uint256)`, `EnforcedPause()`) and `s4.py`, run with the agent's environment: `uv run --project agent python spikes/s4-revert-decode/s4.py`. The script refuses any chain other than 31337 or 84532 and uses anvil's unlocked dev account (no private key).

1. Preflight: `contract.functions.buy(mode).call()` → web3.py 8 raises `ContractCustomError`; `e.data` is the raw revert data. A selector table built from the contract ABI (`keccak(name(types))[:4]`) plus `eth_abi.decode` gives the error name and arguments.
2. Broadcast anyway: `transact({"gas": 100_000})` — passing `gas` skips `estimate_gas`, which would otherwise refuse a reverting call. The node mines it with `status 0`.

**Measured**

| Mode | Preflight decoded | Broadcast | Gas used |
| --- | --- | --- | --- |
| 1 | `AboveFairValue(paidPrice=105e18, maxPrice=101e18)` | mined, status 0 | 22,145 |
| 2 | `CorporateActionPending(effectiveAt=1795000000)` | mined, status 0 | 21,940 |
| 3 | `EnforcedPause()` | mined, status 0 | 21,685 |
| 0 | — (success path) | mined, status 1 | — |

**Surprises / notes**

1. No custom decoding library is needed: the vault's ABI is the error table. The agent should load errors from the vault ABI **plus** errors that can bubble up from other contracts — OpenZeppelin v5 (`OwnableUnauthorizedAccount`, `EnforcedPause`) and B20 (`PolicyForbids`, `AccountNotSeizable`, …) — or bubbled reverts show as "unknown error".
2. A reverted tx costs about 22k gas here (cheap revert at the top); a real vault revert after the swap (`AboveFairValue` at step 7) will cost more. Budget agent gas for proof-mode reverts (NFR-12).
3. `estimate_gas` is what blocks broadcasting a failing tx; setting `gas` explicitly is enough. Proof mode must stay testnet-only (the script's chain-id guard is the pattern to copy).

**Recommended SRD changes**

- FR-A4: name the mechanism — "preflight with `eth_call`, decode the revert against an error table built from the vault ABI plus OpenZeppelin and B20 errors; in proof mode broadcast with an explicit gas limit (skipping `estimate_gas`) after a chain-id check that allows only 84532."
- Section 9 S4 fallback ("show preflight result only, labelled simulated") is not needed on testnet; keep it as the NFR-12 budget fallback.
