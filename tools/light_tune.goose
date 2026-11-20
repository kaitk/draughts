// Tunes the light of the room the 3D board stands in on its table (task 104): a room's take
// (rooms::LIBRARY..) and its values on sliders: the sun's direction, height, color and
// strength, how dark its shadow is, the window's sky, the walls, and the window's pattern
// with its bars, curtain, and the trees' leaves. Drag to orbit, scroll to zoom, R resets
// the camera, W switches the pattern (its leaves swaying in the wind), T the leaves between
// the tree's baked shadow and the noise, K the wind's kind (rooms::WIND_KINDS: sines,
// noise, still, branches), D the dust in the sunbeam, O the room round the table (its
// herringbone oak floor and the panelled wall facing the window, model3d::surfaces), V
// the view of the room from the window's side, P prints the room as Goose (and saves it in
// build/light-tune.txt).
//
//   scripts/mac.py tools/light_tune.goose
//   cd tools && ../build/light_tune [--room library|hall-snow|hall-sun|hall-spring|evening]
//       [--season autumn|winter|spring|summer] [--material auto|wood|stone|carved]
//       [--table board|flame] [--window on|off] [--leaves tree|noise|both] [--seed N] [--wind-time S]
//       [--wind-kind sines|noise|still|branches]
//       [--tree|--crown|--foliage|--trees|--wind X,Y,Z,W (rooms::Room's tree, crown, foliage, leaves, wind)]
//       [--wall|--panes|--opening X,Y,Z,W (the window's)] [--key|--fill|--walls|--pattern|--bounce X,Y,Z,W]
//       [--dump-map out.pgm] [--azimuth DEG] [--sun-height DEG]
//       [--dust on|off] [--motes N] [--mote-size PX] [--mote-blur PX] [--mote-bright K] [--exposure K]
//       [--room-surfaces on|off] [--wall-away UNITS] [--room-exposure K] [--eye X,Y,Z --at X,Y,Z (a camera of its own)]
//       [--wallpaper-tile M (the wall a tile of the wallpaper covers, metres)]
//       [--view room] [--dump-oak PREFIX (the oak's fields as PREFIX-floor.ppm, -wall.ppm)]
//       [--size 1600x1000] [--distance K] [--height DEG] [--yaw DEG] [--shot out.png]

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

let PANEL_W: f32 = 340.0;
let ROW:     f32 = 20.0;
// looks::AUTUMN.. and MATERIAL_AUTO.. in this order.
let SEASONS = ["autumn", "winter", "spring", "summer"];
let MATERIALS = ["auto", "wood", "stone", "carved"];
let SQUARES = ["8", "10"];

// A mid-game position, dark on the far rows: (row, col, dark), row 0 the far side.
let PIECES: i32[3][12] = [
    [0, 1, 1], [0, 5, 1], [1, 2, 1], [1, 6, 1], [2, 3, 1], [3, 4, 1],
    [4, 1, 0], [5, 2, 0], [5, 6, 0], [6, 3, 0], [7, 0, 0], [7, 4, 0],
];

// What the tuner shows besides the layout.
struct Setup {
    taken: panel::Taken = panel::Taken { men: [9, 7], kings: [1, 2] },
    n:     i64          = 0,    // SQUARES's
    flip:  bool         = false,
    look:  i64          = 0,    // KING_LOOKS's
}

fn squares_of(st: Setup) -> i64 { if st.n == 1 { 10 } else { 8 } }

