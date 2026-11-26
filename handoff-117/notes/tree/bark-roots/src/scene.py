# The junction and flare demo on today's skeleton (tools/tree_dump's tree-none-whole.bin):
# the trunk's foot with its roots, the trunk's lowest limb's collar, and a branch's foot on
# that limb; each drawn as today's tubes, as the new mesh with the grown bark, as
# wireframe, and with the grain's lines.
#
# The method ("swell and weld"), all on the tube mesh as it is, no new topology:
#  1. Extra rings near each junction (the parent round the child's foot, the child's first
#     few radii) and more sides on the trunk.
#  2. The child's radius swells toward its foot (the branch collar): r (1 + c e^(-s/(lam r))),
#     more on its underside.
#  3. The parent's vertices move out along their normals by a bump round the child's foot
#     (the trunk collar) and a narrow fold along the contact on the crotch side (the branch
#     bark ridge).
#  4. The child's vertices that fall inside the bumped parent are pushed out onto its
#     surface, a few millimetres under it (the weld), so the child's swollen foot meets the
#     parent at a shallow angle and the parent's mesh covers the seam.
#  5. The bark's grain: the parent's round coordinate bends round the child's footprint
#     (the stream function of a flow past a cylinder); near the contact each vertex also
#     carries the other part's chart and a weight (0.5 on the contact), and the fragment
#     blends the two samples by height.
# The flare: the trunk's lowest rings take lobes over each root; 4-7 root tubes, flattened,
# swell toward the trunk and are welded to it the same way, and dive below the ground.
#
# Usage: python scene.py <dump dir> <out img dir> <bark img dir (crack.npy)> [views...]
import sys, os, math, time, numpy as np
from PIL import Image
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE); sys.path.insert(0, os.path.join(HERE, '..', '..', 'branches', 'src'))
import junction as J
from junction import Chain, tube, recompute_normals
import rast, render, bark, today

DUMP, OUT, BIMG = sys.argv[1], sys.argv[2], sys.argv[3]
seg, limbs, cards = J.load(DUMP + '/tree-none-whole.bin')

def t_of_radius(r): return float(np.clip(np.log(r / 0.004) / np.log(0.45 / 0.004), 0, 1))
def sstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1); return t * t * (3 - 2 * t)
def unit(v): return v / np.linalg.norm(v)
UP = np.array([0, 1.0, 0])

# --- the parts --------------------------------------------------------------------------
tp0, tr0 = J.chain_of(seg, limbs, 0)
GROUND = tp0[0, 1]
R0 = 0.49                                               # the girth without today's flare
tway = unit(tp0[1] - tp0[0])
tp = np.vstack([tp0[0] - tway * 0.5, tp0]); tr = np.concatenate([[R0 * 1.06], tr0]); tr[1] = R0 * 1.06
trunk = Chain(tp, tr)
foot = tp0[0].copy()

lp, lr = J.chain_of(seg, limbs, 1)                      # the lowest limb
cp, cr = J.chain_of(seg, limbs, 164)                    # a rising branch on it
limb = Chain(lp, lr); branch = Chain(cp, cr)

def exit_s(parent, ch):
    """How far along a child's axis it leaves its parent's surface."""
    for s in np.linspace(0, ch.s[-1], 600):
        i = min(np.searchsorted(ch.s, s, side='right') - 1, len(ch.p) - 2)
        t = (s - ch.s[i]) / (ch.s[i + 1] - ch.s[i]); p = ch.p[i] + (ch.p[i + 1] - ch.p[i]) * t
        if parent.dist(p[None])[0] > 0: return s
    return 0.0
s0_l = exit_s(trunk, limb); s0_c = exit_s(limb, branch)

