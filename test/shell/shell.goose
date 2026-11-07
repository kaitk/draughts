// The screens (shell/), headless, driven through the pointer as the app drives them:
// the app opens at home with the board beside the menu; continue opens the game as it
// stands and back on the panel returns home with the game kept; a friend starts a new
// game; the computer and puzzles do nothing until tasks 006 and 007; settings opens
// settings, with no board, and its back returns home; home lays out the same in
// landscape and portrait, the board clear of the menu.
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
// continue, a friend, the computer, puzzles, settings. The game: undo, hint, restart,
// back.
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
    tap(sh, g, tile(g, 3), 2.0);            // back
    show(sh, g, "back");
    tap(sh, g, tile(g, 2), 2.1);            // the computer
    tap(sh, g, tile(g, 3), 2.2);            // puzzles
    show(sh, g, "the computer, puzzles");
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
    tap(sh, g, tile(g, 0), 2.35);           // back
    tap(sh, g, tile(g, 0), 2.4);            // continue
    show(sh, g, "continue");
    tap(sh, g, tile(g, 3), 2.5);
    tap(sh, g, tile(g, 1), 2.6);            // a friend
    show(sh, g, "a friend");

    // Home in portrait: the board above the sheet.
    sh.screen = shell::HOME;
    gui::begin(g, gui::Input {}, 1.0, 3.0);
    shell::frame(sh, g, H, W, 3.0);
    var sheet = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads { if q.look.x == gui::GLASS { sheet = q.rect; } }
    print("portrait: board ", sh.layout.board, ", sheet from ", sheet.y, ", clear ",
          sh.layout.board.y + sh.layout.board.z < sheet.y);
}
