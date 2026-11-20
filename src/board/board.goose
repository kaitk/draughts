// The board on screen, with no graphics: where it goes, which square a point is on,
// what a tap or a drag does, how a move animates, and what to draw each frame. Nothing
// here allocates: the moves and draw lists are fixed buffers in the caller's `Board`.
namespace board;
import std;
import math;
import vec;
import rules from "../rules";
import gui from "../gui";
import model3d from "../model3d";
import .view3d;
import .taken3d;
import .rig;
import .panel;
import .sound_event;

let MAX_PIECES = 48;        // 40 pieces on 10×10, the moving one, and margin
let HOP = 0.2;              // seconds per square of a quiet move, per stop of a capture
let FADE = 0.18;            // captured pieces fade out after the move
let TAKEN = 0.35;           // a jumped piece's opacity until the capture ends, so a king's way back past it shows
let CARRY = 0.5;            // seconds captured pieces take to the table after the move, in place of FADE (on_table)
let PULSE = 2.8;            // must-capture rings pulse for two of their 1.4 s cycles
let DRAG_START = 10.0;      // dp a press moves before it becomes a drag
let SNAP = 0.9;             // squares from a square's center a press or drop off the dark squares still reaches
let FLASH = 1.2;            // a wrong move's red ring flashes twice, 0.6 s each

// Move hints: mistakes only marks a wrong move and pulses the pieces that must capture;
// moves also shows the selected piece's targets.
let MISTAKES = 0;
let MOVES = 1;

// How a king is drawn: a crown on its face, or a stack of two plain discs. A piece's
// look.y is 0 for a man or one of these.
let CROWN = 1;
let STACK = 2;

// Where the board goes, in pixels. `scale` is pixels per dp.
struct Layout {
    scale: f32,
    board: float4,      // x, y, size of the board; w: the corner radius
    inner: float4,      // x, y, size of the squares inside the board's thin lip; w: one square
    n:     i64,         // squares per side
    flip:  bool,        // turned, black playing up the screen
}

// dp: a board beside a screen's controls smaller than this isn't shown; its squares
// would be under 13 dp on 10 × 10, too small to read.
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

// One piece to draw, as the piece shader reads it.
struct Piece {
    at:   float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x, y center in pixels, radius, lift in pixels
    look: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // black (0 or 1), 0 or CROWN or STACK, selected glow 0..1, opacity
    ring: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x: must-capture ring, 1 pulsing, 2 still; y: a glow ring tight round it, 0 to 1; z: pieces it takes, as pips; w: DRAINED, or LIGHT a hint's ghost
    win:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // a win (game::cheer): x dimmed by, 0..1; y its square lit, 0..1; z the square's half side in radii; w: over the UI, 1 on the board (a win's card's piece)
}

// Pieces over the UI: clocks, the winner or a draw's pieces, and what each side has
// taken; a transition holds two screens' at once.
let OVER = 96;

type Overlay = Piece[..OVER];

// What the board shader marks, one bit per square numbered y * size + x.
struct Marks {
    last:   u32[4] = [0; 4],
    target: u32[4] = [0; 4],
    via:    u32[4] = [0; 4],
    next:   u32[4] = [0; 4],    // where a piece waiting on a stop goes on to, pulsing (flash.z)
    shade:  u32[4] = [0; 4],    // the lookout's crowning squares, shaded under a dark ghost king
}

// Piece.ring.w: drained of color (a piece in danger, a crowning ghost king), or light
// (the hint's ghost).
let DRAINED = 1.0;
let LIGHT = -1.0;
let GHOST_KING = 0.62;      // the crowning ghost king's opacity
let GHOST_HINT = 0.5;       // the hint's ghost's
let TRACE_GHOST = 0.3;      // a replay's last move: the piece where it started

