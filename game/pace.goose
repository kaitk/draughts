// How long the computer takes over a move against the clock, as a player of its level
// would (docs/architecture/ai.md, "In the game"), with no graphics. The search still
// stops at its own depth; this only decides when its move is played, so its strength
// never changes. It spends a share of what it could spend each move and keep its clock
// (the time left over the moves still to come, plus the increment), more on hard than
// on easy; more when several moves are about as good, less when one stands out or it
// must capture; at once, after the level's pause, when it has a single move; and the
// first moves of a game quickly, as a player knows them, longer as the game opens up.
// Its clock
// keeps it from running low: it never spends more than a tenth of what is left, so
// with the increment it can't lose on time.
namespace pace;
import std;

let HORIZON = 30.0;             // the moves it spreads the time it has left over
let SHARE = [0.15, 0.3, 0.45];   // of that, by level, on a choice among three close moves
let MOST = [4.0, 8.0, 15.0];    // seconds, by level: the longest it thinks over a move
let CLOSE = 15;                 // hundredths of a man from the best: a close move (ai::close)
let FULL = 3.0;                 // close moves for an ordinary choice
let HARDEST = 5;                // more close moves than this take no longer
let CAPTURE = 0.5;              // a choice among captures takes this much of a quiet one
let SPARE = 10.0;               // it spends at most a tenth of its clock on a move
let OPENING = 12;               // plies: the first moves take a growing part of the time

// Seconds from the computer's turn to its move, at `level` with `left` seconds on its
// clock and `increment` added a move, `ply` plies into the game: `moves` legal moves,
// captures or not, `close` of them about as good as the best. Never less than `pause`,
// the level's pause without a clock, unless its clock is nearly out.
fn seconds(pause: f64, level: i64, left: f64, increment: f64, ply: i64, moves: i64, capture: bool,
           close: i64) -> f64 {
    let least = min(pause, left / SPARE);
    guard moves > 1 else { return least; }
    let lv = clamp(level, 0, 2);
    let fair = left / HORIZON + increment;
    let choice = if capture { CAPTURE } else { (clamp(close, 1, HARDEST) as f64) / FULL };
    let early = (min(ply + 1, OPENING) as f64) / OPENING;
    let t = min(min(fair * SHARE[lv] * choice * early, MOST[lv]), left / SPARE);
    return max(t, least);
}
