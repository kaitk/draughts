// The game screen's panel (docs/architecture/rendering.md, "Game screen";
// prototypes/game.html): a glass panel beside the board, the side to move on top (task
// 008-02), then undo, hint, restart, and back, in a 2 × 2 grid right of the board in
// landscape and in a row below it in portrait.
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

let ICONS = [gui::UNDO, gui::HINT, gui::RESTART, gui::BACK];

// Declares the panel for this frame; returns the button released this frame, if any.
fn game(g: gui::Gui&, l: board::Layout) -> i64 {
    let u = l.scale;
    gui::panel(g, l.panel);
    let landscape = l.panel.z < l.panel.w;
    var r = gui::inset(l.panel, 24.0 * u);
    // The side to move and the move-hints toggle go in the top row (008-02).
    let top_h = 88.0 * u;
    var chosen = NOTHING;
    if landscape {
        // The top row, a rule, and the 2 × 2 grid, centered down the panel.
        let tile = min(104.0 * u, 0.5 * (r.z - 16.0 * u));
        let gap = 22.0 * u;
        let h = top_h + 2.0 * gap + u + 2.0 * tile + 16.0 * u;
        var col = gui::center(r, r.z, h);
        gui::cut_top(col, top_h + gap);
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
        gui::cut_top(col, top_h + gap);
        for icon, i in ICONS {
            if gui::button(g, 100 + i, gui::cell(col, 4, 1, tile, tile, 24.0 * u, i), icon) { chosen = UNDO + i; }
        }
    }
    return chosen;
}
