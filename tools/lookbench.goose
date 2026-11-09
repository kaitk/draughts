// How long the lookout's threats take (ai/lookout.goose; task 040): `now` (the other
// side's moves were it its turn), `after` a move (what a held piece shows), and `traps`
// (three plies, on the worker), over the quiet positions 10 to 40 plies into a game played
// by a fixed rule from each variant's start, each function over all of them in turn many
// times, the mean a call. Build it (C at -O2) for numbers worth recording:
//
//   goose build -o build/lookbench tools/lookbench.goose && build/lookbench
import std;
import os;
import math;
import rules from "../src/rules";
import ai from "../src/ai";

let ROUNDS = 2000;

fn main() {
    var buf:   rules::Moves = [];
    var moves: rules::Moves = [];
    let tested: u8[3] = [rules::RUSSIAN, rules::INTERNATIONAL, rules::BRAZILIAN];
    for variant in tested {
        // The positions, each with one of its moves to play for `after`, and the other side
        // to move for `traps`.
        var ps: rules::Position[..40] = [];
        var ms: rules::Move[..40]     = [];
        var p = rules::start(variant);
        for ply in 40 {
            rules::generate(p, moves);
            guard moves.len > 0 else { break; }
            if ply >= 10 && moves[0].captured == 0 {
                ps.push(p);
                ms.push(moves[ply % moves.len]);
            }
            p = rules::play(p, moves[moves.len / 2]);
        }
        let n = ps.len;
        var sink: u64 = 0;
        var s = lookout::Seen {};
        let t0 = clock();
        for r in ROUNDS {
            for q in ps {
                lookout::now(q, s, buf);
                sink += s.of[r % lookout::KINDS] + (buf.len as u64);
            }
        }
        let t1 = clock();
        for r in ROUNDS {
            for q, i in ps {
                lookout::after(q, ms[i], s, buf);
                sink += s.of[r % lookout::KINDS] + (buf.len as u64);
            }
        }
        let t2 = clock();
        var most = 0.0;
        for q in ps {
            var o = q;
            o.side = 1 - q.side;
            let a = clock();
            for r in ROUNDS / 10 { sink += lookout::traps(o) + (r as u64); }
            most = max(most, (clock() - a) / (ROUNDS / 10));
        }
        let t3 = clock();
        let calls = (ROUNDS * n) as f64;
        print(rules::VARIANT_NAMES[variant], ": ", n, " positions; now ", floor((t1 - t0) / calls * 1.0e8) / 100.0,
              " us, after a move ", floor((t2 - t1) / calls * 1.0e8) / 100.0, " us, traps ",
              floor((t3 - t2) / (calls / 10.0) * 1.0e8) / 100.0, " us, at most ", floor(most * 1.0e8) / 100.0,
              if sink == 1 { " never" } else { "" });
    }
}
