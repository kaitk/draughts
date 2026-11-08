// The puzzles (shell/picker.goose, shell/puzzle.goose), headless, driven through the
// pointer as the app drives them. Home's puzzles opens the picker: three tiers of ten,
// the first open with its first puzzle lit, the others locked. A puzzle opens on a tap.
// A tap that isn't a move is a miss: a star goes out and "try again" shows for two
// seconds, after which nothing animates. Solved, the stars won are kept in the settings
// (the most a puzzle has won), next lights and opens the next puzzle. A wrong move plays,
// then slides back by itself with the red ring and a ghost on its square; after two
// misses the piece to move glows. In a shot, a right move is answered by the line's
// reply after a pause, and the capture after it solves the puzzle. Half a tier solved
// opens the next. Settings opened from a puzzle go back to it as it was; a puzzle isn't
// saved with the game, which brings back the picker instead. In portrait the picker
// shows each tier as two rows of five, the tiles at least 88 dp.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import game from "../../game";
import strings from "../../strings";
import ai from "../../ai";
import shell from "../../shell";
import puzzles from "../../puzzles";
import drive from "../drive";

let SCREENS = ["home", "game", "settings", "picker", "puzzle"];
let STATES = ["playing", "answer", "back", "solved"];

fn show(sh: shell::Shell&, what: const u8[:]) {
    let pl .= sh.puzzle;
    let v .= rules::VARIANTS[pl.b.variant];
    var text: u8[>..] = [];
    format(text, what, ": ", SCREENS[sh.screen]);
    if sh.screen == shell::PUZZLE {
        format(text, " ", puzzle::current(pl).id, ", ", rules::fen(pl.b.pos), ", ", STATES[pl.state], ", misses ",
               pl.misses, ", stars ", puzzle::stars(pl), ", moves left ", pl.left);
        if pl.b.glow >= 0 { format(text, ", glow on ", drive::name(v, pl.b.glow)); }
        if pl.b.wrong >= 0 { format(text, ", red ring on ", drive::name(v, pl.b.wrong), ", ghost ", pl.b.ghost); }
    }
    print(text);
}

fn kept(sh: shell::Shell&) -> u8[>..] {
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    let at = find(out, "stars");
    let changed = sh.changed;
    sh.changed = false;
    return str(if at >= 0 { trim(out[at..]) } else { "no stars" }, ", changed ", changed);
}

// The icons of a kind the last frame declared, and the tiles lit.
fn icons(g: gui::Gui&, icon: i64) -> i64 {
    var n = 0;
    for q in g.quads { if q.look.x == gui::ICON && q.look.z == icon { n++; } }
    return n;
}
fn lit(g: gui::Gui&) -> i64 {
    var n = 0;
    for q in g.quads { if q.look.x == gui::BUTTON && q.extra.y == gui::CHOSEN { n++; } }
    return n;
}

fn tap_square(sh: shell::Shell&, g: gui::Gui&, name: const u8[:], now: f64) {
    drive::tap(sh, g, drive::at(sh.layout, name), now);
}

