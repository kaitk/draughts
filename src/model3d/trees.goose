// A tree outside the window, grown from a seed (task 105), and its shadow as the sun sees
// it: a trunk and limbs branching with taper and droop (after Weber and Penn, Creation and
// Rendering of Realistic Trees, 1995), leaves as small ellipses clustered on the twigs.
// Only the parts whose shadow can come through the window are kept, up to fixed counts.
// draw_map() bakes how much of the sun passes into four layers, each blurred by the sun's
// disc at its distance, so the gaps between leaves become round flecks. Plain data, tested
// headless; render3d uploads the map once when the room is put on.
//
// The tree's frame, in world units (a square is 1, about 3.3 cm): its origin where the ray
// from the board's middle toward the sun meets the plane through the trunk parallel to the
// window's wall; x along the wall (shaders::LIGHT_FN's `along`), y up, z away from the house.
namespace trees;
import std;
import vec;
import math;

let MAX_SEGMENTS = 8000;
let MAX_LEAVES = 40000;

// The trunk 0, limbs 1, branches 2, twigs 3, and the fine twigs 4.
let LEVELS = 5;

struct Segment { a: float3, b: float3, ra: f32, rb: f32, level: i32 }

// A leaf as its shadow falls: its middle, its length, and on the map the half axes of
// its outline, from the middle to the tip and to the side; a leaf turned toward the sun's
// rays falls short along one of them, edge-on a sliver. `kind` the leaf atlas's leaf
// whose outline it casts (leaf_atlas::silhouettes), -1 the species' own outline.
struct Leaf { at: float3, length: f32, tip: float2, side: float2, kind: i32 = -1 }

// Filled at setup only, as the room is put on: `var t = trees::Tree { .. };`.
root struct Tree {
    segments: Segment[>..] = [],    // at most MAX_SEGMENTS
    leaves:   Leaf[>..]    = [],    // at most MAX_LEAVES
    left_out: i64          = 0,     // parts past those counts
    // The whole tree's (grow_whole) branches and leaves as the picture draws them.
    limbs: Limb[>..] = [],          // at most MAX_LIMBS
    cards: Card[>..] = [],          // at most MAX_CARDS
    // What shedding left of each limb (SHED_GROWN ..), while grow_whole reshapes the tree.
    limb_shed: u8[>..] = [],
}

// What the tree is (rooms::Room's tree, crown and foliage).
struct Spec {
    seed:       f32,
    height:     f32,    // the trunk's
    leafy:      f32,    // how many of its leaves it has (0 bare, 1 full, more denser)
    leaf:       f32,    // a leaf's length
    leaf_width: f32,    // its width against its length
    leaf_light: f32,    // how much of the sun a leaf lets through
    along:      f32,    // the trunk's foot, along the wall and up, in the tree's frame
    ground:     f32,
    crooked:    f32,    // 0 straight limbs, 1 an oak's
    hang:       f32,    // 0 twigs reaching out, 1 hanging as a birch's
    kind:       i64 = 0, // its species (SPECIES_NAMES)
}

// How the sun sees the tree, and the map's rectangle: the key's slant past the wall's
// normal (a point at depth z falls on the map z × shear from its own x and y), the map's
// middle and size in the tree's frame and its texels across and up (square), the ray's length from the board's middle to the trunk's
// plane, how squarely the key meets the wall (the cosine), and how wide the sun's disc is
// (radians across, with the room's softness); and the house's wall, its depth in the
// tree's frame, which nothing of the tree comes nearer than WALL_GAP.
struct View {
    shear:    float2,
    middle:   float2,
    size:     float2,
    w:        i64,
    h:        i64,
    distance: f32,
    toward:   f32,
    blur:     f32,
    wall:     f32,
    // The trunk's and limbs' widths and their blur times these: the shell's tree has them
    // finer and softer (rooms::SHELL_LIMBS), the game's as grown.
    wood: float2 = float2 { 1.0, 1.0 },
    // The windows' own rectangles on the map (x0, x1, y0, y1, with room for the blur and
    // the sway), where the sun gets in: what casts between them, on the piers, is left
    // out of the whole tree (grow_whole). None, all the map's rectangle.
    holes: float4[..4] = [],
}

let WALL_GAP: f32 = 6.0;

// Whether a point of the tree is clear of the house.
fn clear_of_wall(v: View&, p: float3) -> bool { p.z > v.wall + WALL_GAP }

// The game's map's texels a side (the table's cut), the room's across and up (the whole
// window, rooms::tree_view), and the shell's over its three windows (render3d's
// tree_view_of).
let SIDE = 512;
let ROOM_W = 512;
let ROOM_H = 1024;
let SHELL_W = 2048;
let SHELL_H = 768;

// A map's levels, down to the one whose shorter side is a texel (render3d::baked's rule).
fn mips_of(w: i64, h: i64) -> i64 {
    var n = 1;
    while min(w, h) >> n > 0 { n++; }
    return n;
}

// The map's bytes, RGBA8, every level one after another.
fn map_bytes(w: i64, h: i64) -> i64 {
    var n = 0;
    for level in mips_of(w, h) { n += (w >> level) * (h >> level) * 4; }
    return n;
}

