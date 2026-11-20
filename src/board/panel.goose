// The panels round the board (docs/architecture/rendering.md, "Game screen"): the way
// out on the left (above the board in portrait) and the play on the right (below it).
// Start over sits far from undo move so it isn't hit for it. layout() places the board
// and both panels for every screen that has them.
namespace panel;
import std;
import vec;

import gui from "../gui";
import strings from "../../strings";

// The moves panel's rows (game/notes.goose) and the moves' line's head (game/sheet.goose),
// in dp, which the layouts size the moves panel by.
let MOVES_ROW = 34.0;
let MOVES_PAD = 12.0;       // round the rows inside the glass
let LINE_HEAD = 30.0;

// What the panels' tiles ask for: the shared asks (gui::ASK_NOTHING..), and the panel's own.
let NOTHING = gui::ASK_NOTHING;
let RESTART = gui::ASK_RESTART;
let BACK = gui::ASK_BACK;
let SETTINGS = gui::ASK_SETTINGS;
let UNDO = 1;
let LOOKOUT = 5;            // the lookout's eye, turned on or off
let HINT = 6;               // the hint's tile

// The lookout's eye, a round toggle at the end of whose turn's line, and the hint's
// tile beside undo move with a pip a hint left; in dp.
let EYE_TOUCH = 56.0;
let EYE_DISC = 48.0;
let PIP = 12.0;             // dp: a hint's pip, and the gap between two
let PIP_GAP = 7.0;
let EYE_ID = gui::PANEL_IDS + 4;
let HINT_ID = gui::PANEL_IDS + 5;
let BOARD_ID = gui::PANEL_IDS + 15;     // the board, a grid to the keys' focus (board::keys)

// The keys' groups (gui::group), in Tab's order.
let GROUP_OUT = 0;
let GROUP_BOARD = 1;
let GROUP_PLAY = 2;

// The board offered to the keys' focus over its bounds on screen, Enter on it a tap when
// `mine`. Returns whether anything changed. `turn` is the 3D board's hot-seat turn in
// degrees: past a quarter turn the arrows go as the turned board shows it.
fn board_keys(g: gui::Gui&, l: Layout, b: board::Board&, mine: bool, now: f64, turn: f32 = 0.0) -> bool {
    gui::group(g, GROUP_BOARD);
    let r = if l.is_3d { l.view.rect } else { float4 { l.board.board.x, l.board.board.y, l.board.board.z, l.board.board.z } };
    var flat = l.board;
    if l.is_3d && turn > 90.0 && turn < 270.0 { flat.flip = !flat.flip; }
    return board::keys(b, flat, g, BOARD_ID, r, mine, now);
}

// What the panel shows of the lookout and the hint: the lookout on; the hints left; how
// far the hint has gone (0 none shown, 1 the piece lit, 2 its square too); whether the
// hint can be pressed now (the side to move's turn, nothing to capture).
struct Help {
    look:  bool = false,
    left:  i64  = 0,
    stage: i64  = 0,
    can:   bool = false,
}

// A panel's room inside its glass, in dp: IN_ACROSS across its narrow way and IN_ALONG
// at its ends.
let IN_ACROSS = 16.0;
let IN_ALONG = 20.0;
let TALL_IN = float2 { IN_ACROSS, IN_ALONG };
let WIDE_IN = float2 { IN_ALONG, IN_ACROSS };

// The tiles' heights, in dp: a tile with its icon over its word is 8 dp taller than
// gui::stacked_tile_height() for the word; undo move's tall tile half again.
fn stack_h() -> f32 { gui::stacked_tile_height() + 8.0 }
fn tall_h() -> f32 { 1.5 * gui::stacked_tile_height() }
let BACK_GAP = 12.0;        // dp between the way out's tiles in landscape
let CLOCK_H = 72.0;
let CLOCK_GAP = 10.0;       // dp: between the clocks in a column
let SHORT_GAP = 36.0;       // dp: the clocks' gap holding the countdown's short line in a corner panel
let MID_GAP = 12.0;         // dp: either side of the short form between side-by-side clocks

let SIDE = 232.0;           // dp: each panel's width in landscape,
let NARROW = 192.0;         // narrowing to this near square
let SQUARISH: f32 = 1.5;    // a landscape narrower than this, width to height, takes NARROW panels (3D)
let BOARD = 720.0;          // dp: the board the panels narrow for
// Portrait, in dp: the bar above the board, its icons over their words where a third of
// it is under STACK_W; the bar's width its tiles don't take; and the play below the
// board, whose turn or the clocks over the hint and undo move.
fn bar_h() -> f32 { gui::tap_size() }
fn bar_stacked_h() -> f32 { stack_h() }
let STACK_W = 170.0;
let BAR_SPARE = 2.0 * IN_ALONG + 2.0 * gui::PAD_WIDE;
fn play_h() -> f32 { 2.0 * IN_ACROSS + CLOCK_H + gui::PAD + gui::tap_size() }
let GAP = 24.0;
// A small window in portrait (gui::compact): the bar a row of icons alone, the play one
// row, and the margins smaller, for the board. An icon's tile is ICON_W × ICON_H dp, under
// the gui::tap_size() floor in compact only.
let ICON_W = 72.0;
let ICON_H = 64.0;
let TOP_COMPACT = ICON_H + 2.0 * gui::PAD;
fn play_compact_h() -> f32 { gui::tap_size() + 2.0 * gui::PAD }
let GAP_COMPACT = 16.0;

// How the panels stand round the board: in landscape short ones in the top corners; in
// portrait a bar above the board and the play below it, or in a small window each one row.
let CORNERS = 1;
let PORTRAIT = 2;
let COMPACT = 3;

// Whether the panels are columns beside the board (landscape), not rows above and below it.
fn columns(l: Layout) -> bool { l.mode == CORNERS }

// Where the board and the panels beside it go, in pixels. A 3D board (`is_3d`) is drawn
// through `view`, its bounds on screen view.rect; `board` is then the flat layout the
// board package plays on, a square in the bounds' middle at rest (`rest`), which taps
// reach through the perspective (view3d::pick). The camera buttons stand in `buttons`, a
// column or a `row`, each a touch area `touch` pixels square holding a disc `disc`
// across; `view` is the camera as they have put it (aim), fitted into `box` clear of
// `keep`, and zoomed into `room` (room.z 0 for no zoom).
struct Layout {
    board:     board::Layout,
    left:      float4,    // x, y, width, height of what leaves the game: back over its panel (the bar above in portrait)
    right:     float4,    // and of the one that plays it (below in portrait)
    is_3d:     bool         = false,
    view:      view3d::View = view3d::View {},
    rest_view: view3d::View = view3d::View {},
    pitch:     f32          = 0.0,
    buttons:   float4       = float4 { 0.0, 0.0, 0.0, 0.0 },
    count:     i64          = 0,
    row:       bool         = false,
    touch:     f32          = 0.0,
    disc:      f32          = 0.0,
    box:       float4       = float4 { 0.0, 0.0, 0.0, 0.0 },
    room:      float4       = float4 { 0.0, 0.0, 0.0, 0.0 },
    keep:      float4[5]    = [float4 { 0.0, 0.0, 0.0, 0.0 }; 5],
    gap:       f32          = 0.0,
    mode:      i64          = CORNERS,
    // The portrait bar's room for its three tiles, above what each side has taken in a
    // game; `stacked` where each icon goes over its word.
    tiles:   float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    stacked: bool   = false,
    // Where what each side has taken goes, as `taken_as` lays it out, each piece
    // `taken_d` pixels across.
    taken:    float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    taken_as: i64    = 0,
    taken_d:  f32    = 0.0,
    // The moves panel (game::moves_panel), z 0 where it has no room.
    moves: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    // Where the moves panel has no room (game::moves_line): the moves' line, its tap, and
    // how it shows; `counts` where what each side has taken shows as counts; `out_row`
    // where back and settings stand side by side over start over. The sheet the line
    // opens, in the safe area `area`, and its room inside.
    line:     float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    line_tap: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    line_as:  i64    = LINE_NONE,
    counts:   bool   = false,
    out_row:  bool   = false,
    area:     float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    sheet:    float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    sheet_in: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
}

// How the moves' line shows.
let LINE_NONE = 0;
let LINE_ROWS = 1;          // a tile at the left column's foot holding the last moves (a phone in landscape)
let LINE_BAR = 2;           // the last move in the portrait bar's row
let LINE_TAP_W = 200.0;     // dp: the portrait line's tap across, from the tiles' foot to the board

// What each side has taken: small pieces, each covering about half the one before, the
// kings after a gap. A piece is TAKEN_D dp, TAKEN_PHONE on a phone, TAKEN_COMPACT in a
// small window.
let TAKEN_NONE = 0;
let TAKEN_PANEL = 1;        // two rows on their own glass
let TAKEN_LINE = 2;         // one line on its own glass, the far side's catch first
let TAKEN_BAR = 3;          // one line on glass as wide as it, centered in `taken`
let TAKEN_ROW = 4;          // the portrait bar's row: white's catch at the left, black's at the right
let TAKEN_STACK = 5;        // two rows, no glass of their own (compact's bar)
let TAKEN_D = 32.0;
let TAKEN_PHONE = 26.0;
let TAKEN_COMPACT = 22.0;
let TAKEN_BAR_ROW = 52.0;   // dp: the portrait bar's row: its cards 42 tall under a 10 dp gap
let TAKEN_CARD_GAP = 10.0;
let TAKEN_CARD_PAD = 10.0;  // dp: either side inside a side's card in that row
let TAKEN_STEP: f32 = 0.52; // of a piece: from one to the next in a row
let TAKEN_GAP:  f32 = 0.3;  // of a piece: before the kings, and between two rows
let TAKEN_PAD = 16.0;       // dp: either side inside their glass
let TAKEN_ROWS_PAD = 14.0;  // dp: above and below two rows on their glass
let TAKEN_LINE_PAD = 8.0;   // dp: above and below one line

// How many pieces of each color have been taken, men and kings apart (board::taken).
struct Taken {
    men:   i64[2] = [0, 0],
    kings: i64[2] = [0, 0],
}

// The left corner column's height in dp: back and settings side by side over start over
// on a touch screen (out_row); on a desktop the three under each other.
fn left_h() -> f32 {
    guard !out_row() else { return 2.0 * stack_h() + BACK_GAP; }
    return 3.0 * gui::tap_size() + 2.0 * BACK_GAP;
}
// Whether the way out stands two tiles over one in landscape: on a touch screen, where
// a taller column would cost the 3D board its size.
fn out_row() -> bool { gui::desktop_scale <= 0.0 }
// The play's corner panel's height in dp: room for three stacked tiles, or for the clocks
// over undo move's tall tile, whichever is more.
fn corner_h() -> f32 {
    return max(gui::tap_size() + BACK_GAP + 2.0 * stack_h() + 3.0 * IN_ALONG,
               2.0 * IN_ALONG + 2.0 * CLOCK_H + CLOCK_GAP + gui::PAD + tall_h());
}
// Two panels' heights in dp, a few over what they hold: a puzzle's play panel on the flat
// board (the piece, the goal, the stars, and next's tall tile), and a phone's narrow play
// panel (whose turn and the eye, the hint over undo move).
let CORNER_PUZZLE = 504.0;
let CORNER_PLAY = 368.0;

