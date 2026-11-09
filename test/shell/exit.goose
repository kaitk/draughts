// Home's way out (shell/home.goose), headless: a round X 88 dp across in the screen's top
// right, 24 dp from both edges, on the menu and in a setup, in landscape and portrait.
// A tap on it makes home ask for EXIT and the shell ask the app to stop (quit), which
// ends its loop as Escape does; the game is then written as at any loop's end, and that
// image restores it. A tap just outside it, left of it or under it, does nothing. It
// goes down while held as the other tiles do. It is clear of the board and of the column
// or sheet: in portrait the board moves down to 16 dp under it and shrinks to keep 24 dp
// above the sheet. On iOS, where an app never closes itself, home shows none
// (home::closable): a tap where it would be does nothing.
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

// The way out: the last tile home declares.
fn way_out(g: gui::Gui&) -> float4 { drive::rect(g, drive::tiles(g) - 1) }

fn overlaps(a: float4, b: float4) -> bool {
    return a.x < b.x + b.z && b.x < a.x + a.z && a.y < b.y + b.w && b.y < a.y + a.w;
}

// Home at rest on the screen drive::size, the menu or a setup.
fn fresh(setup: i64) -> shell::Shell {
    var sh = shell::new(rules::INTERNATIONAL);
    sh.setup = setup;
    return sh;
}

fn check(what: const u8[:], setup: i64) {
    var g = gui::Gui {};
    gui::test_faces(g);
    let u = gui::scale_of(drive::size.x, drive::size.y);
    var sh = fresh(setup);
    drive::idle(sh, g, 0.0);
    let r = way_out(g);
    let b = sh.layout.board;
    // The column or sheet: the first glass.
    var col = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads { if q.look.x == gui::GLASS && col.z == 0.0 { col = q.rect; } }
    print(what, ": the way out at ", r, " (", (drive::size.x - r.x - r.z) / u, " dp from the right, ", r.y / u,
          " from the top, ", r.z / u, " across), the board at ", b, ", clear of the board ", !overlaps(r, b),
          ", of the column ", !overlaps(r, col), ", the board's gap under it ", (b.y - r.y - r.w) / u,
          " dp, beside it ", (r.x - b.x - b.z) / u, " dp");

    // Just outside it, left and under: nothing.
    drive::tap(sh, g, float2 { r.x - 1.0, r.y + 0.5 * r.w }, 1.0);
    drive::tap(sh, g, float2 { r.x + 0.5 * r.z, r.y + r.w + 1.0 }, 1.1);
    print("  a tap just left of it and just under it: quit ", sh.quit, ", ", if sh.screen == shell::HOME { "home" } else { "moved" },
          ", setup ", sh.setup);

    // Held: it goes down as a tile does.
    let at = drive::middle(r);
    drive::frame(sh, g, at, true, true, false, 2.0);
    drive::frame(sh, g, at, true, false, false, 2.0 + gui::PRESS);
    print("  held: pressed ", g.quads[g.quads.len - 2].look.w, ", quit ", sh.quit);
    drive::frame(sh, g, at, false, false, true, 2.2);
    print("  released over it: quit ", sh.quit);

    // Home itself asks for EXIT.
    var l = sh.layout;
    var room = float4 { 0.0, 0.0, 0.0, 0.0 };
    var over: game::Overlay = [];
    var h = gui::Gui {};
    gui::test_faces(h);
    gui::begin(h, gui::Input { at: at, down: true, pressed: true, .. }, u, 3.0);
    home::frame(over, h, l, 10, float4 { 0.0, 0.0, drive::size.x, drive::size.y }, setup, sh.prefs, room);
    gui::begin(h, gui::Input { at: at, released: true, .. }, u, 3.02);
    print("  home asks for EXIT: ", home::frame(over, h, l, 10, float4 { 0.0, 0.0, drive::size.x, drive::size.y }, setup, sh.prefs, room) == home::EXIT);
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    drive::size = float2 { 1280.0, 800.0 };
    check("landscape", home::NOTHING);
    check("landscape, the computer's setup", home::COMPUTER);
    drive::size = float2 { 800.0, 1280.0 };
    check("portrait", home::NOTHING);
    check("portrait, the computer's setup", home::COMPUTER);
    drive::size = float2 { 600.0, 960.0 };
    check("portrait at 600 x 960", home::NOTHING);

    // After the way out, the app writes the game as at any loop's end: a game under way
    // comes back from that image in a new start.
    var g = gui::Gui {};
    gui::test_faces(g);
    drive::size = float2 { 1280.0, 800.0 };
    var sh = shell::new(rules::RUSSIAN);
    let p, ok = rules::parse_fen("W:Wc3,e3:Bd6,f6", rules::RUSSIAN);
    assert(ok);
    board::set(sh.game.b, p);
    drive::idle(sh, g, 0.0);
    drive::tap(sh, g, drive::middle(way_out(g)), 1.0);
    print("a game under way, the way out: quit ", sh.quit);
    let image = shell::save(sh);
    var next = shell::new(rules::INTERNATIONAL);
    print("the next start restores it: ", shell::restore(next, image), ", screen ", next.screen, ", ",
          rules::fen(next.game.b.pos), ", quit ", next.quit);

    // Without the way out (iOS) home declares one tile fewer, and a tap where it was
    // does nothing.
    var ios = shell::new(rules::RUSSIAN);
    drive::idle(ios, g, 0.0);
    let spot = way_out(g);
    let tiles = drive::tiles(g);
    home::closable = false;
    drive::idle(ios, g, 0.5);
    print("not closable: tiles ", drive::tiles(g), " of ", tiles);
    drive::tap(ios, g, drive::middle(spot), 1.0);
    print("  a tap where the way out was: quit ", ios.quit, ", screen ", ios.screen, ", setup ", ios.setup);
}
