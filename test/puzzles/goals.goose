// The puzzle format and its goals (docs/architecture/puzzles.md). A file that breaks
// the format is refused at its first mistake, with the line and what is wrong: an
// unknown key, a goal that isn't one, a move that isn't legal, a capture's stops off its
// path, a puzzle with no line, an id given twice, a line outside a puzzle.
// Then what a move does to each goal: a capture taken back doesn't keep the pieces
// (take); a capture that doesn't end on the far row doesn't crown; leaving the other
// side no move wins; a man left in danger isn't safe; a shot's quiet first move keeps
// the goal in reach and its capture reaches it, while another quiet move doesn't. The
// reply the screen plays is the one that resists longest, and the hint is the first
// right move's piece.
import std;
import rules from "../../rules";
import puzzles from "../../puzzles";

fn read(text: const u8[:]) {
    var set = puzzles::Set { list: [] };
    var err: u8[>..] = [];
    let ok = puzzles::parse(text, set, err);
    print(if ok { "read" } else { "refused, " }, err.trim(), if ok { str(": ", set.list.len, " puzzles") } else { str("") });
}

fn puzzle(fen: const u8[:], goal: const u8[:], moves: i64) -> puzzles::Puzzle {
    let p, ok = rules::parse_fen(fen, rules::INTERNATIONAL);
    assert(ok);
    let g, count, good = puzzles::parse_goal(goal);
    assert(good);
    return puzzles::Puzzle { id: 1, tier: 1, goal: g, count: count, start: p, moves: moves, lines: [], told: true };
}

let WHAT = ["wrong", "on", "solved"];

// What each named move does at the start of a puzzle.
fn judge(s: puzzles::Solver&, pz: puzzles::Puzzle&, words: const u8[:]) {
    var moves: rules::Moves = [];
    puzzles::begin(s, pz);
    var text: u8[>..] = [];
    for w in split(words, ' ') {
        let ply, ok = puzzles::parse_move(pz.start, w, moves);
        assert(ok);
        let i = puzzles::index_of(pz.start, ply, moves);
        format(text, w, " ", WHAT[puzzles::judge(s, pz.start, puzzles::short(moves[i]), pz.moves)], "; ");
    }
    print(puzzles::GOAL_NAMES[pz.goal], " ", rules::fen(pz.start), ": ", text);
}

fn main() {
    let good = "variant international\n\nid 1\ntier 1\ngoal take 1\nposition W:W32:B28\nline 32x23\nsource own\n";
    read(good);
    read("id 1\ntier 1\ngoal take 1\nposition W:W32:B28\nline 32x23\ncolour white\n");
    read("id 1\ntier 1\ngoal take\nposition W:W32:B28\nline 32x23\n");
    read("id 1\ntier 1\ngoal take 1\nposition W:W32:B28\nline 32-27\n");
    // The king on c3 takes d4 and lands on e5 or beyond: its end names the move, and
    // stops off its path name none.
    read("id 1\ntier 1\ngoal take 1\nposition W:WK37:B32\nline 37x28\n");
    read("id 1\ntier 1\ngoal take 1\nposition W:WK37:B32\nline 37x32x28\n");
    read("id 1\ntier 1\ngoal take 1\nposition W:W32:B28\n\n");
    read(str(good, "\nid 1\ntier 2\ngoal crown\nposition W:W32:B28\nline 32x23\n"));
    read("line 32x23\n");

    var s = puzzles::Solver { moves: [], stack: [] };
    // c3 or e3 takes d4; from e5 the man is taken back by f6, from c5 it isn't.
    var take = puzzle("W:W37,38:B19,23,32", "take 1", 1);
    judge(s, take, "37x28 38x27");
    // f8 crowns taking e9; c3 takes d4 but stays a man.
    var crown = puzzle("W:W13,37,48:B6,8,32", "crown", 1);
    judge(s, crown, "13x2 37x28");
    // a3-b4 leaves the man on a5 no move; c3-b4 is taken.
    var win = puzzle("W:W36,37,42:B26", "win", 1);
    judge(s, win, "36-31 37-31 42-38");
    // e7 threatens d6; only d6-c7 escapes.
    var safe = puzzle("W:W22,26,29,34,44:B3,7,13,15,18", "safe", 1);
    judge(s, safe, "22-17 26-21 44-39");
    // f4-e5 gives a man for three; e1-d2 gives nothing.
    var shot = puzzle("W:W33,38,43,45,47,48:B3,11,21,23,24,29", "take 2", 2);
    judge(s, shot, "33-28 48-42");
    var moves: rules::Moves = [];
    let first, ok = puzzles::parse_move(shot.start, "33-28", moves);
    let after = rules::play(shot.start, moves[puzzles::index_of(shot.start, first, moves)]);
    let r = puzzles::reply(s, after, 1);
    rules::generate(after, moves);
    var said: u8[>..] = [];
    rules::format_move(said, rules::INTERNATIONAL, moves[r]);
    let next = rules::play(after, moves[r]);
    let m = puzzles::right_move(s, next, 1);
    rules::generate(next, moves);
    var then: u8[>..] = [];
    rules::format_move(then, rules::INTERNATIONAL, moves[m]);
    let solved = puzzles::judge(s, next, puzzles::short(moves[m]), 1);
    let h = puzzles::right_move(s, shot.start, 2);
    rules::generate(shot.start, moves);
    print("the shot: reply ", said, ", then ", then, " ", WHAT[solved], "; needs ", puzzles::need(s, shot.start, 3),
          " moves from the start; the hint's piece on ", rules::VARIANTS[rules::INTERNATIONAL].number_of[moves[h].from]);
    // A position whose quiet moves lose the man to a reply: f8-g9 is taken by h10.
    var guard_ = puzzle("W:W13,46,47:B4,21,22", "crown", 2);
    judge(s, guard_, "13-8 13-9");
}
