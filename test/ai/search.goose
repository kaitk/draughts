// The search machine (ai/search.goose) against a plain recursive minimax written here
// with no pruning and no table: every root move the machine scores exactly must have
// the minimax value, and every other must be worse than the best by more than the
// margin. Then the transposition table must change no exact root score at a fixed
// depth, only the number of nodes. Positions: the starts and middlegames of each variant,
// and one with kings.
import std;
import rules from "../../rules";
import ai from "../../ai";
import check from "../";

// The value of p to the side to move, searched as the machine searches: d plies of free
// moves, h plies in all, forced moves costing no depth, captures followed past d.
recursive fn minimax(p: rules::Position, d: i64, h: i64, ply: i64) -> i64 {
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    let n = moves.len;
    if n == 0 { return -(ai::WIN - ply); }
    if h <= 0 || ply >= ai::MAX_PLY - 1 || (d <= 0 && moves[0].captured == 0) {
        return ai::evaluate(p);
    }
    let cd = if d > 0 && n == 1 { d } else { max(d - 1, 0) };
    var best = -ai::INF;
    for i in n { best = max(best, -minimax(rules::play(p, moves[i]), cd, h - 1, ply + 1)); }
    return best;
}

// Searches p to `depth` plies with `extra` more, all root moves within `margin`.
fn search(e: ai::Engine&, p: rules::Position, depth: i64, extra: i64, margin: i64, tt: bool) {
    e.use_tt = tt;
    ai::begin(e, p, depth, extra, margin, 1 << 40);
    while e.searching { ai::run(e, 1 << 30); }
    e.use_tt = true;
}

fn against_minimax(e: ai::Engine&, variant: u8, fen: const u8[:], depth: i64, extra: i64, margin: i64) {
    let p = check::position(variant, fen);
    search(e, p, depth, extra, margin, true);
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    var best = -ai::INF;
    for i in moves.len { if e.exact[i] { best = max(best, e.score[i]); } }
    var exact = 0;
    var wrong = 0;
    for i in moves.len {
        let v = -minimax(rules::play(p, moves[i]), depth - 1, depth + extra - 1, 1);
        if e.exact[i] {
            exact += 1;
            if v != e.score[i] { wrong += 1; }
        } else if v > e.score[i] || v > best - margin {
            wrong += 1;
        }
    }
    print(fen, "  depth ", depth, "+", extra, " margin ", margin, ": ", moves.len, " moves, ",
          exact, " exact, ", wrong, " wrong");
}

fn with_and_without_table(e: ai::Engine&, variant: u8, fen: const u8[:], depth: i64, extra: i64) {
    let p = check::position(variant, fen);
    search(e, p, depth, extra, 30, false);
    let n = e.root_count;
    let without = e.nodes;
    var score: i64[rules::MAX_MOVES]  = [0; rules::MAX_MOVES];
    var exact: bool[rules::MAX_MOVES] = [false; rules::MAX_MOVES];
    for i in n {
        score[i] = e.score[i];
        exact[i] = e.exact[i];
    }
    search(e, p, depth, extra, 30, true);
    var differ = 0;
    // A move worse than the margin has only an upper bound, which depends on the order
    // moves were searched in; whether it is exact and the exact scores must agree.
    for i in n { if exact[i] != e.exact[i] || (exact[i] && score[i] != e.score[i]) { differ += 1; } }
    print(fen, "  depth ", depth, "+", extra, ": ", differ, " root scores differ, table saves nodes: ",
          e.nodes < without);
}

fn main() {
    var e = ai::Engine { .. };
    ai::init(e);
    against_minimax(e, rules::RUSSIAN, "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8", 4, 2, 40);
    against_minimax(e, rules::RUSSIAN, "W:Wa1,e1,g1,f2,a3,e3,g3,b4,f4,a5:Bd4,h4,c5,g5,b6,d6,h6,a7,c7,b8,f8", 4, 4, 0);
    against_minimax(e, rules::RUSSIAN, "W:Wc1,g1,d2,f2,g3,b4,a5:Bh4,g5,f6,h6,a7,c7,e7,b8", 5, 3, 90);
    against_minimax(e, rules::RUSSIAN, "B:WKa1,c3,e3,g3:BKh2,b6,d6", 4, 2, 60);
    against_minimax(e, rules::INTERNATIONAL, "W:W31-50:B1-20", 3, 2, 40);
    against_minimax(e, rules::INTERNATIONAL, "W:W27,30,31,34,37,38,39,40,43,44,46,47,50:B1,3,4,7,9,12,13,14,16,17,18,23,29", 3, 3, 90);
    against_minimax(e, rules::INTERNATIONAL, "W:WK46,32,33,38:BK5,18,19,24", 3, 2, 60);
    against_minimax(e, rules::BRAZILIAN, "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8", 4, 2, 40);
    against_minimax(e, rules::BRAZILIAN, "W:Wa1,g1,b2,d2,f2,h2,a3,g3,b4,a5,g5:Bd4,h4,e5,d6,f6,a7,c7,e7,g7,f8,h8", 4, 4, 0);
    against_minimax(e, rules::BRAZILIAN, "B:WKa1,c3,e3,g3:BKh2,b6,d6", 4, 2, 60);
    with_and_without_table(e, rules::RUSSIAN, "W:Wa1,e1,g1,b2,d2,f2,h2,a3,e3,f4,a5:Bg5,b6,d6,f6,h6,a7,c7,e7,g7,b8,f8", 7, 6);
    with_and_without_table(e, rules::RUSSIAN, "B:WKa1,c3,e3,g3:BKh2,b6,d6", 7, 4);
    with_and_without_table(e, rules::INTERNATIONAL, "W:W25,32,33,34,35,36,38,39,40,42,43,44,46,47,49,50:B1,2,3,4,7,9,11,13,14,15,16,18,19,20,23,24", 5, 6);
    with_and_without_table(e, rules::INTERNATIONAL, "W:WK46,32,33,38:BK5,18,19,24", 6, 4);
    with_and_without_table(e, rules::BRAZILIAN, "W:Wb2,h2,c3,e3,b4,d4,h4:Bf4,a5,g5,f6,h6,a7,e7", 7, 6);
    with_and_without_table(e, rules::BRAZILIAN, "B:WKa1,c3,e3,g3:BKh2,b6,d6", 7, 4);
}
