// The game screen, with no graphics: the board, the panels beside it, the clocks, and
// the end's cards (docs/architecture/rendering.md, "Game screen"). Against the computer
// it asks for a move (asking()) and plays the answer (answer()) once the time a person
// would take has passed.
namespace game;
import std;
import math;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import ai from "../ai";
import strings from "../../strings";
import .clock;
import .pace;
import .ending;
import .notes;
import .sheet;

let STEP = 2.0;             // seconds: the longest gap between two frames the clock counts
let PAUSE = [0.8, 0.6, 0.45];   // seconds from the computer's turn to its move without a clock, by level
let PULSE = 1.2;            // seconds: the computer's ring pulses once as it begins to think

// What the screen asks the shell for: nothing, home (its back), or settings.
let STAY = gui::ASK_NOTHING;
let HOME = gui::ASK_BACK;
let SETTINGS = gui::ASK_SETTINGS;

// What a frame tells the shell: where to go, and what happened to the game that it
// keeps a count of.
struct Event {
    go:                i64  = STAY,
    ended:             bool = false, // a game against the computer ended, the first time
    result:            i64  = 0,     // and how: 1 the child won, -1 lost, 0 drawn
    restarted:         bool = false, // started over: the shell gives it a skill and number
    lookout_toggled:   bool = false,  // the lookout's eye turned on or off
    ended_for_history: bool = false,    // any game ended, the first time, for the history
    winner:            i64  = -1, // its winner's side, or -1 for a draw
}

// The computer's levels.
let EASY = 0;
let MEDIUM = 1;
let HARD = 2;

struct Game {
    b:                   board::Board,
    clock:               clock::Clock = clock::Clock {},
    computer:            i64          = -1,         // the side the computer plays, or -1 for a friend
    level:               i64          = MEDIUM,     // the computer's
    skill:               i64          = 40,         // the computer's for the whole game (ai::level_skill)
    number:              i64          = 0,          // the game's number, for the computer's seeds
    turn:                u8           = 0,          // the side to move as last seen, to tell a move was made
    clock_counted_at:    f64          = -1.0,               // when the clock last counted, or -1 to count nothing next
    clock_seconds_drawn: i64          = -1,                    // the running clock's whole seconds as last drawn
    won_at:              f64          = -1.0,       // when the celebration began, or -1
    won_on:              i64          = -1,         // the winning piece's square, or -1 for none to lift
    win_still_from:      f64          = STILL,            // the celebration's moment from which it is still
    win_still_drawn:     bool         = false,             // whether its still frame has been drawn
    // When a draw's ending began, or -1.
    drawn_at:    f64  = -1.0,
    drawn_still: bool = false,
    // The computer's turn: the move asked for, and its answer.
    ai_request_count:    i64         = 0,                   // moves asked for so far, to number them
    ai_request_id:       i64         = 0,                // the one waited for, or 0
    asked_at:            f64         = 0.0,         // when the computer's turn began
    ai_answered:         bool        = false,          // whether its answer has come
    wait:                f64         = 0.0,         // seconds from its turn to its move, once answered
    reply:               rules::Move = rules::Move { .. },
    end_sent_for_rating: bool        = false,                  // the end was given to the shell (Event.ended)
    // On the 3D board, a held piece's place against the finger on its plane, and the
    // camera its buttons move.
    grab: float2   = float2 { 0.0, 0.0 },
    cam:  rig::Rig = rig::Rig {},
    // The lookout (docs/architecture/ai.md, "The lookout"): on or off, the skill whose
    // plain threats it leaves to the player, and what it last worked the threats out for.
    lookout_on:    bool  = false,
    lookout_skill: i64   = 0,
    lookout_cache: Watch = Watch {},
    // Its traps, searched on the worker: the ask's id, or 0, and the position it is for.
    trap_request_id: i64             = 0,
    trap_pos:        rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    // The hint: hints left, each side's; how far the one shown has gone (1 the piece lit,
    // 2 its square too); the ask, the position it is for (board::Board.positions_shown),
    // and the move once answered, lit on the next frame (`hint_new`).
    hints:                i64[2]      = [panel::HINTS, panel::HINTS],
    hint_stage:           i64         = 0,
    hint_request_id:      i64         = 0,
    hint_positions_shown: i64         = -1,
    hint_move:            rules::Move = rules::Move { .. },
    hint_new:             bool        = false,
    // What each side has taken, as last counted at `taken_pos` after `taken_len` moves.
    taken:     panel::Taken    = panel::Taken {},
    taken_len: i64             = -1,
    taken_pos: rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    // The moves as played and their marks (notes.goose): the plies the history dropped,
    // what they were last brought in line with, and the judge's ask id, or 0, and note.
    notes:                Notes           = [],
    notes_from:           i64             = 0,
    notes_len:            i64             = -1,
    notes_pos:            rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    scratch:              rules::Moves    = [],
    judge_moves:          bool            = true,
    moves_shown:          i64             = 2, // the moves panel: 0 hidden, 1 the moves, 2 with marks (settings::MOVES_*)
    turns:                bool            = false, // a friend's game turns the board to the side to move (settings' `turns`)
    moves_seen:           i64             = -1, // the moves the panel's list was last scrolled to the foot for
    judge_request_id:     i64             = 0,
    judge_ply:            i64             = 0,
    end_sent_for_history: bool            = false, // the end was given to the shell (Event.ended_for_history)
    // The moves' sheet (sheet.goose): open or not; the note whose mark's tip shows, or -1,
    // and whether under the mouse; the marked move a touch went down on, or -1, and whether
    // the tip then took that press; the marked moves as the panel last showed them.
    sheet:     bool                   = false,
    tip:       i64                    = -1,
    tip_hover: bool                   = false,
    tip_press: i64                    = -1,
    tip_took:  bool                   = false,
    refocus:   bool                   = false,  // the sheet closed by the keys: the line takes the focus back
    marks_at:  MarkAt[..MAX_MARKS_AT] = [],
    // A game played on from a past game's move: the plies before its start, which its
    // move numbers go on from, and that it counts for nothing.
    ply0:     i64  = 0,
    no_count: bool = false,
    // The clocks' warnings heard so far (sound_event::chime), once a side a game.
    chimes: sound_event::Chimes = sound_event::Chimes {},
}

