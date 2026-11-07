// International: a capture must take the most pieces, and a king counts as
// one piece like a man. Russian lets the player choose.
import rules from "../../rules";
import check from "../";

fn main() {
    // c3 can take two (d4, f6), h2 one (g3): only c3's capture is legal.
    check::show(rules::INTERNATIONAL, "W:Wc3,h2:Bd4,f6,g3");
    check::show(rules::RUSSIAN, "W:Wc3,h2:Bd4,f6,g3");
    // Two men beat one king.
    check::show(rules::INTERNATIONAL, "W:Wc3,h2:Bd4,f6,Kg3");
    // A capture beats every plain move, however long.
    check::show(rules::INTERNATIONAL, "W:WKa1,h2:Bg3");
}