# The branch collar (Shigo 1985: the branch's base swells, wrapped by the trunk's collar),
# more on the underside.
COLLAR = dict(c=0.22, lam=1.2, under=0.3)
FILLET = 0.35                 # the fillet's reach at the contact, a share of the child's radius
def collar_fn(s0, rc, c=COLLAR['c'], lam=COLLAR['lam'], under=COLLAR['under']):
    def f(st, n, r):
        below = max(-(n @ UP), 0.0)
        return r * (1 + c * math.exp(-max(st - s0, 0) / (lam * rc)) * (1 + under * below))
    return f

# --- the roots: 4-7, azimuths uneven with gaps, strengths and reaches their own ----------
rng = np.random.default_rng(5)
NR = 6
gaps = rng.uniform(0.55, 1.6, NR); gaps = gaps / gaps.sum() * 2 * math.pi
phis = (rng.uniform(0, 2 * math.pi) + np.cumsum(gaps)) % (2 * math.pi)
A = rng.uniform(0.25, 0.6, NR)                          # strength: lobe height, root size
D = 2 * R0
Hk = rng.uniform(0.3, 0.8, NR) * D                      # flare height
reach = rng.uniform(0.25, 0.8, NR) * D                  # exposed reach on a lawn (the photos: short)
FLAT = 0.55
roots = []; root_r0 = []
for k in range(NR):
    d = np.array([math.cos(phis[k]), 0, math.sin(phis[k])]); side = np.array([-d[2], 0, d[0]])
    bend = rng.uniform(-0.4, 0.4)
    r0 = R0 * (0.2 + 0.3 * A[k])
    L = reach[k] * 1.5 + 0.8 * R0
    pts, rad = [], []
    for s in np.linspace(0, L, 16):
        way = d * math.cos(bend * s / L) + side * math.sin(bend * s / L)
        sp = max(s - 0.8 * R0, 0) / reach[k]
        dive = sstep(0.5, 1.25, sp)
        p = foot + way * (0.3 * R0 + s)
        p[1] = GROUND - 0.15 * r0 + 0.25 * Hk[k] * math.exp(-s / (0.5 * R0)) - r0 * 2.4 * dive
        pts.append(p); rad.append(r0 * (0.45 + 0.55 * math.exp(-max(s - 0.8 * R0, 0) / (0.8 * reach[k] + 0.15))))
    roots.append(Chain(np.array(pts), np.array(rad))); root_r0.append(r0)

def lobes(x):
    """The trunk's lobes over its roots: each a ridge as wide as its root, highest at the
    ground and fading up over its flare height; nothing above 1.5 m."""
    h = np.maximum(x[:, 1] - GROUND, 0)
    phi = np.arctan2(x[:, 2] - foot[2], x[:, 0] - foot[0])
    out = np.zeros(len(x))
    for k in range(NR):
        dp = (phi - phis[k] + math.pi) % (2 * math.pi) - math.pi
        out += A[k] * R0 * 0.95 * np.exp(-(dp / (0.25 + 0.25 * A[k])) ** 2) * np.exp(-h / Hk[k])
    return (out + 0.06 * R0 * np.exp(-h / (0.4 * D))) * np.clip((1.5 - h) / 0.5, 0, 1)

# --- the parent's bumps: the trunk collar round a child's foot and the bark ridge --------
def extended(ch, back=1.0):
    """The chain carried on back past its foot, its arc length kept (negative behind), so
    a point beside the parent's surface never finds the chain's round end."""
    w = unit(ch.p[1] - ch.p[0])
    e = Chain(np.vstack([ch.p[0] - w * back, ch.p]), np.concatenate([[ch.r[0]], ch.r]))
    e.s = e.s - back
    return e