// The board's pieces and the table's, put on the GPU.
fn place(r3d: render3d::Own&, g: render3d::Gpu&, st: Setup) {
    var s = view3d::Scene {};
    var squares: float4[200] = [float4_0; 200];
    var marks:   float4[100] = [float4 { 0.0, 0.0, 0.0, -1.0 }; 100];
    var lit:     float4[100] = [float4_0; 100];
    var fades:   f32[1]      = [0.0];
    let n = squares_of(st);
    let u = view3d::unit(n);
    for p, i in PIECES {
        let x = (p[1] + 0.5) * u - view3d::FIELD;
        let z = (p[0] + 0.5) * u - view3d::FIELD;
        let dark: f32 = if (p[2] == 1) != st.flip { 1.0 } else { 0.0 };
        s.inst.push(float4 { x, 0.0, z, u });
        s.inst.push(float4 { dark, 0.0, 0.0, i });
        squares[2 * (p[0] * n + p[1])] = float4 { view3d::HEIGHT * u, 0.0, view3d::RADIUS * u, 1.0 };
        squares[2 * (p[0] * n + p[1]) + 1] = float4 { x, z, 0.0, 0.0 };
    }
    taken3d::lay_counts(s, st.taken, n, st.flip, if st.look == 1 { board::STACK } else { board::CROWN });
    render3d::place(r3d, g, s.inst[..s.inst.len], fades[..0], squares[..], marks[..], lit[..], float4_0, 0.0, true);
    render3d::table_discs(g, s.discs[..], s.disc_r);
}

// The season's look in the material, its wood and finish as the app picks them
// (draw3d::choose_look), baked with the table.
fn put_look(r3d: render3d::Own&, g: render3d::Gpu&, season: i64, material: i64, st: Setup) {
    let look = looks::of(season, material);
    if look == looks::SPRING { g.spring = 0; }
    let shown = looks::shown(look, g.spring);
    let own = looks::wood_for(shown);
    render3d::choose(g, if own >= 0 { own } else { model3d::WOOD_MODEL }, -1);
    g.finish = looks::finish_for(shown, g.wood);
    g.look = -1;
    render3d::apply(r3d, g, look, squares_of(st));
    place(r3d, g, st);
}

fn num(out: u8[>..]&, v: f32) {
    let k = floor(v * 1000.0 + 0.5) / 1000.0;
    format(out, k);
}

// The command that shows the same again, and the layout as a Goose literal for

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

fn count(c: ui::Context, name: const u8[:], v: i64&, lo: i64, hi: i64) {
    let ratios: f32[2] = [0.45, 0.55];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    ui::label(c, str(name, " ", v), ui::TEXT_LEFT);
    ui::slider_int(c, lo, v, hi, 1);
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

fn has(argv: u8[:][>..]&, name: const u8[:]) -> bool {
    for a in argv { if a == name { return true; } }
    return false;
}

fn pick(argv: u8[:][>..]&, name: const u8[:], names: const u8[:][], otherwise: i64) -> i64 {
    let at = flag_value(argv, name);
    if at < 0 { return otherwise; }
    for n, i in names { if argv[at] == n { return i; } }
    abort(str(name, ": no ", argv[at]));
    return otherwise;
}

// The flag's four numbers, `x,y,z,w`, or `otherwise`.
fn four(argv: u8[:][>..]&, name: const u8[:], otherwise: float4) -> float4 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    var v:    f32[4]      = [otherwise.x, otherwise.y, otherwise.z, otherwise.w];
    var rest: const u8[:] = argv[at];
    for i in 4 {
        let part, after, more = split_once(rest, ",");
        let x, ok = parse_flt(part);
        guard ok else { abort(str(name, ": four numbers, x,y,z,w")); }
        v[i] = x as f32;
        guard more else { break; }
        rest = after;
    }
    return float4 { v[0], v[1], v[2], v[3] };
}

// The flag's number, or `otherwise`.
fn number(argv: u8[:][>..]&, name: const u8[:], otherwise: f32) -> f32 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    let v, ok = parse_flt(argv[at]);
    guard ok else { abort(str(name, ": a number")); }
    return v as f32;
}

fn whole(argv: u8[:][>..]&, name: const u8[:], otherwise: i64) -> i64 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    let v, ok = parse_int(argv[at]);
    guard ok else { abort(str(name, ": a whole number")); }
    return v;
}

// --white-took MEN,KINGS: the men and kings of color c taken, into t.

fn room_line(out: u8[>..]&, name: const u8[:], v: float4) {
    out.append("    ");
    out.append(name);
    out.append(": float4 { ");
    num(out, v.x);
    out.append(", ");
    num(out, v.y);
    out.append(", ");
    num(out, v.z);
    out.append(", ");
    num(out, v.w);
    out.append(" },\n");
}

