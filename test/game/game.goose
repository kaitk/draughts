// The game screen (game/), headless, driven through the pointer as the app drives it:
// take back takes back one move at a time, also one still animating, and brings back the
// last move's marks; start over goes back to where the game began, a FEN start too; home
// and settings ask the shell for them; a press that starts on a panel never moves a
// piece and one that starts on the board never presses a tile; a win starts the
// celebration once the move has shown, its card comes after the pieces have answered,
// and its restart starts over (the celebration's moments: test/game/win.goose). With a 5+3 clock: no clock runs before the first move,
// the running one counts the time between frames but not a pause, adds the increment,
// asks for a frame only when its shown time changes, turns red under ten seconds, and
// ends the game on a flag. Against the computer playing white the board is turned, the
// game says when the computer is to move, and the child can't move its pieces (the
// computer's moves: test/game/computer.goose). In portrait the panels are above and
// below the board.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import strings from "../../strings";
import game from "../../game";
import ai from "../../ai";
import shell from "../../shell";
import puzzles from "../../puzzles";
import drive from "../drive";

fn show(gm: game::Game&, what: const u8[:]) {
    let v .= rules::VARIANTS[gm.b.variant];
    var last: u8[>..] = [];
    if gm.b.has_last { last = str(drive::name(v, gm.b.last.from), "-", drive::name(v, gm.b.last.to)); } else { last = str("none"); }
    print(what, ": ", rules::fen(gm.b.pos), ", history ", gm.b.history.len, ", last ", last);
}

let HOME = 0;
let SETTINGS = 1;
let RESTART = 2;
let UNDO = 3;
let CARD_BACK = 4;
let CARD_RESTART = 5;

// The overlay's pieces: side, opacity, ring.
fn pieces() -> u8[>..] {
    var s: u8[>..] = [];
    for p in drive::over { format(s, if p.look.x > 0.5 { "black" } else { "white" }, " ", p.look.w, " ", p.ring.y, "; "); }
    return s;
}

// What the clocks show, from the glyph quads' count and the clocks' values.
fn clocks(gm: game::Game&, g: gui::Gui&) -> u8[>..] {
    var w: u8[..8] = [];
    var b: u8[..8] = [];
    clock::text(clock::shown(gm.clock, 0), w);
    clock::text(clock::shown(gm.clock, 1), b);
    var styles: u8[>..] = [];
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.extra.y >= gui::CLOCK_RUN else { continue; }
        format(styles, if q.extra.y == gui::CLOCK_RUN { "run " } else if q.extra.y == gui::CLOCK_LOW { "low " } else { "wait " });
    }
    return str("white ", w, ", black ", b, ", running ", gm.clock.running, ", tiles top to bottom ", styles);
}

