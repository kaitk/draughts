// The maple's tubes shaped where its wood meets (task 117's step three), in place of
// wood_mesh's plain tubes when WoodShape asks: more rings and sides by tier, a collar where a
// branch leaves its parent (it swells toward its foot, more underneath, after Shigo 1985),
// the parent's wood swelling round the branch's foot with a raised ridge in the crotch above
// it, the branch's foot laid with a fillet and welded a few millimetres under the parent's
// surface so the parent's mesh covers the seam, the parent's bark grain bent round each foot
// (the stream function of a flow past a cylinder), the wood darker in the crease, and each
// end closed by a rounded cap (a stub's woundwood). The trunk's foot flares into roots that
// dive into the lawn: its lowest rings are the level lines of the trunk and its roots as one
// surface, so no seam parts the trunk's grain from the roots'; the grain fans out along each
// root by the rings' arc length. Part of trees, in its namespace; made when the tree is
// grown, never in the frame loop. No vertex layout changes: a crease's shade goes into the
// light, the bark's age stays the radius.
namespace trees;
import std;
import vec;
import math;

let WOOD_HIGH = 0;
let WOOD_STANDARD = 1;
let WOOD_PHONE = 2;

// What the tubes are shaped with (render3d::tree_wood, the light tuner's --tree-junctions and
// --tree-roots), all off as made: the plain tubes of wood_mesh.
struct WoodShape {
    junctions: bool = false,
    roots:     bool = false,
    tier:      i64  = WOOD_HIGH,
}

fn wood_shaped(s: WoodShape) -> bool { s.junctions || s.roots }

// A number for the tree's geometry key (render3d::tree_geometry_key): the parts on and the tier.
fn wood_shape_key(s: WoodShape) -> f32 {
    guard wood_shaped(s) else { return 0.0; }
    return (if s.junctions { 1.0 } else { 0.0 }) + (if s.roots { 2.0 } else { 0.0 }) + 16.0 * (s.tier + 1);
}

// The bark's age from a radius (shaders::TREE_WOOD_FRAG): 0 at BARK_YOUNG_RADIUS, 1 at
// BARK_OLD_RADIUS, by the log; the scale and the log of the youngest, world units.
let BARK_YOUNG_RADIUS: f32 = 0.004;
let BARK_OLD_RADIUS:   f32 = 0.45;
fn bark_age_scale() -> f32 { 1.0 / log(BARK_OLD_RADIUS / BARK_YOUNG_RADIUS) }
fn bark_age_from() -> f32 { log(BARK_YOUNG_RADIUS * surfaces::METRE) }

// By tier (high, standard, phone): the sides round the trunk, a limb, a branch (tier × 3 +
// level), and round the trunk with roots; a ring every RING_STEP radii (tier × 3 + level, 0:
// the joints alone); round a junction of a branch at least FOOT_LEAST wide (world units) a
// ring every FOOT_STEP of the branch's radius; the roots and the flare's rings.
let SHAPED_SIDES: i64[9] = [48, 16, 6, 24, 10, 6, 12, 9, 6];
let ROOTED_SIDES: i64[3] = [72, 36, 12];
let RING_STEP:    f32[9] = [0.7, 1.5, 0.0, 1.2, 0.0, 0.0, 0.0, 0.0, 0.0];
let FOOT_STEP:    f32[3] = [0.35, 0.6, 0.0];
let FOOT_LEAST:   f32[3] = [2.0, 4.0, 1e9];
let ROOT_COUNT:   i64[3] = [6, 5, 0];
let FLARE_RINGS:  i64[3] = [26, 13, 0];
let MAX_STATIONS = 900;
let MAX_ROOTS = 8;

// The junction's shape: the collar's swell at the foot (a share of the radius, a branch under
// COLLAR_FULL of its parent's radius fully, none from COLLAR_NONE), its fall over COLLAR_FALL
// radii, its extra underneath; the parent's swell round the foot and its reach (radii of the
// branch), the crotch's ridge, the fillet's reach, the weld's depth under the parent (world
// units), the foot's length laid densely (radii), the crease's shade.
let COLLAR:       f32 = 0.22;
let COLLAR_FULL:  f32 = 0.55;
let COLLAR_NONE:  f32 = 0.95;
let COLLAR_FALL:  f32 = 1.2;
let COLLAR_UNDER: f32 = 0.3;
let SWELL:        f32 = 0.28;
let SWELL_REACH:  f32 = 1.1;
let RIDGE:        f32 = 0.1;
let RIDGE_WIDTH:  f32 = 0.25;
let FILLET:       f32 = 0.35;
let WELD:         f32 = 0.12;
let FOOT_LENGTH:  f32 = 2.5;
let CREASE_SHADE: f32 = 0.45;

