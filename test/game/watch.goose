// The lookout on the game screen (game::watch, docs/architecture/ai.md, "The lookout"):
// off by default; its eye on whose turn's line turns it on and off. On, it marks the
// side to move's pieces the other side could take were it its turn, and a crowning
// square, of the kinds the skill leaves out; worked out once a position, so an idle frame
// changes nothing. While a piece is dragged over a target the marks are what that move
// would leave; a piece selected by a tap keeps the marks of the position, and the mouse
// over a target shows that move's (on touch a finger lifted rests on the piece). Nothing
// shows on the computer's turn, while a capture is due, or once the game has ended; at
// hard's skills nothing at all. The prototype's positions (Russian, white the child).
// Traps are asked of the app's worker (game::ask_for, kind TRAPS), answered here at once
// as it would, and marked with the rest; an answer for a position left is ignored, and
// from hard's skills none is asked.
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

fn bits(v: rules::Variant&, b: u64) -> u8[>..] {
    var s: u8[>..] = [];
    var left = b;
    while left != 0 {
        let sq = ctz(left);
        left &= left - 1;
        if s.len > 0 { s.push(' '); }
        s.append(drive::name(v, sq));
    }
    return if s.len > 0 { s } else { str("-") };
}

// The marks as the board will draw them: the pieces in danger and the crowning squares.
fn show(gm: game::Game&, what: const u8[:]) {
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    let r, lit = drive::eye(g0);
    print(what, ": danger ", bits(v, b.danger), ", crowns ", bits(v, b.crowns), ", eye lit ", lit);
}

var g0: gui::Gui;

fn start(gm: game::Game&, fen: const u8[:], computer: i64) {
    game::start(gm, rules::RUSSIAN, clock::NONE, computer, game::EASY, 0, 1);
    board::set(gm.b, check::position(rules::RUSSIAN, fen));
    gm.turn = gm.b.pos.side;
    gm.look_skill = 0;
}

