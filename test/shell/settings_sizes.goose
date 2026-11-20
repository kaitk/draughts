// Settings laid out at the devices' sizes, headless: the tablet's
// landscape and portrait (1280 x 800 and 800 x 1280 dp), the Pixel 7a's at 540 dp with
// its cutout and gesture bar, and the iPhone 13 mini's at 500 dp with its notch and home
// indicator, each both ways, in English and Estonian. In landscape the list is a 480 dp
// column at the left, the preview right of it; in portrait the preview is a band at the
// top, 40% of the safe area's height on the tablet and 30% on a phone, the list a sheet
// under it. A line a size: the lines each row's tiles take, whether the list scrolls, the
// preview shows, and a row's gaps (10 dp) close to fit five across a phone, and the
// language list opened from the title row, its rows; verbose (DRAUGHTS_TEST_VERBOSE) the
// column's width or the sheet's top, the list's view and how far it scrolls, the picture
// rows' gaps, the smallest tap, the preview's flat board and the 3D board's room, and the
// language rows' size, in dp. Every tap is 88 dp at least, every tile and the language
// list inside the safe area across, and the preview at least board::SMALLEST where it shows; a line with anything
// wrong fails the test. The words are the test faces' (each character half its face
// wide), wider than the real font's.
import std;
import vec;
import rules from "../../src/rules";
import board from "../../src/board";
import model3d from "../../src/model3d";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

let LANGUAGE = 1;           // the language button, after back
let FIRST_TILE = 2;         // the list's first tile: the Theme row's first season
// The list's rows' tiles on the 3D board (its Pieces and the Background's table with them),
// puzzles a day's four too, the speaker, back, language, About.
let TILES = 31;

fn whole(x: f32) -> i64 { floor(x + 0.5) as i64 }

// The tap round tile r: the smallest control the keys' focus was offered whose rect
// holds r, else r itself; the About row is small, its tap a tap round it (sizes.goose's).
fn tap_of(g: gui::Gui&, r: float4) -> float4 {
    var best = r;
    var found = false;
    for s in g.spots {
        let q = s.rect;
        guard q.x <= r.x + 0.5 && q.y <= r.y + 0.5 && q.x + q.z >= r.x + r.z - 0.5 && q.y + q.w >= r.y + r.w - 0.5 else { continue; }
        if !found || q.z * q.w < best.z * best.w { best = q; }
        found = true;
    }
    return best;
}

fn inside_across(r: float4, a: float4) -> bool { r.x >= a.x - 0.5 && r.x + r.z <= a.x + a.z + 0.5 }

// How many lines a row's tiles take, from tile `first`, `n` of them, and the gap between
// the first two in dp (verbose) or whether it is closed under 10 dp.
fn row_of(g: gui::Gui&, first: i64, n: i64) -> u8[>..] {
    var lines = 1;
    for i in 1..n { if drive::rect(g, first + i).y > drive::rect(g, first + i - 1).y + 0.5 { lines++; } }
    let a = drive::rect(g, first);
    let b = drive::rect(g, first + 1);
    let gap = (b.x - a.x - a.z) / g.scale;
    var out = str(lines, if lines == 1 { " line" } else { " lines" });
    if drive::verbose { format(out, " ", whole(gap), " apart"); }
    else if gap < 9.5 { out.append(" closed up"); }
    return out;
}

var failures = 0;

