// The screens (shell/), headless, driven through the pointer as the app drives them:
// the app opens at home with the board beside the menu; continue opens the game as it
// stands and home on the panel returns home with the game kept; puzzles opens the
// puzzles to pick from, its back home (test/shell/puzzles.goose has the rest), and home
// notes the stars won of those there are; settings opens settings, with their own board beside them, and its back
// returns where it came from, home or the game. A friend and the computer open a setup in home's column whose
// choices are kept in the settings and whose play starts that game over the old one;
// against the computer playing white the board is turned, the game takes the skill kept
// for its level and the number of games against the computer so far, which goes up, and
// home notes the level.
// Home and the setup lay out in landscape and portrait, the board clear of the column.
// The setup's draughts tiles are thirds of their row in portrait; in landscape, where a
// third is too narrow for "International" in the body face, each takes its name's width
// and a share of the rest. A tap that switches between home and the game or settings
// starts a transition, so the next tap waits until it is over
// (test/shell/transition.goose, test/shell/game_transition.goose).
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

let W = 1280.0;
let H = 800.0;

// A setup's three draughts tiles' widths, rounded, and whether the first's name has its
// face's room (gui::pick).
fn draughts_widths(g: gui::Gui&) -> u8[>..] {
    let name = gui::text_width(g, gui::BODY, strings::get(strings::VARIANT_INTERNATIONAL));
    return str(round(drive::rect(g, 1).z), " ", round(drive::rect(g, 2).z), " ", round(drive::rect(g, 3).z),
               ", the first's name in the body face ", name <= drive::rect(g, 1).z - 8.0);
}

fn screen(sh: shell::Shell&) -> const u8[:] {
    if sh.screen == shell::HOME { "home" } else if sh.screen == shell::GAME { "game" }
    else if sh.screen == shell::PICKER { "puzzles" } else { "settings" }
}

fn show(sh: shell::Shell&, g: gui::Gui&, what: const u8[:]) {
    var glyphs = 0;
    for q in g.quads { if q.look.x == gui::TEXT { glyphs++; } }
    print(what, ": ", screen(sh), ", sharp ", sh.blur == 0.0, ", board at ", sh.layout.board, ", glyphs ", glyphs,
          ", ", rules::fen(sh.game.b.pos), ", history ", sh.game.b.history.len);
}

fn prefs(sh: shell::Shell&) -> u8[>..] {
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    for i in out.len { if out[i] == '\n' { out[i] = ';'; } }
    return out;
}

fn game_of(sh: shell::Shell&) -> u8[>..] {
    let gm .= sh.game;
    return str(rules::VARIANTS[gm.b.variant].size, "x", rules::VARIANTS[gm.b.variant].size, " ",
               rules::fen(gm.b.pos), ", clock ", gm.clock.kind, ", computer ", gm.computer, ", level ", gm.level,
               ", skill ", gm.skill, ", number ", gm.number, ", turned ", sh.layout.flip);
}

// A tap that switches screens, then a frame once the transition it starts is over.
fn switch(sh: shell::Shell&, g: gui::Gui&, p: float2, now: f64) {
    drive::tap(sh, g, p, now);
    drive::idle(sh, g, now + 0.4);
}

