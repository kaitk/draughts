// The platform the app runs on, all the main loop asks of it but drawing
// (docs/architecture/README.md, "A frame"): the window, the frame's end and its clock,
// the screen's size and focus, the pointer, the keys and typed text, and the screenshot,
// through gfx's platform half; and the program's own C for what gfx doesn't give: the
// safe area and the display's scale, the wake timer, the storage folder, the locales,
// Android's launch cover, back, and close, the memory malloc keeps, and the display's
// rate under the 3D board. Drawing is render.goose's. A second renderer that brings its
// own window replaces the gfx calls here and leaves the rest.
namespace host;
import std;
import vec;
import gfx;

import gui from "../gui";

let DESKTOP = 0;
let ANDROID = 1;
let IOS = 2;

// Which platform the program runs on: DESKTOP, ANDROID, or IOS (launch.c).
extern fn draughts_platform() -> i64;
// The system's preferred locales, "et-EE,en-US" (locale.c); returns how many bytes.
extern fn draughts_locales(out: u8[:]) -> i64;
// The app's storage folder, ending in a separator (storage.c); returns how many bytes.
extern fn draughts_storage(out: u8[:]) -> i64;
// The insets around the window's safe area in pixels (left, top, right, bottom) and the
// display's scale, into out[0..5] (display.c); 0, leaving out as it is, without a window.
extern fn draughts_display(out: f32[:]) -> i64;
// Asks SDL for Vulkan on Windows, before the window opens (display.c).
extern fn draughts_choose_gpu();
// Wakes the loop in ms milliseconds, where frame() waits for events (wake.c).
extern fn draughts_wake_in(ms: i64);
// Tells Android the first frame is on screen, to lift the splash and the cover (launch.c).
extern fn draughts_first_frame();
// Closes the app on Android and takes it out of recents, as home's way out asks; on the
// Mac the window closes as the program returns (launch.c).
extern fn draughts_close();
// Android's back where the app has no way back (home's menu): the system's back, which
// puts the app in the background; nothing on the Mac (launch.c).
extern fn draughts_leave();
// Gives back to the system the memory malloc keeps for freed blocks; Android only
// (memory.c).
extern fn draughts_release_memory();
// Asks Android's display for 60 Hz while the 3D board draws, if its frames can't keep up
// with a faster display; drawing is 1 when this pass drew it (display.c). Nothing elsewhere.
extern fn draughts_pace_3d(drawing: i64, now: f64);

// What the host keeps between frames: the safe area and scale as last read, the events
// read for typed text, and whether the keyboard is up, for which tap on the name.
struct Host {
    display:  f32[5]         = [0.0; 5],
    events:   gfx::Event[64] = [default<gfx::Event>(); 64],
    erase:    i64            = 0,
    enter:    i64            = 0,
    text_on:  bool           = false,
    keyboard: i64            = 0,
}

// Opens the window, `title` and width × height where the platform has windows; filling
// the screen with the system's bars hidden on a phone or a tablet, or with `full`.
// Aborts if it can't.
fn open(title: const u8[:], width: i64, height: i64, full: bool) -> Host {
    let flags = if platform() != DESKTOP || full { gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE } else { gfx::WINDOW_RESIZABLE };
    draughts_choose_gpu();
    guard gfx::open(title, width, height, flags) else { abort(str("gfx: ", gfx::error())); }
    return Host { erase: gfx::scancode("Backspace"), enter: gfx::scancode("Return"), .. };
}

fn close() { gfx::close(); }

// Ends the frame, presenting what its pass drew, and waits for an event when nothing
// did; false once the window is asked to close, or the GPU device is lost
// (patches/goose_gfx/0006), and the loop ends.
fn frame() -> bool { gfx::frame() }

// The frames presented so far: the first is on screen once the second frame() returns.
fn frame_count() -> i64 { gfx::frame_count() }

// Seconds since the window opened.
fn time() -> f64 { gfx::time() }

// The screen's size in pixels.
fn screen_size() -> int2 { gfx::screen_size() }

// Whether the window had the keyboard's focus at the last frame().
fn focused() -> bool { gfx::focused() }

fn platform() -> i64 { draughts_platform() }

// The safe area's insets in pixels and the display's scale, read into h.display: a few
// fields in SDL, read each frame, since turning the screen moves them.
fn read_display(h: Host&) { draughts_display(h.display); }

// The pointer this frame, and with the keyboard up the characters typed, Backspace, and
// Return. A quick tap can press and release within one frame, which mouse_down never
// sees; pressed and released catch it.
fn input(h: Host&) -> gui::Input {
    var input = gui::Input { at: gfx::mouse_pos(), down: gfx::mouse_down(gfx::MOUSE_LEFT),
                             pressed: gfx::mouse_pressed(gfx::MOUSE_LEFT),
                             released: gfx::mouse_released(gfx::MOUSE_LEFT), wheel: gfx::mouse_wheel() };
    guard h.text_on else { return input; }
    let n = min(gfx::events_into(h.events), h.events.len);
    for e in h.events[..n] {
        guard input.typed.len < gui::MAX_TYPED else { break; }
        if e.kind == gfx::EVENT_TEXT { input.typed.push(e.codepoint); }
        if e.kind == gfx::EVENT_KEY && e.down && e.scancode == h.erase { input.typed.push(gui::ERASE); }
        if e.kind == gfx::EVENT_KEY && e.down && e.scancode == h.enter { input.typed.push(gui::ENTER); }
    }
    return input;
}

// Whether Android's back (SDL's "AC Back"; DraughtsActivity hands the system's back to
// SDL as that key) or Escape went down this frame.
// The A key, which switches the 3D board's antialiasing (task 071's comparison).
fn aa_key() -> bool { gfx::key_pressed("A") }

fn back() -> bool { gfx::key_pressed("AC Back") || gfx::key_pressed("Escape") }

// The keyboard up while `typing`, brought up again by each new `tap` on the name.
fn keyboard(h: Host&, typing: bool, tap: i64) {
    guard typing != h.text_on || (typing && tap != h.keyboard) else { return; }
    gfx::text_input(false);
    if typing { gfx::text_input(true); }
    h.text_on = typing;
    h.keyboard = tap;
}

// Saves the screen as last shown to `path`, a PNG.
fn screenshot(path: const u8[:]) { gfx::screenshot(path); }

// The app's storage folder into `out`, and the system's locales; each returns its bytes.
fn storage(out: u8[:]) -> const u8[:] { out[..draughts_storage(out)] }
fn locales(out: u8[:]) -> const u8[:] { out[..draughts_locales(out)] }

fn wake_in(ms: i64) { draughts_wake_in(ms); }
fn first_frame() { draughts_first_frame(); }
fn close_app() { draughts_close(); }
fn leave() { draughts_leave(); }
fn release_memory() { draughts_release_memory(); }
fn pace_3d(drawing: bool, now: f64) { draughts_pace_3d(if drawing { 1 } else { 0 }, now); }
