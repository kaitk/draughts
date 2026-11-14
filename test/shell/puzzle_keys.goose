// A puzzle solved with the keys (shell/puzzle.goose), headless: the first arrow focuses
// the board, its cursor is put on 32 and on 21 as the arrows would walk it, and Enter
// on each plays 32x21, solving the puzzle; the frame after, next has the focus, so Enter
// (a gamepad's A) opens the next puzzle, whose board takes the focus back. The same puzzle solved with the pointer leaves
// no focus: on a touch screen or with a mouse nothing is ringed. Solved with the keys
// and the mouse moved before the next frame, the pointer leads and next isn't focused.
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

// Two one-move captures, as a file writes them.
fn set() -> u8[>..] {
    return str("variant international\n\n",
               "id 1\ntheme captures\nlevel 1\ngoal take 1\nposition W:W32,47:B27,5\nline 32x21\nsource own\n\n",
               "id 2\ntheme captures\nlevel 1\ngoal take 1\nposition W:W33,47:B28,5\nline 33x22\nsource own\n");
}

fn sq(n: i64) -> u8[>..] {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    return drive::name(v, v.bit_of[n]);
}

// Enter on square n: the board's cursor put there (the grid's cell, row 0 at the top),
// then Enter.
fn enter_on(sh: shell::Shell&, g: gui::Gui&, n: i64, now: f64) {
    let l = sh.out.layout;
    let p = drive::at(l, sq(n));
    let cx = floor((p.x - l.inner.x) / l.inner.w) as i64;
    let cr = floor((p.y - l.inner.y) / l.inner.w) as i64;
    g.cell = cr * l.n + cx;
    drive::key(sh, g, gui::STEP_NONE, true, now);
}

fn focus(g: gui::Gui&) -> const u8[:] {
    if g.focus == panel::EYE_ID { return "next"; }
    if g.focus == panel::BOARD_ID { return "the board"; }
    return if g.focus == 0 { "none" } else { "another control" };
}

fn solved(sh: shell::Shell&) -> bool { sh.puzzle.state == puzzle::SOLVED }

fn main() {
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    puzzles::all.list.clear();
    var err: u8[>..] = [];
    print("read: ", puzzles::parse(set(), puzzles::all, err), err);

    // With the keys.
    shell::play_puzzle(sh, 0, 0.0);
    drive::idle(sh, g, 1.0);
    drive::key(sh, g, gui::STEP_DOWN, false, 1.1);
    print("the first arrow: focus on ", focus(g));
    enter_on(sh, g, 32, 1.2);
    enter_on(sh, g, 21, 1.3);
    print("32x21 by Enter: solved ", solved(sh), ", focus on ", focus(g));
    drive::idle(sh, g, 1.4);
    drive::idle(sh, g, 1.5);
    print("  the frames after: focus on ", focus(g));
    drive::idle(sh, g, 3.0);
    drive::key(sh, g, gui::STEP_NONE, true, 3.1);
    drive::idle(sh, g, 4.0);
    drive::idle(sh, g, 4.1);
    print("  Enter: the puzzle of id ", puzzles::all.list[sh.puzzle.index].id, ", focus on ", focus(g));

    // With the pointer.
    shell::play_puzzle(sh, 0, 5.0);
    drive::idle(sh, g, 6.0);
    drive::tap(sh, g, drive::at(sh.out.layout, sq(32)), 6.1);
    drive::tap(sh, g, drive::at(sh.out.layout, sq(21)), 6.2);
    drive::idle(sh, g, 6.5);
    print("32x21 by taps: solved ", solved(sh), ", focus on ", focus(g));

    // With the keys, the mouse moved before the next frame.
    shell::play_puzzle(sh, 0, 8.0);
    drive::idle(sh, g, 9.0);
    drive::key(sh, g, gui::STEP_DOWN, false, 9.1);
    enter_on(sh, g, 32, 9.2);
    enter_on(sh, g, 21, 9.3);
    drive::frame(sh, g, float2 { 10.0, 10.0 }, false, false, false, 9.4);
    drive::idle(sh, g, 9.5);
    print("32x21 by Enter, then the mouse: solved ", solved(sh), ", focus on ", focus(g));
}
