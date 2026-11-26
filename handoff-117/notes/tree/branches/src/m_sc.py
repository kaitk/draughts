# Method a: space colonisation (Runions, Lane and Prusinkiewicz 2007, Modeling trees with a
# space colonization algorithm, Eurographics NPH). Attraction points fill the crown's
# envelope; each pulls the nearest tree node within the radius of influence di; a node so
# pulled grows one step D toward the mean of the unit vectors to its points (plus a
# tropism vector, as the paper allows); points within the kill distance dk of a node are
# removed. Radii by the pipe model r^n = sum r_child^n, n 2..3 in the paper. The paper
# gives di and dk in multiples of D and shows a range; the values here are within it.
# The envelope is the generator's (10 x 9.5 x 9 m), the points start at 3.5 m (the
# crown's base), the trunk grows straight until it is within di of a point.
import math, numpy as np
from graph import Graph, Arr, Crown, UP, norm, pipe_radii

P0 = dict(points=9000, D=0.30, di_k=12.0, dk_k=2.0, tropism=0.10, n_exp=2.3, tip_r=0.004,
          below=3.5, iters=220, trunk_r=0.5)


def run(crown, P, seed, start, d0, base_r_target=None):
    rng = np.random.default_rng(seed)
    pts = crown.sample(rng, P['points'], below=P.get('below', -1e9))
    D = P['D']; di = P['di_k'] * D; dk = P['dk_k'] * D
    trop = UP * P['tropism']
    pos = [np.array(start, float)]; par = [-1]
    alive = np.ones(len(pts), bool)
    best_d = np.full(len(pts), np.inf); best_i = np.full(len(pts), -1)
    # The trunk (or the shoot), straight until it feels a point.
    def feel(k):
        nonlocal best_d, best_i
        P_ = np.array(pos[k:])
        live = np.nonzero(alive)[0]
        if len(P_) == 0 or len(live) == 0: return
        Q = pts[live]
        for c in range(0, len(P_), 256):
            B = P_[c:c + 256]
            dd = ((Q[:, None, :] - B[None, :, :]) ** 2).sum(axis=2)
            j = dd.argmin(axis=1); m = np.sqrt(dd[np.arange(len(Q)), j])
            upd = m < best_d[live]
            best_d[live[upd]] = m[upd]; best_i[live[upd]] = j[upd] + k + c
    feel(0)
    while (best_d[alive] > di).all() and len(pos) < 400:
        pos.append(pos[-1] + d0 * D); par.append(len(pos) - 2); feel(len(pos) - 1)
    for it in range(P['iters']):
        alive &= best_d > dk
        act = alive & (best_d <= di)
        if not act.any():
            break
        k0 = len(pos)
        nodes = best_i[act]
        vec = pts[act] - np.array(pos)[nodes]
        vec /= np.linalg.norm(vec, axis=1, keepdims=True)
        acc = {}
        for n, v in zip(nodes, vec):
            acc.setdefault(int(n), np.zeros(3)); acc[int(n)] += v
        for n, v in acc.items():
            d = norm(norm(v) + trop + rng.normal(0, 0.02, 3))
            q = pos[n] + d * D
            pos.append(q); par.append(n)
        feel(k0)
    pos = np.array(pos); par = np.array(par)
    r = pipe_radii(par, P['n_exp'], P['tip_r'])
    if base_r_target:
        r *= base_r_target / r[1]
    ra = r.copy(); rb = r.copy()
    ra[0] = rb[0] = 0.0
    return Arr(pos, par, ra, rb, np.zeros(len(pos), int))


def tree(seed=7, P=None):
    P = dict(P0, **(P or {}))
    t = run(Crown(), P, seed, (0, 0, 0), UP)
    # The tips' radius set so the trunk is 50 cm, as the generator's.
    s = P['trunk_r'] / t.ra[1]
    t.ra *= s; t.rb *= s
    return t


def fan(seed=7, P=None):
    """A twig fan grown on its own at a fine step: a shoot leaving level into an envelope
    of 1.6 x 1.2 x 1.4 m ahead of it, its base 1.5 cm."""
    P = dict(P0, **(P or {}))
    P.update(points=2500, D=0.04, below=-1e9, iters=150)
    crown = Crown((0.9, -0.15, 0.0), (0.8, 0.6, 0.7))
    t = run(crown, P, seed, (0, 0, 0), np.array([1.0, 0.0, 0.0]))
    s = 0.015 / max(t.ra[1], 1e-9)
    t.ra *= s; t.rb *= s
    return t
