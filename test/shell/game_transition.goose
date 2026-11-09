// Home to the game and back through their transition, headless: continue, and play in a
// friend's setup, grow the board from home's place into the game's (left and larger in
// landscape, down and larger in portrait), home's column fading out under the game's
// panels, both drifting the way the board goes, and the photograph going from sharp to
// blurred. One board, so its pieces never fade. The frame of the tap still shows home
// as it stands; the frame after the end is drawn, at rest, as the game opened straight
// is, and then nothing more. A tap during it lands on the game (take back), and the
// game's home during it turns it round where it is. Play's setup leaves as it was, its
// small boards fading, its board the game's start on squares of its size all the way.
// While the transition runs the game counts no time on the clock and asks the computer
// for nothing, both ways; once it is over the clock counts and the computer is asked.
// Leaving a won game, its dim, lifts, and card fade out with the game's panels. Both
// screens' UI is hidden where the board passes (the hole), but for the card and its
// piece, which lie on the board.
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

fn screen(sh: shell::Shell&) -> const u8[:] {
    if sh.screen == shell::HOME { "home" } else if sh.screen == shell::GAME { "game" } else { "settings" }
}

fn rect(r: float4) -> u8[>..] { str(round(r.x), ",", round(r.y), " ", round(r.z)) }

// Where the UI is hidden this frame: nowhere at rest, else the board's rect.
fn hole(sh: shell::Shell&) -> const u8[:] {
    if sh.hole.z <= 0.0 { "none" } else if sh.hole == sh.layout.board { "the board" } else { "elsewhere" }
}

// The quads and pieces over the UI that lie on the board, which the hole leaves: a win's
// card.
fn on_board(sh: shell::Shell&, g: gui::Gui&) -> u8[>..] {
    var quads = 0;
    var pieces = 0;
    for q in g.quads { if q.extra.z >= gui::ON_BOARD { quads++; } }
    for p in sh.over { if p.win.w > 0.5 { pieces++; } }
    return str(quads, " quads and ", pieces, " piece");
}
fn pc(x: f32) -> f64 { round(100.0 * x) }

// One idle frame at `now`: what the shell says of it and what it declared.
fn look(sh: shell::Shell&, g: gui::Gui&, now: f64, what: const u8[:]) {
    let drawn = drive::idle(sh, g, now);
    var faded = 0;
    var gone = 0;
    var minis = 0;
    for q in g.quads {
        if q.extra.w > 0.0 { faded++; }
        if q.extra.w > 0.5 { gone++; }
        if q.look.x == gui::MINI { minis++; }
    }
    let b .= shell::fill(sh, now);
    var faint = 0;
    for p in b.pieces { if p.look.w < 1.0 { faint++; } }
    print(what, " ", now, ": ", screen(sh), ", board ", rect(sh.layout.board), " ", sh.layout.n, "x", sh.layout.n,
          ", mix ", pc(sh.mix), "%, blur ", pc(sh.blur), "%, quads ", g.quads.len, " faded ", faded, " mostly ", gone,
          if minis > 0 { str(", small boards ", minis) } else { str("") }, ", pieces ", b.pieces.len, " faint ", faint,
          ", over the UI ", sh.over.len, ", hole ", hole(sh), ", drawn ", drawn, ", animating ", shell::animating(sh, g, now));
}

// The game's clocks and the computer's ask.
fn clocks(sh: shell::Shell&) -> u8[>..] {
    let gm .= sh.game;
    return str("black's clock ", round(100.0 * gm.clock.left[rules::BLACK]) / 100.0, ", runs ", gm.clock.running,
               ", asking ", gm.asking != 0);
}

// The game opened straight on a screen of drive::size at `now`: its board, quads, and
// pieces over the UI, as a transition should arrive at them.
fn straight(sh: shell::Shell&, now: f64) -> u8[>..] {
    var h = gui::Gui {};
    gui::test_faces(h);
    let screen = sh.screen;
    let drawn = sh.drawn;
    sh.screen = shell::GAME;
    sh.drawn = shell::GAME;
    drive::idle(sh, h, now);
    let s = str(rect(sh.layout.board), " ", sh.layout.flip, ", quads ", h.quads.len, ", over the UI ", sh.over.len,
                ", blur ", pc(sh.blur));
    sh.screen = screen;
    sh.drawn = drawn;
    return s;
}

// The n-th control's opacity (drive::control's order), rounded to a percent.
fn opacity(g: gui::Gui&, n: i64) -> f64 {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.extra.y < gui::CLOCK_RUN else { continue; }
        if k == n { return pc(1.0 - q.extra.w); }
        k++;
    }
    return -1.0;
}

