# Method b: self-organising trees (Palubicki, Horel, Longay, Runions, Lane, Mech and
# Prusinkiewicz 2009, SIGGRAPH), with its shadow grid. Grown year by year:
#   1. Light: each bud casts a pyramid of shadow into the voxels below it, s += a b^-q for
#      q = 0..qmax layers down, p = 0..q across; a bud's light Q = max(C - s + a, 0).
#      The paper: a > 0, b > 1, qmax 4..8, a voxel about one internode.
#   2. Bud fate by the extended Borchert-Honda model: light gathered basipetally; at the
#      base v = alpha Q (alpha = 2 in the paper's figures), sent up and split at each node
#      vm = v lambda Qm / (lambda Qm + (1 - lambda) Ql), vl the rest; lambda 0.46..0.54.
#      A bud given v grows floor(v) internodes of length v / floor(v) internodes.
#   3. Each new internode turns to the default direction + epsilon V (the least shaded
#      neighbour voxel) + eta T (the tropism vector, here up).
#   4. Shedding: a branch whose light per internode falls under a threshold is shed
#      (Takenaka 1994); here it leaves a stub, as maples do.
#   5. Radii by the pipe model, d^n = d1^n + d2^n, n 2..3.
# The maple's: opposite buds, each pair a quarter turn from the last (decussate), 50
# degrees off the shoot. Grown at low detail so it runs in Python (0.30 m);
# the envelope as everywhere (no light outside it). With gravity on, Stava et al. 2014's
# bend is applied after each year, as in their model (gravity.bend_cycle).
import math, numpy as np
from graph import Arr, Crown, UP, norm, turned, pipe_radii
import gravity

P0 = dict(years=36, l=0.30, voxel=0.30, a=0.25, b=2.0, qmax=6, C=1.0, alpha=2.0, lam=0.50,
          eps=0.25, eta=0.04, angle=50.0, nmax=3, shed=0.18, shed_min=6, tip_r=0.010,
          n_exp=2.4, trunk_r=0.5, box=((-12.5, -0.5, -12.5), (12.5, 24.5, 12.5)), crown_base=3.0)


class Tree:
    def __init__(self):
        self.pos = []; self.par = []; self.dir = []; self.main = []; self.lat = []
        self.buds = []      # per node: list of lateral bud directions not yet grown
        self.term = []      # per node: has a living terminal bud
        self.dead = []; self.kind = []; self.roll = []

    def add(self, parent, p, d, roll):
        self.pos.append(np.array(p, float)); self.par.append(parent); self.dir.append(np.array(d, float))
        self.main.append(-1); self.lat.append([]); self.buds.append([]); self.term.append(False)
        self.dead.append(False); self.kind.append(0); self.roll.append(roll)
        return len(self.pos) - 1


def pyramid(qmax, a, b):
    offs = []; w = []
    for q in range(qmax + 1):
        for i in range(-q, q + 1):
            for k in range(-q, q + 1):
                offs.append((i, -q, k)); w.append(a * b ** (-q))
    return np.array(offs), np.array(w)


