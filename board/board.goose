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
    // The move being shown: the position before it, when it started, and where the
    // piece starts from if it was dropped there; `back`, a move shown sliding back.
    moving:    bool,
    back:      bool,
    move:      rules::Move,
    before:    rules::Position,
    since:     f64,
    drop:      float2,
    dropped:   bool,
    last:      rules::Move,
    has_last:  bool,
    pulse_end: f64,
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
    b.moving = false;
    b.wrong = -1;
    b.held = false;
    b.pulse_end = 0.0;
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

// Takes back the last move as a mistake: the piece slides back along its way and the
// pieces it took fade back in, while its square flashes the red ring over a fading ghost
// of it. False when there is no move to take back.
fn slide_back(b: Board&, now: f64) -> bool {
    guard b.history.len > 0 else { return false; }
    let m = b.move;
    let side = 1 - b.pos.side;
    let king = b.pos.kings & rules::bit(m.to) != 0;
    undo(b);
    b.move = m;
    b.before = b.pos;
    b.moving = true;
    b.back = true;
    b.since = now;
    b.dropped = false;
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

// The selected piece's move ending on `to`, or -1.
fn move_to(b: Board&, to: i64) -> i64 {
    guard b.selected >= 0 && to >= 0 else { return -1; }
    for i in b.moves.len {
        let m .= b.moves[i];
        if m.from == b.selected && m.to == to { return i; }
    }
    return -1;
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
    b.glow = -1;
    // A move starts from its square unless release says it was dropped elsewhere; a
    // move played by code (the computer's) must not start from the last drop.
    b.dropped = false;
}

fn must_capture(b: Board&) -> bool { b.moves.len > 0 && b.moves[0].captured != 0 }

// A wrong move ending on square `sq`: its ring flashes, and if a capture was due, the
// pieces that must capture pulse.
fn mistake(b: Board&, sq: i64, now: f64) {
    b.wrong = sq;
    b.wrong_at = now;
    b.held = false;
    if must_capture(b) { b.pulse_end = now + PULSE; }
}

fn empty(b: Board&, sq: i64) -> bool {
    sq >= 0 && ((b.pos.pieces[rules::WHITE] | b.pos.pieces[rules::BLACK]) >> sq) & 1 == 0
}

// A finger or the mouse goes down at p. On a piece that can move: select it (and it may
// be dragged). On a target of the selected piece: play that move. On another empty
// square while a piece is selected, or on a piece that can't move because another must
// capture: a mistake. Elsewhere: deselect.
fn press(b: Board&, l: Layout, p: float2, now: f64) {
    guard !b.moving else { return; }
    let v .= rules::VARIANTS[b.variant];
    let sq = hit(l, v, p);
    let i = move_to(b, sq);
    if i >= 0 {
        b.dropped = false;
        start_move(b, i, now);
        return;
    }
    if sq >= 0 && (b.pos.pieces[b.pos.side] >> sq) & 1 != 0 {
        if has_move_from(b, sq) {
            b.selected = sq;
            b.pressed = sq;
            b.press_at = p;
            b.dragging = false;
            return;
        }
        if must_capture(b) { mistake(b, sq, now); }
    }
    if b.selected >= 0 && empty(b, sq) {
        mistake(b, sq, now);
        return;
    }
    b.selected = -1;
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

// The pointer goes up at p. A drag dropped on a target plays the move from there; on
// another empty square it is a mistake. Either way but a move, the piece goes back,
// still selected.
fn release(b: Board&, l: Layout, p: float2, now: f64) {
    let was = b.dragging;
    b.pressed = -1;
    b.dragging = false;
    guard was else { return; }
    let sq = hit(l, rules::VARIANTS[b.variant], p);
    let i = move_to(b, sq);
    if i >= 0 {
        start_move(b, i, now);
        b.drop = p;
        b.dropped = true;
    } else if empty(b, sq) {
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
    let fade_at = hops(b.move) as f64 * HOP;
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
        if k == 0 && b.dropped { a = b.drop; }
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
        for i in b.moves.len {
            let m .= b.moves[i];
            guard m.from == b.selected && b.hints == MOVES else { continue; }
            mark(b, b.marks.target, m.to);
            for j in 1..m.path.len - 1 { mark(b, b.marks.via, m.path[j]); }
        }
    }
}
