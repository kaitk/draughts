// The maple's bark grown once at startup by the fracture of a stretched outer layer (task
// 117, after Lefebvre and Neyret 2002, "Synthesizing Bark"): as the stem thickens, the cork
// can hold only narrower plates, so where a plate across a row is too wide the weakest cork
// opens, and the crack runs up and down the stem, leaning, pulled into cracks near it, until
// it meets one or the cork round it is no longer overstretched. Each crack texel keeps the
// time it opened, so one run gives every age: BARK_LAYERS snapshots (BARK_AGES) from
// branch bark with its first thin cracks to the old trunk's broad interlaced ridges between
// deep furrows. A furrow is wider and deeper the longer it has been open, and narrows toward
// a crack's free ends (Kratt et al. 2015). Part of trees, in its namespace; the tile wraps
// both ways, BARK_W × BARK_H texels for BARK_ACROSS × BARK_ALONG as the first tile.
//
// Two RGBA8 textures, each channel one age: the height (BARK_HEIGHT_MM a step from 128) and
// the cavity, how open each texel is to the sky (1 open, its neighbourhood's height over
// it). The shader blends the channels by the wood's age and takes the normal from the
// height's slope (shaders::TREE_WOOD_FRAG). A third, the detail (task 117's round two),
// holds what every age shares at the small scale: R the cork's fine relief (its cells' small
// domes between grooves, and its fibres along the stem), G the secondary cracks in the
// plates (1 none, 0 the deepest), B the colour's drift (0.5 the mean; lower a warmer
// grey-brown, higher an olive grey), A the lichen's cover.
namespace trees;
import std;
import vec;
import math;

let BARK_LAYERS = 4;
let BARK_AGES: f32[4] = [0.45, 0.65, 0.82, 1.0];
// A texel's height step in the height texture, millimetres (128 the mean).
let BARK_HEIGHT_MM: f32 = 0.1;

// The growth: time runs from 0 (a twig) to 1 (the old trunk); the cork first cracks at
// T_CRACK, in BARK_STEPS steps to 1. The widest plate it holds at time t is
// PLATE_END · t^-PLATE_EXP texels, its strength varying by STRENGTH_SPREAD.
let BARK_T_CRACK: f32 = 0.42;
let BARK_STEPS = 36;
let BARK_PLATE_END:       f32 = 54.0;
let BARK_PLATE_EXP:       f32 = 1.6;
let BARK_STRENGTH_SPREAD: f32 = 0.35;
// A crack's run along the stem at least (texels), its lean (texels across a row, the
// spread of its start and of each row's drift), and the reach and odds of a crack near it
// pulling it over.
let BARK_RUN_LEAST = 70;
let BARK_RUN_MOST = 300;
let BARK_LEAN:       f32 = 0.42;
let BARK_LEAN_DRIFT: f32 = 0.07;
let BARK_PULL_REACH = 16;
let BARK_PULL_ODDS: f32 = 0.8;
// How far from a free end a crack is at its full width (texels).
let BARK_TAPER = 60.0;
// The snapshot: the oldest furrows' depth (mm), a new furrow's half width and how much the
// oldest widen (texels), the ridges' crowns' height against the depth, the cork's grain.
let BARK_RELIEF_MM:   f32 = 9.0;
let BARK_WIDTH_YOUNG: f32 = 1.5;
let BARK_WIDTH_OLD:   f32 = 8.5;
let BARK_CROWN:       f32 = 0.45;
let BARK_GRAIN_MM:    f32 = 0.7;
let BARK_CRACK_NONE:  f32 = 1e9;
let BARK_LENTICELS = 220;
// The plates' edges jagged (bark_layers' `jagged`): the distance to the crack moved by up
// to EDGE_JAG of the furrow's half width either way, by noise of a few texels.
let BARK_EDGE_JAG: f32 = 0.7;
// The secondary cracks: FINE_CRACKS short ones along the stem (FINE_RUN_LEAST..MOST
// texels) and CROSS_CRACKS shorter ones across the ridges' crowns (CROSS_RUN_LEAST..MOST),
// each stopping at a furrow. The cork's cells, CELLS_ACROSS × CELLS_ALONG over the tile.
let BARK_FINE_CRACKS = 1400;
let BARK_FINE_RUN_LEAST = 6;
let BARK_FINE_RUN_MOST = 34;
let BARK_CROSS_CRACKS = 700;
let BARK_CROSS_RUN_LEAST = 3;
let BARK_CROSS_RUN_MOST = 12;
let BARK_CELLS_ACROSS = 64;
let BARK_CELLS_ALONG = 72;

