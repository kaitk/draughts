// The board played with the keys (board::keys, task 072), headless through the game's
// frames: the board is one control to the keys' focus, a grid of its squares, and the
// screen's first choice, so the first arrow puts its cursor on the side to move's movable
// piece nearest the bottom middle; the arrows move the cursor a square at a time, light
// squares too; Enter on a dark square is a tap there, so it chooses a piece and then its
// target, and a piece that can't move while another must capture is a mistake as a tap
// is; Enter on a light square does nothing; with a piece chosen, the square under the
// cursor is what the lookout would show (Board.over). An arrow past the board's edge
// leaves it for the nearest control that way, and an arrow back comes in on the near
// edge, in line. Tab steps through the groups (the way out, the board, the play panel)
// and back to the cell the cursor had. On the turned board (black at the bottom) the
// arrows go as the screen shows it. On the computer's turn the cursor moves but Enter
// plays nothing. Escape with a piece chosen puts it down (board::put_down). The mouse
// moving lets the keys go: the cursor is gone.
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
import check from "../";

var now = 0.0;

// A frame with the keys as given and the pointer away (or at `at`).
fn key(gm: game::Game&, g: gui::Gui&, l: panel::Layout, step: i64, confirm: bool, tab: i64 = 0,
       at: float2 = float2 { -1.0, -1.0 }) -> bool {
    now += 0.5;
    gui::begin(g, gui::Input { at: at, step: step, confirm: confirm, tab: tab, .. }, l.board.scale, now);
    let ev, changed = game::frame(gm, g, l, now, drive::over);
    return changed;
}

// The cursor's square by name ("e3"), "-" for none.
fn cursor(b: board::Board&) -> u8[>..] {
    guard b.cursor >= 0 else { return str("-"); }
    let n = rules::VARIANTS[b.variant].size;
    var t: u8[>..] = [];
    t.push(('a' + b.cursor % n) as u8);
    format(t, b.cursor / n + 1);
    return t;
}

fn state(gm: game::Game&, g: gui::Gui&, changed: bool, what: const u8[:]) {
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    let on = if g.focus == panel::BOARD_ID { str("board") } else if g.focus == 0 { str("none") } else { str("control ", g.focus) };
    print(what, ": focus ", on, ", cursor ", cursor(b), ", chosen ", drive::name(v, b.selected), ", over ",
          drive::name(v, b.over), ", wrong ", drive::name(v, b.wrong), ", moves made ", b.history.len, ", changed ", changed);
}

fn start(gm: game::Game&, fen: const u8[:], computer: i64) {
    game::start(gm, rules::RUSSIAN, clock::NONE, computer, game::EASY, 0, 1);
    board::set(gm.b, check::position(rules::RUSSIAN, fen));
    gm.turn = gm.b.pos.side;
}

fn main() {
    strings::use(strings::EN);
    let l = panel::layout(1280.0, 800.0, 8);
    var g = gui::Gui {};
    gui::test_faces(g);
    gui::desktop_scale = 1.0;
    var gm = game::new(rules::RUSSIAN);
    let none = gui::STEP_NONE;
    let opening = "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8";
    start(gm, opening, -1);
    state(gm, g, key(gm, g, l, none, false), "at rest");
    state(gm, g, key(gm, g, l, gui::STEP_DOWN, false), "down: the board");
    state(gm, g, key(gm, g, l, none, false), "  resting");
    state(gm, g, key(gm, g, l, none, true), "enter: chosen");
    state(gm, g, key(gm, g, l, gui::STEP_UP, false), "up: a light square");
    state(gm, g, key(gm, g, l, none, true), "  enter there: nothing");
    state(gm, g, key(gm, g, l, gui::STEP_LEFT, false), "left: its target");
    state(gm, g, key(gm, g, l, none, true), "enter: played");
    key(gm, g, l, none, false);

    // Black to move: the cursor stays where it was; left past the edge leaves the board.
    for i in 3 { key(gm, g, l, gui::STEP_LEFT, false); }
    state(gm, g, key(gm, g, l, none, false), "left three: the edge");
    state(gm, g, key(gm, g, l, gui::STEP_LEFT, false), "left: off the board");
    state(gm, g, key(gm, g, l, gui::STEP_RIGHT, false), "right: back on its near edge");

    // Tab: the play panel, the way out, and the board again at its cell.
    state(gm, g, key(gm, g, l, none, false, 1), "tab");
    state(gm, g, key(gm, g, l, none, false, 1), "tab");
    state(gm, g, key(gm, g, l, none, false, 1), "tab");
    state(gm, g, key(gm, g, l, none, false, -1), "shift tab");
    state(gm, g, key(gm, g, l, none, false, 1), "tab");

    // Escape with a piece chosen puts it down.
    g = gui::Gui {};
    gui::test_faces(g);
    start(gm, opening, -1);
    key(gm, g, l, none, false);
    key(gm, g, l, gui::STEP_DOWN, false);
    key(gm, g, l, none, true);
    state(gm, g, false, "a new game, a piece chosen");
    print("  put down: ", board::put_down(gm.b), ", again: ", board::put_down(gm.b));

    // A capture due: a piece that can't take, chosen, is a mistake.
    g = gui::Gui {};
    gui::test_faces(g);
    start(gm, "W:Wa1,c3,g3:Bd4,h8", -1);
    key(gm, g, l, none, false);
    state(gm, g, key(gm, g, l, gui::STEP_DOWN, false), "a capture due: down");
    for i in 4 { key(gm, g, l, gui::STEP_RIGHT, false); }
    state(gm, g, key(gm, g, l, none, false), "right four");
    state(gm, g, key(gm, g, l, none, true), "enter: not the piece that must take");

    // The turned board, the computer white: black's pieces at the bottom, up away from them.
    g = gui::Gui {};
    gui::test_faces(g);
    start(gm, opening, rules::WHITE);
    gm.b.pos.side = rules::BLACK;
    rules::generate(gm.b.pos, gm.b.moves);
    var turned = l;
    turned.board.flip = true;
    key(gm, g, turned, none, false);
    state(gm, g, key(gm, g, turned, gui::STEP_DOWN, false), "turned: down");
    state(gm, g, key(gm, g, turned, gui::STEP_UP, false), "  up");
    state(gm, g, key(gm, g, turned, gui::STEP_RIGHT, false), "  right");

    // The computer's turn: the cursor moves, Enter plays nothing.
    gm.b.pos.side = rules::WHITE;
    rules::generate(gm.b.pos, gm.b.moves);
    state(gm, g, key(gm, g, turned, gui::STEP_DOWN, false), "the computer's turn: down");
    state(gm, g, key(gm, g, turned, none, true), "  enter");

    // The mouse moves: the keys let go.
    state(gm, g, key(gm, g, turned, none, false, 0, float2 { 5.0, 5.0 }), "the mouse moves");
}
