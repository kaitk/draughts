// What the board and the game say happened, for the app's sounds (docs/architecture/
// sound.md): sound events, with no sound of their own. The board adds one as its
// animation gets there (a piece landing, a capture's stop) or as a move is refused; the
// game adds its end and its clocks'. The app plays them once a frame, after
// `one_per_move` has kept one sound a move. Input says nothing: a tap is never heard,
// only what it did on the board.
namespace sound_event;
import std;

let NONE = -1;
let MOVE = 0;               // a piece set down
let STOP = 1;               // a capture's stop before its last, `step` the stops before it
let TAKE = 2;               // a capture's last landing: the taken pieces come off
let CROWN = 3;              // a man crowned as it lands
let WRONG = 4;              // a wrong move: the piece slides back, or a square no move goes to
let MUST = 5;               // a piece or square chosen while another piece must capture
let GOLD = 6;               // a person's clock under a minute
let RED = 7;                // a person's clock at 0:20
let SOLVED = 8;             // a puzzle's last move
let WON = 9;                // a game won: the child's against the computer, either side's against a friend
let LOST = 10;              // a game lost to the computer
let DRAWN = 11;
let CROWN_COMPUTER = 12;    // the computer's man crowned (the shell's, from a CROWN on the game's board)
let KINDS = 13;

struct Event {
    kind: i64 = NONE,
    step: i64 = 0,
}

// A frame's sound events: more than a frame ever says, and any past it are dropped.
let MOST = 8;
type Events = Event[..MOST];

fn add(cs: Events&, kind: i64, step: i64 = 0) {
    guard cs.len < MOST && kind != NONE else { return; }
    cs.push(Event { kind: kind, step: step });
}

// A move's landing: crowned, else the taken pieces, else the piece set down.
fn landing(captured: bool, crowned: bool) -> i64 {
    if crowned { return CROWN; }
    return if captured { TAKE } else { MOVE };
}

// How much an event that ends a move says, to keep the most of a move's: the game's end,
// then a crowning, then the taken pieces, then the piece set down; 0 for an event that is no
// move's end (a stop, a wrong move, a capture due, a clock), which is always kept.
fn rank(kind: i64) -> i64 {
    if kind == SOLVED || kind == WON || kind == LOST || kind == DRAWN { return 4; }
    if kind == CROWN || kind == CROWN_COMPUTER { return 3; }
    if kind == TAKE { return 2; }
    return if kind == MOVE { 1 } else { 0 };
}

// One sound a move: of a frame's events, those that end a move give way to the most
// important of them, which keeps its place; the rest stay in their order.
fn one_per_move(cs: Events&) {
    var best = -1;
    for c, i in cs { if rank(c.kind) > 0 && (best < 0 || rank(c.kind) > rank(cs[best].kind)) { best = i; } }
    guard best >= 0 else { return; }
    var kept: Events = [];
    for c, i in cs { if rank(c.kind) == 0 || i == best { kept.push(c); } }
    cs = kept;
}

// The clock's two warnings, each said once a side a game: an increment that lifts the time
// back over a line doesn't arm it again; a new game does (a fresh Chimes).
struct Chimes {
    gold: bool[2] = [false, false],
    red:  bool[2] = [false, false],
}

// The event for `side`'s clock: GOLD the first time it runs under a minute (`warn`), RED the
// first time at 0:20 (`low`), which also spends the gold; nothing for the computer's
// clock (`person` false), or an event said already.
fn chime(ch: Chimes&, side: i64, warn: bool, low: bool, person: bool) -> i64 {
    guard person && side >= 0 && side < 2 else { return NONE; }
    if low && !ch.red[side] {
        ch.red[side] = true;
        ch.gold[side] = true;
        return RED;
    }
    if warn && !ch.gold[side] {
        ch.gold[side] = true;
        return GOLD;
    }
    return NONE;
}
