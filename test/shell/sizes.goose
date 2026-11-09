// Every screen at other proportions than the tablet's (task 030), headless: a foldable's
// near-square inner screen, a 4:3 tablet, and a 20:9 phone, each in both orientations,
// in English and Estonian; and the phone's layout at 540 and 480 dp across its shorter
// side (gui::short_dp, the phone scale's floor), with a 9:16 phone at 480, the tightest.
// On each, every tile lies inside the screen and no two overlap; the board lies inside
// it too, clear of the tiles (the win card's excepted, which sits on the board); every
// tile that takes a tap keeps the 88 dp a small hand needs (the clocks only show), but
// settings' theme switch, whose halves are given on their own: 88 dp square beside the
// theme's name where it is above the tiles, under it in the name's column where it is
// at their left, where they don't fit (shell/settings.goose). A line
// per screen gives its tiles, the smallest tap across and down in dp, and the board in
// dp (0 where none shows), so a layout that moves shows here. The words are the test
// faces' (each character half its face wide), wider than the real font's, so a word
// that fits here fits on screen. The phones again with the Pixel 7a's insets (its
// camera's cutout at the top in portrait and at a side in landscape, either side, and
// its gesture bar at the bottom): every tile and the board inside the safe area, but a
// scrolling list's rows past its foot (the puzzles' library on a 9:16 phone); and
// the 16:10 tablet with its hidden navigation bar at the bottom, and the 13" and 11"
// iPad's landscape with their status bar and home indicator, settings keeping both
// groups on each. Then a phone's tabs:
// settings' Look tab and the puzzles' crown each show their own tiles. A puzzle's turn
// piece lies in its panel clear of the tiles, icons, and words, over the goal where the
// panel has the room and beside its icon where not. On the game, flat and 3D, what each
// side has taken late in a game (task 052) lies inside the safe area clear of the tiles,
// the camera buttons, and the board, and the flat screen's panels are the 3D one's
// (task 054), or the line says how they differ; the iPad's smallest window too.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn overlaps(a: float4, b: float4) -> bool {
    let e: f32 = 0.5;           // px: tiles that only touch don't overlap
    return a.x + e < b.x + b.z && b.x + e < a.x + a.z && a.y + e < b.y + b.w && b.y + e < a.y + a.w;
}

// Whether r lies inside a, a rect.
fn inside(r: float4, a: float4) -> bool {
    return r.x >= a.x - 0.5 && r.y >= a.y - 0.5 && r.x + r.z <= a.x + a.z + 0.5 && r.y + r.w <= a.y + a.w + 0.5;
}

fn whole(x: f32) -> i64 { floor(x + 0.5) as i64 }

// The style of the n-th tile the last frame declared, as drive::rect counts them.
fn style(g: gui::Gui&, n: i64) -> f32 {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        if k == n { return q.extra.y; }
        k++;
    }
    return -1.0;
}

// Whether the n-th tile is in a scrolling list (gui::scroll_begin), drawn only inside its
// view: the rows past its foot are reached by scrolling.
fn listed(g: gui::Gui&, n: i64) -> bool {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        if k == n { return q.extra.z >= gui::CLIP; }
        k++;
    }
    return false;
}

