// The puzzles to pick from (prototypes/puzzles.html, take a; docs/architecture/puzzles.md,
// "The screen"): a library of the themes, and a theme's page.
//
// The library is back and a glass row per theme: its mark (the theme's icon on a disc in
// the glow color), its name, "n / total" solved, and a bar; under the title in portrait
// and where the height allows in landscape. Learn is open; the other themes open once
// half of Learn is solved, and until then each shows its mark plain with a lock and how
// many more Learn wants. The rows are one column, or two in landscape where one doesn't
// fit the height. A row opens the theme's page: back, the theme's mark, name, and count
// over its levels, each a glass row of the level's mark and name beside its tiles, or
// over them where the two don't fit side by side; a level's tiles split into rows as even
// as they go. Each tile shows the stars won, the first without stars lit. Every tap is
// 88 dp at least. The sharp photograph shows behind it, and no board.
namespace picker;
import std;
import vec;

import gui from "../gui";
import strings from "../strings";
import puzzles from "../puzzles";

// What the screen asks for: these, or the index in puzzles::all of a puzzle tapped.
let BACK = -2;              // home
let NOTHING = -1;
let SHOWN = -3;             // a theme's page opened or left: drawn again

let MARKS = [gui::BOOK, gui::JUMPS, gui::CROWN, gui::TARGET, gui::KING];
let NAMES = [strings::THEME_LEARN, strings::THEME_CAPTURES, strings::THEME_CROWNING, strings::THEME_SHOTS,
             strings::THEME_KING_SHOTS];
let LEVEL_NAMES = [strings::PUZZLES_LEVEL1, strings::PUZZLES_LEVEL2, strings::PUZZLES_LEVEL3];
let COLUMN = 600.0;         // dp a column of the library takes at most
let PHONE = 600.0;          // dp across the shorter side under which the layout is a phone's

// How many of a theme's puzzles have stars.
fn solved(stars: const u8[:], theme: i64) -> i64 {
    var n = 0;
    for p in puzzles::all.list { if p.theme == theme && stars[p.id] > 0 { n++; } }
    return n;
}

// How many more of Learn's puzzles open the other themes, 0 once they are open.
fn to_open(stars: const u8[:]) -> i64 {
    let half = (puzzles::theme_count(puzzles::all, puzzles::LEARN) + 1) / 2;
    return max(0, half - solved(stars, puzzles::LEARN));
}

// Whether a theme is open: Learn always, the others once half of Learn is solved.
fn open(stars: const u8[:], theme: i64) -> bool { theme == puzzles::LEARN || to_open(stars) == 0 }

// The first puzzle of a theme without stars, as its index in puzzles::all, or -1.
fn first_open(stars: const u8[:], theme: i64) -> i64 {
    for p, i in puzzles::all.list { if p.theme == theme && stars[p.id] == 0 { return i; } }
    return -1;
}

// The stars won and those there are, for home's note.
fn totals(stars: const u8[:]) -> i64, i64 {
    var won = 0;
    for p in puzzles::all.list { won += stars[p.id]; }
    return won, 3 * puzzles::all.list.len;
}

// How many puzzles a theme's level has, and the index in puzzles::all of its k-th.
fn level_count(theme: i64, level: i64) -> i64 {
    var n = 0;
    for p in puzzles::all.list { if p.theme == theme && p.level == level { n++; } }
    return n;
}
fn level_nth(theme: i64, level: i64, k: i64) -> i64 {
    var n = 0;
    for p, i in puzzles::all.list {
        guard p.theme == theme && p.level == level else { continue; }
        if n == k { return i; }
        n++;
    }
    return -1;
}

fn line_h(g: gui::Gui&, face: i64) -> f32 { g.faces[face].ascent - g.faces[face].descent }

// Declares the screen in `area`, the screen's safe area, with the stars won so far:
// the library while `theme` is -1, else that theme's page. Sets `spot` to the tile of the
// puzzle tapped, or else of puzzle `at` (an index in puzzles::all, or -1 for none), which
// a puzzle's board grows out of and shrinks back into. Returns BACK, SHOWN (having set
// `theme`), the index in puzzles::all of a puzzle tapped, or NOTHING.
fn frame(g: gui::Gui&, area: float4, stars: const u8[:], at: i64, theme: i64&, spot: float4&) -> i64 {
    if theme < 0 { return library(g, area, stars, at, theme, spot); }
    return page(g, area, stars, at, theme, spot);
}

