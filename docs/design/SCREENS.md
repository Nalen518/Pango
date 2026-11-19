# Pango design: screens and data sources

Every label, number and state on a screen maps to a contract view, an agent API field (API-CONTRACT 4) or static copy. Anything without a source is a gap.

## Page map and build order (proposed Nov 19, 2026)

Every app page shares one shell: testnet banner, top bar (logo, tabs, Pause and Withdraw for the owner, "I own this vault" or wallet), main area, and the 360 px Side panel on the right.

| # | Page | What it holds | SRD | Status |
| --- | --- | --- | --- | --- |
| 1 | Landing | Promise, 49 h problem, try it, how it works, not real yet | G3, NFR-8, NFR-11 | Done |
| 2 | Console (default tab for visitors) | "Try to trick it" box, 6 presets, chat with Pango, the newest receipt large | FR-W4, US-13 | Next |
| 3 | Receipt detail | Full paper receipt opened from any stub, with the Basescan link | FR-W5, US-06 | |
| 4 | Overview | Balances in shares, oracle price, swap price, band, price age, pending splits, mainnet shadow panel (49 h feed) | FR-W3, FR-W10, US-05 | |
| 5 | Portfolio | Target vs current weight per stock, drift highlighted, owner bounds, last rebalance | FR-W8, US-17 | |
| 6 | Research | Thesis, per stock baseline / LLM proposal / final weight with sources, "hash matches on chain" and "within band" badges | FR-W9, US-19 | |
| 7 | Limits (owner only) | Mandate form with plain hints: caps, bands, share limits, weight bounds, tolerance, drift trigger, cooldown | FR-W2, US-01, US-15 | |
| 8 | Owner flows | Connect ("I own this vault"), Deposit (Wallet steps), Withdraw, Pause and Unpause confirms | FR-W6, US-02 to US-04 | |
| 9 | States board | Every error, wait and edge case as a card: what happened, what to do next, what happened to my money | Brief step 6 | |
| 10 | Handoff | Map of pages, frames and components with IDs, decision log, build prompt for the coding agent | Brief step 12 | |

Where the first screen list (DD2) went: Dashboard is Overview (4); Mandate form is Limits (7); Chat and Attack console are both in Console (2); Receipt log is the Side panel plus Receipt detail (3); Owner controls live in the top bar and Owner flows (8); Honesty panels are on the Landing, with the shadow panel in Overview (4).

Order follows the 2 min 15 s demo (G3): a normal trade and a blocked attack (Console), then the receipt, then the vault and the drift rebalance (Overview, Portfolio), then the research and owner pages.

## Landing / Desktop 1440 (Figma `31:2`, Screens page)

| Section | Element | Source |
| --- | --- | --- |
| Banner | "Test network. Test money. Nothing here is real." / Visitor line | Static copy; role from connected address vs `owner()` |
| Nav | Pango, How it works, Try it, The proof, I own this vault, Try to trick Pango | Static copy. "I own this vault" opens the wallet connect (wagmi `baseAccount`, `injected`) |
| Hero | Headline and sub line | Static copy from SRD 1 promise |
| Hero | Network chip | Static, chain from `GET /config.chainId` |
| Hero | Four check cards: fair price within 1%, no trading through a split, limits 100 per trade and 250 a day, money leaves only to you | Band from `stockConfig(token).bandBps`; limits from `mandate()`; the other two are static claims backed by the verified contract link |
| Hero | "The vault code is public and verified." | Link to the vault on sepolia.basescan.org (`GET /config.contracts.vault`) |
| Hero | Mascot pose | Live pose from chain state (API-CONTRACT 5); Walking in the design |
| Problem | 49 h, +2.5%, "Nov 13 to 16 weekend" | Static copy from Spike S3 (SPIKES.md), mainnet read only. Source link: the Coinbase NVDA feed address (API-CONTRACT 6.2) on basescan.org |
| Problem | Chart | Static illustration of the S3 data, not live |
| Try it | Attack input | `POST /attacks/freeform`; rate limit from `429 Retry-After` |
| Try it | Four preset cards | `GET /attacks` (label, expectedError); the fifth and sixth live in the app console |
| Try it | Receipt | Latest attempt from `GET /attempts`; sample A2 in the design |
| How it works | Three steps | Static copy |
| Vault map ("Here’s what’s real, and what we made up.") | Vault with the mascot, five drawn parts (test stocks, research, price feed, swap pool, real tokenized stocks), Truth tags (TEST or REAL), issuer callout | Static copy (NFR-8, FR-W7); token names from `GET /config` |
| Closing | Mascot, headline, buttons | Static; "Read the vault code" links to the verified contract |
| Footer | GitHub, Contracts on Basescan, compliance line | Static (NFR-11); contract links from `GET /config` |

Gaps: none on this page. The demo video link target is still to be recorded (G3).

Motion on this page follows MOTION.md: vault map lines draw out from the vault, parts pop in, each tag swings once on its string and settles; headline words rise, the four checks rise in around the mascot, mascot idle breathe, verdict stamp on the receipt when a try finishes, preset cards deal in once.
