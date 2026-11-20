"""Draws the library's floor plan (task 109) as SVG, in metres. Run as
`python3 plan.py OUT_DIR`: plan-1 and plan-2, each clean and with labels.

x runs along the window wall, 0..9, the stove's end at x=0; y runs from the hall
wall (0) to the window wall (7). Facing x=0 from the room, the windows are on the
left, as in style-01.
"""
import sys

W, D = 9.0, 7.0
OUT, HALL, END = 0.8, 0.6, 0.5          # wall thicknesses
WIN_X = (1.5, 4.5, 7.5)                 # window centres
WIN_W, NICHE_W = 1.1, 1.3

INK = "#3b2f25"
WALL = "#8a8079"
FLOOR = "#efe4cf"
WOOD = "#7a4a2a"
GREEN = "#8c9a76"
GOLD = "#c9a23a"
STOVE = "#cfdcc4"
RUG = "#b9786a"


def rect(x, y, w, h, fill, stroke=INK, sw=0.02, extra=""):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{fill}" '
            f'stroke="{stroke}" stroke-width="{sw}" {extra}/>')


def line(x1, y1, x2, y2, sw=0.02, color=INK, extra=""):
    return (f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" '
            f'stroke-width="{sw}" {extra}/>')


def text(x, y, s, size=0.22, anchor="middle"):
    return (f'<text x="{x}" y="{y}" font-family="Georgia, serif" font-size="{size}" '
            f'fill="{INK}" text-anchor="{anchor}">{s}</text>')


def door_h(cx, w, y_face, into):
    """A double door in a horizontal wall; leaves swing into the room (into=+1/-1)."""
    out = []
    half = w / 2
    for hinge, sgn in ((cx - half, 1), (cx + half, -1)):
        tip_x, tip_y = hinge, y_face + into * half
        out.append(line(hinge, y_face, tip_x, tip_y, 0.035))
        end_x = hinge + sgn * half
        sweep = 0 if (sgn * into) > 0 else 1
        out.append(f'<path d="M {tip_x} {tip_y} A {half} {half} 0 0 {sweep} {end_x} {y_face}" '
                   f'fill="none" stroke="{INK}" stroke-width="0.012" stroke-dasharray="0.06 0.04"/>')
    return out


def door_v(cy, w, x_face, into):
    """A double door in a vertical wall; leaves swing into the room."""
    out = []
    half = w / 2
    for hinge, sgn in ((cy - half, 1), (cy + half, -1)):
        tip_x, tip_y = x_face + into * half, hinge
        out.append(line(x_face, hinge, tip_x, tip_y, 0.035))
        end_y = hinge + sgn * half
        sweep = 0 if (sgn * into) > 0 else 1
        out.append(f'<path d="M {tip_x} {tip_y} A {half} {half} 0 0 {sweep} {x_face} {end_y}" '
                   f'fill="none" stroke="{INK}" stroke-width="0.012" stroke-dasharray="0.06 0.04"/>')
    return out


def bookcase(x, y, w, h, glazed=False, label=None):
    out = [rect(x, y, w, h, WOOD)]
    # shelves seen from above: a line along the books' fronts
    if w > h:
        fy = y + h - 0.08 if y < 1 else y + 0.08
        out.append(line(x + 0.05, fy, x + w - 0.05, fy, 0.015, "#e8d9b8"))
    else:
        fx = x + 0.08 if x > 4 else x + w - 0.08
        out.append(line(fx, y + 0.05, fx, y + h - 0.05, 0.015, "#e8d9b8"))
    if glazed:
        if w > h:
            out.append(line(x, y + h + 0.03, x + w, y + h + 0.03, 0.012, INK, 'stroke-dasharray="0.05 0.03"'))
        else:
            out.append(line(x + w + 0.03, y, x + w + 0.03, y + h, 0.012, INK, 'stroke-dasharray="0.05 0.03"'))
    return out


def chair(cx, cy, facing, color=GREEN, s=0.5):
    """A chair centred at (cx, cy); facing is the direction the sitter looks: 'n','s','e','w'."""
    h = s / 2
    out = [f'<rect x="{cx-h}" y="{cy-h}" width="{s}" height="{s}" rx="0.07" fill="{color}" stroke="{INK}" stroke-width="0.018"/>']
    back = {"n": (cx - h, cy + h - 0.1, s, 0.1), "s": (cx - h, cy - h, s, 0.1),
            "e": (cx - h, cy - h, 0.1, s), "w": (cx + h - 0.1, cy - h, 0.1, s)}[facing]
    out.append(rect(*back, WOOD, INK, 0.015))
    return out


def plant(cx, cy, r=0.17):
    return [f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="#6f8a55" stroke="{INK}" stroke-width="0.012"/>',
            f'<circle cx="{cx}" cy="{cy}" r="{r*0.45}" fill="#8fa86e"/>']