// A branch's foot on its parent: where its axis starts, its way, its radius, the parent's radius
// there, how far along the parent (arc length from the parent's foot), the sine of its angle
// off the parent, its collar's swell; radius 0 for none.
struct Junction { foot: float3, dir: float3, radius: f32, parent_radius: f32, along: f32, sine: f32, collar: f32 }

// A root of the flare: its way round (radians), its radius at the trunk, how far it runs out
// before it is under the lawn, how high its buttress climbs the trunk, its curve.
struct Root { round: f32, radius: f32, reach: f32, rise: f32, curve: f32 }

// A ring of a shaped tube: its arc length from the foot, centre, radius, way and frame, the
// light through the crown there, and for the flare the height over the ground.
struct Station { s: f32, p: float3, r: f32, way: float3, side: float3, up: float3, lit: float2, flare: f32 }

// The arc length of l's joints from its foot.
fn joint_arcs(t: Tree&, l: Limb) -> f32[..14] {
    var arcs: f32[..14] = [];
    arcs.push(0.0);
    for i in l.count as i64 {
        let sg = t.segments[l.first as i64 + i];
        arcs.push(arcs[i] + length(sg.b - sg.a));
    }
    return arcs;
}

// The point, radius and way at arc length s along l (joints' arcs `arcs`).
fn chain_at(t: Tree&, l: Limb, arcs: f32[..14]&, s: f32) -> float3, f32, float3, i64, f32 {
    let n = l.count as i64;
    var i = 0;
    while i < n - 1 && arcs[i + 1] < s { i++; }
    let sg = t.segments[l.first as i64 + i];
    let span = max(arcs[i + 1] - arcs[i], 1e-6);
    let f = (s - arcs[i]) / span;
    let p = sg.a + (sg.b - sg.a) * f;
    let r = sg.ra + (sg.rb - sg.ra) * clamp(f, 0.0, 1.0);
    let way = normalize(joint_way(t, l, i) * (1.0 - clamp(f, 0.0, 1.0)) + joint_way(t, l, i + 1) * clamp(f, 0.0, 1.0));
    return p, r, way, i, clamp(f, 0.0, 1.0);
}

// Each tube limb's junction on its parent (junctions[limb]), and each limb's tube children
// (children[first[limb] .. first[limb + 1]]).
fn find_junctions(t: Tree&, junctions: Junction[>..]&, first: i32[>..]&, children: i32[>..]&) {
    let n = t.limbs.len;
    junctions.clear();
    junctions.resize(n, Junction { float3_0, float3_0, 0.0, 0.0, 0.0, 1.0, 0.0 });
    first.clear();
    first.resize(n + 1, 0);
    children.clear();
    for &l, li in t.limbs {
        guard l.level < TUBE_LEVELS && l.count > 0 && l.parent >= 0 && (l.parent as i64) < n else { continue; }
        let p = t.limbs[l.parent as i64];
        guard p.level < TUBE_LEVELS && p.count > 0 && l.attach >= p.first && l.attach < p.first + p.count else { continue; }
        let sg = t.segments[l.attach as i64];
        let foot = joint_at(t, l, 0);
        let axis = sg.b - sg.a;
        let f = clamp(dot(foot - sg.a, axis) / max(dot(axis, axis), 1e-9), 0.0, 1.0);
        let rp = sg.ra + (sg.rb - sg.ra) * f;
        let rc = joint_radius(t, l, 0);
        let arcs = joint_arcs(t, p);
        let along = arcs[(l.attach - p.first) as i64] + length(axis) * f;
        let dir = joint_way(t, l, 0);
        let sine = max(length(cross(dir, normalize(axis))), 0.35);
        let ratio = rc / max(rp, 1e-6);
        let collar = COLLAR * (1.0 - clamp((ratio - COLLAR_FULL) / (COLLAR_NONE - COLLAR_FULL), 0.0, 1.0));
        junctions[li] = Junction { foot, dir, rc, rp, along, sine, collar };
        first[l.parent as i64 + 1]++;
    }
    for k in 1..n + 1 { first[k] += first[k - 1]; }
    children.resize(first[n] as i64, 0);
    var filled: i32[>..] = [];
    filled.resize(n, 0);
    for &l, li in t.limbs {
        guard junctions[li].radius > 0.0 else { continue; }
        let pi = l.parent as i64;
        children[(first[pi] + filled[pi]) as i64] = li as i32;
        filled[pi]++;
    }
}

