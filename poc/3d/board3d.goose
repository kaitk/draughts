// Task 015's 3D board prototype: the board in autumn wood or winter stone and a fixed
// position, drawn natively with goose_gfx through the renderer the app shares
// (src/render3d/), floating in front of the season's photograph. A drag turns the camera;
// Tab or a double click switches between inspecting round the default view and turning
// freely round the board; R resets the view; T, or a long press for touch, switches the
// theme; K switches the king between a stack of two discs and one crowned disc; W cycles
// the wood's model and M the winter frame's marble (task 039); S cycles summer's variants;
// G spring's look: the birch, the elven stone or the Baltic oak (task 041); P shows the tuning
// panel (panel.goose), V prints its values; A cycles the antialiasing (MSAA, SMAA, none) and
// Z a 4× zoom on the board's near left corner, magnified without filtering, which a drag
// pans (task 071), the label at the top left naming both; H cycles the shadow's looks (task
// 086's softer ones: render3d::SHADOW_9..), the label and the jump's panel naming it.
// Nothing of the app's shell.
// J, or --jump T, switches to the jump (task 082, New game's icon): one light man on c3
// capturing a dark one on d4, the board otherwise empty, the camera turning freely round
// the jump with the mouse wheel moving it nearer or farther; the light man flies along a
// high arc (--arc H squares, 1 by default) to e5 as the slider at the bottom goes from 0 to
// 1, Left and Right nudge it by 0.01, and each release of the mouse, or V, prints the
// camera and the slider as the flags that give that shot again.
//
//   cd poc/3d
//   ../../build/goose-v2026.4-macos-arm64/goose build -o ../../build/board3d board3d.goose
//   ../../build/board3d
//   ../../build/board3d --shot out.png --size 1920x1200 [--yaw 20 --pitch 40]
//   ../../build/board3d --theme winter --king crown
//   ../../build/board3d --wood 0                  # the wood's model: 0 to 3 (each look has its own)
//   ../../build/board3d --theme winter --marble 1 # the frame's marble: 0 the slate, 1 to 4
//   ../../build/board3d --summer 2                # summer's variant: 0 to 6 (looks::SUMMERS), 4 and 5 amber, 6 its plain stone
//   ../../build/board3d --autumn 1                # autumn's: 0 the wood, 1 to 3 stone (looks::AUTUMNS)
//   ../../build/board3d --winter 1                # winter's: 0 the slate, 1 to 3 wood (looks::WINTERS)
//   ../../build/board3d --theme spring --spring 1 # spring's look: 0 the birch, 1 elven, 2 Baltic (the default)
//   ../../build/board3d --panel                   # the tuning panel shown; --plain no finish
//   ../../build/board3d --bench 200
//   ../../build/board3d --zoom 4 --aa smaa [--full]  # the antialiasing a pixel at a time
//   ../../build/board3d --jump 0.5                # the jump, halfway; J switches it
//   ../../build/board3d --shot out.png --jump 0.5 --yaw 30 --pitch 35 --distance 8
//   ../../build/board3d --shadow few              # the shadow in 4 taps, a phone's
//   ../../build/board3d --jump 0.5 --shadows disc  # task 086's looks: 9, 9wide, 16, 4, disc; H cycles
//
// --shot draws one frame headless (no window) into a PNG; --bench times frames.
//
// Frame structure (render3d): the shadow map only when the position changes; each drawn
// frame one forward pass into a 4× multisampled target resolved into gfx's screen.
// Nothing is drawn while nothing changes.

import std;
import vec;
import math;
import os;
import gfx;
import ui;
import model3d from "../../src/model3d";
import render3d from "../../src/render3d";
import .panel;

// Measuring (--samples, --shadow-every): the multisampled target's samples, 1 drawing
// straight into the screen; and the shadow map redrawn every frame, not only on change.
var samples: i32 = render3d::SAMPLES;
var shadow_every = false;

// The camera: 52.5° down, a 31° field of view, framed as the 3D reference (fitted to its
// field corners); the app's is view3d's, the same. Inspecting keeps it near the default
// view; free turns it all round the board.
let FOV:              f32 = 31.0;
let DISTANCE:         f32 = 14.75;
let PITCH:            f32 = 52.5;
let INSPECT_YAW:      f32 = 35.0;
let INSPECT_PITCH_LO: f32 = 35.0;
let INSPECT_PITCH_HI: f32 = 75.0;
let FREE_PITCH_LO:    f32 = 20.0;
let FREE_PITCH_HI:    f32 = 85.0;
let DRAG:             f32 = 0.25; // degrees per pixel
// A press held this long (seconds) within this many pixels switches the theme on touch.
let LONG_PRESS:      f64 = 0.6;
let LONG_PRESS_SLOP: f32 = 12.0;

struct Camera { yaw: f32, pitch: f32, free: bool }

// The jump (J, --jump T): the light man from c3 over the dark one on d4 to e5, at `jump_t`
// of the way, `arc` squares up at its height; the camera looks at the jump's middle from
// `distance` (the mouse wheel; --distance), the whole board's DISTANCE otherwise.
var jumping = false;
var jump_t:   f32 = 0.5;
var arc:      f32 = 1.0;
var distance: f32 = DISTANCE;
let JUMP_DISTANCE: f32 = 8.0;
var jump_ui = default<ui::Context>();

