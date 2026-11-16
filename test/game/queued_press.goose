// A tap while the last move still shows isn't lost (board::touch): pressed during the
// slide, or once the piece has landed while its taken piece fades, it is kept and pressed
// when the move has ended, so the next side's piece is chosen. Before, board::press
// dropped it, and a tap right after the computer's reply took two. A friend's game on
// Russian 8 × 8 shows it, the next side's tap the same as the player's after the
// computer's move.
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

fn chosen(gm: game::Game&) -> u8[>..] {
    let b .= gm.b;
    guard b.selected >= 0 else { return str("none"); }
    return drive::name(rules::VARIANTS[b.variant], b.selected);
}

fn main() {
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::test_faces(g);
    let l = panel::layout(1280.0, 800.0, 8);
    var gm = game::new(rules::RUSSIAN);
    drive::idle(gm, g, l, 0.5);

    // c3-d4 slides for 0.2 s; black's tap on f6 0.05 s in, down and up while it slides.
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 1.0);
    drive::tap(gm, g, l, drive::at(l.board, "d4"), 1.1);
    drive::tap(gm, g, l, drive::at(l.board, "f6"), 1.17);
    print("tapped while c3-d4 slides: moving ", gm.b.moving, ", chosen ", chosen(gm));
    drive::idle(gm, g, l, 1.4);
    print("once it has landed: moving ", gm.b.moving, ", chosen ", chosen(gm));

    // f6-e5, then d4 takes e5: a hop of 0.2 s and 0.18 s of the taken man fading;
    // black's tap on g7 lands in the fade, the piece already on f6.
    drive::tap(gm, g, l, drive::at(l.board, "e5"), 1.5);
    drive::idle(gm, g, l, 2.0);
    drive::tap(gm, g, l, drive::at(l.board, "d4"), 2.1);
    drive::tap(gm, g, l, drive::at(l.board, "f6"), 2.2);
    drive::idle(gm, g, l, 2.45);
    print("d4:f6 landed, e5 fading: moving ", gm.b.moving);
    drive::tap(gm, g, l, drive::at(l.board, "g7"), 2.46);
    print("tapped in the fade: chosen ", chosen(gm));
    drive::idle(gm, g, l, 3.0);
    print("once it has faded: moving ", gm.b.moving, ", chosen ", chosen(gm), ", ", rules::fen(gm.b.pos));
}
