// Draughts: home and the game screen, played by two on one screen or against the
// computer, which thinks on a worker thread (think.goose). It draws only when something
// changed: input, a move or a pulse animating, or a new screen size
// (docs/architecture/rendering.md, "Frames and battery"). The thread needs a build: on
// the Mac, from src/app/, `goose build -o ../../build/draughts draughts.goose`, then
//
//   ../../build/draughts                          at home
//   ../../build/draughts --screen game            the game screen; --fen and --tap open it too
//   ../../build/draughts --fen W:Wc3,Kh6:Be5 --tap c3 --frames 30   taps, then saves draughts.png
//   scripts/android.py src/app/draughts.goose --run   on a device over USB (docs/development.md)
//   scripts/ios.py src/app/draughts.goose --run   in the iOS simulator
//
// Every flag is a field of flags::Flags.

import std;
import vec;
import gfx;
import os;
import rules from "../rules";
import board from "../board";
import strings from "../../strings";
import gui from "../gui";
import .theme;
import .draw;
import .scene;
import .widgets;
import game from "../game";
import shell from "../shell";
import ai from "../ai";
import puzzles from "../puzzles";
import badges from "../badges";
import render3d from "../render3d";
import .text;
import .think;
import .draw3d;
import .flags;
import .dev;

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
// Which platform the program runs on: DESKTOP, ANDROID, or IOS (launch.c).
extern fn draughts_platform() -> i64;
// Seconds between looks for the hint's answer while it is on its way (think::frame).
let HINT_POLL = 0.02;

let DESKTOP = 0;
let ANDROID = 1;
let IOS = 2;

// The theme a season setting picks: its own, or by the date.
fn theme_for(season: i64) -> i64 {
    return if season >= 0 { season } else { theme::for_month(theme::month(time())) };
}

