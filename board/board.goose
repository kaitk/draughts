// The board on screen, with no graphics: where it goes, which square a point is on,
// what a tap or a drag does, how a move animates, and what to draw each frame. The app
// (app/kabe.goose) feeds it input and time and draws what it fills in; tests run it
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

// Where things go, in pixels. `scale` is pixels per dp: the prototypes' 800 px short side.
struct Layout {
    scale: f32,
    board: float4,      // x, y, size of the board with its frame; w: the corner radius
    inner: float4,      // x, y, size of the squares; w: one square
    panel: float4,      // x, y, width, height of the space for the side panel
    n:     i64,         // squares per side
}

// Landscape: the board fills the height less a 24 dp margin, with a 230 dp panel to its
// right. Portrait: the board fills the width, with a 220 dp panel below it.
fn layout(width: f32, height: f32, n: i64) -> Layout {
    let s = min(width, height) / 800.0;
    let gap = 24.0 * s;
    var l = Layout { scale: s, n: n, .. };
    if width >= height {
        let panel = 230.0 * s;
        let size = min(height - 2.0 * gap, width - panel - 3.0 * gap);
        let x = (width - (size + gap + panel)) / 2.0;
        let y = (height - size) / 2.0;
        l.board = float4 { x, y, size, 0.022 * size };
        l.panel = float4 { x + size + gap, y, panel, size };
    } else {
        let panel = 220.0 * s;
        let size = min(width - 2.0 * gap, height - panel - 3.0 * gap);
        let x = (width - size) / 2.0;
        let y = (height - (size + gap + panel)) / 2.0;
        l.board = float4 { x, y, size, 0.022 * size };
        l.panel = float4 { x, y + size + gap, size, panel };
    }
    let frame = 0.024 * l.board.z;
    let inner = l.board.z - 2.0 * frame;
    l.inner = float4 { l.board.x + frame, l.board.y + frame, inner, inner / n };
    return l;
}

// A square as its rules bit, from its column and row (a1 is 0, 0); -1 off the board or
// on a light square.
fn bit_at(v: rules::Variant&, x: i64, y: i64) -> i64 {
    guard x >= 0 && y >= 0 && x < v.size && y < v.size && (x + y) % 2 == 0 else { return -1; }
    return y * v.h + x / 2 + (y + 1) / 2;
}

// The square under a point, as a rules bit, or -1. White plays up the screen.
fn hit(l: Layout, v: rules::Variant&, p: float2) -> i64 {
    let fx = (p.x - l.inner.x) / l.inner.w;
    let fy = (p.y - l.inner.y) / l.inner.w;
    guard fx >= 0.0 && fy >= 0.0 else { return -1; }
    let x = floor(fx) as i64;
    let row = floor(fy) as i64;
    return bit_at(v, x, v.size - 1 - row);
}

// The center of a square, in pixels.
fn center(l: Layout, v: rules::Variant&, b: i64) -> float2 {
    let x = v.x_of[b] as f32;
    let row = (v.size - 1 - v.y_of[b]) as f32;
    return float2 { l.inner.x + (x + 0.5) * l.inner.w, l.inner.y + (row + 0.5) * l.inner.w };
}

// One piece to draw: where, how big, how high, and its state. The app copies these into
// the storage buffer the piece shader pulls from.
struct Piece {
    at:   float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x, y center in pixels, radius, lift in pixels
    look: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // black (0 or 1), king (0 or 1), selected glow 0..1, opacity
    ring: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x: must-capture ring (0 or 1)
}

// What the board shader marks, one bit per square numbered y * size + x.
struct Marks {
    last:   u32[4] = [0; 4],
    target: u32[4] = [0; 4],
    via:    u32[4] = [0; 4],
}

struct Board {
    variant:  u8,
    pos:      rules::Position,
    moves:    rules::Moves,     // the legal moves of pos
    selected: i64,              // a bit, or -1
    // The move being shown: the position before it, when it started, and where the
    // piece starts from if it was dropped there.
    moving:    bool,
    move:      rules::Move,
    before:    rules::Position,
    since:     f64,
    drop:      float2,
    dropped:   bool,
    last:      rules::Move,
    has_last:  bool,
    pulse_end: f64,
    // A press on a piece, and whether it became a drag.
    pressed:  i64,
    press_at: float2,
    dragging: bool,
    drag_at:  float2,
    // Filled by fill() for the app to draw.
    pieces: Piece[..MAX_PIECES],
    marks:  Marks,
}

