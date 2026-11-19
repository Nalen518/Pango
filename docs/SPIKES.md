# Phase 0 spike report

| Spike | Verdict | One line |
| --- | --- | --- |
| S1 B20 multiplier | PASS (local) · Sepolia tx hashes pending | Pending split is readable from a contract; Sepolia supports it |
| S2 Vault holds B20 | PASS (local) · Sepolia tx hashes deferred | A contract can pull, hold and send our test stock; allowlists and issuer seizure behave as documented |
| S3 Fair-value units | PARTIAL · rest deferred (API blocked, public RPC rate-limited) | Feeds read: 8 decimals, ~50 h weekend freeze; units and real-token checks need the Coinbase API |
| S4 Revert decode | PASS (local) · Sepolia tx hash deferred | web3.py decodes custom errors from eth_call and can broadcast the reverting tx |
| S6 Spend permissions | PASS (Sepolia fork) | A guard pulls USDC and a B20 stock from a Coinbase Smart Wallet via SpendPermissionManager, checks the account's agent, returns funds; allowance, revoke and isolation hold |
| S5 Weight math | PASS | 55/55 states within 1 bps of exact math; full buy with target check 223k gas; split leaves weights unchanged |

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

## S5 — Weight math across decimals, and gas of a buy with the target check

**Verdict:** PASS on base-anvil (live Rust precompiles). Run: `cd spikes && bash s5-weight-math/run.sh` (forge tests with `--isolate`, then `python3 s5-weight-math/check_weights.py`).

**What we did**