def grow(P=None, seed=7, crown=None, start=(0, 0, 0), d0=UP, bend=False, gp=None):
    P = dict(P0, **(P or {}))
    rng = np.random.default_rng(seed)
    crown = crown or Crown()
    lo = np.array(P['box'][0]); hi = np.array(P['box'][1]); vx = P['voxel']
    dims = np.ceil((hi - lo) / vx).astype(int) + 1
    offs, ws = pyramid(P['qmax'], P['a'], P['b'])
    T = Tree()
    root = T.add(-1, start, d0, 0.0)
    T.term[root] = True
    acc = None
    tan = math.radians(P['angle'])

    def vox(p):
        return np.clip(((np.asarray(p) - lo) / vx).astype(int), 0, dims - 1)

    for year in range(P['years']):
        N = len(T.pos)
        pos = np.array(T.pos)
        # 1. Light from the shadow grid.
        bud_nodes = [i for i in range(N) if not T.dead[i] and (T.term[i] or T.buds[i])]
        bp = pos[bud_nodes] if bud_nodes else np.zeros((0, 3))
        idx = vox(bp)
        s = np.zeros(dims)
        if len(idx):
            cells = idx[:, None, :] + offs[None, :, :]
            ok = ((cells >= 0) & (cells < dims)).all(axis=2)
            flat = np.ravel_multi_index(tuple(cells[ok].T), dims)
            s = np.bincount(flat, weights=np.broadcast_to(ws, ok.shape)[ok], minlength=int(np.prod(dims))).reshape(dims)
        Qn = {}
        for i, (c, p) in zip(bud_nodes, zip(idx, bp)):
            q = max(P['C'] - s[tuple(c)] + P['a'], 0.0)
            inside = crown.radius(p) <= 1.0 or p[1] < crown.middle[1] - crown.size[1]
            Qn[i] = q if inside else 0.0
        # 2. Basipetal light, internodes per branch.
        Qm_t = np.zeros(N); Ql_b = [None] * N; Qsum = np.zeros(N); cnt = np.ones(N)
        for i in range(N - 1, -1, -1):
            if T.dead[i]: continue
            qb = Qn.get(i, 0.0)
            qt = qb if T.term[i] else 0.0            # the terminal bud's (same voxel)
            qm = Qsum[T.main[i]] if T.main[i] >= 0 else qt
            lat_q = [Qsum[j] for j in T.lat[i] if not T.dead[j]]
            bud_q = [qb] * len(T.buds[i]) if T.pos[i][1] >= P['crown_base'] else []
            Qm_t[i] = qm; Ql_b[i] = (lat_q, bud_q)
            Qsum[i] = qm + sum(lat_q) + sum(bud_q)
            if T.main[i] >= 0: cnt[i] += cnt[T.main[i]]
            for j in T.lat[i]:
                if not T.dead[j]: cnt[i] += cnt[j]
        # 4. Shedding of branches with too little light for their size.
        for i in range(N):
            if T.dead[i]: continue
            for j in T.lat[i]:
                if T.dead[j] or T.kind[j] == 1: continue
                if cnt[j] >= P['shed_min'] and Qsum[j] / cnt[j] < P['shed']:
                    # Its first internode stays as a stub; the rest falls.
                    stack = [T.main[j]] + list(T.lat[j]) if T.main[j] >= 0 else list(T.lat[j])
                    while stack:
                        k = stack.pop()
                        if k < 0 or T.dead[k]: continue
                        T.dead[k] = True
                        stack.extend([T.main[k]] + T.lat[k])
                    T.kind[j] = 1; T.main[j] = -1; T.lat[j] = []; T.buds[j] = []; T.term[j] = False
                    T.pos[j] = T.pos[i] + (T.pos[j] - T.pos[i]) * 0.5
        # 2b. Acropetal resource.
        v = np.zeros(N); v[root] = P['alpha'] * Qsum[root]
        grow_list = []      # (node, direction, v, kind 'term' or bud index)
        lam = P['lam']
        for i in range(N):
            if T.dead[i] or T.kind[i] == 1: continue
            qm = Qm_t[i]; lat_q, bud_q = Ql_b[i]
            ql = sum(lat_q) + sum(bud_q)
            den = lam * qm + (1 - lam) * ql
            if den <= 0: continue
            vm = v[i] * lam * qm / den; vl = v[i] * (1 - lam) * ql / den
            if T.main[i] >= 0: v[T.main[i]] = vm
            elif T.term[i]: grow_list.append((i, T.dir[i], vm, -1))
            k = 0
            for j in T.lat[i]:
                if not T.dead[j]:
                    v[j] = vl * Qsum[j] / ql if ql > 0 else 0.0
            # Stava et al.'s low-branch pruning (LB_PF): no side shoots under the crown's base.
            if T.pos[i][1] < P['crown_base']:
                continue
            for bi, q in enumerate(bud_q):
                if ql > 0: grow_list.append((i, T.buds[i][bi], vl * q / ql, bi))
        # 3. New shoots.
        flushed = {}
        for (i, d, vv, bi) in grow_list:
            n = min(int(vv), P['nmax'])
            if n < 1: continue
            L = P['l'] * min(vv / n, 2.0)
            par = i; d = np.array(d, float); p = T.pos[i].copy(); roll = T.roll[i]
            first = True
            for k in range(n):
                c = vox(p)
                # The least shaded neighbour, ahead of the shoot (perception cone ~ 90 deg).
                best = None; bs = 1e9
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        for dz in (-1, 0, 1):
                            if dx == dy == dz == 0: continue
                            o = np.array([dx, dy, dz], float)
                            if o @ d < 0.3 * np.linalg.norm(o): continue
                            cc = np.clip(c + [dx, dy, dz], 0, dims - 1)
                            # Ties go to the neighbour most ahead.
                            sc = s[tuple(cc)] - 1e-3 * (o @ d) / np.linalg.norm(o)
                            if sc < bs: bs = sc; best = o
                V = norm(best) if best is not None else d
                d = norm(d + P['eps'] * V + P['eta'] * UP + rng.normal(0, 0.03, 3))
                p = p + d * L
                roll += math.pi * 0.5
                j = T.add(par, p, d, roll)
                if first:
                    if bi < 0: T.main[i] = j; T.term[i] = False
                    else: T.lat[i].append(j); flushed.setdefault(i, []).append(bi)
                    first = False
                else:
                    T.main[par] = j
                # Two lateral buds, opposite, a quarter turn from the last pair.
                T.buds[j] = [turned(d, tan, roll), turned(d, tan, roll + math.pi)] if p[1] >= P['crown_base'] else []
                par = j
            T.term[par] = True
        for i, bis in flushed.items():
            T.buds[i] = [b for k, b in enumerate(T.buds[i]) if k not in set(bis)]
        # 5 and gravity: radii, then the year's bend.
        if bend:
            A = as_arr(T, P)
            keepmap = A.keepmap
            if acc is None or len(acc) < len(T.pos): acc = np.concatenate([acc if acc is not None else np.zeros(0), np.zeros(len(T.pos) - (0 if acc is None else len(acc)))])
            sub_acc = acc[keepmap]
            gravity.bend_cycle(A, gp, sub_acc)
            acc[keepmap] = sub_acc
            for k, node in enumerate(keepmap):
                T.pos[node] = A.pos[k]
                R = A.R[k]
                T.dir[node] = R @ T.dir[node] if k > 0 else T.dir[node]
                T.buds[node] = [R @ b for b in T.buds[node]]
    return T, as_arr(T, P)


