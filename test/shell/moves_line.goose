// The moves where the moves panel has no room, and a mark's tip (task 078,
// prototypes/history.html's take d and B), on a Russian game of twelve moves each, its
// moves' marks set by hand (judging off), on the flat and the 3D board.
//
// On the Pixel 7a (540 dp, its 118 px cutout and 84 px gesture bar), the Galaxy A33 (512
// dp, its notch and three-button bar assumed, 80 and 135 px), and the iPhone 13 mini (500
// dp at the density floor, 50 and 34 points; and at 375 dp, its points, where what each
// side has taken has no room and shows as counts in the line), in landscape and portrait:
// where the line goes, its tap (88 dp at least), what each side has taken, and the sheet;
// each inside the safe area, clear of the board and the tiles. The sheet opened by a tap
// on the line, its head a tile, the board still taking a tap in landscape, closed by its
// head, in portrait by the dim layer too, and by back; opened and closed by the keys (the
// line focused, Enter, then Enter on the head the sheet focuses). The setting off shows no
// line and the column as built; the list alone, no legend.
//
// On the tablet's panel: a touch on a marked move shows its tip, the next tap elsewhere
// only closes it (settings' tile under it isn't pressed), a tap on another mark moves
// it, on the same one closes it; on a desktop the tip follows the mouse.
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

// A Russian game, from and to, every move a step or a single capture (test/perft.py's
// moves, a random game of seed 9).
let GAME = ["c3", "d4", "b6", "c5", "d4", "b6", "a7", "c5", "b2", "c3", "f6", "e5", "g3", "f4", "e5", "g3",
            "f2", "h4", "d6", "e5", "c1", "b2", "b8", "a7", "c3", "b4", "c7", "b6"];
// Marks set on its moves in turn: best, good, ?!, ?, ??, only.
let MARKS: u8[6] = [ai::BEST, ai::GOOD, ai::INACCURACY, ai::MISTAKE, ai::BLUNDER, ai::ONLY];

fn whole(x: f32) -> i64 { floor(x + 0.5) as i64 }

fn overlaps(a: float4, b: float4) -> bool {
    let e: f32 = 0.5;
    return a.x + e < b.x + b.z && b.x + e < a.x + a.z && a.y + e < b.y + b.w && b.y + e < a.y + a.w;
}

fn inside(r: float4, a: float4) -> bool {
    return r.x >= a.x - 0.5 && r.y >= a.y - 0.5 && r.x + r.z <= a.x + a.z + 0.5 && r.y + r.w <= a.y + a.w + 0.5;
}

// A rect in dp from the safe area's corner.
fn dp(r: float4, safe: float4, u: f32) -> u8[>..] {
    return str(whole((r.x - safe.x) / u), ",", whole((r.y - safe.y) / u), " ", whole(r.z / u), "x", whole(r.w / u));
}

// A shell on the game, the game's moves played and marked, at rest.
fn played(raised: bool, moves: i64, g: gui::Gui&) -> shell::Shell {
    var sh = shell::new(rules::RUSSIAN);
    sh.prefs.moves = moves;
    if raised { sh.prefs.board = settings::RAISED; }
    sh.game = game::new(rules::RUSSIAN);
    shell::apply_prefs(sh);
    sh.game.judge = false;
    sh.screen = shell::GAME;
    sh.drawn = shell::GAME;
    let b .= sh.game.b;
    let v .= rules::VARIANTS[rules::RUSSIAN];
    var now = 0.0;
    var k = 0;
    while k + 1 < GAME.len {
        let from = drive::square(v, GAME[k]);
        let to = drive::square(v, GAME[k + 1]);
        var found = false;
        for i in b.moves.len {
            guard b.moves[i].from == from && b.moves[i].to == to else { continue; }
            board::play_chosen(b, i, now);
            found = true;
            break;
        }
        if !found { print("no move ", GAME[k], "-", GAME[k + 1]); }
        now += 1.0;
        drive::idle(sh, g, now);
        k += 2;
    }
    for &n, i in sh.game.notes { n.mark = MARKS[i % MARKS.len]; }
    drive::idle(sh, g, now + 1.0);
    drive::idle(sh, g, now + 2.0);
    return sh;
}

// Where the n-th tile is, by its rect, or -1.
fn tile_at(g: gui::Gui&, r: float4) -> i64 {
    for i in drive::tiles(g) {
        let t = drive::rect(g, i);
        if abs(t.x - r.x) < 0.5 && abs(t.y - r.y) < 0.5 && abs(t.z - r.z) < 0.5 && abs(t.w - r.w) < 0.5 { return i; }
    }
    return -1;
}

