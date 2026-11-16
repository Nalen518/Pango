# Pango — API contract

Nov 16, 2026 · Phase 0 output · source of truth for every interface between the vault, the agent service, the web app and the outside world.

Built from `docs/Pango-SRD.md`, the pinned libraries in `contracts/lib` (base-std v1.1.0, OpenZeppelin v5.7.0), the spike results in `docs/SPIKES.md`, and the Base docs pages the SRD links (read Nov 16, 2026).

**Source tags** — every item says where it comes from:

| Tag | Meaning |
| --- | --- |
| **SRD** | Stated in the SRD |
| **Base** | From base-std v1.1.0 / OpenZeppelin v5.7.0 source, or Base / wagmi docs |
| **Spike** | Measured in a Phase 0 spike (`docs/SPIKES.md`) |
| **Proposed** | Not specified anywhere yet; designed here, frozen when Phase 1 starts. Change it here first, then in code |

Open contradictions and undecided items are collected in [section 9](#9-gaps-and-decisions); nothing there is settled silently.

---

## 1. Conventions

| Item | Value | Tag |
| --- | --- | --- |
| Networks | base-anvil (local, chain id 31337) and Base Sepolia (84532). Base mainnet (8453) is **read-only**, never written | SRD |
| USDC amounts | 6 decimals (`tUSDC`) | SRD |
| Feed prices | 8 decimals, **USDC per UI share** (Chainlink `AggregatorV3Interface`) | SRD, Spike S3 (real feeds are 8 decimals) |
| Stock amounts | `raw` = B20 `balanceOf` units; `shares` = `balanceOfUI` units, both in the token's own `decimals()` (6–18) | Base, Spike S5 |
| Prices inside the vault and in error arguments | 18 decimals, USDC per UI share (NFR-5) | SRD, Proposed (error args) |
| Portfolio value | 18-decimal USD: `USDC × 1e12 + Σ balanceOfUI × price8 × 1e10 / 10^decimals` | SRD FR-V12, Spike S5 |
| Weights | basis points, `value × 10,000 / total` rounded down, 0 when total is 0; drift = absolute percentage points | SRD, Spike S5 |
| Time | Unix seconds (`block.timestamp`); "day" = UTC day `timestamp / 86400` | SRD |
| Hashes | `keccak256` | SRD |

---

## 2. PangoVault (Solidity)

Non-upgradeable, OpenZeppelin `Ownable2Step` + `Pausable` + `ReentrancyGuard` + `SafeERC20`; no `delegatecall`, no arbitrary call; only the configured router and tokens are called (SRD NFR-1).

### 2.1 Types

```solidity
enum Side { BUY, SELL }                      // Proposed: TradeExecuted.side, 0 = BUY, 1 = SELL

struct StockConfig {                         // Proposed field set; values from SRD section 5
    bool    allowed;          // trade allowed
    address feed;             // AggregatorV3Interface, 8 decimals
    uint16  bandBps;          // fresh-feed band, e.g. 100
    uint16  staleBandBps;     // stale-feed band, e.g. 25
    uint32  maxStaleness;     // seconds, e.g. 26 h
    uint32  hardStaleLimit;   // seconds, e.g. 72 h
    uint256 maxShares;        // share cap in UI units, token decimals (see D1)
}
```

Per-stock weight bounds and targets live outside `StockConfig` because they have their own setters (SRD).

### 2.2 Functions

```solidity
constructor(address owner, address agent, address usdc, address router);   // SRD FR-V1; usdc immutable

// ---- owner (onlyOwner; all work while paused) ----                          SRD
function setMandate(uint256 perTradeCapUsd, uint256 dailyCapUsd, uint256 dailySellCapUsd) external;
function configureStock(address token, StockConfig calldata cfg) external;
function setWeightBounds(address token, uint16 minBps, uint16 maxBps) external;
function setTolerance(uint16 toleranceBps, uint16 driftTriggerBps) external;
function setTargetsCooldown(uint32 cooldownSeconds) external;
function setAgent(address agent) external;
function setRouter(address router) external;
function deposit(uint256 usdcAmount) external;                 // pulls tUSDC from owner (transferFrom)
function withdraw(address token, uint256 amount) external;     // nonReentrant; always to owner()
function pause() external;
function unpause() external;
// ownership: transferOwnership / acceptOwnership from Ownable2Step          Base (OZ v5)

// ---- agent (onlyAgent) ----                                                  SRD
function buy(address token, uint256 usdcIn) external returns (uint256 rawOut);    // whenNotPaused, nonReentrant
function sell(address token, uint256 rawIn) external returns (uint256 usdcOut);   // whenNotPaused, nonReentrant
function setTargets(address[] calldata tokens, uint16[] calldata weightsBps, bytes32 researchHash) external; // whenNotPaused

// ---- views ----                                                              SRD
function previewBuy(address token, uint256 usdcIn) external view
    returns (bytes4 errorSelector, uint256 maxPrice, uint256 feedAge);  // errorSelector == 0x00000000 → would pass (Proposed)
function previewSell(address token, uint256 rawIn) external view
    returns (bytes4 errorSelector, uint256 minPrice, uint256 feedAge);
function spentToday() external view returns (uint256);
function soldToday() external view returns (uint256);
function portfolioValue() external view returns (uint256 usdValue18);
function weightOf(address token) external view returns (uint16 weightBps);

// ---- public getters (Proposed, needed by web + agent) ----
function agent() external view returns (address);
function router() external view returns (address);
function usdc() external view returns (address);
function stockConfig(address token) external view returns (StockConfig memory);
function stocks() external view returns (address[] memory);              // configured tokens, in order
function weightBounds(address token) external view returns (uint16 minBps, uint16 maxBps);
function targetBps(address token) external view returns (uint16);
function researchHash() external view returns (bytes32);
function lastTargetsAt() external view returns (uint256);
function mandate() external view returns (uint256 perTradeCapUsd, uint256 dailyCapUsd, uint256 dailySellCapUsd);
function tolerance() external view returns (uint16 toleranceBps, uint16 driftTriggerBps);
function targetsCooldown() external view returns (uint32);
// paused() and owner() from OZ
```

### 2.3 Check order

**Buy** (SRD section 5; proven in Spike S5's MiniVault):

1. Paused → `EnforcedPause`; caller ≠ agent → `NotAgent`
2. `!allowed` → `TokenNotAllowed`
3. `usdcIn > perTradeCapUsd` → `ExceedsPerTradeCap`; `spentToday + usdcIn > dailyCapUsd` → `ExceedsDailyCap` (day rolls at 00:00 UTC)
4. Feed `answer ≤ 0` → `InvalidFeedAnswer`; `age > hardStaleLimit` → `StaleOracle`; band = `staleBandBps` if `age > maxStaleness`, else `bandBps`
5. `IB20Asset(token).effectiveAt() > block.timestamp` → `CorporateActionPending(effectiveAt)` — never test `!= 0` (Spike S1)
6. `maxPrice = oracle × (10,000 + band) / 10,000`; `forceApprove(router, usdcIn)` exactly; swap; measure `balanceOfUI` received
7. paid > max → `AboveFairValue(paidPrice, maxPrice)`
8. `balanceOfUI(vault) > maxShares` → `ExceedsShareCap(sharesAfter, maxShares)`
9. If `researchHash != 0`: `weightOf(token) > target + tolerance` → `OvershootsTarget`
10. Update `spentToday`, emit `TradeExecuted`

**Sell** mirrors 1, 2, 4, 5, then `soldToday + value(rawIn at oracle) > dailySellCapUsd` → `ExceedsDailySellCap`, then `BelowFairValue(receivedPrice, minPrice)`, then target check (`weight < target − tolerance` → `OvershootsTarget`) (SRD).

**setTargets**: paused → `EnforcedPause`; not agent → `NotAgent`; `block.timestamp < lastTargetsAt + cooldown` → `TargetsCooldown(readyAt)`; length mismatch → `LengthMismatch`; `researchHash == 0` → `ZeroResearchHash`; each weight outside `[min, max]` or Σ > 10,000 → `TargetOutOfBounds`; configured stocks not listed get target 0 (revert `TargetOutOfBounds` if their `min > 0`) (SRD FR-V11; error names for the two new cases Proposed).

### 2.4 Errors

Plain-English text is what the receipt line shows (SRD section 5). Parameters marked *Proposed* where the SRD names the error without arguments.

| Error | Thrown by | Receipt text | Tag |
| --- | --- | --- | --- |
| `OwnableUnauthorizedAccount(address account)` | owner functions | Only the owner can do this | Base (OZ v5) |
| `NotAgent(address caller)` | agent functions | Only the agent can do this | SRD name, Proposed args |
| `EnforcedPause()` | buy, sell, setTargets | The owner paused the agent | Base (OZ v5) |
| `TokenNotAllowed(address token)` | buy, sell | This stock is not on your list | SRD, Proposed args |
| `ExceedsPerTradeCap(uint256 usdcIn, uint256 cap)` | buy | Over your per-trade limit | SRD, Proposed args |
| `ExceedsDailyCap(uint256 spentAfter, uint256 cap)` | buy | Over your daily limit | SRD, Proposed args |
| `ExceedsDailySellCap(uint256 soldAfter, uint256 cap)` | sell | Over your daily selling limit | SRD, Proposed args |
| `InvalidFeedAnswer(int256 answer)` | buy, sell | No trustworthy price right now | SRD, Proposed args |
| `StaleOracle(uint256 feedAge, uint256 limit)` | buy, sell | No trustworthy price right now | SRD, Proposed args |
| `CorporateActionPending(uint256 effectiveAt)` | buy, sell | A split or dividend adjustment is scheduled; trading waits until it takes effect | SRD |
| `AboveFairValue(uint256 paidPrice, uint256 maxPrice)` | buy | The price is too far from the reference price | SRD (prices 18 dec, Proposed) |
| `BelowFairValue(uint256 receivedPrice, uint256 minPrice)` | sell | The price is too far from the reference price | SRD |
| `ExceedsShareCap(uint256 sharesAfter, uint256 maxShares)` | buy | This would put you over your share limit | SRD |
| `TargetOutOfBounds(address token, uint16 weightBps)` | setTargets | That target is outside the range you allowed | SRD |
| `OvershootsTarget(address token, uint256 weightAfterBps, uint256 targetBps)` | buy, sell | This trade would push the stock past its target | SRD |
| `TargetsCooldown(uint256 readyAt)` | setTargets | Targets were changed moments ago; wait before changing them again | SRD |
| `LengthMismatch(uint256 tokens, uint256 weights)` | setTargets | — (agent bug) | Proposed |
| `ZeroResearchHash()` | setTargets | — (agent bug) | Proposed |
| `ZeroAddress()` | constructor, setAgent, setRouter, configureStock | — (setup bug) | Proposed |
| `InvalidBounds(uint16 minBps, uint16 maxBps)` | setWeightBounds | — (owner form validation) | Proposed |

**Errors that bubble up from other contracts** — the agent's decoder must know these (SRD FR-A4, Spike S4). Selectors computed with `base-cast sig`:

| Error | Selector | From | Receipt text |
| --- | --- | --- | --- |
| `PolicyForbids(bytes32 policyScope, uint64 policyId)` | `0xa43fec12` | B20 token | The stock's issuer does not allow this transfer right now |
| `ContractPaused(uint8 feature)` | `0xfd8c4245` | B20 token (`PausableFeature` 0 TRANSFER, 1 MINT, 2 BURN, 3 SEIZE) | The stock's issuer paused transfers |
| `InsufficientBalance(address sender, uint256 balance, uint256 needed)` | `0xdb42144d` | B20 token | Not enough of this stock |
| `AccountNotSeizable(address account)` | `0x91dbbc8d` | B20 token (issuer side only) | — |
| `OwnableUnauthorizedAccount(address)` | `0x118cdaa7` | OZ v5 | Only the owner can do this |
| `EnforcedPause()` | `0xd93c0665` | OZ v5 | The owner paused the agent |
| `ExpectedPause()` | `0x8dfc202b` | OZ v5 (`unpause` when not paused) | — |
| `ReentrancyGuardReentrantCall()` | `0x3ee5aeb5` | OZ v5 | — |
| `SafeERC20FailedOperation(address token)` | `0x5274afe7` | OZ v5 | A token transfer failed |

Anything else → "unknown error 0x…" with the raw selector (SRD FR-A4).

### 2.5 Events

| Event | Emitted by | Tag |
| --- | --- | --- |
| `MandateUpdated(uint256 perTradeCapUsd, uint256 dailyCapUsd, uint256 dailySellCapUsd)` | setMandate | SRD name, Proposed args |
| `StockConfigured(address indexed token, StockConfig cfg)` | configureStock | SRD name, Proposed args |
| `WeightBoundsUpdated(address indexed token, uint16 minBps, uint16 maxBps)` | setWeightBounds | Proposed (see D3) |
| `ToleranceUpdated(uint16 toleranceBps, uint16 driftTriggerBps)` | setTolerance | Proposed (see D3) |
| `TargetsCooldownUpdated(uint32 cooldownSeconds)` | setTargetsCooldown | Proposed |
| `AgentChanged(address indexed oldAgent, address indexed newAgent)` | setAgent | SRD name, Proposed args |
| `RouterChanged(address indexed oldRouter, address indexed newRouter)` | setRouter | SRD name, Proposed args |
| `Deposited(address indexed token, uint256 amount)` | deposit | SRD name, Proposed args |
| `Withdrawn(address indexed token, uint256 amount, address indexed to)` | withdraw | SRD name, Proposed args |
| `TradeExecuted(address indexed token, Side side, uint256 usdcAmount, uint256 rawAmount, uint256 sharesAfter, uint256 oraclePrice, uint256 feedAge)` | buy, sell | SRD |
| `TargetsSet(bytes32 indexed researchHash, address[] tokens, uint16[] weightsBps)` | setTargets | SRD (indexed Proposed) |
| `Paused(address account)` `0x62e78cea…a258` / `Unpaused(address account)` `0x5db9ee0a…73aa` | pause / unpause | Base (OZ v5) |
| `OwnershipTransferStarted`, `OwnershipTransferred` | Ownable2Step | Base (OZ v5) |

B20 tokens emit their own `Paused(address,uint8[])` with a different topic; index vault events by vault address only.

### 2.6 Gas (Spike S5, base-anvil, 2 stocks)

Full buy with every check incl. target ≈ 223k execution gas (~245k per transaction); `AboveFairValue` revert after the swap ≈ 170k; revert at the top of `buy` ≈ 22k (Spike S4). Proof-mode sends use a 400k gas limit (SRD NFR-12).

---

## 3. Test contracts on Base Sepolia (we deploy them)

All test-only, labelled in the UI (SRD FR-W7). Interfaces Proposed unless stated.

### 3.1 tUSDC

ERC-20 (OZ), 6 decimals, `mint(address to, uint256 amount)` restricted to the deployer, so balances on the public demo stay meaningful (Proposed).

### 3.2 tNVDA, tAAPL — B20 asset tokens

Created through the factory (Base, Spike S1):

```text
B20_FACTORY.createB20(ASSET, salt, encodeAssetCreateParams(name, symbol, admin, 18), initCalls)
initCalls = grantRole(MINT_ROLE, deployer), grantRole(OPERATOR_ROLE, deployer)
```

18 decimals; every policy slot left at `0` (always allow), so the vault and StockSwap hold them with no setup (Spike S2). Splits: `updateUIMultiplier(newMultiplier, effectiveAt)` by the operator (Spike S1).

### 3.3 MockAggregatorV3 (one per stock)

```solidity
function decimals() external pure returns (uint8);           // 8
function description() external view returns (string memory); // "Pango test tNVDA / USD"
function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
function getRoundData(uint80 roundId) external view returns (uint80, int256, uint256, uint256, uint80);
// test levers (deployer only)
function setAnswer(int256 answer) external;                 // updatedAt = block.timestamp, new round
function setAnswerAt(int256 answer, uint256 updatedAt) external; // for SetWeekend / SetFeedDead
```

Copies real-feed behaviour (Spike S3): 8 decimals, ~50 h weekend freeze.

### 3.4 StockSwap (router)

```solidity
function quote(address tokenIn, address tokenOut, uint256 amountIn) external view returns (uint256 amountOut); // used by previews (SRD FR-V9)
function swapExactIn(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut) external returns (uint256 amountOut);
// test levers (deployer only)
function setPrice(address stock, uint256 price8) external;     // USDC per UI share, 8 dec
function setPremiumBps(int256 premiumBps) external;            // +400 = SetPremium(4%), negative = discount
```

The vault passes its own `minAmountOut` and **also** measures the balance change (SRD FR-V6), so a dishonest router still cannot overcharge.

### 3.5 Scenario scripts (SRD section 7)

`SetFair`, `SetPremium(4%)`, `SetWeekend` (feed 40 h back), `SetFeedDead` (80 h back), `ScheduleSplit(10)` (multiplier ×10 in 30 min, then feed and swap price ÷10 at the effective time), `ResetDay` (base-anvil only), `SetDrift(tNVDA, +30%)`.

---

## 4. Agent service HTTP API (FastAPI) — all Proposed

The SRD names the agent's jobs (FR-A1…A10) but not its HTTP surface; this section defines it.

### 4.1 Rules

- Base URL: `NEXT_PUBLIC_AGENT_API_URL` (local `http://127.0.0.1:8000`, hosted on Railway). JSON in and out, UTF-8.
- **No owner actions, ever.** The owner key never reaches the server (SRD NFR-3); mandate, deposit, withdraw and pause are signed in the browser.
- **Public endpoints** are rate-limited per IP (SRD NFR-12, e.g. 1 attack per 30 s) and answer `429` with `Retry-After` when exceeded. When the daily gas budget is spent, attempts still run but are recorded with `mode: "simulated"` (preflight only).
- **Admin endpoints** need header `X-Admin-Token: <ADMIN_TOKEN env>`; they start research, a rebalance, or toggle proof mode. Never exposed in the web bundle.
- Every write takes an `idempotencyKey` (client-generated UUID); repeating it returns the same attempt and never sends twice (SRD NFR-7).
- CORS: only the web app's origin.
- Errors: `{"error": {"code": "rate_limited" | "invalid_input" | "not_found" | "unauthorized" | "budget_exhausted" | "chain_unavailable" | "internal", "message": "..."}}`.

### 4.2 Endpoints

| Method & path | Access | Body / query | Returns |
| --- | --- | --- | --- |
| `GET /health` | public | — | `{"ok": true, "chainId": 84532, "block": 123, "version": "0.1.0"}` |
| `GET /config` | public | — | Addresses, chain, explorer, labels (4.4) |
| `POST /chat` | public, rate-limited | `{"message": "Buy $20 of tNVDA", "idempotencyKey": "uuid"}` | `202 {"attemptId": "att_…"}` |
| `POST /news` | public, rate-limited | `{"text": "…"} or {"url": "https://…"}, "idempotencyKey"` | `202 {"attemptId"}` |
| `GET /attacks` | public | — | `[{"id": "fake-split", "label": "Fake split news", "expectedError": "AboveFairValue", "setup": "SetPremium(4%)"}, …]` — the 6 presets of US-13 |
| `POST /attacks/{id}` | public, rate-limited | `{"idempotencyKey"}` | `202 {"attemptId"}` |
| `GET /attempts` | public | `?after=<attemptId>&limit=50` | `{"items": [Attempt], "next": "att_…" \| null}` — poll every 4 s (SRD NFR-6) |
| `GET /attempts/{id}` | public | — | `Attempt` |
| `GET /research/current` | public | — | `{"researchHash": "0x…", "scoringVersion": "score-v1", "createdAt": "…", "targets": [{"ticker": "NVDA", "token": "0x…", "weightBps": 3500}], "reportUrl": "/research/0x…/report.json"}` |
| `GET /research/{hash}/report.json` | public | — | The report **exact stored bytes**, `Content-Type: application/json` (4.5) |
| `GET /loop` | public | — | `{"enabled": true, "intervalSec": 300, "lastRunAt": "…", "nextRunAt": "…", "lastResult": "within_tolerance" \| "rebalanced" \| "waiting_corporate_action" \| "error"}` |
| `POST /admin/research/run` | admin | `{"idempotencyKey"}` | `202 {"runId"}` |
| `POST /admin/rebalance/run` | admin | `{"idempotencyKey"}` | `202 {"attemptIds": [...]}` |
| `POST /admin/loop` | admin | `{"enabled": bool, "intervalSec": 300}` | `GET /loop` body |
| `POST /admin/proof-mode` | admin | `{"enabled": bool}` | `{"proofMode": bool}` |

### 4.3 Attempt object

```json
{
  "id": "att_01JD…",
  "idempotencyKey": "6f1c…",
  "createdAt": "2026-11-20T03:14:15Z",
  "channel": "chat | news | attack | rebalance",
  "input": "Buy $20 of tNVDA",
  "proposal": { "ticker": "NVDA", "token": "0x…", "side": "buy | sell", "amount": "20000000", "amountUnit": "usdc6 | raw", "rationale": "one paragraph" },
  "factCheck": { "claim": "10-for-1 split", "verdict": "verified_onchain | unverified | not_applicable", "evidence": { "effectiveAt": 0, "newUIMultiplier": "1000000000000000000" } },
  "preflight": { "ok": false, "error": { "name": "AboveFairValue", "selector": "0x…", "args": { "paidPrice": "…", "maxPrice": "…" }, "reason": "The price is too far from the reference price" } },
  "mode": "live | proof | simulated",
  "tx": { "hash": "0x…", "status": "success | reverted | pending | dropped", "gasUsed": 169632, "blockNumber": 123, "explorerUrl": "https://sepolia.basescan.org/tx/0x…" },
  "status": "proposed | preflight_failed | sent | confirmed | reverted | refused"
}
```

`tx` is `null` when nothing was sent (preflight failed outside proof mode, or `simulated`). Amounts are decimal strings (no float). Big integers in `args` are strings.

### 4.4 `GET /config`

```json
{
  "chainId": 84532,
  "explorer": "https://sepolia.basescan.org",
  "contracts": {
    "vault": "0x…", "usdc": "0x…", "router": "0x…",
    "stocks": [ { "ticker": "NVDA", "symbol": "tNVDA", "token": "0x…", "feed": "0x…", "decimals": 18 } ]
  },
  "builderCode": "bc_…",
  "proofMode": true,
  "budget": { "gasRemainingToday": 11800000 },
  "labels": { "network": "Base Sepolia test network", "assets": "Test stocks issued by us on Base Sepolia", "research": "Research uses real market data; trades use test stocks on Base Sepolia." }
}
```

The web app reads chain state itself (5); `/config` only tells it where to look.

### 4.5 Research report (FR-A7, US-19)

The hash check only works if both sides hash **the same bytes**:

1. The agent serialises the report once (canonical JSON: UTF-8, keys sorted, no insignificant whitespace), stores those bytes, and sends `keccak256(bytes)` as `researchHash` to `setTargets`.
2. `GET /research/{hash}/report.json` returns the stored bytes verbatim.
3. The browser hashes the response body as received (`keccak256(new Uint8Array(await res.arrayBuffer()))`) and compares with `vault.researchHash()`. It never re-serialises the JSON.

```json
{
  "schema": "pango.research.v1",
  "scoringVersion": "score-v1",
  "createdAt": "2026-11-20T03:00:00Z",
  "chainId": 84532,
  "vault": "0x…",
  "bounds": { "NVDA": { "minBps": 1000, "maxBps": 4000 } },
  "signals": [
    {
      "ticker": "NVDA",
      "token": "0x… (tNVDA)",
      "feedMomentum": { "window": "7d", "changeBps": 312, "source": "mainnet feed 0x0468…8513" },
      "navPremium": { "status": "ok | unavailable", "bps": null, "reason": "api.coinbase.com unreachable" },
      "corporateAction": { "pending": false, "effectiveAt": 0, "newUIMultiplier": "1000000000000000000" },
      "news": [ { "title": "…", "url": "https://…", "publishedAt": "…", "source": "…" } ]
    }
  ],
  "weightsBps": { "NVDA": 3500, "AAPL": 3500 },
  "thesis": { "NVDA": "…", "AAPL": "…" },
  "llm": { "provider": "TBD", "model": "TBD" }
}
```

A missing signal is recorded as `"status": "unavailable"`, never a failed run (the Tokenized Stocks API is blocked on the build network, Spike S3). `weightsBps = score(signals, bounds)` must be reproducible from the report alone (SRD US-19, AT-14); the scoring function and its version string live in the agent repo.

---

## 5. Web app ↔ chain (wagmi / viem)

| Item | Value | Tag |
| --- | --- | --- |
| Connectors | `baseAccount({ appName, appLogoUrl })` from `wagmi/connectors` (needs `@base-org/account ^2.5.1`; we have 2.6.0) and `injected()` | Base (wagmi docs), SRD |
| Chain | `baseSepolia` from `viem/chains` | Base |
| Reads (every block or 4 s, NFR-6) | `paused`, `mandate`, `stocks`, `stockConfig`, `spentToday`, `soldToday`, `portfolioValue`, `weightOf`, `targetBps`, `weightBounds`, `tolerance`, `researchHash`; per stock `balanceOfUI(vault)`, `balanceOf(vault)`, `effectiveAt`, `newUIMultiplier`, `uiMultiplier`; feed `latestRoundData`; router `quote` | SRD FR-W3, W8 |
| Owner writes | `setMandate`, `configureStock`, `setWeightBounds`, `setTolerance`, `setTargetsCooldown`, `deposit` (after `tUSDC.approve`), `withdraw`, `pause`, `unpause` | SRD FR-W2, W6 |
| Errors on owner writes | decoded with viem `decodeErrorResult` against the vault ABI + the bubbled errors (2.4), shown with the receipt text | Proposed |
| Mascot pose (FR 4.4) | Sleeping if `paused`; else Curled if the latest attempt `status = reverted / preflight_failed`; else Half-curled if any stock `effectiveAt > now`; else Peeking if any feed age > `maxStaleness`; else Walking | SRD, priority order Proposed |

---

## 6. External interfaces

### 6.1 B20 precompiles (Base, base-std v1.1.0 Cobalt; same addresses on all chains)

| Contract | Address |
| --- | --- |
| B20 factory | `0xB20f000000000000000000000000000000000000` |
| Activation registry | `0x8453000000000000000000000000000000000001` |
| Policy registry | `0x8453000000000000000000000000000000000002` |

| Call | Selector | Used by |
| --- | --- | --- |
| `balanceOf(address)` | `0x70a08231` | vault, web |
| `balanceOfUI(address)` | `0x437a9958` | vault (share cap, valuation), web |
| `decimals()` | `0x313ce567` | vault valuation |
| `transfer(address,uint256)` / `transferFrom(address,address,uint256)` / `approve(address,uint256)` | `0xa9059cbb` / `0x23b872dd` / `0x095ea7b3` | vault, StockSwap |
| `uiMultiplier()` / `newUIMultiplier()` / `effectiveAt()` | `0xa60bf13d` / `0xdc767007` / `0x97a4064f` | vault check 5, agent fact-check, web |
| `toUIAmount(uint256)` / `fromUIAmount(uint256)` | `0x3248d4ff` / `0x65cd9b3c` | vault, StockSwap |
| `isPaused(uint8)` | `0xbc61e733` | web (issuer pause banner) |
| `policyId(bytes32)` / `isAuthorized(uint64,address)` / `policyExists(uint64)` | `0xdb3de624` / `0x55a1179e` / `0x330f5637` | agent diagnostics |
| `isActivated(bytes32)` | `0xba87af80` | deploy script guard (`B20_ASSET` = `0xcdcc772f…f54c`) |
| `createB20(uint8,bytes32,bytes,bytes[])` / `getB20Address(uint8,address,bytes32)` | `0x62975e6a` / `0x8c30260f` | deploy script |
| `updateUIMultiplier(uint256,uint256)` | `0x628e600f` | `ScheduleSplit` script |

Events to index: `Transfer(address,address,uint256)` `0xddf252ad…b3ef`, `UIMultiplierUpdated(uint256,uint256,uint256)` `0x2205df45…b055` (emitted at scheduling time, not when it takes effect — Base changelog).

Rules learned: decimals 6–18 (factory reverts `InvalidDecimals` otherwise); pending ⇔ `effectiveAt() > block.timestamp`; policies default to always-allow; issuer can freeze or seize (Spike S2).

### 6.2 Chainlink `AggregatorV3Interface` (Base, Spike S3)

`latestRoundData()` `0xfeaf968c` → `(roundId, answer, startedAt, updatedAt, answeredInRound)`; `getRoundData(uint80)` `0x9a6fc8f5`; `decimals()`.

Real Coinbase feeds on Base **mainnet, read-only**, for the shadow panel and S3 only (FR-W10, FR-A9): NVDA `0x04689a41629776563E6822F76f2e57D148d28513`, AAPL `0x787f13dEa48Db0897CbCDD985de77809D837F988`. Stored only in the read-only shadow config, never loaded by the signer.

### 6.3 Tokenized Stocks API (Base docs; **blocked on the build network**)

- Base URL `https://api.coinbase.com/v1/tokenized-stocks`, public, no key.
- `GET /` → `{ "tokens": [...], "next_page_token": "…" }` (page_size default 100, max 500). Token fields: `contract_address`, `symbol`, `name`, `decimals`, `icon_url`, `total_supply`, `isin`, `adgm_isin`, `multiplier` (1.0 = no adjustment), `paused_features`, `nav_price`, `nav_price_updated_at`, `description`, `first_mint_date`.
- Also `GET /chains`, `/total-supply/{contract_address}`, `/metadata/{ticker}`, `/images/{symbol}`, `/prospectus/{ticker}`, `/prospectuses`, `/corporate-actions/{id}`.
- Errors `{ "code": N, "message": "…" }` (HTTP 400/404/503 → codes 3/5/14).
- The agent treats it as **optional**: timeout 5 s, on failure the signal is `"unavailable"` (4.5).

### 6.4 Builder Codes (ERC-8021) — FR-A10 (Base docs)

| Item | Value |
| --- | --- |
| Get a code (agent) | `POST https://api.base.dev/v1/agents/builder-codes` `{"walletAddress": "0x…"}` → `{"builderCode": "bc_…", "walletAddress": "0x…"}`; no auth, idempotent per wallet. **Sends the agent address to an external service — run only with Nalen518's approval** (see D9) |
| Get a code (app) | dashboard.base.org → Settings → Project Settings → Builder Code |
| Suffix layout (appended to calldata) | `ASCII(codes joined by ",") ‖ length (1 byte) ‖ schema id 0x00 (1 byte) ‖ marker 0x80218021802180218021802180218021 (16 bytes)` — example `bc_b7k3p9da` → `0x62635f62376b33703964610b0080218021802180218021802180218021` |
| Python (agent) | build the bytes above and append to `tx["data"]` before signing; contracts ignore trailing bytes. Cost: 16 gas per non-zero byte |
| Web (wagmi) | `import { Attribution } from "ox/erc8021"`; `DATA_SUFFIX = Attribution.toDataSuffix({ codes: [code] })`; pass `dataSuffix: DATA_SUFFIX` **on every** `writeContract` / `sendTransaction` call. A `dataSuffix` in `createConfig` is **not** applied to connected wallets. Needs viem ≥ 2.45 (we have 2.57.19) |
| Smart wallets (Base Account) | ERC-5792 wallets take it as `capabilities: { dataSuffix: { value, optional: true } }` via `sendCalls` — see D6 |
| Verify | last 16 bytes of calldata are `8021…` on Basescan, or builder-code-checker.vercel.app |

### 6.5 Other

| Service | Use | Status |
| --- | --- | --- |
| LLM with tool calling | proposal + thesis text only (FR-A2, A7) | provider TBD (SRD open question) |
| News feed (RSS / pasted) | research signals, attack presets | Proposed: RSS URL list in config |
| Bankr Agent API | stretch signer | out of v1 |
| RPC | provider URL for agent (`BASE_SEPOLIA_RPC_URL`, `BASE_MAINNET_RPC_URL`); public RPC is rate-limited (Spike S3) | needed |

---

## 7. Environment variables

| Variable | Used by | Secret | Tag |
| --- | --- | --- | --- |
| `BASE_SEPOLIA_RPC_URL` | agent, scripts | yes (provider key) | SRD |
| `BASE_MAINNET_RPC_URL` | shadow panel, S3 (read-only) | yes | SRD |
| `BASESCAN_API_KEY` | contract verification | yes | SRD |
| `DEPLOYER_PRIVATE_KEY` | base-forge scripts only | yes | SRD |
| `AGENT_PRIVATE_KEY` | agent executor | yes | SRD |
| `OWNER_ADDRESS` | deploy script | no | SRD |
| `LLM_API_KEY` | agent | yes | SRD |
| `ADMIN_TOKEN` | agent admin endpoints | yes | Proposed |
| `DATABASE_URL` | agent log (SQLite local, Railway Postgres hosted) | yes | SRD NFR-13 |
| `BUILDER_CODE` | agent suffix | no | Proposed |
| `GAS_BUDGET_DAILY` | agent, default 12,000,000 | no | Proposed (SRD NFR-12) |
| `ALLOWED_ORIGIN` | agent CORS | no | Proposed |
| `NEXT_PUBLIC_CHAIN_ID`, `NEXT_PUBLIC_VAULT_ADDRESS`, `NEXT_PUBLIC_AGENT_API_URL`, `NEXT_PUBLIC_BUILDER_CODE` | web (public values only) | no | SRD / Proposed |

`.env.example` gains the Proposed rows in Phase 1.

---

## 8. Traceability

| SRD requirement | Section here |
| --- | --- |
| FR-V1–V13 | 2 |
| FR-A1, A2, A6 | 4.2, 4.3 |
| FR-A3 | 4.3 `factCheck`, 6.1 |
| FR-A4 | 2.4 bubbled errors, 4.1 proof mode |
| FR-A5, NFR-3, NFR-4 | 4.1, 7 |
| FR-A7, US-19, AT-14 | 4.5 |
| FR-A8 | 4.2 `/loop`, `/admin/rebalance/run` |
| FR-A9, FR-W10 | 6.2, D5 |
| FR-A10 | 6.4 |
| FR-W1–W9 | 4.4, 5 |
| US-13 (6 presets) | 4.2 `GET /attacks` |
| NFR-6, NFR-7, NFR-12, NFR-13 | 4.1, 4.2, 2.6 |

---

## 9. Gaps and decisions

Found while writing this contract. Each needs a decision before Phase 1 freezes the vault (Nov 23).

| # | Gap | Options | Recommended |
| --- | --- | --- | --- |
| D1 | SRD says `maxShares` is "18 decimals, UI units", but `balanceOfUI` is in the token's own decimals (Spike S5) | (a) state "token decimals" and keep 6–18 allowed; (b) `configureStock` requires 18-decimal tokens | (a), and our test stocks are 18 anyway |
| D2 | US-01 / AT-01 say the owner *creates* a vault; FR-W1 says no factory | (a) reword: owner *configures* the deployed demo vault; (b) add a factory | (a) |
| D3 | US-15 says weight bounds emit `MandateUpdated`; its args don't fit | (a) dedicated `WeightBoundsUpdated` / `ToleranceUpdated` (2.5); (b) one generic event | (a) |
| D4 | `minMultiplierChangeBps` (US-09 fallback) depends on deferred S3 | (a) leave out of v1, "block every pending update"; (b) add now | (a) |
| D5 | FR-W10 shadow panel needs real token + pool addresses (S3 deferred); feed addresses are known | (a) feed-only panel now (real price + weekend age), pool quote later; (b) drop FR-W10; (c) wait for a provider RPC | (a) |
| D6 | Base Account is a smart wallet; whether `writeContract` + `dataSuffix` carries the Builder Code through it is unverified | (a) test in the web phase, fall back to `sendCalls` capability; (b) attribute agent txs only | (a) |
| D7 | Price units in error args: NFR-5 says 18 decimals inside the contract; Spike S5 used 8 | (a) 18 decimals (2.4); (b) 8 decimals like the feed | (a) |
| D8 | `previewBuy` / `previewSell` "no error" value is unspecified | `bytes4(0)` = would pass (2.2) | as written |
| D9 | Registering a Builder Code sends the agent address to `api.base.dev` (external, reachability from this network unchecked) | (a) register when the agent key exists, with approval; (b) dashboard code only | (a) |
| D10 | Real-feed units (per share vs per raw token) still open (S3) | (a) keep "per UI share" for our mocks, revisit for FR-W10; (b) switch now | (a) |
| D11 | SRD section 5 and this file both define the vault interface | (a) SRD section 5 points here, this file is the single source; (b) keep both in sync by hand | (a) |
