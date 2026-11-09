// Plays the computer against itself at two skills, to check that the levels are
// ordered and to see how often each wins.
//
//   goose build -o build/aimatch tools/aimatch.goose
//   build/aimatch russian|international|brazilian SKILL_A SKILL_B GAMES [--fens PLY] [--nodes A B]
//                 [--overlooks A B] [--hangs]
//
// Each pair of games starts from the same position with colors swapped. A game is
// drawn by the variant's rules (rules/draw.goose), which the engine sees, or after 300
// plies. Prints
// A's wins, draws, and losses. --fens prints the position at ply PLY of each game
// instead, for benchmarks. --nodes gives each side its own node limit. --overlooks gives
// each side its percent of the overlook chances (ai::Engine.overlooks): 0 plays a skill
// below 15 as it played before it overlooked anything, 200 overlooks twice as often.
// --hangs also counts, for each side, its moves (with a choice) in quiet and in tense
// positions and the moves that hung a piece in each: a move after which the opponent's captures
// win a man or more, when another move loses less that way (a minimax over material,
// the move and then captures only, four plies), unless its own search shows the
// material coming back (a sacrifice it sees). Tense: the side to move must capture, or
// the other side could capture were it its turn; quiet: neither.
import std;
import os;
import rules from "../src/rules";
import ai from "../src/ai";

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

// Whether a capture is around p: its side must capture, or the other could.
fn tense(p: rules::Position, moves: rules::Moves&) -> bool {
    guard moves[0].captured == 0 else { return true; }
    var other_moves: rules::Moves = [];
    var other = p;
    other.side = 1 - p.side;
    rules::generate(other, other_moves);
    return other_moves.len > 0 && other_moves[0].captured != 0;
}

// Whether `m` hangs a piece in p at `skill`, as --hangs counts them.
fn hung(e: ai::Engine&, p: rules::Position, moves: rules::Moves&, m: rules::Move, skill: i64) -> bool {
    var value: i64[rules::MAX_MOVES] = [0; rules::MAX_MOVES];
    var best = -100000;
    var chosen = 0;
    for i in moves.len {
        value[i] = -minimax(rules::play(p, moves[i]), 0, 4);
        best = max(best, value[i]);
        if same(moves[i], m) { chosen = i; }
    }
    guard value[chosen] <= best - 100 else { return false; }
    let pr = ai::params(skill);
    ai::begin(e, p, pr.depth, pr.extra, pr.margin, e.node_limit);
    while e.searching { ai::run(e, 1 << 30); }
    var deep = -ai::INF;
    for j in moves.len { if e.exact[j] { deep = max(deep, e.score[j]); } }
    return !(e.exact[chosen] && e.score[chosen] > deep - 100);
}

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
    var hangs = false;
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
            if a[k] == "--hangs" { hangs = true; }
            k += 1;
        }
    }
    if k < a.len && a[k] == "--hangs" { hangs = true; }
    var e = ai::Engine { .. };
    ai::init(e);
    var moves: rules::Moves = [];
    var wins = 0;
    var draws = 0;
    var losses = 0;
    var plies = 0;
    // By side (A, B) and position (quiet, tense): moves with a choice, men hung.
    var chances:    i64[4] = [0; 4];
    var hung_moves: i64[4] = [0; 4];
    for g in games {
        // A plays white in even games.
        let a_side: u8 = if g % 2 == 0 { rules::WHITE } else { rules::BLACK };
        var p = rules::start(variant);
        var past = rules::Past { draw: rules::draw_start(p), before: [] };
        var result = 0;
        for ply in 300 {
            if ply == fens_at { print(rules::fen(p)); }
            rules::generate(p, moves);
            if moves.len == 0 {
                result = if p.side == a_side { -1 } else { 1 };
                break;
            }
            guard rules::draw_reason(past.draw, p) == rules::NO_DRAW else { break; }
            let skill = if p.side == a_side { sa } else { sb };
            e.node_limit = if p.side == a_side { limit_a } else { limit_b };
            e.overlooks = if p.side == a_side { overlooks_a } else { overlooks_b };
            // Pairs of games share seeds, so both colors meet the same choices.
            let seed = ((g / 2) * 1000 + ply) as u64;
            let m = ai::think_after(e, past, p, skill, seed);
            if hangs && moves.len >= 2 {
                let at = (if p.side == a_side { 0 } else { 2 }) + (if tense(p, moves) { 1 } else { 0 });
                chances[at] += 1;
                if hung(e, p, moves, m, skill) { hung_moves[at] += 1; }
            }
            let q = rules::play(p, m);
            rules::pass(past, p, m, q);
            p = q;
            plies += 1;
        }
        if result > 0 { wins += 1; } else if result < 0 { losses += 1; } else { draws += 1; }
    }
    if fens_at < 0 {
        print("skill ", sa, " against ", sb, ": ", wins, " won, ", draws, " drawn, ", losses,
              " lost, ", plies / max(games, 1), " plies a game");
    }
    if hangs {
        for side in 2 {
            let q = side * 2;
            let skill = if side == 0 { sa } else { sb };
            print("  skill ", skill, ": quiet moves ", chances[q], ", hanging ", hung_moves[q], "; tense moves ",
                  chances[q + 1], ", hanging ", hung_moves[q + 1], "; hangs per 100 games ", hung_moves[q] * 100 / max(games, 1), " quiet, ",
                  hung_moves[q + 1] * 100 / max(games, 1), " tense");
        }
    }
}
