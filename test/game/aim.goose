// Anywhere on a capture's landing square plays that capture: black against the computer
// on the turned International board (task 048, a report that a king was made to take
// where the player didn't mean), a king with four landings beyond the piece it takes and
// a man with two captures. Each capture is chosen by a tap on the piece and a tap at 25
// points spread over its landing square (to 0.4 of a square from its center), and by a
// drag dropped there, on the flat board and the 3D board, at the tablet's size in
// landscape and portrait. On the 3D board a tap goes to the field under the finger, and
// a dragged piece is held where the finger took it, on the plane of its lifted top
// (board::touch), so the drop is aimed with the piece over the point. Each line counts,
// per capture, the points that played it, played nothing, or played another.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

let V = rules::INTERNATIONAL;

fn number(sq: i64) -> i64 {
    let v .= rules::VARIANTS[V];
    for n in 1..rules::squares(V) + 1 { if v.bit_of[n] == sq { return n; } }
    return -1;
}

fn same(a: rules::Move, b: rules::Move) -> bool { a.from == b.from && a.to == b.to && a.captured == b.captured }

// A point of the flat layout at height h on the 3D board, on the screen.
fn on_screen(sh: shell::Shell&, flat: float2, h: f32) -> float2 {
    let c = view3d::to_world(sh.layout, flat);
    let q = view3d::project(sh.view, float3 { c.x, h, c.y });
    return float2 { q.x, q.y };
}

fn sweep(g: gui::Gui&, fen: const u8[:], size: float2, three: bool, by_drag: bool) {
    drive::size = size;
    g.scale = gui::scale_of(size.x, size.y);
    var t = 0.0;
    var sh = shell::new(V);
    if three {
        sh.prefs.board = settings::RAISED;
        shell::apply_prefs(sh);
    }
    game::start(sh.game, V, clock::NONE, rules::WHITE, game::MEDIUM, 40, 0);
    let p, ok = rules::parse_fen(fen, V);
    assert(ok);
    board::set(sh.game.b, p);
    sh.game.turn = sh.game.b.pos.side;
    sh.screen = shell::GAME;
    sh.drawn = shell::GAME;
    drive::idle(sh, g, t);
    let opts = sh.game.b.moves;
    var line: u8[>..] = [];
    var all = true;
    for m in opts {
        var good = 0;
        var none = 0;
        var other = 0;
        for i in 5 {
            for j in 5 {
                board::set(sh.game.b, p);
                drive::idle(sh, g, t);
                drive::idle(sh, g, t + 0.05);
                let l = sh.layout;
                let w = l.inner.w;
                let from = board::center(l, rules::VARIANTS[V], m.from);
                let to = board::center(l, rules::VARIANTS[V], m.to)
                         + float2 { (i as f32 - 2.0) * 0.2 * w, (j as f32 - 2.0) * 0.2 * w };
                var a = from;
                var q = to;
                if sh.raised {
                    let un = view3d::unit(l.n);
                    let stack = sh.game.b.pos.kings & rules::bit(m.from) != 0 && sh.game.b.king_look == board::STACK;
                    let discs: f32 = if stack { 2.0 } else { 1.0 };
                    a = on_screen(sh, from, discs * view3d::HEIGHT * un);
                    if by_drag {
                        let h = view3d::lift_of(l, view3d::FLAT_DRAG * l.board.z) + discs * view3d::HEIGHT * un * view3d::GROW;
                        let xz, on = view3d::on_plane(sh.view, a, h);
                        assert(on);
                        let grab = from - view3d::to_flat(l, xz);
                        q = on_screen(sh, to - grab, h);
                    } else {
                        q = on_screen(sh, to, 0.0);
                    }
                }
                if by_drag {
                    drive::frame(sh, g, a, true, true, false, t + 0.1);
                    for k in 1..5 {
                        let f = (k as f32) / 4.0;
                        drive::frame(sh, g, a + (q - a) * f, true, false, false, t + 0.1 + 0.02 * k);
                    }
                    drive::frame(sh, g, q, false, false, true, t + 0.22);
                } else {
                    drive::tap(sh, g, a, t + 0.1);
                    drive::tap(sh, g, q, t + 0.2);
                }
                drive::idle(sh, g, t + 3.0);
                if sh.game.b.history.len == 0 { none++; } else if same(sh.game.b.move, m) { good++; } else { other++; }
                t += 10.0;
            }
        }
        if good != 25 { all = false; }
        format(line, " ", number(m.from), "x", number(m.to), " ", good, "/", none, "/", other);
    }
    print(if sh.raised { "3D" } else { "flat" }, " ", size.x as i64, " x ", size.y as i64, " (turned ", sh.layout.flip,
          ") by ", if by_drag { "drags" } else { "taps" }, ":", line, if all { "" } else { "  <- not all chosen" });
}

fn main() {
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::test_faces(g);
    // The king on 46 takes 23 landing on 19 (taken back by 12x23x14), 14, 10, or 5; the
    // man on 18 takes 12 or 23.
    let fen = "B:W12,23,31:B18,K46";
    print(fen, ": played / nothing / another, of 25 points on the landing square");
    for size in [float2 { 1280.0, 800.0 }, float2 { 800.0, 1280.0 }] {
        for three in [false, true] {
            for by_drag in [false, true] { sweep(g, fen, size, three, by_drag); }
        }
    }
}
