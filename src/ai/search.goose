// Alpha-beta as a machine that can stop after any node and go on later, so the game
// can think a few milliseconds a frame on the thread that draws (docs/architecture/ai.md).
// The recursion is unrolled into one frame per ply in `Engine.plies`: entering a node
// fills its frame and pushes a child, and a child's value comes back to the frame
// below it. Negamax, fail-soft, with iterative deepening, a transposition table, and
// moves ordered by the table's move, captures, killers, and history.
//
// A node searches `d` more plies of free moves and at most `h` more plies in all. At
// d = 0 it goes on only while the side to move must capture (captures are forced, so
// there is no standing pat); at h = 0 it stops wherever it is. h is how far a level
// sees, and nothing is searched past it.
//
// Nothing here allocates: frames, moves, and the table are made once by `init`.
namespace ai;
import std;
import rules from "../rules";
import .eval;

let MAX_PLY = 64;
let INF = 32000;
let WIN = 30000;            // a won position, less the plies it takes to win
let WON = WIN - 1000;       // scores past this are wins or losses
let TT_BITS = 18;
let TT_MASK = (1 << TT_BITS) - 1;
let HISTORY_CAP = 1 << 16;

// A table entry's bound.
let EXACT = 1;
let LOWER = 2;              // the value is at least the score
let UPPER = 3;              // the value is at most the score

// What the machine does next at the current ply.
let ENTER = 0;              // search the node in the frame
let RETURN = 1;             // take the value a child left in Engine.value

struct Entry {
    key:   u64 = 0,
    score: i16 = 0,
    best:  u16 = 0,         // the best move's index in the node's moves, plus one; 0 for none
    d:     u8  = 0,
    h:     u8  = 0,
    flag:  u8  = 0,
}

// One node being searched.
struct Frame {
    pos:    rules::Position,
    key:    u64,
    alpha:  i64,
    beta:   i64,
    first:  i64,            // alpha as the node was entered, for the table's bound
    window: i64,            // at the root: the alpha the current move is searched with
    best:   i64,
    best_i: i64,
    d:      i64,
    h:      i64,
    count:  i64,            // moves tried so far
    move:   i64,            // the move being searched
    tt:     i64,            // the table's move for this node, or -1
}

struct Ply {
    f:     Frame,
    moves: rules::Moves,
    rank:  i32[rules::MAX_MOVES],   // the order to try moves in, highest first; tried ones are -1
}

// Makes the table and the frames; once, before the first search.
fn init(e: Engine&) {
    guard e.tt.len == 0 else { return; }
    for i in 1 << TT_BITS { e.tt.push(Entry { .. }); }
    for i in MAX_PLY { e.plies.push(Ply { .. }); }
}

// Sets up a search of p, which has at least two moves: `depth` plies of free moves and
// `extra` more of forced captures, root moves within `margin` of the best scored
// exactly, and no new iteration begun after `limit` nodes.
fn begin(e: Engine&, p: rules::Position, depth: i64, extra: i64, margin: i64, limit: i64) {
    for &t in e.tt { t = Entry { .. }; }
    for &x in e.history { x = 0; }
    for &x in e.killer { x = 0; }
    e.root = p;
    e.depth = min(depth, MAX_PLY - 1);
    e.extra = extra;
    e.margin = margin;
    e.limit = limit;
    e.nodes = 0;
    e.iteration = 0;
    e.finished = 0;
    rules::generate(p, e.plies[0].moves);
    e.root_count = e.plies[0].moves.len;
    for i in e.root_count {
        e.score[i] = 0;
        e.exact[i] = false;
    }
    next_iteration(e);
}

fn next_iteration(e: Engine&) {
    e.iteration += 1;
    let f .= e.plies[0].f;
    f.pos = e.root;
    f.key = key(e.root);
    f.alpha = -INF;
    f.beta = INF;
    f.d = e.iteration;
    f.h = min(e.iteration + e.extra, MAX_PLY - 1);
    e.ply = 0;
    e.mode = ENTER;
    e.searching = true;
}

// Searches for at most `budget` nodes; returns how many it took. The search is over
// when `e.searching` is false, and `e.score` and `e.exact` hold the last finished
// iteration's root scores.
fn run(e: Engine&, budget: i64) -> i64 {
    var used = 0;
    while e.searching && used < budget {
        if e.mode == ENTER {
            // A new iteration may stop at the node limit; the first always finishes.
            if e.nodes >= e.limit && e.finished > 0 {
                e.searching = false;
                break;
            }
            e.nodes += 1;
            used += 1;
            enter(e);
        } else if e.ply < 0 {
            finish_iteration(e);
        } else {
            resume(e);
        }
    }
    return used;
}

fn finish_iteration(e: Engine&) {
    let f .= e.plies[0].f;
    for i in e.root_count {
        e.score[i] = e.next_score[i];
        e.exact[i] = e.next_exact[i];
    }
    e.finished = e.iteration;
    // A forced win or loss found needs no deeper look.
    if e.iteration >= e.depth || abs(f.best) > WON {
        e.searching = false;
    } else {
        next_iteration(e);
    }
}

// Leaves v as the node's value for the frame below it.
fn leave(e: Engine&, v: i64) {
    e.value = v;
    e.ply -= 1;
    e.mode = RETURN;
}

fn store_score(v: i64, ply: i64) -> i64 {
    return if v > WON { v + ply } else if v < -WON { v - ply } else { v };
}

fn load_score(v: i64, ply: i64) -> i64 {
    return if v > WON { v - ply } else if v < -WON { v + ply } else { v };
}

