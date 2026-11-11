// The 3D board's renderer (task 015), shared by the app (src/app/draw3d.goose) and the
// prototype (poc/3d/board3d.goose): the meshes and the themes (src/model3d/, which holds
// all of the board but drawing) put on the GPU, the surfaces baked there in the steps
// model3d plans, the season's photograph blurred into the backdrop with its ambient
// taken, the shadow map, and one forward pass into a 4× multisampled target resolved
// into a picture (shaders.goose).
//
// The one package besides app/ that draws: it imports gfx, and only the app and the
// prototype import it; the game's packages stay headless (docs/architecture/README.md).
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
// on a resize, and the pass's targets, the kept backdrop, and the kept depth again after
// rest() gave them back once the app drew nothing for a while.
namespace render3d;
import std;
import vec;
import math;
import gfx;
import .shaders;

import model3d from "../model3d";

// Theme `kind`'s photograph, or 0 when it isn't built in: the ASTC image as stored, or
// the JPEG decoded and scaled down to `decoded` square (src/app/background.c, which the
// app and poc/3d both compile). Declared once, here; the app's scene calls it too.
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
    frame_map:       float4,
}
struct Draw { draw: float4 }
// The backdrop's draw: x how opaque, y the plain fade's brightness (0: the photograph);
// the fade's colors in linear light (shaders::FADE_FN).
struct Backdrop { draw: float4, fade_top: float4, fade_low: float4, fade_light: float4 }
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
struct Shrink { to: float4 }
struct Pulse { pulse: float4, place: float4, more: float4 }
struct Show { from: float4, to: float4, screen: float4 }
struct Blur { dir: float4 }

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
let SAMPLES = 4;
let MAX_INSTANCES = 96;     // view3d::MAX_INSTANCES: two for each of board::MAX_PIECES
let SQUARES = 100;          // the field's squares, 10 × 10 at most

