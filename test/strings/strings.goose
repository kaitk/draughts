// The string table (strings/): every language file has every key and nothing else, so
// a key missing from a translation fails here rather than showing English on screen; the
// checker finds each kind of mistake; the key constants name the keys they should; and
// the language is picked from the system's preferred locales, English when none has a
// file.
import std;
import strings from "../../strings";

let NAMED = [
    "language.name", "app.name", "home.continue", "home.friend", "home.computer",
    "home.puzzles", "home.settings", "level.easy", "level.medium",
    "level.hard", "settings.background", "settings.by_date", "settings.board",
    "settings.hints", "settings.kings", "season.winter", "season.spring",
    "season.summer", "season.autumn", "hints.mistakes", "hints.moves", "board.flat",
    "board.raised", "settings.game", "settings.look", "settings.tutorial", "board.flat_note",
    "board.raised_note", "kings.auto", "kings.crown", "kings.stack",
    "tutorial.learn", "players.who", "players.new", "players.picture", "players.name", "players.start_again",
    "players.remove", "players.hold",
];

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
    // The constants name the keys they index.
    assert(strings::KEYS.len == strings::COUNT);
    let ks = [strings::LANGUAGE_NAME, strings::APP_NAME, strings::HOME_CONTINUE,
              strings::HOME_FRIEND, strings::HOME_COMPUTER, strings::HOME_PUZZLES,
              strings::HOME_SETTINGS, strings::LEVEL_EASY,
              strings::LEVEL_MEDIUM, strings::LEVEL_HARD, strings::SETTINGS_BACKGROUND,
              strings::SETTINGS_BY_DATE, strings::SETTINGS_BOARD, strings::SETTINGS_HINTS,
              strings::SETTINGS_KINGS, strings::SEASON_WINTER, strings::SEASON_SPRING,
              strings::SEASON_SUMMER, strings::SEASON_AUTUMN, strings::HINTS_MISTAKES,
              strings::HINTS_MOVES, strings::BOARD_FLAT, strings::BOARD_RAISED,
              strings::SETTINGS_GAME, strings::SETTINGS_LOOK, strings::SETTINGS_TUTORIAL,
              strings::BOARD_FLAT_NOTE, strings::BOARD_RAISED_NOTE, strings::KINGS_AUTO,
              strings::KINGS_CROWN, strings::KINGS_STACK,
              strings::TUTORIAL_LEARN, strings::PLAYERS_WHO, strings::PLAYERS_NEW, strings::PLAYERS_PICTURE,
              strings::PLAYERS_NAME, strings::PLAYERS_START_AGAIN, strings::PLAYERS_REMOVE, strings::PLAYERS_HOLD];
    var wrong = 0;
    for k, i in ks {
        if strings::KEYS[k] != NAMED[i] {
            print("constant ", i, " names ", strings::KEYS[k], ", not ", NAMED[i]);
            wrong++;
        }
    }
    print("constants: ", ks.len, " checked, ", wrong, " wrong");
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
