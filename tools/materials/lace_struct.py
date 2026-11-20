#!/usr/bin/env python3
"""Prototype: the library's lace rebuilt from the download's structure (way e).

    python3 tools/materials/lace_struct.py OUT_DIR [--seed N] [--scallops 1|2] [--overlay DIR]

--seed draws the leaves' and blossoms' own variation (3); --scallops sets the hem's edge
scallops under each garland arc (1, ways c and d's; the download has 2); --overlay
writes the reading (flowers, stems, leaves drawn over the download) and its page to DIR.
The library's copies:
    lace_struct.py build/notes/lace-library/e --seed 3 --overlay build/notes/lace-struct
    lace_struct.py build/notes/lace-library/e-hem2 --seed 3 --scallops 2

Way d took every big blob of the traced download for a flower; the download has few
flowers and many leaves on clear stems. This way reads the download's structure first,
on its field tile (lace_crisp.source_tile, two trails across), then draws it new:
- Flowers by their boss, not their size: a ring of dark eyelets round a lit centre, with
  solid petals round it, at 6 to 12 download px; a tilted boss shows only half its ring,
  so the best half counts. The tile holds the trail twice (lace.REPEAT apart), so a boss
  must be found in both copies. Each is drawn as lace_blossom's wild rose, tilted,
  sized by how far its petals reach and turned to its blob.
- Stems: the silhouette's stem-width parts (what an opening of the leaves leaves),
  thinned to a skeleton, cut into paths at their branch points, the spurs pruned, and
  smoothed. Where a stem runs into a leaf and out the other side it is carried through.
- Leaves: the rest of the silhouette, each blob cut into lobes at the peaks of its
  distance to the edge; a blob of one lobe is a single leaf, of two a pair, of more a
  spray. Each lobe is a pointed leaf of lace_crisp's (midrib, side veins, a light
  serration), fitted to the lobe's length, width and axis a little smaller, so leaves
  stay apart, its base toward the stem with a short petiole to it, half stitch on the
  side the download shades. A small round lobe at a stem's end is a bud.
The hem is way c's (lace_crisp's parametric hem, its openwork filled with the traced and
regrown flowers), with the edge's scallops as --scallops says.
"""

import os
import sys

import numpy as np
from PIL import Image, ImageDraw

import common as cm
import lace
import lace_blossom as lb
import lace_crisp as lc
from lace_crisp import BIG, N, mm

T = 2 * lace.REPEAT          # download px a field tile: 694
A = 2                        # analysis px a download px
TA = T * A
S = N / T                    # full-detail px a download px: 5.9

BOSS_R = range(6, 13)        # download px: an eyelet ring's radius
BOSS_DARK = 0.25             # coverage under which a ring's sample is an eyelet
BOSS_MIN = 0.63              # the boss score, summed over the trail's two copies
STEM_HALF = 3.2              # download px: a part narrower than twice this is stem
SPUR = 7.0                   # download px: shorter dead-end stems are pruned
LEAF_SHRINK = 0.9            # the leaves drawn this much of their lobe's length and
LEAF_WIDTH = 0.95            # width, so they part
LEAF_MIN = 7.0               # download px: a lobe shorter than this in a bigger blob is no leaf
FLOWER_R = (18.0, 46.0)      # download px: the least and most a flower's petals reach
BUD_LEN = 9.0                # download px: a round lobe shorter than this on a stem's end
SEED = 3


# Reading the download.

def roll(a, dx, dy):
    return np.roll(a, (-dy, -dx), (0, 1))


def bil(a, dx, dy):
    ix, iy = int(np.floor(dx)), int(np.floor(dy))
    fx, fy = dx - ix, dy - iy
    return (roll(a, ix, iy) * (1 - fx) * (1 - fy) + roll(a, ix + 1, iy) * fx * (1 - fy)
            + roll(a, ix, iy + 1) * (1 - fx) * fy + roll(a, ix + 1, iy + 1) * fx * fy)


def boss_score(c, K=32):
    """For every px, how much it looks like a boss's centre: the best half of a ring of
    eyelets (dark samples, in separate runs) at radius r, minus dark samples inside the
    ring and just outside it, with lit cloth round it. Returns the score and r."""
    cs = lace.blur(c, 0.5, True)
    cb = lace.blur(c, 1.5, True)
    h, w = c.shape

    def hits(r0, r1):
        out = np.zeros((K, h, w), np.float32)
        for k in range(K):
            th = 2 * np.pi * k / K
            m = np.full((h, w), 9.0, np.float32)
            for r in np.arange(r0, r1 + 0.01, 0.5):
                m = np.minimum(m, bil(cs, r * np.cos(th), r * np.sin(th)))
            out[k] = m < BOSS_DARK
        return out

    def lit(r0, r1):
        acc = np.zeros((h, w), np.float32)
        n = 0
        for k in range(K):
            th = 2 * np.pi * k / K
            for r in np.arange(r0, r1 + 0.01, 1.0):
                acc += bil(cb, r * np.cos(th), r * np.sin(th))
                n += 1
        return np.clip((acc / n - 0.5) / 0.15, 0, 1)

    def arc(a, st, n):
        return a[[(st + i) % K for i in range(n)]].mean(0)

    best = np.zeros((h, w), np.float32)
    rad = np.zeros((h, w), np.float32)
    for r in BOSS_R:
        ring = hits(r - 2.0, r + 2.0)
        inner = hits(3.0, max(r - 3.5, 3.0))
        outer = hits(r + 3.5, r + 6.5)
        solid = lit(r + 3.5, r + 6.5)
        starts = ring * (1 - np.roll(ring, 1, 0))
        n = K // 2
        s = np.zeros((h, w), np.float32)
        for st in range(0, K, 2):
            runs = arc(starts, st, n) * n
            v = (arc(ring, st, n) - arc(inner, st, n) - arc(outer, st, n)) * (runs >= 4) * runs / 6
            s = np.maximum(s, v)
        s *= solid
        rad = np.where(s > best, r, rad)
        best = np.maximum(best, s)
    return best, rad


