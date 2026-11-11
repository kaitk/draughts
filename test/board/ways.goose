// A capture tapped stop by stop may take any of its ways, not only the one the move list
// keeps (rules::ways, board::follow; 2026-11-11, issue 1: a king's other way cost a
// puzzle's stars). The Russian king on c1 takes b2, d2, b4, and d4 round either way and
// is back on c1, one move whose kept way goes by a3 first; tapped by e3, c5, and a3, the
// move plays, shown along the way tapped. Its last square, c1, which two ways reach, is
// played by neither. A tap on the selected piece puts it down, a drag from it still
// plays; and a tap on a stop shows the piece hopping there over the HOP, then resting.
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

let V = rules::RUSSIAN;

fn name(bit: i64) -> u8[>..] { drive::name(rules::VARIANTS[V], bit) }

fn tap(b: board::Board&, l: board::Layout, at: const u8[:], now: f64) {
    let p = drive::at(l, at);
    board::update(b, now);
    board::press(b, l, p, now);
    board::release(b, l, p, now);
}

// Where the selected piece is drawn, lifted and glowing, as the square under it ("-"
// between squares), and how high.
fn drawn(b: board::Board&, l: board::Layout, now: f64) -> u8[>..] {
    board::fill(b, l, now);
    for p in b.pieces {
        if p.look.z == 1.0 {
            let sq = board::hit(l, rules::VARIANTS[V], float2 { p.at.x, p.at.y });
            return str(if sq >= 0 { name(sq) } else { str("-") }, if p.at.w > 1.2 * 0.01 * l.board.z { " in the air" } else { "" });
        }
    }
    return str("none");
}

fn way(m: rules::Move&) -> u8[>..] {
    var t: u8[>..] = [];
    for s, i in m.path { format(t, if i > 0 { ":" } else { "" }, name(s)); }
    return t;
}

fn main() {
    let l = panel::layout(1280.0, 800.0, 8).board;
    let p, ok = rules::parse_fen("W:WKc1:Bb2,d2,b4,d4", V);
    assert(ok);
    var b = board::new(V);
    board::set(b, p);
    var w: rules::Moves = [];
    rules::ways(p, b.moves[0].from, w);
    print("the move kept: ", way(b.moves[0]), ", ways: ", w.len);

    tap(b, l, "c1", 0.0);
    tap(b, l, "e3", 1.0);
    print("c1, then e3: waits on ", name(board::waiting(b)), ", wrong ", name(b.wrong));
    tap(b, l, "c5", 2.0);
    tap(b, l, "a3", 3.0);
    tap(b, l, "c1", 4.0);
    print("then c5, a3, c1: playing ", b.moving, ", along ", way(b.move), ", history ", b.history.len);

    board::set(b, p);
    tap(b, l, "c1", 10.0);
    tap(b, l, "c1", 11.0);
    print("c1 twice, two ways end there: selected ", name(b.selected), ", waits on ", name(board::waiting(b)),
          ", playing ", b.moving, ", wrong ", name(b.wrong));

    // A tap on the selected piece puts it down; a drag from it plays.
    let start = rules::start(V);
    board::set(b, start);
    tap(b, l, "c3", 20.0);
    print("c3: selected ", name(b.selected));
    tap(b, l, "c3", 21.0);
    print("c3 again: selected ", name(b.selected), ", wrong ", name(b.wrong));
    tap(b, l, "c3", 22.0);
    board::press(b, l, drive::at(l, "c3"), 23.0);
    board::drag(b, l, drive::at(l, "c3") + float2 { 40.0, -40.0 });
    board::drag(b, l, drive::at(l, "d4"));
    board::release(b, l, drive::at(l, "d4"), 23.1);
    print("c3 selected, pressed and dragged to d4: playing ", b.moving, ", ", name(b.move.from), "-", name(b.move.to));

    // The hop to a stop: halfway in the air between the squares, then on the stop at rest.
    board::set(b, p);
    tap(b, l, "c1", 30.0);
    tap(b, l, "a3", 31.0);
    print("c1, then a3: drawn ", drawn(b, l, 31.1), " at 0.1 s, animating ", board::animating(b, 31.1), "; ",
          drawn(b, l, 31.3), " at 0.3 s, ended and at rest ", board::update(b, 31.3) && !board::animating(b, 31.3));
}
