// The tree's leaves as one atlas (task 107's T3): eight Norway maple leaves, each five
// lobes drawn out into long sharp points, a few long teeth, the stalk's upper part,
// palmate veins, two with tar spots (Rhytisma acerinum), made once at startup. It holds
// what the leaf is, not its colour, so each twig tints its own leaves (trees::Card.tint)
// and the same texel gives the front's colour and the light through it (front, back).
//
// Two RGBA8 layers, ATLAS_W × ATLAS_H, four leaves across and two down, CELL texels each,
// with their mips:
//   shape: R the blade's light and dark, G where it turns first (0 green longest),
//          B the veins, A the outline (blade and stalk);
//   marks: R how thick (the veins and stalk let less through), G a tar spot's black core,
//          B the stalk, A the spot's yellow-green halo.
// A leaf's own frame: its foot (where the blade meets the stalk) at the cell's FOOT, y up
// to the middle lobe's tip at 1, SCALE texels a unit; a card's quad spans QUAD.
namespace leaf_atlas;
import std;
import vec;
import math;

let LEAVES = 8;
let CELL = 256;
let ACROSS = 4;
let ATLAS_W = 1024;
let ATLAS_H = 512;
let SCALE: f32 = 150.0;
let FOOT = float2 { 128.0, 170.0 };
// The card's quad in the leaf's frame: x from -QUAD.x to QUAD.x, y from QUAD.y to QUAD.z.
let QUAD = float4 { 0.853, -0.573, 1.133, 0.0 };

// A lobe: its way out from the foot, its length and half width (the blade's lengths), and
// its teeth, each side's two: where along it (a share of its length) and how tall, 0 none.
struct Lobe { dir: float2, length: f32, width: f32, at: float4, tall: float4 }

struct Leaf {
    lobes: Lobe[5],
    spots: float4[..6],     // x, y, radius in the leaf's frame
    bend:  f32,             // the stalk's curve
    seed:  u64,
}

