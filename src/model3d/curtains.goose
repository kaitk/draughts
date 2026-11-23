// The library's curtains (option A of build/notes/curtains/, the measures in shell.goose):
// over each window a brass rod on two brackets with ball finials, and a lace panel each
// side gathered on it, tied back with a cord to a hook on the pier. Built once with the
// shell, in metres from the window's middle (x along the wall, y up from the floor, z out
// of the wall), the right panel's numbers mirrored for the left.
//
// A panel is a strip of LACE_COLS × LACE_ROWS over HEM_COLS × HEM_ROWS: its column s (0
// at the inner edge, 1 at the outer) a place across the flat cloth, its row a height. Each row runs from the inner
// edge to the outer (LACE_INNER, LACE_OUTER), LACE_MIDDLE off the wall, and folds in and
// out about that line, so deep that the row still holds the cloth's 1.20 m (fold_depth);
// each fold its own depth, its phase wandering over the drop, its crests a little sharp.
// The folds run down into the hem, whose line rises toward the inner edge, as a tied
// curtain's does, and scallops between the folds' turns. The lace's uv is the flat
// cloth's: u across it from the outer edge, v up it from the hem along the surface, so the
// pattern bunches on the folds as real lace does and the hem's border follows the hem.
namespace room_shell;
import std;
import vec;
import math;

// The panel down to 0.83 m, 6 columns a fold, and from there to the hem 12 a fold, so the
// folds hang round at the hem, where they are seen end on; the two meet on the 0.83 m
// row, whose extra columns below lie on the straight edges of the row above. The rows
// close together round the tie, where the cord's tilted loop gathers the cloth.
let LACE_COLS = 37;
let LACE_ROWS = 20;
let LACE_VERTS = 740;  // LACE_COLS × LACE_ROWS
let HEM_COLS = 73;
let HEM_ROWS = 6;
let HEM_VERTS = 438;   // HEM_COLS × HEM_ROWS
// The rows' heights, the hem's last (hem_y).
let LACE_ROW_Y: f32[20] = [3.7, 3.66, 3.55, 3.4, 3.2, 2.9, 2.5, 2.1, 1.7, 1.4, 1.2, 1.1, 1.04, 1.0, 0.97, 0.94, 0.91,
                           0.88, 0.855, 0.83];
let HEM_ROW_Y: f32[6] = [0.83, 0.75, 0.6, 0.32, 0.15, 0.05];
// How much of the sky and park the lace sees through the niche behind it, where it hangs
// in front of the niche (the glass 0.4 m back in a 1.3 m opening, its frames and bars).
let LACE_SKY_VIEW: f32 = 0.6;
let CORD_RADIUS:   f32 = 0.0045;  // a 9 mm cord
// How far the rod pocket's gathers stand off the rod's middle.
let POCKET: f32 = 0.016;

// The value at y of keys (y, value) sorted by y, a Catmull-Rom through them, clamped.
fn key_at(keys: float2[], y: f32) -> f32 {
    let n = keys.len;
    if y <= keys[0].x { return keys[0].y; }
    if y >= keys[n - 1].x { return keys[n - 1].y; }
    var i = 0;
    while keys[i + 1].x < y { i++; }
    let a = keys[i];
    let c = keys[i + 1];
    let t = (y - a.x) / (c.x - a.x);
    let before = if i > 0 { keys[i - 1].y } else { a.y - (c.y - a.y) };
    let after = if i + 2 < n { keys[i + 2].y } else { c.y + (c.y - a.y) };
    let m0 = 0.5 * (c.y - before);
    let m1 = 0.5 * (after - a.y);
    let t2 = t * t;
    let t3 = t2 * t;
    return (2.0 * t3 - 3.0 * t2 + 1.0) * a.y + (t3 - 2.0 * t2 + t) * m0 + (-2.0 * t3 + 3.0 * t2) * c.y + (t3 - t2) * m1;
}

// A fold's own depth (0.6 to 1.3 of the row's), and its phase at height y, a fraction of
// a fold up to ±0.3, wandering smoothly over about 0.8 m.
fn fold_depth(seed: i64, k: i64) -> f32 { 0.6 + 0.7 * surfaces::hash(seed, k) }
fn fold_phase(seed: i64, k: i64, y: f32) -> f32 {
    let at = y / 0.8;
    let i = floor(at) as i64;
    let f = at - i;
    let e = f * f * (3.0 - 2.0 * f);
    let a = surfaces::hash(seed, 100 + 37 * k + i) - 0.5;
    let c = surfaces::hash(seed, 101 + 37 * k + i) - 0.5;
    return 0.6 * (a + (c - a) * e);
}

