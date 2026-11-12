// The 3D board's camera on the game screen and a puzzle (task 015, prototypes/game3d.html,
// placement a), as plain data with no graphics: where the camera buttons have put it and
// where it is easing to. The view goes from the rest angle to the top one and back, the
// zoom frames the playing field, the showcase turns and tips the board under a drag, and
// in a game against a friend the board turns 180° to face the side to move. Each is an
// `Ease`, a value easing from one end to the other over a fixed time, read at any moment
// by `value`; nothing here knows the screen, which game/panel.goose fits the camera into
// (panel::aim). Tests run it headless.
namespace rig;
import std;
import math;
import vec;

let TOP_PITCH: f32 = 74.0;  // the top view's angle, degrees down
let EASE = 0.6;             // seconds the view, the zoom, and the showcase's way back take
let TURN = 0.7;             // the hot-seat turn, on its gentler curve (soft)
let SWING: f32 = 35.0;      // the showcase turns the board this far either way,
let LOW:   f32 = 35.0;      // and tips it between these angles down
let HIGH:  f32 = 80.0;
let DRAG:  f32 = 0.3;       // degrees a dp of drag turns or tips it

// A value easing from `from` to `to` over `length` seconds from `start`, in and out.
struct Ease {
    from:   f32 = 0.0,
    to:     f32 = 0.0,
    start:  f64 = 0.0,
    length: f64 = 0.0,
    soft:   bool = false,   // on a sine curve, whose middle is half as fast again as its
                            // average, not three times as the cubic's
}

// The ease's curve, 0..1 over 0..1: cubic in, then cubic out, as the prototype's.
fn curve(u: f64) -> f64 {
    if u < 0.5 { return 4.0 * u * u * u; }
    let k = 2.0 - 2.0 * u;
    return 1.0 - 0.5 * k * k * k;
}

// The soft ease's curve: a half cosine, gentle in and out (the hot-seat turn: on the cubic
// over 0.7 s it crept, then swung through the middle at 390° a second, 2026-11-12).
fn soft_curve(u: f64) -> f64 { 0.5 - 0.5 * cos(PI * u) }

fn value(e: Ease, now: f64) -> f32 {
    guard e.length > 0.0 && now < e.start + e.length else { return e.to; }
    let u = clamp((now - e.start) / e.length, 0.0, 1.0);
    let k = if e.soft { soft_curve(u) } else { curve(u) };
    return e.from + (e.to - e.from) * k as f32;
}

fn moving(e: Ease, now: f64) -> bool { e.from != e.to && e.length > 0.0 && now < e.start + e.length }

// Eases from where it is at `now` to `to` over `length` seconds.
fn go(e: Ease&, to: f32, now: f64, length: f64) {
    e.from = value(e, now);
    e.to = to;
    e.start = now;
    e.length = length;
}

// Puts it at v at once.
fn put(e: Ease&, v: f32) {
    e.from = v;
    e.to = v;
    e.length = 0.0;
}

// The camera: the view (0 the rest angle, 1 the top view), the zoom (0 the board at rest,
// 1 the field framed), the board's turn in degrees (the hot-seat turn, adding 180 each
// time), and the showcase's turn (`swing`, degrees round) and tip (`tilt`, degrees added
// to the view's angle). `showcase` while its mode is on, when a drag on the board moves
// the camera (`held` from a press to its release, the pointer last at `last`, in pixels).
// `ready` once the turn has been put where the game stands, which a new game undoes.
struct Rig {
    top:      Ease   = Ease {},
    zoom:     Ease   = Ease {},
    turn:     Ease   = Ease { soft: true, .. },
    swing:    Ease   = Ease {},
    tilt:     Ease   = Ease {},
    showcase: bool   = false,
    across:   bool   = false,   // the top view and the zoom set for a friend's game that doesn't turn
    held:     bool   = false,
    last:     float2 = float2 { 0.0, 0.0 },
    ready:    bool   = false,
}

// The view's angle at `now`, from `rest` (the orientation's) toward the top view.
fn pitch(r: Rig&, rest: f32, now: f64) -> f32 { rest + (TOP_PITCH - rest) * value(r.top, now) }

// The board's turn at `now`, in 0..360.
fn turn(r: Rig&, now: f64) -> f32 {
    let t = value(r.turn, now);
    return t - 360.0 * floor(t / 360.0);
}

// The camera the board is fitted for at `now`: the view's angle and the board's turn, as
// the board's bounds follow them (panel::aim).
fn base(r: Rig&, rest: f32, now: f64) -> view3d::Camera {
    return view3d::Camera { pitch: pitch(r, rest, now), yaw: 0.0, turn: turn(r, now) };
}

// The camera drawn through at `now`: the fitted one turned and tipped by the showcase,
// which keeps the fit, as the prototype's does.
fn camera(r: Rig&, rest: f32, now: f64) -> view3d::Camera {
    return view3d::Camera { pitch: pitch(r, rest, now) + value(r.tilt, now), yaw: value(r.swing, now),
                            turn: turn(r, now) };
}

