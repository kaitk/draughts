// The game screen, with no graphics: the board, the panels beside it, the clocks, and
// the celebration on a win (docs/architecture/rendering.md, "Game screen", "Clocks").
// Each frame it counts the time on the running clock, advances the board, declares the
// panels, does what their tiles ask, and gives the pointer to the board only when a
// press didn't land on the UI, so a press that starts on a panel never moves a piece and
// one that starts on the board never presses a tile. The app draws what it leaves: the
// board's draw lists, the UI's quads, and a few pieces over the UI, in a list the shell
// holds for every screen (Overlay). Tests run it headless.
//
// Against the computer the game knows which side it plays, its level, and the skill it
// plays the whole game at. On its turn the game asks for a move (asking()) and plays the
// answer (answer()) through the board's animation once it has taken the time a person
// would (a short pause, or against the clock pace::seconds); the app thinks on a worker
// thread, tests call ai::think. Meanwhile the computer's piece on the panel pulses
// once, its clock runs, and the child can't move its pieces. Take back then takes back
// the child's last move and the computer's reply.
namespace game;
import std;
import math;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import ai from "../ai";
import strings from "../../strings";
import .panel;
import .clock;
import .pace;

// A win (rendering.md, "Controls", A win), in seconds since it: the winning piece lifts
// with its ring; a ring of glow passes across the winner's other pieces outward from it,
// each lifting a little with its square lit; the board dims under the winning piece; the
// card slides up as it fades in, and the crowned piece fades in on it. Then it is still.
let LIFT = 0.35;            // the winning piece lifts, easing out
let WAVE_AT = 0.15;         // the glow reaches a piece on the next square then,
let WAVE_STEP = 0.08;       // one a square farther this much later,
let WAVE = 0.6;             // and takes this long to pass it
let DIM_AT = 0.9;           // the board dims to DIM over 0.6 s
let DIM = 0.45;
let CARD_AT = 1.0;          // the card slides up SLIDE dp as it fades in over 0.7 s
let SLIDE = 28.0;
let CROWN_AT = 1.2;         // the crowned piece fades in over 0.5 s
let STILL = 1.7;            // still from here, or once the glow has passed the farthest piece
// A draw (rendering.md, "Controls", A draw), calm: the board dims as the win's does over
// 0.6 s, and the card with both pieces, "Draw", and why slides up as it fades in from
// DRAW_CARD; still from DRAW_STILL. Nothing lifts or glows.
let DRAW_DIM = 0.6;
let DRAW_CARD = 0.1;
let DRAW_STILL = 0.8;
let STEP = 2.0;             // seconds: the longest gap between two frames the clock counts
let PAUSE = [0.8, 0.6, 0.45];   // seconds from the computer's turn to its move without a clock, by level
let PULSE = 1.2;            // seconds: the computer's ring pulses once as it begins to think
let HINT_UP = 15;           // the hint's search: this much above the skill of the side it plays against

// What the screen asks the shell for.
let STAY = 0;
let HOME = 1;
let SETTINGS = 2;

// The computer's levels.
let EASY = 0;
let MEDIUM = 1;
let HARD = 2;

// The pieces a screen shows over the UI this frame (put()), drawn after it.
type Overlay = board::Piece[..panel::OVER];

struct Game {
    b:        board::Board,
    clock:    clock::Clock = clock::Clock {},
    computer: i64          = -1,                    // the side the computer plays, or -1 for a friend
    level:    i64          = MEDIUM,                // the computer's
    skill:    i64          = 40,                    // the computer's for the whole game (ai::level_skill)
    number:   i64          = 0,                     // the game's number, for the computer's seeds
    turn:     u8           = 0,                     // the side to move as last seen, to tell a move was made
    seen:     f64          = -1.0,                  // when the clock last counted, or -1 to count nothing next
    shown:    i64          = -1,                    // the running clock's whole seconds as last drawn
    won_at:   f64          = -1.0,                  // when the celebration began, or -1
    won_on:   i64          = -1,                    // the winning piece's square, or -1 for none to lift
    still:    f64          = STILL,                 // the celebration's moment from which it is still
    stilled:  bool         = false,                 // whether its still frame has been drawn
    // A draw (rules/draw.goose): the game's past for it at the position as last folded
    // over the board's history (`seen_len` plies, at `seen_pos`), why the game is drawn
    // (rules::DRAW_*, NO_DRAW while it goes on), and when its ending began, or -1.
    past:        rules::Past     = rules::Past { draw: rules::Draw {}, before: [] },
    seen_len:    i64             = -1,
    seen_pos:    rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    drawn_at:    f64             = -1.0,
    drawn_still: bool            = false,
    // The computer's turn: the move asked for, and its answer.
    asks:     i64         = 0,                      // moves asked for so far, to number them
    asking:   i64         = 0,                      // the one waited for, or 0
    asked_at: f64         = 0.0,                    // when the computer's turn began
    answered: bool        = false,                  // whether its answer has come
    wait:     f64         = 0.0,                    // seconds from its turn to its move, once answered
    reply:    rules::Move = rules::Move { .. },
    // Against the computer, the result as the game ends, for the shell: 1 the child won,
    // -1 lost; and whether it was given, for a game counts once.
    result:  i64  = 0,
    counted: bool = false,
    // Whether the game was started over (play again, or start over), for the shell to
    // give the new game its level's skill as adapting left it and a new number.
    restarted: bool = false,
    // On the 3D board, a held piece's place against the finger on its plane (frame), and
    // the camera its buttons move (board/rig.goose).
    grab: float2   = float2 { 0.0, 0.0 },
    cam:  rig::Rig = rig::Rig {},
    // The lookout (docs/architecture/ai.md, "The lookout"): on as the player's setting has
    // it (the shell keeps them in step), the skill whose plain threats it leaves to the
    // player (the shell's: the game's against the computer, the player's level's against
    // a friend), and what it last worked the threats out for, so it does once a position
    // or held target, never a frame.
    look:       bool  = false,
    look_skill: i64   = 0,
    watched:    Watch = Watch {},
    // Its traps, searched on the worker (ai's lookout::traps): the ask's id, or 0, and the
    // position it is for, the other side to move.
    trapping: i64             = 0,
    trap_pos: rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    // The hint (docs/product.md): hints left a game, each side's against a friend; how far
    // the one shown has gone (panel::Help.stage: 1 the piece lit, 2 its square too); the ask
    // for its move, the position it is for (board::Board.shows), and the move once
    // answered, lit on the next frame (`hint_new`).
    hints:      i64[2]      = [panel::HINTS, panel::HINTS],
    hint_stage: i64         = 0,
    hinting:    i64         = 0,
    hint_shows: i64         = -1,
    hint_move:  rules::Move = rules::Move { .. },
    hint_new:   bool        = false,
    // What each side has taken (taken()), as last counted for the board at rest at
    // `taken_pos` after `taken_len` moves, or -1 for not yet.
    taken:     panel::Taken    = panel::Taken {},
    taken_len: i64             = -1,
    taken_pos: rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
}