def find_bosses(c):
    """The bosses: peaks of the score that the trail's other copy, REPEAT px across,
    confirms. Returns (x, y, ring radius) in download px of the tile."""
    s, rad = boss_score(c)
    sb = lace.blur(s, 0.7, True)
    m = sb.copy()
    for dy in range(-7, 8):
        for dx in range(-7, 8):
            if dx * dx + dy * dy <= 49:
                m = np.maximum(m, roll(sb, dx, dy))
    pair = sb + roll(m, lace.REPEAT, 0)
    h, w = c.shape
    yy, xx = np.mgrid[0:h, 0:w]
    found = []
    d = pair.copy()
    while True:
        k = int(np.argmax(d))
        y, x = divmod(k, w)
        if d[y, x] < BOSS_MIN:
            break
        found.append((float(x), float(y), float(rad[y, x]), float(d[y, x])))
        dx = (xx - x + w // 2) % w - w // 2
        dy = (yy - y + h // 2) % h - h // 2
        d[dx * dx + dy * dy < 25 ** 2] = 0
    return found


def label(mask, diag=False):
    """Connected parts (4-neighbours, or 8 with diag; wrapping): each px's label is the
    smallest flat index in its part; -1 outside."""
    h, w = mask.shape
    idx = np.arange(h * w).reshape(h, w)
    big = h * w
    lab = np.where(mask, idx, big)
    flat_mask = mask.ravel()
    while True:
        m = lab
        for dx, dy in NB8[:8 if diag else 4]:
            m = np.minimum(m, np.where(mask, roll(lab, dx, dy), big))
        f = m.ravel().copy()
        f[flat_mask] = f[f[flat_mask]]
        f[flat_mask] = f[f[flat_mask]]
        m = f.reshape(h, w)
        if np.array_equal(m, lab):
            break
        lab = m
    return np.where(mask, lab, -1)


def thin(mask):
    """Zhang and Suen's thinning, wrapping."""
    m = mask.copy()
    while True:
        changed = False
        for step in (0, 1):
            P = [roll(m, dx, dy) for dx, dy in ((0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1))]
            P = [p.astype(np.int8) for p in P]
            B = sum(P)
            A_ = sum(((P[i] == 0) & (P[(i + 1) % 8] == 1)).astype(np.int8) for i in range(8))
            if step == 0:
                c1 = P[0] * P[2] * P[4] == 0
                c2 = P[2] * P[4] * P[6] == 0
            else:
                c1 = P[0] * P[2] * P[6] == 0
                c2 = P[0] * P[4] * P[6] == 0
            kill = m & (B >= 2) & (B <= 6) & (A_ == 1) & c1 & c2
            if kill.any():
                m &= ~kill
                changed = True
        if not changed:
            return m


NB8 = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))


def skeleton_paths(sk):
    """The skeleton cut into paths between its nodes (its ends, and each cluster of
    branch px as one), each an unwrapped line of (x, y) px with its two node ids."""
    h, w = sk.shape
    ring = [roll(sk, dx, dy) for dx, dy in ((0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1), (-1, 0), (-1, -1))]
    trans = sum((~ring[i] & ring[(i + 1) % 8]).astype(np.int8) for i in range(8))
    nb = sum(r.astype(np.int8) for r in ring)
    node = sk & ((trans != 2) | (nb >= 4))
    nid = label(node, diag=True)
    visited = np.zeros_like(sk)
    paths = []
    for y, x in zip(*np.nonzero(node)):
        a = nid[y, x]
        for dx, dy in NB8:
            qy, qx = (y + dy) % h, (x + dx) % w
            if not sk[qy, qx] or node[qy, qx] or visited[qy, qx]:
                continue
            visited[qy, qx] = True
            ux, uy = x + dx, y + dy
            line = [(x, y), (ux, uy)]
            cy, cx = qy, qx
            end = None
            while end is None:
                step = None
                for ddx, ddy in NB8:
                    ry, rx = (cy + ddy) % h, (cx + ddx) % w
                    if node[ry, rx] and (nid[ry, rx] != a or len(line) > 3):
                        step, end = (ddx, ddy), nid[ry, rx]
                        break
                if step is None:
                    for ddx, ddy in NB8:
                        ry, rx = (cy + ddy) % h, (cx + ddx) % w
                        if sk[ry, rx] and not node[ry, rx] and not visited[ry, rx]:
                            step = (ddx, ddy)
                            break
                if step is None:
                    break
                ux, uy = ux + step[0], uy + step[1]
                line.append((ux, uy))
                cy, cx = (cy + step[1]) % h, (cx + step[0]) % w
                visited[cy, cx] = True
            if end is not None:
                paths.append(dict(a=int(a), b=int(end), line=np.array(line, np.float64)))
    return paths


