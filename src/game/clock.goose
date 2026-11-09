// A game's clocks, with no graphics (docs/architecture/rendering.md, "Clocks"): the
// time each side has left, the increment a move adds, and which side's clock runs. The
// game advances it by the time that passed on screen; it never reads a clock of its own,
// so a test drives it with any times. The clock starts with the first move: white's
// first move is untimed, then black's clock runs. The side whose time runs out loses.
namespace clock;
import std;
import math;

// The choices: no clock, five minutes plus three seconds a move, ten plus five.
let NONE = 0;
let BLITZ = 1;
let RAPID = 2;
let KINDS = 3;
let MINUTES = [0.0, 5.0, 10.0];
let INCREMENTS = [0.0, 3.0, 5.0];
let LOW = 10;               // under this many seconds shown, the running clock turns red
let CHARS = "0123456789:";  // what text() writes

struct Clock {
    kind:    i64    = NONE,
    left:    f64[2] = [0.0, 0.0],  // seconds, white's and black's
    running: i64    = -1,          // the side whose clock runs, or -1
    flag:    i64    = -1,          // the side whose time ran out, or -1
}

fn new(kind: i64) -> Clock {
    let k = if kind >= 0 && kind < KINDS { kind } else { NONE };
    let t = 60.0 * MINUTES[k];
    return Clock { kind: k, left: [t, t], .. };
}

fn on(c: Clock&) -> bool { c.kind != NONE }

// Takes `seconds` off the running clock; true when its time ran out now.
fn tick(c: Clock&, seconds: f64) -> bool {
    guard c.running >= 0 && c.flag < 0 && seconds > 0.0 else { return false; }
    let s = c.running;
    c.left[s] = max(c.left[s] - seconds, 0.0);
    guard c.left[s] <= 0.0 else { return false; }
    c.flag = s;
    c.running = -1;
    return true;
}

// `side` has moved: its clock gains the increment if it was running, and the other
// side's starts.
fn moved(c: Clock&, side: i64) {
    guard on(c) && c.flag < 0 else { return; }
    if c.running == side { c.left[side] += INCREMENTS[c.kind]; }
    c.running = 1 - side;
}

// A move was taken back and `side` is to move again: its clock runs, unless the game
// is back where it began, where no clock runs yet. The time taken stays taken.
fn undone(c: Clock&, side: i64, at_start: bool) {
    guard on(c) && c.flag < 0 else { return; }
    c.running = if at_start { -1 } else { side };
}

fn stop(c: Clock&) { c.running = -1; }

// The whole seconds a side's clock shows: rounded up, so it shows 0:00 only once the
// time is out.
fn shown(c: Clock&, side: i64) -> i64 { ceil(c.left[side]) as i64 }

// Whether the running clock is under ten seconds.
fn low(c: Clock&, side: i64) -> bool { c.running == side && shown(c, side) < LOW }

// Seconds until the running clock shows another time, or -1 when none runs.
fn until_next(c: Clock&) -> f64 {
    guard c.running >= 0 else { return -1.0; }
    let t = c.left[c.running];
    return t - (ceil(t) - 1.0);
}

// A time as m:ss, appended to out.
fn text(seconds: i64, out: u8[..8]&) {
    let m = seconds / 60;
    let s = seconds % 60;
    if m >= 10 { out.push('0' + (m / 10) as u8); }
    out.push('0' + (m % 10) as u8);
    out.push(':');
    out.push('0' + (s / 10) as u8);
    out.push('0' + (s % 10) as u8);
}
