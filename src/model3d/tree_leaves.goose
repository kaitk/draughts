// The maple's leaves in plates at its shoot tips, tilted by season and height, and bent
// (task 117's step two, after build/notes/tree/leaves/): add_plates puts a twig's leaves
// on its current shoots in place of add_cards when Growth.plates asks, and leaf_shapes
// makes the bent blades' meshes the leaves' vertex shader reads (shaders::TREE_LEAF_VERT).
// Part of trees, in its namespace; at setup only, never in the frame loop.
//
// The evidence. Norway maple's leaves come in opposite pairs, each pair a quarter turn
// from the last; on a level shoot the lower leaf of a pair is larger and on the longer
// stalk, the outer leaf of a side pair longer than the inner (Weisse 1895), and the long
// stalks (5-20 cm) spread the blades into one layer (Niinemets 1996). The blades' tilt
// from level by height and season is Raabe et al. 2015's, from the data in Chianucci et al.
// 2018: the top of the crown flattest in summer, steeper as the leaves age. Nothing
// measures the blades' curvature in Norway maple; the bent shapes follow the photos and
// beech (Fleck et al. 2003): most flat, a few cupped up in the sun, more sagging in the
// shade, on big blades and in autumn.
namespace trees;
import std;
import vec;
import math;

// The blades' tilt from level, Norway maple at Tõravere (Chianucci et al. 2018's data),
// counted in 5° bins from 0 to 90°: the summer's (14 June and 1 August 2013) top, middle
// and bottom of the crown, 13 September 2013's, and the whole crown on 11 October 2011.
let TILT_BINS = 18;
let TILT_ROWS = 7;
let LEAF_TILTS: f32[126] = [
    35, 25, 39, 24, 31, 16, 13, 3, 4, 5, 1, 0, 0, 1, 0, 0, 0, 0,
    22, 18, 18, 24, 27, 21, 23, 17, 11, 4, 4, 4, 1, 0, 0, 0, 0, 0,
    17, 16, 19, 23, 24, 22, 13, 15, 8, 5, 6, 5, 4, 5, 0, 0, 0, 0,
    4, 11, 12, 15, 19, 8, 4, 11, 7, 2, 2, 5, 0, 0, 0, 0, 0, 0,
    7, 8, 8, 11, 15, 14, 11, 7, 3, 6, 3, 3, 1, 1, 0, 0, 2, 0,
    8, 8, 10, 10, 18, 11, 7, 4, 8, 8, 4, 2, 2, 0, 0, 0, 0, 0,
    1, 4, 2, 6, 6, 6, 10, 10, 14, 11, 7, 8, 6, 3, 2, 4, 0, 0,
];

// A blade's tilt from level (radians) drawn from the measurements of `season` (0 summer,
// 1 mid-September, 2 October; between, the two blended) at `height` in the crown (0 its
// bottom, 1 its top; the top, middle and bottom samples blended).
fn drawn_tilt(d: Dice&, season: f32, height: f32) -> f32 {
    let summer = clamp(1.0 - season, 0.0, 1.0);
    let october = clamp(season - 1.0, 0.0, 1.0);
    let september = 1.0 - summer - october;
    let top = clamp((height - 0.5) / 0.33, 0.0, 1.0);
    let bottom = clamp((0.5 - height) / 0.33, 0.0, 1.0);
    let middle = 1.0 - top - bottom;
    let weights: f32[7] = [summer * top, summer * middle, summer * bottom, september * top, september * middle,
                           september * bottom, october];
    var mass: f32[18] = [0.0; 18];
    var all:  f32     = 0.0;
    for r in TILT_ROWS {
        guard weights[r] > 0.0 else { continue; }
        var count: f32 = 0.0;
        for b in TILT_BINS { count += LEAF_TILTS[r * TILT_BINS + b]; }
        for b in TILT_BINS {
            let m = weights[r] * LEAF_TILTS[r * TILT_BINS + b] / count;
            mass[b] += m;
            all += m;
        }
    }
    var pick = roll(d) * all;
    var bin = TILT_BINS - 1;
    for b in TILT_BINS {
        if pick < mass[b] { bin = b; break; }
        pick -= mass[b];
    }
    return radians((bin + roll(d)) * 5.0);
}

