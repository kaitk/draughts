// The 3D board's renderer (task 015), shared by the app (src/app/draw3d.goose) and the
// prototype (poc/3d/board3d.goose): the board and the pieces as meshes (mesh.goose), the
// themes as data (looks.goose), the surfaces baked on the GPU, the season's photograph
// blurred into the backdrop with its ambient taken, the shadow map, and one forward pass
// into a 4× multisampled target resolved into a picture (shaders.goose).
//
// The one package besides app/ that draws: it imports gfx, and only the app and the
// prototype import it; the game's packages stay headless (docs/architecture/README.md).
// What it draws comes as data: the camera's matrix and eye (view3d::matrix), the
// instances and the field's occlusion and marks (view3d::Scene, laid out as the shaders
// read them).
//
// Frame structure: the shadow map (2048², 16-bit, from the key light) only when the
// pieces stand differently; then one pass: the blurred photograph as a backdrop, the
// board's soft shadow on nothing, the board and the pieces lit, the field's marks added.
// No post pass, no discard, nothing temporal. Nothing is made or released while drawing
// but the targets on a resize.
namespace render3d;
import std;
import vec;
import math;
import gfx;
import .mesh;
import .shaders;
import .looks;

// The season's photograph (src/app/background.c, which both programs compile): kind is
// the app's theme, decoded to `decoded` square where the GPU has no ASTC.
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
    finish:        float4,  // looks::Finish: varnish, sanding, grain, rings
    tone:          float4,  // x: its warmth, y: pickle, z: caulk
    marble:        float4,  // looks::Marble: veins, wave, polish, tint
    marble_base:   float4,
    marble_vein:   float4,
    marble_form:   float4,
    seam:          float4,  // looks::Theme.seam
}
struct Shrink { to: float4 }
struct Show { from: float4, to: float4, screen: float4 }
struct Blur { dir: float4 }

let SHADOW_SIZE = 2048;
let PLAN_SIZE = 2048;
let FRAME_MAP = 2048;
let PHOTO_SIZE = 512;
let SAMPLES = 4;
let MAX_INSTANCES = 96;     // view3d::MAX_INSTANCES: two for each of board::MAX_PIECES
let SQUARES = 100;          // the field's squares, 10 × 10 at most
// The wood's model (task 039): 0 noise drawn out along the grain, 1 growth rings, 2
// growth rings with pores and a fibre relief, 3 the first with thin lines and pores laid
// over it.
let WOOD_MODELS = 4;
let WOOD_MODEL = 2;

// Everything on the GPU, made by setup() (the targets again on a resize).
struct Gpu {
    samples:        i32,
    wood:           i64,            // the wood's model the surfaces are baked with
    finish:         looks::Finish,  // and its finish
    marble:         i64,            // the stone frame's marble (looks::MARBLE..), 0 slate
    stone:          looks::Marble,  // and its look
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
    marks:          gfx::Buffer,
    glows:          gfx::Buffer,      // the field's glow rings and lit squares
    plan_albedo:    gfx::Texture,
    plan_normal:    gfx::Texture,
    frame_albedo:   gfx::Texture,
    frame_normal:   gfx::Texture,
    photo:          gfx::Texture,
    shadow_map:     gfx::Texture,
    color:          gfx::Texture,   // the multisampled target and its depth
    depth:          gfx::Texture,
    image:          gfx::Texture,   // what draw() resolves into when asked to keep it
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
    copy:           gfx::Pipeline,
    show:           gfx::Pipeline,  // the kept image over what is there, anywhere (show())
    bake:           gfx::Pipeline,  // kept for a theme's rebake, with the photograph's
    shrink:         gfx::Pipeline,
    blur:           gfx::Pipeline,
    small:          gfx::Texture,
    across:         gfx::Texture,
    frame:          Frame,
    shadow_dirty:   bool,
    turn:           f32,            // the board's turn (view3d::View.turn), the light turned with it
}

fn f4(v: float3, w: f32) -> float4 { float4 { v.x, v.y, v.z, w } }

// sRGB to linear, as the shaders take colors.
fn linear(c: f32) -> f32 {
    if c <= 0.04045 { return c / 12.92; }
    let e: f32 = 2.4;
    pow((c + 0.055) / 1.055, e)
}

