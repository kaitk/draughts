// Recording the 3D board's renderer (render3d.goose) through goose-ngfx, beside gfx's
// recorder (src/render3d/render3d_gpu.goose) in the build that holds both
// (src/main/draughts_ngfx.goose): one forward pass, into 4× multisampled transient
// targets resolved into the picture as gfx's is, or at the size antialiasing wants and
// then SMAA or the 2 × 2 supersampled pass shrunk. The shaders are gfx's GLSL in
// shaders.goose, written into Slang by scripts/ngfx_3d_shaders.py, each module with one
// root (Root) and its blob built ahead. The handles render3d.goose holds are gfx's types (nx).
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

// What only ngfx's renderer holds beside Gpu, the first parameter of each of its calls,
// which render3d.goose makes on it as on gfx's render3d::Own: the nearest sampler SMAA reads
// with, the mips' and the supersampled pass's shrinking pipelines, and a 4 × 4 depth warm()
// makes the kept depth's pipelines on.
struct Own {
    point:     nx::Sampler,
    mip:       nx::Pipeline,
    down:      nx::Pipeline,
    warm_kept: nx::Texture,
}

// Theme `kind`'s photograph through goose-ngfx's C (photo_ngfx.c), or 0 when it isn't built in.
extern fn draughts_photo_ngfx_id(kind: i64, decoded: i64) -> u32;
fn photo(own: Own&, kind: i64, decoded: i64) -> Texture { Texture { draughts_photo_ngfx_id(kind, decoded) } }

fn gpu_flush(own: Own&) { ngfx::flush(); }
fn gpu_release(own: Own&, t: Texture) { nx::release(t); }
fn gpu_target(own: Own&, w: i64, h: i64) -> Texture { nx::render_target(w, h, ngfx::RGBA8) }
fn gpu_clear(own: Own&, t: Texture, color: float4) {
    nx::begin_pass(t, nx::Texture { 0 }, color);
    ngfx::end_pass();
}
// Waits for the GPU, then releases two textures it was reading.
fn gpu_release_waited(own: Own&, a: Texture, b: Texture) {
    ngfx::flush();
    nx::release(a);
    nx::release(b);
}
fn gpu_update(own: Own&, b: Buffer, bytes: const u8[:]) { nx::update_buffer(b, bytes); }
fn gpu_mesh(own: Own&, verts: const u8[:], indices: const u8[:]) -> Buffer, Buffer {
    return nx::buffer(verts), nx::buffer(indices);
}
fn gpu_release_mesh(own: Own&, vb: Buffer, ib: Buffer) {
    ngfx::flush();
    nx::release(vb);
    nx::release(ib);
}
fn gpu_mipped(own: Own&, w: i64, h: i64, format: i32, mips: i64) -> Texture {
    return nx::texture(ngfx::TextureDesc { format: format, usage: ngfx::COLOR_TARGET | ngfx::SAMPLED,
                                             width: w as i32, height: h as i32, mips: mips as i32 });
}
// A texture only sampled, of `format` with `mips` levels, filled by gpu_upload.
fn gpu_sampled(own: Own&, w: i64, h: i64, mips: i64, format: i32) -> Texture {
    return nx::texture(ngfx::TextureDesc { format: format, usage: ngfx::SAMPLED, width: w as i32, height: h as i32,
                                             mips: mips as i32 });
}
fn gpu_upload(own: Own&, t: Texture, mip: i64, bytes: const u8[:]) { nx::update_texture(t, ngfx::Region { mip: mip as i32 }, bytes); }

// The photograph's pipelines made ahead for its target (theme_step).
fn photo_pipelines(own: Own&, g: Gpu&) {
    nx::prepare(g.shrink, g.small, nx::Texture { 0 });
    nx::prepare(g.blur, g.small, nx::Texture { 0 });
}

fn shadow_pass(own: Own&, g: Gpu&) {
    nx::begin_pass(nx::PassDesc { depth: g.shadow_map });
    nx::bind(g.shadow);
    draw_meshes(own, g, frame_addr(own, g), 1.0);
    ngfx::end_pass();
    barrier_between_passes();
}

// The table's top and base into its own map (render3d::table_map), seen along the key
// through `place`: the key's pipeline, the board's frame with its light's projection
// replaced, made the first time.
fn table_map_pass(own: Own&, g: Gpu&, place: Mat) {
    if g.table_map.id == 0 {
        g.table_map = nx::texture2d(render3d::TABLE_MAP_W, render3d::TABLE_MAP_H, ngfx::DEPTH16,
                                    ngfx::DEPTH_TARGET | ngfx::SAMPLED);
    }
    let kept = g.frame.light_view_proj;
    g.frame.light_view_proj = place;
    let f = frame_addr(own, g);
    g.frame.light_view_proj = kept;
    nx::begin_pass(nx::PassDesc { depth: g.table_map });
    nx::bind(g.shadow);
    var r = lit_root(own, g, f, g.table_vb);
    r.u = blocks([float4 { 0.0, 1.0, 1.0, 0.0 }]);
    nx::draw_indexed(ngfx::root(r), g.table_ib, 4, g.table_count);
    ngfx::end_pass();
    barrier_between_passes();
}

