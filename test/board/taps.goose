// What taps and drags on the board do, on a 1280×800 landscape screen, through the
// same calls the app makes: layout, which square a point is on, selecting, playing a
// move by tap and by drag, the pulse when a piece that can't move is touched while
// another must capture, the draw lists for one frame, and that the frame after an
// animation ends is drawn (else the last move's marks or a pulse ring would stay as the
// last animated frame left them).
import std;
import vec;
import rules from "../../rules";
import board from "../../board";

fn name(v: rules::Variant&, sq: i64) -> u8[>..] {
    if sq < 0 { return str("-"); }
    var s: u8[>..] = [];
    s.push(97 + v.x_of[sq]);
    format(s, v.y_of[sq] as i64 + 1);
    return s;
}

fn square(v: rules::Variant&, text: const u8[:]) -> i64 {
    return board::bit_at(v, text[0] - 97, text[1] - 49);
}

// The squares a mark set holds, by name.
fn marked(v: rules::Variant&, bits: u32[4]&) -> u8[>..] {
    var s: u8[>..] = [];
    for y in v.size {
        for x in v.size {
            let n = y * v.size + x;
            if (bits[n / 32] >> (n % 32)) & 1 != 0 { s.append(name(v, board::bit_at(v, x, y))); s.append(" "); }
        }
    }
    return s;
}

fn tap(b: board::Board&, l: board::Layout, text: const u8[:], now: f64) {
    let v .= rules::VARIANTS[b.variant];
    let p = board::center(l, v, square(v, text));
    board::update(b, now);
    board::press(b, l, p, now);
    board::release(b, l, p, now);
    print("tap ", text, ": selected ", name(v, b.selected), ", moving ", b.moving,
          ", pulse ", b.pulse_end > now);
}

fn main() {
    let v .= rules::VARIANTS[rules::RUSSIAN];
    let l = board::layout(1280.0, 800.0, 8);
    print("board ", l.board, " square ", l.inner.w, " panel ", l.panel);
    let p = board::layout(800.0, 1280.0, 8);
    print("portrait board ", p.board, " panel ", p.panel);
    // The corners of the squares: a1 bottom left, h8 top right; the frame is no square.
    print("hits: ", name(v, board::hit(l, v, float2 { l.inner.x + 1.0, l.inner.y + l.inner.z - 1.0 })),
          " ", name(v, board::hit(l, v, float2 { l.inner.x + l.inner.z - 1.0, l.inner.y + 1.0 })),
          " ", name(v, board::hit(l, v, float2 { l.board.x + 2.0, l.board.y + 2.0 })));

    var b = board::new(rules::RUSSIAN);
    tap(b, l, "c3", 0.0);       // selects
    board::fill(b, l, 0.0);
    print("targets ", marked(v, b.marks.target), ", pieces ", b.pieces.len);
    tap(b, l, "d4", 0.1);       // plays c3-d4
    board::update(b, 0.2);
    print("at 0.2 s: moving ", b.moving);
    print("the frame that ends it is drawn: ", board::update(b, 0.35));
    print("after ", board::duration(b.move), " s: moving ", b.moving, ", ", rules::fen(b.pos));

    // Black to move: drag f6 to e5 by way of a point past the drag threshold.
    let from = board::center(l, v, square(v, "f6"));
    let to = board::center(l, v, square(v, "e5"));
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