// A narrow play panel's height in dp: CORNER_PLAY on a touch screen; on a desktop, whose
// smaller tap leaves more for the moves under it, its glass's ends, the piece with its
// gaps closed up, whose turn's line, and the hint's row and undo move's tile.
fn narrow_play_h() -> f32 {
    guard gui::tap_size() < gui::TAP else { return CORNER_PLAY; }
    return 2.0 * IN_ALONG + (8.0 + 72.0 + 10.0 + 32.0) + gui::PAD + gui::tap_size() + gui::PAD + stack_h();
}
let PITCH_LANDSCAPE: f32 = 52.5;
let PITCH_PORTRAIT:  f32 = 65.0;
// The camera buttons: a touch area and the disc in it, in dp, on a tablet, a phone in
// landscape, and in portrait; BUTTON_GAP between two touch areas, BUTTON_MARGIN from the
// panel or board beside them.
let TOUCH_TABLET = 56.0;
let DISC_TABLET = 44.0;
let TOUCH_PHONE = 48.0;
let DISC_PHONE = 40.0;
let TOUCH_PHONE_PORTRAIT = 52.0;
let DISC_PHONE_PORTRAIT = 42.0;
let BUTTON_GAP = 8.0;
let BUTTON_MARGIN = 12.0;
// Which button is which, top to bottom (left to right in a row): the view, the zoom
// (landscape only), the showcase.
let VIEW = 0;
let ZOOM = 1;
let SHOWCASE = 2;

// The layout round the 3D board in `area`: in landscape short panels in the top corners,
// the board as large as clears them and the camera buttons by half a gap; in portrait
// the bar, the board, the buttons, the play. `game`: the game's screen, with room for
// what each side has taken; `moves`: the moves shown; `taller`: dp more for the play in
// portrait (how to play's back over next).
fn corners_in(area: float4, n: i64, s: f32, portrait_pitch: f32 = PITCH_PORTRAIT, small: bool = true,
              game: bool = false, moves: bool = false, taller: f32 = 0.0) -> Layout {
    let width = area.z;
    let height = area.w;
    let gap = GAP * s;
    let m = BUTTON_MARGIN * s;
    let phone = gui::phone(area, s);   // NARROW panels
    let safe = area;
    if landscape(area, s) {
        // Raised by half the top margin: the board, near edge low, looked low.
        let area = framed_in(area, s, if game && moves { FRAME_WIDE_MOVES } else { FRAME_WIDE_3D }, FRAME_UP_3D);
        let width = area.z;
        let height = area.w;
        // A tablet squarer than 3:2 takes NARROW panels: its board is held by the width
        // between them, not by the height.
        let narrow = phone || width < SQUARISH * height;
        let side = (if narrow { NARROW } else { SIDE }) * s;
        let tall = min(corner_h() * s, height - 2.0 * gap);
        let left = float4 { area.x + gap, area.y + gap, side, min(left_h() * s, height - 2.0 * gap) };
        let play_tall = if narrow { min(narrow_play_h() * s, height - 2.0 * gap) } else { tall };
        let right = float4 { area.x + width - gap - side, area.y + gap, side, play_tall };
        // The buttons under the play panel: a column at the right edge where it fits above
        // the bottom margin, else a row centered under the panel.
        let touch = (if phone { TOUCH_PHONE } else { TOUCH_TABLET }) * s;
        let disc = (if phone { DISC_PHONE } else { DISC_TABLET }) * s;
        let len = 3.0 * touch + 2.0 * BUTTON_GAP * s;
        let x1 = right.x + right.z;
        let y = right.y + right.w + m;
        let col = y + len <= area.y + height - gap;
        let buttons = if col { float4 { x1 - touch, y, touch, len } }
                      else { float4 { right.x + 0.5 * (right.z - len), min(y, area.y + height - touch), len, touch } };
        let box = float4 { area.x + gap, area.y + gap, width - 2.0 * gap, height - 2.0 * gap };
        // The top view's zoom may reach down past a desktop's frame margin to a gap above
        // the window's foot (zoomed): the margin is for the board at rest.
        let room = if gui::desktop_scale > 0.0 { float4 { box.x, box.y, box.z, safe.y + safe.w - gap - box.y } } else { box };
        var l = Layout { board: board::layout_at(0.0, 0.0, 1.0, s, n), left: left, right: right, is_3d: true,
                         pitch: PITCH_LANDSCAPE, buttons: buttons, count: 3, row: !col, touch: touch, disc: disc,
                         box: box, room: room, gap: gap, mode: CORNERS, area: safe, out_row: out_row(), .. };
        l.keep = [left, right, buttons, float4 { 0.0, 0.0, 0.0, 0.0 }, float4 { 0.0, 0.0, 0.0, 0.0 }];
        let cam = view3d::Camera { pitch: PITCH_LANDSCAPE, yaw: 0.0 };
        set_rest_view(l, fit_view(l, cam, n), s);
        guard game else { return l; }
        // A tablet squarer than 3:2: the moves panel above the board, between the corner
        // panels, what each side has taken as counts in its head.
        if moves && !phone && narrow {
            let x0 = left.x + left.z + gap;
            let y = area.y + gap;
            // Down to the board at rest, a row shorter where the top view, whose board
            // reaches higher, needs it.
            let up = fit_view(l, view3d::Camera { pitch: rig::TOP_PITCH, yaw: 0.0 }, n);
            let at_rest = l.rest_view.rect.y - gap - y;
            let rows = ((at_rest / s - 2.0 * MOVES_PAD - LINE_HEAD) / MOVES_ROW) as i64;
            let h = min(at_rest, max(up.rect.y - gap - y, at_rest - MOVES_ROW * s));
            let top = float4 { x0, y, right.x - gap - x0, h };
            if rows >= MOVES_TOP_LEAST && !view3d::touches(l.rest_view, top, 0.5 * gap) {
                l.moves = top;
                l.keep[4] = top;
                l.counts = true;
                l.taken_as = TAKEN_NONE;
                return l;
            }
        }
        // Else MOVES_3D rows under the way out, where they fit, the board shrinking to clear
        // them; then as many rows more as leave the board that size, found by halving.
        if moves && !phone && l.moves.z <= 0.0 {
            let lower = area;
            let base = with_moves(l, lower, s, MOVES_3D, n);
            if base.moves.z <= 0.0 {
                l.moves = float4 { 0.0, 0.0, 0.0, 0.0 };
            } else {
                l = base;
                let most = with_moves(l, lower, s, 0, n);
                var lo = MOVES_3D;
                var hi = ((most.moves.w / s - 2.0 * MOVES_PAD) / MOVES_ROW) as i64;
                if hi > lo && most.rest_view.k >= 0.995 * base.rest_view.k { l = most; }
                else {
                    while hi - lo > 1 {
                        let mid = (lo + hi) / 2;
                        let t = with_moves(base, lower, s, mid, n);
                        if t.rest_view.k >= 0.995 * base.rest_view.k { lo = mid; l = t; } else { hi = mid; }
                    }
                }
            }
        }
        // A phone: the left column as row_fit lays it out, the moves' line at its foot.
        if moves && phone && l.moves.z <= 0.0 {
            row_fit(l, area, s, TAKEN_PHONE * s, left.x + left.z + BACK_GAP * s);
            l.keep[0] = float4 { left.x, left.y, left.z, area.y + height - gap - left.y };
            set_rest_view(l, fit_view(l, cam, n), s);
            return l;
        }
        // What each side has taken: a line at the top between the panels where the board
        // at rest clears it; else under the left panel where the board clears that; else
        // the line, the board shrinking for it.
        let d = (if phone { TAKEN_PHONE } else { TAKEN_D }) * s;
        let x0 = left.x + left.z + gap;
        let bar = float4 { x0, area.y + gap, right.x - gap - x0, d + 2.0 * TAKEN_LINE_PAD * s };
        if !view3d::touches(l.rest_view, bar, 0.5 * gap) {
            l.taken = bar;
            l.taken_as = TAKEN_BAR;
            l.taken_d = d;
            l.keep[3] = bar;
            return l;
        }
        var under = l;
        if l.moves.z > 0.0 { under.taken_as = TAKEN_NONE; } else { under_left(under, area, s, d); }
        // Narrowed to clear the board's near edge, the bounds' widest, down to 3/4.
        under.taken.z = min(under.taken.z, l.rest_view.rect.x - 0.5 * gap - under.taken.x);
        if under.taken.z >= 0.75 * left.z && under.taken_as != TAKEN_NONE && !view3d::touches(l.rest_view, under.taken, 0.5 * gap)
           && !overlaps(under.taken, buttons) {
            l.taken = under.taken;
            l.taken_as = under.taken_as;
            l.taken_d = under.taken_d;
            l.keep[3] = l.taken;
            return l;
        }
        l.taken = bar;
        l.taken_as = TAKEN_BAR;
        l.taken_d = d;
        l.keep[3] = bar;
        set_rest_view(l, fit_view(l, cam, n), s);
        return l;
    }
    let cam = view3d::Camera { pitch: portrait_pitch, yaw: 0.0 };
    let bar = portrait_bar(area, s, small, game, true, taller);
    let gap = bar.gap;
    let top = bar.top;
    let bottom = bar.bottom;
    let touch = (if phone { TOUCH_PHONE_PORTRAIT } else { TOUCH_TABLET }) * s;
    let disc = (if phone { DISC_PHONE_PORTRAIT } else { DISC_TABLET }) * s;
    let len = 2.0 * touch + BUTTON_GAP * s;
    // The bar, the board, a row of buttons at the right edge, the play, centered down the
    // safe area.
    let b = view3d::bounds(cam, n);
    let w = width - 2.0 * gap;
    let room = height - top - bottom - 3.0 * gap - 2.0 * m;
    let h = min(w * b.w / b.z, room - touch);
    let x = area.x + gap;
    let y = area.y + (height - (top + gap + h + 2.0 * m + touch + bottom)) / 2.0;
    let box = float4 { x, y + top + gap, w, h };
    let buttons = float4 { x + w - len, box.y + h + m, len, touch };
    let play = float4 { x, buttons.y + touch + m, w, bottom };
    var l = Layout { board: board::layout_at(0.0, 0.0, 1.0, s, n), left: float4 { x, y, w, top }, right: play,
                     is_3d: true, pitch: portrait_pitch, buttons: buttons, count: 2, row: true, touch: touch,
                     disc: disc, box: box, gap: gap, mode: bar.mode, area: area, .. };
    l.keep = [l.left, play, buttons, float4 { 0.0, 0.0, 0.0, 0.0 }, float4 { 0.0, 0.0, 0.0, 0.0 }];
    bar_tiles(l, bar, game, phone, s, game && moves);
    set_rest_view(l, view3d::fit(cam, n, box, view3d::MIDDLE), s);
    portrait_sheet(l, l.view.rect.y + 0.5 * l.view.rect.w, s);
    return l;
}

// The view at rest, and the flat square the board package plays on, which stays while the
// camera moves.
fn set_rest_view(l: Layout&, v: view3d::View, s: f32) {
    l.rest_view = v;
    l.view = v;
    l.board = view3d::square(v, s);
}

// Whether the board v places (with `field`, its playing field) is clear of what the
// layout keeps clear, by `gap` pixels.
fn clear(v: view3d::View, keep: float4[5]&, gap: f32, field: bool = false) -> bool {
    for r in keep { if view3d::touches(v, r, gap, field) { return false; } }
    return true;
}

