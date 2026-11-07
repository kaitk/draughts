// Draughts: home and the game screen, played by two on one screen or against the
// computer, which thinks on a worker thread (think.goose). It draws only when something
// changed: input, a move or a pulse animating, or a new screen size
// (docs/architecture/rendering.md, "Frames and battery"). The thread needs a build: on
// the Mac, from app/, `goose build -o ../build/draughts draughts.goose`, then
//
//   ../build/draughts                             at home
//   ../build/draughts --screen game               the game screen; --fen and --tap open it too
//   ../build/draughts --theme sunset              another board than the season's
//   ../build/draughts --frames 30 --tap c3        taps squares, then saves draughts.png
//   ../build/draughts --fen W:Wc3,Kh6:Be5         starts from a position
//   ../build/draughts --hints moves               shows the selected piece's targets
//   ../build/draughts --lang et                   another language than the system's
//   ../build/draughts --variant russian           a new game of another draughts
//   ../build/draughts --clock 5+3                 with a clock
//   ../build/draughts --computer white --level hard   against the computer playing white
//   scripts/android.py app/draughts.goose --run   on the tablet (docs/development.md)

import std;
import vec;
import gfx;
import os;
import rules from "../rules";
import board from "../board";
import strings from "../strings";
import gui from "../gui";
import .theme;
import .draw;
import .scene;
import .widgets;
import game from "../game";
import shell from "../shell";
import ai from "../ai";
import .text;
import .think;

// The system's preferred locales, "et-EE,en-US" (locale.c); returns how many bytes.
extern fn draughts_locales(out: u8[:]) -> i64;
// The app's storage folder, ending in a separator (storage.c); returns how many bytes.
extern fn draughts_storage(out: u8[:]) -> i64;
// Wakes the loop in ms milliseconds, where frame() waits for events (wake.c).
extern fn draughts_wake_in(ms: i64);

// The theme a season setting picks: its own, or by the date.
fn theme_for(season: i64) -> i64 {
    return if season >= 0 { season } else { theme::for_month(theme::month(time())) };
}