// The pieces of each color taken so far (task 052): the start's pieces less those on the
// board, so a game set up from a position counts what it lacks as taken. Kings apart: a
// piece taken while a king counts as a king, as the child saw it taken, found from the
// undo history's positions (a king of the side not moving gone after the move), so
// kings taken more than board::MAX_HISTORY moves back count as men.
fn taken(b: board::Board&) -> panel::Taken {
    var t = panel::Taken {};
    let v .= rules::VARIANTS[b.variant];
    for c in 2 {
        let lost = max(popcount(v.start[c]) - popcount(b.pos.pieces[c]), 0);
        var kings: i64 = 0;
        for st, i in b.history {
            let a = st.pos;
            guard a.side != c else { continue; }
            let next = if i + 1 < b.history.len { b.history[i + 1].pos } else { b.pos };
            kings += popcount(a.pieces[c] & a.kings & ~next.pieces[c]);
        }
        t.kings[c] = min(kings, lost);
        t.men[c] = lost - t.kings[c];
    }
    return t;
}

// Counts what each side has taken again where the board, at rest, shows another position
// than it was counted for (a move has shown, or undo, start over). Returns whether the
// counts may have changed.
fn count_taken(gm: Game&) -> bool {
    let b .= gm.b;
    guard !b.moving else { return false; }
    let p = b.pos;
    let q = gm.taken_pos;
    guard gm.taken_len != b.history.len || p.pieces[0] != q.pieces[0] || p.pieces[1] != q.pieces[1]
          || p.kings != q.kings || p.side != q.side || p.variant != q.variant else { return false; }
    gm.taken = taken(b);
    gm.taken_len = b.history.len;
    gm.taken_pos = p;
    return true;
}

// What the lookout last worked its threats out for (watch): whether it showed, the
// position, and the held piece and the square under it.
struct Watch {
    on:       bool            = false,
    pos:      rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    selected: i64             = -1,
    over:     i64             = -1,
    shows:    i64             = -1,     // board::Board.shows: a position shown again clears the marks
}

fn new(variant: u8) -> Game {
    var gm = Game { b: board::new(variant), .. };
    gm.turn = gm.b.pos.side;
    return gm;
}

// Starts a new game of `variant` with a clock of `kind` (clock::NONE..), against the
// computer playing `computer` at `level` and `skill`, or against a friend for -1. The
// game's `number` varies the computer's moves from one game to the next.
fn start(gm: Game&, variant: u8, kind: i64, computer: i64, level: i64, skill: i64, number: i64) {
    board::reset(gm.b, variant);
    gm.clock = clock::new(kind);
    gm.computer = computer;
    gm.level = level;
    gm.skill = skill;
    gm.number = number;
    gm.turn = gm.b.pos.side;
    gm.seen = -1.0;
    gm.won_at = -1.0;
    gm.drawn_at = -1.0;
    gm.seen_len = -1;
    gm.counted = false;
    gm.result = 0;
    gm.asking = 0;
    gm.restarted = false;
    gm.watched = Watch {};
    new_hints(gm);
    rig::reset(gm.cam);
}

// A game's hints, all of them left, none shown or asked for.
fn new_hints(gm: Game&) {
    gm.hints = [panel::HINTS, panel::HINTS];
    gm.hint_stage = 0;
    gm.hinting = 0;
    gm.hint_new = false;
}

// Starts the game over from where it began, the clocks full again: a new game, whose
// result counts again, the 3D board's showcase angle easing back from `now`. The shell
// sees `restarted` and gives it its skill and number.
fn restart(gm: Game&, now: f64 = 0.0) {
    gm.restarted = true;
    board::restart(gm.b);
    gm.clock = clock::new(gm.clock.kind);
    gm.turn = gm.b.pos.side;
    gm.won_at = -1.0;
    gm.drawn_at = -1.0;
    gm.counted = false;
    gm.asking = 0;
    new_hints(gm);
    rig::settle(gm.cam, now);
}

// The side that has won, or -1 while the game goes on: the other side has no move left
// (once the move has shown), or its time ran out.
fn winner(gm: Game&) -> i64 {
    if gm.clock.flag >= 0 { return 1 - gm.clock.flag; }
    return board::winner(gm.b);
}

// The game's past for draws at the board's position, folded again when the position
// changed: a move, undo, start over, a saved game brought back.
fn past(gm: Game&) -> rules::Past& {
    let b .= gm.b;
    if gm.seen_len != b.history.len || !rules::same(gm.seen_pos, b.pos) {
        board::past(b, gm.past);
        gm.seen_len = b.history.len;
        gm.seen_pos = b.pos;
    }
    return gm.past;
}

