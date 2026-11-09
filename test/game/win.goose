// A win (game::cheer, game::celebrate; prototypes/win.html, take a), headless. The
// winning piece is the last move's: it lifts with its ring, is drawn last, over the
// others, and stays out of the dim. A ring of glow passes the winner's other pieces
// outward from it, the nearer first, each lifting a little with its ring and its square
// lit as it passes. Then the board dims and the card comes, sliding up as it fades in,
// the crowned piece fading in on it. The celebration is still from 1.7 s, later on
// 10 × 10 when the glow has farther to go, and from then the game asks for no frames:
// one more, at rest, then none. A win with no winning piece to lift (a position set up
// already won) goes straight to the dim and the card. On a turned board the same squares
// answer.
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

// The board at `now` as the app draws it: filled, then the win on it. Each piece by its
// square: lifted by (in radii), grown by, its ring, dimmed by, its square lit; then the
// board's dim and the piece drawn last.
fn board_at(gm: game::Game&, l: board::Layout, now: f64) -> u8[>..] {
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    let r = 0.39 * l.inner.w;
    board::fill(b, l, now);
    game::cheer(gm, l, now);
    var s: u8[>..] = [];
    for p in b.pieces {
        let sq = board::hit(l, v, float2 { p.at.x, p.at.y });
        guard p.at.w > 0.0 || p.ring.y > 0.0 || p.win.y > 0.0 else { continue; }
        format(s, drive::name(v, sq), " up ", r2(p.at.w / r), " x", r2(p.at.z / r), " ring ", r2(p.ring.y), " dim ",
               r2(p.win.x), " lit ", r2(p.win.y), "; ");
    }
    let top .= b.pieces[b.pieces.len - 1];
    format(s, "board dim ", r2(b.dim), ", last drawn ", drive::name(v, board::hit(l, v, float2 { top.at.x, top.at.y })),
           " dim ", r2(top.win.x));
    return s;
}

// The card: its tiles beyond the panels' and their opacity, and the crowned piece's.
fn card(g: gui::Gui&) -> u8[>..] {
    var s: u8[>..] = [];
    var k = 0;
    for q in g.quads {
        guard q.look.x == gui::BUTTON && q.extra.y < gui::CLOCK_RUN else { continue; }
        k++;
        if k > 4 { format(s, "tile at y ", r2(q.rect.y), " opacity ", r2(1.0 - q.extra.w), "; "); }
    }
    for p in drive::over { if p.look.y > 0.5 { format(s, "crowned ", r2(p.look.w), " ring ", r2(p.ring.y)); } }
    return if s.len > 0 { s } else { str("none") };
}

// Frames 1/60 s apart from `from` to `to`, as the app draws them: when the frame says
// something changed or the game is animating. How many, and when the last was.
fn frames(gm: game::Game&, g: gui::Gui&, l: panel::Layout, from: f64, to: f64) -> u8[>..] {
    var n = 0;
    var last = -1.0;
    var t = from;
    while t < to {
        gui::begin(g, gui::Input { at: drive::AWAY, .. }, l.board.scale, t);
        let go, changed = game::frame(gm, g, l, t, drive::over);
        if changed || game::animating(gm, g, t) {
            n++;
            last = t;
        }
        t += 1.0 / 60.0;
    }
    return str(n, " frames, the last at ", r2(last - gm.won_at), " s");
}

// Plays the move `a`-`b` that wins in `fen`, and returns when the win began.
fn win(gm: game::Game&, g: gui::Gui&, l: panel::Layout, variant: u8, fen: const u8[:], a: const u8[:], b: const u8[:],
       now: f64) -> f64 {
    let p, ok = rules::parse_fen(fen, variant);
    assert(ok);
    gm = game::new(variant);
    board::set(gm.b, p);
    gm.turn = gm.b.pos.side;
    drive::tap(gm, g, l, drive::at(l.board, a), now);
    drive::tap(gm, g, l, drive::at(l.board, b), now + 0.1);
    var t = now + 0.2;
    while gm.won_at < 0.0 {
        drive::idle(gm, g, l, t);
        t += 1.0 / 60.0;
    }
    return gm.won_at;
}

