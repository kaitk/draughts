// Home, the title menu (prototypes/home.html; rendering.md, "Home"): the sharp
// photograph, the board as the game stands, and one glass column with the wordmark, then
// continue, a friend, the computer with its level, puzzles, and settings, each an icon
// and a word. In landscape the column stands at the left, its left edge off the screen;
// in portrait it is a sheet along the bottom, and settings is a quiet button beside the
// wordmark, so the sheet leaves the board its room. Puzzles notes the stars won of those
// there are.
//
// A friend and the computer open a new game's setup in the same column: back and the
// title, then a row of tiles per choice, lit as in settings: the draughts, the level and
// the child's color against the computer, the clock; then play. The choices are kept in
// the settings.
//
// A round glass X in the screen's top right closes the app, at once: the game is kept in
// any case. In portrait the board moves down and shrinks to clear it.
namespace home;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../strings";
import puzzles from "../puzzles";

// What home asks for.
let NOTHING = 0;
let CONTINUE = 1;
let FRIEND = 2;             // a friend's setup
let SETTINGS = 3;
let COMPUTER = 4;           // the computer's setup
let BACK = 5;               // from a setup to the menu
let PLAY = 6;               // a new game as the setup stands
let CHANGED = 7;            // a choice in the setup
let PUZZLES = 8;
let EXIT = 9;               // close the app

let ROWS = 4;               // and settings, a fifth in landscape
let ROW_H = 88.0;           // dp, the floor for small hands
let ROW_GAP = 2.0;
let MARK_H = 72.0;          // the wordmark's row
let MARK_GAP = 34.0;        // under it in landscape; 14 beside settings' gear, down to 4
let GEAR = 88.0;            // settings beside the wordmark, over its row's height
let MARGIN = 16.0;          // dp the menu keeps from the screen's top and foot at least
let CORNER = 88.0;          // the way out, round, in the top right,
let EDGE = 24.0;            // this far from both edges,
let CROSS = 32.0;           // its X

// The setup's parts, in dp.
let HEAD_H = 88.0;          // back and the title
let HEAD_GAP = 18.0;
let GROUP_H = 34.0;         // a choice's dim name over its tiles
let BOARD_TILE_H = 128.0;   // a draughts tile: its board at the start, name, and size
let MINI_SIZE = 64.0;       // that board
let WORD_PAD = 16.0;        // the room a draughts tile's name wants either side
let TILE_H = 88.0;          // the other tiles
let TILE_GAP = 10.0;
let PLAY_GAP = 18.0;
let COLUMN_W = 360.0;       // the column's content in landscape;
let GEAR_W = 440.0;         // the menu's with the gear beside the wordmark;
let PAIR_W = 330.0;         // each of two side by side where one is too tall (a phone),
let PAIR_LEAST = 290.0;     // narrowing to this to keep clear of the way out
let PAIR_GAP = 24.0;

let LEVEL_KEYS = [strings::PICK_EASY, strings::PICK_MEDIUM, strings::PICK_HARD];
let LEVEL_NOTES = [strings::LEVEL_EASY, strings::LEVEL_MEDIUM, strings::LEVEL_HARD];

// Where the way out is in the safe area `area`: its top right.
fn corner(area: float4, u: f32) -> float4 {
    float4 { area.x + area.z - (EDGE + CORNER) * u, area.y + EDGE * u, CORNER * u, CORNER * u }
}

// The gap under the wordmark in dp: MARK_GAP with settings a row of its own; 14 beside
// the gear, less, down to 4, where the area's `height` would leave the gear's 8 dp over
// the wordmark's row off the screen (a landscape phone at 480 dp less its gesture bar).
fn mark_gap(gear: bool, height: f32, u: f32) -> f32 {
    guard gear else { return MARK_GAP; }
    return clamp(height / u - 8.0 - (MARK_H + ROWS * ROW_H + (ROWS - 1) * ROW_GAP), 4.0, 14.0);
}

// How tall the menu is in an area `height` tall, with settings a row of its own or the
// gear beside the wordmark.
fn menu_height(gear: bool, height: f32, u: f32) -> f32 {
    let rows = if gear { ROWS } else { ROWS + 1 };
    return (MARK_H + mark_gap(gear, height, u) + rows * ROW_H + (rows - 1) * ROW_GAP) * u;
}

// Whether settings is the gear beside the wordmark: in portrait, and in a landscape too
// short for the menu with it as a row (a phone).
fn gear_beside(landscape: bool, height: f32, u: f32) -> bool {
    return !landscape || menu_height(false, height, u) > height - 2.0 * MARGIN * u;
}

