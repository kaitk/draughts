#!/usr/bin/env python3
"""Engraves the library wallpaper's mask: the same flowers and tile, with veins drawn in.

    python3 -I tools/materials/wallpaper_engrave.py OUT_DIR [MASK]
    cp OUT_DIR/wallpaper_engraved.png design/materials/

Reads the app's mask (design/materials/wallpaper_mask.png, or MASK) and writes
wallpaper_engraved.png (L8, 1024², tileable) and engraved_lines.png (the lines by kind, for
looking at). A block-printed paper's depth is mostly its cut lines: a vein down each leaf,
side veins off it, sharp partings between the petals. They are drawn here from the mask's
own shapes, so the motifs, layout and repeat stay as they are:

- the midribs: the skeleton of the print with its serrations smoothed away, its short
  spurs pruned, drawn as tapered strokes where the print is a leaf's width (stems stay
  solid);
- the side veins: short strokes off each midrib, slanted toward its tip, ending short of
  the outline;
- the mask's own soft lines (the petals' partings, the flowers' cups) made sharp and dark;
  in the flower heads, the print's densest parts, these are the only lines.

The print between the lines is brightened to keep its local mean, so the room's look from
afar stays. Strokes are drawn at SS times the tile's resolution and taken down to it, so each stays a
clean line of about one texel (0.9 mm on the wall). Numpy and Pillow only.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import common as cm  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
MASK = os.path.join(HERE, '..', '..', 'design', 'materials', 'wallpaper_mask.png')

PRINT = 0.4             # the mask's value where the print starts (ROOM_FRAG cuts it there too)
SMOOTH = 2.5            # texels of blur on the print before its skeleton: the serrations gone
NARROW = 3.6            # a midrib's run is somewhere at least this half width (texels): a stem's is about 2
MID_LEAST = 2.9         # and runs where the print is at least this
SMOOTH_PATH = 5         # points each side a skeleton path's points are averaged over
SPUR = 7                # skeleton branches shorter than this (texels) are pruned
MID_WIDTH = 0.26        # a midrib's width over the print's half width there
MID_MAX = 2.0           # texels
SIDE_EVERY = 6.5        # texels between side veins along a midrib
SIDE_SLANT = 50.0       # degrees off the midrib, toward its tip
SIDE_FROM = 6.0         # side veins only off midribs at least this long (texels)
SIDE_WIDTH = 0.8        # a side vein's width at its root over the midrib's there
EDGE = 1.6              # strokes end this far (texels) inside the outline
FLOWER_BLUR = 14        # texels: the flower heads are the print's densest parts at this scale
FLOWER_DENSITY = 0.62   # least share of print in that blur for a head
HEAD_GROW = 8.0         # texels of blur that grow a head's dense middle out to its petals
OWN_FROM = 0.055        # the mask's own lines: the least curvature across one that counts
OWN_SPAN = 0.08         # and the more that makes it a full line
OWN = 1.0               # how dark they go, as a share of a drawn line
DEPTH = 1.0             # how far a line takes the print toward the ground (1 all the way)
KEEP_MEAN = 4.0         # texels over which the print keeps its mean brightness
SS = 4                  # supersampling of the strokes
PAD = 48                # texels drawn past each side of the tile, folded back


def gauss(a, s):
    """Gaussian blur of a wrapping image, s texels."""
    H, W = a.shape
    fy = np.fft.fftfreq(H)[:, None]
    fx = np.fft.fftfreq(W)[None, :]
    g = np.exp(-2 * (np.pi * s) ** 2 * (fy ** 2 + fx ** 2))
    return np.real(np.fft.ifft2(np.fft.fft2(a) * g)).astype(np.float32)


def distance(inside, R):
    """Euclidean distance (texels, up to R) from each inside texel to the nearest outside one, wrapping."""
    D = np.where(inside, np.float32(R), np.float32(0))
    out = ~inside
    offs = sorted(((dx * dx + dy * dy) ** 0.5, dy, dx) for dy in range(-R, R + 1) for dx in range(-R, R + 1)
                  if 0 < dx * dx + dy * dy <= R * R)
    for r, dy, dx in offs:
        np.minimum(D, np.where(np.roll(out, (dy, dx), (0, 1)), np.float32(r), np.float32(R)), out=D)
    return D


NB = [(-1, 0), (-1, 1), (0, 1), (1, 1), (1, 0), (1, -1), (0, -1), (-1, -1)]   # P2..P9, clockwise from up


def thin(img):
    """Zhang-Suen thinning of a wrapping bool image to a one-texel skeleton."""
    img = img.copy()
    while True:
        changed = False
        for step in (0, 1):
            p = [np.roll(img, (-dy, -dx), (0, 1)) for dy, dx in NB]
            b = sum(q.astype(np.int8) for q in p)
            a = sum((~p[i] & p[(i + 1) % 8]).astype(np.int8) for i in range(8))
            if step == 0:
                c = ~(p[0] & p[2] & p[4]) & ~(p[2] & p[4] & p[6])
            else:
                c = ~(p[0] & p[2] & p[6]) & ~(p[0] & p[4] & p[6])
            kill = img & (b >= 2) & (b <= 6) & (a == 1) & c
            if kill.any():
                img &= ~kill
                changed = True
        if not changed:
            return img


def neighbours(sk, y, x):
    H, W = sk.shape
    return [((y + dy) % H, (x + dx) % W, dy, dx) for dy, dx in NB if sk[(y + dy) % H, (x + dx) % W]]


def trace(sk):
    """The skeleton as paths between its ends and junctions: lists of unwrapped (y, x), and
    for each whether its first and last points are free ends."""
    H, W = sk.shape
    deg = np.zeros(sk.shape, np.int8)
    for dy, dx in NB:
        deg += np.roll(sk, (-dy, -dx), (0, 1))
    deg = np.where(sk, deg, 0)
    nodes = sk & (deg != 2)
    used = set()
    paths = []

    def walk(y, x, uy, ux, ny, nx, dy, dx):
        pts = [(uy, ux), (uy + dy, ux + dx)]
        py, px = y, x
        y, x, uy, ux = ny, nx, uy + dy, ux + dx
        while not nodes[y, x]:
            used.add((y, x))
            nxt = [n for n in neighbours(sk, y, x) if (n[0], n[1]) != (py, px)]
            nxt = [n for n in nxt if (n[0], n[1]) not in used or nodes[n[0], n[1]]] or nxt
            if not nxt:
                break
            n = nxt[0]
            py, px = y, x
            y, x, uy, ux = n[0], n[1], uy + n[2], ux + n[3]
            pts.append((uy, ux))
        return pts, (y, x)

    seen_edges = set()
    for y, x in zip(*np.nonzero(nodes)):
        for ny, nx, dy, dx in neighbours(sk, y, x):
            if (ny, nx) in used:
                continue
            key = ((y, x), (ny, nx))
            if key in seen_edges:
                continue
            pts, end = walk(y, x, float(y), float(x), ny, nx, dy, dx)
            seen_edges.add(key)
            if len(pts) >= 2:
                seen_edges.add((end, (int(pts[-2][0]) % H, int(pts[-2][1]) % W)))
            paths.append((pts, deg[y, x] == 1, deg[end] == 1))
    return paths


def prune(sk, length):
    """The skeleton without its spurs shorter than `length`, twice over."""
    H, W = sk.shape
    for _ in range(2):
        for pts, free0, free1 in trace(sk):
            if (free0 or free1) and len(pts) < length:
                inner = pts if free0 and free1 else (pts[:-1] if free0 else pts[1:])
                for y, x in inner:
                    sk[int(y) % H, int(x) % W] = False
        sk = thin(sk)
    return sk


def smooth(pts, n=2):
    a = np.array(pts, np.float32)
    if len(a) < 2 * n + 3:
        return a
    out = a.copy()
    for i in range(n, len(a) - n):
        out[i] = a[i - n:i + n + 1].mean(0)
    return out


def at(a, y, x):
    H, W = a.shape
    return a[int(round(y)) % H, int(round(x)) % W]


class Pen:
    """Tapered strokes drawn at SS times the tile, PAD texels round it, folded back on taking."""

    def __init__(self, side):
        self.side = side
        n = (side + 2 * PAD) * SS
        self.img = Image.new('L', (n, n), 0)
        self.d = ImageDraw.Draw(self.img)

    def dot(self, y, x, r, v=255):
        cy, cx = (y + PAD) * SS, (x + PAD) * SS
        r *= SS
        self.d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=v)

    def stroke(self, pts, widths):
        """A line through pts (texels), each point's width (texels), round-jointed."""
        for (y0, x0), (y1, x1), w0, w1 in zip(pts[:-1], pts[1:], widths[:-1], widths[1:]):
            steps = max(1, int(np.hypot(y1 - y0, x1 - x0) * SS))
            for i in range(steps + 1):
                t = i / steps
                w = w0 + (w1 - w0) * t
                if w > 0.05:
                    self.dot(y0 + (y1 - y0) * t, x0 + (x1 - x0) * t, w / 2)

    def take(self):
        n = self.side + 2 * PAD
        a = np.asarray(self.img.resize((n, n), Image.BOX), np.float32) / 255.0
        s = self.side
        out = np.zeros((s, s), np.float32)
        for oy in (-1, 0, 1):
            for ox in (-1, 0, 1):
                y0, x0 = PAD + oy * s, PAD + ox * s
                ys, xs = slice(max(y0, 0), min(y0 + s, n)), slice(max(x0, 0), min(x0 + s, n))
                part = a[ys, xs]
                ty, tx = ys.start - y0, xs.start - x0
                np.maximum(out[ty:ty + part.shape[0], tx:tx + part.shape[1]], part,
                           out=out[ty:ty + part.shape[0], tx:tx + part.shape[1]])
        return out


