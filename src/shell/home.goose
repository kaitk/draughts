// Home, the title menu (prototypes/home.html; rendering.md, "Home"): the sharp
// photograph, the board as the game stands, and one glass column with the wordmark, then
// continue, new game with the last opponent, puzzles, the games played, and settings,
// each an icon and a word. In landscape the column stands at the left, its left edge off
// the screen; in portrait it is a sheet along the bottom, and settings is a gear alone
// beside the wordmark, so the sheet leaves the board its room. Puzzles notes the puzzles
// solved of those there are in the player's draughts until Today opens, then today's
// puzzles as dots, filled as they are solved, and a check once all are (task 088).
//
// New game opens the setup in the same column (prototypes/new-game.html, take c): back
// and the title, then a row of tiles per choice, lit as in settings: whom to play (a
// friend, or the computer easy, medium, or hard), the draughts, the child's color
// against the computer or for a friend whether the board turns, the clock; then play.
// Both opponents have the same rows, so the column never jumps. The choices are kept in
// the settings. Where they don't fit the column they scroll, play pinned under them, or,
// in a phone's landscape, in the head row in the title's place (choose).
//
// A bare X in the screen's top right, with no disc until pressed, closes the app, at
// once on a touch screen: the game is kept in any case. On a desktop it asks first
// (ask_quit), as Quit and the shell's back on the menu do. In portrait the board moves down and shrinks to clear it.
// On a desktop's landscape column, where it fits, the way out is a last row, Quit, under
// settings, and the X isn't shown (quit_row): one way out shown one of two ways, as
// settings is the gear or a row.
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

// What home asks for: the shared asks (gui::ASK_NOTHING..), and home's own. NEW_GAME is
// also whether the setup is open (Shell.setup), NO_SETUP when it isn't.
let NO_SETUP = 0;
let NOTHING = gui::ASK_NOTHING;
let SETTINGS = gui::ASK_SETTINGS;
let BACK = gui::ASK_BACK;   // from a setup to the menu
let CHANGED = gui::ASK_CHANGED; // a choice in the setup
let CONTINUE = 1;
let NEW_GAME = 2;           // the setup
let PLAY = 6;               // a new game as the setup stands
let PUZZLES = 8;
let EXIT = 9;               // close the app

// Whether home shows its way out: not on iOS, where an app never closes itself (the app
// sets it at launch).
var closable = true;
let PLAYERS = 10;           // who's playing
let RESULTS = 11;           // the games played (results.goose, task 074)
let LEARN = 12;             // how to play (task 026)

let ROWS = 3;               // continue, new game, puzzles; the games and settings after them
// The menu's rows shown: ROWS, or one fewer while there is no game to continue (frame
// sets it from Resume before the layout; issue 1).
var rows = ROWS;
// The games played (task 074), a last row after the others (before settings and Quit
// where they are rows). The menu's height is reckoned without it (menu_height); where it
// fits with it the menu grows by a row, and where that would shrink the board or leave
// the screen (a phone) the menu keeps its height and its rows scroll under the wordmark,
// the lowest fading out at the foot to show there are more (layout's `scroll`, menu).
let MENU_LIST = gui::HOME_IDS + 11;     // the rows' scrolling list's id (gui::scroll_begin)
let FADE = 72.0;            // dp at the list's foot over which a row fades out
let PEEK = 60.0;            // dp of the next row a scrolling menu shows, its word in it
let ROW_GAP = 2.0;
// A small window (gui::compact, task 050): the menu's rows and the wordmark's row lower,
// the sheet's rim thinner, so the board keeps a room above it.
let ROW_COMPACT = 72.0;
let MARK_COMPACT = 64.0;
let RIM_COMPACT = 20.0;
fn row_h(small: bool) -> f32 { if small { min(ROW_COMPACT, gui::tap()) } else { gui::tap() } }
fn mark_h(small: bool) -> f32 { if small { MARK_COMPACT } else { MARK_H } }
let MARK_H = 72.0;          // the wordmark's row
let MARK_GAP = 34.0;        // under it in landscape; 14 beside settings' gear, down to 4
let DESKTOP_MARK_GAP = 56.0; // under it on a desktop's column, where 34 read as the rows crowding it
let GEAR_ICON = 40.0;       // settings' gear beside the wordmark, alone in a tap over its row's height
let MARGIN = 16.0;          // dp the menu keeps from the screen's top and foot at least
let EDGE = 24.0;            // the way out, a round tap in the top right, this far from both edges,
let CROSS = 34.0;           // its X, bare (clear until pressed)
let CHIP_FACE = 64.0;       // the player's chip: their badge in a tap, the name
let CHIP_GAP = 12.0;        // beside it in the row labels' face, this past the badge's tap, on a glass pill
let CHIP_PILL = 16.0;       // the pill's room either side of the name,
let CHIP_PILL_H = 49.0;     // its height (the face's 30 dp, 9 above and 10 below),
let CHIP_RADIUS = 22.0;     // its corners,
let CHIP_PAD = 40.0;        // and the tap's end, this past the name's

