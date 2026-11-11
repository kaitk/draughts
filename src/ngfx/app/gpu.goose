// The renderer's handles and the few calls every drawer makes, for goose-ngfx, in place of
// src/app/gpu.goose (scripts/ngfx.py).
namespace gpu;
import std;
import vec;
import ngfx;

type Texture = ngfx::Texture;
type Sampler = ngfx::Sampler;
type Pipeline = ngfx::Pipeline;
type Buffer = ngfx::Buffer;

fn no_texture() -> Texture { ngfx::Texture { 0 } }

fn release(t: Texture) { ngfx::release(t); }
fn release(s: Sampler) { ngfx::release(s); }

// A texture the passes draw into, RGBA8.
fn target(width: i64, height: i64) -> Texture { ngfx::render_target(width, height, ngfx::RGBA8) }

// A texture of one channel, sampled, holding px.
fn texture_r8(width: i64, height: i64, px: const u8[:]) -> Texture {
    let t = ngfx::texture2d(width, height, ngfx::R8, ngfx::SAMPLED);
    ngfx::update_texture(t, px);
    return t;
}

// Texture t's pixels read back into px, RGBA8; false if it can't.
fn read_texture(t: Texture, px: u8[>..]&) -> bool { ngfx::read_texture(t, px) }

// Submits what is drawn and waits for the GPU.
fn flush() { ngfx::flush(); }