// draw()'s one pass, at the scale antialiasing draws it at, then antialiased into
// `target` of `size`.
fn board_pass(own: Own&, g: Gpu&, target: Texture, size: int2, backdrop: bool) {
    // The pass at the scale it is drawn at: its block's screen is the target's.
    let k = scale(own, g);
    g.frame.screen = float4 { size.x * k, size.y * k, g.frame.screen.z, 0.0 };
    let f = frame_addr(own, g);
    let clear = if backdrop { float4 { 0.11, 0.078, 0.063, 1.0 } } else { float4_0 };
    var pass = nx::PassDesc { depth: g.depth, color_value: clear };
    pass.color[0] = if g.aa != AA_OFF { g.color } else { target };
    if g.aa == AA_MSAA { pass.resolve[0] = target; }
    nx::begin_pass(pass);
    if render3d::outside_shown(g) { draw_outside(own, g, f); }
    else if backdrop { draw_backdrop(own, g, f, 1.0); }

    nx::bind(g.lit);
    draw_meshes(own, g, f, 0.0);
    // The fading pieces, each alone at its opacity, over what stands behind them.
    if g.solid < g.instance_count {
        nx::bind(g.fading);
        for i in g.solid..g.instance_count {
            var r = lit_root(own, g, f, g.piece_vb);
            r.u = blocks([float4 { 1.0, 0.0, g.alphas[i - g.solid], i }]);
            nx::draw_indexed(ngfx::root(r), g.piece_ib, 4, g.piece_count);
        }
    }

    // The table under the board, after it, so what the board covers fails the depth test.
    if render3d::table_shown(g) {
        nx::bind(if render3d::table_in_room(g) { g.table_room } else { g.table_lit });
        var t = no_root();
        t.frame = f;
        let tb: render3d::TableBlock[1] = [render3d::table_block(g)];
        t.u = ngfx::frame_data(bytes_of(tb));
        t.verts = nx::address(g.table_vb);
        slot(t, 0, g.table_albedo, g.aniso);
        slot(t, 1, g.table_normal, g.aniso);
        slot(t, 2, g.frame_albedo, g.aniso);
        slot(t, 3, g.table_wear, g.aniso);
        slot(t, 4, g.table_wear_n, g.aniso);
        slot(t, 5, render3d::tree_or_stand_in(g), g.linear);
        slot(t, 6, g.shadow_map, g.compare);
        slot(t, 7, render3d::table_map_or_stand_in(g), g.compare);
        if render3d::table_in_room(g) { slot(t, 8, render3d::ssao_or_stand_in(g), g.linear); }
        nx::draw_indexed(ngfx::root(t), g.table_ib, 4, g.table_count);
    }

    // The room round the table, behind what stands in it.
    if render3d::room_shown(g) {
        nx::bind(g.room_lit);
        var t = no_root();
        t.frame = f;
        let rb: render3d::SurfacesBlock[1] = [render3d::surfaces_block(g)];
        t.u = ngfx::frame_data(bytes_of(rb));
        t.verts = nx::address(g.room_vb);
        slot(t, 0, g.floor_albedo, g.aniso);
        slot(t, 1, g.floor_normal, g.aniso);
        slot(t, 2, g.wall_albedo, g.aniso);
        slot(t, 3, g.wall_normal, g.aniso);
        slot(t, 4, render3d::tree_or_stand_in(g), g.linear);
        slot(t, 5, g.paper_mask, g.aniso);
        slot(t, 6, g.plaster_tone, g.aniso);
        slot(t, 7, g.lace_mask, g.aniso);
        slot(t, 8, render3d::light_or_stand_in(g), g.linear);
        slot(t, 9, g.book_atlas, g.aniso);
        slot(t, 10, render3d::table_map_or_stand_in(g), g.compare);
        slot(t, 11, render3d::ssao_or_stand_in(g), g.linear);
        nx::draw_indexed(ngfx::root(t), g.room_ib, 4, g.room_count);
        // The shell's glass and lace over what stands behind them.
        if g.glass_count > 0 {
            nx::bind(g.room_glass);
            t.verts = nx::address(g.glass_vb);
            nx::draw_indexed(ngfx::root(t), g.glass_ib, 4, g.glass_count);
        }
    }

    // The board's soft shadow round it, after the board so the depth test leaves out
    // what the board covers; the table casts its own.
    if !render3d::table_shown(g) {
        nx::bind(g.catcher);
        var c = no_root();
        c.frame = f;
        c.u = blocks([float4_0]);
        ngfx::draw(ngfx::root(c), 6);
    }

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
    if render3d::motes_shown(g) { draw_motes(own, g, f); }
    ngfx::end_pass();
    barrier_between_passes();
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    antialias(own, g, target, size);
}

// The dust's pipeline and seeds (render3d::Dust), made the first time they are wanted,
// before any pass.
fn make_motes(own: Own&, g: Gpu&) {
    guard g.motes.id == 0 else { return; }
    let seeds = render3d::mote_seeds();
    g.mote_seeds = nx::buffer(bytes_of(seeds));
    g.motes = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_dust.blob"),
                           ngfx::PipelineDesc { depth_test: true, blend: ngfx::BLEND_ADD });
}

// The room's pipeline and its bake's (render3d::room_surfaces), made the first time they
// are wanted, before any pass.
fn make_room(own: Own&, g: Gpu&) {
    guard g.room_lit.id == 0 else { return; }
    g.room_lit = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_room.blob"),
                              ngfx::PipelineDesc { depth_test: true, depth_write: true });
    g.room_glass = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_room.blob"),
                                ngfx::PipelineDesc { depth_test: true, blend: ngfx::BLEND_PREMULTIPLIED });
    g.bake_room = module(embed_file("../../build/ngfx/blobs/r3d_bake_room.blob"));
    g.table_room = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_table_room.blob"),
                                ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true,
                                                     blend: ngfx::BLEND_PREMULTIPLIED });
    g.outside = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_outside.blob"),
                             ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED });
    g.bloom_pick = module(embed_file("../../build/ngfx/blobs/r3d_glow_pick.blob"));
    g.bloom_blur = module(embed_file("../../build/ngfx/blobs/r3d_glow_blur.blob"));
    g.bloom_add = module(embed_file("../../build/ngfx/blobs/r3d_glow_add.blob"));
    let solid = ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true };
    g.pre_room = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_pre_room.blob"),
                              ngfx::PipelineDesc { depth_test: true, depth_write: true });
    g.pre_table = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_pre_table.blob"), solid);
    g.pre_lit = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_pre_lit.blob"), solid);
    g.ssao = module(embed_file("../../build/ngfx/blobs/r3d_ssao.blob"));
    g.ssao_blur = module(embed_file("../../build/ngfx/blobs/r3d_ssao_blur.blob"));
}

