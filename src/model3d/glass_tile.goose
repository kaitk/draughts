// The window glass's wiping marks as one small tile (the window view's W8 and W9,
// build/notes/window-view/), made once from seeded strokes, no texture downloaded: the
// film a cleaning cloth leaves, thinner inside each wipe and gathered along its edges, and
// the fine hairline scratches grit in the cloth draws, circular arcs from rubbing and short
// straight wipes. Each pane takes the tile offset and turned by its own seed. It wraps, so
// a stroke over one edge goes on at the opposite one.
//
// A texel, RGBA8 with its mips (MIPS, bytes()): R and G the scratch's direction as its
// doubled angle times its depth (0.5 + 0.5 × depth × (cos 2θ, sin 2θ)), so a groove's two
// ways are one and a mip's mean keeps the deeper scratches' direction; B the scratch's
// depth (0 none) over the texel; A the film's thickness, 0.5 its mean. The glass's shader
// (shaders::ROOM_FRAG's ROOM_GLASS) reads it: the film's haze times A under its forward
// lobe, and a glint exp(-(s/w)²) × B where s = t · (l + v) is near 0 (Raymond et al.'s
// cone, through the glass), w widened by the pixel's footprint. Plain data.
namespace glass_tile;
import std;
import vec;
import math;

let SIDE = 512;
let MIPS = 10;
fn bytes() -> i64 {
    var sum = 0;
    for level in MIPS { sum += 4 * (SIDE >> level) * (SIDE >> level); }
    return sum;
}
// The metres the tile spans: a millimetre a texel.
let METRES: f32 = 0.512;

// What the strokes are: how many rubbing arcs and straight wipes scratch it, how many
// wipes of the cloth lay the film.
struct Strokes {
    arcs:   i64 = 70,
    wipes:  i64 = 25,
    swirls: i64 = 50,
}

// The tile from seed and its mips, level by level from the top, into out (bytes()).
fn make(seed: u64, st: Strokes, out: u8[>..]&) {
    var dir:     float2[>..] = [];
    var depth:   f32[>..]    = [];
    var residue: f32[>..]    = [];
    dir.resize(SIDE * SIDE, float2 { 1.0, 0.0 });
    depth.resize(SIDE * SIDE, 0.0);
    residue.resize(SIDE * SIDE, 0.5);
    var d = trees::Dice { trees::mixed(seed + 77) };
    // The film: each wipe of the cloth a broad arc band, thinner inside and drawn into fine
    // streaks along the stroke by the cloth's weave, the residue pushed to its edges in soft
    // ridges, most to the outer one.
    for k in st.swirls {
        let r = trees::roll_between(d, 50.0, 200.0);
        let c = float2 { trees::roll(d) * SIDE, trees::roll(d) * SIDE };
        let a0 = trees::roll(d) * TAU;
        let span = trees::roll_between(d, 0.5, 1.6);
        let band = trees::roll_between(d, 30.0, 60.0);
        swirl(residue, c, r, a0, span, band, trees::roll(d) * TAU);
    }
    // A slow unevenness over it, a few centimetres across.
    let ph = float4 { trees::roll(d) * TAU, trees::roll(d) * TAU, trees::roll(d) * TAU, trees::roll(d) * TAU };
    var mean: f32 = 0.0;
    for j in SIDE {
        for i in SIDE {
            let u = TAU * i / SIDE;
            let v = TAU * j / SIDE;
            let slow = 0.06 * sin(3.0 * u + 2.0 * v + ph.x) + 0.05 * sin(5.0 * v - 4.0 * u + ph.y)
                + 0.04 * sin(9.0 * u + 7.0 * v + ph.z) + 0.03 * sin(13.0 * v + 11.0 * u + ph.w);
            residue[j * SIDE + i] += slow;
            mean += residue[j * SIDE + i];
        }
    }
    mean = mean / (SIDE * SIDE);
    // The scratches: rubbing arcs 3 to 12 cm long on radii of 6 to 25 cm, and straight
    // wipes 4 to 16 cm, slightly tilted, shallower.
    for k in st.arcs {
        let r = trees::roll_between(d, 60.0, 250.0);
        let c = float2 { trees::roll(d) * SIDE, trees::roll(d) * SIDE };
        let a0 = trees::roll(d) * TAU;
        let length = trees::roll_between(d, 30.0, 120.0);
        let deep = trees::roll_between(d, 0.3, 1.0);
        let steps = (length * 2.0) as i64 + 2;
        for n in steps {
            let a = a0 + length / r * n / (steps - 1);
            let p = c + float2 { cos(a), sin(a) } * r;
            scratch_at(dir, depth, p, float2 { -sin(a), cos(a) }, deep, c, r);
        }
    }
    for k in st.wipes {
        let p0 = float2 { trees::roll(d) * SIDE, trees::roll(d) * SIDE };
        let length = trees::roll_between(d, 40.0, 160.0);
        let t = normalize(float2 { 1.0, trees::roll_between(d, -0.05, 0.05) });
        let deep = trees::roll_between(d, 0.2, 0.6);
        let steps = (length * 2.0) as i64 + 2;
        for n in steps {
            let p = p0 + t * (length * n / (steps - 1));
            scratch_at(dir, depth, p, t, deep, float2 { 0.0, 0.0 }, 0.0);
        }
    }
    var texel: float4[>..] = [];
    texel.resize(SIDE * SIDE, float4_0);
    for i in SIDE * SIDE {
        let t = dir[i];
        let deep = depth[i];
        texel[i] = float4 { deep * (t.x * t.x - t.y * t.y), deep * 2.0 * t.x * t.y, deep, residue[i] - mean + 0.5 };
    }
    out.clear();
    out.resize(bytes(), 0);
    var at = 0;
    for level in MIPS {
        let w = SIDE >> level;
        if level > 0 {
            // Each texel the mean of four of the level above, in place.
            let up = w * 2;
            for y in w {
                for x in w {
                    texel[y * w + x] = (texel[2 * y * up + 2 * x] + texel[2 * y * up + 2 * x + 1] + texel[(2 * y + 1) * up + 2 * x]
                                        + texel[(2 * y + 1) * up + 2 * x + 1]) * 0.25;
                }
            }
        }
        for i in w * w {
            let v = texel[i];
            out[at + 4 * i] = byte(0.5 + 0.5 * v.x);
            out[at + 4 * i + 1] = byte(0.5 + 0.5 * v.y);
            out[at + 4 * i + 2] = byte(v.z);
            out[at + 4 * i + 3] = byte(v.w);
        }
        at += 4 * w * w;
    }
}

