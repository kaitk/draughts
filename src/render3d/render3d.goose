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
    disc_n:          float4,
    discs:           float4[MAX_DISCS],
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
    wood:            i64,            // the wood's model the surfaces are baked with
    finish:          looks::Finish,  // and its finish
    marble:          i64,            // the stone frame's marble (looks::MARBLE..), 0 slate
    stone:           looks::Marble,  // and its look
    spring:          i64,            // spring's look (looks::SPRING_LOOK..), 1 the carved
    carving:         looks::Carving, // and the carving of a carved look shown,
    carved:          i64,            // the look it is the carving of (looks::shown), -1 none yet
    n:               i64,            // squares per side the plan is baked for
    look:            i64,            // looks::AUTUMN.., and the photograph's kind
    photo_kind:      i64,
    board_vb:        Buffer,
    board_ib:        Buffer,
    board_count:     i64,
    piece_vb:        Buffer,
    piece_ib:        Buffer,
    piece_count:     i64,
    instances:       Buffer,
    instance_count:  i64,
    solid:           i64,                   // the instances drawn opaque, first; the rest fade
    alphas:          f32[MAX_INSTANCES],    // how opaque each fading one is
    squares:         Buffer,
    crown_map:       Texture,          // the crown's distance (shaders::CROWN_FRAG), drawn at setup
    occ_map:         Texture,          // the pieces' occlusion of the field (occlusion())
    occ_n:           i64,                    // the squares a side it was drawn for, 0 none yet
    occ_squares:     float4[SQUARE_ENTRIES], // the squares it was drawn from
    squares_now:     float4[SQUARE_ENTRIES], // and the ones place() last gave
    marks:           Buffer,
    glows:           Buffer,     // the field's glow rings and lit squares
    marked:          bool,            // whether the board's pass has marks to draw
    plan_albedo:     Texture,
    plan_normal:     Texture,
    side:            i64,           // the surfaces' side they are made at (model3d::BAKE_SIDE..), 0 none yet
    want_side:       i64,           // and the one set_bake() asks for, 0 BAKE_SIDE
    frame_albedo:    Texture,
    frame_normal:    Texture,
    frame_rows:      i64,           // the frame map's rows: `side`, or the mitred bands'
    frame_flat:      bool,          // frame_normal is flat_frame()'s 4 × 4, not the map's
    table:           bool,          // the table under the board (set_table), its map baked
    classic:         bool,           // settings' Classic pieces (looks::classic), put on by theme_end
    table_albedo:    Texture,       // with the theme's surfaces, at model3d::table_size
    table_normal:    Texture,
    table_wear:      Texture,       // its wear's tile, at model3d::wear_side (wear_at)
    table_wear_n:    Texture,
    table_side:      i64,           // the side its maps are made at, 0 none
    table_baked:     bool,          // its maps hold table_spec's wood
    table_spec:      tables::Table, // the table shown (tables::BOARD_WOOD.., or as tuned)
    room:            rooms::Room,   // the room's light on the table (rooms::of, or as tuned)
    room_tuned:      bool,          // room set by a tuner, not taken from the season
    tree_map:        Texture,       // the tree's shadow (trees::draw_map), made with the first bake
    tree_for:        float4[10],    // what it was baked from (tree_key())
    tree_stale:      bool,          // to bake again before the next draw
    tree_ms:         f64,           // the last bake's time (measuring)
    table_edge:      float4,        // the edge its mesh is made with (tables::Table.edge)
    table_vb:        Buffer,
    table_ib:        Buffer,
    table_count:     i64,
    table_lit:       Pipeline,
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
    // The room round the table (model3d::surfaces, the tuner's for now): shown or not, the
    // panelled wall's distance, its oak's two fields baked once (the floor's and the
    // wall's, albedo and roughness, the normal), its mesh made for the room's frame.
    room_on:      bool,
    room_away:    f32,
    room_side:    i64,              // the fields' side they are made at, 0 none
    room_baked:   bool,
    room_ms:      f64,              // the bake's time (measuring)
    floor_albedo: Texture,
    floor_normal: Texture,
    wall_albedo:  Texture,
    wall_normal:  Texture,
    room_frame:   surfaces::Frame,
    room_for:     float4[2],        // what the mesh was made for: the key's x and z, the window's wall, the wall's v
    room_vb:      Buffer,
    room_ib:      Buffer,
    room_count:   i64,
    room_lit:     Pipeline,         // made when first wanted (make_room)
    bake_room:    Pipeline,
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

