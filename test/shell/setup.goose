// The board beside home's setup, headless: it shows the game the setup's play will start,
// not the game in progress. Each draughts tile sets it to that draughts' start, 10 × 10
// or 8 × 8, in landscape and portrait; against the computer black turns it and white
// turns it back, and a friend, chosen in the first row, shows it unturned, the computer
// at a level after that turning it again. A friend's board switched to Turns turns the
// setup's board once round to show it, and Stays leaves it. Back to the menu shows the
// game in progress again (a Russian game a move in), and play starts the game the board
// showed, turned the same, so nothing jumps. The board switches at once, so once the
// frame after a tap is drawn the shell asks for none. The frame of a tap still shows what
// it declared, its board's pieces on squares of its size. Then the setup's layout at the
// tablet's, the Pixel 7a's, and the iPhone 13 mini's sizes (layouts).
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

// Whether the board filled for `now` lies whole on squares of its size where the layout
// puts them: every piece inside the board, and the layout as many squares across as the
// board's draughts has.
fn whole(sh: shell::Shell&, now: f64) -> bool {
    let b .= shell::fill(sh, now);
    let r = sh.out.layout.board;
    var inside = sh.out.layout.n == rules::VARIANTS[b.variant].size;
    for p in b.pieces { inside = inside && p.at.x > r.x && p.at.x < r.x + r.z && p.at.y > r.y && p.at.y < r.y + r.z; }
    return inside;
}

// What the board shows at `now`: its size and position, whether white's pieces are at the
// bottom of the screen, and whether it lies whole.
fn shows(sh: shell::Shell&, now: f64) -> u8[>..] {
    let b .= shell::fill(sh, now);
    let mid = sh.out.layout.board.y + 0.5 * sh.out.layout.board.z;
    var low = 0;
    var white = 0;
    for p in b.pieces {
        guard p.look.x == 0.0 else { continue; }
        white++;
        if p.at.y > mid { low++; }
    }
    let n = rules::VARIANTS[b.variant].size;
    return str(n, "x", n, " ", rules::fen(b.pos), ", white at the bottom ", white > 0 && low == white, ", whole ",
               whole(sh, now));
}

// A tap at p as the app sees it: the frame of the release, where the tap acts, still
// shows its board whole; the frame after it shows what the tap changed; then, once a
// transition to or from the game would be over and its last frame drawn, a frame long
// after asks for no drawing and nothing animates.
fn tap(sh: shell::Shell&, g: gui::Gui&, p: float2, now: f64, what: const u8[:]) {
    drive::frame(sh, g, p, true, true, false, now);
    drive::frame(sh, g, p, false, false, true, now + 0.02);
    let was = whole(sh, now + 0.02);
    drive::idle(sh, g, now + 0.04);
    let shown = shows(sh, now + 0.04);
    drive::idle(sh, g, now + 0.4);
    let later = drive::idle(sh, g, now + 0.5);
    print(what, ": ", shown, "; the tap's frame whole ", was, ", then drawn ", later, " animating ",
          shell::animating(sh, g, now + 0.5));
}

// Each draughts tile of the setup in turn, tiles 6, 7, and 5, International, left chosen.
fn each_draughts(sh: shell::Shell&, g: gui::Gui&, now: f64) {
    tap(sh, g, drive::tile(g, 6), now, "  Brazilian");
    tap(sh, g, drive::tile(g, 7), now + 1.0, "  Russian");
    tap(sh, g, drive::tile(g, 5), now + 2.0, "  International");
}

// The setup's tiles: back 0, whom to play 1 (a friend) to 4 (hard), the draughts 5 to 7,
// the child's pieces 8 and 9 or the board staying 8 and turning 9, the clock 10 to 12, play 13.
let FRIEND = 1;
let EASY = 2;
let WHITE = 8;
let BLACK = 9;
let TURNS = 9;
let STAYS = 8;
let PLAY = 13;