// The position: the 3D reference's, dark pieces on the far rows and light on the near,
// one light king, one light piece selected. Each piece is (row, col, dark, king,
// selected); row 0 is the far side, and pieces stand on the dark squares.
let PIECES: i32[5][23] = [
    [0, 1, 1, 0, 0], [0, 3, 1, 0, 0], [0, 5, 1, 0, 0], [0, 7, 1, 0, 0],
    [1, 0, 1, 0, 0], [1, 2, 1, 0, 0], [1, 4, 1, 0, 0], [1, 6, 1, 0, 0],
    [2, 1, 1, 0, 0], [2, 3, 1, 0, 0], [2, 5, 1, 0, 0], [2, 7, 1, 0, 0],
    [3, 2, 1, 0, 0], [3, 6, 1, 0, 0],
    [5, 0, 0, 0, 0], [5, 6, 0, 0, 0],
    [6, 1, 0, 0, 0], [6, 3, 0, 0, 0], [6, 5, 0, 0, 1],
    [7, 0, 0, 0, 0], [7, 2, 0, 0, 0], [7, 4, 0, 1, 0], [7, 6, 0, 0, 0],
];

// The selected piece lifts by 0.8% of the board and grows to 1.05.
let LIFT:   f32 = 0.07;
let GROW:   f32 = 1.05;
let HEIGHT: f32 = 0.29;
let RADIUS: f32 = 0.44;

// How a king is shown (--king stack|crown, K switches): a plain stack of two discs, or
// one disc with the crown debossed in its recess. The app shows one or the other.
var king_crown = false;

// Puts the position on the GPU: the instances (two float4s each: foot and scale; dark, 1
// crowned or 0.5 a stack's upper disc, 1 selected or 2 a stack's lower disc, seed), the
// squares the field's occlusion reads (top, foot, radius, occupied; then the piece's middle), no marks, and where
// the selected piece stands; the shadow map follows.
fn place(g: render3d::Gpu&) {
    if jumping {
        place_jump(g);
        return;
    }
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
        let lift:  f32 = if sel { LIFT } else { 0.0 };
        let scale: f32 = if sel { GROW } else { 1.0 };
        let seed = i as f32;
        var top = lift + HEIGHT * scale;
        if p[3] == 1 && king_crown {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 1.0, 0.0, seed });
        } else if p[3] == 1 {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, 2.0, seed });
            inst.push(float4 { x, top, z, scale });
            inst.push(float4 { dark, 0.5, 0.0, seed + 0.5 });
            top += HEIGHT * scale;
        } else {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, if sel { 1.0 } else { 0.0 }, seed });
        }
        squares[2 * (p[0] * 8 + p[1])] = float4 { top, lift, RADIUS * scale, 1.0 };
        squares[2 * (p[0] * 8 + p[1]) + 1] = float4 { x, z, 0.0, 0.0 };
        if sel { selected = float4 { x, lift, z, RADIUS * scale }; }
    }
    render3d::place(g, inst[..inst.len], fades[..0], squares[..], marks[..], lit[..], selected, 0.0, true);
}

// The jump's two men: the dark one on d4 (row 4, column 3), the light one at jump_t of the
// way from c3 (row 5, column 2) to e5 (row 3, column 4), lifted by the arc's sine; the
// field's occlusion sees it where it is, kept on the square it is over, but d4's, which
// stays the dark man's.
fn place_jump(g: render3d::Gpu&) {
    var inst:    float4[..4] = [];
    var squares: float4[200] = [float4_0; 200];
    var marks:   float4[100] = [float4 { 0.0, 0.0, 0.0, -1.0 }; 100];
    var lit:     float4[100] = [float4_0; 100];
    var fades:   f32[1]      = [0.0];
    inst.push(float4 { 3.0 - 3.5, 0.0, 4.0 - 3.5, 1.0 });
    inst.push(float4 { 1.0, 0.0, 0.0, 0.0 });
    squares[2 * (4 * 8 + 3)] = float4 { HEIGHT, 0.0, RADIUS, 1.0 };
    squares[2 * (4 * 8 + 3) + 1] = float4 { 3.0 - 3.5, 4.0 - 3.5, 0.0, 0.0 };
    let col = 2.0 + 2.0 * jump_t;
    let row = 5.0 - 2.0 * jump_t;
    let lift = arc * sin(PI * jump_t);
    inst.push(float4 { col - 3.5, lift, row - 3.5, 1.0 });
    inst.push(float4 { 0.0, 0.0, 0.0, 1.0 });
    let sq = (floor(row + 0.5) as i64) * 8 + floor(col + 0.5) as i64;
    if sq != 4 * 8 + 3 {
        squares[2 * sq] = float4 { lift + HEIGHT, lift, RADIUS, 1.0 };
        squares[2 * sq + 1] = float4 { col - 3.5, row - 3.5, 0.0, 0.0 };
    }
    render3d::place(g, inst[..inst.len], fades[..0], squares[..], marks[..], lit[..], float4_0, 0.0, true);
}

// What the camera looks at: the jump's middle, or the board's.
fn target() -> float3 { if jumping { float3 { -0.5, 0.3, 0.5 } } else { float3 { 0.0, -0.15, 1.1 } } }

