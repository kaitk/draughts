// The 3D board's recording through gfx: its shaders, pipelines, buffers, and passes, one
// forward pass multisampled and resolved, or SMAA after a 1x pass. render3d.goose calls
// these on an Own; src/ngfx/render3d_ngfx.goose is the ngfx build's twin.
namespace render3d;
import std;
import vec;
import math;
import gfx;
import .shaders;
import .smaa;
import .room_fixed;

// The handles render3d.goose holds, the formats it bakes into, and the matrices' math.
type Texture = gfx::Texture;
type Buffer = gfx::Buffer;
type Sampler = gfx::Sampler;
type Pipeline = gfx::Pipeline;
let RGBA8 = gfx::RGBA8;
let RGBA8_SRGB = gfx::RGBA8_SRGB;
let R8 = gfx::R8;
let RG8 = gfx::RG8;
let RGBA16F = gfx::RGBA16F;
fn mul(a: Mat, b: Mat) -> Mat { gfx::mul(a, b) }
fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Mat {
    gfx::ortho(left, right, bottom, top, near, far)
}
fn look_at(eye: float3, target: float3, up: float3) -> Mat { gfx::look_at(eye, target, up) }

// What only gfx's renderer holds, the first parameter of each of its calls: the pass's
// samples (4 multisampled, 1 for SMAA or none), and a 4 × 4 target warm() makes the kept
// image's pipelines on.
struct Own {
    samples:   i32,
    warm_kept: gfx::Texture,
}

// Theme `kind`'s photograph, or 0 when it isn't built in: the ASTC image as stored, or
// the JPEG decoded and scaled down to `decoded` square (src/native/photo.c and
// background.c, which the app and tools/board_shot both compile).
extern fn draughts_photo_id(kind: i64, decoded: i64) -> u32;
fn photo(own: Own&, kind: i64, decoded: i64) -> Texture { Texture { draughts_photo_id(kind, decoded) } }

fn gpu_flush(own: Own&) { gfx::flush(); }
fn gpu_release(own: Own&, t: Texture) { gfx::release(t); }
fn gpu_target(own: Own&, w: i64, h: i64) -> Texture { gfx::render_target(w, h, gfx::RGBA8) }
fn gpu_clear(own: Own&, t: Texture, color: float4) {
    gfx::begin_pass(t, gfx::Texture { 0 }, color);
    gfx::end_pass();
}
// Releases two textures the GPU may still be reading, and waits for it, so the next
// made take their place.
fn gpu_release_waited(own: Own&, a: Texture, b: Texture) {
    gfx::release(a);
    gfx::release(b);
    gfx::flush();
}
fn gpu_update(own: Own&, b: Buffer, bytes: const u8[:]) { gfx::update_buffer(b, bytes); }
fn gpu_mesh(own: Own&, verts: const u8[:], indices: const u8[:]) -> Buffer, Buffer {
    return gfx::vertex_buffer(verts), gfx::index_buffer(indices);
}
fn gpu_storage(own: Own&, bytes: const u8[:]) -> Buffer { gfx::buffer(gfx::BUFFER_STORAGE, bytes) }
fn gpu_release_storage(own: Own&, b: Buffer) {
    gfx::flush();
    gfx::release(b);
}
fn gpu_release_mesh(own: Own&, vb: Buffer, ib: Buffer) {
    gfx::release(vb);
    gfx::release(ib);
}
fn gpu_mipped(own: Own&, w: i64, h: i64, format: i32, mips: i64) -> Texture {
    return gfx::texture(gfx::TextureDesc { format: format, usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                           width: w as i32, height: h as i32, mips: mips as i32 });
}
// A texture only sampled, of `format` with `mips` levels, filled by gpu_upload.
fn gpu_sampled(own: Own&, w: i64, h: i64, mips: i64, format: i32) -> Texture {
    return gfx::texture(gfx::TextureDesc { format: format, usage: gfx::SAMPLED, width: w as i32, height: h as i32,
                                           mips: mips as i32 });
}
fn gpu_upload(own: Own&, t: Texture, mip: i64, bytes: const u8[:]) { gfx::update_texture(t, gfx::Region { mip: mip as i32 }, bytes); }

// The photograph's pipelines made, in a pass that draws nothing (theme_step): goose_gfx
// makes a pipeline when it is first bound in a pass.
fn photo_pipelines(own: Own&, g: render3d::Gpu&) {
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = g.small;
    gfx::begin_pass(pass);
    gfx::bind(g.shrink);
    gfx::bind(g.blur);
    gfx::end_pass();
}

fn shadow_pass(own: Own&, g: render3d::Gpu&) {
    let f = g.frame;
    var sp = gfx::PassDesc { depth: g.shadow_map };
    gfx::begin_pass(sp);
    gfx::bind(g.shadow);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::uniforms(gfx::VERTEX, 0, f);
    draw_meshes(own, g, 1.0);
    gfx::end_pass();
}

// The table's top and base, and the chairs, into its own map (render3d::table_map), seen along the key
// through `place`: the key's pipeline, the board's frame with its light's projection
// replaced, made the first time.
fn table_map_pass(own: Own&, g: render3d::Gpu&, place: render3d::Mat) {
    if g.table_map.id == 0 {
        g.table_map = gfx::texture2d(render3d::TABLE_MAP_W, render3d::TABLE_MAP_H, gfx::DEPTH16,
                                     gfx::DEPTH_TARGET | gfx::SAMPLED);
    }
    var f = g.frame;
    f.light_view_proj = place;
    gfx::begin_pass(gfx::PassDesc { depth: g.table_map });
    gfx::bind(g.shadow);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 0.0, 1.0, 1.0, 0.0 } });
    gfx::bind_vertex_buffer(g.table_vb);
    gfx::bind_index_buffer(g.table_ib, 4);
    gfx::draw_indexed(g.table_count);
    gfx::end_pass();
}

// draw()'s one pass into `target` of `size`, with the `backdrop` or clear, multisampled
// and resolved into it, or SMAA after it.
fn board_pass(own: Own&, g: render3d::Gpu&, target: Texture, size: int2, backdrop: bool, outside: bool, table_covers: bool) {
    let f = g.frame;
    let clear = if backdrop { float4 { 0.11, 0.078, 0.063, 1.0 } } else { float4_0 };
    var pass = gfx::PassDesc { depth: g.depth, color_value: clear };
    if g.aa == AA_MSAA {
        pass.color[0] = g.color;
        pass.resolve[0] = target;
    } else if g.aa == AA_SMAA {
        // With HDR the pass draws into the HDR image at 1x, and SMAA runs after the
        // tonemap, on the 8-bit picture it is made for (tone_pass).
        pass.color[0] = if g.hdr { target } else { g.color };
    } else {
        pass.color[0] = target;
    }
    gfx::begin_pass(pass);
    // The opaque tabletop covers the backdrop at every sample in this view.
    if !table_covers {
        if outside {
            draw_outside(own, g);
            if render3d::tree_card_in_view(g) { draw_tree_card(own, g); }
        } else if backdrop {
            draw_backdrop(own, g, 1.0);
        }
    }

    let h .= g.hdr_pipes;
    let in_shell = render3d::board_in_shell(g);
    gfx::bind(if g.hdr { h.lit } else if in_shell { g.lit_shell } else { g.lit });
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.plan_albedo, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.plan_normal, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 2, g.frame_albedo, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 3, g.frame_normal, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 4, g.shadow_map, g.compare);
    gfx::bind_texture(gfx::FRAGMENT, 5, g.occ_map, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 6, g.crown_map, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 7, render3d::tree_or_stand_in(g), g.linear);
    if g.hdr || in_shell {
        gfx::bind_texture(gfx::FRAGMENT, 8, render3d::lace_or_stand_in(g), g.linear);
        gfx::uniforms(gfx::FRAGMENT, 1, render3d::shell_block(g));
    }
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    draw_meshes(own, g, 0.0);
    // The fading pieces, each alone at its opacity, over what stands behind them.
    if g.solid < g.instance_count {
        gfx::bind(if g.hdr { h.fading } else if in_shell { g.fading_shell } else { g.fading });
        gfx::bind_vertex_buffer(g.piece_vb);
        gfx::bind_index_buffer(g.piece_ib, 4);
        for i in g.solid..g.instance_count {
            gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 1.0, 0.0, g.alphas[i - g.solid], i } });
            gfx::draw_indexed(g.piece_count);
        }
    }

    // The table under the board, after it, so what the board covers fails the depth test.
    if render3d::table_shown(g) {
        gfx::bind(if g.hdr { h.table } else if render3d::table_in_room(g) { g.table_room } else { g.table_lit });
        gfx::bind_texture(gfx::FRAGMENT, 0, g.table_albedo, g.aniso);
        gfx::bind_texture(gfx::FRAGMENT, 1, g.table_normal, g.aniso);
        gfx::bind_texture(gfx::FRAGMENT, 2, g.frame_albedo, g.aniso);
        gfx::bind_texture(gfx::FRAGMENT, 3, g.table_wear, g.aniso);
        gfx::bind_texture(gfx::FRAGMENT, 4, g.table_wear_n, g.aniso);
        gfx::bind_texture(gfx::FRAGMENT, 5, render3d::tree_or_stand_in(g), g.linear);
        gfx::bind_texture(gfx::FRAGMENT, 6, g.shadow_map, g.compare);
        gfx::bind_texture(gfx::FRAGMENT, 7, render3d::table_map_or_stand_in(g), g.compare);
        let room_table = g.hdr || render3d::table_in_room(g);
        if room_table { gfx::bind_texture(gfx::FRAGMENT, 8, render3d::tapestry_or_stand_in(g), g.aniso); }
        if room_table && (g.hdr || g.room_ssao) { gfx::bind_texture(gfx::FRAGMENT, 9, render3d::ssao_or_stand_in(g), g.linear); }
        if room_table { gfx::bind_texture(gfx::FRAGMENT, if g.hdr || g.room_ssao { 10 } else { 9 }, render3d::lace_or_stand_in(g), g.linear); }
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 1, render3d::table_block(g));
        if room_table { gfx::uniforms(gfx::FRAGMENT, 2, render3d::shell_block(g)); }
        // The props' light (shaders::PROPS_LIGHT): their bake a vertex, the room's probes.
        if (g.hdr && h.props_light) || (!g.hdr && render3d::table_in_room(g) && g.room_props) {
            gfx::bind_storage_buffer(gfx::VERTEX, 0, g.props_open);
            gfx::bind_texture(gfx::FRAGMENT, 11, render3d::light_or_stand_in(g), g.linear);
            gfx::uniforms(gfx::FRAGMENT, 3, render3d::props_light_block(g));
        }
        gfx::bind_vertex_buffer(g.table_vb);
        gfx::bind_index_buffer(g.table_ib, 4);
        gfx::draw_indexed(g.table_count);
    }

    // The room round the table, behind what stands in it: each material group with its own
    // pipeline, the floor's seeing the mirror where it is drawn.
    if render3d::room_shown(g) {
        let planar = render3d::planar_seen_on_floor(g);
        let ssao = g.room_ssao;
        let surfaces = render3d::surfaces_block(g);
        if g.hdr {
            if render3d::floor_pieces_on(g) { draw_floor_pieces(g, f, surfaces, h, ssao, planar); }
            else { draw_room_group(g, f, surfaces, if planar { h.planar } else { h.floor }, render3d::GROUP_FLOOR, ssao, planar); }
            draw_room_group(g, f, surfaces, h.walls, render3d::GROUP_WALLS, ssao, false);
            draw_room_group(g, f, surfaces, h.sill, render3d::GROUP_SILL, ssao, false);
            draw_room_group(g, f, surfaces, h.paint, render3d::GROUP_PAINT, ssao, false);
            draw_room_group(g, f, surfaces, h.metals, render3d::GROUP_METALS, ssao, false);
            if render3d::tree_drawn(g) { draw_tree(own, g); }
            draw_room_group(g, f, surfaces, h.glass, render3d::GROUP_GLASS, ssao, false);
            draw_room_group(g, f, surfaces, h.lace, render3d::GROUP_LACE, ssao, false);
        } else {
            draw_room_group(g, f, surfaces, if planar { g.room_planar } else { g.room_floor }, render3d::GROUP_FLOOR, ssao, planar);
            draw_room_group(g, f, surfaces, g.room_walls, render3d::GROUP_WALLS, ssao, false);
            draw_room_group(g, f, surfaces, g.room_sill, render3d::GROUP_SILL, ssao, false);
            draw_room_group(g, f, surfaces, g.room_paint, render3d::GROUP_PAINT, ssao, false);
            draw_room_group(g, f, surfaces, g.room_metals, render3d::GROUP_METALS, ssao, false);
            if render3d::tree_drawn(g) { draw_tree(own, g); }
            // The shell's glass and lace over what stands behind them.
            draw_room_group(g, f, surfaces, g.room_glass, render3d::GROUP_GLASS, ssao, false);
            draw_room_group(g, f, surfaces, g.room_lace, render3d::GROUP_LACE, ssao, false);
        }
    }

    // The board's soft shadow round it, after the board so the depth test leaves out
    // what the board covers; the table casts its own.
    if !render3d::table_shown(g) {
        gfx::bind(g.catcher);
        gfx::uniforms(gfx::FRAGMENT, 0, f);
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::uniforms(gfx::VERTEX, 1, Draw { float4_0 });
        gfx::draw(6);
    }

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
    if render3d::motes_shown(g) { draw_motes(own, g); }
    gfx::end_pass();
    if g.aa == AA_SMAA && !g.hdr { antialias(own, g, target); }
}