// The fold's offset at s across and y up, -1.3 to 1.3 of the row's depth: the folds'
// sine with sharpened crests, rounding toward the hem where the cloth hangs free, each
// fold its own depth and phase, faded to the line over the last half fold at each edge so
// the edges hang clean.
fn fold_at(seed: i64, s: f32, y: f32) -> f32 {
    let n = LACE_FOLDS as f32;
    let k = min(floor(s * n) as i64, LACE_FOLDS - 1);
    let f = s * n - k;
    let depth = fold_depth(seed, k) * (1.0 - f) + fold_depth(seed, k + 1) * f;
    let phase = fold_phase(seed, k, y) * (1.0 - f) + fold_phase(seed, k + 1, y) * f;
    let v = sin(TAU * (s * n + phase));
    let sharp: f32 = 0.75 + 0.25 * clamp((0.7 - y) / 0.6, 0.0, 1.0);
    let shaped = if v < 0.0 { -pow(-v, sharp) } else { pow(v, sharp) };
    let edge = min(1.0, min(s * n * 2.0, (1.0 - s) * n * 2.0));
    return depth * shaped * edge;
}

// The panel's inner and outer edge at y as it hangs before the cord gathers it.
fn span(y: f32) -> float2 { float2 { key_at(LACE_INNER[..], y), key_at(LACE_OUTER[..], y) } }

// The row's fold depth at y, ungathered: a zigzag of LACE_FOLDS folds across w holds the
// flat cloth when its half depth is w / 4n × √(r² − 1), r the gather.
fn fold_amplitude(y: f32) -> f32 { fold_amplitude_in(span(y), y) }
fn fold_amplitude_in(x: float2, y: f32) -> f32 {
    let w = x.y - x.x;
    let r = LACE_FLAT / w;
    let a = 0.25 * w / LACE_FOLDS * sqrt(max(r * r - 1.0, 0.0));
    // The rod pocket: the cloth bunched round the rod, the folds opening below it.
    let open = clamp((LACE_ROD - 0.02 - y) / 0.28, 0.0, 1.0);
    return POCKET + (a - POCKET) * open * open * (3.0 - 2.0 * open);
}

// The bundle's section at y, ungathered: its middle across (x) and off the wall (y), and
// its half width (z) and half depth (w), an ellipse round the folds' crests.
fn bundle(y: f32) -> float4 { bundle_in(span(y), y) }
fn bundle_in(x: float2, y: f32) -> float4 {
    return float4 { 0.5 * (x.x + x.y), key_at(LACE_MIDDLE[..], y), 0.5 * (x.y - x.x), 1.1 * fold_amplitude_in(x, y) };
}

// The right panel's point at s across and y up: the cloth as it hangs, drawn in toward
// the bundle's middle round the cord's settled loop (Tie), as much as the loop squeezes
// it where it passes that side of the bundle, and standing out a little above and below.
fn drape_at(tie: Tie&, seed: i64, s: f32, y: f32) -> float3 {
    let x = span(y);
    let c = bundle_in(x, y);
    let px = x.x + s * (x.y - x.x);
    let pz = c.y + c.w / 1.1 * fold_at(seed, s, y);
    let h, q = tie_at(tie, atan2((px - c.x) / c.z, (pz - c.y) / c.w));
    let t = (y - h) / TIE_SPREAD;
    let above = t - 1.7;
    let below = t + 1.7;
    let k = 1.0 - (1.0 - q) * (exp(-t * t) - 0.12 * (exp(-above * above) + exp(-below * below)));
    return float3 { c.x + (px - c.x) * k, y, c.y + (pz - c.y) * k };
}

// The hem's height at s: about LACE_HEM, rising 3.5 cm toward the inner edge where the
// tie pulls the cloth up, lifting at each fold's turn, front and back, so the line
// scallops between them, the front's turns a little higher, and a slow wave along it.
fn hem_y(seed: i64, s: f32) -> f32 {
    let rise = 0.035 * (1.0 - s) * (1.0 - s);
    let wave = 0.01 * sin(TAU * (1.3 * s + surfaces::hash(seed, 7)));
    let f = fold_at(seed, s, LACE_HEM);
    return LACE_HEM + 0.005 + rise + 0.007 * f * f + 0.003 * f + wave;
}

// How much of the window behind the niche the lace sees at x, y (its distance from the
// window's middle, its height): all of LACE_SKY_VIEW in front of the casements' glazed
// opening (the blind frame's, 0.98 m across, from 3 cm over the sill to 6 cm under the
// springing, as shaders::LIGHT_FN's glazing), none in front of the frame, the niche's
// plaster round it or the pier, soft over GLAZED_SOFT for the glass's depth behind it.
let GLAZED_SOFT: f32 = 0.1;
fn sky_behind(o: Opening, x: f32, y: f32) -> f32 {
    let across = clamp((0.49 - abs(x)) / GLAZED_SOFT + 0.5, 0.0, 1.0);
    let up = clamp((y - o.sill - 0.03) / GLAZED_SOFT + 0.5, 0.0, 1.0)
           * clamp((o.sill + o.height - 0.06 - y) / GLAZED_SOFT + 0.5, 0.0, 1.0);
    return LACE_SKY_VIEW * across * up;
}

