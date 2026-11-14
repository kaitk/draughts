// The renderer's handles, and gfx's backend: what the drawers record through. The drawers
// (scene, draw, widgets, draw3d, render3d) hold these handle types, renderer-free, and take
// a backend `be` that they call: the few calls below on it (`be.flush()`), and each
// recorder on its field (`be.draw.board(...)`, draw_gpu.goose's on gfx). Each such call
// resolves by be's type at compile time; goose-ngfx's backend is gpu_ngfx::Ngfx
// (src/ngfx/), and backend::with picks one (src/app/backend.goose).
namespace gpu;
import std;
import vec;
import gfx;

type Texture = gfx::Texture;
type Sampler = gfx::Sampler;
type Pipeline = gfx::Pipeline;
type Buffer = gfx::Buffer;

fn no_texture() -> Texture { gfx::Texture { 0 } }

// gfx's backend: each recorder's state, the 3D board's what only gfx holds, and the
// window's half.
struct Gfx {
    draw:    draw_gpu::Gpu,
    widgets: widgets_gpu::Gpu,
    scene:   scene_gpu::Gpu,
    r3d:     render3d::Own,
    host:    host_gpu::Host,
}

fn release(b: Gfx&, t: Texture) { gfx::release(t); }
fn release(b: Gfx&, s: Sampler) { gfx::release(s); }

// The screen's texture, and a pass into texture t cleared to `clear`, with no depth
// target, and its end.
fn screen(b: Gfx&) -> Texture { gfx::screen() }
fn begin_pass(b: Gfx&, t: Texture, clear: float4) { gfx::begin_pass(t, gfx::Texture { 0 }, clear); }
fn end_pass(b: Gfx&) { gfx::end_pass(); }

// A texture the passes draw into, RGBA8.
fn target(b: Gfx&, width: i64, height: i64) -> Texture { gfx::render_target(width, height, gfx::RGBA8) }

// A texture of one channel, sampled, holding px.
fn texture_r8(b: Gfx&, width: i64, height: i64, px: const u8[:]) -> Texture {
    let t = gfx::texture2d(width, height, gfx::R8, gfx::SAMPLED);
    gfx::update_texture(t, px);
    return t;
}

// Texture t's pixels read back into px, RGBA8; false if it can't.
fn read_texture(b: Gfx&, t: Texture, px: u8[>..]&) -> bool { gfx::read_texture(t, px) }

// Submits what is drawn and waits for the GPU.
fn flush(b: Gfx&) { gfx::flush(); }

// Where the bench's pulse phase draws its passes: the screen, kept apart from the window.
fn bench_target(b: Gfx&, t: Texture&, size: int2) -> Texture { gfx::screen() }

// The full-screen triangle's vertex shader (render3d's), which gfx's board, scene, and
// widgets passes share.
fn full_vert() -> const u8[:] { embed_shader("vert", shaders::FULL_VERT) }