def painting(x1, y1, x2, y2):
    return [line(x1, y1, x2, y2, 0.07, GOLD)]


def plan(variant, labels):
    s = []
    s.append(rect(-1.6, -1.6, W + 3.2, D + 3.6, "#f6efe1", "none", 0))
    # floor with a faint herringbone hint
    s.append('<defs><pattern id="hb" width="0.6" height="0.6" patternUnits="userSpaceOnUse">'
             '<path d="M0 0.3 L0.3 0 M0.3 0.6 L0.6 0.3 M0.3 0 L0.6 0.3 M0 0.3 L0.3 0.6" '
             'stroke="#ddcfb2" stroke-width="0.015" fill="none"/></pattern></defs>')
    s.append(rect(0, 0, W, D, FLOOR, "none", 0))
    s.append(rect(0, 0, W, D, "url(#hb)", "none", 0))
    # walls
    s.append(rect(-END, -HALL, W + 2 * END, HALL, WALL, INK, 0.03))
    s.append(rect(-END, D, W + 2 * END, OUT, WALL, INK, 0.03))
    s.append(rect(-END, -HALL, END, D + HALL + OUT, WALL, INK, 0.03))
    s.append(rect(W, -HALL, END, D + HALL + OUT, WALL, INK, 0.03))
    # windows: niches with straight reveals, the casement near the outer face
    for cx in WIN_X:
        gy = D + OUT - 0.22
        pts = [(cx - NICHE_W / 2, D), (cx + NICHE_W / 2, D), (cx + NICHE_W / 2, gy), (cx - NICHE_W / 2, gy)]
        s.append('<polygon points="%s" fill="#f7f3ea" stroke="%s" stroke-width="0.02"/>' %
                 (" ".join(f"{x},{y}" for x, y in pts), INK))
        s.append(rect(cx - WIN_W / 2, gy, WIN_W, 0.22, "#f7f3ea", INK, 0.02))
        for dy in (0.04, 0.1, 0.16):
            s.append(line(cx - WIN_W / 2, gy + dy, cx + WIN_W / 2, gy + dy, 0.012, "#5d7f99"))
        # shutters folded flat against the reveals
        for sx in (-1, 1):
            s.append(line(cx + sx * (NICHE_W / 2 - 0.04), D + 0.06, cx + sx * (NICHE_W / 2 - 0.04), gy - 0.06, 0.05, "#d9d2c4"))
        # sill plants
        s += plant(cx + 0.35, D + 0.3, 0.13)
    # hall door, middle of the hall wall
    s.append(rect(4.5 - 0.7, -HALL - 0.01, 1.4, HALL + 0.02, FLOOR, "none", 0))
    s += door_h(4.5, 1.4, 0.0, 1)
    # stove in the corner by the hall wall, fed from the hall through the wall
    s.append('<polygon points="0.05,0.05 1.15,0.05 1.15,0.75 0.75,1.15 0.05,1.15" fill="%s" stroke="%s" stroke-width="0.03"/>' % (STOVE, INK))
    s.append('<polygon points="0.2,0.2 1.0,0.2 1.0,0.68 0.68,1.0 0.2,1.0" fill="none" stroke="%s" stroke-width="0.012"/>' % INK)
    s.append(rect(0.4, -HALL, 0.35, HALL, "#5a514b", INK, 0.015))  # firing hole from the hall
    # door to the next room, in the stove's end wall, near the hall side
    s.append(rect(-END - 0.01, 1.65, END + 0.02, 1.3, FLOOR, "none", 0))
    s += door_v(2.3, 1.3, 0.0, 1)
    if variant == 1:
        s.append(rect(W - 0.01, 1.65, END + 0.02, 1.3, FLOOR, "none", 0))
        s += door_v(2.3, 1.3, W, -1)
    # glazed bookcase on the stove's end wall, the window side of the door
    s += bookcase(0.0, 3.6, 0.5, 1.8, glazed=True)
    s += painting(0.02, 3.0, 0.02, 3.4)
    # low open bookcases either side of the hall door
    s += bookcase(2.3, 0.0, 1.3, 0.4)
    s += bookcase(5.4, 0.0, 1.3, 0.4)
    # sofa under a large painting on the hall wall, toward the far end
    s += painting(6.95, 0.02, 8.75, 0.02)
    s.append(rect(6.85, 0.05, 2.0, 0.85, GREEN, INK, 0.02, 'rx="0.1"'))
    s.append(rect(6.85, 0.05, 2.0, 0.22, "#76835f", INK, 0.015))
    if variant == 2:
        # open bookcases up to the ceiling along the far end wall, a ladder on a rail
        s += bookcase(W - 0.42, 1.2, 0.42, 3.8)
        s.append(rect(W - 0.75, 2.2, 0.3, 0.55, "none", WOOD, 0.03))
    # the round table by the middle window, as the game lights it: the board's middle
    # 1.2 m from the window wall; the players either side along the wall, the one facing
    # the stove with the window at their left; the window side free
    TY = D - 1.2
    s.append(rect(3.0, TY - 1.4, 3.0, 2.2, RUG, INK, 0.02))
    s.append(rect(3.18, TY - 1.22, 2.64, 1.84, "none", "#e8d6c0", 0.06))
    s.append(f'<circle cx="4.5" cy="{TY}" r="0.4" fill="{WOOD}" stroke="{INK}" stroke-width="0.025"/>')
    s.append(rect(4.35, TY - 0.15, 0.3, 0.3, "#c9a77a", INK, 0.015))        # the board: 8 squares of 3.3 cm and its frame
    s.append(f'<circle cx="4.68" cy="{TY - 0.24}" r="0.07" fill="#e9eef2" stroke="{INK}" stroke-width="0.012"/>')  # the vase
    s += chair(5.2, TY, "w")
    s += chair(3.8, TY, "e")
    s += chair(4.5, TY - 0.72, "s")
    # the chandelier in the middle of the room
    s.append(f'<circle cx="4.5" cy="3.5" r="0.45" fill="none" stroke="{GOLD}" stroke-width="0.025" stroke-dasharray="0.08 0.06"/>')
    s.append(f'<circle cx="4.5" cy="3.5" r="0.08" fill="{GOLD}"/>')
    # a sofa table and an armchair in front of the sofa on the hall wall
    s.append(f'<ellipse cx="7.85" cy="1.3" rx="0.5" ry="0.3" fill="{WOOD}" stroke="{INK}" stroke-width="0.02"/>')
    s += chair(6.75, 1.4, "e", GREEN, 0.6)
    # a reading armchair by the first window, a side table, a plant
    s += chair(1.25, 5.7, "n", GREEN, 0.7)
    s.append(f'<circle cx="1.95" cy="6.2" r="0.2" fill="{WOOD}" stroke="{INK}" stroke-width="0.015"/>')
    s += plant(0.45, 6.5, 0.25)
    # the writing desk, the second place to play: at a right angle to the window wall in
    # front of the third window, centred where the table's board is to the middle window
    # (1.2 m out, opposite the window's middle), so one room light serves both; the board
    # in the middle of its leather, the player at the middle of the long side, looking
    # along the room toward the stove, the window at their left
    s.append(rect(7.125, TY - 0.75, 0.75, 1.5, WOOD, INK, 0.025))
    s.append(rect(7.2, TY - 0.65, 0.6, 1.3, "#3f5f45", "none", 0))
    s.append(rect(7.35, TY - 0.15, 0.3, 0.3, "#c9a77a", INK, 0.015))
    s += chair(8.3, TY, "w", WOOD, 0.48)
    # paintings on the piers and walls
    s += painting(2.6, D - 0.02, 3.4, D - 0.02)
    s += painting(5.6, D - 0.02, 6.4, D - 0.02)
    s += painting(W - 0.02, 5.2, W - 0.02, 5.9) if variant == 1 else []
    s += painting(1.4, 0.02, 2.1, 0.02)
    # scale bar, 0-5 m
    for i in range(5):
        s.append(rect(i, D + OUT + 0.45, 1, 0.08, INK if i % 2 == 0 else "#f6efe1", INK, 0.01))
    if labels:
        L = [(4.5, -0.85, "door from the hall"),
             (0.6, -0.85, "stove, fed from the hall"),
             (-0.95, 2.35, "garden salon"),
             (1.45, 4.55, "glazed bookcase"),
             (2.95, 0.65, "open bookcase"), (6.05, 0.65, "open bookcase"),
             (7.85, -0.85, "sofa, large painting above"),
             (4.5, 3.05, "chandelier"),
             (7.85, 1.95, "sofa table"),
             (4.5, 4.05, "games table and board, rug"),
             (1.25, 5.15, "armchair"),
             (7.2, 4.9, "writing desk and board"),
             (4.5, D + OUT + 0.38, "garden (south-west)"),
             (2.5, D + OUT + 0.85, "0 – 5 m")]
        if variant == 1:
            L.append((W + 0.9, 2.35, "next room"))
        else:
            L.append((W - 1.75, 3.0, "open shelves to the ceiling"))
            L.append((W - 1.75, 3.3, "and a ladder"))
        for x, y, t in L:
            s.append(text(x, y, t))
    return ('<svg xmlns="http://www.w3.org/2000/svg" viewBox="-1.6 -1.6 %s %s" width="%d" height="%d">%s</svg>'
            % (W + 3.2, D + 3.6, int((W + 3.2) * 110), int((D + 3.6) * 110), "".join(s)))


if __name__ == "__main__":
    out = sys.argv[1]
    for v in (1, 2):
        for labels, suffix in ((False, ""), (True, "-labels")):
            with open(f"{out}/plan-{v}{suffix}.svg", "w") as f:
                f.write(plan(v, labels))
