// A capture of many jumps tapped stop by stop, as in a game (board::follow): a tap on
// the next stop of the selected piece's captures is kept and ringed, whatever the hints,
// and narrows the targets shown with hints on moves; once only one capture goes on that
// way, or a tap lands on a capture's last square, the capture is played. A tap off every
// way is a mistake and forgets the stops; selecting the piece again does too, and a drag
// dropped on a stop keeps it. The king of puzzle 14 (W:W46,K47:B5,12,22,38) takes 38, 22,
// and 12 by 33 and 17, ending on 8 or 3; a man of puzzle 4 takes two by 28 alone.
// Made by hand (`by_hand`, a puzzle's), a stop waits even when one way goes on from it,
// and a last square two captures reach (W:WK9:B18,28,29,32, the king to 15 by 22 and 33
// or by 27 and 38, taking 28 or 32) plays neither, nor is it a mistake: the piece stays
// selected for its stops. In a game the first of the two is played.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import strings from "../../strings";
import game from "../../game";
import ai from "../../ai";
import shell from "../../shell";
import puzzles from "../../puzzles";
import drive from "../drive";

// The name of square number n.
fn sq(n: i64) -> u8[>..] {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    return drive::name(v, v.bit_of[n]);
}

// The name of a square given as its bit.
fn named(bit: i64) -> u8[>..] { drive::name(rules::VARIANTS[rules::INTERNATIONAL], bit) }

fn tap(b: board::Board&, l: board::Layout, n: i64, now: f64) {
    let p = drive::at(l, sq(n));
    board::update(b, now);
    board::press(b, l, p, now);
    board::release(b, l, p, now);
}

fn show(b: board::Board&, l: board::Layout, what: const u8[:], now: f64) {
    let v .= rules::VARIANTS[b.variant];
    board::fill(b, l, now);
    print(what, ": selected ", drive::name(v, b.selected), ", stops ", b.steps.len, ", ringed ",
          drive::marked(v, b.marks.via), "targets ", drive::marked(v, b.marks.target), "wrong ", drive::name(v, b.wrong),
          ", moving ", b.moving);
}

fn main() {
    let l = panel::layout(1280.0, 800.0, 10).board;
    let king, ok = rules::parse_fen("W:W46,K47:B5,12,22,38", rules::INTERNATIONAL);
    assert(ok);
    var b = board::new(rules::INTERNATIONAL);
    board::set(b, king);
    print("47 is ", sq(47), ", 33 ", sq(33), ", 17 ", sq(17), ", 8 ", sq(8), ", 3 ", sq(3), ", 28 ", sq(28));
    tap(b, l, 47, 0.0);
    tap(b, l, 33, 0.1);
    show(b, l, "47, then 33", 0.1);
    b.hints = board::MOVES;
    show(b, l, "  with hints on moves", 0.1);
    tap(b, l, 17, 0.2);
    show(b, l, "then 17", 0.2);
    tap(b, l, 28, 0.3);                     // off the way
    show(b, l, "then 28", 0.3);
    tap(b, l, 33, 2.0);
    tap(b, l, 47, 2.1);                     // the piece again
    show(b, l, "33, then 47 again", 2.1);
    tap(b, l, 33, 2.2);
    tap(b, l, 17, 2.3);
    tap(b, l, 8, 2.4);
    show(b, l, "33, 17, 8", 2.4);
    board::update(b, 10.0);
    print("  ", rules::fen(b.pos));

    // A drag dropped on a stop keeps it; the last square tapped then plays the capture.
    board::set(b, king);
    b.hints = board::MISTAKES;
    board::press(b, l, drive::at(l, sq(47)), 0.0);
    board::drag(b, l, drive::at(l, sq(47)) + float2 { 40.0, -40.0 });
    board::release(b, l, drive::at(l, sq(33)), 0.1);
    show(b, l, "47 dropped on 33", 0.1);
    tap(b, l, 3, 0.2);
    show(b, l, "then 3", 0.2);
    print("  the way ", b.move.path.len - 1, " jumps to ", named(b.move.to));

    // One capture goes by 28: tapping it plays the capture.
    let man, ok2 = rules::parse_fen("W:W37,39,43,46:B23,32,34", rules::INTERNATIONAL);
    assert(ok2);
    board::set(b, man);
    tap(b, l, 37, 0.0);
    tap(b, l, 28, 0.1);
    show(b, l, "37, then 28", 0.1);
    print("  to ", named(b.move.to), ", taking ", popcount(b.move.captured));

    // By hand: 28 waits, and the man is drawn there; 19 then plays the rest.
    board::set(b, man);
    b.by_hand = true;
    tap(b, l, 37, 1.0);
    tap(b, l, 28, 1.1);
    show(b, l, "by hand, 37, then 28", 1.1);
    tap(b, l, 19, 1.2);
    show(b, l, "then 19", 1.2);
    print("  to ", named(b.move.to), ", taking ", popcount(b.move.captured), ", shown from ", named(b.move.path[b.skip]));

    // Two captures end on 15: by hand, a tap there waits for the stops; 27, 38, 15 then
    // plays the way by 27. In a game, the tap on 15 plays the first.
    let two, ok3 = rules::parse_fen("W:WK9:B18,28,29,32", rules::INTERNATIONAL);
    assert(ok3);
    board::set(b, two);
    tap(b, l, 9, 2.0);
    tap(b, l, 15, 2.1);
    show(b, l, "by hand, two ways: 9, then 15", 2.1);
    tap(b, l, 27, 2.2);
    tap(b, l, 38, 2.3);
    show(b, l, "then 27, 38", 2.3);
    tap(b, l, 15, 2.4);
    show(b, l, "then 15", 2.4);
    print("  by ", named(b.move.path[1]), ", taking ", popcount(b.move.captured));
    board::set(b, two);
    b.by_hand = false;
    tap(b, l, 9, 3.0);
    tap(b, l, 15, 3.1);
    show(b, l, "in a game: 9, then 15", 3.1);
    print("  by ", named(b.move.path[1]));
}