// A leaf of a plate before its blade is placed (place_blade): where its stalk leaves the
// shoot, the blade's way out in plan (an angle about up; as grown and now), its stalk (as
// grown and now), the blade's length, how much its stalk rises past the plate's, its tilt
// from level and the way it tilts (an angle about up from the way out, 0 tip down), how
// deep in the crown, the segment it grows on; then the blade as placed.
struct PlateLeaf {
    node: float3, out0: f32, out: f32, stalk0: f32, stalk: f32, size: f32, lift: f32, tilt: f32, tilt_way: f32,
    deep: f32, segment: i32, base: float3, along: float3, face: float3,
}

// A twig's short shoots beside its tip's at most, so a plate holds (2 + MOST_SPURS) pairs.
let MOST_SPURS = 6;
let MOST_PLATE_LEAVES = 16;

// The mosaic's steps (nudge_apart) and how far a blade may turn from where it grew.
let NUDGE_STEPS = 16;
let MOST_TILT:  f32 = 1.536;   // 88°
let NUDGE_TURN: f32 = 0.61;     // 35°

// v turned by `angle` about the unit `axis` (Rodrigues).
fn about(v: float3, axis: float3, angle: f32) -> float3 {
    let c = cos(angle);
    let s = sin(angle);
    return v * c + cross(axis, v) * s + axis * (dot(axis, v) * (1.0 - c));
}

// A leaf's blade where its stalk puts it: out from the node along its way in plan and up,
// level, then tilted from level by its tilt toward its tilt's way.
fn place_blade(l: PlateLeaf&) {
    let up = float3 { 0.0, 1.0, 0.0 };
    let out = float3 { cos(l.out), 0.0, sin(l.out) };
    l.base = l.node + out * (l.stalk * 0.92) + up * (l.stalk * (0.22 + l.lift));
    let down_way = about(out, up, l.tilt_way);
    l.face = up * cos(l.tilt) + down_way * sin(l.tilt);
    let along = out - l.face * dot(out, l.face);
    let al = length(along);
    l.along = if al > 1e-3 { along / al } else { cross(l.face, float3 { -out.z, 0.0, out.x }) };
}

// A pair of leaves at a node of a shoot going `shoot`, one either side at `round` about
// it (Weisse 1895's ratios, softened as the study's: the lower leaf larger on the longer
// stalk, the outer of a side pair, away from the crown's middle, on the longer stalk); the
// tip's pair smaller, the pair below it on longer stalks. Added to `leaves`.
fn plate_pair(leaves: PlateLeaf[..16]&, d: Dice&, w: Whole&, node: float3, shoot: float3, round: f32, out_of_crown: float3,
              tip_pair: bool, lower_pair: bool, deep: f32, height: f32, segment: i32) {
    let up = float3 { 0.0, 1.0, 0.0 };
    let g = w.growth;
    let across = turned(shoot, PI * 0.5, round);
    let outward = out_of_crown - shoot * dot(out_of_crown, shoot);
    for k in 2 {
        let side = if k == 0 { across } else { across * -1.0 };
        let level_pair = abs(side.y) < 0.5;
        let outer: f32 = if !level_pair { 0.0 } else if dot(side, outward) > 0.0 { 1.0 } else { -1.0 };
        let stalk_share = 1.0 + 0.45 * -side.y + 0.15 * outer;
        let size = w.leaf * roll_between(d, 0.85, 1.12) * (1.0 + 0.22 * -side.y) * (if tip_pair { 0.85 } else { 1.0 })
                   * (1.0 + 0.25 * deep);
        let stalk = size * roll_between(d, 0.75, 1.05) * stalk_share * (if lower_pair { 1.15 } else { 1.0 });
        var out = side * 0.75 + shoot * (if tip_pair { 0.9 } else { 0.35 });
        out = float3 { out.x, 0.0, out.z };
        if length(out) < 1e-3 { out = float3 { shoot.x, 0.0, shoot.z }; }
        let tilt = if g.tilt.x > 0.0 { drawn_tilt(d, g.tilt.y, height) + radians(g.tilt.z) * (0.6 * deep + 0.4 * (1.0 - height)) }
                   else { radians(roll_between(d, 0.0, 5.0)) };
        let tilt_way = if roll(d) < 0.5 { 0.0 } else { roll_between(d, -PI, PI) };
        let angle = atan2(out.z, out.x);
        guard leaves.len < MOST_PLATE_LEAVES else { return; }
        leaves.push(PlateLeaf { node, angle, angle, stalk, stalk, size, 0.25 * side.y, min(tilt, MOST_TILT), tilt_way, deep,
                                segment, node, up, up });
        place_blade(leaves[leaves.len - 1]);
    }
}

