// A past game replayed (prototypes/history.html's replay view), opened from its row on
// the results screen: the board at a move beside the game's move list, the steps, and
// play from here, which plays the game on from the move shown (shell::play_from_here).
// The replay only shows, with its own board and moves: nothing of it reaches the game,
// the history, or a rating. The positions are played out once, as it opens, into fixed
// buffers; a frame allocates nothing. The list's rows are 34 dp, under the 88 dp tap,
// as a miss only shows a nearby move, which the steps put right.
namespace replay;
import std;
import math;
import vec;

let NOTHING = gui::ASK_NOTHING;
let BACK = gui::ASK_BACK;
let SHOWN = gui::ASK_SHOWN;         // another move shown
let PLAY = gui::ASK_OWN;            // play from here: a game from the move shown

let MAX_PLIES = rules::MAX_HISTORY;
let POSITIONS = MAX_PLIES + 1; // the start and the position after each move

let EDGE = 24.0;            // dp from the safe area's edges
let GAP = 12.0;             // between the parts
let BESIDE = 24.0;          // between the board and the column at its right
let MIN_SIDE = 300.0;       // the column at the board's right, at least, in landscape
let MIN_LIST = 220.0;       // the glass under the steps, at least, in portrait
let IN = 16.0;              // inside the glass
let ROW = panel::MOVES_ROW;  // a row of the list, as the moves panel's
let NUMBER = 40.0;          // the moves' numbers ("100." in the small face)
let LINE = 26.0;            // a line of the move shown
let DISC = 9.0;             // dp: the radius of a side's piece by its accuracy and the move shown
let FADE = game::MOVES_FADE; // dp at the list's top and foot over which rows past them fade
let MARK_GAP = game::MARK_GAP;
let NOTE = 26.0;            // dp: the line under the board saying a game from here doesn't count

let REVEAL = 0.25;          // s: the move shown's marks fade in once its piece has arrived
let BULB_GAP = 8.0;         // dp: the bulb further below the steps than they are apart
let TILE_LINE = 44.0;       // dp: the glass's line about the best move as a tile (its tap a tap tall)
let SAY_ICON = 22.0;        // dp: the icon before a line of the glass about the best move
// The move's way on the board, in squares: a dot's radius, a stop's, how far apart the
// dots are, and how far they keep from a piece at the way's end and from a stop.
let DOT = 0.06;
let STOP_DOT = 0.12;
let DOT_STEP = 0.3;
let DOT_END = 0.42;
let DOT_STOP = 0.28;
// The squares' numbers: a fifth of a square, NUMBER_MIN dp at least, in the corner.
let NUMBER_SIZE = 0.2;
let NUMBER_MIN = 11.0;
// A desktop's large window (gui::large): the column at most LARGE_COL dp wide and at
// least LARGE_SIDE, its words LARGE times as large.
let LARGE_COL = 760.0;
let LARGE_SIDE = 420.0;
let LARGE = 1.5;

// The widget ids, from gui::REPLAY_IDS, each on from the one before by as many as it
// takes, so no two meet; test/gui/ids keeps IDS_END inside the range.
let BACK_ID = gui::REPLAY_IDS;
let STEP_ID = BACK_ID + 1;          // the four steps
let LIST = STEP_ID + 4;             // the list's scroll
let PLAY_ID = LIST + 1;             // play from here
let BULB_ID = PLAY_ID + 1;          // the comparison with the best move: the fifth step tile,
let BEST_LINE_ID = BULB_ID + 1;     // and the glass's line about the best move
let MOVE_ID = BEST_LINE_ID + 1;     // a move's tap, by its index in the game
let IDS_END = MOVE_ID + MAX_PLIES;

// The keys' groups (gui::group), in Tab's order: the head, the steps, the list.
let GROUP_HEAD = 0;
let GROUP_STEPS = 1;
let GROUP_LIST = 2;

// A move of the game as the list and the board need it, with its mark, and the best move
// from the position before it as the judge found it (none for an only move, one not
// judged, or a game written before the history kept them).
struct Ply {
    move:     rules::Way = rules::Way { .. },
    best:     rules::Way = rules::Way { .. },
    has_best: bool       = false,
    only:     bool       = false,       // the position before had this one legal move
    mark:     u8         = 0,           // ai::NOT_JUDGED..BLUNDER
}

struct Replay {
    game:  history::Game                = history::Game {},
    plies: Ply[..MAX_PLIES]             = [],
    pos:   rules::Position[..POSITIONS] = [],
    ply:   i64                          = 0,    // the moves shown played: 0 the start
    over:  bool                         = false, // the last position has no move: the game ended there
    b:     board::Board,
    // The move the keys' focus was on last frame (its tap's id), or 0; and the move the
    // list last scrolled to show, -1 none yet.
    focused: i64 = 0,
    seen:    i64 = -1,
    // Where the last frame put the line saying a game from here doesn't count, and
    // whether it said why: for the layout's tests.
    note: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    why:  bool   = false,
    rows: f32    = 0.0,     // the list's rows in view, for the layout's tests
    was:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 }, // the line about the best move, as a tap, or none: for the tests
    // The move shown compared with the best there (the bulb), kept through the steps; whether
    // the game has any best move (a game written before the history kept them has none: no
    // line for it, and the bulb stays dimmed).
    best:     bool = false,
    any_best: bool = false,
    // When the move shown's piece arrives (its marks fade in from then), or -1: at once.
    rest_at: f64 = -1.0,
    // This frame's words: the column's faces and how much larger its sizes are (LARGE on
    // a desktop's large window, else 1).
    k:     f32 = 1.0,
    body:  i64 = gui::BODY,
    small: i64 = gui::SMALL,
}

fn new() -> Replay { Replay { b: board::new(rules::INTERNATIONAL), .. } }

