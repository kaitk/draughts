// Tunes the table under the 3D board (task 095): a take (tables::BOARD_WOOD..) on a season's
// board, its wood, age, polish, light and edge on sliders, baked again as they change.
// Drag to orbit, scroll to zoom, R resets the camera, P prints the table as Goose to put
// in src/model3d/tables.goose.
//
//   goose build -o build/table_tune tools/table_tune.goose
//   cd tools && ../build/table_tune [--table board|flame] [--season autumn|winter|spring|summer]
//                                   [--material auto|wood|stone|carved] [--size 1600x1000]
//                                   [--distance K] [--height DEG] [--yaw DEG] [--shot out.png]

import std;
import vec;
import math;
import os;
import gfx;
import ui;
import rules from "../src/rules";
import gui from "../src/gui";
import strings from "../strings";
import board from "../src/board";
import model3d from "../src/model3d";
import render3d from "../src/render3d";

let PANEL_W: f32 = 360.0;
let ROW:     f32 = 20.0;
// looks::AUTUMN.. and MATERIAL_AUTO.. in this order.
let SEASONS = ["autumn", "winter", "spring", "summer"];
let MATERIALS = ["auto", "wood", "stone", "carved"];
let EDGES = ["bullnose", "thumbnail", "ogee", "stepped"];

// A mid-game position, dark on the far rows: (row, col, dark), row 0 the far side.
let PIECES: i32[3][12] = [
    [0, 1, 1], [0, 5, 1], [1, 2, 1], [1, 6, 1], [2, 3, 1], [3, 4, 1],
    [4, 1, 0], [5, 2, 0], [5, 6, 0], [6, 3, 0], [7, 0, 0], [7, 4, 0],
];

fn place(r3d: render3d::Own&, g: render3d::Gpu&) {
    var inst:    float4[..64] = [];
    var squares: float4[200]  = [float4_0; 200];
    var marks:   float4[100]  = [float4 { 0.0, 0.0, 0.0, -1.0 }; 100];
    var lit:     float4[100]  = [float4_0; 100];
    var fades:   f32[1]       = [0.0];
    for p, i in PIECES {
        let x = p[1] as f32 - 3.5;
        let z = p[0] as f32 - 3.5;
        let dark: f32 = if p[2] == 1 { 1.0 } else { 0.0 };
        inst.push(float4 { x, 0.0, z, 1.0 });
        inst.push(float4 { dark, 0.0, 0.0, i });
        squares[2 * (p[0] * 8 + p[1])] = float4 { view3d::HEIGHT, 0.0, view3d::RADIUS, 1.0 };
        squares[2 * (p[0] * 8 + p[1]) + 1] = float4 { x, z, 0.0, 0.0 };
    }
    render3d::place(r3d, g, inst[..inst.len], fades[..0], squares[..], marks[..], lit[..], float4_0, 0.0, true);
}

// The season's look in the material, its wood and finish as the app picks them
// (draw3d::choose_look), baked with the table.
fn put_look(r3d: render3d::Own&, g: render3d::Gpu&, season: i64, material: i64) {
    let look = looks::of(season, material);
    if look == looks::SPRING { g.spring = 0; }
    let shown = looks::shown(look, g.spring);
    let own = looks::wood_for(shown);
    render3d::choose(g, if own >= 0 { own } else { model3d::WOOD_MODEL }, -1);
    g.finish = looks::finish_for(shown, g.wood);
    g.look = -1;
    render3d::apply(r3d, g, look, 8);
    place(r3d, g);
}

fn num(out: u8[>..]&, v: f32) {
    let k = floor(v * 1000.0 + 0.5) / 1000.0;
    format(out, k);
}

fn vec4(out: u8[>..]&, name: const u8[:], v: float4) {
    format(out, "        ", name, " float4 { ");
    num(out, v.x);
    out.append(", ");
    num(out, v.y);
    out.append(", ");
    num(out, v.z);
    out.append(", ");
    num(out, v.w);
    out.append(" },\n");
}

