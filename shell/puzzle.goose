// One puzzle on screen (prototypes/puzzle.html, take c; docs/architecture/puzzles.md,
// "The screen"): the board between the game's panels, leaving it on the left (the
// puzzles, settings, start over) and playing it on the right: the goal under its icon,
// the three stars at stake, and next, a big tile dim until the puzzle is solved.
//
// The child plays the side to move. A right move that leaves the goal ahead is answered
// after a short pause; a wrong one plays, then slides back by itself, its square
// flashing the red ring over a fading ghost of the piece, while the goal gives way to
// "try again" for a moment and a star goes out. A tap that isn't a move, which the board
// flashes as a mistake, is a miss too. After two misses the piece to move glows. Solved,
// the goal says so, the stars won pop in, and next lights; nothing covers the board.
// A star stays at the least, so a puzzle solved is one, two, or three stars.
namespace puzzle;
import std;
import math;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../strings";
import puzzles from "../puzzles";

// Where the puzzle is.
let PLAYING = 0;
let ANSWER = 1;             // a right move shows, then the reply comes
let BACK = 2;               // a wrong move shows, then it slides back
let SOLVED = 3;

let REPLY_PAUSE = 0.5;      // seconds from a right move landing to the reply
let BACK_PAUSE = 0.35;      // from a wrong move landing to its sliding back
let TRY_AGAIN = 2.0;        // "try again" shows this long after a miss
let POP = 0.6;              // a star won pops in
let POP_GAP = 0.15;         // and the next a little after
let STAKE = 3;
let GLOW_AFTER = 2;         // misses before the piece to move glows

// What the screen asks the shell for.
let STAY = 0;
let PUZZLES = 1;
let SETTINGS = 2;
let NEXT = 3;

struct Play {
    b:         board::Board,
    s:         puzzles::Solver,
    index:     i64 = -1,      // in puzzles::all
    left:      i64 = 0,       // the solver's moves to the goal
    misses:    i64 = 0,
    state:     i64 = PLAYING,
    path:      puzzles::Ply[..puzzles::MAX_PLIES],  // the moves played since the start
    at:        f64  = 0.0,    // when the move shown lands (ANSWER, BACK, SOLVED)
    missed_at: f64  = -100.0,
    won:       i64  = 0,      // stars won, once solved
    fresh:     bool = false,  // solved this frame, for the shell to keep the stars
}

// A puzzle never shows a selected piece's targets, whatever the move hints setting: the
// child is to find the move (docs/product.md).
fn new() -> Play {
    var pl = Play { b: board::new(rules::INTERNATIONAL), s: puzzles::Solver { moves: [], stack: [] }, path: [], .. };
    pl.b.hints = board::MISTAKES;
    return pl;
}

fn current(pl: Play&) -> puzzles::Puzzle& { return puzzles::all.list[pl.index]; }

// Opens puzzle `index` of puzzles::all, from its start with three stars at stake.
fn open(pl: Play&, index: i64) {
    pl.index = index;
    pl.misses = 0;
    restart(pl);
}

// Starts the puzzle over: its position again, the misses kept until it is solved.
fn restart(pl: Play&) {
    let pz .= current(pl);
    pl.b.variant = pz.start.variant;
    board::set(pl.b, pz.start);
    puzzles::begin(pl.s, pz);
    if pl.state == SOLVED { pl.misses = 0; }
    pl.left = pz.moves;
    pl.state = PLAYING;
    pl.path.clear();
    pl.missed_at = -100.0;
    pl.won = 0;
    pl.fresh = false;
}

// The stars still at stake, or won.
fn stars(pl: Play&) -> i64 { if pl.state == SOLVED { pl.won } else { max(1, STAKE - pl.misses) } }

// Whether the child can move: the puzzle is the child's to play and nothing moves.
fn ready(pl: Play&) -> bool { pl.state == PLAYING && !pl.b.moving }