// A window's curtains in wall b (b's s at its middle): the lace into the glass list, the
// rod, brackets, finials, cords and hooks into the room's.
fn curtains(verts: mesh::Vertex[>..]&, indices: u32[>..]&, glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&,
            b: surfaces::Builder, o: Opening, seed: i64&) {
    let brass = surfaces::MAT_BRASS;
    if !tie_settled {
        settle_tie(settled_tie);
        tie_settled = true;
    }
    let tie .= settled_tie;
    let rod: float3[2] = [float3 { -ROD_HALF, LACE_ROD, LACE_OFF }, float3 { ROD_HALF, LACE_ROD, LACE_OFF }];
    tube(verts, indices, b, rod[..], ROD_RADIUS, 10, false, brass);
    for sx in SIDES {
        seed++;
        lace_panel(glass, glass_indices, b, o, sx, seed, tie);
        tie_back(verts, indices, b, sx, tie);
        // The finial, a ball on a short neck; the bracket, a rosette on the wall, an arm
        // out to a cup under the rod.
        let end = sx * ROD_HALF;
        let neck: float3[2] = [float3 { end, LACE_ROD, LACE_OFF }, float3 { end + sx * 0.012, LACE_ROD, LACE_OFF }];
        tube(verts, indices, b, neck[..], 0.008, 8, false, brass);
        ball(verts, indices, b, float3 { end + sx * (0.010 + FINIAL_RADIUS), LACE_ROD, LACE_OFF }, FINIAL_RADIUS, brass);
        let x = sx * ROD_BRACKET;
        let arm_y = LACE_ROD - ROD_RADIUS - 0.006;
        let rosette: float3[2] = [float3 { x, arm_y, 0.0 }, float3 { x, arm_y, 0.01 }];
        tube(verts, indices, b, rosette[..], 0.025, 12, false, brass);
        disc(verts, indices, b, float3 { x, arm_y, 0.01 }, 0.025, 12, brass);
        let arm: float3[2] = [float3 { x, arm_y, 0.01 }, float3 { x, arm_y, LACE_OFF }];
        tube(verts, indices, b, arm[..], 0.006, 8, false, brass);
        ball(verts, indices, b, float3 { x, arm_y + 0.002, LACE_OFF }, 0.011, brass);
    }
}

// One panel, side sx (1 the right, -1 the left), into the glass list: the hem's rows, then
// the rows above, v up the cloth from the hem along its surface.
fn lace_panel(glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&, b: surfaces::Builder, o: Opening, sx: f32, seed: i64,
              tie: Tie&) {
    var low:    float3[HEM_VERTS] = [float3_0; HEM_VERTS];
    var low_up: f32[HEM_VERTS]    = [0.0; HEM_VERTS];
    for j in HEM_ROWS {
        for i in HEM_COLS {
            let s = (i as f32) / ((HEM_COLS - 1) as f32);
            let y = if j == HEM_ROWS - 1 { hem_y(seed, s) } else { HEM_ROW_Y[j] };
            low[j * HEM_COLS + i] = drape_at(tie, seed, s, y);
        }
    }
    for h in LACE_COLS - 1 { low[2 * h + 1] = (low[2 * h] + low[2 * h + 2]) * 0.5; }
    climb(low[..], low_up[..], HEM_COLS, HEM_ROWS);
    var high:    float3[LACE_VERTS] = [float3_0; LACE_VERTS];
    var high_up: f32[LACE_VERTS]    = [0.0; LACE_VERTS];
    for j in LACE_ROWS {
        for i in LACE_COLS {
            let s = (i as f32) / ((LACE_COLS - 1) as f32);
            high[j * LACE_COLS + i] = drape_at(tie, seed, s, LACE_ROW_Y[j]);
        }
    }
    let last = (LACE_ROWS - 1) * LACE_COLS;
    for i in LACE_COLS { high_up[last + i] = low_up[2 * i]; }
    climb(high[..], high_up[..], LACE_COLS, LACE_ROWS);
    put_lace(glass, glass_indices, b, o, sx, seed, tie, low[..], low_up[..], HEM_COLS, HEM_ROWS);
    put_lace(glass, glass_indices, b, o, sx, seed, tie, high[..], high_up[..], LACE_COLS, LACE_ROWS);
}

// v up a grid's columns from its last row's (which `up` holds), along the cloth.
fn climb(pos: float3[:], up: f32[:], cols: i64, rows: i64) {
    for i in cols {
        var j = rows - 2;
        while j >= 0 {
            let a = j * cols + i;
            up[a] = up[a + cols] + length(pos[a] - pos[a + cols]);
            j--;
        }
    }
}

// How much of the room's light the folds beside a point of the drape hide from it, across its
// row: the share of the half circle out of the wall (cosine weighted) under the highest
// neighbour within FOLD_REACH each side, FOLD_DEEP in the deepest valleys and 0 on the
// crests. It goes into the lace's material's fraction (render3d moves it into a channel of
// its own), and the shader darkens its room-side fill by it (shaders::ROOM_GLASS,
// render3d::lace_shade).
let FOLD_REACH:  f32 = 0.1;
let FOLD_DEEP:   f32 = 0.4;
let FOLD_HIDDEN: f32 = 0.8;   // the hidden share that counts as the deepest (the 99th percentile)
fn fold_hidden(pos: float3[:], cols: i64, j: i64, i: i64) -> f32 {
    let p = pos[j * cols + i];
    var left:  f32 = 0.0;     // the highest neighbour's sine each side
    var right: f32 = 0.0;
    for k in cols {
        let q = pos[j * cols + k];
        let dx = q.x - p.x;
        let dz = q.z - p.z;
        guard k != i && abs(dx) < FOLD_REACH && dz > 0.0 else { continue; }
        let sine = dz / sqrt(dx * dx + dz * dz);
        if dx < 0.0 { left = max(left, sine); } else { right = max(right, sine); }
    }
    let hidden = 1.0 - 0.5 * (sqrt(1.0 - left * left) + sqrt(1.0 - right * right));
    return FOLD_DEEP * min(hidden / FOLD_HIDDEN, 1.0);
}

