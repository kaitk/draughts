// Whether a move solves a puzzle (docs/architecture/puzzles.md, "Goals"): an exact
// search over the rules that counts pieces and nothing else. The solver's side must
// reach the goal within the puzzle's moves whatever the other side replies; a move is
// right when it reaches the goal or keeps it within reach, whichever line it is on.
//
// The search keeps every position's moves on one fixed stack in the Solver, which the
// caller owns, so it allocates nothing and its recursion keeps little on the native
// stack.
namespace puzzles;
import std;
import rules from "../rules";

let STACK = 4096;           // moves on the search's stack at once
let SAFE_DEPTH = 3;         // plies a safe move is looked past, captures beyond: a double sacrifice's
let SHOW_DEPTH = 3;         // plies a wrong move's answer is looked past (answer), captures beyond
let WON = 1000;             // the value of a position whose side to move has no move

// What a move does to a puzzle.
let WRONG = 0;
let ON = 1;                 // right, the goal still ahead
let SOLVED = 2;

// A move as the search keeps it.
struct Short { from: u8, to: u8, crowned: bool, captured: u64 }

struct Solver {
    side:   u8     = 0,     // the side solving the puzzle
    goal:   i64    = TAKE,
    count:  i64    = 1,
    pieces: i64[2] = [0, 0], // each side's pieces at the start
    moves:  rules::Moves,
    stack:  Short[..STACK],
    nodes:  i64 = 0,        // positions searched, for tools
}

// Sets the solver to puzzle pz.
fn begin(s: Solver&, pz: Puzzle&) {
    s.side = pz.start.side;
    s.goal = pz.goal;
    s.count = pz.count;
    s.pieces = [popcount(pz.start.pieces[0]), popcount(pz.start.pieces[1])];
    s.stack.clear();
}

// The pieces the solver is up at q against the start: taken less lost.
fn net(s: Solver&, q: rules::Position) -> i64 {
    let other = 1 - s.side;
    let taken = s.pieces[other] - popcount(q.pieces[other]);
    let lost = s.pieces[s.side] - popcount(q.pieces[s.side]);
    return taken - lost;
}

fn short(m: rules::Move&) -> Short { Short { from: m.from, to: m.to, crowned: m.crowned, captured: m.captured } }

fn after(q: rules::Position, m: Short) -> rules::Position {
    return rules::play(q, rules::Move { from: m.from, to: m.to, crowned: m.crowned, captured: m.captured, path: [] });
}

// Pushes q's legal moves on the stack; returns where they start.
fn push_moves(s: Solver&, q: rules::Position) -> i64 {
    rules::generate(q, s.moves);
    let base = s.stack.len;
    assert(base + s.moves.len <= STACK);
    for m in s.moves { s.stack.push(short(m)); }
    return base;
}

// The pieces the solver is up with best play by both sides for `depth` more plies, and
// the captures that are due played out beyond; WON when the other side is left with no
// move, -WON when the solver is.
recursive fn value(s: Solver&, q: rules::Position, depth: i64, alpha: i64, beta: i64) -> i64 {
    s.nodes++;
    let base = push_moves(s, q);
    let end = s.stack.len;
    let mine = q.side == s.side;
    if end == base { return if mine { -WON } else { WON }; }
    if depth <= 0 && s.stack[base].captured == 0 {
        s.stack.resize(base);
        return net(s, q);
    }
    var a = alpha;
    var b = beta;
    var best = if mine { -WON - 1 } else { WON + 1 };
    for i in base..end {
        let v = value(s, after(q, s.stack[i]), depth - 1, a, b);
        if mine {
            best = max(best, v);
            a = max(a, v);
        } else {
            best = min(best, v);
            b = min(b, v);
        }
        if a >= b { break; }
    }
    s.stack.resize(base);
    return best;
}

// Whether the other side, to move at r, has a shot: no capture is due, and it has a
// move that gives the solver a capture after which the solver ends down, with best play
// over `depth` plies from r and the captures due beyond.
fn shot(s: Solver&, r: rules::Position, depth: i64) -> bool {
    let base = push_moves(s, r);
    let end = s.stack.len;
    var found = false;
    if end > base && s.stack[base].captured == 0 {
        for i in base..end {
            let t = after(r, s.stack[i]);
            rules::generate(t, s.moves);
            guard s.moves.len > 0 && s.moves[0].captured != 0 else { continue; }
            if value(s, t, depth - 1, -WON - 1, WON + 1) < 0 {
                found = true;
                break;
            }
        }
    }
    s.stack.resize(base);
    return found;
}

