// Settings (prototypes/settings.html; rendering.md, "Settings"): back and the title,
// the language at the title row's right end, and the choices as words in two glass
// groups by what they change. Game: the draughts a new game starts on (the setup's
// choice too), move hints, and the tutorial. Look: the background (by the date, or one
// season), the board (flat or raised, a row hidden until the 3D board exists), and the kings (auto,
// crown, or stack). Beside them is home's board as the choices make it: its size, the
// kings, and what the move hints show, on a fixed position. In landscape the choices
// take the width they need at the left and the board the rest (near square, each
// setting's name above its tiles, so the rows fit the height); in portrait the board is
// on top and the groups stand side by side under it, each setting's name above its
// tiles. Where the groups don't fit so (a phone), one shows at a time: two tiles, Game
// and Look, choose which, in the title row in landscape and under it in portrait. A
// tap applies at once; there is no save button.
//
// The values are kept across runs as a small text file, one `key = value` per line,
// which the app reads at start and writes after a change. The file also keeps the
// computer's skill at each level, which moves after each game against it, how many
// such games began, and the stars won in each puzzle (`stars = 1:3 4:2`, by puzzle id).
namespace settings;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../strings";
import ai from "../ai";
import puzzles from "../puzzles";

// The board themes by season, as app/theme.goose numbers them, in the order the tiles
// show the seasons: winter stone, spring birch, summer sunset, autumn wood.
let SEASON_KINDS = [1, 2, 3, 0];
let SEASON_KEYS = [strings::SEASON_WINTER, strings::SEASON_SPRING, strings::SEASON_SUMMER, strings::SEASON_AUTUMN];
let SEASON_NAMES = ["winter", "spring", "summer", "autumn"];
let BY_DATE = -1;
let FLAT = 0;                   // the 2D board
let RAISED = 1;                 // the 3D board (task 015)
let SYSTEM = -1;                // the language the system's locales pick
// Kings: AUTO, board::CROWN, or board::STACK, as the file names them. Auto is a crown
// on the flat board and a stack on the raised one.
let AUTO = 0;
let KING_NAMES = ["auto", "crown", "stack"];
let KING_KEYS = [strings::KINGS_AUTO, strings::KINGS_CROWN, strings::KINGS_STACK];

// The draughts a new game can be, in the order the setup shows them: the variant, its
// name and board, whether it is offered, and its name in the file. International is the
// default.
let DRAUGHTS = [rules::INTERNATIONAL, rules::BRAZILIAN, rules::RUSSIAN];
let DRAUGHTS_KEYS = [strings::VARIANT_INTERNATIONAL, strings::VARIANT_BRAZILIAN, strings::VARIANT_RUSSIAN];
let DRAUGHTS_SIZES = [strings::SIZE_10, strings::SIZE_8, strings::SIZE_8];
let DRAUGHTS_ON = [true, true, true];
let DRAUGHTS_NAMES = ["international", "brazilian", "russian"];
let DEFAULT_DRAUGHTS = rules::INTERNATIONAL;
// The computer's levels (game::EASY..) and the clocks (clock::NONE..), in the file.
let LEVEL_NAMES = ["easy", "medium", "hard"];
let SKILL_KEYS = ["skill_easy", "skill_medium", "skill_hard"];
let CLOCK_NAMES = ["none", "5+3", "10+5"];