// The setup's parts, in dp: back and the title, and play are gui::tap() tall, the tiles
// with their icon over their word gui::stacked().
let HEAD_GAP = 18.0;
let GROUP_H = 34.0;         // a choice's dim name over its tiles,
let FIRST_GROUP_H = 26.0;   // the first's, under the head's gap
let BOARD_TILE_H = 128.0;   // a draughts tile: its board at the start, name, and size
let MINI_SIZE = 64.0;       // that board
let TILE_GAP = 10.0;
let PLAY_GAP = 18.0;
let PLAY_UP_GAP = 12.0;     // between back and play where play is in the head row
let SETUP_MARGIN = 8.0;     // the least the setup keeps from the safe area's top and foot before it scrolls
let SETUP_LIST = gui::HOME_IDS + 16; // the setup's choices' scrolling list's id
let COLUMN_W = 360.0;       // the column's content in landscape;
let GEAR_W = 440.0;         // the menu's with the gear beside the wordmark;
let SETUP_W = 400.0;        // the setup's, its first row's four tiles each a tap wide
// On a desktop (gui::desktop_scale) the column's content starts DESKTOP_TOP dp from the
// top rather than centered down it, and is DESKTOP_COLUMN_W dp wide at least: centered on
// a large window the menu floated in the column's middle, and the setup's choices were
// cramped (task 068, the user 2026-11-11).
let DESKTOP_TOP = 40.0;
let DESKTOP_COLUMN_W = 440.0;

let LEVEL_KEYS = [strings::PICK_EASY, strings::PICK_MEDIUM, strings::PICK_HARD];
// New game's note: the last opponent, the computer's level or a friend.
let LEVEL_NOTES = [strings::LEVEL_EASY, strings::LEVEL_MEDIUM, strings::LEVEL_HARD];

// Where the way out is in the safe area `area`: its top right.
fn corner(area: float4, u: f32) -> float4 {
    float4 { area.x + area.z - (EDGE + gui::tap()) * u, area.y + EDGE * u, gui::tap() * u, gui::tap() * u }
}

// How far in dp the gear's tap reaches over and under the wordmark's row: 8, 12 in a
// small window, none where the tap is no taller than the row (a desktop).
fn reach(small: bool) -> f32 { max(0.0, 0.5 * (gui::tap() - mark_h(small))) }

// The gap under the wordmark in dp: MARK_GAP with settings a row of its own,
// DESKTOP_MARK_GAP on a desktop; 14 beside the gear, less where the area's `height`
// would leave the gear's reach over the wordmark's row off the screen, but never under
// that reach, so the gear's tap keeps off the first row's (a landscape phone at 480 dp
// less its gesture bar: row_gap gives way instead).
fn mark_gap(gear: bool, height: f32, u: f32, small: bool = false) -> f32 {
    guard gear else { return if gui::desktop_scale > 0.0 { DESKTOP_MARK_GAP } else { MARK_GAP }; }
    guard !small else { return reach(true); }
    return clamp(height / u - reach(false) - (MARK_H + rows * gui::tap() + (rows - 1) * ROW_GAP), reach(false), 14.0);
}

// The gap between the menu's rows in dp: ROW_GAP, less, down to none, where the gap
// under the wordmark can't give way any further (mark_gap).
fn row_gap(gear: bool, height: f32, u: f32, small: bool = false) -> f32 {
    guard gear && !small else { return ROW_GAP; }
    let left = height / u - reach(false) - MARK_H - mark_gap(gear, height, u) - rows * gui::tap();
    return clamp(left / (rows - 1), 0.0, ROW_GAP);
}

// How tall the menu is in an area `height` tall, with settings a row of its own or the
// gear beside the wordmark.
fn menu_height(gear: bool, height: f32, u: f32, small: bool = false, quit: bool = false) -> f32 {
    let more = if quit { 2 } else { 1 };
    let n = if gear { rows } else { rows + more };
    return (mark_h(small) + mark_gap(gear, height, u, small) + n * row_h(small)
            + (n - 1) * row_gap(gear, height, u, small)) * u;
}

// Whether settings is the gear beside the wordmark: in portrait, and in a landscape too
// short for the menu with it as a row (a phone).
fn gear_beside(landscape: bool, height: f32, u: f32) -> bool {
    return !landscape || menu_height(false, height, u) > height - 2.0 * MARGIN * u;
}

// Whether the way out is Quit, a last row under settings: on a desktop (gui::desktop_scale),
// where home shows its way out, in landscape with settings a row and room for one more.
fn quit_row(landscape: bool, height: f32, u: f32, small: bool = false) -> bool {
    guard closable && gui::desktop_scale > 0.0 && landscape && !gear_beside(true, height, u) else { return false; }
    return menu_height(false, height, u, small, true) <= height - 2.0 * MARGIN * u;
}

// How tall the setup's choices are in dp: their groups, each a dim name over its tiles.
fn choices_height() -> f32 { FIRST_GROUP_H + 3.0 * GROUP_H + 3.0 * gui::stacked() + BOARD_TILE_H }

// How tall the setup's column is unscrolled: back and the title, the choices, and play.
fn setup_height(u: f32) -> f32 { (gui::tap() + HEAD_GAP + choices_height() + PLAY_GAP + gui::tap()) * u }

// Whether the setup's play moves into its head row in the title's place, the choices
// scrolling under it to the screen's foot: in a phone's landscape, too short for the
// column (prototypes/new-game.html), where play pinned under the choices would leave
// them a view under 300 dp tall (the Pixel 7a's 288). Elsewhere play stays under them.
fn play_up(area: float4, u: f32) -> bool {
    return area.z >= area.w && gui::phone(area, u) && setup_height(u) > area.w - 2.0 * SETUP_MARGIN * u;
}

