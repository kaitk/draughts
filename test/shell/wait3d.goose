// The 3D board chosen but not ready yet (the app gets it ready a step a frame and says so
// in sh.ready3d, task 042), headless. With no image of it yet (sh.shown3d false) a still
// mark, glass round the words "Preparing 3D…", shows in the middle of where the board goes,
// on the game, home, and settings alike, and nothing in the shell animates for it (the
// app draws its steps); a tap on a piece is left alone while the UI's tiles still answer.
// Once it is ready the mark is gone and the same tap selects the piece. While a new theme
// gets ready over an image already shown, there is no mark, and taps still wait.
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

// Whether quad q's middle is the 3D board's bounds' middle, within half a pixel.
fn centred(sh: shell::Shell&, q: gui::Quad) -> bool {
    let r = sh.place;
    return abs(q.rect.x + 0.5 * q.rect.z - (r.x + 0.5 * r.z)) < 0.5 && abs(q.rect.y + 0.5 * q.rect.w - (r.y + 0.5 * r.w)) < 0.5;
}

// The waiting marks the last frame declared: glass in the middle of the board's bounds.
fn marks(sh: shell::Shell&, g: gui::Gui&) -> i64 {
    var n = 0;
    for q in g.quads { if q.look.x == gui::GLASS && centred(sh, q) { n++; } }
    return n;
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

    // The game, waiting with nothing shown: the mark, and nothing animating for it once
    // the game's own start has settled.
    var sh = shell::new(rules::RUSSIAN);
    sh.prefs.board = settings::RAISED;
    sh.screen = shell::GAME;
    sh.ready3d = false;
    sh.shown3d = false;
    drive::idle(sh, g, 0.0);
    drive::idle(sh, g, 5.0);
    print("game, waiting: raised ", sh.raised, ", marks in the board's middle ", marks(sh, g), ", animating ",
          shell::animating(sh, g, 5.5));
    drive::tap(sh, g, on_screen(sh, v, "c3", top), 6.0);
    print("  c3 tapped: selected ", sh.game.b.selected, " (none is -1)");
    // The panels answer meanwhile: some tile leaves the game.
    var went = false;
    for i in drive::tiles(g) {
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

    // Ready: no mark, and the tap selects.
    sh.ready3d = true;
    sh.shown3d = true;
    drive::idle(sh, g, 7.0);
    print("game, ready: marks ", marks(sh, g));
    drive::tap(sh, g, on_screen(sh, v, "c3", top), 8.0);
    print("  c3 tapped: selected ", drive::name(v, sh.game.b.selected));

    // A new theme getting ready over the image shown: no mark, taps wait.
    var th = shell::new(rules::RUSSIAN);
    th.prefs.board = settings::RAISED;
    th.screen = shell::GAME;
    th.ready3d = false;
    th.shown3d = true;
    drive::idle(th, g, 0.0);
    drive::tap(th, g, on_screen(th, v, "c3", top), 1.0);
    print("game, a new theme getting ready: marks ", marks(th, g), ", c3 tapped: selected ", th.game.b.selected);

    // Home and settings, waiting: the mark where their board goes, in both languages.
    for lang in [strings::EN, strings::ET] {
        strings::use(lang);
        for screen in [shell::HOME, shell::SETTINGS] {
            var s = shell::new(rules::RUSSIAN);
            s.prefs.board = settings::RAISED;
            s.screen = screen;
            s.ready3d = false;
            s.shown3d = false;
            drive::idle(s, g, 0.0);
            drive::idle(s, g, 1.0);
            print(if screen == shell::HOME { "home" } else { "settings" }, ", waiting: raised ", s.raised,
                  ", marks in the board's middle ", marks(s, g), ", saying \"", strings::get(strings::BOARD_PREPARING), "\"");
        }
    }
    strings::use(strings::EN);

    // Flat: never a mark, whatever the app says of the 3D board.
    var flat = shell::new(rules::RUSSIAN);
    flat.screen = shell::GAME;
    flat.ready3d = false;
    flat.shown3d = false;
    drive::idle(flat, g, 0.0);
    print("flat: marks ", marks(flat, g));
}
