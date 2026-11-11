// The game screen's panels (docs/architecture/rendering.md, "Game screen";
// prototypes/game.html, and "The way back" there for back): the board between
// them, leaving the game on the left (back on its own glass tile over a panel of
// settings and start over at the bottom) and playing it on the right (whose turn, or the
// two clocks, and undo move at the bottom, a tall tile). Each control is a glass tile
// with an icon and a word. In portrait the left side is a bar of three above the board,
// back first, and the right one is below it: whose turn or the clocks side by side, over
// undo move across the width. Start over sits far from undo move so it isn't hit for it.
// layout() places the board and the two panels, for every screen that has them.
namespace panel;
import std;
import vec;

import gui from "../gui";
import board from "../board";
import strings from "../../strings";

// What the panels' tiles ask for: the shared asks (gui::ASK_NOTHING..), and the panel's own.
let NOTHING = gui::ASK_NOTHING;
let RESTART = gui::ASK_RESTART;
let BACK = gui::ASK_BACK;
let SETTINGS = gui::ASK_SETTINGS;
let UNDO = 1;
let LOOKOUT = 5;            // the lookout's eye, turned on or off
let HINT = 6;               // the hint's tile

// The lookout and the hint on the play panel (prototypes/coach.html, round 3, take a):
// the lookout a round toggle at the end of whose turn's line, a 56 dp target round a
// 48 dp disc as the 3D board's camera buttons are, with its name under whose turn in the
// landscape column; the hint a tile beside undo move, its word over a pip a hint left.
let EYE_TOUCH = 56.0;
let EYE_DISC = 48.0;
let HINT_H = 88.0;          // dp: the hint's tile over undo move in the landscape column
let PIP = 12.0;             // dp: a hint's pip, and the gap between two
let PIP_GAP = 7.0;
let EYE_ID = gui::PANEL_IDS + 4;
let HINT_ID = gui::PANEL_IDS + 5;

// What the panel shows of the lookout and the hint: the lookout on; the hints left; how
// far the hint has gone (0 none shown, 1 the piece lit, 2 its square too); whether the
// hint can be pressed now (the side to move's turn, nothing to capture).
struct Help {
    look:  bool = false,
    left:  i64  = 0,
    stage: i64  = 0,
    can:   bool = false,
}

let ROW_H = 88.0;           // dp: a control's row, the 88 dp a small hand needs
let BACK_GAP = 12.0;        // dp: back over the left panel in landscape
let TALL_H = 132.0;         // undo move in landscape, STACK_H in a panel under SHORT
let SHORT = 420.0;          // dp: a panel this short (a phone) has the shorter tile
let WIDE_H = 88.0;          // undo move in portrait
let CLOCK_H = 72.0;
let SHORT_GAP = 36.0;       // dp: the clocks' gap holding the countdown's short line in a corner panel
let MID_GAP = 12.0;         // dp: either side of the short form between side-by-side clocks

let SIDE = 232.0;           // dp: each panel's width in landscape,
let NARROW = 192.0;         // narrowing to this near square
let BOARD = 720.0;          // dp: the board the panels narrow for, the tablet's at 16:10
let PANEL_LEAST = 372.0;    // dp: a landscape panel's height at least, room for its tiles
let STACK_H = 96.0;         // dp: a tile with its icon over its word
let TOP = 120.0;            // dp: the bar above the board in portrait,
let TOP_STACKED = 128.0;    // with its icons over their words where the bar is narrow:
let STACK_W = 170.0;        // dp: a third of the bar under which it is
let BAR_SPARE = 72.0;       // dp: the bar's width its tiles don't take, WIDE_IN at both ends and two 16 dp gaps
let BOTTOM = 204.0;         // dp: the play below it
let GAP = 24.0;
// A small window in portrait (gui::compact, task 050): the bar a row of icons alone, the
// play one row, whose turn beside undo move, and the margins smaller, for the board.
let TOP_COMPACT = 88.0;     // dp: the bar, its 64 dp tiles and 12 dp round them
let BOTTOM_COMPACT = 112.0; // dp: the play, its 88 dp row and 12 dp round it
let ICON_W = 72.0;          // dp: an icon's tile in the bar, 64 dp tall (accepted under the
// 88 dp floor in compact only, the user 2026-11-09)
let GAP_COMPACT = 16.0;
// A panel's room inside its glass, in dp, across and down: a tall one's (a landscape
// column, the play beside the board) 16 at the sides and 20 above and below, a wide
// one's (the bar, the play under the board) the other way round.
let TALL_IN = float2 { 16.0, 20.0 };
let WIDE_IN = float2 { 20.0, 16.0 };

// How the panels stand round the board: in landscape as tall as it at its sides (a
// puzzle's flat board), or short ones in the top corners (the game's flat board, and the
// 3D board's); in portrait a bar above the board and the play below it, or in a small
// window (gui::compact, task 050) each one row.
let LANDSCAPE = 0;
let CORNERS = 1;
let PORTRAIT = 2;
let COMPACT = 3;

// Whether the panels are columns beside the board (landscape), not rows above and below it.
fn columns(l: Layout) -> bool { l.mode == LANDSCAPE || l.mode == CORNERS }