fn linear4(c: float4) -> float4 { float4 { linear(c.x), linear(c.y), linear(c.z), c.w } }

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

// The photograph `kind` blurred into g.photo (src/app/scene.goose's way: shrunk to 512
// on the GPU, two passes of a Gaussian of sigma 5.6 texels), and its harmonics, taken
// `grey` of the way to grey. Decodes the photograph, so only at setup and on a theme
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
// their mips. Bake.mode: x the surface (0 the plan, 1 the frame map), y the wood's model,
// z the squares per side, w the marble (a stone frame's only).
fn bake(g: Gpu&, albedo: gfx::Texture, normal: gfx::Texture, w: i64, h: i64, mode: f32,
        extent: float2, t: looks::Theme&) {
    var pass = gfx::PassDesc {};
    pass.color[0] = albedo;
    pass.color[1] = normal;
    gfx::begin_pass(pass);
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
                                           m.base, m.vein, m.form, t.seam });
    gfx::draw(3);
    gfx::end_pass();
    gfx::generate_mips(albedo);
    gfx::generate_mips(normal);
}

// Bakes the plan and the frame map (or one of them), and waits for them: at setup, on a
// theme change, a new board size, and when the wood's model, its finish or the marble
// switches.
fn bake_surfaces(g: Gpu&, plan: bool = true, frame: bool = true) {
    let t = looks::get(g.look);
    let span = 2.0 * mesh::INNER;
    if plan { bake(g, g.plan_albedo, g.plan_normal, PLAN_SIZE, PLAN_SIZE, 0.0, float2 { span, span }, t); }
    if frame { bake(g, g.frame_albedo, g.frame_normal, FRAME_MAP, FRAME_MAP, 1.0, float2 { 10.4, 10.4 }, t); }
    gfx::flush();
}

// A target with its mips for a baked surface.
fn baked(w: i64, h: i64, format: i32) -> gfx::Texture {
    return gfx::texture(gfx::TextureDesc { format: format,
                                           usage: gfx::COLOR_TARGET | gfx::SAMPLED,
                                           width: w as i32, height: h as i32, mips: 0 });
}

// The multisampled target, its depth, and the kept image, at `size`; made again only
// when the size changes.
fn targets(g: Gpu&, size: int2) {
    if g.color.id != 0 { gfx::release(g.color); }
    if g.depth.id != 0 { gfx::release(g.depth); }
    if g.image.id != 0 { gfx::release(g.image); }
    g.color = gfx::Texture { 0 };
    if g.samples > 1 {
        g.color = gfx::texture(gfx::TextureDesc { format: gfx::RGBA8, usage: gfx::COLOR_TARGET,
                                                  width: size.x, height: size.y,
                                                  samples: g.samples });
    }
    g.depth = gfx::texture(gfx::TextureDesc { format: gfx::DEPTH, usage: gfx::DEPTH_TARGET,
                                              width: size.x, height: size.y,
                                              samples: g.samples });
    g.image = gfx::render_target(size.x, size.y, gfx::RGBA8);
    g.size = size;
}

