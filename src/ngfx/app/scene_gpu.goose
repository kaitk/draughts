// The scene's passes (scene.goose) in the build that holds both renderers (scripts/ngfx.py
// lays this over src/app/scene_gpu.goose): gfx's recorder (scene_gfx) or goose-ngfx's
// (scene_ngfx), as nx::ngfx_on says.
namespace scene_gpu;
import std;
import vec;

fn sampler() -> gpu::Sampler { return if nx::ngfx_on { scene_ngfx::sampler() } else { scene_gfx::sampler() }; }
fn black() -> gpu::Texture { return if nx::ngfx_on { scene_ngfx::black() } else { scene_gfx::black() }; }
fn shrinker() -> gpu::Pipeline { return if nx::ngfx_on { scene_ngfx::shrinker() } else { scene_gfx::shrinker() }; }
fn blurrer() -> gpu::Pipeline { return if nx::ngfx_on { scene_ngfx::blurrer() } else { scene_gfx::blurrer() }; }
fn fader() -> gpu::Pipeline { return if nx::ngfx_on { scene_ngfx::fader() } else { scene_gfx::fader() }; }
fn done(p: gpu::Pipeline) { if nx::ngfx_on { scene_ngfx::done(p); } else { scene_gfx::done(p); } }
fn begin(dst: gpu::Texture, clear: bool) { if nx::ngfx_on { scene_ngfx::begin(dst, clear); } else { scene_gfx::begin(dst, clear); } }
fn end() { if nx::ngfx_on { scene_ngfx::end(); } else { scene_gfx::end(); } }

fn shrink(p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, from: float4, to: float4) {
    if nx::ngfx_on { scene_ngfx::shrink(p, sampler, src, from, to); } else { scene_gfx::shrink(p, sampler, src, from, to); }
}

fn blur(p: gpu::Pipeline, sampler: gpu::Sampler, src: gpu::Texture, dst: gpu::Texture, dir: float4) {
    if nx::ngfx_on { scene_ngfx::blur(p, sampler, src, dst, dir); } else { scene_gfx::blur(p, sampler, src, dst, dir); }
}

fn fade(p: gpu::Pipeline, to: float4, top: float4, low: float4, light: float4) {
    if nx::ngfx_on { scene_ngfx::fade(p, to, top, low, light); } else { scene_gfx::fade(p, to, top, low, light); }
}

fn let_go(t: gpu::Texture) { if nx::ngfx_on { scene_ngfx::let_go(t); } else { scene_gfx::let_go(t); } }
