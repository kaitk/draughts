// The window hardware's antique brass tile (task 129), made once when the box window first
// shows: 64 mm a tile, 62.5 µm a texel, laid on the hardware by world position (ROOM_FRAG's
// window metal). Wrapped value noise at whole periods: clouds of 4 to 13 mm, blots of 1.3 to
// 2.7 mm and flecks of 0.3 to 0.7 mm under a slight warp, summed and ranked into one field
// whose values run evenly from 0 to 1, so the brass's states (bare, tarnish, deposit) cover
// the share a threshold on it says; and sparse pits of 0.2 to 0.4 mm. Stored RGBA8 with its
// mips: R the rank, G the pits, B and A unused.
namespace room_shell;
import std;
import vec;
import math;

let BRASS_SIDE = 1024;
let BRASS_MIPS = 11;
let BRASS_TILE: f32 = 0.064;           // metres a tile covers
let BRASS_BINS = 4096;                 // the rank's histogram

fn brass_bytes() -> i64 {
    var sum = 0;
    for level in BRASS_MIPS { sum += 4 * (BRASS_SIDE >> level) * (BRASS_SIDE >> level); }
    return sum;
}

// Value noise (-1 to 1) at (x, y) texels with `per` cells a tile.
fn brass_noise(x: f32, y: f32, per: i64, seed: i64) -> f32 {
    return 2.0 * tile_noise(x, y, BRASS_SIDE / per, BRASS_SIDE / per, seed, BRASS_SIDE) - 1.0;
}

// The tile's level 0 into out (RGBA8, brass_bytes(); the mips left to put_rgba).
fn brass_tile(out: u8[>..]&) {
    let n = BRASS_SIDE;
    out.resize(brass_bytes(), 0);
    var field: f32[>..] = [];
    field.resize(n * n, 0.0);
    var lo: f32 = 1.0e9;
    var hi: f32 = -1.0e9;
    for y in n {
        for x in n {
            let fx: f32 = x;
            let fy: f32 = y;
            let clouds = 0.6 * brass_noise(fx, fy, 5, 61) + 0.36 * brass_noise(fx, fy, 9, 62) + 0.24 * brass_noise(fx, fy, 16, 63);
            // The warp: about 2 texels (0.13 mm), period 20 and 40.
            let wx = fx + 2.0 * (brass_noise(fx, fy, 20, 64) + 0.5 * brass_noise(fx, fy, 40, 65));
            let wy = fy + 2.0 * (brass_noise(fx, fy, 20, 66) + 0.5 * brass_noise(fx, fy, 40, 67));
            let blots = brass_noise(wx, wy, 32, 68) + 0.7 * brass_noise(wx, wy, 64, 69);
            let flecks = brass_noise(wx, wy, 128, 70) + 0.6 * brass_noise(wx, wy, 256, 71);
            let v = clouds + 0.7 * blots + flecks;
            field[y * n + x] = v;
            lo = min(lo, v);
            hi = max(hi, v);
        }
    }
    // The rank: each value's share of the field below it, by a histogram.
    var count: i64[>..] = [];
    count.resize(BRASS_BINS + 1, 0);
    let bins: f32 = BRASS_BINS - 1;
    let scale = bins / max(hi - lo, 1.0e-6);
    for v in field { count[((v - lo) * scale) as i64] += 1; }
    var below: f32[>..] = [];
    below.resize(BRASS_BINS, 0.0);
    let all: f32 = n * n;
    var run: f32 = 0.0;
    for b in BRASS_BINS {
        let c: f32 = count[b];
        below[b] = (run + 0.5 * c) / all;
        run += c;
    }
    for y in n {
        for x in n {
            let fx: f32 = x;
            let fy: f32 = y;
            let i = y * n + x;
            let rank = below[((field[i] - lo) * scale) as i64];
            let fine = brass_noise(fx, fy, 256, 72) + 0.5 * brass_noise(fx, fy, 512, 73);
            let pit = clamp((fine - 0.95) / 0.25, 0.0, 1.0);
            out[4 * i] = (clamp(255.0 * rank, 0.0, 255.0) + 0.5) as u8;
            out[4 * i + 1] = (255.0 * pit + 0.5) as u8;
            out[4 * i + 2] = 0;
            out[4 * i + 3] = 255;
        }
    }
}
