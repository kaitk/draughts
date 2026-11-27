// The light tuner (tools/light_tune.goose) drawing through goose-ngfx, so the room's views
// can be shot on both renderers and compared: its tune() with render3d_ngfx's Own, gfx's
// window opened WINDOW_ONLY with ngfx in it, as the app's build that holds both opens it.
// The panel is gfx's (ui) and isn't drawn here: run it headless for shots.
//
//   scripts/mac.py tools/light_tune_ngfx.goose   (NGFX and NGFX_SLANGC set, as for the app)
//   cd tools && GOOSE_GFX_HEADLESS=1 ../build/light_tune_ngfx --shot out.png [light_tune's flags]

import std;
import vec;
import math;
import os;
import gfx;
import ui;
import ngfx from "../build/ngfx/goose-ngfx";
import rules from "../src/rules";
import gui from "../src/gui";
import strings from "../strings";
import board from "../src/board";
import model3d from "../src/model3d";
import render3d from "../src/render3d";
import gpu_ngfx from "../src/ngfx";
import .light_tune;

var host = default<host_ngfx::Host>();

fn main() {
    var r3d = default<render3d_ngfx::Own>();
    tune(r3d);
}

// ngfx's window, frame and screen for tune(), as light_tune.goose's are gfx's.
fn open_window(o: render3d_ngfx::Own&, title: const u8[:], w: i64, h: i64, flags: i64) {
    host_ngfx::open(title, w, h, flags & ~gfx::NO_VSYNC, (flags & gfx::NO_VSYNC) != 0);
}
fn close_window(o: render3d_ngfx::Own&) { host_ngfx::close(host); }
fn next_frame(o: render3d_ngfx::Own&) -> bool { host_ngfx::frame(host) }
fn screen_of(o: render3d_ngfx::Own&) -> gfx::Texture { nx::screen() }
fn save_screen(o: render3d_ngfx::Own&, path: const u8[:]) -> bool { ngfx::screenshot(path) }
fn draw_panel(o: render3d_ngfx::Own&, c: ui::Context) {}
fn panel_input(o: render3d_ngfx::Own&, c: ui::Context) {
    ui::input_begin(c);
    ui::input_end(c);
}
fn read_back(o: render3d_ngfx::Own&, t: gfx::Texture) -> u8[>..] {
    var px: u8[>..] = [];
    guard nx::read_texture(t, px) else { abort("ngfx: could not read the texture back"); }
    return px;
}
