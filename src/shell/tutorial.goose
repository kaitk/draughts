// How to play (task 026; prototypes/tutorial.html; rendering.md, "How to play"): the
// rules one at a time, each a step played on the board in the puzzle's layout, with the
// moves shown (board::MOVES, the only place they show by default, docs/product.md). The
// left panel is the puzzle's (back, settings, start over, which plays the step again);
// the right one shows the steps as dots, the rule's name, its line, and next, dim until
// the step's move is played, then lit with what the move showed in the line's place.
// Where nothing must be taken the piece to move glows, as a puzzle's hint does; where
// something must, the board's pulse says which piece. The first step is a move, the other
// side's answer, and a move again: the game's turns. The last step's next is done, which
// opens the end's card over the dimmed screen: the puzzles' Learn theme, a new game, or
// home, the draughts just learned kept.
//
// The steps follow the draughts (rules.md): International and Brazilian take the most and
// crown a man only where its capture ends, nine steps; Russian may take any capture and
// crowns on the way, ten. Each step's position is a FEN on the board's lower left, so one
// serves both sizes but the crowning step's, a row from the far side.
namespace tutorial;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../../strings";

// The steps, as strings::HOW_STEP names their keys (three a step).
let MOVE = 0;
let JUMP = 1;
let MUST = 2;
let CHAIN = 3;
let MOST = 4;               // International and Brazilian: take with the piece that takes more
let ANY = 5;                // Russian: either capture
let KING = 6;
let FLY = 7;
let AFAR = 8;
let WAY = 9;                // Russian: crowned in the middle of a capture, on as a king
let WIN = 10;
let MAX_STEPS = 10;
// Each step's position, white to move, by step; KING's is KING_8 or KING_10.
let FENS = ["W:Wc3:Bf8,h8", "W:Wd4:Be5,b8", "W:Wc3,g3:Bd4,h8", "W:Wa3:Bb4,d6,f6,b8", "W:Wb2,f2:Bc3,g3,g5",
            "W:Wb2,f2:Bc3,g3,g5", "", "W:WKd4:Ba7", "W:WKa1:Bd4", "W:Wb6:Bc7,f6", "W:We3,c1:Bf4"];
let KING_8 = "W:Wc7:Bg5";
let KING_10 = "W:Wc9:Bg5";
// The first step's answer, whatever the child played: f8-e7, nothing taken either way.
let REPLY_FROM = "f8";
let REPLY_TO = "e7";
let MOVES_IN_FIRST = 2;     // the child's moves in the first step, the answer between them

// Where the step is.
let PLAYING = 0;            // the child to move
let REPLY = 1;              // the child's move shows, then the other side's answer comes
let PLAYED = 2;             // the step's move is played: next is lit
let END = 3;                // the end's card

let REPLY_PAUSE = 0.6;      // seconds from the child's move landing to the answer

// What the screen asks the shell for.
let STAY = gui::ASK_NOTHING;
let BACK = gui::ASK_BACK;   // where it was opened from
let SETTINGS = gui::ASK_SETTINGS;
let PUZZLES = 1;            // the end's: the Learn theme's first open puzzle
let NEW_GAME = 2;           // home's setup, the draughts learned chosen
let HOME = 3;

// The ids: next is the panel's (panel::EYE_ID, as a puzzle's); the end's card's own.
let CARD = gui::TUTORIAL_IDS;
let CARD_PUZZLES = gui::TUTORIAL_IDS + 1;
let CARD_NEW_GAME = gui::TUTORIAL_IDS + 2;
let CARD_HOME = gui::TUTORIAL_IDS + 3;
let CARD_OUTSIDE = gui::TUTORIAL_IDS + 4;

// What a frame tells the shell: where to go, and the steps played so far when one was
// played this frame (else -1), for the player's file.
struct Event {
    go:      i64 = STAY,
    learned: i64 = -1,
}

