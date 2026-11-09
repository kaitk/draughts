// The board on screen, with no graphics: where it goes, which square a point is on,
// what a tap or a drag does, how a move animates, and what to draw each frame. The app
// (app/draughts.goose) feeds it input and time and draws what it fills in; tests run it
// headless. Values are from docs/architecture/rendering.md ("Look").
//
// Nothing here allocates: the legal moves and the draw lists are fixed buffers in the
// `Board` the caller owns.
namespace board;
import std;
import math;
import vec;
import rules from "../rules";
import .view3d;

let MAX_PIECES = 48;        // 40 pieces on 10×10, the moving one, and margin
let HOP = 0.2;              // seconds per square of a quiet move, per stop of a capture
let FADE = 0.18;            // captured pieces fade out after the move
let PULSE = 2.8;            // must-capture rings pulse for two of their 1.4 s cycles
let DRAG_START = 10.0;      // dp a press moves before it becomes a drag
let SNAP = 0.9;             // squares from a square's center a press or drop off the dark squares still reaches
let FLASH = 1.2;            // a wrong move's red ring flashes twice, 0.6 s each
let MAX_HISTORY = 512;      // moves undo can take back; the oldest go first

// Move hints (docs/product.md): mistakes only, the default, marks a wrong move and pulses
// the pieces that must capture, and a second wrong square in a capture lights its next
// stop; moves also shows the selected piece's targets.
let MISTAKES = 0;
let MOVES = 1;

// How a king is drawn (rendering.md, "Kings"): a crown on its face, or a stack of two
// plain discs. A piece's look.y is 0 for a man or one of these.
let CROWN = 1;
let STACK = 2;

// Where the board goes, in pixels. `scale` is pixels per dp: the prototypes' 800 px short
// side. The screens place it: the game's panels beside it (game/panel.goose), or alone.
struct Layout {
    scale: f32,
    board: float4,      // x, y, size of the board; w: the corner radius
    inner: float4,      // x, y, size of the squares inside the board's thin lip; w: one square
    n:     i64,         // squares per side
    flip:  bool,        // turned, black playing up the screen: a child playing black
}

// dp: a board beside a screen's controls (home's, a setup's, settings' preview) smaller
// than this isn't shown, where a phone leaves it too little room: its squares would be
// under 13 dp on 10 × 10, too small to read a position from.
let SMALLEST = 128.0;

// A board of side `size` at x, y.
fn layout_at(x: f32, y: f32, size: f32, scale: f32, n: i64) -> Layout {
    var l = Layout { scale: scale, board: float4 { x, y, size, 0.016 * size }, n: n, .. };
    place(l);
    return l;
}

// The squares inside the board's thin lip.
fn place(l: Layout&) {
    let lip = 0.011 * l.board.z;
    let inner = l.board.z - 2.0 * lip;
    l.inner = float4 { l.board.x + lip, l.board.y + lip, inner, inner / l.n };
}

// The square under a point, as a rules bit, or -1. White plays up the screen, black on
// a turned board.
fn hit(l: Layout, v: rules::Variant&, p: float2) -> i64 {
    let fx = (p.x - l.inner.x) / l.inner.w;
    let fy = (p.y - l.inner.y) / l.inner.w;
    guard fx >= 0.0 && fy >= 0.0 && fx < v.size && fy < v.size else { return -1; }
    let x = floor(fx) as i64;
    let row = floor(fy) as i64;
    return if l.flip { rules::bit_at(v, v.size - 1 - x, row) } else { rules::bit_at(v, x, v.size - 1 - row) };
}

// The center of a square, in pixels.
fn center(l: Layout, v: rules::Variant&, b: i64) -> float2 {
    var x = v.x_of[b] as f32;
    var row = (v.size - 1 - v.y_of[b]) as f32;
    if l.flip {
        x = (v.size - 1) - x;
        row = (v.size - 1) - row;
    }
    return float2 { l.inner.x + (x + 0.5) * l.inner.w, l.inner.y + (row + 0.5) * l.inner.w };
}

// One piece to draw: where, how big, how high, and its state. The app copies these into
// the storage buffer the piece shader pulls from.
struct Piece {
    at:   float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x, y center in pixels, radius, lift in pixels
    look: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // black (0 or 1), 0 or CROWN or STACK, selected glow 0..1, opacity
    ring: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x: must-capture ring, 1 pulsing, 2 still; y: a glow ring tight round it, 0 to 1; z: pieces it takes, as pips
    win:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // a win (game::cheer): x dimmed by, 0..1; y its square lit, 0..1; z the square's half side in radii; w: over the UI, 1 on the board (a win's card's piece)
}

