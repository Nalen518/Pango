# Pango — project checklist

Nov 16, 2026 · tracks every phase from setup to submission (deadline **Dec 5, 2026**). Tick items as they land; put the commit hash next to done items.

- Dates come from SRD section 10. **Design** and **slicing** are not separate phases in the SRD; their dates sit inside the SRD's "Web app + mascot" window (Nov 25 – Dec 1), with design allowed to start early. Those are marked *(proposed)*.
- IDs (FR-, NFR-, US-, AT-) point to `docs/Pango-SRD.md`; interfaces point to `docs/API-CONTRACT.md` (§ = section).
- Work happens on `Development`; `main` only gets ready-to-deploy merges, when Nalen518 asks.

## Milestones

| Date | Milestone | Status |
| --- | --- | --- |
| Nov 17 | Spikes done or on fallback | ✅ spikes run Nov 16 (S3 partial) |
| Nov 23 | Vault frozen | ⬜ |
| Nov 25 | Sepolia deployment live | ⬜ |
| Nov 28 | Scope-cut check: keep research step, or owner sets targets by hand | ⬜ |
| Dec 1 | Web app + mascot done | ⬜ |
| Dec 4 | Video + X post | ⬜ |
| **Dec 5** | **Submit** | ⬜ |

---

## P0 — Setup and risk spikes (Nov 15–17)

### Done

- [x] SRD review: 17 findings fixed, changelog added — `fa33c6f` (and earlier edits)
- [x] WSL2 Ubuntu (already present); Base Foundry build **v1.5.1** installed — README
- [x] Repo scaffold: `contracts/` (OZ v5.7.0, base-std v1.1.0, forge-std v1.17.0), `agent/` (uv, Python 3.11, FastAPI, web3 8), `web/` (Next.js 16, wagmi, viem, Base Account), `spikes/`, `.env.example`, README, CLAUDE.md — `c7f7106`
- [x] GitHub repo Nalen518/Pango linked; `Development` branch in use — `69c8db1`
- [x] Gap review applied: deterministic research, sell cap + cooldown, mainnet shadow panel, Railway hosting — `fa33c6f`
- [x] S1 — B20 split readable from a contract; Sepolia factory open and Cobalt live (eth_call) — `69c8db1`
- [x] S2 — contract holds and moves B20; allowlist and issuer seizure behaviour recorded — `dea9051`
- [x] S3 (partial) — real feeds: 8 decimals, ~50 h weekend freeze — `04f337b`
- [x] S4 — custom errors decoded from `eth_call`; reverting tx broadcast — `dbc04c2`
- [x] S5 — weight math within 1 bps (55 states), split-invariant; buy 223k gas — `17de7a4`
- [x] SRD updated with S1, S2, S4, S5 findings — `f54f2bc`, `955a13f`, `e2806d6`
- [x] `docs/SPIKES.md` report
- [x] `docs/API-CONTRACT.md` and this checklist

### Still open

- [ ] Fund a deployer wallet (key generated in WSL straight into `.env`, address only shown) → Sepolia tx hashes for S1 (create token, schedule split), S2 (transfer in/out), S4 (reverted tx)
- [ ] S3 real-token checks: token addresses, NAV vs feed vs DEX, real policy for a contract, corporate-action lead times — needs a provider RPC URL in `.env` (`BASE_MAINNET_RPC_URL`) or a network where `api.coinbase.com` loads
- [ ] Decide API-CONTRACT §9 items D1–D11 before the vault freeze
- [ ] Choose the LLM provider and budget (SRD open question)
- [ ] Ask the partner Telegram groups for judging criteria and build-in-public rules (only Nalen518 can)
- [ ] Get a provider RPC (Alchemy / CDP) for Base Sepolia — the agent needs it anyway (SRD §11)

---

## P1 — PangoVault contract (Nov 17–23)

Interface: API-CONTRACT §2. Tests first (SRD §9 risk: limited Solidity experience).

