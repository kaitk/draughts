// The computer's skill across games (shell/), headless: each level keeps its own skill
// in the settings, which a game against the computer plays at throughout. A game the
// child wins moves its level's skill up a step (ai::adapt), one the computer wins down a
// step, and the settings file keeps it; the steps are larger over a player's first
// games on a level. A game started over before it ends moves no skill. Play again on
// the card, or start over, begins a new game at its level's skill as it is now, and
// counts it as home's play does. A skill in the file stays within its level's band, and
// a file from before the games per level were kept starts a skill still where its level
// started then afresh. A game restored after the level's skill moved still plays at its
// own.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

// Answers the game's ask at once, as the app's worker does later.
fn answer(sh: shell::Shell&, e: ai::Engine&) {
    let ask = game::asking(sh.game);
    if ask.id != 0 { game::answer(sh.game, ask.id, ai::think(e, ask.pos, ask.skill, ask.seed), ai::close(e, pace::CLOSE)); }
}

fn skills(sh: shell::Shell&) -> u8[>..] {
    let s .= sh.prefs.skill;
    let n .= sh.prefs.played;
    return str("skills ", s[0], " ", s[1], " ", s[2], ", played ", n[0], " ", n[1], " ", n[2], ", changed ", sh.changed);
}

// The game under way: its skill and number, and the games begun against the computer.
fn current(sh: shell::Shell&) -> u8[>..] {
    return str("the game at skill ", sh.game.skill, ", number ", sh.game.number, "; games ", sh.prefs.games);
}

// The child takes black's last piece on easy and wins.
fn win_easy(sh: shell::Shell&, g: gui::Gui&, t: f64) {
    board::set(sh.game.b, check_position("W:Wc3:Bd4"));
    drive::idle(sh, g, t);
    drive::tap(sh, g, drive::at(sh.layout, "c3"), t + 0.1);
    drive::tap(sh, g, drive::at(sh.layout, "e5"), t + 0.2);
    drive::idle(sh, g, t + 1.0);
}

fn check_position(fen: const u8[:]) -> rules::Position {
    let p, ok = rules::parse_fen(fen, rules::RUSSIAN);
    assert(ok);
    return p;
}

// A new game against the computer playing black at `level`, from `fen`, as home's play
// starts one.
fn play(sh: shell::Shell&, level: i64, fen: const u8[:]) {
    game::start(sh.game, rules::RUSSIAN, clock::NONE, rules::BLACK, level, sh.prefs.skill[level], sh.prefs.games);
    let p, ok = rules::parse_fen(fen, rules::RUSSIAN);
    assert(ok);
    board::set(sh.game.b, p);
    sh.screen = shell::GAME;
    sh.changed = false;
}

fn main() {
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::test_faces(g);
    var e = ai::Engine { .. };
    ai::init(e);
    var sh = shell::new(rules::RUSSIAN);
    print("at first: ", skills(sh));

    // Easy: the child takes black's last piece and wins.
    play(sh, game::EASY, "W:Wc3:Bd4");
    drive::idle(sh, g, 0.0);
    drive::tap(sh, g, drive::at(sh.layout, "c3"), 0.1);
    drive::tap(sh, g, drive::at(sh.layout, "e5"), 0.2);
    drive::idle(sh, g, 1.0);
    print("the child won on easy: winner ", game::winner(sh.game), ", ", skills(sh));
    sh.changed = false;
    drive::idle(sh, g, 2.0);
    print("  a frame later: ", skills(sh));

    // Play again on the card: a new game at easy's new skill, counted. The celebration's
    // card has come by 3 s.
    sh.prefs.games = 5;
    sh.game.number = 4;
    drive::idle(sh, g, 4.0);
    drive::tap(sh, g, drive::control(g, 5), 4.1);
    print("played again: winner ", game::winner(sh.game), ", ", current(sh), ", changed ", sh.changed);
    // Won again: the second of the first games, a large step.
    win_easy(sh, g, 5.0);
    print("won again: ", skills(sh));
    // Started over during the game: the new game at the skill now, counted.
    drive::idle(sh, g, 9.0);
    drive::tap(sh, g, drive::control(g, 5), 9.1);
    print("played again: ", current(sh));
    drive::tap(sh, g, drive::control(g, 2), 9.5);
    print("started over: ", current(sh));
    win_easy(sh, g, 10.0);
    drive::idle(sh, g, 13.0);
    drive::tap(sh, g, drive::control(g, 5), 13.1);
    win_easy(sh, g, 14.0);
    print("two more wins, the third game a large step and the fourth a small one: ", skills(sh));
    sh.changed = false;

    // Medium: the computer takes the child's last piece and wins.
    play(sh, game::MEDIUM, "B:Wd4:Bc5");
    drive::idle(sh, g, 10.0);
    answer(sh, e);
    drive::idle(sh, g, 11.0);
    drive::idle(sh, g, 12.0);
    print("the computer won on medium: winner ", game::winner(sh.game), ", ", skills(sh));

    // Medium again: losses stop at its floor, 25, short of 20 below its start.
    for _ in 6 {
        play(sh, game::MEDIUM, "B:Wd4:Bc5");
        drive::idle(sh, g, 10.0);
        answer(sh, e);
        drive::idle(sh, g, 11.0);
        drive::idle(sh, g, 12.0);
    }
    print("six more losses on medium: ", skills(sh));

    // Hard: started over before the end, a game counts nothing.
    play(sh, game::HARD, "W:Wc3:Bd4");
    drive::idle(sh, g, 20.0);
    drive::tap(sh, g, drive::control(g, 2), 20.1);
    drive::idle(sh, g, 21.0);
    print("started over on hard: ", skills(sh));

    // The file keeps the skills, and reads them back.
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    let back = settings::parse(out);
    print("read back: skills ", back.skill[0], " ", back.skill[1], " ", back.skill[2]);
    let far = settings::parse("skill_easy = 99\nskill_medium = -5\nskill_hard = many\n");
    print("out of the band: skills ", far.skill[0], " ", far.skill[1], " ", far.skill[2]);
    // A file from before: easy still at its old start, 10, starts at 0 with its first
    // games to come; skills moved keep where they are, past their first games; a level
    // the file doesn't name is new.
    let old = settings::parse("skill_easy = 10\nskill_medium = 44\n");
    print("a file from before: skills ", old.skill[0], " ", old.skill[1], " ", old.skill[2], ", played ",
          old.played[0], " ", old.played[1], " ", old.played[2]);
    let moved = settings::parse("skill_easy = 6\nskill_medium = 40\n");
    print("  and another: skills ", moved.skill[0], " ", moved.skill[1], " ", moved.skill[2], ", played ",
          moved.played[0], " ", moved.played[1], " ", moved.played[2]);

    // A game on easy saved at skill 14, restored after easy's skill moved on, asks at 14.
    play(sh, game::EASY, "B:Wc3,e3:Bd6,f6");
    let image = shell::save(sh);
    var later = shell::new(rules::RUSSIAN);
    later.prefs.skill[game::EASY] = 18;
    print("restored: ", shell::restore(later, image));
    drive::idle(later, g, 30.0);
    let ask = game::asking(later.game);
    print("  against ", later.game.computer, " at level ", later.game.level, ", asks ", ask.id != 0, " at skill ",
          ask.skill);
}
