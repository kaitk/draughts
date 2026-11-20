#!/usr/bin/env python3
"""Prototype: way c of lace_crisp.py with its big flowers drawn in the download's hand.

    python3 tools/materials/lace_blossom.py OUT_DIR

The download's big flowers are wild roses: five broad petals, a shallow notch in each
tip, wavy edges, petals overlapping at the base, fine lines fanning from the centre with
half stitch between some, and a raised boss ringed by eyelets round a dot. Each blossom
here is drawn as such, seen face on, at three-quarters, from the side, half open, or as a
bud, as distances on lace_crisp's Canvas. Every petal is a fan in its own plane that
rises from the centre (a cup), projected as the flower turns away, so far petals stand up
behind the boss and near ones overlap it; they are painted far to near. Way c's tracing
places them, one for each of its big flowers, turned and sized to the traced blob; the
hem stays way c's.
"""

import os
import sys

import numpy as np
from PIL import Image

import common as cm
import lace
import lace_crisp as lc
from lace_crisp import BIG, N, mm

# (name, tilt cos, cup slope, petals, petal length of R, fan half-angle)
KINDS = {
    'face': (1.00, 0.10, 5, 0.92, 0.86),
    'face6': (0.96, 0.18, 6, 0.90, 0.74),
    'three_quarter': (0.74, 0.35, 5, 0.95, 0.86),
    'side': (0.50, 0.30, 5, 0.98, 0.84),
    'half_open': (0.45, 0.75, 5, 0.85, 0.70),
}


def petal_shape(s, t, L, fan_l, fan_r, notch, wave, wph, rng_lobes):
    """A petal fanning from its base along s: a broad rounded tip with a shallow notch and
    a wavy edge, narrowing to the base. Returns the edge radius at each pixel's angle and
    the angle, of the fan."""
    r = np.hypot(s, t)
    phi = np.arctan2(t, s)
    fan = np.where(phi >= 0, fan_l, fan_r)
    q = np.clip(phi / fan, -1, 1)
    f = np.clip(1 - np.abs(q) ** 3.5, 0, 1) ** 0.45
    f = f * (1 - notch * np.exp(-(q / 0.16) ** 2))
    f = f * (1 + wave * np.sin(rng_lobes * np.pi * q + wph))
    f = np.where(np.abs(phi) < fan, f, 0)
    return r, phi, q, L * f


