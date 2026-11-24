// The stove's relief (option A of build/notes/stove/): a small height atlas made once at
// startup, as the paint's relief tile is: the frieze's palmette tile (0.22 × 0.16 m, rows 0
// to PALMETTE_ROWS, its top first), which the crest's plates take too, and the waist's
// rosette tile (0.22 × 0.08 m, the rows after). Stored RGBA8: R and G the height's slopes
// across and up the tile (metres a metre, STOVE_SLOPE full scale, 128 flat), B the height
// (STOVE_RELIEF_H at 255), A 255. ROOM_FRAG's glaze turns its normal by the slopes and pools
// the glaze in the hollows.
namespace room_shell;
import std;
import vec;
import math;

let STOVE_RELIEF_SIDE = 256;
let STOVE_RELIEF_MIPS = 5;
let PALMETTE_ROWS = 176;
let STOVE_SLOPE:    f32 = 1.5;
let STOVE_RELIEF_H: f32 = 0.0035;

// A rounded rib's height (0 to 1) at distance q of its half width (1 - q², 0 past it).
fn rib(q: f32) -> f32 { max(1.0 - q * q, 0.0) }

// The palmette's height (metres) at x across the tile from its middle and y up from its
// foot: seven lobes fanned from a point over the base bar, the middle one longest, each
// pointed at its tip; two volutes either side of the fan's foot; the bar under them.
fn palmette_height(x: f32, y: f32) -> f32 {
    var h: f32 = 0.0;
    let foot = float2 { 0.0, 0.032 };
    let p = float2 { x, y } - foot;
    for k in 7 {
        let i = k - 3;
        let a: f32 = (90.0 + 21.0 * i) * PI / 180.0;
        let along = 0.108 - 0.011 * abs(i);
        let d = float2 { cos(a), sin(a) };
        let t = dot(p, d);
        guard t > 0.004 && t < along else { continue; }
        let u = t / along;
        let half = 0.0105 * pow(sin(PI * min(u * 1.1, 1.0)), 0.7 as f32) * (0.45 + 0.55 * u);
        guard half > 0.0003 else { continue; }
        let across = p.x * d.y - p.y * d.x;
        h = max(h, rib(across / half) * (0.75 + 0.25 * u));
    }
    for side in SIDES {
        let c = float2 { 0.03 * side, 0.03 };
        let r = length(float2 { x, y } - c);
        h = max(h, 0.8 * rib((r - 0.012) / 0.0035));
        h = max(h, 0.9 * rib(r / 0.0042));
    }
    if abs(x) < 0.062 { h = max(h, 0.6 * rib((y - 0.014) / 0.0042) * min((0.062 - abs(x)) / 0.004, 1.0)); }
    return h * STOVE_RELIEF_H;
}

// The rosette's height at x across its tile from the middle and y up from its foot: eight
// petals round a domed boss, a bead either side.
fn rosette_height(x: f32, y: f32) -> f32 {
    let p = float2 { x, y - 0.04 };
    let r = length(p);
    let a = if r > 1e-6 { atan2(p.y, p.x) } else { 0.0 };
    let petal = 0.026 * (0.55 + 0.45 * pow(abs(cos(4.0 * a)), 0.8 as f32));
    var h = 0.85 * rib(r / petal) * min(r / 0.007, 1.0);
    h = max(h, 1.1 * rib(r / 0.0075));
    for side in SIDES { h = max(h, 0.7 * rib(length(p - float2 { 0.07 * side, 0.0 }) / 0.006)); }
    return h * STOVE_RELIEF_H;
}

fn relief_byte(v: f32) -> u8 { clamp(v * 127.0 + 128.0, 0.0, 255.0) as u8 }

// The atlas's top level into px, sized for its mips (render3d::put_rgba makes them).
fn stove_relief(px: u8[>..]&) {
    let n = STOVE_RELIEF_SIDE;
    var total = 0;
    for level in STOVE_RELIEF_MIPS { total += 4 * (n >> level) * (n >> level); }
    px.resize(total, 0);
    for row in n {
        let palmette = row < PALMETTE_ROWS;
        let rows = if palmette { PALMETTE_ROWS } else { n - PALMETTE_ROWS };
        let high: f32 = if palmette { 0.16 } else { 0.08 };
        let r = if palmette { row } else { row - PALMETTE_ROWS };
        let y = (1.0 - (r + 0.5) / rows) * high;
        let dy = high / rows;
        let dx: f32 = 0.22 / n;
        for col in n {
            let x = ((col + 0.5) / n - 0.5) * 0.22;
            var h:  f32 = 0.0;
            var sx: f32 = 0.0;
            var sy: f32 = 0.0;
            if palmette {
                h = palmette_height(x, y);
                sx = (palmette_height(x + 0.5 * dx, y) - palmette_height(x - 0.5 * dx, y)) / dx;
                sy = (palmette_height(x, y + 0.5 * dy) - palmette_height(x, y - 0.5 * dy)) / dy;
            } else {
                h = rosette_height(x, y);
                sx = (rosette_height(x + 0.5 * dx, y) - rosette_height(x - 0.5 * dx, y)) / dx;
                sy = (rosette_height(x, y + 0.5 * dy) - rosette_height(x, y - 0.5 * dy)) / dy;
            }
            let at = 4 * (row * n + col);
            px[at] = relief_byte(sx / STOVE_SLOPE);
            px[at + 1] = relief_byte(sy / STOVE_SLOPE);
            px[at + 2] = clamp(h / STOVE_RELIEF_H * 255.0, 0.0, 255.0) as u8;
            px[at + 3] = 255;
        }
    }
}

fn stove_relief_bytes() -> i64 {
    var total = 0;
    for level in STOVE_RELIEF_MIPS { total += 4 * (STOVE_RELIEF_SIDE >> level) * (STOVE_RELIEF_SIDE >> level); }
    return total;
}
