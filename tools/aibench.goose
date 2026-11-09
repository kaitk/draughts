// Times the computer player: for each level, the time and nodes it takes to reply in
// a few middlegame positions of each variant, and its speed in nodes a second.
//
//   goose build -o build/aibench tools/aibench.goose
//   build/aibench [russian|international|brazilian] [FEN]
//
// Prints one line per position and level: the move, the deepest iteration finished,
// nodes, milliseconds; then each level's slowest reply and the nodes a second overall.
import std;
import os;
import rules from "../src/rules";
import ai from "../src/ai";

// The start, then middlegames reached by the medium level playing itself
// (tools/aimatch.goose --fens).
let RUSSIAN_FENS = [
    "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8",
    "W:Wa1,e1,g1,b2,d2,f2,h2,a3,e3,f4,a5:Bg5,b6,d6,f6,h6,a7,c7,e7,g7,b8,f8",
    "W:Wa1,e1,g1,f2,a3,e3,g3,b4,f4,a5:Bd4,h4,c5,g5,b6,d6,h6,a7,c7,b8,f8",
    "W:Wa1,c1,e1,g1,b2,d2,f2,a3,g3:Bd4,e5,d6,c7,e7,b8,d8,f8,h8",
    "W:Wc1,g1,d2,f2,g3,b4,a5:Bh4,g5,f6,h6,a7,c7,e7,b8",
];
let INTERNATIONAL_FENS = [
    "W:W31-50:B1-20",
    "W:W30,33,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50:B1,2,3,4,5,6,7,8,9,13,14,16,19,20,21,23,24",
    "W:W25,32,33,34,35,36,38,39,40,42,43,44,46,47,49,50:B1,2,3,4,7,9,11,13,14,15,16,18,19,20,23,24",
    "W:W31,35,36,38,39,40,41,43,44,45,46,47,48,49:B1,2,3,4,5,6,7,10,11,12,13,14,17,22",
    "W:W27,30,31,34,37,38,39,40,43,44,46,47,50:B1,3,4,7,9,12,13,14,16,17,18,23,29",
];

let BRAZILIAN_FENS = [
    "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8",
    "W:Wa1,c1,e1,g1,f2,h2,a3,e3,g3,b4,f4,a5:Bh4,c5,e5,d6,f6,a7,c7,e7,g7,b8,f8,h8",
    "W:Wa1,g1,b2,d2,f2,h2,a3,g3,b4,a5,g5:Bd4,h4,e5,d6,f6,a7,c7,e7,g7,f8,h8",
    "W:Wa1,g1,f2,h2,a3,c3,g3,b4:Bf4,h4,c5,e5,f6,a7,b8,f8,h8",
    "W:Wb2,h2,c3,e3,b4,d4,h4:Bf4,a5,g5,f6,h6,a7,e7",
];

fn bench(e: ai::Engine&, variant: u8, fen: const u8[:], slowest: f64[]&, nodes: i64[]&,
         seconds: f64[]&) {
    let p, ok = rules::parse_fen(fen, variant);
    if !ok {
        print("not a position: ", fen);
        exit(1);
    }
    print(fen);
    for level in ai::LEVELS {
        let t0 = clock();
        let m = ai::think(e, p, ai::level_skill(level), 1);
        let dt = clock() - t0;
        var text: u8[>..] = [];
        rules::format_move(text, variant, m);
        print("  level ", level, ": ", text, "  depth ", e.seen, "  nodes ", e.total_nodes,
              "  ", (dt * 1000.0) as i64, " ms");
        slowest[level] = max(slowest[level], dt);
        nodes[level] += e.total_nodes;
        seconds[level] += dt;
    }
}

fn main() {
    let a = args();
    var e = ai::Engine { .. };
    ai::init(e);
    var slowest: f64[] = [0.0, 0.0, 0.0];
    var nodes:   i64[] = [0, 0, 0];
    var seconds: f64[] = [0.0, 0.0, 0.0];
    let both = a.len < 2;
    if both || a[1] == "russian" {
        if a.len >= 3 { bench(e, rules::RUSSIAN, a[2], slowest, nodes, seconds); }
        else { for f in RUSSIAN_FENS { bench(e, rules::RUSSIAN, f, slowest, nodes, seconds); } }
    }
    if both || a[1] == "international" {
        if a.len >= 3 { bench(e, rules::INTERNATIONAL, a[2], slowest, nodes, seconds); }
        else { for f in INTERNATIONAL_FENS { bench(e, rules::INTERNATIONAL, f, slowest, nodes, seconds); } }
    }
    if both || a[1] == "brazilian" {
        if a.len >= 3 { bench(e, rules::BRAZILIAN, a[2], slowest, nodes, seconds); }
        else { for f in BRAZILIAN_FENS { bench(e, rules::BRAZILIAN, f, slowest, nodes, seconds); } }
    }
    for level in ai::LEVELS {
        let rate = if seconds[level] > 0.0 { nodes[level] / seconds[level] } else { 0.0 };
        print("level ", level, ": slowest ", (slowest[level] * 1000.0) as i64, " ms, ",
              (rate / 1000.0) as i64, "k nodes/s");
    }
}
