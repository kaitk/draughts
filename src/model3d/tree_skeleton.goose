// The passes on the whole tree's grown skeleton (task 117), run by grow_whole between its
// growth and its culling when Whole.growth asks: Palubicki et al. 2009's shedding of
// shaded thin wood (shed_shaded), the gravity layer (bend_by_weight: Stava et al. 2014's
// bending with a beam's stiffness by r⁴, and the growth's correction upward), and
// keep_parts, which drops what was shed and keeps what the windows show or cast through
// them. Part of trees, in its namespace; at setup only, never in the frame loop.
namespace trees;
import std;
import vec;
import math;

// What shedding left of a limb (Tree.limb_shed).
let SHED_GROWN = 0;
let SHED_STUB = 1;  // its first segment, the rest and its offspring gone
let SHED_GONE = 2;

fn shed_state(t: Tree&, limb: i64) -> u8 {
    guard limb < t.limb_shed.len else { return SHED_GROWN; }
    return t.limb_shed[limb];
}

// Whether a limb is a broken leader's stub (a limb of its parent's level).
fn is_stub(t: Tree&, l: Limb) -> bool { l.parent >= 0 && t.limbs[l.parent as i64].level == l.level }

// The sky's ways the shedding looks along for a twig's light (sky_ways' first five: up,
// counted twice, and four round at 35°), worked out once a grid cell, from its middle.
// A cheaper tier looks up alone (SHED_WAYS 1).
let SHED_WAYS = 5;

fn cell_middle(g: Grid, cell: i64) -> float3 {
    let i = cell % GRID;
    let j = (cell / GRID) % GRID;
    let k = cell / (GRID * GRID);
    return g.low + float3 { i + 0.5, j + 0.5, k + 0.5 } * g.cell;
}

// The leaves' grid for the shedding's light: each twig's leaves in full leaf (add_cards'
// TWIG_NODES pairs) at its tip, where add_cards grows them (in the shell), whatever the
// season's Whole.leafy, so a bare tree sheds as a leafy one. crown_grid's cells and
// extinction.
fn foliage_grid(t: Tree&, w: Whole&, density: f32[>..]&) -> Grid {
    var lo = float3 { 1e9, 1e9, 1e9 };
    var hi = float3 { -1e9, -1e9, -1e9 };
    for &l in t.limbs {
        guard l.level == 4 && l.count > 0 else { continue; }
        let p = t.segments[(l.first + l.count - 1) as i64].b;
        lo = float3 { min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z) };
        hi = float3 { max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z) };
    }
    density.clear();
    density.resize(GRID * GRID * GRID, 0.0);
    guard hi.x > lo.x else { return Grid { float3_0, 1.0 }; }
    lo = lo - float3 { GRID_MARGIN, GRID_MARGIN, GRID_MARGIN };
    hi = hi + float3 { GRID_MARGIN, GRID_MARGIN, GRID_MARGIN };
    let span = hi - lo;
    let cell = max(span.x, max(span.y, span.z)) / GRID;
    let g = Grid { lo, cell };
    let leaves: f32 = TWIG_NODES * 2 + 0.3;
    let area = leaves * w.leaf * w.leaf * 1.15 * BLADE_FILL * LEAF_EXTINCTION / (cell * cell * cell);
    for &l in t.limbs {
        guard l.level == 4 && l.count > 0 else { continue; }
        let p = t.segments[(l.first + l.count - 1) as i64].b;
        guard crown_depth(w, p) < w.shell else { continue; }
        let at = cell_of(g, p);
        guard at >= 0 else { continue; }
        density[at] += area;
    }
    return g;
}

