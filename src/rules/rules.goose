// The rules of draughts as pure functions over values, with no graphics:
// positions, legal moves, and playing a move. The variant is data
// (docs/architecture/rules.md): Russian 8×8, International 10×10, English 8×8,
// and Brazilian 8×8 differ only in the fields of a `Variant`.
//
// The board is one bit per dark square, with a ghost bit before each odd row,
// so every diagonal step is a fixed shift and a step off the board lands on a
// ghost bit or outside the mask. Square (x, y), with a1 at (0, 0) and dark
// where x + y is even, is bit `y * h + x / 2 + (y + 1) / 2`, h being the dark
// squares per row: 36 bits for 8×8 and 55 for 10×10. Steps: up-left +h,
// up-right +h + 1, down-left -(h + 1), down-right -h.
//
// Nothing here allocates: moves go into a `Moves` buffer the caller owns.
namespace rules;
import std;
import .fen;

let WHITE = 0;
let BLACK = 1;

let RUSSIAN = 0;
let INTERNATIONAL = 1;
let ENGLISH = 2;
let BRAZILIAN = 3;
let VARIANT_COUNT = 4;
// The variants' names, in RUSSIAN.. order: as the files name them (settings' `draughts`,
// the puzzles' `variant` and `stars.NAME`), the --variant flag, and the tools.
let VARIANT_NAMES = ["russian", "international", "english", "brazilian"];

// The variant a name in VARIANT_NAMES stands for; false for any other name.
fn variant_named(name: const u8[:]) -> u8, bool {
    for n, v in VARIANT_NAMES { if name == n { return v as u8, true; } }
    return 0, false;
}

// What happens when a man reaches the far row in the middle of a capture.
let CROWN_CONTINUES = 0;    // Russian: crowned at once, keeps capturing as a king
let CROWN_AT_END = 1;       // International, Brazilian: crowned only if the move ends there
let CROWN_ENDS_MOVE = 2;    // English: crowned, and the move ends

// Room for the longest move: a capture's stops, from the start square on.
// A 10×10 board has 32 squares a piece can be captured on.
let MAX_PATH = 34;
// Room for every legal move of any position reached in play, with margin.
let MAX_MOVES = 512;

struct Variant {
    size:          i64,     // squares per side: 8 or 10
    h:             i64,     // dark squares per row
    rows:          i64,     // rows of men each side starts with
    back_captures: bool,    // men capture backward
    flying:        bool,    // kings move and capture any distance
    majority:      bool,    // a capture must take the most pieces
    crowning:      i64,     // CROWN_*
    first:         u8,      // the side that moves first
    algebraic:     bool,    // squares written a1..h8 rather than numbered
    // Derived by make_variant.
    mask:      u64,         // every dark square
    promotion: u64[2],      // the row each side crowns on
    start:     u64[2],      // each side's men at the start
    delta:     i64[4],      // the four steps: up-left, up-right, down-left, down-right
    bit_of:    u8[51],      // square number (1-based, PDN order) to bit
    number_of: u8[64],      // bit to square number, 0 for none
    x_of:      u8[64],      // bit to column, from a
    y_of:      u8[64],      // bit to row, from 1
}

// A position: pieces by side, which of them are kings, side to move, variant.
struct Position { pieces: u64[2], kings: u64, side: u8, variant: u8 }

// A move: where the piece starts and ends, the pieces it takes, whether it
// is crowned, and its stops (from first, to last) for showing it.
struct Move { from: u8, to: u8, crowned: bool, captured: u64, path: u8[..MAX_PATH] }

type Moves = Move[..MAX_MOVES];
type Path = u8[..MAX_PATH];

fn bit(n: i64) -> u64 { (1 as u64) << n }

// A square as its bit, from its column and row (a1 is 0, 0); -1 off the board or on a
// light square.
fn bit_at(v: Variant&, x: i64, y: i64) -> i64 {
    guard x >= 0 && y >= 0 && x < v.size && y < v.size && (x + y) % 2 == 0 else { return -1; }
    return y * v.h + x / 2 + (y + 1) / 2;
}

fn make_variant(size: i64, rows: i64, back_captures: bool, flying: bool, majority: bool,
                crowning: i64, first: u8, algebraic: bool) -> Variant {
    let h = size / 2;
    var v = Variant { size: size, h: h, rows: rows, back_captures: back_captures,
                      flying: flying, majority: majority, crowning: crowning, first: first,
                      algebraic: algebraic, .. };
    v.delta = [h, h + 1, -(h + 1), -h];
    for y in size {
        for x in size {
            let b = bit_at(v, x, y);
            guard b >= 0 else { continue; }
            let number = (size - 1 - y) * h + x / 2 + 1;
            v.mask |= bit(b);
            if y == size - 1 { v.promotion[WHITE] |= bit(b); }
            if y == 0 { v.promotion[BLACK] |= bit(b); }
            if y < rows { v.start[WHITE] |= bit(b); }
            if y >= size - rows { v.start[BLACK] |= bit(b); }
            v.bit_of[number] = b as u8;
            v.number_of[b] = number as u8;
            v.x_of[b] = x as u8;
            v.y_of[b] = y as u8;
        }
    }
    return v;
}