// The board seen by `cam` fitted as the layout places it: in landscape the largest share
// of the box, kept at its bottom and centered across, whose board clears the panels and
// the buttons by half a gap, found by halving, the board shrinking as the share does; in
// portrait as large as fits the box, in its middle.
fn fit_view(l: Layout&, cam: view3d::Camera, n: i64) -> view3d::View {
    let box = l.box;
    guard l.count == 3 else { return view3d::fit(cam, n, box, view3d::MIDDLE); }
    let g = 0.5 * l.gap;
    let v = view3d::fit(cam, n, box, view3d::BOTTOM_EDGE);
    if clear(v, l.keep, g) { return v; }
    var lo: f32 = 0.2;
    var hi: f32 = 1.0;
    for i in 20 {
        let k = 0.5 * (lo + hi);
        let b = float4 { box.x + 0.5 * box.z * (1.0 - k), box.y + box.w * (1.0 - k), box.z * k, box.w * k };
        if clear(view3d::fit(cam, n, b, view3d::BOTTOM_EDGE), l.keep, g) { lo = k; } else { hi = k; }
    }
    let b = float4 { box.x + 0.5 * box.z * (1.0 - lo), box.y + box.w * (1.0 - lo), box.z * lo, box.w * lo };
    return view3d::fit(cam, n, b, view3d::BOTTOM_EDGE);
}

// The zoom (landscape): the playing field seen by `cam`, every square and the pieces'
// tops (view3d::outline's field), as large as fits the room, centered across it and, by
// `up` (the share of the way to the top view), from the room's bottom at the rest angle
// to its middle in the top view; its outline clear of the panels and the buttons by a
// quarter gap, found by halving. The room is the box at the rest angle and in the top
// view reaches to the window's foot (corners_in). Where the middle isn't clear it sits lower, at most to
// the room's bottom (field_at's `low`), so space under the board isn't left unused while
// what stands above it holds the board down. The view's rect is the whole board's
// bounds, larger than the room.
fn zoomed(l: Layout&, cam: view3d::Camera, n: i64, up: f32) -> view3d::View {
    // The room reaches lower on the way to the top view: at the rest angle the near
    // rows would crowd the window's edge.
    var room = l.room;
    if l.box.z > 0.0 { room.w = l.box.w + (l.room.w - l.box.w) * up; }
    let f = view3d::bounds(cam, n, true);
    let b = view3d::bounds(cam, n);
    var lo: f32 = 0.0;
    var hi = min(room.z / f.z, room.w / f.w);
    let v, ok = zoom_at(l, cam, n, room, f, b, hi, up);
    if ok { return v; }
    for i in 20 {
        let k = 0.5 * (lo + hi);
        let t, clear = zoom_at(l, cam, n, room, f, b, k, up);
        if clear { lo = k; } else { hi = k; }
    }
    let w, _ = zoom_at(l, cam, n, room, f, b, lo, up);
    return w;
}

// The zoom's view at k pixels a unit where it is clear: in its place, else, on a desktop
// whose room reaches past the box, at the room's bottom; and whether either is. A tablet
// keeps the middle (docs/decisions/rendering.md).
fn zoom_at(l: Layout&, cam: view3d::Camera, n: i64, room: float4, f: float4, b: float4, k: f32,
           up: f32) -> view3d::View, bool {
    let v = field_at(cam, n, room, f, b, k, up, false);
    if zoom_clear(l, v) || l.room.w <= l.box.w { return v, zoom_clear(l, v); }
    let w = field_at(cam, n, room, f, b, k, up, true);
    return w, zoom_clear(l, w);
}

// Whether the zoom's view v clears what stands round it by a quarter gap: the panels and
// the buttons its field, the frame passing under them, and on a desktop, whose frame
// stands raised (FRAME_UP_3D), the cards of what each side has taken at the top the whole
// board. A tablet has no room to spare: its zoom would be no larger than the board at rest.
fn zoom_clear(l: Layout&, v: view3d::View) -> bool {
    guard clear(v, l.keep, 0.25 * l.gap, true) else { return false; }
    return l.taken_as != TAKEN_BAR || gui::desktop_scale <= 0.0 || !view3d::touches(v, l.taken, 0.25 * l.gap);
}

// cam's view at k pixels a unit with the field's bounds f (at k 1) centered across the
// room, at its bottom (`up` 0) or its middle (`up` 1); b the board's bounds, for the rect.
// `low`: as low as the room lets it, the field at its bottom at the rest angle and the
// whole board in the top view, whose frame is seen whole.
fn field_at(cam: view3d::Camera, n: i64, room: float4, f: float4, b: float4, k: f32, up: f32,
            low: bool = false) -> view3d::View {
    let x = room.x + 0.5 * (room.z - f.z * k);
    let below = (b.y + b.w - f.y - f.w) * up;   // the frame shown under the field
    let y = if low { room.y + room.w - (f.w + below) * k } else { room.y + (room.w - f.w * k) * (1.0 - 0.5 * up) };
    let c = float2 { x - f.x * k, y - f.y * k };
    var v = view3d::View { k: k, c: c, rect: float4 { c.x + b.x * k, c.y + b.y * k, b.z * k, b.w * k }, n: n, .. };
    view3d::place(v, cam);
    return v;
}

// The camera as the rig has it at `now`: fitted at the view's angle, zoomed by the zoom's
// share, then turned by the hot-seat turn and tipped by the showcase, which keep the fit,
// so the board stays its size through a turn. The flat layout stays.
fn apply_camera(l: Layout&, r: rig::Rig&, now: f64) {
    guard l.is_3d else { return; }
    let n = l.rest_view.n;
    var fit = rig::base(r, l.pitch, now);
    fit.turn = 0.0;
    var v = if fit.pitch == l.pitch { l.rest_view } else { fit_view(l, fit, n) };
    let z = if l.room.z > 0.0 { rig::value(r.zoom, now) } else { 0.0 };
    if z > 0.0 {
        let q = zoomed(l, fit, n, rig::value(r.top, now));
        v.k += (q.k - v.k) * z;
        v.c = v.c + (q.c - v.c) * z;
        v.rect = v.rect + (q.rect - v.rect) * z;
    }
    l.view = view3d::with_camera_turn(v, rig::camera(r, l.pitch, now));
}

// The camera buttons round the 3D board: the view (a gold dot while the showcase has left
// the board off its rest angle), the zoom in landscape, and the showcase, lit while on.
// Returns whether one was tapped.
fn camera(g: gui::Gui&, l: Layout, r: rig::Rig&, now: f64) -> bool {
    guard l.is_3d && l.count > 0 else { return false; }
    let step = l.touch + BUTTON_GAP * g.scale;
    var tapped = false;
    for i in l.count {
        let what = if l.count == 2 && i == 1 { SHOWCASE } else { i };
        let at = if l.row { float4 { l.buttons.x + i * step, l.buttons.y, l.touch, l.touch } }
                 else { float4 { l.buttons.x, l.buttons.y + i * step, l.touch, l.touch } };
        let icon = if what == VIEW { if rig::top(r) && !rig::off_rest(r) { gui::VIEW_LOW } else { gui::VIEW_TOP } }
                   else if what == ZOOM { if rig::zoomed(r) { gui::ZOOM_OUT } else { gui::ZOOM_IN } }
                   else { gui::SHOWCASE };
        guard gui::floating(g, gui::PANEL_IDS + 10 + what, at, l.disc, icon, what == SHOWCASE && r.showcase,
                            what == VIEW && rig::off_rest(r)) else { continue; }
        tapped = true;
        if what == VIEW { rig::view_tap(r, now); }
        else if what == ZOOM { rig::zoom_tap(r, now); }
        else { rig::showcase_tap(r); }
    }
    return tapped;
}

// The game screen's layout in a whole window.
fn layout(width: f32, height: f32, n: i64) -> Layout {
    return layout_in(float4 { 0.0, 0.0, width, height }, n, gui::scale_of(width, height), true, true);
}

// The landscape layout's panels' width in `area`: SIDE, narrowing to NARROW for the board.
fn side_of(area: float4, s: f32) -> f32 {
    let room = area.z - 4.0 * GAP * s;
    guard room - 2.0 * SIDE * s < BOARD * s else { return SIDE * s; }
    return max(NARROW * s, 0.5 * (room - BOARD * s));
}

// The landscape layout's flat board in `area`: the height less the margins, or what the
// panels leave across.
fn landscape_board(area: float4, s: f32) -> f32 {
    let gap = GAP * s;
    return min(area.w - 2.0 * gap, area.z - 2.0 * side_of(area, s) - 4.0 * gap);
}

// Whether the game takes its landscape layout in `area`: wider than tall, and its flat
// board at least HANDOVER of the height less the margins; else, near square, the portrait
// one. The 3D board takes the same choice, so switching boards keeps the layout.
let HANDOVER = 0.667;
fn landscape(area: float4, s: f32) -> bool {
    return area.z >= area.w && landscape_board(area, s) >= HANDOVER * (area.w - 2.0 * GAP * s);
}

// On a desktop the landscape board and its corner panels stand in a frame: the flat
// board 92% of the height on a window up to FRAME_SMALL points tall, easing to 85% at
// FRAME_LARGE, and the frame at most FRAME_WIDE times as wide as tall, centered, so the
// panels stay near the board. The 3D board's wide near edge must clear the panels, and
// the moves panel takes room beside it, hence the wider frames. A phone and a tablet
// keep every dp for the board.
let FRAME_SMALL = 1000.0;
let FRAME_LARGE = 1440.0;
let FRAME_WIDE = 1.45;
let FRAME_WIDE_3D = 1.7;
let FRAME_WIDE_MOVES = 2.0;
let FRAME_UP_3D = 0.5;
// `up` moves that share of the top margin to the bottom.
fn framed_in(area: float4, s: f32, wide: f32 = FRAME_WIDE, up: f32 = 0.0) -> float4 {
    guard gui::desktop_scale > 0.0 else { return area; }
    let k = clamp((area.w / gui::desktop_scale - FRAME_SMALL) / (FRAME_LARGE - FRAME_SMALL), 0.0, 1.0);
    // A share of the height less the margins on each side: 4% leaves the board 92%, 7.5% 85%.
    let m = (0.04 + 0.035 * k) * (area.w - 2.0 * GAP * s);
    let h = area.w - 2.0 * m;
    let w = min(area.z - 2.0 * m, wide * h);
    return float4 { area.x + 0.5 * (area.z - w), area.y + m * (1.0 - up), w, h };
}

// The flat board's frame on a desktop: framed_in's, and where the width holds the board
// under the height, only as tall as the board and its margins, so the board's top stays
// level with the panels'.
fn flat_frame(area: float4, s: f32) -> float4 {
    var f = framed_in(area, s);
    guard gui::desktop_scale > 0.0 else { return f; }
    let h = landscape_board(f, s) + 2.0 * GAP * s;
    if h < f.w {
        f.y += 0.5 * (f.w - h);
        f.w = h;
    }
    return f;
}