// The legal move of `legal` a history's word stands for (rules::format_move's text), or
// its from and to alone, as a capture written without its stops; -1 for none.
fn find(legal: rules::Moves&, p: rules::Position, word: const u8[:], said: u8[>..]&) -> i64 {
    let v .= rules::VARIANTS[p.variant];
    for i in legal.len {
        said.clear();
        rules::format_move(said, p, legal[i]);
        if said[..] == word { return i; }
    }
    for i in legal.len {
        said.clear();
        rules::format_square(said, v, legal[i].from);
        said.push(if legal[i].captured == 0 { '-' } else if v.algebraic { ':' } else { 'x' });
        rules::format_square(said, v, legal[i].to);
        if said[..] == word { return i; }
    }
    return -1;
}

// Opens game g, whose history line is `line`: its moves played out from the draughts'
// start, as far as each is legal, with their marks and best moves; shown at its end, the
// best move off.
fn open(r: Replay&, g: history::Game, line: const u8[:]) {
    r.game = g;
    r.best = false;
    r.any_best = false;
    r.plies.clear();
    r.pos.clear();
    let variant = g.variant as u8;
    var p = rules::start(variant);
    r.pos.push(p);
    let moves, marks, best = history::moves_of(line);
    var legal: rules::Moves = [];
    var said:  u8[>..]      = [];
    let bests = split(best, ' ');
    for word in split(moves, ' ') {
        guard word.len > 0 else { continue; }
        guard r.plies.len < MAX_PLIES else { break; }
        rules::generate(p, legal);
        let i = find(legal, p, word, said);
        guard i >= 0 else { break; }
        let k = r.plies.len;
        let c = if k < marks.len { (marks[k] as i64) - '0' } else { 0 };
        let mark = if c >= 0 && c < ai::MARKS { c } else { ai::NOT_JUDGED };
        var ply = Ply { move: rules::way_of(p, legal[i]), only: legal.len == 1, mark: mark as u8, .. };
        // The best move's word, if the line has one for this move: a legal move of p.
        if k < bests.len && bests[k] != "-" {
            let j = find(legal, p, bests[k], said);
            if j >= 0 {
                ply.best = rules::way_of(p, legal[j]);
                ply.has_best = true;
                r.any_best = true;
            }
        }
        r.plies.push(ply);
        p = rules::play(p, legal[i]);
        r.pos.push(p);
    }
    rules::generate(p, legal);
    r.over = legal.len == 0;
    board::reset(r.b, variant);
    r.b.quiet = true;
    r.b.by_hand = true;
    r.b.trace = true;
    r.ply = -1;
    r.focused = 0;
    r.seen = -1;
    go(r, r.plies.len, 0.0);
}

// Shows the move `ply` moves in (clamped to the game): a step on played on the board, any
// other step, and every step while comparing, at once. True when another is shown.
fn go(r: Replay&, ply: i64, now: f64) -> bool {
    let k = clamp(ply, 0, r.plies.len);
    guard k != r.ply else { return false; }
    let one = r.ply >= 0 && k == r.ply + 1 && !r.best;
    let before = r.ply;
    r.ply = k;
    r.rest_at = -1.0;
    guard one else {
        settle(r);
        return true;
    }
    board::set(r.b, r.pos[before]);
    let m = r.plies[before].move;
    var at = -1;
    for x, i in r.b.moves {
        if at < 0 && x.from == m.from && x.to == m.to && x.captured == m.captured { at = i; }
    }
    guard at >= 0 else {
        settle(r);
        return true;
    }
    board::start_move(r.b, at, now);
    // The move's marks show once its piece has arrived.
    if r.b.moving { r.rest_at = now + board::duration(r.b.move); }
    return true;
}

// The board at rest for the move shown: the position after it with it as the last move,
// or, comparing, the position before it, where the move and the best one both start, with
// no last move shaded (a third move on the board).
fn settle(r: Replay&) {
    guard !comparing(r) else {
        board::set(r.b, r.pos[r.ply - 1]);
        return;
    }
    board::set(r.b, r.pos[r.ply]);
    if r.ply > 0 {
        r.b.last = r.plies[r.ply - 1].move;
        r.b.has_last = true;
    }
}

// How far the move shown's marks have faded in at `now`, 0..1: none while its piece moves.
fn revealed(r: Replay&, now: f64) -> f32 {
    guard !r.b.moving else { return 0.0; }
    guard r.rest_at >= 0.0 else { return 1.0; }
    return clamp((now - r.rest_at) / REVEAL, 0.0, 1.0) as f32;
}

// Whether anything is still changing at `now`: the board, or the marks fading in.
fn animating(r: Replay&, now: f64) -> bool {
    board::animating(r.b, now) || (r.rest_at >= 0.0 && now < r.rest_at + REVEAL)
}

// Whether the move shown has a best move to compare it with: one the judge found, the
// move not forced.
fn has_best(r: Replay&) -> bool { r.ply > 0 && r.plies[r.ply - 1].has_best && !r.plies[r.ply - 1].only }

// Whether the board compares the move shown with the best one (the bulb on, and a best
// move there): the position before the move, both drawn from it.
fn comparing(r: Replay&) -> bool { r.best && has_best(r) }

// Whether the move shown was the best one.
fn was_best(p: Ply&) -> bool { p.best.from == p.move.from && p.best.to == p.move.to && p.best.captured == p.move.captured }

// The best move in place of the move shown as the game's hint, while comparing and the
// board is at rest: a ring on its piece, a light ghost and a ring where it goes, a ring at
// each stop between; lit and still, never pulsing (each frame sets it again). The move
// played gets a light ghost where it went too, with no ring.
fn show_best(r: Replay&) {
    let b .= r.b;
    guard comparing(r) && !b.moving else {
        b.glow = -1;
        b.hint_to = -1;
        b.hint_via = 0;
        b.played_to = -1;
        return;
    }
    // The move played, a light ghost where it went, as the best move's.
    b.played_from = r.plies[r.ply - 1].move.from;
    b.played_to = r.plies[r.ply - 1].move.to;
    let m .= r.plies[r.ply - 1].best;
    b.glow = m.from;
    b.glow_at = -1.0;
    b.hint_to = m.to;
    b.ghost_at = -1.0;
    var via: u64 = 0;
    if m.path.len > 2 {
        for i in 1..m.path.len - 1 { via |= rules::bit(m.path[i]); }
    }
    b.hint_via = via;
}

