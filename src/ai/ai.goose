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
//   while !ai::step(e, 10000) { a newer ask? }    the app's worker thread looks for a
//                                                 newer ask every 10000 nodes, about
//                                                 2 ms on the tablet's big cores
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

// Skill runs 0 to 100. Each level starts at its own and adapts between its floor and
// its top: easy starts at its floor, so it can only climb from where a young child
// begins (the user's call, 2026-11-09).
let LEVEL_SKILL: i64[LEVELS] = [0, 40, 90];
let LEVEL_FLOOR: i64[LEVELS] = [0, 25, 70];   // the lowest a level adapts to (medium never under 25)
let LEVEL_TOP:   i64[LEVELS] = [30, 60, 100]; // the highest
let STEP = 4;               // how far one win or loss moves the skill
let FIRST_STEP = 8;         // how far it moves over a player's first games against a level
let FIRST_GAMES = 3;        // how many games that is

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

// Overlooking the child's captures, as a person errs: where captures are around, more
// the more pieces a capture takes and the further it starts from the piece just moved
// (docs/architecture/ai.md, "Levels"). Each reply capture after each of its moves is
// seen or not by its own seeded chance, in 1/1000: MISS by the pieces it takes (1, 2, 3,
// 4 or more) at skill 0 in a tense position, next to the moved piece, fading with the
// square of the way left to SURE, where it is none; times FAR by how far it starts from
// that piece, in quarters; times QUIET in percent where no capture is around.
let MISS: i64[4] = [25, 300, 300, 450];
let SURE: i64[4] = [15, 25, 65, 65];   // from these skills on it sees every such capture
let FAR:  i64[4] = [4, 5, 6, 8];       // a step away (as a capture of the moved piece starts), 2, 3, 4 or more
let QUIET = 10;
let LAND = 1;               // Engine.overlook: it missed a capture of the piece it moved
let OPEN = 2;               // or another of the child's captures

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
    miss:   i64[4],         // per thousand, how often it misses a capture of 1, 2, 3, 4+ pieces (MISS)
}

fn params(skill: i64) -> Params {
    let s = clamp(skill, 0, 100);
    let temper = 2 + 60 * (100 - s) * (100 - s) / 10000;
    var miss: i64[4] = [0; 4];
    for i in 4 { miss[i] = MISS[i] * max(SURE[i] - s, 0) * max(SURE[i] - s, 0) / (SURE[i] * SURE[i]); }
    return Params {
        depth:  1 + s / 12 + max(s - 60, 0) / 6,
        extra:  2 + s / 8,
        margin: min(MAX_MARGIN, 3 * temper),
        temper: temper,
        gift:   max(GIFT_SKILL - s, 0) * GIFT_CHANCE,
        miss:   miss,
    };
}

// The starting skill of a level.
fn level_skill(level: i64) -> i64 { LEVEL_SKILL[clamp(level, 0, LEVELS - 1)] }

// A skill kept within its level's floor and top.
fn within(skill: i64, level: i64) -> i64 {
    let l = clamp(level, 0, LEVELS - 1);
    return clamp(skill, LEVEL_FLOOR[l], LEVEL_TOP[l]);
}

// The skill for the next game after one at `skill` on `level`, the player having
// finished `played` games on it before this one: up a step when the person won, down a
// step when the computer did (child_won 1, -1, or 0 for a draw), so a child meets an
// opponent they beat about half the time. Over the first games the steps are larger,
// so the skill finds the child quickly.
fn adapt(skill: i64, level: i64, child_won: i64, played: i64) -> i64 {
    let step = if played < FIRST_GAMES { FIRST_STEP } else { STEP };
    return within(skill + step * clamp(child_won, -1, 1), level);
}

root struct Engine {
    tt:    Entry[>..] = [],
    plies: Ply[>..]   = [],
    // Move ordering, reset for each search.
    history:    i32[64 * 64]     = [0; 64 * 64],
    killer:     u16[MAX_PLY * 2] = [0; MAX_PLY * 2],
    use_tt:     bool             = true, // off only to test that the table changes no result
    node_limit: i64              = NODE_LIMIT,
    overlooks:  i64              = 100,  // percent of the overlook chances: 0 to measure without
    blind:      bool,           // whether the search under way may overlook (only the main search)
    tense:      bool,           // whether a capture is around the position a move is found for
    hidden:     u64,            // the seed of what this move overlooks
    // The search under way (search.goose).
    root:       rules::Position,
    root_draw:  rules::Draw,                // the draw counts at the search's root
    draw_at:    rules::Draw,                // the game's, at the position a move is found for
    past:       u64[..rules::PAST],          // the keys of the game's positions before the root, oldest first
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
    overlook:   i64,            // what the reply overlooked: LAND, OPEN, both, or 0
    budget:     i64,
    // What the last search did, for benchmarks.
    total_nodes: i64,
    seen:        i64,           // the deepest iteration the main search finished
}

