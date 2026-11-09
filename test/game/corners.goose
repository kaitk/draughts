// The game screen round the 3D board (game/panel.goose's corners_in, task 015's
// `corners`), headless: in landscape the panels in the top corners and the board as
// large as clears them by half a gap, its near edge on the bottom margin; in portrait
// the flat board's order. At the tablet's size, a foldable, 4:3, and a 20:9 and a 9:16
// phone at 540 and 480 dp, in both orientations, and the phones and the tablet with
// their insets: every tile the game screen declares lies inside its panel and the safe
// area and keeps 88 dp, and the board's outline on screen lies inside the safe area and
// clear of the panels. A line per screen gives the board's bounds in dp, their
// proportions, and the far edge against the near one. Then what a steeper portrait camera
// (60 and 65°, a proposal) gives. Then the shell on the 3D board (settings::raised): a
// game tapped through the perspective, a piece dragged, and the flat layout's board
// untouched.
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

fn inside(r: float4, a: float4) -> bool {
    return r.x >= a.x - 0.5 && r.y >= a.y - 0.5 && r.x + r.z <= a.x + a.z + 0.5 && r.y + r.w <= a.y + a.w + 0.5;
}

fn dp(r: float4, u: f32) -> u8[>..] { str(whole(r.x / u), " ", whole(r.y / u), " ", whole(r.z / u), " x ", whole(r.w / u)) }

// The frame's far and near edges on screen, across.
fn edges(v: view3d::View) -> f32 {
    let e = view3d::INNER + view3d::FRAME_W;
    let t = view3d::FRAME_TOP;
    let far = view3d::project(v, float3 { e, t, -e }).x - view3d::project(v, float3 { -e, t, -e }).x;
    let near = view3d::project(v, float3 { e, t, e }).x - view3d::project(v, float3 { -e, t, e }).x;
    return far / near;
}

fn report(what: const u8[:], g: gui::Gui&, size: float2) {
    let u = gui::scale_of(size.x, size.y);
    let safe = gui::safe(g, size.x, size.y);
    let l = panel::corners_in(safe, 10, u);
    var gm = game::new(rules::INTERNATIONAL);
    drive::idle(gm, g, l, 0.0);
    var wrong: u8[>..] = [];
    var small = 0;
    for i in drive::tiles(g) {
        let r = drive::rect(g, i);
        if !inside(r, safe) { format(wrong, " tile ", i, " off the safe area;"); }
        if !inside(r, l.left) && !inside(r, l.right) { format(wrong, " tile ", i, " off its panel;"); }
        if r.z < 88.0 * u - 0.5 || r.w < 88.0 * u - 0.5 { small++; }
    }
    if small > 0 { format(wrong, " ", small, " taps under 88 dp;"); }
    var h: view3d::Hull = [];
    view3d::hull(l.view, h);
    for q in h { if !inside(float4 { q.x, q.y, 0.0, 0.0 }, safe) { format(wrong, " the board off the safe area;"); break; } }
    if view3d::touches(l.view, l.left, 0.0) || view3d::touches(l.view, l.right, 0.0) { format(wrong, " the board on a panel;"); }
    let r = l.view.rect;
    print("  ", what, ": board ", dp(r, u), " dp, ", floor(r.z / r.w * 100.0 + 0.5) / 100.0, ":1, far edge ",
          whole(100.0 * edges(l.view)), "%; panels ", dp(l.left, u), ", ", dp(l.right, u), "; ", drive::tiles(g),
          " tiles", if wrong.len == 0 { ", all in place" } else { "" }, wrong);
}

