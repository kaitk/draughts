// Task 015's 3D board prototype: the autumn board and a fixed position, drawn natively
// with goose_gfx, floating in front of the season's photograph. A drag turns the camera;
// Tab or a double click switches between inspecting round the default view and turning
// freely round the board; R resets the view. Nothing of the app's shell.
//
//   cd poc/3d
//   ../../build/goose-v2026.4-macos-arm64/goose build -o ../../build/board3d board3d.goose
//   ../../build/board3d
//   ../../build/board3d --shot out.png --size 1920x1200 [--yaw 20 --pitch 40]
//   ../../build/board3d --bench 200
//
// --shot draws one frame headless (no window) into a PNG; --bench times frames.
//
// Frame structure (tasks/015-3d-board.md, "Prototype"): the shadow map is drawn only when
// the position changes; each drawn frame is one forward pass into a 4× multisampled
// target with depth, resolved into gfx's screen: the backdrop, the board's soft shadow,
// the board and pieces lit, the selection's glow added. Nothing is drawn while nothing
// changes.

import std;
import vec;
import math;
import os;
import gfx;
import mesh;
import shaders;

// The season's photograph (src/app/background.c, compiled from there): theme 0 is
// autumn's, decoded to `decoded` square where the GPU has no ASTC.
extern fn draughts_photo(kind: i64, decoded: i64) -> gfx::Texture;

// Laid out as the shaders' blocks (shaders::FRAME), std140: all vec4s and mat4s.
struct Frame {
    view_proj:       gfx::mat4,
    light_view_proj: gfx::mat4,
    eye:             float4,
    light_dir:       float4,
    light_color:     float4,
    sh:              float4[9],
    params:          float4,
    screen:          float4,
    glow:            float4,
    selected:        float4,
}
struct Draw { draw: float4 }
struct Bake { mode: float4, size: float4 }
struct Shrink { to: float4 }
struct Blur { dir: float4 }

let SHADOW_SIZE = 2048;
let PLAN_SIZE = 2048;
let STRIP_W = 4096;
let STRIP_H = 256;
let PHOTO_SIZE = 512;
let SAMPLES = 4;
// Measuring (--samples, --shadow-every): the multisampled target's samples, 1 drawing
// straight into the screen; and the shadow map redrawn every frame, not only on change.
var samples: i32 = SAMPLES;
var shadow_every = false;
let MAX_INSTANCES = 32;

// The camera: about 50° down, a 32° field of view. Inspecting keeps it near the default
// view; free turns it all round the board.
let FOV:              f32 = 32.0;
let DISTANCE:         f32 = 15.0;
let PITCH:            f32 = 50.0;
let INSPECT_YAW:      f32 = 35.0;
let INSPECT_PITCH_LO: f32 = 35.0;
let INSPECT_PITCH_HI: f32 = 75.0;
let FREE_PITCH_LO:    f32 = 20.0;
let FREE_PITCH_HI:    f32 = 85.0;
let DRAG:             f32 = 0.25; // degrees per pixel

struct Camera { yaw: f32, pitch: f32, free: bool }

// Everything on the GPU, made at startup (the targets again on a resize).
struct Gpu {
    board_vb:       gfx::Buffer,
    board_ib:       gfx::Buffer,
    board_count:    i64,
    piece_vb:       gfx::Buffer,
    piece_ib:       gfx::Buffer,
    piece_count:    i64,
    instances:      gfx::Buffer,
    instance_count: i64,
    squares:        gfx::Buffer,
    plan_albedo:    gfx::Texture,
    plan_normal:    gfx::Texture,
    strip_albedo:   gfx::Texture,
    strip_normal:   gfx::Texture,
    photo:          gfx::Texture,
    shadow_map:     gfx::Texture,
    color:          gfx::Texture,    // the multisampled target and its depth
    depth:          gfx::Texture,
    size:           int2,
    linear:         gfx::Sampler,
    wood:           gfx::Sampler,
    compare:        gfx::Sampler,
    lit:            gfx::Pipeline,
    shadow:         gfx::Pipeline,
    backdrop:       gfx::Pipeline,
    catcher:        gfx::Pipeline,
    glow:           gfx::Pipeline,
    frame:          Frame,
    shadow_dirty:   bool,
}