fn pack(m: rules::Move&) -> u16 { (m.from as u16) * 64 + m.to + 1 }

fn enter(e: Engine&) {
    let ply = e.ply;
    let pl .= e.plies[ply];
    let f .= pl.f;
    f.tt = -1;
    // The table's entry answers the node only when it was searched as far: a value
    // from another depth would make the result depend on what was searched before.
    let slot = (f.key & TT_MASK) as i64;
    if ply > 0 && e.use_tt && e.tt[slot].key == f.key {
        let t = e.tt[slot];
        f.tt = t.best as i64 - 1;
        if t.d == max(f.d, 0) && t.h == f.h {
            let v = load_score(t.score, ply);
            if t.flag == EXACT || (t.flag == LOWER && v >= f.beta) || (t.flag == UPPER && v <= f.alpha) {
                leave(e, v);
                return;
            }
        }
    }
    if ply > 0 { rules::generate(f.pos, pl.moves); }
    let n = pl.moves.len;
    if n == 0 {
        leave(e, -(WIN - ply));
        return;
    }
    let capture = pl.moves[0].captured != 0;
    if f.h <= 0 || ply >= MAX_PLY - 1 || (f.d <= 0 && !capture) {
        leave(e, evaluate(f.pos));
        return;
    }
    rank(e, ply);
    f.first = f.alpha;
    f.best = -INF;
    f.best_i = -1;
    f.count = 0;
    next_child(e);
}

// The order to try a node's moves in: the table's move, then captures by what they
// take, then the killers, then by history. At the root, by the last iteration's scores.
fn rank(e: Engine&, ply: i64) {
    let pl .= e.plies[ply];
    let n = pl.moves.len;
    if ply == 0 && e.finished > 0 {
        for i in n { pl.rank[i] = (e.score[i] + INF + 1) as i32; }
        return;
    }
    let k0 = e.killer[ply * 2];
    let k1 = e.killer[ply * 2 + 1];
    let kings = pl.f.pos.kings;
    for i in n {
        let m .= pl.moves[i];
        var r = 0;
        if i == pl.f.tt {
            r = 1 << 30;
        } else if m.captured != 0 {
            r = (1 << 24) + 1024 * popcount(m.captured) + 512 * popcount(m.captured & kings);
        } else {
            let p = pack(m);
            if p == k0 { r = 1 << 22; }
            else if p == k1 { r = (1 << 22) - 1; }
            else {
                r = e.history[(m.from as i64) * 64 + m.to];
                if m.crowned { r += HISTORY_CAP; }
            }
        }
        pl.rank[i] = r as i32;
    }
}

// Searches the node's next move, or leaves the node when none is left.
fn next_child(e: Engine&) {
    let ply = e.ply;
    let pl .= e.plies[ply];
    let f .= pl.f;
    let n = pl.moves.len;
    var pick = -1;
    var top: i32 = -1;
    for i in n {
        if pl.rank[i] > top {
            top = pl.rank[i];
            pick = i;
        }
    }
    if pick < 0 {
        done(e);
        return;
    }
    pl.rank[pick] = -1;
    let m .= pl.moves[pick];
    f.move = pick;
    f.count += 1;
    var a = max(f.alpha, f.best);
    if ply == 0 {
        // Every root move within the margin of the best gets an exact score.
        a = if f.best > -INF { f.best - e.margin } else { -INF };
        f.window = a;
    }
    let c .= e.plies[ply + 1].f;
    c.pos = rules::play(f.pos, m);
    c.key = key_after(f.key, f.pos, m);
    c.alpha = -f.beta;
    c.beta = -a;
    // A forced move costs no depth: a person sees it at once.
    c.d = if f.d > 0 && n == 1 { f.d } else { max(f.d - 1, 0) };
    c.h = f.h - 1;
    e.ply = ply + 1;
    e.mode = ENTER;
}

// Takes the value of the move just searched.
fn resume(e: Engine&) {
    let ply = e.ply;
    let pl .= e.plies[ply];
    let f .= pl.f;
    let s = -e.value;
    let i = f.move;
    if ply == 0 {
        e.next_score[i] = s;
        e.next_exact[i] = s > f.window;
    }
    if s > f.best {
        f.best = s;
        f.best_i = i;
    }
    if ply > 0 && s > f.alpha { f.alpha = s; }
    if f.best >= f.beta {
        let m .= pl.moves[i];
        if m.captured == 0 {
            let p = pack(m);
            if e.killer[ply * 2] != p {
                e.killer[ply * 2 + 1] = e.killer[ply * 2];
                e.killer[ply * 2] = p;
            }
            let slot = (m.from as i64) * 64 + m.to;
            e.history[slot] = min(e.history[slot] + f.d * f.d, HISTORY_CAP - 1) as i32;
        }
        done(e);
        return;
    }
    e.mode = ENTER;
    next_child(e);
}

// Stores the node in the table and leaves it.
fn done(e: Engine&) {
    let ply = e.ply;
    let f .= e.plies[ply].f;
    let flag: u8 = if f.best <= f.first { UPPER } else if f.best >= f.beta { LOWER } else { EXACT };
    let slot = (f.key & TT_MASK) as i64;
    if e.use_tt { e.tt[slot] = Entry { key: f.key, score: store_score(f.best, ply) as i16, best: (f.best_i + 1) as u16,
                         d: max(f.d, 0) as u8, h: f.h as u8, flag: flag }; }
    leave(e, f.best);
}
