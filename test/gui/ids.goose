// The widget ids' ranges (gui::IDS, gui::IDS_SPAN): each screen numbers its widgets from
// its base, and a transition declares two screens in one frame, so two ranges that run
// into each other would let one screen's widget take another's press. Each range is
// listed with where it ends, and a range that runs into the next fails. The puzzles to
// pick from number a theme's puzzles from 400 past their base, so the largest theme of
// every variant's set must fit what is left of the range.
import std;
import vec;
import rules from "../../src/rules";
import gui from "../../src/gui";
import puzzles from "../../src/puzzles";

fn main() {
    let names = ["panel", "card", "home", "settings", "who", "picker", "games", "scroll"];
    assert(names.len == gui::IDS.len && gui::IDS_SPAN.len == gui::IDS.len);
    var wrong = 0;
    for base, i in gui::IDS {
        let end = base + gui::IDS_SPAN[i];
        print(names[i], ": ", base, " to ", end - 1);
        if i + 1 < gui::IDS.len && end > gui::IDS[i + 1] {
            print("  runs into ", names[i + 1], "'s");
            wrong++;
        }
    }
    var most = 0;
    for v in [rules::INTERNATIONAL, rules::BRAZILIAN, rules::RUSSIAN] {
        guard puzzles::load(v as u8) else { abort("the puzzles don't load"); }
        for t in puzzles::THEMES { most = max(most, puzzles::theme_count(puzzles::all, t)); }
    }
    let room = gui::IDS_SPAN[5] - 400;
    print("the largest theme: ", most, " puzzles, room for ", room);
    if most > room { wrong++; }
    print(if wrong == 0 { "no range runs into another" } else { "ranges run into each other" });
    if wrong > 0 { exit(1); }
}