// Everything on the GPU, made by setup() (the targets again on a resize).
struct Gpu {
    samples:        i32,
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
    board_vb:       gfx::Buffer,
    board_ib:       gfx::Buffer,
    board_count:    i64,
    piece_vb:       gfx::Buffer,
    piece_ib:       gfx::Buffer,
    piece_count:    i64,
    instances:      gfx::Buffer,
    instance_count: i64,
    solid:          i64,                    // the instances drawn opaque, first; the rest fade
    alphas:         f32[MAX_INSTANCES],     // how opaque each fading one is
    squares:        gfx::Buffer,
    crown_map:      gfx::Texture,           // the crown's distance (shaders::CROWN_FRAG), drawn at setup
    occ_map:        gfx::Texture,           // the pieces' occlusion of the field (occlusion())
    occ_n:          i64,                    // the squares a side it was drawn for, 0 none yet
    occ_squares:    float4[SQUARES],        // the squares it was drawn from
    squares_now:    float4[SQUARES],        // and the ones place() last gave
    marks:          gfx::Buffer,
    glows:          gfx::Buffer,      // the field's glow rings and lit squares
    marked:         bool,             // whether the board's pass has marks to draw
    plan_albedo:    gfx::Texture,
    plan_normal:    gfx::Texture,
    frame_albedo:   gfx::Texture,
    frame_normal:   gfx::Texture,
    frame_rows:     i64,            // the frame map's rows: model3d::FRAME_MAP, or the mitred bands'
    frame_flat:     bool,           // frame_normal is flat_frame()'s 4 × 4, not the map's
    photo:          gfx::Texture,
    shadow_map:     gfx::Texture,
    color:          gfx::Texture,   // the multisampled target and its depth
    depth:          gfx::Texture,
    image:          gfx::Texture,   // what draw() resolves into when asked to keep it
    kept_backdrop:  gfx::Texture,   // the backdrop at full opacity, g.size (keep_backdrop())
    kept_for:       float4[7],      // what it was drawn from (backdrop_key())
    live:           bool,           // the app's --keep off: the backdrop drawn each frame, never kept
    photo_gen:      i64,            // counts photo_part()'s steps, each of which may change g.photo
    kept_depth:     gfx::Texture,   // its depth at 1x, for the pulsing marks (marks_over)
    warm_color:     gfx::Texture,   // 4 × 4 targets warm() makes the pipelines on
    warm_depth:     gfx::Texture,
    warm_kept:      gfx::Texture,
    no_photo:       bool,           // no photograph built in for the theme (photo_part), or plain
    plain:          bool,           // the plain fade behind (task 044), set before a theme's steps
    fade:           float4[3],      // its colors (app/theme.goose's fade_top, low, light), linear
    size:           int2,
    linear:         gfx::Sampler,
    aniso:          gfx::Sampler,
    compare:        gfx::Sampler,
    lit:            gfx::Pipeline,
    fading:         gfx::Pipeline,  // the lit pass for a fading piece, blended
    shadow:         gfx::Pipeline,
    backdrop:       gfx::Pipeline,
    catcher:        gfx::Pipeline,
    glow:           gfx::Pipeline,
    pulse:          gfx::Pipeline,  // the pulsing marks over the kept image (marks_over)
    depth_only:     gfx::Pipeline,  // the kept depth
    copy:           gfx::Pipeline,
    show:           gfx::Pipeline,  // the kept image over what is there, anywhere (show())
    occ:            gfx::Pipeline,  // the field's occlusion map (occlusion())
    kept:           gfx::Pipeline,  // the kept backdrop laid on the screen (backdrop())
    bake:           gfx::Pipeline,  // kept for a theme's rebake, with the photograph's
    shrink:         gfx::Pipeline,
    blur:           gfx::Pipeline,
    small:          gfx::Texture,
    across:         gfx::Texture,
    frame:          Frame,
    shadow_dirty:   bool,
    turn:           f32,            // the board's turn (view3d::View.turn), the light turned with it
    bake_ms:        f64,            // the last bake's time and the photograph's (measuring)
    photo_ms:       f64,
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
            gfx::begin_pass(g.photo, gfx::Texture { 0 }, float4 { 0.11, 0.078, 0.063, 1.0 });
            gfx::end_pass();
            for i in 9 { sh[i] = float4_0; }
            sh[0] = model3d::no_photo_ambient();
            return;
        }
        gfx::begin_pass(g.small, gfx::Texture { 0 }, float4_0);
        gfx::bind(g.shrink);
        gfx::bind_texture(gfx::FRAGMENT, 0, sharp, g.linear);
        gfx::uniforms(gfx::FRAGMENT, 0, Shrink { float4 { PHOTO_SIZE, PHOTO_SIZE, 0.0, 0.0 } });
        gfx::draw(3);
        gfx::end_pass();
        gfx::release(sharp);
        return;
    }
    guard !g.no_photo else { return; }
    if k == 1 {
        gfx::begin_pass(g.across, gfx::Texture { 0 }, float4_0);
        gfx::bind(g.blur);
        gfx::bind_texture(gfx::FRAGMENT, 0, g.small, g.linear);
        gfx::uniforms(gfx::FRAGMENT, 0, Blur { float4 { s, 0.0, 5.6, s } });
        gfx::draw(3);
        gfx::end_pass();
        return;
    }
    gfx::begin_pass(g.photo, gfx::Texture { 0 }, float4_0);
    gfx::bind(g.blur);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.across, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, Blur { float4 { 0.0, s, 5.6, s } });
    gfx::draw(3);
    gfx::end_pass();
    let px = gfx::read_pixels(g.photo);
    sh = model3d::harmonics(px, PHOTO_SIZE, grey);
}

// Bakes one surface of the theme into its albedo-and-roughness and normal targets, and
// their mips. Bake.mode: x the surface (0 the plan, 1 the frame map), y the wood's model,
// z the squares per side, w the marble (a stone frame's only).
fn bake(g: Gpu&, albedo: gfx::Texture, normal: gfx::Texture, w: i64, h: i64, mode: f32,
        extent: float2, t: looks::Theme&, y0: i64 = 0, y1: i64 = -1, mips: bool = true) {
    // Not cleared: the bake writes every texel, and a cleared target SDL finds still
    // referenced (as a new one is) it cycles into a second copy kept for good, 85 MB for
    // the four surfaces on the Pixel 7a. Only rows y0 to y1 when given (theme_step's
    // bands), the mips after the last.
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = albedo;
    pass.color[1] = normal;
    gfx::begin_pass(pass);
    if y1 >= 0 { gfx::scissor(0, y0, w, y1 - y0); }
    gfx::bind(g.bake);
    let fi = g.finish;
    let m = g.stone;
    gfx::uniforms(gfx::FRAGMENT, 0, Bake { float4 { mode, g.wood, g.n, g.marble },
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
                                           t.fill, looks::LICHEN });
    gfx::draw(3);
    gfx::end_pass();
    guard mips else { return; }
    gfx::generate_mips(albedo);
    gfx::generate_mips(normal);
}

