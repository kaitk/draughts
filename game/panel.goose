// The game screen's panels (docs/architecture/rendering.md, "Game screen";
// prototypes/game.html): the board between them, leaving the game on the left (home,
// settings, and start over at the bottom) and playing it on the right (whose turn, or
// the two clocks, and take back at the bottom, a tall tile). Each control is a glass
// tile with an icon and a word. In portrait the left panel is a bar of three above the
// board and the right one is below it: whose turn or the clocks side by side, over take
// back across the width. Start over sits far from take back so it isn't hit for it.
// layout() places the board and the two panels, for every screen that has them.
namespace panel;
import std;
import vec;

import gui from "../gui";
import board from "../board";
import strings from "../strings";

// What the panels' tiles ask for.
let NOTHING = 0;
let UNDO = 1;
let RESTART = 2;
let HOME = 3;
let SETTINGS = 4;

let ROW_H = 72.0;           // dp: a control's row
let TALL_H = 132.0;         // take back in landscape
let WIDE_H = 80.0;          // take back in portrait
let CLOCK_H = 72.0;
let OVER = 4;               // pieces over the UI: two clocks and the winner, at most

let SIDE = 232.0;           // dp: each panel's width in landscape
let TOP = 104.0;            // dp: the bar above the board in portrait
let BOTTOM = 196.0;         // dp: the play below it
let GAP = 24.0;

// Where the board and the panels beside it go, in pixels.
struct Layout {
    board: board::Layout,
    left:  float4,      // x, y, width, height of the panel that leaves the game (above in portrait)
    right: float4,      // and of the one that plays it (below in portrait)
}

// The game screen (rendering.md, "Game screen"). Landscape: the board fills the height
// less a 24 dp margin, between two panels 232 dp wide and as tall as it. Portrait: the
// board fills the width less the margin, with a 104 dp bar above it and the 196 dp play
// below it, both as wide as the board.
fn layout(width: f32, height: f32, n: i64) -> Layout {
    let s = gui::scale_of(width, height);
    let gap = GAP * s;
    if width >= height {
        let side = SIDE * s;
        let size = min(height - 2.0 * gap, width - 2.0 * side - 4.0 * gap);
        let x = (width - (size + 2.0 * side + 2.0 * gap)) / 2.0;
        let y = (height - size) / 2.0;
        return Layout { board: board::layout_at(x + side + gap, y, size, s, n), left: float4 { x, y, side, size },
                        right: float4 { x + side + gap + size + gap, y, side, size } };
    }
    let top = TOP * s;
    let bottom = BOTTOM * s;
    let size = min(width - 2.0 * gap, height - top - bottom - 4.0 * gap);
    let x = (width - size) / 2.0;
    let y = (height - (top + size + bottom + 2.0 * gap)) / 2.0;
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

// The left panel's three tiles: the way out (`icon` and the word `word`: home, or the
// puzzles), settings, and start over at the bottom, far from what plays; in portrait a
// bar of three above the board. Returns HOME for the way out, SETTINGS, RESTART, or
// NOTHING.
fn leave(g: gui::Gui&, l: Layout, icon: i64, word: i64) -> i64 {
    let u = g.scale;
    var chosen = NOTHING;
    let words = [word, strings::HOME_SETTINGS, strings::GAME_START_OVER];
    let icons = [icon, gui::GEAR, gui::RESTART];
    let asks = [HOME, SETTINGS, RESTART];
    if l.left.z < l.left.w {
        var left = float4 { l.left.x + 16.0 * u, l.left.y + 20.0 * u, l.left.z - 32.0 * u, l.left.w - 40.0 * u };
        for i in 3 {
            let r = if i < 2 { gui::cut_top(left, ROW_H * u) } else { gui::cut_bottom(left, ROW_H * u) };
            if i == 0 { gui::cut_top(left, 12.0 * u); }
            if gui::labelled(g, 110 + i, r, icons[i], 34.0, strings::get(words[i]), gui::HEADING, gui::BESIDE) {
                chosen = asks[i];
            }
        }
        return chosen;
    }
    let bar = float4 { l.left.x + 20.0 * u, l.left.y + 16.0 * u, l.left.z - 40.0 * u, ROW_H * u };
    let w = (bar.z - 32.0 * u) / 3.0;
    for i in 3 {
        let r = float4 { bar.x + i * (w + 16.0 * u), bar.y, w, bar.w };
        if gui::labelled(g, 110 + i, r, icons[i], 34.0, strings::get(words[i]), gui::HEADING, gui::MIDDLE) {
            chosen = asks[i];
        }
    }
    return chosen;
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
    gui::panel(g, l.left);
    gui::panel(g, l.right);
    var chosen = leave(g, l, gui::HOME, strings::GAME_HOME);
    var right = play_area(g, l);
    if landscape {
        let back = gui::cut_bottom(right, TALL_H * u);
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
            gui::text(g, gui::HEADING, gui::cut_top(right, f.ascent - f.descent), strings::get(turn_key), 1.0, 0.0,
                      gui::CENTER);
        }
        if gui::labelled(g, 113, back, gui::UNDO, 48.0, strings::get(strings::GAME_TAKE_BACK), gui::HEADING,
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
    if gui::labelled(g, 113, gui::cut_top(right, WIDE_H * u), gui::UNDO, 36.0, strings::get(strings::GAME_TAKE_BACK),
                     gui::HEADING, gui::MIDDLE) {
        chosen = UNDO;
    }
    return chosen;
}
