// Checks the puzzles (docs/architecture/puzzles.md, "Checks"), and helps compose them.
//
//   goose build -o build/puzzles tools/puzzles.goose
//   build/puzzles [FILE]                     every puzzle in FILE (puzzles/international.txt)
//   build/puzzles try VARIANT FEN GOAL MOVES the moves that reach GOAL (take N, crown,
//                                            win, safe) within MOVES moves, and how many
//
// For each puzzle it prints its tier, goal, pieces, the moves that solve it, and what the
// checks found (puzzles::check); then the computer player at full skill: its root scores,
// and whether the moves it rates best all solve the puzzle, which a second engine
// sharing only the rules with the solver confirms. The positions searched show how much
// a puzzle costs the screen's checks.
import std;
import os;
import rules from "../rules";
import ai from "../ai";
import puzzles from "../puzzles";

// The computer's view of p: its best move, and every move it scores within `margin` of
// that, appended to out; whether each of those solves the puzzle.
fn engine(e: ai::Engine&, s: puzzles::Solver&, pz: puzzles::Puzzle&, out: u8[>..]&) -> bool {
    e.node_limit = 4000000;
    let best = ai::think(e, pz.start, 100, 1);
    var moves: rules::Moves = [];
    if e.moves.len == 1 {
        out.append("  engine: one legal move\n");
        return true;
    }
    var all_right = true;
    var top = -1000000;
    for i in e.moves.len { if e.main_exact[i] { top = max(top, e.main_score[i]); } }
    out.append("  engine:");
    for i in e.moves.len {
        guard e.main_exact[i] && e.main_score[i] >= top - 50 else { continue; }
        let m = puzzles::short(e.moves[i]);
        let right = puzzles::judge(s, pz.start, m, pz.moves) != puzzles::WRONG;
        if !right { all_right = false; }
        out.append(" ");
        puzzles::move_text(out, pz.start, m, moves);
        format(out, " ", e.main_score[i], if right { "" } else { " (doesn't solve it)" });
    }
    out.append("; plays ");
    puzzles::move_text(out, pz.start, puzzles::short(best), moves);
    out.append("\n");
    return all_right;
}

fn check_file(path: const u8[:]) {
    var text: u8[>..] = [];
    if path.len > 0 {
        guard read_file(path, text) else { abort(str("can't read ", path)); }
    } else {
        text.append(puzzles::file());
    }
    var set = puzzles::Set { list: [] };
    var err: u8[>..] = [];
    guard puzzles::parse(text, set, err) else { abort(err); }
    var s = puzzles::Solver { moves: [], stack: [] };
    var e = ai::Engine { .. };
    ai::init(e);
    var problems = 0;
    var engine_off = 0;
    var counts: i64[4] = [0, 0, 0, 0];
    for pz in set.list {
        var out:  u8[>..] = [];
        var ways: u8[>..] = [];
        s.nodes = 0;
        let start = time();
        let n = puzzles::check(s, pz, out, ways);
        let ms = (time() - start) * 1000.0;
        problems += n;
        counts[pz.tier]++;
        var goal: u8[>..] = [];
        goal.append(puzzles::GOAL_NAMES[pz.goal]);
        if pz.goal == puzzles::TAKE { format(goal, " ", pz.count); }
        var cost: u8[>..] = [];
        format_flt(cost, ms, 1);
        print(pz.id, ": tier ", pz.tier, ", ", goal, " in ", pz.moves, ", ", puzzles::pieces(pz.start), " pieces; ",
              if n == 0 { "ok" } else { "PROBLEMS" }, "; solved by ", ways, " (", s.nodes, " positions, ", cost,
              " ms)");
        if n > 0 { print(out); }
        var view: u8[>..] = [];
        // The engine plays for material, so a king made is no aim of its own.
        if !engine(e, s, pz, view) && pz.goal != puzzles::CROWN { engine_off++; }
        print(view);
    }
    print(set.list.len, " puzzles: tier 1 ", counts[1], ", tier 2 ", counts[2], ", tier 3 ", counts[3], "; ", problems,
          " problems; the engine's best doesn't solve ", engine_off, " (crowning aside)");
}

// A puzzle of position p with a goal as the file writes it ("take 2") in k moves.
fn puzzle_of(p: rules::Position, goal: const u8[:], k: i64) -> puzzles::Puzzle {
    let g, count, ok = puzzles::parse_goal(goal);
    guard ok else { abort(str("not a goal: ", goal)); }
    return puzzles::Puzzle { id: 1, tier: 1, goal: g, count: count, start: p, moves: k, lines: [], told: true };
}

// The moves of p that are right, appended to out; returns how many.
fn right_moves(s: puzzles::Solver&, p: rules::Position, k: i64, out: u8[>..]&) -> i64 {
    var legal: rules::Moves = [];
    rules::generate(p, legal);
    var n = 0;
    for m in legal {
        guard puzzles::judge(s, p, puzzles::short(m), k) != puzzles::WRONG else { continue; }
        out.append(" ");
        rules::format_move(out, p.variant, m);
        n++;
    }
    return n;
}

