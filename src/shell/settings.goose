// Settings (prototypes/settings.html; rendering.md, "Settings"; task 080, take b): back,
// the title, and the language pinned at the top, and under them one list that scrolls,
// on one glass: Look (the background, the photograph or the plain fade; the theme, a
// season or by the date; the board, flat, or raised in the season's own material or its
// wood, stone, or carved board, each a picture; the kings, auto, crown, or stack), then
// Game (move hints, and the moves panel beside the game with a line saying what the
// chosen one shows), then the privacy note. The draughts are chosen in home's setup and
// the puzzles' library, whether a friend's game turns the board in home's setup. The
// preview beside the list is home's board as the choices make it: the player's draughts'
// size, the kings, and what the move hints show, on a fixed position. In landscape the
// list is a column at the left, its glass running off the screen's edge as home's, and
// the preview the rest; in portrait the preview is a band at the top and the list a sheet
// under it. The list fades out at its foot while there is more below, as home's does. The
// language is a button at the title row's right end, a globe, its code, and a chevron,
// opening a small glass list of the languages over the screen. A tap applies at once;
// there is no save button.
// The values, the file they are kept in, and its keys are in prefs.goose.
namespace settings;
import std;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import game from "../game";
import strings from "../../strings";
import .prefs;

// What the screen asks for (gui::ASK_NOTHING..): SHOWN when the language list opens or
// closes.
let NOTHING = gui::ASK_NOTHING;
let BACK = gui::ASK_BACK;
let CHANGED = gui::ASK_CHANGED;
let SHOWN = gui::ASK_SHOWN;

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
        board::select(b, square(v, "d4", k));
    } else {
        board::mistake(b, square(v, "c5", k), now);
    }
}

// The screen's parts, in dp (prototypes/settings.html).
let COLUMN_W = 480.0;       // the list in landscape: five tiles a tap wide, TILE_GAP apart
let COLUMN_IN = 32.0;       // the column's glass round it, its left edge off the screen
let TOP = 16.0;             // above the title row
let HEAD_GAP = 8.0;         // under it, where the list's view starts
let SIDE = 24.0;            // portrait: the sheet's room either side of the list,
let SIDE_PHONE = 16.0;      // a phone's
// Portrait: the preview's band at the top, a share of the safe area's height: the list
// scrolls, and the board needn't be large to show the look.
let BAND = 0.4;
let BAND_PHONE = 0.3;
let SECTION_TOP = 6.0;      // above a section's title,
let SECTION_H = 40.0;       // its icon and title,
let SECTION_END = 14.0;     // under its last row, and again under the rule after it
let NAME_H = 34.0;          // a setting's dim name over its tiles
let TILE_GAP = 10.0;
// A row of pictures closes its gaps down to this before it wraps: the five across a phone
// in portrait (the iPhone 13 mini's 468 dp, 7 dp apart).
let LEAST_GAP = 2.0;
let PIC_W = 76.0;           // a picture tile's picture (scene::THUMB_W × THUMB_H's shape)
let PIC_H = 50.0;
let PIC_IN = 6.0;           // gui::choice's room round it
let MINI_BOARD = 40.0;      // the flat board's tile: a small board at the start on a faint picture
let KING_PIC = 34.0;        // the crown's and the stack's tiles: their king
let NOTE_TOP = 6.0;         // between the move list's tiles and their note
let SHIELD = 22.0;          // the privacy note's shield,
let SHIELD_GAP = 10.0;      // and its gap to the words
let FOOT_GAP = 16.0;        // under the privacy note, over the screen's inset
let FADE = 72.0;            // dp at the list's foot over which a row fades out, as home's
let SLACK = 0.5;            // px a row may pass its width by without wrapping
// The preview's share of the room it is given, each way: the rest a margin round it.
// preview_room's 0.03 is half of what is left.
let PREVIEW_SHARE = 0.94;

// The settings in the list's order, each one's name and how many tiles; the first four
// are the look's, the last two the game's.
let BACKGROUND_ROW = 0;
let THEME_ROW = 1;
let BOARD_ROW = 2;
let KINGS_ROW = 3;
let HINTS_ROW = 4;
let MOVES_ROW = 5;
let ROWS = 6;
let LOOK_ROWS = 4;
let ROW_NAMES = [strings::SETTINGS_BACKGROUND, strings::SETTINGS_THEME, strings::SETTINGS_BOARD, strings::SETTINGS_KINGS,
                 strings::SETTINGS_HINTS, strings::SETTINGS_MOVES];
