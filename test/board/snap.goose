// A press or drop that misses the dark squares (board::snap): a finger on a phone's
// board often lands a little off, on a light square, which is no square to play. It goes
// to the nearest square it could mean within 0.9 of a square: a piece that can move, or
// the selected piece's target or next stop. A dark square is never moved, so a drop on a
// wrong one is still a mistake, and a point farther off still does nothing. Puzzle 1's
// position, W:W32,41:B6,28: only 32 can move, taking 28 to 23.
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

// The center of square number n, moved by (dx, dy) squares.
fn at(l: board::Layout, n: i64, dx: f32, dy: f32) -> float2 {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    return board::center(l, v, v.bit_of[n]) + float2 { dx * l.inner.w, dy * l.inner.w };
}

fn drop(b: board::Board&, l: board::Layout, from: float2, to: float2, now: f64) {
    board::update(b, now);
    board::press(b, l, from, now);
    board::drag(b, l, to);
    board::release(b, l, to, now);
}

fn show(b: board::Board&, what: const u8[:]) {
    let v .= rules::VARIANTS[b.variant];
    var played = str("-");
    if b.moving { played = str(drive::name(v, b.move.from), "x", drive::name(v, b.move.to)); }
    print(what, ": selected ", drive::name(v, b.selected), ", playing ", played, ", wrong ", drive::name(v, b.wrong));
}

fn main() {
    let l = panel::layout(1080.0, 2400.0, 10).board;
    let p, ok = rules::parse_fen("W:W32,41:B6,28", rules::INTERNATIONAL);
    assert(ok);
    var b = board::new(rules::INTERNATIONAL);

    board::set(b, p);
    board::press(b, l, at(l, 32, 0.0, 0.55), 0.0);
    board::release(b, l, at(l, 32, 0.0, 0.55), 0.0);
    show(b, "press half a square below 32, on a light square");
    board::set(b, p);
    board::press(b, l, at(l, 32, 0.0, 1.0), 0.0);
    show(b, "  a whole square below");

    board::set(b, p);
    drop(b, l, at(l, 32, 0.0, 0.0), at(l, 23, 0.6, 0.0), 1.0);
    show(b, "32 dropped 0.6 right of 23, on a light square");
    board::set(b, p);
    drop(b, l, at(l, 32, 0.0, 0.0), at(l, 23, 1.0, 0.0), 2.0);
    show(b, "  a whole square right");
    board::set(b, p);
    drop(b, l, at(l, 32, 0.0, 0.0), at(l, 23, 0.0, -0.6), 3.0);
    show(b, "  0.6 above 23");
    board::set(b, p);
    drop(b, l, at(l, 32, 0.0, 0.0), at(l, 24, 0.2, 0.0), 4.0);
    show(b, "  on 24, next to 23, a dark square");
}
