// What makes a puzzle sound, for test/puzzles/ and tools/puzzles.goose
// (docs/architecture/puzzles.md, "Checks"): each line is legal and reaches the goal
// with its last move and not before; the goal can be reached within the puzzle's moves
// whatever the replies, and not in fewer; every move that is right where a line has the
// solver to move is a line's move there, so the file lists every way in and on; each
// line ends quiet, no capture due for either side against any reply (a safe move's
// replies aside), a take's line wins its count exactly, and a crown's line ends with
// the king made; a safe puzzle's every other move loses to a shot; no move along a line
// shares its squares with another legal move, which a tap couldn't tell apart; and it
// says where it came from.
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

// Checks pz, appending what is wrong to out, and the first moves that solve it to `ways`.
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
    if pz.goal == SAFE { n += safe_check(s, pz, out); }
    // Every move that is right where a line has the solver to move must be a line's
    // move there: the file lists every way on, not only every way in. Lines sharing
    // the moves so far are checked once, at the first of them.
    for line, li in pz.lines {
        var p = pz.start;
        for ply, i in line.plies {
            var first = true;
            for k in li { if same_start(pz.lines[k], line, i) { first = false; } }
            if i % 2 == 0 && first {
                rules::generate(p, moves);
                var all: Short[..rules::MAX_MOVES] = [];
                for m in moves { all.push(short(m)); }
                for m in all {
                    guard judge(s, p, m, pz.moves - i / 2) != WRONG else { continue; }
                    if i == 0 {
                        if ways.len > 0 { ways.append(" "); }
                        move_text(ways, p, m, moves);
                    }
                    var listed = false;
                    for other in pz.lines {
                        guard same_start(other, line, i) && other.plies.len > i else { continue; }
                        let f = other.plies[i];
                        if f.from == m.from && f.to == m.to && f.captured == m.captured { listed = true; }
                    }
                    if !listed {
                        var t: u8[>..] = [];
                        move_text(t, p, m, moves);
                        format(out, "  line ", li + 1, " move ", i + 1, ": solved too by ", t, ", which no line lists\n");
                        n++;
                    }
                }
            }
            let m = as_played(p, ply, moves);
            if pz.goal == CROWN && i == line.plies.len - 1 && !m.crowned {
                format(out, "  line ", li + 1, " ends without a king made\n");
                n++;
            }
            p = after(p, m);
        }
        // The end is quiet: no capture due for either side, against any reply. A safe
        // move's replies may still give men, offers its threat no longer makes good:
        // that none wins anything is the move's being right.
        if !quiet(p, moves, pz.goal != SAFE) {
            format(out, "  line ", li + 1, " ends with a capture due\n");
            n++;
        }
        if pz.goal == TAKE && net(s, p) != pz.count {
            format(out, "  line ", li + 1, " wins ", net(s, p), ", not ", pz.count, "\n");
            n++;
        }
    }
    return n;
}

// What a safe puzzle needs beyond the rest: one move, no capture due at the start, and
// every move but the right one losing to a shot (solve.goose, shot), not to a capture
// at once or a quiet threat. That the right move leaves no shot is its being right:
// nothing is lost over SAFE_DEPTH plies. Returns how many problems, appended to out.
fn safe_check(s: Solver&, pz: Puzzle&, out: u8[>..]&) -> i64 {
    var moves: rules::Moves = [];
    var n = 0;
    if pz.moves != 1 {
        format(out, "  a safe move is one move, not ", pz.moves, "\n");
        n++;
    }
    rules::generate(pz.start, moves);
    if moves.len > 0 && moves[0].captured != 0 {
        format(out, "  a capture is due at the start\n");
        n++;
    }
    var all: Short[..rules::MAX_MOVES] = [];
    for m in moves { all.push(short(m)); }
    for m in all {
        guard judge(s, pz.start, m, 1) == WRONG && !shot(s, after(pz.start, m), SAFE_DEPTH) else { continue; }
        var t: u8[>..] = [];
        move_text(t, pz.start, m, moves);
        format(out, "  ", t, " loses material, but not to a shot\n");
        n++;
    }
    return n;
}

// Whether two lines have the same first n moves.
fn same_start(a: Line&, b: Line&, n: i64) -> bool {
    guard a.plies.len >= n && b.plies.len >= n else { return false; }
    for i in n { if a.plies[i] != b.plies[i] { return false; } }
    return true;
}

// Whether p is quiet: its side to move has no capture, and, if `replies`, none of its
// moves gives the other side one. A side with no move at all is quiet.
fn quiet(p: rules::Position, moves: rules::Moves&, replies: bool = true) -> bool {
    rules::generate(p, moves);
    guard moves.len == 0 || moves[0].captured == 0 else { return false; }
    guard replies else { return true; }
    var all: Short[..rules::MAX_MOVES] = [];
    for m in moves { all.push(short(m)); }
    for m in all {
        rules::generate(after(p, m), moves);
        if moves.len > 0 && moves[0].captured != 0 { return false; }
    }
    return true;
}

// The pieces on the board.
fn pieces(p: rules::Position) -> i64 { popcount(p.pieces[0] | p.pieces[1]) }