fn byte(x: f32) -> u8 { (clamp(x, 0.0, 1.0) * 255.0 + 0.5) as u8 }

// The texel (i, j) wrapped onto the tile.
fn wrapped(i: i64, j: i64) -> i64 { (j % SIDE) * SIDE + i % SIDE }

// A scratch's point p with its direction t: the texels round it covered as a hairline a
// texel wide, the deepest kept with its direction. With r > 0 the distance is to the arc's
// circle round c (exact across the hairline), else to the line through p along t.
fn scratch_at(dir: float2[>..]&, depth: f32[>..]&, p: float2, t: float2, deep: f32, c: float2, r: f32) {
    let i0 = floor(p.x) as i64;
    let j0 = floor(p.y) as i64;
    for dj in -1..2 {
        for di in -1..2 {
            let q = float2 { (i0 + di) + 0.5, (j0 + dj) + 0.5 };
            let off = q - p;
            let dist = if r > 0.0 { abs(length(q - c) - r) } else { abs(off.x * t.y - off.y * t.x) };
            let cover = clamp(1.0 - dist / 0.7, 0.0, 1.0) * deep;
            guard cover > 0.0 else { continue; }
            let k = wrapped(i0 + di, j0 + dj);
            if cover > depth[k] {
                depth[k] = cover;
                dir[k] = t;
            }
        }
    }
}

// One wipe of the cloth: an arc band round c, radius r, from a0 over span radians, band
// texels wide; inside it the film thinner, in streaks along the stroke (their phase), along
// its edges soft ridges of residue, the outer twice the inner.
fn swirl(residue: f32[>..]&, c: float2, r: f32, a0: f32, span: f32, band: f32, phase: f32) {
    let reach = r + 0.5 * band + 12.0;
    let i0 = floor(c.x - reach) as i64;
    let j0 = floor(c.y - reach) as i64;
    let n = (2.0 * reach) as i64 + 2;
    for dj in n {
        for di in n {
            let q = float2 { (i0 + di) + 0.5 - c.x, (j0 + dj) + 0.5 - c.y };
            let a = atan2(q.y, q.x) - a0;
            let turn = a - TAU * floor(a / TAU);
            // Faded in and out over a fifth of a radian at the arc's ends.
            let ends = clamp(min(turn, span - turn) / 0.2, 0.0, 1.0);
            guard ends > 0.0 else { continue; }
            let out = length(q) - r;
            let off = abs(out) - 0.5 * band;
            let ridge = exp(-(off * off) / 100.0) * (if out > 0.0 { 0.1 } else { 0.05 });
            let inside = clamp(-off / 8.0, 0.0, 1.0);
            let streaks = 0.5 + 0.5 * sin(1.3 * out + phase + 2.0 * sin(0.21 * out + phase));
            let k = wrapped(i0 + di, j0 + dj);
            residue[k] = residue[k] * (1.0 - (0.15 + 0.1 * streaks) * inside * ends) + ridge * ends;
        }
    }
}

// What a pane shows of the tile seen toward the sun, for the previews (the tuner's
// --dump-glass-tile): the glints of its scratches and its film's haze at texel (i, j) of a
// pane a metre and a half from the eye, the sun's image at sun (texels from the pane's
// middle, behind it), sun_up the sun's elevation's tangent; film and glint the strengths.
fn lit_at(tile: u8[>..]&, i: i64, j: i64, w: i64, h: i64, sun: float2, film: f32, glint: f32) -> f32 {
    let k = wrapped(i, j) * 4;
    let c2:    f32 = tile[k] / 127.5 - 1.0;
    let s2:    f32 = tile[k + 1] / 127.5 - 1.0;
    let deep:  f32 = tile[k + 2] / 255.0;
    let thick: f32 = tile[k + 3] / 255.0;
    let eye:   f32 = 1500.0;
    let v = normalize(float3 { i - 0.5 * w, j - 0.5 * h, -eye });
    let l = normalize(float3 { sun.x / eye, sun.y / eye, 1.0 });
    // The groove's direction from its doubled angle.
    let half = 0.5 * atan2(s2, c2);
    let t = float2 { cos(half), sin(half) };
    let s = t.x * (l.x + v.x) + t.y * (l.y + v.y);
    let g = exp(-(s / 0.02) * (s / 0.02)) * deep;
    let from_sun = acos(clamp(-(v.x * l.x + v.y * l.y + v.z * l.z), -1.0, 1.0));
    let lobe = exp(-from_sun / 0.25);
    return (glint * g + film * thick) * lobe;
}