// Bakes the plan and the frame map (or one of them), and waits for them: at setup, on a
// theme change, a new board size, and when the wood's model, its finish or the marble
// switches.
fn bake_surfaces(g: Gpu&, plan: bool = true, frame: bool = true) {
    let t = look(g, g.look);
    if plan {
        bake(g, g.plan_albedo, g.plan_normal, model3d::PLAN_SIZE, model3d::PLAN_SIZE, 0.0, model3d::plan_extent(), t);
    }
    if frame {
        full_frame(g);
        let rows = g.frame_rows;
        bake(g, g.frame_albedo, g.frame_normal, model3d::FRAME_MAP, rows, 1.0, model3d::frame_extent(rows), t);
        flat_frame(g);
    }
    gfx::flush();
}

// A target with its mips for a baked surface, down to the level whose shorter side is 1
// pixel. The full chain runs to the longer side's 1: a mitred frame map's (2048 × 1152)
// last level would be 1 × 0 in SDL's mip blits, a zero-height blit that loses the device
// on a Mali-G68 (the Galaxy A33; docs/goose-findings.md). Nothing samples that far down.
fn baked(w: i64, h: i64, format: i32) -> gfx::Texture {
    var mips = 1;
    while min(w, h) >> mips > 0 { mips++; }
    return gfx::texture(gfx::TextureDesc { format: format,
                                           usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                           width: w as i32, height: h as i32, mips: mips as i32 });
}

// The kept image at `size`, made again only when the size changes; the pass's own
// targets when draw() needs them (pass_targets), the kept backdrop and depth when it
// keeps them.
fn targets(g: Gpu&, size: int2) {
    give_back(g);
    if g.image.id != 0 { gfx::release(g.image); }
    g.image = gfx::render_target(size.x, size.y, gfx::RGBA8);
    g.kept_for[0] = float4_0;
    g.size = size;
}

// The pass's multisampled target and its depth at g.size, made for a draw after rest()
// gave them back.
fn pass_targets(g: Gpu&) {
    if g.samples > 1 && g.color.id == 0 {
        g.color = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8, usage: gfx::COLOR_TARGET,
                                                  width: g.size.x, height: g.size.y,
                                                  samples: g.samples });
    }
    // 16-bit depth is plenty between NEAR 2 and FAR 40 for a scene 10 to 20 away (a step
    // about 0.003 at 20, under the marks' 0.004 lift), and half of 32-bit's memory, which
    // SDL can't keep in tile memory: 20 MB less at 4× on the Pixel 7a.
    if g.depth.id == 0 {
        g.depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET,
                                                  width: g.size.x, height: g.size.y,
                                                  samples: g.samples });
    }
}

// Gives back what only drawing the board needs once the app is at rest: the pass's
// targets, the depth kept for the pulsing marks, and the kept backdrop, which the
// screen's frames grade live from the photograph till the next draw() keeps it again.
// The kept image shows the board until it changes; the next draw() makes the rest again.
// Not while drawing: it submits what was recorded, as released textures are freed after
// the next submit is done, and none comes at rest.
fn rest(g: Gpu&) {
    give_back(g);
    gfx::flush();
}

// rest()'s releases, also before a resize's new targets.
fn give_back(g: Gpu&) {
    let held = [g.color, g.depth, g.kept_depth, g.kept_backdrop];
    for t in held { if t.id != 0 { gfx::release(t); } }
    g.color = gfx::Texture { 0 };
    g.depth = gfx::Texture { 0 };
    g.kept_depth = gfx::Texture { 0 };
    g.kept_backdrop = gfx::Texture { 0 };
}