let VARIANTS: Variant[VARIANT_COUNT] = [
    make_variant(8, 3, true, true, false, CROWN_CONTINUES, WHITE, true),
    make_variant(10, 4, true, true, true, CROWN_AT_END, WHITE, false),
    make_variant(8, 3, false, false, false, CROWN_ENDS_MOVE, BLACK, false),
    make_variant(8, 3, true, true, true, CROWN_AT_END, WHITE, true),
];

fn start(variant: u8) -> Position {
    let v .= VARIANTS[variant];
    return Position { pieces: v.start, kings: 0, side: v.first, variant: variant };
}

// The number of dark squares, the highest square number.
fn squares(variant: u8) -> i64 { VARIANTS[variant].size * VARIANTS[variant].h }

fn on_board(v: Variant&, n: i64) -> bool { n >= 0 && n < 64 && (v.mask >> n) & 1 != 0 }

fn occupied(p: Position) -> u64 { p.pieces[WHITE] | p.pieces[BLACK] }

// What a capture search keeps fixed while it walks the jumps of one piece.
struct Search {
    side:  u8,
    from:  u8,
    opp:   u64,     // the opponent's pieces, those taken included: they stay until the move ends
    occ:   u64,     // every piece but the one moving
    first: i64,     // where this piece's captures start in the buffer
    best:  i64,     // the most pieces any capture so far takes, under the majority rule
}

// Whether a piece on sq can take anything, with `taken` already taken.
fn can_take(v: Variant&, s: Search&, sq: i64, king: bool, taken: u64) -> bool {
    for d in 4 {
        let step = v.delta[d];
        var n = sq + step;
        if king && v.flying {
            while on_board(v, n) && s.occ & bit(n) == 0 { n += step; }
        } else if !king && !v.back_captures && (d < 2) != (s.side == WHITE) {
            continue;
        }
        guard on_board(v, n) && s.opp & ~taken & bit(n) != 0 else { continue; }
        let l = n + step;
        if on_board(v, l) && s.occ & bit(l) == 0 { return true; }
    }
    return false;
}

// Adds a finished capture, unless the same piece already has one with the same
// end and the same pieces taken, or the majority rule rules it out.
fn record(v: Variant&, s: Search&, to: i64, crowned: bool, taken: u64, path: Path&,
          out: Moves&) {
    if v.majority {
        let n = popcount(taken);
        if n < s.best { return; }
        if n > s.best {
            s.best = n;
            out.clear();
            s.first = 0;
        }
    }
    for i in s.first..out.len {
        if out[i].to == to && out[i].captured == taken { return; }
    }
    assert(out.len < MAX_MOVES);
    out.push(Move { from: s.from, to: to as u8, crowned: crowned, captured: taken, path: path });
}

// Every way the piece on sq continues its capture, recorded when it can't.
recursive fn jump(v: Variant&, s: Search&, sq: i64, king: bool, crowned: bool, taken: u64,
                  path: Path&, out: Moves&) {
    var found = false;
    for d in 4 {
        let step = v.delta[d];
        if king && v.flying {
            var n = sq + step;
            while on_board(v, n) && s.occ & bit(n) == 0 { n += step; }
            guard on_board(v, n) && s.opp & ~taken & bit(n) != 0 else { continue; }
            let now = taken | bit(n);
            // A king lands where the capture goes on, if it can anywhere.
            var onward = false;
            var l = n + step;
            while on_board(v, l) && s.occ & bit(l) == 0 {
                if can_take(v, s, l, true, now) { onward = true; break; }
                l += step;
            }
            l = n + step;
            while on_board(v, l) && s.occ & bit(l) == 0 {
                if !onward || can_take(v, s, l, true, now) {
                    found = true;
                    path.push(l as u8);
                    jump(v, s, l, true, crowned, now, path, out);
                    path.pop();
                }
                l += step;
            }
            continue;
        }
        if !king && !v.back_captures && (d < 2) != (s.side == WHITE) { continue; }
        let n = sq + step;
        guard on_board(v, n) && s.opp & ~taken & bit(n) != 0 else { continue; }
        let l = n + step;
        guard on_board(v, l) && s.occ & bit(l) == 0 else { continue; }
        found = true;
        let now = taken | bit(n);
        path.push(l as u8);
        if !king && v.promotion[s.side] & bit(l) != 0 && v.crowning != CROWN_AT_END {
            if v.crowning == CROWN_CONTINUES {
                jump(v, s, l, true, true, now, path, out);
            } else {
                record(v, s, l, true, now, path, out);
            }
        } else {
            jump(v, s, l, king, crowned, now, path, out);
        }
        path.pop();
    }
    if !found && taken != 0 {
        let ends_crowned = crowned || (!king && v.promotion[s.side] & bit(sq) != 0);
        record(v, s, sq, ends_crowned, taken, path, out);
    }
}

