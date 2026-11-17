// Compare piece scattering. B toggles it while preserving the materials.
// Drag to orbit, scroll to zoom, R resets the camera.
//   goose build -o build/piece_tune tools/piece_tune.goose
//   build/piece_tune [--season autumn|winter|spring|summer] [--material auto|wood|stone|carved]
//                    [--size 1600x1000] [any of board_shot's pieces' flags]
//                    [--shot out.png]   # the window saved after a few frames, then closed

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
import .pieces3d;

let PANEL_W: f32 = 330.0;
let PANEL_H: f32 = 510.0;
let ROW:     f32 = 21.0;
// looks::AUTUMN.. and MATERIAL_AUTO.. in this order.
let SEASONS = ["autumn", "winter", "spring", "summer"];
let MATERIALS = ["auto", "wood", "stone", "carved"];

// A label with its value, and a slider.
fn slider(c: ui::Context, name: const u8[:], v: f32&, lo: f32, hi: f32) {
    let ratios: f32[2] = [0.45, 0.55];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    var text: u8[>..] = [];
    text.append(name);
    text.push(' ');
    pieces3d::num(text, v);
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
    ui::layout_row_dynamic(c, ROW, 1);
    ui::label(c, text, ui::TEXT_LEFT);
}

// Preview a piece set on any board. Board default also accepts board_shot's profile.
fn selected_pieces(shown: i64, material: i64, profile: i64) -> pieces3d::Pieces {
    if material == 1 { return pieces3d::profile(looks::SPRING_STONE, 1); }
    if material == 2 { return pieces3d::of_look(looks::SPRING_STONE); }
    if material == 3 { return pieces3d::of_look(looks::AUTUMN); }
    return pieces3d::profile(shown, profile);
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
    var season = pick(argv, "--season", SEASONS, looks::SPRING);
    var material = pick(argv, "--material", MATERIALS, looks::MATERIAL_AUTO);
    guard gfx::open("Draughts: the pieces' tuning", w, h, gfx::WINDOW_RESIZABLE) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    var g = default<render3d::Gpu>();
    var r3d = default<render3d::Own>();
    render3d::setup(r3d, g, render3d::SAMPLES, render3d::SHADOW_16);
    render3d::set_aa(r3d, g, render3d::AA);
    render3d::choose(g, -1, looks::MARBLE, looks::SPRING_LOOK);
    var shown = pieces3d::put_look(r3d, g, season, material);
    var p = pieces3d::of_look(shown);
    pieces3d::read_flags(argv, p, shown);
    pieces3d::place(r3d, g);

    let scale = max(gfx::screen_size().x as f32 / w, 1.0);
    let c = ui::create(14.0, scale);
    guard c.id != 0 else { abort(str("ui: ", ui::error())); }
    var shown_season = season;
    var shown_material = material;
    var chosen = 0;         // the profile (pieces3d::profile)
    let pf = flag_value(argv, "--profile");
    if pf > 0 {
        let k, ok = parse_int(argv[pf]);
        if ok { chosen = k; }
    }
    let sets = ["Board default", "Plastic", "Jade", "Wood"];
    let lights = ["game", "left", "right"];
    var direction = pick(argv, "--key", lights, 0);
    var last_direction = -1;
    var piece_material = pick(argv, "--pieces", sets, 0);
    if piece_material != 0 { p = selected_pieces(shown, piece_material, chosen); }
    var scattering = pick(argv, "--scatter", ["off", "on"], if piece_material == 1 { 0 } else { 1 }) == 1;
    var dark_brightness: f32 = 1.0;
    var yaw:   f32 = 0.0;
    var pitch: f32 = 0.0;
    var near:  f32 = 1.0;
    let shot = flag_value(argv, "--shot");
    var frames = 0;
    while gfx::frame() {
        frames += 1;
        if shot > 0 && frames == 6 {
            guard gfx::screenshot(argv[shot]) else { abort(str("could not save ", argv[shot])); }
            break;
        }
        ui::input_from_gfx(c);
        if gfx::key_pressed("B") { scattering = !scattering; }
        var defaults = false;
        let flags = ui::WINDOW_BORDER | ui::WINDOW_TITLE | ui::WINDOW_MOVABLE | ui::WINDOW_SCALABLE;
        if ui::begin(c, "Material comparison", ui::rect(10.0, 10.0, PANEL_W, PANEL_H), flags) {
            choice(c, "season", season, SEASONS);
            choice(c, "Board", material, MATERIALS);
            let previous = piece_material;
            choice(c, "Pieces", piece_material, sets);
            choice(c, "Key", direction, lights);
            if piece_material != previous {
                scattering = piece_material != 1;
                p = selected_pieces(shown, piece_material, chosen);
                dark_brightness = 1.0;
            }
            ui::layout_row_dynamic(c, ROW + 4.0, 1);
            ui::checkbox_label(c, "Subsurface scattering (B)", scattering);
            heading(c, "Dark pieces");
            slider(c, "Scattering", p.dark_scatter.w, 0.0, 2.0);
            slider(c, "Brightness", dark_brightness, 0.25, 2.0);
            slider(c, "Texture", p.piece_fig.y, 0.0, 0.6);
            slider(c, "Roughness", p.dark_piece.w, 0.1, 1.0);
            heading(c, "Light pieces");
            slider(c, "Scattering", p.light_scatter.w, 0.0, 2.0);
            slider(c, "Texture", p.piece_fig.x, 0.0, 0.3);
            slider(c, "Roughness", p.light_piece.w, 0.1, 1.0);
            ui::layout_row_dynamic(c, ROW + 4.0, 1);
            if ui::button_label(c, "Reset material") { defaults = true; }
        }
        ui::end(c);
        if season != shown_season || material != shown_material {
            shown_season = season;
            shown_material = material;
            shown = pieces3d::put_look(r3d, g, season, material);
            pieces3d::place(r3d, g);
            last_direction = -1;
            chosen = 0;
            defaults = true;
        }
        if defaults {
            p = selected_pieces(shown, piece_material, chosen);
            dark_brightness = 1.0;
        }
        if gfx::key_pressed("R") {
            yaw = 0.0;
            pitch = 0.0;
            near = 1.0;
        }
        if !ui::wants_mouse(c) {
            if gfx::mouse_down(gfx::MOUSE_LEFT) {
                let d = gfx::mouse_delta();
                yaw -= d.x * 0.25;
                pitch = clamp(pitch + d.y * 0.25, -30.0, 30.0);
            }
            near = clamp(near * pow(0.9 as f32, gfx::mouse_wheel()), 0.25, 1.5);
        }
        if last_direction != direction {
            render3d::light(g);
            if direction != 0 {
                let l = normalize(float3 { if direction == 1 { -1.0 } else { 1.0 }, 0.32, 0.12 });
                g.frame.light_dir = model3d::f4(l, g.frame.light_dir.w);
                g.frame.light_view_proj = render3d::plan_light(l);
            }
            g.shadow_dirty = true;
            last_direction = direction;
        }
        pieces3d::put(g, p);
        g.frame.dark_piece.x *= dark_brightness;
        g.frame.dark_piece.y *= dark_brightness;
        g.frame.dark_piece.z *= dark_brightness;
        if !scattering {
            g.frame.light_scatter.w = 0.0;
            g.frame.dark_scatter.w = 0.0;
        }
        let size = gfx::screen_size();
        let view, eye = pieces3d::camera(size, yaw, pitch, near);
        render3d::draw(r3d, g, view, eye, gfx::screen(), size);
        if shot < 0 { ui::render(c); }
    }
}
