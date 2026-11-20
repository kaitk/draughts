#!/usr/bin/env python3
"""Bakes the view out of the library's windows: the sky, the far band of trees, the oak.

    python3 -I tools/materials/outside.py OUT_DIR [--preview]

Sources: task 109's park panels and oak in design/manor/outside/ (local; MANOR_DIR
points at another checkout's design/manor). The layers as design/manor/outside/park.py
put them together, made ready for the room to draw. Azimuths are degrees from straight
out of the window, right positive; elevations degrees over the horizon.

- outside_sky.png: RGB, equirectangular, azimuth -90..90, elevation -30..90, 4 px a
  degree: our sky, the sun's glow at SUN, autumn's late afternoon; below the horizon a
  plain lawn, which the band's own lawn covers but where it ends.
- outside_band.png: RGBA, premultiplied in linear light, sRGB encoded: the three far
  panels joined on a cylinder BAND_M out, their skies cut, the haze kept;
  azimuth -64..64 at 16 px a degree, rows linear in height on the cylinder. Its ends
  past the panels (+-47 deg) are mirrored, for the oblique views.
- outside_oak.png: RGBA as the band: the oak, OAK_H tall, a billboard OAK_M out.
- outside.txt: the numbers the renderer needs.
The band and the oak are pre-blurred a little (BAND_BLUR, OAK_BLUR): they are magnified
on every screen, so they need no mips, and the depth of field will blur them more.
With --preview, the layers through the light tuner's window and the shell's three, as the
renderer would draw them, and index.html.
"""

import math
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # python3 -I leaves it out
import common as cm  # noqa: E402

F = 1024.0              # work px a radian; the panels' 24 mm focal length in px
EYE = 2.2               # m over the lawn the panels were joined from (the games table)
PATH_M = 60.0           # the path along the lawn's far edge, by the trees' size
PANELS = [              # file, centre azimuth (deg), path row at its middle
    ('library-far-left-01.png', -50.0, 530),
    ('library-far-01.png', 0.0, 538),
    ('library-far-right-01.png', 50.0, 543),
]
SEAMS = [-25.0, 25.0]   # where one panel gives way to the next, in the panels' angles
LAWN_SEAM = 16.0        # the panels' lawns blended over this, in the panels' angles
SUN = (-20.0, 18.0)     # azimuth, elevation
BAND_M = 110.0          # the tree line's distance
OAK_M, OAK_AZ, OAK_H = 70.0, 22.0, 20.0

SKY_PX = 4              # px a degree
SKY_AZ, SKY_EL = (-90.0, 90.0), (-30.0, 90.0)
BAND_PX = 16
BAND_AZ = 64.0          # +- degrees; the windows' straight reveals pass +-58
BAND_LOW = -8.0         # elevation of the band's foot, faded over the last BAND_FADE
BAND_FADE = 2.5
BAND_BLUR = 0.25        # degrees, a Gaussian's sigma
OAK_PX = 24             # px a degree at OAK_M
OAK_BLUR = 0.06

ZENITH, HOR_COOL, HOR_WARM, CORE = '#9fb3cf', '#d6dde6', '#f3d6aa', '#fff3d6'


def box(a, r, axis):
    c = np.cumsum(np.pad(a, [(r + 1, r) if i == axis else (0, 0) for i in range(a.ndim)], mode='edge'), axis)
    n = a.shape[axis]
    return (np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis) - np.take(c, np.arange(n), axis)) / (2 * r + 1)


def blur(a, sigma):
    """Three box passes each way, near a Gaussian of `sigma` px."""
    r = int(round((math.sqrt(4 * sigma * sigma + 1) - 1) / 2))
    for _ in range(3 if r > 0 else 0):
        a = box(box(a, r, 0), r, 1)
    return a


def fill(v, ok):
    """Carries the nearest known value into gaps, along axis 0."""
    idx = np.where(ok, np.arange(len(ok)), 0)
    np.maximum.accumulate(idx, out=idx)
    idx[:np.argmax(ok)] = np.argmax(ok)
    return v[idx]


