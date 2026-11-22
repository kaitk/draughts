// A draw offered and a game given up (game/, shell/), headless, through the shell so the
// rating, the skill, and the history count it. The draw tile shows while both sides have
// a king. Against the computer, ahead, it refuses: a card in the middle with Continue,
// then the tile dim for the child's next five moves. In a dead draw it accepts: the
// draw's card says Agreed, the rating counts ½, the skill stays, and after undo and a
// second agreement nothing counts again. After its own move into a dead draw it offers
// once: Play on closes the card and it never asks again. From the child's fifth move
// start over asks to give up: Keep playing goes on, Give up is the computer's win,
// counted once though taken back and given up again. In a friend's game Draw ends the
// game at once, and undo takes it back.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import model3d from "../../src/model3d";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

let UNDO = 3;
let RESTART = 2;
let CARDS = ["no card", "refused", "offer", "give up"];
let TILES = ["hidden", "on", "dim"];
let ENDS = ["by the board", "agreed", "given up"];

// The center of the tile holding `icon`, the first or the last such: the tile declared
// just before the icon.
fn icon_tile(g: gui::Gui&, icon: i64, last: bool) -> float2 {
    var at = float2 { -1.0, -1.0 };
    var tile = -1;
    for q, i in g.quads {
        if q.look.x == gui::BUTTON { tile = i; }
        guard q.look.x == gui::ICON && q.look.z as i64 == icon && tile >= 0 else { continue; }
        at = drive::middle(g.quads[tile].rect);
        guard last else { return at; }
    }
    assert(at.x >= 0.0);
    return at;
}

// The last tile the frame declared: a card's only answer.
fn last_tile(g: gui::Gui&) -> float2 { drive::tile(g, drive::tiles(g) - 1) }

// Answers the game's ask at once with the search's score, as the app's worker does.
fn answer(sh: shell::Shell&, e: ai::Engine&) {
    let ask = game::asking(sh.game);
    guard ask.id != 0 else { return; }
    let m = ai::think(e, ask.pos, ask.skill, ask.seed);
    let score, searched = ai::search_score(e);
    game::answer(sh.game, ask.id, m, ai::close(e, pace::CLOSE), score, searched);
}

fn state(sh: shell::Shell&, what: const u8[:]) {
    let gm .= sh.game;
    let p .= sh.prefs;
    print(what, ": ", rules::fen(gm.b.pos), ", card ", CARDS[gm.card], ", tile ", TILES[game::draw_tile(gm)], ", ended ",
          ENDS[gm.ended_by], ", winner ", game::winner(gm), ", drawn ", game::drawn(gm));
    print("  rating ", p.rating[rules::RUSSIAN], ", rated ", p.rated[rules::RUSSIAN], ", medium's skill ", p.skill[game::MEDIUM],
          ", played ", p.played[game::MEDIUM], ", history's last winner ", sh.kept.game.winner);
}

fn play(sh: shell::Shell&, computer: i64, fen: const u8[:]) {
    game::start(sh.game, rules::RUSSIAN, clock::NONE, computer, game::MEDIUM, sh.prefs.skill[game::MEDIUM], sh.prefs.games);
    let p, ok = rules::parse_fen(fen, rules::RUSSIAN);
    assert(ok);
    board::set(sh.game.b, p);
    sh.screen = shell::GAME;
}

// Frames until the board is at rest, from `now`; returns the time after.
fn rest(sh: shell::Shell&, g: gui::Gui&, now: f64) -> f64 {
    var t = now;
    drive::idle(sh, g, t);
    while sh.game.b.moving || t < now + 1.0 {
        t += 1.0 / 60.0;
        drive::idle(sh, g, t);
    }
    return t;
}

// The child plays the first legal move, the computer answers, and both show.
fn both_move(sh: shell::Shell&, g: gui::Gui&, e: ai::Engine&, now: f64) -> f64 {
    board::start_move(sh.game.b, 0, now);
    var t = rest(sh, g, now);
    answer(sh, e);
    return rest(sh, g, t + 1.0);
}

