"""Generates the five Pango trenggiling poses (SRD 4.4) as SVG. Run: python make_mascot.py

Style: sticker. Thick ink outline, flat brand fill, ink scale rows, cream face and belly,
big eye with a highlight, blush, a dark batik scarf as the accessory.
Colour says who (brand brown = Pango). Pose shape and badge say the state.
"""
from pathlib import Path

INK, BODY, SKIN, BLUSH, WHITE, PAPER = "#1C1914", "#9A5B34", "#F0D2B0", "#E8907A", "#FFFDF8", "#F5F1E8"
WAIT, BLOCK = "#B7791F", "#B8342A"
W = 6  # outline width in a 200 x 200 box


def shape(d, fill, extra=""):
    return f'<path d="{d}" fill="{fill}" stroke="{INK}" stroke-width="{W}" stroke-linejoin="round" stroke-linecap="round"{extra}/>'


def scaled(pid, d):
    """Brand fill, scale rows and halftone clipped to the shape, outline on top."""
    return (f'<path d="{d}" fill="{BODY}"/>'
            f'<path d="{d}" fill="url(#{pid}-sc)"/>'
            f'<path d="{d}" fill="url(#{pid}-dt)" clip-path="url(#{pid}-low)"/>'
            f'<path d="{d}" fill="none" stroke="{INK}" stroke-width="{W}" stroke-linejoin="round"/>')


def eye(x, y, r=10, look=(2, 1)):
    return (f'<circle cx="{x}" cy="{y}" r="{r}" fill="{WHITE}" stroke="{INK}" stroke-width="5"/>'
            f'<circle cx="{x+look[0]}" cy="{y+look[1]}" r="{r*0.5:.1f}" fill="{INK}"/>'
            f'<circle cx="{x+look[0]+2}" cy="{y+look[1]-2.5}" r="{r*0.2:.1f}" fill="{WHITE}"/>')


def closed_eye(x, y):
    return f'<path d="M{x-6} {y}q6 5 12 0" fill="none" stroke="{INK}" stroke-width="4.5" stroke-linecap="round"/>'


def blush(x, y):
    return f'<ellipse cx="{x}" cy="{y}" rx="6" ry="3.5" fill="{BLUSH}"/>'


def badge(x, y, fill, glyph):
    return f'<circle cx="{x}" cy="{y}" r="20" fill="{fill}" stroke="{INK}" stroke-width="{W}"/>{glyph}'


def svg(pid, title, body, low_y=120):
    defs = (f'<defs>'
            f'<pattern id="{pid}-sc" width="24" height="16" patternUnits="userSpaceOnUse">'
            f'<path d="M0 8Q12-6 24 8M-12 16Q0 2 12 16M12 16Q24 2 36 16" fill="none" stroke="{INK}" stroke-width="3" stroke-opacity=".55"/></pattern>'
            f'<pattern id="{pid}-dt" width="7" height="7" patternUnits="userSpaceOnUse">'
            f'<circle cx="3.5" cy="3.5" r="1.6" fill="{INK}" fill-opacity=".45"/></pattern>'
            f'<clipPath id="{pid}-low"><rect x="0" y="{low_y}" width="200" height="200"/></clipPath>'
            f'</defs>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200" role="img">'
            f'<title>{title}</title>{defs}{body}</svg>\n')


