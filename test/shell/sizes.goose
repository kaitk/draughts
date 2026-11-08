// Every screen at other proportions than the tablet's (task 030), headless: a foldable's
// near-square inner screen, a 4:3 tablet, and a 20:9 phone, each in both orientations,
// in English and Estonian; and the phone's layout at 540 and 480 dp across its shorter
// side (gui::short_dp, the phone scale's floor), with a 9:16 phone at 480, the tightest.
// On each, every tile lies inside the screen and no two overlap; the board lies inside
// it too, clear of the tiles (the win card's excepted, which sits on the board); every
// tile that takes a tap keeps the 88 dp a small hand needs (the clocks only show). A line
// per screen gives its tiles, the smallest tap across and down in dp, and the board in
// dp (0 where none shows), so a layout that moves shows here. The words are the test
// faces' (each character half its face wide), wider than the real font's, so a word
// that fits here fits on screen. The phones again with the Pixel 7a's insets (its
// camera's cutout at the top in portrait and at a side in landscape, either side, and
// its gesture bar at the bottom): every tile and the board inside the safe area; and
// the 16:10 tablet with its hidden navigation bar at the bottom. Then a phone's tabs:
// settings' Look tab and the puzzles' crown each show their own tiles.
import std;
import vec;
import rules from "../../rules";
import board from "../../board";
import gui from "../../gui";
import strings from "../../strings";
import game from "../../game";
import ai from "../../ai";
import shell from "../../shell";
import puzzles from "../../puzzles";
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
    for i in n {
        let r = drive::rect(g, i);
        let tap = style(g, i) < gui::CLOCK_RUN;
        if tap {
            narrow = min(narrow, r.z);
            low = min(low, r.w);
        }
        if !inside(r, safe) { format(wrong, " tile ", i, " off the safe area;"); }
        for j in i { if overlaps(r, drive::rect(g, j)) { format(wrong, " tiles ", j, " and ", i, " overlap;"); } }
        if board_shows && b.z > 0.0 && overlaps(r, b) && !(card && i >= n - 2) { format(wrong, " tile ", i, " on the board;"); }
        if tap && (r.z < 88.0 * u - 0.5 || r.w < 88.0 * u - 0.5) { small++; }
    }
    if small > 0 { format(wrong, " ", small, " taps under 88 dp;"); }
    format(line, ", smallest ", whole(narrow / u), " x ", whole(low / u), " dp");
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

// Home's chip (the last tile but one), with no name and with twelve characters: off the
// column (the first glass the frame declares) and the way out, and anchored to the
// board's top left corner: its left edge at the board's and its foot 16 dp above it, or,
// where that would leave no board, its top at the board's and 16 dp left of it
// (home::player_spot).
fn chip(g: gui::Gui&, sh: shell::Shell&) {
    let u = g.scale;
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
        var line = str("  home's chip", if named { ", named" } else { "" }, ": ", whole(c.z / u), " dp wide, board ", whole(b.z / u), " dp");
        var wrong: u8[>..] = [];
        if overlaps(c, col) { wrong.append(" on the column;"); }
        if overlaps(c, way) { wrong.append(" on the way out;"); }
        if b.z <= 0.0 { wrong.append(" no board;"); }
        let above = abs(c.x - b.x) <= 0.5 && abs(c.y + c.w + 16.0 * u - b.y) <= 0.5;
        let left = abs(c.x + c.z + 16.0 * u - b.x) <= 0.5 && abs(c.y - b.y) <= 0.5;
        if b.z > 0.0 && !above && !left { wrong.append(" not at the board's top left;"); }
        line.append(if wrong.len > 0 { ";" } else if above { ", above the board's top left, off the column" }
                    else { ", left of the board's top, off the column" });
        line.append(wrong);
        print(line);
    }
    sh.prefs.name.clear();
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
    drive::tap(picker, g, drive::tile(g, 1), 2.0);
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
    g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
    strings::use(strings::EN);
    gui::short_dp = 480.0;
    drive::size = float2 { 1080.0, 2400.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    tabs(g);
    gui::short_dp = 800.0;
}
