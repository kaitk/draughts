// The daily puzzles in the shell (shell/today.goose, task 088), headless, on a test
// library of 200 one-move captures written as the generated file is, difficulties 300 to
// 2290, Captures and Shots by turns. Today is locked until Learn is solved, all of it: the
// library ends with its locked row, home notes the puzzles solved in the set. Once open,
// a new day picks today's four at the player's rating, seeded from the course's stars,
// from Captures alone while no Shots puzzle is solved, marks them had, and keeps them in
// the player's file; the same day keeps them, home and the library shown again. A daily
// puzzle opens from its tile in Today's row and plays on the puzzle screen with today's
// dots over next; its first solve keeps its stars and moves the rating, a replay the same
// day keeps the most stars and leaves the rating; next goes through today's set and after
// the last back to the library, whose mark turns to the moon, and home shows a check in
// place of the dots. The next day picks four more, none had before, from Shots too once one
// is solved in the course; the setting's 5 a day, chosen today, counts from the next day.
// The test library's ids run against its order, so a record by id is read through the
// index. A player's file from before the library had ids, its puzzles kept by their
// lines then, reads today's puzzles and those had as the same puzzles of the built-in
// library, whose first puzzles' ids are those lines.
// Then the layouts at the tablet's size and a 20:9 phone's at 480 dp in both orientations,
// four and ten a day: the library (every tap 88 dp at least, none off the screen nor over
// another, Today's tiles in the picker's ids) and a daily puzzle (its dots on the screen,
// clear of every tile).
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

let DAY = 20406;            // 2025-11-14
let SET = rules::INTERNATIONAL;

// The test library: one capture, 32x21 over 27, at each difficulty, the ids from the
// hardest.
fn library_text() -> u8[>..] {
    var t: u8[>..] = [];
    t.append("# a test library\nvariant international\n");
    for i in 200 {
        let theme = if i % 2 == 0 { "captures 1" } else { "shots 2" };
        format(t, 199 - i, " | ", 300 + 10 * i, " | ", theme, " | take 1 in 1 | W:W32,47:B27,5 | 32x21\n");
    }
    return t;
}

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

// Today's tiles in the library: the square picks (the draughts switch's are wider).
fn today_tiles(g: gui::Gui&, out: float4[..16]&) {
    out.clear();
    for q in g.quads {
        guard q.look.x == gui::BUTTON && (q.extra.y == gui::CHOICE || q.extra.y == gui::CHOSEN) else { continue; }
        if abs(q.rect.z - q.rect.w) < 0.5 && out.len < 16 { out.push(q.rect); }
    }
}

// Today's dots: the round fills and rings DOT dp across at most, those in the glow, the
// one ringed, and the rest.
fn dots(g: gui::Gui&, out: float4[..16]&) -> i64, i64, i64 {
    out.clear();
    let d = picker::DOT * g.scale;
    var lit = 0;
    var ringed = 0;
    var dim = 0;
    for q in g.quads {
        let round = abs(q.rect.z - q.rect.w) < 0.5 && abs(q.look.y - 0.5 * q.rect.z) < 0.5;
        guard (q.look.x == gui::FILL || q.look.x == gui::RING) && round && q.rect.z < d + 1.0 else { continue; }
        if out.len < 16 { out.push(q.rect); }
        if q.look.x == gui::RING { ringed++; } else if q.look.z > 0.5 { lit++; } else { dim++; }
    }
    return lit, ringed, dim;
}

// Today's record as the player's file keeps it.
fn record(sh: shell::Shell&) -> u8[>..] {
    let t .= sh.prefs.today[SET];
    var out: u8[>..] = [];
    format(out, "day ", t.day, ",");
    for id, k in t.picked.list {
        let i = puzzles::place_of(puzzles::library, id);
        format(out, " ", puzzles::library.list[i].difficulty, if puzzles::library.list[i].theme == puzzles::SHOTS { "s" } else { "c" },
               ":", t.stars[k]);
    }
    var seen = 0;
    for w in sh.prefs.seen[SET] { seen += popcount(w); }
    format(out, "; rating ", sh.prefs.puzzle_rating[SET], " after ", sh.prefs.puzzle_rated[SET], ", ", seen, " had");
    return out;
}

// What the library shows of Today: its tiles, lit, the moon, the lock.
fn library_line(sh: shell::Shell&, g: gui::Gui&) -> u8[>..] {
    var tiles: float4[..16] = [];
    today_tiles(g, tiles);
    var lit = -1;
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.extra.y == gui::CHOSEN else { continue; }
        for r, k in tiles { if r == q.rect { lit = k; } }
    }
    return str(tiles.len, " tiles, lit ", lit, ", calendar ", icons(g, gui::TODAY), ", moon ", icons(g, gui::MOON), ", locks ",
               icons(g, gui::LOCK), ", how to play's mark ", icons(g, gui::HOW));
}

