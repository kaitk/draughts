// The sounds made with sample math (docs/architecture/sound.md): a felt knock, a mallet's
// note, and a plucked string, each written into an f32 array at RATE, and the helpers that
// lay them one after another, match their loudness, and cut their tails. Each is built
// once, when sound is turned on, and handed to the mixer.
namespace sound;
import std;
import math;

// A small xorshift, seeded, so each take of a knock or a pluck is the same every build:
// -1..1.
struct Rng { s: u32 = 1 }

fn rng(seed: u32) -> Rng { Rng { s: if seed == 0 { 1 } else { seed } } }

fn next(r: Rng&) -> f64 {
    r.s ^= r.s << 13;
    r.s ^= r.s >> 17;
    r.s ^= r.s << 5;
    return r.s / 2147483648.0 - 1.0;
}

fn frames(seconds: f64) -> i64 { round(seconds * SR) as i64 }

// A one-pole low-pass at `hz`, in place: no ringing, so no edge.
fn lowpass(x: f32[>..]&, hz: f64) {
    let a = 1.0 - exp(-TAU * hz / SR);
    var y = 0.0;
    for &v in x {
        y += a * (v - y);
        v = y as f32;
    }
}

fn peak(x: const f32[:]) -> f32 {
    var m: f32 = 0.0;
    for v in x { m = max(m, abs(v)); }
    return m;
}

fn scale(x: f32[>..]&, g: f64) { for &v in x { v = (v * g) as f32; } }

// Adds x, times `gain`, into out from `at` seconds, growing out with silence to hold it.
fn add(out: f32[>..]&, at: f64, x: const f32[:], gain: f64 = 1.0) {
    let o = frames(at);
    if out.len < o + x.len { out.resize(o + x.len, 0.0); }
    for v, i in x { out[o + i] += (v * gain) as f32; }
}

// Loudness matched: the first 0.6 s to one RMS, the peak kept under 0.95; so the moments
// sit at one level, and their gains alone set them against the move.
fn even(x: f32[>..]&) {
    let n = min(x.len, frames(0.6));
    var e = 0.0;
    for i in n { e += x[i] as f64 * x[i]; }
    scale(x, min(0.3 / sqrt(e / n + 1.0e-12), 0.95 / (peak(x) as f64 + 1.0e-9)));
}

// Cuts the tail once it stays under -54 dBFS at full volume (-72 at the default half), or
// -60 dB under the peak for a loud sound, with a 10 ms fade to the cut: past it nothing is
// heard, and it would only hold a voice and memory.
let TAIL = 0.002;
let TAIL_UNDER = 0.001;
fn trim(x: f32[>..]&) {
    let floor = max(TAIL, peak(x) * TAIL_UNDER);
    var end = x.len;
    while end > 0 && abs(x[end - 1]) < floor { end--; }
    let fade = min(end, frames(0.01));
    for i in fade { x[end - fade + i] *= ((fade - i) as f64 / fade) as f32; }
    x.resize(max(end, 1));
}

// A knock: a piece set down on a cloth-covered board, as modal synthesis makes one. The
// piece rings in a few inharmonic modes, each detuned a little per take (seed); a 1.5 ms
// breath of noise is the contact; the board under it gives a short low thump; a 0.6 ms
// rise keeps the start from clicking, and a gentle low-pass keeps it muted. No pitch glide:
// that made a punch of it.
let MODES = 3;
let MODE_HZ = [520.0, 1240.0, 2100.0];
let MODE_GAIN = [1.0, 0.4, 0.15];
let MODE_DECAY = [0.016, 0.009, 0.005];
let THUMP_HZ = 130.0;
let THUMP_GAIN = 0.7;
let THUMP_DECAY = 0.014;
let NOISE = 0.4;
let KNOCK_LOWPASS = 2000.0;
fn knock(seed: u32, pitch: f64) -> f32[>..] {
    var x: f32[>..] = [];
    x.resize(frames(0.25), 0.0);
    var r = rng(seed);
    var hz:    f64[MODES] = [0.0; MODES];
    var gain:  f64[MODES] = [0.0; MODES];
    var phase: f64[MODES] = [0.0; MODES];
    for k in MODES {
        hz[k] = MODE_HZ[k] * pitch * (1.0 + 0.04 * next(r));
        gain[k] = MODE_GAIN[k] * (1.0 + 0.15 * next(r));
    }
    for k in MODES { phase[k] = next(r) * PI; }
    var n = 0.0;
    for i in x.len {
        let t = i / SR;
        var v = 0.0;
        for k in MODES { v += gain[k] * sin(phase[k] + TAU * hz[k] * t) * exp(-t / MODE_DECAY[k]); }
        v += THUMP_GAIN * sin(TAU * THUMP_HZ * t) * exp(-t / THUMP_DECAY) * min(1.0, t / 0.002);
        n += 0.5 * (next(r) - n);
        x[i] = (min(1.0, t / 0.0006) * (v + NOISE * n * exp(-t / 0.0015))) as f32;
    }
    lowpass(x, KNOCK_LOWPASS);
    scale(x, 0.9 / (peak(x) as f64 + 1.0e-9));
    return x;
}