def chains(paths, n_of):
    """Paths joined through the nodes where exactly two meet, as long lines; n_of maps
    a node to how many paths meet there."""
    at = {}
    for i, p in enumerate(paths):
        at.setdefault(p['a'], []).append((i, 0))
        at.setdefault(p['b'], []).append((i, 1))
    used = set()
    out = []

    def oriented(i, end):
        ln = paths[i]['line']
        return (ln if end == 0 else ln[::-1]), (paths[i]['b'] if end == 0 else paths[i]['a'])

    starts = [n for n in at if n_of[n] != 2] + list(at)
    for n0 in starts:
        for i, end in at[n0]:
            if i in used:
                continue
            used.add(i)
            line, n = oriented(i, end)
            parts = [line]
            while n_of[n] == 2 and n != n0:
                nxt = [(j, e) for j, e in at[n] if j not in used]
                if not nxt:
                    break
                j, e = nxt[0]
                used.add(j)
                ln, n = oriented(j, e)
                off = np.round((parts[-1][-1] - ln[0]) / TA) * TA
                parts.append(ln + off)
            out.append(dict(line=np.concatenate(parts, 0), a=n0, b=n))
    return out


def smooth(line, k=4):
    """A moving average along the path, ends kept, then resampled every px."""
    if len(line) < 3:
        return line
    out = line.copy()
    for i in range(1, len(line) - 1):
        j0, j1 = max(0, i - k), min(len(line), i + k + 1)
        n = min(i - j0, j1 - 1 - i)
        out[i] = line[i - n:i + n + 1].mean(0)
    seg = np.hypot(*np.diff(out, axis=0).T)
    s = np.concatenate([[0], np.cumsum(seg)])
    if s[-1] < 1:
        return out
    t = np.linspace(0, s[-1], max(int(s[-1]) + 1, 2))
    return np.stack([np.interp(t, s, out[:, 0]), np.interp(t, s, out[:, 1])], 1)


def longest_run(ok):
    """The slice of the longest run of True in ok."""
    best, start = (0, 0), None
    for i, v in enumerate(list(ok) + [False]):
        if v and start is None:
            start = i
        elif not v and start is not None:
            if i - start > best[1] - best[0]:
                best = (start, i)
            start = None
    return slice(*best)


def wrap_d(dx, n):
    return (dx + n / 2) % n - n / 2