// How far the parent's surface rises round a branch's foot at q (along the parent's normal),
// the trunk collar's swell and the crotch's ridge above it; and how far q is from the
// branch's swollen surface (the crease's distance).
fn junction_swell(j: Junction&, q: float3, parent_way: float3) -> f32, f32 {
    let rel = q - j.foot;
    let along = max(dot(rel, j.dir), 0.0);
    let off = length(rel - j.dir * along);
    let rc = j.radius;
    let gap = off - rc * (1.0 + j.collar);
    let g = max(gap, 0.0) / (SWELL_REACH * rc);
    let swell = SWELL * (j.collar / COLLAR) * rc * exp(-g * g);
    let above = clamp((dot(normalize(rel), parent_way) - 0.1) / 0.5, 0.0, 1.0);
    let rd = (gap - 0.2 * rc) / (RIDGE_WIDTH * rc);
    let ridge = RIDGE * rc * exp(-rd * rd) * above * above * (3.0 - 2.0 * above);
    return swell + ridge, gap;
}

// The roots of the trunk l, on dice of its own: ROOT_COUNT by tier at uneven ways round, one
// slot left empty, each its own size, reach, buttress and curve (r0 the trunk's foot's radius).
fn trunk_roots(l: Limb, r0: f32, tier: i64, roots: Root[..8]&) {
    roots.clear();
    let count = ROOT_COUNT[tier];
    guard count > 0 else { return; }
    var d = Dice { mixed(l.first as u64 * 0x2545F4914F6CDD1D + 0x7007) };
    let slots = count + 1;
    let empty = (roll(d) * slots) as i64 % slots;
    let first_round = roll(d) * TAU;
    for k in slots {
        let jitter = roll_between(d, -0.35, 0.35);
        // Some roots strong, running out and climbing the trunk as buttresses; the others
        // short, gone under the lawn at once.
        let strong = roll(d) < 0.55;
        let radius = r0 * (if strong { roll_between(d, 0.24, 0.34) } else { roll_between(d, 0.14, 0.22) });
        let reach = 2.0 * r0 * (if strong { roll_between(d, 0.45, 0.85) } else { roll_between(d, 0.15, 0.35) });
        let rise = 2.0 * r0 * (if strong { roll_between(d, 0.25, 0.45) } else { roll_between(d, 0.08, 0.18) });
        let curve = roll_between(d, -0.3, 0.3);
        guard k != empty && roots.len < MAX_ROOTS else { continue; }
        roots.push(Root { first_round + (k + jitter) * TAU / slots, radius, reach, rise, curve });
    }
}

// How high root k's surface is over the ground at ρ from the trunk's axis, `round` the way
// round (radians), r0 the trunk's foot's radius: a buttress climbing the trunk, the root
// tapering and sinking under the lawn toward its reach, rounded across and meeting the lawn
// at a shallow slope, as if partly buried.
fn root_height(k: Root&, r0: f32, rho: f32, round: f32) -> f32 {
    let x = rho - r0;
    let centre = k.round + k.curve * max(x, 0.0) / r0 * 0.3;
    var off = round - centre;
    off -= TAU * floor(off / TAU + 0.5);
    guard abs(off) < 1.4 else { return -1.0; }
    let s = rho * sin(off);
    let out = max(x, 0.0);
    let buttress = k.rise * exp(-out / (0.6 * r0));
    let rr = k.radius * (1.0 - 0.5 * clamp(x / k.reach, 0.0, 1.4));
    let sink = clamp((x - 0.2 * k.reach) / (0.8 * k.reach), 0.0, 1.0);
    let top = buttress + rr * 1.1 - k.radius * 1.3 * sink * sink * (3.0 - 2.0 * sink);
    let half_width = rr * 1.2 + buttress * 0.3;
    let across = s / half_width;
    guard top > 0.0 && abs(across) < 1.0 else { return -1.0; }
    let bulge = 1.0 - across * across;
    return top * bulge * (1.5 - 0.5 * bulge);
}

