// Checks the puzzles (docs/architecture/puzzles.md, "Checks"), and helps compose them.
//
//   goose build -o build/puzzles tools/puzzles.goose
//   build/puzzles [FILE]                     every puzzle in FILE (the variant's built-in set)
//   build/puzzles try FEN GOAL MOVES [LINE]  the moves that reach GOAL (take N, crown, win,
//                                            safe) within MOVES moves, how many, the line
//                                            the screen would play, after LINE's moves
//                                            ("a5:c7 h6-g5") if given, and what the
//                                            checks say of a puzzle made of that line
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
// time, written to out and set as pz's one line; whether it reaches the goal. The moves
// in `given` (PDN, the solver's and the replies, from the start) are played first.
fn screen_line(s: puzzles::Solver&, pz: puzzles::Puzzle&, out: u8[>..]&, given: const u8[:] = "") -> bool {
    let k = pz.moves;
    var legal: rules::Moves = [];
    var q = pz.start;
    pz.lines.clear();
    let line .= pz.lines.push(puzzles::Line { plies: [] });
    puzzles::begin(s, pz);
    var words: u8[..64][..2 * puzzles::MAX_PLIES] = [];
    for w in split(given, ' ') { if w.len > 0 && w.len <= 64 && words.len < 2 * puzzles::MAX_PLIES { words.push(w); } }
    var next = 0;
    for left in 0..k {
        var i = puzzles::right_move(s, q, k - left);
        if next < words.len {
            let ply, ok = puzzles::parse_move(q, words[next], legal);
            guard ok else { abort(str("not a legal move here: ", words[next])); }
            i = puzzles::index_of(q, ply, legal);
            next++;
        }
        guard i >= 0 else { return false; }
        rules::generate(q, legal);
        let m = legal[i];
        let solved = puzzles::judge(s, q, puzzles::short(m), k - left) == puzzles::SOLVED;
        if out.len > 0 { out.append(" "); }
        rules::format_move(out, q.variant, m);
        line.plies.push(puzzles::Ply { from: m.from, to: m.to, captured: m.captured });
        q = rules::play(q, m);
        guard !solved else { return true; }
        var j = puzzles::reply(s, q, k - left - 1);
        if next < words.len {
            let ply, ok = puzzles::parse_move(q, words[next], legal);
            guard ok else { abort(str("not a legal move here: ", words[next])); }
            j = puzzles::index_of(q, ply, legal);
            next++;
        }
        guard j >= 0 else { return false; }
        rules::generate(q, legal);
        out.append(" ");
        rules::format_move(out, q.variant, legal[j]);
        line.plies.push(puzzles::Ply { from: legal[j].from, to: legal[j].to, captured: legal[j].captured });
        q = rules::play(q, legal[j]);
    }
    return false;
}

fn try_position(fen: const u8[:], goal: const u8[:], moves: const u8[:], given: const u8[:]) {
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
    let reached = screen_line(s, pz, line, given);
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
    var found = 0;
    var tries = 0;
    var st = Stages { .. };
    while found < count && tries < 2000000 {
        tries++;
        let p = placed(r, mine, theirs, kings, core);
        var pz = puzzle_of(p, goal, k);
        var line: u8[>..] = [];
        guard candidate(s, pz, line, st, if tempo { TEMPO } else { SHOT }) else { continue; }
        var black: u8[>..] = [];
        if side == rules::BLACK { guard turn(s, pz, black) else { continue; } }
        let shown: const u8[:] = if side == rules::BLACK { black[..] } else { line[..] };
        print(rules::fen(pz.start), " | ", goal, " in ", k, " | ", shown);
        found++;
    }
}

// A game-like position for find: the solver's `mine` men in a camp, white to move,
// `kings` of them made kings, and the other side's `theirs`, round core's men; its
// piece counts short when the camps had no room.
fn placed(r: rng&, mine: i64, theirs: i64, kings: i64, core: rules::Position) -> rules::Position {
    var p = core;
    p.side = rules::WHITE;
    p.variant = variant;
    camp(p, r, rules::WHITE, mine - popcount(core.pieces[0]), kings);
    camp(p, r, rules::BLACK, theirs - popcount(core.pieces[1]), 0);
    return p;
}