let ROW_TILES = [2, 5, 5, 3, 2, 3];
let MOST_TILES = 5;
let SECTION_ICONS = [gui::SUN, gui::TARGET];
let SECTION_TITLES = [strings::SETTINGS_LOOK, strings::SETTINGS_GAME];

// The Board row's tiles: flat, then raised in the season's own material (MATERIAL_AUTO)
// and in each other one, tile i the material i - 1.
let FLAT_TILE = 0;
let BOARD_WORDS = [strings::BOARD_FLAT, strings::BOARD_RAISED, strings::MATERIAL_WOOD, strings::MATERIAL_STONE,
                   strings::MATERIAL_CARVED];
// The pictures the widgets draw (gui::PICTURE's look.z): the theme shown's photograph and
// fade, its board pictures (its own raised board whole, then its wood's, stone's, and
// carved board's near corner, from -4 down), and the faint picture under the flat board.
let PHOTO_PIC = -2;
let FADE_PIC = -3;
let BOARD_PIC = -4;
let FLAT_PIC = -8;

// Ids, from gui::SETTINGS_IDS: back 0, the language button 1, the languages' rows from 2,
// the catch round their list 6 and under it 7, the tiles from 10 (10 a row), the list 70.
let LANGUAGE_ID = gui::SETTINGS_IDS + 1;
let LANGUAGE_ROWS = gui::SETTINGS_IDS + 2;
let OUTSIDE_ID = gui::SETTINGS_IDS + 6;
let POPUP_ID = gui::SETTINGS_IDS + 7;
let LIST = gui::SETTINGS_IDS + 70;

// Whether a row's tiles are pictures (gui::choice) rather than words.
fn pictured(row: i64) -> bool { row <= BOARD_ROW }

// Tile i of a row's word.
fn word(row: i64, i: i64) -> i64 {
    if row == BACKGROUND_ROW { return [strings::BACKGROUND_PHOTO, strings::BACKGROUND_PLAIN][i]; }
    if row == THEME_ROW { return if i == BY_DATE_TILE { strings::SETTINGS_BY_DATE } else { SEASON_KEYS[i] }; }
    if row == BOARD_ROW { return BOARD_WORDS[i]; }
    if row == KINGS_ROW { return KING_KEYS[i]; }
    if row == HINTS_ROW { return [strings::HINTS_MISTAKES, strings::HINTS_MOVES][i]; }
    return [strings::MOVES_HIDDEN, strings::MOVES_LIST, strings::MOVES_MARKS][i];
}

// What the move list's tile i shows, said under its row for the chosen one: its words
// alone (Off, Moves, Marks) didn't say (task 078).
let MOVES_NOTES = [strings::MOVES_HIDDEN_NOTE, strings::MOVES_LIST_NOTE, strings::MOVES_MARKS_NOTE];

// How many lines the move list's notes take at most at width w, so the list keeps one
// height whichever is chosen.
fn moves_note_lines(g: gui::Gui&, w: f32) -> i64 {
    var n = 0;
    for k in MOVES_NOTES { n = max(n, note_lines(g, strings::get(k), float4 { 0.0, 0.0, w, 0.0 }, false)); }
    return n;
}

// How wide tile i of a row is, at least a tap: a picture tile its picture or its word in
// the small face, whichever is wider, and PIC_IN either side; a word's its word with
// gui::side() either side.
fn tile_width(g: gui::Gui&, row: i64, i: i64) -> f32 {
    let u = g.scale;
    let label = strings::get(word(row, i));
    if pictured(row) { return max(gui::tap() * u, max(PIC_W * u, gui::text_width(g, gui::SMALL, label)) + 2.0 * PIC_IN * u); }
    return max(gui::tap() * u, gui::text_width(g, gui::BODY, label) + 2.0 * gui::side() * u);
}

// Whether tile i of a row is the one chosen in s.
fn chosen(s: Settings&, row: i64, i: i64) -> bool {
    if row == BACKGROUND_ROW { return s.plain == (i == 1); }
    if row == THEME_ROW { return s.season == (if i == BY_DATE_TILE { BY_DATE } else { SEASON_KINDS[i] }); }
    if row == BOARD_ROW { return if i == FLAT_TILE { s.board == FLAT } else { s.board == RAISED && s.material == i - 1 }; }
    if row == KINGS_ROW { return s.kings == i; }
    if row == HINTS_ROW { return s.hints == i; }
    return s.moves == i;
}

