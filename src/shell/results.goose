// The games played (task 074, prototypes/history.html's games view): the playing
// player's rating in a draughts, their wins, draws, and losses against each of the
// computer's levels, the moves panel's setting, and their games in that draughts, newest
// first, in a scrolling list. Back and the title head it, the draughts as tiles at the
// head's right, each with its rating. In landscape the rating and the setting stand in a
// panel at the left and the games at the right; in portrait the panel is above the
// games. Reached from who's playing (who.goose's results tile). Everything is read off the
// history the shell read when the screen opened (record.goose); nothing allocates.
namespace results;
import std;
import vec;

let NOTHING = gui::ASK_NOTHING;
let BACK = gui::ASK_BACK;
let CHANGED = gui::ASK_CHANGED;     // the moves panel's setting
let SHOWN = gui::ASK_SHOWN;         // another draughts shown

let EDGE = 24.0;            // dp from the safe area's edges
let GAP = 16.0;             // between the head and the panels, and between the panels
let IN = 20.0;              // inside a panel
let SIDE = 380.0;           // the left panel's width in landscape at most
let BIG = 52.0;             // the rating's line: its figures in the clock's face (gui::FIGURES)
let LEVEL_ROW = 40.0;
let ROW = 88.0;             // a game's row
let ROW_GAP = 8.0;
let HEAD = 24.0;            // a heading's line in the small face
let ICON = 40.0;            // a game's result

let BACK_ID = gui::RESULTS_IDS;
let DRAUGHTS_ID = gui::RESULTS_IDS + 1;   // the three draughts' tiles
let MOVES_ID = gui::RESULTS_IDS + 5;      // the moves panel's three
let LIST = gui::RESULTS_IDS + 10;         // the games' scrolling list

type Text = u8[..64];

fn push_number(t: Text&, n: i64) {
    if n < 0 { t.push('-'); }
    var digits: u8[..20] = [];
    var k = abs(n);
    loop {
        digits.push(('0' + k % 10) as u8);
        k /= 10;
        guard k > 0 else { break; }
    }
    var i = digits.len - 1;
    while i >= 0 {
        t.push(digits[i]);
        i -= 1;
    }
}

fn push_two(t: Text&, n: i64) {
    if n < 10 { t.push('0'); }
    push_number(t, n);
}

fn push(t: Text&, s: const u8[:]) { for c in s { if t.len < 64 { t.push(c); } } }

// The draughts' tile i shows: International, Brazilian, Russian (settings' order).
fn variant_of(i: i64) -> i64 { settings::DRAUGHTS[i] }

// The screen for the player's settings s and games gs, showing draughts `variant` (one of
// settings::DRAUGHTS), which a tile changes. Returns what it asks for.
fn frame(g: gui::Gui&, area: float4, s: settings::Settings&, gs: history::Game[..history::MAX_GAMES]&,
         variant: i64&) -> i64 {
    let u = g.scale;
    var ask = NOTHING;
    var c = gui::inset(area, EDGE * u);
    var head = gui::cut_top(c, gui::tap() * u);
    gui::cut_top(c, GAP * u);
    let back = strings::get(strings::NAV_BACK);
    if gui::back(g, BACK_ID, gui::cut_left(head, gui::back_width(g, back)), back) { ask = BACK; }
    // The draughts at the head's right, each its name and rating, as wide as its words;
    // where they don't fit beside back (a phone in portrait), a row of their own under the
    // head, sharing its width.
    var t:      Text   = [];
    var widths: f32[3] = [0.0; 3];
    var all:    f32    = 0.0;
    for i in 3 {
        let name = strings::get(settings::DRAUGHTS_KEYS[i]);
        widths[i] = max(gui::tap() * u, gui::text_width(g, gui::BODY, name) + 2.0 * gui::side() * u);
        all += widths[i] + (if i > 0 { 10.0 * u } else { 0.0 });
    }
    let title_x = head.x + gui::back_width(g, back) + gui::PAD_WIDE * u;
    let own_row = title_x + all > head.x + head.z;
    var tiles: float4[3] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 3];
    var right = head.x + head.z;
    if own_row {
        let line = gui::cut_top(c, gui::tap() * u);
        gui::cut_top(c, GAP * u);
        let w = (line.z - 20.0 * u) / 3.0;
        for i in 3 { tiles[i] = float4 { line.x + i * (w + 10.0 * u), line.y, w, line.w }; }
    } else {
        for k in 3 {
            let i = 2 - k;
            tiles[i] = float4 { right - widths[i], head.y, widths[i], head.w };
            right -= widths[i] + 10.0 * u;
        }
    }
    let title = strings::get(strings::RESULTS_TITLE);
    let room = right - title_x;
    if gui::text_width(g, gui::LABEL, title) <= room {
        gui::text(g, gui::LABEL, float4 { title_x, head.y, room, head.w }, title, 1.0, 0.0, gui::LEFT);
    }
    for i in 3 {
        let v = variant_of(i);
        t.clear();
        push_number(t, s.rating[v]);
        let tapped, unused = gui::pick(g, DRAUGHTS_ID + i, tiles[i], 0.0, strings::get(settings::DRAUGHTS_KEYS[i]), t[..],
                                       variant == v, true);
        if tapped && variant != v {
            variant = v;
            ask = SHOWN;
        }
    }

    let wide = c.z > c.w;
    let levels = c.w >= 560.0 * u || !wide;
    let panel_h = panel_height(g, levels);
    var side = if wide { gui::cut_left(c, min(SIDE * u, 0.42 * c.z)) } else { gui::cut_top(c, min(panel_h, c.w - (2.0 * ROW + ROW_GAP + 24.0) * u)) };
    if wide { gui::cut_left(c, GAP * u); } else { gui::cut_top(c, GAP * u); }
    if wide { side.w = min(side.w, panel_h); }
    if rating_panel(g, side, s, gs, variant, levels) { ask = CHANGED; }
    list(g, c, gs, variant);
    return ask;
}

