// Tunes the light of the room the 3D board stands in on its table (task 104): a room's take
// (rooms::LIBRARY..) and its values on sliders: the sun's direction, height, color and
// strength, how dark its shadow is, the window's sky, the walls, and the window's pattern
// with its bars, curtain, and the trees' leaves. Drag to orbit, scroll to zoom, R resets
// the camera, W switches the pattern (its leaves swaying in the wind), T the leaves between
// the tree's baked shadow and the noise, K the wind's kind (rooms::WIND_KINDS: sines,
// noise, still, branches), D the dust in the sunbeam, O the room round the table (the
// library's shell, room_shell::LIBRARY: its walls, wainscot, windows, doors, cornice and
// ceiling; S switches it for the panelled wall facing the window alone, model3d::surfaces,
// as it was), V the views in turn (the board, then the room's: room, window, hall, stove,
// VIEWS), U the view out of the shell's windows (model3d::view_out) or the plain sky behind
// them as before, B the bookcases' books (model3d::books) in or out, L the wallpaper's tile round a real paper's
// 0.65 m, the default 0.9 m and style-01's 1.4 m, F the frame counter in the corner (frames a
// second, the frame's time and its worst over half a second, the time in the loop before
// the submit; SDL's GPU has no timer queries, so no GPU time), G waits for the GPU each
// frame so the loop's time is the CPU's and the GPU's, P prints the room as Goose and the
// flags that show the same again (and saves them in build/light-tune.txt). Tab walks round
// the room (Walk: WASD and the mouse, Esc back to the panel); the camera stays where the
// walk left it, and P prints it as --plan-eye and --plan-at, till R or V.
//
// The panel is in sections that open and close (SECTIONS, kept for the session; Keys
// lists the keys). A drag that starts on the panel holds the tree's and the probes' bakes
// till it is let go, so a slider bakes once, not each step.
//
//   scripts/mac.py tools/light_tune.goose
//   cd tools && ../build/light_tune [--room library|hall-snow|hall-sun|hall-spring|evening]
//       [--season autumn|winter|spring|summer] [--material auto|wood|stone|carved]
//       [--table board|flame] [--table-top 0.95|1.05|0.80 (the top across, metres)] [--window on|off] [--leaves tree|noise|both] [--seed N] [--wind-time S]
//       [--wind-kind sines|noise|still|branches]
//       [--gust X,Y,Z,W | --gust-strength K --gust-length S --gust-every S --gust-reach K (rooms::Room's gust)]
//       [--tree|--crown|--foliage|--trees|--wind X,Y,Z,W (rooms::Room's tree, crown, foliage, leaves, wind)]
//       [--wall|--panes|--opening X,Y,Z,W (the window's)] [--key|--fill|--walls|--pattern|--bounce X,Y,Z,W]
//       [--dump-map out.pgm] [--azimuth DEG] [--sun-height DEG]
//       [--dust on|off] [--motes N] [--mote-size PX] [--mote-blur PX] [--mote-bright K] [--exposure K]
//       [--room-surfaces on|off] [--shell on|off] [--wall-away UNITS] [--room-exposure K]
//       [--outside on|off] [--outside-exposure K (rooms::Room's outside)]
//       [--eye X,Y,Z --at X,Y,Z (a camera of its own, world units)]
//       [--plan-eye X,Y,H --plan-at X,Y,H (one in the room's plan, metres: x along the window wall
//       from the stove's end, y from the hall wall, H up from the floor)] [--fov DEG]
//       [--wallpaper-tile M (the wall a tile of the wallpaper covers, metres)]
//       [--oak-tint L,S | --ceiling-tint L,S (the panelling oak's, the ceiling's lightness and saturation, 1,1 as made)]
//       [--books on|off] [--book-fade K (how much of the books' fade shows, 1 as made)]
//       [--sections all|NAME,NAME.. (SECTION_NAMES open at the start)] [--shot-panel (the panel in a --shot)]
//       [--view board|room|window|hall|stove] [--dump-oak PREFIX (the oak's fields as PREFIX-floor.ppm, -wall.ppm)]
//       [--size 1600x1000] [--distance K] [--height DEG] [--yaw DEG] [--shot out.png]
//       [--fps on|off] [--fps-wait (wait for the GPU each frame, G)]
//       [--fps-seconds S (print the counter each half second, quit after S)]
//       [--walk-test N (the walk driven by injected input for N frames, WALK_TEST_END all; with --shot)]

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

let PANEL_W: f32 = 380.0;
let ROW:     f32 = 20.0;
// looks::AUTUMN.. and MATERIAL_AUTO.. in this order.
let SEASONS = ["autumn", "winter", "spring", "summer"];
let MATERIALS = ["auto", "wood", "stone", "carved"];
let SQUARES = ["8", "10"];
// The table's tops to compare (--table-top, the panel's Top): the game's 0.95 m
// (mesh::TABLE_R), the 1.05 m it was and task 109's period 0.80 m; the base under them
// the same.
let TOPS = ["0.95", "1.05", "0.80"];
let TOP_METRES: f32[3] = [0.95, 1.05, 0.80];
fn top_radius(top: i64) -> f32 { mesh::TABLE_R * TOP_METRES[top] / 0.95 }

// The views (V cycles them): the board's orbit, then the room's from a person's eyes, in
// the plan's metres (room_shell): the whole room from the far corner by the hall; the
// window wall from the hall door; the hall wall from the window; the stove's end from the
// far end. With the shell off, room is the view over the table to the panelled wall.
let VIEWS = ["board", "room", "window", "hall", "stove"];
let VIEW_EYES: float3[5] = [float3_0, float3 { 8.4, 0.6, 1.7 }, float3 { 4.5, 1.0, 1.6 }, float3 { 4.5, 6.3, 1.6 },
                            float3 { 8.3, 3.5, 1.6 }];
let VIEW_ATS: float3[5] = [float3_0, float3 { 2.6, 5.8, 1.3 }, float3 { 4.5, 7.0, 1.8 }, float3 { 4.5, 0.0, 1.3 },
                           float3 { 0.0, 3.0, 1.4 }];

// The sky behind the shell's windows, linear: a mid-October afternoon's blue overhead,
// paler and warmer to the horizon, the sun's side lighter.
let SKY_TOP = float4 { 0.36, 0.52, 0.8, 1.0 };
let SKY_LOW = float4 { 0.85, 0.84, 0.8, 1.0 };
let SKY_LIGHT = float4 { 1.0, 0.86, 0.66, 1.0 };

// A point of the room's plan (metres, h up from the floor) in the world, as the room is
// turned now.
fn plan_point(g: render3d::Gpu&, p: float3) -> float3 {
    let r = room_shell::room_of(room_shell::LIBRARY, float2 { p.x, p.y });
    let f = g.room_frame;
    let xz = f.along * r.x + f.into * r.y;
    return float3 { xz.x, surfaces::FLOOR_Y + p.z * surfaces::METRE, xz.y };
}

