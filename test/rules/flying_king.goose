// Flying kings take from a distance and may land on any empty square behind
// the piece, unless some landing square lets the capture go on: then they
// must land on one of those.
import rules from "../../rules";
import check from "../";

fn main() {
    check::show(rules::RUSSIAN, "W:WKa1:Bd4");
    // From f6 the king can go on over e7, so it must land there.
    check::show(rules::RUSSIAN, "W:WKa1:Bd4,e7");
    // A piece of its own, or two in a row, stops it.
    check::show(rules::RUSSIAN, "W:WKa1,f6:Bd4");
    check::show(rules::RUSSIAN, "W:WKa1:Bd4,e5");
    // International, on the 46-5 diagonal.
    check::show(rules::INTERNATIONAL, "W:WK46:B28");
    // English kings move one square and take only a piece next to them.
    check::show(rules::ENGLISH, "W:WK29:B18");
    check::show(rules::ENGLISH, "W:WK29:B25");
}
