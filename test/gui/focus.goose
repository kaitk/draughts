// The keys' focus (gui::focus_keys, task 072), headless: the first arrow key focuses the
// screen's primary control, or the first declared where none is; the arrows move it to
// the nearest control that way, one in line before a nearer one off to the side, and
// leave it where none lies that way; Enter presses the focused control, a click as a
// release over it is, and with none focused focuses the primary as the first arrow does,
// pressing nothing; a disabled control is never
// focused, the nearest that way taken past it; the focus is lit as the mouse's hover is
// and ringed (one RING quad), the frames asked for only while that light moves; the mouse moving, a press, or the wheel lets it go; a control the next
// frame doesn't declare (another screen) hands it to that screen's primary; a screen a
// transition leaves (listen off) offers none; and Enter held on a focused hold tile fills
// its ring as a held press does, Enter pressed alone never firing it, let go early
// nothing, held to the end firing it once and no more until Enter is pressed again. On a
// screen of one group, Tab steps through the controls in the order declared, round from
// the last to the first, and Shift and Tab back (the board's grid and the groups:
// test/game/board_keys).
import std;
import vec;
import gui from "../../src/gui";

// A column of three rows (1..3, the second primary) and, right of it, a grid of two by
// two tiles (11, 12 over 13, 14), the last dimmed while `dim`. Prints what was clicked.
fn screen(g: gui::Gui&, step: i64, confirm: bool, at: float2, now: f64, dim: bool, what: const u8[:], tab: i64 = 0) {
    gui::begin(g, gui::Input { at: at, step: step, confirm: confirm, tab: tab, .. }, 1.0, now);
    var clicked: u8[>..] = [];
    for i in 3 {
        if gui::row(g, 1 + i, float4 { 20.0, 20.0 + 100.0 * i, 300.0, 88.0 }, gui::NEXT, "row", "", i == 1, true) {
            format(clicked, " row ", 1 + i);
        }
    }
    for i in 4 {
        let r = float4 { 360.0 + 100.0 * (i % 2), 70.0 + 100.0 * (i / 2), 88.0, 88.0 };
        let clicked_tile, unused = gui::hold_if(g, 11 + i, r, !(dim && i == 3));
        gui::fill(g, r, float4 { 1.0, 1.0, 1.0, 0.1 }, 16.0);
        if clicked_tile { format(clicked, " tile ", 11 + i); }
    }
    var rings = 0;
    for q in g.quads { if q.look.x == gui::RING { rings++; } }
    print(what, ": focus ", g.focus, ", lit ", g.under, ", rings ", rings, ", clicked", if clicked.len == 0 { " nothing" } else { clicked[..] },
          ", acted ", g.acted, ", animating ", gui::animating(g));
}

// One frame of a lone hold tile (id 70, primary, 2 s) with the keys as given.
fn hold_frame(g: gui::Gui&, step: i64, confirm: bool, held: bool, now: f64, what: const u8[:]) {
    gui::begin(g, gui::Input { at: float2 { -1.0, -1.0 }, step: step, confirm: confirm, held: held, .. }, 1.0, now);
    let fired, k = gui::hold_tile(g, 70, float4 { 20.0, 20.0, 300.0, 88.0 }, 20.0, 2.0, false);
    print(what, ": focus ", g.focus, ", ring ", k, ", fired ", fired, ", acted ", g.acted, ", holding ", g.holding);
}