def flower_heads(inside):
    """Where the flower heads are: the print's densest parts, grown by HEAD_GROW. Their
    petals are parted by the mask's own lines already; midribs there would cross them."""
    G = gauss(inside.astype(np.float32), FLOWER_BLUR)
    return gauss((G > FLOWER_DENSITY).astype(np.float32), HEAD_GROW) > 0.1


def hessian_max(a):
    """The larger eigenvalue of a wrapping image's Hessian, positive along its dark lines, and
    its direction (y, x), across them."""
    xx = np.roll(a, -1, 1) - 2 * a + np.roll(a, 1, 1)
    yy = np.roll(a, -1, 0) - 2 * a + np.roll(a, 1, 0)
    xy = (np.roll(a, (-1, -1), (0, 1)) - np.roll(a, (-1, 1), (0, 1)) - np.roll(a, (1, -1), (0, 1))
          + np.roll(a, (1, 1), (0, 1))) / 4
    tr = xx + yy
    lmax = tr / 2 + np.sqrt(np.maximum(tr * tr / 4 - (xx * yy - xy * xy), 0))
    ey, ex = lmax - xx, xy
    n = np.hypot(ey, ex) + 1e-9
    return lmax, ey / n, ex / n


def engrave(mask):
    side = mask.shape[0]
    inside = mask > PRINT
    D = distance(inside, 12)
    body = gauss(inside.astype(np.float32), SMOOTH) > 0.5
    D2 = distance(body, 20)
    near_head = flower_heads(inside)
    sk = thin(body) & (D2 >= MID_LEAST) & (D >= 1.0) & ~near_head
    sk = prune(sk, SPUR)
    pen, side_pen = Pen(side), Pen(side)
    # The midribs and their side veins: each path's runs where the print is wide enough,
    # if somewhere a leaf's width (not a stem's).
    for pts, free0, free1 in trace(sk):
        a = smooth(pts, SMOOTH_PATH)
        half = np.array([at(D2, y, x) for y, x in a])
        wide = np.concatenate([[False], half >= MID_LEAST, [False]])
        edges = np.flatnonzero(wide[1:] != wide[:-1])
        for i0, i1 in zip(edges[::2], edges[1::2]):
            if i1 - i0 >= 3 and half[i0:i1].max() >= NARROW:
                midrib(pen, side_pen, D, a[i0:i1], half[i0:i1], free0 or i0 > 0, free1 or i1 < len(a))
    kinds = [pen.take() * inside, side_pen.take() * inside]
    # The mask's own lines inside the print, made as dark and sharp as the drawn ones.
    closed = gauss(inside.astype(np.float32), 1.5) > 0.3
    Dc = distance(closed, 6)
    valley = hessian_max(gauss(mask, 0.7))[0]
    own = np.clip((valley - OWN_FROM) / OWN_SPAN, 0, 1) * np.clip((Dc - 1.5) / 1.0, 0, 1)
    kinds.append(own * OWN)
    lines = np.maximum.reduce(kinds)
    engraved = mask * (1 - DEPTH * lines)
    # The print between the lines a little brighter, so that a patch of it is as bright as
    # before on the whole and the room's look from afar stays.
    want = gauss(mask, KEEP_MEAN)
    for _ in range(3):
        gain = np.clip(want / np.maximum(gauss(engraved, KEEP_MEAN), 1e-4), 1.0, 1.6)
        engraved = np.where(inside, np.minimum(mask * (1 - DEPTH * lines) * gain, 1.0), engraved)
    return engraved, kinds


