// The hint on the game screen (game::press_hint, docs/product.md): a tile beside undo
// move with a pip for each of a game's three hints. The first press asks for a move (the
// app's worker gives the move judging finds best, at full strength; this test answers at once with ai::hint, as the worker would); the answer
// spends a pip and lights the piece to move with the puzzles' pulsing ring, the tile
// asking Where to?; the second press shows a light ghost of the piece on its square, for
// nothing more; the move ends it. Undo before the answer drops the ask, and an answer
// that comes after is ignored. With no hint left, while a capture is due, or on the
// computer's turn the tile takes no press. Against a friend each side has its own three.
// The ring pulses as the puzzles' does, then holds still, so nothing animates after.
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
import check from "../";

let HINT = 4;               // the hint's tile among the controls, after undo move

fn state(gm: game::Game&, g: gui::Gui&, what: const u8[:]) {
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    var t: u8[>..] = [];
    if gm.hint_stage > 0 { rules::format_move(t, b.variant, gm.hint_move); } else { t.append("-"); }
    print(what, ": stage ", gm.hint_stage, ", asking ", gm.hinting != 0, ", left ", gm.hints[0], " ", gm.hints[1],
          ", move ", t, ", glow ", drive::name(v, b.glow), ", ghost ", drive::name(v, b.hint_to), ", tile ",
          tile(g));
}

// The hint's tile as declared: lit (chosen), plain, or dim (taking no press).
fn tile(g: gui::Gui&) -> u8[>..] {
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.extra.y < gui::CLOCK_RUN else { continue; }
        if k == HINT {
            return str(if q.extra.y == gui::CHOSEN { "lit" } else if q.color.w < 0.5 { "dim" } else { "plain" });
        }
        k++;
    }
    return str("none");
}

// Answers the game's open hint ask at once, as the worker would.
fn answer(gm: game::Game&, e: ai::Engine&) {
    let ask = game::ask_for(gm);
    guard ask.id != 0 && ask.kind == game::HINT else { return; }
    let m = ai::hint(e, ask.past, ask.pos);
    var t: u8[>..] = [];
    rules::format_move(t, gm.b.variant, m);
    print("  answered ", t);
    game::hinted(gm, ask.id, m);
}

// A reply that leaves the other side no capture, so its next hint can be asked; the
// first move where every one does.
fn quiet_reply(p: rules::Position, moves: rules::Moves&) -> rules::Move {
    var next: rules::Moves = [];
    for &m in moves {
        rules::generate(rules::play(p, m), next);
        if next.len == 0 || next[0].captured == 0 { return m; }
    }
    return moves[0];
}

fn start(gm: game::Game&, fen: const u8[:], computer: i64, skill: i64) {
    game::start(gm, rules::RUSSIAN, clock::NONE, computer, game::EASY, skill, 1);
    board::set(gm.b, check::position(rules::RUSSIAN, fen));
    gm.turn = gm.b.pos.side;
}

