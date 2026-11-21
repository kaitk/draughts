#!/usr/bin/env python3
"""Bakes the library's books: their spines as a mask atlas the room's shader colours.

    python3 -I tools/materials/books.py OUT_DIR [--ppm 0.7] [--seed 7] [--preview]

Writes books_atlas.png, RGBA: R the cover's tone (grain, the bands' relief, the head's
dust), G gilt or ink, B the label, A wear (rubbed to a lighter, duller layer); and
book_cells.goose, the atlas's cells (each a design: one volume's spine, its place in
texels and its size in millimetres, format, binding, set and volume) with the covers' and
labels' colours, for src/model3d/. Colours are per book, chosen by the room's builder
from the binding's own (model3d's books.goose), so one cell serves many books. With
--preview, also atlas_colour.png, the atlas coloured as the shader colours it.

The titles (book_titles.py) are baked art in period languages, set in the OFL fonts in
tools/materials/fonts/; only the PNG goes into the program, never the fonts. From the
research of build/notes/books/ (option B, 2026-11-21).
"""

import math, os, random, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from book_titles import TITLES

HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "fonts")
FRAKTUR = os.path.join(FONTS, "unifrakturmaguntia", "UnifrakturMaguntia-Book.ttf")
FRAKTUR_BOLD = os.path.join(FONTS, "unifrakturcook", "UnifrakturCook-Bold.ttf")
ROMAN = os.path.join(FONTS, "oldstandardtt", "OldStandard-Regular.ttf")
ROMAN_BOLD = os.path.join(FONTS, "oldstandardtt", "OldStandard-Bold.ttf")

# Formats in mm: (height range, thickness range of one volume). Board width (depth on the
# shelf) is about 0.68 of the height for octavo and smaller, 0.75 for quarto and folio.
FORMATS = {
    "F": ((330, 420), (40, 75)),
    "Q": ((250, 320), (28, 55)),
    "O": ((195, 245), (20, 42)),
    "D": ((155, 190), (16, 30)),
    "S": ((130, 152), (12, 20)),
}

# Colours as sRGB, aged (not as bound), toward library-autumn-02's case (k-means
# #341f13 to #8e6a4d): mostly calf and half calf browns, a tan now and then; the cloth's
# and half leather's green, blue and red muted and few. Each binding picks a cover, a
# label, a gilt.
COVERS = {
    "calf": ["#5e3a22", "#6c4328", "#4c2c1a", "#6a4529", "#3e2616", "#765236"],
    "half": ["#4a2c1a", "#5a321e", "#3a2618", "#2e2420", "#5a3a26", "#523022", "#363226"],
    "house": ["#4a2c1a"],
    "cloth": ["#38382a", "#4a2824", "#2e3038", "#4a3626", "#3a2e2c", "#54442e", "#2c322c"],
    "vellum": ["#b09a74", "#a48e6a", "#b8a47e"],
    "boards": ["#5e5040", "#4e4a48", "#6a5a44", "#563e2e", "#464640"],
    "wraps": ["#867a64", "#6e6c64", "#7c6e58"],
}
LABELS = {"calf": ["#5a1e14", "#262e20", "#1e1a16"], "half": ["#1e1a16", "#5a1e14", "#262e20"],
          "house": ["#1e1a16"], "cloth": [None], "vellum": [None, "#5a1e14"],
          "boards": ["#cdbf9e", "#c4b694"], "wraps": [None]}
GILT = "#c09a4e"
INK = "#2a2018"

def hexrgb(h):
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float) / 255.0

