// A past game replayed (task 078's C, prototypes/history.html's replay view), opened from
// its row on the results screen: the board at a move beside the game's whole move list,
// to step through, and play from here, which plays the game on from the move shown. The
// replay only shows: it has its own board and moves, never the game's, so it doesn't
// become the game to continue, and nothing of it is written to the history or moves a
// rating. The game played from it is the shell's (shell::play_from_here), and counts for
// nothing either.
//   Landscape: the steps a column of four taps at the board's left (to the start, back,
//   on, to the end), the board the height less the margins, and at its right back, the
//   title, and play from here over a glass holding what the move shown was and the list.
//   Portrait: back, the title, and play from here, the board, the steps a row under it,
//   then the glass.
// Play from here stands at the head's right end, its icon beside its word, or over it
// where that is too wide; where the head has no room for it beside back and the title (the
// tablet's narrow column), it is a row of its own over the glass. It is dimmed at the end
// of a game that ended there. Under it, at the glass's top, a note with an info sign says
// that a game played from here doesn't count and why; where the list would lose too much
// to it, only that it doesn't, or that in place of the game's line (frame). In portrait
// the board gives way for it. The head says what the game was (the result, the opponent
// and its rating, the date) on the title's second line where it fits, else at the glass's
// top. Over the list a line names the move shown with its mark and the
// mark's tip; each side's accuracy heads its column. The list's moves are taps that jump
// there, 34 dp rows under the 88 dp rule, as a miss only shows the next move, which the
// steps put right. The board takes no moves; its last move's mark sits in a disc at its
// square's corner. Left and Right step the moves from anywhere (gui::claim_sideways);
// the keys' focus on a move shows it. The positions are played out from the moves once,
// as it opens, into fixed buffers; a frame allocates nothing.
namespace replay;
import std;
import vec;

let NOTHING = gui::ASK_NOTHING;
let BACK = gui::ASK_BACK;
let SHOWN = gui::ASK_SHOWN;         // another move shown
let PLAY = 1;                       // play from here: a game from the move shown

let MAX_PLIES = board::MAX_HISTORY;
let POSITIONS = 513;        // MAX_PLIES + 1: the start and the position after each move

let EDGE = 24.0;            // dp from the safe area's edges
let GAP = 12.0;             // between the parts
let BESIDE = 24.0;          // between the board and the column at its right
let MIN_SIDE = 300.0;       // the column at the board's right, at least, in landscape
let MIN_LIST = 220.0;       // the glass under the steps, at least, in portrait
let MIN_BOARD = 300.0;      // the least board in portrait that gives way to the note
let IN = 16.0;              // inside the glass
let ROW = 34.0;             // a row of the list
let NUMBER = 40.0;          // the moves' numbers ("100." in the small face)
let LINE = 26.0;            // a line of the move shown
let DISC = 9.0;             // dp: the radius of a side's piece by its accuracy and the move shown
let FADE = 40.0;            // dp at the list's top and foot over which rows past them fade
let MARK_GAP = 4.0;
let INFO = 18.0;            // dp: the note's info sign, a disc
let INFO_GAP = 8.0;         // between the sign and the note's words
let NOTE_GAP = 8.0;         // under the note
let NOTE_LIST = 3.0;        // the list's rows the note leaves it, where it had them: the move shown and one either side,
let BRIEF_LIST = 2.0;       // and the short one where the whole has no room: the move shown and one more

// Which note the glass has (frame): none, why a game from here doesn't count, only that it
// doesn't, or that in the game's line's place.
let NOTE_NONE = 0;
let NOTE_WHY = 1;
let NOTE_SHORT = 2;
let NOTE_INSTEAD = 3;

let BACK_ID = gui::REPLAY_IDS;
let STEP_ID = gui::REPLAY_IDS + 1;  // the four steps
let LIST = gui::REPLAY_IDS + 5;     // the list's scroll
let PLAY_ID = gui::REPLAY_IDS + 6;  // play from here
let MOVE_ID = gui::REPLAY_IDS + 10; // a move's tap, by its index in the game