// The next move of a line the moves so far follow, and whether there is one.
fn line_next(pl: Play&) -> puzzles::Ply, bool {
    let pz .= current(pl);
    for line in pz.lines {
        guard line.plies.len > pl.path.len else { continue; }
        var same = true;
        for p, i in pl.path { if p != line.plies[i] { same = false; } }
        if same { return line.plies[pl.path.len], true; }
    }
    return puzzles::Ply { from: 0, to: 0, captured: 0 }, false;
}

// The index in the board's legal moves of the next move: the line's, if the moves so far
// follow one and it is legal, else what `fallback` gives.
fn next_move(pl: Play&, fallback: i64) -> i64 {
    let ply, on = line_next(pl);
    guard on else { return fallback; }
    for m, i in pl.b.moves { if m.from == ply.from && m.to == ply.to && m.captured == ply.captured { return i; } }
    return fallback;
}

fn played(pl: Play&, m: rules::Move&) {
    if pl.path.len < puzzles::MAX_PLIES { pl.path.push(puzzles::Ply { from: m.from, to: m.to, captured: m.captured }); }
}

// The hint: the piece of the next right move glows.
fn hint(pl: Play&, now: f64) {
    let i = next_move(pl, puzzles::right_move(pl.s, pl.b.pos, pl.left));
    if i >= 0 { board::glow_on(pl.b, pl.b.moves[i].from, now); }
}

fn missed(pl: Play&, now: f64) {
    pl.misses++;
    pl.missed_at = now;
}

// After the pointer has gone to the board: a move made is judged, a mistake tapped is a
// miss. `history` and `wrong_at` are the board's from before.
fn judge(pl: Play&, history: i64, wrong_at: f64, now: f64) {
    let b .= pl.b;
    if b.history.len > history {
        let m = b.move;
        played(pl, m);
        let what = puzzles::judge(pl.s, b.before, puzzles::short(m), pl.left);
        pl.at = now + board::duration(m);
        if what == puzzles::SOLVED {
            pl.won = stars(pl);
            pl.state = SOLVED;
            pl.fresh = true;
        } else if what == puzzles::ON {
            pl.state = ANSWER;
            pl.left--;
        } else {
            pl.state = BACK;
        }
        return;
    }
    if b.wrong >= 0 && b.wrong_at != wrong_at {
        // The board's pulse of the pieces that must capture would show the answer; the
        // hint is the glow, after two misses.
        b.pulse_end = 0.0;
        missed(pl, now);
    }
}

// A tap at p by the app's development flags, as a press and release.
fn tap(pl: Play&, l: board::Layout, p: float2, now: f64) {
    let history = pl.b.history.len;
    let wrong_at = pl.b.wrong_at;
    board::press(pl.b, l, p, now);
    board::release(pl.b, l, p, now);
    judge(pl, history, wrong_at, now);
}

