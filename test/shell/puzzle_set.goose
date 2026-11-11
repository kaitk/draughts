// The draughts switch on the puzzles' library (shell/picker.goose, take a of
// prototypes/puzzle-set.html), headless, driven through the pointer. The switch is
// settings' draughts: a tap on Russian shows Russian's set and its four themes, on
// Brazilian Brazilian's own set and its four, on International its six; each tap sets the player's draughts, written to the player's
// file as settings writes them, and home's count follows, each set's stars apart. A tap
// on the lit tile changes nothing. A list scrolled down (a small window) is back at its
// top after a switch. Then the library with each draughts chosen at the tablet's size in
// both orientations, a 20:9 phone's at 480 dp in both, in English and Estonian, and the
// 11" iPad's smallest window (a compact layout): its tiles (back, the switch's three, a
// row per theme), where the switch stands, the title's lines, and whether any tile lies
// off the screen, overlaps another, or is under 88 dp, or the title runs into a tile or
// off the screen.
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

fn inside(a: float4, b: float4) -> bool {
    let e: f32 = 0.5;
    return a.x + e >= b.x && a.y + e >= b.y && a.x + a.z <= b.x + b.z + e && a.y + a.w <= b.y + b.w + e;
}

fn dp(r: float4, u: f32) -> u8[>..] {
    return str(floor(r.x / u + 0.5) as i64, ",", floor(r.y / u + 0.5) as i64, " ", floor(r.z / u + 0.5) as i64, "x",
               floor(r.w / u + 0.5) as i64);
}

// Which of the switch's three is lit (the tiles after back), or -1.
fn lit(g: gui::Gui&) -> i64 {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        if k >= 1 && k <= 3 && q.extra.y == gui::CHOSEN { return k - 1; }
        k++;
    }
    return -1;
}

// The lines of text drawn bare on the photograph outside every tile (the title),
// counted by their distinct tops, the halo's copies left out.
fn bare_lines(g: gui::Gui&) -> i64 {
    var tops: f32[..8] = [];
    for q in g.quads {
        guard q.look.x == gui::TEXT && q.color.x > 0.5 && q.extra.z < gui::CLIP else { continue; }
        var on_tile = false;
        for t in g.quads { if t.look.x == gui::BUTTON && inside(q.rect, t.rect) { on_tile = true; } }
        guard !on_tile else { continue; }
        var seen = false;
        for y in tops { if abs(y - q.rect.y) < 6.0 * g.scale { seen = true; } }
        if !seen && tops.len < 8 { tops.push(q.rect.y); }
    }
    return tops.len;
}

fn show(sh: shell::Shell&, g: gui::Gui&, what: const u8[:]) {
    var rows = 0;
    for t in puzzles::THEMES { if puzzles::theme_count(puzzles::all, t) > 0 { rows++; } }
    let won, all = picker::totals(sh.prefs.stars[puzzles::loaded]);
    print(what, ": draughts ", rules::VARIANT_NAMES[sh.prefs.variant], ", lit ", lit(g), ", the set ",
          rules::VARIANT_NAMES[puzzles::loaded], " of ", puzzles::all.list.len, ", ", rows, " themes, ",
          drive::tiles(g), " tiles, home's count ", won, " / ", all,
          ", changed ", sh.changed);
}

// The library as the last frame declared it, at the size in drive::size.
fn report(what: const u8[:], g: gui::Gui&) {
    let w = drive::size.x;
    let h = drive::size.y;
    let u = g.scale;
    let safe = gui::safe(g, w, h);
    let n = drive::tiles(g);
    var wrong: u8[>..] = [];
    for i in n {
        let r = drive::rect(g, i);
        // The rows past the list's foot scroll; only the visible part counts as off.
        if r.x < safe.x - 0.5 || r.y < safe.y - 0.5 || r.x + r.z > safe.x + safe.z + 0.5 || (i < 4 && r.y + r.w > safe.y + safe.w + 0.5) {
            format(wrong, " tile ", i, " off the screen;");
        }
        for j in i { if overlaps(r, drive::rect(g, j)) { format(wrong, " tiles ", j, " and ", i, " overlap;"); } }
        if r.z < gui::TAP * u - 0.5 || r.w < gui::TAP * u - 0.5 { format(wrong, " tile ", i, " under 88 dp;"); }
    }
    var bad_text = 0;
    for q in g.quads {
        guard q.look.x == gui::TEXT && q.extra.z < gui::CLIP else { continue; }
        var on_tile = false;
        var hit = false;
        for t in g.quads {
            guard t.look.x == gui::BUTTON else { continue; }
            if inside(q.rect, t.rect) { on_tile = true; } else if overlaps(q.rect, t.rect) { hit = true; }
        }
        let off = q.rect.x < safe.x - 3.0 * u || q.rect.x + q.rect.z > safe.x + safe.z + 3.0 * u;
        if !on_tile && (hit || off) { bad_text++; }
    }
    if bad_text > 0 { format(wrong, " ", bad_text, " glyphs on a tile or off the screen;"); }
    let first = drive::rect(g, 1);
    let last = drive::rect(g, 3);
    let sw = float4 { first.x, first.y, last.x + last.z - first.x, first.w };
    print("  ", what, ": ", n, " tiles, back ", dp(drive::rect(g, 0), u), ", the switch ", dp(sw, u), " (",
          floor(drive::rect(g, 1).z / u + 0.5) as i64, " ", floor(drive::rect(g, 2).z / u + 0.5) as i64, " ",
          floor(drive::rect(g, 3).z / u + 0.5) as i64, "), the first row ", dp(drive::rect(g, 4), u), ", ",
          bare_lines(g), " lines of title, ", g.quads.len, " quads", if wrong.len > 0 { str(";", wrong) } else { str(", all in place") });
}

