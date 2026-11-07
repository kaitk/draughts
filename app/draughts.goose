// Draughts: home and the game screen, playable by two on one screen. It draws only
// when something changed: input, a move or a pulse animating, or a new screen size
// (docs/architecture/rendering.md, "Frames and battery").
//
//   goose draughts.goose                          on the Mac, at home
//   goose draughts.goose -- --screen game         the game screen; --fen and --tap open it too
//   goose draughts.goose -- --theme sunset           another board than the season's
//   goose draughts.goose -- --frames 30 --tap c3  taps squares, then saves draughts.png
//   goose draughts.goose -- --fen W:Wc3,Kh6:Be5   starts from a position
//   goose draughts.goose -- --hints moves         shows the selected piece's targets
//   goose draughts.goose -- --lang et             another language than the system's
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
import .text;

// The system's preferred locales, "et-EE,en-US" (locale.c); returns how many bytes.
extern fn draughts_locales(out: u8[:]) -> i64;
// The app's storage folder, ending in a separator (storage.c); returns how many bytes.
extern fn draughts_storage(out: u8[:]) -> i64;

// The theme a season setting picks: its own, or by the date.
fn theme_for(season: i64) -> i64 {
    return if season >= 0 { season } else { theme::for_month(theme::month(time())) };
}

fn main() {
    // Development flags: --theme NAME, --size WxH (the window), --fen POSITION,
    // --tap SQUARE (any number, played in order on the first frames), --frames N (then
    // save draughts.png), --hints moves (show targets; mistakes only by default), --lang
    // CODE (a language with a file in strings/; the system's by default), --screen
    // home|game|settings (home unless a position or taps are given). --theme, --hints, and
    // --lang override the settings for the run without changing them.
    var width = 1280;
    var height = 800;
    var kind = -1;
    var frames = -1;
    var hints = -1;
    var lang = -1;
    var screen = -1;
    var fen:  u8[>..]       = [];
    var taps: u8[..2][..16] = [];
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
        if argv[i] == "--screen" {
            screen = if argv[i + 1] == "game" { shell::GAME } else if argv[i + 1] == "settings" { shell::SETTINGS } else { shell::HOME };
        }
        if argv[i] == "--tap" && argv[i + 1].len == 2 && taps.len < 16 {
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

    var sh = shell::new(rules::RUSSIAN);
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
    sh.screen = if screen >= 0 { screen } else if fen.len > 0 || taps.len > 0 { shell::GAME } else { shell::HOME };
    // The game as it was when the app was last paused (shell::restore; nothing changes
    // for a missing or damaged file). A run with flags that set up a game or take a
    // screenshot neither reads nor writes it.
    let keep = screen < 0 && fen.len == 0 && taps.len == 0 && frames < 0;
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
    while gfx::frame() {
        if gfx::key_pressed("Escape") { break; }
        // Android may kill the app once it is paused; it loses focus then, and SDL lets
        // the loop run once more before blocking, so the game is written here: one small
        // write per pause, none while idle.
        if keep && focused && !gfx::focused() { write_file_atomic(save_path, shell::save(sh)); }
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
        if tapped < taps.len && !b.moving && sh.screen == shell::GAME {
            let v .= rules::VARIANTS[b.variant];
            let t .= taps[tapped];
            let p = board::center(l, v, board::bit_at(v, t[0] - 97, t[1] - 49));
            board::press(b, l, p, now);
            board::release(b, l, p, now);
            tapped++;
            dirty = true;
        }
        if dirty || shell::animating(sh, g, now) {
            board::fill(b, l, now);
            widgets::upload(w, g);
            draw::frame(d, b, gm.overlay, l, colors, sh.sharp, sh.board, now, size.x, size.y);
            widgets::frame(w, g, d.scene, colors, size.x, size.y);
            draw::overlay(d, colors, now);
            gfx::end_pass();
            dirty = false;
            drawn++;
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
