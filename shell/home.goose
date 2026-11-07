// Home, the title menu (prototypes/home.html; rendering.md, "Home"): the sharp
// photograph, the board as the game stands, and one glass column with the wordmark, then
// continue, a friend, the computer with its level, puzzles, and settings, each an icon
// and a word. In landscape the column stands at the left, its left edge off the screen;
// in portrait it is a sheet along the bottom, and settings is a quiet button beside the
// wordmark, so the sheet leaves the board its room. Puzzles are dimmed until task 007
// exists.
//
// A friend and the computer open a new game's setup in the same column: back and the
// title, then a row of tiles per choice, lit as in settings: the draughts, the level and
// the child's color against the computer, the clock; then play. The choices are kept in
// the settings.
namespace home;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../strings";

// What home asks for.
let NOTHING = 0;
let CONTINUE = 1;
let FRIEND = 2;             // a friend's setup
let SETTINGS = 3;
let COMPUTER = 4;           // the computer's setup
let BACK = 5;               // from a setup to the menu
let PLAY = 6;               // a new game as the setup stands
let CHANGED = 7;            // a choice in the setup

let ROWS = 4;               // and settings, a fifth in landscape
let ROW_H = 80.0;           // dp
let ROW_GAP = 10.0;
let MARK_H = 72.0;          // the wordmark's row
let MARK_GAP = 28.0;        // under it in landscape; 12 in portrait

// The setup's parts, in dp.
let HEAD_H = 56.0;          // back and the title
let HEAD_GAP = 18.0;
let GROUP_H = 34.0;         // a choice's dim name over its tiles
let BOARD_TILE_H = 128.0;   // a draughts tile: its board at the start, name, and size
let TILE_H = 76.0;          // the other tiles
let TILE_GAP = 10.0;
let PLAY_GAP = 18.0;

let LEVEL_KEYS = [strings::PICK_EASY, strings::PICK_MEDIUM, strings::PICK_HARD];
let LEVEL_NOTES = [strings::LEVEL_EASY, strings::LEVEL_MEDIUM, strings::LEVEL_HARD];

// How tall the column's content is: the menu, or a setup (FRIEND or COMPUTER).
fn content_height(setup: i64, landscape: bool, u: f32) -> f32 {
    if setup == NOTHING {
        let mark_gap = (if landscape { MARK_GAP } else { 12.0 }) * u;
        let rows = if landscape { ROWS + 1 } else { ROWS };
        return MARK_H * u + mark_gap + ROW_GAP * u + rows * ROW_H * u + (rows - 1) * ROW_GAP * u;
    }
    let groups = if setup == COMPUTER { 4 } else { 2 };
    let tiles = BOARD_TILE_H + (groups - 1) * TILE_H;
    return (HEAD_H + HEAD_GAP + groups * GROUP_H + tiles + PLAY_GAP + ROW_H) * u;
}

