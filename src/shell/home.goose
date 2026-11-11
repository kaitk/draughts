// Home, the title menu (prototypes/home.html; rendering.md, "Home"): the sharp
// photograph, the board as the game stands, and one glass column with the wordmark, then
// continue, a friend, the computer with its level, puzzles, and settings, each an icon
// and a word. In landscape the column stands at the left, its left edge off the screen;
// in portrait it is a sheet along the bottom, and settings is a gear alone beside the
// wordmark, so the sheet leaves the board its room. Puzzles notes the stars won of those
// there are.
//
// A friend and the computer open a new game's setup in the same column: back and the
// title, then a row of tiles per choice, lit as in settings: the draughts, the level and
// the child's color against the computer, the clock; then play. The choices are kept in
// the settings.
//
// A bare X in the screen's top right, with no disc until pressed, closes the app, at
// once: the game is kept in any case. In portrait the board moves down and shrinks to clear it.
//
// On the menu, the player's chip, their badge bare as the X is and their name on a small
// glass pill (rendering.md, "Controls", Players; so it reads on any photograph), opens who's
// playing (who.goose): it mirrors the X, at the top left of the board's side of the
// screen (the whole width in portrait, right of the column in landscape), so it is never
// on the column (player_spot).
namespace home;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../../strings";
import puzzles from "../puzzles";

// What home asks for: the shared asks (gui::ASK_NOTHING..), and home's own. FRIEND and
// COMPUTER are also which setup is open (Shell.setup), NO_SETUP when none is.
let NO_SETUP = 0;
let NOTHING = gui::ASK_NOTHING;
let SETTINGS = gui::ASK_SETTINGS;
let BACK = gui::ASK_BACK;   // from a setup to the menu
let CHANGED = gui::ASK_CHANGED; // a choice in the setup
let CONTINUE = 1;
let FRIEND = 2;             // a friend's setup
let COMPUTER = 4;           // the computer's setup
let PLAY = 6;               // a new game as the setup stands
let PUZZLES = 8;
let EXIT = 9;               // close the app

// Whether home shows its way out: not on iOS, where an app never closes itself (the app
// sets it at launch).
var closable = true;
let PLAYERS = 10;           // who's playing

let ROWS = 4;               // and settings, a fifth in landscape
let ROW_H = 88.0;           // dp, the floor for small hands
let ROW_GAP = 2.0;
// A small window (gui::compact, task 050): the menu's rows and the wordmark's row lower,
// the sheet's rim thinner, so the board keeps a room above it.
let ROW_COMPACT = 72.0;
let MARK_COMPACT = 64.0;
let RIM_COMPACT = 20.0;
fn row_h(small: bool) -> f32 { if small { ROW_COMPACT } else { ROW_H } }
fn mark_h(small: bool) -> f32 { if small { MARK_COMPACT } else { MARK_H } }
let MARK_H = 72.0;          // the wordmark's row
let MARK_GAP = 34.0;        // under it in landscape; 14 beside settings' gear, down to 4
let GEAR = 88.0;            // settings' tap beside the wordmark, over its row's height,
let GEAR_ICON = 40.0;       // its gear alone, with no tile
let MARGIN = 16.0;          // dp the menu keeps from the screen's top and foot at least
let CORNER = 88.0;          // the way out, round, in the top right,
let EDGE = 24.0;            // this far from both edges,
let CROSS = 34.0;           // its X, bare (clear until pressed)
let CHIP_FACE = 64.0;       // the player's chip: their badge in an 88 dp tap, the name
let CHIP_GAP = 12.0;        // beside it in the row labels' face, this past the badge's 88 dp, on a glass pill
let CHIP_PILL = 16.0;       // the pill's room either side of the name,
let CHIP_PILL_H = 49.0;     // its height (the face's 30 dp, 9 above and 10 below),
let CHIP_RADIUS = 22.0;     // its corners,
let CHIP_PAD = 40.0;        // and the tap's end, this past the name's

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
// On a desktop (gui::desktop_scale) the column's content starts DESKTOP_TOP dp from the
// top rather than centered down it, and is DESKTOP_COLUMN_W dp wide at least: centered on
// a large window the menu floated in the column's middle, and the setup's choices were
// cramped (task 068, the user 2026-11-11).
let DESKTOP_TOP = 40.0;
let DESKTOP_COLUMN_W = 440.0;