// The room's ambient occlusion (render3d::ssao_shown), before the board's pass: the room,
// the table and the board at half size into where each pixel is and which way it faces,
// then its occlusion, then that blurred into g.ssao_map, which the room and the table read;
// the modules' headers: the prepass's the frame and the vertices (the board's lit_root's),
// r3d_ssao's the two targets and its block, r3d_ssao_blur's the occlusion.
fn ssao_pass(own: Own&, g: Gpu&, size: int2) {
    let q = render3d::ssao_size_of(size);
    if g.ssao_map.id == 0 || g.ssao_size.x != q.x || g.ssao_size.y != q.y {
        if g.ssao_map.id != 0 {
            for t in [g.pre_place, g.pre_facing, g.pre_depth, g.ssao_raw, g.ssao_map] { nx::release(t); }
            ngfx::flush();
        }
        g.pre_place = nx::render_target(q.x, q.y, ngfx::RGBA16F);
        g.pre_facing = nx::render_target(q.x, q.y, ngfx::RGBA8);
        g.pre_depth = nx::texture(ngfx::TextureDesc { format: ngfx::DEPTH16, usage: ngfx::DEPTH_TARGET,
                                                      width: q.x as i32, height: q.y as i32 });
        g.ssao_raw = nx::render_target(q.x, q.y, ngfx::RG16F);
        g.ssao_map = nx::render_target(q.x, q.y, ngfx::RG16F);
        g.ssao_size = q;
    }
    let f = frame_addr(own, g);
    var pass = nx::PassDesc { depth: g.pre_depth, color_value: float4_0 };
    pass.color[0] = g.pre_place;
    pass.color[1] = g.pre_facing;
    nx::begin_pass(pass);
    nx::bind(g.pre_lit);
    draw_meshes(own, g, f, 0.0);
    if render3d::table_shown(g) {
        nx::bind(g.pre_table);
        var t = no_root();
        t.frame = f;
        t.verts = nx::address(g.table_vb);
        nx::draw_indexed(ngfx::root(t), g.table_ib, 4, g.table_count);
    }
    nx::bind(g.pre_room);
    var r = no_root();
    r.frame = f;
    r.verts = nx::address(g.room_vb);
    nx::draw_indexed(ngfx::root(r), g.room_ib, 4, g.room_count);
    if g.glass_count > 0 {
        r.verts = nx::address(g.glass_vb);
        nx::draw_indexed(ngfx::root(r), g.glass_ib, 4, g.glass_count);
    }
    ngfx::end_pass();
    barrier_between_passes();
    nx::begin_pass(g.ssao_raw, nx::Texture { 0 }, float4_0);
    nx::bind(g.ssao);
    var a = no_root();
    slot(a, 0, g.pre_place, g.linear);
    slot(a, 1, g.pre_facing, g.linear);
    let look: render3d::SsaoBlock[1] = [render3d::ssao_pass_of(g, q)];
    a.u = ngfx::frame_data(bytes_of(look));
    ngfx::draw(ngfx::root(a), 3);
    ngfx::end_pass();
    barrier_between_passes();
    nx::begin_pass(g.ssao_map, nx::Texture { 0 }, float4_0);
    nx::bind(g.ssao_blur);
    var b = no_root();
    slot(b, 0, g.ssao_raw, g.linear);
    ngfx::draw(ngfx::root(b), 3);
    ngfx::end_pass();
    barrier_between_passes();
}

// The window's glow (render3d::bloom_shown): what is bright in `image` picked into a quarter
// of its size, blurred across and down, and added back over it into `target`; the modules'
// headers: the source (and the glow), their one block.
fn bloom_pass(own: Own&, g: Gpu&, image: Texture, target: Texture, size: int2) {
    let q = render3d::bloom_size_of(size);
    if g.bloom_a.id == 0 || g.bloom_size.x != q.x || g.bloom_size.y != q.y {
        if g.bloom_a.id != 0 { gpu_release_waited(own, g.bloom_a, g.bloom_b); }
        g.bloom_a = nx::render_target(q.x, q.y, ngfx::RGBA16F);
        g.bloom_b = nx::render_target(q.x, q.y, ngfx::RGBA16F);
        g.bloom_size = q;
    }
    nx::begin_pass(g.bloom_a, nx::Texture { 0 }, float4_0);
    nx::bind(g.bloom_pick);
    var r = no_root();
    slot(r, 0, image, g.linear);
    let pick: render3d::GlowPick[1] = [render3d::bloom_pick_of(g, size)];
    r.u = ngfx::frame_data(bytes_of(pick));
    ngfx::draw(ngfx::root(r), 3);
    ngfx::end_pass();
    barrier_between_passes();
    for k in 2 {
        let from = if k == 0 { g.bloom_a } else { g.bloom_b };
        let to = if k == 0 { g.bloom_b } else { g.bloom_a };
        nx::begin_pass(to, nx::Texture { 0 }, float4_0);
        nx::bind(g.bloom_blur);
        var b = no_root();
        slot(b, 0, from, g.linear);
        let blur: render3d::GlowBlur[1] = [render3d::bloom_blur_of(g, q, k == 0)];
        b.u = ngfx::frame_data(bytes_of(blur));
        ngfx::draw(ngfx::root(b), 3);
        ngfx::end_pass();
        barrier_between_passes();
    }
    var pass = nx::PassDesc { clear_color: false };
    pass.color[0] = target;
    nx::begin_pass(pass);
    nx::bind(g.bloom_add);
    var a = no_root();
    slot(a, 0, image, g.linear);
    slot(a, 1, g.bloom_a, g.linear);
    let add: render3d::GlowAdd[1] = [render3d::bloom_add_of(g, size)];
    a.u = ngfx::frame_data(bytes_of(add));
    ngfx::draw(ngfx::root(a), 3);
    ngfx::end_pass();
    barrier_between_passes();
}

// The view out of the shell's windows (model3d::view_out), first in the pass in place of
// the photograph: one draw, the sky, then the band, then the oak, each over the last;
// r3d_outside.slang's header: Outside, the band, the oak.
fn draw_outside(own: Own&, g: Gpu&, f: u64) {
    nx::bind(g.outside);
    var t = no_root();
    t.frame = f;
    let b: render3d::OutsideBlock[1] = [render3d::outside_block(g)];
    t.u = ngfx::frame_data(bytes_of(b));
    t.verts = nx::address(g.outside_vb);
    slot(t, 0, g.outside_band, g.linear);
    slot(t, 1, g.outside_oak, g.linear);
    nx::draw_indexed(ngfx::root(t), g.outside_ib, 4, g.outside_count);
}