// What the board shader marks, one bit per square numbered y * size + x.
struct Marks {
    last:   u32[4] = [0; 4],
    target: u32[4] = [0; 4],
    via:    u32[4] = [0; 4],
    next:   u32[4] = [0; 4],    // where a piece waiting on a stop goes on to, pulsing (flash.z)
}

// A position the game was in, for undo, with the move that led to it.
struct Step {
    pos:       rules::Position,
    last_from: u8,
    last_to:   u8,
    has_last:  bool,
}

struct Board {
    variant:  u8,
    start:    rules::Position,  // where the game began, for restart
    pos:      rules::Position,
    history:  Step[..MAX_HISTORY],  // the positions before each move, oldest first
    moves:    rules::Moves,     // the legal moves of pos
    selected: i64,              // a bit, or -1
    steps:    rules::Path,      // the stops of a capture tapped so far, after the selected piece's square
    // A puzzle's board: a capture is made stop by stop as in a game (`follow`), but
    // nothing shows the way: no count on the pieces that must capture, no pieces to
    // take after a wrong square, and no next stop after two.
    by_hand: bool,
    // When the piece last came to wait on a stop, or a second wrong square lit the next
    // stops: the squares it goes on to pulse from then, when they are shown (next_shown).
    kept_at: f64,
    // Wrong squares in this turn's capture (`missed`): the first pulses what to take,
    // the second lights the next stop.
    misses: i64,
    // No count on the pieces that must capture: the computer is to move (game::frame).
    quiet: bool,
    // The move being shown: the position before it, when it started, and where the
    // piece starts from if it was dropped there; `back`, a move shown sliding back.
    moving:    bool,
    back:      bool,
    move:      rules::Move,
    before:    rules::Position,
    since:     f64,
    drop:      float2,
    dropped:   bool,
    skip:      i64,             // the hops of the move already made by hand, not shown again
    last:      rules::Move,
    has_last:  bool,
    pulse_end: f64,
    // The pieces the legal captures take, pulsing beside the pieces that must take them,
    // after a tap on a piece that could take but fewer (the majority rule): the reason.
    outtaken:  u64,
    hints:     i64,             // MISTAKES or MOVES
    wrong:     i64,             // the square of the last wrong move, a bit, or -1
    wrong_at:  f64,
    ghost:     bool,            // a ghost of the piece that slid back fades on the wrong square
    ghost_of:  float2,          // its side (0 or 1) and whether it is a king
    glow:      i64,             // the piece a hint shows with a glow ring, a bit, or -1
    glow_at:   f64,
    king_look: i64,             // CROWN or STACK
    // A picture rather than a game (settings' preview): once a wrong move's ring has
    // flashed, it stays, and once the pieces that must capture have pulsed, their rings
    // stay, lit and still (`held`), so the picture needs no frames after.
    still: bool,
    held:  bool,
    // A press on a piece, and whether it became a drag.
    pressed:  i64,
    press_at: float2,
    dragging: bool,
    drag_at:  float2,
    // Filled by fill() for the app to draw.
    pieces: Piece[..MAX_PIECES],
    marks:  Marks,
    flash:  float4,             // x: the wrong move's square (y * size + x) or -1; y: its flash, 0..1; z: marks.next's dots, 0..1
    dim:    f32,                // the board dimmed by, 0..1, under a win (game::cheer)
}

fn new(variant: u8) -> Board {
    var b = Board { variant: variant, selected: -1, wrong: -1, glow: -1, king_look: CROWN, pressed: -1, .. };
    set(b, rules::start(variant));
    return b;
}

// Shows position p with nothing selected, moving, or flashing.
fn show(b: Board&, p: rules::Position) {
    b.pos = p;
    rules::generate(b.pos, b.moves);
    b.selected = -1;
    b.steps.clear();
    b.moving = false;
    b.wrong = -1;
    b.held = false;
    b.pulse_end = 0.0;
    b.outtaken = 0;
    b.pressed = -1;
    b.dragging = false;
    b.back = false;
    b.ghost = false;
    b.glow = -1;
    b.kept_at = -1.0;
    b.misses = 0;
}