// Chooses tile i of a row in s.
fn choose(s: Settings&, row: i64, i: i64) {
    if row == BACKGROUND_ROW { s.plain = i == 1; }
    if row == THEME_ROW { s.season = if i == BY_DATE_TILE { BY_DATE } else { SEASON_KINDS[i] }; }
    if row == BOARD_ROW {
        s.board = if i == FLAT_TILE { FLAT } else { RAISED };
        if i != FLAT_TILE { s.material = i - 1; }
    }
    if row == KINGS_ROW { s.kings = i; }
    if row == HINTS_ROW { s.hints = i; }
    if row == MOVES_ROW { s.moves = i; }
}

// The picture tile i of a row shows (the widgets' look.z): the background's the theme
// shown's photograph or fade; a season's its photograph, or with plain its fade (4 on), by
// the date's the glow's tint with a sun (-1); the board's the theme shown's.
fn picture_of(s: Settings&, row: i64, i: i64) -> i64 {
    if row == BACKGROUND_ROW { return if i == 0 { PHOTO_PIC } else { FADE_PIC }; }
    if row == THEME_ROW {
        let kind = if i == BY_DATE_TILE { BY_DATE } else { SEASON_KINDS[i] };
        return if kind >= 0 && s.plain { kind + 4 } else { kind };
    }
    return if i == FLAT_TILE { FLAT_PIC } else { BOARD_PIC - (i - 1) };
}

// Declares tile i of a row in r. True when a tap changed s.
fn tile(s: Settings&, over: board::Overlay&, g: gui::Gui&, row: i64, i: i64, r: float4) -> bool {
    let u = g.scale;
    let id = gui::SETTINGS_IDS + 10 + 10 * row + i;
    let label = strings::get(word(row, i));
    let on = chosen(s, row, i);
    var tapped = false;
    if pictured(row) {
        let size = float2 { PIC_W * u, PIC_H * u };
        tapped = gui::choice(g, id, r, picture_of(s, row, i), size, label, on, true);
        let pic = gui::choice_picture(g, r, size);
        // The flat board: a small board at the start; the raised one in the season's own
        // material says so.
        if row == BOARD_ROW && i == FLAT_TILE { gui::mini(g, pic, MINI_BOARD * u, 8, 3, 1.0); }
        if row == BOARD_ROW && i == FLAT_TILE + 1 { gui::tag(g, pic, strings::get(strings::MATERIAL_AUTO)); }
    } else {
        // The crown's and the stack's tiles each show their king.
        let king = row == KINGS_ROW && i != AUTO;
        let picked, pic = gui::pick(g, id, r, if king { KING_PIC } else { 0.0 }, label, "", on, true);
        if king { game::put(over, pic, 15.0 * u, rules::WHITE, i, 1.0, false); }
        tapped = picked;
    }
    guard tapped else { return false; }
    choose(s, row, i);
    return true;
}

// Where a row's tiles go, from r's top left across its width, into `at`; returns how tall
// they are. They keep TILE_GAP apart on one line; a row of pictures that doesn't fit so
// closes its gaps down to LEAST_GAP first; else they wrap.
fn lay(g: gui::Gui&, row: i64, r: float4, at: float4[:]) -> f32 {
    let u = g.scale;
    let h = gui::stacked() * u;
    let n = ROW_TILES[row];
    var sum: f32 = 0.0;
    for i in n { sum += min(tile_width(g, row, i), r.z); }
    var gap = TILE_GAP * u;
    if pictured(row) && sum + (n - 1) * gap > r.z + SLACK { gap = max(LEAST_GAP * u, (r.z - sum) / (n - 1)); }
    if sum + (n - 1) * gap > r.z + SLACK { gap = TILE_GAP * u; }
    var x: f32 = 0.0;
    var y: f32 = 0.0;
    for i in n {
        let w = min(tile_width(g, row, i), r.z);
        if x > 0.0 && x + w > r.z + SLACK {
            x = 0.0;
            y += h + TILE_GAP * u;
        }
        at[i] = float4 { r.x + x, r.y + y, w, h };
        x += w + gap;
    }
    return y + h;
}

