// The game's moves as played, each with its mark once judged, and the moves panel. The
// moves are read off the board's record, so undo, start over, and a saved game need
// nothing of their own; a move taken back loses its mark. Judging asks the worker for
// the oldest unjudged move, so the game never waits on it.
namespace game;
import std;

struct Note {
    before: rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    move:   rules::Move     = rules::Move { .. },
    mark:   u8              = 0,        // ai::NOT_JUDGED, ONLY, BEST..
    loss:   i16             = 0,        // the fall in the mover's expected result, thousandths
    // The judge's best move from `before`; none for an only move or one not judged.
    best:     rules::Move = rules::Move { .. },
    has_best: bool        = false,
}

type Notes = Note[..rules::MAX_HISTORY];

// The position after move i of the board's history.
fn after(b: board::Board&, i: i64) -> rules::Position { rules::record_after(b.rec, i, b.pos) }

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
// stands, drops the rest, and adds the moves played since, unjudged. Returns whether
// they changed.
fn sync_notes(gm: Game&) -> bool {
    let b .= gm.b;
    let ns .= gm.notes;
    var changed = false;
    // The history full and its oldest step dropped: the notes shift with it.
    if ns.len > 1 && b.rec.history.len > 0 && !rules::same(ns[0].before, b.rec.history[0].pos)
       && rules::same(ns[1].before, b.rec.history[0].pos) {
        for k in ns.len - 1 { ns[k] = ns[k + 1]; }
        ns.pop();
        gm.notes_from += 1;
        changed = true;
    }
    var k = 0;
    while k < ns.len && k < b.rec.history.len && rules::same(ns[k].before, b.rec.history[k].pos) {
        let played = rules::play(ns[k].before, ns[k].move);
        let next = after(b, k);
        guard rules::same(played, next) else { break; }
        k += 1;
    }
    if k < ns.len { changed = true; }
    while ns.len > k { ns.pop(); }
    if b.rec.history.len == 0 { gm.notes_from = 0; }
    for i in k..b.rec.history.len {
        let m, ok = move_between(b.rec.history[i].pos, after(b, i), gm.scratch);
        guard ok else { break; }
        ns.push(Note { before: b.rec.history[i].pos, move: m, .. });
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
    if b.rec.history.len != gm.notes_len || !rules::same(b.pos, gm.notes_pos) {
        changed = sync_notes(gm);
        gm.notes_len = b.rec.history.len;
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
    var past = rules::Past { draw: rules::Draw {}, before: [] };
    rules::record_past_to(gm.b.rec, i, gm.b.pos, past);
    return Ask { id: gm.judging, pos: gm.notes[i].before, past: past, skill: ai::JUDGE_SKILL, seed: 0, kind: JUDGE,
                 move: gm.notes[i].move };
}

// The worker's verdict on the ask `id`: the note's mark, and the best move where there
// was a choice. One for an ask no longer open is ignored. True when a mark was set.
fn judged(gm: Game&, id: i64, mark: i64, loss: i64, best: rules::Move, has_best: bool) -> bool {
    guard id != 0 && id == gm.judging else { return false; }
    gm.judging = 0;
    guard gm.judge_ply < gm.notes.len else { return false; }
    let n .= gm.notes[gm.judge_ply];
    n.mark = mark as u8;
    n.loss = clamp(loss, 0, 1000) as i16;
    n.best = best;
    n.has_best = has_best;
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

// The moves panel: numbered rows, white's and black's move side by side, the latest lit,
// each followed by its mark where marks show.
let MOVES_FADE = 40.0;      // dp at the list's top and foot over which rows past them fade
let MOVES_LIST = gui::PANEL_IDS + 16;  // the list's id (gui::scroll_begin)
let MOVES_NUMBER = 32.0;    // dp the moves' numbers take ("19." in the small face, 22)
let MARK_GAP = 4.0;         // dp between a move and its mark
let ORANGE = float4 { 1.0, 0.62, 0.25, 1.0 };

type Line = gui::Text;

fn push_square(out: Line&, v: rules::Variant&, b: i64) {
    if v.algebraic {
        out.push('a' + v.x_of[b]);
        gui::push_number(out, v.y_of[b] as i64 + 1);
    } else {
        gui::push_number(out, v.number_of[b]);
    }
}

// A move as the panel shows it: from and to, a capture's stops left out ("28x19",
// "c3:e5").
fn notation(out: Line&, v: rules::Variant&, m: rules::Move) {
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

// Whether a mark shows after its move: a good or only move, or one not judged, has none.
fn shows_mark(mark: u8) -> bool {
    return mark == ai::BEST || mark == ai::INACCURACY || mark == ai::MISTAKE || mark == ai::BLUNDER;
}

// A move's mark in row r from x at opacity a: the best's star, the others as text in
// `face`, the star scaled by `k`. Returns its width (mark_width), 0 for none.
let MARK_STAR = 16.0;
fn mark_at(g: gui::Gui&, x: f32, r: float4, mark: u8, a: f32 = 1.0, face: i64 = gui::BODY, k: f32 = 1.0) -> f32 {
    let u = g.scale;
    if mark == ai::BEST {
        let s = MARK_STAR * k * u;
        gui::glyph_icon(g, float4 { x, r.y + 0.5 * (r.w - s), s, s }, gui::STAR, gui::PLAIN, 0.0, 0.9 * a);
        return s;
    }
    let t, c = mark_text(mark);
    guard t.len > 0 else { return 0.0; }
    gui::colored(g, face, float4 { x, r.y, r.z, r.w }, t, float4 { c.x, c.y, c.z, c.w * a }, gui::LEFT);
    return gui::text_width(g, face, t);
}

// How wide mark_at draws a mark, 0 for none.
fn mark_width(g: gui::Gui&, mark: u8, face: i64 = gui::BODY, k: f32 = 1.0) -> f32 {
    if mark == ai::BEST { return MARK_STAR * k * g.scale; }
    let t, c = mark_text(mark);
    return if t.len > 0 { gui::text_width(g, face, t) } else { 0.0 };
}

// Note 0's ply in the whole game, white's first move 0: the plies before the game's start
// (Game.ply0), those the history dropped, and one for a set-up game with black to move.
fn first_ply(gm: Game&) -> i64 {
    let black: i64 = if gm.ply0 == 0 && gm.b.rec.start.side == rules::BLACK { 1 } else { 0 };
    return gm.ply0 + gm.notes_from + black;
}

// The number of note i's row, and whether the move is black's half of it.
fn row_of(gm: Game&, i: i64) -> i64, bool {
    let a = first_ply(gm) + i;
    return a / 2 + 1, a % 2 == 1;
}

// The panel in l.moves, if there is room and the setting shows it: a head, with the
// taken counts at its right when l.counts, over the list. The glass grows with its rows
// up to l.moves, then scrolls.
fn moves_panel(gm: Game&, g: gui::Gui&, l: panel::Layout, over: board::Overlay&) {
    guard gm.moves_shown != 0 && l.moves.z > 0.0 && l.moves.w > 0.0 else { return; }
    let u = g.scale;
    let rows = max(1, (gm.notes.len + first_ply(gm) % 2 + 1) / 2);
    let tall = (panel::MOVES_PAD + panel::LINE_HEAD + rows * panel::MOVES_ROW + 2.0 * panel::MOVES_PAD) * u;
    let box = float4 { l.moves.x, l.moves.y, l.moves.z, min(l.moves.w, tall) };
    gui::panel(g, box);
    var room = box;
    let head = gui::cut_top(room, (panel::MOVES_PAD + panel::LINE_HEAD) * u);
    let words = float4 { head.x + panel::MOVES_PAD * u, head.y + panel::MOVES_PAD * u, head.z - 2.0 * panel::MOVES_PAD * u, panel::LINE_HEAD * u };
    let word = strings::get(strings::SETTINGS_MOVES);
    gui::text(g, gui::fitting(g, gui::SMALL, word, words.z), words, word, 0.7, 0.0, gui::LEFT);
    gui::fill(g, float4 { words.x, words.y + words.w - 2.0 * u, words.z, max(1.0, u) }, float4 { 1.0, 1.0, 1.0, 0.12 }, 0.0);
    if l.counts {
        let d = 18.0 * u;
        let row = float4 { words.x, words.y, words.z, words.w - 2.0 * u };
        let w = panel::count_at(g, over, gm.taken, rules::WHITE, row, d, true);
        panel::count_at(g, over, gm.taken, rules::BLACK, float4 { row.x, row.y, row.z - w - 14.0 * u, row.w }, d, true);
    }
    moves_list(gm, g, room, MOVES_LIST, true);
}

// The moves as rows in r, a list scrolled within it (`id`), scrolled to the latest when
// a move is added or the list is shown again. With `record`, the marked moves' rects go to
// gm.marks_at for their tips. Before the first move it says there are none.
fn moves_list(gm: Game&, g: gui::Gui&, r: float4, id: i64, record: bool) {
    let u = g.scale;
    let ns .= gm.notes;
    guard ns.len > 0 else {
        let inner = gui::inset(r, panel::MOVES_PAD * u);
        gui::text(g, gui::BODY, float4 { inner.x, inner.y, inner.z, panel::MOVES_ROW * u }, strings::get(strings::MOVES_NONE),
                  0.55, 0.0, gui::CENTER);
        return;
    }
    let v .= rules::VARIANTS[gm.b.variant];
    let marks = gm.moves_shown == 2;
    // Black first leaves white's half of row one empty.
    let off = first_ply(gm) % 2;
    let first_number = first_ply(gm) / 2 + 1;
    let rows = (ns.len + off + 1) / 2;
    let inner = gui::inset(r, panel::MOVES_PAD * u);
    let half = 0.5 * (inner.z - MOVES_NUMBER * u);
    let view = float4 { r.x, r.y + 4.0 * u, r.z, r.w - 8.0 * u };
    let content = rows * panel::MOVES_ROW * u + 2.0 * (panel::MOVES_PAD - 4.0) * u;
    if g.scroll.id != id || gm.moves_seen != ns.len {
        gui::scroll_set(g, id, content);
        gm.moves_seen = ns.len;
    }
    let scrolled = gui::scroll_begin(g, id, view, content);
    let listed = g.quads.len;
    var line: Line = [];
    for row in 0..rows {
        let y = inner.y - scrolled + row * panel::MOVES_ROW * u;
        guard y + panel::MOVES_ROW * u > view.y && y < view.y + view.w else { continue; }
        line.clear();
        gui::push_number(line, first_number + row);
        line.push('.');
        gui::text(g, gui::SMALL, float4 { inner.x, y, MOVES_NUMBER * u, panel::MOVES_ROW * u }, line[..], 0.55, 0.0, gui::LEFT);
        for side in 2 {
            let i = 2 * row + side - off;
            guard i >= 0 && i < ns.len else { continue; }
            let n .= ns[i];
            let cell = float4 { inner.x + MOVES_NUMBER * u + side * half, y, half, panel::MOVES_ROW * u };
            notation(line, v, n.move);
            let w = gui::text_width(g, gui::BODY, line[..]);
            if i == ns.len - 1 {
                gui::glow_fill(g, float4 { cell.x - 6.0 * u, cell.y + 3.0 * u, w + 12.0 * u, cell.w - 6.0 * u }, 0.22, 8.0 * u);
            }
            gui::text(g, gui::BODY, cell, line[..], 1.0, 0.0, gui::LEFT);
            guard marks else { continue; }
            let mw = mark_at(g, cell.x + w + MARK_GAP * u, cell, n.mark);
            // The whole move, words and mark, is its tip's touch, clipped to the view.
            let mid = y + 0.5 * panel::MOVES_ROW * u;
            if record && mw > 0.0 && mid > view.y && mid < view.y + view.w && gm.marks_at.len < MAX_MARKS_AT {
                let top = max(y, view.y);
                let bottom = min(y + panel::MOVES_ROW * u, view.y + view.w);
                gm.marks_at.push(MarkAt { rect: float4 { cell.x - 6.0 * u, top, w + (MARK_GAP + 12.0) * u + mw, bottom - top },
                                          ply: i });
            }
        }
    }
    gui::fade_edges(g, listed, view, scrolled, content - scrolled - view.w, MOVES_FADE * u);
    gui::scroll_end(g);
}
