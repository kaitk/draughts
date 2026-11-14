// Recording the scene's passes (scene.goose) through goose-ngfx, beside gfx's
// src/app/scene_gpu.goose in the build that holds both (draughts_ngfx.goose): the shaders are written from that file's
// GLSL (scripts/ngfx_2d_shaders.py) and built ahead, the pipelines made once and kept,
// and each pass's writes made visible to the passes after it that sample them.
namespace scene_ngfx;
import std;
import vec;
import ngfx;

// The shaders' roots, as their headers lay them out.
struct ShrinkRoot { src: u32, smp: u32, pad0: u32, pad1: u32, from: float4, to: float4 }
struct BlurRoot { src: u32, smp: u32, pad0: u32, pad1: u32, dir: float4 }
struct FadeRoot { to: float4, top: float4, low: float4, light: float4 }

// The pipelines, made at their first use and kept.
struct Gpu { shrinking: nx::Pipeline, blurring: nx::Pipeline, fading: nx::Pipeline }

fn made(g: Gpu&) -> Gpu {
    if g.shrinking.id == 0 {
        g.shrinking = nx::pipeline(embed_file("../../build/ngfx/blobs/shrink.blob"));
        g.blurring = nx::pipeline(embed_file("../../build/ngfx/blobs/blur.blob"));
        g.fading = nx::pipeline(embed_file("../../build/ngfx/blobs/fade.blob"));
    }
    return g;
}

fn sampler(g: Gpu&) -> gpu::Sampler { nx::sampler(ngfx::LINEAR, ngfx::CLAMP) }

fn black(g: Gpu&) -> gpu::Texture {
    let none = nx::texture2d(1, 1);
    var px: u8[4] = [0; 4];
    nx::update_texture(none, px);
    return none;
}

fn shrinker(g: Gpu&) -> gpu::Pipeline { made(g).shrinking }
fn blurrer(g: Gpu&) -> gpu::Pipeline { made(g).blurring }
fn fader(g: Gpu&) -> gpu::Pipeline { made(g).fading }

// The pipelines are kept for the next use.
fn done(g: Gpu&, p: gpu::Pipeline) {}

fn begin(g: Gpu&, dst: gpu::Texture, clear: bool) {
    var desc = nx::PassDesc { clear_color: clear, .. };
    desc.color[0] = dst;
    nx::begin_pass(desc);
}

// Ends the pass and makes what it wrote visible to the passes after it that sample it.
fn end(g: Gpu&) {
    ngfx::end_pass();
    ngfx::barrier(ngfx::TARGET_WRITE, ngfx::FRAGMENT_READ);
}

fn shrink(g: Gpu&, p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, from: float4, to: float4) {
    ngfx::viewport(to.x, to.y, to.z, to.w);
    nx::bind(p);
    ngfx::draw(ngfx::root(ShrinkRoot { src: nx::index(src), smp: nx::index(sampler), pad0: 0, pad1: 0,
                                       from: from, to: to }), 3);
}

fn blur(g: Gpu&, p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, dst: gpu::Texture, dir: float4) {
    begin(g, dst, true);
    nx::bind(p);
    ngfx::draw(ngfx::root(BlurRoot { src: nx::index(src), smp: nx::index(sampler), pad0: 0, pad1: 0, dir: dir }), 3);
    end(g);
}

fn fade(g: Gpu&, p: gpu::Pipeline, to: float4, top: float4, low: float4, light: float4) {
    ngfx::viewport(to.x, to.y, to.z, to.w);
    nx::bind(p);
    ngfx::draw(ngfx::root(FadeRoot { to: to, top: top, low: low, light: light }), 3);
}

// Releases a texture the pass before drew from, if any, once the next pass into the same
// target waits for that one.
fn let_go(g: Gpu&, t: gpu::Texture) {
    ngfx::barrier(ngfx::TARGET_WRITE, ngfx::TARGET_WRITE);
    if t.id != 0 { nx::release(t); }
}
