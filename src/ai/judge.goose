// How good a played move was (task 074): the position before it searched at full
// strength, nothing overlooked, and the played move's score set against the best's as a
// fall in the mover's expected result. Pure, as the rest of the engine; the app runs it
// on the computer's worker between its other asks (src/app/think.goose).
//
//   ai::judge_start(e, past, p);                  p: the position before the move
//   while !ai::judge_step(e, 10000) { a newer ask? }
//   let v = ai::verdict(e, played);
//
// A score becomes an expected result through a logistic (expected), and the mark is
// the fall in it (MARK_*), lidraughts' curve and cut-offs: a move that keeps a won game
// won is no mistake whatever it gives back. The hint is the move this search finds best
// (judged_best), so a hint followed is never marked down.
namespace ai;
import std;
import math;
import rules from "../rules";

// What a move was. NOT_JUDGED until its verdict comes.
let NOT_JUDGED = 0;
let ONLY = 1;               // the one legal move
let BEST = 2;               // the best the search saw, or as good to within BEST_LOSS
let GOOD = 3;
let INACCURACY = 4;         // ?!
let MISTAKE = 5;            // ?
let BLUNDER = 6;            // ??
let MARKS = 7;

// The falls in the expected result, in thousandths, from which each mark begins:
// lidraughts' 0.075, 0.15, and 0.30 of its win chance, which runs -1..1 (its
// modules/analyse Advice.scala); best within about 0.04 of a man of the best.
let BEST_LOSS = 4;
let INACCURACY_LOSS = 38;
let MISTAKE_LOSS = 75;
let BLUNDER_LOSS = 150;

// Hundredths of a man for the logistic's unit, lidraughts' 0.004 a centipiece: a man up
// expects 0.60, two 0.69. From an even position a mistake begins at 0.76 of a man lost,
// a blunder at 1.55.
let SCALE = 250.0;

// Root moves this much under the best are only bounded, not scored: at an even
// position that is a fall of 0.23 and more, a blunder whatever the bound.
let JUDGE_MARGIN = 250;
let JUDGE_SKILL = 100;      // the depth it sees: hard's at its top
let JUDGE_LIMIT = 300000;   // nodes after which it begins no new iteration: about 0.1 s on the tablet's big cores

struct Verdict {
    mark:   i64 = NOT_JUDGED,
    loss:   i64 = 0,        // the fall in the expected result, thousandths (at least, for a bound)
    best:   i64 = 0,        // the best move's score, hundredths of a man for the mover
    played: i64 = 0,        // the played move's, or its upper bound
    // The move the search found best from the position, for a replay (task 087); none
    // where the position had one move.
    best_move: rules::Move = rules::Move { .. },
    has_best:  bool        = false,
}

// The mover's expected result, in thousandths, of a score from its side.
fn expected(s: i64) -> i64 {
    guard s < WON else { return 1000; }
    guard s > -WON else { return 0; }
    let x = (s as f64) / SCALE;
    return (1000.0 / (1.0 + exp(-x)) + 0.5) as i64;
}

// The mark for a fall of `loss` thousandths.
fn mark_of(loss: i64) -> i64 {
    return if loss >= BLUNDER_LOSS { BLUNDER } else if loss >= MISTAKE_LOSS { MISTAKE }
           else if loss >= INACCURACY_LOSS { INACCURACY } else if loss >= BEST_LOSS { GOOD } else { BEST };
}

// One move's accuracy in percent, as lichess's: 103.17 · e^(−4.354 · loss) − 3.17,
// within 0..100, a fall of 0 a hundred, of 0.2 about 39, of 0.5 8.
fn accuracy(loss: i64) -> i64 {
    let a = 103.1668 * exp(-4.354 * loss / 1000.0) - 3.1669;
    return clamp((a + 0.5) as i64, 0, 100);
}

// Begins judging a move from p, in a game that went through `past` to p. A position
// with one move needs no search: judge_step is done at once and the verdict is ONLY.
fn judge_start(e: Engine&, past: rules::Past&, p: rules::Position) {
    init(e);
    e.past.clear();
    for &q in past.before { e.past.push(key(q)); }
    e.draw_at = past.draw;
    e.root_draw = past.draw;
    e.position = p;
    rules::generate(p, e.moves);
    e.searching = false;
    guard e.moves.len > 1 else { return; }
    let pr = params(JUDGE_SKILL);
    begin(e, p, pr.depth, pr.extra, JUDGE_MARGIN, min(e.node_limit, JUDGE_LIMIT));
}

// Searches for about `nodes` more nodes; true once the verdict is ready.
fn judge_step(e: Engine&, nodes: i64) -> bool {
    var budget = nodes;
    while e.searching {
        guard budget > 0 else { return false; }
        budget -= run(e, budget);
    }
    return true;
}

// The verdict on `played`, one of the position's legal moves, once judge_step is done.
// A move not among them (it can't be) is NOT_JUDGED.
fn verdict(e: Engine&, played: rules::Move&) -> Verdict {
    var k = -1;
    for i in e.moves.len {
        let m .= e.moves[i];
        if m.from == played.from && m.to == played.to && m.captured == played.captured { k = i; }
    }
    guard k >= 0 else { return Verdict {}; }
    guard e.moves.len > 1 else { return Verdict { mark: ONLY, .. }; }
    let at = best_at(e, k);
    let best = e.score[at];
    let played_score = e.score[k];
    let loss = max(expected(best) - expected(played_score), 0);
    return Verdict { mark: mark_of(loss), loss: loss, best: best, played: played_score, best_move: e.moves[at],
                     has_best: true };
}

// The root move the judging search scored highest, the first among equals; `none` where
// it scored none exactly (it always scores the best).
fn best_at(e: Engine&, none: i64) -> i64 {
    var best = -INF;
    var at = none;
    for i in e.root_count {
        if e.exact[i] && e.score[i] > best {
            best = e.score[i];
            at = i;
        }
    }
    return at;
}

// The hint's move once judge_step is done: the move the judge would mark best, or the
// one legal move.
fn judged_best(e: Engine&) -> rules::Move {
    guard e.moves.len > 1 else { return e.moves[0]; }
    return e.moves[best_at(e, 0)];
}

// The hint's move for p at once, for tests: as the worker finds it.
fn hint(e: Engine&, past: rules::Past&, p: rules::Position) -> rules::Move {
    judge_start(e, past, p);
    while !judge_step(e, 1 << 30) {}
    return judged_best(e);
}

// The verdict at once, for tests and tools.
fn judge(e: Engine&, past: rules::Past&, p: rules::Position, played: rules::Move&) -> Verdict {
    judge_start(e, past, p);
    while !judge_step(e, 1 << 30) {}
    return verdict(e, played);
}