// The table's mesh made again when its edge isn't the one it was made with.
fn table_mesh<O>(o: O&, g: Gpu&) {
    let e = g.table_spec.edge;
    let was = g.table_edge;
    guard g.table_vb.id == 0 || e.x != was.x || e.y != was.y || e.z != was.z || e.w != was.w else { return; }
    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    mesh::table(verts, indices, e);
    if g.table_vb.id != 0 { o.gpu_release_mesh(g.table_vb, g.table_ib); }
    g.table_vb, g.table_ib = o.gpu_mesh(bytes_of(verts), bytes_of(indices));
    g.table_count = indices.len;
    g.table_edge = e;
}

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

// TABLE_FRAG's block: the table's light, its polish, and its rim's wear (tables::Table).
struct TableBlock { pool: float4, coat: float4, polish: float4, worn: float4 }
fn table_block(g: Gpu&) -> TableBlock {
    let t = g.table_spec;
    TableBlock { t.light, t.coat, t.polish, t.wear }
}

// The pieces lying on the table (view3d::Scene.discs, taken3d::lay), each x, z, its foot's
// and its top's height over the table, all of radius r, for the shadows TABLE_FRAG and
// LIT_FRAG work out from them: the shadow map covers only the board.
let MAX_DISCS = 48;     // view3d::MAX_DISCS, FRAME's discs[48]
fn table_discs(g: Gpu&, discs: const float4[:], r: f32) {
    let n = min(discs.len, MAX_DISCS);
    for i in n { g.frame.discs[i] = discs[i]; }
    g.frame.disc_n = float4 { n, r, 0.0, 0.0 };
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

// Shows the room round the table or not (model3d::surfaces), its wall `away` into the
// room: its oak is baked and its mesh made before the next draw (room_surfaces).
fn show_room(g: Gpu&, on: bool, away: f32 = surfaces::WALL_AWAY) {
    g.room_on = on;
    if away != g.room_away { g.room_for[1] = float4_0; }
    g.room_away = away;
}

// Whether the board's pass draws the room.
fn room_shown(g: Gpu&) -> bool { g.room_on && g.room_baked && g.room_vb.id != 0 && g.room_lit.id != 0 }

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
        g.room_side = side;
        g.room_baked = true;
        g.room_ms = (clock() - t0) * 1000.0;
    }
    let l = g.frame.light_dir;
    let w = g.room.window;
    let key: float4[2] = [float4 { l.x, l.z, w.y, w.x }, float4 { w.z, g.room_away, 1.0, 0.0 }];
    guard g.room_vb.id == 0 || !same4(key[0], g.room_for[0]) || !same4(key[1], g.room_for[1]) else { return; }
    g.room_frame = surfaces::frame_of(float3 { l.x, l.y, l.z }, g.room.window.y);
    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    surfaces::build(verts, indices, g.room_frame, g.room_away, w.x, w.z);
    if g.room_vb.id != 0 { o.gpu_release_mesh(g.room_vb, g.room_ib); }
    g.room_vb, g.room_ib = o.gpu_mesh(bytes_of(verts), bytes_of(indices));
    g.room_count = indices.len;
    g.room_for = key;
}

// The fields' memory in bytes: two RGBA8 targets each, with their mips.
fn room_bytes(g: Gpu&) -> i64 {
    guard g.room_side > 0 else { return 0; }
    var level = g.room_side * g.room_side;
    var sum = 0;
    while level > 0 {
        sum += level;
        level = level / 4;
    }
    return 4 * 4 * sum;
}

