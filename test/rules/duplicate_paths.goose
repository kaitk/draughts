// The same start, end, and pieces taken make one move, however many ways lead
// there: the king goes round d2, d4, b4, b2 either way and is back on c1.
import rules from "../../src/rules";
import check from "../";

fn main() {
    check::show(rules::INTERNATIONAL, "W:WKc1:Bd2,d4,b4,b2");
    check::show(rules::RUSSIAN, "W:WKc1:Bd2,d4,b4,b2");
}