// What home's Puzzles row shows of today: its dots, or the check.
fn home_line(g: gui::Gui&) -> u8[>..] {
    var at: float4[..16] = [];
    let lit, ringed, dim = dots(g, at);
    return str("dots ", lit, " filled ", dim, " not, check ", icons(g, gui::CHECK));
}

fn library(sh: shell::Shell&, g: gui::Gui&, now: f64) {
    sh.screen = shell::PICKER;
    sh.theme = -1;
    drive::idle(sh, g, now);
}

fn home(sh: shell::Shell&, g: gui::Gui&, now: f64) {
    sh.screen = shell::HOME;
    drive::idle(sh, g, now);
}

// Taps today's tile k in the library and waits out the transition.
fn open(sh: shell::Shell&, g: gui::Gui&, k: i64, now: f64) {
    var tiles: float4[..16] = [];
    today_tiles(g, tiles);
    drive::tap(sh, g, drive::middle(tiles[k]), now);
    drive::idle(sh, g, now + 1.0);
}

fn sq(n: i64) -> u8[>..] {
    let v .= rules::VARIANTS[SET];
    return drive::name(v, v.bit_of[n]);
}

fn tap_sq(sh: shell::Shell&, g: gui::Gui&, n: i64, now: f64) { drive::tap(sh, g, drive::at(sh.out.layout, sq(n)), now); }

// Solves the daily puzzle showing, after `misses` taps on 47, which can't move while a
// capture is due; then lets the stars pop.
fn solve(sh: shell::Shell&, g: gui::Gui&, misses: i64, now: f64) {
    var t = now;
    for m in misses {
        tap_sq(sh, g, 47, t);
        t += 0.5;
    }
    tap_sq(sh, g, 32, t);
    tap_sq(sh, g, 21, t + 0.2);
    drive::idle(sh, g, t + 2.0);
}

// Next on the puzzle screen (back, settings, start over, next), then the transition.
fn next(sh: shell::Shell&, g: gui::Gui&, now: f64) {
    drive::tap(sh, g, drive::tile(g, 3), now);
    drive::idle(sh, g, now + 1.0);
}

fn playing(sh: shell::Shell&, g: gui::Gui&) -> u8[>..] {
    var at: float4[..16] = [];
    let lit, ringed, dim = dots(g, at);
    let screen = if sh.screen == shell::PUZZLE { "the puzzle" } else if sh.screen == shell::PICKER { "the library" } else { "home" };
    return str(screen, ", today's ", sh.puzzle.daily, ", its dots ", lit, " solved ", ringed, " this ", dim, " to come");
}

// Every tap's rect on the screen the last frame declared, with what's wrong.
fn check(g: gui::Gui&, what: const u8[:], extra: const u8[:]) {
    let w = drive::size.x;
    let h = drive::size.y;
    let u = g.scale;
    let safe = gui::safe(g, w, h);
    let n = drive::tiles(g);
    var wrong: u8[>..] = [];
    var below = 0;
    for i in n {
        let r = drive::rect(g, i);
        let across = r.x >= safe.x - 0.5 && r.x + r.z <= safe.x + safe.z + 0.5;
        if across && r.y >= safe.y - 0.5 && r.y + r.w > safe.y + safe.w + 0.5 {
            below++;
        } else if !across || r.y < safe.y - 0.5 || r.y + r.w > safe.y + safe.w + 0.5 {
            format(wrong, " tile ", i, " off the screen;");
        }
        for j in i { if overlaps(r, drive::rect(g, j)) { format(wrong, " tiles ", j, " and ", i, " overlap;"); } }
        if r.z < gui::TAP * u - 0.5 || r.w < gui::TAP * u - 0.5 { format(wrong, " tile ", i, " under 88 dp;"); }
    }
    var at: float4[..16] = [];
    dots(g, at);
    for d in at {
        if d.x < safe.x || d.y < safe.y || d.x + d.z > safe.x + safe.z || d.y + d.w > safe.y + safe.w { format(wrong, " a dot off the screen;"); }
        for i in n { if overlaps(d, drive::rect(g, i)) { format(wrong, " a dot on tile ", i, ";"); } }
    }
    var scrolled: u8[>..] = [];
    if below > 0 { format(scrolled, ", ", below, " below the foot (the list scrolls)"); }
    print("  ", what, ": ", n, " tiles", extra, scrolled[..], ", ", g.quads.len, " quads",
          if wrong.len > 0 { str(";", wrong) } else { str(", all in place") });
}