// Why the game is drawn (rules::DRAW_*), or rules::NO_DRAW while it goes on: once the
// drawing move has shown, unless it won (the other side has no move, or no time).
fn drawn(gm: Game&) -> i64 {
    guard winner(gm) < 0 && !gm.b.moving else { return rules::NO_DRAW; }
    return rules::draw_reason(past(gm).draw, gm.b.pos);
}

// Whether the game is over, won or drawn.
fn ended(gm: Game&) -> bool { winner(gm) >= 0 || drawn(gm) != rules::NO_DRAW }

// Whether the computer is to move, for the app to ask it for a move.
fn computer_to_move(gm: Game&) -> bool {
    return gm.computer >= 0 && !gm.b.moving && gm.b.pos.side == gm.computer && !ended(gm);
}

// The clock counts nothing until the frame after the next: the app was paused or lost
// focus, or the game screen was left. A move the computer was asked for is dropped, and
// asked for again when the game shows.
fn pause(gm: Game&) {
    gm.seen = -1.0;
    gm.asking = 0;
}

// What the game asks the computer player for: a move in `pos` at `skill`, with `seed`
// for its choices; id 0 when it asks for nothing. A flat value, so it can go to a worker.
struct Ask {
    id:    i64,
    pos:   rules::Position,
    past:  rules::Past,     // the game before pos, for the draws (ai::start_after)
    skill: i64,
    seed:  u64,
    kind:  i64 = THINK,
}

// What an ask is for: the computer's move, the hint's (ai::helping), or the lookout's
// traps (ai's lookout::traps, no search).
let THINK = 0;
let HINT = 1;
let TRAPS = 2;

fn asking(gm: Game&) -> Ask {
    // The seed: the game's number and the ply, so moves vary between games yet the same
    // game replays the same.
    let seed = (gm.number as u64) * 1000 + gm.b.history.len as u64;
    return Ask { id: gm.asking, pos: gm.b.pos, past: past(gm), skill: gm.skill, seed: seed };
}

// The ask the worker should have, by its id: the computer's move, else the hint's, else
// none (0). One at a time: the hint is asked on the side to move's turn, the computer's
// move on its own.
fn open_ask(gm: Game&) -> i64 { if gm.asking != 0 { gm.asking } else if gm.hinting != 0 { gm.hinting } else { gm.trapping } }

// That ask in full: the hint's searched at HINT_UP above the skill of the side it plays
// against (the computer's, or against a friend the player's on their level), capped.
fn ask_for(gm: Game&) -> Ask {
    var a = asking(gm);
    guard gm.asking == 0 else { return a; }
    if gm.hinting != 0 {
        let against = if gm.computer >= 0 { gm.skill } else { gm.look_skill };
        a.id = gm.hinting;
        a.skill = min(against + HINT_UP, 100);
        a.kind = HINT;
    } else if gm.trapping != 0 {
        a.id = gm.trapping;
        a.pos = gm.trap_pos;
        a.kind = TRAPS;
    }
    return a;
}

// The lookout's traps for the ask `id`, from the worker (or a test), as they stand in the
// position it was asked for: marked with the other threats, the held piece's on the
// square it was taken from. One for an ask no longer open is ignored. True when shown.
fn trapped(gm: Game&, id: i64, pieces: u64) -> bool {
    guard id != 0 && id == gm.trapping else { return false; }
    gm.trapping = 0;
    let w .= gm.watched;
    var p = pieces & gm.b.pos.pieces[gm.b.pos.side] | (if w.over >= 0 && pieces & rules::bit(w.over) != 0 { rules::bit(w.selected) } else { 0 });
    gm.b.danger |= p;
    return p != 0;
}

// Whether the hint can be asked for or shown on: the side to move's turn, the board at
// rest with no capture due (the must-capture ring says what to do then) and no piece
// waiting partway through one, the game going on.
fn can_hint(gm: Game&) -> bool {
    let b .= gm.b;
    return !b.moving && b.pos.side != gm.computer && !ended(gm) && !board::must_capture(b) && b.steps.len == 0;
}

// The hint's move for the ask `id`, from the worker (or a test): spends one of the side's
// hints and lights the piece to move on the next frame. One for an ask no longer open is
// ignored.
fn hinted(gm: Game&, id: i64, m: rules::Move) {
    guard id != 0 && id == gm.hinting else { return; }
    gm.hinting = 0;
    let side = gm.b.pos.side;
    gm.hints[side] = max(gm.hints[side] - 1, 0);
    gm.hint_move = m;
    gm.hint_stage = 1;
    gm.hint_new = true;
}

// Whether an ask the app waits on for no frame of its own is open (the hint's), for the
// loop to wake soon and take its answer.
fn awaiting(gm: Game&) -> bool { gm.hinting != 0 || gm.trapping != 0 }

// The hint's tile pressed: the first press asks for the move (answered, it lights the
// piece and spends a hint), the second shows the square with a light ghost of the piece,
// for nothing more; then it stays until the move.
fn press_hint(gm: Game&, now: f64) {
    guard can_hint(gm) else { return; }
    let b .= gm.b;
    if gm.hint_stage == 0 && gm.hinting == 0 && gm.hints[b.pos.side] > 0 {
        gm.asks += 1;
        gm.hinting = gm.asks;
        gm.hint_shows = b.shows;
    } else if gm.hint_stage == 1 {
        board::ghost_on(b, gm.hint_move.to, now);
        gm.hint_stage = 2;
    }
}

// The computer's move for the ask `id`, `close` of the moves about as good as it
// (ai::close); one for an ask no longer open is ignored. Its move comes after the
// level's pause, or, while its clock runs, after the time a player of its level would
// take (pace::seconds).
fn answer(gm: Game&, id: i64, m: rules::Move, close: i64) {
    guard id != 0 && id == gm.asking else { return; }
    gm.reply = m;
    gm.answered = true;
    let level = clamp(gm.level, EASY, HARD);
    gm.wait = PAUSE[level];
    guard gm.clock.running == gm.computer else { return; }
    gm.wait = pace::seconds(PAUSE[level], level, gm.clock.left[gm.computer], clock::INCREMENTS[gm.clock.kind],
                            gm.b.history.len, gm.b.moves.len, board::must_capture(gm.b), pace::tense(gm.b.pos, m),
                            close);
}

