// The game's moves as played, each with its mark once judged (task 074): what the moves
// panel lists and the history keeps. The moves aren't kept beside the board: they are
// read off its undo history (board::Board.history, the position before each move), so
// undo, start over, and a saved game brought back need nothing of their own. A move's
// mark is kept while the move stays in the game; a move taken back loses it, and a
// saved game brought back is judged again.
//
// Judging asks the worker (game::JUDGE) for the oldest move not yet judged, after the
// computer's move, the hint, and the lookout's traps, so the game never waits on it.
namespace game;
import std;

struct Note {
    before: rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    move:   rules::Move     = rules::Move { .. },
    mark:   u8              = 0,        // ai::NOT_JUDGED, ONLY, BEST..
    loss:   i16             = 0,        // the fall in the mover's expected result, thousandths
}

type Notes = Note[..board::MAX_HISTORY];

// The position after move i of the board's history.
fn after(b: board::Board&, i: i64) -> rules::Position {
    return if i + 1 < b.history.len { b.history[i + 1].pos } else { b.pos };
}

// The legal move of p that leads to q, and whether there is one. Two captures by
// different ways that take the same pieces to the same square lead to one position: the
// first in move order stands for them.
fn move_between(p: rules::Position, q: rules::Position, out: rules::Moves&) -> rules::Move, bool {
    rules::generate(p, out);
    for i in out.len {
        let r = rules::play(p, out[i]);
        if rules::same(r, q) { return out[i], true; }
    }
    return rules::Move { .. }, false;
}

// Brings the notes in line with the board's history: keeps those whose move still
// stands, drops the rest, and adds the moves played since, unjudged. The oldest note
// goes with the oldest history step when the history is full. Returns whether they
// changed. Runs only when the history or the position changed (the caller's check).
fn sync_notes(gm: Game&) -> bool {
    let b .= gm.b;
    let ns .= gm.notes;
    var changed = false;
    // The history full and its oldest step dropped: the notes shift with it.
    if ns.len > 1 && b.history.len > 0 && !rules::same(ns[0].before, b.history[0].pos)
       && rules::same(ns[1].before, b.history[0].pos) {
        for k in ns.len - 1 { ns[k] = ns[k + 1]; }
        ns.pop();
        gm.notes_from += 1;
        changed = true;
    }
    var k = 0;
    while k < ns.len && k < b.history.len && rules::same(ns[k].before, b.history[k].pos) {
        let played = rules::play(ns[k].before, ns[k].move);
        let next = after(b, k);
        guard rules::same(played, next) else { break; }
        k += 1;
    }
    if k < ns.len { changed = true; }
    while ns.len > k { ns.pop(); }
    if b.history.len == 0 { gm.notes_from = 0; }
    for i in k..b.history.len {
        let m, ok = move_between(b.history[i].pos, after(b, i), gm.scratch);
        guard ok else { break; }
        ns.push(Note { before: b.history[i].pos, move: m, .. });
        changed = true;
    }
    // A judge asked for a move no longer in the game is dropped.
    if gm.judging != 0 && (gm.judge_ply >= ns.len || ns[gm.judge_ply].mark != ai::NOT_JUDGED) { gm.judging = 0; }
    return changed;
}

// Each frame: the notes brought in line where the board's history or position changed,
// and the next move to judge asked for. Returns whether the notes changed.
fn keep_notes(gm: Game&) -> bool {
    let b .= gm.b;
    var changed = false;
    if b.history.len != gm.notes_len || !rules::same(b.pos, gm.notes_pos) {
        changed = sync_notes(gm);
        gm.notes_len = b.history.len;
        gm.notes_pos = b.pos;
    }
    next_judge(gm);
    return changed;
}

// Asks for the oldest unjudged move to be judged, unless a judge is asked already or
// judging is off. The board at rest: a move still showing is judged once it has.
fn next_judge(gm: Game&) {
    guard gm.judge && gm.judging == 0 && !gm.b.moving else { return; }
    for n, i in gm.notes {
        guard n.mark == ai::NOT_JUDGED else { continue; }
        gm.asks += 1;
        gm.judging = gm.asks;
        gm.judge_ply = i;
        return;
    }
}

