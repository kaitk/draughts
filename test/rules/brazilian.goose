// Brazilian: International's rules on 8×8. A capture must take the most
// pieces, and a man is crowned only if its move ends on the far row; one that
// passes it in the middle of a capture stays a man and goes on as one.
import rules from "../../rules";
import check from "../";

fn main() {
    // c3 can take two (d4, f6), h2 one (g3): only c3's capture is legal, where
    // Russian lets h2 take too (majority.goose).
    check::show(rules::BRAZILIAN, "W:Wc3,h2:Bd4,f6,g3");
    // The longest capture is a man's backward one, e5 over d4 and b2.
    check::show(rules::BRAZILIAN, "W:We5,h2:Bd4,b2,g3");
    // A flying king takes two, c3 then f6, landing on g7 or h8; h2's one is out.
    check::show(rules::BRAZILIAN, "W:WKa1,h2:Bc3,f6,g3");
    // b6 reaches d8 taking c7 and must go on, as a man, back over e7 to f6:
    // it ends uncrowned.
    check::show(rules::BRAZILIAN, "W:Wb6:Bc7,e7");
    check::play_only(rules::BRAZILIAN, "W:Wb6:Bc7,e7");
    // The same for black, crossing e1 on the way from g3 to c3.
    check::show(rules::BRAZILIAN, "B:Wd2,f2:Bg3");
    // Ending on the far row crowns. A man on d8 can't fly to g5 as Russian's
    // new king does (russian_crowning.goose), so the capture ends there.
    check::show(rules::BRAZILIAN, "W:Wb6:Bc7,g5");
    check::play_only(rules::BRAZILIAN, "W:Wb6:Bc7,g5");
}
