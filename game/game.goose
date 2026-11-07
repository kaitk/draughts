// The game screen, with no graphics: the board, the panel beside it, and the
// celebration on a win (docs/architecture/rendering.md, "Game screen"). Each frame it
// advances the board, declares the panel, does what its buttons ask, and gives the
// pointer to the board only when a press didn't land on the UI, so a press that starts
// on the panel never moves a piece and one that starts on the board never presses a
// button. The app draws what it leaves: the board's draw lists, the UI's quads, and a
// few pieces over the UI. Tests run it headless.
namespace game;
import std;
import math;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import .panel;

let MAX_OVERLAY = 2;        // pieces over the UI: the side to move and the winner
let POP = 0.6;              // seconds the winner's piece takes to pop in
let SPARKS = 14;
let SPARK_CYCLE = 2.4;      // seconds a spark takes to drift up and fade
let SPARK_CYCLES = 2;       // each spark drifts this many times, then the screen is still

// What the screen asks the shell for.
let STAY = 0;
let HOME = 1;

struct Game {
    b:       board::Board,
    won_at:  f64                         = -1.0,  // when the celebration began, or -1
    overlay: board::Piece[..MAX_OVERLAY] = [],    // filled each frame, drawn over the UI
}

fn new(variant: u8) -> Game { Game { b: board::new(variant), .. } }

// One frame, after gui::begin. Returns what the shell should do and whether anything on
// screen changed.
fn frame(gm: Game&, g: gui::Gui&, l: board::Layout, now: f64) -> i64, bool {
    let b .= gm.b;
    let input = g.input;
    var changed = board::update(b, now) || input.pressed || input.released;
    var go = STAY;
    gm.overlay.clear();

    let pick, turn = panel::game(g, l, b.hints == board::MOVES);
    match pick {
        panel::UNDO => { board::undo(b); },
        panel::HINT => { board::hint(b); },
        panel::RESTART => { board::restart(b); },
        panel::BACK => { go = HOME; },
        panel::HINTS => { b.hints = if b.hints == board::MOVES { board::MISTAKES } else { board::MOVES }; },
        _ => {},
    }
    if pick != panel::NOTHING { changed = true; }

    let won = board::winner(b);
    if won < 0 {
        gm.won_at = -1.0;
    } else if gm.won_at < 0.0 {
        gm.won_at = now;
        changed = true;
    }
    // The side to move, or the winner once there is one.
    let side = if won >= 0 { won } else { b.pos.side as i64 };
    put(gm, float2 { turn.x, turn.y }, turn.z, side, false, 1.0);
    if gm.won_at >= 0.0 {
        let ask = celebrate(gm, g, l, won, now);
        if ask == panel::RESTART {
            board::restart(b);
            gm.won_at = -1.0;
            changed = true;
        }
        if ask == panel::BACK { go = HOME; }
    } else if !g.took {
        if input.pressed { board::press(b, l, input.at, now); }
        if input.down && board::drag(b, l, input.at) { changed = true; }
        if input.released { board::release(b, l, input.at, now); }
    }
    return go, changed;
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(gm: Game&, g: gui::Gui&, now: f64) -> bool {
    let celebrating = gm.won_at >= 0.0 && now < gm.won_at + SPARK_CYCLE * (SPARK_CYCLES + 1);
    return board::animating(gm.b, now) || gui::animating(g) || celebrating;
}

// A piece of `side` over the UI with a glow ring right round it, at c with radius r,
// at opacity a, crowned or not.
fn put(gm: Game&, c: float2, r: f32, side: i64, king: bool, a: f32) {
    guard gm.overlay.len < MAX_OVERLAY else { return; }
    let k = if king { 1.0 } else { 0.0 };
    gm.overlay.push(board::Piece { at: float4 { c.x, c.y, r, 0.0 }, look: float4 { side, k, 0.0, a },
                                   ring: float4 { 0.0, 1.0, 0.0, 0.0 } });
}

fn hash(i: i64, k: i64) -> f32 {
    let x = sin(i * 12.9898 + k * 78.233) * 43758.5453;
    return (x - floor(x)) as f32;
}

// The celebration (prototypes/solved.html): the board dimmed, a glass card over it with
// the winner's piece popping in, crowned, then restart or back; a few sparks drift up
// and fade.
// Returns panel::RESTART, panel::BACK, or panel::NOTHING.
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
    if gui::button(g, 200, gui::cell(row, 2, 1, 112.0 * u, 88.0 * u, 20.0 * u, 0), gui::BACK) { ask = panel::BACK; }
    if gui::tile(g, 201, gui::cell(row, 2, 1, 112.0 * u, 88.0 * u, 20.0 * u, 1), gui::RESTART, gui::PRIMARY, 22.0) {
        ask = panel::RESTART;
    }
    // The winner pops in: grows from 0.3 past its size and settles, as CSS
    // cubic-bezier(.2, 1.6, .4, 1) does.
    let k = clamp(t / POP, 0.0, 1.0);
    let s = 1.0 + 2.70158 * pow(k - 1.0, 3.0) + 1.70158 * pow(k - 1.0, 2.0);
    let grow = 0.3 + 0.7 * s;
    put(gm, float2 { spot.x + 0.5 * spot.z, spot.y + 0.5 * spot.w }, 44.0 * u * grow as f32, won, true, clamp(2.0 * k, 0.0, 1.0) as f32);
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