// The pieces of each color taken so far: the start's pieces less those on the board. A
// piece taken while a king counts as a king, found from the undo history, so kings taken
// more than rules::MAX_HISTORY moves back count as men.
fn taken(b: board::Board&) -> panel::Taken {
    var t = panel::Taken {};
    let v .= rules::VARIANTS[b.variant];
    for c in 2 {
        let lost = max(popcount(v.start[c]) - popcount(b.pos.pieces[c]), 0);
        var kings: i64 = 0;
        for st, i in b.rec.history {
            let a = st.pos;
            guard a.side != c else { continue; }
            let next = if i + 1 < b.rec.history.len { b.rec.history[i + 1].pos } else { b.pos };
            kings += popcount(a.pieces[c] & a.kings & ~next.pieces[c]);
        }
        t.kings[c] = min(kings, lost);
        t.men[c] = lost - t.kings[c];
    }
    return t;
}

// Counts what each side has taken again when the board at rest shows another position
// than it was counted for. Returns whether the counts may have changed.
fn count_taken(gm: Game&) -> bool {
    let b .= gm.b;
    guard !b.moving else { return false; }
    let p = b.pos;
    let q = gm.taken_pos;
    guard gm.taken_len != b.rec.history.len || p.pieces[0] != q.pieces[0] || p.pieces[1] != q.pieces[1]
          || p.kings != q.kings || p.side != q.side || p.variant != q.variant else { return false; }
    gm.taken = taken(b);
    gm.taken_len = b.rec.history.len;
    gm.taken_pos = p;
    return true;
}

// What the lookout last worked its threats out for: whether it showed, the position,
// and the held piece and the square under it.
struct Watch {
    on:                   bool            = false,
    pos:                  rules::Position = rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: 0 },
    selected:             i64             = -1,
    target_under_pointer: i64             = -1,
    positions_shown:      i64             = -1, // board::Board.positions_shown: a position shown again clears the marks
}