struct Settings {
    season:   i64 = BY_DATE,    // a theme (app/theme.goose), or BY_DATE
    board:    i64 = FLAT,       // kept in the file; the flat board is drawn until show_board_row
    hints:    i64 = board::MISTAKES,
    kings:    i64 = AUTO,
    language: i64 = SYSTEM,     // strings::EN.., or SYSTEM
    // A new game's setup, kept for the next one.
    variant: i64 = DEFAULT_DRAUGHTS,
    level:   i64 = 1,           // medium
    color:   i64 = rules::WHITE, // the child's pieces against the computer
    clock:   i64 = 0,           // none
    // The computer's skill at each level (ai::adapt), and the games against it so far.
    skill: i64[3] = ai::LEVEL_SKILL,
    games: i64    = 0,
    // The stars won in each puzzle, 1 to 3, by its id; 0 for one not solved.
    stars: u8[puzzles::MAX_PUZZLES + 1] = [0; puzzles::MAX_PUZZLES + 1],
    // Whether the Board row shows. The 3D board doesn't exist yet (task 015), so the row
    // is hidden and the board always flat, whatever the file's `board` says; the app's
    // `--3d` flag turns it on for working on that task. Not in the file; remove it, and
    // this switch, when 3D lands.
    show_board_row: bool = false,
    // The group a phone's settings show, 0 the game's or 1 the look's. Not in the file.
    group: i64 = 0,
}

// What the screen asks for.
let NOTHING = 0;
let BACK = 1;
let CHANGED = 2;

// How the board draws kings: auto is a crown, the board being flat (the only board
// drawn while the Board row is hidden, and none other exists yet).
fn king_look(s: Settings) -> i64 { if s.kings == board::STACK { board::STACK } else { board::CROWN } }

