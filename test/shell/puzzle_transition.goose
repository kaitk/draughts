// The puzzles to pick from to a puzzle and back through their transition, headless: a
// tile tapped grows the puzzle's board out of it into its place between the panels, the
// picker fading out under the panels and the photograph going from sharp to blurred;
// the puzzles on the panel shrink it back into its tile. At rest on the picker the board
// lies off the screen. The frame after the end is drawn, at rest, as the puzzle opened
// straight is, and then nothing more. A tap during it lands on the puzzle: its way out
// turns the transition round where it is. The picker's rows, tiles, and the panels are
// hidden where the board passes (the hole) while it runs.
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

fn screen(sh: shell::Shell&) -> const u8[:] {
    if sh.screen == shell::PICKER { "puzzles" } else if sh.screen == shell::PUZZLE { "puzzle" } else { "other" }
}

fn rect(r: float4) -> u8[>..] { str(round(r.x), ",", round(r.y), " ", round(r.z)) }
fn pc(x: f32) -> f64 { round(100.0 * x) }

// Where the UI is hidden this frame: nowhere at rest, else the board's rect.
fn hole(sh: shell::Shell&) -> const u8[:] {
    if sh.out.hole.z <= 0.0 { "none" } else if sh.out.hole == sh.out.layout.board { "the board" } else { "elsewhere" }
}

fn look(sh: shell::Shell&, g: gui::Gui&, now: f64, what: const u8[:]) {
    let drawn = drive::idle(sh, g, now);
    var faded = 0;
    for q in g.quads { if q.extra.w > 0.0 { faded++; } }
    let b .= shell::fill(sh, now);
    var faint = 0;
    for p in b.pieces { if p.look.w < 1.0 { faint++; } }
    print(what, " ", now, ": ", screen(sh), ", board ", rect(sh.out.layout.board), " ", sh.out.layout.n, "x", sh.out.layout.n,
          ", mix ", pc(sh.mix), "%, blur ", pc(sh.out.blur), "%, quads ", g.quads.len, " faded ", faded, ", pieces ",
          b.pieces.len, " faint ", faint, ", hole ", hole(sh), ", drawn ", drawn, ", animating ", shell::animating(sh, g, now));
}

fn main() {
    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    puzzles::load();
    var sh = shell::new(rules::INTERNATIONAL);
    sh.screen = shell::PICKER;
    sh.theme = puzzles::LEARN;              // Learn's page, its tiles
    look(sh, g, 0.0, "picker");
    let first_tile = drive::rect(g, 1);

    // The first puzzle, tapped at 1.0 and released at 1.02.
    drive::frame(sh, g, drive::tile(g, 1), true, true, false, 1.0);
    drive::frame(sh, g, drive::tile(g, 1), false, false, true, 1.02);
    print("tapped: ", screen(sh), ", the board in the tile ", sh.out.layout.board.x == first_tile.x && sh.out.layout.board.y == first_tile.y
          && sh.out.layout.board.z == first_tile.z, ", blur ", pc(sh.out.blur), "%");
    var size = sh.out.layout.board.z;
    var grew = true;
    for i in 1..5 {
        look(sh, g, 1.02 + 0.0625 * i, "  ");
        if sh.out.layout.board.z < size { grew = false; }
        size = sh.out.layout.board.z;
    }
    look(sh, g, 1.4, "idle");
    print("the board grew all the way ", grew);
    let arrived = sh.out.layout.board;
    let quads = g.quads.len;
    let way_out = drive::control(g, 0);

    // The puzzle opened straight.
    var straight = shell::new(rules::INTERNATIONAL);
    shell::play_puzzle(straight, 0);
    var h = gui::Gui {};
    gui::test_faces(h);
    drive::idle(straight, h, 0.0);
    print("as opened straight: board ", straight.out.layout.board == arrived, ", quads ", h.quads.len == quads, ", blur ",
          pc(straight.out.blur), "%");

    // Back to the picker: the board shrinks into its tile, then lies off the screen.
    drive::tap(sh, g, way_out, 2.0);
    look(sh, g, 2.145, "back");
    look(sh, g, 2.4, "ended");
    look(sh, g, 2.5, "idle");

    // Once more, and the puzzle's way out mid-way turns it round.
    drive::frame(sh, g, drive::tile(g, 1), true, true, false, 3.0);
    drive::frame(sh, g, drive::tile(g, 1), false, false, true, 3.02);
    look(sh, g, 3.145, "again");
    drive::frame(sh, g, way_out, true, true, false, 3.16);
    let before = sh.out.layout.board;
    drive::frame(sh, g, way_out, false, false, true, 3.17);
    let turned = sh.out.layout.board;
    drive::idle(sh, g, 3.18);
    print("its way out during it: ", screen(sh), ", the board on the frames ", rect(before), ", ", rect(turned), ", ",
          rect(sh.out.layout.board));
    look(sh, g, 3.3, "  ");
    look(sh, g, 3.4, "ended");
    look(sh, g, 3.5, "idle");
}
