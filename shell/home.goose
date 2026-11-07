// Home, the title menu (prototypes/home-menu.html; rendering.md, "Home"): the sharp
// photograph, the board as the game stands, and one glass column with the wordmark, then
// continue, a friend, the computer with its level, puzzles, and settings, each an icon
// and a word. In landscape the column stands at the left, its left edge off the screen;
// in portrait it is a sheet along the bottom, and settings is a quiet button beside the
// wordmark, so the sheet leaves the board its room. The computer and puzzles are dimmed
// until tasks 006 and 007 exist.
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
let FRIEND = 2;
let SETTINGS = 3;

let ROWS = 4;               // and settings, a fifth in landscape
let ROW_H = 80.0;           // dp
let ROW_GAP = 10.0;
let MARK_H = 72.0;          // the wordmark's row
let MARK_GAP = 28.0;        // under it in landscape; 12 in portrait

// Declares home for this frame on a screen width × height pixels, and sets l to where
// the board goes. Returns what was tapped.
fn frame(gm: game::Game&, g: gui::Gui&, l: board::Layout&, width: f32, height: f32) -> i64 {
    let u = min(width, height) / 800.0;
    let n = rules::VARIANTS[gm.b.variant].size;
    let landscape = width >= height;
    let mark_gap = (if landscape { MARK_GAP } else { 12.0 }) * u;
    let rows = if landscape { ROWS + 1 } else { ROWS };
    let content_h = MARK_H * u + mark_gap + ROW_GAP * u + rows * ROW_H * u + (rows - 1) * ROW_GAP * u;
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

    // The wordmark: a crowned light piece and the app's name; in portrait, settings at
    // the right.
    gm.overlay.clear();
    var mark = gui::cut_top(content, MARK_H * u);
    let piece = gui::cut_left(mark, 56.0 * u);
    game::put(gm, float2 { piece.x + 0.5 * piece.z, piece.y + 0.5 * piece.w }, 28.0 * u, rules::WHITE, true,
              1.0, false);
    gui::cut_left(mark, 14.0 * u);
    var pick = NOTHING;
    if !landscape {
        let gear = gui::center(gui::cut_right(mark, 48.0 * u), 48.0 * u, 48.0 * u);
        if gui::tile(g, 300, gear, gui::GEAR, gui::QUIET, 16.0) { pick = SETTINGS; }
    }
    gui::text(g, gui::TITLE, mark, strings::get(strings::APP_NAME), 1.0, 0.06 * gui::FACE_DP[gui::TITLE] as f32 * u,
              gui::LEFT);
    gui::cut_top(content, mark_gap + ROW_GAP * u);

    // The menu.
    let rows = [CONTINUE, FRIEND, 0, 0];
    let icons = [gui::NEXT, gui::FRIEND, gui::COMPUTER, gui::PUZZLE];
    let keys = [strings::HOME_CONTINUE, strings::HOME_FRIEND, strings::HOME_COMPUTER, strings::HOME_PUZZLES];
    for i in ROWS {
        let r = gui::cut_top(content, ROW_H * u);
        gui::cut_top(content, ROW_GAP * u);
        let note = if i == 2 { strings::get(strings::LEVEL_MEDIUM) } else { "" };
        if gui::row(g, 301 + i, r, icons[i], strings::get(keys[i]), note, i == 0, rows[i] != 0) { pick = rows[i]; }
    }
    if landscape {
        let r = gui::cut_top(content, ROW_H * u);
        if gui::row(g, 305, r, gui::GEAR, strings::get(strings::HOME_SETTINGS), "", false, true) { pick = SETTINGS; }
    }
    return pick;
}
