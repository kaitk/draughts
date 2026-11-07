// The game screen's panel (docs/architecture/rendering.md, "Game screen";
// prototypes/game.html): a glass panel beside the board, the side to move on top with
// the move-hints toggle beside it, then undo, hint, restart, and back, in a 2 × 2 grid
// under a rule right of the board in landscape and in a row below it in portrait.
namespace panel;
import std;
import vec;

import gui from "../gui";
import board from "../board";

// What the panel's buttons ask for.
let NOTHING = 0;
let UNDO = 1;
let HINT = 2;
let RESTART = 3;
let BACK = 4;
let HINTS = 5;              // the move-hints toggle

let ICONS = [gui::UNDO, gui::HINT, gui::RESTART, gui::BACK];

// Declares the panel for this frame. Returns the button released this frame, if any,
// and where the side to move goes: its center and radius.
fn game(g: gui::Gui&, l: board::Layout, hints_on: bool) -> i64, float4 {
    let u = l.scale;
    gui::panel(g, l.panel);
    let landscape = l.panel.z < l.panel.w;
    var r = gui::inset(l.panel, 24.0 * u);
    let top_h = 88.0 * u;
    var chosen = NOTHING;
    var top = r;
    if landscape {
        // The top row, a rule, and the 2 × 2 grid, centered down the panel.
        let tile = min(104.0 * u, 0.5 * (r.z - 16.0 * u));
        let gap = 22.0 * u;
        let h = top_h + 2.0 * gap + u + 2.0 * tile + 16.0 * u;
        var col = gui::center(r, r.z, h);
        top = gui::cut_top(col, top_h);
        gui::cut_top(col, gap);
        gui::fill(g, gui::cut_top(col, u), float4 { 1.0, 1.0, 1.0, 0.18 }, 0.0);
        gui::cut_top(col, gap);
        for icon, i in ICONS {
            if gui::button(g, 100 + i, gui::cell(col, 2, 2, tile, tile, 16.0 * u, i), icon) { chosen = UNDO + i; }
        }
    } else {
        // The top row over the four buttons in a row.
        let tile = 88.0 * u;
        let gap = 18.0 * u;
        var col = gui::center(r, r.z, top_h + gap + tile);
        top = gui::cut_top(col, top_h);
        gui::cut_top(col, gap);
        for icon, i in ICONS {
            if gui::button(g, 100 + i, gui::cell(col, 4, 1, tile, tile, 24.0 * u, i), icon) { chosen = UNDO + i; }
        }
    }
    // The side to move, a 64 dp piece, in the middle of the top row; the toggle, a
    // 52 dp tile, at its right: lit in the glow color while hints show moves.
    let turn = float4 { top.x + 0.5 * top.z, top.y + 0.5 * top.w, 32.0 * u, 0.0 };
    let toggle = gui::center(gui::cut_right(top, 52.0 * u), 52.0 * u, 52.0 * u);
    let look = if hints_on { gui::ON } else { gui::OFF };
    if gui::tile(g, 104, toggle, gui::DOTS, look, 16.0) { chosen = HINTS; }
    return chosen, turn;
}
