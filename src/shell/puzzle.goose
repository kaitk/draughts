// One puzzle on screen (prototypes/puzzle.html, take c; docs/architecture/puzzles.md,
// "The screen"): the board between the game's panels, leaving it on the left (the
// puzzles, settings, start over) and playing it on the right: whose puzzle it is as the
// game's turn piece, the goal under its icon,
// the three stars at stake, and next, a big tile dim until the puzzle is solved.
//
// The child plays the side to move. A right move that leaves the goal ahead is answered
// after a short pause; a wrong one plays, then slides back by itself, its square
// flashing the red ring over a fading ghost of the piece, while the goal gives way to
// "try again" for a moment and a star goes out. A wrong move the other side answers by
// taking something back (a capture back, a shot) shows that answer first, played as a
// reply is and held a moment, then both slide back. A tap that isn't a move, which the
// board flashes as a mistake, is a miss too. A capture of many jumps is made by hand: a tap or
// a drop on a stop leaves the piece waiting there for the next jump, and next wakes;
// pressed then, it leaves the capture unfinished, no move under the rules, so the piece
// slides back as a wrong move does and it is a miss. After two misses the piece to move
// glows. Solved,
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
import strings from "../../strings";
import puzzles from "../puzzles";

// Where the puzzle is.
let PLAYING = 0;
let ANSWER = 1;             // a right move shows, then the reply comes
let BACK = 2;               // a wrong move shows, then it slides back
let SOLVED = 3;
let SHOW = 4;               // a wrong move shows, then the answer that shows why comes
let SHOWN = 5;              // the answer shows, then it slides back
let UNSHOW = 6;             // the answer slides back, then the wrong move does

let REPLY_PAUSE = 0.5;      // seconds from a right move landing to the reply
let BACK_PAUSE = 0.35;      // from a wrong move landing to its sliding back
let SHOW_PAUSE = 0.4;       // from a wrong move landing to the answer that shows why
let SHOW_HOLD = 0.8;        // from the answer landing to its sliding back, the wrong move after it
let TRY_AGAIN = 2.0;        // "try again" shows this long after a miss
let POP = 0.6;              // a star won pops in
let POP_GAP = 0.15;         // and the next a little after
let STAKE = 3;
let GLOW_AFTER = 2;         // misses before the piece to move glows

// What the screen asks the shell for: nothing, the puzzles (its back), settings, or the
// next puzzle.
let STAY = gui::ASK_NOTHING;
let PUZZLES = gui::ASK_BACK;
let SETTINGS = gui::ASK_SETTINGS;
let NEXT = 3;

struct Play {
    b:         board::Board,
    s:         puzzles::Solver,
    index:     i64 = -1,      // in puzzles::all
    left:      i64 = 0,       // the solver's moves to the goal
    misses:    i64 = 0,
    state:     i64 = PLAYING,
    path:      puzzles::Ply[..puzzles::MAX_PLIES],  // the moves played since the start
    at:        f64 = 0.0,     // when the move shown lands (ANSWER, BACK, SHOW, SHOWN, SOLVED)
    tried:     rules::Move,   // the wrong move, to slide back after its answer
    answer:    i64      = -1, // the answer to it that shows why, in the board's moves (SHOW)
    missed_at: f64      = -100.0,
    won:       i64      = 0,     // stars won, once solved
    fresh:     bool     = false, // solved this frame, for the shell to keep the stars
    grab:      float2   = float2 { 0.0, 0.0 }, // on the 3D board, a held piece against the finger (board::touch)
    cam:       rig::Rig = rig::Rig {},          // and the camera its buttons move (board/rig.goose)
}

// A puzzle never shows a selected piece's targets, whatever the move hints setting: the
// child is to find the move (docs/product.md).
fn new() -> Play {
    var pl = Play { b: board::new(rules::INTERNATIONAL), s: puzzles::Solver { moves: [], stack: [] }, path: [],
                    tried: rules::Move { .. }, .. };
    pl.b.hints = board::MISTAKES;
    pl.b.by_hand = true;
    return pl;
}

fn current(pl: Play&) -> puzzles::Puzzle& { return puzzles::all.list[pl.index]; }

