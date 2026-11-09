// Task 015's 3D board prototype: the board in autumn wood or winter stone (theme.goose)
// and a fixed position, drawn natively with goose_gfx, floating in front of the season's
// photograph. A drag turns the camera; Tab or a double click switches between inspecting
// round the default view and turning freely round the board; R resets the view; T, or a
// long press for touch, switches the theme; K switches the king between a stack of two
// discs and one crowned disc; W cycles the wood's model (task 039). Nothing of the app's
// shell.
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
import theme;

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
    light_piece:     float4,
    dark_piece:      float4,
    piece_fig:       float4,
    crown:           float4,
    edge:            float4,
    line:            float4,
    bounce:          float4,
    grade:           float4,
    tint:            float4,
    frame_build:     float4,
    frame_surface:   float4,
}
struct Draw { draw: float4 }
struct Bake {
    mode:          float4,
    size:          float4,
    light_sq:      float4,
    light_fig:     float4,
    dark_sq:       float4,
    dark_fig:      float4,
    inlay:         float4,
    inlay_fig:     float4,
    frame:         float4,
    frame_fig:     float4,
    surface:       float4,
    frame_surface: float4,
    stone:         float4,
    light_ring:    float4,
    dark_ring:     float4,
    frame_ring:    float4,
}
struct Shrink { to: float4 }
struct Blur { dir: float4 }

let SHADOW_SIZE = 2048;
let PLAN_SIZE = 2048;
let FRAME_MAP = 2048;
let PHOTO_SIZE = 512;
let SAMPLES = 4;
// Measuring (--samples, --shadow-every): the multisampled target's samples, 1 drawing
// straight into the screen; and the shadow map redrawn every frame, not only on change.
var samples: i32 = SAMPLES;
var shadow_every = false;
// The wood's model (--wood N, W cycles; task 039): 0 noise drawn out along the grain,
// 1 growth rings, 2 growth rings with pores and a fibre relief, 3 the first with thin
// lines and pores laid over it. A switch rebakes the surfaces, nothing else.
let WOOD_MODELS = 4;
var wood_model = 2;
let MAX_INSTANCES = 32;

// The camera: 52.5° down, a 31° field of view, framed as the 3D reference (fitted to its
// field corners). Inspecting keeps it near the default view; free turns it all round the
// board.
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
    frame_albedo:   gfx::Texture,
    frame_normal:   gfx::Texture,
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
    bake:           gfx::Pipeline,  // kept for a theme's rebake, with the photograph's
    shrink:         gfx::Pipeline,
    blur:           gfx::Pipeline,
    small:          gfx::Texture,
    across:         gfx::Texture,
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

// How a king is shown (--king stack|crown, K switches): a plain stack of two discs, or
// one disc with the crown debossed in its recess. The app will show one or the other.
var king_crown = false;

// Fills the instances (two float4s each: foot and scale; dark, 1 crowned or 0.5 a
// stack's upper disc, 1 selected or 2 a stack's lower disc, seed) and the squares the
// field's occlusion reads (top, foot, radius, occupied), and says where the selected
// piece stands.
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
        if p[3] == 1 && king_crown {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 1.0, 0.0, seed });
        } else if p[3] == 1 {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, 2.0, seed });
            inst.push(float4 { x, top, z, scale });
            inst.push(float4 { dark, 0.5, 0.0, seed + 0.5 });
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
fn harmonics(px: const u8[:], size: i64, toward_grey: f32) -> float4[9] {
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
    // Part way to grey (the theme's): autumn's forest is orange, and its full color
    // tinted everything.
    for k in 9 {
        let l = if k == 0 { 0 } else { if k < 4 { 1 } else { 2 } };
        let c = sh[k] * (4.0 * PI / total * band[l]);
        let grey = (c.x + c.y + c.z) / 3.0;
        out[k] = f4(lerp(c, float3 { grey, grey, grey }, toward_grey), 0.0);
    }
    return out;
}

