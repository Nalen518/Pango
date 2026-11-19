"""Pango's own marks, drawn in the mascot's style (ink outline, scale plates). Run: python make_marks.py

Replaces stock tick, cross, clock and arrow icons. Shape says the state (works in grayscale);
colour follows the token jobs: brown = Pango, green = money moved, red = vault refused,
amber = waiting on time, blue = proof.
"""
from pathlib import Path

INK, BROWN, BROWN_L, SKIN = "#1C1914", "#9A5B34", "#D9A57E", "#F0D2B0"
GREEN, RED, AMBER, BLUE, PAPER = "#1E7A4A", "#B8342A", "#B7791F", "#0052FF", "#FFFDF8"
SW = 'stroke="%s" stroke-width="2" stroke-linejoin="round" stroke-linecap="round"' % INK
SCALE = "M4 5.5Q12 1.5 20 5.5Q20.5 14.5 12 21.5Q3.5 14.5 4 5.5Z"  # one pangolin scale plate, point down


def svg(title, body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" role="img">'
            f'<title>{title}</title>{body}</svg>\n')


MARKS = {
    # a step passed: one scale plate, closed and in place
    "passed": svg("Passed", f'<path d="{SCALE}" fill="{BROWN_L}" {SW}/><path d="M8 8.5Q12 6.5 16 8.5" fill="none" {SW}/>'),
    # a step still to come: an empty scale outline
    "open": svg("Not yet", f'<path d="{SCALE}" fill="{PAPER}" {SW} stroke-dasharray="3 2.5"/>'),
    # the vault refused: a tiny curled pangolin, tail spiral inside
    "blocked": svg("Blocked by the vault", f'<circle cx="12" cy="12" r="9" fill="{RED}" {SW}/><path d="M12 12m-4 0a4 4 0 1 1 4 4" fill="none" stroke="{PAPER}" stroke-width="2" stroke-linecap="round"/>'),
    # waiting on time: half curled, a C with the snout tucked in
    "waiting": svg("Waiting", f'<path d="M19.4 9A9 9 0 1 0 18.4 18.4L14.8 14.8A4 4 0 1 1 15.4 10.6Z" fill="{AMBER}" {SW}/><circle cx="18.2" cy="13.6" r="1.6" fill="{INK}"/>'),
    # money moved: two scales stacked like coins
    "moved": svg("Money moved", f'<path d="M3 8Q9.5 4.5 16 8Q16.4 15 9.5 20.5Q2.6 15 3 8Z" fill="{GREEN}" {SW}/><path d="M9 6Q15 3 21 6Q21.4 12.5 15 17.5" fill="none" {SW}/>'),
    # proof: a pangolin footprint, tracks on chain
    "proof": svg("Proof on chain", f'<ellipse cx="12" cy="15.5" rx="5" ry="4.5" fill="{BLUE}" {SW}/>'
                 f'<path d="M7.5 9.5L6 5.5M12 8.5V4M16.5 9.5L18 5.5" fill="none" stroke="{BLUE}" stroke-width="2.4" stroke-linecap="round"/>'),
    # on its way: three paw dots walking up and right
    "sending": svg("Sending", f'<circle cx="5.5" cy="17.5" r="2.3" fill="{AMBER}" {SW}/><circle cx="12" cy="12" r="2.3" fill="{AMBER}" {SW}/><circle cx="18.5" cy="6.5" r="2.3" fill="{PAPER}" {SW}/>'),
    # we could not read it: a scale with a question mark
    "unknown": svg("Unknown", f'<path d="{SCALE}" fill="{PAPER}" {SW}/><path d="M9.6 9.2Q9.8 6.8 12 6.8Q14.4 6.8 14.3 9Q14.2 10.6 12 11.4V12.8" fill="none" {SW}/><circle cx="12" cy="16" r="1.2" fill="{INK}"/>'),
    # checked only, nothing sent: a scale with a dot, like a test print
    "checked": svg("Checked, not sent", f'<path d="{SCALE}" fill="{PAPER}" {SW}/><circle cx="12" cy="11" r="2.6" fill="{INK}"/>'),
    # role: the trenggiling's snout in profile
    "pango": svg("Pango", f'<path d="M3 15Q3 7 11 6Q17 5.5 21.5 13.5Q16 16.5 11 16.5Q6 17 3 15Z" fill="{SKIN}" {SW}/><circle cx="11" cy="11" r="1.6" fill="{INK}"/><circle cx="21" cy="13.4" r="1" fill="{INK}"/>'),
    # owner: a key with a scale for its bow
    "owner": svg("Owner", f'<path d="M3 9Q8 6.5 13 9Q13.3 14.5 8 18Q2.7 14.5 3 9Z" fill="{BROWN}" {SW}/><path d="M13 12H21M18 12V15M21 12V14.5" fill="none" {SW}/>'),
    # paused: two scales standing, the agent is asleep
    "paused": svg("Paused", f'<path d="M5 4H10V20H5Z" fill="{BROWN_L}" {SW}/><path d="M14 4H19V20H14Z" fill="{BROWN_L}" {SW}/>'),
}

if __name__ == "__main__":
    out = Path(__file__).resolve().parents[3] / "web" / "public" / "marks"
    out.mkdir(parents=True, exist_ok=True)
    for name, s in MARKS.items():
        (out / f"{name}.svg").write_text(s, encoding="utf-8")
    assert all(s.count("<svg") == 1 for s in MARKS.values())
    rows = "".join(
        f"<div style='display:flex;gap:28px;align-items:center;margin:0 0 18px;{g}'>"
        + "".join(f"<figure style='margin:0;text-align:center;width:84px'><img src='/web/public/marks/{n}.svg' width='{sz}'><figcaption style='font:12px sans-serif'>{n}</figcaption></figure>" for n in MARKS)
        + "</div>"
        for sz in (48, 24, 16) for g in ("", "filter:grayscale(1)"))
    (Path(__file__).parent / "preview.html").write_text(
        f"<!doctype html><meta charset=utf-8><body style='background:#F5F1E8;margin:24px'>{rows}</body>", encoding="utf-8")
    print("wrote", len(MARKS), "marks")
