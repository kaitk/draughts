#!/usr/bin/env python3
"""Bakes the library's lace curtains: a generated net, the flowers of library-lace-01.png
over it, and the scalloped hem as a strip of its own.

    python3 tools/materials/lace.py OUT_DIR

The library's copy (lace-2, the old bake): `lace.py build/notes/lace-library/lace-2`. No seed: the net's
jitter is hashed (cm.rand's seeds 11 and 12, the thread's wobble 13), so it bakes the same
every time.

Writes, all coverage (linear, 0 where light passes, 1 solid):
- lace_net.png (L8, NET_SIZE px, NET_M a side): the tulle, hexagonal bobbinet, made here.
  It repeats NET_REPEAT times a motif tile, so its UV is the motif's times NET_REPEAT.
- lace_motif.png (L8, MOTIF_SIZE px, TILE_M a side): the flowers, leaves and stems cut
  from the download, its light, shading and folds taken out; 0 between them.
- lace_border.png (RGB8, BORDER_W x BORDER_H, TILE_M long, wraps along x only): the hem.
  R the border's lace; G where there is cloth at all (0 below the scallops and in the
  openwork's holes); B how much of the field's motif shows (1 at the strip's top, 0 below
  a wavy line through the net above the border's arcs).
The shader: field = max(net, motif); in the hem band, G * max(net, R, B * motif). The
thread is THREAD with roughness ROUGH (no map).

The download is a whole curtain on black, lit from the front with folds painted in. Its
net is left behind: the motifs are where the lace's coverage, smoothed past the net's
cells, is high. Its trails repeat REPEAT px across, so a tile two repeats wide wraps along
x by design and is seam-cut along y. Also writes previews (the coverage tiled 3x3, from
afar, close up, backlit as against a window, and the hem under the field) and contact.html.
"""

import os
import sys

import numpy as np
from PIL import Image

import common as cm

TILE_M = 0.56           # metres a motif tile covers, both ways: its flowers come out 5 to
                        # 6.5 cm, its trails 28 cm apart, the download's net 2.4 mm
REPEAT = 347            # source px: the trails' repeat across (autocorrelation peak)
MOTIF_SIZE = 1024       # px: 0.55 mm a px
FIELD = (30, 40, 994)   # x0, y0, x1 of the field in the download: inside the selvedges
OVERLAP = 96            # source px the edges overlap for the seam cut
FOLD_WIDTH = 81         # px: straight bands down the curtain narrower than about half this
                        # are folds
WHITE_BLOCK = 48        # px: the thread's lit brightness is a high percentile per block,
WHITE_PCT = 97          # then smoothed over WHITE_SMOOTH px
WHITE_SMOOTH = 40
SHAPE_BLUR = 1.6        # source px: smooths the download's net away; what stays above
SHAPE = (0.53, 0.58)    # this coverage ramp is a motif's shape
DETAIL_BLUR = 0.6       # source px: the veins and the flowers' eyes, open where the
VEIN = (0.18, 0.36)     # coverage falls this far below its surroundings (VEIN_AROUND px),
VEIN_AROUND = 3.0       # so the download's broad shading goes and only narrow dark lines stay
VEIN_OPEN = 0.45        # coverage left in a vein: the cloth-work's veins are open stitches
SUPPORT = 5.0           # output px: a shape whose smoothed coverage stays under SUPPORT_MIN
SUPPORT_MIN = (0.22, 0.32)  # is a speck of the download's light, not cloth-work

NET_REPEAT = 16         # net tiles a motif tile: 35 mm
NET_SIZE = 256          # px: 0.137 mm a px
NET_COLS, NET_ROWS = 19, 22  # holes a net tile, rows staggered: 1.84 mm apart along a row,
                        # 1.59 mm between rows (a regular hexagon's 1.60); Nottingham curtain
                        # net is 1.5 to 3 mm
NET_THREAD_MM = 0.28    # the twisted threads between holes
NET_ROUND = 0.52        # hole radius, of the pitch: rounds the hexagons' corners, so the
                        # threads thicken where three meet, as bobbinet's twists do
NET_JITTER = 0.06       # of the pitch: the holes' centres wander, so the mesh is not a stamp
NET_WIDTH_VAR = 0.18    # the thread's width wanders by this share