// How far positions get through candidate's filters, for the pass rates.
struct Stages {
    tried:  i64 = 0,            // positions looked at
    cheap:  i64 = 0,            // past the cheap guards: moves to choose from, no capture for the other side
    solved: i64 = 0,            // the goal forced in k and not fewer
    shaped: i64 = 0,            // a line the screen plays, of the shape asked
    sound:  i64 = 0,            // every check passed
}

// What a take in more moves must start with (candidate).
let SHOT = 0;               // every reply to the first move is a capture
let TEMPO = 1;              // no reply is a capture, and each gives men
let EITHER = 2;             // any quiet first move (positions from games)

// Whether pz, its start, goal, and moves set, makes a puzzle: exactly one right move at
// each of the solver's turns within its moves and not fewer, every check passed
// (puzzles::check), ending quiet, and the game going on after the line. A take in
// more moves starts as `first` says; a one-move take has a capture due. Each has two
// moves at least to choose from. The other side has no capture were it to move; for the
// safe move it has a shot (puzzles::shot), the threat the move answers, and the solver
// has no capture due. Sets pz's one line, its text in `line`, and counts in st how far
// it got.
fn candidate(s: puzzles::Solver&, pz: puzzles::Puzzle&, line: u8[>..]&, st: Stages&, first: i64) -> bool {
    let p = pz.start;
    let k = pz.moves;
    var legal: rules::Moves = [];
    st.tried++;
    // No man on the far row, which would have crowned.
    let v .= rules::VARIANTS[p.variant];
    guard p.pieces[0] & ~p.kings & v.promotion[0] == 0 && p.pieces[1] & ~p.kings & v.promotion[1] == 0
    else { return false; }
    rules::generate(p, legal);
    let take = pz.goal == puzzles::TAKE;
    let safe = pz.goal == puzzles::SAFE;
    guard legal.len >= 2 && (!take || (legal[0].captured != 0) == (k == 1)) && (!safe || legal[0].captured == 0)
    else { return false; }
    var q = p;
    q.side = 1 - p.side;
    rules::generate(q, legal);
    guard legal.len > 0 && legal[0].captured == 0 else { return false; }
    st.cheap++;
    puzzles::begin(s, pz);
    // The threat a safe move answers: were the other side to move, it would have a shot.
    guard !safe || puzzles::shot(s, q, puzzles::SAFE_DEPTH) else { return false; }
    guard puzzles::wins(s, p, k) && (k == 1 || !puzzles::wins(s, p, k - 1)) else { return false; }
    st.solved++;
    guard screen_line(s, pz, line) else { return false; }
    if take && k > 1 && first != EITHER {
        // A shot: every reply to the first move is a capture; or a free tempo: none is,
        // and each gives men.
        let p1 = puzzles::after(p, puzzles::as_played(p, pz.lines[0].plies[0], legal));
        rules::generate(p1, legal);
        guard legal.len > 0 && (legal[0].captured != 0) == (first == SHOT) else { return false; }
    }
    st.shaped++;
    var out:  u8[>..] = [];
    var ways: u8[>..] = [];
    guard puzzles::check(s, pz, out, ways) == 0 else { return false; }
    // The game goes on after the line: a goal reached by leaving no move is a win.
    var end = p;
    for ply in pz.lines[0].plies { end = puzzles::after(end, puzzles::as_played(end, ply, legal)); }
    rules::generate(end, legal);
    guard legal.len > 0 || pz.goal == puzzles::WIN else { return false; }
    st.sound++;
    return true;
}

// pz, found for white, turned round to be black's (turned); its line, written to an
// empty `line`, may take another reply, so it is checked again. Whether it passes.
fn turn(s: puzzles::Solver&, pz: puzzles::Puzzle&, line: u8[>..]&) -> bool {
    pz.start = turned(pz.start);
    guard screen_line(s, pz, line) else { return false; }
    var out:  u8[>..] = [];
    var ways: u8[>..] = [];
    return puzzles::check(s, pz, out, ways) == 0;
}

// What a puzzle's line shows, read off its moves the way lichess-puzzler's tagger reads
// its themes: the men the solver gives (its moves answered by a capture), whether a king
// captures, whether the solver crowns, whether its first move is a capture, and the most
// pieces one capture takes.
struct Shape {
    given:      i64  = 0,
    king:       bool = false,
    crowns:     bool = false,
    capture:    bool = false,
    most:       i64  = 0,
    quiet:      bool = false,   // a quiet first move no reply captures after: a free tempo
    lets_crown: bool = false,   // a reply crowns
}

