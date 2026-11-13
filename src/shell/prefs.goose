// A player's settings, the data behind the settings screen (settings.goose), in its
// namespace: the values and their defaults, and the file they are kept in, read and
// written. They are kept across runs as a small text file per player, one `key = value`
// per line, which the app reads at start and writes after a change (players.goose): the
// player's picture and name, whether they have had the first start, the screen's
// choices but the language, which is the device's, a new game's setup (the opponent,
// and for a friend whether the board turns), the computer's
// skill at each level, which moves after each game against it, how many games ended on
// each level, how many games against it began, and the stars won in each puzzle
// (`stars.international = 1:3 4:2`, by puzzle id, the ids being a set's own, so each
// set's stars are under its variant's name; an older file's `stars` is read as
// International's).
namespace settings;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../../strings";
import ai from "../ai";
import puzzles from "../puzzles";

// The board themes by season, as app/theme.goose numbers them, in the order the tiles
// show the seasons: winter stone, spring birch, summer sunset, autumn wood.
let SEASON_KINDS = [1, 2, 3, 0];
let SEASON_KEYS = [strings::SEASON_WINTER, strings::SEASON_SPRING, strings::SEASON_SUMMER, strings::SEASON_AUTUMN];
let SEASON_NAMES = ["winter", "spring", "summer", "autumn"];
let BY_DATE = -1;
// By the date is the background row's last tile, after the four seasons: wrapped on a
// phone in portrait the seasons keep one row and by the date goes under them, and the
// order is the same at every size, turned or not (2026-11-08).
let BY_DATE_TILE = 4;
let FLAT = 0;                   // the 2D board
let RAISED = 1;                 // the 3D board (task 015)
let SYSTEM = -1;                // the language the system's locales pick
// The raised board's material, as the file names it (`material = auto|wood|stone|carved`,
// task 080), one for every season, numbered as looks::MATERIAL_AUTO..: the season's own
// (auto), or its wood, stone, or carved board. The flat board has none.
let MATERIAL_AUTO = 0;
let MATERIAL_WOOD = 1;
let MATERIAL_STONE = 2;
let MATERIAL_CARVED = 3;
let MATERIAL_NAMES = ["auto", "wood", "stone", "carved"];
// Kings: AUTO, board::CROWN, or board::STACK, as the file names them. Auto is a crown
// on the flat board and a stack on the raised one.
let AUTO = 0;
let KING_NAMES = ["auto", "crown", "stack"];
let KING_KEYS = [strings::KINGS_AUTO, strings::KINGS_CROWN, strings::KINGS_STACK];

// The draughts a new game can be, in the order the setup shows them: the variant, its
// name, and its board; the file names it as rules::VARIANT_NAMES does. International is the default.
let DRAUGHTS = [rules::INTERNATIONAL, rules::BRAZILIAN, rules::RUSSIAN];
let DRAUGHTS_KEYS = [strings::VARIANT_INTERNATIONAL, strings::VARIANT_BRAZILIAN, strings::VARIANT_RUSSIAN];
let DRAUGHTS_SIZES = [strings::SIZE_10, strings::SIZE_8, strings::SIZE_8];
let DEFAULT_DRAUGHTS = rules::INTERNATIONAL;
// The computer's levels (game::EASY..) and the clocks (clock::NONE..), in the file.
let LEVEL_NAMES = ["easy", "medium", "hard"];
let SKILL_KEYS = ["skill_easy", "skill_medium", "skill_hard"];
let PLAYED_KEYS = ["played_easy", "played_medium", "played_hard"];
// The moves panel on the game screen (task 074): hidden, the moves alone, or with their
// marks.
let MOVES_HIDDEN = 0;
let MOVES_LIST = 1;
let MOVES_MARKS = 2;
let MOVES_NAMES = ["hidden", "list", "marks"];
// Where each level started before easy started at 0 (2026-11-09), for a file from
// before `played`: a skill still there has had no games that moved it, and starts
// afresh; one moved from it has had its first games.
let OLD_SKILL = [10, 40, 90];
let CLOCK_NAMES = ["none", "5+3", "10+5"];

