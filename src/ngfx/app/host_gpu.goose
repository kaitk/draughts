// The window's GPU half in the build that holds both renderers (scripts/ngfx.py lays this
// over src/app/host_gpu.goose): gfx's (host_gfx, gfx's window and device) or goose-ngfx's
// (host_ngfx, gfx's window WINDOW_ONLY and ngfx drawing into it), chosen once at open by
// --renderer gfx|ngfx, ngfx without it, and kept in nx::ngfx_on.
namespace host_gpu;
import std;
import vec;

// photo.c's renderer (photo_gpu.h).
extern fn photo_ngfx(on: bool) = "draughts_photo_ngfx";

// --renderer's value, or "" without it.
fn renderer_flag() -> const u8[:] {
    let a = args();
    for i in 1..a.len - 1 { if a[i] == "--renderer" { return a[i + 1]; } }
    return "";
}

fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    nx::ngfx_on = renderer_flag() != "gfx";
    photo_ngfx(nx::ngfx_on);
    if nx::ngfx_on { host_ngfx::open(title, width, height, flags, no_vsync); } else { host_gfx::open(title, width, height, flags, no_vsync); }
}

fn close() { if nx::ngfx_on { host_ngfx::close(); } else { host_gfx::close(); } }
fn frame() -> bool { return if nx::ngfx_on { host_ngfx::frame() } else { host_gfx::frame() }; }
fn exposed() -> bool { return if nx::ngfx_on { host_ngfx::exposed() } else { host_gfx::exposed() }; }
fn screenshot(path: const u8[:]) { if nx::ngfx_on { host_ngfx::screenshot(path); } else { host_gfx::screenshot(path); } }