// A grid of the panel's points into the glass list, its normals by the drape's own slopes.
fn put_lace(glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&, b: surfaces::Builder, o: Opening, sx: f32, seed: i64,
            tie: Tie&, pos: float3[:], up: f32[:], cols: i64, rows: i64) {
    let k = m();
    let base = glass.len as u32;
    for j in rows {
        for i in cols {
            let s = (i as f32) / ((cols - 1) as f32);
            let p = pos[j * cols + i];
            let e: f32 = 0.002;
            let ds = drape_at(tie, seed, min(s + e, 1.0), p.y) - drape_at(tie, seed, max(s - e, 0.0), p.y);
            let dy = drape_at(tie, seed, s, p.y + 0.01) - drape_at(tie, seed, s, p.y - 0.01);
            let n = normalize(cross(ds, dy));
            let q = float3 { sx * p.x, p.y, p.z } * k;
            glass.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), surfaces::world_normal(b, float3 { sx * n.x, n.y, n.z }),
                                      float2 { (1.0 - s) * LACE_FLAT * k, up[j * cols + i] * k }, sky_behind(o, p.x, p.y),
                                      surfaces::MAT_LACE + fold_hidden(pos, cols, j, i) });
        }
    }
    for j in rows - 1 {
        for i in cols - 1 {
            let a = base + (j * cols + i) as u32;
            let c = a + cols as u32;
            glass_indices.append([a, a + 1, c + 1, a, c + 1, c]);
        }
    }
}

// The tie-back, settled once when the room is built (settle_tie): the cord as a chain of
// points under gravity, Verlet steps with fixed iterations over fixed buffers, a few
// milliseconds. Its loop once round the bundle, as long as the bundle's girth gathered at
// TIE_Y and never longer; the bundle a soft ellipse a section, its waist gathered round
// TIE_Y where the cord was tied, giving like the cloth, and the lace gripping the cord
// (the friction: a move along the bundle held back by how hard the cord presses on it).
// The knot stays where it was tied round the bundle, on its front toward the hook; two
// tails with their tassels hang from it, and the run from it to the hook's crook hangs
// slack. The knot's and the tails' weight drag their side of the loop down the waist's
// lower flank, so the loop tilts down toward the knot. The cloth then gathers round the
// loop where it settled (drape_at, from the angle table).
let TIE_LOOP = 40;        // the loop's points, the knot first, round toward the outer side
let TIE_RUN = 14;         // the run's segments, from the knot to the crook
let TIE_TAIL = 8;         // a tail's points, the knot's first
let TIE_POINTS = 68;      // TIE_LOOP + TIE_RUN + 2 × (TIE_TAIL − 1)
let TIE_LINKS = 108;      // the loop's, its bends', the run's and the tails' constraints
let TIE_ANGLES = 64;      // the settled loop's height and squeeze, round the bundle
let TIE_STEPS = 150;      // 0.62 s at TIE_RATE a second: it rests from about 0.5 s
let TIE_RATE: f32 = 240.0;
let TIE_ITERATIONS = 10;
let KNOT_ANGLE:    f32 = 0.22 * PI;  // the knot round the bundle from its front toward the hook
let GATHER_ACROSS: f32 = 0.74;   // the loop's length: the bundle's girth at the tie, its
let GATHER_DEEP:   f32 = 0.5;    // width and depth gathered to these
let WAIST:         f32 = 0.13;   // how far up and down the tie's gathering of the bundle reaches
let RUN_SLACK:     f32 = 1.3;    // the run's length over the way from the knot to the crook
let KNOT_MASS:     f32 = 7.0;    // a segment of cord's
let TASSEL_MASS:   f32 = 12.0;
let BUNDLE_GIVE:   f32 = 0.1;    // how much of the cord's way into the bundle it gives back an
let TIE_PUSH:      f32 = 0.01;   // iteration, and at most how far (metres)
let LACE_GRIP:     f32 = 0.2;    // a point's move up or down a step held back by this much of
// how far the bundle pushed it back in that step
let TIE_SPREAD: f32 = 0.075;     // how far up and down the cloth the cord's gathering reaches
let KNOT_SIZE:  f32 = 0.0042;    // the overhand's scale, about 25 mm across

struct Tie {
    ring:    float3[TIE_LOOP],     // the loop round the bundle, the knot first
    run:     float3[15],          // TIE_RUN + 1, the knot first
    tail_a:  float3[TIE_TAIL],
    tail_b:  float3[TIE_TAIL],
    height:  f32[TIE_ANGLES],     // the loop's height at each angle round the bundle
    squeeze: f32[TIE_ANGLES],     // and how far it draws the cloth in there (1 not at all)
}