fn main() {
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::test_faces(g);
    var e = ai::Engine { .. };
    e.node_limit = 60000;
    ai::init(e);
    var sh = shell::new(rules::RUSSIAN);

    // The computer, black, three kings against the child's one off the long diagonal: it
    // is ahead (its last search said about six men) and refuses.
    play(sh, rules::BLACK, "W:WKh2:BKb8,Kd8,Kf8");
    sh.game.score = 600;
    var t = rest(sh, g, 0.0);
    state(sh, "three kings against one");
    drive::tap(sh, g, icon_tile(g, gui::HANDSHAKE, false), t);
    state(sh, "offered");
    drive::tap(sh, g, last_tile(g), t + 0.5);
    state(sh, "continued");
    drive::tap(sh, g, icon_tile(g, gui::HANDSHAKE, false), t + 1.0);
    state(sh, "the dim tile tapped");

    // Two kings against one, a dead draw though its score says won: it accepts.
    play(sh, rules::BLACK, "W:WKc1,Ke1:BKa7");
    t = both_move(sh, g, e, rest(sh, g, 2.0));
    sh.game.score = 300;
    drive::tap(sh, g, icon_tile(g, gui::HANDSHAKE, false), t);
    t = rest(sh, g, t + 0.1);
    state(sh, "two kings against one, offered");
    print("  the draw's reason: ", strings::get(strings::DRAW_AGREED), ", controls ", drive::tiles(g));
    drive::tap(sh, g, drive::control(g, UNDO), t);
    state(sh, "undone");
    drive::tap(sh, g, icon_tile(g, gui::HANDSHAKE, false), t + 0.5);
    t = rest(sh, g, t + 0.6);
    state(sh, "agreed again: nothing counted again");

    // Black to move with two kings each: after its move a dead draw, and it offers.
    play(sh, rules::BLACK, "B:WKc1,Ke1:BKa7,Kh8");
    t = rest(sh, g, 10.0);
    answer(sh, e);
    t = rest(sh, g, t + 1.0);
    state(sh, "its move made");
    drive::tap(sh, g, icon_tile(g, gui::NEXT, true), t);
    state(sh, "played on");
    t = both_move(sh, g, e, t + 0.5);
    state(sh, "another move each: no second offer");

    // Giving up, from the start: before the child's fifth move start over is free.
    play(sh, rules::BLACK, "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8");
    t = rest(sh, g, 20.0);
    for i in 4 {
        print("  child's moves ", game::child_moves(sh.game), ", start over asks ", game::asks_to_give_up(sh.game));
        t = both_move(sh, g, e, t);
    }
    print("  child's moves ", game::child_moves(sh.game), ", start over asks ", game::asks_to_give_up(sh.game));
    drive::tap(sh, g, drive::control(g, RESTART), t);
    state(sh, "start over");
    drive::tap(sh, g, icon_tile(g, gui::NEXT, true), t + 0.5);
    state(sh, "kept playing");
    drive::tap(sh, g, drive::control(g, RESTART), t + 1.0);
    drive::tap(sh, g, icon_tile(g, gui::FLAG, true), t + 1.5);
    t = rest(sh, g, t + 1.6);
    state(sh, "given up");
    drive::tap(sh, g, drive::control(g, UNDO), t);
    t = rest(sh, g, t + 0.1);
    state(sh, "undone");
    t = both_move(sh, g, e, t);
    drive::tap(sh, g, drive::control(g, RESTART), t);
    drive::tap(sh, g, icon_tile(g, gui::FLAG, true), t + 0.5);
    t = rest(sh, g, t + 0.6);
    state(sh, "given up again: nothing counted again");

    // A friend's game: Draw ends it at once; undo takes it back.
    play(sh, -1, "W:WKc1,Ke1:BKa7");
    board::start_move(sh.game.b, 0, 60.0);
    t = rest(sh, g, 60.0);
    state(sh, "a friend's game");
    drive::tap(sh, g, icon_tile(g, gui::HANDSHAKE, false), t);
    t = rest(sh, g, t + 0.1);
    state(sh, "drawn");
    drive::tap(sh, g, drive::control(g, UNDO), t);
    state(sh, "undone");
}
