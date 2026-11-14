// Settings' 3D board turned by a drag on it, as home's is (shell::drag_board, one camera
// for both, Shell.cam), through the shell on the tablet's landscape at 1280 × 800: a drag
// that starts inside the board's outline turns and tips it (rig::drive: 0.3° a dp, ±35°
// round, 35° to 80° down), drawing only while it moves and nothing once let go. A tap on a
// setting changes the setting and leaves the board's angle alone; a drag from a setting
// onto the board moves nothing, and a drag from the board let go over a setting presses
// nothing. With the language list open a press on the board only closes the list. Leaving
// settings (back, to home) eases the board back to rest over the transition, so home
// shows it at rest; a drag on home's board is likewise undone by opening settings, which
// opens at rest, as it does again after a drag left there and a trip out and back.
import std;
import vec;
import math;
import rules from "../../src/rules";
import board from "../../src/board";
import model3d from "../../src/model3d";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

// Settings' tiles in the order the screen declares them (test/shell/settings).
let BACK = 0;
let LANGUAGE = 1;
let SUMMER = 6;

fn r1(x: f32) -> f64 { floor((x as f64) * 10.0 + 0.5) / 10.0 }

// The angle the shell's 3D board shows at `now`: round, and down.
fn angle(sh: shell::Shell&, now: f64) -> u8[>..] {
    let c = rig::camera(sh.cam, view3d::PITCH, now);
    return str("yaw ", r1(c.yaw), ", pitch ", r1(c.pitch));
}

// A drag from a to b in `steps` moves, pressed at `now`, released over b; how many of
// its frames asked to be drawn.
fn drag(sh: shell::Shell&, g: gui::Gui&, a: float2, b: float2, steps: i64, now: f64) -> i64 {
    var drawn = 0;
    if drive::frame(sh, g, a, true, true, false, now) { drawn++; }
    for i in 1..steps + 1 {
        let p = a + (b - a) * ((i as f32) / steps);
        if drive::frame(sh, g, p, true, false, false, now + 0.02 * i) { drawn++; }
    }
    if drive::frame(sh, g, b, false, false, true, now + 0.02 * (steps + 1)) { drawn++; }
    return drawn;
}

// Frames at rest from `now`: how many changed or kept animating.
fn rest(sh: shell::Shell&, g: gui::Gui&, now: f64) -> i64 {
    var drawn = 0;
    for i in 10 {
        let t = now + 0.1 * i;
        if drive::idle(sh, g, t) || shell::animating(sh, g, t) { drawn++; }
    }
    return drawn;
}

// The middle of the 3D board's bounds as the last frame drew it.
fn middle(sh: shell::Shell&) -> float2 {
    let r = sh.out.view.rect;
    return float2 { r.x + 0.5 * r.z, r.y + 0.5 * r.w };
}