struct Lesson {
    b:       board::Board,
    variant: u8       = rules::INTERNATIONAL,
    step:    i64      = 0,    // in steps(variant)
    state:   i64      = PLAYING,
    played:  i64      = 0,     // the child's moves in this step
    glowed:  bool     = false, // the piece to move has glowed for this turn
    at:      f64      = 0.0,   // when the child's move lands (REPLY)
    grab:    float2   = float2 { 0.0, 0.0 }, // on the 3D board, a held piece against the finger (board::touch)
    cam:     rig::Rig = rig::Rig {},          // and the camera its buttons move
}

fn new() -> Lesson {
    var ls = Lesson { b: board::new(rules::INTERNATIONAL), .. };
    ls.b.hints = board::MOVES;
    ls.b.by_hand = true;
    return ls;
}

// The steps of `variant`'s tutorial, in order, into out.
fn steps(variant: u8, out: i64[..MAX_STEPS]&) {
    out.clear();
    let russian = variant == rules::RUSSIAN;
    for s in [MOVE, JUMP, MUST, CHAIN] { out.push(s); }
    out.push(if russian { ANY } else { MOST });
    for s in [KING, FLY, AFAR] { out.push(s); }
    if russian { out.push(WAY); }
    out.push(WIN);
}

// How many steps `variant`'s tutorial has.
fn count(variant: u8) -> i64 {
    var all: i64[..MAX_STEPS] = [];
    steps(variant, all);
    return all.len;
}

// The step showing, as STEPS name it.
fn current(ls: Lesson&) -> i64 {
    var all: i64[..MAX_STEPS] = [];
    steps(ls.variant, all);
    return all[clamp(ls.step, 0, all.len - 1)];
}

// A step's position in `variant`.
fn start_of(s: i64, variant: u8) -> rules::Position {
    let fen = if s != KING { FENS[s] } else if rules::VARIANTS[variant].size == 10 { KING_10 } else { KING_8 };
    let p, ok = rules::parse_fen(fen, variant);
    assert(ok);
    return p;
}

// Opens `variant`'s tutorial at step `step` (0 the first), the camera at rest.
fn open(ls: Lesson&, variant: u8, step: i64 = 0) {
    ls.variant = variant;
    ls.step = clamp(step, 0, count(variant) - 1);
    rig::reset(ls.cam);
    restart(ls);
}

// Plays the step again from its position.
fn restart(ls: Lesson&) {
    ls.b.variant = ls.variant;
    board::set(ls.b, start_of(current(ls), ls.variant));
    ls.state = PLAYING;
    ls.played = 0;
    ls.glowed = false;
}

// Whether this is the tutorial's last step.
fn last(ls: Lesson&) -> bool { ls.step == count(ls.variant) - 1 }

// The first step's answer in the board's moves, or -1.
fn reply(ls: Lesson&) -> i64 {
    let v .= rules::VARIANTS[ls.variant];
    let from, a = rules::parse_square(v, REPLY_FROM);
    let to, b = rules::parse_square(v, REPLY_TO);
    guard a && b else { return -1; }
    for m, i in ls.b.moves { if m.from == from && m.to == to { return i; } }
    return -1;
}

// Whether the child can move.
fn ready(ls: Lesson&) -> bool { ls.state == PLAYING && !ls.b.moving && ls.b.pos.side == rules::WHITE }

// A tap at p by the app's development flags, as a press and release.
fn tap(ls: Lesson&, l: board::Layout, p: float2, now: f64) {
    let history = ls.b.history.len;
    board::press(ls.b, l, p, now);
    board::release(ls.b, l, p, now);
    judge(ls, history);
}

// After the pointer has gone to the board: a move made counts. In the first step the
// first move waits for the answer; any other move plays the step. Returns whether the
// step was played.
fn judge(ls: Lesson&, history: i64) -> bool {
    let b .= ls.b;
    guard b.history.len > history else { return false; }
    ls.played++;
    ls.glowed = false;
    if current(ls) == MOVE && ls.played < MOVES_IN_FIRST {
        ls.state = REPLY;
        ls.at = b.since + board::duration(b.move);
        return false;
    }
    ls.state = PLAYED;
    return true;
}