// The flat board's layout in `area`, a screen's safe area, at s pixels a dp: in
// landscape short corner panels (flat_corners); in portrait the bar and the play, as wide
// as the area for the game (`game`). `moves`: the game shows its moves, as a panel or,
// where that has no room, a line. `taller`: dp more for the play in portrait.
fn layout_in(area: float4, n: i64, s: f32, small: bool = true, game: bool = false, moves: bool = false,
             taller: f32 = 0.0) -> Layout {
    let width = area.z;
    let height = area.w;
    let phone = gui::phone(area, s);   // NARROW panels
    if landscape(area, s) {
        let framed = flat_frame(area, s);
        var l = flat_corners(framed, n, s, landscape_board(framed, s), game && moves);
        l.area = area;
        if game && moves && phone && l.moves.z <= 0.0 {
            row_fit(l, framed, s, TAKEN_PHONE * s, l.board.board.x - BACK_GAP * s);
        }
        return l;
    }
    let bar = portrait_bar(area, s, small, game, game, taller);
    let compact = bar.mode == COMPACT;
    let gap = bar.gap;
    let top = bar.top;
    let bottom = bar.bottom;
    let size = min(width - 2.0 * gap, height - top - bottom - 4.0 * gap);
    let x = area.x + (width - size) / 2.0;
    let y = area.y + (height - (top + size + bottom + 2.0 * gap)) / 2.0;
    // Compact and the game's, the panels keep the width where the board is narrower.
    let px = if compact || game { area.x + gap } else { x };
    let pw = if compact || game { width - 2.0 * gap } else { size };
    var l = Layout { board: board::layout_at(x, y + top + gap, size, s, n), left: float4 { px, y, pw, top },
                     right: float4 { px, y + top + gap + size + gap, pw, bottom }, mode: bar.mode, area: area };
    bar_tiles(l, bar, game, phone, s, game && moves);
    portrait_sheet(l, y + top + gap + 0.5 * size, s);
    return l;
}

// A phone in landscape with no room for the moves panel: back and settings side by side
// over start over; under them what each side has taken; at the foot the moves' line, a
// tap at least. Where the catch has no room, the tiles are a tap tall and the catch shows
// as counts at the line's head. The line's sheet runs from the screen's left edge to
// `edge`.
fn row_fit(l: Layout&, area: float4, s: f32, d: f32, edge: f32) {
    let gap = GAP * s;
    let foot = area.y + area.w - gap;
    let column = l.left;
    var st = stack_h() * s;
    var t = l;
    t.left = float4 { column.x, column.y, column.z, 2.0 * st + BACK_GAP * s };
    t.taken_as = TAKEN_NONE;
    under_left_to(t, foot - (gui::tap_size() + BACK_GAP) * s, s, d);
    l.counts = t.taken_as == TAKEN_NONE;
    if l.counts {
        st = gui::tap_size() * s;
        t.left.w = 2.0 * st + BACK_GAP * s;
    }
    l.left = t.left;
    l.out_row = true;
    l.taken = t.taken;
    l.taken_as = t.taken_as;
    l.taken_d = t.taken_d;
    let top = if l.counts { l.left.y + l.left.w + BACK_GAP * s } else { l.taken.y + l.taken.w + BACK_GAP * s };
    l.line = float4 { column.x, top, column.z, foot - top };
    l.line_tap = l.line;
    l.line_as = LINE_ROWS;
    let a = l.area;
    l.sheet = float4 { a.x, a.y, edge - a.x, a.w };
    l.sheet_in = float4 { a.x + 16.0 * s, a.y + 12.0 * s, edge - a.x - 32.0 * s, a.w - 24.0 * s };
}

// The portrait line's sheet: from the board's middle `mid` to the safe area's foot.
fn portrait_sheet(l: Layout&, mid: f32, s: f32) {
    guard l.line_as == LINE_BAR else { return; }
    let a = l.area;
    l.sheet = float4 { a.x, mid, a.z, a.y + a.w - mid };
    l.sheet_in = float4 { a.x + 16.0 * s, mid + 8.0 * s, a.z - 32.0 * s, a.y + a.w - 12.0 * s - (mid + 8.0 * s) };
}

// The portrait bar's and play's heights and the margins in `area` at s pixels a dp:
// compact in a small window (where `small` allows it), else the bar stacked where a third
// of it is under STACK_W, and TAKEN_BAR_ROW taller in a game. The bar is as wide as the
// area less the margins where `wide`, else as wide as the board; the play `taller` dp more
// but in compact.
struct Bar {
    mode:    i64  = PORTRAIT,
    gap:     f32  = 0.0,
    top:     f32  = 0.0,
    bottom:  f32  = 0.0,
    stacked: bool = false,
}
fn portrait_bar(area: float4, s: f32, small: bool, game: bool, wide: bool, taller: f32 = 0.0) -> Bar {
    let width = area.z;
    let height = area.w;
    let compact = small && height < gui::COMPACT * s;
    let gap = (if compact { GAP_COMPACT } else { GAP }) * s;
    let bottom = (if compact { play_compact_h() } else { play_h() + taller }) * s;
    let across = if wide { width - 2.0 * gap }
                 else if width > height { min(width - 2.0 * gap, height - bar_h() * s - bottom - 4.0 * gap) }
                 else { width - 2.0 * gap };
    let narrow = (across - BAR_SPARE * s) / 3.0 < STACK_W * s;
    let extra = if game && !compact { TAKEN_BAR_ROW } else { 0.0 };
    let top = ((if compact { TOP_COMPACT } else if narrow { bar_stacked_h() } else { bar_h() }) + extra) * s;
    return Bar { mode: if compact { COMPACT } else { PORTRAIT }, gap: gap, top: top, bottom: bottom,
                 stacked: narrow && !compact };
}

// The flat board in landscape: short panels in the top corners, no wider than side_of so
// the board keeps its size. With `moves`, the moves panel under the left one where it
// has room (not on a phone), what each side has taken then under the right one; else
// what each side has taken under the left one.
fn flat_corners(area: float4, n: i64, s: f32, size: f32, moves: bool) -> Layout {
    let width = area.z;
    let height = area.w;
    let gap = GAP * s;
    let phone = gui::phone(area, s);   // NARROW panels
    let side = min((if phone { NARROW } else { SIDE }) * s, side_of(area, s));
    let tall = min(corner_h() * s, height - 2.0 * gap);
    let play_tall = if side < SIDE * s - 0.5 { min(narrow_play_h() * s, height - 2.0 * gap) } else { tall };
    let left = float4 { area.x + gap, area.y + gap, side, min(left_h() * s, height - 2.0 * gap) };
    let right = float4 { area.x + width - gap - side, area.y + gap, side, play_tall };
    var l = Layout { board: board::layout_at(area.x + (width - size) / 2.0, area.y + (height - size) / 2.0, size, s, n),
                     left: left, right: right, mode: CORNERS, out_row: out_row(), .. };
    let d = (if phone { TAKEN_PHONE } else { TAKEN_D }) * s;
    if moves && !phone { under(l, l.left, area, s, 0); }
    if l.moves.z > 0.0 { taken_under(l, l.right, area.y + area.w - GAP * s, s, d); }
    else { under_left(l, area, s, d); }
    return l;
}

// The 3D landscape layout `l` with the moves panel `rows` rows under the way out (0 as
// many as `area` holds), the camera's buttons where they were under the play panel, the
// board settled clear of all; moves.z 0 where it doesn't fit.
fn with_moves(l0: Layout, area: float4, s: f32, rows: i64, n: i64) -> Layout {
    var l = l0;
    l.moves = float4 { 0.0, 0.0, 0.0, 0.0 };
    under(l, l.left, area, s, rows);
    guard l.moves.z > 0.0 else { return l; }
    l.keep[4] = l.moves;
    set_rest_view(l, fit_view(l, view3d::Camera { pitch: PITCH_LANDSCAPE, yaw: 0.0 }, n), s);
    return l;
}

// The moves panel under `column` (the way out), as wide, down to the bottom margin (or
// `most` rows, 0 for no limit), where it holds MOVES_LEAST rows.
let MOVES_LEAST = 4;
let MOVES_TOP_LEAST = 3;         // above the 3D board, where it costs the board nothing
let MOVES_GAP = 16.0;           // dp between the way out and the moves panel
let MOVES_GAP_DESKTOP = 24.0;   // more on a desktop
let MOVES_3D = 5;
fn moves_room(rows: i64, s: f32) -> f32 { (rows * MOVES_ROW + 2.0 * MOVES_PAD) * s }
fn under(l: Layout&, column: float4, area: float4, s: f32, most: i64) {
    let gap = GAP * s;
    let x = column.x;
    let w = column.z;
    let y = column.y + column.w + (if gui::desktop_scale > 0.0 { MOVES_GAP_DESKTOP } else { MOVES_GAP }) * s;
    let h = area.y + area.w - gap - y;
    var rows = ((h / s - 2.0 * MOVES_PAD) / MOVES_ROW) as i64;
    if most > 0 { rows = min(rows, most); }
    guard rows >= MOVES_LEAST else { return; }
    l.moves = float4 { x, y, w, moves_room(rows, s) };
}

// A puzzle's layout on the flat board in `area` at s pixels a dp: layout_in's, in
// landscape the play panel CORNER_PUZZLE tall for what it holds, and nothing taken shown;
// in portrait the play `taller` dp more.
fn puzzle_in(area: float4, n: i64, s: f32, taller: f32 = 0.0) -> Layout {
    var l = layout_in(area, n, s, false, false, false, taller);
    guard columns(l) else { return l; }
    l.right.w = min(CORNER_PUZZLE * s, flat_frame(area, s).w - 2.0 * GAP * s);
    l.taken_as = TAKEN_NONE;
    return l;
}

fn overlaps(a: float4, b: float4) -> bool { a.x < b.x + b.z && b.x < a.x + a.z && a.y < b.y + b.w && b.y < a.y + a.w }

// What each side has taken on its own glass under l's left corner panel, its pieces d
// across: two rows where they fit down to the bottom margin, smaller where they must (to
// 3/4), else one line; none where even that has no room.
fn under_left(l: Layout&, area: float4, s: f32, d: f32) { under_left_to(l, area.y + area.w - GAP * s, s, d); }

// The same down to `limit`, a y in pixels.
fn under_left_to(l: Layout&, limit: f32, s: f32, d: f32) { taken_under(l, l.left, limit, s, d); }

// The same under `left`, a corner panel (the play panel's where the moves panel has the
// left one's).
fn taken_under(l: Layout&, left: float4, limit: f32, s: f32, d: f32) {
    let side = left.z;
    let under = left.y + left.w + BACK_GAP * s;
    let room = limit - under;
    let rows = (2.0 + TAKEN_GAP) * d + 2.0 * TAKEN_ROWS_PAD * s;
    let edge = TAKEN_LINE_PAD * s;
    let squeezed = (room - 2.0 * edge) / (2.0 + TAKEN_GAP);
    if room >= rows {
        l.taken = float4 { left.x, under, side, rows };
        l.taken_as = TAKEN_PANEL;
        l.taken_d = d;
    } else if squeezed >= 0.75 * d {
        l.taken = float4 { left.x, under, side, room };
        l.taken_as = TAKEN_PANEL;
        l.taken_d = squeezed;
    } else {
        let one = min(d, room - 2.0 * edge);
        guard one > 0.5 * d else { return; }
        l.taken = float4 { left.x, under, side, one + 2.0 * edge };
        l.taken_as = TAKEN_LINE;
        l.taken_d = one;
    }
}

