// The 3D board's renderer (task 015), shared by the app (src/app/draw3d.goose) and the
// prototype (poc/3d/board3d.goose): the meshes and the themes (src/model3d/, which holds
// all of the board but drawing) put on the GPU, the surfaces baked there in the steps
// model3d plans, the season's photograph blurred into the backdrop with its ambient
// taken, the shadow map, and one forward pass into a picture, antialiased.
//
// This file is what it draws and when: the state, the theme's steps, what is stale, and
// each frame's order. Recording it is the renderer's, in the same namespace:
// render3d_gpu.goose, gfx's (its shaders in shaders.goose and smaa.goose), or in the
// build scripts/ngfx.py makes goose-ngfx's, src/ngfx/render3d/render3d_gpu.goose.
//
// The one package besides app/ that draws, and only the app and the prototype import
// it; the game's packages stay headless (docs/architecture/README.md).
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
import .render3d_gpu;

import model3d from "../model3d";

// Theme `kind`'s photograph, or 0 when it isn't built in: the ASTC image as stored, or
// the JPEG decoded and scaled down to `decoded` square (src/app/photo.c and
// background.c, which the app and poc/3d both compile). Declared once, here; the app's
// scene calls it too.
extern fn draughts_photo_id(kind: i64, decoded: i64) -> u32;

fn draughts_photo(kind: i64, decoded: i64) -> Texture { Texture { draughts_photo_id(kind, decoded) } }

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
    carve_more:    float4,  // looks::Carving: motif, amber, lichen, the folk band's pattern
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

let MAX_INSTANCES = 96;     // view3d::MAX_INSTANCES: two for each of board::MAX_PIECES

let SQUARES = 100;          // the field's squares, 10 × 10 at most
let SQUARE_ENTRIES = 2 * SQUARES;   // the occlusion's two float4s a square (place's `squares`)

// Everything on the GPU, made by setup() (the targets again on a resize).
struct Gpu {
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
    occ_n:          i64,                    // the squares a side it was drawn for, 0 none yet
    occ_squares:    float4[SQUARE_ENTRIES], // the squares it was drawn from
    squares_now:    float4[SQUARE_ENTRIES], // and the ones place() last gave
    marks:          Buffer,
    glows:          Buffer,      // the field's glow rings and lit squares
    marked:         bool,             // whether the board's pass has marks to draw
    plan_albedo:    Texture,
    plan_normal:    Texture,
    frame_albedo:   Texture,
    frame_normal:   Texture,
    frame_rows:     i64,            // the frame map's rows: model3d::FRAME_MAP, or the mitred bands'
    frame_flat:     bool,           // frame_normal is flat_frame()'s 4 × 4, not the map's
    photo:          Texture,
    shadow_map:     Texture,
    aa:             i32,            // AA_OFF.. (set_aa), the renderer's ways
    color:          Texture,   // the pass's target (antialiasing's input) and its depth
    edges:          Texture,   // SMAA's edges and blending weights, at the pass's size
    weights:        Texture,
    area:           Texture,   // SMAA's tables (third_party/smaa), made by set_aa
    search:         Texture,
    smaa_edges:     Pipeline,
    smaa_weights:   Pipeline,
    smaa_blend:     Pipeline,
    depth:          Texture,
    image:          Texture,   // what draw() resolves into when asked to keep it
    kept_backdrop:  Texture,   // the backdrop at full opacity, g.size (keep_backdrop())
    kept_for:       float4[7],      // what it was drawn from (backdrop_key())
    live:           bool,           // the app's --keep off: the backdrop drawn each frame, never kept
    photo_gen:      i64,            // counts photo_part()'s steps, each of which may change g.photo
    kept_depth:     Texture,   // its depth at 1x, for the pulsing marks (marks_over)
    warm_color:     Texture,   // 4 × 4 targets warm() makes the pipelines on
    warm_depth:     Texture,
    no_photo:       bool,           // no photograph built in for the theme (photo_part), or plain
    plain:          bool,           // the plain fade behind (task 044), set before a theme's steps
    fade:           float4[3],      // its colors (app/theme.goose's fade_top, low, light), linear
    size:           int2,
    linear:         Sampler,
    aniso:          Sampler,
    compare:        Sampler,
    lit:            Pipeline,
    fading:         Pipeline,  // the lit pass for a fading piece, blended
    shadow:         Pipeline,
    few_shadow:     bool,           // lit and fading filter the shadow in 4 taps, not 9 (set_shadow)
    backdrop:       Pipeline,
    catcher:        Pipeline,
    glow:           Pipeline,
    pulse:          Pipeline,  // the pulsing marks over the kept image (marks_over)
    depth_only:     Pipeline,  // the kept depth
    copy:           Pipeline,
    show:           Pipeline,  // the kept image over what is there, anywhere (show())
    occ:            Pipeline,  // the field's occlusion map (occlusion())
    kept:           Pipeline,  // the kept backdrop laid on the screen (backdrop())
    bake:           Pipeline,  // kept for a theme's rebake, with the photograph's
    shrink:         Pipeline,
    blur:           Pipeline,
    small:          Texture,
    across:         Texture,
    frame:          Frame,
    shadow_dirty:   bool,
    turn:           f32,            // the board's turn (view3d::View.turn), the light turned with it
    bake_ms:        f64,            // the last bake's time and the photograph's (measuring)
    photo_ms:       f64,
    own:            Own,            // what only this renderer holds (render3d_gpu.goose)
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
    gpu_flush();
}