// The jump's slider at the bottom of the screen, `scale` pixels to the ui's unit, run each
// frame; returns whether jump_t changed and whether there was input to draw the ui again
// for. It allocates (ui's input and text), as the tuning panel does: a tool on the Mac.
fn jump_frame(scale: f32, input: bool) -> bool, bool {
    if jump_ui.id == 0 {
        jump_ui = ui::create(16.0, scale);
        guard jump_ui.id != 0 else { abort(str("ui: ", ui::error())); }
    }
    let c = jump_ui;
    ui::input_from_gfx(c);
    let was = jump_t;
    let ss = gfx::screen_size();
    let w: f32 = 640.0;
    let x = 0.5 * (ss.x / scale - w);
    let y = ss.y / scale - 64.0;
    if ui::begin(c, "jump", ui::rect(x, y, w, 48.0), ui::WINDOW_NO_SCROLLBAR) {
        let ratios: f32[2] = [0.45, 0.55];
        ui::layout_row(c, ui::DYNAMIC, 30.0, ratios);
        var text: u8[>..] = [];
        text.append("jump ");
        panel::num(text, jump_t);
        text.append(" (J)  shadow ");
        text.append(render3d::shadow_look_name(shadow_look));
        text.append(" (H)");
        ui::label(c, text, ui::TEXT_LEFT);
        ui::slider_float(c, 0.0, jump_t, 1.0, 0.01);
    }
    ui::end(c);
    return jump_t != was, input;
}

// The camera and the jump as the flags that give the shot again.
fn print_jump(cam: Camera) {
    var line: u8[>..] = [];
    line.append("jump: --jump ");
    panel::num(line, jump_t);
    line.append(" --yaw ");
    panel::num(line, cam.yaw);
    line.append(" --pitch ");
    panel::num(line, cam.pitch);
    line.append(" --distance ");
    panel::num(line, distance);
    if arc != 1.0 {
        line.append(" --arc ");
        panel::num(line, arc);
    }
    print(line);
}

fn radians32(d: f32) -> f32 { d * PI / 180.0 }

// The zoom (Z, --zoom N): the screen shows a 1/zoom crop of the view round `centre` (in
// the full view's clip space), drawn at 1/zoom of the screen's pixels, as the full view
// draws that part, and magnified zoom × zoom a pixel with no filtering, to see what the
// antialiasing (A: MSAA, SMAA, none) does to each pixel. A drag pans the crop.
var zoom:   i32    = 1;
var centre: float2 = float2 { 0.0, 0.0 };
var aa:     i32    = render3d::AA;

// The shadow's look (H, --shadows 9|9wide|16|4|disc; task 086): render3d::SHADOW_9, the
// app's on a tablet or a desktop, or one tried against it.
var shadow_look: i32 = render3d::SHADOW_9;
var nearest = gfx::Sampler { 0 };
var label = default<ui::Context>();

// The view's matrices for the camera at the screen's aspect.
fn view_of(cam: Camera, size: int2) -> gfx::mat4 {
    let yaw = radians32(cam.yaw);
    let pitch = radians32(cam.pitch);
    let target = target();
    let eye = target + float3 { sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch) } * distance;
    let aspect = size.x as f32 / size.y;
    let proj = gfx::perspective(radians32(FOV), aspect, 2.0, 40.0);
    return gfx::mul(proj, gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 }));
}

fn eye_of(cam: Camera) -> float3 {
    let yaw = radians32(cam.yaw);
    let pitch = radians32(cam.pitch);
    return target() + float3 { sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch) } * distance;
}

// Where the board's near left corner is in the full view's clip space.
fn corner(cam: Camera) -> float2 {
    let p = gfx::mul(view_of(cam, gfx::screen_size()), float4 { -4.55, 0.0, 4.55, 1.0 });
    return float2 { p.x / p.w, p.y / p.w };
}

