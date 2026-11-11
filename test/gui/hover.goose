// The mouse's hover on a desktop (task 066), headless: the tile under the pointer lights
// from the frame after it is found there, over gui::PRESS, eased, and fades out when the
// pointer leaves; one left mid-fade turns from where it is; the frames are asked for
// only while the hover moves or fades, never for a pointer resting or moving within one
// tile; a pointer down elsewhere lights nothing, a dimmed tile never lights, and with
// desktop_scale 0 (a phone, a tablet, --touch on) nothing does. The fade reaches the
// tile's quad in extra.z.
import std;
import vec;
import gui from "../../src/gui";

let A = float4 { 20.0, 20.0, 88.0, 88.0 };
let B = float4 { 120.0, 20.0, 88.0, 88.0 };

// The extra.z of the tile quad drawn at r, or -1.
fn lit_quad(g: gui::Gui&, r: float4) -> f32 {
    for q in g.quads { if q.look.x == gui::BUTTON && q.rect == r { return q.extra.z; } }
    return -1.0;
}

fn milli(x: f32) -> f64 { floor(x as f64 * 1000.0 + 0.5) / 1000.0 }

// A frame of a panel with buttons a and b, and d taking taps while `d_on`, the pointer at `at`.
fn frame(g: gui::Gui&, at: float2, down: bool, pressed: bool, now: f64, d_on: bool, what: const u8[:]) {
    gui::begin(g, gui::Input { at: at, down: down, pressed: pressed }, 1.0, now);
    gui::panel(g, float4 { 0.0, 0.0, 300.0, 300.0 });
    gui::button(g, 1, A, gui::UNDO);
    gui::button(g, 2, B, gui::HINT);
    gui::hold_if(g, 4, float4 { 120.0, 120.0, 88.0, 88.0 }, d_on);
    print(what, ": a ", milli(gui::hover(g, 1)), ", b ", milli(gui::hover(g, 2)),
          ", d ", milli(gui::hover(g, 4)), ", a's quad ", milli(lit_quad(g, A)), ", a pressed ",
          milli(gui::pressed(g, 1)), ", animating ", gui::animating(g));
}

fn main() {
    var g = gui::Gui {};
    let on_a = float2 { 50.0, 50.0 };
    let on_a2 = float2 { 90.0, 90.0 };
    let on_b = float2 { 150.0, 50.0 };
    let panel = float2 { 250.0, 250.0 };
    let on_dim = float2 { 150.0, 150.0 };
    let away = float2 { 500.0, 500.0 };

    print("desktop_scale 0 (a phone, a tablet, --touch on):");
    gui::desktop_scale = 0.0;
    frame(g, away, false, false, 0.0, true, "  away");
    frame(g, on_a, false, false, 1.0, true, "  over a");
    frame(g, on_a, false, false, 1.02, true, "  over a, a frame on");
    frame(g, on_a, false, false, 1.5, true, "  over a, resting");

    print("desktop_scale 1 (a desktop):");
    gui::desktop_scale = 1.0;
    frame(g, away, false, false, 10.0, true, "  away");
    frame(g, on_a, false, false, 11.0, true, "  onto a: found");
    frame(g, on_a, false, false, 11.02, true, "  a frame on: fading in");
    frame(g, on_a, false, false, 11.08, true, "  halfway");
    frame(g, on_a, false, false, 11.2, true, "  all the way");
    frame(g, on_a2, false, false, 11.5, true, "  moved within a");
    frame(g, on_b, false, false, 12.0, true, "  onto b: found");
    frame(g, on_b, false, false, 12.02, true, "  a frame on");
    frame(g, on_b, false, false, 12.08, true, "  halfway");
    frame(g, on_b, false, false, 12.2, true, "  all the way");
    frame(g, panel, false, false, 13.0, true, "  onto the panel");
    frame(g, panel, false, false, 13.02, true, "  a frame on");
    frame(g, panel, false, false, 13.06, true, "  a quarter of the way down");
    frame(g, on_b, false, false, 13.07, true, "  back onto b");
    frame(g, on_b, false, false, 13.09, true, "  a frame on: turned where it was");
    frame(g, on_b, false, false, 13.15, true, "  rising again");
    frame(g, on_b, false, false, 13.3, true, "  all the way");
    frame(g, away, false, false, 14.0, true, "  off the window");
    frame(g, away, false, false, 14.02, true, "  a frame on");
    frame(g, away, false, false, 14.2, true, "  all the way");

    print("pressed:");
    frame(g, on_a, false, false, 20.0, true, "  onto a");
    frame(g, on_a, false, false, 20.02, true, "  a frame on");
    frame(g, on_a, false, false, 20.2, true, "  lit");
    frame(g, on_a, true, true, 20.3, true, "  down on a");
    frame(g, on_a, true, false, 20.5, true, "  held: lit and pressed");
    frame(g, on_a, false, false, 20.6, true, "  up on a");
    frame(g, on_a, false, false, 20.8, true, "  up");
    frame(g, away, true, true, 21.0, true, "  down off the UI");
    frame(g, on_b, true, false, 21.02, true, "  slid over b, down");
    frame(g, on_b, true, false, 21.3, true, "  still down over b");
    frame(g, on_b, false, false, 21.4, true, "  up over b");
    frame(g, on_b, false, false, 21.42, true, "  a frame on");

    frame(g, on_b, false, false, 21.6, true, "  lit");
    frame(g, away, false, false, 22.0, true, "  off");
    frame(g, away, false, false, 22.02, true, "  a frame on");
    frame(g, away, false, false, 22.2, true, "  dark");

    print("dimmed:");
    frame(g, on_dim, false, false, 30.0, false, "  over the dimmed tile");
    frame(g, on_dim, false, false, 30.2, false, "  resting");
    frame(g, on_dim, false, false, 31.0, true, "  turned on");
    frame(g, on_dim, false, false, 31.02, true, "  a frame on");
    frame(g, on_dim, false, false, 31.2, true, "  lit");
    frame(g, on_dim, false, false, 31.3, false, "  turned off under the mouse");
    frame(g, on_dim, false, false, 31.32, false, "  a frame on");
    gui::desktop_scale = 0.0;
}