// Takes back a move, also one still animating: against the computer, the child's last
// move and the computer's reply to it, if it made one, so it is the child's turn again;
// nothing before the child's first move. A move asked for is dropped.
fn take_back(gm: Game&) -> bool {
    let b .= gm.b;
    var done = false;
    if gm.computer < 0 || b.pos.side == gm.computer {
        done = board::undo(b);
    } else if b.history.len >= 2 {
        board::undo(b);
        done = board::undo(b);
    }
    if done { gm.asking = 0; }
    return done;
}

// The computer's turn: ask for its move when the turn begins, and play the answer once
// it has come and the pause is over. True when its move began.
fn think(gm: Game&, now: f64) -> bool {
    guard computer_to_move(gm) else {
        gm.asking = 0;
        return false;
    }
    if gm.asking == 0 {
        gm.asks += 1;
        gm.asking = gm.asks;
        gm.asked_at = now;
        gm.answered = false;
    }
    guard gm.answered && now >= gm.asked_at + gm.wait else { return false; }
    let b .= gm.b;
    gm.asking = 0;
    for k in b.moves.len {
        let m .= b.moves[k];
        guard m.from == gm.reply.from && m.to == gm.reply.to && m.captured == gm.reply.captured else { continue; }
        board::start_move(b, k, now);
        return true;
    }
    return false;
}

// The computer's ring as it begins to think: full, fading to a third and back once,
// then still. A longer think shows on its clock, which counts each second, so the app
// draws nothing more until the move (due()).
fn pulse(gm: Game&, now: f64) -> f32 {
    guard gm.asking != 0 && now < gm.asked_at + PULSE else { return 1.0; }
    return (0.65 + 0.35 * cos(2.0 * PI * (now - gm.asked_at) / PULSE)) as f32;
}

// Seconds until the computer's move is due, for the app to wake then, or -1.
fn due(gm: Game&, now: f64) -> f64 {
    guard gm.asking != 0 && gm.answered else { return -1.0; }
    return max(gm.asked_at + gm.wait - now, 0.0);
}

// One frame, after gui::begin, its pieces over the UI put in `over`. Returns what the
// shell should do and whether anything on screen changed. `frozen` (the shell's
// transition into the game) counts no time on the clock and asks the computer for
// nothing; the clock counts again from the frame after.
fn frame(gm: Game&, g: gui::Gui&, l: panel::Layout, now: f64, over: Overlay&, frozen: bool = false) -> i64, bool {
    let b .= gm.b;
    let input = g.input;
    var changed = board::update(b, now) || input.pressed || input.released;
    var go = STAY;
    over.clear();
    if !frozen && gm.seen >= 0.0 && clock::tick(gm.clock, min(now - gm.seen, STEP)) { changed = true; }
    gm.seen = if frozen { -1.0 } else { now };

    // The side to move, or the winner once there is one.
    var won = winner(gm);
    let side = if won >= 0 { won } else { b.pos.side as i64 };
    var note = panel::Note {};
    countdown(gm, note);
    let pick = panel::game(g, l, gm.clock, side, won >= 0, drawn(gm) != rules::NO_DRAW, note, gm.asking != 0,
                           pulse(gm, now), over, help(gm));
    if count_taken(gm) { changed = true; }
    panel::taken(g, l, gm.taken, over);
    var undone = false;
    match pick {
        // Partway through a capture, take back only takes the capture back to its start.
        panel::UNDO => { if !board::unwind(b) && gm.clock.flag < 0 { undone = take_back(gm); } },
        panel::RESTART => { restart(gm, now); },
        panel::BACK => { go = HOME; },
        panel::SETTINGS => { go = SETTINGS; },
        panel::LOOKOUT => { gm.look = !gm.look; },
        panel::HINT => { press_hint(gm, now); },
        _ => {},
    }
    if pick != panel::NOTHING { changed = true; }
    if panel::camera(g, l, gm.cam, now) { changed = true; }

    if !frozen && think(gm, now) { changed = true; }
    won = winner(gm);
    let draw = drawn(gm);
    if draw == rules::NO_DRAW {
        gm.drawn_at = -1.0;
    } else if gm.drawn_at < 0.0 {
        gm.drawn_at = now;
        gm.drawn_still = false;
        changed = true;
        // A draw counts too, as 0: the computer's skill stays (ai::adapt).
        if gm.computer >= 0 && !gm.counted {
            gm.counted = true;
            gm.result = 0;
        }
    }
    if won < 0 {
        gm.won_at = -1.0;
    } else if gm.won_at < 0.0 {
        gm.won_at = now;
        aim(gm, won);
        changed = true;
        // A game against the computer counts once, when it first ends: the result
        // moves the computer's skill (ai::adapt).
        if gm.computer >= 0 && !gm.counted {
            gm.counted = true;
            gm.result = if won == gm.computer { -1 } else { 1 };
        }
    }
    if gm.won_at >= 0.0 {
        // The frame from which the celebration is still is drawn too, at rest.
        if !gm.stilled && moment(gm, now) >= gm.still {
            gm.stilled = true;
            changed = true;
        }
        let ask = celebrate(gm, g, l, won, now, over);
        if ask == panel::RESTART {
            restart(gm, now);
            changed = true;
        }
        if ask == panel::BACK { go = HOME; }
    } else if gm.drawn_at >= 0.0 {
        if !gm.drawn_still && now - gm.drawn_at >= DRAW_STILL {
            gm.drawn_still = true;
            changed = true;
        }
        let ask = settle(gm, g, l, draw, now, over);
        if ask == panel::RESTART {
            restart(gm, now);
            changed = true;
        }
        if ask == panel::BACK { go = HOME; }
    } else if !g.took && l.three && gm.cam.showcase {
        // The showcase: a drag anywhere off the UI turns and tips the board, not a piece.
        if rig::drive(gm.cam, input.at, input.down, input.pressed, input.released, g.scale, l.pitch, now) {
            changed = true;
        }
    } else if !g.took && b.pos.side != gm.computer {
        if touch(b, l, input, gm.grab, now) { changed = true; }
    }
    // Against a friend the 3D board turns to face the side to move once a move has shown,
    // unless the game is over; against the computer it stays turned to the child.
    if l.three && !frozen && gm.computer < 0 && !ended(gm) && !b.moving && b.pressed < 0 {
        if rig::face(gm.cam, b.pos.side, now) { changed = true; }
    }
    // A move made or taken back, whichever way: the clocks follow it, and stop once the
    // side to move has none.
    if undone {
        clock::undone(gm.clock, b.pos.side, b.history.len == 0);
    } else if b.pos.side != gm.turn {
        clock::moved(gm.clock, gm.turn);
    }
    gm.turn = b.pos.side;
    if watch(gm) { changed = true; }
    // The hint belongs to the position it was asked in: a move, undo, or start over ends
    // it. Its answer lights the piece on the frame after it came.
    if (gm.hint_stage > 0 || gm.hinting != 0) && b.shows != gm.hint_shows {
        gm.hint_stage = 0;
        gm.hinting = 0;
        gm.hint_new = false;
        changed = true;
    }
    if gm.hint_new {
        gm.hint_new = false;
        board::glow_on(b, gm.hint_move.from, now);
        changed = true;
    }
    // The computer's pieces show no count of what they must take: the child can't move them.
    b.quiet = gm.computer >= 0 && b.pos.side == gm.computer;
    if b.moves.len == 0 || drawn(gm) != rules::NO_DRAW { clock::stop(gm.clock); }
    // A running clock draws once a second, when the time it shows changes.
    let shown = if gm.clock.running >= 0 { clock::shown(gm.clock, gm.clock.running) } else { -1 };
    if shown != gm.shown {
        gm.shown = shown;
        changed = true;
    }
    return go, changed;
}

