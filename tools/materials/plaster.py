#!/usr/bin/env python3
"""Bakes the library's plaster: limewash on the sills, the niches' reveals and the ceiling.

    python3 tools/materials/plaster.py OUT_DIR [--contact]

Writes, all L8 and tileable, one tile TILE_M a side:
- plaster_tone.png: the limewash's tone. The shader tints it from two colours, SHADE
  where it is 0 and LIGHT where it is 1, mixed in linear light (as the wallpaper's mask).
  One channel and not RGB: limewash varies along one line, darker and a little warmer or
  lighter and cooler, so RGB would hold the same thing three times; and the shader can
  move both colours for the season or the age masks without a second texture.
- plaster_rough.png: perceptual roughness, about 0.86 to 0.94.
- plaster_height.png: the trowel's unevenness, 1 high, 0 low, HEIGHT_MM deep in all.
  Gentle: it shows only in raking light. Tone and height may share one RG8 texture.
- plaster_preview.png: the tone tinted here (RGB, sRGB albedo), to look at.
With --contact, also previews and contact.html in OUT_DIR. At 1024 px each L8 map is
1 MB, 1.4 MB with mips; the tile is 4 m, so detail below a centimetre is not in it.

Left to the shader, in world space, with masks of its own: the age. Soot greying above
and beside the stove and in a soft ring on the ceiling over the chandelier; a darker,
greyer film into the ceiling's corners and along the cornice; and on the sills, wear and
a little more sheen (lower roughness) where hands and things rest, at the front edge.
The tone map holds none of it, so the same tile serves all three places. On the 9 by 7 m
ceiling the tile repeats about twice each way; if that shows, the shader can scale the
tone by a slow world-space noise, which the age masks may want anyway.
"""

import os
import sys

import numpy as np

import common as cm

SIZE = 1024             # px a side
TILE_M = 4.0            # metres a tile covers (2.6 px/cm): the metre-scale tone needs
                        # room for many patches a tile, or the repeat shows
SEED = 23

SHADE = '#d5cab5'       # guess, to check under our light: sRGB albedo at tone 0
LIGHT = '#efebe1'       # guess: sRGB albedo at tone 1, warm off-white
ROUGH_MEAN = 0.90       # guess: matte limewash
ROUGH_VAR = 0.04        # guess: +- across the fine mottle and the trowel's flats
HEIGHT_MM = 1.2         # the height map's full range

# The tone's parts, each of standard deviation 1 times these weights before they are summed.
BROAD = 1.0             # patches about 0.8 m across (waves BROAD_M long)
MID = 0.35              # about 20 cm
BRUSH = 0.20            # the brush's cloudiness: soft patches streaked along a stroke
MOTTLE = 0.35           # fine limewash mottle, about a centimetre
BROAD_M, MID_M, MOTTLE_M = 1.6, 0.4, 0.02
RIDGE_TONE = 0.12       # lime gathers a little lighter on the trowel's ridges
TONE_MEAN = 0.6         # the tone's mean, and its standard deviation, after the parts are summed
TONE_SPREAD = 0.11

TROWEL_STROKES = 520    # per tile
TROWEL_LEN_CM = (22, 45)    # half-length of a stroke
TROWEL_WIDTH_CM = (9, 16)   # half-width
BRUSH_STROKES = 900
BRUSH_LEN_CM = (10, 22)
BRUSH_WIDTH_CM = (5, 10)


def blur(a, sigma):
    """Gaussian blur that wraps, through the spectrum; sigma in px."""
    f = np.fft.fftfreq(a.shape[0])
    g = np.exp(-2 * (np.pi * sigma) ** 2 * f * f)
    return np.real(np.fft.ifft2(np.fft.fft2(a) * np.outer(g, g))).astype(np.float32)


