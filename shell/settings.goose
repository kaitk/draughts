// Settings (prototypes/settings.html; rendering.md, "Settings"): back and the title,
// the language at the title row's right end, and the choices as words in two glass
// groups by what they change. Game: the draughts a new game starts on (the setup's
// choice too), move hints, and the tutorial. Look: the background (by the date, or one
// season), the board (flat; raised once the 3D board exists), and the kings (auto,
// crown, or stack). Beside them is home's board as the choices make it: its size, the
// kings, and what the move hints show, on a fixed position. In landscape the choices
// take the width they need at the left and the board the rest; in portrait the board is
// on top and the groups stand side by side under it, each setting's name above its
// tiles. A tap applies at once; there is no save button.
//
// The values are kept across runs as a small text file, one `key = value` per line,
// which the app reads at start and writes after a change. The file also keeps the
// computer's skill at each level, which moves after each game against it, and how many
// such games began.
namespace settings;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../strings";
import ai from "../ai";

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
    board:    i64 = FLAT,
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
}

// What the screen asks for.
let NOTHING = 0;
let BACK = 1;
let CHANGED = 2;

// How the board draws kings: auto is a crown, the board being flat.
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
    format(out, "\ngames = ", s.games, "\n");
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
let HEAD_H = 88.0;          // back, the title, and the language
let HEAD_GAP = 14.0;        // under them in landscape; 16 in portrait, as round the board
let SIDE_GAP = 24.0;        // between the choices and the board in landscape
let GROUP_GAP = 10.0;
let GROUP_PAD = 20.0;       // a group's sides; 12 above, 14 below
let TITLE_H = 34.0;         // a group's icon and title
let NAME_W = 120.0;         // a setting's name, at the left of its tiles in landscape
let NAME_H = 28.0;          // and above them in portrait
let ROW_GAP = 10.0;
let TILE_GAP = 10.0;
let THUMB_W = 62.0;         // a season's thumbnail
let THUMB_H = 40.0;

// The settings in order, the first three in the game's group, the rest in the look's:
// each one's name, how many tiles, and how tall they are.
let DRAUGHTS_ROW = 0;
let HINTS_ROW = 1;
let TUTORIAL_ROW = 2;
let BACKGROUND_ROW = 3;
let BOARD_ROW = 4;
let KINGS_ROW = 5;
let GROUP_ROWS = 3;
let ROW_NAMES = [strings::SETUP_DRAUGHTS, strings::SETTINGS_HINTS, strings::SETTINGS_TUTORIAL,
                 strings::SETTINGS_BACKGROUND, strings::SETTINGS_BOARD, strings::SETTINGS_KINGS];
let ROW_TILES = [3, 2, 1, 5, 2, 3];
let ROW_H = [56.0, 56.0, 56.0, 70.0, 56.0, 72.0];
let GROUP_ICONS = [gui::TARGET, gui::SUN];
let GROUP_TITLES = [strings::SETTINGS_GAME, strings::SETTINGS_LOOK];

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
// season's, its thumbnail or label and 6 dp either side; the tutorial's, its icon too.
fn tile_width(g: gui::Gui&, row: i64, i: i64) -> f32 {
    let u = g.scale;
    let label = strings::get(word(row, i));
    if row == BACKGROUND_ROW { return max(THUMB_W * u, gui::text_width(g, gui::SMALL, label)) + 12.0 * u; }
    let w = gui::text_width(g, gui::BODY, label);
    if row == TUTORIAL_ROW { return (16.0 + 26.0 + 10.0 + 16.0) * u + w; }
    return max(88.0 * u, max(w, gui::text_width(g, gui::SMALL, note(row, i))) + 32.0 * u);
}

// Declares tile i of a row in r. True when a tap changed s.
fn tile(s: Settings&, gm: game::Game&, g: gui::Gui&, row: i64, i: i64, r: float4) -> bool {
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
    if king { game::put(gm, pic, 15.0 * u, rules::WHITE, i, 1.0, false); }
    guard tapped else { return false; }
    if row == DRAUGHTS_ROW { s.variant = DRAUGHTS[i]; }
    if row == HINTS_ROW { s.hints = i; }
    if row == BOARD_ROW { s.board = i; }
    if row == KINGS_ROW { s.kings = i; }
    return true;
}