fn shape_of(pz: puzzles::Puzzle&) -> Shape {
    var sh = Shape { .. };
    var legal: rules::Moves = [];
    var p = pz.start;
    let plies .= pz.lines[0].plies;
    for ply, i in plies {
        let m = puzzles::as_played(p, ply, legal);
        if i % 2 == 0 {
            let n = popcount(m.captured);
            if i == 0 { sh.capture = n > 0; }
            sh.most = max(sh.most, n);
            if n > 0 && p.kings & rules::bit(m.from) != 0 { sh.king = true; }
            if m.crowned { sh.crowns = true; }
        } else if m.captured != 0 {
            sh.given += popcount(m.captured);
            if m.crowned { sh.lets_crown = true; }
        } else if i == 1 && !sh.capture {
            sh.quiet = true;
        }
        if i % 2 == 1 && m.crowned { sh.lets_crown = true; }
        p = puzzles::after(p, m);
    }
    return sh;
}

// The theme and level a found puzzle belongs to, from its goal and its line (Shape), so
// the daily pick can keep to the themes a child has opened: the safe move; crowning;
// the king's captures; a shot (men given, or a free tempo); else a capture to find. A
// variant whose set lacks a theme (Russian's and Brazilian's King shots) takes Shots.
// Levels as the themes' own: a capture's by the pieces it takes, a shot's and a king's
// by its moves and the men given, a crown's by its moves, a safe move's by the moves to
// weigh.
fn motif(pz: puzzles::Puzzle&) -> i64, i64 {
    let sh = shape_of(pz);
    var legal: rules::Moves = [];
    rules::generate(pz.start, legal);
    if pz.goal == puzzles::SAFE { return puzzles::SAFE_MOVE, if legal.len <= 4 { 1 } else if legal.len <= 7 { 2 } else { 3 }; }
    if pz.goal == puzzles::CROWN { return puzzles::CROWNING, clamp(pz.moves, 1, 3); }
    let deep = clamp(pz.moves - 1 + (if sh.given >= 2 { 1 } else { 0 }), 1, 3);
    if sh.king {
        let kings_theme = pz.start.variant == rules::INTERNATIONAL;
        return if kings_theme { puzzles::KING_SHOTS } else { puzzles::SHOTS }, deep;
    }
    if sh.given > 0 || sh.quiet { return puzzles::SHOTS, deep; }
    if pz.goal == puzzles::WIN { return puzzles::SHOTS, 3; }
    return puzzles::CAPTURES, if sh.most <= 2 { 1 } else if sh.most == 3 { 2 } else { 3 };
}

// The keys of the puzzles kept, to keep each once: a position's, and its line's moves'
// (the same shot found in two camps that differ only in men it never touches).
let KEPT = 20000;
var kept: u64[..KEPT];

fn line_key(pz: puzzles::Puzzle&) -> u64 {
    var h: u64 = 0xcbf29ce484222325;
    for ply in pz.lines[0].plies {
        h = (h ^ (ply.from)) * 0x100000001b3;
        h = (h ^ (ply.to)) * 0x100000001b3;
        h = (h ^ ply.captured) * 0x100000001b3;
    }
    return h ^ (pz.start.side);
}

// Whether pz is new: neither its position nor its line kept before; then keeps both.
fn fresh(pz: puzzles::Puzzle&) -> bool {
    let a = ai::key(pz.start);
    let b = line_key(pz);
    for x in kept { if x == a || x == b { return false; } }
    guard kept.len + 2 <= KEPT else { return false; }
    kept.push(a);
    kept.push(b);
    return true;
}

// Keeps the course's puzzles (the variant's built-in set), so none is found again.
fn keep_course() {
    var set = puzzles::Set { list: [] };
    var err: u8[>..] = [];
    guard puzzles::parse(puzzles::file(variant), set, err) else { abort(err); }
    for pz in set.list { fresh(pz); }
}

// A puzzle as the library writes it, one a line: theme and level, goal, position, line,
// and where it came from.
fn entry(pz: puzzles::Puzzle&, line: const u8[:], source: const u8[:]) {
    let theme, level = motif(pz);
    print(puzzles::THEME_NAMES[theme], " ", level, " | ", goal_text(pz), " in ", pz.moves, " | ", rules::fen(pz.start),
          " | ", line, " | ", source);
}

