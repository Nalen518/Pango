# Pango design: decision log

Owner: Nalen518. Figma file: Base-Stock (`9QhCVAk2PjlGV9T8XXsqpi`). One entry per decision the owner made, with why and what it costs.

| # | Date | Decision | Why | Cost |
| --- | --- | --- | --- | --- |
| DD1 | Nov 16, 2026 | Build order: foundations and tokens page, then components page, then screens one at a time | Every screen uses only tokens and components, so screens stay consistent | No screen to look at until the foundations and components are done |
| DD2 | Nov 16, 2026 | Screen list, in order: Landing and connect, Dashboard (FR-W3), Mandate form (FR-W2), Portfolio (FR-W8), Research viewer (FR-W9), Chat (FR-W4), Attack console (US-13), Receipt log (FR-W5), Owner controls (FR-W6), Honesty panels (NFR-8, FR-W10, NFR-11) | Matches SRD and checklist P3 | Full list, so it takes longer than a demo path only pass |
| DD3 | Nov 16, 2026 | Screens are designed and shown one by one, kept neat. Judges see the built app, not Figma | Figma serves the builder, not the judges | App layout (one screen or several pages) is still open, see Open |
| DD4 | Nov 16, 2026 | Visual direction: borrow ideas from hellonear.xyz (primary) and sharkco.vercel.app, with Pango's own look | Low look alike risk and a distinct entry | More design time than copying a look |
| DD5 | Nov 16, 2026 | Copy: plain English, one idea per sentence, no hyphens or dashes | Owner's style | API terms like "per-trade cap" need rewording on screen. Exceptions are still open, see Open |

| DD6 | Nov 16, 2026 | Direction "Burrow": paper `#F5F1E8`, ink `#1C1914`, brand scale `#9A5B34`, moved `#1E7A4A`, blocked `#B8342A`, waiting `#B7791F`, proof link `#0052FF`. Bricolage Grotesque headings, Inter body, JetBrains Mono numbers. Radius 6, 12, 20, pill chips. Flat 2D trenggiling | Own look, warm and calm, far from hellonear's lime and 3D clay and from sharkco's cobalt and mono | The mascot must be drawn as vectors |
| DD7 | Nov 16, 2026 | Light theme only, desktop only for now | Focus | Phone and dark mode are later work; a phone visitor gets an unchecked layout |
| DD8 | Nov 16, 2026 | Mascot: draw the five poses as local SVG files first, then bring them into Figma | Owner wants the art settled before Figma design | Figma components wait for the SVGs |
| DD9 | Nov 16, 2026 | Mascot style: sticker, like the owner's sharkco shark. Thick ink outline, flat brand fill, ink scale rows, halftone dots, big eye with a highlight, blush, a dark batik scarf as the accessory. Not hellonear's 3D clay | Flat first pass was too plain; 3D clay cannot be drawn as SVG and would look like hellonear | Outline style also sets the icon style for the rest of the UI |
| DD10 | Nov 16, 2026 | The SVG poses are the foundation. In Figma the mascot gets a soft 3D finish on top of the same shapes: gradient fills, inner shadows, highlights, a ground shadow | Owner wants the depth and charm of hellonear without 3D software | The app needs the Figma export (SVG with gradients or PNG), not the flat SVG. Some look alike risk with hellonear's clay; kept low by the outline, scale rows, palette and our own silhouettes |

| DD11 | Nov 16, 2026 | Design references: hellonear (primary), plus EurekaScout (mascot at the centre of the proof story), MEND (testnet banner, receipt timeline with money cells, "next decision, not a spinner"), Priced In (before and after verdict card, one meaning per colour, rules before the action). nearhunt and ethglobal are galleries, not references. Neptune AI and Verdict dropped as generic. IntentFolio is prior art to look different from | Owner judged these the most memorable and closest to Pango | Each borrow must be checked against the "do not copy" list in REFERENCES.md |

