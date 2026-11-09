// What the tests under test/rules/ share. They declare test/ as a package,
// `import check from "../";`, since a program's own imports resolve below its
// root file's directory.
namespace check;
import std;
import rules from "../src/rules";

// The position fen gives, which must be well formed.
fn position(variant: u8, fen: const u8[:]) -> rules::Position {
    let p, ok = rules::parse_fen(fen, variant);
    if !ok { print("not a position: ", fen); assert(false); }
    return p;
}

// Prints the position, then its legal moves sorted, each with how many pieces
// it takes and whether it crowns.
fn show(variant: u8, fen: const u8[:]) {
    let p = position(variant, fen);
    print(rules::fen(p));
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    var lines: u8[..80][>..] = [];
    for i in moves.len {
        let m = moves[i];
        var text: u8[>..] = [];
        text.append("  ");
        rules::format_move(text, variant, m);
        if m.captured != 0 { format(text, "  takes ", popcount(m.captured)); }
        if m.crowned { text.append("  crowned"); }
        let line .= lines.push([]);
        line.append(text);
    }
    sort(lines) { a, b => compare(a, b) < 0 };
    for l in lines { print(l); }
    print(moves.len, if moves.len == 1 { " move" } else { " moves" });
}

// Plays the one legal move of the position and prints the position after it.
fn play_only(variant: u8, fen: const u8[:]) {
    let p = position(variant, fen);
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    if moves.len != 1 { print(moves.len, " moves in ", fen, ", expected one"); assert(false); }
    print("after: ", rules::fen(rules::play(p, moves[0])));
}

// How a draw test walks a game on (walk): each ply the mover's first move in sorted
// order that repeats no position of the game so far, preferring, most first: a man's
// move on the plies in `men` and a king's on the others; a move that leaves the other
// side no capture; for the main road, the lone king's moves onto the long diagonal up
// to ply `road` and off it after, and the strong side's off it; one that threatens no
// capture. Captures, being forced, are played as they come.
struct Walk {
    men:  i64[..4] = [],
    road: i64      = 0,
}

let REASONS = ["none", "repetition", "only kings", "lone king", "balance"];

// What the draw counts say after a ply: the countdown and the reason, if any.
fn say(text: u8[>..]&, d: rules::Draw&, p: rules::Position&) {
    let r = rules::draw_reason(d, p);
    if r != rules::NO_DRAW {
        format(text, "  DRAWN: ", REASONS[r]);
        return;
    }
    let c = rules::countdown(d, p);
    if c.kind == rules::COUNT_DRAW { format(text, "  draw in ", c.moves); }
    if c.kind == rules::COUNT_WIN { format(text, "  ", if c.side == 0 { "white" } else { "black" }, " must win in ", c.moves); }
    if c.kind == rules::COUNT_TWICE { text.append("  same position twice"); }
}

// Plays `script` (moves as rules::format_move writes them) from fen, then walks on as
// `how` says, for at most `plies` plies or until the game is drawn or over. Prints each
// ply with a countdown or a draw, and the ply it ended on. The counts are kept from the
// moves (draw_after) and checked against those from the positions (draw_between).
fn walk(variant: u8, fen: const u8[:], script: const u8[:][:], how: Walk, plies: i64) {
    let start = position(variant, fen);
    print(fen);
    var line: rules::Position[>..] = [];
    line.push(start);
    var d = rules::draw_start(start);
    var moves:   rules::Moves = [];
    var answers: rules::Moves = [];
    for ply in 1..plies + 1 {
        let p = line[line.len - 1];
        rules::generate(p, moves);
        if moves.len == 0 {
            print("  ", ply - 1, ": ", if p.side == 0 { "white" } else { "black" }, " has no move");
            return;
        }
        var pick = -1;
        var best = -1;
        var text:   u8[>..] = [];
        var chosen: u8[>..] = [];
        for i in moves.len {
            let m = moves[i];
            text.clear();
            rules::format_move(text, variant, m);
            if ply <= script.len {
                if text == script[ply - 1] { pick = i; }
                continue;
            }
            let q = rules::play(p, m);
            var fresh = true;
            for &x in line { if rules::same(x, q) { fresh = false; } }
            guard fresh else { continue; }
            rules::generate(q, answers);
            var score = 0;
            if answers.len == 0 || answers[0].captured == 0 { score += 8; }
            var threat = q;
            threat.side = p.side;
            rules::generate(threat, answers);
            if answers.len == 0 || answers[0].captured == 0 { score += 1; }
            let man = p.kings & rules::bit(m.from) == 0;
            var want_man = false;
            for k in how.men { if k == ply { want_man = true; } }
            if man == want_man && !m.crowned { score += 32; }
            if how.road > 0 {
                let lone = popcount(p.pieces[p.side]) == 1;
                let on = rules::ROAD & rules::bit(m.to) != 0;
                if lone && on == (ply <= how.road) { score += 2; }
                if !lone && !on { score += 2; }
            }
            if score > best || (score == best && compare(text, chosen) < 0) {
                best = score;
                pick = i;
                chosen.clear();
                chosen.append(text);
            }
        }
        if pick < 0 {
            print("  ", ply - 1, ": no move to play");
            return;
        }
        let m = moves[pick];
        let q = rules::play(p, m);
        d = rules::draw_after(d, p, m, q);
        line.push(q);
        d.seen = rules::repeats(line, line.len - 1, d.quiet);
        let all = rules::draw_of(line);
        if all.quiet != d.quiet || all.calm != d.calm || all.lone != d.lone || all.road != d.road
           || all.seen != d.seen || all.road_state != d.road_state || all.lone_kind != d.lone_kind {
            print("  ", ply, ": the counts from the positions differ");
        }
        text.clear();
        rules::format_move(text, variant, m);
        var out: u8[>..] = [];
        format(out, "  ", ply, " ", text);
        let before = out.len;
        say(out, d, q);
        if out.len > before || ply <= script.len { print(out); }
        if rules::draw_reason(d, q) != rules::NO_DRAW { return; }
    }
    print("  no draw in ", plies, " plies");
}
