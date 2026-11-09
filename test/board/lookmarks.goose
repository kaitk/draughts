// The lookout's and the hint's marks on the board (board::fill, view3d::fill; the
// rendering doc's "The lookout and the hint"): a piece in danger drained, solid and
// still; a crowning square shaded under the other side's dark ghost king; the hint's
// piece with its glow ring and, once shown, a light ghost of it on its square, whose
// ring pulses as the puzzles' hint's does and then stays, lit. On the 3D board a
// drained piece's seed is below 0, the shaded square's field.w 1, and only one ring
// pulses at a time, drawn over the kept image (Scene.pulse). A move clears them all.
// The prototype's king position (Russian): black's d2 crowns on e1; c5 in danger.
import std;
import vec;
import math;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";
import check from "../";

fn r2(x: f32) -> u8[>..] {
    var out: u8[>..] = [];
    format_flt(out, x as f64, 2);
    return out;
}

// The pieces fill drew with a mark: where, whose, a king, how opaque, the mark, the ring.
fn pieces(b: board::Board&, l: board::Layout) {
    let v .= rules::VARIANTS[b.variant];
    for p, i in b.pieces {
        guard p.ring.w != 0.0 || p.ring.y > 0.0 else { continue; }
        let sq = board::hit(l, v, float2 { p.at.x, p.at.y });
        let what = if p.ring.w > 0.5 { "drained" } else if p.ring.w < -0.5 { "light" } else { "plain" };
        print("  ", drive::name(v, sq), if p.look.x > 0.5 { " black" } else { " white" },
              if p.look.y > 0.5 { " king" } else { "" }, ", opacity ", r2(p.look.w), ", ", what, ", ring ",
              r2(p.ring.y), if i == b.pulsed { " pulsing" } else { "" });
    }
    print("  shaded: ", drive::marked(v, b.marks.shade));
}

fn scene(s: view3d::Scene&) {
    var drained = 0;
    for i in s.inst.len / 2 { if s.inst[2 * i + 1].w < 0.0 { drained++; } }
    var shaded = 0;
    for f in s.field { if f.w > 0.5 { shaded++; } }
    print("  3D: ", drained, " drained instances, ", shaded, " shaded squares, pulse square ", s.pulse.z,
          ", pulsing ", s.pulsing);
}

fn main() {
    strings::use(strings::EN);
    let pl = panel::layout(1280.0, 800.0, 8);
    let l = pl.board;
    let pl3 = panel::corners_in(float4 { 0.0, 0.0, 1280.0, 800.0 }, 8, 1.0);
    var b = board::new(rules::RUSSIAN);
    let v .= rules::VARIANTS[b.variant];
    board::set(b, check::position(rules::RUSSIAN, "W:Wc1,g1,h2,a3,g3,b4,c5:Bd2,e3,d6,a7,c7,e7,f8,h8"));
    b.danger = rules::bit(drive::square(v, "c5"));
    b.crowns = rules::bit(drive::square(v, "e1"));
    board::fill(b, l, 0.0);
    print("the lookout: c5 in danger, e1 a crowning square");
    pieces(b, l);
    var s = view3d::Scene {};
    view3d::fill(s, b, pl3.board, pl3.view, 0.0);
    scene(s);
    print("  animating: ", board::animating(b, 0.0));

    // The hint: c5's glow, pulsing, then its ghost on b6 whose ring pulses in its place.
    board::glow_on(b, drive::square(v, "c5"), 1.0);
    board::fill(b, l, 1.5);
    print("the hint's first step, at 0.5 s");
    pieces(b, l);
    view3d::fill(s, b, pl3.board, pl3.view, 1.5);
    scene(s);
    board::ghost_on(b, drive::square(v, "b6"), 2.0);
    board::fill(b, l, 2.5);
    print("its second step, 0.5 s on");
    pieces(b, l);
    view3d::fill(s, b, pl3.board, pl3.view, 2.5);
    scene(s);
    print("  animating: ", board::animating(b, 2.5), "; at 5 s: ", board::update(b, 5.0), ", ", board::animating(b, 5.0));
    board::fill(b, l, 5.0);
    print("still");
    pieces(b, l);
    view3d::fill(s, b, pl3.board, pl3.view, 5.0);
    scene(s);

    // The move clears every mark.
    var k = -1;
    for m, i in b.moves { if m.from == drive::square(v, "c5") && m.to == drive::square(v, "b6") { k = i; } }
    board::start_move(b, k, 6.0);
    board::update(b, 7.0);
    board::fill(b, l, 7.0);
    print("after c5-b6");
    pieces(b, l);
}
