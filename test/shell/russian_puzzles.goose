// The puzzles of a Russian player (shell/shell.goose, sync_puzzles; puzzles::set_of):
// headless, driven through the pointer. The app starts with International's set; a
// player whose draughts are Russian gets Russian's on home, where every way to the
// puzzles starts. Its library has the four themes Russian's set has, no King shots,
// Learn open and the other three shut. Learn's ninth puzzle, a man crowned mid-capture,
// is made by hand stop by stop: h4 takes g5 to f6, e7 to d8, where it is crowned, and
// goes on as a king over c7 to b6, which solves it. The stars are kept under
// `stars.russian`, and home counts them over Russian's set. Back to International on
// home, the library is International's again, its stars kept apart. A Brazilian player
// has Brazilian's own set; a variant with none (English, not offered) is shown
// International's.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import game from "../../src/game";
import strings from "../../strings";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

let SCREENS = ["home", "game", "settings", "picker", "puzzle"];
let STATES = ["playing", "answer", "back", "solved", "show", "shown", "unshow"];

fn show(sh: shell::Shell&, what: const u8[:]) {
    let pl .= sh.puzzle;
    var text: u8[>..] = [];
    format(text, what, ": ", SCREENS[sh.screen], ", the set ", rules::VARIANT_NAMES[puzzles::loaded], " of ",
           puzzles::all.list.len);
    if sh.screen == shell::PICKER {
        format(text, ", ", if sh.theme >= 0 { puzzles::THEME_NAMES[sh.theme] } else { "library" });
    }
    if sh.screen == shell::PUZZLE {
        let v .= rules::VARIANTS[pl.b.variant];
        format(text, ", puzzle ", puzzle::current(pl).id, ", ", rules::fen(pl.b.pos), ", ", STATES[pl.state], ", stars ",
               puzzle::stars(pl), ", waits on ", drive::name(v, board::waiting(pl.b)));
    }
    print(text);
}

// The icons of a kind the last frame declared.
fn icons(g: gui::Gui&, icon: i64) -> i64 {
    var n = 0;
    for q in g.quads { if q.look.x == gui::ICON && q.look.z == icon { n++; } }
    return n;
}

// The library as the last frame declared it: its tiles (back and a row per theme), locks,
// and each theme's mark.
fn library(g: gui::Gui&) -> u8[>..] {
    return str("tiles ", drive::tiles(g), ", locks ", icons(g, gui::LOCK), ", marks ", icons(g, gui::BOOK), " ",
               icons(g, gui::JUMPS), " ", icons(g, gui::CROWN), " ", icons(g, gui::TARGET), " ", icons(g, gui::KING));
}

// The stars the player's file keeps.
fn kept(sh: shell::Shell&) -> u8[>..] {
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    var lines: u8[>..] = [];
    for line in split(out, '\n') {
        guard find(line, "stars") == 0 else { continue; }
        if lines.len > 0 { lines.append("; "); }
        lines.append(line);
    }
    return lines;
}

fn tap_square(sh: shell::Shell&, g: gui::Gui&, name: const u8[:], now: f64) {
    drive::tap(sh, g, drive::at(sh.out.layout, name), now);
}

fn main() {
    strings::use(strings::EN);
    print("loaded: ", puzzles::load(), ", the set ", rules::VARIANT_NAMES[puzzles::loaded], " of ",
          puzzles::all.list.len);
    print("a Brazilian player's set: ", rules::VARIANT_NAMES[puzzles::set_of(rules::BRAZILIAN)],
          ", a Russian's: ", rules::VARIANT_NAMES[puzzles::set_of(rules::RUSSIAN)], ", an English one's: ",
          rules::VARIANT_NAMES[puzzles::set_of(rules::ENGLISH)]);
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::RUSSIAN);
    sh.prefs.variant = rules::RUSSIAN;
    drive::idle(sh, g, 0.0);
    show(sh, "home");
    drive::tap(sh, g, drive::tile(g, 2), 0.1);              // puzzles
    drive::idle(sh, g, 0.5);
    show(sh, "puzzles");
    print("  ", library(g));
    drive::tap(sh, g, drive::tile(g, drive::LEARN_ROW), 0.6);   // learn
    show(sh, "learn tapped");
    print("  tiles ", drive::tiles(g));

    // Learn's ninth: h4 takes three, crowned on d8 on the way.
    drive::tap(sh, g, drive::tile(g, 9), 1.0);
    drive::idle(sh, g, 1.4);
    show(sh, "the ninth");
    tap_square(sh, g, "h4", 1.6);
    tap_square(sh, g, "f6", 1.7);
    show(sh, "h4, f6");
    tap_square(sh, g, "d8", 1.8);
    show(sh, "then d8, crowned");
    tap_square(sh, g, "b6", 1.9);
    drive::idle(sh, g, 3.0);
    show(sh, "then b6");
    print("  kept: ", kept(sh));

    // Home counts Russian's stars over Russian's set; International's set comes back
    // with International, its stars apart.
    shell::back(sh, 4.0);
    shell::back(sh, 4.1);
    shell::back(sh, 4.2);
    drive::idle(sh, g, 4.5);
    show(sh, "home again");
    let won, all = picker::totals(sh.prefs.stars[puzzles::loaded]);
    print("  home's count: ", won, " / ", all);
    sh.prefs.variant = rules::INTERNATIONAL;
    drive::idle(sh, g, 5.0);
    show(sh, "draughts international");
    let won_i, all_i = picker::totals(sh.prefs.stars[puzzles::loaded]);
    print("  home's count: ", won_i, " / ", all_i);
    drive::tap(sh, g, drive::tile(g, 2), 5.1);
    drive::idle(sh, g, 5.5);
    show(sh, "puzzles");
    var themes = 0;
    for t in puzzles::THEMES { if puzzles::theme_count(puzzles::all, t) > 0 { themes++; } }
    print("  back and a row per theme of the set: ", drive::tiles(g) == themes + drive::LEARN_ROW, ", king shots' mark ",
          icons(g, gui::KING));
    print("  kept: ", kept(sh));
}
