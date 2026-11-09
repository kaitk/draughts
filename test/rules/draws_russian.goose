// Russian draws (the 2022 sport rules, 5.4.13 and 6.1.8.3–6.1.8.8;
// docs/architecture/rules.md, "Draws"), each count shown at its edge: the plies before
// the draw with their countdown, and the ply of the draw.
import rules from "../../src/rules";
import check from "../";

fn main() {
    let R: u8 = rules::RUSSIAN;
    // 6.1.8.8: only kings moved, 15 moves each with 4 or 5 pieces (ply 30), 25 with 6 or
    // 7 (ply 50), and no such count with 8 (nor 6.1.8.6, which ends at 7).
    check::walk(R, "W:WKc1,Ke1:BKd8,Kf8", [], check::Walk {}, 80);
    check::walk(R, "W:WKc1,Ke1,Kg1:BKb8,Kd8,Kf8", [], check::Walk {}, 80);
    check::walk(R, "W:WKa1,Kc1,Ke1,Kg1:BKb8,Kd8,Kf8,Kh8", [], check::Walk {}, 130);
    // 6.1.8.6: both sides with kings and nothing taken or crowned: 5 moves each with 2 or
    // 3 pieces (ply 10); 30 with 4 or 5 (ply 60), here with a man moved on plies 21 and
    // 42 so that the kings alone never move for 15 moves each; each man steps to the edge,
    // where nothing can take it.
    check::walk(R, "W:WKc1:BKf8", [], check::Walk {}, 40);
    check::walk(R, "W:WKc1,Ke1:BKf8", [], check::Walk {}, 40);
    check::walk(R, "W:WKc1,g3:BKf8,b6", [], check::Walk { men: [21, 42], .. }, 100);
    // 6.1.8.3: three kings against one, off the main road: drawn on the strong side's
    // 15th move, ply 29 with white to move.
    check::walk(R, "W:WKc1,Ke1,Kg1:BKb8", [], check::Walk { road: 1, .. }, 60);
    // 6.1.8.4, three kings and a man: the same.
    check::walk(R, "W:WKc1,Ke1,Kg1,h2:BKb8", [], check::Walk {}, 60);
    // Made by black's crowning, after which white moves first: white's 15th move is
    // ply 30.
    check::walk(R, "B:WKa5,Kc5,Kg5:Bb2", ["b2-c1"], check::Walk { road: 1, .. }, 60);
    // 6.1.8.5: three pieces off the main road against a lone king on it: drawn on the
    // strong side's 5th move, ply 9; three kings, and three men.
    check::walk(R, "W:WKa3,Kc1,Kh4:BKd4", [], check::Walk { road: 99, .. }, 60);
    check::walk(R, "W:Wa3,c1,e1:BKf6", [], check::Walk { road: 99, .. }, 60);
    // The king leaves the road on ply 4: that count stops for good, and 6.1.8.3's runs
    // on to ply 29.
    check::walk(R, "W:WKa3,Kc1,Kh4:BKd4", ["h4-e1", "d4-e5", "e1-d2", "e5-h2"], check::Walk { road: 3, .. }, 60);
    // 5.4.13: the same position a third time, not in a row.
    check::walk(R, "W:WKa1,Kc1,Ke1,Kg1:BKb8,Kd8,Kf8,Kh8",
                ["c1-d2", "d8-c7", "d2-c1", "c7-d8", "e1-f2", "f8-e7", "f2-e1", "e7-f8"], check::Walk {}, 20);
}
