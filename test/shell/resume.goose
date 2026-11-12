// Resuming after Android kills the app (shell::save, shell::restore), headless: the
// screen, the position, where the game began, the last move's marks, and the undo
// history come back from the image, and undo goes on working; a game of another variant
// comes back with its own, its clocks, and whom it is against at which skill; an image
// that is damaged, cut short, or of something else changes nothing. Whether the game is
// one nobody set up comes back too (issue 1); a version 3 image, from before that was
// kept, reads as a game set up.
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

fn show(sh: shell::Shell&, what: const u8[:]) {
    let b .= sh.game.b;
    print(what, ": screen ", sh.screen, ", ", rules::fen(b.pos), ", began ", rules::fen(b.start), ", history ",
          b.history.len, ", last ", b.has_last, " ", b.last.from, "-", b.last.to);
}

fn play(b: board::Board&, from: i64, to: i64, now: f64) {
    let l = panel::layout(1280.0, 800.0, 8).board;
    let v .= rules::VARIANTS[b.variant];
    board::update(b, now);
    board::press(b, l, board::center(l, v, rules::bit_at(v, from % 8, from / 8)), now);
    board::release(b, l, board::center(l, v, rules::bit_at(v, from % 8, from / 8)), now);
    board::press(b, l, board::center(l, v, rules::bit_at(v, to % 8, to / 8)), now);
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

    // An International game against the computer playing black, at easy with skill 14,
    // game number 7, with black's 5+3 clock running, comes back into a shell started on
    // Russian.
    var intl = shell::new(rules::INTERNATIONAL);
    game::start(intl.game, rules::INTERNATIONAL, clock::BLITZ, rules::BLACK, game::EASY, 14, 7);
    clock::moved(intl.game.clock, rules::WHITE);
    clock::tick(intl.game.clock, 12.5);
    var russian = shell::new(rules::RUSSIAN);
    print("International restored: ", shell::restore(russian, shell::save(intl)));
    let gm .= russian.game;
    print("  variant ", gm.b.variant, ", ", rules::fen(gm.b.pos), ", clock ", gm.clock.kind, " left ", gm.clock.left[0],
          " ", gm.clock.left[1], " running ", gm.clock.running, ", computer ", gm.computer, ", level ", gm.level,
          ", skill ", gm.skill, ", number ", gm.number);

    // Unset, kept with the game; a version 3 image of the same game reads as set up.
    sh.unset = true;
    var unset = shell::new(rules::RUSSIAN);
    print("unset restored: ", shell::restore(unset, shell::save(sh)), ", unset ", unset.unset);
    let b .= sh.game.b;
    var three: shell::Saved3[>..] = [];
    three.push(shell::Saved3 { version: 3, screen: shell::GAME, variant: b.variant, start: b.start, pos: b.pos,
                               last_from: b.last.from, last_to: b.last.to, has_last: b.has_last, history: b.history,
                               clock: sh.game.clock, computer: sh.game.computer, level: sh.game.level,
                               skill: sh.game.skill, number: sh.game.number, counted: sh.game.counted });
    var old = to_bytes(three);
    let h = shell::checksum(old);
    for i in 8 { old.push(((h >> (8 * i)) & 0xFF) as u8); }
    var migrated = shell::new(rules::RUSSIAN);
    migrated.unset = true;
    print("version 3 restored: ", shell::restore(migrated, old), ", unset ", migrated.unset);
    show(migrated, "  as it was");
}