fn try_position(fen: const u8[:], goal: const u8[:], moves: const u8[:]) {
    let k, ok = parse_int(moves);
    guard ok && k >= 1 else { abort("MOVES is a number"); }
    let p, fen_ok = rules::parse_fen(fen, rules::INTERNATIONAL);
    guard fen_ok else { abort("not a position"); }
    var pz = puzzle_of(p, goal, k);
    var s = puzzles::Solver { moves: [], stack: [] };
    puzzles::begin(s, pz);
    var shown: u8[>..] = [];
    right_moves(s, p, k, shown);
    print("solved within ", k, " by:", shown, "; needs ", puzzles::need(s, p, k), "; ", s.nodes, " positions");
    if pz.goal == puzzles::SAFE {
        // What each move loses with best play.
        var each: u8[>..]      = [];
        var all:  rules::Moves = [];
        rules::generate(p, all);
        for m in all {
            rules::format_move(each, p.variant, m);
            format(each, " ", puzzles::value(s, rules::play(p, m), puzzles::SAFE_DEPTH, -2000, 2000), "; ");
        }
        print("each: ", each);
    }
    // A line as the screen would play it: the first right move, the hardest reply.
    var line:  u8[>..]      = [];
    var legal: rules::Moves = [];
    var q = p;
    for left in 0..k {
        let i = puzzles::right_move(s, q, k - left);
        guard i >= 0 else { break; }
        rules::generate(q, legal);
        let m = legal[i];
        let solved = puzzles::judge(s, q, puzzles::short(m), k - left) == puzzles::SOLVED;
        if line.len > 0 { line.append(" "); }
        rules::format_move(line, q.variant, m);
        q = rules::play(q, m);
        guard !solved else { break; }
        let j = puzzles::reply(s, q, k - left - 1);
        guard j >= 0 else { break; }
        rules::generate(q, legal);
        line.append(" ");
        rules::format_move(line, q.variant, legal[j]);
        q = rules::play(q, legal[j]);
    }
    print("line ", line);
}

// Random positions of `white` and `black` men, white to move with no capture due, which
// exactly one first move solves in `k` moves and none in fewer: candidates to compose
// from, printed `count` of them.
fn find(goal: const u8[:], k: i64, white: i64, black: i64, count: i64, seed: u64) {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    var r = rng { seed };
    var s = puzzles::Solver { moves: [], stack: [] };
    var legal: rules::Moves = [];
    var found = 0;
    var tries = 0;
    while found < count && tries < 2000000 {
        tries++;
        var p = rules::Position { pieces: [0, 0], kings: 0, side: rules::WHITE, variant: rules::INTERNATIONAL };
        for side in 2 {
            var placed = 0;
            while placed < (if side == 0 { white } else { black }) {
                // White's men on rows 1 to 6, black's on 5 to 10, as in a game.
                let y = if side == 0 { rand_int(r, 6) } else { 4 + rand_int(r, 6) };
                let x = rand_int(r, 10);
                let b = rules::bit_at(v, x, y);
                guard b >= 0 && (p.pieces[0] | p.pieces[1]) & rules::bit(b) == 0 else { continue; }
                p.pieces[side] |= rules::bit(b);
                placed++;
            }
        }
        rules::generate(p, legal);
        guard legal.len >= 3 && legal[0].captured == 0 else { continue; }
        // Black has no capture either, were it to move; for the safe move it has, so a
        // man is in danger that one move alone saves.
        var q = p;
        q.side = rules::BLACK;
        rules::generate(q, legal);
        var pz = puzzle_of(p, goal, k);
        guard legal.len > 0 && (legal[0].captured != 0) == (pz.goal == puzzles::SAFE) else { continue; }
        puzzles::begin(s, pz);
        guard puzzles::wins(s, p, k) && (k == 1 || !puzzles::wins(s, p, k - 1)) else { continue; }
        var shown: u8[>..] = [];
        guard right_moves(s, p, k, shown) == 1 else { continue; }
        // A shot: every reply to the first move is a capture.
        if k > 1 {
            let first = puzzles::right_move(s, p, k);
            rules::generate(p, legal);
            var q2 = rules::play(p, legal[first]);
            rules::generate(q2, legal);
            guard legal.len > 0 && legal[0].captured != 0 else { continue; }
        }
        print(rules::fen(p), " ", goal, " in ", k, ":", shown);
        found++;
    }
}

fn main() {
    let argv = args();
    if argv.len >= 5 && argv[1] == "try" {
        try_position(argv[2], argv[3], argv[4]);
        return;
    }
    if argv.len >= 7 && argv[1] == "find" {
        let k, ok_k = parse_int(argv[3]);
        let w, ok_w = parse_int(argv[4]);
        let b, ok_b = parse_int(argv[5]);
        let n, ok_n = parse_int(argv[6]);
        let seed, ok_s = parse_int(if argv.len >= 8 { argv[7] } else { "1" });
        guard ok_k && ok_w && ok_b && ok_n && ok_s else { abort("find GOAL MOVES WHITE BLACK COUNT [SEED]"); }
        find(argv[2], k, w, b, n, seed as u64);
        return;
    }
    check_file(if argv.len >= 2 { argv[1] } else { "" });
}
