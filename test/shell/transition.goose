// Home to settings and back through their transition (task 022), headless: settings
// from home starts it, and while it runs the shell asks for frames, home fading out
// under settings, both drifting the way the board goes, which eases from home's place
// to the preview's: right in landscape; in portrait, where settings' title row comes
// above it, down a little as it shrinks. The preview's pieces fade in over the game's.
// The frame of the tap still shows home as it stands. The frame after it ends is drawn
// at rest, as settings at rest are; the preview's wrong move flashes then, and once it
// and the pulse are over nothing more is drawn. A tap during it lands on settings: their
// back turns it round where it is, the board going back from where it was, and home's
// rows, still showing faintly, take no tap.
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

let OFF = float2 { -1.0, -1.0 };

fn screen(sh: shell::Shell&) -> const u8[:] {
    if sh.screen == shell::HOME { "home" } else if sh.screen == shell::GAME { "game" } else { "settings" }
}

fn rect(r: float4) -> u8[>..] { str(round(r.x), ",", round(r.y), " ", round(r.z)) }

// One idle frame at `now`: what the shell says of it and what it declared.
fn look(sh: shell::Shell&, g: gui::Gui&, now: f64, what: const u8[:]) {
    let drawn = drive::idle(sh, g, now);
    var faded = 0;
    var gone = 0;
    for q in g.quads {
        if q.extra.w > 0.0 { faded++; }
        if q.extra.w > 0.5 { gone++; }
    }
    let b .= shell::fill(sh, now);
    var faint = 0;
    for p in b.pieces { if p.look.w < 1.0 { faint++; } }
    print(what, " ", now, ": ", screen(sh), ", board ", rect(sh.layout.board), " ", sh.layout.n, "x", sh.layout.n,
          ", mix ", round(100.0 * sh.mix), "%, quads ", g.quads.len, " faded ", faded, " mostly ", gone, ", pieces ",
          b.pieces.len, " faint ", faint, ", over the UI ", sh.over.len, ", drawn ", drawn, ", animating ",
          shell::animating(sh, g, now));
}

fn main() {
    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    puzzles::load();
    // A Russian game at home; settings' preview is International, the default.
    var sh = shell::new(rules::RUSSIAN);
    look(sh, g, 0.0, "home");
    let home_at = sh.layout.board;
    let settings_row = drive::tile(g, 4);
    let continue_row = drive::tile(g, 0);

    // Settings, tapped at 1.0 and released at 1.02: the transition runs from then.
    drive::frame(sh, g, settings_row, true, true, false, 1.0);
    let first = drive::frame(sh, g, settings_row, false, false, true, 1.02);
    print("tapped settings: ", screen(sh), ", from home ", sh.from == shell::HOME, ", drawn ", first, " with home's board ",
          sh.layout.board == home_at, " at ", round(100.0 * sh.mix), "%");
    var x = home_at.x;
    var right = true;
    for i in 1..5 {
        let t = 1.02 + 0.0625 * i;
        look(sh, g, t, "  ");
        if sh.layout.board.x < x { right = false; }
        x = sh.layout.board.x;
    }
    look(sh, g, 1.3, "ended");
    look(sh, g, 1.4, "  ");
    look(sh, g, 5.3, "after the flash and the pulse");
    look(sh, g, 5.4, "idle");
    print("the board went right all the way ", right);
    let settings_at = sh.layout.board;
    let back_at = drive::tile(g, 0);
    // At rest it is where settings opened straight put it.
    var direct = shell::new(rules::RUSSIAN);
    direct.screen = shell::SETTINGS;
    var h = gui::Gui {};
    gui::test_faces(h);
    drive::idle(direct, h, 0.0);
    print("settings at rest as opened straight: board ", direct.layout.board == settings_at, ", quads ",
          h.quads.len == g.quads.len);

    // Back to home, and once more to settings; halfway, a tap where home's continue was
    // lands on settings, not home.
    drive::tap(sh, g, back_at, 6.0);
    drive::idle(sh, g, 6.5);
    print("back: ", screen(sh), ", board ", sh.layout.board == home_at, ", animating ", shell::animating(sh, g, 6.5));
    drive::frame(sh, g, settings_row, true, true, false, 7.0);
    drive::frame(sh, g, settings_row, false, false, true, 7.02);
    look(sh, g, 7.1, "again");
    drive::frame(sh, g, continue_row, true, true, false, 7.12);
    drive::frame(sh, g, continue_row, false, false, true, 7.14);
    print("a tap where home's continue was: ", screen(sh), ", a setting changed ", sh.changed);
    sh.changed = false;

    // Settings' back during the transition turns it round: the board goes back from where
    // it is, and takes as long as it came.
    look(sh, g, 7.16, "before back");
    drive::frame(sh, g, back_at, true, true, false, 7.17);
    let before = sh.layout.board;
    drive::frame(sh, g, back_at, false, false, true, 7.18);
    let turned = sh.layout.board;
    drive::idle(sh, g, 7.19);
    let after = sh.layout.board;
    print("back during it: ", screen(sh), ", from settings ", sh.from == shell::SETTINGS, ", the board on the frames ",
          rect(before), ", ", rect(turned), ", ", rect(after));
    look(sh, g, 7.24, "  ");
    look(sh, g, 7.32, "  ");
    look(sh, g, 7.36, "ended");
    look(sh, g, 7.5, "idle");
    print("at home's place ", sh.layout.board == home_at);

    // Portrait: settings' gear beside the wordmark; the board shrinks and goes down a
    // little, under settings' title row.
    drive::size = float2 { 800.0, 1280.0 };
    g = gui::Gui {};
    gui::test_faces(g);
    var p = shell::new(rules::INTERNATIONAL);
    look(p, g, 0.0, "portrait home");
    let gear = drive::tile(g, 0);
    let low = p.layout.board.y;
    drive::tap(p, g, gear, 1.0);
    var down = true;
    var y = low;
    for i in 1..5 {
        let t = 1.02 + 0.0625 * i;
        look(p, g, t, "  ");
        if p.layout.board.y < y { down = false; }
        y = p.layout.board.y;
    }
    look(p, g, 1.3, "ended");
    look(p, g, 5.3, "after the flash and the pulse");
    look(p, g, 5.4, "idle");
    print("the board went down all the way ", down, ", from ", round(low), " to ", round(p.layout.board.y));
}