fn mixed(x: u64) -> u64 {
    var z = x + 0x9E3779B97F4A7C15;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

struct Dice { state: u64 }

fn roll(d: Dice&) -> f32 {
    d.state = mixed(d.state);
    let top = (d.state >> 40) as f32;
    return top / 16777216.0;
}

fn roll_between(d: Dice&, lo: f32, hi: f32) -> f32 { lo + (hi - lo) * roll(d) }

// Leaf k: the middle lobe, the two big ones beside it about 58 degrees out, and the two
// small ones by the stalk about 118 out; the middle and big ones with two long teeth a
// side, the small ones one; leaves 6 and 7 tar-spotted.
fn leaf_of(k: i64) -> Leaf {
    var d = Dice { mixed(k as u64 * 7919 + 101) };
    var lf = Leaf { lobes: [default<Lobe>(); 5], spots: [], bend: roll_between(d, -0.08, 0.08), seed: mixed(k as u64 + 5) };
    let angles:  f32[5] = [0.0, 56.0, -56.0, 110.0, -110.0];
    let lengths: f32[5] = [1.0, 0.9, 0.9, 0.56, 0.56];
    let widths:  f32[5] = [0.32, 0.3, 0.3, 0.2, 0.2];
    let wide = roll_between(d, 0.92, 1.1);
    for j in 5 {
        let a = radians(angles[j] + roll_between(d, -6.0, 6.0) + (if j > 0 { (angles[j] / abs(angles[j])) * 4.0 * (wide - 1.0) * 10.0 } else { 0.0 }));
        let length = lengths[j] * (if j == 0 { 1.0 } else { roll_between(d, 0.9, 1.06) });
        let small = j >= 3;
        let t1 = if small { 0.0 } else { roll_between(d, 0.09, 0.15) };
        let t2 = if small { 0.0 } else { roll_between(d, 0.07, 0.12) };
        let t3 = if small { 0.0 } else { roll_between(d, 0.09, 0.15) };
        let t4 = if small { 0.0 } else { roll_between(d, 0.07, 0.12) };
        let s1 = roll_between(d, 0.4, 0.5);
        let s2 = roll_between(d, 0.62, 0.72);
        let s3 = roll_between(d, 0.4, 0.5);
        let s4 = roll_between(d, 0.62, 0.72);
        // The small lobes' one tooth on their outer side.
        let outer = if small { roll_between(d, 0.1, 0.16) } else { 0.0 };
        var at = float4 { s1, s2, s3, s4 };
        var tall = float4 { t1, t2, t3, t4 };
        if small {
            at = float4 { 0.5, 0.0, 0.5, 0.0 };
            tall = if angles[j] > 0.0 { float4 { outer, 0.0, 0.0, 0.0 } } else { float4 { 0.0, 0.0, outer, 0.0 } };
        }
        lf.lobes[j] = Lobe { float2 { sin(a), cos(a) }, length, widths[j] * wide, at, tall };
    }
    if k >= LEAVES - 2 {
        let count = 2 + (roll(d) * 4.0) as i64;
        for i in count {
            let j = min((roll(d) * 5.0) as i64, 4);
            let s = roll_between(d, 0.2, 0.6) * lf.lobes[j].length;
            let side = roll_between(d, -0.08, 0.08);
            let dir = lf.lobes[j].dir;
            lf.spots.push(float4 { dir.x * s + dir.y * side, dir.y * s - dir.x * side, roll_between(d, 0.025, 0.07), 0.0 });
        }
    }
    return lf;
}

// A lobe's half width at share x of its length on side `side` (0 the +t side, 1 the
// other): broad by the foot, its edges hollow to a long sharp tip, and its teeth, each
// rising slowly to a point and dropping at once, so they lean toward the tip.
fn half_width(lb: Lobe&, x: f32, side: i64) -> f32 {
    guard x >= 0.0 && x <= 1.0 else { return -1.0; }
    let e: f32 = 1.4;
    var hw = lb.width * pow(1.0 - x, e) * (1.0 + 0.8 * x);
    let rise: f32 = 0.15;
    let drop: f32 = 0.012;
    for k in 2 {
        let a = if side == 0 { if k == 0 { lb.at.x } else { lb.at.y } } else { if k == 0 { lb.at.z } else { lb.at.w } };
        let tall = if side == 0 { if k == 0 { lb.tall.x } else { lb.tall.y } } else { if k == 0 { lb.tall.z } else { lb.tall.w } };
        guard tall > 0.0 else { continue; }
        let sharp: f32 = 1.8;
        if x > a - rise && x <= a { hw += tall * lb.length * pow((x - (a - rise)) / rise, sharp); }
        if x > a && x < a + drop { hw += tall * lb.length * (1.0 - (x - a) / drop); }
    }
    return hw;
}

// How far inside the blade p is (negative outside), about a distance, in the leaf's units.
fn inside(lf: Leaf&, p: float2) -> f32 {
    // The middle, round, so the sinuses between the lobes are round; cut at the stalk.
    let c = float2 { 0.0, 0.12 };
    var f = 0.34 - length(p - c);
    f = min(f, p.y + 0.05 + 0.35 * abs(p.x));
    for &lb in lf.lobes {
        let s = dot(p, lb.dir);
        let t = lb.dir.x * p.y - lb.dir.y * p.x;
        let x = s / lb.length;
        let side = if t >= 0.0 { 0 } else { 1 };
        let hw = half_width(lb, x, side);
        if hw > 0.0 { f = max(f, hw - abs(t)); }
    }
    return f;
}

fn segment_distance(p: float2, a: float2, b: float2) -> f32 {
    let ab = b - a;
    let h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-9), 0.0, 1.0);
    return length(p - a - ab * h);
}

// A lattice noise over the leaf, 0..1, `cells` a unit.
fn noise(seed: u64, p: float2, cells: f32) -> f32 {
    let x = p.x * cells + 64.0;
    let y = p.y * cells + 64.0;
    let ix = floor(x) as i64;
    let iy = floor(y) as i64;
    let fx = x - ix;
    let fy = y - iy;
    let ux = fx * fx * (3.0 - 2.0 * fx);
    let uy = fy * fy * (3.0 - 2.0 * fy);
    let a = lattice(seed, ix, iy);
    let b = lattice(seed, ix + 1, iy);
    let c = lattice(seed, ix, iy + 1);
    let e = lattice(seed, ix + 1, iy + 1);
    return a + (b - a) * ux + (c - a) * uy + (a - b - c + e) * ux * uy;
}

fn lattice(seed: u64, x: i64, y: i64) -> f32 {
    let h = mixed(seed ^ (x as u64 * 0x632BE59BD9B4E019) ^ (y as u64 * 0x85157AF5));
    return (h >> 40) as f32 / 16777216.0;
}