// The board turned for a player who played black against the computer.
fn turned(r: Replay&) -> bool { r.game.level != history::FRIEND && r.game.side == rules::BLACK }

// The game's line: the opponent and its rating, and the date.
fn game_text(t: gui::Text&, g: history::Game&) {
    t.clear();
    results::opponent(t, g);
    gui::push(t, " · ");
    results::date(t, g);
}

// The game's result as the results list signs it, `k` dp across in r's left: a crown won,
// = drawn, an X lost (against a friend a crown for a game won by either side).
fn result_sign(g: gui::Gui&, r: float4, x: history::Game&, k: f32) {
    let u = g.scale;
    let res = results::outcome(x);
    let icon = float4 { r.x, r.y + 0.5 * (r.w - k * u), k * u, k * u };
    if res > 0 { gui::glyph_icon(g, icon, gui::CROWN, gui::PLAIN, 0.0, 0.9); }
    if res == 0 { gui::text(g, gui::BODY, icon, "=", 0.8, 0.0, gui::CENTER); }
    if res < 0 { gui::glyph_icon(g, gui::inset(icon, 2.0 * u), gui::CLOSE, gui::PLAIN, 0.0, 0.6); }
}

// The game's line in r: its sign and its text, dimmed; in `face`, `k` times as large.
fn game_line(g: gui::Gui&, r: float4, x: history::Game&, face: i64 = gui::SMALL, k: f32 = 1.0) {
    let u = g.scale * k;
    var t: gui::Text = [];
    game_text(t, x);
    result_sign(g, r, x, 20.0 * k);
    gui::text(g, face, float4 { r.x + 28.0 * u, r.y, r.z - 28.0 * u, r.w }, t[..], 0.66, 0.0, gui::LEFT);
}

fn game_width(g: gui::Gui&, x: history::Game&) -> f32 {
    var t: gui::Text = [];
    game_text(t, x);
    return 28.0 * g.scale + gui::text_width(g, gui::SMALL, t[..]);
}

// The title and the game's line in r, between back and play from here. Returns whether
// the game's line is in it, which it is where it fits on a line of its own under the
// title. Where even the title has no room, neither shows, and the glass's top has the game.
fn title(g: gui::Gui&, r: float4, x: history::Game&) -> bool {
    let u = g.scale;
    let name = strings::get(strings::REPLAY_TITLE);
    guard gui::text_width(g, gui::LABEL, name) <= r.z + 0.5 else { return false; }
    let label = g.faces[gui::LABEL].ascent - g.faces[gui::LABEL].descent;
    let small = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    let gap = 6.0 * u;
    let second = small + 8.0 * u;
    let line = game_width(g, x) <= r.z;
    var c = gui::center(r, r.z, label + (if line { gap + second } else { 0.0 }));
    let top = gui::cut_top(c, label);
    gui::text(g, gui::LABEL, top, name, 1.0, 0.0, gui::LEFT);
    gui::cut_top(c, gap);
    if line { game_line(g, c, x); }
    return line;
}

// The position on the board, by its moves played: the move shown's, or, comparing, the
// one before it.
fn on_board(r: Replay&) -> i64 { if comparing(r) { r.ply - 1 } else { r.ply } }

// Whether the position on the board can be played on from: any but the end of a game that
// ended there.
fn playable(r: Replay&) -> bool { on_board(r) < r.plies.len || !r.over }

// How back and play from here share the head, `head` pixels across: both icon beside
// word (gui::MIDDLE) or both icon over word (gui::STACKED, play from here's word in a
// smaller face where its room is narrower than it, down to the small face), so they
// match; back's width and play from here's; and whether the title stands between them.
// The title gives its room up first; then the two tiles fill the head with GAP between
// them, in halves where play from here's word fits in its half, else it takes what it
// needs and back the rest, so no gap opens where the title was. They stack where side by
// side they don't fit. The game's line then heads the glass.
// With back elsewhere (`with_back` false: over the board on a desktop's large window),
// the head holds the title and play from here alone, back's width still returned.
fn play_fit(g: gui::Gui&, head: f32, with_back: bool = true) -> i64, f32, f32, bool {
    let u = g.scale;
    let word = strings::get(strings::REPLAY_PLAY);
    let wide = gui::back_width(g, strings::get(strings::NAV_BACK));
    let tap = gui::tap() * u;
    let name = gui::text_width(g, gui::LABEL, strings::get(strings::REPLAY_TITLE)) + GAP * u;
    // Beside, the word keeps back's room at the sides (gui::back_width), so the two tiles
    // match and the word doesn't sit against the tile's right edge.
    let beside = (2.0 * (gui::side() + 4.0) + 34.0 + 12.0) * u + gui::text_width(g, gui::HEADING, word);
    let over = max(tap, gui::text_width(g, gui::HEADING, word) + 2.0 * gui::LABEL_PAD * u);
    guard with_back else {
        let fits = head >= beside;
        let play = if fits { beside } else { min(over, head) };
        return if fits { gui::MIDDLE } else { gui::STACKED }, wide, play, head - name >= play;
    }
    if head - wide - gui::PAD_WIDE * u - name >= beside { return gui::MIDDLE, wide, beside, true; }
    let room = head - GAP * u;
    let arrange = if room >= wide + beside { gui::MIDDLE } else { gui::STACKED };
    let need = if arrange == gui::MIDDLE { beside } else { over };
    let least = if arrange == gui::MIDDLE { wide } else { tap };
    let play = max(min(max(0.5 * room, need), room - least), tap);
    return arrange, max(room - play, tap), play, false;
}

// One step's tap, dimmed where it would change nothing (at the start or the end),
// though it still takes the press and the keys' focus. True when tapped and `on`. The
// bulb is one too, gui::ON while the best move shows.
fn step(g: gui::Gui&, id: i64, r: float4, icon: i64, on: bool, style: i64 = gui::PLAIN) -> bool {
    let u = g.scale;
    let clicked, p = gui::hold(g, id, r);
    let a: f32 = if on { 1.0 } else { 0.35 };
    gui::add(g, gui::Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { gui::BUTTON, 22.0 * u, 0.0, p },
                            extra: float4 { u, style, gui::hover(g, id), 0.0 } });
    let s = 0.5 * min(r.z, r.w) * (1.0 - 0.04 * p);
    gui::glyph_icon(g, gui::center(r, s, s), icon, style, p, a);
    return clicked && on;
}