// How tall a setup's column is (FRIEND or COMPUTER): its groups, back and the title before
// them (unless not `headed`) and play after, or, `paired`, two columns side by side, the
// first with back, the title, and the first half of the groups, the second with the rest
// and play.
fn setup_height(setup: i64, paired: bool, u: f32, headed: bool = true) -> f32 {
    let groups = if setup == COMPUTER { 4 } else { 2 };
    let head: f32 = if headed { HEAD_H + HEAD_GAP } else { 0.0 };
    let play: f32 = PLAY_GAP + ROW_H;
    guard paired else { return (head + groups * GROUP_H + BOARD_TILE_H + (groups - 1) * TILE_H + play) * u; }
    let first = head + groups / 2 * GROUP_H + BOARD_TILE_H + (groups / 2 - 1) * TILE_H;
    let second = groups / 2 * GROUP_H + groups / 2 * TILE_H + play;
    return max(first, second) * u;
}

// Whether a setup's column is two side by side: in a landscape too short for one.
fn paired(setup: i64, landscape: bool, height: f32, u: f32) -> bool {
    return landscape && setup != NOTHING && setup_height(setup, false, u) > height - 2.0 * MARGIN * u;
}

// How tall the column's content is: the menu, or a setup (FRIEND or COMPUTER).
fn content_height(setup: i64, landscape: bool, height: f32, u: f32) -> f32 {
    if setup == NOTHING { return menu_height(gear_beside(landscape, height, u), height, u); }
    return setup_height(setup, paired(setup, landscape, height, u), u);
}

// Declares home for this frame in `area`, the screen's safe area, its pieces over the UI
// put in `over`, and sets l to where the board of n × n squares goes: the menu, or the
// setup `setup` (FRIEND or COMPUTER) with the choices in s. Returns what was tapped.
fn frame(over: game::Overlay&, g: gui::Gui&, l: board::Layout&, n: i64, area: float4, setup: i64,
         s: settings::Settings&) -> i64 {
    let u = g.scale;
    let width = area.z;
    let height = area.w;
    let landscape = width >= height;
    let content_h = content_height(setup, landscape, height, u);
    let pair = paired(setup, landscape, height, u);
    let clear = (EDGE + CORNER + 16.0) * u;
    // Two columns, each 330 dp, narrower where the second would reach the way out (a
    // 16:9 phone with its camera's cutout at a side), in dp; 0 for one column.
    let pair_w = if pair { clamp((width - clear) / u * 0.5 - 0.5 * (40.0 + PAIR_GAP), PAIR_LEAST, PAIR_W) } else { 0.0 };
    var col = float4 { 0.0, 0.0, 0.0, 0.0 };
    var content = col;
    var head = col;             // back and the title, where they share a row with the way out
    var way = corner(area, u);  // the way out
    if landscape {
        // The column, its left corners off the screen, 360 dp of content (a setup too
        // tall for that, two columns of 300 side by side); the board in the rest, 70% of
        // the height at most, 40 dp from the column. Where the board would reach the way
        // out (a phone), it moves down to 8 dp under it or narrows to 16 dp left of it,
        // whichever leaves it larger.
        let wide = if pair { 2.0 * pair_w + PAIR_GAP } else if setup == NOTHING && gear_beside(true, height, u) { GEAR_W }
                   else { COLUMN_W };
        let w = wide * u;
        col = float4 { area.x - 32.0 * u, area.y, w + 112.0 * u, height };
        content = gui::center(float4 { area.x + 40.0 * u, area.y, w, height }, w, content_h);
        // The gear reaches 8 dp over the wordmark's row: on the screen, where the menu
        // has under 8 dp above it (a 16:9 phone less its gesture bar).
        if setup == NOTHING && gear_beside(true, height, u) {
            content.y = min(max(content.y, area.y + 8.0 * u), area.y + height - content_h);
        }
        let stage = float4 { w + 80.0 * u, 0.0, width - w - 80.0 * u, height };
        var size = min(0.7 * height, stage.z - 80.0 * u);
        var x = stage.x + 0.5 * (stage.z - size);
        var y = 0.5 * (height - size);
        let below = (EDGE + CORNER + 8.0) * u;
        if y < below && x + size > width - clear {
            let down = min(size, height - 24.0 * u - below);
            let left = min(size, width - clear - stage.x - 40.0 * u);
            if down >= left {
                size = down;
                x = stage.x + 0.5 * (stage.z - size);
                y = below;
            } else {
                size = left;
                x = width - clear - size;
                y = 0.5 * (height - size);
            }
        }
        if size < board::SMALLEST * u { size = 0.0; }
        l = board::layout_at(area.x + x, area.y + y, size, u, n);
    } else {
        // A sheet along the bottom, its lower corners off the screen; the board above it,
        // moving down to 16 dp under the way out where it would reach it, and shrinking to
        // keep 24 dp above the sheet. It keeps 40 dp above and below, less, down to 24,
        // where a tall setup's sheet near square would leave it under 40% of the width.
        // Where a setup's sheet would reach the way out (the computer's on a short phone),
        // the sheet takes the height, 8 dp under its top at least, its margins above and
        // below shrinking to 8 dp to fit; back, the title, and the way out share its first
        // row, and the board, with no room left, isn't shown.
        var sheet_h = content_h + 64.0 * u;
        var rim = 32.0 * u;
        let full = setup != NOTHING && height - sheet_h < clear;
        if full {
            rim = clamp(0.5 * (height - 8.0 * u - content_h), 8.0 * u, 32.0 * u);
            sheet_h = content_h + 2.0 * rim;
        }
        col = float4 { area.x, area.y + height - sheet_h, width, sheet_h + 32.0 * u };
        content = float4 { area.x + 32.0 * u, area.y + height - sheet_h + rim, width - 64.0 * u, content_h };
        if full {
            head = float4 { content.x, content.y, content.z - (CORNER + 16.0) * u, HEAD_H * u };
            way = float4 { content.x + content.z - CORNER * u, content.y, CORNER * u, CORNER * u };
            gui::cut_top(content, (HEAD_H + HEAD_GAP) * u);
        }
        let stage_h = height - sheet_h;
        let room = max(stage_h - 80.0 * u, min(stage_h - 48.0 * u, 0.4 * width));
        var size = min(min(0.8 * width, 0.6 * height), room);
        var y = 0.5 * (stage_h - size);
        if 0.5 * (width + size) > width - clear && y < clear {
            y = clear;
            size = min(size, stage_h - 24.0 * u - y);
        }
        if full || size < board::SMALLEST * u { size = 0.0; }
        l = board::layout_at(area.x + 0.5 * (width - size), area.y + y, size, u, n);
    }
    // The column or sheet runs on past the safe area to the screen's edges.
    gui::glass(g, gui::bleed(g, col, area), 32.0);
    over.clear();
    let gear = gear_beside(landscape, height, u);
    var pick = if setup != NOTHING { choose(over, g, content, setup == COMPUTER, pair_w, head, s) }
               else { menu(over, g, content, gear, mark_gap(gear, height, u), s) };
    // The way out, declared last so the tiles before it keep their order.
    if gui::round_button(g, 309, way, gui::CLOSE, CROSS) { pick = EXIT; }
    return pick;
}

