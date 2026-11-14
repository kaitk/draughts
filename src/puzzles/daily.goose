// The daily puzzles (docs/architecture/puzzles.md, "Daily puzzles"): a large library
// generated offline (tools/puzzles.goose) and built into the program, a few a day picked
// by the date and the player at the player's level, and the player's puzzle rating that
// a solve moves. Pure functions over value types and fixed tables: nothing allocates
// once the library's index is read, which load_library does at start and when the
// player's draughts change, never while a screen is drawn.
namespace puzzles;
import std;
import math;
import rules from "../rules";

let MAX_LIBRARY = 4096;     // puzzles a variant's library may hold
let MAX_DAILY = 10;         // puzzles a day at most (the setting's 3, 4, 5, or 10)
let DAILY_DEFAULT = 4;
let SEEN_WORDS = MAX_LIBRARY / 64; // a bit for each library puzzle a player has had

// The day's shape around the player's rating: a warm-up below it, the middle at it, and
// a stretch above it.
let WARM_UP = -250;
let STRETCH = 250;
let NEAR = 60;              // library puzzles nearest a slot's target that one is picked from, at most
let WINDOW = 75;            // how far from the target they may be, once FEW are found
let FEW = 8;

// The puzzle rating, Elo's, on the scale the library's difficulties are estimated on.
let FIRST_PUZZLE_RATING = 350;   // a player with no star in the course
let COURSE_SPAN = 600;           // what the whole course at three stars adds to it
let LEAST_PUZZLE_RATING = 100;
let K_FIRST = 96;           // the step while the rating is new, as Glicko's deviation is large then
let K_LEAST = 24;           // the step once settled
let K_FALL = 6;             // how much the step falls with each puzzle rated
let STAR_SCORE: i64[4] = [0, 30, 60, 100]; // a solve's score in percent by its stars (3 = 1.0, 2 = 0.6, 1 = 0.3)

// A library puzzle as the index keeps it: its difficulty and theme, and where its line
// of text is in the built-in file.
struct Entry { difficulty: i64, theme: i64, level: i64, at: i64, len: i64 }

struct Library { list: Entry[..MAX_LIBRARY], variant: u8 = rules::INTERNATIONAL }

var library:        Library;
var library_loaded: u8 = rules::INTERNATIONAL;

// A variant's library file, as built into the program: one puzzle a line,
//
//   difficulty | theme level | goal in moves | position | line
//
// sorted by difficulty; `#` starts a comment, and a `variant` line names the rules.
fn library_file(variant: u8 = rules::INTERNATIONAL) -> const u8[:] {
    let set = set_of(variant);
    if set == rules::RUSSIAN { return embed_file("library-russian.txt"); }
    if set == rules::BRAZILIAN { return embed_file("library-brazilian.txt"); }
    return embed_file("library-international.txt");
}

// Reads the index of the library a player of `variant` is shown into `library`: each
// line's difficulty, theme, and place, not its position or line, which entry_of reads
// for one puzzle when it is wanted. False if a line isn't one, which test/puzzles/ rules
// out.
fn load_library(variant: u8 = rules::INTERNATIONAL) -> bool {
    library_loaded = set_of(variant);
    return index_library(library_file(library_loaded), library);
}

fn index_library(text: const u8[:], lib: Library&) -> bool {
    lib.list.clear();
    lib.variant = rules::INTERNATIONAL;
    var at = 0;
    while at < text.len {
        var end = at;
        while end < text.len && text[end] != '\n' { end++; }
        let l = trim(text[at..end]);
        if starts_with(l, "variant ") {
            let named, known = rules::variant_named(trim(l[8..]));
            guard known else { return false; }
            lib.variant = named;
        } else if l.len > 0 && l[0] != '#' {
            guard lib.list.len < MAX_LIBRARY else { return false; }
            let d, rest, ok1 = split_once(l, '|');
            let tl, _, ok2 = split_once(rest, '|');
            let name, lv, ok3 = split_once(trim(tl), ' ');
            let difficulty, ok4 = parse_int(trim(d));
            let level, ok5 = parse_int(trim(lv));
            var theme = -1;
            for n, i in THEME_NAMES { if trim(name) == n { theme = i; } }
            guard ok1 && ok2 && ok3 && ok4 && ok5 && theme >= 0 else { return false; }
            lib.list.push(Entry { difficulty: difficulty, theme: theme, level: level, at: at, len: end - at });
        }
        at = end + 1;
    }
    return true;
}

// Library puzzle i (an index into lib) read into pz from its line of text, its id i + 1;
// whether it reads.
fn entry_of(text: const u8[:], lib: Library&, i: i64, pz: Puzzle&) -> bool {
    guard i >= 0 && i < lib.list.len else { return false; }
    let e = lib.list[i];
    guard parse_entry(text[e.at..e.at + e.len], lib.variant, pz) else { return false; }
    pz.id = i + 1;
    pz.theme = e.theme;
    pz.level = e.level;
    return true;
}

