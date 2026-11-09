// A capture played as a child plays it, through the game's frames and pointer, from a
// real case (2026-11-09): a child on black against the computer, the board turned, had a
// lone king that pulsed must-capture, and nothing said how far its capture went; once he
// played the first jump, the game played the rest, so he never learned the way.
//
// - The count: a piece that must capture shows how many pieces it takes, at most, as
//   pips on its ring (Piece.ring.z), shown here with move hints: pieces, not stops or
//   squares a flying king could land on. A man's double shows 2; the child's king 4. Under the
//   majority rule only the pieces taking the most show it, each of them; in Russian each
//   piece shows its own most. The computer's pieces show none, a friend's do. Partway
//   through a capture only the piece making it shows what is left. On mistakes only, the
//   rest of this test's hints, the count shows only from a wrong square to the next
//   right jump (test/game/pips has it in full).
// - No autocomplete: after a jump, tapped or dropped, the piece waits on its stop and
//   each next jump is the child's, to the last.
// - The last square tapped straight away plays the capture, the one capture going there.
// - Hints only after a miss: the first wrong square pulses the pieces still to take and
//   leaves the piece on its stop; the second lights the next stop as a pulsing dot, and
//   so on for the rest of the capture.
// - Take back mid-capture takes the capture back to its start, no move taken back.
//
// The child's position, read from a photo of the tablet (white men on j2, b4, d4, f4,
// e5, h6, white kings on b6 and b10, black's king on j4, seen on the left edge on the
// turned board): the king takes h6, b6, b4, and f4, ending on g5, its only move
// (test/perft.py moves international gives "35 29 21 24 31 33").
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

let PHOTO = "B:WK1,K21,24,28,31,32,33,45:BK35";
let UNDO = 3;       // take back, among the game's controls (drive::control)

var l: panel::Layout;
var g: gui::Gui;
var now = 0.0;

// A new game against the computer on `computer` (-1 a friend) from fen, turned when the
// child plays black.
fn begin(gm: game::Game&, variant: u8, fen: const u8[:], computer: i64) {
    l = panel::layout(1280.0, 800.0, rules::VARIANTS[variant].size);
    l.board.flip = computer == rules::WHITE;
    game::start(gm, variant, clock::NONE, computer, game::MEDIUM, 40, 1);
    board::set(gm.b, check::position(variant, fen));
    gm.b.hints = board::MISTAKES;
    gm.turn = gm.b.pos.side;
    now += 10.0;
    drive::idle(gm, g, l, now);
}

// The pieces showing a count, with it.
fn counts(gm: game::Game&) -> u8[>..] {
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    board::fill(b, l.board, now + 0.3);     // a moment on, where a pulse shows
    var out: u8[>..] = [];
    for pc in b.pieces {
        guard pc.ring.z > 0.0 else { continue; }
        format(out, drive::name(v, board::hit(l.board, v, float2 { pc.at.x, pc.at.y })), " ", pc.ring.z as i64, " ");
    }
    return out;
}

// What the board shows after a step.
fn state(gm: game::Game&, what: const u8[:]) {
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    let shown = counts(gm);
    var rings: u8[>..] = [];
    for pc in b.pieces {
        if pc.ring.x > 0.0 { format(rings, drive::name(v, board::hit(l.board, v, float2 { pc.at.x, pc.at.y })), " "); }
    }
    var text: u8[>..] = [];
    if b.moving { rules::format_move(text, b.variant, b.move); } else { text.append("-"); }
    var lit: u8[>..] = [];
    if drive::marked(v, b.marks.next).len > 0 { lit = str("(", if b.flash.z < 1.0 { "pulsing" } else { "lit" }, ") "); }
    print("  ", what, ": waits on ", drive::name(v, board::waiting(b)), ", counts ", shown, ", wrong ",
          drive::name(v, b.wrong), ", pulsing ", rings, "next ", drive::marked(v, b.marks.next), lit, "playing ", text);
}

fn tap(gm: game::Game&, sq: i64) {
    let v .= rules::VARIANTS[gm.b.variant];
    now += 0.1;
    drive::tap(gm, g, l, drive::at(l.board, drive::name(v, sq)), now);
}

// The piece dragged from where it is drawn to sq and dropped there, a frame each step.
fn drop(gm: game::Game&, from: i64, sq: i64) {
    let v .= rules::VARIANTS[gm.b.variant];
    let a = drive::at(l.board, drive::name(v, from));
    let c = drive::at(l.board, drive::name(v, sq));
    now += 0.1;
    drive::frame(gm, g, l, a, true, true, false, now);
    drive::frame(gm, g, l, a + (c - a) * 0.5, true, false, false, now + 0.02);
    drive::frame(gm, g, l, c, true, false, false, now + 0.04);
    drive::frame(gm, g, l, c, false, false, true, now + 0.06);
}

