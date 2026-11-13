// Recording the 3D board's renderer (render3d.goose) through gfx: its shaders
// (shaders.goose, smaa.goose) and pipelines, its buffers, and every pass, one forward pass
// into a 4× multisampled target resolved into a picture, or SMAA after a 1x pass. In
// namespace render3d, as render3d.goose, which holds what is drawn and when. The
// goose-ngfx build's src/ngfx/render3d/render3d_gpu.goose takes this file's place.
namespace render3d;
import std;
import vec;
import math;
import gfx;
import .shaders;
import .smaa;

// The handles render3d.goose holds, the formats it bakes into, and the matrices' math.
type Texture = gfx::Texture;
type Buffer = gfx::Buffer;
type Sampler = gfx::Sampler;
type Pipeline = gfx::Pipeline;
let RGBA8 = gfx::RGBA8;
let RGBA8_SRGB = gfx::RGBA8_SRGB;
fn mul(a: Mat, b: Mat) -> Mat { gfx::mul(a, b) }
fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Mat {
    gfx::ortho(left, right, bottom, top, near, far)
}
fn look_at(eye: float3, target: float3, up: float3) -> Mat { gfx::look_at(eye, target, up) }

// What only gfx's renderer holds: the pass's samples (4 multisampled, 1 for SMAA or none),
// and a 4 × 4 target warm() makes the kept image's pipelines on.
struct Own {
    samples:   i32,
    warm_kept: gfx::Texture,
}

// The few calls render3d.goose makes itself: submit and wait, release, a color target,
// one cleared and nothing drawn, a buffer's bytes, a target with `mips` levels.
fn gpu_flush() { gfx::flush(); }
fn gpu_release(t: Texture) { gfx::release(t); }
fn gpu_target(w: i64, h: i64) -> Texture { gfx::render_target(w, h, gfx::RGBA8) }
fn gpu_clear(t: Texture, color: float4) {
    gfx::begin_pass(t, gfx::Texture { 0 }, color);
    gfx::end_pass();
}
// Releases two textures the GPU may still be reading, and waits for it, so the next
// made take their place.
fn gpu_release_waited(a: Texture, b: Texture) {
    gfx::release(a);
    gfx::release(b);
    gfx::flush();
}
fn gpu_update(b: Buffer, bytes: const u8[:]) { gfx::update_buffer(b, bytes); }
fn gpu_mipped(w: i64, h: i64, format: i32, mips: i64) -> Texture {
    return gfx::texture(gfx::TextureDesc { format: format, usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                           width: w as i32, height: h as i32, mips: mips as i32 });
}

// The photograph's pipelines made, in a pass that draws nothing (theme_step): goose_gfx
// makes a pipeline when it is first bound in a pass.
fn photo_pipelines(g: render3d::Gpu&) {
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = g.small;
    gfx::begin_pass(pass);
    gfx::bind(g.shrink);
    gfx::bind(g.blur);
    gfx::end_pass();
}

// The shadow map, from the key light.
fn shadow_pass(g: render3d::Gpu&) {
    let f = g.frame;
    var sp = gfx::PassDesc { depth: g.shadow_map };
    gfx::begin_pass(sp);
    gfx::bind(g.shadow);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::uniforms(gfx::VERTEX, 0, f);
    draw_meshes(g, 1.0);
    gfx::end_pass();
}

// draw()'s one pass into `target` of `size`, with the `backdrop` or clear, multisampled
// and resolved into it, or SMAA after it.
fn board_pass(g: render3d::Gpu&, target: Texture, size: int2, backdrop: bool) {
    let f = g.frame;
    let clear = if backdrop { float4 { 0.11, 0.078, 0.063, 1.0 } } else { float4_0 };
    var pass = gfx::PassDesc { depth: g.depth, color_value: clear };
    if g.aa == AA_MSAA {
        pass.color[0] = g.color;
        pass.resolve[0] = target;
    } else if g.aa == AA_SMAA {
        pass.color[0] = g.color;
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
    if g.aa == AA_SMAA { antialias(g, target); }
}

// The occlusion map's texels x0..x1, y0..y1 drawn again from the field's squares.
fn occ_pass(g: render3d::Gpu&, x0: i64, y0: i64, x1: i64, y1: i64) {
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = g.occ_map;
    gfx::begin_pass(pass);
    gfx::scissor(x0, y0, x1 - x0, y1 - y0);
    gfx::bind(g.occ);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 0, g.squares);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::draw(3);
    gfx::end_pass();
}