def sky_alpha(c, path_row):
    """The panel's sky as a smooth field, a color per row plus an offset per column,
    fitted to the pixels taken as sky; a pixel's alpha is how far its color is from it."""
    h, w = c.shape[:2]
    m = np.zeros((h, w), np.float32)
    m[:100] = 1
    col = np.zeros((w, 3), np.float32)
    for _ in range(6):
        n = m.sum(1)
        row = fill((m[..., None] * (c - col[None])).sum(1) / np.maximum(n, 1)[:, None], n > 15)
        n2 = m.sum(0)
        col = fill((m[..., None] * (c - row[:, None])).sum(0) / np.maximum(n2, 1)[:, None], n2 > 5)
        col = box(col, 60, 0)
        d = np.sqrt(((c - row[:, None] - col[None]) ** 2).sum(-1))
        m = (d < 0.05).astype(np.float32)
        m[path_row - 30:] = 0
    a = np.clip((d - 0.03) / 0.07, 0, 1)
    a[path_row - 8:] = 1
    # Where the tree line is low the fit misses the sky's gradient: the sky is also what
    # is smooth all the way down from the top, and just under that edge what is still
    # its color.
    lum = c @ np.array([0.2126, 0.7152, 0.0722], np.float32)
    mean = box(box(lum, 3, 0), 3, 1)
    sd = np.sqrt(np.maximum(box(box(lum * lum, 3, 0), 3, 1) - mean * mean, 0))
    top = np.cumprod(sd < 0.012, axis=0)
    top[path_row - 60:] = 0
    edge = top.sum(0)
    ref = c[np.maximum(edge - 2, 0), np.arange(w)]
    rows = np.arange(h)[:, None]
    near = (rows >= edge) & (rows < edge + 8)
    a_edge = np.clip((np.sqrt(((c - ref[None]) ** 2).sum(-1)) - 0.03) / 0.07, 0, 1)
    return np.minimum(a, np.where(near, a_edge, 1 - top))


def bilinear(img, x, y):
    x = np.clip(x, 0, img.shape[1] - 1.001)
    y = np.clip(y, 0, img.shape[0] - 1.001)
    x0, y0 = x.astype(int), y.astype(int)
    fx, fy = (x - x0)[..., None], (y - y0)[..., None]
    return (img[y0, x0] * (1 - fx) * (1 - fy) + img[y0, x0 + 1] * fx * (1 - fy)
            + img[y0 + 1, x0] * (1 - fx) * fy + img[y0 + 1, x0 + 1] * fx * fy)


def sky_color(az, el):
    """park.py's sky at azimuth and elevation (radians), sRGB."""
    s_az, s_el = map(math.radians, SUN)
    c = np.sin(el) * math.sin(s_el) + np.cos(el) * math.cos(s_el) * np.cos(az - s_az)
    ang = np.degrees(np.arccos(np.clip(c, -1, 1)))[..., None]
    up = np.clip(el / math.radians(40), 0, 1)[..., None]
    warm = np.exp(-(ang / 45) ** 2)
    hor = cm.hex_rgb(HOR_COOL) * (1 - warm) + cm.hex_rgb(HOR_WARM) * warm
    s = hor * (1 - up) + cm.hex_rgb(ZENITH) * up
    return s + (cm.hex_rgb(CORE) - s) * np.exp(-(ang / 7) ** 2)


