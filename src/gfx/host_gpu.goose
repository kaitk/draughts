// The window's GPU half for gfx (host.goose holds the rest): gfx opens the window with its
// own device, presents its pass at each frame, and shows its kept screen again by itself.
namespace host_gpu;
import std;
import vec;
import gfx;

struct Host {}

// Aborts if it can't.
fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    let all = if no_vsync { flags | gfx::NO_VSYNC } else { flags };
    guard gfx::open(title, width, height, all) else { abort(str("gfx: ", gfx::error())); }
}

fn close(h: Host&) { gfx::close(); }

// Presents what the frame's pass drew, or waits for an event when nothing did; false once
// the window is asked to close or the GPU device is lost.
fn frame(h: Host&) -> bool { gfx::frame() }

// Never: gfx presents its kept screen again itself.
fn exposed(h: Host&) -> bool { false }

fn screenshot(h: Host&, path: const u8[:]) { gfx::screenshot(path); }
