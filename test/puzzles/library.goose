// The daily puzzles' libraries as built into the program (docs/architecture/puzzles.md,
// "Daily puzzles"), International's, Russian's, and Brazilian's: each reads, holds no
// more than the index can, is sorted by difficulty, and every puzzle in it reads from
// its line, with a theme its variant's set has, and every CHECKED-th puzzle (all of
// them: about 9 s for the three through TinyCC) passes the course's checks
// (puzzles::check), as tools/puzzles.goose checked each one when it found it.
import std;
import rules from "../../src/rules";
import puzzles from "../../src/puzzles";

let CHECKED = 1;

fn main() {
    var s = puzzles::Solver { moves: [], stack: [] };
    for v in [rules::INTERNATIONAL, rules::RUSSIAN, rules::BRAZILIAN] {
        let variant = v as u8;
        let ok = puzzles::load_library(variant);
        let lib .= puzzles::library;
        let text = puzzles::library_file(variant);
        var sorted = true;
        var unread = 0;
        var problems = 0;
        var checked = 0;
        var themes: i64[puzzles::THEMES] = [0; puzzles::THEMES];
        var pz = puzzles::Puzzle { id: 0, theme: 0, level: 1, goal: 0, count: 1, start: rules::start(variant), moves: 0, lines: [],
                                   told: false };
        for e, i in lib.list {
            if i > 0 && e.difficulty < lib.list[i - 1].difficulty { sorted = false; }
            themes[e.theme]++;
            guard puzzles::entry_of(text, lib, i, pz) && pz.start.variant == variant else {
                unread++;
                continue;
            }
            guard i % CHECKED == 0 else { continue; }
            var out:  u8[>..] = [];
            var ways: u8[>..] = [];
            let n = puzzles::check(s, pz, out, ways);
            problems += n;
            if n > 0 { print("  ", i, ": ", rules::fen(pz.start), out); }
            checked++;
        }
        var per: u8[>..] = [];
        for t in puzzles::THEMES { if themes[t] > 0 { format(per, " ", puzzles::THEME_NAMES[t], " ", themes[t]); } }
        let least = if lib.list.len > 0 { lib.list[0].difficulty } else { 0 };
        let most = if lib.list.len > 0 { lib.list[lib.list.len - 1].difficulty } else { 0 };
        print(rules::VARIANT_NAMES[variant], ": read ", ok, ", ", lib.list.len, " puzzles (at most ", puzzles::MAX_LIBRARY,
              "), sorted ", sorted, ", difficulty ", least, " to ", most, ", unread ", unread, ";", per, "; ", checked,
              " checked, ", problems, " problems");
    }
}
