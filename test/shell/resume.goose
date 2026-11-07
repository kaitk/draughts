// Resuming after Android kills the app (shell::save, shell::restore), headless: the
// screen, the position, where the game began, the last move's marks, and the undo
// history come back from the image, and undo goes on working; an image that is damaged,
// cut short, or of something else changes nothing.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import game from "../../game";
import shell from "../../shell";
import strings from "../../strings";

fn show(sh: shell::Shell&, what: const u8[:]) {
    let b .= sh.game.b;
    print(what, ": screen ", sh.screen, ", ", rules::fen(b.pos), ", began ", rules::fen(b.start), ", history ",
          b.history.len, ", last ", b.has_last, " ", b.last.from, "-", b.last.to);
}

fn play(b: board::Board&, from: i64, to: i64, now: f64) {
    let l = board::layout(1280.0, 800.0, 8);
    let v .= rules::VARIANTS[b.variant];
    board::update(b, now);
    board::press(b, l, board::center(l, v, board::bit_at(v, from % 8, from / 8)), now);
    board::release(b, l, board::center(l, v, board::bit_at(v, from % 8, from / 8)), now);
    board::press(b, l, board::center(l, v, board::bit_at(v, to % 8, to / 8)), now);
    board::update(b, now + 1.0);
}

fn main() {
    var sh = shell::new(rules::RUSSIAN);
    let p, ok = rules::parse_fen("W:Wc3,e3,g3:Bb6,d6,f6", rules::RUSSIAN);
    assert(ok);
    board::set(sh.game.b, p);
    play(sh.game.b, 2 + 8 * 2, 3 + 8 * 3, 0.0);     // c3-d4
    play(sh.game.b, 5 + 8 * 5, 4 + 8 * 4, 2.0);     // f6-e5
    sh.screen = shell::GAME;
    show(sh, "saved");
    let image = shell::save(sh);
    print("image ", image.len, " bytes");

    var back = shell::new(rules::RUSSIAN);
    print("restored: ", shell::restore(back, image));
    show(back, "  as it was");
    board::undo(back.game.b);
    show(back, "  undo");
    board::undo(back.game.b);
    show(back, "  undo");

    var other = shell::new(rules::RUSSIAN);
    var damaged = copy(image);
    damaged[damaged.len / 2] ^= 0xFF;
    print("a damaged byte in the middle: ", shell::restore(other, damaged));
    print("cut short: ", shell::restore(other, image[..image.len - 9]));
    print("not an image: ", shell::restore(other, "season = winter\n"));
    print("empty: ", shell::restore(other, ""));
    show(other, "  left as it was");
}