fn main() {
    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    puzzles::load();
    // A Russian game, a move in; the setup's choices are the defaults, the computer at
    // easy, International, and white.
    var sh = shell::new(rules::RUSSIAN);
    drive::idle(sh, g, 0.0);
    tap(sh, g, drive::tile(g, 0), 1.0, "continue");
    drive::tap(sh, g, drive::at(sh.out.layout, "c3"), 2.0);
    drive::tap(sh, g, drive::at(sh.out.layout, "d4"), 2.1);
    drive::idle(sh, g, 3.0);
    tap(sh, g, drive::tile(g, 0), 4.0, "home");

    print("landscape");
    tap(sh, g, drive::tile(g, 1), 5.0, "the setup, the computer");
    each_draughts(sh, g, 6.0);
    tap(sh, g, drive::tile(g, BLACK), 9.0, "  black");
    tap(sh, g, drive::tile(g, WHITE), 10.0, "  white");
    tap(sh, g, drive::tile(g, BLACK), 11.0, "  black");
    tap(sh, g, drive::tile(g, 6), 12.0, "  Brazilian, black");
    // A friend: the pieces' row becomes the board's turning, and the board isn't turned.
    tap(sh, g, drive::tile(g, FRIEND), 13.0, "  a friend");
    print("  friend ", sh.prefs.friend, ", tiles ", drive::tiles(g), ", the board's turning on ", sh.prefs.turns);
    turning(sh, g, 14.0);
    tap(sh, g, drive::tile(g, EASY), 17.0, "  easy, black kept");
    tap(sh, g, drive::tile(g, 0), 18.0, "back");

    print("portrait");
    // The menu's tiles start with settings beside the wordmark.
    drive::size = float2 { 800.0, 1280.0 };
    drive::idle(sh, g, 18.9);
    tap(sh, g, drive::tile(g, 2), 19.0, "the setup, the computer");
    each_draughts(sh, g, 20.0);
    tap(sh, g, drive::tile(g, FRIEND), 23.0, "  a friend");
    tap(sh, g, drive::tile(g, EASY), 24.0, "  easy, black kept");
    tap(sh, g, drive::tile(g, WHITE), 25.0, "  white");
    tap(sh, g, drive::tile(g, BLACK), 26.0, "  black");
    tap(sh, g, drive::tile(g, 6), 27.0, "  Brazilian, black");

    // Play: the game starts as the board showed it, turned the same. The computer, white,
    // is to move, and its turn's ring animates.
    let before = shows(sh, 32.0);
    let flip = sh.out.layout.flip;
    tap(sh, g, drive::tile(g, PLAY), 32.0, "play");
    let gm .= sh.game;
    print("the game: computer ", gm.computer, ", turned ", sh.out.layout.flip, ", as the setup showed ",
          shows(sh, 33.0) == before && sh.out.layout.flip == flip);
    drive::tap(sh, g, drive::tile(g, 0), 34.0);       // home
    print("home: ", shows(sh, 34.1), ", turned ", sh.out.layout.flip);

    layouts(g);
}

// A friend's board's turning, Stays by default: Turns switched on turns the setup's flat
// board once round to show it, black's side showing for the middle half (half way at
// 0.7 s), at rest again after 1.4 s; the game's turns follow. Stays again turns nothing.
fn turning(sh: shell::Shell&, g: gui::Gui&, now: f64) {
    drive::tap(sh, g, drive::tile(g, TURNS), now);
    let at = now + 0.04;
    drive::idle(sh, g, at + 0.7);
    print("  turns tapped: on ", sh.prefs.turns, ", the game's ", sh.game.turns, "; 0.7 s on the board turned ",
          sh.out.layout.flip, ", animating ", shell::animating(sh, g, at + 0.7));
    drive::idle(sh, g, at + 1.5);
    print("  1.5 s on: turned ", sh.out.layout.flip, ", still turning ", rig::moving(sh.demo, at + 1.5));
    drive::tap(sh, g, drive::tile(g, STAYS), now + 2.0);
    drive::idle(sh, g, now + 2.7);
    print("  stays tapped: on ", sh.prefs.turns, ", turned ", sh.out.layout.flip, ", animating ",
          shell::animating(sh, g, now + 2.7));
}

