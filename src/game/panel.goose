// The game screen's panels (docs/architecture/rendering.md, "Game screen";
// prototypes/game.html, and prototypes/back.html's take b for back): the board between
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

// What the panels' tiles ask for.
let NOTHING = 0;
let UNDO = 1;
let RESTART = 2;
let BACK = 3;
let SETTINGS = 4;

let ROW_H = 88.0;           // dp: a control's row, the 88 dp a small hand needs
let BACK_GAP = 12.0;        // dp: back over the left panel in landscape
let TALL_H = 132.0;         // undo move in landscape, STACK_H in a panel under SHORT
let SHORT = 420.0;          // dp: a panel this short (a phone) has the shorter tile
let WIDE_H = 88.0;          // undo move in portrait
let CLOCK_H = 72.0;
let OVER = 4;               // pieces over the UI: two clocks and the winner, at most

let SIDE = 232.0;           // dp: each panel's width in landscape,
let NARROW = 192.0;         // narrowing to this near square
let BOARD = 720.0;          // dp: the board the panels narrow for, the tablet's at 16:10
let PANEL_LEAST = 372.0;    // dp: a landscape panel's height at least, room for its tiles
let STACK_H = 96.0;         // dp: a tile with its icon over its word
let TOP = 120.0;            // dp: the bar above the board in portrait,
let TOP_STACKED = 128.0;    // with its icons over their words where the bar is narrow:
let STACK_W = 170.0;        // dp: a third of the bar under which it is
let BOTTOM = 204.0;         // dp: the play below it
let GAP = 24.0;

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
    keep:    float4[3]    = [float4 { 0.0, 0.0, 0.0, 0.0 }; 3],
    gap:     f32          = 0.0,
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
let PHONE_DP = 600.0;       // dp: a screen whose shorter side is under this (a phone) has NARROW panels
let PITCH_LANDSCAPE: f32 = 52.5;
let PITCH_PORTRAIT:  f32 = 65.0;
// The camera buttons (the user, 2026-11-09): a touch area and the disc in it, in dp, on a
// tablet (its shorter side PHONE_DP or more), a phone in landscape, and in portrait;
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

