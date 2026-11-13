// A replay's play from here (task 078, the user's correction of 2026-11-13): at the move
// a replay shows, its button starts a game from that position, of the same draughts,
// against the same opponent (the computer at the game's level and skill, or a friend),
// the player on the same side, the side to move as there, with no clock, its moves
// numbered on from the replay's. It plays as any game: the computer answers, the hint,
// undo, the lookout, and start over (back to the position) work. It counts for nothing:
// its end writes no history and moves no rating, skill, games played, or count of games,
// and the game in progress stays the one kept and the one to resume, the image the app
// writes the same before, during, and after it. Its back, the system's back, and the
// end card's back go to the replay where it was left. The button is dimmed at the end of
// a game that ended there. Then the button and the label at the sizes: test/shell/sizes.
import std;
import vec;
import os;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";
import check from "../";

let SIDES = ["white", "black"];

fn folder() -> u8[>..] {
    let dir = if is_dir("build") { str("build/play-here-files/") } else { str("play-here-files/") };
    make_dir(dir);
    var names: u8[>..] = [];
    list_dir(dir, names);
    for name in split(names, '\n') { if name.len > 0 { delete_file(str(dir, name)); } }
    return dir;
}

var now = 1.0;
fn tick() -> f64 {
    now += 0.5;
    return now;
}

// The rect of control id as the last frame offered it to the keys' focus.
fn spot(g: gui::Gui&, id: i64) -> float4 {
    for s in g.spots { if s.id == id { return s.rect; } }
    print("  no control ", id);
    return float4 { -100.0, -100.0, 1.0, 1.0 };
}

fn press(sh: shell::Shell&, g: gui::Gui&, id: i64) { drive::tap(sh, g, drive::middle(spot(g, id)), tick()); }

var asked: i64 = 0;          // the computer's ask last printed

// Answers the game's open ask at once, as the app's worker would; true when it answered.
fn answer(sh: shell::Shell&, e: ai::Engine&) -> bool {
    let gm .= sh.game;
    var a = game::ask_for(gm);
    guard a.id != 0 else { return false; }
    if a.kind == game::JUDGE {
        let v = ai::judge(e, a.past, a.pos, a.move);
        game::judged(gm, a.id, v.mark, v.loss);
        return true;
    }
    if a.kind == game::HINT {
        game::hinted(gm, a.id, ai::think_after(e, a.past, a.pos, a.skill, a.seed));
        return true;
    }
    if a.kind == game::THINK {
        if a.id != asked { print("  the computer asked at skill ", a.skill); }
        asked = a.id;
        game::answer(gm, a.id, ai::think_after(e, a.past, a.pos, a.skill, a.seed), 1);
        return true;
    }
    return false;
}

// Frames for `seconds`, the worker answering between them.
fn run(sh: shell::Shell&, g: gui::Gui&, e: ai::Engine&, seconds: f64) {
    let end = now + seconds;
    while now < end {
        drive::idle(sh, g, now);
        answer(sh, e);
        now += 0.05;
    }
}

// Plays the move named `text` on the game's board, as a tap would.
fn play(sh: shell::Shell&, text: const u8[:]) {
    let b .= sh.game.b;
    for i in b.moves.len {
        var t: u8[>..] = [];
        rules::format_move(t, b.variant, b.moves[i]);
        guard t == text else { continue; }
        board::play_chosen(b, i, now);
        return;
    }
    print("  no move ", text);
}

// The first legal move's name on the game's board.
fn first_move(sh: shell::Shell&) -> u8[>..] {
    var t: u8[>..] = [];
    rules::format_move(t, sh.game.b.variant, sh.game.b.moves[0]);
    return t;
}

// What the game on the game screen is: from where, against whom, and how.
fn trial(sh: shell::Shell&) -> u8[>..] {
    let gm .= sh.game;
    let r .= sh.replay;
    let opponent = if gm.computer < 0 { str("a friend") } else { str("the computer as ", SIDES[gm.computer], " at level ", gm.level, ", skill ", gm.skill) };
    return str("screen ", sh.screen, " (game ", shell::GAME, "), from the replay ", sh.trial, ", doesn't count ", gm.no_count,
               "; ", rules::VARIANT_NAMES[gm.b.variant], " against ", opponent, "; the replay's position ",
               rules::same(gm.b.pos, r.pos[r.ply]), ", ", SIDES[gm.b.pos.side], " to move; clock ", gm.clock.kind,
               "; moves ", gm.b.history.len);
}