let LEVEL_KEYS = [strings::PICK_EASY, strings::PICK_MEDIUM, strings::PICK_HARD];
let LEVEL_NOTES = [strings::LEVEL_EASY, strings::LEVEL_MEDIUM, strings::LEVEL_HARD];

// Where the way out is in the safe area `area`: its top right.
fn corner(area: float4, u: f32) -> float4 {
    float4 { area.x + area.z - (EDGE + CORNER) * u, area.y + EDGE * u, CORNER * u, CORNER * u }
}

// How far in dp the gear's 88 dp tap reaches over and under the wordmark's row: 8, 12
// in a small window.
fn reach(small: bool) -> f32 { 0.5 * (GEAR - mark_h(small)) }

// The gap under the wordmark in dp: MARK_GAP with settings a row of its own; 14 beside
// the gear, less where the area's `height` would leave the gear's reach over the
// wordmark's row off the screen, but never under that reach, so the gear's tap keeps off
// the first row's (a landscape phone at 480 dp less its gesture bar: row_gap gives way
// instead).
fn mark_gap(gear: bool, height: f32, u: f32, small: bool = false) -> f32 {
    guard gear else { return MARK_GAP; }
    guard !small else { return reach(true); }
    return clamp(height / u - reach(false) - (MARK_H + ROWS * ROW_H + (ROWS - 1) * ROW_GAP), reach(false), 14.0);
}

// The gap between the menu's rows in dp: ROW_GAP, less, down to none, where the gap
// under the wordmark can't give way any further (mark_gap).
fn row_gap(gear: bool, height: f32, u: f32, small: bool = false) -> f32 {
    guard gear && !small else { return ROW_GAP; }
    let left = height / u - reach(false) - MARK_H - mark_gap(gear, height, u) - ROWS * ROW_H;
    return clamp(left / (ROWS - 1), 0.0, ROW_GAP);
}

// How tall the menu is in an area `height` tall, with settings a row of its own or the
// gear beside the wordmark.
fn menu_height(gear: bool, height: f32, u: f32, small: bool = false) -> f32 {
    let rows = if gear { ROWS } else { ROWS + 1 };
    return (mark_h(small) + mark_gap(gear, height, u, small) + rows * row_h(small)
            + (rows - 1) * row_gap(gear, height, u, small)) * u;
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
    return landscape && setup != NO_SETUP && setup_height(setup, false, u) > height - 2.0 * MARGIN * u;
}

// How tall the column's content is: the menu, or a setup (FRIEND or COMPUTER).
fn content_height(setup: i64, landscape: bool, height: f32, u: f32, small: bool = false) -> f32 {
    if setup == NO_SETUP { return menu_height(gear_beside(landscape, height, u), height, u, small); }
    return setup_height(setup, paired(setup, landscape, height, u), u);
}

// Where home's parts go in `area`, the screen's safe area (layout): the column or sheet's
// glass (`col`) and its content, the menu or the setup `setup` (FRIEND or COMPUTER);
// back and the title where they share a row with the way out (`head`); the way out;
// where the board's side of the screen starts (`side`, for the player's chip); the board
// of n × n squares, and `room3d`, where a 3D board may go instead (wider than tall, it
// fits there as large as it can): across the stage less 40 dp each side (24 in
// portrait), as tall as the flat board below the row of the player's chip and the way
// out, or the flat board's square where that leaves under half of it. With the menu: the
// gear beside the wordmark or settings a row, the gap under the wordmark and between the
// rows in dp, and `small`, a small window's rows; with a setup, two columns `pair_w` dp
// wide each, or 0 for one.
struct Home {
    col:     float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    content: float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    head:    float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    way:     float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    side:    f32           = 0.0,
    board:   board::Layout = board::layout_at(0.0, 0.0, 0.0, 1.0, 8),
    room3d:  float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    gear:    bool          = false,
    below:   f32           = 0.0,
    apart:   f32           = 0.0,
    small:   bool          = false,
    pair_w:  f32           = 0.0,
}

