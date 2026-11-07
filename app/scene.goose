// The season's photograph behind the 2D game, blurred once on the GPU when the season
// is picked (docs/architecture/rendering.md, "Scene and glass"). The program's C
// (background.c) decodes the built-in JPEG and scales it down; two passes of a Gaussian,
// across and then down, blur it into the texture the board pass samples. A season whose
// image isn't built in has no photograph, and the board pass shows the page color.
// Glass panels sample a copy blurred further, made at the same time.
namespace scene;
import std;
import vec;
import gfx;

// The blurred copy's side. The photograph is cover-cropped to the screen by its long
// side, so the blur is a fraction of that: 14 px at 1280 px (rendering.md) is a sigma
// of 5.6 texels here, at any screen size. Scaled up, a blurred image this size shows
// no texels.
let SIZE = 512;

// The glass copy's side, and its blur: the one a 24 px blur is at 1280 px (rendering.md,
// "Scene and glass"), 4.8 texels here, of which the 512 px copy already has 2.8.
let GLASS_SIZE = 256;
let GLASS_SIGMA = 3.9;

extern fn draughts_background(kind: i64, size: i64, out: u8[:]) -> bool;

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
    glass:   gfx::Texture,     // the copy glass samples, blurred further
    sampler: gfx::Sampler,
    has:     bool,             // whether there is a photograph
}

// The photograph of theme `kind` (theme::WOOD..SEA), decoded and blurred.
fn load(kind: i64, full_vert: const u8[:]) -> Scene {
    let sampler = gfx::sampler(gfx::LINEAR, gfx::CLAMP);
    var px: u8[>..] = [];
    px.resize(SIZE * SIZE * 4, 0);
    if !draughts_background(kind, SIZE, px) {
        let none = gfx::texture2d(1, 1);
        gfx::update_texture(none, px[0..4]);
        return Scene { photo: none, glass: none, sampler: sampler, has: false };
    }
    let src = gfx::texture2d(SIZE, SIZE);
    gfx::update_texture(src, px);
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
    return Scene { photo: blurred, glass: glass, sampler: sampler, has: true };
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