fn main() {
    strings::use(strings::EN);
    let l = panel::layout(1280.0, 800.0, 8);
    var g = gui::Gui {};
    gui::test_faces(g);
    var gm = game::new(rules::RUSSIAN);

    // White's e3 takes black's last piece on f4, landing on g5; white's other pieces are
    // 3.2 (h2) to 7.2 (a1) squares from it, so the glow has passed them all by 1.33 s.
    let w = win(gm, g, l, rules::RUSSIAN, "W:Wa1,c1,g1,b2,h2,e3:Bf4", "e3", "g5", 0.0);
    print("Russian, e3 takes f4 to g5: the winning piece ", drive::name(rules::VARIANTS[rules::RUSSIAN], gm.won_on),
          ", still from ", r2(gm.still), " s");
    for t in [0.2, 0.5, 0.75, 1.2, 1.4, 2.5] {
        drive::idle(gm, g, l, w + t);
        print("  at ", t, " s: ", board_at(gm, l.board, w + t));
        print("    card: ", card(g));
    }
    // The frames from the win on: none once it is still, but the one at rest.
    let w2 = win(gm, g, l, rules::RUSSIAN, "W:Wa1,c1,g1,b2,h2,e3:Bf4", "e3", "g5", 10.0);
    print("frames over 5 s from the win: ", frames(gm, g, l, w2, w2 + 5.0), "; animating at 2 s ",
          game::animating(gm, g, w2 + 2.0));

    // International, h8 takes i9 to j10, crowned, the other piece on a1 across the board:
    // the glow reaches it at 1.17 s and passes by 1.77 s, and that is when it is still.
    let li = panel::layout(1280.0, 800.0, 10);
    let wi = win(gm, g, li, rules::INTERNATIONAL, "W:W14,46:B10", "h8", "j10", 20.0);
    print("International, h8 takes i9 to j10: the winning piece ",
          drive::name(rules::VARIANTS[rules::INTERNATIONAL], gm.won_on), ", still from ", r2(gm.still), " s");
    drive::idle(gm, g, li, wi + 1.4);
    print("  at 1.4 s: ", board_at(gm, li.board, wi + 1.4));
    print("  frames over 5 s: ", frames(gm, g, li, wi, wi + 5.0));

    // Black to move with no move left from the start: white has won with no move to
    // show, so the dim and the card come at once, still from 0.8 s.
    let p, ok = rules::parse_fen("B:Wg1:Bh2", rules::RUSSIAN);
    assert(ok);
    gm = game::new(rules::RUSSIAN);
    board::set(gm.b, p);
    gm.turn = gm.b.pos.side;
    drive::idle(gm, g, l, 30.0);
    print("set up won: winner ", game::winner(gm), ", the winning piece ", gm.won_on);
    drive::idle(gm, g, l, 30.3);
    print("  at 0.3 s: ", board_at(gm, l.board, 30.3));
    print("    card: ", card(g));
    print("  frames over 5 s: ", frames(gm, g, l, gm.won_at, gm.won_at + 5.0));

    // A turned board (black playing up the screen, the computer white): black's d6 takes
    // e5 to f4; its pieces on h8 and b8 answer as on a board the right way up.
    var turned = panel::layout(1280.0, 800.0, 8);
    turned.board.flip = true;
    let wt = win(gm, g, turned, rules::RUSSIAN, "B:We5:Bd6,h8,b8", "d6", "f4", 40.0);
    drive::idle(gm, g, turned, wt + 0.9);
    print("turned, d6 takes e5 to f4, at 0.9 s: ", board_at(gm, turned.board, wt + 0.9));
}
