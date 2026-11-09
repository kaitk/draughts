// The clocks (game/clock.goose), headless: a 5+3 clock starts with both at 5:00 and none
// running; white's first move starts black's clock without adding white's increment;
// later moves add the increment to the side that moved; a take back runs the clock of
// the side to move again, or none back at the start; the running clock shows whole
// seconds rounded up, turns warn under a minute and low at 20 and under, and its time running out flags that side and
// stops it; no clock never runs.
import std;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";

fn show(c: clock::Clock&, what: const u8[:]) {
    var w: u8[..8] = [];
    var b: u8[..8] = [];
    clock::text(clock::shown(c, 0), w);
    clock::text(clock::shown(c, 1), b);
    print(what, ": white ", w, ", black ", b, ", running ", c.running, ", flag ", c.flag, ", warn ",
          clock::warn(c, 0), " ", clock::warn(c, 1), ", low ",
          clock::low(c, 0), " ", clock::low(c, 1), ", next in ", clock::until_next(c));
}

fn main() {
    var c = clock::new(clock::BLITZ);
    show(c, "5+3");
    print("ticks before the first move: ", clock::tick(c, 10.0));
    show(c, "  after 10 s");
    clock::moved(c, 0);
    show(c, "white moved");
    clock::tick(c, 4.25);
    show(c, "  4.25 s");
    clock::moved(c, 1);
    show(c, "black moved");
    clock::tick(c, 0.75);
    clock::moved(c, 0);
    show(c, "white moved after 0.75 s");
    clock::undone(c, 0, false);
    show(c, "take back");
    clock::undone(c, 0, true);
    show(c, "take back to the start");
    clock::moved(c, 0);
    clock::tick(c, 298.75 - 12.5);
    show(c, "black at 12.5 s");
    clock::tick(c, 3.0);
    show(c, "  9.5 s");
    clock::tick(c, 0.5);
    show(c, "  9 s");
    print("  out after 8.9 s: ", clock::tick(c, 8.9));
    print("  out after 0.2 s more: ", clock::tick(c, 0.2));
    show(c, "black's time ran out");
    clock::moved(c, 1);
    print("  a move after the flag ticks: ", clock::tick(c, 1.0));
    show(c, "  then");

    var r = clock::new(clock::RAPID);
    var t: u8[..8] = [];
    clock::text(clock::shown(r, 0), t);
    print("10+5: ", t, ", on ", clock::on(r));
    var n = clock::new(clock::NONE);
    clock::moved(n, 0);
    print("no clock: on ", clock::on(n), ", running ", n.running, ", ticks ", clock::tick(n, 1.0));
}