// The study's mosaic: each blade turns about its node (within NUDGE_TURN of where it grew)
// and its stalk lengthens or shortens (0.7..1.5 of its own) away from the blades it covers
// in plan or is covered by, the lower one moving more (it is in the other's shade);
// `strength` 1 the study's steps.
fn nudge_apart(leaves: PlateLeaf[..16]&, strength: f32) {
    let n = leaves.len;
    for step in NUDGE_STEPS {
        var push: float2[16] = [float2 { 0.0, 0.0 }; 16];
        var moved = false;
        for i in n {
            let a .= leaves[i];
            let ca = a.base + a.along * (a.size * 0.42);
            for j in i + 1..n {
                let b .= leaves[j];
                let cb = b.base + b.along * (b.size * 0.42);
                let dv = float2 { ca.x - cb.x, ca.z - cb.z };
                let dist = length(dv) + 1e-6;
                let over = (a.size + b.size) * 0.5 - dist;
                guard over > 0.0 else { continue; }
                let share: f32 = if ca.y < cb.y { 0.7 } else { 0.3 };
                push[i] = push[i] + dv * (over * share / dist);
                push[j] = push[j] - dv * (over * (1.0 - share) / dist);
                moved = true;
            }
        }
        guard moved else { return; }
        for i in n {
            let l .= leaves[i];
            let p = push[i] * strength;
            guard p.x != 0.0 || p.y != 0.0 else { continue; }
            let out = float2 { cos(l.out), sin(l.out) };
            let tangent = float2 { -out.y, out.x };
            let lever = l.stalk + l.size * 0.42;
            var turn = l.out + 0.5 * dot(p, tangent) / lever - l.out0;
            turn = turn - TAU * floor((turn + PI) / TAU);
            l.out = l.out0 + clamp(turn, -NUDGE_TURN, NUDGE_TURN);
            l.stalk = clamp(l.stalk + 0.5 * dot(p, out), l.stalk0 * 0.7, l.stalk0 * 1.5);
            place_blade(l);
        }
    }
}

// The bent blades (leaf_shapes, Card.shape): flat, cupped up, the midrib drooping, the
// edges down (tented lobes), the lobe tips bent down, and sagging (twisted per leaf).
let LEAF_SHAPES = 6;
let SHAPE_FLAT = 0;
let SHAPE_CUP = 1;
let SHAPE_SAG_TWIST = 5;

// A leaf's bent shape (Growth.bend): cupped up by chance 0.1 + 0.1 × its exposure, one of the
// four sagging shapes by 0.15 + 0.15 × autumn (its tint past gold) + 0.25 × (its size against
// the species' less 1) + 0.2 × shade, both times Growth.bend.x; else flat. Its amount 0.3..1,
// its twist a little either way, the sagging and twisted shape's far.
fn chosen_shape(d: Dice&, g: Growth, size_share: f32, deep: f32, tint: f32) -> i32, f32, f32 {
    let cup = (0.1 + 0.1 * (1.0 - deep)) * g.bend.x;
    let sag = max(0.15 + 0.15 * clamp(tint - 1.0, 0.0, 1.0) + 0.25 * (size_share - 1.0) + 0.2 * deep, 0.0) * g.bend.x;
    let r = roll(d);
    let amount = roll_between(d, 0.3, 1.0);
    let sign: f32 = if roll(d) < 0.5 { -1.0 } else { 1.0 };
    let twist = sign * roll_between(d, 0.0, 0.25);
    if r < cup { return SHAPE_CUP, amount, twist; }
    if r < cup + sag {
        let shape = 2 + min((roll(d) * 4.0) as i64, 3);
        let far = if shape == SHAPE_SAG_TWIST { sign * roll_between(d, 0.6, 1.0) * amount } else { twist };
        return shape as i32, amount, far;
    }
    return SHAPE_FLAT, 0.0, 0.0;
}

