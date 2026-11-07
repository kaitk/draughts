// Russian: a man reaching the far row in the middle of a capture is crowned
// at once and goes on capturing as a king, here along the d8-h4 diagonal that
// a man couldn't take on.
import rules from "../../rules";
import check from "../";

fn main() {
    check::show(rules::RUSSIAN, "W:Wb6:Bc7,g5");
    check::play_only(rules::RUSSIAN, "W:Wb6:Bc7,g5");
    // Crowned when the capture ends on the far row too, and on a plain move.
    check::show(rules::RUSSIAN, "W:Wb6:Bc7");
    check::show(rules::RUSSIAN, "B:Wa1:Bb2");
    // The same in English (d6 is 10, e7 7, g7 8): reaching the far row ends
    // the move, even with more to take.
    check::show(rules::RUSSIAN, "W:Wd6:Be7,g7");
    check::show(rules::ENGLISH, "W:W10:B7,8");
}
