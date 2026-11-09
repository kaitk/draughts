// No skill from 15 on hangs a piece: in positions from games the computer played
// against itself, neither easy's skill 15 nor medium's or hard's start, under any of
// several seeds, plays a move after which the opponent's captures win a man or more,
// when another move loses less that way. Below 15 easy now and then overlooks a capture
// the child can make (ai::start's overlook), as a young child does: easy's start, skill
// 0, hangs a piece only on a move that overlooked one, and those are counted apart. The check is a
// plain recursive minimax over material written here: the move, then only captures,
// four plies of them at most. A move it flags passes as a sacrifice only when the
// level's own search shows the material coming back within what it sees: a combination
// it tried, which may fail deeper, as a person's does. So this guards the choosing
// (ai::choose and the chances left for the child); that every level sees a plain hang
// at all follows from each seeing two plies and the captures they force, and from the
// search matching minimax (test/ai/search.goose). A move that leaves the child a
// combination on the easiest skills is counted apart: it never leaves a capture.
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";

let SEEDS = 2;
// The skills checked: easy's start, the lowest that never overlooks, medium's, hard's.
let SKILLS = [0, 15, 40, 90];
let COUNT = 4;

fn material(p: rules::Position) -> i64 {
    var s = 0;
    for side in 2 {
        let v = 100 * popcount(p.pieces[side] & ~p.kings) + 300 * popcount(p.pieces[side] & p.kings);
        s += if side == p.side { v } else { -v };
    }
    return s;
}

recursive fn minimax(p: rules::Position, d: i64, h: i64) -> i64 {
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    if moves.len == 0 { return -10000; }
    if h <= 0 || (d <= 0 && moves[0].captured == 0) { return material(p); }
    let cd = if d > 0 && moves.len == 1 { d } else { max(d - 1, 0) };
    var best = -100000;
    for i in moves.len { best = max(best, -minimax(rules::play(p, moves[i]), cd, h - 1)); }
    return best;
}

fn same(a: rules::Move&, b: rules::Move&) -> bool { a.from == b.from && a.to == b.to && a.captured == b.captured }

fn main() {
    var e = ai::Engine { .. };
    ai::init(e);
    // Hard thinks with far fewer nodes than in play, to keep the test quick: this tests
    // the choosing, not the strength.
    e.node_limit = 4000;
    var moves: rules::Moves = [];
    let tested: u8[3] = [rules::RUSSIAN, rules::INTERNATIONAL, rules::BRAZILIAN];
    for variant in tested {
        var positions = 0;
        var checked: i64[COUNT] = [0; COUNT];
        var hangs:   i64[COUNT] = [0; COUNT];
        var overlooks = 0;          // moves at skill 0 that overlooked something
        var overlooked = 0;         // and of them, those that hung a piece
        var sacrifices = 0;
        var gifts = 0;
        for game in 3 {
            var p = rules::start(variant);
            for ply in 40 {
                rules::generate(p, moves);
                guard moves.len > 0 else { break; }
                if moves.len >= 2 {
                    positions += 1;
                    var value: i64[rules::MAX_MOVES] = [0; rules::MAX_MOVES];
                    var best = -100000;
                    for i in moves.len {
                        value[i] = -minimax(rules::play(p, moves[i]), 0, 4);
                        best = max(best, value[i]);
                    }
                    for skill, level in SKILLS {
                        for k in SEEDS {
                            let seed = (positions * SEEDS + k) as u64;
                            let m = ai::think(e, p, skill, seed);
                            checked[level] += 1;
                            if e.gifted { gifts += 1; }
                            let missed = e.overlook != 0;
                            if missed { overlooks += 1; }
                            var i = 0;
                            while !same(moves[i], m) { i += 1; }
                            guard value[i] <= best - 100 else { continue; }
                            // A sacrifice the level sees win it back is no hang.
                            let pr = ai::params(skill);
                            ai::begin(e, p, pr.depth, pr.extra, pr.margin, e.node_limit);
                            while e.searching { ai::run(e, 1 << 30); }
                            var deep = -ai::INF;
                            for j in moves.len { if e.exact[j] { deep = max(deep, e.score[j]); } }
                            if e.exact[i] && e.score[i] > deep - 100 {
                                sacrifices += 1;
                            } else if missed {
                                overlooked += 1;
                            } else {
                                hangs[level] += 1;
                                var t: u8[>..] = [];
                                rules::format_move(t, variant, m);
                                print("  skill ", skill, " seed ", seed, " hangs in ", rules::fen(p), ": ", t);
                            }
                        }
                    }
                }
                // The games: medium against itself, seeded per game and ply.
                p = rules::play(p, ai::think(e, p, ai::level_skill(ai::MEDIUM), (game * 100 + ply + 7) as u64));
            }
        }
        print(rules::VARIANT_NAMES[variant], ": ", positions,
              " positions; moves checked per skill 0, 15, 40, 90: ", checked[0], ", ", checked[1], ", ", checked[2],
              ", ", checked[3], "; hangs ", hangs[0], ", ", hangs[1], ", ", hangs[2], ", ", hangs[3], "; sacrifices ",
              sacrifices, "; combinations left ", gifts, "; at skill 0, moves overlooking a capture ", overlooks,
              ", of them hanging a piece ", overlooked);
    }
}
