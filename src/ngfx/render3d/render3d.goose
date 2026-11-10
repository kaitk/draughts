// The 3D board's renderer drawn through goose-ngfx (task 065; src/render3d/render3d.goose
// is gfx's, whose comments this keeps): the meshes and the themes (src/model3d/, which holds
// all of the board but drawing) put on the GPU, the surfaces baked there in the steps
// model3d plans, the season's photograph blurred into the backdrop with its ambient
// taken, the shadow map, and one forward pass at twice the size shrunk into a picture,
// NoGraphicsAPI having no multisampling. The shaders are gfx's GLSL in shaders.goose,
// written into Slang by scripts/ngfx_3d_shaders.py (src/ngfx/shaders/r3d_*.slang), each
// module with one root (Root) and its blob built ahead and embedded.
//
// The one package besides app/ that draws: it imports ngfx, and only the app imports it;
// the game's packages stay headless (docs/architecture/README.md).
// What it draws comes as data: the camera's matrix and eye (view3d::matrix), the
// instances and the field's occlusion and marks (view3d::Scene, laid out as the shaders
// read them), and model3d's meshes, looks, and harmonics.
//
// Frame structure: the shadow map (1024², 16-bit, from the key light) only when the
// pieces stand differently; then one pass: the blurred photograph as a backdrop, the
// pieces and the board lit (front to back), the board's soft shadow on nothing round
// it, the field's marks that hold still added. The marks that pulse (a must-capture ring, a wrong move's flash, a
// hint's ring) are drawn apart, over the kept image in the screen's pass each frame
// (marks_over), against a 1x depth of the board kept with the image. No post pass, no
// discard, nothing temporal. Nothing is made or released while drawing but the targets
// on a resize, and the kept depth the first time marks pulse.
namespace render3d;
import std;
import vec;
import math;
import ngfx;

import model3d from "../model3d";

// Theme `kind`'s photograph as a texture's id, or 0 when it isn't built in: the JPEG
// decoded and scaled down to `decoded` square (src/ngfx/app/photo.c). Declared once,
// here; the app's scene calls it too.
extern fn draughts_photo_ngfx(kind: i64, decoded: i64) -> u32;
fn draughts_photo(kind: i64, decoded: i64) -> ngfx::Texture { ngfx::Texture { draughts_photo_ngfx(kind, decoded) } }

// gfx's mat4, as the shaders read it: four columns, clip space y up as SDL_GPU's is (the
// vertex stages negate y for NoGraphicsAPI's).
struct Mat { c0: float4, c1: float4, c2: float4, c3: float4 }
let mat_identity = Mat { c0: float4 { 1.0, 0.0, 0.0, 0.0 }, c1: float4 { 0.0, 1.0, 0.0, 0.0 },
                         c2: float4 { 0.0, 0.0, 1.0, 0.0 }, c3: float4 { 0.0, 0.0, 0.0, 1.0 } };
fn mul(m: Mat, v: float4) -> float4 { m.c0 * v.x + m.c1 * v.y + m.c2 * v.z + m.c3 * v.w }
fn mul(a: Mat, b: Mat) -> Mat { Mat { c0: mul(a, b.c0), c1: mul(a, b.c1), c2: mul(a, b.c2), c3: mul(a, b.c3) } }
// gfx::ortho and gfx::look_at.
fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Mat {
    Mat { c0: float4 { 2.0 / (right - left), 0.0, 0.0, 0.0 }, c1: float4 { 0.0, 2.0 / (top - bottom), 0.0, 0.0 },
          c2: float4 { 0.0, 0.0, 1.0 / (near - far), 0.0 },
          c3: float4 { (left + right) / (left - right), (top + bottom) / (bottom - top), near / (near - far), 1.0 } }
}
fn look_at(eye: float3, target: float3, up: float3) -> Mat {
    let f = normalize(target - eye);
    let s = normalize(cross(f, up));
    let u = cross(s, f);
    Mat { c0: float4 { s.x, u.x, -f.x, 0.0 }, c1: float4 { s.y, u.y, -f.y, 0.0 }, c2: float4 { s.z, u.z, -f.z, 0.0 },
          c3: float4 { -dot(s, eye), -dot(u, eye), dot(f, eye), 1.0 } }
}

// Every module's root (src/ngfx/shaders/r3d.slang): the frame's block and the uniform
// blocks' float4s in this frame's memory, the storage buffers, the vertices, and the
// textures with their samplers in the slots each module's header lists.
struct Root { frame: u64, u: u64, buf0: u64, buf1: u64, buf2: u64, verts: u64, tex: u32[8], smp: u32[8] }
fn no_root() -> Root { Root { frame: 0, u: 0, buf0: 0, buf1: 0, buf2: 0, verts: 0, tex: [0; 8], smp: [0; 8] } }

// Laid out as the shaders' blocks (shaders::FRAME), std140: all vec4s and mat4s.
struct Frame {
    view_proj:       Mat,
    light_view_proj: Mat,
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
    frame_map:       float4,
}
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
    finish:        float4,  // looks::Finish: varnish, sanding, grain, rings
    tone:          float4,  // x: its warmth, y: pickle, z: caulk
    marble:        float4,  // looks::Marble: veins, wave, polish, tint
    marble_base:   float4,
    marble_vein:   float4,
    marble_form:   float4,
    seam:          float4,  // looks::Theme.seam
    carve:         float4,  // looks::Carving: depth, repeats per side, moss; w 1 carved
    moss:          float4,  // looks::MOSS
    carve_more:    float4,  // looks::Carving: motif, amber, lichen
    fill:          float4,  // looks::Theme.fill
    lichen:        float4,  // looks::LICHEN
}

// The shadow map: 1024² keeps the soft shadows as they were at 2048² (the lit shader's
// filter spreads over 5 of its texels), at a quarter of the memory.
let SHADOW_SIZE = 1024;
let PHOTO_SIZE = 512;
// The pieces' occlusion of the field (shaders::OCC_FRAG), over the plan's extent: 62
// texels a square on 8 × 8, for a falloff a piece's radius wide that rises steeply at
// its foot.
let OCC_SIZE = 512;
// The crown's map (shaders::CROWN_FRAG): 256 texels over 1.2 of the piece's radius, a
// texel 0.7 px on a piece 140 px across.
let CROWN_SIZE = 256;
// How the 3D pass is antialiased, NoGraphicsAPI having no MSAA (task 065): not at all;
// FXAA or SMAA 1x over the pass drawn at 1x; or the pass drawn at twice the size and
// shrunk (2 x 2 supersampling).
let AA_OFF = 0;
let AA_FXAA = 1;
let AA_SMAA = 2;
let AA_SSAA = 3;
let AA = AA_SMAA;
let MAX_INSTANCES = 96;     // view3d::MAX_INSTANCES: two for each of board::MAX_PIECES
let SQUARES = 100;          // the field's squares, 10 × 10 at most