fn f4(v: float3, w: f32) -> float4 { float4 { v.x, v.y, v.z, w } }

// sRGB to linear, as the shaders take colors.
fn linear(c: f32) -> f32 {
    if c <= 0.04045 { return c / 12.92; }
    let e: f32 = 2.4;
    pow((c + 0.055) / 1.055, e)
}

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
let LIFT: f32 = 0.07;
let GROW: f32 = 1.05;

// Fills the instances (two float4s each: foot and scale; dark, crown, selected or
// stacked, seed) and the squares the field's occlusion reads (top, foot, radius,
// occupied), and says where the selected piece stands.
fn position(inst: float4[..64]&, squares: float4[64]&) -> float4 {
    var selected = float4_0;
    for p, i in PIECES {
        let x = p[1] as f32 - 3.5;
        let z = p[0] as f32 - 3.5;
        let dark: f32 = if p[2] == 1 { 1.0 } else { 0.0 };
        let sel = p[4] == 1;
        let lift:  f32 = if sel { LIFT } else { 0.0 };
        let scale: f32 = if sel { GROW } else { 1.0 };
        let seed = i as f32;
        var top = lift + mesh::HEIGHT * scale;
        if p[3] == 1 {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, 2.0, seed });
            inst.push(float4 { x, top, z, scale });
            inst.push(float4 { dark, 1.0, 0.0, seed + 0.5 });
            top += mesh::HEIGHT * scale;
        } else {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, if sel { 1.0 } else { 0.0 }, seed });
        }
        squares[p[0] * 8 + p[1]] = float4 { top, lift, mesh::RADIUS * scale, 1.0 };
        if sel { selected = float4 { x, lift, z, mesh::RADIUS * scale }; }
    }
    return selected;
}

// Nine spherical harmonics of the photograph's light, convolved with the cosine and over
// pi, so the shader's sum is the irradiance a white Lambert surface sends back. The
// photograph is laid over the sphere as a latitude-longitude map, its middle straight
// behind the board (-z), its top up.
fn harmonics(px: const u8[:], size: i64) -> float4[9] {
    var sh: float3[9] = [float3_0; 9];
    let step = 8;
    var total: f32 = 0.0;
    var y = step / 2;
    while y < size {
        let el = (0.5 - (y as f32 + 0.5) / size) * PI;
        let w = cos(el);
        var x = step / 2;
        while x < size {
            let az = ((x as f32 + 0.5) / size - 0.5) * TAU;
            let d = float3 { cos(el) * sin(az), sin(el), -cos(el) * cos(az) };
            let o = (y * size + x) * 4;
            let c = float3 { linear(px[o] / 255.0), linear(px[o + 1] / 255.0),
                             linear(px[o + 2] / 255.0) } * w;
            let b: f32[9] = [0.282095, 0.488603 * d.y, 0.488603 * d.z, 0.488603 * d.x,
                             1.092548 * d.x * d.y, 1.092548 * d.y * d.z,
                             0.315392 * (3.0 * d.y * d.y - 1.0), 1.092548 * d.x * d.z,
                             0.546274 * (d.x * d.x - d.z * d.z)];
            for k in 9 { sh[k] += c * b[k]; }
            total += w;
            x += step;
        }
        y += step;
    }
    // Each sample stands for 4 pi / total of the sphere; the bands' cosine lobes are
    // pi, 2 pi / 3 and pi / 4, and the result is over pi.
    let band: f32[3] = [1.0, 2.0 / 3.0, 0.25];
    var out: float4[9] = [float4_0; 9];
    // Half toward grey: the forest is orange, and its full color tinted everything.
    for k in 9 {
        let l = if k == 0 { 0 } else { if k < 4 { 1 } else { 2 } };
        let c = sh[k] * (4.0 * PI / total * band[l]);
        let grey = (c.x + c.y + c.z) / 3.0;
        out[k] = f4(lerp(c, float3 { grey, grey, grey }, 0.5), 0.0);
    }
    return out;
}

