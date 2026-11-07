// The user-facing text, looked up by key: each language is a file here, `key = text`
// per line, built into the program. Code names a string by its constant (HOME_CONTINUE)
// and reads it with get(); nothing is copied, the text stays in the embedded file. English
// is the default and fills in any key a translation lacks; the language comes from the
// system's preferred locales (pick()).
namespace strings;
import std;

// The languages, by their codes as locales name them.
let EN = 0;
let ET = 1;
let LANGUAGES = ["en", "et"];

// The keys, as the files name them; the constants below index KEYS.
let KEYS = [
    "language.name", "app.name",
    "home.continue", "home.friend", "home.computer", "home.puzzles", "home.settings",
    "level.easy", "level.medium", "level.hard",
    "settings.game", "settings.look", "settings.tutorial",
    "settings.background", "settings.by_date", "settings.board", "settings.hints", "settings.kings",
    "season.winter", "season.spring", "season.summer", "season.autumn",
    "hints.mistakes", "hints.moves",
    "board.flat", "board.flat_note", "board.raised", "board.raised_note",
    "kings.auto", "kings.auto_note", "kings.crown", "kings.stack",
    "tutorial.learn",
    "game.home", "game.start_over", "game.take_back",
    "turn.white", "turn.black", "won.white", "won.black",
    "setup.draughts", "setup.level", "setup.color", "setup.clock", "setup.play",
    "variant.international", "variant.brazilian", "variant.russian", "size.10", "size.8",
    "pick.easy", "pick.medium", "pick.hard",
    "color.white", "color.black",
    "clock.none", "clock.blitz", "clock.blitz_note", "clock.rapid", "clock.rapid_note",
];
let LANGUAGE_NAME = 0;
let APP_NAME = 1;
let HOME_CONTINUE = 2;
let HOME_FRIEND = 3;
let HOME_COMPUTER = 4;
let HOME_PUZZLES = 5;
let HOME_SETTINGS = 6;
let LEVEL_EASY = 7;
let LEVEL_MEDIUM = 8;
let LEVEL_HARD = 9;
let SETTINGS_GAME = 10;
let SETTINGS_LOOK = 11;
let SETTINGS_TUTORIAL = 12;
let SETTINGS_BACKGROUND = 13;
let SETTINGS_BY_DATE = 14;
let SETTINGS_BOARD = 15;
let SETTINGS_HINTS = 16;
let SETTINGS_KINGS = 17;
let SEASON_WINTER = 18;
let SEASON_SPRING = 19;
let SEASON_SUMMER = 20;
let SEASON_AUTUMN = 21;
let HINTS_MISTAKES = 22;
let HINTS_MOVES = 23;
let BOARD_FLAT = 24;
let BOARD_FLAT_NOTE = 25;
let BOARD_RAISED = 26;
let BOARD_RAISED_NOTE = 27;
let KINGS_AUTO = 28;
let KINGS_AUTO_NOTE = 29;
let KINGS_CROWN = 30;
let KINGS_STACK = 31;
let TUTORIAL_LEARN = 32;
let GAME_HOME = 33;
let GAME_START_OVER = 34;
let GAME_TAKE_BACK = 35;
let TURN_WHITE = 36;
let TURN_BLACK = 37;
let WON_WHITE = 38;
let WON_BLACK = 39;
let SETUP_DRAUGHTS = 40;
let SETUP_LEVEL = 41;
let SETUP_COLOR = 42;
let SETUP_CLOCK = 43;
let SETUP_PLAY = 44;
let VARIANT_INTERNATIONAL = 45;
let VARIANT_BRAZILIAN = 46;
let VARIANT_RUSSIAN = 47;
let SIZE_10 = 48;
let SIZE_8 = 49;
let PICK_EASY = 50;
let PICK_MEDIUM = 51;
let PICK_HARD = 52;
let COLOR_WHITE = 53;
let COLOR_BLACK = 54;
let CLOCK_NONE = 55;
let CLOCK_BLITZ = 56;
let CLOCK_BLITZ_NOTE = 57;
let CLOCK_RAPID = 58;
let CLOCK_RAPID_NOTE = 59;
let COUNT = 60;

// The current language's strings, as views into its file.
var table: const u8[:][COUNT];
var current = EN;

// A language's file, as built into the program.
fn file(lang: i64) -> const u8[:] {
    return if lang == ET { embed_file("et.txt") } else { embed_file("en.txt") };
}

// The index of a key in KEYS, or -1.
fn key(name: const u8[:]) -> i64 {
    for k, i in KEYS { if k == name { return i; } }
    return -1;
}

// The next line of text and what follows it.
fn next_line(text: const u8[:]) -> const u8[:], const u8[:] {
    let line, rest, found = split_once(text, '\n');
    return line, rest;
}

// A line's key and text, or false for a blank line or a comment.
fn entry(line: const u8[:]) -> const u8[:], const u8[:], bool {
    let l = trim(line);
    if l.len == 0 || l[0] == '#' { return l, l, false; }
    let name, text, found = split_once(l, '=');
    return trim(name), trim(text), true;
}

// Makes lang the current language: its strings, and English for any it lacks.
fn use(lang: i64) {
    current = if lang >= 0 && lang < LANGUAGES.len { lang } else { EN };
    for l in [EN, current] {
        var text = file(l);
        while text.len > 0 {
            let line, rest = next_line(text);
            text = rest;
            let name, value, ok = entry(line);
            guard ok else { continue; }
            let k = key(name);
            if k >= 0 { table[k] = value; }
        }
    }
}

// The current language's string for a key (one of the constants above).
fn get(k: i64) -> const u8[:] { return table[k]; }

// A language's own name, as its file gives it, whichever language is current.
fn name_of(lang: i64) -> const u8[:] {
    var text = file(lang);
    while text.len > 0 {
        let line, rest = next_line(text);
        text = rest;
        let name, value, ok = entry(line);
        if ok && name == KEYS[LANGUAGE_NAME] { return value; }
    }
    return LANGUAGES[lang];
}

// The language to use, from the system's preferred locales in order, separated by
// commas ("et-EE,en-US"): the first whose language has a file, else English.
fn pick(locales: const u8[:]) -> i64 {
    var text = locales;
    while text.len > 0 {
        let one, rest, found = split_once(text, ',');
        text = rest;
        var code: u8[..8] = [];
        for c in trim(one) {
            if c == '-' || c == '_' || code.len == 8 { break; }
            code.push(c);
        }
        to_lower(code);
        for name, i in LANGUAGES { if name == code { return i; } }
    }
    return EN;
}

// What is wrong with a language file, appended to out: lines that aren't `key = text`,
// unknown keys, keys given twice, and keys it lacks. Returns how many problems.
fn problems(text: const u8[:], out: u8[>..]&) -> i64 {
    var seen: bool[COUNT] = [false; COUNT];
    var n = 0;
    var rest = text;
    while rest.len > 0 {
        let line, after = next_line(rest);
        rest = after;
        let l = trim(line);
        if l.len == 0 || l[0] == '#' { continue; }
        let name, value, found = split_once(l, '=');
        let k = key(trim(name));
        if !found || trim(value).len == 0 {
            format(out, "  not key = text: ", l, "\n");
            n++;
        } else if k < 0 {
            format(out, "  unknown key: ", trim(name), "\n");
            n++;
        } else if seen[k] {
            format(out, "  given twice: ", trim(name), "\n");
            n++;
        } else {
            seen[k] = true;
        }
    }
    for k in COUNT {
        if !seen[k] {
            format(out, "  missing: ", KEYS[k], "\n");
            n++;
        }
    }
    return n;
}