// The dust in the sunbeam over the open pass's target, added, hidden by what stands
// in front of it; r3d_dust.slang's header: Dust, the seeds, the tree's map.
fn draw_motes(own: Own&, g: Gpu&, f: u64) {
    nx::bind(g.motes);
    var r = no_root();
    r.frame = f;
    let b: render3d::DustBlock[1] = [render3d::dust_block()];
    r.u = ngfx::frame_data(bytes_of(b));
    r.buf0 = nx::address(g.mote_seeds);
    slot(r, 0, render3d::tree_or_stand_in(g), g.linear);
    ngfx::draw_instanced(ngfx::root(r), 6, render3d::motes_drawn());
}

// The occlusion map's texels x0..x1, y0..y1 drawn again from the field's squares.
fn occ_pass(own: Own&, g: Gpu&, x0: i64, y0: i64, x1: i64, y1: i64) {
    var pass = nx::PassDesc { clear_color: false };
    pass.color[0] = g.occ_map;
    nx::begin_pass(pass);
    ngfx::scissor(x0, y0, x1 - x0, y1 - y0);
    nx::bind(g.occ);
    var r = no_root();
    r.frame = frame_addr(own, g);
    r.buf0 = nx::address(g.squares);
    ngfx::draw(ngfx::root(r), 3);
    ngfx::end_pass();
    barrier_between_passes();
}

// The backdrop at full opacity into the kept one.
fn kept_pass(own: Own&, g: Gpu&) {
    var pass = nx::PassDesc { clear_color: false };
    pass.color[0] = g.kept_backdrop;
    nx::begin_pass(pass);
    draw_backdrop(own, g, frame_addr(own, g), 1.0);
    ngfx::end_pass();
    barrier_between_passes();
}

let mat_identity = Mat { c0: float4 { 1.0, 0.0, 0.0, 0.0 }, c1: float4 { 0.0, 1.0, 0.0, 0.0 },
                         c2: float4 { 0.0, 0.0, 1.0, 0.0 }, c3: float4 { 0.0, 0.0, 0.0, 1.0 } };

fn mul(m: Mat, v: float4) -> float4 { m.c0 * v.x + m.c1 * v.y + m.c2 * v.z + m.c3 * v.w }

// Every module's root (src/ngfx/shaders/r3d.slang): the frame's block and the uniform
// blocks' float4s in this frame's memory, the storage buffers, the vertices, and the
// textures with their samplers in the slots each module's header lists.
struct Root { frame: u64, u: u64, buf0: u64, buf1: u64, buf2: u64, verts: u64, tex: u32[12], smp: u32[12] }

fn no_root() -> Root { Root { frame: 0, u: 0, buf0: 0, buf1: 0, buf2: 0, verts: 0, tex: [0; 12], smp: [0; 12] } }

// How the 3D pass is antialiased: not at all; SMAA 1x over the pass drawn at 1x; the
// pass drawn at twice the size and shrunk (2 x 2 supersampling); or 4× multisampled into
// transient targets, resolved as the pass ends.
let AA_OFF = 0;

let AA_SMAA = 2;

let AA_SSAA = 3;

let AA_MSAA = 4;

// The default, as gfx's: its targets memoryless, cheaper than SMAA in time and memory.
let AA = AA_MSAA;

let SAMPLES = 4;

// The pass's ways by the names --aa takes and the log prints (-1 for none), and the next
// the A key switches to: MSAA, SMAA, none, and 2 × 2 supersampling in turn.
fn aa_named(own: Own&, name: const u8[:]) -> i32 {
    if name == "off" { return AA_OFF; }
    if name == "msaa" { return AA_MSAA; }
    if name == "smaa" { return AA_SMAA; }
    if name == "ssaa" { return AA_SSAA; }
    return -1;
}

fn aa_name(own: Own&, aa: i32) -> const u8[:] {
    if aa == AA_MSAA { "msaa" } else if aa == AA_SMAA { "smaa" } else if aa == AA_SSAA { "ssaa" } else { "off" }
}

fn aa_next(own: Own&, aa: i32) -> i32 {
    if aa == AA_MSAA { AA_SMAA } else if aa == AA_SMAA { AA_OFF } else if aa == AA_OFF { AA_SSAA } else { AA_MSAA }
}

// A target of the pass: 4× and transient (cleared, never stored, and on Metal kept in
// tile memory alone) with AA_MSAA, else one sample, `usage` alone.
fn pass_target(own: Own&, g: Gpu&, w: i64, h: i64, format: i32, usage: i32) -> nx::Texture {
    let msaa = g.aa == AA_MSAA;
    return nx::texture(ngfx::TextureDesc { format: format, usage: if msaa { usage | ngfx::TRANSIENT } else { usage },
                                             width: w as i32, height: h as i32, samples: if msaa { SAMPLES } else { 1 } });
}

// What a pass wrote, before what comes after reads or writes it again: between passes,
// as ngfx wants, where SDL_GPU orders passes itself.
fn barrier_between_passes() {
    ngfx::barrier(ngfx::TARGET_WRITE | ngfx::FRAGMENT_READ, ngfx::TARGET_WRITE | ngfx::FRAGMENT_READ);
}

// The frame's block as it is now, in this frame's memory, for a root.
fn frame_addr(own: Own&, g: Gpu&) -> u64 {
    let one: render3d::Frame[1] = [g.frame];
    return ngfx::frame_data(bytes_of(one));
}