def midrib(pen, side_pen, D, a, half, free0, free1):
    """A midrib along a (texels), the print half as wide as `half` there, tapered to its free
    ends, and its side veins."""
    w = np.clip(MID_WIDTH * half, 0.0, MID_MAX)
    n = len(a)
    k = np.minimum(np.arange(n), np.arange(n)[::-1]).astype(np.float32)
    taper = np.ones(n, np.float32)
    span = max(3.0, 0.35 * n)
    if free0:
        taper = np.minimum(taper, np.clip(np.arange(n) / span, 0, 1))
    if free1:
        taper = np.minimum(taper, np.clip(np.arange(n)[::-1] / span, 0, 1))
    pen.stroke(a, w * taper)
    if n < SIDE_FROM:
        return
    # Toward the tip: the thinner end.
    tip = 1 if half[-1] < half[0] else -1
    step = 0.0
    for i in range(1, n - 1):
        step += np.hypot(*(a[i] - a[i - 1]))
        if step < SIDE_EVERY or k[i] < 2:
            continue
        step = 0.0
        ty, tx = (a[min(i + 2, n - 1)] - a[max(i - 2, 0)]) * tip
        tl = np.hypot(ty, tx) + 1e-6
        for sgn in (1, -1):
            ang = np.radians(SIDE_SLANT) * sgn
            vy, vx = (ty * np.cos(ang) - tx * np.sin(ang)) / tl, (ty * np.sin(ang) + tx * np.cos(ang)) / tl
            line = ray(D, a[i][0], a[i][1], vy, vx, 1.4 * half[i])
            if len(line) < 5:
                continue
            m = len(line)
            side_pen.stroke(line, SIDE_WIDTH * w[i] * taper[i] * (1 - np.arange(m) / m))


