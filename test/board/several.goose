// Several pieces that can capture, tapped on the board as a game does. Under the
// majority rule (International, Brazilian) only the captures taking the most pieces are
// legal: every piece that has one may be selected and played, and after a mistake all of
// them pulse, never just one. A piece that could take, but fewer, is a mistake: its square
// flashes, and the pieces that take more pulse with the pieces they take, so a child sees
// why (rules::can_take_from tells it from a piece with no capture at all). In Russian any
// capture may be chosen. Each position's moves were checked with test/perft.py moves.
//
// - equal: c3 takes d4 and h4 takes g5, one each: both legal.
// - more: c3 takes d4 and f6, h2 only g3: only c3.
// - king and man: the king on a5 takes c7 (landing d8, e9, or f10), h2 takes g3.
// - king more: with e7 too, the king takes c7, e7, and g3; h2's one is no move.
// - shared stop: c3 and g3 both jump to e5 and on over f6 to g7, two each.
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
import check from "../";
import drive from "../drive";

fn tap(b: board::Board&, l: board::Layout, text: const u8[:], now: f64) {
    let p = drive::at(l, text);
    board::update(b, now);
    board::press(b, l, p, now);
    board::release(b, l, p, now);
}

// The squares of the pieces drawn with the must-capture ring, in board order.
fn ringed(b: board::Board&, l: board::Layout) -> u8[>..] {
    let v .= rules::VARIANTS[b.variant];
    var text: u8[>..] = [];
    for i in b.pieces.len {
        let pc = b.pieces[i];
        guard pc.ring.x > 0.0 else { continue; }
        text.append(drive::name(v, board::hit(l, v, float2 { pc.at.x, pc.at.y })));
        text.append(" ");
    }
    return text;
}

fn show(b: board::Board&, l: board::Layout, what: const u8[:], now: f64) {
    let v .= rules::VARIANTS[b.variant];
    board::fill(b, l, now);
    var text: u8[>..] = [];
    if b.moving { rules::format_move(text, b.variant, b.move); }
    print("  ", what, ": selected ", drive::name(v, b.selected), ", wrong ", drive::name(v, b.wrong), ", pulsing ",
          ringed(b, l), ", playing ", if b.moving { text } else { "-" });
}

// Shows fen's moves, then, from fen each time, each line of taps: squares apart by spaces,
// "c3 e5" a piece and where it goes, with what each tap leaves on the board.
fn try(variant: u8, fen: const u8[:], taps: const u8[:][:]) {
    check::show(variant, fen);
    let n = rules::VARIANTS[variant].size;
    let l = panel::layout(1280.0, 800.0, n).board;
    var b = board::new(variant);
    let p = check::position(variant, fen);
    var now = 0.0;
    for t in taps {
        board::show(b, p);
        b.pulse_end = 0.0;
        now += 10.0;
        var at = 0;
        while at < t.len {
            var end = at;
            while end < t.len && t[end] != ' ' { end++; }
            tap(b, l, t[at..end], now);
            show(b, l, t[at..end], now + 0.1);
            now += 0.2;
            at = end + 1;
        }
    }
}

fn main() {
    let I: u8 = rules::INTERNATIONAL;
    print("equal");
    try(I, "W:Wc3,h4:Bd4,g5", ["c3 e5", "h4 f6", "c3 c5"]);
    print("more");
    try(I, "W:Wc3,h2:Bd4,f6,g3", ["c3 g7", "h2 f4"]);
    print("king and man");
    try(I, "W:Wh2,Ka5:Bg3,c7", ["a5 e9", "h2 f4", "h2 h4"]);
    print("king more");
    try(I, "W:Wh2,Ka5:Bg3,c7,e7", ["h2", "a5 d8 h4 e1"]);
    print("shared stop");
    try(I, "W:Wc3,g3:Bd4,f4,f6", ["c3 e5 g7", "g3 g7", "e5"]);
    print("brazilian, more");
    try(rules::BRAZILIAN, "W:Wc3,h2:Bd4,f6,g3", ["h2", "c3 g7"]);
    print("russian, more");
    try(rules::RUSSIAN, "W:Wc3,h2:Bd4,f6,g3", ["h2 f4", "c3 g7", "a3"]);
}