fn main() {
    strings::use(strings::EN);
    let l = panel::layout(1280.0, 800.0, 8);
    var g = gui::Gui {};
    gui::test_faces(g);
    var e = ai::Engine { .. };
    ai::init(e);
    var gm = game::new(rules::RUSSIAN);
    let calm = "W:Wa1,c1,e1,g1,b2,d2,h2,a3,e3,g3,d4:Bb8,d8,f8,h8,a7,c7,e7,g7,b6,f6,e5,h4";
    start(gm, calm, rules::BLACK, 0);
    drive::idle(gm, g, l, 1.0);
    state(gm, g, "calm");
    let at = drive::control(g, HINT);
    drive::tap(gm, g, l, at, 1.1);
    state(gm, g, "pressed");
    answer(gm, e);
    drive::idle(gm, g, l, 1.2);
    state(gm, g, "answered");
    drive::idle(gm, g, l, 2.0);
    let pulsing = game::animating(gm, g, 2.0);
    drive::idle(gm, g, l, 4.9);
    print("  animating while it pulses ", pulsing, ", at 4.9 s ", game::animating(gm, g, 4.9));
    drive::tap(gm, g, l, at, 5.0);
    state(gm, g, "pressed again");
    drive::tap(gm, g, l, at, 5.5);
    state(gm, g, "and again");
    drive::idle(gm, g, l, 9.0);
    print("  still at 9 s: animating ", game::animating(gm, g, 9.0));
    let m = gm.hint_move;
    let v .= rules::VARIANTS[gm.b.variant];
    drive::tap(gm, g, l, board::center(l.board, v, m.from), 10.0);
    drive::tap(gm, g, l, board::center(l.board, v, m.to), 10.1);
    drive::idle(gm, g, l, 10.2);
    state(gm, g, "the move played");

    // A move made before the answer drops the ask; the answer after is ignored.
    start(gm, calm, rules::BLACK, 40);
    drive::idle(gm, g, l, 20.0);
    drive::tap(gm, g, l, drive::control(g, HINT), 20.1);
    let late = game::ask_for(gm);
    drive::tap(gm, g, l, drive::at(l.board, "d2"), 20.3);
    drive::tap(gm, g, l, drive::at(l.board, "c3"), 20.4);
    drive::idle(gm, g, l, 21.0);
    game::hinted(gm, late.id, ai::hint(e, late.past, late.pos));
    drive::idle(gm, g, l, 21.1);
    state(gm, g, "a move made before the answer");

    // A friend's game: white takes three hints, each played, black none and replying
    // quietly; then white's tile is dim and black's still has three.
    let opening = "W:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,c3,e3,g3:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8";
    start(gm, opening, -1, 0);
    gm.look_skill = 25;
    var t = 30.0;
    for i in 3 {
        drive::idle(gm, g, l, t);
        drive::tap(gm, g, l, drive::control(g, HINT), t + 0.1);
        answer(gm, e);
        drive::idle(gm, g, l, t + 0.2);
        let h = gm.hint_move;
        drive::tap(gm, g, l, board::center(l.board, v, h.from), t + 0.3);
        drive::tap(gm, g, l, board::center(l.board, v, h.to), t + 0.4);
        drive::idle(gm, g, l, t + 1.0);
        let r = quiet_reply(gm.b.pos, gm.b.moves);
        drive::tap(gm, g, l, board::center(l.board, v, r.from), t + 1.1);
        drive::tap(gm, g, l, board::center(l.board, v, r.path[1]), t + 1.2);
        drive::idle(gm, g, l, t + 2.0);
        t += 3.0;
    }
    state(gm, g, "white's three spent, white to move");
    drive::tap(gm, g, l, drive::control(g, HINT), t);
    state(gm, g, "pressed with none left");

    // A capture due: no hint; a friend's game: each side's own.
    start(gm, "W:Wa1,c3:Bd4,h8", rules::BLACK, 0);
    drive::idle(gm, g, l, 40.0);
    drive::tap(gm, g, l, drive::control(g, HINT), 40.1);
    state(gm, g, "a capture due");
    start(gm, "B:Wa1,c1,e1,g1,b2,d2,f2,h2,a3,e3,g3,d4:Bb6,d6,f6,h6,a7,c7,e7,g7,b8,d8,f8,h8", -1, 0);
    gm.look_skill = 25;
    gm.hints[0] = 0;
    drive::idle(gm, g, l, 50.0);
    drive::tap(gm, g, l, drive::control(g, HINT), 50.1);
    answer(gm, e);
    drive::idle(gm, g, l, 50.2);
    state(gm, g, "a friend's game, black's own hint");

    // The words of undo move and the hint inside their tiles, side by side in the tablet's
    // landscape corner panel, flat and 3D, in both languages: Estonian's undo move ("Võta
    // käik tagasi") goes on two lines in a smaller face where one line has no room.
    for lang in [strings::EN, strings::ET] {
        strings::use(lang);
        for raised in [false, true] {
            let k = if raised { panel::corners_in(float4 { 0.0, 0.0, 1280.0, 800.0 }, 8, 1.0, panel::PITCH_PORTRAIT, true, true) }
                    else { l };
            start(gm, calm, -1, 0);
            drive::idle(gm, g, k, 60.0);
            var past = 0;
            for i in drive::tiles(g) {
                let r = drive::rect(g, i);
                for q in g.quads {
                    guard q.look.x == gui::TEXT && overlaps(q.rect, r) else { continue; }
                    if q.rect.x < r.x || q.rect.x + q.rect.z > r.x + r.z || q.rect.y < r.y || q.rect.y + q.rect.w > r.y + r.w { past++; }
                }
            }
            print(strings::LANGUAGES[lang], if raised { ", 3D" } else { ", flat" }, ": undo move ",
                  whole(drive::control(g, HINT - 1).x), ", the hint ", whole(drive::control(g, HINT).x),
                  ", glyphs past their tile ", past);
        }
        // The iPad's smallest window (compact, 499 x 645 dp): whose turn's words clear of
        // the eye and the tiles, the tiles icons alone where their words would leave it
        // too little room (Estonian's undo move).
        g.scale = 1.5;
        gui::test_faces(g);
        let k = panel::layout_in(float4 { 0.0, 0.0, 748.0, 968.0 }, 8, 1.5, true, true);
        start(gm, calm, -1, 0);
        drive::idle(gm, g, k, 70.0);
        var eye = float4 { 0.0, 0.0, 0.0, 0.0 };
        for q in g.quads { if q.look.x == gui::FLOAT { eye = q.rect; } }
        var on = 0;
        for q in g.quads {
            guard q.look.x == gui::TEXT else { continue; }
            if overlaps(q.rect, eye) { on++; }
            for i in drive::tiles(g) {
                let r = drive::rect(g, i);
                if overlaps(q.rect, r) && (q.rect.x < r.x || q.rect.x + q.rect.z > r.x + r.z) { on++; }
            }
        }
        print(strings::LANGUAGES[lang], ", the smallest window: undo move ", whole(drive::rect(g, HINT - 1).z / 1.5),
              " dp across, glyphs on the eye or past a tile ", on);
        g.scale = 1.0;
        gui::test_faces(g);
    }
}

fn whole(x: f32) -> i64 { floor(x + 0.5) as i64 }

fn overlaps(a: float4, b: float4) -> bool { a.x < b.x + b.z && b.x < a.x + a.z && a.y < b.y + b.w && b.y < a.y + a.w }
