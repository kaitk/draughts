// The platform: all the main loop asks of it but drawing, through gfx's platform half
// and the program's own C for what gfx doesn't give. Opening the window, presenting, and
// the screenshot are the backend's (backend::open; host_gpu.goose on gfx).
namespace host;
import std;
import vec;
import gfx;

import gui from "../gui";
import .keys;

let DESKTOP = 0;
let ANDROID = 1;
let IOS = 2;

// Seconds nobody plays before the system's own timeout may dim and lock the screen. A
// child thinking over a move keeps it lit; a game left lying doesn't keep it lit for hours.
let SCREEN_IDLE = 900.0;

// DESKTOP, ANDROID, or IOS.
extern fn draughts_platform() -> i64;
// The system's preferred locales, "et-EE,en-US"; returns how many bytes.
extern fn draughts_locales(out: u8[:]) -> i64;
// The local date as days since the epoch.
extern fn draughts_local_day() -> i64;
// The local zone's offset from UTC now, in seconds.
extern fn draughts_utc_offset() -> i64;
// The app's storage folder, ending in a separator; returns how many bytes.
extern fn draughts_storage(out: u8[:]) -> i64;
// The safe area's insets in pixels (left, top, right, bottom) and the display's scale,
// into out[0..5]; 0, leaving out as it is, without a window.
extern fn draughts_display(out: f32[:]) -> i64;
// Asks SDL for Vulkan on Windows, before the window opens.
extern fn draughts_choose_gpu();
// Wakes the loop in ms milliseconds, where frame() waits for events.
extern fn draughts_wake_in(ms: i64);
// 1 lets the system's timeout dim and lock the screen; 0 keeps it on.
extern fn draughts_screen_sleeps(allow: i64);
// Tells Android the first frame is on screen, to lift the splash and the cover.
extern fn draughts_first_frame();
// Closes the app on Android and takes it out of recents; elsewhere the program's return does.
extern fn draughts_close();
// The system's back on Android, putting the app in the background.
extern fn draughts_leave();
// Gives the memory malloc keeps for freed blocks back to the system; Android only.
extern fn draughts_release_memory();
// Asks iOS for the ambient audio session before audio opens (sound.c).
extern fn draughts_sound_session();
// Android: times the 3D board's frames against the display; 1, once, when they first
// can't keep up, and if still slow asks for 60 Hz while it draws. `drawing` is 1 when
// this pass drew it.
extern fn draughts_pace_3d(drawing: i64, now: f64) -> i64;
// Settings' About (about.c): "version|commit|date" of the build, the system's name and
// version with the CPU's, and the GPU's name, each returning how many bytes; and the
// display's refresh rate in Hz, 0 where unknown.
extern fn draughts_about_build(out: u8[:]) -> i64;
extern fn draughts_about_system(out: u8[:]) -> i64;
extern fn draughts_about_gpu(out: u8[:]) -> i64;
extern fn draughts_about_refresh() -> f32;
// The system's battery saver: 1 on, 0 off, -1 where it can't be asked (about.c). And on
// Android, the display asked for 60 Hz while `on` is 1 (display.c).
extern fn draughts_battery_saver() -> i64;
extern fn draughts_cap_60(on: i64);

// Puts text on the system's clipboard (settings' About's Copy).
fn copy_text(text: const u8[:]) {
    if !gfx::set_clipboard(text) { print("clipboard: ", gfx::error()); }
}

struct Host {
    display:   f32[5]         = [0.0; 5],
    events:    gfx::Event[64] = [default<gfx::Event>(); 64],
    erase:     i64            = 0,
    enter:     i64            = 0,
    pad_enter: i64            = 0,
    text_on:   bool           = false,
    keyboard:  i64            = 0,
    repeat:    Repeat         = Repeat {}, // the arrow held (keys.goose)
    played:    f64            = 0.0,       // when someone last touched, typed, or the computer moved
    sleeps:    bool           = false,     // the screen is let sleep (keep_screen)
}

// Opens the window, filling the screen on a phone or a tablet or with `full`. Aborts if it can't.
fn open(title: const u8[:], width: i64, height: i64, full: bool, no_vsync: bool) -> Host {
    // The system reads a gamepad where it can, and wakes the idle app when it is used.
    let shown = if platform() != DESKTOP || full { gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE } else { gfx::WINDOW_RESIZABLE };
    let flags = shown | SYSTEM_GAMEPADS;
    draughts_choose_gpu();
    backend::open(title, width, height, flags, no_vsync);
    return Host { erase: gfx::scancode("Backspace"), enter: gfx::scancode("Return"), pad_enter: gfx::scancode("Keypad Enter"), .. };
}

