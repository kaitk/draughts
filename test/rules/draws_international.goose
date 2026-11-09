// International draws (FMJD Annex 1, 6.1–6.4; docs/architecture/rules.md, "Draws"), each
// count shown at its edge: the plies before the draw with their countdown, and the ply
// of the draw. A move is one side's; 25 moves each is 50 plies.
import rules from "../../src/rules";
import check from "../";

fn main() {
    let I: u8 = rules::INTERNATIONAL;
    // 6.2: only kings moved, nothing taken: drawn on the 50th ply.
    check::walk(I, "W:WK47,K49:BK2,K4", [], check::Walk {}, 80);
    // A man's move restarts it: black's man moves on ply 20, so the draw comes on ply 70.
    check::walk(I, "W:WK47,K49,36:BK2,K4,15", [], check::Walk { men: [20], .. }, 100);
    // 6.4: two kings against one, 5 moves each from the start: ply 10.
    check::walk(I, "W:WK47,K49:BK4", [], check::Walk {}, 40);
    // Two men against a king count nothing until one is crowned; that move starts 6.4,
    // which a second crowning doesn't restart: drawn 10 plies after ply 1.
    check::walk(I, "W:W7,38:BK45", ["7-2"], check::Walk {}, 40);
    // 6.3: three kings against one, 16 moves each: ply 32.
    check::walk(I, "W:WK46,K47,K49:BK4", [], check::Walk {}, 60);
    // Made by a capture, which doesn't count: from ply 1, drawn on ply 33.
    check::walk(I, "W:WK47,K49,K50:BK4,28", ["50x17"], check::Walk {}, 60);
    // 6.1: the same position a third time, not in a row: back at the start on plies 4
    // and 8 by two different ways.
    check::walk(I, "W:WK47,K49:BK2,K4", ["47-42", "2-8", "42-47", "8-2", "49-44", "4-9", "44-49", "9-4"], check::Walk {}, 20);
}
