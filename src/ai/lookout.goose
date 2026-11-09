// The lookout's threats (docs/architecture/ai.md, "The lookout"): pure functions over
// `rules`, no graphics, so tests run them headless. What the other side could take or
// crown on were it its turn now, or once the side to move plays a move, each sorted by
// how plain it is to see. The game shows the kinds a player of its skill would miss
// (shown()); nothing here allocates, the caller passes the move buffer.
namespace lookout;
import std;

// What a threat is, from the plainest. A capture's pieces, or a crowning's square.
let NEAR = 0;       // one piece taken by a piece standing next to it
let FAR = 1;        // one piece taken from afar (a flying king)
let TWO = 2;        // two pieces taken in one capture
let MANY = 3;       // three or more
let STEP = 4;       // a man crowning by a step
let JUMP = 5;       // a man crowning through a capture
let KINDS = 6;

// The skill from which each kind is left to the player (docs/architecture/ai.md, "The
// lookout"): the computer's own horizon at that skill, as the game matches it to the
// player. From 15 it sees every one-piece capture next to its piece, and a man one step
// from crowning is as plain; from 25 every two-piece capture, and a flying king's from
// afar is as easy to miss; a crowning through a capture is a small combination, left
// from medium's start; three pieces or more show through medium. Hard's skills, 70 and
// up, show nothing.
let UNTIL: i64[KINDS] = [15, 25, 25, 70, 15, 40];

// The pieces or squares of each kind (pieces for the captures, the crowning squares for
// STEP and JUMP), as rules bits.
struct Seen { of: u64[KINDS] = [0; KINDS] }

// Whether the piece on `sq` stands next to `from`, a step away on a diagonal.
fn next_to(v: rules::Variant&, from: i64, sq: i64) -> bool {
    let dx = (v.x_of[from] as i64) - v.x_of[sq];
    let dy = (v.y_of[from] as i64) - v.y_of[sq];
    return abs(dx) == 1 && abs(dy) == 1;
}

// Sorts what move m of the threatening side takes or crowns on into `out`.
fn classify(v: rules::Variant&, m: rules::Move&, out: Seen&) {
    let crown = if m.captured != 0 { JUMP } else { STEP };
    if m.crowned { out.of[crown] |= rules::bit(m.to); }
    guard m.captured != 0 else { return; }
    let n = popcount(m.captured);
    let kind = if n >= 3 { MANY } else if n == 2 { TWO } else if next_to(v, m.from, ctz(m.captured)) { NEAR } else { FAR };
    out.of[kind] |= m.captured;
}

// What q's side to move threatens: every legal move's capture, its whole chain, and
// every crowning. Captures are compulsory, so when it must take, the crownings are those
// of its captures.
fn threats(q: rules::Position, out: Seen&, buf: rules::Moves&) {
    out = Seen {};
    let v .= rules::VARIANTS[q.variant];
    rules::generate(q, buf);
    for &m in buf { classify(v, m, out); }
}

// What threatens p's side to move now: the other side's moves were it its turn.
fn now(p: rules::Position, out: Seen&, buf: rules::Moves&) {
    var q = p;
    q.side = 1 - p.side;
    threats(q, out, buf);
}

// What threatens p's side to move once it plays m, one of p's legal moves: the other
// side's moves then. The piece m moves is marked on m.from, where the player holds it.
fn after(p: rules::Position, m: rules::Move, out: Seen&, buf: rules::Moves&) {
    threats(rules::play(p, m), out, buf);
    let to = rules::bit(m.to);
    for k in KINDS {
        guard k != STEP && k != JUMP && out.of[k] & to != 0 else { continue; }
        out.of[k] = (out.of[k] & ~to) | rules::bit(m.from);
    }
}

// The pieces in danger and the crowning squares in s, of every kind.
fn all(s: Seen&) -> u64, u64 {
    return s.of[NEAR] | s.of[FAR] | s.of[TWO] | s.of[MANY], s.of[STEP] | s.of[JUMP];
}

// The pieces in danger and the crowning squares of s that a player of `skill` is shown:
// the kinds they would miss (UNTIL).
fn shown(s: Seen&, skill: i64) -> u64, u64 {
    var danger: u64 = 0;
    var crowns: u64 = 0;
    for k in KINDS {
        guard skill < UNTIL[k] else { continue; }
        if k == STEP || k == JUMP { crowns |= s.of[k]; } else { danger |= s.of[k]; }
    }
    return danger, crowns;
}