// The walk round the room (Tab, or the button under Camera and views): WASD and the mouse,
// captured, from a person's eyes 1.6 m up (seated 1.2 m, C); Shift faster; with X, Q and E
// go up and down; Esc back to the panel. The eye keeps WALL_MARGIN off the plan's walls and
// stays where it is when the walk ends, till R or another view.
let WALK_EYE:   f32 = 1.6;
let SEATED_EYE: f32 = 1.2;
let WALK_SPEED: f32 = 1.4;      // metres a second
let WALK_FAST:  f32 = 2.5;      // times as fast with Shift
let RISE_SPEED: f32 = 1.0;      // metres a second up or down
let LOOK_DEG:   f32 = 0.1;      // degrees a pixel of the mouse
let PITCH_MAX:  f32 = 85.0;
// The views' near plane, 0.39 m out (16-bit depth), reaches 0.58 m at its corners: an eye
// nearer a wall would see through it.
let WALL_MARGIN:  f32 = 0.6;
let LOWEST:       f32 = 0.2;    // the eye's lowest and its highest under the ceiling
let WALK_FOV:     f32 = 60.0;   // the room's views'
let LOOK_AHEAD:   f32 = 2.0;    // metres to the point looked at, for --plan-at
let LONGEST_STEP: f32 = 0.1;    // seconds: a stalled frame doesn't jump

struct Walk {
    on:     bool   = false,
    placed: bool   = false,     // the camera is the walk's, on or off
    eye:    float3 = float3_0,  // the plan's metres, z up from the floor
    yaw:    f32    = 0.0,       // degrees in the plan, 0 along x
    pitch:  f32    = 0.0,
    seated: bool   = false,
    rise:   bool   = false,     // Q and E move up and down (X)
}

// The point the walk looks at, in the plan.
fn walk_at(k: Walk) -> float3 {
    let a = radians(k.pitch);
    let b = radians(k.yaw);
    return k.eye + float3 { cos(a) * cos(b), cos(a) * sin(b), sin(a) } * LOOK_AHEAD;
}

// The walk put at a plan view's eye, looking where it looks, a person's eyes high.
fn walk_from(k: Walk&, eye: float3, at: float3) {
    let d = at - eye;
    k.eye = float3 { eye.x, eye.y, if k.seated { SEATED_EYE } else { WALK_EYE } };
    k.yaw = degrees(atan2(d.y, d.x));
    k.pitch = clamp(degrees(atan2(d.z, length(float2 { d.x, d.y }))), -PITCH_MAX, PITCH_MAX);
}

// The walk's one step: the mouse's delta in pixels, the keys held, dt seconds. `hand` is
// +1 when the plan's x and y turn the world's way (screen right is the plan's (-y, x) of
// forward), -1 when mirrored.
fn walk_step(k: Walk&, look: float2, dt: f32, hand: f32) {
    k.yaw -= hand * look.x * LOOK_DEG;
    if k.yaw > 180.0 { k.yaw -= 360.0; }
    if k.yaw < -180.0 { k.yaw += 360.0; }
    k.pitch = clamp(k.pitch - look.y * LOOK_DEG, -PITCH_MAX, PITCH_MAX);
    let b = radians(k.yaw);
    let ahead = float2 { cos(b), sin(b) };
    let right = float2 { ahead.y, -ahead.x } * hand;
    var move = float2_0;
    if gfx::key_down("W") { move += ahead; }
    if gfx::key_down("S") { move -= ahead; }
    if gfx::key_down("D") { move += right; }
    if gfx::key_down("A") { move -= right; }
    let fast = gfx::key_down("Left Shift") || gfx::key_down("Right Shift");
    let speed = WALK_SPEED * (if fast { WALK_FAST } else { 1.0 });
    if length(move) > 0.0 { move = normalize(move) * (speed * dt); }
    let s = room_shell::LIBRARY;
    k.eye.x = clamp(k.eye.x + move.x, WALL_MARGIN, s.walls[0].b.x - WALL_MARGIN);
    k.eye.y = clamp(k.eye.y + move.y, WALL_MARGIN, s.walls[0].a.y - WALL_MARGIN);
    if k.rise {
        var up: f32 = 0.0;
        if gfx::key_down("E") { up += 1.0; }
        if gfx::key_down("Q") { up -= 1.0; }
        k.eye.z = clamp(k.eye.z + up * RISE_SPEED * (if fast { WALK_FAST } else { 1.0 }) * dt, LOWEST, s.ceiling - LOWEST);
    }
}

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

// The frame counter (F): frames a second, the frame's time from one frame to the next,
// its mean and worst, and the time in the loop before the frame is submitted (the CPU's
// work and any wait for the GPU in it; with G all the GPU's work, waited for), each over
// half a second. The tuner draws every frame; a gap of over half a second (the window
// hidden) shows as idle until a new half second is measured.
let METER_WINDOW: f64 = 0.5;

struct Meter {
    on:       bool = true,
    wait:     bool = false, // each frame waited for, as --bench's first phase: CPU and GPU
    start:    f64  = 0.0,   // the window's start
    last:     f64  = 0.0,   // the last frame's start
    frames:   i64  = 0,
    sum:      f64  = 0.0,   // seconds, frame to frame
    worst:    f64  = 0.0,
    in_loop:  f64  = 0.0,   // seconds in the loop before the submit
    idle_for: f64  = 0.0,   // the last gap, while no window is measured since
    fps:      f64  = 0.0,   // the last window's
    mean_ms:  f64  = 0.0,
    worst_ms: f64  = 0.0,
    loop_ms:  f64  = 0.0,
    measured: bool = false,
}

// A new frame begins at `now`: false when it closed a half second's window.
fn meter_frame(m: Meter&, now: f64) -> bool {
    let dt = now - m.last;
    let first = m.last == 0.0;
    m.last = now;
    if first || dt > METER_WINDOW {
        if !first { m.idle_for = dt; }
        m.measured = false;
        m.start = now;
        m.frames = 0;
        m.sum = 0.0;
        m.worst = 0.0;
        m.in_loop = 0.0;
        return false;
    }
    m.frames += 1;
    m.sum += dt;
    m.worst = max(m.worst, dt);
    guard now - m.start >= METER_WINDOW else { return false; }
    m.fps = m.frames as f64 / (now - m.start);
    m.mean_ms = 1000.0 * m.sum / m.frames as f64;
    m.worst_ms = 1000.0 * m.worst;
    m.loop_ms = 1000.0 * m.in_loop / m.frames as f64;
    m.measured = true;
    m.start = now;
    m.frames = 0;
    m.sum = 0.0;
    m.worst = 0.0;
    m.in_loop = 0.0;
    return true;
}