// A twig's leaves on its current shoots (Growth.plates): its tip's shoot, with the tip's
// pair and one pair a quarter turn below it, and Growth.plates.y short shoots along its outer
// part, each with one pair at its end; on stalks that spread the blades into one layer
// (plate_pair), nudged apart in plan by Growth.plates.z, tilted by Growth.tilt, bent by
// Growth.bend. None deep in the crown; Whole.leafy of the pairs, as add_cards.
fn add_plates(t: Tree&, w: Whole&, v: View&, sight: Sight&, cull: bool, d: Dice&, points: float3[13]&, dirs: float3[13]&,
              n: i64, tint: f32, free: bool, first: i64) {
    let g = w.growth;
    var bend_dice = Dice { mixed(d.state ^ 0x6C8E9CF570932BD5) };
    let up = float3 { 0.0, 1.0, 0.0 };
    let middle = w.foot + w.middle;
    let height_share = clamp((points[n].y - w.foot.y) / w.height, 0.0, 1.0);
    let outer_share = clamp(crown_radius(w, points[n]), 0.0, 1.1);
    let twig_tint = clamp(tint + 1.6 * (outer_share - 0.85) + 0.6 * (height_share - 0.5) + roll_between(d, -0.12, 0.12), 0.0, 2.0);
    let first_round = roll(d) * TAU;
    var leaves: PlateLeaf[..16] = [];
    // The tip's shoot, its lower pair 4.5 cm below the tip.
    let shoot = normalize(dirs[n]);
    let tip = points[n];
    let below = tip - shoot * min(0.045 * surfaces::METRE, length(points[n] - points[n - 1]) * 0.9);
    let spurs = clamp(g.plates.y as i64, 0, MOST_SPURS);
    for node in 2 + spurs {
        var at = tip;
        var way = shoot;
        var round = first_round;
        var segment = (first + n - 1) as i32;
        let on_tip = node < 2;
        if node == 1 {
            at = below;
            round = first_round + PI * 0.5;
        }
        if !on_tip {
            // A short shoot from the twig's outer part, lying flat, its pair at its end.
            let j = node - 2;
            let f = (0.3 + 0.55 * (j + 0.5) / spurs) * n;
            let i = min(floor(f) as i64, n - 1);
            let twig = normalize(dirs[i + 1]);
            var side = turned(twig, PI * 0.5, first_round + j * (PI * 0.5) + roll_between(d, -0.3, 0.3));
            side = normalize(float3 { side.x, side.y * 0.3, side.z });
            way = normalize(twig * 0.6 + side * 0.8 + up * 0.08);
            at = points[i] + (points[i + 1] - points[i]) * (f - i) + way * (roll_between(d, 0.02, 0.05) * surfaces::METRE);
            round = roll(d) * TAU;
            segment = (first + i) as i32;
        }
        guard free || crown_depth(w, at) < w.shell else { continue; }
        guard w.leafy >= 1.0 || roll(d) < w.leafy else { continue; }
        let deep = if free { 0.3 } else { clamp(crown_depth(w, at) / max(w.shell, 1.0), 0.0, 1.0) };
        let crown_height = clamp((at.y - (middle.y - w.crown.y)) / (2.0 * w.crown.y), 0.0, 1.0);
        let out_of_crown = normalize(at - middle);
        plate_pair(leaves, d, w, at, way, round, out_of_crown, node == 0, node == 1, deep, crown_height, segment);
    }
    if g.plates.z > 0.0 { nudge_apart(leaves, g.plates.z); }
    for &l in leaves {
        let width = l.size * roll_between(d, 1.05, 1.25);
        let kind = min((roll(d) * LEAF_KINDS) as i64, LEAF_KINDS - 1);
        let leaf_tint = clamp(twig_tint + roll_between(d, -0.08, 0.08), 0.0, 2.0);
        let mid = l.base + l.along * (l.size * 0.5);
        guard l.base.z > w.house + WALL_GAP && mid.z - l.size > w.house + WALL_GAP else { continue; }
        var shape:  i32 = SHAPE_FLAT;
        var amount: f32 = 0.0;
        var twist:  f32 = 0.0;
        if g.bend.x > 0.0 {
            let s, a, tw = chosen_shape(bend_dice, g, l.size / w.leaf, l.deep, leaf_tint);
            shape = s;
            amount = a;
            twist = tw * radians(g.bend.y);
        }
        let cast = casts(v, mid, l.size);
        guard !cull || cast || seen(sight, mid, l.size) else { continue; }
        if t.cards.len < MAX_CARDS {
            t.cards.push(Card { l.node, l.base, l.along, l.face, l.size, width, kind as i32, leaf_tint, l.segment, shape, amount, twist });
        } else {
            t.left_out++;
        }
        if cast && on_holes(v, on_map(v, mid), l.size) {
            let across = cross(l.face, l.along);
            keep_leaf(t, Leaf { mid, l.size, map_dir(v, l.along) * (l.size * 0.5), map_dir(v, across) * (width * 0.5), kind as i32 });
        }
    }
}

