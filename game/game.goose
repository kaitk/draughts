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
import strings from "../strings";
import .panel;
import .clock;
import .pace;

let POP = 0.6;              // seconds the winner's piece takes to pop in
let SPARKS = 14;
let SPARK_CYCLE = 2.4;      // seconds a spark takes to drift up and fade
let SPARK_CYCLES = 2;       // each spark drifts this many times, then the screen is still
let STEP = 2.0;             // seconds: the longest gap between two frames the clock counts
let PAUSE = [0.8, 0.6, 0.45];   // seconds from the computer's turn to its move without a clock, by level
let PULSE = 1.2;            // seconds: the computer's ring pulses once as it begins to think

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
    skill:    i64          = 45,                    // the computer's for the whole game (ai::level_skill)
    number:   i64          = 0,                     // the game's number, for the computer's seeds
    turn:     u8           = 0,                     // the side to move as last seen, to tell a move was made
    seen:     f64          = -1.0,                  // when the clock last counted, or -1 to count nothing next
    shown:    i64          = -1,                    // the running clock's whole seconds as last drawn
    won_at:   f64          = -1.0,                  // when the celebration began, or -1
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
    gm.counted = false;
    gm.result = 0;
    gm.asking = 0;
}

// Starts the game over from where it began, the clocks full again: a new game, whose
// result counts again.
fn restart(gm: Game&) {
    board::restart(gm.b);
    gm.clock = clock::new(gm.clock.kind);
    gm.turn = gm.b.pos.side;
    gm.won_at = -1.0;
    gm.counted = false;
    gm.asking = 0;
}

// The side that has won, or -1 while the game goes on: the other side has no move left
// (once the move has shown), or its time ran out.
fn winner(gm: Game&) -> i64 {
    if gm.clock.flag >= 0 { return 1 - gm.clock.flag; }
    return board::winner(gm.b);
}

// Whether the computer is to move, for the app to ask it for a move.
fn computer_to_move(gm: Game&) -> bool {
    return gm.computer >= 0 && winner(gm) < 0 && !gm.b.moving && gm.b.pos.side == gm.computer;
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
    skill: i64,
    seed:  u64,
}

