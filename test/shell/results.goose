// The results screen (shell/results.goose, task 074): reached from who's playing's results tile,
// it reads the playing player's history; a draughts' tile shows that draughts' games and
// rating; the draughts' tiles stand on one glass; back goes home. The move list's setting
// is settings' alone (2026-11-13). Laid out at the tablet's and a phone's
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
    // From home: its games row opens the screen.
    drive::idle(sh, g, tick());
    var row = float4 { -100.0, -100.0, 1.0, 1.0 };
    for s in g.spots { if s.id == gui::HOME_IDS + 7 { row = s.rect; } }
    drive::tap(sh, g, drive::middle(row), tick());
    drive::idle(sh, g, tick());
    print("games row tapped: screen ", sh.screen, " (results ", shell::RESULTS, "), ", sh.past.games.len, " games read, showing ",
          rules::VARIANT_NAMES[sh.past.variant]);
    print("  ", check(g, float4 { 0.0, 0.0, drive::size.x, drive::size.y }));
    // Russian's tile (the third).
    drive::tap(sh, g, drive::tile(g, 3), tick());
    print("Russian tapped: showing ", rules::VARIANT_NAMES[sh.past.variant], ", ", check(g, float4 { 0.0, 0.0, drive::size.x, drive::size.y }));
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

    // A desktop's windows (a display scale of 1), large ones (gui::large): the whole at most
    // results::LARGE_W dp wide and centered, the rows 96 dp; then an ultrawide's.
    gui::desktop_scale = 1.0;
    for size in [float2 { 1280.0, 800.0 }, float2 { 2560.0, 1440.0 }, float2 { 3440.0, 1440.0 }] {
        drive::size = size;
        g.scale = gui::scale_of(size.x, size.y);
        gui::test_faces(g);
        sh.drawn = -1;
        drive::idle(sh, g, tick());
        drive::idle(sh, g, tick());
        let safe = gui::safe(g, size.x, size.y);
        var row = float4 { 0.0, 0.0, 0.0, 0.0 };
        var back = float4 { 0.0, 0.0, 0.0, 0.0 };
        for s in g.spots {
            if s.id == results::ROW_ID { row = s.rect; }
            if s.id == results::BACK_ID { back = s.rect; }
        }
        let left = back.x - safe.x;
        let right = safe.x + safe.z - (row.x + row.z);
        print("a desktop's ", size.x as i64, " x ", size.y as i64, ": ", check(g, safe), "; large ", gui::large(safe, g.scale),
              ", from back to the list's right ", ((row.x + row.z - back.x) / g.scale + 0.5) as i64, " dp, a row ",
              (row.w / g.scale + 0.5) as i64, " dp tall, centered ", abs(left - right) < 14.0 * g.scale);
    }
    gui::desktop_scale = 0.0;
}
