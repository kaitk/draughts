# Method c: our Weber-Penn generator as it is today (src/model3d/tree_whole.goose,
# grow_whole and grow_part with MAPLE_HABIT and rooms.goose's old-leader Whole), ported
# to Python in metres, no culling, with broken leaders added: in wood of 5-35 cm across,
# the axis ends as a stub and the side shoot takes over, turned 30-50 degrees, 1-3 elbows a
# limb.
#
# Weber and Penn 1995's terms, as Blender's Sapling and friggog/tree-gen name them, and
# ours: nBranches = children, downAngle = angle, length ratio = ratio, curveV = crook,
# attractUp = rise; ours adds share (the child's cross-section), wave, sag, paired.
# Their parameter tables (quaking aspen, black tupelo, weeping willow, ...) are hand-tuned
# by the authors for the look; no maple. tree-gen's acer preset is its author's, not the
# paper's. Ours were tuned by eye in task 107.
import math, random, numpy as np
from graph import Graph, Arr, Crown, UP, norm, turned, mixed

M = 30.48
HABIT = dict(
    segments=[10, 12, 9, 6, 3],
    children=[12, 12, 10, 8, 0],
    start=[0.0, 0.12, 0.1, 0.1, 0.0],
    angle=[45.0, 48.0, 52.0, 50.0, 0.0],
    ratio=[1.0, 0.7, 0.5, 0.42, 0.0],
    share=[0.22, 0.2, 0.16, 0.2, 0.0],
    crook=[0.02, 0.06, 0.12, 0.16, 0.14],
    wave=[0.0, 0.08, 0.14, 0.16, 0.08],
    rise=[0.0, 0.22, 0.2, 0.14, 0.08],
    sag=[0.0, 0.16, 0.2, 0.14, 0.04],
    paired=[False, False, True, True, True],
)
WHOLE = dict(height=22.0, girth=0.5, fork=3.0, leader=0.65, limbs=(62.0, 28.0), sag=False,
             elbows=(1, 3), elbow_r=(0.025, 0.175), elbow_turn=(30.0, 50.0), breaks=True)


class Rng:
    def __init__(self, seed): self.r = random.Random(seed)
    def roll(self): return self.r.random()
    def between(self, a, b): return a + (b - a) * self.r.random()
    def ball(self):
        while True:
            v = np.array([self.between(-1, 1) for _ in range(3)])
            if v @ v <= 1: return v


def flare(w, p):
    up = max(p[1], 0.0) / w['girth']
    return 1.0 + 0.3 * math.exp(-up * 1.1)