// A library line read into pz: its goal, moves, position, and its one line. Its theme
// and level come from the index.
fn parse_entry(l: const u8[:], variant: u8, pz: Puzzle&) -> bool {
    var fields: const u8[:][..5] = [];
    var rest:   const u8[:]      = l;
    while fields.len < 5 {
        let a, b, more = split_once(rest, '|');
        fields.push(trim(a));
        rest = b;
        guard more else { break; }
    }
    guard fields.len == 5 else { return false; }
    let goal_part, k_part, has_k = split_once(fields[2], " in ");
    guard has_k else { return false; }
    let k, ok_k = parse_int(trim(k_part));
    let g, count, ok_g = parse_goal(goal_part);
    let start, ok_p = rules::parse_fen(fields[3], variant);
    guard ok_k && ok_g && ok_p else { return false; }
    pz = Puzzle { id: 1, theme: 0, level: 1, goal: g, count: count, start: start, moves: k, lines: [], told: true };
    let line .= pz.lines.push(Line { plies: [] });
    var q = start;
    var legal: rules::Moves = [];
    for word in split(fields[4], ' ') {
        guard word.len > 0 else { continue; }
        guard line.plies.len < MAX_PLIES else { return false; }
        let ply, ok = parse_move(q, word, legal);
        guard ok else { return false; }
        line.plies.push(ply);
        q = rules::play(q, legal[index_of(q, ply, legal)]);
    }
    return line.plies.len > 0;
}

// A day's puzzles: indexes into the library, in the order they are played.
struct Day { list: i64[..MAX_DAILY] }

// A mixing hash (splitmix64's finish), so the day's choices look random but come again
// the same from the same day, player, and slot.
fn mix(x: u64) -> u64 {
    var z = x + 0x9E3779B97F4A7C15;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EB;
    return z ^ (z >> 31);
}

// The target difficulty of slot i of a day of n around `rating`: the first a warm-up,
// the last a stretch, those between at the rating, each a little apart.
fn target(rating: i64, i: i64, n: i64) -> i64 {
    guard n >= 3 else { return rating; }
    if i == 0 { return rating + WARM_UP; }
    if i == n - 1 { return rating + STRETCH; }
    let middle = n - 2;
    return rating + (i - 1) * 100 / max(middle, 1) - 50 * (middle - 1) / max(middle, 1);
}

fn is_seen(seen: u64[SEEN_WORDS]&, i: i64) -> bool { seen[i / 64] & rules::bit(i % 64) != 0 }

// The day's puzzles for a player (docs/architecture/puzzles.md, "Daily puzzles"): `n` of
// them from lib, by `day` (days since the epoch, by the local date) and `player`, so a
// day's set comes again the same all day and differs between players. Each slot has its
// target (target) around `rating`, the player's at the day's start; of the library's
// puzzles in the themes of `themes` (a bit per theme) not yet had (`seen`) nor picked
// today, it takes one of the NEAR nearest the target within WINDOW of it (or of the FEW
// nearest, where the library is sparse), by the hash of the day, player, and slot. Fewer than n when the library has too few left.
fn pick(lib: Library&, day: i64, player: i64, rating: i64, themes: u64, seen: u64[SEEN_WORDS]&, n: i64, out: Day&) {
    out.list.clear();
    let count = min(n, MAX_DAILY);
    for slot in count {
        let t = target(rating, slot, count);
        // The first at or past the target, the list being sorted by difficulty.
        var lo = 0;
        var hi = lib.list.len;
        while lo < hi {
            let mid = (lo + hi) / 2;
            if lib.list[mid].difficulty < t { lo = mid + 1; } else { hi = mid; }
        }
        // Walk out both ways from there, nearest first, keeping NEAR candidates.
        var near: i64[NEAR] = [0; NEAR];
        var found = 0;
        var a = lo - 1;
        var b = lo;
        while found < NEAR && (a >= 0 || b < lib.list.len) {
            var i = -1;
            if a < 0 {
                i = b;
                b++;
            } else if b >= lib.list.len {
                i = a;
                a--;
            } else if t - lib.list[a].difficulty <= lib.list[b].difficulty - t {
                i = a;
                a--;
            } else {
                i = b;
                b++;
            }
            guard found < FEW || abs(lib.list[i].difficulty - t) <= WINDOW else { break; }
            guard themes & rules::bit(lib.list[i].theme) != 0 && !is_seen(seen, i) else { continue; }
            var taken = false;
            for x in out.list { if x == i { taken = true; } }
            guard !taken else { continue; }
            near[found] = i;
            found++;
        }
        guard found > 0 else { continue; }
        let h = mix(mix((day as u64) * 1000003 + (player as u64)) + (slot as u64));
        out.list.push(near[(h % (found as u64)) as i64]);
    }
}

// The first puzzle rating of a player, from the course: the stars won in the player's
// set of `all` there are to win.
fn first_puzzle_rating(stars: i64, all: i64) -> i64 {
    guard all > 0 else { return FIRST_PUZZLE_RATING; }
    return FIRST_PUZZLE_RATING + COURSE_SPAN * clamp(stars, 0, all) / all;
}

// The rating after a first try at a puzzle of `difficulty` solved with `stars` (1 to 3),
// `rated` puzzles having moved it before: Elo's expected score against the difficulty,
// the step large while the rating is new and falling to K_LEAST.
fn rated(rating: i64, rated_before: i64, difficulty: i64, stars: i64) -> i64 {
    let k = max(K_LEAST, K_FIRST - K_FALL * rated_before);
    let expected = 1.0 / (1.0 + pow(10.0, (difficulty - rating) / 400.0));
    let score = STAR_SCORE[clamp(stars, 0, 3)] / 100.0;
    let moved = k * (score - expected);
    return max(LEAST_PUZZLE_RATING, rating + round(moved) as i64);
}
