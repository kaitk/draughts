// Tunes how what each side has taken lies on the table beside the 3D board (task 099): a
// layout (taken3d::STACKS..) and its values on sliders, how many men and kings each side
// has taken, the board's squares, its turn, and the kings' look. Drag to orbit, scroll to
// zoom, R resets the camera, P prints the command that shows the same again.
//
//   goose build -o build/taken_tune tools/taken_tune.goose
//   cd tools && ../build/taken_tune [--layout stacks|row|heap|towers] [--out X] [--along X]
//       [--turn DEG] [--spread X] [--stack N] [--askew X] [--kings X] [--kings-out X] [--seed N]
//       [--white-took MEN,KINGS] [--black-took MEN,KINGS] [--squares 8|10] [--flip]
//       [--king-look crown|stack] [--season autumn|winter|spring|summer]
//       [--material auto|wood|stone|carved] [--table board|flame] [--size 1600x1000]
//       [--distance K] [--height DEG] [--yaw DEG] [--look-at X,Z] [--shot out.png]

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
let KING_LOOKS = ["crown", "stack"];
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
// taken3d::TABLE_LAYOUTS.
fn report(h: taken3d::TableLayout, st: Setup, season: i64, material: i64, take: i64, yaw: f32, pitch: f32, far: f32,
          at: float2) {
    var out: u8[>..] = [];
    format(out, "../build/taken_tune --layout ", taken3d::NAMES[h.kind], " --out ");
    num(out, h.out);
    out.append(" --along ");
    num(out, h.along);
    out.append(" --turn ");
    num(out, h.turn);
    out.append(" --spread ");
    num(out, h.spread);
    format(out, " --stack ", h.stack, " --askew ");
    num(out, h.askew);
    out.append(" --kings ");
    num(out, h.kings_along);
    out.append(" --kings-out ");
    num(out, h.kings_out);
    format(out, " --seed ", h.seed, " --white-took ", st.taken.men[rules::BLACK], ",", st.taken.kings[rules::BLACK],
           " --black-took ", st.taken.men[rules::WHITE], ",", st.taken.kings[rules::WHITE], " --squares ", SQUARES[st.n],
           " --king-look ", KING_LOOKS[st.look], " --season ", SEASONS[season], " --material ", MATERIALS[material],
           " --table ", tables::NAMES[take]);
    if st.flip { out.append(" --flip"); }
    out.append(" --yaw ");
    num(out, yaw);
    out.append(" --height ");
    num(out, pitch);
    out.append(" --distance ");
    num(out, far);
    out.append(" --look-at ");
    num(out, at.x);
    out.append(",");
    num(out, at.y);
    out.append("\n    TableLayout { kind: ");
    out.append(upper(taken3d::NAMES[h.kind]));
    out.append(", out: ");
    num(out, h.out);
    out.append(", along: ");
    num(out, h.along);
    out.append(", turn: ");
    num(out, h.turn);
    out.append(", spread: ");
    num(out, h.spread);
    format(out, ", stack: ", h.stack, ", askew: ");
    num(out, h.askew);
    out.append(", kings_along: ");
    num(out, h.kings_along);
    out.append(", kings_out: ");
    num(out, h.kings_out);
    format(out, ", seed: ", h.seed, " },");
    print(out);
    // Also kept in a file, as a window's tool has no terminal to read.
    if write_file("../build/taken-tune.txt", out[..]) { print("saved in build/taken-tune.txt"); }
}

