// A past game's replay (shell/replay.goose, task 078's C): a game's row on the results
// screen opens it at the game's end; the steps go to the start, back, on (the move played
// on the board), and to the end; a move tapped in the list jumps there; Left and Right
// step from anywhere, the keys' focus on a move shows it and follows the steps; back
// goes to the results as they were left. A capture written with its stops left out
// (from and to alone) still replays. Nothing of it reaches the game in progress (its
// saved image the same on the replay as before), the history file, or the ratings. Then
// the layouts at the sizes test/shell/sizes uses: every tile at least a tap, inside the
// safe area and apart, the board clear of them, back and play from here as tall and
// level, the line saying a game from here doesn't count over the board, on no tile, and
// inside the safe area, with why or without, and the frame's quads under gui::MAX_QUADS.
import std;
import vec;
import math;
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
    let dir = if is_dir("build") { str("build/replay-files/") } else { str("replay-files/") };
    make_dir(dir);
    var names: u8[>..] = [];
    list_dir(dir, names);
    for name in split(names, '\n') { if name.len > 0 { delete_file(str(dir, name)); } }
    return dir;
}

var now = 1.0;
fn tick() -> f64 {
    now += 0.5;
    return now;
}

// The rect of control id as the last frame offered it to the keys' focus.
fn spot(g: gui::Gui&, id: i64) -> float4 {
    for s in g.spots { if s.id == id { return s.rect; } }
    print("  no control ", id);
    return float4 { -100.0, -100.0, 1.0, 1.0 };
}

// Whether r, a rect with some size, lies inside a.
fn within(r: float4, a: float4) -> bool {
    return r.z > 0.0 && r.x >= a.x - 0.5 && r.y >= a.y - 0.5 && r.x + r.z <= a.x + a.z + 0.5 && r.y + r.w <= a.y + a.w + 0.5;
}

fn press(sh: shell::Shell&, g: gui::Gui&, id: i64) { drive::tap(sh, g, drive::middle(spot(g, id)), tick()); }

// What the replay shows: the move, the board's position, and whether it is the one the
// game's moves give there.
fn shown(sh: shell::Shell&) -> u8[>..] {
    let r .= sh.past.replay;
    let b .= r.b;
    let right = rules::same(b.pos, r.pos[r.ply]);
    var s = str("move ", r.ply, " of ", r.plies.len, ", the board ", if right { "right" } else { "WRONG" });
    if b.moving { s.append(", moving"); }
    if b.has_last { format(s, ", last ", drive::name(rules::VARIANTS[b.variant], b.last.from), "-",
                           drive::name(rules::VARIANTS[b.variant], b.last.to)); }
    return s;
}

// The best move on the board: the hint's piece, where it goes, and its stops ringed, and
// whether they are the best move from the position shown.
fn hint(sh: shell::Shell&) -> u8[>..] {
    let r .= sh.past.replay;
    let b .= r.b;
    guard b.glow >= 0 else { return str("no best move on the board"); }
    let v .= rules::VARIANTS[b.variant];
    let m = r.plies[r.ply].best;
    let right = b.glow == m.from as i64 && b.hint_to == m.to as i64 && popcount(b.hint_via) == max(m.path.len - 2, 0);
    return str("the best move ", drive::name(v, b.glow), "-", drive::name(v, b.hint_to), " on the board, ", popcount(b.hint_via),
               " stops ringed, ", if right { "right" } else { "WRONG" });
}

// The squares numbered on the board, by name.
fn numbered(sh: shell::Shell&) -> u8[>..] {
    let v .= rules::VARIANTS[sh.past.replay.b.variant];
    var s: u8[>..] = [];
    var left = replay::numbered(sh.past.replay);
    while left != 0 {
        if s.len > 0 { s.push(' '); }
        s.append(drive::name(v, ctz(left) as i64));
        left &= left - 1;
    }
    return s;
}

