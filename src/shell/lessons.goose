// How to play (task 026): the shell's side of tutorial.goose, opening it and going where
// its end's card asks. Part of the shell's namespace.
namespace shell;
import std;

// How many steps of the player's draughts' tutorial they have played.
fn learned(sh: Shell&) -> i64 { sh.prefs.learned[clamp(sh.prefs.variant, 0, rules::VARIANT_COUNT - 1)] }

// Opens how to play in the player's draughts (task 026), from `from` (HOME or PICKER),
// where its back goes: at the step after those played, or the first once all are.
fn learn(sh: Shell&, from: i64, now: f64) {
    let v = sh.prefs.variant as u8;
    let done = learned(sh);
    tutorial::open(sh.lesson, v, if done < tutorial::count(v) { done } else { 0 });
    sh.lesson_from = from;
    apply_prefs(sh);
    go_to(sh, TUTORIAL, now);
}

// Where how to play puts the board and its panels: a puzzle's layout.
fn tutorial_layout(sh: Shell&, area: float4, u: f32, now: f64) -> panel::Layout {
    return side_layout(sh, area, u, sh.lesson.b.variant, false, sh.lesson.cam, now);
}

// How to play for this frame: the steps played kept in the player's file, and the end's
// ways on, the Learn theme's first open puzzle, home's setup, or home. Returns whether
// anything on screen changed.
fn tutorial_screen(sh: Shell&, g: gui::Gui&, area: float4, now: f64) -> bool {
    let ls .= sh.lesson;
    var l = tutorial_layout(sh, area, g.scale, now);
    sh.out.layout = l.board;
    let ev, changed = tutorial::frame(ls, g, l, area, gui::bleed(g, area, area), now, sh.out.over);
    aimed(sh, l, ls.cam, now);
    let v = clamp(ls.variant as i64, 0, rules::VARIANT_COUNT - 1);
    if ev.learned > sh.prefs.learned[v] {
        sh.prefs.learned[v] = ev.learned;
        sh.changed = true;
    }
    match ev.go {
        tutorial::BACK => {
            go_up(sh, sh.lesson_from, now);
        },
        tutorial::SETTINGS => {
            open_settings(sh, TUTORIAL, now);
        },
        tutorial::PUZZLES => {
            load_set(sh);
            var i = picker::first_open(sh.prefs.stars[puzzles::loaded], puzzles::LEARN);
            if i < 0 { i = picker::level_nth(puzzles::LEARN, 0, 0); }
            if i >= 0 { play_puzzle(sh, i, now); } else { go_to(sh, PICKER, now); }
        },
        tutorial::NEW_GAME => {
            go_to(sh, HOME, now);
            sh.setup = home::NEW_GAME;
        },
        tutorial::HOME => {
            go_up(sh, HOME, now);
        },
        _ => {},
    }
    return changed || ev.go != tutorial::STAY;
}
