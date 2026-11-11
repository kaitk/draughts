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

// Submits what is drawn and waits for the GPU.
fn flush() { ngfx::flush(); }
