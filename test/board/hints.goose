// Move hints (docs/product.md). By default they show mistakes only: selecting a piece
// marks no targets, and a tap or a drop on an empty square that isn't a move flashes a
// red ring there for 1.2 s, with the piece kept selected. When a capture is due, the
// mistake also pulses the pieces that must capture, as touching a piece that can't move
// does. With hints on moves, the targets are marked as well.
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

fn at(l: board::Layout, v: rules::Variant&, text: const u8[:]) -> float2 {
    return board::center(l, v, rules::bit_at(v, text[0] - 97, text[1] - 49));
}

fn targets(b: board::Board&) -> i64 {
    var n = 0;
    for i in 4 { n += popcount(b.marks.target[i]); }
    return n;
}

fn show(b: board::Board&, l: board::Layout, what: const u8[:], now: f64) {
    let v .= rules::VARIANTS[b.variant];
    board::fill(b, l, now);
    var rings = 0;
    for i in b.pieces.len { if b.pieces[i].ring.x > 0.0 { rings++; } }
    print(what, ": selected ", name(v, b.selected), ", targets ", targets(b), ", wrong ",
          name(v, b.wrong), " flash ", b.flash.x, " at ", b.flash.y, ", pulsing ", rings);
}

fn tap(b: board::Board&, l: board::Layout, text: const u8[:], now: f64) {
    let p = at(l, rules::VARIANTS[b.variant], text);
    board::update(b, now);
    board::press(b, l, p, now);
    board::release(b, l, p, now);
}

fn main() {
    let v .= rules::VARIANTS[rules::RUSSIAN];
    let l = board::layout(1280.0, 800.0, 8);

    var b = board::new(rules::RUSSIAN);
    print("default hints are mistakes: ", b.hints == board::MISTAKES);
    tap(b, l, "c3", 0.0);
    show(b, l, "c3 selected", 0.0);
    tap(b, l, "c5", 0.1);                   // two squares up: not a move
    show(b, l, "tap c5", 0.4);
    print("animating at 1.2 s: ", board::animating(b, 1.2), ", at 1.4 s: ", board::animating(b, 1.4),
          ", the frame that ends it is drawn: ", board::update(b, 1.4));
    show(b, l, "after the flash", 1.4);
    tap(b, l, "b6", 1.5);                   // the other side's piece: not a mistake, deselects
    show(b, l, "tap b6", 1.5);

    // A drag dropped on an empty square that isn't a move.
    board::press(b, l, at(l, v, "e3"), 2.0);
    board::drag(b, l, at(l, v, "e3") + float2 { 40.0, -40.0 });
    board::release(b, l, at(l, v, "e5"), 2.1);
    show(b, l, "drop e3 on e5", 2.1);

    // White must take d4xf6: a quiet move by another piece is a mistake, and d4 pulses.
    let pos, ok = rules::parse_fen("W:Wd4,a3:Be5,h8", rules::RUSSIAN);
    assert(ok);
    board::set(b, pos);
    tap(b, l, "d4", 3.0);
    tap(b, l, "c5", 3.1);                   // d4 selected, c5 isn't the capture
    show(b, l, "d4 to c5 with a capture due", 3.2);
    tap(b, l, "a3", 5.0);                   // can't move while d4 must take
    show(b, l, "touch a3", 5.0);

    b.hints = board::MOVES;
    tap(b, l, "d4", 7.0);
    show(b, l, "hints on moves, d4 selected", 7.0);
}