def noise(rng, w, h, cell, octaves=3):
    """Value noise in 0..1, a few octaves, for grain and wear."""
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        c = max(1, cell >> o)
        small = rng.random((h // c + 2, w // c + 2))
        im = Image.fromarray((small * 255).astype(np.uint8)).resize((w + 2 * c, h + 2 * c), Image.BICUBIC)
        out += amp * np.asarray(im, float)[c:c + h, c:c + w] / 255.0
        tot += amp
        amp *= 0.5
    return out / tot

def font(lang, size, bold=False):
    if lang in ("de", "et", "lv"):
        return ImageFont.truetype(FRAKTUR_BOLD if bold else FRAKTUR, size)
    return ImageFont.truetype(ROMAN_BOLD if bold else ROMAN, size)

def fit_lines(draw, lines, lang, box_w, box_h, max_px):
    """The largest size at which every line fits the box."""
    size = max_px
    while size > 4:
        f = font(lang, size, bold=lang not in ("de", "et", "lv"))
        widths = [draw.textlength(l, font=f, features=["liga", "dlig"]) if lang in ("de", "et", "lv")
                  else draw.textlength(l, font=f) for l in lines]
        line_h = size * 1.05
        if max(widths) <= box_w and line_h * len(lines) <= box_h:
            return f, line_h
        size -= 1
    return font(lang, 4), 4.2

def text_block(layer, lines, lang, x0, y0, w, h, max_px):
    d = ImageDraw.Draw(layer)
    f, lh = fit_lines(d, lines, lang, w, h, max_px)
    total = lh * len(lines)
    y = y0 + (h - total) / 2
    for l in lines:
        tw = d.textlength(l, font=f)
        d.text((x0 + (w - tw) / 2, y), l, fill=255, font=f)
        y += lh

def fleuron(d, cx, cy, r):
    """A small gilt flower: four petals and a dot, the compartments' tool."""
    for a in range(4):
        ang = a * math.pi / 2 + math.pi / 4
        px, py = cx + math.cos(ang) * r * 0.55, cy + math.sin(ang) * r * 0.55
        d.ellipse([px - r * 0.38, py - r * 0.38, px + r * 0.38, py + r * 0.38], fill=255)
    d.ellipse([cx - r * 0.22, cy - r * 0.22, cx + r * 0.22, cy + r * 0.22], fill=0)

class Book:
    """One design: what the spine shows. Instances add colour, lean and fade."""
    def __init__(self, lang, lines, fmt, binding, vol, nvol, rng):
        self.lang, self.lines, self.fmt, self.binding = lang, lines, fmt, binding
        self.vol, self.nvol = vol, nvol
        (h0, h1), (t0, t1) = FORMATS[fmt]
        self.h = rng.uniform(h0, h1)
        self.t = rng.uniform(t0, t1)
        self.cover = rng.choice(COVERS[binding])
        self.label = rng.choice(LABELS[binding])
        self.gilt = INK if binding in ("vellum", "boards", "wraps") else GILT
        if binding == "vellum" and self.label:
            self.gilt = GILT
        self.bands = binding in ("calf", "vellum") and fmt != "S"
        self.rounded = binding not in ("boards", "wraps")
        self.seed = rng.randrange(1 << 30)

def roman_numeral(n):
    vals = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
    s = ""
    for v, r in vals:
        while n >= v:
            s += r; n -= v
    return s

def paint_spine(b, ppm):
    """The spine's mask (H x W x 4, uint8) at ppm pixels a millimetre."""
    W = max(6, int(round(b.t * ppm)))
    H = max(24, int(round(b.h * ppm)))
    rng = np.random.default_rng(b.seed)
    R = Image.new("L", (W, H), 0)
    G = Image.new("L", (W, H), 0)
    B = Image.new("L", (W, H), 0)
    dg, db = ImageDraw.Draw(G), ImageDraw.Draw(B)
    mm = ppm
    # tone: base, grain, a little darker at the edges and toward the head (dust)
    grain = noise(rng, W, H, max(2, int(3 * mm)), 3)
    if b.binding == "cloth":
        weave = (np.indices((H, W)).sum(0) % 2) * 0.06
        tone = 0.55 + 0.12 * (grain - 0.5) + weave
    elif b.binding == "vellum":
        tone = 0.6 + 0.25 * (noise(rng, W, H, max(4, int(18 * mm)), 2) - 0.5)
    else:
        tone = 0.55 + 0.30 * (grain - 0.5)
    y = np.linspace(0, 1, H)[:, None]
    # each volume aged its own way: a set's spines a little darker or lighter one to the next
    tone = tone + 0.14 * (rng.random() - 0.5)
    # the head's dust and handling, the tail's shelf dirt, darker on the long way down
    tone = tone - 0.16 * np.exp(-y / 0.05) - 0.06 * np.exp(-(1 - y) / 0.03) - 0.05 * y
    # compartments: raised bands (calf, vellum) or gilt false bands (half, house, cloth)
    nb = 5 if b.fmt in ("F", "Q", "O") else 4
    top, bot = 0.06 * H, 0.94 * H
    ys = [top + (bot - top) * (i + 0.5) / nb for i in range(nb)]
    ys = [top] + [(ys[i] + ys[i + 1]) / 2 for i in range(nb - 1)] + [bot]
    bandw = 3.5 * mm
    yy = np.arange(H)[:, None]
    wide = b.t >= 22 or b.fmt in ("F", "Q")
    if not wide:
        b.bands = False
    if b.binding in ("calf", "vellum", "half", "house"):
        for yb in ys[1:-1]:
            if b.bands:
                d = (yy - yb) / bandw
                ridge = np.clip(1 - d * d, 0, 1)
                tone = tone + 0.22 * ridge * np.where(yy < yb, 1.0, -0.4)
            if b.binding != "vellum":
                for off in (-bandw * 0.9, bandw * 0.9) if b.bands else (-1.2 * mm, 1.2 * mm):
                    dg.line([(0, yb + off), (W, yb + off)], fill=255, width=max(1, int(0.5 * mm)))
                if not b.bands:
                    dg.line([(0, yb), (W, yb)], fill=255, width=max(1, int(1.2 * mm)))
    # title: horizontal in a label in the second compartment when the spine is wide
    # enough, else along the spine reading bottom to top (the continental way)
    wide = b.t >= 22 or b.fmt in ("F", "Q")
    lines = b.lines
    if wide:
        y0, y1 = ys[1], ys[2]
        pad = 1.5 * mm
        if b.label:
            db.rectangle([pad * 0.6, y0 + pad, W - pad * 0.6, y1 - pad], fill=255)
            if b.binding == "boards":    # a paper label: a thin printed frame
                dg.rectangle([pad * 1.2, y0 + pad * 1.6, W - pad * 1.2, y1 - pad * 1.6], outline=255, width=max(1, int(0.3 * mm)))
        text_block(G, lines, b.lang, pad * 1.6, y0 + pad * 2, W - pad * 3.2, (y1 - y0) - pad * 4, int(7 * mm) + 2)
        if b.nvol > 1:                  # the volume in the fourth compartment
            v0, v1 = ys[3], ys[4] if len(ys) > 4 else ys[3] + 20 * mm
            if b.label and b.binding in ("calf", "half"):
                db.rectangle([pad * 0.6, v0 + pad * 2, W - pad * 0.6, v1 - pad * 2], fill=255)
            vtxt = str(b.vol) if b.lang in ("de", "et", "lv") else roman_numeral(b.vol)
            if b.lang == "fr":
                vtxt = "TOME " + vtxt if W > 26 * mm else vtxt
            text_block(G, [vtxt], b.lang if b.lang != "de" else "fr", pad * 2, v0 + pad * 3, W - pad * 4, (v1 - v0) - pad * 6, int(5 * mm) + 2)
        # compartments' tools: a fleuron in each empty one (calf, house)
        if b.binding in ("calf", "house"):
            for i in range(len(ys) - 1):
                if i in (1,) or (b.nvol > 1 and i == 3):
                    continue
                cy = (ys[i] + ys[i + 1]) / 2
                if b.binding == "house" and i == len(ys) - 2:
                    text_block(G, ["v. S."], "fr", 1.5 * mm, ys[i] + 3 * mm, W - 3 * mm, ys[i + 1] - ys[i] - 6 * mm, int(4 * mm) + 2)
                    continue
                fleuron(dg, W / 2, cy, min(W * 0.18, 4 * mm))
        if b.binding == "cloth":       # cloth: gilt rules at head and tail, a vignette
            for yv in (4 * mm, 6 * mm, H - 4 * mm, H - 6 * mm):
                dg.line([(1 * mm, yv), (W - 1 * mm, yv)], fill=255, width=max(1, int(0.6 * mm)))
            fleuron(dg, W / 2, H * 0.72, min(W * 0.22, 5 * mm))
    else:
        # along the spine: draw on a rotated canvas, bottom to top
        L = Image.new("L", (H, W), 0)
        x0, x1 = H * 0.18, H * 0.82
        if b.label:
            lb = Image.new("L", (H, W), 0)
            ImageDraw.Draw(lb).rectangle([x0 - 2 * mm, 0.8 * mm, x1 + 2 * mm, W - 0.8 * mm], fill=255)
            B.paste(lb.rotate(90, expand=True), (0, 0))
        text_block(L, [" ".join(lines).replace("- ", "")], b.lang, x0, 1.2 * mm, x1 - x0, W - 2.4 * mm, int(6 * mm) + 2)
        G.paste(Image.composite(Image.new("L", (W, H), 255), G, L.rotate(90, expand=True)), (0, 0))
        if b.binding in ("cloth", "half", "house", "calf"):
            for yv in (5 * mm, H - 5 * mm):
                dg.line([(0, yv), (W, yv)], fill=255, width=max(1, int(0.6 * mm)))
    # gilt worn: broken up where the grain is high, more at head and tail
    g = np.asarray(G, float) / 255.0
    flake = noise(rng, W, H, max(1, int(1.2 * mm)), 2)
    g = g * np.clip((flake - 0.18) * 4, 0, 1)
    # wear: head, tail, band crowns, and a few scuffs
    w = noise(rng, W, H, max(2, int(4 * mm)), 3)
    # the head cap pulled by fingers, chipped and rubbed deeper than the tail's
    edge = 1.1 * np.exp(-y / 0.035) + 0.8 * np.exp(-(1 - y) / 0.03)
    xx = np.linspace(-1, 1, W)[None, :]
    side = np.clip(np.abs(xx) - 0.7, 0, 1) * 2.5           # the joints rub first
    wear = np.clip((w - 0.58) * 3 + edge * (0.5 + 0.8 * w) + side * 0.6, 0, 1)
    if b.binding == "vellum":
        wear *= 0.4
    m = np.stack([np.clip(tone, 0, 1), g, np.asarray(B, float) / 255.0, wear], -1)
    return (m * 255 + 0.5).astype(np.uint8)


def colour(mask, b):
    """What the shader does: the cover, the label over it, wear, gilt on top (sRGB)."""
    m = mask.astype(float) / 255.0
    tone, g, lab, wear = m[..., 0:1], m[..., 1:2], m[..., 2:3], m[..., 3:4]
    base = np.broadcast_to(hexrgb(b.cover), m.shape[:2] + (3,)).copy()
    if b.label:
        base = base * (1 - lab) + hexrgb(b.label) * lab
    base = base * (0.4 + 1.0 * tone)
    rubbed = base * 0.75 + np.array([0.42, 0.33, 0.24]) * 0.25
    base = base * (1 - wear * 0.6) + rubbed * wear * 0.6
    gilt = hexrgb(b.gilt) * (0.85 + 0.3 * tone)
    return np.clip(base * (1 - g) + gilt * g, 0, 1)

def make_library(rng):
    """Every design in the library, one per volume; a set shares its height and colours."""
    books = []
    for si, (lang, lines, fmt, binding, nvol, _note) in enumerate(TITLES):
        base = Book(lang, lines, fmt, binding, 1, nvol, rng)
        for v in range(1, nvol + 1):
            b = Book(lang, lines, fmt, binding, v, nvol, rng)
            b.h, b.cover, b.label, b.gilt = base.h, base.cover, base.label, base.gilt
            b.t = base.t * rng.uniform(0.85, 1.15)
            b.set_id = si
            books.append(b)
    return books

GUTTER = 4          # texels between cells, so the room's 4 mip levels keep them apart

def pack(cells, width):
    """Rows by height, tallest first; positions and the rows' height."""
    order = sorted(range(len(cells)), key=lambda i: -cells[i].shape[0])
    x = y = row_h = 0
    pos = [None] * len(cells)
    for i in order:
        h, w = cells[i].shape[:2]
        if x + w + GUTTER > width:
            x, y, row_h = 0, y + row_h + GUTTER, 0
        pos[i] = (x, y)
        x += w + GUTTER
        row_h = max(row_h, h)
    return pos, y + row_h

# The tables the room's builder takes, in the order book_cells.goose writes them.
BINDINGS = ["calf", "half", "house", "cloth", "vellum", "boards", "wraps"]
FORMAT_ORDER = ["F", "Q", "O", "D", "S"]
LABEL_COLOURS = ["#5a1e14", "#1e1a16", "#262e20", "#cdbf9e"]
# What else the shader's table holds after the labels: gilt, ink, the page edges plain
# (old paper) and sprinkled red.
EDGES = [GILT, INK, "#8a7a5c", "#5e3628"]

def goose_rgb(h):
    c = hexrgb(h)
    return "float4 { %.3f, %.3f, %.3f, 1.0 }" % (c[0], c[1], c[2])

def write_goose(path, books, pos, w, h, ppm):
    covers = [c for b in BINDINGS for c in COVERS[b]]
    first, at = [], 0
    for b in BINDINGS:
        first.append(at)
        at += len(COVERS[b])
    labels = []
    for b in BINDINGS:
        mask = 0
        for c in LABELS[b]:
            if c is not None:
                mask |= 1 << LABEL_COLOURS.index(nearest_label(c))
        labels.append(mask)
    out = []
    out.append("// The books' atlas (design/materials/books_atlas.png): its cells and the covers' and")
    out.append("// labels' colours. Made by tools/materials/books.py; make it again rather than edit it.")
    out.append("namespace books;")
    out.append("import std;")
    out.append("import vec;")
    out.append("")
    out.append("let ATLAS_W = %d;" % w)
    out.append("let ATLAS_H = %d;" % h)
    out.append("let TEXELS_A_MM: f32 = %.2f;" % ppm)
    out.append("let CELLS = %d;" % len(books))
    out.append("let SETS = %d;" % len(TITLES))
    out.append("")
    out.append("// Each design: its place in texels (x, y, w, h, the head at y), its height and")
    out.append("// thickness (mm), format (F Q O D S), binding (BINDINGS), set (a title of")
    out.append("// book_titles.py), volume, and whether its spine has a label.")
    out.append("let CELL: Cell[%d] = [" % len(books))
    for b, (x, y) in zip(books, pos):
        cw, ch = cell_size(b, ppm)
        out.append("    Cell { %d, %d, %d, %d, %.1f, %.1f, %d, %d, %d, %d, %d }," % (
            x, y, cw, ch, b.h, b.t, FORMAT_ORDER.index(b.fmt), BINDINGS.index(b.binding), b.set_id, b.vol,
            1 if b.label else 0))
    out.append("];")
    out.append("")
    out.append("// The covers by binding (sRGB, aged): calf, half leather, the house's, cloth, vellum,")
    out.append("// paper boards, wrappers, each binding's from COVER_FIRST.")
    out.append("let COVER: float4[%d] = [" % len(covers))
    for c in covers:
        out.append("    %s," % goose_rgb(c))
    out.append("];")
    out.append("let COVER_FIRST: i64[%d] = [%s];" % (len(first), ", ".join(str(f) for f in first)))
    out.append("let COVER_COUNT: i64[%d] = [%s];" % (len(first), ", ".join(str(len(COVERS[b])) for b in BINDINGS)))
    out.append("")
    out.append("// The labels' colours, then gilt, ink, and the page edges plain and sprinkled; which")
    out.append("// labels each binding takes, a bit each.")
    out.append("let LABEL: float4[8] = [")
    for c in LABEL_COLOURS + EDGES:
        out.append("    %s," % goose_rgb(c))
    out.append("];")
    out.append("let LABELS_OF: i64[%d] = [%s];" % (len(labels), ", ".join(str(m) for m in labels)))
    open(path, "w").write("\n".join(out) + "\n")

def nearest_label(c):
    v = hexrgb(c)
    d = [float(((hexrgb(l) - v) ** 2).sum()) for l in LABEL_COLOURS]
    return LABEL_COLOURS[d.index(min(d))]

def cell_size(b, ppm):
    return max(6, int(round(b.t * ppm))), max(24, int(round(b.h * ppm)))

def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "out"
    ppm = float(sys.argv[sys.argv.index("--ppm") + 1]) if "--ppm" in sys.argv else 0.7
    seed = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else 7
    os.makedirs(out, exist_ok=True)
    rng = random.Random(seed)
    books = make_library(rng)
    for b in books:                   # each label's colour one of the shader's table's
        if b.label:
            b.label = nearest_label(b.label)
    masks = [paint_spine(b, ppm) for b in books]
    width = 1024
    pos, used_h = pack(masks, width)
    h = (used_h + 15) // 16 * 16
    atl = np.zeros((h, width, 4), np.uint8)
    col = np.zeros((h, width, 3)) + 0.12
    for b, m, (x, y) in zip(books, masks, pos):
        mh, mw = m.shape[:2]
        atl[y:y + mh, x:x + mw] = m
        if "--preview" in sys.argv:
            col[y:y + mh, x:x + mw] = colour(m, b)
    # The tone in 64 steps and the wear in 16, which the grain hides, so the PNG packs smaller.
    atl[..., 0] = np.minimum((atl[..., 0].astype(int) + 2) // 4 * 4, 255)
    atl[..., 3] = np.minimum((atl[..., 3].astype(int) + 8) // 16 * 16, 255)
    Image.fromarray(atl, "RGBA").save(os.path.join(out, "books_atlas.png"), optimize=True)
    if "--preview" in sys.argv:
        Image.fromarray((col * 255).astype(np.uint8)).save(os.path.join(out, "atlas_colour.png"))
    write_goose(os.path.join(out, "book_cells.goose"), books, pos, width, h, ppm)
    used = sum(m.shape[0] * m.shape[1] for m in masks)
    print(f"{len(books)} designs, atlas {width}x{h} at {ppm} texels a mm, {used / (width * h):.0%} used")

if __name__ == "__main__":
    main()