// The menu in c: the wordmark, `below` dp under it, the rows, and settings, a row of its
// own or, `gear`, a quiet tile at the wordmark's right (portrait, and a short landscape).
fn menu(over: game::Overlay&, g: gui::Gui&, c: float4, gear: bool, below: f32, s: settings::Settings&) -> i64 {
    let u = g.scale;
    var content = c;

    // The wordmark: a crowned light piece and the app's name; settings at the right, 88
    // dp, reaching 8 dp over and under the row.
    var mark = gui::cut_top(content, MARK_H * u);
    let piece = gui::cut_left(mark, 56.0 * u);
    game::put(over, piece, 28.0 * u, rules::WHITE, board::CROWN,
              1.0, false);
    gui::cut_left(mark, 14.0 * u);
    var pick = NOTHING;
    if gear {
        let r = gui::center(gui::cut_right(mark, GEAR * u), GEAR * u, GEAR * u);
        if gui::tile(g, 300, r, gui::GEAR, gui::QUIET, 16.0) { pick = SETTINGS; }
    }
    // The name spaced out, less where the gear leaves it too little room (a phone).
    let name = strings::get(strings::APP_NAME);
    let gap = if gear { 12.0 * u } else { 0.0 };
    let spaced = 0.06 * gui::FACE_DP[gui::TITLE] as f32 * u;
    let room = (mark.z - gap - gui::text_width(g, gui::TITLE, name)) / max(1, name.len - 1);
    gui::text(g, gui::TITLE, mark, name, 1.0, clamp(room, 0.0, spaced), gui::LEFT);
    gui::cut_top(content, below * u);

    // The menu.
    let rows = [CONTINUE, FRIEND, COMPUTER, PUZZLES];
    let icons = [gui::NEXT, gui::FRIEND, gui::COMPUTER, gui::PUZZLE];
    let keys = [strings::HOME_CONTINUE, strings::HOME_FRIEND, strings::HOME_COMPUTER, strings::HOME_PUZZLES];
    for i in ROWS {
        let r = gui::cut_top(content, ROW_H * u);
        gui::cut_top(content, ROW_GAP * u);
        var stars: u8[..64] = [];
        let won, all = picker::totals(s.stars);
        strings::fill_in(stars, strings::PUZZLES_STARS, [won, all]);
        let note = if i == 2 { strings::get(LEVEL_NOTES[s.level]) } else if i == 3 && all > 0 { stars[..] } else { "" };
        if gui::row(g, 301 + i, r, icons[i], strings::get(keys[i]), note, i == 0, rows[i] != 0) { pick = rows[i]; }
    }
    if !gear {
        let r = gui::cut_top(content, ROW_H * u);
        if gui::row(g, 305, r, gui::GEAR, strings::get(strings::HOME_SETTINGS), "", false, true) { pick = SETTINGS; }
    }
    return pick;
}