// The lit module with its shadow filtered as `look` says (render3d::SHADOW_9..): in 4
// taps (r3d_lit_few, shaders::SHADOW_FEW), 16 (r3d_lit_many, shaders::SHADOW_MANY), or 9;
// and the pieces in one material (render3d::PIECES_..: _wood, _winter, _mineral).
fn lit_blob(look: i32, pieces: i32) -> const u8[:] {
    if look == render3d::SHADOW_4 {
        if pieces == render3d::PIECES_WOOD { return embed_file("../../build/ngfx/blobs/r3d_lit_few_wood.blob"); }
        if pieces == render3d::PIECES_WINTER { return embed_file("../../build/ngfx/blobs/r3d_lit_few_winter.blob"); }
        if pieces == render3d::PIECES_MINERAL { return embed_file("../../build/ngfx/blobs/r3d_lit_few_mineral.blob"); }
        return embed_file("../../build/ngfx/blobs/r3d_lit_few.blob");
    }
    if look == render3d::SHADOW_16 {
        if pieces == render3d::PIECES_WOOD { return embed_file("../../build/ngfx/blobs/r3d_lit_many_wood.blob"); }
        if pieces == render3d::PIECES_WINTER { return embed_file("../../build/ngfx/blobs/r3d_lit_many_winter.blob"); }
        if pieces == render3d::PIECES_MINERAL { return embed_file("../../build/ngfx/blobs/r3d_lit_many_mineral.blob"); }
        return embed_file("../../build/ngfx/blobs/r3d_lit_many.blob");
    }
    if pieces == render3d::PIECES_WOOD { return embed_file("../../build/ngfx/blobs/r3d_lit_wood.blob"); }
    if pieces == render3d::PIECES_WINTER { return embed_file("../../build/ngfx/blobs/r3d_lit_winter.blob"); }
    if pieces == render3d::PIECES_MINERAL { return embed_file("../../build/ngfx/blobs/r3d_lit_mineral.blob"); }
    return embed_file("../../build/ngfx/blobs/r3d_lit.blob");
}

// The table's module with its shadow filtered as `look` says, as the lit one's (lit_blob).
fn table_blob(look: i32) -> const u8[:] {
    if look == render3d::SHADOW_4 { return embed_file("../../build/ngfx/blobs/r3d_table_few.blob"); }
    if look == render3d::SHADOW_16 { return embed_file("../../build/ngfx/blobs/r3d_table_many.blob"); }
    return embed_file("../../build/ngfx/blobs/r3d_table.blob");
}

// The table's pipeline, its shadow filtered as `look` says (table_blob).
fn table_pipeline(own: Own&, g: Gpu&, look: i32) {
    g.table_lit = nx::pipeline(table_blob(look), ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true,
                                                                       blend: ngfx::BLEND_PREMULTIPLIED });
}

// The lit pass's pipelines, the board's and a fading piece's (lit_blob).
fn lit_pipelines(own: Own&, g: Gpu&, look: i32) {
    let lit = lit_blob(look, g.pieces);
    g.lit = nx::pipeline(lit, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true });
    g.fading = nx::pipeline(lit, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, blend: ngfx::BLEND_ALPHA });
    g.shadow_look = look;
}

// The shadow filtered as `look` says from the next draw on: the lit and table pipelines
// made again if it changes (render3d_gpu.goose's set_shadow).
fn set_shadow(own: Own&, g: Gpu&, look: i32) {
    guard g.lit.id != 0 && look != g.shadow_look else { return; }
    ngfx::flush();
    nx::release(g.lit);
    nx::release(g.fading);
    nx::release(g.table_lit);
    lit_pipelines(own, g, look);
    table_pipeline(own, g, look);
}

// The pieces' material from the next draw on (render3d_gpu.goose's set_pieces).
fn set_pieces(own: Own&, g: Gpu&, pieces: i32) {
    guard pieces != g.pieces else { return; }
    g.pieces = pieces;
    guard g.lit.id != 0 else { return; }
    ngfx::flush();
    nx::release(g.lit);
    nx::release(g.fading);
    lit_pipelines(own, g, g.shadow_look);
    g.pieces_unwarmed = true;
}