// One frame, after gui::begin. Returns what the shell should do and whether anything on
// screen changed.
fn frame(pl: Play&, g: gui::Gui&, l: panel::Layout, now: f64, over: game::Overlay&) -> i64, bool {
    let b .= pl.b;
    let input = g.input;
    var changed = board::update(b, now) || input.pressed || input.released;
    over.clear();
    let side = current(pl).start.side;
    // The reply to a right move, once it has landed and a moment passed; the slide back
    // of a wrong one.
    if pl.state == ANSWER && !b.moving && now >= pl.at + REPLY_PAUSE {
        let k = next_move(pl, puzzles::reply(pl.s, b.pos, pl.left));
        if k >= 0 {
            played(pl, b.moves[k]);
            board::start_move(b, k, now);
        }
        pl.state = PLAYING;
        changed = true;
    }
    if pl.state == BACK && !b.moving && now >= pl.at + BACK_PAUSE {
        board::slide_back(b, now);
        pl.path.pop();
        missed(pl, now);
        pl.state = PLAYING;
        changed = true;
    }
    if pl.misses >= GLOW_AFTER && ready(pl) && b.glow < 0 && b.pos.side == side {
        hint(pl, now);
        changed = true;
    }
    pl.fresh = false;

    var go = STAY;
    let ask = panel_frame(pl, g, l, now);
    if ask != STAY {
        changed = true;
        go = ask;
    }
    if ask == RESTART_ASK {
        restart(pl);
        go = STAY;
    }
    if !g.took && ready(pl) && b.pos.side == side {
        let history = b.history.len;
        let wrong_at = b.wrong_at;
        if input.pressed { board::press(b, l.board, input.at, now); }
        if input.down && board::drag(b, l.board, input.at) { changed = true; }
        if input.released { board::release(b, l.board, input.at, now); }
        judge(pl, history, wrong_at, now);
    }
    return go, changed;
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(pl: Play&, g: gui::Gui&, now: f64) -> bool {
    let popping = pl.state == SOLVED && now < pl.at + POP + (STAKE - 1) * POP_GAP;
    return board::animating(pl.b, now) || gui::animating(g) || pl.state == ANSWER || pl.state == BACK || popping
           || now < pl.missed_at + TRY_AGAIN;
}

let RESTART_ASK = -1;

// The goal's icon and words.
fn goal_icon(pz: puzzles::Puzzle&) -> i64 {
    return if pz.goal == puzzles::CROWN { gui::CROWN } else if pz.goal == puzzles::SAFE { gui::SHIELD } else { gui::TARGET };
}
fn goal_words(pz: puzzles::Puzzle&, out: u8[..64]&) {
    let key = if pz.goal == puzzles::TAKE { strings::GOAL_TAKE } else if pz.goal == puzzles::CROWN { strings::GOAL_CROWN }
              else if pz.goal == puzzles::WIN { strings::GOAL_WIN } else { strings::GOAL_SAFE };
    strings::fill_in(out, key, [pz.count]);
}

// The largest of the faces from `face` down that fits `text` in w.
fn fitting(g: gui::Gui&, face: i64, text: const u8[:], w: f32) -> i64 {
    var f = face;
    while f < gui::SMALL && gui::text_width(g, f, text) > w { f++; }
    return f;
}

// The stars in r, centered, `size` dp each and `gap` apart: lit for those at stake or
// won, popping in once solved, outlined for those gone.
fn stake(pl: Play&, g: gui::Gui&, r: float4, size: f32, gap: f32, now: f64) {
    let u = g.scale;
    let lit = stars(pl);
    for i in STAKE {
        let cell = gui::cell(r, STAKE, 1, size * u, size * u, gap * u, i);
        if i >= lit {
            gui::glyph_icon(g, cell, gui::STAR_OFF, gui::PLAIN, 0.0, 0.3);
            continue;
        }
        var grow = 1.0;
        var a = 1.0;
        if pl.state == SOLVED {
            // Grows from 0.3 past its size and settles, as CSS cubic-bezier(.2, 1.6, .4, 1).
            let k = clamp((now - pl.at - i * POP_GAP) / POP, 0.0, 1.0);
            grow = 0.3 + 0.7 * (1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0));
            a = clamp(2.0 * k, 0.0, 1.0);
        }
        let s = cell.z * grow as f32;
        gui::glyph_icon(g, gui::center(cell, s, s), gui::STAR, gui::ON, 0.0, a as f32);
    }
}

