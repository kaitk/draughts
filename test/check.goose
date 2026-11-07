// What the tests under test/rules/ share. They declare test/ as a package,
// `import check from "../";`, since a program's own imports resolve below its
// root file's directory.
namespace check;
import std;
import rules from "../rules";

// The position fen gives, which must be well formed.
fn position(variant: u8, fen: const u8[:]) -> rules::Position {
    let p, ok = rules::parse_fen(fen, variant);
    if !ok { print("not a position: ", fen); assert(false); }
    return p;
}

// Prints the position, then its legal moves sorted, each with how many pieces
// it takes and whether it crowns.
fn show(variant: u8, fen: const u8[:]) {
    let p = position(variant, fen);
    print(rules::fen(p));
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    var lines: u8[..80][>..] = [];
    for i in moves.len {
        let m = moves[i];
        var text: u8[>..] = [];
        text.append("  ");
        rules::format_move(text, variant, m);
        if m.captured != 0 { format(text, "  takes ", popcount(m.captured)); }
        if m.crowned { text.append("  crowned"); }
        let line .= lines.push([]);
        line.append(text);
    }
    sort(lines) { a, b => compare(a, b) < 0 };
    for l in lines { print(l); }
    print(moves.len, if moves.len == 1 { " move" } else { " moves" });
}

// Plays the one legal move of the position and prints the position after it.
fn play_only(variant: u8, fen: const u8[:]) {
    let p = position(variant, fen);
    var moves: rules::Moves = [];
    rules::generate(p, moves);
    if moves.len != 1 { print(moves.len, " moves in ", fen, ", expected one"); assert(false); }
    print("after: ", rules::fen(rules::play(p, moves[0])));
}