// How tall the column's content is: the menu, or the setup, no taller than the safe
// area less its margins, where the choices scroll.
fn content_height(setup: i64, landscape: bool, height: f32, u: f32, small: bool = false) -> f32 {
    if setup == NO_SETUP {
        return menu_height(gear_beside(landscape, height, u), height, u, small, quit_row(landscape, height, u, small));
    }
    return min(setup_height(u), height - 2.0 * SETUP_MARGIN * u);
}

// Where home's parts go in `area`, the screen's safe area (layout): the column or sheet's
// glass (`col`) and its content, the menu or the setup (`setup` NEW_GAME); back and the
// title where they share a row with the way out (`head`); the way out;
// where the board's side of the screen starts (`side`, for the player's chip); the board
// of n × n squares, and `room3d`, where a 3D board may go instead (wider than tall, it
// fits there as large as it can): across the stage less 40 dp each side (24 in
// portrait), as tall as the flat board below the row of the player's chip and the way
// out, or the flat board's square where that leaves under half of it. With the menu: the
// gear beside the wordmark or settings a row, the gap under the wordmark and between the
// rows in dp, `small`, a small window's rows, and `quit`, the way out a last row
// (quit_row); with the setup, `up`, play in the head row (play_up).
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
    quit:    bool          = false,
    up:      bool          = false,
    scroll:  bool          = false,
}

// Where home's parts go (Home), declaring nothing.
fn layout(g: gui::Gui&, n: i64, area: float4, setup: i64, s: settings::Settings&) -> Home {
    let u = g.scale;
    let width = area.z;
    let height = area.w;
    let landscape = width >= height;
    let small = setup == NO_SETUP && gui::compact(g, area);
    let clear = (EDGE + gui::tap() + 16.0) * u;
    let least_h = content_height(setup, landscape, height, u, small);
    // With the menu, its results row: a row more where that leaves the board its size and
    // the menu on the screen, else the menu keeps its height and scrolls.
    let more_h = if setup == NO_SETUP { (row_h(small) + row_gap(gear_beside(landscape, height, u), height, u, small)) * u } else { 0.0 };
    var scroll = false;
    if more_h > 0.0 {
        if landscape {
            scroll = least_h + more_h > height - 2.0 * MARGIN * u;
        } else {
            let rim = (if small { RIM_COMPACT } else { 32.0 }) * u;
            let kept, unused_y = sheet_board(width, height - least_h - 2.0 * rim, u, height, clear);
            let grown, unused_z = sheet_board(width, height - least_h - more_h - 2.0 * rim, u, height, clear);
            scroll = kept > grown + 0.5;
        }
    }
    // Scrolling in portrait, the next row shows PEEK dp under the last whole one, through
    // the sheet's rim and the inset under it, the sheet taller by what those lack.
    var content_h = if scroll { least_h } else { least_h + more_h };
    if scroll && !landscape {
        let rim = if small { RIM_COMPACT } else { 32.0 };
        content_h += max(0.0, PEEK - rim - g.insets.w / u) * u;
    }
    let up = setup != NO_SETUP && play_up(area, u);
    // The player's chip on the menu, in the way out's row at the board's side's left.
    let chip = setup == NO_SETUP;
    var side = area.x;          // where the board's side of the screen starts
    var col = float4 { 0.0, 0.0, 0.0, 0.0 };
    var content = col;
    var head = col;             // back and the title, where they share a row with the way out
    var way = corner(area, u);  // the way out
    var l = board::layout_at(0.0, 0.0, 0.0, u, n);
    var room3d = col;
    if landscape {
        // The column, its left corners off the screen, 360 dp of content (the setup's 400);
        // the board in the rest, 70% of the height at most, 40 dp from the column. Where
        // the board would reach the way out (a phone), it moves down to 8 dp under it or
        // narrows to 16 dp left of it, whichever leaves it larger.
        let narrow: f32 = if setup != NO_SETUP { SETUP_W } else if gear_beside(true, height, u) { GEAR_W } else { COLUMN_W };
        let desktop = gui::desktop_scale > 0.0;
        let wide = if desktop { max(narrow, DESKTOP_COLUMN_W) } else { narrow };
        let w = wide * u;
        col = float4 { area.x - 32.0 * u, area.y, w + 112.0 * u, height };
        content = gui::center(float4 { area.x + 40.0 * u, area.y, w, height }, w, content_h);
        // Play in the head row, the column from MARGIN under the top down to the safe
        // area's foot, where the choices' list runs on to the screen's.
        if up { content = float4 { content.x, area.y + MARGIN * u, w, height - MARGIN * u }; }
        // The gear reaches 8 dp over the wordmark's row: on the screen, where the menu
        // has under 8 dp above it (a 16:9 phone less its gesture bar).
        if setup == NO_SETUP && gear_beside(true, height, u) {
            content.y = min(max(content.y, area.y + 8.0 * u), area.y + height - content_h);
        }
        if desktop { content.y = max(area.y, min(area.y + DESKTOP_TOP * u, area.y + height - content_h)); }
        // A scrolling menu at the top, its spare room at the foot where the next row shows.
        if scroll { content.y = min(content.y, area.y + 8.0 * u); }
        let stage = float4 { w + 80.0 * u, 0.0, width - w - 80.0 * u, height };
        side = area.x + stage.x;
        var size = min(0.7 * height, stage.z - 80.0 * u);
        var x = stage.x + 0.5 * (stage.z - size);
        var y = 0.5 * (height - size);
        // Where the board would reach the way out's row at the X or, on the menu, at the
        // player's badge (16 dp from either), the same choice.
        let below = (EDGE + gui::tap() + 8.0) * u;
        let start: f32 = if chip { EDGE + gui::tap() + 16.0 } else { 40.0 };
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
        // Where the setup's sheet would reach the way out (a short phone), the sheet takes
        // the height, 8 dp under its top at least, its margins above and below shrinking
        // to 8 dp to fit, and where even that is too short (a small window) the choices
        // scroll; back, the title, and the way out share its first row, and the board,
        // with no room left, isn't shown.
        var rim = (if small { RIM_COMPACT } else { 32.0 }) * u;
        var sheet_h = content_h + 2.0 * rim;
        let full = setup != NO_SETUP && height - sheet_h < clear;
        if full {
            content_h = min(content_h, height - 3.0 * SETUP_MARGIN * u);
            rim = clamp(0.5 * (height - 8.0 * u - content_h), 8.0 * u, 32.0 * u);
            sheet_h = content_h + 2.0 * rim;
        }
        col = float4 { area.x, area.y + height - sheet_h, width, sheet_h + 32.0 * u };
        content = float4 { area.x + 32.0 * u, area.y + height - sheet_h + rim, width - 64.0 * u, content_h };
        if full {
            head = float4 { content.x, content.y, content.z - (gui::tap() + 16.0) * u, gui::tap() * u };
            way = float4 { content.x + content.z - gui::tap() * u, content.y, gui::tap() * u, gui::tap() * u };
            gui::cut_top(content, gui::tap() * u);
        }
        let stage_h = height - sheet_h;
        var size, y = sheet_board(width, stage_h, u, height, clear);
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
                  quit: setup == NO_SETUP && quit_row(landscape, height, u, small), up: up, scroll: scroll };
}

