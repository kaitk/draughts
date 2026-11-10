// Puzzles and captures of many jumps (shell/puzzle.goose, board::follow): a capture is
// made by hand. A tap or a drop on a stop leaves the piece waiting there, drawn on it,
// and never plays the rest of the way; a tap or a drop on the last square plays the
// capture when one way alone goes there. A right capture made stop by stop costs no
// star, as one dropped on its last square doesn't. Left partway, it is no move: next,
// dim until solved, wakes while the piece waits, and pressed then the piece slides back
// to its square with the red ring on the stop, and a star goes out; next does nothing
// before. Puzzle 14's king takes three by 33 and 17, ending on 8 or 3; a tap off the
// way (28) is a miss. Puzzle 10 has two doubles, 38 by 29 to 20 and by 27 to 16; the
// first ends where it is taken back: a miss, and after the answer has shown, it slides back. Puzzle 31's man takes
// two by 17 to 6; dropped on 17, the frame the finger lifts on asks for the one after,
// which shows next awake, the man it jumped still there. Puzzles never show a selected
// piece's targets, even with move hints on in settings and in Learn.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import game from "../../src/game";
import strings from "../../strings";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

let STATES = ["playing", "answer", "back", "solved", "show", "shown", "unshow"];

// The name of square number n.
fn sq(n: i64) -> u8[>..] {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    return drive::name(v, v.bit_of[n]);
}

// The name of a square given as its bit.
fn named(bit: i64) -> u8[>..] { drive::name(rules::VARIANTS[rules::INTERNATIONAL], bit) }

fn tap(sh: shell::Shell&, g: gui::Gui&, n: i64, now: f64) { drive::tap(sh, g, drive::at(sh.out.layout, sq(n)), now); }

// A drag from square number `from` dropped on `to`, frame by frame as a finger makes it,
// up to the frame the finger lifts.
fn drop(sh: shell::Shell&, g: gui::Gui&, from: i64, to: i64, now: f64) {
    let a = drive::at(sh.out.layout, sq(from));
    let c = drive::at(sh.out.layout, sq(to));
    drive::frame(sh, g, a, true, true, false, now);
    drive::frame(sh, g, a + (c - a) * 0.5, true, false, false, now + 0.02);
    drive::frame(sh, g, c, true, false, false, now + 0.04);
    drive::frame(sh, g, c, false, false, true, now + 0.06);
}

// The same, then a frame with nothing happening.
fn drag(sh: shell::Shell&, g: gui::Gui&, from: i64, to: i64, now: f64) {
    drop(sh, g, from, to, now);
    drive::idle(sh, g, now + 0.08);
}

// Next, the right panel's tile: whether it is drawn awake (not dim) and lit.
fn next(g: gui::Gui&) -> u8[>..] {
    let r = drive::rect(g, 3);
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.rect == r else { continue; }
        return str(if q.color.w == 1.0 { "awake" } else { "dim" }, if q.extra.y == gui::CHOSEN { " lit" } else { "" });
    }
    return str("none");
}

// Where the selected piece is drawn, lifted and glowing: its square.
fn drawn(sh: shell::Shell&, b: board::Board&) -> u8[>..] {
    let v .= rules::VARIANTS[b.variant];
    for p in b.pieces {
        if p.look.z == 1.0 { return drive::name(v, board::hit(sh.out.layout, v, float2 { p.at.x, p.at.y })); }
    }
    return str("-");
}

