#!/usr/bin/env python3
"""The library's lace side by side: ChatGPT's download beside our bakes, at the same
framing and physical scale, labelled on each image.

    python3 tools/materials/lace_compare.py build/notes/lace-library build/notes/lace-compare

LIBRARY_DIR holds one folder a way, as the bakers' headers make them (lace-2, b, c, d,
d-tilted, d-near, f, f2, f3); OUT_DIR gets index.html and its tiles. The download's scale is
lace.py's: 2 * REPEAT source px a TILE_M tile. Field windows are in metres from the
download's field corner (FIELD's x0, y0), where our traced ways' tile starts too; hem
windows in metres from a garland's cusp across and from the lowest edge of the hem up.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

import common as cm
import lace
import lace_crisp as lc

N = lc.N
SRC_M = lace.TILE_M / (2 * lace.REPEAT)        # metres a download px: 0.81 mm
OURS_M = lace.TILE_M / N                       # metres a full-detail px: 0.137 mm
SRC_CUSP_X = 576                               # download column of a garland's cusp
FIELD_ROWS = (lace.FIELD[1], lace.BORDER_ROWS[0])

GPT = '#ff9f1c'                                # ChatGPT's labels
OURS = '#4cc9f0'                               # ours
WAYS = [  # folder, file tag, label, one line
    ('f', 'f', 'f, wild rose grammar', 'grown: trails, shoots, pinnate leaves, roses at the tips'),
    ('f2', 'f2', 'f2, fuller and twining', 'f grown fuller: overlapping leaves, twining stems'),
    ('f3', 'f3', 'f3, fronds and larger roses', 'f2 with frond leaves, gaps filled, more and larger roses'),
    ('d-tilted', 'd', 'd-tilted', 'wild roses, tilted and warped'),
    ('d', 'd', 'd', 'wild roses, face on'),
    ('c', 'c', 'c', 'traced layout, rosette flowers'),
    ('b', 'b', 'b', 'grown from scratch, own layout'),
    ('lace-2', None, 'lace-2', 'old bake, cut straight from the download'),
]
NEAR = ('d-near', 'd', 'd-near', 'd-tilted tuned toward the download')
HEM_ONLY = set()                               # ways whose field is the way before it's

# name, metres (x, y, w, h), output px (w, h)
FIELD_VIEWS = [
    ('14 cm close-up', (0.079, 0.152, 0.14, 0.14), (768, 768)),
    ('50 cm across', (0.0, 0.0, 0.5, 0.5), (768, 768)),
    ('1.2 m across, a curtain\'s width', (0.0, 0.0, 1.2, 0.8), (900, 600)),
    ('far, the whole curtain 2.5 m tall', (0.0, 0.0, 1.2, 2.5), (360, 750)),
]
HEM_VIEWS = [
    ('14 cm close-up', (-0.07, -0.13, 0.14, 0.14), (768, 768)),
    ('50 cm across', (-0.25, -0.31, 0.5, 0.333), (900, 600)),
    ('1.2 m across, a curtain\'s width', (-0.55, -0.78, 1.2, 0.8), (900, 600)),
    ('far, the whole curtain 2.5 m tall', (-0.55, -2.48, 1.2, 2.5), (360, 750)),
]


def font(size, bold=True):
    for path, idx in (('/System/Library/Fonts/HelveticaNeue.ttc', 1 if bold else 0),
                      ('/System/Library/Fonts/Helvetica.ttc', 1 if bold else 0)):
        try:
            return ImageFont.truetype(path, size, index=idx)
        except OSError:
            pass
    return ImageFont.load_default()


def fit_font(draw, text, width, size, bold=True):
    while size > 12 and draw.textlength(text, font=font(size, bold)) > width:
        size -= 1
    return font(size, bold)


def labelled(img, colour, title, what, light):
    """The image under a band in its colour: whose it is large, what it is, its light;
    framed in the colour."""
    im = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8))
    w, h = im.size
    pad = 6
    big = max(28, min(48, w // 12))
    mid, small = int(big * 0.66), int(big * 0.56)
    band = 8 + big + 6 + mid + 4 + small + 10
    out = Image.new('RGB', (w + 2 * pad, h + band + pad), colour)
    out.paste(im, (pad, band))
    d = ImageDraw.Draw(out)
    y = 6
    for text, size, bold in ((title, big, True), (what, mid, True), (light, small, False)):
        d.text((pad + 8, y), text, fill='#111', font=fit_font(d, text, w - 16, size, bold))
        y += size + (6 if size == big else 4)
    return out


# Ours.

class Way:
    def __init__(self, lib, folder, tag, net):
        p = os.path.join(lib, folder)
        if tag is None:                                    # lace.py's: 1024 px, 4x up
            up = np.ones((4, 4), np.float32)
            motif = np.kron(cm.load(os.path.join(p, 'lace_motif.png'), 'L'), up)
            border = cm.load(os.path.join(p, 'lace_border.png'))
            hem = np.stack([np.kron(border[..., i], up) for i in range(3)], -1)
        else:
            motif = cm.load(os.path.join(p, f'{tag}_motif_full.png'), 'L')
            hem = cm.load(os.path.join(p, f'{tag}_hem_full.png'))
        net_big = lace.tiled(net, lace.NET_REPEAT)
        self.full = np.maximum(net_big, motif)
        r, g, b = hem[..., 0], hem[..., 1], hem[..., 2]
        self.strip = g * np.maximum(np.maximum(net_big[:lc.HEM_H], r), b * motif[:lc.HEM_H])
        self.quarter = lace.box(self.full, 4)
        # The hem's lowest cloth, for the hem's windows.
        rows = np.arange(lc.HEM_H)[:, None]
        self.bottom = int(np.max(np.where(g > 0.5, rows, 0)))
        self._panels = {}

    def field(self, win, size):
        x, y, w, h = win
        f = 1 if w <= 0.6 else 4
        a = self.full if f == 1 else self.quarter
        return sample(a, x, y, w, h, OURS_M * f, size, wrap_y=True)

    def panel(self, f):
        """The curtain's bottom 2.6 m at 1/f detail: the field, the hem, then air; its
        row of the hem's lowest edge."""
        if f not in self._panels:
            tile = self.full if f == 1 else self.quarter
            strip = self.strip if f == 1 else lace.box(self.strip, f)
            n = int(np.ceil(2.6 / lace.TILE_M))
            air = np.zeros((int(0.3 / (OURS_M * f)), tile.shape[1]), np.float32)
            p = np.concatenate([np.tile(tile, (n, 1)), strip, air], 0)
            self._panels[f] = (p, n * tile.shape[0] + self.bottom // f)
        return self._panels[f]

    def hem(self, win, size):
        x, y, w, h = win
        f = 1 if w <= 0.6 else 4
        p, bottom = self.panel(f)
        m = OURS_M * f
        return sample(p, x, y + bottom * m, w, h, m, size, wrap_y=False)


def sample(a, x, y, w, h, m, size, wrap_y):
    """The window (metres, m a px of a, which wraps along x) resized to size, coverage."""
    x0, y0 = int(round(x / m)), int(round(y / m))
    nw, nh = int(round(w / m)), int(round(h / m))
    cols = np.arange(x0, x0 + nw) % a.shape[1]
    rows = np.arange(y0, y0 + nh)
    if wrap_y:
        win = a[np.ix_(rows % a.shape[0], cols)]
    else:
        ok = (rows >= 0) & (rows < a.shape[0])
        win = np.zeros((nh, nw), np.float32)
        win[ok] = a[np.ix_(rows[ok], cols)]
    return np.clip(cm.resize(win, *size), 0, 1)


# The download.

def hatch(h, w):
    y, x = np.mgrid[0:h, 0:w]
    stripe = ((x + y) // 14) % 2 == 0
    img = np.where(stripe[..., None], np.array([0.17, 0.16, 0.15]), np.array([0.11, 0.105, 0.10]))
    return img.astype(np.float32)


def download_view(src_lin, win, size, ox, oy, valid):
    """The window in the download's own light at the same scale, metres from (ox, oy)
    source px; parts outside valid (r0, r1, c0, c1) hatched. Returns the image and the
    covered rectangle (x0, y0, x1, y1) in output px, or None."""
    x, y, w, h = win
    W, H = size
    out = hatch(H, W)
    sx0, sy0 = ox + x / SRC_M, oy + y / SRC_M
    sx1, sy1 = sx0 + w / SRC_M, sy0 + h / SRC_M
    r0, r1, c0, c1 = valid
    cx0, cx1 = max(sx0, c0), min(sx1, c1)
    cy0, cy1 = max(sy0, r0), min(sy1, r1)
    if cx1 <= cx0 or cy1 <= cy0:
        return out, None
    px = W / (sx1 - sx0)
    dx0, dx1 = int(round((cx0 - sx0) * px)), int(round((cx1 - sx0) * px))
    dy0, dy1 = int(round((cy0 - sy0) * px)), int(round((cy1 - sy0) * px))
    chans = []
    for c in range(3):
        im = Image.fromarray(np.ascontiguousarray(src_lin[..., c], np.float32), 'F')
        chans.append(np.asarray(im.resize((dx1 - dx0, dy1 - dy0), Image.LANCZOS,
                                          box=(cx0, cy0, cx1, cy1))))
    out[dy0:dy1, dx0:dx1] = cm.to_srgb(np.clip(np.stack(chans, -1), 0, None))
    return out, (dx0, dy0, dx1, dy1)


def uncovered_note(img, rect):
    """Writes on the largest hatched part that the download has nothing there."""
    im = Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8))
    w, h = im.size
    if rect is None:
        rect = (0, 0, 0, 0)
    x0, y0, x1, y1 = rect
    gaps = [(x0 * h, (0, 0, x0, h)), ((w - x1) * h, (x1, 0, w, h)),
            (y0 * w, (0, 0, w, y0)), ((h - y1) * w, (0, y1, w, h))]
    area, (gx0, gy0, gx1, gy1) = max(gaps)
    if area < 0.01 * w * h:
        return np.asarray(im, np.float32) / 255
    d = ImageDraw.Draw(im)
    f = font(max(18, min(34, w // 14)))
    words = ['not in', 'the', 'download'] if gx1 - gx0 < 0.45 * w else ['not in the download']
    lh = f.size + 6
    ty = (gy0 + gy1) / 2 - len(words) * lh / 2
    for ln in words:
        lw = d.textlength(ln, font=f)
        d.text(((gx0 + gx1) / 2 - lw / 2, ty), ln, fill=GPT, font=f, stroke_width=3, stroke_fill='#000')
        ty += lh
    return np.asarray(im, np.float32) / 255


def src_bottom(src_lin):
    lum = src_lin @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    b = lace.blur(lum, 2) > 0.08
    rows = np.arange(lum.shape[0])[:, None]
    bot = np.max(np.where(b[1300:], rows[1300:], 0), 0)
    return int(np.max(bot[SRC_CUSP_X - 300:SRC_CUSP_X + 300]))


# The page.

def build(lib, out):
    os.makedirs(os.path.join(out, 'tiles'), exist_ok=True)
    src_path = cm.source('library-lace-01.png')
    src_lin = cm.to_linear(cm.load(src_path))
    net = lace.net_tile()
    ways = [(w, Way(lib, w[0], w[1], net)) for w in WAYS if os.path.isdir(os.path.join(lib, w[0]))]
    near = Way(lib, NEAR[0], NEAR[1], net) if os.path.isdir(os.path.join(lib, NEAR[0])) else None
    x0, y0 = lace.FIELD[0], lace.FIELD[1]
    bot = src_bottom(src_lin)
    field_valid = (FIELD_ROWS[0], FIELD_ROWS[1], lace.FIELD[0], lace.FIELD[2])
    hem_valid = (0, src_lin.shape[0], lace.FIELD[0], lace.FIELD[2])

    def save(name, im):
        im.save(os.path.join(out, 'tiles', name), quality=88)
        return 'tiles/' + name

    def gpt_tile(name, win, size, ox, oy, valid, extra=''):
        img, rect = download_view(src_lin, win, size, ox, oy, valid)
        img = uncovered_note(img, rect)
        share = 0 if rect is None else (rect[2] - rect[0]) * (rect[3] - rect[1]) / (size[0] * size[1])
        what = 'the download' if share >= 0.995 else f'the download: {share * 100:.0f}% of this frame'
        return save(name, labelled(img, GPT, 'ChatGPT (library-lace-01)', what,
                                   'its own light: front-lit on black' + extra))

    def our_tile(name, way, cov, lighting):
        front, back = lace.shade(cov)
        img = back if lighting == 'backlit' else front
        light = 'backlit by a bright window' if lighting == 'backlit' else 'front-lit on a dark ground'
        return save(name, labelled(img, OURS, f'Ours: {way[2]}', way[3], light))

    sections = []
    for part, views_, notes in (('field', FIELD_VIEWS, FIELD_NOTES), ('hem', HEM_VIEWS, HEM_NOTES)):
        rows = []
        for vi, (vname, win, size) in enumerate(views_):
            if part == 'field':
                covs = [(w, wy.field(win, size)) for w, wy in ways if w[0] not in HEM_ONLY]
                gpt = lambda n, extra='': gpt_tile(n, win, size, x0, y0, field_valid, extra)
            else:
                covs = [(w, wy.hem(win, size)) for w, wy in ways]
                gpt = lambda n, extra='': gpt_tile(n, win, size, SRC_CUSP_X, bot, hem_valid, extra)
            for lighting in ('backlit', 'front'):
                key = f'{part}{vi}_{lighting}'
                tiles = [gpt(f'{key}_chatgpt.jpg', '' if lighting == 'front' else ' (no backlit version)')]
                for w, cov in covs:
                    tiles.append(our_tile(f'{key}_{w[0]}.jpg', w, cov, lighting))
                light = 'Backlit against a bright window' if lighting == 'backlit' else 'Front-lit on a dark ground'
                rows.append((f'{part.capitalize()}, {vname}: {light.lower()}', notes[vi], tiles, size))
        sections.append(('The main pattern (field)' if part == 'field' else 'The hem', rows))

    if near is not None:
        rows = []
        for vi in (0, 1):
            vname, win, size = FIELD_VIEWS[vi]
            cov = near.field(win, size)
            dt_way = next(w for w in WAYS if w[0] == 'd-tilted')
            dt = dict(ways).get(dt_way)
            tiles = [gpt_tile(f'near{vi}_chatgpt.jpg', win, size, x0, y0, field_valid)]
            tiles.append(our_tile(f'near{vi}_front.jpg', NEAR, cov, 'front'))
            tiles.append(our_tile(f'near{vi}_backlit.jpg', NEAR, cov, 'backlit'))
            if dt is not None:
                tiles.append(our_tile(f'near{vi}_dtilted.jpg', dt_way, dt.field(win, size), 'front'))
            rows.append((f'As close as we get: {vname}', NEAR_NOTES[vi], tiles, size))
        sections.append(('As close as possible to ChatGPT\'s', rows))
    write_page(out, sections, [w for w, _ in ways])


FIELD_NOTES = [
    'One flower and its leaves, the same patch in every column (b and the f ways grow their own layouts, so '
    'their patches differ; the f ways are placed so a big rose sits here). The download is only 173 px across here, so it is soft: judge '
    'its shapes, not its sharpness. Look at the petals\' tilt, the boss, the leaves\' veins.',
    'Half a metre: flowers against leaves and the net. Look at how much is solid and how '
    'the flowers stand out of the trails.',
    'The width of a curtain as seen across the room. The download is 0.78 m wide, so the '
    'rest is hatched. Look at the rhythm of trails and flowers and how even the field reads.',
    'The whole curtain\'s field from the table. Look for repeats, stripes and blotches; '
    'the download covers only its top part.',
]
HEM_NOTES = [
    'A garland\'s cusp at the bottom edge. Look at the scallops, picots, the eyelet band '
    'and the openwork.',
    'One garland arc and the scallops under it. The download\'s edge has two small '
    'scallops to each arc, ours one large one with lobes.',
    'The hem across a curtain\'s width, the field above it.',
    'The whole curtain with its hem from the table: how strong the border reads against '
    'the field.',
]
NEAR_NOTES = [
    'Our d-near beside the download at the same crop: front-lit as the download is, '
    'backlit as it will mostly show, and d-tilted for reference.',
    'The same at 50 cm.',
]


def write_page(out, sections, ways):
    def tile(src):
        return f'<a href="{src}" target="_blank"><img src="{src}" loading="lazy"></a>'

    body = []
    for title, rows in sections:
        body.append(f'<h2>{title}</h2>')
        for head, note, tiles, size in rows:
            cls = 'tall' if size[1] > size[0] else ''
            body.append(f'<section id="r{len(body)}"><h3>{head}</h3><p>{note}</p>'
                        f'<div class="grid n{len(tiles)} {cls}">{"".join(tile(t) for t in tiles)}</div></section>')
    names = ', '.join(f'<b>{w[2]}</b> {w[3]}' for w in ways)
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lace comparison</title>
<style>
:root {{ --bg: #141312; --fg: #ece8e0; --muted: #a9a399; --gpt: {GPT}; --ours: {OURS}; }}
* {{ box-sizing: border-box; }}
body {{ background: var(--bg); color: var(--fg); font: 16px/1.5 system-ui, sans-serif; margin: 0; }}
header {{ position: sticky; top: 0; z-index: 2; background: rgba(20,19,18,.96);
         border-bottom: 1px solid #333; padding: 10px 24px; display: flex; gap: 28px;
         align-items: center; flex-wrap: wrap; }}
header h1 {{ font-size: 18px; margin: 0; }}
.key {{ display: flex; align-items: center; gap: 10px; font-size: 16px; }}
.sw {{ width: 22px; height: 22px; border-radius: 3px; display: inline-block; }}
main {{ padding: 8px 24px 64px; }}
h2 {{ font-size: 24px; margin: 40px 0 4px; border-bottom: 2px solid #333; padding-bottom: 6px; }}
section {{ scroll-margin-top: 64px; }}
h3 {{ font-size: 18px; margin: 26px 0 2px; }}
p {{ color: var(--muted); margin: 0 0 10px; max-width: 95ch; }}
.intro {{ max-width: 110ch; }}
.grid {{ display: grid; gap: 12px; grid-template-columns: repeat(3, minmax(0, 1fr)); }}
.grid.tall {{ grid-template-columns: repeat(6, minmax(0, 1fr)); }}
@media (min-width: 2200px) {{ .grid.n6 {{ grid-template-columns: repeat(6, minmax(0, 1fr)); }} }}
.grid.n4 {{ grid-template-columns: repeat(4, minmax(0, 1fr)); }}
@media (max-width: 1100px) {{ .grid, .grid.tall, .grid.n4 {{ grid-template-columns: repeat(2, minmax(0, 1fr)); }} }}
img {{ width: 100%; display: block; }}
</style></head><body>
<header><h1>Library lace: ChatGPT's download and ours</h1>
<span class="key"><span class="sw" style="background:var(--gpt)"></span>orange = ChatGPT's download (library-lace-01)</span>
<span class="key"><span class="sw" style="background:var(--ours)"></span>blue = ours, generated</span>
</header>
<main>
<p class="intro">Every image says on itself whose it is. In each row the first image is ChatGPT's,
then ours: {names}. All at the same physical scale and framing in a row; the download at
0.81 mm a pixel (0.56 m a motif tile, as lace.py assumes), so close up it is soft and
far out it does not reach (hatched). The download has only its own light, front-lit on
black, so it shows the same in both lightings. Click an image for full size.</p>
{"".join(body)}
</main></body></html>
'''
    with open(os.path.join(out, 'index.html'), 'w') as fh:
        fh.write(html)
    print('wrote', os.path.join(out, 'index.html'))


if __name__ == '__main__':
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    build(sys.argv[1], sys.argv[2])