// The setup laid out where it fits and where not (prototypes/new-game.html, take c), the
// computer's and a friend's, on the tablet's landscape and portrait (1280 x 800 and 800 x
// 1280 dp), the Pixel 7a's at 540 dp with its insets (cutout and gesture bar) in both
// orientations, and the iPhone 13 mini's (500 dp, its notch and home indicator): where
// play is (under the choices or in the head row), whether the choices scroll and by how
// much, the four tiles' width, the lowest tile's foot against the list's, and the board's
// size, in dp. Every tile a tap wide and tall at least.
fn layouts(g: gui::Gui&) {
    let sizes = [float2 { 1280.0, 800.0 }, float2 { 800.0, 1280.0 }, float2 { 2400.0, 1080.0 }, float2 { 1080.0, 2400.0 },
                 float2 { 2436.0, 1125.0 }, float2 { 1125.0, 2436.0 }];
    let dps: f32[6] = [800.0, 800.0, 540.0, 540.0, 500.0, 500.0];
    // Insets in pixels: the Pixel's 118 px cutout and 84 px gesture bar, the iPhone's 50
    // and 34 points (66.7 and 45.3 dp of the layout's, 3 px a dp at 500).
    let insets = [float4 { 0.0, 0.0, 0.0, 0.0 }, float4 { 0.0, 0.0, 0.0, 0.0 }, float4 { 118.0, 0.0, 0.0, 84.0 },
                  float4 { 0.0, 118.0, 0.0, 84.0 }, float4 { 150.0, 0.0, 150.0, 63.0 }, float4 { 0.0, 150.0, 0.0, 102.0 }];
    let names = ["the tablet, landscape", "the tablet, portrait", "the Pixel 7a, landscape", "the Pixel 7a, portrait",
                 "the iPhone 13 mini, landscape", "the iPhone 13 mini, portrait"];
    for size, i in sizes {
        drive::size = size;
        gui::short_dp = dps[i];
        g.scale = gui::scale_of(size.x, size.y);
        gui::test_faces(g);
        g.insets = insets[i];
        for friend in [false, true] {
            var sh = shell::new(rules::INTERNATIONAL);
            sh.setup = home::NEW_GAME;
            sh.prefs.friend = friend;
            drive::idle(sh, g, 0.0);
            drive::idle(sh, g, 1.0);
            print(names[i], if friend { ", a friend: " } else { ", the computer: " }, placed(sh, g));
        }
    }
    g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
    gui::short_dp = 800.0;
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
}

fn whole(x: f32) -> i64 { floor(x + 0.5) as i64 }

// Where the setup's parts are, from the last frame (layouts).
fn placed(sh: shell::Shell&, g: gui::Gui&) -> u8[>..] {
    let u = g.scale;
    let back = drive::rect(g, 0);
    let play = drive::rect(g, PLAY);
    let clock = drive::rect(g, PLAY - 1);
    let up = abs(play.y - back.y) < 0.5;
    var listed = false;
    var k = 0;
    var view = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        if k == FRIEND { listed = q.extra.z >= gui::CLIP; }
        k++;
    }
    if g.scroll.id == home::SETUP_LIST { view = g.scroll.view; }
    let scrolls = listed && g.scroll.max > 0.5;
    var small = 0;
    for i in drive::tiles(g) {
        let r = drive::rect(g, i);
        if r.z < gui::TAP * u - 0.5 || r.w < gui::TAP * u - 0.5 { small++; }
    }
    var out = str("play ", if up { "in the head row" } else { "under the choices" });
    if scrolls {
        format(out, ", the choices scroll ", whole(g.scroll.max / u), " dp in a view ", whole(view.w / u), " dp tall");
    } else {
        format(out, ", the choices fit, the clock's foot ", whole((play.y - clock.y - clock.w) / u), " dp above play");
    }
    format(out, ", whom to play's tiles ", whole(drive::rect(g, FRIEND).z / u), " dp wide, board ",
           whole(sh.out.layout.board.z / u), " dp, ", small, " taps under 88 dp");
    return out;
}
