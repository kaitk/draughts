// The piece shader (src/gfx/draw_gpu.goose's PIECE_VERT, and the ngfx build's written
// from it) steps through the uploaded board::Piece array PIECE_VEC4S float4s at a time.
// A Piece of any other size shifts every piece after the first: 0.9.2's id made it 68
// bytes against the shader's 64, and the flat board showed only every 17th piece.
import std;
import vec;
import math;
import rules from "../../src/rules";
import board from "../../src/board";
import model3d from "../../src/model3d";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";

// The value of `const int NAME = X;` in the text, and whether there is one.
fn constant(text: const u8[:], name: const u8[:]) -> i64, bool {
    let key = str("const int ", name, " = ");
    var rest: const u8[:] = text;
    while rest.len > 0 {
        let line, after, more = split_once(rest, "\n");
        let t = trim(line);
        if t.len > key.len && t[..key.len] == key[..] {
            let v, end, found = split_once(t[key.len..], ";");
            let x, ok = parse_int(v);
            return x, found && ok;
        }
        rest = if more { after } else { "" };
    }
    return 0, false;
}

fn main() {
    var ps: board::Piece[2] = [board::Piece {}; 2];
    let bytes = bytes_of(ps).len / 2;
    let n, ok = constant(embed_file("../../src/gfx/draw_gpu.goose"), "PIECE_VEC4S");
    let same = ok && bytes == 16 * n;
    print("board::Piece: ", bytes, " bytes; shader: ", if ok { str(16 * n, " bytes") } else { str("missing") },
          if same { "" } else { "  DIFFERS" });
    if !same { exit(1); }
}
