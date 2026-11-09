// Checks the puzzles (docs/architecture/puzzles.md, "Checks"), and helps compose them.
//
//   goose build -o build/puzzles tools/puzzles.goose
//   build/puzzles [FILE]                     every puzzle in FILE (the variant's built-in set)
//   build/puzzles try FEN GOAL MOVES         the moves that reach GOAL (take N, crown, win,
//                                            safe) within MOVES moves, how many, the line
//                                            the screen would play, and what the checks
//                                            say of a puzzle made of that line
//   build/puzzles find SIDE GOAL MOVES MINE THEIRS COUNT [SEED [KINGS [CORE]]]
//                                            game-like positions that make a puzzle: see find
//
// try and find take `--variant NAME` (international by default; russian, brazilian) for
// the rules and the board, and find `--rows N`, the rows from its own back row a side's
// camp spans (the board's size less 3 by default: 7 of 10, 5 of 8), and `--tempo`: a take
// in more moves starts with a free tempo, a quiet move no reply captures after, rather
// than a shot.
//
// For each puzzle it prints its theme, level, goal, pieces, the moves that solve it, and
// what the checks found (puzzles::check), and the moves it turns down that win as much
// a move later (puzzles::rivals); then the computer player at full skill: its
// root scores, whether the moves it rates best all solve the puzzle, which a second
// engine sharing only the rules with the solver confirms, and whether it scores a right
// first move as losing material. The positions searched show how much a puzzle costs the
// screen's checks.
import std;
import os;
import rules from "../src/rules";
import ai from "../src/ai";
import puzzles from "../src/puzzles";

let LOSING = -50;           // a root score this far under even loses material (a man is about 100)

// The variant try and find work in, and the rows a camp spans (0: the board's size less 3).
var variant: u8 = rules::INTERNATIONAL;
var camp_rows = 0;
var tempo = false;          // find: a take in more moves starts with a quiet move, not a shot

// The computer's view of pz: its best move, and every move it scores within 50 of that,
// appended to out, each marked if it doesn't solve the puzzle; then any right first
// move it scores as losing material. Returns whether its best all solve it, and how
// many right first moves it scores as losing.
fn engine(e: ai::Engine&, s: puzzles::Solver&, pz: puzzles::Puzzle&, out: u8[>..]&) -> bool, i64 {
    e.node_limit = 4000000;
    let best = ai::think(e, pz.start, 100, 1);
    var moves: rules::Moves = [];
    if e.moves.len == 1 {
        out.append("  engine: one legal move\n");
        return true, 0;
    }
    var all_right = true;
    var top = -1000000;
    for i in e.moves.len { if e.main_exact[i] { top = max(top, e.main_score[i]); } }
    out.append("  engine:");
    var losing = 0;
    var lost: u8[>..] = [];
    for i in e.moves.len {
        let m = puzzles::short(e.moves[i]);
        let right = puzzles::judge(s, pz.start, m, pz.moves) != puzzles::WRONG;
        if right && e.main_exact[i] && e.main_score[i] < LOSING {
            losing++;
            lost.append(" ");
            puzzles::move_text(lost, pz.start, m, moves);
            format(lost, " ", e.main_score[i]);
        }
        guard e.main_exact[i] && e.main_score[i] >= top - 50 else { continue; }
        if !right { all_right = false; }
        out.append(" ");
        puzzles::move_text(out, pz.start, m, moves);
        format(out, " ", e.main_score[i], if right { "" } else { " (doesn't solve it)" });
    }
    out.append("; plays ");
    puzzles::move_text(out, pz.start, puzzles::short(best), moves);
    out.append("\n");
    if losing > 0 { format(out, "  engine scores a right move as losing:", lost, "\n"); }
    return all_right, losing;
}

fn goal_text(pz: puzzles::Puzzle&) -> u8[>..] {
    var goal: u8[>..] = [];
    goal.append(puzzles::GOAL_NAMES[pz.goal]);
    if pz.goal == puzzles::TAKE { format(goal, " ", pz.count); }
    return goal;
}