// The bark's three textures with their mips, bark_bytes() each; with `jagged` the plates'
// edges broken by noise (BARK_EDGE_JAG), else as round one made them.
fn bark_layers(heights: u8[>..]&, cavities: u8[>..]&, details: u8[>..]&, jagged: bool) {
    let n = BARK_W * BARK_H;
    var crack:    f32[>..] = [];
    var taper:    f32[>..] = [];
    var tough:    f32[>..] = [];
    var strength: f32[>..] = [];
    crack.resize(n, BARK_CRACK_NONE);
    taper.resize(n, 0.0);
    tough.resize(n, 0.0);
    strength.resize(n, 1.0);
    bark_cork(tough, strength);
    bark_grow(crack, taper, tough, strength);
    // The relief every age shares: slow swells, the cork's grain, young bark's streaks and
    // lenticels.
    var macro:  f32[>..] = [];
    var grain:  f32[>..] = [];
    var streak: f32[>..] = [];
    macro.resize(n, 0.0);
    grain.resize(n, 0.0);
    streak.resize(n, 0.0);
    var lattice: f32[>..] = [];
    bark_add_noise(macro, lattice, 41, 3, 2, 0.65 * 3.0);
    bark_add_noise(macro, lattice, 43, 6, 5, 0.35 * 3.0);
    bark_add_noise(grain, lattice, 47, 64, 64, 0.45 * 2.0 * BARK_GRAIN_MM);
    bark_add_noise(grain, lattice, 53, 128, 96, 0.3 * 2.0 * BARK_GRAIN_MM);
    bark_add_noise(grain, lattice, 83, 96, 24, 0.25 * 2.0 * BARK_GRAIN_MM);
    bark_add_noise(streak, lattice, 59, 48, 6, 0.5);
    for k in n {
        macro[k] -= 0.5 * 3.0;
        grain[k] -= 0.5 * 2.0 * BARK_GRAIN_MM;
        streak[k] -= 0.5 * 0.5;
    }
    var dice = Dice { mixed(0xBA4C0FF) };
    for k in BARK_LENTICELS {
        let x = (roll(dice) * BARK_W) as i64;
        let y = (roll(dice) * BARK_H) as i64;
        let half = 2 + (roll(dice) * 3.0) as i64;
        for dx in -half..half + 1 {
            streak[y * BARK_W + (x + dx) % BARK_W] += 0.45;
            streak[((y + 1) % BARK_H) * BARK_W + (x + dx) % BARK_W] += 0.25;
        }
    }
    heights.clear();
    cavities.clear();
    heights.resize(bark_bytes(), 0);
    cavities.resize(bark_bytes(), 0);
    var height:       f32[>..] = [];
    var spare:        f32[>..] = [];
    var near:         i32[>..] = [];
    var dist:         f32[>..] = [];
    var furrow_width: f32[>..] = [];
    var furrow_depth: f32[>..] = [];
    var jag:          f32[>..] = [];
    jag.resize(n, 0.0);
    if jagged {
        bark_add_noise(jag, lattice, 89, 48, 48, 0.65 * 2.0 * BARK_EDGE_JAG);
        bark_add_noise(jag, lattice, 97, 128, 160, 0.35 * 2.0 * BARK_EDGE_JAG);
        for k in n { jag[k] -= BARK_EDGE_JAG; }
    }
    furrow_width.resize(n, 1.0);
    furrow_depth.resize(n, 0.0);
    height.resize(n, 0.0);
    spare.resize(n, 0.0);
    near.resize(n, -1);
    dist.resize(n, 0.0);
    for layer in BARK_LAYERS {
        let t = BARK_AGES[layer];
        bark_distance(crack, t, near, dist);
        let cork = bark_step(BARK_T_CRACK - 0.05, 1.0, t);
        let young = 1.0 - bark_step(BARK_T_CRACK - 0.1, BARK_T_CRACK + 0.15, t);
        // Each open crack texel's furrow: its half width and depth by its age and taper.
        for k in n {
            guard crack[k] <= t else { continue; }
            let old = clamp((t - crack[k]) / (1.0 - BARK_T_CRACK), 0.0, 1.0);
            let tp = taper[k];
            furrow_width[k] = (BARK_WIDTH_YOUNG + BARK_WIDTH_OLD * pow(old, 0.8 as f32)) * (0.45 + 0.55 * tp);
            furrow_depth[k] = BARK_RELIEF_MM * cork * (0.35 + 0.65 * pow(old, 0.6 as f32)) * (0.55 + 0.45 * tp);
        }
        let crown_reach = 1.0 / (BARK_PLATE_END * 0.3);
        for k in n {
            var h = macro[k] * cork + grain[k] * (0.3 + cork) + streak[k] * young;
            let s = near[k];
            if s >= 0 {
                let half_width = furrow_width[s as i64];
                let depth = furrow_depth[s as i64];
                let d = dist[k] + jag[k] * half_width;
                let shoulder = bark_step(0.0, 1.0, d / half_width);
                let crown = clamp((d - half_width) * crown_reach, 0.0, 1.0);
                h += -depth * (1.0 - shoulder) + depth * BARK_CROWN * (1.0 - (1.0 - crown) * (1.0 - crown));
            }
            height[k] = h;
        }
        bark_blur(height, spare, 1);
        for k in n {
            heights[k * 4 + layer] = bark_height_byte(height[k]);
        }
        // The cavity: how far a texel lies under its neighbourhood, at three reaches.
        var cavity: f32[>..] = [];
        cavity.resize(n, 0.0);
        let reaches: i64[3] = [2, 5, 10];
        let weights: f32[3] = [0.5, 0.35, 0.15];
        for reach, ri in reaches {
            var blurred: f32[>..] = [];
            blurred.resize(n, 0.0);
            for k in n { blurred[k] = height[k]; }
            bark_blur(blurred, spare, reach);
            for k in n { cavity[k] += weights[ri] * max(blurred[k] - height[k], 0.0); }
        }
        for k in n { cavities[k * 4 + layer] = bark_byte(clamp(1.0 - cavity[k] / 2.6, 0.1, 1.0)); }
    }
    // The detail, from the oldest age's plates (near, dist and height as its snapshot left
    // them): how far each texel lies inside its plate, in texels.
    for k in n {
        let s = near[k];
        spare[k] = if s >= 0 { dist[k] + jag[k] * furrow_width[s as i64] - furrow_width[s as i64] } else { 1e9 };
    }
    bark_detail(details, spare, height, lattice);
    var from = 0;
    var w = BARK_W;
    var h = BARK_H;
    for level in 1..mips_of(BARK_W, BARK_H) {
        let to = from + w * h * 4;
        halve(heights, from, to, w, h);
        halve(cavities, from, to, w, h);
        halve(details, from, to, w, h);
        w /= 2;
        h /= 2;
        from = to;
    }
}

