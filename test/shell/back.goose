// Android's back, and Escape on the Mac (shell::back), headless: on each screen it does
// what the screen's own back control does, the first tile each declares, which is the
// arrow (prototypes/back.html, take b: the arrow and "Back" wherever the game, a puzzle,
// the puzzles, and settings leave), 88 dp at least, in landscape and in portrait. A setup
// goes back to home's menu, the game, settings opened from home, and the puzzles to pick
// from go home, settings opened from the game or a puzzle go back to it, a puzzle to its
// theme's page, and a theme's page to the library of themes. Each screen is reached twice by the same taps, left once by back and once
// by its tile, and the two must end alike: the screen, home's column, and where the
// board rests. On home's menu back changes nothing and says so (false), for the app to
// hand it to the system. In a transition it turns round, as a tap on the screen come to
// does.
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

fn name(sh: shell::Shell&) -> const u8[:] {
    let screen = sh.screen;
    if screen == shell::HOME { "home" } else if screen == shell::GAME { "the game" }
    else if screen == shell::SETTINGS { "settings" } else if screen == shell::GAMES { "the games" }
    else if screen == shell::PICKER { if sh.theme >= 0 { "a theme" } else { "the puzzles" } } else { "a puzzle" }
}

fn state(sh: shell::Shell&) -> u8[>..] {
    return str(name(sh), ", setup ", sh.setup, ", in a transition ", sh.from >= 0, ", the board at ",
               sh.out.layout.board, ", the game ", rules::fen(sh.game.b.pos));
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

// Whether the first tile the last frame declared shows the arrow back, and its size in dp.
fn first_back(g: gui::Gui&) -> u8[>..] {
    let r = drive::rect(g, 0);
    var seen = false;
    var arrow = false;
    for q in g.quads {
        if q.look.x == gui::BUTTON && q.rect == r { seen = true; }
        if seen && q.look.x == gui::ICON {
            arrow = q.look.z == gui::BACK;
            break;
        }
    }
    let u = g.scale;
    let big = r.z >= gui::TAP * u - 0.5 && r.w >= gui::TAP * u - 0.5;
    return str(if arrow { "the arrow" } else { "not the arrow" }, if big { "" } else { ", under 88 dp" });
}

fn check(what: const u8[:], path: i64[:]) {
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::RUSSIAN);
    var now = open(sh, g, path);
    let was = str(name(sh), ", setup ", sh.setup);
    let arrow = first_back(g);
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
    print("  its first tile (", arrow, ") -> ", if by_tile == by_back { "the same" } else { by_tile });
}

// Each screen, reached from home's menu, whose rows start at tile `o` (after the gear in
// portrait) and whose settings is tile `gear`.
fn screens(o: i64, gear: i64) {
    check("a friend's setup", [1 + o]);
    check("the computer's setup", [2 + o]);
    check("the game", [o]);
    check("settings from home", [gear]);
    check("settings from the game", [o, 1]);
    check("the puzzles", [3 + o]);
    check("the games", [4 + o]);
    check("a theme", [3 + o, drive::LEARN_ROW]);
    check("a puzzle", [3 + o, drive::LEARN_ROW, 1]);
    check("settings from a puzzle", [3 + o, drive::LEARN_ROW, 1, 1]);
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

    screens(0, 5);
    // Portrait, where the game's and a puzzle's back leads the bar above the board.
    drive::size = float2 { 800.0, 1280.0 };
    print("portrait:");
    screens(1, 0);
    drive::size = float2 { 1280.0, 800.0 };

    // Continue tapped, and back a tenth of a second into the transition: it turns round
    // where it is and ends at home, the game kept.
    var h = gui::Gui {};
    gui::test_faces(h);
    var other = shell::new(rules::RUSSIAN);
    drive::idle(other, h, 0.0);
    drive::tap(other, h, drive::tile(h, 0), 0.1);
    drive::idle(other, h, 0.2);
    print("in the transition to ", name(other), ": back ", shell::back(other, 0.2));
    drive::idle(other, h, 0.25);
    print("  then ", name(other), ", in a transition ", other.from >= 0);
    drive::idle(other, h, 0.6);
    print("  at rest ", state(other));
}
