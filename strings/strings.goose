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
    "home.continue", "setup.friend", "home.new_game", "home.puzzles", "home.settings",
    "level.easy", "level.medium", "level.hard",
    "settings.game", "settings.look", "settings.tutorial",
    "settings.theme", "settings.by_date", "settings.board", "settings.hints", "settings.kings",
    "season.winter", "season.spring", "season.summer", "season.autumn",
    "hints.mistakes", "hints.moves",
    "board.flat", "board.raised",
    "kings.auto", "kings.crown", "kings.stack",
    "tutorial.learn",
    "nav.back", "game.start_over", "game.undo_move",
    "turn.white", "turn.black", "won.white", "won.black",
    "setup.draughts", "setup.against", "setup.color", "setup.clock", "setup.play",
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
    "home.quit",
    "continue.friend", "continue.easy", "continue.medium", "continue.hard",
    "settings.moves", "moves.hidden", "moves.list", "moves.marks",
    "results.title", "results.rating", "results.computer", "results.friend", "results.none",
    "moves.none",
    "board.turns", "board.turns_note",
    "quit.ask", "quit.cancel",
    "moves.hidden_note", "moves.list_note", "moves.marks_note",
    "mark.only", "mark.only_tip",
    "mark.best", "mark.best_tip",
    "mark.good", "mark.good_tip",
    "mark.inaccuracy", "mark.inaccuracy_tip",
    "mark.mistake", "mark.mistake_tip",
    "mark.blunder", "mark.blunder_tip",
    "replay.title", "replay.no_count", "replay.start",
    "replay.play",
    "board.stays", "board.stays_note", "setup.board", "level.friend",
    "settings.background", "background.photo", "background.plain",
    "material.wood", "material.stone", "material.carved", "material.auto",
];
let LANGUAGE_NAME = 0;
let APP_NAME = 1;
let HOME_CONTINUE = 2;
let SETUP_FRIEND = 3;       // the setup's first tile to play against
let HOME_NEW_GAME = 4;
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
let BOARD_RAISED = 25;
let KINGS_AUTO = 26;
let KINGS_CROWN = 27;
let KINGS_STACK = 28;
let TUTORIAL_LEARN = 29;
let NAV_BACK = 30;
let GAME_START_OVER = 31;
let GAME_UNDO_MOVE = 32;
let TURN_WHITE = 33;
let TURN_BLACK = 34;
let WON_WHITE = 35;
let WON_BLACK = 36;
let SETUP_DRAUGHTS = 37;
let SETUP_AGAINST = 38;     // the setup's first row: a friend, or the computer at a level
let SETUP_COLOR = 39;
let SETUP_CLOCK = 40;
let SETUP_PLAY = 41;
let VARIANT_INTERNATIONAL = 42;
let VARIANT_BRAZILIAN = 43;
let VARIANT_RUSSIAN = 44;
let SIZE_10 = 45;
let SIZE_8 = 46;
let PICK_EASY = 47;
let PICK_MEDIUM = 48;
let PICK_HARD = 49;
let COLOR_WHITE = 50;
let COLOR_BLACK = 51;
let CLOCK_NONE = 52;
let CLOCK_BLITZ = 53;
let CLOCK_BLITZ_NOTE = 54;
let CLOCK_RAPID = 55;
let CLOCK_RAPID_NOTE = 56;
let PUZZLES_STARS = 57;     // stars won of those there are: "{} / {}"
let PUZZLE_NEXT = 58;
let PUZZLE_TRY_AGAIN = 59;
let PUZZLE_SOLVED = 60;
let GOAL_TAKE = 61;         // "{}", the men to win, more than one
let GOAL_CROWN = 62;
let GOAL_WIN = 63;
let GOAL_SAFE = 64;
let PLAYERS_WHO = 65;
let PLAYERS_NEW = 66;
let PLAYERS_PICTURE = 67;
let PLAYERS_NAME = 68;
let PLAYERS_START_AGAIN = 69;
let PLAYERS_REMOVE = 70;
let PLAYERS_HOLD = 71;      // under start again and remove: how they are done
let GOAL_TAKE_ONE = 72;     // one man to win
let PUZZLE_WHITE_TO_MOVE = 73;
let PUZZLE_BLACK_TO_MOVE = 74;
let THEME_LEARN = 75;       // the themes' names, in puzzles::THEME_NAMES' order
let THEME_CAPTURES = 76;
let THEME_CROWNING = 77;
let THEME_SHOTS = 78;
let THEME_KING_SHOTS = 79;
let THEME_SAFE_MOVE = 80;
let PUZZLES_LEVEL1 = 81;    // a theme's levels: easy, harder, hardest
let PUZZLES_LEVEL2 = 82;
let PUZZLES_LEVEL3 = 83;
let PUZZLES_LOCKED = 84;    // "{}", the puzzles still to solve in Learn to open a theme
let BOARD_PREPARING = 85;   // where the 3D board goes while it gets ready
let DRAW = 86;              // a drawn game's word, where "White wins" goes
let DRAW_REPEAT = 87;       // why, on the draw's card
let DRAW_KINGS = 88;        // "{}", each side's moves the count was of
let DRAW_BALANCE = 89;      // "{}", likewise
let DRAW_LONE = 90;
let COUNT_DRAW = 91;        // the countdown under whose turn: "{}" moves, more than one
let COUNT_DRAW_ONE = 92;
let COUNT_WHITE = 93;       // the strong side must take the lone king within "{}" of its moves
let COUNT_WHITE_ONE = 94;
let COUNT_BLACK = 95;
let COUNT_BLACK_ONE = 96;
let COUNT_TWICE = 97;       // the position has come twice
let COUNT_THIRD = 98;       // under it: a third time draws
let COUNT_SHORT = 99;       // the short form between the clocks: over or before the moves left
let COUNT_REPEATED = 100;   // and before "2/3" for the position come twice
let SETTINGS_PRIVACY = 101; // the privacy note at the end of settings' game group
let GAME_LOOKOUT = 102;     // the lookout's toggle: the threats past the player's sight
let GAME_HINT = 103;        // the hint's tile
let GAME_WHERE_TO = 104;    // and its word once it has lit the piece to move
let HOME_QUIT = 105;        // a desktop's way out on home, the last row
let CONTINUE_FRIEND = 106;  // continue's note: whose game it goes back to (home::menu)
let CONTINUE_EASY = 107;    // the computer's, at each level
let CONTINUE_MEDIUM = 108;
let CONTINUE_HARD = 109;
let SETTINGS_MOVES = 110;   // the moves panel's row (task 074): hidden, the list, or the list with marks
let MOVES_HIDDEN = 111;
let MOVES_LIST = 112;
let MOVES_MARKS = 113;
let RESULTS_TITLE = 114;    // the results screen (task 074): its title,
let RESULTS_RATING = 115;   // the rating's heading,
let RESULTS_COMPUTER = 116; // the levels' results' heading,
let RESULTS_FRIEND = 117;   // a game against a friend in the list,
let RESULTS_NONE = 118;     // and the list with no game yet
let MOVES_NONE = 119;       // the moves panel before the first move
let BOARD_TURNS = 120;      // a friend's setup: the board turns to who plays,
let BOARD_TURNS_NOTE = 121; // its note
let QUIT_ASK = 122;         // a desktop's quit asks first (home::ask_quit): the question,
let QUIT_CANCEL = 123;      // and the button that keeps the app open
let MOVES_HIDDEN_NOTE = 124; // settings' move list: what the chosen tile shows, under the row
let MOVES_LIST_NOTE = 125;
let MOVES_MARKS_NOTE = 126;
let MARK_ONLY = 127;  // a mark's word (the list's legend), then its _TIP line (the popover); in ai::judge's order from ONLY
let MARK_ONLY_TIP = 128;
let MARK_BEST = 129;
let MARK_BEST_TIP = 130;
let MARK_GOOD = 131;
let MARK_GOOD_TIP = 132;
let MARK_INACCURACY = 133;
let MARK_INACCURACY_TIP = 134;
let MARK_MISTAKE = 135;
let MARK_MISTAKE_TIP = 136;
let MARK_BLUNDER = 137;
let MARK_BLUNDER_TIP = 138;
let REPLAY_TITLE = 139;     // a past game's replay (task 078): its title,
let REPLAY_NO_COUNT = 140;  // the label on a game played from a replay's move, which counts for nothing,
let REPLAY_START = 141;     // the line over its list at the start, before the first move,
let REPLAY_PLAY = 142;      // and its button that plays on from the move shown (2026-11-13)
let BOARD_STAYS = 143;      // or stays, the same for both,
let BOARD_STAYS_NOTE = 144; // its note,
let SETUP_BOARD = 145;      // and the row's name
let LEVEL_FRIEND = 146;     // home's new game's note for a friend, as LEVEL_EASY.. for the computer
let SETTINGS_BACKGROUND = 147; // settings' Background row (task 080): the photograph or the plain fade,
let BACKGROUND_PHOTO = 148;
let BACKGROUND_PLAIN = 149;
let MATERIAL_WOOD = 150;    // the raised board's materials, its Board row's tiles after Flat and Raised,
let MATERIAL_STONE = 151;
let MATERIAL_CARVED = 152;
let MATERIAL_AUTO = 153;    // and the tag on Raised, the theme's own board
let COUNT = 154;

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
