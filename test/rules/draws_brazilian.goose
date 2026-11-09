// Brazilian draws (FMJD-64's rules, 7.2.3–7.2.8; docs/architecture/rules.md, "Draws"),
// each count shown at its edge, and English, which has repetition only.
import rules from "../../src/rules";
import check from "../";

fn main() {
    let B: u8 = rules::BRAZILIAN;
    // 7.2.5: only kings moved, 15 moves each at any material: ply 30.
    check::walk(B, "W:WKa1,Kc1,Ke1,Kg1:BKb8,Kd8,Kf8,Kh8", [], check::Walk {}, 80);
    // 7.2.6: nothing taken or crowned, with a man moved on plies 21 and 42: 30 moves
    // each with 4 or 5 pieces, ply 60.
    check::walk(B, "W:WKc1,g3:BKf8,b6", [], check::Walk { men: [21, 42], .. }, 100);
    // 7.2.4: three kings against one: the strong side's 15th move, ply 29.
    check::walk(B, "W:WKc1,Ke1,Kg1:BKb8", [], check::Walk { road: 1, .. }, 60);
    // 7.2.8: two kings against one: its 5th move, ply 9.
    check::walk(B, "W:WKc1,Ke1:BKb8", [], check::Walk {}, 60);
    // 7.2.7: two kings and a man against a king on the long diagonal: ply 9.
    check::walk(B, "W:WKa3,Kc1,h2:BKd4", [], check::Walk { road: 99, .. }, 60);
    // A king and two men off the diagonal have no count but only kings moving: ply 30.
    check::walk(B, "W:WKc1,a3,h2:BKb8", [], check::Walk { road: 1, .. }, 60);
    // 7.2.3: the same position a third time.
    check::walk(B, "W:WKa1,Kc1,Ke1,Kg1:BKb8,Kd8,Kf8,Kh8",
                ["c1-d2", "d8-c7", "d2-c1", "c7-d8", "e1-f2", "f8-e7", "f2-e1", "e7-f8"], check::Walk {}, 20);
    // English: no count, only repetition.
    let E: u8 = rules::ENGLISH;
    check::walk(E, "B:WK29,K30:BK3,K4", [], check::Walk {}, 60);
    check::walk(E, "B:WK29,K30:BK3,K4", ["3-7", "29-25", "7-3", "25-29", "4-8", "30-26", "8-4", "26-30"], check::Walk {}, 20);
}
