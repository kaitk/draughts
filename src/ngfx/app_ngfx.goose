// The app's backend for goose-ngfx, beside gfx's gpu::Gfx (src/gfx/gpu.goose): each
// recorder's state, the 3D board's what only ngfx holds, the window's half, and the few
// calls the drawers make on the backend itself. backend.goose imports it, so a program
// that draws the 3D scene alone (tools/light_tune_ngfx.goose) leaves the app's drawers out.
namespace gpu_ngfx;
import std;
import vec;
import ngfx;
import .draw_ngfx;
import .scene_ngfx;
import .widgets_ngfx;

struct Ngfx {
    draw:    draw_ngfx::Gpu,
    widgets: widgets_ngfx::Gpu,
    scene:   scene_ngfx::Gpu,
    r3d:     render3d_ngfx::Own,
    host:    host_ngfx::Host,
}

fn release(b: Ngfx&, t: gpu::Texture) { nx::release(t); }
fn release(b: Ngfx&, s: gpu::Sampler) { nx::release(s); }

// The screen's texture, and a pass into texture t cleared to `clear`, with no depth
// target, and its end.
fn screen(b: Ngfx&) -> gpu::Texture { nx::screen() }
fn begin_pass(b: Ngfx&, t: gpu::Texture, clear: float4) { nx::begin_pass(t, nx::Texture { 0 }, clear); }
fn end_pass(b: Ngfx&) { ngfx::end_pass(); }

// A texture the passes draw into, RGBA8.
fn target(b: Ngfx&, width: i64, height: i64) -> gpu::Texture { nx::render_target(width, height, ngfx::RGBA8) }

// A texture of one channel, sampled, holding px.
fn texture_r8(b: Ngfx&, width: i64, height: i64, px: const u8[:]) -> gpu::Texture {
    let t = nx::texture2d(width, height, ngfx::R8, ngfx::SAMPLED);
    nx::update_texture(t, px);
    return t;
}

// Texture t's pixels read back into px, RGBA8; false if it can't.
fn read_texture(b: Ngfx&, t: gpu::Texture, px: u8[>..]&) -> bool { nx::read_texture(t, px) }

// Submits what is drawn and waits for the GPU.
fn flush(b: Ngfx&) { ngfx::flush(); }

// Where the bench's pulse phase draws its passes: a texture the screen's size, made in t
// once, as the screen is the window's image, which each flush would show without the UI.
fn bench_target(b: Ngfx&, t: gpu::Texture&, size: int2) -> gpu::Texture {
    if t.id == 0 { t = nx::render_target(size.x, size.y, ngfx::BGRA8); }
    return t;
}
