// The tree grown whole at its real size (task 107's T1), for the picture as well as the
// shadow: an old Norway maple, its crown filling an envelope, its leaves on the twigs'
// nodes in opposite pairs on stalks, each twig tinted on its own, culled to the parts seen
// through the library's windows or casting through them. Part of trees, in its namespace:
// the same frame, dice, segments and map leaves as trees.goose, so trees::draw_map bakes
// its shadow as it bakes the first tree's.
namespace trees;
import std;
import vec;
import math;

let MAX_WHOLE_SEGMENTS = 80000;
let MAX_LIMBS = 30000;
let MAX_CARDS = 160000;
// The leaf atlas's leaves (leaf_atlas::LEAVES).
let LEAF_KINDS = 8;

// A branch as a chain of segments, segments[first .. first + count], for its tube (T2);
// its parent's index in limbs, -1 for the trunk, and the segment its foot sits on (the
// parent's, or the joint's before a broken leader's stub), -1 for the trunk. A broken
// leader's stub is a limb of its parent's level.
struct Limb { first: i32, count: i32, level: i32, parent: i32, attach: i32 }

// A leaf as the picture draws it: where its stalk leaves the twig, where the blade starts,
// the blade's axis from there to its middle lobe's tip and its face (the side the sun is
// on); the blade's length and width, which of the atlas's leaves it is, and its tint
// (0 green, 1 gold, 2 orange-red); the twig's segment it grows on.
struct Card { foot: float3, base: float3, along: float3, face: float3, size: f32, width: f32, kind: i32, tint: f32, segment: i32 }

// How a tree grows, per level (the trunk, limbs, branches, branchlets, twigs): the
// segments a branch, its children, where along it they start, their angle off it
// (degrees), their length against its, their cross-section's share of its, how crooked
// at random and how wavy, how much its end turns up to the light and how much a slender
// branch sags under its load, and whether its children come in opposite pairs.
struct Habit {
    segments: i64[5],
    children: i64[5],
    start:    f32[5],
    angle:    f32[5],
    ratio:    f32[5],
    share:    f32[5],
    crook:    f32[5],
    wave:     f32[5],
    rise:     f32[5],
    sag:      f32[5],
    paired:   bool[5],
}

// A Norway maple grown in the open: the limbs leave the trunk in a spiral, its branches
// arc (sag, then turn up), wavy and slender toward their ends; opposite twigs; the leaves
// in a shell under the crown's outside.
let MAPLE_HABIT = Habit {
    segments: [10, 12, 9, 6, 3],
    children: [12, 12, 10, 8, 0],
    start:    [0.0, 0.12, 0.1, 0.1, 0.0],
    angle:    [45.0, 48.0, 52.0, 50.0, 0.0],
    ratio:    [1.0, 0.7, 0.5, 0.42, 0.0],
    share:    [0.22, 0.2, 0.16, 0.2, 0.0],
    crook:    [0.02, 0.06, 0.12, 0.16, 0.14],
    wave:     [0.0, 0.08, 0.14, 0.16, 0.08],
    rise:     [0.0, 0.22, 0.2, 0.14, 0.08],
    sag:      [0.0, 0.16, 0.2, 0.14, 0.04],
    paired:   [false, false, true, true, true],
};

// What grow_whole does past the habit (task 117), each part off as made, for the light
// tuner and tools/tree_dump until checked: broken leaders a hero limb (elbows x the fewest,
// y the most, z and w the side shoot's turn in degrees; a branch has one at even odds when
// y > 0); the gravity layer in place of Habit.sag (gravity its strength, 1 the study's; 0
// Habit.sag); the shedding of shaded thin wood (shed x the light under which it dies, 0
// none; y the share of the shed branches left as stubs).
struct Growth {
    elbows:  float4 = float4 { 0.0, 0.0, 30.0, 50.0 },
    gravity: f32    = 0.0,
    shed:    float2 = float2 { 0.0, 0.5 },
}

// Whether the grown skeleton is reshaped after growth (gravity, shedding): then the tree is
// grown whole, reshaped, and culled after (keep_parts), not as it grows.
fn reshaped(g: Growth) -> bool { g.gravity > 0.0 || g.shed.x > 0.0 }

