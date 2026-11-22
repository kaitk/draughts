// The sills' limestone tile (build/notes/paint-research/'s Vasalemma-type stone), made once
// when the shell is first shown: 256 mm of honed crinoidal limestone a tile, a quarter of a
// millimetre a texel. A whitish grey with faint clouds and a dense speckle of crinoid
// grains, 0.3 to 1.4 mm, paler and darker than the stone, and a few dirt-filled pores.
// Stored RGBA8 with its mips: R the albedo over the stone's mean (STONE_LOW to
// STONE_LOW + 1, its mean 1), G the pores (rougher), B the slow patches the polished band
// follows, A the honed roughness's unevenness (0 to 1 each).
namespace room_shell;
import std;
import vec;
import math;

let STONE_SIDE = 1024;
let STONE_MIPS = 11;
let STONE_TILE:  f32 = 0.256;          // metres a tile covers
let STONE_TEXEL: f32 = 0.25;           // millimetres a texel
let STONE_LOW:   f32 = 0.4;            // R's 0

fn stone_bytes() -> i64 {
    var sum = 0;
    for level in STONE_MIPS { sum += 4 * (STONE_SIDE >> level) * (STONE_SIDE >> level); }
    return sum;
}

// Grains or pores, `count` of them, radius r0 to r1 mm, a little oval, stamped into mask
// (0 to 1, the tile wrapped) with a soft rim of 0.2 mm.
fn stamp_grains(mask: f32[>..]&, count: i64, r0: f32, r1: f32, seed: i64) {
    let n = STONE_SIDE;
    let rim: f32 = 0.2 / STONE_TEXEL;
    for i in count {
        let cx = surfaces::hash(i, seed) * n;
        let cy = surfaces::hash(i, seed + 1) * n;
        let r = (r0 + (r1 - r0) * surfaces::hash(i, seed + 2)) / STONE_TEXEL;
        let squash = 0.7 + 0.7 * surfaces::hash(i, seed + 3);
        let reach = (r * max(squash, 1.0 / squash) + rim + 1.0) as i64;
        let x0 = floor(cx) as i64;
        let y0 = floor(cy) as i64;
        for dy in -reach..reach + 1 {
            for dx in -reach..reach + 1 {
                let fx = x0 + dx + 0.5 - cx;
                let fy = (y0 + dy + 0.5 - cy) * squash;
                let d = sqrt(fx * fx + fy * fy);
                let lo = r - rim;
                let hi = r + rim;
                let m = 1.0 - smoothstep(lo, hi, d);
                guard m > 0.0 else { continue; }
                let at = (((y0 + dy) % n + n) % n) * n + ((x0 + dx) % n + n) % n;
                mask[at] = max(mask[at], m);
            }
        }
    }
}

// The tile and its mips, level by level from the top, into out (RGBA8, stone_bytes()).
fn stone_tile(out: u8[>..]&) {
    let n = STONE_SIDE;
    out.resize(stone_bytes(), 0);
    // Grains a square centimetre: the pale ones, the dark, the pores.
    let cm2 = (n * STONE_TEXEL / 10.0) * (n * STONE_TEXEL / 10.0);
    var pale:  f32[>..] = [];
    var dark:  f32[>..] = [];
    var pores: f32[>..] = [];
    pale.resize(n * n, 0.0);
    dark.resize(n * n, 0.0);
    pores.resize(n * n, 0.0);
    stamp_grains(pale, (4.0 * cm2) as i64, 0.3, 1.4, 23);
    stamp_grains(dark, (2.0 * cm2) as i64, 0.3, 1.1, 24);
    stamp_grains(pores, (0.25 * cm2) as i64, 0.2, 0.6, 25);
    // The albedo over the stone's: clouds of 64 and 8 mm (±3 %), the pale grains half way to
    // a stone 15 % lighter (in sRGB), the dark 22 % darker, the pores 40 %; then over its mean.
    let paler: f32 = 1.36;
    var s: float4[>..] = [];
    s.resize(n * n, float4_0);
    var sum: f64 = 0.0;
    for y in n {
        for x in n {
            let fx: f32 = x;
            let fy: f32 = y;
            let i = y * n + x;
            let cloud = 0.5 * (2.0 * tile_noise(fx, fy, 256, 256, 31, n) - 1.0) + 0.5 * (2.0 * tile_noise(fx, fy, 32, 32, 37, n) - 1.0);
            var f = 1.0 + 0.03 * cloud;
            f = f * (1.0 - 0.5 * pale[i]) + 0.5 * pale[i] * paler;
            f *= 1.0 - 0.22 * dark[i];
            f *= 1.0 - 0.4 * pores[i];
            sum += f;
            let band = 0.5 * tile_noise(fx, fy, 64, 64, 41, n) + 0.5 * tile_noise(fx, fy, 128, 128, 43, n);
            let honed = tile_noise(fx, fy, 64, 64, 47, n);
            s[i] = float4 { f, pores[i], band, honed };
        }
    }
    let mean = (sum / (n * n)) as f32;
    for i in n * n { s[i].x /= mean; }
    var at = 0;
    for level in STONE_MIPS {
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
            out[at + 4 * i] = (clamp(255.0 * (v.x - STONE_LOW), 0.0, 255.0) + 0.5) as u8;
            out[at + 4 * i + 1] = (clamp(255.0 * v.y, 0.0, 255.0) + 0.5) as u8;
            out[at + 4 * i + 2] = (clamp(255.0 * v.z, 0.0, 255.0) + 0.5) as u8;
            out[at + 4 * i + 3] = (clamp(255.0 * v.w, 0.0, 255.0) + 0.5) as u8;
        }
        at += 4 * w * w;
    }
}
