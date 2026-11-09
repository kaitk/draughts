// What taps and drags on the board do, on a 1280×800 landscape screen, through the
// same calls the app makes: layout, which square a point is on, selecting, playing a
// move by tap and by drag, the pulse when a piece that can't move is touched while
// another must capture, the draw lists for one frame, and that the frame after an
// animation ends is drawn (else the last move's marks or a pulse ring would stay as the
// last animated frame left them).
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

fn tap(b: board::Board&, l: board::Layout, text: const u8[:], now: f64) {
    let v .= rules::VARIANTS[b.variant];
    let p = board::center(l, v, drive::square(v, text));
    board::update(b, now);
    board::press(b, l, p, now);
    board::release(b, l, p, now);
    print("tap ", text, ": selected ", drive::name(v, b.selected), ", moving ", b.moving,
          ", pulse ", b.pulse_end > now);
}

fn main() {
    let v .= rules::VARIANTS[rules::RUSSIAN];
    let gl = panel::layout(1280.0, 800.0, 8);
    let l = gl.board;
    print("board ", l.board, " square ", l.inner.w, " panels ", gl.left, " ", gl.right);
    let p = panel::layout(800.0, 1280.0, 8);
    print("portrait board ", p.board.board, " panels ", p.left, " ", p.right);
    // The corners of the squares: a1 bottom left, h8 top right; just off the board is no square.
    print("hits: ", drive::name(v, board::hit(l, v, float2 { l.inner.x + 1.0, l.inner.y + l.inner.z - 1.0 })),
          " ", drive::name(v, board::hit(l, v, float2 { l.inner.x + l.inner.z - 1.0, l.inner.y + 1.0 })),
          " ", drive::name(v, board::hit(l, v, float2 { l.board.x - 2.0, l.board.y + l.board.z - 2.0 })));

    var b = board::new(rules::RUSSIAN);
    b.hints = board::MOVES;     // to see the targets; test/board/hints.goose has the default
    tap(b, l, "c3", 0.0);       // selects
    board::fill(b, l, 0.0);
    print("targets ", drive::marked(v, b.marks.target), ", pieces ", b.pieces.len);
    tap(b, l, "d4", 0.1);       // plays c3-d4
    board::update(b, 0.2);
    print("at 0.2 s: moving ", b.moving);
    print("the frame that ends it is drawn: ", board::update(b, 0.35));
    print("after ", board::duration(b.move), " s: moving ", b.moving, ", ", rules::fen(b.pos));

    // Black to move: drag f6 to e5 by way of a point past the drag threshold.
    let from = board::center(l, v, drive::square(v, "f6"));
    let to = board::center(l, v, drive::square(v, "e5"));
    board::update(b, 1.0);
    board::press(b, l, from, 1.0);
    print("drag starts: ", board::drag(b, l, from + float2 { 30.0, 30.0 }), ", dragging ", b.dragging);
    board::fill(b, l, 1.0);
    print("dragged piece last: ", b.pieces[b.pieces.len - 1].at.x == from.x + 30.0);
    board::release(b, l, to, 1.1);
    board::update(b, 1.5);
    print(rules::fen(b.pos));

    // White must take d4xf6; touching g3, which can't move, pulses d4's ring.
    tap(b, l, "g3", 2.0);
    board::fill(b, l, 2.0);
    var rings = 0;
    for i in b.pieces.len { if b.pieces[i].ring.x > 0.0 { rings++; } }
    print("rings ", rings, ", animating ", board::animating(b, 2.0), " then ", board::animating(b, 5.0),
          ", the frame that ends it is drawn: ", board::update(b, 5.0));
}
