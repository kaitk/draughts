// Recording the scene's passes (scene.goose) through goose-ngfx, in place of
// src/app/scene_gpu.goose (scripts/ngfx.py): the shaders are written from that file's
// GLSL (scripts/ngfx_2d_shaders.py) and built ahead, the pipelines made once and kept,
// and each pass's writes made visible to the passes after it that sample them.
namespace scene_gpu;
import std;
import vec;
import ngfx;

// The shaders' roots, as their headers lay them out.
struct ShrinkRoot { src: u32, smp: u32, pad0: u32, pad1: u32, from: float4, to: float4 }
struct BlurRoot { src: u32, smp: u32, pad0: u32, pad1: u32, dir: float4 }
struct FadeRoot { to: float4, top: float4, low: float4, light: float4 }

struct Pipelines { shrink: ngfx::Pipeline, blur: ngfx::Pipeline, fade: ngfx::Pipeline }
var pipelines = Pipelines { ngfx::Pipeline { 0 }, ngfx::Pipeline { 0 }, ngfx::Pipeline { 0 } };

fn made() -> Pipelines {
    if pipelines.shrink.id == 0 {
        pipelines.shrink = ngfx::pipeline(embed_file("shaders/shrink.blob"));
        pipelines.blur = ngfx::pipeline(embed_file("shaders/blur.blob"));
        pipelines.fade = ngfx::pipeline(embed_file("shaders/fade.blob"));
    }
    return pipelines;
}

fn sampler() -> gpu::Sampler { ngfx::sampler(ngfx::LINEAR, ngfx::CLAMP) }

fn black() -> gpu::Texture {
    let none = ngfx::texture2d(1, 1);
    var px: u8[4] = [0; 4];
    ngfx::update_texture(none, px);
    return none;
}

fn shrinker() -> gpu::Pipeline { made().shrink }
fn blurrer() -> gpu::Pipeline { made().blur }
fn fader() -> gpu::Pipeline { made().fade }

// The pipelines are kept for the next use.
fn done(p: gpu::Pipeline) {}

fn begin(dst: gpu::Texture, clear: bool) {
    var desc = ngfx::PassDesc { clear_color: clear, .. };
    desc.color[0] = dst;
    ngfx::begin_pass(desc);
}

// Ends the pass and makes what it wrote visible to the passes after it that sample it.
fn end() {
    ngfx::end_pass();
    ngfx::barrier(ngfx::TARGET_WRITE, ngfx::FRAGMENT_READ);
}

fn shrink(p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, from: float4, to: float4) {
    ngfx::viewport(to.x, to.y, to.z, to.w);
    ngfx::bind(p);
    ngfx::draw(ngfx::root(ShrinkRoot { src: ngfx::index(src), smp: ngfx::index(sampler), pad0: 0, pad1: 0,
                                       from: from, to: to }), 3);
}

fn blur(p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, dst: gpu::Texture, dir: float4) {
    begin(dst, true);
    ngfx::bind(p);
    ngfx::draw(ngfx::root(BlurRoot { src: ngfx::index(src), smp: ngfx::index(sampler), pad0: 0, pad1: 0, dir: dir }), 3);
    end();
}

fn fade(p: gpu::Pipeline, to: float4, top: float4, low: float4, light: float4) {
    ngfx::viewport(to.x, to.y, to.z, to.w);
    ngfx::bind(p);
    ngfx::draw(ngfx::root(FadeRoot { to: to, top: top, low: low, light: light }), 3);
}

// Releases a texture the pass before drew from, if any, once the next pass into the same
// target waits for that one.
fn let_go(t: gpu::Texture) {
    ngfx::barrier(ngfx::TARGET_WRITE, ngfx::TARGET_WRITE);
    if t.id != 0 { ngfx::release(t); }
}
