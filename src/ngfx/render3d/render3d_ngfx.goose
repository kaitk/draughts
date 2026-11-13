// Recording the 3D board's renderer (render3d.goose) through goose-ngfx, beside gfx's
// recorder in the build that holds both (scripts/ngfx.py; render3d_gpu.goose there picks
// one): one forward pass, into 4× multisampled transient targets resolved into the
// picture as gfx's is, or at the size antialiasing wants and then SMAA or the 2 × 2
// supersampled pass shrunk. The shaders are gfx's GLSL in shaders.goose, written into
// Slang by scripts/ngfx_3d_shaders.py (src/ngfx/shaders/r3d_*.slang), each module with one
// root (Root) and its blob built ahead and embedded. The handles render3d.goose holds are
// gfx's types (nx).
namespace render3d_ngfx;
import std;
import vec;
import math;
import gfx;
import ngfx;

type Texture = render3d::Texture;
type Buffer = render3d::Buffer;
type Sampler = render3d::Sampler;
type Pipeline = render3d::Pipeline;
type Mat = render3d::Mat;
type Gpu = render3d::Gpu;

// What only ngfx's renderer holds, beside Gpu (whose `own` is gfx's): the nearest
// sampler SMAA reads with, the mips' and the supersampled pass's shrinking pipelines, and a
// 4 × 4 depth warm() makes the kept depth's pipelines on.
struct Own {
    point:     nx::Sampler,
    mip:       nx::Pipeline,
    down:      nx::Pipeline,
    warm_kept: nx::Texture,
}

var own = Own { point: gfx::Sampler { 0 }, mip: gfx::Pipeline { 0 }, down: gfx::Pipeline { 0 }, warm_kept: gfx::Texture { 0 } };

fn gpu_flush() { ngfx::flush(); }
fn gpu_release(t: Texture) { nx::release(t); }
fn gpu_target(w: i64, h: i64) -> Texture { nx::render_target(w, h, ngfx::RGBA8) }
fn gpu_clear(t: Texture, color: float4) {
    nx::begin_pass(t, nx::Texture { 0 }, color);
    ngfx::end_pass();
}
// Waits for the GPU, then releases two textures it was reading.
fn gpu_release_waited(a: Texture, b: Texture) {
    ngfx::flush();
    nx::release(a);
    nx::release(b);
}
fn gpu_update(b: Buffer, bytes: const u8[:]) { nx::update_buffer(b, bytes); }
fn gpu_mipped(w: i64, h: i64, format: i32, mips: i64) -> Texture {
    return nx::texture(ngfx::TextureDesc { format: format, usage: ngfx::COLOR_TARGET | ngfx::SAMPLED,
                                             width: w as i32, height: h as i32, mips: mips as i32 });
}

// The photograph's pipelines made ahead for its target (theme_step).
fn photo_pipelines(g: Gpu&) {
    nx::prepare(g.shrink, g.small, nx::Texture { 0 });
    nx::prepare(g.blur, g.small, nx::Texture { 0 });
}

// The shadow map, from the key light.
fn shadow_pass(g: Gpu&) {
    nx::begin_pass(nx::PassDesc { depth: g.shadow_map });
    nx::bind(g.shadow);
    draw_meshes(g, frame_addr(g), 1.0);
    ngfx::end_pass();
    settle();
}

// draw()'s one pass, at the scale antialiasing draws it at, then antialiased into
// `target` of `size`.
fn board_pass(g: Gpu&, target: Texture, size: int2, backdrop: bool) {
    // The pass at the scale it is drawn at: its block's screen is the target's.
    let k = scale(g);
    g.frame.screen = float4 { size.x * k, size.y * k, g.frame.screen.z, 0.0 };
    let f = frame_addr(g);
    let clear = if backdrop { float4 { 0.11, 0.078, 0.063, 1.0 } } else { float4_0 };
    var pass = nx::PassDesc { depth: g.depth, color_value: clear };
    pass.color[0] = if g.aa != AA_OFF { g.color } else { target };
    if g.aa == AA_MSAA { pass.resolve[0] = target; }
    nx::begin_pass(pass);
    if backdrop { draw_backdrop(g, f, 1.0); }

    nx::bind(g.lit);
    draw_meshes(g, f, 0.0);
    // The fading pieces, each alone at its opacity, over what stands behind them.
    if g.solid < g.instance_count {
        nx::bind(g.fading);
        for i in g.solid..g.instance_count {
            var r = lit_root(g, f, g.piece_vb);
            r.u = blocks([float4 { 1.0, 0.0, g.alphas[i - g.solid], i }]);
            nx::draw_indexed(ngfx::root(r), g.piece_ib, 4, g.piece_count);
        }
    }

    // The board's soft shadow round it, after the board so the depth test leaves out
    // what the board covers.
    nx::bind(g.catcher);
    var c = no_root();
    c.frame = f;
    c.u = blocks([float4_0]);
    ngfx::draw(ngfx::root(c), 6);

    // The field's marks and the selected piece's ring, added where nothing stands over;
    // none, nothing drawn.
    if g.marked {
        nx::bind(g.glow);
        var m = no_root();
        m.frame = f;
        m.u = blocks([float4 { 2.0, g.n, 0.0, 0.0 }]);
        m.buf0 = nx::address(g.marks);
        m.buf1 = nx::address(g.glows);
        ngfx::draw(ngfx::root(m), 6);
    }
    ngfx::end_pass();
    settle();
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    antialias(g, target, size);
}

