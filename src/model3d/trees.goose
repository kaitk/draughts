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

// A leaf as its shadow falls: its middle, and as an ellipse on the map, its turn
// (radians), length and width.
struct Leaf { at: float3, angle: f32, length: f32, width: f32 }

// Filled at setup only, as the room is put on: `var t = trees::Tree { .. };`.
root struct Tree {
    segments: Segment[>..] = [],    // at most MAX_SEGMENTS
    leaves:   Leaf[>..]    = [],    // at most MAX_LEAVES
    left_out: i64          = 0,     // parts past those counts
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
}

// How the sun sees the tree, and the map's square: the key's slant past the wall's normal
// (a point at depth z falls on the map z × shear from its own x and y), the map's middle
// and side in the tree's frame, the ray's length from the board's middle to the trunk's
// plane, how squarely the key meets the wall (the cosine), and how wide the sun's disc is
// (radians across, with the room's softness); and the house's wall, its depth in the
// tree's frame, which nothing of the tree comes nearer than WALL_GAP.
struct View {
    shear:    float2,
    middle:   float2,
    span:     f32,
    distance: f32,
    toward:   f32,
    blur:     f32,
    wall:     f32,
}

let WALL_GAP: f32 = 6.0;

// Whether a point of the tree is clear of the house.
fn clear_of_wall(v: View&, p: float3) -> bool { p.z > v.wall + WALL_GAP }

// The map's texels a side, and its levels down to one texel.
let SIDE = 512;
let MIPS = 10;

// The map's bytes, RGBA8, every level one after another.
fn map_bytes() -> i64 {
    var n = 0;
    for level in MIPS {
        let s = SIDE >> level;
        n += s * s * 4;
    }
    return n;
}

// A point of the tree as it falls on the map.
fn on_map(v: View&, p: float3) -> float2 { float2 { p.x - v.shear.x * p.z, p.y - v.shear.y * p.z } }

// How far apart two points of the tree may fall on the map for every unit between them.
fn spread(v: View&) -> f32 { sqrt(1.0 + v.shear.x * v.shear.x + v.shear.y * v.shear.y) }

