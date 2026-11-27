// The 3D board's renderer, for the app (src/app/draw3d.goose) and tools/board_shot: what
// it draws and when (the state, a theme's steps, what is stale, each frame's order).
// Recording goes through `o`, the renderer's own state: render3d::Own with
// render3d_gpu.goose on gfx, or render3d_ngfx::Own (src/ngfx/render3d_ngfx.goose); each
// recording function is generic over o's type.
//
// A frame: the shadow map only when the pieces moved, then one pass (the backdrop, the
// pieces and the board lit front to back, the board's soft shadow, the still marks). The
// pulsing marks are drawn over the kept image each frame (marks_over) against a kept 1x
// depth. Nothing is made or released while drawing but targets on a resize or after
// release_targets().
namespace render3d;
import std;
import vec;
import math;
import .render3d_gpu;

import model3d from "../model3d";

// Laid out as the shaders' blocks (shaders::FRAME), std140: all vec4s and mat4s, each
// a multiple of 16 bytes, so the two match field for field when their sizes do
// (frame_matches, checked as a theme is put on).
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
    frame_wax:       float4,
    light_scatter:   float4,
    dark_scatter:    float4,
    piece_wear:      float4,
    room:            float4,
    window:          float4,
    panes:           float4,
    opening:         float4,
    leaves:          float4,
    twigs:           float4,
    wind:            float4,
    tree:            float4,
    tree_blur:       float4,
    wind_now:        float4,
    tree_shift:      float4[4],
    branches:        float4,
    gust_reach:      float4,
    disc_n:          float4,
    disc_bounds:     float4,
    discs:           float4[MAX_DISCS],
    room_axes:       float4,
    toe:             float4,
}

// The bytes of the uniform block `name` in GLSL `text` of vec4s and mat4s alone, std140,
// or -1 for any other member, which Frame's layout doesn't follow.
fn block_size(text: const u8[:], name: const u8[:]) -> i64 {
    let head = str("uniform ", name, " {");
    var rest: const u8[:] = text;
    var inside = false;
    var size = 0;
    while rest.len > 0 {
        let line, after, more = split_once(rest, "\n");
        rest = if more { after } else { "" };
        let t = trim(line);
        if !inside {
            inside = t.len >= head.len && t[t.len - head.len..] == head[..];
            continue;
        }
        if t.len >= 2 && t[..2] == "};" { return size; }
        guard t.len > 0 && !(t.len >= 2 && t[..2] == "//") else { continue; }
        let kind, member, spaced = split_once(t, " ");
        guard spaced else { return -1; }
        let bytes = if kind == "vec4" { 16 } else if kind == "mat4" { 64 } else { -1 };
        guard bytes > 0 else { return -1; }
        // An array's count, `sh[9];`.
        var count = 1;
        let before, tail, arrayed = split_once(member, "[");
        if arrayed {
            let digits, closing, closed = split_once(tail, "]");
            let n, ok = parse_int(digits);
            guard closed && ok else { return -1; }
            count = n;
        }
        size += bytes * count;
    }
    return -1;
}

// Whether Frame is as large as shaders::FRAME's block: a field added to one and not the
// other shifts every field after it, which nothing else would catch.
fn frame_matches(g: Gpu&) -> bool {
    let one: Frame[1] = [g.frame];
    return bytes_of(one[..]).len == block_size(shaders::FRAME, "Frame");
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
    carve_more:    float4,  // looks::Carving: motif, amber, lichen, the folk band's pattern
    fill:          float4,  // looks::Theme.fill
    lichen:        float4,  // looks::LICHEN
}

// The shadow map's side: the lit shader's filter spreads over 5 of its texels.
let SHADOW_SIZE = 1024;

// How the lit shader filters the key light's shadow (set_shadow): 9 hardware-compared
// taps over 5 × 5 texels, a tablet's; 16 over 7 × 7, softer, a desktop's; 4 over 3 × 3,
// a phone's.
let SHADOW_9 = 0;
let SHADOW_16 = 1;
let SHADOW_4 = 2;
let SHADOW_LOOKS = 3;
fn shadow_look_name(look: i32) -> const u8[:] {
    if look == SHADOW_16 { "16" } else if look == SHADOW_4 { "4" } else { "9" }
}

// The pieces' material the lit shader is compiled for (set_pieces), from the look's
// mineral: classic, turned wood, winter's stones, or a mineral. Each is a pipeline of
// its own, as a phone compiles every branch a shader has.
let PIECES_CLASSIC = 0;
let PIECES_WOOD = 1;
let PIECES_WINTER = 2;
let PIECES_MINERAL = 3;
fn pieces_kind(mineral: f32) -> i32 {
    if mineral == looks::MINERAL_WINTER_SLATE || mineral == looks::MINERAL_WINTER_MARBLE { PIECES_WINTER }
    else if mineral == looks::MINERAL_TURNED_WOOD { PIECES_WOOD }
    else if mineral >= looks::MINERAL_GRANULAR { PIECES_MINERAL } else { PIECES_CLASSIC }
}

// The bake's pipeline for a surface (mode: 0 the plan, 1 the frame map, 2 and 3 the
// table, 4 and 5 the room's oak): the room's, the table's own, the black marble slab's,
// or the rest of the board's.
let BAKE_BOARD = 0;
let BAKE_SLAB = 1;
let BAKE_TABLE = 2;
let BAKE_ROOM = 3;
fn bake_kind(g: Gpu&, mode: f32) -> i32 {
    let m = marble_of(g);
    if mode > 3.5 { BAKE_ROOM } else if mode > 1.5 { BAKE_TABLE } else if looks::is_slab(m) { BAKE_SLAB } else { BAKE_BOARD }
}

let PHOTO_SIZE = 512;

// The pieces' occlusion of the field (shaders::OCC_FRAG), over the plan's extent: 62
// texels a square on 8 × 8, for a falloff a piece's radius wide that rises steeply at
// its foot.
let OCC_SIZE = 512;

// The crown's map (shaders::CROWN_FRAG): 256 texels over 1.2 of the piece's radius, a
// texel 0.7 px on a piece 140 px across.
let CROWN_SIZE = 256;

let MAX_INSTANCES = 96;     // view3d::MAX_INSTANCES: two for each of board::MAX_PIECES

let SQUARES = 100;          // the field's squares, 10 × 10 at most
let SQUARE_ENTRIES = 2 * SQUARES;   // the occlusion's two float4s a square (place's `squares`)

// Everything on the GPU, made by setup() (the targets again on a resize).
struct Gpu {
    wood:           i64,             // the wood's model the surfaces are baked with
    finish:         looks::Finish,   // and its finish
    marble:         i64,             // the stone frame's marble (looks::MARBLE..), 0 slate
    stone:          looks::Marble,   // and its look
    spring:         i64,             // spring's look (looks::SPRING_LOOK..), 1 the carved
    carving:        looks::Carving,  // and the carving of a carved look shown,
    carved:         i64,             // the look it is the carving of (looks::shown), -1 none yet
    n:              i64,             // squares per side the plan is baked for
    look:           i64,             // looks::AUTUMN.., and the photograph's kind
    photo_kind:     i64,
    board_vb:       Buffer,
    board_ib:       Buffer,
    board_count:    i64,
    piece_vb:       Buffer,
    piece_ib:       Buffer,
    piece_count:    i64,
    instances:      Buffer,
    instance_count: i64,
    solid:          i64,                    // the instances drawn opaque, first; the rest fade
    alphas:         f32[MAX_INSTANCES],     // how opaque each fading one is
    squares:        Buffer,
    crown_map:      Texture,           // the crown's distance (shaders::CROWN_FRAG), drawn at setup
    occ_map:        Texture,           // the pieces' occlusion of the field (occlusion())
    occ_n:          i64,                     // the squares a side it was drawn for, 0 none yet
    occ_squares:    float4[SQUARE_ENTRIES],  // the squares it was drawn from
    squares_now:    float4[SQUARE_ENTRIES],  // and the ones place() last gave
    marks:          Buffer,
    glows:          Buffer,      // the field's glow rings and lit squares
    marked:         bool,             // whether the board's pass has marks to draw
    plan_albedo:    Texture,
    plan_normal:    Texture,
    side:           i64,            // the surfaces' side they are made at (model3d::BAKE_SIDE..), 0 none yet
    want_side:      i64,            // and the one set_bake() asks for, 0 BAKE_SIDE
    frame_albedo:   Texture,
    frame_normal:   Texture,
    frame_rows:     i64,            // the frame map's rows: `side`, or the mitred bands'
    frame_flat:     bool,           // frame_normal is flat_frame()'s 4 × 4, not the map's
    table:          bool,           // the table under the board (set_table), its map baked
    classic:        bool,            // settings' Classic pieces (looks::classic), put on by theme_end
    table_albedo:   Texture,        // with the theme's surfaces, at model3d::table_size
    table_normal:   Texture,
    table_wear:     Texture,        // its wear's tile, at model3d::wear_side (wear_at)
    table_wear_n:   Texture,
    table_side:     i64,            // the side its maps are made at, 0 none
    table_baked:    bool,           // its maps hold table_spec's wood
    table_spec:     tables::Table,  // the table shown (tables::BOARD_WOOD.., or as tuned)
    room:           rooms::Room,    // the room's light on the table (rooms::of, or as tuned)
    room_tuned:     bool,           // room set by a tuner, not taken from the season
    tree_map:       Texture,        // the tree's shadow (trees::draw_map), made with the first bake
    tree_for:       float4[11],     // what it was baked from (tree_key())
    tree_w:         i64,            // its texels across and up
    tree_h:         i64,
    tree_stale:     bool,           // to bake again before the next draw
    tree_ms:        f64,            // the last bake's time (measuring)
    tree_bakes:     i64,            // how many times the tree's map was baked (window_map_key)
    table_edge:     float4,         // the edge its mesh is made with (tables::Table.edge)
    // The table turned about its axis under the board (degrees; a tuner's, the room's
    // table only): its mesh, and its top's figure in TABLE_ROOM's shader (TableBlock's
    // shape.zw). 0 the game's.
    table_turn:      f32,
    table_made_turn: f32,
    table_vb:        Buffer,
    table_ib:        Buffer,
    table_count:     i64,
    // The two chairs at the table (mesh::chairs) in its mesh: wanted (a tuner's, where the
    // room shows; the game never), and as made, with the rug under their feet or not.
    chairs:          bool,
    chairs_made:     bool,
    chairs_rug_made: bool,
    // The props' baked occlusion (props_light): one float4 a vertex of the table's mesh, its
    // open direction and open part (model3d::prop_occlusion), TABLE_VERT's storage buffer
    // with shaders::PROPS_LIGHT; whether it holds the mesh as made, and the bake's time.
    props_open:  Buffer,
    props_baked: bool,
    props_ms:    f64,
    table_lit:   Pipeline,
    table_room:  Pipeline,
    // The table's own shadow in the room (table_map): its map, what it was drawn for
    // (table_map_key()), and the rows that place a point in it (table_map_rows()).
    table_map:       Texture,
    table_map_for:   float4[2],
    table_map_place: float4[4],
    photo:           Texture,
    shadow_map:      Texture,
    aa:              i32,           // AA_OFF.. (set_aa), the renderer's ways
    color:           Texture,  // the pass's target (antialiasing's input) and its depth
    edges:           Texture,  // SMAA's edges and blending weights, at the pass's size
    weights:         Texture,
    area:            Texture,  // SMAA's tables (third_party/smaa), made by set_aa
    search:          Texture,
    smaa_edges:      Pipeline,
    smaa_weights:    Pipeline,
    smaa_blend:      Pipeline,
    depth:           Texture,
    image:           Texture,  // what draw() resolves into when asked to keep it
    kept_backdrop:   Texture,  // the backdrop at full opacity, g.size (keep_backdrop())
    kept_for:        float4[7],     // what it was drawn from (backdrop_key())
    live:            bool,          // the app's --keep off: the backdrop drawn each frame, never kept
    photo_gen:       i64,           // counts photo_part()'s steps, each of which may change g.photo
    kept_depth:      Texture,  // its depth at 1x, for the pulsing marks (marks_over)
    warm_color:      Texture,  // 4 × 4 targets warm() makes the pipelines on
    warm_depth:      Texture,
    no_photo:        bool,          // no photograph built in for the theme (photo_part), or plain
    plain:           bool,          // the plain fade behind, set before a theme's steps
    fade:            float4[3],     // its colors (app/theme.goose's fade_top, low, light), linear
    size:            int2,
    linear:          Sampler,
    aniso:           Sampler,
    compare:         Sampler,
    lit:             Pipeline,
    fading:          Pipeline, // the lit pass for a fading piece, blended
    // The two in the room's shell (shaders::LIT_SHELL; make_lit_shell): the sun through its
    // own windows, made when the shell first shows, for the pieces they were made for.
    lit_shell:       Pipeline,
    fading_shell:    Pipeline,
    shell_pieces:    i32,
    shadow:          Pipeline,
    shadow_look:     i32,           // SHADOW_9.., how lit and fading filter the shadow (set_shadow)
    pieces:          i32,           // PIECES_.., the pieces' material lit and fading draw (set_pieces)
    pieces_unwarmed: bool,                    // lit and fading made again for new pieces, not yet warmed
    backdrop:        Pipeline,
    catcher:         Pipeline,
    glow:            Pipeline,
    pulse:           Pipeline, // the pulsing marks over the kept image (marks_over)
    depth_only:      Pipeline, // the kept depth
    copy:            Pipeline,
    show:            Pipeline, // the kept image over what is there, anywhere (show())
    occ:             Pipeline, // the field's occlusion map (occlusion())
    kept:            Pipeline, // the kept backdrop laid on the screen (backdrop())
    bake:            Pipeline, // kept for a theme's rebake, with the photograph's
    bake_slab:       Pipeline, // the bake with the black marble slab, made when first wanted
    bake_table:      Pipeline, // the table's bake, made when first wanted
    shrink:          Pipeline,
    blur:            Pipeline,
    small:           Texture,
    across:          Texture,
    frame:           Frame,
    shadow_dirty:    bool,
    turn:            f32,           // the board's turn (view3d::View.turn), the light turned with it
    bake_ms:         f64,           // the last bake's time and the photograph's (measuring)
    photo_ms:        f64,
    motes:           Pipeline,      // the dust in the sunbeam (draw_motes), made when first wanted
    mote_seeds:      Buffer,        // and each mote's seed (mote_seeds()), filled once
    // The library round the table (room_shell::LIBRARY, the tuner's for now): shown or not,
    // its oak's two fields baked once (the floor's and the wall's, albedo and roughness, the
    // normal), its mesh made for the room's frame.
    room_on:      bool,
    room_side:    i64,              // the fields' side they are made at, 0 none
    room_baked:   bool,
    room_ms:      f64,              // the bake's time (measuring)
    floor_albedo: Texture,
    floor_normal: Texture,
    floor_noise:  Texture,          // the floor's slow noises (surfaces::floor_noise)
    scratch_tile: Texture,          // the floor's scratches' tile, R8 with its mips (surfaces::scratch_tile)
    wall_albedo:  Texture,
    wall_normal:  Texture,
    // The woods' pictures (Wood's way 2; the light tuner's, read from files): the panelling's,
    // the floor's and the table's, each its albedo (RGBA8 sRGB, the roughness in A) and normal
    // (the slopes in R and G, B 0.4, the normal's up in A), with their mips; 0 none.
    wood_pictures: Texture[6],
    paper_mask:    Texture,         // the wallpaper's mask, R8 with its mips (surfaces::PAPER_SIDE)
    paper_tile:    f32,             // the wall a tile of it covers (world units), 0 surfaces::PAPER_TILE
    room_frame:    surfaces::Frame, // the room's frame this frame (put_room)
    room_for:      float4,          // what the mesh was made for: the shell's key
    shell_table:   float2,          // the games table's place in the plan the shell's mesh and view out were made round
    mesh_ms:       f64,             // the mesh's making (measuring)
    // The shell's corners' shade (model3d::corner_map), baked with its mesh: the atlas, R8,
    // the room's corners it was baked for, and the bake's time (measuring).
    corner_map:   Texture,
    corner_for:   float4,
    corner_ms:    f64,
    plaster_tone: Texture,          // the plaster's tone, R8 as the wallpaper's
    lace_mask:    Texture,          // the curtains' lace, R8 with its mips (surfaces::LACE_TEXELS)
    lace_way:     i64,              // which lace (the light tuner's LACE_WAYS), and the one on the GPU
    lace_put:     i64,
    window_vb:    Buffer,            // the shell's glass and lace, drawn blended after the rest
    window_ib:    Buffer,
    window_count: i64,
    lace_first:   i64,
    room_glass:   Pipeline,
    room_lace:    Pipeline,
    room_vb:      Buffer,
    room_ib:      Buffer,
    room_count:   i64,
    room_from:    i64[ROOM_GROUPS], // where each material group's indices start (by_group)
    cheap_from:   i64,              // the cheap mirror world's indices, after the groups' (mirror_cheap)
    cheap_count:  i64,
    // The floor's four corners as the room's mesh has them (by_group), which its pieces
    // (sun_derived) take their attributes from; and the sun-derived block.
    floor_corners: corner_map::RoomVertex[4],
    sun:           SunDerived,
    // The window's light map (window_map), RGBA8 with its mips, what it was baked from, its
    // bake's pipeline, and whether the room's pipelines read it (room_mapped), and whether
    // they take the room's block as constants (room_fixed, room_fixed_on).
    window_map:      Texture,
    window_map_for:  float4[WINDOW_MAP_KEY],
    window_map_bake: Pipeline,
    room_mapped:     bool,
    room_fixed:      bool,
    // The box's map (box_map), RGBA16F, what it was baked from, its bake's pipeline, and
    // whether the room's pipelines read it (room_boxed).
    box_map:      Texture,
    box_map_for:  float4[BOX_MAP_KEY],
    box_map_bake: Pipeline,
    room_boxed:   bool,
    // The room's pipelines, one a material group (room_group), made when first wanted
    // (make_room) for the tier: room_ssao, with the screen's maps (ssao_allowed), or a
    // phone's without them. The floor here sees the room's box; room_planar the mirror.
    room_floor:  Pipeline,
    room_walls:  Pipeline,
    room_paint:  Pipeline,
    room_sill:   Pipeline,
    room_metals: Pipeline,
    room_ssao:   bool,
    room_views:  bool,              // with the tuner's views (room_views_on)
    room_props:  bool,              // the table's and its mirror's with shaders::PROPS_LIGHT (props_light)
    bake_room:   Pipeline,
    // The view out of the shell's windows (model3d::view_out), drawn first in its place of
    // the photograph when on (the tuner's): its mesh, made once, its pipeline, and its two
    // pictures, the far band and the oak, RGBA8 sRGB with no mips.
    outside_on:        bool,
    outside:           Pipeline,
    outside_vb:        Buffer,
    outside_ib:        Buffer,
    outside_count:     i64,
    outside_far_count: i64,         // the sky, the lawn and the band alone (view_out::build)
    outside_band:      Texture,
    outside_oak:       Texture,
    // The shell's baked light (model3d::room_light), RGBA16F: made again when what it is
    // baked from changes (light_key), its time (measuring) and how many sun patches lit it.
    light_volume: Texture,
    // The props' atlas of the same light as nine harmonics (props_light).
    props_probes:  Texture,
    light_for:     float4[LIGHT_KEY],
    light_ms:      f64,
    light_patches: i64,
    // The window's glow (bloom_pass): its pipelines, made with the room's, and its two
    // quarter-size RGBA16F targets, made again for another size.
    bloom_pick: Pipeline,
    bloom_blur: Pipeline,
    bloom_add:  Pipeline,
    bloom_a:    Texture,
    bloom_b:    Texture,
    bloom_size: int2,
    // The room's ambient occlusion (ssao_pass): the prepass's pipelines for the room, the
    // table and the board (shaders::PRE_FRAG), the occlusion's and its blur's, made with
    // the room's; its half-size targets, made again for another size: where each pixel is
    // (RGBA16F), which way it faces (RGBA8), their depth, the occlusion (RG16F) and the
    // blurred map the room reads.
    pre_room:  Pipeline,
    pre_table: Pipeline,
    pre_lit:   Pipeline,
    ssao:      Pipeline,
    ssao_blur: Pipeline,
    // The light tuner's GTAO trial in place of ssao (ssao_gtao, shaders::GTAO_FRAG).
    gtao:       Pipeline,
    pre_place:  Texture,
    pre_facing: Texture,
    pre_depth:  Texture,
    ssao_raw:   Texture,
    ssao_map:   Texture,
    ssao_size:  int2,
    // The floor's mirror (planar_pass): the room drawn mirrored under the floor (its walls',
    // paint's, sills', metals' and glass's pipelines in shaders::MIRROR_PASS, the floor not drawn, the
    // table's winding the other way), that made the room's light again with each texel's
    // distance (resolve), its mips each a tent over the level above (mip), the tuner's view
    // of it (show); its targets at planar_size_of's size, made again for another: the
    // picture (RGBA16F), its depth (sampled), and the map the floor reads (RGBA16F with
    // PLANAR_MIPS). Its pipelines only with the screen's maps (room_ssao).
    room_planar:    Pipeline,       // the floor that sees the mirror (shaders::PLANAR_FLOOR)
    planar_walls:   Pipeline,
    planar_paint:   Pipeline,
    planar_sill:    Pipeline,
    planar_metals:  Pipeline,
    planar_glass:   Pipeline,
    planar_lace:    Pipeline,
    planar_table:   Pipeline,
    cheap_room:     Pipeline,       // the cheap mirror world's (mirror_cheap), made while it is on
    cheap_table:    Pipeline,
    planar_resolve: Pipeline,
    planar_mip:     Pipeline,
    planar_show:    Pipeline,
    planar_color:   Texture,
    planar_depth:   Texture,
    planar_map:     Texture,
    planar_current: bool,
    planar_size:    int2,
    planar_sampler: Sampler,        // clamped, trilinear: the floor's blur picks its mip
    // The room's reflection (refl_pass, task 131): the room drawn from refl_probe in six views
    // (its groups' and the table's pipelines in shaders::MIRROR_PASS with PHYSICAL_COAT, the
    // table wound as in the room) into refl_face, each packed into the octahedral refl_src
    // (pack) with its mips (mip), then refl_map's levels, one a roughness (filter), which the
    // glossy surfaces read.
    refl_walls:  Pipeline,
    refl_paint:  Pipeline,
    refl_sill:   Pipeline,
    refl_metals: Pipeline,
    refl_glass:  Pipeline,
    refl_lace:   Pipeline,
    refl_floor:  Pipeline,
    refl_table:  Pipeline,
    refl_pack:   Pipeline,
    refl_mip:    Pipeline,
    refl_filter: Pipeline,
    refl_face:   Texture,
    refl_depth:  Texture,
    refl_src:    Texture,
    refl_map:    Texture,
    refl_for:    float4[REFL_KEY],
    // A tuner's: the panelling oak's and the ceiling's tint (x, z their lightness, y, w their
    // saturation, as factors, 0 untouched), and the tree's and the shell's light kept as
    // they are, not baked again, while a slider is held, so a drag bakes once on release.
    room_tint: float4,
    bake_held: bool,
    // The bookcases' books (model3d::books): their atlas, RGBA8 with BOOK_MIPS, put with the
    // room's masks; and a tuner's: the books left out of the mesh, their fade scaled (0 as
    // made).
    book_atlas: Texture,
    // The rug under the games table (put_rug), put with the room's masks; and a tuner's: the
    // rug left off the floor.
    rug_map: Texture,
    rug_off: bool,
    // The chairs' tapestry (put_tapestry), put with the room's masks.
    tapestry_map: Texture,
    // The stove's relief atlas (room_shell::stove_relief), RGBA8 with its mips, put with the
    // room's masks.
    stove_relief: Texture,
    // The quiet paint's relief tile (room_shell::relief_tile), RGBA8 with its mips, made
    // with the room's bake, and the time it took (measuring).
    paint_tile:    Texture,
    paint_tile_ms: f64,
    // The sills' limestone tile (room_shell::stone_tile), RGBA8 with its mips, made when the
    // shell first shows, and the time it took.
    stone_tile:    Texture,
    stone_tile_ms: f64,
    // The window hardware's antique brass tile (room_shell::brass_tile), RGBA8 with its mips,
    // made when the box window first shows, and the time it took.
    brass_tile:    Texture,
    brass_tile_ms: f64,
    // The glass's wiping tile (model3d's glass_tile), RGBA8 with its mips, made when the
    // shell first shows, and the time it took.
    glass_tile:    Texture,
    glass_tile_ms: f64,
    books_off:     bool,
    book_fade:     f32,
    // The scene drawn under the screen's size (scene_size_of): its RGBA8 target at that
    // size, made again for another, and its pipelines up to the screen, bilinear and
    // Catmull-Rom (shaders::UPSCALE_FRAG), made the first time it is drawn so.
    scene_image:   Texture,
    upscale:       Pipeline,
    upscale_cubic: Pipeline,
    // The scenic views' HDR (hdr_shown): whether the pass's targets are the HDR ones (g.color
    // multisampled in hdr_format, resolved into hdr_image), its pipelines, and the pass that
    // tonemaps it (tone_pass).
    hdr:       bool,
    hdr_image: Texture,
    hdr_pipes: HdrPipelines,
    // The glow's levels (glow_pass), a quarter of the pass's size and each half the last,
    // made with the HDR target's size.
    glow_levels: Texture[GLOW_LEVELS],
    glow_size:   int2,
    // The haze's (haze_pass): its light at the pre-pass's half size, that size, its panes
    // (haze_panes) as sent, and the beam's cross-section (HAZE_CROSS_SIZE).
    haze_image: Texture,
    haze_size:  int2,
    haze_panes: Buffer,
    haze_cross: Texture,
    // The depth of field's depth (depth_pass): 1x and sampled, DEPTH32F where it can be, at the
    // pass's size; the room's, the table's and the lace's pipelines into it (the board's is
    // depth_only), and the tuner's view of it (depth_show_pass), made the first time.
    scene_depth: Texture,
    depth_room:  Pipeline,
    depth_table: Pipeline,
    depth_lace:  Pipeline,
    depth_show:  Pipeline,
    // The tree outside drawn as geometry (tree_geometry; the light tuner's --tree-draw).
    tree: TreeGpu,
}

// The tree outside as geometry (task 107's T2 and T3; model3d's tree_mesh.goose), after the
// room's opaque groups (draw_tree): its wood's mesh, the tubes' indices first, then the
// ribbons'; the bark's tile, made once; the pipelines (the tubes', the ribbons', 8-bit and
// HDR), made when first wanted; what it was grown for (tree_geometry_key) and how long
// growing, lighting and putting it on the GPU took (measuring).
struct TreeGpu {
    wood_vb:      Buffer,
    wood_ib:      Buffer,
    tube_count:   i64,
    ribbon_first: i64,
    ribbon_count: i64,
    bark:         Texture,
    // The bark's age layers (trees::bark_layers, tree_bark): the height and the cavity.
    bark_height: Texture,
    bark_cavity: Texture,
    tube:        Pipeline,
    ribbon:      Pipeline,
    hdr_tube:    Pipeline,
    hdr_ribbon:  Pipeline,
    leaves:      Buffer,        // the leaves' cards (trees::leaf_cards), when all is drawn
    leaf_count:  i64,
    leaf_shape:  Texture,       // the leaf atlas's two layers (leaf_atlas::make)
    leaf_marks:  Texture,
    leaf:        Pipeline,
    hdr_leaf:    Pipeline,
    // Whether the pipelines move the tree in the wind (tree_wind), and the leaves' meshes of
    // the 8-bit and the HDR pipelines (leaf_mesh), as they were made.
    wind_made:          bool,
    leaf_mesh_made:     i64,
    hdr_leaf_mesh_made: i64,
    // The key's slant onto the shadow's map and its layers' depths (TreeBlock's layers).
    layers:   float4,
    made_for: float4[TREE_GEOMETRY_KEY],
    ms:       f64,
    bark_ms:  f64,      // the age layers' growth (trees::bark_layers), once
    // The card (tree_card): its picture, RGBA16F with its mips; the pipelines drawing the
    // geometry into it and drawing it in the view out's place, 8-bit (the mirror's too) and
    // HDR; where it is in the tree's frame (tree_card_place: the eye and the plane's depth,
    // the rectangle on that plane, the depths it is drawn between); what it was drawn from
    // (tree_card_key) and how long drawing it took, the GPU waited for.
    card:          Texture,
    card_tube:     Pipeline,
    card_ribbon:   Pipeline,
    card_leaf:     Pipeline,
    card_draw:     Pipeline,
    hdr_card_draw: Pipeline,
    card_eye:      float4,
    card_rect:     float4,
    card_range:    float2,
    card_for:      float4[TREE_CARD_KEY],
    card_ms:       f64,
}

// The pipelines of the scenic views' HDR target (shaders::HDR_OUT): the board's and a fading
// piece's in g.pieces' material with the high tier's 16-tap shadow, the table's in the room,
// the room's groups' (the floor's seeing the room's box or the mirror), the view out's, the
// motes', and the tonemap's (shaders::HDR_TONE_FRAG); made outside a pass when HDR is first
// drawn (make_hdr), and again for other pieces or the light tuner's switches of the paint and
// the sills, which they were made for.
struct HdrPipelines {
    lit:    Pipeline,
    fading: Pipeline,
    table:  Pipeline,
    floor:  Pipeline,
    planar: Pipeline,
    // The floor's pieces (SunDerived), by kind: without the sun, without the table's map.
    floor_kinds:  Pipeline[2],
    planar_kinds: Pipeline[2],
    walls:        Pipeline,
    paint:        Pipeline,
    sill:         Pipeline,
    metals:       Pipeline,
    glass:        Pipeline,
    lace:         Pipeline,
    outside:      Pipeline,
    motes:        Pipeline,
    tone:         Pipeline,
    // The glow's (glow_pass): its first pick, a level halved, a level widened back up.
    glow_first: Pipeline,
    glow_down:  Pipeline,
    glow_up:    Pipeline,
    // The haze's (haze_pass): the beam's cross-section, the haze into its half-size target,
    // added straight into the picture, and that target added bilinear.
    haze_cross:   Pipeline,
    haze:         Pipeline,
    haze_full:    Pipeline,
    haze_add:     Pipeline,
    pieces:       i32,
    mapped:       bool,     // with the window's light map (window_map_on)
    props_light:  bool,     // the table's with shaders::PROPS_LIGHT (props_light)
    volumes:      bool,     // the paint's, sills' and metals' with shaders::PROBE_VOLUMES (room_light::volumes_on)
    coat:         bool,     // the walls' and floor's with shaders::PHYSICAL_COAT (physical_coat)
    board_probes: bool,     // the board's with shaders::PROPS_LIGHT (board_probes)
}

// The plain fade behind the 3D game: dimmed to 0.8, as the flat game's background is.
let PLAIN_DIM = 0.8;

// The photograph `kind` blurred into g.photo (src/app/scene.goose's way: shrunk to 512
// on the GPU, two passes of a Gaussian of sigma 5.6 texels), and its harmonics, taken
// `grey` of the way to grey. Decodes the photograph, so only at setup and on a theme
// change, never in the frame loop.
fn photograph<O>(o: O&, g: Gpu&, kind: i64, grey: f32, sh: float4[9]&) {
    for k in 3 { o.photo_part(g, kind, grey, sh, k); }
}

// Bakes the plan and the frame map (or one of them), and waits for them: at setup, on a
// theme change, a new board size, and when the wood's model, its finish or the marble
// switches.
fn bake_surfaces<O>(o: O&, g: Gpu&, plan: bool = true, frame: bool = true) {
    let t = look(g, g.look);
    if plan {
        o.bake(g, g.plan_albedo, g.plan_normal, g.side, g.side, 0.0, model3d::plan_extent(), t);
    }
    if frame {
        full_frame(o, g);
        let rows = g.frame_rows;
        o.bake(g, g.frame_albedo, g.frame_normal, g.side, rows, 1.0, model3d::frame_extent(rows, g.side), t);
        flat_frame(o, g);
    }
    if g.table { bake_table(o, g); }
    o.gpu_flush();
}

// The table's maps made at the surfaces' side when it shows, given back when it doesn't.
fn table_maps<O>(o: O&, g: Gpu&) {
    let side = if g.table { g.side } else { 0 };
    guard side != g.table_side else { return; }
    if g.table_side != 0 {
        o.gpu_release_waited(g.table_albedo, g.table_normal);
        o.gpu_release_waited(g.table_wear, g.table_wear_n);
    }
    g.table_side = side;
    g.table_baked = false;
    guard side > 0 else { return; }
    let ts = model3d::table_size(side);
    g.table_albedo = baked(o, ts.x, ts.y, RGBA8_SRGB);
    g.table_normal = baked(o, ts.x, ts.y, RGBA8);
    let ws = model3d::wear_side(side);
    g.table_wear = baked(o, ws, ws, RGBA8_SRGB);
    g.table_wear_n = baked(o, ws, ws, RGBA8);
}

// The table's mesh, its top and its base, made again when its edge, its turn or its chairs
// aren't the ones it was made with.
fn table_mesh<O>(o: O&, g: Gpu&) {
    let e = g.table_spec.edge;
    let was = g.table_edge;
    let r = mesh::TABLE_R;
    guard g.table_vb.id == 0 || e.x != was.x || e.y != was.y || e.z != was.z || e.w != was.w
          || g.table_turn != g.table_made_turn || g.chairs != g.chairs_made || (g.chairs && chairs_on_rug(g) != g.chairs_rug_made)
          || (props_light && !g.props_baked)
    else { return; }
    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    mesh::table(verts, indices, e, r, surfaces::FLOOR_Y);
    if g.table_turn != 0.0 {
        let a = radians(g.table_turn);
        let c = cos(a);
        let sn = sin(a);
        for &v in verts {
            let x = v.pos.x;
            let z = v.pos.z - mesh::TABLE_Z;
            v.pos.x = c * x - sn * z;
            v.pos.z = sn * x + c * z + mesh::TABLE_Z;
            let nx = v.normal.x;
            v.normal.x = c * nx - sn * v.normal.z;
            v.normal.z = sn * nx + c * v.normal.z;
        }
    }
    // The chairs stand on the board's axis whatever the table's turn, on the rug's top.
    if g.chairs {
        let lift: f32 = if chairs_on_rug(g) { CHAIR_RUG_LIFT * surfaces::METRE } else { 0.0 };
        mesh::chairs(verts, indices, surfaces::FLOOR_Y + lift);
    }
    if g.table_vb.id != 0 { o.gpu_release_mesh(g.table_vb, g.table_ib); }
    g.table_vb, g.table_ib = o.gpu_mesh(bytes_of(verts), bytes_of(indices));
    g.table_count = indices.len;
    g.props_baked = false;
    if props_light { bake_props_open(o, g, verts[..], indices[..]); }
    g.chairs_made = g.chairs;
    g.chairs_rug_made = chairs_on_rug(g);
    g.table_edge = e;
    g.table_made_turn = g.table_turn;
}