// Where the list's parts go (list_at), from its top: each section's title and the rule
// after it, each setting's dim name and its tiles, the move list's note, the privacy
// note (its shield at its left), and how tall it all is.
struct Row {
    name:  float4             = float4 { 0.0, 0.0, 0.0, 0.0 },
    tiles: float4[MOST_TILES] = [float4 { 0.0, 0.0, 0.0, 0.0 }; MOST_TILES],
}
struct List {
    title:   float4[2] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 2],
    rule:    float4[2] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 2],
    row:     Row[ROWS] = [Row {}; ROWS],
    says:    float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    privacy: float4    = float4 { 0.0, 0.0, 0.0, 0.0 },
    h:       f32       = 0.0,
}

// The list from r's top left, as wide as r.
fn list_at(g: gui::Gui&, r: float4) -> List {
    let u = g.scale;
    let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    var l = List {};
    var y = r.y;
    for section in 2 {
        y += SECTION_TOP * u;
        l.title[section] = float4 { r.x, y, r.z, SECTION_H * u };
        y += SECTION_H * u;
        let first = if section == 0 { 0 } else { LOOK_ROWS };
        let end = if section == 0 { LOOK_ROWS } else { ROWS };
        for row in first..end {
            let at .= l.row[row];
            at.name = float4 { r.x + 4.0 * u, y + (NAME_H - 24.0) * u, r.z - 4.0 * u, 24.0 * u };
            y += NAME_H * u;
            y += lay(g, row, float4 { r.x, y, r.z, 0.0 }, at.tiles);
        }
        if section == 1 {
            let n = moves_note_lines(g, r.z - 8.0 * u);
            l.says = float4 { r.x + 4.0 * u, y + NOTE_TOP * u, r.z - 8.0 * u, n * line };
            y += NOTE_TOP * u + n * line;
        }
        y += SECTION_END * u;
        l.rule[section] = float4 { r.x, y, r.z, max(1.0, floor(u + 0.5)) };
        y += l.rule[section].w + SECTION_END * u;
    }
    let text_x = (4.0 + SHIELD + SHIELD_GAP) * u;
    let n = note_lines(g, strings::get(strings::SETTINGS_PRIVACY), float4 { 0.0, 0.0, r.z - text_x, 0.0 }, false);
    l.privacy = float4 { r.x + text_x, y, r.z - text_x, n * line };
    y += n * line + FOOT_GAP * u;
    l.h = y - r.y;
    return l;
}

// Declares the list where list_at put it. True when a tap changed s.
fn list(s: Settings&, over: board::Overlay&, g: gui::Gui&, l: List&) -> bool {
    let u = g.scale;
    var changed = false;
    for section in 2 {
        var title = l.title[section];
        gui::glyph_icon(g, gui::center(gui::cut_left(title, 30.0 * u), 28.0 * u, 28.0 * u), SECTION_ICONS[section],
                        gui::PLAIN, 0.0, 0.85);
        gui::cut_left(title, gui::PAD * u);
        gui::text(g, gui::HEADING, title, strings::get(SECTION_TITLES[section]), 1.0, 0.0, gui::LEFT);
        let first = if section == 0 { 0 } else { LOOK_ROWS };
        let end = if section == 0 { LOOK_ROWS } else { ROWS };
        for row in first..end {
            let at .= l.row[row];
            gui::text(g, gui::SMALL, at.name, strings::get(ROW_NAMES[row]), 0.66, 0.03 * gui::FACE_DP[gui::SMALL] as f32 * u,
                      gui::LEFT);
            for i in ROW_TILES[row] { if tile(s, over, g, row, i, at.tiles[i]) { changed = true; } }
        }
        gui::fill(g, l.rule[section], float4 { 1.0, 1.0, 1.0, 0.1 }, 0.0);
    }
    note_lines(g, strings::get(MOVES_NOTES[clamp(s.moves, 0, 2)]), l.says, true);
    // The privacy note (App Review Guideline 5.1.1(i); store/app-store.md): what the app
    // collects, nothing, dim as the settings' names, under its shield. No link out: the
    // app opens none.
    let p = l.privacy;
    let icon = SHIELD * u;
    gui::glyph_icon(g, float4 { p.x - (SHIELD + SHIELD_GAP) * u, p.y, icon, icon }, gui::SHIELD, gui::PLAIN, 0.0, NOTE_A);
    note_lines(g, strings::get(strings::SETTINGS_PRIVACY), p, true);
    return changed;
}