fn main() {
    strings::use(strings::EN);
    print("loaded: ", puzzles::load(), ", ", puzzles::all.list.len, " puzzles");
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::INTERNATIONAL);
    drive::idle(sh, g, 0.0);
    drive::tap(sh, g, drive::tile(g, 3), 0.1);              // puzzles
    show(sh, "puzzles");
    print("  tiles ", drive::tiles(g), ", locks ", icons(g, gui::LOCK), ", lit ", lit(g), ", stars out ",
          icons(g, gui::STAR_OFF), ", marks ", icons(g, gui::TARGET), " ", icons(g, gui::CROWN), " ",
          icons(g, gui::SHIELD));

    // Puzzle 1: b2 can't move while d4 must capture, a miss; then d4 takes e5.
    // It opens through its transition, the board growing out of its tile.
    drive::tap(sh, g, drive::tile(g, 1), 0.5);
    drive::idle(sh, g, 0.9);
    show(sh, "the first puzzle");
    tap_square(sh, g, "b2", 1.1);
    show(sh, "b2 tapped");
    print("  try again ", icons(g, gui::UNDO) > 0, ", animating at 3.0 s ", shell::animating(sh, g, 3.0),
          ", at 3.2 s ", shell::animating(sh, g, 3.2));
    drive::idle(sh, g, 3.2);
    print("  after: try again ", icons(g, gui::UNDO) > 0);
    tap_square(sh, g, "d4", 4.0);
    tap_square(sh, g, "f6", 4.1);
    show(sh, "d4 takes e5");
    drive::idle(sh, g, 4.9);
    let popping = shell::animating(sh, g, 4.9);
    drive::idle(sh, g, 5.45);
    print("  kept: ", kept(sh), ", animating while the stars pop ", popping, ", after ", shell::animating(sh, g, 5.5));
    drive::idle(sh, g, 6.0);
    print("  next lit ", lit(g), ", stars ", icons(g, gui::STAR), " won ", icons(g, gui::STAR_OFF), " not");
    drive::tap(sh, g, drive::tile(g, 3), 6.1);              // next
    show(sh, "next");

    // Puzzle 7: c3 takes d4 into f6's reach, a wrong move; it slides back, twice.
    shell::play_puzzle(sh, 6);
    drive::idle(sh, g, 10.0);
    show(sh, "puzzle 7");
    tap_square(sh, g, "c3", 10.1);
    tap_square(sh, g, "e5", 10.2);
    show(sh, "c3 takes d4");
    drive::idle(sh, g, 10.7);
    drive::idle(sh, g, 11.0);
    show(sh, "  sliding back");
    drive::idle(sh, g, 12.5);
    show(sh, "  after");
    tap_square(sh, g, "c3", 13.0);
    tap_square(sh, g, "e5", 13.1);
    drive::idle(sh, g, 13.6);
    drive::idle(sh, g, 13.9);
    drive::idle(sh, g, 15.0);
    show(sh, "a second time");
    tap_square(sh, g, "e3", 15.1);
    tap_square(sh, g, "c5", 15.2);
    show(sh, "e3 takes d4");
    print("  kept: ", kept(sh));

    // Settings from the puzzle, and back to it as it was.
    drive::tap(sh, g, drive::tile(g, 1), 16.0);
    show(sh, "settings");
    drive::tap(sh, g, drive::tile(g, 0), 16.1);
    show(sh, "back");

    // Puzzle 21, a shot: f4-e5 gives a man, black takes it, and e3 takes three.
    shell::play_puzzle(sh, 20);
    drive::idle(sh, g, 20.0);
    tap_square(sh, g, "f4", 20.1);
    tap_square(sh, g, "e5", 20.2);
    show(sh, "f4-e5");
    drive::idle(sh, g, 20.5);
    drive::idle(sh, g, 20.9);
    show(sh, "  the reply, 0.5 s after it landed");
    drive::idle(sh, g, 21.5);
    tap_square(sh, g, "e3", 21.6);
    tap_square(sh, g, "c9", 21.7);
    show(sh, "e3 takes three");
    print("  kept: ", kept(sh));
    // Started over once solved, it is played afresh; its stars stay.
    drive::idle(sh, g, 23.0);
    drive::tap(sh, g, drive::tile(g, 2), 23.1);
    show(sh, "start over");

    // The stars read back from the file; half of tier 1 solved opens tier 2.
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    let back = settings::parse(out);
    let odd = settings::parse("stars = 1:3 2:9 99:1 x 4:0\n");
    print("read back: ", back.stars[1], " ", back.stars[7], " ", back.stars[21], "; odd ones ignored: ", odd.stars[1],
          " ", odd.stars[2], " ", odd.stars[4]);
    for id in [2, 3, 4] { sh.prefs.stars[id] = 3; }
    drive::tap(sh, g, drive::tile(g, 0), 30.0);             // the puzzles
    drive::idle(sh, g, 30.4);
    show(sh, "puzzles");
    print("  locks ", icons(g, gui::LOCK), ", lit ", lit(g), ", stars won ", icons(g, gui::STAR));

    // A puzzle isn't saved: the picker comes back.
    shell::play_puzzle(sh, 0);
    let image = shell::save(sh);
    var later = shell::new(rules::INTERNATIONAL);
    print("restored: ", shell::restore(later, image), ", ", SCREENS[later.screen]);

    // Portrait: the left panel above the board, the goal, stars, and next below it.
    drive::size = float2 { 800.0, 1280.0 };
    drive::idle(sh, g, 40.0);
    print("portrait: board ", sh.layout.board, ", next at ", drive::rect(g, 3));
    // The portrait picker: the title beside back, and each tier two rows of five tiles
    // of at least 88 dp.
    sh.screen = shell::PICKER;
    drive::idle(sh, g, 41.0);
    var glyphs = 0;
    for q in g.quads { if q.look.x == gui::TEXT { glyphs++; } }
    let first = drive::rect(g, 1);
    let sixth = drive::rect(g, 6);
    print("portrait picker: title glyphs ", glyphs, ", tiles ", drive::tiles(g), ", the first ", first, ", the sixth ",
          sixth, ", at least 88 dp ", first.z >= 88.0, ", the last tier ends at ", drive::rect(g, 30).y + first.w);
}