// The props' light (shaders::PROPS_LIGHT, task 120): the games table and its chairs lit from
// the room's probe grid where each pixel is, through their occlusion baked per vertex, in
// place of the four samples on the table's axis. The light tuner's, off by default (the app's
// look as before); props_table_shade keeps the table's own shade terms beside the bake (the
// base's hidden sky, the edge's under the top); props_wrap: how far past its terminator the
// sun's light wraps on them (0.2 as made, 0 a lambertian face's, the tuner's --light
// physical); props_profile_ao: the table keeps its profile's own occlusion (mesh::table's)
// beside the bake's open part (off under the tuner's --light physical: the bake's alone, as
// the chairs'). The bake's rays a vertex and reach (metres).
var props_light = false;
// The varnish and wax as clear coats (shaders::PHYSICAL_COAT, the light tuner's --light
// physical): the walls' and floor's groups on the desktop's HDR tier.
var physical_coat = false;
// The woods' own finishes (the light tuner's --woods, task 122): the panelling, the floor, and the
// table with its chairs each as made (way 0), our maps stained and finished as the docx
// manor_wood_materials_cycles says (1), a picture of its own read by the tuner under the same
// finish (2, its maps in Gpu.wood_pictures, else as 1), or the floor's herringbone tuned toward
// the parquet's (3), as tools/blender/scene.py's finished_wood takes them. The walls' and floor's
// under PHYSICAL_COAT, the table's in any light.
struct Wood {
    dark:   float4,   // the stain's darkest colour (linear) and, w, the map's luminance it takes (its 5th percentile)
    mid:    float4,   // its middle colour and, w, the map's luminance the lightest takes (its 95th)
    light:  float4,   // its lightest colour and, w, the way
    finish: float4,   // the base's roughness from x to y over the map's, the coat's weight z and roughness w
    tile:   float4,   // x the picture's side (world units)
}
let WOOD_AS_MADE = 0;
let WOOD_STAINED = 1;
let WOOD_PICTURE = 2;
let WOOD_OAK = 0;
let WOOD_FLOOR = 1;
let WOOD_TABLE = 2;
var woods = [default<Wood>(); 3];
// The floor's planks' cup (x) and tilt (y) in place of surfaces::LOOK's where 0 or more (the tuner's --floor-shape).
var floor_shape = float2 { -1.0, -1.0 };
// The light tuner's panoramas of what the reflections see (--env-pano): every floor or table-top
// pixel shows, in place of itself, the light one lookup returns along the direction its place on
// the screen stands for (equirectangular: the middle column toward [2], [1] to its right, up at
// the top) from the point [0].xyz (world). [0].w the lookup: 0 none; on the floor 1 the
// harmonics, 2 the room's probes (room_wide), 3 the room's box sharp (room_seen), 4 the floor's
// wax as drawn (floor_reflection at [1].w's alpha); on the table 5 the props' probes
// (grid_light), 6 their box sharp (props_seen_at), 7 the polish as drawn at [1].w.
var env_pano = [float4_0, float4_0, float4_0];
// The matt floor's reflection without the mirror (ROOM_FRAG's floor_reflection, in planar_look's
// z and w): x 0 the room's box blurred by the wax's lobe, 1 only the room's light that way and
// the windows' soft shapes; y the windows' light in it then. The tuner's --floor-box.
var floor_box = float2 { 0.0, 1.0 };
// The rows a shader reads for wood `k`: its way 2 only with its picture there, else 1.
fn wood_rows(g: Gpu&, k: i64) -> float4[5] {
    let w = woods[k];
    var way = w.light.w;
    if way == WOOD_PICTURE as f32 && g.wood_pictures[2 * k].id == 0 { way = WOOD_STAINED as f32; }
    return [w.dark, w.mid, float4 { w.light.x, w.light.y, w.light.z, way }, w.finish, w.tile];
}
// The maps a wood's surface reads: its picture's (way 2) where there is one, else `own`.
fn wood_maps(g: Gpu&, k: i64, albedo: Texture, normal: Texture) -> Texture, Texture {
    if woods[k].light.w == WOOD_PICTURE as f32 && g.wood_pictures[2 * k].id != 0 {
        return g.wood_pictures[2 * k], g.wood_pictures[2 * k + 1];
    }
    return albedo, normal;
}
var props_table_shade = false;
var props_profile_ao = true;
var props_wrap: f32 = 0.2;
let PROPS_RAYS = 32;
let PROPS_REACH: f32 = 0.5;

// The props' occlusion baked over the table's mesh as made into g.props_open: a second or
// so on the main thread, when the mesh is made with props_light on.
fn bake_props_open<O>(o: O&, g: Gpu&, verts: const mesh::Vertex[:], indices: const u32[:]) {
    let t0 = clock();
    let n = verts.len;
    var pos:    float3[..]               = [..n];
    var normal: float3[..]               = [..n];
    var open:   prop_occlusion::Open[..] = [..n];
    for v in verts {
        pos.push(v.pos);
        normal.push(v.normal);
        open.push(prop_occlusion::Open { float3_0, 0.0 });
    }
    prop_occlusion::bake(pos[..], normal[..], indices, PROPS_RAYS, PROPS_REACH * surfaces::METRE, open[..]);
    var packed: float4[..] = [..n];
    for a in open { packed.push(float4 { a.dir.x, a.dir.y, a.dir.z, a.open }); }
    if g.props_open.id != 0 { o.gpu_release_storage(g.props_open); }
    g.props_open = o.gpu_storage(bytes_of(packed));
    g.props_baked = true;
    g.props_ms = (clock() - t0) * 1000.0;
}

// TABLE_FRAG's block with PROPS_LIGHT (shaders::TABLE_SHELL's PropsLight): the probes' grid
// as the room's (light_box_of, light_grid_of), and props_look x 1 where the table keeps its
// own shade terms (props_table_shade), y the sun's wrap (props_wrap), z 1 where the table
// takes the bake's open part alone (props_profile_ao off).
// props_look.w 1 where the polish sees the room's box (props_seen); then the box and its
// surfaces as the room's block has them (TABLE_FRAG's props_seen_at), linear: the paper's
// mean (its ground and a third of its gold), the doors' paint, the ceiling's.
struct PropsLightBlock {
    light_box: float4, light_grid: float4, props_look: float4,
    room_box:  float4, room_doors: float4, room_heights: float4, lace_light: float4,
    box_paper: float4, box_paint: float4, box_ceiling: float4,
    env_pano:  float4[3],
}
// Whether the table's and chairs' polish reflects the room's box and its windows sharply
// (TABLE_FRAG's props_seen_at) in place of the probes' light alone (the light tuner's
// --props-seen, on under --light physical; task 122).
var props_seen = false;
// Whether the board and its pieces in the HDR views are lit as the table is: the probes'
// light where each pixel is and the room's box in their varnish (LIT_FRAG with PROPS_LIGHT,
// the props' probes and PropsLightBlock), not the look's harmonics (the light tuner's
// --board-probes, on under --light physical; task 122). With props_light only.
var board_probes = false;
fn props_light_block(g: Gpu&) -> PropsLightBlock {
    let s = surfaces_block(g);
    let paper = model3d::linear4(s.paper);
    let gold = model3d::linear4(s.gold);
    PropsLightBlock { light_box_of(), light_grid_of(),
                      float4 { if props_table_shade { 1.0 } else { 0.0 }, props_wrap, if props_profile_ao { 0.0 } else { 1.0 }, if props_seen { 1.0 } else { 0.0 } },
                      s.room_box, s.room_doors, s.room_heights, s.lace_light, paper + (gold - paper) * 0.3, model3d::linear4(s.paint),
                      model3d::linear4(s.ceiling_light), env_pano }
}

// A chair's plan round its seat's middle (world units: half its width, its front, its back's
// rearmost) and its height, for the table's map (mesh::chairs' measures).
let CHAIR_PLAN = float3 { 7.925, 7.925, -9.754 };   // 260, 260, -320 mm
let CHAIR_TALL: f32 = 29.26;                         // 960 mm

// The rug's thickness (ROOM_FRAG's RUG_THICK, metres): the chairs' feet stand on its top.
let CHAIR_RUG_LIFT: f32 = 0.008;
fn chairs_on_rug(g: Gpu&) -> bool { !g.rug_off && g.rug_map.id != 0 }

// The table's wood baked into its maps (rows y0 to y1, -1 all; the mips with the last),
// as a look's light squares: tables::Table in their slots.
fn bake_table<O>(o: O&, g: Gpu&, y0: i64 = 0, y1: i64 = -1, mips: bool = true) {
    table_maps(o, g);
    guard g.table else { return; }
    table_mesh(o, g);
    let tb = g.table_spec;
    var t = look(g, g.look);
    t.light_sq = tb.wood;
    t.light_fig = tb.fig;
    t.light_ring = tb.ring;
    t.inlay = tb.pores;
    t.surface = tb.surface;
    t.seam = tb.planks;
    t.dark_sq = tb.patina;
    t.dark_fig = tb.wear;
    t.dark_ring = tb.flame;
    t.build.w = 0.0;
    let ts = model3d::table_size(g.side);
    let wood = g.wood;
    let finish = g.finish;
    g.wood = clamp(tb.model as i64, 0, model3d::WOOD_MODELS - 1);
    g.finish = tb.finish;
    o.bake(g, g.table_albedo, g.table_normal, ts.x, ts.y, 2.0, model3d::table_extent(), t, y0, y1, mips);
    g.wood = wood;
    g.finish = finish;
    guard y1 < 0 || y1 >= ts.y else { return; }
    // The wear's tile with the last band, sampled as finely as at the full side.
    let ws = model3d::wear_side(g.side);
    o.bake(g, g.table_wear, g.table_wear_n, ws, ws, 3.0, float2 { model3d::WEAR_TILE, model3d::WEAR_TILE }, t,
           0, -1, true, model3d::WEAR_SIDE / ws);
    g.table_baked = true;
}

// Whether the board's pass draws the table: on, and its wood baked.
fn table_shown(g: Gpu&) -> bool { g.table && g.table_baked && g.table_side == g.side && g.table_vb.id != 0 }

// TABLE_FRAG's block: the table's light, its polish, and its rim's wear (tables::Table),
// and its shape: x the top's radius, y the floor's height; the table's own map
// (table_map_place, all 0 where none is drawn).
// In the room with its light baked, the room's light round the table: the probes on its
// axis (table_probes), mix: x 1 (0 the game's harmonics as before), y the harmonics the room
// keeps, z the room's exposure over the board's, w how much of the shade's floor of the key
// stays (shade_fill); shade: the room's even bounce it keeps, w a metre in world units.
struct TableBlock {
    pool:       float4, coat: float4, polish: float4, worn: float4, shape: float4, map: float4[4],
    room_light: float4[12], room_mix: float4, room_shade: float4, ssao: float4, base_wood: float4,
    base_look:  float4, wood_finish: float4[5],
}
// How the base reads its wood (shaders::TABLE_FRAG's base_wood, the light tuner's
// --base-wood): x 0 as made, 1 its own, its grain along the column and the legs; then y its
// lightness and z its figure's contrast, each a share of the map's, w how far the figure is
// drawn out along the grain. base_look: x the grain's slant round the column (degrees),
// y the rings the cut crosses, z its place across the map, w the colour's strength.
// The defaults match the chairs' legs (their wood, darker and less red than the map).
var base_wood = float4 { 1.0, 0.57, 0.6, 3.0 };
var base_look = float4 { 0.0, 0.0, 0.5, 0.75 };
// Whether the table stands in the room with its light baked: drawn with TABLE_ROOM's
// pipeline (g.table_room) and the probes round it.
fn table_in_room(g: Gpu&) -> bool { table_map_shown(g)[3].x > 0.5 && light_baked(g) && g.light_volume.id != 0 && g.table_room.id != 0 }
fn table_block(g: Gpu&) -> TableBlock {
    let t = g.table_spec;
    let map = table_map_shown(g);
    let r = g.room;
    let on = table_in_room(g);
    let shade = rooms::color_of(r.bounce) * (r.bounce.w * r.baked.w);
    let turn = radians(g.table_turn);
    TableBlock { t.light, t.coat, t.polish, t.wear, float4 { mesh::TABLE_R, surfaces::FLOOR_Y, sin(turn), cos(turn) }, map,
                 table_probes, float4 { if on { 1.0 } else { 0.0 }, r.baked.z, r.room_exposure, shade_fill },
                 float4 { shade.x, shade.y, shade.z, surfaces::METRE }, if on { ssao_block_of(g) } else { float4_0 }, base_wood,
                 base_look, wood_rows(g, WOOD_TABLE) }
}

// The table's own shadow in the room (shaders::TABLE_MAP_FN): its top and base, and the
// chairs where they stand, drawn into a map of their own, projected along the key onto the
// floor round the table, so the floor, the walls it reaches, the base and the chairs take
// the table's and the chairs' true shadows. Drawn when the room and the table show, again
// only when the key or the table changes; the game, which shows no room, never draws it.
// Fitted to the table and the chairs (table_map_rows): its texels about 3 mm on the floor
// along the shadow, 2 mm across, 2.5 at the worst sun.
let TABLE_MAP_W = 2048;
let TABLE_MAP_H = 1024;
let TABLE_MAP_MARGIN: f32 = 1.5;     // round the top (world units)
let TABLE_MAP_REACH:  f32 = 122.0;   // the farthest the shadow is followed (4 m)
let TABLE_MAP_DEPTH:  f32 = 150.0;   // half the depth range along the key (world units)

// Whether the table's map is wanted this frame.
fn table_map_wanted(g: Gpu&) -> bool { room_shown(g) && table_shown(g) }

// The map's rows where it is drawn and wanted, else all 0 (the shaders then take none).
fn table_map_shown(g: Gpu&) -> float4[4] {
    if g.table_map.id != 0 && table_map_wanted(g) { return g.table_map_place; }
    return [float4_0; 4];
}

// The rows that place a world point in the table's map: x along the shadow and y across it
// (-1..1, where the point's ray along the key meets the floor), z its depth (nearer the key
// lower), each a row's dot with (p, 1); the fourth row x 1 (drawn).
fn table_map_rows(g: Gpu&) -> float4[4] {
    let l = float3 { g.frame.light_dir.x, g.frame.light_dir.y, g.frame.light_dir.z };
    let ly = max(l.y, 0.05);
    let h = length(float2 { l.x, l.z });
    let d = if h > 1e-4 { float2 { l.x / h, l.z / h } } else { float2 { 1.0, 0.0 } };
    let e = float2 { -d.y, d.x };
    let fy = surfaces::FLOOR_Y;
    let c = float3 { 0.0, fy, mesh::TABLE_Z };
    let r = mesh::TABLE_R + TABLE_MAP_MARGIN;
    let slope = h / ly;
    let reach = min((mesh::TABLE_TOP - fy) * slope, TABLE_MAP_REACH);
    let cd = c.x * d.x + c.z * d.y;
    let ce = c.x * e.x + c.z * e.y;
    // What the map holds, along the shadow (s, from the middle on the floor away from the
    // key) and across it (t): the top's circle and its shadow's reach; with the chairs, each
    // one's plan's corners and its shadow from its full height.
    var s0 = -r;
    var s1 = r + reach;
    var t0 = -r;
    var t1 = r;
    if g.chairs_made {
        let tall = min(CHAIR_TALL * slope, TABLE_MAP_REACH);
        for at in mesh::CHAIRS {
            for k in 4 {
                let x: f32 = if k % 2 == 0 { -CHAIR_PLAN.x } else { CHAIR_PLAN.x };
                let z: f32 = if k < 2 { CHAIR_PLAN.y } else { CHAIR_PLAN.z };
                let px = at.x + at.w * x + at.z * z;
                let pz = at.y - at.z * x + at.w * z;
                let s = cd - (px * d.x + pz * d.y);
                let t = px * e.x + pz * e.y - ce;
                s0 = min(s0, s - TABLE_MAP_MARGIN);
                s1 = max(s1, s + tall + TABLE_MAP_MARGIN);
                t0 = min(t0, t - TABLE_MAP_MARGIN);
                t1 = max(t1, t + TABLE_MAP_MARGIN);
            }
        }
    }
    let mid = 0.5 * (s0 + s1);
    let half = 0.5 * (s1 - s0);
    let tm = 0.5 * (t0 + t1);
    let across = 0.5 * (t1 - t0);
    let kz = 0.5 / TABLE_MAP_DEPTH;
    return [
        float4 { -d.x / half, slope / half, -d.y / half, (cd - slope * fy - mid) / half },
        float4 { e.x / across, 0.0, e.y / across, -(ce + tm) / across },
        float4 { -l.x * kz, -l.y * kz, -l.z * kz, 0.5 + dot(c, l) * kz },
        float4 { 1.0, 0.0, 0.0, 0.0 },
    ];
}

// The rows as a matrix for the map's pass (light_view_proj in its frame's copy).
fn table_map_matrix(rows: float4[4]) -> Mat {
    var m = default<Mat>();
    m.c0 = float4 { rows[0].x, rows[1].x, rows[2].x, 0.0 };
    m.c1 = float4 { rows[0].y, rows[1].y, rows[2].y, 0.0 };
    m.c2 = float4 { rows[0].z, rows[1].z, rows[2].z, 0.0 };
    m.c3 = float4 { rows[0].w, rows[1].w, rows[2].w, 1.0 };
    return m;
}

// What the table's map is drawn for: the key, the top's radius, the table's mesh.
fn table_map_key(g: Gpu&) -> float4[2] {
    let l = g.frame.light_dir;
    return [float4 { l.x, l.y, l.z, mesh::TABLE_R }, float4 { g.table_vb.id, g.table_count, g.table_turn, 0.0 }];
}

// The table's map drawn where it is wanted and what it was drawn for changed. Recording
// only, before the board's pass.
fn table_map<O>(o: O&, g: Gpu&) {
    guard table_map_wanted(g) else { return; }
    let key = table_map_key(g);
    guard g.table_map.id == 0 || !same4(key[0], g.table_map_for[0]) || !same4(key[1], g.table_map_for[1]) else { return; }
    g.table_map_for = key;
    g.table_map_place = table_map_rows(g);
    o.table_map_pass(g, table_map_matrix(g.table_map_place));
}

// The table's map to bind, or the key's where none is drawn (a depth texture either way,
// for the compare sampler): the shaders read it only when their block says it is drawn.
fn table_map_or_stand_in(g: Gpu&) -> Texture { if g.table_map.id != 0 { g.table_map } else { g.shadow_map } }

// The sun-derived block (docs/decisions/rendering.md, "Sun-derived at the bake"): what
// depends only on the sun and the room, worked out when either changes (sun_derived) and
// only read by both renderers' passes; a new saving of the kind adds a field here and its
// line in sun_derived. Now the floor's pieces: the shell's floor cut along the sun into
// where no sun reaches it through the windows (FLOOR_SHADE), where it may (FLOOR_LIT), and
// where the table's map may darken that too (FLOOR_TABLE), each drawn with a floor shader
// holding only what it needs (shaders::FLOOR_SHADE, FLOOR_NO_TABLE; the full one for
// FLOOR_TABLE). The cuts are those shell_open's and table_map_at's own tests make, widened
// by the largest penumbra, so each piece's shader gives what the full one would.
let FLOOR_SHADE = 0;
let FLOOR_LIT = 1;
let FLOOR_TABLE = 2;
let FLOOR_KINDS = 3;
// The lines along the sun the floor is cut at (each window's sides, the table map's), the
// pieces (three rows: before the sun's band, the band, after it), a piece's corners at most.
let SUN_CUTS = 8;
let FLOOR_PIECES = 3 * (SUN_CUTS + 1);
let PIECE_CORNERS = 8;
// What a cut is widened by past the penumbra's reach (metres): rounding's room.
let SUN_CUT_SPARE: f32 = 0.01;
struct SunDerived {
    made_for: float4[SUN_KEY],
    // The floor's pieces: their mesh, where each kind's indices start and how many.
    pieces_vb: Buffer,
    pieces_ib: Buffer,
    first:     i64[FLOOR_KINDS],
    count:     i64[FLOOR_KINDS],
}

// The pieces' mesh as it is made: fixed, touched only when the sun or the room changes.
var piece_verts:   corner_map::RoomVertex[FLOOR_PIECES * PIECE_CORNERS];
var piece_indices: u32[FLOOR_PIECES * (PIECE_CORNERS - 2) * 3];

// The floor's corners in the room's mesh: its vertices at the least and most u and v.
fn floor_corners_of(room: corner_map::RoomVertex[>..]&) -> corner_map::RoomVertex[4] {
    var c: corner_map::RoomVertex[4] = [default<corner_map::RoomVertex>(); 4];
    var lo = float2 { 1e9, 1e9 };
    var hi = float2 { -1e9, -1e9 };
    for v in room {
        guard room_group(v.mat) == GROUP_FLOOR else { continue; }
        lo = float2 { min(lo.x, v.pos.x), min(lo.y, v.pos.z) };
        hi = float2 { max(hi.x, v.pos.x), max(hi.y, v.pos.z) };
    }
    let at: float2[4] = [lo, float2 { hi.x, lo.y }, hi, float2 { lo.x, hi.y }];
    for v in room {
        guard room_group(v.mat) == GROUP_FLOOR else { continue; }
        for k in 4 { if v.pos.x == at[k].x && v.pos.z == at[k].y { c[k] = v; } }
    }
    return c;
}

// Whether the floor is drawn in its pieces: made, and the room's sun the shell's, with the
// table's map drawn (FLOOR_SHADE's light then needs neither), in the HDR target, whose
// pipelines have the pieces' kinds.
fn floor_pieces_on(g: Gpu&) -> bool {
    g.sun.pieces_vb.id != 0 && g.hdr && g.room_on && g.frame.room.y > 0.0 && table_map_shown(g)[3].x > 0.5
}

// What the sun-derived block is worked out from: the key, the room's turn, the table's map,
// the penumbra and the room's mesh.
let SUN_KEY = 4;
fn sun_key(g: Gpu&) -> float4[SUN_KEY] {
    let f = g.room_frame;
    let m = table_map_shown(g);
    return [g.frame.light_dir, float4 { f.along.x, f.along.y, f.into.x, f.into.y }, float4 { m[1].x, m[1].z, m[1].w, m[3].x },
            float4 { g.room.shell_sun.x, g.frame.room.z, g.room_vb.id, 0.0 }];
}

// The sun-derived block worked out again where what it is made from changed. Recording only,
// before the board's pass.
fn sun_derived<O>(o: O&, g: Gpu&) {
    guard room_shown(g) else { return; }
    let key = sun_key(g);
    var same = g.sun.pieces_vb.id != 0;
    for k in SUN_KEY { same = same && same4(key[k], g.sun.made_for[k]); }
    guard !same else { return; }
    g.sun.made_for = key;
    let nv, ni = floor_pieces(g, surfaces_block(g));
    if g.sun.pieces_vb.id != 0 { o.gpu_release_mesh(g.sun.pieces_vb, g.sun.pieces_ib); }
    g.sun.pieces_vb, g.sun.pieces_ib = o.gpu_mesh(bytes_of(piece_verts[0..nv]), bytes_of(piece_indices[0..ni]));
}

// The window's light map: the shell's windows' pattern (the light their casements, bars
// and lace let through) baked in the window wall's inner face over the strip that holds the
// windows (shaders::window_map_place), where the key's ray from a point crosses it, and
// projected along the sun: LIGHT_FN's shell_open then takes the nearest niche's outline and
// a tap of the map, its mip by how far the point is past the face (the penumbra widens with
// it), in place of tracing the ray through the casements and the lace a pixel
// (shaders::WINDOW_MAP). The tree's light is in it, in a channel of its own with its own
// mip, where the leaves keep still (window_map_tree); while they move, the desktop's shaders
// light them a pixel (WINDOW_MAP_LEAVES). Baked on the GPU (render3d_gpu::window_map_pass)
// when what it is made from changes: the sun, the shell, the tree's map. Not the glass's or
// the lace's groups, the floor's mirror, the tuner's views and switched shaders, the board,
// the table or the dust, which trace the windows as before. window_map_on false: shell_open
// a pixel everywhere (the light tuner's --window-map off).
var window_map_on = true;
// The phone's tier's room shaders with the Surfaces block as constants (render3d_gpu's
// room_frag_fixed, room_fixed.goose; the light tuner's --room-fixed off for the uniforms).
var room_fixed_on = true;
// The first member whose constant isn't the block's any more (render3d_gpu's fixed_current):
// the looks tuned since scripts/room_fixed.py ran, or a state it doesn't keep. Where one is,
// the uniform shaders draw the room; the light tuner says which.
var room_fixed_stale: const u8[:] = "";
// The sharp box's light from the box's map on the phone's tier (box_map; the light
// tuner's --box-map off traces it a pixel as before).
var box_map_on = true;
let WINDOW_MAP_W = 2048;   // shaders::WINDOW_MAP_SIZE: 7.7 m by 3.15 m, a texel about 3.8 mm
let WINDOW_MAP_H = 832;
// The phone's tier's leaves (its shaders light none of their own): baked into the map at the
// wind's phase when it was baked, or none (the light tuner's --phone-leaves).
let LEAVES_STATIC = 0;
let LEAVES_OFF = 1;
var phone_leaves = LEAVES_STATIC;
// Whether the leaves move (the tuner's wind running): the desktop's map then leaves them out
// and its shaders light them a pixel. The app keeps them still.
var leaves_moving = false;

fn window_map_shown(g: Gpu&) -> bool { window_map_on && room_shown(g) }
// Whether the room's pipelines for group read the map in the lace's slot (make_room_tier,
// make_hdr): not the glass's or the lace's, the mirror's or the tuner's views.
fn window_map_read(g: Gpu&, group: i64, mirror: bool) -> bool {
    g.window_map.id != 0 && window_map_on && !mirror && !window_group(group) && !room_views_on()
}
// Whether the tree's light is baked into the map: on the phone's tier as phone_leaves says,
// elsewhere while the leaves keep still.
fn window_map_tree(g: Gpu&) -> bool {
    if !ssao_allowed { return phone_leaves == LEAVES_STATIC; }
    return !leaves_moving;
}
// What the map is baked from: the key, the shell's windows, the penumbra, whether the
// casements' members have their depth (Frame's panes.w), the tree's place and map, and
// whether the tree is in (never the wind: on the phone's tier the leaves stay
// as they were when it was baked).
let WINDOW_MAP_KEY = 15;
fn window_map_key(g: Gpu&) -> float4[WINDOW_MAP_KEY] {
    let b = shell_block(g);
    let f = g.frame;
    return [f.light_dir, b.axes, b.tile, b.shell, b.shell_mids, b.shell_niche, b.shell_glass, b.shell_sun, b.window_view, b.shell_case,
            f.room, f.panes, f.tree, f.tree_blur, float4 { if window_map_tree(g) { 1.0 } else { 0.0 }, g.tree_bakes, g.lace_mask.id, g.tree_map.id }];
}
// The map baked again where what it is made from changed. Recording only, before the
// board's pass.
fn window_map<O>(o: O&, g: Gpu&) {
    guard window_map_shown(g) else { return; }
    let key = window_map_key(g);
    var same = g.window_map.id != 0;
    for k in WINDOW_MAP_KEY { same = same && same4(key[k], g.window_map_for[k]); }
    guard !same else { return; }
    g.window_map_for = key;
    o.window_map_pass(g);
}

// The box's map (render3d_gpu::box_map_pass, task 115): the light leaving the shell's
// box (shaders::box_irradiance, the baked light) a texel each 4 cm on its six faces, which the phone
// tier's sharp reflection (SHARP_BOX on the floor and the metals) reads in one tap, with the
// surface there (box_albedo) and the sun through the windows (box_sun) worked out as before, in place of the second probe lookup; the windows
// on the window wall it still traces. Baked again when what it is made from changes: the
// probes, the window's light map, the sun, the room's light and the box's surfaces.
fn box_map_shown(g: Gpu&) -> bool {
    box_map_on && !ssao_allowed && sharp_box_allowed && window_map_shown(g) && light_baked(g) && g.light_volume.id != 0
}
let BOX_MAP_KEY = 54;
fn box_map_key(g: Gpu&) -> float4[BOX_MAP_KEY] {
    let b = surfaces_block(g);
    let f = g.frame;
    var k: float4[BOX_MAP_KEY] = [float4_0; BOX_MAP_KEY];
    for i in LIGHT_KEY { k[i] = g.light_for[i]; }
    for i in WINDOW_MAP_KEY { k[LIGHT_KEY + i] = g.window_map_for[i]; }
    var at = LIGHT_KEY + WINDOW_MAP_KEY;
    for v in [f.light_dir, f.light_color, f.params, b.shade, b.paper, b.gold, b.ceiling_light, b.paint, b.room_baked, b.room_sun,
              b.shell_sun, b.room_box, b.room_doors, b.room_heights, b.book_cases, b.light_box, b.light_grid] {
        k[at] = v;
        at++;
    }
    for i in 9 {
        k[at] = f.sh[i];
        at++;
    }
    k[at] = float4 { g.light_volume.id, g.window_map.id, 0.0, 0.0 };
    return k;
}
// The room's reflection (refl_pass, task 131), under the physical light on the desktop's
// tier: baked again when the room's light, its surfaces or the woods change. REFL_SIZE the
// octahedral map's side, REFL_FACE a view's, REFL_LEVELS its levels, roughness 0 to 1 evenly.
var refl_on = true;
let REFL_SIZE = 256;
let REFL_FACE = 128;
let REFL_LEVELS = 6;
let REFL_SAMPLES: f32 = 256.0;
let REFL_HEIGHT:  f32 = 1.0;    // the probe's height over the floor, metres
fn refl_shown(g: Gpu&) -> bool {
    refl_on && physical_coat && g.room_ssao && room_shown(g) && light_baked(g) && g.light_volume.id != 0
}
// The probe: the middle of the room's box, REFL_HEIGHT over the floor (the world's).
fn refl_probe(g: Gpu&) -> float3 { refl_probe_of(surfaces_block(g)) }
fn refl_probe_of(b: SurfacesBlock) -> float3 {
    let x = 0.5 * (b.room_box.x + b.room_box.y);
    let z = 0.5 * (b.room_box.z + b.room_box.w);
    return float3 { b.axes.x * x + b.axes.z * z, b.shell.z + REFL_HEIGHT * surfaces::METRE, b.axes.y * x + b.axes.w * z };
}
let REFL_KEY = BOX_MAP_KEY + 13;
fn refl_key(g: Gpu&) -> float4[REFL_KEY] {
    let b = surfaces_block(g);
    var k: float4[REFL_KEY] = [float4_0; REFL_KEY];
    let box = box_map_key(g);
    for i in BOX_MAP_KEY { k[i] = box[i]; }
    for i in 5 {
        k[BOX_MAP_KEY + i] = b.wood_oak[i];
        k[BOX_MAP_KEY + 5 + i] = b.wood_floor[i];
    }
    k[BOX_MAP_KEY + 10] = b.paper;
    k[BOX_MAP_KEY + 11] = b.paper_detail;
    k[BOX_MAP_KEY + 12] = float4 { g.room_vb.id, g.table_vb.id, if table_shown(g) { 1.0 } else { 0.0 }, 0.0 };
    return k;
}
fn refl_map<O>(o: O&, g: Gpu&) {
    guard refl_shown(g) else { return; }
    let key = refl_key(g);
    var same = g.refl_map.id != 0;
    for k in REFL_KEY { same = same && same4(key[k], g.refl_for[k]); }
    guard !same else { return; }
    g.refl_for = key;
    o.refl_pass(g);
}
// The frame of the probe's view `face` (+x, -x, +y, -y, +z, -z), 90° square.
fn refl_frame(g: Gpu&, face: i64) -> Frame {
    let at = refl_probe(g);
    let dirs = [float3 { 1.0, 0.0, 0.0 }, float3 { -1.0, 0.0, 0.0 }, float3 { 0.0, 1.0, 0.0 },
                float3 { 0.0, -1.0, 0.0 }, float3 { 0.0, 0.0, 1.0 }, float3 { 0.0, 0.0, -1.0 }];
    let up = if face == 2 { float3 { 0.0, 0.0, -1.0 } } else if face == 3 { float3 { 0.0, 0.0, 1.0 } } else { float3 { 0.0, 1.0, 0.0 } };
    var f = g.frame;
    f.view_proj = gfx::mul(gfx::perspective(1.5707963, 1.0, 0.05 * surfaces::METRE, 40.0 * surfaces::METRE), gfx::look_at(at, at + dirs[face], up));
    f.eye = float4 { at.x, at.y, at.z, 1.0 };
    f.screen = float4 { REFL_FACE as f32, REFL_FACE as f32, 0.0, 0.0 };
    return f;
}
// The pack's block for view `face`.
struct ReflPack { face: float4[4], at: float4, size: float4 }
fn refl_pack_of(g: Gpu&, f: Frame) -> ReflPack {
    let at = refl_probe(g);
    let exposure = max(g.frame.params.x * g.room.room_exposure, 1e-3);
    ReflPack { [f.view_proj.c0, f.view_proj.c1, f.view_proj.c2, f.view_proj.c3], float4 { at.x, at.y, at.z, 1.0 / exposure },
               float4 { REFL_SIZE as f32, REFL_SIZE as f32, 0.0, 0.0 } }
}

fn box_map<O>(o: O&, g: Gpu&) {
    guard box_map_shown(g) else { return; }
    let key = box_map_key(g);
    var same = g.box_map.id != 0;
    for k in BOX_MAP_KEY { same = same && same4(key[k], g.box_map_for[k]); }
    guard !same else { return; }
    g.box_map_for = key;
    o.box_map_pass(g);
}

