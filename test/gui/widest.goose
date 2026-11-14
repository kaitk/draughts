// gui::safe on a desktop keeps the screens to the window's middle WIDEST (1.9) times its
// height: an ultrawide's full window loses its sides to the photograph, a 27" 16:9 and a
// MacBook's 16:10 don't; a touch screen is never narrowed, a phone's 20:9 landscape
// included. bleed carries a glass at the area's edge over the room beside it.
import std;
import vec;
import gui from "../../src/gui";

fn show(g: gui::Gui&, what: const u8[:], w: f32, h: f32) {
    let a = gui::safe(g, w, h);
    let b = gui::bleed(g, float4 { a.x, a.y, 100.0, a.w }, a);
    print(what, ": area ", a.x, " ", a.y, " ", a.z, " ", a.w, ", side ", g.side, ", a left glass bled ", b.x, " ", b.z);
}

fn main() {
    var g = gui::Gui {};
    gui::desktop_scale = 1.0;
    show(g, "desktop 3440 x 1440", 3440.0, 1440.0);
    show(g, "desktop 2560 x 1440", 2560.0, 1440.0);
    show(g, "desktop 1728 x 1080", 1728.0, 1080.0);
    g.insets = float4 { 0.0, 40.0, 0.0, 0.0 };
    show(g, "desktop 3440 x 1440, 40 px off its top", 3440.0, 1440.0);
    g.insets = float4 { 52.0, 0.0, 0.0, 37.0 };
    gui::desktop_scale = 0.0;
    show(g, "touch 2400 x 1080, a cutout and a bar", 2400.0, 1080.0);
}