def grow_part(g, w, crown, node, at, dir, length, radius, level, dice, h):
    d = Rng(dice)
    segments = h['segments'][level]
    step = length / segments
    pts = [at.copy()]; dirs = [dir.copy()]; rad = [radius * (flare(w, at) if level == 0 else 1.0)]
    nodes = [node]
    tip = 0.6 if level == 0 else 0.5 if level == 4 else 0.22
    slender = min(max(length / (radius * 70.0), 0.4), 2.0)
    sag = h['sag'][level] * slender if w['sag'] else 0.0
    rise = h['rise'][level]; rise_from = 0.4
    phase = d.roll() * 2 * math.pi; wave_turn = d.roll() * 2 * math.pi
    # The broken leaders on this axis: at which segments, if its wood is 5-35 cm across.
    elbows = set()
    if w['breaks'] and level in (1, 2) and w['elbow_r'][0] < radius < w['elbow_r'][1] * 2:
        k = int(round(d.between(w['elbows'][0] - 0.49, w['elbows'][1] + 0.49))) if level == 1 else (1 if d.roll() < 0.5 else 0)
        for _ in range(k):
            elbows.add(int(d.between(2, segments - 2)))
    p = at.copy(); n = 0; r_scale = 1.0
    for i in range(segments):
        f = (i + 0.5) / segments
        level_out = 1.0 - abs(dir[1])
        side = turned(dir, math.pi * 0.5, wave_turn)
        bend = UP * (rise * min(max((f - rise_from) / (1 - rise_from), 0.0), 1.0) - sag * f * (0.3 + level_out)) \
            + side * (h['wave'][level] * math.sin(phase + i * 1.9)) + d.ball() * h['crook'][level]
        dir = norm(dir + bend)
        rb0 = radius * (1.0 + (tip - 1.0) * (i + 1) / segments) * r_scale
        if i in elbows and rb0 > w['elbow_r'][0]:
            # The leader broke here: its end a stub going on straight, the side shoot taking
            # over thinner, turned 30-50 degrees up or aside.
            q = p + dir * step * d.between(0.3, 0.7)
            g.add(nodes[-1], q, rad[-1], rad[-1] * 0.8, kind=1)
            t = math.radians(d.between(*w['elbow_turn']))
            dir = norm(turned(dir, t, d.roll() * 2 * math.pi) + UP * 0.15)
            r_scale *= 0.78
            rb0 *= 0.78
        q = p + dir * step
        if level > 0 and crown.radius(q) > 1.06:
            break
        rb = rb0 * (flare(w, q) if level == 0 else 1.0)
        nodes.append(g.add(nodes[-1], q, rad[-1] if not (i in elbows) else rad[-1] * 0.78, rb))
        p = q; pts.append(p.copy()); dirs.append(dir.copy()); rad.append(rb); n = i + 1
    if n == 0 or level == 4:
        return
    count = h['children'][level]; start = h['start'][level]; paired = h['paired'][level]
    first_round = d.roll() * 2 * math.pi
    slots = (count + 1) // 2 if paired else count
    fork_share = min(max(w['fork'] / length, 0.0), 0.95)
    for c in range(count):
        slot = c // 2 if paired else c
        f = start + (1 - start) * (slot + d.between(0.15, 0.85)) / slots
        if level == 0:
            f = fork_share + (1 - fork_share) * (slot + d.between(0.3, 1.0)) / slots
        a = f * n; i = min(int(math.floor(a)), n - 1); k = a - i
        foot = pts[i] + (pts[i + 1] - pts[i]) * k
        along = dirs[i + 1]
        r_there = rad[i] + (rad[i + 1] - rad[i]) * k
        leader = level == 0 and c == count - 1
        high = (f - fork_share) / max(1 - fork_share, 0.05)
        if leader: spread = d.between(6, 14)
        elif level == 0: spread = w['limbs'][0] + (w['limbs'][1] - w['limbs'][0]) * high + d.between(-10, 10)
        else: spread = h['angle'][level] + d.between(-14, 14)
        turn = slot * (math.pi * 0.5) + (c % 2) * math.pi if paired else c * 2.39996
        rnd = first_round + turn + d.between(-0.35, 0.35)
        cdir = turned(along, math.radians(spread), rnd)
        if level >= 2:
            cdir = norm(cdir + crown.out(foot) * 0.35 + UP * 0.15)
        shape = 1.0 if level == 0 else 1.0 - 0.45 * f
        want = length * h['ratio'][level] * shape * d.between(0.8, 1.15)
        if level == 0: want = w['height'] * 1.2
        room = crown.ahead(foot, cdir, want)
        if level <= 1: L = room * d.between(0.88, 0.98)
        elif level == 2: L = min(want, room * d.between(0.8, 0.97))
        else: L = min(want, room * d.between(0.8, 1.0) + want * 0.15)
        rad_c = max(r_there * math.sqrt(h['share'][level] * d.between(0.75, 1.25)), (0.06 if level >= 3 else 0.12) / M)
        dice_c = mixed(dice ^ (((c + 1) * 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF))
        if not (L > 1.0 / M and (level == 0 or crown.radius(foot) <= 1.06)):
            continue
        if level == 3 and crown.depth(foot) > 2.6 * 1.4 and d.roll() < 0.8:
            continue
        # Hang the child on the nearest node of this axis (the port keeps the graph a tree).
        parent_node = nodes[i]
        cn = g.add(parent_node, foot, 0.0, 0.0, kind=2)   # a joint along the axis, not drawn
        grow_part(g, w, crown, cn, foot, cdir, L, rad_c, level + 1, dice_c, h)


def tree(seed=7, P=None):
    w = dict(WHOLE, **(P or {}))
    crown = Crown()
    d = Rng(mixed(seed + 11))
    lean = norm(np.array([d.between(-0.04, 0.04), 1.0, d.between(-0.04, 0.04)]))
    g = Graph()
    grow_part(g, w, crown, 0, np.zeros(3), lean, max(w['leader'] * w['height'], w['fork'] * 1.3), w['girth'], 0, mixed(seed * 31 + 5), HABIT)
    return Arr.of(g)