// Whether rest() has anything to give back.
fn resting(g: Gpu&) -> bool { g.color.id == 0 && g.depth.id == 0 && g.kept_depth.id == 0 && g.kept_backdrop.id == 0 }

// The kept depth: 1x, 16-bit as the pass's, sampled by the pulsing marks.
fn depth_target(size: int2) -> gfx::Texture {
    return gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET | gfx::SAMPLED,
                                           width: size.x, height: size.y });
}

// Makes everything the renderer draws with: the meshes, the buffers, the pipelines, the
// baked surfaces' and the photograph's targets. Then apply() puts a theme on it.
// `samples` 4 is the multisampled pass; 1 draws straight into the target (measuring).
fn setup(g: Gpu&, samples: i32 = SAMPLES) {
    g.samples = samples;
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
    g.board_vb = gfx::vertex_buffer(bytes_of(verts));
    g.board_ib = gfx::index_buffer(bytes_of(indices));
    g.board_count = indices.len;
    verts.resize(0);
    indices.resize(0);
    mesh::piece(verts, indices);
    g.piece_vb = gfx::vertex_buffer(bytes_of(verts));
    g.piece_ib = gfx::index_buffer(bytes_of(indices));
    g.piece_count = indices.len;

    var empty: float4[SQUARES] = [float4_0; SQUARES];
    var none:  float4[SQUARES] = [float4 { 0.0, 0.0, 0.0, -1.0 }; SQUARES];
    g.instances = gfx::buffer(gfx::BUFFER_STORAGE, MAX_INSTANCES * 32, bytes_of(empty[..2]));
    g.instance_count = 0;
    g.squares = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(empty));
    g.marks = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(none));
    g.glows = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(empty));

    let full = embed_shader("vert", shaders::FULL_VERT);
    g.bake = gfx::pipeline(full, embed_shader("frag", shaders::BAKE_FRAG));
    g.shrink = gfx::pipeline(full, embed_shader("frag", shaders::SHRINK_FRAG));
    g.blur = gfx::pipeline(full, embed_shader("frag", shaders::BLUR_FRAG));
    g.copy = gfx::pipeline(full, embed_shader("frag", shaders::COPY_FRAG));
    g.show = gfx::pipeline(embed_shader("vert", shaders::SHOW_VS, shaders::SHOW_BLOCK, shaders::SHOW_VERT),
                           embed_shader("frag", shaders::SHOW_FS, shaders::SHOW_BLOCK, shaders::SHOW_FRAG),
                           gfx::PipelineDesc { blend: gfx::BLEND_PREMULTIPLIED });
    g.plan_albedo = baked(model3d::PLAN_SIZE, model3d::PLAN_SIZE, gfx::RGBA8_SRGB);
    g.plan_normal = baked(model3d::PLAN_SIZE, model3d::PLAN_SIZE, gfx::RGBA8);
    g.frame_rows = 0;   // made by apply(), as the look's frame wants
    g.photo = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);
    g.small = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);
    g.across = gfx::render_target(PHOTO_SIZE, PHOTO_SIZE, gfx::RGBA8);

    g.shadow_map = gfx::texture2d(SHADOW_SIZE, SHADOW_SIZE, gfx::DEPTH16,
                                  gfx::DEPTH_TARGET | gfx::SAMPLED);
    g.occ_map = gfx::texture(gfx::TextureDesc { format: gfx::R8, usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                                width: OCC_SIZE, height: OCC_SIZE });
    g.occ_n = 0;
    g.occ = gfx::pipeline(full, embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::OCC_FRAG));
    g.kept = gfx::pipeline(full, embed_shader("frag", shaders::KEPT_FRAG), gfx::PipelineDesc { blend: gfx::BLEND_ALPHA });
    g.linear = gfx::sampler(gfx::LINEAR, gfx::CLAMP);
    g.aniso = gfx::sampler(gfx::SamplerDesc { max_anisotropy: 8.0 });
    g.compare = gfx::shadow_sampler();

    let lit_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::LIT_VERT);
    let quad_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::QUAD_VERT);
    let lit_fs = embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::LIT_FRAG);
    g.lit = gfx::pipeline(lit_vs, lit_fs, gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true });
    g.fading = gfx::pipeline(lit_vs, lit_fs, gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true,
                                                                 blend: gfx::BLEND_ALPHA });
    g.shadow = gfx::pipeline(lit_vs, embed_shader("frag", shaders::EMPTY_FRAG),
                             gfx::PipelineDesc { depth_test: true, depth_write: true,
                                                 depth_bias: 1.0, depth_bias_slope: 1.5 });
    g.backdrop = gfx::pipeline(full, embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::FADE_FN,
                                                  shaders::BACKDROP_FRAG),
                               gfx::PipelineDesc { blend: gfx::BLEND_ALPHA });
    g.catcher = gfx::pipeline(quad_vs, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                                    shaders::SHADOW_CATCHER_FRAG),
                              gfx::PipelineDesc { depth_test: true, blend: gfx::BLEND_ALPHA });
    g.glow = gfx::pipeline(quad_vs, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                                 shaders::MARKS_FRAG),
                           gfx::PipelineDesc { depth_test: true, blend: gfx::BLEND_PREMULTIPLIED });
    g.pulse = gfx::pipeline(quad_vs, embed_shader("frag", shaders::MARKS_PULSE, shaders::FS_SET, shaders::FRAME,
                                                  shaders::MARKS_FRAG),
                            gfx::PipelineDesc { blend: gfx::BLEND_ADD });
    g.depth_only = gfx::pipeline(lit_vs, embed_shader("frag", shaders::EMPTY_FRAG),
                                 gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true });
    // The crown's distance, once: a small pipeline made, drawn, and given back.
    g.crown_map = gfx::texture(gfx::TextureDesc { format: gfx::R16F, usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                                  width: CROWN_SIZE, height: CROWN_SIZE });
    let crown = gfx::pipeline(full, embed_shader("frag", shaders::CROWN_FN, shaders::CROWN_FRAG));
    gfx::begin_pass(g.crown_map, gfx::Texture { 0 }, float4_0);
    gfx::bind(crown);
    gfx::draw(3);
    gfx::end_pass();
    gfx::release(crown);
    g.frame = default<Frame>();
    g.frame.view_proj = gfx::mat4_identity;
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
            gfx::release(g.frame_albedo);
            gfx::release(g.frame_normal);
            gfx::flush();
        }
        g.frame_albedo = baked(model3d::FRAME_MAP, rows, gfx::RGBA8_SRGB);
        g.frame_normal = baked(model3d::FRAME_MAP, rows, gfx::RGBA8);
        g.frame_rows = rows;
        g.frame_flat = false;
    }
    full_frame(g);
    return true;
}