def band_work():
    """The band at F px a radian, columns linear in azimuth over +-BAND_AZ, rows linear
    in tan(elevation): premultiplied sRGB color and alpha, and the horizon's row."""
    k = BAND_M / PATH_M         # farther: the same angles hold k times less
    w = int(F * math.radians(2 * BAND_AZ))
    top, low = math.tan(math.radians(22)), math.tan(math.radians(BAND_LOW))
    v0 = int(F * top)
    h = v0 + int(-F * low)
    az = (np.arange(w) - w / 2 + 0.5) / F
    edge = max(abs(a) for _, a, _ in PANELS) + 36.5
    reach = math.radians(edge) / k  # what the panels cover; mirrored past it
    az = np.where(az > reach, 2 * reach - az, np.where(az < -reach, -2 * reach - az, az))
    edges = [-1e9] + [math.radians(s) / k for s in SEAMS] + [1e9]
    acc = np.zeros((h, w, 3), np.float32)
    acc_a = np.zeros((h, w, 1), np.float32)
    # The seams: a cut at a trunk through the trees, a broad blend through the lawn.
    el = np.degrees(np.arctan((v0 - np.arange(h) - 0.5) / F))[:, None]
    lawn = np.clip((-1.2 - el) / 1.3, 0, 1)
    feather = 10 / F * (1 - lawn) + math.radians(LAWN_SEAM) / k * lawn
    for i, (name, a, pr) in enumerate(PANELS):
        img = cm.load(cm.source(name))
        alpha = sky_alpha(img, pr)
        hor = pr - F * EYE / PATH_M
        th = az * k - math.radians(a)
        x = F * np.tan(th) + img.shape[1] / 2
        y = (np.arange(h) - v0)[:, None] * k / np.cos(th)[None, :] + hor
        xs = np.broadcast_to(x[None, :], y.shape)
        o = bilinear(np.concatenate([img * alpha[..., None], alpha[..., None]], -1), xs, y)
        inside = (np.abs(th) < math.radians(36.5))[None, :] & (y >= 0) & (y < img.shape[0] - 1)
        sel = np.clip((az - edges[i]) / feather + 0.5, 0, 1) * np.clip((edges[i + 1] - az) / feather + 0.5, 0, 1)
        wgt = (inside * sel)[..., None]
        acc += o[..., :3] * wgt
        acc_a += o[..., 3:] * wgt
    # The foot: faded out above the panels' lowest rows, so the sky's lawn takes over.
    foot = np.clip((el[..., None] - BAND_LOW) / BAND_FADE, 0, 1)
    return acc * foot, acc_a * foot, v0


def premultiplied_linear(rgb_pm, a):
    """Premultiplied sRGB work values to premultiplied linear light, sRGB encoded."""
    straight = rgb_pm / np.maximum(a, 1e-4)
    return cm.to_srgb(cm.to_linear(np.clip(straight, 0, 1)) * a)


def resize4(a, w, h):
    return np.stack([cm.resize(np.ascontiguousarray(a[..., c]), w, h) for c in range(a.shape[2])], -1)


