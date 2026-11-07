// The app's screens, with no graphics: home and the game, and which one shows
// (docs/architecture/rendering.md, "Home", "Game screen"). Each frame it declares the
// screen showing and switches when that asks: home's continue and a friend open the
// game, the game's back returns home. It says where the board goes this frame and
// whether the photograph behind it is sharp, for the app to draw. Tests run it headless.
namespace shell;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import .home;

let HOME = 0;
let GAME = 1;

struct Shell {
    screen: i64 = HOME,
    game:   game::Game,
    layout: board::Layout,          // where the board is this frame
    sharp:  bool = true,            // the photograph as it is (home), or blurred (the game)
}

fn new(variant: u8) -> Shell {
    let g = game::new(variant);
    return Shell { game: g, layout: board::layout(1.0, 1.0, rules::VARIANTS[variant].size), .. };
}

// One frame, after gui::begin, on a screen width × height pixels. Returns whether
// anything on screen changed.
fn frame(sh: Shell&, g: gui::Gui&, width: f32, height: f32, now: f64) -> bool {
    let n = rules::VARIANTS[sh.game.b.variant].size;
    if sh.screen == GAME {
        sh.layout = board::layout(width, height, n);
        sh.sharp = false;
        let go, changed = game::frame(sh.game, g, sh.layout, now);
        if go == game::HOME {
            sh.screen = HOME;
            return true;
        }
        return changed;
    }
    sh.sharp = true;
    var changed = board::update(sh.game.b, now) || g.input.pressed || g.input.released;
    let pick = home::frame(sh.game, g, sh.layout, width, height);
    if pick == home::CONTINUE {
        sh.screen = GAME;
        changed = true;
    }
    if pick == home::FRIEND {
        board::set(sh.game.b, rules::start(sh.game.b.variant));
        sh.game.won_at = -1.0;
        sh.screen = GAME;
        changed = true;
    }
    return changed;
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(sh: Shell&, g: gui::Gui&, now: f64) -> bool {
    return if sh.screen == GAME { game::animating(sh.game, g, now) }
           else { board::animating(sh.game.b, now) || gui::animating(g) };
}
