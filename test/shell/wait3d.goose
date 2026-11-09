// The 3D board chosen but not ready yet (the app gets it ready a step a frame and says so
// in sh.ready3d, task 042), headless. With no image of it yet (sh.shown3d false) a spinner
// shows where the board goes, on the game, home, and settings alike, and the shell keeps
// drawing; a tap on a piece is left alone while the UI's tiles still answer. Once it is
// ready the spinner is gone and the same tap selects the piece. While a new theme gets
// ready over an image already shown, there is no spinner, and taps still wait.
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

fn spinners(g: gui::Gui&) -> i64 {
    var n = 0;
    for q in g.quads { if q.look.x == gui::SPINNER { n++; } }
    return n;
}

// The spinner's middle against the 3D board's bounds' middle, in whole pixels.
fn centred(sh: shell::Shell&, g: gui::Gui&) -> bool {
    for q in g.quads {
        guard q.look.x == gui::SPINNER else { continue; }
        let r = sh.place;
        return abs(q.rect.x + 0.5 * q.rect.z - (r.x + 0.5 * r.z)) < 0.5
               && abs(q.rect.y + 0.5 * q.rect.w - (r.y + 0.5 * r.w)) < 0.5;
    }
    return false;
}

fn on_screen(sh: shell::Shell&, v: rules::Variant&, name: const u8[:], h: f32) -> float2 {
    let c = view3d::to_world(sh.layout, board::center(sh.layout, v, drive::square(v, name)));
    let q = view3d::project(sh.view, float3 { c.x, h, c.y });
    return float2 { q.x, q.y };
}

fn main() {
    var g = gui::Gui {};
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(1280.0, 800.0);
    gui::test_faces(g);
    strings::use(strings::EN);
    puzzles::load();
    let v .= rules::VARIANTS[rules::RUSSIAN];
    let top = view3d::HEIGHT * view3d::unit(8);

    // The game, waiting with nothing shown.
    var sh = shell::new(rules::RUSSIAN);
    sh.prefs.board = settings::RAISED;
    sh.screen = shell::GAME;
    sh.ready3d = false;
    sh.shown3d = false;
    drive::idle(sh, g, 0.0);
    print("game, waiting: raised ", sh.raised, ", spinners ", spinners(g), " in the board's middle ", centred(sh, g),
          ", drawing on ", shell::animating(sh, g, 0.5));
    drive::tap(sh, g, on_screen(sh, v, "c3", top), 1.0);
    print("  c3 tapped: selected ", sh.game.b.selected, " (none is -1)");
    // The panels answer meanwhile: the settings tile.
    var tiles = drive::tiles(g);
    var went = false;
    for i in tiles {
        var s = shell::new(rules::RUSSIAN);
        s.prefs.board = settings::RAISED;
        s.screen = shell::GAME;
        s.ready3d = false;
        s.shown3d = false;
        drive::idle(s, g, 0.0);
        drive::tap(s, g, drive::tile(g, i), 1.0);
        if s.screen == shell::SETTINGS || s.from == shell::GAME { went = true; }
    }
    print("  a panel tile still leaves the game: ", went);

    // Ready: no spinner, and the tap selects.
    sh.ready3d = true;
    sh.shown3d = true;
    drive::idle(sh, g, 2.0);
    print("game, ready: spinners ", spinners(g), ", drawing on ", shell::animating(sh, g, 2.5));
    drive::tap(sh, g, on_screen(sh, v, "c3", top), 3.0);
    print("  c3 tapped: selected ", drive::name(v, sh.game.b.selected));

    // A new theme getting ready over the image shown: no spinner, taps wait.
    var th = shell::new(rules::RUSSIAN);
    th.prefs.board = settings::RAISED;
    th.screen = shell::GAME;
    th.ready3d = false;
    th.shown3d = true;
    drive::idle(th, g, 0.0);
    drive::tap(th, g, on_screen(th, v, "c3", top), 1.0);
    print("game, a new theme getting ready: spinners ", spinners(g), ", c3 tapped: selected ", th.game.b.selected);

    // Home and settings, waiting: the spinner where their board goes.
    for screen in [shell::HOME, shell::SETTINGS] {
        var s = shell::new(rules::RUSSIAN);
        s.prefs.board = settings::RAISED;
        s.screen = screen;
        s.ready3d = false;
        s.shown3d = false;
        drive::idle(s, g, 0.0);
        drive::idle(s, g, 1.0);
        print(if screen == shell::HOME { "home" } else { "settings" }, ", waiting: raised ", s.raised, ", spinners ",
              spinners(g), " in the board's middle ", centred(s, g));
    }

    // Flat: never a spinner, whatever the app says of the 3D board.
    var flat = shell::new(rules::RUSSIAN);
    flat.screen = shell::GAME;
    flat.ready3d = false;
    flat.shown3d = false;
    drive::idle(flat, g, 0.0);
    print("flat: spinners ", spinners(g));
}
