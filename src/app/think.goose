// The computer thinks on a worker thread, so the frame loop never waits for it
// (docs/architecture/ai.md, "Thinking on a worker"). Between search steps the worker
// looks for a newer ask, which drops the search under way; the game takes an answer only
// if its ask is still open.
namespace think;
import std;
import os;

// Nodes between looks at the queue.
let NODES = 10000;

// The move for the ask `id`, and what finding it took.
struct Thought {
    id:      i64,
    move:    rules::Move,
    found:   bool,          // false when the position had no move
    close:   i64,           // moves about as good as the best, for the time it takes (ai::close)
    nodes:   i64,
    seconds: f64,
    kind:    i64,           // game::THINK, HINT, TRAPS, or JUDGE, as asked
    pieces:  u64,           // the lookout's traps: the pieces they would win
    mark:    i64 = 0,       // JUDGE: the move's mark (ai::ONLY..BLUNDER) and its loss
    loss:    i64 = 0,
    best:    rules::Move = rules::Move { .. },  // JUDGE: the best move from the position, if has_best
    has_best: bool = false,
}

// The engine is the worker's own, since a root can't cross to a thread, made at the first
// search: the lookout's traps need none.
thread_fn worker() {
    var e = ai::Engine { .. };
    var made = false;
    var ask = qget<game::Ask>();
    loop {
        guard ask.id != 0 else {
            ask = qget<game::Ask>();
            continue;
        }
        let began = clock();
        if ask.kind == game::TRAPS {
            qput(Thought { id: ask.id, move: rules::Move { .. }, found: true, close: 0, nodes: 0, seconds: clock() - began,
                           kind: ask.kind, pieces: lookout::traps(ask.pos) });
            ask = qget<game::Ask>();
            continue;
        }
        if !made {
            ai::init(e);
            made = true;
        }
        // The hint is the move judging finds best, so a hint followed is never marked down.
        if ask.kind == game::JUDGE || ask.kind == game::HINT {
            ai::judge_start(e, ask.past, ask.pos);
            var newer = false;
            var next = ask;
            while !newer && !ai::judge_step(e, NODES) {
                let a, got = qpoll<game::Ask>();
                next = a;
                newer = got;
            }
            if newer {
                ask = next;
                continue;
            }
            if ask.kind == game::HINT {
                let found = e.moves.len > 0;
                let m = if found { ai::judged_best(e) } else { rules::Move { .. } };
                qput(Thought { id: ask.id, move: m, found: found, close: 0, nodes: e.nodes, seconds: clock() - began,
                               kind: ask.kind, pieces: 0 });
                ask = qget<game::Ask>();
                continue;
            }
            let v = ai::verdict(e, ask.move);
            qput(Thought { id: ask.id, move: ask.move, found: true, close: 0, nodes: e.nodes, seconds: clock() - began,
                           kind: ask.kind, pieces: 0, mark: v.mark, loss: v.loss, best: v.best_move,
                           has_best: v.has_best });
            ask = qget<game::Ask>();
            continue;
        }
        ai::start_after(e, ask.past, ask.pos, ask.skill, ask.seed);
        var newer = false;
        var next = ask;
        while !newer && !ai::step(e, NODES) {
            let a, got = qpoll<game::Ask>();
            next = a;
            newer = got;
        }
        if newer {
            ask = next;
            continue;
        }
        let found = ai::has_reply(e);
        var m = rules::Move { .. };
        if found { m = ai::reply(e); }
        qput(Thought { id: ask.id, move: m, found: found, close: ai::close(e, pace::CLOSE), nodes: e.total_nodes,
                       seconds: clock() - began, kind: ask.kind, pieces: 0 });
        ask = qget<game::Ask>();
    }
}

// The worker's side of the loop, kept by the app.
struct Thinker {
    worker: i64 = -1,       // started at the first ask
    sent:   i64 = 0,        // the ask it has last been given
}

// Gives the worker the game's ask when it changed, and the game an answer that came. True
// when a hint or traps came, which nothing else would draw.
fn frame(t: Thinker&, gm: game::Game&) -> bool {
    if game::open_ask(gm) != t.sent {
        let ask = game::ask_for(gm);
        if t.worker < 0 && ask.id != 0 { t.worker = thread_spawn(worker); }
        if t.worker >= 0 { qput(ask); }
        t.sent = ask.id;
    }
    guard t.worker >= 0 else { return false; }
    let th, got = qpoll<Thought>();
    guard got && th.found else { return false; }
    if th.kind == game::TRAPS { return game::trapped(gm, th.id, th.pieces); }
    if th.kind == game::JUDGE { return game::judged(gm, th.id, th.mark, th.loss, th.best, th.has_best); }
    if th.kind == game::HINT {
        game::hinted(gm, th.id, th.move);
        return true;
    }
    game::answer(gm, th.id, th.move, th.close);
    return false;
}