// A flat marble frame's normal is the same everywhere (BAKE_FRAG writes it so, and its
// mips are it too): once baked, its map, 22 MB with mips, is given back for a 4 × 4 of
// that value, which samples the same. full_frame() makes the map again to bake into.
fn flat_frame(g: Gpu&) {
    let t = look(g, g.look);
    guard !g.frame_flat && marbled(g, t) else { return; }
    gfx::release(g.frame_normal);
    g.frame_normal = gfx::render_target(4, 4, gfx::RGBA8);
    let half: f32 = 128.0 / 255.0;
    gfx::begin_pass(g.frame_normal, gfx::Texture { 0 }, float4 { half, half, 1.0, 1.0 });
    gfx::end_pass();
    g.frame_flat = true;
}

fn full_frame(g: Gpu&) {
    guard g.frame_flat else { return; }
    gfx::release(g.frame_normal);
    g.frame_normal = baked(model3d::FRAME_MAP, g.frame_rows, gfx::RGBA8);
    g.frame_flat = false;
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
    gfx::flush();
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
        var pass = gfx::PassDesc { clear_color: false };
        pass.color[0] = g.small;
        gfx::begin_pass(pass);
        gfx::bind(g.shrink);
        gfx::bind(g.blur);
        gfx::end_pass();
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
    flat_frame(g);
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
    let light_view = gfx::look_at(l * 20.0, float3_0, float3 { 0.0, 1.0, 0.0 });
    let reach: f32 = 6.6;
    let light_proj = gfx::ortho(-reach, reach, -reach, reach, 5.0, 35.0);
    g.frame.light_view_proj = gfx::mul(light_proj, light_view);
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
    if count > 0 { gfx::update_buffer(g.instances, bytes_of(inst[..count])); }
    g.instance_count = count / 2;
    let fading = min(alphas.len, g.instance_count);
    g.solid = g.instance_count - fading;
    for i in fading { g.alphas[i] = alphas[i]; }
    gfx::update_buffer(g.squares, bytes_of(squares[..min(squares.len, SQUARES)]));
    for i in SQUARES { g.squares_now[i] = if i < squares.len { squares[i] } else { float4_0 }; }
    gfx::update_buffer(g.marks, bytes_of(marks[..min(marks.len, SQUARES)]));
    if lit.len > 0 { gfx::update_buffer(g.glows, bytes_of(lit[..min(lit.len, SQUARES)])); }
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
// (gfx's screen; or for Texture { 0 } g.image, kept for show()): the shadow map first if
// the pieces moved, then the one pass. Without the `backdrop` the target is clear but for
// the board, its shadow, and the pieces (premultiplied), for show() to lay over a
// backdrop drawn apart (backdrop(), or the app's photograph). With `keep_depth` the
// board's depth is kept too, at 1x, for marks_over. Recording only; the caller's
// gfx::frame() submits it.
fn draw(g: Gpu&, view_proj: gfx::mat4, eye: float3, out: gfx::Texture, size: int2, shadow_every: bool = false,
        backdrop: bool = true, keep_depth: bool = false) {
    if size.x != g.size.x || size.y != g.size.y { targets(g, size); }
    pass_targets(g);
    let target = if out.id == 0 { g.image } else { out };
    g.frame.view_proj = view_proj;
    g.frame.eye = model3d::f4(eye, 1.0);
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    let f = g.frame;

    keep_backdrop(g, size);
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

    occlusion(g);

    let clear = if backdrop { float4 { 0.11, 0.078, 0.063, 1.0 } } else { float4_0 };
    var pass = gfx::PassDesc { depth: g.depth, color_value: clear };
    if g.samples > 1 {
        pass.color[0] = g.color;
        pass.resolve[0] = target;
    } else {
        pass.color[0] = target;
    }
    gfx::begin_pass(pass);
    if backdrop { draw_backdrop(g, 1.0); }

    gfx::bind(g.lit);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.plan_albedo, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.plan_normal, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 2, g.frame_albedo, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 3, g.frame_normal, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 4, g.shadow_map, g.compare);
    gfx::bind_texture(gfx::FRAGMENT, 5, g.occ_map, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 6, g.crown_map, g.linear);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    draw_meshes(g, 0.0);
    // The fading pieces, each alone at its opacity, over what stands behind them.
    if g.solid < g.instance_count {
        gfx::bind(g.fading);
        gfx::bind_vertex_buffer(g.piece_vb);
        gfx::bind_index_buffer(g.piece_ib, 4);
        for i in g.solid..g.instance_count {
            gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 1.0, 0.0, g.alphas[i - g.solid], i } });
            gfx::draw_indexed(g.piece_count);
        }
    }

    // The board's soft shadow round it, after the board so the depth test leaves out
    // what the board covers.
    gfx::bind(g.catcher);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4_0 });
    gfx::draw(6);

    // The field's marks and the selected piece's ring, added where nothing stands over;
    // none, nothing drawn.
    if g.marked {
        gfx::bind(g.glow);
        gfx::bind_storage_buffer(gfx::FRAGMENT, 0, g.marks);
        gfx::bind_storage_buffer(gfx::FRAGMENT, 1, g.glows);
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 2.0, g.n, 0.0, 0.0 } });
        gfx::uniforms(gfx::FRAGMENT, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 1, Draw { float4 { 2.0, g.n, 0.0, 0.0 } });
        gfx::draw(6);
    }
    gfx::end_pass();
    if keep_depth { draw_depth(g); }
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
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = g.occ_map;
    gfx::begin_pass(pass);
    gfx::scissor(x0, y0, x1 - x0, y1 - y0);
    gfx::bind(g.occ);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 0, g.squares);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::draw(3);
    gfx::end_pass();
    g.occ_squares = g.squares_now;
    g.occ_n = n;
}