// A vein from a to b, `wide` across at a and `narrow` at b, drawn into the cell's vein
// buffer over its box only.
fn vein(veins: f32[>..]&, a: float2, b: float2, wide: f32, narrow: f32) {
    let r = max(wide, narrow) + 2.0 / SCALE;
    let x0 = clamp(floor(FOOT.x + (min(a.x, b.x) - r) * SCALE) as i64, 0, CELL);
    let x1 = clamp(ceil(FOOT.x + (max(a.x, b.x) + r) * SCALE) as i64, 0, CELL);
    let y0 = clamp(floor(FOOT.y - (max(a.y, b.y) + r) * SCALE) as i64, 0, CELL);
    let y1 = clamp(ceil(FOOT.y - (min(a.y, b.y) - r) * SCALE) as i64, 0, CELL);
    let ab = b - a;
    let ll = max(dot(ab, ab), 1e-9);
    for j in y0..y1 {
        for i in x0..x1 {
            let p = texel_point(i, j);
            let h = clamp(dot(p - a, ab) / ll, 0.0, 1.0);
            let d = length(p - a - ab * h);
            let w = wide + (narrow - wide) * h;
            let v = clamp(0.5 + (w - d) * SCALE, 0.0, 1.0);
            veins[j * CELL + i] = max(veins[j * CELL + i], v);
        }
    }
}

fn texel_point(i: i64, j: i64) -> float2 { float2 { (i + 0.5 - FOOT.x) / SCALE, (FOOT.y - (j + 0.5)) / SCALE } }

// The leaf's veins: one along each lobe, one out to each tooth, and a few to the edge
// between.
fn draw_veins(lf: Leaf&, veins: f32[>..]&) {
    for i in veins.len { veins[i] = 0.0; }
    let o = float2 { 0.0, 0.0 };
    for &lb in lf.lobes {
        let perp = float2 { -lb.dir.y, lb.dir.x };
        vein(veins, o, lb.dir * (lb.length * 0.96), 0.011, 0.002);
        for side in 2 {
            let sign: f32 = if side == 0 { 1.0 } else { -1.0 };
            for k in 2 {
                let a = if side == 0 { if k == 0 { lb.at.x } else { lb.at.y } } else { if k == 0 { lb.at.z } else { lb.at.w } };
                let tall = if side == 0 { if k == 0 { lb.tall.x } else { lb.tall.y } } else { if k == 0 { lb.tall.z } else { lb.tall.w } };
                guard tall > 0.0 else { continue; }
                let from = lb.dir * (a * lb.length * 0.55);
                let tip = lb.dir * (a * lb.length) - perp * (sign * (half_width(lb, a, side) * 0.92));
                vein(veins, from, tip, 0.005, 0.0015);
            }
            // The smaller side veins, out and forward to the edge.
            for k in 4 {
                let x = 0.12 + 0.2 * k;
                let foot = lb.dir * (x * lb.length);
                let reach = max(half_width(lb, x + 0.08, side), 0.0) * 0.9;
                let end = lb.dir * ((x + 0.08) * lb.length) - perp * (sign * reach);
                vein(veins, foot, end, 0.0032, 0.001);
            }
        }
    }
}

// The two layers at level 0 for leaf k into its cell.
fn draw_leaf(k: i64, shape: u8[>..]&, marks: u8[>..]&, veins: f32[>..]&) {
    let lf = leaf_of(k);
    draw_veins(lf, veins);
    let cx = (k % ACROSS) * CELL;
    let cy = (k / ACROSS) * CELL;
    let stalk_end = float2 { lf.bend, QUAD.y };
    for j in CELL {
        for i in CELL {
            let p = texel_point(i, j);
            let blade = clamp(0.5 + inside(lf, p) * SCALE, 0.0, 1.0);
            // The stalk: from the foot down out of the cell, curving a little.
            let sd = segment_distance(p, float2 { 0.0, 0.02 }, stalk_end);
            let stalk = clamp(0.5 + (0.016 - 0.004 * clamp(-p.y / 0.5, 0.0, 1.0) - sd) * SCALE, 0.0, 1.0);
            let cover = max(blade, stalk);
            let v = veins[j * CELL + i] * blade;
            // Light and dark over the blade, and where it turns first: away from the main
            // veins, at the edge, in blotches.
            let light = 0.82 + 0.18 * noise(lf.seed, p, 9.0) - 0.08 * noise(lf.seed ^ 3, p, 40.0);
            var main: f32 = 1e9;
            for &lb in lf.lobes { main = min(main, segment_distance(p, float2 { 0.0, 0.0 }, lb.dir * lb.length)); }
            let edge = clamp(1.0 - inside(lf, p) / 0.06, 0.0, 1.0);
            let turn = clamp(0.15 + 0.55 * clamp(main / 0.16, 0.0, 1.0) + 0.25 * edge + 0.5 * (noise(lf.seed ^ 9, p, 3.5) - 0.5), 0.0, 1.0);
            var core: f32 = 0.0;
            var halo: f32 = 0.0;
            for &s in lf.spots {
                let d = length(p - float2 { s.x, s.y });
                let r = s.z * (0.85 + 0.3 * noise(lf.seed ^ 17, p, 30.0));
                core = max(core, clamp(0.5 + (r - d) * SCALE, 0.0, 1.0));
                halo = max(halo, clamp(1.0 - (d - r) / (s.z * 1.3), 0.0, 1.0));
            }
            let at = ((cy + j) * ATLAS_W + cx + i) * 4;
            shape[at] = byte(light);
            shape[at + 1] = byte(turn);
            shape[at + 2] = byte(v);
            shape[at + 3] = byte(cover);
            marks[at] = byte(max(v, stalk * (1.0 - blade)));
            marks[at + 1] = byte(core * blade);
            marks[at + 2] = byte(stalk * (1.0 - blade));
            marks[at + 3] = byte(halo * blade);
        }
    }
}