fn at_size(g: gui::Gui&, size: float2, short: f32, display: f32) {
    gui::short_dp = short;
    gui::display_scale = display;
    drive::size = size;
    g.scale = gui::scale_of(size.x, size.y);
    gui::test_faces(g);
}

fn layouts(g: gui::Gui&, what: const u8[:]) {
    print(what, ":");
    for v in [rules::INTERNATIONAL, rules::BRAZILIAN, rules::RUSSIAN] {
        var sh = shell::new(rules::INTERNATIONAL);
        sh.prefs.variant = v;
        sh.screen = shell::HOME;
        drive::idle(sh, g, 0.0);
        sh.screen = shell::PICKER;
        drive::idle(sh, g, 0.1);
        report(rules::VARIANT_NAMES[v], g);
    }
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    at_size(g, float2 { 1920.0, 1200.0 }, 800.0, 0.0);
    var sh = shell::new(rules::INTERNATIONAL);
    sh.prefs.stars[rules::INTERNATIONAL][1] = 3;
    sh.prefs.stars[rules::RUSSIAN][9] = 2;
    sh.prefs.stars[rules::BRAZILIAN][9] = 1;
    sh.screen = shell::PICKER;
    drive::idle(sh, g, 0.0);
    show(sh, g, "the library");
    var now = 1.0;
    for k in [3, 2, 1, 1] {
        sh.changed = false;
        drive::tap(sh, g, drive::tile(g, k), now);
        now += 1.0;
        show(sh, g, ["", "International tapped", "Brazilian tapped", "Russian tapped"][k]);
    }
    // The player's file has the draughts the switch chose.
    drive::tap(sh, g, drive::tile(g, 3), now);
    var out: u8[>..] = [];
    settings::write(sh.prefs, out);
    for line in split(out[..], '\n') { if starts_with(line, "draughts") { print("the file: ", line); } }
    // Home's count over the set shown.
    sh.screen = shell::HOME;
    drive::idle(sh, g, now + 1.0);
    show(sh, g, "home");

    // The smallest iPad window's list scrolled down, then switched: back at its top.
    puzzles::load();
    at_size(g, float2 { 748.0, 968.0 }, 800.0, 2.0);
    var ph = shell::new(rules::INTERNATIONAL);
    ph.screen = shell::PICKER;
    drive::idle(ph, g, 0.0);
    let from = drive::rect(g, 5);
    let p = drive::middle(from);
    drive::frame(ph, g, p, true, true, false, 0.1);
    for k in 10 { drive::frame(ph, g, float2 { p.x, p.y - 30.0 * (k + 1) * g.scale }, true, false, false, 0.12 + 0.01 * k); }
    drive::frame(ph, g, float2 { p.x, p.y - 300.0 * g.scale }, false, false, true, 0.3);
    drive::idle(ph, g, 0.4);
    print("the smallest window's list dragged: ", floor(g.scroll.offset / g.scale + 0.5) as i64, " dp down");
    drive::tap(ph, g, drive::tile(g, 3), 1.0);
    drive::idle(ph, g, 1.1);
    print("Russian tapped: ", floor(g.scroll.offset / g.scale + 0.5) as i64, " dp down, the first row at ",
          dp(drive::rect(g, 4), g.scale));

    at_size(g, float2 { 1920.0, 1200.0 }, 800.0, 0.0);
    layouts(g, "the tablet, landscape");
    at_size(g, float2 { 1200.0, 1920.0 }, 800.0, 0.0);
    layouts(g, "the tablet, portrait");
    at_size(g, float2 { 2400.0, 1080.0 }, 480.0, 0.0);
    layouts(g, "a 20:9 phone at 480 dp, landscape");
    at_size(g, float2 { 1080.0, 2400.0 }, 480.0, 0.0);
    layouts(g, "a 20:9 phone at 480 dp, portrait");
    strings::use(strings::ET);
    gui::test_faces(g);
    layouts(g, "a 20:9 phone at 480 dp, portrait, Estonian");
    at_size(g, float2 { 2400.0, 1080.0 }, 480.0, 0.0);
    layouts(g, "a 20:9 phone at 480 dp, landscape, Estonian");
    strings::use(strings::EN);
    // The 11" iPad's smallest window, 374 x 484 pt at 2 px a point: 499 x 645 dp, compact.
    at_size(g, float2 { 748.0, 968.0 }, 800.0, 2.0);
    layouts(g, "the smallest iPad window");
    strings::use(strings::ET);
    gui::test_faces(g);
    layouts(g, "the smallest iPad window, Estonian");
}