// Back, a glass tile in r.
fn back(g: gui::Gui&, r: float4) -> bool {
    gui::glass(g, r, 22.0);
    return gui::button(g, 500, r, gui::BACK);
}

// A theme's mark, a disc `size` dp across centered in r: its icon on the glow color at
// 20%, or plain at 6% with a lock badge while the theme is shut.
fn mark(g: gui::Gui&, r: float4, theme: i64, size: f32, opened: bool) {
    let u = g.scale;
    let m = size * u;
    let disc = gui::center(r, m, m);
    if opened { gui::glow_fill(g, disc, 0.2, 0.5 * m); }
    else { gui::fill(g, disc, float4 { 1.0, 1.0, 1.0, 0.06 }, 0.5 * m); }
    let s = 0.57 * m;
    gui::glyph_icon(g, gui::center(disc, s, s), MARKS[theme], gui::PLAIN, 0.0, if opened { 1.0 } else { 0.45 });
    guard !opened else { return; }
    let b = 30.0 * u;
    let badge = float4 { disc.x + disc.z + 4.0 * u - b, disc.y + disc.w + 4.0 * u - b, b, b };
    gui::fill(g, badge, float4 { 1.0, 1.0, 1.0, 0.25 }, 0.5 * b);
    gui::glyph_icon(g, gui::center(badge, 18.0 * u, 18.0 * u), gui::LOCK, gui::PLAIN, 0.0, 1.0);
}

// "n / total" of a theme, into out.
fn count_of(stars: const u8[:], theme: i64, out: u8[..64]&) {
    strings::fill_in(out, strings::PUZZLES_STARS, [solved(stars, theme), puzzles::theme_count(puzzles::all, theme)]);
}

// A theme's row in the library: its mark, name, count, and bar, or for a shut theme how
// many more Learn wants. True when tapped while open.
fn theme_row(g: gui::Gui&, r: float4, theme: i64, stars: const u8[:], phone: bool) -> bool {
    let u = g.scale;
    let opened = open(stars, theme);
    // A glass card as a level's on a theme's page, lit only while pressed: a plain tile
    // (white at 10%) barely shows over the sharp photograph.
    gui::glass(g, r, 22.0);
    let tapped = gui::tile(g, 600 + theme, r, gui::NO_ICON, gui::ROW, 22.0);
    var c = r;
    gui::cut_left(c, (if phone { 12.0 } else { 20.0 }) * u);
    gui::cut_right(c, (if phone { 18.0 } else { 26.0 }) * u);
    let size: f32 = if phone { 64.0 } else { 88.0 };
    mark(g, gui::cut_left(c, size * u), theme, size, opened);
    gui::cut_left(c, (if phone { 18.0 } else { 22.0 }) * u);
    let name_h = line_h(g, gui::LABEL);
    let under = if opened { 8.0 * u } else { line_h(g, gui::SMALL) };
    let tall = name_h + 10.0 * u + under;
    var b = float4 { c.x, c.y + 0.5 * (c.w - tall), c.z, tall };
    var top = gui::cut_top(b, name_h);
    gui::cut_top(b, 10.0 * u);
    let name = strings::get(NAMES[theme]);
    if opened {
        var n: u8[..64] = [];
        count_of(stars, theme, n);
        let w = gui::text_width(g, gui::BODY, n[..]);
        gui::text(g, gui::BODY, gui::cut_right(top, w), n[..], 0.66, 0.0, gui::RIGHT);
        gui::cut_right(top, 12.0 * u);
        let bar = gui::cut_top(b, 8.0 * u);
        gui::fill(g, bar, float4 { 1.0, 1.0, 1.0, 0.14 }, 4.0 * u);
        let all = puzzles::theme_count(puzzles::all, theme);
        let k = (solved(stars, theme) as f32) / max(1, all);
        if k > 0.0 { gui::glow_fill(g, float4 { bar.x, bar.y, bar.z * k, bar.w }, 1.0, 4.0 * u); }
    } else {
        var more: u8[..64] = [];
        strings::fill_in(more, strings::PUZZLES_LOCKED, [to_open(stars)]);
        gui::text(g, gui::fitting(g, gui::SMALL, more[..], b.z), b, more[..], 0.66, 0.0, gui::LEFT);
    }
    gui::text(g, gui::fitting(g, gui::LABEL, name, top.z), top, name, if opened { 1.0 } else { 0.66 }, 0.0,
              gui::LEFT);
    return tapped && opened;
}

