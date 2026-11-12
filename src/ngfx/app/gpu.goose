// The renderer's handles and the few calls every drawer makes, in the build that holds
// both renderers (scripts/ngfx.py lays this over src/app/gpu.goose): each call goes to
// gfx's (gpu_gfx, src/app/gpu.goose compiled under that name) or goose-ngfx's (gpu_ngfx),
// as nx::ngfx_on says, set once at start (host_gpu::open). The handles are gfx's types; under
// ngfx they hold ngfx's ids (nx).
namespace gpu;
import std;
import vec;
import gfx;

type Texture = gfx::Texture;
type Sampler = gfx::Sampler;
type Pipeline = gfx::Pipeline;
type Buffer = gfx::Buffer;

fn no_texture() -> Texture { gfx::Texture { 0 } }

fn release(t: Texture) { if nx::ngfx_on { gpu_ngfx::release(t); } else { gpu_gfx::release(t); } }
fn release(s: Sampler) { if nx::ngfx_on { gpu_ngfx::release(s); } else { gpu_gfx::release(s); } }

fn screen() -> Texture { return if nx::ngfx_on { gpu_ngfx::screen() } else { gpu_gfx::screen() }; }
fn begin_pass(t: Texture, clear: float4) { if nx::ngfx_on { gpu_ngfx::begin_pass(t, clear); } else { gpu_gfx::begin_pass(t, clear); } }
fn end_pass() { if nx::ngfx_on { gpu_ngfx::end_pass(); } else { gpu_gfx::end_pass(); } }

fn target(width: i64, height: i64) -> Texture {
    return if nx::ngfx_on { gpu_ngfx::target(width, height) } else { gpu_gfx::target(width, height) };
}

fn texture_r8(width: i64, height: i64, px: const u8[:]) -> Texture {
    return if nx::ngfx_on { gpu_ngfx::texture_r8(width, height, px) } else { gpu_gfx::texture_r8(width, height, px) };
}

fn read_texture(t: Texture, px: u8[>..]&) -> bool {
    return if nx::ngfx_on { gpu_ngfx::read_texture(t, px) } else { gpu_gfx::read_texture(t, px) };
}

fn flush() { if nx::ngfx_on { gpu_ngfx::flush(); } else { gpu_gfx::flush(); } }

// gfx's alone: ngfx's passes have their own full-screen vertex shader in each blob.
fn full_vert() -> const u8[:] { gpu_gfx::full_vert() }

fn bench_target(t: Texture&, size: int2) -> Texture {
    return if nx::ngfx_on { gpu_ngfx::bench_target(t, size) } else { gpu_gfx::bench_target(t, size) };
}
