// The results screen (shell/results.goose, task 074): reached from who's playing's results tile,
// it reads the playing player's history; a draughts' tile shows that draughts' games and
// rating; the move list's three tiles set the player's moves panel, written as settings
// are, and the game follows it; back goes home. Laid out at the tablet's and a phone's
// size in both orientations: every tile at least a tap, inside the safe area, none over
// another; the frame's quads under gui::MAX_QUADS with a full list.
import std;
import vec;
import os;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn folder() -> u8[>..] {
    let dir = if is_dir("build") { str("build/games-files/") } else { str("games-files/") };
    make_dir(dir);
    var names: u8[>..] = [];
    list_dir(dir, names);
    for name in split(names, '\n') { if name.len > 0 { delete_file(str(dir, name)); } }
    return dir;
}

// The tiles the last frame declared: how many, the smallest side in dp, and whether all
// are inside `area` and apart.
fn check(g: gui::Gui&, area: float4) -> u8[>..] {
    let n = drive::tiles(g);
    var least: f32 = 1.0e9;
    var inside = true;
    var apart = true;
    for i in n {
        let r = drive::rect(g, i);
        least = min(least, min(r.z, r.w) / g.scale);
        if r.x < area.x - 0.5 || r.y < area.y - 0.5 || r.x + r.z > area.x + area.z + 0.5 || r.y + r.w > area.y + area.w + 0.5 {
            inside = false;
        }
        for j in i + 1..n {
            let q = drive::rect(g, j);
            if r.x < q.x + q.z - 0.5 && q.x < r.x + r.z - 0.5 && r.y < q.y + q.w - 0.5 && q.y < r.y + r.w - 0.5 { apart = false; }
        }
    }
    return str(n, " tiles, smallest ", least as i64, " dp, inside ", inside, ", apart ", apart, ", quads ", g.quads.len);
}

var now = 1.0;
fn tick() -> f64 {
    now += 0.5;
    return now;
}

fn main() {
    strings::use(strings::EN);
    let dir = folder();
    // A history of 30 International games against the computer and 2 Russian.
    var text: u8[>..] = [];
    for i in 32 {
        let variant = if i < 30 { "international" } else { "russian" };
        let winner = ["white", "black", "draw"][i % 3];
        format(text, "time=", 1762819200 + i * 3600, "\tdraughts=", variant, "\tagainst=computer\tlevel=", i % 3, "\tskill=",
               [8, 40, 90][i % 3], "\tside=white\twinner=", winner, "\trating=", 800 + i, ">", 801 + i,
               "\taccuracy=80,70\tmarks=2236523\tmoves=\n");
    }
    write_file(str(dir, "history-1.txt"), text);

    var sh = shell::new(rules::INTERNATIONAL);
    var ps = players::Players {};
    sh.prefs = players::load(ps, dir, true);
    sh.players = ps;
    sh.game = game::new(rules::INTERNATIONAL);
    var g = gui::Gui {};
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    // From home: the chip opens who's playing, its results tile the screen.
    drive::idle(sh, g, tick());
    let home = drive::tiles(g);
    drive::tap(sh, g, drive::tile(g, home - 2), tick());
    drive::tap(sh, g, drive::tile(g, drive::tiles(g) - 1), tick());
    drive::idle(sh, g, tick());
    print("results tile tapped: screen ", sh.screen, " (results ", shell::RESULTS, "), ", sh.games.len, " games read, showing ",
          rules::VARIANT_NAMES[sh.results_variant]);
    print("  ", check(g, float4 { 0.0, 0.0, drive::size.x, drive::size.y }));
    // Russian's tile (the third).
    drive::tap(sh, g, drive::tile(g, 3), tick());
    print("Russian tapped: showing ", rules::VARIANT_NAMES[sh.results_variant], ", ", check(g, float4 { 0.0, 0.0, drive::size.x, drive::size.y }));
    // The move list's Off (after back and the three draughts).
    drive::tap(sh, g, drive::tile(g, 4), tick());
    print("Off tapped: moves ", sh.prefs.moves, ", the game's ", sh.game.moves_shown, ", to write ", sh.changed);
    drive::tap(sh, g, drive::tile(g, 6), tick());
    print("Marks tapped: moves ", sh.prefs.moves, ", the game's ", sh.game.moves_shown);
    drive::tap(sh, g, drive::tile(g, 0), tick());
    drive::idle(sh, g, tick());
    print("back: screen ", sh.screen);

    // The layouts, the International list showing.
    let sizes = [float2 { 1280.0, 800.0 }, float2 { 800.0, 1280.0 }, float2 { 1066.0, 480.0 }, float2 { 480.0, 1040.0 }];
    let names = ["tablet landscape", "tablet portrait", "phone landscape", "phone portrait"];
    for size, i in sizes {
        drive::size = size;
        gui::short_dp = if i >= 2 { 480.0 } else { 800.0 };
        g.scale = gui::scale_of(size.x, size.y);
        gui::test_faces(g);
        sh.screen = shell::RESULTS;
        sh.drawn = -1;
        drive::idle(sh, g, tick());
        drive::idle(sh, g, tick());
        print(names[i], ": ", check(g, float4 { 0.0, 0.0, size.x, size.y }));
    }
    gui::short_dp = 800.0;
}