// Black first (a game set up from a position) leaves white's half of row one empty.
fn offset(r: Replay&) -> i64 { if r.pos.len > 0 && r.pos[0].side == rules::BLACK { 1 } else { 0 } }

// The move number of move i, and whether it is black's.
fn number_of(r: Replay&, i: i64) -> i64, bool {
    let k = i + offset(r);
    return k / 2 + 1, k % 2 == 1;
}

fn as_move(p: Ply&) -> rules::Move { rules::move_of(p.move) }

// The width of a move's mark after it in the list, its gap before it, 0 for none; the
// mark drawn as the moves panel draws it (game::mark_at), in the column's face.
fn mark_width(r: Replay&, g: gui::Gui&, mark: u8) -> f32 {
    let w = game::mark_width(g, mark, r.body, r.k);
    return if w > 0.0 { MARK_GAP * r.k * g.scale + w } else { 0.0 };
}

// A move with every stop of a capture, as the glass's lines about the best move write it
// ("22x33x24"); a quiet move from-to.
fn way_text(t: gui::Text&, v: rules::Variant&, m: rules::Way&) {
    guard m.captured != 0 && m.path.len > 2 else {
        game::notation(t, v, rules::move_of(m));
        return;
    }
    t.clear();
    for s, i in m.path {
        if i > 0 { t.push(if v.algebraic { ':' } else { 'x' }); }
        game::push_square(t, v, s);
    }
}

// What the move shown was, in r (two lines): the mover's piece, its number and move, its
// mark, and the mark's tip, running on to the second line; at the start, a line saying so.
fn shown_line(r: Replay&, g: gui::Gui&, box: float4, over: board::Overlay&) {
    let u = g.scale * r.k;
    let first = float4 { box.x, box.y, box.z, LINE * u };
    guard r.ply > 0 else {
        gui::text(g, r.body, first, strings::get(strings::REPLAY_START), 0.8, 0.0, gui::LEFT);
        return;
    }
    let i = r.ply - 1;
    let p .= r.plies[i];
    let side = r.pos[i].side as i64;
    panel::piece(over, float4 { box.x, box.y, 2.0 * DISC * u, LINE * u }, DISC * u, side, 0, 1.0, 0.0);
    var x = box.x + (2.0 * DISC + 10.0) * u;
    let v .= rules::VARIANTS[r.game.variant];
    var t: gui::Text = [];
    let n, black = number_of(r, i);
    gui::push_number(t, n);
    gui::push(t, if black { "… " } else { ". " });
    var m: game::Line = [];
    let mv = as_move(p);
    game::notation(m, v, mv);
    gui::push(t, m[..]);
    gui::text(g, r.body, float4 { x, first.y, box.z, first.w }, t[..], 1.0, 0.0, gui::LEFT);
    x += gui::text_width(g, r.body, t[..]);
    game::mark_at(g, x + MARK_GAP * u, first, p.mark, 1.0, r.body, r.k);
    x += mark_width(r, g, p.mark) + 8.0 * u;
    guard p.mark >= ai::ONLY && p.mark <= ai::BLUNDER else { return; }
    let tip = strings::get(strings::MARK_ONLY_TIP + 2 * ((p.mark as i64) - ai::ONLY));
    let room = box.x + box.z - x;
    if gui::text_width(g, r.body, tip) <= room {
        gui::text(g, r.body, float4 { x, first.y, room, first.w }, tip, 0.8, 0.0, gui::LEFT);
        return;
    }
    // Broken at the last space that leaves the first part on the first line; the rest
    // on the second, in a smaller face where it is too long for it.
    var cut = -1;
    for c, k in tip {
        if c == 32 && gui::text_width(g, r.body, tip[..k]) <= room { cut = k; }
    }
    if cut > 0 { gui::text(g, r.body, float4 { x, first.y, room, first.w }, tip[..cut], 0.8, 0.0, gui::LEFT); }
    let rest = if cut > 0 { tip[cut + 1..] } else { tip };
    let indent = (2.0 * DISC + 10.0) * u;
    let second = float4 { box.x + indent, box.y + LINE * u, box.z - indent, LINE * u };
    gui::text(g, gui::fitting(g, r.body, rest, second.z), second, rest, 0.8, 0.0, gui::LEFT);
}

// A line of the glass about the best move in box: an icon in `style` (gui::ON in the glow
// color), the words dimmed, then the move, in the column's face or a smaller one where
// the line is wider than box.
fn say(r: Replay&, g: gui::Gui&, box: float4, icon: i64, style: i64, words: const u8[:], way: const u8[:]) {
    let u = g.scale * r.k;
    let s = SAY_ICON * u;
    gui::glyph_icon(g, float4 { box.x, box.y + 0.5 * (box.w - s), s, s }, icon, style, 0.0, 1.0);
    let x = box.x + s + 10.0 * u;
    let room = box.x + box.z - x;
    var t: gui::Text = [];
    gui::push(t, words);
    if way.len > 0 {
        gui::push(t, " ");
        gui::push(t, way);
    }
    let face = gui::fitting(g, r.body, t[..], room);
    gui::text(g, face, float4 { x, box.y, room, box.w }, words, 0.8, 0.0, gui::LEFT);
    guard way.len > 0 else { return; }
    let w = gui::text_width(g, face, t[..min(words.len + 1, t.len)]);
    gui::text(g, face, float4 { x + w, box.y, room - w, box.w }, way, 1.0, 0.0, gui::LEFT);
}

// A line of the glass that is a tap, lit faintly under the mouse and by a press.
fn lit_line(g: gui::Gui&, box: float4, hover: f32, press: f32) {
    guard hover > 0.0 || press > 0.0 else { return; }
    let u = g.scale;
    gui::fill(g, float4 { box.x - 6.0 * u, box.y, box.z + 12.0 * u, box.w }, float4 { 1.0, 1.0, 1.0, 0.04 + 0.06 * hover + 0.08 * press },
              8.0 * u);
}