fn check_file(path: const u8[:]) {
    var text: u8[>..] = [];
    if path.len > 0 {
        guard read_file(path, text) else { abort(str("can't read ", path)); }
    } else {
        text.append(puzzles::file(variant));
    }
    var set = puzzles::Set { list: [] };
    var err: u8[>..] = [];
    guard puzzles::parse(text, set, err) else { abort(err); }
    var s = puzzles::Solver { moves: [], stack: [] };
    var e = ai::Engine { .. };
    ai::init(e);
    var problems = 0;
    var engine_off = 0;
    var engine_losing = 0;
    var black = 0;
    var most = 0;
    var rivals = 0;
    var counts: i64[puzzles::THEMES * (puzzles::LEVELS + 1)] = [0; puzzles::THEMES * (puzzles::LEVELS + 1)];
    for pz in set.list {
        var out:  u8[>..] = [];
        var ways: u8[>..] = [];
        s.nodes = 0;
        let start = time();
        let n = puzzles::check(s, pz, out, ways);
        let ms = (time() - start) * 1000.0;
        problems += n;
        most = max(most, s.nodes);
        counts[pz.theme * (puzzles::LEVELS + 1) + pz.level]++;
        if pz.start.side == rules::BLACK { black++; }
        var cost: u8[>..] = [];
        format_flt(cost, ms, 1);
        print(pz.id, ": ", puzzles::THEME_NAMES[pz.theme], " ", pz.level, ", ",
              if pz.start.side == rules::BLACK { "black" } else { "white" }, ", ", goal_text(pz), " in ", pz.moves, ", ",
              puzzles::pieces(pz.start), " pieces; ", if n == 0 { "ok" } else { "PROBLEMS" }, "; solved by ", ways, " (",
              s.nodes, " positions, ", cost, " ms)");
        if n > 0 { print(out); }
        var won: u8[>..] = [];
        let r = puzzles::rivals(s, pz, won);
        rivals += r;
        if r > 0 { print("  wins as much a move later: ", won); }
        var view: u8[>..] = [];
        let agrees, losing = engine(e, s, pz, view);
        // The engine plays for material, so a king made is no aim of its own.
        if !agrees && pz.goal != puzzles::CROWN { engine_off++; }
        engine_losing += losing;
        print(view);
    }
    var per: u8[>..] = [];
    for t in puzzles::THEMES {
        format(per, "\n  ", puzzles::THEME_NAMES[t], ":");
        for l in 1..puzzles::LEVELS + 1 { format(per, " ", counts[t * (puzzles::LEVELS + 1) + l]); }
    }
    print(set.list.len, " puzzles, ", black, " black to move; by theme, levels 1 to 3:", per);
    print(problems, " problems; the engine's best doesn't solve ", engine_off, " (crowning aside); it scores ",
          engine_losing, " right first moves as losing; at most ", most, " positions a check");
    print("moves turned down that win as much a move later: ", rivals);
}

