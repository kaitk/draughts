// The window's GPU half for goose-ngfx, beside gfx's src/gfx/host_gpu.goose in the build
// that holds both (draughts_ngfx.goose): gfx opens the window WINDOW_ONLY, with gfx's
// input, events, and wait and no device, and ngfx draws into it.
namespace host_ngfx;
import std;
import vec;
import os;
import gfx;
import ngfx;

// What the goose_gfx fork adds, which the release's gfx.goose doesn't declare: open's
// flag for a window with no device, the window's native handle for ngfx (on Linux a Wayland surface or an X11 window, its display, and which of the two),
// whether ngfx showed this frame, and whether the window wants one shown.
let WINDOW_ONLY = 64;
extern fn native_window() -> u64 = "gs_gfx_native_window";
extern fn native_display() -> u64 = "gs_gfx_native_display";
extern fn native_kind() -> i64 = "gs_gfx_native_kind";
extern fn presented(shown: bool) = "gs_gfx_presented";
extern fn needs_present() -> bool = "gs_gfx_needs_present";
extern fn draughts_show_window();

// What the start (backend::open) leaves for the first frames: the crash marker's path,
// whether to clear it at ngfx's first frame presented, whether the window, opened hidden,
// waits to be shown, and how many of ngfx's frames have ended.
struct Host {
    marker_path:  u8[..512],
    marker_set:   bool,
    show_pending: bool,
    frames:       i64,
}

// Opens gfx's window with `flags` (gfx's) and no device, and ngfx in it, presenting
// without waiting for the display with `no_vsync` (ngfx's NO_VSYNC, the Metal layer's
// display sync off; gfx's flag would mean nothing to a window with no device). False, with
// everything it opened closed, if either fails: the reason is gfx::error() or ngfx::error().
fn try_open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) -> bool {
    guard gfx::open(title, width, height, flags | WINDOW_ONLY) else { return false; }
    let size = gfx::screen_size();
    let sync = if no_vsync { ngfx::NO_VSYNC } else { 0 };
    if ngfx::open(native_window(), size.x, size.y, sync, native_display(), native_kind()) { return true; }
    gfx::close();
    return false;
}

// The same, aborting if it can't (--renderer ngfx).
fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    guard try_open(title, width, height, flags, no_vsync) else { abort(str("ngfx: ", ngfx::error(), gfx::error())); }
}

fn close(h: Host&) {
    ngfx::close();
    gfx::close();
}

// Presents what the frame drew, then ends gfx's frame, which waits for an event when
// nothing did; false once the window is asked to close. The screen then follows the
// window's size. The loop draws after each, so the first frame ngfx drew is presented by
// the second: then the hidden window is shown, and the marker cleared (its device made, a
// frame drawn, submitted, and handed to the display).
fn frame(h: Host&) -> bool {
    presented(ngfx::present());
    let running = gfx::frame();
    ngfx::resize(gfx::screen_size());
    h.frames += 1;
    if h.frames >= 2 && h.show_pending {
        draughts_show_window();
        h.show_pending = false;
    }
    if h.frames >= 2 && h.marker_set {
        delete_file(h.marker_path);
        h.marker_set = false;
    }
    running
}

// Whether the window wants a frame drawn though nothing changed (exposed, shown or
// resized): ngfx draws straight into the window's image and keeps no copy to show again.
fn exposed(h: Host&) -> bool { needs_present() }

// Saves the screen as last shown to `path`, a PNG; headless only, as a window's screen
// is the window's image, which ngfx can't read.
fn screenshot(h: Host&, path: const u8[:]) { ngfx::screenshot(path); }
