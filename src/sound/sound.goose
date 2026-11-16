// The app's sounds (docs/architecture/sound.md), over goose_gfx's mixer (`audio`): a few
// quiet ones, each made once into the mixer when sound is turned on, and played by one
// call. Nothing is built, and the device stays closed, while the volume is at zero, so a
// phone at its default never opens audio.
//
// The move and the taken pieces are recorded hits (hits.goose); the rest is sample math
// (synth.goose). Each sound's gain against the move is in its samples, so the volume is
// one gain for all of them.
namespace sound;
import std;
import math;
import audio;
import .synth;
import .hits;

let RATE = 24000;           // the mixer's and every sound's, mono
let SR = 24000.0;

// What can be played (play's `kind`).
let MOVE = 0;               // a piece set down; play's `step`, a capture's stop, a whole tone up each
let TAKE = 1;               // the taken pieces, once a capture
let CROWN = 2;              // a kannel's two plucks up a fifth
let WRONG = 3;              // two low soft knocks, the second lower
let MUST = 4;               // the same knocks, the second up: a capture due elsewhere
let GOLD = 5;               // one mallet note: a clock under a minute
let RED = 6;                // the note as ri-tai: a clock at 0:20
let SOLVED = 7;             // three notes up
let WON = 8;                // three notes up, lower and slower
let LOST = 9;               // two low notes together: a close, never a sad one
let DRAWN = 10;             // the kannel's two low strings
let KINDS = 11;

// Each sound's gain against the move's, as the prototype's set played them: the moments
// well under the move, so the sound heard most is the loudest.
let MOVE_GAIN = 0.9;
let TAKE_GAIN = 0.5;
let CROWN_GAIN = 0.12;
let KNOCKS_GAIN = 0.4;
let MOMENT_GAIN = 0.1;

// The volume's slider, 0..1, to a gain: -36 dB at its foot to 0 dB at the top, as the
// ear hears loudness; a linear gain would put all the change in its first fifth.
let RANGE_DB = 36.0;
fn gain_of(level: f32) -> f32 {
    guard level > 0.0 else { return 0.0; }
    return pow(10.0, (min(level, 1.0) as f64 - 1.0) * RANGE_DB / 20.0) as f32;
}

// The highest step a capture's stops climb to: an octave and a fifth.
let TOP_STEP = 9;

// The notes, on D major's pentatonic scale, so any two that overlap sound fine.
let D3 = 146.8;
let A3 = 220.0;
let E4 = 329.6;
let D4 = 293.7;
let A4 = 440.0;
let D5 = 587.3;
let E5 = 659.3;
let F5 = 740.0;             // F sharp
let A5 = 880.0;

let MOST_SOUNDS = 32;
struct Bank {
    open: bool = false,
    gain: f32  = 0.0,
    // The mixer's sounds: the move's hits, the take's, then one for each kind from CROWN
    // on (kind - CROWN + hits); and each one's length in frames.
    sounds: audio::Sound[MOST_SOUNDS] = [audio::Sound { 0 }; MOST_SOUNDS],
    frames: i64[MOST_SOUNDS]          = [0; MOST_SOUNDS],
    count:  i64                       = 0,
    moves:  i64                       = 0,
    takes:  i64                       = 0,
    last:   i64[2]                    = [-1, -1], // the move's and the take's hit played last
    seed:   u32                       = 2463534242,
}

// Sets the volume: `level` 0..1 as the slider has it, silent while `muted`. Above zero the
// first time, opens the device and builds the sounds; at zero, closes it and frees them.
// `offline` opens the mixer with no device (the tests). False when the device won't open.
fn set_level(bk: Bank&, level: f32, muted: bool, offline: bool = false) -> bool {
    bk.gain = if muted { 0.0 } else { gain_of(level) };
    if bk.gain <= 0.0 {
        if bk.open { close(bk); }
        return true;
    }
    guard !bk.open else { return true; }
    let opened = if offline { audio::open_offline(RATE) } else { audio::open(RATE) };
    guard opened else { return false; }
    bk.open = true;
    build(bk);
    return true;
}

// Stops every sound, frees them, and closes the device.
fn close(bk: Bank&) {
    audio::close();
    bk.open = false;
    bk.count = 0;
    bk.moves = 0;
    bk.takes = 0;
    bk.last = [-1, -1];
}

// Hands x to the mixer as the next sound, its tail cut.
fn keep(bk: Bank&, x: f32[>..]&) {
    guard bk.count < MOST_SOUNDS else { return; }
    trim(x);
    bk.sounds[bk.count] = audio::create_sound(x[..], RATE);
    bk.frames[bk.count] = x.len;
    bk.count++;
}