struct Settings {
    // The player's picture (players::ANIMALS) and name, up to 12 characters, perhaps
    // none; and whether they have had the first start (task 026).
    picture:          i64           = 0,
    name:             players::Name = [],
    first_start_done: bool          = false,
    season:           i64           = BY_DATE, // a theme (app/theme.goose), or BY_DATE
    plain:            bool          = false,   // the plain fade in place of the photograph (`background = plain`)
    board:            i64           = FLAT,    // the Board row's: flat, or raised (the 3D board)
    material:         i64           = MATERIAL_AUTO, // and the raised board's material
    turns:            bool          = false,   // the setup's: a friend's game turns the board to the side to move (`turn = on`)
    hints:            i64           = board::MISTAKES,
    lookout:          bool          = false,   // the game's lookout, its eye on whose turn's line (`lookout = on`)
    kings:            i64           = AUTO,
    language:         i64           = SYSTEM, // strings::EN.., or SYSTEM; the device's, in settings.txt
    // A new game's setup, kept for the next one: against a friend or the computer
    // (`opponent = friend|computer`, the computer by default), the draughts, the level,
    // the child's pieces, the clock.
    friend:  bool = false,
    variant: i64  = DEFAULT_DRAUGHTS,
    level:   i64  = 0,          // easy (the user's call, 2026-11-09)
    color:   i64  = rules::WHITE, // the child's pieces against the computer
    clock:   i64  = 0,          // none
    // The computer's skill at each level (ai::adapt), the games that ended on each, and
    // the games against it so far.
    skill:  i64[3] = ai::LEVEL_SKILL,
    played: i64[3] = [0; 3],
    games:  i64    = 0,
    // The moves panel (MOVES_*), and the player's rating (ai/rating.goose) and rated games
    // against the computer by draughts (rules::RUSSIAN..), task 074.
    moves:  i64                       = MOVES_MARKS,
    rating: i64[rules::VARIANT_COUNT] = [ai::FIRST_RATING; rules::VARIANT_COUNT],
    rated:  i64[rules::VARIANT_COUNT] = [0; rules::VARIANT_COUNT],
    // The stars won in each puzzle, 1 to 3, by its set's variant (puzzles::set_of) and
    // its id; 0 for one not solved.
    stars: u8[puzzles::MAX_PUZZLES + 1][rules::VARIANT_COUNT] = [[0; puzzles::MAX_PUZZLES + 1]; rules::VARIANT_COUNT],
    // Whether settings' language list is open (settings::head). Not in the file.
    languages_open: bool = false,
}

// How the flat board draws kings: auto is a crown there.
fn king_look(s: Settings) -> i64 { if s.kings == board::STACK { board::STACK } else { board::CROWN } }

// Whether the game is played on the 3D board, chosen in the Board row.
fn raised(s: Settings) -> bool { s.board == RAISED }

// Whether the season's photograph is shown, or the plain fade in its place: with plain
// the app decodes, uploads, and holds no photograph (task 044).
fn photo_shown(s: Settings) -> bool { !s.plain }

// How the 3D board draws kings: auto is a stack of two plain discs there.
fn raised_king_look(s: Settings) -> i64 { if s.kings == board::CROWN { board::CROWN } else { board::STACK } }

// The settings a file holds; what it lacks or doesn't know stays at the default.
fn parse(text: const u8[:]) -> Settings {
    var s = Settings {};
    var skill_read = [false; 3];
    var played_read = [false; 3];
    var rest = text;
    while rest.len > 0 {
        let line, after, found = split_once(rest, '\n');
        rest = after;
        let k, v, ok = split_once(line, '=');
        guard ok else { continue; }
        let key = trim(k);
        let value = trim(v);
        if key == "picture" {
            for name, i in players::ANIMALS { if value == name { s.picture = i; } }
        }
        if key == "name" { players::set_name(s.name, value); }
        if key == "first_start" && value == "done" { s.first_start_done = true; }
        if key == "season" {
            for name, i in SEASON_NAMES { if value == name { s.season = SEASON_KINDS[i]; } }
        }
        if key == "background" && value == "plain" { s.plain = true; }
        if key == "board" && value == "3d" { s.board = RAISED; }
        if key == "material" {
            for name, i in MATERIAL_NAMES { if value == name { s.material = i; } }
        }
        if key == "turn" && value == "on" { s.turns = true; }
        if key == "hints" && value == "moves" { s.hints = board::MOVES; }
        if key == "lookout" && value == "on" { s.lookout = true; }
        if key == "kings" {
            for name, i in KING_NAMES { if value == name { s.kings = i; } }
        }
        if key == "language" {
            for name, i in strings::LANGUAGES { if value == name { s.language = i; } }
        }
        if key == "opponent" && value == "friend" { s.friend = true; }
        if key == "draughts" {
            let v, known = rules::variant_named(value);
            for d in DRAUGHTS { if known && v == d { s.variant = d; } }
        }
        if key == "level" {
            for name, i in LEVEL_NAMES { if value == name { s.level = i; } }
        }
        if key == "color" && value == "black" { s.color = rules::BLACK; }
        if key == "clock" {
            for name, i in CLOCK_NAMES { if value == name { s.clock = i; } }
        }
        // A skill stays within its level's band, as adapting keeps it.
        let n, number = parse_int(value);
        for name, i in SKILL_KEYS {
            if key == name && number {
                s.skill[i] = ai::within(n, i);
                skill_read[i] = true;
            }
        }
        for name, i in PLAYED_KEYS {
            if key == name && number && n >= 0 {
                s.played[i] = n;
                played_read[i] = true;
            }
        }
        if key == "games" && number && n >= 0 { s.games = n; }
        if key == "moves" {
            for name, i in MOVES_NAMES { if value == name { s.moves = i; } }
        }
        let kind, of, has_of = split_once(key, '.');
        let rated_v, rated_known = rules::variant_named(of);
        if has_of && rated_known && number {
            if kind == "rating" { s.rating[rated_v] = max(n, ai::LEAST_RATING); }
            if kind == "rated" && n >= 0 { s.rated[rated_v] = n; }
        }
        var set = -1;
        if key == "stars" { set = rules::INTERNATIONAL; }
        let dot, rest, has_dot = split_once(key, '.');
        let named, known = rules::variant_named(rest);
        if has_dot && dot == "stars" && known { set = named; }
        if set >= 0 {
            for one in split(value, ' ') {
                let a, b, pair = split_once(one, ':');
                let id, ok_id = parse_int(a);
                let won, ok_won = parse_int(b);
                if pair && ok_id && ok_won && id >= 1 && id <= puzzles::MAX_PUZZLES && won >= 1 && won <= 3 {
                    s.stars[set][id] = won as u8;
                }
            }
        }
    }
    // No game has ended on a level, so nothing has moved its skill: it starts where the
    // level starts now (easy moved from 0 to 8 on 2026-11-11).
    for i in 3 {
        if played_read[i] && s.played[i] == 0 { s.skill[i] = ai::level_skill(i); }
    }
    for i in 3 {
        guard skill_read[i] && !played_read[i] else { continue; }
        if s.skill[i] == OLD_SKILL[i] {
            s.skill[i] = ai::level_skill(i);
        } else {
            s.played[i] = ai::FIRST_GAMES;
        }
    }
    return s;
}

