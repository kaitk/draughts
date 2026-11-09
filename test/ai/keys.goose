// The search's incremental Zobrist key must equal the key computed from scratch after
// every kind of move: quiet, capturing men and kings, crowning, a king returning to
// its square. Plays seeded random games in each variant and checks every move.
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";

fn main() {
    var r = rng { 7 };
    var moves: rules::Moves = [];
    for variant: u8 in 3 {
        var checked = 0;
        var bad = 0;
        for game in 40 {
            var p = rules::start(variant);
            var k = ai::key(p);
            for ply in 200 {
                rules::generate(p, moves);
                guard moves.len > 0 else { break; }
                let m = moves[rand_int(r, moves.len)];
                k = ai::key_after(k, p, m);
                p = rules::play(p, m);
                checked += 1;
                if k != ai::key(p) { bad += 1; }
            }
        }
        print("variant ", variant, ": ", checked,
              " moves, ", bad, " keys wrong");
    }
}