// The line, the catch, and the sheet on one device's screen, then the sheet opened and
// closed every way.
fn device(name: const u8[:], g: gui::Gui&, raised: bool) {
    let w = drive::size.x;
    let h = drive::size.y;
    let u = gui::scale_of(w, h);
    let safe = gui::safe(g, w, h);
    var sh = played(raised, settings::MOVES_MARKS, g);
    let l = shell::game_layout(sh, safe, u, 20.0);
    var line = str("  ", name, if raised { ", 3D" } else { ", flat" }, ": ");
    var wrong: u8[>..] = [];
    let land = l.line_as == panel::LINE_ROWS;
    if l.line_as == panel::LINE_NONE {
        print(line, "no line");
        return;
    }
    format(line, if land { "the line " } else { "the bar's line " }, dp(l.line, safe, u), ", its tap ", whole(l.line_tap.z / u), "x",
           whole(l.line_tap.w / u), " dp");
    if land {
        format(line, ", the column ", dp(l.left, safe, u), if l.counts { ", the catch as counts" } else { "" });
        if l.taken_as != panel::TAKEN_NONE { format(line, ", the catch ", dp(l.taken, safe, u)); }
    }
    format(line, ", the sheet ", whole(l.sheet.z / u), "x", whole(l.sheet.w / u), " dp");
    let b = sh.out.layout.board;
    let sq = float4 { b.x, b.y, b.z, b.z };
    format(line, if raised { ", the 3D board " } else { ", the board " }, whole((if raised { sh.out.view.rect.z } else { b.z }) / u), " dp");
    let tap = l.line_tap;
    if tap.z < gui::TAP * u - 0.5 || tap.w < gui::TAP * u - 0.5 { wrong.append(" the tap under 88 dp;"); }
    if !inside(tap, safe) || !inside(l.line, safe) { wrong.append(" the line off the safe area;"); }
    if l.taken_as != panel::TAKEN_NONE && !inside(l.taken, safe) { wrong.append(" the catch off the safe area;"); }
    let on_board = if raised { view3d::touches(sh.out.view, tap, 0.0) } else { overlaps(tap, sq) };
    if on_board { wrong.append(" the line on the board;"); }
    let me = tile_at(g, if land { l.line } else { l.line_tap });
    if me < 0 { wrong.append(" the line not a tile;"); }
    for i in drive::tiles(g) {
        guard i != me else { continue; }
        if overlaps(drive::rect(g, i), tap) { format(wrong, " on tile ", i, ";"); }
    }
    if land && l.taken_as != panel::TAKEN_NONE && overlaps(l.taken, tap) { wrong.append(" on the catch;"); }
    let side_sheet = if raised { view3d::touches(sh.out.view, l.sheet, 0.0) } else { overlaps(l.sheet, sq) };
    if land && side_sheet { wrong.append(" the sheet on the board;"); }
    print(line, if wrong.len > 0 { ";" } else { ", in place" }, wrong);

    // Opened by a tap on the line.
    let closed_tiles = drive::tiles(g);
    var t: f64 = 30.0;
    drive::tap(sh, g, drive::middle(tap), t);
    let opened = sh.game.sheet;
    var head = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads { if q.look.x == gui::BUTTON && abs(q.rect.x - l.sheet_in.x) < 0.5 && abs(q.rect.y - l.sheet_in.y) < 0.5 { head = q.rect; } }
    var said = str("    a tap on it: ", if opened { "open" } else { "closed" }, ", ", drive::tiles(g), " tiles (", closed_tiles,
                   " closed), the head ", whole(head.z / u), "x", whole(head.w / u), " dp, ", g.quads.len, " quads");
    if land && !raised {
        // The board still plays: a white piece taken up by a tap.
        let v .= rules::VARIANTS[rules::RUSSIAN];
        var piece = -1;
        for m in sh.game.b.moves { piece = m.from; }
        drive::tap(sh, g, board::center(sh.out.layout, v, piece), t + 0.1);
        format(said, ", a tap on the board ", if sh.game.b.selected == piece { "takes up a piece" } else { "does nothing" });
        drive::tap(sh, g, board::center(sh.out.layout, v, piece), t + 0.2);
    } else if !land {
        // The board under the dim layer takes nothing: a tap there closes the sheet.
        let v .= rules::VARIANTS[rules::RUSSIAN];
        var piece = -1;
        for m in sh.game.b.moves { piece = m.from; }
        let p = board::center(sh.out.layout, v, piece);
        if p.y < l.sheet.y {
            drive::tap(sh, g, p, t + 0.1);
            format(said, ", a tap on the dimmed board: ", if sh.game.sheet { "open" } else { "closed" }, ", ",
                   if sh.game.b.selected >= 0 { "a piece taken up" } else { "no piece taken up" });
            drive::tap(sh, g, drive::middle(tap), t + 0.2);
        }
    }
    drive::tap(sh, g, drive::middle(head), t + 0.3);
    format(said, "; its head: ", if sh.game.sheet { "open" } else { "closed" });
    drive::tap(sh, g, drive::middle(tap), t + 0.4);
    shell::back(sh, t + 0.5);
    drive::idle(sh, g, t + 0.6);
    format(said, "; back: ", if sh.game.sheet { "open" } else { "closed" }, ", on ",
           if sh.screen == shell::GAME { "the game" } else { "another screen" });
    // The keys: the line focused, Enter; the head focused, Enter.
    g.focus = game::LINE_ID;
    drive::key(sh, g, gui::STEP_NONE, true, t + 0.7);
    let keyed = sh.game.sheet;
    drive::idle(sh, g, t + 0.8);
    drive::idle(sh, g, t + 0.9);
    let at_head = g.focus == game::SHEET_HEAD;
    drive::key(sh, g, gui::STEP_NONE, true, t + 1.0);
    drive::idle(sh, g, t + 1.1);
    drive::idle(sh, g, t + 1.2);
    format(said, "; the keys: ", if keyed { "open" } else { "closed" }, ", the head ", if at_head { "focused" } else { "not focused" },
           ", then ", if sh.game.sheet { "open" } else { "closed" }, ", the line ",
           if g.focus == game::LINE_ID { "focused" } else { "not focused" });
    print(said);
}