def band(wavelength_m, seed, octave_width=0.6):
    """Isotropic noise of features about wavelength_m across, wrapping, std 1: white
    noise filtered in the spectrum. Unlike lattice noise it has no rows or columns, which
    at a few cells a tile show as the tile's grid from afar."""
    rng = np.random.default_rng(seed)
    f = np.fft.fftfreq(SIZE) * SIZE  # cycles a tile
    k = np.hypot(f[:, None], f[None, :])
    k0 = TILE_M / wavelength_m
    g = np.exp(-0.5 * (np.log2(np.maximum(k, 1e-6) / k0) / octave_width) ** 2)
    # No tile-wide waves along the axes: they make rows or columns that run on from tile
    # to tile and show the grid.
    g[(k < 3.5) & ((f[:, None] == 0) | (f[None, :] == 0))] = 0
    a = np.real(np.fft.ifft2(np.fft.fft2(rng.standard_normal((SIZE, SIZE))) * g))
    return (a / a.std()).astype(np.float32)


def normalise(a, lo=0.5, hi=99.5):
    p0, p1 = np.percentile(a, [lo, hi])
    return np.clip((a - p0) / (p1 - p0), 0, 1)


def stamps(count, len_cm, width_cm, seed):
    """Yields elongated soft patches at random spots, angles and sizes, wrapping:
    (index, along, across, mask, edge, rng), index the patch's box in the tile, along and
    across in -1..1 of its half-length and half-width, mask its soft inside, edge a band
    at its rim, rng for the caller's own draws."""
    px_cm = SIZE / (TILE_M * 100)
    rng = np.random.default_rng(seed)
    for _ in range(count):
        cx, cy = rng.uniform(0, SIZE, 2)
        ang = rng.uniform(0, np.pi)
        L = rng.uniform(*len_cm) * px_cm
        W = rng.uniform(*width_cm) * px_cm
        bend = rng.uniform(-0.35, 0.35)  # the arc a trowel or brush sweeps
        R = int(L + W) + 2
        rows = (np.arange(int(cy) - R, int(cy) + R + 1)) % SIZE
        cols = (np.arange(int(cx) - R, int(cx) + R + 1)) % SIZE
        dy = np.arange(-R, R + 1, dtype=np.float32)[:, None] + (int(cy) - cy)
        dx = np.arange(-R, R + 1, dtype=np.float32)[None, :] + (int(cx) - cx)
        a = (dx * np.cos(ang) + dy * np.sin(ang)) / L
        b = (-dx * np.sin(ang) + dy * np.cos(ang)) / W
        b = b - bend * (a * a - 0.33)
        r = np.sqrt(a * a + b * b)
        soft = rng.uniform(0.5, 0.9)
        m = np.clip((1 - r) / soft, 0, 1)
        m = m * m * (3 - 2 * m)
        edge = np.exp(-((r - 1) / 0.3) ** 2)
        yield np.ix_(rows, cols), a, b, m, edge, rng


def trowel():
    """The height: overlapping trowel strokes, each a near-flat facet laid over the
    plaster before it, with a soft ridge where it squeezed plaster out at its rim."""
    h = band(0.8, SEED + 1) * 0.1
    ridges = np.zeros((SIZE, SIZE), np.float32)
    for ix, a, b, m, edge, rng in stamps(TROWEL_STROKES, TROWEL_LEN_CM, TROWEL_WIDTH_CM, SEED + 2):
        under = h[ix]
        level = (under * m).sum() / max(m.sum(), 1e-6) + rng.normal(0, 0.06)
        tilt = rng.normal(0, 0.10, 2)
        facet = level + tilt[0] * a + tilt[1] * b
        h[ix] = under * (1 - m) + facet * m
        rid = edge * rng.uniform(0.02, 0.06) * np.clip(a + 0.5, 0, 1)  # most at the trailing rim
        h[ix] += rid
        ridges[ix] += rid
    h = blur(h, 3.0)
    return normalise(h, 0.2, 99.8), blur(ridges, 2)


def brush():
    """The limewash's cloudiness: soft patches where the coat lies thicker or thinner,
    each faintly streaked along its stroke."""
    px_cm = SIZE / (TILE_M * 100)
    t = np.zeros((SIZE, SIZE), np.float32)
    for ix, a, b, m, edge, rng in stamps(BRUSH_STROKES, BRUSH_LEN_CM, BRUSH_WIDTH_CM, SEED + 3):
        L = a.shape[0] / px_cm  # cm, roughly the patch's span
        seed = int(rng.integers(1 << 20))
        streak = cm.value_noise(a * L / 12.0 + seed % 97, b * L / 2.5, seed)
        coat = rng.normal(0, 0.3) + 0.3 * (streak - 0.5)
        t[ix] = t[ix] * (1 - 0.4 * m) + coat * 0.4 * m
    return blur(t, 2.0)