// Draw a material group from the room or window mesh with pipeline p. The screen's maps
// (ssao) and the floor's mirror (planar) determine its texture bindings
// (render3d::room_textures).
fn draw_room_group(g: render3d::Gpu&, f: render3d::Frame, surfaces: render3d::SurfacesBlock, p: gfx::Pipeline, group: i64,
                   ssao: bool, planar: bool, mirror: bool = false) {
    let window = render3d::window_group(group);
    let first, count = render3d::room_index_range(g, group);
    guard count > 0 else { return; }
    gfx::bind(p);
    let t = render3d::room_textures(g, group, ssao, planar, mirror);
    for i in t.count { gfx::bind_texture(gfx::FRAGMENT, i, t.tex[i], t.smp[i]); }
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 1, surfaces);
    gfx::bind_vertex_buffer(if window { g.window_vb } else { g.room_vb });
    gfx::bind_index_buffer(if window { g.window_ib } else { g.room_ib }, 4);
    gfx::draw_indexed(count, 1, first, 0, 0);
}

// The floor in its pieces (render3d::SunDerived), each kind with its own pipeline: without
// the sun, without the table's map, then the full one.
fn draw_floor_pieces(g: render3d::Gpu&, f: render3d::Frame, surfaces: render3d::SurfacesBlock, h: render3d::HdrPipelines&,
                     ssao: bool, planar: bool) {
    let t = render3d::room_textures(g, render3d::GROUP_FLOOR, ssao, planar);
    for kind in render3d::FLOOR_KINDS {
        let count = g.sun.count[kind];
        guard count > 0 else { continue; }
        let full = if planar { h.planar } else { h.floor };
        gfx::bind(if kind == render3d::FLOOR_TABLE { full } else if planar { h.planar_kinds[kind] } else { h.floor_kinds[kind] });
        for i in t.count { gfx::bind_texture(gfx::FRAGMENT, i, t.tex[i], t.smp[i]); }
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 1, surfaces);
        gfx::bind_vertex_buffer(g.sun.pieces_vb);
        gfx::bind_index_buffer(g.sun.pieces_ib, 4);
        gfx::draw_indexed(count, 1, g.sun.first[kind], 0, 0);
    }
}

// The dust's pipeline and seeds (render3d::Dust), made the first time they are wanted.
fn make_motes(own: Own&, g: render3d::Gpu&) {
    guard g.motes.id == 0 else { return; }
    let seeds = render3d::mote_seeds();
    g.mote_seeds = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(seeds));
    g.motes = gfx::pipeline(embed_shader("vert", shaders::SHELL_WINDOWS, shaders::VS_SET, shaders::FRAME, shaders::DUST_HEAD, shaders::WIND_FN, shaders::LIGHT_FN,
                                         shaders::DUST_VERT),
                            embed_shader("frag", shaders::DUST_FRAG),
                            gfx::PipelineDesc { depth_test: true, blend: gfx::BLEND_ADD });
}