// The blurred photograph (src/app/scene.goose's way: shrunk to 512 on the GPU, two
// passes of a Gaussian of sigma 5.6 texels), and its harmonics.
fn photograph(full: const u8[:], sh: float4[9]&) -> gfx::Texture {
    let sharp = draughts_photo(0, 2048);
    let out = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);
    if sharp.id == 0 {
        // No photograph built in: the page under the scene, and a warm dim ambient.
        gfx::begin_pass(out, gfx::Texture { 0 }, float4 { 0.11, 0.078, 0.063, 1.0 });
        gfx::end_pass();
        for k in 9 { sh[k] = float4_0; }
        sh[0] = float4 { 0.25, 0.17, 0.1, 0.0 };
        return out;
    }
    let sampler = gfx::sampler(gfx::LINEAR, gfx::CLAMP);
    let small = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);
    let across = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);
    let shrink = gfx::pipeline(full, embed_shader("frag", shaders::SHRINK_FRAG));
    let blur = gfx::pipeline(full, embed_shader("frag", shaders::BLUR_FRAG));
    gfx::begin_pass(small, gfx::Texture { 0 }, float4_0);
    gfx::bind(shrink);
    gfx::bind_texture(gfx::FRAGMENT, 0, sharp, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Shrink { float4 { PHOTO_SIZE, PHOTO_SIZE, 0.0, 0.0 } });
    gfx::draw(3);
    gfx::end_pass();
    let s: f32 = 1.0 / PHOTO_SIZE;
    gfx::begin_pass(across, gfx::Texture { 0 }, float4_0);
    gfx::bind(blur);
    gfx::bind_texture(gfx::FRAGMENT, 0, small, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Blur { float4 { s, 0.0, 5.6, s } });
    gfx::draw(3);
    gfx::end_pass();
    gfx::begin_pass(out, gfx::Texture { 0 }, float4_0);
    gfx::bind(blur);
    gfx::bind_texture(gfx::FRAGMENT, 0, across, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Blur { float4 { 0.0, s, 5.6, s } });
    gfx::draw(3);
    gfx::end_pass();
    let px = gfx::read_pixels(out);
    sh = harmonics(px, PHOTO_SIZE);
    gfx::release(shrink);
    gfx::release(blur);
    gfx::release(sampler);
    gfx::release(small);
    gfx::release(across);
    gfx::release(sharp);
    return out;
}

// Bakes one wood surface into an albedo-and-roughness target and a normal target, both
// with their mips.
fn bake(pipe: gfx::Pipeline, w: i64, h: i64, mode: f32, extent: float2) -> gfx::Texture,
                                                                           gfx::Texture {
    let albedo = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8_SRGB,
                                                 usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                                 width: w as i32, height: h as i32, mips: 0 });
    let normal = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8,
                                                 usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                                 width: w as i32, height: h as i32, mips: 0 });
    var pass = gfx::PassDesc {};
    pass.color[0] = albedo;
    pass.color[1] = normal;
    gfx::begin_pass(pass);
    gfx::bind(pipe);
    gfx::uniforms(gfx::FRAGMENT, 0, Bake { float4 { mode, 0.0, 0.0, 0.0 },
                                           float4 { w, h, extent.x, extent.y } });
    gfx::draw(3);
    gfx::end_pass();
    gfx::generate_mips(albedo);
    gfx::generate_mips(normal);
    return albedo, normal;
}

fn targets(g: Gpu&, size: int2) {
    if g.color.id != 0 { gfx::release(g.color); }
    if g.depth.id != 0 { gfx::release(g.depth); }
    if samples > 1 {
        g.color = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8, usage: gfx::COLOR_TARGET,
                                                  width: size.x, height: size.y,
                                                  samples: samples });
    }
    g.depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH, usage: gfx::DEPTH_TARGET,
                                              width: size.x, height: size.y,
                                              samples: samples });
    g.size = size;
}