// The portrait bar's tiles and, in a game, what each side has taken: a row under the
// tiles; compact, the bar's middle between back and settings. With `moves` (not compact)
// the moves' line in that row's middle, the catches either side of it.
fn bar_tiles(l: Layout&, bar: Bar, game: bool, phone: bool, s: f32, moves: bool = false) {
    l.stacked = bar.stacked;
    if l.mode == COMPACT {
        l.tiles = gui::inset(l.left, gui::PAD * s);
        guard game else { return; }
        let t = icons(l.tiles, s);
        let x0 = t[0].x + t[0].z + gui::PAD * s;
        let x1 = t[1].x - gui::PAD * s;
        l.taken = float4 { x0, l.tiles.y, max(x1 - x0, 0.0), l.tiles.w };
        l.taken_as = TAKEN_STACK;
        l.taken_d = TAKEN_COMPACT * s;
        return;
    }
    // In a game a row under the tiles: each side's catch on a card of its own, the moves'
    // line between.
    let row = if game { TAKEN_BAR_ROW * s } else { 0.0 };
    l.tiles = float4 { l.left.x, l.left.y, l.left.z, l.left.w - row };
    guard game else { return; }
    let h = (TAKEN_BAR_ROW - TAKEN_CARD_GAP) * s;
    l.taken = float4 { l.left.x, l.left.y + l.left.w - h, l.left.z, h };
    l.taken_as = TAKEN_ROW;
    l.taken_d = (if phone { TAKEN_PHONE } else { TAKEN_D }) * s;
    guard moves else { return; }
    let mid = l.taken.x + 0.5 * l.taken.z;
    let w = LINE_TAP_W * s;
    let top = l.tiles.y + l.tiles.w;
    l.line_tap = float4 { mid - 0.5 * w, top, w, l.left.y + l.left.w + bar.gap - top };
    l.line = float4 { mid - 0.5 * w + 12.0 * s, l.taken.y, w - 24.0 * s, l.taken.w };
    l.line_as = LINE_BAR;
}

// The compact bar's icons in its tiles' room r: back at the left, settings and start over
// at the right, the board between start over and undo move.
fn icons(r: float4, s: f32) -> float4[3] {
    var bar = r;
    let tw = ICON_W * s;
    let back = gui::cut_left(bar, tw);
    let restart = gui::cut_right(bar, tw);
    gui::cut_right(bar, gui::PAD * s);
    let gear = gui::cut_right(bar, tw);
    return [back, gear, restart];
}

// The countdown before a draw under whose turn: a line of words, and in landscape a row
// of `of` dots, `lit` of them lit; `more` adds "A third time is a draw" under the line.
// Between clocks with no room for the line, the short form instead: `word` and `fig`,
// "Draw in" and "3". Empty for none.
struct Note {
    line: u8[..64] = [],
    more: bool     = false,
    lit:  i64      = 0,
    of:   i64      = 0,
    word: u8[..24] = [],
    fig:  u8[..8]  = [],
}

// Both pieces side by side, just touching, white on the left: a draw's mark where a
// winner's piece goes. Each of radius r, overlapping by `overlap` pixels, at opacity a.
fn pair(ui_pieces: board::Overlay&, spot: float4, r: f32, overlap: f32, a: f32) {
    let w = 4.0 * r - overlap;
    let x = spot.x + 0.5 * (spot.z - w);
    piece(ui_pieces, float4 { x, spot.y, 2.0 * r, spot.w }, r, 0, 0, a, 0.0);
    piece(ui_pieces, float4 { x + 2.0 * r - overlap, spot.y, 2.0 * r, spot.w }, r, 1, 0, a, 0.0);
}

// Words in w pixels of face `face`: where they break in two, the lines as even as they
// can be, or -1 for one line.
fn note_break(g: gui::Gui&, face: i64, s: const u8[:], w: f32) -> i64 {
    guard gui::text_width(g, face, s) > w else { return -1; }
    var best = -1;
    var widest = w;
    for c, i in s {
        guard c == 32 else { continue; }
        let longer = max(gui::text_width(g, face, s[..i]), gui::text_width(g, face, s[i + 1..]));
        if longer <= widest {
            widest = longer;
            best = i;
        }
    }
    return best;
}

// The countdown under whose turn in landscape, at the top of r: the dots, then the line,
// broken in two where it doesn't fit, and the second line, dimmer. Where r is too short
// for all of it (a 3D board's corner panel), the dots go, then the words take the small
// face; where even that doesn't fit, it shows nothing.
fn countdown(g: gui::Gui&, r: float4&, note: Note&) {
    guard note.of > 0 else { return; }
    let u = g.scale;
    let line = note.line[..note.line.len];
    let more = if note.more { strings::get(strings::COUNT_THIRD) } else { strings::get(strings::DRAW) };
    var face = gui::BODY;
    var dots = true;
    var fits = false;
    for k in 3 {
        face = if k < 2 { gui::BODY } else { gui::SMALL };
        dots = k == 0;
        let gaps: f32 = if dots { 40.0 } else { 10.0 };
        if words_height(g, face, line, more, note.more, r.z) + gaps * u <= r.w {
            fits = true;
            break;
        }
    }
    guard fits else { return; }
    if dots {
        gui::cut_top(r, 14.0 * u);
        let row = gui::cut_top(r, 14.0 * u);
        for i in note.of {
            let d = gui::cell(row, note.of, 1, 14.0 * u, 14.0 * u, 9.0 * u, i);
            if i < note.lit { gui::glow_fill(g, d, 1.0, 7.0 * u); }
            else { gui::rounded_rect(g, d, float4 { 1.0, 1.0, 1.0, 0.18 }, 7.0 * u); }
        }
        gui::cut_top(r, gui::PAD * u);
    } else {
        gui::cut_top(r, 10.0 * u);
    }
    words(g, face, r, line, 1.0);
    if note.more { words(g, face, r, more, 0.66); }
}

// The short form between side-by-side clocks in r: the word over the figure.
fn short_stacked(g: gui::Gui&, r: float4, note: Note&) {
    let small = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    let big = g.faces[gui::LABEL].ascent - g.faces[gui::LABEL].descent;
    var c = gui::center(r, r.z, small + big);
    gui::text(g, gui::SMALL, gui::cut_top(c, small), note.word[..note.word.len], 1.0, 0.0, gui::CENTER);
    gui::text(g, gui::LABEL, c, note.fig[..note.fig.len], 1.0, 0.0, gui::CENTER);
}

// The short form between stacked clocks, in one line.
fn short_line(g: gui::Gui&, r: float4, note: Note&) {
    var s: u8[..48] = [];
    s.append(note.word[..note.word.len]);
    s.push(' ');
    s.append(note.fig[..note.fig.len]);
    gui::text(g, gui::SMALL, r, s[..s.len], 1.0, 0.0, gui::CENTER);
}

// How tall the countdown's words are in w pixels of face `face`.
fn words_height(g: gui::Gui&, face: i64, line: const u8[:], more: const u8[:], has_more: bool, w: f32) -> f32 {
    let f .= g.faces[face];
    let h = f.ascent - f.descent;
    var n: f32 = if note_break(g, face, line, w) >= 0 { 2.0 } else { 1.0 };
    if has_more { n += if note_break(g, face, more, w) >= 0 { 2.0 } else { 1.0 }; }
    return n * h;
}

// Words centered at the top of r in face `face`, broken in two where they don't fit.
fn words(g: gui::Gui&, face: i64, r: float4&, s: const u8[:], a: f32) {
    let f .= g.faces[face];
    let h = f.ascent - f.descent;
    let cut = note_break(g, face, s, r.z);
    if cut >= 0 {
        gui::text(g, face, gui::cut_top(r, h), s[..cut], a, 0.0, gui::CENTER);
        gui::text(g, face, gui::cut_top(r, h), s[cut + 1..], a, 0.0, gui::CENTER);
    } else {
        gui::text(g, face, gui::cut_top(r, h), s, a, 0.0, gui::CENTER);
    }
}

// A piece of `side` over the UI centered in `spot` with radius r, at opacity a, a man (0)
// or a king (board::CROWN, board::STACK), with a glow ring right round it as strong as
// `ring`, 0 to 1.
fn piece(ui_pieces: board::Overlay&, spot: float4, r: f32, side: i64, king: i64, a: f32, ring: f32) {
    guard ui_pieces.len < board::OVER else { return; }
    let x = spot.x + 0.5 * spot.z;
    let y = spot.y + 0.5 * spot.w;
    ui_pieces.push(board::Piece { at: float4 { x, y, r, 0.0 }, look: float4 { side, king, 0.0, a },
                             ring: float4 { 0.0, ring, 0.0, 0.0 } });
}

// What the clocks show, as the game's clock has it (game::clocks): whether there are any,
// the side whose clock runs, or -1, and each side's style (gui::CLOCK_*) and time.
struct Clocks {
    on:      bool       = false,
    running: i64        = -1,
    style:   i64[2]     = [0, 0],
    text:    u8[..8][2] = [[], []],
}

// One side's clock in r: its piece and its time, lit while it runs (gold under a
// minute, red at 20 seconds or under), faint while it waits; its piece's ring as strong
// as `ring`.
fn clock_of(g: gui::Gui&, r: float4, c: Clocks&, side: i64, ring: f32, ui_pieces: board::Overlay&) {
    let u = g.scale;
    let runs = c.running == side;
    let style = c.style[side];
    gui::clock_tile(g, r, style);
    var room = r;
    gui::cut_left(room, 14.0 * u);
    gui::cut_right(room, 14.0 * u);
    let spot = gui::cut_left(room, 44.0 * u);
    piece(ui_pieces, spot, 22.0 * u, side, 0,
          if runs { 1.0 } else { 0.7 }, ring);
    let t = c.text[side];
    // A clock narrowed for the lookout's eye beside it takes a smaller face where its
    // time doesn't fit.
    let face = if gui::text_width(g, gui::FIGURES, t) <= room.z { gui::FIGURES } else { gui::face_that_fits(g, gui::LABEL, t, room.z) };
    gui::figures(g, face, room, t, if runs { 1.0 } else { 0.66 }, style, gui::RIGHT);
}

// The way out: back, settings, and start over, far from what plays. Returns BACK,
// SETTINGS, RESTART, or NOTHING.
let OUT_WORDS = [strings::NAV_BACK, strings::HOME_SETTINGS, strings::GAME_START_OVER];
fn leave(g: gui::Gui&, l: Layout) -> i64 {
    // The words' widths, measured first, where they are shown: not the compact bar's icons,
    // nor back's in landscape, which measures its word itself.
    var words: f32[3] = [0.0, 0.0, 0.0];
    if l.mode != COMPACT {
        let first = if columns(l) { 1 } else { 0 };
        for i in first..3 { words[i] = gui::text_width(g, gui::HEADING, strings::get(OUT_WORDS[i])); }
    }
    let o = way_out(l, words, g.scale);
    let icons = [gui::BACK, gui::GEAR, gui::RESTART];
    let asks = [BACK, SETTINGS, RESTART];
    var chosen = NOTHING;
    gui::group(g, GROUP_OUT);
    if columns(l) {
        if gui::back(g, gui::PANEL_IDS, o.tiles[0], strings::get(OUT_WORDS[0]), l.out_row) { chosen = BACK; }
        gui::under_tile(g, o.tiles[1], 22.0);
        gui::under_tile(g, o.tiles[2], 22.0);
    } else if l.mode == COMPACT {
        gui::panel(g, l.left);
    } else {
        for t in o.tiles { gui::under_tile(g, t, 22.0); }
    }
    for i in 3 {
        guard i > 0 || !columns(l) else { continue; }
        let tapped = if o.arrange == ICON { gui::button(g, gui::PANEL_IDS + i, o.tiles[i], icons[i]) }
                     else { gui::labelled(g, gui::PANEL_IDS + i, o.tiles[i], icons[i], 34.0, strings::get(OUT_WORDS[i]),
                                          gui::HEADING, o.arrange) };
        if tapped { chosen = asks[i]; }
    }
    return chosen;
}

