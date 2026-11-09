// The lookout's threats (ai/lookout.goose, docs/architecture/ai.md, "The lookout"): what
// the other side could take or crown on were it its turn, each sorted by how plain it is.
// The prototype's three positions (prototypes/coach.html, Russian, white the player):
// calm, where black would take d4 and g3, each by the man next to it; held, where b4 to
// a5 opens c5 and c3 to d6's double jump; king, where d2 crowns on e1 by a step. Then a
// flying king taking from afar (International, 5 over 28), a man's triple jump that
// crowns on its way (Russian, a7 over b6, d4, f2 to g1), and every move of calm with
// what it would leave open: a man moved next to an attacker is marked on its square.
import std;
import rules from "../../src/rules";
import ai from "../../src/ai";
import check from "../";

let NAMES = ["near", "far", "two", "many", "step", "jump"];

// The squares of bits, in the variant's notation, sorted.
fn squares(variant: u8, bits: u64) -> u8[>..] {
    let v .= rules::VARIANTS[variant];
    var names: u8[..8][>..] = [];
    var left = bits;
    while left != 0 {
        let s = ctz(left);
        left &= left - 1;
        var t: u8[>..] = [];
        rules::format_square(t, v, s);
        let n .= names.push([]);
        n.append(t);
    }
    sort(names) { a, b => a.len < b.len || (a.len == b.len && compare(a, b) < 0) };
    var out: u8[>..] = [];
    for n, i in names {
        if i > 0 { out.push(' '); }
        out.append(n);
    }
    if names.len == 0 { out.append("-"); }
    return out;
}

// Each kind of s that holds anything, on one line.
fn kinds(variant: u8, s: lookout::Seen&) -> u8[>..] {
    var out: u8[>..] = [];
    for k in lookout::KINDS {
        guard s.of[k] != 0 else { continue; }
        if out.len > 0 { out.append(", "); }
        format(out, NAMES[k], " ", squares(variant, s.of[k]));
    }
    if out.len == 0 { out.append("nothing"); }
    return out;
}

fn show_now(name: const u8[:], variant: u8, fen: const u8[:]) {
    let p = check::position(variant, fen);
    var buf: rules::Moves = [];
    var s = lookout::Seen {};
    lookout::now(p, s, buf);
    print(name, " now: ", kinds(variant, s));
}

fn main() {
    let calm = "W:Wa1,c1,e1,g1,b2,d2,h2,a3,e3,g3,d4:Bb8,d8,f8,h8,a7,c7,e7,g7,b6,f6,e5,h4";
    let held = "W:Wa1,c1,e1,g1,b2,f2,h2,c3,g3,b4,c5:Bb8,d8,f8,h8,a7,e7,g7,d6,f6,h6";
    let king = "W:Wc1,g1,h2,a3,g3,b4,c5:Bd2,e3,d6,a7,c7,e7,f8,h8";
    show_now("calm", rules::RUSSIAN, calm);
    show_now("held", rules::RUSSIAN, held);
    show_now("king", rules::RUSSIAN, king);
    show_now("flying king", rules::INTERNATIONAL, "W:W28,48:BK5,3");
    show_now("triple", rules::RUSSIAN, "W:Wa1,b6,d4,f2:Ba7");

    var buf:   rules::Moves = [];
    var moves: rules::Moves = [];
    for name, i in ["held", "calm", "king"] {
        let fen = if i == 0 { held } else if i == 1 { calm } else { king };
        let p = check::position(rules::RUSSIAN, fen);
        rules::generate(p, moves);
        var lines: u8[..120][>..] = [];
        for &m in moves {
            var s = lookout::Seen {};
            lookout::after(p, m, s, buf);
            var t: u8[>..] = [];
            rules::format_move(t, rules::RUSSIAN, m);
            let line .= lines.push([]);
            line.append(str(name, " after ", t, ": ", kinds(rules::RUSSIAN, s)));
        }
        sort(lines) { a, b => compare(a, b) < 0 };
        for l in lines { print(l); }
    }
}