// The board and the opaque pieces' depth at 1x into g.kept_depth, as the pass above drew
// them (the fading pieces write none there either): only the vertices and a 16-bit
// target, no shading.
fn draw_depth(g: Gpu&) {
    if g.kept_depth.id == 0 { g.kept_depth = depth_target(g.size); }
    gfx::begin_pass(gfx::PassDesc { depth: g.kept_depth });
    gfx::bind(g.depth_only);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::uniforms(gfx::VERTEX, 0, g.frame);
    draw_meshes(g, 0.0);
    gfx::end_pass();
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
    let place = gfx::mat4 { c0: float4 { kx, 0.0, 0.0, 0.0 }, c1: float4 { 0.0, ky, 0.0, 0.0 },
                            c2: float4 { 0.0, 0.0, 1.0, 0.0 }, c3: float4 { sx, sy, 0.0, 1.0 } };
    var f = g.frame;
    f.view_proj = gfx::mul(place, g.frame.view_proj);
    gfx::bind(g.pulse);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.kept_depth, g.linear);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 0, g.marks);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 1, g.glows);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 2.0, g.n, 0.0, 0.0 } });
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 1, Draw { float4 { 2.0, g.n, 0.0, 0.0 } });
    gfx::uniforms(gfx::FRAGMENT, 2, Pulse { pulse, float4 { to.x, to.y, 1.0 / k, alpha }, float4 { next, 0.0, 0.0, 0.0 } });
    gfx::draw(6);
}