// Palubicki's shedding (Takenaka 1994): a branch whose light a twig falls under
// Growth.shed.x dies; its twigs and leaves fall, and Growth.shed.y of the branches and
// branchlets stay as a stub of their first segment. A twig's light is the sky's open share
// at its tip through the foliage grid; a branch's the mean of its twigs'. The trunk and
// the hero limbs stay. Fills t.limb_shed.
fn shed_shaded(t: Tree&, w: Whole&) {
    let n = t.limbs.len;
    t.limb_shed.clear();
    t.limb_shed.resize(n, SHED_GROWN);
    var density: f32[>..] = [];
    let g = foliage_grid(t, w, density);
    let ways = sky_ways();
    // Each limb's twigs' light summed and counted.
    var light: float2[>..] = [];
    light.resize(n, float2_0);
    // Each cell's open share, -1 not yet worked out.
    var open_of_cell: f32[>..] = [];
    open_of_cell.resize(GRID * GRID * GRID, -1.0);
    for li in n {
        let l = t.limbs[li];
        guard l.level == 4 && l.count > 0 else { continue; }
        let cell = cell_of(g, t.segments[(l.first + l.count - 1) as i64].b);
        guard cell >= 0 else {
            light[li] = float2 { 1.0, 1.0 };
            continue;
        }
        if open_of_cell[cell] < 0.0 {
            let p = cell_middle(g, cell);
            var open: f32 = 2.0 * open_along(density, g, p, ways[0]);
            for k in 1..SHED_WAYS { open += open_along(density, g, p, ways[k]); }
            open_of_cell[cell] = open / (SHED_WAYS + 1);
        }
        light[li] = float2 { open_of_cell[cell], 1.0 };
    }
    for k in n {
        let li = n - 1 - k;
        let p = t.limbs[li].parent;
        guard p >= 0 else { continue; }
        light[p as i64] = light[p as i64] + light[li];
    }
    let threshold = w.growth.shed.x;
    for li in n {
        let l = t.limbs[li];
        guard l.parent >= 0 else { continue; }
        // What its parent lost, it loses.
        if t.limb_shed[l.parent as i64] != SHED_GROWN {
            t.limb_shed[li] = SHED_GONE;
            continue;
        }
        guard l.level >= 2 && !is_stub(t, l) else { continue; }
        let lit = light[li];
        let mean = if lit.y > 0.0 { lit.x / lit.y } else { 0.0 };
        guard mean < threshold else { continue; }
        var d = Dice { mixed(li as u64 * 0x9E3779B97F4A7C15 + 0x5EED) };
        if l.level < 4 && roll(d) < w.growth.shed.y {
            t.limb_shed[li] = SHED_STUB;
            let s = l.first as i64;
            t.segments[s].rb = t.segments[s].ra * 0.7;
        } else {
            t.limb_shed[li] = SHED_GONE;
        }
    }
}

// How many segments of a limb are still wood after shedding.
fn kept_count(t: Tree&, li: i64) -> i64 {
    let state = shed_state(t, li);
    if state == SHED_GONE { return 0; }
    if state == SHED_STUB { return 1; }
    return t.limbs[li].count;
}

// A rotation as a unit quaternion (x, y, z the axis times sin(angle / 2), w cos(angle / 2)).
let ROTATION_NONE = float4 { 0.0, 0.0, 0.0, 1.0 };

fn rotation_about(axis: float3, angle: f32) -> float4 {
    let s = sin(angle * 0.5);
    return float4 { axis.x * s, axis.y * s, axis.z * s, cos(angle * 0.5) };
}

// a after b.
fn rotation_then(a: float4, b: float4) -> float4 {
    let q = float4 { a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
                     a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
                     a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
                     a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z };
    return q / length(q);
}

fn rotated(q: float4, v: float3) -> float3 {
    let u = float3 { q.x, q.y, q.z };
    let t = cross(u, v) * 2.0;
    return v + t * q.w + cross(u, t);
}

// The gravity layer's constants (the study's, build/notes/tree/branches/src/gravity.py):
// green wood's density (kg/m³), an effective stiffness (Pa, set by eye: green maple's 10 GPa
// barely bends in one pass, real limbs sag over years under a growing load), Stava's GBA
// over the thickness in millimetres, the length his largest bend is for (a year's
// internode, m), and the growth's correction upward: young wood (radius under
// YOUNG_RADIUS, m) back CORRECT_YOUNG of the way it dropped, old wood CORRECT_OLD.
let WOOD_DENSITY:  f32 = 900.0;
let STIFFNESS:     f32 = 2e7;
let BEND_PER:      f32 = 0.5;
let YOUNG_RADIUS:  f32 = 0.025;
let CORRECT_YOUNG: f32 = 0.85;
let CORRECT_OLD:   f32 = 0.25;