// Where a scrolling menu's list ends, in pixels: at the screen's foot, under the safe
// area's (the inset's), so the row after the last that fits shows faded over the inset.
fn foot(g: gui::Gui&, area: float4) -> f32 { area.y + area.w + g.insets.w }

// The board's size and top above a portrait sheet, `stage_h` above it in an area
// `height` tall: as large as 80% of the width and 60% of the height, keeping 40 dp above
// and below (24 where that would leave it under 40% of the width), centered, and where
// that reaches the way out's row (`clear` from the top) moved down under it and shrunk
// to keep 24 dp above the sheet.
fn sheet_board(width: f32, stage_h: f32, u: f32, height: f32, clear: f32) -> f32, f32 {
    let room = max(stage_h - 80.0 * u, min(stage_h - 48.0 * u, 0.4 * width));
    var size = min(min(0.8 * width, 0.6 * height), room);
    var y = 0.5 * (stage_h - size);
    // The board, centered, clears the player's badge at the left as it clears the X.
    if 0.5 * (width + size) > width - clear && y < clear {
        y = clear;
        size = min(size, stage_h - 24.0 * u - y);
    }
    return size, y;
}

// Declares home for this frame in `area`, the screen's safe area, where layout puts its
// parts, its pieces over the UI put in `over`, and sets l to where the board of n × n
// squares goes and `room3d` to where a 3D board may go instead: the menu, or the setup
// (`setup` NEW_GAME) with the choices in s. Returns what was tapped.
// What continue goes back to (issue 1, prototypes/issue-1.html, take a): whether there
// is a game to go back to, one played or set up, and whose it is, a strings key for the
// row's note (CONTINUE_FRIEND..), or -1 for none. With none (a first run, a new player)
// the row isn't shown, as Quit isn't where it doesn't fit; but for a new player who
// hasn't learned the player's draughts (`learn`, task 026, prototypes/tutorial.html entry
// b), How to play shows in its place, lit, its note the draughts it teaches. It goes once
// the tutorial is done, a game is played or set up, or the player said they know how; a
// player never asked (one from before the question) doesn't see it.
struct Resume {
    on:    bool = true,
    note:  i64  = -1,
    learn: bool = false,
}

// The name of draughts `variant`, a strings key.
fn draughts_key(variant: i64) -> i64 {
    for v, i in settings::DRAUGHTS { if v == variant { return settings::DRAUGHTS_KEYS[i]; } }
    return settings::DRAUGHTS_KEYS[0];
}

// The note for a game against the computer at `level`, or a friend for computer -1.
fn resume_note(computer: i64, level: i64) -> i64 {
    guard computer >= 0 else { return strings::CONTINUE_FRIEND; }
    return [strings::CONTINUE_EASY, strings::CONTINUE_MEDIUM, strings::CONTINUE_HARD][clamp(level, 0, 2)];
}

fn frame(over: board::Overlay&, g: gui::Gui&, l: board::Layout&, n: i64, area: float4, setup: i64,
         s: settings::Settings&, room3d: float4&, resume: Resume = Resume {}) -> i64 {
    rows = if resume.on || resume.learn { ROWS } else { ROWS - 1 };
    let h = layout(g, n, area, setup, s);
    l = h.board;
    room3d = h.room3d;
    // The column or sheet runs on past the safe area to the screen's edges.
    gui::glass(g, gui::bleed(g, h.col, area), 32.0);
    over.clear();
    var pick = if setup != NO_SETUP { choose(over, g, h.content, h.head, h.up, foot(g, area), s) }
               else { menu(over, g, h.content, h.gear, h.below, h.apart, s, h.small, h.quit, resume, h.scroll, foot(g, area)) };
    // The player and the way out, declared last so the tiles before them keep their order.
    if setup == NO_SETUP && player_chip(g, player_spot(g, area, h.side, l.board, h.way, s), s) { pick = PLAYERS; }
    if closable && !h.quit && gui::bare_x(g, gui::HOME_IDS + 9, h.way, gui::CLOSE, CROSS) { pick = EXIT; }
    return pick;
}