// The occlusion map's texels x0..x1, y0..y1 drawn again from the field's squares.
fn occ_pass(g: Gpu&, x0: i64, y0: i64, x1: i64, y1: i64) {
    var pass = nx::PassDesc { clear_color: false };
    pass.color[0] = g.occ_map;
    nx::begin_pass(pass);
    ngfx::scissor(x0, y0, x1 - x0, y1 - y0);
    nx::bind(g.occ);
    var r = no_root();
    r.frame = frame_addr(g);
    r.buf0 = nx::address(g.squares);
    ngfx::draw(ngfx::root(r), 3);
    ngfx::end_pass();
    settle();
}

// The backdrop at full opacity into the kept one.
fn kept_pass(g: Gpu&) {
    var pass = nx::PassDesc { clear_color: false };
    pass.color[0] = g.kept_backdrop;
    nx::begin_pass(pass);
    draw_backdrop(g, frame_addr(g), 1.0);
    ngfx::end_pass();
    settle();
}

let mat_identity = Mat { c0: float4 { 1.0, 0.0, 0.0, 0.0 }, c1: float4 { 0.0, 1.0, 0.0, 0.0 },
                         c2: float4 { 0.0, 0.0, 1.0, 0.0 }, c3: float4 { 0.0, 0.0, 0.0, 1.0 } };

fn mul(m: Mat, v: float4) -> float4 { m.c0 * v.x + m.c1 * v.y + m.c2 * v.z + m.c3 * v.w }

// Every module's root (src/ngfx/shaders/r3d.slang): the frame's block and the uniform
// blocks' float4s in this frame's memory, the storage buffers, the vertices, and the
// textures with their samplers in the slots each module's header lists.
struct Root { frame: u64, u: u64, buf0: u64, buf1: u64, buf2: u64, verts: u64, tex: u32[8], smp: u32[8] }

fn no_root() -> Root { Root { frame: 0, u: 0, buf0: 0, buf1: 0, buf2: 0, verts: 0, tex: [0; 8], smp: [0; 8] } }

// How the 3D pass is antialiased: not at all; SMAA 1x over the pass drawn at 1x; the
// pass drawn at twice the size and shrunk (2 x 2 supersampling); or 4× multisampled into
// transient targets, resolved as the pass ends (task 077).
let AA_OFF = 0;

let AA_SMAA = 2;

let AA_SSAA = 3;

let AA_MSAA = 4;

// The default, as gfx's: on the M1 Pro 10% under SMAA's GPU time and 12 MB less GPU memory
// while drawing (its targets memoryless), 2% over gfx's MSAA (task 077).
let AA = AA_MSAA;

let SAMPLES = 4;

// The pass's ways by the names --aa takes and the log prints (-1 for none), and the next
// the A key switches to: MSAA, SMAA, none, and 2 × 2 supersampling in turn.
fn aa_named(name: const u8[:]) -> i32 {
    if name == "off" { return AA_OFF; }
    if name == "msaa" { return AA_MSAA; }
    if name == "smaa" { return AA_SMAA; }
    if name == "ssaa" { return AA_SSAA; }
    return -1;
}

fn aa_name(aa: i32) -> const u8[:] {
    if aa == AA_MSAA { "msaa" } else if aa == AA_SMAA { "smaa" } else if aa == AA_SSAA { "ssaa" } else { "off" }
}

fn aa_next(aa: i32) -> i32 {
    if aa == AA_MSAA { AA_SMAA } else if aa == AA_SMAA { AA_OFF } else if aa == AA_OFF { AA_SSAA } else { AA_MSAA }
}