- [ ] `contracts/src/PangoVault.sol` skeleton: constructor, storage, getters (§2.2), OZ `Ownable2Step`, `Pausable`, `ReentrancyGuard`, `SafeERC20` — FR-V1, NFR-1
- [ ] Owner setters + events: `setMandate`, `configureStock`, `setWeightBounds`, `setTolerance`, `setTargetsCooldown`, `setAgent`, `setRouter` — FR-V2, FR-V10, US-01, US-15
- [ ] `deposit` / `withdraw` (to owner only, works while paused, `nonReentrant`) — US-02, US-03, NFR-2
- [ ] `pause` / `unpause` — US-04
- [ ] `buy` with the 10-step check order (§2.3), exact `forceApprove`, balance-change measurement — FR-V3–V7, US-07–US-11
- [ ] Stale band (`staleBandBps` past `maxStaleness`) and `StaleOracle` past `hardStaleLimit` — FR-V5, US-10
- [ ] Corporate-action check `effectiveAt() > block.timestamp` — FR-V4, US-09
- [ ] `sell` with sell cap and `BelowFairValue` — US-08, SRD §5
- [ ] `setTargets` with bounds, Σ ≤ 10,000, omitted stocks = 0, cooldown, non-zero hash — FR-V11, US-16, US-18
- [ ] `portfolioValue` / `weightOf` with token decimals (S5 formula) — FR-V12
- [ ] Target check after trades, skipped while `researchHash == 0` — FR-V13
- [ ] `previewBuy` / `previewSell` via `StockSwap.quote()` incl. share-cap and target checks — FR-V9
- [ ] Unit tests: one per error, 100% of functions — SRD §8
- [ ] Fuzz: caps and band math, 1,000 runs per property — SRD §8
- [ ] Invariant: funds leave only to owner or a fair-value swap (issuer seizure excluded) — SRD §8
- [ ] Decimals tests: USDC 6, feed 8, B20 18 and 6 — NFR-5
- [ ] Gas check: buy under 300k with 2 stocks — SRD S5
- [ ] **Freeze the vault interface (Nov 23)** — update API-CONTRACT §2 if anything moved

## P2 — Test contracts, deployment and scenario scripts (Nov 22–25)

Interfaces: API-CONTRACT §3.

- [ ] `tUSDC` (6 dec, deployer-only mint) — §3.1
- [ ] `MockAggregatorV3` with `setAnswer` / `setAnswerAt` — §3.3
- [ ] `StockSwap` with `quote`, `swapExactIn`, `setPrice`, `setPremiumBps` — §3.4
- [ ] `script/Deploy.s.sol`: chain-id guard (84532), `isActivated(B20_ASSET)` guard, tUSDC → tNVDA/tAAPL via factory → feeds → StockSwap → PangoVault — SRD §7 runbook 3
- [ ] `script/Seed.s.sol`: mint, prices, swap = feed — runbook 4
- [ ] Create owner, agent and deployer wallets; fund with Sepolia ETH (agent: gas only) — runbook 2
- [ ] Deploy to base-anvil, then Base Sepolia
- [ ] Verify every contract on sepolia.basescan.org; addresses into README and web/agent config — NFR-9, runbook 6
- [ ] 7 scenario scripts: `SetFair`, `SetPremium(4%)`, `SetWeekend`, `SetFeedDead`, `ScheduleSplit(10)` (moves feed and swap ÷10 at effect), `ResetDay` (anvil only), `SetDrift(tNVDA, +30%)` — SRD §7
- [ ] Run each scenario on Sepolia, record the expected result and tx link

## P3 — Design (Nov 17 – Nov 27, proposed)

Can start now; no code dependency.

