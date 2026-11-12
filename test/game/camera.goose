// The camera buttons on the game screen round the 3D board (task 015, the user's
// decisions of 2026-11-09), through the shell with the 3D board chosen, on the tablet's
// landscape at 1280 × 800 (a dp a pixel): the three round buttons under the play panel;
// the view button easing to the top view and back in 0.6 s, drawn only while it moves;
// the zoom framing the playing field in the room clear of the panels and the buttons, in
// the top view too; the showcase, whose drags turn and tip the camera and move no piece,
// its angle kept once it is off, with the view button's dot, and a move tapped through
// that angle; a game against a friend turning the board 180° after each move, keeping
// its size (its bounds as at rest mid-turn), the showcase's angle easing back with it, black's move tapped through the turned board, and
// a new game putting it back; against the computer no turn; a puzzle's buttons.
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

fn whole(x: f32) -> i64 { floor(x + 0.5) as i64 }
fn r1(x: f32) -> f64 { floor((x as f64) * 10.0 + 0.5) / 10.0 }
fn dp(r: float4) -> u8[>..] { str(whole(r.x), " ", whole(r.y), " ", whole(r.z), " x ", whole(r.w)) }

// The k-th floating button the last frame declared: its disc, and how many there were.
fn button(g: gui::Gui&, k: i64) -> float4 {
    var i = 0;
    for q, n in g.quads {
        guard drive::camera_disc(g, n) else { continue; }
        if i == k { return q.rect; }
        i++;
    }
    return float4 { 0.0, 0.0, 0.0, 0.0 };
}
fn buttons(g: gui::Gui&) -> i64 {
    var i = 0;
    for q, n in g.quads { if drive::camera_disc(g, n) { i++; } }
    return i;
}
fn middle(r: float4) -> float2 { float2 { r.x + 0.5 * r.z, r.y + 0.5 * r.w } }
// Whether the k-th button is lit, and shows its dot.
fn lit(g: gui::Gui&, k: i64) -> bool {
    var i = 0;
    for q, n in g.quads {
        guard drive::camera_disc(g, n) else { continue; }
        if i == k { return (q.look.z as i64) % 2 == 1; }
        i++;
    }
    return false;
}
fn dot(g: gui::Gui&, k: i64) -> bool {
    var i = 0;
    for q, n in g.quads {
        guard drive::camera_disc(g, n) else { continue; }
        if i == k { return q.look.z >= 2.0; }
        i++;
    }
    return false;
}

// The camera as the shell's view has it: its angle down and the board's turn.
fn angle(v: view3d::View) -> u8[>..] {
    let pitch = degrees(asin(-v.ahead.y));
    return str(r1(pitch), "° down, board turned ", r1(v.turn), "°, bounds ", dp(v.rect));
}

// Where a named square's middle lands on screen through the shell's view.
fn spot(sh: shell::Shell&, name: const u8[:]) -> float2 {
    let vr .= rules::VARIANTS[sh.game.b.variant];
    let c = view3d::to_world(sh.out.layout, board::center(sh.out.layout, vr, drive::square(vr, name)));
    let q = view3d::project(sh.out.view, float3 { c.x, 0.0, c.y });
    return float2 { q.x, q.y };
}

// Taps two squares through the perspective and lets the move play out.
fn play(sh: shell::Shell&, g: gui::Gui&, a: const u8[:], b: const u8[:], now: f64) {
    drive::tap(sh, g, spot(sh, a), now);
    drive::tap(sh, g, spot(sh, b), now + 0.1);
    drive::idle(sh, g, now + 1.0);
}