// A target of the pass: 4× and transient (cleared, never stored, and on Metal kept in
// tile memory alone) with AA_MSAA, else one sample, `usage` alone.
fn pass_target(g: Gpu&, w: i64, h: i64, format: i32, usage: i32) -> nx::Texture {
    let msaa = g.aa == AA_MSAA;
    return nx::texture(ngfx::TextureDesc { format: format, usage: if msaa { usage | ngfx::TRANSIENT } else { usage },
                                             width: w as i32, height: h as i32, samples: if msaa { SAMPLES } else { 1 } });
}

// What a pass wrote, before what comes after reads or writes it again: between passes,
// as ngfx wants, where SDL_GPU orders passes itself.
fn settle() {
    ngfx::barrier(ngfx::TARGET_WRITE | ngfx::FRAGMENT_READ, ngfx::TARGET_WRITE | ngfx::FRAGMENT_READ);
}

// The frame's block as it is now, in this frame's memory, for a root.
fn frame_addr(g: Gpu&) -> u64 {
    let one: render3d::Frame[1] = [g.frame];
    return ngfx::frame_data(bytes_of(one));
}

// The lit pass's pipelines, the board's and a fading piece's, their shadow filtered as
// `look` says (render3d::SHADOW_9..): in 4 taps (r3d_lit_few, shaders::SHADOW_FEW), 16
// (r3d_lit_many, shaders::SHADOW_MANY), or 9.
fn lit_pipelines(g: Gpu&, look: i32) {
    let lit = if look == render3d::SHADOW_4 { embed_file("../app/shaders/r3d_lit_few.blob") }
              else if look == render3d::SHADOW_16 { embed_file("../app/shaders/r3d_lit_many.blob") }
              else { embed_file("../app/shaders/r3d_lit.blob") };
    g.lit = nx::pipeline(lit, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true });
    g.fading = nx::pipeline(lit, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, blend: ngfx::BLEND_ALPHA });
    g.shadow_look = look;
}

// The shadow filtered as `look` says from the next draw on: the lit pipelines made
// again if it changes (render3d_gpu.goose's set_shadow).
fn set_shadow(g: Gpu&, look: i32) {
    guard g.lit.id != 0 && look != g.shadow_look else { return; }
    ngfx::flush();
    nx::release(g.lit);
    nx::release(g.fading);
    lit_pipelines(g, look);
}

// float4s in this frame's memory: a root's uniform blocks.
fn blocks(u: const float4[:]) -> u64 { return ngfx::frame_data(bytes_of(u)); }

// Texture slot i of a root: the texture and its sampler.
fn slot(r: Root&, i: i64, t: nx::Texture, s: nx::Sampler) {
    r.tex[i] = nx::index(t);
    r.smp[i] = nx::index(s);
}

// A full-screen module's pipeline, its blob built ahead (scripts/ngfx.py).
fn module(blob: const u8[:], desc: ngfx::PipelineDesc = ngfx::PipelineDesc {}) -> nx::Pipeline {
    return nx::pipeline(blob, desc);
}

// Part k of photograph(), each short enough for a frame (theme_step): 0 the photograph
// decoded or uploaded and shrunk, 1 blurred across, 2 blurred down, read back, and its
// harmonics taken into sh.
fn photo_part(g: Gpu&, kind: i64, grey: f32, sh: float4[9]&, k: i64) {
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
            nx::begin_pass(g.photo, nx::Texture { 0 }, float4 { 0.11, 0.078, 0.063, 1.0 });
            ngfx::end_pass();
            settle();
            for i in 9 { sh[i] = float4_0; }
            sh[0] = model3d::no_photo_ambient();
            return;
        }
        nx::begin_pass(g.small, nx::Texture { 0 }, float4_0);
        nx::bind(g.shrink);
        var r = no_root();
        slot(r, 0, sharp, g.linear);
        r.u = blocks([float4 { render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, 0.0, 0.0 }]);
        ngfx::draw(ngfx::root(r), 3);
        ngfx::end_pass();
        settle();
        // Given back once the GPU is done with it.
        ngfx::flush();
        nx::release(sharp);
        return;
    }
    guard !g.no_photo else { return; }
    if k == 1 {
        blur(g, g.small, g.across, float4 { s, 0.0, 5.6, s });
        return;
    }
    blur(g, g.across, g.photo, float4 { 0.0, s, 5.6, s });
    let px = nx::read_pixels(g.photo);
    sh = model3d::harmonics(px, render3d::PHOTO_SIZE, grey);
}