// Where the board and the panels beside it go, in pixels. A 3D board (`three`) is drawn
// through `view`, its bounds on screen view.rect; `board` is then the flat layout the
// board package plays on, a square of the bounds' height in their middle at rest
// (`rest`), which taps reach through the perspective (view3d::pick) and which the 3D
// board's world follows (view3d::to_world). Round the 3D board the camera buttons stand
// in `buttons` (a column, or a row where a column doesn't fit), `count` of them, each a
// touch area `touch` pixels square holding a disc `disc` across; `view` is the camera as
// they have put it (aim), fitted into `box` clear of `keep` (the panels and the
// buttons), and zoomed into `room` (room.z 0 for no zoom: portrait); `pitch` the
// camera's angle at rest.
struct Layout {
    board:   board::Layout,
    left:    float4,      // x, y, width, height of what leaves the game: back over its panel (the bar above in portrait)
    right:   float4,      // and of the one that plays it (below in portrait)
    three:   bool         = false,
    view:    view3d::View = view3d::View {},
    rest:    view3d::View = view3d::View {},
    pitch:   f32          = 0.0,
    buttons: float4       = float4 { 0.0, 0.0, 0.0, 0.0 },
    count:   i64          = 0,
    row:     bool         = false,
    touch:   f32          = 0.0,
    disc:    f32          = 0.0,
    box:     float4       = float4 { 0.0, 0.0, 0.0, 0.0 },
    room:    float4       = float4 { 0.0, 0.0, 0.0, 0.0 },
    keep:    float4[4]    = [float4 { 0.0, 0.0, 0.0, 0.0 }; 4],
    gap:     f32          = 0.0,
    mode:    i64          = LANDSCAPE,
    // The portrait bar's room for its three tiles inside its glass (task 050's compact
    // row too), above what each side has taken in a game; `stacked` where each icon goes
    // over its word (TOP_STACKED).
    tiles:   float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    stacked: bool   = false,
    // Where what each side has taken goes (task 052), as `taken_as` lays it out, each
    // piece `taken_d` pixels across; TAKEN_NONE where the screen shows none (a puzzle).
    taken:    float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    taken_as: i64    = 0,
    taken_d:  f32    = 0.0,
}

// What each side has taken (task 052, prototypes/game-captured.html's take a, its `row`
// look): the app's pieces small, each covering about half the one before, the kings after
// a gap, crowned. Landscape, flat: a small glass panel under the left corner panel, black's
// catch (the white pieces) over white's, as black's side of the board is above white's
// (under it on a turned board); one line where the panel has no height for two (a short
// phone with its gesture bar). Landscape, 3D: one line on glass above the board, at the
// top between the corner panels, white's catch at the left and black's at the right, as
// in portrait's row. Portrait: a row under the bar's tiles, the bar TAKEN_ROW taller.
// Compact: the bar's empty middle, two rows as the flat panel's. A piece is TAKEN_D dp,
// TAKEN_PHONE on a phone, TAKEN_COMPACT in a small window.
let TAKEN_NONE = 0;
let TAKEN_PANEL = 1;        // two rows on their own glass
let TAKEN_LINE = 2;         // one line on its own glass, the far side's catch first
let TAKEN_BAR = 3;          // one line on glass as wide as it, centered in `taken`
let TAKEN_ROW = 4;          // the portrait bar's row: white's catch at the left, black's at the right
let TAKEN_STACK = 5;        // two rows, no glass of their own (compact's bar)
let TAKEN_D = 32.0;
let TAKEN_PHONE = 26.0;
let TAKEN_COMPACT = 22.0;
let TAKEN_BAR_ROW = 52.0;   // dp: the portrait bar's row for them, 36 under a 16 dp gap
let TAKEN_STEP: f32 = 0.52; // of a piece: from one to the next in a row
let TAKEN_GAP:  f32 = 0.3;  // of a piece: before the kings, and between two rows
let TAKEN_PAD = 16.0;       // dp: either side inside their glass
let TAKEN_ROWS_PAD = 14.0;  // dp: above and below two rows on their glass
let TAKEN_LINE_PAD = 8.0;   // dp: above and below one line

// How many pieces of each color have been taken, men and kings apart (game::taken).
struct Taken {
    men:   i64[2] = [0, 0],
    kings: i64[2] = [0, 0],
}

// The game screen round the 3D board (task 015, prototypes/game3d.html's `corners` with
// its camera buttons at `a`): in landscape short glass panels in the top corners, the
// board's far edge narrowing between them and its wide near edge running under them, as
// large as clears them and the camera buttons by half a gap, the buttons a column under
// the play panel (a row where a column doesn't fit: a phone); in portrait the order of
// the flat board's, the bar, the board, the buttons at the right edge, the play,
// with the board as wide as the screen less the gaps and as tall as its perspective at
// PITCH_PORTRAIT makes it, steeper than landscape's to fill more of the height. A puzzle
// shares it.
let CORNER_H = 352.0;       // dp: a corner panel, room for three tiles with their icons over their words (back and a panel of two on the left)
let CORNER_PLAY = 368.0;    // dp: a phone's narrow play panel, room for whose turn and the eye, the hint over undo move
let PITCH_LANDSCAPE: f32 = 52.5;
let PITCH_PORTRAIT:  f32 = 65.0;
// The camera buttons (the user, 2026-11-09): a touch area and the disc in it, in dp, on a
// tablet (not gui::phone), a phone in landscape, and in portrait;
// BUTTON_GAP between two touch areas, BUTTON_MARGIN from the panel or board beside them.
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