// A kind of puzzle batch looks for: the goal and moves, the men in the camps, kings, and
// how a take in more moves starts.
struct Kind {
    name:   const u8[:],
    goal:   const u8[:],
    k:      i64,
    mine:   i64,
    theirs: i64,
    kings:  i64,
    first:  i64,
    share:  i64,            // batch keeps PER times this many: the hard kinds more, so the library reaches far past the course
}

// The kinds batch runs, easy to hard: more men round a motif make it harder to see, and
// more moves harder to read.
let KINDS: Kind[] = [
    Kind { name: "capture-8", goal: "take 2", k: 1, mine: 8, theirs: 8, kings: 0, first: SHOT, share: 1 },
    Kind { name: "capture-13", goal: "take 3", k: 1, mine: 13, theirs: 13, kings: 0, first: SHOT, share: 1 },
    Kind { name: "shot2-10", goal: "take 2", k: 2, mine: 10, theirs: 10, kings: 0, first: SHOT, share: 1 },
    Kind { name: "shot2-15", goal: "take 2", k: 2, mine: 15, theirs: 15, kings: 0, first: SHOT, share: 3 },
    Kind { name: "shot3-12", goal: "take 3", k: 2, mine: 12, theirs: 12, kings: 0, first: SHOT, share: 3 },
    Kind { name: "shot3m-12", goal: "take 2", k: 3, mine: 12, theirs: 12, kings: 0, first: SHOT, share: 3 },
    Kind { name: "shot3m-14", goal: "take 2", k: 3, mine: 14, theirs: 14, kings: 0, first: SHOT, share: 3 },
    Kind { name: "shot4m-14", goal: "take 2", k: 4, mine: 14, theirs: 14, kings: 0, first: SHOT, share: 3 },
    Kind { name: "shot3t-12", goal: "take 3", k: 3, mine: 12, theirs: 12, kings: 0, first: SHOT, share: 3 },
    Kind { name: "shot4m-12", goal: "take 2", k: 4, mine: 12, theirs: 12, kings: 0, first: SHOT, share: 3 },
    Kind { name: "tempo-10", goal: "take 1", k: 2, mine: 10, theirs: 10, kings: 0, first: TEMPO, share: 1 },
    Kind { name: "crown1-7", goal: "crown", k: 1, mine: 7, theirs: 7, kings: 0, first: SHOT, share: 1 },
    Kind { name: "crown2-8", goal: "crown", k: 2, mine: 8, theirs: 8, kings: 0, first: SHOT, share: 1 },
    Kind { name: "crown3-9", goal: "crown", k: 3, mine: 9, theirs: 9, kings: 0, first: SHOT, share: 3 },
    Kind { name: "king1-8", goal: "take 3", k: 1, mine: 8, theirs: 9, kings: 1, first: SHOT, share: 1 },
    Kind { name: "king2-9", goal: "take 2", k: 2, mine: 9, theirs: 10, kings: 1, first: SHOT, share: 1 },
    Kind { name: "king3-10", goal: "take 2", k: 3, mine: 10, theirs: 11, kings: 1, first: SHOT, share: 3 },
    Kind { name: "king3-12", goal: "take 2", k: 3, mine: 12, theirs: 13, kings: 1, first: SHOT, share: 3 },
    Kind { name: "safe-10", goal: "safe", k: 1, mine: 10, theirs: 10, kings: 0, first: SHOT, share: 1 },
    Kind { name: "safe-15", goal: "safe", k: 1, mine: 15, theirs: 15, kings: 0, first: SHOT, share: 3 },
];