// The line about the move shown's best in box: what was best in its place ("The best was
// 34-29") or that it was the best, each the comparison's toggle, lit in the glow while it
// shows; or that the move was forced; or, with none of those, that the game ended here. As
// a `tile` (a phone), the toggle is a thin tile whose tap is a tap tall; elsewhere the line
// is a tap beside the bulb tile, lit under the mouse as the list's moves are. True when
// tapped.
fn best_line(r: Replay&, g: gui::Gui&, box: float4, tile: bool) -> bool {
    let u = g.scale;
    guard r.ply > 0 else { return false; }
    let p .= r.plies[r.ply - 1];
    if p.only {
        let key = if p.move.captured != 0 { strings::REPLAY_TAKE } else { strings::REPLAY_ONE };
        say(r, g, box, gui::LOCK, gui::PLAIN, strings::get(key + r.pos[r.ply - 1].side), "");
        return false;
    }
    guard p.has_best else {
        if r.ply == r.plies.len && r.over { say(r, g, box, gui::CROWN, gui::PLAIN, strings::get(strings::REPLAY_ENDED), ""); }
        return false;
    }
    let v .= rules::VARIANTS[r.game.variant];
    var way: gui::Text = [];
    let best = was_best(p);
    if !best { way_text(way, v, p.best); }
    var clicked = false;
    var inner = box;
    if tile {
        let tap = gui::tap() * u;
        let hit = float4 { box.x, box.y + 0.5 * (box.w - tap), box.z, tap };
        let c, press = gui::hold(g, BEST_LINE_ID, hit);
        clicked = c;
        gui::add(g, gui::Quad { rect: box, look: float4 { gui::BUTTON, 14.0 * u, 0.0, press },
                                extra: float4 { u, if r.best { gui::CHOSEN } else { gui::CHOICE }, gui::hover(g, BEST_LINE_ID), 0.0 } });
        inner = float4 { box.x + 12.0 * u, box.y, box.z - 24.0 * u, box.w };
    } else {
        let c, press = gui::hold(g, BEST_LINE_ID, box, false);
        clicked = c;
        lit_line(g, box, gui::hover(g, BEST_LINE_ID), press);
    }
    let words = strings::get(if best { strings::REPLAY_WAS_BEST } else { strings::REPLAY_BEST_WAS });
    say(r, g, inner, gui::STAR, if r.best || !tile { gui::ON } else { gui::PLAIN }, words, way[..]);
    return clicked;
}

// The line over the board in r saying that a game played from here doesn't count: in
// the small face, dim as settings' notes, centered; with why (replay.no_count_why) where
// that fits on the line, else only that it doesn't (replay.no_count), its glyphs drawn
// smaller where even that is wider than the line. Returns whether it said why.
fn disclaimer(g: gui::Gui&, r: float4, face: i64 = gui::SMALL) -> bool {
    let why = strings::get(strings::REPLAY_NO_COUNT_WHY);
    let full = gui::text_width(g, face, why) <= r.z;
    let s = if full { why } else { strings::get(strings::REPLAY_NO_COUNT) };
    let k = min(1.0, r.z / max(gui::text_width(g, face, s), 1.0));
    gui::write(g, face, r, s, float4 { 1.0, 1.0, 1.0, settings::NOTE_A }, false, 0.0, gui::CENTER, false, k);
    return full;
}

// The steps' rects and where the board goes (x, y, size) and the head and the glass, for
// a safe area: landscape when it is wider than tall. Over the board a NOTE dp line
// (`note`), which the board gives way for: in landscape by its height, the two centered
// in the height; in portrait by its height less the gap under the head, which it takes,
// so the glass keeps its room, MIN_LIST tall at least. In landscape the bulb is a fifth
// step tile, BULB_GAP further down, where the board's side holds five taps (`five`: the
// tablet, a desktop); else it is the glass's line. A desktop's large window (`big`)
// keeps the column LARGE_SIDE dp at least and LARGE_COL at most, the steps, the board,
// and the column centered as one, and its line over the board LARGE times as tall. Any
// desktop window in landscape has over the board a head row of its own (`back`, from the
// board's left edge, as wide) holding back and, in its middle, the line over the board,
// level with the column's head; the board gives up the row's height and GAP, its top
// level with the glass's, so back stands top left as on every other screen.
struct Layout {
    head:  float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    board: float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    note:  float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    glass: float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    steps: float4[4] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 4],
    bulb:  float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    back:  float4    = float4 { 0.0, 0.0, 0.0, 0.0 }, // back's row over the board (big), else none
    five:  bool      = false,
}

fn layout(area: float4, u: f32, big: bool = false) -> Layout {
    var o = Layout {};
    var c = gui::inset(area, EDGE * u);
    let tap = gui::tap() * u;
    let k: f32 = if big { LARGE } else { 1.0 };
    let note = NOTE * k * u;
    if c.z > c.w {
        let least = (if big { LARGE_SIDE } else { MIN_SIDE }) * u;
        // Back's own row over the board on any desktop window.
        let own = gui::desktop_scale > 0.0;
        let row = if own { tap + GAP * u } else { 0.0 };
        let over = if own { 0.0 } else { note };
        let size = max(min(c.w - row - over, c.z - tap - (GAP + BESIDE) * u - least), 0.0);
        var col = c.z - tap - (GAP + BESIDE) * u - size;
        if big { col = min(col, LARGE_COL * u); }
        let x0 = c.x + 0.5 * (c.z - (tap + (GAP + BESIDE) * u + size + col));
        let y0 = c.y + 0.5 * (c.w - row - size - over);
        o.board = float4 { x0 + tap + GAP * u, y0 + row + over, size, size };
        o.five = size >= 5.0 * tap + 4.0 * GAP * u;
        let n: f32 = if o.five { 5.0 } else { 4.0 };
        let extra = if o.five { BULB_GAP * u } else { 0.0 };
        let gap = clamp((size - n * tap - extra) / (n - 1.0), 0.0, 16.0 * u);
        let top = o.board.y + 0.5 * (size - n * tap - (n - 1.0) * gap - extra);
        for i in 4 { o.steps[i] = float4 { x0, top + i * (tap + gap), tap, tap }; }
        if o.five { o.bulb = float4 { x0, top + 4.0 * (tap + gap) + extra, tap, tap }; }
        let x = o.board.x + size + BESIDE * u;
        if own {
            o.back = float4 { o.board.x, y0, size, tap };
            o.note = float4 { o.board.x, y0 + 0.5 * (tap - note), size, note };
            o.head = float4 { x, y0, col, tap };
            o.glass = float4 { x, o.board.y, col, size };
        } else {
            var column = float4 { x, c.y, col, c.w };
            o.head = gui::cut_top(column, tap);
            gui::cut_top(column, GAP * u);
            o.glass = column;
        }
    } else {
        o.head = gui::cut_top(c, tap);
        let size = max(min(c.z, c.w - tap - (3.0 * GAP + MIN_LIST) * u) - (note - GAP * u), 0.0);
        gui::cut_top(c, note);
        o.board = float4 { c.x + 0.5 * (c.z - size), c.y, size, size };
        gui::cut_top(c, size + GAP * u);
        let steps = gui::cut_top(c, tap);
        gui::cut_top(c, GAP * u);
        let w = (steps.z - 3.0 * GAP * u) / 4.0;
        for i in 4 { o.steps[i] = float4 { steps.x + i * (w + GAP * u), steps.y, w, tap }; }
        o.glass = c;
    }
    if o.back.z == 0.0 { o.note = float4 { o.board.x, o.board.y - note, o.board.z, note }; }
    return o;
}