// Whether a shape at `m` reaching `r` round it falls on the map.
fn on_square(v: View&, m: float2, r: f32) -> bool {
    let h = v.span * 0.5 + r;
    return abs(m.x - v.middle.x) <= h && abs(m.y - v.middle.y) <= h;
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

// Per level (the fine twigs last): segments a branch, children it sprouts, where along it
// they start, their angle off it (degrees), their length against it, the radius at its tip
// against its foot, how crooked (times Spec.crooked), how much it turns up a segment, how
// much more it hangs (times Spec.hang), and leaves (times Spec.leafy).
let SEGMENTS_OF: i64[5] = [8, 6, 4, 3, 2];
let CHILDREN_OF: i64[5] = [9, 7, 7, 6, 0];
let START_OF:    f32[5] = [0.35, 0.15, 0.15, 0.2, 0.0];
let ANGLE_OF:    f32[5] = [58.0, 42.0, 45.0, 40.0, 0.0];
let RATIO_OF:    f32[5] = [0.55, 0.5, 0.42, 0.42, 0.0];
let TIP_OF:      f32[5] = [0.35, 0.25, 0.3, 0.35, 0.4];
let CROOK_OF:    f32[5] = [0.06, 0.35, 0.4, 0.35, 0.3];
let RISE_OF:     f32[5] = [0.0, 0.07, 0.04, 0.02, 0.0];
let HANG_OF:     f32[5] = [0.0, 0.02, 0.06, 0.2, 0.3];
let LEAVES_OF:   f32[5] = [0.0, 0.0, 0.0, 8.0, 22.0];

// How far a branch's offspring reach against its length (the ratios summed, and a bend).
let REACH = 1.8;

struct Branch { at: float3, dir: float3, length: f32, radius: f32, level: i64, dice: u64 }

// The tree grown from s, kept where it falls on v's map.
fn grow(t: Tree&, s: Spec, v: View) {
    t.segments.clear();
    t.leaves.clear();
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
    let segments = SEGMENTS_OF[level];
    let step = b.length / segments;
    let tip = TIP_OF[level];
    let sway = s.crooked * CROOK_OF[level];
    let rise = RISE_OF[level] - s.hang * HANG_OF[level];
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
        if on_square(v, middle, length(float2 { mb.x - ma.x, mb.y - ma.y }) * 0.5 + ra) {
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
    if level >= 3 && s.leafy > 0.0 {
        var leaf_dice = Dice { mixed(b.dice ^ 0x5DEECE66D) };
        add_leaves(t, s, v, leaf_dice, points, n, level);
    }
    guard level < LEVELS - 1 else { return; }
    let count = CHILDREN_OF[level];
    let start = START_OF[level];
    let first_round = roll(d) * TAU;
    for c in count {
        let f = start + (1.0 - start) * (c + roll_between(d, 0.2, 0.8)) / count;
        let at = f * n;
        let i = min(floor(at) as i64, n - 1);
        let w = at - i;
        let foot = points[i] + (points[i + 1] - points[i]) * w;
        let along = normalize(dirs[i + 1]);
        let tilt = radians(ANGLE_OF[level] + roll_between(d, -12.0, 12.0));
        let round = first_round + c * 2.39996 + roll_between(d, -0.3, 0.3);
        // The limbs longest low on the trunk, every child shorter toward its parent's tip.
        let shape: f32 = if level == 0 { 1.0 - 0.55 * (f - start) / (1.0 - start) } else { 1.0 - 0.5 * f };
        let child_length = b.length * RATIO_OF[level] * shape * roll_between(d, 0.8, 1.15);
        let radius_there = b.radius * (1.0 + (tip - 1.0) * f * n / segments);
        let child_radius = max(radius_there * pow(child_length / b.length, 0.9 as f32), 0.04);
        let child = Branch { foot, turned(along, tilt, round), child_length, child_radius, level + 1,
                             mixed(b.dice ^ ((c + 1) as u64 * 0x9E3779B97F4A7C15)) };
        // Left out where nothing it grows can fall on the map.
        guard clear_of_wall(v, foot) && on_square(v, on_map(v, foot), (child_length * REACH + s.leaf * 2.0) * k) else {
            continue;
        }
        grow_branch(t, s, v, child);
    }
}

// The leaves along a twig's outer part and clustered at its tip, each on a short stalk
// out from it, as many as Spec.leafy says.
fn add_leaves(t: Tree&, s: Spec&, v: View&, d: Dice&, points: float3[9]&, n: i64, level: i64) {
    let want = LEAVES_OF[level] * s.leafy;
    var count = floor(want) as i64;
    if roll(d) < want - count { count++; }
    for j in count {
        // Along the outer four fifths, a little more toward the tip.
        let f = 1.0 - 0.8 * roll(d) * (0.5 + 0.5 * roll(d));
        let at = f * n;
        let i = min(floor(at) as i64, n - 1);
        let foot = points[i] + (points[i + 1] - points[i]) * (at - i);
        let out = normalize(roll_ball(d) + float3 { 0.0, -0.3 * s.hang, 0.0 });
        let length = s.leaf * roll_between(d, 0.75, 1.2);
        let middle = foot + out * (length * 0.9);
        let m = on_map(v, middle);
        guard clear_of_wall(v, middle) && on_square(v, m, length) else { continue; }
        // Turned along its stalk as the sun sees it, foreshortened by its tilt.
        let mo = on_map(v, middle + out);
        let angle = atan2(mo.y - m.y, mo.x - m.x) + roll_between(d, -0.5, 0.5);
        let width = length * s.leaf_width * roll_between(d, 0.45, 1.0);
        if t.leaves.len < MAX_LEAVES {
            t.leaves.push(Leaf { middle, angle, length, width });
        } else {
            t.left_out++;
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

fn depths(t: Tree&) -> Depths {
    var lo: f32 = 1e9;
    var hi: f32 = -1e9;
    for &sg in t.segments {
        guard sg.level > 1 else { continue; }
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
// RGBA8 at SIDE texels a side and then its mips (map_bytes() in all) into `out`.
fn draw_map(t: Tree&, s: Spec, v: View, out: u8[>..]&) {
    out.clear();
    out.resize(map_bytes(), 255);
    var plane: f32[>..] = [];
    plane.resize(SIDE * SIDE, 1.0);
    var sums: f32[>..] = [];
    var sp = s;
    var vw = v;
    let depth = depths(t);
    // Each layer's mean depth, for its blur.
    var z_sum:   f32[4] = [0.0; 4];
    var z_count: f32[4] = [0.0; 4];
    for &sg in t.segments {
        let l = layer_of_segment(sg, depth);
        z_sum[l] += (sg.a.z + sg.b.z) * 0.5;
        z_count[l] += 1.0;
    }
    for &lf in t.leaves {
        let l = layer_of_depth(lf.at.z, depth);
        z_sum[l] += lf.at.z;
        z_count[l] += 1.0;
    }
    let texel = vw.span / SIDE;
    for layer in 4 {
        for i in plane.len { plane[i] = 1.0; }
        for &sg in t.segments {
            guard layer_of_segment(sg, depth) == layer else { continue; }
            draw_segment(plane, vw, sg);
        }
        for &lf in t.leaves {
            guard layer_of_depth(lf.at.z, depth) == layer else { continue; }
            draw_leaf(plane, vw, lf, 1.0 - sp.leaf_light);
        }
        let z = if z_count[layer] > 0.0 { z_sum[layer] / z_count[layer] } else { 0.0 };
        let across = max(vw.distance + z / vw.toward, 1.0) * vw.blur;
        blur_disc(plane, sums, vw, across * 0.5 / texel);
        for i in SIDE * SIDE {
            out[i * 4 + layer] = (clamp(plane[i], 0.0, 1.0) * 255.0 + 0.5) as u8;
        }
    }
    shrink_levels(out);
}

// The texel's middle in the tree's frame.
fn texel_x(v: View&, i: i64) -> f32 { v.middle.x - v.span * 0.5 + (i + 0.5) * v.span / SIDE }
fn texel_y(v: View&, j: i64) -> f32 { v.middle.y - v.span * 0.5 + (j + 0.5) * v.span / SIDE }

// The texels a shape over x0..x1, y0..y1 (the tree's frame) touches, clamped to the map.
fn texel_range(v: View&, lo: f32, hi: f32, middle: f32) -> i64, i64 {
    let k = SIDE / v.span;
    let a = floor((lo - (middle - v.span * 0.5)) * k) as i64;
    let b = ceil((hi - (middle - v.span * 0.5)) * k) as i64;
    return clamp(a, 0, SIDE), clamp(b, 0, SIDE);
}

// A branch's segment, a tapered capsule as the sun sees it (its width unchanged by the
// slant), its coverage antialiased over a texel, a twig thinner than one drawn fainter.
fn draw_segment(plane: f32[>..]&, v: View&, sg: Segment&) {
    let a = on_map(v, sg.a);
    let b = on_map(v, sg.b);
    let r = max(sg.ra, sg.rb);
    let texel = v.span / SIDE;
    let x0, x1 = texel_range(v, min(a.x, b.x) - r - texel, max(a.x, b.x) + r + texel, v.middle.x);
    let y0, y1 = texel_range(v, min(a.y, b.y) - r - texel, max(a.y, b.y) + r + texel, v.middle.y);
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
            let rr = sg.ra + (sg.rb - sg.ra) * h;
            let dist = sqrt(dx * dx + dy * dy);
            let cover = clamp(rr + texel * 0.5 - dist, 0.0, min(2.0 * rr, texel)) / texel;
            guard cover > 0.0 else { continue; }
            plane[j * SIDE + i] *= 1.0 - cover;
        }
    }
}

// A leaf, an ellipse, letting `blocks` of the sun's light stop where it covers.
fn draw_leaf(plane: f32[>..]&, v: View&, lf: Leaf&, blocks: f32) {
    let m = on_map(v, lf.at);
    let a = lf.length * 0.5;
    let b = max(lf.width * 0.5, 0.02);
    let texel = v.span / SIDE;
    let x0, x1 = texel_range(v, m.x - a - texel, m.x + a + texel, v.middle.x);
    let y0, y1 = texel_range(v, m.y - a - texel, m.y + a + texel, v.middle.y);
    let c = cos(lf.angle);
    let sn = sin(lf.angle);
    for j in y0..y1 {
        let y = texel_y(v, j) - m.y;
        for i in x0..x1 {
            let x = texel_x(v, i) - m.x;
            let u = (x * c + y * sn) / a;
            let w = (-x * sn + y * c) / b;
            let k0 = sqrt(u * u + w * w);
            // The distance to the edge to first order (Quilez).
            let gu = u / a;
            let gw = w / b;
            let k1 = max(sqrt(gu * gu + gw * gw), 1e-6);
            let dist = k0 * (k0 - 1.0) / k1;
            let cover = clamp(0.5 - dist / texel, 0.0, 1.0);
            guard cover > 0.0 else { continue; }
            plane[j * SIDE + i] *= 1.0 - blocks * cover;
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
    let row = SIDE + 2 * reach + 1;
    sums.clear();
    sums.resize(row * SIDE, 0.0);
    for j in SIDE {
        var run: f32 = 0.0;
        sums[j * row] = 0.0;
        for k in row - 1 {
            let i = clamp(k - reach, 0, SIDE - 1);
            run += plane[j * SIDE + i];
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
    for j in SIDE {
        for i in SIDE {
            var total: f32 = 0.0;
            for r, n in rows {
                let jj = clamp(j + r, 0, SIDE - 1);
                let base = jj * row;
                let lo = mids[n] - halves[n] + (i + reach) + 0.5;
                let hi = mids[n] + halves[n] + (i + reach) + 0.5;
                total += sum_at(sums, base, hi) - sum_at(sums, base, lo);
            }
            plane[j * SIDE + i] = total * scale;
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
fn shrink_levels(out: u8[>..]&) {
    var from = 0;
    var size = SIDE;
    for level in 1..MIPS {
        let to = from + size * size * 4;
        let half = size / 2;
        for y in half {
            for x in half {
                for c in 4 {
                    let a = out[from + ((2 * y) * size + 2 * x) * 4 + c] as i64;
                    let b = out[from + ((2 * y) * size + 2 * x + 1) * 4 + c] as i64;
                    let e = out[from + ((2 * y + 1) * size + 2 * x) * 4 + c] as i64;
                    let f = out[from + ((2 * y + 1) * size + 2 * x + 1) * 4 + c] as i64;
                    out[to + (y * half + x) * 4 + c] = ((a + b + e + f + 2) / 4) as u8;
                }
            }
        }
        from = to;
        size = half;
    }
}

// How much of the sun the map lets through on average (a layer, or all four multiplied),
// for the tests.
fn passing(out: u8[>..]&, layer: i64) -> f32 {
    var total: f32 = 0.0;
    for i in SIDE * SIDE {
        var v: f32 = 1.0;
        if layer >= 0 { v = out[i * 4 + layer] / 255.0; }
        else { for c in 4 { v *= out[i * 4 + c] / 255.0; } }
        total += v;
    }
    return total / (SIDE * SIDE);
}