// A point of the tree as it falls on the map.
fn on_map(v: View&, p: float3) -> float2 { float2 { p.x - v.shear.x * p.z, p.y - v.shear.y * p.z } }

// How far apart two points of the tree may fall on the map for every unit between them.
fn spread(v: View&) -> f32 { sqrt(1.0 + v.shear.x * v.shear.x + v.shear.y * v.shear.y) }

// Whether a shape at `m` reaching `r` round it falls on the map.
fn on_rect(v: View&, m: float2, r: f32) -> bool {
    return abs(m.x - v.middle.x) <= v.size.x * 0.5 + r && abs(m.y - v.middle.y) <= v.size.y * 0.5 + r;
}

// Whether a segment falls on the map, as grow keeps it: the whole tree's segments
// (grow_whole) reach past it, and only those on it are drawn or count for the layers.
fn segment_on_map(v: View&, sg: Segment&) -> bool {
    let ma = on_map(v, sg.a);
    let mb = on_map(v, sg.b);
    let middle = float2 { (ma.x + mb.x) * 0.5, (ma.y + mb.y) * 0.5 };
    return on_rect(v, middle, length(float2 { mb.x - ma.x, mb.y - ma.y }) * 0.5 + sg.ra);
}

// Whether a segment falls in one of the map's holes, as grow_whole keeps the parts
// that cast.
fn segment_in_holes(v: View&, sg: Segment&) -> bool {
    let ma = on_map(v, sg.a);
    let mb = on_map(v, sg.b);
    let middle = float2 { (ma.x + mb.x) * 0.5, (ma.y + mb.y) * 0.5 };
    return on_holes(v, middle, length(float2 { mb.x - ma.x, mb.y - ma.y }) * 0.5 + sg.ra);
}

// Whether a shape at `m` reaching `r` round it falls on the map, in one of its holes when
// it has them.
fn on_holes(v: View&, m: float2, r: f32) -> bool {
    guard on_rect(v, m, r) else { return false; }
    guard v.holes.len > 0 else { return true; }
    for &o in v.holes {
        if m.x > o.x - r && m.x < o.y + r && m.y > o.z - r && m.y < o.w + r { return true; }
    }
    return false;
}