// How wide the player's chip is: round, a tap, without a name (or `named` false); with
// one, the badge's tap, CHIP_GAP, the name, and CHIP_PAD (the pill ends 16 dp past the name).
fn chip_width(g: gui::Gui&, s: settings::Settings&, named: bool = true) -> f32 {
    let u = g.scale;
    guard named && s.name.len > 0 else { return gui::tap() * u; }
    return (gui::tap() + CHIP_GAP + CHIP_PAD) * u + gui::text_width(g, gui::LABEL, s.name[..]);
}

// Where a board in the way out's row must start, from the left of the board's side of
// the screen, `across` wide, to keep 16 dp from the player's chip with their name: 0
// with no name or one that wouldn't keep 16 dp from the way out anyway. A board there
// steps down below the row where that costs it no size, so the name shows (the tablet
// with its navigation bar in landscape); otherwise the chip is round (player_spot).
fn named_end(g: gui::Gui&, s: settings::Settings&, across: f32) -> f32 {
    let u = g.scale;
    let end = (EDGE + 16.0) * u + chip_width(g, s);
    guard s.name.len > 0 && end <= across - (EDGE + gui::tap()) * u else { return 0.0; }
    return end;
}

// Where the player's chip goes, a tap tall: mirroring the way out `way` (2026-11-09), EDGE
// dp from the top and from `side`, the left of the board's side of the screen (the safe
// area's left in portrait, the column's right edge in landscape), so it is never on the
// column. With a name that would come within 16 dp of the way out or of the board `b`
// (x, y, size) in the same row, it is round, the badge alone; frame keeps the board
// clear of that. The one place that places it.
fn player_spot(g: gui::Gui&, area: float4, side: f32, b: float4, way: float4, s: settings::Settings&) -> float4 {
    let u = g.scale;
    var r = float4 { side + EDGE * u, area.y + EDGE * u, chip_width(g, s), gui::tap() * u };
    let end = r.x + r.z + 16.0 * u;
    let board = b.z > 0.0 && end > b.x && b.y < r.y + r.w + 8.0 * u;
    if end > way.x || board { r.z = chip_width(g, s, false); }
    return r;
}

// The player's chip in r: their badge in its first tap, bare as the way out, and their
// name beside it on a glass pill hugging it; no name, no pill. The tap covers both, and
// pressed it lights as the X's does. True when it is tapped.
fn player_chip(g: gui::Gui&, r: float4, s: settings::Settings&) -> bool {
    let u = g.scale;
    let named = r.z > gui::tap() * u + 0.5;
    if named {
        let w = gui::text_width(g, gui::LABEL, s.name[..]) + 2.0 * CHIP_PILL * u;
        let pill = gui::center(float4 { r.x + (gui::tap() + CHIP_GAP - CHIP_PILL) * u, r.y, w, r.w }, w, CHIP_PILL_H * u);
        gui::glass(g, pill, CHIP_RADIUS);
    }
    let clicked, p = gui::bare(g, gui::HOME_IDS + 8, r);
    let k = 1.0 - 0.04 * p;
    var c = r;
    let f = CHIP_FACE * u * k;
    gui::face(g, gui::center(gui::cut_left(c, gui::tap() * u), f, f), s.picture, 1.0, false);
    if named {
        gui::cut_left(c, CHIP_GAP * u);
        gui::text(g, gui::LABEL, c, s.name[..], 1.0, 0.0, gui::LEFT);
    }
    return clicked;
}