// A move of the game as the list and the board need it, with its mark.
struct Ply {
    captured: u64 = 0,
    from:     u8  = 0,
    to:       u8  = 0,
    mark:     u8  = 0,          // ai::NOT_JUDGED..BLUNDER
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
    // Where the last frame put the note that a game from here doesn't count, and which
    // (NOTE_NONE..): for the layout's tests.
    note: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    kind: i64    = 0,
}

fn new() -> Replay { Replay { b: board::new(rules::INTERNATIONAL), .. } }

// The legal move of `legal` a history's word stands for (rules::format_move's text), or
// its from and to alone, as a capture written without its stops; -1 for none.
fn find(legal: rules::Moves&, variant: u8, word: const u8[:], said: u8[>..]&) -> i64 {
    let v .= rules::VARIANTS[variant];
    for i in legal.len {
        said.clear();
        rules::format_move(said, variant, legal[i]);
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
// start, as far as each is legal, with their marks; shown at its end.
fn open(r: Replay&, g: history::Game, line: const u8[:]) {
    r.game = g;
    r.plies.clear();
    r.pos.clear();
    let variant = g.variant as u8;
    var p = rules::start(variant);
    r.pos.push(p);
    let moves, marks = history::moves_of(line);
    var legal: rules::Moves = [];
    var said:  u8[>..]      = [];
    for word in split(moves, ' ') {
        guard word.len > 0 else { continue; }
        guard r.plies.len < MAX_PLIES else { break; }
        rules::generate(p, legal);
        let i = find(legal, variant, word, said);
        guard i >= 0 else { break; }
        let k = r.plies.len;
        let c = if k < marks.len { (marks[k] as i64) - '0' } else { 0 };
        let mark = if c >= 0 && c < ai::MARKS { c } else { ai::NOT_JUDGED };
        r.plies.push(Ply { captured: legal[i].captured, from: legal[i].from, to: legal[i].to, mark: mark as u8 });
        p = rules::play(p, legal[i]);
        r.pos.push(p);
    }
    rules::generate(p, legal);
    r.over = legal.len == 0;
    board::reset(r.b, variant);
    r.b.quiet = true;
    r.b.by_hand = true;
    r.ply = -1;
    r.focused = 0;
    r.seen = -1;
    go(r, r.plies.len, 0.0);
}

// Shows the position after `ply` moves (clamped to the game), the one move on from the
// one shown played on the board, the others at once. True when another is shown.
fn go(r: Replay&, ply: i64, now: f64) -> bool {
    let k = clamp(ply, 0, r.plies.len);
    guard k != r.ply else { return false; }
    let one = r.ply >= 0 && k == r.ply + 1;
    let from = if one { r.ply } else { k };
    board::set(r.b, r.pos[from]);
    if one {
        let m = r.plies[r.ply];
        var at = -1;
        for x, i in r.b.moves {
            if at < 0 && x.from == m.from && x.to == m.to && x.captured == m.captured { at = i; }
        }
        if at >= 0 { board::start_move(r.b, at, now); }
        else { board::set(r.b, r.pos[k]); }
    }
    if k > 0 && !one {
        r.b.last = rules::Move { from: r.plies[k - 1].from, to: r.plies[k - 1].to, .. };
        r.b.has_last = true;
    }
    r.ply = k;
    return true;
}

// The board turned for a player who played black against the computer.
fn turned(r: Replay&) -> bool { r.game.level != history::FRIEND && r.game.side == rules::BLACK }

// The game's line: the opponent and its rating, and the date.
fn game_text(t: results::Text&, g: history::Game&) {
    t.clear();
    if g.level == history::FRIEND {
        results::push(t, strings::get(strings::RESULTS_FRIEND));
    } else {
        results::push(t, strings::get(strings::PICK_EASY + g.level));
        results::push(t, " ");
        results::push_number(t, ai::skill_rating(g.skill));
    }
    results::push(t, " · ");
    let y, m, d = history::date(g.time);
    results::push_number(t, y);
    t.push('-');
    results::push_two(t, m);
    t.push('-');
    results::push_two(t, d);
}

// The game's result as the results list signs it, `k` dp across in r's left: a crown won,
// = drawn, an X lost (against a friend a crown for a game won by either side).
fn result_sign(g: gui::Gui&, r: float4, x: history::Game&, k: f32) {
    let u = g.scale;
    let res = if x.level == history::FRIEND { if x.winner == history::DRAW { 0 } else { 1 } } else { history::result(x) };
    let icon = float4 { r.x, r.y + 0.5 * (r.w - k * u), k * u, k * u };
    if res > 0 { gui::glyph_icon(g, icon, gui::CROWN, gui::PLAIN, 0.0, 0.9); }
    if res == 0 { gui::text(g, gui::BODY, icon, "=", 0.8, 0.0, gui::CENTER); }
    if res < 0 { gui::glyph_icon(g, gui::inset(icon, 2.0 * u), gui::CLOSE, gui::PLAIN, 0.0, 0.6); }
}

// The game's line in r: its sign and its text, dimmed.
fn game_line(g: gui::Gui&, r: float4, x: history::Game&) {
    let u = g.scale;
    var t: results::Text = [];
    game_text(t, x);
    result_sign(g, r, x, 20.0);
    gui::text(g, gui::SMALL, float4 { r.x + 28.0 * u, r.y, r.z - 28.0 * u, r.w }, t[..], 0.66, 0.0, gui::LEFT);
}

fn game_width(g: gui::Gui&, x: history::Game&) -> f32 {
    var t: results::Text = [];
    game_text(t, x);
    return 28.0 * g.scale + gui::text_width(g, gui::SMALL, t[..]);
}

// The title and the game's line in r, between back and play from here. Returns whether
// the game's line is in it, which it is where it fits on a line of its own under the
// title. Where even the title has no room, neither shows, and the glass's top has the game.
fn title(g: gui::Gui&, r: float4, x: history::Game&) -> bool {
    let u = g.scale;
    let name = strings::get(strings::REPLAY_TITLE);
    guard gui::text_width(g, gui::LABEL, name) <= r.z else { return false; }
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

// Whether the title in a room w pixels wide has the game's line under it (title).
fn titles(g: gui::Gui&, w: f32, x: history::Game&) -> bool {
    return gui::text_width(g, gui::LABEL, strings::get(strings::REPLAY_TITLE)) <= w && game_width(g, x) <= w;
}

// Whether the move shown can be played on from: any but the end of a game that ended
// there.
fn playable(r: Replay&) -> bool { r.ply < r.plies.len || !r.over }

// How play from here fits in the head, `head` pixels across: its icon beside its word
// (gui::MIDDLE), or over it (gui::STACKED, the word in a smaller face where the room
// left is narrower than it, down to the small face), or not (0: a row of its own); its
// width there; whether the title keeps its place beside it; and whether back is its
// arrow over its word in a tap's square. On a phone the title gives its room up, then
// back its width, before the button goes to a row, which would cost the list or the
// board most of what a phone has (the game's line then heads the glass).
fn play_fit(g: gui::Gui&, head: f32, phone: bool) -> i64, f32, bool, bool {
    let u = g.scale;
    let word = strings::get(strings::REPLAY_PLAY);
    let wide = gui::back_width(g, strings::get(strings::NAV_BACK));
    let name = gui::text_width(g, gui::LABEL, strings::get(strings::REPLAY_TITLE)) + GAP * u;
    let beside = gui::labelled_width(g, 34.0, word, gui::HEADING);
    let over = max(gui::tap() * u, gui::text_width(g, gui::HEADING, word) + 2.0 * gui::LABEL_PAD * u);
    let least = max(gui::tap() * u, gui::text_width(g, gui::SMALL, word) + 2.0 * gui::LABEL_PAD * u);
    for k in 3 {
        let titled = k == 0;
        let square = k == 2;
        guard titled || phone else { continue; }
        let back = (if square { gui::tap() * u } else { wide }) + gui::PAD_WIDE * u;
        let room = head - back - (if titled { name } else { 0.0 });
        if room >= beside { return gui::MIDDLE, beside, titled, square; }
        if room >= least { return gui::STACKED, min(room, over), titled, square; }
    }
    return 0, 0.0, true, false;
}

// One step's tap, dimmed where it would change nothing (at the start or the end),
// though it still takes the press and the keys' focus. True when tapped and `on`.
fn step(g: gui::Gui&, id: i64, r: float4, icon: i64, on: bool) -> bool {
    let u = g.scale;
    let clicked, p = gui::hold(g, id, r);
    let a: f32 = if on { 1.0 } else { 0.35 };
    gui::add(g, gui::Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { gui::BUTTON, 22.0 * u, 0.0, p },
                            extra: float4 { u, gui::PLAIN, gui::hover(g, id), 0.0 } });
    let s = 44.0 * u * (1.0 - 0.04 * p);
    gui::glyph_icon(g, gui::center(r, s, s), icon, gui::PLAIN, p, a);
    return clicked && on;
}

// Black first (a game set up from a position) leaves white's half of row one empty.
fn offset(r: Replay&) -> i64 { if r.pos.len > 0 && r.pos[0].side == rules::BLACK { 1 } else { 0 } }

// The move number of move i, and whether it is black's.
fn number_of(r: Replay&, i: i64) -> i64, bool {
    let k = i + offset(r);
    return k / 2 + 1, k % 2 == 1;
}

fn as_move(p: Ply&) -> rules::Move { rules::Move { from: p.from, to: p.to, captured: p.captured, .. } }

// The width of a move's mark after it in the list, 0 for none.
fn mark_width(g: gui::Gui&, mark: u8) -> f32 {
    let u = g.scale;
    if mark == ai::BEST { return MARK_GAP * u + 16.0 * u; }
    let t, c = game::mark_text(mark);
    return if t.len > 0 { MARK_GAP * u + gui::text_width(g, gui::BODY, t) } else { 0.0 };
}

// A move's mark from x in row r, as the moves panel draws it: a star for the best, ?! ?
// ?? in their colors, nothing for a good or only move.
fn mark_at(g: gui::Gui&, x: f32, r: float4, mark: u8, a: f32) {
    let u = g.scale;
    if mark == ai::BEST {
        let k = 16.0 * u;
        gui::glyph_icon(g, float4 { x, r.y + 0.5 * (r.w - k), k, k }, gui::STAR, gui::PLAIN, 0.0, 0.9 * a);
        return;
    }
    let t, c = game::mark_text(mark);
    if t.len > 0 { gui::colored(g, gui::BODY, float4 { x, r.y, r.z, r.w }, t, float4 { c.x, c.y, c.z, a }, gui::LEFT); }
}

// What the move shown was, in r (two lines): the mover's piece, its number and move, its
// mark, and the mark's tip, running on to the second line; at the start, a line saying so.
fn shown_line(r: Replay&, g: gui::Gui&, box: float4, over: board::Overlay&) {
    let u = g.scale;
    let first = float4 { box.x, box.y, box.z, LINE * u };
    guard r.ply > 0 else {
        gui::text(g, gui::BODY, first, strings::get(strings::REPLAY_START), 0.8, 0.0, gui::LEFT);
        return;
    }
    let i = r.ply - 1;
    let p .= r.plies[i];
    let side = r.pos[i].side as i64;
    panel::piece(over, float4 { box.x, box.y, 2.0 * DISC * u, LINE * u }, DISC * u, side, 0, 1.0, 0.0);
    var x = box.x + (2.0 * DISC + 10.0) * u;
    let v .= rules::VARIANTS[r.game.variant];
    var t: results::Text = [];
    let n, black = number_of(r, i);
    results::push_number(t, n);
    results::push(t, if black { "… " } else { ". " });
    var m: game::Line = [];
    let mv = as_move(p);
    game::notation(m, v, mv);
    results::push(t, m[..]);
    gui::text(g, gui::BODY, float4 { x, first.y, box.z, first.w }, t[..], 1.0, 0.0, gui::LEFT);
    x += gui::text_width(g, gui::BODY, t[..]);
    mark_at(g, x + MARK_GAP * u, first, p.mark, 1.0);
    x += mark_width(g, p.mark) + 8.0 * u;
    guard p.mark >= ai::ONLY && p.mark <= ai::BLUNDER else { return; }
    let tip = strings::get(strings::MARK_ONLY_TIP + 2 * ((p.mark as i64) - ai::ONLY));
    let room = box.x + box.z - x;
    if gui::text_width(g, gui::BODY, tip) <= room {
        gui::text(g, gui::BODY, float4 { x, first.y, room, first.w }, tip, 0.8, 0.0, gui::LEFT);
        return;
    }
    // Broken at the last space that leaves the first part on the first line; the rest
    // on the second, in a smaller face where it is too long for it.
    var cut = -1;
    for c, k in tip {
        if c == 32 && gui::text_width(g, gui::BODY, tip[..k]) <= room { cut = k; }
    }
    if cut > 0 { gui::text(g, gui::BODY, float4 { x, first.y, room, first.w }, tip[..cut], 0.8, 0.0, gui::LEFT); }
    let rest = if cut > 0 { tip[cut + 1..] } else { tip };
    let indent = (2.0 * DISC + 10.0) * u;
    let second = float4 { box.x + indent, box.y + LINE * u, box.z - indent, LINE * u };
    gui::text(g, gui::fitting(g, gui::BODY, rest, second.z), second, rest, 0.8, 0.0, gui::LEFT);
}

// The note that a game played from here doesn't count (2026-11-13, the user: next to the
// button that starts it): an info sign, a faint disc with an "i", and the words wrapped
// beside it in the small face, dim as settings' notes (settings::note_lines): why it
// doesn't count, or with `short` only that it doesn't, where the list has no room for
// more. Its height at r's top, r.z wide; drawn when `draw`.
fn note(g: gui::Gui&, r: float4, draw: bool, short: bool = false) -> f32 {
    let u = g.scale;
    let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    let k = INFO * u;
    let at = (INFO + INFO_GAP) * u;
    let s = strings::get(if short { strings::REPLAY_NO_COUNT } else { strings::REPLAY_NO_COUNT_WHY });
    let n = settings::note_lines(g, s, float4 { r.x + at, r.y, r.z - at, 0.0 }, draw);
    if draw {
        let sign = float4 { r.x, r.y + max(0.5 * (line - k), 0.0), k, k };
        gui::fill(g, sign, float4 { 1.0, 1.0, 1.0, 0.16 }, 0.5 * k);
        gui::text(g, gui::SMALL, sign, "i", settings::NOTE_A, 0.0, gui::CENTER);
    }
    return max(n * line, k);
}

// The glass's height above and under its list, inside its margins, `w` wide: the game's
// line where the head hasn't it, the move shown, the rule, the sides' heads, the legend.
fn above_list(g: gui::Gui&, w: f32, in_head: bool) -> f32 {
    let u = g.scale;
    let game = if in_head { 0.0 } else { (LINE + 6.0) * u };
    return game + (2.0 * LINE + 8.0 + ROW) * u + max(1.0, u) + game::legend_h(g, w);
}

// The steps' rects and where the board goes (x, y, size) and the head and the glass, for
// a safe area: landscape when it is wider than tall. With `row`, play from here is a row
// of its own over the glass (`play`), else in the head. In portrait the glass is MIN_LIST
// tall at least, or `need` pixels where the board stays MIN_BOARD with that: the room
// for the note and the list's rows it must keep (frame).
struct Layout {
    head:  float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    board: float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    glass: float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    steps: float4[4] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 4],
    play:  float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
}

fn layout(area: float4, u: f32, row: bool = false, need: f32 = 0.0) -> Layout {
    var o = Layout {};
    var c = gui::inset(area, EDGE * u);
    let tap = gui::tap() * u;
    if c.z > c.w {
        let size = max(min(c.w, c.z - tap - (GAP + BESIDE + MIN_SIDE) * u), 0.0);
        o.board = float4 { c.x + tap + GAP * u, c.y + 0.5 * (c.w - size), size, size };
        let gap = clamp((size - 4.0 * tap) / 3.0, 0.0, 16.0 * u);
        let top = o.board.y + 0.5 * (size - 4.0 * tap - 3.0 * gap);
        for i in 4 { o.steps[i] = float4 { c.x, top + i * (tap + gap), tap, tap }; }
        let x = o.board.x + size + BESIDE * u;
        var col = float4 { x, c.y, c.x + c.z - x, c.w };
        o.head = gui::cut_top(col, tap);
        gui::cut_top(col, GAP * u);
        if row {
            o.play = gui::cut_top(col, tap);
            gui::cut_top(col, GAP * u);
        }
        o.glass = col;
    } else {
        o.head = gui::cut_top(c, tap);
        gui::cut_top(c, GAP * u);
        let extra = if row { tap + GAP * u } else { 0.0 };
        let room = c.w - tap - extra - 2.0 * GAP * u;
        let bare = max(min(c.z, room - MIN_LIST * u), 0.0);
        let given = min(c.z, room - max(MIN_LIST * u, need));
        let size = if given >= bare || given >= MIN_BOARD * u { given } else { bare };
        o.board = float4 { c.x + 0.5 * (c.z - size), c.y, size, size };
        gui::cut_top(c, size + GAP * u);
        let steps = gui::cut_top(c, tap);
        gui::cut_top(c, GAP * u);
        let w = (steps.z - 3.0 * GAP * u) / 4.0;
        for i in 4 { o.steps[i] = float4 { steps.x + i * (w + GAP * u), steps.y, w, tap }; }
        if row {
            o.play = gui::cut_top(c, tap);
            gui::cut_top(c, GAP * u);
        }
        o.glass = c;
    }
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

    // Play from here in the head where it fits there, else a row of its own.
    var o = layout(area, u);
    let arrange, play_w, titled, square = play_fit(g, o.head.z, gui::phone(area, u));
    if arrange == 0 { o = layout(area, u, true); }
    // What the head leaves the title (the board's size changes neither), and whether the
    // game's line fits under it there.
    let back = strings::get(strings::NAV_BACK);
    let back_w = if square { gui::tap() * u } else { gui::back_width(g, back) };
    let room = o.head.z - back_w - gui::PAD_WIDE * u - (if arrange != 0 { play_w + GAP * u } else { 0.0 });
    let in_head = titled && titles(g, room, r.game);
    // The note leaves the list what it had without it, up to NOTE_LIST rows. In portrait
    // the board gives way for it, down to MIN_BOARD.
    let inner = o.glass.z - 2.0 * IN * u;
    let above = 2.0 * IN * u + above_list(g, inner, in_head);
    let keep = clamp(o.glass.w - above, 0.0, NOTE_LIST * ROW * u);
    let note_h = note(g, float4 { 0.0, 0.0, inner, 0.0 }, false) + NOTE_GAP * u;
    if area.z <= area.w { o = layout(area, u, arrange == 0, above + note_h + keep); }
    let v .= rules::VARIANTS[r.game.variant];
    l = board::layout_at(o.board.x, o.board.y, o.board.z, u, v.size);
    l.flip = turned(r);

    // The steps.
    gui::group(g, 1);
    let icons = [gui::FIRST, gui::PREV, gui::FWD, gui::LAST];
    for i in 4 {
        let to = if i == 0 { 0 } else if i == 1 { r.ply - 1 } else if i == 2 { r.ply + 1 } else { n };
        let on = if i < 2 { r.ply > 0 } else { r.ply < n };
        if step(g, STEP_ID + i, o.steps[i], icons[i], on) && go(r, to, now) { ask = SHOWN; }
        if i == 2 { gui::prefer(g, STEP_ID + i); }
    }

    // The head: back, the title and the game where it fits, and play from here.
    gui::group(g, 0);
    var head = o.head;
    if gui::back(g, BACK_ID, gui::cut_left(head, back_w), back, square) { ask = BACK; }
    gui::cut_left(head, gui::PAD_WIDE * u);
    let at = if arrange == 0 { o.play } else { gui::cut_right(head, play_w) };
    if arrange != 0 { gui::cut_right(head, GAP * u); }
    let icon = if r.game.level == history::FRIEND { gui::FRIEND } else { gui::COMPUTER };
    if gui::labelled(g, PLAY_ID, at, icon, 34.0, strings::get(strings::REPLAY_PLAY), gui::HEADING,
                     if arrange == 0 { gui::MIDDLE } else { arrange }, gui::PRIMARY, playable(r)) {
        ask = PLAY;
    }
    if titled { title(g, head, r.game); }

    // The glass: the game where the head had no room for it, the move shown, each side's
    // accuracy, and the list.
    gui::panel(g, o.glass);
    var c = gui::inset(o.glass, IN * u);
    // The note under play from here: why a game from here doesn't count, where the list
    // keeps what it must with it; else only that it doesn't, in the game's line's place,
    // which costs the list nothing (the results row the replay was opened from says what
    // the game was); else, the game's line in the head, only that it doesn't over the list
    // where that keeps BRIEF_LIST rows.
    let rows = c.w - above_list(g, c.z, in_head);
    let brief = note(g, c, false, true) + NOTE_GAP * u;
    r.kind = if rows - note_h >= keep - 0.5 { NOTE_WHY }
             else if !in_head { NOTE_INSTEAD }
             else if rows - brief >= min(keep, BRIEF_LIST * ROW * u) - 0.5 { NOTE_SHORT } else { NOTE_NONE };
    r.note = float4 { 0.0, 0.0, 0.0, 0.0 };
    if r.kind != NOTE_NONE {
        r.note = gui::cut_top(c, (if r.kind == NOTE_WHY { note_h } else { brief }) - NOTE_GAP * u);
        note(g, r.note, true, r.kind != NOTE_WHY);
        gui::cut_top(c, NOTE_GAP * u);
    }
    if !in_head && r.kind != NOTE_INSTEAD {
        game_line(g, gui::cut_top(c, LINE * u), r.game);
        gui::cut_top(c, 6.0 * u);
    }
    shown_line(r, g, gui::cut_top(c, 2.0 * LINE * u), over);
    gui::cut_top(c, 8.0 * u);
    gui::fill(g, gui::cut_top(c, max(1.0, u)), float4 { 1.0, 1.0, 1.0, 0.12 }, 0.0);
    let half = 0.5 * (c.z - NUMBER * u);
    let heads = gui::cut_top(c, ROW * u);
    var t: results::Text = [];
    for side in 2 {
        let at = heads.x + NUMBER * u + side * half;
        panel::piece(over, float4 { at, heads.y, 2.0 * DISC * u, heads.w }, DISC * u, side, 0, 1.0, 0.0);
        t.clear();
        let acc = r.game.accuracy[side];
        if acc >= 0 {
            results::push_number(t, acc);
            t.push('%');
        } else {
            t.push('-');
        }
        gui::text(g, gui::BODY, float4 { at + (2.0 * DISC + 8.0) * u, heads.y, half, heads.w }, t[..], 1.0, 0.0, gui::LEFT);
    }
    // The marks explained at the glass's foot, under the list (task 078's B).
    game::legend(g, gui::cut_bottom(c, game::legend_h(g, c.z)));
    list(r, g, float4 { o.glass.x, c.y, o.glass.z, c.w }, c.x, c.z, now, ask);

    // The last move's mark on the board, once it stands on its square.
    if r.ply > 0 && !r.b.moving { badge(g, l, v, r.plies[r.ply - 1]); }
    return ask;
}

// The list in `view`, its rows from x `left`, `width` wide: every move, scrolled to keep
// the move shown in view whenever it changes; a tap on a move jumps there (ask SHOWN).
fn list(r: Replay&, g: gui::Gui&, view: float4, left: f32, width: f32, now: f64, ask: i64&) {
    let u = g.scale;
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
    gui::group(g, 2);
    let scrolled = gui::scroll_begin(g, LIST, view, content);
    let listed = g.quads.len;
    let v .= rules::VARIANTS[r.game.variant];
    var t: results::Text = [];
    var m: game::Line    = [];
    for row in rows {
        let y = view.y + 4.0 * u - scrolled + row * row_h;
        guard y + row_h > view.y && y < view.y + view.w else { continue; }
        let num, unused = number_of(r, max(2 * row - off, 0));
        t.clear();
        results::push_number(t, num);
        t.push('.');
        gui::text(g, gui::SMALL, float4 { left, y, NUMBER * u, row_h }, t[..], 0.55, 0.0, gui::LEFT);
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
            let w = gui::text_width(g, gui::BODY, m[..]);
            let lit = i == r.ply - 1;
            let hover = gui::hover(g, id);
            // The move's shape first, which the keys' focus ring follows: lit for the move
            // shown, faint under the mouse or a press.
            if lit || g.focus == id || press > 0.0 || hover > 0.0 {
                let shape = float4 { cell.x - 6.0 * u, cell.y + 3.0 * u, w + mark_width(g, p.mark) + 12.0 * u, cell.w - 6.0 * u };
                if lit { gui::glow_fill(g, shape, 0.22 + 0.1 * press, 8.0 * u); }
                else { gui::fill(g, shape, float4 { 1.0, 1.0, 1.0, 0.04 + 0.06 * hover + 0.08 * press }, 8.0 * u); }
            }
            // Moves after the one shown are dimmed: not yet played on the board.
            let a: f32 = if i < r.ply { 1.0 } else { 0.55 };
            gui::text(g, gui::BODY, cell, m[..], a, 0.0, gui::LEFT);
            mark_at(g, cell.x + w + MARK_GAP * u, cell, p.mark, a);
            if clicked && go(r, i + 1, now) { ask = SHOWN; }
        }
    }
    gui::fade_edges(g, listed, view, scrolled, content - scrolled - view.w, FADE * u);
    gui::scroll_end(g);
}

