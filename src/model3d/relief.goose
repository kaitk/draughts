// The quiet paint's relief tile (build/notes/paint-research/'s fine relief), made once at
// startup: 256 mm of painted pine a tile, half a millimetre a texel, its grain up the tile.
// The height is brush ridges laid off along the grain in bands a brush wide, each band's
// stroke unloading from its lap and levelled in patches, with a bead at its edges; the
// pine's latewood telegraphing through the coats; and a fine orange peel; micrometres
// high, so it shows in the sheen and in grazing light, never as streaks of colour. Stored
// RGBA8 with its mips: R and G the slopes across and along (RELIEF_SLOPE full scale), B the
// sheen's slow unevenness (-1 to 1), A how much the slopes under a texel spread (Toksvig's
// variance, as RELIEF_SLOPE scales them), 0 at the top level.
namespace room_shell;
import std;
import vec;
import math;

let RELIEF_SIDE = 512;
let RELIEF_MIPS = 10;
let RELIEF_TILE:  f32 = 0.256;         // metres a tile covers
let RELIEF_SLOPE: f32 = 0.02;          // the slope (radians) at 255 or 1, 128 flat
let RELIEF_TEXEL: f32 = 500.0;         // micrometres a texel

// A hash of a lattice point, 0 to 1, its cells wrapped every px across and py along.
fn lattice(x: i64, y: i64, px: i64, py: i64, seed: i64) -> f32 {
    return surfaces::hash(((x % px) + px) % px + 4096 * (((y % py) + py) % py), seed);
}

// Value noise (0 to 1) at texel (x, y) of cells cx texels across and cy along, tiling a
// tile `side` texels square (a multiple of each cell).
fn tile_noise(x: f32, y: f32, cx: i64, cy: i64, seed: i64, side: i64 = RELIEF_SIDE) -> f32 {
    let px = side / cx;
    let py = side / cy;
    let fx = x / cx;
    let fy = y / cy;
    let ix = floor(fx) as i64;
    let iy = floor(fy) as i64;
    let tx = fx - ix;
    let ty = fy - iy;
    let ux = tx * tx * (3.0 - 2.0 * tx);
    let uy = ty * ty * (3.0 - 2.0 * ty);
    let a = lattice(ix, iy, px, py, seed);
    let b = lattice(ix + 1, iy, px, py, seed);
    let c = lattice(ix, iy + 1, px, py, seed);
    let d = lattice(ix + 1, iy + 1, px, py, seed);
    return lerp(lerp(a, b, ux), lerp(c, d, ux), uy);
}

// The relief's height (micrometres) at texel (x across, y along).
let BRUSH_BAND = 128;                  // 64 mm
let BRUSH_UM: f32 = 2.5;
let GRAIN_UM: f32 = 1.5;
let PEEL_UM:  f32 = 1.5;
fn relief_height(x: i64, y: i64) -> f32 {
    let fx: f32 = x;
    let fy: f32 = y;
    // The brush: ridges a fraction of a millimetre to a few apart, drawn out along the
    // stroke, wandering a little across.
    let wander = 3.6 * (tile_noise(0.0, fy, 1, 64, 3) - 0.5);
    let ax = fx + wander;
    let ridges = 0.6 * (2.0 * tile_noise(ax, fy, 2, 32, 5) - 1.0) + 0.4 * (2.0 * tile_noise(ax, fy, 4, 64, 7) - 1.0);
    let band = x / BRUSH_BAND;
    let across = (x % BRUSH_BAND) as f32 / BRUSH_BAND;
    // Each band's stroke from its lap, loaded there and thinning along it.
    let lap = surfaces::hash(band, 11) * RELIEF_SIDE;
    var along = (fy - lap) / RELIEF_SIDE;
    along -= floor(along);
    let unload = if surfaces::hash(band, 13) < 0.5 { 1.25 - 0.75 * along } else { 0.5 + 0.75 * along };
    let lo: f32 = 0.35;
    let hi: f32 = 0.75;
    let level = smoothstep(lo, hi, tile_noise(fx, fy, 64, 64, 17));
    let edge = min(across, 1.0 - across) * BRUSH_BAND;
    let bead = exp(-(edge / 3.0) * (edge / 3.0));
    let lap_d = min(along, 1.0 - along) * RELIEF_SIDE;
    let lap_bump = exp(-(lap_d / 8.0) * (lap_d / 8.0));
    let brush = BRUSH_UM * (unload * (1.0 - 0.7 * level) * ridges + 0.6 * bead + 0.5 * lap_bump);
    // The pine's latewood, a band every 4 mm, wavering along the grain.
    let wob = 10.0 * (tile_noise(0.0, fy, 1, 128, 19) - 0.5) + 1.2 * (tile_noise(fx, fy, 8, 32, 23) - 0.5);
    var ring = (fx + wob) / 8.0;
    ring -= floor(ring);
    let late = exp(-((ring - 0.5) / 0.11) * ((ring - 0.5) / 0.11));
    // The orange peel, even each way.
    let peel = 2.0 * tile_noise(fx, fy, 2, 2, 29) - 1.0;
    return brush + GRAIN_UM * late + PEEL_UM * peel;
}

