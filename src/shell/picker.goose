// The puzzles to pick from (rendering.md, "Controls", Puzzle picker; docs/architecture/puzzles.md,
// "The screen"): a library of the themes, and a theme's page.
//
// The library is back, the title, the draughts switch (prototypes/puzzle-set.html, take
// a: settings' draughts, one setting), and a glass row per theme: its mark (the theme's
// icon on a disc in the glow color), its name, its stars ("★ n / total"), and a bar of
// them. The switch stands at the title row's right in landscape and in a row under the
// title in portrait; a draughts shown another's set (none now) says so under the title.
// Learn is open; the other themes open once
// half of Learn is solved, and until then each shows its mark plain with a lock and how
// many more Learn wants. The rows are two columns in landscape where two fit the width or
// one doesn't fit the height, else one column. A row opens the theme's page: back, the theme's mark, name, and count
// over its levels, each a glass row of the level's mark and name beside its tiles, or
// over them where the two don't fit side by side; a level's tiles split into rows as even
// as they go. Each tile shows the stars won, the first without stars lit. Every tap is
// a tap (gui::tap()) at least. Over the themes, across the columns, How to play (task 026,
// prototypes/tutorial.html entry b): its mark, its name, the steps played of the
// switch's draughts' tutorial, and a bar of them; it is never needed to open a theme. The sharp photograph shows behind it, and no board.
//
// The daily puzzles (task 087, prototypes/puzzles.html?daily=b): until Learn is solved,
// all of it, How to play heads the list and a locked Today row ends it, across the
// columns ("Solve n more in Learn"). Once it is, Today's row heads the list across the
// columns: its mark (a calendar, the moon once all are solved), "Today", a note ("n to
// go", or "New puzzles tomorrow"), and today's puzzles as tiles, beside them where they
// fit and under them where they don't, each its level's bars (the warm-up one, the middle
// two, the stretch three) over its stars, the first unsolved lit; a tile opens its
// puzzle. How to play is then a tile with its mark beside the title in landscape, and its
// row ends the list in portrait, where the title row has no room.
namespace picker;
import std;
import vec;

import gui from "../gui";
import strings from "../../strings";
import puzzles from "../puzzles";

// What the screen asks for: these, or the index in puzzles::all of a puzzle tapped, and
// so all negative, the shared asks (gui::ASK_NOTHING..) and its own.
let NOTHING = gui::ASK_NOTHING;
let BACK = gui::ASK_BACK;   // home
let SHOWN = gui::ASK_SHOWN; // a theme's page opened or left: drawn again
let SWITCHED = -10;         // other draughts chosen on the library's switch
let LEARN = -11;            // how to play, the library's first row (task 026)
let TODAY = -100;           // today's puzzle k tapped is TODAY - k (task 087), k under puzzles::MAX_DAILY
let TODAY_IDS = gui::PICKER_IDS + 30;          // today's tiles, one id each

let MARKS = [gui::BOOK, gui::JUMPS, gui::CROWN, gui::TARGET, gui::KING, gui::SHIELD];
let NAMES = [strings::THEME_LEARN, strings::THEME_CAPTURES, strings::THEME_CROWNING, strings::THEME_SHOTS,
             strings::THEME_KING_SHOTS, strings::THEME_SAFE_MOVE];
let LEVEL_NAMES = [strings::PUZZLES_LEVEL1, strings::PUZZLES_LEVEL2, strings::PUZZLES_LEVEL3];
let COLUMN = 600.0;         // dp a column of the library takes at most
let NARROWEST = 420.0;      // and at least where it goes to two in landscape for the width
let MARGIN = 24.0;          // dp round the library and a theme's page, and between back's column and the rest,
let MARGIN_PHONE = 16.0;    // round them on a phone
let LIBRARY_LIST = gui::PICKER_IDS + 100;     // the scrolling lists' ids (gui::scroll_begin): the library,
let PAGE_LIST = gui::PICKER_IDS + 110;        // and a theme's page, plus the theme

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

// How many of Learn's puzzles are still to solve before Today opens (task 087): all of
// Learn, the rules a daily puzzle may use; 0 once it is open. A set read with no Learn
// (none read yet) keeps it shut.
fn today_more(stars: const u8[:]) -> i64 { puzzles::theme_count(puzzles::all, puzzles::LEARN) - solved(stars, puzzles::LEARN) }
fn today_open(stars: const u8[:]) -> bool {
    return puzzles::theme_count(puzzles::all, puzzles::LEARN) > 0 && today_more(stars) <= 0;
}

// The puzzles of the set solved, any stars, and how many it has: home's note before Today
// opens.
fn solved_all(stars: const u8[:]) -> i64, i64 {
    var n = 0;
    for p in puzzles::all.list { if stars[p.id] > 0 { n++; } }
    return n, puzzles::all.list.len;
}