// Where home's parts go (Home), declaring nothing.
fn layout(g: gui::Gui&, n: i64, area: float4, setup: i64, s: settings::Settings&) -> Home {
    let u = g.scale;
    let width = area.z;
    let height = area.w;
    let landscape = width >= height;
    let small = setup == NO_SETUP && gui::compact(g, area);
    let content_h = content_height(setup, landscape, height, u, small);
    let pair = paired(setup, landscape, height, u);
    let clear = (EDGE + CORNER + 16.0) * u;
    // The player's chip on the menu, in the way out's row at the board's side's left.
    let chip = setup == NO_SETUP;
    var side = area.x;          // where the board's side of the screen starts
    // Two columns, each 330 dp, narrower where the second would reach the way out (a
    // 16:9 phone with its camera's cutout at a side), in dp; 0 for one column.
    let pair_w = if pair { clamp((width - clear) / u * 0.5 - 0.5 * (40.0 + PAIR_GAP), PAIR_LEAST, PAIR_W) } else { 0.0 };
    var col = float4 { 0.0, 0.0, 0.0, 0.0 };
    var content = col;
    var head = col;             // back and the title, where they share a row with the way out
    var way = corner(area, u);  // the way out
    var l = board::layout_at(0.0, 0.0, 0.0, u, n);
    var room3d = col;
    if landscape {
        // The column, its left corners off the screen, 360 dp of content (a setup too
        // tall for that, two columns of 300 side by side); the board in the rest, 70% of
        // the height at most, 40 dp from the column. Where the board would reach the way
        // out (a phone), it moves down to 8 dp under it or narrows to 16 dp left of it,
        // whichever leaves it larger.
        let narrow = if pair { 2.0 * pair_w + PAIR_GAP } else if setup == NO_SETUP && gear_beside(true, height, u) { GEAR_W }
                     else { COLUMN_W };
        let desktop = gui::desktop_scale > 0.0;
        let wide = if desktop && !pair { max(narrow, DESKTOP_COLUMN_W) } else { narrow };
        let w = wide * u;
        col = float4 { area.x - 32.0 * u, area.y, w + 112.0 * u, height };
        content = gui::center(float4 { area.x + 40.0 * u, area.y, w, height }, w, content_h);
        // The gear reaches 8 dp over the wordmark's row: on the screen, where the menu
        // has under 8 dp above it (a 16:9 phone less its gesture bar).
        if setup == NO_SETUP && gear_beside(true, height, u) {
            content.y = min(max(content.y, area.y + 8.0 * u), area.y + height - content_h);
        }
        if desktop { content.y = max(area.y, min(area.y + DESKTOP_TOP * u, area.y + height - content_h)); }
        let stage = float4 { w + 80.0 * u, 0.0, width - w - 80.0 * u, height };
        side = area.x + stage.x;
        var size = min(0.7 * height, stage.z - 80.0 * u);
        var x = stage.x + 0.5 * (stage.z - size);
        var y = 0.5 * (height - size);
        // Where the board would reach the way out's row at the X or, on the menu, at the
        // player's badge (16 dp from either), the same choice.
        let below = (EDGE + CORNER + 8.0) * u;
        let start: f32 = if chip { EDGE + CORNER + 16.0 } else { 40.0 };
        if y < below && (x + size > width - clear || x < stage.x + start * u) {
            let down = min(size, height - 24.0 * u - below);
            let left = min(size, width - clear - stage.x - start * u);
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
        if chip && y < below && x < stage.x + named_end(g, s, stage.z) && height - 24.0 * u - below >= size {
            y = below;
        }
        if size < board::SMALLEST * u { size = 0.0; }
        l = board::layout_at(area.x + x, area.y + y, size, u, n);
        room3d = float4 { area.x + x, area.y + y, size, size };
        let top = max(y, below);
        if size > 0.0 && y + size - top >= 0.5 * size {
            let half = max(0.5 * size, min(x + 0.5 * size - stage.x - 40.0 * u, stage.x + stage.z - 40.0 * u - x - 0.5 * size));
            room3d = float4 { area.x + x + 0.5 * size - half, area.y + top, 2.0 * half, y + size - top };
        }
    } else {
        // A sheet along the bottom, its lower corners off the screen; the board above it,
        // moving down to 16 dp under the way out where it would reach it, and shrinking to
        // keep 24 dp above the sheet. It keeps 40 dp above and below, less, down to 24,
        // where a tall setup's sheet near square would leave it under 40% of the width.
        // Where a setup's sheet would reach the way out (the computer's on a short phone),
        // the sheet takes the height, 8 dp under its top at least, its margins above and
        // below shrinking to 8 dp to fit; back, the title, and the way out share its first
        // row, and the board, with no room left, isn't shown.
        var rim = (if small { RIM_COMPACT } else { 32.0 }) * u;
        var sheet_h = content_h + 2.0 * rim;
        let full = setup != NO_SETUP && height - sheet_h < clear;
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
        // The board, centered, clears the player's badge at the left as it clears the X.
        if 0.5 * (width + size) > width - clear && y < clear {
            y = clear;
            size = min(size, stage_h - 24.0 * u - y);
        }
        if chip && y < clear && 0.5 * (width - size) < named_end(g, s, width) && stage_h - 24.0 * u - clear >= size {
            y = clear;
        }
        if full || size < board::SMALLEST * u { size = 0.0; }
        l = board::layout_at(area.x + 0.5 * (width - size), area.y + y, size, u, n);
        let top = max(y, clear);
        room3d = if size > 0.0 && y + size - top >= 0.5 * size {
            float4 { area.x + 24.0 * u, area.y + top, width - 48.0 * u, y + size - top }
        } else { float4 { area.x + 0.5 * (width - size), area.y + y, size, size } };
    }
    let gear = gear_beside(landscape, height, u);
    return Home { col: col, content: content, head: head, way: way, side: side, board: l, room3d: room3d, gear: gear,
                  below: mark_gap(gear, height, u, small), apart: row_gap(gear, height, u, small), small: small,
                  pair_w: pair_w };
}

// Declares home for this frame in `area`, the screen's safe area, where layout puts its
// parts, its pieces over the UI put in `over`, and sets l to where the board of n × n
// squares goes and `room3d` to where a 3D board may go instead: the menu, or the setup
// `setup` (FRIEND or COMPUTER) with the choices in s. Returns what was tapped.
fn frame(over: board::Overlay&, g: gui::Gui&, l: board::Layout&, n: i64, area: float4, setup: i64,
         s: settings::Settings&, room3d: float4&) -> i64 {
    let h = layout(g, n, area, setup, s);
    l = h.board;
    room3d = h.room3d;
    // The column or sheet runs on past the safe area to the screen's edges.
    gui::glass(g, gui::bleed(g, h.col, area), 32.0);
    over.clear();
    var pick = if setup != NO_SETUP { choose(over, g, h.content, setup == COMPUTER, h.pair_w, h.head, s) }
               else { menu(over, g, h.content, h.gear, h.below, h.apart, s, h.small) };
    // The player and the way out, declared last so the tiles before them keep their order.
    if setup == NO_SETUP && player_chip(g, player_spot(g, area, h.side, l.board, h.way, s), s) { pick = PLAYERS; }
    if closable && gui::bare_x(g, gui::HOME_IDS + 9, h.way, gui::CLOSE, CROSS) { pick = EXIT; }
    return pick;
}

// How wide the player's chip is: round, 88 dp, without a name (or `named` false); with
// one, the badge's 88 dp, CHIP_GAP, the name, and CHIP_PAD (the pill ends 16 dp past the name).
fn chip_width(g: gui::Gui&, s: settings::Settings&, named: bool = true) -> f32 {
    let u = g.scale;
    guard named && s.name.len > 0 else { return CORNER * u; }
    return (CORNER + CHIP_GAP + CHIP_PAD) * u + gui::text_width(g, gui::LABEL, s.name[..]);
}

// Where a board in the way out's row must start, from the left of the board's side of
// the screen, `across` wide, to keep 16 dp from the player's chip with their name: 0
// with no name or one that wouldn't keep 16 dp from the way out anyway. A board there
// steps down below the row where that costs it no size, so the name shows (the tablet
// with its navigation bar in landscape); otherwise the chip is round (player_spot).
fn named_end(g: gui::Gui&, s: settings::Settings&, across: f32) -> f32 {
    let u = g.scale;
    let end = (EDGE + 16.0) * u + chip_width(g, s);
    guard s.name.len > 0 && end <= across - (EDGE + CORNER) * u else { return 0.0; }
    return end;
}

// Where the player's chip goes, 88 dp tall: mirroring the way out `way` (2026-11-09), EDGE
// dp from the top and from `side`, the left of the board's side of the screen (the safe
// area's left in portrait, the column's right edge in landscape), so it is never on the
// column. With a name that would come within 16 dp of the way out or of the board `b`
// (x, y, size) in the same row, it is round, the badge alone; frame keeps the board
// clear of that. The one place that places it.
fn player_spot(g: gui::Gui&, area: float4, side: f32, b: float4, way: float4, s: settings::Settings&) -> float4 {
    let u = g.scale;
    var r = float4 { side + EDGE * u, area.y + EDGE * u, chip_width(g, s), CORNER * u };
    let end = r.x + r.z + 16.0 * u;
    let board = b.z > 0.0 && end > b.x && b.y < r.y + r.w + 8.0 * u;
    if end > way.x || board { r.z = chip_width(g, s, false); }
    return r;
}

// The player's chip in r: their badge in its first 88 dp, bare as the way out, and their
// name beside it on a glass pill hugging it; no name, no pill. The tap covers both, and
// pressed it lights as the X's does. True when it is tapped.
fn player_chip(g: gui::Gui&, r: float4, s: settings::Settings&) -> bool {
    let u = g.scale;
    let named = r.z > CORNER * u + 0.5;
    if named {
        let w = gui::text_width(g, gui::LABEL, s.name[..]) + 2.0 * CHIP_PILL * u;
        let pill = gui::center(float4 { r.x + (CORNER + CHIP_GAP - CHIP_PILL) * u, r.y, w, r.w }, w, CHIP_PILL_H * u);
        gui::glass(g, pill, CHIP_RADIUS);
    }
    let clicked, p = gui::bare(g, gui::HOME_IDS + 8, r);
    let k = 1.0 - 0.04 * p;
    var c = r;
    let f = CHIP_FACE * u * k;
    gui::face(g, gui::center(gui::cut_left(c, CORNER * u), f, f), s.picture, 1.0, false);
    if named {
        gui::cut_left(c, CHIP_GAP * u);
        gui::text(g, gui::LABEL, c, s.name[..], 1.0, 0.0, gui::LEFT);
    }
    return clicked;
}

// The menu in c: the wordmark, `below` dp under it, the rows `apart` dp apart, and
// settings, a row of its own or, `gear`, a gear at the wordmark's right (portrait, and a
// short landscape).
fn menu(over: board::Overlay&, g: gui::Gui&, c: float4, gear: bool, below: f32, apart: f32, s: settings::Settings&,
        small: bool = false) -> i64 {
    let u = g.scale;
    // The wordmark, then the rows, and settings as the last where it isn't the gear.
    let rows_n = if gear { ROWS } else { ROWS + 1 };
    var items: gui::Item[ROWS + 2] = [gui::Item {}; ROWS + 2];
    var at:    float4[ROWS + 2]    = [float4 { 0.0, 0.0, 0.0, 0.0 }; ROWS + 2];
    items[0].size = mark_h(small) * u;
    for i in rows_n {
        items[1 + i].size = (if i < ROWS { row_h(small) } else { ROW_H }) * u;
        items[1 + i].gap = (if i == 0 { below } else { apart }) * u;
    }
    gui::stack(c, items[..rows_n + 1], at);

    // The wordmark: a crowned light piece and the app's name; settings at the right, a
    // gear with no tile in an 88 dp tap reaching 8 dp over and under the row. The name may
    // run under the tap's clear left side, up to 12 dp from the gear.
    var mark = at[0];
    let piece = gui::cut_left(mark, 56.0 * u);
    game::put(over, piece, 28.0 * u, rules::WHITE, board::CROWN,
              1.0, false);
    gui::cut_left(mark, 14.0 * u);
    var pick = NOTHING;
    if gear {
        let r = gui::center(gui::cut_right(mark, GEAR * u), GEAR * u, GEAR * u);
        if gui::icon_button(g, gui::HOME_IDS, r, gui::GEAR, GEAR_ICON) { pick = SETTINGS; }
        mark.z += 0.5 * (GEAR - GEAR_ICON) * u;
    }
    // The name spaced out, less where the gear leaves it too little room (a phone).
    let name = strings::get(strings::APP_NAME);
    let gap = if gear { gui::PAD * u } else { 0.0 };
    let spaced = 0.06 * gui::FACE_DP[gui::TITLE] as f32 * u;
    let room = (mark.z - gap - gui::text_width(g, gui::TITLE, name)) / max(1, name.len - 1);
    gui::text(g, gui::TITLE, mark, name, 1.0, clamp(room, 0.0, spaced), gui::LEFT);

    // The menu.
    let rows = [CONTINUE, FRIEND, COMPUTER, PUZZLES];
    let icons = [gui::NEXT, gui::FRIEND, gui::COMPUTER, gui::PUZZLE];
    let keys = [strings::HOME_CONTINUE, strings::HOME_FRIEND, strings::HOME_COMPUTER, strings::HOME_PUZZLES];
    for i in ROWS {
        let r = at[1 + i];
        var stars: u8[..64] = [];
        let won, all = picker::totals(s.stars[puzzles::loaded]);
        strings::fill_in(stars, strings::PUZZLES_STARS, [won, all]);
        let note = if i == 2 { strings::get(LEVEL_NOTES[s.level]) } else if i == 3 && all > 0 { stars[..] } else { "" };
        if gui::row(g, gui::HOME_IDS + 1 + i, r, icons[i], strings::get(keys[i]), note, i == 0, rows[i] != NOTHING) { pick = rows[i]; }
    }
    if !gear {
        if gui::row(g, gui::HOME_IDS + 5, at[1 + ROWS], gui::GEAR, strings::get(strings::HOME_SETTINGS), "", false, true) { pick = SETTINGS; }
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
fn choose(over: board::Overlay&, g: gui::Gui&, content: float4, computer: bool, pair_w: f32, apart: float4,
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
    if gui::tile(g, gui::HOME_IDS + 20, back, gui::BACK, gui::PLAIN, 16.0) { ask = BACK; }
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
        let tapped, pic = gui::pick(g, gui::HOME_IDS + 30 + i, draughts_tile(g, kinds, i), MINI_SIZE,
                                    strings::get(settings::DRAUGHTS_KEYS[i]), strings::get(settings::DRAUGHTS_SIZES[i]),
                                    s.variant == v, true);
        let n = rules::VARIANTS[v].size;
        gui::mini(g, pic, MINI_SIZE * u, n, n / 2 - 1, 1.0);
        if tapped {
            s.variant = v;
            ask = CHANGED;
        }
    }
    if computer {
        // The level, with one to three pips.
        let levels = group(g, c, strings::SETUP_LEVEL, TILE_H);
        for i in 3 {
            let tapped, pic = gui::pick(g, gui::HOME_IDS + 40 + i, across(levels, 3, i, u), 10.0, strings::get(LEVEL_KEYS[i]), "",
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
            let tapped, pic = gui::pick(g, gui::HOME_IDS + 50 + i, across(colors, 2, i, u), 30.0,
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
        let tapped, pic = gui::pick(g, gui::HOME_IDS + 60 + i, across(clocks, 3, i, u), if i == 0 { 26.0 } else { 0.0 }, label,
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
    if gui::row(g, gui::HOME_IDS + 70, play, gui::NO_ICON, "", "", true, true) { ask = PLAY; }
    var mid = gui::center(play, w, play.w);
    gui::cut_left(mid, 18.0 * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(mid, 34.0 * u), 34.0 * u, 34.0 * u), gui::NEXT, gui::ROW_PRIMARY, 0.0,
                    0.85);
    gui::cut_left(mid, 18.0 * u);
    gui::text(g, gui::LABEL, mid, word, 1.0, 0.0, gui::LEFT);
    return ask;
}
