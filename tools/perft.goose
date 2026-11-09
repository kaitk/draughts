// Counts the positions a number of moves ahead, to check move generation
// against published counts and against test/perft.py.
//
//   goose build -o build/perft tools/perft.goose
//   build/perft russian|international|english|brazilian DEPTH [FEN] [--divide | --moves]
//
// Prints each depth's count and time up to DEPTH. --divide prints the count
// below each move at DEPTH instead, one "move count" per line. --moves prints
// each legal move as its start, its end, and the squares it takes, sorted by
// number, the form test/perft.py compares.
import std;
import os;
import rules from "../src/rules";

fn variant_named(name: const u8[:]) -> u8, bool {
    if name == "russian" { return rules::RUSSIAN, true; }
    if name == "international" { return rules::INTERNATIONAL, true; }
    if name == "english" { return rules::ENGLISH, true; }
    if name == "brazilian" { return rules::BRAZILIAN, true; }
    return 0, false;
}

fn usage() {
    write_stderr("usage: perft russian|international|english|brazilian DEPTH [FEN] [--divide | --moves]\n");
    exit(2);
}

fn main() {
    let a = args();
    if a.len < 3 { usage(); }
    let variant, vok = variant_named(a[1]);
    let depth, dok = parse_int(a[2]);
    if !vok || !dok || depth < 1 { usage(); }
    var p = rules::start(variant);
    var divide = false;
    var list = false;
    for i in 3..a.len {
        if a[i] == "--divide" { divide = true; continue; }
        if a[i] == "--moves" { list = true; continue; }
        let q, ok = rules::parse_fen(a[i], variant);
        if !ok { write_stderr(str("not a position: ", a[i], "\n")); exit(2); }
        p = q;
    }
    if list {
        let v .= rules::VARIANTS[variant];
        var moves: rules::Moves = [];
        rules::generate(p, moves);
        for i in moves.len {
            let m = moves[i];
            var line: u8[>..] = [];
            rules::format_square(line, v, m.from);
            line.push(' ');
            rules::format_square(line, v, m.to);
            for n in 1..rules::squares(variant) + 1 {
                let b: i64 = v.bit_of[n];
                guard m.captured & rules::bit(b) != 0 else { continue; }
                line.push(' ');
                rules::format_square(line, v, b);
            }
            print(line);
        }
        return;
    }
    if divide {
        var moves: rules::Moves = [];
        rules::generate(p, moves);
        var total = 0;
        for i in moves.len {
            let n = rules::perft(rules::play(p, moves[i]), depth - 1);
            total += n;
            var line: u8[>..] = [];
            rules::format_move(line, variant, moves[i]);
            print(line, " ", n);
        }
        print("total ", total);
        return;
    }
    for d in 1..depth + 1 {
        let t = clock();
        let n = rules::perft(p, d);
        let s = clock() - t;
        var line: u8[>..] = [];
        format(line, d, " ", n, " ");
        format_flt(line, s, 3);
        line.append(" s");
        if s > 0.01 {
            line.append(", ");
            format_flt(line, n / s / 1000000.0, 1);
            line.append(" M/s");
        }
        print(line);
    }
}