// The pointer on the board this frame: a press, a drag, a release, as board::press and
// the rest take them. On the 3D board (l.three) a tap reaches the flat layout through the
// perspective (view3d::pick); a piece held moves on the plane of its lifted top, kept
// where the finger took it (`grab`, the screen's own), so a press doesn't drag it before
// the finger moves. The game and a puzzle share it. Returns whether a drag moved a piece.
fn touch(b: board::Board&, l: panel::Layout, input: gui::Input, grab: float2&, now: f64) -> bool {
    let at = if l.three { view3d::pick(l.view, b, l.board, input.at) } else { input.at };
    if input.pressed {
        board::press(b, l.board, at, now);
        if l.three && b.pressed >= 0 { grab = b.press_at - view3d::pick(l.view, b, l.board, input.at); }
    }
    let held = if l.three && b.pressed >= 0 { view3d::pick(l.view, b, l.board, input.at) + grab } else { at };
    var moved = false;
    if input.down && board::drag(b, l.board, held) { moved = true; }
    if input.released { board::release(b, l.board, held, now); }
    // The square under a held piece, or under the mouse over a piece selected by a tap, for
    // the lookout: a finger lifted from a tap rests on the piece, so on touch it is only
    // while a drag goes.
    b.over = if b.dragging { board::target_at(b, l.board, held) }
             else if !input.down && b.pressed < 0 { board::target_at(b, l.board, at) } else { -1 };
    return moved;
}

// Whether the lookout shows now: on, the side to move's turn and the board at rest, the
// game going on, no capture due (the must-capture ring says what to do then). Against a
// friend it watches for whoever's turn it is.
fn watching(gm: Game&) -> bool {
    let b .= gm.b;
    return gm.look && !b.moving && b.pos.side != gm.computer && !ended(gm) && !board::must_capture(b);
}

// The lookout's marks on the board (Board.danger, crowns), worked out again only when
// what they depend on changed: the position, whether it shows, the held piece and the
// square under it. Then the side to move's threats now, or the ones the held piece's move
// would leave, of the kinds the skill leaves out (ai's lookout::shown). Two move
// generations into a buffer on the stack. True when the marks changed.
fn watch(gm: Game&) -> bool {
    let b .= gm.b;
    let on = watching(gm);
    let over = if on { b.over } else { -1 };
    let selected = if over >= 0 { b.selected } else { -1 };
    let w .= gm.watched;
    guard on != w.on || over != w.over || selected != w.selected || (on && (!rules::same(b.pos, w.pos) || b.shows != w.shows))
    else { return false; }
    gm.watched = Watch { on: on, pos: b.pos, selected: selected, over: over, shows: b.shows };
    let danger = b.danger;
    let crowns = b.crowns;
    b.danger = 0;
    b.crowns = 0;
    gm.trapping = 0;
    if on {
        var buf: rules::Moves = [];
        var seen = lookout::Seen {};
        var k = -1;
        if over >= 0 { for m, i in b.moves { if m.from == selected && m.to == over { k = i; } } }
        if k >= 0 { lookout::after(b.pos, b.moves[k], seen, buf); } else { lookout::now(b.pos, seen, buf); }
        let d, c = lookout::shown(seen, gm.look_skill);
        b.danger = d;
        b.crowns = c;
        // The traps, three plies, on the worker: the other side to move, as now or after
        // the held piece's move.
        if gm.look_skill < lookout::UNTIL[lookout::TRAP] {
            var q = b.pos;
            q.side = 1 - q.side;
            if k >= 0 { q = rules::play(b.pos, b.moves[k]); }
            gm.asks += 1;
            gm.trapping = gm.asks;
            gm.trap_pos = q;
        }
    }
    return b.danger != danger || b.crowns != crowns;
}