// The tie-back as it settled, the same for every curtain, settled with the first.
var settled_tie = default<Tie>();
var tie_settled = false;

// The tied bundle's sections every SECTION_STEP from SECTION_LOW up, for the settling.
let SECTIONS = 161;
let SECTION_LOW:  f32 = 0.6;
let SECTION_STEP: f32 = 0.005;
fn section_at(sections: float4[SECTIONS]&, y: f32) -> float4 {
    let at = clamp((y - SECTION_LOW) / SECTION_STEP, 0.0, (SECTIONS - 1) as f32 - 0.001);
    let i = floor(at) as i64;
    let f = at - i;
    return sections[i] + (sections[i + 1] - sections[i]) * f;
}

// The hook's crook, where the run ends over it.
fn crook() -> float3 { float3 { TIE_HOOK, TIE_HOOK_Y + 0.003 + CORD_RADIUS, 0.044 } }

// The bundle as the cord found it: gathered round TIE_Y, where it was tied.
fn tied_bundle(y: f32) -> float4 {
    let c = bundle(y);
    let t = (y - TIE_Y) / WAIST;
    let g = exp(-t * t);
    return float4 { c.x, c.y, c.z * (1.0 - (1.0 - GATHER_ACROSS) * g), c.w * (1.0 - (1.0 - GATHER_DEEP) * g) };
}

// The angle round the bundle's section c of a point (0 the front, a quarter turn the outer
// side), and its distance out in c's ellipse grown by `out` (1 on it).
fn round_bundle(p: float3, c: float4, out: f32) -> float2 {
    let u = (p.x - c.x) / (c.z + out);
    let v = (p.z - c.y) / (c.w + out);
    return float2 { atan2(u, v), sqrt(u * u + v * v) };
}

// p pushed back out of the bundle by `give` of how far in it is, along the way its
// ellipse grows (its slope up the drop too, so the loop rests on the bundle's waist).
fn out_of_bundle(p: float3, give: f32, tied: float4[SECTIONS]&) -> float3 {
    let c = section_at(tied, p.y);
    let r = round_bundle(p, c, CORD_RADIUS).y;
    guard r < 1.0 && r > 0.0001 else { return p; }
    let a = c.z + CORD_RADIUS;
    let d = c.w + CORD_RADIUS;
    let e: f32 = 0.005;
    let up = (round_bundle(p, section_at(tied, p.y + e), CORD_RADIUS).y - round_bundle(p, section_at(tied, p.y - e), CORD_RADIUS).y) /
             (2.0 * e);
    // Out across the section, and up or down it no steeper than about 30°: the bundle's
    // middle bends toward the wall at the tie, which would push a cord at its back along it.
    let across = float2 { (p.x - c.x) / (r * a * a), (p.z - c.y) / (r * d * d) };
    let steep = 0.6 * length(across);
    let g = float3 { across.x, clamp(up, -steep, steep), across.y };
    let push = g * (give * (1.0 - r) / dot(g, g));
    return p + push * min(1.0, TIE_PUSH / max(length(push), 0.000001));
}

fn link(links: int2[..TIE_LINKS]&, lengths: f32[..TIE_LINKS]&, i: i64, j: i64, length: f32) {
    links.push(int2 { i as i32, j as i32 });
    lengths.push(length);
}

