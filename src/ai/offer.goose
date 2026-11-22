// A draw offered (docs/architecture/ai.md, "Draws and giving up"): the computer's answer
// to the child's offer and its own offer, pure functions over the position and the score
// of its last search, with no search of their own.
namespace offer;
import std;
import rules from "../rules";

let WINNING = 50;           // hundredths of a man: ahead by this much, it declines
let EVEN = 20;              // within this of even with only kings, it offers

// Whether both sides have a king.
fn kings_each(p: rules::Position&) -> bool {
    return p.pieces[0] & p.kings != 0 && p.pieces[1] & p.kings != 0;
}

// The long diagonal, a1–h8 or a1–j10: the squares whose column equals their row, both
// from 0.
fn long_diagonal(variant: u8) -> u64 {
    let v .= rules::VARIANTS[variant];
    var d: u64 = 0;
    var left = v.mask;
    while left != 0 {
        let b = ctz(left);
        left &= left - 1;
        if v.x_of[b] == v.y_of[b] { d |= (1 as u64) << b; }
    }
    return d;
}

// Whether the material alone is a draw, whatever a score says: only kings on the board,
// each side with one or more, and the stronger side with at most two, or three against a
// lone king on the long diagonal. Two kings can't take one with flying kings, nor three
// one that holds the long diagonal; a search's score sees only the kings counted.
fn dead_draw(p: rules::Position&) -> bool {
    let all = p.pieces[0] | p.pieces[1];
    guard all & ~p.kings == 0 && kings_each(p) else { return false; }
    let n0 = popcount(p.pieces[0]);
    let n1 = popcount(p.pieces[1]);
    let strong = max(n0, n1);
    if strong <= 2 { return true; }
    guard strong == 3 && min(n0, n1) == 1 else { return false; }
    let lone = if n0 == 1 { p.pieces[0] } else { p.pieces[1] };
    return lone & long_diagonal(p.variant) != 0;
}

// Whether the computer, playing `computer`, accepts the child's offer in p: unless it is
// WINNING ahead by `score`, its last search's score for itself, or the material is a
// dead draw.
fn accepts_draw(p: rules::Position&, computer: i64, score: i64) -> bool {
    guard computer == 0 || computer == 1 else { return false; }
    return dead_draw(p) || score < WINNING;
}

// Whether the computer offers a draw in p after its move, `score` its search's score for
// itself: both sides have a king, and the material is a dead draw or only kings stand
// with the score within EVEN of even.
fn offers_draw(p: rules::Position&, computer: i64, score: i64) -> bool {
    guard (computer == 0 || computer == 1) && kings_each(p) else { return false; }
    if dead_draw(p) { return true; }
    let men = (p.pieces[0] | p.pieces[1]) & ~p.kings;
    return men == 0 && abs(score) <= EVEN;
}
