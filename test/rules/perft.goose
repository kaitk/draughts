// Move counts from the start position: International, English, and Brazilian
// against published values, Russian against test/perft.py. tools/perft.goose goes
// deeper, natively.
import rules from "../../src/rules";

fn main() {
    for v: u8 in 0..rules::VARIANT_COUNT {
        let p = rules::start(v);
        for d in 1..6 { print(v, " ", d, " ", rules::perft(p, d)); }
    }
}
