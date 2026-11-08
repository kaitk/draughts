// Puzzles, with no graphics (docs/architecture/puzzles.md): the plain text they are
// written in, read into a fixed table, and whether a move solves one (solve.goose). A
// puzzle is a position, a goal (win so many men, become a king, win, or find the only
// safe move), and the lines that solve it; any line that reaches the goal counts.
// The puzzles are built into the program and read once at start (load()); tests and
// tools/puzzles.goose read and check them the same way.
//
// Nothing here allocates once loaded: the set is a fixed table, and the solver searches
// with buffers the caller owns.
namespace puzzles;
import std;
import rules from "../rules";
import .solve;
import .check;

let MAX_PUZZLES = 150;      // ids a variant's set may use, 1 to this
let MAX_LINES = 4;          // lines a puzzle lists
let MAX_PLIES = 8;          // moves in a line, the solver's and the replies
let LEVELS = 3;             // a theme's levels: easy, harder, hardest

// The themes, in the library's order; the file names them as THEME_NAMES does.
let LEARN = 0;              // the rules in action
let CAPTURES = 1;           // finding the multi-capture
let CROWNING = 2;           // to the far row
let SHOTS = 3;              // combinations: give men, then take more
let KING_SHOTS = 4;         // the king as a weapon
let THEMES = 5;
let THEME_NAMES = ["learn", "captures", "crowning", "shots", "king-shots"];

// The goals.
let TAKE = 0;               // capture `count` more pieces than are lost, kept through the replies
let CROWN = 1;              // become a king, and keep it through the reply
let WIN = 2;                // leave the other side no move: capture all, or block them
let SAFE = 3;               // the one move that loses nothing (solve.goose, SAFE_DEPTH)
let GOAL_NAMES = ["take", "crown", "win", "safe"];

// A move in a line, as the legal move it matched.
struct Ply { from: u8, to: u8, captured: u64 }

struct Line { plies: Ply[..MAX_PLIES] }

struct Puzzle {
    id:    i64,             // stable, 1..MAX_PUZZLES: progress is kept by it
    theme: i64,             // LEARN..
    level: i64,             // 1..LEVELS
    goal:  i64,
    count: i64,             // TAKE's pieces
    start: rules::Position, // the side to move is the side that solves it
    moves: i64,             // the solver's moves the longest line takes
    lines: Line[..MAX_LINES],
    told:  bool,            // whether it says where it came from (`source`)
}

struct Set { list: Puzzle[..MAX_PUZZLES] }

// The variants as a file names them (`variant russian`, `stars.russian`), in
// rules::RUSSIAN.. order.
let VARIANT_NAMES = ["russian", "international", "english", "brazilian"];

// The puzzles built into the program, once load() has read them, and the variant whose
// set they are.
var all:    Set;
var loaded: u8 = rules::INTERNATIONAL;

// The variant whose set a player of `variant` is shown: Russian has its own, the others
// International's for now.
fn set_of(variant: u8) -> u8 { if variant == rules::RUSSIAN { rules::RUSSIAN } else { rules::INTERNATIONAL } }

// A variant's puzzle file, as built into the program.
fn file(variant: u8 = rules::INTERNATIONAL) -> const u8[:] {
    if set_of(variant) == rules::RUSSIAN { return embed_file("russian.txt"); }
    return embed_file("international.txt");
}

// Reads the built-in puzzles of the set a player of `variant` is shown (set_of) into
// `all`; false if the file has a mistake, which test/puzzles/ rules out.
fn load(variant: u8 = rules::INTERNATIONAL) -> bool {
    all.list.clear();
    loaded = set_of(variant);
    var err: u8[>..] = [];
    return parse(file(loaded), all, err);
}

// The index in set of the puzzle with `id`, or -1.
fn find(set: Set&, id: i64) -> i64 {
    for p, i in set.list { if p.id == id { return i; } }
    return -1;
}

// The legal move of p that `text` names: "32-28", a capture's end "28x10" when no
// other capture from there ends there, or its stops "28x19x10"; and whether there is one.
fn parse_move(p: rules::Position, text: const u8[:], moves: rules::Moves&) -> Ply, bool {
    let v .= rules::VARIANTS[p.variant];
    var stops: u8[..rules::MAX_PATH] = [];
    var rest = text;
    while rest.len > 0 {
        var n = 0;
        while n < rest.len && rest[n] != '-' && rest[n] != 'x' && rest[n] != ':' { n++; }
        let sq, ok = rules::parse_square(v, rest[..n]);
        guard ok && stops.len < rules::MAX_PATH else { return Ply { from: 0, to: 0, captured: 0 }, false; }
        stops.push(sq as u8);
        rest = if n < rest.len { rest[n + 1..] } else { rest[n..] };
    }
    guard stops.len >= 2 else { return Ply { from: 0, to: 0, captured: 0 }, false; }
    rules::generate(p, moves);
    var found = -1;
    for m, i in moves {
        guard m.from == stops[0] && m.to == stops[stops.len - 1] else { continue; }
        guard stops.len == 2 || m.path == stops else { continue; }
        // A capture's end alone must name one move.
        guard found < 0 else { return Ply { from: 0, to: 0, captured: 0 }, false; }
        found = i;
    }
    guard found >= 0 else { return Ply { from: 0, to: 0, captured: 0 }, false; }
    let m .= moves[found];
    return Ply { from: m.from, to: m.to, captured: m.captured }, true;
}

// The legal move of p a ply is, as an index into moves, or -1.
fn index_of(p: rules::Position, ply: Ply, moves: rules::Moves&) -> i64 {
    rules::generate(p, moves);
    for m, i in moves { if m.from == ply.from && m.to == ply.to && m.captured == ply.captured { return i; } }
    return -1;
}

