// A past game's replay (shell/replay.goose, task 078's C): a game's row on the results
// screen opens it at the game's end; the steps go to the start, back, on (the move played
// on the board), and to the end; a move tapped in the list jumps there; Left and Right
// step from anywhere, the keys' focus on a move shows it and follows the steps; back
// goes to the results as they were left. A capture written with its stops left out
// (from and to alone) still replays. Nothing of it reaches the game in progress (its
// saved image the same on the replay as before), the history file, or the ratings. Then
// the layouts at the sizes test/shell/sizes uses: every tile at least a tap, inside the
// safe area and apart, the board clear of them, and the frame's quads under
// gui::MAX_QUADS.
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
    let r .= sh.replay;
    let b .= r.b;
    let right = rules::same(b.pos, r.pos[r.ply]);
    var s = str("move ", r.ply, " of ", r.plies.len, ", the board ", if right { "right" } else { "WRONG" });
    if b.moving { s.append(", moving"); }
    if b.has_last { format(s, ", last ", drive::name(rules::VARIANTS[b.variant], b.last.from), "-",
                           drive::name(rules::VARIANTS[b.variant], b.last.to)); }
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
    let rows = floor(10.0 * sh.replay.rows + 0.5) / 10.0;
    return str(n, " tiles, smallest ", (least + 0.5) as i64, " dp, inside ", inside, ", apart ", apart, ", off the board ",
               off_board, "; board ", (b.z / g.scale + 0.5) as i64, " dp, inside ", board_in, "; ", moves,
               " moves listed, ", rows, " rows in view; quads ", g.quads.len);
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
    print("results: screen ", sh.screen, ", ", sh.games.len, " games");

    // The first row, the newest game: its replay, at its end.
    press(sh, g, results::ROW_ID);
    drive::idle(sh, g, tick());
    print("its row tapped: screen ", sh.screen, " (replay ", shell::REPLAY, "), ", rules::VARIANT_NAMES[sh.replay.game.variant],
          ", ", shown(sh));
    let image = shell::save(sh);
    print("  the saved image on the replay is the one before: ", image == saved, ", screen kept as home");
    for name, k in ["the start", "back", "on", "the end"] {
        // Each step from the middle of the game.
        replay::go(sh.replay, 45, 0.0);
        press(sh, g, replay::STEP_ID + k);
        print(name, ": ", shown(sh));
        drive::idle(sh, g, tick());
    }
    replay::go(sh.replay, 0, 0.0);
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

    // Why a game from here doesn't count: the info sign's tap opens its card; the next tap,
    // on a step, only closes it; Tab to the sign and Enter opens it, Enter again closes
    // it; opened again, back closes it and stays on the replay.
    drive::idle(sh, g, tick());
    let at = sh.replay.ply;
    press(sh, g, replay::INFO_ID);
    drive::idle(sh, g, tick());
    print("the sign tapped: card open ", sh.replay.why, ", inside the safe area ", within(sh.replay.card, gui::safe(g, drive::size.x, drive::size.y)));
    press(sh, g, replay::STEP_ID);
    drive::idle(sh, g, tick());
    print("a step tapped: card open ", sh.replay.why, ", the move shown kept ", sh.replay.ply == at);
    drive::key(sh, g, gui::STEP_NONE, false, tick());
    tabs = 0;
    while tabs < 5 && g.focus != replay::INFO_ID {
        tab(sh, g);
        tabs++;
    }
    drive::idle(sh, g, tick());
    print("Tab ", tabs, " times: focus on the sign ", g.focus == replay::INFO_ID);
    drive::key(sh, g, gui::STEP_NONE, true, tick());
    drive::idle(sh, g, tick());
    print("Enter: card open ", sh.replay.why);
    drive::key(sh, g, gui::STEP_NONE, true, tick());
    drive::idle(sh, g, tick());
    print("Enter again: card open ", sh.replay.why);
    drive::key(sh, g, gui::STEP_NONE, true, tick());
    drive::idle(sh, g, tick());
    shell::back(sh, tick());
    drive::idle(sh, g, tick());
    print("Enter, then back: card open ", sh.replay.why, ", screen ", sh.screen, " (replay ", shell::REPLAY, ")");

    // Back: the results as they were, then the Russian game, its captures' stops left out.
    press(sh, g, replay::BACK_ID);
    drive::idle(sh, g, tick());
    print("back: screen ", sh.screen, ", showing ", rules::VARIANT_NAMES[sh.results_variant], ", ", sh.games.len, " games");
    drive::tap(sh, g, drive::tile(g, 3), tick());
    press(sh, g, results::ROW_ID);
    drive::idle(sh, g, tick());
    print("Russian's row: ", rules::VARIANT_NAMES[sh.replay.game.variant], ", ", shown(sh));
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
            replay::go(sh.replay, 31, 0.0);
            drive::idle(sh, g, tick());
            drive::idle(sh, g, tick());
            print("  ", s.name, ": ", check(g, sh, gui::safe(g, s.size.x, s.size.y)));
        }
    }
    g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
    gui::short_dp = 800.0;
}
