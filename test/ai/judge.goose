// A played move judged (ai/judge.goose, task 074): every legal move of a position marked
// by the fall in the mover's expected result, as the full-strength search scores it.
// International's start, where every first move is sound and none may come out worse
// than an inaccuracy; and a Russian position where c3-d4 gives a man for nothing (e5
// takes it, landing on c3), g3-f4 offers an exchange (e5xg3, h2xf4), and g3-h4 and the
// rest keep everything: the hanging move must be a blunder, the others not. Then the
// marks' cut-offs and the accuracy at a few falls, and the computer's ratings and a
// player's rating after a game (ai/rating.goose).
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";
import check from "../";

let NAMES = ["-", "only", "best", "good", "?!", "?", "??"];

fn text(variant: u8, m: rules::Move&) -> u8[>..] {
    var t: u8[>..] = [];
    rules::format_move(t, variant, m);
    return t;
}

fn judge_all(e: ai::Engine&, variant: u8, fen: const u8[:]) {
    let p = check::position(variant, fen);
    var past = rules::Past { draw: rules::draw_start(p), before: [] };
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    print(rules::fen(p));
    for i in moves.len {
        let v = ai::judge(e, past, p, moves[i]);
        print("  ", text(variant, moves[i]), "  ", NAMES[v.mark], "  loss ", v.loss, "  best ", v.best, "  played ", v.played);
    }
}

fn main() {
    var e = ai::Engine { .. };
    ai::init(e);
    // Far fewer nodes than the app's, to stay quick through TinyCC.
    e.node_limit = 30000;
    judge_all(e, rules::INTERNATIONAL, "W:W31-50:B1-20");
    judge_all(e, rules::RUSSIAN, "W:Wc3,g3,h2:Be5,a7,h8");

    // The one legal move: no search.
    let p = check::position(rules::RUSSIAN, "W:Wc3:Bd4");
    var past = rules::Past { draw: rules::draw_start(p), before: [] };
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    print("forced ", text(rules::RUSSIAN, moves[0]), "  ", NAMES[ai::judge(e, past, p, moves[0]).mark]);

    print("expected at -300, -100, 0, 100, 300, won: ", ai::expected(-300), " ", ai::expected(-100), " ",
          ai::expected(0), " ", ai::expected(100), " ", ai::expected(300), " ", ai::expected(ai::WIN - 10));
    for loss in [0, 9, 10, 49, 50, 99, 100, 199, 200, 500] {
        print("loss ", loss, ": ", NAMES[ai::mark_of(loss)], ", accuracy ", ai::accuracy(loss));
    }

    for skill in [0, 8, 10, 25, 30, 40, 60, 90, 100] { print("skill ", skill, " rated ", ai::skill_rating(skill)); }
    print("800 against 800: won ", ai::rate(800, 800, 1, 0), ", drawn ", ai::rate(800, 800, 0, 0), ", lost ",
          ai::rate(800, 800, -1, 0));
    print("800 against 1644 (medium), 25 games: won ", ai::rate(800, 1644, 1, 25), ", lost ", ai::rate(800, 1644, -1, 25));
    print("150 losing to 587 (easy): ", ai::rate(150, 587, -1, 3), ", at the floor: ", ai::rate(100, 587, -1, 3));
}