fn main() {
    strings::use(strings::EN);
    let v .= rules::VARIANTS[rules::RUSSIAN];
    let l = panel::layout(1280.0, 800.0, 8);
    var g = gui::Gui {};
    gui::test_faces(g);
    var gm = game::new(rules::RUSSIAN);
    let away = float2 { 0.0, 0.0 };
    drive::frame(gm, g, l, away, false, false, false, 0.0);
    print("panels ", l.left, " ", l.right, ", board ", l.board.board);
    print("over the UI: ", pieces());

    // Two moves, then undo each; undo at the start does nothing.
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 0.0);
    drive::tap(gm, g, l, drive::at(l.board, "d4"), 0.1);
    drive::frame(gm, g, l, away, false, false, false, 1.0);
    print("turn after c3-d4: ", pieces());
    drive::tap(gm, g, l, drive::at(l.board, "f6"), 1.0);
    drive::tap(gm, g, l, drive::at(l.board, "e5"), 1.1);
    drive::frame(gm, g, l, away, false, false, false, 2.0);
    show(gm, "two moves");
    drive::tap(gm, g, l, drive::control(g, UNDO), 2.0);
    show(gm, "undo");
    drive::tap(gm, g, l, drive::control(g, UNDO), 2.1);
    show(gm, "undo");
    drive::tap(gm, g, l, drive::control(g, UNDO), 2.2);
    show(gm, "undo at the start");

    // Undo while the move is still animating.
    drive::tap(gm, g, l, drive::at(l.board, "e3"), 3.0);
    drive::tap(gm, g, l, drive::at(l.board, "f4"), 3.1);
    print("moving ", gm.b.moving);
    drive::tap(gm, g, l, drive::control(g, UNDO), 3.15);
    print("undo while moving: moving ", gm.b.moving);
    show(gm, "  then");

    // From a FEN start white must take: c3 two pieces, by way of e5 to g7. Restart goes
    // back to the FEN.
    let p, ok = rules::parse_fen("W:Wc3,h2,a1:Bd4,f6,g3,h8", rules::RUSSIAN);
    assert(ok);
    board::set(gm.b, p);
    drive::frame(gm, g, l, away, false, false, false, 4.0);
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 4.0);
    drive::tap(gm, g, l, drive::at(l.board, "g7"), 4.1);
    drive::frame(gm, g, l, away, false, false, false, 5.5);
    show(gm, "the capture played");
    drive::tap(gm, g, l, drive::control(g, RESTART), 5.6);
    show(gm, "start over");

    // Home and settings ask the shell; neither changes the game.
    print("home asks for home: ", drive::tap(gm, g, l, drive::control(g, HOME), 6.0) == game::HOME);
    print("settings asks for settings: ", drive::tap(gm, g, l, drive::control(g, SETTINGS), 6.1) == game::SETTINGS);

    // A press on take back slid onto the board and released on a target moves nothing;
    // a press on a piece released on take back takes nothing back.
    board::set(gm.b, rules::start(rules::RUSSIAN));
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 7.0);
    let undo_at = drive::control(g, UNDO);
    drive::frame(gm, g, l, undo_at, true, true, false, 7.1);
    drive::frame(gm, g, l, drive::at(l.board, "d4"), true, false, false, 7.2);
    drive::frame(gm, g, l, drive::at(l.board, "d4"), false, false, true, 7.3);
    print("press on take back, released on d4: moving ", gm.b.moving, ", selected ", drive::name(v, gm.b.selected));
    drive::tap(gm, g, l, drive::at(l.board, "d4"), 7.4);
    drive::frame(gm, g, l, away, false, false, false, 8.0);
    drive::frame(gm, g, l, drive::at(l.board, "f6"), true, true, false, 8.0);
    drive::frame(gm, g, l, undo_at, true, false, false, 8.1);
    drive::frame(gm, g, l, undo_at, false, false, true, 8.2);
    show(gm, "press on f6, released on take back");

    // A win: c3 takes d4 and black has nothing left.
    let w, ok_w = rules::parse_fen("W:Wc3,a1:Bd4", rules::RUSSIAN);
    assert(ok_w);
    board::set(gm.b, w);
    gm.turn = gm.b.pos.side;
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 10.0);
    drive::tap(gm, g, l, drive::at(l.board, "e5"), 10.1);
    drive::frame(gm, g, l, away, false, false, false, 10.2);
    print("while the capture shows: celebrating ", gm.won_at >= 0.0);
    drive::frame(gm, g, l, away, false, false, false, 11.0);
    print("after: celebrating since ", gm.won_at, ", over the UI ", pieces(), "tiles ", drive::tiles(g));
    drive::frame(gm, g, l, away, false, false, false, 13.0);
    print("at 2.0 s: over the UI ", pieces(), "the winner crowned ", drive::over[1].look.y, ", tiles ",
          drive::tiles(g), ", animating at 8 s ", game::animating(gm, g, 19.0));
    print("back on the card asks for home: ", drive::tap(gm, g, l, drive::control(g, CARD_BACK), 19.1) == game::HOME);
    drive::tap(gm, g, l, drive::control(g, CARD_RESTART), 19.2);
    show(gm, "restart on the card");
    print("celebrating ", gm.won_at >= 0.0);

    // A 5+3 game: no clock runs until white's first move, then black's counts the time
    // between frames; a frame is drawn when the time shown changes, not between.
    gm = game::new(rules::RUSSIAN);
    game::start(gm, rules::RUSSIAN, clock::BLITZ, -1, game::MEDIUM, 40, 0);
    drive::frame(gm, g, l, away, false, false, false, 20.0);
    drive::frame(gm, g, l, away, false, false, false, 30.0);
    print("5+3, 10 s before a move: ", clocks(gm, g), "; over the UI ", pieces());
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 30.0);
    drive::tap(gm, g, l, drive::at(l.board, "d4"), 30.1);
    gui::begin(g, gui::Input {}, l.board.scale, 30.6);
    let a, drawn_a = game::frame(gm, g, l, 30.6, drive::over);
    print("c3-d4: ", clocks(gm, g), "; over the UI ", pieces());
    gui::begin(g, gui::Input {}, l.board.scale, 30.9);
    let b, drawn_b = game::frame(gm, g, l, 30.9, drive::over);
    gui::begin(g, gui::Input {}, l.board.scale, 31.15);
    let c, drawn_c = game::frame(gm, g, l, 31.15, drive::over);
    print("frames at 0.5, 0.8, 1.05 s on black's clock: drawn ", drawn_a, " ", drawn_b, " ", drawn_c, "; ",
          clocks(gm, g));
    // A pause: the frame after it counts nothing, however long it was.
    game::pause(gm);
    drive::frame(gm, g, l, away, false, false, false, 500.0);
    print("after a pause of 469 s: ", clocks(gm, g));
    drive::tap(gm, g, l, drive::at(l.board, "f6"), 501.0);
    drive::tap(gm, g, l, drive::at(l.board, "e5"), 501.1);
    drive::frame(gm, g, l, away, false, false, false, 502.0);
    print("f6-e5 after 2 s more: ", clocks(gm, g));
    drive::tap(gm, g, l, drive::control(g, UNDO), 502.0);
    print("take back: ", clocks(gm, g), ", ", rules::fen(gm.b.pos));
    // Frames a second apart until black's time runs out: the clock turns red under ten
    // seconds, and the flag ends the game as a win for white.
    var t = 503.0;
    while gm.clock.left[1] > 10.5 {
        drive::frame(gm, g, l, away, false, false, false, t);
        t += 1.0;
    }
    drive::frame(gm, g, l, away, false, false, false, t + 1.0);
    print("under ten seconds: ", clocks(gm, g));
    t += 2.0;
    while gm.clock.flag < 0 {
        drive::frame(gm, g, l, away, false, false, false, t);
        t += 1.0;
    }
    drive::frame(gm, g, l, away, false, false, false, t);
    print("black's flag: ", clocks(gm, g), "; winner ", game::winner(gm), ", celebrating ", gm.won_at >= 0.0,
          ", over the UI ", pieces());
    drive::tap(gm, g, l, drive::control(g, UNDO), t + 0.1);
    print("take back after the flag: ", clocks(gm, g), ", flag ", gm.clock.flag);
    drive::tap(gm, g, l, drive::control(g, RESTART), t + 0.2);
    print("start over: ", clocks(gm, g), ", flag ", gm.clock.flag, ", celebrating ", gm.won_at >= 0.0);

    // Against the computer playing white the board is turned: the child's black pieces
    // are at the bottom, a tap lands on the turned square, and the child's clock is the
    // lower one. While the computer is to move, a tap on its piece does nothing, and its
    // clock's piece has a pulsing ring though no clock runs yet.
    game::start(gm, rules::RUSSIAN, clock::RAPID, rules::WHITE, game::HARD, 90, 0);
    var turned = panel::layout(1280.0, 800.0, 8);
    turned.board.flip = true;
    print("the computer to move: ", game::computer_to_move(gm));
    drive::tap(gm, g, turned, drive::at(turned.board, "c3"), 600.0);
    drive::tap(gm, g, turned, drive::at(turned.board, "d4"), 600.1);
    drive::frame(gm, g, turned, away, false, false, false, 601.0);
    print("c3 at ", drive::at(turned.board, "c3"), ", f6 at ", drive::at(turned.board, "f6"), "; a tap on c3 and d4 leaves ",
          rules::fen(gm.b.pos), "; the computer to move: ", game::computer_to_move(gm), "; ", clocks(gm, g),
          "; over the UI ", pieces());

    // Portrait: the bar of three above the board, the play below it.
    let pl = panel::layout(800.0, 1280.0, 8);
    var pg = game::new(rules::RUSSIAN);
    drive::frame(pg, g, pl, away, false, false, false, 0.0);
    print("portrait: panels ", pl.left, " ", pl.right, ", board ", pl.board.board, ", take back at ", drive::control(g, UNDO));
    print("portrait take back undoes: ", drive::tap(pg, g, pl, drive::control(g, UNDO), 0.1) == game::STAY);
}
