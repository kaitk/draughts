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
    "settings.theme", "settings.by_date", "settings.board", "settings.hints", "settings.kings",
    "season.winter", "season.spring", "season.summer", "season.autumn",
    "hints.mistakes", "hints.moves",
    "board.flat", "board.flat_note", "board.raised", "board.raised_note",
    "kings.auto", "kings.crown", "kings.stack",
    "tutorial.learn",
    "nav.back", "game.start_over", "game.undo_move",
    "turn.white", "turn.black", "won.white", "won.black",
    "setup.draughts", "setup.level", "setup.color", "setup.clock", "setup.play",
    "variant.international", "variant.brazilian", "variant.russian", "size.10", "size.8",
    "pick.easy", "pick.medium", "pick.hard",
    "color.white", "color.black",
    "clock.none", "clock.blitz", "clock.blitz_note", "clock.rapid", "clock.rapid_note",
    "puzzles.stars", "puzzle.next", "puzzle.try_again", "puzzle.solved",
    "goal.take", "goal.crown", "goal.win", "goal.safe",
    "players.who", "players.new", "players.picture", "players.name", "players.start_again", "players.remove",
    "players.hold",
    "goal.take_one", "puzzle.white_to_move", "puzzle.black_to_move",
    "theme.learn", "theme.captures", "theme.crowning", "theme.shots", "theme.king_shots", "theme.safe_move",
    "puzzles.level1", "puzzles.level2", "puzzles.level3", "puzzles.locked",
    "board.preparing",
    "draw", "draw.repeat", "draw.kings", "draw.balance", "draw.lone",
    "count.draw", "count.draw_one", "count.white", "count.white_one", "count.black", "count.black_one",
    "count.twice", "count.third", "count.short", "count.repeated",
    "settings.privacy",
    "game.lookout", "game.hint", "game.where_to",
    "puzzles.for_now",
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
let SETTINGS_THEME = 13;
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
let KINGS_CROWN = 29;
let KINGS_STACK = 30;
let TUTORIAL_LEARN = 31;
let NAV_BACK = 32;
let GAME_START_OVER = 33;
let GAME_UNDO_MOVE = 34;
let TURN_WHITE = 35;
let TURN_BLACK = 36;
let WON_WHITE = 37;
let WON_BLACK = 38;
let SETUP_DRAUGHTS = 39;
let SETUP_LEVEL = 40;
let SETUP_COLOR = 41;
let SETUP_CLOCK = 42;
let SETUP_PLAY = 43;
let VARIANT_INTERNATIONAL = 44;
let VARIANT_BRAZILIAN = 45;
let VARIANT_RUSSIAN = 46;
let SIZE_10 = 47;
let SIZE_8 = 48;
let PICK_EASY = 49;
let PICK_MEDIUM = 50;
let PICK_HARD = 51;
let COLOR_WHITE = 52;
let COLOR_BLACK = 53;
let CLOCK_NONE = 54;
let CLOCK_BLITZ = 55;
let CLOCK_BLITZ_NOTE = 56;
let CLOCK_RAPID = 57;
let CLOCK_RAPID_NOTE = 58;
let PUZZLES_STARS = 59;     // stars won of those there are: "{} / {}"
let PUZZLE_NEXT = 60;
let PUZZLE_TRY_AGAIN = 61;
let PUZZLE_SOLVED = 62;
let GOAL_TAKE = 63;         // "{}", the men to win, more than one
let GOAL_CROWN = 64;
let GOAL_WIN = 65;
let GOAL_SAFE = 66;
let PLAYERS_WHO = 67;
let PLAYERS_NEW = 68;
let PLAYERS_PICTURE = 69;
let PLAYERS_NAME = 70;
let PLAYERS_START_AGAIN = 71;
let PLAYERS_REMOVE = 72;
let PLAYERS_HOLD = 73;      // under start again and remove: how they are done
let GOAL_TAKE_ONE = 74;     // one man to win
let PUZZLE_WHITE_TO_MOVE = 75;
let PUZZLE_BLACK_TO_MOVE = 76;
let THEME_LEARN = 77;       // the themes' names, in puzzles::THEME_NAMES' order
let THEME_CAPTURES = 78;
let THEME_CROWNING = 79;
let THEME_SHOTS = 80;
let THEME_KING_SHOTS = 81;
let THEME_SAFE_MOVE = 82;
let PUZZLES_LEVEL1 = 83;    // a theme's levels: easy, harder, hardest
let PUZZLES_LEVEL2 = 84;
let PUZZLES_LEVEL3 = 85;
let PUZZLES_LOCKED = 86;    // "{}", the puzzles still to solve in Learn to open a theme
let BOARD_PREPARING = 87;   // where the 3D board goes while it gets ready
let DRAW = 88;              // a drawn game's word, where "White wins" goes
let DRAW_REPEAT = 89;       // why, on the draw's card
let DRAW_KINGS = 90;        // "{}", each side's moves the count was of
let DRAW_BALANCE = 91;      // "{}", likewise
let DRAW_LONE = 92;
let COUNT_DRAW = 93;        // the countdown under whose turn: "{}" moves, more than one
let COUNT_DRAW_ONE = 94;
let COUNT_WHITE = 95;       // the strong side must take the lone king within "{}" of its moves
let COUNT_WHITE_ONE = 96;
let COUNT_BLACK = 97;
let COUNT_BLACK_ONE = 98;
let COUNT_TWICE = 99;       // the position has come twice
let COUNT_THIRD = 100;      // under it: a third time draws
let COUNT_SHORT = 101;      // the short form between the clocks: over or before the moves left
let COUNT_REPEATED = 102;   // and before "2/3" for the position come twice
let SETTINGS_PRIVACY = 103; // the privacy note at the end of settings' game group
let GAME_LOOKOUT = 104;     // the lookout's toggle: the threats past the player's sight
let GAME_HINT = 105;        // the hint's tile
let GAME_WHERE_TO = 106;    // and its word once it has lit the piece to move
let PUZZLES_FOR_NOW = 107; // under the puzzles' title while a draughts shows another's set (picker::note_of)
let COUNT = 108;

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

// The string for a key into out, each {} in it replaced by the next of `numbers`.
fn fill_in(out: u8[..64]&, k: i64, numbers: const i64[:]) {
    out.clear();
    var rest = table[k];
    var n = 0;
    while rest.len > 0 {
        if rest.len >= 2 && rest[0] == '{' && rest[1] == '}' && n < numbers.len {
            var digits: u8[..20] = [];
            var x = max(numbers[n], 0);
            if x == 0 { digits.push('0'); }
            while x > 0 {
                digits.push(('0' + x % 10) as u8);
                x /= 10;
            }
            for i in digits.len { if out.len < 64 { out.push(digits[digits.len - 1 - i]); } }
            n++;
            rest = rest[2..];
            continue;
        }
        if out.len < 64 { out.push(rest[0]); }
        rest = rest[1..];
    }
}

// A key's text in a language, as its file gives it, whichever language is current; ""
// when the file lacks the key.
fn text_of(lang: i64, k: i64) -> const u8[:] {
    var text = file(lang);
    while text.len > 0 {
        let line, rest = next_line(text);
        text = rest;
        let name, value, ok = entry(line);
        if ok && name == KEYS[k] { return value; }
    }
    return "";
}

// A language's own name, as its file gives it, whichever language is current.
fn name_of(lang: i64) -> const u8[:] {
    let name = text_of(lang, LANGUAGE_NAME);
    return if name.len > 0 { name } else { LANGUAGES[lang] };
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