// `game`: the game's screen, with room for what each side has taken.
fn corners_in(area: float4, n: i64, s: f32, portrait_pitch: f32 = PITCH_PORTRAIT, small: bool = true,
              game: bool = false) -> Layout {
    let width = area.z;
    let height = area.w;
    let gap = GAP * s;
    let m = BUTTON_MARGIN * s;
    let phone = gui::phone(area, s);   // NARROW panels
    if landscape(area, s) {
        let side = (if phone { NARROW } else { SIDE }) * s;
        let tall = min(CORNER_H * s, height - 2.0 * gap);
        let left = float4 { area.x + gap, area.y + gap, side, tall };
        let play_tall = if phone { min(CORNER_PLAY * s, height - 2.0 * gap) } else { tall };
        let right = float4 { area.x + width - gap - side, area.y + gap, side, play_tall };
        // The buttons under the play panel at the right edge: a column where it fits above
        // the bottom margin, else a row, as low as the safe area lets it.
        let touch = (if phone { TOUCH_PHONE } else { TOUCH_TABLET }) * s;
        let disc = (if phone { DISC_PHONE } else { DISC_TABLET }) * s;
        let len = 3.0 * touch + 2.0 * BUTTON_GAP * s;
        let x1 = right.x + right.z;
        let y = right.y + right.w + m;
        let col = y + len <= area.y + height - gap;
        let buttons = if col { float4 { x1 - touch, y, touch, len } }
                      else { float4 { x1 - len, min(y, area.y + height - touch), len, touch } };
        let box = float4 { area.x + gap, area.y + gap, width - 2.0 * gap, height - 2.0 * gap };
        var l = Layout { board: board::layout_at(0.0, 0.0, 1.0, s, n), left: left, right: right, three: true,
                         pitch: PITCH_LANDSCAPE, buttons: buttons, count: 3, row: !col, touch: touch, disc: disc,
                         box: box, room: box, gap: gap, mode: CORNERS, .. };
        l.keep = [left, right, buttons, float4 { 0.0, 0.0, 0.0, 0.0 }];
        let cam = view3d::Camera { pitch: PITCH_LANDSCAPE, yaw: 0.0 };
        rest(l, settle(l, cam, n), s);
        guard game else { return l; }
        // What each side has taken: a line at the top between the panels, which the board
        // clears as it clears them, where the board at rest already does (a tablet). Else
        // (a phone, whose board reaches the top margin) in the free corner under the left
        // panel, as on the flat screen, where the board clears that; else the line, the
        // board shrinking for it.
        let d = (if phone { TAKEN_PHONE } else { TAKEN_D }) * s;
        let x0 = left.x + left.z + gap;
        let bar = float4 { x0, area.y + gap, right.x - gap - x0, d + 2.0 * TAKEN_LINE_PAD * s };
        if !view3d::touches(l.rest, bar, 0.5 * gap) {
            l.taken = bar;
            l.taken_as = TAKEN_BAR;
            l.taken_d = d;
            l.keep[3] = bar;
            return l;
        }
        var under = l;
        under_left(under, area, s, d);
        // Narrowed to clear the board's near edge, the bounds' widest, down to 3/4.
        under.taken.z = min(under.taken.z, l.rest.rect.x - 0.5 * gap - under.taken.x);
        if under.taken.z >= 0.75 * left.z && under.taken_as != TAKEN_NONE && !view3d::touches(l.rest, under.taken, 0.5 * gap)
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
        rest(l, settle(l, cam, n), s);
        return l;
    }
    let cam = view3d::Camera { pitch: portrait_pitch, yaw: 0.0 };
    let bar = portrait_bar(area, s, small, game, true);
    let gap = bar.gap;
    let top = bar.top;
    let bottom = bar.bottom;
    let touch = (if phone { TOUCH_PHONE_PORTRAIT } else { TOUCH_TABLET }) * s;
    let disc = (if phone { DISC_PHONE_PORTRAIT } else { DISC_TABLET }) * s;
    let len = 2.0 * touch + BUTTON_GAP * s;
    // The bar, the board, the buttons between the board and the play at the right edge,
    // the play, centered down the safe area: the buttons a column where the board keeps
    // the width beside it, else a row, which takes less of the height.
    let b = view3d::bounds(cam, n);
    let w = width - 2.0 * gap;
    let room = height - top - bottom - 3.0 * gap - 2.0 * m;
    let col = w * b.w / b.z <= room - len;
    let tall = if col { len } else { touch };
    let h = min(w * b.w / b.z, room - tall);
    let x = area.x + gap;
    let y = area.y + (height - (top + gap + h + 2.0 * m + tall + bottom)) / 2.0;
    let box = float4 { x, y + top + gap, w, h };
    let buttons = if col { float4 { x + w - touch, box.y + h + m, touch, len } }
                  else { float4 { x + w - len, box.y + h + m, len, touch } };
    let play = float4 { x, buttons.y + tall + m, w, bottom };
    var l = Layout { board: board::layout_at(0.0, 0.0, 1.0, s, n), left: float4 { x, y, w, top }, right: play,
                     three: true, pitch: portrait_pitch, buttons: buttons, count: 2, row: !col, touch: touch,
                     disc: disc, box: box, gap: gap, mode: bar.mode, .. };
    l.keep = [l.left, play, buttons, float4 { 0.0, 0.0, 0.0, 0.0 }];
    bar_tiles(l, bar, game, phone, s);
    rest(l, view3d::fit(cam, n, box, view3d::MIDDLE), s);
    return l;
}

// The view at rest, and the flat square the board package plays on, which stays while the
// camera moves.
fn rest(l: Layout&, v: view3d::View, s: f32) {
    l.rest = v;
    l.view = v;
    l.board = view3d::square(v, s);
}

// Whether the board v places (with `field`, its playing field) is clear of what the
// layout keeps clear, by `gap` pixels.
fn clear(v: view3d::View, keep: float4[4]&, gap: f32, field: bool = false) -> bool {
    for r in keep { if view3d::touches(v, r, gap, field) { return false; } }
    return true;
}