// The height texel's byte of h millimetres: 128 at 0, BARK_HEIGHT_MM a step.
fn bark_height_byte(h: f32) -> u8 { (clamp(128.0 + h / BARK_HEIGHT_MM, 0.0, 255.0) + 0.5) as u8 }

fn bark_step(a: f32, b: f32, x: f32) -> f32 {
    let s = clamp((x - a) / (b - a), 0.0, 1.0);
    return s * s * (3.0 - 2.0 * s);
}

// The cork's toughness (stretched noise, long along the stem, warped) and its strength.
fn bark_cork(tough: f32[>..]&, strength: f32[>..]&) {
    let n = BARK_W * BARK_H;
    var lattice: f32[>..] = [];
    var warp_u:  f32[>..] = [];
    var warp_v:  f32[>..] = [];
    warp_u.resize(n, 0.0);
    warp_v.resize(n, 0.0);
    bark_add_noise(warp_u, lattice, 61, 4, 4, 30.0 / BARK_W);
    bark_add_noise(warp_v, lattice, 67, 4, 4, 30.0 / BARK_H);
    bark_add_noise(tough, lattice, 73, 64, 16, 0.4);
    bark_add_noise(strength, lattice, 79, 8, 4, 2.0 * BARK_STRENGTH_SPREAD);
    bark_lattice(lattice, 71, 24, 6);
    var lo: f32 = 1e9;
    var hi: f32 = -1e9;
    for j in BARK_H {
        for i in BARK_W {
            let k = j * BARK_W + i;
            let u = (i + 0.5) / BARK_W + warp_u[k] - 15.0 / BARK_W;
            let v = (j + 0.5) / BARK_H + warp_v[k] - 15.0 / BARK_H;
            let x = tough[k] + 0.6 * lattice_noise(lattice, 24, 6, u, v);
            tough[k] = x;
            lo = min(lo, x);
            hi = max(hi, x);
            strength[k] -= BARK_STRENGTH_SPREAD;
        }
    }
    for k in n { tough[k] = (tough[k] - lo) / max(hi - lo, 1e-6); }
}

