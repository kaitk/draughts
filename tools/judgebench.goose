// Times judging moves (ai/judge.goose, task 074) as the app's worker judges them: a game
// of the computer against itself at medium's start, each move judged after it is played,
// with the time and nodes each took and the marks counted.
//
//   goose build -o build/judgebench tools/judgebench.goose
//   build/judgebench [international|russian|brazilian] [PLIES]
import std;
import os;
import rules from "../src/rules";
import ai from "../src/ai";

fn main() {
    let args = args();
    var variant: u8 = rules::INTERNATIONAL;
    if args.len > 1 {
        let v, ok = rules::variant_named(args[1]);
        if ok { variant = v; }
    }
    var plies = 80;
    if args.len > 2 {
        let n, ok = parse_int(args[2]);
        if ok { plies = n; }
    }
    var e = ai::Engine { .. };
    ai::init(e);
    var j = ai::Engine { .. };
    ai::init(j);
    var p = rules::start(variant);
    var past = rules::Past { draw: rules::draw_start(p), before: [] };
    var moves: rules::Moves   = [];
    var marks: i64[ai::MARKS] = [0; ai::MARKS];
    var total = 0.0;
    var most = 0.0;
    var nodes = 0;
    var n = 0;
    for ply in plies {
        rules::generate(p, moves);
        guard moves.len > 0 else { break; }
        let m = ai::think_after(e, past, p, 40, ply as u64);
        let began = clock();
        let v = ai::judge(j, past, p, m);
        let t = clock() - began;
        total += t;
        most = max(most, t);
        nodes += j.nodes;
        n += 1;
        marks[v.mark] += 1;
        let q = rules::play(p, m);
        rules::pass(past, p, m, q);
        p = q;
    }
    print(n, " moves judged: ", total * 1000.0 / n, " ms a move on average, ", most * 1000.0, " ms at most, ",
          nodes / max(n, 1), " nodes a move");
    print("marks: only ", marks[ai::ONLY], ", best ", marks[ai::BEST], ", good ", marks[ai::GOOD], ", ?! ",
          marks[ai::INACCURACY], ", ? ", marks[ai::MISTAKE], ", ?? ", marks[ai::BLUNDER]);
}