// The backdrop at full opacity into the kept one.
fn kept_pass(g: render3d::Gpu&) {
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = g.kept_backdrop;
    gfx::begin_pass(pass);
    draw_backdrop(g, 1.0);
    gfx::end_pass();
}

struct Draw { draw: float4 }

// The backdrop's draw: x how opaque, y the plain fade's brightness (0: the photograph);
// the fade's colors in linear light (shaders::FADE_FN).
struct Backdrop { draw: float4, fade_top: float4, fade_low: float4, fade_light: float4 }

struct Shrink { to: float4 }

struct Pulse { pulse: float4, place: float4, more: float4 }

struct Show { from: float4, to: float4, screen: float4 }

struct Blur { dir: float4 }

let SAMPLES = 4;

// The pass's samples on a device whose ready 3D board can't keep up with its display
// (task 081, src/app/display.c): on the Galaxy A33's Mali-G68 2× draws a quarter faster
// than 4×, and the user found the moving board fine at it.
let FEW_SAMPLES = 2;

// How the pass is antialiased (set_aa, the app's --aa and its A key, task 071): 4×
// multisampled, or drawn at 1x and SMAA 1x after it (smaa.goose), or neither. The
// values are the ngfx build's.
let AA_OFF = 0;

let AA_SMAA = 2;

let AA_MSAA = 4;

let AA = AA_MSAA;

// The pass's ways by the names --aa takes and the log prints (-1 for none), and the next
// the A key switches to: MSAA and SMAA in turn.
fn aa_named(name: const u8[:]) -> i32 {
    if name == "off" { return AA_OFF; }
    if name == "msaa" { return AA_MSAA; }
    if name == "smaa" { return AA_SMAA; }
    return -1;
}

fn aa_name(aa: i32) -> const u8[:] { if aa == AA_MSAA { "msaa" } else if aa == AA_SMAA { "smaa" } else { "off" } }

fn aa_next(aa: i32) -> i32 { if aa == AA_MSAA { AA_SMAA } else { AA_MSAA } }

// The view's matrices, as the ngfx build's render3d names its own.
type Mat = gfx::mat4;

// Part k of photograph(), each short enough for a frame (theme_step): 0 the photograph
// decoded or uploaded and shrunk, 1 blurred across, 2 blurred down, read back, and its
// harmonics taken into sh.
fn photo_part(g: render3d::Gpu&, kind: i64, grey: f32, sh: float4[9]&, k: i64) {
    g.photo_gen++;
    let s: f32 = 1.0 / render3d::PHOTO_SIZE;
    if k == 0 && g.plain {
        // The plain background: nothing to decode or blur, the ambient from the fade.
        g.no_photo = true;
        sh = model3d::fade_harmonics(g.fade, grey);
        return;
    }
    if k == 0 {
        let sharp = render3d::draughts_photo(kind, 2048);
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
        gfx::uniforms(gfx::FRAGMENT, 0, Shrink { float4 { render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, 0.0, 0.0 } });
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
    sh = model3d::harmonics(px, render3d::PHOTO_SIZE, grey);
}

// Bakes one surface of the theme into its albedo-and-roughness and normal targets, and
// their mips. Bake.mode: x the surface (0 the plan, 1 the frame map), y the wood's model,
// z the squares per side, w the marble (a stone frame's only).
fn bake(g: render3d::Gpu&, albedo: gfx::Texture, normal: gfx::Texture, w: i64, h: i64, mode: f32,
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
    let m = render3d::stone_of(g);
    gfx::uniforms(gfx::FRAGMENT, 0, render3d::Bake { float4 { mode, g.wood, g.n, render3d::marble_of(g) },
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
                                           float4 { g.carving.motif, g.carving.amber, g.carving.lichen, g.carving.pattern },
                                           t.fill, looks::LICHEN });
    gfx::draw(3);
    gfx::end_pass();
    guard mips else { return; }
    gfx::generate_mips(albedo);
    gfx::generate_mips(normal);
}

// The pass's target (multisampled, or SMAA's input and its edges and weights) and its
// depth at g.size, made for a draw after rest() gave them back.
fn pass_targets(g: render3d::Gpu&) {
    guard g.depth.id == 0 else { return; }
    if g.aa == AA_MSAA {
        g.color = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8, usage: gfx::COLOR_TARGET,
                                                  width: g.size.x, height: g.size.y,
                                                  samples: g.own.samples });
    } else if g.aa == AA_SMAA {
        g.color = gfx::render_target(g.size.x, g.size.y, gfx::RGBA8);
        g.edges = gfx::render_target(g.size.x, g.size.y, gfx::RG8);
        g.weights = gfx::render_target(g.size.x, g.size.y, gfx::RGBA8);
    }
    // 16-bit depth is plenty between NEAR 2 and FAR 40 for a scene 10 to 20 away (a step
    // about 0.003 at 20, under the marks' 0.004 lift), and half of 32-bit's memory, which
    // SDL can't keep in tile memory: 20 MB less at 4× on the Pixel 7a.
    g.depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET,
                                              width: g.size.x, height: g.size.y,
                                              samples: g.own.samples });
}