// wrapped_noise's lattice of `seed`, across × along values.
fn bark_lattice(lattice: f32[>..]&, seed: u64, across: i64, along: i64) {
    lattice.clear();
    for j in along { for i in across { lattice.push(lattice_value(seed, i, j)); } }
}

// wrapped_noise from its lattice (bark_lattice), the same values without the hashing.
fn lattice_noise(lattice: f32[>..]&, across: i64, along: i64, u: f32, v: f32) -> f32 {
    let x = u * across;
    let y = v * along;
    let fi = floor(x);
    let fj = floor(y);
    let fx = x - fi;
    let fy = y - fj;
    let i = fi as i64 % across;
    let j = fj as i64 % along;
    let i1 = (i + 1) % across;
    let j1 = (j + 1) % along;
    let sx = fx * fx * (3.0 - 2.0 * fx);
    let sy = fy * fy * (3.0 - 2.0 * fy);
    let a = lattice[j * across + i];
    let b = lattice[j * across + i1];
    let c = lattice[j1 * across + i];
    let d = lattice[j1 * across + i1];
    let low = a + (b - a) * sx;
    return low + ((c + (d - c) * sx) - low) * sy;
}

// weight × wrapped_noise of `seed` added to every texel of x.
fn bark_add_noise(x: f32[>..]&, lattice: f32[>..]&, seed: u64, across: i64, along: i64, weight: f32) {
    bark_lattice(lattice, seed, across, along);
    for j in BARK_H {
        let v = (j + 0.5) / BARK_H;
        for i in BARK_W { x[j * BARK_W + i] += weight * lattice_noise(lattice, across, along, (i + 0.5) / BARK_W, v); }
    }
}

fn bark_cracked(crack: f32[>..]&, x: i64, y: i64) -> bool { crack[(y % BARK_H) * BARK_W + x % BARK_W] < BARK_CRACK_NONE }

