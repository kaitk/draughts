// Easy's overlooks (ai/ai.goose, docs/architecture/ai.md, "Levels"): below skill 15 the
// computer now and then doesn't look where the piece it moves lands (LAND), or what its
// move opens behind it (OPEN), as a young child does, with a chance that fades to none
// at 15. Prints each skill's chances; how often each overlook comes over many seeds;
// then, in two positions with one move that hangs a man and safe ones, how often skill
// 0 plays it under 40 seeds: never with overlooks off, now and then as in play, often
// when every move overlooks, and never at 15 whatever the chances. Only what the child
// may capture next is overlooked: its own captures stay compulsory, as the rules make
// them.
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";
import check from "../";

let SEEDS = 40;

// How many of SEEDS seeds play `bad` in fen at `skill`, `overlooks` percent of the
// chances.
fn hangs(e: ai::Engine&, fen: const u8[:], bad: const u8[:], skill: i64, overlooks: i64) -> i64 {
    let p = check::position(rules::RUSSIAN, fen);
    e.overlooks = overlooks;
    var n = 0;
    for seed: u64 in SEEDS {
        let m = ai::think(e, p, skill, seed);
        var t: u8[>..] = [];
        rules::format_move(t, rules::RUSSIAN, m);
        if t[..] == bad { n += 1; }
    }
    e.overlooks = 100;
    return n;
}

fn position(e: ai::Engine&, what: const u8[:], fen: const u8[:], bad: const u8[:]) {
    print(fen, ": ", bad, " ", what);
    print("  skill 0, overlooks off ", hangs(e, fen, bad, 0, 0), ", as in play ", hangs(e, fen, bad, 0, 100),
          ", every move ", hangs(e, fen, bad, 0, 100000), "; skill 15, every move ", hangs(e, fen, bad, 15, 100000),
          " of ", SEEDS);
}

fn main() {
    for s in [0, 5, 10, 14, 15, 30] {
        let pr = ai::params(s);
        print("skill ", s, ": per 1000 moves, misses where its piece lands ", pr.land, ", a capture it opens ",
              pr.open);
    }
    var e = ai::Engine { .. };
    ai::init(e);
    // How often each comes at skill 0, over 2000 moves of the opening.
    let start = rules::start(rules::RUSSIAN);
    var land = 0;
    var open = 0;
    for seed: u64 in 2000 {
        ai::think(e, start, 0, seed);
        if e.overlook & ai::LAND != 0 { land += 1; }
        if e.overlook & ai::OPEN != 0 { open += 1; }
    }
    print("skill 0 over 2000 moves: misses where its piece lands ", land, ", a capture it opens ", open);
    // c3-d4 lands where e5:c3 takes it; c3-b4, g1-f2, and h2-g3 are safe.
    position(e, "moves a man where it is taken", "W:Wc3,h2,g1:Be5,h8,a7", "c3-d4");
    // d2-e3 leaves d2 empty behind c3, so b4:d2 takes c3, and nothing takes back (e3's
    // landing square c1 is held); c1-b2, c3-d4, f4-e5, f4-g5, and h2-g3 are safe.
    position(e, "opens a capture behind it", "W:Wc1,c3,d2,f4,h2:Ba5,b4,h8", "d2-e3");
}
