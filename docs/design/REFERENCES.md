# Pango design: references

Opened live on Nov 16, 2026 in the browser pane. Values were read from computed styles, not from memory.

## hellonear.xyz (primary, named by the owner)

How it is built
- Warm paper background `#F3F2EE`, ink `#161614`, muted text `#5C5A54`. Lime `#D8F04A` is the only accent. Moss green `#4F7A2A`, with peach and pink tints for cards.
- One family: Geist (sans), weight 500 for headings. H1 44 to 48, H2 48, H3 28, body 14 to 16, labels 11 to 13. Mono appears only twice.
- Containers 1200 and 1440 wide, text columns 420 to 560. Sticky pill nav (white, blurred, radius 999). Dark pill CTA plus a light ghost pill.
- Hero: a full bleed 3D clay mascot rendered into a sky and grass photo, copy left, mascot cropped on the right. Then a logo marquee, a scroll pinned "pick a Mind" card stack, a "Tricked? Still can't spend it" scene with floating glass cards over a 3D render, a numbered three step section and a closing CTA.
- Motion: 150 ms standard ease for hover, 300 ms `cubic-bezier(.23,1,.32,1)` for reveals, one 380 ms overshoot spring. There is a loading splash with the mascot.

Borrow (the idea)
- A mascot carries the emotion, so the copy can stay calm and short.
- A "Tricked? Still can't" section: the attack is shown twice, once stopped by you and once stopped by the rails.
- An approval card that states the amount, the recipient and why it is allowed, before the buttons.
- Plain short copy and one accent colour.

Do not copy (the look)
- The 3D clay mascot in photo scenes, the lime accent, Geist with the warm grey paper and pill everything, the glass cards over grass.
- Why: same category (agent wallet with limits). A judge who has seen it would read Pango as a reskin.

## sharkco.vercel.app (the owner's latest project)

How it is built
- Cool white `#FCFCFD`, ink `#161A22`, grey text `#5A606C`, cobalt `#2B59FF` for CTAs and links. Green `#147A44` and red `#C2362B` are used rarely.
- IBM Plex Mono carries most text (266 nodes). Schibsted Grotesk 800 for the 76 px uppercase H1, 600 for the 40 px H2. A "Patrick Hand" note face appears twice.
- Radius 10 and 22 for cards, pills for chips. A "TESTNET" pill sits in the nav, and "Testnet · test USDC" sits next to the CTA.
- Hero: a blurred headline that resolves, a dotted world map with orbit rings. Then a three card grid with price bands and a "Watch a receipt print" section: a paper receipt prints line by line, each line with proof.
- Motion: mostly 150 ms hovers, plus one scroll driven receipt print.

Borrow (the idea)
- A testnet label in the nav and beside every money CTA.
- The receipt as the core proof object, with one line per step and each line linked to its proof. Pango's receipt log (US-06) is the same idea.
- Price band shown as a range on the card.

Do not copy (the look)
- The mono heavy type, cobalt plus cool white, the uppercase 76 px headline, the printing paper receipt visual.
- Why: Pango should not look like the owner's previous entry reskinned.

## nearhunt.xyz (a gallery: we use it to find projects, not as a design reference)

Close projects found there (NEAR Hackathon 2026): IntentFolio (portfolio manager for tokenized stocks with targets and tolerance bands), Veto (onchain spending firewall for AI agents), Neptune AI (agents that trade and rebalance), Nia (a game where you test an AI agent that handles money), Hermit, NEAR Autopilot. Live web apps for IntentFolio and Neptune AI are taken apart below. Veto, Nia, Hermit and Autopilot only link to X posts, Telegram or GitHub, so they were not opened.

## ethglobal.com/showcase (a gallery as well)

- Light, centred "Find a Project" with a search bar and a three column card grid. Each card has a one line pitch and an event chip.
- Note for Pango: winning entries pitch in one plain line ("USDC escrow on Arc that pays out only when two AI judges agree"). Our landing headline should do the same.

## App layouts (opened live Nov 16, 2026)

### hellonear.xyz: motion and UI detail (studied live Nov 18, 2026; primary reference for UI and motion)

Stack seen: Framer Motion style attributes, Lenis smooth scroll, a canvas scene, a webm demo video. Nine `prefers-reduced-motion` rules switch off clouds, rays, button swipes and smooth scroll.