fn layouts(text: const u8[:], g: gui::Gui&, count: i64) {
    let sizes = [float2 { 1920.0, 1200.0 }, float2 { 1200.0, 1920.0 }, float2 { 2400.0, 1080.0 }, float2 { 1080.0, 2400.0 }];
    let names = ["the tablet, landscape", "the tablet, portrait", "a 20:9 phone at 480 dp, landscape",
                 "a 20:9 phone at 480 dp, portrait"];
    for size, i in sizes {
        gui::short_dp = if i < 2 { 800.0 } else { 480.0 };
        drive::size = size;
        g.scale = gui::scale_of(size.x, size.y);
        gui::test_faces(g);
        var sh = fresh(text);
        sh.prefs.daily_count = count;
        learn_all(sh);
        library(sh, g, 0.0);
        var tiles: float4[..16] = [];
        today_tiles(g, tiles);
        var where: u8[>..] = [];
        format(where, ", Today's ", tiles.len, " from ", dp(tiles[0], g.scale), " to ", dp(tiles[tiles.len - 1], g.scale));
        print(names[i], ", ", count, " a day:");
        check(g, "the library", where[..]);
        open(sh, g, 1, 1.0);
        var at: float4[..16] = [];
        dots(g, at);
        var each: u8[>..] = [];
        format(each, ", ", at.len, " dots from ", dp(at[0], g.scale), ", next ", dp(drive::rect(g, 3), g.scale));
        check(g, "a daily puzzle", each[..]);
        // Round the 3D board, in its corner panels.
        sh.prefs.board = settings::RAISED;
        shell::apply_prefs(sh);
        drive::idle(sh, g, 3.0);
        dots(g, at);
        each.clear();
        format(each, ", ", at.len, " dots from ", dp(at[0], g.scale), ", next ", dp(drive::rect(g, 3), g.scale));
        check(g, "on the 3D board", each[..]);
    }
    gui::short_dp = 800.0;
}

// A shell with the test library and the day, at home.
fn fresh(text: const u8[:]) -> shell::Shell {
    var sh = shell::new(SET);
    puzzles::index_library(text, puzzles::library);
    sh.library = SET;
    sh.library_text = text;
    sh.day = DAY;
    return sh;
}