// The pass antialiased by `aa` (AA_MSAA..) from the next draw on, MSAA at `samples`:
// its targets given back (made again for the new way by the next draw), SMAA's pipelines
// and tables made the first time it is chosen. The app calls it after setup(), on its A
// key, and for fewer samples.
fn set_aa(g: render3d::Gpu&, aa: i32, samples: i32 = SAMPLES) {
    render3d::give_back(g);
    g.aa = aa;
    g.own.samples = if aa == AA_MSAA { samples } else { 1 };
    guard aa == AA_SMAA && g.smaa_edges.id == 0 else { return; }
    // The edges pass marks the pixels it finds an edge on with depth 0 (its triangle's z;
    // where it finds none it discards, leaving the cleared 1), and the weights pass, drawn
    // at the same z, tests it equal: the early depth test skips the pixels with no edge,
    // whose weights are 0, as the cleared target holds them. SMAA's reference does it
    // with a stencil; the pass's own depth is free by then and needs none.
    g.smaa_edges = gfx::pipeline(embed_shader("vert", smaa::VS_METRICS, smaa::DEFS, smaa::CORNER, smaa::EDGES_VERT),
                                 embed_shader("frag", smaa::EDGES_TEX, smaa::UNUSED_TEX, smaa::FS_METRICS, smaa::DEFS, smaa::EDGES_FRAG),
                                 gfx::PipelineDesc { depth_test: true, depth_write: true,
                                                     depth_compare: gfx::COMPARE_ALWAYS });
    g.smaa_weights = gfx::pipeline(embed_shader("vert", smaa::VS_METRICS, smaa::DEFS, smaa::CORNER, smaa::WEIGHTS_VERT),
                                   embed_shader("frag", smaa::WEIGHTS_TEX, smaa::UNUSED_TEX, smaa::FS_METRICS, smaa::DEFS, smaa::WEIGHTS_FRAG),
                                   gfx::PipelineDesc { depth_test: true, depth_compare: gfx::COMPARE_EQUAL });
    g.smaa_blend = gfx::pipeline(embed_shader("vert", smaa::VS_METRICS, smaa::DEFS, smaa::CORNER, smaa::BLEND_VERT),
                                 embed_shader("frag", smaa::BLEND_TEX, smaa::UNUSED_TEX, smaa::FS_METRICS, smaa::DEFS, smaa::BLEND_FRAG));
    g.area = gfx::texture2d(160, 560, gfx::RG8, gfx::SAMPLED);
    gfx::update_texture(g.area, embed_file("../../third_party/smaa/area.bin"));
    g.search = gfx::texture2d(64, 16, gfx::R8, gfx::SAMPLED);
    gfx::update_texture(g.search, embed_file("../../third_party/smaa/search.bin"));
}

struct Metrics { m: float4 }

// SMAA's three passes over g.color into `target`, at g.size: the edges, their blending
// weights, and the neighbours blended (smaa.goose). Recording only.
fn antialias(g: render3d::Gpu&, target: gfx::Texture) {
    let m = Metrics { float4 { 1.0 / g.size.x, 1.0 / g.size.y, g.size.x, g.size.y } };
    // The edge pass discards where it finds none, and the weights are read only where
    // there are edges, so both start cleared.
    var edges = gfx::PassDesc { depth: g.depth, color_value: float4_0 };
    edges.color[0] = g.edges;
    gfx::begin_pass(edges);
    gfx::bind(g.smaa_edges);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.color, g.linear);
    gfx::uniforms(gfx::VERTEX, 0, m);
    gfx::uniforms(gfx::FRAGMENT, 0, m);
    gfx::draw(3);
    gfx::end_pass();
    var weights = gfx::PassDesc { depth: g.depth, clear_depth: false, color_value: float4_0 };
    weights.color[0] = g.weights;
    gfx::begin_pass(weights);
    gfx::bind(g.smaa_weights);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.edges, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.area, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 2, g.search, g.linear);
    gfx::uniforms(gfx::VERTEX, 0, m);
    gfx::uniforms(gfx::FRAGMENT, 0, m);
    gfx::draw(3);
    gfx::end_pass();
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = target;
    gfx::begin_pass(pass);
    gfx::bind(g.smaa_blend);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.color, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.weights, g.linear);
    gfx::uniforms(gfx::VERTEX, 0, m);
    gfx::uniforms(gfx::FRAGMENT, 0, m);
    gfx::draw(3);
    gfx::end_pass();
}