// A choice's dim name, then a row of `count` tiles `h` dp tall cut from c; returns the
// row.
fn group(g: gui::Gui&, c: float4&, key: i64, h: f32) -> float4 {
    let u = g.scale;
    var name = gui::cut_top(c, GROUP_H * u);
    gui::cut_top(name, 10.0 * u);
    gui::cut_left(name, 4.0 * u);
    gui::text(g, gui::SMALL, name, strings::get(key), 0.66, 0.04 * gui::FACE_DP[gui::SMALL] as f32 * u, gui::LEFT);
    return gui::cut_top(c, h * u);
}

// Tile i of `count` across a row, 10 dp apart.
fn across(row: float4, count: i64, i: i64, u: f32) -> float4 {
    let w = (row.z - (count - 1) * TILE_GAP * u) / count;
    return float4 { row.x + i * (w + TILE_GAP * u), row.y, w, row.w };
}

// How wide draughts k's tile must be: its name or its board, whichever is wider, and
// `least` dp at least.
fn draughts_width(g: gui::Gui&, k: i64, least: f32) -> f32 {
    return max(gui::text_width(g, gui::BODY, strings::get(settings::DRAUGHTS_KEYS[k])), least * g.scale);
}

// Draughts i's tile in the row: a third of it when every name fits a third with room
// either side; else each tile its name's width and an even share of the rest, so a long
// name keeps the body face ("Rahvusvaheline", 130 dp, beside a landscape third of 113),
// each at least 88 dp wide. Thirds too where the names leave no room to share (two
// columns on a phone): a name too wide for its third then takes the small face.
fn draughts_tile(g: gui::Gui&, row: float4, i: i64) -> float4 {
    let u = g.scale;
    let count = settings::DRAUGHTS.len;
    let third = across(row, count, i, u);
    var least:  f32 = MINI_SIZE;
    var share:  f32 = 0.0;
    var widest: f32 = 0.0;
    for pass in 2 {
        var spare = row.z - (count - 1) * TILE_GAP * u;
        var narrowest: f32 = 1.0e9;
        for k in count {
            spare -= draughts_width(g, k, least);
            widest = max(widest, draughts_width(g, k, least));
            narrowest = min(narrowest, draughts_width(g, k, least));
        }
        share = spare / count;
        guard narrowest + share < 88.0 * u else { break; }
        least = 88.0;
    }
    guard widest + 2.0 * WORD_PAD * u > third.z && share >= 0.0 else { return third; }
    var x = row.x;
    for k in i { x += draughts_width(g, k, least) + share + TILE_GAP * u; }
    return float4 { x, row.y, draughts_width(g, i, least) + share, row.w };
}

