// Compare piece scattering. B toggles it while preserving the materials.
// Drag to orbit, scroll to zoom, R resets the camera.
//   goose build -o build/piece_tune tools/piece_tune.goose
//   cd tools && ../build/piece_tune [--season autumn|winter|spring|summer] [--material auto|wood|stone|carved]
//                    [--size 1600x1000] [any of board_shot's pieces' flags]
//                    [--pieces Plastic|Jade|Wood|Slate|Marble] [--marble N] [--key game|left|right]
//                    [--scatter off|on] [--board-scatter off|on] [--board-strength 0..1]
//                    [--board-radius 0.02..0.6] [--board-color 0..3]
//                    [--yaw DEG] [--pitch DEG] [--near 0.25..1.5] [--shot out.png]

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
let PANEL_H: f32 = 540.0;
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

fn choice(c: ui::Context, name: const u8[:], v: i64&, names: const u8[:][:]) {
    let ratios: f32[2] = [0.45, 0.55];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    ui::label(c, str(name, " ", names[v]), ui::TEXT_LEFT);
    ui::slider_int(c, 0, v, names.len - 1, 1);
}

// Preview a piece set on any board. Board default also accepts board_shot's profile.
fn selected_pieces(shown: i64, material: i64, profile: i64) -> pieces3d::Pieces {
    if material == 1 { return pieces3d::profile(looks::SPRING_STONE, 1); }
    if material == 2 { return pieces3d::of_look(looks::SPRING_STONE); }
    if material == 3 {
        var p = pieces3d::of_look(looks::AUTUMN);
        p.mineral = looks::MINERAL_TURNED_WOOD;
        p.light_piece = float4 { 0.89, 0.77, 0.60, 0.5 };
        p.dark_piece = float4 { 0.36, 0.235, 0.16, 0.5 };
        // z: the varnish coat's strength, w: the figure's relief under it.
        p.piece_fig = float4 { 0.3, 0.3, 0.6, 1.0 };
        return p;
    }
    if material == 4 || material == 5 {
        var p = pieces3d::of_look(looks::WINTER);
        if material == 5 {
            p.mineral = looks::MINERAL_WINTER_MARBLE;
            p.dark_piece = float4 { 0.075, 0.08, 0.085, 0.15 };
            p.piece_fig.y = 0.2;
        }
        return p;
    }
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

fn scalar(argv: u8[:][>..]&, name: const u8[:], initial: f32, lo: f32, hi: f32) -> f32 {
    let at = flag_value(argv, name);
    if at < 0 { return initial; }
    let v, ok = parse_flt(argv[at]);
    guard ok && v >= lo && v <= hi else { abort(str("invalid ", name)); }
    return v as f32;
}

// The first six values scale the chosen slab. Polish is absolute (1 is glossy).
let SLAB_FLAGS = ["--slab-base", "--slab-strength", "--slab-spacing", "--slab-width",
                  "--slab-branches", "--slab-cloud", "--slab-polish"];
let SLAB_LOW:  f32[7] = [0.0, 0.0, 0.25, 0.05, 0.0, 0.0, 0.0];
let SLAB_HIGH: f32[7] = [5.0, 2.0, 3.0, 4.0, 3.0, 3.0, 1.0];

// The marbles' names (looks::MARBLES), and the slab sliders' labels in SLAB_FLAGS' order,
// then the reset button's and the board marble checkbox's.
let MARBLE_NAMES = ["slate", "Nero Marquina", "grey cloud", "blue-black", "threads", "calcite forks",
                    "silver web", "cloud breccia", "white lightning"];
let SLAB_LABELS = ["Base brightness", "Vein strength", "Vein spacing", "Vein width", "Branch strength",
                   "Cloud pockets", "Polish", "Reset marble", "Tune board marble"];

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
    // Winter's frame's marble (looks::marble): --marble N.
    var marble = scalar(argv, "--marble", looks::MARBLE, 0.0, looks::MARBLES - 1) as i64;
    var shown_marble = marble;
    render3d::choose(g, -1, marble, looks::SPRING_LOOK);
    var slabs = default<f32[7][looks::MARBLES]>();
    for i in looks::MARBLES { slabs[i] = looks::slab_defaults(i); }
    if looks::is_slab(marble) {
        for flag, i in SLAB_FLAGS {
            slabs[marble][i] = scalar(argv, flag, slabs[marble][i], SLAB_LOW[i], SLAB_HIGH[i]);
        }
        g.stone = looks::slab_material(marble, slabs[marble]);
    }
    var shown = pieces3d::put_look(r3d, g, season, material);
    var p = pieces3d::of_look(shown);
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
    let sets = ["Board default", "Plastic", "Jade", "Wood", "Slate", "Marble"];
    let lights = ["game", "left", "right"];
    var direction = pick(argv, "--key", lights, 0);
    var last_direction = -1;
    var piece_material = pick(argv, "--pieces", sets, 0);
    if piece_material == 0 {
        pieces3d::read_flags(argv, p, shown);
    } else {
        p = selected_pieces(shown, piece_material, chosen);
        pieces3d::read_values(argv, p);
    }
    var scattering = pick(argv, "--scatter", ["off", "on"], if p.light_scatter.w + p.dark_scatter.w > 0.0 { 1 } else { 0 }) == 1;
    // The board's scattering starts as the look has it on a desktop (Theme.board_scatter).
    let look_scatter = looks::get(shown).board_scatter;
    var board_scatter = pick(argv, "--board-scatter", ["off", "on"], if look_scatter.x > 0.0 { 1 } else { 0 }) == 1;
    var side = 0;
    var edit_marble = true;
    // The board's scattering: the fraction of its diffuse light that leaves the body,
    // and how far it travels there in world units (a square is 1).
    var board_strength = scalar(argv, "--board-strength", if look_scatter.x > 0.0 { look_scatter.x } else { 0.5 }, 0.0, 1.0);
    var board_radius = scalar(argv, "--board-radius", if look_scatter.x > 0.0 { look_scatter.y } else { 0.2 }, 0.02, 0.6);
    // How deeply the light that travelled takes on the stone's color (0 not at all).
    var board_color = scalar(argv, "--board-color", if look_scatter.x > 0.0 { look_scatter.z } else { 1.0 }, 0.0, 3.0);
    var dark_brightness = scalar(argv, "--brightness", model3d::dark_brightness(p.mineral), 0.25, 2.0);
    var yaw:   f32 = scalar(argv, "--yaw", 0.0, -360.0, 360.0);
    var pitch: f32 = scalar(argv, "--pitch", 0.0, -30.0, 30.0);
    var near:  f32 = scalar(argv, "--near", 1.0, 0.25, 1.5);
    let shot = flag_value(argv, "--shot");
    var print_initial = false;
    for arg in argv { if arg == "--print" { print_initial = true; } }
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
        var slab_changed = false;
        var report = gfx::key_pressed("P") || (frames == 1 && print_initial);
        let flags = ui::WINDOW_BORDER | ui::WINDOW_TITLE | ui::WINDOW_MOVABLE | ui::WINDOW_SCALABLE;
        if ui::begin(c, "Material comparison", ui::rect(10.0, 10.0, PANEL_W, PANEL_H), flags) {
            choice(c, "season", season, SEASONS);
            choice(c, "Board", material, MATERIALS);
            let previous = piece_material;
            choice(c, "Pieces", piece_material, sets);
            choice(c, "Key", direction, lights);
            if piece_material != previous {
                p = selected_pieces(shown, piece_material, chosen);
                scattering = p.light_scatter.w + p.dark_scatter.w > 0.0;
                dark_brightness = model3d::dark_brightness(p.mineral);
            }
            ui::layout_row_dynamic(c, ROW + 4.0, 1);
            ui::checkbox_label(c, "Subsurface scattering (B)", scattering);
            if shown == looks::WINTER {
                choice(c, "Marble", marble, MARBLE_NAMES);
            }
            if shown == looks::SPRING_STONE || shown == looks::SPRING_ELVEN {
                ui::checkbox_label(c, "Board SSS", board_scatter);
                slider(c, "Board strength", board_strength, 0.0, 1.0);
                slider(c, "Board radius", board_radius, 0.02, 0.6);
                slider(c, "Board color", board_color, 0.0, 3.0);
            }
            let slab = shown == looks::WINTER && looks::is_slab(marble);
            if slab {
                ui::layout_row_dynamic(c, ROW, 1);
                ui::checkbox_label(c, SLAB_LABELS[SLAB_FLAGS.len + 1], edit_marble);
            }
            let tune_slab = slab && edit_marble;
            if tune_slab {
                for i in SLAB_FLAGS.len {
                    let before = slabs[marble][i];
                    slider(c, SLAB_LABELS[i], slabs[marble][i], SLAB_LOW[i], SLAB_HIGH[i]);
                    if before != slabs[marble][i] {
                        slabs[marble][i] = round(slabs[marble][i] * 1000.0) / 1000.0;
                        slab_changed = true;
                    }
                }
            } else {
                choice(c, "Tune", side, ["Dark", "Light"]);
                if side == 0 {
                    slider(c, "Scattering", p.dark_scatter.w, 0.0, 2.0);
                    slider(c, "Brightness", dark_brightness, 0.25, 2.0);
                    slider(c, "Texture", p.piece_fig.y, 0.0, 1.0);
                    slider(c, "Roughness", p.dark_piece.w, 0.1, 1.0);
                } else {
                    slider(c, "Scattering", p.light_scatter.w, 0.0, 2.0);
                    slider(c, "Texture", p.piece_fig.x, 0.0, 1.0);
                    slider(c, "Roughness", p.light_piece.w, 0.1, 1.0);
                }
                if piece_material == 3 {
                    slider(c, "Varnish", p.piece_fig.z, 0.0, 1.0);
                    slider(c, "Relief", p.piece_fig.w, 0.0, 3.0);
                }
            }
            ui::layout_row_dynamic(c, ROW + 4.0, 2);
            if ui::button_label(c, "Print (P)") { report = true; }
            if tune_slab {
                if ui::button_label(c, SLAB_LABELS[SLAB_FLAGS.len]) {
                    slabs[marble] = looks::slab_defaults(marble);
                    slab_changed = true;
                }
            } else if ui::button_label(c, "Reset material") { defaults = true; }
        }
        ui::end(c);
        if marble != shown_marble {
            shown_marble = marble;
            render3d::choose(g, -1, marble);
            if looks::is_slab(marble) { g.stone = looks::slab_material(marble, slabs[marble]); }
            g.look = -1;
            shown = pieces3d::put_look(r3d, g, season, material);
            pieces3d::place(r3d, g);
            last_direction = -1;
        }
        else if slab_changed {
            g.stone = looks::slab_material(marble, slabs[marble]);
            render3d::bake_surfaces(r3d, g);
        }
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
            dark_brightness = model3d::dark_brightness(p.mineral);
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
        g.frame.frame_map.z = board_radius;
        g.frame.params.y = board_color;
        g.frame.frame_map.w = if board_scatter && (shown == looks::SPRING_STONE || shown == looks::SPRING_ELVEN) { board_strength } else { 0.0 };
        if report {
            var out: u8[>..] = [];
            format(out, "../build/piece_tune --season ", SEASONS[season], " --material ", MATERIALS[material]);
            if piece_material > 0 { format(out, " --pieces ", sets[piece_material]); }
            if shown == looks::WINTER { format(out, " --marble ", marble); }
            if shown == looks::WINTER && looks::is_slab(marble) {
                for flag, i in SLAB_FLAGS {
                    format(out, " ", flag, " ");
                    pieces3d::num(out, slabs[marble][i]);
                }
            }
            format(out, " --key ", lights[direction], " --scatter ", if scattering { "on" } else { "off" },
                   " --board-scatter ", if board_scatter { "on" } else { "off" }, " --board-strength ");
            pieces3d::num(out, board_strength);
            out.append(" --board-radius ");
            pieces3d::num(out, board_radius);
            out.append(" --board-color ");
            pieces3d::num(out, board_color);
            out.append(" --brightness ");
            pieces3d::num(out, dark_brightness);
            pieces3d::flag4(out, "--light", p.light_piece);
            pieces3d::flag4(out, "--dark", p.dark_piece);
            pieces3d::flag4(out, "--figure", p.piece_fig);
            pieces3d::flag4(out, "--wear", p.piece_wear);
            pieces3d::flag4(out, "--light-scatter", p.light_scatter);
            pieces3d::flag4(out, "--dark-scatter", p.dark_scatter);
            if piece_material == 0 && chosen > 0 { format(out, " --profile ", chosen); }
            if yaw != 0.0 || pitch != 0.0 || near != 1.0 {
                out.append(" --yaw ");
                pieces3d::num(out, yaw);
                out.append(" --pitch ");
                pieces3d::num(out, pitch);
                out.append(" --near ");
                pieces3d::num(out, near);
            }
            print(out);
        }
        pieces3d::put(g, p, dark_brightness);
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