| DD12 | Nov 16, 2026 | App layout: landing, then one app shell. Testnet banner with an Owner / Judge switch on top; top bar with logo, tabs (Console default for judges, Overview, Portfolio, Research, Limits), Pause, Withdraw, wallet; a side panel on every tab with the mascot, vault state and live receipt timelines | Mascot and the vault's answer never leave the screen; simple video; looks unlike IntentFolio and Neptune | Each tab needs its own design; the side panel takes about 360 px of the 1440 px desktop |

| DD13 | Nov 16, 2026 | Copy: receipt texts reworded to follow the rule (API-CONTRACT 2.4 and SRD 5 updated: "Over your limit for one trade", split and cooldown texts split into two sentences). Token names, contract error names and code identifiers are exempt | Keeps the rule checkable without renaming FR-W7 tokens | One shared doc edit; the agent must use the new texts |
| DD14 | Nov 16, 2026 | Role is a read-only chip: "Viewing as judge" until the wallet that is `owner()` connects, then "Owner". Pause, Withdraw and Limits show only for the owner | Role comes from chain, not from a toggle; a judge cannot sign owner actions | Judges see owner controls only in the video |
| DD15 | Nov 16, 2026 | Non-verdict colour: Pause, Withdraw, Deposit are ink buttons. Form mistakes and server or network errors use ink text with their own icon, never red. Red stays "vault refused", green stays "trade executed", each status chip also gets its own icon | Keeps one job per colour; green 600 and red 600 are close in grayscale, so icons carry the difference | Form errors are less loud |

| DD16 | Nov 18, 2026 | hellonear is the lead reference for UI and motion; EurekaScout, MEND and Priced In support it. UI moves to hellonear's language: pill buttons, no outlines on cards, soft clay shadows with a white inner highlight, radius 8, 16, 28 and pill, 1 px hairlines, glass panels over scenes. Motion follows hellonear (MOTION.md). Pango identity stays: Burrow palette, Bricolage and Inter, brown brand, the trenggiling | Owner wants hellonear's feel | Medium look alike risk, carried by colour, type and the mascot. Replaces the sticker shadow; mascot keeps its outline as character art |