// The plate across row y round x: the texels to the crack on its left and on its right.
fn bark_plate(crack: f32[>..]&, x: i64, y: i64) -> i64, i64 {
    var l = 0;
    while l < BARK_W && !bark_cracked(crack, x - l - 1 + BARK_W, y) { l++; }
    var r = 0;
    while r < BARK_W && !bark_cracked(crack, x + r + 1, y) { r++; }
    return l, r;
}

// A spread-1 normal number, near enough: three rolls.
fn bark_normal(d: Dice&) -> f32 { (roll(d) + roll(d) + roll(d) - 1.5) * 2.0 }

fn bark_grow(crack: f32[>..]&, taper: f32[>..]&, tough: f32[>..]&, strength: f32[>..]&) {
    var d = Dice { mixed(0x5EED7) };
    var path: i32[>..] = [];
    for step in BARK_STEPS {
        let t = BARK_T_CRACK + (1.0 - BARK_T_CRACK) * (step + 1) / BARK_STEPS;
        let widest = BARK_PLATE_END * pow(t, -BARK_PLATE_EXP);
        var misses = 0;
        while misses < 6 {
            // The weakest of the overstretched texels among a few at random.
            var best = -1;
            var best_tough: f32 = 2.0;
            for k in 48 {
                let x = (roll(d) * BARK_W) as i64 % BARK_W;
                let y = (roll(d) * BARK_H) as i64 % BARK_H;
                guard !bark_cracked(crack, x, y) else { continue; }
                let l, r = bark_plate(crack, x, y);
                let width = (l + r) as f32;
                guard width > widest * strength[y * BARK_W + x] && min(l, r) as f32 > 0.3 * width else { continue; }
                if tough[y * BARK_W + x] < best_tough {
                    best_tough = tough[y * BARK_W + x];
                    best = y * BARK_W + x;
                }
            }
            if best < 0 {
                misses++;
                continue;
            }
            let run = BARK_RUN_LEAST + (roll(d) * (BARK_RUN_MOST - BARK_RUN_LEAST)) as i64;
            bark_crack(crack, taper, tough, strength, d, path, best % BARK_W, best / BARK_W, t, run, widest);
        }
    }
}