// The kept depth: 1x, 16-bit as the pass's, sampled by the pulsing marks.
fn depth_target(size: int2) -> gfx::Texture {
    return gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET | gfx::SAMPLED,
                                           width: size.x, height: size.y });
}

// Makes everything the renderer draws with: the meshes, the buffers, the pipelines, the
// baked surfaces' and the photograph's targets. Then apply() puts a theme on it.
// `samples` 4 is the multisampled pass; 1 draws straight into the target (measuring).
fn setup(g: render3d::Gpu&, samples: i32 = SAMPLES) {
    g.own.samples = samples;
    g.aa = if samples > 1 { AA_MSAA } else { AA_OFF };
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

    var empty: float4[render3d::SQUARES] = [float4_0; render3d::SQUARES];
    var none:  float4[render3d::SQUARES] = [float4 { 0.0, 0.0, 0.0, -1.0 }; render3d::SQUARES];
    g.instances = gfx::buffer(gfx::BUFFER_STORAGE, render3d::MAX_INSTANCES * 32, bytes_of(empty[..2]));
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
    g.plan_albedo = render3d::baked(model3d::PLAN_SIZE, model3d::PLAN_SIZE, gfx::RGBA8_SRGB);
    g.plan_normal = render3d::baked(model3d::PLAN_SIZE, model3d::PLAN_SIZE, gfx::RGBA8);
    g.frame_rows = 0;   // made by apply(), as the look's frame wants
    g.photo = gfx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, gfx::RGBA8);
    g.small = gfx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, gfx::RGBA8);
    g.across = gfx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, gfx::RGBA8);

    g.shadow_map = gfx::texture2d(render3d::SHADOW_SIZE, render3d::SHADOW_SIZE, gfx::DEPTH16,
                                  gfx::DEPTH_TARGET | gfx::SAMPLED);
    g.occ_map = gfx::texture(gfx::TextureDesc { format: gfx::R8, usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                                width: render3d::OCC_SIZE, height: render3d::OCC_SIZE });
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
                             gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true,
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
                                                  width: render3d::CROWN_SIZE, height: render3d::CROWN_SIZE });
    let crown = gfx::pipeline(full, embed_shader("frag", shaders::CROWN_FN, shaders::CROWN_FRAG));
    gfx::begin_pass(g.crown_map, gfx::Texture { 0 }, float4_0);
    gfx::bind(crown);
    gfx::draw(3);
    gfx::end_pass();
    gfx::release(crown);
    g.frame = default<render3d::Frame>();
    g.frame.view_proj = gfx::mat4_identity;
    g.frame.params.w = 8.0;
}

