#!/usr/bin/env python3
"""Bakes the library's lace curtains from library-lace-01.png: a cut-out mask, tileable.

    python3 tools/materials/lace.py OUT_DIR

Writes lace_mask.png (L8, linear): the thread's coverage, 0 where light passes and 1
where it is solid; the shader cuts or blends with it and tints the thread THREAD with
roughness ROUGH (no map). The download is a whole curtain on black, lit from the front
with folds painted in; the black behind it is what the holes show, so a pixel's
brightness over the thread's own lit brightness there is its coverage. The thread's
brightness is found locally (it carries the light and folds) and divided out; what is
left of the folds, the net's density changing across them, is evened out too. The field
between the selvedges and above the scalloped border is cut into a tile.
Also writes previews: lace_preview.png (the thread on dark), lace_backlit.png (lit from
behind, as a sunlit window), their 3x3 and far tilings, and contact.html.
"""

import os
import sys

import numpy as np
from PIL import Image

import common as cm

SIZE = 1024             # px a side; one tile is the whole repeat
TILE_M = 0.70           # metres a tile covers, both ways: the net's mesh comes out 2.7 mm
                        # (Nottingham curtain net, 8 to 10 point, is 2.5 to 3 mm), its flowers
                        # 4 to 5 cm, its trails 25 to 30 cm apart
FIELD = (30, 0, 994)    # x0, y0, x1 of the field in the download: inside the selvedges
OVERLAP = 96            # source px the edges overlap for the seam cut
WHITE_BLOCK = 48        # px: the thread's lit brightness is a high percentile per block,
WHITE_PCT = 97          # then smoothed over WHITE_SMOOTH px
WHITE_SMOOTH = 40
SOLID = 0.60            # coverage above this is cloth-work: pushed toward solid, as its
SOLID_PUSH = 0.85       # painted shading is light, not holes; its veins stay a little open
NET_SMOOTH = 28         # px: the net's density is evened out over this scale
FOLD_WIDTH = 81         # px: straight bands down the curtain narrower than about half this
                        # are folds
SOFTEN = 0.5            # px of blur on the tile before the resize: drops the download's
                        # 2 px compression ripple
THREAD = '#ddd3bf'      # guess: sRGB albedo, off-white cotton, warm and aged
ROUGH = 0.9             # cotton
TRANSMIT = 0.12         # guess: share of the light behind that a thread lets through, warm


def blur(a, sigma, wrap=False):
    """Gaussian blur through the spectrum; mirrored at the edges unless wrap."""
    h, w = a.shape
    m = a if wrap else np.concatenate([np.concatenate([a, a[::-1]], 0),
                                       np.concatenate([a[:, ::-1], a[::-1, ::-1]], 0)], 1)
    fy = np.fft.fftfreq(m.shape[0])[:, None]
    fx = np.fft.fftfreq(m.shape[1])[None, :]
    g = np.exp(-2 * (np.pi * sigma) ** 2 * (fy * fy + fx * fx))
    return np.real(np.fft.ifft2(np.fft.fft2(m) * g))[:h, :w].astype(np.float32)