// The level of today's puzzle k of n, its bars: the warm-up 1, the middle ones 2, the
// stretch 3 (puzzles::target's shape).
fn slot_level(k: i64, n: i64) -> i64 { if k == 0 { 1 } else if k == n - 1 { 3 } else { 2 } }

// Today's dots (task 087): n of them `d` pixels across and `gap` apart, centered in r,
// those with stars in `won` filled in the glow, puzzle `ring` (or none, -1) ringed in it,
// the rest dim; home's note and over a daily puzzle's next. Smaller where r is narrower
// than they want (ten over a phone's next).
fn dots(g: gui::Gui&, r: float4, n: i64, won: const u8[:], ring: i64, size: f32, space: f32) {
    let k_fit = min(1.0, r.z / max(1.0, n * size + (n - 1) * space));
    let d = floor(size * k_fit + 0.5);
    let gap = space * k_fit;
    for k in n {
        let c = gui::cell(r, n, 1, d, d, gap, k);
        if won[k] > 0 { gui::glow_fill(g, c, 1.0, 0.5 * d); }
        else if k == ring {
            gui::add(g, gui::Quad { rect: c, look: float4 { gui::RING, 0.5 * d, 1.0, 3.0 }, extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
        }
        else { gui::fill(g, c, float4 { 1.0, 1.0, 1.0, 0.3 }, 0.5 * d); }
    }
}

// How many of today's puzzles are solved.
fn today_solved(t: settings::Today&) -> i64 {
    var n = 0;
    for k in t.picked.list.len { if t.stars[k] > 0 { n++; } }
    return n;
}

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
// `theme`), SWITCHED (having set `variant`, the player's draughts, from the library's
// switch), the index in puzzles::all of a puzzle tapped, or NOTHING.
//
// With `today`, the player's daily puzzles in the set (task 087), and `today_at` the one
// playing (its place in them, or -1), whose tile the board grows out of: a tap on one
// returns TODAY - its place.
fn frame(g: gui::Gui&, area: float4, stars: const u8[:], at: i64, theme: i64&, spot: float4&, variant: i64&,
         learned: i64, steps: i64, today: settings::Today&, today_at: i64) -> i64 {
    if theme < 0 { return library(g, area, stars, at, theme, spot, variant, learned, steps, today, today_at); }
    return page(g, area, stars, at, theme, spot);
}

// Back (gui::back) in r: the arrow and "Back" on a glass tile, side by side or, `stacked`,
// one over the other.
fn back(g: gui::Gui&, r: float4, stacked: bool = false) -> bool {
    return gui::back(g, gui::PICKER_IDS, r, strings::get(strings::NAV_BACK), stacked);
}

// How wide back is.
fn back_w(g: gui::Gui&) -> f32 { gui::back_width(g, strings::get(strings::NAV_BACK)) }

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

// The stars won in a theme's puzzles.
fn stars_won(stars: const u8[:], theme: i64) -> i64 {
    var n = 0;
    for p in puzzles::all.list { if p.theme == theme { n += stars[p.id]; } }
    return n;
}

// "n / total" of a theme, into out.
fn count_of(stars: const u8[:], theme: i64, out: u8[..64]&) {
    strings::fill_in(out, strings::PUZZLES_STARS, [solved(stars, theme), puzzles::theme_count(puzzles::all, theme)]);
}

// A theme's row in the library: its mark, name, stars won (a star, "n / total"), and a bar
// of them, or for a shut theme how
// many more Learn wants. True when tapped while open.
fn theme_row(g: gui::Gui&, r: float4, theme: i64, stars: const u8[:], phone: bool) -> bool {
    let u = g.scale;
    let opened = open(stars, theme);
    // A glass card as a level's on a theme's page, lit only while pressed: a plain tile
    // (white at 10%) barely shows over the sharp photograph.
    gui::glass(g, r, 22.0);
    let tapped = gui::tile(g, gui::PICKER_IDS + 10 + theme, r, gui::NO_ICON, gui::ROW, 22.0);
    var c = r;
    gui::cut_left(c, (if phone { 12.0 } else { 20.0 }) * u);
    gui::cut_right(c, (if phone { 18.0 } else { 26.0 }) * u);
    let size: f32 = min(if phone { 64.0 } else { 88.0 }, r.w / u - 24.0);    // a row given up height keeps 12 dp round it
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
        // The stars won of those there are, a star before them (prototypes/puzzle-set.html,
        // take b), and the bar under the name as far as the stars go.
        let won = stars_won(stars, theme);
        let all = 3 * puzzles::theme_count(puzzles::all, theme);
        var n: u8[..64] = [];
        strings::fill_in(n, strings::PUZZLES_STARS, [won, all]);
        let w = gui::text_width(g, gui::BODY, n[..]);
        gui::text(g, gui::BODY, gui::cut_right(top, w), n[..], 0.66, 0.0, gui::RIGHT);
        gui::cut_right(top, 6.0 * u);
        let star = 22.0 * u;
        gui::glyph_icon(g, gui::center(gui::cut_right(top, star), star, star), gui::STAR, gui::ON, 0.0, 1.0);
        gui::cut_right(top, gui::PAD * u);
        let bar = gui::cut_top(b, 8.0 * u);
        gui::fill(g, bar, float4 { 1.0, 1.0, 1.0, 0.14 }, 4.0 * u);
        let k = (won as f32) / max(1, all);
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

// How to play's row in the library: its mark (the finger on a disc of the glow at 40%), its
// name, the steps played ("✓ n / total steps"), and a bar of them. True when tapped.
fn learn_row(g: gui::Gui&, r: float4, learned: i64, steps: i64, phone: bool) -> bool {
    let u = g.scale;
    gui::glass(g, r, 22.0);
    let tapped = gui::tile(g, gui::PICKER_IDS + 8, r, gui::NO_ICON, gui::ROW, 22.0);
    var c = r;
    gui::cut_left(c, (if phone { 12.0 } else { 20.0 }) * u);
    gui::cut_right(c, (if phone { 18.0 } else { 26.0 }) * u);
    let m = min(if phone { 56.0 } else { 72.0 }, r.w / u - 16.0) * u;
    let disc = gui::center(gui::cut_left(c, m), m, m);
    gui::glow_fill(g, disc, 0.4, 0.5 * m);
    let s = 0.57 * m;
    gui::glyph_icon(g, gui::center(disc, s, s), gui::HOW, gui::PLAIN, 0.0, 1.0);
    gui::cut_left(c, (if phone { 18.0 } else { 22.0 }) * u);
    let name_h = line_h(g, gui::LABEL);
    let tall = name_h + 18.0 * u;
    var b = float4 { c.x, c.y + 0.5 * (c.w - tall), c.z, tall };
    var top = gui::cut_top(b, name_h);
    gui::cut_top(b, 10.0 * u);
    var n: u8[..64] = [];
    let done = clamp(learned, 0, steps);
    strings::fill_in(n, strings::HOW_STEP_COUNT, [done, steps]);
    let w = gui::text_width(g, gui::BODY, n[..]);
    gui::text(g, gui::BODY, gui::cut_right(top, w), n[..], 0.66, 0.0, gui::RIGHT);
    if done >= steps && steps > 0 {
        gui::cut_right(top, 6.0 * u);
        let k = 22.0 * u;
        gui::glyph_icon(g, gui::center(gui::cut_right(top, k), k, k), gui::CHECK, gui::ON, 0.0, 1.0);
    }
    gui::cut_right(top, gui::PAD * u);
    let name = strings::get(strings::HOW_TITLE);
    gui::text(g, gui::fitting(g, gui::LABEL, name, top.z), top, name, 1.0, 0.0, gui::LEFT);
    let bar = gui::cut_top(b, 8.0 * u);
    gui::fill(g, bar, float4 { 1.0, 1.0, 1.0, 0.14 }, 4.0 * u);
    let k = (done as f32) / max(1, steps);
    if k > 0.0 { gui::glow_fill(g, float4 { bar.x, bar.y, bar.z * k, bar.w }, 1.0, 4.0 * u); }
    return tapped;
}

// The draughts switch (prototypes/puzzle-set.html, take a): settings' draughts tiles, each
// its name over its board's size, joined on one glass, 4 dp round them and between.
let SWITCH_PAD = 4.0;
fn switch_row_h() -> f32 { gui::tap() + 2.0 * SWITCH_PAD } // its tiles, a tap tall, and the glass round them
let SWITCH_IDS = gui::PICKER_IDS + 20;

// How wide draughts tile i wants to be: as settings' tiles, its words with gui::side()
// either side, at least a tap.
fn switch_tile_w(g: gui::Gui&, i: i64) -> f32 {
    let u = g.scale;
    let w = max(gui::text_width(g, gui::BODY, strings::get(settings::DRAUGHTS_KEYS[i])),
                gui::text_width(g, gui::SMALL, strings::get(settings::DRAUGHTS_SIZES[i])));
    return max(gui::tap() * u, w + 2.0 * gui::side() * u);
}

// How wide the switch wants to be.
fn switch_width(g: gui::Gui&) -> f32 {
    var w = (settings::DRAUGHTS.len + 1) * SWITCH_PAD * g.scale;
    for i in settings::DRAUGHTS.len { w += switch_tile_w(g, i); }
    return w;
}

// The switch in r, the player's draughts lit; its tiles widened or narrowed in proportion to what each wants.
// True when a tap chose other draughts, set in `variant`.
fn switch(g: gui::Gui&, r: float4, variant: i64&) -> bool {
    let u = g.scale;
    let rim = SWITCH_PAD * u;
    gui::glass(g, r, 22.0);
    let n = settings::DRAUGHTS.len;
    let k = (r.z - (n + 1) * rim) / (switch_width(g) - (n + 1) * rim);
    var x = r.x + rim;
    var chose = false;
    for d, i in settings::DRAUGHTS {
        let w = if i == n - 1 { r.x + r.z - rim - x } else { floor(switch_tile_w(g, i) * k + 0.5) };
        let on = variant == d;
        let tapped, pic = gui::pick(g, SWITCH_IDS + i, float4 { x, r.y + rim, w, r.w - 2.0 * rim },
                                    0.0, strings::get(settings::DRAUGHTS_KEYS[i]),
                                    strings::get(settings::DRAUGHTS_SIZES[i]), on, true);
        if tapped && !on {
            variant = d;
            chose = true;
        }
        x += w + rim;
    }
    return chose;
}

// The title in r, bare on the photograph, centered down r.
fn title(g: gui::Gui&, r: float4) {
    let name = strings::get(strings::HOME_PUZZLES);
    let face = gui::fitting(g, gui::LABEL, name, r.z);
    // Bare on the photograph, over bright bark or snow at some sizes: a soft shadow.
    gui::shadowed(g, face, gui::center(r, r.z, line_h(g, face)), name, gui::LEFT);
}

// How wide the title wants to be.
fn title_width(g: gui::Gui&) -> f32 { gui::text_width(g, gui::LABEL, strings::get(strings::HOME_PUZZLES)) }

// Today's row (task 087): its padding, its mark, and its gap after the mark, as How to
// play's row; its tiles a tap square each, TODAY_GAP apart at least, and under the head
// where they don't fit beside it, TODAY_FOOT dp above the row's foot.
let TODAY_GAP = 10.0;
let TODAY_FOOT = 16.0;
fn row_pads(phone: bool) -> f32, f32 {
    if phone { return 12.0, 18.0; }
    return 20.0, 26.0;
}
fn mark_dp(phone: bool) -> f32 { if phone { 56.0 } else { 72.0 } }
fn mark_gap(phone: bool) -> f32 { if phone { 18.0 } else { 22.0 } }
fn learn_dp(phone: bool) -> f32 { if phone { gui::tap() } else { 104.0 } }

// How wide Today's words want to be: its name, or the longest note.
fn today_words(g: gui::Gui&) -> f32 {
    var left: u8[..64] = [];
    strings::fill_in(left, strings::DAILY_LEFT, [10]);
    return max(gui::text_width(g, gui::LABEL, strings::get(strings::DAILY_TODAY)),
               max(gui::text_width(g, gui::SMALL, strings::get(strings::DAILY_TOMORROW)), gui::text_width(g, gui::SMALL, left[..])));
}

// How wide n of today's tiles are in a line.
fn tiles_w(n: i64, u: f32) -> f32 { n * gui::tap() * u + max(n - 1, 0) * TODAY_GAP * u }

// Whether today's n tiles fit beside the head of a row w pixels wide.
fn today_beside(g: gui::Gui&, w: f32, n: i64, phone: bool) -> bool {
    let u = g.scale;
    let l, r = row_pads(phone);
    let head = (l + r + mark_dp(phone) + mark_gap(phone) + 24.0) * u + today_words(g);
    return n == 0 || head + tiles_w(n, u) <= w;
}

// How many of n tiles go in a line of a row w pixels wide, and in how many lines, as even
// as they go.
fn today_lines(w: f32, n: i64, phone: bool, u: f32) -> i64, i64 {
    let l, r = row_pads(phone);
    let fit = max(1, floor((w - (l + r) * u + TODAY_GAP * u) / ((gui::tap() + TODAY_GAP) * u)) as i64);
    let lines = max(1, (n + fit - 1) / fit);
    return (n + lines - 1) / lines, lines;
}

// How tall Today's row is, w pixels wide, with n puzzles: as How to play's with the tiles
// beside its head, else the head and the tiles' lines under it.
fn today_h(g: gui::Gui&, w: f32, n: i64, phone: bool) -> f32 {
    let u = g.scale;
    let head = learn_dp(phone) * u;
    if today_beside(g, w, n, phone) { return max(head, (gui::tap() + 2.0 * 8.0) * u); }
    let per, lines = today_lines(w, n, phone, u);
    return head + lines * gui::tap() * u + (lines - 1) * TODAY_GAP * u + TODAY_FOOT * u;
}

// Today's mark, a disc `m` pixels across centered in r: the calendar on the glow at 40%,
// the moon once all are solved; shut, plain at 6% with the lock.
fn today_mark(g: gui::Gui&, r: float4, m: f32, icon: i64, opened: bool) {
    let disc = gui::center(r, m, m);
    if opened { gui::glow_fill(g, disc, 0.4, 0.5 * m); }
    else { gui::fill(g, disc, float4 { 1.0, 1.0, 1.0, 0.06 }, 0.5 * m); }
    let s = 0.57 * m;
    gui::glyph_icon(g, gui::center(disc, s, s), icon, gui::PLAIN, 0.0, if opened { 1.0 } else { 0.45 });
}

// A name over a note in c, centered down it, the name dim with `dim`.
fn name_note(g: gui::Gui&, c: float4, name: const u8[:], note: const u8[:], dim: bool) {
    let u = g.scale;
    let name_h = line_h(g, gui::LABEL);
    let note_h = line_h(g, gui::SMALL);
    var b = gui::center(c, c.z, name_h + 6.0 * u + note_h);
    let top = gui::cut_top(b, name_h);
    gui::cut_top(b, 6.0 * u);
    gui::text(g, gui::fitting(g, gui::LABEL, name, top.z), top, name, if dim { 0.66 } else { 1.0 }, 0.0, gui::LEFT);
    gui::text(g, gui::fitting(g, gui::SMALL, note, b.z), b, note, 0.66, 0.0, gui::LEFT);
}

// One of today's puzzles' tiles: its level's bars over its stars, lit if it is the first
// unsolved. True when tapped.
fn today_tile(g: gui::Gui&, k: i64, r: float4, level: i64, won: i64, lit: bool) -> bool {
    let u = g.scale;
    let tapped, pic = gui::pick(g, TODAY_IDS + k, r, 0.0, "", "", lit, true);
    let bars = 26.0 * u;
    let star = 16.0 * u;
    var col = gui::center(r, r.z, bars + 8.0 * u + star);
    gui::glyph_icon(g, gui::center(gui::cut_top(col, bars), bars, bars), gui::LEVEL + level - 1, gui::PLAIN, 0.0, 1.0);
    gui::cut_top(col, 8.0 * u);
    for i in 3 {
        let cell = gui::cell(col, 3, 1, star, star, 1.0 * u, i);
        if i < won { gui::glyph_icon(g, cell, gui::STAR, gui::ON, 0.0, 1.0); }
        else { gui::glyph_icon(g, cell, gui::STAR_OFF, gui::PLAIN, 0.0, 0.28); }
    }
    return tapped;
}

// Today's row in r, open: its mark, its name and note, and its tiles. Sets `spot` to the
// tile of puzzle `at`, or of one tapped. Returns the place of the one tapped, or -1.
fn today_row(g: gui::Gui&, r: float4, t: settings::Today&, at: i64, spot: float4&, phone: bool) -> i64 {
    let u = g.scale;
    gui::glass(g, r, 22.0);
    let n = t.picked.list.len;
    let done = today_solved(t);
    var c = r;
    let pl, pr = row_pads(phone);
    gui::cut_left(c, pl * u);
    gui::cut_right(c, pr * u);
    let beside = today_beside(g, r.z, n, phone);
    var head = if beside { c } else { gui::cut_top(c, learn_dp(phone) * u) };
    let m = mark_dp(phone) * u;
    today_mark(g, gui::cut_left(head, m), m, if done >= n { gui::MOON } else { gui::TODAY }, true);
    gui::cut_left(head, mark_gap(phone) * u);
    var lines = c;
    if beside { lines = gui::cut_right(head, tiles_w(n, u)); }
    else { gui::cut_bottom(lines, TODAY_FOOT * u); }
    var note: u8[..64] = [];
    if done >= n { note.append(strings::get(strings::DAILY_TOMORROW)); }
    else { strings::fill_in(note, strings::DAILY_LEFT, [n - done]); }
    name_note(g, head, strings::get(strings::DAILY_TODAY), note[..], false);
    // The tiles in lines as even as they go, each line spread across the row under the head
    // (TODAY_GAP apart at least, 40 dp at most), or beside it at its right.
    var per = n;
    var unused_lines = 1;
    if !beside { per, unused_lines = today_lines(r.z, n, phone, u); }
    var lit = -1;
    for k in n { if lit < 0 && t.stars[k] == 0 { lit = k; } }
    var pick = -1;
    let side = gui::tap() * u;
    for k in n {
        let line = k / per;
        let in_line = min(per, n - line * per);
        let gap = if beside || in_line < 2 { TODAY_GAP * u }
                  else { clamp((lines.z - in_line * side) / (in_line - 1), TODAY_GAP * u, 40.0 * u) };
        let w = in_line * side + (in_line - 1) * gap;
        let x = lines.x + floor(0.5 * (lines.z - w) + 0.5) + (k - line * per) * (side + gap);
        let y = if beside { lines.y + floor(0.5 * (lines.w - side) + 0.5) } else { lines.y + line * (side + TODAY_GAP * u) };
        let tr = float4 { x, y, side, side };
        if k == at { spot = tr; }
        if today_tile(g, k, tr, slot_level(k, n), t.stars[k], k == lit) {
            pick = k;
            spot = tr;
        }
    }
    return pick;
}

// Today's row while it is shut: its mark with the lock, its name, and how many more of
// Learn's puzzles open it.
fn today_locked(g: gui::Gui&, r: float4, stars: const u8[:], phone: bool) {
    let u = g.scale;
    gui::glass(g, r, 22.0);
    var c = r;
    let pl, pr = row_pads(phone);
    gui::cut_left(c, pl * u);
    gui::cut_right(c, pr * u);
    let m = mark_dp(phone) * u;
    today_mark(g, gui::cut_left(c, m), m, gui::LOCK, false);
    gui::cut_left(c, mark_gap(phone) * u);
    var more: u8[..64] = [];
    strings::fill_in(more, strings::PUZZLES_LOCKED, [today_more(stars)]);
    name_note(g, c, strings::get(strings::DAILY_TODAY), more[..], true);
}

// How to play as a tile beside the title (task 087, once Today heads the list in
// landscape): its mark on glass, a tap square. True when tapped.
fn learn_tile(g: gui::Gui&, r: float4) -> bool {
    gui::glass(g, r, 22.0);
    return gui::tile(g, gui::PICKER_IDS + 8, r, gui::HOW, gui::ROW, 22.0);
}

// The library: back, the title, the draughts switch, and a row per theme the set has.
// In landscape the switch stands at the title row's right where the two fit, else (in
// portrait, a small window) in a row of its own under the title. A tap on the switch
// sets `variant` and returns SWITCHED, the list back at its top. Over the themes How to
// play's row, or Today's once it is open (frame), and under them Today's locked row, or
// in portrait How to play's once Today is open.
fn library(g: gui::Gui&, area: float4, stars: const u8[:], at: i64, theme: i64&, spot: float4&,
           variant: i64&, learned: i64, steps: i64, today: settings::Today&, today_at: i64) -> i64 {
    let u = g.scale;
    let landscape = area.z >= area.w;
    let phone = gui::phone(area, u);
    var page = gui::inset(area, (if phone { MARGIN_PHONE } else { MARGIN }) * u);
    var pick = NOTHING;
    let whole = page;           // the rows center on the screen, not on what back leaves
    if landscape {
        var column = gui::cut_left(page, back_w(g));
        if back(g, gui::cut_top(column, gui::tap() * u)) { pick = BACK; }
        gui::cut_left(page, MARGIN * u);
    }
    let gap = gui::PAD * u;
    let opened = today_open(stars);
    let n_today = today.picked.list.len;
    // How to play beside the title once Today heads the list, in landscape.
    let how_tile = opened && landscape;
    let how_w = if how_tile { (16.0 + gui::tap()) * u } else { 0.0 };
    let sw_w = switch_width(g);
    let sw_h = switch_row_h() * u;
    let beside = landscape && title_width(g) + how_w + 24.0 * u + sw_w <= page.z;
    let head = if beside { sw_h + gap } else { gui::tap() * u + gap + sw_h + gap };
    // A variant's set may leave a theme out (Russian's has no king shots): its row too.
    var rows = 0;
    for t in puzzles::THEMES { if puzzles::theme_count(puzzles::all, t) > 0 { rows++; } }
    // In portrait the rows give up height to fit the page under the switch's row (a
    // foldable, a 9:16 phone), down to the gui::tap() a tap wants; where even that doesn't
    // fit, they keep their height and scroll.
    var row_h = (if phone { 96.0 } else { 124.0 }) * u;
    // How to play's row over them, across the columns, or Today's once it is open, which
    // is as tall as its tiles want at the width of one column, or of the two where there
    // are two; and under them Today's locked row, or How to play's in portrait once Today
    // is open.
    let learn_h = learn_dp(phone) * u;
    let one_w = min(page.z, COLUMN * u);
    var first_h = if opened { today_h(g, one_w, n_today, phone) } else { learn_h };
    var first = first_h + gap;
    let end = if !opened || !landscape { gap + learn_h } else { 0.0 };
    let fit = floor((page.w - head - first - end - (rows - 1) * gap) / rows);
    if !landscape && fit >= gui::tap() * u { row_h = min(row_h, fit); }
    let one = first + rows * row_h + (rows - 1) * gap + end;
    // Two columns in landscape where two fit the width (a tablet, a wide window) or one
    // doesn't fit the height (a phone); one in portrait, scrolling where it must.
    let wide = page.z >= 2.0 * NARROWEST * u + gap;
    let cols = if landscape && rows > 1 && (wide || head + one > page.w) { 2 } else { 1 };
    let per = (rows + cols - 1) / cols;
    // Where the title and the rows start below back (a tablet's landscape), they take the
    // whole width and center on it; else they keep clear of back's column, centered on
    // the screen as far as that allows (a phone's landscape, back beside the rows).
    let y0 = if landscape { page.y + max(0.0, floor(0.5 * (page.w - (head + first + per * row_h + (per - 1) * gap + end)) + 0.5)) }
             else { page.y };
    // On a tablet where only the title row reaches up beside back (Today open, 16:9 or
    // 4:3), the rows under it start below back's foot and take the whole width, centered
    // on it, and the title row alone keeps clear of back.
    let foot = whole.y + gui::tap() * u + gap;
    let room = if landscape && (y0 >= foot || !phone && y0 + head >= foot) { whole } else { page };
    let top_room = if landscape && y0 < foot { page } else { room };
    let col_w = min((room.z - (cols - 1) * gap) / cols, COLUMN * u);
    let w = cols * col_w + (cols - 1) * gap;
    if opened {
        first_h = today_h(g, w, n_today, phone);
        first = first_h + gap;
    }
    let h = head + first + per * row_h + (per - 1) * gap + end;
    let y = if landscape { page.y + max(0.0, floor(0.5 * (page.w - h) + 0.5)) } else { page.y };
    let x = max(room.x, whole.x + floor(0.5 * (whole.z - w) + 0.5));
    // The title row as wide as the rows, or as the title and the switch beside it want.
    let top_wanted = if beside { min(top_room.z, max(w, title_width(g) + how_w + 24.0 * u + sw_w)) } else { w };
    let top_x = max(top_room.x, min(x, whole.x + floor(0.5 * (whole.z - top_wanted) + 0.5)));
    let top_w = min(top_wanted, top_room.x + top_room.z - top_x);
    var top = float4 { top_x, y, top_w, if beside { sw_h } else { gui::tap() * u } };
    if !landscape {
        if back(g, gui::cut_left(top, back_w(g))) { pick = BACK; }
        gui::cut_left(top, 20.0 * u);
    }
    let sw = if beside { gui::cut_right(top, sw_w) } else { float4 { x, y + gui::tap() * u + gap, w, sw_h } };
    if beside { gui::cut_right(top, 24.0 * u); }
    if how_tile {
        // How to play's tile after the title, as far along as the title's words.
        let tw = min(title_width(g), top.z - how_w);
        let tile = float4 { top.x + tw + 16.0 * u, top.y + floor(0.5 * (top.w - gui::tap() * u) + 0.5), gui::tap() * u,
                            gui::tap() * u };
        title(g, float4 { top.x, top.y, tw, top.w });
        if learn_tile(g, tile) { pick = LEARN; }
    } else {
        title(g, top);
    }
    if switch(g, sw, variant) {
        gui::scroll_set(g, LIBRARY_LIST, 0.0);
        pick = SWITCHED;
    }
    // Rows that run past the page's foot (a small window, a phone with its insets) scroll
    // under the title row, shown down to the screen's foot.
    let list_top = y + head;
    let view = float4 { area.x, list_top, area.z, g.insets.w + area.y + area.w - list_top };
    let off = gui::scroll_begin(g, LIBRARY_LIST, view, first + per * row_h + (per - 1) * gap + end + gui::PAD_WIDE * u);
    var k = 0;
    for t in puzzles::THEMES {
        guard puzzles::theme_count(puzzles::all, t) > 0 else { continue; }
        let r = float4 { x + (k / per) * (col_w + gap), list_top - off + first + (k % per) * (row_h + gap), col_w, row_h };
        k++;
        if at >= 0 && puzzles::all.list[at].theme == t { spot = float4 { r.x, r.y, r.w, r.w }; }
        if theme_row(g, r, t, stars, phone) {
            theme = t;
            pick = SHOWN;
        }
    }
    // The rows over and under them, declared after them so the themes' tiles keep their
    // order: How to play, or Today, heading the list; Today shut, or How to play, ending it.
    let foot = float4 { x, list_top - off + first + per * row_h + (per - 1) * gap + gap, w, learn_h };
    if opened {
        let tapped = today_row(g, float4 { x, list_top - off, w, first_h }, today, today_at, spot, phone);
        if tapped >= 0 { pick = TODAY - tapped; }
        if !landscape && learn_row(g, foot, learned, steps, phone) { pick = LEARN; }
    } else {
        if learn_row(g, float4 { x, list_top - off, w, learn_h }, learned, steps, phone) { pick = LEARN; }
        today_locked(g, foot, stars, phone);
    }
    gui::scroll_end(g);
    return pick;
}

// One puzzle's tile: its stars, lit if it is the first without them. True when tapped.
fn tile(g: gui::Gui&, i: i64, r: float4, won: i64, lit: bool) -> bool {
    let u = g.scale;
    let tapped, pic = gui::pick(g, gui::PICKER_IDS + 400 + i, r, 0.0, "", "", lit, true);
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

// How tall theme t's levels are at least on a landscape page w pixels wide, its head in
// the column under back: as page() lays them out.
fn tightest(t: i64, w: f32, short: bool, phone: bool, u: f32) -> f32 {
    let side = (if phone { gui::tap() } else { 96.0 }) * u;
    let gap = (if short { 8.0 } else { 10.0 }) * u;
    let pad_x = (if short { 12.0 } else { 16.0 }) * u;
    let pad_y = (if short { 4.0 } else { 14.0 }) * u;
    let between = (if short { 6.0 } else { 14.0 }) * u;
    var label = (if short { 96.0 } else { 120.0 }) * u + 14.0 * u;
    var above: f32 = 0.0;
    var fit = fit_of(w, pad_x, label, side, gap);
    if fit < 4 {
        label = 0.0;
        above = 30.0 * u + 8.0 * u;
        fit = fit_of(w, pad_x, label, side, gap);
    }
    let lv, widest = levels_h(t, fit, side, gap, pad_y, above, between);
    return lv - between;
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
    let phone = gui::phone(area, u);
    let short = landscape && area.w < gui::PHONE * u;
    var room = gui::inset(area, (if phone { MARGIN_PHONE } else { MARGIN }) * u);
    var pick = NOTHING;
    var column = room;
    if landscape {
        // Back as wide as its word wants, or a tap with the word under the arrow where the
        // levels wouldn't fit the height beside that (Shots on a phone with its insets).
        let stacked = tightest(t, room.z - back_w(g) - 24.0 * u, short, phone, u) > room.w;
        column = gui::cut_left(room, if stacked { gui::tap() * u } else { back_w(g) });
        if back(g, gui::cut_top(column, gui::tap() * u), stacked) { pick = SHOWN; }
        gui::cut_left(room, MARGIN * u);
    }
    let side = (if phone { gui::tap() } else { 96.0 }) * u;
    var gap = (if short { 8.0 } else { 10.0 }) * u;
    var pad_x = (if short { 12.0 } else { 16.0 }) * u;
    var pad_y = (if short { 4.0 } else { 14.0 }) * u;
    var between = (if short { 6.0 } else { 14.0 }) * u;
    let head_h = (if !landscape { gui::tap() } else if short { 52.0 } else { 72.0 }) * u;
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
        pad_x = gui::PAD * u;
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
        gui::cut_top(column, gui::PAD * u);
        mark(g, gui::cut_top(column, 52.0 * u), t, 52.0, true);
        gui::cut_top(column, 6.0 * u);
        gui::text(g, gui::SMALL, gui::cut_top(column, line_h(g, gui::SMALL)), n[..], 0.66, 0.0, gui::CENTER);
        y -= between;
    } else {
        // The head: back in portrait, the mark, the name, and the count.
        var head = float4 { x, y, w, head_h };
        y += head_h;
        if !landscape {
            if back(g, gui::cut_left(head, back_w(g))) { pick = SHOWN; }
            gui::cut_left(head, gui::PAD_WIDE * u);
        }
        let m: f32 = if short { 52.0 } else if landscape { 60.0 } else { 64.0 };
        mark(g, gui::cut_left(head, m * u), t, m, true);
        gui::cut_left(head, gui::PAD_WIDE * u);
        let count_w = gui::text_width(g, gui::BODY, n[..]);
        gui::text(g, gui::BODY, gui::cut_right(head, count_w + 8.0 * u), n[..], 0.66, 0.0, gui::LEFT);
        gui::cut_right(head, gui::PAD * u);
        let name = strings::get(NAMES[t]);
        gui::text(g, gui::fitting(g, gui::LABEL, name, head.z), head, name, 1.0, 0.0, gui::LEFT);
    }
    // In portrait the levels scroll under the head where they run past the page's foot
    // (a small window), shown down to the screen's foot.
    let scrolls = !landscape;
    if scrolls {
        let view = float4 { area.x, y, area.z, g.insets.w + area.y + area.w - y };
        y -= gui::scroll_begin(g, PAGE_LIST + t, view, lv + gui::PAD_WIDE * u);
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
    if scrolls { gui::scroll_end(g); }
    if pick == SHOWN { theme = -1; }
    return pick;
}