fn panel_height(g: gui::Gui&, levels: bool) -> f32 {
    let u = g.scale;
    var h = 2.0 * IN + HEAD + BIG + GAP + HEAD + gui::stacked();
    if levels { h += GAP + HEAD + 3.0 * LEVEL_ROW; }
    return h * u;
}

// The rating, the levels' results, and the moves panel's setting in r. True when the
// setting changed.
fn rating_panel(g: gui::Gui&, r: float4, s: settings::Settings&, gs: history::Game[..history::MAX_GAMES]&,
                variant: i64, levels: bool) -> bool {
    let u = g.scale;
    gui::panel(g, r);
    var c = gui::inset(r, IN * u);
    var t: Text = [];
    gui::text(g, gui::SMALL, gui::cut_top(c, HEAD * u), strings::get(strings::RESULTS_RATING), 0.66, 0.0, gui::LEFT);
    t.clear();
    push_number(t, s.rating[variant]);
    gui::figures(g, gui::FIGURES, gui::cut_top(c, BIG * u), t[..], 1.0, gui::PLAIN, gui::LEFT);
    let wide = c.z > c.w;
    if levels {
        gui::cut_top(c, GAP * u);
        gui::text(g, gui::SMALL, gui::cut_top(c, HEAD * u), strings::get(strings::RESULTS_COMPUTER), 0.66, 0.0, gui::LEFT);
        let tot = history::totals(gs);
        for level in 3 {
            var row = gui::cut_top(c, LEVEL_ROW * u);
            t.clear();
            push(t, strings::get(strings::PICK_EASY + level));
            push(t, " ");
            push_number(t, ai::skill_rating(s.skill[level]));
            gui::text(g, gui::BODY, row, t[..], 1.0, 0.0, gui::LEFT);
            // Won, drawn, lost, each a sign and a count, from the right.
            let base = (variant * 3 + level) * 3;
            let cell = 56.0 * u;
            for k in 3 {
                let at = float4 { row.x + row.z - (3 - k) * cell, row.y, cell, row.w };
                let icon = float4 { at.x, at.y + 0.5 * (at.w - 20.0 * u), 20.0 * u, 20.0 * u };
                if k == 0 { gui::glyph_icon(g, icon, gui::CROWN, gui::PLAIN, 0.0, 0.9); }
                if k == 1 { gui::text(g, gui::BODY, icon, "=", 0.8, 0.0, gui::CENTER); }
                if k == 2 { gui::glyph_icon(g, icon, gui::CLOSE, gui::PLAIN, 0.0, 0.6); }
                t.clear();
                push_number(t, tot.computer[base + k]);
                gui::text(g, gui::BODY, float4 { at.x + 24.0 * u, at.y, at.z - 24.0 * u, at.w }, t[..], 1.0, 0.0,
                          gui::LEFT);
            }
        }
    }
    gui::cut_top(c, GAP * u);
    gui::text(g, gui::SMALL, gui::cut_top(c, HEAD * u), strings::get(strings::SETTINGS_MOVES), 0.66, 0.0, gui::LEFT);
    let row = gui::cut_top(c, gui::stacked() * u);
    let keys = [strings::MOVES_HIDDEN, strings::MOVES_LIST, strings::MOVES_MARKS];
    let w = (row.z - 2.0 * 10.0 * u) / 3.0;
    var changed = false;
    for i in 3 {
        let tr = float4 { row.x + i * (w + 10.0 * u), row.y, w, row.w };
        let tapped, unused = gui::pick(g, MOVES_ID + i, tr, 0.0, strings::get(keys[i]), "", s.moves == i, true);
        if tapped && s.moves != i {
            s.moves = i;
            changed = true;
        }
    }
    return changed;
}