// The tree whole (grow_whole), in the tree's frame and world units.
struct Whole {
    seed:   f32,
    foot:   float3,     // the trunk's foot
    height: f32,        // the crown's top over the foot
    girth:  f32,        // the trunk's radius a metre and a half up
    fork:   f32,        // where the lowest limbs leave the trunk, over the foot
    leader: f32,        // how far up the trunk goes on, a share of the height
    limbs:  float2,     // the limbs' angles off the trunk, low to high (degrees)
    // The crown's envelope, two half ellipsoids about `middle` (from the foot): x its
    // half width along the wall, y its half height, z its half depth away from the house,
    // w toward it.
    crown:  float4,
    middle: float3,
    house:  f32,        // the house's outer face, a depth; nothing grows nearer than WALL_GAP
    leaf:   f32,        // a blade's length, the middle lobe's
    leafy:  f32,        // 1 as grown, less fewer leaves (autumn's fall), 0 bare
    autumn: f32,        // the crown's tint, 0 green .. 2 orange-red
    shell:  f32,        // how deep under the crown's outside the leaves grow
    // A low limb sweeping down and out toward the house, across the windows' view (as
    // library-home-01's): its foot over the trunk's, its way out (the tree's frame) and
    // length; 0 long, none.
    hang_at:    f32,
    hang_dir:   float3,
    hang:       f32,
    hang_thick: f32,    // its radius against the trunk's
    hang_sag:   f32,    // how much it sags (a main limb's 0.16)
    habit:      Habit,
    growth:     Growth = Growth { .. },
}

// Where the tree may be seen from: eyes in the room and the openings they look through,
// rectangles x0, x1, y0, y1 at depth `plane`, all in the tree's frame.
struct Sight {
    eyes:    float3[..48] = [],
    windows: float4[..4]  = [],
    plane:   f32          = 0.0,
}

// Whether a ball at c of radius r is seen from an eye through an opening.
fn seen(s: Sight&, c: float3, r: f32) -> bool {
    for &e in s.eyes {
        guard c.z > s.plane && e.z < s.plane else { continue; }
        let k = (s.plane - e.z) / (c.z - e.z);
        let x = e.x + (c.x - e.x) * k;
        let y = e.y + (c.y - e.y) * k;
        let m = r * k + 1.0;
        for &o in s.windows {
            if x > o.x - m && x < o.y + m && y > o.z - m && y < o.w + m { return true; }
        }
    }
    return false;
}

// Whether a ball at c of radius r casts on the map.
fn casts(v: View&, c: float3, r: f32) -> bool { on_holes(v, on_map(v, c), r * spread(v)) }

// How far out inside the envelope a point is: 0 at its middle, 1 on its outside.
fn crown_radius(w: Whole&, p: float3) -> f32 {
    let c = w.foot + w.middle;
    let dz = if p.z > c.z { w.crown.z } else { w.crown.w };
    let x = (p.x - c.x) / w.crown.x;
    let y = (p.y - c.y) / w.crown.y;
    let z = (p.z - c.z) / dz;
    return sqrt(x * x + y * y + z * z);
}

fn inside_crown(w: Whole&, p: float3, slack: f32) -> bool {
    return crown_radius(w, p) <= slack && p.z > w.house + WALL_GAP;
}

// How far from p along dir the envelope's outside is (p inside it), to a few millimetres.
fn crown_ahead(w: Whole&, p: float3, dir: float3, most: f32) -> f32 {
    guard !inside_crown(w, p + dir * most, 1.0) else { return most; }
    var lo: f32 = 0.0;
    var hi = most;
    for i in 16 {
        let mid = (lo + hi) * 0.5;
        if inside_crown(w, p + dir * mid, 1.0) { lo = mid; } else { hi = mid; }
    }
    return lo;
}

// How deep under the crown's outside a point is, world units.
fn crown_depth(w: Whole&, p: float3) -> f32 {
    return max(1.0 - crown_radius(w, p), 0.0) * min(w.crown.x, w.crown.y);
}

// A branch to grow; `free` a hanging limb's and its offspring's, which may leave the
// crown's envelope below; `attach` the segment its foot sits on (Limb.attach).
struct Part { at: float3, dir: float3, length: f32, radius: f32, level: i64, dice: u64, tint: f32, parent: i32, free: bool, attach: i32 }

// How far out of the envelope a hanging limb's parts may grow.
let HANG_SLACK: f32 = 1.8;

// How much farther than its own length a branch's offspring may reach.
let WHOLE_REACH: f32 = 1.4;

// The leaf pairs on a twig.
let TWIG_NODES = 4;

// The wood a leader breaks in (Growth.elbows): its radius in metres, 5 to 35 cm across.
let ELBOW_RADII = float2 { 0.025, 0.175 };