// Lays out a row's tiles from r's top left, wrapping at its width, and declares them
// when `declare`. Returns how tall they are, and whether a tap changed s.
fn lay(s: Settings&, gm: game::Game&, g: gui::Gui&, row: i64, r: float4, declare: bool) -> f32, bool {
    let u = g.scale;
    let h = (ROW_H[row] as f32) * u;
    var x: f32 = 0.0;
    var y: f32 = 0.0;
    var changed = false;
    for i in ROW_TILES[row] {
        let w = min(tile_width(g, row, i), r.z);
        if x > 0.0 && x + w > r.z {
            x = 0.0;
            y += h + TILE_GAP * u;
        }
        if declare && tile(s, gm, g, row, i, float4 { r.x + x, r.y + y, w, h }) { changed = true; }
        x += w + TILE_GAP * u;
    }
    return y + h, changed;
}

// A group's settings from r's top left, as wide as r, each its dim name and its tiles:
// the name at the left in landscape, above them in portrait. Declares them when
// `declare`. Returns how tall they are, and whether a tap changed s.
fn rows(s: Settings&, gm: game::Game&, g: gui::Gui&, group: i64, r: float4, landscape: bool,
        declare: bool) -> f32, bool {
    let u = g.scale;
    var y = r.y;
    var changed = false;
    for k in GROUP_ROWS {
        let row = GROUP_ROWS * group + k;
        if k > 0 { y += ROW_GAP * u; }
        let aside = (NAME_W + 14.0) * u;
        let tiles = if landscape { float4 { r.x + aside, y, r.z - aside, 0.0 } }
                    else { float4 { r.x, y + NAME_H * u, r.z, 0.0 } };
        let h, tapped = lay(s, gm, g, row, tiles, declare);
        if declare {
            let name = float4 { r.x, y, NAME_W * u, if landscape { h } else { NAME_H * u - 6.0 * u } };
            gui::text(g, gui::SMALL, name, strings::get(ROW_NAMES[row]), 0.66, 0.03 * gui::FACE_DP[gui::SMALL] as f32 * u,
                      gui::LEFT);
        }
        if tapped { changed = true; }
        y += if landscape { h } else { NAME_H * u + h };
    }
    return y - r.y, changed;
}

// How tall a group's glass is at width w.
fn group_height(s: Settings&, gm: game::Game&, g: gui::Gui&, group: i64, w: f32, landscape: bool) -> f32 {
    let u = g.scale;
    let h, unused = rows(s, gm, g, group, float4 { 0.0, 0.0, w - 2.0 * GROUP_PAD * u, 0.0 }, landscape, false);
    return (12.0 + TITLE_H + ROW_GAP + 14.0) * u + h;
}

// How wide a group's glass wants to be in landscape, its rows unwrapped.
fn group_width(g: gui::Gui&, group: i64) -> f32 {
    let u = g.scale;
    var widest: f32 = 0.0;
    for k in GROUP_ROWS {
        let row = GROUP_ROWS * group + k;
        var w = -TILE_GAP * u;
        for i in ROW_TILES[row] { w += tile_width(g, row, i) + TILE_GAP * u; }
        widest = max(widest, w);
    }
    return widest + (NAME_W + 14.0 + 2.0 * GROUP_PAD) * u;
}

// A group's glass in r: its icon and title, then its settings. True when a tap changed s.
fn group(s: Settings&, gm: game::Game&, g: gui::Gui&, group: i64, r: float4, landscape: bool) -> bool {
    let u = g.scale;
    gui::glass(g, r, 24.0);
    var c = float4 { r.x + GROUP_PAD * u, r.y + 12.0 * u, r.z - 2.0 * GROUP_PAD * u, r.w - 26.0 * u };
    var title = gui::cut_top(c, TITLE_H * u);
    gui::cut_top(c, ROW_GAP * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(title, 30.0 * u), 30.0 * u, 30.0 * u), GROUP_ICONS[group], gui::PLAIN,
                    0.0, 0.85);
    gui::cut_left(title, 12.0 * u);
    gui::text(g, gui::HEADING, title, strings::get(GROUP_TITLES[group]), 1.0, 0.0, gui::LEFT);
    let h, changed = rows(s, gm, g, group, c, landscape, true);
    return changed;
}