BORDER_ROWS = (1207, 1470)  # source rows of the hem strip: above the arcs to below the
BORDER_PERIOD = 351         # scallops, whose repeat is this; two repeats make the strip
BORDER_W, BORDER_H = 1024, 384
BORDER_CUT = (1210, 1290)   # source rows the field-to-border line wanders in
BORDER_SHAPE = (0.53, 0.60)
HOLE = (0.08, 0.16)     # brightness (of the lace's white) under which the hem has no cloth

THREAD = '#ddd3bf'      # guess: sRGB albedo, off-white cotton, warm and aged
ROUGH = 0.9             # cotton
TRANSMIT = 0.12         # guess: share of the light behind that a thread lets through, warm
PREVIEW = NET_SIZE * NET_REPEAT  # px a side of the full-detail composite: 4096


def blur(a, sigma, wrap=False):
    """Gaussian blur through the spectrum; mirrored at the edges unless wrap."""
    h, w = a.shape
    m = a if wrap else np.concatenate([np.concatenate([a, a[::-1]], 0),
                                       np.concatenate([a[:, ::-1], a[::-1, ::-1]], 0)], 1)
    fy = np.fft.fftfreq(m.shape[0])[:, None]
    fx = np.fft.fftfreq(m.shape[1])[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fy * fy + fx * fx))
    return np.real(np.fft.ifft2(np.fft.fft2(m) * g))[:h, :w].astype(np.float32)


def ramp(a, lo_hi):
    lo, hi = lo_hi
    return np.clip((a - lo) / (hi - lo), 0, 1)