// ROOM_FRAG's block: surfaces::Look, the room's frame, and where its walls and fields are.
struct SurfacesBlock { plank: float4, planks: float4, worn: float4, paper: float4, axes: float4, place: float4 }
fn surfaces_block(g: Gpu&) -> SurfacesBlock {
    let k = surfaces::LOOK;
    let f = g.room_frame;
    SurfacesBlock { k.plank, k.planks, k.worn, k.paper, float4 { f.along.x, f.along.y, f.into.x, f.into.y },
                    float4 { g.room.window.x, g.room_away, surfaces::FLOOR_FIELD, surfaces::WALL_FIELD } }
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
    let held = [g.color, g.depth, g.edges, g.weights, g.kept_depth, g.kept_backdrop];
    for t in held { if t.id != 0 { o.gpu_release(t); } }
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
           && g.kept_backdrop.id == 0;
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

// The branches' clock (rooms::branch_clock) and the wind's time it was taken at, carried
// on from frame to frame; taken again from 0 when the time goes back.
var branch_time:  f64 = 0.0;
var branch_clock: f64 = 0.0;

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
    f.wind = float4 { r.wind.x, r.wind.y, if still { 0.0 } else { wind_time }, r.wind.w };
    let span = if on && r.tree.x > 0.5 { rooms::tree_view(r).span } else { 0.0 };
    let t = (wind_time * r.wind.y) as f64;
    if t < branch_time {
        branch_time = 0.0;
        branch_clock = 0.0;
    }
    if wind_kind == rooms::WIND_BRANCHES {
        branch_clock = rooms::branch_clock(branch_time, branch_clock, t);
        branch_time = t;
    }
    let wa = rooms::wind_of(r, wind_kind, wind_time, span, branch_clock);
    f.wind_now = wa.now;
    f.tree_shift = wa.shift;
    f.branches = wa.branches;
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
    let v = rooms::tree_view(r);
    let key = tree_key(r);
    var same = g.tree_map.id != 0;
    for i in 10 { if !same4(key[i], g.tree_for[i]) { same = false; } }
    if !same { g.tree_stale = true; }
    f.tree = float4 { v.span, 0.0, v.middle.x, v.middle.y };
    let crown = if r.tree.x > 1.5 { max(r.crown_blur, 0.01) } else { 0.0 };
    f.tree_blur = float4 { v.blur * trees::SIDE / v.span, v.distance, crown, r.crown_fill };
}

// The tree's map to bind, or another texture where none is baked: the shaders sample it
// only when the frame's block says the tree shows.
fn tree_or_stand_in(g: Gpu&) -> Texture { if g.tree_map.id != 0 { g.tree_map } else { g.crown_map } }

// What the tree's map is baked from.
fn tree_key(r: rooms::Room) -> float4[10] {
    return [r.tree, r.crown, r.foliage, r.leaves, r.window, r.panes, r.opening, r.key, float4 { r.tree_blur, 0.0, 0.0, 0.0 }, float4 { r.species, 0.0, 0.0, 0.0 }];
}

// The tree grown and its shadow drawn on the CPU, then put on the GPU with its mips:
// before a draw, after put_room() found it stale. Tens of milliseconds, never in the
// frame loop's steady state.
fn bake_tree<O>(o: O&, g: Gpu&) {
    guard g.tree_stale else { return; }
    g.tree_stale = false;
    let t0 = clock();
    let r = g.room;
    let s = rooms::tree_spec(r);
    let v = rooms::tree_view(r);
    var map: u8[>..] = [];
    {
        var t = trees::Tree { .. };
        trees::grow(t, s, v);
        trees::draw_map(t, s, v, map);
    }
    if g.tree_map.id == 0 { g.tree_map = o.gpu_sampled(trees::SIDE, trees::SIDE, trees::MIPS); }
    var at = 0;
    for level in trees::MIPS {
        let side = trees::SIDE >> level;
        let n = side * side * 4;
        o.gpu_upload(g.tree_map, level, map[at..at + n]);
        at += n;
    }
    g.tree_for = tree_key(r);
    g.tree_ms = (clock() - t0) * 1000.0;
}