// The board seen by `cam` fitted as the layout places it: in landscape the largest share
// of the box, kept at its bottom and centered across, whose board clears the panels and
// the buttons by half a gap, found by halving, the board shrinking as the share does; in
// portrait as large as fits the box, in its middle.
fn settle(l: Layout&, cam: view3d::Camera, n: i64) -> view3d::View {
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
// tops (view3d::outline's field), as large as fits the room, at its bottom and centered
// across it, its outline clear of the panels and the buttons by a quarter gap, found by
// halving. The view's rect is the whole board's bounds, larger than the room.
fn zoomed(l: Layout&, cam: view3d::Camera, n: i64) -> view3d::View {
    let room = l.room;
    let f = view3d::bounds(cam, n, true);
    let b = view3d::bounds(cam, n);
    var lo: f32 = 0.0;
    var hi = min(room.z / f.z, room.w / f.w);
    let v = field_at(cam, n, room, f, b, hi);
    if clear(v, l.keep, 0.25 * l.gap, true) { return v; }
    for i in 20 {
        let k = 0.5 * (lo + hi);
        if clear(field_at(cam, n, room, f, b, k), l.keep, 0.25 * l.gap, true) { lo = k; } else { hi = k; }
    }
    return field_at(cam, n, room, f, b, lo);
}

// cam's view at k pixels a unit with the field's bounds f (at k 1) at the room's bottom,
// centered across; b the board's bounds, for the rect.
fn field_at(cam: view3d::Camera, n: i64, room: float4, f: float4, b: float4, k: f32) -> view3d::View {
    let x = room.x + 0.5 * (room.z - f.z * k);
    let y = room.y + room.w - f.w * k;
    let c = float2 { x - f.x * k, y - f.y * k };
    var v = view3d::View { k: k, c: c, rect: float4 { c.x + b.x * k, c.y + b.y * k, b.z * k, b.w * k }, n: n, .. };
    view3d::place(v, cam);
    return v;
}

// The camera as the rig has it at `now` (board/rig.goose): fitted at the view's angle and
// the board's turn as the layout places the board (so it shrinks mid-turn to keep clear
// of the panels), zoomed by the zoom's share, then turned and tipped by the showcase,
// which keeps the fit. At rest it is the rest view, turned. The flat layout stays.
fn aim(l: Layout&, r: rig::Rig&, now: f64) {
    guard l.three else { return; }
    let n = l.rest.n;
    let fit = rig::base(r, l.pitch, now);
    let half = fit.turn - 180.0 * floor(fit.turn / 180.0);
    var v = if fit.pitch == l.pitch && half == 0.0 { l.rest } else { settle(l, fit, n) };
    let z = if l.room.z > 0.0 { rig::value(r.zoom, now) } else { 0.0 };
    if z > 0.0 {
        let q = zoomed(l, fit, n);
        v.k += (q.k - v.k) * z;
        v.c = v.c + (q.c - v.c) * z;
        v.rect = v.rect + (q.rect - v.rect) * z;
    }
    l.view = view3d::turned(v, rig::camera(r, l.pitch, now));
}

// The camera buttons round the 3D board (prototypes/game3d.html's `.ctl`, placement a):
// the view (the top view's icon, or the rest angle's while in the top view; a gold dot
// while the showcase has left the board off its rest angle), the zoom in landscape, and
// the showcase, lit while on. A tap changes the rig at `now`. Returns whether one was
// tapped.
fn camera(g: gui::Gui&, l: Layout, r: rig::Rig&, now: f64) -> bool {
    guard l.three && l.count > 0 else { return false; }
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

// The game screen (rendering.md, "Game screen"). Landscape: the board fills the height
// less a 24 dp margin, between two panels 232 dp wide and as tall as it; where that
// leaves the board under 720 dp (narrower than 16:10), the panels narrow, down to 192 dp,
// for the board to grow. Portrait: the board fills the width less the margin, with a
// 120 dp bar above it (128 where a third of it is under STACK_W, on a phone, its icons
// over their words) and the 204 dp play below it, both as wide as the board.
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
// one, the bar above the board and the play below it (task 050, the user 2026-11-09: a
// near-square window's landscape had a small board between square-ish panels). The 3D
// board takes the same choice, so switching boards keeps the layout. Every device's
// landscape passes: the 16:10 tablet's board is 96% of that height, the 4:3 and 13" iPad's
// 78 and 82%, the foldable's 69%, a 9:16 phone's 81 to 86%, the 20:9 ones' all of it.
let HANDOVER = 0.667;
fn landscape(area: float4, s: f32) -> bool {
    return area.z >= area.w && landscape_board(area, s) >= HANDOVER * (area.w - 2.0 * GAP * s);
}

// The same in `area`, a screen's safe area, at s pixels a dp. The game's screen (`game`,
// task 054) has the 3D board's panels round the flat board: in landscape its short
// corner panels (flat_corners), in portrait the bar and the play as wide as the 3D
// board's, and room for what each side has taken (task 052). A puzzle keeps the panels
// as tall as the board.
fn layout_in(area: float4, n: i64, s: f32, small: bool = true, game: bool = false) -> Layout {
    let width = area.z;
    let height = area.w;
    let gap = GAP * s;
    let phone = gui::phone(area, s);   // NARROW panels
    if landscape(area, s) {
        let side = side_of(area, s);
        let size = landscape_board(area, s);
        if game { return flat_corners(area, n, s, size); }
        let x = area.x + (width - (size + 2.0 * side + 2.0 * gap)) / 2.0;
        let y = area.y + (height - size) / 2.0;
        // The panels as tall as the board, or PANEL_LEAST where the width keeps the board
        // shorter (a 16:9 phone less its camera's cutout at a side), centered beside it.
        let tall = min(max(size, PANEL_LEAST * s), height - 2.0 * gap);
        let py = area.y + (height - tall) / 2.0;
        return Layout { board: board::layout_at(x + side + gap, y, size, s, n), left: float4 { x, py, side, tall },
                        right: float4 { x + side + gap + size + gap, py, side, tall } };
    }
    let bar = portrait_bar(area, s, small, game, game);
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
                     right: float4 { px, y + top + gap + size + gap, pw, bottom }, mode: bar.mode };
    bar_tiles(l, bar, game, phone, s);
    return l;
}

// The portrait bar's and play's heights and the margins in `area` at s pixels a dp, for
// the flat and the 3D board alike: compact in a small window (where `small` allows it),
// else a bar of tiles TOP tall, TOP_STACKED where a third of it is under STACK_W (its
// icons over their words), and TAKEN_BAR_ROW taller in a game, for what each side has
// taken. The bar is as wide as the width less the margins where `wide` (the game's and the
// 3D board's), else as wide as the board: in a window wider than tall that keeps this
// layout (panel::landscape), the board's, which the height holds under the width.
struct Bar {
    mode:    i64  = PORTRAIT,
    gap:     f32  = 0.0,
    top:     f32  = 0.0,
    bottom:  f32  = 0.0,
    stacked: bool = false,
}
fn portrait_bar(area: float4, s: f32, small: bool, game: bool, wide: bool) -> Bar {
    let width = area.z;
    let height = area.w;
    let compact = small && height < gui::COMPACT * s;
    let gap = (if compact { GAP_COMPACT } else { GAP }) * s;
    let bottom = (if compact { BOTTOM_COMPACT } else { BOTTOM }) * s;
    let across = if wide { width - 2.0 * gap }
                 else if width > height { min(width - 2.0 * gap, height - TOP * s - bottom - 4.0 * gap) }
                 else { width - 2.0 * gap };
    let narrow = (across - BAR_SPARE * s) / 3.0 < STACK_W * s;
    let extra = if game && !compact { TAKEN_BAR_ROW } else { 0.0 };
    let top = ((if compact { TOP_COMPACT } else if narrow { TOP_STACKED } else { TOP }) + extra) * s;
    return Bar { mode: if compact { COMPACT } else { PORTRAIT }, gap: gap, top: top, bottom: bottom,
                 stacked: narrow && !compact };
}

// The game's flat board in landscape (task 054) with the 3D board's panels: short glass
// panels in the top corners, CORNER_H tall, NARROW on a phone, else SIDE, but no wider
// than the flat layout's panels (side_of), so the board keeps its size and place (near
// square they narrow for it, where the 3D board's stay SIDE); a narrowed play panel
// CORNER_PLAY tall, as a phone's, for the hint over undo move. Under the left one, what
// each side has taken, on its own glass.
fn flat_corners(area: float4, n: i64, s: f32, size: f32) -> Layout {
    let width = area.z;
    let height = area.w;
    let gap = GAP * s;
    let phone = gui::phone(area, s);   // NARROW panels
    let side = min((if phone { NARROW } else { SIDE }) * s, side_of(area, s));
    let tall = min(CORNER_H * s, height - 2.0 * gap);
    let play_tall = if side < SIDE * s - 0.5 { min(CORNER_PLAY * s, height - 2.0 * gap) } else { tall };
    let left = float4 { area.x + gap, area.y + gap, side, tall };
    let right = float4 { area.x + width - gap - side, area.y + gap, side, play_tall };
    var l = Layout { board: board::layout_at(area.x + (width - size) / 2.0, area.y + (height - size) / 2.0, size, s, n),
                     left: left, right: right, mode: CORNERS, .. };
    under_left(l, area, s, (if phone { TAKEN_PHONE } else { TAKEN_D }) * s);
    return l;
}

fn overlaps(a: float4, b: float4) -> bool { a.x < b.x + b.z && b.x < a.x + a.z && a.y < b.y + b.w && b.y < a.y + a.w }

// What each side has taken on its own glass under l's left corner panel, its pieces d
// across: two rows where they fit down to the bottom margin, smaller where they must (to
// 3/4), else one line; none where even that has no room.
fn under_left(l: Layout&, area: float4, s: f32, d: f32) {
    let left = l.left;
    let side = left.z;
    let gap = GAP * s;
    let height = area.w;
    let under = left.y + left.w + BACK_GAP * s;
    let room = area.y + height - gap - under;
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
// tiles; compact, the bar's middle between back and settings.
fn bar_tiles(l: Layout&, bar: Bar, game: bool, phone: bool, s: f32) {
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
    let row = if game { TAKEN_BAR_ROW * s } else { 0.0 };
    l.tiles = inside(float4 { l.left.x, l.left.y, l.left.z, l.left.w - row }, WIDE_IN, s);
    guard game else { return; }
    let h = (TAKEN_BAR_ROW - WIDE_IN.y) * s;
    l.taken = float4 { l.left.x + WIDE_IN.x * s, l.left.y + l.left.w - WIDE_IN.y * s - h, l.left.z - 2.0 * WIDE_IN.x * s,
                       h };
    l.taken_as = TAKEN_ROW;
    l.taken_d = (if phone { TAKEN_PHONE } else { TAKEN_D }) * s;
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

// The countdown before a draw under whose turn (rendering.md, "Controls", The countdown): a line
// of words, and in landscape a row of `of` dots, `lit` of them lit, the rest going out
// one a move; `more` adds "A third time is a draw" under the line. Between clocks with
// no room for the line (fit b) the short form instead: `word` and `fig`, "Draw in" and
// "3". Empty for none.
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
fn pair(over: board::Overlay&, spot: float4, r: f32, overlap: f32, a: f32) {
    let w = 4.0 * r - overlap;
    let x = spot.x + 0.5 * (spot.z - w);
    piece(over, float4 { x, spot.y, 2.0 * r, spot.w }, r, 0, 0, a, 0.0);
    piece(over, float4 { x + 2.0 * r - overlap, spot.y, 2.0 * r, spot.w }, r, 1, 0, a, 0.0);
}

// Words in w pixels of face `face`: where they break in two, the lines as even as they
// can be (the prototypes' balanced wrap), or -1 for one line.
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
            else { gui::fill(g, d, float4 { 1.0, 1.0, 1.0, 0.18 }, 7.0 * u); }
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
fn piece(over: board::Overlay&, spot: float4, r: f32, side: i64, king: i64, a: f32, ring: f32) {
    guard over.len < board::OVER else { return; }
    let x = spot.x + 0.5 * spot.z;
    let y = spot.y + 0.5 * spot.w;
    over.push(board::Piece { at: float4 { x, y, r, 0.0 }, look: float4 { side, king, 0.0, a },
                             ring: float4 { 0.0, ring, 0.0, 0.0 } });
}

// One side's clock in r: its piece and its time, lit while it runs (gold under a
// minute, red at 20 seconds or under), faint while it waits; its piece's ring as strong
// as `ring`.
fn clock_of(g: gui::Gui&, r: float4, c: clock::Clock&, side: i64, ring: f32, over: board::Overlay&) {
    let u = g.scale;
    let runs = c.running == side;
    let style = if clock::low(c, side) { gui::CLOCK_LOW } else if clock::warn(c, side) { gui::CLOCK_WARN }
                else if runs { gui::CLOCK_RUN } else { gui::CLOCK_IDLE };
    gui::clock_tile(g, r, style);
    var room = r;
    gui::cut_left(room, 14.0 * u);
    gui::cut_right(room, 14.0 * u);
    let spot = gui::cut_left(room, 44.0 * u);
    piece(over, spot, 22.0 * u, side, 0,
          if runs { 1.0 } else { 0.7 }, ring);
    var t: u8[..8] = [];
    clock::text(clock::shown(c, side), t);
    // A clock narrowed for the lookout's eye beside it takes a smaller face where its
    // time doesn't fit.
    let face = if gui::text_width(g, gui::FIGURES, t) <= room.z { gui::FIGURES } else { gui::fitting(g, gui::LABEL, t, room.z) };
    gui::figures(g, face, room, t, if runs { 1.0 } else { 0.66 }, style, gui::RIGHT);
}

// The way out: back, settings, and start over at the bottom, far from what plays. In
// landscape back is its own glass tile at the top of `left` (rendering.md, "Controls", The
// way back) and the panel under it holds the other two; in portrait the three are a bar above
// the board, back first. Back goes where the screen's way out goes (home from the game,
// the theme's page from a puzzle). Returns BACK, SETTINGS, RESTART, or NOTHING.
let OUT_WORDS = [strings::NAV_BACK, strings::HOME_SETTINGS, strings::GAME_START_OVER];
fn leave(g: gui::Gui&, l: Layout) -> i64 {
    // The words' widths, measured first, where they are shown: not the compact bar's icons,
    // nor back's on its own glass tile in landscape, which measures its word itself.
    var words: f32[3] = [0.0, 0.0, 0.0];
    if l.mode != COMPACT {
        let first = if columns(l) { 1 } else { 0 };
        for i in first..3 { words[i] = gui::text_width(g, gui::HEADING, strings::get(OUT_WORDS[i])); }
    }
    let o = way_out(l, words, g.scale);
    let icons = [gui::BACK, gui::GEAR, gui::RESTART];
    let asks = [BACK, SETTINGS, RESTART];
    var chosen = NOTHING;
    if columns(l) {
        if gui::back(g, gui::PANEL_IDS, o.tiles[0], strings::get(OUT_WORDS[0])) { chosen = BACK; }
        gui::panel(g, o.glass);
    } else {
        gui::panel(g, l.left);
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

// Where the way out's tiles go: back, settings, start over; in landscape the glass under
// back that holds the other two; and how each tile lays out its icon and word (gui::MIDDLE,
// STACKED, or ICON alone).
struct Out {
    tiles:   float4[3] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 3],
    glass:   float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    arrange: i64       = gui::MIDDLE,
}

// The way out's tiles in l at u pixels a dp, `words` the three words' widths in the
// heading face.
fn way_out(l: Layout, words: f32[3], u: f32) -> Out {
    var o = Out {};
    if columns(l) {
        var column = l.left;
        o.tiles[0] = gui::cut_top(column, ROW_H * u);
        gui::cut_top(column, BACK_GAP * u);
        o.glass = column;
        // Each icon beside its word, or, where a word doesn't fit so in a narrowed panel,
        // both icons over their words in taller rows.
        var left = inside(column, TALL_IN, u);
        for i in 1..3 {
            if labelled_width(u, 34.0, words[i]) > left.z { o.arrange = gui::STACKED; }
        }
        let h = (if o.arrange == gui::MIDDLE { ROW_H } else { STACK_H }) * u;
        o.tiles[1] = gui::cut_top(left, h);
        o.tiles[2] = gui::cut_bottom(left, h);
        return o;
    }
    if l.mode == COMPACT {
        o.tiles = icons(l.tiles, u);
        o.arrange = ICON;
        return o;
    }
    // Thirds of the bar while each word fits its third; else each tile as wide as its
    // word wants and an even share of the rest, as the setup's draughts are. A bar made
    // taller for it (TOP_STACKED) puts each icon over its word, which needs less width.
    o.arrange = if l.stacked { gui::STACKED } else { gui::MIDDLE };
    let bar = l.tiles;
    let gap = (if l.stacked { 12.0 } else { 16.0 }) * u;
    let free = bar.z - 2.0 * gap;
    var wants: f32[3] = [0.0, 0.0, 0.0];
    var fits = true;
    for i in 3 {
        let want = if l.stacked { words[i] + 2.0 * gui::LABEL_PAD * u } else { labelled_width(u, 34.0, words[i]) };
        wants[i] = max(want, 88.0 * u);
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

// How tall the right panel's bottom tile is in landscape: TALL_H, or STACK_H in a panel
// too short for it beside what is above it (a phone).
fn tall(l: Layout, u: f32) -> f32 {
    // A corner panel is short on every screen: the tall tile but in a phone's narrow one.
    if l.mode == CORNERS { return (if l.right.z < SIDE * u - 0.5 { STACK_H } else { TALL_H }) * u; }
    return (if l.right.w < SHORT * u { STACK_H } else { TALL_H }) * u;
}

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
    name:    f32 = 0.0,     // the lookout's name in the body face
}

// Where the play panel's parts go (one function per mode lays it out: column_play,
// compact_play, portrait_play): the two clocks, the first one's (the far player's)
// first; the countdown's short form between them, on a line (SHORT_LINE) or its word
// over its figure (SHORT_STACKED); else whose turn's piece in `spot`, `r` pixels round
// (both pieces overlapping by `overlap` for a draw), and its words; the lookout's name
// beside its eye in the landscape column; where the countdown's line goes under whose
// turn in landscape (`note`, empty for none); and the eye, the hint, and undo move,
// each laid out as `*_as` says (gui::MIDDLE.., or ICON alone) with its icon `*_icon` dp.
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

// The landscape column, a panel as tall as the board or a corner one: as the prototype
// has it where the panel is tall enough, whose turn or the clocks, the lookout's eye and
// name, the hint over undo move. Else (a phone's, a 3D board's corner panel) the eye at
// the end of whose turn's line, or beside the clocks, and the hint beside undo move where
// both keep 88 dp across, or over it, the gaps round the piece closed up where the panel
// is short.
fn column_play(l: Layout, w: Words, on: Shows, u: f32) -> Play {
    var p = Play { r: 36.0 * u, overlap: 6.0 * u, .. };
    var right = play_room(l, u);
    // A corner panel's short line between the clocks takes from undo move what the
    // panel lacks, and leaves a gap above it.
    let squeezed = l.mode == CORNERS && on.clocks && on.counting && !on.drawn;
    let wanted = tall(l, u);
    let low = if squeezed { min(wanted, right.w - (2.0 * CLOCK_H + SHORT_GAP + 12.0) * u) } else { wanted };
    let head = if on.clocks { (2.0 * CLOCK_H + 10.0) * u } else { (18.0 + 72.0 + 18.0) * u + w.heading };
    let column = right.w >= head + (EYE_TOUCH + 12.0 + HINT_H + 12.0) * u + low;
    let beside = !column && right.z >= (2.0 * 88.0 + 12.0) * u;
    let tight = !column && !beside && right.w < head + (12.0 + HINT_H + 12.0) * u + low;
    p.undo = gui::cut_bottom(right, low);
    if beside {
        p.hint = gui::cut_left(p.undo, 0.5 * (p.undo.z - gui::PAD * u));
        gui::cut_left(p.undo, gui::PAD * u);
    } else {
        gui::cut_bottom(right, gui::PAD * u);
        p.hint = gui::cut_bottom(right, HINT_H * u);
    }
    p.undo_icon = if beside { 36.0 } else { 48.0 };
    p.hint_as = if beside { gui::STACKED } else { gui::MIDDLE };
    p.hint_icon = if beside { 36.0 } else { 34.0 };
    if on.clocks {
        let extra = if squeezed { (SHORT_GAP - 10.0) * u } else { 0.0 };
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
            gui::cut_top(clocks, 10.0 * u);
        }
        p.clocks[1] = gui::cut_top(clocks, CLOCK_H * u);
    } else {
        // The piece, its glow ring, and the words under it; both pieces for a draw. A
        // countdown in a 3D board's short corner panel closes the gaps up.
        let close = (l.mode == CORNERS && on.counting) || tight;
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
    if !(l.mode == CORNERS && on.clocks) { p.note = right; }
    return p;
}

// A small window's play (compact): one row, whose turn (or the two clocks) at the left,
// undo move at the right. The eye at the end of whose turn's line, the hint between it
// and undo move, each its icon over its word, or icons alone with clocks and where the
// words would leave whose turn too little room for its own in the small face (Estonian's
// undo move).
fn compact_play(l: Layout, w: Words, on: Shows, u: f32) -> Play {
    var p = Play { r: 22.0 * u, overlap: 4.0 * u, undo_icon: 28.0, hint_icon: 28.0, .. };
    var row = float4 { l.right.x + gui::PAD * u, l.right.y + gui::PAD * u, l.right.z - 2.0 * gui::PAD * u, l.right.w - 2.0 * gui::PAD * u };
    let mark = (if on.drawn { 84.0 } else { 44.0 }) * u;
    let sides = 2.0 * gui::LABEL_PAD * u;
    let undo_wants = max(88.0 * u, w.undo + sides);
    let hint_wants = max(88.0 * u, w.hint + sides);
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
    var row = gui::cut_top(right, WIDE_H * u);
    p.undo = gui::cut_right(row, 0.5 * (row.z - gui::PAD_WIDE * u));
    gui::cut_right(row, gui::PAD_WIDE * u);
    p.hint = row;
    return p;
}

// Declares the panels for this frame, with the clocks `c`, and `side` the side to move,
// or the winner when `won`; when `drawn`, both pieces and "Draw" instead. The side to
// move's piece has a ring as strong as `glow`; it pulses while the computer thinks, when
// its clock's piece has it even before the clocks start. The countdown before a draw,
// `note`, goes under whose turn (or under the clocks in landscape); between the clocks
// in its short form where they leave no room for the line, a portrait panel and a 3D
// board's corner panel. Pieces shown on the panels go into `over`. The lookout's eye and
// the hint's tile (`help`) go on the play panel. Returns the tile tapped this frame, if
// any.
fn game(g: gui::Gui&, l: Layout, c: clock::Clock&, side: i64, won: bool, drawn: bool, note: Note&, thinking: bool,
        glow: f32, over: board::Overlay&, help: Help = Help {}) -> i64 {
    let u = g.scale;
    let turn_key = if drawn { strings::DRAW }
                   else if won { if side == 0 { strings::WON_WHITE } else { strings::WON_BLACK } }
                   else if side == 0 { strings::TURN_WHITE } else { strings::TURN_BLACK };
    let label = strings::get(turn_key);
    let line = note.line[..note.line.len];
    let hint_word = strings::get(if help.stage == 1 { strings::GAME_WHERE_TO } else { strings::GAME_HINT });
    let name = strings::get(strings::GAME_LOOKOUT);
    let on = Shows { clocks: clock::on(c), counting: note.of > 0, drawn: drawn };
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
        },
    }
    let p = match l.mode { COMPACT => compact_play(l, w, on, u), PORTRAIT => portrait_play(l, w, on, u),
                           _ => column_play(l, w, on, u) };
    var chosen = leave(g, l);
    gui::panel(g, l.right);
    if on.clocks {
        // The clock nearer the player whose pieces are at the bottom goes second: under
        // the other in landscape, right of it in portrait.
        let first = if l.board.flip { 0 } else { 1 };
        var rings: f32[2] = [0.0, 0.0];
        for s in 2 { if c.running == s || (thinking && s == side) { rings[s] = glow; } }
        clock_of(g, p.clocks[0], c, first, rings[first], over);
        if p.short_as == SHORT_LINE { short_line(g, p.short, note); }
        clock_of(g, p.clocks[1], c, 1 - first, rings[1 - first], over);
        if p.short_as == SHORT_STACKED { short_stacked(g, p.short, note); }
    } else {
        if drawn { pair(over, p.spot, p.r, p.overlap, 1.0); }
        else { piece(over, p.spot, p.r, side, 0, 1.0, glow); }
        turn_words(g, l, p.words, label, line, on.counting);
    }
    if p.name.z > 0.0 {
        // The lookout's name, dim while off.
        let dim: f32 = if help.look { 1.0 } else { 0.66 };
        gui::text(g, gui::fitting(g, gui::BODY, name, p.name.z), p.name, name, dim, 0.0, gui::LEFT);
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
        gui::text(g, gui::fitting(g, gui::HEADING, label, r.z), r, label, 1.0, 0.0, gui::CENTER);
        return;
    }
    let fit = l.mode == COMPACT;
    let face = if fit { gui::fitting(g, gui::HEADING, label, r.z) } else { gui::HEADING };
    guard counting else {
        gui::text(g, face, r, label, 1.0, 0.0, gui::LEFT);
        return;
    }
    let head = g.faces[face].ascent - g.faces[face].descent;
    let small = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    var words = gui::center(r, r.z, head + 2.0 * u + small);
    gui::text(g, face, gui::cut_top(words, head), label, 1.0, 0.0, gui::LEFT);
    gui::cut_top(words, 2.0 * u);
    let small_face = if fit { gui::fitting(g, gui::SMALL, line, words.z) } else { gui::SMALL };
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

// The hint's tile in r (prototypes/coach.html's `hint`): the bulb and its word over a pip
// for each hint, a pip lit for each left, laid out as `arrange` has it (gui::MIDDLE,
// STACKED, or ICON, the bulb over the pips alone), the bulb `size` dp. Its word is
// Hint, or Where to? once it has lit the piece; it is lit in the glow while it shows, as a
// chosen tile is; dim, taking no tap, with no hint left or none to give. True when tapped.
let ICON = 3;
let HINTS = 3;              // the pips: a game's hints
fn hint_tile(g: gui::Gui&, r: float4, arrange: i64, help: Help, size: f32) -> bool {
    let u = g.scale;
    let on = help.can && (help.stage > 0 || help.left > 0);
    let clicked, p = gui::hold_if(g, HINT_ID, r, on);
    let a: f32 = if on { 1.0 } else { 0.35 };
    let style = if help.stage > 0 { gui::CHOSEN } else { gui::PLAIN };
    gui::add(g, gui::Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { gui::BUTTON, 22.0 * u, 0.0, p },
                            extra: float4 { u, style, 0.0, 0.0 } });
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
            gui::text(g, gui::fitting(g, gui::HEADING, word, room), gui::cut_top(c, line), word, a, 0.0, gui::CENTER);
            gui::cut_top(c, 6.0 * u);
        }
        pips(g, gui::center(gui::cut_top(c, PIP * u), pips_w, PIP * u), help.left, a);
        return clicked;
    }
    let gap = gui::PAD * u;
    let room = r.z - s - gap - 2.0 * gui::LABEL_PAD * u;
    let face = gui::fitting(g, gui::HEADING, word, room);
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
        else { gui::fill(g, d, float4 { 1.0, 1.0, 1.0, 0.2 * a }, 0.5 * PIP * u); }
    }
}