// A crack opened at (x0, y0) at time t, run up and down the stem (Lefebvre and Neyret's
// a·slope + b·rnd, the slope pulled toward a crack near it); its texels' taper by the
// distance to its free ends.
fn bark_crack(crack: f32[>..]&, taper: f32[>..]&, tough: f32[>..]&, strength: f32[>..]&, d: Dice&, path: i32[>..]&,
              x0: i64, y0: i64, t: f32, run: i64, widest: f32) {
    path.clear();
    crack[y0 * BARK_W + x0] = min(crack[y0 * BARK_W + x0], t);
    var free: bool[2] = [true, true];
    for way in 2 {
        let dy = if way == 0 { -1 } else { 1 };
        if way == 1 { path.push((y0 * BARK_W + x0) as i32); }
        var x = x0;
        var y = y0;
        var fx = x0 as f32;
        var slope = bark_normal(d) * BARK_LEAN;
        for k in BARK_H {
            let y2 = (y + dy + BARK_H) % BARK_H;
            var pull = 0;
            for r in 1..BARK_PULL_REACH + 1 {
                if bark_cracked(crack, x + r, y2) { pull = r; break; }
                if bark_cracked(crack, x - r + BARK_W, y2) { pull = -r; break; }
            }
            slope = clamp(slope * 0.985 + bark_normal(d) * BARK_LEAN_DRIFT, -1.0, 1.0);
            var want = fx + slope;
            if pull != 0 && roll(d) < BARK_PULL_ODDS { want += if pull > 0 { 0.4 } else { -0.4 }; }
            let c0 = floor(want) as i64 - 1;
            var nx = c0;
            var least: f32 = 1e9;
            for c in c0..c0 + 3 {
                let cost = tough[y2 * BARK_W + (c + 4 * BARK_W) % BARK_W] + abs(c as f32 - want) * 0.35 + roll(d) * 0.05;
                if cost < least {
                    least = cost;
                    nx = c;
                }
            }
            fx = 0.6 * want + 0.4 * nx;
            let lo = min(x, nx);
            let hi = max(x, nx);
            var met = false;
            for xx in lo..hi + 1 { if xx != x && bark_cracked(crack, xx + 4 * BARK_W, y2) { met = true; } }
            for xx in lo..hi + 1 {
                let at = y2 * BARK_W + (xx + 4 * BARK_W) % BARK_W;
                crack[at] = min(crack[at], t);
            }
            x = (nx + 4 * BARK_W) % BARK_W;
            fx += (x - nx) as f32;
            y = y2;
            path.push((y * BARK_W + x) as i32);
            if met {
                free[way] = false;
                break;
            }
            if k > run {
                let l, r = bark_plate(crack, x, y);
                if ((l + r) as f32) < widest * strength[y * BARK_W + x] * 0.9 { break; }
            }
        }
        if way == 0 {
            // The way down was pushed outward from the start: turn it round so the path runs
            // from the lower end up.
            let m = path.len;
            for i in m / 2 {
                let a = path[i];
                path[i] = path[m - 1 - i];
                path[m - 1 - i] = a;
            }
        }
    }
    let total = path.len;
    for p, i in path {
        let from_low = if free[0] { i as f32 } else { 1e9 };
        let from_high = if free[1] { (total - 1 - i) as f32 } else { 1e9 };
        let tp = clamp(min(from_low, from_high) / BARK_TAPER, 0.2, 1.0);
        let at = p as i64;
        taper[at] = max(taper[at], tp);
        // The texels filled across to keep the path whole take its taper too.
        for dx in -1..2 {
            let side = (at / BARK_W) * BARK_W + (at % BARK_W + dx + BARK_W) % BARK_W;
            if crack[side] == t { taper[side] = max(taper[side], tp); }
        }
    }
}

// Each texel's nearest crack open by time t (its index, -1 none) and the distance to it
// (texels), by a chamfer distance's two passes, twice for the wrap.
fn bark_distance(crack: f32[>..]&, t: f32, near: i32[>..]&, dist: f32[>..]&) {
    let n = BARK_W * BARK_H;
    for k in n {
        if crack[k] <= t {
            near[k] = k as i32;
            dist[k] = 0.0;
        } else {
            near[k] = -1;
            dist[k] = 1e9;
        }
    }
    let diagonal: f32 = 1.41421;
    for round in 2 {
        for j in BARK_H {
            let up = (j + BARK_H - 1) % BARK_H;
            for i in BARK_W {
                let k = j * BARK_W + i;
                let left = (i + BARK_W - 1) % BARK_W;
                let right = (i + 1) % BARK_W;
                bark_take(near, dist, k, j * BARK_W + left, 1.0);
                bark_take(near, dist, k, up * BARK_W + left, diagonal);
                bark_take(near, dist, k, up * BARK_W + i, 1.0);
                bark_take(near, dist, k, up * BARK_W + right, diagonal);
            }
        }
        for jj in BARK_H {
            let j = BARK_H - 1 - jj;
            let down = (j + 1) % BARK_H;
            for ii in BARK_W {
                let i = BARK_W - 1 - ii;
                let k = j * BARK_W + i;
                let left = (i + BARK_W - 1) % BARK_W;
                let right = (i + 1) % BARK_W;
                bark_take(near, dist, k, j * BARK_W + right, 1.0);
                bark_take(near, dist, k, down * BARK_W + right, diagonal);
                bark_take(near, dist, k, down * BARK_W + i, 1.0);
                bark_take(near, dist, k, down * BARK_W + left, diagonal);
            }
        }
    }
}

fn bark_take(near: i32[>..]&, dist: f32[>..]&, k: i64, from: i64, step: f32) {
    let d = dist[from] + step;
    if d < dist[k] {
        dist[k] = d;
        near[k] = near[from];
    }
}

