// The game screen, with no graphics: the board, the panels beside it, the clocks, and
// the celebration on a win (docs/architecture/rendering.md, "Game screen", "Clocks").
// Each frame it counts the time on the running clock, advances the board, declares the
// panels, does what their tiles ask, and gives the pointer to the board only when a
// press didn't land on the UI, so a press that starts on a panel never moves a piece and
// one that starts on the board never presses a tile. The app draws what it leaves: the
// board's draw lists, the UI's quads, and a few pieces over the UI. Tests run it
// headless.
//
// Against the computer the game knows which side it plays and its level, and
// computer_to_move() says when it is its turn; until the computer player is wired in
// (task 006) that side waits for a move made by hand.
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

let POP = 0.6;              // seconds the winner's piece takes to pop in
let SPARKS = 14;
let SPARK_CYCLE = 2.4;      // seconds a spark takes to drift up and fade
let SPARK_CYCLES = 2;       // each spark drifts this many times, then the screen is still
let STEP = 2.0;             // seconds: the longest gap between two frames the clock counts

// What the screen asks the shell for.
let STAY = 0;
let HOME = 1;
let SETTINGS = 2;

// The computer's levels.
let EASY = 0;
let MEDIUM = 1;
let HARD = 2;

struct Game {
    b:        board::Board,
    clock:    clock::Clock                = clock::Clock {},
    computer: i64                         = -1,     // the side the computer plays, or -1 for a friend
    level:    i64                         = MEDIUM, // the computer's
    turn:     u8                          = 0,      // the side to move as last seen, to tell a move was made
    seen:     f64                         = -1.0,   // when the clock last counted, or -1 to count nothing next
    shown:    i64                         = -1,     // the running clock's whole seconds as last drawn
    won_at:   f64                         = -1.0,   // when the celebration began, or -1
    overlay:  board::Piece[..panel::OVER] = [],      // filled each frame, drawn over the UI
}

fn new(variant: u8) -> Game {
    var gm = Game { b: board::new(variant), .. };
    gm.turn = gm.b.pos.side;
    return gm;
}

// Starts a new game of `variant` with a clock of `kind` (clock::NONE..), against the
// computer playing `computer` at `level`, or against a friend for -1.
fn start(gm: Game&, variant: u8, kind: i64, computer: i64, level: i64) {
    board::reset(gm.b, variant);
    gm.clock = clock::new(kind);
    gm.computer = computer;
    gm.level = level;
    gm.turn = gm.b.pos.side;
    gm.seen = -1.0;
    gm.won_at = -1.0;
}

// Starts the game over from where it began, the clocks full again.
fn restart(gm: Game&) {
    board::restart(gm.b);
    gm.clock = clock::new(gm.clock.kind);
    gm.turn = gm.b.pos.side;
    gm.won_at = -1.0;
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
// focus, or the game screen was left.
fn pause(gm: Game&) { gm.seen = -1.0; }

// One frame, after gui::begin. Returns what the shell should do and whether anything on
// screen changed.
fn frame(gm: Game&, g: gui::Gui&, l: board::Layout, now: f64) -> i64, bool {
    let b .= gm.b;
    let input = g.input;
    var changed = board::update(b, now) || input.pressed || input.released;
    var go = STAY;
    gm.overlay.clear();
    if gm.seen >= 0.0 && clock::tick(gm.clock, min(now - gm.seen, STEP)) { changed = true; }
    gm.seen = now;

    // The side to move, or the winner once there is one.
    var won = winner(gm);
    let side = if won >= 0 { won } else { b.pos.side as i64 };
    let pick = panel::game(g, l, gm.clock, side, won >= 0, gm.overlay);
    var undone = false;
    match pick {
        panel::UNDO => { if gm.clock.flag < 0 { undone = board::undo(b); } },
        panel::RESTART => { restart(gm); },
        panel::HOME => { go = HOME; },
        panel::SETTINGS => { go = SETTINGS; },
        _ => {},
    }
    if pick != panel::NOTHING { changed = true; }

    won = winner(gm);
    if won < 0 {
        gm.won_at = -1.0;
    } else if gm.won_at < 0.0 {
        gm.won_at = now;
        changed = true;
    }
    if gm.won_at >= 0.0 {
        let ask = celebrate(gm, g, l, won, now);
        if ask == panel::RESTART {
            restart(gm);
            changed = true;
        }
        if ask == panel::HOME { go = HOME; }
    } else if !g.took {
        if input.pressed { board::press(b, l, input.at, now); }
        if input.down && board::drag(b, l, input.at) { changed = true; }
        if input.released { board::release(b, l, input.at, now); }
    }
    // A move made or taken back, whichever way: the clocks follow it, and stop once the
    // side to move has none.
    if b.pos.side != gm.turn {
        if undone { clock::undone(gm.clock, b.pos.side, b.history.len == 0); } else { clock::moved(gm.clock, gm.turn); }
        gm.turn = b.pos.side;
    }
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
    return board::animating(gm.b, now) || gui::animating(g) || celebrating;
}

// A piece of `side` over the UI at c with radius r, at opacity a, crowned or not, with
// a glow ring right round it or not.
fn put(gm: Game&, c: float2, r: f32, side: i64, king: bool, a: f32, ring: bool) {
    panel::piece(gm.overlay, c, r, side, king, a, ring);
}

fn hash(i: i64, k: i64) -> f32 {
    let x = sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return (x - floor(x)) as f32;
}

// The celebration (prototypes/solved.html): the board dimmed, a glass card over it with
// the winner's piece popping in, crowned, then restart or back; a few sparks drift up
// and fade.
// Returns panel::RESTART, panel::HOME, or panel::NOTHING.
fn celebrate(gm: Game&, g: gui::Gui&, l: board::Layout, won: i64, now: f64) -> i64 {
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
    put(gm, float2 { spot.x + 0.5 * spot.z, spot.y + 0.5 * spot.w }, 44.0 * u * grow as f32, won, true, clamp(2.0 * k, 0.0, 1.0) as f32, true);
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
