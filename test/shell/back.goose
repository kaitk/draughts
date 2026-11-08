// Android's back, and Escape on the Mac (shell::back), headless: on each screen it does
// what the screen's own back or home control does, the first tile each declares. A setup
// goes back to home's menu, the game, settings opened from home, and the puzzles to pick
// from go home, settings opened from the game or a puzzle go back to it, and a puzzle to
// the puzzles. Each screen is reached twice by the same taps, left once by back and once
// by its tile, and the two must end alike: the screen, home's column, and where the
// board rests. On home's menu back changes nothing and says so (false), for the app to
// hand it to the system. In a transition it turns round, as a tap on the screen come to
// does.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import strings from "../../strings";
import game from "../../game";
import ai from "../../ai";
import shell from "../../shell";
import puzzles from "../../puzzles";
import drive from "../drive";

fn name(screen: i64) -> const u8[:] {
    if screen == shell::HOME { "home" } else if screen == shell::GAME { "the game" }
    else if screen == shell::SETTINGS { "settings" } else if screen == shell::PICKER { "the puzzles" } else { "a puzzle" }
}

fn state(sh: shell::Shell&) -> u8[>..] {
    return str(name(sh.screen), ", setup ", sh.setup, ", in a transition ", sh.from >= 0, ", the board at ",
               sh.layout.board, ", the game ", rules::fen(sh.game.b.pos));
}

// A fresh shell at home with a game under way, then the tiles `path` tapped in
// order, each switch let finish. Returns when the last ended.
fn open(sh: shell::Shell&, g: gui::Gui&, path: i64[:]) -> f64 {
    let p, ok = rules::parse_fen("W:Wc3,e3:Bd6,f6", rules::RUSSIAN);
    assert(ok);
    board::set(sh.game.b, p);
    var now = 0.0;
    drive::idle(sh, g, now);
    for t in path {
        drive::tap(sh, g, drive::tile(g, t), now + 0.1);
        now += 0.6;
        drive::idle(sh, g, now);
    }
    return now;
}

fn check(what: const u8[:], path: i64[:]) {
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::RUSSIAN);
    var now = open(sh, g, path);
    let was = str(name(sh.screen), ", setup ", sh.setup);
    let went = shell::back(sh, now + 0.1);
    drive::idle(sh, g, now + 0.6);
    let by_back = state(sh);

    var h = gui::Gui {};
    gui::test_faces(h);
    var other = shell::new(rules::RUSSIAN);
    now = open(other, h, path);
    drive::tap(other, h, drive::tile(h, 0), now + 0.1);
    drive::idle(other, h, now + 0.6);
    let by_tile = state(other);
    print(what, " (", was, "): back ", went, " -> ", by_back);
    print("  its first tile -> ", if by_tile == by_back { "the same" } else { by_tile });
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    drive::size = float2 { 1280.0, 800.0 };

    // Home's menu: nothing, and false.
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::RUSSIAN);
    drive::idle(sh, g, 0.0);
    let before = state(sh);
    let went = shell::back(sh, 0.1);
    drive::idle(sh, g, 0.6);
    print("home's menu: back ", went, ", unchanged ", state(sh) == before);

    check("a friend's setup", [1]);
    check("the computer's setup", [2]);
    check("the game", [0]);
    check("settings from home", [4]);
    check("settings from the game", [0, 1]);
    check("the puzzles", [3]);
    check("a puzzle", [3, 1]);
    check("settings from a puzzle", [3, 1, 1]);

    // Continue tapped, and back a tenth of a second into the transition: it turns round
    // where it is and ends at home, the game kept.
    var h = gui::Gui {};
    gui::test_faces(h);
    var other = shell::new(rules::RUSSIAN);
    drive::idle(other, h, 0.0);
    drive::tap(other, h, drive::tile(h, 0), 0.1);
    drive::idle(other, h, 0.2);
    print("in the transition to ", name(other.screen), ": back ", shell::back(other, 0.2));
    drive::idle(other, h, 0.25);
    print("  then ", name(other.screen), ", in a transition ", other.from >= 0);
    drive::idle(other, h, 0.6);
    print("  at rest ", state(other));
}