// Two low soft knocks, the second at `second` of the knock's pitch and quieter: a wrong
// move (lower), or a capture due elsewhere (pitched up, a warning but another one).
fn knocks(second: f64) -> f32[>..] {
    var x: f32[>..] = [];
    let a = knock(41, 0.7);
    add(x, 0.0, a);
    let b = knock(42, second);
    add(x, 0.14, b, 0.6);
    return x;
}

// A mallet's note, soft: the fundamental, a quiet partial near 4 (as a marimba's bar) and
// one at 2, a 12 ms rise, and a long low-passed decay.
fn note(f: f64, decay: f64, gain: f64 = 1.0) -> f32[>..] {
    var x: f32[>..] = [];
    x.resize(frames(decay * 6.0), 0.0);
    for i in x.len {
        let t = i / SR;
        let v = sin(TAU * f * t) * exp(-t / decay) + 0.08 * sin(TAU * f * 3.93 * t) * exp(-t / (decay * 0.15))
                + 0.05 * sin(TAU * f * 2.0 * t) * exp(-t / (decay * 0.5));
        x[i] = (gain * min(1.0, t / 0.012) * v) as f32;
    }
    lowpass(x, 1800.0);
    return x;
}

// A plucked string (Karplus-Strong), as Estonia's kannel: a soft noise burst round a delay
// line one period long, averaged and damped each pass.
let LONGEST = 512;          // samples a delay line holds: a period at 47 Hz
fn pluck(f: f64, seconds: f64 = 1.6, seed: u32 = 5) -> f32[>..] {
    var x: f32[>..] = [];
    x.resize(frames(seconds), 0.0);
    let n = clamp(round(SR / f) as i64, 2, LONGEST);
    var line: f32[LONGEST] = [0.0; LONGEST];
    var r = rng(seed);
    var y = 0.0;
    for k in n {
        y += 0.45 * (next(r) - y);
        line[k] = y as f32;
    }
    var j = 0;
    let rise = SR * 0.002;
    for i in x.len {
        let a = line[j];
        let b = line[(j + 1) % n];
        line[j] = (0.5 * (a + b) as f64 * 0.9965) as f32;
        x[i] = (a * min(1.0, i / rise)) as f32;
        j = (j + 1) % n;
    }
    lowpass(x, 2600.0);
    return x;
}

// Ri-tai, short then long: the note's first sixteenth at 100 to the quarter, damped over
// 50 ms, then the note again on the dotted eighth, left to ring.
let SIXTEENTH = 0.15;
fn ritai(b: const f32[:]) -> f32[>..] {
    let cut = frames(SIXTEENTH);
    let fade = frames(0.05);
    var first: f32[>..] = [];
    first.resize(min(b.len, cut + fade), 0.0);
    for i in first.len {
        let k = if i < cut { 1.0 } else { 1.0 - (i - cut) as f64 / fade };
        first[i] = (b[i] as f64 * 0.8 * k) as f32;
    }
    var x: f32[>..] = [];
    add(x, 0.0, first);
    add(x, SIXTEENTH, b);
    return x;
}