fn new(variant: u8) -> Game {
    var gm = Game { b: board::new(variant), .. };
    gm.turn = gm.b.pos.side;
    return gm;
}

// Starts a new game of `variant` with a clock of `kind`, against the computer playing
// side `computer` at `level` and `skill`, or against a friend for -1. `number` varies the
// computer's moves from one game to the next.
fn start(gm: Game&, variant: u8, kind: i64, computer: i64, level: i64, skill: i64, number: i64) {
    board::reset(gm.b, variant);
    gm.clock = clock::new(kind);
    gm.chimes = sound_event::Chimes {};
    gm.computer = computer;
    gm.level = level;
    gm.skill = skill;
    gm.number = number;
    gm.turn = gm.b.pos.side;
    gm.clock_counted_at = -1.0;
    gm.won_at = -1.0;
    gm.drawn_at = -1.0;
    gm.end_sent_for_rating = false;
    gm.end_sent_for_history = false;
    gm.ai_request_id = 0;
    gm.judge_request_id = 0;
    gm.lookout_cache = Watch {};
    gm.ply0 = 0;
    gm.no_count = false;
    new_hints(gm);
    rig::reset(gm.cam);
    rig::across_table(gm.cam, computer < 0 && !gm.turns);
}

// The game just started begins at p instead, `ply` plies into a past game, and counts for
// nothing. Start over goes back to p.
fn start_from(gm: Game&, p: rules::Position, ply: i64) {
    board::set(gm.b, p);
    gm.turn = p.side;
    gm.ply0 = ply;
    gm.no_count = true;
}

fn new_hints(gm: Game&) {
    gm.hints = [panel::HINTS, panel::HINTS];
    gm.hint_stage = 0;
    gm.hint_request_id = 0;
    gm.hint_new = false;
}

// Starts the game over from where it began, the clocks full again, the 3D board's camera
// easing back from `now`. A new game for the shell (Event.restarted).
fn restart(gm: Game&, now: f64 = 0.0) {
    board::restart(gm.b);
    gm.clock = clock::new(gm.clock.kind);
    gm.chimes = sound_event::Chimes {};
    gm.turn = gm.b.pos.side;
    gm.won_at = -1.0;
    gm.drawn_at = -1.0;
    gm.end_sent_for_rating = false;
    gm.end_sent_for_history = false;
    gm.ai_request_id = 0;
    gm.judge_request_id = 0;
    new_hints(gm);
    rig::ease_to_rest(gm.cam, now);
}

// What the panels show of clock c: each side's time, gold under a minute and red at 20
// seconds or under, lit while it runs.
fn clocks(c: clock::Clock&) -> panel::Clocks {
    var cs = panel::Clocks { on: clock::on(c), running: c.running, .. };
    for side in 2 {
        cs.style[side] = if clock::low(c, side) { gui::CLOCK_LOW } else if clock::warn(c, side) { gui::CLOCK_WARN }
                         else if c.running == side { gui::CLOCK_RUN } else { gui::CLOCK_IDLE };
        clock::text(clock::whole_seconds(c, side), cs.text[side]);
    }
    return cs;
}

// The side that has won, or -1 while the game goes on: the other side has no move left
// (once the move has shown), or its time ran out.
fn winner(gm: Game&) -> i64 {
    if gm.clock.flag >= 0 { return 1 - gm.clock.flag; }
    return board::winner(gm.b);
}

// The game's past for draws at the board's position.
fn past(gm: Game&) -> rules::Past& { board::past(gm.b) }

// Why the game is drawn (rules::DRAW_*), or rules::NO_DRAW while it goes on, once the
// drawing move has shown, unless it won.
fn drawn(gm: Game&) -> i64 {
    guard winner(gm) < 0 && !gm.b.moving else { return rules::NO_DRAW; }
    return rules::draw_reason(past(gm).draw, gm.b.pos);
}

fn ended(gm: Game&) -> bool { winner(gm) >= 0 || drawn(gm) != rules::NO_DRAW }

