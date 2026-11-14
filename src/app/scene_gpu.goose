// Recording the scene's passes (scene.goose) through gfx. On goose-ngfx: scene_ngfx.
namespace scene_gpu;
import std;
import vec;
import gfx;

// Nothing kept: gfx's pipelines are made for each use.
struct Gpu {}

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

// The blur's and the shrink's shaders are the 3D board's too (src/render3d/shaders.goose).
struct Blur { dir: float4 }

struct Shrink { from: float4, to: float4 }

fn sampler(g: Gpu&) -> gpu::Sampler { gfx::sampler(gfx::LINEAR, gfx::CLAMP) }

// A 1×1 black texture, the stand-in for a photograph there is none of.
fn black(g: Gpu&) -> gpu::Texture {
    let none = gfx::texture2d(1, 1);
    var px: u8[4] = [0; 4];
    gfx::update_texture(none, px);
    return none;
}

fn shrinker(g: Gpu&) -> gpu::Pipeline { gfx::pipeline(gpu::full_vert(), embed_shader("frag", shaders::SHRINK_FRAG), gfx::PipelineDesc {}) }
fn blurrer(g: Gpu&) -> gpu::Pipeline { gfx::pipeline(gpu::full_vert(), embed_shader("frag", shaders::BLUR_FRAG), gfx::PipelineDesc {}) }
fn fader(g: Gpu&) -> gpu::Pipeline {
    gfx::pipeline(gpu::full_vert(), embed_shader("frag", shaders::FADE_FN, FADE_FRAG), gfx::PipelineDesc {})
}

fn done(g: Gpu&, p: gpu::Pipeline) { gfx::release(p); }

// A pass into `dst`, cleared to black with `clear`, else keeping what it holds.
fn begin(g: Gpu&, dst: gpu::Texture, clear: bool) {
    var desc = gfx::PassDesc { clear_color: clear, .. };
    desc.color[0] = dst;
    gfx::begin_pass(desc);
}

fn end(g: Gpu&) { gfx::end_pass(); }

// Draws src's part `from` (uv origin and size) shrunk into the part `to` (pixels) of the
// open pass's target.
fn shrink(g: Gpu&, p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, from: float4, to: float4) {
    gfx::viewport(to.x, to.y, to.z, to.w);
    gfx::bind(p);
    gfx::bind_texture(gfx::FRAGMENT, 0, src, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Shrink { from: from, to: to });
    gfx::draw(3);
}

fn blur(g: Gpu&, p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, dst: gpu::Texture, dir: float4) {
    begin(g, dst, true);
    gfx::bind(p);
    gfx::bind_texture(gfx::FRAGMENT, 0, src, sampler);
    gfx::uniforms(gfx::FRAGMENT, 0, Blur { dir: dir });
    gfx::draw(3);
    gfx::end_pass();
}

// The plain fade into the part `to` (pixels) of the open pass's target.
fn fade(g: Gpu&, p: gpu::Pipeline, to: float4, top: float4, low: float4, light: float4) {
    gfx::viewport(to.x, to.y, to.z, to.w);
    gfx::bind(p);
    gfx::uniforms(gfx::FRAGMENT, 0, Fade { to: to, top: top, low: low, light: light });
    gfx::draw(3);
}

// Releases a texture the pass before drew from, if any, and waits for the GPU: a released
// texture is freed only once the GPU is done with it, so the next is made in its place.
fn let_go(g: Gpu&, t: gpu::Texture) {
    if t.id != 0 { gfx::release(t); }
    gfx::flush();
}
