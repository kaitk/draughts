// Draughts: the game screen, playable by two on one screen. It draws only when
// something changed: input, a move or a pulse animating, or a new screen size
// (docs/architecture/rendering.md, "Frames and battery").
//
//   goose draughts.goose                          on the Mac
//   goose draughts.goose -- --theme sea           another board than the season's
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

// The system's preferred locales, "et-EE,en-US" (locale.c); returns how many bytes.
extern fn draughts_locales(out: u8[:]) -> i64;

fn main() {
    // Development flags: --theme NAME, --size WxH (the window), --fen POSITION,
    // --tap SQUARE (any number, played in order on the first frames), --frames N (then
    // save draughts.png), --hints moves (show targets; mistakes only by default), --lang
    // CODE (a language with a file in strings/; the system's by default).
    var width = 1280;
    var height = 800;
    var kind = theme::for_month(theme::month(time()));
    var frames = -1;
    var hints = board::MISTAKES;
    var lang = -1;
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
        if argv[i] == "--tap" && argv[i + 1].len == 2 && taps.len < 16 {
            let t .= taps.push([]);
            t.append(argv[i + 1]);
        }
        i += 2;
    }
    let colors = theme::get(kind);
    if lang < 0 {
        var locales: u8[256] = [0; 256];
        let n = draughts_locales(locales);
        lang = strings::pick(locales[..n]);
    }
    strings::use(lang);

    var android_root: u8[>..] = [];
    let on_android = env("ANDROID_ROOT", android_root);
    let window_flags = if on_android { gfx::WINDOW_FULLSCREEN } else { gfx::WINDOW_RESIZABLE };
    guard gfx::open(strings::get(strings::APP_NAME), width, height, window_flags) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    var gm = game::new(rules::RUSSIAN);
    let b .= gm.b;
    b.hints = hints;
    if fen.len > 0 {
        let p, ok = rules::parse_fen(fen, b.variant);
        guard ok else { abort(str("not a position: ", fen)); }
        board::set(b, p);
    }
    var d = draw::new(kind);
    var w = widgets::new();
    var g = gui::Gui {};
    var size = int2 { 0, 0 };
    var dirty = true;
    var drawn = 0;
    var tapped = 0;
    while gfx::frame() {
        if gfx::key_pressed("Escape") { break; }
        let now = gfx::time();
        let s = gfx::screen_size();
        if s.x != size.x || s.y != size.y {
            size = s;
            dirty = true;
        }
        let l = board::layout(size.x, size.y, rules::VARIANTS[b.variant].size);
        // A quick tap can press and release within one frame, which mouse_down never
        // sees; pressed and released catch it. The game screen gives the pointer to the
        // UI first; a press that lands on it never reaches the board.
        let input = gui::Input { at: gfx::mouse_pos(), down: gfx::mouse_down(gfx::MOUSE_LEFT),
                                 pressed: gfx::mouse_pressed(gfx::MOUSE_LEFT),
                                 released: gfx::mouse_released(gfx::MOUSE_LEFT) };
        gui::begin(g, input, l.scale, now);
        let go, changed = game::frame(gm, g, l, now);
        if changed { dirty = true; }
        // Back goes home once there is one (task 008-03); until then it does nothing.
        if go == game::HOME { dirty = true; }
        if tapped < taps.len && !b.moving {
            let v .= rules::VARIANTS[b.variant];
            let t .= taps[tapped];
            let p = board::center(l, v, board::bit_at(v, t[0] - 97, t[1] - 49));
            board::press(b, l, p, now);
            board::release(b, l, p, now);
            tapped++;
            dirty = true;
        }
        if dirty || game::animating(gm, g, now) {
            board::fill(b, l, now);
            widgets::upload(w, g);
            draw::frame(d, b, gm.overlay, l, colors, now, size.x, size.y);
            widgets::frame(w, g, d.scene, colors, size.x, size.y);
            draw::overlay(d, colors, now);
            gfx::end_pass();
            dirty = false;
            drawn++;
        }
        if frames > 0 && gfx::frame_count() >= frames { break; }
    }
    if frames > 0 { gfx::screenshot("draughts.png"); }
}