// Frames from `from` to `to` every 1/60 s with the pointer away: how many changed the view
// the board is drawn through (each a 3D redraw), and whether the shell still animated
// after the last.
fn run(sh: shell::Shell&, g: gui::Gui&, from: f64, to: f64) -> i64, bool {
    var redraws = 0;
    var last = sh.out.view;
    var t = from;
    while t <= to {
        drive::idle(sh, g, t);
        if !view3d::same_view(last, sh.out.view) { redraws++; }
        last = sh.out.view;
        t += 1.0 / 60.0;
    }
    return redraws, shell::animating(sh, g, to);
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    drive::size = float2 { 1280.0, 800.0 };
    var g = gui::Gui {};
    g.scale = gui::scale_of(1280.0, 800.0);
    gui::test_faces(g);
    var sh = shell::new(rules::RUSSIAN);
    sh.prefs.board = settings::RAISED;
    shell::apply_prefs(sh);
    game::start(sh.game, rules::RUSSIAN, clock::NONE, -1, game::MEDIUM, 40, 0);
    sh.screen = shell::GAME;
    drive::idle(sh, g, 0.0);
    print("at rest: ", angle(sh.out.view), "; ", buttons(g), " buttons:");
    for k in buttons(g) { print("  ", dp(button(g, k))); }

    // The view: the top view and back, each 0.6 s, drawn while it moves and then not.
    drive::tap(sh, g, middle(button(g, 0)), 1.0);
    var t = 1.04;
    let n1, moving1 = run(sh, g, t, t + 0.3);
    print("the view tapped, 0.3 s on: ", angle(sh.out.view), "; ", n1, " redraws");
    let n2, moving2 = run(sh, g, t + 0.3 + 1.0 / 60.0, t + 1.0);
    print("  1 s on: ", angle(sh.out.view), "; ", n2, " redraws more, still animating ", moving2);
    let n3, moving3 = run(sh, g, t + 1.0 + 1.0 / 60.0, t + 2.0);
    print("  a second later: ", n3, " redraws, animating ", moving3);
    drive::tap(sh, g, middle(button(g, 0)), 4.0);
    run(sh, g, 4.04, 5.0);
    print("tapped again: ", angle(sh.out.view));

    // The zoom: the field framed in the room, at rest and in the top view.
    let l0 = sh.out.view;
    drive::tap(sh, g, middle(button(g, 1)), 6.0);
    let nz, mz = run(sh, g, 6.04, 7.0);
    print("zoomed: ", angle(sh.out.view), ", ", r1(sh.out.view.k / l0.k), " times the size; ", nz, " redraws, animating ", mz);
    drive::tap(sh, g, middle(button(g, 0)), 8.0);
    run(sh, g, 8.04, 9.0);
    print("zoomed, the top view: ", angle(sh.out.view));
    drive::tap(sh, g, middle(button(g, 0)), 10.0);
    drive::tap(sh, g, middle(button(g, 1)), 10.1);
    run(sh, g, 10.14, 11.0);
    print("back: ", angle(sh.out.view), ", the same view as at first ", view3d::same_view(l0, sh.out.view));

    // The showcase: a drag on the board turns and tips the camera, moving no piece.
    let fen = rules::fen(sh.game.b.pos);
    drive::tap(sh, g, middle(button(g, 2)), 12.0);
    print("showcase on: lit ", lit(g, 2), ", dot ", dot(g, 0));
    let from = spot(sh, "c3");
    drive::frame(sh, g, from, true, true, false, 12.5);
    drive::frame(sh, g, from + float2 { -40.0, 0.0 }, true, false, false, 12.52);
    drive::frame(sh, g, from + float2 { -60.0, 30.0 }, true, false, false, 12.54);
    drive::frame(sh, g, from + float2 { -60.0, 30.0 }, false, false, true, 12.56);
    drive::idle(sh, g, 12.6);
    print("dragged 60 left and 30 down: ", angle(sh.out.view), "; eye ", r1(sh.out.view.eye.x), " ", r1(sh.out.view.eye.y), " ",
          r1(sh.out.view.eye.z), "; selected ", sh.game.b.selected, ", pressed ", sh.game.b.pressed, ", the position the same ",
          rules::fen(sh.game.b.pos) == fen, ", dot ", dot(g, 0));
    drive::tap(sh, g, middle(button(g, 2)), 13.0);
    let kept = sh.out.view;
    drive::idle(sh, g, 14.0);
    print("showcase off: lit ", lit(g, 2), ", the angle kept ", view3d::same_view(kept, sh.out.view), ", dot ", dot(g, 0));
    // White plays c3-d4 through that angle; the board then turns for black and the angle
    // eases back with the turn.
    let vr .= rules::VARIANTS[rules::RUSSIAN];
    drive::tap(sh, g, spot(sh, "c3"), 15.0);
    print("c3 tapped through the angle: selected ", drive::name(vr, sh.game.b.selected));
    drive::tap(sh, g, spot(sh, "d4"), 15.1);
    print("d4 tapped: moving ", sh.game.b.moving);
    let nt, mt = run(sh, g, 15.2, 15.7);
    print("the move shown, the board turning: ", angle(sh.out.view), ", dot ", dot(g, 0));
    let nt2, mt2 = run(sh, g, 15.7 + 1.0 / 60.0, 17.0);
    print("turned: ", angle(sh.out.view), "; ", nt + nt2, " redraws over the move and the turn, animating ", mt2, ", dot ",
          dot(g, 0), ", ", rules::fen(sh.game.b.pos));
    // Black, its pieces now at the bottom, plays f6-e5 through the turned board.
    let f6 = spot(sh, "f6");
    let e5 = spot(sh, "e5");
    print("f6 at ", whole(f6.x), " ", whole(f6.y), ", e5 at ", whole(e5.x), " ", whole(e5.y), " (low on the screen)");
    play(sh, g, "f6", "e5", 18.0);
    run(sh, g, 19.0, 20.0);
    print("black's move: ", rules::fen(sh.game.b.pos), "; ", angle(sh.out.view));
    // White takes on f6, the board turns to black again, and a new game turns it back.
    play(sh, g, "d4", "f6", 21.0);
    run(sh, g, 22.0, 23.0);
    print("white's capture: ", rules::fen(sh.game.b.pos), "; ", angle(sh.out.view));
    drive::tap(sh, g, drive::control(g, 2), 24.0);
    run(sh, g, 24.04, 24.4);
    print("started over, turning back: ", angle(sh.out.view));
    run(sh, g, 24.4 + 1.0 / 60.0, 25.0);
    print("  turned: ", angle(sh.out.view), ", ", rules::fen(sh.game.b.pos));

    // Against the computer the board stays turned to the child (here black, the flat
    // layout turned): no turn as the sides move.
    game::start(sh.game, rules::RUSSIAN, clock::NONE, rules::WHITE, game::MEDIUM, 40, 0);
    drive::idle(sh, g, 30.0);
    print("against the computer (white): ", angle(sh.out.view), ", the flat layout turned ", sh.out.layout.flip);
    var e = ai::Engine { .. };
    ai::init(e);
    e.node_limit = 2000;
    var now = 30.0;
    while sh.game.b.pos.side == rules::WHITE && now < 40.0 {
        if game::computer_to_move(sh.game) {
            let ask = game::asking(sh.game);
            if ask.id != 0 { game::answer(sh.game, ask.id, ai::think(e, ask.pos, ask.skill, ask.seed), 1); }
        }
        now += 0.1;
        drive::idle(sh, g, now);
    }
    run(sh, g, now, now + 2.0);
    print("after its move: ", angle(sh.out.view), ", black to move ", sh.game.b.pos.side == rules::BLACK);

    // A puzzle shares the layout and the buttons.
    shell::play_puzzle(sh, 0, 50.0);
    drive::idle(sh, g, 51.0);
    print("a puzzle: ", buttons(g), " buttons, ", angle(sh.out.view));
}
