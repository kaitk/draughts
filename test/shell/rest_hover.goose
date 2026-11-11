// The mouse's hover on every screen (task 066), headless at a desktop's 1280 × 800 with
// desktop_scale 1: the pointer rests at each point of a 20 px grid, and two frames after
// it came there the screen asks for no more (shell::animating false, nothing changed),
// so a mouse resting anywhere, over a tile, the board, or nothing, draws nothing. Prints
// each screen's points and any that keep asking.
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

fn main() {
    strings::use(strings::EN);
    gui::desktop_scale = 1.0;
    let names = ["home", "settings", "the game", "the puzzles"];
    let screens = [shell::HOME, shell::SETTINGS, shell::GAME, shell::PICKER];
    for to, k in screens {
        var sh = shell::new(rules::RUSSIAN);
        var g = gui::Gui {};
        gui::test_faces(g);
        var now = 0.0;
        drive::idle(sh, g, now);
        if to != shell::HOME { shell::go_to(sh, to, now); }
        now = 1.0;
        drive::idle(sh, g, now);
        now = 30.0;
        drive::idle(sh, g, now);
        var points = 0;
        var busy = 0;
        var lit = 0;
        var y: f32 = 10.0;
        while y < drive::size.y {
            var x: f32 = 10.0;
            while x < drive::size.x {
                let p = float2 { x, y };
                drive::frame(sh, g, p, false, false, false, now);
                drive::frame(sh, g, p, false, false, false, now + 0.02);
                drive::frame(sh, g, p, false, false, false, now + 0.3);
                let changed = drive::frame(sh, g, p, false, false, false, now + 0.32);
                if g.hovered != 0 { lit++; }
                if changed || shell::animating(sh, g, now + 0.32) {
                    busy++;
                    if busy <= 5 { print("  ", names[k], ": still asking at ", x, ", ", y, " (hovered ", g.hovered, ")"); }
                }
                points++;
                now += 1.0;
                x += 20.0;
            }
            y += 20.0;
        }
        print(names[k], ": ", points, " points, ", lit, " over a lit tile, ", busy, " still asking");
    }
    gui::desktop_scale = 0.0;
}