// Whether the board may scatter light through its stone: on a desktop only (set at
// startup by the app). It adds 16 shadow taps a board pixel, about 0.35 ms at
// 1280 × 800 on an M1 Pro (task 094), not yet timed on a phone or tablet.
var scatter_allowed = false;

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

// Draws a frame seen through view_proj from `eye` into `out`, a color target of `size`
// (the renderer's screen; or for Texture { 0 } g.image, kept for show()): the shadow map
// first if the pieces moved, then the one pass, antialiased as g.aa says. Without the
// `backdrop` the target is clear but for the board, its shadow, and the pieces
// (premultiplied), for show() to lay over a backdrop drawn apart (backdrop(), or the
// app's photograph). With `keep_depth` the board's depth is kept too, at 1x, for
// marks_over. Recording only; the caller's frame submits it.
fn draw<O>(o: O&, g: Gpu&, view_proj: Mat, eye: float3, out: Texture, size: int2, shadow_every: bool = false,
        backdrop: bool = true, keep_depth: bool = false) {
    if size.x != g.size.x || size.y != g.size.y { targets(o, g, size); }
    o.pass_targets(g);
    let target = if out.id == 0 { g.image } else { out };
    g.frame.view_proj = view_proj;
    g.frame.eye = model3d::f4(eye, 1.0);
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    keep_backdrop(o, g, size);
    bake_tree(o, g);
    if dust.count > 0 { o.make_motes(g); }
    room_surfaces(o, g);
    if g.shadow_dirty || shadow_every {
        o.shadow_pass(g);
        g.shadow_dirty = false;
    }
    occlusion(o, g);
    o.board_pass(g, target, size, backdrop);
    if keep_depth { o.draw_depth(g); }
}

// The pieces' occlusion of the field drawn into g.occ_map where the squares changed since
// it was drawn (all of it the first time and for a new board size): a square's piece,
// anywhere over it, darkens the field within OCC_REACH squares of its own
// (shaders::OCC_FRAG's 5 × 5), so the changed squares and that many round them,
// scissored. Recording only, before the board's pass.
let OCC_REACH = 2;
fn same4(a: float4, b: float4) -> bool { a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w }
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

// Dust in the sunbeam (shaders::DUST_VERT): up to MAX_MOTES motes in a box over the
// table, drawn after the scene in the board's pass (draw_motes) while `count` is over 0,
// lit by the key through the window where each is, its disc growing away from the focus.
// Where each is follows from its seed and the seconds (wind_time), so a frame uploads
// nothing; the tuner's for now, the home screen's later (task 106).
let MAX_MOTES = 1024;
struct Dust {
    count:  i64    = 0,     // motes drawn, 0 none
    size:   f32    = 1.0,   // an in-focus mote's radius, pixels at 1000 high
    blur:   f32    = 14.0,  // the lens: a disc's radius at twice the focus's distance, the same pixels
    bright: f32    = 0.6,
    focus:  f32    = 19.0,  // the focus's distance from the eye (the tuner's: its target's)
    thin:   f32    = 1.0,   // how much a disc's light thins as it grows (2 its light kept)
    ahead:  f32    = 0.6,   // the forward scattering's g, 0 even
    rise:   f32    = 0.05,  // units a second
    reach:  f32    = 0.5,   // how far each wanders, units
    low:    float3 = float3 { -9.0, -0.7, -9.0 },  // the box's low corner
    span:   float3 = float3 { 18.0, 11.0, 21.0 },  // and its size
}
var dust = Dust {};

// shaders::DUST_HEAD's block.
struct DustBlock { box: float4, span: float4, look: float4, lens: float4 }
fn dust_block() -> DustBlock {
    return DustBlock { model3d::f4(dust.low, wind_time), model3d::f4(dust.span, dust.rise),
                       float4 { dust.size, dust.blur, dust.bright, dust.focus },
                       float4 { dust.thin, dust.ahead, dust.reach, 0.0 } };
}

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
