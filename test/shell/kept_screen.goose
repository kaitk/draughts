// The screen a kept game comes back on (saved.goose, shell::KINDS' `kept`): the app
// writes the game whatever screen shows as it is paused or quits, so each screen's image
// must restore, the game in it as it was, on the screen it comes back to. A puzzle comes
// back as the puzzles to pick from; the results, a replay, and how to play as home. How
// to play's image once failed to restore at all (2026-11-13), losing the game.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import strings from "../../strings";
import puzzles from "../../src/puzzles";

let NAMES = ["home", "game", "settings", "picker", "puzzle", "results", "replay", "tutorial"];

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    let p, ok = rules::parse_fen("W:Wc3,e3:Bd6,f6", rules::RUSSIAN);
    assert(ok);
    for name, screen in NAMES {
        var sh = shell::new(rules::RUSSIAN);
        board::set(sh.game.b, p);
        sh.screen = screen;
        let image = shell::save(sh);
        var next = shell::new(rules::INTERNATIONAL);
        let back = shell::restore(next, image);
        print(name, ": restored ", back, ", comes back on ", NAMES[next.screen], ", ", rules::fen(next.game.b.pos));
    }
}