// The move shown's way in dots on the board as the last frame laid it out: how many, the
// stops' larger ones, and how near a small one comes to the squares' centres at its ends
// and at its stops, in squares; and the squares numbered.
fn dots(sh: shell::Shell&) -> u8[>..] {
    let r .= sh.past.replay;
    let l = sh.out.layout;
    let v .= rules::VARIANTS[r.b.variant];
    let m = r.plies[r.ply - 1].move;
    var ds: replay::Dots = [];
    replay::dots_of(l, v, m, ds);
    let sq = l.inner.w;
    var large = 0;
    var ends:  f32 = 1.0e9;
    var stops: f32 = 1.0e9;
    for d in ds {
        if d.z > 0.1 * sq { large++; continue; }
        for s, i in m.path {
            let c = board::center(l, v, s as i64);
            let k = sqrt((d.x - c.x) * (d.x - c.x) + (d.y - c.y) * (d.y - c.y)) / sq;
            if i == 0 || i == m.path.len - 1 { ends = min(ends, k); } else { stops = min(stops, k); }
        }
    }
    var s = str(m.path.len, " squares stood on, ", ds.len, " dots, ", large, " at stops; nearest the ends ",
                floor(100.0 * ends + 0.5) / 100.0);
    if large > 0 { format(s, ", the stops ", floor(100.0 * stops + 0.5) / 100.0); }
    format(s, "; numbered ", numbered(sh));
    return s;
}

// The game's moves with each capture's stops left out, written "from-to" or "fromxto".
fn ends_only(line: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    for field, i in split(line, '\t') {
        if i > 0 { out.push('\t'); }
        let k, v, ok = split_once(field, '=');
        guard ok && k == "moves" else {
            out.append(field);
            continue;
        }
        out.append("moves=");
        for word, j in split(v, ' ') {
            if j > 0 { out.push(' '); }
            var a = word.len;
            var z = 0;
            for c, n in word {
                if (c == 'x' || c == ':') && a == word.len { a = n; }
                if c == 'x' || c == ':' { z = n; }
            }
            if a < word.len { out.append(word[..a + 1]); out.append(word[z + 1..]); } else { out.append(word); }
        }
    }
    return out;
}

// The tiles the last frame declared: how many, the smallest, and whether all are inside
// `safe` and apart and off the board; the board's size; the quads.
fn check(g: gui::Gui&, sh: shell::Shell&, safe: float4) -> u8[>..] {
    let n = drive::tiles(g);
    let b = sh.out.layout.board;
    var least: f32 = 1.0e9;
    var inside = true;
    var apart = true;
    var off_board = true;
    for i in n {
        let r = drive::rect(g, i);
        least = min(least, min(r.z, r.w) / g.scale);
        if r.x < safe.x - 0.5 || r.y < safe.y - 0.5 || r.x + r.z > safe.x + safe.z + 0.5 || r.y + r.w > safe.y + safe.w + 0.5 {
            inside = false;
        }
        if r.x < b.x + b.z - 0.5 && b.x < r.x + r.z - 0.5 && r.y < b.y + b.z - 0.5 && b.y < r.y + r.w - 0.5 { off_board = false; }
        for j in i + 1..n {
            let q = drive::rect(g, j);
            if r.x < q.x + q.z - 0.5 && q.x < r.x + r.z - 0.5 && r.y < q.y + q.w - 0.5 && q.y < r.y + r.w - 0.5 { apart = false; }
        }
    }
    let board_in = b.x >= safe.x - 0.5 && b.y >= safe.y - 0.5 && b.x + b.z <= safe.x + safe.z + 0.5 && b.y + b.z <= safe.y + safe.w + 0.5;
    var moves = 0;
    for s in g.spots { if s.id >= replay::MOVE_ID { moves++; } }
    let rows = floor(10.0 * sh.past.replay.rows + 0.5) / 10.0;
    // The line saying a game from here doesn't count: over the board, as wide, on no tile.
    let note = sh.past.replay.note;
    var over = abs(note.y + note.w - b.y) < 0.5 && abs(note.x - b.x) < 0.5 && abs(note.z - b.z) < 0.5;
    for i in n {
        let q = drive::rect(g, i);
        if note.x < q.x + q.z - 0.5 && q.x < note.x + note.z - 0.5 && note.y < q.y + q.w - 0.5 && q.y < note.y + note.w - 0.5 { over = false; }
    }
    // Back and play from here: as tall, level.
    let back = spot(g, replay::BACK_ID);
    let play = spot(g, replay::PLAY_ID);
    let level = abs(back.w - play.w) < 0.5 && abs(back.y - play.y) < 0.5;
    // The taps but the list's moves: the smallest across, inside the safe area. The bulb:
    // a fifth step tile, or the glass's line for the best move as a thin tile.
    var tap: f32 = 1.0e9;
    var taps_in = true;
    var bulb = "none";
    for s in g.spots {
        guard s.id < replay::MOVE_ID else { continue; }
        tap = min(tap, min(s.rect.z, s.rect.w) / g.scale);
        if !within(s.rect, safe) { taps_in = false; }
        if s.id == replay::BULB_ID { bulb = "a step tile"; }
        if s.id == replay::BEST_LINE_ID { bulb = "the glass's line"; }
    }
    return str(n, " tiles, smallest ", (least + 0.5) as i64, " dp, inside ", inside, ", apart ", apart, ", off the board ",
               off_board, "; taps ", (tap + 0.5) as i64, " dp at least, inside ", taps_in, "; the bulb ", bulb, "; board ",
               (b.z / g.scale + 0.5) as i64, " dp, inside ", board_in, "; the line ",
               if sh.past.replay.why { "why" } else { "short" }, ", over the board ", over, ", inside ", within(note, safe),
               "; back and play from here level ", level, "; ",
               moves, " moves listed, ", rows, " rows in view; quads ", g.quads.len);
}