// The room as a Goose literal for rooms.goose.
fn report(r: rooms::Room, take: i64) {
    var out: u8[>..] = [];
    format(out, "// ", rooms::NAMES[take], ", the wind's kind ", rooms::WIND_KINDS[render3d::wind_kind], "\nRoom {\n");
    room_line(out, "key:       ", r.key);
    room_line(out, "key_color: ", r.key_color);
    room_line(out, "fill:      ", r.fill);
    room_line(out, "fill_color:", r.fill_color);
    room_line(out, "walls:     ", r.walls);
    room_line(out, "ceiling:   ", r.ceiling);
    room_line(out, "floor:     ", r.floor);
    room_line(out, "lamp:      ", r.lamp);
    room_line(out, "lamp_color:", r.lamp_color);
    out.append("    exposure:   ");
    num(out, r.exposure);
    out.append(",\n    tree_blur:  ");
    num(out, r.tree_blur);
    out.append(",\n    crown_blur: ");
    num(out, r.crown_blur);
    out.append(",\n    crown_fill: ");
    num(out, r.crown_fill);
    format(out, ",\n    species:    ", r.species, ", // ", trees::SPECIES_NAMES[r.species], "\n");
    room_line(out, "pattern:   ", r.pattern);
    room_line(out, "window:    ", r.window);
    room_line(out, "panes:     ", r.panes);
    room_line(out, "opening:   ", r.opening);
    room_line(out, "leaves:    ", r.leaves);
    room_line(out, "twigs:     ", r.twigs);
    room_line(out, "wind:      ", r.wind);
    room_line(out, "tree:      ", r.tree);
    room_line(out, "crown:     ", r.crown);
    room_line(out, "foliage:   ", r.foliage);
    room_line(out, "bounce:    ", r.bounce);
    out.append("    room_exposure: ");
    num(out, r.room_exposure);
    out.append(",\n};");
    print(out);
    // Also kept in a file, as a window's tool has no terminal to read.
    if write_file("../build/light-tune.txt", out[..]) { print("saved in build/light-tune.txt"); }
}

// A square texture's first level as a binary PPM, its alpha left out.
fn dump_rgb(t: gfx::Texture, side: i64, path: const u8[:]) {
    let px = gfx::read_pixels(t);
    var out: u8[>..] = [];
    format(out, "P6\n", side, " ", side, "\n255\n");
    for i in side * side {
        out.push(px[4 * i]);
        out.push(px[4 * i + 1]);
        out.push(px[4 * i + 2]);
    }
    guard write_file(path, out[..]) else { abort(str("could not write ", path)); }
}

