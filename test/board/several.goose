// Several pieces that can capture, tapped on the board as a game does. Under the
// majority rule (International, Brazilian) only the captures taking the most pieces are
// legal: every piece that has one may be selected and played, and after a mistake all of
// them pulse, never just one, with the pieces the selected one must take. A piece that could take, but fewer, is a mistake: its square
// flashes, and the pieces that take more pulse with the pieces they take, so a child sees
// why (rules::can_take_from tells it from a piece with no capture at all). In Russian any
// capture may be chosen. Each position's moves were checked with test/perft.py moves.
//
// - equal: c3 takes d4 and h4 takes g5, one each: both legal.
// - more: c3 takes d4 and f6, h2 only g3: only c3.
// - king and man: the king on a5 takes c7 (landing d8, e9, or f10), h2 takes g3.
// - king more: with e7 too, the king takes c7, e7, and g3; h2's one is no move.
// - shared stop: c3 and g3 both jump to e5 and on over f6 to g7, two each.
// - turned: the child on black against the computer, the board turned, i9 (seen lower
//   left) and c5 (middle right) each take one: the rings, the squares tapped, and the
//   moves agree. The pulse a mistake starts ends once a move is played: it used to run
//   on and ring the computer's capturers, white h8 seen lower left beside the child's
//   pieces (reported 2026-11-09).
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

// Where a piece is on the screen, by thirds: "lower left", "middle right".
fn seen(l: board::Layout, at: float2) -> u8[>..] {
    let fx = (at.x - l.inner.x) / l.inner.z;
    let fy = (at.y - l.inner.y) / l.inner.z;
    let row = if fy < 0.34 { "upper" } else if fy < 0.67 { "middle" } else { "lower" };
    let col = if fx < 0.34 { "left" } else if fx < 0.67 { "centre" } else { "right" };
    return str(row, " ", col);
}

// The game against the computer playing white, the board turned for the child on black
// (shell::game_layout), driven through the pointer: each ringed piece's square and where
// it is seen, which must be a piece with a legal capture, and each capture tapped.
fn turned(fen: const u8[:], taps: const u8[:][:]) {
    let V: u8 = rules::INTERNATIONAL;
    let v .= rules::VARIANTS[V];
    check::show(V, fen);
    var l = panel::layout(1280.0, 800.0, 10);
    l.board.flip = true;
    var g = gui::Gui {};
    gui::test_faces(g);
    var gm = game::new(V);
    var now = 0.0;
    for t in taps {
        game::start(gm, V, clock::NONE, rules::WHITE, game::MEDIUM, 40, 1);
        board::set(gm.b, check::position(V, fen));
        gm.turn = gm.b.pos.side;
        now += 10.0;
        drive::idle(gm, g, l, now);
        var at = 0;
        while at < t.len {
            var end = at;
            while end < t.len && t[end] != ' ' { end++; }
            drive::tap(gm, g, l, drive::at(l.board, t[at..end]), now);
            now += 0.1;
            let b .= gm.b;
            board::fill(b, l.board, now);
            var rings: u8[>..] = [];
            for i in b.pieces.len {
                let pc = b.pieces[i];
                guard pc.ring.x > 0.0 else { continue; }
                let c = float2 { pc.at.x, pc.at.y };
                let sq = board::hit(l.board, v, c);
                var legal = false;
                for m in b.moves { if m.from == sq { legal = true; } }
                let shown = if b.moving { b.before } else { b.pos };
                rings.append(if shown.pieces[rules::BLACK] & rules::bit(sq) != 0 { "black " } else { "white " });
                rings.append(drive::name(v, sq));
                rings.append(" (");
                rings.append(seen(l.board, c));
                rings.append(if legal { ", legal) " } else { ", no move) " });
            }
            var text: u8[>..] = [];
            if b.moving { rules::format_move(text, V, b.move); }
            var sel: u8[>..] = [];
            if b.selected >= 0 {
                sel.append(drive::name(v, b.selected));
                sel.append(" (");
                sel.append(seen(l.board, board::center(l.board, v, b.selected)));
                sel.append(")");
            } else { sel.append("-"); }
            print("  ", t[at..end], ": selected ", sel, ", wrong ", drive::name(v, b.wrong), ", pulsing ", rings,
                  ", playing ", if b.moving { text } else { "-" });
            now += 0.1;
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
    print("turned, the child on black: i9 takes h8, c5 takes d4, a9 can't move");
    turned("B:Wh8,d4,a1:Bi9,c5,a9", ["a9 i9 g7", "a9 c5 e3", "i9 g7", "c5 e3", "c5 i9 g7"]);
}
