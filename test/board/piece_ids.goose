// Each piece's id (board::Piece.id, the 3D figure's seed) stays with the piece: while it
// is dragged, while it moves, on the square it lands on, and back on its square with the
// piece it took after an undo. The dragged and the moving piece are drawn last, so an id
// taken from the drawing order would hand every later piece another's figure.
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
import drive from "../drive";

// The drawn pieces by id: the square each stands on, or "held" off any square.
fn show(b: board::Board&, l: board::Layout, what: const u8[:]) {
    let v .= rules::VARIANTS[b.variant];
    var line: u8[>..] = [];
    var id = 0;
    while id < 64 {
        for p in b.pieces {
            guard p.id as i64 == id else { continue; }
            var at: u8[>..] = "held";
            var dark = v.mask;
            while dark != 0 {
                let sq = ctz(dark);
                dark &= dark - 1;
                let c = board::center(l, v, sq);
                if length(float2 { p.at.x, p.at.y } - c) < 0.1 * l.inner.w { at = drive::name(v, sq); }
            }
            format(line, " ", id, if p.look.x > 0.5 { " black " } else { " white " }, at[..]);
        }
        id++;
    }
    print(what, ":", line[..]);
}

fn main() {
    strings::use(strings::EN);
    let l = panel::corners_in(float4 { 0.0, 0.0, 1280.0, 800.0 }, 8, 1.0).board;
    var b = board::new(rules::RUSSIAN);
    // White must take d4 with c3 or e3; c3 takes it, dragged to e5.
    let p, ok = rules::parse_fen("W:Wc3,e3,g3:Bd4,h8", rules::RUSSIAN);
    assert(ok);
    board::set(b, p);
    board::build_frame_pieces(b, l, 0.0);
    show(b, l, "at rest");
    board::press(b, l, drive::at(l, "c3"), 0.0);
    board::drag(b, l, drive::at(l, "c3") + 0.3 * (drive::at(l, "e5") - drive::at(l, "c3")));
    board::build_frame_pieces(b, l, 0.1);
    show(b, l, "c3 dragged");
    board::drag(b, l, drive::at(l, "e5"));
    board::release(b, l, drive::at(l, "e5"), 0.2);
    let m = b.move;
    board::build_frame_pieces(b, l, 0.2);
    show(b, l, "dropped on e5");
    board::update(b, 2.0);
    board::build_frame_pieces(b, l, 2.0);
    show(b, l, "landed");
    // Taken back: c3 slides home and d4 comes back with its own id.
    assert(board::slide_back(b, rules::Move { from: m.from, to: m.to, crowned: m.crowned, captured: m.captured }, 3.0, false));
    board::update(b, 3.1);
    board::build_frame_pieces(b, l, 3.1);
    show(b, l, "sliding back");
    board::update(b, 5.0);
    board::build_frame_pieces(b, l, 5.0);
    show(b, l, "undone");
}