fn computer_to_move(gm: Game&) -> bool {
    return gm.computer >= 0 && !gm.b.moving && gm.b.pos.side == gm.computer && !ended(gm);
}

// The app paused or the screen was left: the clock counts nothing until the frame after
// the next, and the computer's and the judge's asks are dropped, asked again later.
fn pause(gm: Game&) {
    gm.clock_counted_at = -1.0;
    gm.ai_request_id = 0;
    gm.judge_request_id = 0;
}

// What the game asks the computer player for, id 0 for nothing. A flat value, so it can
// go to a worker.
struct Ask {
    id:    i64,
    pos:   rules::Position,
    past:  rules::Past,     // the game before pos, for the draws (ai::start_after)
    skill: i64,
    seed:  u64,
    kind:  i64         = THINK,
    move:  rules::Move = rules::Move { .. },   // JUDGE: the move played from pos
}

// What an ask is for.
let THINK = 0;              // the computer's move
let HINT = 1;               // the hint's (ai::judged_best)
let TRAPS = 2;              // the lookout's traps (lookout::traps, no search)
let JUDGE = 3;              // a played move judged (notes.goose)

fn asking(gm: Game&) -> Ask {
    // Moves vary between games, yet the same game replays the same.
    let seed = (gm.number as u64) * 1000 + gm.b.rec.history.len as u64;
    return Ask { id: gm.ai_request_id, pos: gm.b.pos, past: past(gm), skill: gm.skill, seed: seed };
}

// The ask the worker should have, by its id, or 0 for none: the first open of the
// computer's move, the hint, the lookout's traps, and a move to judge, most waited on
// first. A slot behind another keeps its ask until those before it are done.
fn open_ask(gm: Game&) -> i64 {
    return if gm.ai_request_id != 0 { gm.ai_request_id } else if gm.hint_request_id != 0 { gm.hint_request_id } else if gm.trap_request_id != 0 { gm.trap_request_id }
           else { gm.judge_request_id };
}

// That ask in full. The hint is the judge's best move at full strength, so it never shows
// a move the judge marks down.
fn ask_for(gm: Game&) -> Ask {
    var a = asking(gm);
    guard gm.ai_request_id == 0 else { return a; }
    if gm.hint_request_id != 0 {
        a.id = gm.hint_request_id;
        a.kind = HINT;
    } else if gm.trap_request_id != 0 {
        a.id = gm.trap_request_id;
        a.pos = gm.trap_pos;
        a.kind = TRAPS;
    } else if gm.judge_request_id != 0 {
        return judge_ask(gm);
    }
    return a;
}

// The lookout's traps for the ask `id`, marked with the other threats, the held piece's
// on the square it was taken from. An ask no longer open is ignored. True when shown.
fn trapped(gm: Game&, id: i64, pieces: u64) -> bool {
    guard id != 0 && id == gm.trap_request_id else { return false; }
    gm.trap_request_id = 0;
    let w .= gm.lookout_cache;
    var p = pieces & gm.b.pos.pieces[gm.b.pos.side] | (if w.target_under_pointer >= 0 && pieces & rules::bit(w.target_under_pointer) != 0 { rules::bit(w.selected) } else { 0 });
    gm.b.danger |= p;
    return p != 0;
}

// Whether the hint can be asked for or shown: the player's turn, the board at rest with
// no capture due or partway through, the game going on.
fn can_hint(gm: Game&) -> bool {
    let b .= gm.b;
    return !b.moving && b.pos.side != gm.computer && !ended(gm) && !board::must_capture(b) && b.steps.len == 0;
}

// The hint's move for the ask `id`: spends one of the side's hints and lights the piece
// on the next frame. An ask no longer open is ignored.
fn hinted(gm: Game&, id: i64, m: rules::Move) {
    guard id != 0 && id == gm.hint_request_id else { return; }
    gm.hint_request_id = 0;
    let side = gm.b.pos.side;
    gm.hints[side] = max(gm.hints[side] - 1, 0);
    gm.hint_move = m;
    gm.hint_stage = 1;
    gm.hint_new = true;
}

