// A draw on the game screen (game::drawn, game::settle; prototypes/draw.html, take a),
// headless. Russian king against king: 6.1.8.6 draws on the 10th ply. Each ply is
// tapped as a child plays it, and after it has shown the play panel's countdown is
// printed: from 5 moves left, its dots lit as many. The drawing move shows, then the
// game is drawn: the clock stops, the board dims over 0.6 s, the card slides up as it
// fades in from 0.1 s and is still from 0.8 s, and from then the game asks for no frames.
// Undo from the draw takes it back to the countdown, and the drawing move again draws.
// Against the computer a draw counts once, as 0. A saved game brings back its counts
// (shell::save keeps the undo history they are folded over). A move that repeats a
// position counts twice, then three times draws.
import std;
import vec;
import math;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn r2(x: f64) -> f64 { floor(x * 100.0 + 0.5) / 100.0 }

// The play panel's countdown, as game::frame gives it.
fn note(gm: game::Game&) -> u8[>..] {
    var n = panel::Note {};
    game::countdown(gm, n);
    guard n.of > 0 else { return str("no countdown"); }
    var s = str(n.line[..n.line.len], ", dots ", n.lit, " of ", n.of);
    if n.more { s.append(", and: "); s.append(strings::get(strings::COUNT_THIRD)); }
    format(s, ", short ", n.word[..n.word.len], " ", n.fig[..n.fig.len]);
    return s;
}

// Plays `a`-`b` by taps and lets it show; returns the time after.
fn play(gm: game::Game&, g: gui::Gui&, l: panel::Layout, a: const u8[:], b: const u8[:], now: f64) -> f64 {
    drive::tap(gm, g, l, drive::at(l.board, a), now);
    drive::tap(gm, g, l, drive::at(l.board, b), now + 0.1);
    var t = now + 0.2;
    while gm.b.moving || t < now + 1.0 {
        drive::idle(gm, g, l, t);
        t += 1.0 / 60.0;
    }
    return t;
}

// The draw's card: its tiles beyond the panels' and their opacity, and the pieces on it.
fn card(g: gui::Gui&) -> u8[>..] {
    var s: u8[>..] = [];
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.extra.y < gui::CLOCK_RUN else { continue; }
        k++;
        if k > 4 { format(s, "tile at y ", r2(q.rect.y), " opacity ", r2(1.0 - q.extra.w), "; "); }
    }
    var on = 0;
    for p in drive::over { if p.win.w > 0.5 { on++; } }
    format(s, "pieces on it ", on);
    return s;
}

let LINE = ["c1", "a3", "f8", "g7", "a3", "b4", "g7", "a1", "b4", "a3", "a1", "c3", "a3", "c1", "c3", "a1", "c1", "d2"];

fn start(gm: game::Game&, fen: const u8[:], kind: i64) {
    let p, ok = rules::parse_fen(fen, rules::RUSSIAN);
    assert(ok);
    game::start(gm, rules::RUSSIAN, kind, -1, game::MEDIUM, 40, 0);
    board::set(gm.b, p);
    gm.turn = gm.b.pos.side;
}