fn blur(g: Gpu&, from: nx::Texture, to: nx::Texture, dir: float4) {
    nx::begin_pass(to, nx::Texture { 0 }, float4_0);
    nx::bind(g.blur);
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
fn bake(g: Gpu&, albedo: nx::Texture, normal: nx::Texture, w: i64, h: i64, mode: f32,
        extent: float2, t: looks::Theme&, y0: i64 = 0, y1: i64 = -1, mips: bool = true) {
    // Not cleared: the bake writes every texel. Only rows y0 to y1 when given
    // (theme_step's bands), the mips after the last.
    var pass = nx::PassDesc { clear_color: false };
    pass.color[0] = albedo;
    pass.color[1] = normal;
    nx::begin_pass(pass);
    if y1 >= 0 { ngfx::scissor(0, y0, w, y1 - y0); }
    nx::bind(g.bake);
    let fi = g.finish;
    let m = g.stone;
    let u: render3d::Bake[1] = [render3d::Bake { float4 { mode, g.wood, g.n, g.marble },
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
fn mip_chain(g: Gpu&, t: nx::Texture) {
    let levels = nx::texture_info(t).mips as i64;
    for level in 1..levels {
        var pass = nx::PassDesc { mip: level as i32, clear_color: false };
        pass.color[0] = t;
        nx::begin_pass(pass);
        nx::bind(own.mip);
        ngfx::draw(ngfx::root(MipRoot { src: nx::index(t), level: (level - 1) as u32, pad0: 0, pad1: 0 }), 3);
        ngfx::end_pass();
        settle();
    }
}

struct MipRoot { src: u32, level: u32, pad0: u32, pad1: u32 }

// The pass's target (at twice the size for AA_SSAA, 4× for AA_MSAA) and its depth, and
// SMAA's, at g.size, made for a draw after rest() gave them back.
fn pass_targets(g: Gpu&) {
    guard g.depth.id == 0 else { return; }
    let size = g.size;
    let k = scale(g);
    if g.aa == AA_MSAA {
        g.color = pass_target(g, size.x, size.y, ngfx::RGBA8, ngfx::COLOR_TARGET);
    } else if g.aa != AA_OFF {
        g.color = nx::render_target(size.x * k, size.y * k, ngfx::RGBA8);
    }
    if g.aa == AA_SMAA {
        g.edges = nx::render_target(size.x, size.y, ngfx::RG8);
        g.weights = nx::render_target(size.x, size.y, ngfx::RGBA8);
    }
    // 16-bit depth is plenty between NEAR 2 and FAR 40 for a scene 10 to 20 away (a step
    // about 0.003 at 20, under the marks' 0.004 lift).
    g.depth = pass_target(g, size.x * k, size.y * k, ngfx::DEPTH16, ngfx::DEPTH_TARGET);
}

// The pass antialiased by `aa` (AA_OFF..) from the next draw on: its targets given back
// (made again for the new way by the next draw), the way's pipelines and tables made the
// first time it is chosen. The app's A key (task 071). It draws SAMPLES whatever `samples`
// says: fewer are asked for only on Android, which the ngfx build isn't built for.
fn set_aa(g: Gpu&, aa: i32, samples: i32 = SAMPLES) {
    render3d::give_back(g);
    g.aa = aa;
    aa_resources(g, aa);
}

// What antialiasing by `aa` draws with, made once.
fn aa_resources(g: Gpu&, aa: i32) {
    if aa == AA_SMAA && g.smaa_edges.id == 0 {
        let smaa = embed_file("../app/shaders/smaa.blob");
        // The edges pass marks the pixels it finds an edge on with depth 0 (its triangle's
        // z; where it finds none it discards, leaving the cleared 1), and the weights pass,
        // drawn at the same z, tests it equal: the early depth test skips the pixels with
        // no edge, whose weights are 0, as the cleared target holds them. SMAA's reference
        // does it with a stencil, which ngfx has none of; the pass's own depth is free by
        // then and holds no stencil.
        g.smaa_edges = nx::pipeline(smaa, "edges_vertex", "edges_fragment",
                                      ngfx::PipelineDesc { depth_test: true, depth_write: true,
                                                           depth_compare: ngfx::COMPARE_ALWAYS });
        g.smaa_weights = nx::pipeline(smaa, "weights_vertex", "weights_fragment",
                                        ngfx::PipelineDesc { depth_test: true, depth_compare: ngfx::COMPARE_EQUAL });
        g.smaa_blend = nx::pipeline(smaa, "blend_vertex", "blend_fragment", ngfx::PipelineDesc {});
        g.area = nx::texture2d(160, 560, ngfx::RG8, ngfx::SAMPLED);
        nx::update_texture(g.area, embed_file("../app/shaders/smaa_area.bin"));
        g.search = nx::texture2d(64, 16, ngfx::R8, ngfx::SAMPLED);
        nx::update_texture(g.search, embed_file("../app/shaders/smaa_search.bin"));
    }
}

// How many times the size the pass is drawn at: 2 for AA_SSAA.
fn scale(g: Gpu&) -> i64 { return if g.aa == AA_SSAA { 2 } else { 1 }; }

// The kept depth: 1x, 16-bit as the pass's, sampled by the pulsing marks.
fn depth_target(size: int2) -> nx::Texture {
    return nx::texture2d(size.x, size.y, ngfx::DEPTH16, ngfx::DEPTH_TARGET | ngfx::SAMPLED);
}

// Makes everything the renderer draws with: the meshes, the buffers, the pipelines, the
// baked surfaces' and the photograph's targets. Then apply() puts a theme on it.
// `aa` is how the pass is antialiased (AA_OFF..AA_MSAA); `look` how the shadow is
// filtered (render3d::SHADOW_9..; set_shadow).
fn setup(g: Gpu&, aa: i32 = AA, look: i32 = render3d::SHADOW_9) {
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
    g.board_vb = nx::buffer(bytes_of(verts));
    g.board_ib = nx::buffer(bytes_of(indices));
    g.board_count = indices.len;
    verts.resize(0);
    indices.resize(0);
    mesh::piece(verts, indices);
    g.piece_vb = nx::buffer(bytes_of(verts));
    g.piece_ib = nx::buffer(bytes_of(indices));
    g.piece_count = indices.len;

    var empty: float4[render3d::SQUARES] = [float4_0; render3d::SQUARES];
    var none:  float4[render3d::SQUARES] = [float4 { 0.0, 0.0, 0.0, -1.0 }; render3d::SQUARES];
    var no_squares: float4[render3d::SQUARE_ENTRIES] = [float4_0; render3d::SQUARE_ENTRIES];
    g.instances = nx::buffer(render3d::MAX_INSTANCES * 32, bytes_of(empty[..2]));
    g.instance_count = 0;
    g.squares = nx::buffer(bytes_of(no_squares));
    g.marks = nx::buffer(bytes_of(none));
    g.glows = nx::buffer(bytes_of(empty));

    let blend = ngfx::PipelineDesc { blend: ngfx::BLEND_ALPHA };
    g.bake = module(embed_file("../app/shaders/r3d_bake.blob"));
    g.shrink = module(embed_file("../app/shaders/r3d_shrink.blob"));
    g.blur = module(embed_file("../app/shaders/r3d_blur.blob"));
    g.copy = module(embed_file("../app/shaders/r3d_copy.blob"));
    own.mip = module(embed_file("../app/shaders/mip.blob"));
    own.down = module(embed_file("../app/shaders/down.blob"));
    aa_resources(g, aa);
    g.show = module(embed_file("../app/shaders/r3d_show.blob"), ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED });
    g.plan_albedo = render3d::baked(model3d::PLAN_SIZE, model3d::PLAN_SIZE, ngfx::RGBA8_SRGB);
    g.plan_normal = render3d::baked(model3d::PLAN_SIZE, model3d::PLAN_SIZE, ngfx::RGBA8);
    g.frame_rows = 0;   // made by apply(), as the look's frame wants
    g.photo = nx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, ngfx::RGBA8);
    g.small = nx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, ngfx::RGBA8);
    g.across = nx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, ngfx::RGBA8);

    g.shadow_map = nx::texture2d(render3d::SHADOW_SIZE, render3d::SHADOW_SIZE, ngfx::DEPTH16, ngfx::DEPTH_TARGET | ngfx::SAMPLED);
    g.occ_map = nx::render_target(render3d::OCC_SIZE, render3d::OCC_SIZE, ngfx::R8);
    g.occ_n = 0;
    g.occ = module(embed_file("../app/shaders/r3d_occ.blob"));
    g.kept = module(embed_file("../app/shaders/r3d_kept.blob"), blend);
    g.linear = nx::sampler(ngfx::LINEAR, ngfx::CLAMP);
    own.point = nx::sampler(ngfx::NEAREST, ngfx::CLAMP);
    g.aniso = nx::sampler(ngfx::SamplerDesc { max_anisotropy: 8.0 });
    g.compare = nx::shadow_sampler();

    let depth = embed_file("../app/shaders/r3d_depth.blob");
    let marks = embed_file("../app/shaders/r3d_marks.blob");
    lit_pipelines(g, look);
    g.shadow = nx::pipeline(depth, ngfx::PipelineDesc { depth_test: true, depth_write: true, depth_bias: 1.0,
                                                          depth_bias_slope: 1.5 });
    g.backdrop = module(embed_file("../app/shaders/r3d_backdrop.blob"), blend);
    g.catcher = nx::pipeline(embed_file("../app/shaders/r3d_catcher.blob"),
                               ngfx::PipelineDesc { depth_test: true, blend: ngfx::BLEND_ALPHA });
    g.glow = nx::pipeline(marks, ngfx::PipelineDesc { depth_test: true, blend: ngfx::BLEND_PREMULTIPLIED });
    g.pulse = nx::pipeline(embed_file("../app/shaders/r3d_pulse.blob"), ngfx::PipelineDesc { blend: ngfx::BLEND_ADD });
    g.depth_only = nx::pipeline(depth, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true });
    // The crown's distance, once: a small pipeline made, drawn, and given back.
    g.crown_map = nx::render_target(render3d::CROWN_SIZE, render3d::CROWN_SIZE, ngfx::R16F);
    let crown = module(embed_file("../app/shaders/r3d_crown.blob"));
    nx::begin_pass(g.crown_map, nx::Texture { 0 }, float4_0);
    nx::bind(crown);
    ngfx::draw(ngfx::root(no_root()), 3);
    ngfx::end_pass();
    settle();
    ngfx::flush();
    nx::release(crown);
    g.frame = default<render3d::Frame>();
    g.frame.view_proj = mat_identity;
    g.frame.params.w = 8.0;
}