def ray(D, y, x, vy, vx, reach):
    """Points from (y, x) along (vy, vx) every half texel, up to reach, while EDGE inside the print."""
    line = [(y, x)]
    walked = 0.0
    while walked < reach:
        y, x = y + 0.5 * vy, x + 0.5 * vx
        walked += 0.5
        if at(D, y, x) < EDGE:
            break
        line.append((y, x))
    return line


def main():
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    mask = cm.load(sys.argv[2] if len(sys.argv) == 3 else MASK, 'L')
    engraved, kinds = engrave(mask)
    lines = np.maximum.reduce(kinds)
    cm.save(os.path.join(out, 'wallpaper_engraved.png'), engraved)
    # The lines by kind on the mask: midribs red, side veins green, the mask's own white.
    colours = np.array([[1, 0.2, 0.2], [0.2, 1, 0.2], [1, 1, 1]], np.float32)
    shown = 0.25 * mask[..., None] * np.ones(3, np.float32)
    for k, c in zip(kinds, colours):
        shown = shown * (1 - k[..., None]) + c * k[..., None]
    cm.save(os.path.join(out, 'engraved_lines.png'), shown)
    print(f'print mean {mask[mask > PRINT].mean():.3f} -> {engraved[mask > PRINT].mean():.3f}, '
          f'mask mean {mask.mean():.4f} -> {engraved.mean():.4f}')


if __name__ == '__main__':
    main()