// Makes everything the renderer draws with: the meshes, the buffers, the pipelines, the
// baked surfaces' and the photograph's targets. Then apply() puts a theme on it.
// `samples` 4 is the multisampled pass; 1 draws straight into the target (measuring).
fn setup(g: Gpu&, samples: i32 = SAMPLES) {
    g.samples = samples;
    g.wood = WOOD_MODEL;
    g.finish = looks::finish(WOOD_MODEL);
    g.marble = looks::MARBLE;
    g.stone = looks::marble(looks::MARBLE);
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
    g.backdrop = gfx::pipeline(full, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                                  shaders::BACKDROP_FRAG),
                               gfx::PipelineDesc { blend: gfx::BLEND_ALPHA });
    g.catcher = gfx::pipeline(quad_vs, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                                    shaders::SHADOW_CATCHER_FRAG),
                              gfx::PipelineDesc { blend: gfx::BLEND_ALPHA });
    g.glow = gfx::pipeline(quad_vs, embed_shader("frag", shaders::FS_SET, shaders::FRAME,
                                                 shaders::MARKS_FRAG),
                           gfx::PipelineDesc { depth_test: true, blend: gfx::BLEND_ADD });
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
    let t = looks::get(which);
    let kind = if photo >= 0 { photo } else { t.photo };
    if which != g.look || n != g.n {
        g.look = which;
        g.n = n;
        bake_surfaces(g);
    }
    if kind != g.photo_kind || g.frame.light_dir.w == 0.0 {
        g.photo_kind = kind;
        var sh: float4[9] = [float4_0; 9];
        photograph(g, kind, t.ambient.z, sh);
        g.frame.sh = sh;
        gfx::flush();
    }
    // The key light, from the upper left; the photograph's ambient.
    light(g);
    let f .= g.frame;
    f.light_color = linear4(t.key_color);
    f.params = float4 { t.ambient.x, 1.0 / SHADOW_SIZE, t.ambient.y, n };
    f.glow = t.glow;
    f.light_piece = linear4(t.light_piece);
    f.dark_piece = linear4(t.dark_piece);
    f.piece_fig = t.piece_fig;
    f.crown = linear4(t.crown);
    f.edge = linear4(t.edge);
    if marbled(g, t) { f.edge.w = 0.0; }
    f.line = linear4(t.line);
    f.bounce = linear4(t.bounce);
    f.grade = t.grade;
    f.tint = linear4(t.tint);
    f.frame_build = t.build;
    f.frame_surface = t.frame_surface;
    g.shadow_dirty = true;
}

// The key light, from the upper left of the screen, turned with the board (g.turn) so it
// keeps its place on screen while the board turns under it: its direction and the shadow
// map's projection.
fn light(g: Gpu&) {
    let t = looks::get(g.look);
    let l = spin(normalize(float3 { t.key.x, t.key.y, t.key.z }), g.turn);
    let light_view = gfx::look_at(l * 20.0, float3_0, float3 { 0.0, 1.0, 0.0 });
    let reach: f32 = 6.6;
    let light_proj = gfx::ortho(-reach, reach, -reach, reach, 5.0, 35.0);
    g.frame.light_view_proj = gfx::mul(light_proj, light_view);
    g.frame.light_dir = f4(l, t.key.w);
}

// The board turned `turn` degrees under the light (a hot-seat turn, view3d::Camera.turn):
// the light turned the same way, and the shadow map drawn again with the next frame.
fn turn_light(g: Gpu&, turn: f32) {
    guard turn != g.turn else { return; }
    g.turn = turn;
    light(g);
    g.shadow_dirty = true;
}

// p turned `degrees` about the y axis, as view3d::spin turns the camera.
fn spin(p: float3, degrees: f32) -> float3 {
    let a = radians(degrees);
    let c = cos(a);
    let s = sin(a);
    return float3 { c * p.x + s * p.z, p.y, c * p.z - s * p.x };
}

// Whether the frame is marble: a stone frame with a marble chosen. Its rounded edge
// then keeps the marble, not the slate's steel-blue round.
fn marbled(g: Gpu&, t: looks::Theme&) -> bool { g.marble > 0 && t.frame_fig.w < 0.5 }