// Runs every kind (KINDS; on 8x8 its men scaled to the board, the safe move and the
// king shots International's alone) for `seconds` each, keeping `per` puzzles of a kind
// at most, a third of them turned for black, each new (fresh): one a line (entry), and
// each kind's pass rates and cost on stderr.
fn batch(seed: u64, per: i64, seconds: f64) {
    var r = rng { seed };
    var s = puzzles::Solver { moves: [], stack: [] };
    let small = rules::VARIANTS[variant].size == 8;
    keep_course();
    print("variant ", rules::VARIANT_NAMES[variant]);
    for kind in KINDS {
        let goal_ok, _, ok = puzzles::parse_goal(kind.goal);
        guard ok && !(small && (goal_ok == puzzles::SAFE || kind.kings > 0 && kind.k > 1)) else { continue; }
        let mine = if small { (kind.mine * 12 + 10) / 20 } else { kind.mine };
        let theirs = if small { (kind.theirs * 12 + 10) / 20 } else { kind.theirs };
        var st = Stages { .. };
        var found = 0;
        var dups = 0;
        let begun = time();
        while found < per * kind.share && time() - begun < seconds * kind.share {
            let p = placed(r, mine, theirs, kind.kings, rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: variant });
            guard popcount(p.pieces[0]) == mine && popcount(p.pieces[1]) == theirs else { continue; }
            var pz = puzzle_of(p, kind.goal, kind.k);
            var line: u8[>..] = [];
            guard candidate(s, pz, line, st, kind.first) else { continue; }
            var black: u8[>..] = [];
            let turned_round = rand_int(r, 3) == 0;
            if turned_round { guard turn(s, pz, black) else { continue; } }
            guard fresh(pz) else {
                dups++;
                continue;
            }
            let shown: const u8[:] = if turned_round { black[..] } else { line[..] };
            entry(pz, shown, str("find ", kind.name, " seed ", seed));
            found++;
        }
        report(kind.name, st, dups, found, time() - begun);
    }
}

fn report(name: const u8[:], st: Stages&, dups: i64, found: i64, seconds: f64) {
    var t: u8[>..] = [];
    format_flt(t, seconds, 1);
    var each: u8[>..] = [];
    format_flt(each, seconds / max(found as f64, 1.0), 2);
    write_stderr(str(name, ": ", st.tried, " tried, ", st.cheap, " cheap, ", st.solved, " solved, ", st.shaped,
                     " shaped, ", st.sound, " sound, ", dups, " seen, ", found, " kept; ", t, " s, ", each,
                     " s a puzzle\n"));
}

let GAME_PLIES = 300;
let OPENING = 4;            // plies played at random first, so games differ
let SHOT_MOVES = 4;         // the most of the solver's moves a puzzle from a game takes
let EVEN = 60;              // the side that moved before the puzzle scored its move at least this (a man is 100)

// Puzzles from the computer's own games (task 088, after lichess-puzzler): `games`
// games of the computer against itself at `skill`, `nodes` a move, from `OPENING`
// random plies. A position is a candidate where the material is even, no side up a man
// or a king, and the side that just moved scored its move as roughly even (EVEN): the
// puzzle is the moment it turns, not a game already won. The game itself says what
// the side to move went on to win: when it is up `n` within SHOT_MOVES moves, the
// position is tried as "take n" in the fewest moves that force it, with one right move
// at each turn (candidate). One puzzle a game, the first; one a line (entry).
fn games(seed: u64, count: i64, skill: i64, nodes: i64) {
    var r = rng { seed };
    var e = ai::Engine { .. };
    ai::init(e);
    var s = puzzles::Solver { moves: [], stack: [] };
    var moves:   rules::Moves                  = [];
    var line_at: rules::Position[..GAME_PLIES] = [];
    var scored:  i64[GAME_PLIES]               = [0; GAME_PLIES];
    var st = Stages { .. };
    var found = 0;
    var dups = 0;
    var candidates = 0;
    let begun = time();
    keep_course();
    print("variant ", rules::VARIANT_NAMES[variant]);
    for g in count {
        var p = rules::start(variant);
        var past = rules::Past { draw: rules::draw_start(p), before: [] };
        line_at.clear();
        e.node_limit = nodes;
        for ply in GAME_PLIES {
            line_at.push(p);
            rules::generate(p, moves);
            guard moves.len > 0 && rules::draw_reason(past.draw, p) == rules::NO_DRAW else { break; }
            var m = moves[rand_int(r, moves.len)];
            scored[ply] = 0;
            if ply >= OPENING {
                m = ai::think_after(e, past, p, skill, seed * 100000 + (g * GAME_PLIES + ply) as u64);
                scored[ply] = if e.chosen >= 0 && e.main_exact[e.chosen] { e.main_score[e.chosen] } else { 0 };
            }
            let q = rules::play(p, m);
            rules::pass(past, p, m, q);
            p = q;
        }
        // The first position that makes a puzzle.
        var done = false;
        for i in OPENING + 1..line_at.len {
            guard !done else { break; }
            let at = line_at[i];
            let me = at.side as i64;
            guard popcount(at.pieces[0] & ~at.kings) == popcount(at.pieces[1] & ~at.kings) &&
                  popcount(at.pieces[0] & at.kings) == popcount(at.pieces[1] & at.kings) && true &&
                  abs(scored[i - 1]) <= EVEN
            else { continue; }
            for k in 1..SHOT_MOVES + 1 {
                let j = i + 2 * k - 1;
                guard j < line_at.len else { break; }
                let after_k = line_at[j];
                let won = (popcount(at.pieces[1 - me]) - popcount(after_k.pieces[1 - me])) -
                          (popcount(at.pieces[me]) - popcount(after_k.pieces[me]));
                guard won >= 1 else { continue; }
                candidates++;
                var pz = puzzle_of(at, str("take ", won), k);
                var line: u8[>..] = [];
                guard candidate(s, pz, line, st, EITHER) else { continue; }
                guard fresh(pz) else {
                    dups++;
                    break;
                }
                entry(pz, line, str("game seed ", seed, " game ", g, " ply ", i));
                found++;
                done = true;
                break;
            }
        }
    }
    var name: u8[>..] = [];
    format(name, "games at ", skill, ", ", count, " (", candidates, " swings)");
    report(name, st, dups, found, time() - begun);
}