// The replay for this frame in `area`, its board put in l and the pieces it shows over
// the UI in `over`; `fresh` its first frame, whose Left or Right was the screen's before.
// Returns what it asks for.
fn frame(r: Replay&, g: gui::Gui&, area: float4, l: board::Layout&, over: board::Overlay&, now: f64,
         fresh: bool) -> i64 {
    let u = g.scale;
    var ask = NOTHING;
    let n = r.plies.len;
    let big = gui::large(area, u);
    r.k = if big { LARGE } else { 1.0 };
    r.body = if big { gui::LABEL } else { gui::BODY };
    r.small = if big { gui::HEADING } else { gui::SMALL };
    let k = r.k;
    // The keys: Left and Right step from anywhere, the focus on a move following the move
    // shown; the focus come to a move (Up and Down in the list) shows it.
    gui::claim_sideways(g);
    let key = if fresh { gui::STEP_NONE } else { g.pointer.step };
    let on_move = g.focus >= MOVE_ID && g.focus < MOVE_ID + n;
    if key == gui::STEP_LEFT || key == gui::STEP_RIGHT {
        if go(r, r.ply + (if key == gui::STEP_LEFT { -1 } else { 1 }), now) { ask = SHOWN; }
        if on_move { g.focus = MOVE_ID + max(r.ply - 1, 0); }
    } else if on_move && g.focus != r.focused {
        if go(r, g.focus - MOVE_ID + 1, now) { ask = SHOWN; }
    }
    r.focused = g.focus;

    let o = layout(area, u, big);
    let own = o.back.z > 0.0; // back in a row of its own over the board
    let arrange, back_w, play_w, titled = play_fit(g, o.head.z, !own);
    let v .= rules::VARIANTS[r.game.variant];
    l = board::layout_at(o.board.x, o.board.y, o.board.z, u, v.size);
    l.flip = turned(r);

    // The steps, and the bulb under them where it is a fifth tile.
    gui::group(g, GROUP_STEPS);
    let icons = [gui::FIRST, gui::PREV, gui::FWD, gui::LAST];
    for i in 4 {
        let to = if i == 0 { 0 } else if i == 1 { r.ply - 1 } else if i == 2 { r.ply + 1 } else { n };
        let on = if i < 2 { r.ply > 0 } else { r.ply < n };
        if step(g, STEP_ID + i, o.steps[i], icons[i], on) && go(r, to, now) { ask = SHOWN; }
        if i == 2 { gui::prefer(g, STEP_ID + i); }
    }
    var toggled = false;
    if o.five && step(g, BULB_ID, o.bulb, gui::HINT, has_best(r), if r.best { gui::ON } else { gui::PLAIN }) { toggled = true; }

    // The head: back, the title and the game where they fit, and play from here.
    gui::group(g, GROUP_HEAD);
    let label = strings::get(strings::NAV_BACK);
    if own && gui::back(g, BACK_ID, float4 { o.back.x, o.back.y, back_w, o.back.w }, label) { ask = BACK; }
    let tapped, at, head = gui::head(g, BACK_ID, o.head, label, if own { 0.0 } else { back_w }, arrange,
                                     if own { 0.0 } else { gui::PAD_WIDE * u }, play_w, GAP * u);
    if tapped { ask = BACK; }
    let icon = if r.game.level == history::FRIEND { gui::FRIEND } else { gui::COMPUTER };
    if gui::labelled(g, PLAY_ID, at, icon, 34.0, strings::get(strings::REPLAY_PLAY), gui::HEADING, arrange, gui::PRIMARY,
                     playable(r)) {
        ask = PLAY;
    }
    let in_head = titled && title(g, head, r.game);

    // Over the board, that a game from here doesn't count; not a tap. On a desktop it
    // shares back's row, kept clear of back on both sides so it stays centered.
    r.note = o.note;
    if own {
        let clear = back_w + GAP * u;
        r.note = float4 { o.note.x + clear, o.note.y, max(o.note.z - 2.0 * clear, 0.0), o.note.w };
    }
    r.why = disclaimer(g, r.note, r.small);

    // The glass: the game where the head had no room for it, the move shown, the line about
    // its best, each side's accuracy, and the list; the legend under it where the bulb is a
    // tile (portrait and a phone in landscape keep its room for the rows).
    let ku = k * u;
    gui::panel(g, o.glass);
    var c = gui::inset(o.glass, IN * ku);
    if !in_head {
        game_line(g, gui::cut_top(c, LINE * ku), r.game, r.small, k);
        gui::cut_top(c, 6.0 * ku);
    }
    shown_line(r, g, gui::cut_top(c, 2.0 * LINE * ku), over);
    r.was = float4 { 0.0, 0.0, 0.0, 0.0 };
    if r.any_best {
        gui::group(g, GROUP_STEPS);
        let line = if o.five { gui::cut_top(c, LINE * ku) } else { gui::cut_top(c, 10.0 * u); gui::cut_top(c, TILE_LINE * u) };
        if has_best(r) { r.was = line; }
        if best_line(r, g, line, !o.five) { toggled = true; }
    }
    if toggled && has_best(r) {
        r.best = !r.best;
        settle(r);
        ask = SHOWN;
    }
    show_best(r);
    gui::cut_top(c, 8.0 * ku);
    gui::fill(g, gui::cut_top(c, max(1.0, u)), float4 { 1.0, 1.0, 1.0, 0.12 }, 0.0);
    let half = 0.5 * (c.z - NUMBER * ku);
    let heads = gui::cut_top(c, ROW * ku);
    var t: gui::Text = [];
    for side in 2 {
        let at = heads.x + NUMBER * ku + side * half;
        panel::piece(over, float4 { at, heads.y, 2.0 * DISC * ku, heads.w }, DISC * ku, side, 0, 1.0, 0.0);
        t.clear();
        let acc = r.game.accuracy[side];
        if acc >= 0 {
            gui::push_number(t, acc);
            t.push('%');
        } else {
            t.push('-');
        }
        gui::text(g, r.body, float4 { at + (2.0 * DISC + 8.0) * ku, heads.y, half, heads.w }, t[..], 1.0, 0.0, gui::LEFT);
    }
    // The marks explained at the glass's foot, under the list.
    if o.five { game::legend(g, gui::cut_bottom(c, game::legend_h(g, c.z, k, r.small)), k, r.small, r.body); }
    r.rows = c.w / (ROW * ku);
    list(r, g, float4 { o.glass.x, c.y, o.glass.z, c.w }, c.x, c.z, now, ask);

    // The move shown on the board once it stands on its square, fading in (comparing, from
    // the square it starts on, at once): its way, its squares' numbers and the best move's
    // while it shows, and its mark.
    let a = revealed(r, now);
    r.b.trace_a = a;
    guard a > 0.0 else { return ask; }
    if r.ply > 0 {
        var ds: Dots = [];
        dots_of(l, v, r.plies[r.ply - 1].move, ds);
        for d in ds { dot(g, float2 { d.x, d.y }, d.z, a); }
    }
    numbers(g, l, v, numbered(r), a);
    if r.ply > 0 { badge(g, l, v, r.plies[r.ply - 1], a); }
    return ask;
}

