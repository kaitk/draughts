// When a piece that must capture shows how many pieces it takes, as pips (Piece.ring.z),
// played through the game's frames and pointer (2026-11-09, docs/product.md). Showing
// the count up front gave the capture away, so on mistakes only, the default, it is a
// mistake's hint: no pips until a wrong move, a wrong square or a touch on a piece that
// can't move because another must capture; from it to the next right move or jump they
// show, then they hide until another mistake, which shows what is left of the capture.
// A new turn starts with none. With move hints they show at once and count down. The 3D
// board shows the same pips, from the same draw lists (view3d::Scene.lit's z).
//
// After a second wrong square in the same capture, the flat board lights where the
// waiting piece goes on to (board::Marks.next), pulsing (Board.flash.z) and then still;
// the 3D board lights the same squares (Scene.lit's w: 2 pulsing over the image at
// Scene.next, 1 still), shown after the pips as `next`; while they pulse, a frame on
// draws only the marks over the kept image again.
//
// The capture is a child's lone king on the turned board taking four, j4 e9 a5 d2 g5
// (test/board/count's photo); the new turn, a white man's capture after which black's
// man on 22 must take it back, in a friend's game.
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
let TURNS = "W:W37,46:B17,22,32";
let I: u8 = rules::INTERNATIONAL;

var l:  panel::Layout;
var l3: panel::Layout;
var g:  gui::Gui;
var now = 0.0;

// A new game from fen, against the computer on `computer` (-1 a friend), with `hints`.
fn begin(gm: game::Game&, fen: const u8[:], computer: i64, hints: i64) {
    l = panel::layout(1280.0, 800.0, 10);
    l.board.flip = computer == rules::WHITE;
    l3 = panel::corners_in(float4 { 0.0, 0.0, 1280.0, 800.0 }, 10, 1.0);
    l3.board.flip = l.board.flip;
    game::start(gm, I, clock::NONE, computer, game::MEDIUM, 40, 1);
    board::set(gm.b, check::position(I, fen));
    gm.b.hints = hints;
    gm.turn = gm.b.pos.side;
    now += 10.0;
    drive::idle(gm, g, l, now);
}

// The pieces showing a count on the flat board, with it, a moment on; then the 3D
// board's, by its world grid's row.column.
fn state(gm: game::Game&, what: const u8[:]) {
    let b .= gm.b;
    let v .= rules::VARIANTS[I];
    board::fill(b, l.board, now + 0.3);
    var flat: u8[>..] = [];
    for pc in b.pieces {
        guard pc.ring.z > 0.0 else { continue; }
        format(flat, drive::name(v, board::hit(l.board, v, float2 { pc.at.x, pc.at.y })), " ", pc.ring.z as i64, " ");
    }
    board::fill(b, l3.board, now + 0.3);
    var s = view3d::Scene {};
    view3d::fill(s, b, l3.board, l3.view, now + 0.3);
    var deep: u8[>..] = [];
    for i in 100 {
        if s.lit[i].z > 0.0 { format(deep, i / 10, ".", i % 10, " ", s.lit[i].z as i64, " "); }
    }
    var next: u8[>..] = [];
    for sq in v.size * v.size {
        guard (b.marks.next[sq / 32] >> (sq % 32)) & 1 != 0 else { continue; }
        let at = rules::bit_at(v, sq % v.size, sq / v.size);
        format(next, drive::name(v, at), " ");
    }
    var next3: u8[>..] = [];
    for i in 100 {
        if s.lit[i].w > 0.0 { format(next3, i / 10, ".", i % 10, if s.lit[i].w > 1.5 { " pulsing " } else { " " }); }
    }
    print("  ", what, ": pips ", flat, "| 3D ", deep, "| wrong ", drive::name(v, b.wrong));
    if next.len > 0 || next3.len > 0 {
        print("    next ", next, "| 3D ", next3, "| lit ", (b.flash.z * 100.0 + 0.5) as i64, "% and ",
              (s.next * 100.0 + 0.5) as i64, "%");
    }
    if s.next < 1.0 {
        // A frame on, only the marks over the kept image are drawn again (MARKS, 4).
        board::fill(b, l3.board, now + 0.4);
        var on = view3d::Scene {};
        view3d::fill(on, b, l3.board, l3.view, now + 0.4);
        print("    a frame on: changes ", view3d::changes(s, on), ", lit ", (on.next * 100.0 + 0.5) as i64, "%");
    }
}

fn tap(gm: game::Game&, sq: i64) {
    now += 0.1;
    drive::tap(gm, g, l, drive::at(l.board, drive::name(rules::VARIANTS[I], sq)), now);
}

fn named(sq: i64) -> u8[>..] { drive::name(rules::VARIANTS[I], sq) }

fn main() {
    strings::use(strings::EN);
    gui::test_faces(g);
    let v .= rules::VARIANTS[I];
    let off = v.bit_of[50];     // empty, on no way

    print("mistakes only");
    var gm = game::new(I);
    begin(gm, PHOTO, rules::WHITE, board::MISTAKES);
    let k = gm.b.moves[0];
    state(gm, "the start");
    tap(gm, k.from);
    state(gm, str(named(k.from), " picked"));
    tap(gm, off);
    state(gm, str(named(off), ", wrong"));
    tap(gm, k.path[1]);
    state(gm, str(named(k.path[1]), ", right"));
    tap(gm, k.path[2]);
    state(gm, str(named(k.path[2]), ", right"));
    tap(gm, off);
    state(gm, str(named(off), ", wrong again"));
    now += 3.0;
    drive::idle(gm, g, l, now);
    state(gm, "after the pulse");
    tap(gm, k.path[3]);
    state(gm, str(named(k.path[3]), ", right"));
    tap(gm, k.to);
    state(gm, str(named(k.to), ", the last"));

    print("a touch on a piece that can't move, then a new turn");
    begin(gm, TURNS, -1, board::MISTAKES);
    let blocked = v.bit_of[46];
    let man = gm.b.moves[0];
    state(gm, "white to move");
    tap(gm, blocked);
    state(gm, str(named(blocked), " touched"));
    tap(gm, man.from);
    state(gm, str(named(man.from), " picked"));
    tap(gm, man.to);
    now += 3.0;
    drive::idle(gm, g, l, now);
    state(gm, str(named(man.from), " took one, black must take"));
    let stuck = v.bit_of[17];
    tap(gm, stuck);
    state(gm, str(named(stuck), " touched"));

    print("all moves");
    begin(gm, PHOTO, rules::WHITE, board::MOVES);
    state(gm, "the start");
    tap(gm, k.from);
    for i in 1..k.path.len - 1 {
        tap(gm, k.path[i]);
        state(gm, named(k.path[i]));
    }
}