// The setting off and the list alone on the Pixel's landscape.
fn settings_line(g: gui::Gui&) {
    let w = drive::size.x;
    let h = drive::size.y;
    let u = gui::scale_of(w, h);
    let safe = gui::safe(g, w, h);
    var off = played(false, settings::MOVES_HIDDEN, g);
    let lo = shell::game_layout(off, safe, u, 20.0);
    print("  the setting off: line ", lo.line_as, ", the column ", dp(lo.left, safe, u), ", ", drive::tiles(g), " tiles");
    // The 3D board with the line and without it.
    var off3 = played(true, settings::MOVES_HIDDEN, g);
    let w3 = off3.out.view.rect.z / u;
    var on3 = played(true, settings::MOVES_MARKS, g);
    print("  the 3D board ", whole(on3.out.view.rect.z / u), " dp across with the line, ", whole(w3), " with the setting off");
    var list = played(false, settings::MOVES_LIST, g);
    let ll = shell::game_layout(list, safe, u, 20.0);
    drive::tap(list, g, drive::middle(ll.line_tap), 30.0);
    // The legend's words, in the small face, are the frame's last quads but the list's.
    var words = 0;
    for q in g.quads { if q.look.x == gui::TEXT && q.rect.y > ll.sheet_in.y + ll.sheet_in.w - game::legend_h(g, ll.sheet_in.z) { words++; } }
    print("  the list alone: line ", ll.line_as, ", sheet ", if list.game.sheet { "open" } else { "closed" }, ", ", words,
          " glyphs at its foot");
}

