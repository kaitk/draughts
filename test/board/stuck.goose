// A capture that reaches the far row, dropped and tapped in a game against the computer,
// the child on black and the board turned (reported 2026-11-09: in International a black
// man's capture that looked like it crowned wasn't taken, only take back helped). Each
// line is from the position afresh: "t" taps squares, "d" drags the piece from where it
// is drawn to each square in turn, through the game's frames.
//
// - alone: e3 takes d2 and crowns on c1, tapped or dropped on c1.
// - on, one way: from c1 the capture goes on over b2 to a3 (International crowns only a
//   man that stops on the far row): c1 is a stop the man waits on, a3 then plays the
//   rest, and a3 alone plays the whole of it (2026-11-09: c1 alone played it before).
// - on, two ways: c3 by e1 and g3, then to e5 or i5. e1 is only a stop. The piece waits
//   on it, as in a puzzle; with hints on mistakes nothing shows where it goes on. It used
//   to go back to c3 with e1 ringed, and picked up again it forgot e1, so a drop on g3
//   was wrong and on e1 did nothing: dropped, such a capture was made only by its last
//   square. With move hints, the squares it goes on to (g3) pulse, then g3's next, e5
//   and i5 (the pulse, and through the shell).
// - majority: e3 to c1 takes one, e3 by g5 to e7 two, so c1 is no move. The drop is
//   wrong, and the pieces e3 must take, f4 and f6, pulse beside it.
// - a king takes to the far row; and in Russian a man crowned on the far row mid-capture
//   waits there as a king.
// - after a puzzle left with a piece waiting on a stop, move hints set, and the game come
//   to through the shell: the same as on its own (the puzzle's board is its own).
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
import check from "../";
import drive from "../drive";

// The pointer pressed at a, dragged to c, and lifted there, a frame each step.
fn drop(gm: game::Game&, g: gui::Gui&, l: panel::Layout, a: float2, c: float2, now: f64) {
    drive::frame(gm, g, l, a, true, true, false, now);
    drive::frame(gm, g, l, a + (c - a) * 0.5, true, false, false, now + 0.02);
    drive::frame(gm, g, l, c, true, false, false, now + 0.04);
    drive::frame(gm, g, l, c, false, false, true, now + 0.06);
}

// What the board shows: the selected piece and the square it is drawn on (lifted, or a
// king), the stops ringed, where it goes on (pulsing, and how lit), the wrong square,
// the pieces pulsing red, and the move playing.
fn state(b: board::Board&, l: board::Layout, what: const u8[:], now: f64) {
    let v .= rules::VARIANTS[b.variant];
    board::fill(b, l, now);
    var rings: u8[>..] = [];
    var drawn: u8[>..] = [];
    drawn.append("-");
    for pc in b.pieces {
        let sq = board::hit(l, v, float2 { pc.at.x, pc.at.y });
        if pc.ring.x > 0.0 {
            rings.append(drive::name(v, sq));
            rings.append(" ");
        }
        if pc.look.z == 1.0 { drawn = str(drive::name(v, sq), if pc.look.y > 0.0 { " a king" } else { "" }); }
    }
    var text: u8[>..] = [];
    if b.moving { rules::format_move(text, b.variant, b.move); }
    var lit: u8[>..] = [];
    if drive::marked(v, b.marks.next).len > 0 { lit = str("(", if b.flash.z < 1.0 { "pulsing" } else { "lit" }, ") "); }
    print("  ", what, ": selected ", drive::name(v, b.selected), " drawn on ", drawn,
          ", ringed ", drive::marked(v, b.marks.via), "goes on to ", drive::marked(v, b.marks.next), lit, ", wrong ",
          drive::name(v, b.wrong), ", pulsing ", rings, "playing ", if b.moving { text } else { "-" });
}

// Plays a line, "t c3 e1" or "d c3 e1 g3", on gm's board laid out by l.
fn line(gm: game::Game&, g: gui::Gui&, l: panel::Layout, t: const u8[:], now: f64) -> f64 {
    let v .= rules::VARIANTS[gm.b.variant];
    var t0 = now;
    print(" ", t);
    var a: i64[..8] = [];
    var e: i64[..8] = [];
    var at = 0;
    while at < t.len {
        var end = at;
        while end < t.len && t[end] != ' ' { end++; }
        a.push(at);
        e.push(end);
        at = end + 1;
    }
    if t[0] == 't' {
        for i in 1..a.len {
            drive::tap(gm, g, l, drive::at(l.board, t[a[i]..e[i]]), t0);
            t0 += 0.1;
            state(gm.b, l.board, t[a[i]..e[i]], t0);
        }
    } else {
        for i in 2..a.len {
            let w = board::waiting(gm.b);
            let from = if w >= 0 { drive::name(v, w) } else { str(t[a[1]..e[1]]) };
            drop(gm, g, l, drive::at(l.board, from), drive::at(l.board, t[a[i]..e[i]]), t0);
            t0 += 0.1;
            state(gm.b, l.board, str(from, " to ", t[a[i]..e[i]]), t0);
        }
    }
    return t0;
}