// The bake's pipeline for a surface (render3d::bake_kind), made the first time it is wanted.
fn bake_pipeline(g: Gpu&, mode: f32) -> Pipeline {
    let kind = render3d::bake_kind(g, mode);
    if kind == render3d::BAKE_ROOM { return g.bake_room; }
    if kind == render3d::BAKE_TABLE {
        if g.bake_table.id == 0 { g.bake_table = module(embed_file("../../build/ngfx/blobs/r3d_bake_table.blob")); }
        return g.bake_table;
    }
    if kind == render3d::BAKE_SLAB {
        if g.bake_slab.id == 0 { g.bake_slab = module(embed_file("../../build/ngfx/blobs/r3d_bake_slab.blob")); }
        return g.bake_slab;
    }
    return g.bake;
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
fn photo_part(own: Own&, g: Gpu&, kind: i64, grey: f32, sh: float4[9]&, k: i64) {
    g.photo_gen++;
    let s: f32 = 1.0 / render3d::PHOTO_SIZE;
    if k == 0 && g.plain {
        // The plain background: nothing to decode or blur, the ambient from the fade.
        g.no_photo = true;
        sh = model3d::fade_harmonics(g.fade, grey);
        return;
    }
    if k == 0 {
        let sharp = photo(own, kind, 2048);
        g.no_photo = sharp.id == 0;
        if g.no_photo {
            // No photograph built in: the page under the scene, and a dim ambient.
            nx::begin_pass(g.photo, nx::Texture { 0 }, float4 { 0.11, 0.078, 0.063, 1.0 });
            ngfx::end_pass();
            barrier_between_passes();
            for i in 9 { sh[i] = float4_0; }
            sh[0] = model3d::no_photo_ambient();
            return;
        }
        nx::begin_pass(g.small, nx::Texture { 0 }, float4_0);
        nx::bind(g.shrink);
        var r = no_root();
        slot(r, 0, sharp, g.linear);
        r.u = blocks([float4 { 0.0, 0.0, 1.0, 1.0 }, float4 { 0.0, 0.0, render3d::PHOTO_SIZE, render3d::PHOTO_SIZE }]);
        ngfx::draw(ngfx::root(r), 3);
        ngfx::end_pass();
        barrier_between_passes();
        // Given back once the GPU is done with it.
        ngfx::flush();
        nx::release(sharp);
        return;
    }
    guard !g.no_photo else { return; }
    if k == 1 {
        blur(own, g, g.small, g.across, float4 { s, 0.0, 5.6, s });
        return;
    }
    blur(own, g, g.across, g.photo, float4 { 0.0, s, 5.6, s });
    let px = nx::read_pixels(g.photo);
    sh = model3d::harmonics(px, render3d::PHOTO_SIZE, grey);
}

fn blur(own: Own&, g: Gpu&, from: nx::Texture, to: nx::Texture, dir: float4) {
    nx::begin_pass(to, nx::Texture { 0 }, float4_0);
    nx::bind(g.blur);
    var r = no_root();
    slot(r, 0, from, g.linear);
    r.u = blocks([dir]);
    ngfx::draw(ngfx::root(r), 3);
    ngfx::end_pass();
    barrier_between_passes();
}

// Bakes one surface of the theme into its albedo-and-roughness and normal targets, and
// their mips. Bake.mode: x the surface (0 the plan, 1 the frame map), y the wood's model,
// z the squares per side, w the marble (a stone frame's only).
fn bake(own: Own&, g: Gpu&, albedo: nx::Texture, normal: nx::Texture, w: i64, h: i64, mode: f32,
        extent: float2, t: looks::Theme&, y0: i64 = 0, y1: i64 = -1, mips: bool = true, fine: i64 = 0) {
    // Not cleared: the bake writes every texel. Only rows y0 to y1 when given
    // (theme_step's bands), the mips after the last.
    let pipeline = bake_pipeline(g, mode);   // made before the pass: never inside one
    var pass = nx::PassDesc { clear_color: false };
    pass.color[0] = albedo;
    pass.color[1] = normal;
    nx::begin_pass(pass);
    if y1 >= 0 { ngfx::scissor(0, y0, w, y1 - y0); }
    nx::bind(pipeline);
    let fi = g.finish;
    // Samples a side a texel: a phone's half-size surface sampled as the full one, averaged.
    let fine = if fine > 0 { fine } else { model3d::BAKE_SIDE / w };
    let m = render3d::stone_of(g);
    let u: render3d::Bake[1] = [render3d::Bake { float4 { mode, g.wood, g.n, render3d::marble_of(g) },
                                           float4 { w * fine, h * fine, extent.x, extent.y },
                                           t.light_sq, t.light_fig, t.dark_sq, t.dark_fig,
                                           t.inlay, t.inlay_fig, t.frame, t.frame_fig,
                                           t.surface, t.frame_surface, t.stone,
                                           t.light_ring, t.dark_ring, t.frame_ring,
                                           float4 { fi.varnish, fi.sanding, fi.grain, fi.rings },
                                           float4 { fi.warmth, fi.pickle, fi.caulk, fine },
                                           float4 { m.veins, m.wave, m.polish, m.tint },
                                           m.base, m.vein, m.form, t.seam,
                                           float4 { g.carving.depth, g.carving.scale, g.carving.moss, t.build.w },
                                           looks::MOSS,
                                           float4 { g.carving.motif, g.carving.amber, g.carving.lichen, g.carving.pattern },
                                           t.fill, looks::LICHEN }];
    var r = no_root();
    r.u = ngfx::frame_data(bytes_of(u));
    ngfx::draw(ngfx::root(r), 3);
    ngfx::end_pass();
    barrier_between_passes();
    guard mips else { return; }
    mip_chain(own, g, albedo);
    mip_chain(own, g, normal);
}

// The texture's mips from its first level, a pass a level (shaders/mip.slang): an sRGB
// one averaged in linear light, which ngfx's generate_mips can't write.
fn mip_chain(own: Own&, g: Gpu&, t: nx::Texture) {
    let levels = nx::texture_info(t).mips as i64;
    for level in 1..levels {
        var pass = nx::PassDesc { mip: level as i32, clear_color: false };
        pass.color[0] = t;
        nx::begin_pass(pass);
        nx::bind(own.mip);
        ngfx::draw(ngfx::root(MipRoot { src: nx::index(t), level: (level - 1) as u32, pad0: 0, pad1: 0 }), 3);
        ngfx::end_pass();
        barrier_between_passes();
    }
}

struct MipRoot { src: u32, level: u32, pad0: u32, pad1: u32 }

// The pass's target (at twice the size for AA_SSAA, 4× for AA_MSAA) and its depth, and
// SMAA's, at g.size, made for a draw after release_targets() gave them back.
fn pass_targets(own: Own&, g: Gpu&) {
    guard g.depth.id == 0 else { return; }
    let size = g.size;
    let k = scale(own, g);
    if g.aa == AA_MSAA {
        g.color = pass_target(own, g, size.x, size.y, ngfx::RGBA8, ngfx::COLOR_TARGET);
    } else if g.aa != AA_OFF {
        g.color = nx::render_target(size.x * k, size.y * k, ngfx::RGBA8);
    }
    if g.aa == AA_SMAA {
        g.edges = nx::render_target(size.x, size.y, ngfx::RG8);
        g.weights = nx::render_target(size.x, size.y, ngfx::RGBA8);
    }
    // 16-bit depth is plenty between NEAR 2 and FAR 40 for a scene 10 to 20 away (a step
    // about 0.003 at 20, under the marks' 0.004 lift).
    g.depth = pass_target(own, g, size.x * k, size.y * k, ngfx::DEPTH16, ngfx::DEPTH_TARGET);
}

// The pass antialiased by `aa` (AA_OFF..) from the next draw on: its targets given back
// (made again for the new way by the next draw), the way's pipelines and tables made the
// first time it is chosen. The app's A key. It draws SAMPLES whatever `samples`
// says: fewer are asked for only on Android, which the ngfx build isn't built for.
fn set_aa(own: Own&, g: Gpu&, aa: i32, samples: i32 = SAMPLES) {
    render3d::give_back(own, g);
    g.aa = aa;
    aa_resources(own, g, aa);
}

// What antialiasing by `aa` draws with, made once.
fn aa_resources(own: Own&, g: Gpu&, aa: i32) {
    if aa == AA_SMAA && g.smaa_edges.id == 0 {
        let smaa = embed_file("../../build/ngfx/blobs/smaa.blob");
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
        nx::update_texture(g.area, embed_file("../../third_party/smaa/area.bin"));
        g.search = nx::texture2d(64, 16, ngfx::R8, ngfx::SAMPLED);
        nx::update_texture(g.search, embed_file("../../third_party/smaa/search.bin"));
    }
}

// How many times the size the pass is drawn at: 2 for AA_SSAA.
fn scale(own: Own&, g: Gpu&) -> i64 { return if g.aa == AA_SSAA { 2 } else { 1 }; }

// The kept depth: 1x, 16-bit as the pass's, sampled by the pulsing marks.
fn depth_target(size: int2) -> nx::Texture {
    return nx::texture2d(size.x, size.y, ngfx::DEPTH16, ngfx::DEPTH_TARGET | ngfx::SAMPLED);
}

// Makes everything the renderer draws with: the meshes, the buffers, the pipelines, the
// baked surfaces' and the photograph's targets. Then apply() puts a theme on it.
// Antialiased as AA says (set_aa changes it), whatever `samples` says, as set_aa; `look`
// how the shadow is filtered (render3d::SHADOW_9..; set_shadow).
fn setup(own: Own&, g: Gpu&, samples: i32 = SAMPLES, look: i32 = render3d::SHADOW_9) {
    let aa: i32 = AA;
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
    g.table_spec = tables::get(tables::BOARD_WOOD);
    g.table_vb = nx::Buffer { 0 };

    var empty:      float4[render3d::SQUARES]        = [float4_0; render3d::SQUARES];
    var none:       float4[render3d::SQUARES]        = [float4 { 0.0, 0.0, 0.0, -1.0 }; render3d::SQUARES];
    var no_squares: float4[render3d::SQUARE_ENTRIES] = [float4_0; render3d::SQUARE_ENTRIES];
    g.instances = nx::buffer(render3d::MAX_INSTANCES * 32, bytes_of(empty[..2]));
    g.instance_count = 0;
    g.squares = nx::buffer(bytes_of(no_squares));
    g.marks = nx::buffer(bytes_of(none));
    g.glows = nx::buffer(bytes_of(empty));

    let blend = ngfx::PipelineDesc { blend: ngfx::BLEND_ALPHA };
    g.bake = module(embed_file("../../build/ngfx/blobs/r3d_bake.blob"));
    g.shrink = module(embed_file("../../build/ngfx/blobs/r3d_shrink.blob"));
    g.blur = module(embed_file("../../build/ngfx/blobs/r3d_blur.blob"));
    g.copy = module(embed_file("../../build/ngfx/blobs/r3d_copy.blob"));
    own.mip = module(embed_file("../../build/ngfx/blobs/mip.blob"));
    own.down = module(embed_file("../../build/ngfx/blobs/down.blob"));
    aa_resources(own, g, aa);
    g.show = module(embed_file("../../build/ngfx/blobs/r3d_show.blob"), ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED });
    g.side = 0;         // the plan and the frame map made by apply(), at its side and as the look's frame wants
    g.frame_rows = 0;
    g.photo = nx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, ngfx::RGBA8);
    g.small = nx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, ngfx::RGBA8);
    g.across = nx::render_target(render3d::PHOTO_SIZE, render3d::PHOTO_SIZE, ngfx::RGBA8);

    g.shadow_map = nx::texture2d(render3d::SHADOW_SIZE, render3d::SHADOW_SIZE, ngfx::DEPTH16, ngfx::DEPTH_TARGET | ngfx::SAMPLED);
    g.occ_map = nx::render_target(render3d::OCC_SIZE, render3d::OCC_SIZE, ngfx::R8);
    g.occ_n = 0;
    g.occ = module(embed_file("../../build/ngfx/blobs/r3d_occ.blob"));
    g.kept = module(embed_file("../../build/ngfx/blobs/r3d_kept.blob"), blend);
    g.linear = nx::sampler(ngfx::LINEAR, ngfx::CLAMP);
    own.point = nx::sampler(ngfx::NEAREST, ngfx::CLAMP);
    g.aniso = nx::sampler(ngfx::SamplerDesc { max_anisotropy: 8.0 });
    g.compare = nx::shadow_sampler();

    let depth = embed_file("../../build/ngfx/blobs/r3d_depth.blob");
    let marks = embed_file("../../build/ngfx/blobs/r3d_marks.blob");
    lit_pipelines(own, g, look);
    table_pipeline(own, g, look);
    g.shadow = nx::pipeline(depth, ngfx::PipelineDesc { depth_test: true, depth_write: true, depth_bias: 1.0,
                                                          depth_bias_slope: 1.5 });
    g.backdrop = module(embed_file("../../build/ngfx/blobs/r3d_backdrop.blob"), blend);
    g.catcher = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_catcher.blob"),
                               ngfx::PipelineDesc { depth_test: true, blend: ngfx::BLEND_ALPHA });
    g.glow = nx::pipeline(marks, ngfx::PipelineDesc { depth_test: true, blend: ngfx::BLEND_PREMULTIPLIED });
    g.pulse = nx::pipeline(embed_file("../../build/ngfx/blobs/r3d_pulse.blob"), ngfx::PipelineDesc { blend: ngfx::BLEND_ADD });
    g.depth_only = nx::pipeline(depth, ngfx::PipelineDesc { cull: ngfx::CULL_BACK, depth_test: true, depth_write: true });
    // The crown's distance, once: a small pipeline made, drawn, and given back.
    g.crown_map = nx::render_target(render3d::CROWN_SIZE, render3d::CROWN_SIZE, ngfx::R16F);
    let crown = module(embed_file("../../build/ngfx/blobs/r3d_crown.blob"));
    nx::begin_pass(g.crown_map, nx::Texture { 0 }, float4_0);
    nx::bind(crown);
    ngfx::draw(ngfx::root(no_root()), 3);
    ngfx::end_pass();
    barrier_between_passes();
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
fn antialias(own: Own&, g: Gpu&, target: nx::Texture, size: int2) {
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
            if i < 2 { barrier_between_passes(); }
        }
    }
    barrier_between_passes();
}

