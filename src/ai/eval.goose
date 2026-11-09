// What the computer player knows of a position without searching: its value to the
// side to move, in hundredths of a man, and its Zobrist key for the transposition
// table. Both are plain integer arithmetic over the bitboards, so a search gives the
// same result on every machine.
namespace ai;
import std;
import rules from "../rules";

let MAN = 100;
let ROWS = 10;      // the most rows a board has

// The terms of the evaluation for one variant, with the squares they count.
struct Weights {
    king:   i64,            // a king, in hundredths of a man
    back:   i64,            // a man still on its own back row, which keeps kings out
    center: i64,            // a man on one of the central squares
    adv:    i64[ROWS],      // a man r rows up from its own back row
    rows:   u64[2 * ROWS],  // side * ROWS + r: the squares r rows up from that side's back row
    middle: u64,            // the central squares
}

fn make_weights(variant: u8) -> Weights {
    let v .= rules::VARIANTS[variant];
    var w = Weights { king: if v.flying { 300 } else { 150 }, .. };
    // Men gain as they advance, more near the far row, where they are close to
    // crowning; the far row itself is never held by a man.
    if v.size == 8 {
        w.adv = [0, 0, 2, 4, 7, 11, 16, 0, 0, 0];
        w.back = 4;
    } else {
        w.adv = [0, 0, 1, 2, 4, 6, 8, 11, 15, 0];
        w.back = 3;
    }
    w.center = 3;
    let lo = (v.size - 4) / 2;
    for b in 64 {
        guard rules::on_board(v, b) else { continue; }
        let y = v.y_of[b] as i64;
        let x = v.x_of[b] as i64;
        w.rows[y] |= rules::bit(b);
        w.rows[ROWS + v.size - 1 - y] |= rules::bit(b);
        if x >= lo && x < v.size - lo && y >= lo && y < v.size - lo { w.middle |= rules::bit(b); }
    }
    return w;
}

let WEIGHTS: Weights[rules::VARIANT_COUNT] = [make_weights(0), make_weights(1), make_weights(2),
                                               make_weights(3)];

fn side_value(w: Weights&, p: rules::Position&, side: i64) -> i64 {
    let men = p.pieces[side] & ~p.kings;
    var v = MAN * popcount(men) + w.king * popcount(p.pieces[side] & p.kings);
    v += w.back * popcount(men & w.rows[side * ROWS]);
    for r in 1..ROWS { v += w.adv[r] * popcount(men & w.rows[side * ROWS + r]); }
    v += w.center * popcount(men & w.middle);
    return v;
}

// The value of p to the side to move.
fn evaluate(p: rules::Position&) -> i64 {
    let w .= WEIGHTS[p.variant];
    let s = side_value(w, p, rules::WHITE) - side_value(w, p, rules::BLACK);
    return if p.side == rules::WHITE { s } else { -s };
}

// Zobrist keys: one per side, kind (man or king), and bit, and one for black to move.
struct Keys { piece: u64[256], black: u64 }

fn make_keys() -> Keys {
    var r = rng { 0x9E3779B97F4A7C15 };
    var k = Keys { .. };
    for i in 256 { k.piece[i] = rand_u64(r); }
    k.black = rand_u64(r);
    return k;
}

let KEYS = make_keys();

fn piece_key(side: i64, king: bool, b: i64) -> u64 {
    let kind = if king { 1 } else { 0 };
    return KEYS.piece[(side * 2 + kind) * 64 + b];
}

// The key of p, from scratch.
fn key(p: rules::Position&) -> u64 {
    var k: u64 = if p.side == rules::BLACK { KEYS.black } else { 0 };
    for side in 2 {
        var x = p.pieces[side];
        while x != 0 {
            let b = ctz(x);
            x &= x - 1;
            k ^= piece_key(side, p.kings & rules::bit(b) != 0, b);
        }
    }
    return k;
}

// The key of the position after m, from p's key k.
fn key_after(k: u64, p: rules::Position&, m: rules::Move&) -> u64 {
    let side = p.side as i64;
    let king = p.kings & rules::bit(m.from) != 0;
    var after = k ^ KEYS.black;
    after ^= piece_key(side, king, m.from);
    after ^= piece_key(side, king || m.crowned, m.to);
    var taken = m.captured;
    while taken != 0 {
        let b = ctz(taken);
        taken &= taken - 1;
        after ^= piece_key(1 - side, p.kings & rules::bit(b) != 0, b);
    }
    return after;
}