fn new(variant: u8) -> Board {
    var b = Board { variant: variant, pos: rules::start(variant), selected: -1, pressed: -1, .. };
    rules::generate(b.pos, b.moves);
    return b;
}

// Starts over from position p.
fn set(b: Board&, p: rules::Position) {
    b.pos = p;
    rules::generate(b.pos, b.moves);
    b.selected = -1;
    b.moving = false;
    b.has_last = false;
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
    b.move = b.moves[i];
    b.before = b.pos;
    b.pos = rules::play(b.pos, b.move);
    rules::generate(b.pos, b.moves);
    b.moving = true;
    b.since = now;
    b.last = b.move;
    b.has_last = true;
    b.selected = -1;
}

// A finger or the mouse goes down at p. On a piece that can move: select it (and it may
// be dragged). On a target of the selected piece: play that move. On a piece that can't
// move because another must capture: pulse the pieces that must. Elsewhere: deselect.
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
        if b.moves.len > 0 && b.moves[0].captured != 0 { b.pulse_end = now + PULSE; }
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

// The pointer goes up at p. A drag dropped on a target plays the move from there;
// anywhere else the piece goes back, still selected.
fn release(b: Board&, l: Layout, p: float2, now: f64) {
    let was = b.dragging;
    b.pressed = -1;
    b.dragging = false;
    guard was else { return; }
    let i = move_to(b, hit(l, rules::VARIANTS[b.variant], p));
    if i >= 0 {
        b.drop = p;
        b.dropped = true;
        start_move(b, i, now);
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
    b.moving || now < b.pulse_end
}

// Ends the move, or the pulse, once its time is up. Call before input each frame; true
// when something ended, so the frame after an animation is drawn too.
fn update(b: Board&, now: f64) -> bool {
    var ended = false;
    if b.moving && now - b.since >= duration(b.move) {
        b.moving = false;
        ended = true;
    }
    if b.pulse_end > 0.0 && now >= b.pulse_end {
        b.pulse_end = 0.0;
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

fn add(b: Board&, at: float2, r: f32, lift: f32, black: bool, king: bool, glow: f32,
       alpha: f32, ring: bool) {
    guard b.pieces.len < MAX_PIECES else { return; }
    b.pieces.push(Piece {
        at:   float4 { at.x, at.y, r, lift },
        look: float4 { if black { 1.0 } else { 0.0 }, if king { 1.0 } else { 0.0 }, glow, alpha },
        ring: float4 { if ring { 1.0 } else { 0.0 }, 0.0, 0.0, 0.0 } });
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
    let t = now - b.since;
    let pulsing = now < b.pulse_end;
    var must: u64 = 0;
    if pulsing && b.moves.len > 0 && b.moves[0].captured != 0 {
        for i in b.moves.len { must |= rules::bit(b.moves[i].from); }
    }
    let fade_at = hops(b.move) as f64 * HOP;
    for row in v.size {
        let y = v.size - 1 - row;
        for x in v.size {
            let sq = bit_at(v, x, y);
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
                shown.kings & m != 0, if selected { 1.0 } else { 0.0 }, alpha, must & m != 0);
        }
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
        add(b, at, r, lift, b.before.side == rules::BLACK, king, 0.0, 1.0, false);
    } else if b.dragging && b.selected >= 0 {
        add(b, b.drag_at, r * 1.06, 1.6 * unit, b.pos.side == rules::BLACK,
            b.pos.kings & rules::bit(b.selected) != 0, 1.0, 1.0, false);
    }
    if b.has_last && !b.moving {
        mark(b, b.marks.last, b.last.from);
        mark(b, b.marks.last, b.last.to);
    }
    if b.selected >= 0 && !b.moving {
        for i in b.moves.len {
            let m .= b.moves[i];
            guard m.from == b.selected else { continue; }
            mark(b, b.marks.target, m.to);
            for j in 1..m.path.len - 1 { mark(b, b.marks.via, m.path[j]); }
        }
    }
}