fn upper(s: const u8[:]) -> u8[>..] {
    var out: u8[>..] = [];
    for ch in s { out.push(if ch >= 'a' && ch <= 'z' { ch - 32 } else { ch }); }
    return out;
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
fn read_taken(argv: u8[:][>..]&, name: const u8[:], t: panel::Taken&, c: i64) {
    let at = flag_value(argv, name);
    guard at > 0 else { return; }
    let a, b, ok = split_once(argv[at], ",");
    let m, okm = parse_int(a);
    let k, okk = parse_int(b);
    guard ok && okm && okk else { abort(str(name, ": MEN,KINGS")); }
    t.men[c] = clamp(m, 0, taken3d::MOST);
    t.kings[c] = clamp(k, 0, taken3d::MOST);
}

fn same(a: taken3d::TableLayout, b: taken3d::TableLayout) -> bool {
    return a.kind == b.kind && a.out == b.out && a.along == b.along && a.turn == b.turn && a.spread == b.spread
           && a.stack == b.stack && a.askew == b.askew && a.kings_along == b.kings_along && a.kings_out == b.kings_out
           && a.seed == b.seed;
}

fn same_setup(a: Setup, b: Setup) -> bool {
    return a.taken.men[0] == b.taken.men[0] && a.taken.men[1] == b.taken.men[1] && a.taken.kings[0] == b.taken.kings[0]
           && a.taken.kings[1] == b.taken.kings[1] && a.flip == b.flip && a.look == b.look;
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
    var layout = pick(argv, "--layout", taken3d::NAMES, taken3d::TOWERS);
    var hp = taken3d::TABLE_LAYOUTS[layout];
    hp.out = number(argv, "--out", hp.out);
    hp.along = number(argv, "--along", hp.along);
    hp.turn = number(argv, "--turn", hp.turn);
    hp.spread = number(argv, "--spread", hp.spread);
    hp.stack = whole(argv, "--stack", hp.stack);
    hp.askew = number(argv, "--askew", hp.askew);
    hp.kings_along = number(argv, "--kings", hp.kings_along);
    hp.kings_out = number(argv, "--kings-out", hp.kings_out);
    hp.seed = whole(argv, "--seed", hp.seed);
    var st = Setup {};
    read_taken(argv, "--white-took", st.taken, rules::BLACK);
    read_taken(argv, "--black-took", st.taken, rules::WHITE);
    st.n = pick(argv, "--squares", SQUARES, 0);
    st.look = pick(argv, "--king-look", KING_LOOKS, 0);
    st.flip = has(argv, "--flip");
    taken3d::table_layout = hp;
    guard gfx::open("Draughts: the taken pieces' tuning", w, h, gfx::WINDOW_RESIZABLE) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    var g = default<render3d::Gpu>();
    var r3d = default<render3d::Own>();
    render3d::setup(r3d, g, render3d::SAMPLES, render3d::SHADOW_16);
    render3d::set_aa(r3d, g, render3d::AA);
    render3d::choose(g, -1, looks::MARBLE, looks::SPRING_LOOK);
    g.table = true;
    g.table_spec = tables::get(take);
    put_look(r3d, g, season, material, st);

    let scale = max(gfx::screen_size().x as f32 / w, 1.0);
    let c = ui::create(13.0, scale);
    guard c.id != 0 else { abort(str("ui: ", ui::error())); }
    var shown_season = season;
    var shown_material = material;
    var shown_take = take;
    var shown_layout = layout;
    var shown_n = st.n;
    var shown = hp;
    var shown_st = st;
    var flip:  i64 = if st.flip { 1 } else { 0 };
    var yaw:   f32 = number(argv, "--yaw", 0.0);
    var pitch: f32 = number(argv, "--height", view3d::PITCH);
    var far:   f32 = number(argv, "--distance", 1.3);
    // The point the camera turns round, x and z on the field's plane: the board's middle,
    // or a pile's for a close look.
    var at = float2 { view3d::TARGET.x, view3d::TARGET.z };
    let la = flag_value(argv, "--look-at");
    if la > 0 {
        let a, b, ok = split_once(argv[la], ",");
        let x, okx = parse_flt(a);
        let z, okz = parse_flt(b);
        guard ok && okx && okz else { abort("--look-at: X,Z"); }
        at = float2 { x as f32, z as f32 };
    }
    let shot = flag_value(argv, "--shot");
    var frames = 0;
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
        if ui::begin(c, "Taken pieces", ui::rect(10.0, 10.0, PANEL_W, panel_h), flags) {
            choice(c, "Layout", layout, taken3d::NAMES);
            heading(c, "Layout's values");
            slider(c, "Out from board", hp.out, 0.3, 4.0);
            slider(c, "Along its side", hp.along, -4.0, 5.0);
            slider(c, "Turn", hp.turn, -45.0, 45.0);
            slider(c, "Spread", hp.spread, 0.9, 1.6);
            count(c, "Most a stack", hp.stack, 1, 8);
            slider(c, "Askew", hp.askew, 0.0, 0.6);
            slider(c, "Kings along", hp.kings_along, -6.0, 3.0);
            slider(c, "Kings out", hp.kings_out, -2.0, 3.0);
            count(c, "Seed", hp.seed, 0, 40);
            heading(c, "What was taken");
            count(c, "White took men", st.taken.men[rules::BLACK], 0, taken3d::MOST);
            count(c, "White took kings", st.taken.kings[rules::BLACK], 0, taken3d::MOST);
            count(c, "Black took men", st.taken.men[rules::WHITE], 0, taken3d::MOST);
            count(c, "Black took kings", st.taken.kings[rules::WHITE], 0, taken3d::MOST);
            choice(c, "King look", st.look, KING_LOOKS);
            choice(c, "Squares", st.n, SQUARES);
            choice(c, "Board turned", flip, ["no", "yes"]);
            heading(c, "Scene");
            choice(c, "Season", season, SEASONS);
            choice(c, "Board", material, MATERIALS);
            choice(c, "Table", take, tables::NAMES);
            heading(c, "View (drag, scroll, R)");
            slider(c, "Distance", far, 0.4, 4.0);
            slider(c, "Height", pitch, 10.0, 89.0);
            slider(c, "Round", yaw, -180.0, 180.0);
            slider(c, "Look at x", at.x, -9.0, 9.0);
            slider(c, "Look at z", at.y, -6.0, 6.0);
            ui::layout_row_dynamic(c, ROW + 4.0, 2);
            if ui::button_label(c, "Print (P)") { print_it = true; }
            if ui::button_label(c, "Reset layout") { shown_layout = -1; }
        }
        ui::end(c);
        st.flip = flip == 1;
        if layout != shown_layout {
            shown_layout = layout;
            hp = taken3d::TABLE_LAYOUTS[layout];
        }
        hp.kind = layout;
        if season != shown_season || material != shown_material || take != shown_take || st.n != shown_n {
            shown_season = season;
            shown_material = material;
            shown_take = take;
            shown_n = st.n;
            g.table_spec = tables::get(take);
            render3d::tune_table(r3d, g, g.table_spec);
            taken3d::table_layout = hp;
            put_look(r3d, g, season, material, st);
            shown = hp;
            shown_st = st;
        }
        if !same(hp, shown) || !same_setup(st, shown_st) {
            taken3d::table_layout = hp;
            place(r3d, g, st);
            shown = hp;
            shown_st = st;
        }
        if print_it { report(hp, st, season, material, take, yaw, pitch, far, at); }
        if gfx::key_pressed("R") {
            yaw = 0.0;
            pitch = view3d::PITCH;
            far = 1.3;
            at = float2 { view3d::TARGET.x, view3d::TARGET.z };
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
        let target = float3 { at.x, view3d::TARGET.y, at.y };
        let eye = target + float3 { sin(b) * cos(a), sin(a), cos(b) * cos(a) } * (view3d::DISTANCE * far);
        let proj = gfx::perspective(view3d::FOV * PI / 180.0, size.x as f32 / size.y, 1.0, 120.0);
        render3d::draw(r3d, g, gfx::mul(proj, gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 })), eye,
                       gfx::screen(), size);
        if shot < 0 { ui::render(c); }
    }
}
