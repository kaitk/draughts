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
import os;
import rules from "../rules";
import board from "../board";
import strings from "../../strings";
import gui from "../gui";
import .theme;
import .draw;
import .draw_gpu;
import .gpu;
import .scene;
import .scene_gpu;
import .widgets;
import .widgets_gpu;
import game from "../game";
import shell from "../shell";
import ai from "../ai";
import puzzles from "../puzzles";
import badges from "../badges";
import model3d from "../model3d";
import render3d from "../render3d";
import .text;
import .host;
import .host_gpu;
import .think;
import .draw3d;
import .render;
import .flags;
import .dev;

// Seconds between looks for the hint's answer while it is on its way (think::frame).
let HINT_POLL = 0.02;

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
    let dir = host::storage(folder);
    var players_read = players::Players {};
    let prefs = players::load(players_read, dir, keep);
    if kind < 0 { kind = theme_for(prefs.season); }
    var locales: u8[256] = [0; 256];
    let system_lang = strings::pick(host::locales(locales));
    if lang < 0 { lang = if prefs.language >= 0 { prefs.language } else { system_lang }; }
    strings::use(lang);
    puzzles::load((if f.variant >= 0 { f.variant } else { prefs.variant }) as u8);

    // A phone or a tablet: the window fills the screen with the system's bars hidden, the
    // clocks count only while the app has focus, and the layout takes the display's scale.
    let platform = host::platform();
    let on_android = platform == host::ANDROID;
    let on_ios = platform == host::IOS;
    let mobile = platform != host::DESKTOP;
    // An iOS app never closes itself, so home has no way out there.
    if on_ios { home::closable = false; }
    var h = host::open(strings::get(strings::APP_NAME), f.width, f.height, f.full, f.no_vsync);
    defer host::close();

    // A new game of the draughts the setup last chose, until a saved game is restored;
    // the flags' setup (dev.goose), then the playing player's game, with the screen it
    // was on, and a fresh install's first run on the sheet of its one player.
    var sh = shell::new((if f.variant >= 0 { f.variant } else { prefs.variant }) as u8);
    shell::launch(sh, prefs, players_read);
    dev::setup(f, sh, prefs);
    shell::open(sh, keep);
    var rd = render::new(kind, !settings::photo_shown(sh.prefs), f);
    var dv = dev::new(f);
    var g = gui::Gui {};
    var size = int2 { 0, 0 };
    var was_scale: f32 = 0.0;
    var dirty = true;
    var focused = true;
    var season_in = 0;
    var wake_at = -1.0;
    var released = false;
    var thinker = think::Thinker {};
    while host::frame() {
        // frame() presents what the pass before it drew, and the first pass draws.
        if host::frame_count() == 2 { host::first_frame(); }
        // Android may kill the app once it is paused; it loses focus then, and SDL lets
        // the loop run once more before blocking, so the game is written here: one small
        // write per pause, none while idle.
        if focused && !host::focused() { shell::write_game(sh); }
        // The clocks count only time the game was on screen: not the gap while Android had
        // the app paused, nor while it was in the background. On the Mac a window started
        // from a terminal never has focus, and the loop never blocks there, so focus is
        // left out and the clock runs while the window shows.
        if mobile && (!focused || !host::focused()) { shell::pause(sh); }
        focused = host::focused();
        // A new season's photograph, colors, and blurred copies load two frames after the
        // tap: the frame after it shows the tile lit, and is on screen before the load
        // (80 to 95 ms on the tablet) holds the thread.
        if season_in > 0 {
            season_in--;
            if season_in == 0 && !render::shows_theme(rd, theme_for(sh.prefs.season), !settings::photo_shown(sh.prefs)) {
                render::reload(rd, theme_for(sh.prefs.season), !settings::photo_shown(sh.prefs));
                dirty = true;
            }
        }
        let now = host::time();
        let s = host::screen_size();
        if s.x != size.x || s.y != size.y {
            size = s;
            dirty = true;
        }
        if host::exposed() { dirty = true; }
        // The safe area and the display's scale, read each frame (a few fields in SDL):
        // turning the screen moves the camera's cutout and the gesture bar, and a change
        // of either is a change of the screen, as a new size is. On a desktop the display
        // scale sets only the scale's ceiling (gui::scale_of), and a window moved to
        // another display lays out again.
        host::read_display(h);
        let display = h.display;
        if mobile && f.display_scale < 0.0 { gui::display_scale = display[4]; }
        // A desktop's controls stay the size a mouse wants however large the window
        // (gui::desktop_scale), unless --touch lays it out as a touch screen.
        // --display-scale stands for another display's (a 27" screen at 1: --size 1280x720
        // --touch off --display-scale 1 on a Retina Mac draws its 2560 × 1440 pixels).
        if !mobile && f.touch != 1 { gui::desktop_scale = if f.display_scale >= 0.0 { f.display_scale } else { display[4] }; }
        let scale = gui::scale_of(size.x, size.y);
        let e = if f.inset.x < 0.0 { float4 { display[0], display[1], display[2], display[3] } }
                else { float4 { floor(f.inset.x * scale + 0.5), floor(f.inset.y * scale + 0.5),
                                floor(f.inset.z * scale + 0.5), floor(f.inset.w * scale + 0.5) } };
        if scale != was_scale || e.x != g.insets.x || e.y != g.insets.y || e.z != g.insets.z || e.w != g.insets.w {
            was_scale = scale;
            g.insets = e;
            dirty = true;
        }
        if render::upload_text(rd, g, scale) { trim_memory(); }
        // The pointer, and a player's name typed while the keyboard is up (shell::who). The
        // screens give the pointer to the UI first; a press that lands on it never reaches
        // the board.
        let input = dev::pointer(dv, f, host::input(h, now));
        gui::begin(g, input, scale, now);
        // A wheel's turn scrolls a list (gui::scroll_begin), a change to draw.
        if input.wheel != 0.0 { dirty = true; }
        // Android's back and Escape go back a screen, as the screen's own back or home
        // control does. On home's menu back leaves the app as the system's back would,
        // putting it in the background; Escape there ends the loop, closing the Mac's window.
        if host::back(h) {
            if shell::put_down(sh, g) || shell::back(sh, now) { dirty = true; }
            else if on_android { host::leave(); }
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
        let ready3d = want != shell::WANTED || render::ready3d(rd, shell::board_n(sh));
        let shown3d = render::shown3d(rd);
        if want == shell::WANTED && (!ready3d || !shown3d || render::appearing3d(rd, now)) { dirty = true; }
        // Once ready, the frame after its last step draws the new image (nothing else may
        // be changing then), and it eases back from grey: when the last frame showed it.
        if sh.out.raised && render::moving3d(rd) { dirty = true; }
        if want == shell::DROPPED { render::drop3d(rd); }
        let out .= shell::frame(sh, g, size.x, size.y, now, ready3d, shown3d);
        if out.changed { dirty = true; }
        // The A key switches the 3D board between MSAA and SMAA, not while a name is typed.
        if !out.typing && host::aa_key() {
            render::toggle_aa(rd);
            dirty = true;
        }
        // The keyboard: up while a name is typed, brought up again by each tap on the name.
        host::keyboard(h, out.typing, out.keyboard);
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
            if !render::shows_theme(rd, theme_for(sh.prefs.season), !settings::photo_shown(sh.prefs)) { season_in = 2; }
            dirty = true;
        }
        // Settings' thumbnails, if settings show before the first idle frame loaded them
        // (below): opened at launch.
        if out.screen == shell::SETTINGS { render::thumbs(rd); }
        // The development flags' taps, and their benches' start (dev.goose).
        if dev::after_shell(dv, f, sh, g, rd, now) { dirty = true; }
        let l = out.layout;
        // iOS ends an app that uses the GPU in the background, and SDL doesn't block the
        // loop there as on Android: nothing is drawn while the app hasn't focus, which it
        // loses before going to the background, and the screen is drawn again on its return.
        let hidden = on_ios && !host::focused();
        if hidden { dirty = true; }
        let drew = !hidden && (dirty || shell::animating(sh, g, now));
        if drew {
            dev::drawing(dv);
            // The board the screen shows, its draw lists filled, and what the shell's frame
            // left: on the 3D board its image moves in a transition, drawn once.
            var frame = render::Frame { board: shell::fill(sh, now), layout: l, over: out.over[..], quads: g.quads[..],
                                        clip:  g.scroll.view, raised: out.raised, view: out.view,
                                        which: shell::which(out.shows), hold: out.hold, place: out.place,
                                        fade:  out.fade, blur: out.blur, hole: out.hole, tall: out.tall, now: now,
                                        size: size };
            render::frame(rd, frame);
            dirty = false;
            dev::drawn(dv, f);
        }
        // The display at 60 Hz while the 3D board draws, on a device whose 3D board is too slow
        // for its faster display (task 056): a 90 Hz display shows 60 frames a second two
        // refreshes and one in turn, where at 60 each shows for one.
        // The 3D bench's frames that wait for each are left out (dev::waited3d).
        let paced = drew && out.raised && ready3d && shown3d && !dev::waited3d(rd);
        if on_android { host::pace_3d(paced, now); }
        // Settings' thumbnails load in the first frame that draws nothing once the launch's
        // first frame is on screen, so settings' first opening doesn't wait for them; the
        // next frame shows the screen again unchanged, then the app is idle. The launch's
        // loads are done then, and what they freed goes back to the system (memory.c).
        if !drew && !hidden && !released && host::frame_count() >= 2 {
            render::thumbs(rd);
            host::release_memory();
            released = true;
        }
        // A running clock is drawn when the time it shows changes, the computer's move
        // played when it is due, and the 3D board's pass gives back its targets a second
        // after it last drew (draw3d::rest); a timer wakes the loop then, rather than
        // whenever the idle wait ends (wake.c).
        let resting = if !drew && !hidden { render::rest(rd, now) } else { -1.0 };
        var next = shell::wake_in(sh, now, HINT_POLL);
        if resting >= 0.0 && (next < 0.0 || resting < next) { next = resting; }
        // An arrow held repeats (host's keys.goose), waking the loop when it is due.
        let repeat = host::repeat_in(h.repeat, now);
        if repeat >= 0.0 && (next < 0.0 || repeat < next) { next = repeat; }
        // A gamepad connected is read when the loop runs (pad.c), so the loop wakes for it
        // while the app is shown.
        let polled = if hidden { -1.0 } else { host::pad_in(h.repeat) };
        if polled >= 0.0 && (next < 0.0 || polled < next) { next = polled; }
        if next >= 0.0 && (wake_at < now || now + next < wake_at - 0.005) {
            host::wake_in((1000.0 * next) as i64 + 2);
            wake_at = now + next;
        }
        // A widget declared this frame before a click changed what it shows (a choice
        // lit, a toggle), so the next frame draws again; this one drew, so the next
        // doesn't wait for an event.
        if g.acted { dirty = true; }
        // The development flags' frame count, rest, and benches (dev.goose).
        if dev::after(dv, f, rd, drew, size, now) { break; }
    }
    dev::end(f, rd);
    shell::write_game(sh);
    if sh.out.quit { host::close_app(); }
}