// The menu in c: the wordmark, `below` dp under it, the rows `apart` dp apart, the games
// row last, and settings, a row of its own or, `gear`, a gear at the wordmark's right
// (portrait, and a short landscape). With `scroll`, c is a row short of them: the rows
// scroll under the wordmark down to `foot` (y in pixels, the screen's safe foot), the
// lowest fading out while there are more below.
fn menu(over: board::Overlay&, g: gui::Gui&, c: float4, gear: bool, below: f32, apart: f32, s: settings::Settings&,
        small: bool = false, quit: bool = false, resume: Resume = Resume {}, scroll: bool = false, foot: f32 = 0.0) -> i64 {
    let u = g.scale;
    // The wordmark, then the rows and the results row, settings as the next where it isn't
    // the gear, and Quit last with `quit`.
    let more = if quit { 2 } else { 1 };
    let first = ROWS - rows;    // the first row shown: Continue's, or Friend's without it
    let shown = rows + 1;       // with the results row
    let rows_n = if gear { shown } else { shown + more };
    var items: gui::Item[ROWS + 4] = [gui::Item {}; ROWS + 4];
    var at:    float4[ROWS + 4]    = [float4 { 0.0, 0.0, 0.0, 0.0 }; ROWS + 4];
    items[0].size = mark_h(small) * u;
    for i in rows_n {
        items[1 + i].size = (if i < shown { row_h(small) } else { gui::tap() }) * u;
        items[1 + i].gap = (if i == 0 { below } else { apart }) * u;
    }
    gui::stack(c, items[..rows_n + 1], at);

    // The wordmark: a crowned light piece and the app's name; settings at the right, a
    // gear with no tile in a tap reaching 8 dp over and under the row. The name may
    // run under the tap's clear left side, up to 12 dp from the gear.
    var mark = at[0];
    let piece = gui::cut_left(mark, 56.0 * u);
    game::put(over, piece, 28.0 * u, rules::WHITE, board::CROWN,
              1.0, false);
    gui::cut_left(mark, 14.0 * u);
    var pick = NOTHING;
    if gear {
        let r = gui::center(gui::cut_right(mark, gui::tap() * u), gui::tap() * u, gui::tap() * u);
        if gui::icon_button(g, gui::HOME_IDS, r, gui::GEAR, GEAR_ICON) { pick = SETTINGS; }
        mark.z += 0.5 * (gui::tap() - GEAR_ICON) * u;
    }
    // The name spaced out, less where the gear leaves it too little room (a phone).
    let name = strings::get(strings::APP_NAME);
    let gap = if gear { gui::PAD * u } else { 0.0 };
    let spaced = 0.06 * gui::FACE_DP[gui::TITLE] as f32 * u;
    let room = (mark.z - gap - gui::text_width(g, gui::TITLE, name)) / max(1, name.len - 1);
    gui::text(g, gui::TITLE, mark, name, 1.0, clamp(room, 0.0, spaced), gui::LEFT);

    // The rows, a list under the wordmark where the menu kept its height.
    let end = at[rows_n].y + at[rows_n].w;
    var listed = g.quads.len;
    var view = float4 { 0.0, 0.0, 0.0, 0.0 };
    var off: f32 = 0.0;
    if scroll {
        let top = at[0].y + at[0].w;
        view = float4 { c.x - 24.0 * u, top, c.z + 48.0 * u, foot - top };
        off = gui::scroll_begin(g, MENU_LIST, view, end - top);
        for k in 1..rows_n + 1 { at[k].y -= off; }
        listed = g.quads.len;
    }
    let ways = [CONTINUE, NEW_GAME, PUZZLES];
    let icons = [gui::NEXT, gui::NEW_GAME, gui::PUZZLE];
    let keys = [strings::HOME_CONTINUE, strings::HOME_NEW_GAME, strings::HOME_PUZZLES];
    let set = puzzles::loaded;
    let daily = picker::today_open(s.stars[set]);
    for i in first..ROWS {
        let r = at[1 + i - first];
        var stars: u8[..64] = [];
        let won, all = picker::solved_all(s.stars[set]);
        if !daily { strings::fill_in(stars, strings::PUZZLES_STARS, [won, all]); }
        // New game notes the opponent its setup keeps, the computer's icon and level or a
        // friend's; it is outlined under continue, and lit in its place where continue
        // isn't shown (a first run), the keys' first choice then.
        let opponent = if s.friend { strings::LEVEL_FRIEND } else { LEVEL_NOTES[s.level] };
        let note = if i == 0 && resume.note >= 0 { strings::get(resume.note) }
                   else if i == 1 { strings::get(opponent) } else if i == 2 && all > 0 { stars[..] } else { "" };
        let mark = if i != 1 { gui::NO_ICON } else if s.friend { gui::FRIEND } else { gui::COMPUTER };
        // How to play in continue's place (Resume.learn).
        if i == 0 && !resume.on {
            if gui::row(g, gui::HOME_IDS + 1, r, gui::HOW, strings::get(strings::HOW_TITLE),
                        strings::get(draughts_key(s.variant)), true, true) { pick = LEARN; }
            continue;
        }
        if gui::row(g, gui::HOME_IDS + 1 + i, r, icons[i], strings::get(keys[i]), note, i == first, true, i == 1, mark) {
            pick = ways[i];
        }
        if i == 2 && daily { today_dots(g, r, s.today[set]); }
    }
    // The games: the player's rating in their draughts once they have one.
    var rating: u8[..16] = [];
    if s.rated[s.variant] > 0 { format(rating, s.rating[s.variant]); }
    if gui::row(g, gui::HOME_IDS + 7, at[1 + rows], gui::LEVEL + 2, strings::get(strings::RESULTS_TITLE), rating[..], false, true) {
        pick = RESULTS;
    }
    if !gear {
        if gui::row(g, gui::HOME_IDS + 5, at[2 + rows], gui::GEAR, strings::get(strings::HOME_SETTINGS), "", false, true) { pick = SETTINGS; }
    }
    if quit && gui::row(g, gui::HOME_IDS + 6, at[3 + rows], gui::CLOSE, strings::get(strings::HOME_QUIT), "", false, true) {
        pick = EXIT;
    }
    if scroll {
        // The rows fade out at the foot while there are more below (at the top they go
        // under the wordmark, cut by the view).
        gui::fade_edges(g, listed, view, 0.0, end - off - foot, FADE * u);
        gui::scroll_end(g);
    }
    return pick;
}

// Today's puzzles at the right of the Puzzles row r, as gui::row puts its note: a dot
// each, filled in the glow once solved, or a check once all are.
let DONE = 26.0;
fn today_dots(g: gui::Gui&, r: float4, t: settings::Today&) {
    let u = g.scale;
    let n = t.picked.list.len;
    guard n > 0 else { return; }
    var c = r;
    gui::cut_right(c, 18.0 * u);
    if picker::today_solved(t) >= n {
        let k = DONE * u;
        gui::glyph_icon(g, gui::center(gui::cut_right(c, k), k, k), gui::CHECK, gui::ON, 0.0, 1.0);
        return;
    }
    picker::dots(g, gui::cut_right(c, picker::dots_w(n, u)), n, t.stars[..], -1);
}