// The squares whose numbers show (bits): every square the move shown stood on, and the
// best move's while it shows on the board.
fn numbered(r: Replay&) -> u64 {
    var squares: u64 = 0;
    if r.ply > 0 { for s in r.plies[r.ply - 1].move.path { squares |= rules::bit(s); } }
    if r.b.glow >= 0 && has_best(r) { for s in r.plies[r.ply - 1].best.path { squares |= rules::bit(s); } }
    return squares;
}

// The list in `view`, its rows from x `left`, `width` wide: every move, scrolled to keep
// the move shown in view whenever it changes; a tap on a move jumps there (ask SHOWN).
fn list(r: Replay&, g: gui::Gui&, view: float4, left: f32, width: f32, now: f64, ask: i64&) {
    let u = g.scale * r.k;
    let n = r.plies.len;
    let off = offset(r);
    let rows = (n + off + 1) / 2;
    let row_h = ROW * u;
    let content = rows * row_h + 8.0 * u;
    let half = 0.5 * (width - NUMBER * u);
    let shown_row = (max(r.ply - 1, 0) + off) / 2;
    if r.seen != r.ply {
        var at = if g.scroll.id == LIST { g.scroll.offset } else { 0.0 };
        let top = shown_row * row_h;
        if top - row_h < at { at = top - row_h; }
        if top + 2.0 * row_h > at + view.w { at = top + 2.0 * row_h - view.w; }
        gui::scroll_set(g, LIST, at);
        r.seen = r.ply;
    }
    gui::group(g, GROUP_LIST);
    let scrolled = gui::scroll_begin(g, LIST, view, content);
    let listed = g.quads.len;
    let v .= rules::VARIANTS[r.game.variant];
    var t: gui::Text  = [];
    var m: game::Line = [];
    for row in rows {
        let y = view.y + 4.0 * u - scrolled + row * row_h;
        guard y + row_h > view.y && y < view.y + view.w else { continue; }
        let num, unused = number_of(r, max(2 * row - off, 0));
        t.clear();
        gui::push_number(t, num);
        t.push('.');
        gui::text(g, r.small, float4 { left, y, NUMBER * u, row_h }, t[..], 0.55, 0.0, gui::LEFT);
        for side in 2 {
            let i = 2 * row + side - off;
            guard i >= 0 && i < n else { continue; }
            let p .= r.plies[i];
            let id = MOVE_ID + i;
            let cell = float4 { left + NUMBER * u + side * half, y, half, row_h };
            let clicked, press = gui::hold(g, id, cell);
            // Tab come to the list lands on the move shown.
            if i == r.ply - 1 { gui::prefer(g, id); }
            let mv = as_move(p);
            game::notation(m, v, mv);
            let w = gui::text_width(g, r.body, m[..]);
            let lit = i == r.ply - 1;
            let hover = gui::hover(g, id);
            // The move's shape first, which the keys' focus ring follows: lit for the move
            // shown, faint under the mouse or a press.
            if lit || g.focus == id || press > 0.0 || hover > 0.0 {
                let shape = float4 { cell.x - 6.0 * u, cell.y + 3.0 * u, w + mark_width(r, g, p.mark) + 12.0 * u, cell.w - 6.0 * u };
                if lit { gui::glow_fill(g, shape, 0.22 + 0.1 * press, 8.0 * u); }
                else { gui::fill(g, shape, float4 { 1.0, 1.0, 1.0, 0.04 + 0.06 * hover + 0.08 * press }, 8.0 * u); }
            }
            // Moves after the one shown are dimmed: not yet played on the board.
            let a: f32 = if i < r.ply { 1.0 } else { 0.55 };
            gui::text(g, r.body, cell, m[..], a, 0.0, gui::LEFT);
            game::mark_at(g, cell.x + w + MARK_GAP * u, cell, p.mark, a, r.body, r.k);
            if clicked && go(r, i + 1, now) { ask = SHOWN; }
        }
    }
    gui::fade_edges(g, listed, view, scrolled, content - scrolled - view.w, FADE * u);
    gui::scroll_end(g);
}