// The floor's pieces into piece_verts and piece_indices, by kind (g.sun.first, count), from
// the block the shaders read; how many vertices and indices. In the room's frame (u along
// the window wall, v away from it, the mesh's own), a floor point (u, v) sees the sun
// through the window wall's plane at k (u + j (v + S)) along it, S the wall's face, and
// h (v + S) up from the floor (shaders::shell_open's t); the lines along the sun are those
// of one place along the wall, the band those of one height. The table's map reaches only
// within 0.995 of its half width across the sun (table_map_at).
fn floor_pieces(g: Gpu&, b: SurfacesBlock) -> i64, i64 {
    let f = g.room_frame;
    let l = g.frame.light_dir;
    let lu = l.x * f.along.x + l.z * f.along.y;
    let toward = -(l.x * f.into.x + l.z * f.into.y);
    let metre = b.shell.w;
    let face = b.shell.y;
    // The band of v the sun can reach, and the cuts across it, in u + j (v + S) (world
    // units); none lit where shell_open gives none (toward under 0.05).
    var band = float2 { 1e9, 1e9 };
    var cuts:  f32[SUN_CUTS] = [0.0; SUN_CUTS];
    var spans: float2[4]     = [float2_0; 4];
    var n_spans = 0;
    var n_cuts = 0;
    let lit = toward >= 0.05 && l.y > 0.02;
    let j = if lit { lu / toward } else { 0.0 };
    if lit {
        // The penumbra's widest, at the opening's top (shell_open's soft), solved for the
        // height it reaches to.
        let widen = if b.shell_sun.x > 0.0 { b.shell_sun.x } else { g.frame.room.z };
        let top = b.shell_niche.y + b.shell_niche.z + b.shell_niche.w;
        let grow = widen / l.y;
        let soft = if grow < 0.5 { (0.03 / metre + grow * top) / (1.0 - grow) + SUN_CUT_SPARE } else { 1e6 };
        let up = l.y / toward / metre;
        band = float2 { (b.shell_niche.y - soft) / up - face, (top + soft) / up - face };
        let half = (b.shell_niche.x + soft) * metre;
        let mids: f32[3] = [b.shell_mids.x, b.shell_mids.y, b.shell_mids.z];
        for i in min(b.shell.x as i64, 3) {
            spans[n_spans] = float2 { mids[i] - half, mids[i] + half };
            n_spans++;
        }
    }
    // The table's map across the sun, as a span of the same measure.
    let d = normalize(float2 { l.x, l.z });
    let e = float2 { -d.y, d.x };
    let m = b.table_map;
    let r = 1.0 / length(float2 { m[1].x, m[1].z });
    let ce = -m[1].w * r;
    var table = float2_0;
    for side in 2 {
        let at = e * (ce + (if side == 0 { -0.995 } else { 0.995 }) * r);
        let u = at.x * f.along.x + at.y * f.along.y;
        let v = at.x * f.into.x + at.y * f.into.y;
        let c = u + j * (v + face);
        if side == 0 { table.x = c; } else { table.y = c; }
    }
    let spare = SUN_CUT_SPARE * metre;
    table = float2 { min(table.x, table.y) - spare, max(table.x, table.y) + spare };
    for s in n_spans { cuts[n_cuts] = spans[s].x; cuts[n_cuts + 1] = spans[s].y; n_cuts += 2; }
    if n_spans > 0 { cuts[n_cuts] = table.x; cuts[n_cuts + 1] = table.y; n_cuts += 2; }
    sort_cuts(cuts, n_cuts);
    // Each piece: a row by a column, cut from the floor's rectangle; its kind by the
    // column's middle.
    let lo = float2 { g.floor_corners[0].pos.x, g.floor_corners[0].pos.z };
    let hi = float2 { g.floor_corners[2].pos.x, g.floor_corners[2].pos.z };
    let rows: f32[4] = [lo.y, clamp(band.x, lo.y, hi.y), clamp(band.y, lo.y, hi.y), hi.y];
    var nv = 0;
    var counts: i64[FLOOR_KINDS]  = [0; FLOOR_KINDS];
    var kinds:  i64[FLOOR_PIECES] = [0; FLOOR_PIECES];
    var starts: i64[FLOOR_PIECES] = [0; FLOOR_PIECES];
    var sizes:  i64[FLOOR_PIECES] = [0; FLOOR_PIECES];
    var pieces = 0;
    for row in 3 {
        guard rows[row + 1] > rows[row] else { continue; }
        for col in n_cuts + 1 {
            let left = if col > 0 { cuts[col - 1] } else { -1e9 };
            let right = if col < n_cuts { cuts[col] } else { 1e9 };
            guard right > left else { continue; }
            var kind = FLOOR_SHADE;
            if row == 1 {
                let mid = if col == 0 { right - 1.0 } else if col == n_cuts { left + 1.0 } else { 0.5 * (left + right) };
                for s in n_spans { if mid > spans[s].x && mid < spans[s].y { kind = FLOOR_LIT; } }
                if kind == FLOOR_LIT && mid > table.x && mid < table.y { kind = FLOOR_TABLE; }
            }
            let corners = piece(g, lo, hi, rows[row], rows[row + 1], left, right, j, face, nv);
            guard corners >= 3 else { continue; }
            kinds[pieces] = kind;
            starts[pieces] = nv;
            sizes[pieces] = corners;
            counts[kind] += 3 * (corners - 2);
            nv += corners;
            pieces++;
        }
    }
    // The indices, a fan a piece, kind by kind.
    var ni = 0;
    for kind in FLOOR_KINDS {
        g.sun.first[kind] = ni;
        g.sun.count[kind] = counts[kind];
        for p in pieces {
            guard kinds[p] == kind else { continue; }
            for t in 1..(sizes[p] - 1) {
                piece_indices[ni] = starts[p] as u32;
                piece_indices[ni + 1] = (starts[p] + t) as u32;
                piece_indices[ni + 2] = (starts[p] + t + 1) as u32;
                ni += 3;
            }
        }
    }
    return nv, ni;
}

// The cuts in increasing order (insertion: at most SUN_CUTS).
fn sort_cuts(c: f32[SUN_CUTS]&, n: i64) {
    for i in 1..n {
        let x = c[i];
        var k = i;
        while k > 0 && c[k - 1] > x {
            c[k] = c[k - 1];
            k--;
        }
        c[k] = x;
    }
}

// One piece of the floor into piece_verts from `at`: the rectangle lo..hi between rows v0
// and v1, clipped to the lines along the sun u + j (v + S) = left and right. Each corner is
// worked out from the line or edge it lies on alone, so the pieces either side of a cut
// share their corners exactly and the floor stays whole. How many corners.
fn piece(g: Gpu&, lo: float2, hi: float2, v0: f32, v1: f32, left: f32, right: f32, j: f32, face: f32, at: i64) -> i64 {
    var a: float2[PIECE_CORNERS] = [float2_0; PIECE_CORNERS];
    var b: float2[PIECE_CORNERS] = [float2_0; PIECE_CORNERS];
    a[0] = float2 { lo.x, v0 };
    a[1] = float2 { hi.x, v0 };
    a[2] = float2 { hi.x, v1 };
    a[3] = float2 { lo.x, v1 };
    var n = 4;
    for side in 2 {
        let c = if side == 0 { left } else { right };
        let keep = if side == 0 { 1.0 } else { -1.0 };
        var m = 0;
        for i in n {
            let p = a[i];
            let q = a[(i + 1) % n];
            let sp = keep * (p.x + j * (p.y + face) - c);
            let sq = keep * (q.x + j * (q.y + face) - c);
            if sp >= 0.0 && m < PIECE_CORNERS { b[m] = p; m++; }
            if (sp < 0.0) != (sq < 0.0) && m < PIECE_CORNERS {
                // A crossing on a row's edge (v fixed) or the floor's side (u fixed).
                b[m] = if p.y == q.y { float2 { c - j * (p.y + face), p.y } } else { float2 { p.x, (c - p.x) / j - face } };
                m++;
            }
        }
        for i in m { a[i] = b[i]; }
        n = m;
    }
    for i in n { piece_verts[at + i] = floor_vertex(g, a[i]); }
    return n;
}

// A floor vertex at (u, v): its attributes the floor's own there, from its corners.
fn floor_vertex(g: Gpu&, p: float2) -> corner_map::RoomVertex {
    let c = g.floor_corners;
    let s = (p.x - c[0].pos.x) / (c[2].pos.x - c[0].pos.x);
    let t = (p.y - c[0].pos.z) / (c[2].pos.z - c[0].pos.z);
    var v = c[0];
    v.pos = float3 { p.x, c[0].pos.y, p.y };
    v.uv = c[0].uv + (c[1].uv - c[0].uv) * s + (c[3].uv - c[0].uv) * t;
    v.corner = c[0].corner + (c[1].corner - c[0].corner) * s + (c[3].corner - c[0].corner) * t;
    return v;
}

// The pieces lying on the table (view3d::Scene.discs, taken3d::lay), each x, z, its foot's
// and its top's height over the table, all of radius r, for the shadows TABLE_FRAG and
// LIT_FRAG work out from them: the shadow map covers only the board.
let MAX_DISCS = 48;     // view3d::MAX_DISCS, FRAME's discs[48]
fn table_discs(g: Gpu&, discs: const float4[:], r: f32) {
    let n = min(discs.len, MAX_DISCS);
    var low = float2 { 1e6, 1e6 };
    var high = float2 { -1e6, -1e6 };
    var lo_y: f32 = 0.0;
    var hi_y: f32 = 0.0;
    for i in n {
        let d = discs[i];
        g.frame.discs[i] = d;
        let at = float2 { d.x, d.y };
        low = float2 { min(low.x, at.x), min(low.y, at.y) };
        high = float2 { max(high.x, at.x), max(high.y, at.y) };
        lo_y = min(lo_y, min(d.z, d.w));
        hi_y = max(hi_y, max(d.z, d.w));
    }
    let reach = r + max(0.35 * r, 0.015 + 0.1 * hi_y) + 0.01;
    g.frame.disc_n = float4 { n, r, lo_y, hi_y };
    g.frame.disc_bounds = float4 { low.x - reach, low.y - reach, high.x + reach, high.y + reach };
}

// Shows the table under the board or not; its maps are baked with the next theme put on
// (the caller puts it on again) or, where the theme is on, now.
fn set_table<O>(o: O&, g: Gpu&, on: bool) {
    guard on != g.table else { return; }
    g.table = on;
    table_maps(o, g);
    if on && g.side > 0 && g.look >= 0 {
        bake_table(o, g);
        o.gpu_flush();
    }
}

// Shows table `t` (a take, or one tuned): its mesh made again for a new edge, its wood
// baked again now where the theme is on.
fn tune_table<O>(o: O&, g: Gpu&, t: tables::Table) {
    g.table_spec = t;
    guard g.table && g.side > 0 && g.look >= 0 else { return; }
    bake_table(o, g);
    o.gpu_flush();
}

// Shows the library round the table or not (room_shell::LIBRARY): its oak is baked and
// its mesh made before the next draw (room_surfaces).
fn show_room(g: Gpu&, on: bool) { g.room_on = on; }

// The room's materials in groups, each drawn with a pipeline of its own whose shader holds
// only its materials' code: the floor; the walls' surfaces (the panelling oak, the paper,
// the plaster and the ceiling, the cord); the painted wood (the doors, their architraves,
// the windows' joinery and shutters); the sills' stone; the metals (the brass, the books
// with their gilt, and the stove's glaze), which see the room's box sharply. The glass and the lace are a
// shared mesh with an index range for each.
let GROUP_FLOOR = 0;
let GROUP_WALLS = 1;
let GROUP_PAINT = 2;
let GROUP_SILL = 3;
let GROUP_METALS = 4;
let ROOM_GROUPS = 5;
let GROUP_GLASS = ROOM_GROUPS;
let GROUP_LACE = ROOM_GROUPS + 1;
fn window_group(group: i64) -> bool { group == GROUP_GLASS || group == GROUP_LACE }
fn room_group(mat: f32) -> i64 {
    let kind = floor(mat + 0.001);
    if kind < surfaces::MAT_FLOOR + 0.5 { return GROUP_FLOOR; }
    if kind == surfaces::MAT_BRASS || kind >= surfaces::MAT_BOOK { return GROUP_METALS; }
    if kind == surfaces::MAT_PAINT { return GROUP_PAINT; }
    if kind == surfaces::MAT_STONE { return GROUP_SILL; }
    return GROUP_WALLS;
}

// The room's triangles sorted by group (room_group), each group's in its order: where each
// group's indices start.
fn by_group(room: corner_map::RoomVertex[>..]&, indices: u32[>..]&) -> i64[ROOM_GROUPS] {
    var sorted: u32[>..]         = [];
    var from:   i64[ROOM_GROUPS] = [0; ROOM_GROUPS];
    for k in ROOM_GROUPS {
        from[k] = sorted.len;
        var i = 0;
        while i < indices.len {
            if room_group(room[indices[i] as i64].mat) == k {
                for j in 0..3 { sorted.push(indices[i + j]); }
            }
            i += 3;
        }
    }
    for i in 0..indices.len { indices[i] = sorted[i]; }
    return from;
}

// Where group k's indices end.
fn group_end(g: Gpu&, k: i64) -> i64 { if k + 1 < ROOM_GROUPS { g.room_from[k + 1] } else { g.room_count } }

// Separate the window mesh's glass and lace, keeping the original triangle order within
// each range. The material is integral here, after the fold shade moved into the corner.
fn window_indices_by_group(verts: corner_map::RoomVertex[>..]&, indices: u32[>..]&) -> i64 {
    var sorted: u32[>..] = [];
    var lace_first = 0;
    for material in [surfaces::MAT_GLASS, surfaces::MAT_LACE] {
        lace_first = sorted.len;
        var i = 0;
        while i < indices.len {
            if verts[indices[i] as i64].mat == material {
                for j in 0..3 { sorted.push(indices[i + j]); }
            }
            i += 3;
        }
    }
    indices[..].move_from(sorted[..]);
    return lace_first;
}

fn room_index_range(g: Gpu&, group: i64) -> i64, i64 {
    if group == GROUP_GLASS { return 0, g.lace_first; }
    if group == GROUP_LACE { return g.lace_first, g.window_count - g.lace_first; }
    let first = g.room_from[group];
    return first, group_end(g, group) - first;
}

// The textures a group's shader reads, in its slots (shaders::ROOM_HEAD): the tree's
// and lace's maps, the light's, the group's own, the screen's maps (ssao), and the mirror.
let ROOM_TEXTURES = 13;
struct RoomTextures { tex: Texture[ROOM_TEXTURES], smp: Sampler[ROOM_TEXTURES], count: i64 }
fn add_texture(t: RoomTextures&, tex: Texture, smp: Sampler) {
    t.tex[t.count] = tex;
    t.smp[t.count] = smp;
    t.count += 1;
}
fn room_textures(g: Gpu&, group: i64, ssao: bool, planar: bool, mirror: bool = false) -> RoomTextures {
    var t = default<RoomTextures>();
    add_texture(t, tree_or_stand_in(g), g.linear);
    if window_map_read(g, group, mirror) { add_texture(t, g.window_map, g.linear); }
    else { add_texture(t, g.lace_mask, g.aniso); }
    if !window_group(group) {
        add_texture(t, light_or_stand_in(g), g.linear);
        add_texture(t, table_map_or_stand_in(g), g.compare);
        add_texture(t, corners_or_stand_in(g), g.linear);
    }
    let oak = g.aniso;
    if group == GROUP_FLOOR {
        // The woods' pictures in the room's own draw only: the mirror's world reads its fields.
        let fa, fn_ = wood_maps(g, WOOD_FLOOR, g.floor_albedo, g.floor_normal);
        add_texture(t, if mirror { g.floor_albedo } else { fa }, oak);
        add_texture(t, if mirror { g.floor_normal } else { fn_ }, oak);
        add_texture(t, g.floor_noise, g.linear);
        add_texture(t, g.scratch_tile, g.aniso);
        add_texture(t, g.rug_map, g.aniso);
    } else if group == GROUP_WALLS {
        let wa, wn = wood_maps(g, WOOD_OAK, g.wall_albedo, g.wall_normal);
        add_texture(t, if mirror { g.wall_albedo } else { wa }, oak);
        add_texture(t, if mirror { g.wall_normal } else { wn }, oak);
        add_texture(t, g.paper_mask, g.aniso);
        add_texture(t, g.plaster_tone, g.aniso);
    } else if group == GROUP_PAINT {
        add_texture(t, g.paint_tile, g.aniso);
    } else if group == GROUP_SILL {
        add_texture(t, g.stone_tile, g.aniso);
    } else if group == GROUP_METALS {
        add_texture(t, g.book_atlas, g.aniso);
        add_texture(t, g.stove_relief, g.aniso);
    }
    // The box's map after the floor's and metals' own, on the phone's tier (box_map).
    if g.room_boxed && !ssao && !planar && !mirror && (group == GROUP_FLOOR || group == GROUP_METALS) {
        add_texture(t, g.box_map, g.linear);
    }
    if group == GROUP_GLASS { add_texture(t, if g.glass_tile.id != 0 { g.glass_tile } else { g.crown_map }, g.aniso); }
    if ssao {
        add_texture(t, ssao_or_stand_in(g), g.linear);
        if !window_group(group) { add_texture(t, pre_place_or_stand_in(g), g.linear); }
        if group == GROUP_METALS { add_texture(t, if g.brass_tile.id != 0 { g.brass_tile } else { g.crown_map }, g.aniso); }
    }
    // The room's reflection on the floor under the physical light (refl_map), else a stand-in.
    if group == GROUP_FLOOR && ssao && !planar && !mirror && physical_coat {
        add_texture(t, if g.refl_map.id != 0 { g.refl_map } else { g.crown_map }, g.planar_sampler);
    }
    if planar { add_texture(t, g.planar_map, g.planar_sampler); }
    return t;
}

// Whether the board's pass draws the room.
fn room_shown(g: Gpu&) -> bool { g.room_on && g.room_baked && g.room_vb.id != 0 && g.room_walls.id != 0 }

// Whether the board's pass draws the view out of the shell's windows in place of the
// photograph.
fn outside_shown(g: Gpu&) -> bool {
    room_shown(g) && g.outside_on && g.outside_vb.id != 0 && g.outside.id != 0
}

// OUTSIDE_FRAG's block: the exposure (rooms::Room.outside), the sun disc's brightness; in
// the floor's mirror, z how much brighter the view out is than its look (rooms::Room.planar.w),
// drawn as its light before the tonemap; else 0.
// Then the sun's look (SunLook) and, out of the mirror, the tree seen round it.
struct OutsideBlock { exposure: float4, sun_disc: float4, sun_glare: float4, sun_tree: float4 }
// The sun in the view out (OUTSIDE_FRAG's sky and tree_seen): disc x its radius (degrees,
// the real sun's 0.27), y its limb's darkening, z its edge's softness (degrees), w its
// brightness over the sky's, linear; glare the haze's halo round it, x and y a tight core's
// strength and width (degrees), z and w a wider glow's; tree the tree outside against the
// sky near the sun: x the power its light through is taken to (0 none, 1 as its map, more
// denser), y how far from the sun (degrees), z its leaves' back light, w how sharp (the
// metres along the view it is looked up from; 0 the eye's blur). As made: the disc 0.27°,
// its edge a pixel, 30 over the sky; no tree.
// The tonemap's part of the sun (HDR_TONE_FRAG, HDR only): veil the eye's veiling glare round
// it, x its strength (linear light at the sun, 0 none), y the angle it halves at and z where
// it has faded out (degrees), w how far it turns amber away from the sun (1 white to (1,
// 0.82, 0.6) by 10°), scaled by how much of the sun is open, read from the glow's smallest
// level. As made a faint one, a third of look b's (the light tuner's --sun-look veil and --sun-eye).
struct SunLook {
    disc:  float4 = float4 { 0.27, 0.0, 0.0, 30.0 },
    glare: float4 = float4 { 1.5, 1.2, 0.4, 4.0 },
    tree:  float4 = float4_0,
    veil:  float4 = float4 { 1.0, 1.5, 20.0, 1.0 },
}
var sun_look = SunLook {};
// The camera's exposure for what is seen out of the windows, stops over the room's (the light
// tuner's --window-ev under --light physical): the outside and the tree through the glass, not
// their reflections. A camera's choice, as an HDR photograph's: the park lies 5 stops and more
// over the room, the concepts hold it about 2 over (task 122, 2026-11-27).
var window_ev: f32 = 0.0;
fn seen_outside(g: Gpu&) -> f32 { let two: f32 = 2.0; return g.room.outside * pow(two, window_ev); }
fn outside_block(g: Gpu&, in_mirror: bool = false) -> OutsideBlock {
    OutsideBlock { float4 { if in_mirror { g.room.outside } else { seen_outside(g) }, sun_look.disc.w, if in_mirror { max(g.room.planar.w, 1.0) } else { 0.0 }, sun_veil },
                   sun_look.disc, sun_look.glare,
                   if in_mirror || near_trees_left_out(g) { float4_0 }
                   else { float4 { sun_look.tree.x, sun_look.tree.y, sun_look.tree.z, sun_look.tree.w * surfaces::METRE } } }
}

// Whether the view out's near trees are left out of the main view: their pictures (the oak,
// the park's cards) and the maple seen from its shadow's map (tree_seen), where the maple
// is drawn as geometry (tree_draw wood or all). The mirror keeps them, as no geometry is
// drawn there. The far band stays.
fn near_trees_left_out(g: Gpu&) -> bool { tree_draw != TREE_OFF }

// How many of the view out's indices to draw (view_out::build's order).
fn outside_drawn(g: Gpu&, in_mirror: bool) -> i64 {
    if !in_mirror && near_trees_left_out(g) { g.outside_far_count } else { g.outside_count }
}

// An oak's bake (surfaces::Oak) in the slots of a theme BAKE_FRAG's oak reads.
fn oak_theme(g: Gpu&, oak: surfaces::Oak) -> looks::Theme {
    var t = look(g, max(g.look, 0));
    t.light_sq = oak.base;
    t.light_fig = oak.figure;
    t.light_ring = oak.ring;
    t.dark_sq = oak.stain;
    t.dark_fig = oak.wax;
    t.inlay = oak.shellac;
    t.inlay_fig = oak.age;
    t.surface = oak.boards;
    t.frame = oak.tint;
    return t;
}

// The room's oak baked into its two fields with their mips, once (a phone's at half the
// side), and its mesh made again when the room's frame moved: before a draw, outside a
// pass. Tens of milliseconds the first time.
fn room_surfaces<O>(o: O&, g: Gpu&) {
    guard g.room_on && g.look >= 0 else { return; }
    o.make_room(g);
    if !g.room_baked {
        let t0 = clock();
        let side = if g.side > 0 && g.side < model3d::BAKE_SIDE { surfaces::PHONE_FIELD_SIDE } else { surfaces::FIELD_SIDE };
        g.floor_albedo = baked(o, side, side, RGBA8_SRGB);
        g.floor_normal = baked(o, side, side, RGBA8);
        o.gpu_flush();
        put_floor_noise(o, g);
        put_scratch_tile(o, g);
        g.wall_albedo = baked(o, side, side, RGBA8_SRGB);
        g.wall_normal = baked(o, side, side, RGBA8);
        let finish = g.finish;
        g.finish = looks::Finish { varnish: 0.0, sanding: 0.0, grain: 1.0, rings: 1.0, warmth: 0.0, pickle: 0.0, caulk: 0.0 };
        var t = oak_theme(g, surfaces::FLOOR_OAK);
        o.bake(g, g.floor_albedo, g.floor_normal, side, side, 4.0, float2 { surfaces::FLOOR_FIELD, surfaces::FLOOR_FIELD }, t,
               0, -1, true, surfaces::FIELD_SIDE / side);
        t = oak_theme(g, surfaces::WALL_OAK);
        o.bake(g, g.wall_albedo, g.wall_normal, side, side, 5.0, float2 { surfaces::WALL_FIELD, surfaces::WALL_FIELD }, t,
               0, -1, true, surfaces::FIELD_SIDE / side);
        g.finish = finish;
        o.gpu_flush();
        put_paper(o, g);
        put_outside(o, g);
        g.room_side = side;
        g.room_baked = true;
        g.room_ms = (clock() - t0) * 1000.0;
    }
    put_paper(o, g);
    if g.stone_tile.id == 0 { put_stone(o, g); }
    if g.glass_tile.id == 0 { put_glass_tile(o, g); }
    if g.brass_tile.id == 0 && room_shell::box_window_on { put_brass_tile(o, g); }
    bake_room_light(o, g);
    // The view out of the shell's windows, round its middle window: made once, and again
    // with the shell's mesh where the games table moved in the plan (the room's frame is the
    // table's).
    let table_moved = !same2(room_shell::LIBRARY.table, g.shell_table);
    if table_moved && g.outside_vb.id != 0 {
        o.gpu_release_mesh(g.outside_vb, g.outside_ib);
        g.outside_vb = Buffer { 0 };
    }
    if g.outside_vb.id == 0 {
        var verts:   mesh::Vertex[>..] = [];
        var indices: u32[>..]          = [];
        g.outside_far_count = view_out::build(verts, indices, view_out::centre_of(room_shell::LIBRARY), park_ground);
        g.outside_vb, g.outside_ib = o.gpu_mesh(bytes_of(verts), bytes_of(indices));
        g.outside_count = indices.len;
    }
    // The mesh, in the room's frame (ROOM_VERT turns it with the key): made again only
    // where the shell's parts changed.
    let shell_key: f32 =
        (if g.books_off { 2.0 } else { 1.0 }) + (if room_shell::shutters_on { 0.0 } else { 2.0 }) + 32.0 * room_shell::lace_hang;
    let key = float4 { shell_key, 0.0, 0.0, 0.0 };
    // The corners' shade is baked with the mesh, again when the room's corners change, but
    // not while a slider is held.
    let corners = g.room.corners;
    let corners_moved = !same4(corners, g.corner_for) && !g.bake_held;
    guard g.room_vb.id == 0 || !same4(key, g.room_for) || corners_moved || table_moved else { return; }
    let t0 = clock();
    var verts:         mesh::Vertex[>..] = [];
    var indices:       u32[>..]          = [];
    var glass:         mesh::Vertex[>..] = [];
    var glass_indices: u32[>..]          = [];
    room_shell::build(verts, indices, glass, glass_indices, room_shell::LIBRARY, !g.books_off);
    // Each vertex with its place in the corners' map, and the glass's holds the fraction of its material, whole across each triangle
    // (the lace's: what its folds hide, room_shell::fold_hidden).
    var room:         corner_map::RoomVertex[>..] = [];
    var room_indices: u32[>..]                    = [];
    corner_map::lay_out(verts, indices, surfaces::METRE, room, room_indices);
    g.room_from = by_group(room, room_indices);
    // The cheap mirror world's triangles after the groups': the walls' to the metals' less
    // what is small (mirror_cheap).
    g.cheap_from = room_indices.len;
    if mirror_cheap {
        for i in g.room_from[GROUP_WALLS]..g.cheap_from {
            if i % 3 == 0 && floor(room[room_indices[i] as i64].mat + 0.001) != surfaces::MAT_CORD {
                for j in 0..3 { room_indices.push(room_indices[i + j]); }
            }
        }
    }
    g.cheap_count = room_indices.len - g.cheap_from;
    g.floor_corners = floor_corners_of(room);
    var glass_room: corner_map::RoomVertex[>..] = [];
    for v in glass {
        let kind = floor(v.mat);
        let whole = mesh::Vertex { v.pos, v.normal, v.uv, v.ao, kind };
        glass_room.push(corner_map::room_vertex(whole, float2 { v.mat - kind, 0.0 }, float2_0));
    }
    keep_window_verts(glass_room);
    if g.room_vb.id != 0 { o.gpu_release_mesh(g.room_vb, g.room_ib); }
    if g.window_vb.id != 0 { o.gpu_release_mesh(g.window_vb, g.window_ib); }
    g.room_vb, g.room_ib = o.gpu_mesh(bytes_of(room), bytes_of(room_indices));
    g.room_count = g.cheap_from;
    g.window_count = glass_indices.len;
    g.lace_first = window_indices_by_group(glass_room, glass_indices);
    if g.window_count > 0 { g.window_vb, g.window_ib = o.gpu_mesh(bytes_of(glass_room), bytes_of(glass_indices)); }
    else {
        g.window_vb = Buffer { 0 };
        g.window_ib = Buffer { 0 };
    }
    g.room_for = key;
    g.shell_table = room_shell::LIBRARY.table;
    if lace_lit_once { lace_into_mesh(o, g); }
    g.mesh_ms = (clock() - t0) * 1000.0;
    if g.corner_map.id != 0 {
        o.gpu_flush();
        o.gpu_release(g.corner_map);
        g.corner_map = Texture { 0 };
    }
    g.corner_for = corners;
    let t1 = clock();
    var planes = corner_planes(g);
    corner_map::bake(planes, verts, indices);
    g.corner_map = o.gpu_sampled(corner_map::WIDTH, corner_map::rows, 1, R8);
    o.gpu_upload(g.corner_map, 0, corner_map::atlas[0..corner_map::WIDTH * corner_map::rows]);
    g.corner_ms = (clock() - t1) * 1000.0;
}

// What the corners' shade is baked from: the shell's planes and the room's corners, as
// ROOM_FRAG's block has them.
fn corner_planes(g: Gpu&) -> corner_map::Planes {
    let b = surfaces_block(g);
    corner_map::Planes { b.shell, b.shell_mids, b.shell_niche, b.shell_glass, b.room_box, b.room_doors, b.room_heights,
                         b.book_cases, b.corners }
}

// The corners' map to bind, or another texture where none is made: ROOM_FRAG reads it only
// in the shell.
fn corners_or_stand_in(g: Gpu&) -> Texture { if g.corner_map.id != 0 { g.corner_map } else { g.crown_map } }

// The floor's scratches' tile put on the GPU with its mips, once with the room's bake.
fn put_scratch_tile<O>(o: O&, g: Gpu&) {
    var px: u8[>..] = [];
    surfaces::scratch_tile(px);
    g.scratch_tile = o.gpu_sampled(surfaces::SCRATCH_SIDE, surfaces::SCRATCH_SIDE, surfaces::SCRATCH_MIPS, R8);
    var at = 0;
    for level in surfaces::SCRATCH_MIPS {
        let w = surfaces::SCRATCH_SIDE >> level;
        o.gpu_upload(g.scratch_tile, level, px[at..at + w * w]);
        at += w * w;
    }
}

// The floor's slow noises put on the GPU, once with the room's bake.
fn put_floor_noise<O>(o: O&, g: Gpu&) {
    var px: u8[>..] = [];
    surfaces::floor_noise(px);
    g.floor_noise = o.gpu_sampled(surfaces::FLOOR_NOISE_SIDE, surfaces::FLOOR_NOISE_SIDE, 1, RG8);
    o.gpu_upload(g.floor_noise, 0, px[..]);
}

// The room's masks decoded (src/native/materials.c) and put on the GPU with their mips:
// the wallpaper's, the plaster's tone, once with the room's bake; the curtains' lace, again
// when another way of it is asked for (the tuner's).
fn put_paper<O>(o: O&, g: Gpu&) {
    if g.lace_mask.id != 0 && g.lace_put != g.lace_way {
        o.gpu_release(g.lace_mask);
        g.lace_mask = Texture { 0 };
    }
    if g.lace_mask.id == 0 {
        g.lace_mask = put_lace(o);
        g.lace_put = g.lace_way;
    }
    guard g.paper_mask.id == 0 else { return; }
    g.paper_mask = if paper_close_on() { put_paper_with_grain(o) } else { put_mask(o, 0) };
    g.plaster_tone = put_mask(o, 1);
    g.book_atlas = put_books(o);
    g.rug_map = put_rug(o);
    g.tapestry_map = put_tapestry(o);
    var relief: u8[>..] = [];
    room_shell::stove_relief(relief);
    g.stove_relief = put_rgba(o, relief, room_shell::STOVE_RELIEF_SIDE, room_shell::STOVE_RELIEF_SIDE, room_shell::STOVE_RELIEF_MIPS);
    let t0 = clock();
    var px: u8[>..] = [];
    room_shell::relief_tile(px);
    g.paint_tile = o.gpu_sampled(room_shell::RELIEF_SIDE, room_shell::RELIEF_SIDE, room_shell::RELIEF_MIPS, RGBA8);
    var at = 0;
    for level in room_shell::RELIEF_MIPS {
        let w = room_shell::RELIEF_SIDE >> level;
        o.gpu_upload(g.paint_tile, level, px[at..at + 4 * w * w]);
        at += 4 * w * w;
    }
    g.paint_tile_ms = (clock() - t0) * 1000.0;
}

// The sills' limestone tile made and put on the GPU with its mips.
fn put_stone<O>(o: O&, g: Gpu&) {
    let t0 = clock();
    var px: u8[>..] = [];
    room_shell::stone_tile(px);
    g.stone_tile = o.gpu_sampled(room_shell::STONE_SIDE, room_shell::STONE_SIDE, room_shell::STONE_MIPS, RGBA8);
    var at = 0;
    for level in room_shell::STONE_MIPS {
        let w = room_shell::STONE_SIDE >> level;
        o.gpu_upload(g.stone_tile, level, px[at..at + 4 * w * w]);
        at += 4 * w * w;
    }
    g.stone_tile_ms = (clock() - t0) * 1000.0;
}

// The window hardware's brass tile made and put on the GPU with its mips.
fn put_brass_tile<O>(o: O&, g: Gpu&) {
    let t0 = clock();
    var px: u8[>..] = [];
    room_shell::brass_tile(px);
    g.brass_tile = put_rgba(o, px, room_shell::BRASS_SIDE, room_shell::BRASS_SIDE, room_shell::BRASS_MIPS);
    g.brass_tile_ms = (clock() - t0) * 1000.0;
}

// The glass's wiping tile made and put on the GPU with its mips.
fn put_glass_tile<O>(o: O&, g: Gpu&) {
    let t0 = clock();
    var px: u8[>..] = [];
    glass_tile::make(GLASS_SEED, glass_tile::Strokes {}, px);
    g.glass_tile = o.gpu_sampled(glass_tile::SIDE, glass_tile::SIDE, glass_tile::MIPS, RGBA8);
    var at = 0;
    for level in glass_tile::MIPS {
        let w = glass_tile::SIDE >> level;
        o.gpu_upload(g.glass_tile, level, px[at..at + 4 * w * w]);
        at += 4 * w * w;
    }
    g.glass_tile_ms = (clock() - t0) * 1000.0;
}
let GLASS_SEED: u64 = 7;

