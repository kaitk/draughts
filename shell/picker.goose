// The puzzles to pick from (prototypes/puzzles.html; docs/architecture/puzzles.md, "The
// screen"): back, and a glass row per tier, its mark (a target for captures, a crown for
// many jumps and crowning, a shield for shots and the safe move) and its ten puzzles,
// each with the stars won, 0 to 3. The next puzzle to solve is lit; a tier opens once
// half the one before it is solved, and until then each of its tiles shows a lock. In
// portrait the title stands beside back, and each tier's ten are two rows of five, at
// least 88 dp, as in landscape where ten in a row would be under that (4:3, 3:2, a
// foldable). The tiles take what the width and the height leave, and the glass hugs
// them. Where that would leave them under 88 dp (a phone), one tier shows at a time: the
// three marks as tiles, the shown one lit, at the left in landscape and in a row under
// back in portrait, and that tier's ten beside or under them, in rows of five, or of four
// where five don't fit across. The sharp photograph shows behind it, and no board.
namespace picker;
import std;
import vec;

import gui from "../gui";
import strings from "../strings";
import puzzles from "../puzzles";

let BACK = -2;              // what the screen asks for, or the index of a puzzle tapped
let NOTHING = -1;
let MARKS = [gui::TARGET, gui::CROWN, gui::SHIELD];
let PER_ROW = 10;           // tiles a tier's row has room for
let TIER_GAP = 20.0;        // dp between the tiers' glass
let OPENS = 5;              // puzzles of a tier solved to open the next

// How many of a tier's puzzles have stars.
fn solved(stars: const u8[:], tier: i64) -> i64 {
    var n = 0;
    for p in puzzles::all.list { if p.tier == tier && stars[p.id] > 0 { n++; } }
    return n;
}

// Whether a tier is open: the first always, the others once the one before is half
// solved.
fn open(stars: const u8[:], tier: i64) -> bool { tier == 1 || 2 * solved(stars, tier - 1) >= puzzles::tier_count(puzzles::all, tier - 1) }

// The next puzzle to solve: the first without stars in an open tier, or -1.
fn next(stars: const u8[:]) -> i64 {
    for t in 1..puzzles::TIERS + 1 {
        guard open(stars, t) else { continue; }
        for k in puzzles::tier_count(puzzles::all, t) {
            let i = puzzles::nth(puzzles::all, t, k);
            if stars[puzzles::all.list[i].id] == 0 { return i; }
        }
    }
    return -1;
}

// The stars won and those there are, for home's note.
fn totals(stars: const u8[:]) -> i64, i64 {
    var won = 0;
    for p in puzzles::all.list { won += stars[p.id]; }
    return won, 3 * puzzles::all.list.len;
}

// One tile: lit if it is the next, its stars or its lock. True when tapped.
fn tile(g: gui::Gui&, id: i64, r: float4, won: i64, lit: bool, opened: bool, star: f32) -> bool {
    let u = g.scale;
    let tapped, pic = gui::pick(g, id, r, 0.0, "", "", lit, opened);
    if !opened {
        let s = 26.0 * u;
        gui::glyph_icon(g, gui::center(r, s, s), gui::LOCK, gui::PLAIN, 0.0, 0.3);
        return false;
    }
    for k in 3 {
        let cell = gui::cell(r, 3, 1, star * u, star * u, 2.0 * u, k);
        if k < won { gui::glyph_icon(g, cell, gui::STAR, gui::ON, 0.0, 1.0); }
        else { gui::glyph_icon(g, cell, gui::STAR_OFF, gui::PLAIN, 0.0, 0.28); }
    }
    return tapped;
}

// The tier a phone's picker shows: `tier` once a mark was tapped, else the tier of puzzle
// `at` (the one last played), else of the next to solve.
fn shown(stars: const u8[:], at: i64, tier: i64) -> i64 {
    if tier >= 1 { return tier; }
    let i = if at >= 0 { at } else { next(stars) };
    return if i >= 0 { puzzles::all.list[i].tier } else { 1 };
}