// Everything on the GPU, made by setup() (the targets again on a resize).
struct Gpu {
    aa:             i32,            // AA_OFF..AA_SSAA: how the pass is antialiased
    wood:           i64,            // the wood's model the surfaces are baked with
    finish:         looks::Finish,  // and its finish
    marble:         i64,            // the stone frame's marble (looks::MARBLE..), 0 slate
    stone:          looks::Marble,  // and its look
    spring:         i64,            // spring's look (looks::SPRING_LOOK..), 1 the carved
    carving:        looks::Carving, // and the carving of a carved look shown,
    carved:         i64,            // the look it is the carving of (looks::shown), -1 none yet
    n:              i64,            // squares per side the plan is baked for
    look:           i64,            // looks::AUTUMN.., and the photograph's kind
    photo_kind:     i64,
    board_vb:       ngfx::Buffer,
    board_ib:       ngfx::Buffer,
    board_count:    i64,
    piece_vb:       ngfx::Buffer,
    piece_ib:       ngfx::Buffer,
    piece_count:    i64,
    instances:      ngfx::Buffer,
    instance_count: i64,
    solid:          i64,                    // the instances drawn opaque, first; the rest fade
    alphas:         f32[MAX_INSTANCES],     // how opaque each fading one is
    squares:        ngfx::Buffer,
    crown_map:      ngfx::Texture,          // the crown's distance (shaders::CROWN_FRAG), drawn at setup
    occ_map:        ngfx::Texture,          // the pieces' occlusion of the field (occlusion())
    occ_n:          i64,                    // the squares a side it was drawn for, 0 none yet
    occ_squares:    float4[SQUARES],        // the squares it was drawn from
    squares_now:    float4[SQUARES],        // and the ones place() last gave
    marks:          ngfx::Buffer,
    glows:          ngfx::Buffer,     // the field's glow rings and lit squares
    marked:         bool,             // whether the board's pass has marks to draw
    plan_albedo:    ngfx::Texture,
    plan_normal:    ngfx::Texture,
    frame_albedo:   ngfx::Texture,
    frame_normal:   ngfx::Texture,
    frame_rows:     i64,            // the frame map's rows: model3d::FRAME_MAP, or the mitred bands'
    photo:          ngfx::Texture,
    shadow_map:     ngfx::Texture,
    color:          ngfx::Texture,  // the pass before antialiasing (aa not AA_OFF), and its depth
    depth:          ngfx::Texture,
    image:          ngfx::Texture,  // what draw() antialiases into when asked to keep it
    edges:          ngfx::Texture,  // SMAA's edges and blending weights, at the pass's size
    weights:        ngfx::Texture,
    area:           ngfx::Texture,  // SMAA's tables (third_party/smaa)
    search:         ngfx::Texture,
    kept_backdrop:  ngfx::Texture,  // the backdrop at full opacity, g.size (keep_backdrop())
    kept_for:       float4[7],      // what it was drawn from (backdrop_key())
    live:           bool,           // the app's --keep off: the backdrop drawn each frame, never kept
    photo_gen:      i64,            // counts photo_part()'s steps, each of which may change g.photo
    kept_depth:     ngfx::Texture,  // its depth at 1x, for the pulsing marks (marks_over)
    warm_color:     ngfx::Texture,  // 4 × 4 targets warm() makes the pipelines for
    warm_depth:     ngfx::Texture,
    no_photo:       bool,           // no photograph built in for the theme (photo_part), or plain
    plain:          bool,           // the plain fade behind (task 044), set before a theme's steps
    fade:           float4[3],      // its colors (app/theme.goose's fade_top, low, light), linear
    size:           int2,
    linear:         ngfx::Sampler,
    point:          ngfx::Sampler,  // nearest, clamped (SMAA)
    aniso:          ngfx::Sampler,
    compare:        ngfx::Sampler,
    lit:            ngfx::Pipeline,
    fading:         ngfx::Pipeline, // the lit pass for a fading piece, blended
    shadow:         ngfx::Pipeline,
    backdrop:       ngfx::Pipeline,
    catcher:        ngfx::Pipeline,
    glow:           ngfx::Pipeline,
    pulse:          ngfx::Pipeline, // the pulsing marks over the kept image (marks_over)
    depth_only:     ngfx::Pipeline, // the kept depth
    copy:           ngfx::Pipeline,
    show:           ngfx::Pipeline, // the kept image over what is there, anywhere (show())
    occ:            ngfx::Pipeline, // the field's occlusion map (occlusion())
    kept:           ngfx::Pipeline, // the kept backdrop laid on the screen (backdrop())
    bake:           ngfx::Pipeline, // kept for a theme's rebake, with the photograph's
    shrink:         ngfx::Pipeline,
    blur:           ngfx::Pipeline,
    mip:            ngfx::Pipeline, // a baked surface's mips (mip_chain())
    down:           ngfx::Pipeline, // the pass at twice the size into its target
    fxaa:           ngfx::Pipeline,
    smaa_edges:     ngfx::Pipeline, // SMAA's three passes
    smaa_weights:   ngfx::Pipeline,
    smaa_blend:     ngfx::Pipeline,
    small:          ngfx::Texture,
    across:         ngfx::Texture,
    frame:          Frame,
    shadow_dirty:   bool,
    turn:           f32,            // the board's turn (view3d::View.turn), the light turned with it
    bake_ms:        f64,            // the last bake's time and the photograph's (measuring)
    photo_ms:       f64,
}

// What a pass wrote, before what comes after reads or writes it again: between passes,
// as ngfx wants, where SDL_GPU orders passes itself.
fn settle() {
    ngfx::barrier(ngfx::TARGET_WRITE | ngfx::FRAGMENT_READ, ngfx::TARGET_WRITE | ngfx::FRAGMENT_READ);
}

// The frame's block as it is now, in this frame's memory, for a root.
fn frame_addr(g: Gpu&) -> u64 {
    let one: Frame[1] = [g.frame];
    return ngfx::frame_data(bytes_of(one));
}

// float4s in this frame's memory: a root's uniform blocks.
fn blocks(u: const float4[:]) -> u64 { return ngfx::frame_data(bytes_of(u)); }

// Texture slot i of a root: the texture and its sampler.
fn slot(r: Root&, i: i64, t: ngfx::Texture, s: ngfx::Sampler) {
    r.tex[i] = ngfx::index(t);
    r.smp[i] = ngfx::index(s);
}

// A full-screen module's pipeline, its blob built ahead (scripts/ngfx.py).
fn module(blob: const u8[:], desc: ngfx::PipelineDesc = ngfx::PipelineDesc {}) -> ngfx::Pipeline {
    return ngfx::pipeline(blob, desc);
}

// The plain fade behind the 3D game: dimmed to 0.8, as the flat game's background is.
let PLAIN_DIM = 0.8;

// The photograph `kind` blurred into g.photo (src/app/scene.goose's way: shrunk to 512
// on the GPU, two passes of a Gaussian of sigma 5.6 texels), and its harmonics, taken
// `grey` of the way to grey. Decodes the photograph, so only at setup and on a theme
// change, never in the frame loop.
fn photograph(g: Gpu&, kind: i64, grey: f32, sh: float4[9]&) {
    for k in 3 { photo_part(g, kind, grey, sh, k); }
}

// Part k of photograph(), each short enough for a frame (theme_step): 0 the photograph
// decoded or uploaded and shrunk, 1 blurred across, 2 blurred down, read back, and its
// harmonics taken into sh.
fn photo_part(g: Gpu&, kind: i64, grey: f32, sh: float4[9]&, k: i64) {
    g.photo_gen++;
    let s: f32 = 1.0 / PHOTO_SIZE;
    if k == 0 && g.plain {
        // The plain background: nothing to decode or blur, the ambient from the fade.
        g.no_photo = true;
        sh = model3d::fade_harmonics(g.fade, grey);
        return;
    }
    if k == 0 {
        let sharp = draughts_photo(kind, 2048);
        g.no_photo = sharp.id == 0;
        if g.no_photo {
            // No photograph built in: the page under the scene, and a dim ambient.
            ngfx::begin_pass(g.photo, ngfx::Texture { 0 }, float4 { 0.11, 0.078, 0.063, 1.0 });
            ngfx::end_pass();
            settle();
            for i in 9 { sh[i] = float4_0; }
            sh[0] = model3d::no_photo_ambient();
            return;
        }
        ngfx::begin_pass(g.small, ngfx::Texture { 0 }, float4_0);
        ngfx::bind(g.shrink);
        var r = no_root();
        slot(r, 0, sharp, g.linear);
        r.u = blocks([float4 { PHOTO_SIZE, PHOTO_SIZE, 0.0, 0.0 }]);
        ngfx::draw(ngfx::root(r), 3);
        ngfx::end_pass();
        settle();
        // Given back once the GPU is done with it.
        ngfx::flush();
        ngfx::release(sharp);
        return;
    }
    guard !g.no_photo else { return; }
    if k == 1 {
        blur(g, g.small, g.across, float4 { s, 0.0, 5.6, s });
        return;
    }
    blur(g, g.across, g.photo, float4 { 0.0, s, 5.6, s });
    let px = ngfx::read_pixels(g.photo);
    sh = model3d::harmonics(px, PHOTO_SIZE, grey);
}