// Starts a new game from position p.
fn set(b: Board&, p: rules::Position) {
    b.start = p;
    b.history.clear();
    b.has_last = false;
    show(b, p);
}

// Starts the game over from where it began.
fn restart(b: Board&) { set(b, b.start); }

// Starts a new game of another variant, from its start.
fn reset(b: Board&, variant: u8) {
    b.variant = variant;
    set(b, rules::start(variant));
}

// Takes back the last move, even one still animating; false when there is none.
fn undo(b: Board&) -> bool {
    guard b.history.len > 0 else { return false; }
    let s = b.history.pop();
    b.has_last = s.has_last;
    b.last = rules::Move { from: s.last_from, to: s.last_to, .. };
    show(b, s.pos);
    return true;
}

// The side that has won, the other having no move left, or -1 while the game goes on
// or a move is still showing.
fn winner(b: Board&) -> i64 {
    guard !b.moving && b.moves.len == 0 else { return -1; }
    return 1 - b.pos.side as i64;
}

// A hint (puzzles): the piece on `sq` glows, pulsing for two cycles, then lit and still.
fn glow_on(b: Board&, sq: i64, now: f64) {
    b.glow = sq;
    b.glow_at = now;
}

// Takes back the last move, m, as a mistake: the piece slides back along its way and
// the pieces it took fade back in, while its square flashes the red ring over a fading
// ghost of it. Not a `mistake`, it slides back without them: a puzzle's answer that
// showed why a move was wrong, before the move itself. The board keeps only the last
// move it played, so the caller passes m: after one move is taken back, the move under
// it is the caller's to know. False when there is no move to take back.
fn slide_back(b: Board&, m: rules::Move, now: f64, mistake: bool = true) -> bool {
    guard b.history.len > 0 else { return false; }
    let side = 1 - b.pos.side;
    let king = b.pos.kings & rules::bit(m.to) != 0;
    undo(b);
    b.move = m;
    b.before = b.pos;
    b.moving = true;
    b.back = true;
    b.since = now;
    b.dropped = false;
    b.skip = 0;
    guard mistake else { return true; }
    b.wrong = m.to;
    b.wrong_at = now;
    b.ghost = true;
    b.ghost_of = float2 { side, if king { 1.0 } else { 0.0 } };
    return true;
}

fn has_move_from(b: Board&, from: i64) -> bool {
    for i in b.moves.len { if b.moves[i].from == from { return true; } }
    return false;
}

// Whether move m is the selected piece's and makes the stops tapped so far, with more of
// its way still to come.
fn on_steps(b: Board&, m: rules::Move&) -> bool {
    guard m.from == b.selected && m.path.len > b.steps.len + 1 else { return false; }
    for s, k in b.steps { if m.path[k + 1] != s { return false; } }
    return true;
}

// What a tap or a drop on `sq` does for the selected piece, among its moves that make
// the stops tapped so far. One ending just after them on sq is played. Else, if sq is
// the next stop of any of them, it is kept, the piece waiting there to be tapped or
// dragged on: the rest of the way is never played by itself, in a game as in a puzzle
// (2026-11-09: a child whose first jump played the whole capture never learned its
// way). A capture's last square further on is played when one capture alone goes
// there; one several reach waits for the stops. Returns the move to play or -1, and
// whether sq was taken as part of a way, so not a mistake.
fn follow(b: Board&, sq: i64) -> i64, bool {
    guard b.selected >= 0 && sq >= 0 else { return -1, false; }
    let k = b.steps.len + 1;    // where sq stands in a way
    var end = -1;
    var vias = 0;
    for m, i in b.moves {
        guard on_steps(b, m) else { continue; }
        if m.to == sq {
            if end < 0 || (m.path.len == k + 1 && b.moves[end].path.len != k + 1) { end = i; }
        } else if m.path[k] == sq {
            vias++;
        }
    }
    if end >= 0 && b.moves[end].path.len == k + 1 { return end, false; }
    if vias > 0 {
        b.steps.push(sq as u8);
        return -1, true;
    }
    guard end >= 0 else { return -1, false; }
    for m in b.moves {
        if on_steps(b, m) && m.to == sq && m.captured != b.moves[end].captured { return -1, true; }
    }
    return end, false;
}

