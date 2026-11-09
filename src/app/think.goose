// The computer thinks on a worker thread, so the frame loop never waits for it
// (docs/architecture/ai.md, "Thinking on a worker"). The game asks for a move
// (game::Ask) and the loop puts the ask on its queue; the worker finds the move in steps
// and, between steps, looks for a newer ask: take back, start over, or leaving the game
// asks for something else or for nothing (id 0), and the search under way is dropped.
// It answers with a Thought, which the game takes only if its ask is still open. Idle,
// the worker waits on the queue and uses no CPU.
namespace think;
import std;
import os;

// Nodes between looks at the queue: about 2 ms on the tablet's big cores.
let NODES = 10000;

// The move for the ask `id`, and what finding it took.
struct Thought {
    id:      i64,
    move:    rules::Move,
    found:   bool,          // false when the position had no move
    close:   i64,           // moves about as good as the best, for the time it takes (ai::close)
    nodes:   i64,
    seconds: f64,
    kind:    i64,           // game::THINK or game::HINT, as asked
}

// The engine is the worker's own, made once: a root can't cross to a thread.
thread_fn worker() {
    var e = ai::Engine { .. };
    ai::init(e);
    var ask = qget<game::Ask>();
    loop {
        guard ask.id != 0 else {
            ask = qget<game::Ask>();
            continue;
        }
        let began = clock();
        // The hint's search sees all and leaves nothing, and gives the best it sees.
        let hint = ask.kind == game::HINT;
        ai::helping(e, hint);
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
        if found { m = if hint { ai::best(e) } else { ai::reply(e) }; }
        qput(Thought { id: ask.id, move: m, found: found, close: ai::close(e, pace::CLOSE), nodes: e.total_nodes,
                       seconds: clock() - began, kind: ask.kind });
        ask = qget<game::Ask>();
    }
}

// The worker's side of the loop, kept by the app.
struct Thinker {
    worker: i64 = -1,       // started at the first ask
    sent:   i64 = 0,        // the ask it has last been given
}

// Each frame: gives the worker the game's ask when it changed (the computer's move or the
// hint's, game::open_ask), and the game the answer when one has come. True when a hint's
// answer came, which nothing else draws: the app draws it, and the frame after.
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
    if th.kind == game::HINT {
        game::hinted(gm, th.id, th.move);
        return true;
    }
    game::answer(gm, th.id, th.move, th.close);
    return false;
}