// The tile and its mips, level by level from the top, into out (RGBA8, relief_bytes()).
fn relief_bytes() -> i64 {
    var sum = 0;
    for level in RELIEF_MIPS { sum += 4 * (RELIEF_SIDE >> level) * (RELIEF_SIDE >> level); }
    return sum;
}

fn relief_tile(out: u8[>..]&) {
    let n = RELIEF_SIDE;
    out.resize(relief_bytes(), 0);
    var h: f32[>..] = [];
    h.resize(n * n, 0.0);
    for y in n {
        for x in n { h[y * n + x] = relief_height(x, y); }
    }
    // The slopes (radians) and the sheen's unevenness at the top level, kept as floats for
    // the mips: slope across, along, its square, the sheen.
    var s: float4[>..] = [];
    s.resize(n * n, float4_0);
    for y in n {
        for x in n {
            let dx = (h[y * n + (x + 1) % n] - h[y * n + (x + n - 1) % n]) / (2.0 * RELIEF_TEXEL);
            let dy = (h[((y + 1) % n) * n + x] - h[((y + n - 1) % n) * n + x]) / (2.0 * RELIEF_TEXEL);
            let fx: f32 = x;
            let fy: f32 = y;
            let sheen = 0.6 * (2.0 * tile_noise(fx, fy, 64, 64, 31) - 1.0) + 0.4 * (2.0 * tile_noise(fx, fy, 128, 128, 37) - 1.0);
            s[y * n + x] = float4 { dx, dy, dx * dx + dy * dy, sheen };
        }
    }
    var at = 0;
    for level in RELIEF_MIPS {
        let w = n >> level;
        if level > 0 {
            // Each texel the mean of four of the level above, in place.
            let up = w * 2;
            for y in w {
                for x in w {
                    let a = s[(2 * y) * up + 2 * x];
                    let b = s[(2 * y) * up + 2 * x + 1];
                    let c = s[(2 * y + 1) * up + 2 * x];
                    let d = s[(2 * y + 1) * up + 2 * x + 1];
                    s[y * w + x] = (a + b + c + d) * 0.25;
                }
            }
        }
        for i in w * w {
            let v = s[i];
            let spread = sqrt(max(v.z - v.x * v.x - v.y * v.y, 0.0));
            out[at + 4 * i] = (clamp(128.0 + 127.0 * v.x / RELIEF_SLOPE, 0.0, 255.0) + 0.5) as u8;
            out[at + 4 * i + 1] = (clamp(128.0 + 127.0 * v.y / RELIEF_SLOPE, 0.0, 255.0) + 0.5) as u8;
            out[at + 4 * i + 2] = (clamp(128.0 + 127.0 * v.w, 0.0, 255.0) + 0.5) as u8;
            out[at + 4 * i + 3] = (clamp(255.0 * spread / RELIEF_SLOPE, 0.0, 255.0) + 0.5) as u8;
        }
        at += 4 * w * w;
    }
}