// What the last frame declared on screen `what`: its tiles, the smallest tap across and
// down, the board, and anything out of place. `board_shows` when the screen has a board,
// `card` when the win's card sits on it.
fn report(what: const u8[:], g: gui::Gui&, sh: shell::Shell&, board_shows: bool, card: bool) {
    let w = drive::size.x;
    let h = drive::size.y;
    let u = gui::scale_of(w, h);
    let safe = gui::safe(g, w, h);
    let n = drive::tiles(g);
    var line = str("  ", what, ": ", n, " tiles");
    var narrow: f32     = 1.0e9;
    var low:    f32     = 1.0e9;
    var wrong:  u8[>..] = [];
    let b = float4 { sh.layout.board.x, sh.layout.board.y, sh.layout.board.z, sh.layout.board.z };
    var small = 0;
    let sw = sh.prefs.switch_at;
    var half = float2 { 0.0, 0.0 };
    for i in n {
        let r = drive::rect(g, i);
        let tap = style(g, i) < gui::CLOCK_RUN;
        let switched = sh.screen == shell::SETTINGS && sw.z > 0.0 && inside(r, sw);
        if switched { half = float2 { r.z, r.w }; }
        if tap && !switched {
            narrow = min(narrow, r.z);
            low = min(low, r.w);
        }
        // A list's rows past the safe area's foot scroll into it (the puzzles' library).
        let below = listed(g, i) && r.y >= safe.y && r.x >= safe.x && r.x + r.z <= safe.x + safe.z;
        if !inside(r, safe) && !below { format(wrong, " tile ", i, " off the safe area;"); }
        for j in i { if overlaps(r, drive::rect(g, j)) { format(wrong, " tiles ", j, " and ", i, " overlap;"); } }
        if board_shows && b.z > 0.0 && overlaps(r, b) && !(card && i >= n - 2) { format(wrong, " tile ", i, " on the board;"); }
        if tap && !switched && (r.z < 88.0 * u - 0.5 || r.w < 88.0 * u - 0.5) { small++; }
    }
    if small > 0 { format(wrong, " ", small, " taps under 88 dp;"); }
    format(line, ", smallest ", whole(narrow / u), " x ", whole(low / u), " dp");
    if half.x > 0.0 { format(line, ", the theme's switch ", whole(half.x / u), " x ", whole(half.y / u), " dp a half"); }
    if board_shows {
        format(line, ", board ", whole(b.z / u), " dp");
        if b.z > 0.0 && !inside(b, safe) { wrong.append(" the board off the safe area;"); }
    }
    if card {
        // The card's two buttons, on the board.
        let back = drive::rect(g, n - 2);
        format(line, ", card buttons ", whole(back.z / u), " x ", whole(back.w / u), " dp");
        if !inside(back, b) { wrong.append(" the card off the board;"); }
    }
    line.append(if wrong.len > 0 { ";" } else { ", all in place" });
    line.append(wrong);
    print(line);
}

// Home's chip (the last tile but one), with no name and with twelve characters, mirrors
// the way out (the last tile): its top level with the X's, and as far from the left of
// the board's side of the screen as the X is from the screen's right (the safe area's
// left in portrait, the column's right edge in landscape: the first glass the frame
// declares); off the column, the way out, and the board (home::player_spot).
fn chip(g: gui::Gui&, sh: shell::Shell&) {
    let u = g.scale;
    let safe = gui::safe(g, drive::size.x, drive::size.y);
    for named in [false, true] {
        sh.prefs.name.clear();
        if named { sh.prefs.name.append("Wwwwwwwwwwww"); }
        at_rest(sh, g);
        let n = drive::tiles(g);
        let c = drive::rect(g, n - 2);
        let way = drive::rect(g, n - 1);
        var col = float4 { 0.0, 0.0, 0.0, 0.0 };
        for q in g.quads { if q.look.x == gui::GLASS { col = q.rect; break; } }
        let b = sh.layout.board;
        let sq = float4 { b.x, b.y, b.z, b.z };
        var line = str("  home's chip", if named { ", named" } else { "" }, ": ", whole(c.z / u), " dp wide, board ", whole(b.z / u), " dp");
        var wrong: u8[>..] = [];
        if overlaps(c, col) { wrong.append(" on the column;"); }
        if overlaps(c, way) { wrong.append(" on the way out;"); }
        if b.z > 0.0 && overlaps(c, sq) { wrong.append(" on the board;"); }
        let landscape = drive::size.x >= drive::size.y;
        let side = if landscape { col.x + col.z } else { safe.x };
        let inset = safe.x + safe.z - (way.x + way.z);
        if abs(c.y - way.y) > 0.5 { wrong.append(" not level with the X;"); }
        if abs(c.x - side - inset) > 0.5 { wrong.append(" not mirroring the X;"); }
        if b.z > 0.0 && b.x + 0.5 < side { wrong.append(" the board not on its side;"); }
        // The name's glass pill: inside the chip's tap, none without a name.
        var pills = 0;
        for q in g.quads {
            guard q.look.x == gui::GLASS && q.rect.z < c.z else { continue; }
            pills++;
            if q.rect.x < c.x || q.rect.x + q.rect.z > c.x + c.z { wrong.append(" the pill outside the chip;"); }
        }
        if pills != (if named { 1 } else { 0 }) { wrong.append(" the pill wrong;"); }
        line.append(if wrong.len > 0 { ";" } else { ", mirroring the X on the board's side, off the column and the board" });
        line.append(wrong);
        print(line);
    }
    sh.prefs.name.clear();
}