Motion inventory (keyframes read from the stylesheet):
- Ambient, always on and slow: `cloud-drift` 160 to 190 s (moves 24 px), `rays-breathe` 14 s (opacity .75 to 1, rotate 1.5 deg), logo `marquee` 45 and 55 s in opposite directions, `float-idle` 6 s (up 12 px, rotate 0.6 deg).
- Entrances, once: `word-up` (each headline word rises from 105% under a mask), `rise-in` (24 px up and fade), `fade-in` (6 px), `cta-fly-in` (from 45% right, 4 deg tilt).
- Character: `hand-enter`, `hand-drop` and `hand-hi` use squash and stretch (scale 0.96 by 1.06, then 1.08 by 0.88) with overshoot, so the mascot feels soft and alive.
- Cards: `card-deal` deals cards up from 130% below with a tilt and a 180 deg flip, `face-front` and `face-back` swap the faces halfway. Used for "Pick a Mind" (silver backs flip to reveal each Mind).
- Loader: `ld-pop`, `ld-grow`, `ld-open`, `ld-blink` (eyes blink at 94%), `ld-breathe`, `ld-creep` and `ld-sweep` (progress line). The mascot itself is the loading screen.
- Interaction: buttons change colour over 0.32 s and transform over 0.16 s, both `cubic-bezier(.23,1,.32,1)`. A `::before` swipe fills the button on hover.

UI language:
- Buttons are pills (radius 999), 42 px high, 15 px weight 500, no shadow. Primary is ink, secondary is white at 75%.
- Nav is a floating white pill bar that blurs what is behind it.
- Cards and panels are soft: radius 24 to 32, layered shadows with a white inner top highlight and a long soft drop (`0 24px 60px -28px`), so they feel tactile like clay rather than flat.
- Glass panels (`backdrop-filter: blur(12px) saturate(1.2)`) float over full bleed photo scenes in the "Tricked? Still can't spend it" and approval sections.
- Story order: sky hero with the mascot, logo marquee, card deal "Pick a Mind", a payment approval card over a grass scene, "Tricked? Still can't" (two numbered glass panels: you say no, the wallet says no), a dark "Watch your Mind think" node map, a demo video that grows to full width, three steps, closing CTA.

Gap against our components (built Nov 16): ours use a 2 px ink outline, a hard sticker shadow and radius 12. hellonear uses no outline, soft layered shadows, pills and radius 24 to 32.

### app.hellonear.xyz: entry and onboarding
- Entry is a split screen. Left: a tall photo card with one reassurance line ("Your limits stay yours"). Right: logo, H1 "Meet your Mind.", one line intro, then three stacked choice rows: recommended wallet, other wallets, and "Continue as guest. No sign-up. 20 messages with a shared test wallet."
- Under the choices, two small trust lines with icons: "We never see your keys. Signing in is free." and "Running on NEAR testnet. No real money." Footer: "Nothing here is financial advice."
- Next step: "Choose your first Mind", a stack of choice cards, then a sticky bottom bar with the name input and "Next: start chatting with it" plus Continue.
- The app itself is dark, while the landing page is light.
- Borrow: guest entry as an equal choice, which is our judge path (FR-W1). Trust lines under the buttons say what signing costs and that it's a test network (our web3 rules). A sticky bottom action bar that says what the next step is.
- Do not copy: the photo panel, the dark app skin.
- Not explored further: going past the picker means submitting their form, so it was not done.

### ethglobal showcase, project page and a winning demo (Verdict)
- Project page: a media carousel, then the name, a one line pitch, two pill buttons (Live Demo, Source Code) and a small side card with the event chip. Long description below.
- Verdict's demo is one dark page: a five step "How a verdict moves money" strip (Lock, Evidence, Judge, Sign, Settle), then numbered work panels in a two column grid (1 Open an escrow, 2 Commit evidence, 3 Escrow state, 4 Verify a settlement yourself), then a deployment list of contract addresses. A network chip and Connect wallet sit at the top.
- Borrow: the "how money moves" strip as the explainer above the app. Numbered panels that each do one job. A "verify it yourself" panel. Contract addresses listed openly.
- Do not copy: the dev tool density and dark form wall.

### IntentFolio (intentfolio.app, found on nearhunt): closest prior art
- Same idea space: pick a mix (NVDA, AAPL, AMZN, QQQ), set targets and tolerance bands, the portfolio moves toward them. "You can try IntentFolio without connecting your wallet." "Stocks aren't available in the United States or Canada."
- Landing: dark plum, a huge centred headline, a radial dial with a magenta ring in the middle showing the mix, a preset picker card on the right (Tech Titans, AI Leaders, Balanced...) with "Start with this mix", and the mix weights in a card on the left. Then four numbered "How it works" steps.
- App (/dashboard): a top bar with portfolio tabs ("Funding", "+ New portfolio"), one centred narrow column (about 640 px). A funding card with the balance, Connect Wallet and Withdraw. The empty state is the four numbered steps as clickable rows, ending in "Build my first portfolio".
- Borrow: try before connecting; the empty state doubles as a numbered onboarding; Withdraw sits next to the balance.
- Do not copy: the radial dial hero, the dark plum and magenta, preset mixes as the main story. Why: a judge who saw IntentFolio must see at once that Pango is different. Our story is safety (the vault says no), theirs is earning spread.