def read(src):
    """The download's structure on its field tile. Returns a dict of flowers, stems,
    leaves (in download px of the tile, unwrapped) and the analysis maps."""
    c = lc.source_tile(src)
    bosses = find_bosses(c)
    # The silhouette at A x the download's px, as lace_crisp.sharpen's, its holes filled.
    sil = lace.ramp(cm.resize_periodic(lace.blur(c, lace.SHAPE_BLUR, True), TA, TA), lace.SHAPE)
    sil = sil * lace.ramp(lace.blur(sil, lace.SUPPORT, True), lace.SUPPORT_MIN)
    mask = sil > 0.5
    holes = label(~mask)
    ids, counts = np.unique(holes[holes >= 0], return_counts=True)
    small = ids[counts < 40 * A * A]
    mask |= np.isin(holes, small)
    dist = lc.edt_band(~mask, 24 * A)                       # A px to the edge, inside
    cov = cm.resize_periodic(c, TA, TA)

    # Flowers: how far the petals reach from the boss, and the blob's axis round it.
    flowers = []
    fmask = np.zeros_like(mask)
    yy, xx = np.mgrid[0:TA, 0:TA].astype(np.float32)
    for bx, by, br, score in bosses:
        cx, cy = bx * A, by * A
        reach = []
        for k in range(48):
            th = 2 * np.pi * k / 48
            r = (br + 4) * A                    # past the eyelets
            while r < FLOWER_R[1] * 1.2 * A:
                x, y = int(round(cx + r * np.cos(th))) % TA, int(round(cy + r * np.sin(th))) % TA
                if not mask[y, x]:
                    break
                r += 1
            reach.append(r)
        R = float(np.clip(np.percentile(reach, 70), FLOWER_R[0] * A, FLOWER_R[1] * A))
        dx, dy = wrap_d(xx - cx, TA), wrap_d(yy - cy, TA)
        near = (dx * dx + dy * dy < (1.1 * R) ** 2) & mask
        ex, ey = dx[near].astype(np.float64), dy[near].astype(np.float64)
        cxx, cyy, cxy = (ex * ex).mean(), (ey * ey).mean(), (ex * ey).mean()
        tr, det = cxx + cyy, cxx * cyy - cxy * cxy
        l1 = tr / 2 + np.sqrt(max(tr * tr / 4 - det, 0))
        l2 = max(tr - l1, 1e-6)
        axis = 0.5 * np.arctan2(2 * cxy, cxx - cyy)
        # The petals' centre: where the blob's mass is, the boss toward the far side.
        off = (ex.mean(), ey.mean())
        flowers.append(dict(x=bx, y=by, ring=br, R=R / A, aspect=float(np.sqrt(l1 / l2)),
                            axis=float(axis), off=(off[0] / A, off[1] / A), score=score))
        fmask |= dx * dx + dy * dy < (1.12 * R) ** 2

    # Leaves and stems: the opening of the silhouette by a disc a stem's width keeps the
    # leaves; what it drops is stem.
    rest = mask & ~fmask
    d_rest = lc.edt_band(~rest, 24 * A)
    core = d_rest >= STEM_HALF * A
    body = lc.edt_band(core, 8) <= STEM_HALF * A + 0.5
    body &= rest
    stem = rest & ~body
    # Stems: the whole silhouette thinned, its paths a stem's width (or short wide ones
    # between two stems: a stem carried through a leaf's foot), dead ends shorter than
    # SPUR pruned, joined into long lines and smoothed.
    paths = skeleton_paths(thin(rest))
    for p in paths:
        ys = p['line'][:, 1].astype(int) % TA
        xs = p['line'][:, 0].astype(int) % TA
        p['half'] = float(np.percentile(d_rest[ys, xs], 30)) / A
        p['len'] = len(p['line']) / A
    # Of two paths between the same nodes (a small loop round a hole) the shorter.
    best = {}
    for p in paths:
        key = (min(p['a'], p['b']), max(p['a'], p['b']))
        if p['a'] != p['b'] and (key not in best or p['len'] < best[key]['len']):
            best[key] = p
    paths = list(best.values())
    thin_ = [p for p in paths if p['half'] <= STEM_HALF]

    def count(ps):
        n = {}
        for p in ps:
            for e in (p['a'], p['b']):
                n[e] = n.get(e, 0) + 1
        return n

    for _ in range(3):
        n = count(thin_)
        thin_ = [p for p in thin_ if not ((n[p['a']] == 1 or n[p['b']] == 1) and p['len'] < SPUR)]
    n = count(thin_)
    through = [p for p in paths if p['half'] > STEM_HALF and p['len'] < 40 and n.get(p['a'], 0) >= 1 and n.get(p['b'], 0) >= 1 and p['a'] != p['b']]
    keep = thin_ + through
    n = count(keep)
    stems = []
    for ch in chains(keep, n):
        L = len(ch['line']) / A
        if n[ch['a']] == 1 and n[ch['b']] == 1 and L < 2.5 * SPUR:
            continue
        line = ch['line']
        # A dead end that runs on into a leaf stops at the leaf's edge: the leaf's base.
        inside = body[np.round(line[:, 1]).astype(int) % TA, np.round(line[:, 0]).astype(int) % TA]
        if n[ch['b']] == 1:
            k = len(line)
            while k > 1 and inside[k - 1]:
                k -= 1
            line, inside = line[:k], inside[:k]
        if n[ch['a']] == 1:
            k = 0
            while k < len(line) - 1 and inside[k]:
                k += 1
            line = line[k:]
        if len(line) < 2 * A:
            continue
        # Clear of the flowers, and a stem that ends near one runs on into it.
        for f in flowers:
            fx, fy = f['x'] * A, f['y'] * A
            far = np.hypot(wrap_d(line[:, 0] - fx, TA), wrap_d(line[:, 1] - fy, TA)) > 1.2 * f['R'] * A
            if not far.all():
                line = line[longest_run(far)]
            if len(line) < 2 * A:
                break
        if len(line) < 2 * A:
            continue
        line = smooth(smooth(line, 5 * A), 5 * A)
        for end in (0, -1):
            p0 = line[end]
            for f in flowers:
                fx, fy = f['x'] * A, f['y'] * A
                v = np.array([wrap_d(fx - p0[0], TA), wrap_d(fy - p0[1], TA)])
                dv = np.hypot(*v)
                tang = line[end] - line[min(3, len(line) - 1) if end == 0 else max(-4, -len(line))]
                tang = tang / max(np.hypot(*tang), 1e-6)
                if dv < 2.0 * f['R'] * A and tang @ v > 0.2 * dv:
                    q = p0 + v * (1 - 0.7 * f['R'] * A / dv)
                    ext = lc.bezier(p0, p0 + tang * dv * 0.35, q, 10)
                    line = np.concatenate([ext[::-1], line], 0) if end == 0 else np.concatenate([line, ext], 0)
                    break
        ys = np.round(line[:, 1]).astype(int) % TA
        xs = np.round(line[:, 0]).astype(int) % TA
        half = float(np.median(np.minimum(d_rest[ys, xs], STEM_HALF * A))) / A
        stems.append(dict(line=line / A, half=half, a=ch['a'], b=ch['b']))
    ends = count(stems)
    nodes_xy = {}
    for st_ in stems:
        nodes_xy[st_['a']] = st_['line'][0]
        nodes_xy[st_['b']] = st_['line'][-1]
    branch_pts = [tuple(nodes_xy[e]) for e, k in ends.items() if k >= 3]
    tips = [tuple(nodes_xy[e]) for e, k in ends.items() if k == 1]
    links = []

    # The leaves: each body part cut into lobes at the peaks of its distance.
    lab = label(body)
    stem_pts = np.concatenate([s['line'] for s in stems], 0) if stems else np.zeros((0, 2))
    leaves = []
    groups = []
    db = lace.blur(d_rest * body, 1.0, True)
    peak = body & (db >= STEM_HALF * A * 1.3)
    for dx, dy in NB8:
        peak &= db >= roll(db, dx, dy)
    for g in np.unique(lab[lab >= 0]):
        sel = lab == g
        ys, xs = np.nonzero(sel)
        if len(xs) < 30 * A * A:
            continue
        x0, y0 = xs[0], ys[0]
        ux = x0 + wrap_d(xs - x0, TA)
        uy = y0 + wrap_d(ys - y0, TA)
        pk = peak[ys, xs]
        cand = sorted(zip(db[ys, xs][pk], ux[pk], uy[pk]), reverse=True)
        seeds = []
        for v, sx, sy in cand:
            if all(np.hypot(sx - qx, sy - qy) > 1.1 * max(v, qv) + 2 * A for qv, qx, qy in seeds):
                seeds.append((v, sx, sy))
        if not seeds:
            continue
        sv = np.array([q[0] for q in seeds])
        sxy = np.array([(q[1], q[2]) for q in seeds])
        dd = np.hypot(ux[:, None] - sxy[None, :, 0], uy[:, None] - sxy[None, :, 1]) / sv[None, :]
        own = np.argmin(dd, 1)
        gc = (ux.mean(), uy.mean())
        lobes = []
        for i in range(len(seeds)):
            m = own == i
            if m.sum() < 12 * A * A:
                continue
            lx, ly = ux[m].astype(np.float64), uy[m].astype(np.float64)
            mx, my = lx.mean(), ly.mean()
            ex, ey = lx - mx, ly - my
            cxx, cyy, cxy = (ex * ex).mean(), (ey * ey).mean(), (ex * ey).mean()
            tr, det = cxx + cyy, cxx * cyy - cxy * cxy
            l1 = tr / 2 + np.sqrt(max(tr * tr / 4 - det, 0))
            l2 = max(tr - l1, 1e-6)
            ang = 0.5 * np.arctan2(2 * cxy, cxx - cyy)
            along = ex * np.cos(ang) + ey * np.sin(ang)
            L = float(along.max() - along.min())
            Wd = float(4.0 * np.sqrt(l2))
            # Its shading: the mean coverage each side of the axis, in the download.
            across = -ex * np.sin(ang) + ey * np.cos(ang)
            cv_ = cov[ly.astype(int) % TA, lx.astype(int) % TA]
            pos, neg = cv_[across > 0].mean() if (across > 0).any() else 1, cv_[across < 0].mean() if (across < 0).any() else 1
            if any(np.hypot(wrap_d(mx / A - f['x'], T), wrap_d(my / A - f['y'], T)) < 1.3 * f['R']
                   and L / A < 0.6 * f['R'] for f in flowers):
                continue                                    # a petal's tip, not a leaf
            if L / A < LEAF_MIN and len(seeds) > 1:
                continue                                    # a knot on the stem
            if len(stem_pts):
                ds = np.hypot(wrap_d(stem_pts[:, 0] - mx / A, T), wrap_d(stem_pts[:, 1] - my / A, T)).min()
                if ds < 0.4 * Wd / A:
                    continue                                # a stem's thickening, run through
            lobes.append(dict(cx=mx / A, cy=my / A, ang=float(ang), L=L / A, W=Wd / A,
                              shade=float(pos - neg), lo=float(along.min()) / A, hi=float(along.max()) / A))
        if not lobes:
            continue
        kind = 'single' if len(lobes) == 1 else 'pair' if len(lobes) == 2 else 'spray'
        group = dict(kind=kind, cx=gc[0] / A, cy=gc[1] / A, lobes=lobes)
        for lo in lobes:
            lo['group'] = len(groups)
            # The base: the lobe's end nearer the stem it hangs from (or the group's
            # middle, for a lobe of a pair or spray away from any stem).
            ca, sa = np.cos(lo['ang']), np.sin(lo['ang'])
            e1 = (lo['cx'] + ca * lo['lo'], lo['cy'] + sa * lo['lo'])
            e2 = (lo['cx'] + ca * lo['hi'], lo['cy'] + sa * lo['hi'])

            def near_stem(p):
                if not len(stem_pts):
                    return BIG, None
                d = np.hypot(wrap_d(stem_pts[:, 0] - p[0], T), wrap_d(stem_pts[:, 1] - p[1], T))
                i = int(np.argmin(d))
                return float(d[i]), stem_pts[i]

            d1, s1 = near_stem(e1)
            d2, s2 = near_stem(e2)
            if len(lobes) > 1 and min(d1, d2) > 0.5 * lo['L']:
                g1 = np.hypot(e1[0] - gc[0] / A, e1[1] - gc[1] / A)
                g2 = np.hypot(e2[0] - gc[0] / A, e2[1] - gc[1] / A)
                base_first = g1 < g2
                att = None
            else:
                base_first = d1 < d2
                att = s1 if base_first else s2
                if min(d1, d2) > 0.35 * lo['L'] + 3:
                    att = None
            lo['base'] = e1 if base_first else e2
            lo['tip'] = e2 if base_first else e1
            lo['attach'] = None if att is None else (float(att[0]), float(att[1]))
            # A bud: short, round, on a stem's tip.
            tip_near = min((np.hypot(wrap_d(t[0] - lo['cx'], T), wrap_d(t[1] - lo['cy'], T)) for t in tips), default=BIG)
            lo['bud'] = (lo['L'] < BUD_LEN and lo['L'] < 1.8 * lo['W'] and len(lobes) == 1
                         and tip_near < lo['L'] * 0.9 + 3)
            leaves.append(lo)
        groups.append(group)
    return dict(c=c, mask=mask, body=body, stem=stem, fmask=fmask, flowers=flowers,
                stems=stems, links=links, n_through=len(through), leaves=leaves, groups=groups, branches=branch_pts, tips=tips)


