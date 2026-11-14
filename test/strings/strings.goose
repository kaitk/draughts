// The string table (strings/): every language file has every key and nothing else, so
// a key missing from a translation fails here rather than showing English on screen; the
// checker finds each kind of mistake; the runs of keys code steps through by offset
// (MARK_ONLY + 2 * mark) hold together in en.txt, whose order makes the constants
// (scripts/strings_keys.py); and the language is picked from the system's preferred
// locales, English when none has a file.
import std;
import strings from "../../strings";

// Keys from `first` every `stride`, as code steps through them, against their names.
fn run(first: i64, stride: i64, names: const u8[:][:]) -> i64 {
    var wrong = 0;
    for name, i in names {
        let k = first + stride * i;
        if k >= strings::COUNT || strings::KEYS[k] != name {
            print("key ", k, " isn't ", name);
            wrong++;
        }
    }
    return wrong;
}

fn main() {
    var bad = 0;
    // Each language's file: none missing, none unknown, none twice.
    for code, lang in strings::LANGUAGES {
        var out: u8[>..] = [];
        let n = strings::problems(strings::file(lang), out);
        print(code, ": ", strings::COUNT, " keys, ", n, " problems");
        if n > 0 { print(out); }
        bad += n;
    }
    // The checker itself, on a file with a missing key, an unknown one, one given twice,
    // and a line that isn't key = text.
    var out:    u8[>..] = [];
    var sample: u8[>..] = [];
    sample.append(strings::file(strings::EN));
    let cut = find(sample, "home.puzzles");
    var broken: u8[>..] = [];
    broken.append(sample[..cut]);
    broken.append("home.puzzle = Puzzles\napp.name = Again\nno text here\n");
    let at = find(sample[cut..], "\n");
    broken.append(sample[cut + at + 1..]);
    let n = strings::problems(broken, out);
    print("a broken file: ", n, " problems");
    print(out);
    // The runs code steps through by offset.
    assert(strings::KEYS.len == strings::COUNT);
    var wrong = run(strings::PICK_EASY, 1, ["pick.easy", "pick.medium", "pick.hard"]);
    wrong += run(strings::MARK_ONLY, 2, ["mark.only", "mark.best", "mark.good", "mark.inaccuracy", "mark.mistake", "mark.blunder"]);
    wrong += run(strings::MARK_ONLY_TIP, 2, ["mark.only_tip", "mark.best_tip", "mark.good_tip", "mark.inaccuracy_tip",
                                             "mark.mistake_tip", "mark.blunder_tip"]);
    wrong += run(strings::HOW_STEP, 3, ["how.move", "how.jump", "how.must", "how.chain", "how.most", "how.any",
                                        "how.king", "how.fly", "how.afar", "how.way", "how.win"]);
    wrong += run(strings::HOW_STEP + 1, 3, ["how.move_line", "how.jump_line", "how.must_line", "how.chain_line",
                                            "how.most_line", "how.any_line", "how.king_line", "how.fly_line",
                                            "how.afar_line", "how.way_line", "how.win_line"]);
    wrong += run(strings::HOW_STEP + 2, 3, ["how.move_well", "how.jump_well", "how.must_well", "how.chain_well",
                                            "how.most_well", "how.any_well", "how.king_well", "how.fly_well",
                                            "how.afar_well", "how.way_well", "how.win_well"]);
    wrong += run(strings::MONTH_JAN, 1, ["month.jan", "month.feb", "month.mar", "month.apr", "month.may", "month.jun",
                                         "month.jul", "month.aug", "month.sep", "month.oct", "month.nov", "month.dec"]);
    wrong += run(strings::REPLAY_TAKE, 1, ["replay.take_white", "replay.take_black"]);
    wrong += run(strings::REPLAY_ONE, 1, ["replay.one_white", "replay.one_black"]);
    print("runs stepped through by offset: ", wrong, " wrong");
    print("the languages' own names: ", strings::name_of(strings::EN), ", ", strings::name_of(strings::ET));
    bad += wrong;
    // The strings each language shows.
    for code, lang in strings::LANGUAGES {
        strings::use(lang);
        print(code, ": ", strings::get(strings::APP_NAME), " / ",
              strings::get(strings::HOME_CONTINUE), " / ", strings::get(strings::HINTS_MOVES));
    }
    // Numbers filled into a string, each {} in turn.
    for code, lang in strings::LANGUAGES {
        strings::use(lang);
        var goal:  u8[..64] = [];
        var stars: u8[..64] = [];
        strings::fill_in(goal, strings::GOAL_TAKE, [2]);
        strings::fill_in(stars, strings::PUZZLES_STARS, [23, 90]);
        print(code, ": ", goal, " / ", stars);
    }
    // Picking the language.
    for locales in ["et-EE,en-US", "en-GB", "de-DE,et", "ET_ee", "fi-FI,sv-SE", ""] {
        print("locales \"", locales, "\": ", strings::LANGUAGES[strings::pick(locales)]);
    }
    if bad > 0 { exit(1); }
}
