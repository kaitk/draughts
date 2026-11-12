// The window's GPU half for goose-ngfx, in place of src/app/host_gpu.goose
// (scripts/ngfx.py): gfx opens the window WINDOW_ONLY (patches/goose_gfx/0008), with gfx's
// input, events, and wait and no device, and ngfx draws into it.
namespace host_gpu;
import std;
import vec;
import gfx;
import ngfx;

// What patches/goose_gfx/0008 adds to gfx, which the release's gfx.goose doesn't
// declare: open's flag for a window with no device, the window's native handle for ngfx
// (on Linux a Wayland surface or an X11 window, its display, and which of the two),
// whether ngfx showed this frame, and whether the window wants one shown.
let WINDOW_ONLY = 64;
extern fn native_window() -> u64 = "gs_gfx_native_window";
extern fn native_display() -> u64 = "gs_gfx_native_display";
extern fn native_kind() -> i64 = "gs_gfx_native_kind";
extern fn presented(shown: bool) = "gs_gfx_presented";
extern fn needs_present() -> bool = "gs_gfx_needs_present";

// Opens gfx's window with `flags` (gfx's) and no device, and ngfx in it, presenting
// without waiting for the display with `no_vsync` (ngfx's NO_VSYNC, the Metal layer's
// display sync off; gfx's flag would mean nothing to a window with no device). Aborts if
// it can't.
fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    guard gfx::open(title, width, height, flags | WINDOW_ONLY) else { abort(str("gfx: ", gfx::error())); }
    let size = gfx::screen_size();
    let sync = if no_vsync { ngfx::NO_VSYNC } else { 0 };
    let display = native_display();    // Linux's, 0 elsewhere
    let ok = if display != 0 { ngfx::open_linux(display, native_window(), native_kind(), size.x, size.y, sync) }
             else { ngfx::open(native_window(), size.x, size.y, sync) };
    guard ok else { abort(str("ngfx: ", ngfx::error())); }
}

fn close() {
    ngfx::close();
    gfx::close();
}

// Presents what the frame drew, then ends gfx's frame, which waits for an event when
// nothing did; false once the window is asked to close. The screen then follows the
// window's size.
fn frame() -> bool {
    presented(ngfx::present());
    let running = gfx::frame();
    ngfx::resize(gfx::screen_size());
    running
}

// Whether the window wants a frame drawn though nothing changed (exposed, shown or
// resized): ngfx draws straight into the window's image and keeps no copy to show again.
fn exposed() -> bool { needs_present() }

// Saves the screen as last shown to `path`, a PNG; headless only, as a window's screen
// is the window's image, which ngfx can't read.
fn screenshot(path: const u8[:]) { ngfx::screenshot(path); }