// The books' atlas (design/materials/books_atlas.png) on the GPU, RGBA8 with BOOK_MIPS, each
// level the mean of four of the level above; blank where it isn't built in.
let BOOK_MIPS = 4;
extern fn draughts_book_atlas(out: u8[:], w: i64, h: i64) -> bool;
fn put_books<O>(o: O&) -> Texture {
    var px: u8[>..] = [];
    px.resize(rgba_bytes(books::ATLAS_W, books::ATLAS_H, BOOK_MIPS), 0);
    draughts_book_atlas(px[0..4 * books::ATLAS_W * books::ATLAS_H], books::ATLAS_W, books::ATLAS_H);
    return put_rgba(o, px, books::ATLAS_W, books::ATLAS_H, BOOK_MIPS);
}

// The rug under the games table (design/materials/rug.png, tools/materials/rug.py) on the
// GPU, RGBA8 (the pile's albedo at a 2.2 gamma, A 1) with RUG_MIPS; blank where it isn't
// built in. ROOM_FRAG lays it over the floor round the table (its rug).
let RUG_W = 1200;
let RUG_H = 800;
let RUG_MIPS = 5;
extern fn draughts_rug(out: u8[:], w: i64, h: i64) -> bool;
fn put_rug<O>(o: O&) -> Texture {
    var px: u8[>..] = [];
    px.resize(rgba_bytes(RUG_W, RUG_H, RUG_MIPS), 0);
    draughts_rug(px[0..4 * RUG_W * RUG_H], RUG_W, RUG_H);
    return put_rgba(o, px, RUG_W, RUG_H, RUG_MIPS);
}

// The chairs' tapestry (design/materials/tapestry.png, tools/materials/tapestry.py) on the
// GPU, RGBA8 (its tile's albedo at a 2.2 gamma, A 1, 240 mm of cloth) with its mips; blank
// where it isn't built in. TABLE_FRAG covers the chairs' seats and backs with it.
let TAPESTRY_SIDE = 512;
let TAPESTRY_MIPS = 10;
extern fn draughts_tapestry(out: u8[:], w: i64, h: i64) -> bool;
fn put_tapestry<O>(o: O&) -> Texture {
    var px: u8[>..] = [];
    px.resize(rgba_bytes(TAPESTRY_SIDE, TAPESTRY_SIDE, TAPESTRY_MIPS), 0);
    draughts_tapestry(px[0..4 * TAPESTRY_SIDE * TAPESTRY_SIDE], TAPESTRY_SIDE, TAPESTRY_SIDE);
    return put_rgba(o, px, TAPESTRY_SIDE, TAPESTRY_SIDE, TAPESTRY_MIPS);
}

// The tapestry to bind, or the crown's map where it isn't put (the table's room pipelines read it
// only on the chairs).
fn tapestry_or_stand_in(g: Gpu&) -> Texture { if g.tapestry_map.id != 0 { g.tapestry_map } else { g.crown_map } }

// The bytes of a w0 × h0 RGBA8 picture with `mips` levels.
fn rgba_bytes(w0: i64, h0: i64, mips: i64) -> i64 {
    var total = 0;
    for level in mips { total += 4 * (w0 >> level) * (h0 >> level); }
    return total;
}

// An RGBA8 picture on the GPU (or `format`'s), its top level first in px and the rest made there, each level
// the mean of four of the level above.
fn put_rgba<O>(o: O&, px: u8[>..]&, w0: i64, h0: i64, mips: i64, format: i32 = RGBA8) -> Texture {
    let tex = o.gpu_sampled(w0, h0, mips, format);
    var at = 0;
    for level in mips {
        let w = w0 >> level;
        let h = h0 >> level;
        if level > 0 {
            let up = at - 4 * 4 * w * h;
            for y in h {
                for x in w {
                    for c in 4 {
                        let a = up + 4 * (2 * y * 2 * w + 2 * x) + c;
                        let sum = px[a] as i64 + px[a + 4] + px[a + 8 * w] + px[a + 8 * w + 4];
                        px[at + 4 * (y * w + x) + c] = ((sum + 2) / 4) as u8;
                    }
                }
            }
        }
        o.gpu_upload(tex, level, px[at..at + 4 * w * h]);
        at += 4 * w * h;
    }
    return tex;
}

// The lace on the GPU, R8 with its mips down to where its sides stay even: the built-in
// one, or lace_png where the light tuner set it (its spare ways, read from files).
var lace_png: const u8[:] = "";
extern fn draughts_lace_mask(out: u8[:], w: i64, h: i64) -> bool;
extern fn draughts_gray_png(png: const u8[:], out: u8[:], w: i64, h: i64) -> bool;
fn put_lace<O>(o: O&) -> Texture {
    let size = surfaces::LACE_TEXELS;
    var px: u8[>..] = [];
    px.resize(lace_bytes(), 0);
    if lace_png.len > 0 { draughts_gray_png(lace_png, px[0..size.x * size.y], size.x, size.y); }
    else { draughts_lace_mask(px[0..size.x * size.y], size.x, size.y); }
    let mask = o.gpu_sampled(size.x, size.y, surfaces::LACE_MIPS, R8);
    var at = 0;
    for level in surfaces::LACE_MIPS {
        let w = size.x >> level;
        let h = size.y >> level;
        if level > 0 {
            let up = at - 4 * w * h;
            for y in h {
                for x in w {
                    let a = up + 2 * y * 2 * w + 2 * x;
                    let sum = px[a] as i64 + px[a + 1] + px[a + 2 * w] + px[a + 2 * w + 1];
                    px[at + y * w + x] = ((sum + 2) / 4) as u8;
                }
            }
        }
        o.gpu_upload(mask, level, px[at..at + w * h]);
        at += w * h;
    }
    return mask;
}

// The lace's texels with its mips.
fn lace_bytes() -> i64 {
    var sum = 0;
    for level in surfaces::LACE_MIPS { sum += (surfaces::LACE_TEXELS.x >> level) * (surfaces::LACE_TEXELS.y >> level); }
    return sum;
}

// The view out's two pictures (src/native/materials.c) on the GPU, as stored: sRGB,
// premultiplied in linear light, no mips, as they are only ever magnified. Once, with the
// room's bake; 0 where they aren't built in.
extern fn draughts_outside_picture(which: i64, out: u8[:], w: i64, h: i64) -> bool;
fn put_outside<O>(o: O&, g: Gpu&) {
    guard g.outside_band.id == 0 else { return; }
    g.outside_band = put_picture(o, 0, view_out::BAND_TEXELS);
    g.outside_oak = put_picture(o, 1, view_out::OAK_TEXELS);
}
fn put_picture<O>(o: O&, which: i64, size: int2) -> Texture {
    var px: u8[>..] = [];
    px.resize(4 * size.x * size.y, 0);
    guard draughts_outside_picture(which, px[..], size.x, size.y) else { return Texture { 0 }; }
    if which == 1 { soften(px, size, view_out::OAK_SOFT); }
    let t = o.gpu_sampled(size.x, size.y, 1, RGBA8_SRGB);
    o.gpu_upload(t, 0, px[..]);
    return t;
}

// A picture (sRGB, premultiplied in linear light) blurred by a Gaussian of `sigma` texels in
// linear light, colour and coverage alike, so its edges go soft as out of focus: the oak
// outside, once when it is put on the GPU.
fn soften(px: u8[>..]&, size: int2, sigma: f32) {
    guard sigma > 0.0 else { return; }
    var to_linear: f32[256] = [0.0; 256];
    for i in 256 { to_linear[i] = rooms::srgb_linear(i / 255.0); }
    let n = size.x * size.y;
    var a: float4[>..] = [];
    a.resize(n, float4_0);
    var b: float4[>..] = [];
    b.resize(n, float4_0);
    for i in n {
        a[i] = float4 { to_linear[px[4 * i]], to_linear[px[4 * i + 1]], to_linear[px[4 * i + 2]], px[4 * i + 3] / 255.0 };
    }
    let reach = min((3.0 * sigma) as i64 + 1, 24);
    var w:     f32[49] = [0.0; 49];
    var total: f32     = 0.0;
    for k in 2 * reach + 1 {
        let d = (k - reach) as f32;
        w[k] = exp(-0.5 * d * d / (sigma * sigma));
        total += w[k];
    }
    for k in 2 * reach + 1 { w[k] = w[k] / total; }
    blur_line(a, b, size, w, reach, true);
    blur_line(b, a, size, w, reach, false);
    for i in n {
        let c = a[i];
        px[4 * i] = srgb_byte(c.x);
        px[4 * i + 1] = srgb_byte(c.y);
        px[4 * i + 2] = srgb_byte(c.z);
        px[4 * i + 3] = (clamp(c.w, 0.0, 1.0) * 255.0 + 0.5) as u8;
    }
}

// soften()'s blur one way, from `from` into `to`, by the weights w over ±reach.
fn blur_line(from: float4[>..]&, to: float4[>..]&, size: int2, w: f32[49]&, reach: i64, across: bool) {
    for y in size.y {
        for x in size.x {
            var c = float4_0;
            for k in 2 * reach + 1 {
                let sx = if across { clamp(x + k - reach, 0, size.x - 1) } else { x };
                let sy = if across { y } else { clamp(y + k - reach, 0, size.y - 1) };
                c = c + from[sy * size.x + sx] * w[k];
            }
            to[y * size.x + x] = c;
        }
    }
}

// A linear value as an sRGB byte.
fn srgb_byte(v: f32) -> u8 {
    let c = clamp(v, 0.0, 1.0);
    let e: f32 = 1.0 / 2.4;
    let s = if c <= 0.0031308 { c * 12.92 } else { 1.055 * pow(c, e) - 0.055 };
    return (s * 255.0 + 0.5) as u8;
}

// Mask `which` (draughts_material_mask's) on the GPU, R8 with its mips, each level the
// mean of four texels of the one above; 0 where it isn't built in.
extern fn draughts_material_mask(which: i64, out: u8[:], side: i64) -> bool;
// The wallpaper's mask read from a file in place of the built-in one, where the light tuner
// set it (--paper-mask: the engraved one, tools/materials/wallpaper_engrave.py).
var paper_png: const u8[:] = "";
fn material_mask(which: i64, out: u8[:], side: i64) {
    if which == 0 && paper_png.len > 0 { draughts_gray_png(paper_png, out, side, side); }
    else { draughts_material_mask(which, out, side); }
}
fn put_mask<O>(o: O&, which: i64) -> Texture {
    let side = surfaces::PAPER_SIDE;
    var mips = 0;
    while side >> mips > 0 { mips++; }
    var px: u8[>..] = [];
    px.resize(texels_with_mips(side), 0);
    material_mask(which, px[0..side * side], side);
    let mask = o.gpu_sampled(side, side, mips, R8);
    var at = 0;
    for level in mips {
        let s = side >> level;
        if level > 0 {
            let up = at - 4 * s * s;
            for y in s {
                for x in s {
                    let a = up + 2 * y * 2 * s + 2 * x;
                    let sum = px[a] as i64 + px[a + 1] + px[a + 2 * s] + px[a + 2 * s + 1];
                    px[at + y * s + x] = ((sum + 2) / 4) as u8;
                }
            }
        }
        o.gpu_upload(mask, level, px[at..at + s * s]);
        at += s * s;
    }
    return mask;
}

// The wallpaper's mask with the paper's grain beside it, RG8 with its mips: r the mask as
// put_mask puts it, g the grain (paper_grain), for ROOM_FRAG's paper_close.
fn put_paper_with_grain<O>(o: O&) -> Texture {
    let side = surfaces::PAPER_SIDE;
    var mips = 0;
    while side >> mips > 0 { mips++; }
    var mask: u8[>..] = [];
    mask.resize(side * side, 0);
    material_mask(0, mask[..], side);
    var px: u8[>..] = [];
    px.resize(2 * texels_with_mips(side), 0);
    for y in side {
        for x in side {
            px[2 * (y * side + x)] = mask[y * side + x];
            px[2 * (y * side + x) + 1] = (clamp(paper_grain(x, y, side), 0.0, 1.0) * 255.0 + 0.5) as u8;
        }
    }
    let tex = o.gpu_sampled(side, side, mips, RG8);
    var at = 0;
    for level in mips {
        let s = side >> level;
        if level > 0 {
            let up = at - 8 * s * s;
            for y in s {
                for x in s {
                    for c in 2 {
                        let a = up + 2 * (2 * y * 2 * s + 2 * x) + c;
                        let sum = px[a] as i64 + px[a + 2] + px[a + 4 * s] + px[a + 4 * s + 2];
                        px[at + 2 * (y * s + x) + c] = ((sum + 2) / 4) as u8;
                    }
                }
            }
        }
        o.gpu_upload(tex, level, px[at..at + 2 * s * s]);
        at += 2 * s * s;
    }
    return tex;
}

// The paper's grain at texel (x, y) of a tile `side` a side, repeating with it: three value
// noises 2, 4 and 8 texels a cell, the finest the most, about 0.5 with a spread of 0.25.
fn paper_grain(x: i64, y: i64, side: i64) -> f32 {
    return 0.5 + 0.9 * (grain_noise(x, y, side, 2, 0.0) - 0.5) + 0.7 * (grain_noise(x, y, side, 4, 11.0) - 0.5)
               + 0.5 * (grain_noise(x, y, side, 8, 23.0) - 0.5);
}

// A value noise over texel (x, y)'s middle, `cell` texels a cell, its lattice repeating
// every `side` texels (surfaces::floor_hash's hashes, shifted by `seed`).
fn grain_noise(x: i64, y: i64, side: i64, cell: i64, seed: f32) -> f32 {
    let cells = side / cell;
    let fx: f32 = (x as f32 + 0.5) / cell;
    let fy: f32 = (y as f32 + 0.5) / cell;
    let ix = floor(fx);
    let iy = floor(fy);
    let ux = (fx - ix) * (fx - ix) * (3.0 - 2.0 * (fx - ix));
    let uy = (fy - iy) * (fy - iy) * (3.0 - 2.0 * (fy - iy));
    let i0 = (ix as i64) % cells;
    let j0 = (iy as i64) % cells;
    let i1: f32 = ((i0 + 1) % cells) as f32 + seed;
    let j1: f32 = ((j0 + 1) % cells) as f32 + seed;
    let a = surfaces::floor_hash(i0 as f32 + seed, j0 as f32 + seed);
    let b = surfaces::floor_hash(i1, j0 as f32 + seed);
    let c = surfaces::floor_hash(i0 as f32 + seed, j1);
    let d = surfaces::floor_hash(i1, j1);
    let low = a + (b - a) * ux;
    return low + (c + (d - c) * ux - low) * uy;
}

// A square texture's texels, `side` a side, with all its mips.
fn texels_with_mips(side: i64) -> i64 {
    var level = side * side;
    var sum = 0;
    while level > 0 {
        sum += level;
        level = level / 4;
    }
    return sum;
}

// The fields' memory in bytes: two RGBA8 targets each, with their mips; the three
// masks, one byte a texel; the view out's two pictures, four.
fn room_bytes(g: Gpu&) -> i64 {
    guard g.room_side > 0 else { return 0; }
    let grain = if paper_close_on() { texels_with_mips(surfaces::PAPER_SIDE) } else { 0 };
    let paper = if g.paper_mask.id != 0 { 2 * texels_with_mips(surfaces::PAPER_SIDE) + grain + lace_bytes() } else { 0 };
    let b = view_out::BAND_TEXELS;
    let k = view_out::OAK_TEXELS;
    let outside = if g.outside_band.id != 0 { 4 * (b.x * b.y + k.x * k.y) } else { 0 };
    let relief = if g.paint_tile.id != 0 { room_shell::relief_bytes() } else { 0 };
    let stone = if g.stone_tile.id != 0 { room_shell::stone_bytes() } else { 0 };
    let glass = if g.glass_tile.id != 0 { glass_tile::bytes() } else { 0 };
    let brass = if g.brass_tile.id != 0 { room_shell::brass_bytes() } else { 0 };
    let floor = if g.floor_noise.id != 0 { 2 * surfaces::FLOOR_NOISE_SIDE * surfaces::FLOOR_NOISE_SIDE } else { 0 };
    let scratches = if g.scratch_tile.id != 0 { texels_with_mips(surfaces::SCRATCH_SIDE) } else { 0 };
    let rug = if g.rug_map.id != 0 { rgba_bytes(RUG_W, RUG_H, RUG_MIPS) } else { 0 };
    let tapestry = if g.tapestry_map.id != 0 { rgba_bytes(TAPESTRY_SIDE, TAPESTRY_SIDE, TAPESTRY_MIPS) } else { 0 };
    let stove = if g.stove_relief.id != 0 { room_shell::stove_relief_bytes() } else { 0 };
    return 4 * 4 * texels_with_mips(g.room_side) + paper + outside + relief + stone + glass + brass + floor + scratches + rug + tapestry + stove;
}

// ROOM_FRAG's block: surfaces::Look, the room's frame, where its walls and fields are, the
// room's shade (rooms::Room.bounce, linear, times its strength) and own exposure, and the
// wall a tile of the wallpaper, the plaster's tone and the lace covers; the curtains' brass
// and the window's light behind their lace (linear, exposed as the view out).
struct SurfacesBlock {
    plank:         float4,
    planks:        float4,
    worn:          float4,
    paper:         float4,
    gold:          float4,
    axes:          float4,
    place:         float4,
    shade:         float4,
    tile:          float4,
    plaster_shade: float4,
    plaster_light: float4,
    ceiling_shade: float4,
    ceiling_light: float4,
    paint:         float4,
    lace_thread:   float4,
    shell:         float4,
    shell_mids:    float4,
    shell_niche:   float4,
    shell_glass:   float4,
    stone:         float4,
    shell_ends:    float4,
    brass:         float4,
    lace_light:    float4,
    table:         float4,
    shell_sun:     float4,
    room_baked:    float4,
    light_box:     float4,
    light_grid:    float4,
    room_box:      float4,
    room_doors:    float4,
    room_heights:  float4,
    books:         float4,
    book_cases:    float4,
    corners:       float4,
    ssao:          float4,
    planar:        float4,
    planar_look:   float4,
    contact:       float4,
    sheen:         float4,
    room_sun:      float4,
    paint_quiet:   float4,
    paper_detail:  float4,         // the wallpaper close up (paper_detail)
    sill:          float4,
    lace_back:     float4,         // the light on the lace's window side, its mean over the cloth (lace_on_vertices)
    physical:      float4,         // the lace's light from the room (probes_on_lace) and stove_glaze
    window_view:   float4,
    shell_case:    float4,
    lace_shade:    float4,
    table_map:     float4[4],
    book_cover:    float4[32],
    book_label:    float4[8],
    wood_oak:      float4[5],      // the panelling's finish (Wood, wood_rows)
    wood_floor:    float4[5],      // the floor's
    window_metal:  float4,         // room_shell::window_metal, last so room_fixed's spans stay
    env_pano:      float4[3],      // the light tuner's panoramas (env_pano)
    refl:          float4,         // the room's reflection: its probe (world), its levels (0 none)
}
fn surfaces_block(g: Gpu&) -> SurfacesBlock {
    var b = room_block(g);
    guard g.room_on else { return b; }
    // The shell's windows, which light the room in its place (shaders::LIGHT_FN's
    // shell_open), the lace letting through what the room's curtain does.
    let s = room_shell::LIBRARY;
    let metre = surfaces::METRE;
    var mids: f32[3] = [0.0; 3];
    var n = 0;
    var o = s.openings[0];
    for k in s.count {
        guard s.openings[k].kind == room_shell::WINDOW && n < 3 else { continue; }
        o = s.openings[k];
        mids[n] = (s.table.x - o.mid) * metre;
        n++;
    }
    b.shell = float4 { n, shell_face(s), surfaces::FLOOR_Y, metre };
    b.shell_mids = float4 { mids[0], mids[1], mids[2], room_shell::lace_hang };
    b.shell_niche = float4 { 0.5 * o.width, o.sill, o.height, o.rise };
    b.shell_glass = float4 { o.glass.x * metre, o.glass.y * metre, room_shell::LACE_OFF * metre,
                             if lace_lit(g) { -lace_slant.x } else { g.room.opening.w } };
    // The end walls' u, for the floor's darker band along every wall.
    let stove_end = room_shell::room_of(s, s.walls[room_shell::STOVE_WALL].a);
    let far_end = room_shell::room_of(s, s.walls[room_shell::FAR_WALL].a);
    // z: 1 where the window's light map holds the tree's light (window_map_tree); w 1 with the rug, 2 more
    // with the chairs.
    b.shell_ends = float4 { stove_end.x, far_end.x, if window_map_shown(g) && window_map_tree(g) { 1.0 } else { 0.0 },
                            (if g.rug_off || g.rug_map.id == 0 { 0.0 } else { 1.0 }) + (if g.chairs && g.chairs_made { 2.0 } else { 0.0 }) };
    // Its own sun, and its baked light where it is made.
    let r = g.room;
    b.shell_sun = float4 { r.shell_sun.x, r.shell_sun.y, g.room_tint.z, g.room_tint.w };
    if light_baked(g) && g.light_volume.id != 0 {
        b.room_baked = float4 { 1.0, shade_fill, r.baked.z, r.baked.w };
        b.light_box = light_box_of();
        b.light_grid = light_grid_of();
        // The box the reflections meet, and its doors.
    }
    // The box the reflections meet and the corners darken in.
    let near = room_shell::room_of(s, float2 { s.walls[room_shell::FAR_WALL].a.x, s.walls[room_shell::WINDOW_WALL].a.y });
    let far = room_shell::room_of(s, float2 { s.walls[room_shell::STOVE_WALL].a.x, s.walls[room_shell::HALL_WALL].a.y });
    b.room_box = float4 { near.x, far.x, near.y, far.y };
    b.corners = float4 { r.corners.x, r.corners.y * metre, 0.0, 0.0 };
    // The doors, for the reflections' box and the floor before them.
    var doors = float4_0;
    var top: f32 = 0.0;
    for k in s.count {
        let d = s.openings[k];
        guard d.kind == room_shell::DOOR else { continue; }
        let wl = s.walls[d.wall];
        let at = wl.a + normalize(wl.b - wl.a) * d.mid;
        let mid = room_shell::room_of(s, at);
        let half = (0.5 * d.width + room_shell::ARCHITRAVE) * metre;
        if d.wall == room_shell::HALL_WALL { doors.x = mid.x; doors.y = half; } else { doors.z = mid.y; doors.w = half; }
        top = d.height + room_shell::ARCHITRAVE;
    }
    b.room_doors = doors;
    b.room_heights = float4 { surfaces::FLOOR_Y + s.ceiling * metre, top, room_shell::WAINSCOT_TOP, room_shell::ARCHITRAVE };
    // The bookcases either side of the hall door, for the reflections: their middles' distance
    // from the door's along u, their half width (world units), their top (metres).
    for k in s.count {
        let c = s.openings[k];
        guard c.kind == room_shell::BOOKCASE else { continue; }
        let door = room_shell::door_mid(s, c.wall);
        b.book_cases = float4 { abs(c.mid - door) * metre, 0.5 * c.width * metre, c.height, 0.0 };
    }
    if g.refl_map.id != 0 && refl_on && physical_coat {
        let p = refl_probe_of(b);
        b.refl = float4 { p.x, p.y, p.z, REFL_LEVELS as f32 };
    }
    return b;
}

fn room_block(g: Gpu&) -> SurfacesBlock {
    let k = surfaces::LOOK;
    let f = g.room_frame;
    let tile = if g.paper_tile > 0.0 { g.paper_tile } else { surfaces::PAPER_TILE };
    // The window wall's and the far wall's v, the shell's.
    let s = room_shell::LIBRARY;
    let window_v = shell_face(s);
    let away = s.table.y * surfaces::METRE;
    // The floor's planks' cup and tilt as the tuner sets them (floor_shape), else the look's.
    let plank = if floor_shape.x >= 0.0 { float4 { k.plank.x, k.plank.y, k.plank.z, floor_shape.x } } else { k.plank };
    let planks = if floor_shape.y >= 0.0 { float4 { k.planks.x, k.planks.y, floor_shape.y, k.planks.w } } else { k.planks };
    // The lace as room_light describes it (task 124), lit by the bake's light.
    let described = lace_lit(g);
    SurfacesBlock { plank, planks, k.worn, paper_ground, paper_gold, float4 { f.along.x, f.along.y, f.into.x, f.into.y },
                    float4 { window_v, away, surfaces::FLOOR_FIELD, surfaces::WALL_FIELD },
                    model3d::f4(rooms::color_of(g.room.bounce) * g.room.bounce.w, g.room.room_exposure),
                    float4 { tile, surfaces::PLASTER_TILE, surfaces::LACE_TILE, if paper_metal { 1.0 } else { 0.0 } }, k.plaster_shade, k.plaster_light,
                    k.ceiling_shade, k.ceiling_light, k.paint,
                    k.lace_thread, float4_0, float4_0, float4_0, float4_0, k.stone, float4_0, k.brass,
                    model3d::f4(rooms::color_of(k.lace_light) * g.room.outside, k.lace_light.w),
                    float4 { mesh::TABLE_R, surfaces::FLOOR_Y, g.room_tint.x, g.room_tint.y }, float4 { 0.0, 1.0, 0.0, 0.0 },
                    float4_0, float4_0, float4_0, float4_0, float4_0, float4_0,
                    float4 { if g.book_fade > 0.0 { g.book_fade } else { 1.0 }, books::FADE_MAX / books::FADE_STEPS, books::CODES, 0.0 },
                    float4_0, float4_0, ssao_block_of(g), planar_block_of(g), planar_look_of(g), contact_block_of(g), sheen_look, room_sun,
                    float4 { k.paint_quiet.x, k.paint_quiet.y, k.paint_quiet.z, k.paint_quiet.w * paint_relief }, paper_detail, k.sill,
                    if described { model3d::f4(lace_back_mean, lace_self) } else { float4 { 1.0, 1.0, 1.0, 1.0 } },
                    if described { model3d::f4(lace_room_mean, stove_glaze) } else { float4 { lace_room.x + lace_back.x, lace_room.y + lace_back.y, lace_room.z + lace_back.z, stove_glaze } },
                    window_view, shell_case_of(g),
                    float4 { lace_shade.x, lace_shade.y, if lace_probed && light_baked(g) { 1.0 } else { 0.0 }, if described { room_light::LACE_THROUGH } else { 0.0 } },
                    table_map_shown(g),
                    books::COVER, books::LABEL, wood_rows(g, WOOD_OAK), wood_rows(g, WOOD_FLOOR),
                    room_shell::window_metal, env_pano, float4_0 }
}

// The tree's map at TREE_LEVEL kept on the CPU for the shell's baked light, where it fits.
fn keep_tree_small(map: const u8[:], w: i64, h: i64) {
    var at = 0;
    for level in TREE_LEVEL { at += 4 * (w >> level) * (h >> level); }
    let sw = w >> TREE_LEVEL;
    let sh = h >> TREE_LEVEL;
    tree_small_w = 0;
    tree_small_h = 0;
    guard 4 * sw * sh <= TREE_SMALL && at + 4 * sw * sh <= map.len else { return; }
    for i in 4 * sw * sh { tree_small[i] = map[at + i]; }
    tree_small_w = sw;
    tree_small_h = sh;
}

// The probes' first corner in the room's frame and, w, the step between them (world units);
// how many across, along v, and up (model3d::room_light).
fn light_box_of() -> float4 {
    let s = room_shell::LIBRARY;
    let metre = surfaces::METRE;
    let corner = room_shell::room_of(s, float2 { s.walls[room_shell::FAR_WALL].a.x - room_light::INSET, room_light::PLAN_Y0 });
    return float4 { corner.x, surfaces::FLOOR_Y + room_light::INSET * metre, corner.y, room_light::CELL * metre };
}
// The grid's probes across, along v and up, and how many probe volumes follow it in the
// atlas (room_light::volumes, with volumes_on; ROOM_FRAG's PROBE_VOLUMES reads them).
fn light_grid_of() -> float4 {
    let volumes: f32 = if room_light::volumes_on { room_light::volumes.len } else { 0.0 };
    return float4 { room_light::NX, room_light::NZ, room_light::NH, volumes };
}

// The baked light's atlas to bind, or another texture where none is made: ROOM_FRAG reads
// it only when its block says it is on.
fn light_or_stand_in(g: Gpu&) -> Texture { if g.light_volume.id != 0 { g.light_volume } else { g.crown_map } }
// The props' atlas of nine harmonics (room_light's PROPS_*), or another texture where none is
// made: TABLE_FRAG reads it with PROPS_LIGHT only.
fn props_probes_or_stand_in(g: Gpu&) -> Texture { if g.props_probes.id != 0 { g.props_probes } else { g.crown_map } }

// Whether the shell's light is baked: the shell shown and its room asking for it.
fn light_baked(g: Gpu&) -> bool { g.room_on && g.room.baked.x + g.room.baked.y > 0.0 }

// What the shell's baked light is made from: the key, the room's light, the tree, the
// casements' members' depth (panes.w), whether the props take their nine harmonics
// (props_light), the rug in the floor's cells, the exact gather and the niche's light
// (room_light::rug_in_bake, gather_exact, niche_light), the table's top, the bounces and the sun's saturation on the room, and the bake's own
// settings (room_light's bounce_grey, lace_source, gather_near), and whether the windows
// have their shutters (room_shell::shutters_on), how far the lace hangs over the opening
// (room_shell::lace_hang), and where the games table stands in the plan.
let LIGHT_KEY = 12;
fn light_key(g: Gpu&) -> float4[LIGHT_KEY] {
    let f = g.frame;
    let r = g.room;
    return [f.light_dir, f.light_color, r.baked, r.shell_sun, f.tree, f.room, f.panes, f.room_axes,
            float4 { if props_light { 1.0 } else { 0.0 }, if room_light::rug_in_bake { 1.0 } else { 0.0 },
                     (if room_light::gather_exact { 1.0 } else { 0.0 }) + (if room_light::niche_light { 2.0 } else { 0.0 }), if room_light::volumes_on { room_light::cavity_up + 1000 * room_light::cavity_across } else { 0.0 } },
            float4 { mesh::TABLE_R, g.tree_ms as f32, light_bounces as f32, room_sun.x },
            float4 { room_light::bounce_grey, room_light::lace_source, room_light::gather_near,
                     (if room_shell::shutters_on { 1.0 } else { 0.0 }) + 2.0 * room_shell::lace_hang },
            float4 { room_shell::LIBRARY.table.x, room_shell::LIBRARY.table.y, room_light::glazing, sun_panes }];
}

// The bake's buffers, sized once: the probes' atlas in floats and as half floats (and the
// props' with props_light), the sun's
// patches, how much of the sun the tree lets through each sun ray's glass point, and the
// tree's map at a low mip, kept on the CPU when it is baked (bake_tree).
// With room_light::volumes_on the atlas has the volumes' rows after the grid's
// (room_light::FULL_H); light_rows is the height of the one on the GPU.
var light_atlas: f32[room_light::FULL_FLOATS];
var light_bytes: u8[FULL_BYTES];
var light_rows = 0;
// The props' atlas of nine harmonics (room_light::PROPS_FLOATS), with props_light.
var light_props:   f32[room_light::PROPS_FLOATS];
var props_bytes:   u8[PROPS_BYTES];
var light_patches: room_light::Patch[room_light::BINS];
var light_tree:    f32[room_light::RAYS];
var light_bounce:  room_light::Bounce;
// The lace's own light on the window wall in the probes' light toward the room
// (room_light::LACE_WALL_FLOATS), which the lace's room side leaves out (lace_into_mesh).
var light_lace_wall: f32[room_light::LACE_WALL_FLOATS];
// How many times the room's light is thrown on after the sun's patches (room_light::BOUNCES;
// 0 the patches alone, the tuner's --bounces), and each step's time in the last bake:
// the sun's rays, the first light, each bounce, the half grid's gather, the probes.
var light_bounces = room_light::BOUNCES;
// The tonemaps' toes into the HDR target (FRAME's toe, HDR_OUT): the room's and the view
// out's way, the table's, the board's and the pieces' (0 on the luminance, 1 on the least
// channel, 2 none, the light tuner's --light physical, whose camera curve takes it); w
// unused. The app's 8-bit shaders keep their own toes and never read it.
var tone_toe = float4 { 0.0, 1.0, 1.0, 0.02 };
var light_steps: f64[8] = [0.0; 8];
// The probes' light on the games table's axis at TABLE_PROBE_UP + k × CELL over the floor
// (k 0 to 3: by its feet, its urn, under its top, over it), each colour's constant and
// direction, the direction turned into the world's; TABLE_FRAG reads it in the room.
var table_probes: float4[12] = [float4_0; 12];
let TABLE_PROBE_UP: f32 = 0.15;
// How much of the shade's floor of the key (rooms::Room.pattern's x leaves it) the room's
// surfaces and the games table keep beside the baked light: 1 all, 0 none (the tuner's
// --shade-fill). A fifth, with the sun twice as strong on the room (rooms::AUTUMN's
// shell_sun): the patches gain, the shade stays near where it was.
var shade_fill: f32 = 0.2;
// The share of the sun the window's panes let through that the key's strength already holds
// (1 none; the light tuner's --light physical, which lights every surface through the
// panes): the bake takes the sun before them, as its glazing has them.
var sun_panes: f32 = 1.0;
let FULL_BYTES = 274560;    // room_light::ATLAS_W × FULL_H × 8
let PROPS_BYTES = 567840;   // room_light::ATLAS_W × PROPS_H × 8
let TREE_LEVEL = 3;
let TREE_SMALL = 98304;     // trees::SHELL_W × SHELL_H × 4 >> 2 × TREE_LEVEL
var tree_small:   u8[TREE_SMALL];
var tree_small_w: i64 = 0;
var tree_small_h: i64 = 0;

