// What the computer overlooks (ai/ai.goose, docs/architecture/ai.md, "Levels"): as a
// person errs, it misses the child's captures after its move more where captures are
// around (tense), the more pieces a capture takes, and the further it starts from the
// piece just moved, and hardly at all in a quiet position. Easy misses a one-piece
// capture now and then until 15, a two-piece one until 25; medium only captures of
// three pieces or more, now and then; hard never.
//
// Prints each skill's chances; then, for one of the computer's moves and one of the
// child's captures after it, how often it is overlooked over 4000 seeds, in a quiet
// position and in the same with a capture around (a man of the computer's attacked far
// off); then, where one move hangs pieces and others are safe, how often it is played
// under 40 seeds: with overlooks off, as in play, and with every chance a thousand
// times over. Only what the child may capture next is overlooked: the computer's own
// captures stay compulsory, as the rules make them.
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";
import check from "../";

let SEEDS = 40;
let DRAWS = 4000;

// The move of p written `text`.
fn find(p: rules::Position, text: const u8[:]) -> rules::Move {
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    for i in moves.len {
        var t: u8[>..] = [];
        rules::format_move(t, p.variant, moves[i]);
        if t[..] == text { return moves[i]; }
    }
    print("no move ", text, " in ", rules::fen(p));
    exit(1);
    return moves[0];
}

// How many of DRAWS seeds overlook the capture `theirs` after `mine` in fen at `skill`.
fn rate(e: ai::Engine&, fen: const u8[:], mine: const u8[:], theirs: const u8[:], skill: i64) -> i64 {
    let p = check::position(rules::RUSSIAN, fen);
    let m = find(p, mine);
    let c = find(rules::play(p, m), theirs);
    var n = 0;
    for seed: u64 in DRAWS {
        ai::notice(e, p, skill, seed);
        if ai::overlooked(e, m, c) { n += 1; }
    }
    return n;
}

fn rates(e: ai::Engine&, what: const u8[:], fen: const u8[:], mine: const u8[:], theirs: const u8[:]) {
    var text: u8[>..] = [];
    for s in [0, 10, 15, 25, 40, 65] { format(text, " ", rate(e, fen, mine, theirs, s)); }
    print(fen, ": ", mine, " then ", theirs, ", ", what, "; overlooked at skill 0, 10, 15, 25, 40, 65:", text,
          " of ", DRAWS);
}

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

fn position(e: ai::Engine&, what: const u8[:], fen: const u8[:], bad: const u8[:], skill: i64) {
    print(fen, ": ", bad, " ", what);
    print("  skill ", skill, ", overlooks off ", hangs(e, fen, bad, skill, 0), ", as in play ",
          hangs(e, fen, bad, skill, 100), ", a thousand times over ", hangs(e, fen, bad, skill, 100000), " of ",
          SEEDS);
}

fn main() {
    for s in [0, 5, 10, 14, 15, 20, 25, 40, 60, 65, 90] {
        let pr = ai::params(s);
        print("skill ", s, ": per 1000, tense, next to the moved piece, misses a capture of 1, 2, 3, 4+ pieces ",
              pr.miss[0], ", ", pr.miss[1], ", ", pr.miss[2], ", ", pr.miss[3]);
    }
    var e = ai::Engine { .. };
    ai::init(e);
    // c3-d4 lands next to e5, which takes it. Quiet; with g5 for g3 tense, as h6
    // attacks g5.
    rates(e, "one man next to it, quiet", "W:Wc3,h2,g1,g3:Be5,h6,a7", "c3-d4", "e5:c3");
    rates(e, "one man next to it, tense", "W:Wc3,h2,g1,g5:Be5,h6,a7", "c3-d4", "e5:c3");
    // c3-b4 leaves g5 to h6, which starts six columns away.
    rates(e, "one man far from it, tense", "W:Wc3,h2,g1,g5:Be5,h6,a7", "c3-b4", "h6:f4");
    // a5-b6 lands next to a7, which takes it and two more: a7:c5:e3:g1.
    rates(e, "three men from next to it, quiet", "W:Wa5,d4,f2,g3:Ba7,h6", "a5-b6", "a7:c5:e3:g1");
    rates(e, "three men from next to it, tense", "W:Wa5,d4,f2,g5:Ba7,h6", "a5-b6", "a7:c5:e3:g1");
    // In play. c3-d4 hangs a man in the quiet position, where c3-b4, g1-f2, g3-f4, and
    // g3-h4 are safe: easy almost never plays it.
    position(e, "moves a man where it is taken, quiet", "W:Wc3,h2,g1,g3:Be5,h6,a7", "c3-d4", 0);
    // a5-b6 gives three men for none. Easy plays it now and then, though g5's danger,
    // which it sees, draws it to g5-f6 or f2-g3 even when it overlooks a7's capture;
    // from 65 on nothing does. Medium's share shows in the rates above.
    position(e, "gives three men, tense", "W:Wa5,d4,f2,g5:Ba7,h6", "a5-b6", 0);
    position(e, "gives three men, tense", "W:Wa5,d4,f2,g5:Ba7,h6", "a5-b6", 65);
}