// Chooses the wood's model and the marble, each with its own finish or look, before
// apply() bakes them (-1 keeps what is chosen): the app's --wood and --marble.
fn choose(g: Gpu&, wood: i64, marble: i64) {
    if wood >= 0 {
        g.wood = clamp(wood, 0, WOOD_MODELS - 1);
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
    let t = looks::get(g.look);
    let wood_changed = wood != g.wood || finish != g.finish;
    let marble_changed = marble != g.marble || stone != g.stone;
    g.wood = clamp(wood, 0, WOOD_MODELS - 1);
    g.finish = finish;
    g.marble = clamp(marble, 0, looks::MARBLES - 1);
    g.stone = stone;
    let plan = wood_changed && t.light_fig.w > 0.5;
    let frame = (wood_changed && t.frame_fig.w > 0.5) || (marble_changed && t.frame_fig.w < 0.5);
    if plan || frame { bake_surfaces(g, plan, frame); }
    g.frame.edge = linear4(t.edge);
    if marbled(g, t) { g.frame.edge.w = 0.0; }
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
    gfx::update_buffer(g.marks, bytes_of(marks[..min(marks.len, SQUARES)]));
    if lit.len > 0 { gfx::update_buffer(g.glows, bytes_of(lit[..min(lit.len, SQUARES)])); }
    g.frame.selected = selected;
    g.frame.screen.z = dim;
    if moved { g.shadow_dirty = true; }
}

// Draws a frame seen through view_proj from `eye` into `out`, a color target of `size`
// (gfx's screen; or for Texture { 0 } g.image, kept for show()): the shadow map first if
// the pieces moved, then the one pass. Without the `backdrop` the target is clear but for
// the board, its shadow, and the pieces (premultiplied), for show() to lay over a
// backdrop drawn apart (backdrop(), or the app's photograph). Recording only; the
// caller's gfx::frame() submits it.
fn draw(g: Gpu&, view_proj: gfx::mat4, eye: float3, out: gfx::Texture, size: int2, shadow_every: bool = false,
        backdrop: bool = true) {
    if size.x != g.size.x || size.y != g.size.y { targets(g, size); }
    let target = if out.id == 0 { g.image } else { out };
    g.frame.view_proj = view_proj;
    g.frame.eye = f4(eye, 1.0);
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
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

    gfx::bind(g.catcher);
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4_0 });
    gfx::draw(6);

    gfx::bind(g.lit);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, g.instances);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.plan_albedo, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 1, g.plan_normal, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 2, g.frame_albedo, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 3, g.frame_normal, g.aniso);
    gfx::bind_texture(gfx::FRAGMENT, 4, g.shadow_map, g.compare);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 0, g.squares);
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

    // The field's marks and the selected piece's ring, added where nothing stands over.
    gfx::bind(g.glow);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 0, g.marks);
    gfx::bind_storage_buffer(gfx::FRAGMENT, 1, g.glows);
    gfx::uniforms(gfx::VERTEX, 0, f);
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 2.0, g.n, 0.0, 0.0 } });
    gfx::uniforms(gfx::FRAGMENT, 0, f);
    gfx::uniforms(gfx::FRAGMENT, 1, Draw { float4 { 2.0, g.n, 0.0, 0.0 } });
    gfx::draw(6);
    gfx::end_pass();
}

// The board, then the opaque pieces as instances; from the light when `light` is 1.
fn draw_meshes(g: Gpu&, light: f32) {
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 0.0, light, 1.0, 0.0 } });
    gfx::bind_vertex_buffer(g.board_vb);
    gfx::bind_index_buffer(g.board_ib, 4);
    gfx::draw_indexed(g.board_count);
    guard g.solid > 0 else { return; }
    gfx::uniforms(gfx::VERTEX, 1, Draw { float4 { 1.0, light, 1.0, 0.0 } });
    gfx::bind_vertex_buffer(g.piece_vb);
    gfx::bind_index_buffer(g.piece_ib, 4);
    gfx::draw_indexed_instanced(g.piece_count, g.solid);
}

// The blurred photograph, graded, at opacity `alpha` over the open pass's target.
fn draw_backdrop(g: Gpu&, alpha: f32) {
    gfx::bind(g.backdrop);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.photo, g.linear);
    gfx::uniforms(gfx::FRAGMENT, 0, g.frame);
    gfx::uniforms(gfx::FRAGMENT, 1, Draw { float4 { alpha, 0.0, 0.0, 0.0 } });
    gfx::draw(3);
}

// The backdrop draw() leaves out without one, over the open pass's target of `size`
// (gfx's screen) at opacity `alpha`: under show()'s image, or fading in over the app's
// own photograph in a transition.
fn backdrop(g: Gpu&, alpha: f32, size: int2) {
    g.frame.screen = float4 { size.x, size.y, g.frame.screen.z, 0.0 };
    draw_backdrop(g, alpha);
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
// pixels, at opacity `alpha`. The same rect is the image as drawn, texel for texel.
fn show(g: Gpu&, from: float4, to: float4, alpha: f32, size: int2) {
    gfx::bind(g.show);
    gfx::bind_texture(gfx::FRAGMENT, 0, g.image, g.linear);
    let u = Show { from: from, to: to, screen: float4 { size.x, size.y, alpha, 0.0 } };
    gfx::uniforms(gfx::VERTEX, 0, u);
    gfx::uniforms(gfx::FRAGMENT, 0, u);
    gfx::draw(6);
}