fn settle_tie(tie: Tie&) {
    var pos:     float3[TIE_POINTS] = [float3_0; TIE_POINTS];
    var last:    float3[TIE_POINTS] = [float3_0; TIE_POINTS];
    var free:    f32[TIE_POINTS]    = [1.0; TIE_POINTS];
    var links:   int2[..TIE_LINKS]  = [];
    var lengths: f32[..TIE_LINKS]   = [];
    var tied:    float4[SECTIONS]   = [float4_0; SECTIONS];
    for i in SECTIONS { tied[i] = tied_bundle(SECTION_LOW + SECTION_STEP * i); }
    // The loop on the gathered ellipse, level at the tie, its girth its length.
    let c = bundle(TIE_Y);
    let a = GATHER_ACROSS * c.z + CORD_RADIUS;
    let d = GATHER_DEEP * c.w + CORD_RADIUS;
    for i in TIE_LOOP {
        let t = KNOT_ANGLE + TAU * i / TIE_LOOP;
        pos[i] = float3 { c.x + a * sin(t), TIE_Y, c.y + d * cos(t) };
    }
    for i in TIE_LOOP {
        let j = (i + 1) % TIE_LOOP;
        link(links, lengths, i, j, length(pos[j] - pos[i]));
    }
    for i in TIE_LOOP {
        let j = (i + 2) % TIE_LOOP;
        link(links, lengths, i, j, length(pos[j] - pos[i]));
    }
    var girth: f32 = 0.0;
    for k in TIE_LOOP { girth += lengths[k]; }
    free[0] = 1.0 / KNOT_MASS;
    // The run, straight to the crook to start, held there.
    let knot = pos[0];
    let way = crook() - knot;
    let run_link = RUN_SLACK * length(way) / TIE_RUN;
    for i in 1..TIE_RUN + 1 {
        let k = TIE_LOOP + i - 1;
        pos[k] = knot + way * (i as f32 / TIE_RUN);
        link(links, lengths, if i == 1 { 0 } else { k - 1 }, k, run_link);
    }
    free[TIE_LOOP + TIE_RUN - 1] = 0.0;
    // The tails, 11 and 8.5 cm, straight down a little apart, on the bundle's face.
    let tails = TIE_LOOP + TIE_RUN;
    let tail_links: f32[2] = [0.11 / (TIE_TAIL - 1), 0.085 / (TIE_TAIL - 1)];
    let tail_apart: f32[2] = [0.004, -0.004];
    for side in 2 {
        let first = tails + side * (TIE_TAIL - 1);
        for i in 1..TIE_TAIL {
            let k = first + i - 1;
            let y = knot.y - tail_links[side] * i;
            let b = tied_bundle(y);
            let u = (knot.x - b.x) / (b.z + CORD_RADIUS);
            let face = b.y + (b.w + CORD_RADIUS) * sqrt(max(1.0 - u * u, 0.0)) + 0.002;
            pos[k] = float3 { knot.x + tail_apart[side], y, max(face, knot.z) };
            link(links, lengths, if i == 1 { 0 } else { k - 1 }, k, tail_links[side]);
        }
        free[first + TIE_TAIL - 2] = 1.0 / TASSEL_MASS;
    }
    assert(links.len == TIE_LINKS);
    for i in TIE_POINTS { last[i] = pos[i]; }
    let dt: f32 = 1.0 / TIE_RATE;
    let fall = float3 { 0.0, -9.8 * dt * dt, 0.0 };
    let wall = 0.02 + CORD_RADIUS;
    var pressed: f32[TIE_POINTS] = [0.0; TIE_POINTS];
    for step in TIE_STEPS {
        for i in TIE_POINTS { pressed[i] = 0.0; }
        for i in TIE_POINTS {
            guard free[i] > 0.0 else { continue; }
            let p = pos[i];
            pos[i] = p + (p - last[i]) * 0.97 + fall;
            last[i] = p;
        }
        for it in TIE_ITERATIONS {
            for i in TIE_POINTS {
                guard free[i] > 0.0 else { continue; }
                var p = out_of_bundle(pos[i], BUNDLE_GIVE, tied);
                pressed[i] += length(p - pos[i]);
                p.z = max(p.z, wall);
                pos[i] = p;
            }
            for l, k in links {
                let i = l.x as i64;
                let j = l.y as i64;
                let w = free[i] + free[j];
                guard w > 0.0 else { continue; }
                let e = pos[j] - pos[i];
                let n = length(e);
                guard n > 0.000001 else { continue; }
                let stiff: f32 = if k >= TIE_LOOP && k < 2 * TIE_LOOP { 0.1 } else { 1.0 };
                let move = e * (stiff * (n - lengths[k]) / (n * w));
                pos[i] = pos[i] + move * free[i];
                pos[j] = pos[j] - move * free[j];
            }
            // The cord doesn't stretch: a loop longer than its girth is drawn in toward the
            // bundle's middle, its last places with it so the drawing in isn't a speed.
            var round: f32 = 0.0;
            for i in TIE_LOOP { round += length(pos[(i + 1) % TIE_LOOP] - pos[i]); }
            if round > girth {
                let k = girth / round;
                for i in TIE_LOOP {
                    let c = section_at(tied, pos[i].y);
                    let to = float3 { c.x + (pos[i].x - c.x) * k, pos[i].y, c.y + (pos[i].z - c.y) * k };
                    last[i] = last[i] + (to - pos[i]);
                    pos[i] = to;
                }
            }
            // The knot stays where it was tied round the bundle.
            let b = section_at(tied, pos[0].y);
            let r = round_bundle(pos[0], b, CORD_RADIUS).y;
            pos[0] = float3 { b.x + r * (b.z + CORD_RADIUS) * sin(KNOT_ANGLE), pos[0].y, b.y + r * (b.w + CORD_RADIUS) * cos(KNOT_ANGLE) };
        }
        for i in TIE_POINTS {
            let hold = LACE_GRIP * pressed[i];
            let fall_by = pos[i].y - last[i].y;
            pos[i].y -= clamp(fall_by, -hold, hold);
        }
    }
    for i in TIE_LOOP { tie.ring[i] = pos[i]; }
    tie.run[0] = pos[0];
    for i in 1..TIE_RUN + 1 { tie.run[i] = pos[TIE_LOOP + i - 1]; }
    tie.tail_a[0] = pos[0];
    tie.tail_b[0] = pos[0];
    for i in 1..TIE_TAIL {
        tie.tail_a[i] = pos[tails + i - 1];
        tie.tail_b[i] = pos[tails + TIE_TAIL - 1 + i - 1];
    }
    // Round the bundle, where the loop passes and how far in it draws the cloth: its
    // distance out in the cloth's own ellipse, less the cord's thickness.
    var angle: f32[TIE_LOOP] = [0.0; TIE_LOOP];
    var draw:  f32[TIE_LOOP] = [0.0; TIE_LOOP];
    for p, i in tie.ring {
        let b = bundle(p.y);
        let r = round_bundle(p, b, 0.0);
        let off = length(float2 { p.x - b.x, p.z - b.y });
        angle[i] = r.x;
        draw[i] = clamp(r.y * (off - CORD_RADIUS) / max(off, 0.001), 0.2, 1.0);
    }
    for j in TIE_ANGLES {
        let phi = TAU * j / TIE_ANGLES - PI;
        for i in TIE_LOOP {
            let n = (i + 1) % TIE_LOOP;
            let from = phi - angle[i];
            let span = angle[n] - angle[i];
            let at = from - TAU * floor(from / TAU);
            let wide = span - TAU * floor(span / TAU);
            guard at <= wide && wide > 0.0 else { continue; }
            let f = at / wide;
            tie.height[j] = tie.ring[i].y + (tie.ring[n].y - tie.ring[i].y) * f;
            tie.squeeze[j] = draw[i] + (draw[n] - draw[i]) * f;
            break;
        }
    }
}