// Whether the solver's move m, which led to q, reaches the goal: the other side has no
// move; or, by the goal, m is a capture that leaves the solver `count` up through the
// captures that follow, the king made isn't taken by the reply, or nothing is lost over
// SAFE_DEPTH plies.
fn reached(s: Solver&, q: rules::Position, m: Short) -> bool {
    let base = push_moves(s, q);
    let end = s.stack.len;
    var crowned = m.crowned;
    for i in base..end { if s.stack[i].captured & rules::bit(m.to) != 0 { crowned = false; } }
    s.stack.resize(base);
    if end == base { return true; }
    if s.goal == TAKE { return m.captured != 0 && value(s, q, 0, -WON - 1, WON + 1) >= s.count; }
    if s.goal == CROWN { return crowned; }
    if s.goal == SAFE { return value(s, q, SAFE_DEPTH, -WON - 1, WON + 1) >= 0; }
    return false;
}

// What the solver's move m does at q with `left` moves to the goal: SOLVED, ON, or WRONG.
recursive fn judge(s: Solver&, q: rules::Position, m: Short, left: i64) -> i64 {
    let r = after(q, m);
    if reached(s, r, m) { return SOLVED; }
    return if left > 1 && forced(s, r, left - 1) { ON } else { WRONG };
}

// Whether the solver, to move at q, can reach the goal within `left` moves whatever the
// replies.
recursive fn wins(s: Solver&, q: rules::Position, left: i64) -> bool {
    s.nodes++;
    let base = push_moves(s, q);
    let end = s.stack.len;
    var found = false;
    for i in base..end {
        if judge(s, q, s.stack[i], left) != WRONG {
            found = true;
            break;
        }
    }
    s.stack.resize(base);
    return found;
}

// Whether every reply at r, the other side to move, leaves the solver a win within
// `left` moves.
recursive fn forced(s: Solver&, r: rules::Position, left: i64) -> bool {
    let base = push_moves(s, r);
    let end = s.stack.len;
    var all = true;
    for i in base..end {
        if !wins(s, after(r, s.stack[i]), left) {
            all = false;
            break;
        }
    }
    s.stack.resize(base);
    return all;
}

// The fewest moves the solver, to move at q, needs to the goal, or most + 1 if more.
fn need(s: Solver&, q: rules::Position, most: i64) -> i64 {
    for k in 1..most + 1 { if wins(s, q, k) { return k; } }
    return most + 1;
}

// The other side's reply at r, to move there, with `left` of the solver's moves to go:
// the one after which the solver needs the most moves, the first of those. Returns its
// index in r's legal moves (rules::generate's order), or -1 when there is none.
fn reply(s: Solver&, r: rules::Position, left: i64) -> i64 {
    let base = push_moves(s, r);
    let end = s.stack.len;
    var best = -1;
    var most = 0;
    for i in base..end {
        let n = need(s, after(r, s.stack[i]), left);
        if best < 0 || n > most {
            best = i - base;
            most = n;
        }
    }
    s.stack.resize(base);
    return best;
}

// The first of the solver's moves at q that is right with `left` moves to go, as its
// index in q's legal moves, or -1.
fn right_move(s: Solver&, q: rules::Position, left: i64) -> i64 {
    let base = push_moves(s, q);
    let end = s.stack.len;
    var found = -1;
    for i in base..end {
        if judge(s, q, s.stack[i], left) != WRONG {
            found = i - base;
            break;
        }
    }
    s.stack.resize(base);
    return found;
}

// The other side's answer to a wrong move, which shows the child why it was wrong
// (docs/architecture/puzzles.md, "The screen"): at r, after the solver's move, the
// other side to move, the reply after which the solver ends worst with best play over
// SHOW_DEPTH plies from r and the captures due beyond, when that is less than the solver
// has at r: a capture back, or a shot's first move. Returns its index in r's legal
// moves (rules::generate's order), or -1 when no reply takes anything back.
fn answer(s: Solver&, r: rules::Position) -> i64 {
    let has = net(s, r);
    let base = push_moves(s, r);
    let end = s.stack.len;
    var best = -1;
    var worst = has;
    for i in base..end {
        let v = value(s, after(r, s.stack[i]), SHOW_DEPTH - 1, -WON - 1, WON + 1);
        if v < worst {
            best = i - base;
            worst = v;
        }
    }
    s.stack.resize(base);
    return best;
}
