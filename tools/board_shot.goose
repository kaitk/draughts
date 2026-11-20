// One headless shot of the 3D board in a season's look and material, for settings' Board
// row (tools/assets/board_thumbs.py): the 3D reference's position from the app's camera
// (view3d's), drawn by the app's renderer (src/render3d/) in front of the season's
// photograph, the look picked as the app picks it (looks::of), its wood and finish as
// draw3d::choose_look gives them. The pieces' values can be overridden to shoot versions
// side by side (task 094; tools/pieces3d.goose's read_flags): tools/piece_tune.goose
// prints the flags of what its sliders show.
//
//   goose build -o build/board_shot tools/board_shot.goose
//   build/board_shot out.png [--size 1600x1200] [--season autumn|winter|spring|summer]
//                            [--material auto|wood|stone|carved] [--table board|flame]
//                            [--light-scatter R,G,B,S] [--dark-scatter R,G,B,S]
//                            [--wear UNEVEN,EDGES,TONE] [--light R,G,B,ROUGH]
//                            [--dark R,G,B,ROUGH] [--figure X,Y,Z,W] [--before]
//                            [--profile K]   # pieces3d::profile, before the other flags

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
import .pieces3d;

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
    let take = pick(argv, "--table", tables::NAMES, -1);
    g.table = take >= 0;
    if take >= 0 { g.table_spec = tables::get(take); }
    let shown = pieces3d::put_look(r3d, g, season, material);
    var pieces = pieces3d::of_look(shown);
    pieces3d::read_flags(argv, pieces, shown);
    pieces3d::put(g, pieces, model3d::dark_brightness(pieces.mineral));
    pieces3d::place(r3d, g);

    let view, eye = pieces3d::camera(gfx::screen_size());
    render3d::draw(r3d, g, view, eye, gfx::screen(), gfx::screen_size());
    guard gfx::screenshot(argv[1]) else { abort(str("could not save ", argv[1])); }
}
