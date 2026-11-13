// The puzzles' library and each theme's page (shell/picker.goose, take a), headless, at
// the tablet's size (1920 × 1200, 800 dp across its shorter side) and a 20:9 phone's at
// 480 dp, in both orientations: each screen's taps, where the first and the last lie in
// dp, the smallest across and down, and whether any lies off the screen, overlaps
// another, or is under 88 dp. In the library the rows are one column where they fit the
// height and two where they don't; on a page the levels' tiles go in rows as even as
// they go. With half of Learn solved the other themes open, and the first puzzle
// without stars is lit, one per page.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import game from "../../src/game";
import strings from "../../strings";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn overlaps(a: float4, b: float4) -> bool {
    let e: f32 = 0.5;
    return a.x + e < b.x + b.z && b.x + e < a.x + a.z && a.y + e < b.y + b.w && b.y + e < a.y + a.w;
}

fn dp(r: float4, u: f32) -> u8[>..] {
    return str(floor(r.x / u + 0.5) as i64, ",", floor(r.y / u + 0.5) as i64, " ", floor(r.z / u + 0.5) as i64, "x",
               floor(r.w / u + 0.5) as i64);
}

fn icons(g: gui::Gui&, icon: i64) -> i64 {
    var n = 0;
    for q in g.quads { if q.look.x == gui::ICON && q.look.z == icon { n++; } }
    return n;
}

fn lit(g: gui::Gui&) -> i64 {
    var n = 0;
    for q in g.quads { if q.look.x == gui::BUTTON && q.extra.y == gui::CHOSEN { n++; } }
    return n;
}

// The screen as the last frame declared it.
fn report(what: const u8[:], g: gui::Gui&) {
    let w = drive::size.x;
    let h = drive::size.y;
    let u = gui::scale_of(w, h);
    let safe = gui::safe(g, w, h);
    let n = drive::tiles(g);
    var narrow: f32     = 1.0e9;
    var low:    f32     = 1.0e9;
    var wrong:  u8[>..] = [];
    var below = 0;
    for i in n {
        let r = drive::rect(g, i);
        narrow = min(narrow, r.z);
        low = min(low, r.w);
        // A row past the foot of the list, which scrolls to it (a phone's landscape since
        // How to play's row, task 026), is counted apart.
        let across = r.x >= safe.x - 0.5 && r.x + r.z <= safe.x + safe.z + 0.5;
        if across && r.y >= safe.y - 0.5 && r.y + r.w > safe.y + safe.w + 0.5 {
            below++;
        } else if r.x < safe.x - 0.5 || r.y < safe.y - 0.5 || !across || r.y + r.w > safe.y + safe.w + 0.5 {
            format(wrong, " tile ", i, " off the screen;");
        }
        for j in i { if overlaps(r, drive::rect(g, j)) { format(wrong, " tiles ", j, " and ", i, " overlap;"); } }
        if r.z < gui::TAP * u - 0.5 || r.w < gui::TAP * u - 0.5 { format(wrong, " tile ", i, " under 88 dp;"); }
    }
    var scrolled: u8[>..] = [];
    if below > 0 { format(scrolled, ", ", below, " below the foot (the list scrolls)"); }
    print("  ", what, ": ", n, " tiles, lit ", lit(g), ", locks ", icons(g, gui::LOCK), ", stars ", icons(g, gui::STAR), ", back ", dp(drive::rect(g, 0), u), ", the first ",
          dp(drive::rect(g, 1), u), ", the last ", dp(drive::rect(g, n - 1), u), ", smallest ",
          floor(narrow / u + 0.5) as i64, " x ", floor(low / u + 0.5) as i64, " dp",
          scrolled[..], if wrong.len > 0 { str(";", wrong) } else { str(", all in place") });
}

fn screens(g: gui::Gui&, stars: i64[:]) {
    var sh = shell::new(rules::INTERNATIONAL);
    for id in stars { sh.prefs.stars[rules::INTERNATIONAL][id] = 3; }
    sh.screen = shell::PICKER;
    drive::idle(sh, g, 0.0);
    report("the library", g);
    for t in puzzles::THEMES {
        sh.theme = t;
        drive::idle(sh, g, 0.1);
        report(puzzles::THEME_NAMES[t], g);
    }
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    let sizes = [float2 { 1920.0, 1200.0 }, float2 { 1200.0, 1920.0 }, float2 { 2400.0, 1080.0 },
                 float2 { 1080.0, 2400.0 }];
    let names = ["the tablet, landscape", "the tablet, portrait", "a 20:9 phone at 480 dp, landscape",
                 "a 20:9 phone at 480 dp, portrait"];
    for size, i in sizes {
        gui::short_dp = if i < 2 { 800.0 } else { 480.0 };
        drive::size = size;
        g.scale = gui::scale_of(size.x, size.y);
        gui::test_faces(g);
        print(names[i], ":");
        screens(g, []);
    }
    // Half of Learn solved, the first four and 6 and 9: the others open, and on Learn's
    // page the first without stars is lit.
    gui::short_dp = 800.0;
    drive::size = sizes[0];
    g.scale = gui::scale_of(sizes[0].x, sizes[0].y);
    gui::test_faces(g);
    print("the tablet, half of Learn solved:");
    screens(g, [1, 3, 7, 8, 6, 9]);
}