fn main() {
    var g = gui::Gui {};
    strings::use(strings::EN);
    puzzles::load();
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(1280.0, 800.0);
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    sh.prefs.board = settings::RAISED;
    shell::apply_prefs(sh);
    drive::idle(sh, g, 0.0);
    shell::open_settings(sh, shell::HOME, 0.5);
    drive::idle(sh, g, 0.5);
    drive::idle(sh, g, 2.0);
    let r = sh.out.view.rect;
    let eye = sh.out.view.eye;
    let mid = middle(sh);
    print("settings at rest: ", angle(sh, 2.0), ", raised ", sh.out.raised, ", its middle on the board ",
          view3d::on_board(sh.out.view, mid));

    // On the board: 100 px left and 50 down turn it 30° and tip it 15° toward the top.
    let d1 = drag(sh, g, mid, mid + float2 { -100.0, 50.0 }, 5, 8.0);
    print("dragged on the board: ", angle(sh, 8.2), ", frames drawn ", d1, " of 7, the view drawn turned ",
          r1(sh.out.view.eye.x) != 0.0, ", the screen settings ", sh.screen == shell::SETTINGS);
    print("let go: frames drawn at rest ", rest(sh, g, 9.0), ", ", angle(sh, 10.0));

    // A setting tapped: the season changes, the angle stays.
    let before = angle(sh, 11.0);
    let season = sh.prefs.season;
    drive::tap(sh, g, drive::tile(g, SUMMER), 11.0);
    print("a season tapped: the setting changed ", sh.prefs.season != season, ", the angle kept ", angle(sh, 11.5) == before);
    // From a setting onto the board: the press is the setting's, the board stays.
    shell::wrote(sh);
    let theme = sh.prefs.season;
    drag(sh, g, drive::tile(g, SUMMER), mid, 5, 12.0);
    print("a drag from a setting onto the board: the angle kept ", angle(sh, 12.5) == before, ", nothing changed ",
          !sh.changed && sh.prefs.season == theme);
    // From the board, let go over a setting: the board turns, the setting isn't pressed.
    drive::idle(sh, g, 12.8);
    let tile = drive::tile(g, SUMMER + 1);
    drag(sh, g, mid, tile, 5, 13.0);
    print("a drag from the board let go over a setting: ", angle(sh, 13.5), ", nothing changed ",
          !sh.changed && sh.prefs.season == theme);
    drag(sh, g, mid, mid + float2 { 600.0, 0.0 }, 4, 14.0);
    // The language list open: a press on the board closes it and turns nothing.
    let held = angle(sh, 14.5);
    drive::tap(sh, g, drive::tile(g, LANGUAGE), 15.0);
    let open = sh.prefs.languages_open;
    drag(sh, g, mid, mid + float2 { -100.0, 0.0 }, 4, 15.5);
    print("the language list open ", open, ", a drag on the board closes it ", !sh.prefs.languages_open,
          " and the angle kept ", angle(sh, 16.0) == held);

    // Back, to home: the board eases back to rest over the transition.
    drive::idle(sh, g, 17.0);
    drive::tap(sh, g, drive::tile(g, BACK), 17.0);
    print("back: screen home ", sh.screen == shell::HOME, ", halfway ", angle(sh, 17.02 + 0.5 * shell::DURATION),
          ", at its end ", angle(sh, 17.02 + shell::DURATION));
    drive::idle(sh, g, 18.0);
    print("home: ", angle(sh, 18.0), ", drawn at rest ", rest(sh, g, 18.5));

    // Home's board dragged, then settings opened: they open at rest.
    let hm = middle(sh);
    drag(sh, g, hm, hm + float2 { 60.0, 30.0 }, 3, 20.0);
    let turned = angle(sh, 20.2);
    shell::open_settings(sh, shell::HOME, 20.5);
    drive::idle(sh, g, 20.5);
    drive::idle(sh, g, 22.0);
    print("home dragged to ", turned, ", settings opened: ", angle(sh, 22.0), ", the view as at first ",
          sh.out.view.eye == eye && sh.out.view.rect == r);

    // Dragged in settings, out to the game and back: at rest again.
    drag(sh, g, mid, mid + float2 { -60.0, -30.0 }, 3, 23.0);
    let left = angle(sh, 23.2);
    shell::go_to(sh, shell::GAME, 23.5);
    drive::idle(sh, g, 23.5);
    drive::idle(sh, g, 25.0);
    shell::open_settings(sh, shell::GAME, 25.5);
    drive::idle(sh, g, 25.5);
    drive::idle(sh, g, 27.0);
    drive::idle(sh, g, 30.0); // the preview's flash and pulse over
    print("settings dragged to ", left, ", out to the game and back: ", angle(sh, 27.0), ", the view as at first ",
          sh.out.view.eye == eye && sh.out.view.rect == r, ", drawn at rest ", rest(sh, g, 31.0));

    // The flat board: no turn.
    var flat = shell::new(rules::INTERNATIONAL);
    shell::open_settings(flat, shell::HOME, 0.0);
    drive::idle(flat, g, 0.0);
    drive::idle(flat, g, 1.0);
    let fl = flat.out.layout.board;
    let fm = float2 { fl.x + 0.5 * fl.z, fl.y + 0.5 * fl.z };
    drag(flat, g, fm, fm + float2 { 100.0, 0.0 }, 4, 2.0);
    print("flat: ", angle(flat, 3.0), ", raised ", flat.out.raised);
}