// One frame, after gui::begin: the step on the board in l, the panels, and over all of
// it the end's card once it shows (`screen` the whole window it dims, `area` the safe
// area it centers in). Returns what the shell should do and know, and whether anything
// on screen changed.
fn frame(ls: Lesson&, g: gui::Gui&, l: panel::Layout, area: float4, screen: float4, now: f64,
         over: board::Overlay&) -> Event, bool {
    let b .= ls.b;
    let input = g.input;
    var changed = board::update(b, now) || input.pressed || input.released;
    over.clear();
    var ev = Event {};
    // The other side's answer in the first step, once the child's move has landed.
    if ls.state == REPLY && !b.moving && now >= ls.at + REPLY_PAUSE {
        let k = reply(ls);
        if k >= 0 { board::start_move(b, k, now); }
        ls.state = PLAYING;
        changed = true;
    }
    // Where nothing must be taken, the piece to move glows (every move it has is the
    // piece's: the steps give the child one piece to move); where something must, the
    // pieces that must take pulse, as after a wrong tap (board::mistake), so the line's
    // "pulses red" shows from the start.
    if ready(ls) && !ls.glowed && b.moves.len > 0 {
        if board::must_capture(b) { b.pulse_end = now + board::PULSE; }
        else { board::glow_on(b, b.moves[0].from, now); }
        ls.glowed = true;
        changed = true;
    }
    let ending = ls.state == END;
    if ending { gui::listen(g, false); }
    let ask = panel_frame(ls, g, l, now);
    if ask != STAY { changed = true; }
    if ask == BACK || ask == SETTINGS { ev.go = ask; }
    if ask == gui::ASK_RESTART {
        restart(ls);
        rig::settle(ls.cam, now);
    }
    if ask == NEXT && ls.state == PLAYED {
        if last(ls) { ls.state = END; }
        else {
            ls.step++;
            restart(ls);
        }
    }
    let held, moved = board::showcase(ls.cam, g, input, l.three, l.pitch, now);
    if moved { changed = true; }
    let mine = !held && !g.took && ready(ls);
    let history = b.history.len;
    if mine && board::touch(b, l.board, l.three, l.view, input, ls.grab, now) { changed = true; }
    if panel::board_keys(g, l, b, mine, now) { changed = true; }
    if mine && judge(ls, history) {
        ev.learned = ls.step + 1;
        changed = true;
    }
    if ending {
        gui::listen(g, true);
        let go = end_card(g, area, screen, over);
        if go != STAY {
            ev.go = go;
            changed = true;
        }
    }
    return ev, changed;
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(ls: Lesson&, g: gui::Gui&, now: f64) -> bool {
    return board::animating(ls.b, now) || gui::animating(g) || ls.state == REPLY || rig::moving(ls.cam, now);
}

let NEXT = 4;               // the panel's next was tapped
let CAMERA = 5;             // a camera button was

// The steps as dots, `most` dp across and `most_gap` apart from r's left, smaller where
// they wouldn't fit r's width: those played lit at 60%, this one lit.
fn dots(ls: Lesson&, g: gui::Gui&, r: float4, most: f32, most_gap: f32) {
    let u = g.scale;
    let n = count(ls.variant);
    let k = min(1.0, (r.z / u + most_gap) / (n * (most + most_gap)));
    let d = most * k;
    let gap = most_gap * k;
    for i in n {
        let c = float4 { r.x + i * (d + gap) * u, r.y + 0.5 * (r.w - d * u), d * u, d * u };
        if i < ls.step { gui::glow_fill(g, c, 0.6, 0.5 * d * u); }
        else if i == ls.step { gui::glow_fill(g, c, 1.0, 0.5 * d * u); }
        else { gui::fill(g, c, float4 { 1.0, 1.0, 1.0, 0.22 }, 0.5 * d * u); }
    }
}

// The line under the rule's name: what to do, or in the first step what comes, or once
// played what the move showed, after a check in the glow color.
fn line_key(ls: Lesson&) -> i64 {
    let s = current(ls);
    let base = strings::HOW_STEP + 3 * s;
    if ls.state == PLAYED || ls.state == END { return base + 2; }
    if s == MOVE && ls.state == REPLY { return strings::HOW_MOVE_REPLY; }
    if s == MOVE && ls.played > 0 { return strings::HOW_MOVE_AGAIN; }
    return base + 1;
}

// The rule's name and its line in r from the top, the line in the body face, or the
// small one where that runs past r's foot.
fn words(ls: Lesson&, g: gui::Gui&, r: float4) {
    let u = g.scale;
    var c = r;
    let name = strings::get(strings::HOW_STEP + 3 * current(ls));
    let nf = gui::fitting(g, gui::LABEL, name, c.z);
    let nh = g.faces[nf].ascent - g.faces[nf].descent;
    gui::text(g, nf, gui::cut_top(c, nh), name, 1.0, 0.0, gui::LEFT);
    gui::cut_top(c, 10.0 * u);
    let said = ls.state == PLAYED || ls.state == END;
    if said {
        let s = 24.0 * u;
        var row = gui::cut_top(c, s);
        gui::glyph_icon(g, gui::cut_left(row, s), gui::CHECK, gui::ON, 0.0, 1.0);
        gui::cut_top(c, 6.0 * u);
    }
    let text = strings::get(line_key(ls));
    let face = if gui::wrapped(g, gui::BODY, c, text, 1.0, gui::LEFT, 1.25, false) <= c.w { gui::BODY } else { gui::SMALL };
    gui::wrapped(g, face, c, text, if said { 1.0 } else { 0.72 }, gui::LEFT);
}

// Declares the panels: the left one as a puzzle's; the right one with the dots, the
// name and line, and next, a tall tile at the foot in landscape, at the right in
// portrait. Round the 3D board, the camera buttons. Returns BACK, SETTINGS,
// gui::ASK_RESTART, NEXT, CAMERA, or STAY.
fn panel_frame(ls: Lesson&, g: gui::Gui&, l: panel::Layout, now: f64) -> i64 {
    let u = g.scale;
    var ask = STAY;
    let out = panel::leave(g, l);
    gui::group(g, panel::GROUP_PLAY);
    gui::panel(g, l.right);
    if panel::camera(g, l, ls.cam, now) { ask = CAMERA; }
    if out == panel::BACK { ask = BACK; }
    if out == panel::SETTINGS { ask = SETTINGS; }
    if out == panel::RESTART { ask = gui::ASK_RESTART; }
    var right = panel::play_area(g, l);
    let played = ls.state == PLAYED || ls.state == END;
    let style = if played { gui::CHOSEN } else { gui::PLAIN };
    let word = strings::get(if last(ls) { strings::HOW_FINISH } else { strings::PUZZLE_NEXT });
    let icon = if last(ls) { gui::CHECK } else { gui::NEXT };
    if panel::columns(l) {
        let next = gui::cut_bottom(right, if l.three { panel::stack_h() * u } else { panel::tall(l, u) });
        gui::cut_bottom(right, gui::PAD * u);
        gui::cut_top(right, 8.0 * u);
        dots(ls, g, gui::cut_top(right, 12.0 * u), 12.0, 8.0);
        gui::cut_top(right, 16.0 * u);
        words(ls, g, right);
        let h .= g.faces[gui::HEADING];
        let arrow = min(48.0, (next.w - h.ascent + h.descent) / u - 16.0);
        if gui::labelled(g, panel::EYE_ID, next, icon, arrow, word, gui::HEADING, gui::STACKED, style, played) { ask = NEXT; }
        return ask;
    }
    // Portrait: the dots, the name, and the line at the left, next at the right.
    let next = gui::cut_right(right, min(200.0 * u, 0.36 * right.z));
    gui::cut_right(right, gui::PAD * u);
    dots(ls, g, gui::cut_top(right, 12.0 * u), 10.0, 6.0);
    gui::cut_top(right, 10.0 * u);
    words(ls, g, right);
    if gui::labelled(g, panel::EYE_ID, next, icon, 40.0, word, gui::HEADING, gui::STACKED, style, played) { ask = NEXT; }
    return ask;
}

// The end's card (prototypes/tutorial.html, done): over the dimmed screen, a glass card
// with a crowned light piece, "You know the moves!", and the two ways on, the puzzles (lit,
// the keys' first) and a new game, side by side where they fit, else one over the other;
// home under them. Returns PUZZLES, NEW_GAME, HOME, or STAY.
let CARD_PAD = 28.0;
let ANSWER_W = 240.0;       // dp a way on's tile is wide at most
let ANSWER_H = 150.0;       // and tall, side by side; a tap and a half one over the other
let ANSWER_GAP = 16.0;
fn end_card(g: gui::Gui&, area: float4, screen: float4, over: board::Overlay&) -> i64 {
    let u = g.scale;
    gui::fill(g, screen, float4 { 0.0, 0.0, 0.0, 0.42 }, 0.0);
    gui::hold(g, CARD_OUTSIDE, screen, false);
    let title = strings::get(strings::HOW_DONE);
    let room = area.z - 2.0 * gui::PAD * u;
    let pair = 2.0 * ANSWER_W * u + ANSWER_GAP * u;
    let beside = pair + 2.0 * CARD_PAD * u <= room;
    let tile_w = if beside { ANSWER_W * u } else { min(room - 2.0 * CARD_PAD * u, 2.0 * ANSWER_W * u) };
    let tile_h = (if beside { ANSWER_H } else { 1.5 * gui::tap() }) * u;
    let tiles_w = if beside { pair } else { tile_w };
    let tiles_h = if beside { tile_h } else { 2.0 * tile_h + ANSWER_GAP * u };
    let line = g.faces[gui::LABEL].ascent - g.faces[gui::LABEL].descent;
    let king = 72.0 * u;
    let width = min(max(tiles_w, gui::text_width(g, gui::LABEL, title)) + 2.0 * CARD_PAD * u, room);
    let height = (CARD_PAD + 16.0 + 20.0 + 20.0 + 12.0 + CARD_PAD) * u + king + line + tiles_h + gui::tap() * u;
    let r = gui::center(area, width, min(height, area.w));
    gui::glass(g, r, 32.0);
    gui::hold(g, CARD, r, false);
    var c = gui::inset(r, CARD_PAD * u);
    gui::cut_top(c, 16.0 * u);
    game::put(over, gui::center(gui::cut_top(c, king), king, king), 0.5 * king, rules::WHITE, board::CROWN, 1.0, false);
    gui::cut_top(c, 20.0 * u);
    gui::text(g, gui::fitting(g, gui::LABEL, title, c.z), gui::cut_top(c, line), title, 1.0, 0.0, gui::CENTER);
    gui::cut_top(c, 20.0 * u);
    var tiles = gui::center(gui::cut_top(c, tiles_h), tiles_w, tiles_h);
    let a = if beside { gui::cut_left(tiles, tile_w) } else { gui::cut_top(tiles, tile_h) };
    let b = if beside { gui::cut_right(tiles, tile_w) } else { gui::cut_bottom(tiles, tile_h) };
    let arrange = if beside { gui::STACKED } else { gui::MIDDLE };
    let size: f32 = if beside { 52.0 } else { 36.0 };
    var go = STAY;
    if gui::labelled(g, CARD_PUZZLES, a, gui::PUZZLE, size, strings::get(strings::HOME_PUZZLES), gui::LABEL, arrange,
                     gui::CHOSEN) { go = PUZZLES; }
    if gui::labelled(g, CARD_NEW_GAME, b, gui::NEW_GAME, size, strings::get(strings::HOME_NEW_GAME), gui::LABEL, arrange) {
        go = NEW_GAME;
    }
    gui::cut_top(c, 12.0 * u);
    let home_r = gui::center(gui::cut_top(c, gui::tap() * u), min(c.z, 240.0 * u), gui::tap() * u);
    if gui::labelled(g, CARD_HOME, home_r, gui::BACK, 30.0, strings::get(strings::HOW_HOME), gui::BODY, gui::MIDDLE,
                     gui::QUIET) { go = HOME; }
    return go;
}