// The settled loop's height and squeeze at angle `a` round the bundle (atan2's range).
fn tie_at(tie: Tie&, a: f32) -> f32, f32 {
    let at = (a + PI) / TAU * TIE_ANGLES;
    let i = floor(at) as i64;
    let f = at - i;
    let j0 = ((i % TIE_ANGLES) + TIE_ANGLES) % TIE_ANGLES;
    let j1 = (j0 + 1) % TIE_ANGLES;
    return tie.height[j0] + (tie.height[j1] - tie.height[j0]) * f, tie.squeeze[j0] + (tie.squeeze[j1] - tie.squeeze[j0]) * f;
}

// The tie-back of side sx, as it settled (settle_tie): the cord round the bundle, its two
// ends into the knot, an overhand knot on the bundle's front toward the hook, the two
// tails with their tassels hanging from it and the run to a small brass hook on the pier.
// Mirrored for the left.
fn tie_back(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, sx: f32, tie: Tie&) {
    let mirror = float3 { sx, 1.0, 1.0 };
    let cord = surfaces::MAT_CORD;
    var round: float3[..TIE_LOOP] = [];
    for i in 1..TIE_LOOP { round.push(tie.ring[i] * mirror); }
    tube(verts, indices, b, round[..], CORD_RADIUS, 8, false, cord);
    var run: float3[..20] = [];
    for p in tie.run { run.push(p * mirror); }
    run.push(float3 { TIE_HOOK, TIE_HOOK_Y - 0.004, 0.036 } * mirror);
    run.push(float3 { TIE_HOOK + 0.002, TIE_HOOK_Y - 0.02, 0.034 } * mirror);
    tube(verts, indices, b, run[..], CORD_RADIUS, 8, false, cord);
    var tail_a: float3[..TIE_TAIL] = [];
    var tail_b: float3[..TIE_TAIL] = [];
    for p in tie.tail_a { tail_a.push(p * mirror); }
    for p in tie.tail_b { tail_b.push(p * mirror); }
    tube(verts, indices, b, tail_a[..], 0.85 * CORD_RADIUS, 6, false, cord);
    tube(verts, indices, b, tail_b[..], 0.85 * CORD_RADIUS, 6, false, cord);
    tassel(verts, indices, b, tail_a[TIE_TAIL - 1]);
    tassel(verts, indices, b, tail_b[TIE_TAIL - 1]);
    overhand(verts, indices, b, tie.ring[0], mirror);
    // The hook: a rosette on the panelling, a pin out of it turned up at its end.
    let hx = sx * TIE_HOOK;
    let hy = TIE_HOOK_Y;
    disc(verts, indices, b, float3 { hx, hy, 0.026 }, 0.01, 8, surfaces::MAT_BRASS);
    let pin: float3[5] = [float3 { hx, hy, 0.02 }, float3 { hx, hy, 0.04 }, float3 { hx, hy + 0.003, 0.048 },
                          float3 { hx, hy + 0.011, 0.051 }, float3 { hx, hy + 0.017, 0.051 }];
    tube(verts, indices, b, pin[..], 0.0028, 6, false, surfaces::MAT_BRASS);
    ball(verts, indices, b, float3 { hx, hy + 0.018, 0.051 }, 0.0042, surfaces::MAT_BRASS);
}

// The knot at k (the right side's): an overhand, a trefoil of the cord swept tight, lying
// on the bundle's face there, its middle out by its own depth and the cord's.
fn overhand(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, k: float3, mirror: float3) {
    let c = bundle(k.y);
    let out = normalize(float3 { (k.x - c.x) / (c.z * c.z), 0.0, (k.z - c.y) / (c.w * c.w) });
    let up = float3 { 0.0, 1.0, 0.0 };
    let side = normalize(cross(up, out));
    let n = 48;
    var pts: float3[..48] = [];
    var mid = float3_0;
    for i in n {
        let t: f32 = TAU * i / n;
        let q = float3 { sin(t) + 2.0 * sin(2.0 * t), cos(t) - 2.0 * cos(2.0 * t), -1.15 * sin(3.0 * t) };
        pts.push(q);
        mid = mid + q * (1.0 / n);
    }
    let lift = 1.15 * KNOT_SIZE + CORD_RADIUS;
    for &p in pts {
        let q = (p - mid) * KNOT_SIZE;
        p = (k + side * q.x + up * (0.8 * q.y) + out * (q.z + lift)) * mirror;
    }
    tube(verts, indices, b, pts[..], CORD_RADIUS, 8, true, surfaces::MAT_CORD);
}