// How far the highest piece is lifted, in pixels.
fn lift(b: board::Board&) -> f32 {
    var up: f32 = 0.0;
    for p in b.pieces { up = max(up, p.at.w); }
    return up;
}

fn arrived(sh: shell::Shell&, g: gui::Gui&) -> u8[>..] {
    return str(rect(sh.layout.board), " ", sh.layout.flip, ", quads ", g.quads.len, ", over the UI ", sh.over.len,
               ", blur ", pc(sh.blur));
}

fn main() {
    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    puzzles::load();

    // A Russian game a move in, against a friend, at home.
    var sh = shell::new(rules::RUSSIAN);
    sh.screen = shell::GAME;
    drive::idle(sh, g, 0.0);
    let into = straight(sh, 0.0);
    let take_back = drive::control(g, 3);
    drive::tap(sh, g, drive::at(sh.layout, "c3"), 0.1);
    drive::tap(sh, g, drive::at(sh.layout, "d4"), 0.2);
    sh.screen = shell::HOME;
    look(sh, g, 1.0, "home");
    let home_at = sh.layout.board;
    let continue_row = drive::tile(g, 0);

    // Continue, tapped at 2.0 and released at 2.02: the transition runs from then.
    drive::frame(sh, g, continue_row, true, true, false, 2.0);
    let first = drive::frame(sh, g, continue_row, false, false, true, 2.02);
    print("tapped continue: ", screen(sh), ", from home ", sh.from == shell::HOME, ", drawn ", first,
          " with home's board ", sh.layout.board == home_at, " at ", pc(sh.mix), "%, blur ", pc(sh.blur), "%");
    var x = home_at.x;
    var size = home_at.z;
    var left = true;
    for i in 1..5 {
        look(sh, g, 2.02 + 0.0625 * i, "  ");
        if sh.layout.board.x > x || sh.layout.board.z < size { left = false; }
        x = sh.layout.board.x;
        size = sh.layout.board.z;
    }
    look(sh, g, 2.4, "  ");
    look(sh, g, 2.5, "idle");
    print("the board went left and grew all the way ", left);
    print("the game as opened straight ", arrived(sh, g) == into, ": ", into);

    // Home from the game, and back to it; halfway, take back lands on the game and takes
    // back the move.
    drive::tap(sh, g, drive::control(g, 0), 3.0);
    look(sh, g, 3.1, "home again");
    drive::idle(sh, g, 3.5);
    print("home: ", screen(sh), ", board ", sh.layout.board == home_at, ", blur ", pc(sh.blur), "%, animating ",
          shell::animating(sh, g, 3.5));
    drive::frame(sh, g, continue_row, true, true, false, 4.0);
    drive::frame(sh, g, continue_row, false, false, true, 4.02);
    look(sh, g, 4.1, "continue again");
    drive::frame(sh, g, take_back, true, true, false, 4.12);
    drive::frame(sh, g, take_back, false, false, true, 4.14);
    print("take back where the game has it: ", screen(sh), ", moves made ", sh.game.b.history.len);

    // The game's home during the transition turns it round: the board goes back from
    // where it is, and takes as long as it came.
    drive::idle(sh, g, 4.5);
    let home_tile = drive::control(g, 0);
    drive::tap(sh, g, home_tile, 4.6);
    drive::idle(sh, g, 5.0);
    drive::frame(sh, g, continue_row, true, true, false, 5.1);
    drive::frame(sh, g, continue_row, false, false, true, 5.12);
    look(sh, g, 5.26, "before home");
    drive::frame(sh, g, home_tile, true, true, false, 5.27);
    let before = sh.layout.board;
    drive::frame(sh, g, home_tile, false, false, true, 5.28);
    let turned = sh.layout.board;
    drive::idle(sh, g, 5.29);
    let after = sh.layout.board;
    print("home during it: ", screen(sh), ", from the game ", sh.from == shell::GAME, ", the board on the frames ",
          rect(before), ", ", rect(turned), ", ", rect(after));
    look(sh, g, 5.34, "  ");
    look(sh, g, 5.42, "  ");
    look(sh, g, 5.46, "ended");
    look(sh, g, 5.6, "idle");
    print("at home's place ", sh.layout.board == home_at);

    // A friend's setup, Brazilian (8 × 8, as the Russian game at home is); play.
    drive::tap(sh, g, drive::tile(g, 1), 6.0);
    drive::tap(sh, g, drive::tile(g, 2), 6.1);
    look(sh, g, 6.5, "a friend's setup");
    let setup_at = sh.layout.board;
    let play = drive::tile(g, 7);
    drive::frame(sh, g, play, true, true, false, 7.0);
    drive::frame(sh, g, play, false, false, true, 7.02);
    print("tapped play: ", screen(sh), ", the setup's board ", sh.layout.board == setup_at, ", a new game ",
          sh.game.b.history.len == 0, ", setup ", sh.setup);
    for i in 1..5 { look(sh, g, 7.02 + 0.0625 * i, "  "); }
    look(sh, g, 7.4, "idle");
    print("the game as opened straight ", arrived(sh, g) == straight(sh, 7.4));

    // A clocked game against the computer, which plays black: white moves, black's clock
    // runs and the computer is to move. Home and back: neither transition counts time or
    // asks the computer for a move.
    game::start(sh.game, rules::RUSSIAN, clock::BLITZ, rules::BLACK, game::MEDIUM, 40, 0);
    drive::idle(sh, g, 10.0);
    drive::tap(sh, g, drive::at(sh.layout, "c3"), 10.1);
    drive::tap(sh, g, drive::at(sh.layout, "d4"), 10.2);
    drive::idle(sh, g, 11.0);
    print("the computer's turn: ", clocks(sh));
    drive::tap(sh, g, drive::control(g, 0), 12.0);
    print("  home: ", screen(sh), ", ", clocks(sh));
    for i in 1..5 {
        drive::idle(sh, g, 12.02 + 0.0625 * i);
        print("  ", 12.02 + 0.0625 * i, ": ", screen(sh), ", ", clocks(sh));
    }
    drive::idle(sh, g, 13.0);
    drive::frame(sh, g, continue_row, true, true, false, 14.0);
    drive::frame(sh, g, continue_row, false, false, true, 14.02);
    print("  continue: ", screen(sh), ", ", clocks(sh));
    for i in 1..5 {
        drive::idle(sh, g, 14.02 + 0.0625 * i);
        print("  ", 14.02 + 0.0625 * i, ": ", screen(sh), ", in the transition ", sh.from >= 0, ", ", clocks(sh));
    }
    drive::idle(sh, g, 15.0);
    print("  a little after: ", clocks(sh));

    // A won game: white takes the last black piece; once its celebration is still, home.
    // The dim, the winning piece's lift, and the card fade with the game's panels.
    let p, ok = rules::parse_fen("W:Wa1,c1,g1,b2,h2,e3:Bf4", rules::RUSSIAN);
    game::start(sh.game, rules::RUSSIAN, clock::NONE, -1, game::MEDIUM, 40, 0);
    board::set(sh.game.b, p);
    sh.game.turn = sh.game.b.pos.side;
    drive::idle(sh, g, 20.0);
    drive::tap(sh, g, drive::at(sh.layout, "e3"), 20.1);
    drive::tap(sh, g, drive::at(sh.layout, "g5"), 20.2);
    drive::idle(sh, g, 21.0);
    drive::idle(sh, g, 25.0);
    print("won: ", ok, ", winner ", game::winner(sh.game), ", the card's back ", opacity(g, 4), ", on the board ",
          on_board(sh, g));
    let gone .= shell::fill(sh, 25.0);
    print("  at rest: the board dimmed ", pc(gone.dim), "%, lifted ", round(lift(gone)), " px");
    drive::tap(sh, g, drive::control(g, 0), 26.0);
    for i in 1..6 {
        let t = 26.02 + 0.0625 * i;
        drive::idle(sh, g, t);
        let b .= shell::fill(sh, t);
        print("  ", t, ": ", screen(sh), ", the board dimmed ", pc(b.dim), "%, lifted ", round(lift(b)),
              " px, the card's back ", if sh.from >= 0 { opacity(g, 4) } else { -1.0 }, ", over the UI ", sh.over.len,
              ", on the board ", on_board(sh, g), ", hole ", hole(sh));
    }

    // Portrait: continue; the board goes down and grows.
    drive::size = float2 { 800.0, 1280.0 };
    g = gui::Gui {};
    gui::test_faces(g);
    var q = shell::new(rules::INTERNATIONAL);
    look(q, g, 0.0, "portrait home");
    let top = q.layout.board;
    drive::tap(q, g, drive::tile(g, 1), 1.0);
    var down = true;
    var y = top.y;
    var z = top.z;
    for i in 1..5 {
        look(q, g, 1.02 + 0.0625 * i, "  ");
        if q.layout.board.y < y || q.layout.board.z < z { down = false; }
        y = q.layout.board.y;
        z = q.layout.board.z;
    }
    look(q, g, 1.4, "idle");
    print("the board went down and grew all the way ", down, ", from ", rect(top), " to ", rect(q.layout.board));
    print("the game as opened straight ", arrived(q, g) == straight(q, 1.4));
}
