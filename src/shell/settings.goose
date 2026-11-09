// Settings (prototypes/settings.html; rendering.md, "Settings"): back and the title,
// the language at the title row's right end, and the choices as words in two glass
// groups by what they change. Game: the draughts a new game starts on (the setup's
// choice too) and move hints; the tutorial's row comes with the tutorial (task 026).
// Look: the theme (one season, or by the date; and under its name a two-part switch,
// the season's photograph or the plain fade in its place), the board (flat or raised),
// and the kings (auto, crown, or stack). Beside them is home's board as the choices make it: its size, the
// kings, and what the move hints show, on a fixed position. In landscape the choices
// take the width they need at the left and the board the rest (near square, each
// setting's name above its tiles, so the rows fit the height); in portrait the board is
// on top and the groups stand side by side under it, each setting's name above its
// tiles. Where the groups don't fit so (a phone), one shows at a time: two tiles, Game
// and Look, choose which, in the title row in landscape and under it in portrait. A
// tap applies at once; there is no save button. The game's group also holds the privacy
// note (`note_lines`), beside its title or at its foot.
//
// The values are kept across runs as a small text file per player, one `key = value`
// per line, which the app reads at start and writes after a change (players.goose): the
// player's picture and name, whether they have had the first start, the choices here
// but the language, which is the device's, a new game's setup, the computer's skill at
// each level, which moves after each game against it, how many games ended on each
// level, how many games against it began, and
// the stars won in each puzzle (`stars.international = 1:3 4:2`, by puzzle id, the ids
// being a set's own, so each set's stars are under its variant's name; an older file's
// `stars` is read as International's).
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
// Kings: AUTO, board::CROWN, or board::STACK, as the file names them. Auto is a crown
// on the flat board and a stack on the raised one.
let AUTO = 0;
let KING_NAMES = ["auto", "crown", "stack"];
let KING_KEYS = [strings::KINGS_AUTO, strings::KINGS_CROWN, strings::KINGS_STACK];

// The draughts a new game can be, in the order the setup shows them: the variant, its
// name and board, and whether it is offered; the file names it as rules::VARIANT_NAMES
// does. International is the default.
let DRAUGHTS = [rules::INTERNATIONAL, rules::BRAZILIAN, rules::RUSSIAN];
let DRAUGHTS_KEYS = [strings::VARIANT_INTERNATIONAL, strings::VARIANT_BRAZILIAN, strings::VARIANT_RUSSIAN];
let DRAUGHTS_SIZES = [strings::SIZE_10, strings::SIZE_8, strings::SIZE_8];
let DRAUGHTS_ON = [true, true, true];
let DEFAULT_DRAUGHTS = rules::INTERNATIONAL;
// The computer's levels (game::EASY..) and the clocks (clock::NONE..), in the file.
let LEVEL_NAMES = ["easy", "medium", "hard"];
let SKILL_KEYS = ["skill_easy", "skill_medium", "skill_hard"];
let PLAYED_KEYS = ["played_easy", "played_medium", "played_hard"];
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
    hints:            i64           = board::MISTAKES,
    kings:            i64           = AUTO,
    language:         i64           = SYSTEM, // strings::EN.., or SYSTEM; the device's, in settings.txt
    // A new game's setup, kept for the next one.
    variant: i64 = DEFAULT_DRAUGHTS,
    level:   i64 = 0,           // easy (the user's call, 2026-11-09)
    color:   i64 = rules::WHITE, // the child's pieces against the computer
    clock:   i64 = 0,           // none
    // The computer's skill at each level (ai::adapt), the games that ended on each, and
    // the games against it so far.
    skill:  i64[3] = ai::LEVEL_SKILL,
    played: i64[3] = [0; 3],
    games:  i64    = 0,
    // The stars won in each puzzle, 1 to 3, by its set's variant (puzzles::set_of) and
    // its id; 0 for one not solved.
    stars: u8[puzzles::MAX_PUZZLES + 1][rules::VARIANT_COUNT] = [[0; puzzles::MAX_PUZZLES + 1]; rules::VARIANT_COUNT],
    // The group a phone's settings show, 0 the game's or 1 the look's. Not in the file.
    group: i64 = 0,
    // Where the theme's switch was declared last (both halves), for the tests. Not in the
    // file.
    switch_at: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    // How wide the settings' names are at the left of their tiles: NAME_W, or WIDE_NAME_W
    // where the landscape has the width (`frame` sets it each frame). Not in the file.
    name_w: f32 = NAME_W,
}