fn show(sh: shell::Shell&, g: gui::Gui&, what: const u8[:], now: f64) {
    let pl .= sh.puzzle;
    let v .= rules::VARIANTS[pl.b.variant];
    let b .= shell::fill(sh, now);
    print(what, ": puzzle ", puzzle::current(pl).id, " ", puzzles::THEME_NAMES[puzzle::current(pl).theme], " ", puzzle::current(pl).level, ", ", STATES[pl.state],
          ", misses ", pl.misses, ", stars ", puzzle::stars(pl), ", selected ", drive::name(v, b.selected), " drawn on ",
          drawn(sh, b), ", waits on ", drive::name(v, board::waiting(b)), ", ringed ", drive::marked(v, b.marks.via),
          "targets ", drive::marked(v, b.marks.target), "wrong ", drive::name(v, b.wrong), ", next ", next(g));
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    sh.prefs.hints = board::MOVES;
    shell::apply_prefs(sh);

    // Tapped stop by stop: the king waits on each stop, and the last solves.
    shell::play_puzzle(sh, 8);
    drive::idle(sh, g, 0.0);
    tap(sh, g, 47, 0.1);
    tap(sh, g, 33, 0.2);
    show(sh, g, "47, 33", 0.3);
    tap(sh, g, 17, 0.3);
    show(sh, g, "then 17", 0.4);
    tap(sh, g, 8, 0.5);
    print("  the way shown from ", named(sh.puzzle.b.move.path[sh.puzzle.b.skip]), ", landing ",
          sh.puzzle.b.since + board::duration(sh.puzzle.b.move) - 0.5, " s after the tap");
    drive::idle(sh, g, 2.0);
    show(sh, g, "then 8", 2.0);
    print("  ", rules::fen(sh.puzzle.b.pos), ", kept stars ", sh.prefs.stars[rules::INTERNATIONAL][14]);

    shell::play_puzzle(sh, 8, 10.0);
    drive::idle(sh, g, 10.0);
    tap(sh, g, 47, 10.1);
    tap(sh, g, 33, 10.2);
    tap(sh, g, 28, 10.3);
    show(sh, g, "again: 47, 33, 28", 10.4);

    // The first stop of the wrong double waits; its end plays it, a miss. Then the right
    // one dragged stop by stop solves it.
    shell::play_puzzle(sh, 6, 20.0);
    drive::idle(sh, g, 20.0);
    tap(sh, g, 38, 20.1);
    tap(sh, g, 29, 20.2);
    show(sh, g, "38, then 29", 20.3);
    tap(sh, g, 20, 20.3);
    print("  then 20: ", STATES[sh.puzzle.state], ", playing ", named(sh.puzzle.b.move.from), "x",
          named(sh.puzzle.b.move.to));
    // Taken back by 21x32: the answer shows, then both slide back.
    for t in [21.0, 21.5, 22.0, 23.0, 23.5, 24.0, 24.5] { drive::idle(sh, g, t); }
    show(sh, g, "  slid back", 24.5);
    drag(sh, g, 38, 27, 25.5);
    show(sh, g, "38 dropped on 27", 25.6);
    drag(sh, g, 27, 16, 25.7);
    show(sh, g, "then 27 dropped on 16", 25.8);
    print("  playing ", named(sh.puzzle.b.move.from), "x", named(sh.puzzle.b.move.to), ", kept stars ",
          sh.prefs.stars[rules::INTERNATIONAL][10]);

    // Dropped on the capture's last square: one way goes there, so it is played.
    shell::play_puzzle(sh, 12, 30.0);
    drive::idle(sh, g, 30.0);
    tap(sh, g, 26, 30.1);
    show(sh, g, "26 selected, hints on moves in settings", 30.2);
    drag(sh, g, 26, 6, 30.3);
    show(sh, g, "26 dropped on 6", 30.4);

    // Left partway: next before a move does nothing; while the man waits on 17 next
    // wakes, and pressed it is a miss, the man sliding back to 26.
    shell::play_puzzle(sh, 12, 40.0);
    drive::idle(sh, g, 40.0);
    show(sh, g, "puzzle 31 again", 40.0);
    drive::tap(sh, g, drive::tile(g, 3), 40.1);
    show(sh, g, "next, nothing moved", 40.2);
    drag(sh, g, 26, 17, 40.3);
    show(sh, g, "26 dropped on 17", 40.4);
    drive::tap(sh, g, drive::tile(g, 3), 40.5);
    show(sh, g, "next", 40.6);
    print("  sliding back ", sh.puzzle.b.moving && sh.puzzle.b.back, ", ", rules::fen(sh.puzzle.b.pos), ", try again ",
          shell::animating(sh, g, 40.6));
    drive::idle(sh, g, 41.0);
    drive::idle(sh, g, 43.0);
    show(sh, g, "  slid back", 43.0);
    tap(sh, g, 26, 43.1);
    tap(sh, g, 17, 43.2);
    tap(sh, g, 6, 43.3);
    drive::idle(sh, g, 45.0);
    show(sh, g, "26, 17, 6", 45.0);
    print("  kept stars ", sh.prefs.stars[rules::INTERNATIONAL][31]);

    // A drop is the last event a finger makes, so the app draws the frame it lands on and
    // then waits: that frame or one it asks for must show next awake. The man jumped (21)
    // stays on the board while the man waits.
    shell::play_puzzle(sh, 12, 50.0);
    drive::idle(sh, g, 50.0);
    drop(sh, g, 26, 17, 50.1);
    let b .= shell::fill(sh, 50.2);
    var black = 0;
    for p in b.pieces { if p.look.x == 1.0 { black++; } }
    print("dropped on 17, as the app sees it: next ", next(g), ", another frame asked ",
          g.acted || shell::animating(sh, g, 50.2), ", black men drawn ", black, ", ", rules::fen(b.pos));
    drive::idle(sh, g, 50.2);
    show(sh, g, "  the frame after", 50.2);
}