// Where the way out's tiles go: back, settings, start over; and how each tile lays out
// its icon and word (gui::MIDDLE, STACKED, or ICON alone).
struct Out {
    tiles:   float4[3] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 3],
    arrange: i64       = gui::MIDDLE,
}

// The way out's tiles in l at u pixels a dp, `words` the three words' widths in the
// heading face.
fn way_out(l: Layout, words: f32[3], u: f32) -> Out {
    var o = Out {};
    if columns(l) && l.out_row {
        // Back and settings side by side over start over.
        let c = l.left;
        let st = 0.5 * (c.w - BACK_GAP * u);
        let half = 0.5 * (c.z - BACK_GAP * u);
        o.tiles[0] = float4 { c.x, c.y, half, st };
        o.tiles[1] = float4 { c.x + c.z - half, c.y, half, st };
        o.tiles[2] = float4 { c.x, c.y + c.w - st, c.z, st };
        o.arrange = gui::STACKED;
        return o;
    }
    if columns(l) {
        var column = l.left;
        o.tiles[0] = gui::cut_top(column, gui::tap_size() * u);
        // Each icon beside its word, or, where a word doesn't fit so in a narrowed column,
        // both icons over their words, as tall as the column leaves them.
        for i in 1..3 {
            if labelled_width(u, 34.0, words[i]) > column.z { o.arrange = gui::STACKED; }
        }
        let want = (if o.arrange == gui::MIDDLE { gui::tap_size() } else { stack_h() }) * u;
        let h = max(0.0, min(want, 0.5 * (column.w - 2.0 * BACK_GAP * u)));
        o.tiles[1] = float4 { column.x, column.y + BACK_GAP * u, column.z, h };
        o.tiles[2] = float4 { column.x, column.y + 2.0 * BACK_GAP * u + h, column.z, h };
        return o;
    }
    if l.mode == COMPACT {
        o.tiles = icons(l.tiles, u);
        o.arrange = ICON;
        return o;
    }
    // Thirds of the bar while each word fits its third; else each tile as wide as its
    // word wants and an even share of the rest, as the setup's draughts are. A bar made
    // taller for it (bar_stacked_h()) puts each icon over its word, which needs less width.
    o.arrange = if l.stacked { gui::STACKED } else { gui::MIDDLE };
    let bar = l.tiles;
    let gap = (if l.stacked { 12.0 } else { 16.0 }) * u;
    let free = bar.z - 2.0 * gap;
    var wants: f32[3] = [0.0, 0.0, 0.0];
    var fits = true;
    for i in 3 {
        let want = if l.stacked { words[i] + 2.0 * gui::LABEL_PAD * u } else { labelled_width(u, 34.0, words[i]) };
        wants[i] = max(want, gui::tap_size() * u);
        if wants[i] > free / 3.0 { fits = false; }
    }
    let share = (free - wants[0] - wants[1] - wants[2]) / 3.0;
    let even = fits || share < 0.0;
    var x = bar.x;
    for i in 3 {
        let w = if even { free / 3.0 } else { wants[i] + share };
        o.tiles[i] = if even { float4 { bar.x + i * (w + gap), bar.y, w, bar.w } } else { float4 { x, bar.y, w, bar.w } };
        x += w + gap;
    }
    return o;
}

// gui::labelled_width from the word's width `word` at u pixels a dp, its icon `size` dp.
fn labelled_width(u: f32, size: f32, word: f32) -> f32 {
    return (2.0 * gui::LABEL_PAD + size + 12.0) * u + word;
}

// r less `room` dp (TALL_IN, WIDE_IN) at s pixels a dp across and down, each side.
fn inside(r: float4, room: float2, s: f32) -> float4 {
    return float4 { r.x + room.x * s, r.y + room.y * s, r.z - 2.0 * room.x * s, r.w - 2.0 * room.y * s };
}

// How tall the right panel's bottom tile is in landscape: tall_h(), or stack_h() in a phone's
// narrow corner panel.
fn tall(l: Layout, u: f32) -> f32 { (if l.right.z < SIDE * u - 0.5 { stack_h() } else { tall_h() }) * u }

// The right panel's room inside its glass, where a screen plays.
fn play_area(g: gui::Gui&, l: Layout) -> float4 { play_room(l, g.scale) }
fn play_room(l: Layout, u: f32) -> float4 {
    if columns(l) { return inside(l.right, TALL_IN, u); }
    return inside(l.right, WIDE_IN, u);
}

// What the play panel shows this frame, as far as where things go: the clocks or whose
// turn, the countdown's lines (`counting`), a draw, and the widths of its words, measured
// first (Words).
struct Shows {
    clocks:   bool = false,
    counting: bool = false,
    drawn:    bool = false,
}
struct Words {
    heading: f32 = 0.0,     // the heading face's height
    turn:    f32 = 0.0,     // whose turn's words, in the heading face,
    turn_s:  f32 = 0.0,     // and in the small one
    line:    f32 = 0.0,     // the countdown's line in the small face
    short:   f32 = 0.0,     // its short form, the word or the figure, the wider
    undo:    f32 = 0.0,     // undo move's word, the hint's, in the heading face
    hint:    f32 = 0.0,
    undo2:   f32 = 0.0,     // undo move's and the hint's widest line on two, in the small face
    hint2:   f32 = 0.0,
    name:    f32 = 0.0,     // the lookout's name in the body face
}

// Where the play panel's parts go (column_play, compact_play, portrait_play): the two
// clocks, the far player's first, and the countdown's short form between them; else
// whose turn's piece in `spot`, `r` pixels round (both overlapping by `overlap` for a
// draw), and its words; the lookout's name; the countdown's line (`note`); and the eye,
// the hint, and undo move, each laid out as `*_as` says with its icon `*_icon` dp.
let SHORT_NONE = 0;
let SHORT_LINE = 1;
let SHORT_STACKED = 2;
struct Play {
    clocks:    float4[2] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 2],
    short:     float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    short_as:  i64       = SHORT_NONE,
    spot:      float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    r:         f32       = 0.0,
    overlap:   f32       = 0.0,
    words:     float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    name:      float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    note:      float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    eye:       float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    hint:      float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    hint_as:   i64       = gui::MIDDLE,
    hint_icon: f32       = 0.0,
    undo:      float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    undo_as:   i64       = gui::STACKED,
    undo_icon: f32       = 0.0,
}

// The landscape column: where the panel is tall enough, whose turn or the clocks, the
// lookout's eye and name, the hint over undo move. Else the eye at the end of whose
// turn's line or beside the clocks, the hint beside undo move where both keep a tap
// across or over it, the gaps round the piece closed up where the panel is short.
fn column_play(l: Layout, w: Words, on: Shows, u: f32) -> Play {
    var p = Play { r: 36.0 * u, overlap: 6.0 * u, .. };
    var right = play_room(l, u);
    // A corner panel's short line between the clocks takes from undo move what the
    // panel lacks, and leaves a gap above it.
    let squeezed = on.clocks && on.counting && !on.drawn;
    // The hint beside undo move where both keep a tap across and each word fits its half
    // on two lines at most; the tiles are tall then, for their icons over those lines.
    let half = 0.5 * (right.z - gui::PAD * u) - 2.0 * gui::LABEL_PAD * u;
    let pair = right.z >= (2.0 * gui::tap_size() + gui::PAD) * u && half >= max(w.undo2, w.hint2);
    let wanted = if pair { tall_h() * u } else { tall(l, u) };
    let low = if squeezed { min(wanted, right.w - (2.0 * CLOCK_H + SHORT_GAP + 12.0) * u) } else { wanted };
    let head = if on.clocks { (2.0 * CLOCK_H + CLOCK_GAP) * u } else { (18.0 + 72.0 + 18.0) * u + w.heading };
    let column = right.w >= head + (EYE_TOUCH + gui::PAD + gui::tap_size() + gui::PAD) * u + low;
    let beside = !column && pair;
    let tight = !column && !beside && right.w < head + (gui::PAD + gui::tap_size() + gui::PAD) * u + low;
    p.undo = gui::cut_bottom(right, low);
    if beside {
        p.hint = gui::cut_left(p.undo, 0.5 * (p.undo.z - gui::PAD * u));
        gui::cut_left(p.undo, gui::PAD * u);
    } else {
        gui::cut_bottom(right, gui::PAD * u);
        p.hint = gui::cut_bottom(right, gui::tap_size() * u);
    }
    p.undo_icon = if beside { 36.0 } else { 48.0 };
    p.hint_as = if beside { gui::STACKED } else { gui::MIDDLE };
    p.hint_icon = if beside { 36.0 } else { 34.0 };
    if on.clocks {
        let extra = if squeezed { (SHORT_GAP - CLOCK_GAP) * u } else { 0.0 };
        var clocks = gui::cut_top(right, head + extra);
        if !column {
            p.eye = gui::center(gui::cut_right(clocks, EYE_TOUCH * u), EYE_TOUCH * u, EYE_TOUCH * u);
            gui::cut_right(clocks, 6.0 * u);
        }
        p.clocks[0] = gui::cut_top(clocks, CLOCK_H * u);
        if squeezed {
            p.short = gui::cut_top(clocks, SHORT_GAP * u);
            p.short_as = SHORT_LINE;
        } else {
            gui::cut_top(clocks, CLOCK_GAP * u);
        }
        p.clocks[1] = gui::cut_top(clocks, CLOCK_H * u);
    } else {
        // The piece, its glow ring, and the words under it; both pieces for a draw. A
        // countdown in a 3D board's short corner panel closes the gaps up.
        let close = on.counting || tight;
        gui::cut_top(right, (if close { 8.0 } else { 18.0 }) * u);
        p.spot = gui::cut_top(right, 72.0 * u);
        if !column {
            // The piece stays centered over the words where the panel is wide enough.
            p.eye = gui::center(gui::cut_right(p.spot, EYE_TOUCH * u), EYE_TOUCH * u, EYE_TOUCH * u);
            if p.spot.z - EYE_TOUCH * u >= 72.0 * u { gui::cut_left(p.spot, EYE_TOUCH * u); }
        }
        gui::cut_top(right, (if close { 10.0 } else { 18.0 }) * u);
        p.words = gui::cut_top(right, w.heading);
    }
    if column {
        // The eye and its name under whose turn.
        let line = gui::cut_top(right, EYE_TOUCH * u);
        let wide = EYE_TOUCH * u + 4.0 * u + w.name;
        var pair_r = gui::center(line, min(wide, line.z), line.w);
        p.eye = gui::cut_left(pair_r, EYE_TOUCH * u);
        gui::cut_left(pair_r, 4.0 * u);
        p.name = pair_r;
    }
    if !on.clocks { p.note = right; }
    return p;
}