// Makes every sound into the mixer: the hits decoded, the rest synthesized, each at its
// gain.
fn build(bk: Bank&) {
    let d = data();
    let list, moves = hits(d);
    for h, k in list {
        var q: i16[>..] = [];
        decode(d, h, q);
        var x: f32[>..] = [];
        x.resize(q.len, 0.0);
        let g = (if k < moves { MOVE_GAIN } else { TAKE_GAIN }) / 32768.0;
        for v, i in q { x[i] = (v * g) as f32; }
        keep(bk, x);
    }
    bk.moves = moves;
    bk.takes = bk.count - moves;
    for kind in CROWN..KINDS {
        var x = moment(kind);
        keep(bk, x);
    }
}

// The sound of `kind`, from CROWN on, at its gain.
fn moment(kind: i64) -> f32[>..] {
    var x: f32[>..] = [];
    if kind == CROWN {
        let a = pluck(A4);
        add(x, 0.0, a);
        let b = pluck(E5);
        add(x, 0.12, b);
        even(x);
        scale(x, CROWN_GAIN);
    } else if kind == WRONG || kind == MUST {
        x = knocks(if kind == WRONG { 0.66 } else { 0.84 });
        scale(x, KNOCKS_GAIN);
    } else {
        if kind == GOLD { x = note(A4, 0.4); }
        if kind == RED {
            let a = note(A4, 0.4);
            x = ritai(a);
        }
        if kind == SOLVED { three(x, 0.12, D5, F5, A5, 0.45, 0.8); }
        if kind == WON { three(x, 0.14, D4, A4, D5, 0.5, 0.7); }
        if kind == LOST {
            let a = note(A3, 0.8);
            add(x, 0.0, a);
            let b = note(E4, 0.8, 0.7);
            add(x, 0.02, b);
        }
        if kind == DRAWN {
            let a = pluck(D3, 2.4, 41);
            add(x, 0.0, a);
            let b = pluck(A3, 2.4, 42);
            add(x, 0.09, b);
        }
        even(x);
        scale(x, MOMENT_GAIN);
    }
    return x;
}

// Three mallet notes `dt` apart, the first two decaying over `decay`, the last over `last`.
fn three(x: f32[>..]&, dt: f64, a: f64, b: f64, c: f64, decay: f64, last: f64) {
    let na = note(a, decay);
    add(x, 0.0, na);
    let nb = note(b, decay);
    add(x, dt, nb);
    let nc = note(c, last);
    add(x, 2.0 * dt, nc);
}

// One of n hits at random, never `last` again while there are others.
fn pick(bk: Bank&, n: i64, last: i64) -> i64 {
    guard n > 1 else { return 0; }
    bk.seed ^= bk.seed << 13;
    bk.seed ^= bk.seed >> 17;
    bk.seed ^= bk.seed << 5;
    let k = (bk.seed % (n - 1) as u32) as i64;
    return if last >= 0 && k >= last { k + 1 } else { k };
}

// The mixer's sound for `kind` (its hit picked at random for a move or a take), or -1.
fn sound_of(bk: Bank&, kind: i64) -> i64 {
    if kind == MOVE || kind == TAKE {
        guard bk.moves > 0 else { return -1; }
        bk.last[0] = pick(bk, bk.moves, bk.last[0]);
        return bk.last[0];
    }
    if kind == TAKE && bk.takes > 0 {
        bk.last[1] = pick(bk, bk.takes, bk.last[1]);
        return bk.moves + bk.last[1];
    }
    let i = bk.moves + bk.takes + kind - CROWN;
    return if kind > TAKE && kind < KINDS && i < bk.count { i } else { -1 };
}

// Plays `kind` at the volume; a move `step` whole tones up (a capture's stops). Nothing
// while sound is off.
fn play(bk: Bank&, kind: i64, step: i64 = 0) -> audio::Voice {
    guard bk.open && bk.gain > 0.0 else { return audio::Voice { 0 }; }
    let i = sound_of(bk, kind);
    guard i >= 0 else { return audio::Voice { 0 }; }
    let pitch = pow(2.0, 2.0 * clamp(step, 0, TOP_STEP) / 12.0) as f32;
    return audio::play(bk.sounds[i], bk.gain, 0.0, pitch);
}

// How many frames sound `kind`'s longest take lasts at the mixer's rate.
fn length(bk: Bank&, kind: i64) -> i64 {
    var n = 0;
    let first = if kind == MOVE { 0 } else if kind == TAKE { bk.moves } else { bk.moves + bk.takes + kind - CROWN };
    let end = if kind == MOVE { bk.moves } else if kind == TAKE { bk.moves + bk.takes } else { first + 1 };
    for i in first..min(end, bk.count) { n = max(n, bk.frames[i]); }
    return n;
}
