// The computer player: pure Goose over `rules`, with no graphics, so tests run it
// headless (docs/architecture/ai.md). It is weaker the way a person is weaker, not the
// way a crippled engine is: a level sees a fixed number of plies and never past them,
// so it misses only what shows deeper, and it picks among the moves it sees as good
// with chances that fall off with how much worse each is, from one skill setting for
// the whole game.
//
//   var e = ai::Engine { .. };
//   ai::init(e);                                  once: the table and the frames
//   ai::start(e, position, skill, seed);          a move to find
//   while !ai::step(e, 20000) { draw a frame }    nodes a frame can spare: 20000 is
//                                                 about 4 ms on the tablet's big cores
//   let m = ai::reply(e);                         one of position's legal moves
//
// The same skill, position, and seed give the same move, however the thinking is cut
// into steps and on any machine: the search counts nodes, never time.
namespace ai;
import std;
import rules from "../rules";
import .eval;
import .search;

let EASY = 0;
let MEDIUM = 1;
let HARD = 2;
let LEVELS = 3;

// Skill runs 0 to 100. Each level starts at its own and moves within BAND of it.
let LEVEL_SKILL: i64[LEVELS] = [10, 45, 90];
let BAND = 20;
let STEP = 4;               // how far one win or loss moves the skill

// The most nodes a search begins a new iteration after. It bounds hard's reply time:
// see tasks and docs/architecture/ai.md for the speed on the tablet.
let NODE_LIMIT = 800000;

// The widest margin: well under a man, so positional terms never pass off a move that
// loses one.
let MAX_MARGIN = 60;

// Leaving the child something to find (the easiest skills only).
let GIFT_SKILL = 25;        // below this skill the computer sometimes leaves a chance
let GIFT_CHANCE = 5;        // per thousand moves, per skill point below GIFT_SKILL
let GIFT_COST = 120;        // the most it gives up for one, about a man
let FIND = 80;              // what the child's best reply must gain over the position
let PROBE_DEPTH = 3;        // how far it looks for the child's chance
let PROBE_EXTRA = 4;
let PROBE_LIMIT = 20000;
let MAX_PROBES = 12;

// What the engine is doing.
let IDLE = 0;
let MAIN = 1;               // searching the position
let PROBE = 2;              // looking for a chance to leave the child
let READY = 3;              // the reply is ready

// How a skill plays.
struct Params {
    depth:  i64,            // plies of free moves it sees
    extra:  i64,            // plies of forced captures it sees past them
    margin: i64,            // it never plays a move this much worse than the best it sees
    temper: i64,            // how much worse a move is for its chance to fall by e
    gift:   i64,            // per thousand moves, how often it leaves the child a chance
}

fn params(skill: i64) -> Params {
    let s = clamp(skill, 0, 100);
    let temper = 2 + 60 * (100 - s) * (100 - s) / 10000;
    return Params {
        depth:  2 + s * s / 1000,
        extra:  2 + s / 8,
        margin: min(MAX_MARGIN, 3 * temper),
        temper: temper,
        gift:   max(GIFT_SKILL - s, 0) * GIFT_CHANCE,
    };
}

// The starting skill of a level.
fn level_skill(level: i64) -> i64 { LEVEL_SKILL[clamp(level, 0, LEVELS - 1)] }

// The skill for the next game after one at `skill` on `level`: up a step when the
// person won, down a step when the computer did (child_won 1, -1, or 0 for a draw), so
// a child meets an opponent they beat about half the time.
fn adapt(skill: i64, level: i64, child_won: i64) -> i64 {
    let base = level_skill(level);
    let s = skill + STEP * clamp(child_won, -1, 1);
    return clamp(s, max(base - BAND, 0), min(base + BAND, 100));
}

root struct Engine {
    tt:    Entry[>..] = [],
    plies: Ply[>..]   = [],
    // Move ordering, reset for each search.
    history:    i32[64 * 64]     = [0; 64 * 64],
    killer:     u16[MAX_PLY * 2] = [0; MAX_PLY * 2],
    use_tt:     bool             = true, // off only to test that the table changes no result
    node_limit: i64              = NODE_LIMIT,
    // The search under way (search.goose).
    root:       rules::Position,
    depth:      i64,
    extra:      i64,
    margin:     i64,
    limit:      i64,
    nodes:      i64,
    iteration:  i64,
    finished:   i64,        // the last iteration that finished
    root_count: i64,
    score:      i64[rules::MAX_MOVES],      // root scores of the last finished iteration
    exact:      bool[rules::MAX_MOVES],     // whether each is exact, or only an upper bound
    next_score: i64[rules::MAX_MOVES],
    next_exact: bool[rules::MAX_MOVES],
    ply:        i64,
    mode:       i64,
    value:      i64,
    searching:  bool,
    // The move being chosen.
    phase:      i64,
    params:     Params,
    random:     rng,
    position:   rules::Position,
    moves:      rules::Moves,   // the position's legal moves
    gift:       bool,           // this move leaves the child a chance, if there is one
    best:       i64,            // the best score the main search found
    main_score: i64[rules::MAX_MOVES],  // its root scores, kept while probes search
    main_exact: bool[rules::MAX_MOVES],
    cands:      i64[rules::MAX_MOVES],  // moves to probe for a gift, best first
    cand_count: i64,
    probe:      i64,            // the candidate being probed
    gift_move:  i64,            // the best gift so far, or -1
    gift_score: i64,
    chosen:     i64,            // the reply, an index into moves, or -1
    gifted:     bool,           // whether the reply leaves the child a chance
    budget:     i64,
    // What the last search did, for benchmarks.
    total_nodes: i64,
    seen:        i64,           // the deepest iteration the main search finished
}