def as_arr(T, P):
    keep = [i for i in range(len(T.pos)) if not T.dead[i]]
    newi = {o: k for k, o in enumerate(keep)}
    par = np.array([newi.get(T.par[i], -1) if T.par[i] >= 0 else -1 for i in keep])
    pos = np.array([T.pos[i] for i in keep])
    kind = np.array([T.kind[i] for i in keep])
    # A fake foot so node 0 has no wood: the root internode's start.
    pos = np.vstack([pos[0:1] - T.dir[keep[0]] * 0.0, pos])
    par = np.concatenate([[-1], par + 1]); par[1] = 0
    kind = np.concatenate([[0], kind])
    r = pipe_radii(par, P['n_exp'], P['tip_r'])
    r[kind == 1] = np.maximum(r[kind == 1], P['tip_r'] * 3)
    A = Arr(pos, par, r.copy(), r.copy(), kind)
    A.ra[0] = A.rb[0] = 0
    A.keepmap = np.array([keep[0]] + keep)
    return A


def tree(seed=7, P=None, bend=False, gp=None):
    P = dict(P0, **(P or {}))
    # The trunk: a straight run to the crown's base, as an old park tree's after its lower
    # limbs were shed; grown here as the first years' leader.
    T, A = grow(P, seed, bend=bend, gp=gp)
    s = P['trunk_r'] / max(A.ra[1], 1e-9)
    A.ra *= s; A.rb *= s
    return A


def fan(seed=7, P=None, bend=False, gp=None):
    """A twig fan grown on its own at fine detail: a level shoot, 9 years of 6 cm
    internodes, in open space (an envelope of 1.6 x 1.2 x 1.4 m ahead of it)."""
    P = dict(P0, **(P or {}))
    P.update(years=9, l=0.06, voxel=0.06, box=((-0.3, -1.3, -1.0), (2.0, 1.0, 1.0)), shed_min=4, tip_r=0.002, crown_base=-9.0)
    crown = Crown((0.8, -0.1, 0.0), (0.95, 0.7, 0.8))
    T, A = grow(P, seed, crown=crown, d0=np.array([1.0, 0.05, 0.0]) / 1.00125, bend=bend, gp=gp)
    s = 0.015 / max(A.ra[1], 1e-9)
    A.ra *= s; A.rb *= s
    return A
ITERATIVE = True