struct DownRoot { src: u32, pad0: u32, pad1: u32, pad2: u32 }

struct SmaaRoot { color: u32, edges: u32, weights: u32, area: u32, search: u32, linear: u32, point: u32, pad0: u32,
                  metrics: float4 }

// The pass in g.color antialiased into `target` as g.aa says: shrunk (AA_SSAA) or
// SMAA's three (shaders/smaa.slang); with AA_OFF the pass drew into it, and with AA_MSAA
// resolved into it.
fn antialias(g: Gpu&, target: nx::Texture, size: int2) {
    guard g.aa != AA_OFF && g.aa != AA_MSAA else { return; }
    let metrics = float4 { 1.0 / size.x, 1.0 / size.y, size.x, size.y };
    if g.aa == AA_SSAA {
        nx::begin_pass(target, nx::Texture { 0 }, float4_0);
        nx::bind(own.down);
        ngfx::draw(ngfx::root(DownRoot { src: nx::index(g.color), pad0: 0, pad1: 0, pad2: 0 }), 3);
        ngfx::end_pass();
    } else {
        let r = SmaaRoot { color: nx::index(g.color), edges: nx::index(g.edges), weights: nx::index(g.weights),
                           area: nx::index(g.area), search: nx::index(g.search), linear: nx::index(g.linear),
                           point: nx::index(own.point), pad0: 0, metrics: metrics };
        let steps = [g.smaa_edges, g.smaa_weights, g.smaa_blend];
        let into = [g.edges, g.weights, target];
        for p, i in steps {
            // The edges and the weights with the pass's depth (above), the edges clearing it.
            var pass = nx::PassDesc { color_value: float4_0, clear_depth: i == 0 };
            pass.color[0] = into[i];
            if i < 2 { pass.depth = g.depth; }
            nx::begin_pass(pass);
            nx::bind(p);
            ngfx::draw(ngfx::root(r), 3);
            ngfx::end_pass();
            if i < 2 { settle(); }
        }
    }
    settle();
}

