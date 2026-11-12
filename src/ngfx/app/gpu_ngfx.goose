// The few calls every drawer makes, for goose-ngfx, beside gfx's src/app/gpu.goose in the
// build that holds both (scripts/ngfx.py; gpu.goose there picks one). Handles are gfx's
// types (nx).
namespace gpu_ngfx;
import std;
import vec;
import ngfx;

type Texture = nx::Texture;
type Sampler = nx::Sampler;
type Pipeline = nx::Pipeline;
type Buffer = nx::Buffer;

fn no_texture() -> Texture { nx::Texture { 0 } }

fn release(t: Texture) { nx::release(t); }
fn release(s: Sampler) { nx::release(s); }

// The screen's texture, and a pass into texture t cleared to `clear`, with no depth
// target, and its end.
fn screen() -> Texture { nx::screen() }
fn begin_pass(t: Texture, clear: float4) { nx::begin_pass(t, nx::Texture { 0 }, clear); }
fn end_pass() { ngfx::end_pass(); }

// A texture the passes draw into, RGBA8.
fn target(width: i64, height: i64) -> Texture { nx::render_target(width, height, ngfx::RGBA8) }

// A texture of one channel, sampled, holding px.
fn texture_r8(width: i64, height: i64, px: const u8[:]) -> Texture {
    let t = nx::texture2d(width, height, ngfx::R8, ngfx::SAMPLED);
    nx::update_texture(t, px);
    return t;
}

// Texture t's pixels read back into px, RGBA8; false if it can't.
fn read_texture(t: Texture, px: u8[>..]&) -> bool { nx::read_texture(t, px) }

// Submits what is drawn and waits for the GPU.
fn flush() { ngfx::flush(); }

// Where the bench's pulse phase draws its passes: a texture the screen's size, made in t
// once, as the screen is the window's image, which each flush would show without the UI.
fn bench_target(t: Texture&, size: int2) -> Texture {
    if t.id == 0 { t = nx::render_target(size.x, size.y, ngfx::BGRA8); }
    return t;
}
