// The screens (shell/), headless, driven through the pointer as the app drives them:
// the app opens at home with the board beside the menu; continue opens the game as it
// stands and home on the panel returns home with the game kept; puzzles do nothing until
// task 007; settings opens settings, with no board, and its back returns where it came
// from, home or the game. A friend and the computer open a setup in home's column whose
// choices are kept in the settings and whose play starts that game over the old one;
// against the computer playing white the board is turned, and home notes the level.
// Home and the setup lay out in landscape and portrait, the board clear of the column.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import game from "../../game";
import shell from "../../shell";
import strings from "../../strings";

let W = 1280.0;
let H = 800.0;

fn frame(sh: shell::Shell&, g: gui::Gui&, at: float2, down: bool, pressed: bool, released: bool, now: f64) {
    gui::begin(g, gui::Input { at: at, down: down, pressed: pressed, released: released }, 1.0, now);
    shell::frame(sh, g, W, H, now);
}

fn tap(sh: shell::Shell&, g: gui::Gui&, p: float2, now: f64) {
    frame(sh, g, p, true, true, false, now);
    frame(sh, g, p, false, false, true, now + 0.02);
    frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, now + 0.04);
}

// The center of the n-th tile or row the last frame declared. Home in landscape:
// continue, a friend, the computer, puzzles, settings. The game: home, settings, start
// over, take back. Settings: back first. A setup: back, the three draughts, against the
// computer the three levels and two colors, the three clocks, play.
fn tile(g: gui::Gui&, n: i64) -> float2 {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        if k == n { return float2 { q.rect.x + 0.5 * q.rect.z, q.rect.y + 0.5 * q.rect.w }; }
        k++;
    }
    assert(false);
    return float2 { 0.0, 0.0 };
}

fn screen(sh: shell::Shell&) -> const u8[:] {
    if sh.screen == shell::HOME { "home" } else if sh.screen == shell::GAME { "game" } else { "settings" }
}

fn show(sh: shell::Shell&, g: gui::Gui&, what: const u8[:]) {
    var glyphs = 0;
    for q in g.quads { if q.look.x == gui::TEXT { glyphs++; } }
    print(what, ": ", screen(sh), ", sharp ", sh.sharp, ", board at ", sh.layout.board, ", glyphs ", glyphs,
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
               ", turned ", sh.layout.flip);
}

fn main() {
    let v .= rules::VARIANTS[rules::RUSSIAN];
    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    var sh = shell::new(rules::RUSSIAN);
    let off = float2 { -1.0, -1.0 };
    frame(sh, g, off, false, false, false, 0.0);
    show(sh, g, "start");
    print("the wordmark's piece: ", sh.game.overlay.len, ", crowned ", sh.game.overlay[0].look.y,
          ", no ring ", sh.game.overlay[0].ring.y == 0.0);

    tap(sh, g, tile(g, 0), 1.0);            // continue
    show(sh, g, "continue");
    let c3 = board::center(sh.layout, v, board::bit_at(v, 2, 2));
    let d4 = board::center(sh.layout, v, board::bit_at(v, 3, 3));
    tap(sh, g, c3, 1.1);
    tap(sh, g, d4, 1.2);
    frame(sh, g, off, false, false, false, 2.0);
    tap(sh, g, tile(g, 0), 2.0);            // home
    show(sh, g, "home");
    tap(sh, g, tile(g, 3), 2.2);            // puzzles
    show(sh, g, "puzzles");
    // Settings, and an idle frame long after the tap: the new screen's first frame is
    // drawn, the next one isn't.
    let at = tile(g, 4);
    frame(sh, g, at, true, true, false, 2.3);
    frame(sh, g, at, false, false, true, 2.32);
    gui::begin(g, gui::Input { at: off, .. }, 1.0, 3.0);
    let first = shell::frame(sh, g, W, H, 3.0);
    gui::begin(g, gui::Input { at: off, .. }, 1.0, 3.1);
    print("settings: ", screen(sh), ", board ", sh.board, ", sharp ", sh.sharp, ", its first frame drawn ", first,
          ", the next ", shell::frame(sh, g, W, H, 3.1));
    tap(sh, g, tile(g, 0), 3.2);            // back
    print("back from settings: ", screen(sh));
    tap(sh, g, tile(g, 0), 3.3);            // continue
    tap(sh, g, tile(g, 1), 3.4);            // the game's settings
    print("settings from the game: ", screen(sh));
    tap(sh, g, tile(g, 0), 3.5);            // back
    show(sh, g, "back from settings");
    tap(sh, g, tile(g, 0), 3.6);            // home

    // A friend's setup: back, the three draughts, the clock, play. Russian and 5+3 are
    // kept in the settings; play starts that game over the one there was.
    tap(sh, g, tile(g, 1), 4.0);
    var tiles = 0;
    for q in g.quads { if q.look.x == gui::BUTTON { tiles++; } }
    var minis = 0;
    for q in g.quads { if q.look.x == gui::MINI { minis++; } }
    print("a friend's setup: ", screen(sh), ", tiles ", tiles, ", small boards ", minis, ", ", prefs(sh));
    tap(sh, g, tile(g, 3), 4.1);            // Russian
    tap(sh, g, tile(g, 5), 4.2);            // 5+3
    print("Russian, 5+3: changed ", sh.changed, ", ", prefs(sh));
    sh.changed = false;
    tap(sh, g, tile(g, 0), 4.3);            // back
    print("back: setup ", sh.setup, ", ", screen(sh));
    tap(sh, g, tile(g, 1), 4.4);            // a friend
    tap(sh, g, tile(g, 7), 4.5);            // play
    print("play: ", screen(sh), ", ", game_of(sh));

    // The computer's setup adds the level and the child's color. Black, hard, 10+5:
    // the computer plays white and the board is turned.
    tap(sh, g, tile(g, 0), 5.0);            // home
    tap(sh, g, tile(g, 2), 5.1);            // the computer
    tiles = 0;
    for q in g.quads { if q.look.x == gui::BUTTON { tiles++; } }
    print("the computer's setup: tiles ", tiles, ", pieces over the UI ", sh.game.overlay.len);
    tap(sh, g, tile(g, 6), 5.2);            // hard
    tap(sh, g, tile(g, 8), 5.3);            // black
    tap(sh, g, tile(g, 11), 5.4);           // 10+5
    tap(sh, g, tile(g, 12), 5.5);           // play
    print("play: ", screen(sh), ", ", game_of(sh), "; ", prefs(sh));
    tap(sh, g, tile(g, 0), 6.0);            // home
    var note = 0;
    for q in g.quads { if q.look.x == gui::TEXT { note++; } }
    print("home: the computer's row notes hard; glyphs ", note, ", turned ", sh.layout.flip);

    // Home in portrait: the board above the sheet; the setup too.
    sh.screen = shell::HOME;
    gui::begin(g, gui::Input {}, 1.0, 7.0);
    shell::frame(sh, g, H, W, 7.0);
    var sheet = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads { if q.look.x == gui::GLASS { sheet = q.rect; } }
    print("portrait: board ", sh.layout.board, ", sheet from ", sheet.y, ", clear ",
          sh.layout.board.y + sh.layout.board.z < sheet.y);
    sh.setup = home::COMPUTER;
    gui::begin(g, gui::Input {}, 1.0, 7.1);
    shell::frame(sh, g, H, W, 7.1);
    for q in g.quads { if q.look.x == gui::GLASS { sheet = q.rect; } }
    print("portrait setup: board ", sh.layout.board, ", sheet from ", sheet.y, ", clear ",
          sh.layout.board.y + sh.layout.board.z < sheet.y);
}
