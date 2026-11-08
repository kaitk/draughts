// Puzzles and captures of many jumps (shell/puzzle.goose, board::follow): tapped stop
// by stop, a right capture costs no star, as tapping its last square doesn't. Puzzle
// 14's king takes three by 33 and 17, ending on 8 or 3; a tap off the way (28) is a
// miss. Puzzle 10 has two doubles: tapping 29, the first stop of the wrong one, plays it,
// a miss, and it slides back; 27 then plays the right one. Puzzles never show a selected
// piece's targets, even with move hints on in settings and in the first tier: puzzle 4's
// man on 37 is selected with nothing marked, and 28 plays its double.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import game from "../../game";
import strings from "../../strings";
import ai from "../../ai";
import shell from "../../shell";
import puzzles from "../../puzzles";
import drive from "../drive";

let STATES = ["playing", "answer", "back", "solved"];

// The name of square number n.
fn sq(n: i64) -> u8[>..] {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    return drive::name(v, v.bit_of[n]);
}

// The name of a square given as its bit.
fn named(bit: i64) -> u8[>..] { drive::name(rules::VARIANTS[rules::INTERNATIONAL], bit) }

fn tap(sh: shell::Shell&, g: gui::Gui&, n: i64, now: f64) { drive::tap(sh, g, drive::at(sh.layout, sq(n)), now); }

fn show(sh: shell::Shell&, what: const u8[:], now: f64) {
    let pl .= sh.puzzle;
    let v .= rules::VARIANTS[pl.b.variant];
    let b .= shell::fill(sh, now);
    print(what, ": puzzle ", puzzle::current(pl).id, " tier ", puzzle::current(pl).tier, ", ", STATES[pl.state],
          ", misses ", pl.misses, ", stars ", puzzle::stars(pl), ", selected ", drive::name(v, b.selected), ", ringed ",
          drive::marked(v, b.marks.via), "targets ", drive::marked(v, b.marks.target), "wrong ", drive::name(v, b.wrong));
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    sh.prefs.hints = board::MOVES;

    shell::play_puzzle(sh, 13);
    drive::idle(sh, g, 0.0);
    tap(sh, g, 47, 0.1);
    tap(sh, g, 33, 0.2);
    tap(sh, g, 17, 0.3);
    show(sh, "47, 33, 17", 0.4);
    tap(sh, g, 8, 0.5);
    show(sh, "then 8", 0.6);
    print("  ", rules::fen(sh.puzzle.b.pos), ", kept stars ", sh.prefs.stars[14]);

    shell::play_puzzle(sh, 13);
    drive::idle(sh, g, 10.0);
    tap(sh, g, 47, 10.1);
    tap(sh, g, 33, 10.2);
    tap(sh, g, 28, 10.3);
    show(sh, "again: 47, 33, 28", 10.4);

    shell::play_puzzle(sh, 9);
    drive::idle(sh, g, 20.0);
    tap(sh, g, 38, 20.1);
    tap(sh, g, 29, 20.2);
    show(sh, "38, then 29", 20.3);
    print("  playing ", named(sh.puzzle.b.move.from), "x", named(sh.puzzle.b.move.to));
    drive::idle(sh, g, 21.0);
    drive::idle(sh, g, 21.5);
    drive::idle(sh, g, 22.5);
    show(sh, "  slid back", 22.5);
    tap(sh, g, 38, 23.0);
    tap(sh, g, 27, 23.1);
    show(sh, "38, then 27", 23.2);
    print("  playing ", named(sh.puzzle.b.move.from), "x", named(sh.puzzle.b.move.to), ", kept stars ", sh.prefs.stars[10]);

    shell::play_puzzle(sh, 3);
    drive::idle(sh, g, 30.0);
    tap(sh, g, 37, 30.1);
    show(sh, "37 selected, hints on moves in settings", 30.2);
    tap(sh, g, 28, 30.3);
    show(sh, "then 28", 30.4);
}