// A glow disc of radius `rad` pixels at c, at opacity a.
fn dot(g: gui::Gui&, c: float2, rad: f32, a: f32) { gui::glow_fill(g, float4 { c.x - rad, c.y - rad, 2.0 * rad, 2.0 * rad }, a, rad); }

// The way of a move in glow dots: each its centre and radius in pixels (x, y, z), at most
// MAX_DOTS (a king's longest capture on 10 × 10 needs under a hundred).
let MAX_DOTS = 160;
type Dots = float4[..MAX_DOTS];

fn put_dot(out: Dots&, x: f32, y: f32, rad: f32) { if out.len < MAX_DOTS { out.push(float4 { x, y, rad, 0.0 }); } }

// The way of move m on the board in dots, into out: from square centre to centre,
// DOT_STEP of a square apart, clear of the pieces at its ends (DOT_END) and of the stops
// between (DOT_STOP), and a larger dot at each stop.
fn dots_of(l: board::Layout, v: rules::Variant&, m: rules::Way&, out: Dots&) {
    out.clear();
    let sq = l.inner.w;
    let n = m.path.len;
    guard n >= 2 else { return; }
    for i in 1..n {
        let p0 = board::center(l, v, m.path[i - 1]);
        let p1 = board::center(l, v, m.path[i]);
        let dx = p1.x - p0.x;
        let dy = p1.y - p0.y;
        let len = sqrt(dx * dx + dy * dy) / sq;
        let start: f32 = if i == 1 { DOT_END } else { DOT_STOP };
        let end:   f32 = if i == n - 1 { DOT_END } else { DOT_STOP };
        let run = len - start - end;
        guard run > 0.0 else { continue; }
        let count = max(floor(run / DOT_STEP + 0.5) as i64, 1);
        for j in count + 1 {
            let t = (start + run * j / count) / len;
            put_dot(out, p0.x + dx * t, p0.y + dy * t, DOT * sq);
        }
    }
    for i in 1..n - 1 {
        let c = board::center(l, v, m.path[i]);
        put_dot(out, c.x, c.y, STOP_DOT * sq);
    }
}

// The numbers of the squares in `squares` (bits), as the move list writes them, at
// opacity a: in each square's top left corner, NUMBER_SIZE of a square tall and
// NUMBER_MIN dp at least, over a dark halo (gui::shadowed's, nearer) and drawn twice a
// little apart to read bold, the atlas having no bold face.
fn numbers(g: gui::Gui&, l: board::Layout, v: rules::Variant&, squares: u64, a: f32) {
    let sq = l.inner.w;
    let px = max(NUMBER_SIZE * sq, NUMBER_MIN * g.scale);
    // The smallest face at least as large, its glyphs drawn smaller to px.
    var face = gui::LABEL;
    for f in [gui::LABEL, gui::HEADING, gui::BODY, gui::SMALL] { if g.faces[f].size >= px { face = f; } }
    let fc .= g.faces[face];
    let k = min(1.0, px / max(fc.size, 1.0));
    let h = k * (fc.ascent - fc.descent);
    let d = max(0.04 * px, 0.75 * g.scale);
    let bold = max(0.035 * px, 0.5);
    var t: gui::Text = [];
    var left = squares;
    while left != 0 {
        let s = ctz(left);
        left &= left - 1;
        let c = board::center(l, v, s);
        let r = float4 { c.x - 0.5 * sq + 0.06 * sq, c.y - 0.5 * sq + 0.03 * sq, sq, h };
        t.clear();
        game::push_square(t, v, s);
        let ring = float4 { 0.0, 0.0, 0.0, 0.3 * a };
        for q in 8 {
            let ang = q as f32 * 0.785398;
            gui::write(g, face, float4 { r.x + d * cos(ang), r.y + d * sin(ang), r.z, r.w }, t[..], ring, true, 0.0, gui::LEFT, false, k);
        }
        let ink = float4 { 1.0, 1.0, 1.0, 0.9 * a };
        gui::write(g, face, r, t[..], ink, false, 0.0, gui::LEFT, false, k);
        gui::write(g, face, float4 { r.x + bold, r.y, r.z, r.w }, t[..], ink, false, 0.0, gui::LEFT, false, k);
    }
}

// The mark of move p in a disc at its square's top right corner on the board, at opacity
// a: the star on the glow color, ?! gold, ? orange, ?? red; nothing for a good or only
// move.
fn badge(g: gui::Gui&, l: board::Layout, v: rules::Variant&, p: Ply&, a: f32) {
    let u = g.scale;
    guard p.mark == ai::BEST || p.mark == ai::INACCURACY || p.mark == ai::MISTAKE || p.mark == ai::BLUNDER else { return; }
    let sq = l.inner.w;
    let at = board::center(l, v, p.move.to);
    let d = clamp(0.46 * sq, 22.0 * u, 34.0 * u);
    let r = float4 { at.x + 0.6 * sq - d, at.y - 0.62 * sq, d, d };
    if p.mark == ai::BEST {
        gui::glow_fill(g, r, a, 0.5 * d);
        let k = 0.6 * d;
        gui::glyph_icon(g, gui::center(r, k, k), gui::STAR, gui::PLAIN, 0.0, a);
        return;
    }
    let t, c = game::mark_text(p.mark);
    gui::fill(g, r, float4 { c.x, c.y, c.z, c.w * a }, 0.5 * d);
    let ink = if p.mark == ai::BLUNDER { float4 { 1.0, 1.0, 1.0, a } } else { float4 { 0.1, 0.07, 0.03, a } };
    gui::colored(g, gui::SMALL, r, t, ink, gui::CENTER);
}
