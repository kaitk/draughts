// Recording the scene's passes (scene.goose) through gfx: its shaders, its pipelines,
// made for each use and released after, and the passes into its textures. The
// goose-ngfx build's src/ngfx/app/scene_gpu.goose takes this file's place.
namespace scene_gpu;
import std;
import vec;
import gfx;

// The plain fade in a pass's part `to` (pixels: origin, size), from the theme's colors.
let FADE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 3, binding = 0) uniform Fade { vec4 to; vec4 top; vec4 low; vec4 light; };
    void main() {
        result = vec4(plain_fade(gl_FragCoord.xy - to.xy, to.zw, top.rgb, low.rgb, light.rgb), 1.0);
    }
    """;

struct Fade { to: float4, top: float4, low: float4, light: float4 }

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

fn sampler() -> gpu::Sampler { gfx::sampler(gfx::LINEAR, gfx::CLAMP) }

// A 1×1 black texture, the stand-in for a photograph there is none of.
fn black() -> gpu::Texture {
    let none = gfx::texture2d(1, 1);
    var px: u8[4] = [0; 4];
    gfx::update_texture(none, px);
    return none;
}

fn shrinker() -> gpu::Pipeline { gfx::pipeline(gpu::full_vert(), embed_shader("frag", SHRINK_FRAG), gfx::PipelineDesc {}) }
fn blurrer() -> gpu::Pipeline { gfx::pipeline(gpu::full_vert(), embed_shader("frag", BLUR_FRAG), gfx::PipelineDesc {}) }
fn fader() -> gpu::Pipeline {
    gfx::pipeline(gpu::full_vert(), embed_shader("frag", shaders::FADE_FN, FADE_FRAG), gfx::PipelineDesc {})
}

// A pipeline the passes are done with.
fn done(p: gpu::Pipeline) { gfx::release(p); }

// A pass into `dst`, cleared to black with `clear`, else keeping what it holds.
fn begin(dst: gpu::Texture, clear: bool) {
    var desc = gfx::PassDesc { clear_color: clear, .. };
    desc.color[0] = dst;
    gfx::begin_pass(desc);
}

fn end() { gfx::end_pass(); }

// Draws src's part `from` (uv origin and size) shrunk into the part `to` (pixels) of the
// open pass's target.
fn shrink(p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, from: float4, to: float4) {
    gfx::viewport(to.x, to.y, to.z, to.w);
    gfx::bind(p);
    gfx::bind_texture(gfx::FRAGMENT, 0, src, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Shrink { from: from, to: to });
    gfx::draw(3);
}

// One blur pass from src into dst, in direction dir (Blur's fields).
fn blur(p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, dst: gpu::Texture, dir: float4) {
    begin(dst, true);
    gfx::bind(p);
    gfx::bind_texture(gfx::FRAGMENT, 0, src, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Blur { dir: dir });
    gfx::draw(3);
    gfx::end_pass();
}

// The plain fade into the part `to` (pixels) of the open pass's target, in a theme's
// colors.
fn fade(p: gpu::Pipeline, to: float4, top: float4, low: float4, light: float4) {
    gfx::viewport(to.x, to.y, to.z, to.w);
    gfx::bind(p);
    gfx::uniforms(gfx::FRAGMENT, 0, Fade { to: to, top: top, low: low, light: light });
    gfx::draw(3);
}

// Releases a texture the pass before drew from, if any, and waits for the GPU: a released
// texture is freed only once the GPU is done with it, so the next is made in its place.
fn let_go(t: gpu::Texture) {
    if t.id != 0 { gfx::release(t); }
    gfx::flush();
}
