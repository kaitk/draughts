// The season's photograph (docs/architecture/rendering.md, "Scene and glass"): sharp
// behind home, and blurred once on the GPU when the season is picked behind the 2D game.
// The program's C (background.c) makes the sharp texture: the built-in ASTC image where
// the GPU samples it, else the JPEG decoded. A shrinking pass averages it down to a small
// copy, and two passes of a Gaussian, across and then down, blur that into the texture
// the board pass samples behind the game. A season whose image isn't built in has no
// photograph, and the board pass shows the page color. Glass panels sample a copy
// blurred further, made at the same time.
namespace scene;
import std;
import vec;
import gfx;

// The blurred copy's side. The photograph is cover-cropped to the screen by its long
// side, so the blur is a fraction of that: 14 px at 1280 px (rendering.md) is a sigma
// of 5.6 texels here, at any screen size. Scaled up, a blurred image this size shows
// no texels.
let SIZE = 512;

// The sharp photograph's side where the JPEG is decoded: as it is stored, about a texel
// to a pixel across a 1920 px screen. 16 MB of graphics memory as RGBA8, 1.8 MB as the
// ASTC image (6 × 6 blocks), which keeps the size it is stored at.
let SHARP_SIZE = 2048;

// The glass copy's side, and its blur: the one a 24 px blur is at 1280 px (rendering.md,
// "Scene and glass"), 4.8 texels here, of which the 512 px copy already has 2.8.
let GLASS_SIZE = 256;
let GLASS_SIGMA = 3.9;

// Theme `kind`'s photograph, or 0 when it isn't built in: the ASTC image as stored, or
// the JPEG decoded and scaled down to `decoded` square (background.c).
extern fn draughts_photo(kind: i64, decoded: i64) -> gfx::Texture;

// A season's thumbnail in settings: the photograph's middle at the picture's 104 × 64
// shape, about a texel to a pixel at 1.5 pixels per dp; the four stacked in one texture.
let THUMB_W = 160;
let THUMB_H = 98;

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

// Averages a part of the source into a part of the target. Each target pixel takes taps
// spread evenly across its footprint, about two source texels apart, each a bilinear
// average of four texels: shrinking 4×, 2 × 2 taps on the texels' corners are an exact
// box of 4 × 4 texels.
let SHRINK_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    // The source's part in uv (origin, size), the target's in pixels (origin, size).
    layout(set = 3, binding = 0) uniform Shrink { vec4 from; vec4 to; };
    void main() {
        vec2 pixel = from.zw / to.zw;
        vec2 uv = from.xy + (gl_FragCoord.xy - to.xy) * pixel;
        ivec2 n = max(ivec2(ceil(pixel * vec2(textureSize(src, 0)) * 0.5)), ivec2(1));
        vec3 sum = vec3(0.0);
        for (int y = 0; y < n.y; y++) {
            for (int x = 0; x < n.x; x++) {
                sum += texture(src, uv + ((vec2(x, y) + 0.5) / vec2(n) - 0.5) * pixel).rgb;
            }
        }
        result = vec4(sum / float(n.x * n.y), 1.0);
    }
    """;

struct Shrink { from: float4, to: float4 }

struct Scene {
    photo:   gfx::Texture,     // the blurred copy, or a 1×1 stand-in when there is none
    sharp:   gfx::Texture,     // the photograph as it is, or the stand-in
    glass:   gfx::Texture,     // the copy glass samples, blurred further
    sampler: gfx::Sampler,
    has:     bool,             // whether there is a photograph
}

// The photograph of theme `kind` (theme::WOOD..SUNSET), and its blurred copies.
fn load(kind: i64, full_vert: const u8[:]) -> Scene {
    let sampler = gfx::sampler(gfx::LINEAR, gfx::CLAMP);
    let sharp = draughts_photo(kind, SHARP_SIZE);
    if sharp.id == 0 {
        let none = gfx::texture2d(1, 1);
        var black: u8[4] = [0; 4];
        gfx::update_texture(none, black);
        return Scene { photo: none, sharp: none, glass: none, sampler: sampler, has: false };
    }
    let src = gfx::render_target(SIZE, SIZE, gfx::RGBA8);
    let shrink = gfx::pipeline(full_vert, embed_shader("frag", SHRINK_FRAG), gfx::PipelineDesc {});
    gfx::begin_pass(src, gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
    draw_shrink(shrink, sampler, sharp, float4 { 0.0, 0.0, 1.0, 1.0 },
                float4 { 0.0, 0.0, SIZE, SIZE });
    gfx::end_pass();
    gfx::release(shrink);
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

// Draws src's part `from` (uv origin and size) shrunk into the part `to` (pixels) of the
// pass's target, in a pass the caller begins.
fn draw_shrink(shrink: gfx::Pipeline, sampler: gfx::Sampler, src: gfx::Texture, from: float4,
               to: float4) {
    gfx::viewport(to.x, to.y, to.z, to.w);
    gfx::bind(shrink);
    gfx::bind_texture(gfx::FRAGMENT, 0, src, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Shrink { from: from, to: to });
    gfx::draw(3);
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

// The four seasons' thumbnails stacked, by theme, top to bottom, in one texture: each
// photograph's middle at the thumbnail's shape, shrunk on the GPU, one at a time; a
// season without a photograph is black. A decoded JPEG (about 125 ms for the four on the
// tablet) is scaled to SIZE on the way, so its texture is small. The app makes this in
// the first frame after the launch's first that draws nothing, rather than when settings
// first open.
fn thumbs(full_vert: const u8[:]) -> gfx::Texture {
    let t = gfx::render_target(THUMB_W, 4 * THUMB_H, gfx::RGBA8);
    let sampler = gfx::sampler(gfx::LINEAR, gfx::CLAMP);
    let shrink = gfx::pipeline(full_vert, embed_shader("frag", SHRINK_FRAG), gfx::PipelineDesc {});
    let crop: f32 = THUMB_H as f32 / THUMB_W;
    for kind in 4 {
        let photo = draughts_photo(kind, SIZE);
        // The first pass clears the whole texture; the others keep what is drawn.
        var desc = gfx::PassDesc { clear_color: kind == 0, .. };
        desc.color[0] = t;
        gfx::begin_pass(desc);
        if photo.id != 0 {
            draw_shrink(shrink, sampler, photo, float4 { 0.0, (1.0 - crop) * 0.5, 1.0, crop },
                        float4 { 0.0, kind * THUMB_H, THUMB_W, THUMB_H });
        }
        gfx::end_pass();
        if photo.id != 0 { gfx::release(photo); }
        // A released texture is freed once the GPU is done with it: waiting here keeps
        // one photograph at a time, which as ASTC (1.8 MB) sits in SDL's shared 16 MiB
        // block; four at once took a second block that stayed.
        gfx::flush();
    }
    gfx::release(shrink);
    gfx::release(sampler);
    return t;
}