// The ask for judging note `judge_ply`: its position before, and the game's past up to
// it for the draws.
fn judge_ask(gm: Game&) -> Ask {
    let i = gm.judge_ply;
    var past = rules::Past { draw: rules::draw_start(gm.b.start), before: [] };
    board::past_to(gm.b, i, past);
    return Ask { id: gm.judging, pos: gm.notes[i].before, past: past, skill: ai::JUDGE_SKILL, seed: 0, kind: JUDGE,
                 move: gm.notes[i].move };
}

// The worker's verdict on the ask `id`: the note's mark. One for an ask no longer open is
// ignored. True when a mark was set.
fn judged(gm: Game&, id: i64, mark: i64, loss: i64) -> bool {
    guard id != 0 && id == gm.judging else { return false; }
    gm.judging = 0;
    guard gm.judge_ply < gm.notes.len else { return false; }
    let n .= gm.notes[gm.judge_ply];
    n.mark = mark as u8;
    n.loss = clamp(loss, 0, 1000) as i16;
    return true;
}

// Each side's marks counted over the notes (by ai::ONLY..BLUNDER), and its accuracy in
// percent over its judged moves, or -1 while none is.
struct Tally {
    marks:    i64[2 * ai::MARKS] = [0; 2 * ai::MARKS],   // side * MARKS + mark
    accuracy: i64[2]             = [-1, -1],
    judged:   i64[2]             = [0, 0],
    moves:    i64[2]             = [0, 0],
}

fn tally(ns: Notes&) -> Tally {
    var t = Tally {};
    var sum: i64[2] = [0, 0];
    for &n in ns {
        let s = n.before.side as i64;
        t.moves[s] += 1;
        t.marks[s * ai::MARKS + n.mark] += 1;
        guard n.mark != ai::NOT_JUDGED && n.mark != ai::ONLY else { continue; }
        t.judged[s] += 1;
        sum[s] += ai::accuracy(n.loss);
    }
    for s in 2 {
        if t.judged[s] > 0 { t.accuracy[s] = (sum[s] + t.judged[s] / 2) / t.judged[s]; }
    }
    return t;
}

// Whether every move is judged (or judging is off).
fn all_judged(gm: Game&) -> bool {
    for &n in gm.notes {
        if n.mark == ai::NOT_JUDGED { return false; }
    }
    return true;
}

// The moves panel (task 074, prototypes/history.html): the moves as numbered rows, white's
// and black's side by side, the last that fit, the latest move lit; after each its mark
// where marks show: a star in the glow color for the best, ?! gold, ? orange, ?? the
// forced-capture red, nothing for a good or only move or one not yet judged. Nothing
// allocates: each line is built in a fixed buffer.
let MOVES_ROW = 34.0;       // dp a row
let MOVES_PAD = 12.0;       // dp round the rows inside the glass
let MOVES_FADE = 40.0;      // dp at the list's top and foot over which rows past them fade
let MOVES_LIST = gui::PANEL_IDS + 16;  // the list's id (gui::scroll_begin)
let MOVES_NUMBER = 32.0;    // dp the moves' numbers take ("19." in the small face, 22)
let MARK_GAP = 4.0;         // dp between a move and its mark
let ORANGE = float4 { 1.0, 0.62, 0.25, 1.0 };

type Line = u8[..24];

fn push_number(out: Line&, n: i64) {
    var digits: u8[..20] = [];
    var k = max(n, 0);
    loop {
        digits.push(('0' + k % 10) as u8);
        k /= 10;
        guard k > 0 else { break; }
    }
    var i = digits.len - 1;
    while i >= 0 {
        out.push(digits[i]);
        i -= 1;
    }
}

fn push_square(out: Line&, v: rules::Variant&, b: i64) {
    if v.algebraic {
        out.push('a' + v.x_of[b]);
        push_number(out, v.y_of[b] as i64 + 1);
    } else {
        push_number(out, v.number_of[b]);
    }
}

// A move as the panel shows it: from and to, a capture's stops left out ("28x19",
// "c3:e5").
fn notation(out: Line&, v: rules::Variant&, m: rules::Move&) {
    out.clear();
    push_square(out, v, m.from);
    out.push(if m.captured == 0 { '-' } else if v.algebraic { ':' } else { 'x' });
    push_square(out, v, m.to);
}

