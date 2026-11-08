// The built-in puzzles (puzzles/international.txt): they load, and every one passes
// puzzles::check (each line legal and reaching the goal with its last move, the goal
// forced within the puzzle's moves and not in fewer, every first move that solves it
// listed, no move along a line sharing its squares with another, a source), printed
// with its tier, goal, pieces, and the first moves that solve it. The computer player's
// view of them is tools/puzzles.goose's, too slow for TinyCC.
import std;
import rules from "../../rules";
import puzzles from "../../puzzles";

fn main() {
    print("loaded: ", puzzles::load());
    let set .= puzzles::all;
    var s = puzzles::Solver { moves: [], stack: [] };
    var problems = 0;
    for pz in set.list {
        var out:  u8[>..] = [];
        var ways: u8[>..] = [];
        let n = puzzles::check(s, pz, out, ways);
        problems += n;
        var goal: u8[>..] = [];
        goal.append(puzzles::GOAL_NAMES[pz.goal]);
        if pz.goal == puzzles::TAKE { format(goal, " ", pz.count); }
        print(pz.id, ": tier ", pz.tier, ", ", goal, " in ", pz.moves, ", ", puzzles::pieces(pz.start), " pieces, ",
              pz.lines.len, if pz.lines.len == 1 { " line" } else { " lines" }, "; solved by ", ways);
        if n > 0 { print(out); }
    }
    for t in 1..puzzles::TIERS + 1 { print("tier ", t, ": ", puzzles::tier_count(set, t), " puzzles"); }
    print(problems, " problems");
}
