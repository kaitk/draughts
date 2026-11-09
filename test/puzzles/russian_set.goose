// The built-in Russian puzzles (puzzles/russian.txt): they load, and every one passes
// puzzles::check (each line legal and reaching the goal with its last move, the goal
// forced within the puzzle's moves and not in fewer, every move that is right where a
// line has the solver to move listed, each line ending quiet with a take's count won
// exactly and a crown's king made, no move along a line sharing its squares with
// another, a source), printed with its theme, level, side, goal, pieces, and the first
// moves that solve it; then the count per level of each theme the set has, and how many
// are black's. Russian's own rules are what make it: men capture backward, no capture
// has to take the most, and a man crowned mid-capture goes on as a king. The computer
// player's view of them is tools/puzzles.goose's, too slow for TinyCC, and
// `test/perft.py puzzles russian puzzles/russian.txt` replays every line independently.
import std;
import rules from "../../src/rules";
import puzzles from "../../src/puzzles";

fn main() {
    print("loaded: ", puzzles::load(rules::RUSSIAN), ", the set ", puzzles::VARIANT_NAMES[puzzles::loaded]);
    let set .= puzzles::all;
    var s = puzzles::Solver { moves: [], stack: [] };
    var problems = 0;
    var black = 0;
    var most = 0;
    for pz in set.list {
        var out:  u8[>..] = [];
        var ways: u8[>..] = [];
        s.nodes = 0;
        let n = puzzles::check(s, pz, out, ways);
        problems += n;
        most = max(most, s.nodes);
        if pz.start.side == rules::BLACK { black++; }
        var goal: u8[>..] = [];
        goal.append(puzzles::GOAL_NAMES[pz.goal]);
        if pz.goal == puzzles::TAKE { format(goal, " ", pz.count); }
        print(pz.id, ": ", puzzles::THEME_NAMES[pz.theme], " ", pz.level, ", ",
              if pz.start.side == rules::BLACK { "black" } else { "white" }, ", ", goal, " in ", pz.moves, ", ",
              puzzles::pieces(pz.start), " pieces, ", pz.lines.len, if pz.lines.len == 1 { " line" } else { " lines" },
              "; solved by ", ways);
        if n > 0 { print(out); }
    }
    for t in puzzles::THEMES {
        guard puzzles::theme_count(set, t) > 0 else { continue; }
        var levels: u8[>..] = [];
        for l in 1..puzzles::LEVELS + 1 {
            var k = 0;
            for p in set.list { if p.theme == t && p.level == l { k++; } }
            format(levels, " ", k);
        }
        print(puzzles::THEME_NAMES[t], ": ", puzzles::theme_count(set, t), " puzzles, by level", levels);
    }
    print(set.list.len, " puzzles, ", black, " black to move; at most ", most, " positions a check; ", problems,
          " problems");
}