// b over a by at least 0, eased in over k: a where b is under it, b - k/2 well over.
fn eased_over(a: f32, b: f32, k: f32) -> f32 {
    let d = max(b - a, 0.0);
    return a + (if d > k { d - 0.5 * k } else { d * d / (2.0 * k) });
}

// The trunk's radius with its roots at `round`, h over the ground (core its radius without):
// out along the way to where no root's surface is as high, the valleys between them filled.
fn rooted_radius(roots: Root[..8]&, r0: f32, core: f32, h: f32, round: f32) -> f32 {
    var most = core;
    for &k in roots { most = max(most, r0 + k.reach + 2.0 * k.radius); }
    let steps = 48;
    let step = (most - core) / steps;
    var inside = core;
    var outside: f32 = -1.0;
    for i in 1..steps + 1 {
        let rho = core + step * i;
        var high: f32 = -1.0;
        for &k in roots { high = max(high, root_height(k, r0, rho, round)); }
        if high >= h {
            inside = rho;
        } else {
            outside = rho;
            break;
        }
    }
    if outside > 0.0 && inside > core {
        for i in 6 {
            let mid = (inside + outside) * 0.5;
            var high: f32 = -1.0;
            for &k in roots { high = max(high, root_height(k, r0, mid, round)); }
            if high >= h { inside = mid; } else { outside = mid; }
        }
    }
    return eased_over(core, inside, 0.08 * r0);
}

// The sides' ways round the trunk with roots: from the back (seam_round, away from the house),
// denser over the roots, so a root has sides enough across it.
fn rooted_rounds(roots: Root[..8]&, seam_round: f32, sides: i64, rounds: f32[>..]&) {
    rounds.clear();
    let bins = 1024;
    var total: f32      = 0.0;
    var cdf:   f32[>..] = [];
    cdf.push(0.0);
    for b in bins {
        let a = seam_round + (b + 0.5) * TAU / bins;
        var dense: f32 = 1.0;
        for &k in roots {
            var off = a - k.round;
            off -= TAU * floor(off / TAU + 0.5);
            dense += 2.5 * exp(-(off / 0.22) * (off / 0.22));
        }
        total += dense;
        cdf.push(total);
    }
    var b = 0;
    for k in sides + 1 {
        let want = total * k / sides;
        while b < bins - 1 && cdf[b + 1] < want { b++; }
        let f = (want - cdf[b]) / max(cdf[b + 1] - cdf[b], 1e-6);
        rounds.push(seam_round + (b + clamp(f, 0.0, 1.0)) * TAU / bins);
    }
}

// The tubes of t shaped (WoodShape), in place of tube(): each tube limb in order, appended to
// verts and indices as tube() does.
fn shaped_tubes(t: Tree&, density: f32[>..]&, g: Grid, sun: float3, ways: float3[SKY_WAYS]&, shape: WoodShape, verts: WoodVertex[>..]&,
                indices: u32[>..]&) {
    var junctions: Junction[>..] = [];
    var first:     i32[>..]      = [];
    var children:  i32[>..]      = [];
    find_junctions(t, junctions, first, children);
    var rounds: f32[>..] = [];
    for &l, li in t.limbs {
        guard l.level < TUBE_LEVELS && l.count > 0 else { continue; }
        shaped_tube(t, density, g, sun, ways, shape, li, junctions, first, children, rounds, verts, indices);
    }
}