// The table as a Goose literal for tables.goose.
fn report(t: tables::Table&) {
    var out: u8[>..] = [];
    out.append("    return Table {\n");
    vec4(out, "wood:   ", t.wood);
    vec4(out, "fig:    ", t.fig);
    vec4(out, "ring:   ", t.ring);
    out.append("        model:   ");
    num(out, t.model);
    out.append(",\n");
    vec4(out, "pores:  ", t.pores);
    vec4(out, "surface:", t.surface);
    vec4(out, "planks: ", t.planks);
    vec4(out, "patina: ", t.patina);
    vec4(out, "wear:   ", t.wear);
    vec4(out, "flame:  ", t.flame);
    let f = t.finish;
    out.append("        finish:  looks::Finish { varnish: ");
    num(out, f.varnish);
    out.append(", sanding: ");
    num(out, f.sanding);
    out.append(", grain: ");
    num(out, f.grain);
    out.append(", rings: ");
    num(out, f.rings);
    out.append(", warmth: ");
    num(out, f.warmth);
    out.append(", pickle: 0.0,\n                                 caulk: 1.0 },\n");
    vec4(out, "light:  ", t.light);
    vec4(out, "coat:   ", t.coat);
    vec4(out, "polish: ", t.polish);
    vec4(out, "edge:   ", t.edge);
    out.append("    };");
    print(out);
    // Also kept in a file, as a window's tool has no terminal to read.
    if write_file("../build/table/table.txt", out[..]) { print("saved in build/table/table.txt"); }
}

fn slider(c: ui::Context, name: const u8[:], v: f32&, lo: f32, hi: f32) {
    let ratios: f32[2] = [0.45, 0.55];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    var text: u8[>..] = [];
    text.append(name);
    text.push(' ');
    num(text, v);
    ui::label(c, text, ui::TEXT_LEFT);
    ui::slider_float(c, lo, v, hi, (hi - lo) / 400.0);
}

fn choice(c: ui::Context, name: const u8[:], v: i64&, names: const u8[:][]) {
    let ratios: f32[2] = [0.45, 0.55];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    ui::label(c, str(name, " ", names[v]), ui::TEXT_LEFT);
    ui::slider_int(c, 0, v, names.len - 1, 1);
}

fn heading(c: ui::Context, text: const u8[:]) {
    ui::layout_row_dynamic(c, ROW + 4.0, 1);
    ui::label(c, text, ui::TEXT_LEFT);
}

fn flag_value(argv: u8[:][>..]&, name: const u8[:]) -> i64 {
    for a, i in argv { if a == name && i + 1 < argv.len { return i + 1; } }
    return -1;
}

fn pick(argv: u8[:][>..]&, name: const u8[:], names: const u8[:][], otherwise: i64) -> i64 {
    let at = flag_value(argv, name);
    if at < 0 { return otherwise; }
    for n, i in names { if argv[at] == n { return i; } }
    abort(str(name, ": no ", argv[at]));
    return otherwise;
}

// The flag's number, or `otherwise`.
fn number(argv: u8[:][>..]&, name: const u8[:], otherwise: f32) -> f32 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    let v, ok = parse_flt(argv[at]);
    guard ok else { abort(str(name, ": a number")); }
    return v as f32;
}

// Whether a and b bake the same wood (the light, the polish and the edge aside).
fn same_bake(a: tables::Table&, b: tables::Table&) -> bool {
    var x = a;
    var y = b;
    x.light = float4_0;
    y.light = float4_0;
    x.coat = float4_0;
    y.coat = float4_0;
    x.polish = float4_0;
    y.polish = float4_0;
    x.edge = float4_0;
    y.edge = float4_0;
    return x == y;
}