- [ ] User flows: owner (connect → configure → deposit → watch → pause/withdraw), judge (open → attack console → receipts), agent loop view
- [ ] Wireframes for each screen: landing / connect, dashboard (FR-W3), mandate form with plain-English hints (FR-W2), portfolio target vs current (FR-W8), research viewer with hash check (FR-W9), chat (FR-W4), attack console with 6 presets (US-13), receipt log (FR-W5), "what is not real yet" panel (NFR-8), mainnet shadow panel (FR-W10, feed-only per D5), compliance notice (NFR-11)
- [ ] Always-visible pause and withdraw for the owner (FR-W6)
- [ ] Test-asset labels on every token, feed and pool (FR-W7)
- [ ] Trenggiling mascot: 5 poses as SVG — walking, peeking, half-curled, curled with error tag, sleeping (SRD §4.4); readable without text (NFR-10)
- [ ] Copy: every error's receipt text (API-CONTRACT §2.4), labels, empty states
- [ ] Design tokens (colour, type, spacing), light and dark, mobile width
- [ ] Review against the 2 min 15 s video script (G3)

## P4 — Slicing: frontend from the design (Nov 25 – Dec 1, proposed)

Static components with mock data first, then wire in P6.

- [ ] Layout shell, navigation, wallet button
- [ ] Dashboard cards: USDC, holdings in shares (`balanceOfUI`, US-05), oracle price, swap price, band, feed age, pending corporate action
- [ ] Mandate form with validation and hints
- [ ] Portfolio view with drift highlight and owner bounds
- [ ] Research viewer
- [ ] Chat panel and attack console
- [ ] Receipt log: time, action, amount, result, error name, plain-English reason, tx link per attempt (US-06)
- [ ] Mascot component driven by a `pose` prop (priority order API-CONTRACT §5)
- [ ] Not-real-yet panel, shadow panel, compliance notice
- [ ] Responsive check at phone width; keyboard and screen-reader pass

## P5 — Agent service (Nov 23–29)

Interfaces: API-CONTRACT §4. Python, FastAPI, web3.py.

- [ ] Config and env (§7): RPC, agent key, DB URL, admin token, builder code, gas budget, CORS origin
- [ ] Log store: attempts table (SQLite local, Postgres hosted via `DATABASE_URL`) — FR-A6, NFR-13
- [ ] Error table: vault ABI + bubbled OZ and B20 errors, receipt texts — FR-A4, §2.4
- [ ] Executor: preflight `eth_call`, chain-id guard 84532, explicit gas limit in proof mode, nonce management, one retry, idempotency key — FR-A4, NFR-7
- [ ] Builder Code suffix on every agent tx (register code with approval, D9) — FR-A10, §6.4
- [ ] Rate limiting per IP and daily gas budget → `simulated` mode — NFR-12
- [ ] Endpoints: `/health`, `/config`, `/chat`, `/news`, `/attacks`, `/attacks/{id}`, `/attempts`, `/attempts/{id}`, `/research/current`, `/research/{hash}/report.json`, `/loop`, `/admin/*` — §4.2
- [ ] LLM proposal step (stock, side, amount, rationale; never decides safety) — FR-A2
- [ ] Fact-check of split / dividend claims from `effectiveAt` / `newUIMultiplier` — FR-A3, US-12
- [ ] 6 attack presets with their scenario setup — US-13
- [ ] Research: signal snapshot, versioned scoring function, LLM thesis, canonical JSON, `setTargets` with hash — FR-A7, US-16, §4.5 *(cut candidate on Nov 28)*
- [ ] Rebalance loop every 5 min, smallest trade set, waits on pending corporate actions — FR-A8, US-17, AT-17
- [ ] Ticker → test-token mapping; mainnet addresses only in the read-only shadow config — FR-A9
- [ ] Optional Tokenized Stocks API client (5 s timeout, `unavailable` on failure) — §6.3
- [ ] Tests: decoder, idempotency, scoring reproducibility, chain-id guard

## P6 — Backend integration (Nov 27 – Dec 1)