// A puzzle's turn piece, the side to move as the game's: its size in dp, over the goal's
// icon or beside it, inside the safe area and the play's panel (the last glass), and clear
// of every tile, icon, and word the frame declared.
fn turn_piece(g: gui::Gui&, sh: shell::Shell&) {
    let u = g.scale;
    guard sh.over.len == 1 else {
        print("  the turn piece: ", sh.over.len, " pieces over the UI");
        return;
    }
    let p = sh.over[0];
    let r = p.at.z;
    let disc = float4 { p.at.x - r, p.at.y - r, 2.0 * r, 2.0 * r };
    var panel = float4 { 0.0, 0.0, 0.0, 0.0 };
    var goal = float4 { 0.0, 0.0, 0.0, 0.0 };
    var wrong: u8[>..] = [];
    for q in g.quads {
        if q.look.x == gui::GLASS { panel = q.rect; }
        if q.look.x == gui::ICON && (q.look.z == gui::TARGET || q.look.z == gui::CROWN || q.look.z == gui::SHIELD) {
            goal = q.rect;
        }
        let kind = q.look.x;
        if (kind == gui::BUTTON || kind == gui::ICON || kind == gui::TEXT) && overlaps(disc, q.rect) {
            format(wrong, " on a ", if kind == gui::BUTTON { "tile" } else if kind == gui::ICON { "icon" } else { "word" }, ";");
        }
    }
    if !inside(disc, gui::safe(g, drive::size.x, drive::size.y)) { wrong.append(" off the safe area;"); }
    if !inside(disc, panel) { wrong.append(" off the panel;"); }
    let where = if disc.y + disc.w <= goal.y + 0.5 { "over" } else { "beside" };
    print("  the turn piece: ", whole(2.0 * r / u), " dp, ", where, " the goal's icon, side ", p.look.x, ", ring ",
          p.ring.y, if wrong.len > 0 { ";" } else { ", in place" }, wrong);
}

// A shell showing `screen` at rest, home's column showing `setup`.
fn showing(screen: i64, setup: i64) -> shell::Shell {
    var sh = shell::new(rules::INTERNATIONAL);
    sh.screen = screen;
    sh.setup = setup;
    return sh;
}

fn at_rest(sh: shell::Shell&, g: gui::Gui&) {
    drive::idle(sh, g, 0.0);
    drive::idle(sh, g, 1.0);
}

fn screens(g: gui::Gui&) {
    var home = showing(shell::HOME, home::NOTHING);
    at_rest(home, g);
    report("home", g, home, true, false);
    chip(g, home);
    var friend = showing(shell::HOME, home::FRIEND);
    at_rest(friend, g);
    report("a friend's setup", g, friend, true, false);
    var computer = showing(shell::HOME, home::COMPUTER);
    at_rest(computer, g);
    report("the computer's setup", g, computer, true, false);
    var plain = showing(shell::GAME, home::NOTHING);
    at_rest(plain, g);
    report("the game", g, plain, true, false);
    var clocked = showing(shell::GAME, home::NOTHING);
    game::start(clocked.game, rules::RUSSIAN, clock::RAPID, -1, game::MEDIUM, 50, 0);
    at_rest(clocked, g);
    report("the game on the clock", g, clocked, true, false);
    taken(g);
    var settings = showing(shell::SETTINGS, home::NOTHING);
    at_rest(settings, g);
    report("settings", g, settings, true, false);
    var picker = showing(shell::PICKER, home::NOTHING);
    at_rest(picker, g);
    report("the puzzles", g, picker, false, false);
    // Learn's page, three levels of four, and Shots', the longest: two levels of ten.
    for t in [puzzles::LEARN, puzzles::SHOTS] {
        var page = showing(shell::PICKER, home::NOTHING);
        page.theme = t;
        at_rest(page, g);
        report(if t == puzzles::LEARN { "the puzzles' Learn" } else { "the puzzles' Shots" }, g, page, false, false);
    }
    var one = showing(shell::PUZZLE, home::NOTHING);
    puzzle::open(one.puzzle, 0);
    at_rest(one, g);
    report("a puzzle", g, one, true, false);
    turn_piece(g, one);
    // Black to move with no move left: white has won, and the card comes at once.
    var won = showing(shell::GAME, home::NOTHING);
    won.game = game::new(rules::RUSSIAN);
    let p, ok = rules::parse_fen("B:Wg1:Bh2", rules::RUSSIAN);
    assert(ok);
    board::set(won.game.b, p);
    won.game.turn = won.game.b.pos.side;
    drive::idle(won, g, 0.0);
    drive::idle(won, g, 3.0);
    report("the win", g, won, true, true);
}