// The bent blades as the leaves' vertex shader reads them (shaders::TREE_LEAF_VERT), put
// before the cards in their buffer (leaf_cards' `at`): each vertex two float4s, the bent
// point in the leaf's frame (x across in the card's half widths, y along and z out of its
// face in blade lengths) with the flat point's x, then the bent normal with the flat point's
// y (the atlas's texel). As triangle lists, so the shader draws without an index buffer:
// first the card in LEAF_ROWS rows (the standard tier: bent along its midrib alone, by its
// lobes' mean), LEAF_SHAPES shapes of LEAF_ROW_VERTICES; then for each of the atlas's
// leaves a fan hugging its outline (the high tier: one ray along each lobe, one down the
// stalk, two between, out in two rings, and a strip for the stalk's top), LEAF_SHAPES
// shapes of LEAF_FAN_VERTICES. The card's 27 % of its area is blade, the fan's 45 %.
let LEAF_ROWS = 4;
let LEAF_ROW_VERTICES = 24;     // 10 vertices, 8 triangles
let LEAF_SPOKES = 8;
let LEAF_FAN_VERTICES = 78;     // 21 vertices, 26 triangles
let LEAF_ROW_VEC4S = LEAF_SHAPES * LEAF_ROW_VERTICES * 2;
let LEAF_SHAPE_VEC4S = LEAF_ROW_VEC4S + LEAF_KINDS * LEAF_SHAPES * LEAF_FAN_VERTICES * 2;

// The shapes' angles at the lobes' tips (degrees: the middle lobe, the two big ones, the two
// small ones; up toward the face positive), where along a lobe the turn starts, how it
// grows along it (a power), and the curl across each lobe's vein (edges up positive): the
// study's variants (build/notes/tree/leaves/src/leaf.py), the sagging one's twist per leaf.
let SHAPE_TIPS: f32[30] = [
    0.0, 0.0, 0.0, 0.0, 0.0,
    14.0, 20.0, 20.0, 22.0, 22.0,
    -38.0, -12.0, -12.0, -4.0, -4.0,
    -10.0, -28.0, -28.0, -34.0, -34.0,
    -30.0, -35.0, -14.0, -40.0, -8.0,
    -30.0, -24.0, -30.0, -30.0, -26.0,
];
let SHAPE_START:  f32[6] = [0.0, 0.0, 0.0, 0.0, 0.55, 0.0];
let SHAPE_POWER:  f32[6] = [2.0, 1.6, 1.8, 2.0, 1.5, 1.8];
let SHAPE_CURL:   f32[6] = [0.0, 0.1, 0.0, -0.22, 0.0, -0.15];
let LOBE_ANGLES:  f32[5] = [0.0, 56.0, -56.0, 110.0, -110.0];
let LOBE_LENGTHS: f32[5] = [1.0, 0.9, 0.9, 0.56, 0.56];
let BEND_STEPS = 24;

// The angle from b to a, -π..π.
fn angle_between(a: f32, b: f32) -> f32 {
    let x = a - b;
    return x - TAU * floor((x + PI) / TAU);
}