// The room's fragment shader for a group (render3d::room_group, GROUP_GLASS, GROUP_LACE), with the
// screen's maps or without (shaders::NO_SSAO, a phone's tier), with the tuner's views
// (shaders::ROOM_VIEWS, only with the screen's maps), reading the window's light map
// (mapped, render3d::window_map_read: not the lace's or the views'), and on the phone's tier
// with the room's block as constants (fixed, render3d::room_fixed_on).
fn room_frag(group: i64, ssao: bool, views: bool, mapped: bool, fixed: bool, boxed: bool) -> const u8[:] {
    if fixed && !ssao && !views { return room_frag_fixed(group, mapped, boxed); }
    if views {
        if group == render3d::GROUP_FLOOR {
            return embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::ROOM_VIEWS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
        }
        if group == render3d::GROUP_WALLS {
            return embed_shader("frag", shaders::ROOM_WALLS, shaders::ROOM_VIEWS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
        }
        if group == render3d::GROUP_PAINT {
            return embed_shader("frag", shaders::ROOM_PAINT, shaders::ROOM_VIEWS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
        }
        if group == render3d::GROUP_SILL {
            return embed_shader("frag", shaders::ROOM_SILL, shaders::ROOM_VIEWS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
        }
        if group == render3d::GROUP_METALS {
            return embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::ROOM_VIEWS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
        }
        if group == render3d::GROUP_LACE {
            return embed_shader("frag", shaders::ROOM_LACE, shaders::ROOM_VIEWS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
        }
        return embed_shader("frag", shaders::ROOM_GLASS, shaders::ROOM_VIEWS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if ssao {
        if group == render3d::GROUP_FLOOR {
            if mapped { return tuned_or(TUNED_FLOOR, embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG)); }
            return tuned_or(TUNED_FLOOR, embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG));
        }
        if group == render3d::GROUP_WALLS {
            if mapped { return tuned_or(TUNED_WALLS, embed_shader("frag", shaders::ROOM_WALLS, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG)); }
            return tuned_or(TUNED_WALLS, embed_shader("frag", shaders::ROOM_WALLS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG));
        }
        if group == render3d::GROUP_PAINT {
            if render3d::paint_steps_on() && tuned_frags[TUNED_PAINT_STEPS].len > 0 { return tuned_frags[TUNED_PAINT_STEPS]; }
            if mapped { return tuned_or(TUNED_PAINT, embed_shader("frag", shaders::ROOM_PAINT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG)); }
            return tuned_or(TUNED_PAINT, embed_shader("frag", shaders::ROOM_PAINT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG));
        }
        if group == render3d::GROUP_SILL {
            if render3d::sill_steps_on() && tuned_frags[TUNED_SILL_STEPS].len > 0 { return tuned_frags[TUNED_SILL_STEPS]; }
            if mapped { return tuned_or(TUNED_SILL, embed_shader("frag", shaders::ROOM_SILL, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG)); }
            return tuned_or(TUNED_SILL, embed_shader("frag", shaders::ROOM_SILL, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG));
        }
        if group == render3d::GROUP_METALS {
            if mapped { return tuned_or(TUNED_METALS, embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG)); }
            return tuned_or(TUNED_METALS, embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG));
        }
        if group == render3d::GROUP_LACE {
            return tuned_or(TUNED_LACE, embed_shader("frag", shaders::ROOM_LACE, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG));
        }
        return tuned_or(TUNED_GLASS, embed_shader("frag", shaders::ROOM_GLASS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG));
    }
    // The phone's tier without the floor's and the metals' sharp box (render3d::sharp_box_allowed,
    // the light tuner's --box off): their reflection the room's broad light, as the walls'.
    if !render3d::sharp_box_allowed && group == render3d::GROUP_FLOOR {
        if mapped { return embed_shader("frag", shaders::ROOM_FLOOR, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_FLOOR, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if !render3d::sharp_box_allowed && group == render3d::GROUP_METALS {
        if mapped { return embed_shader("frag", shaders::ROOM_METALS, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_METALS, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_FLOOR {
        if mapped { return embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_WALLS {
        if mapped { return embed_shader("frag", shaders::ROOM_WALLS, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_WALLS, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_PAINT {
        if mapped { return embed_shader("frag", shaders::ROOM_PAINT, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_PAINT, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_SILL {
        if mapped { return embed_shader("frag", shaders::ROOM_SILL, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_SILL, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_METALS {
        if mapped { return embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_LACE {
        return embed_shader("frag", shaders::ROOM_LACE, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    return embed_shader("frag", shaders::ROOM_GLASS, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
}

// Whether room_fixed's constants are still the room's block: each fixed member's bytes as
// scripts/room_fixed.py's dump had them, else the first that differs in room_fixed_stale.
fn fixed_current(g: render3d::Gpu&) -> bool {
    let one: render3d::SurfacesBlock[1] = [render3d::surfaces_block(g)];
    let b = bytes_of(one);
    var at = 0;
    for k in room_fixed::COUNT {
        let start = room_fixed::SPANS[2 * k];
        let n = room_fixed::SPANS[2 * k + 1];
        for i in n {
            guard b[start + i] == room_fixed::BYTES[at + i] else {
                render3d::room_fixed_stale = room_fixed::NAMES[k];
                return false;
            }
        }
        at += n;
    }
    render3d::room_fixed_stale = "";
    return true;
}

// The phone tier's room shaders with the room's Surfaces block as constants (room_fixed,
// made by scripts/room_fixed.py from the tuner's dump): a Valhall Mali holds only 128 uniform
// components in registers, and past them each vec4 the shaders read is a load a pixel (task 115).
fn room_frag_fixed(group: i64, mapped: bool, boxed: bool) -> const u8[:] {
    // Without the floor's and the metals' sharp box (render3d::sharp_box_allowed,
    // the light tuner's --box off): their reflection the room's broad light, as the walls'.
    if !render3d::sharp_box_allowed && group == render3d::GROUP_FLOOR {
        if mapped { return embed_shader("frag", shaders::ROOM_FLOOR, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_FLOOR, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if !render3d::sharp_box_allowed && group == render3d::GROUP_METALS {
        if mapped { return embed_shader("frag", shaders::ROOM_METALS, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_METALS, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_FLOOR {
        if mapped && boxed { return embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::BOX_MAP, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        if mapped { return embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_WALLS {
        if mapped { return embed_shader("frag", shaders::ROOM_WALLS, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_WALLS, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_PAINT {
        if mapped { return embed_shader("frag", shaders::ROOM_PAINT, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_PAINT, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_SILL {
        if mapped { return embed_shader("frag", shaders::ROOM_SILL, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_SILL, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_METALS {
        if mapped && boxed { return embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::BOX_MAP, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        if mapped { return embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG); }
        return embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    if group == render3d::GROUP_LACE {
        return embed_shader("frag", shaders::ROOM_LACE, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
    }
    return embed_shader("frag", shaders::ROOM_GLASS, shaders::NO_SSAO, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, room_fixed::ROOM_FIXED, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG);
}

// The room's pipelines for the tier (render3d::ssao_allowed): its groups', its glass's and
// the table's in it, with the screen's maps and then the floor's mirror's too, or a phone's
// without either; made again if the tier changes, or as the tuner's views come and go
// (render3d::room_views_on; their code alone cost 0.55 ms), or the tuner's switches of the
// painted wood or the sills, or the props' light (render3d::props_light, the table's and its
// mirror's with the screen's maps). The toe's shaders have none.
fn make_room_tier(own: Own&, g: render3d::Gpu&) {
    let ssao = render3d::ssao_allowed;
    let views = render3d::room_views_on();
    let steps = render3d::paint_steps_on() && tuned_frags[TUNED_PAINT_STEPS].len > 0;
    let sill_steps = render3d::sill_steps_on() && tuned_frags[TUNED_SILL_STEPS].len > 0;
    let mapped = render3d::window_map_on;
    let fixed = render3d::room_fixed_on && !ssao && !views && fixed_current(g);
    // The sharp box from the box's map, with the constants (room_frag_fixed) and the light map.
    let boxed = fixed && mapped && render3d::box_map_shown(g);
    let props = render3d::props_light && ssao;
    guard g.room_walls.id == 0 || g.room_ssao != ssao || g.room_views != views || g.room_steps != steps || g.sill_steps != sill_steps
          || g.room_mapped != mapped || g.room_fixed != fixed || g.room_boxed != boxed || g.room_props != props
    else { return; }
    if g.room_walls.id != 0 {
        for p in [g.room_floor, g.room_walls, g.room_paint, g.room_sill, g.room_metals, g.room_glass, g.room_lace, g.table_room] { gfx::release(p); }
        if g.room_planar.id != 0 {
            for p in [g.room_planar, g.planar_walls, g.planar_paint, g.planar_sill, g.planar_metals, g.planar_glass, g.planar_lace, g.planar_table] {
                gfx::release(p);
            }
            g.room_planar = gfx::Pipeline { 0 };
            g.planar_walls = gfx::Pipeline { 0 };
            g.planar_paint = gfx::Pipeline { 0 };
            g.planar_sill = gfx::Pipeline { 0 };
            g.planar_metals = gfx::Pipeline { 0 };
            g.planar_glass = gfx::Pipeline { 0 };
            g.planar_lace = gfx::Pipeline { 0 };
            g.planar_table = gfx::Pipeline { 0 };
        }
        if g.cheap_room.id != 0 {
            gfx::release(g.cheap_room);
            gfx::release(g.cheap_table);
            g.cheap_room = gfx::Pipeline { 0 };
            g.cheap_table = gfx::Pipeline { 0 };
        }
    }
    g.room_ssao = ssao;
    g.room_views = views;
    g.room_steps = steps;
    g.sill_steps = sill_steps;
    g.room_mapped = mapped;
    g.room_fixed = fixed;
    g.room_boxed = boxed;
    g.room_props = props;
    let room_vert = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::ROOM_VERT);
    let opaque = gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true };
    let blended = gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, blend: gfx::BLEND_PREMULTIPLIED };
    g.room_floor = gfx::pipeline(room_vert, room_frag(render3d::GROUP_FLOOR, ssao, views, mapped, fixed, boxed), opaque);
    g.room_walls = gfx::pipeline(room_vert, room_frag(render3d::GROUP_WALLS, ssao, views, mapped, fixed, boxed), opaque);
    g.room_paint = gfx::pipeline(room_vert, room_frag(render3d::GROUP_PAINT, ssao, views, mapped, fixed, boxed), opaque);
    g.room_sill = gfx::pipeline(room_vert, room_frag(render3d::GROUP_SILL, ssao, views, mapped, fixed, boxed), opaque);
    g.room_metals = gfx::pipeline(room_vert, room_frag(render3d::GROUP_METALS, ssao, views, mapped, fixed, boxed), opaque);
    g.room_glass = gfx::pipeline(room_vert, room_frag(render3d::GROUP_GLASS, ssao, views, mapped, fixed, boxed), blended);
    g.room_lace = gfx::pipeline(room_vert, room_frag(render3d::GROUP_LACE, ssao, views, mapped, fixed, boxed), blended);
    let table_vert = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TABLE_VERT);
    let table_desc = gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true, blend: gfx::BLEND_PREMULTIPLIED };
    let props_vert = embed_shader("vert", shaders::PROPS_LIGHT, shaders::VS_SET, shaders::FRAME, shaders::TABLE_VERT);
    let room_table_frag = if props { embed_shader("frag", shaders::PROPS_LIGHT, shaders::TABLE_ROOM, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::TABLE_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TABLE_FRAG) }
                          else if ssao { tuned_or(TUNED_TABLE_ROOM, embed_shader("frag", shaders::TABLE_ROOM, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::TABLE_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TABLE_FRAG)) }
                          else { embed_shader("frag", shaders::TABLE_ROOM, shaders::SHELL_WINDOWS, shaders::NO_SSAO, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::TABLE_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TABLE_FRAG) };
    g.table_room = gfx::pipeline(if props { props_vert } else { table_vert }, room_table_frag, table_desc);
    guard ssao else { return; }
    let planar_frag = if views { embed_shader("frag", shaders::ROOM_FLOOR, shaders::PLANAR_FLOOR, shaders::ROOM_VIEWS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }
                      else { if mapped { embed_shader("frag", shaders::ROOM_FLOOR, shaders::PLANAR_FLOOR, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }
        else { tuned_or(TUNED_PLANAR, embed_shader("frag", shaders::ROOM_FLOOR, shaders::PLANAR_FLOOR, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG)) } };
    g.room_planar = gfx::pipeline(room_vert, planar_frag, opaque);
    g.planar_walls = gfx::pipeline(room_vert, embed_shader("frag", shaders::ROOM_WALLS, shaders::MIRROR_PASS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG), opaque);
    g.planar_paint = gfx::pipeline(room_vert, embed_shader("frag", shaders::ROOM_PAINT, shaders::MIRROR_PASS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG), opaque);
    // The sills in the mirror as in the room, the tuner's switches too.
    let sill_mirror = if sill_steps { tuned_frags[TUNED_SILL_MIRROR] } else { embed_shader("frag", shaders::ROOM_SILL, shaders::MIRROR_PASS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) };
    g.planar_sill = gfx::pipeline(room_vert, sill_mirror, opaque);
    g.planar_metals = gfx::pipeline(room_vert, embed_shader("frag", shaders::ROOM_METALS, shaders::MIRROR_PASS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG), opaque);
    // The glass and lace write depth here, so the reflection resolves at the window.
    g.planar_glass = gfx::pipeline(room_vert, embed_shader("frag", shaders::ROOM_GLASS, shaders::MIRROR_PASS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG),
                                   gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true, blend: gfx::BLEND_PREMULTIPLIED });
    g.planar_lace = gfx::pipeline(room_vert, embed_shader("frag", shaders::ROOM_LACE, shaders::MIRROR_PASS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG),
                                   gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true, blend: gfx::BLEND_PREMULTIPLIED });
    let mirror_frag = if props { embed_shader("frag", shaders::PROPS_LIGHT, shaders::TABLE_ROOM, shaders::SHELL_WINDOWS, shaders::MIRROR_PASS, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::TABLE_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TABLE_FRAG) }
                      else { embed_shader("frag", shaders::TABLE_ROOM, shaders::SHELL_WINDOWS, shaders::MIRROR_PASS, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::TABLE_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TABLE_FRAG) };
    g.planar_table = gfx::pipeline(if props { props_vert } else { table_vert }, mirror_frag,
                                   gfx::PipelineDesc { cull: gfx::CULL_BACK, clockwise: true, depth_test: true, depth_write: true,
                                                       blend: gfx::BLEND_PREMULTIPLIED });
    guard render3d::mirror_cheap else { return; }
    g.cheap_room = gfx::pipeline(room_vert, embed_shader("frag", shaders::MIRROR_CHEAP_PASS, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::ROOM_FRAG), opaque);
    g.cheap_table = gfx::pipeline(table_vert, embed_shader("frag", shaders::MIRROR_CHEAP_PASS, shaders::CHEAP_TABLE, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::ROOM_FRAG),
                                  gfx::PipelineDesc { cull: gfx::CULL_BACK, clockwise: true, depth_test: true, depth_write: true });
}

// The room's pipelines (make_room_tier) and its bake's, its view out's, glow's, occlusion's
// and mirror's (render3d::room_surfaces), made the first time they are wanted, outside a
// pass.
fn make_room(own: Own&, g: render3d::Gpu&) {
    make_room_tier(own, g);
    guard g.bake_room.id == 0 else { return; }
    g.bake_room = gfx::pipeline(embed_shader("vert", shaders::FULL_VERT), embed_shader("frag", shaders::BAKE_ROOM, shaders::BAKE_FRAG));
    g.outside = gfx::pipeline(embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::OUTSIDE_VERT),
                              tuned_or(TUNED_OUTSIDE, embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::OUTSIDE_MAIN)),
                              gfx::PipelineDesc { cull: gfx::CULL_NONE, blend: gfx::BLEND_PREMULTIPLIED });
    let full = embed_shader("vert", shaders::FULL_VERT);
    g.bloom_pick = gfx::pipeline(full, embed_shader("frag", shaders::GLOW_PICK_FRAG));
    g.bloom_blur = gfx::pipeline(full, embed_shader("frag", shaders::GLOW_BLUR_FRAG));
    g.bloom_add = gfx::pipeline(full, embed_shader("frag", shaders::GLOW_ADD_FRAG));
    let solid = gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true };
    let pre = embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::PRE_FRAG);
    g.pre_room = gfx::pipeline(embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::ROOM_VERT),
                               embed_shader("frag", shaders::PRE_ROOM, shaders::FS_SET, shaders::FRAME, shaders::PRE_FRAG),
                               gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true });
    g.pre_table = gfx::pipeline(embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TABLE_VERT), pre, solid);
    g.pre_lit = gfx::pipeline(embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::LIT_VERT), pre, solid);
    g.ssao = gfx::pipeline(full, embed_shader("frag", shaders::SSAO_FRAG));
    g.ssao_blur = gfx::pipeline(full, embed_shader("frag", shaders::SSAO_BLUR_FRAG));
    g.gtao = gfx::pipeline(full, embed_shader("frag", shaders::GTAO_FRAG));
    g.planar_resolve = gfx::pipeline(full, embed_shader("frag", shaders::PLANAR_RESOLVE_FRAG));
    g.planar_show = gfx::pipeline(full, embed_shader("frag", shaders::TONE_FN, shaders::PLANAR_SHOW_FRAG));
    g.planar_mip = gfx::pipeline(full, embed_shader("frag", shaders::PLANAR_MIP_FRAG));
    g.planar_sampler = gfx::sampler(gfx::SamplerDesc { wrap_u: gfx::CLAMP, wrap_v: gfx::CLAMP, wrap_w: gfx::CLAMP });
}

// The window's light map (render3d::window_map) baked into its first level, made the first
// time, and its mips: shaders::WINDOW_MAP_FRAG for every texel, with the shell's block and
// the frame's, outside a pass.
struct WindowMapBake { tree: float4 }
fn window_map_pass(own: Own&, g: render3d::Gpu&) {
    if g.window_map.id == 0 {
        g.window_map = render3d::baked(own, render3d::WINDOW_MAP_W, render3d::WINDOW_MAP_H, gfx::RGBA8);
        g.window_map_bake = gfx::pipeline(embed_shader("vert", shaders::FULL_VERT),
                                          embed_shader("frag", shaders::WINDOW_MAP_BAKE, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME,
                                                       shaders::WINDOW_MAP_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::WINDOW_MAP_FRAG));
    }
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = g.window_map;
    gfx::begin_pass(pass);
    gfx::bind(g.window_map_bake);
    gfx::bind_texture(gfx::FRAGMENT, 0, render3d::tree_or_stand_in(g), g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, render3d::lace_or_stand_in(g), g.aniso);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 1, render3d::shell_block(g));
    gfx::uniforms(gfx::FRAGMENT, 2, WindowMapBake { float4 { if render3d::window_map_tree(g) { 1.0 } else { 0.0 }, 0.0, 0.0, 0.0 } });
    gfx::draw(3);
    gfx::end_pass();
    gfx::generate_mips(g.window_map);
}

// The box's map (render3d::box_map): shaders::box_irradiance a texel, by box_cell's layout,
// drawn by ROOM_FRAG's bake over a target sized from the shell's box (BOX_MAP_TEXEL, a
// texel more each way than the shader's cells need), with the opaque groups' shared
// textures (render3d::room_textures's first five) and the room's block.
let BOX_MAP_TEXEL: f32 = 1.2192;    // shaders::BOX_MAP_TEXEL, 4 cm
fn box_map_pass(own: Own&, g: render3d::Gpu&) {
    let b = render3d::surfaces_block(g);
    if g.box_map.id == 0 {
        let cx = ceil((b.room_box.y - b.room_box.x) / BOX_MAP_TEXEL + 0.5) as i64 + 1;
        let cy = ceil((b.room_heights.x - b.shell.z) / BOX_MAP_TEXEL + 0.5) as i64 + 1;
        let cz = ceil((b.room_box.w - b.room_box.z) / BOX_MAP_TEXEL + 0.5) as i64 + 1;
        g.box_map = gfx::render_target(2 * (cx + cz), cz + cy, gfx::RGBA16F);
        g.box_map_bake = gfx::pipeline(embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::BOX_MAP_VERT),
                                       embed_shader("frag", shaders::BOX_MAP_BAKE, shaders::NO_SSAO, shaders::WINDOW_MAP, shaders::SHELL_WINDOWS,
                                                    shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN,
                                                    shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG));
    }
    var pass = gfx::PassDesc { color_value: float4_0 };
    pass.color[0] = g.box_map;
    gfx::begin_pass(pass);
    gfx::bind(g.box_map_bake);
    gfx::bind_texture(gfx::FRAGMENT, 0, render3d::tree_or_stand_in(g), g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.window_map, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 2, render3d::light_or_stand_in(g), g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 3, render3d::table_map_or_stand_in(g), g.compare);
    gfx::bind_texture(gfx::FRAGMENT, 4, render3d::corners_or_stand_in(g), g.linear);
    gfx::uniforms(gfx::VERTEX, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 1, b);
    gfx::draw(3);
    gfx::end_pass();
}

// The floor's mirror (render3d::planar_shown), before the board's pass: the view out, the
// table and the room drawn mirrored under the floor with clip's frame (the view out with
// plain's) into g.planar_color, then made the room's light again with each texel's distance
// into g.planar_map (shaders::PLANAR_RESOLVE_FRAG), and its mips, which the floor reads.
// Not the board and its pieces: from under the floor the table's top hides them.
fn planar_pass(own: Own&, g: render3d::Gpu&, size: int2, clip: render3d::Frame, plain: render3d::Frame,
               resolve: render3d::PlanarResolve) {
    let q = render3d::planar_size_of(size);
    if g.planar_map.id == 0 || g.planar_size.x != q.x || g.planar_size.y != q.y {
        if g.planar_map.id != 0 {
            for t in [g.planar_color, g.planar_depth, g.planar_map] { gfx::release(t); }
            gfx::flush();
        }
        g.planar_color = gfx::render_target(q.x, q.y, gfx::RGBA16F);
        g.planar_depth = gfx::texture2d(q.x, q.y, gfx::DEPTH16, gfx::DEPTH_TARGET | gfx::SAMPLED);
        g.planar_map = gfx::texture(gfx::TextureDesc { format: gfx::RGBA16F, usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                                       width: q.x as i32, height: q.y as i32,
                                                       mips: render3d::PLANAR_MIPS as i32 });
        g.planar_size = q;
    }
    var pass = gfx::PassDesc { depth: g.planar_depth, color_value: float4 { 0.0, 0.0, 0.0, 1.0 } };
    pass.color[0] = g.planar_color;
    gfx::begin_pass(pass);
    let kept = g.frame;
    if render3d::outside_shown(g) {
        g.frame = plain;
        draw_outside(own, g, true);
        if render3d::tree_card_in_mirror(g) { draw_tree_card(own, g, true); }
    }
    g.frame = clip;
    let surfaces = render3d::mirror_surfaces_block(g);
    if render3d::mirror_cheap_on(g) {
        cheap_mirror(g, clip, surfaces);
    } else {
        if render3d::table_shown(g) && render3d::table_in_room(g) {
            gfx::bind(g.planar_table);
            gfx::bind_texture(gfx::FRAGMENT, 0, g.table_albedo, g.aniso);
            gfx::bind_texture(gfx::FRAGMENT, 1, g.table_normal, g.aniso);
            gfx::bind_texture(gfx::FRAGMENT, 2, g.frame_albedo, g.aniso);
            gfx::bind_texture(gfx::FRAGMENT, 3, g.table_wear, g.aniso);
            gfx::bind_texture(gfx::FRAGMENT, 4, g.table_wear_n, g.aniso);
            gfx::bind_texture(gfx::FRAGMENT, 5, render3d::tree_or_stand_in(g), g.linear);
            gfx::bind_texture(gfx::FRAGMENT, 6, g.shadow_map, g.compare);
            gfx::bind_texture(gfx::FRAGMENT, 7, render3d::table_map_or_stand_in(g), g.compare);
            gfx::uniforms(gfx::VERTEX, 0, clip);
            gfx::uniforms(gfx::FRAGMENT, 0, clip);
            gfx::bind_texture(gfx::FRAGMENT, 8, render3d::tapestry_or_stand_in(g), g.aniso);
            gfx::bind_texture(gfx::FRAGMENT, 9, render3d::lace_or_stand_in(g), g.linear);
            gfx::uniforms(gfx::FRAGMENT, 1, render3d::mirror_table_block(g));
            gfx::uniforms(gfx::FRAGMENT, 2, render3d::shell_block(g));
            if g.room_props {
                gfx::bind_storage_buffer(gfx::VERTEX, 0, g.props_open);
                gfx::bind_texture(gfx::FRAGMENT, 10, render3d::light_or_stand_in(g), g.linear);
                gfx::uniforms(gfx::FRAGMENT, 3, render3d::props_light_block(g));
            }
            gfx::bind_vertex_buffer(g.table_vb);
            gfx::bind_index_buffer(g.table_ib, 4);
            gfx::draw_indexed(g.table_count);
        }
        // The room less its floor, which lies under the clip plane.
        draw_room_group(g, clip, surfaces, g.planar_walls, render3d::GROUP_WALLS, false, false, true);
        draw_room_group(g, clip, surfaces, g.planar_sill, render3d::GROUP_SILL, false, false, true);
        draw_room_group(g, clip, surfaces, g.planar_paint, render3d::GROUP_PAINT, false, false, true);
        draw_room_group(g, clip, surfaces, g.planar_metals, render3d::GROUP_METALS, false, false, true);
    }
    draw_room_group(g, clip, surfaces, g.planar_glass, render3d::GROUP_GLASS, false, false, true);
    draw_room_group(g, clip, surfaces, g.planar_lace, render3d::GROUP_LACE, false, false, true);
    gfx::end_pass();
    g.frame = kept;
    var into = gfx::PassDesc { clear_color: false };
    into.color[0] = g.planar_map;
    gfx::begin_pass(into);
    gfx::bind(g.planar_resolve);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.planar_color, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.planar_depth, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, resolve);
    gfx::draw(3);
    gfx::end_pass();
    // Its mips, each a tent over the level above (shaders::PLANAR_MIP_FRAG), drawn into the
    // level while the shader reads only the one above.
    for level in 1..render3d::PLANAR_MIPS {
        var down = gfx::PassDesc { mip: level as i32, clear_color: false };
        down.color[0] = g.planar_map;
        gfx::begin_pass(down);
        gfx::bind(g.planar_mip);
        gfx::bind_texture(gfx::FRAGMENT, 0, g.planar_map, g.planar_sampler);
        gfx::uniforms(gfx::FRAGMENT, 0, float4 { (level - 1) as f32, 0.0, 0.0, 0.0 });
        gfx::draw(3);
        gfx::end_pass();
    }
}

// The cheap mirror world (render3d::mirror_cheap_on): the table and the room's large
// shapes, each with the one cheap shader, into the mirror's pass begun.
fn cheap_textures(g: render3d::Gpu&) -> Texture[8] {
    var tex: Texture[8] = [render3d::tree_or_stand_in(g), g.lace_mask, render3d::light_or_stand_in(g), render3d::corners_or_stand_in(g),
                           g.wall_albedo, g.paper_mask, g.plaster_tone, g.stone_tile];
    for i in 8 { if tex[i].id == 0 { tex[i] = g.crown_map; } }
    return tex;
}
fn cheap_mirror(g: render3d::Gpu&, clip: render3d::Frame, surfaces: render3d::SurfacesBlock) {
    let tex = cheap_textures(g);
    if render3d::table_shown(g) && render3d::table_in_room(g) {
        gfx::bind(g.cheap_table);
        for i in 8 { gfx::bind_texture(gfx::FRAGMENT, i, if i == 4 { g.table_albedo } else { tex[i] }, g.linear); }
        gfx::uniforms(gfx::VERTEX, 0, clip);
        gfx::uniforms(gfx::FRAGMENT, 0, clip);
        gfx::uniforms(gfx::FRAGMENT, 1, surfaces);
        gfx::uniforms(gfx::FRAGMENT, 2, render3d::mirror_table_block(g));
        gfx::bind_vertex_buffer(g.table_vb);
        gfx::bind_index_buffer(g.table_ib, 4);
        gfx::draw_indexed(g.table_count);
    }
    gfx::bind(g.cheap_room);
    for i in 8 { gfx::bind_texture(gfx::FRAGMENT, i, tex[i], g.linear); }
    gfx::uniforms(gfx::VERTEX, 0, clip);
    gfx::uniforms(gfx::FRAGMENT, 0, clip);
    gfx::uniforms(gfx::FRAGMENT, 1, surfaces);
    gfx::bind_vertex_buffer(g.room_vb);
    gfx::bind_index_buffer(g.room_ib, 4);
    gfx::draw_indexed(g.cheap_count, 1, g.cheap_from, 0, 0);
}

// The tuner's view of the floor's mirror over all of `target`.
fn planar_show_pass(own: Own&, g: render3d::Gpu&, target: Texture, show: render3d::PlanarShow) {
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = target;
    gfx::begin_pass(pass);
    gfx::bind(g.planar_show);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.planar_map, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, show);
    gfx::draw(3);
    gfx::end_pass();
}

// The room's ambient occlusion (render3d::ssao_shown), before the board's pass: the room,
// the table and the board at half size into where each pixel is and which way it faces,
// then its occlusion, then that blurred into g.ssao_map, which the room and the table read.
fn ssao_pass(own: Own&, g: render3d::Gpu&, size: int2) {
    let q = render3d::ssao_size_of(size);
    if g.ssao_map.id == 0 || g.ssao_size.x != q.x || g.ssao_size.y != q.y {
        if g.ssao_map.id != 0 {
            for t in [g.pre_place, g.pre_facing, g.pre_depth, g.ssao_raw, g.ssao_map] { gfx::release(t); }
            gfx::flush();
        }
        g.pre_place = gfx::render_target(q.x, q.y, gfx::RGBA16F);
        g.pre_facing = gfx::render_target(q.x, q.y, gfx::RGBA8);
        g.pre_depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET, width: q.x, height: q.y });
        g.ssao_raw = gfx::render_target(q.x, q.y, gfx::RG16F);
        g.ssao_map = gfx::render_target(q.x, q.y, gfx::RG16F);
        g.ssao_size = q;
    }
    let f = g.frame;
    var pass = gfx::PassDesc { depth: g.pre_depth, color_value: float4_0 };
    pass.color[0] = g.pre_place;
    pass.color[1] = g.pre_facing;
    gfx::begin_pass(pass);
    gfx::bind(g.pre_lit);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    draw_meshes(own, g, 0.0);
    if render3d::table_shown(g) {
        gfx::bind(g.pre_table);
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 0, f);
        gfx::bind_vertex_buffer(g.table_vb);
        gfx::bind_index_buffer(g.table_ib, 4);
        gfx::draw_indexed(g.table_count);
    }
    gfx::bind(g.pre_room);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::bind_vertex_buffer(g.room_vb);
    gfx::bind_index_buffer(g.room_ib, 4);
    gfx::draw_indexed(g.room_count);
    if g.window_count > 0 {
        gfx::bind_vertex_buffer(g.window_vb);
        gfx::bind_index_buffer(g.window_ib, 4);
        gfx::draw_indexed(g.window_count);
    }
    gfx::end_pass();
    gfx::begin_pass(g.ssao_raw, gfx::Texture { 0 }, float4_0);
    gfx::bind(if render3d::ssao_gtao { g.gtao } else { g.ssao });
    gfx::bind_texture(gfx::FRAGMENT, 0, g.pre_place, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.pre_facing, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, render3d::ssao_pass_of(g, q));
    gfx::draw(3);
    gfx::end_pass();
    gfx::begin_pass(g.ssao_map, gfx::Texture { 0 }, float4_0);
    gfx::bind(g.ssao_blur);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.ssao_raw, g.linear);
    gfx::draw(3);
    gfx::end_pass();
}

// The window's glow (render3d::bloom_shown): what is bright in `image` picked into a quarter
// of its size, blurred across and down, and added back over it into `target`.
fn bloom_pass(own: Own&, g: render3d::Gpu&, image: Texture, target: Texture, size: int2) {
    let q = render3d::bloom_size_of(size);
    if g.bloom_a.id == 0 || g.bloom_size.x != q.x || g.bloom_size.y != q.y {
        if g.bloom_a.id != 0 { gpu_release_waited(own, g.bloom_a, g.bloom_b); }
        g.bloom_a = gfx::render_target(q.x, q.y, gfx::RGBA16F);
        g.bloom_b = gfx::render_target(q.x, q.y, gfx::RGBA16F);
        g.bloom_size = q;
    }
    gfx::begin_pass(g.bloom_a, gfx::Texture { 0 }, float4_0);
    gfx::bind(g.bloom_pick);
    gfx::bind_texture(gfx::FRAGMENT, 0, image, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, render3d::bloom_pick_of(g, size));
    gfx::draw(3);
    gfx::end_pass();
    for k in 2 {
        let from = if k == 0 { g.bloom_a } else { g.bloom_b };
        let to = if k == 0 { g.bloom_b } else { g.bloom_a };
        gfx::begin_pass(to, gfx::Texture { 0 }, float4_0);
        gfx::bind(g.bloom_blur);
        gfx::bind_texture(gfx::FRAGMENT, 0, from, g.linear);
        gfx::uniforms(gfx::FRAGMENT, 0, render3d::bloom_blur_of(g, q, k == 0));
        gfx::draw(3);
        gfx::end_pass();
    }
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = target;
    gfx::begin_pass(pass);
    gfx::bind(g.bloom_add);
    gfx::bind_texture(gfx::FRAGMENT, 0, image, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.bloom_a, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, render3d::bloom_add_of(g, size));
    gfx::draw(3);
    gfx::end_pass();
}

// The scene's target under the screen's size (render3d::scene_size_of), and its
// pipelines up to the screen, made the first time.
fn scene_target(own: Own&, g: render3d::Gpu&, size: int2) -> Texture {
    if g.upscale.id == 0 {
        let full = embed_shader("vert", shaders::FULL_VERT);
        g.upscale = gfx::pipeline(full, embed_shader("frag", shaders::UPSCALE_FRAG));
        g.upscale_cubic = gfx::pipeline(full, embed_shader("frag", shaders::UPSCALE_CUBIC, shaders::UPSCALE_FRAG));
    }
    return gfx::render_target(size.x, size.y, gfx::RGBA8);
}

// The scene scaled up over all of `target` (render3d::draw, shaders::UPSCALE_FRAG).
fn upscale_pass(own: Own&, g: render3d::Gpu&, target: Texture, u: render3d::Upscale) {
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = target;
    gfx::begin_pass(pass);
    gfx::bind(if render3d::scene_cubic { g.upscale_cubic } else { g.upscale });
    gfx::bind_texture(gfx::FRAGMENT, 0, g.scene_image, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, u);
    gfx::draw(3);
    gfx::end_pass();
}

// The scenic views' HDR targets' format (render3d::hdr_shown): RG11B10F, as many bytes as
// the 8-bit picture's, or RGBA16F where it can't be drawn into and sampled, or not
// multisampled at own.samples. The fork's gfx asks the device (src/native/gfx_fork.c's
// stand-ins say no, so a plain build against the release's gfx draws RGBA16F).
extern fn gfx_format_supported(format: i32, usage: i32) -> bool = "gs_gfx_format_supported";
extern fn gfx_samples_supported(format: i32, samples: i32) -> bool = "gs_gfx_samples_supported";
fn hdr_format(own: Own&) -> i32 {
    let rg = gfx_format_supported(gfx::RG11B10F, gfx::COLOR_TARGET | gfx::SAMPLED)
        && (own.samples <= 1 || gfx_samples_supported(gfx::RG11B10F, own.samples));
    if !render3d::hdr_wide && rg { gfx::RG11B10F } else { gfx::RGBA16F }
}

// The board's lit shader into the HDR target for the pieces' material (render3d::PIECES_..),
// its shadow in 16 taps, the high tier's.
fn lit_hdr_frag(pieces: i32) -> const u8[:] {
    if pieces == render3d::PIECES_WOOD { return embed_shader("frag", shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::PIECES_WOOD, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::LIT_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    if pieces == render3d::PIECES_WINTER { return embed_shader("frag", shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::PIECES_WINTER, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::LIT_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    if pieces == render3d::PIECES_MINERAL { return embed_shader("frag", shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::PIECES_MINERAL, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::LIT_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    return embed_shader("frag", shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::LIT_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG);
}

// The board's lit shader in the room's shell (8-bit), as lit_hdr_frag's but tonemapped as
// the app's: the sun through the shell's own windows.
fn lit_shell_frag(pieces: i32) -> const u8[:] {
    if pieces == render3d::PIECES_WOOD { return embed_shader("frag", shaders::SHELL_WINDOWS, shaders::PIECES_WOOD, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::LIT_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    if pieces == render3d::PIECES_WINTER { return embed_shader("frag", shaders::SHELL_WINDOWS, shaders::PIECES_WINTER, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::LIT_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    if pieces == render3d::PIECES_MINERAL { return embed_shader("frag", shaders::SHELL_WINDOWS, shaders::PIECES_MINERAL, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::LIT_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    return embed_shader("frag", shaders::SHELL_WINDOWS, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::LIT_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG);
}

// The lit pass's pipelines in the shell (render3d::Gpu.lit_shell), made outside a pass when
// the shell first shows and again when the pieces change.
fn make_lit_shell(own: Own&, g: render3d::Gpu&) {
    guard g.lit_shell.id == 0 || g.shell_pieces != g.pieces else { return; }
    if g.lit_shell.id != 0 {
        gfx::flush();
        gfx::release(g.lit_shell);
        gfx::release(g.fading_shell);
    }
    g.shell_pieces = g.pieces;
    let lit_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::LIT_VERT);
    let lit_fs = lit_shell_frag(g.pieces);
    g.lit_shell = gfx::pipeline(lit_vs, lit_fs, gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true });
    g.fading_shell = gfx::pipeline(lit_vs, lit_fs, gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, blend: gfx::BLEND_ALPHA });
}

// The HDR target's pipelines (render3d::HdrPipelines), made outside a pass when first wanted
// and again when what they were made for changes.
fn make_hdr(own: Own&, g: render3d::Gpu&) {
    let h .= g.hdr_pipes;
    let paint = render3d::paint_steps_on() && tuned_frags[TUNED_PAINT_HDR].len > 0;
    let sill = render3d::sill_steps_on() && tuned_frags[TUNED_SILL_HDR].len > 0;
    let mapped = render3d::window_map_on;
    let props = render3d::props_light;
    guard h.tone.id == 0 || h.pieces != g.pieces || h.paint_steps != paint || h.sill_steps != sill || h.mapped != mapped || h.props_light != props
    else { return; }
    if h.tone.id != 0 { release_hdr(own, g); }
    h.pieces = g.pieces;
    h.mapped = mapped;
    h.props_light = props;
    h.paint_steps = paint;
    h.sill_steps = sill;
    let lit_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::LIT_VERT);
    let lit_fs = lit_hdr_frag(g.pieces);
    h.lit = gfx::pipeline(lit_vs, lit_fs, gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true });
    h.fading = gfx::pipeline(lit_vs, lit_fs, gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, blend: gfx::BLEND_ALPHA });
    h.table = gfx::pipeline(if props { embed_shader("vert", shaders::PROPS_LIGHT, shaders::VS_SET, shaders::FRAME, shaders::TABLE_VERT) }
                            else { embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TABLE_VERT) },
                            if props { embed_shader("frag", shaders::PROPS_LIGHT, shaders::TABLE_ROOM, shaders::SHELL_WINDOWS, shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::TABLE_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TABLE_FRAG) }
                            else { embed_shader("frag", shaders::TABLE_ROOM, shaders::SHELL_WINDOWS, shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::TABLE_SHELL, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TABLE_FRAG) },
                            gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true, blend: gfx::BLEND_PREMULTIPLIED });
    let room_vert = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::ROOM_VERT);
    let opaque = gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true };
    h.floor = gfx::pipeline(room_vert, (if mapped { embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_FLOOR, shaders::SHARP_BOX, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }), opaque);
    h.planar = gfx::pipeline(room_vert, (if mapped { embed_shader("frag", shaders::ROOM_FLOOR, shaders::PLANAR_FLOOR, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_FLOOR, shaders::PLANAR_FLOOR, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }), opaque);
    h.floor_kinds = [gfx::pipeline(room_vert, (if mapped { embed_shader("frag", shaders::ROOM_FLOOR, shaders::FLOOR_SHADE, shaders::FLOOR_NO_TABLE, shaders::SHARP_BOX, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_FLOOR, shaders::FLOOR_SHADE, shaders::FLOOR_NO_TABLE, shaders::SHARP_BOX, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }), opaque),
                     gfx::pipeline(room_vert, (if mapped { embed_shader("frag", shaders::ROOM_FLOOR, shaders::FLOOR_NO_TABLE, shaders::SHARP_BOX, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_FLOOR, shaders::FLOOR_NO_TABLE, shaders::SHARP_BOX, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }), opaque)];
    h.planar_kinds = [gfx::pipeline(room_vert, (if mapped { embed_shader("frag", shaders::ROOM_FLOOR, shaders::FLOOR_SHADE, shaders::FLOOR_NO_TABLE, shaders::PLANAR_FLOOR, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_FLOOR, shaders::FLOOR_SHADE, shaders::FLOOR_NO_TABLE, shaders::PLANAR_FLOOR, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }), opaque),
                      gfx::pipeline(room_vert, (if mapped { embed_shader("frag", shaders::ROOM_FLOOR, shaders::FLOOR_NO_TABLE, shaders::PLANAR_FLOOR, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_FLOOR, shaders::FLOOR_NO_TABLE, shaders::PLANAR_FLOOR, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }), opaque)];
    h.walls = gfx::pipeline(room_vert, (if mapped { embed_shader("frag", shaders::ROOM_WALLS, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_WALLS, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }), opaque);
    h.paint = gfx::pipeline(room_vert, if paint { tuned_frags[TUNED_PAINT_HDR] } else { (if mapped { embed_shader("frag", shaders::ROOM_PAINT, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_PAINT, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }) }, opaque);
    h.sill = gfx::pipeline(room_vert, if sill { tuned_frags[TUNED_SILL_HDR] } else { (if mapped { embed_shader("frag", shaders::ROOM_SILL, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_SILL, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }) }, opaque);
    h.metals = gfx::pipeline(room_vert, (if mapped { embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::HDR_OUT, shaders::WINDOW_MAP_LEAVES, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) } else { embed_shader("frag", shaders::ROOM_METALS, shaders::SHARP_BOX, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG) }), opaque);
    h.glass = gfx::pipeline(room_vert, embed_shader("frag", shaders::ROOM_GLASS, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG),
                            gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, blend: gfx::BLEND_PREMULTIPLIED });
    h.lace = gfx::pipeline(room_vert, embed_shader("frag", shaders::ROOM_LACE, shaders::HDR_OUT, shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::ROOM_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::SSAO_FN, shaders::TONE_FN, shaders::ROOM_FRAG),
                            gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, blend: gfx::BLEND_PREMULTIPLIED });
    h.outside = gfx::pipeline(embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::OUTSIDE_VERT),
                              tuned_or(TUNED_OUTSIDE_HDR, embed_shader("frag", shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::OUTSIDE_MAIN)),
                              gfx::PipelineDesc { cull: gfx::CULL_NONE, blend: gfx::BLEND_PREMULTIPLIED });
    h.motes = gfx::pipeline(embed_shader("vert", shaders::SHELL_WINDOWS, shaders::VS_SET, shaders::FRAME, shaders::DUST_HEAD, shaders::WIND_FN, shaders::LIGHT_FN,
                                         shaders::DUST_VERT),
                            embed_shader("frag", shaders::HDR_OUT, shaders::DUST_FRAG),
                            gfx::PipelineDesc { depth_test: true, blend: gfx::BLEND_ADD });
    h.tone = gfx::pipeline(embed_shader("vert", shaders::FULL_VERT), embed_shader("frag", shaders::HDR_TONE_FRAG));
    let full = embed_shader("vert", shaders::FULL_VERT);
    h.glow_first = gfx::pipeline(full, embed_shader("frag", shaders::GLOW_FIRST, shaders::GLOW_DOWN_FRAG));
    h.glow_down = gfx::pipeline(full, embed_shader("frag", shaders::GLOW_DOWN_FRAG));
    h.glow_up = gfx::pipeline(full, embed_shader("frag", shaders::GLOW_UP_FRAG), gfx::PipelineDesc { blend: gfx::BLEND_ALPHA });
    h.haze_cross = gfx::pipeline(full, embed_shader("frag", shaders::SHELL_WINDOWS, shaders::FS_SET, shaders::FRAME, shaders::HAZE_BLOCK,
                                                    shaders::HAZE_CROSS_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::HAZE_CROSS_FRAG));
    let haze = embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::HAZE_BLOCK, shaders::HAZE_FRAG);
    h.haze = gfx::pipeline(full, haze);
    h.haze_full = gfx::pipeline(full, haze, gfx::PipelineDesc { blend: gfx::BLEND_ADD });
    h.haze_add = gfx::pipeline(full, embed_shader("frag", shaders::HAZE_ADD_FRAG), gfx::PipelineDesc { blend: gfx::BLEND_ADD });
}

// The HDR target's pipelines given back (make_hdr, release).
fn release_hdr(own: Own&, g: render3d::Gpu&) {
    let h = g.hdr_pipes;
    for p in [h.lit, h.fading, h.table, h.floor, h.planar, h.walls, h.paint, h.sill, h.metals, h.glass, h.lace, h.outside, h.motes, h.tone,
              h.glow_first, h.glow_down, h.glow_up, h.haze_cross, h.haze, h.haze_full, h.haze_add, h.floor_kinds[0], h.floor_kinds[1],
              h.planar_kinds[0], h.planar_kinds[1]] {
        if p.id != 0 { gfx::release(p); }
    }
    g.hdr_pipes = default<render3d::HdrPipelines>();
}

// The HDR target the pass resolved (g.hdr_image) tonemapped over all of `target`
// (shaders::HDR_TONE_FRAG).
// With SMAA into its input (g.color), then antialiased into `target`.
fn tone_pass(own: Own&, g: render3d::Gpu&, target: Texture) {
    let smaa = g.aa == AA_SMAA;
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = if smaa { g.color } else { target };
    gfx::begin_pass(pass);
    gfx::bind(g.hdr_pipes.tone);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.hdr_image, g.linear);
    let glow = render3d::glow_shown(g);
    gfx::bind_texture(gfx::FRAGMENT, 1, if glow { g.glow_levels[0] } else { g.hdr_image }, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 2, if glow { g.glow_levels[render3d::glow_smallest()] } else { g.hdr_image }, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, render3d::hdr_tone_of(g));
    gfx::draw(3);
    gfx::end_pass();
    if smaa { antialias(own, g, target); }
}

// The scenic views' glow (render3d::glow_shown) from the HDR target the pass resolved: what
// is over the threshold picked into a quarter of its size, halved level by level, and
// widened back up, each level blended over the one above; tone_pass adds the first.
fn glow_pass(own: Own&, g: render3d::Gpu&, size: int2) {
    if g.glow_size.x != size.x || g.glow_size.y != size.y {
        gfx::flush();
        for k in render3d::GLOW_LEVELS {
            if g.glow_levels[k].id != 0 { gfx::release(g.glow_levels[k]); }
            let q = render3d::glow_level_size(size, k);
            g.glow_levels[k] = gfx::render_target(q.x, q.y, gfx::RGBA16F);
        }
        g.glow_size = size;
    }
    let h .= g.hdr_pipes;
    let n = clamp(render3d::hdr_glow.levels, 1, render3d::GLOW_LEVELS);
    for k in n {
        gfx::begin_pass(g.glow_levels[k], gfx::Texture { 0 }, float4_0);
        gfx::bind(if k == 0 { h.glow_first } else { h.glow_down });
        gfx::bind_texture(gfx::FRAGMENT, 0, if k == 0 { g.hdr_image } else { g.glow_levels[k - 1] }, g.linear);
        let from = if k == 0 { size } else { render3d::glow_level_size(size, k - 1) };
        gfx::uniforms(gfx::FRAGMENT, 0, render3d::glow_step_of(from, render3d::glow_level_size(size, k), k == 0));
        gfx::draw(3);
        gfx::end_pass();
    }
    for i in n - 1 {
        let k = n - 2 - i;
        var pass = gfx::PassDesc { clear_color: false };
        pass.color[0] = g.glow_levels[k];
        gfx::begin_pass(pass);
        gfx::bind(h.glow_up);
        gfx::bind_texture(gfx::FRAGMENT, 0, g.glow_levels[k + 1], g.linear);
        gfx::uniforms(gfx::FRAGMENT, 0, render3d::glow_step_of(render3d::glow_level_size(size, k + 1), render3d::glow_level_size(size, k), false));
        gfx::draw(3);
        gfx::end_pass();
    }
}

// The haze in the sunbeam (render3d::haze_shown) added into the HDR target the pass resolved,
// before the glow: the beam's cross-section drawn into its atlas, then the haze worked out at
// the pre-pass's half size from its pre_place and added bilinear (Haze.half), or straight into
// the target. Its panes sent when they change; its targets made the first time and at the
// pre-pass's size.
fn haze_pass(own: Own&, g: render3d::Gpu&, size: int2) {
    let q = render3d::ssao_size_of(size);
    let half = render3d::haze.half;
    let b = render3d::haze_block(g, if half { q } else { size });
    if g.haze_panes.id == 0 {
        g.haze_panes = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(render3d::haze_panes));
        render3d::haze_sent = render3d::haze_panes;
    } else if render3d::haze_changed() {
        gfx::update_buffer(g.haze_panes, bytes_of(render3d::haze_panes));
    }
    if g.haze_cross.id == 0 { g.haze_cross = gfx::render_target(render3d::HAZE_CROSS_SIZE.x, render3d::HAZE_CROSS_SIZE.y, gfx::RGBA16F); }
    if half && (g.haze_image.id == 0 || g.haze_size.x != q.x || g.haze_size.y != q.y) {
        if g.haze_image.id != 0 {
            gfx::release(g.haze_image);
            gfx::flush();
        }
        g.haze_image = gfx::render_target(q.x, q.y, gfx::RGBA16F);
        g.haze_size = q;
    }
    let h .= g.hdr_pipes;
    var cross = gfx::PassDesc { clear_color: false };
    cross.color[0] = g.haze_cross;
    gfx::begin_pass(cross);
    gfx::bind(h.haze_cross);
    gfx::bind_texture(gfx::FRAGMENT, 0, render3d::tree_or_stand_in(g), g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, render3d::lace_or_stand_in(g), g.linear);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 0, g.haze_panes);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 1, b);
    gfx::draw(3);
    gfx::end_pass();
    let h .= g.hdr_pipes;
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = if half { g.haze_image } else { g.hdr_image };
    gfx::begin_pass(pass);
    gfx::bind(if half { h.haze } else { h.haze_full });
    gfx::bind_texture(gfx::FRAGMENT, 0, g.haze_cross, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.pre_place, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 1, b);
    gfx::draw(3);
    gfx::end_pass();
    guard half else { return; }
    var add = gfx::PassDesc { clear_color: false };
    add.color[0] = g.hdr_image;
    gfx::begin_pass(add);
    gfx::bind(h.haze_add);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.haze_image, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, render3d::HazeAdd { float4 { 1.0 / size.x, 1.0 / size.y, 0.0, 0.0 } });
    gfx::draw(3);
    gfx::end_pass();
}

// The depth of field's depth (render3d::depth_shown) at the pass's size, 1x and sampled: the
// board and the opaque pieces, the table, the room, and the lace by its coverage
// (shaders::LACE_DEPTH_FRAG); the view out is drawn into none, so it stays at the far plane.
// Its target and pipelines made the first time.
fn depth_pass(own: Own&, g: render3d::Gpu&) {
    if g.depth_room.id == 0 {
        let solid = gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true };
        let both = gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true };
        let room_vert = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::ROOM_VERT);
        g.depth_room = gfx::pipeline(room_vert, embed_shader("frag", shaders::EMPTY_FRAG), both);
        g.depth_table = gfx::pipeline(embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TABLE_VERT),
                                      embed_shader("frag", shaders::EMPTY_FRAG), solid);
        g.depth_lace = gfx::pipeline(room_vert, embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::LACE_DEPTH_FRAG), both);
        g.depth_show = gfx::pipeline(embed_shader("vert", shaders::FULL_VERT), embed_shader("frag", shaders::DEPTH_SHOW_FRAG));
    }
    if g.scene_depth.id == 0 {
        let deep = gfx_format_supported(gfx::DEPTH32F, gfx::DEPTH_TARGET | gfx::SAMPLED);
        g.scene_depth = gfx::texture2d(g.size.x, g.size.y, if deep { gfx::DEPTH32F } else { gfx::DEPTH16 },
                                       gfx::DEPTH_TARGET | gfx::SAMPLED);
    }
    let f = g.frame;
    gfx::begin_pass(gfx::PassDesc { depth: g.scene_depth });
    gfx::bind(g.depth_only);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::uniforms(gfx::VERTEX, 0, f);
    draw_meshes(own, g, 0.0);
    if render3d::table_shown(g) {
        gfx::bind(g.depth_table);
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::bind_vertex_buffer(g.table_vb);
        gfx::bind_index_buffer(g.table_ib, 4);
        gfx::draw_indexed(g.table_count);
    }
    gfx::bind(g.depth_room);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::bind_vertex_buffer(g.room_vb);
    gfx::bind_index_buffer(g.room_ib, 4);
    gfx::draw_indexed(g.room_count);
    if g.window_count > 0 {
        gfx::bind(g.depth_lace);
        gfx::bind_texture(gfx::FRAGMENT, 0, render3d::lace_or_stand_in(g), g.linear);
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 1, render3d::LaceDepth { render3d::surfaces_block(g).tile });
        gfx::bind_vertex_buffer(g.window_vb);
        gfx::bind_index_buffer(g.window_ib, 4);
        gfx::draw_indexed(g.window_count);
    }
    gfx::end_pass();
}

// The light tuner's view of the depth over all of `target` (shaders::DEPTH_SHOW_FRAG).
fn depth_show_pass(own: Own&, g: render3d::Gpu&, target: Texture, show: render3d::DepthShow) {
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = target;
    gfx::begin_pass(pass);
    gfx::bind(g.depth_show);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.scene_depth, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, show);
    gfx::draw(3);
    gfx::end_pass();
}

// The view out of the shell's windows (model3d::view_out), first in the pass in place of
// the photograph: one draw, the sky, then the band, then the oak, each over the last.
fn draw_outside(own: Own&, g: render3d::Gpu&, in_mirror: bool = false) {
    gfx::bind(if g.hdr && !in_mirror { g.hdr_pipes.outside } else { g.outside });
    gfx::bind_texture(gfx::FRAGMENT, 0, g.outside_band, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.outside_oak, g.linear);
    gfx::bind_texture(gfx::FRAGMENT, 2, render3d::tree_or_stand_in(g), g.linear);
    gfx::uniforms(gfx::VERTEX, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 1, render3d::outside_block(g, in_mirror));
    gfx::bind_vertex_buffer(g.outside_vb);
    gfx::bind_index_buffer(g.outside_ib, 4);
    gfx::draw_indexed(render3d::outside_drawn(g, in_mirror));
}

// The tree's pipelines (render3d::TreeGpu): its tubes' and ribbons', 8-bit and HDR, made
// outside a pass the first time the tree is grown, and again when the wind on it comes or
// goes (render3d::tree_wind: the standard tier's vertex stages with the shadow's field, the
// high tier's leaves fluttering too). The ribbons blend by their coverage (premultiplied),
// writing no depth.
fn make_tree(own: Own&, g: render3d::Gpu&) {
    let t .= g.tree;
    let mesh = render3d::leaf_mesh(false);
    let hdr_mesh = render3d::leaf_mesh(true);
    guard t.tube.id == 0 || t.wind_made != render3d::tree_wind || t.leaf_mesh_made != mesh || t.hdr_leaf_mesh_made != hdr_mesh
        else { return; }
    if t.tube.id != 0 {
        gfx::flush();
        for p in [t.tube, t.ribbon, t.hdr_tube, t.hdr_ribbon, t.leaf, t.hdr_leaf] { gfx::release(p); }
    }
    t.wind_made = render3d::tree_wind;
    t.leaf_mesh_made = mesh;
    t.hdr_leaf_mesh_made = hdr_mesh;
    let wind = render3d::tree_wind;
    let tube_vs = if wind {
        embed_shader("vert", shaders::TREE_WIND, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::WIND_FN, shaders::TREE_FN,
                     shaders::TREE_WOOD_VERT)
    } else {
        embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::TREE_FN, shaders::TREE_WOOD_VERT)
    };
    let ribbon_vs = if wind {
        embed_shader("vert", shaders::TREE_RIBBON, shaders::TREE_WIND, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::WIND_FN,
                     shaders::TREE_FN, shaders::TREE_WOOD_VERT)
    } else {
        embed_shader("vert", shaders::TREE_RIBBON, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::TREE_FN,
                     shaders::TREE_WOOD_VERT)
    };
    let solid = gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true };
    let flat = gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, blend: gfx::BLEND_PREMULTIPLIED };
    // The bark's tiers (shaders::TREE_BARK_STANDARD): the 8-bit pipeline the standard tier's,
    // the HDR one the high tier's.
    t.tube = gfx::pipeline(tube_vs, embed_shader("frag", shaders::TREE_BARK_STANDARD, shaders::FS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                                 shaders::TONE_FN, shaders::TREE_LIGHT_FN, shaders::TREE_WOOD_FRAG), solid);
    t.ribbon = gfx::pipeline(ribbon_vs, embed_shader("frag", shaders::TREE_RIBBON, shaders::FS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                                     shaders::TONE_FN, shaders::TREE_LIGHT_FN, shaders::TREE_WOOD_FRAG), flat);
    t.hdr_tube = gfx::pipeline(tube_vs, embed_shader("frag", shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                                     shaders::TONE_FN, shaders::TREE_LIGHT_FN, shaders::TREE_WOOD_FRAG), solid);
    t.hdr_ribbon = gfx::pipeline(ribbon_vs, embed_shader("frag", shaders::TREE_RIBBON, shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME,
                                                         shaders::TREE_HEAD, shaders::TONE_FN, shaders::TREE_LIGHT_FN,
                                                         shaders::TREE_WOOD_FRAG), flat);
    let leaf_vs = leaf_vertex_shader(mesh, wind, false);
    let hdr_leaf_vs = leaf_vertex_shader(hdr_mesh, wind, wind);
    // The leaves cut by alpha-to-coverage in a multisampled pass (shaders::TREE_COVERAGE).
    let card = gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true, alpha_to_coverage: true };
    t.leaf = gfx::pipeline(leaf_vs, embed_shader("frag", shaders::TREE_COVERAGE, shaders::FS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                                 shaders::TONE_FN, shaders::TREE_LIGHT_FN, shaders::TREE_LEAF_FRAG), card);
    t.hdr_leaf = gfx::pipeline(hdr_leaf_vs, embed_shader("frag", shaders::TREE_COVERAGE, shaders::HDR_OUT, shaders::FS_SET,
                                                         shaders::FRAME, shaders::TREE_HEAD, shaders::TONE_FN,
                                                         shaders::TREE_LIGHT_FN, shaders::TREE_LEAF_FRAG), card);
}

// The leaves' vertex stage for a mesh (render3d::leaf_mesh), still, in the wind, or
// fluttering too.
fn leaf_vertex_shader(mesh: i64, wind: bool, flutter: bool) -> const u8[:] {
    if mesh == render3d::LEAF_MESH_FAN {
        if flutter {
            return embed_shader("vert", shaders::TREE_LEAF_FAN, shaders::TREE_FLUTTER, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                shaders::WIND_FN, shaders::TREE_FN, shaders::TREE_LEAF_VERT);
        }
        if wind {
            return embed_shader("vert", shaders::TREE_LEAF_FAN, shaders::TREE_WIND, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                shaders::WIND_FN, shaders::TREE_FN, shaders::TREE_LEAF_VERT);
        }
        return embed_shader("vert", shaders::TREE_LEAF_FAN, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::TREE_FN,
                            shaders::TREE_LEAF_VERT);
    }
    if mesh == render3d::LEAF_MESH_ROWS {
        if flutter {
            return embed_shader("vert", shaders::TREE_LEAF_ROWS, shaders::TREE_FLUTTER, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                shaders::WIND_FN, shaders::TREE_FN, shaders::TREE_LEAF_VERT);
        }
        if wind {
            return embed_shader("vert", shaders::TREE_LEAF_ROWS, shaders::TREE_WIND, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                shaders::WIND_FN, shaders::TREE_FN, shaders::TREE_LEAF_VERT);
        }
        return embed_shader("vert", shaders::TREE_LEAF_ROWS, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::TREE_FN,
                            shaders::TREE_LEAF_VERT);
    }
    if flutter {
        return embed_shader("vert", shaders::TREE_FLUTTER, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::WIND_FN,
                            shaders::TREE_FN, shaders::TREE_LEAF_VERT);
    }
    if wind {
        return embed_shader("vert", shaders::TREE_WIND, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::WIND_FN, shaders::TREE_FN,
                            shaders::TREE_LEAF_VERT);
    }
    return embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::TREE_FN, shaders::TREE_LEAF_VERT);
}

// The tree outside in the board's pass, after the room's opaque groups (render3d::tree_drawn):
// its tubes, its leaves, then its ribbons (blended, so last).
fn draw_tree(own: Own&, g: render3d::Gpu&) {
    let t = g.tree;
    let tb = render3d::tree_block(g, own.samples);
    gfx::bind(if g.hdr { t.hdr_tube } else { t.tube });
    let bark_height, bark_cavity, bark_detail = render3d::tree_bark_textures(g);
    gfx::bind_texture(gfx::FRAGMENT, 0, bark_height, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 1, bark_cavity, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 2, bark_detail, g.aniso);
    gfx::uniforms(gfx::VERTEX, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::VERTEX, 1, tb);
    gfx::uniforms(gfx::FRAGMENT, 1, tb);
    gfx::bind_vertex_buffer(t.wood_vb);
    gfx::bind_index_buffer(t.wood_ib, 4);
    gfx::draw_indexed(t.tube_count);
    if t.leaf_count > 0 {
        gfx::bind(if g.hdr { t.hdr_leaf } else { t.leaf });
        gfx::bind_storage_buffer(gfx::VERTEX, 0, t.leaves);
        gfx::bind_texture(gfx::FRAGMENT, 0, t.leaf_shape, g.aniso);
        gfx::bind_texture(gfx::FRAGMENT, 1, t.leaf_marks, g.aniso);
        gfx::uniforms(gfx::VERTEX, 0, g.frame);
        gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
        gfx::uniforms(gfx::VERTEX, 1, tb);
        gfx::uniforms(gfx::FRAGMENT, 1, tb);
        gfx::draw_instanced(render3d::leaf_vertices(if g.hdr { t.hdr_leaf_mesh_made } else { t.leaf_mesh_made }), t.leaf_count);
    }
    gfx::bind(if g.hdr { t.hdr_ribbon } else { t.ribbon });
    gfx::uniforms(gfx::VERTEX, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::VERTEX, 1, tb);
    gfx::uniforms(gfx::FRAGMENT, 1, tb);
    gfx::bind_vertex_buffer(t.wood_vb);
    gfx::bind_index_buffer(t.wood_ib, 4);
    gfx::draw_indexed(t.ribbon_count, 1, t.ribbon_first, 0, 0);
}

// The tree's card (render3d::tree_card): the pipelines the first time, then the geometry,
// still, its light exposed with no toe (shaders::TREE_CARD), into a 4× multisampled RGBA16F
// target cleared to nothing, resolved into the card, whose mips follow; the multisampled
// targets given back after. Outside a pass, the frame's block `f` the card's.
fn tree_card_pass(own: Own&, g: render3d::Gpu&, f: render3d::Frame, b: render3d::TreeBlock) {
    let t .= g.tree;
    if t.card_tube.id == 0 {
        let tube_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::TREE_FN, shaders::TREE_WOOD_VERT);
        let ribbon_vs = embed_shader("vert", shaders::TREE_RIBBON, shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::TREE_FN,
                                     shaders::TREE_WOOD_VERT);
        let leaf_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TREE_HEAD, shaders::TREE_FN, shaders::TREE_LEAF_VERT);
        t.card_tube = gfx::pipeline(tube_vs, embed_shader("frag", shaders::TREE_CARD, shaders::FS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                                          shaders::TONE_FN, shaders::TREE_LIGHT_FN, shaders::TREE_WOOD_FRAG),
                                    gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true });
        t.card_ribbon = gfx::pipeline(ribbon_vs, embed_shader("frag", shaders::TREE_RIBBON, shaders::TREE_CARD, shaders::FS_SET, shaders::FRAME,
                                                              shaders::TREE_HEAD, shaders::TONE_FN, shaders::TREE_LIGHT_FN,
                                                              shaders::TREE_WOOD_FRAG),
                                      gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, blend: gfx::BLEND_PREMULTIPLIED });
        t.card_leaf = gfx::pipeline(leaf_vs, embed_shader("frag", shaders::TREE_CARD, shaders::FS_SET, shaders::FRAME, shaders::TREE_HEAD,
                                                          shaders::TONE_FN, shaders::TREE_LIGHT_FN, shaders::TREE_LEAF_FRAG),
                                    gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true });
        let card_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::CARD_VERT);
        let over = gfx::PipelineDesc { cull: gfx::CULL_NONE, blend: gfx::BLEND_PREMULTIPLIED };
        t.card_draw = gfx::pipeline(card_vs, embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::TONE_FN, shaders::CARD_FRAG), over);
        t.hdr_card_draw = gfx::pipeline(card_vs, embed_shader("frag", shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::TONE_FN,
                                                              shaders::CARD_FRAG), over);
    }
    let w = render3d::TREE_CARD_W;
    let h = render3d::TREE_CARD_H;
    if t.card.id == 0 {
        t.card = gfx::texture(gfx::TextureDesc { format: gfx::RGBA16F, usage: gfx::COLOR_TARGET | gfx::SAMPLED, width: w as i32,
                                                 height: h as i32, mips: trees::mips_of(w, h) as i32 });
    }
    let color = gfx::texture(gfx::TextureDesc { format: gfx::RGBA16F, usage: gfx::COLOR_TARGET, width: w as i32, height: h as i32,
                                                samples: SAMPLES });
    let depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET, width: w as i32, height: h as i32,
                                                samples: SAMPLES });
    var pass = gfx::PassDesc { depth: depth, color_value: float4_0 };
    pass.color[0] = color;
    pass.resolve[0] = t.card;
    gfx::begin_pass(pass);
    gfx::bind(t.card_tube);
    let bark_height, bark_cavity, bark_detail = render3d::tree_bark_textures(g);
    gfx::bind_texture(gfx::FRAGMENT, 0, bark_height, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 1, bark_cavity, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 2, bark_detail, g.aniso);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::uniforms(gfx::VERTEX, 1, b);
    gfx::uniforms(gfx::FRAGMENT, 1, b);
    gfx::bind_vertex_buffer(t.wood_vb);
    gfx::bind_index_buffer(t.wood_ib, 4);
    gfx::draw_indexed(t.tube_count);
    if t.leaf_count > 0 {
        gfx::bind(t.card_leaf);
        gfx::bind_storage_buffer(gfx::VERTEX, 0, t.leaves);
        gfx::bind_texture(gfx::FRAGMENT, 0, t.leaf_shape, g.aniso);
        gfx::bind_texture(gfx::FRAGMENT, 1, t.leaf_marks, g.aniso);
        gfx::uniforms(gfx::VERTEX, 0, f);
        gfx::uniforms(gfx::FRAGMENT, 0, f);
        gfx::uniforms(gfx::VERTEX, 1, b);
        gfx::uniforms(gfx::FRAGMENT, 1, b);
        gfx::draw_instanced(6, t.leaf_count);
    }
    gfx::bind(t.card_ribbon);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::uniforms(gfx::VERTEX, 1, b);
    gfx::uniforms(gfx::FRAGMENT, 1, b);
    gfx::bind_vertex_buffer(t.wood_vb);
    gfx::bind_index_buffer(t.wood_ib, 4);
    gfx::draw_indexed(t.ribbon_count, 1, t.ribbon_first, 0, 0);
    gfx::end_pass();
    gfx::generate_mips(t.card);
    gfx::release(color);
    gfx::release(depth);
}

// The tree's card in the view out's place, over it (render3d::tree_card_in_view,
// tree_card_in_mirror); the mirror's in its own light, as the view out there.
fn draw_tree_card(own: Own&, g: render3d::Gpu&, in_mirror: bool = false) {
    let t = g.tree;
    gfx::bind(if g.hdr && !in_mirror { t.hdr_card_draw } else { t.card_draw });
    gfx::bind_texture(gfx::FRAGMENT, 0, t.card, g.linear);
    gfx::uniforms(gfx::VERTEX, 0, g.frame);
    gfx::uniforms(gfx::VERTEX, 1, render3d::tree_card_block(g));
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 1, render3d::outside_block(g, in_mirror));
    gfx::draw(6);
}

// The dust in the sunbeam over the open pass's target, added, hidden by what stands
// in front of it.
fn draw_motes(own: Own&, g: render3d::Gpu&) {
    gfx::bind(if g.hdr { g.hdr_pipes.motes } else { g.motes });
    gfx::bind_texture(gfx::VERTEX, 0, render3d::tree_or_stand_in(g), g.linear);
    gfx::bind_texture(gfx::VERTEX, 1, render3d::lace_or_stand_in(g), g.linear);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.mote_seeds);
    gfx::uniforms(gfx::VERTEX, 0, g.frame);
    gfx::uniforms(gfx::VERTEX, 1, render3d::dust_block(g));
    gfx::draw_instanced(6, render3d::motes_drawn());
}

