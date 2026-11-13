// How to play (shell/tutorial.goose, task 026), headless at the tablet's landscape: each
// draughts' steps with their positions and every legal move in them, so a step can only
// be played as it teaches; then the whole tutorial played through the shell by taps, the
// first step's answer between the child's two moves, next lit only once a step is played,
// the steps kept in the player's settings, the end's card, and its puzzles opening the
// Learn theme's first puzzle in the draughts learned. Then home's How to play row: shown
// for a player asked and not yet done, gone once done.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import game from "../../src/game";
import strings from "../../strings";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

let STATES = ["playing", "reply", "played", "end"];
var t: f64 = 0.0;
fn tick() -> f64 {
    t += 0.05;
    return t;
}

// Frames for `seconds`, so what moves lands.
fn settle(sh: shell::Shell&, g: gui::Gui&, seconds: f64) {
    let end = t + seconds;
    while t < end { drive::idle(sh, g, tick()); }
}

fn spot(g: gui::Gui&, id: i64) -> float4 {
    for s in g.spots { if s.id == id { return s.rect; } }
    print("  no control ", id);
    return float4 { -100.0, -100.0, 1.0, 1.0 };
}

fn press(sh: shell::Shell&, g: gui::Gui&, id: i64) { drive::tap(sh, g, drive::middle(spot(g, id)), tick()); }

// A move as text: from, its stops, and its end, x between them for a capture.
fn said(v: rules::Variant&, m: rules::Move&) -> u8[>..] {
    var s = str(drive::name(v, m.from));
    let sep = if m.captured != 0 { "x" } else { "-" };
    for p in m.path { if p != m.to && p != m.from { format(s, sep, drive::name(v, p)); } }
    format(s, sep, drive::name(v, m.to));
    if m.crowned { s.append("K"); }
    return s;
}

// Plays the board's first legal move by taps: its piece, then each stop to its end.
fn play_first(sh: shell::Shell&, g: gui::Gui&) {
    let b .= shell::shown(sh);
    let v .= rules::VARIANTS[b.variant];
    let m = b.moves[0];
    drive::tap(sh, g, drive::at(sh.out.layout, drive::name(v, m.from)), tick());
    for p in m.path {
        guard p != m.to && p != m.from else { continue; }
        drive::tap(sh, g, drive::at(sh.out.layout, drive::name(v, p)), tick());
        settle(sh, g, 0.6);
    }
    drive::tap(sh, g, drive::at(sh.out.layout, drive::name(v, m.to)), tick());
    settle(sh, g, 1.5);
}

fn state(sh: shell::Shell&) -> u8[>..] {
    let ls .= sh.lesson;
    return str("step ", ls.step + 1, " ", STATES[ls.state], ", played ", ls.played, ", learned ",
               sh.prefs.learned[sh.prefs.variant], ", next lit ", tutorial::ready(ls) == false && ls.state == tutorial::PLAYED);
}

fn main() {
    strings::use(strings::EN);
    // Each draughts' steps.
    var ls = tutorial::new();
    for v in [rules::INTERNATIONAL, rules::BRAZILIAN, rules::RUSSIAN] {
        print(rules::VARIANT_NAMES[v], ": ", tutorial::count(v as u8), " steps");
        for k in tutorial::count(v as u8) {
            tutorial::open(ls, v as u8, k);
            let s = tutorial::current(ls);
            let vv .= rules::VARIANTS[v];
            var moves: u8[>..] = [];
            for m in ls.b.moves { format(moves, " ", said(vv, m)); }
            print("  ", k + 1, " ", strings::get(strings::HOW_STEP + 3 * s), ": ", rules::fen(ls.b.pos), ",", moves[..],
                  if board::must_capture(ls.b) { " (must take)" } else { "" });
        }
    }

    // Through the shell: a new player, asked, playing International's tutorial.
    var g = gui::Gui {};
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    puzzles::load();
    var sh = shell::new(rules::INTERNATIONAL);
    sh.unset = true;
    sh.prefs.first_start_done = true;
    drive::idle(sh, g, tick());
    print("home's first row how to play: ", shell::resume(sh).learn);
    press(sh, g, gui::HOME_IDS + 1);
    settle(sh, g, 0.5);
    print("how to play: screen ", sh.screen, " (", shell::TUTORIAL, "), ", state(sh));
    // Next takes no tap before the step is played.
    var takes = false;
    for s in g.spots { if s.id == panel::EYE_ID { takes = true; } }
    print("next before the move takes a tap: ", takes);
    let n = tutorial::count(rules::INTERNATIONAL);
    for k in n {
        play_first(sh, g);
        if k == 0 {
            print("  the first move: ", state(sh));
            settle(sh, g, 1.5);
            let b .= shell::shown(sh);
            print("  the answer: ", state(sh), ", last ", drive::name(rules::VARIANTS[b.variant], b.last.from), "-",
                  drive::name(rules::VARIANTS[b.variant], b.last.to), ", glowing ",
                  if b.glow >= 0 { drive::name(rules::VARIANTS[b.variant], b.glow) } else { str("none") });
            play_first(sh, g);
        }
        print("  played: ", state(sh), ", changed ", sh.changed);
        press(sh, g, panel::EYE_ID);
        settle(sh, g, 0.3);
    }
    print("the end: ", state(sh), ", the card's ways ", drive::tiles(g));
    print("home's first row how to play, done: ", shell::resume(sh).learn);
    press(sh, g, tutorial::CARD_PUZZLES);
    settle(sh, g, 0.5);
    print("puzzles: screen ", sh.screen, " (puzzle ", shell::PUZZLE, "), theme ", sh.theme, " (learn ", puzzles::LEARN, ")");

    // Back from it goes where it came from; settings and back return to it.
    var lib = shell::new(rules::INTERNATIONAL);
    drive::idle(lib, g, tick());
    shell::learn(lib, shell::PICKER, tick());
    settle(lib, g, 0.3);
    print("from the library: screen ", lib.screen, ", step ", lib.lesson.step + 1);
    shell::back(lib, tick());
    settle(lib, g, 0.3);
    print("back: screen ", lib.screen, " (the library ", shell::PICKER, ")");
    // A tutorial played partway opens at the next step.
    lib.prefs.learned[rules::INTERNATIONAL] = 4;
    shell::learn(lib, shell::HOME, tick());
    print("four played: opens at step ", lib.lesson.step + 1);
}
