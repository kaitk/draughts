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
// Which platform the program runs on: DESKTOP, ANDROID, or IOS (launch.c).
extern fn draughts_platform() -> i64;
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
    let fen .= f.fen;
    let taps .= f.taps;
    var kind = f.theme;
    var hints = f.hints;
    var lang = f.lang;
    var go = f.go;
    // The game as it was when the app was last paused (shell::restore; nothing changes
    // for a missing or damaged file). A run with flags that set up a game or take a
    // screenshot neither reads nor writes it.
    let keep = f.screen < 0 && f.puzzle < 0 && go < 0 && f.win < 0.0 && fen.len == 0 && taps.len == 0 && f.frames < 0 && f.variant < 0 && f.clock < 0 && f.computer < 0;
    // The players, their settings, and their games, kept in the app's storage folder
    // (shell/players.goose): the playing player's settings with the device's language.
    var folder: u8[512] = [0; 512];
    let dir = folder[..draughts_storage(folder)];
    var players_read = players::Players {};
    let prefs = players::load(players_read, dir, keep);
    if kind < 0 { kind = theme_for(prefs.season); }
    if hints < 0 { hints = prefs.hints; }
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
    let window_flags = if mobile { gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE } else { gfx::WINDOW_RESIZABLE };
    draughts_choose_gpu();
    guard gfx::open(strings::get(strings::APP_NAME), f.width, f.height, window_flags) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    // A new game of the draughts the setup last chose, until a saved game is restored.
    var sh = shell::new((if f.variant >= 0 { f.variant } else { prefs.variant }) as u8);
    if f.clock >= 0 || f.computer >= 0 {
        let lv = if f.level >= 0 { f.level } else { prefs.level };
        game::start(sh.game, sh.game.b.variant, max(f.clock, 0), f.computer, lv, prefs.skill[lv], prefs.games);
    }
    sh.prefs = prefs;
    if f.reset_skill {
        sh.prefs.level = game::EASY;
        sh.prefs.skill = ai::LEVEL_SKILL;
        sh.prefs.played = [0; 3];
        sh.changed = true;
    }
    if f.board >= 0 { sh.prefs.board = f.board; }
    sh.players = players_read;
    let gm .= sh.game;
    let b .= gm.b;
    b.hints = hints;
    if fen.len > 0 {
        let p, ok = rules::parse_fen(fen, b.variant);
        guard ok else { abort(str("not a position: ", fen)); }
        board::set(b, p);
    }
    sh.screen = if f.screen >= 0 { f.screen } else if fen.len > 0 || taps.len > 0 || f.clock >= 0 || f.computer >= 0 { shell::GAME } else { shell::HOME };
    sh.setup = f.setup;
    // A setup the flags open shows the draughts, the child's color, and the level they
    // give, with the settings file left as it is unless a tap in the setup writes it.
    if f.setup != home::NOTHING {
        if f.variant >= 0 { sh.prefs.variant = f.variant; }
        if f.computer >= 0 { sh.prefs.color = 1 - f.computer; }
        if f.level >= 0 { sh.prefs.level = f.level; }
    }
    if f.puzzle >= 0 && puzzles::find(puzzles::all, f.puzzle) >= 0 && go != shell::PUZZLE {
        shell::play_puzzle(sh, puzzles::find(puzzles::all, f.puzzle));
    }
    // The playing player's game, with the screen it was on.
    shell::read_game(sh);
    // A fresh install's first run opens on the sheet of its one player, to pick a badge.
    if keep && sh.players.fresh { who::first_run(sh.who, sh.players); }
    if f.background >= 0 { sh.prefs.plain = f.background == 1; }
    var d = draw::new(kind, !settings::photo_shown(sh.prefs));
    var d3 = draw3d::Drawer { wood: f.wood, marble: f.marble, summer: f.summer, spring: f.spring, timed: f.bench > 0, .. };
    var w = widgets::new();
    var g = gui::Gui {};
    var t = text::Text {};
    var size = int2 { 0, 0 };
    var display:   f32[5] = [0.0; 5];
    var was_scale: f32    = 0.0;
    var dirty = true;
    var tapped = 0;
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
        if mobile && (!focused || !gfx::focused()) { game::pause(sh.game); }
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
        if text::bake(t, g, scale) { trim_memory(); }
        w.atlas = t.texture;
        // A quick tap can press and release within one frame, which mouse_down never
        // sees; pressed and released catch it. The screens give the pointer to the UI
        // first; a press that lands on it never reaches the board.
        var input = gui::Input { at: gfx::mouse_pos(), down: gfx::mouse_down(gfx::MOUSE_LEFT),
                                 pressed: gfx::mouse_pressed(gfx::MOUSE_LEFT),
                                 released: gfx::mouse_released(gfx::MOUSE_LEFT) };
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
        // A switch the flags ask for waits for their taps to have played out, and for the
        // win they lead to, if any, held at --win's moment (which must be past: the
        // celebration's start is kept as a time, never before 0).
        if go >= 0 && gfx::frame_count() >= 2 && tapped >= taps.len && !b.moving
           && (f.win < 0.0 || ((sh.game.won_at >= 0.0 || sh.game.drawn_at >= 0.0) && now > f.win)) {
            if go == flags::GO_PLAY {
                // As the setup's play, leaving settings.txt as it is: the count of games
                // against the computer and the choices the flags gave aren't written.
                shell::play(sh, now);
                sh.changed = false;
            }
            else if go == shell::PUZZLE { shell::play_puzzle(sh, max(puzzles::find(puzzles::all, f.puzzle), 0), now); }
            else { shell::go_to(sh, go, now); }
            go = -1;
        }
        // Android's back (SDL's "AC Back"; DraughtsActivity hands the system's back to SDL
        // as that key) and Escape go back a screen, as the screen's own back or home control
        // does. On home's menu back leaves the app as the system's back would, putting it in
        // the background; Escape there ends the loop, closing the Mac's window.
        if gfx::key_pressed("AC Back") || gfx::key_pressed("Escape") {
            if shell::back(sh, now) { dirty = true; }
            else if on_android { draughts_leave(); }
            else { break; }
        }
        if f.hold >= 0.0 && sh.from >= 0 { sh.since = now - f.hold * shell::DURATION; }
        if f.win >= 0.0 && sh.game.won_at >= 0.0 { sh.game.won_at = now - f.win; }
        if f.win >= 0.0 && sh.game.drawn_at >= 0.0 { sh.game.drawn_at = now - f.win; }
        // The 3D board chosen but not ready (it gets ready a step a frame as it is drawn,
        // draw3d::prepare): the shell shows a still mark in its place, or the old image while
        // a new theme bakes, and leaves taps on it alone; the frames go on until it shows
        // and has faded in, and while the old image eases grey or the new one back. Back
        // to flat, it is all given back once settings is left, so switching flat and 3D
        // there and back doesn't prepare it again each time.
        let n_was = if sh.layout.n > 0 { sh.layout.n } else { rules::VARIANTS[sh.prefs.variant].size };
        sh.ready3d = !settings::raised(sh.prefs) || draw3d::ready(d3, d.kind, n_was, d.scene.plain);
        sh.shown3d = draw3d::shows(d3);
        if settings::raised(sh.prefs) && (!sh.ready3d || !sh.shown3d || draw3d::appearing(d3, now)) { dirty = true; }
        // Once ready, the frame after its last step draws the new image (nothing else may
        // be changing then), and it eases back from grey.
        if sh.raised && (d3.fresh || draw3d::greying(d3)) { dirty = true; }
        if !settings::raised(sh.prefs) && sh.screen != shell::SETTINGS && sh.from < 0 { draw3d::drop(d3); }
        if shell::frame(sh, g, size.x, size.y, now) { dirty = true; }
        // The keyboard: up while a name is typed, brought up again by each tap on the name.
        let typing = sh.who.typing && sh.screen == shell::HOME;
        if typing != text_on || (typing && sh.who.keyboard != keyboard) {
            gfx::text_input(false);
            if typing { gfx::text_input(true); }
            text_on = typing;
            keyboard = sh.who.keyboard;
        }
        // Home's way out ends the loop; the game is written below.
        if sh.quit { break; }
        // The computer's move: the worker gets what the game asks, and the game the answer.
        think::frame(thinker, sh.game);
        // A tap in settings applies at once and is written; a new season reloads the
        // photograph and its blurred copies, once the tile shows lit. A change made by the
        // tap that starts a transition (the computer's play counting a game) is written
        // once it is over: the write flushes to disk, 13 to 17 ms on the tablet, too long
        // for the frame that starts it moving.
        if sh.changed && sh.from < 0 {
            sh.changed = false;
            players::write(sh.players, sh.prefs);
            let next = if sh.prefs.language >= 0 { sh.prefs.language } else { system_lang };
            if next != strings::current { strings::use(next); }
            if theme_for(sh.prefs.season) != d.kind || !settings::photo_shown(sh.prefs) != d.scene.plain { season_in = 2; }
            dirty = true;
        }
        // Settings' thumbnails, if settings show before the first idle frame loaded them
        // (below): opened at launch.
        if sh.screen == shell::SETTINGS && w.thumbs.id == 0 {
            w.thumbs = scene::thumbs(d.full);
        }
        let l = sh.layout;
        if tapped < taps.len && !b.moving && sh.screen == shell::GAME && b.pos.side != gm.computer {
            let v .= rules::VARIANTS[b.variant];
            let sq, ok = rules::parse_square(v, taps[tapped]);
            if ok {
                let p = board::center(l, v, sq);
                board::press(b, l, p, now);
                board::release(b, l, p, now);
            }
            tapped++;
            dirty = true;
        }
        if tapped < taps.len && sh.screen == shell::PUZZLE && puzzle::ready(sh.puzzle) {
            let v .= rules::VARIANTS[sh.puzzle.b.variant];
            let sq, ok = rules::parse_square(v, taps[tapped]);
            if ok { puzzle::tap(sh.puzzle, l, board::center(l, v, sq), now); }
            tapped++;
            dirty = true;
            // Next was declared before this tap, which may have left a piece waiting.
            g.acted = true;
        }
        // --bench N times the 3D board's frames 2 s after the launch, settled (draw3d.goose).
        if f.bench > 0 && sh.raised && d3.draws > 0 && now > 2.0 && d3.bench.n == 0 { d3.bench.n = f.bench; }
        if d3.bench.n > 0 { dirty = true; }
        // iOS ends an app that uses the GPU in the background, and SDL doesn't block the
        // loop there as on Android: nothing is drawn while the app hasn't focus, which it
        // loses before going to the background, and the screen is drawn again on its return.
        let hidden = on_ios && !gfx::focused();
        if hidden { dirty = true; }
        let drew = !hidden && (dirty || shell::animating(sh, g, now));
        if drew {
            let shown .= shell::fill(sh, now);
            widgets::upload(w, g);
            if sh.raised {
                // The 3D board (draw3d.goose) over the photograph, the UI and its pieces
                // drawn over it as on the flat board; in a transition its image moves,
                // drawn once.
                draw3d::frame(d3, shown, l, sh.view, now, size, d.kind, d.scene.plain, shell::which(sh.shows), sh.hold);
                draw::pieces_over(d, sh.over, l, size.x, size.y);
                draw::photo(d, sh.blur, now, size.x, size.y, draw3d::shows(d3) && !draw3d::appearing(d3, now));
                draw3d::show(d3, sh.blur, sh.place, sh.fade, size, now);
            } else {
                draw::frame(d, shown, sh.over, l, sh.blur, now, size.x, size.y);
            }
            widgets::frame(w, g, d.scene, d.colors, size.x, size.y, sh.hole, sh.tall);
            draw::overlay(d, now, sh.hole, sh.tall);
            gfx::end_pass();
            dirty = false;
        }
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
        var next = -1.0;
        if sh.screen == shell::GAME {
            next = clock::until_next(sh.game.clock);
            let due = game::due(sh.game, now);
            if due >= 0.0 && (next < 0.0 || due < next) { next = due; }
        }
        if next >= 0.0 && (wake_at < now || now + next < wake_at - 0.005) {
            draughts_wake_in((1000.0 * next) as i64 + 2);
            wake_at = now + next;
        }
        // A widget declared this frame before a click changed what it shows (a choice
        // lit, a toggle), so the next frame draws again; this one drew, so the next
        // doesn't wait for an event.
        if g.acted { dirty = true; }
        if f.frames > 0 && gfx::frame_count() >= f.frames { break; }
        if draw3d::bench_done(d3) { break; }
    }
    if f.frames > 0 { gfx::screenshot("draughts.png"); }
    if f.frames > 0 && d3.prep_ms.len > 0 {
        var line: u8[>..] = [];
        for ms in d3.prep_ms { format(line, " ", floor(ms * 100.0 + 0.5) / 100.0); }
        print("3D board prepared in ", d3.prep_ms.len, " steps, each waited, ms:", line);
    }
    if f.frames > 0 && d3.frames > 0 { print("3D board: ", d3.frames, " frames showed it, ", d3.draws, " drew it, ", d3.shadows, " its shadow map, ", d3.pulses, " only its pulsing marks"); }
    shell::write_game(sh);
    if sh.quit { draughts_close(); }
}