// The blades' outlines alone, MASK texels a side over the card's quad, each leaf's after
// the last: what the tree's shadow map casts (trees::draw_atlas_leaf). A card's half width
// in the leaf's frame is ACROSS_HALF of its blade's length.
let MASK = 64;
let ACROSS_HALF: f32 = 0.575;

fn silhouettes(out: f32[>..]&) {
    out.clear();
    out.resize(LEAVES * MASK * MASK, 0.0);
    let per = MASK / (QUAD.x * 2.0);
    for k in LEAVES {
        let lf = leaf_of(k);
        for j in MASK {
            for i in MASK {
                let p = float2 { -QUAD.x + (i + 0.5) / per, QUAD.z - (j + 0.5) / per };
                out[(k * MASK + j) * MASK + i] = clamp(0.5 + inside(lf, p) * per, 0.0, 1.0);
            }
        }
    }
}

// A leaf's outline at p (its frame) from silhouettes(), bilinear; 0 outside its square.
fn outline_at(masks: f32[>..]&, base: i64, x: f32, y: f32) -> f32 {
    let per = MASK / (QUAD.x * 2.0);
    let fx = (x + QUAD.x) * per - 0.5;
    let fy = (QUAD.z - y) * per - 0.5;
    guard fx > -1.0 && fy > -1.0 && fx < MASK && fy < MASK else { return 0.0; }
    let ix = floor(fx) as i64;
    let iy = floor(fy) as i64;
    let tx = fx - ix;
    let ty = fy - iy;
    let a = mask_at(masks, base, ix, iy);
    let b = mask_at(masks, base, ix + 1, iy);
    let c = mask_at(masks, base, ix, iy + 1);
    let e = mask_at(masks, base, ix + 1, iy + 1);
    return (a + (b - a) * tx) + ((c + (e - c) * tx) - (a + (b - a) * tx)) * ty;
}

fn mask_at(masks: f32[>..]&, base: i64, i: i64, j: i64) -> f32 {
    guard i >= 0 && j >= 0 && i < MASK && j < MASK else { return 0.0; }
    return masks[base + j * MASK + i];
}

fn byte(x: f32) -> u8 { (clamp(x, 0.0, 1.0) * 255.0 + 0.5) as u8 }

fn mips_of(w: i64, h: i64) -> i64 {
    var n = 1;
    while min(w, h) >> n > 0 { n++; }
    return n;
}

fn atlas_bytes() -> i64 {
    var n = 0;
    for level in mips_of(ATLAS_W, ATLAS_H) { n += (ATLAS_W >> level) * (ATLAS_H >> level) * 4; }
    return n;
}

// The atlas, both layers with their mips (atlas_bytes() each). The outline's mips keep
// each leaf's share of texels over a half as level 0 has it (Castaño's coverage-preserving
// mips), so a leaf at a distance under alpha-to-coverage doesn't thin away.
fn make(shape: u8[>..]&, marks: u8[>..]&) {
    shape.clear();
    marks.clear();
    shape.resize(atlas_bytes(), 0);
    marks.resize(atlas_bytes(), 0);
    var veins: f32[>..] = [];
    veins.resize(CELL * CELL, 0.0);
    for k in LEAVES { draw_leaf(k, shape, marks, veins); }
    var target: f32[8] = [0.0; 8];
    for k in LEAVES { target[k] = share_over_half(shape, 0, ATLAS_W, k, CELL, 1.0); }
    var from = 0;
    var w = ATLAS_W;
    var h = ATLAS_H;
    for level in 1..mips_of(ATLAS_W, ATLAS_H) {
        let to = from + w * h * 4;
        shrink(shape, from, to, w, h);
        shrink(marks, from, to, w, h);
        w /= 2;
        h /= 2;
        let cell = CELL >> level;
        if cell >= 2 {
            for k in LEAVES { keep_coverage(shape, to, w, k, cell, target[k]); }
        }
        from = to;
    }
}

