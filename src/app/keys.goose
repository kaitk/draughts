// The keys' side of the platform (task 072; rendering.md, "Keys"): the arrows, Enter,
// Space, and Tab read into gui::Input, and a gamepad's the same way: the D-pad or the left
// stick moves as the arrows do, A (the bottom button) as Enter, the shoulder buttons as
// Tab and Shift and Tab, between a screen's groups, and B goes back as Escape does (back).
// An arrow or the D-pad held repeats, REPEAT_DELAY seconds after its press and then every
// REPEAT_RATE, as a desktop's lists do: gfx reports a key's first press only. The main
// loop's wake timer counts the next repeat (repeat_in), so a held arrow repeats in an idle
// loop too. Part of host, in its namespace.
//
// The gamepad is goose_gfx's (the fork's, docs/goose-findings.md, "goose_gfx: no
// gamepad"), which reads it and wakes its idle wait when it is used, opened with
// SYSTEM_GAMEPADS (host::open). The release's gfx.goose doesn't declare its gamepad
// functions, so they are declared here; gfx_fork.c stands in for them where the release's
// own gfx is linked.
namespace host;
import std;
import gfx;
import gui from "../gui";

let REPEAT_DELAY = 0.4;     // seconds an arrow is held before it repeats
let REPEAT_RATE = 0.08;     // seconds between its repeats

extern fn pad_connected(slot: i64) -> bool = "gs_gfx_gamepad_connected";
extern fn pad_down(slot: i64, button: i64) -> bool = "gs_gfx_gamepad_down";
extern fn pad_pressed(slot: i64, button: i64) -> bool = "gs_gfx_gamepad_pressed";
extern fn pad_axis(slot: i64, axis: i64) -> f32 = "gs_gfx_gamepad_axis";
let SYSTEM_GAMEPADS = 128;  // gfx's open flag: the system reads the pads (gfx.goose's)
let PAD_SLOTS = 4;          // gfx's MAX_GAMEPADS
let PAD_SOUTH = 0;          // gfx's buttons (SDL's), and the left stick's axes
let PAD_EAST = 1;
let PAD_LEFT_SHOULDER = 9;
let PAD_RIGHT_SHOULDER = 10;
let PAD_DPAD_UP = 11;       // then down, left, right
let PAD_AXIS_X = 0;
let PAD_AXIS_Y = 1;         // down positive

// The gamepad's bits, as pad_bits makes them.
let PAD_A = 1;
let PAD_B = 2;
let PAD_LB = 16;
let PAD_RB = 32;
let PAD_UP = 256;           // the D-pad or the stick; the next three after it
let PAD_THERE = 1 << 31;    // a gamepad is connected
let STICK_ON = 0.5;         // the stick's way out that counts as the D-pad
let STICK_OFF = 0.33;       // and under which it is let go again

// The arrow held, one of gui::STEP_UP..STEP_RIGHT or STEP_NONE, and when it next repeats;
// the gamepad's bits last frame, and whether its B went down this frame; the stick's
// direction bit last frame, for its hysteresis.
struct Repeat {
    step:    i64  = 0,
    at:      f64  = 0.0,
    buttons: i64  = 0,
    back:    bool = false,
    stick:   i64  = 0,
}

// Whether the gamepad in slot has button down, or pressed since the last frame though let
// go again (gfx keeps the press).
fn pad_button(slot: i64, button: i64) -> bool { pad_down(slot, button) || pad_pressed(slot, button) }

// The first gamepad connected's buttons this frame as the bits above, PAD_THERE while one
// is; 0 with none. The left stick past STICK_ON counts as the D-pad toward its larger
// axis, let go under STICK_OFF (a little hysteresis, so a stick resting near the
// threshold doesn't flicker).
fn pad_bits(r: Repeat&) -> i64 {
    var slot = -1;
    for s in PAD_SLOTS {
        if slot < 0 && pad_connected(s) { slot = s; }
    }
    guard slot >= 0 else {
        r.stick = 0;
        return 0;
    }
    var bits = PAD_THERE;
    if pad_button(slot, PAD_SOUTH) { bits |= PAD_A; }
    if pad_button(slot, PAD_EAST) { bits |= PAD_B; }
    if pad_button(slot, PAD_LEFT_SHOULDER) { bits |= PAD_LB; }
    if pad_button(slot, PAD_RIGHT_SHOULDER) { bits |= PAD_RB; }
    for d in 4 {
        if pad_button(slot, PAD_DPAD_UP + d) { bits |= PAD_UP << d; }
    }
    let x = pad_axis(slot, PAD_AXIS_X);
    let y = pad_axis(slot, PAD_AXIS_Y);
    let ax = max(x, -x);
    let ay = max(y, -y);
    let far = max(ax, ay);
    var want = PAD_UP;              // up, down, left, right: the bits PAD_UP << 0..3
    if ax > ay {
        want = if x < 0.0 { PAD_UP << 2 } else { PAD_UP << 3 };
    } else if y > 0.0 {
        want = PAD_UP << 1;
    }
    var dir = 0;
    if far > STICK_ON {
        dir = want;
    } else if r.stick != 0 && far > STICK_OFF {
        dir = r.stick;              // held past STICK_OFF: as it was
    }
    r.stick = dir;
    return bits | dir;
}

// The arrow key that names step.
fn arrow(step: i64) -> const u8[:] {
    return match step {
        gui::STEP_UP => "Up",
        gui::STEP_DOWN => "Down",
        gui::STEP_LEFT => "Left",
        _ => "Right",
    };
}

// The gamepad's bit for step: the D-pad's (or the stick's) that way.
fn pad_bit(step: i64) -> i64 { PAD_UP << (step - gui::STEP_UP) }

// The keys' moves into input: an arrow or the D-pad pressed this frame, or the one held
// when its repeat is due; Enter, Space, or A pressed, and held; Tab, or a shoulder button.
fn keys(r: Repeat&, input: gui::Input&, now: f64) {
    let down = pad_bits(r);
    let went = down & ~r.buttons;
    r.buttons = down;
    var step = gui::STEP_NONE;
    for s in gui::STEP_UP..gui::STEP_RIGHT + 1 {
        if step == gui::STEP_NONE && (gfx::key_pressed(arrow(s)) || went & pad_bit(s) != 0) { step = s; }
    }
    if step != gui::STEP_NONE {
        r.step = step;
        r.at = now + REPEAT_DELAY;
    } else if r.step != gui::STEP_NONE {
        if !gfx::key_down(arrow(r.step)) && down & pad_bit(r.step) == 0 {
            r.step = gui::STEP_NONE;
        } else if now >= r.at {
            step = r.step;
            r.at = now + REPEAT_RATE;
        }
    }
    input.step = step;
    input.confirm = gfx::key_pressed("Return") || gfx::key_pressed("Keypad Enter") || gfx::key_pressed("Space")
                    || went & PAD_A != 0;
    input.held = gfx::key_down("Return") || gfx::key_down("Keypad Enter") || gfx::key_down("Space") || down & PAD_A != 0;
    if gfx::key_pressed("Tab") {
        input.tab = if gfx::key_down("Left Shift") || gfx::key_down("Right Shift") { -1 } else { 1 };
    } else if went & PAD_RB != 0 {
        input.tab = 1;
    } else if went & PAD_LB != 0 {
        input.tab = -1;
    }
    r.back = went & PAD_B != 0;
}

// Seconds until the held arrow's next repeat, or -1 with none held.
fn repeat_in(r: Repeat, now: f64) -> f64 {
    guard r.step != gui::STEP_NONE else { return -1.0; }
    return max(0.0, r.at - now);
}