// The library: back, the title, and a row per theme the set has.
fn library(g: gui::Gui&, area: float4, stars: const u8[:], at: i64, theme: i64&, spot: float4&) -> i64 {
    let u = g.scale;
    let landscape = area.z >= area.w;
    let phone = min(area.z, area.w) < PHONE * u;
    let short = landscape && area.w < PHONE * u;
    var page = gui::inset(area, (if phone { 16.0 } else { 24.0 }) * u);
    var pick = NOTHING;
    let title = strings::get(strings::HOME_PUZZLES);
    let whole = page;           // the rows center on the screen, not on what back leaves
    if landscape {
        var column = gui::cut_left(page, 88.0 * u);
        if back(g, gui::cut_top(column, 88.0 * u)) { pick = BACK; }
        gui::cut_left(page, 24.0 * u);
    }
    let gap = 12.0 * u;
    let row_h = (if phone { 96.0 } else { 124.0 }) * u;
    // A variant's set may leave a theme out (Russian's has no king shots): its row too.
    var rows = 0;
    for t in puzzles::THEMES { if puzzles::theme_count(puzzles::all, t) > 0 { rows++; } }
    let one = rows * row_h + (rows - 1) * gap;
    let head = if short { 0.0 } else { 88.0 * u + gap };
    let cols = if landscape && head + one > page.w { 2 } else { 1 };
    let per = (rows + cols - 1) / cols;
    let col_w = min((page.z - (cols - 1) * gap) / cols, COLUMN * u);
    let w = cols * col_w + (cols - 1) * gap;
    let h = head + per * row_h + (per - 1) * gap;
    let x = max(page.x, whole.x + floor(0.5 * (whole.z - w) + 0.5));
    let y = if landscape { page.y + max(0.0, floor(0.5 * (page.w - h) + 0.5)) } else { page.y };
    if !short {
        var top = float4 { x, y, w, 88.0 * u };
        if !landscape {
            if back(g, gui::cut_left(top, 88.0 * u)) { pick = BACK; }
            gui::cut_left(top, 20.0 * u);
        }
        gui::text(g, gui::fitting(g, gui::LABEL, title, top.z), top, title, 1.0, 0.0, gui::LEFT);
    }
    var k = 0;
    for t in puzzles::THEMES {
        guard puzzles::theme_count(puzzles::all, t) > 0 else { continue; }
        let r = float4 { x + (k / per) * (col_w + gap), y + head + (k % per) * (row_h + gap), col_w, row_h };
        k++;
        if at >= 0 && puzzles::all.list[at].theme == t { spot = float4 { r.x, r.y, r.w, r.w }; }
        if theme_row(g, r, t, stars, phone) {
            theme = t;
            pick = SHOWN;
        }
    }
    return pick;
}

// One puzzle's tile: its stars, lit if it is the first without them. True when tapped.
fn tile(g: gui::Gui&, i: i64, r: float4, won: i64, lit: bool) -> bool {
    let u = g.scale;
    let tapped, pic = gui::pick(g, 1000 + i, r, 0.0, "", "", lit, true);
    let star: f32 = 20.0;
    for k in 3 {
        let cell = gui::cell(r, 3, 1, star * u, star * u, 2.0 * u, k);
        if k < won { gui::glyph_icon(g, cell, gui::STAR, gui::ON, 0.0, 1.0); }
        else { gui::glyph_icon(g, cell, gui::STAR_OFF, gui::PLAIN, 0.0, 0.28); }
    }
    return tapped;
}