fn blur(g: Gpu&, from: ngfx::Texture, to: ngfx::Texture, dir: float4) {
    ngfx::begin_pass(to, ngfx::Texture { 0 }, float4_0);
    ngfx::bind(g.blur);
    var r = no_root();
    slot(r, 0, from, g.linear);
    r.u = blocks([dir]);
    ngfx::draw(ngfx::root(r), 3);
    ngfx::end_pass();
    settle();
}

// Bakes one surface of the theme into its albedo-and-roughness and normal targets, and
// their mips. Bake.mode: x the surface (0 the plan, 1 the frame map), y the wood's model,
// z the squares per side, w the marble (a stone frame's only).
fn bake(g: Gpu&, albedo: ngfx::Texture, normal: ngfx::Texture, w: i64, h: i64, mode: f32,
        extent: float2, t: looks::Theme&, y0: i64 = 0, y1: i64 = -1, mips: bool = true) {
    // Not cleared: the bake writes every texel. Only rows y0 to y1 when given
    // (theme_step's bands), the mips after the last.
    var pass = ngfx::PassDesc { clear_color: false };
    pass.color[0] = albedo;
    pass.color[1] = normal;
    ngfx::begin_pass(pass);
    if y1 >= 0 { ngfx::scissor(0, y0, w, y1 - y0); }
    ngfx::bind(g.bake);
    let fi = g.finish;
    let m = g.stone;
    let u: Bake[1] = [Bake { float4 { mode, g.wood, g.n, g.marble },
                                           float4 { w, h, extent.x, extent.y },
                                           t.light_sq, t.light_fig, t.dark_sq, t.dark_fig,
                                           t.inlay, t.inlay_fig, t.frame, t.frame_fig,
                                           t.surface, t.frame_surface, t.stone,
                                           t.light_ring, t.dark_ring, t.frame_ring,
                                           float4 { fi.varnish, fi.sanding, fi.grain, fi.rings },
                                           float4 { fi.warmth, fi.pickle, fi.caulk, 0.0 },
                                           float4 { m.veins, m.wave, m.polish, m.tint },
                                           m.base, m.vein, m.form, t.seam,
                                           float4 { g.carving.depth, g.carving.scale, g.carving.moss, t.build.w },
                                           looks::MOSS,
                                           float4 { g.carving.motif, g.carving.amber, g.carving.lichen, 0.0 },
                                           t.fill, looks::LICHEN }];
    var r = no_root();
    r.u = ngfx::frame_data(bytes_of(u));
    ngfx::draw(ngfx::root(r), 3);
    ngfx::end_pass();
    settle();
    guard mips else { return; }
    mip_chain(g, albedo);
    mip_chain(g, normal);
}

// The texture's mips from its first level, a pass a level (shaders/mip.slang): an sRGB
// one averaged in linear light, which ngfx's generate_mips can't write.
fn mip_chain(g: Gpu&, t: ngfx::Texture) {
    let levels = ngfx::texture_info(t).mips as i64;
    for level in 1..levels {
        var pass = ngfx::PassDesc { mip: level as i32, clear_color: false };
        pass.color[0] = t;
        ngfx::begin_pass(pass);
        ngfx::bind(g.mip);
        ngfx::draw(ngfx::root(MipRoot { src: ngfx::index(t), level: (level - 1) as u32, pad0: 0, pad1: 0 }), 3);
        ngfx::end_pass();
        settle();
    }
}
struct MipRoot { src: u32, level: u32, pad0: u32, pad1: u32 }

// Bakes the plan and the frame map (or one of them), and waits for them: at setup, on a
// theme change, a new board size, and when the wood's model, its finish or the marble
// switches.
fn bake_surfaces(g: Gpu&, plan: bool = true, frame: bool = true) {
    let t = look(g, g.look);
    if plan {
        bake(g, g.plan_albedo, g.plan_normal, model3d::PLAN_SIZE, model3d::PLAN_SIZE, 0.0, model3d::plan_extent(), t);
    }
    if frame {
        let rows = g.frame_rows;
        bake(g, g.frame_albedo, g.frame_normal, model3d::FRAME_MAP, rows, 1.0, model3d::frame_extent(rows), t);
    }
    ngfx::flush();
}

// A target with its mips for a baked surface, down to the level whose shorter side is 1
// pixel. The full chain runs to the longer side's 1: a mitred frame map's (2048 × 1152)
// last level would be 1 × 0 in SDL's mip blits, a zero-height blit that loses the device
// on a Mali-G68 (the Galaxy A33; docs/goose-findings.md). Nothing samples that far down.
fn baked(w: i64, h: i64, format: i32) -> ngfx::Texture {
    var mips = 1;
    while min(w, h) >> mips > 0 { mips++; }
    return ngfx::texture(ngfx::TextureDesc { format: format,
                                             usage: ngfx::COLOR_TARGET | ngfx::SAMPLED,
                                             width: w as i32, height: h as i32, mips: mips as i32 });
}

// The pass's target (at twice the size for AA_SSAA) and its depth, SMAA's, and the kept
// image, at `size`; made again only when the size changes.
fn targets(g: Gpu&, size: int2) {
    let old = [g.color, g.depth, g.image, g.edges, g.weights];
    for t in old { if t.id != 0 { ngfx::release(t); } }
    g.color = ngfx::Texture { 0 };
    g.edges = ngfx::Texture { 0 };
    g.weights = ngfx::Texture { 0 };
    let k = scale(g);
    if g.aa != AA_OFF { g.color = ngfx::render_target(size.x * k, size.y * k, ngfx::RGBA8); }
    if g.aa == AA_SMAA {
        g.edges = ngfx::render_target(size.x, size.y, ngfx::RG8);
        g.weights = ngfx::render_target(size.x, size.y, ngfx::RGBA8);
    }
    // 16-bit depth is plenty between NEAR 2 and FAR 40 for a scene 10 to 20 away (a step
    // about 0.003 at 20, under the marks' 0.004 lift).
    g.depth = ngfx::texture2d(size.x * k, size.y * k, ngfx::DEPTH16, ngfx::DEPTH_TARGET);
    g.image = ngfx::render_target(size.x, size.y, ngfx::RGBA8);
    if g.kept_backdrop.id != 0 { ngfx::release(g.kept_backdrop); }
    g.kept_backdrop = ngfx::render_target(size.x, size.y, ngfx::RGBA8);
    g.kept_for[0] = float4_0;
    g.size = size;
    if g.kept_depth.id != 0 {
        ngfx::release(g.kept_depth);
        g.kept_depth = depth_target(size);
    }
}

// How many times the size the pass is drawn at: 2 for AA_SSAA.
fn scale(g: Gpu&) -> i64 { return if g.aa == AA_SSAA { 2 } else { 1 }; }

// The kept depth: 1x, 16-bit as the pass's, sampled by the pulsing marks.
fn depth_target(size: int2) -> ngfx::Texture {
    return ngfx::texture2d(size.x, size.y, ngfx::DEPTH16, ngfx::DEPTH_TARGET | ngfx::SAMPLED);
}