// What each side has taken late in a game, 14 white men and a white king and 12 black
// men, on the game screen flat and 3D (task 052): how many pieces show and how many are
// kings, each inside the safe area and clear of every tile, camera button, and the
// board; then whether the flat screen's panels are the 3D screen's (task 054).
fn taken(g: gui::Gui&) {
    let w = drive::size.x;
    let h = drive::size.y;
    let u = gui::scale_of(w, h);
    let safe = gui::safe(g, w, h);
    var line = str("  taken late in a game:");
    for raised in [false, true] {
        var sh = showing(shell::GAME, home::NOTHING);
        if raised { sh.prefs.board = settings::RAISED; }
        let gm .= sh.game;
        gm.taken = panel::Taken { men: [14, 12], kings: [1, 0] };
        gm.taken_len = gm.b.history.len;
        gm.taken_pos = gm.b.pos;
        at_rest(sh, g);
        let b = float4 { sh.layout.board.x, sh.layout.board.y, sh.layout.board.z, sh.layout.board.z };
        var wrong: u8[>..] = [];
        var count = 0;
        var kings = 0;
        for p in sh.over {
            guard p.at.z < 0.5 * panel::TAKEN_D * u + 0.5 else { continue; }
            count++;
            if p.look.y == board::CROWN as f32 { kings++; }
            let r = float4 { p.at.x - p.at.z, p.at.y - p.at.z, 2.0 * p.at.z, 2.0 * p.at.z };
            if !inside(r, safe) { wrong.append(" off the safe area;"); break; }
            var hit = false;
            for i in drive::tiles(g) { if overlaps(r, drive::rect(g, i)) { hit = true; } }
            for q, n in g.quads { if drive::camera_disc(g, n) && overlaps(r, q.rect) { hit = true; } }
            if hit { wrong.append(" on a tile;"); break; }
            let on = if raised { view3d::touches(sh.view, r, 0.0) } else { overlaps(r, b) };
            if on { wrong.append(" on the board;"); break; }
        }
        format(line, if raised { "; 3D " } else { " flat " }, count, " pieces, ", kings, " a king");
        line.append(if wrong.len == 0 { ", in place" } else { "" });
        line.append(wrong);
    }
    let n = 10;
    let fl = panel::layout_in(safe, n, u, true, true);
    let c3 = panel::corners_in(safe, n, u, panel::PITCH_PORTRAIT, true, true);
    // In portrait the bar and the play sit round boards of different heights: their sizes.
    let wide = fl.left.z < fl.left.w;
    let alike = if wide { same(fl.left, c3.left) && same(fl.right, c3.right) }
                else { same(sized(fl.left), sized(c3.left)) && same(sized(fl.right), sized(c3.right)) };
    if alike { line.append("; the panels the 3D screen's"); }
    else {
        format(line, "; the panels ", whole(fl.left.z / u), " x ", whole(fl.left.w / u), " and ", whole(fl.right.z / u), " x ",
               whole(fl.right.w / u), " dp, the 3D screen's ", whole(c3.left.z / u), " x ", whole(c3.left.w / u), " and ",
               whole(c3.right.z / u), " x ", whole(c3.right.w / u));
    }
    print(line);
}

fn sized(r: float4) -> float4 { float4 { 0.0, 0.0, r.z, r.w } }

fn same(a: float4, b: float4) -> bool {
    return abs(a.x - b.x) < 0.5 && abs(a.y - b.y) < 0.5 && abs(a.z - b.z) < 0.5 && abs(a.w - b.w) < 0.5;
}

// The 11" iPad's smallest window (task 050), 374 x 484 pt at 2 px a point with the
// density floor, a 499 x 645 dp compact layout: settings' Look tab, its theme's tiles
// slim, and how far above the glass's foot the Board and Kings rows end (negative: below
// it, reached by scrolling).
fn small_window(g: gui::Gui&) {
    drive::size = float2 { 748.0, 968.0 };
    gui::display_scale = 2.0;
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    let u = g.scale;
    var settings = showing(shell::SETTINGS, home::NOTHING);
    settings.prefs.group = 1;
    at_rest(settings, g);
    var glass = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads { if q.look.x == gui::GLASS { glass = q.rect; } }
    // Back, the two languages, the tabs, the theme's five, the switch's halves, the
    // board's two, the kings' three.
    let season = drive::rect(g, 5);
    let half = drive::rect(g, 10);
    let foot = glass.y + glass.w;
    let board = drive::rect(g, 12);
    let kings = drive::rect(g, 14);
    print("the iPad's smallest window, ", whole(drive::size.x / u), " x ", whole(drive::size.y / u), " dp: Look's ",
          drive::tiles(g), " tiles, the switch ", whole(half.z / u), " x ", whole(half.w / u), " dp a half, a season ",
          whole(season.z / u), " x ", whole(season.w / u), " dp, Board ending ", whole((foot - board.y - board.w) / u),
          " dp above the glass's foot, Kings ", whole((foot - kings.y - kings.w) / u));
    print("the iPad's smallest window, the game:");
    var plain = showing(shell::GAME, home::NOTHING);
    at_rest(plain, g);
    report("the game", g, plain, true, false);
    taken(g);
    gui::display_scale = 0.0;
}