// How many pieces the piece on `sq` takes from here, at most: the most its captures
// take, less the stops already made when it waits on one. Each stop takes one piece,
// whatever squares a flying king could land on after it. 0 when it can't take.
fn takes(b: Board&, sq: i64) -> i64 {
    var most = 0;
    let made = if sq == b.selected { b.steps.len } else { 0 };
    for m in b.moves {
        guard m.from == sq && m.captured != 0 else { continue; }
        guard made == 0 || on_steps(b, m) else { continue; }
        most = max(most, popcount(m.captured) - made);
    }
    return most;
}

// The squares the selected piece can go to next: a move's target or a capture's next stop.
fn reachable(b: Board&) -> u64 {
    var r: u64 = 0;
    for m in b.moves { if on_steps(b, m) { r |= rules::bit(m.path[b.steps.len + 1]); } }
    return r;
}

// The square p is on or, when it is on a light square or just off the board, which is
// no square to play, the nearest of `want` within SNAP squares: a finger on a small
// board often lands a little off. A press or drop on a dark square is never moved.
fn snap(l: Layout, v: rules::Variant&, p: float2, want: u64) -> i64 {
    let sq = hit(l, v, p);
    guard sq < 0 else { return sq; }
    var best = -1;
    var near = SNAP * l.inner.w;
    var w = want;
    while w != 0 {
        let s = ctz(w);
        w &= w - 1;
        let d = length(center(l, v, s) - p);
        if d < near {
            near = d;
            best = s;
        }
    }
    return best;
}

// The square the selected piece waits on, partway through a capture, or -1.
fn waiting(b: Board&) -> i64 {
    guard b.selected >= 0 && b.steps.len > 0 else { return -1; }
    return b.steps[b.steps.len - 1];
}

fn start_move(b: Board&, i: i64, now: f64) {
    if b.history.len == MAX_HISTORY {
        for k in MAX_HISTORY - 1 { b.history[k] = b.history[k + 1]; }
        b.history.pop();
    }
    b.history.push(Step { pos: b.pos, last_from: b.last.from, last_to: b.last.to, has_last: b.has_last });
    b.move = b.moves[i];
    b.before = b.pos;
    b.pos = rules::play(b.pos, b.move);
    rules::generate(b.pos, b.moves);
    b.moving = true;
    b.since = now;
    b.last = b.move;
    b.has_last = true;
    b.selected = -1;
    b.steps.clear();
    b.glow = -1;
    b.kept_at = -1.0;
    b.misses = 0;
    // The must-capture pulse belongs to the position the mistake was made in: left on, it
    // would ring the next side's capturers, the computer's pieces after the child's move.
    b.pulse_end = 0.0;
    b.outtaken = 0;
    // A move starts from its square unless release says it was dropped elsewhere; a
    // move played by code (the computer's) must not start from the last drop.
    b.dropped = false;
    b.skip = 0;
}

// Plays move i, the selected piece's, chosen by a tap or a drop. Made by hand, it is
// shown from the stop the piece waits on: the hops before it are already behind it.
fn play_chosen(b: Board&, i: i64, now: f64) {
    let skip = if waiting(b) >= 0 { b.steps.len } else { 0 };
    start_move(b, i, now);
    b.skip = skip;
    b.since = now - (skip as f64) * HOP;
}

// Leaves a capture made by hand unfinished, which is no move (a capture takes every
// piece it can): the piece slides back from the stop it waits on to its square, which
// flashes the red ring over a fading ghost of it, as slide_back. False when no piece
// waits.
fn abandon(b: Board&, now: f64) -> bool {
    let at = waiting(b);
    guard at >= 0 && !b.moving else { return false; }
    var m = rules::Move { from: b.selected as u8, to: at as u8, crowned: false, captured: 0, path: [] };
    m.path.push(b.selected as u8);
    for s in b.steps { m.path.push(s); }
    let king = b.pos.kings & rules::bit(b.selected) != 0;
    b.move = m;
    b.before = b.pos;
    b.moving = true;
    b.back = true;
    b.since = now;
    b.dropped = false;
    b.skip = 0;
    b.wrong = at;
    b.wrong_at = now;
    b.ghost = true;
    b.ghost_of = float2 { b.pos.side as f32, if king { 1.0 } else { 0.0 } };
    b.selected = -1;
    b.steps.clear();
    b.pressed = -1;
    b.dragging = false;
    return true;
}

fn must_capture(b: Board&) -> bool { b.moves.len > 0 && b.moves[0].captured != 0 }

