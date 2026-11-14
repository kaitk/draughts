// The most legal moves a position was found to have, which rules::MAX_MOVES must hold
// with room to spare: in International, six white kings that can each take six of
// black's pieces by many ends and sets (the majority rule keeps only the sixes, every one
// a move of its own), 407 moves. A search over positions with up to the starting pieces,
// no man on its crowning row, found none with more; test/perft.py agrees on the 407. Each king's ways (rules::ways, every way to each move, which the board keeps
// for a selected piece) stay within rules::MAX_WAYS too, and every move's first way, the
// one the board shows (rules::way_of), ends where the move does and takes its pieces.
import std;
import rules from "../../src/rules";
import check from "../";

let MOST = "W:WK2,K5,K15,36,K46,K47,K48,K49:BK4,K8,K9,13,18,19,22,K24,K27,30,31,35,40,K41,K42,K43,K44";

fn main() {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    let p = check::position(rules::INTERNATIONAL, MOST);
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    print(rules::fen(p));
    print(moves.len, " moves of ", rules::MAX_MOVES, " room");
    var froms:  u64    = 0;
    var taking: i64[8] = [0; 8];
    for m in moves {
        froms |= rules::bit(m.from);
        taking[min(popcount(m.captured), 7)] += 1;
    }
    for n in 8 { if taking[n] > 0 { print("  taking ", n, ": ", taking[n]); } }
    var ways: rules::Ways = [];
    var most = 0;
    var x = froms;
    while x != 0 {
        let f = ctz(x);
        x &= x - 1;
        rules::ways(p, f, ways);
        var n = 0;
        for m in moves { if m.from == f { n += 1; } }
        print("  from ", v.number_of[f], ": ", n, " moves, ", ways.len, " ways");
        most = max(most, ways.len);
    }
    print("the most ways of one piece ", most, " of ", rules::MAX_WAYS, " room");
    var right = 0;
    for m in moves {
        let w = rules::way_of(p, m);
        if w.path.len == popcount(m.captured) + 1 && w.path[0] == m.from && w.path[w.path.len - 1] == m.to { right += 1; }
    }
    print("first ways that end at their move's end, a stop a piece: ", right);
}