fn shaped_tube(t: Tree&, density: f32[>..]&, g: Grid, sun: float3, ways: float3[SKY_WAYS]&, shape: WoodShape, li: i64,
               junctions: Junction[>..]&, first: i32[>..]&, children: i32[>..]&, rounds: f32[>..]&, verts: WoodVertex[>..]&,
               indices: u32[>..]&) {
    let l = t.limbs[li];
    let tier = shape.tier;
    let level = l.level as i64;
    let arcs = joint_arcs(t, l);
    let joints = l.count as i64 + 1;
    let end = arcs[joints - 1];
    let me .= junctions[li];
    let joined = shape.junctions && me.radius > 0.0;
    // A branch wide enough for its foot's rings is laid with a fillet and welded under its
    // parent; a thinner one keeps its collar alone, its foot hidden in the parent as before.
    let welded = joined && me.radius >= FOOT_LEAST[tier];
    let rooted = shape.roots && level == 0 && l.parent < 0 && ROOT_COUNT[tier] > 0;
    let r0 = joint_radius(t, l, 0);
    var roots: Root[..8] = [];
    if rooted { trunk_roots(l, r0, tier, roots); }
    let sides = if rooted { ROOTED_SIDES[tier] } else { SHAPED_SIDES[tier * 3 + level] };
    // The light at each joint, as tube() takes it; the rings between take it in between.
    var joint_lit: float2[..14] = [];
    for i in joints { joint_lit.push(crown_light(density, g, joint_at(t, l, i), sun, ways)); }
    // The rings' arc lengths: a branch starts inside its parent, the flare's level lines first.
    var at:      f32[..900] = [];
    var heights: f32[..900] = [];
    var s:       f32        = 0.0;
    var exit:    f32        = 0.0;
    if joined { exit = min(me.parent_radius / me.sine, end * 0.6); }
    if welded { s = min(0.6 * me.parent_radius, exit * 0.8); }
    var flare_top: f32 = 0.0;
    if rooted {
        for &k in roots { flare_top = max(flare_top, k.rise + 1.1 * k.radius); }
        flare_top = min(flare_top + 0.5 * r0, end * 0.5);
        let rings = FLARE_RINGS[tier];
        for j in rings {
            let f = j / rings as f32;
            at.push(flare_top * pow(f, 1.6 as f32));
            heights.push(flare_top * pow(f, 1.6 as f32));
        }
        s = flare_top;
    }
    let kids = first[li];
    let kids_end = first[li + 1];
    var next_joint = 1;
    while at.len < MAX_STATIONS - 3 {
        at.push(s);
        heights.push(-1.0);
        guard s < end - 1e-4 else { break; }
        while next_joint < joints - 1 && arcs[next_joint] <= s + 1e-4 { next_joint++; }
        // The next joint (the last is the end) caps the step, or is taken when the step falls
        // just short of it.
        let _p, r, _w, _i, _f = chain_at(t, l, arcs, s);
        let ring_step = RING_STEP[tier * 3 + level];
        var step = if ring_step > 0.0 { ring_step * r } else { 1e9 };
        if shape.junctions && FOOT_STEP[tier] > 0.0 {
            if joined && me.radius >= FOOT_LEAST[tier] && s < exit + FOOT_LENGTH * me.radius {
                step = min(step, FOOT_STEP[tier] * me.radius);
            }
            for c in kids..kids_end {
                let j .= junctions[children[c as i64] as i64];
                let reach = 1.6 * j.radius / j.sine;
                if j.radius >= FOOT_LEAST[tier] && abs(s - j.along) < reach { step = min(step, FOOT_STEP[tier] * j.radius); }
            }
        }
        let joint_s = arcs[next_joint];
        var to = s + step;
        if to > joint_s || joint_s - to < 0.3 * step { to = joint_s; }
        s = to;
    }
    // The end's cap: two rings closing it, rounded.
    let r_end = joint_radius(t, l, joints - 1);
    let way_end = joint_way(t, l, joints - 1);
    // The rings' centres, radii and frames, carried along without twisting.
    var stations: Station[..900] = [];
    let way0 = joint_way(t, l, 0);
    let other = if abs(way0.y) < 0.9 { float3 { 0.0, 1.0, 0.0 } } else { float3 { 1.0, 0.0, 0.0 } };
    var side = normalize(cross(way0, other));
    for k, n in at {
        let p, r, way, i, f = chain_at(t, l, arcs, k);
        side = normalize(side - way * dot(side, way));
        let up = cross(way, side);
        let lit = joint_lit[i] * (1.0 - f) + joint_lit[min(i + 1, joints - 1)] * f;
        stations.push(Station { k, p, r, way, side, up, lit, heights[n] });
    }
    for c in 2 {
        let last = stations[stations.len - 1];
        let lift:   f32 = if c == 0 { 0.12 } else { 0.22 };
        let shrink: f32 = if c == 0 { 0.75 } else { 0.06 };
        stations.push(Station { end + lift * r_end, last.p + way_end * (lift * r_end), r_end * shrink, last.way, last.side, last.up, last.lit, -1.0 });
    }
    // The sides' ways round: even, or from the back over the roots more densely.
    rounds.clear();
    if rooted {
        let st0 = stations[0];
        let back = float3 { 0.0, 0.0, 1.0 };
        rooted_rounds(roots, atan2(dot(back, st0.up), dot(back, st0.side)), sides, rounds);
    } else {
        for k in sides + 1 { rounds.push((k as f32) * TAU / sides); }
    }
    // The bark's tiles round, whole, from the foot's girth; each limb's shift of its own.
    let least: f32 = 1.0;
    let tiles = max(floor(TAU * r0 / BARK_ACROSS + 0.5), least);
    var shift = Dice { mixed(l.first as u64 * 0x9E3779B97F4A7C15 + 7) };
    let shift_round = roll(shift);
    let run0: f32 = roll(shift) * BARK_ALONG;
    let ground = joint_at(t, l, 0).y;
    let parent_way = if joined { normalize(t.segments[l.attach as i64].b - t.segments[l.attach as i64].a) } else { float3_0 };
    let base = verts.len;
    let ring = sides + 1;
    for &st, n in stations {
        let flex = flex_at(level, clamp(st.s / max(end, 1e-6), 0.0, 1.0));
        // The collar's swell along the branch from where it leaves its parent.
        let fall = if joined { exp(-max(st.s - exit, 0.0) / (COLLAR_FALL * me.radius)) } else { 0.0 };
        let fade_foot = if joined { 1.0 - clamp((st.s - exit) / (FOOT_LENGTH * me.radius), 0.0, 1.0) } else { 0.0 };
        let core = st.r;
        var arc: f32 = 0.0;
        var last_q = float3_0;
        for k in ring {
            let a = rounds[k];
            let nrm = st.side * cos(a) + st.up * sin(a);
            var r = st.r;
            if st.flare >= 0.0 {
                // The roots fade out toward the flare's top ring, so the trunk above meets it
                // smoothly.
                let fade = 1.0 - clamp((st.flare / flare_top - 0.55) / 0.45, 0.0, 1.0);
                r = core + (rooted_radius(roots, r0, core, st.flare, a) - core) * fade * fade * (3.0 - 2.0 * fade);
            }
            var q = st.p + nrm * r;
            if st.flare >= 0.0 && n == 0 { q.y = ground; }
            var shade: f32 = 1.0;
            if joined {
                let under = max(-nrm.y, 0.0);
                q = st.p + nrm * (r * (1.0 + me.collar * fall * (1.0 + COLLAR_UNDER * under)));
            }
            if welded {
                // The fillet toward the parent and the weld under its surface.
                let parent = t.limbs[l.parent as i64];
                let gap, _radial, _axis = parent_gap(t, parent, l.attach, me, parent_way, q);
                let kf = FILLET * me.radius;
                let g = clamp(gap / kf, 0.0, 1.0);
                q += nrm * (kf * (1.0 - g) * (1.0 - g) * 0.25 * fade_foot);
                let gap2, radial2, axis2 = parent_gap(t, parent, l.attach, me, parent_way, q);
                if gap2 < 0.0 {
                    let rp = length(q - axis2) - gap2;
                    q = axis2 + radial2 * (rp - WELD);
                }
                shade = 1.0 - CREASE_SHADE * exp(-max(gap2, 0.0) / (0.3 * me.radius)) * fade_foot;
            }
            // The parent's swell and ridge round each branch's foot, and its grain bent round it.
            var du: f32 = 0.0;
            if shape.junctions {
                for c in kids..kids_end {
                    let j .= junctions[children[c as i64] as i64];
                    let reach = 3.0 * FOOT_LENGTH * j.radius / j.sine;
                    guard abs(st.s - j.along) < reach else { continue; }
                    let swell, crease = junction_swell(j, q, st.way);
                    q += nrm * swell;
                    shade = min(shade, 1.0 - CREASE_SHADE * exp(-max(crease, 0.0) / (0.3 * j.radius)));
                    du += grain_turn(j, st, a, core) * tiles / (TAU * core);
                }
            }
            if st.flare >= 0.0 {
                let h = q.y - ground;
                shade *= 1.0 - 0.5 * exp(-max(h, 0.0) / (0.12 * r0));
            }
            if k > 0 { arc += length(q - last_q); }
            last_q = q;
            let u = if rooted { arc } else { k * tiles / sides };
            let lit = float2 { st.lit.x * (0.5 + 0.5 * shade), st.lit.y * shade };
            verts.push(WoodVertex { q, nrm, st.way, float2 { u + du + shift_round, 0.0 }, float4 { lit.x, lit.y, max(core, 1e-3), flex } });
        }
        if rooted {
            // Round the trunk with roots by the share of the ring's arc, so every ring wraps
            // whole and the grain spreads over a root rather than shearing round the trunk.
            for k in ring {
                let at_v = base + n * ring + k;
                verts[at_v].uv.x = (verts[at_v].uv.x - shift_round) * tiles / max(arc, 1e-6) + shift_round;
            }
        }
    }
    // The bark along each side by its own arc length, so the grain follows a swell or a root.
    for k in ring {
        var run = run0;
        for n in stations.len {
            let at_v = base + n * ring + k;
            if n > 0 { run += length(verts[at_v].pos - verts[at_v - ring].pos); }
            verts[at_v].uv.y = run / BARK_ALONG;
        }
    }
    // The normals from the shaped surface.
    let rows = stations.len;
    for n in rows {
        for k in ring {
            let at_v = base + n * ring + k;
            let around = verts[base + n * ring + (k + 1) % sides].pos - verts[base + n * ring + (k + sides - 1) % sides].pos;
            let lo = max(n - 1, 0);
            let hi = min(n + 1, rows - 1);
            let along = verts[base + hi * ring + k].pos - verts[base + lo * ring + k].pos;
            var nrm = cross(along, around);
            let len = length(nrm);
            if len > 1e-9 {
                nrm = nrm / len;
                if dot(nrm, verts[at_v].normal) < 0.0 { nrm = -nrm; }
                verts[at_v].normal = nrm;
            }
        }
    }
    // Two triangles a side between rings, wound as tube()'s.
    let first_vertex = base as u32;
    let ring32 = ring as u32;
    for n in rows - 1 {
        for k in sides {
            let a = first_vertex + n as u32 * ring32 + k as u32;
            let b = a + 1;
            let c = a + ring32;
            let d = c + 1;
            indices.push(a);
            indices.push(c);
            indices.push(b);
            indices.push(b);
            indices.push(c);
            indices.push(d);
        }
    }
}