// The opaque pieces as instances, then the board, front to back: the field under the
// pieces fails the depth test before it is shaded. From the light when `light` is 1.
fn draw_meshes(g: Gpu&, light: f32) {
    if g.solid > 0 {
        gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 1.0, light, 1.0, 0.0 } });
        gfx::bind_vertex_buffer(g.piece_vb);
        gfx::bind_index_buffer(g.piece_ib, 4);
        gfx::draw_indexed_instanced(g.piece_count, g.solid);
    }
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 0.0, light, 1.0, 0.0 } });
    gfx::bind_vertex_buffer(g.board_vb);
    gfx::bind_index_buffer(g.board_ib, 4);
    gfx::draw_indexed(g.board_count);
}

// The blurred photograph, graded, or the plain fade dimmed as the flat game dims what is
// behind it (draw::frame's 0.8), at opacity `alpha` over the open pass's target.
fn draw_backdrop(g: Gpu&, alpha: f32) {
    gfx::bind(g.backdrop);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.photo, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    let dim: f32 = if g.plain { PLAIN_DIM } else { 0.0 };
    gfx::uniforms(gfx::FRAGMENT, 1, Backdrop { float4 { alpha, dim, 0.0, 0.0 }, g.fade[0], g.fade[1], g.fade[2] });
    gfx::draw(3);
}

// The backdrop draw() leaves out without one, over the open pass's target of `size`
// (gfx's screen) at opacity `alpha`: under show()'s image, or fading in over the app's
// own photograph in a transition.
fn backdrop(g: Gpu&, alpha: f32, size: int2) {
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    guard kept_current(g, size) else {
        draw_backdrop(g, alpha);
        return;
    }
    gfx::bind(g.kept);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.kept_backdrop, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, Draw { float4 { alpha, 0.0, 0.0, 0.0 } });
    gfx::draw(3);
}

// The backdrop drawn at full opacity into g.kept_backdrop when what it is drawn from
// changed (a size, a photograph, a look, the plain fade), so the screen's frames lay it
// with a fetch a pixel (shaders::KEPT_FRAG) instead of grading the photograph each frame
// (task 059: 7% of the Pixel 7a's GPU cycles a frame). Before draw()'s passes, which
// come with every change but the photograph's alone; till the next, backdrop() draws
// it as it was. Recording only.
fn keep_backdrop(g: Gpu&, size: int2) {
    guard !g.live && !kept_current(g, size) else { return; }
    if g.kept_backdrop.id == 0 { g.kept_backdrop = gfx::render_target(size.x, size.y, gfx::RGBA8); }
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = g.kept_backdrop;
    gfx::begin_pass(pass);
    draw_backdrop(g, 1.0);
    gfx::end_pass();
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
    gfx::bind(g.copy);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.image, g.linear);
    gfx::draw(3);
}