### Neptune AI (neptuneai-agent.vercel.app, found on nearhunt)
- A chat app layout: a left sidebar (New conversation; Chat, Wallet, Fleet Status tabs), a centre chat with icon tabs at the top and a full width input at the bottom ("Swap tokens, ask what your agents are doing, or tell them what to do..."). Dark navy, bright blue buttons.
- Every panel is a "Connect wallet" gate: nothing can be tried without a wallet.
- Borrow: the chat input placeholder that teaches what you can ask.
- Avoid: the wallet gate. Judges must reach the console and chat with no wallet (FR-W1).

## Top three memorable references (found on nearhunt, opened live Nov 16, 2026)

The owner judged Neptune AI and Verdict as generic. These three were chosen for craft and for fit with Pango: a character, receipts as proof, money labelled honestly.

### 1. EurekaScout (eurekascout.com): "The AI scout that shows its receipts"
- How it is built: dark slate `#16181E`, cobalt `#4169E1` and mint `#36E2CC` accents. Headings in "Luckiest Guy" uppercase (a chunky display face), body in Inter. A 3D raccoon mascot, Witty, with goggles, sits in the middle of the hero. Around him float small glass cards: "STEP 1 Sealed first, fingerprint on NEAR", "STEP 2 Revealed at 46h", "LIVE Latest seal #430, 15 min ago", "RECORD 411 calls sealed".
- The mascot levels up with his record: Rookie, Analyst, Elite, each a separate render. A "Before you start" modal has numbered plain risk lines, and the mascot peeks over the modal's top edge. Wins and losses are both shown.
- Motion: idle "breathe" 6 s and "float" 5 s loops on the mascot, a 0.45 s "stamp" when a seal lands, 0.15 to 0.2 s hovers.
- Borrow: the mascot as the centre of the proof story, with the steps orbiting him (for Pango: the vault checks circle the trenggiling). A live "latest" chip. The mascot peeking over a modal or card edge. A stamp moment when the vault rules.
- Do not copy: the raccoon, goggles, Luckiest Guy, the dark slate and mint. Why: their mascot is the selling point; ours must be its own animal and voice.

### 2. MEND (mend-demo.vercel.app): "Get it fixed. Keep it fixed."
- How it is built: warm paper `#FFFDF8` and `#FAF7EE`, deep green `#0E4A39`, mint tint `#DCEEE4`. A serif display (Iowan Old Style) with an italic second line, system sans body, monospace for IDs. Small text sizes, 11 to 14 px.
- A full width banner on every screen: "LIVE TESTNET, TEST VALUE ONLY. Connected to the testnet API and hub. Tokens have no real value." with a "Mode and demo role" switch.
- Trust lines under the CTAs: "No wallet needed to report", "EXIF/GPS removed in your browser", "Humans accept the work".
- The case card is the star: an ID in mono, a status chip (Closed), "LIVE API, TESTNET" chip, then a vertical timeline (Completion evidence submitted, Payment released, Accepted by inspector, Durability inspection passed), each with an icon, a UTC time and an ID. Then three money cells: Funded 100.00 USDC, Awarded 80.00 USDC, Holdback 8.00 USDC. Then "Data source: the configured MEND API".
- A hand drawn schematic map, labelled "Schematic, not to scale". A section titled "Every case has a next decision, not a spinner".
- Motion: almost none, 0.16 s ease hovers and one 2.4 s pulse on the live dot.
- Borrow: the testnet banner with a mode switch (Owner or Judge). The receipt as a vertical timeline with times and IDs, ending in money cells (Pango: "Agent proposed, Fact check, Vault check, Executed or Blocked", then "Spent, Shares received, Fair price"). The "data source" line under each card. The rule "every state has a next decision, not a spinner".
- Do not copy: the serif plus green civic look. Why: our paper tone is close, so the brown brand, Bricolage and the sticker outline must carry the difference.

### 3. Priced In (isitpriced.com): "Bet on whether facts are true"
- How it is built: white, Geist and General Sans, a dark ink text colour. Green only for "Yes, it's true", red only for "No, it's false", each a large soft tinted button. A dial gauge shows "40% chance it's true". Easing `cubic-bezier(.22,1,.36,1)` at 0.7 s for reveals, a 1.25 s overshoot on the gauge needle, a 2.2 s ping on live dots.
- "A real correction" card: "Wikipedia says ~~$72.6 billion~~ → This page says now $122.84 billion. Ruled false, 3 signatures, transaction". A stats strip: "42 facts, 10 decided, $8.70 paid out, every bet is a public NEAR transaction".
- Each claim card states "Yes if" and "No if", and how it settles, before any button. "Your first $1 is free: no wallet, no sign up."
- Borrow: the before and after card with a strikethrough (Pango: "The agent wanted to pay $1.04 → The vault allows at most $1.01. Blocked. Transaction"). Green and red with one meaning each, which matches our colour rule. Rules stated before the action ("Blocked if...") and a stats strip with proof.
- Do not copy: the white Geist sportsbook look and the dial gauge.

## Pattern best examples still to collect

Confirm before signing (hellonear's approval card is our best so far), status page, portfolio target versus current. These get added when each screen is designed.