// The difficulty estimate (task 088): no play data leaves the device, so a puzzle's
// difficulty is judged offline from the computer as judge, the line's shape, and the
// motif's level, blended into one number on the players' rating scale.
let RATE_STEP = 5;          // skills tried, 0 to 100 in these steps
let RIVAL_SKILL = 30;       // the skill whose look at the moves says which look as good as the right one
let RIVAL_MARGIN = 20;      // a move within this of the right one's score looks as good (a man is 100)
let DEEP_NODES = 4000000;
let CROWN_MISSES = 50;      // the most misses a crown puzzle counts (rate)   // full skill's search, given more time, for a move it doesn't find at once

struct Rating {
    misses:     i64      = 0,     // of the skills 0, 5, .. 100, those whose best move isn't the right one, times 5; 20 more if full skill misses it given more time
    moves:      i64      = 0,     // the solver's moves in the line
    given:      i64      = 0,     // men the solver gives along it
    legal:      i64      = 0,     // the first turn's moves to weigh
    forced:     bool     = false, // the first move is a capture, which the rules force
    rivals:     i64      = 0,     // other first moves the computer at RIVAL_SKILL scores as good as the right one
    pieces:     i64      = 0,     // on the board: more to read round the motif
    crowns:     bool     = false, // the line lets the other side crown, which a child is taught never to allow
    level:      i64      = 1,     // the motif's level (motif)
    difficulty: i64      = 0,
    pattern:    u8[..32] = [], // which skills found it, 100 down to 0
}

// The move the computer at `skill` rates best at p, nothing overlooked and no gift, as
// a hint is found; its scores stay in e.
fn rated_best(e: ai::Engine&, p: rules::Position, skill: i64, nodes: i64) -> rules::Move {
    ai::helping(e, true);
    e.node_limit = nodes;
    ai::start(e, p, skill, 1);
    while !ai::step(e, 1 << 30) {}
    let m = ai::best(e);
    ai::helping(e, false);
    return m;
}

fn same_ply(m: rules::Move, want: puzzles::Ply) -> bool { m.from == want.from && m.to == want.to && m.captured == want.captured }

fn right_index(e: ai::Engine&, want: puzzles::Ply) -> i64 {
    for c, i in e.moves { if c.from == want.from && c.to == want.to && c.captured == want.captured { return i; } }
    return -1;
}

// A skill finds the right move when it is the move it would play (its move order
// breaking ties among moves it scores alike, as in an endgame whose win is no material
// within its sight), or when it sees it (sees).
//
// Whether the search just made sees the right move: scores it, exactly, as well as any
// other move, and better than one at least. A crown is no aim of the engine's, which
// plays for material, so a crowning move it scores level with quiet ones is seen; a
// shallow search that scores every move alike sees nothing, whichever it would play.
fn sees(e: ai::Engine&, want: puzzles::Ply, margin: i64) -> bool {
    let right = right_index(e, want);
    guard right >= 0 && e.main_exact[right] else { return false; }
    var level = 0;
    for i in e.moves.len {
        guard i != right else { continue; }
        if e.main_exact[i] && e.main_score[i] > e.main_score[right] + margin { return false; }
        if !e.main_exact[i] || e.main_score[i] >= e.main_score[right] - margin { level++; }
    }
    return level < e.moves.len - 1;
}