def bake(out):
    height, ridges = trowel()
    px_cm = SIZE / (TILE_M * 100)
    brush_ = brush()
    brush_ /= brush_.std()
    tone = (BROAD * band(BROAD_M, SEED + 10, 0.5)
            + MID * band(MID_M, SEED + 11)
            + BRUSH * brush_
            + MOTTLE * band(MOTTLE_M, SEED + 12, 1.0)
            + RIDGE_TONE * ridges / ridges.std())
    z = (tone - tone.mean()) / tone.std()
    # Soft-limited, so no lone patch stands out and marks the repeat.
    tone = np.clip(TONE_MEAN + TONE_SPREAD * 3 * np.tanh(z / 3), 0, 1)

    fine = np.clip(band(MOTTLE_M, SEED + 13, 1.0) / 2, -1, 1)
    # The trowel pressed its flats a little smoother than the slopes between them.
    flat = 1 - normalise(np.hypot(*np.gradient(blur(height, 2))))
    rough = ROUGH_MEAN + ROUGH_VAR * (0.7 * fine + 0.6 * (0.5 - flat))
    rough = np.clip(rough, ROUGH_MEAN - ROUGH_VAR, ROUGH_MEAN + ROUGH_VAR)

    cm.save(os.path.join(out, 'plaster_tone.png'), tone)
    cm.save(os.path.join(out, 'plaster_rough.png'), rough)
    cm.save(os.path.join(out, 'plaster_height.png'), height)
    cm.save(os.path.join(out, 'plaster_preview.png'), albedo(tone))
    print(f'tile {TILE_M} m a side, {px_cm:.1f} px/cm; shade {SHADE}, light {LIGHT}; '
          f'roughness {rough.min():.2f}-{rough.max():.2f}; height {HEIGHT_MM} mm')
    return tone, rough, height


def albedo(tone):
    shade, light = cm.to_linear(cm.hex_rgb(SHADE)), cm.to_linear(cm.hex_rgb(LIGHT))
    return cm.to_srgb(shade + (light - shade) * tone[..., None])


# Previews.

WARM = np.array([1.0, 0.9, 0.78])  # an autumn window light, linear, relative


