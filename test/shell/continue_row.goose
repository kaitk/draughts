// Home's continue (shell::resume, home::Resume; issue 1, prototypes/issue-1.html take a):
// its note says whose game it goes back to, a friend's or the computer's at its level.
// While the game is one nobody set up (none kept: a fresh install, a new player) and no
// move was played in it, the row isn't shown, Friend's the first; a game set up from
// home's setup, or a move played, shows it.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

let NAMES = ["home", "the game", "settings", "the puzzles", "a puzzle"];

fn show(sh: shell::Shell&, what: const u8[:]) {
    let r = shell::resume(sh);
    print(what, ": continue ", if r.on { "shown" } else { "hidden" }, ", note \"",
          if r.note >= 0 { strings::get(r.note) } else { "" }, "\"");
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    show(sh, "a game read back");
    sh.unset = true;
    show(sh, "a first run");
    drive::idle(sh, g, 0.0);
    // Home's first tile in landscape (settings a row of its own): Friend's, with no Continue.
    drive::tap(sh, g, drive::tile(g, 0), 0.1);
    drive::idle(sh, g, 0.2);
    print("  a tap on the first row: ", NAMES[sh.screen], ", setup ", sh.setup, " (", home::FRIEND, " Friend's)");
    shell::back(sh, 0.3);
    drive::idle(sh, g, 0.6);

    sh.setup = home::COMPUTER;
    sh.prefs.level = 0;
    shell::play(sh, 1.0);
    show(sh, "the computer's game set up, easy");
    drive::idle(sh, g, 3.0);
    shell::back(sh, 3.1);
    drive::idle(sh, g, 5.0);
    drive::tap(sh, g, drive::tile(g, 0), 5.1);
    drive::idle(sh, g, 5.2);
    print("  back home, a tap on the first row: ", NAMES[sh.screen]);

    sh.unset = true;
    sh.game = game::new(rules::INTERNATIONAL);
    show(sh, "a new player's game");
    board::play_chosen(sh.game.b, 0, 10.0);
    show(sh, "a move played in it");
}
