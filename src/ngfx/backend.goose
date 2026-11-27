// The seam between the app and its renderer in the build that holds both: open()
// chooses gfx or goose-ngfx once and opens its window, and with() runs its block on that
// renderer's backend, gpu::Gfx or gpu_ngfx::Ngfx. The drawers take the backend as a
// parameter, so they are compiled once for each: the choice is the one `if` in with().
//
// --renderer gfx or ngfx forces one; auto takes the platform's first choice (AUTO_NGFX).
// Where that is ngfx it asks first what needs no window (renderer.c), then opens gfx's
// window hidden for ngfx and closes it again if ngfx won't open there. A marker beside
// the settings, naming the GPU, its driver, and the app's version, stands while ngfx
// starts and goes at its first frame presented: a start that finds it takes gfx, until
// the GPU, the driver, or the app changes. The choice and why are printed.
namespace backend;
import std;
import vec;
import os;
import gfx;
import .app_ngfx;

// renderer.c's.
extern fn draughts_os() -> i64;
extern fn draughts_ngfx_check(out: u8[:]) -> i64;

// auto's first choice per system (renderer.c's draughts_os: macOS, Windows, Linux, iOS),
// the faster renderer on each.
let AUTO_NGFX: bool[4] = [true, true, false, true];
let OS_NAMES = ["macOS", "Windows", "Linux", "iOS"];
let MARKER = "renderer-start.txt";

// Whether ngfx draws, else gfx, set once by open(); the two backends, the chosen one's
// filled as it draws.
var ngfx_on = false;
var gfx_backend:  gpu::Gfx;
var ngfx_backend: gpu_ngfx::Ngfx;

// The block, given the chosen backend.
fn with<F>() { if ngfx_on { F(&ngfx_backend) } else { F(&gfx_backend) } }

// The renderer drawing, and its graphics API as it names it, for settings' About.
fn renderer_name() -> const u8[:] { if ngfx_on { "ngfx" } else { "gfx" } }
fn driver() -> u8[>..] { if ngfx_on { ngfx::driver() } else { gfx::driver() } }

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

fn set_path(marker_path: u8[..512]&) {
    var folder: u8[512] = [0; 512];
    let dir = host::storage(folder);
    marker_path.resize(0);
    // No storage folder, no marker: a path relative to wherever the app was started isn't one.
    if dir.len == 0 { return; }
    marker_path.append(dir);
    marker_path.append(MARKER);
}

fn open(title: const u8[:], width: i64, height: i64, flags: i64, no_vsync: bool) {
    let wanted = renderer_flag();
    let os = draughts_os();
    let h .= ngfx_backend.host;
    set_path(h.marker_path);
    let marker_path = h.marker_path;
    var why: u8[>..] = [];
    var on = false;
    if wanted == "gfx" {
        why = str("--renderer gfx");
    } else if wanted == "ngfx" {
        delete_file(marker_path);
        on = true;
        why = str("--renderer ngfx");
    } else if wanted != "auto" {
        why = str("--renderer ", wanted, " is none of auto, gfx, and ngfx: gfx");
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
            h.marker_set = marker_path.len > 0 && write_file_atomic(marker_path, found);
            // Hidden until ngfx draws into it, so a window that closes again is never seen.
            let opened = host_ngfx::try_open(title, width, height, flags | gfx::WINDOW_HIDDEN, no_vsync);
            if opened && !test_env("DRAUGHTS_RENDERER_TEST", "fail") {
                on = true;
                why = str("auto: ", found);
                h.show_pending = true;
            } else {
                // try_open closed what it opened when it failed.
                if opened { host_ngfx::close(h); }
                // The marker stays: the next start takes gfx without trying.
                h.marker_set = false;
                why = str("auto: ngfx didn't open on ", found, ": ", ngfx::error(), gfx::error());
            }
        }
    }
    ngfx_on = on;
    let name = if on { "ngfx" } else { "gfx" };
    print("renderer: ", name, " (", why, ")");
    if on && wanted != "auto" { host_ngfx::open(title, width, height, flags, no_vsync); }
    if !on { host_gpu::open(title, width, height, flags, no_vsync); }
    if on && test_env("DRAUGHTS_RENDERER_TEST", "crash") { abort("DRAUGHTS_RENDERER_TEST=crash: ended before ngfx's first frame"); }
}
