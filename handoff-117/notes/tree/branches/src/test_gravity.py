# The brief's checks on the gravity layer: a level limb sags, a heavier one more, a thicker
# one less, an upright one not sideways; printed as the tip's drop below level.
import math, numpy as np
from graph import Graph, Arr
from gravity import bend

def limb(r0, length=6.0, rise_deg=0.0, load=0.0, step=0.25):
    g = Graph(); prev = 0; n = int(length / step)
    d = np.array([math.cos(math.radians(rise_deg)), math.sin(math.radians(rise_deg)), 0.0])
    for k in range(n):
        ra = r0 * (1 - 0.8 * k / n); rb = r0 * (1 - 0.8 * (k + 1) / n)
        prev = g.add(prev, d * step * (k + 1), ra, rb)
        if load > 0:   # side twigs adding weight
            for s in (-1, 1):
                q = g.pos[prev] + np.array([0, 0, s * 0.6])
                g.add(prev, q, rb * load, rb * load * 0.5)
    return Arr.of(g)

def drop(t):
    tip = t.pos[np.argmax(t.pos[:, 0] + 0 * t.pos[:, 1])]
    main = [i for i in range(len(t.pos)) if abs(t.pos[i, 2]) < 1e-6]
    e = t.pos[main[-1]]
    return math.degrees(math.atan2(-e[1], math.hypot(e[0], e[2])))

for name, t in [('level r10cm', limb(0.10)), ('level r10cm +load', limb(0.10, load=0.6)),
                ('level r20cm', limb(0.20)), ('level r4cm 2m', limb(0.04, length=2.0)),
                ('level r1.5cm 1m', limb(0.015, length=1.0)), ('rising 45 r10', limb(0.10, rise_deg=45)),
                ('upright r10', limb(0.10, rise_deg=90))]:
    a = t.copy(); before = drop(a); bend(a)
    print(f'{name:22s} tip below level: {before:6.1f} -> {drop(a):6.1f} deg   x-shift {a.pos[-1,0]-t.pos[-1,0]:+.2f} m')
