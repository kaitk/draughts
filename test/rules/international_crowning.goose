// International: a man is crowned only if its move ends on the far row. One
// that passes it in the middle of a capture stays a man and goes on as one.
// Squares are given as a1..j10 and printed as numbers (b8 is 11, d10 is 2).
import rules from "../../src/rules";
import check from "../";

fn main() {
    check::show(rules::INTERNATIONAL, "W:Wb8:Bc9,e9");
    check::play_only(rules::INTERNATIONAL, "W:Wb8:Bc9,e9");
    check::show(rules::INTERNATIONAL, "W:Wb8:Bc9");
    check::play_only(rules::INTERNATIONAL, "W:Wb8:Bc9");
}