// Whether an ask with no frames of its own is open, for the loop to wake for its answer.
fn awaiting(gm: Game&) -> bool { gm.hint_request_id != 0 || gm.trap_request_id != 0 }

// The hint's tile pressed: the first press asks for the move, which lights the piece;
// the second shows its square with a ghost of the piece.
fn press_hint(gm: Game&, now: f64) {
    guard can_hint(gm) else { return; }
    let b .= gm.b;
    if gm.hint_stage == 0 && gm.hint_request_id == 0 && gm.hints[b.pos.side] > 0 {
        gm.ai_request_count += 1;
        gm.hint_request_id = gm.ai_request_count;
        gm.hint_positions_shown = b.positions_shown;
    } else if gm.hint_stage == 1 {
        board::ghost_on(b, gm.hint_move.to, now);
        gm.hint_stage = 2;
    }
}

// The computer's move for the ask `id`, `close` of the moves about as good as it. It is
// played after the level's pause, or while its clock runs after pace::seconds. An ask no
// longer open is ignored.
fn answer(gm: Game&, id: i64, m: rules::Move, close: i64) {
    guard id != 0 && id == gm.ai_request_id else { return; }
    gm.reply = m;
    gm.ai_answered = true;
    let level = clamp(gm.level, EASY, HARD);
    gm.wait = PAUSE[level];
    guard gm.clock.running == gm.computer else { return; }
    gm.wait = pace::seconds(PAUSE[level], level, gm.clock.left[gm.computer], clock::INCREMENTS[gm.clock.kind],
                            gm.b.rec.history.len, gm.b.moves.len, board::must_capture(gm.b), pace::tense(gm.b.pos, m),
                            close);
}

// Takes back a move, also one still animating: against the computer, the child's last
// move and the reply to it, so it is the child's turn again.
fn take_back(gm: Game&) -> bool {
    let b .= gm.b;
    var done = false;
    if gm.computer < 0 || b.pos.side == gm.computer {
        done = board::undo(b);
    } else if b.rec.history.len >= 2 {
        board::undo(b);
        done = board::undo(b);
    }
    if done { gm.ai_request_id = 0; }
    return done;
}

// The computer's turn: ask for its move when the turn begins, and play the answer once
// it has come and the pause is over. True when its move began.
fn think(gm: Game&, now: f64) -> bool {
    guard computer_to_move(gm) else {
        gm.ai_request_id = 0;
        return false;
    }
    if gm.ai_request_id == 0 {
        gm.ai_request_count += 1;
        gm.ai_request_id = gm.ai_request_count;
        gm.asked_at = now;
        gm.ai_answered = false;
    }
    guard gm.ai_answered && now >= gm.asked_at + gm.wait else { return false; }
    let b .= gm.b;
    gm.ai_request_id = 0;
    for k in b.moves.len {
        let m .= b.moves[k];
        guard m.from == gm.reply.from && m.to == gm.reply.to && m.captured == gm.reply.captured else { continue; }
        board::start_move(b, k, now);
        return true;
    }
    return false;
}

// The computer's ring as it begins to think: full, fading and back once, then still.
fn pulse(gm: Game&, now: f64) -> f32 {
    guard gm.ai_request_id != 0 && now < gm.asked_at + PULSE else { return 1.0; }
    return (0.65 + 0.35 * cos(2.0 * PI * (now - gm.asked_at) / PULSE)) as f32;
}

// Seconds until the computer's move is due, for the app to wake then, or -1.
fn due(gm: Game&, now: f64) -> f64 {
    guard gm.ai_request_id != 0 && gm.ai_answered else { return -1.0; }
    return max(gm.asked_at + gm.wait - now, 0.0);
}

