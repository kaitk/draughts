// The daily puzzles' pick and the puzzle rating (docs/architecture/puzzles.md, "Daily
// puzzles"), on a small library of the course's positions written as the generated
// file is, their ids out of the file's order. The index reads each line's id,
// difficulty, and theme, finds a puzzle by its id, and refuses a line that isn't one, an
// id given twice, and one past the index's room. A day's pick is the same for the same day and player, differs between
// days and between players, keeps the day's shape (a warm-up under the rating, the
// middle at it, a stretch over it), keeps to the themes given and skips the puzzles
// already had, never takes one twice in a day, and mixes the day's themes (s and c by
// turns where both are near); a library with too few gives fewer.
// The rating starts from the course's stars, moves a long way on the first puzzles and
// less later, up on a solve of a hard one and less on an easy one, and a solve with one
// star at its level lowers it.
import std;
import rules from "../../src/rules";
import puzzles from "../../src/puzzles";

// The id of the test library's i-th line: every one of 0 to 199 once, out of order, as
// puzzles added to a library take the next ids wherever their difficulty sorts them.
fn id_at(i: i64) -> i64 { (i * 37 + 11) % 200 }

// 200 puzzles, difficulties 300 to 2290 by tens, captures and shots by turns.
fn small() -> u8[>..] {
    var t: u8[>..] = [];
    t.append("# a test library\nvariant international\n");
    for i in 200 {
        let theme = if i % 2 == 0 { "captures 1" } else { "shots 1" };
        format(t, id_at(i), " | ", 300 + 10 * i, " | ", theme,
               " | take 2 in 1 | W:W31,32,36,37,38,41,42,47:B6,10,11,15,16,24,33,34 | 38x29x40\n");
    }
    return t;
}

// A day's puzzles by difficulty and theme, read through their ids.
fn show(lib: puzzles::Library&, d: puzzles::Day&) -> u8[>..] {
    var out: u8[>..] = [];
    for id in d.list {
        let i = puzzles::place_of(lib, id);
        format(out, " ", lib.list[i].difficulty, if lib.list[i].theme == puzzles::SHOTS { "s" } else { "c" });
    }
    return out;
}

fn main() {
    var lib = puzzles::Library { list: [] };
    let text = small();
    print("index: ", puzzles::index_library(text, lib), ", ", lib.list.len, " puzzles");
    var pz = puzzles::Puzzle { id: 0, theme: 0, level: 1, goal: 0, count: 1, start: rules::start(rules::INTERNATIONAL), moves: 0,
                               lines: [], told: false };
    print("entry 5: ", puzzles::entry_of(text, lib, 5, pz), ", id ", lib.list[5].id, " (puzzle ", pz.id, "), ",
          puzzles::THEME_NAMES[pz.theme], ", ", rules::fen(pz.start), ", ", pz.lines[0].plies.len, " ply");
    print("id 11 at ", puzzles::place_of(lib, 11), ", id 196 at ", puzzles::place_of(lib, 196), ", id 200 at ",
          puzzles::place_of(lib, 200), ", id -1 at ", puzzles::place_of(lib, -1));
    print("by id 196: ", puzzles::entry_by_id(text, lib, 196, pz), ", difficulty ", lib.list[puzzles::place_of(lib, 196)].difficulty,
          ", puzzle ", pz.id, "; by id 200: ", puzzles::entry_by_id(text, lib, 200, pz));
    var bad = puzzles::Library { list: [] };
    print("a line that isn't one: ",
          puzzles::index_library("variant international\n0 | 300 | sideways 1 | take 2 in 1 | W:W1:B2 | 1-6\n", bad));
    print("a line without its id: ",
          puzzles::index_library("variant international\n300 | captures 1 | take 1 in 1 | W:W32,47:B27,5 | 32x21\n", bad));
    print("an id given twice: ",
          puzzles::index_library("variant international\n4 | 300 | captures 1 | take 1 in 1 | W:W32,47:B27,5 | 32x21\n4 | 310 | captures 1 | take 1 in 1 | W:W32,47:B27,5 | 32x21\n",
                                 bad));
    print("an id past the index: ",
          puzzles::index_library("variant international\n4096 | 300 | captures 1 | take 1 in 1 | W:W32,47:B27,5 | 32x21\n", bad));
    print("the last id: ",
          puzzles::index_library("variant international\n4095 | 300 | captures 1 | take 1 in 1 | W:W32,47:B27,5 | 32x21\n", bad), ", at ",
          puzzles::place_of(bad, 4095));

    var seen: u64[puzzles::SEEN_WORDS] = [0; puzzles::SEEN_WORDS];
    let both = rules::bit(puzzles::CAPTURES) | rules::bit(puzzles::SHOTS);
    var d = puzzles::Day { list: [] };
    for n in [3, 4, 5, 10] {
        puzzles::pick(lib, 20000, 1, 1200, both, seen, n, d);
        print("day 20000, player 1, rating 1200, ", n, " a day:", show(lib, d));
    }
    var again = puzzles::Day { list: [] };
    puzzles::pick(lib, 20000, 1, 1200, both, seen, 4, d);
    puzzles::pick(lib, 20000, 1, 1200, both, seen, 4, again);
    print("the same day again: ", d.list == again.list);
    puzzles::pick(lib, 20001, 1, 1200, both, seen, 4, again);
    print("the next day:", show(lib, again));
    puzzles::pick(lib, 20000, 2, 1200, both, seen, 4, again);
    print("another player:", show(lib, again));
    puzzles::pick(lib, 20000, 1, 600, rules::bit(puzzles::CAPTURES), seen, 4, d);
    print("rating 600, captures only:", show(lib, d));
    // Every capture but two had: those two, and nothing else.
    for i in 200 { if i % 2 == 0 && i != 40 && i != 160 { seen[id_at(i) / 64] |= rules::bit(id_at(i) % 64); } }
    puzzles::pick(lib, 20000, 1, 1200, rules::bit(puzzles::CAPTURES), seen, 4, d);
    print("all but two had:", show(lib, d));

    print("first rating: no stars ", puzzles::first_puzzle_rating(0, 222), ", half ", puzzles::first_puzzle_rating(111, 222),
          ", all ", puzzles::first_puzzle_rating(222, 222));
    var r = 650;
    var line: u8[>..] = [];
    for k in 8 {
        r = puzzles::rated(r, k, 1100, 3);
        format(line, " ", r);
    }
    print("eight three-star solves at 1100 from 650:", line);
    print("settled, three stars at 1600: ", puzzles::rated(1200, 40, 1600, 3), "; at 800: ", puzzles::rated(1200, 40, 800, 3));
    print("one star at its level: ", puzzles::rated(1200, 40, 1200, 1), "; two: ", puzzles::rated(1200, 40, 1200, 2));
    print("never under ", puzzles::rated(110, 0, 2000, 1));
}