// splitmix64: a branch's dice from its parent's and its place, so leaving out one branch
// changes no other.
fn mixed(x: u64) -> u64 {
    var z = x + 0x9E3779B97F4A7C15;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

struct Dice { state: u64 }

// In [0, 1).
fn roll(d: Dice&) -> f32 {
    d.state = mixed(d.state);
    let top = (d.state >> 40) as f32;
    return top / 16777216.0;
}

fn roll_between(d: Dice&, lo: f32, hi: f32) -> f32 { lo + (hi - lo) * roll(d) }

// A direction within the unit ball, for crooked bends.
fn roll_ball(d: Dice&) -> float3 {
    return float3 { roll(d) * 2.0 - 1.0, roll(d) * 2.0 - 1.0, roll(d) * 2.0 - 1.0 };
}

// How a kind of tree grows, per level (the fine twigs last): segments a branch (at most
// 8), children it sprouts, where along it they start, their angle off it (degrees), their
// length against it, the radius at its tip against its foot, how crooked (times
// Spec.crooked), how much it turns up a segment, how much more it hangs (times Spec.hang),
// and leaves (times Spec.leafy); whether its children come in opposite pairs, and its
// leaves' size against Spec.leaf and their width against Spec.leaf_width.
struct Species {
    segments: i64[5],
    children: i64[5],
    start:    f32[5],
    angle:    f32[5],
    ratio:    f32[5],
    tip:      f32[5],
    crook:    f32[5],
    rise:     f32[5],
    hang:     f32[5],
    leaves:   f32[5],
    paired:   bool,
    leaf:     f32,
    width:    f32,
    spray:    f32 = 0.0,  // leaves spread round a twig, a ball this many of its segments wide
    lobes:    i64 = 0,    // 0 an ellipse; 5 a maple's palmate leaf, its lobes pointing out from the stalk
    // Leaves a cluster on one foot, overlapping (0 each on its own); each leaf turned at
    // random about its stalk and tilted, facing the sun this much (0 the old way: lying
    // along its stalk as the sun sees it, its width shortened at random); the nearest
    // leaves this much larger at the house; the near layer's blur against the others'.
    cluster:   i64 = 0,
    face:      f32 = 0.0,
    near:      f32 = 0.0,
    near_blur: f32 = 1.0,
}

// A broadleaf of no kind in particular, the first take.
let BROADLEAF = Species {
    segments: [8, 6, 4, 3, 2],
    children: [9, 7, 7, 6, 0],
    start:    [0.35, 0.15, 0.15, 0.2, 0.0],
    angle:    [58.0, 42.0, 45.0, 40.0, 0.0],
    ratio:    [0.55, 0.5, 0.42, 0.42, 0.0],
    tip:      [0.35, 0.25, 0.3, 0.35, 0.4],
    crook:    [0.06, 0.35, 0.4, 0.35, 0.3],
    rise:     [0.0, 0.07, 0.04, 0.02, 0.0],
    hang:     [0.0, 0.02, 0.06, 0.2, 0.3],
    leaves:   [0.0, 0.0, 0.0, 8.0, 22.0],
    paired:   false,
    leaf:     1.0,
    width:    1.0,
    spray:    0.0,
};

// Norway maple (library-autumn-01, -02): its twigs in opposite pairs, a dense rounded
// crown of fairly straight branches, big leaves, so larger flecks and fewer gaps.
let MAPLE = Species {
    segments:  [8, 6, 4, 3, 2],
    children:  [8, 6, 6, 6, 0],
    start:     [0.4, 0.15, 0.15, 0.2, 0.0],
    angle:     [50.0, 45.0, 45.0, 45.0, 0.0],
    ratio:     [0.55, 0.5, 0.45, 0.4, 0.0],
    tip:       [0.35, 0.25, 0.3, 0.35, 0.4],
    crook:     [0.05, 0.2, 0.25, 0.2, 0.2],
    rise:      [0.0, 0.08, 0.05, 0.03, 0.0],
    hang:      [0.0, 0.0, 0.03, 0.1, 0.15],
    leaves:    [0.0, 0.0, 3.0, 8.0, 14.0],
    paired:    true,
    leaf:      1.6,
    width:     1.35,
    spray:     2.0,
    lobes:     5,
    cluster:   3,
    face:      0.6,
    near:      0.6,
    near_blur: 0.5,
};

// Small-leaved lime (garden-facade-01, the manor park's common tree): a dense crown of
// many small leaves, so many fine flecks; its lower limbs sweep down and up again, its
// twigs hang.
let LIME = Species {
    segments: [8, 6, 5, 3, 2],
    children: [10, 7, 7, 7, 0],
    start:    [0.3, 0.15, 0.15, 0.2, 0.0],
    angle:    [62.0, 50.0, 45.0, 42.0, 0.0],
    ratio:    [0.55, 0.5, 0.42, 0.4, 0.0],
    tip:      [0.35, 0.25, 0.3, 0.35, 0.4],
    crook:    [0.05, 0.25, 0.3, 0.3, 0.25],
    rise:     [0.0, 0.1, 0.06, 0.02, 0.0],
    hang:     [0.0, 0.06, 0.12, 0.3, 0.35],
    leaves:   [0.0, 0.0, 4.0, 8.0, 14.0],
    paired:   false,
    leaf:     0.7,
    width:    1.15,
    spray:    1.0,
};

// Oak (garden-facade-01's, and winter's bare take): heavy limbs turning at random in a
// zig-zag, wide angles, many short crooked twigs thin at the tips, which in winter make a
// fine net, not a fishbone; its leaves clustered at the twigs' ends, sky between.
let OAK = Species {
    segments: [8, 7, 5, 4, 3],
    children: [8, 7, 7, 9, 0],
    start:    [0.3, 0.12, 0.12, 0.15, 0.0],
    angle:    [65.0, 55.0, 55.0, 55.0, 0.0],
    ratio:    [0.6, 0.5, 0.42, 0.38, 0.0],
    tip:      [0.3, 0.22, 0.25, 0.3, 0.3],
    crook:    [0.12, 0.6, 0.7, 0.65, 0.55],
    rise:     [0.0, 0.04, 0.03, 0.02, 0.01],
    hang:     [0.0, 0.0, 0.02, 0.05, 0.05],
    leaves:   [0.0, 0.0, 0.0, 5.0, 16.0],
    paired:   false,
    leaf:     1.1,
    width:    0.7,
    spray:    0.9,
};

let SPECIES_COUNT = 4;
let SPECIES_NAMES = ["broadleaf", "maple", "lime", "oak"];

fn species(which: i64) -> Species {
    if which == 1 { return MAPLE; }
    if which == 2 { return LIME; }
    if which == 3 { return OAK; }
    return BROADLEAF;
}

// How far a branch's offspring reach against its length (the ratios summed, and a bend).
let REACH = 1.8;

struct Branch { at: float3, dir: float3, length: f32, radius: f32, level: i64, dice: u64 }

// The tree grown from s, kept where it falls on v's map.
fn grow(t: Tree&, s: Spec, v: View) {
    t.segments.clear();
    t.leaves.clear();
    t.limbs.clear();
    t.cards.clear();
    t.left_out = 0;
    var d = Dice { mixed(s.seed as u64 + 1) };
    let lean = float3 { roll_between(d, -0.08, 0.08), 1.0, roll_between(d, -0.08, 0.08) };
    let trunk = Branch { float3 { s.along, s.ground, 0.0 }, normalize(lean), s.height, s.height * 0.03, 0, d.state };
    var sp = s;
    var vw = v;
    grow_branch(t, sp, vw, trunk);
}

// Turns `dir` by `tilt` away from itself, at `round` about it (radians).
fn turned(dir: float3, tilt: f32, round: f32) -> float3 {
    let other = if abs(dir.y) < 0.9 { float3 { 0.0, 1.0, 0.0 } } else { float3 { 1.0, 0.0, 0.0 } };
    let u = normalize(cross(dir, other));
    let w = cross(dir, u);
    let side = u * cos(round) + w * sin(round);
    return normalize(dir * cos(tilt) + side * sin(tilt));
}

recursive fn grow_branch(t: Tree&, s: Spec&, v: View&, b: Branch) {
    var d = Dice { b.dice };
    let level = b.level;
    let sp = species(s.kind);
    let segments = sp.segments[level];
    let step = b.length / segments;
    let tip = sp.tip[level];
    let sway = s.crooked * sp.crook[level];
    let rise = sp.rise[level] - s.hang * sp.hang[level];
    // The points along it, for its children and leaves.
    var points: float3[9] = [float3 { 0.0, 0.0, 0.0 }; 9];
    var dirs:   float3[9] = [float3 { 0.0, 1.0, 0.0 }; 9];
    var p = b.at;
    var dir = b.dir;
    points[0] = p;
    dirs[0] = dir;
    let k = spread(v);
    // The segments grown, fewer where it was pruned at the house.
    var n = 0;
    for i in segments {
        // Bent a little each segment: crooked at random, its young end turning up to the
        // light, the hanging twigs down.
        dir = normalize(dir + roll_ball(d) * sway + float3 { 0.0, rise, 0.0 });
        let q = p + dir * step;
        let ra = b.radius * (1.0 + (tip - 1.0) * i / segments);
        let rb = b.radius * (1.0 + (tip - 1.0) * (i + 1) / segments);
        let ma = on_map(v, p);
        let mb = on_map(v, q);
        let middle = float2 { (ma.x + mb.x) * 0.5, (ma.y + mb.y) * 0.5 };
        // Pruned where it would reach the house: nothing it grows is kept.
        guard clear_of_wall(v, q) else { break; }
        if on_rect(v, middle, length(float2 { mb.x - ma.x, mb.y - ma.y }) * 0.5 + ra) {
            if t.segments.len < MAX_SEGMENTS {
                t.segments.push(Segment { p, q, ra, rb, level as i32 });
            } else {
                t.left_out++;
            }
        }
        p = q;
        points[i + 1] = p;
        dirs[i + 1] = dir;
        n = i + 1;
    }
    guard n > 0 else { return; }
    // The leaves on dice of their own, so the branches are the same with or without them.
    if level >= 2 && s.leafy > 0.0 && species(s.kind).leaves[level] > 0.0 {
        var leaf_dice = Dice { mixed(b.dice ^ 0x5DEECE66D) };
        add_leaves(t, s, v, leaf_dice, points, n, level);
    }
    guard level < LEVELS - 1 else { return; }
    let count = sp.children[level];
    let start = sp.start[level];
    let first_round = roll(d) * TAU;
    for c in count {
        // Opposite pairs share a place, each pair a quarter turn from the last.
        let slot = if sp.paired { c / 2 } else { c };
        let slots = if sp.paired { (count + 1) / 2 } else { count };
        let f = start + (1.0 - start) * (slot + roll_between(d, 0.2, 0.8)) / slots;
        let at = f * n;
        let i = min(floor(at) as i64, n - 1);
        let w = at - i;
        let foot = points[i] + (points[i + 1] - points[i]) * w;
        let along = normalize(dirs[i + 1]);
        let tilt = radians(sp.angle[level] + roll_between(d, -12.0, 12.0));
        let turn = if sp.paired { slot * (PI * 0.5) + (c % 2) * PI } else { c * 2.39996 };
        let round = first_round + turn + roll_between(d, -0.3, 0.3);
        // The limbs longest low on the trunk, every child shorter toward its parent's tip.
        let shape: f32 = if level == 0 { 1.0 - 0.55 * (f - start) / (1.0 - start) } else { 1.0 - 0.5 * f };
        let child_length = b.length * sp.ratio[level] * shape * roll_between(d, 0.8, 1.15);
        let radius_there = b.radius * (1.0 + (tip - 1.0) * f * n / segments);
        let child_radius = max(radius_there * pow(child_length / b.length, 0.9 as f32), 0.04);
        let child = Branch { foot, turned(along, tilt, round), child_length, child_radius, level + 1,
                             mixed(b.dice ^ ((c + 1) as u64 * 0x9E3779B97F4A7C15)) };
        // Left out where nothing it grows can fall on the map.
        guard clear_of_wall(v, foot) && on_rect(v, on_map(v, foot), (child_length * (REACH + sp.spray) + s.leaf * sp.leaf * 2.0) * k) else {
            continue;
        }
        grow_branch(t, s, v, child);
    }
}

// The leaves along a twig's outer part and clustered at its tip, each on a short stalk
// out from it, as many as Spec.leafy says.
fn add_leaves(t: Tree&, s: Spec&, v: View&, d: Dice&, points: float3[9]&, n: i64, level: i64) {
    let sp = species(s.kind);
    let want = sp.leaves[level] * s.leafy;
    var count = floor(want) as i64;
    if roll(d) < want - count { count++; }
    if sp.cluster > 1 {
        add_clusters(t, s, v, d, points, n, count);
        return;
    }
    for j in count {
        // Along the outer four fifths, a little more toward the tip.
        let f = 1.0 - 0.8 * roll(d) * (0.5 + 0.5 * roll(d));
        let at = f * n;
        let i = min(floor(at) as i64, n - 1);
        let foot = points[i] + (points[i + 1] - points[i]) * (at - i);
        let out = normalize(roll_ball(d) + float3 { 0.0, -0.3 * s.hang, 0.0 });
        let length = s.leaf * sp.leaf * roll_between(d, 0.75, 1.2);
        // On a short stalk, or sprayed round the twig in a loose ball, so the crown's
        // outer shell fills with leaves and gaps between them.
        let seg = points[i + 1] - points[i];
        let step = sqrt(dot(seg, seg));
        let middle = foot + out * (length * 0.9 + sp.spray * step * roll(d));
        let m = on_map(v, middle);
        guard clear_of_wall(v, middle) && on_rect(v, m, length) else { continue; }
        // Turned along its stalk as the sun sees it, foreshortened by its tilt.
        let mo = on_map(v, middle + out);
        let angle = atan2(mo.y - m.y, mo.x - m.x) + roll_between(d, -0.5, 0.5);
        let width = length * min(s.leaf_width * sp.width, 1.0) * roll_between(d, 0.45, 1.0);
        let tip = float2 { cos(angle), sin(angle) } * (length * 0.5);
        let side = float2 { -sin(angle), cos(angle) } * (width * 0.5);
        keep_leaf(t, Leaf { middle, length, tip, side, .. });
    }
}

fn keep_leaf(t: Tree&, lf: Leaf) {
    if t.leaves.len < MAX_LEAVES {
        t.leaves.push(lf);
    } else {
        t.left_out++;
    }
}

// A direction of the tree as it falls on the map.
fn map_dir(v: View&, d: float3) -> float2 { float2 { d.x - v.shear.x * d.z, d.y - v.shear.y * d.z } }

// The leaves `count` a twig, in clusters of Species.cluster on one foot, as a maple's come
// at a twig's nodes and tip: their stalks fanning out from it, the blades overlapping by
// the foot. Each blade turned at random about its stalk and tilted, leaning toward the
// sun by Species.face, so some show their whole outline and some only a sliver; the
// nearest the house larger by Species.near.
fn add_clusters(t: Tree&, s: Spec&, v: View&, d: Dice&, points: float3[9]&, n: i64, count: i64) {
    let sp = species(s.kind);
    let sun = normalize(float3 { v.shear.x, v.shear.y, 1.0 });
    let size = sp.cluster;
    let clusters = (count + size - 1) / size;
    var left = count;
    for c in clusters {
        let f = 1.0 - 0.8 * roll(d) * (0.5 + 0.5 * roll(d));
        let at = f * n;
        let i = min(floor(at) as i64, n - 1);
        let seg = points[i + 1] - points[i];
        let step = sqrt(dot(seg, seg));
        let out = normalize(roll_ball(d) + float3 { 0.0, -0.3 * s.hang, 0.0 });
        let foot = points[i] + seg * (at - i) + out * (sp.spray * step * roll(d));
        let near = clamp(foot.z / (v.wall + WALL_GAP), 0.0, 1.0);
        let first = roll(d) * TAU;
        let here = min(left, size + (if roll(d) < 0.3 { 1 } else { 0 }));
        left -= here;
        for k in here {
            // Fanned out about the cluster's direction, each its own way.
            let round = first + k * TAU / here + roll_between(d, -0.4, 0.4);
            let stalk = turned(out, roll_between(d, 0.4, 0.9), round);
            let length = s.leaf * sp.leaf * roll_between(d, 0.75, 1.2) * (1.0 + sp.near * near);
            let middle = foot + stalk * (length * roll_between(d, 0.4, 0.65));
            guard clear_of_wall(v, middle) && on_rect(v, on_map(v, middle), length) else { continue; }
            // The blade's face: at random about the stalk, then leaning toward the sun.
            var face = turned(stalk, PI * 0.5, roll(d) * TAU);
            if dot(face, sun) < 0.0 { face = face * -1.0; }
            face = normalize(face + sun * sp.face);
            let along = normalize(stalk - face * dot(stalk, face));
            let across = cross(face, along);
            let width = length * min(s.leaf_width * sp.width, 1.0) * roll_between(d, 0.8, 1.0);
            keep_leaf(t, Leaf { middle, length, map_dir(v, along) * (length * 0.5), map_dir(v, across) * (width * 0.5), .. });
        }
    }
}

// The map's layers: its R, G and B the twigs and leaves nearer the house than the trunk,
// round it, and farther, A the trunk and limbs; each swayed by the wind on its own.
let NEAR = 0;
let MIDDLE = 1;
let FAR = 2;
let WOOD = 3;

// The layers' bounds: the depths of the twigs and leaves kept, cut in thirds.
struct Depths { near: f32, far: f32 }

fn depths(t: Tree&, v: View&) -> Depths {
    var lo: f32 = 1e9;
    var hi: f32 = -1e9;
    for &sg in t.segments {
        guard sg.level > 1 && segment_on_map(v, sg) else { continue; }
        let z = (sg.a.z + sg.b.z) * 0.5;
        lo = min(lo, z);
        hi = max(hi, z);
    }
    for &lf in t.leaves {
        lo = min(lo, lf.at.z);
        hi = max(hi, lf.at.z);
    }
    guard hi > lo else { return Depths { 0.0, 0.0 }; }
    return Depths { lo + (hi - lo) / 3.0, lo + (hi - lo) * 2.0 / 3.0 };
}

fn layer_of_depth(z: f32, d: Depths&) -> i64 { if z < d.near { NEAR } else if z > d.far { FAR } else { MIDDLE } }

fn layer_of_segment(sg: Segment&, d: Depths&) -> i64 {
    if sg.level <= 1 { return WOOD; }
    return layer_of_depth((sg.a.z + sg.b.z) * 0.5, d);
}

// The map: how much of the sun the tree lets through, as the board's middle sees it,
// RGBA8 at v.w × v.h texels and then its mips (map_bytes() in all) into `out`.
fn draw_map(t: Tree&, s: Spec, v: View, out: u8[>..]&) {
    out.clear();
    out.resize(map_bytes(v.w, v.h), 255);
    var plane: f32[>..] = [];
    plane.resize(v.w * v.h, 1.0);
    var sums: f32[>..] = [];
    var sp = s;
    var vw = v;
    let depth = depths(t, vw);
    // The atlas's leaves' outlines, for the leaves that cast one.
    var outlines: f32[>..] = [];
    leaf_atlas::silhouettes(outlines);
    // Each layer's mean depth, for its blur.
    var z_sum:   f32[4] = [0.0; 4];
    var z_count: f32[4] = [0.0; 4];
    for &sg in t.segments {
        guard segment_on_map(vw, sg) else { continue; }
        let l = layer_of_segment(sg, depth);
        z_sum[l] += (sg.a.z + sg.b.z) * 0.5;
        z_count[l] += 1.0;
    }
    for &lf in t.leaves {
        let l = layer_of_depth(lf.at.z, depth);
        z_sum[l] += lf.at.z;
        z_count[l] += 1.0;
    }
    let texel = vw.size.x / vw.w;
    for layer in 4 {
        for i in plane.len { plane[i] = 1.0; }
        for &sg in t.segments {
            guard layer_of_segment(sg, depth) == layer && segment_on_map(vw, sg) else { continue; }
            draw_segment(plane, vw, sg);
        }
        for &lf in t.leaves {
            guard layer_of_depth(lf.at.z, depth) == layer else { continue; }
            if lf.kind >= 0 {
                draw_atlas_leaf(plane, vw, lf, 1.0 - sp.leaf_light, outlines);
            } else {
                draw_leaf(plane, vw, lf, 1.0 - sp.leaf_light, species(sp.kind).lobes);
            }
        }
        let z = if z_count[layer] > 0.0 { z_sum[layer] / z_count[layer] } else { 0.0 };
        let sharper = if layer == NEAR { species(sp.kind).near_blur } else { 1.0 };
        let wood = if layer == WOOD { vw.wood.y } else { 1.0 };
        let across = max(vw.distance + z / vw.toward, 1.0) * vw.blur * sharper * wood;
        blur_disc(plane, sums, vw, across * 0.5 / texel);
        for i in vw.w * vw.h {
            out[i * 4 + layer] = (clamp(plane[i], 0.0, 1.0) * 255.0 + 0.5) as u8;
        }
    }
    shrink_levels(out, vw.w, vw.h);
}

// The texel's middle in the tree's frame.
fn texel_x(v: View&, i: i64) -> f32 { v.middle.x - v.size.x * 0.5 + (i + 0.5) * v.size.x / v.w }
fn texel_y(v: View&, j: i64) -> f32 { v.middle.y - v.size.y * 0.5 + (j + 0.5) * v.size.y / v.h }

// The texels a shape over lo..hi (the tree's frame, along one axis: the map's middle,
// size, and texels on it) touches, clamped to the map.
fn texel_range(lo: f32, hi: f32, middle: f32, size: f32, n: i64) -> i64, i64 {
    let k = n / size;
    let a = floor((lo - (middle - size * 0.5)) * k) as i64;
    let b = ceil((hi - (middle - size * 0.5)) * k) as i64;
    return clamp(a, 0, n), clamp(b, 0, n);
}

// A branch's segment, a tapered capsule as the sun sees it (its width unchanged by the
// slant), its coverage antialiased over a texel, a twig thinner than one drawn fainter.
fn draw_segment(plane: f32[>..]&, v: View&, sg: Segment&) {
    let a = on_map(v, sg.a);
    let b = on_map(v, sg.b);
    let wide = if sg.level <= 1 { v.wood.x } else { 1.0 };
    let ra = sg.ra * wide;
    let rb = sg.rb * wide;
    let r = max(ra, rb);
    let texel = v.size.x / v.w;
    let x0, x1 = texel_range(min(a.x, b.x) - r - texel, max(a.x, b.x) + r + texel, v.middle.x, v.size.x, v.w);
    let y0, y1 = texel_range(min(a.y, b.y) - r - texel, max(a.y, b.y) + r + texel, v.middle.y, v.size.y, v.h);
    let ab = float2 { b.x - a.x, b.y - a.y };
    let ll = max(dot(ab, ab), 1e-8);
    for j in y0..y1 {
        let y = texel_y(v, j);
        for i in x0..x1 {
            let x = texel_x(v, i);
            let ap = float2 { x - a.x, y - a.y };
            let h = clamp(dot(ap, ab) / ll, 0.0, 1.0);
            let dx = ap.x - ab.x * h;
            let dy = ap.y - ab.y * h;
            let rr = ra + (rb - ra) * h;
            let dist = sqrt(dx * dx + dy * dy);
            let cover = clamp(rr + texel * 0.5 - dist, 0.0, min(2.0 * rr, texel)) / texel;
            guard cover > 0.0 else { continue; }
            plane[j * v.w + i] *= 1.0 - cover;
        }
    }
}

// A leaf cast by the leaf atlas's outline of it (leaf_atlas::silhouettes), on its half
// axes: the blade's middle at lf.at, its foot half a length back along lf.tip. Edge-on, a
// sliver as draw_leaf draws it.
fn draw_atlas_leaf(plane: f32[>..]&, v: View&, lf: Leaf&, blocks: f32, outlines: f32[>..]&) {
    let texel = v.size.x / v.w;
    let a = lf.tip;
    let b = lf.side;
    let la = max(length(a), 1e-6);
    let thin = abs(a.x * b.y - a.y * b.x) / la;
    guard thin >= texel * 0.5 else {
        draw_leaf(plane, v, lf, blocks, 0);
        return;
    }
    let m = on_map(v, lf.at);
    let det = a.x * b.y - a.y * b.x;
    // The outline's box in half lengths along and half widths across.
    let rx = abs(a.x) * 2.2 + abs(b.x) * 1.5;
    let ry = abs(a.y) * 2.2 + abs(b.y) * 1.5;
    let x0, x1 = texel_range(m.x - rx - texel, m.x + rx + texel, v.middle.x, v.size.x, v.w);
    let y0, y1 = texel_range(m.y - ry - texel, m.y + ry + texel, v.middle.y, v.size.y, v.h);
    let du = float2 { b.y / det, -b.x / det };
    let dw = float2 { -a.y / det, a.x / det };
    let base = lf.kind * leaf_atlas::MASK * leaf_atlas::MASK;
    for j in y0..y1 {
        let y = texel_y(v, j) - m.y;
        for i in x0..x1 {
            let x = texel_x(v, i) - m.x;
            let u = du.x * x + du.y * y;
            let w = dw.x * x + dw.y * y;
            let cover = leaf_atlas::outline_at(outlines, base, w * leaf_atlas::ACROSS_HALF, 0.5 + u * 0.5);
            guard cover > 0.0 else { continue; }
            plane[j * v.w + i] *= 1.0 - blocks * cover;
        }
    }
}

// A leaf, an ellipse or a palmate outline on its half axes, letting `blocks` of the sun's
// light stop where it covers.
fn draw_leaf(plane: f32[>..]&, v: View&, lf: Leaf&, blocks: f32, lobes: i64) {
    let m = on_map(v, lf.at);
    let texel = v.size.x / v.w;
    let a = lf.tip;
    var b = lf.side;
    // A sliver thinner than half a texel drawn half a texel wide and fainter.
    let la = max(length(a), 1e-6);
    let thin = abs(a.x * b.y - a.y * b.x) / la;
    var stops = blocks;
    if thin < texel * 0.25 {
        let normal = float2 { -a.y / la, a.x / la };
        stops = blocks * thin / (texel * 0.25);
        b = normal * (texel * 0.25);
    }
    let det = a.x * b.y - a.y * b.x;
    let rx = abs(a.x) + abs(b.x);
    let ry = abs(a.y) + abs(b.y);
    let x0, x1 = texel_range(m.x - rx - texel, m.x + rx + texel, v.middle.x, v.size.x, v.w);
    let y0, y1 = texel_range(m.y - ry - texel, m.y + ry + texel, v.middle.y, v.size.y, v.h);
    // The leaf's own coordinates' change a unit on the map.
    let du = float2 { b.y / det, -b.x / det };
    let dw = float2 { -a.y / det, a.x / det };
    for j in y0..y1 {
        let y = texel_y(v, j) - m.y;
        for i in x0..x1 {
            let x = texel_x(v, i) - m.x;
            let u = du.x * x + du.y * y;
            let w = dw.x * x + dw.y * y;
            let r = max(sqrt(u * u + w * w), 1e-4);
            // The distance to the edge to first order (Quilez): r's change a unit on the map.
            let gx = (u * du.x + w * dw.x) / r;
            let gy = (u * du.y + w * dw.y) / r;
            let step = max(sqrt(gx * gx + gy * gy), 1e-6) * texel;
            // Outside the round outline, or (a palmate leaf) well inside its sinuses: no
            // lobes to work out.
            guard r - 1.0 < 0.5 * step else { continue; }
            var edge: f32 = 1.0;
            if lobes > 0 && r - 0.28 > -0.5 * step {
                // A palmate leaf: round, its radius waving with the lobes, pointed ones out
                // from the stalk (+u) and to the sides, a notch where the stalk joins.
                let turn = atan2(w, u);
                let wave = cos(lobes * turn);
                let pointed = if wave > 0.0 { pow(wave, 0.6 as f32) } else { -pow(-wave, 1.5 as f32) };
                let notch_from: f32 = 2.4;
                let notch_to:   f32 = 3.1;
                let notch = smoothstep(notch_from, notch_to, abs(turn));
                // A maple's: broad, shallow sinuses, three big lobes and two small ones
                // by the stalk, none narrower than 0.28 of its radius.
                let low_from: f32 = 1.6;
                let low_to:   f32 = 2.6;
                let low = smoothstep(low_from, low_to, abs(turn));
                edge = (0.84 + 0.16 * pointed) * (1.0 - 0.25 * low) * (1.0 - 0.45 * notch);
            }
            let dist = (r - edge) * texel / step;
            let cover = clamp(0.5 - dist / texel, 0.0, 1.0);
            guard cover > 0.0 else { continue; }
            plane[j * v.w + i] *= 1.0 - stops * cover;
        }
    }
}

// The plane blurred by the sun's disc, `radius` texels, seen slanted on the map: an
// ellipse longer by 1 / toward along the key's slant. Each row's running sums give a span
// of it in two reads, its ends interpolated, the map's edge carried on outward.
fn blur_disc(plane: f32[>..]&, sums: f32[>..]&, v: View&, radius: f32) {
    guard radius > 0.5 else { return; }
    let long = radius / max(v.toward, 0.2);
    let slant = length(v.shear);
    let ux: f32 = if slant > 1e-4 { v.shear.x / slant } else { 1.0 };
    let uy: f32 = if slant > 1e-4 { v.shear.y / slant } else { 0.0 };
    let reach = ceil(long) as i64 + 2;
    let w = v.w;
    let h = v.h;
    let row = w + 2 * reach + 1;
    sums.clear();
    sums.resize(row * h, 0.0);
    for j in h {
        var run: f32 = 0.0;
        sums[j * row] = 0.0;
        for k in row - 1 {
            let i = clamp(k - reach, 0, w - 1);
            run += plane[j * w + i];
            sums[j * row + k + 1] = run;
        }
    }
    // The ellipse's spans: for each row dy, x from middle - half to middle + half.
    let qa = ux * ux / (long * long) + uy * uy / (radius * radius);
    let qc_y = uy * uy / (long * long) + ux * ux / (radius * radius);
    let qb_y = 2.0 * ux * uy * (1.0 / (long * long) - 1.0 / (radius * radius));
    var mids:   f32[..256] = [];
    var halves: f32[..256] = [];
    var rows:   i64[..256] = [];
    var area:   f32        = 0.0;
    let up = min(reach, 120);
    for dy in -up..up + 1 {
        let y = dy as f32;
        let b = qb_y * y;
        let c = qc_y * y * y - 1.0;
        let disc = b * b - 4.0 * qa * c;
        guard disc > 0.0 else { continue; }
        let half = min(sqrt(disc) / (2.0 * qa), reach - 1.0);
        mids.push(-b / (2.0 * qa));
        halves.push(half);
        rows.push(dy);
        area += 2.0 * half;
    }
    guard area > 0.0 else { return; }
    let scale = 1.0 / area;
    for j in h {
        for i in w {
            var total: f32 = 0.0;
            for r, n in rows {
                let jj = clamp(j + r, 0, h - 1);
                let base = jj * row;
                let lo = mids[n] - halves[n] + (i + reach) + 0.5;
                let hi = mids[n] + halves[n] + (i + reach) + 0.5;
                total += sum_at(sums, base, hi) - sum_at(sums, base, lo);
            }
            plane[j * w + i] = total * scale;
        }
    }
}

// A row's running sum at a fractional place.
fn sum_at(sums: f32[>..]&, base: i64, x: f32) -> f32 {
    let i = floor(x) as i64;
    let f = x - i;
    return sums[base + i] + (sums[base + i + 1] - sums[base + i]) * f;
}

// Each level after the first the one before averaged two by two.
fn shrink_levels(out: u8[>..]&, w0: i64, h0: i64) {
    var from = 0;
    var w = w0;
    var h = h0;
    for level in 1..mips_of(w0, h0) {
        let to = from + w * h * 4;
        let hw = w / 2;
        let hh = h / 2;
        for y in hh {
            for x in hw {
                for c in 4 {
                    let a = out[from + ((2 * y) * w + 2 * x) * 4 + c] as i64;
                    let b = out[from + ((2 * y) * w + 2 * x + 1) * 4 + c] as i64;
                    let e = out[from + ((2 * y + 1) * w + 2 * x) * 4 + c] as i64;
                    let f = out[from + ((2 * y + 1) * w + 2 * x + 1) * 4 + c] as i64;
                    out[to + (y * hw + x) * 4 + c] = ((a + b + e + f + 2) / 4) as u8;
                }
            }
        }
        from = to;
        w = hw;
        h = hh;
    }
}

// How much of the sun the map of v.w × v.h lets through on average (a layer, or all four
// multiplied), for the tests.
fn passing(out: u8[>..]&, layer: i64, v: View&) -> f32 {
    var total: f32 = 0.0;
    for i in v.w * v.h {
        var x: f32 = 1.0;
        if layer >= 0 { x = out[i * 4 + layer] / 255.0; }
        else { for c in 4 { x *= out[i * 4 + c] / 255.0; } }
        total += x;
    }
    return total / (v.w * v.h);
}