def bump(x, nrm, ch, rc, s0, collar_h=0.28, ridge_h=0.10, ridge_w=0.22):
    d, r, s, ap, way = extended(ch).closest(x)
    dC = d - r * (1 + COLLAR['c'] * np.exp(-np.maximum(s - s0, 0) / (COLLAR['lam'] * rc)))
    out = collar_h * rc * np.exp(-(np.maximum(dC, 0) / (1.1 * rc)) ** 2) * sstep(0.2 * s0, 0.7 * s0, s)
    # the crotch: the parent's outward way and the child's point against each other
    nC = (x - ap) / np.maximum(d, 1e-9)[:, None]
    crotch = np.clip((-(nrm * nC).sum(1) - 0.05) / 0.45, 0, 1) * sstep(0.3 * s0, 0.8 * s0, s)
    out += ridge_h * rc * np.exp(-(np.maximum(dC, 0) / (ridge_w * rc)) ** 2) * crotch
    return out * sstep(s0 + 5 * rc, s0 + 3 * rc, s)

# --- meshes -----------------------------------------------------------------------------
def stations(total, base_step, dense, start=0.0):
    st = list(np.arange(start, total, base_step)) + [total]
    for a, b, step in dense: st += list(np.arange(max(a, start), min(b, total), step))
    return np.unique(np.round(np.array(st), 4))

def make_tube(chain, st, sides, shift, age, radius_fn=None, flat=1.0):
    tb = tube(chain, st, sides, shift, radius_fn=radius_fn, flat=flat)
    P, S = chain.p, chain.s
    side = J.frame0(unit(P[1] - P[0])); sv, uv_ = [], []
    for s in st:
        i = max(min(np.searchsorted(S, s, side='right') - 1, len(P) - 2), 0)
        way = unit(P[i + 1] - P[i])
        side = side - way * (side @ way); side /= np.linalg.norm(side)
        sv.append(side.copy()); uv_.append(np.cross(way, side))
    tb.update(st=st, sides_v=np.array(sv), ups_v=np.array(uv_), shift=shift, chain=chain)
    tb['age'] = np.full(len(tb['pos']), age); tb['uv2'] = tb['uv'].copy(); tb['w2'] = np.zeros(len(tb['pos']))
    return tb

def chart_coords(tb, x):
    """The tube's chart (u, v in tiles) at points x, from its nearest station's frame."""
    d, r, s, ap, way = tb['chain'].closest(x)
    j = np.clip(np.searchsorted(tb['st'], s), 0, len(tb['st']) - 1)
    o = x - ap
    a = np.arctan2((o * tb['ups_v'][j]).sum(1), (o * tb['sides_v'][j]).sum(1)) % (2 * math.pi)
    return np.stack([a / (2 * math.pi) * tb['rounds'] + tb['shift'][0], s / J.TILE_H + tb['shift'][1]], -1)

def flow_warp(tb, centre_p, rho_u, rho_v, soft=0.8):
    """Bend the parent's round coordinate round a child's footprint: the stream function
    of a flow along the stem past a cylinder, psi = X (1 - soft / r^2)."""
    c = chart_coords(tb, centre_p[None])[0]
    d, r, s, ap, way = tb['chain'].closest(tb['pos'])
    du = (tb['uv'][:, 0] - c[0]) / tb['rounds']; du = (du + 0.5) % 1 - 0.5
    a = du * 2 * math.pi * r; b = (tb['uv'][:, 1] - c[1]) * J.TILE_H
    X = a / rho_u; Y = b / rho_v
    r2 = np.maximum(X * X + Y * Y, 1.0)
    tb['uv'][:, 0] += (X * (1 - soft / r2) * rho_u - a) / (2 * math.pi * r) * tb['rounds']

def unit_rad(ch, y):
    d, r, s, ap, way = ch.closest(y)
    return (y - ap) / np.maximum(d, 1e-9)[:, None]

def weld(child_tb, parent_tb, parent_dist, bumps, reach_w, eps=0.004):
    """Push the child's vertices inside the bumped parent out onto its surface, eps under
    it, along the parent's radial way; near the contact give them the parent's chart."""
    x = child_tb['pos'].copy()
    nP = unit_rad(parent_tb['chain'], x)
    for _ in range(3):
        f = parent_dist(x) - bumps(x)
        inside = f < -eps
        x = np.where(inside[:, None], x - nP * (f + eps)[:, None], x)
    # never far: a vertex the push can't bring out stays hidden inside
    moved = x - child_tb['pos']; L = np.linalg.norm(moved, axis=1)
    far = L > 0.25
    x[far] = child_tb['pos'][far]
    child_tb['pos'] = x
    f = parent_dist(x) - bumps(x)
    w = 0.5 * np.clip(1 - np.maximum(f, 0) / reach_w, 0, 1)
    near = w > 0
    child_tb['uv2'][near] = chart_coords(parent_tb, x[near]); child_tb['w2'][near] = w[near]

