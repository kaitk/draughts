// Several captures of one piece each, black to move against the computer on the turned
// International board (task 048: a report that a king was made to take where it was
// taken back). A king's capture may land on any free square beyond the piece it takes,
// and a man's capture is as good when both take one, so each is the player's to choose.
// Each capture the rules allow, every landing of the king's, is played here through the
// game screen by a tap on the piece and a tap on the square, and by a drag, with hints on
// mistakes only and on all moves; each is the one chosen, and white's captures after it
// show which landings lose the king. Nothing plays without the player choosing: a tap on
// a piece only selects it, a landing tapped with nothing selected or with the man
// selected moves nothing, and a square no capture ends on is a mistake, after which
// every capture can still be played.
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

let V = rules::INTERNATIONAL;

// The center of square n (FEN numbering) on the screen.
fn at(l: panel::Layout, n: i64) -> float2 {
    let v .= rules::VARIANTS[V];
    return board::center(l.board, v, v.bit_of[n]);
}

fn number(sq: i64) -> i64 {
    let v .= rules::VARIANTS[V];
    for n in 1..rules::squares(V) + 1 { if v.bit_of[n] == sq { return n; } }
    return -1;
}

fn move_text(m: rules::Move) -> u8[>..] {
    var t: u8[>..] = [];
    rules::format_move(t, V, m);
    return t;
}

// A new game against the computer playing white, from `fen` with black to move.
fn begin(gm: game::Game&, g: gui::Gui&, l: panel::Layout, fen: const u8[:], hints: i64, now: f64) {
    game::start(gm, V, clock::NONE, rules::WHITE, game::MEDIUM, 40, 0);
    let p, ok = rules::parse_fen(fen, V);
    assert(ok);
    board::set(gm.b, p);
    gm.turn = gm.b.pos.side;
    gm.b.hints = hints;
    drive::idle(gm, g, l, now);
}

// What was played since the start, if anything, and what white can take after it.
fn played(gm: game::Game&) -> u8[>..] {
    guard gm.b.history.len > 0 else { return str("nothing played"); }
    var white_takes: u8[>..] = [];
    var lost = false;
    for m in gm.b.moves {
        guard m.captured != 0 else { continue; }
        format(white_takes, " ", move_text(m));
        if m.captured & rules::bit(gm.b.last.to) != 0 { lost = true; }
    }
    if white_takes.len == 0 { format(white_takes, " none"); }
    return str(move_text(gm.b.move), ", white takes", white_takes, if lost { " (the piece is lost)" } else { "" });
}

// The first empty square no capture ends on.
fn stray(b: board::Board&, opts: rules::Moves&) -> i64 {
    let v .= rules::VARIANTS[V];
    for n in 1..rules::squares(V) + 1 {
        let sq = v.bit_of[n] as i64;
        guard board::empty(b, sq) else { continue; }
        var target = false;
        for m in opts { if m.to == sq { target = true; } }
        if !target { return n; }
    }
    return -1;
}

fn same(a: rules::Move, b: rules::Move) -> bool { a.from == b.from && a.to == b.to && a.captured == b.captured }

// A press at p, a drag to q over a few frames, and a release there.
fn drag(gm: game::Game&, g: gui::Gui&, l: panel::Layout, p: float2, q: float2, now: f64) {
    drive::frame(gm, g, l, p, true, true, false, now);
    for k in 1..5 {
        let f = (k as f32) / 4.0;
        drive::frame(gm, g, l, p + (q - p) * f, true, false, false, now + 0.02 * k);
    }
    drive::frame(gm, g, l, q, false, false, true, now + 0.12);
}

