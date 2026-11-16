// What the board says is heard (board/sound_event.goose), and the rule that keeps one sound a
// move. A capture played by code (the computer's) says each stop before its last as its
// hop lands, a whole tone up each, then the taken pieces once, at its last landing; the
// same capture tapped stop by stop says each stop as the piece's hop lands there, one
// dropped on a stop at once. A quiet move says the piece set down as it lands, a man
// crowned the crowning in its place, a puzzle's last move its finale. A square no capture
// goes to says another piece must capture before the first stop and is a wrong stop after
// it; a piece that can't move while another must capture says MUST. Of one frame's events
// those that end a move give way to the most important: the end, then a crowning, the
// taken pieces, the piece set down. The clock's gold and red are said once a side a game,
// never for the computer's clock, and an increment doesn't arm them again. The king of
// puzzle 14 (W:W46,K47:B5,12,22,38) takes 38, 22, and 12 by 33 and 17, ending on 8.
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

let NAMES = ["move", "stop", "take", "crown", "wrong", "must", "gold", "red", "solved", "won", "lost", "drawn"];

fn sq(n: i64) -> u8[>..] {
    let v .= rules::VARIANTS[rules::INTERNATIONAL];
    return drive::name(v, v.bit_of[n]);
}

fn said(cs: sound_event::Events&) -> u8[>..] {
    var out: u8[>..] = [];
    for c, i in cs {
        if i > 0 { out.append(", "); }
        out.append(NAMES[c.kind]);
        if c.kind == sound_event::STOP { format(out, " ", c.step); }
    }
    return out;
}

// The board's sound events up to `now`, taken off it, printed if any.
fn events_by(b: board::Board&, now: f64, what: const u8[:]) {
    board::update(b, now);
    if b.sound_events.len > 0 { print("  ", what, " at ", ms(now), ": ", said(b.sound_events)); }
    b.sound_events.clear();
}

fn ms(t: f64) -> u8[>..] { str(round(1000.0 * t) as i64, " ms") }

// Frames every 50 ms from `from` to `to`, in ms.
fn frames(b: board::Board&, from: i64, to: i64) {
    var t = from;
    while t <= to {
        events_by(b, t / 1000.0, "heard");
        t += 50;
    }
}

fn tap(b: board::Board&, l: board::Layout, n: i64, now: f64) {
    let p = drive::at(l, sq(n));
    board::update(b, now);
    board::press(b, l, p, now);
    board::release(b, l, p, now);
    if b.sound_events.len > 0 { print("  tap ", n, " at ", ms(now), ": ", said(b.sound_events)); }
    b.sound_events.clear();
}

fn settled(list: const i64[:]) {
    var cs: sound_event::Events = [];
    for k in list { sound_event::add(cs, k); }
    let before = said(cs);
    sound_event::one_per_move(cs);
    print("  ", before, " -> ", said(cs));
}

fn main() {
    let l = panel::layout(1280.0, 800.0, 10).board;
    let king, ok = rules::parse_fen("W:W46,K47:B5,12,22,38", rules::INTERNATIONAL);
    assert(ok);
    var b = board::new(rules::INTERNATIONAL);

    print("A capture of three played by code, a frame every 50 ms:");
    board::set(b, king);
    var k = -1;
    for m, i in b.moves { if m.from == b.moves[0].from && m.to == rules::VARIANTS[rules::INTERNATIONAL].bit_of[8] { k = i; } }
    board::start_move(b, k, 0.0);
    frames(b, 0, 900);

    print("The same tapped stop by stop:");
    board::set(b, king);
    tap(b, l, 47, 0.0);
    tap(b, l, 33, 0.1);
    frames(b, 150, 350);
    tap(b, l, 17, 0.4);
    tap(b, l, 8, 0.45);                     // before the hop to 17 has landed
    frames(b, 500, 900);

    print("A drag dropped on a stop:");
    board::set(b, king);
    board::press(b, l, drive::at(l, sq(47)), 0.0);
    board::drag(b, l, drive::at(l, sq(47)) + float2 { 40.0, -40.0 });
    board::release(b, l, drive::at(l, sq(33)), 0.1);
    events_by(b, 0.1, "dropped on 33");

    print("Wrong squares while a capture is due:");
    board::set(b, king);
    tap(b, l, 46, 0.0);                     // the man can't move: the king must capture
    tap(b, l, 47, 0.1);
    tap(b, l, 41, 0.2);                     // no capture goes there
    tap(b, l, 33, 2.0);
    frames(b, 2050, 2250);
    tap(b, l, 50, 2.3);                     // partway: a wrong stop

    print("A quiet move, a man crowned, a puzzle's last move:");
    let quiet, ok2 = rules::parse_fen("W:W33,K47:B5", rules::INTERNATIONAL);
    assert(ok2);
    board::set(b, quiet);
    tap(b, l, 33, 0.0);
    tap(b, l, 28, 0.1);
    frames(b, 150, 350);
    let crown, ok3 = rules::parse_fen("W:W7:B45", rules::INTERNATIONAL);
    assert(ok3);
    board::set(b, crown);
    tap(b, l, 7, 0.0);
    tap(b, l, 1, 0.1);
    b.finale = sound_event::NONE;
    frames(b, 150, 350);
    board::set(b, quiet);
    tap(b, l, 33, 0.0);
    tap(b, l, 29, 0.1);
    b.finale = sound_event::SOLVED;
    frames(b, 150, 350);

    print("One sound a move:");
    settled([sound_event::MOVE]);
    settled([sound_event::STOP, sound_event::TAKE, sound_event::WON]);
    settled([sound_event::TAKE, sound_event::CROWN]);
    settled([sound_event::CROWN, sound_event::DRAWN]);
    settled([sound_event::MOVE, sound_event::LOST]);
    settled([sound_event::WRONG, sound_event::MOVE, sound_event::GOLD]);
    settled([sound_event::MUST]);

    print("The clocks:");
    var ch = sound_event::Chimes {};
    let steps = [[1, 0, 0], [1, 1, 0], [1, 1, 0], [1, 0, 0], [1, 1, 0], [1, 1, 1], [1, 1, 1], [0, 1, 1]];
    for st in steps {
        let side = st[0];
        let warn = st[1] == 1;
        let low = st[2] == 1;
        let c = sound_event::chime(ch, side, warn, low, true);
        print("  side ", side, if warn { ", under a minute" } else { "" }, if low { ", at 0:20" } else { "" }, ": ",
              if c == sound_event::NONE { "nothing" } else { NAMES[c] });
    }
    var computer = sound_event::Chimes {};
    print("  the computer's clock under a minute: ",
          if sound_event::chime(computer, 1, true, false, false) == sound_event::NONE { "nothing" } else { "WRONG" });
    var straight = sound_event::Chimes {};
    let first = sound_event::chime(straight, 0, true, true, true);
    let then = sound_event::chime(straight, 0, true, false, true);
    print("  straight to 0:20: ", NAMES[first], ", then under a minute: ", if then == sound_event::NONE { "nothing" } else { "WRONG" });
}
