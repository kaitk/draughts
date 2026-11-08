// Settings (shell/settings.goose), headless: the file they are kept in reads back what
// was written, and a file that lacks a key or says something unknown leaves the default.
// On the regrouped screen a tap applies at once and marks the settings changed for the
// app to write: the language in the title row; the draughts a new game starts on, move
// hints (which the game's board takes), a season, and the kings (which the game's board
// draws too); the tutorial and the 3D board do nothing until they exist. Each choice
// restages the board beside them: its size, its kings, and what the move hints show on
// a fixed position, where white must capture with the man on d4 or the king on h6.
// With mistakes only, a wrong move's ring flashes and both capturing pieces pulse, then
// both stay lit and still, so nothing animates after. In landscape the board is right of
// the choices; in portrait above them.
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

// The tiles in the order the screen declares them.
let BACK = 0;
let ENGLISH = 1;
let EESTI = 2;
let INTERNATIONAL = 3;
let BRAZILIAN = 4;
let RUSSIAN = 5;
let MISTAKES = 6;
let MOVES = 7;
let TUTORIAL = 8;
let BY_DATE = 9;
let SUMMER = 12;
let RAISED = 15;
let AUTO = 16;
let STACK = 18;
let TILES = 19;

fn show(sh: shell::Shell&, what: const u8[:]) {
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    for i in out.len { if out[i] == '\n' { out[i] = ';'; } }
    print(what, ": ", out, " changed ", sh.changed, ", game's board hints moves ", sh.game.b.hints == board::MOVES,
          ", kings ", sh.game.b.king_look);
    sh.changed = false;
}

// The preview at `now`: its size, what is selected and marked, which pieces have a
// must-capture ring (pulsing or still) and how its kings are drawn, and whether it is
// still animating.
fn preview(sh: shell::Shell&, now: f64) {
    let b .= sh.preview;
    board::fill(b, sh.layout, now);
    let v .= rules::VARIANTS[b.variant];
    var text: u8[>..] = [];
    format(text, "  preview ", v.size, "x", v.size, ", ", rules::fen(b.pos));
    if b.selected >= 0 { format(text, ", selected ", v.x_of[b.selected], ",", v.y_of[b.selected]); }
    var targets = 0;
    var via = 0;
    for i in 4 {
        targets += popcount(b.marks.target[i]);
        via += popcount(b.marks.via[i]);
    }
    format(text, ", targets ", targets, ", stops ", via);
    if b.flash.x >= 0.0 { format(text, ", wrong ring at ", b.flash.x, " flash ", b.flash.y); }
    var pulsing = 0;
    var still = 0;
    var king: f32 = 0.0;
    for p in b.pieces {
        if p.ring.x == 1.0 { pulsing++; }
        if p.ring.x == 2.0 { still++; }
        king = max(king, p.look.y);
    }
    format(text, ", rings pulsing ", pulsing, " still ", still, ", kings drawn ", king, ", animating ",
           board::animating(b, now));
    print(text);
}

fn main() {
    var out: u8[>..] = [];
    settings::write(settings::Settings {}, out);
    print("defaults:\n", out);
    let s = settings::parse("season = winter\nhints = moves\nkings = stack\nlanguage = et\nboard = 3d\ndraughts = brazilian\nlevel = easy\ncolor = black\nclock = 10+5\n");
    out.clear();
    settings::write(s, out);
    print("read back:\n", out);
    var twice: u8[>..] = [];
    settings::write(settings::parse(out), twice);
    print("written again the same: ", twice == out);
    let again = settings::parse("kings = crown\n");
    print("kings crown reads back: ", again.kings == board::CROWN, ", draws ", settings::king_look(again),
          "; auto draws ", settings::king_look(settings::Settings {}));
    let odd = settings::parse("season = monsoon\nhints\nkings = tower\nlanguage = xx\n  board =  2d  \ndraughts = english\nlevel = 4\ncolor = red\nclock = 3+2\n");
    out.clear();
    settings::write(odd, out);
    print("unknown values and a line without one:\n", out);

    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    var sh = shell::new(rules::RUSSIAN);
    sh.screen = shell::SETTINGS;
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 0.0);
    print("tiles ", drive::tiles(g), " of ", TILES, ", the kings' tiles' pieces ", sh.over.len, ": ",
          sh.over[0].look.y, " and ", sh.over[1].look.y);
    // The board is right of the choices: every tile and the groups end left of it.
    var right: f32 = 0.0;
    for q in g.quads { right = max(right, q.rect.x + q.rect.z); }
    print("landscape: board at ", sh.layout.board, ", choices end at ", right, ", clear ",
          right < sh.layout.board.x);
    print("opened, defaults:");
    preview(sh, 0.0);
    preview(sh, 1.0);
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 2.0);
    print("after the flash:");
    preview(sh, 2.0);
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 3.0);
    print("after the pulse:");
    preview(sh, 3.0);

    drive::tap(sh, g, drive::tile(g, SUMMER), 4.0);
    show(sh, "summer");
    drive::tap(sh, g, drive::tile(g, RAISED), 4.1);
    show(sh, "3D");
    drive::tap(sh, g, drive::tile(g, TUTORIAL), 4.2);
    show(sh, "the tutorial");
    drive::tap(sh, g, drive::tile(g, MOVES), 4.3);
    show(sh, "all moves");
    preview(sh, 4.4);
    drive::tap(sh, g, drive::tile(g, RUSSIAN), 4.5);
    show(sh, "Russian");
    preview(sh, 4.6);
    drive::tap(sh, g, drive::tile(g, STACK), 4.7);
    show(sh, "stack");
    preview(sh, 4.8);
    drive::tap(sh, g, drive::tile(g, MISTAKES), 4.9);
    show(sh, "mistakes only");
    preview(sh, 5.0);
    drive::tap(sh, g, drive::tile(g, BRAZILIAN), 9.0);
    show(sh, "Brazilian");
    drive::tap(sh, g, drive::tile(g, AUTO), 9.1);
    show(sh, "auto");
    drive::tap(sh, g, drive::tile(g, INTERNATIONAL), 9.2);
    show(sh, "International");
    drive::tap(sh, g, drive::tile(g, EESTI), 9.3);
    show(sh, "Eesti");
    drive::tap(sh, g, drive::tile(g, BY_DATE), 9.4);
    show(sh, "by the date");
    drive::tap(sh, g, drive::tile(g, ENGLISH), 9.5);
    show(sh, "English");

    // Portrait: the board on top, the groups side by side under it.
    drive::size = float2 { 800.0, 1280.0 };
    drive::frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, 10.0);
    let first = drive::rect(g, INTERNATIONAL);
    let look = drive::rect(g, BY_DATE);
    print("portrait: board at ", sh.layout.board, ", the groups from ", first.y, ", clear ",
          sh.layout.board.y + sh.layout.board.z < first.y, ", look beside game ", look.x > first.x + first.z,
          ", tiles ", drive::tiles(g));
    drive::tap(sh, g, drive::tile(g, STACK), 10.1);
    show(sh, "portrait stack");
    drive::tap(sh, g, drive::tile(g, BACK), 10.2);
    print("back: ", sh.screen == shell::HOME);
}