fn main() {
    // The development flags (flags.goose), and the layout's that set gui's values.
    let f = flags::parse(args());
    if f.dp > 0 { gui::short_dp = f.dp; }
    if f.density_floor >= 0.0 { gui::density_floor = f.density_floor; }
    if f.display_scale >= 0.0 { gui::display_scale = f.display_scale; }
    // --dp says how many dp the shorter side has, so the floor stays off unless asked.
    if f.dp > 0 && f.density_floor < 0.0 { gui::density_floor = 0.0; }
    var kind = f.theme;
    var lang = f.lang;
    // The game as it was when the app was last paused (shell::restore; nothing changes
    // for a missing or damaged file). A run with flags that set up a game or take a
    // screenshot neither reads nor writes it.
    let keep = f.screen < 0 && f.puzzle < 0 && f.go < 0 && f.win < 0.0 && f.fen.len == 0 && f.taps.len == 0 && f.frames < 0 && f.variant < 0 && f.clock < 0 && f.computer < 0;
    // The players, their settings, and their games, kept in the app's storage folder
    // (shell/players.goose): the playing player's settings with the device's language.
    var folder: u8[512] = [0; 512];
    let dir = folder[..draughts_storage(folder)];
    var players_read = players::Players {};
    let prefs = players::load(players_read, dir, keep);
    if kind < 0 { kind = theme_for(prefs.season); }
    var locales: u8[256] = [0; 256];
    let system_lang = strings::pick(locales[..draughts_locales(locales)]);
    if lang < 0 { lang = if prefs.language >= 0 { prefs.language } else { system_lang }; }
    strings::use(lang);
    puzzles::load((if f.variant >= 0 { f.variant } else { prefs.variant }) as u8);

    // A phone or a tablet: the window fills the screen with the system's bars hidden, the
    // clocks count only while the app has focus, and the layout takes the display's scale.
    let platform = draughts_platform();
    let on_android = platform == ANDROID;
    let on_ios = platform == IOS;
    let mobile = platform != DESKTOP;
    // An iOS app never closes itself, so home has no way out there.
    if on_ios { home::closable = false; }
    let window_flags = if mobile || f.full { gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE } else { gfx::WINDOW_RESIZABLE };
    draughts_choose_gpu();
    guard gfx::open(strings::get(strings::APP_NAME), f.width, f.height, window_flags) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    // A new game of the draughts the setup last chose, until a saved game is restored;
    // the flags' setup (dev.goose), then the playing player's game, with the screen it
    // was on, and a fresh install's first run on the sheet of its one player.
    var sh = shell::new((if f.variant >= 0 { f.variant } else { prefs.variant }) as u8);
    shell::launch(sh, prefs, players_read);
    dev::setup(f, sh, prefs);
    shell::open(sh, keep);
    var d = draw::new(kind, !settings::photo_shown(sh.prefs));
    var d3 = draw3d::Drawer { wood: f.wood, marble: f.marble, summer: f.summer, spring: f.spring, timed: f.bench > 0, .. };
    var dv = dev::new(f);
    var w = widgets::new();
    var g = gui::Gui {};
    var t = text::Text {};
    var size = int2 { 0, 0 };
    var display:   f32[5] = [0.0; 5];
    var was_scale: f32    = 0.0;
    var dirty = true;
    var focused = true;
    var season_in = 0;
    var wake_at = -1.0;
    var released = false;
    var thinker = think::Thinker {};
    // A player's name, typed: the keyboard is up while the shell asks (shell::who), and its
    // characters, Backspace, and Return go to the UI with the pointer.
    var events: gfx::Event[64] = [default<gfx::Event>(); 64];
    let erase_key = gfx::scancode("Backspace");
    let enter_key = gfx::scancode("Return");
    var text_on = false;
    var keyboard = 0;
    while gfx::frame() {
        // frame() presents what the pass before it drew, and the first pass draws.
        if gfx::frame_count() == 2 { draughts_first_frame(); }
        // Android may kill the app once it is paused; it loses focus then, and SDL lets
        // the loop run once more before blocking, so the game is written here: one small
        // write per pause, none while idle.
        if focused && !gfx::focused() { shell::write_game(sh); }
        // The clocks count only time the game was on screen: not the gap while Android had
        // the app paused, nor while it was in the background. On the Mac a window started
        // from a terminal never has focus, and the loop never blocks there, so focus is
        // left out and the clock runs while the window shows.
        if mobile && (!focused || !gfx::focused()) { shell::pause(sh); }
        focused = gfx::focused();
        // A new season's photograph, colors, and blurred copies load two frames after the
        // tap: the frame after it shows the tile lit, and is on screen before the load
        // (80 to 95 ms on the tablet) holds the thread.
        if season_in > 0 {
            season_in--;
            if season_in == 0 && (theme_for(sh.prefs.season) != d.kind || !settings::photo_shown(sh.prefs) != d.scene.plain) {
                draw::reload(d, theme_for(sh.prefs.season), !settings::photo_shown(sh.prefs));
                dirty = true;
            }
        }
        let now = gfx::time();
        let s = gfx::screen_size();
        if s.x != size.x || s.y != size.y {
            size = s;
            dirty = true;
        }
        // The safe area and the display's scale, read each frame (a few fields in SDL):
        // turning the screen moves the camera's cutout and the gesture bar, and a change
        // of either is a change of the screen, as a new size is. The Mac's display scale
        // is left out (gui::scale_of).
        draughts_display(display);
        if mobile && f.display_scale < 0.0 { gui::display_scale = display[4]; }
        let scale = gui::scale_of(size.x, size.y);
        let e = if f.inset.x < 0.0 { float4 { display[0], display[1], display[2], display[3] } }
                else { float4 { floor(f.inset.x * scale + 0.5), floor(f.inset.y * scale + 0.5),
                                floor(f.inset.z * scale + 0.5), floor(f.inset.w * scale + 0.5) } };
        if scale != was_scale || e.x != g.insets.x || e.y != g.insets.y || e.z != g.insets.z || e.w != g.insets.w {
            was_scale = scale;
            g.insets = e;
            dirty = true;
        }
        if text::bake(t, g, scale) {
            trim_memory();
            w.stale = true;
        }
        w.atlas = t.texture;
        // A quick tap can press and release within one frame, which mouse_down never
        // sees; pressed and released catch it. The screens give the pointer to the UI
        // first; a press that lands on it never reaches the board.
        var input = gui::Input { at: gfx::mouse_pos(), down: gfx::mouse_down(gfx::MOUSE_LEFT),
                                 pressed: gfx::mouse_pressed(gfx::MOUSE_LEFT),
                                 released: gfx::mouse_released(gfx::MOUSE_LEFT), wheel: gfx::mouse_wheel() };
        if text_on {
            let n = min(gfx::events_into(events), events.len);
            for e in events[..n] {
                guard input.typed.len < gui::MAX_TYPED else { break; }
                if e.kind == gfx::EVENT_TEXT { input.typed.push(e.codepoint); }
                if e.kind == gfx::EVENT_KEY && e.down && e.scancode == erase_key { input.typed.push(gui::ERASE); }
                if e.kind == gfx::EVENT_KEY && e.down && e.scancode == enter_key { input.typed.push(gui::ENTER); }
            }
        }
        gui::begin(g, input, scale, now);
        // A wheel's turn scrolls a list (gui::scroll_begin), a change to draw.
        if input.wheel != 0.0 { dirty = true; }
        // Android's back (SDL's "AC Back"; DraughtsActivity hands the system's back to SDL
        // as that key) and Escape go back a screen, as the screen's own back or home control
        // does. On home's menu back leaves the app as the system's back would, putting it in
        // the background; Escape there ends the loop, closing the Mac's window.
        if gfx::key_pressed("AC Back") || gfx::key_pressed("Escape") {
            if shell::back(sh, now) { dirty = true; }
            else if on_android { draughts_leave(); }
            else { break; }
        }
        // The development flags' switch and held moments (dev.goose).
        dev::before(dv, f, sh, now);
        // The 3D board chosen but not ready (it gets ready a step a frame as it is drawn,
        // draw3d::prepare): the shell shows a still mark in its place, or the old image while
        // a new theme bakes, and leaves taps on it alone; the frames go on until it shows
        // and has faded in, and while the old image eases grey or the new one back. Back
        // to flat, it is all given back once settings is left, so switching flat and 3D
        // there and back doesn't prepare it again each time.
        let want = shell::board3d(sh);
        let ready3d = want != shell::WANTED || draw3d::ready(d3, d.kind, shell::board_n(sh), d.scene.plain);
        let shown3d = draw3d::shows(d3);
        if want == shell::WANTED && (!ready3d || !shown3d || draw3d::appearing(d3, now)) { dirty = true; }
        // Once ready, the frame after its last step draws the new image (nothing else may
        // be changing then), and it eases back from grey: when the last frame showed it.
        if sh.out.raised && (d3.fresh || draw3d::greying(d3)) { dirty = true; }
        if want == shell::DROPPED && d3.ready {
            draw3d::drop(d3);
            draw::cover(d);     // the flat game's cover again (resize.c)
        }
        let out .= shell::frame(sh, g, size.x, size.y, now, ready3d, shown3d);
        if out.changed { dirty = true; }
        // The keyboard: up while a name is typed, brought up again by each tap on the name.
        if out.typing != text_on || (out.typing && out.keyboard != keyboard) {
            gfx::text_input(false);
            if out.typing { gfx::text_input(true); }
            text_on = out.typing;
            keyboard = out.keyboard;
        }
        // Home's way out ends the loop; the game is written below.
        if out.quit { break; }
        // The computer's move: the worker gets what the game asks, and the game the answer.
        // After shell::frame, so a game the shell started over this frame, its skill set
        // anew there, is asked at that skill (shell::game_screen).
        if think::frame(thinker, sh.game) {
            dirty = true;
            g.acted = true;
        }
        // A tap in settings applies at once and is written (Frame.save); a new season
        // reloads the photograph and its blurred copies, once the tile shows lit.
        if out.save {
            players::write(sh.players, sh.prefs);
            shell::wrote(sh);
            let next = if sh.prefs.language >= 0 { sh.prefs.language } else { system_lang };
            if next != strings::current { strings::use(next); }
            if theme_for(sh.prefs.season) != d.kind || !settings::photo_shown(sh.prefs) != d.scene.plain { season_in = 2; }
            dirty = true;
        }
        // Settings' thumbnails, if settings show before the first idle frame loaded them
        // (below): opened at launch.
        if out.screen == shell::SETTINGS && w.thumbs.id == 0 {
            w.thumbs = scene::thumbs(d.full);
        }
        // The development flags' taps, and their benches' start (dev.goose).
        if dev::after_shell(dv, f, sh, g, d3, now) { dirty = true; }
        let l = out.layout;
        // iOS ends an app that uses the GPU in the background, and SDL doesn't block the
        // loop there as on Android: nothing is drawn while the app hasn't focus, which it
        // loses before going to the background, and the screen is drawn again on its return.
        let hidden = on_ios && !gfx::focused();
        if hidden { dirty = true; }
        let drew = !hidden && (dirty || shell::animating(sh, g, now));
        if drew {
            dev::drawing(dv);
            let shown .= shell::fill(sh, now);
            widgets::prepare(w, g, d.scene, d.colors, size.x, size.y, out.hole, out.tall);
            if out.raised {
                // The 3D board (draw3d.goose) over the photograph, the UI and its pieces
                // drawn over it as on the flat board; in a transition its image moves,
                // drawn once.
                draw3d::frame(d3, shown, l, out.view, now, size, d.kind, d.scene.plain, shell::which(out.shows), out.hold);
                draw::pieces_over(d, out.over, l, size.x, size.y);
                draw::photo(d, out.blur, now, size.x, size.y, draw3d::shows(d3) && !draw3d::appearing(d3, now));
                draw3d::show(d3, out.blur, out.place, out.fade, size, now);
            } else {
                draw::frame(d, shown, out.over, l, out.blur, now, size.x, size.y);
            }
            widgets::frame(w, g, d.scene, d.colors, size.x, size.y, out.hole, out.tall);
            draw::overlay(d, now, out.hole, out.tall);
            gfx::end_pass();
            dirty = false;
            dev::drawn(dv, f);
        }
        // The display at 60 Hz while the 3D board draws, on a device whose 3D board is too slow
        // for its faster display (task 056): a 90 Hz display shows 60 frames a second two
        // refreshes and one in turn, where at 60 each shows for one.
        // The 3D bench's frames that wait for each are left out (dev::waited3d).
        let paced = drew && out.raised && ready3d && shown3d && !dev::waited3d(d3);
        if on_android { draughts_pace_3d(if paced { 1 } else { 0 }, now); }
        // Settings' thumbnails load in the first frame that draws nothing once the launch's
        // first frame is on screen, so settings' first opening doesn't wait for them; the
        // next frame shows the screen again unchanged, then the app is idle. The launch's
        // loads are done then, and what they freed goes back to the system (memory.c).
        if !drew && !hidden && !released && gfx::frame_count() >= 2 {
            if w.thumbs.id == 0 { w.thumbs = scene::thumbs(d.full); }
            draughts_release_memory();
            released = true;
        }
        // A running clock is drawn when the time it shows changes, and the computer's move
        // played when it is due; a timer wakes the loop then, rather than whenever the
        // idle wait ends (wake.c).
        let next = shell::wake_in(sh, now, HINT_POLL);
        if next >= 0.0 && (wake_at < now || now + next < wake_at - 0.005) {
            draughts_wake_in((1000.0 * next) as i64 + 2);
            wake_at = now + next;
        }
        // A widget declared this frame before a click changed what it shows (a choice
        // lit, a toggle), so the next frame draws again; this one drew, so the next
        // doesn't wait for an event.
        if g.acted { dirty = true; }
        // The development flags' frame count, rest, and benches (dev.goose).
        if dev::after(dv, f, d3, drew, size, now) { break; }
    }
    dev::end(f, d3);
    shell::write_game(sh);
    if sh.out.quit { draughts_close(); }
}
