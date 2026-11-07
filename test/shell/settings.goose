// Settings (shell/settings.goose), headless: the file they are kept in reads back what
// was written, and a file that lacks a key or says something unknown leaves the default;
// on the screen a tap applies at once and marks the settings changed for the app to
// write: a season, move hints (which the game's board takes), the language; the 3D
// board does nothing until task 015. A new game's setup is kept there too: the draughts,
// the level, the child's color, and the clock.
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

// The center of the n-th tile the last frame declared. Settings: back; by the date and
// the four seasons; 2D, 3D; mistakes only, all moves; the languages.
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

fn show(sh: shell::Shell&, what: const u8[:]) {
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    for i in out.len { if out[i] == '\n' { out[i] = ';'; } }
    print(what, ": ", out, " changed ", sh.changed, ", board hints moves ", sh.game.b.hints == board::MOVES);
    sh.changed = false;
}

fn main() {
    var out: u8[>..] = [];
    settings::write(settings::Settings {}, out);
    print("defaults:\n", out);
    let s = settings::parse("season = winter\nhints = moves\nlanguage = et\nboard = 3d\ndraughts = brazilian\nlevel = easy\ncolor = black\nclock = 10+5\n");
    out.clear();
    settings::write(s, out);
    print("read back:\n", out);
    let odd = settings::parse("season = monsoon\nhints\nlanguage = xx\n  board =  2d  \ndraughts = english\nlevel = 4\ncolor = red\nclock = 3+2\n");
    out.clear();
    settings::write(odd, out);
    print("unknown values and a line without one:\n", out);

    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    var sh = shell::new(rules::RUSSIAN);
    sh.screen = shell::SETTINGS;
    frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 0.0);
    tap(sh, g, tile(g, 4), 1.0);            // summer
    show(sh, "summer");
    tap(sh, g, tile(g, 7), 1.1);            // 3D
    show(sh, "3D");
    tap(sh, g, tile(g, 9), 1.2);            // all moves
    show(sh, "all moves");
    tap(sh, g, tile(g, 11), 1.3);           // Eesti
    show(sh, "Eesti");
    tap(sh, g, tile(g, 1), 1.4);            // by the date
    show(sh, "by the date");
}