// The tree grown whole from w, all of it, or with `cull` only the parts seen through
// `sight` or casting on v's map. Each branch has dice of its own, so culling leaves the
// kept parts as they are. Fills t.segments, t.limbs and t.cards, and t.leaves with the
// cards that cast, for draw_map.
// With the skeleton reshaped (Growth: gravity, shedding), it is grown whole, shed, bent and
// then culled (keep_parts, tree_skeleton.goose), so a branch bent into view is kept.
fn grow_whole(t: Tree&, w: Whole, v: View, sight: Sight, cull: bool) {
    t.segments.clear();
    t.leaves.clear();
    t.limbs.clear();
    t.cards.clear();
    t.left_out = 0;
    var wh = w;
    var vw = v;
    var sg = sight;
    let after = reshaped(w.growth);
    let cull_growing = cull && !after;
    var d = Dice { mixed(w.seed as u64 + 11) };
    let lean = float3 { roll_between(d, -0.04, 0.04), 1.0, roll_between(d, -0.04, 0.04) };
    let trunk = Part { w.foot, normalize(lean), max(w.leader * w.height, w.fork * 1.3), w.girth, 0, d.state, w.autumn, -1, false, -1 };
    grow_part(t, wh, vw, sg, cull_growing, trunk);
    // The hanging limb, on dice of its own, from the trunk's side.
    if w.hang > 0.0 {
        var hd = Dice { mixed(w.seed as u64 + 977) };
        let dir = normalize(w.hang_dir);
        let at = w.foot + float3 { 0.0, w.hang_at, 0.0 } + float3 { dir.x, 0.0, dir.z } * (w.girth * 0.8);
        let limb = Part { at, dir, w.hang, w.girth * w.hang_thick, 1, hd.state, w.autumn + 0.15, 0, true, trunk_segment_at(t, at.y) };
        if !cull_growing || casts(vw, at, w.hang * WHOLE_REACH) || seen(sg, at, w.hang * WHOLE_REACH) {
            grow_part(t, wh, vw, sg, cull_growing, limb);
        }
    }
    guard after else { return; }
    if w.growth.shed.x > 0.0 { shed_shaded(t, wh); }
    if w.growth.gravity > 0.0 { bend_by_weight(t, w.growth.gravity); }
    keep_parts(t, wh, vw, sg, cull);
}

// The trunk's segment at height y, for the hanging limb's foot.
fn trunk_segment_at(t: Tree&, y: f32) -> i32 {
    guard t.limbs.len > 0 else { return -1; }
    let l = t.limbs[0];
    for i in l.count as i64 {
        let s = l.first + i;
        if t.segments[s].b.y >= y { return s as i32; }
    }
    return l.first + l.count - 1;
}

// A broken leader's stub where the axis went on: a run on the old way, then a short end
// closing it.
let STUB_PARTS = 2;
let MOST_ELBOWS = 3;

// The trunk's flare at its foot: wider over its lowest metre or so.
fn flare(w: Whole&, p: float3) -> f32 {
    let up = max(p.y - w.foot.y, 0.0) / w.girth;
    return 1.0 + 0.3 * exp(-up * 1.1);
}

