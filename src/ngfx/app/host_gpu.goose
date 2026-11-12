// The window's GPU half in the build that holds both renderers (scripts/ngfx.py lays this
// over src/app/host_gpu.goose): gfx's (host_gfx, gfx's window and device) or goose-ngfx's
// (host_ngfx, gfx's window WINDOW_ONLY and ngfx drawing into it), chosen once at open and
// kept in nx::ngfx_on (task 073).
//
// --renderer gfx or ngfx forces one, ngfx failing loudly where it can't run; auto, the
// default, takes the platform's first choice, measured (AUTO_NGFX). Where that is ngfx it
// asks first what needs no window (renderer.c: the OS and Metal, or Vulkan's loader and
// the GPU's extensions), then opens gfx's window hidden for ngfx and closes it again if
// ngfx won't open there, and gfx starts as it does alone. A marker beside the settings,
// naming the GPU, its driver, and the app's version, stands while ngfx starts and goes at
// its first frame presented: a start that finds it, from a start that never got that far,
// takes gfx, until the GPU, the driver, or the app changes. The choice and why are printed.
namespace host_gpu;
import std;
import vec;
import os;
import gfx;

// photo.c's renderer (photo_gpu.h), and renderer.c's.
extern fn photo_ngfx(on: bool) = "draughts_photo_ngfx";
extern fn draughts_os() -> i64;
extern fn draughts_ngfx_check(out: u8[:]) -> i64;
extern fn draughts_show_window();

// auto's first choice per system (renderer.c's draughts_os: macOS, Windows, Linux, iOS),
// from what was measured: Windows ngfx, 26 to 41% less GPU time a frame on the RTX 4090
// (task 074); the Mac and iOS gfx, ngfx's MSAA frame 2% over gfx's on the M1 Pro (task
// 077); Linux gfx, RADV running ngfx 13% slower (task 076), until MSAA is measured there.
let AUTO_NGFX: bool[4] = [false, true, false, false];
let OS_NAMES = ["macOS", "Windows", "Linux", "iOS"];
let MARKER = "renderer-start.txt";

// The marker's path, and whether to clear it at ngfx's first frame.
var marker_path: u8[..512] = [];
var marker_set = false;

// --renderer's value, "auto" without it.
fn renderer_flag() -> const u8[:] {
    let a = args();
    for i in 1..a.len - 1 { if a[i] == "--renderer" { return a[i + 1]; } }
    return "auto";
}

// A test of the fallback, never set in use (agents/testing.md): DRAUGHTS_RENDERER_TEST
// "fail" makes ngfx's open fail after the window opened, "crash" ends the program after
// ngfx opened, before its first frame; DRAUGHTS_AUTO_NGFX=1 makes auto try ngfx here.
fn test_env(name: const u8[:], value: const u8[:]) -> bool {
    var v: u8[>..] = [];
    return env(name, v) && v == value;
}

fn set_path() {
    var folder: u8[512] = [0; 512];
    marker_path.resize(0);
    marker_path.append(host::storage(folder));
    marker_path.append(MARKER);
}

fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    let wanted = renderer_flag();
    let os = draughts_os();
    set_path();
    var why: u8[>..] = [];
    var ngfx_on = false;
    if wanted == "gfx" {
        why = str("--renderer gfx");
    } else if wanted == "ngfx" {
        delete_file(marker_path);
        ngfx_on = true;
        why = str("--renderer ngfx");
    } else if !AUTO_NGFX[os] && !test_env("DRAUGHTS_AUTO_NGFX", "1") {
        why = str("auto: gfx first on ", OS_NAMES[os]);
    } else {
        var text: u8[512] = [0; 512];
        let n = draughts_ngfx_check(text);
        let found = text[..abs(n)];
        var last: u8[>..] = [];
        if n < 0 {
            why = str("auto: ", found);
        } else if file_exists(marker_path) && read_file(marker_path, last) && last == found {
            why = str("auto: ngfx didn't reach its first frame at the last start on ", found);
        } else {
            write_file_atomic(marker_path, found);
            marker_set = true;
            // Hidden until ngfx draws into it, so a window that closes again is never seen.
            let opened = host_ngfx::try_open(title, width, height, flags | gfx::WINDOW_HIDDEN, no_vsync);
            if opened && !test_env("DRAUGHTS_RENDERER_TEST", "fail") {
                ngfx_on = true;
                why = str("auto: ", found);
                draughts_show_window();
            } else {
                // try_open closed what it opened when it failed.
                if opened { host_ngfx::close(); }
                // The marker stays: the next start takes gfx without trying.
                marker_set = false;
                why = str("auto: ngfx didn't open on ", found, ": ", ngfx::error(), gfx::error());
            }
        }
    }
    nx::ngfx_on = ngfx_on;
    photo_ngfx(ngfx_on);
    let name = if ngfx_on { "ngfx" } else { "gfx" };
    print("renderer: ", name, " (", why, ")");
    if ngfx_on && wanted != "auto" { host_ngfx::open(title, width, height, flags, no_vsync); }
    if !ngfx_on { host_gfx::open(title, width, height, flags, no_vsync); }
    if ngfx_on && test_env("DRAUGHTS_RENDERER_TEST", "crash") { abort("DRAUGHTS_RENDERER_TEST=crash: ended before ngfx's first frame"); }
}

fn close() { if nx::ngfx_on { host_ngfx::close(); } else { host_gfx::close(); } }

// The frame, and ngfx's marker cleared once its first frame was presented: its device
// made, a frame drawn, submitted, and handed to the display.
fn frame() -> bool {
    if !nx::ngfx_on { return host_gfx::frame(); }
    let running = host_ngfx::frame();
    if marker_set {
        delete_file(marker_path);
        marker_set = false;
    }
    running
}

fn exposed() -> bool { return if nx::ngfx_on { host_ngfx::exposed() } else { host_gfx::exposed() }; }
fn screenshot(path: const u8[:]) { if nx::ngfx_on { host_ngfx::screenshot(path); } else { host_gfx::screenshot(path); } }