// A puzzle of position p with a goal as the file writes it ("take 2") in k moves.
fn puzzle_of(p: rules::Position, goal: const u8[:], k: i64) -> puzzles::Puzzle {
    let g, count, ok = puzzles::parse_goal(goal);
    guard ok else { abort(str("not a goal: ", goal)); }
    return puzzles::Puzzle { id: 1, theme: 0, level: 1, goal: g, count: count, start: p, moves: k, lines: [],
                             told: true };
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

// The line the screen would play in pz, the first right move and the hardest reply each
// time, written to out and set as pz's one line; whether it reaches the goal.
fn screen_line(s: puzzles::Solver&, pz: puzzles::Puzzle&, out: u8[>..]&) -> bool {
    let k = pz.moves;
    var legal: rules::Moves = [];
    var q = pz.start;
    pz.lines.clear();
    let line .= pz.lines.push(puzzles::Line { plies: [] });
    puzzles::begin(s, pz);
    for left in 0..k {
        let i = puzzles::right_move(s, q, k - left);
        guard i >= 0 else { return false; }
        rules::generate(q, legal);
        let m = legal[i];
        let solved = puzzles::judge(s, q, puzzles::short(m), k - left) == puzzles::SOLVED;
        if out.len > 0 { out.append(" "); }
        rules::format_move(out, q.variant, m);
        line.plies.push(puzzles::Ply { from: m.from, to: m.to, captured: m.captured });
        q = rules::play(q, m);
        guard !solved else { return true; }
        let j = puzzles::reply(s, q, k - left - 1);
        guard j >= 0 else { return false; }
        rules::generate(q, legal);
        out.append(" ");
        rules::format_move(out, q.variant, legal[j]);
        line.plies.push(puzzles::Ply { from: legal[j].from, to: legal[j].to, captured: legal[j].captured });
        q = rules::play(q, legal[j]);
    }
    return false;
}

fn try_position(fen: const u8[:], goal: const u8[:], moves: const u8[:]) {
    let k, ok = parse_int(moves);
    guard ok && k >= 1 else { abort("MOVES is a number"); }
    let p, fen_ok = rules::parse_fen(fen, variant);
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
    var line: u8[>..] = [];
    let reached = screen_line(s, pz, line);
    print("line ", line);
    guard reached else { return; }
    var out:  u8[>..] = [];
    var ways: u8[>..] = [];
    let n = puzzles::check(s, pz, out, ways);
    print("checks: ", n, " problems");
    if n > 0 { print(out); }
}

// Places `n` men of `side` in a camp, as in a game: the first on its half's front rows,
// each next one beside or behind one already placed (a diagonal neighbor on its own side
// of it), within `camp_rows` of its own back row (7 of 10, 5 of 8 by default). Kings are
// made of the first `kings` placed.
fn camp(p: rules::Position&, r: rng&, side: i64, n: i64, kings: i64) {
    let v .= rules::VARIANTS[variant];
    let rows = if camp_rows > 0 { min(camp_rows, v.size) } else { v.size - 3 };
    var placed = 0;
    var tries = 0;
    while placed < n && tries < 10000 {
        tries++;
        let x = rand_int(r, v.size);
        // Rows from white's side: white's from its back row up, black's down from the top.
        let y = if side == rules::WHITE { rand_int(r, rows) } else { v.size - rows + rand_int(r, rows) };
        let b = rules::bit_at(v, x, y);
        guard b >= 0 && (p.pieces[0] | p.pieces[1]) & rules::bit(b) == 0 else { continue; }
        if placed > 0 {
            // Next to one of its own, a step toward its own back row or beside.
            let back = if side == rules::WHITE { -1 } else { 1 };
            var near = false;
            for dx in [-1, 1] {
                for dy in [back, -back] {
                    let nb = rules::bit_at(v, x + dx, y + dy);
                    if nb >= 0 && p.pieces[side] & rules::bit(nb) != 0 { near = true; }
                }
            }
            guard near || rand_int(r, 4) == 0 else { continue; }
        }
        p.pieces[side] |= rules::bit(b);
        if placed < kings { p.kings |= rules::bit(b); }
        placed++;
    }
}

// The position turned round: each square to its opposite, the colors swapped, so a
// puzzle found for white is one for black.
fn turned(p: rules::Position) -> rules::Position {
    let v .= rules::VARIANTS[p.variant];
    let last = v.size * v.h;
    var q = rules::Position { pieces: [0, 0], kings: 0, side: 1 - p.side, variant: p.variant };
    for n in 1..last + 1 {
        let b = rules::bit(v.bit_of[n]);
        let to = rules::bit(v.bit_of[last + 1 - n]);
        for side in 2 { if p.pieces[side] & b != 0 { q.pieces[1 - side] |= to; } }
        if p.kings & b != 0 { q.kings |= to; }
    }
    return q;
}

// Game-like positions, `mine` men of the solver and `theirs` of the other side in camps
// (camp), `kings` of the solver's made kings, which exactly one move solves at each of
// the solver's turns within `k` moves and not fewer, ending quiet, as puzzles::check
// asks; printed `count` of them with their line, for SIDE to move. A take in more moves
// is a shot: it starts with no capture due and every reply to its first move is a
// capture; a one-move take has a capture due. Each has two moves at least to choose
// from. The other side has no capture were it to move; for the safe move it has a shot
// (puzzles::shot), the threat the move answers, and the solver has no capture due. The
// men of `core`, a motif's skeleton written for white, stand in every position, the
// camps filled round them.
fn find(side: i64, goal: const u8[:], k: i64, mine: i64, theirs: i64, count: i64, seed: u64, kings: i64,
        core: rules::Position) {
    var r = rng { seed };
    var s = puzzles::Solver { moves: [], stack: [] };
    var legal: rules::Moves = [];
    var found = 0;
    var tries = 0;
    while found < count && tries < 2000000 {
        tries++;
        var p = core;
        p.side = rules::WHITE;
        p.variant = variant;
        camp(p, r, rules::WHITE, mine - popcount(core.pieces[0]), kings);
        camp(p, r, rules::BLACK, theirs - popcount(core.pieces[1]), 0);
        guard popcount(p.pieces[0]) == mine && popcount(p.pieces[1]) == theirs else { continue; }
        // No white man on black's back row, which would have crowned.
        guard p.pieces[0] & ~p.kings & rules::VARIANTS[variant].promotion[0] == 0 else { continue; }
        rules::generate(p, legal);
        var pz = puzzle_of(p, goal, k);
        let take = pz.goal == puzzles::TAKE;
        let safe = pz.goal == puzzles::SAFE;
        guard legal.len >= 2 && (!take || (legal[0].captured != 0) == (k == 1)) && (!safe || legal[0].captured == 0)
        else { continue; }
        var q = p;
        q.side = rules::BLACK;
        rules::generate(q, legal);
        guard legal.len > 0 && legal[0].captured == 0 else { continue; }
        puzzles::begin(s, pz);
        // The threat a safe move answers: were the other side to move, it would have a shot.
        guard !safe || puzzles::shot(s, q, puzzles::SAFE_DEPTH) else { continue; }
        guard puzzles::wins(s, p, k) && (k == 1 || !puzzles::wins(s, p, k - 1)) else { continue; }
        var line: u8[>..] = [];
        guard screen_line(s, pz, line) else { continue; }
        if take && k > 1 {
            // A shot: every reply to the first move is a capture.
            var p1 = p;
            rules::generate(p, legal);
            for m in legal {
                if m.from == pz.lines[0].plies[0].from && m.to == pz.lines[0].plies[0].to { p1 = rules::play(p, m); }
            }
            rules::generate(p1, legal);
            // Or, with --tempo, a free tempo: no reply is a capture, and each gives men.
            guard legal.len > 0 && (legal[0].captured != 0) != tempo else { continue; }
        }
        var out:  u8[>..] = [];
        var ways: u8[>..] = [];
        guard puzzles::check(s, pz, out, ways) == 0 else { continue; }
        // The game goes on after the line: a goal reached by leaving no move is a win.
        var end = p;
        for ply in pz.lines[0].plies { end = puzzles::after(end, puzzles::as_played(end, ply, legal)); }
        rules::generate(end, legal);
        guard legal.len > 0 else { continue; }
        if side == rules::BLACK {
            // The same puzzle turned round; its line may take another reply, so it is
            // checked again.
            pz.start = turned(p);
            line.clear();
            screen_line(s, pz, line);
            out.clear();
            ways.clear();
            guard puzzles::check(s, pz, out, ways) == 0 else { continue; }
        }
        print(rules::fen(pz.start), " | ", goal, " in ", k, " | ", line);
        found++;
    }
}

fn main() {
    // The flags first, wherever they are; the words left are the command.
    let all = args();
    var argv: u8[..256][>..] = [];
    var i = 0;
    while i < all.len {
        if i + 1 < all.len && all[i] == "--variant" {
            var known = false;
            for name, k in puzzles::VARIANT_NAMES { if all[i + 1] == name { variant = k as u8; known = true; } }
            guard known else { abort(str("not a variant: ", all[i + 1])); }
            i += 2;
            continue;
        }
        if all[i] == "--tempo" {
            tempo = true;
            i++;
            continue;
        }
        if i + 1 < all.len && all[i] == "--rows" {
            let n, ok = parse_int(all[i + 1]);
            guard ok && n >= 1 else { abort("--rows takes a number"); }
            camp_rows = n;
            i += 2;
            continue;
        }
        argv.push(all[i]);
        i++;
    }
    if argv.len >= 5 && argv[1] == "try" {
        try_position(argv[2], argv[3], argv[4]);
        return;
    }
    if argv.len >= 8 && argv[1] == "find" {
        let k, ok_k = parse_int(argv[4]);
        let w, ok_w = parse_int(argv[5]);
        let b, ok_b = parse_int(argv[6]);
        let n, ok_n = parse_int(argv[7]);
        let seed, ok_s = parse_int(if argv.len >= 9 { argv[8] } else { "1" });
        let kings, ok_kings = parse_int(if argv.len >= 10 { argv[9] } else { "0" });
        let side = if argv[2] == "black" { rules::BLACK } else { rules::WHITE };
        let core, ok_core = rules::parse_fen(if argv.len >= 11 { argv[10] } else { "W:W:B" }, variant);
        guard ok_k && ok_w && ok_b && ok_n && ok_s && ok_kings && ok_core && (argv[2] == "white" || argv[2] == "black")
        else { abort("find SIDE GOAL MOVES MINE THEIRS COUNT [SEED [KINGS [CORE]]]"); }
        find(side, argv[3], k, w, b, n, seed as u64, kings, core);
        return;
    }
    check_file(if argv.len >= 2 { argv[1] } else { "" });
}