# Drawing it new.

class Rose(lb.Blossom):
    """lace_blossom's wild rose with its boss scaled to the download's (its ring a
    larger share of the flower than Blossom's)."""

    boss_scale = 1.0

    def boss(self, cv, ix, X, Y, R):
        super().boss(cv, ix, X / self.boss_scale, Y / self.boss_scale, R)


def leaf_outline(lo, shrink=LEAF_SHRINK, n=40):
    """The drawn leaf's outline, download px (for the overlay): Canvas.leaf's profile."""
    bx, by = lo['base']
    tx, ty = lo['tip']
    L = np.hypot(tx - bx, ty - by) * shrink
    a = np.arctan2(ty - by, tx - bx)
    w = lo['W'] / 1.12 * LEAF_WIDTH
    u = np.linspace(0, 1, n)
    half = w * 0.62 * np.sin(np.pi * u ** 0.85) ** 0.7 * (1 - 0.2 * u)
    s = u * L
    pts = [(s_, h) for s_, h in zip(s, half)] + [(s_, -h) for s_, h in zip(s[::-1], half[::-1])]
    ca, sa = np.cos(a), np.sin(a)
    return [(bx + p * ca - q * sa, by + p * sa + q * ca) for p, q in pts]


def draw_field(st, seed=SEED, tilt=lb.TILT_DEG):
    """The structure drawn at full detail: stems, petioles, leaves and buds, then the
    flowers over them."""
    rng = np.random.default_rng(seed)
    cv = lc.Canvas(N, N)
    P = lambda p: (p[0] * S, p[1] * S)
    for s in st['stems'] + st['links']:
        r = float(np.clip(s['half'] * S * 0.8, mm(0.45), mm(1.1)))
        cv.curve('sd', [P(p) for p in s['line'][::2]] + [P(s['line'][-1])], r)
    for lo in st['leaves']:
        b = np.array(lo['base'])
        t = np.array(lo['tip'])
        if lo['attach'] is not None:
            a = np.array(lo['attach'])
            a = b + np.array([wrap_d(a[0] - b[0], T), wrap_d(a[1] - b[1], T)])
            cv.curve('sd', [P(a), P(b + (t - b) * 0.08)], mm(0.55), mm(0.45))
    for lo in st['leaves']:
        b = np.array(lo['base'])
        t = np.array(lo['tip'])
        L = np.hypot(*(t - b)) * S
        ang = float(np.arctan2(t[1] - b[1], t[0] - b[0]))
        if lo['bud']:
            lb.bud(cv, P((b + t) / 2), L / 1.9, float(np.arctan2(t[0] - b[0], -(t[1] - b[1]))), rng)
            continue
        side = 0 if abs(lo['shade']) < 0.04 else (-1 if lo['shade'] > 0 else 1)
        cv.leaf(P(b + (t - b) * (1 - LEAF_SHRINK) * 0.5), ang, L * LEAF_SHRINK,
                lo['W'] * S / 1.12 * LEAF_WIDTH, int(rng.integers(3, 6)), rng.uniform(-0.12, 0.12), side, rng)
    placed = []
    for f in st['flowers']:
        R = f['R'] * S
        if f['aspect'] > 1.45:
            pool = ['three_quarter', 'side']
        elif f['aspect'] > 1.2:
            pool = ['three_quarter', 'face6', 'face']
        else:
            pool = ['face', 'face6']
        kind = str(rng.choice(pool))
        rot = f['axis']
        rot = (rot + np.pi / 2) % np.pi - np.pi / 2
        if kind in ('face', 'face6'):
            rot = rng.uniform(0, 2 * np.pi)
        x, y = f['x'] * S, f['y'] * S
        kk = max(lb.KINDS[kind][0], 0.55)
        ix, X, Y = cv.box(x - R * 1.2, y - R * 1.2, x + R * 1.2, y + R * 1.2)
        cr, sr = np.cos(rot), np.sin(rot)
        u, v = cr * (X - x) + sr * (Y - y), -sr * (X - x) + cr * (Y - y)
        cv.sd[ix] = np.maximum(cv.sd[ix], R * 1.0 - np.hypot(u, v / kk))
        rose = Rose(kind, rng, tilt)
        rose.boss_scale = float(np.clip(f['ring'] / (0.165 * f['R']), 1.0, 1.25))
        rose.draw(cv, (x, y), R / 1.04, rot)
        placed.append(kind)
    print(f'{len(st["flowers"])} flowers ({", ".join(placed)}), {len(st["leaves"])} leaves, '
          f'{len(st["stems"])} stems, {st["n_through"]} carried through')
    return cv.finish()