fn main() {
    let argv = args();
    var w = 1600;
    var h = 1000;
    let si = flag_value(argv, "--size");
    if si > 0 {
        let a, b, ok = split_once(argv[si], "x");
        let x, okx = parse_int(a);
        let y, oky = parse_int(b);
        guard ok && okx && oky else { abort("--size: WxH"); }
        w = x;
        h = y;
    }
    var season = pick(argv, "--season", SEASONS, looks::AUTUMN);
    var material = pick(argv, "--material", MATERIALS, looks::MATERIAL_AUTO);
    var take = pick(argv, "--table", tables::NAMES, tables::BOARD_WOOD);
    guard gfx::open("Draughts: the table's tuning", w, h, gfx::WINDOW_RESIZABLE) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    var g = default<render3d::Gpu>();
    var r3d = default<render3d::Own>();
    render3d::setup(r3d, g, render3d::SAMPLES, render3d::SHADOW_16);
    render3d::set_aa(r3d, g, render3d::AA);
    render3d::choose(g, -1, looks::MARBLE, looks::SPRING_LOOK);
    g.table = true;
    var t = tables::get(take);
    g.table_spec = t;
    put_look(r3d, g, season, material);
    var baked = t;

    let scale = max(gfx::screen_size().x as f32 / w, 1.0);
    let c = ui::create(13.0, scale);
    guard c.id != 0 else { abort(str("ui: ", ui::error())); }
    var shown_season = season;
    var shown_material = material;
    var shown_take = take;
    var edge = t.edge.x as i64;
    var model = t.model as i64;
    var yaw:   f32 = number(argv, "--yaw", 0.0);
    var pitch: f32 = number(argv, "--height", view3d::PITCH);
    var far:   f32 = number(argv, "--distance", 1.0);
    let shot = flag_value(argv, "--shot");
    var frames = 0;
    var last_bake = 0.0;
    while gfx::frame() {
        frames++;
        if shot > 0 && frames == 6 {
            guard gfx::screenshot(argv[shot]) else { abort(str("could not save ", argv[shot])); }
            break;
        }
        ui::input_from_gfx(c);
        var print_it = gfx::key_pressed("P");
        let flags = ui::WINDOW_BORDER | ui::WINDOW_TITLE | ui::WINDOW_MOVABLE | ui::WINDOW_SCALABLE;
        let panel_h = gfx::screen_size().y / scale - 20.0;
        if ui::begin(c, "Table", ui::rect(10.0, 10.0, PANEL_W, panel_h), flags) {
            choice(c, "Take", take, tables::NAMES);
            choice(c, "Season", season, SEASONS);
            choice(c, "Board", material, MATERIALS);
            heading(c, "View (drag, scroll, R)");
            slider(c, "Distance", far, 0.4, 4.0);
            slider(c, "Height", pitch, 10.0, 89.0);
            heading(c, "Wood");
            slider(c, "Red", t.wood.x, 0.0, 1.0);
            slider(c, "Green", t.wood.y, 0.0, 1.0);
            slider(c, "Blue", t.wood.z, 0.0, 1.0);
            slider(c, "Warmth", t.finish.warmth, -1.0, 1.0);
            choice(c, "Model", model, ["noise", "rings", "rings+pores", "lines"]);
            slider(c, "Grain contrast", t.finish.grain, 0.0, 2.0);
            slider(c, "Wander", t.fig.x, 0.0, 1.0);
            slider(c, "Broad figure", t.fig.y, 0.0, 1.0);
            slider(c, "Fine streaks", t.fig.z, 0.0, 1.0);
            slider(c, "Ring width", t.ring.x, 0.02, 0.3);
            slider(c, "Flat-sawn", t.ring.y, 0.0, 1.0);
            slider(c, "Late wood", t.ring.z, 0.0, 1.0);
            slider(c, "Ring pores", t.ring.w, 0.0, 1.0);
            slider(c, "Pores", t.pores.x, 0.0, 2.0);
            slider(c, "Open pores", t.pores.y, 0.0, 2.0);
            slider(c, "Furrows", t.pores.z, 0.0, 2.0);
            slider(c, "Relief", t.surface.w, 0.0, 2.0);
            slider(c, "Sanding", t.finish.sanding, 0.0, 1.0);
            slider(c, "Plank tone", t.surface.x, 0.0, 0.3);
            slider(c, "Plank width", t.planks.x, 2.0, 60.0);
            slider(c, "Seams", t.surface.z, 0.0, 1.0);
            slider(c, "Ribbon", t.planks.z, 0.0, 0.4);
            heading(c, "Flame figure");
            slider(c, "Flame", t.flame.x, 0.0, 2.0);
            slider(c, "Flame scale", t.flame.y, 0.05, 1.5);
            slider(c, "Sweep", t.flame.z, 0.0, 3.0);
            slider(c, "Leaves alike", t.flame.w, 0.0, 1.0);
            heading(c, "Age");
            slider(c, "Blotches", t.patina.x, 0.0, 1.0);
            slider(c, "Crazing", t.patina.y, 0.0, 1.0);
            slider(c, "Scratches", t.patina.z, 0.0, 1.0);
            slider(c, "Dents", t.patina.w, 0.0, 1.0);
            slider(c, "Rim wear", t.wear.x, 0.0, 1.0);
            slider(c, "Wear width", t.wear.y, 0.1, 2.0);
            heading(c, "Polish and light");
            slider(c, "Top roughness", t.wood.w, 0.02, 0.6);
            slider(c, "Edge roughness", t.coat.x, 0.02, 0.6);
            slider(c, "Polish", t.coat.y, 0.0, 1.5);
            slider(c, "Highlight size", t.coat.w, 0.05, 0.9);
            slider(c, "Follows relief", t.coat.z, 0.0, 1.0);
            slider(c, "Blotchy roughness", t.polish.x, 0.0, 1.0);
            slider(c, "Blotchy strength", t.polish.y, 0.0, 1.0);
            slider(c, "Blotch size", t.polish.z, 0.3, 8.0);
            slider(c, "Wear in polish", t.polish.w, 0.0, 2.0);
            slider(c, "Reflection", t.light.w, 0.0, 2.0);
            slider(c, "Pool reach", t.light.x, 3.0, 30.0);
            slider(c, "Pool dim", t.light.y, 0.0, 1.0);
            slider(c, "Under dark", t.light.z, 0.0, 1.0);
            heading(c, "Edge");
            choice(c, "Profile", edge, EDGES);
            slider(c, "Thickness", t.edge.y, 0.4, 1.6);
            slider(c, "Moulding", t.edge.z, 0.1, 0.7);
            slider(c, "Frieze in", t.edge.w, 0.5, 3.0);
            ui::layout_row_dynamic(c, ROW + 4.0, 2);
            if ui::button_label(c, "Print (P)") { print_it = true; }
            if ui::button_label(c, "Reset take") { shown_take = -1; }
        }
        ui::end(c);
        t.edge.x = edge;
        t.model = model;
        if take != shown_take {
            shown_take = take;
            t = tables::get(take);
            edge = t.edge.x as i64;
            model = t.model as i64;
        }
        if season != shown_season || material != shown_material {
            shown_season = season;
            shown_material = material;
            g.table_spec = t;
            put_look(r3d, g, season, material);
            baked = t;
        }
        // The wood baked again once a slider rests, or every quarter second while one moves.
        let now = clock();
        if !same_bake(t, baked) && (!gfx::mouse_down(gfx::MOUSE_LEFT) || now - last_bake > 0.25) {
            render3d::tune_table(r3d, g, t);
            baked = t;
            last_bake = now;
        } else {
            // The light, the polish and the edge show at once; the wood as last baked.
            var shown = baked;
            shown.light = t.light;
            shown.coat = t.coat;
            shown.polish = t.polish;
            shown.edge = t.edge;
            g.table_spec = shown;
            render3d::table_mesh(r3d, g);
        }
        if print_it { report(t); }
        if gfx::key_pressed("R") {
            yaw = 0.0;
            pitch = view3d::PITCH;
            far = 1.0;
        }
        if !ui::wants_mouse(c) {
            if gfx::mouse_down(gfx::MOUSE_LEFT) {
                let d = gfx::mouse_delta();
                yaw -= d.x * 0.25;
                pitch = clamp(pitch + d.y * 0.25, 10.0, 89.0);
            }
            far = clamp(far * pow(0.9 as f32, gfx::mouse_wheel()), 0.4, 4.0);
        }
        let size = gfx::screen_size();
        let a = radians(pitch);
        let b = radians(yaw);
        let eye = view3d::TARGET + float3 { sin(b) * cos(a), sin(a), cos(b) * cos(a) } * (view3d::DISTANCE * far);
        let proj = gfx::perspective(view3d::FOV * PI / 180.0, size.x as f32 / size.y, 1.0, 120.0);
        render3d::draw(r3d, g, gfx::mul(proj, gfx::look_at(eye, view3d::TARGET, float3 { 0.0, 1.0, 0.0 })), eye,
                       gfx::screen(), size);
        if shot < 0 { ui::render(c); }
    }
}
