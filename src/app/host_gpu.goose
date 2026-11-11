// The window's GPU half for gfx (host.goose holds the rest): gfx opens the window with its
// own device, presents its pass at each frame, and shows its kept screen again by itself.
// The goose-ngfx build's src/ngfx/app/host_gpu.goose takes this file's place.
namespace host_gpu;
import std;
import vec;
import gfx;

// Opens gfx's window with `flags` (gfx's), presenting without waiting for the display
// with `no_vsync` (on Metal SDL_GPU's immediate mode, the layer's display sync off).
// Aborts if it can't.
fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    let all = if no_vsync { flags | gfx::NO_VSYNC } else { flags };
    guard gfx::open(title, width, height, all) else { abort(str("gfx: ", gfx::error())); }
}

fn close() { gfx::close(); }

// Ends the frame, presenting what its pass drew, and waits for an event when nothing
// did; false once the window is asked to close, or the GPU device is lost
// (patches/goose_gfx/0006).
fn frame() -> bool { gfx::frame() }

// Whether the window wants a frame drawn though nothing changed: never, as gfx presents
// its kept screen again itself.
fn exposed() -> bool { false }

// Saves the screen as last shown to `path`, a PNG.
fn screenshot(path: const u8[:]) { gfx::screenshot(path); }
