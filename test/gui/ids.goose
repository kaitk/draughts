// The widget ids' ranges (gui::IDS, gui::IDS_SPAN): each screen numbers its widgets from
// its base, and a transition declares two screens in one frame, so two ranges that run
// into each other would let one screen's widget take another's press. Each range is
// listed with where it ends, and a range that runs into the next fails. Inside a range a
// screen names its ids each on from the one before by as many as it takes, so none meet;
// its last, IDS_END, must not pass the range's end (the puzzles to pick from end with a
// tile for every puzzle a set may hold).
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

fn main() {
    let names = ["panel", "card", "home", "settings", "who", "picker", "games", "replay", "tutorial", "scroll"];
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
    // Each screen's named ids against its range, by its place in gui::IDS.
    let ends = [home::IDS_END, settings::IDS_END, who::IDS_END, picker::IDS_END, results::IDS_END, replay::IDS_END,
                tutorial::IDS_END];
    let ranges = [2, 3, 4, 5, 6, 7, 8];
    for e, k in ends {
        let i = ranges[k];
        let end = gui::IDS[i] + gui::IDS_SPAN[i];
        print(names[i], ": its named ids take ", e - gui::IDS[i], " of ", gui::IDS_SPAN[i]);
        if e > end {
            print("  past its range");
            wrong++;
        }
    }
    print(if wrong == 0 { "no range runs into another" } else { "ranges run into each other" });
    if wrong > 0 { exit(1); }
}