// The lit module's root (r3d_lit.slang's header): the frame, the instances, the vertices,
// and its seven textures.
fn lit_root(g: Gpu&, f: u64, vb: nx::Buffer) -> Root {
    var r = no_root();
    r.frame = f;
    r.buf0 = nx::address(g.instances);
    r.verts = nx::address(vb);
    slot(r, 0, g.plan_albedo, g.aniso);
    slot(r, 1, g.plan_normal, g.aniso);
    slot(r, 2, g.frame_albedo, g.aniso);
    slot(r, 3, g.frame_normal, g.aniso);
    slot(r, 4, g.shadow_map, g.compare);
    slot(r, 5, g.occ_map, g.linear);
    slot(r, 6, g.crown_map, g.linear);
    return r;
}

// The board and the opaque pieces' depth at 1x into g.kept_depth, as the pass above drew
// them (the fading pieces write none there either): only the vertices and a 16-bit
// target, no shading.
fn draw_depth(g: Gpu&) {
    if g.kept_depth.id == 0 { g.kept_depth = depth_target(g.size); }
    nx::begin_pass(nx::PassDesc { depth: g.kept_depth });
    nx::bind(g.depth_only);
    draw_meshes(g, frame_addr(g), 0.0);
    ngfx::end_pass();
    settle();
}