// The notes' opacity: the move list's and the privacy note, dim as the settings' names.
let NOTE_A = 0.66;

// Text s wrapped at whole words to r's width, `align`ed in it: how many lines, each a
// small face's height; drawn from r's top when `draw`.
fn note_lines(g: gui::Gui&, s: const u8[:], r: float4, draw: bool, align: i64 = gui::LEFT) -> i64 {
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

// The language button (prototypes/settings.html, &langui=menu, the globe b): a tile a tap
// tall holding a wireframe globe, the shown language's code, and a chevron down; its list
// below it, each language a row a tap tall: its code, its name in itself, and a tick on
// the one shown.
let GLOBE = 28.0;
let CHEVRON = 20.0;
let BUTTON_IN = 16.0;       // the button's room at its left, 14 at its right,
let BUTTON_GAP = 8.0;       // and between its parts
let POPUP_W = 220.0;        // the list's least width,
let POPUP_GAP = 4.0;        // its gap under the button,
let POPUP_IN = 6.0;         // its glass round its rows,
let ROW_IN = 16.0;          // a row's room either side,
let CODE_W = 40.0;          // its code's cell,
let TICK = 24.0;            // and its tick

// A language's code as its button and list show it, "EN", from strings::LANGUAGES.
fn code(lang: i64) -> u8[..8] {
    var c: u8[..8] = [];
    for ch in strings::LANGUAGES[lang] { if c.len < 8 { c.push(if ch >= 'a' && ch <= 'z' { ch - 32 } else { ch }); } }
    return c;
}

// How wide the language button is: the globe, the widest code in the body face, the
// chevron, and their room.
fn language_width(g: gui::Gui&) -> f32 {
    var widest: f32 = 0.0;
    for i in strings::LANGUAGES.len {
        let c = code(i);
        widest = max(widest, gui::text_width(g, gui::BODY, c[..]));
    }
    return (BUTTON_IN + GLOBE + CHEVRON + 2.0 * BUTTON_GAP + 14.0) * g.scale + widest;
}

// The language button in r, `shown` the language showing; true when tapped.
fn language_button(g: gui::Gui&, r: float4, shown: i64, open: bool) -> bool {
    let u = g.scale;
    gui::glass(g, r, 22.0);
    let tapped, p = gui::hold(g, LANGUAGE_ID, r);
    gui::add(g, gui::Quad { rect: r, look: float4 { gui::BUTTON, 22.0 * u, 0.0, p },
                            extra: float4 { u, if open { gui::CHOSEN } else { gui::PLAIN }, gui::hover(g, LANGUAGE_ID), 0.0 } });
    var c = r;
    gui::cut_left(c, BUTTON_IN * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(c, GLOBE * u), GLOBE * u, GLOBE * u), gui::GLOBE, gui::PLAIN, p, 0.85);
    gui::cut_left(c, BUTTON_GAP * u);
    gui::cut_right(c, 14.0 * u);
    gui::glyph_icon(g, gui::center(gui::cut_right(c, CHEVRON * u), CHEVRON * u, CHEVRON * u), gui::CHEVRON_DOWN, gui::PLAIN, p,
                    0.7);
    gui::cut_right(c, BUTTON_GAP * u);
    let shown_code = code(shown);
    gui::text(g, gui::BODY, c, shown_code[..], 1.0, 0.05 * gui::FACE_DP[gui::BODY] as f32 * u, gui::LEFT);
    return tapped;
}

// Where the language list goes under the button `button`, its right edge with the
// button's.
fn popup_rect(g: gui::Gui&, button: float4) -> float4 {
    let u = g.scale;
    var w = POPUP_W * u;
    for i in strings::LANGUAGES.len {
        w = max(w, (2.0 * ROW_IN + CODE_W + TICK + 2.0 * POPUP_IN + 14.0) * u
                   + gui::text_width(g, gui::BODY, strings::name_of(i)));
    }
    let h = strings::LANGUAGES.len * gui::tap() * u + 2.0 * POPUP_IN * u;
    return float4 { button.x + button.z - w, button.y + button.w + POPUP_GAP * u, w, h };
}