struct Size {
    name:   const u8[:],
    size:   float2,
    dp:     f32,
    insets: float4,
}

// A frame with Tab pressed.
fn tab(sh: shell::Shell&, g: gui::Gui&) {
    gui::begin(g, gui::Input { at: drive::AWAY, tab: 1, .. }, g.scale, tick());
    let f .= shell::frame(sh, g, drive::size.x, drive::size.y, now);
}

fn same(a: i64[rules::VARIANT_COUNT], b: i64[rules::VARIANT_COUNT]) -> bool {
    for x, i in a { if x != b[i] { return false; } }
    return true;
}

fn main() {
    strings::use(strings::EN);
    let dir = folder();
    // Three games: International (60 moves), Russian with its captures' stops left out
    // (40), and International again, the newest (90 at most; it ends at the 80th).
    let first = drive::past_line(rules::INTERNATIONAL, 60, 1762819200);
    let russian = ends_only(drive::past_line(rules::RUSSIAN, 40, 1762822800)[..]);
    let newest = drive::past_line(rules::INTERNATIONAL, 90, 1762826400);
    let text = str(first, "\n", russian, "\n", newest, "\n");
    let path = str(dir, "history-1.txt");
    write_file(path, text);

    var sh = shell::new(rules::INTERNATIONAL);
    var ps = players::Players {};
    sh.prefs = players::load(ps, dir, true);
    sh.players = ps;
    // A game in progress against the computer, two moves in: what home's continue goes
    // back to, which the replay must leave as it is.
    game::start(sh.game, rules::INTERNATIONAL, 0, rules::BLACK, game::MEDIUM, 40, 0);
    var legal: rules::Moves = [];
    for k in 2 {
        rules::generate(sh.game.b.pos, legal);
        board::start_move(sh.game.b, 0, 0.0);
        board::update(sh.game.b, 10.0);
    }
    let saved = shell::save(sh);
    let rating = sh.prefs.rating;
    var g = gui::Gui {};
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(drive::size.x, drive::size.y);
    gui::test_faces(g);
    drive::idle(sh, g, tick());
    // Home's games row opens the results.
    press(sh, g, gui::HOME_IDS + 7);
    drive::idle(sh, g, tick());
    print("results: screen ", sh.screen, ", ", sh.past.games.len, " games");

    // The first row, the newest game: its replay, at its end.
    press(sh, g, results::ROW_ID);
    drive::idle(sh, g, tick());
    print("its row tapped: screen ", sh.screen, " (replay ", shell::REPLAY, "), ", rules::VARIANT_NAMES[sh.past.replay.game.variant],
          ", ", shown(sh));
    let image = shell::save(sh);
    print("  the saved image on the replay is the one before: ", image == saved, ", screen kept as home");
    for name, k in ["the start", "back", "on", "the end"] {
        // Each step from the middle of the game.
        replay::go(sh.past.replay, 45, 0.0);
        press(sh, g, replay::STEP_ID + k);
        print(name, ": ", shown(sh));
        drive::idle(sh, g, tick());
    }
    replay::go(sh.past.replay, 0, 0.0);
    drive::idle(sh, g, tick());
    press(sh, g, replay::STEP_ID + 1);
    print("back at the start: ", shown(sh));
    press(sh, g, replay::STEP_ID + 2);
    print("on from the start: ", shown(sh));
    drive::idle(sh, g, tick());
    print("  once played: ", shown(sh));
    press(sh, g, replay::STEP_ID + 3);
    print("to the end: ", shown(sh));
    press(sh, g, replay::STEP_ID + 3);
    print("  again: ", shown(sh));
    // A move in the list: the list keeps the move shown in view, so move 75 is there.
    press(sh, g, replay::MOVE_ID + 74);
    print("move 75 tapped: ", shown(sh));
    drive::key(sh, g, gui::STEP_LEFT, false, tick());
    print("Left: ", shown(sh));
    drive::key(sh, g, gui::STEP_RIGHT, false, tick());
    print("Right: ", shown(sh));
    drive::idle(sh, g, tick());
    // Tab to the list (the steps' group first): the move the focus comes to shows; Down a move on; Left back one,
    // the focus following.
    drive::key(sh, g, gui::STEP_NONE, false, tick());
    var tabs = 0;
    while tabs < 4 && !(g.focus >= replay::MOVE_ID) {
        tab(sh, g);
        tabs++;
    }
    drive::idle(sh, g, tick());
    print("Tab ", tabs, " times: focus on move ", g.focus - replay::MOVE_ID + 1, ", ", shown(sh));
    drive::key(sh, g, gui::STEP_DOWN, false, tick());
    drive::idle(sh, g, tick());
    print("Down: focus on move ", g.focus - replay::MOVE_ID + 1, ", ", shown(sh));
    drive::key(sh, g, gui::STEP_LEFT, false, tick());
    drive::idle(sh, g, tick());
    print("Left: focus on move ", g.focus - replay::MOVE_ID + 1, ", ", shown(sh));

    // The best moves read from the history: one for each move but the forced, which have
    // none even where the line names one.
    var bests = 0;
    var forced = 0;
    var both = 0;
    var forced_at = -1;
    var free_at = -1;
    var widest = -1;
    for p, i in sh.past.replay.plies {
        if p.has_best { bests++; }
        if p.only { forced++; }
        if p.only && p.has_best { both++; }
        if p.only && forced_at < 0 && i > 0 { forced_at = i; }
        // A move with a best move whose next has one too, for the bulb kept through a step.
        let next = i + 1 < sh.past.replay.plies.len && sh.past.replay.plies[i + 1].has_best && !sh.past.replay.plies[i + 1].only;
        if !p.only && p.has_best && next && free_at < 0 && i > 10 { free_at = i; }
        if p.move.captured != 0 && (widest < 0 || p.move.path.len > sh.past.replay.plies[widest].move.path.len) { widest = i; }
    }
    print("the best moves read: ", bests, " of ", sh.past.replay.plies.len, ", ", forced, " forced, ", both, " of them with one");
    // The bulb, a fifth step tile on the tablet: the best move from the position shown on
    // the board as the hint, kept through the steps, none where the move is forced.
    replay::go(sh.past.replay, free_at, 0.0);
    drive::idle(sh, g, tick());
    print("at move ", free_at, ": ", hint(sh));
    press(sh, g, replay::BULB_ID);
    drive::idle(sh, g, tick());
    print("the bulb: on ", sh.past.replay.best, ", ", hint(sh), "; numbered ", numbered(sh));
    press(sh, g, replay::STEP_ID + 2);
    drive::idle(sh, g, tick());
    drive::idle(sh, g, tick());
    print("on: ", shown(sh), ", the best move on ", sh.past.replay.best, ", a best move here ", replay::has_best(sh.past.replay),
          ", ", hint(sh));
    if forced_at >= 0 {
        replay::go(sh.past.replay, forced_at, 0.0);
        drive::idle(sh, g, tick());
        print("at move ", forced_at, ", forced: ", hint(sh), "; the bulb still on ", sh.past.replay.best);
        press(sh, g, replay::BULB_ID);
        drive::idle(sh, g, tick());
        print("  the bulb there, dimmed, changes nothing: on ", sh.past.replay.best);
    }
    replay::go(sh.past.replay, free_at, 0.0);
    drive::idle(sh, g, tick());
    press(sh, g, replay::BULB_ID);
    drive::idle(sh, g, tick());
    print("the bulb again: on ", sh.past.replay.best, ", ", hint(sh));

    // The line saying what was best after a marked move, tapped: the position it was best
    // in, that move on the board.
    var marked = -1;
    for p, i in sh.past.replay.plies {
        let m = p.mark;
        let other = p.best.from != p.move.from || p.best.to != p.move.to;
        if marked < 0 && i > 10 && p.has_best && other && (m == ai::INACCURACY || m == ai::MISTAKE || m == ai::BLUNDER) { marked = i; }
    }
    replay::go(sh.past.replay, marked + 1, 0.0);
    drive::idle(sh, g, tick());
    let was = sh.past.replay.was;
    print("move ", marked + 1, ", marked ", sh.past.replay.plies[marked].mark, ": the line saying what was best a tap ", was.z > 0.0);
    drive::tap(sh, g, drive::middle(was), tick());
    drive::idle(sh, g, tick());
    print("  tapped: ", shown(sh), ", the best move on ", sh.past.replay.best, ", ", hint(sh), ", the one that was best ",
          sh.past.replay.b.glow == sh.past.replay.plies[marked].best.from && sh.past.replay.b.hint_to == sh.past.replay.plies[marked].best.to);
    press(sh, g, replay::BULB_ID);
    drive::idle(sh, g, tick());

    // The move shown's marks: once its piece has arrived, fading in over 0.25 s, drawn
    // while they fade; at once after a jump.
    replay::go(sh.past.replay, free_at, 0.0);
    drive::idle(sh, g, tick());
    print("a jump: its marks ", replay::revealed(sh.past.replay, now));
    press(sh, g, replay::STEP_ID + 2);
    let arrives = sh.past.replay.rest_at;
    print("on: its marks ", replay::revealed(sh.past.replay, now), " while the piece moves");
    board::update(sh.past.replay.b, arrives + 0.001);
    print("  as it arrives ", replay::revealed(sh.past.replay, arrives), ", 0.125 s on ",
          replay::revealed(sh.past.replay, arrives + 0.125), ", 0.25 s on ", replay::revealed(sh.past.replay, arrives + 0.25),
          "; drawn while they fade ", replay::animating(sh.past.replay, arrives + 0.1), ", after ",
          replay::animating(sh.past.replay, arrives + 0.3));
    drive::idle(sh, g, tick());
    print("  ", dots(sh));
    // A capture's way: its stops' dots and numbers.
    replay::go(sh.past.replay, widest + 1, 0.0);
    drive::idle(sh, g, tick());
    print("the capture of the most stops, move ", widest + 1, ": ", dots(sh));

    // Back: the results as they were, then the Russian game, its captures' stops left out.
    press(sh, g, replay::BACK_ID);
    drive::idle(sh, g, tick());
    print("back: screen ", sh.screen, ", showing ", rules::VARIANT_NAMES[sh.past.variant], ", ", sh.past.games.len, " games");
    drive::tap(sh, g, drive::tile(g, 3), tick());
    press(sh, g, results::ROW_ID);
    drive::idle(sh, g, tick());
    print("Russian's row: ", rules::VARIANT_NAMES[sh.past.replay.game.variant], ", ", shown(sh));
    // Escape or Android's back goes to the results too.
    shell::back(sh, tick());
    drive::idle(sh, g, tick());
    print("back: screen ", sh.screen);

    // Nothing written or changed.
    var after: u8[>..] = [];
    read_file(path, after);
    print("the history file as it was: ", after == text, "; the ratings as they were: ", same(sh.prefs.rating, rating),
          "; the game in progress as it was: ", shell::save(sh) == saved);

    // The layouts: the tablet, the phones at 540 and 480 dp with the Pixel 7a's insets,
    // a foldable, 4:3, and the smallest iPad window.
    let sizes = [
        Size { name: "tablet landscape", size: float2 { 1280.0, 800.0 }, dp: 800.0, insets: float4 { 0.0, 0.0, 0.0, 0.0 } },
        Size { name: "tablet portrait", size: float2 { 800.0, 1280.0 }, dp: 800.0, insets: float4 { 0.0, 0.0, 0.0, 0.0 } },
        Size { name: "tablet landscape, its bar", size: float2 { 1920.0, 1200.0 }, dp: 800.0, insets: float4 { 0.0, 0.0, 0.0, 72.0 } },
        Size { name: "a 20:9 phone landscape at 540 dp, cutout left", size: float2 { 2400.0, 1080.0 }, dp: 540.0,
               insets: float4 { 118.0, 0.0, 0.0, 84.0 } },
        Size { name: "a 20:9 phone landscape at 480 dp, cutout right", size: float2 { 2400.0, 1080.0 }, dp: 480.0,
               insets: float4 { 0.0, 0.0, 118.0, 84.0 } },
        Size { name: "a 20:9 phone portrait at 540 dp", size: float2 { 1080.0, 2400.0 }, dp: 540.0,
               insets: float4 { 0.0, 118.0, 0.0, 84.0 } },
        Size { name: "a 20:9 phone portrait at 480 dp", size: float2 { 1080.0, 2400.0 }, dp: 480.0,
               insets: float4 { 0.0, 118.0, 0.0, 84.0 } },
        Size { name: "a 9:16 phone landscape at 480 dp", size: float2 { 1920.0, 1080.0 }, dp: 480.0,
               insets: float4 { 118.0, 0.0, 0.0, 84.0 } },
        Size { name: "a 9:16 phone portrait at 480 dp", size: float2 { 1080.0, 1920.0 }, dp: 480.0,
               insets: float4 { 0.0, 118.0, 0.0, 84.0 } },
        Size { name: "the iPhone 13 mini landscape", size: float2 { 2436.0, 1125.0 }, dp: 500.0,
               insets: float4 { 150.0, 0.0, 150.0, 67.5 } },
        Size { name: "the iPhone 13 mini portrait", size: float2 { 1125.0, 2436.0 }, dp: 500.0,
               insets: float4 { 0.0, 150.0, 0.0, 102.0 } },
        Size { name: "a foldable landscape", size: float2 { 2208.0, 1768.0 }, dp: 800.0, insets: float4 { 0.0, 0.0, 0.0, 0.0 } },
        Size { name: "a foldable portrait", size: float2 { 1768.0, 2208.0 }, dp: 800.0, insets: float4 { 0.0, 0.0, 0.0, 0.0 } },
        Size { name: "4:3 landscape", size: float2 { 2048.0, 1536.0 }, dp: 800.0, insets: float4 { 0.0, 0.0, 0.0, 0.0 } },
        Size { name: "4:3 portrait", size: float2 { 1536.0, 2048.0 }, dp: 800.0, insets: float4 { 0.0, 0.0, 0.0, 0.0 } },
    ];
    press(sh, g, results::ROW_ID);
    for lang in [strings::EN, strings::ET] {
        strings::use(lang);
        print(strings::LANGUAGES[lang], ":");
        for s in sizes {
            drive::size = s.size;
            gui::short_dp = s.dp;
            g.scale = gui::scale_of(s.size.x, s.size.y);
            g.insets = s.insets;
            gui::test_faces(g);
            replay::go(sh.past.replay, 31, 0.0);
            drive::idle(sh, g, tick());
            drive::idle(sh, g, tick());
            print("  ", s.name, ": ", check(g, sh, gui::safe(g, s.size.x, s.size.y)));
        }
    }
    g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
    gui::short_dp = 800.0;

    // A desktop's windows (a display scale of 1): 1280 × 800 and a 27" screen's full
    // window, both large (gui::large), the column at most LARGE_COL dp, the steps, the
    // board, and the column centered as one, the words half again as large; and an
    // ultrawide's full window, capped at gui::WIDEST times its height.
    strings::use(strings::EN);
    gui::desktop_scale = 1.0;
    for d in [float2 { 1280.0, 800.0 }, float2 { 2560.0, 1440.0 }, float2 { 3440.0, 1440.0 }] {
        drive::size = d;
        g.scale = gui::scale_of(d.x, d.y);
        gui::test_faces(g);
        replay::go(sh.past.replay, 31, 0.0);
        drive::idle(sh, g, tick());
        drive::idle(sh, g, tick());
        let safe = gui::safe(g, d.x, d.y);
        let big = gui::large(safe, g.scale);
        let o = replay::layout(safe, g.scale, big);
        let e = replay::EDGE * g.scale;
        let left = o.steps[0].x - safe.x - e;
        let right = safe.x + safe.z - e - (o.glass.x + o.glass.z);
        // Back at the top left, over the board's left edge and above the line over it; the
        // board's top level with the glass's; play from here at the column's head.
        let back = spot(g, replay::BACK_ID);
        let play = spot(g, replay::PLAY_ID);
        let b = sh.out.layout.board;
        let note = sh.past.replay.note;
        let top_left = abs(back.x - b.x) < 0.5 && back.y + back.w <= note.y + 0.5 && back.x + back.z <= b.x + b.z;
        print("  a desktop's ", d.x as i64, " x ", d.y as i64, ": ", check(g, sh, safe), "; large ", big, ", words ",
              sh.past.replay.k, " times, the column ", (o.glass.z / g.scale + 0.5) as i64, " dp, centered ",
              abs(left - right) < 1.0, "; back at the top left over the board ", top_left, ", the board's and glass's tops level ",
              abs(b.y - o.glass.y) < 0.5, ", play from here at the column's head ", play.x >= o.glass.x - 0.5 && play.y < b.y);
    }
    gui::desktop_scale = 0.0;
}