// Whether the board is off its rest angle, turned or tipped by the showcase and left so:
// the view button shows its dot, and its tap brings the board back first.
fn off_rest(r: Rig&) -> bool { r.swing.to != 0.0 || r.tilt.to != 0.0 }

// Whether the view is the top one, or easing to it.
fn top(r: Rig&) -> bool { r.top.to > 0.5 }
fn zoomed(r: Rig&) -> bool { r.zoom.to > 0.5 }

// Whether anything is easing at `now`; the app draws while it is.
fn moving(r: Rig&, now: f64) -> bool {
    return moving(r.top, now) || moving(r.zoom, now) || moving(r.turn, now) || moving(r.swing, now)
           || moving(r.tilt, now);
}

// The view button: off the rest angle, back to rest; else the rest angle and the top view
// in turn.
fn view_tap(r: Rig&, now: f64) {
    if off_rest(r) {
        go(r.swing, 0.0, now, EASE);
        go(r.tilt, 0.0, now, EASE);
        go(r.top, 0.0, now, EASE);
        return;
    }
    go(r.top, if top(r) { 0.0 } else { 1.0 }, now, EASE);
}

// The zoom button: the field framed, or the board at rest again.
fn zoom_tap(r: Rig&, now: f64) { go(r.zoom, if zoomed(r) { 0.0 } else { 1.0 }, now, EASE); }

// The showcase button: its mode on or off; off keeps the angle the drags left.
fn showcase_tap(r: Rig&) {
    r.showcase = !r.showcase;
    r.held = false;
}

// A drag of d dp in the showcase at `now`, the view's rest angle `rest`: across turns the
// board (SWING either way), down tips it toward the top (LOW to HIGH degrees down).
fn drag(r: Rig&, d: float2, rest: f32, now: f64) {
    let base = pitch(r, rest, now);
    put(r.swing, clamp(value(r.swing, now) - d.x * DRAG, -SWING, SWING));
    let p = clamp(base + value(r.tilt, now) + d.y * DRAG, LOW, HIGH);
    put(r.tilt, p - base);
}

// The pointer in the showcase, `scale` pixels a dp: a press takes it, a drag moves the
// camera, a release lets go. Returns whether the camera moved.
fn drive(r: Rig&, at: float2, down: bool, pressed: bool, released: bool, scale: f32, rest: f32, now: f64) -> bool {
    if pressed {
        r.held = true;
        r.last = at;
    }
    var moved = false;
    if r.held && down && (at.x != r.last.x || at.y != r.last.y) {
        drag(r, (at - r.last) * (1.0 / scale), rest, now);
        r.last = at;
        moved = true;
    }
    if released { r.held = false; }
    return moved;
}

// The showcase's angle eased back to rest and its mode off: a new game, a hot-seat turn.
fn settle(r: Rig&, now: f64, length: f64 = EASE) {
    r.showcase = false;
    r.held = false;
    if r.swing.to != 0.0 || moving(r.swing, now) { go(r.swing, 0.0, now, length); }
    if r.tilt.to != 0.0 || moving(r.tilt, now) { go(r.tilt, 0.0, now, length); }
}

// The board faces `side` (0 the near side, white; 1 the far one, black) at `now`: turned
// at once the first time (`ready`), else, when it faces the other one, turning 180° more
// over TURN, the showcase's angle easing back with it. Returns whether it turned, for the
// frame to be drawn.
fn face(r: Rig&, side: i64, now: f64) -> bool {
    let want: f32 = if side == 1 { 180.0 } else { 0.0 };
    guard r.ready else {
        let was = r.turn.to;
        put(r.turn, want);
        r.ready = true;
        return was != want;
    }
    let to = r.turn.to - 360.0 * floor(r.turn.to / 360.0);
    guard to != want else { return false; }
    // Kept under 360 between turns, so the angle doesn't grow.
    if !moving(r.turn, now) { put(r.turn, to); }
    go(r.turn, r.turn.to + 180.0, now, TURN);
    settle(r, now, TURN);
    return true;
}

// Whether the board faces the far side (black) or is turning to, as the flat board shows
// the turn: at once, where the 3D board eases round.
fn faces_far(r: Rig&) -> bool {
    let to = r.turn.to - 360.0 * floor(r.turn.to / 360.0);
    return to == 180.0;
}

// A friend's game that doesn't turn the board begins in the top view, zoomed (2026-11-12):
// the players sit at either side of the tablet, and looking down the board reads alike to
// both. The camera buttons change them as ever. `friend` false for any other game: what
// such a game set goes back to the view at rest, unzoomed.
fn across_table(r: Rig&, friend: bool) {
    if friend {
        put(r.top, 1.0);
        put(r.zoom, 1.0);
        r.across = true;
    } else if r.across {
        put(r.top, 0.0);
        put(r.zoom, 0.0);
        r.across = false;
    }
}

// A game begins on the board as it stands: the turn put afresh with its first frame (to
// face the near side, or as a friend's game stands), the showcase off and its angle at
// rest at once. The view and the zoom stay as chosen.
fn reset(r: Rig&) {
    r.ready = false;
    put(r.turn, 0.0);
    r.showcase = false;
    r.held = false;
    put(r.swing, 0.0);
    put(r.tilt, 0.0);
}
