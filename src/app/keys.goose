// The keys' side of the platform (task 072; rendering.md, "Keys"): the arrows, Enter,
// Space, and Tab read into gui::Input, and a gamepad's the same way (pad.c): the D-pad or
// the left stick moves as the arrows do, A (the bottom button) as Enter, the shoulder
// buttons as Tab and Shift and Tab, between a screen's groups, and B goes back as Escape
// does (back). An arrow or the D-pad held repeats, REPEAT_DELAY seconds after its press and
// then every REPEAT_RATE, as a desktop's lists do: gfx reports a key's first press only.
// The main loop's wake timer counts the next repeat (repeat_in), so a held arrow repeats
// in an idle loop too. Part of host, in its namespace.
namespace host;
import std;
import gfx;
import gui from "../gui";

let REPEAT_DELAY = 0.4;     // seconds an arrow is held before it repeats
let REPEAT_RATE = 0.08;     // seconds between its repeats

// The gamepad's buttons down this frame (pad.c's bits), 0 with none connected.
extern fn draughts_pad() -> i64;
let PAD_A = 1;
let PAD_B = 2;
let PAD_LB = 16;
let PAD_RB = 32;
let PAD_UP = 256;           // the D-pad or the stick; the next three after it

// The arrow held, one of gui::STEP_UP..STEP_RIGHT or STEP_NONE, and when it next repeats;
// the gamepad's buttons down last frame, and whether its B went down this frame.
struct Repeat {
    step:    i64  = 0,
    at:      f64  = 0.0,
    buttons: i64 = 0,
    back:    bool = false,
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
    let down = draughts_pad();
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