- [ ] wagmi config: `baseSepolia`, `baseAccount({ appName, appLogoUrl })`, `injected()` — §5
- [ ] Chain reads every block / 4 s for dashboard, portfolio, mascot — FR-W3, FR-W8, NFR-6
- [ ] Owner writes (mandate, stock config, bounds, tolerance, cooldown, deposit with approve, withdraw, pause/unpause) with decoded errors — FR-W2, FR-W6
- [ ] `dataSuffix` on every owner write; test through Base Account and an injected wallet (D6) — FR-A10
- [ ] Agent API client: config, chat, attacks, attempts polling, research, loop status
- [ ] Research hash check over the raw response bytes vs `researchHash()` — FR-W9, US-19
- [ ] Mascot pose from chain + last attempt — US-14
- [ ] Shadow panel from the mainnet feeds (read-only) — FR-W10

## P7 — Hosting and operations (Nov 29 – Dec 2)

- [ ] Railway: agent service, exactly one instance, one worker, no sleep — NFR-13
- [ ] Railway Postgres; `DATABASE_URL` set
- [ ] Secrets only in Railway env (agent key, LLM key, admin token) — NFR-4
- [ ] Vercel: web app with public env only
- [ ] Agent key funded with Sepolia ETH for the daily gas budget through judging — NFR-12, NFR-13
- [ ] Uptime check through the judging period after Dec 5

## P8 — QA and attack suite (Dec 1–3)

- [ ] Attack suite: at least 20 prompt-injection texts, all 20 blocked by the vault — SRD §8
- [ ] AT-01 Owner configures vault, sets mandate, deposits 500 tUSDC; dashboard shows it (see D2)
- [ ] AT-02 "Buy $20 of tNVDA" with `SetFair` executes; shares via `balanceOfUI`
- [ ] AT-03 Fake split headline + `SetPremium(4%)` → `AboveFairValue` on Basescan
- [ ] AT-04 Same headline → claim labelled "unverified onchain"
- [ ] AT-05 `ScheduleSplit(10)` → `CorporateActionPending`; after effect shares ×10 at same value; raise `maxShares`, buy works
- [ ] AT-06 `SetWeekend` → tighter band; `SetFeedDead` → `StaleOracle`
- [ ] AT-07 `ExceedsShareCap`, `ExceedsPerTradeCap`, `TokenNotAllowed`
- [ ] AT-08 Agent key `withdraw` → `OwnableUnauthorizedAccount`; owner withdraw works while paused
- [ ] AT-09 Pause → `EnforcedPause`, mascot sleeping; unpause restores
- [ ] AT-10 All 6 presets print a receipt line with a working tx link
- [ ] AT-11 Mascot pose matches chain state for each scenario script
- [ ] AT-12 2 min 15 s recording of AT-02, AT-03, AT-15 without cuts
- [ ] AT-13 Bounds 10–40%, tolerance 2%, trigger 5% read back from the vault
- [ ] AT-14 Research report → `setTargets`; hash matches; weights recompute from the snapshot
- [ ] AT-15 `SetDrift(tNVDA, +30%)` → rebalanced within one loop, all weights within 2%
- [ ] AT-16 Poisoned research → `TargetOutOfBounds`; overshooting buy → `OvershootsTarget`
- [ ] AT-17 Rebalance during pending split → `CorporateActionPending`; finishes after effect
- [ ] NFR spot checks: NFR-3 worst case, NFR-6 < 15 s command → tx, NFR-8 labels, NFR-10 every error readable, NFR-11 notices
- [ ] Fresh-browser judge path end to end (SRD §8 end-to-end level)

## P9 — Submission (Dec 3–5)

- [ ] Video script and recording, 2 min 15 s — G3, AT-12
- [ ] README: what it is, deployed addresses, how to run, what is not real yet — NFR-9
- [ ] Repo public, no secrets (scan before release)
- [ ] X post (build-in-public rules from the Telegram groups)
- [ ] Merge `Development` → `main` when Nalen518 approves
- [ ] Submit on the Stocks Maxxing page by Dec 5
- [ ] Keep agent, DB and gas funded during judging