// A small window's play (compact): one row, whose turn (or the two clocks) at the left,
// undo move at the right. The eye at the end of whose turn's line, the hint between it
// and undo move, each its icon over its word, or icons alone with clocks and where the
// words would leave whose turn too little room for its own in the small face.
fn compact_play(l: Layout, w: Words, on: Shows, u: f32) -> Play {
    var p = Play { r: 22.0 * u, overlap: 4.0 * u, undo_icon: 28.0, hint_icon: 28.0, .. };
    var row = float4 { l.right.x + gui::PAD * u, l.right.y + gui::PAD * u, l.right.z - 2.0 * gui::PAD * u, l.right.w - 2.0 * gui::PAD * u };
    let mark = (if on.drawn { 84.0 } else { 44.0 }) * u;
    let sides = 2.0 * gui::LABEL_PAD * u;
    let undo_wants = max(gui::tap_size() * u, w.undo + sides);
    let hint_wants = max(gui::tap_size() * u, w.hint + sides);
    let words = row.z - undo_wants - hint_wants - (8.0 + 4.0 + EYE_TOUCH + 4.0 + 12.0) * u - mark;
    let icons = on.clocks || words < w.turn_s;
    p.undo = gui::cut_right(row, if icons { ICON_W * u } else { undo_wants });
    gui::cut_right(row, 8.0 * u);
    p.hint = gui::cut_right(row, if icons { ICON_W * u } else { hint_wants });
    gui::cut_right(row, 4.0 * u);
    p.eye = gui::center(gui::cut_right(row, EYE_TOUCH * u), EYE_TOUCH * u, EYE_TOUCH * u);
    gui::cut_right(row, 4.0 * u);
    p.undo_as = if icons { ICON } else { gui::STACKED };
    p.hint_as = p.undo_as;
    if on.clocks {
        // The countdown's short form between them, as in portrait.
        let between = on.counting && !on.drawn;
        let gap = if between { w.short + 2.0 * MID_GAP * u } else { 8.0 * u };
        let half = 0.5 * (row.z - gap);
        let mid = gui::center(row, row.z, CLOCK_H * u);
        p.clocks[0] = float4 { mid.x, mid.y, half, mid.w };
        p.clocks[1] = float4 { mid.x + half + gap, mid.y, half, mid.w };
        if between {
            p.short = float4 { mid.x + half, mid.y, gap, mid.w };
            p.short_as = SHORT_STACKED;
        }
        return p;
    }
    p.spot = gui::cut_left(row, mark);
    gui::cut_left(row, gui::PAD * u);
    p.words = row;
    return p;
}

// Portrait: the play below the board, the eye at the end of whose turn's line (or of the
// clocks side by side), the hint and undo move halves of the row under it.
fn portrait_play(l: Layout, w: Words, on: Shows, u: f32) -> Play {
    var p = Play { r: 26.0 * u, overlap: 4.0 * u, undo_as: gui::MIDDLE, undo_icon: 36.0, hint_as: gui::MIDDLE,
                   hint_icon: 36.0, .. };
    var right = play_room(l, u);
    var top = gui::cut_top(right, CLOCK_H * u);
    gui::cut_top(right, gui::PAD * u);
    p.eye = gui::center(gui::cut_right(top, EYE_TOUCH * u), EYE_TOUCH * u, EYE_TOUCH * u);
    gui::cut_right(top, 8.0 * u);
    if on.clocks {
        let between = on.counting && !on.drawn;
        let mid = if between { w.short + 2.0 * MID_GAP * u } else { gui::PAD_WIDE * u };
        let half = 0.5 * (top.z - mid);
        p.clocks[0] = gui::cut_left(top, half);
        p.clocks[1] = gui::cut_right(top, half);
        if between {
            p.short = top;
            p.short_as = SHORT_STACKED;
        }
    } else {
        // The piece beside the words, centered; both pieces for a draw. The countdown's
        // line goes under the words.
        let mark = (if on.drawn { 100.0 } else { 52.0 }) * u;
        let span = mark + 18.0 * u + max(w.turn, w.line);
        var row = gui::center(top, span, top.w);
        p.spot = gui::cut_left(row, mark);
        gui::cut_left(row, 18.0 * u);
        p.words = row;
    }
    var row = gui::cut_top(right, gui::tap_size() * u);
    p.undo = gui::cut_right(row, 0.5 * (row.z - gui::PAD_WIDE * u));
    gui::cut_right(row, gui::PAD_WIDE * u);
    p.hint = row;
    return p;
}

// Declares the panels for this frame, with the clocks `c`, and `side` the side to move,
// or the winner when `won`; when `drawn`, both pieces and "Draw" instead. The side to
// move's piece has a ring as strong as `glow`; it pulses while the computer thinks. The
// countdown before a draw, `note`, goes under whose turn, or in its short form between
// clocks with no room for the line. Pieces shown on the panels go into `ui_pieces`.
// Returns the tile tapped this frame, if any. Without `out` the way out is left
// undeclared: the moves' sheet covers it.
fn game(g: gui::Gui&, l: Layout, c: Clocks, side: i64, won: bool, drawn: bool, note: Note&, thinking: bool,
        glow: f32, ui_pieces: board::Overlay&, help: Help = Help {}, out: bool = true) -> i64 {
    let u = g.scale;
    let turn_key = if drawn { strings::DRAW }
                   else if won { if side == 0 { strings::WON_WHITE } else { strings::WON_BLACK } }
                   else if side == 0 { strings::TURN_WHITE } else { strings::TURN_BLACK };
    let label = strings::get(turn_key);
    let line = note.line[..note.line.len];
    let hint_word = strings::get(if help.stage == 1 { strings::GAME_WHERE_TO } else { strings::GAME_HINT });
    let name = strings::get(strings::GAME_LOOKOUT);
    let on = Shows { clocks: c.on, counting: note.of > 0, drawn: drawn };
    // The words the mode's layout reads, measured first; only those, as this runs each frame.
    var w = Words {};
    if on.clocks && on.counting {
        w.short = max(gui::text_width(g, gui::SMALL, note.word[..note.word.len]),
                      gui::text_width(g, gui::LABEL, note.fig[..note.fig.len]));
    }
    match l.mode {
        COMPACT => {
            w.turn_s = gui::text_width(g, gui::SMALL, label);
            w.undo = gui::text_width(g, gui::HEADING, strings::get(strings::GAME_UNDO_MOVE));
            w.hint = gui::text_width(g, gui::HEADING, hint_word);
        },
        PORTRAIT => {
            w.turn = gui::text_width(g, gui::HEADING, label);
            w.line = gui::text_width(g, gui::SMALL, line);
        },
        _ => {
            let heading .= g.faces[gui::HEADING];
            w.heading = heading.ascent - heading.descent;
            w.name = gui::text_width(g, gui::BODY, name);
            w.undo2 = gui::two_lines(g, gui::SMALL, strings::get(strings::GAME_UNDO_MOVE));
            w.hint2 = gui::two_lines(g, gui::SMALL, hint_word);
        },
    }
    let p = match l.mode { COMPACT => compact_play(l, w, on, u), PORTRAIT => portrait_play(l, w, on, u),
                           _ => column_play(l, w, on, u) };
    var chosen = if out { leave(g, l) } else { NOTHING };
    gui::group(g, GROUP_PLAY);
    gui::panel(g, l.right);
    if on.clocks {
        // The clock nearer the player whose pieces are at the bottom goes second: under
        // the other in landscape, right of it in portrait.
        let first = if l.board.flip { 0 } else { 1 };
        var rings: f32[2] = [0.0, 0.0];
        for s in 2 { if c.running == s || (thinking && s == side) { rings[s] = glow; } }
        clock_of(g, p.clocks[0], c, first, rings[first], ui_pieces);
        if p.short_as == SHORT_LINE { short_line(g, p.short, note); }
        clock_of(g, p.clocks[1], c, 1 - first, rings[1 - first], ui_pieces);
        if p.short_as == SHORT_STACKED { short_stacked(g, p.short, note); }
    } else {
        if drawn { pair(ui_pieces, p.spot, p.r, p.overlap, 1.0); }
        else { piece(ui_pieces, p.spot, p.r, side, 0, 1.0, glow); }
        turn_words(g, l, p.words, label, line, on.counting);
    }
    if p.name.z > 0.0 {
        // The lookout's name, dim while off.
        let dim: f32 = if help.look { 1.0 } else { 0.66 };
        gui::text(g, gui::face_that_fits(g, gui::BODY, name, p.name.z), p.name, name, dim, 0.0, gui::LEFT);
    }
    var rest = p.note;
    if rest.z > 0.0 { countdown(g, rest, note); }
    let undo_word = strings::get(strings::GAME_UNDO_MOVE);
    if p.undo_as == ICON {
        if gui::button(g, gui::PANEL_IDS + 3, p.undo, gui::UNDO) { chosen = UNDO; }
    } else if gui::labelled(g, gui::PANEL_IDS + 3, p.undo, gui::UNDO, p.undo_icon, undo_word, gui::HEADING, p.undo_as) {
        chosen = UNDO;
    }
    if hint_tile(g, p.hint, p.hint_as, help, p.hint_icon) { chosen = HINT; }
    if eye(g, p.eye, help.look) { chosen = LOOKOUT; }
    return chosen;
}

// Whose turn's words in r: in landscape one line centered, in the heading face or a
// smaller one where it doesn't fit; else at r's left, and the countdown's line under them
// in the small face when `counting`, the faces fitted to r in a small window's row.
fn turn_words(g: gui::Gui&, l: Layout, r: float4, label: const u8[:], line: const u8[:], counting: bool) {
    let u = g.scale;
    if columns(l) {
        gui::text(g, gui::face_that_fits(g, gui::HEADING, label, r.z), r, label, 1.0, 0.0, gui::CENTER);
        return;
    }
    let fit = l.mode == COMPACT;
    let face = if fit { gui::face_that_fits(g, gui::HEADING, label, r.z) } else { gui::HEADING };
    guard counting else {
        gui::text(g, face, r, label, 1.0, 0.0, gui::LEFT);
        return;
    }
    let head = g.faces[face].ascent - g.faces[face].descent;
    let small = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    var words = gui::center(r, r.z, head + 2.0 * u + small);
    gui::text(g, face, gui::cut_top(words, head), label, 1.0, 0.0, gui::LEFT);
    gui::cut_top(words, 2.0 * u);
    let small_face = if fit { gui::face_that_fits(g, gui::SMALL, line, words.z) } else { gui::SMALL };
    gui::text(g, small_face, gui::cut_top(words, small), line, 1.0, 0.0, gui::LEFT);
}

// The lookout's eye in its touch area r: a floating disc, lit in the glow with the open
// eye while on, the eye struck through and dim while off. True when it is tapped.
fn eye(g: gui::Gui&, r: float4, on: bool) -> bool {
    let u = g.scale;
    let icon = if on { gui::EYE } else { gui::EYE_OFF };
    let a: f32 = if on { 1.0 } else { 0.55 };
    return gui::floating(g, EYE_ID, gui::center(r, EYE_TOUCH * u, EYE_TOUCH * u), EYE_DISC * u, icon, on, false, a);
}