// The grown wood bent by its own weight, every segment in order from the trunk out, its
// leaves carried with its twig. At each segment's foot (Stava et al. 2014, appendix A):
// the force fb = m g |c - p0| |h_level| (1 - |h . down|), m the wood it carries and c that
// wood's middle, so upright wood doesn't bend; the angle a beam's, fb L / (E π r⁴ / 4),
// saturating at Stava's largest (π / 2) / d^0.5 a half metre; then the growth's correction
// back toward the way it grew (Almeras and Fournier 2009), most in young wood. `strength`
// divides the stiffness.
fn bend_by_weight(t: Tree&, strength: f32) {
    let n = t.segments.len;
    let k = 1.0 / surfaces::METRE;
    var parent: i32[>..] = [];
    parent.resize(n, -1);
    var mass: f32[>..] = [];
    mass.resize(n, 0.0);
    // Each segment's carried wood's mass times its middle, then its middle.
    var middle: float3[>..] = [];
    middle.resize(n, float3_0);
    for li in t.limbs.len {
        let l = t.limbs[li];
        for j in kept_count(t, li) {
            let s = l.first + j;
            parent[s] = if j == 0 { l.attach } else { (s - 1) as i32 };
            let sg = t.segments[s];
            let r = (sg.ra + sg.rb) * 0.5 * k;
            let m = PI * r * r * length(sg.b - sg.a) * k * WOOD_DENSITY;
            mass[s] = max(m, 1e-9);
            middle[s] = (sg.a + sg.b) * (0.5 * mass[s]);
        }
    }
    for i in n {
        let s = n - 1 - i;
        let p = parent[s] as i64;
        guard p >= 0 && mass[s] > 0.0 else { continue; }
        mass[p] += mass[s];
        middle[p] = middle[p] + middle[s];
    }
    var turn: float4[>..] = [];
    turn.resize(n, ROTATION_NONE);
    var moved: float3[>..] = [];
    moved.resize(n, float3_0);
    let down = float3 { 0.0, -1.0, 0.0 };
    let stiffness = STIFFNESS / max(strength, 1e-3);
    for s in n {
        guard mass[s] > 0.0 else { continue; }
        let sg = t.segments[s];
        let p = parent[s] as i64;
        let before = if p >= 0 { turn[p] } else { ROTATION_NONE };
        moved[s] = if p >= 0 { moved[p] + rotated(before, sg.a - t.segments[p].a) } else { sg.a };
        let v = sg.b - sg.a;
        let len = length(v);
        // A twig (level 4) is too light to bend: it turns with the wood it grows on.
        guard len > 1e-6 && sg.level < 4 else {
            turn[s] = before;
            continue;
        }
        let grown = v / len;
        let h = rotated(before, grown);
        let level = sqrt(h.x * h.x + h.z * h.z);
        let lever = length(middle[s] / mass[s] - sg.a) * k;
        let force = mass[s] * 9.81 * lever * level * (1.0 - abs(h.y));
        let thick_mm = max(2000.0 * sg.ra * k, 0.1);
        let most = (PI * 0.5) / sqrt(thick_mm) * (len * k / BEND_PER);
        let r = max(sg.ra * k, 1e-4);
        let beam = force * len * k / (stiffness * PI * r * r * r * r * 0.25);
        var q = before;
        if level > 1e-6 && most > 0.0 {
            let angle = min(most * (1.0 - exp(-beam / most)), acos(clamp(-h.y, -1.0, 1.0)));
            if angle > 1e-6 { q = rotation_then(rotation_about(normalize(cross(h, down)), angle), q); }
        }
        // The correction toward the way it grew.
        let now = rotated(q, grown);
        let young = clamp(1.0 - sg.ra * k / YOUNG_RADIUS, 0.0, 1.0);
        let back = CORRECT_OLD + (CORRECT_YOUNG - CORRECT_OLD) * young;
        let c = clamp(dot(now, grown), -1.0, 1.0);
        let axis = cross(now, grown);
        let al = length(axis);
        if c < 0.99999 && grown.y > now.y && al > 1e-6 { q = rotation_then(rotation_about(axis / al, acos(c) * back), q); }
        turn[s] = q;
    }
    // The leaves with their twigs, then the wood.
    for &c in t.cards {
        let s = c.segment as i64;
        guard s >= 0 && s < n && mass[s] > 0.0 else { continue; }
        let a = t.segments[s].a;
        let q = turn[s];
        c.foot = moved[s] + rotated(q, c.foot - a);
        c.base = moved[s] + rotated(q, c.base - a);
        c.along = rotated(q, c.along);
        c.face = rotated(q, c.face);
    }
    for s in n {
        guard mass[s] > 0.0 else { continue; }
        let v = t.segments[s].b - t.segments[s].a;
        t.segments[s].a = moved[s];
        t.segments[s].b = moved[s] + rotated(turn[s], v);
    }
}