// Makes everything the renderer draws with: the meshes, the buffers, the pipelines, the
// baked surfaces' and the photograph's targets. Then apply() puts a theme on it.
// `aa` is how the pass is antialiased (AA_OFF..AA_SSAA).
fn setup(g: Gpu&, aa: i32 = AA) {
    g.aa = aa;
    g.wood = model3d::WOOD_MODEL;
    g.finish = looks::finish(model3d::WOOD_MODEL);
    g.marble = looks::MARBLE;
    g.stone = looks::marble(looks::MARBLE);
    g.spring = looks::SPRING_LOOK;
    g.carving = looks::ELVEN;
    g.carved = -1;
    g.n = 8;
    g.look = -1;
    g.photo_kind = -1;
    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    mesh::board(verts, indices);
    // The shaders pull a vertex as ten floats (r3d_lit.slang).
    assert(bytes_of(verts).len == verts.len * 40);
    g.board_vb = ngfx::buffer(bytes_of(verts));
    g.board_ib = ngfx::buffer(bytes_of(indices));
    g.board_count = indices.len;
    verts.resize(0);
    indices.resize(0);
    mesh::piece(verts, indices);
    g.piece_vb = ngfx::buffer(bytes_of(verts));
    g.piece_ib = ngfx::buffer(bytes_of(indices));
    g.piece_count = indices.len;

    var empty: float4[SQUARES] = [float4_0; SQUARES];
    var none:  float4[SQUARES] = [float4 { 0.0, 0.0, 0.0, -1.0 }; SQUARES];
    g.instances = ngfx::buffer(MAX_INSTANCES * 32, bytes_of(empty[..2]));
    g.instance_count = 0;
    g.squares = ngfx::buffer(bytes_of(empty));
    g.marks = ngfx::buffer(bytes_of(none));
    g.glows = ngfx::buffer(bytes_of(empty));

    let blend = ngfx::PipelineDesc { blend: ngfx::BLEND_ALPHA };
    g.bake = module(embed_file("../app/shaders/r3d_bake.blob"));
    g.shrink = module(embed_file("../app/shaders/r3d_shrink.blob"));
    g.blur = module(embed_file("../app/shaders/r3d_blur.blob"));
    g.copy = module(embed_file("../app/shaders/r3d_copy.blob"));
    g.mip = module(embed_file("../app/shaders/mip.blob"));
    g.down = module(embed_file("../app/shaders/down.blob"));
    if aa == AA_FXAA { g.fxaa = module(embed_file("../app/shaders/fxaa.blob")); }
    if aa == AA_SMAA {
        let smaa = embed_file("../app/shaders/smaa.blob");
        g.smaa_edges = ngfx::pipeline(smaa, "edges_vertex", "edges_fragment", ngfx::PipelineDesc {});
        g.smaa_weights = ngfx::pipeline(smaa, "weights_vertex", "weights_fragment", ngfx::PipelineDesc {});
        g.smaa_blend = ngfx::pipeline(smaa, "blend_vertex", "blend_fragment", ngfx::PipelineDesc {});
        g.area = ngfx::texture2d(160, 560, ngfx::RG8, ngfx::SAMPLED);
        ngfx::update_texture(g.area, embed_file("../app/shaders/smaa_area.bin"));
        g.search = ngfx::texture2d(64, 16, ngfx::R8, ngfx::SAMPLED);
        ngfx::update_texture(g.search, embed_file("../app/shaders/smaa_search.bin"));
    }
    g.show = module(embed_file("../app/shaders/r3d_show.blob"), ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED });
    g.plan_albedo = baked(model3d::PLAN_SIZE, model3d::PLAN_SIZE, ngfx::RGBA8_SRGB);
    g.plan_normal = baked(model3d::PLAN_SIZE, model3d::PLAN_SIZE, ngfx::RGBA8);
    g.frame_rows = 0;   // made by apply(), as the look's frame wants
    g.photo = ngfx::render_target(PHOTO_SIZE, PHOTO_SIZE, ngfx::RGBA8);
    g.small = ngfx::render_target(PHOTO_SIZE, PHOTO_SIZE, ngfx::RGBA8);
    g.across = ngfx::render_target(PHOTO_SIZE, PHOTO_SIZE, ngfx::RGBA8);

    g.shadow_map = ngfx::texture2d(SHADOW_SIZE, SHADOW_SIZE, ngfx::DEPTH16, ngfx::DEPTH_TARGET | ngfx::SAMPLED);
    g.occ_map = ngfx::render_target(OCC_SIZE, OCC_SIZE, ngfx::R8);
    g.occ_n = 0;
    g.occ = module(embed_file("../app/shaders/r3d_occ.blob"));
    g.kept = module(embed_file("../app/shaders/r3d_kept.blob"), blend);
    g.linear = ngfx::sampler(ngfx::LINEAR, ngfx::CLAMP);
    g.point = ngfx::sampler(ngfx::NEAREST, ngfx::CLAMP);
    g.aniso = ngfx::sampler(ngfx::SamplerDesc { max_anisotropy: 8.0 });
    g.compare = ngfx::shadow_sampler();

    let lit = embed_file("../app/shaders/r3d_lit.blob");
    let depth = embed_file("../app/shaders/r3d_depth.blob");
    let marks = embed_file("../app/shaders/r3d_marks.blob");
    g.lit = ngfx::pipeline(lit, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true });
    g.fading = ngfx::pipeline(lit, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, blend: ngfx::BLEND_ALPHA });
    g.shadow = ngfx::pipeline(depth, ngfx::PipelineDesc { depth_test: true, depth_write: true, depth_bias: 1.0,
                                                          depth_bias_slope: 1.5 });
    g.backdrop = module(embed_file("../app/shaders/r3d_backdrop.blob"), blend);
    g.catcher = ngfx::pipeline(embed_file("../app/shaders/r3d_catcher.blob"),
                               ngfx::PipelineDesc { depth_test: true, blend: ngfx::BLEND_ALPHA });
    g.glow = ngfx::pipeline(marks, ngfx::PipelineDesc { depth_test: true, blend: ngfx::BLEND_PREMULTIPLIED });
    g.pulse = ngfx::pipeline(embed_file("../app/shaders/r3d_pulse.blob"), ngfx::PipelineDesc { blend: ngfx::BLEND_ADD });
    g.depth_only = ngfx::pipeline(depth, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true });
    // The crown's distance, once: a small pipeline made, drawn, and given back.
    g.crown_map = ngfx::render_target(CROWN_SIZE, CROWN_SIZE, ngfx::R16F);
    let crown = module(embed_file("../app/shaders/r3d_crown.blob"));
    ngfx::begin_pass(g.crown_map, ngfx::Texture { 0 }, float4_0);
    ngfx::bind(crown);
    ngfx::draw(ngfx::root(no_root()), 3);
    ngfx::end_pass();
    settle();
    ngfx::flush();
    ngfx::release(crown);
    g.frame = default<Frame>();
    g.frame.view_proj = mat_identity;
    g.frame.params.w = 8.0;
}

// Puts a theme on the board (looks::AUTUMN..), its surfaces baked for n squares a side,
// with the photograph `photo` (the app's theme, src/app/background.c's kind; -1 the
// theme's own): bakes the surfaces into the same targets, blurs the photograph and takes
// its ambient, and fills the frame's block with its light and colors. Only what changed
// is done again; outside the frame loop's steady state: at setup, on a theme change, a
// new board size.
fn apply(g: Gpu&, which: i64, n: i64, photo: i64 = -1) {
    if theme_begin(g, which, n) {
        let t0 = clock();
        bake_surfaces(g);
        g.bake_ms = (clock() - t0) * 1000.0;
    }
    theme_photo(g, which, photo);
    theme_end(g, which, n);
}

// apply()'s start: the look's carving taken, and for a new look or board size the frame
// map's targets as its frame wants. Whether the surfaces are to be baked.
fn theme_begin(g: Gpu&, which: i64, n: i64) -> bool {
    own_carving(g, looks::shown(which, g.spring));
    guard which != g.look || n != g.n else { return false; }
    let t = look(g, which);
    g.look = which;
    g.n = n;
    let rows = model3d::frame_rows(t);
    if rows != g.frame_rows {
        if g.frame_rows != 0 {
            ngfx::flush();
            ngfx::release(g.frame_albedo);
            ngfx::release(g.frame_normal);
        }
        g.frame_albedo = baked(model3d::FRAME_MAP, rows, ngfx::RGBA8_SRGB);
        g.frame_normal = baked(model3d::FRAME_MAP, rows, ngfx::RGBA8);
        g.frame_rows = rows;
    }
    return true;
}