// How far q lies outside the parent's surface near the branch's foot (the parent's limb, the
// segment the branch sits on), its swell round the foot counted; the way out from the axis
// and the nearest point of the axis.
fn parent_gap(t: Tree&, parent: Limb, attach: i32, j: Junction&, parent_way: float3, q: float3) -> f32, float3, float3 {
    var best: f32 = 1e9;
    var best_c = q;
    for d in -1..2 {
        let si = attach + d;
        guard si >= parent.first && si < parent.first + parent.count else { continue; }
        let sg = t.segments[si as i64];
        let axis = sg.b - sg.a;
        let f = clamp(dot(q - sg.a, axis) / max(dot(axis, axis), 1e-9), 0.0, 1.0);
        let c = sg.a + axis * f;
        let r = sg.ra + (sg.rb - sg.ra) * f;
        let off = length(q - c) - r;
        if off < best {
            best = off;
            best_c = c;
        }
    }
    let radial = normalize(q - best_c);
    let swell, _crease = junction_swell(j, q, parent_way);
    return best - swell, radial, best_c;
}

// How far the parent's grain at way `a` round station st (core its radius) turns round the
// branch's foot j, in world units across: the stream function of a flow past the foot's
// ellipse, ψ = X (1 - 1/ρ²), faded out away from it; under the foot the grain gathers to its
// middle line.
fn grain_turn(j: Junction&, st: Station&, a: f32, core: f32) -> f32 {
    let lean = j.dir - st.way * dot(j.dir, st.way);
    guard length(lean) > 1e-4 else { return 0.0; }
    let foot_round = atan2(dot(lean, st.up), dot(lean, st.side));
    var off = a - foot_round;
    off -= TAU * floor(off / TAU + 0.5);
    let x = off * core;
    let cosine = sqrt(max(1.0 - j.sine * j.sine, 0.0)) * (if dot(j.dir, st.way) < 0.0 { -1.0 } else { 1.0 });
    let y = st.s - (j.along + j.parent_radius * cosine / j.sine);
    let across = j.radius * (1.0 + j.collar);
    let along = j.radius / j.sine;
    let rho2 = (x / across) * (x / across) + (y / along) * (y / along);
    guard rho2 > 1.0 else { return -x; }
    let rho = sqrt(rho2);
    return -x / rho2 * exp(-(rho - 1.0) * (rho - 1.0) / 8.0);
}
