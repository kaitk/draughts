// The daily puzzles' libraries as built into the program (docs/architecture/puzzles.md,
// "Daily puzzles"), International's, Russian's, and Brazilian's: each reads, holds no
// more than the index can, is sorted by difficulty, and every puzzle in it reads from
// its line, with a theme its variant's set has, and every CHECKED-th puzzle (all of
// them: about 9 s for the three through TinyCC) passes the course's checks
// (puzzles::check), as tools/puzzles.goose checked each one when it found it. Ids stay
// for good: the first library's puzzles, whose ids were their lines then and which
// players' files keep, are still found by them.
import std;
import rules from "../../src/rules";
import puzzles from "../../src/puzzles";

let CHECKED = 1;

// Puzzles of the first libraries (2026-11-14) by the id a player's file knows them by:
// the first, one in the middle, and the last line then.
struct Kept { variant: u8, id: i64, fen: const u8[:] }
let FIRST: Kept[] = [
    Kept { variant: rules::INTERNATIONAL, id: 0, fen: "B:W16,21,26,28,32,33,42:B15,20,24,25,29,30,34" },
    Kept { variant: rules::INTERNATIONAL, id: 777,
           fen: "B:W26,27,29,32,33,35,37,38,39,40,41,42,46,47,48:B1,2,3,4,5,6,7,8,9,10,11,12,14,18,19" },
    Kept { variant: rules::INTERNATIONAL, id: 3291, fen: "W:W22,27,32,38,40,41,42,43,44,47,48,K50:B1,7,9,10,11,14,23,24,25,29,30,33,35" },
    Kept { variant: rules::RUSSIAN, id: 0, fen: "B:Wa1,b2,b4,g5:Ba5,c5,d6,a7" },
    Kept { variant: rules::RUSSIAN, id: 777, fen: "W:Wc1,e1,g1,d2,f2,h4:Bf4,a7,e7,d8,f8,h8" },
    Kept { variant: rules::RUSSIAN, id: 2093, fen: "W:Wc1,e1,d2,h2,g3,d4,f4:Bb4,a5,b6,d6,f6,c7,d8" },
    Kept { variant: rules::BRAZILIAN, id: 0, fen: "B:Wd2,b4,d4,c5:Bh4,a5,g7,b8" },
    Kept { variant: rules::BRAZILIAN, id: 777, fen: "B:Wd2,a3,b4,d4:Be5,g5,f6,b8" },
    Kept { variant: rules::BRAZILIAN, id: 1862, fen: "W:Wf2,c3,e3,g3,d4,h4,c5:Ba5,a7,c7,e7,g7,f8,h8" },
];

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
        var highest = -1;
        var pz = puzzles::Puzzle { id: 0, theme: 0, level: 1, goal: 0, count: 1, start: rules::start(variant), moves: 0, lines: [],
                                   told: false };
        for e, i in lib.list {
            if i > 0 && e.difficulty < lib.list[i - 1].difficulty { sorted = false; }
            themes[e.theme]++;
            highest = max(highest, e.id);
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
              " checked, ", problems, " problems; ids 0 to ", highest);
        var same = 0;
        var asked = 0;
        for k in FIRST {
            guard k.variant == variant else { continue; }
            asked++;
            if puzzles::entry_by_id(text, lib, k.id, pz) && rules::fen(pz.start) == k.fen { same++; }
        }
        print("  the first library's puzzles by their ids: ", same, " of ", asked, " the same");
    }
}