// Opens puzzle `index` of puzzles::all, from its start with three stars at stake.
fn open(pl: Play&, index: i64) {
    pl.index = index;
    rig::reset(pl.cam);
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
        pl.at = b.since + board::duration(m);
        if what == puzzles::SOLVED {
            pl.won = stars(pl);
            pl.state = SOLVED;
            pl.fresh = true;
        } else if what == puzzles::ON {
            pl.state = ANSWER;
            pl.left--;
        } else {
            // A wrong move the other side answers by taking something back shows that
            // answer first.
            pl.tried = m;
            pl.answer = puzzles::answer(pl.s, b.pos);
            pl.state = if pl.answer >= 0 { SHOW } else { BACK };
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
fn frame(pl: Play&, g: gui::Gui&, l: panel::Layout, now: f64, over: board::Overlay&) -> i64, bool {
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
    // A wrong move's answer, its hold, and its sliding back before the move's own.
    if pl.state == SHOW && !b.moving && now >= pl.at + SHOW_PAUSE {
        board::start_move(b, pl.answer, now);
        pl.at = now + board::duration(b.move);
        pl.state = SHOWN;
        changed = true;
    }
    if pl.state == SHOWN && !b.moving && now >= pl.at + SHOW_HOLD {
        let m = b.move;
        board::slide_back(b, m, now, false);
        pl.state = UNSHOW;
        changed = true;
    }
    let unshown = pl.state == UNSHOW && !b.moving;
    if unshown || (pl.state == BACK && !b.moving && now >= pl.at + BACK_PAUSE) {
        board::slide_back(b, pl.tried, now);
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
    let ask = panel_frame(pl, g, l, now, over);
    if ask != STAY {
        changed = true;
        go = ask;
    }
    if ask == RESTART_ASK {
        restart(pl);
        rig::settle(pl.cam, now);
        go = STAY;
    }
    if ask == CAMERA { go = STAY; }
    if ask == NEXT && pl.state != SOLVED {
        // A capture left partway: the piece slides back, and it is a miss.
        if board::abandon(b, now) { missed(pl, now); }
        go = STAY;
    }
    if !g.took && l.three && pl.cam.showcase {
        // The showcase: a drag anywhere off the UI turns and tips the board, not a piece.
        if rig::drive(pl.cam, input.at, input.down, input.pressed, input.released, g.scale, l.pitch, now) {
            changed = true;
        }
    } else if !g.took && ready(pl) && b.pos.side == side {
        let history = b.history.len;
        let wrong_at = b.wrong_at;
        let waited = board::waiting(b);
        // Through the perspective on the 3D board, as the game's.
        if board::touch(b, l.board, l.three, l.view, input, pl.grab, now) { changed = true; }
        judge(pl, history, wrong_at, now);
        // Next was declared above, before the board took the pointer: a press or a drop
        // that starts or ends a piece's wait changes how next looks, and a drop is the
        // finger's last event, so the frame after is drawn too, as after a click.
        if board::waiting(b) != waited { g.acted = true; }
    }
    return go, changed;
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(pl: Play&, g: gui::Gui&, now: f64) -> bool {
    let popping = pl.state == SOLVED && now < pl.at + POP + (STAKE - 1) * POP_GAP;
    let wrong = pl.state == BACK || pl.state == SHOW || pl.state == SHOWN || pl.state == UNSHOW;
    return board::animating(pl.b, now) || gui::animating(g) || pl.state == ANSWER || wrong || popping
           || now < pl.missed_at + TRY_AGAIN || rig::moving(pl.cam, now);
}

let RESTART_ASK = gui::ASK_RESTART;
let CAMERA = 4;             // a camera button was tapped (panel_frame)

// The goal's icon and words.
fn goal_icon(pz: puzzles::Puzzle&) -> i64 {
    return if pz.goal == puzzles::CROWN { gui::CROWN } else if pz.goal == puzzles::SAFE { gui::SHIELD } else { gui::TARGET };
}
fn goal_words(pz: puzzles::Puzzle&, out: u8[..64]&) {
    let take = if pz.count == 1 { strings::GOAL_TAKE_ONE } else { strings::GOAL_TAKE };
    let key = if pz.goal == puzzles::TAKE { take } else if pz.goal == puzzles::CROWN { strings::GOAL_CROWN }
              else if pz.goal == puzzles::WIN { strings::GOAL_WIN } else { strings::GOAL_SAFE };
    strings::fill_in(out, key, [pz.count]);
}

// Whose puzzle it is: "White to move" or "Black to move".
fn to_move(pz: puzzles::Puzzle&) -> const u8[:] {
    return strings::get(if pz.start.side == rules::BLACK { strings::PUZZLE_BLACK_TO_MOVE }
                        else { strings::PUZZLE_WHITE_TO_MOVE });
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

// The glow ring on whose puzzle it is, while it is the child's turn.
fn turn_ring(pl: Play&) -> f32 {
    return if pl.state != SOLVED && pl.b.pos.side == current(pl).start.side { 1.0 } else { 0.0 };
}

// The goal, or "try again" for a moment after a miss, or "solved": the icon over the
// words in landscape, beside them in portrait. With `disc` dp, whose puzzle it is goes
// before the icon as the game's turn piece that wide, beside it in landscape (the
// two over the words) and leading the row in portrait.
fn goal(pl: Play&, g: gui::Gui&, r: float4, icon_size: f32, stacked: bool, now: f64, disc: f32,
        over: board::Overlay&) {
    let u = g.scale;
    let pz .= current(pl);
    let d = disc * u;
    var words: u8[..64] = [];
    goal_words(pz, words);
    let again = pl.state != SOLVED && now < pl.missed_at + TRY_AGAIN;
    let text = if pl.state == SOLVED { strings::get(strings::PUZZLE_SOLVED) } else { words[..] };
    let s = icon_size * u;
    var c = r;
    var icon = c;
    if stacked {
        var row = gui::cut_top(c, max(s, d));
        if d > 0.0 {
            // As far apart as the panel lets them, 20 dp at most.
            let gap = clamp(row.z - d - s, 0.0, 20.0 * u);
            row = gui::center(row, d + gap + s, row.w);
            panel::piece(over, gui::cut_left(row, d), 0.5 * d, pz.start.side, 0, 1.0, turn_ring(pl));
            gui::cut_left(row, gap);
        }
        icon = gui::center(row, s, s);
        gui::cut_top(c, 8.0 * u);
    } else {
        if d > 0.0 {
            panel::piece(over, gui::center(gui::cut_left(c, d), d, d), 0.5 * d, pz.start.side, 0, 1.0, turn_ring(pl));
            gui::cut_left(c, gui::PAD * u);
        }
        icon = gui::center(gui::cut_left(c, s), s, s);
        gui::cut_left(c, gui::PAD * u);
    }
    gui::glyph_icon(g, icon, goal_icon(pz), gui::ON, 0.0, 1.0);
    if again {
        // A pill in the forced-capture red at 16%: the undo arrow and "try again".
        let said = strings::get(strings::PUZZLE_TRY_AGAIN);
        let face = gui::fitting(g, gui::HEADING, said, c.z - 72.0 * u);
        let w = min(c.z, 30.0 * u + 10.0 * u + gui::text_width(g, face, said) + 32.0 * u);
        let pill = if stacked { gui::center(gui::cut_top(c, 48.0 * u), w, 48.0 * u) }
                   else { gui::center(float4 { c.x, c.y, w, c.w }, w, 48.0 * u) };
        gui::fill(g, pill, float4 { gui::RED.x, gui::RED.y, gui::RED.z, 0.16 }, 16.0 * u);
        var inner = pill;
        gui::cut_left(inner, gui::PAD_WIDE * u);
        gui::glyph_icon(g, gui::center(gui::cut_left(inner, 30.0 * u), 30.0 * u, 30.0 * u), gui::UNDO, gui::PLAIN, 0.0,
                        1.0);
        gui::cut_left(inner, 10.0 * u);
        gui::text(g, face, inner, said, 1.0, 0.0, gui::LEFT);
        return;
    }
    // The goal, and under it in the small face whose puzzle it is.
    let face = gui::fitting(g, gui::LABEL, text, c.z);
    let f .= g.faces[face];
    let small .= g.faces[gui::SMALL];
    let lh = f.ascent - f.descent;
    let sh = small.ascent - small.descent;
    let side = to_move(pz);
    let align = if stacked { gui::CENTER } else { gui::LEFT };
    var both = if stacked { gui::cut_top(c, lh + 4.0 * u + sh) } else { gui::center(c, c.z, lh + 4.0 * u + sh) };
    gui::text(g, face, gui::cut_top(both, lh), text, 1.0, 0.0, align);
    gui::cut_top(both, 4.0 * u);
    gui::text(g, gui::fitting(g, gui::SMALL, side, both.z), both, side, 0.66, 0.0, align);
}

// Declares the panels: the left one as the game's, its back going to the theme; on the right
// whose puzzle it is as the game's turn piece (72 dp over the goal in landscape, beside
// its icon where the panel is too short for that, a phone's; 52 dp leading the goal's row
// in portrait), the goal, the stars, and next, a tall tile in landscape, a wide one in
// portrait. The piece goes into `over`. Next
// is lit once the puzzle is solved; before, it is dim and takes no tap, but while a piece
// waits partway through a capture it wakes, unlit, to say the move is done, which a
// capture left partway isn't. Round the 3D board, the camera buttons (panel::camera).
// Returns PUZZLES, SETTINGS, NEXT, RESTART_ASK, CAMERA, or STAY.
fn panel_frame(pl: Play&, g: gui::Gui&, l: panel::Layout, now: f64, over: board::Overlay&) -> i64 {
    let u = g.scale;
    let landscape = l.left.z < l.left.w;
    var ask = STAY;
    let out = panel::leave(g, l);
    gui::panel(g, l.right);
    // The camera buttons round the 3D board, as the game's.
    if panel::camera(g, l, pl.cam, now) { ask = CAMERA; }
    if out == panel::BACK { ask = PUZZLES; }
    if out == panel::SETTINGS { ask = SETTINGS; }
    if out == panel::RESTART { ask = RESTART_ASK; }
    var right = panel::play_area(g, l);
    let solved = pl.state == SOLVED;
    let style = if solved { gui::CHOSEN } else { gui::PLAIN };
    let on = solved || (pl.state == PLAYING && board::waiting(pl.b) >= 0);
    let word = strings::get(strings::PUZZLE_NEXT);
    if landscape {
        // Round the 3D board the panel is a short corner one (panel::corners_in): next
        // takes the shorter tile there.
        let next = gui::cut_bottom(right, if l.three { panel::STACK_H * u } else { panel::tall(l, u) });
        if l.three { gui::cut_top(right, 8.0 * u); }
        let f .= g.faces[gui::LABEL];
        let s .= g.faces[gui::SMALL];
        let words = f.ascent - f.descent + 4.0 * u + s.ascent - s.descent;
        let goal_h = 72.0 * u + 8.0 * u + max(48.0 * u, words);
        // The piece over the goal as over the game's turn words, where it fits above the
        // goal and the stars; else beside the goal's icon.
        let above = right.w >= (18.0 + 72.0 + 18.0 + 16.0 + 56.0) * u + goal_h;
        if above {
            gui::cut_top(right, 18.0 * u);
            panel::piece(over, gui::cut_top(right, 72.0 * u), 36.0 * u, current(pl).start.side, 0, 1.0, turn_ring(pl));
            gui::cut_top(right, 18.0 * u);
        } else {
            gui::cut_top(right, 14.0 * u);
        }
        goal(pl, g, gui::cut_top(right, goal_h), 72.0, true, now, if above { 0.0 } else { 72.0 }, over);
        // The gap and the stars shrink to the room left above next, so a short corner panel
        // round the 3D board doesn't run them into next's tile; smaller too where the
        // panel is narrowed near square.
        gui::cut_top(right, clamp(right.w - 56.0 * u, 0.0, 16.0 * u));
        let most = (right.z / u - 2.0 * 8.0) / STAKE;
        let room = max(right.w, 0.0);
        stake(pl, g, gui::cut_top(right, min(56.0 * u, room)), min(min(if solved { 56.0 } else { 44.0 }, most), room / u),
              8.0, now);
        if gui::labelled(g, panel::EYE_ID, next, gui::NEXT, 48.0, word, gui::HEADING, gui::STACKED, style, on) { ask = NEXT; }
        return ask;
    }
    // Portrait: the goal at the left of the row and the stars at its right, over next.
    var top = gui::cut_top(right, panel::CLOCK_H * u);
    gui::cut_top(right, gui::PAD * u);
    let star_room = 3.0 * 44.0 * u + 2.0 * 8.0 * u;
    let stars_at = gui::cut_right(top, star_room);
    gui::cut_left(top, 6.0 * u);
    goal(pl, g, top, 48.0, false, now, 52.0, over);
    stake(pl, g, stars_at, if solved { 48.0 } else { 40.0 }, 6.0, now);
    if gui::labelled(g, panel::EYE_ID, gui::cut_top(right, panel::WIDE_H * u), gui::NEXT, 36.0, word, gui::HEADING, gui::MIDDLE,
                     style, on) {
        ask = NEXT;
    }
    return ask;
}