fn asking(gm: Game&) -> Ask {
    // The seed: the game's number and the ply, so moves vary between games yet the same
    // game replays the same.
    let seed = (gm.number as u64) * 1000 + gm.b.history.len as u64;
    return Ask { id: gm.asking, pos: gm.b.pos, skill: gm.skill, seed: seed };
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
                            gm.b.history.len, gm.b.moves.len, board::must_capture(gm.b), close);
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
// shell should do and whether anything on screen changed.
fn frame(gm: Game&, g: gui::Gui&, l: board::Layout, now: f64, over: Overlay&) -> i64, bool {
    let b .= gm.b;
    let input = g.input;
    var changed = board::update(b, now) || input.pressed || input.released;
    var go = STAY;
    over.clear();
    if gm.seen >= 0.0 && clock::tick(gm.clock, min(now - gm.seen, STEP)) { changed = true; }
    gm.seen = now;

    // The side to move, or the winner once there is one.
    var won = winner(gm);
    let side = if won >= 0 { won } else { b.pos.side as i64 };
    let pick = panel::game(g, l, gm.clock, side, won >= 0, gm.asking != 0, pulse(gm, now), over);
    var undone = false;
    match pick {
        panel::UNDO => { if gm.clock.flag < 0 { undone = take_back(gm); } },
        panel::RESTART => { restart(gm); },
        panel::HOME => { go = HOME; },
        panel::SETTINGS => { go = SETTINGS; },
        _ => {},
    }
    if pick != panel::NOTHING { changed = true; }

    if think(gm, now) { changed = true; }
    won = winner(gm);
    if won < 0 {
        gm.won_at = -1.0;
    } else if gm.won_at < 0.0 {
        gm.won_at = now;
        changed = true;
        // A game against the computer counts once, when it first ends: the result
        // moves the computer's skill (ai::adapt). A draw would count 0; the rules have
        // none yet.
        if gm.computer >= 0 && !gm.counted {
            gm.counted = true;
            gm.result = if won == gm.computer { -1 } else { 1 };
        }
    }
    if gm.won_at >= 0.0 {
        let ask = celebrate(gm, g, l, won, now, over);
        if ask == panel::RESTART {
            restart(gm);
            changed = true;
        }
        if ask == panel::HOME { go = HOME; }
    } else if !g.took && b.pos.side != gm.computer {
        if input.pressed { board::press(b, l, input.at, now); }
        if input.down && board::drag(b, l, input.at) { changed = true; }
        if input.released { board::release(b, l, input.at, now); }
    }
    // A move made or taken back, whichever way: the clocks follow it, and stop once the
    // side to move has none.
    if undone {
        clock::undone(gm.clock, b.pos.side, b.history.len == 0);
    } else if b.pos.side != gm.turn {
        clock::moved(gm.clock, gm.turn);
    }
    gm.turn = b.pos.side;
    if b.moves.len == 0 { clock::stop(gm.clock); }
    // A running clock draws once a second, when the time it shows changes.
    let shown = if gm.clock.running >= 0 { clock::shown(gm.clock, gm.clock.running) } else { -1 };
    if shown != gm.shown {
        gm.shown = shown;
        changed = true;
    }
    return go, changed;
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(gm: Game&, g: gui::Gui&, now: f64) -> bool {
    let celebrating = gm.won_at >= 0.0 && now < gm.won_at + SPARK_CYCLE * (SPARK_CYCLES + 1);
    let pulsing = gm.asking != 0 && (!gm.answered || now < gm.asked_at + PULSE);
    return board::animating(gm.b, now) || gui::animating(g) || celebrating || pulsing;
}

// A piece of `side` over the UI centered in `spot` with radius r, at opacity a, a man (0)
// or a king as board::CROWN or board::STACK draws it, with a glow ring right round it or
// not.
fn put(over: Overlay&, spot: float4, r: f32, side: i64, king: i64, a: f32, ring: bool) {
    panel::piece(over, spot, r, side, king, a, if ring { 1.0 } else { 0.0 });
}

fn hash(i: i64, k: i64) -> f32 {
    let x = sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return (x - floor(x)) as f32;
}

// The celebration (prototypes/solved.html): the board dimmed, a glass card over it with
// the winner's piece popping in, crowned, then restart or back; a few sparks drift up
// and fade.
// Returns panel::RESTART, panel::HOME, or panel::NOTHING.
fn celebrate(gm: Game&, g: gui::Gui&, l: board::Layout, won: i64, now: f64, over: Overlay&) -> i64 {
    let u = l.scale;
    let t = now - gm.won_at;
    let area = float4 { l.board.x, l.board.y, l.board.z, l.board.z };
    gui::fill(g, area, float4 { 0.0, 0.0, 0.0, 0.45 }, l.board.w);
    // The card: 40 dp above and below, 56 dp at the sides; the piece, a 28 dp gap, the
    // buttons.
    let card = gui::center(area, 356.0 * u, 300.0 * u);
    gui::panel(g, card);
    var c = gui::inset(card, 40.0 * u);
    let spot = gui::cut_top(c, 104.0 * u);
    gui::cut_top(c, 28.0 * u);
    let row = gui::cut_top(c, 88.0 * u);
    var ask = panel::NOTHING;
    if gui::button(g, 200, gui::cell(row, 2, 1, 112.0 * u, 88.0 * u, 20.0 * u, 0), gui::BACK) { ask = panel::HOME; }
    if gui::tile(g, 201, gui::cell(row, 2, 1, 112.0 * u, 88.0 * u, 20.0 * u, 1), gui::RESTART, gui::PRIMARY, 22.0) {
        ask = panel::RESTART;
    }
    // The winner pops in: grows from 0.3 past its size and settles, as CSS
    // cubic-bezier(.2, 1.6, .4, 1) does.
    let k = clamp(t / POP, 0.0, 1.0);
    let s = 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0);
    let grow = 0.3 + 0.7 * s;
    put(over, spot, 44.0 * u * grow as f32, won, gm.b.king_look, clamp(2.0 * k, 0.0, 1.0) as f32, true);
    // Sparks over the board: each starts at its own time and place, drifts 160 dp up
    // easing out, fading in over the first fifth and out over the rest.
    for i in SPARKS {
        let local = t - SPARK_CYCLE * hash(i, 3);
        guard local >= 0.0 && local < SPARK_CYCLE * SPARK_CYCLES else { continue; }
        let f = local / SPARK_CYCLE - floor(local / SPARK_CYCLE);
        let rise = 160.0 * u * (1.0 - (1.0 - f) * (1.0 - f));
        let a = if f < 0.2 { f / 0.2 } else { 1.0 - (f - 0.2) / 0.8 };
        let at = float2 { area.x + area.z * (0.1 + 0.8 * hash(i, 1)),
                          area.y + area.z * (0.4 + 0.5 * hash(i, 2)) - rise as f32 };
        gui::spark(g, at, 10.0 * u, a as f32);
    }
    return ask;
}
