// Captured pieces stay on the board until the whole move ends, so no piece is
// jumped twice and a taken piece blocks the way (the Turkish strike rule).
import rules from "../../rules";
import check from "../";

fn main() {
    // The king goes round over b2, b4, d4, d2 and is back on c1. With pieces
    // taken off as they were jumped it could go on over d2's square and take
    // f4; d2 is still there, so that capture ends on c1 with four.
    check::show(rules::RUSSIAN, "W:WKc1:Bd2,d4,b4,b2,f4");
    check::play_only(rules::RUSSIAN, "W:WKc1:Bd2,d4,b4,b2");
    // Two pieces in a row can't be jumped.
    check::show(rules::RUSSIAN, "W:Wc1:Bd2,e3");
}
