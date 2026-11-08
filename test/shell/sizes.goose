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
// that fits here fits on screen. Then a phone's tabs: settings' Look tab and the
// puzzles' crown each show their own tiles.
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

fn inside(r: float4, w: f32, h: f32) -> bool {
    return r.x >= -0.5 && r.y >= -0.5 && r.x + r.z <= w + 0.5 && r.y + r.w <= h + 0.5;
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
        if !inside(r, w, h) { format(wrong, " tile ", i, " off the screen;"); }
        for j in i { if overlaps(r, drive::rect(g, j)) { format(wrong, " tiles ", j, " and ", i, " overlap;"); } }
        if board_shows && b.z > 0.0 && overlaps(r, b) && !(card && i >= n - 2) { format(wrong, " tile ", i, " on the board;"); }
        if tap && (r.z < 88.0 * u - 0.5 || r.w < 88.0 * u - 0.5) { small++; }
    }
    if small > 0 { format(wrong, " ", small, " taps under 88 dp;"); }
    format(line, ", smallest ", whole(narrow / u), " x ", whole(low / u), " dp");
    if board_shows {
        format(line, ", board ", whole(b.z / u), " dp");
        if !inside(b, w, h) { wrong.append(" the board off the screen;"); }
    }
    if card {
        // The card's two buttons, on the board.
        let back = drive::rect(g, n - 2);
        format(line, ", card buttons ", whole(back.z / u), " x ", whole(back.w / u), " dp");
        if !inside(back, b.x + b.z, b.y + b.w) || back.x < b.x || back.y < b.y { wrong.append(" the card off the board;"); }
    }
    line.append(if wrong.len > 0 { ";" } else { ", all in place" });
    line.append(wrong);
    print(line);
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
// game's, and the puzzles' crown shows the second tier, locked.
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
    var locks = 0;
    drive::tap(picker, g, drive::tile(g, 2), 2.0);
    drive::idle(picker, g, 2.1);
    for q in g.quads { if q.look.x == gui::ICON && q.look.z == gui::LOCK { locks++; } }
    print("the puzzles' crown: tier ", picker.tier, ", tiles ", drive::tiles(g), ", locks ", locks);
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
    strings::use(strings::EN);
    gui::short_dp = 480.0;
    drive::size = float2 { 1080.0, 2400.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    tabs(g);
    gui::short_dp = 800.0;
}