fn main() {
    var g = gui::Gui {};
    gui::test_faces(g);
    gui::desktop_scale = 1.0;
    let away = float2 { -1.0, -1.0 };
    var now = 0.0;
    screen(g, gui::STEP_NONE, false, away, now, true, "at rest");
    screen(g, gui::STEP_NONE, true, away, now + 1.0, true, "enter with no focus: the primary, nothing pressed");
    screen(g, gui::STEP_NONE, false, float2 { -2.0, -2.0 }, now + 1.5, true, "the mouse moves: let go");
    now = 2.0;
    screen(g, gui::STEP_DOWN, false, away, now, true, "down: the primary");
    screen(g, gui::STEP_NONE, false, away, now + 0.02, true, "  a frame on");
    screen(g, gui::STEP_NONE, false, away, now + 1.0, true, "  resting");
    screen(g, gui::STEP_DOWN, false, away, now + 2.0, true, "down");
    screen(g, gui::STEP_DOWN, false, away, now + 3.0, true, "down at the last row: stays");
    screen(g, gui::STEP_UP, false, away, now + 4.0, true, "up");
    screen(g, gui::STEP_UP, false, away, now + 5.0, true, "up");
    screen(g, gui::STEP_RIGHT, false, away, now + 6.0, true, "right: the tile in line");
    screen(g, gui::STEP_DOWN, false, away, now + 7.0, true, "down");
    screen(g, gui::STEP_RIGHT, false, away, now + 8.0, true, "right: the dimmed tile skipped for the one above");
    screen(g, gui::STEP_LEFT, false, away, now + 9.0, true, "left: the tile in line");
    screen(g, gui::STEP_NONE, true, away, now + 10.0, true, "enter");
    screen(g, gui::STEP_NONE, false, away, now + 10.02, true, "  a frame on");
    screen(g, gui::STEP_NONE, false, float2 { 50.0, 50.0 }, now + 11.0, true, "the mouse moves over row 1");
    screen(g, gui::STEP_NONE, true, float2 { 50.0, 50.0 }, now + 12.0, true, "enter, the mouse leading: the primary, nothing pressed");
    screen(g, gui::STEP_NONE, false, float2 { 51.0, 50.0 }, now + 12.5, true, "the mouse moves: let go");
    screen(g, gui::STEP_UP, false, float2 { 50.0, 50.0 }, now + 13.0, true, "up: the primary again");
    screen(g, gui::STEP_NONE, false, float2 { 50.0, 50.0 }, now + 14.0, false, "  the pointer resting over row 1");
    screen(g, gui::STEP_NONE, false, float2 { 50.0, 50.0 }, now + 14.5, false, "tab: the next declared", 1);
    screen(g, gui::STEP_NONE, false, float2 { 50.0, 50.0 }, now + 14.6, false, "shift tab", -1);
    screen(g, gui::STEP_NONE, false, float2 { 50.0, 50.0 }, now + 14.7, false, "shift tab", -1);
    screen(g, gui::STEP_NONE, false, float2 { 50.0, 50.0 }, now + 14.8, false, "shift tab: round to the last", -1);

    // Another screen: one tile, primary, where the rows were; the focus goes to it.
    now = 20.0;
    gui::begin(g, gui::Input { at: float2 { 50.0, 50.0 }, .. }, 1.0, now);
    gui::row(g, 40, float4 { 20.0, 500.0, 300.0, 88.0 }, gui::NEXT, "other", "", false, true);
    gui::row(g, 41, float4 { 20.0, 600.0, 300.0, 88.0 }, gui::NEXT, "other", "", true, true);
    print("another screen: focus ", g.focus);
    gui::begin(g, gui::Input { at: float2 { 50.0, 50.0 }, .. }, 1.0, now + 0.02);
    print("  the next frame: focus ", g.focus);

    // A screen a transition leaves offers nothing: the arrow keeps the focus.
    gui::listen(g, false);
    gui::row(g, 41, float4 { 20.0, 600.0, 300.0, 88.0 }, gui::NEXT, "other", "", true, true);
    gui::listen(g, true);
    print("  declared deaf: offered ", g.spots.len);
    gui::begin(g, gui::Input { at: float2 { 50.0, 50.0 }, step: gui::STEP_DOWN, .. }, 1.0, now + 0.04);
    print("  down with nothing offered: focus ", g.focus);

    // The hold tile with the keys.
    var h = gui::Gui {};
    gui::test_faces(h);
    hold_frame(h, gui::STEP_NONE, false, false, 30.0, "hold tile at rest");
    hold_frame(h, gui::STEP_DOWN, false, false, 31.0, "down: focused");
    hold_frame(h, gui::STEP_NONE, true, true, 32.0, "enter pressed and let go");
    hold_frame(h, gui::STEP_NONE, false, false, 32.02, "  a frame on");
    hold_frame(h, gui::STEP_NONE, true, true, 33.0, "enter pressed, held");
    hold_frame(h, gui::STEP_NONE, false, true, 34.0, "  held 1 s");
    hold_frame(h, gui::STEP_NONE, false, false, 34.5, "  let go early");
    hold_frame(h, gui::STEP_NONE, true, true, 35.0, "enter pressed, held");
    hold_frame(h, gui::STEP_NONE, false, true, 36.0, "  held 1 s");
    hold_frame(h, gui::STEP_NONE, false, true, 37.0, "  held 2 s: full");
    hold_frame(h, gui::STEP_NONE, false, true, 38.0, "  still held");
    hold_frame(h, gui::STEP_NONE, false, true, 40.5, "  still held, 2.5 s on");
    hold_frame(h, gui::STEP_NONE, false, false, 41.0, "  let go");
    hold_frame(h, gui::STEP_NONE, true, true, 42.0, "enter pressed again");
}
