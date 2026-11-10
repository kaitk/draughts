// Home's 3D board turned by a drag on it (2026-11-09), through the shell on the tablet's
// landscape at 1280 × 800 (a dp a pixel): a drag that starts inside the board's outline
// on screen moves the game's showcase camera (rig::drive: 0.3° a dp, ±35° round, 35° to
// 80° down), drawing only while it moves and nothing once let go, the angle kept while
// home stays open; a drag far past the range stops at its ends. A drag that starts off
// the board (beside it, or on the column's glass) and a tap on a menu row leave it alone.
// Leaving home (continue, to the game) eases it back to rest over the transition, and
// home shows its board at rest again on return. The flat board has none of it.
import std;
import vec;
import math;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn r1(x: f32) -> f64 { floor((x as f64) * 10.0 + 0.5) / 10.0 }

// The angle home's board shows at `now`: round, and down.
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

// Whether the board as drawn stays in its room: on the screen, clear of every tile, its
// bounds' middle at `mid` (the rest view's), and no larger than at rest (k0).
fn in_room(sh: shell::Shell&, g: gui::Gui&, mid: float2, k0: f32) -> bool {
    let v = sh.view.rect;
    var clear = true;
    for i in drive::tiles(g) { if view3d::touches(sh.view, drive::rect(g, i), 0.0) { clear = false; } }
    return clear && v.x >= 0.0 && v.y >= 0.0 && v.x + v.z <= drive::size.x && v.y + v.w <= drive::size.y
           && abs(v.x + 0.5 * v.z - mid.x) < 0.5 && abs(v.y + 0.5 * v.w - mid.y) < 0.5 && sh.view.k <= k0;
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

fn main() {
    var g = gui::Gui {};
    strings::use(strings::EN);
    puzzles::load();
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(1280.0, 800.0);
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    sh.prefs.board = settings::RAISED;
    drive::idle(sh, g, 0.0);
    drive::idle(sh, g, 1.0);
    let r = sh.view.rect;
    let eye = sh.view.eye;
    let k0 = sh.view.k;
    let mid = float2 { r.x + 0.5 * r.z, r.y + 0.5 * r.w };
    print("home at rest: ", angle(sh, 1.0), ", its middle on the board ", view3d::on_board(sh.view, mid),
          ", the screen's corner ", view3d::on_board(sh.view, float2 { 1270.0, 790.0 }), ", the bounds' corner ",
          view3d::on_board(sh.view, float2 { r.x + 2.0, r.y + 2.0 }));

    // On the board: 100 px left and 50 down turn it 30° and tip it 15° toward the top.
    let d1 = drag(sh, g, mid, mid + float2 { -100.0, 50.0 }, 5, 2.0);
    print("dragged on the board: ", angle(sh, 2.2), ", frames drawn ", d1, " of 7, the view drawn turned ",
          r1(sh.view.eye.x) != 0.0, ", in its room ", in_room(sh, g, mid, k0), " at ",
          r1(100.0 * sh.view.k / k0), "% of its size");
    print("let go: frames drawn at rest ", rest(sh, g, 3.0), ", ", angle(sh, 4.0));
    // Off the board: beside it in the stage, under its outline's foot, and on the column's
    // glass between rows; a tap on the friend row opens the setup and back.
    let before = angle(sh, 8.0);
    let beside = float2 { 1250.0, mid.y };
    let foot = float2 { mid.x, 790.0 };
    print("beside the board on it ", view3d::on_board(sh.view, beside), ", under it ", view3d::on_board(sh.view, foot));
    drag(sh, g, beside, beside + float2 { -200.0, 0.0 }, 4, 8.0);
    drag(sh, g, foot, foot + float2 { 0.0, -200.0 }, 4, 8.5);
    let row = drive::rect(g, 1);
    let glass = float2 { row.x + 0.5 * row.z, row.y - 1.0 };
    drag(sh, g, glass, mid, 4, 9.0);
    drive::tap(sh, g, drive::tile(g, 1), 9.5);
    let setup = sh.setup == home::FRIEND;
    drive::tap(sh, g, drive::tile(g, 0), 9.6);
    print("drags off the board and a menu row tapped: the angle kept ", angle(sh, 10.0) == before, ", the setup opened ",
          setup, " and closed ", sh.setup == home::NO_SETUP);
    // Far past the range, the other way: it stops at its ends.
    drag(sh, g, mid, mid + float2 { 600.0, 400.0 }, 4, 11.0);
    print("dragged far: ", angle(sh, 11.2), ", in its room ", in_room(sh, g, mid, k0), " at ", r1(100.0 * sh.view.k / k0),
          "%");
    drag(sh, g, mid, mid + float2 { -600.0, -600.0 }, 4, 11.5);
    print("dragged far back: ", angle(sh, 11.7), ", in its room ", in_room(sh, g, mid, k0), " at ",
          r1(100.0 * sh.view.k / k0), "%, frames drawn at rest ", rest(sh, g, 12.0));

    // In the setup the board turns too.
    drive::tap(sh, g, drive::tile(g, 1), 13.1);
    drive::idle(sh, g, 13.2);
    let rs = sh.view.rect;
    let ms = float2 { rs.x + 0.5 * rs.z, rs.y + 0.5 * rs.w };
    drag(sh, g, ms, ms + float2 { 30.0, 0.0 }, 3, 13.3);
    print("in the setup: ", angle(sh, 13.5));
    drive::tap(sh, g, drive::tile(g, 0), 13.6);

    // Continue: to the game, the board easing back to rest over the transition.
    drive::idle(sh, g, 14.0);
    drive::tap(sh, g, drive::tile(g, 0), 14.1);
    print("continue: screen game ", sh.screen == shell::GAME, ", halfway ", angle(sh, 14.12 + 0.5 * shell::DURATION),
          ", at its end ", angle(sh, 14.12 + shell::DURATION), ", the showcase off ", !sh.game.cam.showcase,
          ", the game's camera at rest ", !rig::off_rest(sh.game.cam));
    drive::idle(sh, g, 15.0);
    // Back home: its board at rest.
    sh.from = -1;
    shell::go_to(sh, shell::HOME, 16.0);
    drive::idle(sh, g, 16.0);
    drive::idle(sh, g, 17.0);
    print("home again: ", angle(sh, 17.0), ", the view as at first ", sh.view.eye == eye && sh.view.rect == r,
          ", drawn at rest ", rest(sh, g, 18.0));

    // The flat board: no turn.
    var flat = shell::new(rules::INTERNATIONAL);
    drive::idle(flat, g, 0.0);
    let fl = flat.layout.board;
    let fm = float2 { fl.x + 0.5 * fl.z, fl.y + 0.5 * fl.z };
    drag(flat, g, fm, fm + float2 { 100.0, 0.0 }, 4, 1.0);
    print("flat: ", angle(flat, 2.0), ", raised ", flat.raised);
}