// The theme's photograph blurred into g.photo (src/app/scene.goose's way: shrunk to 512
// on the GPU, two passes of a Gaussian of sigma 5.6 texels), and its harmonics, taken
// `grey` of the way to grey. Decodes the photograph, so only at startup and on a theme
// change, never in the frame loop.
fn photograph(g: Gpu&, kind: i64, grey: f32, sh: float4[9]&) {
    let sharp = draughts_photo(kind, 2048);
    if sharp.id == 0 {
        // No photograph built in: the page under the scene, and a dim ambient.
        gfx::begin_pass(g.photo, gfx::Texture { 0 }, float4 { 0.11, 0.078, 0.063, 1.0 });
        gfx::end_pass();
        for k in 9 { sh[k] = float4_0; }
        sh[0] = float4 { 0.25, 0.17, 0.1, 0.0 };
        return;
    }
    gfx::begin_pass(g.small, gfx::Texture { 0 }, float4_0);
    gfx::bind(g.shrink);
    gfx::bind_texture(gfx::FRAGMENT, 0, sharp, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, Shrink { float4 { PHOTO_SIZE, PHOTO_SIZE, 0.0, 0.0 } });
    gfx::draw(3);
    gfx::end_pass();
    let s: f32 = 1.0 / PHOTO_SIZE;
    gfx::begin_pass(g.across, gfx::Texture { 0 }, float4_0);
    gfx::bind(g.blur);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.small, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, Blur { float4 { s, 0.0, 5.6, s } });
    gfx::draw(3);
    gfx::end_pass();
    gfx::begin_pass(g.photo, gfx::Texture { 0 }, float4_0);
    gfx::bind(g.blur);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.across, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, Blur { float4 { 0.0, s, 5.6, s } });
    gfx::draw(3);
    gfx::end_pass();
    let px = gfx::read_pixels(g.photo);
    sh = harmonics(px, PHOTO_SIZE, grey);
    gfx::release(sharp);
}

// Bakes one surface of the theme into its albedo-and-roughness and normal targets, and
// their mips.
fn bake(g: Gpu&, albedo: gfx::Texture, normal: gfx::Texture, w: i64, h: i64, mode: f32,
        extent: float2, t: theme::Theme&) {
    var pass = gfx::PassDesc {};
    pass.color[0] = albedo;
    pass.color[1] = normal;
    gfx::begin_pass(pass);
    gfx::bind(g.bake);
    gfx::uniforms(gfx::FRAGMENT, 0, Bake { float4 { mode, wood_model, 0.0, 0.0 },
                                           float4 { w, h, extent.x, extent.y },
                                           t.light_sq, t.light_fig, t.dark_sq, t.dark_fig,
                                           t.inlay, t.inlay_fig, t.frame, t.frame_fig,
                                           t.surface, t.frame_surface, t.stone,
                                           t.light_ring, t.dark_ring, t.frame_ring });
    gfx::draw(3);
    gfx::end_pass();
    gfx::generate_mips(albedo);
    gfx::generate_mips(normal);
}

// Bakes the plan and the frame map, and waits for them: at startup, on a theme change
// and when the wood's model switches.
fn bake_surfaces(g: Gpu&, t: theme::Theme&) {
    let span = 2.0 * mesh::INNER;
    let c = clock();
    bake(g, g.plan_albedo, g.plan_normal, PLAN_SIZE, PLAN_SIZE, 0.0, float2 { span, span }, t);
    bake(g, g.frame_albedo, g.frame_normal, FRAME_MAP, FRAME_MAP, 1.0, float2 { 10.4, 10.4 },
         t);
    gfx::flush();
    print("setup: bake ", ((clock() - c) * 1000.0) as i64, " ms (wood ", wood_model, ")");
}

// A target with its mips for a baked surface.
fn baked(w: i64, h: i64, format: i32) -> gfx::Texture {
    return gfx::texture(gfx::TextureDesc { format: format,
                                           usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                           width: w as i32, height: h as i32, mips: 0 });
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
    g.bake = gfx::pipeline(full, embed_shader("frag", shaders::BAKE_FRAG));
    g.shrink = gfx::pipeline(full, embed_shader("frag", shaders::SHRINK_FRAG));
    g.blur = gfx::pipeline(full, embed_shader("frag", shaders::BLUR_FRAG));
    g.plan_albedo = baked(PLAN_SIZE, PLAN_SIZE, gfx::RGBA8_SRGB);
    g.plan_normal = baked(PLAN_SIZE, PLAN_SIZE, gfx::RGBA8);
    g.frame_albedo = baked(FRAME_MAP, FRAME_MAP, gfx::RGBA8_SRGB);
    g.frame_normal = baked(FRAME_MAP, FRAME_MAP, gfx::RGBA8);
    g.photo = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);
    g.small = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);
    g.across = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);

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
    g.frame = default<Frame>();
    g.frame.view_proj = gfx::mat4_identity;
    g.frame.selected = selected;
}

