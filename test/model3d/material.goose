// The raised board's material (looks::of, task 080): each season's look for Auto, Wood,
// Stone, and Carved, as the flags of 03's table pick them, so the settings' choice shows
// the board a tuning run of board3d or the app shows. Auto is the season's own look,
// the one it had before the choice (autumn's wood, winter's stone, spring's carved, and
// summer's wood), and a material the file doesn't know is Auto too.
import std;
import vec;
import model3d from "../../src/model3d";

let SEASONS = ["autumn", "winter", "spring", "summer"];
let MATERIALS = ["auto", "wood", "stone", "carved"];

fn main() {
    // The same looks the flags give: --autumn N, --winter N, --spring N, --summer N.
    let flags = [[looks::autumn_look(0), looks::autumn_look(0), looks::autumn_look(3), looks::autumn_look(2)],
                 [looks::winter_look(0), looks::winter_look(1), looks::winter_look(0), looks::winter_look(2)],
                 [looks::shown(looks::SPRING, looks::SPRING_LOOK), looks::shown(looks::SPRING, 0),
                  looks::shown(looks::SPRING, 3), looks::shown(looks::SPRING, 1)],
                 [looks::summer_look(0), looks::summer_look(0), looks::summer_look(6), looks::summer_look(4)]];
    var line: u8[>..] = [];
    for name, s in SEASONS {
        line.clear();
        format(line, name, ":");
        for m in looks::MATERIALS {
            let look = looks::of(s, m);
            format(line, " ", MATERIALS[m], " ", look, if look == flags[s][m] { "" } else { " (not the flag's)" });
        }
        print(line);
    }
    print("an unknown material is auto: ", looks::of(looks::WINTER, 7) == looks::of(looks::WINTER, looks::MATERIAL_AUTO),
          ", ", looks::of(looks::SPRING, -1) == looks::SPRING_ELVEN);
    // Each look's photograph is its season's, so a material never brings another season's
    // light.
    var same = true;
    for s in 4 { for m in looks::MATERIALS { if looks::get(looks::of(s, m)).photo != s { same = false; } } }
    print("every look keeps its season's photograph: ", same);
}