recursive fn grow_part(t: Tree&, w: Whole&, v: View&, sight: Sight&, cull: bool, b: Part) {
    var d = Dice { b.dice };
    let h = w.habit;
    let level = b.level;
    let segments = h.segments[level];
    let step = b.length / segments;
    let up = float3 { 0.0, 1.0, 0.0 };
    var points: float3[13] = [float3_0; 13];
    var dirs:   float3[13] = [float3 { 0.0, 1.0, 0.0 }; 13];
    var radii:  f32[13]    = [0.0; 13];
    var p = b.at;
    var dir = b.dir;
    points[0] = p;
    dirs[0] = dir;
    // The radius along it: tapering by the share its children take, a trunk flaring;
    // the branches slender toward their ends.
    let tip: f32 = if level == 0 { 0.6 } else if level == 4 { 0.5 } else { 0.22 };
    radii[0] = b.radius * (if level == 0 { flare(w, p) } else { 1.0 });
    // How it bends: a slender branch (long against its thickness) sags more under its
    // load, more toward its end, and its end turns up to the light; a hanging limb sags
    // far, then turns up late. A slow wave across it, its phase its own.
    let hanging = b.free && level == 1;
    let slender = clamp(b.length / (b.radius * 70.0), 0.4, 2.0);
    // With the gravity layer on (bend_by_weight), it bends the grown wood instead of sag.
    let sag = if hanging { w.hang_sag } else if w.growth.gravity > 0.0 { 0.0 } else { h.sag[level] * slender };
    let rise = if hanging { 0.32 } else { h.rise[level] };
    let rise_from: f32 = if hanging { 0.6 } else { 0.4 };
    let phase = roll(d) * TAU;
    let wave_turn = roll(d) * TAU;
    let slack = if b.free { HANG_SLACK } else { 1.06 };
    let first = t.segments.len;
    // Broken leaders (Growth.elbows) on a limb or branch, at segments 2 .. segments - 2, on
    // dice of their own so the rest of the branch rolls as without them.
    var elbow_at: u64 = 0;
    var ed = Dice { mixed(b.dice ^ 0xB40CE7E1B0) };
    let elbows = w.growth.elbows;
    if elbows.y > 0.0 && (level == 1 || level == 2) && !hanging {
        let want = if level == 1 { floor(roll_between(ed, elbows.x, elbows.y + 0.999)) as i64 }
                   else if roll(ed) < 0.5 { 1 } else { 0 };
        for k in min(want, MOST_ELBOWS) * 4 {
            guard popcount(elbow_at) < min(want, MOST_ELBOWS) else { break; }
            let at = 2 + min((roll(ed) * (segments - 4)) as i64, segments - 5);
            elbow_at |= (1 as u64) << at;
        }
    }
    var stubs:       Segment[..6] = [];
    var stub_attach: i32[..3]     = [];
    var thinner:     f32          = 1.0;
    var n = 0;
    for i in segments {
        let f = (i + 0.5) / segments;
        let level_out = 1.0 - abs(dir.y);
        let side = turned(dir, PI * 0.5, wave_turn);
        let bend = up * (rise * clamp((f - rise_from) / (1.0 - rise_from), 0.0, 1.0) - sag * f * (0.3 + level_out))
                   + side * (h.wave[level] * sin(phase + i * 1.9)) + roll_ball(d) * h.crook[level];
        dir = normalize(dir + bend);
        // A broken leader in wood of 5-35 cm: the axis ends here as a stub going on its way,
        // and the side shoot takes over, thinner, turned 30-50 degrees.
        let r_here = radii[i];
        if ((elbow_at >> i) & 1) == 1 && r_here > ELBOW_RADII.x * surfaces::METRE && r_here < ELBOW_RADII.y * surfaces::METRE {
            let run = p + dir * (step * roll_between(ed, 0.3, 0.7));
            let end = run + dir * (r_here * 0.6);
            stubs.push(Segment { p, run, r_here, r_here * 0.8, level as i32 });
            stubs.push(Segment { run, end, r_here * 0.8, r_here * 0.3, level as i32 });
            stub_attach.push((first + i - 1) as i32);
            dir = normalize(turned(dir, radians(roll_between(ed, elbows.z, elbows.w)), roll(ed) * TAU) + up * 0.15);
            thinner *= 0.78;
        }
        let q = p + dir * step;
        // Stopped at the crown's outside and at the house.
        guard level == 0 || inside_crown(w, q, slack) else { break; }
        guard q.z > w.house + WALL_GAP else { break; }
        var rb = b.radius * (1.0 + (tip - 1.0) * (i + 1) / segments) * thinner;
        if level == 0 { rb *= flare(w, q); }
        if t.segments.len < MAX_WHOLE_SEGMENTS {
            t.segments.push(Segment { p, q, radii[i], rb, level as i32 });
        } else {
            t.left_out++;
        }
        p = q;
        points[i + 1] = p;
        dirs[i + 1] = dir;
        radii[i + 1] = rb;
        n = i + 1;
    }
    guard n > 0 else { return; }
    let me = t.limbs.len as i32;
    if t.limbs.len < MAX_LIMBS {
        t.limbs.push(Limb { first as i32, (t.segments.len - first) as i32, level as i32, b.parent, b.attach });
    }
    // The stubs, each a limb of this one's level, where the axis reached them.
    for a, k in stub_attach {
        guard a < (first + n) as i32 && t.segments.len + STUB_PARTS <= MAX_WHOLE_SEGMENTS && t.limbs.len < MAX_LIMBS else { continue; }
        t.limbs.push(Limb { t.segments.len as i32, STUB_PARTS, level as i32, me, a });
        for j in STUB_PARTS { t.segments.push(stubs[k * STUB_PARTS + j]); }
    }
    if level == 4 {
        var leaf_dice = Dice { mixed(b.dice ^ 0x5DEECE66D) };
        add_cards(t, w, v, sight, cull, leaf_dice, points, dirs, n, b.tint, b.free, first);
        return;
    }
    let count = h.children[level];
    let start = h.start[level];
    let paired = h.paired[level];
    let first_round = roll(d) * TAU;
    let slots = if paired { (count + 1) / 2 } else { count };
    // The trunk's limbs from the fork to its top, in a spiral; if it stops short of the
    // crown's top (a fork), its last limb leads on.
    let fork_share = clamp(w.fork / b.length, 0.0, 0.95);
    let forks = level == 0 && w.leader * w.height < w.fork * 1.3 + 30.0;
    for c in count {
        let slot = if paired { c / 2 } else { c };
        var f = start + (1.0 - start) * (slot + roll_between(d, 0.15, 0.85)) / slots;
        if level == 0 { f = fork_share + (1.0 - fork_share) * (slot + roll_between(d, 0.3, 1.0)) / slots; }
        let at = f * n;
        let i = min(floor(at) as i64, n - 1);
        let k = at - i;
        let foot = points[i] + (points[i + 1] - points[i]) * k;
        let along = dirs[i + 1];
        let radius_there = radii[i] + (radii[i + 1] - radii[i]) * k;
        let leader = level == 0 && c == count - 1;
        // The limbs wide low on the trunk, steeper up it, each its own way.
        let high = (f - fork_share) / max(1.0 - fork_share, 0.05);
        let spread_deg = if leader { roll_between(d, 6.0, 14.0) }
                         else if level == 0 { w.limbs.x + (w.limbs.y - w.limbs.x) * high + roll_between(d, -10.0, 10.0) }
                         else { h.angle[level] + roll_between(d, -14.0, 14.0) };
        let tilt = radians(spread_deg);
        let turn = if paired { slot * (PI * 0.5) + (c % 2) * PI } else { c * 2.39996 };
        let round = first_round + turn + roll_between(d, -0.35, 0.35);
        var cdir = turned(along, tilt, round);
        // Twigs and branchlets lean out of the crown, toward the light.
        if level >= 2 {
            let out = normalize(foot - (w.foot + w.middle));
            cdir = normalize(cdir + out * 0.35 + up * 0.15);
        }
        let shape: f32 = if level == 0 { 1.0 } else { 1.0 - 0.45 * f };
        var want = b.length * h.ratio[level] * shape * roll_between(d, 0.8, 1.15);
        if level == 0 { want = w.height * 1.2; }
        let room = if b.free { want } else { crown_ahead(w, foot, cdir, want) };
        let length = if level <= 1 && !b.free { room * roll_between(d, 0.88, 0.98) }
                     else if level == 2 { min(want, room * roll_between(d, 0.8, 0.97)) }
                     else { min(want, room * roll_between(d, 0.8, 1.0) + want * 0.15) };
        let thick = if leader && forks { 1.6 } else { 1.0 };
        let radius = max(radius_there * sqrt(h.share[level] * roll_between(d, 0.75, 1.25)) * thick, if level >= 3 { 0.06 } else { 0.12 });
        let dice = mixed(b.dice ^ ((c + 1) as u64 * 0x9E3779B97F4A7C15));
        // Branches turn colour together: each its own shift from its parent's.
        var tint = b.tint;
        if level == 1 { tint += roll_between(d, -0.4, 0.4); }
        if level == 2 { tint += roll_between(d, -0.25, 0.25); }
        let held = inside_crown(w, foot, if b.free { HANG_SLACK } else { 1.06 }) || level == 0;
        guard length > 1.0 && held else { continue; }
        // The core's twigs die back: the leaves stay in the shell.
        if level == 3 && !b.free && crown_depth(w, foot) > w.shell * 1.4 && roll(d) < 0.8 { continue; }
        let child = Part { foot, cdir, length, radius, level + 1, dice, tint, me, b.free, (first + i) as i32 };
        guard !cull || casts(v, foot, length * WHOLE_REACH + w.leaf * 3.0)
                    || seen(sight, foot, length * WHOLE_REACH + w.leaf * 3.0) else { continue; }
        grow_part(t, w, v, sight, cull, child);
    }
}

