// The renderer's handles and the few calls every drawer makes, for gfx; the goose-ngfx
// build's src/ngfx/app/gpu.goose takes this file's place. The drawers' renderer-free
// halves (scene, draw, widgets, ...) hold these types and leave every GPU call to their
// `_gpu` recorders, one per renderer.
namespace gpu;
import std;
import vec;
import gfx;

type Texture = gfx::Texture;
type Sampler = gfx::Sampler;
type Pipeline = gfx::Pipeline;
type Buffer = gfx::Buffer;

fn no_texture() -> Texture { gfx::Texture { 0 } }

fn release(t: Texture) { gfx::release(t); }
fn release(s: Sampler) { gfx::release(s); }

// A texture the passes draw into, RGBA8.
fn target(width: i64, height: i64) -> Texture { gfx::render_target(width, height, gfx::RGBA8) }

// A texture of one channel, sampled, holding px.
fn texture_r8(width: i64, height: i64, px: const u8[:]) -> Texture {
    let t = gfx::texture2d(width, height, gfx::R8, gfx::SAMPLED);
    gfx::update_texture(t, px);
    return t;
}

// Texture t's pixels read back into px, RGBA8; false if it can't.
fn read_texture(t: Texture, px: u8[>..]&) -> bool { gfx::read_texture(t, px) }

// Submits what is drawn and waits for the GPU.
fn flush() { gfx::flush(); }

// The full-screen triangle's vertex shader (render3d's), which the board's, the scene's,
// and the widgets' full-screen passes share.
fn full_vert() -> const u8[:] { embed_shader("vert", shaders::FULL_VERT) }