// The shell's light baked again (model3d::room_light) when what it is made from changed:
// before a draw, outside a pass, after the tree's map. Tens of milliseconds on the CPU;
// nothing allocated, the buffers above fixed.
fn bake_room_light<O>(o: O&, g: Gpu&) {
    guard light_baked(g) && !g.bake_held else { return; }
    let key = light_key(g);
    var same = g.light_volume.id != 0;
    for i in LIGHT_KEY { if !same4(key[i], g.light_for[i]) { same = false; } }
    guard !same else { return; }
    let t0 = clock();
    let s = room_shell::LIBRARY;
    let f = g.frame;
    let r = g.room;
    let fr = g.room_frame;
    let l = float3 { f.light_dir.x, f.light_dir.y, f.light_dir.z };
    // The sun in the plan's frame: the room's u and v are the plan's -x and -y.
    let toward = float3 { -(l.x * fr.along.x + l.z * fr.along.y), -(l.x * fr.into.x + l.z * fr.into.y), l.y };
    // The sky through the windows: the harmonics toward the window, 20° up.
    let up: f32 = 0.342;
    let out = float3 { -fr.into.x * 0.94, up, -fr.into.y * 0.94 };
    let sun = room_light::Sun {
        toward: toward,
        light:  room_sun_of(float3 { f.light_color.x, f.light_color.y, f.light_color.z }) * (f.light_dir.w * r.shell_sun.y / sun_panes),
        sky:    sh_at(f.sh, out) * f.params.z,
        table: float4 { s.table.x, s.table.y, mesh::TABLE_R / surfaces::METRE,
                        (mesh::TABLE_TOP - surfaces::FLOOR_Y) / surfaces::METRE },
        sky_gain:    r.baked.x,
        bounce_gain: r.baked.y,
    };
    room_light::members_traced = f.panes.w > 0.5;
    room_light::table_off = if room_light::gather_exact { float2 { fr.along.y, fr.into.y } * (-mesh::TABLE_Z / surfaces::METRE) } else { float2_0 };
    room_light::nine_harmonics = props_light;
    tree_through(g, l);
    var at = clock();
    let n = room_light::sun_patches(sun, light_tree[..], light_patches, light_bounce);
    light_steps[0] = (clock() - at) * 1000.0;
    at = clock();
    room_light::first_light(sun, light_bounce);
    light_steps[1] = (clock() - at) * 1000.0;
    for b in 3 {
        at = clock();
        if b < light_bounces { room_light::bounce_once(sun, light_bounce, b == 0); }
        light_steps[2 + b] = (clock() - at) * 1000.0;
    }
    at = clock();
    room_light::gather_half(sun, light_bounce);
    light_steps[5] = (clock() - at) * 1000.0;
    at = clock();
    room_light::bake(sun, light_patches, n, light_bounce, light_atlas[..room_light::ATLAS_FLOATS], light_props[..],
                     light_lace_wall[..]);
    light_steps[6] = (clock() - at) * 1000.0;
    at = clock();
    if room_light::volumes_on {
        room_light::bake_volumes(sun, light_tree[..], light_patches, n, light_bounce, light_atlas[..]);
        volume_table();
    }
    light_steps[7] = (clock() - at) * 1000.0;
    probes_on_table(g);
    if lace_probed { probes_on_lace(); }
    if room_light::lace_described && lace_probed { lace_on_vertices(o, g, sun); }
    meter_light = meter_of(light_bounce, sun.bounce_gain);
    board_light = board_light_of(sun, light_bounce);
    let rows = if room_light::volumes_on { room_light::FULL_H } else { room_light::ATLAS_H };
    let floats = room_light::ATLAS_W * rows * 4;
    for i in floats {
        let h = half_bits(light_atlas[i]);
        light_bytes[2 * i] = (h & 0xFF) as u8;
        light_bytes[2 * i + 1] = (h >> 8) as u8;
    }
    if g.light_volume.id != 0 && light_rows != rows {
        o.gpu_release(g.light_volume);
        g.light_volume = Texture { 0 };
    }
    if g.light_volume.id == 0 {
        g.light_volume = o.gpu_sampled(room_light::ATLAS_W, rows, 1, RGBA16F);
        light_rows = rows;
    }
    o.gpu_upload(g.light_volume, 0, light_bytes[..2 * floats]);
    if props_light {
        for i in room_light::PROPS_FLOATS {
            let h = half_bits(light_props[i]);
            props_bytes[2 * i] = (h & 0xFF) as u8;
            props_bytes[2 * i + 1] = (h >> 8) as u8;
        }
        if g.props_probes.id == 0 { g.props_probes = o.gpu_sampled(room_light::ATLAS_W, room_light::PROPS_H, 1, RGBA16F); }
        o.gpu_upload(g.props_probes, 0, props_bytes[..]);
    }
    g.light_for = key;
    g.light_patches = n;
    g.light_ms = (clock() - t0) * 1000.0;
}

// The probe volumes' table in the atlas's row after the grid's, three texels a volume in
// the room's frame (world units), as ROOM_FRAG's volumes_light reads it: its box's low corner
// and how far in from its faces it blends into the grid; its size and its block's first
// column; its probes along x, up and along z, and its block's first row.
fn volume_table() {
    let s = room_shell::LIBRARY;
    let metre = surfaces::METRE;
    for v, n in room_light::volumes {
        // The plan's x and y fall along the room's x and z.
        let low = room_shell::room_of(s, float2 { v.hi.x, v.hi.y });
        let texels: float4[3] = [float4 { low.x, surfaces::FLOOR_Y + v.lo.z * metre, low.y, v.fade * metre },
                                 float4 { (v.hi.x - v.lo.x) * metre, (v.hi.z - v.lo.z) * metre, (v.hi.y - v.lo.y) * metre, v.column },
                                 float4 { v.nx, v.nh, v.ny, v.row }];
        for t in 3 {
            let a = 4 * (room_light::ATLAS_H * room_light::ATLAS_W + 3 * n + t);
            light_atlas[a] = texels[t].x;
            light_atlas[a + 1] = texels[t].y;
            light_atlas[a + 2] = texels[t].z;
            light_atlas[a + 3] = texels[t].w;
        }
    }
}

// The probes' light at four heights on the games table's axis into table_probes, as
// shaders' baked_light reads it (trilinear between probes), its directions turned from the
// room's frame into the world's.
fn probes_on_table(g: Gpu&) {
    let s = room_shell::LIBRARY;
    let fr = g.room_frame;
    let metre = surfaces::METRE;
    let corner = room_shell::room_of(s, float2 { s.walls[room_shell::FAR_WALL].a.x - room_light::INSET, room_light::PLAN_Y0 });
    let box = float3 { corner.x, surfaces::FLOOR_Y + room_light::INSET * metre, corner.y };
    let cell = room_light::CELL * metre;
    // The table's middle in the room's frame (the world's turned back by its axes).
    let lx = fr.along.x * 0.0 + fr.along.y * mesh::TABLE_Z;
    let lz = fr.into.x * 0.0 + fr.into.y * mesh::TABLE_Z;
    for k in 4 {
        let y = surfaces::FLOOR_Y + (TABLE_PROBE_UP + k * room_light::CELL) * metre;
        let gx = clamp((lx - box.x) / cell, 0.0, room_light::NX - 1.0);
        let gh = clamp((y - box.y) / cell, 0.0, room_light::NH - 1.0);
        let gz = clamp((lz - box.z) / cell, 0.0, room_light::NZ - 1.0);
        let x0 = floor(gx) as i64;
        let h0 = floor(gh) as i64;
        let z0 = floor(gz) as i64;
        let x1 = min(x0 + 1, room_light::NX - 1);
        let h1 = min(h0 + 1, room_light::NH - 1);
        let z1 = min(z0 + 1, room_light::NZ - 1);
        let fx = gx - x0;
        let fh = gh - h0;
        let fz = gz - z0;
        for c in 3 {
            var v = float4_0;
            for q in 8 {
                let x = if (q & 1) != 0 { x1 } else { x0 };
                let h = if (q & 2) != 0 { h1 } else { h0 };
                let z = if (q & 4) != 0 { z1 } else { z0 };
                let w = (if (q & 1) != 0 { fx } else { 1.0 - fx }) * (if (q & 2) != 0 { fh } else { 1.0 - fh })
                        * (if (q & 4) != 0 { fz } else { 1.0 - fz });
                let a = 4 * ((c * room_light::NZ + z) * room_light::ATLAS_W + h * room_light::NX + x);
                v = v + float4 { light_atlas[a], light_atlas[a + 1], light_atlas[a + 2], light_atlas[a + 3] } * w;
            }
            // The direction in the room's frame (x along u, z along v) into the world's.
            let wx = fr.along.x * v.y + fr.into.x * v.w;
            let wz = fr.along.y * v.y + fr.into.y * v.w;
            table_probes[k * 3 + c] = float4 { v.x, wx, v.z, wz };
        }
    }
}

// The lace's light from the probes (ROOM_FRAG's lace with lace_probed, the light tuner's
// --lace-fill probes), as baked_light reads them, the mean over the three windows' six
// panels at nine heights: lace_room the light on its room side, toward the room half a cell
// out from the panels' middles; lace_back on its window side where the niche hides the sky
// (over the piers, at the panels' outer parts), toward the window at the cloth. In place of
// the lace's old fill, the harmonics and the room's even bounce at full, which the other
// surfaces no longer take under --light physical (task 122).
var lace_probed = false;
var lace_room = float3_0;
var lace_back = float3_0;
// The light on the lace's room side and window side, the means over its vertices
// (lace_on_vertices, with room_light::lace_described).
var lace_room_mean = float3_0;
var lace_back_mean = float3_0;
// The stove's glaze's albedo over its own (ROOM_FRAG's STOVE_GLAZE), 0 as made (the light
// tuner's --stove-glaze, --light physical only).
var stove_glaze: f32 = 0.0;
fn probes_on_lace() {
    let s = room_shell::LIBRARY;
    let face = s.walls[room_shell::WINDOW_WALL].a.y - room_shell::LACE_MIDDLE[0].y;
    var room = float3_0;
    var back = float3_0;
    var n = 0;
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::WINDOW else { continue; }
        for side in 2 {
            let sign: f32 = if side == 0 { -1.0 } else { 1.0 };
            for j in 9 {
                let h = 0.2 + 0.4 * j;
                // The room's v grows away from the window wall, so +1 is toward the room.
                room = room + probe_light(float3 { o.mid + 0.72 * sign, face - 0.5 * room_light::CELL, h }, 1.0);
                back = back + probe_light(float3 { o.mid + 0.85 * sign, face, h }, -1.0);
                n++;
            }
        }
    }
    lace_room = room * (1.0 / max(n, 1));
    lace_back = back * (1.0 / max(n, 1));
}
// The lace's light on each vertex under room_light::lace_described (task 124), after each
// bake. On its window side what it sees: the glazing's sky, its niche's faces and the window
// wall (room_light::lace_views, kept in the vertex's box at the mesh's making; the wall's own
// light by it, room_light::window_wall_light). On its room side the probes' light half a cell out,
// less what the folds beside it hide (FOLD_HIDDEN over FOLD_DEEP of its corner's x, its
// hidden share), where it sees the cloth beside it: through its open part the wall's light,
// its thread the room's light sent back and what the cloth there throws on into the room
// (room_light::lace_glow, the sun and sky on its window side). The window side's view of the
// wall likewise meets the folds beside it, at their other phase (FOLD_HIDDEN less the room
// side's hidden share): through their open part the room's light, their thread the window
// side's sent back and the room's sent on. Each as its share of the cloth's mean (lace_room_mean,
// lace_back_mean): the room side's in the vertex's corner's y, the window side's in its
// material's fraction over LACE_BACK_SCALE (ROOM_FRAG's lace).
let WINDOW_VERTS = 16384;
let LACE_BACK_SCALE: f32 = 8.0;
var window_verts: corner_map::RoomVertex[WINDOW_VERTS];
var window_vert_count = 0;
var lace_lums: float2[WINDOW_VERTS];
var lace_sun = room_light::Sun { float3_0, float3_0, float3_0, float4_0, 0.0, 0.0 };
var lace_lit_once = false;
fn keep_window_verts(verts: corner_map::RoomVertex[>..]&) {
    window_vert_count = 0;
    guard room_light::lace_described && lace_probed && verts.len <= WINDOW_VERTS else { return; }
    for v, i in verts {
        var w = v;
        if floor(v.mat + 0.001) == surfaces::MAT_LACE {
            let p, n = plan_of(v.pos, v.normal);
            let f = room_light::lace_views(p, n);
            w.box = float2 { f.x, f.y };
        }
        window_verts[i] = w;
    }
    window_vert_count = verts.len;
}
// Whether the lace is lit as room_light describes it (ROOM_FRAG's lace_shade.w, LIGHT_FN's
// lace_shadow by shell_glass.w under 0).
fn lace_lit(g: Gpu&) -> bool { room_light::lace_described && lace_probed && light_baked(g) && lace_lit_once && window_vert_count > 0 }
// The lace as one flat sheet for the sun (room_light::lace_flat: its folds' slant and the
// density on the mask's blurred value; LIGHT_FN's lace_shadow by shell_glass.w and shell_case.y).
var lace_slant = float2 { 1.0, 0.8 };
// The sun's share through the cloth itself to its room side (lace_back.w): one crossing of
// the flat sheet, the mask at its mean.
var lace_self: f32 = 1.0;
fn lace_on_vertices<O>(o: O&, g: Gpu&, sun: room_light::Sun) {
    lace_slant = room_light::lace_flat(float3_0 - sun.toward);
    lace_self = pow(1.0 - lace_slant.y * 0.5137, lace_slant.x);
    lace_sun = sun;
    lace_lit_once = true;
    lace_into_mesh(o, g);
}
fn lace_into_mesh<O>(o: O&, g: Gpu&) {
    guard window_vert_count > 0 && g.window_vb.id != 0 else { return; }
    let sky = room_light::lace_sky(lace_sun);
    let niches: float3[3] = [room_light::lace_niche(lace_sun, light_bounce, 0), room_light::lace_niche(lace_sun, light_bounce, 1),
                             room_light::lace_niche(lace_sun, light_bounce, 2)];
    let face = room_light::wall_face() - 0.5 * room_light::CELL;
    let thread = 1.0 - room_light::lace_open_share(0.5);
    let albedo = room_light::lace_albedo();
    let through = room_light::LACE_THROUGH;
    var front_sum = float3_0;
    var back_sum = float3_0;
    var n = 0;
    for i in window_vert_count {
        let v .= window_verts[i];
        guard floor(v.mat + 0.001) == surfaces::MAT_LACE else { continue; }
        let p, nrm = plan_of(v.pos, v.normal);
        let wall = room_light::window_wall_light(lace_sun, light_bounce, p);
        let window_part = sky * v.box.x + niches[room_light::window_near(p)] * (v.box.y - v.box.x);
        let seen = window_part + wall * (1.0 - v.box.y);
        let room = probe_light(float3 { p.x, face, p.z }, 1.0, true);
        let hidden = min(v.corner.x * (room_shell::FOLD_HIDDEN / room_shell::FOLD_DEEP), 1.0);
        let glow = room_light::lace_glow(light_bounce, p, seen);
        let beside = wall * (1.0 - thread) + (albedo * (room * (1.0 - through)) + glow) * thread;
        let front = room * (1.0 - hidden) + beside * hidden;
        let hidden_back = max(room_shell::FOLD_HIDDEN - hidden, 0.0);
        let beside_back = room * (1.0 - thread) + albedo * (seen * (1.0 - through) + room * through) * thread;
        let back = window_part + (wall * (1.0 - hidden_back) + beside_back * hidden_back) * (1.0 - v.box.y);
        front_sum = front_sum + front;
        back_sum = back_sum + back;
        n++;
        lace_lums[i] = float2 { lum(front), lum(back) };
    }
    guard n > 0 else { return; }
    lace_room_mean = front_sum * (1.0 / n);
    lace_back_mean = back_sum * (1.0 / n);
    let fl = max(lum(lace_room_mean), 1e-9);
    let bl = max(lum(lace_back_mean), 1e-9);
    for i in window_vert_count {
        let v .= window_verts[i];
        guard floor(v.mat + 0.001) == surfaces::MAT_LACE else { continue; }
        v.corner.y = lace_lums[i].x / fl;
        v.mat = surfaces::MAT_LACE + min(lace_lums[i].y / (bl * LACE_BACK_SCALE), 0.99);
    }
    o.gpu_update(g.window_vb, bytes_of(window_verts[..window_vert_count]));
}
// A point and normal of the room's mesh (its own frame, ROOM_VERT's a_pos: u along the window
// wall, v into the room) in the plan's (metres, z up).
fn plan_of(p: float3, n: float3) -> float3, float3 {
    let t = room_shell::LIBRARY.table;
    return float3 { t.x - p.x / surfaces::METRE, t.y - p.z / surfaces::METRE, (p.y - surfaces::FLOOR_Y) / surfaces::METRE },
           float3 { -n.x, -n.z, n.y };
}
fn lum(c: float3) -> f32 { 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z }

// The grid's probes' light at a plan point (x, y, metres up) toward +v (toward 1) or -v,
// trilinear as baked_light; without_lace leaves out the lace's own light on the window wall
// (light_lace_wall), toward +v only.
fn probe_light(p: float3, toward: f32, without_lace: bool = false) -> float3 {
    let s = room_shell::LIBRARY;
    let metre = surfaces::METRE;
    let corner = room_shell::room_of(s, float2 { s.walls[room_shell::FAR_WALL].a.x - room_light::INSET, room_light::PLAN_Y0 });
    let cell = room_light::CELL * metre;
    let at = room_shell::room_of(s, float2 { p.x, p.y });
    let gx = clamp((at.x - corner.x) / cell, 0.0, room_light::NX - 1.0);
    let gh = clamp((p.z - room_light::INSET) / room_light::CELL, 0.0, room_light::NH - 1.0);
    let gz = clamp((at.y - corner.y) / cell, 0.0, room_light::NZ - 1.0);
    let x0 = floor(gx) as i64;
    let h0 = floor(gh) as i64;
    let z0 = floor(gz) as i64;
    let x1 = min(x0 + 1, room_light::NX - 1);
    let h1 = min(h0 + 1, room_light::NH - 1);
    let z1 = min(z0 + 1, room_light::NZ - 1);
    let fx = gx - x0;
    let fh = gh - h0;
    let fz = gz - z0;
    var c3: f32[3] = [0.0; 3];
    for c in 3 {
        var v = float4_0;
        for q in 8 {
            let px = if (q & 1) != 0 { x1 } else { x0 };
            let ph = if (q & 2) != 0 { h1 } else { h0 };
            let pz = if (q & 4) != 0 { z1 } else { z0 };
            let w = (if (q & 1) != 0 { fx } else { 1.0 - fx }) * (if (q & 2) != 0 { fh } else { 1.0 - fh })
                    * (if (q & 4) != 0 { fz } else { 1.0 - fz });
            let a = 4 * ((c * room_light::NZ + pz) * room_light::ATLAS_W + ph * room_light::NX + px);
            v = v + float4 { light_atlas[a], light_atlas[a + 1], light_atlas[a + 2], light_atlas[a + 3] } * w;
            if without_lace { v.x -= w * light_lace_wall[4 * (pz * room_light::ATLAS_W + ph * room_light::NX + px) + c]; }
        }
        c3[c] = max(v.x + toward * v.w, 0.0);
    }
    return float3 { c3[0], c3[1], c3[2] };
}

// The nine harmonics' light toward d.
fn sh_at(sh: float4[9], d: float3) -> float3 {
    let b: f32[9] = [0.282095, 0.488603 * d.y, 0.488603 * d.z, 0.488603 * d.x, 1.092548 * d.x * d.y, 1.092548 * d.y * d.z,
                     0.315392 * (3.0 * d.y * d.y - 1.0), 1.092548 * d.x * d.z, 0.546274 * (d.x * d.x - d.z * d.z)];
    var c = float3_0;
    for i in 9 { c = c + float3 { sh[i].x, sh[i].y, sh[i].z } * b[i]; }
    return float3 { max(c.x, 0.0), max(c.y, 0.0), max(c.z, 0.0) };
}

// How much of the sun the tree outside lets through each sun ray's glass point
// (room_light::ray_point) into light_tree, as LIGHT_FN's tree_light takes it, from the
// tree's map at a low mip, its blur standing for the leaves' flecks; 1 with no tree.
fn tree_through(g: Gpu&, l: float3) {
    let f = g.frame;
    let s = room_shell::LIBRARY;
    let fr = g.room_frame;
    let nw = float2 { -fr.into.x, -fr.into.y };
    let along = fr.along;
    let toward = l.x * nw.x + l.z * nw.y;
    let on = f.tree.x > 0.0 && tree_small_w > 0 && toward > 0.05;
    for k in 3 {
        for j in room_light::RAYS_Y {
            for i in room_light::RAYS_X {
                let at = (k * room_light::RAYS_Y + j) * room_light::RAYS_X + i;
                light_tree[at] = 1.0;
                guard on else { continue; }
                let q = room_light::ray_point(k, i, j);
                let lo = room_shell::room_of(s, float2 { q.x, q.y });
                let px = along.x * lo.x + fr.into.x * lo.y;
                let pz = along.y * lo.x + fr.into.y * lo.y;
                let py = surfaces::FLOOR_Y + q.z * surfaces::METRE;
                let back = (px * nw.x + pz * nw.y) / toward;
                let mx = px * along.x + pz * along.y - (l.x * along.x + l.z * along.y) * back;
                let my = py - l.y * back;
                let u = (mx - f.tree.z) / f.tree.x + 0.5;
                let v = (my - f.tree.w) / f.tree.y + 0.5;
                let tx = clamp((u * tree_small_w) as i64, 0, tree_small_w - 1);
                let ty = clamp((v * tree_small_h) as i64, 0, tree_small_h - 1);
                let o = 4 * (ty * tree_small_w + tx);
                light_tree[at] = (tree_small[o] as f32) * tree_small[o + 1] * tree_small[o + 2] * tree_small[o + 3] / 4228250625.0;
            }
        }
    }
}

// x as a half float's bits: tiny values flushed to zero, large ones held at the largest.
fn half_bits(x: f32) -> u16 {
    let a = abs(x);
    let sign: u16 = if x < 0.0 { 0x8000 } else { 0 };
    guard a >= 6.104e-5 else { return sign; }
    guard a < 65504.0 else { return sign | 0x7bff; }
    var e = floor(log2(a));
    var bits = round((a / exp2(e) - 1.0) * 1024.0);
    if bits >= 1024.0 {
        bits = 0.0;
        e += 1.0;
    }
    return sign | (((e + 15.0) as u16) << 10) | (bits as u16);
}

// A target with its mips for a baked surface, down to the level whose shorter side is 1
// pixel: past it SDL's mip blits are zero-height, which loses the device on Mali
// (docs/goose-findings.md). Nothing samples that far down.
fn baked<O>(o: O&, w: i64, h: i64, format: i32) -> Texture {
    var mips = 1;
    while min(w, h) >> mips > 0 { mips++; }
    return o.gpu_mipped(w, h, format, mips);
}

// The kept image at `size`, made again only when the size changes; the pass's own
// targets when draw() needs them (pass_targets), the kept backdrop and depth when it
// keeps them.
fn targets<O>(o: O&, g: Gpu&, size: int2) {
    give_back(o, g);
    if g.image.id != 0 { o.gpu_release(g.image); }
    g.image = o.gpu_target(size.x, size.y);
    g.kept_for[0] = float4_0;
    g.size = size;
}

// Gives back what only drawing the board needs once it is off the screen or the app is
// going to the background: the pass's targets, the depth kept for the pulsing marks, and
// the kept backdrop, which the screen's frames grade live from the photograph till the
// next draw() keeps it again. The kept image shows the board until it changes; the next
// draw() makes the rest again. Not inside a pass: it submits what was recorded, as
// released textures are freed after the next submit is done, and none comes at rest.
fn release_targets<O>(o: O&, g: Gpu&) {
    give_back(o, g);
    o.gpu_flush();
}

// What release_targets() releases, also before a resize's new targets.
fn give_back<O>(o: O&, g: Gpu&) {
    let held = [g.color, g.depth, g.edges, g.weights, g.kept_depth, g.kept_backdrop, g.scene_image, g.hdr_image, g.scene_depth];
    for t in held { if t.id != 0 { o.gpu_release(t); } }
    g.scene_image = Texture { 0 };
    g.hdr_image = Texture { 0 };
    g.scene_depth = Texture { 0 };
    for k in GLOW_LEVELS {
        if g.glow_levels[k].id != 0 { o.gpu_release(g.glow_levels[k]); }
        g.glow_levels[k] = Texture { 0 };
    }
    g.glow_size = int2_0;
    if g.haze_image.id != 0 { o.gpu_release(g.haze_image); }
    if g.haze_cross.id != 0 { o.gpu_release(g.haze_cross); }
    g.haze_image = Texture { 0 };
    g.haze_cross = Texture { 0 };
    g.haze_size = int2_0;
    g.color = Texture { 0 };
    g.edges = Texture { 0 };
    g.weights = Texture { 0 };
    g.depth = Texture { 0 };
    g.kept_depth = Texture { 0 };
    g.kept_backdrop = Texture { 0 };
}

// Whether release_targets() has anything to give back.
fn resting(g: Gpu&) -> bool {
    return g.color.id == 0 && g.depth.id == 0 && g.edges.id == 0 && g.weights.id == 0 && g.kept_depth.id == 0
           && g.kept_backdrop.id == 0 && g.scene_image.id == 0 && g.hdr_image.id == 0 && g.scene_depth.id == 0;
}

// Puts a theme on the board (looks::AUTUMN..), its surfaces baked for n squares a side,
// with the photograph `photo` (the app's theme, src/native/background.c's kind; -1 the
// theme's own): bakes the surfaces into the same targets, blurs the photograph and takes
// its ambient, and fills the frame's block with its light and colors. Only what changed
// is done again; outside the frame loop's steady state: at setup, on a theme change, a
// new board size.
fn apply<O>(o: O&, g: Gpu&, which: i64, n: i64, photo: i64 = -1) {
    if theme_begin(o, g, which, n) {
        let t0 = clock();
        bake_surfaces(o, g);
        g.bake_ms = (clock() - t0) * 1000.0;
    }
    theme_photo(o, g, which, photo);
    theme_end(o, g, which, n);
}

// apply()'s start: the look's carving taken, and for a new look or board size the frame
// map's targets as its frame wants. Whether the surfaces are to be baked.
fn theme_begin<O>(o: O&, g: Gpu&, which: i64, n: i64) -> bool {
    own_carving(g, looks::shown(which, g.spring));
    let side = if g.want_side > 0 { g.want_side } else { model3d::BAKE_SIDE };
    guard which != g.look || n != g.n || side != g.side else { return false; }
    if !frame_matches(g) { abort("render3d::Frame and shaders::FRAME differ in size"); }
    let t = look(g, which);
    g.look = which;
    g.n = n;
    if side != g.side {
        if g.side != 0 { o.gpu_release_waited(g.plan_albedo, g.plan_normal); }
        g.plan_albedo = baked(o, side, side, RGBA8_SRGB);
        g.plan_normal = baked(o, side, side, RGBA8);
        g.side = side;
        // The frame map's width is the side too: made again below.
        if g.frame_rows != 0 {
            o.gpu_release_waited(g.frame_albedo, g.frame_normal);
            g.frame_rows = 0;
        }
    }
    let rows = model3d::frame_rows(t, side);
    if rows != g.frame_rows {
        if g.frame_rows != 0 {
            o.gpu_release_waited(g.frame_albedo, g.frame_normal);
        }
        g.frame_albedo = baked(o, side, rows, RGBA8_SRGB);
        g.frame_normal = baked(o, side, rows, RGBA8);
        g.frame_rows = rows;
        g.frame_flat = false;
    }
    full_frame(o, g);
    return true;
}

// A flat marble frame's normal is the same everywhere (BAKE_FRAG writes it so, and its
// mips are it too): once baked, its map is given back for a 4 × 4 of
// that value, which samples the same. full_frame() makes the map again to bake into.
fn flat_frame<O>(o: O&, g: Gpu&) {
    let t = look(g, g.look);
    guard !g.frame_flat && marbled(g, t) else { return; }
    o.gpu_release(g.frame_normal);
    g.frame_normal = o.gpu_target(4, 4);
    let half: f32 = 128.0 / 255.0;
    o.gpu_clear(g.frame_normal, float4 { half, half, 1.0, 1.0 });
    g.frame_flat = true;
}

fn full_frame<O>(o: O&, g: Gpu&) {
    guard g.frame_flat else { return; }
    o.gpu_release(g.frame_normal);
    g.frame_normal = baked(o, g.side, g.frame_rows, RGBA8);
    g.frame_flat = false;
}

// apply()'s photograph (`photo`, -1 the look's own) blurred and its ambient taken, when
// it is another than the one shown.
fn theme_photo<O>(o: O&, g: Gpu&, which: i64, photo: i64) {
    let t = look(g, which);
    let kind = if photo >= 0 { photo } else { t.photo };
    guard kind != g.photo_kind || g.frame.light_dir.w == 0.0 else { return; }
    g.photo_kind = kind;
    let t0 = clock();
    var sh: float4[9] = [float4_0; 9];
    photograph(o, g, kind, t.ambient.z, sh);
    g.frame.sh = sh;
    o.gpu_flush();
    g.photo_ms = (clock() - t0) * 1000.0;
}

// Step k (0 to model3d::THEME_STEPS - 1) of putting a theme on, as apply(which, n, photo)
// does at once, as model3d::step plans it. Recording only; the frame's submit runs it.
fn theme_step<O>(o: O&, g: Gpu&, which: i64, n: i64, photo: i64, k: i64) {
    let t = look(g, g.look);
    let rows = g.frame_rows;
    let st = model3d::step(k, rows, g.side);
    if st.what == model3d::BEGIN {
        // A new look or size is baked whatever theme_begin finds: the steps bake in turn.
        theme_begin(o, g, which, n);
    } else if st.what == model3d::PIPELINE || st.what == model3d::PLAN {
        o.bake(g, g.plan_albedo, g.plan_normal, g.side, g.side, 0.0, model3d::plan_extent(), t, st.y0, st.y1, st.mips);
    } else if st.what == model3d::FRAME {
        // A switch can land after a flat marble frame gave its map back (flat_frame).
        full_frame(o, g);
        o.bake(g, g.frame_albedo, g.frame_normal, g.side, rows, 1.0, model3d::frame_extent(rows, g.side), t, st.y0,
             st.y1, st.mips);
    } else if st.what == model3d::TABLE {
        bake_table(o, g, st.y0, st.y1, st.mips);
    } else if st.what == model3d::PHOTO_PIPELINES {
        o.photo_pipelines(g);
    } else {
        let part = st.part;
        let lk = look(g, which);
        let kind = if photo >= 0 { photo } else { lk.photo };
        var sh = g.frame.sh;
        o.photo_part(g, kind, lk.ambient.z, sh, part);
        g.frame.sh = sh;
        if part == 2 {
            g.photo_kind = kind;
            theme_end(o, g, which, n);
        }
    }
}

// apply()'s end: the key light, and the look's colors in the frame's block.
fn theme_end<O>(o: O&, g: Gpu&, which: i64, n: i64) {
    flat_frame(o, g);
    let t = pieces_of(g, which);
    o.set_pieces(g, pieces_kind(t.mineral));
    // The key light, from the upper left; the photograph's ambient.
    light(g);
    let f .= g.frame;
    f.light_color = model3d::linear4(t.key_color);
    f.params = float4 { t.ambient.x, 0.0, t.ambient.y, n };
    f.glow = t.glow;
    f.light_piece = model3d::linear4(t.light_piece);
    f.dark_piece = model3d::dark_piece_color(t.dark_piece, model3d::dark_brightness(t.mineral));
    f.piece_fig = t.piece_fig;
    f.crown = model3d::linear4(t.crown);
    f.edge = model3d::linear4(t.edge);
    if marbled(g, t) && !(g.look == looks::WINTER && looks::is_slab(g.marble)) { f.edge.w = 0.0; }
    f.line = model3d::linear4(t.line);
    f.bounce = model3d::linear4(t.bounce);
    f.grade = t.grade;
    f.tint = model3d::linear4(t.tint);
    f.frame_build = t.build;
    f.frame_map = float4 { (g.frame_rows as f32) / g.side, t.mineral, 0.0, 0.0 };
    f.frame_surface = t.frame_surface;
    f.frame_wax = t.frame_wax;
    f.light_scatter = model3d::linear4(t.light_scatter);
    f.dark_scatter = model3d::linear4(t.dark_scatter);
    f.piece_wear = t.piece_wear;
    board_scatter(g);
    f.room = float4 { 1.0, 0.0, 0.0, 0.0 };
    put_room(g);
    g.shadow_dirty = true;
}

// Whether the key light takes the window's pattern (task 104): the high mode's, till the
// tiers' table exists a development switch (the tuner's, the app's --window).
var window_pattern = false;

// The seconds the leaves' shadows have swayed (rooms::Room.wind): the tuner's clock; the
// app keeps them still at 0 for now, as a sway would draw every frame.
var wind_time: f32 = 0.0;

// How the wind moves the leaves (rooms::WIND_KINDS): the tuner's switch.
var wind_kind = rooms::WIND_NOISE;

// The room's light where the board stands on its table (rooms::Room): its key in place
// of the look's, its fill and walls as the ambient's harmonics, the look's exposure kept.
// Over the photograph or the fade the look's own light stays.
fn put_room(g: Gpu&) {
    guard g.table && g.look >= 0 else { return; }
    if !g.room_tuned { g.room = rooms::of(g.photo_kind); }
    let r = g.room;
    let t = look(g, g.look);
    light(g);
    let f .= g.frame;
    // The room's frame from the key and the window's wall: ROOM_VERT turns the room by it.
    let l = f.light_dir;
    g.room_frame = surfaces::frame_of(float3 { l.x, l.y, l.z }, r.window.y);
    f.room_axes = float4 { g.room_frame.along.x, g.room_frame.along.y, g.room_frame.into.x, g.room_frame.into.y };
    f.light_color = model3d::f4(rooms::key_light(r), 0.0);
    f.sh = rooms::harmonics(r);
    f.params = float4 { t.ambient.x * r.exposure, f.params.y, 1.0, f.params.w };
    let on = window_pattern && r.pattern.x > 0.0;
    f.room = float4 { r.key.w, if on { r.pattern.x } else { 0.0 }, r.pattern.y, 0.0 };
    f.window = r.window;
    f.panes = r.panes;
    f.opening = r.opening;
    f.leaves = r.leaves;
    f.twigs = r.twigs;
    let still = wind_kind == rooms::WIND_STILL;
    // The leaves' ruffle in a gust as strong as the noises' gusts are (the sines keep theirs).
    let ruffle = if wind_kind == rooms::WIND_SINES { r.wind.w } else { r.wind.w * r.gust.x };
    f.wind = float4 { r.wind.x, r.wind.y, if still { 0.0 } else { wind_time }, ruffle };
    let size = if on && r.tree.x > 0.5 { tree_view_of(g).size } else { float2_0 };
    let wa = rooms::wind_of(r, wind_kind, wind_time, size);
    f.wind_now = wa.now;
    f.tree_shift = wa.shift;
    f.branches = wa.branches;
    f.gust_reach = wa.regions;
    put_tree(g, on && r.tree.x > 0.5);
    g.shadow_dirty = true;
}

