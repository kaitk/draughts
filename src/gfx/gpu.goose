// The renderer's handles, and gfx's backend. The drawers hold these handle types and take
// a backend `be`, calling the functions below on it (`be.flush()`) and each recorder on
// its field (`be.draw.board(...)`), resolved by be's type at compile time. goose-ngfx's
// backend is gpu_ngfx::Ngfx (src/ngfx/).
// The entry of the package src/gfx/, which the roots declare as gpu (a package can't be
// named gfx, goose_gfx's name); the gfx-only root imports its backend.goose, the seam.
namespace gpu;
import std;
import vec;
import gfx;
import .draw_gpu;
import .scene_gpu;
import .widgets_gpu;
import .host_gpu;

type Texture = gfx::Texture;
type Sampler = gfx::Sampler;
type Pipeline = gfx::Pipeline;
type Buffer = gfx::Buffer;

fn no_texture() -> Texture { gfx::Texture { 0 } }

struct Gfx {
    draw:    draw_gpu::Gpu,
    widgets: widgets_gpu::Gpu,
    scene:   scene_gpu::Gpu,
    r3d:     render3d::Own,
    host:    host_gpu::Host,
}

fn release(b: Gfx&, t: Texture) { gfx::release(t); }
fn release(b: Gfx&, s: Sampler) { gfx::release(s); }

// Passes have no depth target.
fn screen(b: Gfx&) -> Texture { gfx::screen() }
fn begin_pass(b: Gfx&, t: Texture, clear: float4) { gfx::begin_pass(t, gfx::Texture { 0 }, clear); }
fn end_pass(b: Gfx&) { gfx::end_pass(); }

fn target(b: Gfx&, width: i64, height: i64) -> Texture { gfx::render_target(width, height, gfx::RGBA8) }

fn texture_r8(b: Gfx&, width: i64, height: i64, px: const u8[:]) -> Texture {
    let t = gfx::texture2d(width, height, gfx::R8, gfx::SAMPLED);
    gfx::update_texture(t, px);
    return t;
}

// RGBA8; false if it can't.
fn read_texture(b: Gfx&, t: Texture, px: u8[>..]&) -> bool { gfx::read_texture(t, px) }

// Submits what is drawn and waits for the GPU.
fn flush(b: Gfx&) { gfx::flush(); }

// Where the bench's pulse phase draws its passes: the screen, kept apart from the window.
fn bench_target(b: Gfx&, t: Texture&, size: int2) -> Texture { gfx::screen() }

// The full-screen triangle's vertex shader (render3d's), which gfx's board, scene, and
// widgets passes share.
fn full_vert() -> const u8[:] { embed_shader("vert", shaders::FULL_VERT) }
