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
import strings from "../../strings";
import .panel;
import .clock;
import .pace;

// A win (prototypes/win.html, take a), in seconds since it: the winning piece lifts
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
    skill:    i64          = 40,                    // the computer's for the whole game (ai::level_skill)
    number:   i64          = 0,                     // the game's number, for the computer's seeds
    turn:     u8           = 0,                     // the side to move as last seen, to tell a move was made
    seen:     f64          = -1.0,                  // when the clock last counted, or -1 to count nothing next
    shown:    i64          = -1,                    // the running clock's whole seconds as last drawn
    won_at:   f64          = -1.0,                  // when the celebration began, or -1
    won_on:   i64          = -1,                    // the winning piece's square, or -1 for none to lift
    still:    f64          = STILL,                 // the celebration's moment from which it is still
    stilled:  bool         = false,                 // whether its still frame has been drawn
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
    gm.restarted = false;
    rig::reset(gm.cam);
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
    gm.counted = false;
    gm.asking = 0;
    rig::settle(gm.cam, now);
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
    let pick = panel::game(g, l, gm.clock, side, won >= 0, gm.asking != 0, pulse(gm, now), over);
    var undone = false;
    match pick {
        // Partway through a capture, take back only takes the capture back to its start.
        panel::UNDO => { if !board::unwind(b) && gm.clock.flag < 0 { undone = take_back(gm); } },
        panel::RESTART => { restart(gm, now); },
        panel::BACK => { go = HOME; },
        panel::SETTINGS => { go = SETTINGS; },
        _ => {},
    }
    if pick != panel::NOTHING { changed = true; }
    if panel::camera(g, l, gm.cam, now) { changed = true; }

    if !frozen && think(gm, now) { changed = true; }
    won = winner(gm);
    if won < 0 {
        gm.won_at = -1.0;
    } else if gm.won_at < 0.0 {
        gm.won_at = now;
        aim(gm, won);
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
    if l.three && !frozen && gm.computer < 0 && winner(gm) < 0 && !b.moving && b.pressed < 0 {
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
    // The computer's pieces show no count of what they must take: the child can't move them.
    b.quiet = gm.computer >= 0 && b.pos.side == gm.computer;
    if b.moves.len == 0 { clock::stop(gm.clock); }
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
    return moved;
}

// Declares the screen as it stands, its pieces over the UI put in `over`, doing nothing:
// the shell's transition away from the game, with the pointer taken away and the clocks
// paused. A win's card is declared as it is, to fade with the panels.
fn still(gm: Game&, g: gui::Gui&, l: panel::Layout, now: f64, over: Overlay&) {
    over.clear();
    let won = winner(gm);
    let side = if won >= 0 { won } else { gm.b.pos.side as i64 };
    panel::game(g, l, gm.clock, side, won >= 0, gm.asking != 0, pulse(gm, now), over);
    panel::camera(g, l, gm.cam, now);
    if gm.won_at >= 0.0 { celebrate(gm, g, l, won, now, over); }
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(gm: Game&, g: gui::Gui&, now: f64) -> bool {
    let celebrating = gm.won_at >= 0.0 && moment(gm, now) < gm.still;
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
fn winning_spot(gm: Game&, pl: panel::Layout) -> float2, f32 {
    let l = pl.board;
    let at = board::center(l, rules::VARIANTS[gm.b.variant], gm.won_on);
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
