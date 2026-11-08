// The puzzles to pick from (prototypes/puzzles.html; docs/architecture/puzzles.md, "The
// screen"): back, and a glass row per tier, its mark (a target for captures, a crown for
// many jumps and crowning, a shield for shots and the safe move) and its ten puzzles,
// each with the stars won, 0 to 3. The next puzzle to solve is lit; a tier opens once
// half the one before it is solved, and until then each of its tiles shows a lock. In
// portrait the title stands beside back, and each tier's ten are two rows of five, at
// least 88 dp. The sharp photograph shows behind it, and no board.
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

// Declares the screen on a screen width × height pixels with the stars won so far.
// Returns BACK, the index in puzzles::all of a puzzle tapped, or NOTHING.
fn frame(g: gui::Gui&, width: f32, height: f32, stars: const u8[:]) -> i64 {
    let u = g.scale;
    let landscape = width >= height;
    var page = float4 { 24.0 * u, 24.0 * u, width - 48.0 * u, height - 48.0 * u };
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
    // Landscape: a tier is its mark and a row of ten. Portrait: its mark and two rows of
    // five, so the tiles keep at least the 88 dp a small hand needs.
    let per = if landscape { PER_ROW } else { PER_ROW / 2 };
    let gap = 10.0 * u;
    let margin = (if landscape { 18.0 } else { 16.0 }) * u;
    let mark = (if landscape { 88.0 } else { 56.0 }) * u;
    let mark_gap = (if landscape { 16.0 } else { 12.0 }) * u;
    // The tiles are square: as wide as the row leaves them, at most 96 dp in landscape
    // and 128 in portrait.
    let row_w = page.z - 2.0 * margin - mark - mark_gap;
    let side = min((row_w - (per - 1) * gap) / per, (if landscape { 96.0 } else { 128.0 }) * u);
    let rows = (PER_ROW + per - 1) / per;
    let tier_h = rows * side + (rows - 1) * gap + 2.0 * margin;
    let all_h = puzzles::TIERS * tier_h + (puzzles::TIERS - 1) * 20.0 * u;
    var y = page.y + max(0.0, 0.5 * (page.w - all_h));
    for t in 1..puzzles::TIERS + 1 {
        let glass = float4 { page.x, y, page.z, tier_h };
        y += tier_h + 20.0 * u;
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
            if tile(g, 501 + i, r, won, i == now_next, opened, if landscape { 18.0 } else { 22.0 }) { pick = i; }
        }
    }
    return pick;
}
