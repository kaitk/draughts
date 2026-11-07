// Settings (prototypes/settings.html): the background (by the date, or one season), the
// board (2D; 3D once task 015 exists), move hints, and the language, each a glass group
// with a title and tiles. A tap applies at once; there is no save button. The values
// are kept across runs as a small text file, one `key = value` per line, which the app
// reads at start and writes after a change.
namespace settings;
import std;
import vec;

import board from "../board";
import gui from "../gui";
import strings from "../strings";

// The board themes by season, as app/theme.goose numbers them, in the order the tiles
// show the seasons: winter stone, spring birch, summer sea, autumn wood.
let SEASON_KINDS = [1, 2, 3, 0];
let SEASON_KEYS = [strings::SEASON_WINTER, strings::SEASON_SPRING, strings::SEASON_SUMMER, strings::SEASON_AUTUMN];
let SEASON_NAMES = ["winter", "spring", "summer", "autumn"];
let BY_DATE = -1;
let FLAT = 0;                   // the 2D board
let RAISED = 1;                 // the 3D board (task 015)
let SYSTEM = -1;                // the language the system's locales pick

struct Settings {
    season:   i64 = BY_DATE,    // a theme (app/theme.goose), or BY_DATE
    board:    i64 = FLAT,
    hints:    i64 = board::MISTAKES,
    language: i64 = SYSTEM,     // strings::EN.., or SYSTEM
}

// What the screen asks for.
let NOTHING = 0;
let BACK = 1;
let CHANGED = 2;

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
        if key == "language" {
            for name, i in strings::LANGUAGES { if value == name { s.language = i; } }
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
    out.append("\nlanguage = ");
    out.append(if s.language >= 0 { strings::LANGUAGES[s.language] } else { "system" });
    out.append("\n");
}

// Declares the screen for this frame on a screen width × height pixels, with `shown`
// the language showing. Returns BACK, CHANGED after a tap changed s, or NOTHING.
fn frame(s: Settings&, g: gui::Gui&, width: f32, height: f32, shown: i64) -> i64 {
    let u = min(width, height) / 800.0;
    let landscape = width >= height;
    var page = float4 { 32.0 * u, 24.0 * u, width - 64.0 * u, height - 48.0 * u };
    var ask = NOTHING;
    // Back, a glass tile at the top left.
    let back = float4 { page.x, page.y, 88.0 * u, 88.0 * u };
    gui::glass(g, back, 22.0);
    if gui::button(g, 400, back, gui::BACK) { ask = BACK; }
    // The groups: right of back in landscape, at most 980 dp wide; under it in portrait,
    // a title over its tiles. Pictures 104 × 64 dp, 88 × 56 in portrait.
    if landscape {
        gui::cut_left(page, 112.0 * u);
        page.z = min(page.z, 980.0 * u);
    } else {
        gui::cut_top(page, 112.0 * u);
    }
    let pic_w = (if landscape { 104.0 } else { 88.0 }) * u;
    let pic_h = (if landscape { 64.0 } else { 56.0 }) * u;
    let pics = pic_h + 39.0 * u;            // a picture tile: the picture, its label, padding
    let words = 64.0 * u;
    let head = if landscape { 0.0 } else { 46.0 * u };
    let heights = [pics + head + 32.0 * u, words + head + 32.0 * u, words + head + 32.0 * u, words + head + 32.0 * u];
    var total = 3.0 * 14.0 * u;
    for h in heights { total += h; }
    var list = gui::center(page, page.z, total);
    let icons = [gui::SUN, gui::DOTS, gui::TARGET, gui::GLOBE];
    let titles = [strings::SETTINGS_BACKGROUND, strings::SETTINGS_BOARD, strings::SETTINGS_HINTS,
                  strings::SETTINGS_LANGUAGE];
    for group in 4 {
        let r = gui::cut_top(list, heights[group]);
        gui::cut_top(list, 14.0 * u);
        gui::glass(g, r, 24.0);
        var c = float4 { r.x + 20.0 * u, r.y + 16.0 * u, r.z - 40.0 * u, r.w - 32.0 * u };
        var title = if landscape { gui::cut_left(c, 200.0 * u) } else { gui::cut_top(c, 34.0 * u) };
        if landscape { gui::cut_left(c, 20.0 * u); } else { gui::cut_top(c, 12.0 * u); }
        title = gui::center(title, title.z, 34.0 * u);
        gui::glyph_icon(g, gui::cut_left(title, 34.0 * u), icons[group], gui::PLAIN, 0.0, 0.85);
        gui::cut_left(title, 14.0 * u);
        gui::text(g, gui::HEADING, title, strings::get(titles[group]), 1.0, 0.0, gui::LEFT);
        // The tiles, left to right.
        var x = c.x;
        let id = 410 + 10 * group;
        if group == 0 {
            // By the date, then the four seasons; a tile as wide as its picture, or its
            // label where that is wider.
            for i in 5 {
                let kind = if i == 0 { BY_DATE } else { SEASON_KINDS[i - 1] };
                let label = strings::get(if i == 0 { strings::SETTINGS_BY_DATE } else { SEASON_KEYS[i - 1] });
                let w = max(pic_w + 12.0 * u, gui::text_width(g, gui::SMALL, label, 0.0) + 16.0 * u);
                if gui::choice(g, id + i, float4 { x, c.y, w, pics }, kind, float2 { pic_w, pic_h }, label,
                               s.season == kind, true) {
                    s.season = kind;
                    ask = CHANGED;
                }
                x += w + 12.0 * u;
            }
        } else {
            // Words: at least a picture's width, 18 dp either side of the word.
            for i in 2 {
                let key = if group == 1 { [strings::BOARD_FLAT, strings::BOARD_RAISED][i] }
                          else if group == 2 { [strings::HINTS_MISTAKES, strings::HINTS_MOVES][i] }
                          else { -1 };
                let word = if key >= 0 { strings::get(key) } else { strings::name_of(i) };
                let w = max(104.0 * u, gui::text_width(g, gui::BODY, word, 0.0) + 36.0 * u);
                let on = if group == 1 { s.board == i } else if group == 2 { s.hints == i } else { shown == i };
                // The 3D board is task 015.
                let enabled = group != 1 || i == FLAT;
                if gui::choice(g, id + i, float4 { x, c.y, w, words }, -2, float2 { 0.0, 0.0 }, word, on, enabled) {
                    if group == 1 { s.board = i; }
                    if group == 2 { s.hints = i; }
                    if group == 3 { s.language = i; }
                    ask = CHANGED;
                }
                x += w + 12.0 * u;
            }
        }
    }
    return ask;
}
