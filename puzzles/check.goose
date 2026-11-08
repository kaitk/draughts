// What makes a puzzle sound, for test/puzzles/ and tools/puzzles.goose
// (docs/architecture/puzzles.md, "Checks"): each line is legal and reaches the goal
// with its last move and not before; the goal can be reached within the puzzle's moves
// whatever the replies, and not in fewer; every first move that solves it starts one of
// its lines, so the file lists every way in; no move along a line shares its squares with
// another legal move, which a tap couldn't tell apart; and it says where it came from.
namespace puzzles;
import std;
import rules from "../rules";

// A legal move of p as PDN writes it, with every stop.
fn move_text(out: u8[>..]&, p: rules::Position, m: Short, moves: rules::Moves&) {
    rules::generate(p, moves);
    for c in moves {
        guard c.from == m.from && c.to == m.to && c.captured == m.captured else { continue; }
        rules::format_move(out, p.variant, c);
        return;
    }
}

// The legal move of p that ply is, crowned or not as it is.
fn as_played(p: rules::Position, ply: Ply, moves: rules::Moves&) -> Short {
    let i = index_of(p, ply, moves);
    assert(i >= 0);
    return short(moves[i]);
}

// Whether two of p's legal moves go from and to the same squares.
fn ambiguous(p: rules::Position, moves: rules::Moves&) -> bool {
    rules::generate(p, moves);
    for a, i in moves {
        for k in i + 1..moves.len { if moves[k].from == a.from && moves[k].to == a.to { return true; } }
    }
    return false;
}

// Checks pz, appending what is wrong to out, and the moves that solve it to `ways`.
// Returns how many problems.
fn check(s: Solver&, pz: Puzzle&, out: u8[>..]&, ways: u8[>..]&) -> i64 {
    var moves: rules::Moves = [];
    var n = 0;
    begin(s, pz);
    if !pz.told {
        format(out, "  no source\n");
        n++;
    }
    for line, li in pz.lines {
        var p = pz.start;
        if line.plies.len % 2 == 0 {
            format(out, "  line ", li + 1, " ends with a reply\n");
            n++;
        }
        for ply, i in line.plies {
            let m = as_played(p, ply, moves);
            if i % 2 == 0 {
                if ambiguous(p, moves) {
                    format(out, "  line ", li + 1, " move ", i + 1, ": another move has the same squares\n");
                    n++;
                }
                let want = if i == line.plies.len - 1 { SOLVED } else { ON };
                let got = judge(s, p, m, pz.moves - i / 2);
                if got != want {
                    format(out, "  line ", li + 1, " move ", i + 1, ": ",
                           if got == WRONG { "doesn't solve it" } else if got == SOLVED { "solves it already" }
                           else { "doesn't reach the goal" }, "\n");
                    n++;
                }
            }
            p = after(p, m);
        }
    }
    if !wins(s, pz.start, pz.moves) {
        format(out, "  not solvable in ", pz.moves, "\n");
        n++;
    }
    if pz.moves > 1 && wins(s, pz.start, pz.moves - 1) {
        format(out, "  solvable in ", pz.moves - 1, "\n");
        n++;
    }
    // Every first move that solves it, each of which must start a line.
    rules::generate(pz.start, s.moves);
    var firsts: Short[..rules::MAX_MOVES] = [];
    for m in s.moves { firsts.push(short(m)); }
    for m in firsts {
        guard judge(s, pz.start, m, pz.moves) != WRONG else { continue; }
        if ways.len > 0 { ways.append(" "); }
        move_text(ways, pz.start, m, moves);
        var listed = false;
        for line in pz.lines {
            let f = line.plies[0];
            if f.from == m.from && f.to == m.to && f.captured == m.captured { listed = true; }
        }
        if !listed {
            var t: u8[>..] = [];
            move_text(t, pz.start, m, moves);
            format(out, "  solved too by ", t, ", which starts no line\n");
            n++;
        }
    }
    return n;
}

// The pieces on the board.
fn pieces(p: rules::Position) -> i64 { popcount(p.pieces[0] | p.pieces[1]) }