class Blossom:
    """One flower's petals and boss, drawn on a Canvas at centre c, radius R."""

    def __init__(self, kind, rng):
        k, slope, n, length, fan = KINDS[kind]
        self.kind, self.k, self.slope, self.n = kind, k, slope, n
        self.lift = np.sqrt(max(0.0, 1 - k * k))
        base = rng.uniform(0, 2 * np.pi)
        self.petals = []
        for i in range(n):
            a = base + 2 * np.pi * i / n + rng.normal(0, 0.12)
            self.petals.append(dict(
                a=a,
                L=length * rng.uniform(0.86, 1.08),
                fl=fan * rng.uniform(0.85, 1.15),
                fr=fan * rng.uniform(0.85, 1.15),
                notch=rng.uniform(0.08, 0.18),
                wave=rng.uniform(0.03, 0.06),
                wph=rng.uniform(0, 2 * np.pi),
                lobes=rng.choice([3, 4, 5]),
                streak=rng.uniform(0, 2 * np.pi),
                turn=rng.random() < 0.35,
            ))
        self.holes = rng.integers(9, 12)
        self.hole_jit = rng.uniform(0.8, 1.2, 16)
        self.seed = rng.integers(1 << 30)

    def project(self, u, v, z):
        """Flower plane (u right, v toward the viewer's bottom, z out of the face) to the
        screen before the turn."""
        return u, v * self.k - z * self.lift

    def petal_frame(self, p, R, X, Y):
        """Pixels in a petal's plane (s along it, t across), through its own affine map:
        the petal leaves the boss at 0.12 R and rises along s by the cup's slope."""
        ca, sa = np.cos(p['a']), np.sin(p['a'])
        b0 = 0.12 * R
        # Columns: d(screen)/ds, d(screen)/dt, and the base point.
        ds = np.array(self.project(ca, sa, self.slope)) / np.hypot(1, self.slope)
        dt = np.array(self.project(-sa, ca, 0.0))
        o = np.array(self.project(b0 * ca, b0 * sa, 0.0))
        m = np.array([[ds[0], dt[0]], [ds[1], dt[1]]])
        inv = np.linalg.inv(m)
        x, y = X - o[0], Y - o[1]
        return inv[0, 0] * x + inv[0, 1] * y, inv[1, 0] * x + inv[1, 1] * y

    def draw(self, cv, c, R, rot):
        pad = R * 1.4
        ix, X, Y = cv.box(c[0] - pad, c[1] - pad, c[0] + pad, c[1] + pad)
        if ix is None:
            return
        cr, sr = np.cos(rot), np.sin(rot)
        x, y = X - c[0], Y - c[1]
        X, Y = cr * x + sr * y, -sr * x + cr * y          # into the flower's turned frame
        # Far petals first (their tips up the screen), the boss among them, near last.
        order = sorted(self.petals, key=lambda p: np.sin(p['a']))
        boss_at = sum(1 for p in order if np.sin(p['a']) < 0.15 - 0.6 * (1 - self.k))
        if self.k > 0.9:
            boss_at = len(order)
        for i, p in enumerate(order):
            if i == boss_at:
                self.boss(cv, ix, X, Y, R)
            self.petal(cv, ix, X, Y, R, p)
        if boss_at >= len(order):
            self.boss(cv, ix, X, Y, R)

    def petal(self, cv, ix, X, Y, R, p):
        s, t = self.petal_frame(p, R, X, Y)
        L = p['L'] * R
        r, phi, q, edge = petal_shape(s, t, L, p['fl'], p['fr'], p['notch'], p['wave'],
                                      p['wph'], p['lobes'])
        d = lc.normalise(r - edge)
        u = r / np.maximum(edge, 1e-3)
        # Lines fanning across the petal's middle, three, clear of the boss.
        veins = np.full(X.shape, BIG, np.float32)
        for qa, start, reach in ((-0.42, 0.34, 0.6), (0.0, 0.3, 0.72), (0.42, 0.36, 0.58)):
            pa = qa * (p['fl'] if qa > 0 else p['fr']) + p['wave'] * 2
            dist = r * np.abs(np.sin(phi - pa))
            veins = np.minimum(veins, np.where((u > start) & (u < reach) & (np.cos(phi - pa) > 0), dist, BIG))
        # Half stitch: the base, as the download's lighter heart, and streaks between some
        # of the lines; a far petal's foot too.
        half = (u < 0.3).astype(np.float32)
        streak = np.sin(q * 4.4 * np.pi / 2 + p['streak']) > 0.35
        half = np.maximum(half, (streak & (u < 0.62)).astype(np.float32))
        if np.sin(p['a']) < -0.3 and self.k < 0.8:         # a far petal, its foot in shade
            half = np.maximum(half, (u < 0.55).astype(np.float32))
        # A near petal at a strong turn rolls its tip over: a fold line, half stitch beyond.
        if p['turn'] and self.k < 0.8 and np.sin(p['a']) > 0.3:
            fold = 0.78 + 0.05 * np.sin(q * 3 + p['wph'])
            veins = np.minimum(veins, np.where(np.abs(phi) < 0.9 * np.maximum(p['fl'], p['fr']),
                                               np.abs(u - fold) * edge, BIG))
            half = np.where(u > fold, 1.0, half * (u < fold - 0.08))
        cv.paint(ix, d, veins, half)

    def boss(self, cv, ix, X, Y, R):
        """The raised centre: a disc lifted a little off the face, a ring of eyelets round
        a dot."""
        h = 0.06 * R
        # The boss's plane coordinates: invert the face's map (no cup).
        u = X
        v = (Y + h * self.lift) / self.k
        rb = 0.25 * R
        r = np.hypot(u, v)
        th = np.arctan2(v, u)
        d = lc.normalise((r - rb) * self.k)
        cv.paint(ix, d, np.full_like(d, BIG), np.zeros_like(d))
        n = self.holes
        k = np.round(th * n / (2 * np.pi))
        ph = th - k * 2 * np.pi / n
        idx = (k.astype(int) % n)
        jit = self.hole_jit[idx]
        # Radially long eyelets, irregular in size.
        along = (r - 0.165 * R) / (0.045 * R * jit)
        across = r * np.sin(ph) / (0.022 * R * jit)
        hole = (np.sqrt(along ** 2 + across ** 2) - 1) * 0.022 * R * self.k
        dot = (r - 0.04 * R) * self.k
        cv.put('holes', ix, np.minimum(hole, dot))


