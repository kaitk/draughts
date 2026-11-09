// The game against the computer (game/), headless: the game asks for the computer's
// move once its turn begins, and this test answers at once with ai::think, as the app's
// worker does later. The answer is one of the position's legal moves; it is played only
// after the level's pause, or against the clock the time a player of its level would
// take (except a first move as white and a single move), through the board's animation,
// its clock running meanwhile and gaining the increment after; as the computer begins
// to think its piece's ring on the panel pulses once, and the child can't move its
// pieces. Take back takes back the child's
// move and the computer's reply, or, while the computer thinks, drops its ask and takes
// back the child's move; an answer to a dropped ask is ignored, and so is one after
// leaving the game, which asks again on return. When the child plays black the computer
// moves first, and take back does nothing before the child's first move. A game that
// ends reports its result once, for the shell to move the skill. Once the reply has
// landed nothing animates, so the app draws nothing more.
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

let UNDO = 3;
let RESTART = 2;

fn move_text(variant: u8, m: rules::Move) -> u8[>..] {
    var t: u8[>..] = [];
    rules::format_move(t, variant, m);
    return t;
}

// Answers the game's open ask at once, as the worker would; returns the move and
// whether it is one of the position's legal moves.
fn answer(gm: game::Game&, e: ai::Engine&) -> u8[>..] {
    let ask = game::asking(gm);
    guard ask.id != 0 else { return str("nothing asked"); }
    let m = ai::think(e, ask.pos, ask.skill, ask.seed);
    var legal: rules::Moves = [];
    rules::generate(ask.pos, legal);
    var found = false;
    for c in legal { if c.from == m.from && c.to == m.to && c.captured == m.captured && c.path == m.path { found = true; } }
    game::answer(gm, ask.id, m, ai::close(e, pace::CLOSE));
    return str("ask ", ask.id, " at skill ", ask.skill, " seed ", ask.seed, ": ", move_text(gm.b.variant, m), ", legal ", found);
}

fn seconds(t: f64) -> u8[>..] {
    var out: u8[>..] = [];
    format_flt(out, t, 2);
    return out;
}

// The game as it stands: position, plies, the ask, the clocks, and the ring on the
// panel (the side to move's piece over the UI).
fn show(gm: game::Game&, what: const u8[:]) {
    var ring = 0.0;
    for p in drive::over { ring = max(ring, p.ring.y); }
    var left: u8[>..] = [];
    if clock::on(gm.clock) {
        format(left, ", clocks ");
        format_flt(left, gm.clock.left[0], 2);
        format(left, " ");
        format_flt(left, gm.clock.left[1], 2);
        format(left, " running ", gm.clock.running);
    }
    var r: u8[>..] = [];
    format_flt(r, ring, 2);
    print(what, ": ", rules::fen(gm.b.pos), ", plies ", gm.b.history.len, ", moving ", gm.b.moving, ", asking ",
          gm.asking, left, ", ring ", r);
}