struct Board {
    variant:  u8,
    rec:      rules::Record,    // the game as played: where it began, the positions before each move
    pos:      rules::Position,
    moves:    rules::Moves,     // the legal moves of pos
    selected: i64,              // a bit, or -1
    // The selected piece's captures, every way to each (rules::ways), or its quiet
    // moves. A capture made stop by stop follows any of them (`follow`).
    ways:  rules::Ways,
    steps: rules::Path,         // the stops of a capture tapped so far, after the selected piece's square
    // A tap that kept a stop: the piece hops there from `hop_from` (a bit) since `hop_at`.
    hop_at:            f64,
    hop_from:          i64,
    hop_to:            i64,
    release_deselects: bool,             // a press on the selected piece: let go without a drag, it is put down
    // A puzzle's board: nothing shows the way (no counts, no pieces to take, no next stop).
    by_hand:                    bool,
    next_stops_pulse_at:        f64,        // when the next stops started pulsing (next_shown)
    misses:                     i64, // wrong squares in this turn's capture (`missed`)
    hide_counts:                bool, // no counts: the computer is to move
    counts_shown_after_mistake: bool,              // on mistakes only, a mistake has shown the counts (`counting`)
    // The move being shown: the position before it, when it started, and where the
    // piece starts from if it was dropped there; `back`, a move shown sliding back.
    moving:    bool,
    back:      bool,
    move:      rules::Way,
    before:    rules::Position,
    since:     f64,
    drop:      float2,
    dropped:   bool,
    skip:      i64,             // the hops of the move already made by hand, not shown again
    last:      rules::Way,
    has_last:  bool,
    pulse_end: f64,
    outtaken:  u64,             // pieces pulsing beside the capturers: what they must take
    hints:     i64,             // MISTAKES or MOVES
    wrong:     i64,             // the square of the last wrong move, a bit, or -1
    wrong_at:  f64,
    ghost:     bool,            // a ghost of the piece that slid back fades on the wrong square
    ghost_of:  float2,          // its side (0 or 1) and whether it is a king
    glow:      i64,             // the piece a hint shows with a glow ring, a bit, or -1
    glow_at:   f64,
    // A hint's second step: a light ghost of the piece on the square it goes to (a bit,
    // or -1), its ring pulsing from `ghost_at`; `hint_via`, its capture's stops between.
    hint_to:  i64,
    ghost_at: f64,
    hint_via: u64,
    // A replay's move compared with the hint: a light ghost of the piece on `played_from`
    // where it went, `played_to` (a square, or -1), as the hint's but with no ring.
    played_from: i64,
    played_to:   i64,
    // A replay's last move: every square it stood on shaded, and a ghost where it started
    // at `trace_a` of TRACE_GHOST.
    trace:   bool,
    trace_a: f32 = 1.0,
    // The lookout: the side to move's pieces in danger, and the other side's crowning
    // squares. Cleared by a move.
    danger:          u64,
    crowns:          u64,
    positions_shown: i64,             // counts the positions shown: the lookout's marks were cleared
    pulsed:          i64,       // the piece whose glow ring pulses this frame, or -1
    king_look:       i64,       // CROWN or STACK
    // The 3D board on its table (shell::build_frame_pieces): a capture's pieces leave the
    // board after its last hop and are carried to the table (view3d::carried), not faded.
    on_table: bool,
    // A picture rather than a game: a flashed ring and pulsed capture rings stay lit and
    // still (`rings_frozen`), so it needs no frames after.
    static_picture:       bool,
    rings_frozen:         bool,
    target_under_pointer: i64,                 // the selected piece's target under the pointer, or -1 (`target_at`)
    // The keys' cursor, numbered y * size + x as Marks are (a light square too), or -1.
    cursor:      i64,
    cursor_flip: bool = false,  // whether `keys` last read the cells turned
    pressed:     i64,
    press_at:    float2,
    dragging:    bool,
    drag_at:     float2,
    // A press while a move still slides or its taken pieces fade (`touch`), kept to be
    // pressed once it has ended: where, and whether the pointer has gone up since.
    queued_press:    bool,
    queued_press_at: float2,
    queued_release:  bool,
    // Filled by fill().
    pieces: Piece[..MAX_PIECES],
    marks:  Marks,
    flash:  float4,             // x: the wrong move's square (y * size + x) or -1; y: its flash, 0..1; z: marks.next's dots, 0..1; w: the keys' cursor's square + 1, or 0
    dim:    f32,                // the board dimmed by, 0..1, under a win
    // What happened that is heard (sound_event.goose), said as the animation gets there, for the
    // shell to take each frame; the hops of the move shown already said; an event its last
    // landing says in its place (a puzzle's solve), or sound_event::NONE; and the stop a hand's
    // hop lands on, as the stops before it.
    sound_events:  sound_event::Events = [],
    stops_sounded: i64                 = 0,
    finale:        i64                 = sound_event::NONE,
    hop_step:      i64                 = 0,
}

fn new(variant: u8) -> Board {
    var b = Board { variant: variant, selected: -1, hop_at: -1.0, hop_from: -1, hop_to: -1, wrong: -1, glow: -1, hint_to: -1,
                    played_to: -1, pulsed: -1, king_look: CROWN, target_under_pointer: -1, cursor: -1, pressed: -1, .. };
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
    b.rings_frozen = false;
    b.pulse_end = 0.0;
    b.outtaken = 0;
    b.pressed = -1;
    b.dragging = false;
    b.queued_press = false;
    b.back = false;
    b.ghost = false;
    b.glow = -1;
    b.hint_to = -1;
    b.hint_via = 0;
    b.played_to = -1;
    b.danger = 0;
    b.crowns = 0;
    b.target_under_pointer = -1;
    b.positions_shown++;
    b.next_stops_pulse_at = -1.0;
    b.misses = 0;
    b.counts_shown_after_mistake = false;
}

// Starts a new game from position p.
fn set(b: Board&, p: rules::Position) {
    rules::record_begin(b.rec, p);
    b.has_last = false;
    show(b, p);
}

// Starts the game over from where it began.
fn restart(b: Board&) { set(b, b.rec.start); }

// Starts a new game of another variant, from its start.
fn reset(b: Board&, variant: u8) {
    b.variant = variant;
    set(b, rules::start(variant));
}

// Takes back the last move, even one still animating; false when there is none.
fn undo(b: Board&) -> bool {
    let s, ok = rules::record_pop(b.rec);
    guard ok else { return false; }
    b.has_last = s.has_last;
    b.last = rules::Way { from: s.last_from, to: s.last_to, .. };
    show(b, s.pos);
    return true;
}

// The game's past for draws at its position, from its record.
fn past(b: Board&) -> rules::Past& { rules::record_past(b.rec, b.pos) }

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

// A game's hint, its second step: a light ghost of the glowing piece on square `to`, its
// ring pulsing for two cycles as the glow's does, then lit and still; the piece's own ring
// stops pulsing, so one ring pulses at a time.
fn ghost_on(b: Board&, to: i64, now: f64) {
    b.hint_to = to;
    b.ghost_at = now;
    b.glow_at = -1.0;
}