// Whether quitting asks first (ask_quit): on a desktop, where a gamepad's B or Escape on
// the menu, or a slip onto Quit, would otherwise close the window at once. A touch
// screen's X closes at once: the game is kept, and Android's own back doesn't ask either.
fn asks_quit() -> bool { gui::desktop_scale > 0.0 }

// The quit's question (asks_quit, 2026-11-12): over the dimmed home (`screen`, the whole
// window), a glass card centered in the safe area `area`, the question over cancel and
// quit side by side, quit lit and the keys' first choice, so Enter or A answers it and
// Escape or B (the shell's back) cancels. A press outside the card cancels too. Returns
// EXIT, BACK for cancel, or NOTHING.
let ASK_PAD = 28.0;         // the card's sides, and between the question and the buttons
let ASK_GAP = 12.0;         // between the buttons
let ASK_BUTTON = 150.0;     // a button's width at least
let ASK_ICON = 28.0;
fn ask_quit(g: gui::Gui&, area: float4, screen: float4) -> i64 {
    let u = g.scale;
    gui::fill(g, screen, float4 { 0.0, 0.0, 0.0, 0.42 }, 0.0);
    let outside, unused = gui::hold(g, gui::HOME_IDS + 12, screen, false);
    let title = strings::get(strings::QUIT_ASK);
    let cancel = strings::get(strings::QUIT_CANCEL);
    let quit = strings::get(strings::HOME_QUIT);
    let button = max(ASK_BUTTON * u, max(gui::labelled_width(g, ASK_ICON, cancel, gui::BODY),
                                         gui::labelled_width(g, ASK_ICON, quit, gui::BODY)));
    let pair = 2.0 * button + ASK_GAP * u;
    let line = g.faces[gui::HEADING].ascent - g.faces[gui::HEADING].descent;
    let width = min(max(pair, gui::text_width(g, gui::HEADING, title)) + 2.0 * ASK_PAD * u, area.z);
    let height = line + (3.0 * ASK_PAD + gui::tap()) * u;
    let r = gui::center(area, width, height);
    gui::glass(g, r, 32.0);
    gui::hold(g, gui::HOME_IDS + 13, r, false);
    var c = gui::inset(r, ASK_PAD * u);
    gui::text(g, gui::HEADING, gui::cut_top(c, line), title, 1.0, 0.0, gui::CENTER);
    gui::cut_top(c, ASK_PAD * u);
    var row = gui::center(gui::cut_top(c, gui::tap() * u), pair, gui::tap() * u);
    var ask = NOTHING;
    if gui::labelled(g, gui::HOME_IDS + 14, gui::cut_left(row, button), gui::BACK, ASK_ICON, cancel, gui::BODY, gui::MIDDLE) {
        ask = BACK;
    }
    if gui::labelled(g, gui::HOME_IDS + 15, gui::cut_right(row, button), gui::CLOSE, ASK_ICON, quit, gui::BODY, gui::MIDDLE,
                     gui::PRIMARY) {
        ask = EXIT;
    }
    gui::prefer(g, gui::HOME_IDS + 15);
    if ask == NOTHING && outside { ask = BACK; }
    return ask;
}

// A choice's dim name, `name_h` dp over a row of tiles `h` dp tall, cut from c; returns
// the row.
fn group(g: gui::Gui&, c: float4&, key: i64, h: f32, name_h: f32 = GROUP_H) -> float4 {
    let u = g.scale;
    var name = gui::cut_top(c, name_h * u);
    gui::cut_top(name, (name_h - 24.0) * u);
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
// each at least a tap wide. Thirds too where the names leave no room to share: a name too
// wide for its third then takes the small face.
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
        guard narrowest + share < gui::tap() * u else { break; }
        least = gui::tap();
    }
    guard widest + 2.0 * gui::side() * u > third.z && share >= 0.0 else { return third; }
    var x = row.x;
    for k in i { x += draughts_width(g, k, least) + share + TILE_GAP * u; }
    return float4 { x, row.y, draughts_width(g, i, least) + share, row.w };
}

// Play in r, a primary row: its icon and word centered.
fn play_row(g: gui::Gui&, r: float4) -> bool {
    let u = g.scale;
    let word = strings::get(strings::SETUP_PLAY);
    let w = 34.0 * u + 18.0 * u + gui::text_width(g, gui::LABEL, word) + 36.0 * u;
    let tapped = gui::row(g, gui::HOME_IDS + 70, r, gui::NO_ICON, "", "", true, true);
    var mid = gui::center(r, w, r.w);
    gui::cut_left(mid, 18.0 * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(mid, 34.0 * u), 34.0 * u, 34.0 * u), gui::NEXT, gui::ROW_PRIMARY, 0.0, 0.85);
    gui::cut_left(mid, 18.0 * u);
    gui::text(g, gui::LABEL, mid, word, 1.0, 0.0, gui::LEFT);
    return tapped;
}

