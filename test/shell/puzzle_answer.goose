// A wrong move's answer (shell/puzzle.goose, puzzles::answer), headless, driven through
// the pointer. A position from International's Captures puzzle 32, its man on 39, has
// two doubles: 27x38x29, which lands safe, and 39x28x37, which 21x32x41 takes back. The
// second is wrong: a miss as it lands, the red ring on its square; black's double back
// plays 0.4 s after, as a reply does, holds 0.8 s, and is gone at once, and the wrong
// move slides back, "try again" showing 2 s from then. A wrong move nothing answers, the
// shot's 48-42 (puzzles' goals test), slides back 0.35 s after it lands as before, with
// no answer shown. A safe move's wrong 32-28 (once the daily library's 1543, dropped for
// this line's length) is answered by a shot, which plays on move by move until what it
// wins is taken, then is gone; played again, a tap on the board partway ends the line
// at once.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import model3d from "../../src/model3d";
import gui from "../../src/gui";
import game from "../../src/game";
import strings from "../../strings";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

let STATES = ["playing", "answer", "back", "solved", "show", "shown"];

// The two puzzles, as a file writes them.
fn set() -> u8[>..] {
    return str("variant international\n\n",
               "id 1\ntheme captures\nlevel 1\ngoal take 2\nposition W:W25,27,39,43,44,50:B3,4,21,26,32,33\n",
               "line 27x38x29\nsource own, Captures 32 as it was\n\n",
               "id 2\ntheme shots\nlevel 1\ngoal take 2\nposition W:W33,38,43,45,47,48:B3,11,21,23,24,29\n",
               "line 33-28 23x32 38x27x16x7\nsource own, the shot of the goals test\n\n",
               "id 3\ntheme safe-move\nlevel 3\ngoal safe\n",
               "position W:W17,19,21,22,23,24,27,29,32,33,39,40,42,47,48:B1,2,3,6,8,10,11,12,13,14,15,16,18,20,26\n",
               "line 42-37\nsource the daily library's 1543\n");
}

fn show(sh: shell::Shell&, what: const u8[:]) {
    let pl .= sh.puzzle;
    let v .= rules::VARIANTS[pl.b.variant];
    var text: u8[>..] = [];
    format(text, what, ": ", rules::fen(pl.b.pos), ", ", STATES[pl.state], ", misses ", pl.misses, ", moving ",
           pl.b.moving);
    if pl.b.moving {
        format(text, " ", v.number_of[pl.b.move.from], if pl.b.move.captured != 0 { "x" } else { "-" },
               v.number_of[pl.b.move.to], if pl.b.back { " backward" } else { "" });
    }
    if pl.b.wrong >= 0 { format(text, ", red ring on ", v.number_of[pl.b.wrong]); }
    print(text);
}

fn tap(sh: shell::Shell&, g: gui::Gui&, n: i64, now: f64) {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    drive::tap(sh, g, drive::at(sh.out.layout, drive::name(v, v.bit_of[n])), now);
}

fn main() {
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    puzzles::all.list.clear();
    var err: u8[>..] = [];
    print("read: ", puzzles::parse(set(), puzzles::all, err), err);
    let start = rules::fen(puzzles::all.list[0].start);

    // The double taken back.
    shell::play_puzzle(sh, 0, 0.0);
    drive::idle(sh, g, 1.0);
    show(sh, "Captures 32 as it was");
    tap(sh, g, 39, 1.1);
    tap(sh, g, 37, 1.2);
    show(sh, "39x28x37");
    drive::idle(sh, g, 1.5);
    show(sh, "  at 1.5 s, the move showing");
    drive::idle(sh, g, 1.9);
    show(sh, "  at 1.9 s, landed at 1.78 s");
    drive::idle(sh, g, 2.3);
    show(sh, "  at 2.3 s, the answer, due 0.4 s after the landing");
    print("  animating while it holds: ", shell::animating(sh, g, 2.8));
    drive::idle(sh, g, 2.8);
    show(sh, "  at 2.8 s");
    drive::idle(sh, g, 3.3);
    show(sh, "  at 3.3 s, the answer landed at 2.88 s, held");
    drive::idle(sh, g, 3.6);
    show(sh, "  at 3.6 s, still held");
    drive::idle(sh, g, 3.9);
    show(sh, "  at 3.9 s, the answer gone, due 0.8 s after its landing, the move sliding back");
    drive::idle(sh, g, 4.5);
    show(sh, "  at 4.5 s, back");
    drive::idle(sh, g, 5.5);
    print("  back at the start: ", rules::fen(sh.puzzle.b.pos) == start, ", animating at 5.8 s ",
          shell::animating(sh, g, 5.8), ", at 6.0 s ", shell::animating(sh, g, 6.0));
    drive::idle(sh, g, 7.0);
    tap(sh, g, 27, 7.1);
    tap(sh, g, 29, 7.2);
    show(sh, "then 27x38x29");

    // A wrong move with no answer.
    shell::play_puzzle(sh, 1, 10.0);
    drive::idle(sh, g, 11.0);
    show(sh, "the shot");
    tap(sh, g, 48, 11.1);
    tap(sh, g, 42, 11.2);
    show(sh, "48-42");
    drive::idle(sh, g, 11.5);
    show(sh, "  at 11.5 s, landed at 11.4 s");
    drive::idle(sh, g, 11.6);
    show(sh, "  at 11.6 s");
    drive::idle(sh, g, 12.0);
    show(sh, "  at 12.0 s, sliding back, due 0.35 s after the landing");

    // A safe move's wrong move, and the shot it allows, each move as it starts.
    shell::play_puzzle(sh, 2, 20.0);
    drive::idle(sh, g, 21.0);
    let safe_start = rules::fen(sh.puzzle.b.pos);
    tap(sh, g, 32, 21.1);
    tap(sh, g, 28, 21.2);
    show(sh, "32-28");
    var t = 21.2;
    var was = sh.puzzle.b.since;
    while t < 60.0 && sh.puzzle.state != 0 {
        t += 0.05;
        drive::idle(sh, g, t);
        if sh.puzzle.b.since != was && sh.puzzle.b.moving {
            was = sh.puzzle.b.since;
            show(sh, "  then");
        }
    }
    print("  back at the start: ", rules::fen(sh.puzzle.b.pos) == safe_start, ", misses ", sh.puzzle.misses,
          ", done by ", t < 60.0);

    // Again, a tap on an empty square partway through the line.
    shell::play_puzzle(sh, 2, 70.0);
    drive::idle(sh, g, 71.0);
    tap(sh, g, 32, 71.1);
    tap(sh, g, 28, 71.2);
    t = 71.2;
    while t < 74.0 && sh.puzzle.line.len < 3 {
        t += 0.05;
        drive::idle(sh, g, t);
    }
    show(sh, "  played again, three moves of the line in");
    tap(sh, g, 25, t + 0.05);
    show(sh, "  a tap on 25");
    drive::idle(sh, g, t + 1.0);
    print("  back at the start: ", rules::fen(sh.puzzle.b.pos) == safe_start, ", misses ", sh.puzzle.misses);
}