// Takes back the last move, m, sliding the piece back along its way while the pieces it
// took fade back in; as a `mistake`, its square flashes the red ring over a fading ghost
// of it. The caller passes m: the board keeps only the last move it played. False when
// there is no move to take back.
fn slide_back(b: Board&, m: rules::Move, now: f64, mistake: bool = true) -> bool {
    guard b.rec.history.len > 0 else { return false; }
    let side = 1 - b.pos.side;
    let king = b.pos.kings & rules::bit(m.to) != 0;
    undo(b);
    b.move = rules::way_of(b.pos, m);
    b.before = b.pos;
    b.moving = true;
    b.back = true;
    b.since = now;
    b.dropped = false;
    b.skip = 0;
    guard mistake else { return true; }
    sound_event::add(b.sound_events, sound_event::WRONG);
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

// Selects the piece on sq, a piece of the side to move with a move, its stops forgotten:
// its ways, every way of its captures or its quiet moves, go into `ways`.
fn select(b: Board&, sq: i64) {
    b.selected = sq;
    b.steps.clear();
    b.hop_at = -1.0;
    if must_capture(b) {
        rules::ways(b.pos, sq, b.ways);
    } else {
        b.ways.clear();
        for m in b.moves { if m.from == sq { b.ways.push(rules::way_of(b.pos, m)); } }
    }
}

// Whether move m is the selected piece's and makes the stops tapped so far, with more of
// its way still to come.
fn on_steps(b: Board&, m: rules::Way&) -> bool {
    guard m.from == b.selected && m.path.len > b.steps.len + 1 else { return false; }
    for s, k in b.steps { if m.path[k + 1] != s { return false; } }
    return true;
}

// What a tap or a drop on `sq` does for the selected piece, among its ways that make the
// stops tapped so far (every way, so a king may land on any square the rules allow
// between jumps). A way ending just after them on sq is played. Else, if sq is the next
// stop of any, it is kept and the piece waits there: the rest of a capture is never
// played by itself. A last square further on is played when every way there takes the
// same pieces. Returns the way to play (in `ways`) or -1, and whether sq was taken as
// part of a way, so not a mistake.
fn follow(b: Board&, sq: i64) -> i64, bool {
    guard b.selected >= 0 && sq >= 0 else { return -1, false; }
    let k = b.steps.len + 1;    // where sq stands in a way
    var end = -1;
    var other = false;          // ways ending on sq take different pieces
    var vias = 0;
    for m, i in b.ways {
        guard on_steps(b, m) else { continue; }
        if m.to == sq {
            if end >= 0 && b.ways[end].captured != m.captured { other = true; }
            if end < 0 || (m.path.len == k + 1 && b.ways[end].path.len != k + 1) { end = i; }
        } else if m.path[k] == sq {
            vias++;
        }
    }
    if end >= 0 && b.ways[end].path.len == k + 1 { return end, false; }
    if vias > 0 {
        b.steps.push(sq as u8);
        return -1, true;
    }
    guard end >= 0 else { return -1, false; }
    if other { return -1, true; }
    return end, false;
}

// Whether sq is an empty square the selected piece passes on its way to a next stop,
// strictly between where it stands and the stop on their diagonal: a king's flight, or
// the squares beyond a piece it jumps before the one it must land on. A tap there is no
// stop and no mistake, nothing at all.
fn passes(b: Board&, sq: i64) -> bool {
    guard b.selected >= 0 && empty(b, sq) else { return false; }
    let v .= rules::VARIANTS[b.variant];
    let at = if capture_stop_square(b) >= 0 { capture_stop_square(b) } else { b.selected };
    let k = b.steps.len + 1;
    let dx = v.x_of[sq] as i64 - v.x_of[at];
    let dy = v.y_of[sq] as i64 - v.y_of[at];
    guard dx != 0 && (dx == dy || dx == -dy) else { return false; }
    for m in b.ways {
        guard on_steps(b, m) else { continue; }
        let nx = v.x_of[m.path[k]] as i64 - v.x_of[at];
        let ny = v.y_of[m.path[k]] as i64 - v.y_of[at];
        if nx * dx > 0 && ny * dy > 0 && nx * dy == ny * dx && abs(dx) < abs(nx) { return true; }
    }
    return false;
}

// How many pieces the piece on `sq` takes from here, at most: the most its captures
// take, less the stops already made when it waits on one. Each stop takes one piece,
// whatever squares a flying king could land on after it. 0 when it can't take.
fn takes(b: Board&, sq: i64) -> i64 {
    var most = 0;
    let made = if sq == b.selected { b.steps.len } else { 0 };
    if made == 0 {
        for m in b.moves { if m.from == sq && m.captured != 0 { most = max(most, popcount(m.captured)); } }
    } else {
        for m in b.ways { if m.captured != 0 && on_steps(b, m) { most = max(most, popcount(m.captured) - made); } }
    }
    return most;
}

// The squares the selected piece can go to next: a move's target or a capture's next stop.
fn reachable(b: Board&) -> u64 {
    var r: u64 = 0;
    for m in b.ways { if on_steps(b, m) { r |= rules::bit(m.path[b.steps.len + 1]); } }
    return r;
}

// The square p is on or, on a light square or just off the board, the nearest of `want`
// within SNAP squares: a finger on a small board often lands a little off.
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

// The square of a move of the selected piece under point p, a quiet move's target (snap
// leaves a point just off it there), or -1: where a held piece would go.
fn target_at(b: Board&, l: Layout, p: float2) -> i64 {
    guard b.selected >= 0 && !b.moving && b.steps.len == 0 else { return -1; }
    let sq = snap(l, rules::VARIANTS[b.variant], p, reachable(b));
    guard sq >= 0 else { return -1; }
    for m in b.moves { if m.from == b.selected && m.to == sq && m.captured == 0 { return sq; } }
    return -1;
}

// The square the selected piece waits on, partway through a capture, or -1.
fn capture_stop_square(b: Board&) -> i64 {
    guard b.selected >= 0 && b.steps.len > 0 else { return -1; }
    return b.steps[b.steps.len - 1];
}

fn start_move(b: Board&, i: i64, now: f64) {
    rules::record_push(b.rec, rules::Step { pos: b.pos, last_from: b.last.from, last_to: b.last.to, has_last: b.has_last });
    b.move = rules::way_of(b.pos, b.moves[i]);
    b.before = b.pos;
    b.pos = rules::play(b.pos, b.moves[i]);
    rules::generate(b.pos, b.moves);
    b.moving = true;
    b.since = now;
    b.last = b.move;
    b.has_last = true;
    b.selected = -1;
    b.steps.clear();
    b.glow = -1;
    b.hint_to = -1;
    b.hint_via = 0;
    b.played_to = -1;
    b.danger = 0;
    b.crowns = 0;
    b.target_under_pointer = -1;
    b.positions_shown++;
    b.next_stops_pulse_at = -1.0;
    b.misses = 0;
    b.counts_shown_after_mistake = false;
    // The must-capture pulse belongs to the position before: left on, it would ring the
    // next side's capturers.
    b.pulse_end = 0.0;
    b.outtaken = 0;
    // Only release sets it: a move played by code must not start from the last drop.
    b.dropped = false;
    b.skip = 0;
    b.stops_sounded = 0;
    b.finale = sound_event::NONE;
}

// Plays move i, the selected piece's, chosen by a tap or a drop. Made by hand, it is
// shown from the stop the piece waits on: the hops before it are already behind it.
fn play_chosen(b: Board&, i: i64, now: f64) {
    let skip = if capture_stop_square(b) >= 0 { b.steps.len } else { 0 };
    // The last stop tapped before the hop to the one before it landed: that stop lands now.
    if b.hop_at >= 0.0 && capture_stop_square(b) == b.hop_to { sound_event::add(b.sound_events, sound_event::STOP, b.hop_step); }
    start_move(b, i, now);
    b.skip = skip;
    b.stops_sounded = skip;
    b.since = now - skip * HOP;
}

// Plays way i of the selected piece (`ways`): its move, shown along the way the child
// took, which may be another of the move's ways than the one the move list keeps.
fn play_way(b: Board&, i: i64, now: f64) {
    let w = b.ways[i];
    var k = -1;
    for m, j in b.moves { if k < 0 && m.from == w.from && m.to == w.to && m.captured == w.captured { k = j; } }
    guard k >= 0 else { return; }
    play_chosen(b, k, now);
    b.move.path = w.path;
    b.last = b.move;
}

// Leaves a capture made by hand unfinished, which is no move: the piece slides back from
// the stop it waits on, as slide_back's mistake. False when no piece waits.
fn abandon(b: Board&, now: f64) -> bool {
    let at = capture_stop_square(b);
    guard at >= 0 && !b.moving else { return false; }
    var m = rules::Way { from: b.selected as u8, to: at as u8, crowned: false, captured: 0, path: [] };
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
    sound_event::add(b.sound_events, sound_event::WRONG);
    b.ghost = true;
    b.ghost_of = float2 { b.pos.side, if king { 1.0 } else { 0.0 } };
    b.selected = -1;
    b.steps.clear();
    b.pressed = -1;
    b.dragging = false;
    return true;
}

fn must_capture(b: Board&) -> bool { b.moves.len > 0 && b.moves[0].captured != 0 }

// A wrong move ending on square `sq`: its ring flashes, and if a capture was due, the
// pieces that must capture pulse and, on mistakes only, show their count until the
// capture ends (`counting`).
fn mistake(b: Board&, sq: i64, now: f64) {
    b.steps.clear();
    b.wrong = sq;
    b.wrong_at = now;
    b.rings_frozen = false;
    b.outtaken = 0;
    if must_capture(b) {
        b.pulse_end = now + PULSE;
        b.counts_shown_after_mistake = true;
    }
}

// The pieces the selected piece has jumped on its way to the stop it waits on: the one
// on each diagonal between two stops.
fn jumped(b: Board&) -> u64 {
    let v .= rules::VARIANTS[b.variant];
    let them = b.pos.pieces[1 - b.pos.side];
    var out: u64 = 0;
    var a = b.selected;
    for s in b.steps {
        out |= between(v, a, s) & them;
        a = s;
    }
    return out;
}

// The squares strictly between squares a and c on their diagonal.
fn between(v: rules::Variant&, a: i64, c: i64) -> u64 {
    let to_x = v.x_of[c] as i64;
    let dx: i64 = if to_x > v.x_of[a] { 1 } else { -1 };
    let dy: i64 = if v.y_of[c] > v.y_of[a] { 1 } else { -1 };
    var out: u64 = 0;
    var x:   i64 = v.x_of[a] + dx;
    var y:   i64 = v.y_of[a] + dy;
    while x != to_x {
        out |= rules::bit(rules::bit_at(v, x, y));
        x += dx;
        y += dy;
    }
    return out;
}

// How opaque a captured piece on `m` is `t` into the move: it goes see-through (TAKEN) as
// the mover hops over it, so a king's way back past it stays in view, and fades out
// after the last hop.
fn taken_alpha(v: rules::Variant&, mv: rules::Way&, m: u64, t: f64) -> f32 {
    let fade_at = hops(mv) as f64 * HOP;
    guard t <= fade_at else {
        return (TAKEN * (1.0 - clamp((t - fade_at) / FADE, 0.0, 1.0))) as f32;
    }
    for i in mv.path.len - 1 {
        guard between(v, mv.path[i], mv.path[i + 1]) & m != 0 else { continue; }
        let u = ease(clamp(t / HOP - i, 0.0, 1.0));
        return (1.0 - (1.0 - TAKEN) * u) as f32;
    }
    return 1.0;
}

// A tap or a drop on `sq`, an empty square that is no move for the selected piece: a
// mistake. If the piece must capture, in a game the first such square in a turn also
// pulses the pieces its captures have still to take, and the second lights the next
// stops (next_shown). A piece waiting on a stop stays there: the jumps it made were
// right. A puzzle shows neither and forgets the stops.
fn missed(b: Board&, sq: i64, now: f64) {
    let made = b.steps;
    // Before the first stop, a square no capture goes to says another piece must capture
    // (MUST); partway through one, it is a wrong stop.
    sound_event::add(b.sound_events, if must_capture(b) && made.len == 0 { sound_event::MUST } else { sound_event::WRONG });
    mistake(b, sq, now);
    guard !b.by_hand && must_capture(b) else { return; }
    b.steps = made;
    b.misses++;
    if b.misses == 1 {
        for m in b.moves {
            let w = rules::way_of(b.pos, m);
            if on_steps(b, w) { b.outtaken |= m.captured; }
        }
        b.outtaken &= ~jumped(b);
    }
    if b.misses == 2 { b.next_stops_pulse_at = now; }
}

// A piece came to wait on a stop (`follow`): what it goes on to pulses from now.
fn kept(b: Board&, before: i64, now: f64) {
    if b.steps.len > before { b.next_stops_pulse_at = now; }
}

// A tap kept a stop (`kept`): the piece hops there from the square before it.
fn hop(b: Board&, before: i64, now: f64) {
    guard b.steps.len > before else { return; }
    // A hop still on its way when the next is tapped lands now, heard.
    if b.hop_at >= 0.0 { sound_event::add(b.sound_events, sound_event::STOP, b.hop_step); }
    b.hop_step = b.steps.len - 1;
    b.hop_from = if b.steps.len > 1 { b.steps[b.steps.len - 2] } else { b.selected };
    b.hop_to = b.steps[b.steps.len - 1];
    b.hop_at = now;
}

// Whether the piece waiting on a stop is still hopping there at `now`.
fn hopping(b: Board&, now: f64) -> bool {
    b.hop_at >= 0.0 && now < b.hop_at + HOP && capture_stop_square(b) == b.hop_to && !b.dragging
}

// Whether the pieces that must capture show how many pieces they take: with move hints
// always; on mistakes only from a mistake until the capture ends, as a count up front
// gives the capture away. Never in a puzzle, on the computer's turn, or mid-move.
fn counting(b: Board&) -> bool {
    guard !b.by_hand && !b.hide_counts && !b.moving && must_capture(b) else { return false; }
    return b.hints == MOVES || b.counts_shown_after_mistake;
}

// Take back while a piece waits partway through a capture: the capture goes back to its
// start, the piece on its square and nothing selected; no move is taken back. False when
// no piece waits.
fn unwind(b: Board&) -> bool {
    guard capture_stop_square(b) >= 0 && !b.moving else { return false; }
    b.selected = -1;
    b.steps.clear();
    b.pressed = -1;
    b.dragging = false;
    b.next_stops_pulse_at = -1.0;
    return true;
}

// A tap on the piece on `sq`, which could take but fewer than the pieces that must
// capture (the majority rule): a mistake, and what their captures take pulses too.
fn outnumbered(b: Board&, sq: i64, now: f64) {
    mistake(b, sq, now);
    for m in b.moves { b.outtaken |= m.captured; }
}

fn empty(b: Board&, sq: i64) -> bool {
    sq >= 0 && ((b.pos.pieces[rules::WHITE] | b.pos.pieces[rules::BLACK]) >> sq) & 1 == 0
}

// A finger or the mouse goes down at p. On a piece that can move: select it (and it may
// be dragged). On a target of the selected piece: play that move; on the next stop of
// its captures, keep it (`follow`). On the stop a piece waits on: that piece, which may
// be dragged on. On another empty square while a piece is selected, or on a piece that
// can't move because another must capture: a mistake. Elsewhere: deselect.
fn press(b: Board&, l: Layout, p: float2, now: f64) {
    guard !b.moving else { return; }
    let v .= rules::VARIANTS[b.variant];
    var want = reachable(b);
    for m in b.moves { want |= rules::bit(m.from); }
    if capture_stop_square(b) >= 0 { want |= rules::bit(capture_stop_square(b)); }
    let sq = snap(l, v, p, want);
    if sq >= 0 && sq == capture_stop_square(b) {
        b.pressed = b.selected;
        b.press_at = p;
        b.dragging = false;
        return;
    }
    b.release_deselects = false;
    let before = b.steps.len;
    let i, on_way = follow(b, sq);
    if i >= 0 {
        b.dropped = false;
        play_way(b, i, now);
        return;
    }
    if on_way {
        kept(b, before, now);
        hop(b, before, now);
        return;
    }
    if passes(b, sq) { return; }
    if sq >= 0 && (b.pos.pieces[b.pos.side] >> sq) & 1 != 0 {
        if has_move_from(b, sq) {
            b.release_deselects = sq == b.selected && b.steps.len == 0;
            if !b.release_deselects { select(b, sq); }
            b.pressed = sq;
            b.press_at = p;
            b.dragging = false;
            return;
        }
        if must_capture(b) {
            sound_event::add(b.sound_events, sound_event::MUST);
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
fn release(b: Board&, l: Layout, p: float2, now: f64) {
    let was = b.dragging;
    let again = b.release_deselects;
    b.pressed = -1;
    b.dragging = false;
    b.release_deselects = false;
    if again && !was {
        // A tap on the selected piece puts it down.
        b.selected = -1;
        b.steps.clear();
        return;
    }
    guard was else { return; }
    let sq = snap(l, rules::VARIANTS[b.variant], p, reachable(b));
    guard sq < 0 || sq != capture_stop_square(b) else { return; }
    let before = b.steps.len;
    let i, on_way = follow(b, sq);
    if i >= 0 {
        play_way(b, i, now);
        b.drop = p;
        b.dropped = true;
    } else if on_way {
        // Dropped on a stop, the piece is there at once: its stop is heard now.
        if b.steps.len > before { sound_event::add(b.sound_events, sound_event::STOP, b.steps.len - 1); }
        kept(b, before, now);
    } else if empty(b, sq) && !passes(b, sq) {
        missed(b, sq, now);
    }
}

// The pointer on the board this frame, on the board laid out `flat`. On the 3D board
// (`three`) a point reaches the flat layout through view3d::pick; a held piece keeps the
// offset where the finger took it (`grab`, the caller's), so a press doesn't move it.
// Returns whether a drag moved a piece.
// A press while a move still shows (the computer's reply sliding, or its taken pieces
// fading after it has landed) is kept and pressed once the move has ended, with its
// release if the pointer went up meanwhile, so a tap there isn't lost.
fn touch(b: Board&, flat: Layout, three: bool, view: view3d::View, input: gui::Input, grab: float2&, now: f64) -> bool {
    let at = if three { view3d::pick(view, b, flat, input.at) } else { input.at };
    if input.pressed && b.moving {
        b.queued_press = true;
        b.queued_press_at = at;
        b.queued_release = false;
    } else if input.pressed {
        b.queued_press = false;
        press(b, flat, at, now);
        if three && b.pressed >= 0 { grab = b.press_at - view3d::pick(view, b, flat, input.at); }
    }
    if input.released && b.queued_press { b.queued_release = true; }
    if b.queued_press && !b.moving {
        b.queued_press = false;
        press(b, flat, b.queued_press_at, now);
        if b.queued_release {
            release(b, flat, b.queued_press_at, now);
            b.target_under_pointer = -1;
            return false;
        }
        if three && b.pressed >= 0 { grab = b.press_at - view3d::pick(view, b, flat, input.at); }
    }
    let held = if three && b.pressed >= 0 { view3d::pick(view, b, flat, input.at) + grab } else { at };
    var moved = false;
    if input.down && drag(b, flat, held) { moved = true; }
    if input.released { release(b, flat, held, now); }
    // A finger lifted from a tap was resting on the piece: only the mouse hovers.
    b.target_under_pointer = if b.dragging { target_at(b, flat, held) }
             else if !input.down && b.pressed < 0 { target_at(b, flat, at) } else { -1 };
    return moved;
}

// The keys on the board: a grid of its squares over `r` in gui's focus. The arrows move
// the cursor, and Enter on a dark square is a tap there (`press`) when `mine`, the
// player's turn. Returns whether anything changed.
fn keys(b: Board&, flat: Layout, g: gui::Gui&, id: i64, r: float4, mine: bool, now: f64) -> bool {
    let v .= rules::VARIANTS[b.variant];
    let n = v.size;
    // The board turned: the cursor keeps its square, now across the screen.
    if flat.flip != b.cursor_flip && g.cell_of == id { g.cell = n * n - 1 - g.cell; }
    b.cursor_flip = flat.flip;
    let cell, enter = gui::grid(g, id, r, n, home_cell(b, flat));
    gui::mark_primary(g, id);
    let was = b.cursor;
    let shows = b.positions_shown;
    b.cursor = -1;
    guard cell >= 0 else { return was >= 0; }
    let cx = cell % n;
    let cr = cell / n;
    b.cursor = if flat.flip { cr * n + (n - 1 - cx) } else { (n - 1 - cr) * n + cx };
    let p = float2 { flat.inner.x + (cx + 0.5) * flat.inner.w, flat.inner.y + (cr + 0.5) * flat.inner.w };
    let dark = hit(flat, v, p) >= 0;
    var acted = false;
    if enter && mine && dark && !b.moving {
        let selected = b.selected;
        let steps = b.steps.len;
        let wrong_at = b.wrong_at;
        press(b, flat, p, now);
        // A key's press has no release: nothing is held, and Enter on the chosen piece
        // puts it down as a tap does.
        b.pressed = -1;
        b.dragging = false;
        if b.release_deselects { put_down(b); }
        acted = b.selected != selected || b.steps.len != steps || b.wrong_at != wrong_at || b.positions_shown != shows;
    }
    if mine && b.pressed < 0 { b.target_under_pointer = target_at(b, flat, p); }
    return b.cursor != was || acted;
}

// Puts the chosen piece down, unless it is partway through a capture (that is `unwind`).
// False with none chosen.
fn put_down(b: Board&) -> bool {
    guard b.selected >= 0 && b.steps.len == 0 && !b.moving else { return false; }
    b.selected = -1;
    b.pressed = -1;
    b.dragging = false;
    b.target_under_pointer = -1;
    return true;
}

// The cell the board's focus takes first, y * size + x from the top left on screen: the
// piece chosen, else the movable piece nearest the bottom middle, else the bottom middle.
fn home_cell(b: Board&, l: Layout) -> i64 {
    let v .= rules::VARIANTS[b.variant];
    let n = v.size;
    var sq = if capture_stop_square(b) >= 0 { capture_stop_square(b) } else { b.selected };
    if sq < 0 {
        let aim = float2 { l.inner.x + 0.5 * l.inner.z, l.inner.y + l.inner.z };
        var near: f32 = 1.0e30;
        for m in b.moves {
            let d = length(center(l, v, m.from) - aim);
            if d < near {
                near = d;
                sq = m.from;
            }
        }
    }
    guard sq >= 0 && l.inner.w > 0.0 else { return (n - 1) * n + n / 2; }
    let c = center(l, v, sq);
    let cx = clamp(floor((c.x - l.inner.x) / l.inner.w) as i64, 0, n - 1);
    let cr = clamp(floor((c.y - l.inner.y) / l.inner.w) as i64, 0, n - 1);
    return cr * n + cx;
}

// The showcase mode: a drag on the 3D board off the UI turns and tips the board, not a
// piece. Call before `touch`. Returns whether it had the pointer, and whether the board
// moved.
fn showcase(cam: rig::Rig&, g: gui::Gui&, input: gui::Input, three: bool, pitch: f32, now: f64) -> bool, bool {
    guard !g.press_on_ui && three && cam.showcase else { return false, false; }
    return true, rig::drive(cam, input.at, input.down, input.pressed, input.released, g.scale, pitch, now);
}

fn hops(m: rules::Way&) -> i64 { max(m.path.len - 1, 1) }

// How long the move takes: a quiet move one hop, a capture one per stop, then the fade,
// or on the table the carry.
fn duration(m: rules::Way&, table: bool = false) -> f64 {
    let fade = if m.captured == 0 { 0.0 } else if table { CARRY } else { FADE };
    return hops(m) * HOP + fade;
}

// How far into the move its captured pieces are carried to the table, 0 to 1, at `now`:
// 0 until the last hop ends; an undone move's go back, 1 to 0. -1 when nothing is carried.
fn carried(b: Board&, now: f64) -> f32 {
    guard b.moving && b.on_table && b.move.captured != 0 else { return -1.0; }
    let t = move_time(b, now);
    return clamp((t - hops(b.move) * HOP) / CARRY, 0.0, 1.0) as f32;
}

// How far into the move `now` is: a move sliding back is the move played backward.
fn move_time(b: Board&, now: f64) -> f64 {
    return if b.back { max(duration(b.move, b.on_table) - (now - b.since), 0.0) } else { now - b.since };
}

// The pieces of each color taken so far: the start's pieces less those on the board. A
// piece taken while a king counts as a king, found from the undo history, so kings taken
// more than rules::MAX_HISTORY moves back count as men.
fn taken(b: Board&) -> panel::Taken {
    var t = panel::Taken {};
    let v .= rules::VARIANTS[b.variant];
    for c in 2 {
        let lost = max(popcount(v.start[c]) - popcount(b.pos.pieces[c]), 0);
        var kings: i64 = 0;
        for st, i in b.rec.history {
            let a = st.pos;
            guard a.side != c else { continue; }
            let next = if i + 1 < b.rec.history.len { b.rec.history[i + 1].pos } else { b.pos };
            kings += popcount(a.pieces[c] & a.kings & ~next.pieces[c]);
        }
        t.kings[c] = min(kings, lost);
        t.men[c] = lost - t.kings[c];
    }
    return t;
}

// Whether anything is still changing at `now`; the app draws while it is.
fn animating(b: Board&, now: f64) -> bool {
    b.moving || now < b.pulse_end || (b.wrong >= 0 && now < b.wrong_at + FLASH)
    || (b.glow >= 0 && b.glow_at >= 0.0 && now < b.glow_at + PULSE)
    || (b.hint_to >= 0 && b.ghost_at >= 0.0 && now < b.ghost_at + PULSE)
    || (b.next_stops_pulse_at >= 0.0 && now < b.next_stops_pulse_at + PULSE && next_shown(b))
    || hopping(b, now)
}

// Whether the squares the selected piece's capture goes on to are shown: never in a
// puzzle; with move hints once it waits on a stop, on mistakes only after a second
// wrong square (`missed`).
fn next_shown(b: Board&) -> bool {
    guard !b.by_hand && !b.moving && b.selected >= 0 && must_capture(b) else { return false; }
    return (b.hints == MOVES && capture_stop_square(b) >= 0) || b.misses >= 2;
}

// Ends the move, or the pulse, once its time is up. Call before input each frame; true
// when something ended, so the frame after an animation is drawn too.
fn update(b: Board&, now: f64) -> bool {
    var ended = false;
    add_sound_events(b, now);
    if b.moving && now - b.since >= duration(b.move, b.on_table) {
        b.moving = false;
        b.back = false;
        ended = true;
    }
    if b.glow >= 0 && b.glow_at >= 0.0 && now >= b.glow_at + PULSE {
        b.glow_at = -1.0;
        ended = true;
    }
    if b.hint_to >= 0 && b.ghost_at >= 0.0 && now >= b.ghost_at + PULSE {
        b.ghost_at = -1.0;
        ended = true;
    }
    if b.next_stops_pulse_at >= 0.0 && now >= b.next_stops_pulse_at + PULSE {
        b.next_stops_pulse_at = -1.0;
        ended = true;
    }
    if b.hop_at >= 0.0 && now >= b.hop_at + HOP {
        if capture_stop_square(b) == b.hop_to { sound_event::add(b.sound_events, sound_event::STOP, b.hop_step); }
        b.hop_at = -1.0;
        ended = true;
    }
    if b.pulse_end > 0.0 && now >= b.pulse_end {
        b.pulse_end = 0.0;
        ended = true;
    }
    if b.wrong >= 0 && !b.rings_frozen && now >= b.wrong_at + FLASH {
        if b.static_picture { b.rings_frozen = true; } else {
            b.wrong = -1;
            b.ghost = false;
        }
        ended = true;
    }
    return ended;
}

// Says what the move shown has reached by `now`: each hop landed, a stop before the last
// (sound_event::STOP, a whole tone up each) or the last landing (sound_event::landing, or the finale in
// its place). A move sliding back says nothing: its mistake was said as it began.
fn add_sound_events(b: Board&, now: f64) {
    guard b.moving && !b.back else { return; }
    let n = hops(b.move);
    let reached = clamp(floor((now - b.since) / HOP + 1.0e-6) as i64, 0, n);
    while b.stops_sounded < reached {
        b.stops_sounded++;
        if b.stops_sounded < n { sound_event::add(b.sound_events, sound_event::STOP, b.stops_sounded - 1); }
        else if b.finale != sound_event::NONE { sound_event::add(b.sound_events, b.finale); }
        else { sound_event::add(b.sound_events, sound_event::landing(b.move.captured != 0, b.move.crowned)); }
    }
}

// Smoothstep, t in 0..1.
fn ease(t: f64) -> f64 { t * t * (3.0 - 2.0 * t) }

fn set_bit(bits: u32[4]&, n: i64) { bits[n / 32] |= (1 as u32) << (n % 32); }

fn mark(b: Board&, bits: u32[4]&, sq: i64) {
    let v .= rules::VARIANTS[b.variant];
    set_bit(bits, v.y_of[sq] * v.size + v.x_of[sq]);
}

// A hint's ring at `now` that began pulsing `at` (-1 still): full, fading to a third and
// back every 1.4 s for PULSE, then full and still.
fn ring_at(at: f64, now: f64) -> f32 {
    guard at >= 0.0 && now < at + PULSE else { return 1.0; }
    return (0.65 + 0.35 * cos(2.0 * PI * (now - at) / (0.5 * PULSE))) as f32;
}

// The last piece added gets a hint's glow ring as strong as k, pulsing while `at` is.
fn glow_ring(b: Board&, k: f32, at: f64, now: f64) {
    b.pieces[b.pieces.len - 1].ring.y = k;
    if at >= 0.0 && now < at + PULSE { b.pulsed = b.pieces.len - 1; }
}

// The last piece added is drained: in danger, or the crowning ghost king.
fn drain(b: Board&) {
    guard b.pieces.len > 0 else { return; }
    b.pieces[b.pieces.len - 1].ring.w = DRAINED;
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
fn build_frame_pieces(b: Board&, l: Layout, now: f64) {
    b.pieces.clear();
    b.marks = Marks {};
    b.dim = 0.0;
    let v .= rules::VARIANTS[b.variant];
    let r = 0.39 * l.inner.w;           // a disc fills 78% of its square
    let unit = 0.01 * l.board.z;        // 1% of the board
    let shown = if b.moving { b.before } else { b.pos };
    let t = move_time(b, now);
    let pulsing = now < b.pulse_end;
    let glowing = ring_at(b.glow_at, now);
    b.pulsed = -1;
    // The lookout's marks show on a board at rest.
    let danger = if b.moving { 0 } else { b.danger };
    let crowns = if b.moving { 0 } else { b.crowns };
    let ring: f32 = if pulsing { 1.0 } else { 2.0 };
    var must: u64 = 0;
    if (pulsing || b.rings_frozen) && must_capture(b) {
        for i in b.moves.len { must |= rules::bit(b.moves[i].from); }
    }
    if pulsing { must |= b.outtaken; }
    let count_on = counting(b);
    // A piece waiting partway through a capture is drawn on its stop; the pieces it has
    // jumped stay until the capture ends, as the rules take them, but see-through.
    let waits = if b.moving || b.dragging { -1 } else { capture_stop_square(b) };
    let taken = if !b.moving && b.selected >= 0 && b.steps.len > 0 { jumped(b) } else { 0 };
    let hop_over = if hopping(b, now) { between(v, b.hop_from, b.hop_to) } else { 0 };
    for row in v.size {
        let y = if l.flip { row } else { v.size - 1 - row };
        for x in v.size {
            let sq = rules::bit_at(v, x, y);
            guard sq >= 0 else { continue; }
            let m = rules::bit(sq);
            let white = shown.pieces[rules::WHITE] & m != 0;
            let black = shown.pieces[rules::BLACK] & m != 0;
            if crowns & m != 0 && !white && !black {
                // The other side's man would crown here: a dark, still ghost of its king.
                add(b, center(l, v, sq), r, 0.0, b.pos.side == rules::WHITE, true, 0.0, GHOST_KING, 0.0);
                drain(b);
                mark(b, b.marks.shade, sq);
            }
            guard white || black else { continue; }
            if b.moving && sq == b.move.from { continue; }
            if b.dragging && sq == b.selected { continue; }
            if waits >= 0 && sq == b.selected { continue; }
            var alpha: f32 = 1.0;
            // On the table, once carried off, the 3D board draws it on its way (view3d).
            if b.moving && b.move.captured & m != 0 && b.on_table && t > hops(b.move) * HOP { continue; }
            if b.moving && b.move.captured & m != 0 { alpha = taken_alpha(v, b.move, m, t); }
            if taken & m != 0 {
                let u = if hop_over & m != 0 { ease(clamp((now - b.hop_at) / HOP, 0.0, 1.0)) } else { 1.0 };
                alpha = (1.0 - (1.0 - TAKEN) * u) as f32;
            }
            let selected = sq == b.selected;
            add(b, center(l, v, sq), r, if selected { 1.1 * unit } else { 0.0 }, black,
                shown.kings & m != 0, if selected { 1.0 } else { 0.0 }, alpha, if must & m != 0 { ring } else { 0.0 });
            if sq == b.glow && !b.moving && b.pieces.len > 0 { glow_ring(b, glowing, b.glow_at, now); }
            if count_on && b.steps.len == 0 { show_takes(b, sq); }
            if danger & m != 0 { drain(b); }
        }
    }
    if b.hint_to >= 0 && !b.moving && b.glow >= 0 {
        add(b, center(l, v, b.hint_to), r, 0.0, b.pos.side == rules::BLACK, b.pos.kings & rules::bit(b.glow) != 0, 0.0,
            GHOST_HINT, 0.0);
        if b.pieces.len > 0 {
            b.pieces[b.pieces.len - 1].ring.w = LIGHT;
            glow_ring(b, ring_at(b.ghost_at, now), b.ghost_at, now);
        }
        var via = b.hint_via;
        while via != 0 {
            mark(b, b.marks.via, ctz(via));
            via &= via - 1;
        }
    }
    if b.played_to >= 0 && b.played_to != b.hint_to && !b.moving {
        add(b, center(l, v, b.played_to), r, 0.0, b.pos.side == rules::BLACK, b.pos.kings & rules::bit(b.played_from) != 0, 0.0,
            GHOST_HINT, 0.0);
        if b.pieces.len > 0 { b.pieces[b.pieces.len - 1].ring.w = LIGHT; }
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
        if count_on { show_takes(b, b.selected); }
        if danger & rules::bit(b.selected) != 0 { drain(b); }
    } else if waits >= 0 {
        // A man past the far row is crowned only where crowning goes on mid-capture.
        var king = b.pos.kings & rules::bit(b.selected) != 0;
        if v.crowning == rules::CROWN_CONTINUES {
            for st in b.steps { if v.promotion[b.pos.side] & rules::bit(st) != 0 { king = true; } }
        }
        var at = center(l, v, waits);
        var lift = 1.1 * unit;
        if hopping(b, now) {
            let a = center(l, v, b.hop_from);
            let u = ease(clamp((now - b.hop_at) / HOP, 0.0, 1.0));
            at = a + (at - a) * u as f32;
            lift += 4.0 * unit * sin(PI * u) as f32;
        }
        add(b, at, r, lift, b.pos.side == rules::BLACK, king, 1.0, 1.0, 0.0);
        if b.glow == b.selected && b.pieces.len > 0 { glow_ring(b, glowing, b.glow_at, now); }
        if count_on { show_takes(b, b.selected); }
    }
    if b.has_last && !b.moving {
        mark(b, b.marks.last, b.last.from);
        mark(b, b.marks.last, b.last.to);
        if b.trace {
            for s in b.last.path { mark(b, b.marks.last, s); }
            // Where it started, the mover at TRACE_GHOST: a man that crowned there was a man.
            let from = rules::bit(b.last.from);
            if (b.pos.pieces[rules::WHITE] | b.pos.pieces[rules::BLACK]) & from == 0 {
                let king = b.pos.kings & rules::bit(b.last.to) != 0 && !b.last.crowned;
                add(b, center(l, v, b.last.from), r, 0.0, b.pos.side == rules::WHITE, king, 0.0, TRACE_GHOST * b.trace_a, 0.0);
            }
        }
    }
    b.flash = float4 { -1.0, 1.0, 0.0, b.cursor + 1 };
    if next_shown(b) {
        var r = reachable(b);
        while r != 0 {
            mark(b, b.marks.next, ctz(r));
            r &= r - 1;
        }
        b.flash.z = ring_at(b.next_stops_pulse_at, now);
    }
    if b.wrong >= 0 {
        // Held, the ring stays as bright as its flash gets.
        let t = if b.rings_frozen { 0.2 } else { clamp((now - b.wrong_at) / FLASH, 0.0, 1.0) };
        b.flash.x = v.y_of[b.wrong] * v.size + v.x_of[b.wrong];
        b.flash.y = t as f32;
    }
    if b.selected >= 0 && !b.moving {
        // The stops tapped so far are ringed whatever the hints.
        for s in b.steps { if s != waits { mark(b, b.marks.via, s); } }
        for i in b.ways.len {
            let m .= b.ways[i];
            guard b.hints == MOVES && on_steps(b, m) else { continue; }
            mark(b, b.marks.target, m.to);
            for j in b.steps.len + 1..m.path.len - 1 { mark(b, b.marks.via, m.path[j]); }
        }
    }
}
