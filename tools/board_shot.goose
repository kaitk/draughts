// One headless shot of the 3D board in a season's look and material, for settings' Board
// row (tools/assets/board_thumbs.py): the 3D reference's position from the app's camera
// (view3d's), drawn by the app's renderer (src/render3d/) in front of the season's
// photograph, the look picked as the app picks it (looks::of), its wood and finish as
// draw3d::choose_look gives them.
//
//   goose build -o build/board_shot tools/board_shot.goose
//   build/board_shot out.png [--size 1600x1200] [--season autumn|winter|spring|summer]
//                            [--material auto|wood|stone|carved]

import std;
import vec;
import math;
import os;
import gfx;
import rules from "../src/rules";
import gui from "../src/gui";
import strings from "../strings";
import board from "../src/board";
import model3d from "../src/model3d";
import render3d from "../src/render3d";

// The position: the 3D reference's, dark pieces on the far rows and light on the near,
// one light king (a stack of two discs), one light piece selected. Each piece is (row,
// col, dark, king, selected); row 0 is the far side, and pieces stand on the dark squares.
let PIECES: i32[5][23] = [
    [0, 1, 1, 0, 0], [0, 3, 1, 0, 0], [0, 5, 1, 0, 0], [0, 7, 1, 0, 0],
    [1, 0, 1, 0, 0], [1, 2, 1, 0, 0], [1, 4, 1, 0, 0], [1, 6, 1, 0, 0],
    [2, 1, 1, 0, 0], [2, 3, 1, 0, 0], [2, 5, 1, 0, 0], [2, 7, 1, 0, 0],
    [3, 2, 1, 0, 0], [3, 6, 1, 0, 0],
    [5, 0, 0, 0, 0], [5, 6, 0, 0, 0],
    [6, 1, 0, 0, 0], [6, 3, 0, 0, 0], [6, 5, 0, 0, 1],
    [7, 0, 0, 0, 0], [7, 2, 0, 0, 0], [7, 4, 0, 1, 0], [7, 6, 0, 0, 0],
];

// Puts the position on the GPU: the instances (two float4s each: foot and scale; dark,
// 0.5 a stack's upper disc, 1 selected or 2 a stack's lower disc, seed), the squares the
// field's occlusion reads (top, foot, radius, occupied; then the piece's middle), no
// marks, and where the selected piece stands.
fn place(r3d: render3d::Own&, g: render3d::Gpu&) {
    var inst:    float4[..64] = [];
    var squares: float4[200]  = [float4_0; 200];
    var marks:   float4[100]  = [float4 { 0.0, 0.0, 0.0, -1.0 }; 100];
    var lit:     float4[100]  = [float4_0; 100];
    var fades:   f32[1]       = [0.0];
    var selected = float4_0;
    for p, i in PIECES {
        let x = p[1] as f32 - 3.5;
        let z = p[0] as f32 - 3.5;
        let dark: f32 = if p[2] == 1 { 1.0 } else { 0.0 };
        let sel = p[4] == 1;
        let lift:  f32 = if sel { view3d::LIFT } else { 0.0 };
        let scale: f32 = if sel { view3d::GROW } else { 1.0 };
        let seed = i as f32;
        var top = lift + view3d::HEIGHT * scale;
        if p[3] == 1 {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, 2.0, seed });
            inst.push(float4 { x, top, z, scale });
            inst.push(float4 { dark, 0.5, 0.0, seed + 0.5 });
            top += view3d::HEIGHT * scale;
        } else {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, if sel { 1.0 } else { 0.0 }, seed });
        }
        squares[2 * (p[0] * 8 + p[1])] = float4 { top, lift, view3d::RADIUS * scale, 1.0 };
        squares[2 * (p[0] * 8 + p[1]) + 1] = float4 { x, z, 0.0, 0.0 };
        if sel { selected = float4 { x, lift, z, view3d::RADIUS * scale }; }
    }
    render3d::place(r3d, g, inst[..inst.len], fades[..0], squares[..], marks[..], lit[..], selected, 0.0, true);
}

// The index of the flag's value in argv, or -1.
fn flag(argv: u8[:][>..]&, name: const u8[:]) -> i64 {
    for a, i in argv {
        if a == name && i + 1 < argv.len { return i + 1; }
    }
    return -1;
}

// Which of `names` the flag's value is, or `otherwise`.
fn pick(argv: u8[:][>..]&, name: const u8[:], names: const u8[:][], otherwise: i64) -> i64 {
    let at = flag(argv, name);
    if at < 0 { return otherwise; }
    for n, i in names { if argv[at] == n { return i; } }
    abort(str(name, ": no ", argv[at]));
    return otherwise;
}

fn main() {
    let argv = args();
    guard argv.len > 1 && argv[1].len > 0 && argv[1][0] != '-' else {
        abort("usage: board_shot OUT.png [--size WxH] [--season S] [--material M]");
    }
    var w = 1600;
    var h = 1200;
    let si = flag(argv, "--size");
    if si > 0 {
        let a, b, ok = split_once(argv[si], "x");
        let x, okx = parse_int(a);
        let y, oky = parse_int(b);
        guard ok && okx && oky else { abort("--size: WxH"); }
        w = x;
        h = y;
    }
    // looks::AUTUMN.. and MATERIAL_AUTO.. in this order.
    let season = pick(argv, "--season", ["autumn", "winter", "spring", "summer"], looks::AUTUMN);
    let material = pick(argv, "--material", ["auto", "wood", "stone", "carved"], looks::MATERIAL_AUTO);
    guard gfx::open_headless(w, h) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    var g = default<render3d::Gpu>();
    // What gfx's 3D recorder holds beside the Gpu, the first argument of render3d's calls that record.
    var r3d = default<render3d::Own>();
    render3d::setup(r3d, g, render3d::SAMPLES, render3d::SHADOW_16);
    render3d::set_aa(r3d, g, render3d::AA);
    render3d::choose(g, -1, looks::MARBLE, looks::SPRING_LOOK);
    // As draw3d::choose_look: spring's birch is spring's look 0 to the renderer, and each
    // look takes its own wood's model and that model's finish.
    let look = looks::of(season, material);
    if look == looks::SPRING { g.spring = 0; }
    let shown = looks::shown(look, g.spring);
    let own = looks::wood_for(shown);
    render3d::choose(g, if own >= 0 { own } else { model3d::WOOD_MODEL }, -1);
    g.finish = looks::finish_for(shown, g.wood);
    render3d::apply(r3d, g, look, 8);
    place(r3d, g);

    let pitch = view3d::PITCH * PI / 180.0;
    let eye = view3d::TARGET + float3 { 0.0, sin(pitch), cos(pitch) } * view3d::DISTANCE;
    let proj = gfx::perspective(view3d::FOV * PI / 180.0, w as f32 / h, view3d::NEAR, view3d::FAR);
    render3d::draw(r3d, g, gfx::mul(proj, gfx::look_at(eye, view3d::TARGET, float3 { 0.0, 1.0, 0.0 })), eye,
                   gfx::screen(), gfx::screen_size());
    guard gfx::screenshot(argv[1]) else { abort(str("could not save ", argv[1])); }
}
