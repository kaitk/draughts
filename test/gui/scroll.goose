// A scrolling list (gui::scroll_begin, task 050): ten 88 px rows in a 300 px view. A tap
// on a row is still a tap, also one that wobbles under the slop; a press that moves past
// the slop is a drag that scrolls the list and clicks nothing, and the frames draw while
// it lasts; the offset stops at the list's ends; the wheel scrolls it; a press outside
// the view reaches nothing in the list; the list's quads are marked to be clipped and the
// rest aren't; and another list starts at its top.
import std;
import vec;
import gui from "../../src/gui";

let VIEW = float4 { 0.0, 100.0, 200.0, 300.0 };
let ROW = 88.0;
let ROWS = 10;

// One frame of list `id` with the pointer as given: which row was tapped, or -1.
fn frame(g: gui::Gui&, id: i64, at: float2, down: bool, pressed: bool, released: bool, now: f64, wheel: f32,
         what: const u8[:]) {
    gui::begin(g, gui::Input { at: at, down: down, pressed: pressed, released: released, wheel: wheel, .. }, 1.0, now);
    gui::panel(g, float4 { 0.0, 0.0, 200.0, 90.0 });
    let off = gui::scroll_begin(g, id, VIEW, ROWS * ROW);
    var tapped = -1;
    for i in ROWS {
        let r = float4 { 0.0, VIEW.y - off + i * ROW, 200.0, ROW };
        if gui::button(g, 10 + i, r, gui::UNDO) { tapped = i; }
    }
    gui::scroll_end(g);
    var clipped = 0;
    for q in g.quads { if q.extra.z >= gui::CLIP { clipped++; } }
    print(what, ": offset ", off, ", tapped ", tapped, ", dragging ", g.scroll.dragging, ", animating ",
          gui::animating(g), ", clipped ", clipped, " of ", g.quads.len);
}

fn main() {
    var g = gui::Gui {};
    let away = float2 { 500.0, 500.0 };
    frame(g, 1, away, false, false, false, 0.0, 0.0, "idle");
    // A tap on row 1 (y 188 to 276).
    frame(g, 1, float2 { 50.0, 200.0 }, true, true, false, 1.0, 0.0, "down on row 1");
    frame(g, 1, float2 { 52.0, 206.0 }, true, false, false, 1.1, 0.0, "moved 6 px, under the slop");
    frame(g, 1, float2 { 52.0, 206.0 }, false, false, true, 1.2, 0.0, "up: a tap");
    // A drag up from row 1: the list scrolls, nothing is clicked.
    frame(g, 1, float2 { 50.0, 300.0 }, true, true, false, 2.0, 0.0, "down on row 2");
    frame(g, 1, float2 { 50.0, 285.0 }, true, false, false, 2.1, 0.0, "moved 15 px: a drag");
    frame(g, 1, float2 { 50.0, 150.0 }, true, false, false, 2.2, 0.0, "dragged 150 px");
    frame(g, 1, float2 { 50.0, 150.0 }, false, false, true, 2.3, 0.0, "up over row 2: no tap");
    frame(g, 1, away, false, false, false, 2.4, 0.0, "after");
    // Past the end: it stops at the content's foot (880 - 300).
    frame(g, 1, float2 { 50.0, 390.0 }, true, true, false, 3.0, 0.0, "down");
    frame(g, 1, float2 { 50.0, -2000.0 }, true, false, false, 3.1, 0.0, "dragged far up");
    frame(g, 1, float2 { 50.0, -2000.0 }, false, false, true, 3.2, 0.0, "up");
    // The wheel over the list, up two steps of 40 px; then over the panel, nothing.
    frame(g, 1, float2 { 50.0, 200.0 }, false, false, false, 4.0, 2.0, "wheel over the list");
    frame(g, 1, float2 { 50.0, 50.0 }, false, false, false, 4.1, 2.0, "wheel over the panel");
    // A tap above the view, where a scrolled row would lie under the panel: no row.
    frame(g, 1, float2 { 50.0, 60.0 }, true, true, false, 5.0, 0.0, "down above the view");
    frame(g, 1, float2 { 50.0, 60.0 }, false, false, true, 5.1, 0.0, "up above the view");
    // Another list starts at its top.
    frame(g, 2, away, false, false, false, 6.0, 0.0, "list 2");
}