// The pulsing marks (shaders::MARKS_FRAG with PULSE) over the open pass's target of
// `size`, where show() laid the kept image: drawn with it (draw() with keep_depth) into
// its rect `to` (as show()'s, the whole image), as opaque as `alpha`. `pulse` their
// phases (view3d::Scene.pulse), `next` how lit a capture's next stops are (Scene.next),
// `cursor` the keys' cursor's square in the world's grid, or -1 (Scene.cursor).
// The field's marks are the ones place() gave the image.
fn marks_over(g: Gpu&, pulse: float4, next: f32, cursor: f32, to: float4, alpha: f32, size: int2) {
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
    g.frame.view_proj = render3d::mul(place, keep);
    let f = frame_addr(g);
    g.frame.view_proj = keep;
    nx::bind(g.pulse);
    var r = no_root();
    r.frame = f;
    // r3d_pulse.slang's header: Draw, then Pulse.
    r.u = blocks([float4 { 2.0, g.n, 0.0, 0.0 }, pulse, float4 { to.x, to.y, 1.0 / k, alpha },
                 float4 { next, cursor, 0.0, 0.0 }]);
    r.buf0 = nx::address(g.marks);
    r.buf1 = nx::address(g.glows);
    slot(r, 0, g.kept_depth, g.linear);
    ngfx::draw(ngfx::root(r), 6);
}

// The opaque pieces as instances, then the board, front to back: the field under the
// pieces fails the depth test before it is shaded. From the light when `light` is 1.
fn draw_meshes(g: Gpu&, f: u64, light: f32) {
    if g.solid > 0 {
        var r = lit_root(g, f, g.piece_vb);
        r.u = blocks([float4 { 1.0, light, 1.0, 0.0 }]);
        nx::draw_indexed_instanced(ngfx::root(r), g.piece_ib, 4, g.piece_count, g.solid);
    }
    var r = lit_root(g, f, g.board_vb);
    r.u = blocks([float4 { 0.0, light, 1.0, 0.0 }]);
    nx::draw_indexed(ngfx::root(r), g.board_ib, 4, g.board_count);
}

// The blurred photograph, graded, or the plain fade dimmed as the flat game dims what is
// behind it (draw::frame's 0.8), at opacity `alpha` over the open pass's target; `f` the
// frame's block, its screen the target's size.
fn draw_backdrop(g: Gpu&, f: u64, alpha: f32) {
    nx::bind(g.backdrop);
    var r = no_root();
    r.frame = f;
    let dim: f32 = if g.plain { render3d::PLAIN_DIM } else { 0.0 };
    r.u = blocks([float4 { alpha, dim, 0.0, 0.0 }, g.fade[0], g.fade[1], g.fade[2]]);
    slot(r, 0, g.photo, g.linear);
    ngfx::draw(ngfx::root(r), 3);
}

// The backdrop draw() leaves out without one, over the open pass's target of `size`
// (gfx's screen) at opacity `alpha`: under show()'s image, or fading in over the app's
// own photograph in a transition.
fn backdrop(g: Gpu&, alpha: f32, size: int2) {
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    guard render3d::kept_current(g, size) else {
        draw_backdrop(g, frame_addr(g), alpha);
        return;
    }
    nx::bind(g.kept);
    var r = no_root();
    r.u = blocks([float4 { alpha, 0.0, 0.0, 0.0 }]);
    slot(r, 0, g.kept_backdrop, g.linear);
    ngfx::draw(ngfx::root(r), 3);
}

// Draws the kept image (draw() into g.image with its backdrop) over the open pass's
// target as it is: the prototype, under its tuning panel.
fn copy(g: Gpu&) {
    nx::bind(g.copy);
    var r = no_root();
    slot(r, 0, g.image, g.linear);
    ngfx::draw(ngfx::root(r), 3);
}