// What the screen asks for.
let NOTHING = 0;
let BACK = 1;
let CHANGED = 2;
let SHOWN = 3;              // the other group shown (a phone's tabs): drawn again, nothing kept

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
        if key == "hints" && value == "moves" { s.hints = board::MOVES; }
        if key == "kings" {
            for name, i in KING_NAMES { if value == name { s.kings = i; } }
        }
        if key == "language" {
            for name, i in strings::LANGUAGES { if value == name { s.language = i; } }
        }
        if key == "draughts" {
            let v, known = rules::variant_named(value);
            for d, i in DRAUGHTS { if known && v == d && DRAUGHTS_ON[i] { s.variant = d; } }
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
    out.append(if s.hints == board::MOVES { "\nhints = moves" } else { "\nhints = mistakes" });
    out.append("\nkings = ");
    out.append(KING_NAMES[s.kings]);
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

// The preview's position: white to move and bound to capture two, the man on d4 over
// e5 and g5 or the king on h6 over g5 and e5, after black's d6 to e5; the same on every
// board (test/perft.py), where a black piece on f8 would let the king take a third on
// 10 × 10. There it sits a square in from the corner. With all moves d4 is selected and
// its capture shown; with mistakes only a wrong move to c5 flashes and the pieces that
// must capture pulse, then both stay lit and still.
let PREVIEW_WHITE = "a1 c1 e1 g1 b2 f2 h2 c3 e3 d4 h6";
let PREVIEW_BLACK = "b8 d8 h8 a7 c7 b6 e5 g5";
let PREVIEW_KINGS = "h6";

// A square a preview list names ("c3"), k squares in from the corner, as its rules bit.
fn square(v: rules::Variant&, name: const u8[:], k: i64) -> i64 {
    return rules::bit_at(v, name[0] - 'a' + k, name[1] - '1' + k);
}

// The squares a preview list names, as a set of bits.
fn squares(v: rules::Variant&, list: const u8[:], k: i64) -> u64 {
    var bits: u64 = 0;
    var i = 0;
    while i + 1 < list.len {
        bits |= rules::bit(square(v, list[i..i + 2], k));
        i += 3;
    }
    return bits;
}

// Sets b up as the preview of settings s at `now`: the draughts they start a new game
// on, their kings, and what their move hints show.
fn stage(b: board::Board&, s: Settings&, now: f64) {
    b.variant = s.variant as u8;
    let v .= rules::VARIANTS[b.variant];
    let k = (v.size - 8) / 2;
    board::set(b, rules::Position { pieces: [squares(v, PREVIEW_WHITE, k), squares(v, PREVIEW_BLACK, k)],
                                    kings: squares(v, PREVIEW_KINGS, k), side: rules::WHITE, variant: b.variant });
    b.last = rules::Move { from: square(v, "d6", k) as u8, to: square(v, "e5", k) as u8, .. };
    b.has_last = true;
    b.hints = s.hints;
    b.king_look = if raised(s) { raised_king_look(s) } else { king_look(s) };
    b.still = true;
    if s.hints == board::MOVES {
        b.selected = square(v, "d4", k);
    } else {
        board::mistake(b, square(v, "c5", k), now);
    }
}

// The screen's parts, in dp.
let PAD_X = 32.0;
let PAD_Y = 24.0;
// In landscape under a top inset (an iPad's status bar), the page's top padding gives up
// to 12 dp, the bar already keeping the head from the screen's edge: with it both groups
// fit in the 13" and 11" iPad's landscape, 1 and 5 dp short with the full padding
// (2026-11-09).
let TOP_RISE = 12.0;
let HEAD_H = 100.0;         // back (88), the title, and the language's glass round 88 dp tiles
let BACK_W = 88.0;          // back's height, and the tabs'
let HEAD_GAP = 14.0;        // under them in landscape; 16 in portrait, as round the board
let SIDE_GAP = 24.0;        // between the choices and the board in landscape
let GROUP_GAP = 10.0;
let GROUP_PAD = 20.0;       // a group's sides; 12 above, 14 below
let TITLE_H = 34.0;         // a group's icon and title
let NAME_W = 120.0;         // a setting's name, at the left of its tiles (most landscapes)
let NAME_H = 28.0;          // and above them in portrait
let ROW_GAP = 10.0;
let TILE_GAP = 10.0;
let THUMB_W = 62.0;         // a season's thumbnail
let THUMB_H = 40.0;
// The theme's switch, photograph or plain (prototypes/plain.html, take b): two halves
// side by side. Where the name is above the tiles, beside it at the line's right end,
// each half 88 dp square. Where the name is at the left of the tiles (most landscapes),
// under it in the name's column, in the row's 88 dp: two 88 dp halves need 180 dp across
// where the column has 120, and a taller row would leave the tablet's landscape, which
// has 8 dp to spare over its navigation bar, one group at a time (2026-11-09). Where the
// choices' 55% of the page has the width (16:9 and wider), the names' column widens to
// the switch's 180 dp, so each half is 88 dp wide; the rows keep their height.
let SWITCH_GAP = 4.0;
let SWITCH_NAME = 20.0;     // the name's line above the switch in the name's column
let WIDE_NAME_W = 2.0 * 88.0 + SWITCH_GAP; // the names' column as wide as the switch
let SLACK = 0.5;            // px a row may pass its width by without wrapping
// The smallest board the groups side by side may leave in portrait: 45% of the page, as
// on a phone, but no more than 220 dp, 45% of a 553 dp phone's, so a tablet keeps both
// groups down to the 13" iPad's 3:4 with its bars (a 237 dp board; the look's group, 600
// dp tall at half the page, sets the height, the game's with its privacy note being 459).
// A foldable's 206 dp keeps the tabs.
let BOTH_BOARD = 220.0;

// The settings in order, the first two in the game's group, the rest in the look's:
// each one's name, how many tiles, and how tall they are.
let DRAUGHTS_ROW = 0;
let HINTS_ROW = 1;
let THEME_ROW = 2;
let BOARD_ROW = 3;
let KINGS_ROW = 4;
let GAME_ROWS = 2;
let ROW_NAMES = [strings::SETUP_DRAUGHTS, strings::SETTINGS_HINTS,
                 strings::SETTINGS_THEME, strings::SETTINGS_BOARD, strings::SETTINGS_KINGS];
let ROW_TILES = [3, 2, 5, 2, 3];
let ROW_H = [88.0, 88.0, 88.0, 88.0, 88.0]; // the floor for small hands (56 to 72 until 2026-11-08)
let GROUP_ICONS = [gui::TARGET, gui::SUN];
let GROUP_TITLES = [strings::SETTINGS_GAME, strings::SETTINGS_LOOK];

// The rows a group shows: the game's two, and the look's background, board, and kings.
// Row k of a group is `group_row`.
fn group_rows(group: i64) -> i64 { return if group == 0 { GAME_ROWS } else { ROW_TILES.len - GAME_ROWS }; }

fn group_row(group: i64, k: i64) -> i64 { return GAME_ROWS * group + k; }

// The switch's tap ids, photograph and plain, after the rows' (410 + 10 × row + i).
let SWITCH_ID = 460;

// How wide the line of the theme's name and its switch beside it wants to be.
fn switch_line(g: gui::Gui&) -> f32 {
    let u = g.scale;
    return gui::text_width(g, gui::SMALL, strings::get(ROW_NAMES[THEME_ROW])) + (14.0 + 2.0 * 88.0 + SWITCH_GAP) * u;
}

// The theme's switch in r, its halves side by side: the season's photograph and its
// plain fade, the one chosen lit. True when a tap changed s.
fn switch(s: Settings&, g: gui::Gui&, r: float4) -> bool {
    let u = g.scale;
    let w = 0.5 * (r.z - SWITCH_GAP * u);
    let pic = min(THUMB_W * u, w - 12.0 * u);
    var changed = false;
    for k in 2 {
        let half = float4 { r.x + k * (w + SWITCH_GAP * u), r.y, w, r.w };
        let plain = k == 1;
        // The theme shown's photograph (-2) or fade (-3), as the widgets draw them.
        if gui::picture(g, SWITCH_ID + k, half, if plain { -3 } else { -2 }, float2 { pic, pic * THUMB_H / THUMB_W },
                        s.plain == plain) {
            changed = s.plain != plain;
            s.plain = plain;
        }
    }
    return changed;
}

// Tile i of a row's word.
fn word(row: i64, i: i64) -> i64 {
    if row == DRAUGHTS_ROW { return DRAUGHTS_KEYS[i]; }
    if row == HINTS_ROW { return [strings::HINTS_MISTAKES, strings::HINTS_MOVES][i]; }
    if row == THEME_ROW { return if i == BY_DATE_TILE { strings::SETTINGS_BY_DATE } else { SEASON_KEYS[i] }; }
    if row == BOARD_ROW { return [strings::BOARD_FLAT, strings::BOARD_RAISED][i]; }
    return KING_KEYS[i];
}

// Tile i of a row's note under its word, or "".
fn note(row: i64, i: i64) -> const u8[:] {
    if row == DRAUGHTS_ROW { return strings::get(DRAUGHTS_SIZES[i]); }
    if row == BOARD_ROW { return strings::get([strings::BOARD_FLAT_NOTE, strings::BOARD_RAISED_NOTE][i]); }
    return "";
}

// How wide tile i of a row is: its words with 16 dp either side, at least 88 dp; a
// season's, its thumbnail or label and 6 dp either side, at least 88 dp too.
fn tile_width(g: gui::Gui&, row: i64, i: i64) -> f32 {
    let u = g.scale;
    let label = strings::get(word(row, i));
    if row == THEME_ROW { return max(88.0 * u, max(THUMB_W * u, gui::text_width(g, gui::SMALL, label)) + 12.0 * u); }
    let w = gui::text_width(g, gui::BODY, label);
    return max(88.0 * u, max(w, gui::text_width(g, gui::SMALL, note(row, i))) + 32.0 * u);
}

// Declares tile i of a row in r. True when a tap changed s.
fn tile(s: Settings&, over: game::Overlay&, g: gui::Gui&, row: i64, i: i64, r: float4) -> bool {
    let u = g.scale;
    let id = 410 + 10 * row + i;
    let label = strings::get(word(row, i));
    if row == THEME_ROW {
        let kind = if i == BY_DATE_TILE { BY_DATE } else { SEASON_KINDS[i] };
        // A season's thumbnail: its photograph, or with plain its fade (the widgets' 4 on).
        let pic = if kind >= 0 && s.plain { kind + 4 } else { kind };
        guard gui::choice(g, id, r, pic, float2 { THUMB_W * u, THUMB_H * u }, label, s.season == kind, true)
        else { return false; }
        s.season = kind;
        return true;
    }
    let on = if row == DRAUGHTS_ROW { s.variant == DRAUGHTS[i] } else if row == HINTS_ROW { s.hints == i }
             else if row == BOARD_ROW { s.board == i } else { s.kings == i };
    let enabled = if row == DRAUGHTS_ROW { DRAUGHTS_ON[i] } else { true };
    // The crown's and the stack's tiles each show their king.
    let king = row == KINGS_ROW && i != AUTO;
    let tapped, pic = gui::pick(g, id, r, if king { 34.0 } else { 0.0 }, label, note(row, i), on, enabled);
    if king { game::put(over, pic, 15.0 * u, rules::WHITE, i, 1.0, false); }
    guard tapped else { return false; }
    if row == DRAUGHTS_ROW { s.variant = DRAUGHTS[i]; }
    if row == HINTS_ROW { s.hints = i; }
    if row == BOARD_ROW { s.board = i; }
    if row == KINGS_ROW { s.kings = i; }
    return true;
}

// Lays out a row's tiles from r's top left, wrapping at its width, and declares them
// when `declare`. Returns how tall they are, and whether a tap changed s. A row as wide
// as r, as group_width makes it, doesn't wrap for a rounding difference: SLACK.
fn lay(s: Settings&, over: game::Overlay&, g: gui::Gui&, row: i64, r: float4, declare: bool) -> f32, bool {
    let u = g.scale;
    let h = (ROW_H[row] as f32) * u;
    var x: f32 = 0.0;
    var y: f32 = 0.0;
    var changed = false;
    for i in ROW_TILES[row] {
        let w = min(tile_width(g, row, i), r.z);
        if x > 0.0 && x + w > r.z + SLACK {
            x = 0.0;
            y += h + TILE_GAP * u;
        }
        if declare && tile(s, over, g, row, i, float4 { r.x + x, r.y + y, w, h }) { changed = true; }
        x += w + TILE_GAP * u;
    }
    return y + h, changed;
}

// A group's settings from r's top left, as wide as r, each its dim name and its tiles:
// the name at the left when `aside`, else above them. Declares them when
// `declare`. Returns how tall they are, and whether a tap changed s.
fn rows(s: Settings&, over: game::Overlay&, g: gui::Gui&, group: i64, r: float4, aside: bool,
        declare: bool) -> f32, bool {
    let u = g.scale;
    var y = r.y;
    var changed = false;
    for k in group_rows(group) {
        let row = group_row(group, k);
        if k > 0 { y += ROW_GAP * u; }
        let left = (s.name_w + 14.0) * u;
        // The theme's row: its name on a line of its own, the switch under it at the
        // left of the tiles; or where the name is above the tiles, beside it at the
        // line's right end, the line as tall as the switch.
        let switched = row == THEME_ROW;
        let line: f32 = if switched { (88.0 + SWITCH_GAP) * u } else { NAME_H * u };
        let tiles = if aside { float4 { r.x + left, y, r.z - left, 0.0 } }
                    else { float4 { r.x, y + line, r.z, 0.0 } };
        let h, tapped = lay(s, over, g, row, tiles, declare);
        if declare {
            var name = float4 { r.x, y, s.name_w * u, if aside { h } else { NAME_H * u - 6.0 * u } };
            var sw = float4 { r.x, y + SWITCH_NAME * u, s.name_w * u, (ROW_H[row] as f32 - SWITCH_NAME) * u };
            if switched && aside { name.w = SWITCH_NAME * u; }
            if switched && !aside {
                name = float4 { r.x, y, r.z, 88.0 * u };
                sw = float4 { r.x + r.z - (2.0 * 88.0 + SWITCH_GAP) * u, y, (2.0 * 88.0 + SWITCH_GAP) * u, 88.0 * u };
            }
            gui::text(g, gui::SMALL, name, strings::get(ROW_NAMES[row]), 0.66, 0.03 * gui::FACE_DP[gui::SMALL] as f32 * u,
                      gui::LEFT);
            if switched {
                s.switch_at = sw;
                if switch(s, g, sw) { changed = true; }
            }
        }
        if tapped { changed = true; }
        y += if aside { h } else { line + h };
    }
    return y - r.y, changed;
}

// The privacy note (App Review Guideline 5.1.1(i); store/app-store.md): what the app
// collects, nothing, in the small face and dim as the settings' names, in the game's
// group. At its title row's right end where it fits there in two lines at most (most
// landscapes, where both groups stack and the height is short; one line in English and
// Estonian on the tablet and the iPad), the row as tall as they are; otherwise at the
// glass's foot, wrapped to its width, where the game's group, as tall as the look's
// (portrait, a phone's tabs), has room to spare. No link out: the app opens none.
let NOTE_A = 0.66;
let NOTE_GAP = 24.0;        // between the group's title and the note beside it
let NOTE_BESIDE = 2;        // the most lines the note takes beside the title

// The note wrapped at whole words to r's width, `align`ed in it: how many lines, each a
// small face's height; drawn from r's top when `draw`.
fn note_lines(g: gui::Gui&, r: float4, draw: bool, align: i64 = gui::LEFT) -> i64 {
    let s = strings::get(strings::SETTINGS_PRIVACY);
    let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    var n = 0;
    var start = 0;
    while start < s.len {
        // The most words that fit, or the first alone where none does.
        var end = s.len;
        if gui::text_width(g, gui::SMALL, s[start..]) > r.z {
            var fit = -1;
            var first = -1;
            for i in start..s.len {
                guard s[i] == ' ' else { continue; }
                if first < 0 { first = i; }
                if gui::text_width(g, gui::SMALL, s[start..i]) <= r.z { fit = i; }
            }
            end = if fit >= 0 { fit } else if first >= 0 { first } else { s.len };
        }
        if draw { gui::text(g, gui::SMALL, float4 { r.x, r.y + n * line, r.z, line }, s[start..end], NOTE_A, 0.0, align); }
        n++;
        start = end + 1;
    }
    return n;
}

// How wide the note may be beside the title of a game's group glass w wide.
fn note_room(g: gui::Gui&, w: f32) -> f32 {
    return w - (2.0 * GROUP_PAD + 30.0 + 12.0 + NOTE_GAP) * g.scale
           - gui::text_width(g, gui::HEADING, strings::get(GROUP_TITLES[0]));
}

// How many lines the note takes beside the title of a game's group glass w wide; 0 where
// it goes at the foot.
fn note_beside(g: gui::Gui&, w: f32, titled: bool) -> i64 {
    guard titled else { return 0; }
    let n = note_lines(g, float4 { 0.0, 0.0, note_room(g, w), 0.0 }, false);
    return if n <= NOTE_BESIDE { n } else { 0 };
}

// How tall a group's title row is: as tall as the note beside it, at least TITLE_H.
fn title_height(g: gui::Gui&, group: i64, w: f32) -> f32 {
    let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    let n = if group == 0 { note_beside(g, w, true) } else { 0 };
    return max(TITLE_H * g.scale, n * line);
}

// How tall the note is at the foot of a game's group glass w wide, with the gap above it;
// 0 where it goes in the title row.
fn note_height(g: gui::Gui&, w: f32, titled: bool) -> f32 {
    let u = g.scale;
    guard note_beside(g, w, titled) == 0 else { return 0.0; }
    let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    let n = note_lines(g, float4 { 0.0, 0.0, w - 2.0 * GROUP_PAD * u, 0.0 }, false);
    return ROW_GAP * u + n * line;
}

// How tall a group's glass is at width w; with no title row where a tab names it.
fn group_height(s: Settings&, over: game::Overlay&, g: gui::Gui&, group: i64, w: f32, aside: bool,
                titled: bool = true) -> f32 {
    let u = g.scale;
    let h, unused = rows(s, over, g, group, float4 { 0.0, 0.0, w - 2.0 * GROUP_PAD * u, 0.0 }, aside, false);
    let title: f32 = if titled { title_height(g, group, w) + ROW_GAP * u } else { 0.0 };
    let note:  f32 = if group == 0 { note_height(g, w, titled) } else { 0.0 };
    return (12.0 + 14.0) * u + title + h + note;
}

// How wide a group's glass wants to be with its rows unwrapped, the names at their left
// when `aside`.
fn group_width(s: Settings&, g: gui::Gui&, group: i64, aside: bool) -> f32 {
    let u = g.scale;
    var widest: f32 = 0.0;
    for k in group_rows(group) {
        let row = group_row(group, k);
        var w = -TILE_GAP * u;
        for i in ROW_TILES[row] { w += tile_width(g, row, i) + TILE_GAP * u; }
        widest = max(widest, w);
        // The theme's name and its switch beside it, where the name is above the tiles.
        if row == THEME_ROW && !aside { widest = max(widest, switch_line(g)); }
    }
    let names = if aside { s.name_w + 14.0 } else { 0.0 };
    return widest + (names + 2.0 * GROUP_PAD) * u;
}

// A group's glass in r: its icon and title (unless a tab names it), then its settings.
// Where r reaches the edge of `area`, the safe area, the glass runs on to the screen's.
// True when a tap changed s.
fn group(s: Settings&, over: game::Overlay&, g: gui::Gui&, group: i64, r: float4, area: float4, aside: bool,
         titled: bool = true) -> bool {
    let u = g.scale;
    gui::glass(g, gui::bleed(g, r, area), 24.0);
    var c = float4 { r.x + GROUP_PAD * u, r.y + 12.0 * u, r.z - 2.0 * GROUP_PAD * u, r.w - 26.0 * u };
    if titled {
        var title = gui::cut_top(c, title_height(g, group, r.z));
        gui::cut_top(c, ROW_GAP * u);
        gui::glyph_icon(g, gui::center(gui::cut_left(title, 30.0 * u), 30.0 * u, 30.0 * u), GROUP_ICONS[group],
                        gui::PLAIN, 0.0, 0.85);
        gui::cut_left(title, 12.0 * u);
        gui::text(g, gui::HEADING, title, strings::get(GROUP_TITLES[group]), 1.0, 0.0, gui::LEFT);
        let n = if group == 0 { note_beside(g, r.z, true) } else { 0 };
        if n > 0 {
            // Right-aligned beside the title, centered down its row.
            let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
            let room = note_room(g, r.z);
            note_lines(g, float4 { title.x + title.z - room, title.y + 0.5 * (title.w - n * line), room, 0.0 }, true,
                       gui::RIGHT);
        }
    }
    let h, changed = rows(s, over, g, group, c, aside, true);
    if group == 0 && note_beside(g, r.z, titled) == 0 {
        // At the glass's foot, below the rows however much taller the glass is.
        let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
        let n = note_lines(g, c, false);
        note_lines(g, float4 { c.x, c.y + c.w - n * line, c.z, 0.0 }, true);
    }
    return changed;
}

// A language's tile width: its name in itself with 16 dp either side, at least 88 dp.
fn language_width(g: gui::Gui&, lang: i64) -> f32 {
    return max(88.0 * g.scale, gui::text_width(g, gui::BODY, strings::name_of(lang)) + 32.0 * g.scale);
}

// How wide the language's glass is: a globe, unless `globe` is false, then a tile per
// language, 8 dp apart, inside the glass's 6 dp sides.
fn languages_width(g: gui::Gui&, globe: bool = true) -> f32 {
    var w = (if globe { 52.0 } else { 4.0 }) * g.scale;
    for i in strings::LANGUAGES.len { w += language_width(g, i) + 8.0 * g.scale; }
    return w;
}

// How wide a group's tab must be: its icon and its title.
fn tab_width(g: gui::Gui&, group: i64) -> f32 {
    return gui::labelled_width(g, 30.0, strings::get(GROUP_TITLES[group]), gui::HEADING, gui::MIDDLE) + 16.0 * g.scale;
}

// The two tabs, Game and Look, side by side in r, the shown group's lit. True when a tap
// changed the group shown.
fn tabs(s: Settings&, g: gui::Gui&, r: float4) -> bool {
    let u = g.scale;
    var changed = false;
    let w = 0.5 * (r.z - TILE_GAP * u);
    for k in 2 {
        let t = float4 { r.x + k * (w + TILE_GAP * u), r.y, w, r.w };
        if gui::labelled(g, 398 + k, t, GROUP_ICONS[k], 30.0, strings::get(GROUP_TITLES[k]), gui::HEADING, gui::MIDDLE,
                         if s.group == k { gui::CHOSEN } else { gui::PLAIN }) {
            changed = s.group != k;
            s.group = k;
        }
    }
    return changed;
}

// The title row in r: back, the title, and at its right end the language on glass, each
// named in itself, with `shown` lit. With `tabbed`, the tabs instead of the title (a
// phone's landscape); without, the title, and where it doesn't fit beside them in the
// row labels' face (a phone's portrait), back is the arrow over the word in an 88 dp
// square, and where the title still doesn't fit in the headings' face (480 dp across),
// the language's glass leaves out its globe; the title then takes a smaller face where it
// is too wide for its room, or none where even that is. Returns BACK, CHANGED, SHOWN, or
// NOTHING.
fn head(s: Settings&, g: gui::Gui&, r: float4, shown: i64, tabbed: bool = false) -> i64 {
    let u = g.scale;
    var row = r;
    var ask = NOTHING;
    let title = strings::get(strings::HOME_SETTINGS);
    let wide = gui::back_width(g, strings::get(strings::NAV_BACK));
    let stacked = !tabbed && r.z - wide - 40.0 * u - languages_width(g) < gui::text_width(g, gui::LABEL, title);
    let globe = !stacked || r.z - (BACK_W + 40.0) * u - languages_width(g) >= gui::text_width(g, gui::HEADING, title);
    let bw = if stacked { BACK_W * u } else { wide };
    let back = gui::center(gui::cut_left(row, bw), bw, BACK_W * u);
    if gui::back(g, 400, back, strings::get(strings::NAV_BACK), stacked) { ask = BACK; }
    gui::cut_left(row, 20.0 * u);
    let w = languages_width(g, globe);
    let glass = gui::center(gui::cut_right(row, w), w, HEAD_H * u);
    gui::glass(g, glass, 20.0);
    var c = gui::inset(glass, 6.0 * u);
    if globe {
        gui::cut_left(c, 8.0 * u);
        gui::glyph_icon(g, gui::center(gui::cut_left(c, 28.0 * u), 28.0 * u, 28.0 * u), gui::GLOBE, gui::PLAIN, 0.0,
                        0.85);
        gui::cut_left(c, 12.0 * u);
    }
    for i in strings::LANGUAGES.len {
        let tapped, pic = gui::pick(g, 401 + i, gui::cut_left(c, language_width(g, i)), 0.0, strings::name_of(i), "",
                                    shown == i, true);
        gui::cut_left(c, 8.0 * u);
        if tapped {
            s.language = i;
            ask = CHANGED;
        }
    }
    gui::cut_right(row, 20.0 * u);
    if tabbed {
        if tabs(s, g, gui::center(row, row.z, BACK_W * u)) { ask = SHOWN; }
        return ask;
    }
    let face = gui::fitting(g, gui::LABEL, title, row.z);
    if gui::text_width(g, face, title) <= row.z { gui::text(g, face, row, title, 1.0, 0.0, gui::LEFT); }
    return ask;
}

// Where a 3D preview may go on the page left beside the choices: 94% of it each way, as
// the flat square takes 94% of its shorter side; nothing where the flat preview isn't
// shown (`size` 0).
fn preview_room(page: float4, size: f32) -> float4 {
    guard size > 0.0 else { return float4 { page.x + 0.5 * page.z, page.y + 0.5 * page.w, 0.0, 0.0 }; }
    return float4 { page.x + 0.03 * page.z, page.y + 0.03 * page.w, 0.94 * page.z, 0.94 * page.w };
}

// Declares the screen for this frame in `area`, the screen's safe area, with `shown`
// the language showing, and sets l to where the preview goes, and `room3d` to where a 3D
// preview goes instead, as large as it fits (the same share of the page beside the
// choices as the flat square's). The kings' tiles put their pieces in `over`. Returns
// BACK, CHANGED after a tap changed s, SHOWN after a tab, or NOTHING.
fn frame(s: Settings&, over: game::Overlay&, g: gui::Gui&, l: board::Layout&, area: float4, shown: i64,
         room3d: float4&) -> i64 {
    let u = g.scale;
    let landscape = area.z >= area.w;
    let n = rules::VARIANTS[s.variant].size;
    var page = float4 { area.x + PAD_X * u, area.y + PAD_Y * u, area.z - 2.0 * PAD_X * u, area.w - 2.0 * PAD_Y * u };
    over.clear();
    s.switch_at = float4 { 0.0, 0.0, 0.0, 0.0 };
    s.name_w = NAME_W;
    var ask = NOTHING;
    if landscape {
        // The choices as wide as they want, at most 55% of the page, wrapping beyond, each
        // setting's name at the left of its tiles; the board in the rest, centered. Near
        // square, where the wrapped rows would run past the page's foot, the names go
        // above the tiles instead, as in portrait, and the rows need less width; where
        // that runs past it too, the names go back to the left and the rows take the width
        // they want unwrapped (a foldable). Where even that runs past it (a phone), one
        // group shows at a time, tabs for the two in the title row in place of the title,
        // the names at the left. Over a bottom inset (a gesture or hidden navigation bar)
        // the groups may run on through the page's foot, as long as the look's tiles end
        // above the inset and as far from the screen's edge as they would with none: `room` gains up to that foot, 38 dp.
        let head_w = gui::back_width(g, strings::get(strings::NAV_BACK)) + 40.0 * u + languages_width(g)
                     + gui::text_width(g, gui::LABEL, strings::get(strings::HOME_SETTINGS));
        let rise = min(g.insets.y, TOP_RISE * u);
        page.y -= rise;
        page.w += rise;
        let foot = min(g.insets.w, (PAD_Y + 14.0) * u);
        let room = page.w - (HEAD_H + HEAD_GAP) * u + foot;
        var aside = true;
        var w = min(max(max(group_width(s, g, 0, true), group_width(s, g, 1, true)), head_w), 0.55 * page.z);
        if group_height(s, over, g, 0, w, true) + GROUP_GAP * u + group_height(s, over, g, 1, w, true) > room {
            aside = false;
            w = min(max(max(group_width(s, g, 0, false), group_width(s, g, 1, false)), head_w), 0.55 * page.z);
        }
        if group_height(s, over, g, 0, w, aside) + GROUP_GAP * u + group_height(s, over, g, 1, w, aside) > room {
            aside = true;
            w = max(max(group_width(s, g, 0, true), group_width(s, g, 1, true)), head_w);
        }
        let tabbed = group_height(s, over, g, 0, w, aside) + GROUP_GAP * u + group_height(s, over, g, 1, w, aside) > room
                     || w > 0.7 * page.z;
        if !tabbed && aside && w + (WIDE_NAME_W - NAME_W) * u <= 0.55 * page.z {
            w += (WIDE_NAME_W - NAME_W) * u;
            s.name_w = WIDE_NAME_W;
        }
        if tabbed {
            aside = true;
            let tabs_w = gui::back_width(g, strings::get(strings::NAV_BACK)) + 40.0 * u + languages_width(g)
                         + tab_width(g, 0) + tab_width(g, 1) + TILE_GAP * u;
            w = max(max(group_width(s, g, 0, true), group_width(s, g, 1, true)), tabs_w);
        }
        var side = gui::cut_left(page, w);
        gui::cut_left(page, SIDE_GAP * u);
        var size = 0.94 * min(page.z, page.w);
        if size < board::SMALLEST * u { size = 0.0; }
        l = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
        room3d = preview_room(page, size);
        ask = head(s, g, gui::cut_top(side, HEAD_H * u), shown, tabbed);
        gui::cut_top(side, HEAD_GAP * u);
        if tabbed {
            // The shown group, as tall as the taller, centered down the rest.
            let h = max(group_height(s, over, g, 0, side.z, true, false), group_height(s, over, g, 1, side.z, true, false));
            if group(s, over, g, s.group, gui::center(side, side.z, h), area, true, false) { ask = CHANGED; }
            return ask;
        }
        let game_h = group_height(s, over, g, 0, side.z, aside);
        let look_h = group_height(s, over, g, 1, side.z, aside);
        // Centered down the rest, or from its top if they are taller, running on into the
        // foot; the look's glass ends below its kings there rather than running on to the
        // screen's bottom edge, which left it mostly empty below (the user, 2026-11-09).
        gui::cut_top(side, max(0.0, 0.5 * (side.w - game_h - GROUP_GAP * u - look_h)));
        var list = side;
        if group(s, over, g, 0, gui::cut_top(list, game_h), area, aside) { ask = CHANGED; }
        gui::cut_top(list, GROUP_GAP * u);
        let look = float4 { list.x, list.y, list.z, look_h };
        let unbled = float4 { area.x, area.y, area.z, area.w + g.insets.w };   // no bleed at the foot
        if group(s, over, g, 1, look, unbled, aside) { ask = CHANGED; }
    } else {
        // The title row, the board as large as the rest leaves, and the groups side by
        // side along the bottom, as tall as the taller. Where that leaves the board under
        // 45% of the width, or under BOTH_BOARD (a phone), one group shows at a time,
        // across the width, tabs for the two under the title row.
        let w = 0.5 * (page.z - GROUP_GAP * u);
        let h = max(group_height(s, over, g, 0, w, false), group_height(s, over, g, 1, w, false));
        let left = page.w - (HEAD_H + 32.0) * u - h;
        let tabbed = 0.94 * min(page.z, left) < min(0.45 * page.z, BOTH_BOARD * u);
        ask = head(s, g, gui::cut_top(page, HEAD_H * u), shown);
        gui::cut_top(page, 16.0 * u);
        if tabbed {
            if tabs(s, g, gui::cut_top(page, BACK_W * u)) { ask = SHOWN; }
            gui::cut_top(page, GROUP_GAP * u);
            let one = max(group_height(s, over, g, 0, page.z, false, false), group_height(s, over, g, 1, page.z, false, false));
            let glass = gui::cut_bottom(page, one);
            gui::cut_bottom(page, 16.0 * u);
            var size = 0.94 * min(page.z, page.w);
            if size < board::SMALLEST * u { size = 0.0; }
            l = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
            room3d = preview_room(page, size);
            if group(s, over, g, s.group, glass, area, false, false) { ask = CHANGED; }
            return ask;
        }
        var groups = gui::cut_bottom(page, h);
        gui::cut_bottom(page, 16.0 * u);
        let size = 0.94 * min(page.z, page.w);
        l = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
        room3d = preview_room(page, size);
        if group(s, over, g, 0, gui::cut_left(groups, w), area, false) { ask = CHANGED; }
        gui::cut_left(groups, GROUP_GAP * u);
        if group(s, over, g, 1, groups, area, false) { ask = CHANGED; }
    }
    return ask;
}