// Begins finding a move for p at `skill`, with `seed` for the choices among good moves,
// as a game begins at p: no position before it.
fn start(e: Engine&, p: rules::Position, skill: i64, seed: u64) {
    e.past.clear();
    e.draw_at = rules::draw_start(p);
    begin_move(e, p, skill, seed);
}

// The same in a game that went through `past` to p: the search sees its draws by
// repetition and by the counts (rules/draw.goose).
fn start_after(e: Engine&, past: rules::Past&, p: rules::Position, skill: i64, seed: u64) {
    e.past.clear();
    for &q in past.before { e.past.push(key(q)); }
    e.draw_at = past.draw;
    begin_move(e, p, skill, seed);
}

fn begin_move(e: Engine&, p: rules::Position, skill: i64, seed: u64) {
    init(e);
    e.root_draw = e.draw_at;
    notice(e, p, skill, seed);
    e.random = rng { seed };
    e.total_nodes = 0;
    e.seen = 0;
    e.chosen = -1;
    e.gifted = false;
    e.gift_move = -1;
    e.overlook = 0;
    rules::generate(p, e.moves);
    if e.moves.len <= 1 {
        e.chosen = if e.moves.len == 1 { 0 } else { -1 };
        e.phase = READY;
        return;
    }
    e.gift = rand_int(e.random, 1000) < e.params.gift;
    let margin = if e.gift { max(e.params.margin, GIFT_COST) } else { e.params.margin };
    begin(e, p, e.params.depth, e.params.extra, margin, e.node_limit);
    e.blind = e.overlooks > 0 && e.params.miss[3] > 0;
    e.phase = MAIN;
}

// Sets up finding a move for p at `skill` as far as what it overlooks goes: the
// skill's chances, whether a capture is around p (its side must capture, or the other
// side could were it its turn: a piece of its is attacked), and the seed of what it
// overlooks, apart from the one of its choices among moves, so those stay as they were
// where nothing is overlooked. Two move generations into the first frame's buffer,
// before the search fills it.
fn notice(e: Engine&, p: rules::Position, skill: i64, seed: u64) {
    e.position = p;
    e.params = params(skill);
    e.hidden = seed ^ 0x9E3779B97F4A7C15;
    let buf .= e.plies[0].moves;
    rules::generate(p, buf);
    e.tense = buf.len > 0 && buf[0].captured != 0;
    guard !e.tense else { return; }
    var other = p;
    other.side = 1 - p.side;
    rules::generate(other, buf);
    e.tense = buf.len > 0 && buf[0].captured != 0;
}

// What the reply overlooks: LAND when it misses a capture of the piece it moves, OPEN
// another of the child's captures.
fn missed(e: Engine&) {
    e.overlook = 0;
    guard e.overlooks > 0 && e.params.miss[3] > 0 && e.chosen >= 0 else { return; }
    let m = e.moves[e.chosen];
    let buf .= e.plies[1].moves;
    rules::generate(rules::play(e.position, m), buf);
    guard buf.len > 0 && buf[0].captured != 0 else { return; }
    let moved = rules::bit(m.to);
    for i in buf.len {
        guard overlooked(e, m, buf[i]) else { continue; }
        e.overlook |= if buf[i].captured & moved != 0 { LAND } else { OPEN };
    }
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

// The same in a game that went through `past` to p.
fn think_after(e: Engine&, past: rules::Past&, p: rules::Position, skill: i64, seed: u64) -> rules::Move {
    start_after(e, past, p, skill, seed);
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
        // The probes search the child's replies: the position is then the game's last.
        if e.past.len == rules::PAST {
            for i in rules::PAST - 1 { e.past[i] = e.past[i + 1]; }
            e.past.pop();
        }
        e.past.push(key(e.position));
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
        let m = e.moves[e.cands[e.probe]];
        let q = rules::play(e.position, m);
        rules::generate(q, e.plies[0].moves);
        if e.plies[0].moves.len >= 2 && e.plies[0].moves[0].captured == 0 {
            e.root_draw = rules::draw_after(e.draw_at, e.position, m, q);
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
            missed(e);
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

// How many moves the main search saw within `window` of the best: 1 when one move stands
// out, more when several are about as good. A forced move counts as itself. Only after
// step returned true.
fn close(e: Engine&, window: i64) -> i64 {
    guard e.moves.len > 1 else { return e.moves.len; }
    var n = 0;
    for i in e.moves.len {
        if e.main_exact[i] && e.best - e.main_score[i] <= window { n += 1; }
    }
    return n;
}