// The arc a ray from the foot bends along: how far out and how far up its point at `r` lies,
// the ray turning by `tip` radians at its lobe's tip `length` out, from `start` of it on.
fn arc_point(r: f32, length: f32, tip: f32, start: f32, power: f32) -> float2 {
    var out:  f32 = 0.0;
    var rise: f32 = 0.0;
    let ds = r / BEND_STEPS;
    for k in 1..BEND_STEPS + 1 {
        let s = ds * k;
        let u = max((s / length - start) / max(1.0 - start, 1e-3), 0.0);
        let a = tip * pow(u, power);
        out += cos(a) * ds;
        rise += sin(a) * ds;
    }
    return float2 { out, rise };
}

// A point (x, y) of the leaf's frame bent into `shape` (the fan's bend): every point lies on a
// ray from the foot, which bends as an arc to its lobes' angle (each lobe's weight by how near
// its vein the ray runs), plus the curl across the nearest lobe's vein. The stalk stays flat.
fn bent_point(p: float2, shape: i64) -> float3 {
    let stalk = abs(p.x) < 0.06 && p.y < -0.02;
    guard shape != SHAPE_FLAT && !stalk else { return float3 { p.x, p.y, 0.0 }; }
    let r = length(p);
    guard r > 1e-5 else { return float3_0; }
    let phi = atan2(p.x, p.y);
    let sigma: f32 = 0.419;     // 24°
    var weight_sum: f32 = 0.0;
    var amp:        f32 = 0.0;
    var length_sum: f32 = 0.0;
    var nearest = 0;
    var best: f32 = -1.0;
    for j in 5 {
        let off = angle_between(phi, radians(LOBE_ANGLES[j])) / sigma;
        let wj = exp(-off * off);
        weight_sum += wj;
        amp += wj * radians(SHAPE_TIPS[shape * 5 + j]);
        length_sum += wj * LOBE_LENGTHS[j];
        if wj > best { best = wj; nearest = j; }
    }
    amp /= max(weight_sum, 0.35);
    let lobe_length = length_sum / (weight_sum + 1e-6);
    let arc = arc_point(r, lobe_length, amp, SHAPE_START[shape], SHAPE_POWER[shape]);
    var z = arc.y;
    let vein = radians(LOBE_ANGLES[nearest]);
    let off_vein = sin(phi - vein) * r;
    let along_vein = clamp(cos(phi - vein) * r / LOBE_LENGTHS[nearest], 0.0, 1.0);
    z += SHAPE_CURL[shape] * off_vein * off_vein * along_vein * 4.0;
    return float3 { sin(phi) * arc.x, cos(phi) * arc.x, z };
}

// The card's bend: the blade along its midrib alone, by its lobes' mean angle; below the foot
// flat.
fn bent_row_point(p: float2, shape: i64) -> float3 {
    guard shape != SHAPE_FLAT && p.y > 0.0 else { return float3 { p.x, p.y, 0.0 }; }
    var amp: f32 = 0.0;
    for j in 5 { amp += radians(SHAPE_TIPS[shape * 5 + j]) / 5.0; }
    let arc = arc_point(p.y, 1.0, amp, SHAPE_START[shape], SHAPE_POWER[shape]);
    return float3 { p.x, arc.x, arc.y };
}

// The normal of the bent surface at p, from its differences across and along.
fn bent_normal(p: float2, shape: i64, rows: bool) -> float3 {
    let e: f32 = 0.01;
    let a = if rows { bent_row_point(p, shape) } else { bent_point(p, shape) };
    let bx = if rows { bent_row_point(p + float2 { e, 0.0 }, shape) } else { bent_point(p + float2 { e, 0.0 }, shape) };
    let by = if rows { bent_row_point(p + float2 { 0.0, e }, shape) } else { bent_point(p + float2 { 0.0, e }, shape) };
    let n = cross(bx - a, by - a);
    let l = length(n);
    guard l > 1e-9 else { return float3 { 0.0, 0.0, 1.0 }; }
    return n / l;
}

// How far out from the foot leaf k's blade reaches in the wedge of `half` either side of the
// ray at `angle` (from the midrib, toward +x), a straight edge across the wedge outside it.
fn outline_reach(lf: leaf_atlas::Leaf&, angle: f32, half: f32) -> f32 {
    var most: f32 = 0.05;
    let rays = 9;
    for k in rays {
        let a = angle - half + 2.0 * half * k / (rays - 1);
        let dir = float2 { sin(a), cos(a) };
        var r: f32 = 0.01;
        while r < 1.4 {
            if leaf_atlas::inside(lf, dir * r) > -0.004 { most = max(most, r); }
            r += 0.005;
        }
    }
    return most / cos(half) + 0.04;
}