def fillet_foot(tb, M, radius_fn, flat, pf, kf, Lf, n_fine=72):
    """The child's first M rings, laid generator by generator (each line along the tube at
    one angle round): find where that line's swollen surface meets the parent (pf, the
    parent's distance with its bumps), then put the M rings from there over Lf along it,
    closer together near the contact. The swelling adds kf (1 - f/kf)^2 by the distance f
    to the parent, so the child meets it at a shallow angle; ring 0 lies on the contact.
    Monotone along each line, so the rings never fold over each other."""
    ch = tb['chain']; st = tb['st']; sides = tb['sides']; rs = sides + 1
    S = np.linspace(st[0], st[M - 1], n_fine)
    def frame_at(sv):
        d, r, s, ap, way = None, None, None, None, None
        i = np.clip(np.searchsorted(ch.s, sv, side='right') - 1, 0, len(ch.p) - 2)
        t = (sv - ch.s[i]) / (ch.s[i + 1] - ch.s[i])
        c = ch.p[i] + (ch.p[i + 1] - ch.p[i]) * t[:, None]
        rr = ch.r[i] + (ch.r[i + 1] - ch.r[i]) * t
        way = (ch.p[i + 1] - ch.p[i]); way /= np.linalg.norm(way, axis=1, keepdims=True)
        j = np.clip(np.searchsorted(st[:M], sv), 0, M - 1)
        side = tb['sides_v'][j]; side = side - way * (side * way).sum(1, keepdims=True)
        side /= np.linalg.norm(side, axis=1, keepdims=True)
        up = np.cross(way, side)
        return c, rr, side, up
    flatv = np.array([1.0 / math.sqrt(flat), flat, 1.0 / math.sqrt(flat)])
    def surface(sv, a, sc=None):
        c, rr, side, up = frame_at(sv)
        n = side * math.cos(a) + up * math.sin(a)
        r1 = np.array([radius_fn(sv[q], n[q], rr[q]) for q in range(len(sv))]) if radius_fn else rr
        off0 = n * r1[:, None] * flatv
        f = pf(c + off0)
        extra = kf * np.clip(1 - np.maximum(f, 0) / kf, 0, 1) ** 2
        if sc is not None: extra = extra * sstep(1.0, 0.5, (sv - sc) / Lf)   # none past the foot
        return c + n * (r1 + extra)[:, None] * flatv, n
    for k in range(rs):
        a = 2 * math.pi * k / sides
        P, n = surface(S, a)
        f = pf(P)
        out = np.nonzero(f >= 0)[0]
        i = out[0] if len(out) else len(S) - 1
        if len(out) == 0:
            sc = st[M - 1] - Lf                 # no contact on this line: it stays inside
        elif i > 0:
            t = f[i - 1] / (f[i - 1] - f[i]); sc = S[i - 1] + (S[i] - S[i - 1]) * t
        else:
            sc = S[0]
        sc = float(np.clip(sc, S[0], st[M - 1] - Lf))
        sj = sc + Lf * (np.arange(M) / (M - 1)) ** 1.7
        Pj, nj = surface(sj, a, sc)
        idx = np.arange(M) * rs + k
        tb['pos'][idx] = Pj; tb['nrm'][idx] = nj
        tb['uv'][idx, 1] = sj / J.TILE_H + tb['shift'][1]

