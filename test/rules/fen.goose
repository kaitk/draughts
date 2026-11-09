// Reading and writing positions: numbers, a1..h8, ranges, kings, and what is
// refused.
import rules from "../../src/rules";
import check from "../";

fn round_trip(variant: u8, text: const u8[:]) {
    let p, ok = rules::parse_fen(text, variant);
    guard ok else { print(text, " -> refused"); return; }
    let out = rules::fen(p);
    let q, ok2 = rules::parse_fen(out, variant);
    assert(ok2 && q == p);
    print(text, " -> ", out);
}

fn main() {
    for v: u8 in 0..rules::VARIANT_COUNT { print(rules::fen(rules::start(v))); }
    round_trip(rules::INTERNATIONAL, "W:W31-50:B1-20");
    round_trip(rules::INTERNATIONAL, "B:WK46,31:BK5,19.");
    round_trip(rules::INTERNATIONAL, " W : W a1 , Kj10 : B b10 ");
    // Russian is written a1..h8 and read either way: 1 is b8, 32 is g1.
    round_trip(rules::RUSSIAN, "W:W1,32:BK29");
    round_trip(rules::RUSSIAN, "B:Wa1,Kh8:B");
    round_trip(rules::ENGLISH, "B:W21-32:B1-12");
    round_trip(rules::RUSSIAN, "W:W:B");
    // Refused: a light square, off the board, a square twice, no side.
    round_trip(rules::RUSSIAN, "W:Wa2:B");
    round_trip(rules::RUSSIAN, "W:Wi1:B");
    round_trip(rules::RUSSIAN, "W:W33:B");
    round_trip(rules::INTERNATIONAL, "W:W0:B");
    round_trip(rules::INTERNATIONAL, "W:W5:B5");
    round_trip(rules::INTERNATIONAL, "W:W20-10:B");
    round_trip(rules::INTERNATIONAL, "X:W1:B2");
    round_trip(rules::INTERNATIONAL, "W:W1:Q2");
    round_trip(rules::INTERNATIONAL, "W:WK:B2");
}