// The tree's part of the frame's block (shaders::LIGHT_FN's tree_light), and whether its
// map is to be baked again: only when what it is baked from changed.
fn put_tree(g: Gpu&, on: bool) {
    let r = g.room;
    let f .= g.frame;
    f.tree = float4_0;
    guard on else { return; }
    let v = tree_view_of(g);
    let key = tree_key(g);
    var same = g.tree_map.id != 0;
    for i in 11 { if !same4(key[i], g.tree_for[i]) { same = false; } }
    if !same { g.tree_stale = true; }
    f.tree = float4 { v.size.x, v.size.y, v.middle.x, v.middle.y };
    let crown = if r.tree.x > 1.5 { max(r.crown_blur, 0.01) } else { 0.0 };
    f.tree_blur = float4 { v.blur * v.w / v.size.x, v.distance, crown, r.crown_fill };
}

// The room whose tree is shown: the shell's own (rooms::shell_tree) with the shell on.
fn tree_room(g: Gpu&) -> rooms::Room {
    if g.room_on { return rooms::shell_tree(g.room); }
    return g.room;
}

// How the sun sees the tree: over the shell's three windows with the room on, else cut
// to the table. The shell's windows' niches at the wall's inner face, as the key carries them out to the tree.
fn tree_view_of(g: Gpu&) -> trees::View {
    guard g.room_on else { return rooms::tree_view(g.room, g.room_on); }
    return rooms::shell_tree_view(g.room, room_shell::LIBRARY);
}

// The window wall's inner face's distance from the board's middle toward the sun, world units.
fn shell_face(s: room_shell::Shell) -> f32 {
    return (s.walls[room_shell::WINDOW_WALL].a.y - s.table.y) * surfaces::METRE;
}

// The tree's map to bind, or another texture where none is baked: the shaders sample it
// only when the frame's block says the tree shows.
fn tree_or_stand_in(g: Gpu&) -> Texture { if g.tree_map.id != 0 { g.tree_map } else { g.crown_map } }
fn lace_or_stand_in(g: Gpu&) -> Texture { if g.lace_mask.id != 0 { g.lace_mask } else { g.crown_map } }

// What the tree's map is baked from.
fn tree_key(g: Gpu&) -> float4[11] {
    let r = tree_room(g);
    let v = tree_view_of(g);
    return [r.tree, r.crown, r.foliage, r.leaves, r.window, r.panes, r.opening, r.key, float4 { r.tree_blur, 0.0, 0.0, 0.0 },
            float4 { r.species, if tree_grown_whole { 1.0 } else { 0.0 }, 0.0, 0.0 }, float4 { v.size.x, v.size.y, v.middle.x, v.middle.y }];
}

// The tree grown and its shadow drawn on the CPU, then put on the GPU with its mips:
// before a draw, after put_room() found it stale. Tens of milliseconds, never in the
// frame loop's steady state.
fn bake_tree<O>(o: O&, g: Gpu&) {
    guard g.tree_stale && !g.bake_held else { return; }
    g.tree_stale = false;
    let t0 = clock();
    let s = rooms::tree_spec(tree_room(g));
    let v = tree_view_of(g);
    var map: u8[>..] = [];
    {
        var t = trees::Tree { .. };
        if tree_grown_whole && g.room_on {
            trees::grow_whole(t, whole_tree_of(g), v, rooms::whole_sight(g.room, room_shell::LIBRARY), true);
        } else {
            trees::grow(t, s, v);
        }
        trees::draw_map(t, s, v, map);
    }
    keep_tree_small(map[..], v.w, v.h);
    if g.tree_map.id != 0 && (g.tree_w != v.w || g.tree_h != v.h) {
        o.gpu_release(g.tree_map);
        g.tree_map = Texture { 0 };
    }
    if g.tree_map.id == 0 {
        g.tree_map = o.gpu_sampled(v.w, v.h, trees::mips_of(v.w, v.h), RGBA8);
        g.tree_w = v.w;
        g.tree_h = v.h;
    }
    var at = 0;
    for level in trees::mips_of(v.w, v.h) {
        let n = (v.w >> level) * (v.h >> level) * 4;
        o.gpu_upload(g.tree_map, level, map[at..at + n]);
        at += n;
    }
    g.tree_for = tree_key(g);
    g.tree_bakes++;
    g.tree_ms = (clock() - t0) * 1000.0;
}

// The maple's growth past its habit (trees::Growth, task 117: broken leaders, the gravity
// layer, shedding), all off as in the app until checked: the light tuner's --tree-elbows,
// --tree-gravity and --tree-shed.
var tree_growth = trees::Growth { .. };

// The old maple as the shell grows it, with tree_growth.
fn whole_tree_of(g: Gpu&) -> trees::Whole {
    var w = rooms::whole_tree(g.room, room_shell::LIBRARY);
    w.growth = tree_growth;
    return w;
}

// The leaves' meshes (shaders::TREE_LEAF_VERT, trees::leaf_shapes): flat cards, the card in
// four rows bent along its midrib, or a fan hugging the leaf's outline, bent; by the tier, with
// the bent shapes on (tree_growth.bend), the high tier's (HDR) the fan and the standard's the
// rows, else cards (a phone draws the tree's card, never its leaves). The light tuner's
// --tree-leaf-mesh tier|card|rows|fan.
let TREE_LEAF_MESHES = ["tier", "card", "rows", "fan"];
let LEAF_MESH_TIER = 0;
let LEAF_MESH_CARD = 1;
let LEAF_MESH_ROWS = 2;
let LEAF_MESH_FAN = 3;
var tree_leaf_mesh = LEAF_MESH_TIER;

fn leaf_mesh(hdr: bool) -> i64 {
    if tree_leaf_mesh != LEAF_MESH_TIER { return tree_leaf_mesh; }
    guard tree_growth.bend.x > 0.0 else { return LEAF_MESH_CARD; }
    return if hdr { LEAF_MESH_FAN } else { LEAF_MESH_ROWS };
}

// The vertices a leaf draws with its mesh (as triangle lists).
fn leaf_vertices(mesh: i64) -> i64 {
    if mesh == LEAF_MESH_ROWS { return trees::LEAF_ROW_VERTICES; }
    if mesh == LEAF_MESH_FAN { return trees::LEAF_FAN_VERTICES; }
    return 6;
}

// The tree outside drawn as geometry (task 107's T2 and T3): off (the view out's pictures
// alone, the app's), its wood, or all of it (TREE_DRAWS): the light tuner's --tree-draw,
// until the user has seen it. With it on the shell's shadow comes from the same tree
// (tree_grown_whole).
let TREE_DRAWS = ["off", "wood", "all"];
let TREE_OFF = 0;
let TREE_WOOD = 1;
let TREE_ALL = 2;
var tree_draw = TREE_OFF;

// How the tree is lit (TreeBlock's light, look's y, z and w, tint): the light tuner's --tree-light,
// --tree-look and --tree-tint.
var tree_light = float4 { 2.5, 1.0, 0.35, 0.6 };
var tree_shade:   f32 = 1.0;
var tree_twig_px: f32 = 1.0;
var tree_spread:  f32 = 0.15;
var tree_tint = float4 { 0.2, 1.0, 1.0, 0.6 };

// The maple's wood (task 117's step three), each part off as in the app until checked: the
// bark from the age layers grown at startup (trees::bark_layers) in place of the first tile,
// its relief's strength (1 true slopes); the light wrapped past the terminator as if
// scattered under the bark (0 none) and Oren-Nayar's roughness (0 Lambert's); the junctions
// (collars, the parent's swell and ridge, the grain round each foot, caps on the ends) and
// the flare with its roots (trees::WoodShape). The light tuner's --tree-bark, --tree-relief,
// --tree-scatter, --tree-rough, --tree-junctions and --tree-roots.
var tree_bark = false;
var tree_relief:  f32 = 1.0;
var tree_scatter: f32 = 0.0;
var tree_rough:   f32 = 0.0;
var tree_wood = trees::WoodShape { .. };

// The wind on the tree's geometry (task 107's T4; shaders::TREE_WIND, TREE_FLUTTER): off
// (still, the app's), or the shadow's field moving it, each leaf also turning about its stalk
// in the high tier (HDR), the standard tier's held at its shadow's moment; the light tuner's
// --tree-wind. The flutter: how far a leaf turns in the room's mild wind (degrees) and how
// fast (radians a second of the wind), the tuner's --tree-flutter.
let TREE_WINDS = ["off", "on"];
var tree_wind = false;
var tree_flutter = float2 { 6.0, 9.0 };

// The tree's block (shaders::TREE_HEAD), for a pass of `samples` samples a pixel.
struct TreeBlock { origin: float4, light: float4, look: float4, depth: float4, tint: float4, layers: float4, bark: float4, matte: float4 }
fn tree_block(g: Gpu&, samples: i32) -> TreeBlock {
    let o = rooms::tree_origin(g.room);
    // The projection's depth as A - B / d (d the distance along the view), from the view's
    // matrix: its z row is A times its w row less B. Past 0.85 of the far plane's distance
    // the crown is squeezed into what is left in front of it.
    let m = g.frame.view_proj;
    let ww = m.c0.w * m.c0.w + m.c1.w * m.c1.w + m.c2.w * m.c2.w;
    let a = (m.c0.z * m.c0.w + m.c1.z * m.c1.w + m.c2.z * m.c2.w) / max(ww, 1e-12);
    let b = a * m.c3.w - m.c3.z;
    let far = b / max(a - 1.0, 1e-6);
    let from = a - b / (0.85 * far);
    let keep: f32 = 1e-4;
    let squeeze = (1.0 - keep - from) / max(a - from, 1e-6);
    return TreeBlock { model3d::f4(o, samples), tree_light, float4 { seen_outside(g), tree_shade, tree_spread, tree_twig_px },
                       float4 { from, squeeze, radians(tree_flutter.x), tree_flutter.y }, tree_tint, g.tree.layers,
                       float4 { if tree_bark { 1.0 } else { 0.0 }, tree_relief, trees::bark_age_scale(), trees::bark_age_from() },
                       float4 { tree_scatter, tree_rough, 0.0, 0.0 } };
}

// The tubes' two bark textures (TREE_WOOD_FRAG's slots 0 and 1): the age layers' height and
// cavity with tree_bark once made, else the first tile in both.
fn tree_bark_textures(g: Gpu&) -> Texture, Texture {
    if tree_bark && g.tree.bark_height.id != 0 { return g.tree.bark_height, g.tree.bark_cavity; }
    return g.tree.bark, g.tree.bark;
}

// Whether the tree's geometry is drawn: with the view out, once grown, where its card isn't
// drawn in its place.
fn tree_drawn(g: Gpu&) -> bool { tree_draw != TREE_OFF && outside_shown(g) && g.tree.wood_vb.id != 0 && !tree_card_in_view(g) }

// What the tree's geometry is grown and lit from: the room's key and tree, the shell's table.
let TREE_GEOMETRY_KEY = 5;
fn tree_geometry_key(g: Gpu&) -> float4[TREE_GEOMETRY_KEY] {
    let r = g.room;
    let t = room_shell::LIBRARY.table;
    return [r.key, r.window, r.tree, r.foliage, float4 { t.x, t.y, tree_draw, trees::wood_shape_key(tree_wood) + (if tree_bark { 8.0 } else { 0.0 }) }];
}

// The tree grown whole and made into its meshes and leaf cards (all drawn), lit by its
// crown's grid, and put on the GPU: before a draw, outside a pass, when what it is grown
// from changed. About 70 ms on the CPU, the bark and the leaf atlas 60 more the first time;
// never in the frame loop's steady state. The grid from the whole tree, the meshes and
// cards from the parts seen through the windows or casting through them.
fn tree_geometry<O>(o: O&, g: Gpu&) {
    guard tree_draw != TREE_OFF && outside_shown(g) && !g.bake_held else { return; }
    o.make_tree(g);
    let key = tree_geometry_key(g);
    var same = g.tree.wood_vb.id != 0;
    for i in TREE_GEOMETRY_KEY { if !same4(key[i], g.tree.made_for[i]) { same = false; } }
    guard !same else { return; }
    let t0 = clock();
    if g.tree.bark.id == 0 {
        var px: u8[>..] = [];
        trees::bark_tile(px);
        let mips = trees::mips_of(trees::BARK_W, trees::BARK_H);
        g.tree.bark = o.gpu_sampled(trees::BARK_W, trees::BARK_H, mips, RGBA8);
        var at = 0;
        for level in mips {
            let n = (trees::BARK_W >> level) * (trees::BARK_H >> level) * 4;
            o.gpu_upload(g.tree.bark, level, px[at..at + n]);
            at += n;
        }
    }
    if tree_bark && g.tree.bark_height.id == 0 {
        var heights:  u8[>..] = [];
        var cavities: u8[>..] = [];
        let b0 = clock();
        trees::bark_layers(heights, cavities);
        g.tree.bark_ms = (clock() - b0) * 1000.0;
        let mips = trees::mips_of(trees::BARK_W, trees::BARK_H);
        g.tree.bark_height = o.gpu_sampled(trees::BARK_W, trees::BARK_H, mips, RGBA8);
        g.tree.bark_cavity = o.gpu_sampled(trees::BARK_W, trees::BARK_H, mips, RGBA8);
        var at = 0;
        for level in mips {
            let n = (trees::BARK_W >> level) * (trees::BARK_H >> level) * 4;
            o.gpu_upload(g.tree.bark_height, level, heights[at..at + n]);
            o.gpu_upload(g.tree.bark_cavity, level, cavities[at..at + n]);
            at += n;
        }
    }
    let v = tree_view_of(g);
    let w = whole_tree_of(g);
    let sight = rooms::whole_sight(g.room, room_shell::LIBRARY);
    var verts:   trees::WoodVertex[>..] = [];
    var indices: u32[>..]               = [];
    var density: f32[>..]               = [];
    var cards:   float4[>..]            = [];
    var made = trees::WoodMesh { 0, 0, 0, 0 };
    var leaf_count = 0;
    {
        var all = trees::Tree { .. };
        trees::grow_whole(all, w, v, sight, false);
        let grid = trees::crown_grid(all, density);
        var t = trees::Tree { .. };
        // A reshaped tree is culled from the whole one rather than grown and reshaped again.
        if trees::reshaped(w.growth) { trees::cull_copy(all, t, w, v, sight); } else { trees::grow_whole(t, w, v, sight, true); }
        made = trees::wood_mesh(t, density, grid, trees::toward_sun(v), verts, indices, tree_wood);
        let d = trees::depths(t, v);
        g.tree.layers = float4 { v.shear.x, v.shear.y, d.near, d.far };
        if tree_draw == TREE_ALL {
            trees::leaf_shapes(cards);
            leaf_count = trees::leaf_cards(t, density, grid, trees::toward_sun(v), cards, cards.len);
        }
        g.tree.card_eye, g.tree.card_rect, g.tree.card_range = tree_card_place(g, verts, cards, sight);
    }
    if leaf_count > 0 && g.tree.leaf_shape.id == 0 {
        var shape: u8[>..] = [];
        var marks: u8[>..] = [];
        leaf_atlas::make(shape, marks);
        let mips = leaf_atlas::mips_of(leaf_atlas::ATLAS_W, leaf_atlas::ATLAS_H);
        g.tree.leaf_shape = o.gpu_sampled(leaf_atlas::ATLAS_W, leaf_atlas::ATLAS_H, mips, RGBA8);
        g.tree.leaf_marks = o.gpu_sampled(leaf_atlas::ATLAS_W, leaf_atlas::ATLAS_H, mips, RGBA8);
        var at = 0;
        for level in mips {
            let n = (leaf_atlas::ATLAS_W >> level) * (leaf_atlas::ATLAS_H >> level) * 4;
            o.gpu_upload(g.tree.leaf_shape, level, shape[at..at + n]);
            o.gpu_upload(g.tree.leaf_marks, level, marks[at..at + n]);
            at += n;
        }
    }
    if g.tree.leaves.id != 0 { o.gpu_release_storage(g.tree.leaves); g.tree.leaves = Buffer { 0 }; }
    if leaf_count > 0 { g.tree.leaves = o.gpu_storage(bytes_of(cards)); }
    g.tree.leaf_count = leaf_count;
    if g.tree.wood_vb.id != 0 { o.gpu_release_mesh(g.tree.wood_vb, g.tree.wood_ib); }
    g.tree.wood_vb, g.tree.wood_ib = o.gpu_mesh(bytes_of(verts), bytes_of(indices));
    g.tree.tube_count = made.tube_indices;
    g.tree.ribbon_first = made.ribbon_first;
    g.tree.ribbon_count = made.ribbon_indices;
    g.tree.made_for = key;
    g.tree.ms = (clock() - t0) * 1000.0;
}

// The tree's card (task 107's T5; shaders::TREE_CARD, CARD_VERT, CARD_FRAG): the geometry,
// still, drawn once into a TREE_CARD_W × TREE_CARD_H picture from one eye when the tree is
// grown or its light changes, and drawn in the view out's place as one quad at the crown's
// middle depth: in the floor's mirror (on), and in the main view in place of the geometry on
// a phone (no mirror there) or with main (to compare the two). Off, the app's. The light
// tuner's --tree-card off|on|main.
let TREE_CARDS = ["off", "on", "main"];
let CARD_OFF = 0;
let CARD_ON = 1;
let CARD_MAIN = 2;
var tree_card = CARD_OFF;
let TREE_CARD_W = 1024;
let TREE_CARD_H = 768;
// The eye it is drawn from, in the plan's metres from the games table's middle and up from
// the floor: the main menu's (the light tuner's table-window view, less-turned).
let TREE_CARD_EYE = float3 { -0.36, -2.05, 1.6 };

// CARD_VERT's block: the quad's corners in the world as the room is turned now, from the
// top left round to the bottom left.
struct TreeCardBlock { corners: float4[4] }

fn tree_card_wanted(g: Gpu&) -> bool { tree_card != CARD_OFF && outside_shown(g) && g.tree.wood_vb.id != 0 }
fn tree_card_in_mirror(g: Gpu&) -> bool { tree_card_wanted(g) && g.tree.card.id != 0 }
fn tree_card_in_view(g: Gpu&) -> bool { tree_card_in_mirror(g) && (tree_card == CARD_MAIN || !planar_allowed) }

// A point of the tree's frame in the world (shaders::TREE_FN's tree_world).
fn tree_point_world(g: Gpu&, p: float3) -> float3 {
    let o = rooms::tree_origin(g.room);
    let axes = g.frame.room_axes;
    let a = float3 { p.x - o.x, p.y - o.y, o.z - p.z };
    return float3 { axes.x * a.x + axes.z * a.z, a.y, axes.y * a.x + axes.w * a.z };
}

// Where the card lies: the eye (TREE_CARD_EYE) and the plane's depth, the mean of the leaves'
// blades' middles (the wood's without leaves); the rectangle on that plane (x0, y0, x1, y1)
// the tree covers as the eye sees it, cut to what the windows show from the eye and from
// under the floor (the mirror's eye) with a tenth's margin round it; and the nearest and
// farthest depths along the view, with room round them. All in the tree's frame.
fn tree_card_place(g: Gpu&, verts: trees::WoodVertex[>..]&, cards: float4[>..]&, sight: trees::Sight&) -> float4, float4, float2 {
    let s = room_shell::LIBRARY;
    let at = float3 { s.table.x + TREE_CARD_EYE.x, s.table.y + TREE_CARD_EYE.y, TREE_CARD_EYE.z };
    let e = rooms::plan_to_tree(g.room, s, at);
    let below = rooms::plan_to_tree(g.room, s, float3 { at.x, at.y, -at.z });
    var sum:  f64 = 0.0;
    var near: f32 = 1e9;
    var far:  f32 = -1e9;
    // The cards after the bent shapes (tree_geometry).
    let first = if cards.len > 0 { trees::LEAF_SHAPE_VEC4S } else { 0 };
    let leaves = (cards.len - first) / trees::LEAF_VEC4S;
    for i in leaves {
        let b = cards[first + i * trees::LEAF_VEC4S];
        let a = cards[first + i * trees::LEAF_VEC4S + 1];
        sum += (b.z + a.z * b.w * 0.5) as f64;
    }
    for &v in verts {
        near = min(near, v.pos.z);
        far = max(far, v.pos.z);
        if leaves == 0 { sum += v.pos.z as f64; }
    }
    let n = if leaves > 0 { leaves } else { max(verts.len, 1) };
    let depth = (sum / n) as f32;
    let k = depth - e.z;
    var x0: f32 = 1e9;
    var y0: f32 = 1e9;
    var x1: f32 = -1e9;
    var y1: f32 = -1e9;
    for &v in verts {
        let q = float2 { e.x, e.y } + (float2 { v.pos.x, v.pos.y } - float2 { e.x, e.y }) * (k / max(v.pos.z - e.z, 1.0));
        x0 = min(x0, q.x);
        y0 = min(y0, q.y);
        x1 = max(x1, q.x);
        y1 = max(y1, q.y);
    }
    for i in leaves {
        let b = cards[first + i * trees::LEAF_VEC4S];
        let r = b.w * 1.2;
        near = min(near, b.z - r);
        far = max(far, b.z + r);
        let q = float2 { e.x, e.y } + (float2 { b.x, b.y } - float2 { e.x, e.y }) * (k / max(b.z - e.z, 1.0));
        x0 = min(x0, q.x - r);
        y0 = min(y0, q.y - r);
        x1 = max(x1, q.x + r);
        y1 = max(y1, q.y + r);
    }
    // What the windows show, from the eye and from the mirror's.
    var wx0: f32 = 1e9;
    var wy0: f32 = 1e9;
    var wx1: f32 = -1e9;
    var wy1: f32 = -1e9;
    for &o in sight.windows {
        for from in [e, below] {
            let m = (depth - from.z) / max(sight.plane - from.z, 1.0);
            let a = float2 { from.x, from.y } + (float2 { o.x, o.z } - float2 { from.x, from.y }) * m;
            let b = float2 { from.x, from.y } + (float2 { o.y, o.w } - float2 { from.x, from.y }) * m;
            wx0 = min(wx0, min(a.x, b.x));
            wy0 = min(wy0, min(a.y, b.y));
            wx1 = max(wx1, max(a.x, b.x));
            wy1 = max(wy1, max(a.y, b.y));
        }
    }
    if wx1 > wx0 && wy1 > wy0 {
        let mx = (wx1 - wx0) * 0.1;
        let my = (wy1 - wy0) * 0.1;
        x0 = max(x0, wx0 - mx);
        y0 = max(y0, wy0 - my);
        x1 = min(x1, wx1 + mx);
        y1 = min(y1, wy1 + my);
    }
    if x1 <= x0 || y1 <= y0 {
        x0 = e.x - 1.0;
        y0 = e.y - 1.0;
        x1 = e.x + 1.0;
        y1 = e.y + 1.0;
    }
    return float4 { e.x, e.y, e.z, depth }, float4 { x0, y0, x1, y1 }, float2 { max((near - e.z) * 0.9, 1.0), (far - e.z) * 1.1 + 1.0 };
}

// The card's projection: a world point to the clip space of the card's picture, as the eye
// sees it on the card's plane (the tree's frame from the world, shaders::TREE_FN's tree_world
// turned back; the picture's x and y the plane's, its depth from card_range's near to far).
fn tree_card_view(g: Gpu&) -> Mat {
    let t .= g.tree;
    let o = rooms::tree_origin(g.room);
    let axes = g.frame.room_axes;
    let e = t.card_eye;
    let r = t.card_rect;
    let k = e.w - e.z;
    let hw = (r.z - r.x) * 0.5;
    let hh = (r.w - r.y) * 0.5;
    let cx = (r.x + r.z) * 0.5;
    let cy = (r.y + r.w) * 0.5;
    // Each of the tree's frame's coordinates as a row over the world's x, y, z and 1.
    let px = float4 { axes.x, 0.0, axes.y, o.x };
    let py = float4 { 0.0, 1.0, 0.0, o.y };
    let wr = float4 { -axes.z, 0.0, -axes.w, o.z - e.z };
    let xr = (px - float4 { 0.0, 0.0, 0.0, e.x }) * (k / hw) + wr * ((e.x - cx) / hw);
    let yr = (py - float4 { 0.0, 0.0, 0.0, e.y }) * (k / hh) + wr * ((e.y - cy) / hh);
    let near = t.card_range.x;
    let far = t.card_range.y;
    let a = far / (far - near);
    let zr = wr * a - float4 { 0.0, 0.0, 0.0, far * near / (far - near) };
    var m = default<Mat>();
    m.c0 = float4 { xr.x, yr.x, zr.x, wr.x };
    m.c1 = float4 { xr.y, yr.y, zr.y, wr.y };
    m.c2 = float4 { xr.z, yr.z, zr.z, wr.z };
    m.c3 = float4 { xr.w, yr.w, zr.w, wr.w };
    return m;
}

// The quad's corners in the world, top left, top right, bottom right, bottom left.
fn tree_card_block(g: Gpu&) -> TreeCardBlock {
    let r = g.tree.card_rect;
    let z = g.tree.card_eye.w;
    return TreeCardBlock { [model3d::f4(tree_point_world(g, float3 { r.x, r.w, z }), 1.0),
                            model3d::f4(tree_point_world(g, float3 { r.z, r.w, z }), 1.0),
                            model3d::f4(tree_point_world(g, float3 { r.z, r.y, z }), 1.0),
                            model3d::f4(tree_point_world(g, float3 { r.x, r.y, z }), 1.0)] };
}

// What the card is drawn from: the tree as grown, its light and look, the sun's way.
let TREE_CARD_KEY = 9;
fn tree_card_key(g: Gpu&) -> float4[TREE_CARD_KEY] {
    let m = g.tree.made_for;
    let b = tree_block(g, 1);
    return [m[0], m[1], m[2], m[3], m[4], b.light, b.look, b.tint, g.frame.light_dir];
}

// The card drawn again when what it is drawn from changed: before a draw, outside a pass,
// never in the frame loop's steady state. Its frame's block is the room's with the card's
// projection, eye and size; its tree's block keeps the far crown where it is.
fn make_tree_card<O>(o: O&, g: Gpu&) {
    guard tree_card_wanted(g) && !g.bake_held else { return; }
    let key = tree_card_key(g);
    var same = g.tree.card.id != 0;
    for i in TREE_CARD_KEY { if !same4(key[i], g.tree.card_for[i]) { same = false; } }
    guard !same else { return; }
    let t0 = clock();
    var f = g.frame;
    f.view_proj = tree_card_view(g);
    let e = g.tree.card_eye;
    f.eye = model3d::f4(tree_point_world(g, float3 { e.x, e.y, e.z }), 1.0);
    f.screen = float4 { TREE_CARD_W as f32, TREE_CARD_H as f32, 0.0, 0.0 };
    var b = tree_block(g, 4);
    b.depth = float4 { 1.0, 1.0, 0.0, 0.0 };
    o.tree_card_pass(g, f, b);
    o.gpu_flush();
    g.tree.card_for = key;
    g.tree.card_ms = (clock() - t0) * 1000.0;
}

// Whether the board may scatter light through its stone: on a desktop only (set at
// startup by the app). It adds 16 shadow taps a board pixel, about 0.35 ms at
// 1280 × 800 on an M1 Pro (task 094), not yet timed on a phone or tablet.
var scatter_allowed = false;

// The shell's shadow baked from the old maple grown whole (trees::grow_whole, task 107's
// T1) in place of the first tree (trees::grow): the light tuner's --tree-grow whole only,
// until its shadow is retuned and the user has seen it.
var tree_grown_whole = false;

// The look's board scattering (looks::Theme.board_scatter) into the frame's block where
// it is allowed, else off: only the desktop's lit shader (SHADOW_16) has it.
fn board_scatter(g: Gpu&) {
    guard g.look >= 0 else { return; }
    let s = look(g, g.look).board_scatter;
    let on = scatter_allowed && g.shadow_look == SHADOW_16 && s.x > 0.0;
    g.frame.frame_map.z = s.y;
    g.frame.frame_map.w = if on { s.x } else { 0.0 };
    g.frame.params.y = s.z;
}

// The key light, from the upper left of the screen, turned with the board (g.turn) so it
// keeps its place on screen while the board turns under it: its direction and the shadow
// map's projection.
fn light(g: Gpu&) {
    let t = look(g, g.look);
    var key = float4 { t.key.x, t.key.y, t.key.z, t.key.w };
    if g.table {
        let d = rooms::toward(g.room.key.x, g.room.key.y);
        key = float4 { d.x, d.y, d.z, g.room.key.z };
    }
    let l = model3d::spin(normalize(float3 { key.x, key.y, key.z }), g.turn);
    g.frame.light_view_proj = plan_light(l);
    g.frame.light_dir = model3d::f4(l, key.w);
}

// The board's half width the shadow map covers: the frame's outer edge (mesh's 4.6) and
// a little more, for its sides' feet, which the light's slant moves out by up to 0.45.
let PLAN_REACH: f32 = 5.1;

