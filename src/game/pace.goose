// How long the computer takes over a move against the clock, as a player of its level
// would (docs/architecture/ai.md, "Against the clock"). It only decides when the move is
// played, never the search, and spends at most a tenth of its clock, so it can't lose on
// time.
namespace pace;
import std;
import rules from "../rules";

let HORIZON = 30.0;             // the moves it spreads the time it has left over
let SHARE = [0.2, 0.3, 0.45];   // of that, by level, on a quiet choice among three close moves
let MOST = [12.0, 8.0, 15.0];   // seconds, by level: the longest it thinks over a move
let CLOSE = 15;                 // hundredths of a man from the best: a close move (ai::close)
let FULL = 3.0;                 // close moves for an ordinary choice
let HARDEST = 5;                // more close moves than this take no longer
let SEES = [false, true, true]; // by level: a choice among captures is seen at once,
let CAPTURE = 0.5;              // taking this much of a quiet choice among three
let TENSE = [3.5, 1.0, 1.0];    // by level: times as long when a piece can be taken (tense)
let SPARE = 10.0;               // it spends at most a tenth of its clock on a move
let OPENING = 12;               // plies: the first moves take a growing part of the time

// Whether a piece can be taken around move `m` in `p`: the side to move must capture,
// a piece of the mover's is attacked, or `m` offers or allows a capture.
fn tense(p: rules::Position, m: rules::Move) -> bool {
    guard m.captured == 0 else { return true; }
    var moves: rules::Moves = [];
    var other = p;
    other.side = 1 - p.side;
    rules::generate(other, moves);
    guard moves.len == 0 || moves[0].captured == 0 else { return true; }
    rules::generate(rules::play(p, m), moves);
    return moves.len > 0 && moves[0].captured != 0;
}

// Seconds from the computer's turn to its move, at `level` with `left` seconds on its
// clock and `increment` added a move, `ply` plies into the game: `moves` legal moves,
// captures or not, `close` of them about as good as the best, `sharp` when a piece can
// be taken around its move (tense()). Never less than `pause`, the level's pause
// without a clock, unless its clock is nearly out.
fn seconds(pause: f64, level: i64, left: f64, increment: f64, ply: i64, moves: i64, capture: bool,
           sharp: bool, close: i64) -> f64 {
    let least = min(pause, left / SPARE);
    guard moves > 1 else { return least; }
    let lv = clamp(level, 0, 2);
    let fair = left / HORIZON + increment;
    var choice = if capture && SEES[lv] { CAPTURE } else { (clamp(close, 1, HARDEST) as f64) / FULL };
    if sharp { choice *= TENSE[lv]; }
    let early = (min(ply + 1, OPENING) as f64) / OPENING;
    let t = min(min(fair * SHARE[lv] * choice * early, MOST[lv]), left / SPARE);
    return max(t, least);
}