// A target with its mips for a baked surface, down to the level whose shorter side is 1
// pixel. The full chain runs to the longer side's 1: a mitred frame map's (2048 × 1152)
// last level would be 1 × 0 in SDL's mip blits, a zero-height blit that loses the device
// on a Mali-G68 (the Galaxy A33; docs/goose-findings.md). Nothing samples that far down.
fn baked(w: i64, h: i64, format: i32) -> Texture {
    var mips = 1;
    while min(w, h) >> mips > 0 { mips++; }
    return gpu_mipped(w, h, format, mips);
}

// The kept image at `size`, made again only when the size changes; the pass's own
// targets when draw() needs them (pass_targets), the kept backdrop and depth when it
// keeps them.
fn targets(g: Gpu&, size: int2) {
    give_back(g);
    if g.image.id != 0 { gpu_release(g.image); }
    g.image = gpu_target(size.x, size.y);
    g.kept_for[0] = float4_0;
    g.size = size;
}

// Gives back what only drawing the board needs once the app is at rest: the pass's
// targets, the depth kept for the pulsing marks, and the kept backdrop, which the
// screen's frames grade live from the photograph till the next draw() keeps it again.
// The kept image shows the board until it changes; the next draw() makes the rest again.
// Not while drawing: it submits what was recorded, as released textures are freed after
// the next submit is done, and none comes at rest.
fn rest(g: Gpu&) {
    give_back(g);
    gpu_flush();
}

// rest()'s releases, also before a resize's new targets.
fn give_back(g: Gpu&) {
    let held = [g.color, g.depth, g.edges, g.weights, g.kept_depth, g.kept_backdrop];
    for t in held { if t.id != 0 { gpu_release(t); } }
    g.color = Texture { 0 };
    g.edges = Texture { 0 };
    g.weights = Texture { 0 };
    g.depth = Texture { 0 };
    g.kept_depth = Texture { 0 };
    g.kept_backdrop = Texture { 0 };
}

// Whether rest() has anything to give back.
fn resting(g: Gpu&) -> bool {
    return g.color.id == 0 && g.depth.id == 0 && g.edges.id == 0 && g.weights.id == 0 && g.kept_depth.id == 0
           && g.kept_backdrop.id == 0;
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
            gpu_release_waited(g.frame_albedo, g.frame_normal);
        }
        g.frame_albedo = baked(model3d::FRAME_MAP, rows, RGBA8_SRGB);
        g.frame_normal = baked(model3d::FRAME_MAP, rows, RGBA8);
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
    gpu_release(g.frame_normal);
    g.frame_normal = gpu_target(4, 4);
    let half: f32 = 128.0 / 255.0;
    gpu_clear(g.frame_normal, float4 { half, half, 1.0, 1.0 });
    g.frame_flat = true;
}