# The overlay: the reading drawn over the download.

def overlay(st, src, out):
    os.makedirs(out, exist_ok=True)
    x0, y0, _ = lace.FIELD
    k = 2                                                  # overlay px a download px
    crop = src[y0:y0 + T, x0:x0 + T]
    base = Image.fromarray((np.clip(crop, 0, 1) * 255).astype(np.uint8)).resize((T * k, T * k), Image.LANCZOS)
    base = Image.blend(base, Image.new('RGB', base.size, (0, 0, 0)), 0.25)
    colours = dict(single=(90, 230, 90), pair=(255, 170, 40), spray=(230, 80, 230))

    def draw_on(im, k, ox=0, oy=0, width=2):
        d = ImageDraw.Draw(im)
        for dx in (-T, 0, T):
            for dy in (-T, 0, T):
                P = lambda p: ((p[0] + dx - ox) * k, (p[1] + dy - oy) * k)
                for s in st['stems']:
                    d.line([P(p) for p in s['line']], fill=(60, 200, 255), width=width + (1 if s['half'] > 1.6 else 0))
                for s in st['links']:
                    d.line([P(p) for p in s['line']], fill=(60, 200, 255), width=max(1, width - 1))
                for lo in st['leaves']:
                    col = (255, 120, 170) if lo['bud'] else colours[st['groups'][lo['group']]['kind']]
                    ol = [P(p) for p in leaf_outline(lo)]
                    d.line(ol + ol[:1], fill=col, width=width)
                    if lo['attach'] is not None:
                        a, b = lo['attach'], lo['base']
                        a = (b[0] + wrap_d(a[0] - b[0], T), b[1] + wrap_d(a[1] - b[1], T))
                        d.line([P(a), P(b)], fill=(255, 255, 255), width=max(1, width - 1))
                for b in st['branches']:
                    x, y = P(b)
                    d.ellipse((x - 2 * width, y - 2 * width, x + 2 * width, y + 2 * width), fill=(255, 240, 60))
                for f in st['flowers']:
                    x, y = P((f['x'], f['y']))
                    r = f['ring'] * k
                    R = f['R'] * k
                    d.ellipse((x - r, y - r, x + r, y + r), outline=(255, 40, 40), width=width)
                    d.ellipse((x - R, y - R, x + R, y + R), outline=(255, 40, 40), width=width + 1)
        return im

    tile = draw_on(base.copy(), k)
    tile.save(os.path.join(out, 'overlay_tile.png'))
    # The compared patch (lace_compare's field close-up: 14 cm from (0.079, 0.152) m), 4x.
    m = lace.TILE_M / T
    px, py, pw = 0.079 / m, 0.152 / m, 0.14 / m
    kk = 5
    big = Image.fromarray((np.clip(crop, 0, 1) * 255).astype(np.uint8)).crop(
        (int(px), int(py), int(px + pw), int(py + pw))).resize((int(pw) * kk, int(pw) * kk), Image.LANCZOS)
    plain = big.copy()
    big = Image.blend(big, Image.new('RGB', big.size, (0, 0, 0)), 0.2)
    draw_on(big, kk, int(px), int(py), 3)
    pair = Image.new('RGB', (big.width * 2 + 12, big.height), (20, 19, 18))
    pair.paste(plain, (0, 0))
    pair.paste(big, (big.width + 12, 0))
    pair.save(os.path.join(out, 'overlay_patch.png'))
    # The analysis masks: body (leaves, green), stem (blue), flowers (red).
    rgb = np.zeros(st['mask'].shape + (3,), np.float32)
    rgb[st['body']] = (0.3, 0.8, 0.3)
    rgb[st['stem']] = (0.3, 0.6, 1.0)
    rgb[st['fmask'] & st['mask']] = (0.9, 0.3, 0.3)
    cm.save(os.path.join(out, 'masks.png'), rgb)
    kinds = [g['kind'] for g in st['groups']]
    return dict(flowers=len(st['flowers']), leaves=len(st['leaves']),
                buds=sum(lo['bud'] for lo in st['leaves']), single=kinds.count('single'),
                pair=kinds.count('pair'), spray=kinds.count('spray'), stems=len(st['stems']),
                links=st['n_through'], branches=len(st['branches']))