// A small tassel hanging from a tail's end at top: a round head, and a skirt of threads
// flaring a little and ending square, 5.5 cm long.
let TASSEL_R: f32[8] = [0.0, 0.005, 0.007, 0.0048, 0.0075, 0.0095, 0.0105, 0.005];
let TASSEL_Y: f32[8] = [0.006, 0.004, -0.002, -0.009, -0.014, -0.035, -0.056, -0.057];
fn tassel(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, top: float3) {
    let k = m();
    let sides = 8;
    let base = verts.len as u32;
    for r, i in TASSEL_R {
        for j in sides + 1 {
            let ang: f32 = TAU * j / sides;
            let d = float3 { cos(ang), 0.15, sin(ang) };
            let q = (top + float3 { cos(ang) * r, TASSEL_Y[i], sin(ang) * r }) * k;
            verts.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), surfaces::world_normal(b, normalize(d)),
                                      float2 { (j as f32) / sides, -TASSEL_Y[i] }, 1.0, surfaces::MAT_CORD + 0.5 });
        }
    }
    let ring = (sides + 1) as u32;
    for i in TASSEL_R.len - 1 {
        let r0 = base + (i * (sides + 1)) as u32;
        let r1 = r0 + ring;
        for j in sides {
            let a = j as u32;
            indices.append([r0 + a, r0 + a + 1, r1 + a + 1, r0 + a, r1 + a + 1, r1 + a]);
        }
    }
}

// A tube of radius r round the polyline pts (metres in b's frame), `sides` round,
// closed into a loop or open; its uv round it (0 to 1, the seam doubled) and along it
// (metres), for the cord's twist.
fn tube(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, pts: float3[], r: f32, sides: i64, closed: bool,
        mat: f32) {
    let k = m();
    let n = pts.len;
    let base = verts.len as u32;
    var along: f32 = 0.0;
    for p, i in pts {
        if i > 0 { along += length(p - pts[i - 1]); }
        let prev = if i > 0 { pts[i - 1] } else { if closed { pts[n - 1] } else { p } };
        let next = if i + 1 < n { pts[i + 1] } else { if closed { pts[0] } else { p } };
        let t = normalize(next - prev);
        let lift = if abs(t.y) > 0.9 { float3 { 1.0, 0.0, 0.0 } } else { float3 { 0.0, 1.0, 0.0 } };
        let a = normalize(cross(t, lift));
        let c = cross(a, t);
        for j in sides + 1 {
            let ang: f32 = TAU * j / sides;
            let d = a * cos(ang) + c * sin(ang);
            let q = (p + d * r) * k;
            verts.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), surfaces::world_normal(b, d),
                                      float2 { (j as f32) / sides, along }, 1.0, mat });
        }
    }
    let rings = if closed { n } else { n - 1 };
    let ring = sides + 1;
    for i in rings {
        let r0 = base + (i * ring) as u32;
        let r1 = base + (((i + 1) % n) * ring) as u32;
        for j in sides {
            let j0 = j as u32;
            indices.append([r0 + j0, r0 + j0 + 1, r1 + j0 + 1, r0 + j0, r1 + j0 + 1, r1 + j0]);
        }
    }
}

// A ball of radius r at c (metres in b's frame), 8 round and 6 up.
fn ball(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: float3, r: f32, mat: f32) {
    let k = m();
    let round = 8;
    let rows = 6;
    let base = verts.len as u32;
    for i in rows + 1 {
        let lat: f32 = PI * i / rows;
        for j in round {
            let lon: f32 = TAU * j / round;
            let d = float3 { sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon) };
            let q = (c + d * r) * k;
            verts.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), surfaces::world_normal(b, d), float2 { j, i },
                                      1.0, mat });
        }
    }
    for i in rows {
        let r0 = base + (i * round) as u32;
        let r1 = r0 + round as u32;
        for j in round {
            let j1 = (j + 1) % round;
            indices.append([r0 + j as u32, r0 + j1 as u32, r1 + j1 as u32, r0 + j as u32, r1 + j1 as u32, r1 + j as u32]);
        }
    }
}

// A disc of radius r at c facing out of the wall (+z), `sides` round.
fn disc(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: float3, r: f32, sides: i64, mat: f32) {
    let k = m();
    let n = surfaces::world_normal(b, float3 { 0.0, 0.0, 1.0 });
    let base = verts.len as u32;
    let q = c * k;
    verts.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), n, float2_0, 1.0, mat });
    for j in sides {
        let ang: f32 = TAU * j / sides;
        let p = (c + float3 { cos(ang), sin(ang), 0.0 } * r) * k;
        verts.push(mesh::Vertex { surfaces::world(b, p.x, p.y, p.z), n, float2_0, 1.0, mat });
    }
    for j in sides { indices.append([base, base + 1 + j as u32, base + 1 + ((j + 1) % sides) as u32]); }
}