// One frame, after gui::begin, its pieces over the UI put in `ui_pieces`. Returns what the
// shell should do and know, and whether anything on screen changed. `frozen` (a
// transition into the game) counts no time and asks the computer for nothing.
fn frame(gm: Game&, g: gui::Gui&, l: panel::Layout, now: f64, ui_pieces: board::Overlay&, frozen: bool = false) -> Event, bool {
    let b .= gm.b;
    let input = g.input;
    var changed = board::update(b, now) || input.pressed || input.released;
    var ev = Event {};
    ui_pieces.clear();
    // A mark's tip first: a tap that only closes it goes no further.
    if tips(gm, g, l) { changed = true; }
    // The moves' sheet: in landscape it covers the way out, which isn't declared; in
    // portrait (`cover`) the screen under its dim layer is deaf to the pointer and keys.
    if l.line_as == panel::LINE_NONE || gm.moves_shown == 0 { gm.sheet = false; }
    let open = gm.sheet;
    let cover = open && l.line_as == panel::LINE_BAR;
    if cover { gui::set_input_enabled(g, false); }
    if !frozen && gm.clock_counted_at >= 0.0 && clock::tick(gm.clock, min(now - gm.clock_counted_at, STEP)) { changed = true; }
    gm.clock_counted_at = if frozen { -1.0 } else { now };

    var won = winner(gm);
    let side = if won >= 0 { won } else { b.pos.side as i64 };
    var note = panel::Note {};
    countdown(gm, note);
    let beside = open && !cover;
    let pick = panel::game(g, l, clocks(gm.clock), side, won >= 0, drawn(gm) != rules::NO_DRAW, note, gm.ai_request_id != 0,
                           pulse(gm, now), ui_pieces, help(gm), !beside);
    if count_taken(gm) { changed = true; }
    if keep_notes(gm) { changed = true; }
    gm.marks_at.clear();
    moves_panel(gm, g, l, ui_pieces);
    if beside {
        // A press on the sheet is the UI's, never the board's.
        gui::claim_press(g, gui::extend_to_screen_edge(g, l.sheet, l.area));
    } else {
        panel::taken(g, l, gm.taken, ui_pieces);
        if moves_line(gm, g, l, ui_pieces) {
            gm.sheet = true;
            changed = true;
        }
        if gm.refocus {
            g.focus = LINE_ID;
            gm.refocus = false;
        }
    }
    var undone = false;
    match pick {
        // Partway through a capture, take back only takes the capture back to its start.
        panel::UNDO => { if !board::unwind(b) && gm.clock.flag < 0 { undone = take_back(gm); } },
        panel::RESTART => {
            restart(gm, now);
            ev.restarted = true;
        },
        panel::BACK => { ev.go = HOME; },
        panel::SETTINGS => { ev.go = SETTINGS; },
        panel::LOOKOUT => {
            gm.lookout_on = !gm.lookout_on;
            ev.lookout_toggled = true;
        },
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
        sound_event::add(b.sound_events, sound_event::DRAWN);
        if !gm.end_sent_for_history {
            gm.end_sent_for_history = true;
            ev.ended_for_history = true;
            ev.winner = -1;
        }
        if gm.computer >= 0 && !gm.end_sent_for_rating {
            gm.end_sent_for_rating = true;
            ev.ended = true;
            ev.result = 0;
        }
    }
    if won < 0 {
        gm.won_at = -1.0;
    } else if gm.won_at < 0.0 {
        gm.won_at = now;
        start_win_glow(gm, won);
        changed = true;
        sound_event::add(b.sound_events, if gm.computer >= 0 && won == gm.computer { sound_event::LOST } else { sound_event::WON });
        if !gm.end_sent_for_history {
            gm.end_sent_for_history = true;
            ev.ended_for_history = true;
            ev.winner = won;
        }
        if gm.computer >= 0 && !gm.end_sent_for_rating {
            gm.end_sent_for_rating = true;
            ev.ended = true;
            ev.result = if won == gm.computer { -1 } else { 1 };
        }
    }
    if gm.won_at >= 0.0 {
        // The frame from which the celebration is still is drawn too, at rest.
        if !gm.win_still_drawn && moment(gm, now) >= gm.win_still_from {
            gm.win_still_drawn = true;
            changed = true;
        }
        let ask = celebrate(gm, g, l, won, now, ui_pieces);
        if ask == panel::RESTART {
            restart(gm, now);
            ev.restarted = true;
            changed = true;
        }
        if ask == panel::BACK { ev.go = HOME; }
    } else if gm.drawn_at >= 0.0 {
        if !gm.drawn_still && now - gm.drawn_at >= DRAW_STILL {
            gm.drawn_still = true;
            changed = true;
        }
        let ask = draw_card(gm, g, l, draw, now, ui_pieces);
        if ask == panel::RESTART {
            restart(gm, now);
            ev.restarted = true;
            changed = true;
        }
        if ask == panel::BACK { ev.go = HOME; }
    } else if !cover {
        let held, moved = board::showcase(gm.cam, g, input, l.is_3d, l.pitch, now);
        if moved { changed = true; }
        let mine = !held && !g.press_on_ui && b.pos.side != gm.computer;
        if mine && board::touch(b, l.board, l.is_3d, l.view, input, gm.grab, now) { changed = true; }
        if panel::board_keys(g, l, b, mine, now, rig::turn(gm.cam, now)) { changed = true; }
    }
    // Against a friend the board turns to face the side to move once a move has shown,
    // with the setting on; with it off it faces white.
    if !frozen && gm.computer < 0 && !ended(gm) && !b.moving && b.pressed < 0 {
        if rig::face(gm.cam, if gm.turns { b.pos.side } else { rules::WHITE }, now) { changed = true; }
    }
    if undone {
        clock::undone(gm.clock, b.pos.side, b.rec.history.len == 0);
    } else if b.pos.side != gm.turn {
        clock::moved(gm.clock, gm.turn);
    }
    gm.turn = b.pos.side;
    if watch(gm) { changed = true; }
    // The hint belongs to the position it was asked in.
    if (gm.hint_stage > 0 || gm.hint_request_id != 0) && b.positions_shown != gm.hint_positions_shown {
        gm.hint_stage = 0;
        gm.hint_request_id = 0;
        gm.hint_new = false;
        changed = true;
    }
    if gm.hint_new {
        gm.hint_new = false;
        board::glow_on(b, gm.hint_move.from, now);
        changed = true;
    }
    // The computer's pieces show no count of what they must take: the child can't move them.
    b.hide_counts = gm.computer >= 0 && b.pos.side == gm.computer;
    if b.moves.len == 0 || drawn(gm) != rules::NO_DRAW { clock::stop(gm.clock); }
    // A person's clock heard as it turns gold and as it turns red, once each a game.
    for side in 2 {
        sound_event::add(b.sound_events, sound_event::chime(gm.chimes, side, clock::warn(gm.clock, side), clock::low(gm.clock, side),
                                         gm.computer != side));
    }
    // A running clock draws once a second, when the time it shows changes.
    let shown = if gm.clock.running >= 0 { clock::whole_seconds(gm.clock, gm.clock.running) } else { -1 };
    if shown != gm.clock_seconds_drawn {
        gm.clock_seconds_drawn = shown;
        changed = true;
    }
    // The sheet over everything, and a mark's tip over that.
    if cover {
        gui::set_input_enabled(g, true);
        dim_under(ui_pieces, l.sheet.y);
    }
    if open && moves_sheet(gm, g, l, ui_pieces) {
        gm.sheet = false;
        gm.refocus = g.focus == SHEET_HEAD;
        changed = true;
    }
    if tip(gm, g, l, ui_pieces) { changed = true; }
    return ev, changed;
}

