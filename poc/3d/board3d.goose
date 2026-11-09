// Task 015's 3D board prototype: the board in autumn wood or winter stone and a fixed
// position, drawn natively with goose_gfx through the renderer the app shares
// (src/render3d/), floating in front of the season's photograph. A drag turns the camera;
// Tab or a double click switches between inspecting round the default view and turning
// freely round the board; R resets the view; T, or a long press for touch, switches the
// theme; K switches the king between a stack of two discs and one crowned disc; W cycles
// the wood's model (task 039). Nothing of the app's shell.
//
//   cd poc/3d
//   ../../build/goose-v2026.4-macos-arm64/goose build -o ../../build/board3d board3d.goose
//   ../../build/board3d
//   ../../build/board3d --shot out.png --size 1920x1200 [--yaw 20 --pitch 40]
//   ../../build/board3d --theme winter --king crown
//   ../../build/board3d --wood 0                  # the wood's model: 0 to 3, 2 the default
//   ../../build/board3d --bench 200
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
import render3d from "../../src/render3d";

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
// squares the field's occlusion reads (top, foot, radius, occupied), no marks, and where
// the selected piece stands; the shadow map follows.
fn place(g: render3d::Gpu&) {
    var inst:    float4[..64] = [];
    var squares: float4[100]  = [float4_0; 100];
    var marks:   float4[100]  = [float4 { 0.0, 0.0, 0.0, -1.0 }; 100];
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
        squares[p[0] * 8 + p[1]] = float4 { top, lift, RADIUS * scale, 1.0 };
        if sel { selected = float4 { x, lift, z, RADIUS * scale }; }
    }
    render3d::place(g, inst[..inst.len], squares[..], marks[..], selected, true);
}

fn radians32(d: f32) -> f32 { d * PI / 180.0 }

// Draws a frame from the camera into gfx's screen.
fn draw(g: render3d::Gpu&, cam: Camera) {
    let size = gfx::screen_size();
    let yaw = radians32(cam.yaw);
    let pitch = radians32(cam.pitch);
    let target = float3 { 0.0, -0.15, 1.1 };
    let eye = target + float3 { sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch) } * DISTANCE;
    let aspect = size.x as f32 / size.y;
    let proj = gfx::perspective(radians32(FOV), aspect, 2.0, 40.0);
    let view_proj = gfx::mul(proj, gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 }));
    render3d::draw(g, view_proj, eye, gfx::screen(), size, shadow_every);
}

// Puts theme `which` on the board, timed.
fn apply(g: render3d::Gpu&, which: i64) {
    let c = clock();
    render3d::apply(g, which, 8);
    print("theme ", which, " applied in ", ((clock() - c) * 1000.0) as i64, " ms (wood ", g.wood, ")");
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
    let frames_at = flag_str(argv, "--frames");
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
    if on_android { flags = gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE; }
    let headless = frames < 0 && (shot > 0 || (bench > 0 && !on_android));
    let opened = if headless { gfx::open_headless(w, h) }
                 else { gfx::open("Draughts 3D", w, h, flags) };
    guard opened else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();

    // --theme autumn|winter; T, or a long press (for touch), switches.
    var which = looks::AUTUMN;
    let ti = flag_str(argv, "--theme");
    if ti > 0 && argv[ti] == "winter" { which = looks::WINTER; }
    let ki = flag_str(argv, "--king");
    if ki > 0 && argv[ki] == "crown" { king_crown = true; }

    let t0 = clock();
    var g = default<render3d::Gpu>();
    render3d::setup(g, samples);
    g.wood = clamp(flag_f32(argv, "--wood", render3d::WOOD_MODEL) as i64, 0, render3d::WOOD_MODELS - 1);
    apply(g, which);
    place(g);
    print("setup ", ((clock() - t0) * 1000.0) as i64, " ms");

    var cam = Camera { flag_f32(argv, "--yaw", 0.0), flag_f32(argv, "--pitch", PITCH), false };
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
    var dirty = true;
    var drawn = 0;
    var cpu: f64 = 0.0;
    var frame = 0;
    var size = int2 { 0, 0 };
    var press_at:    f64 = -1.0;   // when the held button went down; -1 once it is used
    var press_moved: f32 = 0.0;
    while gfx::frame() {
        if frames > 0 {
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
        for i in n {
            let e = events[i];
            if e.kind == gfx::EVENT_MOUSE_BUTTON && e.down && e.clicks == 2 {
                cam.free = !cam.free;
                dirty = true;
            }
            if e.kind == gfx::EVENT_MOUSE_BUTTON && e.button == gfx::MOUSE_LEFT {
                press_at = if e.down { clock() } else { -1.0 };
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
            apply(g, which);
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
            render3d::set_wood(g, (g.wood + 1) % render3d::WOOD_MODELS);
            print("wood ", g.wood);
            dirty = true;
        }
        if gfx::key_pressed("R") {
            cam = Camera { 0.0, PITCH, cam.free };
            dirty = true;
        }
        if gfx::mouse_down(gfx::MOUSE_LEFT) {
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
            draw(g, cam);
            cpu += clock() - c;
            drawn++;
            dirty = false;
        }
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