// A twig's leaves: a pair at each node, each pair a quarter turn from the last, and the
// tip's pair, sometimes three; on stalks about as long as the blade, the blades turned
// out of the crown and up, as a maple's mosaic. None deep in the crown.
fn add_cards(t: Tree&, w: Whole&, v: View&, sight: Sight&, cull: bool, d: Dice&, points: float3[13]&, dirs: float3[13]&,
             n: i64, tint: f32, free: bool, first: i64) {
    let up = float3 { 0.0, 1.0, 0.0 };
    let sun = normalize(float3 { v.shear.x, v.shear.y, 1.0 });
    let middle = w.foot + w.middle;
    let first = roll(d) * TAU;
    let height_share = clamp((points[n].y - w.foot.y) / w.height, 0.0, 1.0);
    // The twig's own tint: the crown's outside and top turn first.
    let outer = clamp(crown_radius(w, points[n]), 0.0, 1.1);
    let twig_tint = clamp(tint + 1.6 * (outer - 0.85) + 0.6 * (height_share - 0.5) + roll_between(d, -0.12, 0.12), 0.0, 2.0);
    // The nodes evenly along the twig's outer four fifths, the last at its tip: each a
    // short shoot's pair of leaves, as on an old tree most leaves are.
    let nodes = TWIG_NODES;
    for node in 1..nodes + 1 {
        let at = (0.2 + 0.8 * node / nodes) * n;
        let i = min(floor(at) as i64, n - 1);
        let p = points[i] + (points[i + 1] - points[i]) * (at - i);
        guard free || crown_depth(w, p) < w.shell else { continue; }
        guard w.leafy >= 1.0 || roll(d) < w.leafy else { continue; }
        let twig = normalize(dirs[i + 1]);
        let pair = if node == nodes && roll(d) < 0.3 { 3 } else { 2 };
        let round0 = first + node * (PI * 0.5);
        let deep = if free { 0.3 } else { clamp(crown_depth(w, p) / max(w.shell, 1.0), 0.0, 1.0) };
        let out = normalize(p - middle);
        for k in pair {
            let round = round0 + k * TAU / pair + roll_between(d, -0.25, 0.25);
            // The stalk out from the twig, rising a little, the last pair along the tip.
            let lift = roll_between(d, 0.15, 0.7);
            let side = turned(twig, PI * 0.5, round);
            let toward_tip: f32 = if node == nodes { 0.9 } else { 0.3 };
            let stalk_dir = normalize(side + twig * toward_tip + up * lift);
            // The shade's leaves larger.
            let size = w.leaf * roll_between(d, 0.75, 1.2) * (1.0 + 0.25 * deep);
            let stalk = size * roll_between(d, 0.7, 1.15);
            let base = p + stalk_dir * stalk;
            // The blade faces out and up and a little to the sun, each its own way.
            let goal = normalize(up * 0.7 + out * 0.5 + sun * 0.25);
            var face = normalize(goal + roll_ball(d) * 0.9);
            if dot(face, goal) < 0.0 { face = face * -1.0; }
            // Along the stalk's way, sagging, in the blade's plane.
            var along = stalk_dir + up * -0.45;
            along = along - face * dot(along, face);
            let al = length(along);
            along = if al > 1e-3 { along / al } else { turned(face, PI * 0.5, round) };
            let width = size * roll_between(d, 1.05, 1.25);
            let kind = min((roll(d) * LEAF_KINDS) as i64, LEAF_KINDS - 1);
            let leaf_tint = clamp(twig_tint + roll_between(d, -0.08, 0.08), 0.0, 2.0);
            let mid = base + along * (size * 0.5);
            guard base.z > w.house + WALL_GAP && mid.z - size > w.house + WALL_GAP else { continue; }
            let cast = casts(v, mid, size);
            guard !cull || cast || seen(sight, mid, size) else { continue; }
            if t.cards.len < MAX_CARDS {
                t.cards.push(Card { p, base, along, face, size, width, kind as i32, leaf_tint, (first + i) as i32 });
            } else {
                t.left_out++;
            }
            if cast && on_holes(v, on_map(v, mid), size) {
                let across = cross(face, along);
                keep_leaf(t, Leaf { mid, size, map_dir(v, along) * (size * 0.5), map_dir(v, across) * (width * 0.5), kind as i32 });
            }
        }
    }
}

// How many parts of each level a tree has, for the tests and the notes.
fn limbs_at(t: Tree&, level: i64) -> i64 {
    var n = 0;
    for &l in t.limbs { if l.level == level { n++; } }
    return n;
}