| DD17 | Nov 18, 2026 | Pango's own marks replace stock icons (tick, cross, clock, arrow, person): passed (scale plate), open, blocked (tiny curled pangolin), waiting (half curl), moved (stacked scales), proof (footprint), sending (paw dots), unknown, checked, pango (snout), owner (key with scale bow), paused. Receipt timeline is a trail of scales, not a green checklist. Source: `docs/design/marks/make_marks.py`; Figma Mark set `19:119` | Owner found the stock ticks and green checklist generic | 12 marks to keep in sync between SVG files and Figma. The network chip keeps a plain live dot |
| DD18 | Nov 18, 2026 | Own entry, no copied guest screen: the landing button "Try to trick Pango" goes straight to the console; the owner connects with a quiet "I own this vault" button in the top bar. Roles are Visitor and Owner (replaces DD14's "Viewing as judge") | Owner found the guest entry copied and generated sounding | Owners must find the small button; the video shows it |
| DD19 | Nov 18, 2026 | Copy rewritten shorter: banner "Test network. Test money. Nothing here is real.", Visitor and Owner lines, helper lines ("One try every 30 s.", "Pango is asleep. The owner paused it.", "Next try in 24 s."), Next lines ("Nothing to do.", "Nothing moved. Try another trick.", "About 10 s.", "Pango retries once.") | Owner judged the earlier lines AI sounding | Fewer explanations on screen; the "what is not real yet" panel carries the detail |

| DD20 | Nov 19, 2026 | Receipts are a Pango paper slip (owner's own Shark & Co idea, made Pango's): 360 px warm paper, numbered sections (proposal, fact check, vault check, your money) with dotted rules, a rubber stamp for the result, a pangolin scale scallop tear, the mascot peeking over the edge. Wallet steps are boxless: a two step trail with marks, then plain lines and the button. Old boxed sets moved to the Archive page | Owner found the boxed cards template like; a receipt is the object the SRD describes and fits the 360 px side panel | Some likeness to the owner's own Shark & Co; different paper, edge, stamp and mascot keep it Pango's |

| DD21 | Nov 20, 2026 | Landing "What is not real yet" list replaced by a vault map: the vault with the mascot in the middle, drawn parts linked by brown dotted lines, each wearing a Truth tag (TEST in an amber stamp outline, REAL in ink), and a callout for the issuer freeze rule. Truth tag component `39:1170`, section `41:507`; old list on the Archive page. Receipt prints line by line on the frontend (MOTION.md) | Owner found the list plain next to hellonear; the map shows what is real and how Pango is built in one picture | One more illustrated section to keep in sync with the system if parts change |

## Copy rules (checkable)

1. Plain English, one idea per sentence. No semicolons.
2. No hyphens or dashes in copy. Exempt: token names (FR-W7), contract error names, code identifiers, addresses and hashes.
3. Every money amount names its unit and says it is test money where space allows: "20.00 tUSDC".
4. Every result card answers three things: what happened, what to do next, what happened to my money.
5. Every wallet step says what is signed, what it costs ("test gas only"), and whether money moves. A free signature says it is free.
6. Made up names only in examples (sample addresses, "Rina").

## Built in Figma (Nov 16, 2026)

- Pages: Foundations, Components, Mascot, Screens, Archive.
- Variables: Primitives (21, hidden), Color (23 semantic aliases, scoped, each with its one job in the description), Spacing (8), Radius (4 plus border width). Web code syntax `var(--…)` on all.
- Text styles (12, smallest 12 px): Display, Heading H1 to H3 (Bricolage Grotesque), Body and Label (Inter), Number (JetBrains Mono).
- Effect styles: Shadow/Sticker (0, 3) and Shadow/Sticker Raised (0, 5), hard ink shadows. Proposed by the designer to match the outlined mascot; owner has not ruled on it yet.
- Mascot page, five frames: Walking, Peeking, Half curled, Curled, Sleeping (`/ 3D`). SVG shapes plus 40 to 70 scale plates each, with gradients and inner shadows, clipped to the body, a highlight, a ground shadow, and badges with the same depth.
- Mascot component set (`11:7`), property Pose = Walking, Peeking, Half curled, Curled, Sleeping. Transparent background, 640 px master, scale the instance (48 px minimum). Description carries the chain source and the pose priority. Review frame `11:8` shows every pose at 160 and 48 px.
- Components page: Button `13:35` (Style Primary, Secondary, Ghost x State Default, Hover, Disabled, Loading), Chip `13:79` (11 kinds, each status with its own icon), Attack input `13:132` (Empty, Filled, Focus, Disabled, Rate limited), Tab `13:139`, Testnet banner `13:160` (Role Judge, Owner), Money cell `13:184` (Default, Loading, No data, Cannot reach chain), Receipt `25:1168` (paper; Executed, Blocked, Checked only, Sending, Dropped, Unknown error; Show mascot toggle), Wallet steps `26:973` (boxless trail; Approve ready, Approve waiting, Deposit ready, Deposit waiting, Deposited, Rejected). Earlier boxed versions are on the Archive page.
- Components added Nov 19: Receipt stub `29:656` (one line per attempt for the side panel, 6 results, no truncation), Attack preset `29:697` (Default, Hover, Running, Done; text properties Number, Title, Trick, Expect; states the expected vault answer before you press), Side panel `30:1387` (360 x 900 sunken column; Walking, Peeking, Half curled, Curled, Sleeping, Loading, Cannot reach chain; mascot pose plus a caption that says the state in words, vault rows, latest receipt stubs). All fills, strokes, radii, padding and gaps bound to variables; text uses the 12 styles.
- Grayscale check passed: chips differ by icon, mascot poses differ by shape at 48 px.
- Known exception: the mascot's 3D gradients use raw hex shades of the brand colours, not tokens. Logged, not fixed: gradients need stops that tokens do not model.

## Open (asked, not yet decided)

- App layout: one app screen with panes, tabs, or separate pages. Needed before the nav and shell components.
- No hyphens rule versus fixed names: FR-W7 token name "Pango Test NVDA — not NVIDIA stock", contract error names, code identifiers. Proposed: these are exempt, all other copy follows the rule.