// A box blur of `reach` texels each way, across then along, wrapping (spare the size of the
// tile, scratch).
fn bark_blur(x: f32[>..]&, spare: f32[>..]&, reach: i64) {
    let span = (2 * reach + 1) as f32;
    for j in BARK_H {
        var s: f32 = 0.0;
        for i in -reach..reach + 1 { s += x[j * BARK_W + (i + BARK_W) % BARK_W]; }
        for i in BARK_W {
            spare[j * BARK_W + i] = s / span;
            s += x[j * BARK_W + (i + reach + 1) % BARK_W] - x[j * BARK_W + (i - reach + BARK_W) % BARK_W];
        }
    }
    for i in BARK_W {
        var s: f32 = 0.0;
        for j in -reach..reach + 1 { s += spare[((j + BARK_H) % BARK_H) * BARK_W + i]; }
        for j in BARK_H {
            x[j * BARK_W + i] = s / span;
            s += spare[((j + reach + 1) % BARK_H) * BARK_W + i] - spare[((j - reach + BARK_H) % BARK_H) * BARK_W + i];
        }
    }
}

// The detail texture's level 0 (bark_layers): `inside` how far each texel lies inside its
// plate (texels, under 0 in a furrow), `height` the oldest age's relief (mm).
fn bark_detail(details: u8[>..]&, inside: f32[>..]&, height: f32[>..]&, lattice: f32[>..]&) {
    let n = BARK_W * BARK_H;
    details.clear();
    details.resize(bark_bytes(), 0);
    // The cork's cells: a jittered point a cell, each texel's two nearest (F1, F2); a cell's
    // middle is a small dome, the border between two a groove.
    var cell_x: f32[>..] = [];
    var cell_y: f32[>..] = [];
    var dice = Dice { mixed(0xC0BC311) };
    let cw = BARK_W as f32 / BARK_CELLS_ACROSS;
    let ch = BARK_H as f32 / BARK_CELLS_ALONG;
    for k in BARK_CELLS_ACROSS * BARK_CELLS_ALONG {
        cell_x.push(0.1 + 0.8 * roll(dice));
        cell_y.push(0.1 + 0.8 * roll(dice));
    }
    var fibre:  f32[>..] = [];
    var drift:  f32[>..] = [];
    var lichen: f32[>..] = [];
    var patch:  f32[>..] = [];
    fibre.resize(n, 0.0);
    drift.resize(n, 0.0);
    lichen.resize(n, 0.0);
    patch.resize(n, 0.0);
    bark_add_noise(fibre, lattice, 101, 96, 12, 0.6);
    bark_add_noise(fibre, lattice, 103, 192, 24, 0.4);
    bark_add_noise(drift, lattice, 107, 4, 3, 0.6);
    bark_add_noise(drift, lattice, 109, 24, 20, 0.4);
    bark_add_noise(lichen, lattice, 113, 6, 8, 0.6);
    bark_add_noise(lichen, lattice, 127, 24, 32, 0.4);
    bark_add_noise(patch, lattice, 131, 96, 128, 1.0);
    // The secondary cracks, a depth 0..1 a texel.
    var cracks: f32[>..] = [];
    cracks.resize(n, 0.0);
    var d = Dice { mixed(0x5EC0DC4) };
    for c in BARK_FINE_CRACKS { bark_fine_crack(cracks, inside, d, false); }
    for c in BARK_CROSS_CRACKS { bark_fine_crack(cracks, inside, d, true); }
    for j in BARK_H {
        let fy = (j + 0.5) / ch;
        let cj = floor(fy) as i64;
        for i in BARK_W {
            let fx = (i + 0.5) / cw;
            let ci = floor(fx) as i64;
            var f1: f32 = 1e9;
            var f2: f32 = 1e9;
            for dj in -1..2 {
                for di in -1..2 {
                    let a = (ci + di + BARK_CELLS_ACROSS) % BARK_CELLS_ACROSS;
                    let b = (cj + dj + BARK_CELLS_ALONG) % BARK_CELLS_ALONG;
                    let px = (ci + di) as f32 + cell_x[b * BARK_CELLS_ACROSS + a] - fx;
                    // The cells are longer along the stem: the distance along counts less.
                    let py = ((cj + dj) as f32 + cell_y[b * BARK_CELLS_ACROSS + a] - fy) * 0.8;
                    let q = px * px + py * py;
                    if q < f1 {
                        f2 = f1;
                        f1 = q;
                    } else if q < f2 {
                        f2 = q;
                    }
                }
            }
            let border = sqrt(f2) - sqrt(f1);
            let dome = bark_step(0.0, 0.45, border);
            let k = j * BARK_W + i;
            let fine = 0.45 * dome + 0.55 * fibre[k];
            let crown = clamp((height[k] + 3.0) / 6.0, 0.0, 1.0);
            let cover = bark_step(0.56, 0.68, lichen[k]) * bark_step(0.45, 0.7, patch[k]) * crown;
            let o = k * 4;
            details[o] = bark_byte(fine);
            details[o + 1] = bark_byte(1.0 - clamp(cracks[k], 0.0, 1.0));
            details[o + 2] = bark_byte(drift[k]);
            details[o + 3] = bark_byte(cover);
        }
    }
}