// What a game's end could change: the rating, the skills and games per level, the games
// begun, and the history file.
fn kept(sh: shell::Shell&, path: const u8[:]) -> u8[>..] {
    let p .= sh.prefs;
    var text: u8[>..] = [];
    read_file(path, text);
    var s = str("ratings");
    for v in rules::VARIANT_COUNT { format(s, " ", p.rating[v], "/", p.rated[v]); }
    format(s, "; skills ", p.skill[0], " ", p.skill[1], " ", p.skill[2], ", played ", p.played[0], " ", p.played[1], " ",
           p.played[2], "; games ", p.games, "; history ", split(text, '\n').len, " lines, ", text.len, " bytes");
    return s;
}

// The numbers of the game's first two moves in its list ("16." white's, "16…" black's).
fn numbers(sh: shell::Shell&) -> u8[>..] {
    var s: u8[>..] = [];
    for i in min(sh.game.notes.len, 2) {
        let n, black = game::row_of(sh.game, i);
        var m: u8[>..] = [];
        rules::format_move(m, sh.game.b.variant, sh.game.notes[i].move);
        format(s, n, if black { "… " } else { ". " }, m, "  ");
    }
    return s;
}

fn main() {
    strings::use(strings::EN);
    let dir = folder();
    var e = ai::Engine { .. };
    ai::init(e);
    e.node_limit = 20000;
    // Three games, oldest first: Russian against the computer (40 moves), International
    // against a friend (30), and International against the computer, the newest (90 at
    // most; it ends at the 80th, black having no move).
    let russian = drive::past_line(rules::RUSSIAN, 40, 1762819200);
    var friend: u8[>..] = [];
    for field, i in split(drive::past_line(rules::INTERNATIONAL, 30, 1762822800), '\t') {
        guard !starts_with(field, "against") && !starts_with(field, "level") && !starts_with(field, "skill")
              && !starts_with(field, "side") && !starts_with(field, "rating") else { continue; }
        if friend.len > 0 { friend.push('\t'); }
        friend.append(field);
        if starts_with(field, "draughts") { friend.append("\tagainst=friend"); }
    }
    let newest = drive::past_line(rules::INTERNATIONAL, 90, 1762826400);
    let path = str(dir, "history-1.txt");
    write_file(path, str(russian, "\n", friend, "\n", newest, "\n"));

    var sh = shell::new(rules::INTERNATIONAL);
    var ps = players::Players {};
    sh.prefs = players::load(ps, dir, true);
    sh.players = ps;
    sh.wall = 1762830000.0;
    // A game in progress against the computer, two moves in: the one to resume, which the
    // games from the replay must leave as it is.
    game::start(sh.game, rules::INTERNATIONAL, 0, rules::BLACK, game::MEDIUM, 40, 0);
    for k in 2 {
        board::start_move(sh.game.b, 0, 0.0);
        board::update(sh.game.b, 10.0);
    }
    sh.prefs.games = 7;
    let saved = shell::save(sh);
    let before = kept(sh, path);
    print("before: ", before);

    var g = gui::Gui {};
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    drive::idle(sh, g, tick());
    shell::go_to(sh, shell::RESULTS, now);
    drive::idle(sh, g, tick());
    press(sh, g, results::ROW_ID);
    drive::idle(sh, g, tick());
    let r .= sh.replay;
    print("the newest game's replay: screen ", sh.screen, " (replay ", shell::REPLAY, "), move ", r.ply, " of ", r.plies.len,
          ", the game over there ", r.over);

    // At the end of a game that ended there the button is dimmed and takes no tap.
    replay::go(r, r.plies.len - 1, 0.0);
    drive::idle(sh, g, tick());
    let at = spot(g, replay::PLAY_ID);
    replay::go(r, r.plies.len, 0.0);
    drive::idle(sh, g, tick());
    drive::tap(sh, g, drive::middle(at), tick());
    print("at the end, play from here tapped: playable ", replay::playable(r), ", screen ", sh.screen, ", from the replay ", sh.trial);

    // Move 30: white, the player, to move.
    replay::go(r, 30, 0.0);
    drive::idle(sh, g, tick());
    press(sh, g, replay::PLAY_ID);
    print("played from move 30: ", trial(sh));
    print("  the image kept is the game in progress's: ", shell::save(sh) == saved, "; home's continue still on: ",
          shell::resume(sh).on);
    run(sh, g, e, 0.2);
    let first = first_move(sh);
    play(sh, first[..]);
    run(sh, g, e, 3.0);
    print("  a move and the computer's answer: ", trial(sh), "; listed ", numbers(sh));
    // The hint: asked, answered, a hint spent.
    game::press_hint(sh.game, now);
    run(sh, g, e, 0.5);
    print("  the hint: its piece lit ", sh.game.hint_stage == 1, ", hints left ", sh.game.hints[rules::WHITE]);
    // The lookout's eye, the player's setting as in any game.
    let look = sh.game.look;
    press(sh, g, panel::EYE_ID);
    print("  the lookout turned ", if sh.game.look { "on" } else { "off" }, ", from ", if look { "on" } else { "off" },
          ", the setting following ", sh.prefs.lookout == sh.game.look);
    press(sh, g, panel::EYE_ID);
    // Undo takes back the player's move and the computer's.
    press(sh, g, gui::PANEL_IDS + 3);
    run(sh, g, e, 0.5);
    print("  undo: ", trial(sh), "; notes ", sh.game.notes.len);
    // Start over after a move: back to the replay's position, nothing counted.
    play(sh, first[..]);
    run(sh, g, e, 3.0);
    press(sh, g, gui::PANEL_IDS + 2);
    run(sh, g, e, 0.2);
    print("  started over: ", trial(sh), "; ", kept(sh, path) == before, " nothing kept changed");
    // Its back: the replay where it was left, the game in progress back as it was.
    press(sh, g, gui::PANEL_IDS);
    drive::idle(sh, g, tick());
    print("back: screen ", sh.screen, ", move ", r.ply, ", from the replay ", sh.trial, "; the game in progress as it was: ",
          shell::save(sh) == saved, ", ", sh.game.b.history.len, " moves, the computer as ",
          SIDES[sh.game.computer]);

    // The friend's game at move 11, black to move: two sides of a friend's, numbered on.
    shell::open_replay(sh, 1, tick());
    replay::go(r, 11, 0.0);
    drive::idle(sh, g, tick());
    press(sh, g, replay::PLAY_ID);
    print("the friend's game from move 11: ", trial(sh));
    let one = first_move(sh);
    play(sh, one[..]);
    run(sh, g, e, 1.0);
    let two = first_move(sh);
    play(sh, two[..]);
    run(sh, g, e, 1.0);
    print("  two moves: listed ", numbers(sh), "; ", trial(sh));
    // The system's back (Android's, or Escape) goes to the replay too.
    shell::back(sh, tick());
    drive::idle(sh, g, tick());
    print("  the system's back: screen ", sh.screen, ", from the replay ", sh.trial);

    // The Russian game against the computer: won from the replay, it counts for nothing.
    shell::open_replay(sh, 0, tick());
    replay::go(r, 10, 0.0);
    drive::idle(sh, g, tick());
    press(sh, g, replay::PLAY_ID);
    print("the Russian game from move 10: ", trial(sh));
    board::set(sh.game.b, check::position(rules::RUSSIAN, "W:Wc3:Bd4"));
    sh.game.turn = sh.game.b.pos.side;
    run(sh, g, e, 0.2);
    play(sh, "c3:e5");
    run(sh, g, e, 4.0);
    print("  won: winner ", SIDES[game::winner(sh.game)], ", screen ", sh.screen, "; nothing kept changed: ",
          kept(sh, path) == before, ", the game kept open for its marks ", sh.kept.open, ", the image kept ",
          shell::save(sh) == saved);
    // The card's back: the replay.
    drive::tap(sh, g, drive::control(g, drive::tiles(g) - 2), tick());
    drive::idle(sh, g, tick());
    print("  the card's back: screen ", sh.screen, ", from the replay ", sh.trial);

    print("after: ", kept(sh, path));
    print("the game in progress as it was: ", shell::save(sh) == saved, "; home's continue on: ", shell::resume(sh).on);
}