fn main() {
    strings::use(strings::EN);
    let l = panel::layout(1280.0, 800.0, 8);
    var g = gui::Gui {};
    gui::test_faces(g);
    var gm = game::new(rules::RUSSIAN);
    start(gm, "W:WKc1:BKf8", clock::BLITZ);

    var t = 0.0;
    for i in 9 {
        t = play(gm, g, l, LINE[2 * i], LINE[2 * i + 1], t);
        print("ply ", i + 1, " ", LINE[2 * i], "-", LINE[2 * i + 1], ": ", note(gm), "; drawn ", game::drawn(gm));
    }
    // The 10th, a1-b2.
    drive::tap(gm, g, l, drive::at(l.board, "a1"), t);
    drive::tap(gm, g, l, drive::at(l.board, "b2"), t + 0.1);
    print("a1-b2 showing: drawn ", game::drawn(gm), ", ", note(gm));
    t += 0.2;
    while gm.drawn_at < 0.0 {
        drive::idle(gm, g, l, t);
        t += 1.0 / 60.0;
    }
    let d = gm.drawn_at;
    var why: u8[..64] = [];
    game::reason(gm, game::drawn(gm), why);
    print("drawn: ", why[..why.len], "; the clock runs for ", gm.clock.running);
    for k in [0.05, 0.3, 0.6, 1.0] {
        drive::idle(gm, g, l, d + k);
        board::fill(gm.b, l.board, d + k);
        game::cheer(gm, l.board, d + k);
        print("  at ", k, " s: board dim ", r2(gm.b.dim), ", piece dim ", r2(gm.b.pieces[0].win.x), "; card: ", card(g));
    }
    var n = 0;
    var last = -1.0;
    var u = d;
    while u < d + 5.0 {
        gui::begin(g, gui::Input { at: drive::AWAY, .. }, l.board.scale, u);
        let go, changed = game::frame(gm, g, l, u, drive::over);
        if changed || game::animating(gm, g, u) {
            n++;
            last = u;
        }
        u += 1.0 / 60.0;
    }
    print("frames over 5 s: ", n, ", the last at ", r2(last - d), " s");

    // Undo move from the draw: the countdown again; the move again draws.
    t = d + 6.0;
    drive::tap(gm, g, l, drive::control(g, 3), t);
    drive::idle(gm, g, l, t + 0.5);
    print("undone: drawn ", game::drawn(gm), ", ", note(gm), ", card gone ", gm.drawn_at < 0.0);
    t = play(gm, g, l, "a1", "b2", t + 1.0);
    print("again: drawn ", game::drawn(gm));

    // Against the computer (white), black's drawing move counts the game as 0, once,
    // and the computer is asked for nothing more.
    start(gm, "W:WKc1:BKf8", clock::NONE);
    t = 100.0;
    for i in 9 { t = play(gm, g, l, LINE[2 * i], LINE[2 * i + 1], t); }
    gm.computer = rules::WHITE;
    print("against the computer, before the drawing move: counted ", gm.counted);
    t = play(gm, g, l, "a1", "b2", t);
    print("  drawn ", game::drawn(gm), ", counted ", gm.counted, ", result ", gm.result, "; asks the computer ",
          game::computer_to_move(gm));

    // A saved game: 9 plies in, saved and brought back, the countdown as it was.
    var sh = shell::new(rules::RUSSIAN);
    start(sh.game, "W:WKc1:BKf8", clock::NONE);
    t = 200.0;
    for i in 9 { t = play(sh.game, g, l, LINE[2 * i], LINE[2 * i + 1], t); }
    var back = shell::new(rules::INTERNATIONAL);
    print("saved, brought back ", shell::restore(back, shell::save(sh)), ": ", note(back.game));

    // Repetition, not in a row: four kings each; the start again after 4 plies, then a
    // different way round to it after 8.
    start(gm, "W:WKa1,Kc1,Ke1,Kg1:BKb8,Kd8,Kf8,Kh8", clock::NONE);
    let round = ["c1", "d2", "d8", "c7", "d2", "c1", "c7", "d8", "e1", "f2", "f8", "e7", "f2", "e1", "e7", "f8"];
    t = 300.0;
    for i in 8 {
        t = play(gm, g, l, round[2 * i], round[2 * i + 1], t);
        print("ply ", i + 1, ": ", note(gm), "; drawn ", game::drawn(gm));
    }

    // The short form with the clocks where the line has no room: a portrait panel, the
    // clocks narrowing for it, and the 3D corner panel, its line between them and undo
    // move shorter. The tiles, in dp (the play panel's clocks and undo move).
    shape(g, "portrait", panel::layout(800.0, 1280.0, 8), true);
    shape(g, "portrait, no countdown", panel::layout(800.0, 1280.0, 8), false);
    shape(g, "corner", panel::corners_in(float4 { 0.0, 0.0, 1280.0, 800.0 }, 8, 1.0), true);
    shape(g, "corner, no countdown", panel::corners_in(float4 { 0.0, 0.0, 1280.0, 800.0 }, 8, 1.0), false);
}

// The play panel with clocks at layout l: the clocks' and undo move's tiles.
fn shape(g: gui::Gui&, name: const u8[:], l: panel::Layout, counting: bool) {
    var c = clock::new(clock::BLITZ);
    var n = panel::Note {};
    if counting {
        n.of = 5;
        n.lit = 3;
        n.word.append("Draw in");
        n.fig.push('3');
    }
    gui::begin(g, gui::Input { at: drive::AWAY, .. }, l.board.scale, 0.0);
    drive::over.clear();
    panel::game(g, l, c, 0, false, false, n, false, 1.0, drive::over);
    var s: u8[>..] = [];
    format(s, name, ":");
    for q in g.quads {
        guard q.look.x == gui::BUTTON else { continue; }
        guard q.rect.y >= l.right.y - 1.0 && q.rect.x >= l.right.x - 1.0 else { continue; }
        format(s, " [", r2(q.rect.x), " ", r2(q.rect.y), " ", r2(q.rect.z), " ", r2(q.rect.w), "]");
    }
    print(s);
}