// The lit module's root (r3d_lit.slang's header): the frame, the instances, the vertices,
// and its eight textures.
fn lit_root(own: Own&, g: Gpu&, f: u64, vb: nx::Buffer) -> Root {
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
    slot(r, 7, render3d::tree_or_stand_in(g), g.linear);
    return r;
}

// The board and the opaque pieces' depth at 1x into g.kept_depth, as the pass above drew
// them (the fading pieces write none there either): only the vertices and a 16-bit
// target, no shading.
fn draw_depth(own: Own&, g: Gpu&) {
    if g.kept_depth.id == 0 { g.kept_depth = depth_target(g.size); }
    nx::begin_pass(nx::PassDesc { depth: g.kept_depth });
    nx::bind(g.depth_only);
    draw_meshes(own, g, frame_addr(own, g), 0.0);
    ngfx::end_pass();
    barrier_between_passes();
}

// The pulsing marks (shaders::MARKS_FRAG with PULSE) over the open pass's target of
// `size`, where show() laid the kept image: drawn with it (draw() with keep_depth) into
// its rect `to` (as show()'s, the whole image), as opaque as `alpha`. `pulse` their
// phases (view3d::Scene.pulse), `next` how lit a capture's next stops are (Scene.next),
// `cursor` the keys' cursor's square in the world's grid, or -1 (Scene.cursor).
// The field's marks are the ones place() gave the image.
fn marks_over(own: Own&, g: Gpu&, pulse: float4, next: f32, cursor: f32, to: float4, alpha: f32, size: int2) {
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
    let f = frame_addr(own, g);
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
fn draw_meshes(own: Own&, g: Gpu&, f: u64, light: f32) {
    if g.solid > 0 {
        var r = lit_root(own, g, f, g.piece_vb);
        r.u = blocks([float4 { 1.0, light, 1.0, 0.0 }]);
        nx::draw_indexed_instanced(ngfx::root(r), g.piece_ib, 4, g.piece_count, g.solid);
    }
    var r = lit_root(own, g, f, g.board_vb);
    r.u = blocks([float4 { 0.0, light, 1.0, 0.0 }]);
    nx::draw_indexed(ngfx::root(r), g.board_ib, 4, g.board_count);
}

// The blurred photograph, graded, or the plain fade dimmed as the flat game dims what is
// behind it (draw::frame's 0.8), at opacity `alpha` over the open pass's target; `f` the
// frame's block, its screen the target's size.
fn draw_backdrop(own: Own&, g: Gpu&, f: u64, alpha: f32) {
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
fn backdrop(own: Own&, g: Gpu&, alpha: f32, size: int2) {
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    guard render3d::kept_current(g, size) else {
        draw_backdrop(own, g, frame_addr(own, g), alpha);
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
fn copy(own: Own&, g: Gpu&) {
    nx::bind(g.copy);
    var r = no_root();
    slot(r, 0, g.image, g.linear);
    ngfx::draw(ngfx::root(r), 3);
}

// Draws the kept image (draw() into g.image without the backdrop) over the open pass's
// target of `size`: its rect `from` into the rect `to`, both x, y, width, height in
// pixels, at opacity `alpha`, `grey` of the way to grey and dimmer (shaders::SHOW_FRAG).
// The same rect is the image as drawn, texel for texel.
fn show(own: Own&, g: Gpu&, from: float4, to: float4, alpha: f32, size: int2, grey: f32 = 0.0) {
    nx::bind(g.show);
    var r = no_root();
    r.u = blocks([from, to, float4 { size.x, size.y, alpha, grey }]);
    slot(r, 0, g.image, g.linear);
    ngfx::draw(ngfx::root(r), 6);
}

fn warm(own: Own&, g: Gpu&, k: i64) {
    if k == 0 {
        // The pass's pipelines for its targets (4× with AA_MSAA), the depth-only ones for
        // a kept depth's 1x.
        g.warm_color = pass_target(own, g, 4, 4, ngfx::RGBA8, ngfx::COLOR_TARGET);
        g.warm_depth = pass_target(own, g, 4, 4, ngfx::DEPTH16, ngfx::DEPTH_TARGET);
        own.warm_kept = depth_target(int2 { 4, 4 });
    }
    var pass = nx::PassDesc {};
    if k < 4 || k == render3d::WARM_STEPS - 1 {
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
             g.kept, g.table_lit][k];
    // The table's only with a table: turning one on warms them again (draw3d).
    if k != render3d::WARM_STEPS - 1 || g.table { nx::prepare(p, pass); }
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
fn release(own: Own&, g: Gpu&) {
    ngfx::flush();
    let textures = [g.plan_albedo, g.plan_normal, g.frame_albedo, g.frame_normal, g.table_albedo, g.table_normal, g.table_wear, g.table_wear_n, g.photo, g.shadow_map, g.occ_map,
                    g.crown_map, g.tree_map, g.color, g.depth, g.image, g.kept_backdrop, g.kept_depth, g.small, g.across,
                    g.warm_color, g.warm_depth, own.warm_kept, g.edges, g.weights, g.area, g.search, g.floor_albedo,
                    g.floor_normal, g.wall_albedo, g.wall_normal, g.paper_mask, g.plaster_tone, g.lace_mask,
                    g.outside_band, g.outside_oak, g.light_volume, g.bloom_a, g.bloom_b, g.book_atlas, g.table_map,
                    g.pre_place, g.pre_facing, g.pre_depth, g.ssao_raw, g.ssao_map];
    for t in textures { if t.id != 0 { nx::release(t); } }
    let buffers = [g.board_vb, g.board_ib, g.piece_vb, g.piece_ib, g.table_vb, g.table_ib, g.instances, g.squares, g.marks,
                   g.glows, g.mote_seeds, g.room_vb, g.room_ib, g.glass_vb, g.glass_ib, g.outside_vb, g.outside_ib];
    for b in buffers { if b.id != 0 { nx::release(b); } }
    let samplers = [g.linear, own.point, g.aniso, g.compare];
    for s in samplers { if s.id != 0 { nx::release(s); } }
    let pipelines = [g.lit, g.fading, g.shadow, g.backdrop, g.catcher, g.glow, g.pulse, g.depth_only, g.copy, g.show,
                     g.occ, g.kept, g.bake, g.bake_slab, g.bake_table, g.shrink, g.blur, own.mip, own.down, g.smaa_edges, g.smaa_weights,
                     g.smaa_blend, g.table_lit, g.table_room, g.motes, g.room_lit, g.bake_room, g.room_glass, g.outside, g.bloom_pick,
                     g.bloom_blur, g.bloom_add, g.pre_room, g.pre_table, g.pre_lit, g.ssao, g.ssao_blur];
    for p in pipelines { if p.id != 0 { nx::release(p); } }
    own = default<Own>();
    g = default<Gpu>();
}