def write_overlay_page(out, counts, ours_patch):
    html = f'''<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Lace structure</title>
<style>
:root {{ --bg: #141312; --fg: #ece8e0; --muted: #a9a399; }}
body {{ background: var(--bg); color: var(--fg); font: 16px/1.5 system-ui, sans-serif; margin: 0; padding: 16px 24px 48px; }}
h1 {{ font-size: 22px; margin: 4px 0; }} h2 {{ font-size: 18px; margin: 28px 0 6px; }}
p, li {{ color: var(--muted); max-width: 100ch; }}
img {{ width: 100%; max-width: 1400px; display: block; }}
.k {{ display: inline-block; width: 14px; height: 14px; border-radius: 2px; vertical-align: -2px; margin-right: 4px; }}
</style></head><body>
<h1>Library lace: the download's structure, read</h1>
<p>By tools/materials/lace_struct.py, on the download's field tile (two trails across,
0.56 m). Per tile: <b>{counts["flowers"]} flowers</b> (way d drew 32), {counts["leaves"]}
leaves in {counts["single"]} single leaves, {counts["pair"]} pairs and {counts["spray"]} sprays,
{counts["buds"]} buds, {counts["stems"]} stem paths with {counts["branches"]} branch points, and
{counts["links"]} stems carried through a leaf.</p>
<ul>
<li><span class="k" style="background:#ff2828"></span>flowers: the boss's eyelet ring (thin) and how far its petals reach (thick)</li>
<li><span class="k" style="background:#3cc8ff"></span>stems, smoothed; <span class="k" style="background:#fff03c"></span>branch points; white: petioles, leaf base to stem</li>
<li>leaves as drawn: <span class="k" style="background:#5ae65a"></span>single, <span class="k" style="background:#ffaa28"></span>pair, <span class="k" style="background:#e650e6"></span>spray, <span class="k" style="background:#ff78aa"></span>bud</li>
</ul>
<h2>The compared patch (14 cm, the field close-up of the comparison)</h2>
<p>The download, then the reading over it, then ours at the same crop.</p>
<img src="overlay_patch.png">
<img src="{ours_patch}" style="max-width:700px; margin-top:12px">
<h2>The whole tile</h2>
<img src="overlay_tile.png">
<h2>What the reading split the silhouette into</h2>
<p>Green: leaf bodies (the opening); blue: stem; red: the flowers' discs.</p>
<img src="masks.png" style="max-width:700px">
</body></html>
'''
    with open(os.path.join(out, 'index.html'), 'w') as fh:
        fh.write(html)
    print('wrote', os.path.join(out, 'index.html'))


