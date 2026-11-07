// The computer's skill across games (shell/), headless: each level keeps its own skill
// in the settings, which a game against the computer plays at throughout. A game the
// child wins moves its level's skill up a step (ai::adapt), one the computer wins down a
// step, and the settings file keeps it; a game started over before it ends counts
// nothing. A skill in the file stays within its level's band. A game restored after the
// level's skill moved still plays at its own.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import game from "../../game";
import shell from "../../shell";
import ai from "../../ai";
import strings from "../../strings";

let W = 1280.0;
let H = 800.0;

fn frame(sh: shell::Shell&, g: gui::Gui&, at: float2, down: bool, pressed: bool, released: bool, now: f64) {
    gui::begin(g, gui::Input { at: at, down: down, pressed: pressed, released: released }, 1.0, now);
    shell::frame(sh, g, W, H, now);
}

fn idle(sh: shell::Shell&, g: gui::Gui&, now: f64) { frame(sh, g, float2 { -1.0, -1.0 }, false, false, false, now); }

fn tap(sh: shell::Shell&, g: gui::Gui&, p: float2, now: f64) {
    frame(sh, g, p, true, true, false, now);
    frame(sh, g, p, false, false, true, now + 0.02);
}

fn square(sh: shell::Shell&, text: const u8[:]) -> float2 {
    let v .= rules::VARIANTS[rules::RUSSIAN];
    return board::center(sh.layout, v, rules::bit_at(v, text[0] - 97, text[1] - 49));
}

// The game's start over tile: the third of the game's tiles.
fn start_over(g: gui::Gui&) -> float2 {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.extra.y < gui::CLOCK_RUN else { continue; }
        if k == 2 { return float2 { q.rect.x + 0.5 * q.rect.z, q.rect.y + 0.5 * q.rect.w }; }
        k++;
    }
    assert(false);
    return float2 { 0.0, 0.0 };
}

// Answers the game's ask at once, as the app's worker does later.
fn answer(sh: shell::Shell&, e: ai::Engine&) {
    let ask = game::asking(sh.game);
    if ask.id != 0 { game::answer(sh.game, ask.id, ai::think(e, ask.pos, ask.skill, ask.seed)); }
}

fn skills(sh: shell::Shell&) -> u8[>..] {
    let s .= sh.prefs.skill;
    return str("skills ", s[0], " ", s[1], " ", s[2], ", changed ", sh.changed);
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
    idle(sh, g, 0.0);
    tap(sh, g, square(sh, "c3"), 0.1);
    tap(sh, g, square(sh, "e5"), 0.2);
    idle(sh, g, 1.0);
    print("the child won on easy: winner ", game::winner(sh.game), ", ", skills(sh));
    sh.changed = false;
    idle(sh, g, 2.0);
    print("  a frame later: ", skills(sh));

    // Medium: the computer takes the child's last piece and wins.
    play(sh, game::MEDIUM, "B:Wd4:Bc5");
    idle(sh, g, 10.0);
    answer(sh, e);
    idle(sh, g, 11.0);
    idle(sh, g, 12.0);
    print("the computer won on medium: winner ", game::winner(sh.game), ", ", skills(sh));

    // Hard: started over before the end, a game counts nothing.
    play(sh, game::HARD, "W:Wc3:Bd4");
    idle(sh, g, 20.0);
    tap(sh, g, start_over(g), 20.1);
    idle(sh, g, 21.0);
    print("started over on hard: ", skills(sh));

    // The file keeps the skills, and reads them back.
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    let back = settings::parse(out);
    print("read back: skills ", back.skill[0], " ", back.skill[1], " ", back.skill[2]);
    let far = settings::parse("skill_easy = 99\nskill_medium = -5\nskill_hard = many\n");
    print("out of the band: skills ", far.skill[0], " ", far.skill[1], " ", far.skill[2]);

    // A game on easy saved at skill 14, restored after easy's skill moved on, asks at 14.
    play(sh, game::EASY, "B:Wc3,e3:Bd6,f6");
    let image = shell::save(sh);
    var later = shell::new(rules::RUSSIAN);
    later.prefs.skill[game::EASY] = 18;
    print("restored: ", shell::restore(later, image));
    idle(later, g, 30.0);
    let ask = game::asking(later.game);
    print("  against ", later.game.computer, " at level ", later.game.level, ", asks ", ask.id != 0, " at skill ",
          ask.skill);
}