// Begins finding a move for p at `skill`, with `seed` for the choices among good moves.
fn start(e: Engine&, p: rules::Position, skill: i64, seed: u64) {
    init(e);
    e.position = p;
    e.params = params(skill);
    e.random = rng { seed };
    e.total_nodes = 0;
    e.seen = 0;
    e.chosen = -1;
    e.gifted = false;
    e.gift_move = -1;
    rules::generate(p, e.moves);
    if e.moves.len <= 1 {
        e.chosen = if e.moves.len == 1 { 0 } else { -1 };
        e.phase = READY;
        return;
    }
    e.gift = rand_int(e.random, 1000) < e.params.gift;
    let margin = if e.gift { max(e.params.margin, GIFT_COST) } else { e.params.margin };
    begin(e, p, e.params.depth, e.params.extra, margin, e.node_limit);
    e.phase = MAIN;
}

// Thinks for about `nodes` more nodes; true once the reply is ready.
fn step(e: Engine&, nodes: i64) -> bool {
    e.budget = nodes;
    while e.phase == MAIN || e.phase == PROBE {
        if e.searching {
            guard e.budget > 0 else { return false; }
            e.budget -= run(e, e.budget);
            continue;
        }
        e.total_nodes += e.nodes;
        if e.phase == MAIN {
            e.seen = e.finished;
            main_done(e);
        } else {
            probe_done(e);
        }
    }
    return true;
}

// The reply found: one of the position's legal moves. Only after step returned true,
// and only when the position has a move.
fn reply(e: Engine&) -> rules::Move { e.moves[e.chosen] }

// Whether there is a reply: false when the position has no legal move.
fn has_reply(e: Engine&) -> bool { e.phase == READY && e.chosen >= 0 }

// Finds a move for p at once, for tests and benchmarks.
fn think(e: Engine&, p: rules::Position, skill: i64, seed: u64) -> rules::Move {
    start(e, p, skill, seed);
    while !step(e, 1 << 30) {}
    return reply(e);
}

fn main_done(e: Engine&) {
    e.best = -INF;
    for i in e.moves.len {
        e.main_score[i] = e.score[i];
        e.main_exact[i] = e.exact[i];
        if e.exact[i] && e.score[i] > e.best { e.best = e.score[i]; }
    }
    if e.gift {
        // The moves to look at for a chance, best first, ties in move order.
        e.cand_count = 0;
        for i in e.moves.len {
            guard e.exact[i] && e.score[i] >= e.best - GIFT_COST else { continue; }
            var j = e.cand_count;
            while j > 0 && e.score[e.cands[j - 1]] < e.score[i] {
                e.cands[j] = e.cands[j - 1];
                j -= 1;
            }
            e.cands[j] = i;
            e.cand_count += 1;
        }
        e.cand_count = min(e.cand_count, MAX_PROBES);
        e.probe = -1;
        next_probe(e);
        return;
    }
    choose(e);
}

// Begins searching the next candidate's position from the child's side, or chooses
// once none is left.
fn next_probe(e: Engine&) {
    e.probe += 1;
    while e.probe < e.cand_count {
        let q = rules::play(e.position, e.moves[e.cands[e.probe]]);
        rules::generate(q, e.plies[0].moves);
        if e.plies[0].moves.len >= 2 && e.plies[0].moves[0].captured == 0 {
            begin(e, q, PROBE_DEPTH, PROBE_EXTRA, FIND, PROBE_LIMIT);
            e.phase = PROBE;
            return;
        }
        e.probe += 1;
    }
    if e.gift_move >= 0 {
        e.chosen = e.gift_move;
        e.gifted = true;
        e.phase = READY;
        return;
    }
    choose(e);
}

// A candidate leaves the child something to find when the child has no capture (so
// nothing hangs: captures are forced, and a capture is no find), the child's best
// reply gains a good part of a man on the position as it stands, and few of the
// child's moves do as well: a combination. The computer loses at most about a man
// when the child finds it.
fn probe_done(e: Engine&) {
    let n = e.root_count;
    var best = -INF;
    var good = 0;
    for i in n {
        guard e.exact[i] else { continue; }
        good += 1;
        best = max(best, e.score[i]);
    }
    let gain = best - evaluate(e.root);
    let ours = -best;
    if gain >= FIND && good <= max(1, n / 3) && ours >= e.best - GIFT_COST && (e.gift_move < 0 || ours > e.gift_score) {
        e.gift_move = e.cands[e.probe];
        e.gift_score = ours;
    }
    next_probe(e);
}

// Picks among the moves within the level's margin of the best, each with a chance
// that falls by e for every `temper` it is worse (Regan and Haworth's model of how
// people of a given strength choose).
fn choose(e: Engine&) {
    let pr = e.params;
    var total = 0;
    for i in e.moves.len { total += weight(e, i, pr); }
    var r = rand_int(e.random, total);
    for i in e.moves.len {
        let w = weight(e, i, pr);
        if r < w {
            e.chosen = i;
            e.phase = READY;
            return;
        }
        r -= w;
    }
    assert(false);
}

// e^(-k / 16) in 1/65536, for k below 128; computed by integer steps so every machine
// agrees.
fn make_falloff() -> i64[128] {
    var t: i64[128] = [0; 128];
    t[0] = 65536;
    for k in 1..128 { t[k] = t[k - 1] * 61565 / 65536; }
    return t;
}

let FALLOFF = make_falloff();

fn weight(e: Engine&, i: i64, pr: Params) -> i64 {
    guard e.main_exact[i] else { return 0; }
    let worse = e.best - e.main_score[i];
    guard worse < pr.margin || worse == 0 else { return 0; }
    let k = worse * 16 / pr.temper;
    return if k < 128 { FALLOFF[k] } else { 0 };
}