fn main() {
    // Development flags: --theme NAME, --size WxH (the window), --fen POSITION,
    // --tap SQUARE (any number, played in order on the first frames), --frames N (then
    // save draughts.png), --hints moves (show targets; mistakes only by default), --lang
    // CODE (a language with a file in strings/; the system's by default), --screen
    // home|game|settings|friend|computer (home unless a position, taps, a clock, or the
    // computer are given; the last two open home's setup), --variant
    // international|brazilian|russian, --clock none|5+3|10+5, --computer white|black (a
    // new game; --level easy|medium|hard, the setup's last by default). --theme, --hints,
    // and --lang override the settings for the run without changing them.
    var width = 1280;
    var height = 800;
    var kind = -1;
    var frames = -1;
    var hints = -1;
    var lang = -1;
    var screen = -1;
    var variant = -1;
    var clock_kind = -1;
    var computer = -1;
    var level = -1;
    var setup = 0;
    var fen:  u8[>..]       = [];
    var taps: u8[..3][..16] = [];
    let argv = args();
    var i = 1;
    while i + 1 < argv.len {
        if argv[i] == "--theme" && theme::by_name(argv[i + 1]) >= 0 { kind = theme::by_name(argv[i + 1]); }
        if argv[i] == "--frames" {
            let n, ok = parse_int(argv[i + 1]);
            if ok { frames = n; }
        }
        if argv[i] == "--size" {
            let w, h, found = split_once(argv[i + 1], "x");
            let a, ok_a = parse_int(w);
            let c, ok_c = parse_int(h);
            if found && ok_a && ok_c { width = a; height = c; }
        }
        if argv[i] == "--fen" { fen.append(argv[i + 1]); }
        if argv[i] == "--hints" && argv[i + 1] == "moves" { hints = board::MOVES; }
        if argv[i] == "--lang" { lang = strings::pick(argv[i + 1]); }
        for name, k in settings::DRAUGHTS_NAMES { if argv[i] == "--variant" && argv[i + 1] == name { variant = settings::DRAUGHTS[k]; } }
        for name, k in settings::CLOCK_NAMES { if argv[i] == "--clock" && argv[i + 1] == name { clock_kind = k; } }
        if argv[i] == "--computer" { computer = if argv[i + 1] == "white" { rules::WHITE } else { rules::BLACK }; }
        for name, k in settings::LEVEL_NAMES { if argv[i] == "--level" && argv[i + 1] == name { level = k; } }
        if argv[i] == "--screen" {
            screen = if argv[i + 1] == "game" { shell::GAME } else if argv[i + 1] == "settings" { shell::SETTINGS } else { shell::HOME };
            if argv[i + 1] == "friend" { setup = home::FRIEND; }
            if argv[i + 1] == "computer" { setup = home::COMPUTER; }
        }
        if argv[i] == "--tap" && argv[i + 1].len >= 2 && argv[i + 1].len <= 3 && taps.len < 16 {
            let t .= taps.push([]);
            t.append(argv[i + 1]);
        }
        i += 2;
    }
    // The settings, kept in the app's storage folder (shell/settings.goose).
    var folder:     u8[512] = [0; 512];
    var prefs_path: u8[>..] = [];
    prefs_path.append(folder[..draughts_storage(folder)]);
    prefs_path.append("settings.txt");
    var save_path: u8[>..] = [];
    save_path.append(prefs_path[..prefs_path.len - 12]);
    save_path.append("game.bin");
    var prefs_text: u8[>..] = [];
    read_file(prefs_path, prefs_text);
    let prefs = settings::parse(prefs_text);
    if kind < 0 { kind = theme_for(prefs.season); }
    if hints < 0 { hints = prefs.hints; }
    var colors = theme::get(kind);
    var locales: u8[256] = [0; 256];
    let system_lang = strings::pick(locales[..draughts_locales(locales)]);
    if lang < 0 { lang = if prefs.language >= 0 { prefs.language } else { system_lang }; }
    strings::use(lang);

    var android_root: u8[>..] = [];
    let on_android = env("ANDROID_ROOT", android_root);
    let window_flags = if on_android { gfx::WINDOW_FULLSCREEN } else { gfx::WINDOW_RESIZABLE };
    guard gfx::open(strings::get(strings::APP_NAME), width, height, window_flags) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    // A new game of the draughts the setup last chose, until a saved game is restored.
    var sh = shell::new((if variant >= 0 { variant } else { prefs.variant }) as u8);
    if clock_kind >= 0 || computer >= 0 {
        let lv = if level >= 0 { level } else { prefs.level };
        game::start(sh.game, sh.game.b.variant, max(clock_kind, 0), computer, lv, prefs.skill[lv], prefs.games);
    }
    sh.prefs = prefs;
    sh.prefs.hints = hints;
    let gm .= sh.game;
    let b .= gm.b;
    b.hints = hints;
    if fen.len > 0 {
        let p, ok = rules::parse_fen(fen, b.variant);
        guard ok else { abort(str("not a position: ", fen)); }
        board::set(b, p);
    }
    sh.screen = if screen >= 0 { screen } else if fen.len > 0 || taps.len > 0 || clock_kind >= 0 || computer >= 0 { shell::GAME } else { shell::HOME };
    sh.setup = setup;
    // The game as it was when the app was last paused (shell::restore; nothing changes
    // for a missing or damaged file). A run with flags that set up a game or take a
    // screenshot neither reads nor writes it.
    let keep = screen < 0 && fen.len == 0 && taps.len == 0 && frames < 0 && variant < 0 && clock_kind < 0 && computer < 0;
    if keep {
        var saved: u8[>..] = [];
        if read_file(save_path, saved) { shell::restore(sh, saved); }
    }
    var d = draw::new(kind);
    // Loading the photograph took 16 MB of data stack for its pixels; give the pages back
    // rather than keep them resident. The same after baking the text.
    trim_memory();
    var w = widgets::new();
    var g = gui::Gui {};
    var t = text::Text {};
    var size = int2 { 0, 0 };
    var dirty = true;
    var drawn = 0;
    var tapped = 0;
    var focused = true;
    var season_in = 0;
    var wake_at = -1.0;
    var thinker = think::Thinker {};
    while gfx::frame() {
        if gfx::key_pressed("Escape") { break; }
        // Android may kill the app once it is paused; it loses focus then, and SDL lets
        // the loop run once more before blocking, so the game is written here: one small
        // write per pause, none while idle.
        if keep && focused && !gfx::focused() { write_file_atomic(save_path, shell::save(sh)); }
        // The clocks count only time the game was on screen: not the gap while Android had
        // the app paused, nor while it was in the background. On the Mac a window started
        // from a terminal never has focus, and the loop never blocks there, so focus is
        // left out and the clock runs while the window shows.
        if on_android && (!focused || !gfx::focused()) { game::pause(sh.game); }
        focused = gfx::focused();
        // A new season's photograph, colors, and blurred copies load two frames after the
        // tap: the frame after it shows the tile lit, and is on screen before the load
        // (80 to 95 ms on the tablet) holds the thread.
        if season_in > 0 {
            season_in--;
            if season_in == 0 && theme_for(sh.prefs.season) != kind {
                kind = theme_for(sh.prefs.season);
                colors = theme::get(kind);
                draw::reload(d, kind);
                trim_memory();
                dirty = true;
            }
        }
        let now = gfx::time();
        let s = gfx::screen_size();
        if s.x != size.x || s.y != size.y {
            size = s;
            dirty = true;
        }
        let scale = min(size.x, size.y) / 800.0;
        if text::bake(t, g, scale) { trim_memory(); }
        w.atlas = t.texture;
        // A quick tap can press and release within one frame, which mouse_down never
        // sees; pressed and released catch it. The screens give the pointer to the UI
        // first; a press that lands on it never reaches the board.
        let input = gui::Input { at: gfx::mouse_pos(), down: gfx::mouse_down(gfx::MOUSE_LEFT),
                                 pressed: gfx::mouse_pressed(gfx::MOUSE_LEFT),
                                 released: gfx::mouse_released(gfx::MOUSE_LEFT) };
        gui::begin(g, input, scale, now);
        if shell::frame(sh, g, size.x, size.y, now) { dirty = true; }
        // The computer's move: the worker gets what the game asks, and the game the answer.
        think::frame(thinker, sh.game);
        // A tap in settings applies at once and is written; a new season reloads the
        // photograph and its blurred copies, once the tile shows lit.
        if sh.changed {
            sh.changed = false;
            var out: u8[>..] = [];
            settings::write(sh.prefs, out);
            write_file_atomic(prefs_path, out);
            let next = if sh.prefs.language >= 0 { sh.prefs.language } else { system_lang };
            if next != strings::current { strings::use(next); }
            if theme_for(sh.prefs.season) != kind { season_in = 2; }
            dirty = true;
        }
        if sh.screen == shell::SETTINGS && w.thumbs.id == 0 {
            w.thumbs = scene::thumbs();
            trim_memory();
        }
        let l = sh.layout;
        if tapped < taps.len && !b.moving && sh.screen == shell::GAME && b.pos.side != gm.computer {
            let v .= rules::VARIANTS[b.variant];
            let t .= taps[tapped];
            let row, ok = parse_int(t[1..]);
            let p = board::center(l, v, board::bit_at(v, t[0] - 97, row - 1));
            board::press(b, l, p, now);
            board::release(b, l, p, now);
            tapped++;
            dirty = true;
        }
        if dirty || shell::animating(sh, g, now) {
            // Settings show their preview; the other screens the game's board.
            let preview = sh.screen == shell::SETTINGS;
            if preview { board::fill(sh.preview, l, now); } else { board::fill(b, l, now); }
            widgets::upload(w, g);
            if preview {
                draw::frame(d, sh.preview, gm.overlay, l, colors, sh.sharp, now, size.x, size.y);
            } else {
                draw::frame(d, b, gm.overlay, l, colors, sh.sharp, now, size.x, size.y);
            }
            widgets::frame(w, g, d.scene, colors, size.x, size.y);
            draw::overlay(d, colors, now);
            gfx::end_pass();
            dirty = false;
            drawn++;
        }
        // A running clock is drawn when the time it shows changes; a timer wakes the loop
        // then, rather than whenever the idle wait ends (wake.c).
        let ck .= sh.game.clock;
        if sh.screen == shell::GAME && ck.running >= 0 {
            let next = clock::until_next(ck);
            if wake_at < now || now + next < wake_at - 0.005 {
                draughts_wake_in((1000.0 * next) as i64 + 2);
                wake_at = now + next;
            }
        }
        // A widget declared this frame before a click changed what it shows (a choice
        // lit, a toggle), so the next frame draws again; this one drew, so the next
        // doesn't wait for an event.
        if g.acted { dirty = true; }
        if frames > 0 && gfx::frame_count() >= frames { break; }
    }
    if frames > 0 { gfx::screenshot("draughts.png"); }
    if keep { write_file_atomic(save_path, shell::save(sh)); }
}