def coverage(lum):
    """Coverage 0..1 from the curtain's linear brightness on black."""
    h, w = lum.shape
    b = WHITE_BLOCK
    hb, wb = -(-h // b), -(-w // b)
    pad = np.pad(lum, ((0, hb * b - h), (0, wb * b - w)), mode='reflect')
    blocks = pad.reshape(hb, b, wb, b).transpose(0, 2, 1, 3).reshape(hb, wb, -1)
    white = np.percentile(blocks, WHITE_PCT, axis=2).astype(np.float32)
    white = cm.resize(white, w, h)
    white = blur(white, WHITE_SMOOTH)
    c = np.clip(lum / np.maximum(white, 1e-3), 0, 1)

    # The folds' highlights: bands straight down the whole curtain, a few px to 30 px
    # wide, which nothing in the design is. A column's lower percentile is its net (the
    # motifs are scattered); its running median across FOLD_WIDTH px is what the net
    # should be. Scale the net and the cloth-work's open parts to it.
    col = np.percentile(c, 30, 0)
    pad = np.pad(col, FOLD_WIDTH // 2, mode='reflect')
    ref = np.median(np.lib.stride_tricks.sliding_window_view(pad, FOLD_WIDTH), 1)
    k = np.exp(-0.5 * (np.arange(-24, 25) / 8.0) ** 2)
    ref = np.convolve(np.pad(ref, 24, mode='reflect'), k / k.sum(), 'valid')
    fold = np.clip(ref / np.maximum(col, 1e-3), 0.4, 2.0)
    away = 1 - np.clip((c - 0.75) / 0.2, 0, 1)
    c = c * (1 + (fold[None, :] - 1) * away)

    # The cloth-work: solid where the smoothed coverage is high; its shading goes.
    solid = np.clip((blur(c, 2.5) - SOLID + 0.1) / 0.2, 0, 1)
    c = c + (1 - c) * solid * SOLID_PUSH

    # The net: its density, measured where there is neither cloth-work nor a big hole,
    # varies with the painted folds. Scale it to its overall mean.
    open_ = 1 - np.clip((0.15 - blur(c, 3.0)) / 0.1, 0, 1)
    net = (1 - solid) * open_
    local = blur(c * net, NET_SMOOTH) / np.maximum(blur(net, NET_SMOOTH), 1e-3)
    mean = (c * net).sum() / net.sum()
    gain = np.clip(mean / np.maximum(local, 1e-3), 0.6, 1.6)
    c = c * (1 + (gain - 1) * (1 - solid))

    return np.clip(c, 0, 1), white


def tiled(a, n):
    return np.tile(a, (n, n) + (1,) * (a.ndim - 2))


def save_jpg(path, a):
    Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(path, quality=90)
    print(f'wrote {path}')


def bake(out):
    src_path = cm.source('library-lace-01.png')
    src = cm.load(src_path)
    x0, y0, x1 = FIELD
    t = x1 - x0 - OVERLAP                 # the tile's side in source px, square
    field = src[y0:y0 + t + OVERLAP, x0:x1]
    lum = cm.to_linear(field) @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    c, white = coverage(lum)

    tile = cm.seam_tile(c, OVERLAP, cost_img=blur(c, 1.5))
    tile = np.clip(cm.resize_periodic(tile, SIZE, SIZE, SOFTEN), 0, 1)
    cm.save(os.path.join(out, 'lace_mask.png'), tile)

    # Previews, in linear light.
    thread = cm.to_linear(cm.hex_rgb(THREAD))
    dark = cm.to_linear(cm.hex_rgb('#2a2622'))
    front = dark + (thread - dark) * tile[..., None]
    cm.save(os.path.join(out, 'lace_preview.png'), cm.to_srgb(front))

    # Backlit: a sunlit window behind, the room dim in front. Light through the holes;
    # the threads dark, but a little light comes through them, warmed by the cotton.
    sky = np.array([1.0, 0.97, 0.92], np.float32)
    room = 0.05
    through = TRANSMIT * thread * np.array([1.0, 0.9, 0.7], np.float32)
    back = (1 - tile[..., None]) * sky + tile[..., None] * (through * sky + room * thread)
    cm.save(os.path.join(out, 'lace_backlit.png'), cm.to_srgb(back))

    # Tiled 3x3, and from afar: an eighth, averaged as a mip level would (the mask
    # as it is, the colours in linear light), 6x6.
    mask = np.repeat(tile[..., None], 3, 2)
    for name, img, far in (('lace_mask', mask, mask.reshape(SIZE // 8, 8, SIZE // 8, 8, 3).mean((1, 3))),
                           ('lace_preview', cm.to_srgb(front), cm.downscale(cm.to_srgb(front), 8)),
                           ('lace_backlit', cm.to_srgb(back), cm.downscale(cm.to_srgb(back), 8))):
        big = tiled(img, 3)
        save_jpg(os.path.join(out, f'{name}_3x3.jpg'), cm.resize(big, SIZE * 3 // 2, SIZE * 3 // 2))
        save_jpg(os.path.join(out, f'{name}_far.png'), tiled(far, 6))

    # Before and after the light comes out, the field as cut, side by side.
    flat = np.concatenate([cm.to_srgb(lum), np.clip(cm.to_srgb(white), 0, 1), c], 1)
    save_jpg(os.path.join(out, 'lace_field.jpg'), np.repeat(flat[..., None], 3, 2))
    Image.open(src_path).convert('RGB').save(os.path.join(out, 'library-lace-01.jpg'), quality=90)

    px_mm = TILE_M * 1000 / SIZE
    note = (f'lace_mask.png: L8, {SIZE} px a side, one tile {TILE_M} m both ways '
            f'({SIZE / TILE_M / 100:.1f} px/cm, {px_mm:.2f} mm a px). Thread {THREAD}, '
            f'roughness {ROUGH}, no map. Cut from {t} source px a side.')
    write_contact(out, note)
    print(note)


def write_contact(out, note):
    def fig(src, caption, cls=''):
        return f'<figure class="{cls}"><img src="{src}"><figcaption>{caption}</figcaption></figure>'

    figs = [
        fig('lace_mask.png', 'the mask: coverage, white solid'),
        fig('lace_preview.png', 'the thread on dark, flat'),
        fig('lace_backlit.png', 'lit from behind: a sunlit window'),
        fig('lace_mask_3x3.jpg', 'mask tiled 3x3 (2.1 m)'),
        fig('lace_backlit_3x3.jpg', 'backlit tiled 3x3'),
        fig('lace_preview_3x3.jpg', 'thread tiled 3x3'),
        fig('lace_mask_far.png', 'mask from afar: an eighth, 6x6 (4.2 m)'),
        fig('lace_backlit_far.png', 'backlit from afar'),
        fig('lace_preview_far.png', 'thread from afar'),
        fig('lace_field.jpg', 'the field: brightness, the thread\'s light found, coverage', 'wide'),
        fig('library-lace-01.jpg', 'library-lace-01 (the download)'),
    ]
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Library lace</title>
<style>
:root {{ --bg: #1b1a19; --fg: #e8e4dc; --muted: #a39d92; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif;
       margin: 0; padding: 16px 24px 48px; }}
h1 {{ font-size: 22px; margin: 8px 0 4px; }}
p {{ color: var(--muted); margin: 0 0 12px; max-width: 70ch; }}
.row {{ display: flex; flex-wrap: wrap; gap: 14px; align-items: flex-start; }}
figure {{ margin: 0; width: 420px; max-width: 100%; }}
figure.wide {{ width: 1280px; }}
img {{ width: 100%; display: block; background: #000; }}
figcaption {{ color: var(--muted); font-size: 13px; margin-top: 4px; }}
</style></head><body>
<h1>Library lace</h1>
<p>Baked by tools/materials/lace.py. {note} Click an image to open it full size.</p>
<div class="row">{"".join(figs)}</div>
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
