// The computer player sees draws (rules/draw.goose): a draw on the way scores 0, so the
// side behind steers into one and the side ahead steers clear of it. Each position is
// searched as the game reached it (ai::think_after with the game's past) and as if the
// game began there (ai::think), printing the move chosen and the score of the move that
// draws, for the side to move, in hundredths of a man.
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";
import check from "../";

fn text(variant: u8, m: rules::Move&) -> u8[>..] {
    var t: u8[>..] = [];
    rules::format_move(t, variant, m);
    return t;
}

// Plays `line` from fen, then searches the position reached at `skill` both ways and
// prints each choice and the score of the move `drawing`.
fn search(e: ai::Engine&, variant: u8, fen: const u8[:], line: const u8[:][:], past: rules::Past&,
          drawing: const u8[:]) {
    var p = check::position(variant, fen);
    var moves: rules::Moves = [];
    for want in line {
        rules::generate(p, moves);
        var found = false;
        for i in moves.len {
            guard text(variant, moves[i]) == want else { continue; }
            let q = rules::play(p, moves[i]);
            rules::pass(past, p, moves[i], q);
            p = q;
            found = true;
            break;
        }
        if !found { print("  no move ", want); }
    }
    print(rules::fen(p), "  quiet ", past.draw.quiet, ", seen ", past.draw.seen);
    for way in 2 {
        let m = if way == 0 { ai::think_after(e, past, p, 100, 1) } else { ai::think(e, p, 100, 1) };
        var score = 0;
        for i in e.moves.len { if text(variant, e.moves[i]) == drawing { score = e.main_score[i]; } }
        print("  ", if way == 0 { "as played: " } else { "afresh:    " }, text(variant, m), ", ", drawing, " scores ", score);
    }
}

fn main() {
    var e = ai::Engine { .. };
    e.node_limit = 60000;
    let R: u8 = rules::RUSSIAN;
    // Black, two kings against two kings and two men, has been round a1–b8 and back
    // twice; a7-b8 makes the start's position a third time: as played it draws (0), and
    // black takes it; afresh it is just a move.
    let cycle = ["c1-d2", "b8-a7", "d2-c1", "a7-b8", "c1-d2", "b8-a7", "d2-c1"];
    var past = rules::Past { draw: rules::draw_start(check::position(R, "W:WKc1,Ke1,g3,h2:BKb8,Kh8")), before: [] };
    search(e, R, "W:WKc1,Ke1,g3,h2:BKb8,Kh8", cycle, past, "a7-b8");
    // White, ahead, at the same third time: d2-c1 would draw, and white plays another.
    let ahead = ["b8-a7", "c1-d2", "a7-b8", "d2-c1", "b8-a7", "c1-d2", "a7-b8"];
    past = rules::Past { draw: rules::draw_start(check::position(R, "B:WKc1,Ke1,g3,h2:BKb8,Kh8")), before: [] };
    search(e, R, "B:WKc1,Ke1,g3,h2:BKb8,Kh8", ahead, past, "d2-c1");
    // International, only kings moved for 49 plies: any king's move draws on the 50th,
    // a man's move doesn't, and white, ahead, moves a man.
    let I: u8 = rules::INTERNATIONAL;
    let p = check::position(I, "W:WK47,K49,36,40:BK4");
    past = rules::Past { draw: rules::draw_start(p), before: [] };
    past.draw.quiet = 49;
    past.draw.calm = 49;
    search(e, I, "W:WK47,K49,36,40:BK4", [], past, "47-42");
}