// The settings a file holds; what it lacks or doesn't know stays at the default.
fn parse(text: const u8[:]) -> Settings {
    var s = Settings {};
    var rest = text;
    while rest.len > 0 {
        let line, after, found = split_once(rest, '\n');
        rest = after;
        let k, v, ok = split_once(line, '=');
        guard ok else { continue; }
        let key = trim(k);
        let value = trim(v);
        if key == "season" {
            for name, i in SEASON_NAMES { if value == name { s.season = SEASON_KINDS[i]; } }
        }
        if key == "board" && value == "3d" { s.board = RAISED; }
        if key == "hints" && value == "moves" { s.hints = board::MOVES; }
        if key == "kings" {
            for name, i in KING_NAMES { if value == name { s.kings = i; } }
        }
        if key == "language" {
            for name, i in strings::LANGUAGES { if value == name { s.language = i; } }
        }
        if key == "draughts" {
            for name, i in DRAUGHTS_NAMES { if value == name && DRAUGHTS_ON[i] { s.variant = DRAUGHTS[i]; } }
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
        for name, i in SKILL_KEYS { if key == name && number { s.skill[i] = ai::adapt(n, i, 0); } }
        if key == "games" && number && n >= 0 { s.games = n; }
        if key == "stars" {
            for one in split(value, ' ') {
                let a, b, pair = split_once(one, ':');
                let id, ok_id = parse_int(a);
                let won, ok_won = parse_int(b);
                if pair && ok_id && ok_won && id >= 1 && id <= puzzles::MAX_PUZZLES && won >= 1 && won <= 3 {
                    s.stars[id] = won as u8;
                }
            }
        }
    }
    return s;
}

// The file for settings s, appended to out.
fn write(s: Settings, out: u8[>..]&) {
    out.append("season = ");
    var season = "by-date";
    for kind, i in SEASON_KINDS { if s.season == kind { season = SEASON_NAMES[i]; } }
    out.append(season);
    out.append(if s.board == RAISED { "\nboard = 3d" } else { "\nboard = 2d" });
    out.append(if s.hints == board::MOVES { "\nhints = moves" } else { "\nhints = mistakes" });
    out.append("\nkings = ");
    out.append(KING_NAMES[s.kings]);
    out.append("\nlanguage = ");
    out.append(if s.language >= 0 { strings::LANGUAGES[s.language] } else { "system" });
    out.append("\ndraughts = ");
    for v, i in DRAUGHTS { if s.variant == v { out.append(DRAUGHTS_NAMES[i]); } }
    out.append("\nlevel = ");
    out.append(LEVEL_NAMES[s.level]);
    out.append(if s.color == rules::BLACK { "\ncolor = black" } else { "\ncolor = white" });
    out.append("\nclock = ");
    out.append(CLOCK_NAMES[s.clock]);
    for name, i in SKILL_KEYS { format(out, "\n", name, " = ", s.skill[i]); }
    format(out, "\ngames = ", s.games);
    var first = true;
    for won, id in s.stars {
        guard won > 0 else { continue; }
        out.append(if first { "\nstars = " } else { " " });
        format(out, id, ":", won);
        first = false;
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
    b.king_look = king_look(s);
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
let HEAD_H = 100.0;         // back (88), the title, and the language's glass round 88 dp tiles
let BACK_W = 88.0;          // back, square
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
let SLACK = 0.5;            // px a row may pass its width by without wrapping

// The settings in order, the first three in the game's group, the rest in the look's:
// each one's name, how many tiles, and how tall they are.
let DRAUGHTS_ROW = 0;
let HINTS_ROW = 1;
let TUTORIAL_ROW = 2;
let BACKGROUND_ROW = 3;
let BOARD_ROW = 4;
let KINGS_ROW = 5;
let GAME_ROWS = 3;
let ROW_NAMES = [strings::SETUP_DRAUGHTS, strings::SETTINGS_HINTS, strings::SETTINGS_TUTORIAL,
                 strings::SETTINGS_BACKGROUND, strings::SETTINGS_BOARD, strings::SETTINGS_KINGS];
let ROW_TILES = [3, 2, 1, 5, 2, 3];
let ROW_H = [88.0, 88.0, 88.0, 88.0, 88.0, 88.0]; // the floor for small hands (56 to 72 until 2026-11-08)
let GROUP_ICONS = [gui::TARGET, gui::SUN];
let GROUP_TITLES = [strings::SETTINGS_GAME, strings::SETTINGS_LOOK];

// The rows a group shows: the game's three, and the look's background, board (only with
// the switch on), and kings. Row k of a group is `group_row`.
fn group_rows(s: Settings&, group: i64) -> i64 {
    return if group == 0 || s.show_board_row { 3 } else { 2 };
}

fn group_row(s: Settings&, group: i64, k: i64) -> i64 {
    let row = GAME_ROWS * group + k;
    return if row >= BOARD_ROW && !s.show_board_row { row + 1 } else { row };
}

// Tile i of a row's word.
fn word(row: i64, i: i64) -> i64 {
    if row == DRAUGHTS_ROW { return DRAUGHTS_KEYS[i]; }
    if row == HINTS_ROW { return [strings::HINTS_MISTAKES, strings::HINTS_MOVES][i]; }
    if row == TUTORIAL_ROW { return strings::TUTORIAL_LEARN; }
    if row == BACKGROUND_ROW { return if i == 0 { strings::SETTINGS_BY_DATE } else { SEASON_KEYS[i - 1] }; }
    if row == BOARD_ROW { return [strings::BOARD_FLAT, strings::BOARD_RAISED][i]; }
    return KING_KEYS[i];
}

// Tile i of a row's note under its word, or "".
fn note(row: i64, i: i64) -> const u8[:] {
    if row == DRAUGHTS_ROW { return strings::get(DRAUGHTS_SIZES[i]); }
    if row == BOARD_ROW { return strings::get([strings::BOARD_FLAT_NOTE, strings::BOARD_RAISED_NOTE][i]); }
    if row == KINGS_ROW && i == AUTO { return strings::get(strings::KINGS_AUTO_NOTE); }
    return "";
}

// How wide tile i of a row is: its words with 16 dp either side, at least 88 dp; a
// season's, its thumbnail or label and 6 dp either side, at least 88 dp too; the
// tutorial's, its icon too.
fn tile_width(g: gui::Gui&, row: i64, i: i64) -> f32 {
    let u = g.scale;
    let label = strings::get(word(row, i));
    if row == BACKGROUND_ROW { return max(88.0 * u, max(THUMB_W * u, gui::text_width(g, gui::SMALL, label)) + 12.0 * u); }
    let w = gui::text_width(g, gui::BODY, label);
    if row == TUTORIAL_ROW { return (16.0 + 26.0 + 10.0 + 16.0) * u + w; }
    return max(88.0 * u, max(w, gui::text_width(g, gui::SMALL, note(row, i))) + 32.0 * u);
}

// Declares tile i of a row in r. True when a tap changed s.
fn tile(s: Settings&, over: game::Overlay&, g: gui::Gui&, row: i64, i: i64, r: float4) -> bool {
    let u = g.scale;
    let id = 410 + 10 * row + i;
    let label = strings::get(word(row, i));
    if row == BACKGROUND_ROW {
        let kind = if i == 0 { BY_DATE } else { SEASON_KINDS[i - 1] };
        guard gui::choice(g, id, r, kind, float2 { THUMB_W * u, THUMB_H * u }, label, s.season == kind, true)
        else { return false; }
        s.season = kind;
        return true;
    }
    if row == TUTORIAL_ROW {
        // A bulb and the words, dimmed and taking no tap until the tutorial exists.
        let unused, at = gui::pick(g, id, r, 0.0, "", "", false, false);
        var c = gui::center(r, 36.0 * u + gui::text_width(g, gui::BODY, label), r.w);
        gui::glyph_icon(g, gui::center(gui::cut_left(c, 26.0 * u), 26.0 * u, 26.0 * u), gui::HINT, gui::PLAIN, 0.0, 0.4);
        gui::cut_left(c, 10.0 * u);
        gui::text(g, gui::BODY, c, label, 0.4, 0.0, gui::LEFT);
        return false;
    }
    let on = if row == DRAUGHTS_ROW { s.variant == DRAUGHTS[i] } else if row == HINTS_ROW { s.hints == i }
             else if row == BOARD_ROW { s.board == i } else { s.kings == i };
    let enabled = if row == DRAUGHTS_ROW { DRAUGHTS_ON[i] } else { row != BOARD_ROW || i == FLAT };
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
    for k in group_rows(s, group) {
        let row = group_row(s, group, k);
        if k > 0 { y += ROW_GAP * u; }
        let left = (NAME_W + 14.0) * u;
        let tiles = if aside { float4 { r.x + left, y, r.z - left, 0.0 } }
                    else { float4 { r.x, y + NAME_H * u, r.z, 0.0 } };
        let h, tapped = lay(s, over, g, row, tiles, declare);
        if declare {
            let name = float4 { r.x, y, NAME_W * u, if aside { h } else { NAME_H * u - 6.0 * u } };
            gui::text(g, gui::SMALL, name, strings::get(ROW_NAMES[row]), 0.66, 0.03 * gui::FACE_DP[gui::SMALL] as f32 * u,
                      gui::LEFT);
        }
        if tapped { changed = true; }
        y += if aside { h } else { NAME_H * u + h };
    }
    return y - r.y, changed;
}

// How tall a group's glass is at width w; with no title row where a tab names it.
fn group_height(s: Settings&, over: game::Overlay&, g: gui::Gui&, group: i64, w: f32, aside: bool,
                titled: bool = true) -> f32 {
    let u = g.scale;
    let h, unused = rows(s, over, g, group, float4 { 0.0, 0.0, w - 2.0 * GROUP_PAD * u, 0.0 }, aside, false);
    let title: f32 = if titled { TITLE_H + ROW_GAP } else { 0.0 };
    return (12.0 + title + 14.0) * u + h;
}

// How wide a group's glass wants to be with its rows unwrapped, the names at their left
// when `aside`.
fn group_width(s: Settings&, g: gui::Gui&, group: i64, aside: bool) -> f32 {
    let u = g.scale;
    var widest: f32 = 0.0;
    for k in group_rows(s, group) {
        let row = group_row(s, group, k);
        var w = -TILE_GAP * u;
        for i in ROW_TILES[row] { w += tile_width(g, row, i) + TILE_GAP * u; }
        widest = max(widest, w);
    }
    let names = if aside { NAME_W + 14.0 } else { 0.0 };
    return widest + (names + 2.0 * GROUP_PAD) * u;
}

// A group's glass in r: its icon and title (unless a tab names it), then its settings.
// True when a tap changed s.
fn group(s: Settings&, over: game::Overlay&, g: gui::Gui&, group: i64, r: float4, aside: bool,
         titled: bool = true) -> bool {
    let u = g.scale;
    gui::glass(g, r, 24.0);
    var c = float4 { r.x + GROUP_PAD * u, r.y + 12.0 * u, r.z - 2.0 * GROUP_PAD * u, r.w - 26.0 * u };
    if titled {
        var title = gui::cut_top(c, TITLE_H * u);
        gui::cut_top(c, ROW_GAP * u);
        gui::glyph_icon(g, gui::center(gui::cut_left(title, 30.0 * u), 30.0 * u, 30.0 * u), GROUP_ICONS[group],
                        gui::PLAIN, 0.0, 0.85);
        gui::cut_left(title, 12.0 * u);
        gui::text(g, gui::HEADING, title, strings::get(GROUP_TITLES[group]), 1.0, 0.0, gui::LEFT);
    }
    let h, changed = rows(s, over, g, group, c, aside, true);
    return changed;
}

// A language's tile width: its name in itself with 16 dp either side, at least 88 dp.
fn language_width(g: gui::Gui&, lang: i64) -> f32 {
    return max(88.0 * g.scale, gui::text_width(g, gui::BODY, strings::name_of(lang)) + 32.0 * g.scale);
}

// How wide the language's glass is: a globe, then a tile per language.
fn languages_width(g: gui::Gui&) -> f32 {
    var w = 52.0 * g.scale;
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
// phone's landscape); without, the title in a smaller face where it is too wide for its
// room, or none where even that is (a phone's portrait). Returns BACK, CHANGED, or
// NOTHING.
fn head(s: Settings&, g: gui::Gui&, r: float4, shown: i64, tabbed: bool = false) -> i64 {
    let u = g.scale;
    var row = r;
    var ask = NOTHING;
    let back = gui::center(gui::cut_left(row, BACK_W * u), BACK_W * u, BACK_W * u);
    gui::glass(g, back, 22.0);
    if gui::button(g, 400, back, gui::BACK) { ask = BACK; }
    gui::cut_left(row, 20.0 * u);
    let w = languages_width(g);
    let glass = gui::center(gui::cut_right(row, w), w, HEAD_H * u);
    gui::glass(g, glass, 20.0);
    var c = gui::inset(glass, 6.0 * u);
    gui::cut_left(c, 8.0 * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(c, 28.0 * u), 28.0 * u, 28.0 * u), gui::GLOBE, gui::PLAIN, 0.0, 0.85);
    gui::cut_left(c, 12.0 * u);
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
        if tabs(s, g, gui::center(row, row.z, BACK_W * u)) { ask = CHANGED; }
        return ask;
    }
    let title = strings::get(strings::HOME_SETTINGS);
    let face = gui::fitting(g, gui::LABEL, title, row.z);
    if gui::text_width(g, face, title) <= row.z { gui::text(g, face, row, title, 1.0, 0.0, gui::LEFT); }
    return ask;
}

// Declares the screen for this frame on a screen width × height pixels, with `shown`
// the language showing, and sets l to where the preview goes. The kings' tiles put their
// pieces in `over`. Returns BACK, CHANGED after a tap changed s, or NOTHING.
fn frame(s: Settings&, over: game::Overlay&, g: gui::Gui&, l: board::Layout&, width: f32, height: f32, shown: i64) -> i64 {
    let u = g.scale;
    let landscape = width >= height;
    let n = rules::VARIANTS[s.variant].size;
    var page = float4 { PAD_X * u, PAD_Y * u, width - 2.0 * PAD_X * u, height - 2.0 * PAD_Y * u };
    over.clear();
    var ask = NOTHING;
    if landscape {
        // The choices as wide as they want, at most 55% of the page, wrapping beyond, each
        // setting's name at the left of its tiles; the board in the rest, centered. Near
        // square, where the wrapped rows would run past the page's foot, the names go
        // above the tiles instead, as in portrait, and the rows need less width; where
        // that runs past it too, the names go back to the left and the rows take the width
        // they want unwrapped (a foldable). Where even that runs past it (a phone), one
        // group shows at a time, tabs for the two in the title row in place of the title,
        // the names at the left.
        let head_w = (HEAD_H + 40.0) * u + languages_width(g)
                     + gui::text_width(g, gui::LABEL, strings::get(strings::HOME_SETTINGS));
        let room = page.w - (HEAD_H + HEAD_GAP) * u;
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
        if tabbed {
            aside = true;
            let tabs_w = (BACK_W + 40.0) * u + languages_width(g) + tab_width(g, 0) + tab_width(g, 1) + TILE_GAP * u;
            w = max(max(group_width(s, g, 0, true), group_width(s, g, 1, true)), tabs_w);
        }
        var side = gui::cut_left(page, w);
        gui::cut_left(page, SIDE_GAP * u);
        var size = 0.94 * min(page.z, page.w);
        if size < 96.0 * u { size = 0.0; }
        l = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
        ask = head(s, g, gui::cut_top(side, HEAD_H * u), shown, tabbed);
        gui::cut_top(side, HEAD_GAP * u);
        if tabbed {
            // The shown group, as tall as the taller, centered down the rest.
            let h = max(group_height(s, over, g, 0, side.z, true, false), group_height(s, over, g, 1, side.z, true, false));
            if group(s, over, g, s.group, gui::center(side, side.z, h), true, false) { ask = CHANGED; }
            return ask;
        }
        let game_h = group_height(s, over, g, 0, side.z, aside);
        let look_h = group_height(s, over, g, 1, side.z, aside);
        // Centered down the rest, or from its top if they are taller.
        gui::cut_top(side, max(0.0, 0.5 * (side.w - game_h - GROUP_GAP * u - look_h)));
        var list = side;
        if group(s, over, g, 0, gui::cut_top(list, game_h), aside) { ask = CHANGED; }
        gui::cut_top(list, GROUP_GAP * u);
        if group(s, over, g, 1, gui::cut_top(list, look_h), aside) { ask = CHANGED; }
    } else {
        // The title row, the board as large as the rest leaves, and the groups side by
        // side along the bottom, as tall as the taller. Where that leaves the board under
        // 45% of the width (a phone), one group shows at a time, across the width, tabs
        // for the two under the title row.
        let w = 0.5 * (page.z - GROUP_GAP * u);
        let h = max(group_height(s, over, g, 0, w, false), group_height(s, over, g, 1, w, false));
        let left = page.w - (HEAD_H + 32.0) * u - h;
        let tabbed = 0.94 * min(page.z, left) < 0.45 * page.z;
        ask = head(s, g, gui::cut_top(page, HEAD_H * u), shown);
        gui::cut_top(page, 16.0 * u);
        if tabbed {
            if tabs(s, g, gui::cut_top(page, BACK_W * u)) { ask = CHANGED; }
            gui::cut_top(page, GROUP_GAP * u);
            let one = max(group_height(s, over, g, 0, page.z, false, false), group_height(s, over, g, 1, page.z, false, false));
            let glass = gui::cut_bottom(page, one);
            gui::cut_bottom(page, 16.0 * u);
            var size = 0.94 * min(page.z, page.w);
            if size < 96.0 * u { size = 0.0; }
            l = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
            if group(s, over, g, s.group, glass, false, false) { ask = CHANGED; }
            return ask;
        }
        var groups = gui::cut_bottom(page, h);
        gui::cut_bottom(page, 16.0 * u);
        let size = 0.94 * min(page.z, page.w);
        l = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
        if group(s, over, g, 0, gui::cut_left(groups, w), false) { ask = CHANGED; }
        gui::cut_left(groups, GROUP_GAP * u);
        if group(s, over, g, 1, groups, false) { ask = CHANGED; }
    }
    return ask;
}
