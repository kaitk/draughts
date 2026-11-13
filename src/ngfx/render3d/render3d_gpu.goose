// The 3D board's recording in the build that holds both renderers (scripts/ngfx.py lays
// this over src/render3d/render3d_gpu.goose): each call render3d.goose and the app make
// goes to gfx's recorder (render3d_gfx, src/render3d/render3d_gpu.goose compiled under that
// name) or goose-ngfx's (render3d_ngfx), as nx::ngfx_on says. The handles and the matrices
// are gfx's types (nx), and the Gpu's `own` gfx's; goose-ngfx's keeps its own.
namespace render3d;
import std;
import vec;
import math;
import gfx;
import .nx;
import .render3d_gfx;
import .render3d_ngfx;

type Texture = gfx::Texture;
type Buffer = gfx::Buffer;
type Sampler = gfx::Sampler;
type Pipeline = gfx::Pipeline;
type Mat = gfx::mat4;
type Own = render3d_gfx::Own;
let RGBA8 = gfx::RGBA8;
let RGBA8_SRGB = gfx::RGBA8_SRGB;

// The math is renderer-free: gfx's.
fn mul(a: Mat, b: Mat) -> Mat { gfx::mul(a, b) }
fn ortho(left: f32, right: f32, bottom: f32, top: f32, near: f32, far: f32) -> Mat {
    gfx::ortho(left, right, bottom, top, near, far)
}
fn look_at(eye: float3, target: float3, up: float3) -> Mat { gfx::look_at(eye, target, up) }

// The antialiasing's ways, numbered alike in both recorders (ngfx's also has AA_SSAA, 3).
let AA_OFF = 0;
let AA_SMAA = 2;
let AA_MSAA = 4;
let AA = AA_MSAA;
// MSAA's samples, and gfx's fewer for a slow device (render3d_gpu.goose's FEW_SAMPLES).
let SAMPLES = 4;
let FEW_SAMPLES = 2;
fn aa_named(name: const u8[:]) -> i32 { return if nx::ngfx_on { render3d_ngfx::aa_named(name) } else { render3d_gfx::aa_named(name) }; }
fn aa_name(aa: i32) -> const u8[:] { return if nx::ngfx_on { render3d_ngfx::aa_name(aa) } else { render3d_gfx::aa_name(aa) }; }
fn aa_next(aa: i32) -> i32 { return if nx::ngfx_on { render3d_ngfx::aa_next(aa) } else { render3d_gfx::aa_next(aa) }; }

fn gpu_flush() { if nx::ngfx_on { render3d_ngfx::gpu_flush(); } else { render3d_gfx::gpu_flush(); } }
fn gpu_release(t: Texture) { if nx::ngfx_on { render3d_ngfx::gpu_release(t); } else { render3d_gfx::gpu_release(t); } }
fn gpu_target(w: i64, h: i64) -> Texture { return if nx::ngfx_on { render3d_ngfx::gpu_target(w, h) } else { render3d_gfx::gpu_target(w, h) }; }
fn gpu_clear(t: Texture, color: float4) { if nx::ngfx_on { render3d_ngfx::gpu_clear(t, color); } else { render3d_gfx::gpu_clear(t, color); } }
fn gpu_release_waited(a: Texture, b: Texture) {
    if nx::ngfx_on { render3d_ngfx::gpu_release_waited(a, b); } else { render3d_gfx::gpu_release_waited(a, b); }
}
fn gpu_update(b: Buffer, bytes: const u8[:]) { if nx::ngfx_on { render3d_ngfx::gpu_update(b, bytes); } else { render3d_gfx::gpu_update(b, bytes); } }
fn gpu_mipped(w: i64, h: i64, format: i32, mips: i64) -> Texture {
    return if nx::ngfx_on { render3d_ngfx::gpu_mipped(w, h, format, mips) } else { render3d_gfx::gpu_mipped(w, h, format, mips) };
}