fn main() {
    let v .= rules::VARIANTS[rules::RUSSIAN];
    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    puzzles::load();
    var sh = shell::new(rules::RUSSIAN);
    let off = float2 { -1.0, -1.0 };
    drive::frame(sh, g, off, false, false, false, 0.0);
    show(sh, g, "start");
    print("the wordmark's piece: ", sh.over.len, ", crowned ", sh.over[0].look.y,
          ", no ring ", sh.over[0].ring.y == 0.0);

    switch(sh, g, drive::tile(g, 0), 1.0);                // continue
    show(sh, g, "continue");
    let c3 = board::center(sh.layout, v, rules::bit_at(v, 2, 2));
    let d4 = board::center(sh.layout, v, rules::bit_at(v, 3, 3));
    drive::tap(sh, g, c3, 1.5);
    drive::tap(sh, g, d4, 1.6);
    drive::frame(sh, g, off, false, false, false, 2.0);
    switch(sh, g, drive::tile(g, 0), 2.0);                // home
    show(sh, g, "home");
    switch(sh, g, drive::tile(g, 3), 2.5);                // puzzles
    show(sh, g, "puzzles");
    switch(sh, g, drive::tile(g, 0), 3.0);                // back
    show(sh, g, "back from the puzzles");
    // Settings, and an idle frame long after the tap: the new screen's first frame is
    // drawn, the next one isn't.
    let at = drive::tile(g, 4);
    drive::frame(sh, g, at, true, true, false, 3.5);
    drive::frame(sh, g, at, false, false, true, 3.52);
    gui::begin(g, gui::Input { at: off, .. }, 1.0, 4.0);
    let first = shell::frame(sh, g, W, H, 4.0);
    gui::begin(g, gui::Input { at: off, .. }, 1.0, 4.1);
    print("settings: ", screen(sh), ", board at ", sh.layout.board, ", sharp ", sh.blur == 0.0, ", its first frame drawn ", first,
          ", the next ", shell::frame(sh, g, W, H, 4.1));
    switch(sh, g, drive::tile(g, 0), 4.2);                // back
    print("back from settings: ", screen(sh));
    switch(sh, g, drive::tile(g, 0), 4.7);                // continue
    drive::tap(sh, g, drive::tile(g, 1), 5.2);            // the game's settings
    print("settings from the game: ", screen(sh));
    drive::tap(sh, g, drive::tile(g, 0), 5.3);            // back
    show(sh, g, "back from settings");
    switch(sh, g, drive::tile(g, 0), 5.4);                // home

    // A friend's setup: back, the three draughts, the clock, play. Russian and 5+3 are
    // kept in the settings; play starts that game over the one there was.
    drive::tap(sh, g, drive::tile(g, 1), 6.0);
    var tiles = 0;
    for q in g.quads { if q.look.x == gui::BUTTON { tiles++; } }
    var minis = 0;
    for q in g.quads { if q.look.x == gui::MINI { minis++; } }
    print("a friend's setup: ", screen(sh), ", tiles ", tiles, ", small boards ", minis, ", ", prefs(sh));
    drive::tap(sh, g, drive::tile(g, 3), 6.1);            // Russian
    drive::tap(sh, g, drive::tile(g, 5), 6.2);            // 5+3
    print("Russian, 5+3: changed ", sh.changed, ", ", prefs(sh));
    sh.changed = false;
    drive::tap(sh, g, drive::tile(g, 0), 6.3);            // back
    print("back: setup ", sh.setup, ", ", screen(sh));
    drive::tap(sh, g, drive::tile(g, 1), 6.4);            // a friend
    switch(sh, g, drive::tile(g, 7), 6.5);                // play
    print("play: ", screen(sh), ", ", game_of(sh));

    // The computer's setup adds the level and the child's color. Black, hard, 10+5:
    // the computer plays white and the board is turned.
    switch(sh, g, drive::tile(g, 0), 7.0);                // home
    drive::tap(sh, g, drive::tile(g, 2), 7.5);            // the computer
    tiles = 0;
    for q in g.quads { if q.look.x == gui::BUTTON { tiles++; } }
    print("the computer's setup: tiles ", tiles, ", pieces over the UI ", sh.over.len);
    print("draughts tiles: ", draughts_widths(g));
    drive::tap(sh, g, drive::tile(g, 6), 7.6);            // hard
    drive::tap(sh, g, drive::tile(g, 8), 7.7);            // black
    drive::tap(sh, g, drive::tile(g, 11), 7.8);           // 10+5
    switch(sh, g, drive::tile(g, 12), 7.9);               // play
    print("play: ", screen(sh), ", ", game_of(sh), "; ", prefs(sh));
    switch(sh, g, drive::tile(g, 0), 8.4);                // home
    var note = 0;
    for q in g.quads { if q.look.x == gui::TEXT { note++; } }
    print("home: the computer's row notes hard; glyphs ", note, ", turned ", sh.layout.flip);

    // Home in portrait: the board above the sheet; the setup too.
    sh.screen = shell::HOME;
    gui::begin(g, gui::Input {}, 1.0, 9.0);
    shell::frame(sh, g, H, W, 9.0);
    // The sheet is the first glass; the way out's is the last.
    var sheet = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads { if q.look.x == gui::GLASS && sheet.z == 0.0 { sheet = q.rect; } }
    print("portrait: board ", sh.layout.board, ", sheet from ", sheet.y, ", clear ",
          sh.layout.board.y + sh.layout.board.z < sheet.y);
    sh.setup = home::COMPUTER;
    gui::begin(g, gui::Input {}, 1.0, 9.1);
    shell::frame(sh, g, H, W, 9.1);
    sheet.z = 0.0;
    for q in g.quads { if q.look.x == gui::GLASS && sheet.z == 0.0 { sheet = q.rect; } }
    print("portrait setup: board ", sh.layout.board, ", sheet from ", sheet.y, ", clear ",
          sh.layout.board.y + sh.layout.board.z < sheet.y);
    print("draughts tiles: ", draughts_widths(g));
}