// Puts the position on the GPU again after the king's look switched: the instances, the
// squares, and the shadow map.
fn place(g: Gpu&) {
    var inst:    float4[..64] = [];
    var squares: float4[64]   = [float4_0; 64];
    g.frame.selected = position(inst, squares);
    gfx::update_buffer(g.instances, bytes_of(inst));
    gfx::update_buffer(g.squares, bytes_of(squares));
    g.instance_count = inst.len / 2;
    g.shadow_dirty = true;
}

// sRGB to linear for a color with its fourth value kept.
fn linear4(c: float4) -> float4 { float4 { linear(c.x), linear(c.y), linear(c.z), c.w } }

// Puts a theme on the board: bakes its surfaces into the same targets, blurs its
// photograph and takes its ambient, and fills the frame's block with its light and
// colors. Outside the frame loop's steady state: at startup and on a theme change.
fn apply(g: Gpu&, which: i64) {
    let t = theme::get(which);
    bake_surfaces(g, t);
    var c = clock();
    var sh: float4[9] = [float4_0; 9];
    photograph(g, t.photo, t.ambient.z, sh);
    gfx::flush();
    print("setup: photograph ", ((clock() - c) * 1000.0) as i64, " ms");

    // The key light, from the upper left; the photograph's ambient.
    let l = normalize(float3 { t.key.x, t.key.y, t.key.z });
    let light_view = gfx::look_at(l * 20.0, float3_0, float3 { 0.0, 1.0, 0.0 });
    let reach: f32 = 6.6;
    let light_proj = gfx::ortho(-reach, reach, -reach, reach, 5.0, 35.0);
    let f .= g.frame;
    f.light_view_proj = gfx::mul(light_proj, light_view);
    f.light_dir = f4(l, t.key.w);
    f.light_color = linear4(t.key_color);
    f.sh = sh;
    f.params = float4 { t.ambient.x, 1.0 / SHADOW_SIZE, t.ambient.y, 0.0 };
    f.glow = t.glow;
    f.light_piece = linear4(t.light_piece);
    f.dark_piece = linear4(t.dark_piece);
    f.piece_fig = t.piece_fig;
    f.crown = linear4(t.crown);
    f.edge = linear4(t.edge);
    f.line = linear4(t.line);
    f.bounce = linear4(t.bounce);
    f.grade = t.grade;
    f.tint = linear4(t.tint);
    f.frame_build = t.build;
    f.frame_surface = t.frame_surface;
    g.shadow_dirty = true;
    gfx::flush();
}

fn radians32(d: f32) -> f32 { d * PI / 180.0 }

// Draws a frame: the shadow map first if the position changed, then the one pass.
fn draw(g: Gpu&, cam: Camera) {
    let size = gfx::screen_size();
    if size.x != g.size.x || size.y != g.size.y { targets(g, size); }
    let yaw = radians32(cam.yaw);
    let pitch = radians32(cam.pitch);
    let target = float3 { 0.0, -0.15, 1.1 };
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
    gfx::bind_texture(gfx::FRAGMENT, 2, g.frame_albedo, g.wood);
    gfx::bind_texture(gfx::FRAGMENT, 3, g.frame_normal, g.wood);
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
    // --frames N runs the window's loop hidden for N frames, with a drag, T, K and a long
    // press injected (the press needs N of about 200 to last), and saves the last frame
    // to --shot's path if given: the loop checked without a window in the way.
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

    // --theme autumn|winter; T, or a long press (for touch), switches.
    var which = theme::AUTUMN;
    let ti = flag_str(argv, "--theme");
    if ti > 0 && argv[ti] == "winter" { which = theme::WINTER; }
    let ki = flag_str(argv, "--king");
    if ki > 0 && argv[ki] == "crown" { king_crown = true; }
    wood_model = clamp(flag_f32(argv, "--wood", wood_model) as i64, 0, WOOD_MODELS - 1);

    let t0 = clock();
    var g = default<Gpu>();
    setup(g);
    apply(g, which);
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
            which = (which + 1) % theme::COUNT;
            let c = clock();
            apply(g, which);
            print("theme ", which, " in ", ((clock() - c) * 1000.0) as i64, " ms");
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
            wood_model = (wood_model + 1) % WOOD_MODELS;
            var t = theme::get(which);
            bake_surfaces(g, t);
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