// Draws a frame from the camera into gfx's screen (or for Texture { 0 } the kept image,
// under the tuning panel). Zoomed, into the kept image at 1/zoom and magnified onto the
// screen.
fn draw(g: render3d::Gpu&, cam: Camera, out: gfx::Texture = gfx::screen()) {
    let size = gfx::screen_size();
    let view_proj = view_of(cam, size);
    if zoom == 1 {
        render3d::draw(g, view_proj, eye_of(cam), out, size, shadow_every);
        return;
    }
    let small = int2 { (size.x + zoom - 1) / zoom, (size.y + zoom - 1) / zoom };
    // Scaled by the screen's pixels to the small image's, so a pixel of the small image
    // is exactly one of the full view's.
    let crop = gfx::mul(gfx::scale(float3 { size.x as f32 / small.x, size.y as f32 / small.y, 1.0 }),
                        gfx::translate(float3 { -centre.x, -centre.y, 0.0 }));
    render3d::draw(g, gfx::mul(crop, view_proj), eye_of(cam), gfx::Texture { 0 }, small, shadow_every);
    gfx::begin_pass(gfx::screen(), gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
    let keep = g.linear;
    g.linear = nearest;
    // show() reads its source rect as a part of `size` (the kept image is the screen's
    // size in the app): the whole small image, magnified.
    render3d::show(g, float4 { 0.0, 0.0, size.x, size.y },
                   float4 { 0.0, 0.0, small.x * zoom, small.y * zoom }, 1.0, size);
    g.linear = keep;
    gfx::end_pass();
}

fn aa_name(a: i32) -> const u8[:] {
    if a == render3d::AA_MSAA { return "MSAA 4x"; }
    if a == render3d::AA_SMAA { return "SMAA"; }
    return "no antialiasing";
}

// The label over the screen: the antialiasing shown and the zoom.
fn draw_label(scale: f32) {
    if label.id == 0 {
        label = ui::create(18.0, scale);
        guard label.id != 0 else { abort(str("ui: ", ui::error())); }
    }
    ui::input_from_gfx(label);   // also starts the ui's frame
    if ui::begin(label, "aa", ui::rect(12.0, 12.0, 460.0, 44.0), ui::WINDOW_NO_INPUT | ui::WINDOW_NO_SCROLLBAR) {
        ui::layout_row_dynamic(label, 26.0, 1);
        ui::label(label, str(aa_name(aa), " (A)   ", zoom, "x (Z)   shadow ", render3d::shadow_look_name(shadow_look), " (H)"),
                  ui::TEXT_LEFT);
    }
    ui::end(label);
    ui::render(label);
}

// The wood's model --wood or W chose, -1 for each look's own (looks::wood_for), and
// summer's variant (--summer, S), autumn's and winter's (--autumn, --winter).
var wood_chosen: i64 = -1;
var summer:      i64 = 0;
var autumn:      i64 = 0;
var winter:      i64 = 0;

// The look for a season: summer's, autumn's and winter's their variant's.
fn look_of(season: i64) -> i64 {
    if season == looks::SUMMER { return looks::summer_look(summer); }
    if season == looks::AUTUMN { return looks::autumn_look(autumn); }
    if season == looks::WINTER { return looks::winter_look(winter); }
    return season;
}

// A season's variants (looks::SUMMERS, AUTUMNS, WINTERS; 1 for spring, whose looks G
// switches), the one chosen, and choosing one.
fn variants(season: i64) -> i64 {
    if season == looks::SUMMER { return looks::SUMMERS; }
    if season == looks::AUTUMN { return looks::AUTUMNS; }
    if season == looks::WINTER { return looks::WINTERS; }
    return 1;
}
fn variant(season: i64) -> i64 {
    return if season == looks::SUMMER { summer } else if season == looks::AUTUMN { autumn }
           else if season == looks::WINTER { winter } else { 0 };
}
fn set_variant(season: i64, v: i64) {
    if season == looks::SUMMER { summer = v; }
    if season == looks::AUTUMN { autumn = v; }
    if season == looks::WINTER { winter = v; }
}

// Puts look `which` on the board, with its own wood's model and finish if it has one,
// timed.
fn apply(g: render3d::Gpu&, which: i64) {
    let c = clock();
    let shown = looks::shown(which, g.spring);
    let own = looks::wood_for(shown);
    let wood = if wood_chosen >= 0 { wood_chosen } else if own >= 0 { own } else { model3d::WOOD_MODEL };
    if wood != g.wood || own >= 0 || looks::wood_for(looks::shown(g.look, g.spring)) >= 0 {
        render3d::choose(g, wood, -1);
        g.finish = looks::finish_for(shown, g.wood);
    }
    render3d::apply(g, which, 8);
    print("theme ", which, " applied in ", ((clock() - c) * 1000.0) as i64, " ms (wood ", g.wood,
          ", marble ", g.marble, ", spring ", g.spring, ")");
}

// Keeps the camera in its mode's range.
fn clamp_camera(cam: Camera&) {
    if cam.free {
        cam.pitch = clamp(cam.pitch, FREE_PITCH_LO, FREE_PITCH_HI);
        if cam.yaw > 180.0 { cam.yaw -= 360.0; }
        if cam.yaw < -180.0 { cam.yaw += 360.0; }
    } else {
        cam.pitch = clamp(cam.pitch, INSPECT_PITCH_LO, INSPECT_PITCH_HI);
        cam.yaw = clamp(cam.yaw, -INSPECT_YAW, INSPECT_YAW);
    }
}

fn flag_f32(argv: u8[:][>..]&, name: const u8[:], value: f32) -> f32 {
    for a, i in argv {
        if a == name && i + 1 < argv.len {
            let v, ok = parse_flt(argv[i + 1]);
            if ok { return v as f32; }
        }
    }
    return value;
}

fn flag_str(argv: u8[:][>..]&, name: const u8[:]) -> i64 {
    for a, i in argv {
        if a == name && i + 1 < argv.len { return i + 1; }
    }
    return -1;
}

fn main() {
    let argv = args();
    var w = 1280;
    var h = 800;
    let si = flag_str(argv, "--size");
    if si > 0 {
        let a, b, ok = split_once(argv[si], "x");
        if ok {
            let x, okx = parse_int(a);
            let y, oky = parse_int(b);
            if okx && oky {
                w = x;
                h = y;
            }
        }
    }
    let shot = flag_str(argv, "--shot");
    let bench = flag_str(argv, "--bench");
    // --frames N runs the window's loop hidden for N frames, with a drag, T, K and a long
    // press injected (the press needs N of about 200 to last), and saves the last frame
    // to --shot's path if given: the loop checked without a window in the way.
    // With --panel the panel shows from the start; with --frames too, the injected
    // input works the panel instead: P twice (hidden, shown), a drag along the varnish
    // slider and its release (one bake), Print, M (the marble, in winter).
    let frames_at = flag_str(argv, "--frames");
    var with_panel = false;
    for a in argv { if a == "--panel" { with_panel = true; } }
    var frames = -1;
    if frames_at > 0 {
        let n, ok = parse_int(argv[frames_at]);
        if ok { frames = n; }
    }
    samples = clamp(flag_f32(argv, "--samples", render3d::SAMPLES) as i32, 1, 8);
    for a in argv { if a == "--shadow-every" { shadow_every = true; } }
    // On Android the window is the whole screen, and --bench times frames in it.
    var android_root: u8[>..] = [];
    let on_android = env("ANDROID_ROOT", android_root);
    var flags = if frames > 0 { gfx::WINDOW_HIDDEN } else { gfx::WINDOW_RESIZABLE };
    for a in argv { if a == "--full" { flags |= gfx::WINDOW_FULLSCREEN; } }
    if on_android { flags = gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE; }
    let headless = frames < 0 && (shot > 0 || (bench > 0 && !on_android));
    let opened = if headless { gfx::open_headless(w, h) }
                 else { gfx::open("Draughts 3D", w, h, flags) };
    guard opened else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    // --theme autumn|winter|spring|summer; T, or a long press (for touch), switches.
    var which = looks::AUTUMN;
    let ti = flag_str(argv, "--theme");
    if ti > 0 && argv[ti] == "winter" { which = looks::WINTER; }
    if ti > 0 && argv[ti] == "spring" { which = looks::SPRING; }
    if ti > 0 && argv[ti] == "summer" { which = looks::SUMMER; }
    // --summer N: summer's variant (and summer).
    let si2 = flag_str(argv, "--summer");
    if si2 > 0 {
        summer = clamp(flag_f32(argv, "--summer", 0.0) as i64, 0, looks::SUMMERS - 1);
        which = looks::SUMMER;
    }
    // --autumn N, --winter N: autumn's and winter's variant (and the season).
    if flag_str(argv, "--autumn") > 0 {
        autumn = clamp(flag_f32(argv, "--autumn", 0.0) as i64, 0, looks::AUTUMNS - 1);
        which = looks::AUTUMN;
    }
    if flag_str(argv, "--winter") > 0 {
        winter = clamp(flag_f32(argv, "--winter", 0.0) as i64, 0, looks::WINTERS - 1);
        which = looks::WINTER;
    }
    // --jump T: the jump at T of the way (J switches it), --arc H its height in squares,
    // --distance D the camera's.
    if flag_str(argv, "--jump") > 0 {
        jumping = true;
        jump_t = clamp(flag_f32(argv, "--jump", 0.5), 0.0, 1.0);
        distance = JUMP_DISTANCE;
    }
    arc = max(flag_f32(argv, "--arc", 1.0), 0.0);
    distance = clamp(flag_f32(argv, "--distance", distance), 3.0, 40.0);
    let ki = flag_str(argv, "--king");
    if ki > 0 && argv[ki] == "crown" { king_crown = true; }

    let t0 = clock();
    var g = default<render3d::Gpu>();
    // --shadow few: the shadow in 4 taps, as a phone's app draws it (render3d::set_shadow).
    let fi = flag_str(argv, "--shadow");
    render3d::setup(g, samples, fi > 0 && argv[fi] == "few");
    if fi > 0 && argv[fi] == "few" { shadow_look = render3d::SHADOW_4; }
    let wi = flag_str(argv, "--shadows");
    if wi > 0 {
        let names = ["9", "9wide", "16", "4", "disc"];
        for name, i in names { if argv[wi] == name { shadow_look = i as i32; } }
    }
    render3d::set_shadow_look(g, shadow_look);
    nearest = gfx::sampler(gfx::NEAREST, gfx::CLAMP);
    // --aa msaa|smaa|off (A cycles), --zoom N (Z switches between 1 and 4).
    let ai = flag_str(argv, "--aa");
    if ai > 0 && argv[ai] == "smaa" { aa = render3d::AA_SMAA; }
    if ai > 0 && argv[ai] == "off" { aa = render3d::AA_OFF; }
    render3d::set_aa(g, aa);
    zoom = clamp(flag_f32(argv, "--zoom", 1.0) as i32, 1, 16);
    // --wood N, --marble N: the wood's model with its finish, and the winter frame's
    // marble (0 the slate); --plain takes the finish off (looks::PLAIN), to compare.
    if flag_str(argv, "--wood") > 0 {
        wood_chosen = clamp(flag_f32(argv, "--wood", 0.0) as i64, 0, model3d::WOOD_MODELS - 1);
    }
    render3d::choose(g, wood_chosen, flag_f32(argv, "--marble", looks::MARBLE) as i64,
                     flag_f32(argv, "--spring", looks::SPRING_LOOK) as i64);
    apply(g, look_of(which));
    for a in argv {
        if a == "--plain" {
            g.finish = looks::PLAIN;
            render3d::bake_surfaces(g);
        }
    }
    place(g);
    print("setup ", ((clock() - t0) * 1000.0) as i64, " ms");

    // --save-maps PREFIX: the baked frame map and plan as they are (PREFIX-frame.png,
    // PREFIX-plan.png), to see a figure flat.
    let maps = flag_str(argv, "--save-maps");
    if maps > 0 {
        gfx::save_png(g.frame_albedo, str(argv[maps], "-frame.png"));
        gfx::save_png(g.plan_albedo, str(argv[maps], "-plan.png"));
    }
    var cam = Camera { flag_f32(argv, "--yaw", 0.0), flag_f32(argv, "--pitch", PITCH), jumping };
    centre = corner(cam);
    // --turn D (with --shot): the board turned D degrees under the light, as the game's
    // hot-seat turn does (render3d::turn_light), the camera with it.
    let turn = flag_f32(argv, "--turn", 0.0);
    if turn != 0.0 {
        render3d::turn_light(g, turn);
        cam.yaw += turn;
    }
    if shot > 0 && frames < 0 {
        draw(g, cam);
        let ok = gfx::screenshot(argv[shot]);
        print("saved ", argv[shot], ": ", ok);
        return;
    }
    if bench > 0 {
        let n0, ok = parse_int(argv[bench]);
        guard ok else { return; }
        bench_frames(g, cam, min(n0, 1024), headless);
        return;
    }

    var events: gfx::Event[64] = [default<gfx::Event>(); 64];
    var tuning = panel::new(g);
    let ui_scale = max(gfx::screen_size().x as f32 / w, 1.0);
    if with_panel { panel::toggle(tuning, ui_scale); }
    var ui_dirty = false;
    var knob: f32 = 0.0;   // where --frames --panel grabs the varnish slider
    var dirty = true;
    var drawn = 0;
    var cpu: f64 = 0.0;
    var frame = 0;
    var size = int2 { 0, 0 };
    var press_at:    f64 = -1.0;   // when the held button went down; -1 once it is used
    var press_moved: f32 = 0.0;
    while gfx::frame() {
        if frames > 0 && with_panel {
            // The panel's script: P hides and shows it, a drag on varnish, Print, M.
            let va = tuning.varnish_at;
            let pa = tuning.print_at;
            let vy = va.y + va.h * 0.5;
            if frame == 1 { gfx::inject_focus(true); }
            if frame == 2 { gfx::inject_key("P", true); }
            if frame == 3 { gfx::inject_key("P", false); }
            if frame == 4 { gfx::inject_key("P", true); }
            if frame == 5 { gfx::inject_key("P", false); }
            // Nuklear's slider drags from its knob, which stands at the value (0..1).
            if frame == 8 { knob = va.x + va.w * tuning.finish.varnish; }
            if frame == 8 { gfx::inject_mouse(knob, vy, 0, false); }
            if frame == 9 { gfx::inject_mouse(knob, vy, gfx::MOUSE_LEFT, true); }
            if frame > 9 && frame < 16 { gfx::inject_mouse(knob + va.w * (frame - 9) * 0.04, vy, 0, true); }
            if frame == 16 { gfx::inject_mouse(knob + va.w * 0.24, vy, gfx::MOUSE_LEFT, false); }
            if frame == 20 { gfx::inject_mouse(pa.x + pa.w * 0.5, pa.y + pa.h * 0.5, 0, false); }
            if frame == 21 { gfx::inject_mouse(pa.x + pa.w * 0.5, pa.y + pa.h * 0.5, gfx::MOUSE_LEFT, true); }
            if frame == 22 { gfx::inject_mouse(pa.x + pa.w * 0.5, pa.y + pa.h * 0.5, gfx::MOUSE_LEFT, false); }
            if frame == 25 { gfx::inject_key("M", true); }
            if frame == 26 { gfx::inject_key("M", false); }
            if frame == frames { break; }
            frame++;
        } else if frames > 0 {
            // A drag across the first frames: press, move left and up, release.
            if frame == 1 { gfx::inject_focus(true); }
            if frame == 2 { gfx::inject_mouse(400.0, 400.0, gfx::MOUSE_LEFT, true); }
            if frame > 2 && frame < 12 {
                gfx::inject_mouse(400.0 - (frame - 2) * 8.0, 400.0 - (frame - 2) * 4.0, 0, true);
            }
            if frame == 12 { gfx::inject_mouse(328.0, 364.0, gfx::MOUSE_LEFT, false); }
            // Then T, K, and a long press held still: the theme switches twice, the king
            // once.
            if frame == 14 { gfx::inject_key("T", true); }
            if frame == 15 { gfx::inject_key("T", false); }
            if frame == 16 { gfx::inject_key("K", true); }
            if frame == 17 { gfx::inject_key("K", false); }
            if frame == 20 { gfx::inject_mouse(328.0, 364.0, gfx::MOUSE_LEFT, true); }
            if frame == frames - 1 { gfx::inject_mouse(328.0, 364.0, gfx::MOUSE_LEFT, false); }
            if frame == frames { break; }
            frame++;
        }
        let n = min(gfx::events_into(events), 64);
        let now = clock();
        if gfx::key_pressed("P") {
            panel::toggle(tuning, ui_scale);
            dirty = true;
        }
        if tuning.shown {
            if panel::frame(tuning, now, n > 0) { ui_dirty = true; }
            if panel::settle(tuning, g, now) { dirty = true; }
        }
        // The jump's slider and keys.
        if jumping {
            let moved, input = jump_frame(ui_scale, n > 0);
            if input { ui_dirty = true; }
            var t = jump_t;
            if gfx::key_pressed("Left") { t = floor((t - 0.01) * 100.0 + 0.5) / 100.0; }
            if gfx::key_pressed("Right") { t = floor((t + 0.01) * 100.0 + 0.5) / 100.0; }
            jump_t = clamp(t, 0.0, 1.0);
            if moved || t != jump_t || gfx::key_pressed("Left") || gfx::key_pressed("Right") {
                place(g);
                dirty = true;
            }
            let wheel = gfx::mouse_wheel();
            if wheel != 0.0 {
                distance = clamp(distance * pow(0.92 as f32, wheel), 3.0, 40.0);
                dirty = true;
            }
        }
        if gfx::key_pressed("J") {
            jumping = !jumping;
            distance = if jumping { JUMP_DISTANCE } else { DISTANCE };
            cam.free = cam.free || jumping;
            place(g);
            dirty = true;
        }
        if jumping && gfx::key_pressed("V") { print_jump(cam); }
        // The mouse over the panel or the jump's slider, or dragging on either, is theirs.
        let mine = !panel::wants_mouse(tuning) && !(jumping && ui::wants_mouse(jump_ui));
        for i in n {
            let e = events[i];
            if jumping && e.kind == gfx::EVENT_MOUSE_BUTTON && !e.down && e.button == gfx::MOUSE_LEFT { print_jump(cam); }
            if e.kind == gfx::EVENT_MOUSE_BUTTON && e.down && e.clicks == 2 && mine {
                cam.free = !cam.free;
                dirty = true;
            }
            if e.kind == gfx::EVENT_MOUSE_BUTTON && e.button == gfx::MOUSE_LEFT {
                press_at = if e.down && mine { clock() } else { -1.0 };
                press_moved = 0.0;
            }
        }
        var switch = gfx::key_pressed("T");
        if press_at >= 0.0 && gfx::mouse_down(gfx::MOUSE_LEFT) {
            let d = gfx::mouse_delta();
            press_moved += abs(d.x) + abs(d.y);
            if press_moved > LONG_PRESS_SLOP { press_at = -1.0; }
            else if clock() - press_at > LONG_PRESS {
                switch = true;
                press_at = -1.0;
            }
        }
        if switch {
            which = (which + 1) % looks::COUNT;
            apply(g, look_of(which));
            panel::sync(tuning, g);
            dirty = true;
        }
        if gfx::key_pressed("S") {
            summer = if which == looks::SUMMER { (summer + 1) % looks::SUMMERS } else { summer };
            which = looks::SUMMER;
            apply(g, look_of(which));
            print("summer ", summer);
            panel::sync(tuning, g);
            dirty = true;
        }
        if gfx::key_pressed("Escape") { break; }
        if gfx::key_pressed("Tab") {
            cam.free = !cam.free;
            dirty = true;
        }
        if gfx::key_pressed("K") {
            king_crown = !king_crown;
            place(g);
            dirty = true;
        }
        if gfx::key_pressed("W") {
            let c = clock();
            render3d::set_wood(g, (g.wood + 1) % model3d::WOOD_MODELS);
            wood_chosen = g.wood;
            print("wood ", g.wood, " baked in ", (clock() - c) * 1000.0, " ms");
            panel::sync(tuning, g);
            dirty = true;
        }
        if gfx::key_pressed("G") {
            // Spring's look (task 041): the birch or the carved stone, on spring.
            if which != looks::SPRING {
                which = looks::SPRING;
                apply(g, which);
            }
            let c = clock();
            render3d::carve(g, (g.spring + 1) % looks::SPRINGS, g.carving);
            print("spring ", g.spring, " baked in ", (clock() - c) * 1000.0, " ms");
            panel::sync(tuning, g);
            dirty = true;
        }
        if gfx::key_pressed("M") {
            let next = (g.marble + 1) % looks::MARBLES;
            let c = clock();
            render3d::tune(g, g.wood, g.finish, next, looks::marble(next));
            print("marble ", g.marble, " baked in ", (clock() - c) * 1000.0, " ms");
            panel::sync(tuning, g);
            dirty = true;
        }
        if gfx::key_pressed("R") {
            cam = Camera { 0.0, PITCH, cam.free };
            distance = if jumping { JUMP_DISTANCE } else { DISTANCE };
            centre = corner(cam);
            dirty = true;
        }
        if gfx::key_pressed("A") {
            aa = if aa == render3d::AA_MSAA { render3d::AA_SMAA } else if aa == render3d::AA_SMAA { render3d::AA_OFF }
                 else { render3d::AA_MSAA };
            render3d::set_aa(g, aa);
            print("antialiasing: ", aa_name(aa));
            dirty = true;
        }
        if gfx::key_pressed("H") {
            shadow_look = (shadow_look + 1) % render3d::SHADOW_LOOKS;
            render3d::set_shadow_look(g, shadow_look);
            print("shadow: ", render3d::shadow_look_name(shadow_look));
            dirty = true;
        }
        if gfx::key_pressed("Z") {
            zoom = if zoom == 1 { 4 } else { 1 };
            dirty = true;
        }
        // Zoomed, a drag pans the crop (a screen pixel is 2 / (size × zoom) of clip space).
        if zoom > 1 && gfx::mouse_down(gfx::MOUSE_LEFT) && mine {
            let d = gfx::mouse_delta();
            let ss = gfx::screen_size();
            if d.x != 0.0 || d.y != 0.0 {
                centre.x -= d.x * ui_scale * 2.0 / (ss.x * zoom);
                centre.y += d.y * ui_scale * 2.0 / (ss.y * zoom);
                dirty = true;
            }
        } else if gfx::mouse_down(gfx::MOUSE_LEFT) && mine {
            let d = gfx::mouse_delta();
            if d.x != 0.0 || d.y != 0.0 {
                cam.yaw -= d.x * DRAG;
                cam.pitch += d.y * DRAG;
                dirty = true;
            }
        }
        let s = gfx::screen_size();
        if s.x != size.x || s.y != size.y {
            size = s;
            dirty = true;
        }
        if dirty {
            clamp_camera(cam);
            let c = clock();
            // Under the panel the board goes into the kept image, so that the panel's
            // own changes cost only the copy.
            draw(g, cam, if tuning.shown || jumping { gfx::Texture { 0 } } else { gfx::screen() });
            if !tuning.shown && !jumping { draw_label(ui_scale); }
            cpu += clock() - c;
            drawn++;
        }
        if (tuning.shown || jumping) && (dirty || ui_dirty) {
            gfx::begin_pass(gfx::screen(), gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
            render3d::copy(g);
            gfx::end_pass();
            if tuning.shown { panel::draw(tuning); }
            if jumping { ui::render(jump_ui); }
        }
        dirty = false;
        ui_dirty = false;
    }
    if frames > 0 {
        print("camera yaw ", cam.yaw, " pitch ", cam.pitch);
        if shot > 0 { print("saved ", argv[shot], ": ", gfx::screenshot(argv[shot])); }
    }
    if drawn > 0 { print(drawn, " frames drawn, cpu ", cpu * 1000.0 / drawn, " ms each"); }
}

fn median(xs: f64[..1024]&) -> f64 {
    sort(xs[..xs.len]);
    return xs[xs.len / 2] * 1000.0;
}

// --bench N: the first frame (with the shadow map), then N frames turning the camera, each
// waited for: the CPU's part (recording) and with the submit and the wait for the GPU. In
// a window (Android) also N frames presented as the loop does, frame to frame.
fn bench_frames(g: render3d::Gpu&, cam_in: Camera, n: i64, headless: bool) {
    var cam = cam_in;
    // Each marble's bake (the frame map and its mips, waited for), twice, the second
    // timed; then the chosen one again.
    let chosen = g.marble;
    for m in looks::MARBLES {
        var ms: f64 = 0.0;
        for k in 2 {
            let c = clock();
            render3d::tune(g, g.wood, g.finish, m, looks::marble(m));
            ms = (clock() - c) * 1000.0;
            render3d::tune(g, g.wood, g.finish, (m + 1) % looks::MARBLES, looks::marble((m + 1) % looks::MARBLES));
        }
        print("bench: marble ", m, " baked in ", ms, " ms");
    }
    render3d::tune(g, g.wood, g.finish, chosen, looks::marble(chosen));
    // In summer, autumn and winter, each variant's bake (the plan and the frame map, their
    // mips, waited for), twice, the second timed, with its own wood; then the chosen one
    // again. A look's photograph is its season's.
    let season = looks::get(g.look).photo;
    let count = variants(season);
    if count > 1 {
        let kept = variant(season);
        for v in count {
            var ms: f64 = 0.0;
            for k in 2 {
                set_variant(season, (v + 1) % count);
                apply(g, look_of(season));
                set_variant(season, v);
                let c = clock();
                apply(g, look_of(season));
                ms = (clock() - c) * 1000.0;
            }
            print("bench: season ", season, " variant ", v, " baked in ", ms, " ms");
        }
        set_variant(season, kept);
        apply(g, look_of(season));
    }
    // On spring, each of its looks' bakes (the plan and the frame map, waited for; task
    // 041), twice, the second timed; then the chosen one again.
    if g.look == looks::SPRING {
        let look = g.spring;
        for s in looks::SPRINGS {
            var ms: f64 = 0.0;
            for k in 2 {
                render3d::carve(g, (s + 1) % looks::SPRINGS, g.carving);
                let c = clock();
                render3d::carve(g, s, g.carving);
                ms = (clock() - c) * 1000.0;
            }
            print("bench: spring ", s, " baked in ", ms, " ms");
        }
        render3d::carve(g, look, g.carving);
    }
    if !headless {
        // Let the window reach its size and the swapchain settle.
        for i in 30 {
            guard gfx::frame() else { return; }
            let c = clock();
            draw(g, cam);
            if i == 0 {
                gfx::flush();
                print("bench: first frame, pipelines made ", (clock() - c) * 1000.0, " ms");
            }
        }
        gfx::flush();
        g.shadow_dirty = true;
    }
    let size = gfx::screen_size();
    var c0 = clock();
    draw(g, cam);
    gfx::flush();
    print("bench ", size.x, "x", size.y, " samples ", samples, " shadow-every ", shadow_every,
          ": first frame ", (clock() - c0) * 1000.0, " ms");
    var cpu: f64[..1024] = [];
    var all: f64[..1024] = [];
    for i in n {
        cam.yaw = (i % 40) - 20.0;
        let c = clock();
        draw(g, cam);
        let d = clock();
        gfx::flush();
        cpu.push(d - c);
        all.push(clock() - c);
    }
    print("bench: median cpu ", median(cpu), " ms, cpu+gpu waited ", median(all),
          " ms a frame (", n, " frames)");
    if headless { return; }
    var gap: f64[..1024] = [];
    var last = clock();
    for i in n {
        guard gfx::frame() else { return; }
        let now = clock();
        if i > 0 { gap.push(now - last); }
        last = now;
        cam.yaw = (i % 40) - 20.0;
        draw(g, cam);
    }
    print("bench: median presented frame to frame ", median(gap), " ms");
}