// A player's file for settings s, appended to out: all but the language.
fn write(s: Settings, out: u8[>..]&) {
    out.append("picture = ");
    out.append(players::ANIMALS[clamp(s.picture, 0, players::ANIMALS.len - 1)]);
    if s.name.len > 0 {
        out.append("\nname = ");
        out.append(s.name[..]);
    }
    if s.first_start_done { out.append("\nfirst_start = done"); }
    out.append("\nseason = ");
    var season = "by-date";
    for kind, i in SEASON_KINDS { if s.season == kind { season = SEASON_NAMES[i]; } }
    out.append(season);
    out.append(if s.plain { "\nbackground = plain" } else { "\nbackground = photo" });
    out.append(if s.board == RAISED { "\nboard = 3d" } else { "\nboard = 2d" });
    out.append("\nmaterial = ");
    out.append(MATERIAL_NAMES[clamp(s.material, 0, MATERIAL_NAMES.len - 1)]);
    out.append(if s.turns { "\nturn = on" } else { "\nturn = off" });
    out.append(if s.hints == board::MOVES { "\nhints = moves" } else { "\nhints = mistakes" });
    out.append(if s.lookout { "\nlookout = on" } else { "\nlookout = off" });
    out.append("\nkings = ");
    out.append(KING_NAMES[s.kings]);
    out.append(if s.friend { "\nopponent = friend" } else { "\nopponent = computer" });
    out.append("\ndraughts = ");
    for v in DRAUGHTS { if s.variant == v { out.append(rules::VARIANT_NAMES[v]); } }
    out.append("\nlevel = ");
    out.append(LEVEL_NAMES[s.level]);
    out.append(if s.color == rules::BLACK { "\ncolor = black" } else { "\ncolor = white" });
    out.append("\nclock = ");
    out.append(CLOCK_NAMES[s.clock]);
    for name, i in SKILL_KEYS { format(out, "\n", name, " = ", s.skill[i]); }
    for name, i in PLAYED_KEYS { format(out, "\n", name, " = ", s.played[i]); }
    format(out, "\ngames = ", s.games);
    out.append("\nmoves = ");
    out.append(MOVES_NAMES[clamp(s.moves, 0, 2)]);
    for v in rules::VARIANT_COUNT {
        guard s.rated[v] > 0 else { continue; }
        format(out, "\nrating.", rules::VARIANT_NAMES[v], " = ", s.rating[v]);
        format(out, "\nrated.", rules::VARIANT_NAMES[v], " = ", s.rated[v]);
    }
    for set, v in s.stars {
        var first = true;
        for won, id in set {
            guard won > 0 else { continue; }
            if first { format(out, "\nstars.", rules::VARIANT_NAMES[v], " = "); }
            else { out.append(" "); }
            format(out, id, ":", won);
            first = false;
        }
    }
    out.append("\n");
}