// A wrong move ending on square `sq`: its ring flashes, and if a capture was due, the
// pieces that must capture pulse.
fn mistake(b: Board&, sq: i64, now: f64) {
    b.steps.clear();
    b.wrong = sq;
    b.wrong_at = now;
    b.held = false;
    b.outtaken = 0;
    if must_capture(b) { b.pulse_end = now + PULSE; }
}

// The pieces the selected piece has jumped on its way to the stop it waits on: the one
// on each diagonal between two stops.
fn jumped(b: Board&) -> u64 {
    let v .= rules::VARIANTS[b.variant];
    let them = b.pos.pieces[1 - b.pos.side];
    var out: u64 = 0;
    var a = b.selected;
    for s in b.steps {
        let to_x = v.x_of[s] as i64;
        let dx: i64 = if to_x > v.x_of[a] { 1 } else { -1 };
        let dy: i64 = if v.y_of[s] > v.y_of[a] { 1 } else { -1 };
        var x: i64 = v.x_of[a] + dx;
        var y: i64 = v.y_of[a] + dy;
        while x != to_x {
            let q = rules::bit_at(v, x, y);
            if them & rules::bit(q) != 0 { out |= rules::bit(q); }
            x += dx;
            y += dy;
        }
        a = s;
    }
    return out;
}

// A tap or a drop on `sq`, an empty square that is no move for the selected piece: a
// mistake. If the piece must capture, in a game the first such square in a turn also
// pulses the pieces its captures have still to take, so a child sees what it must take:
// a far-row square a capture only passes, or one a shorter capture ends on that the
// majority rule forbids, looks like a move. The second lights the next stops as target
// dots (next_shown) for the rest of the capture. A piece waiting on a stop stays there:
// the jumps it made were right (2026-11-09). A puzzle shows neither and forgets the
// stops; its own hint comes after two misses (shell/puzzle.goose).
fn missed(b: Board&, sq: i64, now: f64) {
    let made = b.steps;
    mistake(b, sq, now);
    guard !b.by_hand && must_capture(b) else { return; }
    b.steps = made;
    b.misses++;
    if b.misses == 1 {
        for m in b.moves { if on_steps(b, m) { b.outtaken |= m.captured; } }
        b.outtaken &= ~jumped(b);
    }
    if b.misses == 2 { b.kept_at = now; }
}

// A piece came to wait on a stop (`follow`): what it goes on to pulses from now.
fn kept(b: Board&, before: i64, now: f64) {
    if b.steps.len > before { b.kept_at = now; }
}

// Take back while a piece waits partway through a capture: the capture goes back to its
// start, the piece on its square and nothing selected; no move is taken back. False when
// no piece waits.
fn unwind(b: Board&) -> bool {
    guard waiting(b) >= 0 && !b.moving else { return false; }
    b.selected = -1;
    b.steps.clear();
    b.pressed = -1;
    b.dragging = false;
    b.kept_at = -1.0;
    return true;
}

// A tap on the piece on `sq`, which could take but fewer than the pieces that must
// capture (the majority rule): a mistake, and the pieces their captures take pulse too,
// so the child sees the other piece takes more.
fn outnumbered(b: Board&, sq: i64, now: f64) {
    mistake(b, sq, now);
    for m in b.moves { b.outtaken |= m.captured; }
}

fn empty(b: Board&, sq: i64) -> bool {
    sq >= 0 && ((b.pos.pieces[rules::WHITE] | b.pos.pieces[rules::BLACK]) >> sq) & 1 == 0
}

// A finger or the mouse goes down at p. On a piece that can move: select it (and it may
// be dragged). On a target of the selected piece: play that move; on the next stop of
// its captures, keep it (`follow`). On the stop a piece waits on, partway through a
// capture made by hand: that piece, which may be dragged on. On another empty square
// while a piece is selected, or on a piece that can't move because another must capture:
// a mistake. Elsewhere: deselect. A press off the dark squares goes to the nearest of
// those it could mean, within SNAP (`snap`).
fn press(b: Board&, l: Layout, p: float2, now: f64) {
    guard !b.moving else { return; }
    let v .= rules::VARIANTS[b.variant];
    var want = reachable(b);
    for m in b.moves { want |= rules::bit(m.from); }
    if waiting(b) >= 0 { want |= rules::bit(waiting(b)); }
    let sq = snap(l, v, p, want);
    if sq >= 0 && sq == waiting(b) {
        b.pressed = b.selected;
        b.press_at = p;
        b.dragging = false;
        return;
    }
    let before = b.steps.len;
    let i, on_way = follow(b, sq);
    if i >= 0 {
        b.dropped = false;
        play_chosen(b, i, now);
        return;
    }
    if on_way {
        kept(b, before, now);
        return;
    }
    if sq >= 0 && (b.pos.pieces[b.pos.side] >> sq) & 1 != 0 {
        if has_move_from(b, sq) {
            b.selected = sq;
            b.steps.clear();
            b.pressed = sq;
            b.press_at = p;
            b.dragging = false;
            return;
        }
        if must_capture(b) {
            if rules::can_take_from(b.pos, sq) { outnumbered(b, sq, now); } else { mistake(b, sq, now); }
        }
    }
    if b.selected >= 0 && empty(b, sq) {
        missed(b, sq, now);
        return;
    }
    b.selected = -1;
    b.steps.clear();
}

