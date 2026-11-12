// Recording the UI's quads (widgets.goose) through goose-ngfx, beside gfx's
// src/app/widgets_gpu.goose in the build that holds both (scripts/ngfx.py): its shaders, written from that file's GLSL
// (scripts/ngfx_2d_shaders.py) and built ahead, and the quads copied into each frame's
// memory that draws them as they come, an instanced draw per run of one pipeline pulling
// them from there.
namespace widgets_ngfx;
import std;
import vec;
import ngfx;

import gui from "../gui";

// The quads' root (ui_base, ui_icons, and ui_faces alike) and compose's, as their
// shaders' headers lay them out; `first`, the run's first quad, is the one field gfx's
// shaders have no block for: gfx draws from a first instance, which SV_InstanceID leaves
// out.
struct Root {
    quads: u64,
    glass: u32, atlas: u32, thumbs: u32, badges: u32, smp: u32, first: u32,
    view:  widgets::View,
    theme: theme::Theme,
}
struct ComposeRoot { layer: u32, smp: u32, pad0: u32, pad1: u32 }

struct Gpu {
    pipelines: nx::Pipeline[3],
    addr:      u64,              // this frame's quads in its memory
    compose:   nx::Pipeline,
}

fn new() -> Gpu {
    let desc = ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED };
    return Gpu { pipelines: [nx::pipeline(embed_file("shaders/ui_base.blob"), desc),
                             nx::pipeline(embed_file("shaders/ui_icons.blob"), desc),
                             nx::pipeline(embed_file("shaders/ui_faces.blob"), desc)],
                 addr: 0, compose: nx::pipeline(embed_file("shaders/compose.blob"), desc) };
}

// Nothing: the quads go into each frame's memory.
fn buffers(g: Gpu&, all: const gui::Quad[:]) {}

// The first n of `all` into this frame's memory, changed or not: each frame that draws
// them, as they come or into the kept layer, takes them anew.
fn quads(g: Gpu&, all: const gui::Quad[:], n: i64, changed: bool) { g.addr = ngfx::frame_data(bytes_of(all[..n])); }

fn begin_layer(layer: gpu::Texture) { nx::begin_pass(layer, nx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 0.0 }); }

// Ends the layer's pass, what it wrote made visible to the screen's pass that samples it.
fn end_layer() {
    ngfx::end_pass();
    ngfx::barrier(ngfx::TARGET_WRITE, ngfx::FRAGMENT_READ);
}

fn compose(g: Gpu&, layer: gpu::Texture, sampler: gpu::Sampler) {
    nx::bind(g.compose);
    ngfx::draw(ngfx::root(ComposeRoot { layer: nx::index(layer), smp: nx::index(sampler), pad0: 0, pad1: 0 }), 3);
}

fn run(g: Gpu&, p: i64, first: i64, count: i64, s: scene::Scene&, t: theme::Theme, view: widgets::View,
       atlas: gpu::Texture, thumbs: gpu::Texture, badges: gpu::Texture) {
    nx::bind(g.pipelines[p]);
    ngfx::draw_instanced(ngfx::root(Root { quads: g.addr, glass: nx::index(s.glass), atlas: nx::index(atlas),
                                           thumbs: nx::index(thumbs), badges: nx::index(badges),
                                           smp: nx::index(s.sampler), first: first as u32, view: view, theme: t }),
                         6, count);
}