fn tenths(out: u8[..96]&, v: f64) { format(out, floor(v * 10.0 + 0.5) / 10.0); }

// The counter's two lines into `a` and `b`, which the caller owns.
fn meter_text(m: Meter&, a: u8[..96]&, b: u8[..96]&, still: bool) {
    a.clear();
    b.clear();
    if !m.measured {
        if m.idle_for > 0.0 {
            format(a, "idle: nothing drawn for ");
            tenths(a, m.idle_for);
            a.append(" s");
        } else { a.append("measuring"); }
        return;
    }
    tenths(a, m.fps);
    a.append(" fps, ");
    tenths(a, m.mean_ms);
    a.append(" ms a frame, worst ");
    tenths(a, m.worst_ms);
    b.append("in the loop ");
    tenths(b, m.loop_ms);
    b.append(if m.wait { " ms, the GPU waited for" } else { " ms, waits too; no GPU timer" });
    if still { b.append(", the scene still"); }
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
    let ratios: f32[2] = [0.5, 0.5];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    var text: u8[>..] = [];
    text.append(name);
    text.push(' ');
    num(text, v);
    ui::label(c, text, ui::TEXT_LEFT);
    ui::slider_float(c, lo, v, hi, (hi - lo) / 400.0);
}

fn count(c: ui::Context, name: const u8[:], v: i64&, lo: i64, hi: i64) {
    let ratios: f32[2] = [0.5, 0.5];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    ui::label(c, str(name, " ", v), ui::TEXT_LEFT);
    ui::slider_int(c, lo, v, hi, 1);
}