// What the play panel shows of the lookout and the hint.
fn help(gm: Game&) -> panel::Help {
    let side = clamp(gm.b.pos.side as i64, 0, 1);
    return panel::Help { look: gm.look, left: gm.hints[side], stage: gm.hint_stage, can: can_hint(gm) };
}

// Declares the screen as it stands, its pieces over the UI put in `over`, doing nothing:
// the shell's transition away from the game, with the pointer taken away and the clocks
// paused. A win's card is declared as it is, to fade with the panels.
fn still(gm: Game&, g: gui::Gui&, l: panel::Layout, now: f64, over: Overlay&) {
    over.clear();
    let won = winner(gm);
    let side = if won >= 0 { won } else { gm.b.pos.side as i64 };
    var note = panel::Note {};
    countdown(gm, note);
    let draw = drawn(gm);
    panel::game(g, l, gm.clock, side, won >= 0, draw != rules::NO_DRAW, note, gm.asking != 0, pulse(gm, now), over,
                help(gm));
    // Counted here too: a transition declares a game before its first frame of its own.
    count_taken(gm);
    panel::taken(g, l, gm.taken, over);
    panel::camera(g, l, gm.cam, now);
    if gm.won_at >= 0.0 { celebrate(gm, g, l, won, now, over); }
    if gm.drawn_at >= 0.0 { settle(gm, g, l, draw, now, over); }
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(gm: Game&, g: gui::Gui&, now: f64) -> bool {
    let celebrating = (gm.won_at >= 0.0 && moment(gm, now) < gm.still) || (gm.drawn_at >= 0.0 && now - gm.drawn_at < DRAW_STILL);
    let pulsing = gm.asking != 0 && (!gm.answered || now < gm.asked_at + PULSE);
    return board::animating(gm.b, now) || gui::animating(g) || celebrating || pulsing || rig::moving(gm.cam, now);
}

// A piece of `side` over the UI centered in `spot` with radius r, at opacity a, a man (0)
// or a king as board::CROWN or board::STACK draws it, with a glow ring right round it or
// not.
fn put(over: Overlay&, spot: float4, r: f32, side: i64, king: i64, a: f32, ring: bool) {
    panel::piece(over, spot, r, side, king, a, if ring { 1.0 } else { 0.0 });
}

// The celebration's moment at `now`: seconds since the win, or with no winning piece to
// lift (a flag during a move, a position set up already won) from where the board
// dims, so the dim and the card come at once.
fn moment(gm: Game&, now: f64) -> f64 {
    let skip = if gm.won_on < 0 { DIM_AT } else { 0.0 };
    return now - gm.won_at + skip;
}

// The win begins: the winning piece is the last move's, the winner's whichever way the
// game ended (the side that ran out of moves or time was to move after it), unless the
// move is still showing or there was none. The celebration is still once the card is in
// and the glow has passed the winner's farthest piece.
fn aim(gm: Game&, won: i64) {
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    gm.won_on = -1;
    gm.still = STILL;
    gm.stilled = false;
    guard b.has_last && !b.moving && b.pos.pieces[won] & rules::bit(b.last.to) != 0 else { return; }
    gm.won_on = b.last.to;
    var left = b.pos.pieces[won];
    while left != 0 {
        let sq = ctz(left);
        left &= left - 1;
        gm.still = max(gm.still, WAVE_AT + WAVE_STEP * apart(v, sq, gm.won_on) + WAVE);
    }
}

// How many squares apart two squares are, straight across the board.
fn apart(v: rules::Variant&, a: i64, b: i64) -> f64 {
    let dx = v.x_of[a] as f64 - v.x_of[b];
    let dy = v.y_of[a] as f64 - v.y_of[b];
    return sqrt(dx * dx + dy * dy);
}

// Where t is from a to b, 0..1; eased in and out; eased out; up and back down.
fn span(t: f64, a: f64, b: f64) -> f64 { clamp((t - a) / (b - a), 0.0, 1.0) }
fn smooth(x: f64) -> f64 { x * x * (3.0 - 2.0 * x) }
fn ease_out(x: f64) -> f64 { 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x) }
fn bump(x: f64) -> f64 { if x <= 0.0 || x >= 1.0 { 0.0 } else { sin(PI * x) } }

// The win on the board, after board::fill (shell::fill): the board dims under the winning
// piece, which lifts with its ring and is drawn last, over the others; the glow passes
// the winner's other pieces, each lifting a little with its ring and its square lit. A
// piece lifts 6% of its size and grows 5%. The pieces are on their squares: the win
// waits for the move to show. `share` scales it all, the dim, the lifts, and the glow,
// as the game screen fades out or in through a transition.
fn cheer(gm: Game&, l: board::Layout, now: f64, share: f32 = 1.0) {
    if gm.drawn_at >= 0.0 {
        let b .= gm.b;
        b.dim = (DIM * smooth(span(now - gm.drawn_at, 0.0, DRAW_DIM))) as f32 * share;
        for &p in b.pieces { p.win.x = b.dim; }
        return;
    }
    guard gm.won_at >= 0.0 else { return; }
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    let t = moment(gm, now);
    let won = winner(gm);
    b.dim = (DIM * smooth(span(t, DIM_AT, DIM_AT + 0.6))) as f32 * share;
    var top = -1;
    for i in b.pieces.len {
        let p .= b.pieces[i];
        p.win.x = b.dim;
        let sq = board::hit(l, v, float2 { p.at.x, p.at.y });
        guard gm.won_on >= 0 && won >= 0 && sq >= 0 && b.pos.pieces[won] & rules::bit(sq) != 0 else { continue; }
        var k = 0.0;
        if sq == gm.won_on {
            k = ease_out(span(t, 0.0, LIFT));
            p.win.x = 0.0;
            top = i;
        } else {
            let at = WAVE_AT + WAVE_STEP * apart(v, sq, gm.won_on);
            k = bump(span(t, at, at + WAVE));
            p.win.y = k as f32;
        }
        let f = k as f32 * share;
        p.win.y *= share;
        let r = p.at.z;
        p.at.z = r * (1.0 + 0.05 * f);
        p.at.w += 0.12 * r * f;
        p.ring.y = max(p.ring.y, f);
        p.win.z = 0.5 * l.inner.w / p.at.z;
    }
    guard top >= 0 else { return; }
    let p = b.pieces[top];
    for i in top..b.pieces.len - 1 { b.pieces[i] = b.pieces[i + 1]; }
    b.pieces[b.pieces.len - 1] = p;
}

