// The puzzle format and its goals (docs/architecture/puzzles.md). A file that breaks
// the format is refused at its first mistake, with the line and what is wrong: an
// unknown key, a goal that isn't one, a move that isn't legal, a capture's stops off its
// path, a puzzle with no line, an id given twice, a line outside a puzzle, the old `tier`
// in place of a theme and level, a theme that isn't one. Then what puzzles::check
// refuses that the format allows: a line ending with a capture due, a right move along
// a line that no line lists, a take winning more than its count, and a crown that makes
// no king.
// Then what a move does to each goal: a capture taken back doesn't keep the pieces
// (take); a capture that doesn't end on the far row doesn't crown; leaving the other
// side no move wins; a man left in danger isn't safe; a shot's quiet first move keeps
// the goal in reach and its capture reaches it, while another quiet move doesn't. The
// reply the screen plays is the one that resists longest, and the hint is the first
// right move's piece. A wrong move is shown its answer when the other side takes
// something back with it (puzzles::answer): a capture back, a shot's first move; a
// wrong move nothing answers so has none. International's Captures puzzle 32 as it was,
// its man on 39, had a second double, 39x28x37, which 21x32x41 takes back.
import std;
import rules from "../../src/rules";
import puzzles from "../../src/puzzles";

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
    return puzzles::Puzzle { id: 1, theme: 0, level: 1, goal: g, count: count, start: p, moves: moves, lines: [], told: true };
}

let WHAT = ["wrong", "on", "solved"];

// What puzzles::check says of a puzzle, given its goal, position, and lines.
fn checked(body: const u8[:]) {
    var set = puzzles::Set { list: [] };
    var err: u8[>..] = [];
    let ok = puzzles::parse(str("id 1\ntheme learn\nlevel 1\n", body, "source own\n"), set, err);
    assert(ok);
    var s = puzzles::Solver { moves: [], stack: [] };
    var out:  u8[>..] = [];
    var ways: u8[>..] = [];
    let n = puzzles::check(s, set.list[0], out, ways);
    print("checked ", rules::fen(set.list[0].start), ": ", n, " problems", if n > 0 { str("\n", out.trim()) } else { str("") });
}

// What each named move does at the start of a puzzle, and the answer a wrong one is shown.
fn judge(s: puzzles::Solver&, pz: puzzles::Puzzle&, words: const u8[:]) {
    var moves: rules::Moves = [];
    puzzles::begin(s, pz);
    var text: u8[>..] = [];
    for w in split(words, ' ') {
        let ply, ok = puzzles::parse_move(pz.start, w, moves);
        assert(ok);
        let i = puzzles::index_of(pz.start, ply, moves);
        let what = puzzles::judge(s, pz.start, puzzles::short(moves[i]), pz.moves);
        format(text, w, " ", WHAT[what]);
        if what == puzzles::WRONG {
            let r = rules::play(pz.start, moves[i]);
            let a = puzzles::answer(s, r);
            rules::generate(r, moves);
            text.append(if a >= 0 { ", answered by " } else { ", no answer" });
            if a >= 0 { rules::format_move(text, rules::INTERNATIONAL, moves[a]); }
        }
        text.append("; ");
    }
    print(puzzles::GOAL_NAMES[pz.goal], " ", rules::fen(pz.start), ": ", text);
}

fn main() {
    let good = "variant international\n\nid 1\ntheme learn\nlevel 1\ngoal take 1\nposition W:W32:B28\nline 32x23\nsource own\n";
    read(good);
    read("id 1\ntheme learn\nlevel 1\ngoal take 1\nposition W:W32:B28\nline 32x23\ncolour white\n");
    read("id 1\ntheme learn\nlevel 1\ngoal take\nposition W:W32:B28\nline 32x23\n");
    read("id 1\ntheme learn\nlevel 1\ngoal take 1\nposition W:W32:B28\nline 32-27\n");
    // The king on c3 takes d4 and lands on e5 or beyond: its end names the move, and
    // stops off its path name none.
    read("id 1\ntheme learn\nlevel 1\ngoal take 1\nposition W:WK37:B32\nline 37x28\n");
    read("id 1\ntheme learn\nlevel 1\ngoal take 1\nposition W:WK37:B32\nline 37x32x28\n");
    read("id 1\ntheme learn\nlevel 1\ngoal take 1\nposition W:W32:B28\n\n");
    read(str(good, "\nid 1\ntheme learn\nlevel 2\ngoal crown\nposition W:W32:B28\nline 32x23\n"));
    read("line 32x23\n");
    read("id 1\ntier 1\ngoal take 1\nposition W:W32:B28\nline 32x23\n");
    read("id 1\ntheme tactics\nlevel 1\ngoal take 1\nposition W:W32:B28\nline 32x23\n");

    // What puzzles::check refuses beyond the format. The king lands on 33 or 29, and
    // either way black's one move, 6-11, gives it 11: a capture due after the line.
    checked("goal take 1\nposition W:W24,K47:B6,38\nline 47x33\nline 47x29\n");
    // f8 walks past the guard and crowns on c9; d10 crowns as well, and no line lists it.
    checked("goal crown\nposition W:W13,46,47:B4,21,22\nline 13-8 21-26 8-2\n");
    // The king takes two where the goal says one.
    checked("goal take 1\nposition W:W27,K45:B14,15,20,34\nline 45x23x5\n");
    // a3-b4 leaves black no move, which reaches any goal but makes no king.
    checked("goal crown\nposition W:W36,37,42:B26\nline 36-31\n");
    // And one that passes: the king lands on 15, where 25 can't take it.
    checked("goal take 1\nposition W:W31,K47:B8,24,25\nline 47x15\n");

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
    // Captures 32 as it was: the second double is taken back by a double.
    var double = puzzle("W:W25,27,39,43,44,50:B3,4,21,26,32,33", "take 2", 1);
    judge(s, double, "27x38x29 39x28x37");
}