// The game's hand-over from portrait to landscape as a window widens at 800 dp tall
// (panel::landscape): landscape once its flat board takes 2/3 of the height less the
// margins, about 981 dp across; the 3D board takes the same choice. Each width's layout
// and its flat and 3D boards in dp.
fn handover() {
    for w in [892.0, 960.0, 980.0, 1000.0, 1066.0] {
        let area = float4 { 0.0, 0.0, w as f32, 800.0 };
        let fl = panel::layout_in(area, 10, 1.0);
        let c3 = panel::corners_in(area, 10, 1.0);
        let wide = fl.left.z < fl.left.w;
        let wide3 = c3.left.z < c3.left.w;
        print("the game at ", whole(w as f32), " x 800 dp: ", if wide { "landscape" } else { "portrait" }, ", board ",
              whole(fl.board.board.z), " dp; 3D ", if wide3 { "landscape" } else { "portrait" }, ", ", whole(c3.view.rect.z),
              " x ", whole(c3.view.rect.w), " dp");
    }
}

// A phone's tabs, at 480 dp: settings' Look tab shows the look's tiles in place of the
// game's, and the puzzles' Learn row opens Learn's page.
fn tabs(g: gui::Gui&) {
    var settings = showing(shell::SETTINGS, home::NOTHING);
    at_rest(settings, g);
    let game_tiles = drive::tiles(g);
    // Back, the two languages, then the tabs.
    drive::tap(settings, g, drive::tile(g, 4), 2.0);
    drive::idle(settings, g, 2.1);
    print("settings' Look tab: group ", settings.prefs.group, ", tiles ", game_tiles, " then ", drive::tiles(g),
          ", changed ", settings.changed);
    var picker = showing(shell::PICKER, home::NOTHING);
    at_rest(picker, g);
    let rows = drive::tiles(g);
    drive::tap(picker, g, drive::tile(g, drive::LEARN_ROW), 2.0);
    drive::idle(picker, g, 2.1);
    print("the puzzles' Learn row: theme ", picker.theme, ", tiles ", rows, " then ", drive::tiles(g));
}