fn position(gm: game::Game&, g: gui::Gui&, l: panel::Layout, fen: const u8[:], what: const u8[:]) {
    print("== ", what, ": ", fen);
    var t = 0.0;
    var fails = 0;
    for hints in [board::MISTAKES, board::MOVES] {
        begin(gm, g, l, fen, hints, t);
        let opts = gm.b.moves;
        if hints == board::MISTAKES {
            var all: u8[>..] = [];
            for m in opts { format(all, " ", move_text(m)); }
            print("captures:", all);
        }
        for m, i in opts {
            for by_drag in [false, true] {
                begin(gm, g, l, fen, hints, t);
                if by_drag {
                    drag(gm, g, l, at(l, number(m.from)), at(l, number(m.to)), t + 0.1);
                } else {
                    drive::tap(gm, g, l, at(l, number(m.from)), t + 0.1);
                    let after_select = gm.b.history.len;
                    drive::tap(gm, g, l, at(l, number(m.to)), t + 0.2);
                    if after_select != 0 {
                        print("  a tap on ", number(m.from), " played ", played(gm));
                        fails++;
                    }
                }
                drive::idle(gm, g, l, t + 3.0);
                let ok = gm.b.history.len == 1 && same(gm.b.move, m);
                if !ok { fails++; }
                if hints == board::MISTAKES && !by_drag || !ok {
                    print("  ", move_text(m), if by_drag { " by a drag" } else { " by taps" }, ": ", played(gm),
                          if ok { "" } else { "  <- not the one chosen" });
                }
                t += 10.0;
            }
        }
        // A landing with nothing selected, a king's landing with the man selected, and a
        // square no capture ends on with the king selected play nothing; every capture can
        // still be chosen after them.
        var king = -1;
        var man = -1;
        for m in opts { if gm.b.pos.kings & rules::bit(m.from) != 0 { king = m.from; } else { man = m.from; } }
        var king_to = -1;
        for m in opts { if m.from == king { king_to = m.to; } }
        for m in opts {
            begin(gm, g, l, fen, hints, t);
            drive::tap(gm, g, l, at(l, number(king_to)), t + 0.1);
            if man >= 0 {
                drive::tap(gm, g, l, at(l, number(man)), t + 0.2);
                drive::tap(gm, g, l, at(l, number(king_to)), t + 1.5);
            }
            drive::tap(gm, g, l, at(l, number(king)), t + 3.0);
            drive::tap(gm, g, l, at(l, stray(gm.b, opts)), t + 3.1);
            let wrong = gm.b.history.len;
            drive::tap(gm, g, l, at(l, number(m.from)), t + 4.5);
            drive::tap(gm, g, l, at(l, number(m.to)), t + 4.6);
            drive::idle(gm, g, l, t + 8.0);
            let ok = wrong == 0 && gm.b.history.len == 1 && same(gm.b.move, m);
            if !ok {
                fails++;
                print("  after the stray taps, ", move_text(m), ": ", played(gm), "  <- not the one chosen");
            }
            t += 10.0;
        }
    }
    print("every capture by taps and by a drag, hints on mistakes and on all moves, each the one chosen: ",
          fails == 0);
}

// The 3D board through the shell: every capture tapped through the perspective, the
// piece's top and then the field, and dragged from the piece's top to the field.
fn raised(g: gui::Gui&, fen: const u8[:]) {
    var t = 0.0;
    var fails = 0;
    var count = 0;
    var sh_raised = false;
    var sh_flip = false;
    for by_drag in [false, true] {
        var sh = shell::new(V);
        sh.prefs.board = settings::RAISED;
        game::start(sh.game, V, clock::NONE, rules::WHITE, game::MEDIUM, 40, 0);
        let p, ok = rules::parse_fen(fen, V);
        assert(ok);
        board::set(sh.game.b, p);
        sh.game.turn = sh.game.b.pos.side;
        sh.screen = shell::GAME;
        sh.drawn = shell::GAME;
        drive::idle(sh, g, t);
        sh_raised = sh.raised;
        sh_flip = sh.layout.flip;
        let opts = sh.game.b.moves;
        for m in opts {
            board::set(sh.game.b, p);
            drive::idle(sh, g, t);
            drive::idle(sh, g, t + 0.05);
            let un = view3d::unit(sh.layout.n);
            let top = sq_screen(sh, m.from, view3d::HEIGHT * un);
            let field = sq_screen(sh, m.to, 0.0);
            if by_drag {
                drive::frame(sh, g, top, true, true, false, t + 0.1);
                for k in 1..5 {
                    let f = (k as f32) / 4.0;
                    drive::frame(sh, g, top + (field - top) * f, true, false, false, t + 0.1 + 0.02 * k);
                }
                drive::frame(sh, g, field, false, false, true, t + 0.22);
            } else {
                drive::tap(sh, g, top, t + 0.1);
                drive::tap(sh, g, field, t + 0.2);
            }
            drive::idle(sh, g, t + 3.0);
            count++;
            if !(sh.game.b.history.len == 1 && same(sh.game.b.move, m)) {
                fails++;
                print("  3D ", move_text(m), if by_drag { " by a drag" } else { " by taps" }, ": ", played(sh.game),
                      "  <- not the one chosen");
            }
            t += 10.0;
        }
    }
    print("the 3D board (raised ", sh_raised, ", turned ", sh_flip, "): ", count, " captures by taps and drags, each the one chosen: ", fails == 0);
}

fn sq_screen(sh: shell::Shell&, sq: i64, h: f32) -> float2 {
    let c = view3d::to_world(sh.layout, board::center(sh.layout, rules::VARIANTS[V], sq));
    let q = view3d::project(sh.view, float3 { c.x, h, c.y });
    return float2 { q.x, q.y };
}

fn main() {
    strings::use(strings::EN);
    var g = gui::Gui {};
    gui::test_faces(g);
    var l = panel::layout(1280.0, 800.0, 10);
    l.board.flip = true;
    var gm = game::new(V);
    // The report's guess: the man on 18 takes 23, or the king on 46 takes it landing on
    // 19, 14, 10, or 5; 44 is white's other piece.
    position(gm, g, l, "B:W23,44:B18,K46", "a king and a man each take one");
    // The king's nearest landing is taken back, the further ones are safe; the man can
    // take either of two.
    position(gm, g, l, "B:W12,23,31:B18,K46", "the king's nearest landing lost");
    // The king takes 41: its furthest landing is taken back.
    position(gm, g, l, "B:W19,23,41:B18,K46", "the king's furthest landing lost");
    drive::size = float2 { 1280.0, 800.0 };
    raised(g, "B:W12,23,31:B18,K46");
    raised(g, "B:W19,23,41:B18,K46");
}
