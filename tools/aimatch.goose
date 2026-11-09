// Plays the computer against itself at two skills, to check that the levels are
// ordered and to see how often each wins.
//
//   goose build -o build/aimatch tools/aimatch.goose
//   build/aimatch russian|international|brazilian SKILL_A SKILL_B GAMES [--fens PLY] [--nodes A B]
//                 [--overlooks A B]
//
// Each pair of games starts from the same position with colors swapped. A game is
// drawn after 300 plies, or after 50 plies with no capture and no man moved. Prints
// A's wins, draws, and losses. --fens prints the position at ply PLY of each game
// instead, for benchmarks. --nodes gives each side its own node limit. --overlooks gives
// each side its percent of the overlook chances (ai::Engine.overlooks): 0 plays a skill
// below 15 as it played before it overlooked anything, 200 overlooks twice as often.
import std;
import os;
import rules from "../src/rules";
import ai from "../src/ai";

fn main() {
    let a = args();
    if a.len < 5 {
        write_stderr("usage: aimatch russian|international|brazilian SKILL_A SKILL_B GAMES [--fens PLY] [--nodes A B] [--overlooks A B]\n");
        exit(2);
    }
    let named, known = rules::variant_named(a[1]);
    let variant: u8 = if known { named } else { rules::INTERNATIONAL };
    let sa, oka = parse_int(a[2]);
    let sb, okb = parse_int(a[3]);
    let games, okg = parse_int(a[4]);
    var fens_at = -1;
    var limit_a = ai::NODE_LIMIT;
    var limit_b = ai::NODE_LIMIT;
    var overlooks_a = 100;
    var overlooks_b = 100;
    var k = 5;
    while k + 1 < a.len {
        if a[k] == "--fens" {
            let n, ok = parse_int(a[k + 1]);
            if ok { fens_at = n; }
            k += 2;
        } else if a[k] == "--nodes" && k + 2 < a.len {
            let x, okx = parse_int(a[k + 1]);
            let y, oky = parse_int(a[k + 2]);
            if okx && oky { limit_a = x; limit_b = y; }
            k += 3;
        } else if a[k] == "--overlooks" && k + 2 < a.len {
            let x, okx = parse_int(a[k + 1]);
            let y, oky = parse_int(a[k + 2]);
            if okx && oky { overlooks_a = x; overlooks_b = y; }
            k += 3;
        } else {
            k += 1;
        }
    }
    var e = ai::Engine { .. };
    ai::init(e);
    var moves: rules::Moves = [];
    var wins = 0;
    var draws = 0;
    var losses = 0;
    var plies = 0;
    for g in games {
        // A plays white in even games.
        let a_side: u8 = if g % 2 == 0 { rules::WHITE } else { rules::BLACK };
        var p = rules::start(variant);
        var quiet = 0;
        var result = 0;
        for ply in 300 {
            if ply == fens_at { print(rules::fen(p)); }
            rules::generate(p, moves);
            if moves.len == 0 {
                result = if p.side == a_side { -1 } else { 1 };
                break;
            }
            guard quiet < 50 else { break; }
            let skill = if p.side == a_side { sa } else { sb };
            e.node_limit = if p.side == a_side { limit_a } else { limit_b };
            e.overlooks = if p.side == a_side { overlooks_a } else { overlooks_b };
            // Pairs of games share seeds, so both colors meet the same choices.
            let seed = ((g / 2) * 1000 + ply) as u64;
            let m = ai::think(e, p, skill, seed);
            let man = p.kings & rules::bit(m.from) == 0;
            quiet = if m.captured != 0 || man { 0 } else { quiet + 1 };
            p = rules::play(p, m);
            plies += 1;
        }
        if result > 0 { wins += 1; } else if result < 0 { losses += 1; } else { draws += 1; }
    }
    if fens_at < 0 {
        print("skill ", sa, " against ", sb, ": ", wins, " won, ", draws, " drawn, ", losses,
              " lost, ", plies / max(games, 1), " plies a game");
    }
}