def coverage(lum):
    """Coverage 0..1 from the curtain's linear brightness on black, its light divided out
    and the folds' bands evened."""
    h, w = lum.shape
    b = WHITE_BLOCK
    hb, wb = -(-h // b), -(-w // b)
    pad = np.pad(lum, ((0, hb * b - h), (0, wb * b - w)), mode='reflect')
    blocks = pad.reshape(hb, b, wb, b).transpose(0, 2, 1, 3).reshape(hb, wb, -1)
    white = np.percentile(blocks, WHITE_PCT, axis=2).astype(np.float32)
    white = blur(cm.resize(white, w, h), WHITE_SMOOTH)
    c = np.clip(lum / np.maximum(white, 1e-3), 0, 1)

    # The folds' highlights: bands straight down the whole curtain, which nothing in the
    # design is. A column's lower percentile is its net; its running median across
    # FOLD_WIDTH px is what the net should be.
    col = np.percentile(c, 30, 0)
    pad = np.pad(col, FOLD_WIDTH // 2, mode='reflect')
    ref = np.median(np.lib.stride_tricks.sliding_window_view(pad, FOLD_WIDTH), 1)
    fold = np.clip(ref / np.maximum(col, 1e-3), 0.4, 2.0)
    away = 1 - ramp(c, (0.6, 0.85))     # the cloth-work keeps its coverage
    return np.clip(c * (1 + (fold[None, :] - 1) * away), 0, 1)


def motifs(c, shape, size_hw):
    """The cloth-work of a coverage tile that wraps, resized to size_hw: its shape from
    the coverage smoothed past the net, veins open inside it."""
    h, w = size_hw
    sil = ramp(cm.resize_periodic(blur(c, SHAPE_BLUR, True), h, w), shape)
    sil = sil * ramp(blur(sil, SUPPORT, True), SUPPORT_MIN)
    vein = ramp(cm.resize_periodic(blur(c, VEIN_AROUND, True) - blur(c, DETAIL_BLUR, True), h, w), VEIN)
    return sil * (1 - (1 - VEIN_OPEN) * vein)


def net_tile():
    """Hexagonal net: threads along the Voronoi edges of staggered holes, supersampled."""
    ss = 4
    n = NET_SIZE * ss
    pitch = TILE_M * 1000 / NET_REPEAT / NET_COLS      # mm along a row
    row = TILE_M * 1000 / NET_REPEAT / NET_ROWS                      # mm between rows
    y, x = (np.mgrid[0:n, 0:n].astype(np.float32) + 0.5) / n
    u, v = x * NET_COLS, y * NET_ROWS
    d1 = np.full(u.shape, 1e9, np.float32)
    d2 = d1.copy()
    j0 = np.floor(v).astype(np.int64)
    for dj in (-1, 0, 1):
        j = j0 + dj
        off = 0.5 * (j & 1)
        i0 = np.floor(u - off).astype(np.int64)
        for di in (-1, 0, 1, 2):
            i = i0 + di
            key = (i % NET_COLS) + NET_COLS * (j % NET_ROWS)
            cu = i + off + 0.5 + (cm.rand(key, 11) - 0.5) * 2 * NET_JITTER
            cv = j + 0.5 + (cm.rand(key, 12) - 0.5) * 2 * NET_JITTER * pitch / row
            d = np.hypot((u - cu) * pitch, (v - cv) * row)
            d2 = np.where(d < d1, d1, np.minimum(d2, d))
            d1 = np.minimum(d1, d)
    wobble = cm.fbm(x * 8, y * 8, 2, seed=13, period=(8, 8))
    half = 0.5 * NET_THREAD_MM * (1 + NET_WIDTH_VAR * wobble)
    solid = ((d2 - d1) * 0.5 < half) | (d1 > NET_ROUND * pitch)
    return solid.astype(np.float32).reshape(NET_SIZE, ss, NET_SIZE, ss).mean((1, 3))


def luminance(rgb):
    return cm.to_linear(rgb) @ np.array([0.2126, 0.7152, 0.0722], np.float32)


def field_motif(src):
    x0, y0, x1 = FIELD
    c = coverage(luminance(src[:, x0:x1]))
    t = 2 * REPEAT
    c = c[y0:y0 + t + OVERLAP, :t + OVERLAP]
    tile = cm.seam_tile(c, OVERLAP, cost_img=blur(c, 2.0))
    return motifs(tile, SHAPE, (MOTIF_SIZE, MOTIF_SIZE)), c


def border_strip(src):
    """The hem: R its lace, G its cloth, B where the field's motif shows."""
    y0, y1 = BORDER_ROWS
    x0, _, x1 = FIELD
    lum = luminance(src[:y1, x0:x1])
    c = coverage(lum)[y0:]
    bright = lum[y0:] / np.percentile(lum, WHITE_PCT)
    cloth = ramp(blur(bright, 1.2), HOLE)
    c = c * cloth
    t = 2 * BORDER_PERIOD
    stack = np.stack([c, cloth], -1)[:, :t + OVERLAP]
    strip = cm.seam_tile(stack, OVERLAP, cost_img=blur(c, 2.0)[:, :t + OVERLAP], both=False)
    c, cloth = strip[..., 0], strip[..., 1]

    # The field's motif shows above a line that wanders through the net, below the
    # field's flowers that come down into the source's strip and above the arcs.
    a, b = BORDER_CUT[0] - y0, BORDER_CUT[1] - y0
    cost = blur(c, 2.0)[a:b].T.copy()
    path = cm._cut_path(cost + 0.002, wrap=True) + a
    field = (np.arange(c.shape[0])[:, None] < path[None, :]).astype(np.float32)

    # Wraps along x only: resize along y plainly, then along x through the spectrum.
    def fit(a, sigma=0.0):
        a = cm.resize(a, a.shape[1], BORDER_H)
        return cm.resize_periodic(blur(a, sigma) if sigma else a, BORDER_H, BORDER_W)

    sil = ramp(fit(blur(c, SHAPE_BLUR)), BORDER_SHAPE)
    sil = sil * ramp(blur(sil, SUPPORT), SUPPORT_MIN)
    vein = ramp(fit(blur(c, VEIN_AROUND) - blur(c, DETAIL_BLUR)), VEIN)
    lace = sil * (1 - (1 - VEIN_OPEN) * vein) * (1 - np.clip(fit(field, 1.0), 0, 1))
    return np.clip(np.stack([lace, fit(cloth), fit(field, 1.0)], -1), 0, 1)


def tiled(a, n, m=None):
    return np.tile(a, (m or n, n) + (1,) * (a.ndim - 2))


def save_jpg(path, a):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, quality=90)
    print(f'wrote {path}')


def shade(cov):
    """The coverage as the thread on dark, and backlit by a sunlit window, sRGB."""
    thread = cm.to_linear(cm.hex_rgb(THREAD))
    dark = cm.to_linear(cm.hex_rgb('#2a2622'))
    k = cov[..., None]
    front = dark + (thread - dark) * k
    # Light through the holes; the threads dark, but a little light comes through them,
    # warmed by the cotton.
    sky = np.array([1.0, 0.97, 0.92], np.float32)
    through = TRANSMIT * thread * np.array([1.0, 0.9, 0.7], np.float32)
    back = (1 - k) * sky + k * (through * sky + 0.05 * thread)
    return cm.to_srgb(front), cm.to_srgb(back)


def box(a, f):
    h, w = a.shape[0] // f, a.shape[1] // f
    return a[:h * f, :w * f].reshape(h, f, w, f, *a.shape[2:]).mean((1, 3))


def bake(out):
    src_path = cm.source('library-lace-01.png')
    src = cm.load(src_path)
    net = net_tile()
    motif, field = field_motif(src)
    border = border_strip(src)
    cm.save(os.path.join(out, 'lace_net.png'), net)
    cm.save(os.path.join(out, 'lace_motif.png'), motif)
    cm.save(os.path.join(out, 'lace_border.png'), border)

    # The field at full detail, as the shader puts it together: 4096 px, 0.137 mm a px.
    up = PREVIEW // MOTIF_SIZE
    big = np.maximum(tiled(net, NET_REPEAT), np.kron(motif, np.ones((up, up), np.float32)))
    tile = box(big, up)                 # 1024 px, as the GPU's mip level would average
    cm.save(os.path.join(out, 'lace_mask.png'), tile)
    front, back = shade(tile)
    cm.save(os.path.join(out, 'lace_preview.png'), front)
    cm.save(os.path.join(out, 'lace_backlit.png'), back)
    for kind, img in (('mask', np.repeat(tile[..., None], 3, 2)), ('preview', front),
                      ('backlit', back)):
        save_jpg(os.path.join(out, f'lace_{kind}_3x3.jpg'),
                 cm.resize(tiled(img, 3), MOTIF_SIZE * 3 // 2, MOTIF_SIZE * 3 // 2))
        far = box(img, 8) if kind == 'mask' else cm.downscale(img, 8)
        save_jpg(os.path.join(out, f'lace_{kind}_far.png'), tiled(far, 6))

    # Close up: a 1024 px window of the full detail, 14 cm across, over a flower.
    cy, cx = 1500, 1000
    close = big[cy:cy + 1024, cx:cx + 1024]
    front, back = shade(close)
    save_jpg(os.path.join(out, 'lace_close.png'), np.concatenate([front, back], 1))
    front, back = shade(tiled(net, 4))
    save_jpg(os.path.join(out, 'lace_net_4x4.png'), np.concatenate([front, back], 1))

    # The hem under the field, two tiles wide: field one tile, then the strip.
    r, g, b = border[..., 0], border[..., 1], border[..., 2]
    netb = box(tiled(net, NET_REPEAT, -(-BORDER_H * up // NET_SIZE))[:BORDER_H * up], up)
    hem = g * np.maximum(np.maximum(netb, r), b * motif[:BORDER_H])  # the field carries on
    curtain = np.concatenate([tile, hem], 0)
    curtain = tiled(curtain, 2, 1)
    curtain = np.concatenate([curtain, np.zeros((128, curtain.shape[1]), np.float32)], 0)
    front, back = shade(curtain)
    for kind, img in (('front', front), ('backlit', back)):
        save_jpg(os.path.join(out, f'lace_hem_{kind}.jpg'),
                 cm.resize(img, img.shape[1] // 2, img.shape[0] // 2))
    save_jpg(os.path.join(out, 'lace_border_rgb.png'), border)

    save_jpg(os.path.join(out, 'lace_field.jpg'), np.repeat(field[..., None], 3, 2))
    Image.open(src_path).convert('RGB').save(os.path.join(out, 'library-lace-01.jpg'), quality=90)

    mm = TILE_M * 1000
    note = (f'lace_motif.png: L8, {MOTIF_SIZE} px, {TILE_M} m a side ({mm / MOTIF_SIZE:.2f} mm a px), '
            f'cut from {2 * REPEAT} source px. lace_net.png: L8, {NET_SIZE} px, {mm / NET_REPEAT:.0f} mm '
            f'a side ({mm / NET_REPEAT / NET_SIZE:.3f} mm a px), {NET_REPEAT} a motif tile: '
            f'{NET_COLS} x {NET_ROWS} holes, {mm / NET_REPEAT / NET_COLS:.2f} mm apart, threads '
            f'{NET_THREAD_MM} mm. lace_border.png: RGB8, {BORDER_W} x {BORDER_H}, {TILE_M} x '
            f'{TILE_M * BORDER_H / BORDER_W:.2f} m, wraps along x. Mean coverage: net '
            f'{net.mean():.2f}, field {tile.mean():.2f}. Thread {THREAD}, roughness {ROUGH}, no map.')
    write_contact(out, note)
    print(note)


def write_contact(out, note):
    def fig(src, caption, cls=''):
        return f'<figure class="{cls}"><img src="{src}"><figcaption>{caption}</figcaption></figure>'

    old = '../materials-lace/'
    rows = [
        ('The textures', [
            fig('lace_motif.png', 'lace_motif: the flowers (L8)'),
            fig('lace_net_4x4.png', 'lace_net 4x4 (14 cm): thread on dark, backlit', 'wide'),
            fig('lace_border_rgb.png', 'lace_border: R lace, G cloth, B field shows', 'wide'),
        ]),
        ('The field, net and flowers together', [
            fig('lace_close.png', 'close up, 14 cm: on dark, backlit', 'wide'),
            fig('lace_mask.png', 'coverage, one tile (averaged to 1024 px)'),
            fig('lace_preview.png', 'the thread on dark'),
            fig('lace_backlit.png', 'lit from behind: a sunlit window'),
            fig('lace_mask_3x3.jpg', 'coverage tiled 3x3 (1.7 m)'),
            fig('lace_backlit_3x3.jpg', 'backlit tiled 3x3'),
            fig('lace_preview_3x3.jpg', 'thread tiled 3x3'),
            fig('lace_mask_far.png', 'from afar: an eighth, 6x6 (3.4 m)'),
            fig('lace_backlit_far.png', 'backlit from afar'),
            fig('lace_preview_far.png', 'thread from afar'),
        ]),
        ('The hem', [
            fig('lace_hem_front.jpg', 'the hem under the field, 1.1 m: on dark', 'wide'),
            fig('lace_hem_backlit.jpg', 'backlit', 'wide'),
        ]),
        ('The download and the old bake', [
            fig('library-lace-01.jpg', 'library-lace-01 (the download)'),
            fig('lace_field.jpg', 'the field\'s coverage, light out (source px)'),
            fig(old + 'lace_backlit.png', 'old: backlit'),
            fig(old + 'lace_backlit_3x3.jpg', 'old: backlit 3x3'),
            fig(old + 'lace_mask_far.png', 'old: mask from afar'),
        ]),
    ]
    body = '\n'.join(f'<h2>{t}</h2><div class="row">{"".join(f)}</div>' for t, f in rows)
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Library lace</title>
<style>
:root {{ --bg: #1b1a19; --fg: #e8e4dc; --muted: #a39d92; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif;
       margin: 0; padding: 16px 24px 48px; }}
h1 {{ font-size: 22px; margin: 8px 0 4px; }}
h2 {{ font-size: 17px; margin: 28px 0 8px; }}
p {{ color: var(--muted); margin: 0 0 12px; max-width: 80ch; }}
.row {{ display: flex; flex-wrap: wrap; gap: 14px; align-items: flex-start; }}
figure {{ margin: 0; width: 420px; max-width: 100%; }}
figure.wide {{ width: 860px; }}
img {{ width: 100%; display: block; background: #000; }}
figcaption {{ color: var(--muted); font-size: 13px; margin-top: 4px; }}
</style></head><body>
<h1>Library lace</h1>
<p>Baked by tools/materials/lace.py. {note} Click an image to open it full size.</p>
{body}
<script>document.querySelectorAll('img').forEach(i => i.onclick = () => window.open(i.src));</script>
</body></html>
'''
    path = os.path.join(out, 'contact.html')
    with open(path, 'w') as f:
        f.write(html)
    print('wrote', path)


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    os.makedirs(sys.argv[1], exist_ok=True)
    bake(sys.argv[1])
