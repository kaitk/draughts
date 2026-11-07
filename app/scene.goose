// The season's photograph (docs/architecture/rendering.md, "Scene and glass"): sharp
// behind home, and blurred once on the GPU when the season is picked behind the 2D game.
// The program's C (background.c) decodes the built-in JPEG once and scales it to each
// size; two passes of a Gaussian, across and then down, blur the small copy into the
// texture the board pass samples behind the game. A season whose image isn't built in
// has no photograph, and the board pass shows the page color. Glass panels sample a
// copy blurred further, made at the same time.
namespace scene;
import std;
import vec;
import gfx;

// The blurred copy's side. The photograph is cover-cropped to the screen by its long
// side, so the blur is a fraction of that: 14 px at 1280 px (rendering.md) is a sigma
// of 5.6 texels here, at any screen size. Scaled up, a blurred image this size shows
// no texels.
let SIZE = 512;

// The sharp photograph's side: as the JPEG is stored, about a texel to a pixel across a
// 1920 px screen. 16 MB of graphics memory.
let SHARP_SIZE = 2048;

// The glass copy's side, and its blur: the one a 24 px blur is at 1280 px (rendering.md,
// "Scene and glass"), 4.8 texels here, of which the 512 px copy already has 2.8.
let GLASS_SIZE = 256;
let GLASS_SIGMA = 3.9;

extern fn draughts_background(kind: i64, size: i64, out: u8[:]) -> bool;
extern fn draughts_background_crop(kind: i64, width: i64, height: i64, out: u8[:]) -> bool;

// A season's thumbnail in settings: the photograph's middle at the picture's 104 × 64
// shape, about a texel to a pixel at 1.5 pixels per dp; the four stacked in one texture.
let THUMB_W = 160;
let THUMB_H = 98;
extern fn draughts_background_done();

let BLUR_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    // One texel's step in the source, sigma in source texels, one target pixel in uv.
    layout(set = 3, binding = 0) uniform Blur { vec4 dir; };
    void main() {
        vec2 uv = gl_FragCoord.xy * dir.w;
        vec3 sum = vec3(0.0);
        float total = 0.0;
        for (int i = -17; i <= 17; i++) {
            float w = exp(-0.5 * float(i * i) / (dir.z * dir.z));
            sum += w * texture(src, uv + float(i) * dir.xy).rgb;
            total += w;
        }
        result = vec4(sum / total, 1.0);
    }
    """;

struct Blur { dir: float4 }

struct Scene {
    photo:   gfx::Texture,     // the blurred copy, or a 1×1 stand-in when there is none
    sharp:   gfx::Texture,     // the photograph as it is, or the stand-in
    glass:   gfx::Texture,     // the copy glass samples, blurred further
    sampler: gfx::Sampler,
    has:     bool,             // whether there is a photograph
}

// The photograph of theme `kind` (theme::WOOD..SEA), decoded and blurred.
fn load(kind: i64, full_vert: const u8[:]) -> Scene {
    let sampler = gfx::sampler(gfx::LINEAR, gfx::CLAMP);
    var px: u8[>..] = [];
    px.resize(SHARP_SIZE * SHARP_SIZE * 4, 0);
    if !draughts_background(kind, SHARP_SIZE, px) {
        let none = gfx::texture2d(1, 1);
        gfx::update_texture(none, px[0..4]);
        return Scene { photo: none, sharp: none, glass: none, sampler: sampler, has: false };
    }
    let sharp = gfx::texture2d(SHARP_SIZE, SHARP_SIZE);
    gfx::update_texture(sharp, px);
    draughts_background(kind, SIZE, px);
    draughts_background_done();
    let src = gfx::texture2d(SIZE, SIZE);
    gfx::update_texture(src, px[..SIZE * SIZE * 4]);
    let across = gfx::render_target(SIZE, SIZE, gfx::RGBA8);
    let blurred = gfx::render_target(SIZE, SIZE, gfx::RGBA8);
    let glass_across = gfx::render_target(GLASS_SIZE, GLASS_SIZE, gfx::RGBA8);
    let glass = gfx::render_target(GLASS_SIZE, GLASS_SIZE, gfx::RGBA8);
    let blur = gfx::pipeline(full_vert, embed_shader("frag", BLUR_FRAG), gfx::PipelineDesc {});
    let step = 1.0 / SIZE;
    pass(blur, sampler, src, across, float4 { step, 0.0, 5.6, step });
    pass(blur, sampler, across, blurred, float4 { 0.0, step, 5.6, step });
    // The glass copy reads the 512 px copy at half its resolution, in its own texels.
    let g = 1.0 / GLASS_SIZE;
    pass(blur, sampler, blurred, glass_across, float4 { g, 0.0, GLASS_SIGMA, g });
    pass(blur, sampler, glass_across, glass, float4 { 0.0, g, GLASS_SIGMA, g });
    gfx::release(blur);
    gfx::release(across);
    gfx::release(glass_across);
    gfx::release(src);
    return Scene { photo: blurred, sharp: sharp, glass: glass, sampler: sampler, has: true };
}

// One blur pass from src into dst, in direction dir (Blur's fields).
fn pass(blur: gfx::Pipeline, sampler: gfx::Sampler, src: gfx::Texture, dst: gfx::Texture,
        dir: float4) {
    gfx::begin_pass(dst, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
    gfx::bind(blur);
    gfx::bind_texture(gfx::FRAGMENT, 0, src, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Blur { dir: dir });
    gfx::draw(3);
    gfx::end_pass();
}

// Releases the scene's textures, for another season's.
fn release(s: Scene&) {
    gfx::release(s.photo);
    if s.has {
        gfx::release(s.sharp);
        gfx::release(s.glass);
    }
    gfx::release(s.sampler);
}

// The four seasons' thumbnails stacked, by theme, top to bottom, in one texture; a
// season without a photograph is black. Each decodes its photograph, so this is made
// only when settings first opens.
fn thumbs() -> gfx::Texture {
    var px: u8[>..] = [];
    px.resize(THUMB_W * THUMB_H * 4 * 4, 0);
    let one = THUMB_W * THUMB_H * 4;
    for kind in 4 { draughts_background_crop(kind, THUMB_W, THUMB_H, px[kind * one..(kind + 1) * one]); }
    draughts_background_done();
    let t = gfx::texture2d(THUMB_W, 4 * THUMB_H);
    gfx::update_texture(t, px);
    return t;
}
