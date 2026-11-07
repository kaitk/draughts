// Kabe: the board, playable by two on one screen. It draws only when
// something changed: input, a move or a pulse animating, or a new screen size
// (docs/architecture/rendering.md, "Frames and battery").
//
//   goose kabe.goose                          on the Mac
//   goose kabe.goose -- --theme sea           another board than the season's
//   goose kabe.goose -- --frames 30 --tap c3  taps squares, then saves kabe.png
//   goose kabe.goose -- --fen W:Wc3,Kh6:Be5   starts from a position
//   scripts/android.py app/kabe.goose --run   on the tablet (docs/development.md)

import std;
import vec;
import gfx;
import os;
import rules from "../rules";
import board from "../board";
import .theme;
import .draw;

fn main() {
    // Development flags: --theme NAME, --size WxH (the window), --fen POSITION,
    // --tap SQUARE (any number, played in order on the first frames), --frames N (then
    // save kabe.png).
    var width = 1280;
    var height = 800;
    var kind = theme::for_month(theme::month(time()));
    var frames = -1;
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
        if argv[i] == "--tap" && argv[i + 1].len == 2 && taps.len < 16 {
            let t .= taps.push([]);
            t.append(argv[i + 1]);
        }
        i += 2;
    }
    let colors = theme::get(kind);

    var android_root: u8[>..] = [];
    let on_android = env("ANDROID_ROOT", android_root);
    let window_flags = if on_android { gfx::WINDOW_FULLSCREEN } else { gfx::WINDOW_RESIZABLE };
    guard gfx::open("Kabe", width, height, window_flags) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    var b = board::new(rules::RUSSIAN);
    if fen.len > 0 {
        let p, ok = rules::parse_fen(fen, b.variant);
        guard ok else { abort(str("not a position: ", fen)); }
        board::set(b, p);
    }
    var d = draw::new();
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
        if board::update(b, now) { dirty = true; }
        if tapped < taps.len && !b.moving {
            let v .= rules::VARIANTS[b.variant];
            let t .= taps[tapped];
            let p = board::center(l, v, board::bit_at(v, t[0] - 97, t[1] - 49));
            board::press(b, l, p, now);
            board::release(b, l, p, now);
            tapped++;
            dirty = true;
        }
        // A quick tap can press and release within one frame, which mouse_down never
        // sees; pressed and released catch it.
        let p = gfx::mouse_pos();
        if gfx::mouse_pressed(gfx::MOUSE_LEFT) {
            board::press(b, l, p, now);
            dirty = true;
        }
        if gfx::mouse_down(gfx::MOUSE_LEFT) && board::drag(b, l, p) { dirty = true; }
        if gfx::mouse_released(gfx::MOUSE_LEFT) {
            board::release(b, l, p, now);
            dirty = true;
        }
        if dirty || board::animating(b, now) {
            board::fill(b, l, now);
            draw::frame(d, b, l, colors, now, size.x, size.y);
            dirty = false;
            drawn++;
        }
        if frames > 0 && gfx::frame_count() >= frames { break; }
    }
    if frames > 0 { gfx::screenshot("kabe.png"); }
}