fn setup(g: Gpu&) {
    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    mesh::board(verts, indices);
    g.board_vb = gfx::vertex_buffer(bytes_of(verts));
    g.board_ib = gfx::index_buffer(bytes_of(indices));
    g.board_count = indices.len;
    verts.resize(0);
    indices.resize(0);
    mesh::piece(verts, indices);
    g.piece_vb = gfx::vertex_buffer(bytes_of(verts));
    g.piece_ib = gfx::index_buffer(bytes_of(indices));
    g.piece_count = indices.len;

    var inst:    float4[..64] = [];
    var squares: float4[64]   = [float4_0; 64];
    let selected = position(inst, squares);
    g.instances = gfx::buffer(gfx::BUFFER_STORAGE, MAX_INSTANCES * 32, bytes_of(inst));
    g.instance_count = inst.len / 2;
    g.squares = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(squares));

    let full = embed_shader("vert", shaders::FULL_VERT);
    gfx::flush();
    var t = clock();
    let bake_pipe = gfx::pipeline(full, embed_shader("frag", shaders::BAKE_FRAG));
    let span = 2.0 * mesh::INNER;
    g.plan_albedo, g.plan_normal = bake(bake_pipe, PLAN_SIZE, PLAN_SIZE, 0.0,
                                        float2 { span, span });
    g.strip_albedo, g.strip_normal = bake(bake_pipe, STRIP_W, STRIP_H, 1.0,
                                          float2 { 36.0, 1.4 });
    gfx::release(bake_pipe);
    gfx::flush();
    print("setup: bake ", ((clock() - t) * 1000.0) as i64, " ms");
    t = clock();

    var sh: float4[9] = [float4_0; 9];
    g.photo = photograph(full, sh);
    gfx::flush();
    print("setup: photograph ", ((clock() - t) * 1000.0) as i64, " ms");

    g.shadow_map = gfx::texture2d(SHADOW_SIZE, SHADOW_SIZE, gfx::DEPTH16,
                                  gfx::DEPTH_TARGET | gfx::SAMPLED);
    g.linear = gfx::sampler(gfx::LINEAR, gfx::CLAMP);
    g.wood = gfx::sampler(gfx::SamplerDesc { max_anisotropy: 8.0 });
    g.compare = gfx::shadow_sampler();

    let lit_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::LIT_VERT);
    let quad_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::QUAD_VERT);
    g.lit = gfx::pipeline(lit_vs, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                               shaders::LIT_FRAG),
                          gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true,
                                              depth_write: true });
    g.shadow = gfx::pipeline(lit_vs, embed_shader("frag", shaders::EMPTY_FRAG),
                             gfx::PipelineDesc { depth_test: true, depth_write: true,
                                                 depth_bias: 1.0, depth_bias_slope: 1.5 });
    g.backdrop = gfx::pipeline(full, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                                  shaders::BACKDROP_FRAG));
    g.catcher = gfx::pipeline(quad_vs, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                                    shaders::SHADOW_CATCHER_FRAG),
                              gfx::PipelineDesc { blend: gfx::BLEND_ALPHA });
    g.glow = gfx::pipeline(quad_vs, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                                 shaders::GLOW_FRAG),
                           gfx::PipelineDesc { depth_test: true, blend: gfx::BLEND_ADD });

    // The key light: warm, from the upper left and behind; the photograph's ambient.
    let l = normalize(float3 { -0.5, 0.95, -0.55 });
    let light_view = gfx::look_at(l * 20.0, float3_0, float3 { 0.0, 1.0, 0.0 });
    let reach: f32 = 6.6;
    let light_proj = gfx::ortho(-reach, reach, -reach, reach, 5.0, 35.0);
    g.frame = Frame {
        view_proj:       gfx::mat4_identity,
        light_view_proj: gfx::mul(light_proj, light_view),
        eye:             float4_0,
        light_dir:       f4(l, 3.4),
        light_color:     float4 { linear(1.0), linear(0.92), linear(0.8), 0.0 },
        sh:              sh,
        params:          float4 { 1.35, 1.0 / SHADOW_SIZE, 1.6, 0.0 },
        screen:          float4_0,
        glow:            float4 { 1.0, 0.843, 0.353, 0.0 },
        selected:        selected,
    };
    g.shadow_dirty = true;
}

fn radians32(d: f32) -> f32 { d * PI / 180.0 }