// The board and the opaque pieces' depth at 1x into g.kept_depth, as the pass above drew
// them (the fading pieces write none there either): only the vertices and a 16-bit
// target, no shading.
fn draw_depth(g: render3d::Gpu&) {
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
// phases (view3d::Scene.pulse), `next` how lit a capture's next stops are (Scene.next),
// `cursor` the keys' cursor's square in the world's grid, or -1 (Scene.cursor).
// The field's marks are the ones place() gave the image.
fn marks_over(g: render3d::Gpu&, pulse: float4, next: f32, cursor: f32, to: float4, alpha: f32, size: int2) {
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
    gfx::uniforms(gfx::FRAGMENT, 2, Pulse { pulse, float4 { to.x, to.y, 1.0 / k, alpha }, float4 { next, cursor, 0.0, 0.0 } });
    gfx::draw(6);
}

// The opaque pieces as instances, then the board, front to back: the field under the
// pieces fails the depth test before it is shaded. From the light when `light` is 1.
fn draw_meshes(g: render3d::Gpu&, light: f32) {
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
fn draw_backdrop(g: render3d::Gpu&, alpha: f32) {
    gfx::bind(g.backdrop);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.photo, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    let dim: f32 = if g.plain { render3d::PLAIN_DIM } else { 0.0 };
    gfx::uniforms(gfx::FRAGMENT, 1, Backdrop { float4 { alpha, dim, 0.0, 0.0 }, g.fade[0], g.fade[1], g.fade[2] });
    gfx::draw(3);
}

// The backdrop draw() leaves out without one, over the open pass's target of `size`
// (gfx's screen) at opacity `alpha`: under show()'s image, or fading in over the app's
// own photograph in a transition.
fn backdrop(g: render3d::Gpu&, alpha: f32, size: int2) {
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    guard render3d::kept_current(g, size) else {
        draw_backdrop(g, alpha);
        return;
    }
    gfx::bind(g.kept);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.kept_backdrop, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, Draw { float4 { alpha, 0.0, 0.0, 0.0 } });
    gfx::draw(3);
}

// Draws the kept image (draw() into g.image with its backdrop) over the open pass's
// target as it is: the prototype, under its tuning panel.
fn copy(g: render3d::Gpu&) {
    gfx::bind(g.copy);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.image, g.linear);
    gfx::draw(3);
}

// Draws the kept image (draw() into g.image without the backdrop) over the open pass's
// target of `size`: its rect `from` into the rect `to`, both x, y, width, height in
// pixels, at opacity `alpha`, `grey` of the way to grey and dimmer (shaders::SHOW_FRAG).
// The same rect is the image as drawn, texel for texel.
fn show(g: render3d::Gpu&, from: float4, to: float4, alpha: f32, size: int2, grey: f32 = 0.0) {
    gfx::bind(g.show);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.image, g.linear);
    let u = Show { from: from, to: to, screen: float4 { size.x, size.y, alpha, grey } };
    gfx::uniforms(gfx::VERTEX, 0, u);
    gfx::uniforms(gfx::FRAGMENT, 0, u);
    gfx::draw(6);
}

fn warm(g: render3d::Gpu&, k: i64) {
    if k == 0 {
        g.warm_color = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8, usage: gfx::COLOR_TARGET, width: 4,
                                                       height: 4, samples: g.own.samples });
        g.warm_depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET, width: 4,
                                                       height: 4, samples: g.own.samples });
        g.own.warm_kept = depth_target(int2 { 4, 4 });
    }
    var pass = gfx::PassDesc {};
    if k < 4 {
        pass.color[0] = g.warm_color;
        pass.depth = g.warm_depth;
    } else if k == 4 {
        pass.depth = g.shadow_map;
    } else if k == 5 {
        pass.depth = g.own.warm_kept;
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
    if k == render3d::WARM_STEPS - 1 {
        gfx::release(g.warm_color);
        gfx::release(g.warm_depth);
        gfx::release(g.own.warm_kept);
        g.warm_color = gfx::Texture { 0 };
        g.warm_depth = gfx::Texture { 0 };
        g.own.warm_kept = gfx::Texture { 0 };
    }
}

// Everything setup() and the frames made given back (the app's board back to flat): the
// targets, surfaces, buffers, samplers, and pipelines. g is set up again from scratch.
fn release(g: render3d::Gpu&) {
    let textures = [g.plan_albedo, g.plan_normal, g.frame_albedo, g.frame_normal, g.photo, g.shadow_map, g.occ_map, g.crown_map, g.color,
                    g.depth, g.image, g.kept_backdrop, g.kept_depth, g.small, g.across, g.warm_color, g.warm_depth,
                    g.own.warm_kept, g.edges, g.weights, g.area, g.search];
    for t in textures { if t.id != 0 { gfx::release(t); } }
    let buffers = [g.board_vb, g.board_ib, g.piece_vb, g.piece_ib, g.instances, g.squares, g.marks, g.glows];
    for b in buffers { if b.id != 0 { gfx::release(b); } }
    let samplers = [g.linear, g.aniso, g.compare];
    for s in samplers { if s.id != 0 { gfx::release(s); } }
    let pipelines = [g.lit, g.fading, g.shadow, g.backdrop, g.catcher, g.glow, g.pulse, g.depth_only, g.copy, g.show,
                     g.occ, g.kept, g.bake, g.shrink, g.blur, g.smaa_edges, g.smaa_weights, g.smaa_blend];
    for p in pipelines { if p.id != 0 { gfx::release(p); } }
    gfx::flush();
    g = default<render3d::Gpu>();
}