// The tablet's panel: a mark's tip by touch and by the mouse.
fn tips(g: gui::Gui&) {
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(1280.0, 800.0);
    gui::test_faces(g);
    var sh = played(false, settings::MOVES_MARKS, g);
    let gm .= sh.game;
    var first = -1;
    var second = -1;
    for m in gm.marks_at {
        if first < 0 { first = m.ply; } else if second < 0 { second = m.ply; }
    }
    print("the tablet's panel: ", gm.marks_at.len, " marked moves in view, notes ", first, " and ", second);
    var at = float4 { 0.0, 0.0, 0.0, 0.0 };
    var other = float4 { 0.0, 0.0, 0.0, 0.0 };
    for m in gm.marks_at {
        if m.ply == first { at = m.rect; }
        if m.ply == second { other = m.rect; }
    }
    drive::tap(sh, g, drive::middle(at), 30.0);
    var tip = float4 { 0.0, 0.0, 0.0, 0.0 };
    for q in g.quads { if q.look.x == gui::GLASS { tip = q.rect; } }
    let safe = gui::safe(g, 1280.0, 800.0);
    print("  a touch on note ", first, ": tip ", gm.tip, ", ", whole(tip.z), "x", whole(tip.w), " dp at ", whole(tip.x), ",",
          whole(tip.y), if inside(tip, safe) { ", in the safe area" } else { ", off the safe area" },
          if tip.y + tip.w <= at.y || tip.y >= at.y + at.w { ", clear of its move" } else { ", on its move" });
    // Settings' tile: the next tap only closes the tip.
    drive::tap(sh, g, drive::control(g, 1), 31.0);
    drive::idle(sh, g, 31.5);
    print("  a tap on settings: tip ", gm.tip, ", on ", if sh.screen == shell::GAME { "the game" } else { "settings" });
    drive::tap(sh, g, drive::middle(at), 32.0);
    drive::tap(sh, g, drive::middle(other), 32.5);
    print("  then note ", first, ", then note ", second, ": tip ", gm.tip);
    drive::tap(sh, g, drive::middle(other), 33.0);
    print("  note ", second, " again: tip ", gm.tip);
    drive::tap(sh, g, drive::middle(other), 33.5);
    shell::back(sh, 34.0);
    drive::idle(sh, g, 34.1);
    print("  back with a tip: tip ", gm.tip, ", on ", if sh.screen == shell::GAME { "the game" } else { "another screen" });
    // Under the mouse: on a marked move, the tip; off it, none.
    gui::desktop_scale = 1.0;
    drive::idle(sh, g, 34.5);
    drive::idle(sh, g, 34.6);
    var mouse = -1;
    for m in gm.marks_at {
        if mouse < 0 {
            mouse = m.ply;
            other = m.rect;
        }
    }
    second = mouse;
    let came = drive::frame(sh, g, drive::middle(other), false, false, false, 35.0);
    let rest = drive::frame(sh, g, drive::middle(other), false, false, false, 35.1);
    let over = gm.tip;
    let went = drive::frame(sh, g, float2 { 5.0, 5.0 }, false, false, false, 35.2);
    let after = drive::frame(sh, g, float2 { 5.0, 5.0 }, false, false, false, 35.3);
    print("  the mouse over note ", second, ": tip ", over, ", then away: tip ", gm.tip, "; drawn as it came ", came, ", at rest ",
          rest, ", as it went ", went, ", at rest ", after);
    gui::desktop_scale = 0.0;
}

fn main() {
    puzzles::load();
    strings::use(strings::EN);
    var g = gui::Gui {};
    // The devices: size, dp, insets in landscape and in portrait (pixels).
    let names = ["the Pixel 7a", "the Galaxy A33 (insets assumed)", "the iPhone 13 mini", "the iPhone 13 mini at its points"];
    let sizes = [float2 { 2400.0, 1080.0 }, float2 { 2400.0, 1080.0 }, float2 { 2436.0, 1125.0 }, float2 { 2436.0, 1125.0 }];
    let dps: f32[4] = [540.0, 512.0, 500.0, 375.0];
    let land = [float4 { 118.0, 0.0, 0.0, 84.0 }, float4 { 80.0, 0.0, 135.0, 0.0 }, float4 { 150.0, 0.0, 150.0, 68.0 },
                float4 { 150.0, 0.0, 150.0, 63.0 }];
    let port = [float4 { 0.0, 118.0, 0.0, 84.0 }, float4 { 0.0, 80.0, 0.0, 135.0 }, float4 { 0.0, 150.0, 0.0, 102.0 },
                float4 { 0.0, 150.0, 0.0, 102.0 }];
    for name, i in names {
        gui::short_dp = dps[i];
        for turned in [false, true] {
            drive::size = if turned { float2 { sizes[i].y, sizes[i].x } } else { sizes[i] };
            g.scale = gui::scale_of(drive::size.x, drive::size.y);
            gui::test_faces(g);
            g.insets = if turned { port[i] } else { land[i] };
            let safe = gui::safe(g, drive::size.x, drive::size.y);
            print(name, if turned { ", portrait" } else { ", landscape" }, ", ", whole(dps[i]), " dp, safe ",
                  whole(safe.z / g.scale), " x ", whole(safe.w / g.scale), " dp:");
            for raised in [false, true] { device(if turned { "portrait" } else { "landscape" }, g, raised); }
            if i == 0 && !turned { settings_line(g); }
        }
    }
    g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
    gui::short_dp = 800.0;
    tips(g);
}