// The mark of move p in a disc at its square's top right corner on the board: the star
// on the glow color, ?! gold, ? orange, ?? red; nothing for a good or only move.
fn badge(g: gui::Gui&, l: board::Layout, v: rules::Variant&, p: Ply&) {
    let u = g.scale;
    guard p.mark == ai::BEST || p.mark == ai::INACCURACY || p.mark == ai::MISTAKE || p.mark == ai::BLUNDER else { return; }
    let sq = l.inner.w;
    let at = board::center(l, v, p.to);
    let d = clamp(0.46 * sq, 22.0 * u, 34.0 * u);
    let r = float4 { at.x + 0.6 * sq - d, at.y - 0.62 * sq, d, d };
    if p.mark == ai::BEST {
        gui::glow_fill(g, r, 1.0, 0.5 * d);
        let k = 0.6 * d;
        gui::glyph_icon(g, gui::center(r, k, k), gui::STAR, gui::PLAIN, 0.0, 1.0);
        return;
    }
    let t, c = game::mark_text(p.mark);
    gui::fill(g, r, c, 0.5 * d);
    let ink = if p.mark == ai::BLUNDER { float4 { 1.0, 1.0, 1.0, 1.0 } } else { float4 { 0.1, 0.07, 0.03, 1.0 } };
    gui::colored(g, gui::SMALL, r, t, ink, gui::CENTER);
}