def lit(tone, height, elevation_deg, azimuth_deg, gain):
    """The albedo under one light at a given elevation over the surface, plus a little
    sky, with the height's normals (Lambert only)."""
    px_mm = SIZE / (TILE_M * 1000)
    hm = height * HEIGHT_MM
    gx = (np.roll(hm, -1, 1) - np.roll(hm, 1, 1)) * px_mm / 2
    gy = (np.roll(hm, -1, 0) - np.roll(hm, 1, 0)) * px_mm / 2
    n = np.stack([-gx, -gy, np.ones_like(gx)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    e, az = np.radians(elevation_deg), np.radians(azimuth_deg)
    ldir = np.array([np.cos(e) * np.cos(az), np.cos(e) * np.sin(az), np.sin(e)])
    ndl = np.clip(n @ ldir, 0, None) / np.sin(e)  # 1 on the mean surface
    col = cm.to_linear(albedo(tone)) * (gain * WARM * ndl[..., None] + 0.08)
    return cm.to_srgb(col)


def style_crops(out):
    from PIL import Image
    src = Image.open(cm.source('style-01.png'))
    crops = {'ceiling': (760, 0, 1500, 120), 'reveal': (60, 0, 420, 140),
             'sill': (60, 600, 420, 680)}
    for k, box in crops.items():
        src.crop(box).convert('RGB').save(os.path.join(out, f'c_style_{k}.jpg'), quality=90)
    return list(crops)


def contact(out, tone, rough, height):
    from PIL import Image

    def save8(a, name):
        Image.fromarray((np.clip(a, 0, 1) * 255 + 0.5).astype(np.uint8)).save(os.path.join(out, name))

    pv = albedo(tone)
    big = np.tile(pv, (3, 3, 1))
    Image.fromarray((big * 255 + 0.5).astype(np.uint8)).resize((1536, 1536), Image.LANCZOS).save(
        os.path.join(out, 'c_plaster_3x3.jpg'), quality=90)
    save8(np.tile(cm.downscale(pv, 8), (6, 6, 1)), 'c_plaster_far.png')
    save8(cm.downscale(np.tile(lit(tone, height, 8, 20, 0.9), (2, 2, 1)), 2), 'c_plaster_raking.png')
    save8(cm.downscale(np.tile(lit(tone, height, 55, 20, 0.9), (2, 2, 1)), 2), 'c_plaster_flat.png')
    save8(lit(tone, height, 8, 20, 0.9)[:384, :512], 'c_plaster_raking_1to1.png')
    save8(pv[:384, :512], 'c_plaster_1to1.png')
    crops = style_crops(out)
    crop = f'{512 * TILE_M / SIZE:.1f} x {384 * TILE_M / SIZE:.1f} m'

    def fig(src, caption):
        return f'<figure><img src="{src}"><figcaption>{caption}</figcaption></figure>'

    figs = [
        fig('plaster_preview.png', f'albedo, flat: tone tinted {SHADE} to {LIGHT}'),
        fig('c_plaster_3x3.jpg', f'tiled 3x3 ({3 * TILE_M:g} m)'),
        fig('c_plaster_far.png', f'from afar: an eighth, 6x6 ({6 * TILE_M:g} m)'),
        fig('c_plaster_raking.png', f'2x2 tiles, a warm light 8 degrees over the surface ({HEIGHT_MM} mm relief)'),
        fig('c_plaster_flat.png', '2x2 tiles, the same light 55 degrees over it'),
        fig('c_plaster_1to1.png', f'albedo 1:1, {crop}'),
        fig('c_plaster_raking_1to1.png', f'raking 1:1, {crop}'),
        fig('plaster_tone.png', 'tone (L8)'),
        fig('plaster_rough.png', f'roughness (L8): {rough.min():.2f}-{rough.max():.2f}'),
        fig('plaster_height.png', f'height (L8): {HEIGHT_MM} mm in all'),
    ] + [fig(f'c_style_{k}.jpg', f'style-01, the {k}') for k in crops]
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Library plaster</title>
<style>
:root {{ --bg: #1b1a19; --fg: #e8e4dc; --muted: #a39d92; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif;
       margin: 0; padding: 16px 24px 48px; }}
h1 {{ font-size: 22px; margin: 8px 0 4px; }}
p {{ color: var(--muted); margin: 0 0 12px; max-width: 70ch; }}
.row {{ display: flex; flex-wrap: wrap; gap: 14px; align-items: flex-start; }}
figure {{ margin: 0; width: 420px; max-width: 100%; }}
img {{ width: 100%; display: block; background: #000; }}
figcaption {{ color: var(--muted); font-size: 13px; margin-top: 4px; }}
</style></head><body>
<h1>Library plaster</h1>
<p>Baked by tools/materials/plaster.py: limewash for the sills, the niches' reveals and the
ceiling. {SIZE} px, one tile {TILE_M:g} m a side ({SIZE / TILE_M / 100:.1f} px/cm). Tone, roughness
and height, each L8. The age (soot, corners, worn sills) is the shader's, in world space.
Click an image to open it full size.</p>
<div class="row">{"".join(figs)}</div>
<script>document.querySelectorAll('img').forEach(i => i.onclick = () => window.open(i.src));</script>
</body></html>
'''
    with open(os.path.join(out, 'contact.html'), 'w') as f:
        f.write(html)
    print('wrote', os.path.join(out, 'contact.html'))


if __name__ == '__main__':
    args = [a for a in sys.argv[1:] if a != '--contact']
    if len(args) != 1:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    maps = bake(args[0])
    if '--contact' in sys.argv:
        contact(args[0], *maps)
