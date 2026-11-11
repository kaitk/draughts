// The keys' side of the platform (task 072; rendering.md, "Keys"): the arrows, Enter, and
// Space read into gui::Input, and an arrow held repeating, REPEAT_DELAY seconds after its
// press and then every REPEAT_RATE, as a desktop's lists do: gfx reports a key's first
// press only. The main loop's wake timer counts the next repeat (repeat_in), so a held
// arrow repeats in an idle loop too. A gamepad's moves will come in here (task 064). Part
// of host, in its namespace.
namespace host;
import std;
import gfx;
import gui from "../gui";

let REPEAT_DELAY = 0.4;     // seconds an arrow is held before it repeats
let REPEAT_RATE = 0.08;     // seconds between its repeats

// The arrow held, one of gui::STEP_UP..STEP_RIGHT or STEP_NONE, and when it next repeats.
struct Repeat {
    step: i64 = 0,
    at:   f64 = 0.0,
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

// The keys' moves into input: an arrow pressed this frame, or the one held when its repeat
// is due; Enter or Space pressed, and held.
fn keys(r: Repeat&, input: gui::Input&, now: f64) {
    var step = gui::STEP_NONE;
    for s in gui::STEP_UP..gui::STEP_RIGHT + 1 {
        if step == gui::STEP_NONE && gfx::key_pressed(arrow(s)) { step = s; }
    }
    if step != gui::STEP_NONE {
        r.step = step;
        r.at = now + REPEAT_DELAY;
    } else if r.step != gui::STEP_NONE {
        if !gfx::key_down(arrow(r.step)) {
            r.step = gui::STEP_NONE;
        } else if now >= r.at {
            step = r.step;
            r.at = now + REPEAT_RATE;
        }
    }
    input.step = step;
    input.confirm = gfx::key_pressed("Return") || gfx::key_pressed("Keypad Enter") || gfx::key_pressed("Space");
    input.held = gfx::key_down("Return") || gfx::key_down("Keypad Enter") || gfx::key_down("Space");
}

// Seconds until the held arrow's next repeat, or -1 with none held.
fn repeat_in(r: Repeat, now: f64) -> f64 {
    guard r.step != gui::STEP_NONE else { return -1.0; }
    return max(0.0, r.at - now);
}