def make(out):
    notes = []
    # The band, its lawn's color for the sky's.
    acc, acc_a, v0 = band_work()
    sig = BAND_BLUR * F * math.pi / 180
    acc, acc_a = blur(acc, sig), blur(acc_a, sig)
    rows = np.where(acc_a[..., 0].max(1) > 0.004)[0]
    r0 = max(rows[0] - 8, 0)
    acc, acc_a = acc[r0:], acc_a[r0:]
    fb = BAND_PX * 180 / math.pi             # output px a radian (and a unit of tan)
    w = int(round(2 * BAND_AZ * BAND_PX))
    h = int(math.ceil(acc.shape[0] * fb / F / 8)) * 8
    pm = resize4(np.concatenate([acc, acc_a], -1), w, h)
    pm[..., 3] = np.clip(pm[..., 3], 0, 1)
    pm[..., :3] = np.clip(pm[..., :3], 0, pm[..., 3:])
    straight = pm[..., :3] / np.maximum(pm[..., 3:], 1e-4)
    near = (pm[..., 3] > 0.98)[int(h * 0.8):]       # the lawn just above the foot's fade
    lawn = cm.to_srgb(cm.to_linear(straight[int(h * 0.8):][near]).mean(0))
    cm.save(f'{out}/outside_band.png', premultiplied_linear(pm[..., :3], pm[..., 3:]), pm[..., 3])
    tan_top = (v0 - r0) / F
    tan_low = tan_top - h / fb
    band_top, band_low = EYE + BAND_M * tan_top, EYE + BAND_M * tan_low
    notes.append(f'band {w}x{h}: azimuth -{BAND_AZ:g}..{BAND_AZ:g} deg, cylinder radius {BAND_M:g} m, '
                 f'its top row {band_top:.2f} m and bottom row {band_low:.2f} m over the lawn '
                 f'(elevations {math.degrees(math.atan(tan_top)):.2f} and {math.degrees(math.atan(tan_low)):.2f} '
                 f'from {EYE:g} m), rows linear in height')

    # The sky, lawn below the horizon: the band's near lawn, darker toward the house.
    sw = int((SKY_AZ[1] - SKY_AZ[0]) * SKY_PX)
    sh = int((SKY_EL[1] - SKY_EL[0]) * SKY_PX)
    az = np.radians(SKY_AZ[0] + (np.arange(sw) + 0.5) / SKY_PX)[None, :]
    el = np.radians(SKY_EL[1] - (np.arange(sh) + 0.5) / SKY_PX)[:, None]
    sky = sky_color(az, np.broadcast_to(el, (sh, sw)))
    down = np.clip(-np.degrees(el) / 30, 0, 1)[..., None]
    ground = lawn * (1 - 0.35 * down)
    haze = np.clip(-np.degrees(el) / 1.0, 0, 1)[..., None]
    sky = np.where(el[..., None] < 0, sky * (1 - haze) + ground * haze, sky)
    cm.save(f'{out}/outside_sky.png', sky)
    notes.append(f'sky {sw}x{sh}: equirectangular, azimuth {SKY_AZ[0]:g}..{SKY_AZ[1]:g}, '
                 f'elevation {SKY_EL[0]:g}..{SKY_EL[1]:g} deg, row 0 the top; sun {SUN}; '
                 f'lawn sRGB ' + ', '.join(f'{v:.3f}' for v in lawn))

    # The oak, its foot on the lawn.
    oak = Image.open(cm.source('library-oak-01.png')).convert('RGBA')
    oak = np.asarray(oak.crop(oak.getbbox()), np.float32) / 255
    a = np.clip((oak[..., 3:] - 0.15) / 0.85, 0, 1)
    oh = int(round(math.degrees(2 * math.atan(OAK_H / 2 / OAK_M)) * OAK_PX / 4)) * 4
    ow = int(round(oak.shape[1] * oh / oak.shape[0] / 4)) * 4
    pm = resize4(np.concatenate([oak[..., :3] * a, a], -1), ow, oh)
    pm = np.concatenate([blur(pm[..., :3], OAK_BLUR * OAK_PX), blur(pm[..., 3:], OAK_BLUR * OAK_PX)], -1)
    pm[..., 3] = np.clip(pm[..., 3], 0, 1)
    pm[..., :3] = np.clip(pm[..., :3], 0, pm[..., 3:])
    cm.save(f'{out}/outside_oak.png', premultiplied_linear(pm[..., :3], pm[..., 3:]), pm[..., 3])
    notes.append(f'oak {ow}x{oh}: {OAK_H * ow / oh:.2f} m wide, {OAK_H:g} m tall, its foot on the lawn '
                 f'{OAK_M:g} m out at azimuth {OAK_AZ:g} deg, facing the band\'s centre')
    with open(f'{out}/outside.txt', 'w') as f:
        f.write('\n'.join(notes) + '\n')
    print('\n'.join(notes))
    return band_top, band_low