// The setup in c: back and the title, the choices, play.
fn choose(over: game::Overlay&, g: gui::Gui&, content: float4, computer: bool, pair_w: f32, apart: float4,
          s: settings::Settings&) -> i64 {
    let u = g.scale;
    var ask = NOTHING;
    // One column, or two side by side, pair_w dp each where it isn't 0: back, the title,
    // the draughts and the level in the first; the child's pieces, the clock, and play in
    // the second. Back and the title are at the column's top, or in `apart` where that is
    // set, beside the way out.
    let pair = pair_w > 0.0;
    var c = if pair { float4 { content.x, content.y, pair_w * u, content.w } } else { content };
    let second = float4 { content.x + (pair_w + PAIR_GAP) * u, content.y, pair_w * u, content.w };
    var head = apart;
    if apart.z <= 0.0 {
        head = gui::cut_top(c, HEAD_H * u);
        gui::cut_top(c, HEAD_GAP * u);
    }
    let back = gui::cut_left(head, HEAD_H * u);
    if gui::tile(g, 320, back, gui::BACK, gui::PLAIN, 16.0) { ask = BACK; }
    gui::cut_left(head, 14.0 * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(head, 36.0 * u), 36.0 * u, 36.0 * u),
                    if computer { gui::COMPUTER } else { gui::FRIEND }, gui::PLAIN, 0.0, 0.85);
    gui::cut_left(head, 14.0 * u);
    // The title in a smaller face where it is too wide for the column (two side by side).
    let title = strings::get(if computer { strings::HOME_COMPUTER } else { strings::HOME_FRIEND });
    gui::text(g, gui::fitting(g, gui::LABEL, title, head.z), head, title, 1.0, 0.0, gui::LEFT);

    // The draughts, each with its board at the start.
    let kinds = group(g, c, strings::SETUP_DRAUGHTS, BOARD_TILE_H);
    for v, i in settings::DRAUGHTS {
        let on = settings::DRAUGHTS_ON[i];
        let tapped, pic = gui::pick(g, 330 + i, draughts_tile(g, kinds, i), MINI_SIZE,
                                    strings::get(settings::DRAUGHTS_KEYS[i]), strings::get(settings::DRAUGHTS_SIZES[i]),
                                    s.variant == v, on);
        let n = rules::VARIANTS[v].size;
        gui::mini(g, pic, MINI_SIZE * u, n, n / 2 - 1, if on { 1.0 } else { 0.4 });
        if tapped {
            s.variant = v;
            ask = CHANGED;
        }
    }
    if computer {
        // The level, with one to three pips.
        let levels = group(g, c, strings::SETUP_LEVEL, TILE_H);
        for i in 3 {
            let tapped, pic = gui::pick(g, 340 + i, across(levels, 3, i, u), 10.0, strings::get(LEVEL_KEYS[i]), "",
                                        s.level == i, true);
            gui::pips(g, pic, i + 1, 1.0);
            if tapped {
                s.level = i;
                ask = CHANGED;
            }
        }
        if pair { c = second; }
        // The child's pieces, each tile showing one.
        let colors = group(g, c, strings::SETUP_COLOR, TILE_H);
        for i in 2 {
            let tapped, pic = gui::pick(g, 350 + i, across(colors, 2, i, u), 30.0,
                                        strings::get(if i == 0 { strings::COLOR_WHITE } else { strings::COLOR_BLACK }), "",
                                        s.color == i, true);
            game::put(over, pic, 15.0 * u, i, 0, 1.0, false);
            if tapped {
                s.color = i;
                ask = CHANGED;
            }
        }
    }
    if pair && !computer { c = second; }
    // The clock.
    let clocks = group(g, c, strings::SETUP_CLOCK, TILE_H);
    let labels = [-1, strings::CLOCK_BLITZ, strings::CLOCK_RAPID];
    let notes = [strings::CLOCK_NONE, strings::CLOCK_BLITZ_NOTE, strings::CLOCK_RAPID_NOTE];
    for i in 3 {
        let label = if labels[i] >= 0 { strings::get(labels[i]) } else { "" };
        let tapped, pic = gui::pick(g, 360 + i, across(clocks, 3, i, u), if i == 0 { 26.0 } else { 0.0 }, label,
                                    strings::get(notes[i]), s.clock == i, true);
        if i == 0 { gui::glyph_icon(g, gui::center(pic, 26.0 * u, 26.0 * u), gui::CLOCK, gui::PLAIN, 0.0, 0.85); }
        if tapped {
            s.clock = i;
            ask = CHANGED;
        }
    }
    gui::cut_top(c, PLAY_GAP * u);
    var play = gui::cut_top(c, ROW_H * u);
    // Two columns end on one line: play at the bottom of the second, level with the
    // first's last tile, where the first is the taller.
    if pair { play.y = max(play.y, content.y + content.w - ROW_H * u); }
    let word = strings::get(strings::SETUP_PLAY);
    // Play: the row's icon and word centered.
    let w = 34.0 * u + 18.0 * u + gui::text_width(g, gui::LABEL, word) + 36.0 * u;
    if gui::row(g, 370, play, gui::NO_ICON, "", "", true, true) { ask = PLAY; }
    var mid = gui::center(play, w, play.w);
    gui::cut_left(mid, 18.0 * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(mid, 34.0 * u), 34.0 * u, 34.0 * u), gui::NEXT, gui::ROW_PRIMARY, 0.0,
                    0.85);
    gui::cut_left(mid, 18.0 * u);
    gui::text(g, gui::LABEL, mid, word, 1.0, 0.0, gui::LEFT);
    return ask;
}