// The hint's tile in r: the bulb and its word over a pip for each hint, a pip lit for
// each left, laid out as `arrange` has it (ICON: the bulb over the pips alone), the bulb
// `size` dp. Its word is Hint, or Where to? once it has lit the piece; lit in the glow
// while it shows; dim, taking no tap, with no hint left or none to give. True when tapped.
let ICON = 3;
let HINTS = 3;              // the pips: a game's hints
fn hint_tile(g: gui::Gui&, r: float4, arrange: i64, help: Help, size: f32) -> bool {
    let u = g.scale;
    let on = help.can && (help.stage > 0 || help.left > 0);
    let clicked, p = gui::press_widget_if_on(g, HINT_ID, r, on);
    let a: f32 = if on { 1.0 } else { 0.35 };
    let style = if help.stage > 0 { gui::CHOSEN } else { gui::PLAIN };
    gui::add(g, gui::Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { gui::BUTTON, 22.0 * u, 0.0, p },
                            extra: float4 { u, style, gui::hover(g, HINT_ID), 0.0 } });
    let word = strings::get(if help.stage == 1 { strings::GAME_WHERE_TO } else { strings::GAME_HINT });
    let s = size * u;
    let f .= g.faces[gui::HEADING];
    let line = f.ascent - f.descent;
    let pips_w = (HINTS * PIP + (HINTS - 1) * PIP_GAP) * u;
    if arrange == ICON || arrange == gui::STACKED {
        let words: f32 = if arrange == ICON { 0.0 } else { line + 6.0 * u };
        var c = gui::center(r, r.z, s + 6.0 * u + words + PIP * u);
        gui::glyph_icon(g, gui::center(gui::cut_top(c, s), s, s), gui::HINT, gui::PLAIN, p, a);
        gui::cut_top(c, 6.0 * u);
        if arrange != ICON {
            let room = r.z - 2.0 * gui::LABEL_PAD * u;
            gui::text(g, gui::face_that_fits(g, gui::HEADING, word, room), gui::cut_top(c, line), word, a, 0.0, gui::CENTER);
            gui::cut_top(c, 6.0 * u);
        }
        pips(g, gui::center(gui::cut_top(c, PIP * u), pips_w, PIP * u), help.left, a);
        return clicked;
    }
    let gap = gui::PAD * u;
    let room = r.z - s - gap - 2.0 * gui::LABEL_PAD * u;
    let face = gui::face_that_fits(g, gui::HEADING, word, room);
    let w = s + gap + max(gui::text_width(g, face, word), pips_w);
    var c = gui::center(r, min(w, r.z), r.w);
    gui::glyph_icon(g, gui::center(gui::cut_left(c, s), s, s), gui::HINT, gui::PLAIN, p, a);
    gui::cut_left(c, gap);
    var lbl = gui::center(c, c.z, line + PIP_GAP * u + PIP * u);
    gui::text(g, face, gui::cut_top(lbl, line), word, a, 0.0, gui::LEFT);
    gui::cut_top(lbl, PIP_GAP * u);
    pips(g, float4 { lbl.x, lbl.y, pips_w, PIP * u }, help.left, a);
    return clicked;
}

// A pip for each of a game's hints in r, `left` of them lit in the glow, the rest faint.
fn pips(g: gui::Gui&, r: float4, left: i64, a: f32) {
    let u = g.scale;
    for i in HINTS {
        let d = float4 { r.x + i * (PIP + PIP_GAP) * u, r.y, PIP * u, PIP * u };
        if i < left { gui::glow_fill(g, d, a, 0.5 * PIP * u); }
        else { gui::rounded_rect(g, d, float4 { 1.0, 1.0, 1.0, 0.2 * a }, 0.5 * PIP * u); }
    }
}

// What each side has taken, where the layout puts it: `t` counts the pieces of each
// color taken, so black's catch is t's white pieces. A catch on its own glass shows only
// once a piece has been taken. The pieces go into `ui_pieces`.
fn taken(g: gui::Gui&, l: Layout, t: Taken, ui_pieces: board::Overlay&) {
    guard l.taken_as != TAKEN_NONE && l.taken.z > 0.0 && l.taken.w > 0.0 else { return; }
    let u = g.scale;
    let d = l.taken_d;
    let r = l.taken;
    // The catch nearer the top first: black's (white's pieces) over white's, as black's
    // side of the board is, unless the board is turned.
    let first = if l.board.flip { rules::BLACK } else { rules::WHITE };
    let any = t.men[0] + t.kings[0] + t.men[1] + t.kings[1] > 0;
    let edge = TAKEN_PAD * u;
    if l.taken_as == TAKEN_PANEL || l.taken_as == TAKEN_STACK {
        guard any || l.taken_as == TAKEN_STACK else { return; }
        var inner = r;
        if l.taken_as == TAKEN_PANEL {
            gui::panel(g, r);
            inner = float4 { r.x + edge, r.y, r.z - 2.0 * edge, r.w };
        }
        let gap = TAKEN_GAP * d;
        let y = inner.y + 0.5 * (inner.w - 2.0 * d - gap);
        catch_row(ui_pieces, t, first, float4 { inner.x, y, inner.z, d }, false);
        catch_row(ui_pieces, t, 1 - first, float4 { inner.x, y + d + gap, inner.z, d }, false);
        return;
    }
    if l.taken_as == TAKEN_ROW {
        // Each side's catch on a card of its own, as wide as it, where it has taken
        // something: white's (black's pieces) at the left, black's at the right, each in
        // at most its half less a gap; beside the moves' line in its side of the line's
        // tap, as pieces where both fit there at TAKEN_LEAST, else as counts.
        let inset = TAKEN_CARD_PAD * u;
        let strip = float4 { l.taken.x + inset, l.taken.y, l.taken.z - 2.0 * inset, l.taken.w };
        let y = strip.y + 0.5 * (strip.w - d);
        var half = 0.5 * (strip.z - TAKEN_GAP * d);
        var counts = false;
        if l.line_as == LINE_BAR {
            half = l.line_tap.x - TAKEN_GAP * d - strip.x;
            let least = TAKEN_LEAST * d;
            counts = row_len(t, rules::BLACK, least) > half || row_len(t, rules::WHITE, least) > half;
        }
        for k in 2 {
            let c = if k == 0 { rules::BLACK } else { rules::WHITE };
            guard t.men[c] + t.kings[c] > 0 else { continue; }
            let right = c == rules::WHITE;
            let w = if counts { count_w(g, t, c, d) } else { min(row_len(t, c, d), half) };
            let x = if right { strip.x + strip.z - w } else { strip.x };
            gui::glass(g, float4 { x - inset, l.taken.y, w + 2.0 * inset, l.taken.w }, 0.5 * l.taken.w / u);
            let at = float4 { if right { strip.x + strip.z - half } else { strip.x }, strip.y, half, strip.w };
            if counts { count_at(g, ui_pieces, t, c, at, d, right); }
            else { catch_row(ui_pieces, t, c, float4 { at.x, y, half, d }, right); }
        }
        return;
    }
    guard any else { return; }
    if l.taken_as == TAKEN_BAR {
        // Each side's catch on a card of its own, as wide as it, either side of the bar's
        // middle: white's (black's pieces) at the left, as portrait's row has them.
        let inset = TAKEN_CARD_PAD * u;
        let mid = r.x + 0.5 * r.z;
        let half = 0.5 * (r.z - TAKEN_CARD_GAP * u) - 2.0 * inset;
        for k in 2 {
            let c = if k == 0 { rules::BLACK } else { rules::WHITE };
            guard t.men[c] + t.kings[c] > 0 else { continue; }
            let w = min(row_len(t, c, d), half);
            let x = if k == 0 { mid - 0.5 * TAKEN_CARD_GAP * u - inset - w } else { mid + 0.5 * TAKEN_CARD_GAP * u + inset };
            gui::glass(g, float4 { x - inset, r.y, w + 2.0 * inset, r.w }, 0.5 * r.w / u);
            catch_row(ui_pieces, t, c, float4 { x, r.y + 0.5 * (r.w - d), w, d }, false);
        }
        return;
    }
    // One line on its glass, the far side's catch first.
    let a = first;
    let b = 1 - a;
    let mid = (if row_len(t, a, d) > 0.0 && row_len(t, b, d) > 0.0 { 24.0 } else { 0.0 }) * u;
    let glass = r;
    gui::glass(g, glass, min(28.0, 0.5 * glass.w / u));
    let inner = float4 { glass.x + edge, glass.y + 0.5 * (glass.w - d), glass.z - 2.0 * edge, d };
    // Each catch in at most its share of the room, as long as it wants.
    let la = row_len(t, a, d);
    let lb = row_len(t, b, d);
    let room = inner.z - mid;
    let wa = if la + lb <= room { la } else { room * la / (la + lb) };
    catch_row(ui_pieces, t, a, float4 { inner.x, inner.y, wa, d }, false);
    catch_row(ui_pieces, t, b, float4 { inner.x + wa + mid, inner.y, inner.z - wa - mid, d }, false);
}

// The pieces of color `c` taken as a count in r: a piece d across and the number after
// it, from r's left, or ending at its right (`right`). Returns how wide it is.
fn count_at(g: gui::Gui&, ui_pieces: board::Overlay&, t: Taken, c: i64, r: float4, d: f32, right: bool) -> f32 {
    let u = g.scale;
    let s = count_text(t, c);
    let tw = gui::text_width(g, gui::BODY, s[..s.len]);
    let gap = 6.0 * u;
    let w = d + gap + tw;
    let x = if right { r.x + r.z - w } else { r.x };
    piece(ui_pieces, float4 { x, r.y + 0.5 * (r.w - d), d, d }, 0.5 * d, c, 0, 1.0, 0.0);
    gui::text(g, gui::BODY, float4 { x + d + gap, r.y, tw, r.w }, s[..s.len], 1.0, 0.0, gui::LEFT);
    return w;
}

// The number of pieces of color `c` taken, as text.
fn count_text(t: Taken, c: i64) -> u8[..8] {
    var s: u8[..8] = [];
    let n = t.men[c] + t.kings[c];
    if n >= 10 { s.push(('0' + (n / 10) % 10) as u8); }
    s.push(('0' + n % 10) as u8);
    return s;
}

// How wide count_at draws the pieces of color `c` taken, d across.
fn count_w(g: gui::Gui&, t: Taken, c: i64, d: f32) -> f32 {
    let s = count_text(t, c);
    return d + 6.0 * g.scale + gui::text_width(g, gui::BODY, s[..s.len]);
}

// How long a row of the pieces of color `c` taken is at its usual spacing, d across each.
fn row_len(t: Taken, c: i64, d: f32) -> f32 {
    let n = t.men[c] + t.kings[c];
    guard n > 0 else { return 0.0; }
    let gap = if t.men[c] > 0 && t.kings[c] > 0 { TAKEN_GAP * d } else { 0.0 };
    return (n - 1) * TAKEN_STEP * d + d + gap;
}

// The pieces of color `c` taken, in a row in r (at most r.w across each), from its left,
// or ending at its right (`right`). A row that would run past r takes smaller pieces,
// down to TAKEN_LEAST of r.w, then closer ones.
let TAKEN_LEAST: f32 = 0.7;
fn catch_row(ui_pieces: board::Overlay&, t: Taken, c: i64, r: float4, right: bool) {
    let n = t.men[c] + t.kings[c];
    guard n > 0 && r.z > 0.0 else { return; }
    let both = t.men[c] > 0 && t.kings[c] > 0;
    let gaps: f32 = if both { TAKEN_GAP } else { 0.0 };
    let d = clamp(r.z / ((n - 1) * TAKEN_STEP + 1.0 + gaps), TAKEN_LEAST * r.w, r.w);
    let gap = gaps * d;
    var step = TAKEN_STEP * d;
    if n > 1 && (n - 1) * step + d + gap > r.z { step = max((r.z - d - gap) / (n - 1), 0.1 * d); }
    let len = (n - 1) * step + d + gap;
    var x = if right { r.x + r.z - len } else { r.x };
    let y = r.y + 0.5 * (r.w - d);
    for i in n {
        let king = i >= t.men[c];
        if king && i == t.men[c] && t.men[c] > 0 { x += gap; }
        piece(ui_pieces, float4 { x, y, d, d }, 0.5 * d, c, if king { board::CROWN } else { 0 }, 1.0, 0.0);
        x += step;
    }
}