def bud(cv, c, R, rot, rng):
    """A closed bud, pointing along rot (0 up): an egg drawn to a point, the outer petal's
    edge wrapping across it with half stitch on the inner one, two sepals clasping its
    foot and a third up its side."""
    H, W = 1.7 * R, 0.62 * R
    pad = H + R
    ix, X, Y = cv.box(c[0] - pad, c[1] - pad, c[0] + pad, c[1] + pad)
    if ix is None:
        return
    ux, uy = np.sin(rot), -np.cos(rot)                  # up the bud
    base = (c[0] - ux * 0.5 * H, c[1] - uy * 0.5 * H)
    x, y = X - base[0], Y - base[1]
    s = x * ux + y * uy
    t = x * uy - y * ux
    u = np.clip(s / H, 0, 1)
    w = W * np.sin(np.pi * u ** 0.7) ** 0.75 * (1 + 0.04 * np.sin(9 * u + rng.uniform(0, 6)))
    lean = rng.uniform(-0.12, 0.12) * H * u * u
    d = lc.normalise(np.maximum(np.abs(t - lean) - w, np.maximum(-s, s - H)))
    side = 1 if rng.random() < 0.5 else -1
    wrap = side * W * (0.75 - 1.5 * u ** 0.9)           # the outer petal's edge, base to tip
    vein = np.where((u > 0.12) & (u < 0.92), np.abs(t - lean - wrap), BIG)
    half = ((t - lean - wrap) * side > 0).astype(np.float32)
    foot = (base[0] + ux * 0.08 * H, base[1] + uy * 0.08 * H)
    up = np.arctan2(uy, ux)
    for sd in (-1, 1):                                  # sepals behind, flaring out
        cv.leaf(foot, up + sd * rng.uniform(0.75, 0.95), 0.7 * H, 0.2 * H, 2, -sd * 0.3, sd, rng)
    cv.paint(ix, d, vein, half)
    cv.leaf(foot, up + side * 0.22, 0.55 * H, 0.17 * H, 2, -side * 0.15, -side, rng)
    cv.curve('sd', [foot, (foot[0] - ux * 0.35 * H, foot[1] - uy * 0.35 * H)], mm(0.9), mm(0.7))


VARIANTS = ['face', 'face6', 'three_quarter', 'side', 'half_open', 'bud']


def draw_variant(cv, kind, c, R, rot, rng):
    if kind == 'bud':
        bud(cv, c, R, rot, rng)
    else:
        Blossom(kind, rng).draw(cv, c, R, rot)


def variant_sheet(out, cloth, net):
    """Each variant three times, large: 14 cm cells."""
    cell = 600
    rows = 2
    cv = lc.Canvas(cell * rows, cell * len(VARIANTS), wrap_y=False)
    rng = np.random.default_rng(3)
    for j, kind in enumerate(VARIANTS):
        for i in range(rows):
            R = mm(30) if kind != 'bud' else mm(18)
            draw_variant(cv, kind, (j * cell + cell / 2, i * cell + cell / 2), R,
                         rng.uniform(-0.4, 0.4) if kind != 'face' else rng.uniform(0, 6.3), rng)
    sd, vein, half = cv.finish()
    m = lc.render(sd, vein, half, (_tile(cloth[0], cv.h, cv.w), _tile(cloth[1], cv.h, cv.w)))
    big = np.maximum(_tile(lace.tiled(net, lace.NET_REPEAT), cv.h, cv.w), m)
    f, b = lace.shade(big)
    lace.save_jpg(os.path.join(out, 'variants.jpg'), f)
    lace.save_jpg(os.path.join(out, 'variants_backlit.jpg'), b)