// The language list over the screen `screen`, under the button: a tap on a language
// switches to it, one outside closes the list. Returns CHANGED, SHOWN, or NOTHING.
fn languages(s: Settings&, g: gui::Gui&, button: float4, screen: float4, shown: i64) -> i64 {
    let u = g.scale;
    let outside, unused_o = gui::hold(g, OUTSIDE_ID, screen, false);
    let r = popup_rect(g, button);
    gui::glass(g, r, 20.0);
    gui::hold(g, POPUP_ID, r, false);
    var ask = NOTHING;
    var rows = gui::inset(r, POPUP_IN * u);
    for i in strings::LANGUAGES.len {
        let row = gui::cut_top(rows, gui::tap() * u);
        let id = LANGUAGE_ROWS + i;
        let tapped, p = gui::hold(g, id, row);
        let on = i == shown;
        gui::add(g, gui::Quad { rect: row, look: float4 { gui::BUTTON, 14.0 * u, 0.0, p },
                                extra: float4 { u, if on { gui::ROW_PRIMARY } else { gui::ROW }, gui::hover(g, id), 0.0 } });
        var c = row;
        gui::cut_left(c, ROW_IN * u);
        gui::cut_right(c, ROW_IN * u);
        let lang_code = code(i);
        gui::text(g, gui::SMALL, gui::cut_left(c, CODE_W * u), lang_code[..], NOTE_A, 0.05 * gui::FACE_DP[gui::SMALL] as f32 * u,
                  gui::LEFT);
        if on { gui::glyph_icon(g, gui::center(gui::cut_right(c, TICK * u), TICK * u, TICK * u), gui::CHECK, gui::ON, 0.0, 1.0); }
        gui::text(g, gui::BODY, c, strings::name_of(i), 1.0, 0.0, gui::LEFT);
        if tapped {
            s.languages_open = false;
            if on { return SHOWN; }
            s.language = i;
            return CHANGED;
        }
    }
    if outside {
        s.languages_open = false;
        ask = SHOWN;
    }
    return ask;
}

// The title row in r: back, the title, and the language button at its right end. Where
// the title doesn't fit beside a worded back in the row labels' face (a phone's
// portrait), back is the arrow over the word in a tap square; the title then takes a
// smaller face where it is too wide for its room, or none where even that is. Returns
// BACK, SHOWN (the language list opened or closed), or NOTHING; sets `button` to where the
// language button is.
fn head(s: Settings&, g: gui::Gui&, r: float4, shown: i64, button: float4&) -> i64 {
    let u = g.scale;
    var row = r;
    var ask = NOTHING;
    let title = strings::get(strings::HOME_SETTINGS);
    let wide = gui::back_width(g, strings::get(strings::NAV_BACK));
    let lw = language_width(g);
    let stacked = r.z - wide - 40.0 * u - lw < gui::text_width(g, gui::LABEL, title);
    let bw = if stacked { gui::tap() * u } else { wide };
    let back = gui::center(gui::cut_left(row, bw), bw, gui::tap() * u);
    if gui::back(g, gui::SETTINGS_IDS, back, strings::get(strings::NAV_BACK), stacked) { ask = BACK; }
    gui::cut_left(row, 20.0 * u);
    button = gui::center(gui::cut_right(row, lw), lw, gui::tap() * u);
    if language_button(g, button, shown, s.languages_open) {
        s.languages_open = !s.languages_open;
        ask = SHOWN;
    }
    gui::cut_right(row, 20.0 * u);
    let face = gui::fitting(g, gui::LABEL, title, row.z);
    if gui::text_width(g, face, title) <= row.z { gui::text(g, face, row, title, 1.0, 0.0, gui::LEFT); }
    return ask;
}

// Where a 3D preview may go in `page`: PREVIEW_SHARE of it each way, as the flat square
// takes PREVIEW_SHARE of its shorter side; nothing where the flat preview isn't shown
// (`size` 0).
fn preview_room(page: float4, size: f32) -> float4 {
    guard size > 0.0 else { return float4 { page.x + 0.5 * page.z, page.y + 0.5 * page.w, 0.0, 0.0 }; }
    return float4 { page.x + 0.03 * page.z, page.y + 0.03 * page.w, PREVIEW_SHARE * page.z, PREVIEW_SHARE * page.w };
}