// A goal as the file writes it, "take 2", "crown", "win", or "safe": the goal, TAKE's
// count (1 for the others), and whether it is one.
fn parse_goal(text: const u8[:]) -> i64, i64, bool {
    let name, n, has_n = split_once(trim(text), ' ');
    var goal = -1;
    for g, i in GOAL_NAMES { if trim(name) == g { goal = i; } }
    guard goal >= 0 && has_n == (goal == TAKE) else { return 0, 0, false; }
    guard goal == TAKE else { return goal, 1, true; }
    let c, ok = parse_int(trim(n));
    guard ok && c >= 1 else { return 0, 0, false; }
    return goal, c, true;
}

fn fail(err: u8[>..]&, line: i64, what: const u8[:], text: const u8[:]) -> bool {
    format(err, "line ", line, ": ", what);
    if text.len > 0 { format(err, ": ", text); }
    err.append("\n");
    return false;
}

// Reads puzzles from text into set, after those it holds. A puzzle is a block of
// `key value` lines; a blank line ends it, and # starts a comment. Returns false at the
// first mistake, described in err.
//
//   variant international          the variant of the puzzles after it
//   id 4                           a puzzle: its number, kept with the progress
//   theme captures                 one of THEME_NAMES
//   level 1                        1 to LEVELS, easy to hardest
//   goal take 2                    take N, crown, win, or safe
//   position W:W32,38:B27,28       as PDN's FEN; the side to move solves it
//   line 32x23x34                  a line: the solver's move, the reply, and so on
//   source own, verified by the engine
fn parse(text: const u8[:], set: Set&, err: u8[>..]&) -> bool {
    var variant: u8           = rules::INTERNATIONAL;
    var moves:   rules::Moves = [];
    var open = false;           // a puzzle's block is under way
    var has_position = false;
    var number = 0;
    var rest = text;
    while rest.len > 0 || open {
        let raw, after, found = split_once(rest, '\n');
        rest = after;
        number++;
        let hash, comment, has_hash = split_once(raw, '#');
        let l = trim(hash);
        if l.len == 0 {
            // A blank line, or the end of the text, ends a puzzle.
            if open {
                guard has_position && set.list[set.list.len - 1].lines.len > 0
                else { return fail(err, number, "a puzzle needs a position and a line", ""); }
                let pz .= set.list[set.list.len - 1];
                guard pz.theme >= 0 && pz.level >= 1 else { return fail(err, number, "no theme or level", ""); }
                open = false;
            }
            if rest.len == 0 && !found { break; }
            continue;
        }
        let key, value_raw, spaced = split_once(l, ' ');
        let value = trim(value_raw);
        if key == "variant" {
            var known = false;
            for name, i in VARIANT_NAMES {
                if value == name { variant = i as u8; known = true; }
            }
            guard known && !open else { return fail(err, number, "not a variant here", value); }
            continue;
        }
        if key == "id" {
            let id, ok = parse_int(value);
            guard ok && id >= 1 && id <= MAX_PUZZLES && !open && find(set, id) < 0 && set.list.len < MAX_PUZZLES
            else { return fail(err, number, "not a new id", value); }
            set.list.push(Puzzle { id: id, theme: -1, level: 0, goal: TAKE, count: 1, start: rules::start(variant), moves: 0,
                                   lines: [], told: false });
            open = true;
            has_position = false;
            continue;
        }
        guard open else { return fail(err, number, "outside a puzzle", l); }
        let pz .= set.list[set.list.len - 1];
        if key == "theme" {
            var theme = -1;
            for name, i in THEME_NAMES { if value == name { theme = i; } }
            guard theme >= 0 else { return fail(err, number, "not a theme", value); }
            pz.theme = theme;
        } else if key == "level" {
            let n, ok = parse_int(value);
            guard ok && n >= 1 && n <= LEVELS else { return fail(err, number, "not a level", value); }
            pz.level = n;
        } else if key == "goal" {
            let goal, count, ok = parse_goal(value);
            guard ok else { return fail(err, number, "not a goal", value); }
            pz.goal = goal;
            pz.count = count;
        } else if key == "position" {
            let p, ok = rules::parse_fen(value, variant);
            guard ok && !has_position else { return fail(err, number, "not a position", value); }
            pz.start = p;
            has_position = true;
        } else if key == "line" {
            guard has_position && pz.lines.len < MAX_LINES else { return fail(err, number, "a line where none can be", value); }
            let line .= pz.lines.push(Line { plies: [] });
            var p = pz.start;
            for word in split(value, ' ') {
                guard word.len > 0 else { continue; }
                guard line.plies.len < MAX_PLIES else { return fail(err, number, "too long", value); }
                let ply, ok = parse_move(p, word, moves);
                guard ok else { return fail(err, number, "not a legal move here", word); }
                line.plies.push(ply);
                p = rules::play(p, moves[index_of(p, ply, moves)]);
            }
            guard line.plies.len > 0 else { return fail(err, number, "an empty line", value); }
            pz.moves = max(pz.moves, (line.plies.len + 1) / 2);
        } else if key == "source" {
            pz.told = value.len > 0;
        } else {
            return fail(err, number, "unknown key", key);
        }
    }
    return true;
}

// How many puzzles of a theme there are, and the index in set of its n-th.
fn theme_count(set: Set&, theme: i64) -> i64 {
    var n = 0;
    for p in set.list { if p.theme == theme { n++; } }
    return n;
}
fn nth(set: Set&, theme: i64, n: i64) -> i64 {
    var k = 0;
    for p, i in set.list {
        guard p.theme == theme else { continue; }
        if k == n { return i; }
        k++;
    }
    return -1;
}