// The goal, or "try again" for a moment after a miss, or "solved": the icon over the
// words in landscape, beside them in portrait.
fn goal(pl: Play&, g: gui::Gui&, r: float4, icon_size: f32, stacked: bool, now: f64) {
    let u = g.scale;
    let pz .= current(pl);
    var words: u8[..64] = [];
    goal_words(pz, words);
    let again = pl.state != SOLVED && now < pl.missed_at + TRY_AGAIN;
    let text = if pl.state == SOLVED { strings::get(strings::PUZZLE_SOLVED) } else { words[..] };
    let s = icon_size * u;
    var c = r;
    var icon = c;
    if stacked {
        icon = gui::center(gui::cut_top(c, s), s, s);
        gui::cut_top(c, 8.0 * u);
    } else {
        icon = gui::center(gui::cut_left(c, s), s, s);
        gui::cut_left(c, 12.0 * u);
    }
    gui::glyph_icon(g, icon, goal_icon(pz), gui::ON, 0.0, 1.0);
    if again {
        // A pill in the forced-capture red at 16%: the undo arrow and "try again".
        let said = strings::get(strings::PUZZLE_TRY_AGAIN);
        let face = fitting(g, gui::HEADING, said, c.z - 72.0 * u);
        let w = min(c.z, 30.0 * u + 10.0 * u + gui::text_width(g, face, said) + 32.0 * u);
        let pill = if stacked { gui::center(gui::cut_top(c, 48.0 * u), w, 48.0 * u) }
                   else { gui::center(float4 { c.x, c.y, w, c.w }, w, 48.0 * u) };
        gui::fill(g, pill, float4 { gui::RED.x, gui::RED.y, gui::RED.z, 0.16 }, 16.0 * u);
        var inner = pill;
        gui::cut_left(inner, 16.0 * u);
        gui::glyph_icon(g, gui::center(gui::cut_left(inner, 30.0 * u), 30.0 * u, 30.0 * u), gui::UNDO, gui::PLAIN, 0.0,
                        1.0);
        gui::cut_left(inner, 10.0 * u);
        gui::text(g, face, inner, said, 1.0, 0.0, gui::LEFT);
        return;
    }
    let face = fitting(g, gui::LABEL, text, c.z);
    let f .= g.faces[face];
    let line = if stacked { gui::cut_top(c, f.ascent - f.descent) } else { c };
    gui::text(g, face, line, text, 1.0, 0.0, if stacked { gui::CENTER } else { gui::LEFT });
}

// Declares the panels: the left one as the game's with the puzzles for home; on the right
// the goal, the stars, and next, a tall tile in landscape, a wide one in portrait.
// Returns PUZZLES, SETTINGS, NEXT, RESTART_ASK, or STAY.
fn panel_frame(pl: Play&, g: gui::Gui&, l: panel::Layout, now: f64) -> i64 {
    let u = g.scale;
    let landscape = l.left.z < l.left.w;
    gui::panel(g, l.left);
    gui::panel(g, l.right);
    var ask = STAY;
    let out = panel::leave(g, l, gui::PUZZLE, strings::HOME_PUZZLES);
    if out == panel::HOME { ask = PUZZLES; }
    if out == panel::SETTINGS { ask = SETTINGS; }
    if out == panel::RESTART { ask = RESTART_ASK; }
    var right = panel::play_area(g, l);
    let solved = pl.state == SOLVED;
    let style = if solved { gui::CHOSEN } else { gui::PLAIN };
    let word = strings::get(strings::PUZZLE_NEXT);
    if landscape {
        let next = gui::cut_bottom(right, panel::TALL_H * u);
        gui::cut_top(right, 14.0 * u);
        let f .= g.faces[gui::LABEL];
        goal(pl, g, gui::cut_top(right, 72.0 * u + 8.0 * u + max(48.0 * u, f.ascent - f.descent)), 72.0, true, now);
        gui::cut_top(right, 16.0 * u);
        stake(pl, g, gui::cut_top(right, 56.0 * u), if solved { 56.0 } else { 44.0 }, 8.0, now);
        if gui::labelled(g, 114, next, gui::NEXT, 48.0, word, gui::HEADING, gui::STACKED, style, solved) { ask = NEXT; }
        return ask;
    }
    // Portrait: the goal at the left of the row and the stars at its right, over next.
    var top = gui::cut_top(right, panel::CLOCK_H * u);
    gui::cut_top(right, 12.0 * u);
    let star_room = 3.0 * 44.0 * u + 2.0 * 8.0 * u;
    let stars_at = gui::cut_right(top, star_room);
    gui::cut_left(top, 6.0 * u);
    goal(pl, g, top, 48.0, false, now);
    stake(pl, g, stars_at, if solved { 48.0 } else { 40.0 }, 6.0, now);
    if gui::labelled(g, 114, gui::cut_top(right, panel::WIDE_H * u), gui::NEXT, 36.0, word, gui::HEADING, gui::MIDDLE,
                     style, solved) {
        ask = NEXT;
    }
    return ask;
}