// Where the screen's parts go in `area`, the screen's safe area (layout): the glass, the
// column at the left in landscape or the sheet under the preview's band in portrait,
// before it runs on to the screen's edges (gui::bleed); the title row (`head`); the list,
// its content's left and width (`list`, x and z) and its view, from under the title row
// to the screen's foot (`view`); and the preview, `board`, and `room3d` where a 3D
// preview goes instead.
struct Page {
    glass:  float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    head:   float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    list:   float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    view:   float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
    board:  board::Layout = board::layout_at(0.0, 0.0, 0.0, 1.0, 8),
    room3d: float4        = float4 { 0.0, 0.0, 0.0, 0.0 },
}

// Where the screen's parts go in `area` (Page). It declares nothing and changes nothing.
fn layout(s: Settings&, g: gui::Gui&, area: float4) -> Page {
    let u = g.scale;
    let n = rules::VARIANTS[s.variant].size;
    var p = Page {};
    var page = area;
    if area.z >= area.w {
        // The column, COLUMN_W of list with COLUMN_IN round it, its left corners off the
        // screen; the preview in the rest.
        let x = area.x + COLUMN_IN * u;
        p.glass = float4 { area.x - COLUMN_IN * u, area.y, (COLUMN_W + 3.0 * COLUMN_IN) * u, area.w };
        p.head = float4 { x, area.y + TOP * u, COLUMN_W * u, gui::tap() * u };
        let right = p.glass.x + p.glass.z;
        page = float4 { right, area.y, area.x + area.z - right, area.w };
    } else {
        // The preview's band at the top, the sheet under it, its lower corners off the
        // screen.
        let phone = gui::phone(area, u);
        let band = floor((if phone { BAND_PHONE } else { BAND }) * area.w + 0.5);
        let side = (if phone { SIDE_PHONE } else { SIDE }) * u;
        p.glass = float4 { area.x, area.y + band, area.z, area.w - band + 32.0 * u };
        p.head = float4 { area.x + side, area.y + band + TOP * u, area.z - 2.0 * side, gui::tap() * u };
        page = float4 { area.x, area.y, area.z, band };
    }
    let top = p.head.y + p.head.w + HEAD_GAP * u;
    p.list = float4 { p.head.x, top, p.head.z, 0.0 };
    p.view = float4 { p.glass.x, top, p.glass.z, area.y + area.w + g.insets.w - top };
    var size = PREVIEW_SHARE * min(page.z, page.w);
    if size < board::SMALLEST * u { size = 0.0; }
    p.board = board::layout_at(page.x + 0.5 * (page.z - size), page.y + 0.5 * (page.w - size), size, u, n);
    p.room3d = preview_room(page, size);
    return p;
}

// Declares the screen for this frame in `area`, the screen's safe area, where layout puts
// its parts, with `shown` the language showing, and sets l to where the preview goes, and
// `room3d` to where a 3D preview goes instead. The kings' tiles put their pieces in
// `over`. Returns BACK, CHANGED after a tap changed s, SHOWN after the language list
// opened or closed, or NOTHING.
fn frame(s: Settings&, over: board::Overlay&, g: gui::Gui&, l: board::Layout&, area: float4, shown: i64,
         room3d: float4&) -> i64 {
    let u = g.scale;
    over.clear();
    let p = layout(s, g, area);
    l = p.board;
    room3d = p.room3d;
    gui::glass(g, gui::bleed(g, p.glass, area), 32.0);
    var button = float4 { 0.0, 0.0, 0.0, 0.0 };
    var ask = head(s, g, p.head, shown, button);
    // The list, under the title row down to the screen's foot, the inset under the safe
    // area too, so its last row clears the inset once scrolled to the end.
    let at = list_at(g, p.list);
    let content = at.h + g.insets.w;
    let off = gui::scroll_begin(g, LIST, p.view, content);
    let listed = g.quads.len;
    let laid = list_at(g, float4 { p.list.x, p.list.y - off, p.list.z, 0.0 });
    if list(s, over, g, laid) { ask = CHANGED; }
    gui::fade_edges(g, listed, p.view, 0.0, p.view.y + content - off - (p.view.y + p.view.w), FADE * u);
    gui::scroll_end(g);
    if s.languages_open {
        let e = g.insets;
        let screen = float4 { area.x - e.x, area.y - e.y, area.z + e.x + e.z, area.w + e.y + e.w };
        let picked = languages(s, g, button, screen, shown);
        if picked != NOTHING { ask = picked; }
    }
    return ask;
}