// The pointer moves to p while down. Returns whether anything on screen changed.
fn drag(b: Board&, l: Layout, p: float2) -> bool {
    guard b.pressed >= 0 else { return false; }
    let d = p - b.press_at;
    if !b.dragging && length(d) < DRAG_START * l.scale { return false; }
    b.dragging = true;
    b.drag_at = p;
    return true;
}

// The pointer goes up at p. A drag dropped on a target plays the move from there, on a
// capture's next stop keeps it, and on another empty square is a mistake. Either way but
// a move, the piece goes back, still selected: to its square, or to the stop it waits on.
// A drop off the dark squares goes to the nearest target or stop within SNAP (`snap`).
fn release(b: Board&, l: Layout, p: float2, now: f64) {
    let was = b.dragging;
    b.pressed = -1;
    b.dragging = false;
    guard was else { return; }
    let sq = snap(l, rules::VARIANTS[b.variant], p, reachable(b));
    guard sq < 0 || sq != waiting(b) else { return; }
    let before = b.steps.len;
    let i, on_way = follow(b, sq);
    if i >= 0 {
        play_chosen(b, i, now);
        b.drop = p;
        b.dropped = true;
    } else if on_way {
        kept(b, before, now);
    } else if empty(b, sq) {
        missed(b, sq, now);
    }
}

fn hops(m: rules::Move&) -> i64 { max(m.path.len - 1, 1) }

// How long the move takes: a quiet move one hop, a capture one per stop, then the fade.
fn duration(m: rules::Move&) -> f64 {
    let fade = if m.captured != 0 { FADE } else { 0.0 };
    return hops(m) * HOP + fade;
}

// Whether anything is still changing at `now`; the app draws while it is.
fn animating(b: Board&, now: f64) -> bool {
    b.moving || now < b.pulse_end || (b.wrong >= 0 && now < b.wrong_at + FLASH)
    || (b.glow >= 0 && b.glow_at >= 0.0 && now < b.glow_at + PULSE)
    || (b.kept_at >= 0.0 && now < b.kept_at + PULSE && next_shown(b))
}

// Whether the squares the selected piece's capture goes on to are shown: in a game, not
// a puzzle, which leaves the way to the child; with move hints, once it waits on a
// stop, and on mistakes only after a second wrong square in the capture (`missed`).
fn next_shown(b: Board&) -> bool {
    guard !b.by_hand && !b.moving && b.selected >= 0 && must_capture(b) else { return false; }
    return (b.hints == MOVES && waiting(b) >= 0) || b.misses >= 2;
}

// Ends the move, or the pulse, once its time is up. Call before input each frame; true
// when something ended, so the frame after an animation is drawn too.
fn update(b: Board&, now: f64) -> bool {
    var ended = false;
    if b.moving && now - b.since >= duration(b.move) {
        b.moving = false;
        b.back = false;
        ended = true;
    }
    if b.glow >= 0 && b.glow_at >= 0.0 && now >= b.glow_at + PULSE {
        b.glow_at = -1.0;
        ended = true;
    }
    if b.kept_at >= 0.0 && now >= b.kept_at + PULSE {
        b.kept_at = -1.0;
        ended = true;
    }
    if b.pulse_end > 0.0 && now >= b.pulse_end {
        b.pulse_end = 0.0;
        ended = true;
    }
    if b.wrong >= 0 && !b.held && now >= b.wrong_at + FLASH {
        if b.still { b.held = true; } else {
            b.wrong = -1;
            b.ghost = false;
        }
        ended = true;
    }
    return ended;
}

fn ease(t: f64) -> f64 { t * t * (3.0 - 2.0 * t) }