// A language's tile width: its name in itself with 16 dp either side, at least 76 dp.
fn language_width(g: gui::Gui&, lang: i64) -> f32 {
    return max(76.0 * g.scale, gui::text_width(g, gui::BODY, strings::name_of(lang)) + 32.0 * g.scale);
}

// How wide the language's glass is: a globe, then a tile per language.
fn languages_width(g: gui::Gui&) -> f32 {
    var w = 52.0 * g.scale;
    for i in strings::LANGUAGES.len { w += language_width(g, i) + 8.0 * g.scale; }
    return w;
}

// The title row in r: back, the title, and at its right end the language on glass, each
// named in itself, with `shown` lit. Returns BACK, CHANGED, or NOTHING.
fn head(s: Settings&, g: gui::Gui&, r: float4, shown: i64) -> i64 {
    let u = g.scale;
    var row = r;
    var ask = NOTHING;
    let back = gui::cut_left(row, HEAD_H * u);
    gui::glass(g, back, 22.0);
    if gui::button(g, 400, back, gui::BACK) { ask = BACK; }
    gui::cut_left(row, 20.0 * u);
    let w = languages_width(g);
    let glass = gui::center(gui::cut_right(row, w), w, 60.0 * u);
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
    gui::text(g, gui::LABEL, row, strings::get(strings::HOME_SETTINGS), 1.0, 0.0, gui::LEFT);
    return ask;
}

// Declares the screen for this frame on a screen width × height pixels, with `shown`
// the language showing, and sets l to where the preview goes. The kings' tiles put their
// pieces in gm's overlay. Returns BACK, CHANGED after a tap changed s, or NOTHING.
fn frame(s: Settings&, gm: game::Game&, g: gui::Gui&, l: board::Layout&, width: f32, height: f32, shown: i64) -> i64 {
    let u = g.scale;
    let landscape = width >= height;
    let n = rules::VARIANTS[s.variant].size;
    var page = float4 { PAD_X * u, PAD_Y * u, width - 2.0 * PAD_X * u, height - 2.0 * PAD_Y * u };
    gm.overlay.clear();
    var ask = NOTHING;
    if landscape {
        // The choices as wide as they want, at most 55% of the page, wrapping beyond; the
        // board in the rest, centered.
        let want = max(max(group_width(g, 0), group_width(g, 1)), (HEAD_H + 40.0) * u + languages_width(g)
                       + gui::text_width(g, gui::LABEL, strings::get(strings::HOME_SETTINGS)));
        var side = gui::cut_left(page, min(want, 0.55 * page.z));
        gui::cut_left(page, SIDE_GAP * u);
        let size = 0.94 * min(page.z, page.w);
        l = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
        ask = head(s, g, gui::cut_top(side, HEAD_H * u), shown);
        gui::cut_top(side, HEAD_GAP * u);
        let game_h = group_height(s, gm, g, 0, side.z, true);
        let look_h = group_height(s, gm, g, 1, side.z, true);
        // Centered down the rest, or from its top if they are taller.
        gui::cut_top(side, max(0.0, 0.5 * (side.w - game_h - GROUP_GAP * u - look_h)));
        var list = side;
        if group(s, gm, g, 0, gui::cut_top(list, game_h), true) { ask = CHANGED; }
        gui::cut_top(list, GROUP_GAP * u);
        if group(s, gm, g, 1, gui::cut_top(list, look_h), true) { ask = CHANGED; }
    } else {
        // The title row, the board as large as the rest leaves, and the groups side by
        // side along the bottom, as tall as the taller.
        ask = head(s, g, gui::cut_top(page, HEAD_H * u), shown);
        gui::cut_top(page, 16.0 * u);
        let w = 0.5 * (page.z - GROUP_GAP * u);
        let h = max(group_height(s, gm, g, 0, w, false), group_height(s, gm, g, 1, w, false));
        var groups = gui::cut_bottom(page, h);
        gui::cut_bottom(page, 16.0 * u);
        let size = 0.94 * min(page.z, page.w);
        l = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
        if group(s, gm, g, 0, gui::cut_left(groups, w), false) { ask = CHANGED; }
        gui::cut_left(groups, GROUP_GAP * u);
        if group(s, gm, g, 1, groups, false) { ask = CHANGED; }
    }
    return ask;
}