// Draws a frame: the shadow map first if the position changed, then the one pass.
fn draw(g: Gpu&, cam: Camera) {
    let size = gfx::screen_size();
    if size.x != g.size.x || size.y != g.size.y { targets(g, size); }
    let yaw = radians32(cam.yaw);
    let pitch = radians32(cam.pitch);
    let target = float3 { 0.0, -0.15, 0.25 };
    let eye = target + float3 { sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch) } *
                       DISTANCE;
    let aspect = size.x as f32 / size.y;
    let proj = gfx::perspective(radians32(FOV), aspect, 2.0, 40.0);
    g.frame.view_proj = gfx::mul(proj, gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 }));
    g.frame.eye = f4(eye, 1.0);
    g.frame.screen = float4 { size.x, size.y, 0.0, 0.0 };
    let f = g.frame;

    if g.shadow_dirty || shadow_every {
        var sp = gfx::PassDesc { depth: g.shadow_map };
        gfx::begin_pass(sp);
        gfx::bind(g.shadow);
        gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
        gfx::uniforms(gfx::VERTEX, 0, f);
        draw_meshes(g, 1.0);
        gfx::end_pass();
        g.shadow_dirty = false;
    }

    var pass = gfx::PassDesc { depth: g.depth, color_value: float4 { 0.11, 0.078, 0.063, 1.0 } };
    if samples > 1 {
        pass.color[0] = g.color;
        pass.resolve[0] = gfx::screen();
    } else {
        pass.color[0] = gfx::screen();
    }
    gfx::begin_pass(pass);
    gfx::bind(g.backdrop);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.photo, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::draw(3);

    gfx::bind(g.catcher);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4_0 });
    gfx::draw(6);

    gfx::bind(g.lit);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.plan_albedo, g.wood);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.plan_normal, g.wood);
    gfx::bind_texture(gfx::FRAGMENT, 2, g.strip_albedo, g.wood);
    gfx::bind_texture(gfx::FRAGMENT, 3, g.strip_normal, g.wood);
    gfx::bind_texture(gfx::FRAGMENT, 4, g.shadow_map, g.compare);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 0, g.squares);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    draw_meshes(g, 0.0);

    if f.selected.w > 0.0 {
        gfx::bind(g.glow);
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 1.0, 0.0, 0.0, 0.0 } });
        gfx::uniforms(gfx::FRAGMENT, 0, f);
        gfx::draw(6);
    }
    gfx::end_pass();
}

// The board, then the pieces as instances; from the light when `light` is 1.
fn draw_meshes(g: Gpu&, light: f32) {
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 0.0, light, 0.0, 0.0 } });
    gfx::bind_vertex_buffer(g.board_vb);
    gfx::bind_index_buffer(g.board_ib, 4);
    gfx::draw_indexed(g.board_count);
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 1.0, light, 0.0, 0.0 } });
    gfx::bind_vertex_buffer(g.piece_vb);
    gfx::bind_index_buffer(g.piece_ib, 4);
    gfx::draw_indexed_instanced(g.piece_count, g.instance_count);
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
    // --frames N runs the window's loop hidden for N frames, with a drag injected, and
    // saves the last frame to --shot's path if given: the loop checked without a window
    // in the way.
    let frames_at = flag_str(argv, "--frames");
    var frames = -1;
    if frames_at > 0 {
        let n, ok = parse_int(argv[frames_at]);
        if ok { frames = n; }
    }
    samples = clamp(flag_f32(argv, "--samples", SAMPLES) as i32, 1, 8);
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

    let t0 = clock();
    var g = default<Gpu>();
    setup(g);
    gfx::flush();
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
    while gfx::frame() {
        if frames > 0 {
            // A drag across the first frames: press, move left and up, release.
            if frame == 1 { gfx::inject_focus(true); }
            if frame == 2 { gfx::inject_mouse(400.0, 400.0, gfx::MOUSE_LEFT, true); }
            if frame > 2 && frame < 12 {
                gfx::inject_mouse(400.0 - (frame - 2) * 8.0, 400.0 - (frame - 2) * 4.0, 0, true);
            }
            if frame == 12 { gfx::inject_mouse(328.0, 364.0, gfx::MOUSE_LEFT, false); }
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
        }
        if gfx::key_pressed("Escape") { break; }
        if gfx::key_pressed("Tab") {
            cam.free = !cam.free;
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
        let size = gfx::screen_size();
        if size.x != g.size.x || size.y != g.size.y { dirty = true; }
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
fn bench_frames(g: Gpu&, cam_in: Camera, n: i64, headless: bool) {
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