// Where the win's card is centered, and which it keeps inside: the flat board, or the 3D
// board's bounds on screen.
fn card_area(pl: panel::Layout) -> float4 {
    let l = pl.board;
    return if pl.three { pl.view.rect } else { float4 { l.board.x, l.board.y, l.board.z, l.board.z } };
}

// The winning piece on screen, its middle and its radius in pixels, for the card to keep
// clear of: on the flat board the disc as board::fill draws it, on the 3D board its top
// as the perspective shows it.
fn winning_spot(gm: Game&, pl: panel::Layout) -> float2, f32 { return spot_of(gm, pl, gm.won_on); }

// The piece on square `sq` on screen, its middle and its radius in pixels.
fn spot_of(gm: Game&, pl: panel::Layout, sq: i64) -> float2, f32 {
    let l = pl.board;
    let at = board::center(l, rules::VARIANTS[gm.b.variant], sq);
    guard pl.three else { return at, 0.39 * l.inner.w; }
    let s = view3d::on_screen(pl.view, l, at);
    return float2 { s.x, s.y }, s.z;
}

// The card over the dimmed board once the pieces have answered: the winner's piece,
// crowned, fading in over restart or back; it slides up as it fades in, its taps where
// it is at rest. On the 3D board it is placed by the board's bounds on screen and the
// winning piece where the perspective shows it. Returns panel::RESTART, panel::BACK, or
// panel::NOTHING.
fn celebrate(gm: Game&, g: gui::Gui&, pl: panel::Layout, won: i64, now: f64, over: Overlay&) -> i64 {
    let t = moment(gm, now);
    guard t >= CARD_AT else { return panel::NOTHING; }
    let l = pl.board;
    let u = l.scale;
    let area = card_area(pl);
    // The card: 40 dp above and below, 56 dp at the sides; the piece, a 28 dp gap, the
    // buttons, 112 × 88 dp. On a board under panel::BOARD all but the buttons' height
    // shrink with it, the buttons' width down to 88 dp: 356 × 300 dp, 49% of the
    // tablet's board, comes to 52% of the smallest (the foldable's 520 dp) where it
    // would be 68%.
    let fit: f32 = min(1.0, l.board.z / (panel::BOARD * u));
    let button = max(88.0, 112.0 * fit);
    let first = g.quads.len;
    var card = gui::center(area, (112.0 * fit + 2.0 * button + 20.0 * fit) * u,
                           ((40.0 + 40.0 + 104.0 + 28.0) * fit + 88.0) * u);
    // Centered on the board, unless it would cover the winning piece (a phone's board):
    // then in the half away from it, as near the middle as clears the piece.
    if gm.won_on >= 0 {
        let at, r = winning_spot(gm, pl);
        if at.x + r > card.x && at.x - r < card.x + card.z && at.y + r > card.y && at.y - r < card.y + card.w {
            let middle = area.y + 0.5 * area.w;
            card.y = if at.y >= middle { max(area.y, min(middle, at.y - r) - card.w) }
                     else { min(area.y + area.w - card.w, max(middle, at.y + r)) };
        }
    }
    gui::panel(g, card);
    var c = gui::inset(card, 40.0 * fit * u);
    var spot = gui::cut_top(c, 104.0 * fit * u);
    gui::cut_top(c, 28.0 * fit * u);
    let row = gui::cut_top(c, 88.0 * u);
    var ask = panel::NOTHING;
    let gap = 20.0 * fit * u;
    if gui::button(g, 200, gui::cell(row, 2, 1, button * u, 88.0 * u, gap, 0), gui::BACK) { ask = panel::BACK; }
    if gui::tile(g, 201, gui::cell(row, 2, 1, button * u, 88.0 * u, gap, 1), gui::RESTART, gui::PRIMARY, 22.0) {
        ask = panel::RESTART;
    }
    let k = ease_out(span(t, CARD_AT, CARD_AT + 0.7));
    let drop = floor((1.0 - k) * SLIDE * u + 0.5) as f32;
    gui::fade(g, first, g.quads.len, k as f32, float2 { 0.0, drop });
    gui::on_board(g, first, g.quads.len);
    spot.y += drop;
    let a = smooth(span(t, CROWN_AT, STILL)) as f32;
    let n = over.len;
    panel::piece(over, spot, 44.0 * fit * u, won, gm.b.king_look, a, a);
    if over.len > n { over[n].win.w = 1.0; }   // on the board, as the card is
    return ask;
}