fn close() { backend::with() { be => be.host.close() } }

// Presents what the frame's pass drew, or waits for an event when nothing did; false
// once the window is asked to close or the GPU device is lost.
fn frame() -> bool { backend::with() { be => be.host.frame() } }

// Whether the window wants a frame drawn though nothing changed (shown or resized).
fn exposed() -> bool { backend::with() { be => be.host.exposed() } }

// The frames presented so far: the first is on screen once the second frame() returns.
fn frame_count() -> i64 { gfx::frame_count() }

fn time() -> f64 { gfx::time() }

fn screen_size() -> int2 { gfx::screen_size() }

fn focused() -> bool { gfx::focused() }

fn platform() -> i64 { draughts_platform() }
fn sound_session() { draughts_sound_session(); }

fn read_display(h: Host&) { draughts_display(h.display); }

// The pointer and the keys' moves, or with the keyboard up what is typed. A quick tap can
// press and release within one frame, which mouse_down never sees; pressed and released do.
fn input(h: Host&, now: f64) -> gui::Input {
    var input = gui::Input { at: gfx::mouse_pos(), down: gfx::mouse_down(gfx::MOUSE_LEFT),
                             pressed: gfx::mouse_pressed(gfx::MOUSE_LEFT),
                             released: gfx::mouse_released(gfx::MOUSE_LEFT), wheel: gfx::mouse_wheel() };
    // While a name is typed the keys edit it, and a gamepad's buttons held then stay held after.
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

fn aa_key() -> bool { gfx::key_pressed("A") }

// The goose_gfx fork's borderless fullscreen, which the release's gfx.goose doesn't
// declare (gfx_fork.c stands in where the release's gfx is linked).
extern fn set_fullscreen(on: bool) -> bool = "gs_gfx_set_fullscreen";
extern fn fullscreen() -> bool = "gs_gfx_fullscreen";

// Alt and Enter, or F11, on a desktop.
fn alt_held() -> bool { gfx::key_down("Left Alt") || gfx::key_down("Right Alt") }
fn fullscreen_key() -> bool {
    guard platform() == DESKTOP else { return false; }
    return gfx::key_pressed("F11") || (alt_held() && (gfx::key_pressed("Return") || gfx::key_pressed("Keypad Enter")));
}

fn toggle_fullscreen() { set_fullscreen(!fullscreen()); }

// Android's back (DraughtsActivity hands it to SDL as "AC Back"), Escape, or a gamepad's B.
fn back(h: Host&) -> bool { gfx::key_pressed("AC Back") || gfx::key_pressed("Escape") || h.repeat.back }

fn keyboard(h: Host&, typing: bool, tap: i64) {
    guard typing != h.text_on || (typing && tap != h.keyboard) else { return; }
    gfx::text_input(false);
    if typing { gfx::text_input(true); }
    h.text_on = typing;
    h.keyboard = tap;
}

fn screenshot(path: const u8[:]) { backend::with() { be => be.host.screenshot(path) } }

fn storage(out: u8[:]) -> const u8[:] { out[..draughts_storage(out)] }
fn locales(out: u8[:]) -> const u8[:] { out[..draughts_locales(out)] }
fn local_day() -> i64 { draughts_local_day() }
fn utc_offset() -> i64 { draughts_utc_offset() }

fn wake_in(ms: i64) { draughts_wake_in(ms); }

// Whether this frame's input is someone at the app.
fn touched(i: gui::Input) -> bool {
    return i.down || i.pressed || i.released || i.wheel != 0.0 || i.typed.len > 0 || i.step != gui::STEP_NONE
        || i.confirm || i.held || i.tab != 0;
}

// Keeps the screen on while the app is played, and once nobody has for SCREEN_IDLE lets
// the system's timeout dim and lock it, until the next touch. The idle loop wakes at least
// once a second (rendering.md), which is all the check needs.
fn keep_screen(h: Host&, played: bool, now: f64) {
    if played { h.played = now; }
    let sleeps = now - h.played >= SCREEN_IDLE;
    guard sleeps != h.sleeps else { return; }
    draughts_screen_sleeps(if sleeps { 1 } else { 0 });
    h.sleeps = sleeps;
}
fn first_frame() { draughts_first_frame(); }
fn close_app() { draughts_close(); }
fn leave() { draughts_leave(); }
fn release_memory() { draughts_release_memory(); }
fn pace_3d(drawing: bool, now: f64) -> bool { draughts_pace_3d(if drawing { 1 } else { 0 }, now) != 0 }
