// The UI layer (gui/), headless: rect cuts and grid cells; a button is true only on the
// frame the pointer is released over it after going down on it, so a press that slides
// off, or one that starts elsewhere and is released over it, does nothing; a press on
// the UI is taken from the board; the press animation runs for its 0.12 s and then
// stops asking for frames; acted is set on a click's frame only, for the app to draw
// the next one, where widgets declared before the click show what it changed; and the
// quads one frame makes.
import std;
import vec;
import gui from "../../gui";

fn show(name: const u8[:], r: float4) { print(name, ": ", r.x, " ", r.y, " ", r.z, " ", r.w); }

fn frame(g: gui::Gui&, at: float2, down: bool, pressed: bool, released: bool, now: f64,
         what: const u8[:]) {
    gui::begin(g, gui::Input { at: at, down: down, pressed: pressed, released: released }, 1.0, now);
    gui::panel(g, float4 { 0.0, 0.0, 300.0, 200.0 });
    let a = gui::button(g, 1, float4 { 20.0, 20.0, 88.0, 88.0 }, gui::UNDO);
    let b = gui::button(g, 2, float4 { 120.0, 20.0, 88.0, 88.0 }, gui::HINT);
    print(what, ": a ", a, ", b ", b, ", took ", g.took, ", a pressed ", gui::pressed(g, 1),
          ", animating ", gui::animating(g), ", acted ", g.acted, ", quads ", g.quads.len);
}

fn main() {
    var r = float4 { 0.0, 0.0, 400.0, 300.0 };
    show("top 50", gui::cut_top(r, 50.0));
    show("left 100", gui::cut_left(r, 100.0));
    show("right 500 (all that is left)", gui::cut_right(r, 500.0));
    show("left over", r);
    var s = float4 { 0.0, 0.0, 400.0, 300.0 };
    show("bottom 30", gui::cut_bottom(s, 30.0));
    show("inset 10", gui::inset(s, 10.0));
    show("centered 100 x 50", gui::center(s, 100.0, 50.0));
    for i in 4 { show(str("2 x 2 cell ", i), gui::cell(s, 2, 2, 104.0, 104.0, 16.0, i)); }

    var g = gui::Gui {};
    let on_a = float2 { 50.0, 50.0 };
    let on_b = float2 { 150.0, 50.0 };
    let off = float2 { 250.0, 150.0 };
    let away = float2 { 500.0, 500.0 };
    frame(g, away, false, false, false, 0.0, "idle");
    // A tap on a: down, then up a frame later.
    frame(g, on_a, true, true, false, 1.0, "down on a");
    frame(g, on_a, true, false, false, 1.06, "held, halfway down");
    frame(g, on_a, true, false, false, 1.2, "held, all the way");
    frame(g, on_a, false, false, true, 1.3, "up on a");
    frame(g, on_a, false, false, false, 1.36, "after, halfway up");
    frame(g, on_a, false, false, false, 1.5, "after, all the way");
    // Down on a, slid off onto b, up there: nothing.
    frame(g, on_a, true, true, false, 2.0, "down on a");
    frame(g, on_b, true, false, false, 2.2, "slid to b");
    frame(g, on_b, false, false, true, 2.3, "up on b");
    // Down on the panel between them, up on b: nothing, but the press is the UI's.
    frame(g, off, true, true, false, 3.0, "down on the panel");
    frame(g, on_b, false, false, true, 3.1, "up on b");
    // Down off the panel: the board's.
    frame(g, away, true, true, false, 4.0, "down off the UI");
    frame(g, away, false, false, true, 4.1, "up off the UI");
    // A quick tap, down and up within one frame.
    frame(g, on_b, false, true, true, 5.0, "tap on b in one frame");
    frame(g, on_b, false, false, false, 5.5, "after");
    // The quads of a frame.
    for q, i in g.quads {
        print("quad ", i, ": kind ", q.look.x, ", rect ", q.rect.x, " ", q.rect.y, " ", q.rect.z, " ",
              q.rect.w, ", radius ", q.look.y, ", icon ", q.look.z);
    }
}