// How many tiles `side` across, `gap` apart, fit a row in a level `w` wide, its padding
// `margin` and its label `label` wide beside them taken off.
fn fit_of(w: f32, margin: f32, label: f32, side: f32, gap: f32) -> i64 { floor((w - 2.0 * margin - label + gap) / (side + gap)) as i64 }

// A theme's levels laid out `fit` tiles to a row at most, each level's rows as even as
// they go: their height with `between` before each and `above` over each level's tiles
// (its label), and the widest level's tiles.
fn levels_h(t: i64, fit: i64, side: f32, gap: f32, margin: f32, above: f32, between: f32) -> f32, f32 {
    var h:      f32 = 0.0;
    var widest: f32 = 0.0;
    for l in puzzles::LEVELS {
        let n = level_count(t, l + 1);
        guard n > 0 else { continue; }
        let rows = (n + fit - 1) / fit;
        let per = (n + rows - 1) / rows;
        widest = max(widest, per * side + (per - 1) * gap);
        h += between + rows * side + (rows - 1) * gap + 2.0 * margin + above;
    }
    return h, widest;
}

// A theme's page: back, the theme's head (its mark, name, and count), and its levels,
// each its label (the level's mark and name) beside its tiles, or over them where four
// tiles don't fit beside it. Where that leaves the page taller than the screen (a phone
// with its insets), in landscape the mark and count stand under back in place of the
// head, and in portrait each level's label is its mark alone beside its tiles, spaced as
// on a phone in landscape.
fn page(g: gui::Gui&, area: float4, stars: const u8[:], at: i64, theme: i64&, spot: float4&) -> i64 {
    let u = g.scale;
    let t = theme;
    let landscape = area.z >= area.w;
    let phone = min(area.z, area.w) < PHONE * u;
    let short = landscape && area.w < PHONE * u;
    var room = gui::inset(area, (if phone { 16.0 } else { 24.0 }) * u);
    var pick = NOTHING;
    var column = room;
    if landscape {
        column = gui::cut_left(room, 88.0 * u);
        if back(g, gui::cut_top(column, 88.0 * u)) { pick = SHOWN; }
        gui::cut_left(room, 24.0 * u);
    }
    let side = (if phone { 88.0 } else { 96.0 }) * u;
    var gap = (if short { 8.0 } else { 10.0 }) * u;
    var pad_x = (if short { 12.0 } else { 16.0 }) * u;
    var pad_y = (if short { 4.0 } else { 14.0 }) * u;
    var between = (if short { 6.0 } else { 14.0 }) * u;
    let head_h = (if !landscape { 88.0 } else if short { 52.0 } else { 72.0 }) * u;
    let label_h = 30.0 * u;
    let words = (if short { 96.0 } else { 120.0 }) * u;
    var label = words + 14.0 * u;       // the label beside the tiles, and its gap
    var above: f32 = 0.0;               // or over them
    var fit = fit_of(room.z, pad_x, label, side, gap);
    if fit < 4 {
        label = 0.0;
        above = label_h + 8.0 * u;
        fit = fit_of(room.z, pad_x, label, side, gap);
    }
    var lv, widest = levels_h(t, fit, side, gap, pad_y, above, between);
    let tall = head_h + lv > room.w;
    let in_column = tall && landscape;
    let icon_only = tall && !landscape && above > 0.0;
    if icon_only {
        label = 30.0 * u + 10.0 * u;
        above = 0.0;
        gap = 8.0 * u;
        pad_x = 12.0 * u;
        pad_y = 4.0 * u;
        between = 6.0 * u;
        fit = fit_of(room.z, pad_x, label, side, gap);
        lv, widest = levels_h(t, fit, side, gap, pad_y, above, between);
    }
    let h = if in_column { lv - between } else { head_h + lv };
    let w = if above > 0.0 { room.z } else { min(room.z, widest + 2.0 * pad_x + label) };
    let x = room.x + floor(0.5 * (room.z - w) + 0.5);
    var y = if landscape { room.y + max(0.0, floor(0.5 * (room.w - h) + 0.5)) } else { room.y };
    var n: u8[..64] = [];
    count_of(stars, t, n);
    if in_column {
        // The mark and the count under back.
        gui::cut_top(column, 12.0 * u);
        mark(g, gui::cut_top(column, 52.0 * u), t, 52.0, true);
        gui::cut_top(column, 6.0 * u);
        gui::text(g, gui::SMALL, gui::cut_top(column, line_h(g, gui::SMALL)), n[..], 0.66, 0.0, gui::CENTER);
        y -= between;
    } else {
        // The head: back in portrait, the mark, the name, and the count.
        var head = float4 { x, y, w, head_h };
        y += head_h;
        if !landscape {
            if back(g, gui::cut_left(head, 88.0 * u)) { pick = SHOWN; }
            gui::cut_left(head, 16.0 * u);
        }
        let m: f32 = if short { 52.0 } else if landscape { 60.0 } else { 64.0 };
        mark(g, gui::cut_left(head, m * u), t, m, true);
        gui::cut_left(head, 16.0 * u);
        let count_w = gui::text_width(g, gui::BODY, n[..]);
        gui::text(g, gui::BODY, gui::cut_right(head, count_w + 8.0 * u), n[..], 0.66, 0.0, gui::LEFT);
        gui::cut_right(head, 12.0 * u);
        let name = strings::get(NAMES[t]);
        gui::text(g, gui::fitting(g, gui::LABEL, name, head.z), head, name, 1.0, 0.0, gui::LEFT);
    }
    let lit = first_open(stars, t);
    for l in puzzles::LEVELS {
        let count = level_count(t, l + 1);
        guard count > 0 else { continue; }
        let rows = (count + fit - 1) / fit;
        let per = (count + rows - 1) / rows;
        y += between;
        let lh = rows * side + (rows - 1) * gap + 2.0 * pad_y + above;
        let level = float4 { x, y, w, lh };
        y += lh;
        gui::glass(g, level, 22.0);
        var c = level;
        gui::cut_left(c, pad_x);
        gui::cut_right(c, pad_x);
        gui::cut_top(c, pad_y);
        gui::cut_bottom(c, pad_y);
        let word = strings::get(LEVEL_NAMES[l]);
        if above > 0.0 {
            var top = gui::cut_top(c, label_h);
            gui::cut_top(c, 8.0 * u);
            gui::glyph_icon(g, gui::center(gui::cut_left(top, 30.0 * u), 30.0 * u, 30.0 * u), gui::LEVEL + l, gui::PLAIN,
                            0.0, 1.0);
            gui::cut_left(top, 10.0 * u);
            gui::text(g, gui::SMALL, top, word, 0.66, 0.0, gui::LEFT);
        } else if icon_only {
            let mark_r = gui::cut_left(c, 30.0 * u);
            gui::cut_left(c, 10.0 * u);
            gui::glyph_icon(g, gui::center(mark_r, 30.0 * u, 30.0 * u), gui::LEVEL + l, gui::PLAIN, 0.0, 1.0);
        } else {
            let r = gui::cut_left(c, words);
            gui::cut_left(c, 14.0 * u);
            let s = 40.0 * u;
            var mid = gui::center(r, r.z, s + 4.0 * u + line_h(g, gui::SMALL));
            gui::glyph_icon(g, gui::center(gui::cut_top(mid, s), s, s), gui::LEVEL + l, gui::PLAIN, 0.0, 1.0);
            gui::cut_top(mid, 4.0 * u);
            gui::text(g, gui::fitting(g, gui::SMALL, word, r.z), mid, word, 0.66, 0.0, gui::CENTER);
        }
        // The tiles from the left, or centered where the level stands over them; a short
        // last row centered under the others.
        let start = if above > 0.0 { c.x + floor(0.5 * (c.z - (per * side + (per - 1) * gap)) + 0.5) } else { c.x };
        for k in count {
            let i = level_nth(t, l + 1, k);
            let row = k / per;
            let in_row = min(per, count - row * per);
            let left = start + 0.5 * (per - in_row) * (side + gap);
            let r = float4 { left + (k % per) * (side + gap), c.y + row * (side + gap), side, side };
            if i == at && pick == NOTHING { spot = r; }
            if tile(g, i, r, stars[puzzles::all.list[i].id], i == lit) {
                pick = i;
                spot = r;
            }
        }
    }
    if pick == SHOWN { theme = -1; }
    return pick;
}