def scarf(x, y, w=26, rot=0):
    """Dark batik scarf: band plus a knot tail, cream dots."""
    return (f'<g transform="rotate({rot} {x} {y})">'
            + shape(f"M{x-w/2} {y-5}H{x+w/2}V{y+5}H{x-w/2}Z", INK)
            + shape(f"M{x-4} {y+4}L{x-10} {y+20}L{x+2} {y+16}Z", INK)
            + "".join(f'<circle cx="{x-w/2+5+i*8}" cy="{y}" r="1.8" fill="{PAPER}"/>' for i in range(int(w // 8)))
            + "</g>")


POSES = {}

# Walking: side view, facing right, legs down. Price fresh, nothing pending, not paused.
POSES["walking"] = svg("wk", "Pango is walking: price fresh, nothing pending, not paused",
    scaled("wk", "M62 128C40 134 22 150 10 172C30 172 48 162 66 150Z")
    + shape("M70 140V170Q70 176 76 176H90Q94 176 92 170L90 140Z", SKIN)
    + shape("M134 140V170Q134 176 140 176H154Q158 176 156 170L154 140Z", SKIN)
    + scaled("wk", "M50 154C44 98 82 62 122 64C154 66 172 94 170 128C170 142 166 154 160 154Z")
    + shape("M148 88C178 84 194 106 198 128C184 140 162 138 150 134Z", SKIN)
    + scarf(150, 124, w=34, rot=-78)
    + eye(172, 106, r=11) + blush(184, 122)
    + f'<circle cx="196" cy="127" r="3.5" fill="{INK}"/>'
    + f'<path d="M178 130q6 5 12 0" fill="none" stroke="{INK}" stroke-width="4" stroke-linecap="round"/>',
    low_y=128)

# Peeking: up on hind legs, looking out. Price is old, tighter band in force. Amber clock badge.
POSES["peeking"] = svg("pk", "Pango is peeking: the price is old, a tighter limit applies",
    scaled("pk", "M94 158C70 166 44 172 18 178C44 184 80 184 106 176Z")
    + scaled("pk", "M72 182C56 142 58 94 84 66C102 48 126 54 134 80C142 108 138 150 126 182Z")
    + shape("M118 84C130 108 132 150 124 182H108C116 150 116 112 108 90Z", SKIN)
    + shape("M86 76C98 48 128 34 160 36C152 58 130 76 110 84Z", SKIN)
    + scarf(110, 96, w=40, rot=-12)
    + shape("M124 108Q140 106 142 118Q132 124 122 120Z", SKIN)
    + eye(114, 58, r=11, look=(3, -1)) + blush(128, 70)
    + f'<circle cx="158" cy="37" r="3.5" fill="{INK}"/>'
    + badge(38, 40, WAIT, f'<path d="M38 28V40L47 46" fill="none" stroke="{PAPER}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>'),
    low_y=140)

# Half-curled: C shape, head tucked in the gap, worried look. A split is scheduled. Amber divide badge.
RING = "M159.75 94.92A66 66 0 1 0 142.67 158.67L114.38 130.38A26 26 0 1 1 121.11 105.27Z"
POSES["half-curled"] = svg("hc", "Pango is half curled: a stock split is scheduled, trading waits",
    shape("M118 112C138 114 156 126 168 146C152 152 132 146 116 132Z", SKIN)
    + eye(134, 122, r=9, look=(-2, -2)) + blush(146, 136)
    + f'<circle cx="167" cy="145" r="3.5" fill="{INK}"/>'
    + scaled("hc", RING)
    + badge(166, 38, WAIT, f'<path d="M155 38H177" stroke="{PAPER}" stroke-width="5" stroke-linecap="round"/>'
            f'<circle cx="166" cy="29" r="3.2" fill="{PAPER}"/><circle cx="166" cy="47" r="3.2" fill="{PAPER}"/>'),
    low_y=130)

# Curled: full ball, fully hidden. The vault blocked the last attempt. Red tag; the error name is text next to the art.
POSES["curled"] = svg("cu", "Pango is curled up: the vault blocked the last attempt",
    scaled("cu", "M30 112A66 66 0 1 0 162 112A66 66 0 1 0 30 112Z")
    + f'<path d="M96 112m-24 0a24 24 0 1 1 24 24" fill="none" stroke="{INK}" stroke-width="{W}" stroke-linecap="round"/>'
    + f'<path d="M142 64L156 44" stroke="{INK}" stroke-width="4"/>'
    + shape("M150 16H188Q194 16 194 22V46Q194 52 188 52H150L140 34Z", BLOCK)
    + f'<path d="M169 24V36" stroke="{PAPER}" stroke-width="5" stroke-linecap="round"/><circle cx="169" cy="44" r="3" fill="{PAPER}"/>',
    low_y=130)

# Sleeping: lying flat, head on the ground, eyes shut. The owner paused the agent.
POSES["sleeping"] = svg("sl", "Pango is asleep: the owner paused the agent",
    scaled("sl", "M44 168C24 172 10 164 12 150C22 158 34 160 48 156Z")
    + scaled("sl", "M22 180C26 140 68 116 114 118C150 120 172 142 174 180Z")
    + shape("M156 152C176 150 192 162 198 180H154Z", SKIN)
    + scarf(158, 164, w=22, rot=-60)
    + closed_eye(176, 162) + blush(186, 170)
    + f'<path d="M126 72H142L126 92H142M152 46H162L152 58H162" fill="none" stroke="{INK}" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>',
    low_y=150)

if __name__ == "__main__":
    here = Path(__file__).resolve().parents[3] / "web" / "public" / "mascot"  # served by the app
    for name, s in POSES.items():
        (here / f"{name}.svg").write_text(s, encoding="utf-8")
    assert len(POSES) == 5 and all(s.count("<svg") == 1 for s in POSES.values())
    print("wrote", ", ".join(POSES))