fn bake(g: Gpu&, albedo: Texture, normal: Texture, w: i64, h: i64, mode: f32, extent: float2, t: looks::Theme&,
        y0: i64 = 0, y1: i64 = -1, mips: bool = true) {
    if nx::ngfx_on {
        render3d_ngfx::bake(g, albedo, normal, w, h, mode, extent, t, y0, y1, mips);
    } else {
        render3d_gfx::bake(g, albedo, normal, w, h, mode, extent, t, y0, y1, mips);
    }
}
fn photo_pipelines(g: Gpu&) { if nx::ngfx_on { render3d_ngfx::photo_pipelines(g); } else { render3d_gfx::photo_pipelines(g); } }
fn photo_part(g: Gpu&, kind: i64, grey: f32, sh: float4[9]&, k: i64) {
    if nx::ngfx_on { render3d_ngfx::photo_part(g, kind, grey, sh, k); } else { render3d_gfx::photo_part(g, kind, grey, sh, k); }
}
fn shadow_pass(g: Gpu&) { if nx::ngfx_on { render3d_ngfx::shadow_pass(g); } else { render3d_gfx::shadow_pass(g); } }
fn board_pass(g: Gpu&, target: Texture, size: int2, backdrop: bool) {
    if nx::ngfx_on { render3d_ngfx::board_pass(g, target, size, backdrop); } else { render3d_gfx::board_pass(g, target, size, backdrop); }
}
fn occ_pass(g: Gpu&, x0: i64, y0: i64, x1: i64, y1: i64) {
    if nx::ngfx_on { render3d_ngfx::occ_pass(g, x0, y0, x1, y1); } else { render3d_gfx::occ_pass(g, x0, y0, x1, y1); }
}
fn kept_pass(g: Gpu&) { if nx::ngfx_on { render3d_ngfx::kept_pass(g); } else { render3d_gfx::kept_pass(g); } }
fn pass_targets(g: Gpu&) { if nx::ngfx_on { render3d_ngfx::pass_targets(g); } else { render3d_gfx::pass_targets(g); } }
fn set_aa(g: Gpu&, aa: i32, samples: i32 = SAMPLES) {
    if nx::ngfx_on { render3d_ngfx::set_aa(g, aa, samples); } else { render3d_gfx::set_aa(g, aa, samples); }
}
fn setup(g: Gpu&, samples: i32 = SAMPLES, look: i32 = SHADOW_9) {
    if nx::ngfx_on { render3d_ngfx::setup(g, render3d_ngfx::AA, look); } else { render3d_gfx::setup(g, samples, look); }
}
fn set_shadow(g: Gpu&, look: i32) { if nx::ngfx_on { render3d_ngfx::set_shadow(g, look); } else { render3d_gfx::set_shadow(g, look); } }
fn draw_depth(g: Gpu&) { if nx::ngfx_on { render3d_ngfx::draw_depth(g); } else { render3d_gfx::draw_depth(g); } }
fn marks_over(g: Gpu&, pulse: float4, next: f32, cursor: f32, to: float4, alpha: f32, size: int2) {
    if nx::ngfx_on {
        render3d_ngfx::marks_over(g, pulse, next, cursor, to, alpha, size);
    } else {
        render3d_gfx::marks_over(g, pulse, next, cursor, to, alpha, size);
    }
}
fn backdrop(g: Gpu&, alpha: f32, size: int2) { if nx::ngfx_on { render3d_ngfx::backdrop(g, alpha, size); } else { render3d_gfx::backdrop(g, alpha, size); } }
fn show(g: Gpu&, from: float4, to: float4, alpha: f32, size: int2, grey: f32 = 0.0) {
    if nx::ngfx_on { render3d_ngfx::show(g, from, to, alpha, size, grey); } else { render3d_gfx::show(g, from, to, alpha, size, grey); }
}
fn warm(g: Gpu&, k: i64) { if nx::ngfx_on { render3d_ngfx::warm(g, k); } else { render3d_gfx::warm(g, k); } }
fn release(g: Gpu&) { if nx::ngfx_on { render3d_ngfx::release(g); } else { render3d_gfx::release(g); } }
