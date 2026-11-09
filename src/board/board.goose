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

let MAX_PIECES = 48;        // 40 pieces on 10×10, the moving one, and margin
let HOP = 0.2;              // seconds per square of a quiet move, per stop of a capture
let FADE = 0.18;            // captured pieces fade out after the move
let PULSE = 2.8;            // must-capture rings pulse for two of their 1.4 s cycles
let DRAG_START = 10.0;      // dp a press moves before it becomes a drag
let SNAP = 0.9;             // squares from a square's center a press or drop off the dark squares still reaches
let FLASH = 1.2;            // a wrong move's red ring flashes twice, 0.6 s each
let MAX_HISTORY = 512;      // moves undo can take back; the oldest go first

// Move hints (docs/product.md): mistakes only, the default, marks a wrong move and pulses
// the pieces that must capture; moves also shows the selected piece's targets.
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
    ring: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x: must-capture ring, 1 pulsing, 2 still; y: a glow ring tight round it, 0 to 1
    win:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // a win (game::cheer): x dimmed by, 0..1; y its square lit, 0..1; z the square's half side in radii; w: over the UI, 1 on the board (a win's card's piece)
}

// What the board shader marks, one bit per square numbered y * size + x.
struct Marks {
    last:   u32[4] = [0; 4],
    target: u32[4] = [0; 4],
    via:    u32[4] = [0; 4],
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
    // A capture is made by hand, stop by stop (a puzzle's): a tap or a drop on a stop
    // leaves the piece waiting there, never playing the rest of the way by itself.
    by_hand: bool,
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
    flash:  float4,             // x: the wrong move's square (y * size + x) or -1; y: its flash, 0..1
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

// What a tap on `sq` does for the selected piece, among its moves that make the stops
// tapped so far: one ending on sq is played (one with exactly those stops before it
// first). Else, if sq is the next stop of several of them, it is kept as a stop, and if
// of only one, that one is played: a capture of many jumps can be tapped stop by stop
// or by its last square alone. By hand (`by_hand`), a next stop is always kept, the
// piece waiting there, and a last square is played only when it ends just after the
// stops or one capture alone goes there; one several reach waits for the stops. Returns
// the move to play or -1, and whether sq was taken as part of a way, so not a mistake.
fn follow(b: Board&, sq: i64) -> i64, bool {
    guard b.selected >= 0 && sq >= 0 else { return -1, false; }
    let k = b.steps.len + 1;    // where sq stands in a way
    var end = -1;
    var via = -1;
    var vias = 0;
    for m, i in b.moves {
        guard on_steps(b, m) else { continue; }
        if m.to == sq {
            if end < 0 || (m.path.len == k + 1 && b.moves[end].path.len != k + 1) { end = i; }
        } else if m.path[k] == sq {
            if via < 0 { via = i; }
            vias++;
        }
    }
    if end >= 0 && b.moves[end].path.len == k + 1 { return end, false; }
    if b.by_hand && vias > 0 {
        b.steps.push(sq as u8);
        return -1, true;
    }
    if end >= 0 {
        guard b.by_hand else { return end, false; }
        for m in b.moves {
            if on_steps(b, m) && m.to == sq && m.captured != b.moves[end].captured { return -1, true; }
        }
        return end, false;
    }
    if vias == 1 { return via, false; }
    if vias > 1 { b.steps.push(sq as u8); }
    return -1, vias > 1;
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

// The square the selected piece waits on, partway through a capture made by hand, or -1.
fn waiting(b: Board&) -> i64 {
    guard b.by_hand && b.selected >= 0 && b.steps.len > 0 else { return -1; }
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
    let i, kept = follow(b, sq);
    if i >= 0 {
        b.dropped = false;
        play_chosen(b, i, now);
        return;
    }
    if kept { return; }
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
        mistake(b, sq, now);
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
    let i, kept = follow(b, sq);
    if i >= 0 {
        play_chosen(b, i, now);
        b.drop = p;
        b.dropped = true;
    } else if !kept && empty(b, sq) {
        mistake(b, sq, now);
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
    } else if waits >= 0 {
        add(b, center(l, v, waits), r, 1.1 * unit, b.pos.side == rules::BLACK, b.pos.kings & rules::bit(b.selected) != 0,
            1.0, 1.0, 0.0);
        if b.glow == b.selected && b.pieces.len > 0 { b.pieces[b.pieces.len - 1].ring.y = glowing; }
    }
    if b.has_last && !b.moving {
        mark(b, b.marks.last, b.last.from);
        mark(b, b.marks.last, b.last.to);
    }
    b.flash = float4 { -1.0, 1.0, 0.0, 0.0 };
    if b.wrong >= 0 {
        // Held, the ring stays as bright as its flash gets.
        let t = if b.held { 0.2 } else { clamp((now - b.wrong_at) / FLASH, 0.0, 1.0) };
        b.flash = float4 { v.y_of[b.wrong] * v.size + v.x_of[b.wrong], t as f32, 0.0, 0.0 };
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
