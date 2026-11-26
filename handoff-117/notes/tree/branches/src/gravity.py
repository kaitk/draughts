# The gravity layer: branches bend under the wood they carry, after Stava et al. 2014
# (Inverse Procedural Modeling of Trees, CGF 33(6), Appendix A), with the growth's own
# correction upward (gravitropism, Almeras and Fournier 2009) as a residual sag. The same
# pass for every method; Palubicki's growth calls it once a cycle (bend_cycle), as Stava's
# model does, the others once on the grown tree (bend).
#
# Stava's terms, per node p0 with the wood's direction h (unit), g the gravity's (down):
#   fb     = GBS * m_c * |c - p0| * |h_H| * (1 - |h . g|)
#            m_c the supported mass, c its centre, h_H the level part of h
#   phimax = (pi / 2) / d(p0)^GBA          d the wood's thickness there
#   phi    = max(0, phimax * (1 - exp(-|fb| / phimax)) - phi_before)
# The PDF's text of the last line is garbled in extraction; this saturating form is the
# one that keeps phi within phimax and growing with fb, as the paper says it does. Two
# changes for the notes: d in centimetres, and phimax per half metre of wood (Stava's
# nodes are one year's internode), so methods with long and short segments bend alike.
# A vertical piece has h_H = 0 and |h . g| = 1, so it does not bend sideways.
import math, numpy as np

G = np.array([0.0, -1.0, 0.0])


def rot(axis, ang):
    """Rotation matrix about a unit axis (Rodrigues)."""
    x, y, z = axis
    c, s = math.cos(ang), math.sin(ang); C = 1 - c
    return np.array([[c + x * x * C, x * y * C - z * s, x * z * C + y * s],
                     [y * x * C + z * s, c + y * y * C, y * z * C - x * s],
                     [z * x * C - y * s, z * y * C + x * s, c + z * z * C]])


DEFAULT = dict(GBS=1.0, E=2e7, GBA=0.5, per=0.5, young_r=0.025, correct_young=0.85, correct_old=0.25, density=900.0)


def loads(t, density):
    """Supported mass (kg, wood of the given density) and its centre, per node, carried
    by the wood from the node's parent to it."""
    N = len(t.pos)
    i = np.arange(1, N)
    a = t.pos[t.parent[i]]; b = t.pos[i]
    L = np.linalg.norm(b - a, axis=1)
    r = 0.5 * (t.ra[i] + t.rb[i])
    m = np.zeros(N); mc = np.zeros((N, 3))
    m[i] = math.pi * r * r * L * density
    mc[i] = m[i, None] * 0.5 * (a + b)
    for k in range(N - 1, 0, -1):
        p = t.parent[k]
        if p > 0:
            m[p] += m[k]; mc[p] += mc[k]
    c = mc / np.maximum(m, 1e-12)[:, None]
    return m, c


def bend(t, P=None, phi_before=None):
    """t bent in place by its own weight. Returns the bend per node (radians)."""
    P = dict(DEFAULT, **(P or {}))
    N = len(t.pos)
    m, c = loads(t, P['density'])
    v = t.pos - t.pos[np.maximum(t.parent, 0)]       # each piece as grown
    new = t.pos.copy()
    R = [None] * N
    R[0] = np.eye(3)
    phis = np.zeros(N)
    yr = P['young_r']
    for i in range(1, N):
        p = t.parent[i]
        Rp = R[p]
        L = float(np.linalg.norm(v[i]))
        if L < 1e-9 or t.kind[i] == 2:
            R[i] = Rp; new[i] = new[p] + Rp @ v[i]; continue
        h0 = v[i] / L
        h = Rp @ h0
        # Stava's bend at the piece's foot.
        hH = math.hypot(h[0], h[2])
        lever = float(np.linalg.norm(c[i] - t.pos[p]))
        fb = P['GBS'] * m[i] * 9.81 * lever * hH * (1.0 - abs(h @ G))
        d = max(2000.0 * t.ra[i], 0.1)     # mm
        phimax = (math.pi / 2) / d ** P['GBA'] * (L / P['per'])
        # The response: a beam's, kappa = M / (E I) over the piece's length (the brief's
        # small-strain form), saturating at Stava's phimax.
        r4 = max(t.ra[i], 1e-4) ** 4
        beam = fb * L / (P['E'] * math.pi * r4 / 4.0)
        phi = phimax * (1.0 - math.exp(-beam / phimax)) if phimax > 0 else 0.0
        if phi_before is not None:
            phi = max(0.0, phi - phi_before[i])
        if phi > 1e-6 and hH > 1e-6:
            ax = np.cross(h, G); ax /= np.linalg.norm(ax)
            # Not past straight down.
            phi = min(phi, math.acos(float(np.clip(h @ G, -1, 1))))
            Rb = rot(ax, phi)
            Rp = Rb @ Rp
        # The growth's correction (Almeras and Fournier 2009), of the piece's whole drop,
        # its parent's carried and its own: young wood grows back most of the way toward
        # the way it was growing, old wood only partly (reaction wood). What is left is the
        # residual sag the brief asks for.
        h = Rp @ h0
        young = min(max(1.0 - t.ra[i] / yr, 0.0), 1.0)
        k = P['correct_old'] + (P['correct_young'] - P['correct_old']) * young
        cosang = float(np.clip(h @ h0, -1, 1))
        if k > 0 and cosang < 0.99999 and h0[1] > h[1]:
            ax = np.cross(h, h0); ax /= np.linalg.norm(ax)
            Rp = rot(ax, math.acos(cosang) * k) @ Rp
        phis[i] = phi
        R[i] = Rp
        new[i] = new[p] + Rp @ v[i]
    t.pos = new
    t.R = R
    return phis


def bend_cycle(t, P, acc):
    """One growth cycle's bend for an iterative grower: the bend so far per node is acc
    (grown with the tree), the new bend only what phimax still allows. Young wood's
    correction is left to the grower's own tropism, so it is off here."""
    Q = dict(P or {}); Q['correct_young'] = 0.0; Q['correct_old'] = 0.0
    phis = bend(t, Q, phi_before=acc)
    acc += phis
    return acc