# The previews, in the room's frame as the light tuner has it (world units, a metre
# METRE): x along the window's wall, right looking out; y up; z out of the window, the
# wall's inner face at WALL_Z. The tuner's window (--panes 11,12.7,1,0 --opening 3,6,..
# --wall 36,20,-2,2): its middle at WIN_X, 3 x 6 panes 11 x 12.7, bars 1, from SILL up.
METRE = 30.48
WALL_Z, WIN_X, SILL = 36.0, 2.0 - 36.0 * math.tan(math.radians(20)), -2.0
PANES, ACROSS, UP, BAR = (11.0, 12.7), 3, 6, 1.0
LAWN = -23.56 - 1.0 * METRE           # the floor a metre over the lawn
WALL_SRGB = (0.13, 0.11, 0.10)


def tonemap(c):
    """ROOM_FRAG's tonemap and grade, linear in, sRGB out."""
    y = np.maximum((c * np.array([0.2126, 0.7152, 0.0722])).sum(-1, keepdims=True), 1e-6)
    c = c * np.where(y < 0.04, 12.5 * y * y, y - 0.02) / y
    peak = np.maximum(c.max(-1, keepdims=True), 1e-6)
    d = 1 - 0.76
    np_ = 1 - d * d / (peak + d - 0.76)
    g = 1 - 1 / (0.15 * (peak - np_) + 1)
    hi = c * np_ / peak
    hi = hi * (1 - g) + np_ * g
    c = np.where(peak < 0.76, c, hi)
    return cm.to_srgb(np.clip(c * np.array([1.02, 1.0, 0.97]), 0, 1))


def tex(name):
    a = np.asarray(Image.open(name).convert('RGBA'), np.float32) / 255
    return np.concatenate([cm.to_linear(a[..., :3]), a[..., 3:]], -1)


def outside(sky, band, oak, eye, d, centre, exposure, top_m, low_m):
    """What the layers show along the rays d from eye, linear and exposed."""
    # Sky: by direction alone.
    az = np.degrees(np.arctan2(d[..., 0], d[..., 2]))
    el = np.degrees(np.arcsin(np.clip(d[..., 1], -1, 1)))
    sx = (az - SKY_AZ[0]) * SKY_PX - 0.5
    sy = (SKY_EL[1] - el) * SKY_PX - 0.5
    c = bilinear(sky, sx, sy)[..., :3]
    # Band: the ray meets the cylinder round centre, radius R.
    R = BAND_M * METRE
    o = eye - centre
    a2 = d[..., 0] ** 2 + d[..., 2] ** 2
    b = o[0] * d[..., 0] + o[2] * d[..., 2]
    t = (-b + np.sqrt(b * b - a2 * (o[0] ** 2 + o[2] ** 2 - R * R))) / np.maximum(a2, 1e-9)
    p = eye + d * t[..., None]
    baz = np.degrees(np.arctan2(p[..., 0] - centre[0], p[..., 2] - centre[2]))
    hy = (p[..., 1] - LAWN) / METRE
    bx = (baz + BAND_AZ) * BAND_PX - 0.5
    by = (top_m - hy) / (top_m - low_m) * band.shape[0] - 0.5
    s = bilinear(band, bx, by)
    s = s * ((np.abs(baz) < BAND_AZ) & (hy < top_m) & (hy > low_m))[..., None]
    c = c * (1 - s[..., 3:]) + s[..., :3]
    # Oak: a quad facing the centre.
    ra = math.radians(OAK_AZ)
    n = np.array([math.sin(ra), 0, math.cos(ra)])
    foot = centre + n * OAK_M * METRE
    foot[1] = LAWN
    dn = d @ n
    t = ((foot - eye) @ n) / np.where(np.abs(dn) < 1e-9, 1e-9, dn)
    q = eye + d * t[..., None] - foot
    side = np.array([math.cos(ra), 0, -math.sin(ra)])
    wm = OAK_H * oak.shape[1] / oak.shape[0]
    ox = ((q @ side) / METRE / wm + 0.5) * oak.shape[1] - 0.5
    oy = (1 - q[..., 1] / METRE / OAK_H) * oak.shape[0] - 0.5
    ok = (t > 0) & (ox > -0.5) & (ox < oak.shape[1] - 0.5) & (oy > -0.5) & (oy < oak.shape[0] - 0.5)
    s = bilinear(oak, ox, oy) * ok[..., None]
    c = c * (1 - s[..., 3:]) + s[..., :3]
    return c * exposure


