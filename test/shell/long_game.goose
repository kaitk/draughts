// A long game's win on a 2560 x 1440 desktop: an International game of 119 plies against
// the computer, every move marked (two glyphs each), the move list full of rows, then
// the win's card over the board. The UI's quads (gui::MAX_QUADS) must hold them all: at
// 512 the list took them and the card's panel, words, and buttons were dropped unseen,
// its crowned piece (an overlay, not a quad) left alone on the board (2026-11-14). On
// the flat and the 3D board: the quads the frame used, and the card's quads on the board.
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

fn ends(t: const u8[:]) -> i64, i64 {
    var a = -1;
    var cur = 0;
    for c in t {
        if c >= '0' && c <= '9' { cur = cur * 10 + (c - '0') as i64; }
        else { if a < 0 { a = cur; } cur = 0; }
    }
    if a < 0 { a = cur; }
    return a, cur;
}

fn main() {
    puzzles::load();
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::desktop_scale = 1.0;
    drive::size = float2 { 2560.0, 1440.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    let line = "33-28 18-23 34-30 20-24 31-27 14-20 37-31 20-25 39-34 10-14 38-33 5-10 34-29 23x34 40x29x20 25x34 44-40 15x24 40x29x20 14x25 45-40 25-30 35x24 19x30 40-35 13-19 35x24x13 9x18 50-45 17-22 28x17 11x22 32-28 10-15 28x17 12x21x32 42-38 4-10 38x27 3-9 45-40 15-20 40-35 6-11 35-30 10-14 33-28 9-13 41-37 8-12 49-44 13-19 44-40 20-24 40-35 11-17 43-39 18-22 27x18 12x23x32x41 46x37 17-21 31-26 21-27 37-31 27-32 47-41 7-11 48-42 24-29 42-37 29-33 37x28 33x44 28-22 44-49 22-18 11-17 31-27 49x21 18-12 17x8 26x17 8-13 17-12 16-21 36-31 21-26 31-27 1-6 27-22 6-11 30-25 19-24 41-37 14-19 25-20 24x15 35-30 19-23 12-8 13-19 8-3 11-16 3-12 16-21 12x29 2-8 29-24 8-12 24x8x17 21x12 30-24 15-20 24x15 26-31 37x26 12-18 22x13";
    for raised in [false, true] {
        var sh = shell::new(rules::INTERNATIONAL);
        sh.prefs.moves = settings::MOVES_MARKS;
        if raised { sh.prefs.board = settings::RAISED; }
        sh.game = game::new(rules::INTERNATIONAL);
        shell::apply_prefs(sh);
        sh.game.judge = false;
        sh.screen = shell::GAME;
        sh.drawn = shell::GAME;
        let b .= sh.game.b;
        let v .= rules::VARIANTS[rules::INTERNATIONAL];
        var now = 0.0;
        var start = 0;
        var most = 0;
        for i in line.len + 1 {
            guard i == line.len || line[i] == ' ' else { continue; }
            let a, z = ends(line[start..i]);
            start = i + 1;
            var found = false;
            for k in b.moves.len {
                guard b.moves[k].from == v.bit_of[a] && b.moves[k].to == v.bit_of[z] else { continue; }
                board::play_chosen(b, k, now);
                found = true;
                break;
            }
            if !found { print("no move ", line[start..i]); }
            now += 1.0;
            drive::idle(sh, g, now);
            most = max(most, g.quads.len);
        }
        for &n in sh.game.notes { n.mark = ai::BLUNDER; }
        for t in 40 {
            drive::idle(sh, g, now + 0.1 * t);
            most = max(most, g.quads.len);
        }
        var card = 0;
        for q in g.quads { if q.extra.z >= gui::ON_BOARD && q.extra.z < gui::CLIP { card++; } }
        print(if raised { "3D" } else { "flat" }, ": won ", sh.game.won_at >= 0.0, ", moves ", sh.game.notes.len, ", quads ",
              g.quads.len, ", at most ", most, ", under the limit ", most < gui::MAX_QUADS, ", the card's on the board ", card);
    }
}