// apply()'s photograph (`photo`, -1 the look's own) blurred and its ambient taken, when
// it is another than the one shown.
fn theme_photo(g: Gpu&, which: i64, photo: i64) {
    let t = look(g, which);
    let kind = if photo >= 0 { photo } else { t.photo };
    guard kind != g.photo_kind || g.frame.light_dir.w == 0.0 else { return; }
    g.photo_kind = kind;
    let t0 = clock();
    var sh: float4[9] = [float4_0; 9];
    photograph(g, kind, t.ambient.z, sh);
    g.frame.sh = sh;
    ngfx::flush();
    g.photo_ms = (clock() - t0) * 1000.0;
}

// Step k (0 to model3d::THEME_STEPS - 1) of putting a theme on, as apply(which, n, photo)
// does at once, as model3d::step plans it. Recording only; the frame's submit runs it.
fn theme_step(g: Gpu&, which: i64, n: i64, photo: i64, k: i64) {
    let t = look(g, g.look);
    let rows = g.frame_rows;
    let st = model3d::step(k, rows);
    if st.what == model3d::BEGIN {
        // A new look or size is baked whatever theme_begin finds: the steps bake in turn.
        theme_begin(g, which, n);
    } else if st.what == model3d::PIPELINE || st.what == model3d::PLAN {
        bake(g, g.plan_albedo, g.plan_normal, model3d::PLAN_SIZE, model3d::PLAN_SIZE, 0.0, model3d::plan_extent(), t,
             st.y0, st.y1, st.mips);
    } else if st.what == model3d::FRAME {
        bake(g, g.frame_albedo, g.frame_normal, model3d::FRAME_MAP, rows, 1.0, model3d::frame_extent(rows), t, st.y0,
             st.y1, st.mips);
    } else if st.what == model3d::PHOTO_PIPELINES {
        ngfx::prepare(g.shrink, g.small, ngfx::Texture { 0 });
        ngfx::prepare(g.blur, g.small, ngfx::Texture { 0 });
    } else {
        let part = st.part;
        let lk = look(g, which);
        let kind = if photo >= 0 { photo } else { lk.photo };
        var sh = g.frame.sh;
        photo_part(g, kind, lk.ambient.z, sh, part);
        g.frame.sh = sh;
        if part == 2 {
            g.photo_kind = kind;
            theme_end(g, which, n);
        }
    }
}

// apply()'s end: the key light, and the look's colors in the frame's block.
fn theme_end(g: Gpu&, which: i64, n: i64) {
    let t = look(g, which);
    // The key light, from the upper left; the photograph's ambient.
    light(g);
    let f .= g.frame;
    f.light_color = model3d::linear4(t.key_color);
    f.params = float4 { t.ambient.x, 0.0, t.ambient.y, n };
    f.glow = t.glow;
    f.light_piece = model3d::linear4(t.light_piece);
    f.dark_piece = model3d::linear4(t.dark_piece);
    f.piece_fig = t.piece_fig;
    f.crown = model3d::linear4(t.crown);
    f.edge = model3d::linear4(t.edge);
    if marbled(g, t) { f.edge.w = 0.0; }
    f.line = model3d::linear4(t.line);
    f.bounce = model3d::linear4(t.bounce);
    f.grade = t.grade;
    f.tint = model3d::linear4(t.tint);
    f.frame_build = t.build;
    f.frame_map = float4 { (g.frame_rows as f32) / model3d::FRAME_MAP, 0.0, 0.0, 0.0 };
    f.frame_surface = t.frame_surface;
    g.shadow_dirty = true;
}

// The key light, from the upper left of the screen, turned with the board (g.turn) so it
// keeps its place on screen while the board turns under it: its direction and the shadow
// map's projection.
fn light(g: Gpu&) {
    let t = look(g, g.look);
    let l = model3d::spin(normalize(float3 { t.key.x, t.key.y, t.key.z }), g.turn);
    let light_view = look_at(l * 20.0, float3_0, float3 { 0.0, 1.0, 0.0 });
    let reach: f32 = 6.6;
    let light_proj = ortho(-reach, reach, -reach, reach, 5.0, 35.0);
    g.frame.light_view_proj = mul(light_proj, light_view);
    g.frame.light_dir = model3d::f4(l, t.key.w);
}

// The board turned `turn` degrees under the light (a hot-seat turn, view3d::Camera.turn):
// the light turned the same way, and the shadow map drawn again with the next frame.
fn turn_light(g: Gpu&, turn: f32) {
    guard turn != g.turn else { return; }
    g.turn = turn;
    light(g);
    g.shadow_dirty = true;
}

// Whether the frame is marble: a stone frame with a marble chosen. Its rounded edge
// then keeps the marble, not the slate's steel-blue round.
fn marbled(g: Gpu&, t: looks::Theme&) -> bool { g.marble > 0 && t.frame_fig.w < 0.5 && t.build.w < 0.5 }

// The look `which` as g shows it: spring's chosen look with its carving.
fn look(g: Gpu&, which: i64) -> looks::Theme { looks::variant(which, g.spring, g.carving) }

// Chooses the wood's model and the marble, each with its own finish or look, and
// spring's look, before apply() bakes them (-1 keeps what is chosen): the app's --wood,
// --marble and --spring.
fn choose(g: Gpu&, wood: i64, marble: i64, spring: i64 = -1) {
    if spring >= 0 { g.spring = clamp(spring, 0, looks::SPRINGS - 1); }
    if wood >= 0 {
        g.wood = clamp(wood, 0, model3d::WOOD_MODELS - 1);
        g.finish = looks::finish(g.wood);
    }
    if marble >= 0 {
        g.marble = clamp(marble, 0, looks::MARBLES - 1);
        g.stone = looks::marble(g.marble);
    }
}

// Switches the wood's model, with its finish, and bakes the surfaces again.
fn set_wood(g: Gpu&, model: i64) {
    choose(g, model, -1);
    bake_surfaces(g);
}

// Sets the wood's model and finish, and the marble and its look (the prototype's tuning
// panel), baking again only the surfaces they show on: the wood's where the look has
// wood, the frame map where its frame is stone.
fn tune(g: Gpu&, wood: i64, finish: looks::Finish, marble: i64, stone: looks::Marble) {
    let t = look(g, g.look);
    let wood_changed = wood != g.wood || finish != g.finish;
    let marble_changed = marble != g.marble || stone != g.stone;
    g.wood = clamp(wood, 0, model3d::WOOD_MODELS - 1);
    g.finish = finish;
    g.marble = clamp(marble, 0, looks::MARBLES - 1);
    g.stone = stone;
    let plan = wood_changed && t.light_fig.w > 0.5;
    let frame = (wood_changed && t.frame_fig.w > 0.5) || (marble_changed && t.frame_fig.w < 0.5 && t.build.w < 0.5);
    if plan || frame { bake_surfaces(g, plan, frame); }
    g.frame.edge = model3d::linear4(t.edge);
    if marbled(g, t) { g.frame.edge.w = 0.0; }
}

// Takes look `id`'s own carving (looks::carving_for) when it isn't the one g has: a
// carved look's carving tuned in the panel stays while it shows.
fn own_carving(g: Gpu&, id: i64) {
    guard id != g.carved else { return; }
    g.carving = looks::carving_for(id);
    g.carved = id;
}