// The key light's map projected along the light onto the board's plane: a point's texel
// is where the light's ray through it meets y = 0, its depth how far along the ray, so
// the field and the frame fill the map at one texel size with nothing round them. An
// oblique, affine projection whose handedness is a view's along the light.
fn plan_light(l: float3) -> Mat {
    let k = 1.0 / PLAN_REACH;
    let a: f32 = -1.0 / 14.0;          // depth: 0.5 at the origin, nearer the light lower
    var m = default<Mat>();
    m.c0 = float4 { k, 0.0, a * l.x, 0.0 };
    m.c1 = float4 { -k * l.x / l.y, k * l.z / l.y, a * l.y, 0.0 };
    m.c2 = float4 { 0.0, -k, a * l.z, 0.0 };
    m.c3 = float4 { 0.0, 0.0, 0.5, 1.0 };
    return m;
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
fn marbled(g: Gpu&, t: looks::Theme&) -> bool { marble_of(g) > 0 && t.frame_fig.w < 0.5 && t.build.w < 0.5 }

// The marble the shown look's stone frame is made of (looks::marble_for), and its look:
// the chosen one's (g.stone, which the panel tunes) unless the look has its own.
fn marble_of(g: Gpu&) -> i64 { looks::marble_for(looks::shown(g.look, g.spring), g.marble) }
fn stone_of(g: Gpu&) -> looks::Marble {
    let m = marble_of(g);
    return if m == g.marble { g.stone } else { looks::marble(m) };
}

// The look `which` as g shows it: spring's chosen look with its carving.
fn look(g: Gpu&, which: i64) -> looks::Theme { looks::variant(which, g.spring, g.carving) }

// The look with its pieces as settings' Pieces has them: its own material, or Classic.
fn pieces_of(g: Gpu&, which: i64) -> looks::Theme {
    let t = look(g, which);
    return if g.classic { looks::classic(t, looks::shown(which, g.spring)) } else { t };
}

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

// The surfaces' side (model3d::BAKE_SIDE, or PHONE_BAKE_SIDE on a phone) from the next
// theme put on: the caller puts the theme on again for it to show.
fn set_bake(g: Gpu&, side: i64) { g.want_side = side; }

// Switches the wood's model, with its finish, and bakes the surfaces again.
fn set_wood<O>(o: O&, g: Gpu&, model: i64) {
    choose(g, model, -1);
    bake_surfaces(o, g);
}

// Sets the wood's model and finish, and the marble and its look (the prototype's tuning
// panel), baking again only the surfaces they show on: the wood's where the look has
// wood, the frame map where its frame is stone.
fn tune<O>(o: O&, g: Gpu&, wood: i64, finish: looks::Finish, marble: i64, stone: looks::Marble) {
    let t = look(g, g.look);
    let wood_changed = wood != g.wood || finish != g.finish;
    let slab_changed = g.look == looks::WINTER && (looks::is_slab(g.marble) || looks::is_slab(marble));
    let marble_changed = marble != g.marble || stone != g.stone;
    g.wood = clamp(wood, 0, model3d::WOOD_MODELS - 1);
    g.finish = finish;
    g.marble = clamp(marble, 0, looks::MARBLES - 1);
    g.stone = stone;
    let plan = (wood_changed && t.light_fig.w > 0.5) || (slab_changed && marble_changed);
    let frame = (wood_changed && t.frame_fig.w > 0.5) || (marble_changed && t.frame_fig.w < 0.5 && t.build.w < 0.5);
    if plan || frame { bake_surfaces(o, g, plan, frame); }
    g.frame.edge = model3d::linear4(t.edge);
    if marbled(g, t) && !(g.look == looks::WINTER && looks::is_slab(g.marble)) { g.frame.edge.w = 0.0; }
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
fn carve<O>(o: O&, g: Gpu&, spring: i64, c: looks::Carving) {
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
    apply(o, g, which, g.n);
}

// Puts the pieces on the GPU: `inst` two float4s an instance (view3d::Scene.inst), the
// last alphas.len of them fading (a captured piece, a wrong move's ghost), each as
// opaque as its alpha, drawn blended after the rest and casting no shadow; `squares` the
// field's occlusion, `marks` its marks and `lit` its glow rings and lit squares
// (view3d::Scene's, row * n + column); `selected` the selected piece's foot and radius
// (w 0 for none); `dim` the board's under a win. The shadow map is drawn again with the
// next frame when `moved`.
fn place<O>(o: O&, g: Gpu&, inst: const float4[:], alphas: const f32[:], squares: const float4[:], marks: const float4[:],
         lit: const float4[:], selected: float4, dim: f32, moved: bool) {
    let count = min(inst.len, 2 * MAX_INSTANCES);
    if count > 0 { o.gpu_update(g.instances, bytes_of(inst[..count])); }
    g.instance_count = count / 2;
    let fading = min(alphas.len, g.instance_count);
    g.solid = g.instance_count - fading;
    for i in fading { g.alphas[i] = alphas[i]; }
    o.gpu_update(g.squares, bytes_of(squares[..min(squares.len, SQUARE_ENTRIES)]));
    for i in SQUARE_ENTRIES { g.squares_now[i] = if i < squares.len { squares[i] } else { float4_0 }; }
    o.gpu_update(g.marks, bytes_of(marks[..min(marks.len, SQUARES)]));
    if lit.len > 0 { o.gpu_update(g.glows, bytes_of(lit[..min(lit.len, SQUARES)])); }
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

// Draws a frame seen through view_proj from `eye` into `out`, a color target of `screen`
// (the renderer's screen; or for Texture { 0 } g.image, kept for show()): the shadow map
// first if the pieces moved, then the one pass, antialiased as g.aa says. Without the
// `backdrop` the target is clear but for the board, its shadow, and the pieces
// (premultiplied), for show() to lay over a backdrop drawn apart (backdrop(), or the
// app's photograph). With `keep_depth` the board's depth is kept too, at 1x, for
// marks_over. Into `out`, the scene is drawn at scene_size_of(screen) and, if that is
// smaller, scaled up into it (upscale_pass). Recording only; the caller's frame submits it.
fn draw<O>(o: O&, g: Gpu&, view_proj: Mat, eye: float3, out: Texture, screen: int2, shadow_every: bool = false,
        backdrop: bool = true, keep_depth: bool = false) {
    let size = if out.id != 0 && !keep_depth { scene_size_of(screen) } else { screen };
    let scaled = size.x != screen.x || size.y != screen.y;
    if size.x != g.size.x || size.y != g.size.y { targets(o, g, size); }
    // The scenic views into the HDR target, tonemapped after (tone_pass); its targets in
    // place of the 8-bit ones, so each switch makes them again.
    let hdr = hdr_shown(g) && out.id != 0;
    if hdr { o.make_hdr(g); }
    if hdr != g.hdr {
        give_back(o, g);
        g.hdr = hdr;
    }
    o.pass_targets(g);
    if scaled && g.scene_image.id == 0 { g.scene_image = o.scene_target(g, size); }
    let target = if scaled { g.scene_image } else if out.id == 0 { g.image } else { out };
    g.frame.view_proj = view_proj;
    g.frame.eye = model3d::f4(eye, 1.0);
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    g.frame.toe = tone_toe;
    keep_backdrop(o, g, size);
    // The props' occlusion baked when the light tuner turns their light on.
    if props_light && g.table && g.table_vb.id != 0 && !g.props_baked { table_mesh(o, g); }
    bake_tree(o, g);
    if dust.count > 0 { o.make_motes(g); }
    room_surfaces(o, g);
    tree_geometry(o, g);
    make_tree_card(o, g);
    table_map(o, g);
    sun_derived(o, g);
    window_map(o, g);
    box_map(o, g);
    if g.shadow_dirty || shadow_every {
        o.shadow_pass(g);
        g.shadow_dirty = false;
    }
    occlusion(o, g);
    refl_map(o, g);
    // With the window's glow the pass draws into the image, and the glow adds it into the
    // target; not where the image is the target (the app's kept image, which shows no shell).
    let glowing = bloom_shown(g) && out.id != 0;
    if ssao_shown(g) { o.ssao_pass(g, size); }
    let outside = outside_shown(g);
    let mirror = planar_shown(g);
    let table_covers = (outside || mirror) && table_hides_screen(g, view_proj);
    g.planar_current = mirror && (planar_view > 1 || (!table_covers && floor_in_frustum(view_proj, g.room_frame)));
    if g.planar_current {
        let clip, plain = mirrored_frames(g);
        o.planar_pass(g, size, clip, plain, planar_resolve_of(g, clip));
    }
    let shown = if glowing { g.image } else { target };
    // The room baked by now (room_surfaces): the board's pipelines in its shell.
    if !hdr && board_in_shell(g) { o.make_lit_shell(g); }
    o.board_pass(g, if hdr { g.hdr_image } else { shown }, size, backdrop, outside, table_covers);
    if hdr && haze_shown(g) { o.haze_pass(g, size); }
    if hdr && glow_shown(g) {
        glow_exposure = camera_exposure(g);
        o.glow_pass(g, size);
    }
    if hdr { o.tone_pass(g, shown); }
    if glowing { o.bloom_pass(g, g.image, target, size); }
    if depth_shown(g) {
        o.depth_pass(g);
        if depth_view > 0 { o.depth_show_pass(g, target, depth_show_of(g)); }
    }
    if planar_view > 1 && g.planar_current { o.planar_show_pass(g, target, planar_show_of(g, size)); }
    if keep_depth { o.draw_depth(g); }
    if scaled { o.upscale_pass(g, out, upscale_of(size, screen)); }
}

// The scenic views' HDR (build/notes/bokeh/, task 111), the high tier's for the depth of
// field: the room's shell with its view out, multisampled, with the screen's maps, drawn into
// a target of linear light (hdr_format: RG11B10F, or RGBA16F where that can't be drawn
// into), then tonemapped, graded and dithered into the 8-bit picture. Not with the tuner's
// views of the room (their own pipelines tonemap), nor the table before the room's light
// is baked. hdr_allowed: the light tuner's (--hdr, X); the app draws no scenic view yet.
var hdr_allowed = false;
fn hdr_shown(g: Gpu&) -> bool {
    hdr_allowed && outside_shown(g) && (g.aa == AA_MSAA || g.aa == AA_SMAA) && ssao_allowed && !room_views_on()
    && (!table_shown(g) || table_in_room(g))
}

// The depth of field's depth (depth_pass): with HDR, while the lens is on or the tuner's view
// of it is shown (depth_view: 0 none, 1 the distance, 2 the lens's disc; DEPTH_SHOW_FRAG).
var depth_view = 0;
fn depth_shown(g: Gpu&) -> bool { g.hdr && (lens.on || depth_view > 0) }
// LACE_DEPTH_FRAG's block: the room's tile (surfaces_block's).
struct LaceDepth { tile: float4 }
// DEPTH_SHOW_FRAG's block: how its depth d turns into the distance along the view, b / (d -
// a), worked out from two points ahead of the eye through the frame's view_proj, and the
// metres a world unit; the lens; the view and the picture's width.
struct DepthShow { to_w: float4, lens: float4, view: float4 }
fn depth_show_of(g: Gpu&) -> DepthShow {
    let m = g.frame.view_proj;
    let ahead = normalize(float3 { m.c0.w, m.c1.w, m.c2.w });
    let e = float3 { g.frame.eye.x, g.frame.eye.y, g.frame.eye.z };
    var zw: float2[2] = [float2_0; 2];
    for k in 2 {
        let t: f32 = if k == 0 { 10.0 } else { 100.0 };
        let p = e + ahead * t;
        let z = m.c0.z * p.x + m.c1.z * p.y + m.c2.z * p.z + m.c3.z;
        let w = m.c0.w * p.x + m.c1.w * p.y + m.c2.w * p.z + m.c3.w;
        zw[k] = float2 { z, w };
    }
    let a = (zw[1].x - zw[0].x) / (zw[1].y - zw[0].y);
    let b = zw[0].x - a * zw[0].y;
    return DepthShow { float4 { a, b, 1.0 / surfaces::METRE, 0.0 },
                       float4 { lens.focus * surfaces::METRE, lens.aperture, lens.near_cap, lens.far_cap },
                       float4 { depth_view, g.frame.screen.x, 0.0, 0.0 } };
}

// The 3D scene's resolution budget, the high tier's on a Retina or 4K screen, where the
// room's passes cost about their pixels: draw() into a target draws the scene at most
// scene_pixels pixels (0 no limit) and at most scene_scale of the screen's side, keeping
// its shape, then scales it up to the screen with Catmull-Rom (scene_cubic) or bilinear.
// The UI drawn over it after keeps the screen's pixels. Off by default: the scene draws at
// the screen's size. HIGH_SCENE_PIXELS is the cap a manual render scale offers (4.1 MP: 0.85
// of a 3024 × 1890 screen's side, 0.70 of 4K's); the app's kept image is drawn at the
// screen's size.
let HIGH_SCENE_PIXELS: f32 = 4.1e6;
var scene_pixels: f32 = 0.0;
var scene_scale:  f32 = 1.0;
var scene_cubic = true;
fn scene_size_of(screen: int2) -> int2 {
    let pixels = (screen.x as f32) * (screen.y as f32);
    var k = min(scene_scale, 1.0);
    if scene_pixels > 0.0 && pixels > scene_pixels { k = min(k, sqrt(scene_pixels / pixels)); }
    guard k < 1.0 else { return screen; }
    return int2 { max((screen.x as f32 * k + 0.5) as i32, 1), max((screen.y as f32 * k + 0.5) as i32, 1) };
}
// shaders::UPSCALE_FRAG's block: a screen pixel in the scene's texels, a scene texel in uv.
struct Upscale { upscale: float4 }
fn upscale_of(size: int2, screen: int2) -> Upscale {
    Upscale { float4 { size.x / (screen.x as f32), size.y / (screen.y as f32), 1.0 / (size.x as f32), 1.0 / (size.y as f32) } }
}

// The room's ambient occlusion (ssao_pass, shaders::SSAO_FRAG): drawn where the tiers allow
// it (the standard and the high: not on a phone, which the app says), the room shows and
// its strength is over 0. ssao_view: the tuner's views of it (shaders::SSAO_FN's).
var ssao_allowed = true;
// The phone's tier's floor and metals with their sharp box reflection (shaders::SHARP_BOX); off
// gives them the walls' broad one (the light tuner's --box off, to weigh it on a tablet).
var sharp_box_allowed = true;
var ssao_view = 0;
// The occlusion by GTAO (shaders::GTAO_FRAG) in place of SSAO_FRAG's, its visibility raised
// to gtao_power: the high tier's (app::follow_screen, on a desktop) and the light tuner's
// default (--gtao off for SSAO).
var ssao_gtao = false;
var gtao_power: f32 = 1.5;
// Its largest spiral, a share of the map's width.
let SSAO_SPIRAL: f32 = 0.06;
fn ssao_shown(g: Gpu&) -> bool { ssao_allowed && room_shown(g) && g.room.ssao.x > 0.0 && g.ssao_blur.id != 0 }
fn ssao_size_of(size: int2) -> int2 { int2 { max((size.x + 1) / 2, 1), max((size.y + 1) / 2, 1) } }
// SSAO_FRAG's block for the map of q texels: the view's row of view_proj that gives the clip's
// w, the half-size pixels a unit spans at w 1, the reach, bias (rooms::Room.ssao), largest
// spiral and gain.
// GTAO_FRAG's too: ray_x, ray_y a pixel's step across and down the screen's plane in the world
// (screen_steps); gtao: x its power.
struct SsaoBlock { fwd: float4, look: float4, ray_x: float4, ray_y: float4, gtao: float4 }
fn ssao_pass_of(g: Gpu&, q: int2) -> SsaoBlock {
    let m = g.frame.view_proj;
    let across = length(float3 { m.c0.x, m.c1.x, m.c2.x });
    let r = screen_steps(g.frame, q);
    SsaoBlock { float4 { m.c0.w, m.c1.w, m.c2.w, across * 0.5 * q.x },
                float4 { g.room.ssao.y * surfaces::METRE, g.room.ssao.z, SSAO_SPIRAL * q.x, g.room.ssao.w },
                r[0], r[1], float4 { gtao_power, 0.0, 0.0, 0.0 } }
}
// How far a pixel across and a pixel down a target of `size` pixels moves the ray from the
// eye in f's view (in the world, on the plane of the clip's middle depth, which is flat
// across the view): the screen's plane's directions, a pixel long there.
fn screen_steps(f: Frame, size: int2) -> float4[2] {
    let b = inverse(f.view_proj);
    let p0 = unproject(b, -1.0, 1.0);
    let dx = (unproject(b, 1.0, 1.0) - p0) * (1.0 / size.x);
    let dy = (unproject(b, -1.0, -1.0) - p0) * (1.0 / size.y);
    return [float4 { dx.x, dx.y, dx.z, 0.0 }, float4 { dy.x, dy.y, dy.z, 0.0 }];
}
// Where the clip's (x, y) at its middle depth is, by b the inverse of view_proj.
fn unproject(b: Mat, x: f32, y: f32) -> float3 {
    let v = b.c0 * x + b.c1 * y + b.c2 * 0.5 + b.c3;
    return float3 { v.x / v.w, v.y / v.w, v.z / v.w };
}
// ROOM_FRAG's and TABLE_FRAG's ssao (shaders::SSAO_FN): the strength, the view, the map's
// texels a pixel of the pass (its screen, twice the target's when ngfx supersamples); all 0
// when it isn't drawn.
fn ssao_block_of(g: Gpu&) -> float4 {
    guard ssao_shown(g) && g.ssao_map.id != 0 else { return float4_0; }
    let s = g.frame.screen;
    return float4 { g.room.ssao.x, ssao_view, g.ssao_size.x / max(s.x, 1.0), g.ssao_size.y / max(s.y, 1.0) };
}
fn ssao_or_stand_in(g: Gpu&) -> Texture { if g.ssao_map.id != 0 { g.ssao_map } else { g.crown_map } }

// The floor's mirror (planar_pass, rooms::Room.planar): the room drawn mirrored across the
// floor into a target planar_scale times smaller (3, a third of the size; across at least
// planar_least_wide), where the tiers allow
// it (the standard and the high: not on a phone, which the app says), the shell shows and
// its strength is over 0; else the floor sees the room's box (shaders::ROOM_FRAG's
// room_seen). planar_view: the tuner's views (off, the floor's reflection alone, the map's
// light, its distances).
var planar_allowed = true;
// The floor's cheap mirror world (the light tuner's --mirror-cheap, a trial, off): the
// room's large shapes and the table, each surface at its mean colour, lit by the baked
// light and the sun through the windows' outlines, in one cheap shader
// (shaders::MIRROR_CHEAP_PASS); the cord left out. Set before the room's mesh is made.
var mirror_cheap = false;
fn mirror_cheap_on(g: Gpu&) -> bool { mirror_cheap && g.cheap_room.id != 0 && g.cheap_count > 0 }
var planar_view = 0;
var planar_scale: i32 = 3;
let PLANAR_MIPS = 6;
// How steeply the mirror's depth climbs with the height over the floor (its z is this times
// the height): at most the clip's w for all it frames, which is never under the height.
let PLANAR_DEPTH: f32 = 0.25;
// The clip's plane a little over the floor, so the floor itself is never drawn in it (world
// units, 1.5 mm).
let PLANAR_LIFT: f32 = 0.05;
fn planar_shown(g: Gpu&) -> bool {
    planar_allowed && room_shown(g) && g.room.planar.x > 0.0 && g.planar_walls.id != 0
}
// A convex floor can be outside a clip plane only if all four corners are
// outside that same plane. Keep the test homogeneous for corners behind the eye. The
// corners are turned by the room's frame, as ROOM_VERT turns the floor.
fn floor_in_frustum(m: Mat, turn: surfaces::Frame) -> bool {
    let a, b = room_shell::floor_diagonal(room_shell::LIBRARY);
    let base = m.c1 * surfaces::FLOOR_Y + m.c3;
    var outside: u32 = 63;
    for x in [a.x, b.x] {
        for z in [a.y, b.y] {
            let w = turn.along * x + turn.into * z;
            let p = base + m.c0 * w.x + m.c2 * w.y;
            // Leave room for rounding between the CPU and the vertex shader.
            let margin: f32 = 0.01;
            var planes: u32 = 0;
            if p.w + p.x < -margin { planes |= 1; }
            if p.w - p.x < -margin { planes |= 2; }
            if p.w + p.y < -margin { planes |= 4; }
            if p.w - p.y < -margin { planes |= 8; }
            if p.z < -margin { planes |= 16; }
            if p.w - p.z < -margin { planes |= 32; }
            outside &= planes;
        }
    }
    return outside == 0;
}

// Whether the games table's top fills the whole screen (the board's views from over it), so
// no floor shows: the screen's corners inside its outline, an inscribed polygon a little
// inside the top's rim, every point of which lies within the depth range in front of the
// eye, which is over the top.
let TOP_SIDES = 24;
fn table_hides_screen(g: Gpu&, m: Mat) -> bool {
    guard table_shown(g) && g.frame.eye.y > mesh::TABLE_TOP else { return false; }
    // Stay on the flat part of the bevelled top, including the tuner's thick edges.
    let inset = max(0.08, 0.45 * max(g.table_edge.y, 0.3));
    let radius = mesh::TABLE_R;
    let r = min(radius * 0.97, radius - inset - 0.01);
    guard r > 0.0 else { return false; }
    var at: float2[TOP_SIDES] = [float2_0; TOP_SIDES];
    for k in TOP_SIDES {
        let a = 2.0 * PI * (k as f32) / (TOP_SIDES as f32);
        let p = m.c0 * (r * cos(a)) + m.c1 * mesh::TABLE_TOP + m.c2 * (mesh::TABLE_Z + r * sin(a)) + m.c3;
        guard p.w > 1e-4 && p.z >= 0.0 && p.z <= p.w else { return false; }
        at[k] = float2 { p.x / p.w, p.y / p.w };
    }
    for c in [float2 { -1.0, -1.0 }, float2 { 1.0, -1.0 }, float2 { 1.0, 1.0 }, float2 { -1.0, 1.0 }] {
        var left = 0;
        var right = 0;
        for k in TOP_SIDES {
            let a = at[k];
            let b = at[(k + 1) % TOP_SIDES];
            let side = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
            if side > 0.0 { left++; } else { right++; }
        }
        guard left == TOP_SIDES || right == TOP_SIDES else { return false; }
    }
    return true;
}

// The mirror's least width in texels, at most the screen's: half of a 1600-pixel screen let
// a window's bars, a few texels wide, step a whole texel as the eye moved and pulse in the
// floor; the height stays planar_scale times smaller, as the floor draws the reflection out
// down the screen.
var planar_least_wide: i32 = 1600;
fn planar_size_of(size: int2) -> int2 {
    let k: i32 = max(planar_scale, 1);
    let wide = max((size.x + k - 1) / k, min(size.x, planar_least_wide));
    int2 { max(wide, 1), max((size.y + k - 1) / k, 1) }
}

// The frame mirrored across the floor: view_proj times the mirror (y to 2 floor - y), the
// eye under the floor; clip's z made the height over the floor (PLANAR_DEPTH, PLANAR_LIFT),
// so what stands under it is clipped and depth grows along each ray; plain keeps the
// view's z, for the view out, which is drawn first with no depth and stands below the floor.
// Nothing is dimmed.
fn mirrored_frames(g: Gpu&) -> Frame, Frame {
    let fy = surfaces::FLOOR_Y;
    var plain = g.frame;
    let m = g.frame.view_proj;
    plain.view_proj.c1 = float4_0 - m.c1;
    plain.view_proj.c3 = m.c3 + m.c1 * (2.0 * fy);
    plain.eye = float4 { g.frame.eye.x, 2.0 * fy - g.frame.eye.y, g.frame.eye.z, 1.0 };
    let q = planar_size_of(int2 { g.frame.screen.x as i32, g.frame.screen.y as i32 });
    plain.screen = float4 { q.x, q.y, 0.0, 0.0 };
    var clip = plain;
    clip.view_proj.c0.z = 0.0;
    clip.view_proj.c1.z = PLANAR_DEPTH;
    clip.view_proj.c2.z = 0.0;
    clip.view_proj.c3.z = -PLANAR_DEPTH * (fy + PLANAR_LIFT);
    return clip, plain;
}

// The inverse of m (columns), by cofactors; m as a projection always has one.
fn inverse(m: Mat) -> Mat {
    let a: f32[16] = [m.c0.x, m.c0.y, m.c0.z, m.c0.w, m.c1.x, m.c1.y, m.c1.z, m.c1.w,
                      m.c2.x, m.c2.y, m.c2.z, m.c2.w, m.c3.x, m.c3.y, m.c3.z, m.c3.w];
    var r: f32[16] = [0.0; 16];
    r[0] = a[5] * a[10] * a[15] - a[5] * a[11] * a[14] - a[9] * a[6] * a[15] + a[9] * a[7] * a[14] + a[13] * a[6] * a[11] - a[13] * a[7] * a[10];
    r[4] = -a[4] * a[10] * a[15] + a[4] * a[11] * a[14] + a[8] * a[6] * a[15] - a[8] * a[7] * a[14] - a[12] * a[6] * a[11] + a[12] * a[7] * a[10];
    r[8] = a[4] * a[9] * a[15] - a[4] * a[11] * a[13] - a[8] * a[5] * a[15] + a[8] * a[7] * a[13] + a[12] * a[5] * a[11] - a[12] * a[7] * a[9];
    r[12] = -a[4] * a[9] * a[14] + a[4] * a[10] * a[13] + a[8] * a[5] * a[14] - a[8] * a[6] * a[13] - a[12] * a[5] * a[10] + a[12] * a[6] * a[9];
    r[1] = -a[1] * a[10] * a[15] + a[1] * a[11] * a[14] + a[9] * a[2] * a[15] - a[9] * a[3] * a[14] - a[13] * a[2] * a[11] + a[13] * a[3] * a[10];
    r[5] = a[0] * a[10] * a[15] - a[0] * a[11] * a[14] - a[8] * a[2] * a[15] + a[8] * a[3] * a[14] + a[12] * a[2] * a[11] - a[12] * a[3] * a[10];
    r[9] = -a[0] * a[9] * a[15] + a[0] * a[11] * a[13] + a[8] * a[1] * a[15] - a[8] * a[3] * a[13] - a[12] * a[1] * a[11] + a[12] * a[3] * a[9];
    r[13] = a[0] * a[9] * a[14] - a[0] * a[10] * a[13] - a[8] * a[1] * a[14] + a[8] * a[2] * a[13] + a[12] * a[1] * a[10] - a[12] * a[2] * a[9];
    r[2] = a[1] * a[6] * a[15] - a[1] * a[7] * a[14] - a[5] * a[2] * a[15] + a[5] * a[3] * a[14] + a[13] * a[2] * a[7] - a[13] * a[3] * a[6];
    r[6] = -a[0] * a[6] * a[15] + a[0] * a[7] * a[14] + a[4] * a[2] * a[15] - a[4] * a[3] * a[14] - a[12] * a[2] * a[7] + a[12] * a[3] * a[6];
    r[10] = a[0] * a[5] * a[15] - a[0] * a[7] * a[13] - a[4] * a[1] * a[15] + a[4] * a[3] * a[13] + a[12] * a[1] * a[7] - a[12] * a[3] * a[5];
    r[14] = -a[0] * a[5] * a[14] + a[0] * a[6] * a[13] + a[4] * a[1] * a[14] - a[4] * a[2] * a[13] - a[12] * a[1] * a[6] + a[12] * a[2] * a[5];
    r[3] = -a[1] * a[6] * a[11] + a[1] * a[7] * a[10] + a[5] * a[2] * a[11] - a[5] * a[3] * a[10] - a[9] * a[2] * a[7] + a[9] * a[3] * a[6];
    r[7] = a[0] * a[6] * a[11] - a[0] * a[7] * a[10] - a[4] * a[2] * a[11] + a[4] * a[3] * a[10] + a[8] * a[2] * a[7] - a[8] * a[3] * a[6];
    r[11] = -a[0] * a[5] * a[11] + a[0] * a[7] * a[9] + a[4] * a[1] * a[11] - a[4] * a[3] * a[9] - a[8] * a[1] * a[7] + a[8] * a[3] * a[5];
    r[15] = a[0] * a[5] * a[10] - a[0] * a[6] * a[9] - a[4] * a[1] * a[10] + a[4] * a[2] * a[9] + a[8] * a[1] * a[6] - a[8] * a[2] * a[5];
    let det = a[0] * r[0] + a[1] * r[4] + a[2] * r[8] + a[3] * r[12];
    let k: f32 = if abs(det) > 1e-30 { 1.0 / det } else { 0.0 };
    var out = default<Mat>();
    out.c0 = float4 { r[0], r[1], r[2], r[3] } * k;
    out.c1 = float4 { r[4], r[5], r[6], r[7] } * k;
    out.c2 = float4 { r[8], r[9], r[10], r[11] } * k;
    out.c3 = float4 { r[12], r[13], r[14], r[15] } * k;
    return out;
}

// shaders::PLANAR_RESOLVE_FRAG's block for the mirror drawn with clip's frame: the inverse of
// its view_proj, the eye and the floor's y, the room's exposure's inverse and the farthest
// distance kept (12 m).
struct PlanarResolve { back: float4[4], eye: float4, tone: float4 }
fn planar_resolve_of(g: Gpu&, clip: Frame) -> PlanarResolve {
    let b = inverse(clip.view_proj);
    let exposure = max(g.frame.params.x * g.room.room_exposure, 1e-3);
    PlanarResolve { [b.c0, b.c1, b.c2, b.c3], float4 { g.frame.eye.x, g.frame.eye.y, g.frame.eye.z, surfaces::FLOOR_Y },
                    float4 { 1.0 / exposure, 12.0 * surfaces::METRE, 0.0, 0.0 } }
}
// The tuner's view of the map over `size`.
struct PlanarShow { show: float4, px: float4 }
fn planar_show_of(g: Gpu&, size: int2) -> PlanarShow {
    PlanarShow { float4 { g.frame.params.x * g.room.room_exposure, if planar_view > 2 { 2.0 } else { 1.0 }, 6.0 * surfaces::METRE, 0.0 },
                 float4 { 1.0 / size.x, 1.0 / size.y, 0.0, 0.0 } }
}
// ROOM_FRAG's planar and planar_look (all 0 where the mirror isn't drawn): the strength, the
// floor's view, the map's texels a world unit spans at w 1, its last mip; the boards' own
// wax and the blur.
fn planar_block_of(g: Gpu&) -> float4 {
    guard planar_seen_on_floor(g) else { return float4_0; }
    let m = g.frame.view_proj;
    let across = length(float3 { m.c0.x, m.c1.x, m.c2.x });
    let view: f32 = if planar_view == 1 { 1.0 } else { 0.0 };
    return float4 { g.room.planar.x, view, across * 0.5 * g.planar_size.x, PLANAR_MIPS - 1 };
}
fn planar_look_of(g: Gpu&) -> float4 {
    guard planar_seen_on_floor(g) else { return float4 { 0.0, 0.0, floor_box.x, floor_box.y }; }
    return float4 { g.room.planar.z, g.room.planar.y, floor_box.x, floor_box.y };
}
// Whether the room's floor sees the mirror this frame (drawn with g.room_planar).
fn planar_seen_on_floor(g: Gpu&) -> bool { g.planar_current && g.planar_map.id != 0 && g.room_planar.id != 0 }
// The room's and the table's blocks in the mirror: no screen occlusion (the map is the
// screen's), no mirror of its own.
fn mirror_surfaces_block(g: Gpu&) -> SurfacesBlock {
    var b = surfaces_block(g);
    b.ssao = float4_0;
    b.planar = float4_0;
    b.planar_look = float4_0;
    b.contact = float4_0;
    b.refl = float4_0;
    // The mirror's world reads the woods' fields (room_textures): a picture's way as ours.
    b.wood_oak[2].w = min(b.wood_oak[2].w, WOOD_STAINED as f32);
    b.wood_floor[2].w = min(b.wood_floor[2].w, WOOD_STAINED as f32);
    return b;
}

// The sun's contact shadows (ROOM_FRAG's contact_lit): x how strong (0 none), y the ray's
// length toward the sun (world units), z its steps, w the thickness a surface on the
// half-size map (pre_place) is taken to have (world units); only where the SSAO's map
// is drawn (the standard and high tiers). The tuner's --contact.
var contact_look = float4 { 0.8, 3.0, 12.0, 1.5 };
fn contact_block_of(g: Gpu&) -> float4 {
    guard ssao_shown(g) && g.pre_place.id != 0 else { return float4_0; }
    return contact_look;
}
fn pre_place_or_stand_in(g: Gpu&) -> Texture { if g.pre_place.id != 0 { g.pre_place } else { g.crown_map } }
// The sun's broad sheen on the painted wood and the paper (ROOM_FRAG's sheen): x its
// strength (0 none), y its roughness, z the paper's share, w the tuner's view (1: the sun's
// highlights alone, ×4). The tuner's --sheen.
var sheen_look = float4 { 2.0, 0.8, 1.0, 0.0 };
// The wallpaper's ground and print (sRGB and roughness, surfaces::Look's paper and gold), and
// with physical_coat whether the print is a metal (gold its colour at normal incidence) over
// a matt ground. The light tuner's --paper-ground, --paper-gold and --paper-metal.
var paper_ground = surfaces::LOOK.paper;
var paper_gold = surfaces::LOOK.gold;
var paper_metal = false;
// The wallpaper close up with physical_coat and paper_metal (ROOM_FRAG's paper_close), each 0
// off: x the print's sharp outline and lines, y the powder's tone and flecks, z the
// paper's grain, w its relief; all 0 keeps the mask flat, and the mask without its grain
// (paper_grain). The light tuner's --paper-detail.
var paper_detail = float4_0;
fn paper_close_on() -> bool { return paper_detail.x != 0.0 || paper_detail.y != 0.0 || paper_detail.z != 0.0 || paper_detail.w != 0.0; }
// Whether one of the light tuner's views of the room is on (the screen's occlusion, the
// indirect light, the sun's highlights, the floor's reflection alone): the room's pipelines
// then carry their code (shaders::ROOM_VIEWS), else they leave it out.
// The painted wood's relief tile's strength over its look's (the tuner's --paint-relief, 1
// as made).
var paint_relief: f32 = 1.0;
// The window view's steps (build/notes/builder-27/), each a strength over its look's, 1 as
// made, 0 off: x the lace's sun (its shadows on it full and its glow where lit), y the sun
// the lace scatters on below it, z the glass's film, w its cleaning scratches. The light
// tuner's --lace-sun, --lace-scatter, --glass-film, --scratches.
var window_view = float4 { 1.0, 1.0, 1.0, 1.0 };
// The lace's room-side fill (build/notes/lace-shade/): x what is left of it where neither
// the sun nor the sky behind the niche reaches the cloth, 0.5; y how much the folds beside
// it darken it (room_shell::fold_hidden), 1.5. The light tuner's --lace-shade-fill and
// --lace-fold-ao.
var lace_shade = float4 { 0.5, 1.5, 0.0, 0.0 };
// The sun's broad veil in the sky round it (OUTSIDE_FRAG, the tuner's --sun-veil), 1 as
// made, 0 off.
var sun_veil: f32 = 1.0;
// The light tuner's park on the ground (--park, model3d::view_out's lawn and cards, its own
// shaders in TUNED_OUTSIDE and TUNED_OUTSIDE_HDR): the view out's mesh carries them.
var park_ground = false;

fn room_views_on() -> bool { ssao_allowed && (ssao_view > 0 || sheen_look.w > 0.5 || planar_view == 1) }
// The sun on the room's surfaces: x its saturation about its luminance there and in its
// bake (1 as the key is; the tuner's --room-sun); the panelling oak's own: y its share of
// the room's sun, z its saturation, w its share of the sheen (the tuner's --oak-sun). The
// oak keeps the sun it had before the room's sun was doubled (shell_sun.y 2.2): the user
// wanted the stronger sun on the paper and the doors, the wainscot as it was.
let ROOM_SUN_AS_MADE = float4 { 0.6, 0.5, 1.0, 0.0 };
var room_sun = ROOM_SUN_AS_MADE;
fn room_sun_of(c: float3) -> float3 {
    let y = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z;
    return float3 { y, y, y } + (c - float3 { y, y, y }) * room_sun.x;
}
fn mirror_table_block(g: Gpu&) -> TableBlock {
    var b = table_block(g);
    b.ssao = float4_0;
    return b;
}

// Whether the window's glow is drawn: the shell's room with its bloom on, in 8 bits (the
// HDR target has its own, glow_pass).
fn bloom_shown(g: Gpu&) -> bool { room_shown(g) && g.room.bloom.x > 0.0 && g.bloom_add.id != 0 && !g.hdr }

// The scenic views' glow in the HDR target's linear light, before the tonemap
// (shaders::GLOW_DOWN_FRAG, GLOW_UP_FRAG, HDR_TONE_FRAG): x its strength (0 none), y the
// threshold it starts from and z the knee's half width (linear light, the tonemap's white
// about 1), w its reach (each coarser level's share, 0 to 1); levels how many it goes down,
// the first a quarter of the picture, each half the last (at most GLOW_LEVELS); cap the
// brightest a channel is taken at. Under AgX the threshold, the knee and the cap are in the
// picture's light, after the camera's exposure (glow_exposure, camera_exposure's), so the
// glow starts near AgX's white as it starts near the shoulder's without it.
let GLOW_LEVELS = 6;
struct HdrGlow {
    look:   float4 = float4 { 0.06, 1.0, 0.5, 0.65 },
    levels: i64    = GLOW_LEVELS,
    cap:    f32    = 60000.0,
}
var hdr_glow = HdrGlow {};
var glow_exposure: f32 = 1.0;
fn glow_shown(g: Gpu&) -> bool { g.hdr && hdr_glow.look.x > 0.0 && hdr_glow.levels > 0 }
// The glow's smallest level, which holds the sun's light blurred wide (HDR_TONE_FRAG's
// share of it open).
fn glow_smallest() -> i64 { clamp(hdr_glow.levels, 1, GLOW_LEVELS) - 1 }
// GLOW_DOWN_FRAG's and GLOW_UP_FRAG's block; HDR_TONE_FRAG's.
struct GlowStep { step: float4, look: float4 }
struct HdrTone { glow: float4, sun: float4, veil: float4, disc: float4, white: float4, look: float4 }
fn glow_level_size(size: int2, k: i64) -> int2 {
    var q = int2 { max(size.x / 4, 1), max(size.y / 4, 1) };
    for i in k { q = int2 { max(q.x / 2, 1), max(q.y / 2, 1) }; }
    return q;
}
// Level k's step: read from `from` (a texel's half, or a pixel of the full picture for the
// first, whose tent's taps are placed in pixels) into `to`.
fn glow_step_of(from: int2, to: int2, first: bool) -> GlowStep {
    let h = if first { float2 { 1.0 / from.x, 1.0 / from.y } } else { float2 { 0.5 / from.x, 0.5 / from.y } };
    let l = hdr_glow.look;
    let k = glow_exposure;
    GlowStep { float4 { h.x, h.y, 1.0 / to.x, 1.0 / to.y }, float4 { l.y / k, l.z / k, hdr_glow.cap / k, clamp(l.w, 0.0, 1.0) } }
}
// The tonemap's block: glow x the glow's strength (0 none), yz a pixel in uv, w the light
// tuner's probe (tone_probe); sun the sun's place on the picture (pixels), the pixels a
// degree spans there, and w what turns the glow's smallest level there into the share of
// the sun open (0: taken as all open); veil SunLook's, its x 0 where the sun is behind the
// eye; disc the disc's radius (pixels) and what turns the picture's light on it into its
// share open (half the bare disc's light counts as open), z the camera's curve (camera_toe),
// w its exposure (camera_exposure).
var tone_probe: f32 = 0.0;
// The scenic views' camera curve after the pass (shaders::HDR_TONE_FRAG's camera_curve): 0
// to 2 the toe, as tone_toe's ways (0 on the luminance, 1 on the least channel, 2 none), then
// the shoulder; 3 AgX at the camera's exposure. Today 2, each surface taking its own toe as
// it writes the HDR target (tone_toe); the light tuner's --light physical takes one curve for
// the whole picture here, the surfaces' toes 2.
var camera_toe: f32 = 2.0;
let CAMERA_AGX = 3;
// The camera's meter for AgX: the log-average luminance of the light leaving the room's
// surfaces, each of the bake's cells by its area (the lace's left out), as Frame's exposure
// leaves it; worked out once at the bake (meter_of). The camera exposes it to METER_GREY,
// times 2 to camera_ev (stops, the light tuner's --camera-ev).
var meter_light: f32 = 0.0;
var camera_ev:   f32 = 0.0;
let METER_GREY: f32 = 0.18;
// The camera's grade under AgX, a season's (GRADES): ev stops over the meter (with
// camera_ev), white the white balance's gains on the light (green 1), and a look on AgX's
// curve as Blender's AgX looks: (v * slope + offset) ^ power, then the saturation round its
// luminance. Autumn's is a light touch over the light, whose colour comes from the season's air
// (task 122, 2026-11-27: a third of the sixth step's 1.3, 1, 0.6 and power 0.8, which was fitted
// to the autumn reference's regions under a clear sky's blue light).
struct Grade {
    ev:         f32    = 0.0,
    white:      float3 = float3 { 1.0, 1.0, 1.0 },
    slope:      f32    = 1.0,
    offset:     f32    = 0.0,
    power:      f32    = 1.0,
    saturation: f32    = 1.0,
}
// By looks' season: autumn, winter (neutral, not tuned yet), spring, summer.
let GRADES: Grade[4] = [Grade { -3.6, float3 { 1.1, 1.0, 0.85 }, 1.0, 0.0, 0.9, 1.0 }, Grade {}, Grade {}, Grade {}];
var grade = Grade {};
fn meter_of(b: room_light::Bounce&, gain: f32) -> f32 {
    var sum:  f32 = 0.0;
    var area: f32 = 0.0;
    for c in room_light::LACE_C0 {
        let a = b.cells[c].area;
        // Not the inner casements' fronts (niche_light), whose sunlit tops and sides they carry.
        guard a > 0.0 && (c < room_light::CASE_C0 || c >= room_light::TABLE_C) else { continue; }
        let l = b.seen[c] + b.sun[c] * (gain / (PI * a));
        sum += a * log2(max(0.2126 * l.x + 0.7152 * l.y + 0.0722 * l.z, 1e-8));
        area += a;
    }
    let two: f32 = 2.0;
    return if area > 0.0 { pow(two, sum / area) } else { 0.0 };
}
// The camera's board meter (the light tuner's --board-meter, on under --light physical):
// where the board fills the frame, the camera exposes for it as a photographer meters the
// subject, and the room round it falls darker; in the room's wide views, the room's meter.
// board_light is the light leaving the board's middle as meter_of takes the table's top
// (its bounce and sky, and the sun through the windows on the board, room_light::board_sun),
// at the bake. The camera exposes it to METER_GREY times 2 to BOARD_KEY, but only ever
// darker than the room's exposure: a board in shade leaves the room's. Its weight is the
// board's share of the frame from BOARD_SHARE.x (none) to .y (all), smoothly, so a walk or
// the camera's ease changes it without a step (task 122, 2026-11-27).
var board_meter = false;
var board_light: f32 = 0.0;
let BOARD_KEY: f32 = 1.5;
let BOARD_SHARE = float2 { 0.03, 0.25 };
fn board_light_of(sun: room_light::Sun, b: room_light::Bounce&) -> f32 {
    let r = mesh::FIELD * 1.128 / surfaces::METRE;     // the field's area as a disc
    let l = b.seen[room_light::TABLE_C] + room_light::board_sun(sun, light_tree[..], r) * (sun.bounce_gain / PI);
    return 0.2126 * l.x + 0.7152 * l.y + 0.0722 * l.z;
}
// The board's share of the frame: its outer square (the frame's edge, on the table's top)
// projected by the view, cut to the near plane and to the picture, its area over the
// picture's. Fixed arrays, no allocation; a few dozen flops a frame.
fn board_share(m: Mat) -> f32 {
    let h = mesh::INNER + mesh::FRAME_W;
    let corners: float3[4] = [float3 { -h, 0.0, -h }, float3 { h, 0.0, -h }, float3 { h, 0.0, h }, float3 { -h, 0.0, h }];
    var clip: float4[4] = [float4_0; 4];
    for c, i in corners { clip[i] = m.c0 * c.x + m.c1 * c.y + m.c2 * c.z + m.c3; }
    // Against the near side (w over a small floor), then into the picture's plane.
    let near: f32 = 1e-3;
    var a: float2[16] = [float2_0; 16];
    var n = 0;
    for i in 4 {
        let p = clip[i];
        let q = clip[(i + 1) % 4];
        if p.w > near { a[n] = float2 { p.x / p.w, p.y / p.w }; n++; }
        if (p.w > near) != (q.w > near) {
            let t = (near - p.w) / (q.w - p.w);
            let e = p + (q - p) * t;
            a[n] = float2 { e.x / e.w, e.y / e.w };
            n++;
        }
    }
    // Against the picture's four edges, -1 to 1 each way.
    var b: float2[16] = [float2_0; 16];
    for side in 4 {
        var k = 0;
        let axis = side / 2;
        let s: f32 = if side % 2 == 0 { -1.0 } else { 1.0 };
        for i in n {
            let p = a[i];
            let q = a[(i + 1) % n];
            let pv = if axis == 0 { p.x } else { p.y };
            let qv = if axis == 0 { q.x } else { q.y };
            let p_in = pv * s <= 1.0;
            let q_in = qv * s <= 1.0;
            if p_in { b[k] = p; k++; }
            if p_in != q_in && k < 16 {
                let t = (s - pv) / (qv - pv);
                b[k] = p + (q - p) * t;
                k++;
            }
        }
        n = k;
        for i in n { a[i] = b[i]; }
    }
    var area: f32 = 0.0;
    for i in n {
        let p = a[i];
        let q = a[(i + 1) % n];
        area += p.x * q.y - q.x * p.y;
    }
    return min(abs(area) * 0.125, 1.0);
}
// The board meter's weight in this frame, 0 to 1.
fn board_weight(g: Gpu&) -> f32 {
    let t = clamp((board_share(g.frame.view_proj) - BOARD_SHARE.x) / (BOARD_SHARE.y - BOARD_SHARE.x), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}
// The stops the board meter takes off the room's exposure at full weight (0 or less).
fn board_cut() -> f32 { min(log2(meter_light / board_light) + BOARD_KEY, 0.0) }
// What the tone pass multiplies the HDR target's light by before AgX: 1 unless metered. The
// eye's veil is added divided by it, so it adds to the picture what it adds without it.
fn camera_exposure(g: Gpu&) -> f32 {
    guard camera_toe > 2.5 && meter_light > 0.0 else { return 1.0; }
    let two: f32 = 2.0;
    let room = METER_GREY * pow(two, camera_ev + grade.ev) / (meter_light * max(g.frame.params.x * g.room.room_exposure, 1e-6));
    guard board_meter && board_light > 0.0 else { return room; }
    return room * pow(two, board_weight(g) * board_cut());
}
fn hdr_tone_of(g: Gpu&) -> HdrTone {
    let glow = glow_shown(g);
    let k = camera_exposure(g);
    var t = HdrTone { float4 { if glow { hdr_glow.look.x } else { 0.0 }, 1.0 / g.size.x, 1.0 / g.size.y, tone_probe },
                      float4_0, sun_look.veil, float4 { 0.0, 0.0, camera_toe, k },
                      float4 { grade.white.x, grade.white.y, grade.white.z, grade.saturation },
                      float4 { grade.slope, grade.offset, grade.power, 0.0 } };
    t.veil.x = sun_look.veil.x / k;
    guard sun_look.veil.x > 0.0 else { return t; }
    let m = g.frame.view_proj;
    let s = normalize(float3 { g.frame.light_dir.x, g.frame.light_dir.y, g.frame.light_dir.z });
    let at, ok = sun_on_picture(m, s, g.size);
    // A degree away from the sun, across it, for the pixels a degree spans there.
    let side = normalize(cross(s, if abs(s.y) < 0.9 { float3 { 0.0, 1.0, 0.0 } } else { float3 { 1.0, 0.0, 0.0 } }));
    let off, ok2 = sun_on_picture(m, normalize(s + side * 0.017455065), g.size);
    guard ok && ok2 else {
        t.veil.x = 0.0;
        return t;
    }
    let ppd = length(off - at);
    // The bare sun's light in the glow's smallest level: its disc's light over a texel's
    // pixels (SUN_OPEN_FILTER the levels' spread at the texel's middle, measured).
    var open_ref: f32 = 0.0;
    if glow {
        let q = glow_level_size(g.size, glow_smallest());
        let r = sun_look.disc.x * ppd;
        let texel = (g.size.x as f32 / q.x) * (g.size.y as f32 / q.y);
        let bare = sun_look.disc.w * g.room.outside * PI * r * r / texel * SUN_OPEN_FILTER;
        open_ref = 1.0 / max(bare, 1e-6);
    }
    t.sun = float4 { at.x, at.y, ppd, open_ref };
    t.disc = float4 { sun_look.disc.x * ppd, 2.0 / max(sun_look.disc.w * g.room.outside, 1e-6), camera_toe, k };
    return t;
}
let SUN_OPEN_FILTER: f32 = 1.0;
// Where direction s lands on a picture of `size` through m (pixels, y down), and whether it
// is ahead of the eye.
fn sun_on_picture(m: Mat, s: float3, size: int2) -> float2, bool {
    let x = m.c0.x * s.x + m.c1.x * s.y + m.c2.x * s.z;
    let y = m.c0.y * s.x + m.c1.y * s.y + m.c2.y * s.z;
    let w = m.c0.w * s.x + m.c1.w * s.y + m.c2.w * s.z;
    guard w > 1e-4 else { return float2_0, false; }
    return float2 { (0.5 * x / w + 0.5) * size.x, (0.5 - 0.5 * y / w) * size.y }, true;
}

// GLOW_PICK_FRAG's, GLOW_BLUR_FRAG's, and GLOW_ADD_FRAG's blocks.
struct GlowPick { pick: float4 }
struct GlowBlur { dir: float4, px: float4 }
struct GlowAdd { add: float4 }

// The quarter size the glow is worked out at.
fn bloom_size_of(size: int2) -> int2 { int2 { max(size.x / 4, 1), max(size.y / 4, 1) } }
fn bloom_pick_of(g: Gpu&, size: int2) -> GlowPick {
    let b = g.room.bloom;
    GlowPick { float4 { b.y, b.z, 1.0 / size.x, 1.0 / size.y } }
}
fn bloom_blur_of(g: Gpu&, q: int2, across: bool) -> GlowBlur {
    let step = if across { float2 { 1.0 / q.x, 0.0 } } else { float2 { 0.0, 1.0 / q.y } };
    GlowBlur { float4 { step.x, step.y, max(g.room.bloom.w, 0.5), 0.0 }, float4 { 1.0 / q.x, 1.0 / q.y, 0.0, 0.0 } }
}
fn bloom_add_of(g: Gpu&, size: int2) -> GlowAdd {
    let q = bloom_size_of(size);
    GlowAdd { float4 { g.room.bloom.x, 1.0 / (4.0 * q.x), 1.0 / (4.0 * q.y), 0.0 } }
}

// The pieces' occlusion of the field drawn into g.occ_map where the squares changed since
// it was drawn (all of it the first time and for a new board size): a square's piece,
// anywhere over it, darkens the field within OCC_REACH squares of its own
// (shaders::OCC_FRAG's 5 × 5), so the changed squares and that many round them,
// scissored. Recording only, before the board's pass.
let OCC_REACH = 2;
fn same4(a: float4, b: float4) -> bool { a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w }
fn same2(a: float2, b: float2) -> bool { a.x == b.x && a.y == b.y }
fn occlusion<O>(o: O&, g: Gpu&) {
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
            guard !same4(g.occ_squares[2 * i], g.squares_now[2 * i])
                  || !same4(g.occ_squares[2 * i + 1], g.squares_now[2 * i + 1]) else { continue; }
            let row = i / n;
            let col = i % n;
            c0 = min(c0, col - OCC_REACH);
            c1 = max(c1, col + OCC_REACH);
            r0 = min(r0, row - OCC_REACH);
            r1 = max(r1, row + OCC_REACH);
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
    o.occ_pass(g, x0, y0, x1, y1);
    g.occ_squares = g.squares_now;
    g.occ_n = n;
}

// The backdrop drawn at full opacity into g.kept_backdrop when what it is drawn from
// changed (a size, a photograph, a look, the plain fade), so the screen's frames lay it
// with a fetch a pixel (shaders::KEPT_FRAG) rather than grade the photograph each frame.
// Before draw()'s passes, which
// come with every change but the photograph's alone; till the next, backdrop() draws
// it as it was. Recording only.
fn keep_backdrop<O>(o: O&, g: Gpu&, size: int2) {
    guard !g.live && !kept_current(g, size) else { return; }
    if g.kept_backdrop.id == 0 { g.kept_backdrop = o.gpu_target(size.x, size.y); }
    o.kept_pass(g);
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

// The pipelines the 3D pass and the screen's part draw with, each made one step at a
// time (0 to WARM_STEPS - 1) before the board is first drawn, so that frame doesn't make
// them all at once: goose_gfx makes a pipeline when it is first bound in a pass, for that
// pass's target formats (docs/goose-findings.md). Bound in a pass on 4 × 4 targets of the
// pass's formats (made by the first step, given back by the last), or on the target
// itself where it is small or held anyway, with nothing drawn.
let WARM_STEPS = 12;

// Dust in the sunbeam (shaders::DUST_VERT): up to MAX_MOTES points in the beam's own volume
// over the table, drawn after the scene in the board's pass (draw_motes) while `count` is
// over 0, lit by the sun through the shell's windows where each is. Where each is follows
// from its seed and the seconds (wind_time), so a frame uploads nothing. The main menu's
// scene only, never the game's; the light tuner's for now.
let MAX_MOTES = 1024;
struct Dust {
    count:  i64 = 0,        // points drawn, 0 none
    blur:   f32 = 0.0,      // the lens: a disc's radius at twice the focus's distance, pixels at 1000 high (render3d::Lens)
    bright: f32 = 0.6,
    focus:  f32 = 19.0,     // the focus's distance from the eye (the tuner's: its target's)
    ahead:  f32 = 0.6,      // the forward scattering's g, 0 even
    // The beam's volume: its low corner and the axes in the world, along the window wall,
    // up, and into the room along the beam; span their lengths.
    low:    float3 = float3 { -9.0, -0.7, -9.0 },
    span:   float3 = float3 { 18.0, 11.0, 21.0 },
    shell:  bool   = false, // lit through the shell's windows (shell_open)
    u:      float3 = float3_0,
    v:      float3 = float3_0,
    w:      float3 = float3_0,
    fibres: f32    = 0.3,   // the share of fibres
    // The fibres' width across, a share of a point's footprint (their light kept: a thinner
    // line is brighter); the tuner's --fibre-width.
    fibre_width: f32 = 0.5,
    // Their footprint's sigma in pixels, how much of the flakes' glints shows (0 none, 1 as
    // real), the air (cm a second: its drift along the wall, the rise over the sun's patch,
    // the swirls' speed; the swirls' size in cm), the board's share along w, how much denser
    // round it.
    point_px: f32    = 0.75,
    glints:   f32    = 1.0,
    air:      float4 = float4 { 1.2, 1.0, 1.5, 12.0 },
    board_at: f32    = 0.63,
    near:     f32    = 1.0,
}
var dust = Dust {};

// shaders::DUST_HEAD's block: the motes' own, then the shell's windows as the room's block
// has them (surfaces_block), all 0 unless the motes are lit through them (Dust.shell).
struct DustBlock {
    box:         float4,
    span:        float4,
    look:        float4,
    lens:        float4,
    axes:        float4,
    tile:        float4,
    shell:       float4,
    shell_mids:  float4,
    shell_niche: float4,
    shell_glass: float4,
    shell_sun:   float4,
    window_view: float4,
    shell_case:  float4,
    u:           float4,
    v:           float4,
    w:           float4,
    shape:       float4,
    air:         float4,
    point:       float4,
    near:        float4,
}
fn dust_block(g: Gpu&) -> DustBlock {
    var b = DustBlock { model3d::f4(dust.low, wind_time), model3d::f4(dust.span, 0.0),
                        float4 { 0.0, dust.blur, dust.bright, dust.focus }, float4 { 0.0, dust.ahead, 0.0, 0.0 },
                        float4_0, float4_0, float4_0, float4_0, float4_0, float4_0, float4_0, float4_0, float4_0,
                        model3d::f4(dust.u, 0.0), model3d::f4(dust.v, 0.0), model3d::f4(dust.w, 0.0),
                        float4 { 0.0, 0.0, dust.fibres, dust.fibre_width }, dust.air,
                        float4 { dust.point_px, dust.glints, g.room.shell_sun.y * g.room.room_exposure, surfaces::METRE },
                        float4 { dust.board_at, dust.near, 0.0, 0.0 } };
    if lens.on {
        // The lens's disc in the motes' pixels (a thousand to the scene's height): the
        // aperture's share of its width.
        let k = 1000.0 * g.frame.screen.x / max(g.frame.screen.y, 1.0);
        b.look.y = lens.aperture * k;
        b.look.w = lens.focus * surfaces::METRE;
        b.lens.w = lens.near_cap * k;
    }
    guard dust.shell && g.room_on else { return b; }
    let s = surfaces_block(g);
    b.axes = s.axes;
    b.tile = s.tile;
    b.shell = s.shell;
    b.shell_mids = s.shell_mids;
    b.shell_niche = s.shell_niche;
    b.shell_glass = s.shell_glass;
    b.shell_sun = s.shell_sun;
    b.window_view = s.window_view;
    b.shell_case = s.shell_case;
    // Only the sun straight through the glass lights a mote, not the light the lace
    // scatters on.
    b.window_view.y = 0.0;
    return b;
}

// The haze in the sunbeam (haze_pass, shaders::HAZE_CROSS_FRAG and HAZE_FRAG;
// build/notes/builder-33/): the sun scattered toward the eye by the room's air where the beam
// through the shell's windows crosses each pixel's view, added into the HDR target before the
// glow and the tonemap. The sun is one direction and the glass flat, so the beam is its
// cross-section in the outer glass's plane carried along the sun: the panes (each sash of the
// outer glass cut by each of the inner glass's and by the niche's opening, a product set of
// columns times rows there, haze_panes), the lace and the tree, drawn each frame into a small
// atlas; each view, carried onto that plane, is a segment there, and the beam's lit length
// on it the atlas averaged over `taps` along it. Times sigma (the air's scattering a metre),
// the phase (Henyey-Greenstein at g, `even` of it isotropic) and the sun as the room's
// surfaces take it. Off with sigma 0; the light tuner's for now. half: worked out at the
// pre-pass's half size (its pre_place) and added bilinear, or straight into the target.
// soft: the stripes blurred with the distance from the glass as the sun's disc widens the
// bars' shadows, times this (0 sharp, 1 as the disc does, more a softer beam), and toward
// times more again looking toward the sun, where the stripes converge on it.
struct Haze {
    sigma:  f32  = 0.0,
    g:      f32  = 0.7,
    even:   f32  = 0.2,
    taps:   i64  = 12,
    half:   bool = true,
    soft:   f32  = 1.0,
    toward: f32  = 0.0,
}
var haze = Haze {};
fn haze_shown(g: Gpu&) -> bool { g.hdr && haze.sigma > 0.0 && g.room_on && ssao_shown(g) && g.pre_place.id != 0 }

// The panes as the outer glass's plane sees them along the sun (world units: along the
// window wall's u, and up): haze_panes[0..3] each window's bounding box, then window k's
// product sets (haze_set, one a pair of sashes) up to HazeBlock.ranges[k], for the
// cross-section's pass. Worked out each frame and sent when they change.
let MAX_HAZE_PANES = 512;
// The beam's cross-section's atlas (shaders::HAZE_CROSS_FRAG): a slot of 192 × 384 a window.
let HAZE_CROSS_SIZE = int2 { 576, 384 };
var haze_panes: float4[MAX_HAZE_PANES] = [float4_0; MAX_HAZE_PANES];
var haze_sent:  float4[MAX_HAZE_PANES] = [float4_0; MAX_HAZE_PANES];
var haze_count = 0;

// shaders::HAZE_BLOCK, both haze passes': the shell's windows as the room's block has them
// (for LIGHT_FN's lace_shadow and tree_light), then the sun's light as the room's surfaces
// take it (rgb, exposed) and sigma; g, the isotropic share, the taps, soft; the outer glass's
// depth along the wall's normal, the sun's slope along u and up a unit of that depth, and how
// many windows; the panes' ends; a pixel of the target in uv, and toward; each window's
// panes' box.
struct HazeBlock {
    axes:        float4,
    tile:        float4,
    shell:       float4,
    shell_mids:  float4,
    shell_niche: float4,
    shell_glass: float4,
    shell_sun:   float4,
    window_view: float4,
    shell_case:  float4,
    light:       float4,
    look:        float4,
    plane:       float4,
    ranges:      float4,
    pixel:       float4,
    box0:        float4,
    box1:        float4,
    box2:        float4,
}
// HAZE_ADD_FRAG's: a pixel of the picture in uv.
struct HazeAdd { pixel: float4 }

// The casement's glazing at a glass plane (shaders::LIGHT_FN's casement, in its metres: along
// from the window's middle, up from the floor), one sash's: its panes' columns over both leaves,
// left to right, into xs, and its rows, upward, into ys; how many of each. The lower sash is
// one pane across a leaf and two up, the upper three by three, between the bars.
fn casement_sash(niche: float4, upper: bool, xs: float2[12]&, ys: float2[12]&) -> int2 {
    if room_shell::box_window_on { return room_shell::box_panes(room_shell::window_at(0.0), upper, xs, ys); }
    let bar: f32 = 0.024;
    let s = niche.y;
    let h = niche.y + niche.z;
    let zt = s + (h - s) * 2.0 / 3.0;
    let ax0: f32 = 0.0175 + 0.05;
    let ax1: f32 = 0.49 - 0.055;
    let y0 = if upper { zt + 0.045 } else { s + 0.03 };
    let y1 = if upper { h - 0.06 } else { zt - 0.045 };
    let ay0 = y0 + (if upper { 0.055 } else { 0.08 });
    let ay1 = y1 - 0.055;
    let across = if upper { 3 } else { 1 };
    let up = if upper { 3 } else { 2 };
    let px = (ax1 - ax0 + bar) / across;
    let py = (ay1 - ay0 + bar) / up;
    for i in across {
        let x0 = ax0 + i * px;
        let x1 = ax0 + (i + 1) * px - bar;
        xs[across - 1 - i] = float2 { -x1, -x0 };
        xs[across + i] = float2 { x0, x1 };
    }
    for j in up { ys[j] = float2 { ay0 + j * py, ay0 + (j + 1) * py - bar }; }
    return int2 { (across * 2) as i32, up as i32 };
}

// Into out, the intervals two sorted lists of disjoint intervals share, the second's moved by
// `by`, all cut to lo..hi, in order; how many.
fn shared(a: float2[12]&, na: i64, b: float2[12]&, nb: i64, by: f32, lo: f32, hi: f32, out: float2[12]&) -> i64 {
    var i = 0;
    var j = 0;
    var n = 0;
    while i < na && j < nb {
        let x0 = max(max(a[i].x, b[j].x + by), lo);
        let x1 = min(min(a[i].y, b[j].y + by), hi);
        if x1 > x0 && n < 12 {
            out[n] = float2 { x0, x1 };
            n++;
        }
        if a[i].y < b[j].y + by { i++; } else { j++; }
    }
    return n;
}

// One sash of the outer glass (xo, yo, world units) seen through one of the inner glass's (the
// same lists moved by inner) and the niche's opening: a product set in the outer glass's
// plane, its columns times its rows, written at haze_panes[count] as its box, its counts, its
// columns, its rows, one a float4 (x0, x1); the next free place.
fn haze_set(xo: float2[12]&, nxo: i64, yo: float2[12]&, nyo: i64, xi: float2[12]&, nxi: i64, yi: float2[12]&, nyi: i64,
            inner: float2, niche: float4, count: i64, bound: float4&) -> i64 {
    var xs: float2[12] = [float2_0; 12];
    var ys: float2[12] = [float2_0; 12];
    let nx = shared(xo, nxo, xi, nxi, -inner.x, niche.x, niche.z, xs);
    let ny = shared(yo, nyo, yi, nyi, -inner.y, niche.y, niche.w, ys);
    guard nx > 0 && ny > 0 && count + 2 + nx + ny <= MAX_HAZE_PANES else { return count; }
    let box = float4 { xs[0].x, ys[0].x, xs[nx - 1].y, ys[ny - 1].y };
    haze_panes[count] = box;
    haze_panes[count + 1] = float4 { nx, ny, 0.0, 0.0 };
    for k in nx { haze_panes[count + 2 + k] = float4 { xs[k].x, xs[k].y, 0.0, 0.0 }; }
    for k in ny { haze_panes[count + 2 + nx + k] = float4 { ys[k].x, ys[k].y, 0.0, 0.0 }; }
    bound = float4 { min(bound.x, box.x), min(bound.y, box.y), max(bound.z, box.z), max(bound.w, box.w) };
    return count + 2 + nx + ny;
}

// The haze's block, its panes worked out into haze_panes (haze_count of them).
fn haze_block(g: Gpu&, size: int2) -> HazeBlock {
    let s = surfaces_block(g);
    let f = g.frame;
    let l = float3 { f.light_dir.x, f.light_dir.y, f.light_dir.z };
    let along = float2 { s.axes.x, s.axes.y };
    let nw = float2 { -s.axes.z, -s.axes.w };
    let toward = l.x * nw.x + l.z * nw.y;
    var b = HazeBlock { s.axes, s.tile, s.shell, s.shell_mids, s.shell_niche, s.shell_glass, s.shell_sun, s.window_view, s.shell_case,
                        float4_0, float4_0, float4_0, float4_0, float4 { 1.0 / size.x, 1.0 / size.y, haze.toward, 0.0 },
                        float4_0, float4_0, float4_0 };
    haze_count = 0;
    guard toward > 0.05 else { return b; }
    let ka = (l.x * along.x + l.z * along.y) / toward;
    let ky = l.y / toward;
    let metre = s.shell.w;
    let d0 = s.shell.y + s.shell_glass.x;
    // Each plane's rectangles move by the sun's slope times its depth from the outer glass's.
    let inner = float2 { ka, ky } * (s.shell_glass.y - s.shell_glass.x);
    let face = float2 { ka, ky } * (-s.shell_glass.x);
    // Each sash's columns and rows, in the casement's metres.
    var lx: float2[12] = [float2_0; 12];
    var ly: float2[12] = [float2_0; 12];
    var ux: float2[12] = [float2_0; 12];
    var uy: float2[12] = [float2_0; 12];
    let ln = casement_sash(s.shell_niche, false, lx, ly);
    let un = casement_sash(s.shell_niche, true, ux, uy);
    let windows = min(s.shell.x as i64, 3);
    var count = 3;
    var ranges = float4_0;
    for w in windows {
        let mid = if w == 0 { s.shell_mids.x } else if w == 1 { s.shell_mids.y } else { s.shell_mids.z };
        let z = s.shell.z;
        let ni = s.shell_niche;
        let niche = float4 { mid - metre * ni.x - face.x, z + metre * ni.y - face.y, mid + metre * ni.x - face.x,
                             z + metre * (ni.y + ni.z) - face.y };
        // This window's, in world units.
        var wlx = lx;
        var wly = ly;
        var wux = ux;
        var wuy = uy;
        for k in 12 {
            wlx[k] = float2 { mid + metre * lx[k].x, mid + metre * lx[k].y };
            wux[k] = float2 { mid + metre * ux[k].x, mid + metre * ux[k].y };
            wly[k] = float2 { z + metre * ly[k].x, z + metre * ly[k].y };
            wuy[k] = float2 { z + metre * uy[k].x, z + metre * uy[k].y };
        }
        var bound = float4 { 1e9, 1e9, -1e9, -1e9 };
        count = haze_set(wlx, ln.x, wly, ln.y, wlx, ln.x, wly, ln.y, inner, niche, count, bound);
        count = haze_set(wlx, ln.x, wly, ln.y, wux, un.x, wuy, un.y, inner, niche, count, bound);
        count = haze_set(wux, un.x, wuy, un.y, wlx, ln.x, wly, ln.y, inner, niche, count, bound);
        count = haze_set(wux, un.x, wuy, un.y, wux, un.x, wuy, un.y, inner, niche, count, bound);
        if bound.z <= bound.x { bound = float4_0; }
        haze_panes[w] = bound;
        if w == 0 { ranges.x = count; } else if w == 1 { ranges.y = count; } else { ranges.z = count; }
    }
    haze_count = count;
    let sun = room_sun_of(float3 { f.light_color.x, f.light_color.y, f.light_color.z })
              * (f.light_dir.w * g.room.shell_sun.y * f.params.x * g.room.room_exposure);
    b.light = float4 { sun.x, sun.y, sun.z, haze.sigma };
    b.look = float4 { haze.g, haze.even, haze.taps, haze.soft };
    b.plane = float4 { d0, ka, ky, windows };
    b.ranges = ranges;
    b.box0 = haze_panes[0];
    b.box1 = haze_panes[1];
    b.box2 = haze_panes[2];
    return b;
}
// Whether haze_panes changed since they were last sent (and keeps them as sent).
fn haze_changed() -> bool {
    var changed = false;
    for i in haze_count {
        let a = haze_panes[i];
        let b = haze_sent[i];
        if a.x != b.x || a.y != b.y || a.z != b.z || a.w != b.w {
            changed = true;
            haze_sent[i] = a;
        }
    }
    return changed;
}

// shaders::LIT_SHELL's and TABLE_SHELL's block: the shell's windows as the room's block has
// them (surfaces_block), for the board and the table lit through them; all 0 without the
// shell, where LIGHT_FN's window_open takes the game's window.
struct ShellBlock {
    axes:        float4,
    tile:        float4,
    shell:       float4,
    shell_mids:  float4,
    shell_niche: float4,
    shell_glass: float4,
    shell_sun:   float4,
    window_view: float4,
    shell_case:  float4,
}
// The shell's windows' casements: x 1 with task 127's box window (room_shell::box_window_on),
// 0 window B's; y the lace's density as one flat sheet where it is lit as described (lace_lit,
// lace_slant), else 0; z, w kept for a sash's opening.
fn shell_case_of(g: Gpu&) -> float4 {
    return float4 { if room_shell::box_window_on { 1.0 } else { 0.0 }, if lace_lit(g) { lace_slant.y } else { 0.0 }, 0.0, 0.0 };
}
fn shell_block(g: Gpu&) -> ShellBlock {
    var b = default<ShellBlock>();
    guard g.room_on else { return b; }
    let s = surfaces_block(g);
    b.axes = s.axes;
    b.tile = s.tile;
    b.shell = s.shell;
    b.shell_mids = s.shell_mids;
    b.shell_niche = s.shell_niche;
    b.shell_glass = s.shell_glass;
    b.shell_sun = s.shell_sun;
    b.window_view = s.window_view;
    b.shell_case = s.shell_case;
    return b;
}
// Whether the board's pass lights the board and the table through the shell's windows: its
// lit pipelines then the shell's (lit_shell, the HDR target's, the room's table).
fn board_in_shell(g: Gpu&) -> bool { room_shown(g) }

// The lens of the scenic views' depth of field (build/notes/bokeh/, task 111), one for every
// pass that blurs: a disc's radius at a distance d is aperture × |1 - focus / d| of the
// scene's width, at most near_cap nearer than the focus and far_cap farther. Off, nothing
// reads it; on, the motes take their discs from it (dust_block). The light tuner's for now.
struct Lens {
    on:       bool = false,
    focus:    f32  = 1.55,    // the focus's distance from the eye, metres
    aperture: f32  = 0.024,   // a disc's radius at infinity, a share of the width
    near_cap: f32  = 0.045,
    far_cap:  f32  = 0.045,
}
var lens = Lens {};

fn motes_shown(g: Gpu&) -> bool { dust.count > 0 && g.motes.id != 0 }
fn motes_drawn() -> i64 { min(dust.count, MAX_MOTES) }

// Each mote's seed: xyz its place in the box, w its own pace, size, and brightness, all
// 0..1, the same every run (xorshift).
fn mote_seeds() -> float4[MAX_MOTES] {
    var out: float4[MAX_MOTES] = [float4_0; MAX_MOTES];
    var x:   u32               = 2463534242;
    for i in MAX_MOTES {
        var v: f32[4] = [0.0, 0.0, 0.0, 0.0];
        for k in 4 {
            x ^= x << 13;
            x ^= x >> 17;
            x ^= x << 5;
            v[k] = (x >> 8) / 16777216.0;
        }
        out[i] = float4 { v[0], v[1], v[2], v[3] };
    }
    return out;
}
