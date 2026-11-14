// The platform the app runs on, all the main loop asks of it but drawing
// (docs/architecture/README.md, "A frame"): the window, the frame's end and its clock,
// the screen's size and focus, the pointer, the keys and typed text, and the screenshot,
// through gfx's platform half; and the program's own C for what gfx doesn't give: the
// safe area and the display's scale, the wake timer, the storage folder, the locales,
// Android's launch cover, back, and close, the memory malloc keeps, and the display's
// rate under the 3D board. Drawing is render.goose's; opening the window, presenting, and
// the screenshot are the renderer's (host_gpu.goose).
namespace host;
import std;
import vec;
import gfx;

import gui from "../gui";
import .keys;

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
// Times the 3D board's frames against the display: 1, once, when they first can't keep up
// (the pass then draws fewer samples); found so again, asks Android's display for 60 Hz
// while the 3D board draws. drawing is 1 when this pass drew it (display.c). Nothing
// elsewhere.
extern fn draughts_pace_3d(drawing: i64, now: f64) -> i64;

// What the host keeps between frames: the safe area and scale as last read, the events
// read for typed text, and whether the keyboard is up, for which tap on the name.
struct Host {
    display:   f32[5]         = [0.0; 5],
    events:    gfx::Event[64] = [default<gfx::Event>(); 64],
    erase:     i64            = 0,
    enter:     i64            = 0,
    pad_enter: i64            = 0,
    text_on:   bool           = false,
    keyboard:  i64            = 0,
    repeat:    Repeat         = Repeat {}, // the arrow held (keys.goose)
}

// Opens the window, `title` and width × height where the platform has windows; filling
// the screen with the system's bars hidden on a phone or a tablet, or with `full`;
// presenting without waiting for the display with `no_vsync`. Aborts if it can't.
fn open(title: const u8[:], width: i64, height: i64, full: bool, no_vsync: bool) -> Host {
    // The system reads a gamepad where it can, and wakes the idle app when it is used.
    let shown = if platform() != DESKTOP || full { gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE } else { gfx::WINDOW_RESIZABLE };
    let flags = shown | SYSTEM_GAMEPADS;
    draughts_choose_gpu();
    host_gpu::open(title, width, height, flags, no_vsync);
    return Host { erase: gfx::scancode("Backspace"), enter: gfx::scancode("Return"), pad_enter: gfx::scancode("Keypad Enter"), .. };
}

fn close() { host_gpu::close(); }

// Ends the frame, presenting what its pass drew, and waits for an event when nothing
// did; false once the window is asked to close, or the GPU device is lost, and the loop
// ends.
fn frame() -> bool { host_gpu::frame() }

// Whether the window wants a frame drawn though nothing changed (exposed, shown or
// resized).
fn exposed() -> bool { host_gpu::exposed() }

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

// The pointer this frame and, but while the keyboard is up, the keys' moves; with it up
// the characters typed, Backspace, and Return. A quick tap can press and release within one frame, which mouse_down never
// sees; pressed and released catch it.
fn input(h: Host&, now: f64) -> gui::Input {
    var input = gui::Input { at: gfx::mouse_pos(), down: gfx::mouse_down(gfx::MOUSE_LEFT),
                             pressed: gfx::mouse_pressed(gfx::MOUSE_LEFT),
                             released: gfx::mouse_released(gfx::MOUSE_LEFT), wheel: gfx::mouse_wheel() };
    // The arrow keys and a gamepad move the UI's focus, repeating while held, and Enter,
    // Space, or the gamepad's A presses it (gui::focus_keys, keys.goose), not while a name
    // is typed, where the keys edit it; a gamepad's buttons held then stay held after.
    guard h.text_on else {
        keys(h.repeat, input, now);
        return input;
    }
    h.repeat = Repeat { stick: h.repeat.stick, .. };
    h.repeat.buttons = pad_bits(h.repeat);
    let n = min(gfx::events_into(h.events), h.events.len);
    for e in h.events[..n] {
        guard input.typed.len < gui::MAX_TYPED else { break; }
        if e.kind == gfx::EVENT_TEXT { input.typed.push(e.codepoint); }
        if e.kind == gfx::EVENT_KEY && e.down && e.scancode == h.erase { input.typed.push(gui::ERASE); }
        if e.kind == gfx::EVENT_KEY && e.down && (e.scancode == h.enter || e.scancode == h.pad_enter) { input.typed.push(gui::ENTER); }
    }
    return input;
}

// The A key, which switches the 3D board's antialiasing (task 071's comparison).
fn aa_key() -> bool { gfx::key_pressed("A") }

// The fork's borderless fullscreen at the desktop's resolution (kaitk/goose_gfx's
// gfx.goose; the release's doesn't declare it, so it is declared here as keys.goose's
// gamepad is, and gfx_fork.c stands in where the release's gfx is linked).
extern fn set_fullscreen(on: bool) -> bool = "gs_gfx_set_fullscreen";
extern fn fullscreen() -> bool = "gs_gfx_fullscreen";

// Alt and Enter, or F11, went down this frame: a desktop's way in and out of fullscreen.
fn alt_held() -> bool { gfx::key_down("Left Alt") || gfx::key_down("Right Alt") }
fn fullscreen_key() -> bool {
    guard platform() == DESKTOP else { return false; }
    return gfx::key_pressed("F11") || (alt_held() && (gfx::key_pressed("Return") || gfx::key_pressed("Keypad Enter")));
}

// Fullscreen if windowed, else back to the window.
fn toggle_fullscreen() { set_fullscreen(!fullscreen()); }

// Whether Android's back (SDL's "AC Back"; DraughtsActivity hands the system's back to
// SDL as that key), Escape, or a gamepad's B (keys.goose) went down this frame.
fn back(h: Host&) -> bool { gfx::key_pressed("AC Back") || gfx::key_pressed("Escape") || h.repeat.back }

// The keyboard up while `typing`, brought up again by each new `tap` on the name.
fn keyboard(h: Host&, typing: bool, tap: i64) {
    guard typing != h.text_on || (typing && tap != h.keyboard) else { return; }
    gfx::text_input(false);
    if typing { gfx::text_input(true); }
    h.text_on = typing;
    h.keyboard = tap;
}

// Saves the screen as last shown to `path`, a PNG.
fn screenshot(path: const u8[:]) { host_gpu::screenshot(path); }

// The app's storage folder into `out`, and the system's locales; each returns its bytes.
fn storage(out: u8[:]) -> const u8[:] { out[..draughts_storage(out)] }
fn locales(out: u8[:]) -> const u8[:] { out[..draughts_locales(out)] }

fn wake_in(ms: i64) { draughts_wake_in(ms); }
fn first_frame() { draughts_first_frame(); }
fn close_app() { draughts_close(); }
fn leave() { draughts_leave(); }
fn release_memory() { draughts_release_memory(); }
fn pace_3d(drawing: bool, now: f64) -> bool { draughts_pace_3d(if drawing { 1 } else { 0 }, now) != 0 }