def camera(eye, at, vfov, w, h):
    f = at - eye
    f = f / np.linalg.norm(f)
    r = np.cross([0, 1, 0], f)          # x right, y up, z out: a left-handed frame
    r = r / np.linalg.norm(r)
    u = np.cross(f, r)
    k = math.tan(math.radians(vfov) / 2)
    x = ((np.arange(w) + 0.5) / w * 2 - 1) * k * w / h
    y = (1 - (np.arange(h) + 0.5) / h * 2) * k
    d = f + x[None, :, None] * r + y[:, None, None] * u
    return d / np.linalg.norm(d, axis=-1, keepdims=True)


def tuner_window(eye, d):
    """Through the tuner's window: the inner face's plane, its opening and bars (the
    tuner draws only the panelling under the sill; the light's window is this)."""
    t = (WALL_Z - eye[2]) / np.maximum(d[..., 2], 1e-6)
    p = eye + d * t[..., None]
    wx, wy = p[..., 0] - WIN_X, p[..., 1] - SILL
    size = (ACROSS * PANES[0], UP * PANES[1])
    inside = (d[..., 2] > 0) & (np.abs(wx) < size[0] / 2) & (wy > 0) & (wy < size[1])
    fx = np.abs((wx / PANES[0] + ACROSS / 2) % 1 - 0.5) * PANES[0]
    fy = np.abs((wy / PANES[1] + 0.5) % 1 - 0.5) * PANES[1]
    return inside & (np.minimum(fx, fy) > BAR / 2)


def shell_windows(eye, d):
    """Through the shell's three windows (task 109): niches 1.3 m wide with straight
    reveals 0.8 m deep, the glass 1.1 m by 2.35, its bars, the windows 3 m apart."""
    vis = np.zeros(d.shape[:2], bool)
    for k in (-3.0, 0.0, 3.0):
        cx = WIN_X + k * METRE
        ok = d[..., 2] > 0
        for depth, wid, top in ((0.0, 1.3, 2.5), (0.8, 1.3, 2.5), (0.4, 1.1, 2.35)):
            t = (WALL_Z + depth * METRE - eye[2]) / np.maximum(d[..., 2], 1e-6)
            p = eye + d * t[..., None]
            s, hgt = (p[..., 0] - cx) / METRE, (p[..., 1] - SILL) / METRE
            ok &= (np.abs(s) < wid / 2) & (hgt > 0) & (hgt < top)
            if depth == 0.4:
                r, b, tr = wid / 2, 0.012, top * 2 / 3
                bar = (np.abs(s) < 2.5 * b) | (np.abs(hgt - tr) < 2 * b) | ((hgt < tr) & (np.abs(hgt - tr / 2) < b))
                leaf = r - 2.5 * b
                for j in (1, 2):
                    bar |= (hgt > tr) & (np.abs(np.abs(s) - 2.5 * b - j * leaf / 3) < b)
                    bar |= (hgt > tr) & (np.abs(hgt - tr - j * (top - tr) / 3) < b)
                ok &= ~bar
        vis |= ok
    return vis