// One secondary crack into `cracks` from a texel well inside a plate: along the stem,
// leaning and drifting, or `across` the ridge, each way until its run is spent or it
// reaches a furrow; deepest at its middle, a groove a texel wide with soft sides.
fn bark_fine_crack(cracks: f32[>..]&, inside: f32[>..]&, d: Dice&, across: bool) {
    let x0 = (roll(d) * BARK_W) as i64 % BARK_W;
    let y0 = (roll(d) * BARK_H) as i64 % BARK_H;
    let least: f32 = if across { 3.0 } else { 2.0 };
    guard inside[y0 * BARK_W + x0] > least else { return; }
    var run = BARK_FINE_RUN_LEAST + (roll(d) * (BARK_FINE_RUN_MOST - BARK_FINE_RUN_LEAST)) as i64;
    if across { run = BARK_CROSS_RUN_LEAST + (roll(d) * (BARK_CROSS_RUN_MOST - BARK_CROSS_RUN_LEAST)) as i64; }
    let depth = 0.45 + 0.55 * roll(d);
    let half = run / 2 + 1;
    for way in 2 {
        let step: f32 = if way == 0 { -1.0 } else { 1.0 };
        var x = x0 as f32 + 0.5;
        var y = y0 as f32 + 0.5;
        var slope = bark_normal(d) * 0.3;
        for s in half {
            let i = floor(x) as i64 % BARK_W;
            let j = floor(y) as i64 % BARK_H;
            let k = j * BARK_W + i;
            guard inside[k] > 0.0 else { break; }
            let h = depth * sqrt(1.0 - (s as f32) / (half as f32));
            cracks[k] = max(cracks[k], h);
            if across {
                let up = ((j + 1) % BARK_H) * BARK_W + i;
                let down = ((j + BARK_H - 1) % BARK_H) * BARK_W + i;
                cracks[up] = max(cracks[up], 0.35 * h);
                cracks[down] = max(cracks[down], 0.35 * h);
                x += step;
                y += slope;
            } else {
                let right = j * BARK_W + (i + 1) % BARK_W;
                let left = j * BARK_W + (i + BARK_W - 1) % BARK_W;
                cracks[right] = max(cracks[right], 0.35 * h);
                cracks[left] = max(cracks[left], 0.35 * h);
                y += step;
                x += slope * step;
            }
            slope = clamp(slope + bark_normal(d) * 0.08, -0.8, 0.8);
        }
    }
}
