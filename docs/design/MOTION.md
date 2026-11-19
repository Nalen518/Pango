# Pango design: motion budget

Modelled on hellonear (REFERENCES.md, "motion and UI detail"), with Pango's own moments. Rules:

- Shared tokens only. At most one moving thing per pane at a time. Ambient loops pause while something else in the pane moves.
- No fact lives only in motion. Every state the motion shows is also in text or a chip (the mascot pose has its chip, the verdict has its card).
- `prefers-reduced-motion: reduce` turns every row below into its reduced version. Smooth scroll is off.

## Tokens

| Token | Value | Use |
| --- | --- | --- |
| `ease-out` | `cubic-bezier(.23, 1, .32, 1)` | Default for entrances, hovers, colour |
| `ease-spring` | `cubic-bezier(.34, 1.56, .64, 1)` | Overshoot: stamp, mascot pose change, chip pop |
| `ease-in-out` | `ease-in-out` | Ambient loops only |
| `dur-press` | 160 ms | Button press scale (0.97) |
| `dur-hover` | 320 ms | Colour and fill swipe on hover |
| `dur-stamp` | 450 ms | Verdict stamp, chip pop |
| `dur-enter` | 600 ms | Section and card entrances |
| `dur-pose` | 700 ms | Mascot pose change (squash and stretch) |
| `dur-idle` | 6 s | Mascot breathe or float loop |

## Table

| Element | Where | Trigger | What moves | Timing | Reduced motion |
| --- | --- | --- | --- | --- | --- |
| Headline words | Landing hero, section titles | Enters view, once | Each word rises from 105% under a mask, 40 ms stagger | `dur-enter`, `ease-out` | Words shown at once |
| Mascot idle | Landing hero, side panel | Always, while nothing else moves in the pane | Breathe: up 6 px, scale 1.02, rotate 0.6 deg | `dur-idle`, `ease-in-out`, loop | Still |
| Mascot pose change | Side panel | Chain state changes the pose (API-CONTRACT 5) | Squash 1.06 by 0.94, then the new pose springs in | `dur-pose`, `ease-spring` | Crossfade 150 ms; pose chip updates |
| Mascot loader | First app load | Waiting for first chain read | Trenggiling blinks and curls a little, progress line grows | Until data, line `ease-out` | Static mascot and a text line "Reading the vault" |
| Vault checks orbit | Landing hero | Enters view, once | Four check cards (price, split, limits, owner) rise in around the mascot, 80 ms stagger | `dur-enter`, `ease-out` | Shown at once |
| Verdict stamp | Console, Receipt card header chip | A new attempt finishes | Result chip scales 0.6 to 1 with overshoot; Blocked also nudges the mascot to Curled | `dur-stamp`, `ease-spring` | Chip appears, no scale |
| Receipt print | Console, Receipt detail, Landing "Try it" | A new attempt arrives (`GET /attempts`), or the section scrolls into view on the Landing | Like Shark & Co: the paper slides down out of a slot, then each line drops in one by one, section by section (header, 01 proposal, 02 fact check, 03 vault check, 04 your money). A short pause before 03 builds suspense. The stamp thumps last (`dur-stamp`, `ease-spring`), then the mascot peeks over the scallop edge. Lines that are still waiting on the chain show "printing" with a blinking cursor | Each line 80 ms apart, `ease-out`, 6 px drop; whole receipt about 2.5 s | Whole receipt shown at once, stamp included |
| Receipt stub | Side panel | Steps arrive from `GET /attempts` | New stub slides in at the top, older ones move down | 240 ms, `ease-out` | Stub appears |
| Preset cards | Attack console | Console opens, once | Six cards deal up from below with a small tilt (no flip) | `dur-enter` with 60 ms stagger, `ease-out` | Shown at once |
| Button | Everywhere | Hover, press | Fill swipes left to right; press scales to 0.97 | `dur-hover` and `dur-press`, `ease-out` | Colour change only |
| Logo marquee | Landing | Always | Built with logos scroll | 45 s linear loop | Static row |
| Section scene | Landing "Tricked? Still can't" | Scroll | Scene card grows to full width, glass panels rise in | Scroll linked, `ease-out` | Full width at once |
| Tab switch | App top bar | Click | Brand underline slides to the new tab | 240 ms, `ease-out` | Underline jumps |