def regrow(sd, half, wrap_y=True, seed=5):
    """Way c's search for the traced flowers (its widest blobs), each redrawn as one of
    the variants: a round blob face on or at three-quarters, a long one from the side or
    half open, its squash across the blob's long axis; neighbours differ."""
    f = 4
    inside = lace.box((sd < 0).astype(np.float32), f) > 0.5
    depth = lc.edt_band(~inside, 28, wrap_y) * f
    cv = lc.Canvas(sd.shape[0], sd.shape[1], wrap_y)
    cv.sd, cv.half = sd.copy(), half.copy()
    rng = np.random.default_rng(seed)
    d = depth.copy()
    hh, ww = d.shape
    yy, xx = np.mgrid[0:hh, 0:ww]
    found = []
    while True:
        k = int(np.argmax(d))
        y, x = divmod(k, ww)
        if d[y, x] < mm(6.0):
            break
        dx = (xx - x + ww // 2) % ww - ww // 2
        dy = (yy - y + hh // 2) % hh - hh // 2 if wrap_y else yy - y
        near = dx * dx + dy * dy < (mm(30) / f) ** 2
        # The blob's long axis from its second moments within 30 mm.
        m = near & inside
        ex, ey = dx[m].astype(np.float64), dy[m].astype(np.float64)
        cxx, cyy, cxy = (ex * ex).mean(), (ey * ey).mean(), (ex * ey).mean()
        tr, det = cxx + cyy, cxx * cyy - cxy * cxy
        l1 = tr / 2 + np.sqrt(max(tr * tr / 4 - det, 0))
        l2 = max(tr - l1, 1e-6)
        axis = 0.5 * np.arctan2(2 * cxy, cxx - cyy)
        found.append((x * f + f / 2, y * f + f / 2, d[y, x], np.sqrt(l1 / l2), axis))
        d[near] = 0
    placed = []
    for x, y, dep, aspect, axis in found:
        R = float(np.clip(dep * 2.8, mm(15), mm(33)))
        if aspect > 1.45:
            pool = ['side', 'half_open', 'three_quarter']
        elif aspect > 1.2:
            pool = ['three_quarter', 'side', 'face6', 'face']
        else:
            pool = ['face', 'face6', 'three_quarter']
        if R < mm(17):
            pool = ['bud', 'half_open'] + pool[:1]
        near = sorted(placed, key=lambda q: np.hypot(q[0] - x, q[1] - y))[:2]
        taken = {q[2] for q in near}
        kind = next((kd for kd in rng.permutation(pool) if kd not in taken), pool[0])
        placed.append((x, y, kind))
        if kind in ('face', 'face6'):
            rot = rng.uniform(0, 2 * np.pi)
        else:
            rot = axis                                    # squash across the long axis
            rot = (rot + np.pi / 2) % np.pi - np.pi / 2    # facing up the curtain
            rot += rng.normal(0, 0.15)
        tilt = KINDS[kind][0] if kind in KINDS else 0.6
        if kind != 'face':
            R = float(min(R / np.sqrt(max(tilt, 0.5)), mm(34)))
        kk = max(tilt, 0.55)
        ix, X, Y = cv.box(x - R * 1.2, y - R * 1.2, x + R * 1.2, y + R * 1.2)
        cr, sr = np.cos(rot), np.sin(rot)
        u, v = cr * (X - x) + sr * (Y - y), -sr * (X - x) + cr * (Y - y)
        cv.sd[ix] = np.maximum(cv.sd[ix], R * 1.06 - np.hypot(u, v / kk))
        draw_variant(cv, kind, (x, y), R if kind != 'bud' else R * 0.75, rot, rng)
    print(f'regrew {len(found)} flowers:', ', '.join(q[2] for q in placed))
    return cv.finish()


def _tile(a, h, w):
    return np.tile(a, (-(-h // a.shape[0]), -(-w // a.shape[1])))[:h, :w]


def bake(out):
    src_path = cm.source('library-lace-01.png')
    src = cm.load(src_path)
    net = lace.net_tile()
    cloth = (lc.weave('whole'), lc.weave('half'))
    variant_sheet(out, cloth, net)
    sd_a, half_a = lc.sharpen(lc.source_tile(src), N, N)
    sd, vein, half = regrow(sd_a, half_a)
    motif = lc.render(sd, vein, half, cloth)

    def hem_c_motifs(cv, g, traced=lc.hem_motifs_traced(src)):     # way c's, unchanged
        sd_h, _, half_h = traced(cv, g)
        return lc.regrow_flowers(sd_h, half_h, wrap_y=False)
    hem = lc.hem_strip(hem_c_motifs, cloth, motif)
    mean = lc.views(out, 'd', motif, hem, net, (1500, 1000))
    cm.save(os.path.join(out, 'd_motif.png'), lace.box(motif, 4))
    big = np.maximum(lace.tiled(net, lace.NET_REPEAT), motif)
    for i, (cy, cx) in enumerate(CLOSE_UPS):
        f, b = lace.shade(np.roll(big, (-cy, -cx), (0, 1))[:1024, :1024])
        lace.save_jpg(os.path.join(out, f'd_close{i + 2}.jpg'), np.concatenate([f, b], 1))
    srcflower = np.asarray(Image.open(src_path).convert('RGB'), np.float32)[240:500, 120:380] / 255
    crops = [srcflower]
    for path in (os.path.join(out, '..', 'materials-lace-3', 'c_close.jpg'), os.path.join(out, 'd_close.jpg')):
        if os.path.exists(path):
            crops.append(np.asarray(Image.open(path), np.float32)[:, :1024] / 255)
    lc.compare_strip(out, crops)
    write_contact(out, mean)


CLOSE_UPS = ((300, 2300), (2600, 200), (2700, 2500))     # more flowers, beside views' one


def write_contact(out, mean):
    def fig(src, caption, cls=''):
        return f'<figure class="{cls}"><img src="{src}"><figcaption>{caption}</figcaption></figure>'

    c = '../materials-lace-3/'
    rows = [
        ('The blossoms alone', 'Each variant twice, 8 cm cells at full detail: face on (five petals), face on '
         '(six), three-quarters, from the side, half open, a bud.', [
            fig('variants.jpg', 'on dark', 'full'),
            fig('variants_backlit.jpg', 'backlit', 'full'),
        ]),
        ('Side by side', 'The same patch: the download (source px), way c, the new one (14 cm, on dark).', [
            fig('compare_flower.jpg', 'download / c / new', 'full'),
        ]),
        ('Close up, 14 cm: on dark and backlit', '', [
            fig(c + 'c_close.jpg', 'way c', 'wide'),
            fig('d_close.jpg', 'new, the same patch', 'wide'),
            fig('d_close2.jpg', 'new, elsewhere', 'wide'),
            fig('d_close3.jpg', 'new, elsewhere', 'wide'),
            fig('d_close4.jpg', 'new, elsewhere', 'wide'),
        ]),
        ('Tiled 3x3 (1.7 m)', '', [
            fig(c + 'c_backlit_3x3.jpg', 'c backlit'),
            fig('d_backlit_3x3.jpg', 'new backlit'),
            fig(c + 'c_preview_3x3.jpg', 'c on dark'),
            fig('d_preview_3x3.jpg', 'new on dark'),
        ]),
        ('From afar: an eighth, 6x6 (3.4 m)', '', [
            fig(c + 'c_backlit_far.jpg', 'c backlit'),
            fig('d_backlit_far.jpg', 'new backlit'),
            fig(c + 'c_preview_far.jpg', 'c on dark'),
            fig('d_preview_far.jpg', 'new on dark'),
        ]),
        ('The hem under the field, 1.1 m, backlit', "The hem is way c's; only the field above it changed.", [
            fig(c + 'c_hem_backlit.jpg', 'c', 'wide'),
            fig('d_hem_backlit.jpg', 'new', 'wide'),
            fig('d_hem_close.jpg', 'new, the hem close up (14 cm)', 'wide'),
            fig('d_hem_front.jpg', 'new on dark', 'wide'),
        ]),
        ('The texture', '', [fig('d_motif.png', 'motif coverage, averaged to 1024 px')]),
    ]
    body = '\n'.join(f'<h2>{t}</h2><p>{n}</p><div class="row">{"".join(f)}</div>' for t, n, f in rows)
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Library lace, blossoms</title>
<style>
:root {{ --bg: #1b1a19; --fg: #e8e4dc; --muted: #a39d92; }}
body {{ background: var(--bg); color: var(--fg); font: 15px/1.45 system-ui, sans-serif;
       margin: 0; padding: 16px 24px 48px; }}
h1 {{ font-size: 22px; margin: 8px 0 4px; }}
h2 {{ font-size: 17px; margin: 28px 0 8px; }}
p {{ color: var(--muted); margin: 0 0 12px; max-width: 80ch; }}
a {{ color: inherit; }}
.row {{ display: flex; flex-wrap: wrap; gap: 14px; align-items: flex-start; }}
figure {{ margin: 0; width: 420px; max-width: 100%; }}
figure.wide {{ width: 860px; }}
figure.full {{ width: 100%; }}
img {{ width: 100%; display: block; background: #000; }}
figcaption {{ color: var(--muted); font-size: 13px; margin-top: 4px; }}
</style></head><body>
<h1>Library lace, blossoms</h1>
<p>Way c (<a href="{c}contact.html">materials-lace-3</a>) with its big flowers redrawn as wild
roses in the download's hand, by tools/materials/lace_blossom.py. Mean field coverage
{mean:.2f}. Click an image to open it full size.</p>
{body}
<script>document.querySelectorAll('img').forEach(i => i.onclick = () => window.open(i.src));</script>
</body></html>
'''
    with open(os.path.join(out, 'contact.html'), 'w') as fh:
        fh.write(html)
    print('wrote', os.path.join(out, 'contact.html'))


if __name__ == '__main__':
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    os.makedirs(sys.argv[1], exist_ok=True)
    bake(sys.argv[1])
