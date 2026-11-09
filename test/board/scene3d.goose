// The 3D board's frame from the game's state (view3d::fill, task 015), headless: it is
// filled from the same draw lists the flat board draws (board::fill), so both follow one
// state and one animation. A selected man lifted and grown, with its glow; a stacked king
// two instances; a crowned king one; the last move's squares and the targets in the
// world's grid, which a turned board turns; a move in flight with its hop and the pieces
// it takes fading; the must-capture rings pulsing; a dragged piece. And what a new frame
// changes against the last drawn (view3d::changes): nothing for the same frame, the draw
// for a mark or a ring, the shadow map too when a piece moves or lifts.
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

fn r2(x: f32) -> f64 { floor(x * 100.0 + 0.5) / 100.0 }

fn v4(v: float4) -> u8[>..] { str(r2(v.x), " ", r2(v.y), " ", r2(v.z), " ", r2(v.w)) }

// The world grid's marked squares as row.column, row 0 the far side.
fn cells(n: i64, bits: u32[4]&) -> u8[>..] {
    var s: u8[>..] = [];
    for i in n * n {
        if (bits[i / 32] >> (i % 32)) & 1 != 0 { format(s, i / n, ".", i % n, " "); }
    }
    return s;
}

// Every instance: its foot and scale, then its kind, then its state's first float4.
fn show(s: view3d::Scene&, what: const u8[:]) {
    print(what, ": ", s.inst.len / 2, " instances");
    var i = 0;
    while i < s.inst.len {
        let k = s.inst[i + 1];
        let st = s.state[i];
        // Only the interesting ones: lifted, a king's disc, fading, ringed.
        if s.inst[i].y > 0.0 || k.y > 0.0 || k.z > 0.0 || st.x < 1.0 || st.y > 0.0 || st.z > 0.0 {
            print("  foot ", v4(s.inst[i]), "; kind ", v4(k), "; state ", v4(st));
        }
        i += 2;
    }
    print("  selected ", v4(s.selected), "; last ", cells(s.view.n, s.marks.last), "; targets ",
          cells(s.view.n, s.marks.target), "; flash ", v4(s.flash));
}

fn main() {
    strings::use(strings::EN);
    let l0 = panel::corners_in(float4 { 0.0, 0.0, 1280.0, 800.0 }, 8, 1.0);
    var l = l0.board;
    let v = l0.view;
    let vr .= rules::VARIANTS[rules::RUSSIAN];
    var b = board::new(rules::RUSSIAN);
    b.hints = board::MOVES;
    b.king_look = board::STACK;
    // A king on h4 for white, so a stack shows; then c3 selected.
    let p, ok = rules::parse_fen("W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,Kh4:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8", rules::RUSSIAN);
    assert(ok);
    board::set(b, p);
    board::press(b, l, drive::at(l, "c3"), 0.0);
    board::release(b, l, drive::at(l, "c3"), 0.0);
    var s = view3d::Scene {};
    var was = view3d::Scene {};
    board::fill(b, l, 0.1);
    view3d::fill(s, b, l, v);
    show(s, "c3 selected, the king on h4 a stack");
    let same = s;
    print("the same frame again changes ", view3d::changes(same, s));

    // Turned: the same position seen from black's side, c3's targets at the far side.
    var t = l;
    t.flip = true;
    board::fill(b, t, 0.1);
    var ts = view3d::Scene {};
    view3d::fill(ts, b, t, v);
    print("turned: selected ", v4(ts.selected), ", targets ", cells(8, ts.marks.target));

    // A crowned king: one instance with its crown.
    b.king_look = board::CROWN;
    board::fill(b, l, 0.1);
    was = s;
    view3d::fill(s, b, l, v);
    print("crowned king: ", s.inst.len / 2, " instances, changes ", view3d::changes(was, s));
    b.king_look = board::STACK;

    // c3 to d4, halfway through its hop.
    board::press(b, l, drive::at(l, "d4"), 1.0);
    board::fill(b, l, 1.1);
    was = s;
    view3d::fill(s, b, l, v);
    show(s, "c3 to d4, halfway");
    print("changes ", view3d::changes(was, s));
    board::update(b, 2.0);

    // Black must capture with c5: h8 touched is a wrong tap, its ring flashing and c5 pulsing;
    // then c5 takes d4, filled halfway through the taken piece's fade.
    let q, ok2 = rules::parse_fen("B:Wd4:Bc5,h8", rules::RUSSIAN);
    assert(ok2);
    board::set(b, q);
    board::press(b, l, drive::at(l, "h8"), 3.0);  // can't move while c5 must capture
    board::fill(b, l, 3.2);
    view3d::fill(s, b, l, v);
    show(s, "h8 touched while c5 must capture");
    board::update(b, 10.0);
    board::press(b, l, drive::at(l, "c5"), 10.0);
    board::press(b, l, drive::at(l, "e3"), 10.0);
    print("capture moving ", b.moving, ", ", rules::fen(b.pos));
    board::fill(b, l, 10.0 + board::HOP + 0.09);
    view3d::fill(s, b, l, v);
    show(s, "c5 takes d4, the taken piece fading");

    // A drag: the piece held over the board, lifted higher and grown.
    board::update(b, 20.0);
    let r, ok3 = rules::parse_fen("W:Wc3:Bh8", rules::RUSSIAN);
    assert(ok3);
    board::set(b, r);
    board::press(b, l, drive::at(l, "c3"), 21.0);
    let to = drive::at(l, "d4");
    board::drag(b, l, to);
    board::fill(b, l, 21.1);
    was = s;
    view3d::fill(s, b, l, v);
    show(s, "c3 dragged over d4");
    print("changes ", view3d::changes(was, s));
    // Only the targets' marks changing: drawn again, no shadow map.
    was = s;
    s.marks.target[0] ^= 1;
    print("a mark changes ", view3d::changes(was, s));
    // The camera turned: drawn again.
    was = s;
    s.view = view3d::turned(v, view3d::Camera { pitch: 52.5, yaw: 10.0 });
    print("the camera turned changes ", view3d::changes(was, s));
}