fn captures(p: Position, v: Variant&, out: Moves&) {
    let side = p.side;
    let own = p.pieces[side];
    let opp = p.pieces[1 - side];
    let empty = v.mask & ~(own | opp);
    // Men that can take, found for all of them at once: an opponent one step
    // away and an empty square behind it.
    var men: u64 = 0;
    for d in 4 {
        if !v.back_captures && (d < 2) != (side == WHITE) { continue; }
        let step = v.delta[d];
        men |= if step > 0 { (opp >> step) & (empty >> (2 * step)) }
               else { (opp << -step) & (empty << (-2 * step)) };
    }
    var movers = (own & ~p.kings & men) | (own & p.kings);
    var s = Search { side: side, from: 0, opp: opp, occ: 0, first: 0, best: 1 };
    var path: Path = [];
    while movers != 0 {
        let from = ctz(movers);
        movers &= movers - 1;
        s.from = from as u8;
        s.occ = (own | opp) & ~bit(from);
        s.first = out.len;
        path.clear();
        path.push(from as u8);
        jump(v, s, from, p.kings & bit(from) != 0, false, 0, path, out);
    }
}

// Whether the side to move's piece on sq could take anything, legal or not: under the
// majority rule a piece that takes fewer than another has no move, yet a child sees it
// can take (the board says why it may not).
fn can_take_from(p: Position, sq: i64) -> bool {
    let v .= VARIANTS[p.variant];
    guard sq >= 0 && p.pieces[p.side] & bit(sq) != 0 else { return false; }
    let s = Search { side: p.side, from: sq as u8, opp: p.pieces[1 - p.side],
                     occ: occupied(p) & ~bit(sq), first: 0, best: 1 };
    return can_take(v, s, sq, p.kings & bit(sq) != 0, 0);
}

fn quiet(p: Position, v: Variant&, out: Moves&) {
    let side = p.side;
    let own = p.pieces[side];
    let empty = v.mask & ~occupied(p);
    let men = own & ~p.kings;
    for d in 4 {
        guard (d < 2) == (side == WHITE) else { continue; }
        let step = v.delta[d];
        var movers = if step > 0 { men & (empty >> step) } else { men & (empty << -step) };
        while movers != 0 {
            let from = ctz(movers);
            movers &= movers - 1;
            let to = from + step;
            add_quiet(out, from, to, v.promotion[side] & bit(to) != 0);
        }
    }
    var kings = own & p.kings;
    while kings != 0 {
        let from = ctz(kings);
        kings &= kings - 1;
        for d in 4 {
            let step = v.delta[d];
            var to = from + step;
            while on_board(v, to) && empty & bit(to) != 0 {
                add_quiet(out, from, to, false);
                guard v.flying else { break; }
                to += step;
            }
        }
    }
}

fn add_quiet(out: Moves&, from: i64, to: i64, crowned: bool) {
    assert(out.len < MAX_MOVES);
    let m .= out.push(Move { from: from as u8, to: to as u8, crowned: crowned, .. });
    m.path.push(from as u8);
    m.path.push(to as u8);
}

// Every legal move of p into out, which it empties first. Capturing is
// compulsory, so either every move is a capture or none is.
fn generate(p: Position, out: Moves&) {
    out.clear();
    let v .= VARIANTS[p.variant];
    captures(p, v, out);
    if out.len == 0 { quiet(p, v, out); }
}

// The position after m, which must be one of p's legal moves.
fn play(p: Position, m: Move) -> Position {
    var q = p;
    let side = p.side;
    let from = bit(m.from);
    let to = bit(m.to);
    let king = p.kings & from != 0 || m.crowned;
    q.pieces[side] = (q.pieces[side] & ~from) | to;
    q.pieces[1 - side] &= ~m.captured;
    q.kings &= ~(m.captured | from);
    if king { q.kings |= to; }
    q.side = 1 - side;
    return q;
}

// The number of leaf positions depth moves ahead.
recursive fn perft(p: Position, depth: i64) -> i64 {
    if depth == 0 { return 1; }
    var moves: Moves = [];
    generate(p, moves);
    if depth == 1 { return moves.len; }
    var n = 0;
    for i in moves.len { n += perft(play(p, moves[i]), depth - 1); }
    return n;
}