// Sets spring's look and the carving (the prototype's G and tuning panel), putting the
// look on again, its surfaces baked, when it shows: spring's look switched (with the
// new look's own carving, and its own wood if it has one), or a carved look's carving
// changed.
fn carve(g: Gpu&, spring: i64, c: looks::Carving) {
    let s = clamp(spring, 0, looks::SPRINGS - 1);
    guard s != g.spring || c != g.carving else { return; }
    let was = looks::shown(g.look, g.spring);
    g.spring = s;
    g.carving = c;
    let id = looks::shown(g.look, s);
    guard id != was || looks::get(id).build.w > 0.5 else { return; }
    if id != was {
        own_carving(g, id);
        let own = looks::wood_for(id);
        if own >= 0 {
            g.wood = own;
            g.finish = looks::finish_for(id, own);
        } else if looks::wood_for(was) >= 0 {
            g.wood = model3d::WOOD_MODEL;
            g.finish = looks::finish(g.wood);
        }
    }
    let which = g.look;
    g.look = -1;
    apply(g, which, g.n);
}

// Puts the pieces on the GPU: `inst` two float4s an instance (view3d::Scene.inst), the
// last alphas.len of them fading (a captured piece, a wrong move's ghost), each as
// opaque as its alpha, drawn blended after the rest and casting no shadow; `squares` the
// field's occlusion, `marks` its marks and `lit` its glow rings and lit squares
// (view3d::Scene's, row * n + column); `selected` the selected piece's foot and radius
// (w 0 for none); `dim` the board's under a win. The shadow map is drawn again with the
// next frame when `moved`.
fn place(g: Gpu&, inst: const float4[:], alphas: const f32[:], squares: const float4[:], marks: const float4[:],
         lit: const float4[:], selected: float4, dim: f32, moved: bool) {
    let count = min(inst.len, 2 * MAX_INSTANCES);
    if count > 0 { ngfx::update_buffer(g.instances, bytes_of(inst[..count])); }
    g.instance_count = count / 2;
    let fading = min(alphas.len, g.instance_count);
    g.solid = g.instance_count - fading;
    for i in fading { g.alphas[i] = alphas[i]; }
    ngfx::update_buffer(g.squares, bytes_of(squares[..min(squares.len, SQUARES)]));
    for i in SQUARES { g.squares_now[i] = if i < squares.len { squares[i] } else { float4_0 }; }
    ngfx::update_buffer(g.marks, bytes_of(marks[..min(marks.len, SQUARES)]));
    if lit.len > 0 { ngfx::update_buffer(g.glows, bytes_of(lit[..min(lit.len, SQUARES)])); }
    // What MARKS_FRAG without PULSE draws: the selected piece's ring, a last move's tint,
    // a target or a stop, a still must-capture ring, a glow ring, a lit square, a
    // count's pips, or a crowning square's shade. With none, the board's pass leaves its quad out.
    g.marked = selected.w > 0.0;
    for m in marks[..min(marks.len, SQUARES)] {
        if m.x > 0.5 || m.y > 0.5 || m.z > 1.5 || m.w > 0.5 { g.marked = true; }
    }
    for m in lit[..min(lit.len, SQUARES)] {
        if m.x > 0.0 || m.y > 0.0 || m.z > 0.0 { g.marked = true; }
    }
    g.frame.selected = selected;
    g.frame.screen.z = dim;
    if moved { g.shadow_dirty = true; }
}

// Draws a frame seen through view_proj from `eye` into `out`, a color target of `size`
// (the screen; or for Texture { 0 } g.image, kept for show()): the shadow map first if
// the pieces moved, then the one pass, at twice the size and shrunk into the target.
// Without the `backdrop` the target is clear but for the board, its shadow, and the
// pieces (premultiplied), for show() to lay over a backdrop drawn apart (backdrop(), or
// the app's photograph). With `keep_depth` the board's depth is kept too, at 1x, for
// marks_over. Recording only; the caller's ngfx::frame() submits it.
fn draw(g: Gpu&, view_proj: Mat, eye: float3, out: ngfx::Texture, size: int2, shadow_every: bool = false,
        backdrop: bool = true, keep_depth: bool = false) {
    if size.x != g.size.x || size.y != g.size.y { targets(g, size); }
    let target = if out.id == 0 { g.image } else { out };
    g.frame.view_proj = view_proj;
    g.frame.eye = model3d::f4(eye, 1.0);
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };

    keep_backdrop(g, size);
    if g.shadow_dirty || shadow_every {
        ngfx::begin_pass(ngfx::PassDesc { depth: g.shadow_map });
        ngfx::bind(g.shadow);
        draw_meshes(g, frame_addr(g), 1.0);
        ngfx::end_pass();
        g.shadow_dirty = false;
        settle();
    }

    occlusion(g);

    // The pass at the scale it is drawn at: its block's screen is the target's.
    let k = scale(g);
    g.frame.screen = float4 { size.x * k, size.y * k, g.frame.screen.z, 0.0 };
    let f = frame_addr(g);
    let clear = if backdrop { float4 { 0.11, 0.078, 0.063, 1.0 } } else { float4_0 };
    var pass = ngfx::PassDesc { depth: g.depth, color_value: clear };
    pass.color[0] = if g.aa != AA_OFF { g.color } else { target };
    ngfx::begin_pass(pass);
    if backdrop { draw_backdrop(g, f, 1.0); }

    ngfx::bind(g.lit);
    draw_meshes(g, f, 0.0);
    // The fading pieces, each alone at its opacity, over what stands behind them.
    if g.solid < g.instance_count {
        ngfx::bind(g.fading);
        for i in g.solid..g.instance_count {
            var r = lit_root(g, f, g.piece_vb);
            r.u = blocks([float4 { 1.0, 0.0, g.alphas[i - g.solid], i }]);
            ngfx::draw_indexed(ngfx::root(r), g.piece_ib, 4, g.piece_count);
        }
    }

    // The board's soft shadow round it, after the board so the depth test leaves out
    // what the board covers.
    ngfx::bind(g.catcher);
    var c = no_root();
    c.frame = f;
    c.u = blocks([float4_0]);
    ngfx::draw(ngfx::root(c), 6);

    // The field's marks and the selected piece's ring, added where nothing stands over;
    // none, nothing drawn.
    if g.marked {
        ngfx::bind(g.glow);
        var m = no_root();
        m.frame = f;
        m.u = blocks([float4 { 2.0, g.n, 0.0, 0.0 }]);
        m.buf0 = ngfx::address(g.marks);
        m.buf1 = ngfx::address(g.glows);
        ngfx::draw(ngfx::root(m), 6);
    }
    ngfx::end_pass();
    settle();
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    antialias(g, target, size);
    if keep_depth { draw_depth(g); }
}
struct DownRoot { src: u32, pad0: u32, pad1: u32, pad2: u32 }
struct FxaaRoot { color: u32, linear: u32, pad0: u32, pad1: u32, metrics: float4 }
struct SmaaRoot { color: u32, edges: u32, weights: u32, area: u32, search: u32, linear: u32, point: u32, pad0: u32,
                  metrics: float4 }