fn corners_in(area: float4, n: i64, s: f32, portrait_pitch: f32 = PITCH_PORTRAIT) -> Layout {
    let width = area.z;
    let height = area.w;
    let gap = GAP * s;
    let m = BUTTON_MARGIN * s;
    let phone = min(width, height) / s < PHONE_DP;
    if width >= height {
        let side = (if phone { NARROW } else { SIDE }) * s;
        let tall = min(CORNER_H * s, height - 2.0 * gap);
        let left = float4 { area.x + gap, area.y + gap, side, tall };
        let right = float4 { area.x + width - gap - side, area.y + gap, side, tall };
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
                         box: box, room: box, gap: gap, .. };
        l.keep = [left, right, buttons];
        rest(l, settle(l, view3d::Camera { pitch: PITCH_LANDSCAPE, yaw: 0.0 }, n), s);
        return l;
    }
    let cam = view3d::Camera { pitch: portrait_pitch, yaw: 0.0 };
    let narrow = (width - 2.0 * gap - 72.0 * s) / 3.0 < STACK_W * s;
    let top = (if narrow { TOP_STACKED } else { TOP }) * s;
    let bottom = BOTTOM * s;
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
                     disc: disc, box: box, gap: gap, .. };
    l.keep = [l.left, play, buttons];
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
fn clear(v: view3d::View, keep: float4[3]&, gap: f32, field: bool = false) -> bool {
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
        guard gui::floating(g, 120 + what, at, l.disc, icon, what == SHOWCASE && r.showcase,
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
    return layout_in(float4 { 0.0, 0.0, width, height }, n, gui::scale_of(width, height));
}

// The same in `area`, a screen's safe area, at s pixels a dp.
fn layout_in(area: float4, n: i64, s: f32) -> Layout {
    let width = area.z;
    let height = area.w;
    let gap = GAP * s;
    if width >= height {
        let room = width - 4.0 * gap;
        var side = SIDE * s;
        if room - 2.0 * side < BOARD * s { side = max(NARROW * s, 0.5 * (room - BOARD * s)); }
        let size = min(height - 2.0 * gap, width - 2.0 * side - 4.0 * gap);
        let x = area.x + (width - (size + 2.0 * side + 2.0 * gap)) / 2.0;
        let y = area.y + (height - size) / 2.0;
        // The panels as tall as the board, or PANEL_LEAST where the width keeps the board
        // shorter (a 16:9 phone less its camera's cutout at a side), centered beside it.
        let tall = min(max(size, PANEL_LEAST * s), height - 2.0 * gap);
        let py = area.y + (height - tall) / 2.0;
        return Layout { board: board::layout_at(x + side + gap, y, size, s, n), left: float4 { x, py, side, tall },
                        right: float4 { x + side + gap + size + gap, py, side, tall } };
    }
    let narrow = (width - 2.0 * gap - 72.0 * s) / 3.0 < STACK_W * s;
    let top = (if narrow { TOP_STACKED } else { TOP }) * s;
    let bottom = BOTTOM * s;
    let size = min(width - 2.0 * gap, height - top - bottom - 4.0 * gap);
    let x = area.x + (width - size) / 2.0;
    let y = area.y + (height - (top + size + bottom + 2.0 * gap)) / 2.0;
    return Layout { board: board::layout_at(x, y + top + gap, size, s, n), left: float4 { x, y, size, top },
                    right: float4 { x, y + top + gap + size + gap, size, bottom } };
}

// A piece of `side` over the UI centered in `spot` with radius r, at opacity a, a man (0)
// or a king (board::CROWN, board::STACK), with a glow ring right round it as strong as
// `ring`, 0 to 1.
fn piece(over: board::Piece[..OVER]&, spot: float4, r: f32, side: i64, king: i64, a: f32, ring: f32) {
    guard over.len < OVER else { return; }
    let x = spot.x + 0.5 * spot.z;
    let y = spot.y + 0.5 * spot.w;
    over.push(board::Piece { at: float4 { x, y, r, 0.0 }, look: float4 { side, king, 0.0, a },
                             ring: float4 { 0.0, ring, 0.0, 0.0 } });
}

// One side's clock in r: its piece and its time, lit while it runs (red under ten
// seconds), faint while it waits; its piece's ring as strong as `ring`.
fn clock_of(g: gui::Gui&, r: float4, c: clock::Clock&, side: i64, ring: f32, over: board::Piece[..OVER]&) {
    let u = g.scale;
    let runs = c.running == side;
    let low = clock::low(c, side);
    gui::clock_tile(g, r, if low { gui::CLOCK_LOW } else if runs { gui::CLOCK_RUN } else { gui::CLOCK_IDLE });
    var room = r;
    gui::cut_left(room, 14.0 * u);
    gui::cut_right(room, 14.0 * u);
    let spot = gui::cut_left(room, 44.0 * u);
    piece(over, spot, 22.0 * u, side, 0,
          if runs { 1.0 } else { 0.7 }, ring);
    var t: u8[..8] = [];
    clock::text(clock::shown(c, side), t);
    gui::figures(g, gui::FIGURES, room, t, if runs { 1.0 } else { 0.66 }, low, gui::RIGHT);
}

// The way out: back, settings, and start over at the bottom, far from what plays. In
// landscape back is its own glass tile at the top of `left` (prototypes/back.html, take
// b) and the panel under it holds the other two; in portrait the three are a bar above
// the board, back first. Back goes where the screen's way out goes (home from the game,
// the theme's page from a puzzle). Returns BACK, SETTINGS, RESTART, or NOTHING.
fn leave(g: gui::Gui&, l: Layout) -> i64 {
    let u = g.scale;
    var chosen = NOTHING;
    let words = [strings::NAV_BACK, strings::HOME_SETTINGS, strings::GAME_START_OVER];
    let icons = [gui::BACK, gui::GEAR, gui::RESTART];
    let asks = [BACK, SETTINGS, RESTART];
    if l.left.z < l.left.w {
        var column = l.left;
        if gui::back(g, 110, gui::cut_top(column, ROW_H * u), strings::get(words[0])) { chosen = BACK; }
        gui::cut_top(column, BACK_GAP * u);
        gui::panel(g, column);
        // Each icon beside its word, or, where a word doesn't fit so in a narrowed panel,
        // both icons over their words in taller rows.
        var left = float4 { column.x + 16.0 * u, column.y + 20.0 * u, column.z - 32.0 * u, column.w - 40.0 * u };
        var arrange = gui::BESIDE;
        for i in 1..3 {
            if gui::labelled_width(g, 34.0, strings::get(words[i]), gui::HEADING, gui::BESIDE) > left.z {
                arrange = gui::STACKED;
            }
        }
        let h = (if arrange == gui::BESIDE { ROW_H } else { STACK_H }) * u;
        for i in 1..3 {
            let r = if i == 1 { gui::cut_top(left, h) } else { gui::cut_bottom(left, h) };
            if gui::labelled(g, 110 + i, r, icons[i], 34.0, strings::get(words[i]), gui::HEADING, arrange) {
                chosen = asks[i];
            }
        }
        return chosen;
    }
    gui::panel(g, l.left);
    // Thirds of the bar while each word fits its third; else each tile as wide as its
    // word wants and an even share of the rest, as the setup's draughts are. A bar made
    // taller for it (TOP_STACKED) puts each icon over its word, which needs less width.
    let stacked = l.left.w >= TOP_STACKED * u - 0.5;
    let arrange = if stacked { gui::STACKED } else { gui::MIDDLE };
    let bar = float4 { l.left.x + 20.0 * u, l.left.y + 16.0 * u, l.left.z - 40.0 * u, l.left.w - 32.0 * u };
    let gap = (if stacked { 12.0 } else { 16.0 }) * u;
    let free = bar.z - 2.0 * gap;
    var wants: f32[3] = [0.0, 0.0, 0.0];
    var fits = true;
    for i in 3 {
        let word = strings::get(words[i]);
        let want = if stacked { gui::text_width(g, gui::HEADING, word) + 2.0 * gui::LABEL_PAD * u }
                   else { gui::labelled_width(g, 34.0, word, gui::HEADING, gui::MIDDLE) };
        wants[i] = max(want, 88.0 * u);
        if wants[i] > free / 3.0 { fits = false; }
    }
    let share = (free - wants[0] - wants[1] - wants[2]) / 3.0;
    let even = fits || share < 0.0;
    var x = bar.x;
    for i in 3 {
        let w = if even { free / 3.0 } else { wants[i] + share };
        let r = if even { float4 { bar.x + i * (w + gap), bar.y, w, bar.w } } else { float4 { x, bar.y, w, bar.w } };
        x += w + gap;
        if gui::labelled(g, 110 + i, r, icons[i], 34.0, strings::get(words[i]), gui::HEADING, arrange) {
            chosen = asks[i];
        }
    }
    return chosen;
}

// How tall the right panel's bottom tile is in landscape: TALL_H, or STACK_H in a panel
// too short for it beside what is above it (a phone).
fn tall(l: Layout, u: f32) -> f32 {
    // A corner panel is short on every screen: the tall tile but in a phone's narrow one.
    if l.three { return (if l.right.z < SIDE * u - 0.5 { STACK_H } else { TALL_H }) * u; }
    return (if l.right.w < SHORT * u { STACK_H } else { TALL_H }) * u;
}

// The right panel's room inside its glass, where a screen plays.
fn play_area(g: gui::Gui&, l: Layout) -> float4 {
    let u = g.scale;
    if l.left.z < l.left.w {
        return float4 { l.right.x + 16.0 * u, l.right.y + 20.0 * u, l.right.z - 32.0 * u, l.right.w - 40.0 * u };
    }
    return float4 { l.right.x + 20.0 * u, l.right.y + 16.0 * u, l.right.z - 40.0 * u, l.right.w - 32.0 * u };
}

// Declares the panels for this frame, with the clocks `c`, and `side` the side to move,
// or the winner when `won`. The side to move's piece has a ring as strong as `glow`; it
// pulses while the computer thinks, when its clock's piece has it even before the
// clocks start. Pieces shown on the panels go into `over`. Returns the tile tapped this
// frame, if any.
fn game(g: gui::Gui&, l: Layout, c: clock::Clock&, side: i64, won: bool, thinking: bool, glow: f32,
        over: board::Piece[..OVER]&) -> i64 {
    let u = g.scale;
    let landscape = l.left.z < l.left.w;
    let turn_key = if won { if side == 0 { strings::WON_WHITE } else { strings::WON_BLACK } }
                   else if side == 0 { strings::TURN_WHITE } else { strings::TURN_BLACK };
    // The clock nearer the player whose pieces are at the bottom goes second: under the
    // other in landscape, right of it in portrait.
    let first = if l.board.flip { 0 } else { 1 };
    var rings: f32[2] = [0.0, 0.0];
    for s in 2 { if c.running == s || (thinking && s == side) { rings[s] = glow; } }
    var chosen = leave(g, l);
    gui::panel(g, l.right);
    var right = play_area(g, l);
    if landscape {
        let back = gui::cut_bottom(right, tall(l, u));
        if clock::on(c) {
            clock_of(g, gui::cut_top(right, CLOCK_H * u), c, first, rings[first], over);
            gui::cut_top(right, 10.0 * u);
            clock_of(g, gui::cut_top(right, CLOCK_H * u), c, 1 - first, rings[1 - first], over);
        } else {
            // The piece, its glow ring, and the words under it.
            gui::cut_top(right, 18.0 * u);
            let spot = gui::cut_top(right, 72.0 * u);
            piece(over, spot, 36.0 * u, side, 0, 1.0, glow);
            gui::cut_top(right, 18.0 * u);
            let f .= g.faces[gui::HEADING];
            let words = strings::get(turn_key);
            gui::text(g, gui::fitting(g, gui::HEADING, words, right.z), gui::cut_top(right, f.ascent - f.descent), words,
                      1.0, 0.0, gui::CENTER);
        }
        if gui::labelled(g, 113, back, gui::UNDO, 48.0, strings::get(strings::GAME_UNDO_MOVE), gui::HEADING,
                         gui::STACKED) {
            chosen = UNDO;
        }
        return chosen;
    }
    // Portrait: the play below the board.
    var top = gui::cut_top(right, CLOCK_H * u);
    gui::cut_top(right, 12.0 * u);
    if clock::on(c) {
        let half = 0.5 * (top.z - 16.0 * u);
        clock_of(g, gui::cut_left(top, half), c, first, rings[first], over);
        clock_of(g, gui::cut_right(top, half), c, 1 - first, rings[1 - first], over);
    } else {
        // The piece beside the words, centered.
        let label = strings::get(turn_key);
        let span = 52.0 * u + 18.0 * u + gui::text_width(g, gui::HEADING, label);
        var row = gui::center(top, span, top.w);
        let spot = gui::cut_left(row, 52.0 * u);
        piece(over, spot, 26.0 * u, side, 0, 1.0, glow);
        gui::cut_left(row, 18.0 * u);
        gui::text(g, gui::HEADING, row, label, 1.0, 0.0, gui::LEFT);
    }
    if gui::labelled(g, 113, gui::cut_top(right, WIDE_H * u), gui::UNDO, 36.0, strings::get(strings::GAME_UNDO_MOVE),
                     gui::HEADING, gui::MIDDLE) {
        chosen = UNDO;
    }
    return chosen;
}