fn rate(e: ai::Engine&, pz: puzzles::Puzzle&) -> Rating {
    var r = Rating { .. };
    let p = pz.start;
    let want = pz.lines[0].plies[0];
    var legal: rules::Moves = [];
    rules::generate(p, legal);
    r.legal = legal.len;
    r.forced = legal[0].captured != 0;
    r.pieces = puzzles::pieces(p);
    let sh = shape_of(pz);
    r.moves = pz.moves;
    r.given = sh.given;
    r.crowns = sh.lets_crown;
    let theme, level = motif(pz);
    r.level = level;
    // How many skills miss it: a move the shallow skills find by luck (all moves alike
    // to them, the first taken) counts once, not as the lowest that finds it.
    var skill = 100;
    while skill >= 0 {
        let m = rated_best(e, p, skill, ai::NODE_LIMIT);
        let found = same_ply(m, want) || sees(e, want, 0);
        r.pattern.append(if found { "+" } else { "." });
        if !found { r.misses += RATE_STEP; }
        if skill == RIVAL_SKILL {
            let right = right_index(e, want);
            for i in e.moves.len {
                if i != right && right >= 0 && e.main_exact[i] && e.main_score[i] >= e.main_score[right] - RIVAL_MARGIN { r.rivals++; }
            }
        }
        if !found && skill == 100 {
            let deep = rated_best(e, p, 100, DEEP_NODES);
            if !same_ply(deep, want) && !sees(e, want, 0) { r.misses += 20; }
        }
        skill -= RATE_STEP;
    }
    // The engine plays for material and is no judge of a crown given men for: what it
    // misses there counts no more than a middle skill's.
    if pz.goal == puzzles::CROWN { r.misses = min(r.misses, CROWN_MISSES); }
    r.difficulty = blend(r);
    return r;
}

// One number from the parts, on the players' rating scale. The computer as judge
// weighs most; the shape and the motif's level after it. Checked against kabe.ee's five
// (tools/calibration/kabe.txt), which it must place medium to hard and in their
// author's order, and the course, which is the floor.
fn blend(r: Rating&) -> i64 {
    let weigh = log2(max(r.legal, 2) / 2.0);
    let crowd = log2(max(r.pieces, 6) / 6.0);
    var d = 400.0 + 10.0 * r.misses + 50.0 * (r.moves - 1) + 30.0 * r.given + 60.0 * weigh + 10.0 * min(r.rivals, 6) +
            50.0 * crowd + 40.0 * (r.level - 1);
    if r.crowns { d += 80.0; }
    if r.forced { d -= 120.0; }
    return d as i64;
}

// A library line, `theme level | goal in moves | FEN | line | source`, read into pz
// with its one line; whether it is one. The line need not be checked: a calibration
// reference's is its author's.
fn parse_entry(text: const u8[:], variant_of: u8, pz: puzzles::Puzzle&) -> bool {
    var fields: const u8[:][..5] = [];
    var rest:   const u8[:]      = text;
    while fields.len < 5 {
        let a, b, more = split_once(rest, '|');
        fields.push(trim(a));
        rest = b;
        guard more else { break; }
    }
    guard fields.len == 5 else { return false; }
    let goal_part, k_part, has_k = split_once(fields[1], " in ");
    guard has_k else { return false; }
    let k, ok_k = parse_int(trim(k_part));
    let g, count, ok_g = puzzles::parse_goal(goal_part);
    let start, ok_p = rules::parse_fen(fields[2], variant_of);
    guard ok_k && ok_g && ok_p else { return false; }
    pz = puzzles::Puzzle { id: 1, theme: 0, level: 1, goal: g, count: count, start: start, moves: k, lines: [], told: true };
    let line .= pz.lines.push(puzzles::Line { plies: [] });
    var q = start;
    var legal: rules::Moves = [];
    for word in split(fields[3], ' ') {
        guard word.len > 0 else { continue; }
        guard line.plies.len < puzzles::MAX_PLIES else { return false; }
        let ply, ok = puzzles::parse_move(q, word, legal);
        guard ok else { return false; }
        line.plies.push(ply);
        q = puzzles::after(q, puzzles::as_played(q, ply, legal));
    }
    return line.plies.len > 0;
}

