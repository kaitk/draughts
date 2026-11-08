// How long the computer takes over a move against the clock (game/pace.goose), and
// whole games of it on the clock. First the rule on its own: a single move comes after
// the level's pause; a choice among captures quickly; a quiet choice longer the more
// moves are about as good; more on hard than on easy, more on 10+5 than 5+3; the
// first moves of a game quickly; less as its clock runs low, never more than a tenth of
// what is left.
//
// Then whole games, each level against itself on each clock, in Russian and
// International, with time simulated as the app spends it: a side's clock runs from the
// start of the other side's move (its animation, board::duration) until its own move
// starts, the time it takes being pace::seconds from its clock at that point; the
// increment comes with its move, and white's first move is untimed. Neither side may
// lose on time, and the computer's time a move must fall in its level's range (the
// ranges and why: docs/architecture/ai.md). The search counts nodes, so the games
// replay the same on any machine; hard's node limit is lowered to stay quick through
// TinyCC.
import std;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import strings from "../../strings";
import game from "../../game";
import ai from "../../ai";

let PLIES = 240;            // a game longer than this stops, drawn
let QUIET = 50;             // or after this many plies with no capture and no man moved
let GAMES = 1;              // games of each variant, at each level and clock
let NODES = 20000;          // hard's node limit, so it stays quick through TinyCC

// The mean seconds a move each level's computer may take, by clock: the range it must
// fall in over a game.
let LOW:  f64[3][3] = [[0.0, 0.0, 0.0], [1.5, 2.5, 3.5], [2.0, 4.0, 5.5]];
let HIGH: f64[3][3] = [[0.0, 0.0, 0.0], [3.0, 5.0, 7.0], [4.0, 8.0, 11.0]];

fn secs(t: f64) -> u8[>..] {
    var out: u8[>..] = [];
    format_flt(out, t, 2);
    return out;
}

fn rule() {
    let names = ["easy", "medium", "hard"];
    print("the time a move takes with its clock full, past the opening:");
    for kind in 1..3 {
        let left = 60.0 * clock::MINUTES[kind];
        let inc = clock::INCREMENTS[kind];
        for level in 3 {
            let p = game::PAUSE[level];
            var line: u8[>..] = str("  ", ["", "5+3", "10+5"][kind], " ", names[level], ": one move ",
                                    secs(pace::seconds(p, level, left, inc, 20, 1, false, 1)), ", captures ",
                                    secs(pace::seconds(p, level, left, inc, 20, 3, true, 2)), ", close 1 to 5");
            for close in 1..6 { format(line, " ", secs(pace::seconds(p, level, left, inc, 20, 7, false, close))); }
            print(line);
        }
    }
    print("hard on 5+3 with five close moves and its clock full, by ply: the first moves come quickly:");
    var first: u8[>..] = str(" ");
    for ply in [1, 3, 5, 7, 9, 11, 13] {
        format(first, " ", ply, ": ", secs(pace::seconds(0.45, game::HARD, 300.0, 3.0, ply, 7, false, 5)));
    }
    print(first);
    print("hard on 5+3 with five close moves, as its clock runs down:");
    var line: u8[>..] = str(" ");
    for left in [300.0, 120.0, 60.0, 30.0, 10.0, 5.0, 2.0, 0.5] {
        format(line, " ", secs(left), " s: ", secs(pace::seconds(0.45, game::HARD, left, 3.0, 20, 7, false, 5)));
    }
    print(line);
    // The worst it meets: 300 moves, each its hardest choice, each after the other
    // side's longest capture (1.5 s on its clock): it settles, never runs out.
    var left = 300.0;
    var lowest = left;
    for n in 300 {
        left -= 1.5 + pace::seconds(0.45, game::HARD, left - 1.5, 3.0, 20, 7, false, 5);
        lowest = min(lowest, left);
        guard left > 0.0 else { break; }
        left += 3.0;
    }
    print("300 hardest moves on 5+3, each after 1.5 s of the other side's capture: its clock never under ",
          secs(lowest), " s, at the end ", secs(left));
}

// One side's time over a game.
struct Spent {
    moves:   i64  = 0,      // its timed moves
    total:   f64  = 0.0,    // the time it took over them
    longest: f64  = 0.0,
    lowest:  f64  = 1.0e9,  // its clock's least, as a move began
    flagged: bool = false,
}

// A game of the computer at `level` against itself on clock `kind`; the time spent by
// white and black, and the plies played.
fn play(e: ai::Engine&, variant: u8, level: i64, kind: i64, seed: i64, spent: Spent[2]&) -> i64 {
    let skill = ai::level_skill(level);
    var c = clock::new(kind);
    var p = rules::start(variant);
    var moves: rules::Moves = [];
    var shown = 0.0;        // the last move's animation, on the clock of the side to move
    var quiet = 0;
    for ply in PLIES {
        rules::generate(p, moves);
        guard moves.len > 0 && quiet < QUIET else { return ply; }
        let side = p.side as i64;
        let m = ai::think(e, p, skill, (seed * 1000 + ply) as u64);
        let close = ai::close(e, pace::CLOSE);
        if c.running == side {
            let s .= spent[side];
            if clock::tick(c, shown) { s.flagged = true; }
            s.lowest = min(s.lowest, c.left[side]);
            let t = pace::seconds(game::PAUSE[level], level, c.left[side], clock::INCREMENTS[kind], ply, moves.len,
                                  moves[0].captured != 0, close);
            if clock::tick(c, t) { s.flagged = true; }
            s.moves += 1;
            s.total += t;
            s.longest = max(s.longest, t);
        }
        guard c.flag < 0 else { return ply; }
        clock::moved(c, side);
        shown = board::duration(m);
        let man = p.kings & rules::bit(m.from) == 0;
        quiet = if m.captured != 0 || man { 0 } else { quiet + 1 };
        p = rules::play(p, m);
    }
    return PLIES;
}

fn games(e: ai::Engine&) {
    let names = ["easy", "medium", "hard"];
    let variants: u8[2] = [rules::RUSSIAN, rules::INTERNATIONAL];
    for kind in 1..3 {
        for level in 3 {
            var all = Spent {};
            var plies = 0;
            var per_game = 0.0;
            for v in 2 {
                for k in GAMES {
                    var spent: Spent[2] = [Spent {}, Spent {}];
                    plies += play(e, variants[v], level, kind, 10 * v + k + 1, spent);
                    for s in spent {
                        all.moves += s.moves;
                        all.total += s.total;
                        all.longest = max(all.longest, s.longest);
                        all.lowest = min(all.lowest, s.lowest);
                        all.flagged = all.flagged || s.flagged;
                        per_game = max(per_game, s.total);
                    }
                }
            }
            let mean = all.total / all.moves;
            let within = mean >= LOW[kind][level] && mean <= HIGH[kind][level] && all.longest <= pace::MOST[level];
            print(["", "5+3", "10+5"][kind], " ", names[level], ": ", 2 * GAMES, " games, ", plies / (2 * GAMES), " plies a game, ", all.moves,
                  " timed moves; a move ", secs(mean), " s on average, ", secs(all.longest), " at most; a side's most in a game ",
                  secs(per_game), " s; its clock never under ", secs(all.lowest), " s; lost on time ", all.flagged,
                  "; within the range ", within);
        }
    }
}

fn main() {
    rule();
    var e = ai::Engine { .. };
    ai::init(e);
    e.node_limit = NODES;
    games(e);
}