// What each side has taken (task 052), where the layout puts it (Layout.taken): `t`
// counts the pieces of each color taken, so black's catch is t's white pieces. Each
// catch is a row of the app's pieces, men then the kings after a gap, crowned, each
// covering about half the one before, closer where the row would run past its room. A
// catch on its own glass shows it only once a piece has been taken. The pieces go into
// `over`.
fn taken(g: gui::Gui&, l: Layout, t: Taken, over: board::Overlay&) {
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
        catch_row(over, t, first, float4 { inner.x, y, inner.z, d }, false);
        catch_row(over, t, 1 - first, float4 { inner.x, y + d + gap, inner.z, d }, false);
        return;
    }
    if l.taken_as == TAKEN_ROW {
        // White's catch (black's pieces) at the left, black's at the right, each in at
        // most its half less a gap.
        let y = r.y + 0.5 * (r.w - d);
        let half = 0.5 * (r.z - TAKEN_GAP * d);
        catch_row(over, t, rules::BLACK, float4 { r.x, y, half, d }, false);
        catch_row(over, t, rules::WHITE, float4 { r.x + r.z - half, y, half, d }, true);
        return;
    }
    guard any else { return; }
    // One line on its glass: TAKEN_LINE's the far side's catch first, the bar's white's
    // catch first, as portrait's row; the bar as wide as what it holds.
    let a = if l.taken_as == TAKEN_LINE { first } else { rules::BLACK };
    let b = 1 - a;
    let mid = (if row_len(t, a, d) > 0.0 && row_len(t, b, d) > 0.0 { 24.0 } else { 0.0 }) * u;
    var glass = r;
    if l.taken_as == TAKEN_BAR {
        let w = min(r.z, row_len(t, a, d) + mid + row_len(t, b, d) + 2.0 * edge);
        glass = float4 { r.x + 0.5 * (r.z - w), r.y, w, r.w };
    }
    gui::panel(g, glass);
    let inner = float4 { glass.x + edge, glass.y + 0.5 * (glass.w - d), glass.z - 2.0 * edge, d };
    // Each catch in at most its share of the room, as long as it wants.
    let la = row_len(t, a, d);
    let lb = row_len(t, b, d);
    let room = inner.z - mid;
    let wa = if la + lb <= room { la } else { room * la / (la + lb) };
    catch_row(over, t, a, float4 { inner.x, inner.y, wa, d }, false);
    catch_row(over, t, b, float4 { inner.x + wa + mid, inner.y, inner.z - wa - mid, d }, false);
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
fn catch_row(over: board::Overlay&, t: Taken, c: i64, r: float4, right: bool) {
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
        piece(over, float4 { x, y, d, d }, 0.5 * d, c, if king { board::CROWN } else { 0 }, 1.0, 0.0);
        x += step;
    }
}