// Whether the lookout shows now: on, the player's turn, the board at rest, the game going
// on, and no capture due.
fn watching(gm: Game&) -> bool {
    let b .= gm.b;
    return gm.lookout_on && !b.moving && b.pos.side != gm.computer && !ended(gm) && !board::must_capture(b);
}

// The lookout's marks on the board (Board.danger, crowns), worked out again only when the
// position, whether it shows, or the held piece and the square under it changed: the
// threats now, or those the held piece's move would leave. True when the marks changed.
fn watch(gm: Game&) -> bool {
    let b .= gm.b;
    let on = watching(gm);
    let target = if on { b.target_under_pointer } else { -1 };
    let selected = if target >= 0 { b.selected } else { -1 };
    let w .= gm.lookout_cache;
    guard on != w.on || target != w.target_under_pointer || selected != w.selected || (on && (!rules::same(b.pos, w.pos) || b.positions_shown != w.positions_shown))
    else { return false; }
    gm.lookout_cache = Watch { on: on, pos: b.pos, selected: selected, target_under_pointer: target, positions_shown: b.positions_shown };
    let danger = b.danger;
    let crowns = b.crowns;
    b.danger = 0;
    b.crowns = 0;
    gm.trap_request_id = 0;
    if on {
        var buf: rules::Moves = [];
        var seen = lookout::Seen {};
        var k = -1;
        if target >= 0 { for m, i in b.moves { if m.from == selected && m.to == target { k = i; } } }
        if k >= 0 { lookout::after(b.pos, b.moves[k], seen, buf); } else { lookout::now(b.pos, seen, buf); }
        let d, c = lookout::shown(seen, gm.lookout_skill);
        b.danger = d;
        b.crowns = c;
        // The traps, on the worker: the other side to move, now or after the held move.
        if gm.lookout_skill < lookout::UNTIL[lookout::TRAP] {
            var q = b.pos;
            q.side = 1 - q.side;
            if k >= 0 { q = rules::play(b.pos, b.moves[k]); }
            gm.ai_request_count += 1;
            gm.trap_request_id = gm.ai_request_count;
            gm.trap_pos = q;
        }
    }
    return b.danger != danger || b.crowns != crowns;
}

