// goose-ngfx's calls on gfx's handle types, for the ngfx recorders of the build that holds
// both renderers (scripts/ngfx.py). The drawers hold one type of handle, gfx's: a texture,
// sampler, pipeline, or buffer is an id into the tables of the renderer chosen at start
// (ngfx_on), and both renderers' handles are an id alone. Only what takes or makes a
// handle is here; the rest of goose-ngfx is called as it is. In the render3d package, which
// the app's recorders see too.
namespace nx;
import std;
import vec;
import gfx;
import ngfx;

// Whether ngfx draws, else gfx: set once at start (host_gpu::open), read by every facade.
var ngfx_on = false;

type Texture = gfx::Texture;
type Sampler = gfx::Sampler;
type Pipeline = gfx::Pipeline;
type Buffer = gfx::Buffer;

// The other way, ngfx's handle for a gfx-typed one, and back.
fn n(t: Texture) -> ngfx::Texture { ngfx::Texture { t.id } }
fn n(s: Sampler) -> ngfx::Sampler { ngfx::Sampler { s.id } }
fn n(p: Pipeline) -> ngfx::Pipeline { ngfx::Pipeline { p.id } }
fn n(b: Buffer) -> ngfx::Buffer { ngfx::Buffer { b.id } }
fn g(t: ngfx::Texture) -> Texture { gfx::Texture { t.id } }
fn g(s: ngfx::Sampler) -> Sampler { gfx::Sampler { s.id } }
fn g(p: ngfx::Pipeline) -> Pipeline { gfx::Pipeline { p.id } }
fn g(b: ngfx::Buffer) -> Buffer { gfx::Buffer { b.id } }

// ngfx::PassDesc with gfx's handles.
struct PassDesc {
    color:       Texture[4] = [gfx::Texture { 0 }; 4],
    depth:       Texture    = gfx::Texture { 0 },
    layer:       i32        = 0,
    mip:         i32        = 0,
    clear_color: bool       = true,
    clear_depth: bool       = true,
    color_value: float4     = float4 { 0.0, 0.0, 0.0, 1.0 },
    depth_value: f32        = 1.0,
    resolve:     Texture[4] = [gfx::Texture { 0 }; 4],
}

fn desc(d: PassDesc) -> ngfx::PassDesc {
    var r = ngfx::PassDesc { depth: n(d.depth), layer: d.layer, mip: d.mip, clear_color: d.clear_color,
                             clear_depth: d.clear_depth, color_value: d.color_value, depth_value: d.depth_value };
    for i in 4 {
        r.color[i] = n(d.color[i]);
        r.resolve[i] = n(d.resolve[i]);
    }
    return r;
}

fn begin_pass(d: PassDesc) -> bool { ngfx::begin_pass(desc(d)) }
fn begin_pass(target: Texture, depth: Texture, clear: float4) -> bool { ngfx::begin_pass(n(target), n(depth), clear) }
fn prepare(p: Pipeline, d: PassDesc) -> bool { ngfx::prepare(n(p), desc(d)) }
fn prepare(p: Pipeline, target: Texture, depth: Texture) -> bool { ngfx::prepare(n(p), n(target), n(depth)) }

fn screen() -> Texture { g(ngfx::screen()) }
fn texture(desc: ngfx::TextureDesc) -> Texture { g(ngfx::texture(desc)) }
fn texture2d(width: i64, height: i64, format: i32, usage: i32) -> Texture { g(ngfx::texture2d(width, height, format, usage)) }
fn texture2d(width: i64, height: i64) -> Texture { g(ngfx::texture2d(width, height)) }
fn render_target(width: i64, height: i64, format: i32) -> Texture { g(ngfx::render_target(width, height, format)) }
fn update_texture(t: Texture, data: const u8[:]) -> bool { ngfx::update_texture(n(t), data) }
fn read_texture(t: Texture, px: u8[>..]&) -> bool { ngfx::read_texture(n(t), px) }
fn read_pixels(t: Texture) -> u8[>..] { ngfx::read_pixels(n(t)) }
fn texture_info(t: Texture) -> ngfx::TextureDesc { ngfx::texture_info(n(t)) }
fn index(t: Texture) -> u32 { ngfx::index(n(t)) }
fn index(s: Sampler) -> u32 { ngfx::index(n(s)) }
fn release(t: Texture) { ngfx::release(n(t)); }
fn release(s: Sampler) { ngfx::release(n(s)); }
fn release(p: Pipeline) { ngfx::release(n(p)); }
fn release(b: Buffer) { ngfx::release(n(b)); }

fn sampler(desc: ngfx::SamplerDesc) -> Sampler { g(ngfx::sampler(desc)) }
fn sampler(filter: i32, wrap: i32) -> Sampler { g(ngfx::sampler(filter, wrap)) }
fn shadow_sampler() -> Sampler { g(ngfx::shadow_sampler()) }

fn pipeline(shader: const u8[:], vertex: const u8[:], fragment: const u8[:], desc: ngfx::PipelineDesc) -> Pipeline {
    g(ngfx::pipeline(shader, vertex, fragment, desc))
}
fn pipeline(shader: const u8[:], desc: ngfx::PipelineDesc) -> Pipeline { g(ngfx::pipeline(shader, desc)) }
fn pipeline(shader: const u8[:]) -> Pipeline { g(ngfx::pipeline(shader)) }
fn bind(p: Pipeline) { ngfx::bind(n(p)); }

fn buffer(data: const u8[:]) -> Buffer { g(ngfx::buffer(data)) }
fn buffer(size: i64, data: const u8[:]) -> Buffer { g(ngfx::buffer(size, data)) }
fn update_buffer(b: Buffer, data: const u8[:]) -> bool { ngfx::update_buffer(n(b), data) }
fn address(b: Buffer) -> u64 { ngfx::address(n(b)) }
fn draw_indexed(root: u64, indices: Buffer, index_size: i64, count: i64) {
    ngfx::draw_indexed(root, n(indices), index_size, count);
}
fn draw_indexed_instanced(root: u64, indices: Buffer, index_size: i64, count: i64, instances: i64) {
    ngfx::draw_indexed_instanced(root, n(indices), index_size, count, instances);
}