fn main() {
    strings::use(strings::EN);
    puzzles::load();
    var g = gui::Gui {};
    let sizes = [float2 { 1920.0, 1200.0 }, float2 { 1200.0, 1920.0 }, float2 { 2208.0, 1768.0 },
                 float2 { 1768.0, 2208.0 }, float2 { 2048.0, 1536.0 }, float2 { 1536.0, 2048.0 }];
    let names = ["the tablet, landscape", "the tablet, portrait", "a foldable, landscape", "a foldable, portrait",
                 "4:3, landscape", "4:3, portrait"];
    let phones = [float2 { 2400.0, 1080.0 }, float2 { 1080.0, 2400.0 }, float2 { 1920.0, 1080.0 },
                  float2 { 1080.0, 1920.0 }];
    let phone_names = ["a 20:9 phone, landscape", "a 20:9 phone, portrait", "a 9:16 phone, landscape",
                       "a 9:16 phone, portrait"];
    gui::short_dp = 800.0;
    for size, i in sizes {
        g.scale = gui::scale_of(size.x, size.y);
        gui::test_faces(g);
        report(names[i], g, size);
    }
    g.insets = float4 { 0.0, 0.0, 0.0, 72.0 };
    for size, i in sizes {
        guard i < 2 else { continue; }
        g.scale = gui::scale_of(size.x, size.y);
        gui::test_faces(g);
        report(str(names[i], ", its 72 px navigation bar"), g, size);
    }
    g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
    for d in [540.0, 480.0] {
        gui::short_dp = d as f32;
        for size, i in phones {
            guard i < 2 || d < 500.0 else { continue; }
            g.scale = gui::scale_of(size.x, size.y);
            gui::test_faces(g);
            report(str(phone_names[i], " at ", d as i64, " dp"), g, size);
            // The Pixel 7a's insets: the cutout at a side in landscape (either), at the top
            // in portrait, and the gesture bar.
            let sides = if size.x > size.y { 2 } else { 1 };
            for k in sides {
                g.insets = if size.x < size.y { float4 { 0.0, 118.0, 0.0, 84.0 } }
                           else if k == 0 { float4 { 118.0, 0.0, 0.0, 84.0 } } else { float4 { 0.0, 0.0, 118.0, 84.0 } };
                report(str(phone_names[i], " at ", d as i64, " dp, insets ", g.insets.x as i64, " ", g.insets.y as i64, " ",
                           g.insets.z as i64, " ", g.insets.w as i64), g, size);
                g.insets = float4 { 0.0, 0.0, 0.0, 0.0 };
            }
        }
    }
    gui::short_dp = 800.0;

    // The portrait camera, at its 52.5° and steeper: the board's bounds on the tablet and
    // on a 20:9 phone at 540 dp, and the band left over under the play.
    for size in [float2 { 1200.0, 1920.0 }, float2 { 1080.0, 2400.0 }] {
        if size.x == 1080.0 { gui::short_dp = 540.0; }
        let u = gui::scale_of(size.x, size.y);
        for p in [52.5, 60.0, 65.0] {
            let l = panel::corners_in(float4 { 0.0, 0.0, size.x, size.y }, 10, u, p as f32);
            let r = l.view.rect;
            print("portrait ", size.x as i64, " x ", size.y as i64, " at ", p, "° down: board ", whole(r.z / u), " x ",
                  whole(r.w / u), " dp, far edge ", whole(100.0 * edges(l.view)), "%, ",
                  whole((l.right.y - l.left.y + l.right.w) / u), " of ", whole(size.y / u), " dp tall used");
        }
        gui::short_dp = 800.0;
    }

    // The shell with the 3D board chosen: a game against a friend, Russian, tapped through
    // the perspective (c3 then d4), then a drag from f6 for black, and the flat layout.
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(1280.0, 800.0);
    gui::test_faces(g);
    var sh = shell::new(rules::RUSSIAN);
    sh.prefs.show_board_row = true;
    sh.prefs.board = settings::RAISED;
    sh.screen = shell::GAME;
    drive::idle(sh, g, 0.0);
    print("raised ", sh.raised, ", kings drawn as ", sh.game.b.king_look, ", flat layout ", sh.layout.board, ", 3D bounds ",
          sh.view.rect);
    let vr .= rules::VARIANTS[rules::RUSSIAN];
    var now = 1.0;
    for name in ["c3", "d4"] {
        let c = view3d::to_world(sh.layout, board::center(sh.layout, vr, drive::square(vr, name)));
        let q = view3d::project(sh.view, float3 { c.x, 0.0, c.y });
        drive::tap(sh, g, float2 { q.x, q.y }, now);
        now += 0.1;
        print("tap ", name, " at ", whole(q.x), " ", whole(q.y), ": selected ", drive::name(vr, sh.game.b.selected),
              ", moving ", sh.game.b.moving);
    }
    now += 1.0;
    drive::idle(sh, g, now);
    print("after: ", rules::fen(sh.game.b.pos));
    // A drag: press on f6's top, move it over e5, let go.
    let u = view3d::unit(8);
    let f6 = view3d::to_world(sh.layout, board::center(sh.layout, vr, drive::square(vr, "f6")));
    let e5 = view3d::to_world(sh.layout, board::center(sh.layout, vr, drive::square(vr, "e5")));
    let a = view3d::project(sh.view, float3 { f6.x, view3d::HEIGHT * u, f6.y });
    let top = view3d::LIFT * 0.016 / 0.011 + view3d::HEIGHT * u * view3d::GROW;
    let b = view3d::project(sh.view, float3 { e5.x, top, e5.y });
    drive::frame(sh, g, float2 { a.x, a.y }, true, true, false, now);
    print("pressed f6: selected ", drive::name(vr, sh.game.b.selected), ", dragging ", sh.game.b.dragging);
    drive::frame(sh, g, float2 { 0.5 * (a.x + b.x), 0.5 * (a.y + b.y) }, true, false, false, now + 0.02);
    drive::frame(sh, g, float2 { b.x, b.y }, true, false, false, now + 0.04);
    print("dragged: dragging ", sh.game.b.dragging, ", under ",
          drive::name(vr, board::hit(sh.layout, vr, sh.game.b.drag_at)));
    drive::frame(sh, g, float2 { b.x, b.y }, false, false, true, now + 0.06);
    drive::idle(sh, g, now + 2.0);
    print("dropped: ", rules::fen(sh.game.b.pos));
}