// The mark's text and color, or "" for none.
fn mark_text(mark: u8) -> const u8[:], float4 {
    if mark == ai::BLUNDER { return "??", gui::RED; }
    if mark == ai::MISTAKE { return "?", ORANGE; }
    if mark == ai::INACCURACY { return "?!", gui::GOLD; }
    return "", gui::GOLD;
}

// The panel in l.moves, if the layout has room for it and the setting shows it.
fn moves_panel(gm: Game&, g: gui::Gui&, l: panel::Layout) {
    guard gm.moves_shown != 0 && l.moves.z > 0.0 && l.moves.w > 0.0 else { return; }
    let u = g.scale;
    let r = l.moves;
    gui::panel(g, r);
    let ns .= gm.notes;
    guard ns.len > 0 else {
        // No move yet: a dim line where the first row will be, so the glass isn't blank.
        let inner = gui::inset(r, MOVES_PAD * u);
        gui::text(g, gui::BODY, float4 { inner.x, inner.y, inner.z, MOVES_ROW * u }, strings::get(strings::MOVES_NONE),
                  0.55, 0.0, gui::LEFT);
        return;
    }
    let v .= rules::VARIANTS[gm.b.variant];
    let marks = gm.moves_shown == 2;
    // Black first (a game set up from a position) leaves white's half of row one empty.
    let off: i64 = if ns[0].before.side == rules::BLACK { 1 } else { 0 };
    let first_number = (gm.notes_from + off) / 2 + 1;
    let rows = (ns.len + off + 1) / 2;
    let inner = gui::inset(r, MOVES_PAD * u);
    let half = 0.5 * (inner.z - MOVES_NUMBER * u);
    // Every move, a list scrolled within the glass, at its foot (the latest) when a move
    // is added or the list is shown again; the rows past either edge fade out there.
    let view = float4 { r.x, r.y + 4.0 * u, r.z, r.w - 8.0 * u };
    let content = rows * MOVES_ROW * u + 2.0 * (MOVES_PAD - 4.0) * u;
    if g.scroll.id != MOVES_LIST || gm.moves_seen != ns.len {
        gui::scroll_set(g, MOVES_LIST, content);
        gm.moves_seen = ns.len;
    }
    let scrolled = gui::scroll_begin(g, MOVES_LIST, view, content);
    let listed = g.quads.len;
    var line: Line = [];
    for row in 0..rows {
        let y = inner.y - scrolled + row * MOVES_ROW * u;
        guard y + MOVES_ROW * u > view.y && y < view.y + view.w else { continue; }
        line.clear();
        push_number(line, first_number + row);
        line.push('.');
        gui::text(g, gui::SMALL, float4 { inner.x, y, MOVES_NUMBER * u, MOVES_ROW * u }, line[..], 0.55, 0.0, gui::LEFT);
        for side in 2 {
            let i = 2 * row + side - off;
            guard i >= 0 && i < ns.len else { continue; }
            let n .= ns[i];
            let cell = float4 { inner.x + MOVES_NUMBER * u + side * half, y, half, MOVES_ROW * u };
            notation(line, v, n.move);
            let w = gui::text_width(g, gui::BODY, line[..]);
            if i == ns.len - 1 {
                gui::glow_fill(g, float4 { cell.x - 6.0 * u, cell.y + 3.0 * u, w + 12.0 * u, cell.w - 6.0 * u }, 0.22, 8.0 * u);
            }
            gui::text(g, gui::BODY, cell, line[..], 1.0, 0.0, gui::LEFT);
            guard marks else { continue; }
            let at = cell.x + w + MARK_GAP * u;
            if n.mark == ai::BEST {
                let k = 16.0 * u;
                gui::glyph_icon(g, float4 { at, cell.y + 0.5 * (cell.w - k), k, k }, gui::STAR, gui::PLAIN, 0.0, 0.9);
                continue;
            }
            let t, c = mark_text(n.mark);
            if t.len > 0 { gui::colored(g, gui::BODY, float4 { at, cell.y, cell.z, cell.w }, t, c, gui::LEFT); }
        }
    }
    gui::fade_edges(g, listed, view, scrolled, content - scrolled - view.w, MOVES_FADE * u);
    gui::scroll_end(g);
}