fn shrink(out: u8[>..]&, from: i64, to: i64, w: i64, h: i64) {
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
}

// The share of leaf k's cell (`cell` texels a side, in a level `w` wide at `at`) whose
// outline times `scale` is over a half.
fn share_over_half(shape: u8[>..]&, at: i64, w: i64, k: i64, cell: i64, scale: f32) -> f32 {
    let cx = (k % ACROSS) * cell;
    let cy = (k / ACROSS) * cell;
    var n = 0;
    for j in cell {
        for i in cell {
            let a = shape[at + ((cy + j) * w + cx + i) * 4 + 3] / 255.0;
            if a * scale > 0.5 { n++; }
        }
    }
    return n / (cell * cell) as f32;
}

fn keep_coverage(shape: u8[>..]&, at: i64, w: i64, k: i64, cell: i64, target: f32) {
    var lo: f32 = 0.5;
    var hi: f32 = 4.0;
    for i in 14 {
        let mid = (lo + hi) * 0.5;
        if share_over_half(shape, at, w, k, cell, mid) < target { lo = mid; } else { hi = mid; }
    }
    let scale = (lo + hi) * 0.5;
    let cx = (k % ACROSS) * cell;
    let cy = (k / ACROSS) * cell;
    for j in cell {
        for i in cell {
            let o = at + ((cy + j) * w + cx + i) * 4 + 3;
            shape[o] = byte(shape[o] / 255.0 * scale);
        }
    }
}

// The leaves' colours by tint (0 green, 0.7 yellow-green, 1 gold, 1.5 orange, 2
// orange-red), linear: what the shaders will take from the same atlas.
fn tint_color(t: f32) -> float3 {
    let green = float3 { 0.045, 0.11, 0.012 };
    let lime = float3 { 0.3, 0.33, 0.02 };
    let gold = float3 { 0.62, 0.34, 0.01 };
    let orange = float3 { 0.6, 0.14, 0.008 };
    let red = float3 { 0.42, 0.045, 0.006 };
    if t < 0.7 { return lerp(green, lime, t / 0.7); }
    if t < 1.0 { return lerp(lime, gold, (t - 0.7) / 0.3); }
    if t < 1.5 { return lerp(gold, orange, (t - 1.0) / 0.5); }
    return lerp(orange, red, clamp((t - 1.5) / 0.5, 0.0, 1.0));
}

// A texel's colour, linear, lit from the front (the sky on its face) or seen against the
// sun (the light through it: deeper and more saturated, the veins and stalk dark), from
// its two layers' bytes and the leaf's tint.
fn texel_color(s: u8[4], m: u8[4], tint: f32, backlit: bool) -> float3 {
    let light = s[0] / 255.0;
    let turn = s[1] / 255.0;
    let v = s[2] / 255.0;
    let thick = m[0] / 255.0;
    let core = m[1] / 255.0;
    let stalk = m[2] / 255.0;
    let halo = m[3] / 255.0;
    // A texel turns ahead of its leaf or behind it; a tar spot's halo stays green longest.
    let t = clamp(tint + (turn - 0.5) * 0.7 - halo * 0.6, 0.0, 2.0);
    var c = tint_color(t) * light;
    let stalk_color = float3 { 0.2, 0.035, 0.015 };
    let tar = float3 { 0.012, 0.01, 0.008 };
    if backlit {
        // What passes: the colour squared and brightened, so it deepens, less through
        // the veins and the stalk.
        let deeper: f32 = 1.35;
        c = float3 { pow(c.x, deeper), pow(c.y, deeper), pow(c.z, deeper) } * 2.4;
        c = c * (1.0 - 0.55 * thick);
        c = lerp(c, stalk_color * 0.25, stalk);
    } else {
        c = lerp(c, c * 1.25 + float3 { 0.03, 0.03, 0.01 }, v * 0.6);
        c = lerp(c, stalk_color, stalk);
    }
    return lerp(c, tar, core);
}
