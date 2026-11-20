// What each side has taken on the table beside the 3D board (taken3d::lay), headless. On
// the table, a capture's pieces leave the board after its last hop and are carried to
// the next free places of their kind, rising on the way, more opaque as they go, and lie
// there once the move ends; an undo carries them back to their squares, and a new game
// clears the table. A man taken as a king lies with the kings. Without the table nothing
// lies there and a captured piece fades on the board as before.
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

fn r2(x: f32) -> f64 { floor((x as f64) * 100.0 + 0.5) / 100.0 }

// The table's pieces by color and kind (an instance with a seed from 400 on), and those
// on their way (over the board, high, or not yet opaque) with their foot and opacity.
fn show(s: view3d::Scene&, what: const u8[:]) {
    var lying: i64[2][2] = [[0, 0], [0, 0]];
    var way:   u8[>..]   = [];
    var i = 0;
    while i < s.inst.len {
        let foot = s.inst[i];
        let k = s.inst[i + 1];
        let a = s.state[i].x;
        i += 2;
        guard k.w >= 400.0 else { continue; }
        let c = k.x as i64;
        let king = if k.w >= 440.0 && k.w < 464.0 || k.w >= 504.0 { 1 } else { 0 };
        let over_board = abs(foot.x) < 4.6 && abs(foot.z) < 4.6;
        if over_board || a < 1.0 || foot.y > mesh::TABLE_TOP + 4.0 * mesh::HEIGHT {
            format(way, " (", r2(foot.x), " ", r2(foot.y), " ", r2(foot.z), " at ", r2(a), ")");
        } else {
            lying[c][king]++;
        }
    }
    print(what, ": white men ", lying[0][0], ", white kings ", lying[0][1], ", black men ", lying[1][0],
          ", black kings ", lying[1][1], "; on the way", if way.len > 0 { way[..] } else { " none" },
          "; discs ", s.discs.len);
}

// The board's own pieces drawn at `now`: how many, and the least opacity.
fn on_board(b: board::Board&) -> u8[>..] {
    var least: f32 = 1.0;
    for p in b.pieces { least = min(least, p.look.w); }
    return str(b.pieces.len, " on the board, the faintest at ", r2(least));
}

fn main() {
    strings::use(strings::EN);
    let l0 = panel::corners_in(float4 { 0.0, 0.0, 1280.0, 800.0 }, 8, 1.0);
    let l = l0.board;
    let v = l0.view;
    var b = board::new(rules::RUSSIAN);
    b.on_table = true;
    // White's c3 takes the man on d4 and the king on f6 (c3:e5:g7).
    let p, ok = rules::parse_fen("W:Wc3,a1:Bd4,Kf6,h8", rules::RUSSIAN);
    assert(ok);
    board::set(b, p);
    var s = view3d::Scene {};
    let m = b.moves[0];
    board::build_frame_pieces(b, l, 0.0);
    view3d::build_scene(s, b, l, v, 0.0, true);
    show(s, "before");
    board::press(b, l, drive::at(l, "c3"), 0.0);
    board::release(b, l, drive::at(l, "c3"), 0.0);
    board::press(b, l, drive::at(l, "g7"), 0.0);
    board::release(b, l, drive::at(l, "g7"), 0.0);
    print("moving ", b.moving, ", ", rules::fen(b.pos), ", ", board::duration(b.move, true), " s on the table, ",
          board::duration(b.move), " s without");
    for t in [0.3, 0.45, 0.65, 0.88] {
        board::update(b, t);
        board::build_frame_pieces(b, l, t);
        view3d::build_scene(s, b, l, v, t, true);
        show(s, str(t, " s"));
        print("  ", on_board(b));
    }
    board::update(b, 1.0);
    board::build_frame_pieces(b, l, 1.0);
    view3d::build_scene(s, b, l, v, 1.0, true);
    print("moving ", b.moving);
    show(s, "after");

    // Undone: carried back, and on their squares again.
    assert(board::slide_back(b, m, 2.0, false));
    for t in [2.25, 2.55] {
        board::update(b, t);
        board::build_frame_pieces(b, l, t);
        view3d::build_scene(s, b, l, v, t, true);
        show(s, str("undo, ", t, " s"));
        print("  ", on_board(b));
    }
    board::update(b, 3.0);
    board::build_frame_pieces(b, l, 3.0);
    view3d::build_scene(s, b, l, v, 3.0, true);
    show(s, "undone");

    // A new game: nothing taken.
    board::reset(b, rules::RUSSIAN);
    board::build_frame_pieces(b, l, 4.0);
    view3d::build_scene(s, b, l, v, 4.0, true);
    show(s, "new game");

    // Without the table: the capture's pieces fade on the board, nothing lies beside it.
    var f = board::new(rules::RUSSIAN);
    board::set(f, p);
    board::press(f, l, drive::at(l, "c3"), 0.0);
    board::release(f, l, drive::at(l, "c3"), 0.0);
    board::press(f, l, drive::at(l, "g7"), 0.0);
    board::release(f, l, drive::at(l, "g7"), 0.0);
    board::update(f, 0.5);
    board::build_frame_pieces(f, l, 0.5);
    view3d::build_scene(s, f, l, v, 0.5);
    show(s, "no table, 0.5 s");
    print("  ", on_board(f));
}