def preview(out, top_m, low_m):
    sky, band, oak = (tex(f'{out}/outside_{n}.png') for n in ('sky', 'band', 'oak'))
    centre = np.array([WIN_X, 0.0, WALL_Z])
    W, H = 1600, 1000
    m = METRE
    table_eye = np.array([WIN_X, SILL + 0.4 * m, WALL_Z - 1.2 * m])
    room_eye = np.array([WIN_X, -23.56 + 1.6 * m, WALL_Z - 6.0 * m])
    corner_eye = np.array([WIN_X - 3.5 * m, -23.56 + 1.6 * m, WALL_Z - 5.5 * m])
    ahead = table_eye + np.array([0, 0.36 * m, m])
    window = np.array([WIN_X, -23.56 + 1.8 * m, WALL_Z])
    views = [   # name, eye, at, vertical fov, windows, exposure, blur (deg), caption
        ('table', table_eye, ahead, 62.0, tuner_window, 1.0, 0.0,
         'From the games table, the eyes 0.4 m over the sill and 1.2 m from the wall, through the '
         'tuner\'s window; the layers as the build draws them, before the depth of field.'),
        ('table-dof', table_eye, ahead, 62.0, tuner_window, 1.0, 0.5,
         'The same with the outside blurred 0.5 degrees, as a depth of field focused on the board would.'),
        ('table-bright', table_eye, ahead, 62.0, tuner_window, 1.8, 0.5,
         'The same exposed 1.8 times: the sky into the tonemap\'s shoulder, as the concepts\' bright windows.'),
        ('room', room_eye, window, 50.0, tuner_window, 1.0, 0.0,
         'From 6 m into the room, eyes 1.6 m up (the shell\'s planned window view), the tuner\'s window.'),
        ('room-shell', room_eye, window, 50.0, shell_windows, 1.0, 0.0,
         'The same through the shell\'s three windows, 3 m apart, their straight reveals 0.8 m deep.'),
        ('corner-shell', corner_eye, window + np.array([m, 0, 0]), 50.0, shell_windows, 1.0, 0.0,
         'From the room\'s far side, 3.5 m left of the window: the band seen obliquely.'),
    ]
    for name, eye, at, vfov, mask, exposure, dof, _ in views:
        d = camera(eye, at, vfov, W, H)
        c = outside(sky, band, oak, eye, d, centre, exposure, top_m, low_m)
        if dof > 0:                          # degrees, the far layers' blur
            px = dof * H / vfov
            c = blur(c, px)
        img = np.where(mask(eye, d)[..., None], tonemap(c), np.array(WALL_SRGB))
        Image.fromarray((np.clip(img, 0, 1) * 255 + 0.5).astype(np.uint8)).save(f'{out}/preview-{name}.png')
        print(f'wrote {out}/preview-{name}.png')
    with open(f'{out}/outside.txt') as f:
        notes = f.read().splitlines()
    layers = ''.join(f'<figure class="layer"><img src="outside_{n}.png" alt="{n}"><figcaption>{t}</figcaption></figure>'
                     for n, t in zip(('sky', 'band', 'oak'), (notes[1], notes[0], notes[2])))
    shots = ''.join(f'<figure><img src="preview-{v[0]}.png" alt="{v[0]}"><figcaption>{v[7]}</figcaption></figure>'
                    for v in views)
    with open(f'{out}/index.html', 'w') as f:
        f.write(f'''<!doctype html><meta charset="utf-8"><meta name="viewport" content="width=device-width">
<title>Outside layers</title>
<style>body{{font:15px/1.45 system-ui;margin:24px auto;max-width:1100px;padding:0 16px;background:#1d1a18;color:#e8e2da}}
img{{max-width:100%;display:block}} figure{{margin:0 0 28px}} figcaption{{color:#b9b0a5;margin-top:6px}}
.layer img{{background:repeating-conic-gradient(#555 0 25%,#777 0 50%) 0 0/24px 24px}} a{{color:#e9c46a}}</style>
<h1>The view out of the library's windows</h1>
<p>Made by <code>tools/materials/outside.py</code>; the builder's spec is <a href="spec.md">spec.md</a>.
The band and the oak are premultiplied, so on the checker their edges look dark.</p>
<h2>Previews</h2>{shots}<h2>The layers</h2>{layers}
''')
    print(f'wrote {out}/index.html')


if __name__ == '__main__':
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    rows = make(out)
    if '--preview' in sys.argv:
        preview(out, *rows)