// The games of the draughts shown, newest first, in r: only the rows in view are
// declared.
fn list(g: gui::Gui&, r: float4, gs: history::Game[..history::MAX_GAMES]&, variant: i64) {
    let u = g.scale;
    gui::panel(g, r);
    let view = gui::inset(r, 12.0 * u);
    var n = 0;
    for &x in gs { if x.variant == variant { n += 1; } }
    if n == 0 {
        gui::text(g, gui::BODY, view, strings::get(strings::RESULTS_NONE), 0.66, 0.0, gui::CENTER);
        return;
    }
    let step = (ROW + ROW_GAP) * u;
    let off = gui::scroll_begin(g, LIST, view, n * step - ROW_GAP * u);
    let first = max((off / step) as i64, 0);
    let last = min(((off + view.w) / step) as i64 + 1, n);
    var k = 0;
    var i = gs.len - 1;
    while i >= 0 && k < last {
        let x .= gs[i];
        i -= 1;
        guard x.variant == variant else { continue; }
        if k >= first { row(g, float4 { view.x, view.y + k * step - off, view.z, ROW * u }, x); }
        k += 1;
    }
    gui::scroll_end(g);
}

// One game: its result as a sign (a crown won, = drawn, an X lost; against a friend the
// winner's piece colour is not shown, only whether the game was drawn), the opponent
// and the date, the rating's change, and the player's blunders.
fn row(g: gui::Gui&, r: float4, x: history::Game&) {
    let u = g.scale;
    gui::fill(g, r, float4 { 1.0, 1.0, 1.0, 0.06 }, 18.0 * u);
    var c = gui::inset(r, 16.0 * u);
    let res = if x.level == history::FRIEND { if x.winner == history::DRAW { 0 } else { 1 } } else { history::result(x) };
    let sign = gui::cut_left(c, ICON * u);
    let icon = gui::center(sign, ICON * u, ICON * u);
    if res > 0 { gui::glyph_icon(g, gui::inset(icon, 4.0 * u), gui::CROWN, gui::PLAIN, 0.0, 1.0); }
    if res == 0 { gui::text(g, gui::LABEL, icon, "=", 0.9, 0.0, gui::CENTER); }
    if res < 0 { gui::glyph_icon(g, gui::inset(icon, 8.0 * u), gui::CLOSE, gui::PLAIN, 0.0, 0.6); }
    gui::cut_left(c, 16.0 * u);
    var t: Text = [];
    // The player's blunders, at the right: ?? and a count.
    let side = if x.level == history::FRIEND { -1 } else { x.side };
    var blunders = 0;
    for s in 2 { if side < 0 || s == side { blunders += x.marks[s * ai::MARKS + ai::BLUNDER]; } }
    let marks = gui::cut_right(c, 64.0 * u);
    t.clear();
    push(t, "?? ");
    push_number(t, blunders);
    gui::colored(g, gui::SMALL, marks, t[..], float4 { gui::RED.x, gui::RED.y, gui::RED.z, if blunders > 0 { 1.0 } else { 0.35 } },
                 gui::RIGHT);
    // The rating's change.
    let change = gui::cut_right(c, 72.0 * u);
    if x.level != history::FRIEND {
        t.clear();
        let d = x.after - x.before;
        if d > 0 { t.push('+'); }
        push_number(t, d);
        gui::text(g, gui::BODY, change, t[..], 1.0, 0.0, gui::RIGHT);
    }
    // The opponent over the date.
    let body = g.faces[gui::BODY].ascent - g.faces[gui::BODY].descent;
    let small = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    var lines = gui::center(c, c.z, body + 4.0 * u + small);
    t.clear();
    if x.level == history::FRIEND {
        push(t, strings::get(strings::RESULTS_FRIEND));
    } else {
        push(t, strings::get(strings::PICK_EASY + x.level));
        push(t, " ");
        push_number(t, ai::skill_rating(x.skill));
    }
    gui::text(g, gui::BODY, gui::cut_top(lines, body), t[..], 1.0, 0.0, gui::LEFT);
    gui::cut_top(lines, 4.0 * u);
    let y, m, d = history::date(x.time);
    t.clear();
    push_number(t, y);
    t.push('-');
    push_two(t, m);
    t.push('-');
    push_two(t, d);
    gui::text(g, gui::SMALL, gui::cut_top(lines, small), t[..], 0.66, 0.0, gui::LEFT);
}