// Draws the kept image (draw() into g.image without the backdrop) over the open pass's
// target of `size`: its rect `from` into the rect `to`, both x, y, width, height in
// pixels, at opacity `alpha`, `grey` of the way to grey and dimmer (shaders::SHOW_FRAG).
// The same rect is the image as drawn, texel for texel.
fn show(g: Gpu&, from: float4, to: float4, alpha: f32, size: int2, grey: f32 = 0.0) {
    gfx::bind(g.show);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.image, g.linear);
    let u = Show { from: from, to: to, screen: float4 { size.x, size.y, alpha, grey } };
    gfx::uniforms(gfx::VERTEX, 0, u);
    gfx::uniforms(gfx::FRAGMENT, 0, u);
    gfx::draw(6);
}

// The pipelines the 3D pass and the screen's part draw with, each made one step at a
// time (0 to WARM_STEPS - 1) before the board is first drawn, so that frame doesn't make
// them all at once: goose_gfx makes a pipeline when it is first bound in a pass, for that
// pass's target formats (docs/goose-findings.md). Bound in a pass on 4 × 4 targets of the
// pass's formats (made by the first step, given back by the last), or on the target
// itself where it is small or held anyway, with nothing drawn.
let WARM_STEPS = 11;
fn warm(g: Gpu&, k: i64) {
    if k == 0 {
        g.warm_color = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8, usage: gfx::COLOR_TARGET, width: 4,
                                                       height: 4, samples: g.samples });
        g.warm_depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET, width: 4,
                                                       height: 4, samples: g.samples });
        g.warm_kept = depth_target(int2 { 4, 4 });
    }
    var pass = gfx::PassDesc {};
    if k < 4 {
        pass.color[0] = g.warm_color;
        pass.depth = g.warm_depth;
    } else if k == 4 {
        pass.depth = g.shadow_map;
    } else if k == 5 {
        pass.depth = g.warm_kept;
    } else if k == 9 {
        pass.color[0] = g.occ_map;
        pass.clear_color = false;
    } else {
        pass.color[0] = gfx::screen();
        pass.clear_color = false;
    }
    gfx::begin_pass(pass);
    let p = [g.lit, g.fading, g.catcher, g.glow, g.shadow, g.depth_only, g.backdrop, g.show, g.pulse, g.occ,
             g.kept][k];
    gfx::bind(p);
    gfx::end_pass();
    if k == WARM_STEPS - 1 {
        gfx::release(g.warm_color);
        gfx::release(g.warm_depth);
        gfx::release(g.warm_kept);
        g.warm_color = gfx::Texture { 0 };
        g.warm_depth = gfx::Texture { 0 };
        g.warm_kept = gfx::Texture { 0 };
    }
}

// Everything setup() and the frames made given back (the app's board back to flat): the
// targets, surfaces, buffers, samplers, and pipelines. g is set up again from scratch.
fn release(g: Gpu&) {
    let textures = [g.plan_albedo, g.plan_normal, g.frame_albedo, g.frame_normal, g.photo, g.shadow_map, g.occ_map, g.crown_map, g.color,
                    g.depth, g.image, g.kept_backdrop, g.kept_depth, g.small, g.across, g.warm_color, g.warm_depth,
                    g.warm_kept];
    for t in textures { if t.id != 0 { gfx::release(t); } }
    let buffers = [g.board_vb, g.board_ib, g.piece_vb, g.piece_ib, g.instances, g.squares, g.marks, g.glows];
    for b in buffers { if b.id != 0 { gfx::release(b); } }
    let samplers = [g.linear, g.aniso, g.compare];
    for s in samplers { if s.id != 0 { gfx::release(s); } }
    let pipelines = [g.lit, g.fading, g.shadow, g.backdrop, g.catcher, g.glow, g.pulse, g.depth_only, g.copy, g.show,
                     g.occ, g.kept, g.bake, g.shrink, g.blur];
    for p in pipelines { if p.id != 0 { gfx::release(p); } }
    gfx::flush();
    g = default<Gpu>();
}