// The occlusion map's texels x0..x1, y0..y1 drawn again from the field's squares.
fn occ_pass(own: Own&, g: render3d::Gpu&, x0: i64, y0: i64, x1: i64, y1: i64) {
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
fn kept_pass(own: Own&, g: render3d::Gpu&) {
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = g.kept_backdrop;
    gfx::begin_pass(pass);
    draw_backdrop(own, g, 1.0);
    gfx::end_pass();
}

struct Draw { draw: float4 }

// The backdrop's draw: x how opaque, y the plain fade's brightness (0: the photograph);
// the fade's colors in linear light (shaders::FADE_FN).
struct Backdrop { draw: float4, fade_top: float4, fade_low: float4, fade_light: float4 }

struct Shrink { from: float4, to: float4 }  // shaders::SHRINK_FRAG's: source part in uv, target part in pixels

struct Pulse { pulse: float4, place: float4, more: float4 }

struct Show { from: float4, to: float4, screen: float4 }

struct Blur { dir: float4 }

let SAMPLES = 4;

// The pass's samples on a device whose 3D board can't keep up with its display
// (src/native/display.c).
let FEW_SAMPLES = 2;

// How the pass is antialiased (set_aa, the app's --aa and its A key): 4× multisampled,
// or drawn at 1x and SMAA 1x after it (smaa.goose), or neither. The values are the ngfx
// build's.
let AA_OFF = 0;

let AA_SMAA = 2;

let AA_MSAA = 4;

let AA = AA_MSAA;

// The pass's ways by the names --aa takes and the log prints (-1 for none), and the next
// the A key switches to: MSAA and SMAA in turn.
fn aa_named(own: Own&, name: const u8[:]) -> i32 {
    if name == "off" { return AA_OFF; }
    if name == "msaa" { return AA_MSAA; }
    if name == "smaa" { return AA_SMAA; }
    return -1;
}

fn aa_name(own: Own&, aa: i32) -> const u8[:] { if aa == AA_MSAA { "msaa" } else if aa == AA_SMAA { "smaa" } else { "off" } }

fn aa_next(own: Own&, aa: i32) -> i32 { if aa == AA_MSAA { AA_SMAA } else { AA_MSAA } }

// The view's matrices, as the ngfx build's render3d names its own.
type Mat = gfx::mat4;

// Part k of photograph(), each short enough for a frame (theme_step): 0 the photograph
// decoded or uploaded and shrunk, 1 blurred across, 2 blurred down, read back, and its
// harmonics taken into sh.
fn photo_part(own: Own&, g: render3d::Gpu&, kind: i64, grey: f32, sh: float4[9]&, k: i64) {
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
            gfx::begin_pass(g.photo, gfx::Texture { 0 }, float4 { 0.11, 0.078, 0.063, 1.0 });
            gfx::end_pass();
            for i in 9 { sh[i] = float4_0; }
            sh[0] = model3d::no_photo_ambient();
            return;
        }
        gfx::begin_pass(g.small, gfx::Texture { 0 }, float4_0);
        gfx::bind(g.shrink);
        gfx::bind_texture(gfx::FRAGMENT, 0, sharp, g.linear);
        gfx::uniforms(gfx::FRAGMENT, 0, Shrink { float4 { 0.0, 0.0, 1.0, 1.0 },
                                                float4 { 0.0, 0.0, render3d::PHOTO_SIZE, render3d::PHOTO_SIZE } });
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
fn bake(own: Own&, g: render3d::Gpu&, albedo: gfx::Texture, normal: gfx::Texture, w: i64, h: i64, mode: f32,
        extent: float2, t: looks::Theme&, y0: i64 = 0, y1: i64 = -1, mips: bool = true, fine: i64 = 0) {
    // Not cleared: the bake writes every texel, and a cleared target SDL finds still
    // referenced (as a new one is) it cycles into a second copy kept for good. Only rows
    // y0 to y1 when given (theme_step's bands), the mips after the last.
    let pipeline = bake_pipeline(g, mode);   // made before the pass: never inside one
    var pass = gfx::PassDesc { clear_color: false };
    pass.color[0] = albedo;
    pass.color[1] = normal;
    gfx::begin_pass(pass);
    if y1 >= 0 { gfx::scissor(0, y0, w, y1 - y0); }
    gfx::bind(pipeline);
    let fi = g.finish;
    // Samples a side a texel: a phone's half-size surface sampled as the full one, averaged.
    let fine = if fine > 0 { fine } else { model3d::BAKE_SIDE / w };
    let m = render3d::stone_of(g);
    gfx::uniforms(gfx::FRAGMENT, 0, render3d::Bake { float4 { mode, g.wood, g.n, render3d::marble_of(g) },
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
                                           t.fill, looks::LICHEN });
    gfx::draw(3);
    gfx::end_pass();
    guard mips else { return; }
    gfx::generate_mips(albedo);
    gfx::generate_mips(normal);
}

// The pass's target (multisampled, or SMAA's input and its edges and weights) and its
// depth at g.size, made for a draw after release_targets() gave them back.
fn pass_targets(own: Own&, g: render3d::Gpu&) {
    guard g.depth.id == 0 else { return; }
    if g.aa == AA_MSAA {
        g.color = gfx::texture(gfx::TextureDesc { format: if g.hdr { hdr_format(own) } else { gfx::RGBA8 }, usage: gfx::COLOR_TARGET,
                                                  width: g.size.x, height: g.size.y,
                                                  samples: own.samples });
        if g.hdr { g.hdr_image = gfx::render_target(g.size.x, g.size.y, hdr_format(own)); }
    } else if g.aa == AA_SMAA {
        g.color = gfx::render_target(g.size.x, g.size.y, gfx::RGBA8);
        if g.hdr { g.hdr_image = gfx::render_target(g.size.x, g.size.y, hdr_format(own)); }
        g.edges = gfx::render_target(g.size.x, g.size.y, gfx::RG8);
        g.weights = gfx::render_target(g.size.x, g.size.y, gfx::RGBA8);
    }
    // 16-bit depth is plenty between NEAR 2 and FAR 40 for a scene 10 to 20 away (a step
    // about 0.003 at 20, under the marks' 0.004 lift), at half of 32-bit's memory, which
    // SDL can't keep in tile memory.
    g.depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET,
                                              width: g.size.x, height: g.size.y,
                                              samples: own.samples });
}