// Every Learn puzzle of the set solved, with three stars.
fn learn_all(sh: shell::Shell&) {
    for p in puzzles::all.list { if p.theme == puzzles::LEARN { sh.prefs.stars[SET][p.id] = 3; } }
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    let text = library_text();
    var g = gui::Gui {};
    drive::size = float2 { 1920.0, 1200.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    var sh = fresh(text);
    print("the library: ", puzzles::library.list.len, " puzzles");
    print("Today's tiles' ids ", picker::TODAY_IDS, " to ", picker::TODAY_IDS + puzzles::MAX_DAILY - 1, ", the picker's ", gui::PICKER_IDS,
          " to ", gui::PICKER_IDS + gui::IDS_SPAN[5] - 1, ", How to play's ", gui::PICKER_IDS + 8);

    // Locked: one Learn puzzle short of all.
    let learn = puzzles::theme_count(puzzles::all, puzzles::LEARN);
    var k = 0;
    for p in puzzles::all.list {
        guard p.theme == puzzles::LEARN && k < learn - 1 else { continue; }
        sh.prefs.stars[SET][p.id] = 2;
        k++;
    }
    home(sh, g, 0.0);
    let solved, all = picker::solved_all(sh.prefs.stars[SET]);
    print("Learn but one: open ", picker::today_open(sh.prefs.stars[SET]), ", ", picker::today_more(sh.prefs.stars[SET]),
          " more; home notes ", solved, " / ", all, ", ", home_line(g));
    library(sh, g, 0.1);
    print("  the library: ", library_line(sh, g), "; ", record(sh));

    // Learn's last solved: Today opens, and the day is picked.
    learn_all(sh);
    sh.changed = false;
    home(sh, g, 0.2);
    print("all of Learn: open ", picker::today_open(sh.prefs.stars[SET]), "; ", record(sh), "; to save ", sh.changed);
    print("  home: ", home_line(g));
    var written: u8[>..] = [];
    settings::write(sh.prefs, written);
    let back = settings::parse(written);
    print("  read back: day ", back.today[SET].day, ", ", back.today[SET].picked.list.len, " puzzles, the same ",
          back.today[SET].picked.list == sh.prefs.today[SET].picked.list);
    sh.changed = false;
    library(sh, g, 0.3);
    print("  the library: ", library_line(sh, g));
    home(sh, g, 0.4);
    library(sh, g, 0.5);
    print("the same day again: ", record(sh), "; to save ", sh.changed);

    // The first: solved at once, three stars, the rating moved.
    open(sh, g, 0, 1.0);
    print("tile 0: ", playing(sh, g));
    solve(sh, g, 0, 3.0);
    print("  solved: ", playing(sh, g), "; ", record(sh));
    next(sh, g, 6.0);
    print("  next: ", playing(sh, g));
    // Back to the library, then the first again: a miss, two stars, the three kept.
    drive::tap(sh, g, drive::tile(g, 0), 8.0);
    drive::idle(sh, g, 9.0);
    print("  back: ", playing(sh, g), ", the library: ", library_line(sh, g));
    open(sh, g, 0, 10.0);
    solve(sh, g, 1, 12.0);
    print("  played again with a miss: won ", sh.puzzle.won, "; ", record(sh));
    // On through the rest, the second with two misses.
    next(sh, g, 16.0);
    solve(sh, g, 2, 18.0);
    next(sh, g, 22.0);
    solve(sh, g, 0, 24.0);
    next(sh, g, 28.0);
    print("  the fourth: ", playing(sh, g));
    solve(sh, g, 0, 30.0);
    print("  solved: ", playing(sh, g), "; ", record(sh));
    next(sh, g, 34.0);
    print("  next after the last: ", playing(sh, g), ", the library: ", library_line(sh, g));
    home(sh, g, 36.0);
    print("  home: ", home_line(g));

    // Five a day from now, chosen today: today stays four.
    settings::choose(sh.prefs, settings::DAILY_ROW, 2);
    library(sh, g, 37.0);
    print("5 a day chosen: ", record(sh));
    // The next day: five more, none had, still Captures alone.
    sh.day = DAY + 1;
    home(sh, g, 38.0);
    print("the next day: ", record(sh));
    print("  home: ", home_line(g));
    // A Shots puzzle solved in the course: the day after may pick Shots.
    for p in puzzles::all.list {
        guard p.theme == puzzles::SHOTS else { continue; }
        sh.prefs.stars[SET][p.id] = 1;
        break;
    }
    sh.day = DAY + 2;
    library(sh, g, 39.0);
    print("a Shots puzzle solved, the day after: ", record(sh));

    // Starting again clears it all; the puzzles a day stay.
    shell::start_again(sh, 0);
    print("started again: ", record(sh), ", ", sh.prefs.daily_count, " a day");

    // A player's file from before ids, with the built-in library: its record's and its
    // seen bits' puzzles are those of the lines they named then.
    old_file();

    // The layouts.
    layouts(text, g, 4);
    layouts(text, g, 10);
}

// The built-in International library's first lines (2026-11-14), before it had ids: the
// line a player's file then named a puzzle by, and its position.
let OLD_LINES = [0, 12, 40, 55, 70];
let OLD_FENS = ["B:W16,21,26,28,32,33,42:B15,20,24,25,29,30,34", "B:W23,31,32,35,36,40,41:B8,11,12,13,14,17,19",
                "W:W35,43,45,47,48,49,50:B9,19,20,25,28,29,30", "B:W22,29,31,34,35,37,38,39:B4,9,10,14,15,19,20,24",
                "W:W18,30,34,35,39,44,46,48:B1,3,12,16,21,23,24,31"];

fn old_file() {
    var sh = shell::new(SET);
    sh.prefs = settings::parse("daily.international = 20406 12:3 40:0 55:0 70:0\nseen.international = 0:1001\n");
    learn_all(sh);
    shell::load_library(sh);
    sh.day = DAY;
    shell::read_daily(sh);
    var same = 0;
    for pz, k in sh.daily.list { if rules::fen(pz.start) == OLD_FENS[k + 1] { same++; } }
    var had = 0;
    var pz = default<puzzles::Puzzle>();
    for line, k in OLD_LINES {
        guard k == 0 || k == 1 else { continue; }
        if puzzles::is_seen(sh.prefs.seen[SET], line) && puzzles::entry_by_id(sh.library_text, puzzles::library, line, pz) &&
           rules::fen(pz.start) == OLD_FENS[k] { had++; }
    }
    print("a file from before ids: today's ", sh.daily.list.len, " read, ", same, " the same puzzles; had ", had, " of 2 the same");
}