// The setup in `content`: back and the title at its top, or in `apart` where that is set,
// beside the way out; the choices; and play, pinned at the foot. Where the choices don't
// fit between them, they scroll in a list between the head and play, the lowest fading
// out at its foot while there are more below. With `up`, play is in the head row in the
// title's place, and the list runs on down to `foot` (y in pixels, the screen's foot).
// Every tile is declared in one order whatever the layout: back, whom to play, the
// draughts, the pieces or the board's turning, the clock, play.
fn choose(over: board::Overlay&, g: gui::Gui&, content: float4, apart: float4, up: bool, foot: f32,
          s: settings::Settings&) -> i64 {
    let u = g.scale;
    var ask = NOTHING;
    var c = content;
    var head = apart;
    if apart.z <= 0.0 { head = gui::cut_top(c, gui::tap() * u); }
    let back = gui::cut_left(head, gui::tap() * u);
    if gui::tile(g, gui::HOME_IDS + 20, back, gui::BACK, gui::PLAIN, 16.0) { ask = BACK; }
    var play = head;
    if up {
        gui::cut_left(play, PLAY_UP_GAP * u);
    } else {
        gui::cut_left(head, 14.0 * u);
        gui::glyph_icon(g, gui::center(gui::cut_left(head, 36.0 * u), 36.0 * u, 36.0 * u), gui::NEW_GAME, gui::PLAIN, 0.0, 0.85);
        gui::cut_left(head, 14.0 * u);
        // The title in a smaller face where it is too wide for its room.
        let title = strings::get(strings::HOME_NEW_GAME);
        gui::text(g, gui::fitting(g, gui::LABEL, title, head.z), head, title, 1.0, 0.0, gui::LEFT);
        play = gui::cut_bottom(c, gui::tap() * u);
        gui::cut_bottom(c, PLAY_GAP * u);
    }

    // The choices, a list where they don't fit: from under the head, its gap in it, down to
    // play's gap, or to the screen's foot with play up.
    let inner = (HEAD_GAP + choices_height()) * u;
    let scroll = up || inner > c.w + 0.5;
    let bottom = if up { foot } else { c.y + c.w };
    let view = float4 { c.x - 24.0 * u, c.y, c.z + 48.0 * u, bottom - c.y };
    var off: f32 = 0.0;
    if scroll { off = gui::scroll_begin(g, SETUP_LIST, view, inner); }
    let listed = g.quads.len;
    var list = float4 { c.x, c.y - off, c.z, inner };
    gui::cut_top(list, HEAD_GAP * u);

    // Whom to play: a friend, or the computer at a level, its icon and one to three pips.
    let against = group(g, list, strings::SETUP_AGAINST, gui::stacked(), FIRST_GROUP_H);
    for i in 4 {
        let on = if i == 0 { s.friend } else { !s.friend && s.level == i - 1 };
        let label = strings::get(if i == 0 { strings::SETUP_FRIEND } else { LEVEL_KEYS[i - 1] });
        let tapped, pic = gui::pick(g, gui::HOME_IDS + 40 + i, across(against, 4, i, u), 30.0, label, "", on, true);
        let w: f32 = if i == 0 { 24.0 } else { 70.0 };
        var mark = gui::center(pic, w * u, pic.w);
        gui::glyph_icon(g, gui::center(gui::cut_left(mark, 24.0 * u), 24.0 * u, 24.0 * u),
                        if i == 0 { gui::FRIEND } else { gui::COMPUTER }, gui::PLAIN, 0.0, 0.85);
        if i > 0 { gui::pips(g, gui::cut_right(mark, 40.0 * u), i, 1.0); }
        if tapped {
            s.friend = i == 0;
            if i > 0 { s.level = i - 1; }
            ask = CHANGED;
        }
    }

    // The draughts, each with its board at the start.
    let kinds = group(g, list, strings::SETUP_DRAUGHTS, BOARD_TILE_H);
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

    if !s.friend {
        // The child's pieces, each tile showing one.
        let colors = group(g, list, strings::SETUP_COLOR, gui::stacked());
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
    } else {
        // The board for a friend's game: staying, the default, first, or turning to the
        // side to move after each move (settings' `turns`), each with its icon over its word and note where the
        // tile holds all three (a touch screen's 88 dp), without it where not (a desktop's).
        let turning = group(g, list, strings::SETUP_BOARD, gui::stacked());
        let words = g.faces[gui::BODY].ascent - g.faces[gui::BODY].descent + g.faces[gui::SMALL].ascent
                    - g.faces[gui::SMALL].descent;
        let icon: f32 = if words + 42.0 * u <= turning.w { 30.0 } else { 0.0 };
        for i in 2 {
            let turns = i == 1;
            let tapped, pic = gui::pick(g, gui::HOME_IDS + 52 + i, across(turning, 2, i, u), icon,
                                        strings::get(if turns { strings::BOARD_TURNS } else { strings::BOARD_STAYS }),
                                        strings::get(if turns { strings::BOARD_TURNS_NOTE } else { strings::BOARD_STAYS_NOTE }),
                                        s.turns == turns, true);
            if icon > 0.0 {
                gui::glyph_icon(g, gui::center(pic, 30.0 * u, 30.0 * u), if turns { gui::TURNS } else { gui::STAYS }, gui::PLAIN,
                                0.0, 0.85);
            }
            if tapped {
                s.turns = turns;
                ask = CHANGED;
            }
        }
    }

    // The clock.
    let clocks = group(g, list, strings::SETUP_CLOCK, gui::stacked());
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
    if scroll {
        gui::fade_edges(g, listed, view, 0.0, c.y + inner - off - bottom, FADE * u);
        gui::scroll_end(g);
    }
    if play_row(g, play) { ask = PLAY; }
    return ask;
}