def parent_takes(parent_tb, child_tb, child_dist, reach_w, zone):
    """The parent's vertices near the child take the child's chart, 0.5 at the contact."""
    sel = np.nonzero(zone)[0]
    x = parent_tb['pos'][sel]
    w = 0.5 * np.clip(1 - np.maximum(child_dist(x), 0) / reach_w, 0, 1)
    take = w > parent_tb['w2'][sel]
    if take.any():
        parent_tb['uv2'][sel[take]] = chart_coords(child_tb, x[take]); parent_tb['w2'][sel[take]] = w[take]

def ground_mesh(c, size, n):
    xs = np.linspace(-size, size, n)
    X, Z = np.meshgrid(xs + c[0], xs + c[2])
    Y = GROUND + 0.012 * np.sin(X * 3.1) * np.cos(Z * 2.3)
    pos = np.stack([X, Y, Z], -1).reshape(-1, 3)
    idx = []
    for j in range(n - 1):
        for i in range(n - 1):
            a = j * n + i; idx += [(a, a + n, a + 1), (a + 1, a + n, a + n + 1)]
    return dict(pos=pos, nrm=np.tile([0, 1.0, 0], (len(pos), 1)), along=np.tile([1.0, 0, 0], (len(pos), 1)),
                uv=np.zeros((len(pos), 2)), uv2=np.zeros((len(pos), 2)), w2=np.zeros(len(pos)),
                age=np.ones(len(pos)), idx=np.array(idx))

def merge(parts, kinds):
    keys = ('pos', 'nrm', 'along', 'uv', 'uv2', 'w2', 'age')
    out = {k: [] for k in keys + ('kind', 'idx')}; base = 0
    for p, kind in zip(parts, kinds):
        for k in keys: out[k].append(p[k])
        out['kind'].append(np.full(len(p['pos']), float(kind)))
        out['idx'].append(p['idx'] + base); base += len(p['pos'])
    return {k: np.concatenate(v) for k, v in out.items()}

wl = unit(lp[1] - lp[0]); wc = unit(cp[1] - cp[0])
cpt = lp[0] + wl * s0_l; ccp = cp[0] + wc * s0_c        # where each child leaves its parent
js = trunk.closest(cpt[None])[2][0]; jc = limb.closest(ccp[None])[2][0]

def collar_dist(ch, rc, s0):
    def f(y):
        d, r, s, ap, way = ch.closest(y)
        return d - r * (1 + COLLAR['c'] * np.exp(-np.maximum(s - s0, 0) / (COLLAR['lam'] * rc)))
    return f