CLOSE_AT = (1112, 578)       # full-detail px: the comparison's field close-up's corner


def bake(out, seed=SEED, scallops=1, overlay_dir=None):
    src = cm.load(cm.source('library-lace-01.png'))
    net = lace.net_tile()
    cloth = (lc.weave('whole'), lc.weave('half'))
    st = read(src)
    print(f'read {len(st["flowers"])} flowers:', ', '.join(f'({f["x"]:.0f},{f["y"]:.0f}) r{f["ring"]:.0f}' for f in st['flowers']))
    sd, vein, half = draw_field(st, seed)
    motif = lc.render(sd, vein, half, cloth)
    lc.HEM['scallops'] = scallops
    if scallops == 2:
        lc.HEM.update(lobes=5, edge_cusp=lc.HEM['edge_mid'] - mm(16))

    def hem_motifs(cv, g, traced=lc.hem_motifs_traced(src)):     # way c's
        sd_h, _, half_h = traced(cv, g)
        return lc.regrow_flowers(sd_h, half_h, wrap_y=False)
    hem = lc.hem_strip(hem_motifs, cloth, motif)
    lc.views(out, 'e', motif, hem, net, CLOSE_AT)
    cm.save(os.path.join(out, 'e_motif.png'), lace.box(motif, 4))
    if overlay_dir:
        counts = overlay(st, src, overlay_dir)
        big = np.maximum(lace.tiled(net, lace.NET_REPEAT), motif)
        f, _ = lace.shade(np.roll(big, (-CLOSE_AT[0], -CLOSE_AT[1]), (0, 1))[:1024, :1024])
        lace.save_jpg(os.path.join(overlay_dir, 'ours_patch.jpg'), f)
        write_overlay_page(overlay_dir, counts, 'ours_patch.jpg')


if __name__ == '__main__':
    args = sys.argv[1:]
    opts = dict(zip(args[1::2], args[2::2]))
    if not args or len(args) % 2 != 1 or set(opts) - {'--seed', '--scallops', '--overlay'}:
        sys.exit(__doc__)
    os.makedirs(args[0], exist_ok=True)
    bake(args[0], int(opts.get('--seed', SEED)), int(opts.get('--scallops', 1)), opts.get('--overlay'))