// The pass antialiased by `aa` (AA_MSAA..) from the next draw on, MSAA at `samples`:
// its targets given back (made again for the new way by the next draw), SMAA's pipelines
// and tables made the first time it is chosen. The app calls it after setup(), on its A
// key, and for fewer samples.
fn set_aa(own: Own&, g: render3d::Gpu&, aa: i32, samples: i32 = SAMPLES) {
    render3d::give_back(own, g);
    g.aa = aa;
    own.samples = if aa == AA_MSAA { samples } else { 1 };
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

// The lit shader with its shadow filtered as `look` says (SHADOW_9..; shaders::SHADOW_FEW,
// SHADOW_MANY) and the pieces in one material (render3d::PIECES_..).
fn lit_frag(look: i32, pieces: i32) -> const u8[:] {
    if look == render3d::SHADOW_4 {
        if pieces == render3d::PIECES_WOOD { return embed_shader("frag", shaders::PIECES_WOOD, shaders::SHADOW_FEW, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
        if pieces == render3d::PIECES_WINTER { return embed_shader("frag", shaders::PIECES_WINTER, shaders::SHADOW_FEW, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
        if pieces == render3d::PIECES_MINERAL { return embed_shader("frag", shaders::PIECES_MINERAL, shaders::SHADOW_FEW, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
        return embed_shader("frag", shaders::SHADOW_FEW, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG);
    }
    if look == render3d::SHADOW_16 {
        if pieces == render3d::PIECES_WOOD { return embed_shader("frag", shaders::PIECES_WOOD, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
        if pieces == render3d::PIECES_WINTER { return embed_shader("frag", shaders::PIECES_WINTER, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
        if pieces == render3d::PIECES_MINERAL { return embed_shader("frag", shaders::PIECES_MINERAL, shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
        return embed_shader("frag", shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG);
    }
    if pieces == render3d::PIECES_WOOD { return embed_shader("frag", shaders::PIECES_WOOD, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    if pieces == render3d::PIECES_WINTER { return embed_shader("frag", shaders::PIECES_WINTER, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    if pieces == render3d::PIECES_MINERAL { return embed_shader("frag", shaders::PIECES_MINERAL, shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG); }
    return embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::LIT_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::LIT_FRAG);
}

// The light tuner's own fragment shaders (with shaders::TOE_FN, its toe switches),
// embedded by the tuner alone, in place of the app's: the lit one for SHADOW_16 in each
// pieces' material (TUNED_LIT + render3d::PIECES_..), the table's for SHADOW_16, the
// table's in the room, the room's groups with the screen's maps (the floor seeing the
// room's box, then the mirror, the walls, the metals, the glass), the view out, the painted
// wood, and the painted wood with the tuner's switches (render3d::paint_steps_on,
// shaders::PAINT_STEPS) whether the toes are switched or not; the sills, and the sills with
// the tuner's switches (render3d::sill_steps_on, shaders::SILL_STEPS) in the room and in
// the mirror. Empty, the app's. The mirror's pass takes none but the sills' switched one:
// its light is linear, before any toe. The HDR target's painted wood and sills with the
// tuner's switches (render3d::make_hdr), then the HDR target's view out (the park on the
// ground, render3d::park_ground), then the lace.
let TUNED_LIT = 0;
let TUNED_TABLE = 4;
let TUNED_TABLE_ROOM = 5;
let TUNED_FLOOR = 6;
let TUNED_PLANAR = 7;
let TUNED_WALLS = 8;
let TUNED_METALS = 9;
let TUNED_GLASS = 10;
let TUNED_OUTSIDE = 11;
let TUNED_PAINT = 12;
let TUNED_PAINT_STEPS = 13;
let TUNED_SILL = 14;
let TUNED_SILL_STEPS = 15;
let TUNED_SILL_MIRROR = 16;
let TUNED_PAINT_HDR = 17;
let TUNED_SILL_HDR = 18;
let TUNED_OUTSIDE_HDR = 19;
let TUNED_LACE = 20;
let TUNED_FRAGS = 21;
var tuned_frags: const u8[:][TUNED_FRAGS] = ["", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", "", ""];
fn tuned_or(i: i64, frag: const u8[:]) -> const u8[:] { if tuned_frags[i].len > 0 { tuned_frags[i] } else { frag } }

// The table's shader with its shadow filtered as `look` says, as the lit one's (lit_frag).
fn table_frag(look: i32) -> const u8[:] {
    if look == render3d::SHADOW_4 {
        return embed_shader("frag", shaders::SHADOW_FEW, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::TABLE_FRAG);
    }
    if look == render3d::SHADOW_16 {
        return embed_shader("frag", shaders::SHADOW_MANY, shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::TABLE_FRAG);
    }
    return embed_shader("frag", shaders::FS_SET, shaders::FRAME, shaders::TABLE_HEAD, shaders::SHADOW_FN, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TABLE_MAP_FN, shaders::TABLE_FRAG);
}

// The table's pipeline, its shadow filtered as `look` says (table_frag).
fn table_pipeline(own: Own&, g: render3d::Gpu&, look: i32) {
    let frag = if look == render3d::SHADOW_16 { tuned_or(TUNED_TABLE, table_frag(look)) } else { table_frag(look) };
    g.table_lit = gfx::pipeline(embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::TABLE_VERT), frag,
                                gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true,
                                                    blend: gfx::BLEND_PREMULTIPLIED });
}

// The lit pass's pipelines, the board's and a fading piece's, their shadow filtered as
// `look` says and the pieces as g.pieces has them (lit_frag).
fn lit_pipelines(own: Own&, g: render3d::Gpu&, look: i32) {
    let lit_vs = embed_shader("vert", shaders::VS_SET, shaders::FRAME, shaders::LIT_VERT);
    let lit_fs = if look == render3d::SHADOW_16 { tuned_or(TUNED_LIT + g.pieces, lit_frag(look, g.pieces)) } else { lit_frag(look, g.pieces) };
    g.lit = gfx::pipeline(lit_vs, lit_fs, gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true, depth_write: true });
    g.fading = gfx::pipeline(lit_vs, lit_fs, gfx::PipelineDesc { cull: gfx::CULL_BACK, depth_test: true,
                                                                 blend: gfx::BLEND_ALPHA });
    g.shadow_look = look;
}

// The shadow filtered as `look` says (SHADOW_9..) from the next draw on: the lit and table
// pipelines made again if it changes, the board drawn again by the caller. Never in the
// frame loop's steady state: only when the screen turns from a phone's to a larger one.
fn set_shadow(own: Own&, g: render3d::Gpu&, look: i32) {
    guard g.lit.id != 0 && look != g.shadow_look else { return; }
    gfx::flush();
    gfx::release(g.lit);
    gfx::release(g.fading);
    gfx::release(g.table_lit);
    lit_pipelines(own, g, look);
    table_pipeline(own, g, look);
}

// The pieces' material (render3d::PIECES_..) from the next draw on: the lit pipelines
// made again if it changes, marked pieces_unwarmed for the caller to warm.
fn set_pieces(own: Own&, g: render3d::Gpu&, pieces: i32) {
    guard pieces != g.pieces else { return; }
    g.pieces = pieces;
    guard g.lit.id != 0 else { return; }
    gfx::flush();
    gfx::release(g.lit);
    gfx::release(g.fading);
    lit_pipelines(own, g, g.shadow_look);
    g.pieces_unwarmed = true;
}

// The bake's pipeline for a surface (render3d::bake_kind), made the first time it is wanted.
fn bake_pipeline(g: render3d::Gpu&, mode: f32) -> gfx::Pipeline {
    let kind = render3d::bake_kind(g, mode);
    if kind == render3d::BAKE_ROOM { return g.bake_room; }
    if kind == render3d::BAKE_TABLE {
        if g.bake_table.id == 0 {
            g.bake_table = gfx::pipeline(embed_shader("vert", shaders::FULL_VERT), embed_shader("frag", shaders::BAKE_TABLE, shaders::BAKE_FRAG));
        }
        return g.bake_table;
    }
    if kind == render3d::BAKE_SLAB {
        if g.bake_slab.id == 0 {
            g.bake_slab = gfx::pipeline(embed_shader("vert", shaders::FULL_VERT), embed_shader("frag", shaders::BAKE_SLAB, shaders::BAKE_FRAG));
        }
        return g.bake_slab;
    }
    return g.bake;
}

struct Metrics { m: float4 }

// SMAA's three passes over g.color into `target`, at g.size: the edges, their blending
// weights, and the neighbours blended (smaa.goose). Recording only.
fn antialias(own: Own&, g: render3d::Gpu&, target: gfx::Texture) {
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
// `samples` 4 is the multisampled pass; 1 draws straight into the target.
// `look` how the shadow is filtered (SHADOW_9..; set_shadow).
fn setup(own: Own&, g: render3d::Gpu&, samples: i32 = SAMPLES, look: i32 = render3d::SHADOW_9) {
    own.samples = samples;
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
    g.table_spec = tables::get(tables::BOARD_WOOD);
    g.table_vb = gfx::Buffer { 0 };

    var empty:      float4[render3d::SQUARES]        = [float4_0; render3d::SQUARES];
    var none:       float4[render3d::SQUARES]        = [float4 { 0.0, 0.0, 0.0, -1.0 }; render3d::SQUARES];
    var no_squares: float4[render3d::SQUARE_ENTRIES] = [float4_0; render3d::SQUARE_ENTRIES];
    g.instances = gfx::buffer(gfx::BUFFER_STORAGE, render3d::MAX_INSTANCES * 32, bytes_of(empty[..2]));
    g.instance_count = 0;
    g.squares = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(no_squares));
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
    g.side = 0;         // the plan and the frame map made by apply(), at its side and as the look's frame wants
    g.frame_rows = 0;
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
    lit_pipelines(own, g, look);
    table_pipeline(own, g, look);
    // Both faces into the shadow map: with back faces culled the light leaks through where
    // a piece's top curves away from it, its front faces meeting almost end-on.
    g.shadow = gfx::pipeline(lit_vs, embed_shader("frag", shaders::EMPTY_FRAG),
                             gfx::PipelineDesc { cull: gfx::CULL_NONE, depth_test: true, depth_write: true,
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
fn draw_depth(own: Own&, g: render3d::Gpu&) {
    if g.kept_depth.id == 0 { g.kept_depth = depth_target(g.size); }
    gfx::begin_pass(gfx::PassDesc { depth: g.kept_depth });
    gfx::bind(g.depth_only);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::uniforms(gfx::VERTEX, 0, g.frame);
    draw_meshes(own, g, 0.0);
    gfx::end_pass();
}

// The pulsing marks (shaders::MARKS_FRAG with PULSE) over the open pass's target of
// `size`, where show() laid the kept image: drawn with it (draw() with keep_depth) into
// its rect `to` (as show()'s, the whole image), as opaque as `alpha`. `pulse` their
// phases (view3d::Scene.pulse), `next` how lit a capture's next stops are (Scene.next),
// `cursor` the keys' cursor's square in the world's grid, or -1 (Scene.cursor).
// The field's marks are the ones place() gave the image.
fn marks_over(own: Own&, g: render3d::Gpu&, pulse: float4, next: f32, cursor: f32, to: float4, alpha: f32, size: int2) {
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
fn draw_meshes(own: Own&, g: render3d::Gpu&, light: f32) {
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
fn draw_backdrop(own: Own&, g: render3d::Gpu&, alpha: f32) {
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
fn backdrop(own: Own&, g: render3d::Gpu&, alpha: f32, size: int2) {
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    guard render3d::kept_current(g, size) else {
        draw_backdrop(own, g, alpha);
        return;
    }
    gfx::bind(g.kept);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.kept_backdrop, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, Draw { float4 { alpha, 0.0, 0.0, 0.0 } });
    gfx::draw(3);
}

// Draws the kept image (draw() into g.image with its backdrop) over the open pass's
// target as it is.
fn copy(own: Own&, g: render3d::Gpu&) {
    gfx::bind(g.copy);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.image, g.linear);
    gfx::draw(3);
}

// Draws the kept image (draw() into g.image without the backdrop) over the open pass's
// target of `size`: its rect `from` into the rect `to`, both x, y, width, height in
// pixels, at opacity `alpha`, `grey` of the way to grey and dimmer (shaders::SHOW_FRAG).
// The same rect is the image as drawn, texel for texel.
fn show(own: Own&, g: render3d::Gpu&, from: float4, to: float4, alpha: f32, size: int2, grey: f32 = 0.0) {
    gfx::bind(g.show);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.image, g.linear);
    let u = Show { from: from, to: to, screen: float4 { size.x, size.y, alpha, grey } };
    gfx::uniforms(gfx::VERTEX, 0, u);
    gfx::uniforms(gfx::FRAGMENT, 0, u);
    gfx::draw(6);
}

fn warm(own: Own&, g: render3d::Gpu&, k: i64) {
    if k == 0 {
        g.warm_color = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8, usage: gfx::COLOR_TARGET, width: 4,
                                                       height: 4, samples: own.samples });
        g.warm_depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH16, usage: gfx::DEPTH_TARGET, width: 4,
                                                       height: 4, samples: own.samples });
        own.warm_kept = depth_target(int2 { 4, 4 });
    }
    var pass = gfx::PassDesc {};
    if k < 4 || k == render3d::WARM_STEPS - 1 {
        pass.color[0] = g.warm_color;
        pass.depth = g.warm_depth;
    } else if k == 4 {
        pass.depth = g.shadow_map;
    } else if k == 5 {
        pass.depth = own.warm_kept;
    } else if k == 9 {
        pass.color[0] = g.occ_map;
        pass.clear_color = false;
    } else {
        pass.color[0] = gfx::screen();
        pass.clear_color = false;
    }
    gfx::begin_pass(pass);
    let p = [g.lit, g.fading, g.catcher, g.glow, g.shadow, g.depth_only, g.backdrop, g.show, g.pulse, g.occ,
             g.kept, g.table_lit][k];
    // The table's only with a table: turning one on warms them again (draw3d).
    if k != render3d::WARM_STEPS - 1 || g.table { gfx::bind(p); }
    gfx::end_pass();
    if k == render3d::WARM_STEPS - 1 {
        gfx::release(g.warm_color);
        gfx::release(g.warm_depth);
        gfx::release(own.warm_kept);
        g.warm_color = gfx::Texture { 0 };
        g.warm_depth = gfx::Texture { 0 };
        own.warm_kept = gfx::Texture { 0 };
    }
}

// Everything setup() and the frames made given back (the app's board back to flat): the
// targets, surfaces, buffers, samplers, and pipelines. g is set up again from scratch.
fn release(own: Own&, g: render3d::Gpu&) {
    let textures = [g.plan_albedo, g.plan_normal, g.frame_albedo, g.frame_normal, g.table_albedo, g.table_normal, g.table_wear, g.table_wear_n, g.photo, g.shadow_map, g.occ_map, g.crown_map, g.tree_map, g.color,
                    g.depth, g.image, g.kept_backdrop, g.kept_depth, g.small, g.across, g.warm_color, g.warm_depth,
                    own.warm_kept, g.edges, g.weights, g.area, g.search, g.floor_albedo, g.floor_normal, g.floor_noise, g.scratch_tile, g.wall_albedo,
                    g.wall_normal, g.paper_mask, g.plaster_tone, g.lace_mask, g.outside_band, g.outside_oak, g.light_volume, g.bloom_a, g.bloom_b, g.book_atlas, g.rug_map, g.tapestry_map, g.stove_relief, g.corner_map,
                    g.table_map, g.pre_place, g.pre_facing, g.pre_depth, g.ssao_raw, g.ssao_map, g.planar_color,
                    g.planar_depth, g.planar_map, g.scene_image];
    for t in textures { if t.id != 0 { gfx::release(t); } }
    let buffers = [g.board_vb, g.board_ib, g.piece_vb, g.piece_ib, g.table_vb, g.table_ib, g.instances, g.squares, g.marks,
                   g.glows, g.mote_seeds, g.room_vb, g.room_ib, g.window_vb, g.window_ib, g.outside_vb, g.outside_ib, g.haze_panes, g.props_open];
    for b in buffers { if b.id != 0 { gfx::release(b); } }
    let samplers = [g.linear, g.aniso, g.oak_sampler, g.compare, g.planar_sampler];
    for s in samplers { if s.id != 0 { gfx::release(s); } }
    let pipelines = [g.lit, g.fading, g.shadow, g.backdrop, g.catcher, g.glow, g.pulse, g.depth_only, g.copy, g.show,
                     g.occ, g.kept, g.bake, g.bake_slab, g.bake_table, g.shrink, g.blur, g.smaa_edges, g.smaa_weights, g.smaa_blend, g.table_lit, g.table_room, g.motes, g.room_floor, g.room_walls, g.room_metals, g.bake_room, g.room_glass, g.room_lace, g.outside, g.bloom_pick, g.bloom_blur, g.bloom_add,
                     g.pre_room, g.pre_table, g.pre_lit, g.ssao, g.ssao_blur, g.gtao, g.room_planar, g.planar_walls, g.planar_metals, g.planar_glass, g.planar_lace, g.planar_table,
                     g.planar_resolve, g.planar_show, g.planar_mip, g.upscale, g.upscale_cubic];
    for p in pipelines { if p.id != 0 { gfx::release(p); } }
    release_hdr(own, g);
    for p in [g.depth_room, g.depth_table, g.depth_lace, g.depth_show, g.lit_shell, g.fading_shell, g.window_map_bake] { if p.id != 0 { gfx::release(p); } }
    if g.window_map.id != 0 { gfx::release(g.window_map); }
    for t in [g.hdr_image, g.scene_depth] { if t.id != 0 { gfx::release(t); } }
    for t in g.glow_levels { if t.id != 0 { gfx::release(t); } }
    for b in [g.tree.wood_vb, g.tree.wood_ib, g.tree.leaves] { if b.id != 0 { gfx::release(b); } }
    for p in [g.tree.tube, g.tree.ribbon, g.tree.hdr_tube, g.tree.hdr_ribbon, g.tree.leaf, g.tree.hdr_leaf, g.tree.card_tube,
              g.tree.card_ribbon, g.tree.card_leaf, g.tree.card_draw, g.tree.hdr_card_draw] {
        if p.id != 0 { gfx::release(p); }
    }
    gfx::flush();
    g = default<render3d::Gpu>();
}