fn main() {
    strings::use(strings::EN);
    let l = panel::layout(1280.0, 800.0, 8);
    var g = gui::Gui {};
    gui::test_faces(g);
    var e = ai::Engine { .. };
    ai::init(e);
    e.node_limit = 50000;       // hard stays quick through TinyCC

    // The child plays white against hard, with a 10+5 clock. Nothing is asked on the
    // child's turn; once c3-d4 has landed (0.2 s) the game asks, black's clock runs, and
    // the ring pulses once. Against the clock the computer takes as long as a player of
    // its level would (game/pace.goose), longer than its pause without one; after the
    // pulse nothing animates until its move, which the app wakes for (game::due).
    var gm = game::new(rules::RUSSIAN);
    game::start(gm, rules::RUSSIAN, clock::RAPID, rules::BLACK, game::HARD, 90, 3);
    drive::idle(gm, g, l, 0.0);
    show(gm, "the child's turn");
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 1.0);
    drive::tap(gm, g, l, drive::at(l.board, "d4"), 1.1);
    drive::idle(gm, g, l, 1.2);
    show(gm, "c3-d4 moving");
    drive::idle(gm, g, l, 1.4);
    show(gm, "landed");
    print("  ", answer(gm, e));
    let a = 1.4 + gm.wait;
    print("  it takes ", seconds(gm.wait), " s, against 0.45 without a clock");
    drive::idle(gm, g, l, 1.7);
    show(gm, "thinking");
    print("  animating ", game::animating(gm, g, 1.7));
    drive::tap(gm, g, l, drive::at(l.board, "f6"), 1.8);
    print("  a tap on f6: selected ", gm.b.selected);
    drive::idle(gm, g, l, 2.6);
    show(gm, "the pulse over");
    print("  animating ", game::animating(gm, g, 2.6), ", its move due in ", seconds(game::due(gm, 2.6)), " s");
    drive::idle(gm, g, l, a - 0.01);
    show(gm, "its time not over");
    drive::idle(gm, g, l, a);
    print("  move ", move_text(gm.b.variant, gm.b.move));
    show(gm, "its time over, the reply moving");
    drive::idle(gm, g, l, a + 0.3);
    show(gm, "landed");
    print("  animating ", game::animating(gm, g, a + 0.3));

    // Take back: the reply and the child's move; at the start no clock runs.
    drive::tap(gm, g, l, drive::control(g, UNDO), a + 0.8);
    show(gm, "take back");

    // Take back while the computer thinks: its ask is dropped and the child's move taken
    // back; its answer, coming late, is ignored.
    drive::tap(gm, g, l, drive::at(l.board, "c3"), a + 1.8);
    drive::tap(gm, g, l, drive::at(l.board, "d4"), a + 1.9);
    drive::idle(gm, g, l, a + 2.2);
    let dropped = game::asking(gm);
    drive::tap(gm, g, l, drive::control(g, UNDO), a + 2.3);
    show(gm, "take back while it thinks");
    game::answer(gm, dropped.id, ai::think(e, dropped.pos, dropped.skill, dropped.seed), 1);
    print("  the dropped ask's answer taken: ", gm.answered);
    drive::tap(gm, g, l, drive::at(l.board, "c3"), a + 2.8);
    drive::tap(gm, g, l, drive::at(l.board, "b4"), a + 2.9);
    drive::idle(gm, g, l, a + 3.2);
    game::answer(gm, dropped.id, ai::think(e, dropped.pos, dropped.skill, dropped.seed), 1);
    print("  after c3-b4, ask ", gm.asking, "; the old answer taken: ", gm.answered);

    // Leaving the game drops the ask; the game asks again when it shows.
    game::pause(gm);
    show(gm, "left the game");
    drive::idle(gm, g, l, a + 3.8);
    show(gm, "back");
    print("  ", answer(gm, e));
    let b = a + 3.8 + gm.wait;
    drive::idle(gm, g, l, b - 0.01);
    print("  moving before its ", seconds(gm.wait), " s: ", gm.b.moving);
    drive::idle(gm, g, l, b);
    print("  played after them: ", move_text(gm.b.variant, gm.b.move));

    // Take back while the reply still moves: the child's turn again.
    drive::idle(gm, g, l, b + 0.1);
    drive::tap(gm, g, l, drive::control(g, UNDO), b + 0.1);
    show(gm, "take back while the reply moves");

    // The child plays black: the computer, white, moves first, at once asked; take back
    // does nothing before the child's first move, nor right after the computer's.
    var turned = l;
    turned.board.flip = true;
    game::start(gm, rules::RUSSIAN, clock::NONE, rules::WHITE, game::MEDIUM, 40, 3);
    drive::idle(gm, g, turned, 10.0);
    show(gm, "the child plays black");
    let first = gm.asking;
    drive::tap(gm, g, turned, drive::control(g, UNDO), 10.1);
    print("  take back: plies ", gm.b.history.len, ", the same ask ", gm.asking == first);
    print("  ", answer(gm, e));
    drive::idle(gm, g, turned, 10.59);
    show(gm, "0.6 s on medium, not over");
    drive::idle(gm, g, turned, 10.6);
    drive::idle(gm, g, turned, 11.2);
    show(gm, "its first move");
    drive::tap(gm, g, turned, drive::control(g, UNDO), 11.3);
    show(gm, "take back");
    // Start over while it thinks: a new ask, from the start.
    drive::tap(gm, g, turned, drive::control(g, RESTART), 11.5);
    drive::idle(gm, g, turned, 11.6);
    show(gm, "start over");

    // Each level's reply in a middlegame is legal, and comes after its pause: 0.8 s on
    // easy, 0.6 on medium, 0.45 on hard.
    let mid, ok = rules::parse_fen("B:Wa1,e1,g1,b2,d2,f2,h2,a3,e3,f4,a5:Bg5,b6,d6,f6,h6,a7,c7,e7,g7,b8,f8",
                                   rules::RUSSIAN);
    assert(ok);
    for level in 3 {
        game::start(gm, rules::RUSSIAN, clock::NONE, rules::BLACK, level, ai::level_skill(level), 5);
        board::set(gm.b, mid);
        let t = 20.0 * (level + 1);
        drive::idle(gm, g, l, t);
        print(["easy", "medium", "hard"][level], ": ", answer(gm, e));
        let pause = game::PAUSE[level];
        drive::idle(gm, g, l, t + pause - 0.01);
        let before = gm.b.moving;
        drive::idle(gm, g, l, t + pause);
        print("  moving 0.01 s before the pause ends ", before, ", when it ends ", gm.b.moving);
    }

    // Against the clock the computer's first move as white is untimed, so it comes after
    // the pause; so does a single move, here a forced capture with its clock running.
    game::start(gm, rules::RUSSIAN, clock::BLITZ, rules::WHITE, game::HARD, 90, 7);
    drive::idle(gm, g, turned, 90.0);
    print("hard as white on 5+3, no clock running yet: ", answer(gm, e), ", it takes ", seconds(gm.wait), " s");
    let forced, ok_forced = rules::parse_fen("B:Wd4,a1:Bc5,h8", rules::RUSSIAN);
    assert(ok_forced);
    game::start(gm, rules::RUSSIAN, clock::BLITZ, rules::BLACK, game::HARD, 90, 8);
    board::set(gm.b, forced);
    gm.clock.running = rules::BLACK;
    drive::idle(gm, g, l, 95.0);
    print("hard's one move on 5+3, its clock running: ", answer(gm, e), ", it takes ", seconds(gm.wait), " s");

    // A game the child wins reports it once: taken back and won again, it reports
    // nothing more. One the computer wins reports a loss.
    let won, ok_won = rules::parse_fen("W:Wc3:Bd4", rules::RUSSIAN);
    assert(ok_won);
    game::start(gm, rules::RUSSIAN, clock::NONE, rules::BLACK, game::EASY, 10, 9);
    board::set(gm.b, won);
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 100.0);
    drive::tap(gm, g, l, drive::at(l.board, "e5"), 100.1);
    drive::idle(gm, g, l, 101.0);
    print("the child takes the last piece: winner ", game::winner(gm), ", result ", gm.result);
    gm.result = 0;
    drive::tap(gm, g, l, drive::control(g, UNDO), 102.0);
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 103.0);
    drive::tap(gm, g, l, drive::at(l.board, "e5"), 103.1);
    drive::idle(gm, g, l, 104.0);
    print("  taken back and won again: winner ", game::winner(gm), ", result ", gm.result);
    let lost, ok_lost = rules::parse_fen("B:Wd4:Bc5", rules::RUSSIAN);
    assert(ok_lost);
    game::start(gm, rules::RUSSIAN, clock::NONE, rules::BLACK, game::EASY, 10, 10);
    board::set(gm.b, lost);
    drive::idle(gm, g, l, 110.0);
    print("the computer can take the last piece: ", answer(gm, e));
    drive::idle(gm, g, l, 111.0);
    drive::idle(gm, g, l, 112.0);
    print("  winner ", game::winner(gm), ", result ", gm.result);
}