fn named(gm: game::Game&, sq: i64) -> u8[>..] { drive::name(rules::VARIANTS[gm.b.variant], sq) }

// The counts of a position, in a game against the computer on `computer`.
fn shows(variant: u8, fen: const u8[:], computer: i64, what: const u8[:]) {
    var gm = game::new(variant);
    begin(gm, variant, fen, computer);
    gm.b.hints = board::MOVES;
    print(what, ": counts ", counts(gm));
}

fn main() {
    strings::use(strings::EN);
    gui::test_faces(g);
    let I: u8 = rules::INTERNATIONAL;

    print("the count");
    check::show(I, "W:W37,39,43,46:B23,32,34");
    shows(I, "W:W37,39,43,46:B23,32,34", rules::BLACK, "a man's double");
    shows(I, "W:W37,39,43,46:B23,32,34", rules::WHITE, "  the computer's turn");
    shows(I, "W:W37,39,43,46:B23,32,34", -1, "  a friend's");
    check::show(I, PHOTO);
    shows(I, PHOTO, rules::WHITE, "the child's king");
    check::show(I, "W:Wc3,h4:Bd4,g5");
    shows(I, "W:Wc3,h4:Bd4,g5", -1, "two pieces taking one each");
    check::show(I, "W:Wc3,h2:Bd4,f6,g3");
    shows(I, "W:Wc3,h2:Bd4,f6,g3", -1, "the majority rule, c3 two and h2 one");
    check::show(rules::RUSSIAN, "W:Wc3,h2:Bd4,f6,g3");
    shows(rules::RUSSIAN, "W:Wc3,h2:Bd4,f6,g3", -1, "russian, any capture");
    check::show(I, "W:WK46:B37,27,17,18,29,39");
    shows(I, "W:WK46:B37,27,17,18,29,39", -1, "a king's capture of six, past five pips");

    var gm = game::new(I);
    begin(gm, I, PHOTO, rules::WHITE);
    let k = gm.b.moves[0];
    var way: u8[>..] = [];
    for s in k.path { format(way, named(gm, s), " "); }
    print("the child's king, its way ", way);

    print("tapped stop by stop");
    tap(gm, k.from);
    state(gm, named(gm, k.from));
    for i in 1..k.path.len {
        tap(gm, k.path[i]);
        state(gm, named(gm, k.path[i]));
    }
    now += 2.0;
    drive::idle(gm, g, l, now);
    print("  ", rules::fen(gm.b.pos));

    print("dropped stop by stop");
    begin(gm, I, PHOTO, rules::WHITE);
    for i in 1..k.path.len {
        drop(gm, k.path[i - 1], k.path[i]);
        state(gm, str(named(gm, k.path[i - 1]), " to ", named(gm, k.path[i])));
    }

    print("straight to the last square");
    begin(gm, I, PHOTO, rules::WHITE);
    tap(gm, k.from);
    tap(gm, k.to);
    state(gm, named(gm, k.to));
    begin(gm, I, PHOTO, rules::WHITE);
    drop(gm, k.from, k.to);
    state(gm, str(named(gm, k.from), " to ", named(gm, k.to)));

    print("two wrong squares");
    let v .= rules::VARIANTS[I];
    let off = v.bit_of[50];     // empty, on no way
    begin(gm, I, PHOTO, rules::WHITE);
    tap(gm, k.from);
    tap(gm, k.path[1]);
    state(gm, named(gm, k.path[1]));
    tap(gm, off);
    state(gm, str(named(gm, off), ", wrong"));
    now += 3.0;
    drive::idle(gm, g, l, now);
    tap(gm, off);
    state(gm, str(named(gm, off), " again"));
    tap(gm, k.path[2]);
    state(gm, named(gm, k.path[2]));
    now += 3.0;
    drive::idle(gm, g, l, now);
    state(gm, "a moment later");
    print("  with move hints, from the first stop");
    begin(gm, I, PHOTO, rules::WHITE);
    gm.b.hints = board::MOVES;
    tap(gm, k.from);
    tap(gm, k.path[1]);
    state(gm, named(gm, k.path[1]));

    print("take back mid-capture");
    begin(gm, I, PHOTO, rules::WHITE);
    tap(gm, k.from);
    tap(gm, k.path[1]);
    tap(gm, k.path[2]);
    state(gm, named(gm, k.path[2]));
    now += 0.1;
    drive::tap(gm, g, l, drive::control(g, UNDO), now);
    state(gm, "take back");
    print("  ", rules::fen(gm.b.pos), ", history ", gm.b.history.len, ", selected ", named(gm, gm.b.selected));
    tap(gm, k.from);
    tap(gm, k.path[1]);
    state(gm, str(named(gm, k.from), ", ", named(gm, k.path[1]), " again"));
}