// The pass in g.color antialiased into `target` as g.aa says: shrunk (AA_SSAA), FXAA's
// one pass, or SMAA's three (shaders/smaa.slang); with AA_OFF the pass drew into it.
fn antialias(g: Gpu&, target: ngfx::Texture, size: int2) {
    guard g.aa != AA_OFF else { return; }
    let metrics = float4 { 1.0 / size.x, 1.0 / size.y, size.x, size.y };
    if g.aa == AA_SSAA {
        ngfx::begin_pass(target, ngfx::Texture { 0 }, float4_0);
        ngfx::bind(g.down);
        ngfx::draw(ngfx::root(DownRoot { src: ngfx::index(g.color), pad0: 0, pad1: 0, pad2: 0 }), 3);
        ngfx::end_pass();
    } else if g.aa == AA_FXAA {
        ngfx::begin_pass(target, ngfx::Texture { 0 }, float4_0);
        ngfx::bind(g.fxaa);
        ngfx::draw(ngfx::root(FxaaRoot { color: ngfx::index(g.color), linear: ngfx::index(g.linear), pad0: 0,
                                         pad1: 0, metrics: metrics }), 3);
        ngfx::end_pass();
    } else {
        let r = SmaaRoot { color: ngfx::index(g.color), edges: ngfx::index(g.edges), weights: ngfx::index(g.weights),
                           area: ngfx::index(g.area), search: ngfx::index(g.search), linear: ngfx::index(g.linear),
                           point: ngfx::index(g.point), pad0: 0, metrics: metrics };
        let steps = [g.smaa_edges, g.smaa_weights, g.smaa_blend];
        let into = [g.edges, g.weights, target];
        for p, i in steps {
            ngfx::begin_pass(into[i], ngfx::Texture { 0 }, float4_0);
            ngfx::bind(p);
            ngfx::draw(ngfx::root(r), 3);
            ngfx::end_pass();
            if i < 2 { settle(); }
        }
    }
    settle();
}

// The lit module's root (r3d_lit.slang's header): the frame, the instances, the vertices,
// and its seven textures.
fn lit_root(g: Gpu&, f: u64, vb: ngfx::Buffer) -> Root {
    var r = no_root();
    r.frame = f;
    r.buf0 = ngfx::address(g.instances);
    r.verts = ngfx::address(vb);
    slot(r, 0, g.plan_albedo, g.aniso);
    slot(r, 1, g.plan_normal, g.aniso);
    slot(r, 2, g.frame_albedo, g.aniso);
    slot(r, 3, g.frame_normal, g.aniso);
    slot(r, 4, g.shadow_map, g.compare);
    slot(r, 5, g.occ_map, g.linear);
    slot(r, 6, g.crown_map, g.linear);
    return r;
}

// The pieces' occlusion of the field drawn into g.occ_map where the squares changed since
// it was drawn (all of it the first time and for a new board size): a square's piece
// darkens the field within one square of its own (shaders::OCC_FRAG's 3 × 3), so the
// changed squares and one round them, scissored. A moving piece redraws about 3 × 3
// squares of the 64; a still board, nothing. Recording only, before the board's pass.
fn occlusion(g: Gpu&) {
    let n = g.n;
    var c0 = n;
    var r0 = n;
    var c1 = -1;
    var r1 = -1;
    if g.occ_n != n {
        c0 = 0;
        r0 = 0;
        c1 = n - 1;
        r1 = n - 1;
    } else {
        for i in n * n {
            let a = g.occ_squares[i];
            let b = g.squares_now[i];
            guard a.x != b.x || a.y != b.y || a.z != b.z || a.w != b.w else { continue; }
            let row = i / n;
            let col = i % n;
            c0 = min(c0, col - 1);
            c1 = max(c1, col + 1);
            r0 = min(r0, row - 1);
            r1 = max(r1, row + 1);
        }
        guard c1 >= 0 else { return; }
        c0 = max(c0, 0);
        r0 = max(r0, 0);
        c1 = min(c1, n - 1);
        r1 = min(r1, n - 1);
    }
    // The texels over those squares, out to the map's edge past the outer ones (the
    // inlay round the field takes the edge squares' occlusion), a texel more each side.
    let u = 2.0 * mesh::FIELD / n;
    let k = OCC_SIZE / (2.0 * mesh::INNER);
    let at = mesh::INNER - mesh::FIELD;
    let x0 = if c0 == 0 { 0 } else { max(floor((c0 * u + at) * k) as i64 - 1, 0) };
    let y0 = if r0 == 0 { 0 } else { max(floor((r0 * u + at) * k) as i64 - 1, 0) };
    let x1 = if c1 == n - 1 { OCC_SIZE } else { min(ceil(((c1 + 1) * u + at) * k) as i64 + 1, OCC_SIZE) };
    let y1 = if r1 == n - 1 { OCC_SIZE } else { min(ceil(((r1 + 1) * u + at) * k) as i64 + 1, OCC_SIZE) };
    var pass = ngfx::PassDesc { clear_color: false };
    pass.color[0] = g.occ_map;
    ngfx::begin_pass(pass);
    ngfx::scissor(x0, y0, x1 - x0, y1 - y0);
    ngfx::bind(g.occ);
    var r = no_root();
    r.frame = frame_addr(g);
    r.buf0 = ngfx::address(g.squares);
    ngfx::draw(ngfx::root(r), 3);
    ngfx::end_pass();
    settle();
    g.occ_squares = g.squares_now;
    g.occ_n = n;
}

// The board and the opaque pieces' depth at 1x into g.kept_depth, as the pass above drew
// them (the fading pieces write none there either): only the vertices and a 16-bit
// target, no shading.
fn draw_depth(g: Gpu&) {
    if g.kept_depth.id == 0 { g.kept_depth = depth_target(g.size); }
    ngfx::begin_pass(ngfx::PassDesc { depth: g.kept_depth });
    ngfx::bind(g.depth_only);
    draw_meshes(g, frame_addr(g), 0.0);
    ngfx::end_pass();
    settle();
}

// The pulsing marks (shaders::MARKS_FRAG with PULSE) over the open pass's target of
// `size`, where show() laid the kept image: drawn with it (draw() with keep_depth) into
// its rect `to` (as show()'s, the whole image), as opaque as `alpha`. `pulse` their
// phases (view3d::Scene.pulse), `next` how lit a capture's next stops are (Scene.next).
// The field's marks are the ones place() gave the image.
fn marks_over(g: Gpu&, pulse: float4, next: f32, to: float4, alpha: f32, size: int2) {
    guard g.kept_depth.id != 0 && to.z > 0.0 else { return; }
    // The image's clip space moved and scaled into `to`, depth left as it was.
    let k = to.z / g.size.x;
    let sx = 2.0 * to.x / size.x + k * g.size.x / size.x - 1.0;
    let sy = 1.0 - 2.0 * to.y / size.y - k * g.size.y / size.y;
    let kx = k * g.size.x / size.x;
    let ky = k * g.size.y / size.y;
    let place = Mat { c0: float4 { kx, 0.0, 0.0, 0.0 }, c1: float4 { 0.0, ky, 0.0, 0.0 },
                      c2: float4 { 0.0, 0.0, 1.0, 0.0 }, c3: float4 { sx, sy, 0.0, 1.0 } };
    let keep = g.frame.view_proj;
    g.frame.view_proj = mul(place, keep);
    let f = frame_addr(g);
    g.frame.view_proj = keep;
    ngfx::bind(g.pulse);
    var r = no_root();
    r.frame = f;
    // r3d_pulse.slang's header: Draw, then Pulse.
    r.u = blocks([float4 { 2.0, g.n, 0.0, 0.0 }, pulse, float4 { to.x, to.y, 1.0 / k, alpha },
                 float4 { next, 0.0, 0.0, 0.0 }]);
    r.buf0 = ngfx::address(g.marks);
    r.buf1 = ngfx::address(g.glows);
    slot(r, 0, g.kept_depth, g.linear);
    ngfx::draw(ngfx::root(r), 6);
}

// The opaque pieces as instances, then the board, front to back: the field under the
// pieces fails the depth test before it is shaded. From the light when `light` is 1.
fn draw_meshes(g: Gpu&, f: u64, light: f32) {
    if g.solid > 0 {
        var r = lit_root(g, f, g.piece_vb);
        r.u = blocks([float4 { 1.0, light, 1.0, 0.0 }]);
        ngfx::draw_indexed_instanced(ngfx::root(r), g.piece_ib, 4, g.piece_count, g.solid);
    }
    var r = lit_root(g, f, g.board_vb);
    r.u = blocks([float4 { 0.0, light, 1.0, 0.0 }]);
    ngfx::draw_indexed(ngfx::root(r), g.board_ib, 4, g.board_count);
}