// Declares home for this frame on a screen width × height pixels, and sets l to where
// the board goes: the menu, or the setup `setup` (FRIEND or COMPUTER) with the choices
// in s. Returns what was tapped.
fn frame(gm: game::Game&, g: gui::Gui&, l: board::Layout&, width: f32, height: f32, setup: i64,
         s: settings::Settings&) -> i64 {
    let u = g.scale;
    let n = rules::VARIANTS[gm.b.variant].size;
    let landscape = width >= height;
    let content_h = content_height(setup, landscape, u);
    var col = float4 { 0.0, 0.0, 0.0, 0.0 };
    var content = col;
    if landscape {
        // The column, 440 dp wide, its left corners off the screen; the board in the
        // rest, 70% of the height at most, 40 dp from the column.
        col = float4 { -32.0 * u, 0.0, 472.0 * u, height };
        content = gui::center(float4 { 40.0 * u, 48.0 * u, 360.0 * u, height - 96.0 * u }, 360.0 * u, content_h);
        let stage = float4 { 440.0 * u, 0.0, width - 440.0 * u, height };
        let size = min(0.7 * height, stage.z - 80.0 * u);
        l = board::layout_at(stage.x + 0.5 * (stage.z - size), 0.5 * (height - size), size, u, n);
    } else {
        // A sheet along the bottom, its lower corners off the screen; the board above it.
        let sheet_h = content_h + 64.0 * u;
        col = float4 { 0.0, height - sheet_h, width, sheet_h + 32.0 * u };
        content = float4 { 32.0 * u, height - sheet_h + 32.0 * u, width - 64.0 * u, content_h };
        let stage_h = height - sheet_h;
        let size = min(min(0.8 * width, 0.6 * height), stage_h - 80.0 * u);
        l = board::layout_at(0.5 * (width - size), 0.5 * (stage_h - size), size, u, n);
    }
    gui::glass(g, col, 32.0);
    gm.overlay.clear();
    if setup != NOTHING { return choose(gm, g, content, setup == COMPUTER, s); }

    // The wordmark: a crowned light piece and the app's name; in portrait, settings at
    // the right.
    var mark = gui::cut_top(content, MARK_H * u);
    let piece = gui::cut_left(mark, 56.0 * u);
    game::put(gm, piece, 28.0 * u, rules::WHITE, board::CROWN,
              1.0, false);
    gui::cut_left(mark, 14.0 * u);
    var pick = NOTHING;
    if !landscape {
        let gear = gui::center(gui::cut_right(mark, 48.0 * u), 48.0 * u, 48.0 * u);
        if gui::tile(g, 300, gear, gui::GEAR, gui::QUIET, 16.0) { pick = SETTINGS; }
    }
    gui::text(g, gui::TITLE, mark, strings::get(strings::APP_NAME), 1.0, 0.06 * gui::FACE_DP[gui::TITLE] as f32 * u,
              gui::LEFT);
    gui::cut_top(content, (if landscape { MARK_GAP } else { 12.0 }) * u + ROW_GAP * u);

    // The menu.
    let rows = [CONTINUE, FRIEND, COMPUTER, 0];
    let icons = [gui::NEXT, gui::FRIEND, gui::COMPUTER, gui::PUZZLE];
    let keys = [strings::HOME_CONTINUE, strings::HOME_FRIEND, strings::HOME_COMPUTER, strings::HOME_PUZZLES];
    for i in ROWS {
        let r = gui::cut_top(content, ROW_H * u);
        gui::cut_top(content, ROW_GAP * u);
        let note = if i == 2 { strings::get(LEVEL_NOTES[s.level]) } else { "" };
        if gui::row(g, 301 + i, r, icons[i], strings::get(keys[i]), note, i == 0, rows[i] != 0) { pick = rows[i]; }
    }
    if landscape {
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

// The setup in c: back and the title, the choices, play.
fn choose(gm: game::Game&, g: gui::Gui&, c: float4, computer: bool, s: settings::Settings&) -> i64 {
    let u = g.scale;
    var ask = NOTHING;
    var head = gui::cut_top(c, HEAD_H * u);
    gui::cut_top(c, HEAD_GAP * u);
    if gui::tile(g, 320, gui::cut_left(head, 56.0 * u), gui::BACK, gui::PLAIN, 16.0) { ask = BACK; }
    gui::cut_left(head, 14.0 * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(head, 36.0 * u), 36.0 * u, 36.0 * u),
                    if computer { gui::COMPUTER } else { gui::FRIEND }, gui::PLAIN, 0.0, 0.85);
    gui::cut_left(head, 14.0 * u);
    gui::text(g, gui::LABEL, head, strings::get(if computer { strings::HOME_COMPUTER } else { strings::HOME_FRIEND }),
              1.0, 0.0, gui::LEFT);

    // The draughts, each with its board at the start.
    let kinds = group(g, c, strings::SETUP_DRAUGHTS, BOARD_TILE_H);
    for v, i in settings::DRAUGHTS {
        let on = settings::DRAUGHTS_ON[i];
        let tapped, pic = gui::pick(g, 330 + i, across(kinds, 3, i, u), 64.0, strings::get(settings::DRAUGHTS_KEYS[i]),
                                    strings::get(settings::DRAUGHTS_SIZES[i]), s.variant == v, on);
        let n = rules::VARIANTS[v].size;
        gui::mini(g, pic, 64.0 * u, n, n / 2 - 1, if on { 1.0 } else { 0.4 });
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
        // The child's pieces, each tile showing one.
        let colors = group(g, c, strings::SETUP_COLOR, TILE_H);
        for i in 2 {
            let tapped, pic = gui::pick(g, 350 + i, across(colors, 2, i, u), 30.0,
                                        strings::get(if i == 0 { strings::COLOR_WHITE } else { strings::COLOR_BLACK }), "",
                                        s.color == i, true);
            game::put(gm, pic, 15.0 * u, i, 0, 1.0, false);
            if tapped {
                s.color = i;
                ask = CHANGED;
            }
        }
    }
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
    let play = gui::cut_top(c, ROW_H * u);
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