// Declares tier t's tiles in c, `per` to a row of tiles `side` across, `gap` apart, a
// short last row centered. Sets `spot` and `pick` as frame does.
fn tier_tiles(g: gui::Gui&, c: float4, t: i64, per: i64, side: f32, gap: f32, stars: const u8[:], at: i64,
              landscape: bool, spot: float4&, pick: i64&) {
    let opened = open(stars, t);
    let now_next = next(stars);
    let count = min(puzzles::tier_count(puzzles::all, t), PER_ROW);
    for k in count {
        let i = puzzles::nth(puzzles::all, t, k);
        let row = k / per;
        let in_row = min(per, count - row * per);
        let left = c.x + 0.5 * (per - in_row) * (side + gap);
        let r = float4 { left + (k % per) * (side + gap), c.y + row * (side + gap), side, side };
        let won = stars[puzzles::all.list[i].id] as i64;
        if i == at && pick < 0 { spot = r; }
        if tile(g, 501 + i, r, won, i == now_next, opened, if landscape { 18.0 } else { 22.0 }) {
            pick = i;
            spot = r;
        }
    }
}

// Declares the screen in `area`, the screen's safe area, with the stars won so far, and
// sets `spot` to the tile of the puzzle tapped, or else of puzzle `at` (an index in
// puzzles::all, or -1 for none), which a puzzle's board grows out of and shrinks back
// into. `tier` is the tier a phone's picker shows, 0 until a mark is tapped. Returns
// BACK, the index in puzzles::all of a puzzle tapped, or NOTHING.
fn frame(g: gui::Gui&, area: float4, stars: const u8[:], at: i64, tier: i64&, spot: float4&) -> i64 {
    let u = g.scale;
    let landscape = area.z >= area.w;
    var page = float4 { area.x + 24.0 * u, area.y + 24.0 * u, area.z - 48.0 * u, area.w - 48.0 * u };
    var pick = NOTHING;
    let back = if landscape { gui::cut_left(page, 88.0 * u) } else { gui::cut_top(page, 88.0 * u) };
    let button = float4 { back.x, back.y, 88.0 * u, 88.0 * u };
    gui::glass(g, button, 22.0);
    if gui::button(g, 500, button, gui::BACK) { pick = BACK; }
    if !landscape {
        // The title beside back, as settings and the setup have it.
        var head = back;
        gui::cut_left(head, 88.0 * u + 20.0 * u);
        gui::text(g, gui::LABEL, head, strings::get(strings::HOME_PUZZLES), 1.0, 0.0, gui::LEFT);
    }
    if landscape { gui::cut_left(page, 24.0 * u); } else { gui::cut_top(page, 20.0 * u); }
    let now_next = next(stars);
    let gap = 10.0 * u;
    let margin = (if landscape { 18.0 } else { 16.0 }) * u;
    let mark = (if landscape { 88.0 } else { 56.0 }) * u;
    let mark_gap = (if landscape { 16.0 } else { 12.0 }) * u;
    let row_w = page.z - 2.0 * margin - mark - mark_gap;
    // A tier is its mark and a row of ten in landscape while they keep the 88 dp a small
    // hand needs; else, and in portrait, its mark and two rows of five.
    let ten = (row_w - (PER_ROW - 1) * gap) / PER_ROW;
    let per = if landscape && ten >= 88.0 * u { PER_ROW } else { PER_ROW / 2 };
    let rows = (PER_ROW + per - 1) / per;
    // The tiles are square: as large as the row's width and the page's height leave them,
    // at most 96 dp in landscape and 128 in portrait.
    let tall = ((page.w - (puzzles::TIERS - 1) * TIER_GAP * u) / puzzles::TIERS - 2.0 * margin - (rows - 1) * gap) / rows;
    let side = min(min((row_w - (per - 1) * gap) / per, tall), (if landscape { 96.0 } else { 128.0 }) * u);
    let tier_h = rows * side + (rows - 1) * gap + 2.0 * margin;
    guard side >= 88.0 * u - 0.5 else { return one_tier(g, page, landscape, stars, at, tier, spot, pick); }
    let all_h = puzzles::TIERS * tier_h + (puzzles::TIERS - 1) * TIER_GAP * u;
    // The glass as wide as its tiles, centered where they leave room.
    let inside = page.z - (2.0 * margin + mark + mark_gap + per * side + (per - 1) * gap);
    let off = max(0.0, floor(0.5 * inside + 0.5));
    var y = page.y + max(0.0, 0.5 * (page.w - all_h));
    for t in 1..puzzles::TIERS + 1 {
        let glass = float4 { page.x + off, y, page.z - 2.0 * off, tier_h };
        y += tier_h + TIER_GAP * u;
        gui::glass(g, glass, 28.0);
        var c = gui::inset(glass, margin);
        let icon = gui::cut_left(c, mark);
        let s = (if landscape { 60.0 } else { 48.0 }) * u;
        gui::glyph_icon(g, gui::center(icon, s, s), MARKS[t - 1], gui::PLAIN, 0.0, 1.0);
        gui::cut_left(c, mark_gap);
        let opened = open(stars, t);
        for k in puzzles::tier_count(puzzles::all, t) {
            guard k < PER_ROW else { break; }
            let i = puzzles::nth(puzzles::all, t, k);
            let r = float4 { c.x + (k % per) * (side + gap), c.y + (k / per) * (side + gap), side, side };
            let won = stars[puzzles::all.list[i].id] as i64;
            if i == at && pick < 0 { spot = r; }
            if tile(g, 501 + i, r, won, i == now_next, opened, if landscape { 18.0 } else { 22.0 }) {
                pick = i;
                spot = r;
            }
        }
    }
    return pick;
}