fn main() {
    puzzles::load();
    var g = gui::Gui {};
    let sizes = [float2 { 2208.0, 1768.0 }, float2 { 1768.0, 2208.0 }, float2 { 2048.0, 1536.0 },
                 float2 { 1536.0, 2048.0 }, float2 { 2400.0, 1080.0 }, float2 { 1080.0, 2400.0 }];
    let names = ["a foldable, landscape", "a foldable, portrait", "4:3, landscape", "4:3, portrait",
                 "a 20:9 phone, landscape", "a 20:9 phone, portrait"];
    // A phone's layout at fewer dp: the 20:9 phone at 540 and 480 dp, a 9:16 one at 480.
    let phones = [float2 { 2400.0, 1080.0 }, float2 { 1080.0, 2400.0 }, float2 { 1920.0, 1080.0 },
                  float2 { 1080.0, 1920.0 }];
    let phone_names = ["a 20:9 phone, landscape", "a 20:9 phone, portrait", "a 9:16 phone, landscape",
                       "a 9:16 phone, portrait"];
    for lang in [strings::EN, strings::ET] {
        strings::use(lang);
        print(strings::LANGUAGES[lang], ":");
        gui::short_dp = 800.0;
        for size, i in sizes {
            drive::size = size;
            g.scale = gui::scale_of(size.x, size.y);
            gui::test_faces(g);
            print(names[i], ", ", size.x as i64, " x ", size.y as i64, ":");
            screens(g);
        }
        for dp in [540.0, 480.0] {
            gui::short_dp = dp as f32;
            for size, i in phones {
                guard i < 2 || dp < 500.0 else { continue; }
                drive::size = size;
                g.scale = gui::scale_of(size.x, size.y);
                gui::test_faces(g);
                print(phone_names[i], ", ", size.x as i64, " x ", size.y as i64, " at ", dp as i64, " dp:");
                screens(g);
            }
        }
    }
    // The Pixel 7a's insets in pixels, 118 for the camera and 84 for the gesture bar (the
    // swipe-down strip at the top is left to taps, patches/SDL/0002): portrait, landscape
    // with the camera at the left, and at the right.
    for lang in [strings::EN, strings::ET] {
        strings::use(lang);
        print(strings::LANGUAGES[lang], ", with insets:");
        for dp in [540.0, 480.0] {
            gui::short_dp = dp as f32;
            for size, i in phones {
                guard i < 2 || dp < 500.0 else { continue; }
                drive::size = size;
                g.scale = gui::scale_of(size.x, size.y);
                gui::test_faces(g);
                // Both phones are 1080 px across, as the Pixel is.
                let cut: f32 = 118.0;
                let bar: f32 = 84.0;
                let sides = if size.x > size.y { 2 } else { 1 };
                for k in sides {
                    g.insets = if size.x < size.y { float4 { 0.0, cut, 0.0, bar } }
                               else if k == 0 { float4 { cut, 0.0, 0.0, bar } } else { float4 { 0.0, 0.0, cut, bar } };
                    let e = g.insets;
                    print(phone_names[i], ", ", size.x as i64, " x ", size.y as i64, " at ", dp as i64, " dp, insets ",
                          e.x as i64, ", ", e.y as i64, ", ", e.z as i64, ", ", e.w as i64, " px:");
                    screens(g);
                }
            }
        }
    }
    // The Galaxy tablet's hidden navigation bar, 72 px (48 dp) at the bottom, in both
    // orientations: every tile inside the safe area, and settings in landscape still
    // shows both groups, its look's glass running on over the bar (as many tiles as
    // with no inset, not one group's and the tabs).
    gui::short_dp = 800.0;
    for lang in [strings::EN, strings::ET] {
        strings::use(lang);
        print(strings::LANGUAGES[lang], ", the tablet with its navigation bar:");
        for size in [float2 { 1920.0, 1200.0 }, float2 { 1200.0, 1920.0 }] {
            drive::size = size;
            g.scale = gui::scale_of(size.x, size.y);
            gui::test_faces(g);
            g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
            var bare = showing(shell::SETTINGS, home::NOTHING);
            at_rest(bare, g);
            let both = drive::tiles(g);
            g.insets = float4 { 0.0, 0.0, 0.0, 72.0 };
            print(size.x as i64, " x ", size.y as i64, ", insets 0, 0, 0, 72 px:");
            screens(g);
            var inset = showing(shell::SETTINGS, home::NOTHING);
            at_rest(inset, g);
            let shown = drive::tiles(g);
            print("  settings: ", shown, " tiles, ", both, " with no inset: ",
                  if shown == both { "both groups" } else { "one group" });
        }
    }
    // The 13" and 11" iPad in landscape with the status bar and the home indicator, in
    // pixels at 2 a point (24 and 20 points): settings shows both groups there too.
    for lang in [strings::EN, strings::ET] {
        strings::use(lang);
        print(strings::LANGUAGES[lang], ", the iPads in landscape with their bars:");
        for size in [float2 { 2752.0, 2064.0 }, float2 { 2420.0, 1668.0 }] {
            drive::size = size;
            g.scale = gui::scale_of(size.x, size.y);
            gui::test_faces(g);
            g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
            var bare = showing(shell::SETTINGS, home::NOTHING);
            at_rest(bare, g);
            let both = drive::tiles(g);
            g.insets = float4 { 0.0, 48.0, 0.0, 40.0 };
            print(size.x as i64, " x ", size.y as i64, ", insets 0, 48, 0, 40 px:");
            screens(g);
            var inset = showing(shell::SETTINGS, home::NOTHING);
            at_rest(inset, g);
            let shown = drive::tiles(g);
            print("  settings: ", shown, " tiles, ", both, " with no inset: ",
                  if shown == both { "both groups" } else { "one group" });
        }
    }
    g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
    strings::use(strings::EN);
    gui::short_dp = 480.0;
    drive::size = float2 { 1080.0, 2400.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    tabs(g);
    gui::short_dp = 800.0;
    small_window(g);
    handover();
}