// The countdown before a draw (rules::countdown), as the play panel words it: the moves
// left out of the last five, or the position come twice out of three.
fn countdown(gm: Game&, note: panel::Note&) {
    guard !ended(gm) && !gm.b.moving else { return; }
    let c = rules::countdown(past(gm).draw, gm.b.pos);
    guard c.kind != rules::COUNT_NONE else { return; }
    note.of = rules::SOON;
    note.lit = c.moves;
    let one = c.moves == 1;
    note.word.append(strings::get(strings::COUNT_SHORT));
    note.fig.push(('0' + c.moves) as u8);
    if c.kind == rules::COUNT_DRAW {
        strings::fill_in(note.line, if one { strings::COUNT_DRAW_ONE } else { strings::COUNT_DRAW }, [c.moves]);
    } else if c.kind == rules::COUNT_WIN {
        let key = if c.side == rules::WHITE { if one { strings::COUNT_WHITE_ONE } else { strings::COUNT_WHITE } }
                  else if one { strings::COUNT_BLACK_ONE } else { strings::COUNT_BLACK };
        strings::fill_in(note.line, key, [c.moves]);
    } else {
        strings::fill_in(note.line, strings::COUNT_TWICE, []);
        note.more = true;
        note.of = 3;
        note.lit = 2;
        note.word.clear();
        note.word.append(strings::get(strings::COUNT_REPEATED));
        note.fig.clear();
        note.fig.push(('0' + note.lit) as u8);
        note.fig.push('/');
        note.fig.push(('0' + note.of) as u8);
    }
}

// Why the game was drawn, in words, into out.
fn reason(gm: Game&, draw: i64, out: u8[..64]&) {
    let key = match draw {
        rules::DRAW_REPEAT => strings::DRAW_REPEAT,
        rules::DRAW_KINGS => strings::DRAW_KINGS,
        rules::DRAW_BALANCE => strings::DRAW_BALANCE,
        _ => strings::DRAW_LONE,
    };
    strings::fill_in(out, key, [rules::draw_moves(gm.b.pos, draw)]);
}

// The draw's card over the dimmed board (rendering.md, "Controls", A draw): both pieces side
// by side, "Draw", and why, over back and play again, sliding up as it fades in, its
// taps where it is at rest. Sized and placed as the win's card, kept off the piece that
// made the last move; on a board under 540 dp the words say it, and the pieces are left
// out. Returns panel::RESTART, panel::BACK, or panel::NOTHING.
fn settle(gm: Game&, g: gui::Gui&, pl: panel::Layout, draw: i64, now: f64, over: Overlay&) -> i64 {
    let t = now - gm.drawn_at;
    guard t >= DRAW_CARD else { return panel::NOTHING; }
    let l = pl.board;
    let u = l.scale;
    let area = card_area(pl);
    let fit: f32 = min(1.0, l.board.z / (panel::BOARD * u));
    let button = max(88.0, 112.0 * fit);
    let pieces = l.board.z >= 540.0 * u;
    let width = (112.0 * fit + 2.0 * button + 20.0 * fit) * u;
    let room = width - 112.0 * fit * u;
    var why: u8[..64] = [];
    reason(gm, draw, why);
    let head .= g.faces[gui::LABEL];
    let small .= g.faces[gui::BODY];
    let line = small.ascent - small.descent;
    let cut = panel::note_break(g, gui::BODY, why, room);
    let lines: f32 = if cut >= 0 { 2.0 } else { 1.0 };
    let say = head.ascent - head.descent + 6.0 * u + lines * line;
    let spot_h: f32 = if pieces { (104.0 + 28.0 - 10.0) * fit * u } else { 0.0 };
    let first = g.quads.len;
    var card = gui::center(area, width, (80.0 + 28.0) * fit * u + spot_h + say + 88.0 * u);
    if gm.b.has_last {
        let at, r = spot_of(gm, pl, gm.b.last.to);
        if at.x + r > card.x && at.x - r < card.x + card.z && at.y + r > card.y && at.y - r < card.y + card.w {
            let middle = area.y + 0.5 * area.w;
            card.y = if at.y >= middle { max(area.y, min(middle, at.y - r) - card.w) }
                     else { min(area.y + area.w - card.w, max(middle, at.y + r)) };
        }
    }
    gui::panel(g, card);
    var c = gui::inset(card, 40.0 * fit * u);
    var spot = float4 { 0.0, 0.0, 0.0, 0.0 };
    if pieces {
        spot = gui::cut_top(c, 104.0 * fit * u);
        gui::cut_top(c, (28.0 - 10.0) * fit * u);
    }
    let words = strings::get(strings::DRAW);
    gui::text(g, gui::LABEL, gui::cut_top(c, head.ascent - head.descent), words, 1.0, 0.0, gui::CENTER);
    gui::cut_top(c, 6.0 * u);
    if cut >= 0 {
        gui::text(g, gui::BODY, gui::cut_top(c, line), why[..cut], 0.66, 0.0, gui::CENTER);
        gui::text(g, gui::BODY, gui::cut_top(c, line), why[cut + 1..], 0.66, 0.0, gui::CENTER);
    } else {
        gui::text(g, gui::BODY, gui::cut_top(c, line), why, 0.66, 0.0, gui::CENTER);
    }
    gui::cut_top(c, 28.0 * fit * u);
    let row = gui::cut_top(c, 88.0 * u);
    var ask = panel::NOTHING;
    let gap = 20.0 * fit * u;
    if gui::button(g, 200, gui::cell(row, 2, 1, button * u, 88.0 * u, gap, 0), gui::BACK) { ask = panel::BACK; }
    if gui::tile(g, 201, gui::cell(row, 2, 1, button * u, 88.0 * u, gap, 1), gui::RESTART, gui::PRIMARY, 22.0) {
        ask = panel::RESTART;
    }
    let k = ease_out(span(t, DRAW_CARD, DRAW_STILL));
    let drop = floor((1.0 - k) * SLIDE * u + 0.5) as f32;
    gui::fade(g, first, g.quads.len, k as f32, float2 { 0.0, drop });
    gui::on_board(g, first, g.quads.len);
    guard pieces else { return ask; }
    spot.y += drop;
    let n = over.len;
    panel::pair(over, spot, 44.0 * fit * u, 4.0 * fit * u, k as f32);
    for i in n..over.len { over[i].win.w = 1.0; }   // on the board, as the card is
    return ask;
}