// The whole grown tree cut to what stays: the shed wood dropped (Tree.limb_shed), and with
// `cull` only the limbs seen through `sight` or casting on v's map, tested at their reshaped
// feet as grow_part tests them while growing; the leaves likewise, and t.leaves made from
// the cards that cast. Limbs, segments and cards keep their order.
fn keep_parts(t: Tree&, w: Whole&, v: View&, sight: Sight&, cull: bool) {
    let limbs = t.limbs.len;
    let segments = t.segments.len;
    var limb_to: i32[>..] = [];
    limb_to.resize(limbs, -1);
    // Each segment's new place, -1 dropped; and whether its limb keeps its leaves.
    var segment_to: i32[>..] = [];
    segment_to.resize(segments, -1);
    var leafy: bool[>..] = [];
    leafy.resize(segments, false);
    var ws = 0;
    var wl = 0;
    for li in limbs {
        let l = t.limbs[li];
        let count = kept_count(t, li);
        var keep = count > 0 && (l.parent < 0 || limb_to[l.parent as i64] >= 0);
        if keep && cull && l.level > 0 && !is_stub(t, l) {
            var len: f32 = 0.0;
            for j in l.count as i64 { len += length(t.segments[l.first + j].b - t.segments[l.first + j].a); }
            let foot = t.segments[l.first as i64].a;
            let reach = len * WHOLE_REACH + w.leaf * 3.0;
            keep = casts(v, foot, reach) || seen(sight, foot, reach);
        }
        guard keep else { continue; }
        let first = ws;
        let grown = shed_state(t, li) == SHED_GROWN;
        for j in count {
            let s = l.first + j;
            segment_to[s] = ws as i32;
            leafy[s] = grown;
            t.segments[ws] = t.segments[s];
            ws++;
        }
        let parent = if l.parent >= 0 { limb_to[l.parent as i64] } else { -1 };
        let attach = if l.attach >= 0 { segment_to[l.attach as i64] } else { -1 };
        t.limbs[wl] = Limb { first as i32, count as i32, l.level, parent, attach };
        limb_to[li] = wl as i32;
        wl++;
    }
    t.segments.resize(ws);
    t.limbs.resize(wl);
    t.limb_shed.clear();
    t.leaves.clear();
    var wc = 0;
    for ci in t.cards.len {
        let c = t.cards[ci];
        let s = c.segment as i64;
        guard s >= 0 && segment_to[s] >= 0 && leafy[s] else { continue; }
        let mid = c.base + c.along * (c.size * 0.5);
        guard c.base.z > w.house + WALL_GAP && mid.z - c.size > w.house + WALL_GAP else { continue; }
        let cast = casts(v, mid, c.size);
        guard !cull || cast || seen(sight, mid, c.size) else { continue; }
        var kept = c;
        kept.segment = segment_to[s];
        t.cards[wc] = kept;
        wc++;
        if cast && on_holes(v, on_map(v, mid), c.size) {
            let across = cross(c.face, c.along);
            keep_leaf(t, Leaf { mid, c.size, map_dir(v, c.along) * (c.size * 0.5), map_dir(v, across) * (c.width * 0.5), c.kind });
        }
    }
    t.cards.resize(wc);
}

// The whole reshaped tree `all` (grow_whole without culling) culled into t as grow_whole
// with `cull` would grow it, without growing and reshaping it again.
fn cull_copy(all: Tree&, t: Tree&, w: Whole, v: View, sight: Sight) {
    t.segments.clear();
    t.limbs.clear();
    t.cards.clear();
    t.leaves.clear();
    t.limb_shed.clear();
    t.left_out = all.left_out;
    t.segments.append(all.segments[..]);
    t.limbs.append(all.limbs[..]);
    t.cards.append(all.cards[..]);
    var wh = w;
    var vw = v;
    var sg = sight;
    keep_parts(t, wh, vw, sg, true);
}