fn run(variant: u8, fen: const u8[:], lines: const u8[:][:]) {
    check::show(variant, fen);
    var l = panel::layout(1280.0, 800.0, rules::VARIANTS[variant].size);
    l.board.flip = true;
    var g = gui::Gui {};
    gui::test_faces(g);
    var gm = game::new(variant);
    var now = 0.0;
    for t in lines {
        game::start(gm, variant, clock::NONE, rules::WHITE, game::MEDIUM, 40, 1);
        board::set(gm.b, check::position(variant, fen));
        gm.turn = gm.b.pos.side;
        now += 10.0;
        drive::idle(gm, g, l, now);
        now = line(gm, g, l, t, now);
    }
}

let FORK = "B:Wd2,f2,f4,h4,j8:Bc3,a9";

fn main() {
    let I: u8 = rules::INTERNATIONAL;
    print("alone: e3 takes d2, crowned on c1");
    run(I, "B:Wd2,j8:Be3,a9", ["t e3 c1", "d e3 c1"]);
    print("on past the far row, one way: e3 by c1 to a3");
    run(I, "B:Wd2,b2,j8:Be3,a9", ["t e3 c1 a3", "d e3 c1 a3", "d e3 a3"]);
    print("on past the far row, two ways: c3 by e1 and g3 to e5 or i5");
    run(I, FORK, ["t c3 e1 g3 e5", "d c3 e1 g3 i5", "d c3 e1 e1", "d c3 e5", "d c3 e1 c3"]);
    print("majority: e3 to c1 takes one, by g5 to e7 two");
    run(I, "B:Wd2,f4,f6,j8:Be3,a9", ["t e3 c1", "d e3 c1", "d e3 e7"]);
    print("a king takes to the far row");
    run(I, "B:Wd2,j8:BKg5,a9", ["d g5 c1"]);
    print("russian: crowned on e1, the king goes on over f2");
    run(rules::RUSSIAN, "B:Wd2,f2,h6:Bc3,a7", ["d c3 e1", "d c3 e1 h4"]);

    // With move hints, the pulse of where the piece goes on ends, and the frame it ends
    // on is drawn.
    print("the pulse of where it goes on, with move hints");
    var l = panel::layout(1280.0, 800.0, 10);
    l.board.flip = true;
    var g = gui::Gui {};
    gui::test_faces(g);
    var gm = game::new(I);
    game::start(gm, I, clock::NONE, rules::WHITE, game::MEDIUM, 40, 1);
    board::set(gm.b, check::position(I, FORK));
    gm.turn = gm.b.pos.side;
    gm.b.hints = board::MOVES;
    drive::idle(gm, g, l, 1.0);
    line(gm, g, l, "d c3 e1", 1.0);
    for t in [2.0, 3.0, 4.0, 5.0] {
        print("  at ", t, " s: animating ", board::animating(gm.b, t), ", an end drawn ", board::update(gm.b, t));
    }
    state(gm.b, l.board, "after", 5.0);

    // Through the shell: a puzzle left with its man waiting on a stop, move hints chosen,
    // then this game against the computer.
    print("after a puzzle and settings, through the shell");
    strings::use(strings::EN);
    puzzles::load();
    var sh = shell::new(I);
    shell::play_puzzle(sh, 12);
    drive::idle(sh, g, 0.0);
    drive::idle(sh, g, 1.0);
    let v .= rules::VARIANTS[I];
    let a = drive::at(sh.out.layout, drive::name(v, v.bit_of[26]));
    let c = drive::at(sh.out.layout, drive::name(v, v.bit_of[17]));
    drive::frame(sh, g, a, true, true, false, 1.1);
    drive::frame(sh, g, a + (c - a) * 0.5, true, false, false, 1.12);
    drive::frame(sh, g, c, true, false, false, 1.14);
    drive::frame(sh, g, c, false, false, true, 1.16);
    print("  the puzzle's man waits on ", drive::name(v, board::waiting(sh.puzzle.b)));
    sh.prefs.hints = board::MOVES;
    shell::apply_prefs(sh);
    shell::go_to(sh, shell::SETTINGS, 2.0);
    for t in [2.0, 2.1, 2.3, 3.0] { drive::idle(sh, g, t); }
    game::start(sh.game, I, clock::NONE, rules::WHITE, game::MEDIUM, 40, 1);
    board::set(sh.game.b, check::position(I, FORK));
    sh.game.turn = sh.game.b.pos.side;
    sh.game.b.hints = sh.prefs.hints;
    shell::go_to(sh, shell::GAME, 4.0);
    for t in [4.0, 4.1, 4.3, 5.0] { drive::idle(sh, g, t); }
    print("  the game: turned ", sh.out.layout.flip, ", by hand ", sh.game.b.by_hand);
    var now = 6.0;
    for to in ["e1", "g3", "e5"] {
        let w = board::waiting(sh.game.b);
        let from = if w >= 0 { drive::name(v, w) } else { str("c3") };
        let p = drive::at(sh.out.layout, from);
        let q = drive::at(sh.out.layout, to);
        drive::frame(sh, g, p, true, true, false, now);
        drive::frame(sh, g, p + (q - p) * 0.5, true, false, false, now + 0.02);
        drive::frame(sh, g, q, true, false, false, now + 0.04);
        drive::frame(sh, g, q, false, false, true, now + 0.06);
        drive::idle(sh, g, now + 0.08);
        now += 0.1;
        let b .= shell::fill(sh, now);
        state(b, sh.out.layout, str(from, " to ", to), now);
        print("    targets ", drive::marked(v, b.marks.target));
    }
}