fn full_frame(g: Gpu&) {
    guard g.frame_flat else { return; }
    gpu_release(g.frame_normal);
    g.frame_normal = baked(model3d::FRAME_MAP, g.frame_rows, RGBA8);
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
    gpu_flush();
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
        photo_pipelines(g);
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
    g.frame.light_view_proj = plan_light(l);
    g.frame.light_dir = model3d::f4(l, t.key.w);
}

// The board's half width the shadow map covers: the frame's outer edge (mesh's 4.6) and
// a little more, for its sides' feet, which the light's slant moves out by up to 0.45.
let PLAN_REACH: f32 = 5.1;

// The key light's map projected along the light onto the board's plane (task 086): a
// point's texel is where the light's ray through it meets y = 0, its depth how far along
// the ray, so the field and the frame fill the map at one texel size, square, with
// nothing round them. A square view along the light, 13.2 wide, slanted 1.25× across the
// field, gave it 2.1× fewer texels. An oblique, affine projection whose handedness is a
// view's along the light.
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
    if count > 0 { gpu_update(g.instances, bytes_of(inst[..count])); }
    g.instance_count = count / 2;
    let fading = min(alphas.len, g.instance_count);
    g.solid = g.instance_count - fading;
    for i in fading { g.alphas[i] = alphas[i]; }
    gpu_update(g.squares, bytes_of(squares[..min(squares.len, SQUARE_ENTRIES)]));
    for i in SQUARE_ENTRIES { g.squares_now[i] = if i < squares.len { squares[i] } else { float4_0 }; }
    gpu_update(g.marks, bytes_of(marks[..min(marks.len, SQUARES)]));
    if lit.len > 0 { gpu_update(g.glows, bytes_of(lit[..min(lit.len, SQUARES)])); }
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
fn draw(g: Gpu&, view_proj: Mat, eye: float3, out: Texture, size: int2, shadow_every: bool = false,
        backdrop: bool = true, keep_depth: bool = false) {
    if size.x != g.size.x || size.y != g.size.y { targets(g, size); }
    pass_targets(g);
    let target = if out.id == 0 { g.image } else { out };
    g.frame.view_proj = view_proj;
    g.frame.eye = model3d::f4(eye, 1.0);
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    keep_backdrop(g, size);
    if g.shadow_dirty || shadow_every {
        shadow_pass(g);
        g.shadow_dirty = false;
    }
    occlusion(g);
    board_pass(g, target, size, backdrop);
    if keep_depth { draw_depth(g); }
}

// The pieces' occlusion of the field drawn into g.occ_map where the squares changed since
// it was drawn (all of it the first time and for a new board size): a square's piece,
// anywhere over it, darkens the field within OCC_REACH squares of its own
// (shaders::OCC_FRAG's 5 × 5), so the changed squares and that many round them,
// scissored. A moving piece redraws about 6 × 6 squares of the 64; a still board,
// nothing. Recording only, before the board's pass.
let OCC_REACH = 2;
fn same4(a: float4, b: float4) -> bool { a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w }
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
    occ_pass(g, x0, y0, x1, y1);
    g.occ_squares = g.squares_now;
    g.occ_n = n;
}

// The backdrop drawn at full opacity into g.kept_backdrop when what it is drawn from
// changed (a size, a photograph, a look, the plain fade), so the screen's frames lay it
// with a fetch a pixel (shaders::KEPT_FRAG) instead of grading the photograph each frame
// (task 059: 7% of the Pixel 7a's GPU cycles a frame). Before draw()'s passes, which
// come with every change but the photograph's alone; till the next, backdrop() draws
// it as it was. Recording only.
fn keep_backdrop(g: Gpu&, size: int2) {
    guard !g.live && !kept_current(g, size) else { return; }
    if g.kept_backdrop.id == 0 { g.kept_backdrop = gpu_target(size.x, size.y); }
    kept_pass(g);
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
let WARM_STEPS = 11;
