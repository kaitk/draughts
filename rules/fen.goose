// Positions and moves as text, as PDN writes them.
//
// A position is "W:W21,22,K31:B1,2": the side to move, then each side's
// pieces, a K before a king. Squares are numbered 1 up from the top left dark
// square, row by row, as on a 10×10 board (1 is b10, 46 is a1); Russian
// writes them as a1..h8 instead. Reading takes either form, and ranges such as
// 31-50. Moves are "32-28", or a capture's stops: "28x19x10", and "c3:e5:c7"
// in Russian.
namespace rules;
import std;

fn format_square(out: u8[>..]&, v: Variant&, b: i64) {
    if v.algebraic {
        out.push('a' + v.x_of[b]);
        format(out, v.y_of[b] + 1);
    } else {
        format(out, v.number_of[b]);
    }
}

fn format_fen(out: u8[>..]&, p: Position) {
    let v .= VARIANTS[p.variant];
    out.push(if p.side == WHITE { 'W' } else { 'B' });
    for side in 2 {
        out.append(if side == WHITE { ":W" } else { ":B" });
        var first = true;
        // Numbered squares in number order, algebraic ones from a1 up.
        for i in 1..squares(p.variant) + 1 {
            let b: i64 = if v.algebraic { ctz(nth_bit(v.mask, i - 1)) } else { v.bit_of[i] };
            guard p.pieces[side] & bit(b) != 0 else { continue; }
            if !first { out.push(','); }
            first = false;
            if p.kings & bit(b) != 0 { out.push('K'); }
            format_square(out, v, b);
        }
    }
}

fn fen(p: Position) -> u8[>..] {
    var out: u8[>..] = [];
    format_fen(out, p);
    return out;
}

// The lowest set bit of x after the first n.
fn nth_bit(x: u64, n: i64) -> u64 {
    var y = x;
    for i in n { y &= y - 1; }
    return y & (0 - y);
}

// The bit of a square written as a number or as a1..j10, and whether it is one.
fn parse_square(v: Variant&, text: const u8[:]) -> i64, bool {
    guard text.len > 0 else { return 0, false; }
    let c = text[0];
    if c >= 'a' && c <= 'z' {
        let rank, ok = parse_int(text[1..]);
        let b = if ok && rank >= 1 { bit_at(v, c - 'a', rank - 1) } else { -1 };
        guard b >= 0 else { return 0, false; }
        return b, true;
    }
    let n, ok = parse_int(text);
    guard ok && text[0] != '+' && text[0] != '-' && n >= 1 && n <= v.size * v.h
    else { return 0, false; }
    return v.bit_of[n], true;
}

// The position text gives, for the variant, and whether it is well formed.
fn parse_fen(text: const u8[:], variant: u8) -> Position, bool {
    let v .= VARIANTS[variant];
    var p = Position { pieces: [0, 0], kings: 0, side: WHITE, variant: variant };
    var body = trim(text);
    if body.len > 0 && body[body.len - 1] == '.' { body = body[..body.len - 1]; }
    let fields = split(body, ':');
    guard fields.len >= 1 else { return p, false; }
    let turn = trim(fields[0]);
    if turn == "W" { p.side = WHITE; }
    else if turn == "B" { p.side = BLACK; }
    else { return p, false; }
    for f in fields[1..] {
        let field = trim(f);
        guard field.len > 0 else { continue; }
        let side: u8 = if field[0] == 'W' { WHITE } else if field[0] == 'B' { BLACK }
                       else { return p, false; };
        for item in split(field[1..], ',') {
            var sq = trim(item);
            guard sq.len > 0 else { continue; }
            let king = sq[0] == 'K';
            if king { sq = sq[1..]; }
            let a, b, range = split_once(sq, '-');
            var lo = 0;
            var hi = 0;
            if range {
                let l, okl = parse_int(a);
                let h, okh = parse_int(b);
                guard okl && okh && l >= 1 && l <= h && h <= v.size * v.h else { return p, false; }
                lo = l;
                hi = h;
            } else {
                let at, ok = parse_square(v, sq);
                guard ok else { return p, false; }
                lo = v.number_of[at];
                hi = lo;
            }
            for n in lo..hi + 1 {
                let at = bit(v.bit_of[n]);
                guard occupied(p) & at == 0 else { return p, false; }
                p.pieces[side] |= at;
                if king { p.kings |= at; }
            }
        }
    }
    return p, true;
}

fn format_move(out: u8[>..]&, variant: u8, m: Move) {
    let v .= VARIANTS[variant];
    if m.captured == 0 {
        format_square(out, v, m.from);
        out.push('-');
        format_square(out, v, m.to);
        return;
    }
    let sep: u8 = if v.algebraic { ':' } else { 'x' };
    for b, i in m.path {
        if i > 0 { out.push(sep); }
        format_square(out, v, b);
    }
}