fn color_sliders(c: ui::Context, name: const u8[:], v: float4&) {
    slider(c, str(name, " r"), v.x, 0.0, 1.0);
    slider(c, str(name, " g"), v.y, 0.0, 1.0);
    slider(c, str(name, " b"), v.z, 0.0, 1.0);
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
    var take = pick(argv, "--table", tables::NAMES, tables::FLAME);
    var room_take = pick(argv, "--room", rooms::NAMES, rooms::for_season(season));
    var pattern: i64 = if flag_value(argv, "--window") > 0 && argv[flag_value(argv, "--window")] == "off" { 0 } else { 1 };
    var st = Setup {};
    taken3d::table_layout = taken3d::TABLE_LAYOUTS[taken3d::TOWERS];
    guard gfx::open("Draughts: the room's light", w, h, gfx::WINDOW_RESIZABLE) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    var g = default<render3d::Gpu>();
    var r3d = default<render3d::Own>();
    render3d::setup(r3d, g, render3d::SAMPLES, render3d::SHADOW_16);
    render3d::set_aa(r3d, g, render3d::AA);
    render3d::choose(g, -1, looks::MARBLE, looks::SPRING_LOOK);
    render3d::scatter_allowed = true;
    g.table = true;
    g.table_spec = tables::get(take);
    var room = rooms::get(room_take);
    room.key.x = number(argv, "--azimuth", room.key.x);
    room.key.y = number(argv, "--sun-height", room.key.y);
    let shade_at = flag_value(argv, "--leaves");
    if shade_at > 0 { room.tree.x = if argv[shade_at] == "noise" { 0.0 } else if argv[shade_at] == "both" { 2.0 } else { 1.0 }; }
    room.tree.y = number(argv, "--seed", room.tree.y);
    room.tree = four(argv, "--tree", room.tree);
    room.crown = four(argv, "--crown", room.crown);
    room.foliage = four(argv, "--foliage", room.foliage);
    room.leaves = four(argv, "--trees", room.leaves);
    room.window = four(argv, "--wall", room.window);
    room.panes = four(argv, "--panes", room.panes);
    room.opening = four(argv, "--opening", room.opening);
    room.wind = four(argv, "--wind", room.wind);
    room.key = four(argv, "--key", room.key);
    room.fill = four(argv, "--fill", room.fill);
    room.walls = four(argv, "--walls", room.walls);
    room.pattern = four(argv, "--pattern", room.pattern);
    room.bounce = four(argv, "--bounce", room.bounce);
    room.room_exposure = number(argv, "--room-exposure", room.room_exposure);
    room.tree_blur = number(argv, "--tree-blur", room.tree_blur);
    room.exposure = number(argv, "--exposure", room.exposure);
    var motes = whole(argv, "--motes", 500);
    var dust_on = flag_value(argv, "--dust") > 0 && argv[flag_value(argv, "--dust")] == "on";
    render3d::dust.size = number(argv, "--mote-size", render3d::dust.size);
    render3d::dust.blur = number(argv, "--mote-blur", render3d::dust.blur);
    render3d::dust.bright = number(argv, "--mote-bright", render3d::dust.bright);
    render3d::wind_time = number(argv, "--wind-time", 0.0);
    render3d::wind_kind = pick(argv, "--wind-kind", rooms::WIND_KINDS, rooms::WIND_NOISE);
    g.room = room;
    g.room_tuned = true;
    // --dump-map out.pgm: the tree's map as the sun sees it, all layers' light multiplied.
    let dump = flag_value(argv, "--dump-map");
    if dump > 0 {
        var t = trees::Tree { .. };
        let sp = rooms::tree_spec(room);
        let v = rooms::tree_view(room);
        trees::grow(t, sp, v);
        var map: u8[>..] = [];
        trees::draw_map(t, sp, v, map);
        var out: u8[>..] = [];
        format(out, "P5\n", trees::SIDE, " ", trees::SIDE, "\n255\n");
        for i in trees::SIDE * trees::SIDE {
            let o = i * 4;
            let k = (map[o] as i64) * (map[o + 1] as i64) / 255 * (map[o + 2] as i64) / 255 * (map[o + 3] as i64) / 255;
            out.push(k as u8);
        }
        guard write_file(argv[dump], out[..]) else { abort("could not write the map"); }
        print("map span ", v.span, " middle ", v.middle.x, ",", v.middle.y);
    }
    render3d::window_pattern = pattern == 1;
    var room_on = flag_value(argv, "--room-surfaces") > 0 && argv[flag_value(argv, "--room-surfaces")] == "on";
    let away = number(argv, "--wall-away", surfaces::WALL_AWAY);
    render3d::show_room(g, room_on, away);
    g.paper_tile = number(argv, "--wallpaper-tile", surfaces::PAPER_TILE / surfaces::METRE) * surfaces::METRE;
    put_look(r3d, g, season, material, st);

    let scale = max(gfx::screen_size().x as f32 / w, 1.0);
    let c = ui::create(13.0, scale);
    guard c.id != 0 else { abort(str("ui: ", ui::error())); }
    var shown_season = season;
    var shown_material = material;
    var shown_take = take;
    var shown_room = room_take;
    var yaw:   f32 = number(argv, "--yaw", 0.0);
    var pitch: f32 = number(argv, "--height", view3d::PITCH);
    var far:   f32 = number(argv, "--distance", 1.3);
    var at = float2 { view3d::TARGET.x, view3d::TARGET.z };
    // A camera of its own (--eye, --at), or the room seen from the window's side (V).
    let own_eye = flag_value(argv, "--eye") > 0;
    var eye_at = four(argv, "--eye", float4_0);
    var look_at = four(argv, "--at", float4 { view3d::TARGET.x, view3d::TARGET.y, view3d::TARGET.z, 0.0 });
    var room_view = has(argv, "--view") && argv[flag_value(argv, "--view")] == "room";
    let shot = flag_value(argv, "--shot");
    var frames = 0;
    while gfx::frame() {
        frames++;
        if shot > 0 && frames == 6 {
            guard gfx::screenshot(argv[shot]) else { abort(str("could not save ", argv[shot])); }
            if g.tree_ms > 0.0 { print("the tree baked in ", g.tree_ms, " ms"); }
            let oak = flag_value(argv, "--dump-oak");
            if oak > 0 && g.room_baked {
                dump_rgb(g.floor_albedo, g.room_side, str(argv[oak], "-floor.ppm"));
                dump_rgb(g.wall_albedo, g.room_side, str(argv[oak], "-wall.ppm"));
                dump_rgb(g.floor_normal, g.room_side, str(argv[oak], "-floor-normal.ppm"));
            }
            if g.room_ms > 0.0 {
                print("the room's oak baked in ", g.room_ms, " ms, ", g.room_side, " texels a side, ",
                      render3d::room_bytes(g) / 1048576, " MiB");
            }
            break;
        }
        ui::input_from_gfx(c);
        var print_it = gfx::key_pressed("P");
        if gfx::key_pressed("W") { pattern = 1 - pattern; }
        if gfx::key_pressed("T") { room.tree.x = (room.tree.x as i64 + 1) % 3; }
        if gfx::key_pressed("D") { dust_on = !dust_on; }
        if gfx::key_pressed("O") { room_on = !room_on; }
        if gfx::key_pressed("V") { room_view = !room_view; }
        if gfx::key_pressed("K") { render3d::wind_kind = (render3d::wind_kind + 1) % rooms::WIND_KINDS.len; }
        let flags = ui::WINDOW_BORDER | ui::WINDOW_TITLE | ui::WINDOW_MOVABLE | ui::WINDOW_SCALABLE;
        let panel_h = gfx::screen_size().y / scale - 20.0;
        if ui::begin(c, "Room light", ui::rect(10.0, 10.0, PANEL_W, panel_h), flags) {
            heading(c, "Scene");
            choice(c, "Room", room_take, rooms::NAMES);
            choice(c, "Season", season, SEASONS);
            choice(c, "Board", material, MATERIALS);
            choice(c, "Table", take, tables::NAMES);
            choice(c, "Pattern (W)", pattern, ["off", "on"]);
            var shade = clamp(room.tree.x as i64, 0, 2);
            choice(c, "Leaves by (T)", shade, ["noise", "tree", "both"]);
            room.tree.x = shade;
            heading(c, "The tree");
            choice(c, "Kind", room.species, trees::SPECIES_NAMES);
            var seed = room.tree.y as i64;
            count(c, "Seed", seed, 0, 99);
            room.tree.y = seed;
            slider(c, "Leafy", room.tree.w, 0.0, 2.0);
            slider(c, "Leaf long", room.foliage.x, 0.1, 4.0);
            slider(c, "Leaf wide", room.foliage.y, 0.2, 1.2);
            slider(c, "Leaf lets", room.foliage.z, 0.0, 1.0);
            slider(c, "Tree blur", room.tree_blur, 0.1, 3.0);
            slider(c, "Trunk along", room.crown.x, -100.0, 100.0);
            slider(c, "Trunk foot", room.crown.y, -400.0, 0.0);
            slider(c, "Trunk high", room.tree.z, 40.0, 600.0);
            slider(c, "Trunk away", room.foliage.w, 5.0, 300.0);
            slider(c, "Crooked", room.crown.z, 0.0, 1.5);
            slider(c, "Twigs hang", room.crown.w, 0.0, 1.0);
            if g.tree_ms > 0.0 {
                ui::layout_row_dynamic(c, ROW, 1);
                ui::label(c, str("baked in ", floor(g.tree_ms + 0.5) as i64, " ms"), ui::TEXT_LEFT);
            }
            heading(c, "Wind");
            choice(c, "Kind (K)", render3d::wind_kind, rooms::WIND_KINDS);
            slider(c, "Wind", room.wind.x, 0.0, 0.3);
            slider(c, "Wind speed", room.wind.y, 0.0, 4.0);
            slider(c, "Leaves sway", room.wind.z, 0.0, 8.0);
            slider(c, "Ruffle", room.wind.w, 0.0, 2.0);
            heading(c, "The room (O, V)");
            var shown_surfaces: i64 = if room_on { 1 } else { 0 };
            choice(c, "Floor, wall", shown_surfaces, ["off", "on"]);
            room_on = shown_surfaces == 1;
            var shown_view: i64 = if room_view { 1 } else { 0 };
            choice(c, "View", shown_view, ["board", "room"]);
            room_view = shown_view == 1;
            slider(c, "Room's exposure", room.room_exposure, 0.5, 4.0);
            slider(c, "Bounce", room.bounce.w, 0.0, 2.0);
            color_sliders(c, "Bounce", room.bounce);
            if g.room_ms > 0.0 {
                ui::layout_row_dynamic(c, ROW, 1);
                ui::label(c, str("baked in ", floor(g.room_ms + 0.5) as i64, " ms, ", render3d::room_bytes(g) / 1048576, " MiB"),
                          ui::TEXT_LEFT);
            }
            heading(c, "Dust in the sunbeam (D)");
            var shown_dust: i64 = if dust_on { 1 } else { 0 };
            choice(c, "Dust", shown_dust, ["off", "on"]);
            dust_on = shown_dust == 1;
            count(c, "Motes", motes, 0, render3d::MAX_MOTES);
            slider(c, "Mote size", render3d::dust.size, 0.3, 4.0);
            slider(c, "Lens blur", render3d::dust.blur, 0.0, 60.0);
            slider(c, "Bright", render3d::dust.bright, 0.0, 4.0);
            slider(c, "Thin out", render3d::dust.thin, 0.0, 2.0);
            slider(c, "Toward sun", render3d::dust.ahead, 0.0, 0.9);
            slider(c, "Rise", render3d::dust.rise, 0.0, 0.4);
            slider(c, "Wander", render3d::dust.reach, 0.0, 2.0);
            heading(c, "Sun");
            slider(c, "Round", room.key.x, -30.0, 150.0);
            slider(c, "Height", room.key.y, 3.0, 70.0);
            slider(c, "Strength", room.key.z, 0.0, 12.0);
            slider(c, "Shadow", room.key.w, 0.0, 1.0);
            heading(c, "Window");
            slider(c, "Shade", room.pattern.x, 0.0, 1.0);
            slider(c, "Softness", room.pattern.y, 0.0, 0.05);
            slider(c, "Wall away", room.window.x, 10.0, 80.0);
            slider(c, "Wall turn", room.window.y, -60.0, 60.0);
            slider(c, "Sill", room.window.z, -30.0, 30.0);
            slider(c, "Sideways", room.window.w, -30.0, 30.0);
            slider(c, "Pane wide", room.panes.x, 2.0, 20.0);
            slider(c, "Pane high", room.panes.y, 2.0, 20.0);
            slider(c, "Bar", room.panes.z, 0.0, 3.0);
            slider(c, "Panes across", room.opening.x, 1.0, 4.0);
            slider(c, "Panes up", room.opening.y, 1.0, 6.0);
            slider(c, "Curtain in", room.opening.z, 0.0, 20.0);
            slider(c, "Lace lets", room.opening.w, 0.0, 1.0);
            heading(c, "Noise leaves (noise, both)");
            slider(c, "Leaves", room.leaves.x, 0.0, 1.0);
            slider(c, "Leaf size", room.leaves.y, 0.02, 1.0);
            slider(c, "Trees away", room.leaves.z, 0.0, 400.0);
            slider(c, "Leaf blur", room.leaves.w, 0.0, 2.0);
            slider(c, "Single leaves", room.twigs.x, 0.0, 12.0);
            slider(c, "Leaf gaps few", room.twigs.y, 0.2, 0.9);
            slider(c, "Fleck blur", room.twigs.z, 0.005, 0.3);
            slider(c, "In the open", room.twigs.w, 0.0, 1.0);
            slider(c, "Crown blur", room.crown_blur, 0.0, 6.0);
            slider(c, "Crown fill", room.crown_fill, 0.0, 10.0);
            heading(c, "Light in detail (the room's profile)");
            color_sliders(c, "Sun", room.key_color);
            slider(c, "Exposure", room.exposure, 0.5, 2.0);
            slider(c, "Sky round", room.fill.x, -30.0, 150.0);
            slider(c, "Sky height", room.fill.y, 0.0, 80.0);
            slider(c, "Sky strength", room.fill.z, 0.0, 3.0);
            slider(c, "Sky broad", room.fill.w, 0.0, 1.0);
            color_sliders(c, "Sky", room.fill_color);
            slider(c, "Walls", room.walls.w, 0.0, 1.0);
            color_sliders(c, "Walls", room.walls);
            slider(c, "Ceiling", room.ceiling.w, 0.0, 1.0);
            slider(c, "Floor", room.floor.w, 0.0, 1.0);
            slider(c, "Lamp", room.lamp.z, 0.0, 1.0);
            heading(c, "View (drag, scroll, R)");
            slider(c, "Distance", far, 0.4, 4.0);
            slider(c, "Height", pitch, 10.0, 89.0);
            slider(c, "Round", yaw, -180.0, 180.0);
            ui::layout_row_dynamic(c, ROW + 4.0, 2);
            if ui::button_label(c, "Print (P)") { print_it = true; }
            if ui::button_label(c, "Reset room") { shown_room = -1; }
        }
        ui::end(c);
        if room_take != shown_room {
            shown_room = room_take;
            room = rooms::get(room_take);
        }
        if season != shown_season || material != shown_material || take != shown_take {
            if season != shown_season {
                room_take = rooms::for_season(season);
                shown_room = room_take;
                room = rooms::get(room_take);
            }
            shown_season = season;
            shown_material = material;
            shown_take = take;
            g.table_spec = tables::get(take);
            render3d::tune_table(r3d, g, g.table_spec);
            g.room = room;
            put_look(r3d, g, season, material, st);
        }
        // Cheap enough to do each frame: the harmonics on the CPU and the shadow map.
        g.room = room;
        render3d::window_pattern = pattern == 1;
        render3d::show_room(g, room_on, away);
        // A shot is taken at --wind-time itself.
        if shot < 0 { render3d::wind_time += gfx::delta_time() as f32; }
        render3d::put_room(g);
        if print_it { report(room, room_take); }
        if gfx::key_pressed("R") {
            yaw = 0.0;
            pitch = view3d::PITCH;
            far = 1.3;
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
        var target = float3 { at.x, view3d::TARGET.y, at.y };
        var eye = target + float3 { sin(b) * cos(a), sin(a), cos(b) * cos(a) } * (view3d::DISTANCE * far);
        var fov = view3d::FOV;
        if own_eye {
            eye = float3 { eye_at.x, eye_at.y, eye_at.z };
            target = float3 { look_at.x, look_at.y, look_at.z };
        } else if room_view {
            // From beside the window, a person's eyes high, over the table to the wall.
            let f = g.room_frame;
            let e2 = f.along * -15.0 + f.into * -30.0;
            let t2 = f.along * 12.0 + f.into * (0.7 * away);
            eye = float3 { e2.x, 22.0, e2.y };
            target = float3 { t2.x, -14.0, t2.y };
            fov = 50.0;
        }
        render3d::dust.count = if dust_on { motes } else { 0 };
        render3d::dust.focus = length(eye - target);
        // The near plane farther with the room, so 16-bit depth keeps its panels apart.
        let near: f32 = if room_on { clamp(0.2 * length(eye - target), 1.0, 12.0) } else { 1.0 };
        let proj = gfx::perspective(fov * PI / 180.0, size.x as f32 / size.y, near, if room_on { 900.0 } else { 120.0 });
        render3d::draw(r3d, g, gfx::mul(proj, gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 })), eye,
                       gfx::screen(), size);
        if shot < 0 { ui::render(c); }
    }
}