fn set_bit(bits: u32[4]&, n: i64) { bits[n / 32] |= (1 as u32) << (n % 32); }

fn mark(b: Board&, bits: u32[4]&, sq: i64) {
    let v .= rules::VARIANTS[b.variant];
    set_bit(bits, v.y_of[sq] * v.size + v.x_of[sq]);
}

// A piece to draw; `ring` is its must-capture ring: 0 none, 1 pulsing, 2 still.
fn add(b: Board&, at: float2, r: f32, lift: f32, black: bool, king: bool, glow: f32,
       alpha: f32, ring: f32) {
    guard b.pieces.len < MAX_PIECES else { return; }
    let look = if king { b.king_look } else { 0 };
    b.pieces.push(Piece {
        at:   float4 { at.x, at.y, r, lift },
        look: float4 { if black { 1.0 } else { 0.0 }, look, glow, alpha },
        ring: float4 { ring, 0.0, 0.0, 0.0 } });
}

// The last piece added, the one on `sq`, shows how many it takes (ring.z).
fn show_takes(b: Board&, sq: i64) {
    guard b.pieces.len > 0 else { return; }
    b.pieces[b.pieces.len - 1].ring.z = takes(b, sq);
}

// Fills b.pieces and b.marks for the frame at `now`. Pieces go top row first, so a lower
// piece covers the shadow of the one above it; the moving or dragged piece goes last.
fn fill(b: Board&, l: Layout, now: f64) {
    b.pieces.clear();
    b.marks = Marks {};
    b.dim = 0.0;
    let v .= rules::VARIANTS[b.variant];
    let r = 0.39 * l.inner.w;           // a disc fills 78% of its square
    let unit = 0.01 * l.board.z;        // 1% of the board
    let shown = if b.moving { b.before } else { b.pos };
    // A move sliding back is the move played backward.
    let t = if b.back { max(duration(b.move) - (now - b.since), 0.0) } else { now - b.since };
    let pulsing = now < b.pulse_end;
    // The hint's ring: full, fading to a third and back every 1.4 s, then full and still.
    let glowing = if b.glow_at >= 0.0 && now < b.glow_at + PULSE {
        (0.65 + 0.35 * cos(2.0 * PI * (now - b.glow_at) / (0.5 * PULSE))) as f32
    } else { 1.0 };
    let ring: f32 = if pulsing { 1.0 } else { 2.0 };
    var must: u64 = 0;
    if (pulsing || b.held) && must_capture(b) {
        for i in b.moves.len { must |= rules::bit(b.moves[i].from); }
    }
    if pulsing { must |= b.outtaken; }
    // How many pieces each piece that must capture takes, at most, as pips round its
    // ring (`takes`), whatever the hints: a long capture's length shows before it is
    // found (2026-11-09). Partway through a capture, only on the piece making it.
    let counting = !b.by_hand && !b.quiet && !b.moving && must_capture(b);
    let fade_at = hops(b.move) as f64 * HOP;
    // A piece waiting partway through a capture made by hand is drawn on its stop; the
    // pieces it has jumped stay until the capture ends, as the rules take them.
    let waits = if b.moving || b.dragging { -1 } else { waiting(b) };
    for row in v.size {
        let y = if l.flip { row } else { v.size - 1 - row };
        for x in v.size {
            let sq = rules::bit_at(v, x, y);
            guard sq >= 0 else { continue; }
            let m = rules::bit(sq);
            let white = shown.pieces[rules::WHITE] & m != 0;
            let black = shown.pieces[rules::BLACK] & m != 0;
            guard white || black else { continue; }
            if b.moving && sq == b.move.from { continue; }
            if b.dragging && sq == b.selected { continue; }
            if waits >= 0 && sq == b.selected { continue; }
            var alpha: f32 = 1.0;
            if b.moving && b.move.captured & m != 0 && t > fade_at {
                alpha = (1.0 - clamp((t - fade_at) / FADE, 0.0, 1.0)) as f32;
            }
            let selected = sq == b.selected;
            add(b, center(l, v, sq), r, if selected { 1.1 * unit } else { 0.0 }, black,
                shown.kings & m != 0, if selected { 1.0 } else { 0.0 }, alpha, if must & m != 0 { ring } else { 0.0 });
            if sq == b.glow && !b.moving && b.pieces.len > 0 { b.pieces[b.pieces.len - 1].ring.y = glowing; }
            if counting && b.steps.len == 0 { show_takes(b, sq); }
        }
    }
    if b.ghost && b.wrong >= 0 {
        // The ghost fades from 0.8 out over the flash, slowly at first.
        let k = clamp((now - b.wrong_at) / FLASH, 0.0, 1.0);
        add(b, center(l, v, b.wrong), r, 0.0, b.ghost_of.x > 0.5, b.ghost_of.y > 0.5, 0.0,
            (0.8 * (1.0 - k * k)) as f32, 0.0);
    }
    if b.moving {
        // The mover along its stops, with a little hop over each capture.
        let mv .= b.move;
        let n = hops(mv);
        let k = min((t / HOP) as i64, n - 1);
        let u = ease(clamp(t / HOP - k, 0.0, 1.0));
        let from_i = min(k, mv.path.len - 1);
        let to_i = min(k + 1, mv.path.len - 1);
        var a = center(l, v, mv.path[from_i]);
        let c = center(l, v, mv.path[to_i]);
        if k == b.skip && b.dropped { a = b.drop; }
        let at = a + (c - a) * u as f32;
        let arc = if mv.captured != 0 { 4.0 * unit } else { 1.5 * unit };
        let lift = arc * sin(PI * u) as f32;
        // Crowned from the stop where it reaches the far row (Russian crowns mid-capture).
        var king = b.before.kings & rules::bit(mv.from) != 0;
        if mv.crowned {
            let far = v.promotion[b.before.side];
            for i in to_i + 1 {
                if i <= k && far & rules::bit(mv.path[i]) != 0 { king = true; }
            }
            if t >= n * HOP { king = true; }
        }
        add(b, at, r, lift, b.before.side == rules::BLACK, king, 0.0, 1.0, 0.0);
    } else if b.dragging && b.selected >= 0 {
        add(b, b.drag_at, r * 1.06, 1.6 * unit, b.pos.side == rules::BLACK,
            b.pos.kings & rules::bit(b.selected) != 0, 1.0, 1.0, 0.0);
        if counting { show_takes(b, b.selected); }
    } else if waits >= 0 {
        // A man that has passed the far row is crowned on it only where crowning goes on
        // mid-capture (Russian); in International it stays a man (rules.md).
        var king = b.pos.kings & rules::bit(b.selected) != 0;
        if v.crowning == rules::CROWN_CONTINUES {
            for st in b.steps { if v.promotion[b.pos.side] & rules::bit(st) != 0 { king = true; } }
        }
        add(b, center(l, v, waits), r, 1.1 * unit, b.pos.side == rules::BLACK, king, 1.0, 1.0, 0.0);
        if b.glow == b.selected && b.pieces.len > 0 { b.pieces[b.pieces.len - 1].ring.y = glowing; }
        if counting { show_takes(b, b.selected); }
    }
    if b.has_last && !b.moving {
        mark(b, b.marks.last, b.last.from);
        mark(b, b.marks.last, b.last.to);
    }
    b.flash = float4 { -1.0, 1.0, 0.0, 0.0 };
    if next_shown(b) {
        // Where the selected piece's capture goes on to: dots that pulse as the hint's
        // ring does, then stay lit.
        var r = reachable(b);
        while r != 0 {
            mark(b, b.marks.next, ctz(r));
            r &= r - 1;
        }
        b.flash.z = if b.kept_at >= 0.0 && now < b.kept_at + PULSE {
            (0.65 + 0.35 * cos(2.0 * PI * (now - b.kept_at) / (0.5 * PULSE))) as f32
        } else { 1.0 };
    }
    if b.wrong >= 0 {
        // Held, the ring stays as bright as its flash gets.
        let t = if b.held { 0.2 } else { clamp((now - b.wrong_at) / FLASH, 0.0, 1.0) };
        b.flash.x = v.y_of[b.wrong] * v.size + v.x_of[b.wrong];
        b.flash.y = t as f32;
    }
    if b.selected >= 0 && !b.moving {
        // The stops tapped so far are ringed whatever the hints: the child chose them.
        for s in b.steps { if s != waits { mark(b, b.marks.via, s); } }
        for i in b.moves.len {
            let m .= b.moves[i];
            guard b.hints == MOVES && on_steps(b, m) else { continue; }
            mark(b, b.marks.target, m.to);
            for j in b.steps.len + 1..m.path.len - 1 { mark(b, b.marks.via, m.path[j]); }
        }
    }
}