// A phone's picker below back (frame): the three marks as tiles, the shown tier's lit,
// and that tier's ten. Returns as frame does.
fn one_tier(g: gui::Gui&, page: float4, landscape: bool, stars: const u8[:], at: i64, tier: i64&, spot: float4&,
            pick: i64) -> i64 {
    let u = g.scale;
    var asked = pick;
    let t = shown(stars, at, tier);
    let gap = 10.0 * u;
    let margin = (if landscape { 18.0 } else { 16.0 }) * u;
    // The marks on glass: a column at the left in landscape, a row across in portrait.
    let rim = 10.0 * u;
    let mark = 88.0 * u;
    let across = mark + 2.0 * rim;
    let span = puzzles::TIERS * mark + (puzzles::TIERS - 1) * gap + 2.0 * rim;
    let apart = 24.0 * u;
    var c = page;
    if landscape { gui::cut_left(c, across + apart); } else { gui::cut_top(c, across + 20.0 * u); }
    // The tier's ten in rows of five, or of four where five don't fit 88 dp across.
    let room = c.z - 2.0 * margin;
    let per = if (room - 4.0 * gap) / 5.0 >= 88.0 * u { 5 } else { 4 };
    let rows = (PER_ROW + per - 1) / per;
    let most = (if landscape { 96.0 } else { 128.0 }) * u;
    let side = min(min((room - (per - 1) * gap) / per, (c.w - 2.0 * margin - (rows - 1) * gap) / rows), most);
    let w = per * side + (per - 1) * gap + 2.0 * margin;
    let h = rows * side + (rows - 1) * gap + 2.0 * margin;
    // In landscape the marks and the tier side by side, centered together.
    let off = if landscape { max(0.0, floor(0.5 * (page.z - across - apart - w) + 0.5)) } else { 0.0 };
    let marks = if landscape { float4 { page.x + off, page.y + 0.5 * (page.w - span), across, span } }
                else { float4 { page.x, page.y, page.z, across } };
    let glass = if landscape { float4 { marks.x + across + apart, page.y + 0.5 * (page.w - h), w, h } }
                else { float4 { c.x + 0.5 * (c.z - w), c.y, w, h } };
    gui::glass(g, marks, 28.0);
    let m = gui::inset(marks, rim);
    for k in puzzles::TIERS {
        let wide = if landscape { mark } else { (m.z - (puzzles::TIERS - 1) * gap) / puzzles::TIERS };
        let r = if landscape { float4 { m.x, m.y + k * (mark + gap), mark, mark } }
                else { float4 { m.x + k * (wide + gap), m.y, wide, mark } };
        let tapped, pic = gui::pick(g, 540 + k, r, 0.0, "", "", k + 1 == t, true);
        let s = (if landscape { 52.0 } else { 44.0 }) * u;
        gui::glyph_icon(g, gui::center(r, s, s), MARKS[k], gui::PLAIN, 0.0, 1.0);
        if tapped { tier = k + 1; }
    }
    gui::glass(g, glass, 28.0);
    tier_tiles(g, gui::inset(glass, margin), t, per, side, gap, stars, at, landscape, spot, asked);
    return asked;
}