def build(new=True):
    t0 = time.time()
    if not new:
        T = make_tube(Chain(tp0, np.concatenate([[0.65], tr0[1:]])), stations(trunk.s[-1] * 0.62 - 0.5, 1.43, []), 12, (0.37, 0.0), 1.0)
        Lm = make_tube(limb, stations(min(limb.s[-1], 2.6), 0.32, []), 9, (0.11, 0.3), t_of_radius(lr[0]))
        Cm = make_tube(branch, stations(min(branch.s[-1], 1.4), 0.3, []), 6, (0.71, 0.6), max(t_of_radius(cr[0]), 0.55))
        parts = [T, Lm, Cm]
    else:
        st_t = stations(trunk.s[-1] * 0.62, 0.35, [(0, 2.2, 0.05), (js - 0.75, js + 0.75, 0.035)])
        T = make_tube(trunk, st_t, 48, (0.37, 0.0), 1.0)
        M = 10
        st_l = np.concatenate([np.linspace(max(s0_l - 2 * lr[0], 0), s0_l + 3 * lr[0], M),
                               stations(min(limb.s[-1], 2.6), 0.3, [(s0_l + 3 * lr[0], s0_l + 5 * lr[0], 0.05), (jc - 0.35, jc + 0.45, 0.03)], start=s0_l + 3.08 * lr[0])])
        Lm = make_tube(limb, st_l, 20, (0.11, 0.3), t_of_radius(lr[0]), radius_fn=collar_fn(s0_l, lr[0]))
        st_c = np.concatenate([np.linspace(max(s0_c - 2 * cr[0], 0), s0_c + 3 * cr[0], M),
                               stations(min(branch.s[-1], 1.4), 0.3, [(s0_c + 3 * cr[0], s0_c + 5 * cr[0], 0.04)], start=s0_c + 3.08 * cr[0])])
        Cm = make_tube(branch, st_c, 12, (0.71, 0.6), max(t_of_radius(cr[0]), 0.55), radius_fn=collar_fn(s0_c, cr[0]))
        # the roots, flattened and swollen toward the trunk
        R = []; rfs = []
        for k, rc in enumerate(roots):
            st_r = np.concatenate([np.linspace(0.3 * R0, 1.5 * R0, M), stations(rc.s[-1], 0.08, [], start=1.55 * R0)])
            rf = lambda st, n, r: r * (1 + 0.6 * math.exp(-max(st - 0.7 * R0, 0) / (0.6 * R0)))
            tb = make_tube(rc, st_r, 14, (0.2 * k, 0.1 * k), 0.9, radius_fn=rf, flat=FLAT); rfs.append(rf)
            d, r, s, ap, way = rc.closest(tb['pos'])
            tb['age'] = np.clip(1.0 - s / rc.s[-1] * 0.15, 0.82, 1.0)
            R.append(tb)
        # the trunk: lobes, then the limb's collar and ridge; the limb's round the branch
        x = T['pos']; n = T['nrm']
        T['pos'] = x + n * (lobes(x) + bump(x, n, limb, lr[0], s0_l))[:, None]
        Lm['pos'] = Lm['pos'] + Lm['nrm'] * bump(Lm['pos'], Lm['nrm'], branch, cr[0], s0_c)[:, None]
        # the grain bends round the feet
        sin_l = np.linalg.norm(np.cross(wl, tway)); sin_c = np.linalg.norm(np.cross(wc, wl))
        flow_warp(T, cpt, lr[0] * 1.35, lr[0] * 1.35 / max(sin_l, 0.3))
        flow_warp(Lm, ccp, cr[0] * 1.35, cr[0] * 1.35 / max(sin_c, 0.3))
        # the feet: each child's first rings laid along its lines from the contact
        pf_l = lambda y: trunk.dist(y) - lobes(y) - bump(y, unit_rad(trunk, y), limb, lr[0], s0_l)
        pf_c = lambda y: limb.dist(y) - bump(y, unit_rad(limb, y), branch, cr[0], s0_c)
        pf_r = lambda y: trunk.dist(y) - lobes(y)
        fillet_foot(Lm, M, collar_fn(s0_l, lr[0]), 1.0, pf_l, FILLET * lr[0], 2.2 * lr[0])
        fillet_foot(Cm, M, collar_fn(s0_c, cr[0]), 1.0, pf_c, FILLET * cr[0], 2.2 * cr[0])
        for k, tb in enumerate(R):
            fillet_foot(tb, M, rfs[k], FLAT, pf_r, 0.35 * root_r0[k] + 0.06, 0.9 * R0)
        # welds: the limb onto the trunk, the branch onto the limb, the roots onto the trunk
        weld(Lm, T, trunk.dist, lambda y: lobes(y) + bump(y, unit_rad(trunk, y), limb, lr[0], s0_l), 0.5 * lr[0])
        weld(Cm, Lm, limb.dist, lambda y: bump(y, unit_rad(limb, y), branch, cr[0], s0_c), 0.5 * cr[0])
        for tb in R:
            weld(tb, T, trunk.dist, lobes, 0.35 * R0)
        parent_takes(T, Lm, collar_dist(limb, lr[0], s0_l), 0.5 * lr[0], np.linalg.norm(T['pos'] - cpt, axis=1) < 5 * lr[0])
        parent_takes(Lm, Cm, collar_dist(branch, cr[0], s0_c), 0.5 * cr[0], np.linalg.norm(Lm['pos'] - ccp, axis=1) < 5 * cr[0])
        for k, tb in enumerate(R):
            parent_takes(T, tb, lambda y, k=k: roots[k].dist(y) - root_r0[k] * 0.3, 0.35 * R0, T['pos'][:, 1] < GROUND + 0.8)
        parts = [T, Lm, Cm] + R
    for p in parts: p['nrm'] = recompute_normals(p)
    G = ground_mesh(foot, 4.0, 90)
    mesh = merge(parts + [G], [0] * len(parts) + [1])
    return mesh, sum(len(p['idx']) for p in parts), time.time() - t0, parts