fn main() {
    strings::use(strings::EN);
    let l = panel::layout(1280.0, 800.0, 8);
    gui::test_faces(g0);
    var gm = game::new(rules::RUSSIAN);
    let calm = "W:Wa1,c1,e1,g1,b2,d2,h2,a3,e3,g3,d4:Bb8,d8,f8,h8,a7,c7,e7,g7,b6,f6,e5,h4";
    start(gm, calm, rules::BLACK);
    drive::idle(gm, g0, l, 1.0);
    show(gm, "calm, the lookout off");
    let eye, unused = drive::eye(g0);
    drive::tap(gm, g0, l, drive::middle(eye), 1.1);
    drive::idle(gm, g0, l, 1.2);
    show(gm, "its eye tapped");
    gui::begin(g0, gui::Input { at: drive::AWAY, .. }, l.board.scale, 1.3);
    let go, changed = game::frame(gm, g0, l, 1.3, drive::over);
    print("  an idle frame changes nothing: ", !changed);

    // b2 selected by a tap: the position's marks; dragged over c3, that move's.
    drive::tap(gm, g0, l, drive::at(l.board, "d2"), 2.0);
    show(gm, "d2 selected by a tap");
    drive::frame(gm, g0, l, drive::at(l.board, "c3"), false, false, false, 2.1);
    show(gm, "the mouse over c3");
    drive::frame(gm, g0, l, drive::at(l.board, "d2"), true, true, false, 2.2);
    drive::frame(gm, g0, l, drive::at(l.board, "c3"), true, false, false, 2.3);
    show(gm, "d2 dragged over c3");
    drive::frame(gm, g0, l, drive::at(l.board, "e3"), true, false, false, 2.4);
    show(gm, "over e3, no move");
    drive::frame(gm, g0, l, drive::at(l.board, "e3"), false, false, true, 2.5);
    drive::idle(gm, g0, l, 2.6);
    show(gm, "let go on e3");

    // a3 dragged to b4 puts itself next to the attacker: the held piece is marked on its
    // own square, and d4 is then taken in a double jump.
    drive::frame(gm, g0, l, drive::at(l.board, "a3"), true, true, false, 3.0);
    drive::frame(gm, g0, l, drive::at(l.board, "b4"), true, false, false, 3.1);
    show(gm, "a3 dragged over b4");
    drive::frame(gm, g0, l, drive::at(l.board, "b4"), false, false, true, 3.2);
    drive::idle(gm, g0, l, 3.3);
    show(gm, "dropped on b4, the move showing");
    drive::idle(gm, g0, l, 4.0);
    show(gm, "the computer's turn");

    // The held position: b4 over a5 opens c5 and c3 to the double jump.
    start(gm, "W:Wa1,c1,e1,g1,b2,f2,h2,c3,g3,b4,c5:Bb8,d8,f8,h8,a7,e7,g7,d6,f6,h6", rules::BLACK);
    drive::idle(gm, g0, l, 5.0);
    show(gm, "held, at rest");
    drive::frame(gm, g0, l, drive::at(l.board, "b4"), true, true, false, 5.1);
    drive::frame(gm, g0, l, drive::at(l.board, "a5"), true, false, false, 5.2);
    show(gm, "b4 dragged over a5");
    drive::frame(gm, g0, l, drive::at(l.board, "b4"), false, false, true, 5.3);
    drive::idle(gm, g0, l, 5.4);
    gm.look_skill = 25;
    drive::frame(gm, g0, l, drive::at(l.board, "b4"), true, true, false, 5.5);
    drive::frame(gm, g0, l, drive::at(l.board, "a5"), true, false, false, 5.6);
    show(gm, "the same at skill 25, a double jump left to the player");
    drive::frame(gm, g0, l, drive::at(l.board, "b4"), false, false, true, 5.7);

    // King: d2 crowns on e1; shown below 15, left to the player from 15.
    start(gm, "W:Wc1,g1,h2,a3,g3,b4,c5:Bd2,e3,d6,a7,c7,e7,f8,h8", rules::BLACK);
    drive::idle(gm, g0, l, 6.0);
    show(gm, "king");
    start(gm, "W:Wc1,g1,h2,a3,g3,b4,c5:Bd2,e3,d6,a7,c7,e7,f8,h8", rules::BLACK);
    gm.look_skill = 15;
    drive::idle(gm, g0, l, 6.1);
    show(gm, "king at skill 15");
    start(gm, calm, rules::BLACK);
    gm.look_skill = 70;
    drive::idle(gm, g0, l, 6.2);
    show(gm, "calm at hard's 70");

    // A capture due: nothing; a friend's game: for black on its turn.
    start(gm, "W:Wa1,c3:Bd4,h8", rules::BLACK);
    drive::idle(gm, g0, l, 7.0);
    show(gm, "a capture due");
    start(gm, "B:Wa1,c3,d4:Be5,h8", -1);
    drive::idle(gm, g0, l, 7.1);
    show(gm, "a friend's game, black to move");

    // A trap: black's c5-d4 would win c3 and e3 back for one. Asked, then answered.
    let shot = "W:Wa1,c3,e3:Ba7,b6,c5,f6,g7,h8";
    start(gm, shot, rules::BLACK);
    drive::idle(gm, g0, l, 9.0);
    var ask = game::ask_for(gm);
    print("the shot: asked for traps ", ask.kind == game::TRAPS, ", the computer to move in it ", ask.pos.side == 1);
    print("  answered: shown ", game::trapped(gm, ask.id, lookout::traps(ask.pos)));
    show(gm, "  marked");
    // a1 held over b2 guards b2: the trap is gone; the old answer is ignored.
    drive::frame(gm, g0, l, drive::at(l.board, "a1"), true, true, false, 9.1);
    drive::frame(gm, g0, l, drive::at(l.board, "b2"), true, false, false, 9.2);
    let old = ask;
    ask = game::ask_for(gm);
    print("  a1 held over b2: the old answer ignored ", !game::trapped(gm, old.id, lookout::traps(old.pos)),
          ", the new one shown ", game::trapped(gm, ask.id, lookout::traps(ask.pos)));
    show(gm, "  a1 dragged over b2");
    drive::frame(gm, g0, l, drive::at(l.board, "a1"), false, false, true, 9.3);
    start(gm, shot, rules::BLACK);
    gm.look_skill = 70;
    drive::idle(gm, g0, l, 9.4);
    print("at hard's 70: asked ", game::ask_for(gm).id != 0);

    // The eye turned off clears the marks.
    start(gm, calm, rules::BLACK);
    drive::idle(gm, g0, l, 8.0);
    let e2, unused2 = drive::eye(g0);
    drive::tap(gm, g0, l, drive::middle(e2), 8.1);
    drive::idle(gm, g0, l, 8.2);
    show(gm, "the eye tapped again");
}
