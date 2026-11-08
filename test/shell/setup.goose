// The board beside home's setup, headless: it shows the game the setup's play will start,
// not the game in progress. Each draughts tile sets it to that draughts' start, 10 × 10
// or 8 × 8, in a friend's setup and the computer's, in landscape and portrait; against
// the computer black turns it and white turns it back. Back to the menu shows the game in
// progress again (a Russian game a move in), and play starts the game the board showed,
// turned the same, so nothing jumps. The board switches at once, so once the frame after
// a tap is drawn the shell asks for none. The frame of a tap still shows what it declared,
// its board's pieces on squares of its size.
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

// Whether the board filled for `now` lies whole on squares of its size where the layout
// puts them: every piece inside the board, and the layout as many squares across as the
// board's draughts has.
fn whole(sh: shell::Shell&, now: f64) -> bool {
    let b .= shell::fill(sh, now);
    let r = sh.layout.board;
    var inside = sh.layout.n == rules::VARIANTS[b.variant].size;
    for p in b.pieces { inside = inside && p.at.x > r.x && p.at.x < r.x + r.z && p.at.y > r.y && p.at.y < r.y + r.z; }
    return inside;
}

// What the board shows at `now`: its size and position, whether white's pieces are at the
// bottom of the screen, and whether it lies whole.
fn shows(sh: shell::Shell&, now: f64) -> u8[>..] {
    let b .= shell::fill(sh, now);
    let mid = sh.layout.board.y + 0.5 * sh.layout.board.z;
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
// shows its board whole; the frame after it shows what the tap changed; then a frame
// long after asks for no drawing and nothing animates.
fn tap(sh: shell::Shell&, g: gui::Gui&, p: float2, now: f64, what: const u8[:]) {
    drive::frame(sh, g, p, true, true, false, now);
    drive::frame(sh, g, p, false, false, true, now + 0.02);
    let was = whole(sh, now + 0.02);
    drive::idle(sh, g, now + 0.04);
    let shown = shows(sh, now + 0.04);
    let later = drive::idle(sh, g, now + 0.5);
    print(what, ": ", shown, "; the tap's frame whole ", was, ", then drawn ", later, " animating ",
          shell::animating(sh, g, now + 0.5));
}

// Each draughts tile of the setup in turn, tiles 1 to 3, the last, International, left
// chosen.
fn each_draughts(sh: shell::Shell&, g: gui::Gui&, now: f64) {
    tap(sh, g, drive::tile(g, 2), now, "  Brazilian");
    tap(sh, g, drive::tile(g, 3), now + 1.0, "  Russian");
    tap(sh, g, drive::tile(g, 1), now + 2.0, "  International");
}

fn main() {
    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    puzzles::load();
    // A Russian game, a move in; the setup's choices are the defaults, International and
    // white.
    var sh = shell::new(rules::RUSSIAN);
    drive::idle(sh, g, 0.0);
    tap(sh, g, drive::tile(g, 0), 1.0, "continue");
    drive::tap(sh, g, drive::at(sh.layout, "c3"), 2.0);
    drive::tap(sh, g, drive::at(sh.layout, "d4"), 2.1);
    drive::idle(sh, g, 3.0);
    tap(sh, g, drive::tile(g, 0), 4.0, "home");

    print("landscape");
    tap(sh, g, drive::tile(g, 1), 5.0, "a friend's setup");
    each_draughts(sh, g, 6.0);
    tap(sh, g, drive::tile(g, 0), 9.0, "back");

    // The computer's setup: back, the draughts, the level 4 to 6, the color 7 and 8, the
    // clock 9 to 11, play 12.
    tap(sh, g, drive::tile(g, 2), 10.0, "the computer's setup");
    each_draughts(sh, g, 11.0);
    tap(sh, g, drive::tile(g, 8), 14.0, "  black");
    tap(sh, g, drive::tile(g, 7), 15.0, "  white");
    tap(sh, g, drive::tile(g, 8), 16.0, "  black");
    tap(sh, g, drive::tile(g, 2), 17.0, "  Brazilian, black");
    tap(sh, g, drive::tile(g, 0), 18.0, "back");

    print("portrait");
    // The menu's tiles start with settings beside the wordmark.
    drive::size = float2 { 800.0, 1280.0 };
    drive::idle(sh, g, 18.9);
    tap(sh, g, drive::tile(g, 2), 19.0, "a friend's setup");
    each_draughts(sh, g, 20.0);
    tap(sh, g, drive::tile(g, 0), 23.0, "back");
    tap(sh, g, drive::tile(g, 3), 24.0, "the computer's setup");
    each_draughts(sh, g, 25.0);
    tap(sh, g, drive::tile(g, 8), 28.0, "  black");
    tap(sh, g, drive::tile(g, 7), 29.0, "  white");
    tap(sh, g, drive::tile(g, 8), 30.0, "  black");
    tap(sh, g, drive::tile(g, 2), 31.0, "  Brazilian, black");

    // Play: the game starts as the board showed it, turned the same. The computer, white,
    // is to move, and its turn's ring animates.
    let before = shows(sh, 32.0);
    let flip = sh.layout.flip;
    tap(sh, g, drive::tile(g, 12), 32.0, "play");
    let gm .= sh.game;
    print("the game: computer ", gm.computer, ", turned ", sh.layout.flip, ", as the setup showed ",
          shows(sh, 33.0) == before && sh.layout.flip == flip);
    drive::tap(sh, g, drive::tile(g, 0), 34.0);       // home
    print("home: ", shows(sh, 34.1), ", turned ", sh.layout.flip);
}