// Rates every puzzle of a library file (or a course's file, its blocks), each printed as
// `difficulty | misses pattern | moves given legal forced rivals pieces crowns level | the entry`.
fn rate_file(path: const u8[:]) {
    var text: u8[>..] = [];
    guard read_file(path, text) else { abort(str("can't read ", path)); }
    var e = ai::Engine { .. };
    ai::init(e);
    let begun = time();
    var n = 0;
    if find(text[..], "\nid ") >= 0 {
        var set = puzzles::Set { list: [] };
        var err: u8[>..] = [];
        guard puzzles::parse(text, set, err) else { abort(err); }
        for pz in set.list {
            let r = rate(e, pz);
            var shown: u8[>..] = [];
            screen_line_text(pz, shown);
            print_rating(r, str(puzzles::THEME_NAMES[pz.theme], " ", pz.level, " | ", goal_text(pz), " in ", pz.moves, " | ",
                                rules::fen(pz.start), " | ", shown, " | course ", pz.id));
            n++;
        }
    } else {
        var variant_of: u8 = rules::INTERNATIONAL;
        for raw in split(text, '\n') {
            let l = trim(raw);
            guard l.len > 0 && l[0] != '#' else { continue; }
            if starts_with(l, "variant ") {
                let named, known = rules::variant_named(trim(l[8..]));
                guard known else { abort(str("not a variant: ", l)); }
                variant_of = named;
                print(l);
                continue;
            }
            var pz = puzzle_of(rules::start(variant_of), "win", 1);
            guard parse_entry(l, variant_of, pz) else { abort(str("not an entry: ", l)); }
            let r = rate(e, pz);
            print_rating(r, l);
            n++;
        }
    }
    var t: u8[>..] = [];
    format_flt(t, (time() - begun) / max(n as f64, 1.0), 2);
    write_stderr(str(n, " rated, ", t, " s each\n"));
}

fn screen_line_text(pz: puzzles::Puzzle&, out: u8[>..]&) {
    var legal: rules::Moves = [];
    var q = pz.start;
    for ply in pz.lines[0].plies {
        if out.len > 0 { out.append(" "); }
        let m = puzzles::as_played(q, ply, legal);
        puzzles::move_text(out, q, m, legal);
        q = puzzles::after(q, m);
    }
}

fn print_rating(r: Rating&, entry_text: const u8[:]) {
    print(r.difficulty, " | ", r.misses, " ", r.pattern, " | ", r.moves, " ", r.given, " ", r.legal, " ",
          if r.forced { 1 } else { 0 }, " ", r.rivals, " ", r.pieces, " ", if r.crowns { 1 } else { 0 }, " ", r.level, " | ",
          entry_text);
}

fn main() {
    // The flags first, wherever they are; the words left are the command.
    let all = args();
    var argv: u8[..256][>..] = [];
    var i = 0;
    while i < all.len {
        if i + 1 < all.len && all[i] == "--variant" {
            let named, known = rules::variant_named(all[i + 1]);
            if known { variant = named; }
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
        try_position(argv[2], argv[3], argv[4], if argv.len >= 6 { argv[5] } else { "" });
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
    if argv.len >= 3 && argv[1] == "batch" {
        let seed, ok_s = parse_int(argv[2]);
        let per, ok_p = parse_int(if argv.len >= 4 { argv[3] } else { "20" });
        let secs, ok_t = parse_int(if argv.len >= 5 { argv[4] } else { "60" });
        guard ok_s && ok_p && ok_t else { abort("batch SEED [PER [SECONDS]]"); }
        batch(seed as u64, per, secs);
        return;
    }
    if argv.len >= 3 && argv[1] == "games" {
        let seed, ok_s = parse_int(argv[2]);
        let n, ok_n = parse_int(if argv.len >= 4 { argv[3] } else { "10" });
        let skill, ok_k = parse_int(if argv.len >= 5 { argv[4] } else { "90" });
        let nodes, ok_d = parse_int(if argv.len >= 6 { argv[5] } else { "300000" });
        guard ok_s && ok_n && ok_k && ok_d else { abort("games SEED [GAMES [SKILL [NODES]]]"); }
        games(seed as u64, n, skill, nodes);
        return;
    }
    if argv.len >= 3 && argv[1] == "rate" {
        rate_file(argv[2]);
        return;
    }
    check_file(if argv.len >= 2 { argv[1] } else { "" });
}