def views():
    side_l = unit(np.cross(wl, UP)); side_c = unit(np.cross(wc, wl))
    return {
        'flare': rast.Cam(foot + np.array([2.4, 1.15, -2.0]), foot + np.array([0, 0.35, 0]), 44, 900, 680),
        'flare-far': rast.Cam(foot + np.array([5.5, 1.6, -4.6]), foot + np.array([0, 0.9, 0]), 40, 900, 680),
        'collar': rast.Cam(cpt + side_l * 1.25 + np.array([0, -0.3, 0]) + wl * 0.1, cpt + wl * 0.1, 48, 900, 680),
        'collar-below': rast.Cam(cpt - side_l * 0.9 + np.array([0, -0.75, 0]) + wl * 0.3, cpt + wl * 0.1, 50, 900, 680),
        'fork': rast.Cam(ccp - side_c * 0.7 + wl * 0.1 + np.array([0, -0.05, 0]), ccp + wc * 0.06, 46, 900, 680),
    }

if __name__ == '__main__':
    crack = np.load(BIMG + '/crack.npy'); tough = np.load(BIMG + '/tough.npy')
    LT = [0.45, 0.65, 0.82, 1.0]
    layers = []
    for t in LT:
        h, alb, ao = bark.snapshot(crack, tough, t)
        layers.append(render.maps_new(h, alb, ao, bark.normals(h)))
    tl = render.maps_today(today.tile())
    mesh_new, tris_new, tb, parts_new = build(True)
    mesh_old, tris_old, _, parts_old = build(False)
    print('triangles in view: new %d, today %d; build %.1f s (python)' % (tris_new, tris_old, tb))
    for p, name in zip(parts_new[:3], ('trunk', 'limb', 'branch')):
        print('  ', name, len(p['idx']), 'tris', p['sides'], 'sides', len(p['st']), 'rings')
    print('   roots', sum(len(p['idx']) for p in parts_new[3:]), 'tris in', len(parts_new) - 3)
    only = sys.argv[4:] or list(views().keys())
    save = lambda a, fn: Image.fromarray((a * 255).astype(np.uint8)).save(OUT + '/' + fn)
    for name, cam in views().items():
        if name not in only: continue
        light = cam.r * 0.85 + np.array([0, 0.45, 0]) - cam.f * 0.15; light /= np.linalg.norm(light)
        tid, bc, zb = rast.raster(cam, mesh_new['pos'], mesh_new['idx'])
        im_new = rast.shade(cam, mesh_new, tid, bc, zb, layers, LT, light); save(im_new, 'j-%s-new.png' % name)
        save(rast.shade(cam, mesh_new, tid, bc, zb, layers, LT, light, grain=True), 'j-%s-grain.png' % name)
        save(rast.shade(cam, mesh_new, tid, bc, zb, layers, LT, light, mode='plain'), 'j-%s-shape.png' % name)
        w = Image.fromarray((im_new * 255 * 0.55).astype(np.uint8))
        rast.wire(w, cam, mesh_new['pos'], mesh_new['idx'][:tris_new], zb).save(OUT + '/j-%s-wire.png' % name)
        tid, bc, zb = rast.raster(cam, mesh_old['pos'], mesh_old['idx'])
        save(rast.shade(cam, mesh_old, tid, bc, zb, [tl, tl], [0.0, 1.0], light), 'j-%s-today.png' % name)
        print('view', name)
