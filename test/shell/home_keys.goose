// Home with the keys and a desktop's Quit row (task 072), headless. On a desktop
// (desktop_scale above 0) in landscape the way out is a last row, Quit, under settings, and
// the X isn't shown; in portrait, in a landscape too short for the row, and on a touch
// screen (desktop_scale 0) the X is, and no Quit row. The first arrow key focuses
// Continue, the menu's primary row; down walks the rows to Quit and stops there; Enter on
// Quit asks first (home::ask_quit), the question's quit focused, and back cancels it, as
// back on the menu asks it; Enter there asks the app to stop (quit). Enter on a friend
// opens its setup, whose focus goes to play, its primary, and Enter there starts the game.
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

// Home's way out as this frame declared it: the Quit row, the X, or none.
fn way(g: gui::Gui&) -> const u8[:] {
    var quit = false;
    var x = false;
    for s in g.spots {
        if s.id == gui::HOME_IDS + 6 { quit = true; }
        if s.id == gui::HOME_IDS + 9 { x = true; }
    }
    if quit && x { return "both"; }
    return if quit { "the Quit row" } else if x { "the X" } else { "none" };
}

fn layout(what: const u8[:], size: float2, desktop: f32) {
    drive::size = size;
    gui::desktop_scale = desktop;
    var sh = shell::new(rules::INTERNATIONAL);
    var g = gui::Gui {};
    gui::test_faces(g);
    drive::idle(sh, g, 0.0);
    print(what, ": ", way(g));
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    layout("a desktop, 1280 x 800", float2 { 1280.0, 800.0 }, 1.0);
    // The headless layout is 800 dp on the shorter side; a desktop's small window is fewer.
    print("a desktop's landscape 400 dp tall, too short for it: the Quit row ", home::quit_row(true, 400.0, 1.0));
    layout("a desktop in portrait, 800 x 1280", float2 { 800.0, 1280.0 }, 1.0);
    layout("a touch screen, 1280 x 800", float2 { 1280.0, 800.0 }, 0.0);

    drive::size = float2 { 1280.0, 800.0 };
    gui::desktop_scale = 1.0;
    var sh = shell::new(rules::INTERNATIONAL);
    var g = gui::Gui {};
    gui::test_faces(g);
    var now = 0.0;
    drive::idle(sh, g, now);
    var walk: u8[>..] = [];
    for i in 8 {
        now += 1.0;
        drive::key(sh, g, gui::STEP_DOWN, false, now);
        format(walk, " ", g.focus - gui::HOME_IDS);
    }
    print("down from none, eight times (ids past HOME_IDS; the games 7):", walk[..]);
    now += 1.0;
    drive::key(sh, g, gui::STEP_NONE, true, now);
    print("enter on Quit: quit ", sh.out.quit, ", asks ", sh.quitting);
    // The question's buttons, its quit the keys' first choice; back (Escape, a gamepad's
    // B) cancels it, and back on the menu asks again.
    now += 1.0;
    drive::idle(sh, g, now);
    now += 1.0;
    drive::idle(sh, g, now);
    print("the question: focus ", g.focus - gui::HOME_IDS, " (quit 15)");
    print("back: handled ", shell::back(sh, now), ", asks ", sh.quitting);
    print("back on the menu: handled ", shell::back(sh, now), ", asks ", sh.quitting);
    now += 1.0;
    drive::idle(sh, g, now);
    now += 1.0;
    drive::key(sh, g, gui::STEP_NONE, true, now);
    print("enter on the question: quit ", sh.out.quit);

    var fr = shell::new(rules::INTERNATIONAL);
    g = gui::Gui {};
    gui::test_faces(g);
    now = 0.0;
    drive::idle(fr, g, now);
    drive::key(fr, g, gui::STEP_DOWN, false, 1.0);
    drive::key(fr, g, gui::STEP_DOWN, false, 2.0);
    print("on a friend: focus ", g.focus - gui::HOME_IDS);
    drive::key(fr, g, gui::STEP_NONE, true, 3.0);
    drive::idle(fr, g, 3.02);
    drive::idle(fr, g, 3.04);
    print("enter: setup ", fr.setup == home::FRIEND, ", focus ", g.focus - gui::HOME_IDS);
    drive::key(fr, g, gui::STEP_NONE, true, 4.0);
    for i in 200 { drive::idle(fr, g, 4.02 + 0.02 * i); }
    print("enter on play: screen ", if fr.screen == shell::GAME { "the game" } else { "still home" }, ", focus on the game's panels ",
          g.focus >= gui::PANEL_IDS && g.focus < gui::CARD_IDS);
}