fn layout(g: gui::Gui&, name: const u8[:]) {
    let u = g.scale;
    var sh = shell::new(rules::INTERNATIONAL);
    sh.screen = shell::SETTINGS;
    sh.prefs.board = settings::RAISED;
    drive::idle(sh, g, 0.0);
    drive::idle(sh, g, 1.0);
    let safe = gui::safe(g, drive::size.x, drive::size.y);
    var glass = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads { if q.look.x == gui::GLASS { glass = q.rect; break; } }
    let landscape = drive::size.x >= drive::size.y;
    var wrong: u8[>..] = [];
    var out:   u8[>..] = [];
    let v = g.scroll.view;
    if drive::verbose {
        if landscape { format(out, "the column ", whole((glass.x + glass.z - safe.x) / u), " dp"); }
        else { format(out, "the sheet from ", whole((glass.y - safe.y) / u), " dp"); }
        format(out, ", the list ", whole(v.w / u), " dp tall, scrolls ", whole(g.scroll.max / u), " dp");
    } else {
        out.append(if landscape { "the column" } else { "the sheet" });
        out.append(if g.scroll.max > 0.0 { ", the list scrolls" } else { ", the list still" });
    }
    format(out, "; theme ", row_of(g, FIRST_TILE, 5), ", board ", row_of(g, FIRST_TILE + 5, 5), ", pieces ",
           row_of(g, FIRST_TILE + 10, 2), ", background ", row_of(g, FIRST_TILE + 12, 3));
    let n = drive::tiles(g);
    if n != TILES { format(wrong, " ", n, " tiles;"); }
    var narrow: f32 = 1.0e9;
    var low:    f32 = 1.0e9;
    var small = 0;
    for i in n {
        let r = tap_of(g, drive::rect(g, i));
        narrow = min(narrow, r.z);
        low = min(low, r.w);
        if r.z < gui::TAP * u - 0.5 || r.w < gui::TAP * u - 0.5 { small++; }
        if !inside_across(r, safe) { format(wrong, " tile ", i, " off the safe area;"); }
    }
    if small > 0 { format(wrong, " ", small, " taps under 88 dp;"); }
    if drive::verbose { format(out, "; smallest tap ", whole(narrow / u), " x ", whole(low / u), " dp"); }
    // The flat preview as the layout places it, and the 3D board's bounds in its room.
    var flat = sh.prefs;
    flat.board = settings::FLAT;
    let b = settings::layout(flat, g, safe, rules::VARIANTS[sh.preview.variant].size).board.board;
    let raised = sh.to_view.rect;
    if b.z > 0.0 {
        if drive::verbose {
            format(out, "; preview ", whole(b.z / u), " dp, the 3D board ", whole(raised.z / u), " x ", whole(raised.w / u));
        } else {
            out.append("; a preview");
        }
        if raised.x < safe.x - 0.5 || raised.x + raised.z > safe.x + safe.z + 0.5 || raised.y < safe.y - 0.5 { wrong.append(" the 3D board off the safe area;"); }
        if landscape && raised.x < glass.x + glass.z { wrong.append(" the 3D board on the column;"); }
        if !landscape && raised.y + raised.w > glass.y + 0.5 { wrong.append(" the 3D board on the sheet;"); }
        if b.z < board::SMALLEST * u - 0.5 { wrong.append(" the preview under board::SMALLEST;"); }
        if b.x < safe.x - 0.5 || b.x + b.z > safe.x + safe.z + 0.5 || b.y < safe.y - 0.5 { wrong.append(" the preview off the safe area;"); }
        let sq = float4 { b.x, b.y, b.z, b.z };
        if landscape && b.x < glass.x + glass.z { wrong.append(" the preview on the column;"); }
        if !landscape && sq.y + sq.w > glass.y + 0.5 { wrong.append(" the preview on the sheet;"); }
    } else {
        out.append("; no preview");
    }
    // The language list, opened.
    drive::tap(sh, g, drive::tile(g, LANGUAGE), 2.0);
    let rows = drive::tiles(g) - n;
    let row = drive::rect(g, n);
    var list = row;
    for q in g.quads { if q.look.x == gui::GLASS { list = q.rect; } }
    format(out, "; the language list ", rows, " rows");
    if drive::verbose { format(out, " ", whole(row.z / u), " x ", whole(row.w / u), " dp"); }
    if rows != strings::LANGUAGES.len || !sh.prefs.languages_open { wrong.append(" the language list not open;"); }
    if row.w < gui::TAP * u - 0.5 { wrong.append(" a language under 88 dp;"); }
    if !inside_across(list, safe) || list.y + list.w > safe.y + safe.w + 0.5 { wrong.append(" the language list off the safe area;"); }
    print(name, ": ", out, if wrong.len > 0 { ";" } else { ", all in place" }, wrong);
    if wrong.len > 0 { failures++; }
}

fn main() {
    var g = gui::Gui {};
    let sizes = [float2 { 1280.0, 800.0 }, float2 { 800.0, 1280.0 }, float2 { 2400.0, 1080.0 }, float2 { 1080.0, 2400.0 },
                 float2 { 2436.0, 1125.0 }, float2 { 1125.0, 2436.0 }];
    let dps: f32[6] = [800.0, 800.0, 540.0, 540.0, 500.0, 500.0];
    // Insets in pixels: the Pixel's 118 px cutout and 84 px gesture bar, the iPhone's 50
    // and 34 points (66.7 and 45.3 dp of the layout's, 3 px a dp at 500).
    let insets = [float4 { 0.0, 0.0, 0.0, 0.0 }, float4 { 0.0, 0.0, 0.0, 0.0 }, float4 { 118.0, 0.0, 0.0, 84.0 },
                  float4 { 0.0, 118.0, 0.0, 84.0 }, float4 { 150.0, 0.0, 150.0, 63.0 }, float4 { 0.0, 150.0, 0.0, 102.0 }];
    let names = ["the tablet, landscape", "the tablet, portrait", "the Pixel 7a, landscape", "the Pixel 7a, portrait",
                 "the iPhone 13 mini, landscape", "the iPhone 13 mini, portrait"];
    for lang in [strings::EN, strings::ET] {
        strings::use(lang);
        print(strings::LANGUAGES[lang], ":");
        for size, i in sizes {
            drive::size = size;
            gui::short_dp = dps[i];
            g.scale = gui::scale_of(size.x, size.y);
            gui::test_faces(g);
            g.insets = insets[i];
            layout(g, names[i]);
        }
    }
    if failures > 0 {
        print(failures, " lines wrong");
        exit(1);
    }
}