// What the play panel shows of the lookout and the hint.
fn help(gm: Game&) -> panel::Help {
    let side = clamp(gm.b.pos.side as i64, 0, 1);
    return panel::Help { look: gm.lookout_on, left: gm.hints[side], stage: gm.hint_stage, can: can_hint(gm) };
}

// Declares the screen as it stands, doing nothing, for a transition away from the game.
fn still(gm: Game&, g: gui::Gui&, l: panel::Layout, now: f64, ui_pieces: board::Overlay&) {
    ui_pieces.clear();
    let won = winner(gm);
    let side = if won >= 0 { won } else { gm.b.pos.side as i64 };
    var note = panel::Note {};
    countdown(gm, note);
    let draw = drawn(gm);
    panel::game(g, l, clocks(gm.clock), side, won >= 0, draw != rules::NO_DRAW, note, gm.ai_request_id != 0, pulse(gm, now), ui_pieces,
                help(gm));
    // Counted here too: a transition declares a game before its first frame of its own.
    count_taken(gm);
    panel::taken(g, l, gm.taken, ui_pieces);
    gm.marks_at.clear();
    moves_panel(gm, g, l, ui_pieces);
    moves_line(gm, g, l, ui_pieces);
    panel::camera(g, l, gm.cam, now);
    if gm.won_at >= 0.0 { celebrate(gm, g, l, won, now, ui_pieces); }
    if gm.drawn_at >= 0.0 { draw_card(gm, g, l, draw, now, ui_pieces); }
}

// Whether anything is still moving at `now`; the app draws while it is.
fn animating(gm: Game&, g: gui::Gui&, now: f64) -> bool {
    let celebrating = (gm.won_at >= 0.0 && moment(gm, now) < gm.win_still_from) || (gm.drawn_at >= 0.0 && now - gm.drawn_at < DRAW_STILL);
    let pulsing = gm.ai_request_id != 0 && (!gm.ai_answered || now < gm.asked_at + PULSE);
    return board::animating(gm.b, now) || gui::animating(g) || celebrating || pulsing || rig::moving(gm.cam, now);
}

// A piece of `side` over the UI centered in `spot` with radius r at opacity a: a man
// (king 0) or a king as board::CROWN or board::STACK.
fn add_ui_piece(ui_pieces: board::Overlay&, spot: float4, r: f32, side: i64, king: i64, a: f32, ring: bool) {
    panel::piece(ui_pieces, spot, r, side, king, a, if ring { 1.0 } else { 0.0 });
}

// The countdown before a draw, as the play panel words it: the moves left of the last
// five, or the position come twice of three.
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
