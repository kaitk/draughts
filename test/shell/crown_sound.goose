// The crowning's two sounds (shell::gather_sound_events): against the computer, the
// player's man crowned says CROWN and the computer's CROWN_COMPUTER, two low knocks in
// place of the player's temple blocks; against a friend either side's says CROWN. The
// moves are played on the game's board directly, as the computer's worker would answer.
import std;
import vec;
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
import check from "../";

let NAMES = ["move", "stop", "take", "crown", "wrong", "must", "gold", "red", "solved", "won", "lost", "drawn",
             "crown (computer)"];

// Plays from-to on the game's board and runs the frames till it lands; the sounds said.
fn crowned(sh: shell::Shell&, g: gui::Gui&, fen: const u8[:], computer: i64, from: const u8[:], to: const u8[:]) -> u8[>..] {
    game::start(sh.game, rules::RUSSIAN, clock::NONE, computer, game::EASY, 8, 1);
    board::set(sh.game.b, check::position(rules::RUSSIAN, fen));
    sh.game.turn = sh.game.b.pos.side;
    sh.screen = shell::GAME;
    sh.drawn = shell::GAME;
    drive::idle(sh, g, 1.0);
    let b .= sh.game.b;
    let v .= rules::VARIANTS[rules::RUSSIAN];
    for m, i in b.moves {
        guard drive::name(v, m.from) == from && drive::name(v, m.to) == to else { continue; }
        board::play_chosen(b, i, 1.0);
    }
    var said: u8[>..] = [];
    var t = 1.05;
    while t < 2.0 {
        drive::idle(sh, g, t);
        for c in sh.out.sound_events { format(said, NAMES[c.kind], " "); }
        t += 0.05;
    }
    return said;
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    gui::test_faces(g);
    var sh = shell::new(rules::RUSSIAN);
    print("the player's man crowned, against the computer: ", crowned(sh, g, "W:Wc7,a1:Bh6", rules::BLACK, "c7", "d8"));
    print("the computer's man crowned: ", crowned(sh, g, "B:Wg3:Bb2,h6", rules::BLACK, "b2", "c1"));
    print("a friend's black man crowned: ", crowned(sh, g, "B:Wg3:Bb2,h6", -1, "b2", "c1"));
}