// The blurred photograph, graded, or the plain fade dimmed as the flat game dims what is
// behind it (draw::frame's 0.8), at opacity `alpha` over the open pass's target; `f` the
// frame's block, its screen the target's size.
fn draw_backdrop(g: Gpu&, f: u64, alpha: f32) {
    ngfx::bind(g.backdrop);
    var r = no_root();
    r.frame = f;
    let dim: f32 = if g.plain { PLAIN_DIM } else { 0.0 };
    r.u = blocks([float4 { alpha, dim, 0.0, 0.0 }, g.fade[0], g.fade[1], g.fade[2]]);
    slot(r, 0, g.photo, g.linear);
    ngfx::draw(ngfx::root(r), 3);
}

// The backdrop draw() leaves out without one, over the open pass's target of `size`
// (gfx's screen) at opacity `alpha`: under show()'s image, or fading in over the app's
// own photograph in a transition.
fn backdrop(g: Gpu&, alpha: f32, size: int2) {
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    guard kept_current(g, size) else {
        draw_backdrop(g, frame_addr(g), alpha);
        return;
    }
    ngfx::bind(g.kept);
    var r = no_root();
    r.u = blocks([float4 { alpha, 0.0, 0.0, 0.0 }]);
    slot(r, 0, g.kept_backdrop, g.linear);
    ngfx::draw(ngfx::root(r), 3);
}

// The backdrop drawn at full opacity into g.kept_backdrop when what it is drawn from
// changed (a size, a photograph, a look, the plain fade), so the screen's frames lay it
// with a fetch a pixel (shaders::KEPT_FRAG) instead of grading the photograph each frame
// (task 059: 7% of the Pixel 7a's GPU cycles a frame). Before draw()'s passes, which
// come with every change but the photograph's alone; till the next, backdrop() draws
// it as it was. Recording only.
fn keep_backdrop(g: Gpu&, size: int2) {
    guard !g.live && !kept_current(g, size) else { return; }
    var pass = ngfx::PassDesc { clear_color: false };
    pass.color[0] = g.kept_backdrop;
    ngfx::begin_pass(pass);
    draw_backdrop(g, frame_addr(g), 1.0);
    ngfx::end_pass();
    settle();
    g.kept_for = backdrop_key(g, size);
}

// What the backdrop at `size` is drawn from: the size and the photograph's steps, the
// grade, the tint, the plain fade's brightness, and its colors.
fn backdrop_key(g: Gpu&, size: int2) -> float4[7] {
    let dim: f32 = if g.plain { PLAIN_DIM } else { 0.0 };
    return [float4 { size.x, size.y, g.photo_gen, 1.0 }, g.frame.grade, g.frame.tint, float4 { 1.0, dim, 0.0, 0.0 },
            g.fade[0], g.fade[1], g.fade[2]];
}

// Whether g.kept_backdrop holds the backdrop at `size` as it would be drawn now.
fn kept_current(g: Gpu&, size: int2) -> bool {
    guard !g.live && g.kept_backdrop.id != 0 && size.x == g.size.x && size.y == g.size.y else { return false; }
    let k = backdrop_key(g, size);
    for i in 7 {
        let a = k[i];
        let b = g.kept_for[i];
        guard a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w else { return false; }
    }
    return true;
}

// Draws the kept image (draw() into g.image with its backdrop) over the open pass's
// target as it is: the prototype, under its tuning panel.
fn copy(g: Gpu&) {
    ngfx::bind(g.copy);
    var r = no_root();
    slot(r, 0, g.image, g.linear);
    ngfx::draw(ngfx::root(r), 3);
}

// Draws the kept image (draw() into g.image without the backdrop) over the open pass's
// target of `size`: its rect `from` into the rect `to`, both x, y, width, height in
// pixels, at opacity `alpha`, `grey` of the way to grey and dimmer (shaders::SHOW_FRAG).
// The same rect is the image as drawn, texel for texel.
fn show(g: Gpu&, from: float4, to: float4, alpha: f32, size: int2, grey: f32 = 0.0) {
    ngfx::bind(g.show);
    var r = no_root();
    r.u = blocks([from, to, float4 { size.x, size.y, alpha, grey }]);
    slot(r, 0, g.image, g.linear);
    ngfx::draw(ngfx::root(r), 6);
}

// The pipelines the 3D pass and the screen's part draw with, each made one step at a
// time (0 to WARM_STEPS - 1) before the board is first drawn, so that frame doesn't make
// them all at once: ngfx makes a pipeline for a pass's target formats when it is first
// bound in one, unless prepare() made it before, here for 4 × 4 targets of those formats
// (made by the first step, given back by the last), or for the target itself.
let WARM_STEPS = 11;
fn warm(g: Gpu&, k: i64) {
    if k == 0 {
        g.warm_color = ngfx::render_target(4, 4, ngfx::RGBA8);
        g.warm_depth = ngfx::texture2d(4, 4, ngfx::DEPTH16, ngfx::DEPTH_TARGET | ngfx::SAMPLED);
    }
    var pass = ngfx::PassDesc {};
    if k < 4 {
        pass.color[0] = g.warm_color;
        pass.depth = g.warm_depth;
    } else if k == 4 || k == 5 {
        pass.depth = g.warm_depth;
    } else if k == 9 {
        pass.color[0] = g.occ_map;
    } else {
        pass.color[0] = ngfx::screen();
    }
    let p = [g.lit, g.fading, g.catcher, g.glow, g.shadow, g.depth_only, g.backdrop, g.show, g.pulse, g.occ,
             g.kept][k];
    ngfx::prepare(p, pass);
    if k == WARM_STEPS - 1 {
        // The antialiasing's pipelines, for the RGBA8 targets they draw into, and SMAA's
        // edges for RG8.
        var into = ngfx::PassDesc {};
        into.color[0] = g.warm_color;
        let post = [g.down, g.fxaa, g.smaa_weights, g.smaa_blend];
        for q in post { if q.id != 0 { ngfx::prepare(q, into); } }
        if g.smaa_edges.id != 0 {
            let rg = ngfx::render_target(4, 4, ngfx::RG8);
            into.color[0] = rg;
            ngfx::prepare(g.smaa_edges, into);
            ngfx::release(rg);
        }
        ngfx::release(g.warm_color);
        ngfx::release(g.warm_depth);
        g.warm_color = ngfx::Texture { 0 };
        g.warm_depth = ngfx::Texture { 0 };
    }
}

// Everything setup() and the frames made given back (the app's board back to flat): the
// targets, surfaces, buffers, samplers, and pipelines. g is set up again from scratch.
fn release(g: Gpu&) {
    ngfx::flush();
    let textures = [g.plan_albedo, g.plan_normal, g.frame_albedo, g.frame_normal, g.photo, g.shadow_map, g.occ_map,
                    g.crown_map, g.color, g.depth, g.image, g.kept_backdrop, g.kept_depth, g.small, g.across,
                    g.warm_color, g.warm_depth, g.edges, g.weights, g.area, g.search];
    for t in textures { if t.id != 0 { ngfx::release(t); } }
    let buffers = [g.board_vb, g.board_ib, g.piece_vb, g.piece_ib, g.instances, g.squares, g.marks, g.glows];
    for b in buffers { if b.id != 0 { ngfx::release(b); } }
    let samplers = [g.linear, g.point, g.aniso, g.compare];
    for s in samplers { if s.id != 0 { ngfx::release(s); } }
    let pipelines = [g.lit, g.fading, g.shadow, g.backdrop, g.catcher, g.glow, g.pulse, g.depth_only, g.copy, g.show,
                     g.occ, g.kept, g.bake, g.shrink, g.blur, g.mip, g.down, g.fxaa, g.smaa_edges, g.smaa_weights,
                     g.smaa_blend];
    for p in pipelines { if p.id != 0 { ngfx::release(p); } }
    g = default<Gpu>();
}