fn choice(c: ui::Context, name: const u8[:], v: i64&, names: const u8[:][]) {
    let ratios: f32[2] = [0.5, 0.5];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    ui::label(c, str(name, " ", names[v]), ui::TEXT_LEFT);
    ui::slider_int(c, 0, v, names.len - 1, 1);
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
fn report(r: rooms::Room, take: i64, flags: const u8[:]) {
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
    room_line(out, "gust:      ", r.gust);
    room_line(out, "tree:      ", r.tree);
    room_line(out, "crown:     ", r.crown);
    room_line(out, "foliage:   ", r.foliage);
    room_line(out, "bounce:    ", r.bounce);
    out.append("    room_exposure: ");
    num(out, r.room_exposure);
    out.append(",\n    outside:       ");
    num(out, r.outside);
    out.append(",\n");
    room_line(out, "shell_sun: ", r.shell_sun);
    room_line(out, "baked:     ", r.baked);
    room_line(out, "bloom:     ", r.bloom);
    room_line(out, "corners:   ", r.corners);
    out.append("};\n// The flags that show the same again (the room's colours, twigs, species and crown in\n");
    out.append("// the literal above):\n");
    out.append(flags);
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

fn on_off(v: bool) -> const u8[:] { if v { "on" } else { "off" } }

fn flag_four(out: u8[>..]&, name: const u8[:], v: float4) {
    format(out, " ", name, " ");
    format(out, v.x);
    out.push(',');
    format(out, v.y);
    out.push(',');
    format(out, v.z);
    out.push(',');
    format(out, v.w);
}

fn flag_pair(out: u8[>..]&, name: const u8[:], v: float2) {
    format(out, " ", name, " ");
    format(out, v.x);
    out.push(',');
    format(out, v.y);
}

fn flag_one(out: u8[>..]&, name: const u8[:], v: f32) {
    format(out, " ", name, " ");
    format(out, v);
}

// The room's values that have flags.
fn room_flags(out: u8[>..]&, r: rooms::Room) {
    flag_four(out, "--key", r.key);
    flag_four(out, "--fill", r.fill);
    flag_four(out, "--walls", r.walls);
    flag_four(out, "--pattern", r.pattern);
    flag_four(out, "--bounce", r.bounce);
    flag_four(out, "--wall", r.window);
    flag_four(out, "--panes", r.panes);
    flag_four(out, "--opening", r.opening);
    flag_four(out, "--tree", r.tree);
    flag_four(out, "--crown", r.crown);
    flag_four(out, "--foliage", r.foliage);
    flag_four(out, "--trees", r.leaves);
    flag_four(out, "--wind", r.wind);
    flag_four(out, "--gust", r.gust);
    flag_four(out, "--shell-sun", r.shell_sun);
    flag_four(out, "--baked", r.baked);
    flag_four(out, "--bloom", r.bloom);
    flag_four(out, "--corners", r.corners);
    flag_one(out, "--exposure", r.exposure);
    flag_one(out, "--room-exposure", r.room_exposure);
    flag_one(out, "--outside-exposure", r.outside);
    flag_one(out, "--tree-blur", r.tree_blur);
}

// The panel's sections, each a tab that opens and closes (its state kept for the session),
// and the parts inside Light and Sun and tree; their names for --sections, and which are
// open at the start.
let SECTIONS = ["Scene", "Light", "Sun and tree", "Wallpaper", "Wainscot and panelling", "Ceiling", "Curtains and lace",
                "Bookcases and books", "Table", "Outside", "Dust in the sunbeam (D)", "Camera and views", "Debug", "Keys",
                "Light in detail (the board's)", "The sun", "The tree", "Wind", "The board's window", "Noise leaves"];
let SECTION_NAMES = ["scene", "light", "sun", "wallpaper", "wainscot", "ceiling", "curtains", "books", "table", "outside", "dust",
                     "camera", "debug", "keys", "detail", "sun-itself", "tree", "wind", "window", "noise"];
let OPEN_AT_START: i64[20] = [1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0];
let PARTS_FROM = 14;
let SCENE = 0;
let LIGHT = 1;
let SUN = 2;
let WALLPAPER = 3;
let WAINSCOT = 4;
let CEILING = 5;
let CURTAINS = 6;
let BOOKS = 7;
let TABLE = 8;
let OUTSIDE = 9;
let DUST = 10;
let CAMERA = 11;
let DEBUG = 12;
let KEYS = 13;
let DETAIL = 14;
let SUN_ITSELF = 15;
let TREE = 16;
let WIND = 17;
let WINDOW = 18;
let NOISE = 19;

let KEY_HELP = ["drag: orbit, scroll: zoom", "R: reset the orbit and the view", "P: print the room and its flags",
                "V: the views in turn", "O: the room; S: the shell or the wall", "U: the park or a plain sky outside",
                "L: the wallpaper's tile, 0.65, 0.9 or 1.4 m", "C: the lace's way; B: the books", "W: the window's pattern; T: leaves by",
                "K: the wind's kind; D: the dust", "F: the frame counter; G: wait for the GPU",
                "Tab: walk; Esc: back to the panel", "walking: WASD, the mouse, Shift faster",
                "walking: C seated, X then Q, E down and up", "R: back to the view, P: the walk's camera"];

// The sections open at the start: OPEN_AT_START, or --sections NAME,NAME.. (or all).
fn open_sections(argv: u8[:][>..]&) -> i64[20] {
    var open = OPEN_AT_START;
    let at = flag_value(argv, "--sections");
    guard at > 0 else { return open; }
    let all = argv[at] == "all";
    for i in 20 { open[i] = if all { ui::MAXIMIZED } else { ui::MINIMIZED }; }
    guard !all else { return open; }
    var rest: const u8[:] = argv[at];
    while rest.len > 0 {
        let part, after, more = split_once(rest, ",");
        var found = false;
        for n, i in SECTION_NAMES {
            if n == part {
                open[i] = ui::MAXIMIZED;
                found = true;
            }
        }
        guard found else { abort(str("--sections: no ", part)); }
        guard more else { break; }
        rest = after;
    }
    return open;
}

// A section's tab (or a part's node inside one): true while open, when tree_state_pop follows.
fn section(c: ui::Context, open: i64[20]&, i: i64) -> bool {
    let kind = if i >= PARTS_FROM { ui::TREE_NODE } else { ui::TREE_TAB };
    return ui::tree_state_push(c, kind, SECTIONS[i], open[i]);
}

fn switch(c: ui::Context, name: const u8[:], v: bool&, names: const u8[:][2]) {
    var k: i64 = if v { 1 } else { 0 };
    choice(c, name, k, names);
    v = k == 1;
}

fn note(c: ui::Context, text: const u8[:]) {
    ui::layout_row_dynamic(c, ROW, 1);
    ui::label(c, text, ui::TEXT_LEFT);
}

fn color_sliders(c: ui::Context, name: const u8[:], v: float4&) {
    slider(c, str(name, " r"), v.x, 0.0, 1.0);
    slider(c, str(name, " g"), v.y, 0.0, 1.0);
    slider(c, str(name, " b"), v.z, 0.0, 1.0);
}

// --walk-test N: the walk driven by injected input for N frames (WALK_TEST_END the whole
// path), each step 1/60 s, and a --shot taken where it ends: into the walk (Tab), W for a
// second, the mouse turned right and down, D with X and E (up), Shift and W for 2.4
// seconds into the stove's end, C, out (Esc), and P.
let WALK_TEST_END = 265;

fn walk_test_input(frame: i64) {
    match frame {
        2 => { gfx::inject_mouse(400.0, 300.0, 0, false); },
        3 => { gfx::inject_key("Tab", true); },
        4 => { gfx::inject_key("Tab", false); },
        6 => { gfx::inject_key("W", true); },
        66 => { gfx::inject_key("W", false); },
        70 => { gfx::inject_mouse(700.0, 350.0, 0, false); },
        71 => { gfx::inject_key("X", true); },
        72 => {
            gfx::inject_key("X", false);
            gfx::inject_key("D", true);
            gfx::inject_key("E", true);
        },
        102 => {
            gfx::inject_key("D", false);
            gfx::inject_key("E", false);
        },
        105 => {
            gfx::inject_key("Left Shift", true);
            gfx::inject_key("W", true);
        },
        250 => {
            gfx::inject_key("Left Shift", false);
            gfx::inject_key("W", false);
        },
        253 => { gfx::inject_key("C", true); },
        254 => { gfx::inject_key("C", false); },
        257 => { gfx::inject_key("Escape", true); },
        258 => { gfx::inject_key("Escape", false); },
        261 => { gfx::inject_key("P", true); },
        262 => { gfx::inject_key("P", false); },
        _ => {},
    }
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
    room.gust = four(argv, "--gust", room.gust);
    room.gust.x = number(argv, "--gust-strength", room.gust.x);
    room.gust.y = number(argv, "--gust-length", room.gust.y);
    room.gust.z = number(argv, "--gust-every", room.gust.z);
    room.gust.w = number(argv, "--gust-reach", room.gust.w);
    room.key = four(argv, "--key", room.key);
    room.fill = four(argv, "--fill", room.fill);
    room.walls = four(argv, "--walls", room.walls);
    room.pattern = four(argv, "--pattern", room.pattern);
    room.bounce = four(argv, "--bounce", room.bounce);
    room.room_exposure = number(argv, "--room-exposure", room.room_exposure);
    room.shell_sun = four(argv, "--shell-sun", room.shell_sun);
    room.baked = four(argv, "--baked", room.baked);
    room.bloom = four(argv, "--bloom", room.bloom);
    room.corners = four(argv, "--corners", room.corners);
    room.outside = number(argv, "--outside-exposure", room.outside);
    room.tree_blur = number(argv, "--tree-blur", room.tree_blur);
    room.exposure = number(argv, "--exposure", room.exposure);
    var motes = whole(argv, "--motes", 500);
    render3d::light_bounces = whole(argv, "--bounces", room_light::BOUNCES);
    render3d::shade_fill = number(argv, "--shade-fill", render3d::shade_fill);
    var dust_on = flag_value(argv, "--dust") > 0 && argv[flag_value(argv, "--dust")] == "on";
    render3d::dust.size = number(argv, "--mote-size", render3d::dust.size);
    render3d::dust.blur = number(argv, "--mote-blur", render3d::dust.blur);
    render3d::dust.bright = number(argv, "--mote-bright", render3d::dust.bright);
    render3d::wind_time = number(argv, "--wind-time", 0.0);
    render3d::wind_kind = pick(argv, "--wind-kind", rooms::WIND_KINDS, rooms::WIND_NOISE);
    g.room = room;
    g.room_tuned = true;
    render3d::window_pattern = pattern == 1;
    var room_on = flag_value(argv, "--room-surfaces") > 0 && argv[flag_value(argv, "--room-surfaces")] == "on";
    var shell_on = !(flag_value(argv, "--shell") > 0 && argv[flag_value(argv, "--shell")] == "off");
    var outside_on = !(flag_value(argv, "--outside") > 0 && argv[flag_value(argv, "--outside")] == "off");
    let away = number(argv, "--wall-away", surfaces::WALL_AWAY);
    render3d::show_room(g, room_on, away, shell_on);
    var paper_m = number(argv, "--wallpaper-tile", surfaces::PAPER_TILE / surfaces::METRE);
    g.paper_tile = paper_m * surfaces::METRE;
    // The panelling oak's and the ceiling's tint (lightness, saturation; 1,1 as they are).
    let oak4 = four(argv, "--oak-tint", float4 { 1.0, 1.0, 0.0, 0.0 });
    var oak = float2 { oak4.x, oak4.y };
    let ceiling4 = four(argv, "--ceiling-tint", float4 { 1.0, 1.0, 0.0, 0.0 });
    var ceiling = float2 { ceiling4.x, ceiling4.y };
    g.lace_way = pick(argv, "--lace", surfaces::LACE_WAYS, 0);
    // The bookcases' books in or out, and how much of their fade shows (1 as made).
    var books_on = !(flag_value(argv, "--books") > 0 && argv[flag_value(argv, "--books")] == "off");
    var book_fade = number(argv, "--book-fade", 1.0);
    var top = pick(argv, "--table-top", TOPS, 0);
    g.table_r = top_radius(top);
    // --dump-map out.pgm: the tree's map as the sun sees it, all layers' light multiplied, as
    // the renderer bakes it (the room's on or off).
    let dump = flag_value(argv, "--dump-map");
    if dump > 0 {
        var t = trees::Tree { .. };
        let sp = rooms::tree_spec(render3d::tree_room(g));
        let v = render3d::tree_view_of(g);
        trees::grow(t, sp, v);
        var map: u8[>..] = [];
        trees::draw_map(t, sp, v, map);
        var out: u8[>..] = [];
        format(out, "P5\n", v.w, " ", v.h, "\n255\n");
        for i in v.w * v.h {
            let o = i * 4;
            let k = (map[o] as i64) * (map[o + 1] as i64) / 255 * (map[o + 2] as i64) / 255 * (map[o + 3] as i64) / 255;
            out.push(k as u8);
        }
        guard write_file(argv[dump], out[..]) else { abort("could not write the map"); }
        print("map ", v.size.x, " by ", v.size.y, " middle ", v.middle.x, ",", v.middle.y);
    }

    put_look(r3d, g, season, material, st);

    let scale = max(gfx::screen_size().x as f32 / w, 1.0);
    let c = ui::create(13.0, scale);
    guard c.id != 0 else { abort(str("ui: ", ui::error())); }
    var shown_season = season;
    var shown_material = material;
    var shown_take = take;
    var shown_room = room_take;
    var shown_top = top;
    var yaw:   f32 = number(argv, "--yaw", 0.0);
    var pitch: f32 = number(argv, "--height", view3d::PITCH);
    var far:   f32 = number(argv, "--distance", 1.3);
    var at = float2 { view3d::TARGET.x, view3d::TARGET.z };
    // A camera of its own (--eye, --at), or the room seen from the window's side (V).
    let own_eye = flag_value(argv, "--eye") > 0;
    var eye_at = four(argv, "--eye", float4_0);
    var look_at = four(argv, "--at", float4 { view3d::TARGET.x, view3d::TARGET.y, view3d::TARGET.z, 0.0 });
    var view = pick(argv, "--view", VIEWS, 0);
    let plan_eye = flag_value(argv, "--plan-eye") > 0;
    let plan_eye_at = four(argv, "--plan-eye", float4_0);
    let plan_look_at = four(argv, "--plan-at", float4 { 4.5, 5.8, 0.8, 0.0 });
    let fov_flag = number(argv, "--fov", 0.0);
    let shot = flag_value(argv, "--shot");
    var meter = Meter { on: !(has(argv, "--fps") && argv[flag_value(argv, "--fps")] == "off"), wait: has(argv, "--fps-wait"), .. };
    let meter_for = number(argv, "--fps-seconds", 0.0) as f64;
    var meter_a: u8[..96] = [];
    var meter_b: u8[..96] = [];
    var frames = 0;
    var open = open_sections(argv);
    var drag_on_panel = false;
    var reset_orbit = false;
    // --shot-panel: the panel drawn in a shot too.
    let panel_in_shot = has(argv, "--shot-panel");
    var walk = Walk {};
    var shown_view = view;
    var walk_text: u8[..96] = [];
    let walk_test = whole(argv, "--walk-test", 0);
    let shot_frame = if walk_test > 0 { walk_test } else { 6 };
    var bakes_walking = 0;
    var last_tree_ms = 0.0;
    var last_light_ms = 0.0;
    while gfx::frame() {
        frames++;
        let frame_at = gfx::time();
        let still = pattern == 0 || render3d::wind_kind == rooms::WIND_STILL || room.wind.y == 0.0;
        if meter_frame(meter, frame_at) {
            meter_text(meter, meter_a, meter_b, still);
            if meter_for > 0.0 { print(meter_a[..], "; ", meter_b[..]); }
        } else if !meter.measured {
            meter_text(meter, meter_a, meter_b, still);
        }
        if meter_for > 0.0 && frame_at > meter_for { break; }
        if walk_test > 0 { walk_test_input(frames); }
        if shot > 0 && frames == shot_frame {
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
                      render3d::room_bytes(g) / 1048576, " MiB; its mesh made in ", g.mesh_ms, " ms, ",
                      g.room_count / 3, " triangles and ", g.glass_count / 3, " of glass and lace");
            }
            if g.light_ms > 0.0 {
                let st = render3d::light_steps;
                print("the room's light baked in ", g.light_ms, " ms, ", g.light_patches, " sun patches; the sun's rays ", st[0],
                      " ms, the first light ", st[1], ", the bounces ", st[2], ", ", st[3], ", ", st[4], ", the half grid ", st[5],
                      ", the probes ", st[6]);
            }
            if walk_test > 0 {
                print("walked to ", walk.eye.x, ",", walk.eye.y, ",", walk.eye.z, " yaw ", walk.yaw, " pitch ", walk.pitch,
                      "; walking ", walk.on, ", seated ", walk.seated, ", the mouse relative ", gfx::mouse_relative(),
                      ", the cursor shown ", gfx::cursor_visible(), "; bakes while walking ", bakes_walking);
            }
            break;
        }
        ui::input_from_gfx(c);
        var print_it = gfx::key_pressed("P");
        // Tab begins the walk; Esc or Tab ends it, and so does losing focus, which lets the mouse go.
        var walk_now = !walk.on && gfx::key_pressed("Tab");
        if walk.on && (gfx::key_pressed("Escape") || gfx::key_pressed("Tab") || !gfx::mouse_relative()) {
            walk.on = false;
            gfx::set_mouse_relative(false);
        }
        if walk.on {
            if gfx::key_pressed("C") {
                walk.seated = !walk.seated;
                walk.eye.z = if walk.seated { SEATED_EYE } else { WALK_EYE };
            }
            if gfx::key_pressed("X") {
                walk.rise = !walk.rise;
                if !walk.rise { walk.eye.z = if walk.seated { SEATED_EYE } else { WALK_EYE }; }
            }
        } else {
            if gfx::key_pressed("W") { pattern = 1 - pattern; }
            if gfx::key_pressed("T") { room.tree.x = (room.tree.x as i64 + 1) % 3; }
            if gfx::key_pressed("D") { dust_on = !dust_on; }
            if gfx::key_pressed("O") { room_on = !room_on; }
            if gfx::key_pressed("V") { view = (view + 1) % VIEWS.len; }
            if gfx::key_pressed("S") { shell_on = !shell_on; }
            if gfx::key_pressed("U") { outside_on = !outside_on; }
            if gfx::key_pressed("K") { render3d::wind_kind = (render3d::wind_kind + 1) % rooms::WIND_KINDS.len; }
            if gfx::key_pressed("F") { meter.on = !meter.on; }
            if gfx::key_pressed("G") { meter.wait = !meter.wait; }
            if gfx::key_pressed("C") { g.lace_way = (g.lace_way + 1) % surfaces::LACE_WAYS.len; }
            if gfx::key_pressed("B") { books_on = !books_on; }
            if gfx::key_pressed("L") { paper_m = if paper_m > 1.0 { 0.65 } else if paper_m > 0.7 { 1.4 } else { 0.9 }; }
        }
        let flags = ui::WINDOW_BORDER | ui::WINDOW_TITLE | ui::WINDOW_MOVABLE | ui::WINDOW_SCALABLE;
        let panel_h = gfx::screen_size().y / scale - 20.0;
        if !walk.on && ui::begin(c, "Room light", ui::rect(10.0, 10.0, PANEL_W, panel_h), flags) {
            ui::layout_row_dynamic(c, ROW + 4.0, 2);
            if ui::button_label(c, "Print (P)") { print_it = true; }
            if ui::button_label(c, "Reset room") { shown_room = -1; }
            if section(c, open, SCENE) {
                choice(c, "Room", room_take, rooms::NAMES);
                choice(c, "Season", season, SEASONS);
                choice(c, "Board", material, MATERIALS);
                switch(c, "Room (O)", room_on, ["off", "on"]);
                switch(c, "Shell (S)", shell_on, ["wall", "library"]);
                ui::tree_state_pop(c);
            }
            if section(c, open, LIGHT) {
                slider(c, "Room's exposure", room.room_exposure, 0.5, 4.0);
                slider(c, "Bounce", room.bounce.w, 0.0, 2.0);
                color_sliders(c, "Bounce", room.bounce);
                slider(c, "Sun on the room", room.shell_sun.y, 0.0, 5.0);
                slider(c, "Penumbra", room.shell_sun.x, 0.0, 0.02);
                slider(c, "Probes' sky", room.baked.x, 0.0, 20.0);
                slider(c, "Probes' bounce", room.baked.y, 0.0, 30.0);
                slider(c, "Harmonics kept", room.baked.z, 0.0, 1.0);
                slider(c, "Shade kept", room.baked.w, 0.0, 1.0);
                slider(c, "Glow", room.bloom.x, 0.0, 2.0);
                slider(c, "Glow white", room.bloom.y, 0.0, 1.0);
                slider(c, "Glow knee", room.bloom.z, 0.0, 1.0);
                slider(c, "Glow spread", room.bloom.w, 0.5, 12.0);
                slider(c, "Corners' shade", room.corners.x, 0.0, 2.0);
                slider(c, "Corners' reach", room.corners.y, 0.05, 1.0);
                if g.light_ms > 0.0 {
                    note(c, str("probes baked in ", floor(g.light_ms + 0.5) as i64, " ms, ", g.light_patches, " sun patches"));
                }
                if section(c, open, DETAIL) {
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
                    ui::tree_state_pop(c);
                }
                ui::tree_state_pop(c);
            }
            if section(c, open, SUN) {
                choice(c, "Pattern (W)", pattern, ["off", "on"]);
                var shade = clamp(room.tree.x as i64, 0, 2);
                choice(c, "Leaves by (T)", shade, ["noise", "tree", "both"]);
                room.tree.x = shade;
                if section(c, open, SUN_ITSELF) {
                    slider(c, "Round", room.key.x, -30.0, 150.0);
                    slider(c, "Height", room.key.y, 3.0, 70.0);
                    slider(c, "Strength", room.key.z, 0.0, 12.0);
                    slider(c, "Shadow", room.key.w, 0.0, 1.0);
                    ui::tree_state_pop(c);
                }
                if section(c, open, TREE) {
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
                    if g.tree_ms > 0.0 { note(c, str("baked in ", floor(g.tree_ms + 0.5) as i64, " ms")); }
                    ui::tree_state_pop(c);
                }
                if section(c, open, WIND) {
                    choice(c, "Kind (K)", render3d::wind_kind, rooms::WIND_KINDS);
                    slider(c, "Wind", room.wind.x, 0.0, 0.3);
                    slider(c, "Wind speed", room.wind.y, 0.0, 4.0);
                    slider(c, "Leaves sway", room.wind.z, 0.0, 8.0);
                    slider(c, "Ruffle", room.wind.w, 0.0, 2.0);
                    slider(c, "Gust strength", room.gust.x, 0.0, 2.0);
                    slider(c, "Gust length", room.gust.y, 0.3, 8.0);
                    slider(c, "Gust every", room.gust.z, 3.0, 60.0);
                    slider(c, "Gust reach", room.gust.w, 0.0, 1.0);
                    ui::tree_state_pop(c);
                }
                if section(c, open, WINDOW) {
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
                    ui::tree_state_pop(c);
                }
                if section(c, open, NOISE) {
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
                    ui::tree_state_pop(c);
                }
                ui::tree_state_pop(c);
            }
            if section(c, open, WALLPAPER) {
                slider(c, "Tile (m)", paper_m, 0.65, 1.4);
                let thirds: f32[4] = [0.25, 0.25, 0.25, 0.25];
                ui::layout_row(c, ui::DYNAMIC, ROW, thirds);
                ui::label(c, "L flips", ui::TEXT_LEFT);
                if ui::button_label(c, "0.65") { paper_m = 0.65; }
                if ui::button_label(c, "0.9") { paper_m = 0.9; }
                if ui::button_label(c, "1.4") { paper_m = 1.4; }
                ui::tree_state_pop(c);
            }
            if section(c, open, WAINSCOT) {
                slider(c, "Oak light", oak.x, 0.25, 8.0);
                slider(c, "Oak colour", oak.y, 0.0, 1.5);
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "As baked") { oak = float2 { 1.0, 1.0 }; }
                if g.room_ms > 0.0 {
                    note(c, str("oak baked in ", floor(g.room_ms + 0.5) as i64, " ms, ", render3d::room_bytes(g) / 1048576, " MiB"));
                }
                ui::tree_state_pop(c);
            }
            if section(c, open, CEILING) {
                slider(c, "Ceiling light", ceiling.x, 0.3, 1.5);
                slider(c, "Ceiling colour", ceiling.y, 0.0, 3.0);
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "As it is") { ceiling = float2 { 1.0, 1.0 }; }
                ui::tree_state_pop(c);
            }
            if section(c, open, CURTAINS) {
                choice(c, "Lace (C)", g.lace_way, surfaces::LACE_WAYS);
                slider(c, "Curtain in", room.opening.z, 0.0, 20.0);
                slider(c, "Lace lets", room.opening.w, 0.0, 1.0);
                ui::tree_state_pop(c);
            }
            if section(c, open, BOOKS) {
                switch(c, "Books (B)", books_on, ["off", "on"]);
                slider(c, "Their fade", book_fade, 0.0, 3.0);
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "As made") { book_fade = 1.0; }
                ui::tree_state_pop(c);
            }
            if section(c, open, TABLE) {
                choice(c, "Table", take, tables::NAMES);
                choice(c, "Top (m)", top, TOPS);
                ui::tree_state_pop(c);
            }
            if section(c, open, OUTSIDE) {
                switch(c, "Outside (U)", outside_on, ["plain", "park"]);
                slider(c, "Outside's exposure", room.outside, 0.3, 2.5);
                ui::tree_state_pop(c);
            }
            if section(c, open, DUST) {
                switch(c, "Dust", dust_on, ["off", "on"]);
                count(c, "Motes", motes, 0, render3d::MAX_MOTES);
                slider(c, "Mote size", render3d::dust.size, 0.3, 4.0);
                slider(c, "Lens blur", render3d::dust.blur, 0.0, 60.0);
                slider(c, "Bright", render3d::dust.bright, 0.0, 4.0);
                slider(c, "Thin out", render3d::dust.thin, 0.0, 2.0);
                slider(c, "Toward sun", render3d::dust.ahead, 0.0, 0.9);
                slider(c, "Rise", render3d::dust.rise, 0.0, 0.4);
                slider(c, "Wander", render3d::dust.reach, 0.0, 2.0);
                ui::tree_state_pop(c);
            }
            if section(c, open, CAMERA) {
                choice(c, "View (V)", view, VIEWS);
                slider(c, "Distance", far, 0.4, 4.0);
                slider(c, "Height", pitch, 10.0, 89.0);
                slider(c, "Round", yaw, -180.0, 180.0);
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "Reset the orbit and the view (R)") { reset_orbit = true; }
                if ui::button_label(c, "Walk round the room (Tab)") { walk_now = true; }
                switch(c, "Seated (C)", walk.seated, ["no", "yes"]);
                switch(c, "Up and down (X)", walk.rise, ["off", "Q, E"]);
                if walk.placed {
                    note(c, str("walked to ", floor(walk.eye.x * 100.0 + 0.5) / 100.0, ", ", floor(walk.eye.y * 100.0 + 0.5) / 100.0,
                                ", ", floor(walk.eye.z * 100.0 + 0.5) / 100.0, " m; P prints it"));
                }
                ui::tree_state_pop(c);
            }
            if section(c, open, DEBUG) {
                switch(c, "Frames (F)", meter.on, ["off", "on"]);
                switch(c, "Wait GPU (G)", meter.wait, ["off", "on"]);
                note(c, if g.bake_held { "bakes held till the slider's let go" } else { "bakes when let go of a slider" });
                if g.tree_ms > 0.0 { note(c, str("the tree baked in ", floor(g.tree_ms + 0.5) as i64, " ms")); }
                if g.light_ms > 0.0 { note(c, str("the probes baked in ", floor(g.light_ms + 0.5) as i64, " ms")); }
                if g.room_ms > 0.0 { note(c, str("the oak baked in ", floor(g.room_ms + 0.5) as i64, " ms")); }
                ui::tree_state_pop(c);
            }
            if section(c, open, KEYS) {
                for k in KEY_HELP { note(c, k); }
                ui::tree_state_pop(c);
            }
        }
        if !walk.on { ui::end(c); }
        // A drag that began on the panel holds the tree's and the probes' bakes till it is let go.
        if gfx::mouse_pressed(gfx::MOUSE_LEFT) { drag_on_panel = ui::wants_mouse(c); }
        g.bake_held = drag_on_panel && gfx::mouse_down(gfx::MOUSE_LEFT);
        g.paper_tile = paper_m * surfaces::METRE;
        g.books_off = !books_on;
        g.book_fade = max(book_fade, 0.001);
        g.room_tint = float4_0;
        if oak.x != 1.0 || oak.y != 1.0 {
            g.room_tint.x = oak.x;
            g.room_tint.y = oak.y;
        }
        if ceiling.x != 1.0 || ceiling.y != 1.0 {
            g.room_tint.z = ceiling.x;
            g.room_tint.w = ceiling.y;
        }
        if room_take != shown_room {
            shown_room = room_take;
            room = rooms::get(room_take);
        }
        if top != shown_top {
            shown_top = top;
            g.table_r = top_radius(top);
            render3d::tune_table(r3d, g, g.table_spec);
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
        render3d::show_room(g, room_on, away, shell_on);
        // A shot is taken at --wind-time itself.
        if shot < 0 { render3d::wind_time += gfx::delta_time() as f32; }
        render3d::put_room(g);
        // The walk: begun where the view is (or the room's view from the board's orbit), with
        // the room and its shell on; another view ends its camera.
        if view != shown_view {
            shown_view = view;
            walk.placed = false;
        }
        let from_view = if view > 0 { view } else { 1 };
        var start_eye = VIEW_EYES[from_view];
        var start_at = VIEW_ATS[from_view];
        if plan_eye && !own_eye {
            start_eye = float3 { plan_eye_at.x, plan_eye_at.y, plan_eye_at.z };
            start_at = float3 { plan_look_at.x, plan_look_at.y, plan_look_at.z };
        }
        if walk_now && gfx::set_mouse_relative(true) {
            room_on = true;
            shell_on = true;
            render3d::show_room(g, room_on, away, shell_on);
            if !walk.placed { walk_from(walk, start_eye, start_at); }
            if !walk.rise { walk.eye.z = if walk.seated { SEATED_EYE } else { WALK_EYE }; }
            walk.on = true;
            walk.placed = true;
        }
        if gfx::key_pressed("R") || reset_orbit {
            if walk.on { walk_from(walk, start_eye, start_at); } else { walk.placed = false; }
        }
        if walk.on {
            let o = plan_point(g, float3_0);
            let px = plan_point(g, float3 { 1.0, 0.0, 0.0 }) - o;
            let py = plan_point(g, float3 { 0.0, 1.0, 0.0 }) - o;
            let hand: f32 = if py.x * px.z - py.z * px.x >= 0.0 { 1.0 } else { -1.0 };
            let dt = if walk_test > 0 { 1.0 / 60.0 } else { min(gfx::delta_time() as f32, LONGEST_STEP) };
            walk_step(walk, gfx::mouse_delta(), dt, hand);
        }
        if print_it {
            var line: u8[>..] = [];
            line.append("--room ");
            line.append(rooms::NAMES[room_take]);
            format(line, " --season ", SEASONS[season], " --material ", MATERIALS[material], " --table ", tables::NAMES[take],
                   " --table-top ", TOPS[top], " --lace ", surfaces::LACE_WAYS[g.lace_way]);
            format(line, " --room-surfaces ", on_off(room_on), " --shell ", on_off(shell_on), " --outside ", on_off(outside_on),
                   " --window ", on_off(pattern == 1), " --dust ", on_off(dust_on), " --wind-kind ",
                   rooms::WIND_KINDS[render3d::wind_kind], " --view ", VIEWS[view]);
            format(line, " --wallpaper-tile ", paper_m);
            if dust_on {
                format(line, " --motes ", motes, " --mote-size ", render3d::dust.size, " --mote-blur ", render3d::dust.blur,
                       " --mote-bright ", render3d::dust.bright);
            }
            format(line, " --books ", on_off(books_on), " --book-fade ", book_fade);
            flag_pair(line, "--oak-tint", oak);
            flag_pair(line, "--ceiling-tint", ceiling);
            room_flags(line, room);
            if walk.placed {
                let at = walk_at(walk);
                flag_four(line, "--plan-eye", float4 { walk.eye.x, walk.eye.y, walk.eye.z, 0.0 });
                flag_four(line, "--plan-at", float4 { at.x, at.y, at.z, 0.0 });
                format(line, " --fov ", if fov_flag > 0.0 { fov_flag } else { WALK_FOV });
            } else if own_eye {
                flag_four(line, "--eye", eye_at);
                flag_four(line, "--at", look_at);
            } else if plan_eye {
                flag_four(line, "--plan-eye", plan_eye_at);
                flag_four(line, "--plan-at", plan_look_at);
            } else {
                format(line, " --yaw ", yaw, " --height ", pitch, " --distance ", far);
            }
            if fov_flag > 0.0 && !walk.placed { format(line, " --fov ", fov_flag); }
            report(room, room_take, line[..]);
        }
        if gfx::key_pressed("R") || reset_orbit {
            reset_orbit = false;
            yaw = 0.0;
            pitch = view3d::PITCH;
            far = 1.3;
        }
        if !walk.on && !ui::wants_mouse(c) {
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
        if walk.placed {
            eye = plan_point(g, walk.eye);
            target = plan_point(g, walk_at(walk));
            fov = WALK_FOV;
        } else if own_eye {
            eye = float3 { eye_at.x, eye_at.y, eye_at.z };
            target = float3 { look_at.x, look_at.y, look_at.z };
        } else if plan_eye {
            eye = plan_point(g, float3 { plan_eye_at.x, plan_eye_at.y, plan_eye_at.z });
            target = plan_point(g, float3 { plan_look_at.x, plan_look_at.y, plan_look_at.z });
            fov = 55.0;
        } else if view > 0 && shell_on && room_on {
            eye = plan_point(g, VIEW_EYES[view]);
            target = plan_point(g, VIEW_ATS[view]);
            fov = 60.0;
        } else if view > 0 {
            // From beside the window, a person's eyes high, over the table to the wall.
            let f = g.room_frame;
            let e2 = f.along * -15.0 + f.into * -30.0;
            let t2 = f.along * 12.0 + f.into * (0.7 * away);
            eye = float3 { e2.x, 22.0, e2.y };
            target = float3 { t2.x, -14.0, t2.y };
            fov = 50.0;
        }
        // Behind the shell's windows the park (model3d::view_out), or with U a plain sky of
        // ours (render3d's plain fade), not the season's photograph; the fade gives the
        // board's ambient either way.
        g.plain = room_on && shell_on;
        g.outside_on = outside_on;
        g.fade = [SKY_TOP, SKY_LOW, SKY_LIGHT];
        render3d::dust.count = if dust_on { motes } else { 0 };
        render3d::dust.focus = length(eye - target);
        if fov_flag > 0.0 { fov = fov_flag; }
        // The near plane farther with the room, so 16-bit depth keeps its panels apart.
        let near: f32 = if room_on { clamp(0.2 * length(eye - target), 1.0, 12.0) } else { 1.0 };
        let proj = gfx::perspective(fov * PI / 180.0, size.x as f32 / size.y, near, if room_on { 600.0 } else { 120.0 });
        render3d::draw(r3d, g, gfx::mul(proj, gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 })), eye,
                       gfx::screen(), size);
        if walk.on {
            if g.tree_ms != last_tree_ms || g.light_ms != last_light_ms { bakes_walking += 1; }
            if shot < 0 || panel_in_shot {
                walk_text.clear();
                walk_text.append("walking at ");
                tenths(walk_text, walk.eye.x as f64);
                walk_text.append(", ");
                tenths(walk_text, walk.eye.y as f64);
                walk_text.append(", ");
                tenths(walk_text, walk.eye.z as f64);
                walk_text.append(" m");
                if ui::begin(c, "Walk", ui::rect(10.0, 10.0, PANEL_W, 5.0 * ROW + 16.0), ui::WINDOW_NO_INPUT | ui::WINDOW_NO_SCROLLBAR) {
                    note(c, walk_text[..]);
                    note(c, "WASD, the mouse; Shift faster; C seated");
                    note(c, if walk.rise { "Q, E down and up (X)" } else { "X: Q and E go down and up" });
                    note(c, "R back to the view; Esc the panel");
                }
                ui::end(c);
            }
        }
        last_tree_ms = g.tree_ms;
        last_light_ms = g.light_ms;
        if meter.on && shot < 0 {
            let box_w: f32 = 420.0;
            let at_x = gfx::screen_size().x / scale - box_w - 10.0;
            if ui::begin(c, "Frames (F)", ui::rect(at_x, 10.0, box_w, 2.0 * ROW + 16.0),
                         ui::WINDOW_NO_INPUT | ui::WINDOW_NO_SCROLLBAR) {
                ui::layout_row_dynamic(c, ROW, 1);
                ui::label(c, meter_a[..], ui::TEXT_LEFT);
                ui::layout_row_dynamic(c, ROW, 1);
                ui::label(c, meter_b[..], ui::TEXT_LEFT);
            }
            ui::end(c);
        }
        if shot < 0 || panel_in_shot { ui::render(c); }
        if meter.wait { gfx::flush(); }
        meter.in_loop += gfx::time() - frame_at;
    }
}