// The fan's rays for leaf k: one along each lobe, one down the stalk, then the widest gaps
// halved, sorted round from -π.
fn fan_spokes(lf: leaf_atlas::Leaf&) -> f32[8] {
    var a: f32[..8] = [];
    for j in 5 { a.push(atan2(lf.lobes[j].dir.x, lf.lobes[j].dir.y)); }
    a.push(PI);
    while a.len < LEAF_SPOKES {
        sort(a) { x, y => x < y };
        var widest = 0;
        var gap: f32 = 0.0;
        for k in a.len {
            let next = if k + 1 < a.len { a[k + 1] } else { a[0] + TAU };
            if next - a[k] > gap { gap = next - a[k]; widest = k; }
        }
        var mid = a[widest] + gap * 0.5;
        if mid > PI { mid -= TAU; }
        a.push(mid);
    }
    sort(a) { x, y => x < y };
    var out: f32[8] = [0.0; 8];
    for k in LEAF_SPOKES { out[k] = a[k]; }
    return out;
}

// One vertex of a shape into `out`: the bent point with the flat x, the normal with the flat y.
fn put_shape_vertex(out: float4[>..]&, p: float2, shape: i64, rows: bool) {
    let b = if rows { bent_row_point(p, shape) } else { bent_point(p, shape) };
    let n = bent_normal(p, shape, rows);
    out.push(float4 { b.x, b.y, b.z, p.x });
    out.push(float4 { n.x, n.y, n.z, p.y });
}

fn leaf_shapes(out: float4[>..]&) {
    out.clear();
    // The card in rows: across its full width, the rows' edges at its foot and up to its top.
    let ys: f32[5] = [leaf_atlas::QUAD.y, 0.0, leaf_atlas::QUAD.z / 3.0, leaf_atlas::QUAD.z * 2.0 / 3.0, leaf_atlas::QUAD.z];
    let x = leaf_atlas::QUAD.x;
    for shape in LEAF_SHAPES {
        for row in LEAF_ROWS {
            let a = float2 { -x, ys[row] };
            let b = float2 { x, ys[row] };
            let c = float2 { x, ys[row + 1] };
            let e = float2 { -x, ys[row + 1] };
            for p in [a, b, c, a, c, e] { put_shape_vertex(out, p, shape, true); }
        }
    }
    // Each leaf's fan.
    for kind in LEAF_KINDS {
        let lf = leaf_atlas::leaf_of(kind);
        let spokes = fan_spokes(lf);
        var reach: f32[8] = [0.0; 8];
        for k in LEAF_SPOKES { reach[k] = outline_reach(lf, spokes[k], PI / LEAF_SPOKES); }
        let stalk_end = float2 { lf.bend, leaf_atlas::QUAD.y };
        let stalk_half: f32 = 0.045;
        for shape in LEAF_SHAPES {
            for k in LEAF_SPOKES {
                let k1 = (k + 1) % LEAF_SPOKES;
                let a1 = float2 { sin(spokes[k]), cos(spokes[k]) } * (reach[k] * 0.5);
                let b1 = float2 { sin(spokes[k1]), cos(spokes[k1]) } * (reach[k1] * 0.5);
                let a2 = float2 { sin(spokes[k]), cos(spokes[k]) } * reach[k];
                let b2 = float2 { sin(spokes[k1]), cos(spokes[k1]) } * reach[k1];
                for p in [float2 { 0.0, 0.0 }, a1, b1, a1, a2, b2, a1, b2, b1] { put_shape_vertex(out, p, shape, false); }
            }
            let s0 = float2 { -stalk_half, 0.0 };
            let s1 = float2 { stalk_half, 0.0 };
            let s2 = stalk_end + float2 { stalk_half, 0.0 };
            let s3 = stalk_end - float2 { stalk_half, 0.0 };
            for p in [s0, s1, s2, s0, s2, s3] { put_shape_vertex(out, p, shape, false); }
        }
    }
}