// Draws the kept image (draw() into g.image without the backdrop) over the open pass's
// target of `size`: its rect `from` into the rect `to`, both x, y, width, height in
// pixels, at opacity `alpha`, `grey` of the way to grey and dimmer (shaders::SHOW_FRAG).
// The same rect is the image as drawn, texel for texel.
fn show(g: Gpu&, from: float4, to: float4, alpha: f32, size: int2, grey: f32 = 0.0) {
    nx::bind(g.show);
    var r = no_root();
    r.u = blocks([from, to, float4 { size.x, size.y, alpha, grey }]);
    slot(r, 0, g.image, g.linear);
    ngfx::draw(ngfx::root(r), 6);
}

fn warm(g: Gpu&, k: i64) {
    if k == 0 {
        // The pass's pipelines for its targets (4× with AA_MSAA), the depth-only ones for
        // a kept depth's 1x.
        g.warm_color = pass_target(g, 4, 4, ngfx::RGBA8, ngfx::COLOR_TARGET);
        g.warm_depth = pass_target(g, 4, 4, ngfx::DEPTH16, ngfx::DEPTH_TARGET);
        own.warm_kept = depth_target(int2 { 4, 4 });
    }
    var pass = nx::PassDesc {};
    if k < 4 {
        pass.color[0] = g.warm_color;
        pass.depth = g.warm_depth;
        // The backdrop is drawn in the pass too, and at 1x into the screen (below).
        if k == 0 && g.aa == AA_MSAA { nx::prepare(g.backdrop, pass); }
    } else if k == 4 || k == 5 {
        pass.depth = own.warm_kept;
    } else if k == 9 {
        pass.color[0] = g.occ_map;
    } else {
        pass.color[0] = nx::screen();
    }
    let p = [g.lit, g.fading, g.catcher, g.glow, g.shadow, g.depth_only, g.backdrop, g.show, g.pulse, g.occ,
             g.kept][k];
    nx::prepare(p, pass);
    if k == render3d::WARM_STEPS - 1 && g.aa != AA_MSAA {
        // The antialiasing's pipelines, for the RGBA8 targets they draw into, and SMAA's
        // edges for RG8 (none after a multisampled pass, and the warm targets are 4× then).
        var into = nx::PassDesc {};
        into.color[0] = g.warm_color;
        let post = [own.down, g.smaa_blend];
        for q in post { if q.id != 0 { nx::prepare(q, into); } }
        // SMAA's weights test the depth its edges wrote (antialias).
        into.depth = g.warm_depth;
        if g.smaa_weights.id != 0 { nx::prepare(g.smaa_weights, into); }
        if g.smaa_edges.id != 0 {
            let rg = nx::render_target(4, 4, ngfx::RG8);
            into.color[0] = rg;
            nx::prepare(g.smaa_edges, into);
            nx::release(rg);
        }
    }
    if k == render3d::WARM_STEPS - 1 {
        nx::release(g.warm_color);
        nx::release(g.warm_depth);
        nx::release(own.warm_kept);
        g.warm_color = nx::Texture { 0 };
        g.warm_depth = nx::Texture { 0 };
        own.warm_kept = nx::Texture { 0 };
    }
}

// Everything setup() and the frames made given back (the app's board back to flat): the
// targets, surfaces, buffers, samplers, and pipelines. g is set up again from scratch.
fn release(g: Gpu&) {
    ngfx::flush();
    let textures = [g.plan_albedo, g.plan_normal, g.frame_albedo, g.frame_normal, g.photo, g.shadow_map, g.occ_map,
                    g.crown_map, g.color, g.depth, g.image, g.kept_backdrop, g.kept_depth, g.small, g.across,
                    g.warm_color, g.warm_depth, own.warm_kept, g.edges, g.weights, g.area, g.search];
    for t in textures { if t.id != 0 { nx::release(t); } }
    let buffers = [g.board_vb, g.board_ib, g.piece_vb, g.piece_ib, g.instances, g.squares, g.marks, g.glows];
    for b in buffers { if b.id != 0 { nx::release(b); } }
    let samplers = [g.linear, own.point, g.aniso, g.compare];
    for s in samplers { if s.id != 0 { nx::release(s); } }
    let pipelines = [g.lit, g.fading, g.shadow, g.backdrop, g.catcher, g.glow, g.pulse, g.depth_only, g.copy, g.show,
                     g.occ, g.kept, g.bake, g.shrink, g.blur, own.mip, own.down, g.smaa_edges, g.smaa_weights,
                     g.smaa_blend];
    for p in pipelines { if p.id != 0 { nx::release(p); } }
    own = default<Own>();
    g = default<Gpu>();
}
