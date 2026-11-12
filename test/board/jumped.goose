// The pieces a capture has jumped stay on the board until it ends, as the rules take
// them, but see-through (board::TAKEN), so a king that turns back past them still shows
// its way (2026-11-12). Tapped stop by stop, a jumped piece goes see-through as the piece
// hops over it and is whole again once the capture is taken back; played as a move, each
// goes see-through as the mover hops over it, then all fade out after the last hop. The
// king of puzzle 14 (W:W46,K47:B5,12,22,38) takes 38, 22, and 12 by 33 and 17, ending on 8.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn sq(n: i64) -> u8[>..] {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    return drive::name(v, v.bit_of[n]);
}

fn tap(b: board::Board&, l: board::Layout, n: i64, now: f64) {
    let p = drive::at(l, sq(n));
    board::update(b, now);
    board::press(b, l, p, now);
    board::release(b, l, p, now);
}

// The opacity of the piece drawn on square number n, or -1 when none is.
fn alpha(b: board::Board&, l: board::Layout, n: i64) -> f32 {
    let v .= rules::VARIANTS[b.variant];
    let c = board::center(l, v, v.bit_of[n]);
    for p in b.pieces {
        if abs(p.at.x - c.x) < 0.5 && abs(p.at.y - c.y) < 0.5 && p.at.w == 0.0 { return p.look.w; }
    }
    return -1.0;
}

fn show(b: board::Board&, l: board::Layout, what: const u8[:], now: f64) {
    board::update(b, now);
    board::fill(b, l, now);
    print(what, ": 38 ", alpha(b, l, 38), ", 22 ", alpha(b, l, 22), ", 12 ", alpha(b, l, 12),
          ", 5 ", alpha(b, l, 5));
}

fn main() {
    let l = panel::layout(1280.0, 800.0, 10).board;
    let king, ok = rules::parse_fen("W:W46,K47:B5,12,22,38", rules::INTERNATIONAL);
    assert(ok);
    var b = board::new(rules::INTERNATIONAL);
    board::set(b, king);
    tap(b, l, 47, 0.0);
    show(b, l, "47 selected", 0.0);
    tap(b, l, 33, 1.0);
    show(b, l, "33 tapped, halfway through the hop", 1.1);
    show(b, l, "on 33", 1.5);
    tap(b, l, 17, 2.0);
    show(b, l, "on 17", 2.5);
    print("unwound ", board::unwind(b));
    show(b, l, "taken back", 2.6);

    // The same capture played as a move: 33, 17, 8, a hop each, then the fade.
    tap(b, l, 47, 3.0);
    tap(b, l, 33, 3.0);
    tap(b, l, 17, 3.0);
    tap(b, l, 8, 3.0);
    show(b, l, "8 tapped, the hops made by hand", 3.0);
    show(b, l, "halfway over 12", 3.1);
    show(b, l, "on 8, fading", 2.6 + 3.0 * board::HOP + 0.5 * board::FADE);
    show(b, l, "played", 4.0);
}