- `WeightMath` (in `spikes/s5-weight-math/S5Lib.sol`): value18 = `balanceOfUI × price8 × 1e10 / 10^decimals` per stock + `usdc6 × 1e12`; `weightBps = part × 10,000 / total` (0 when total is 0). Feed = USDC per UI share (SRD FR-V12); if S3 settles on "per raw token", only `stockValue18` changes.
- 50 seeded random states (seed `0x5EED5`, regenerable) + 5 edge cases, each written to `states.csv`. Raw balances are minted on **real B20 tokens** and multipliers set on-chain (1×, 10× split, 1.0123× dividend-style, 0.5× reverse split, random 0.5–20×); `balanceOfUI` is read back from the precompile. Every 5th state uses a **6-decimal** B20 token.
- `check_weights.py` recomputes each weight from the raw inputs with exact fractions (independent of Solidity's rounding) and checks the B20 UI conversion equals `floor(raw × multiplier / 1e18)`.
- `MiniVault` (throwaway): the SRD buy path in order — pause, allowlist, per-trade and daily cap, feed answer and staleness, pending split (`effectiveAt() > block.timestamp`), fair-value band, swap through a fixed-price pool, share cap, then the target check (targets set, `researchHash ≠ 0`, so the check really runs). Gas measured with `--isolate` (each call costed as its own transaction, cold storage).

**Measured**

| Check | Result |
| --- | --- |
| Weights, 55 states | all within 1 bps of exact; worst **0.9937 bps** over the 50 random states, **0.99999998 bps** on the dust row (Solidity floors, so the error is always < 1 bps) |
| B20 UI conversion | `balanceOfUI = floor(raw × multiplier / 1e18)` in all 110 reads, for 18- and 6-decimal tokens |
| Edge cases | all-USDC → 10,000 bps USDC; empty portfolio → 0/0/0, no revert; single stock → 10,000; 1e30-unit balances at 20× and $100,000 → no overflow |
| Split invariance | 10× split with feed ÷10 → weights 3857 / 3285 bps before and after, exactly equal |
| Gas: buy 20 USDC, every check incl. target (2 stocks, 2 feeds) | **223,013** execution gas (+21k base + calldata ≈ 245k per tx) — under the 300k target |
| Gas: buy reverting `AboveFairValue` after the swap | **169,632** execution gas |

**Surprises / notes**

1. `balanceOfUI` returns amounts in the token's own `decimals()`, not 18. The math must divide by `10^decimals` (done here); NFR-5's "B20 per its `decimals()`" is right and must not be simplified to 18.
2. The target check reads every stock's feed and balance (portfolio value), so buy gas grows with the number of stocks (~25k per extra stock, estimated). Two stocks fit easily.
3. A post-swap revert costs ~76% of a full buy, so NFR-12's 400k proof-mode gas limit and "budget sized from a full buy" hold.

**Recommended SRD changes**

- Section 9 S5: mark passed; fallback (move the overshoot check to a view) not needed.
- NFR-12: size the budget with the measured numbers — about 245k gas per proof-mode revert transaction (≈ 50 reverts/day ≈ 12M gas).
- FR-V12: state the formula with decimals: value18 = USDC × 1e12 + Σ `balanceOfUI × price8 × 1e10 / 10^decimals`; keep "feed per UI share" pending S3.
- AT-05 / AT-17: the split-invariance property is proven for the math; the `ScheduleSplit` script must move the feed ÷10 at the effective time for it to hold on-chain.

## S6 — Can PangoGuard pull funds from the user's own wallet through Base spend permissions?

**Verdict:** PASS, 5/5, on a fork of Base Sepolia (`vm.createSelectFork`, nothing broadcast). Run: `cd spikes && base-forge test --match-path 's6-*/*' -vv`. Gate for the redesign "PangoVault → PangoGuard" (funds stay in the user's Base Account).

**Facts used (all verified, Nov 19)**

| Item | Value | How verified |
| --- | --- | --- |
| `SpendPermissionManager` | `0xf85210B21cC50302F477BA56686d2019dC9b67Ad` | coinbase/spend-permissions README; 12,610 bytes of code on Base Sepolia and Base mainnet |
| Coinbase Smart Wallet factory | `0x0BA5ED0c6AA8c49038F819E587E2633c4A9F428a` | code on Base Sepolia (1,668 bytes); `implementation()` = `0x000100ab…9E72`; `getAddress(bytes[],uint256)` answers |
| `SpendPermission` struct | `account, spender, token, uint160 allowance, uint48 period, uint48 start, uint48 end, uint256 salt, bytes extraData` | `src/SpendPermissionManager.sol:29-48` (commit `e0004e6`) |
| `spend(SpendPermission, uint160 value)` | only callable by `spender`; moves `value` from `account` **to the spender** | source lines 420-426 |
| ERC-20 path | manager makes the wallet `approve` it via `execute`, then `transferFrom(account, spender)` — so the manager must be a **wallet owner** | source lines 742-751 |
| Web SDK | `@base-org/account` 2.6.0 exports `requestSpendPermission`, `fetchPermissions`, `prepareSpendCallData`, `requestRevoke`, … from `@base-org/account/spend-permission` | package `exports` + type files in `web/node_modules` |

**What the tests do** (`spikes/s6-spend-permission/S6.t.sol`): create a real Coinbase Smart Wallet on the fork with owners `[user, SpendPermissionManager]`; mint tUSDC and a B20 test stock to it; `GuardProbe` (one guard, many accounts, each account sets its agent) pulls via `spend`, checks the balance arrived, and returns it to the wallet.

| Test | Result |
| --- | --- |
| Buy path: 20 USDC through a 100 USDC/day permission | funds back in the wallet, guard holds 0; **~123k gas** for spend + return |
| Sell path: 0.5 B20 stock through a stock permission | works with default B20 policies (manager is the `transferFrom` executor) |
| Allowance ceiling: 60 then 50 within a day | second reverts `ExceededSpendPermission(110e6, 100e6)`; next day works |
| Isolation: other account's agent | guard reverts `NotAgentOf`; calling the manager directly reverts `InvalidSender(agent, guard)` |
| Revoke from the wallet | `isValid` false; next pull reverts `UnauthorizedSpendPermission` |

**Surprises / limits**

1. **Base Account / Coinbase Smart Wallet only.** The manager must be an owner of the wallet; MetaMask and other EOAs cannot use spend permissions (decided: Base Account only).
2. Funds go to the **spender** (the guard), not to an arbitrary recipient — the guard holds them only inside one transaction and must deliver the swap output to the account itself.
3. Permission periods count from `start`, not 00:00 UTC — the guard keeps its own UTC-day caps; the permission is an outer ceiling (decided).
4. The approval in the test is `approve` called from the wallet; the real app uses the SDK's signed `requestSpendPermission` → `approveWithSignature`. The signed path is proven by Coinbase's own tests, not by us — check it in the web phase.
5. Base's docs page for spend permissions now says the docs moved to Coinbase Developer Platform (blocked on this network). Contract and SDK are live; doc status unverified.
6. Gas estimate for a full guarded buy: ~223k (S5 checks) + ~123k (permission spend + delivery) ≈ **350k**, not measured as one transaction yet.

**Recommended SRD changes** (applied Nov 19): PangoVault becomes PangoGuard — one contract for all accounts, no deposits or withdrawals, the user grants a daily USDC permission (and stock permissions for sells), revokes from the wallet, and pauses per account; reads use the account's own balances; gas limit raised to 450k.
