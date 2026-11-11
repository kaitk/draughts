// Recording the UI's quads (widgets.goose) through goose-ngfx, in place of
// src/app/widgets_gpu.goose (scripts/ngfx.py): src/ngfx/shaders/ui.slang and
// compose.slang, built ahead, and the quads copied into each frame's memory that draws
// them as they come, an instanced draw per run of one pipeline pulling them from there.
namespace widgets_gpu;
import std;
import vec;
import ngfx;

import gui from "../gui";

// ui.slang's and compose.slang's roots.
struct Root {
    quads: u64,
    glass: u32, atlas: u32, thumbs: u32, badges: u32, smp: u32, first: u32,
    theme: theme::Theme,
    view:  widgets::View,
}
struct ComposeRoot { layer: u32, pad0: u32, pad1: u32, pad2: u32 }

struct Gpu {
    pipelines: ngfx::Pipeline[3],
    addr:      u64,              // this frame's quads in its memory
    compose:   ngfx::Pipeline,
}

fn new() -> Gpu {
    let desc = ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED };
    return Gpu { pipelines: [ngfx::pipeline(embed_file("shaders/ui_base.blob"), desc),
                             ngfx::pipeline(embed_file("shaders/ui_icons.blob"), desc),
                             ngfx::pipeline(embed_file("shaders/ui_faces.blob"), desc)],
                 addr: 0, compose: ngfx::pipeline(embed_file("shaders/compose.blob"), desc) };
}

// Nothing: the quads go into each frame's memory.
fn buffers(g: Gpu&, all: const gui::Quad[:]) {}

// The first n of `all` into this frame's memory, changed or not: each frame that draws
// them, as they come or into the kept layer, takes them anew.
fn quads(g: Gpu&, all: const gui::Quad[:], n: i64, changed: bool) { g.addr = ngfx::frame_data(bytes_of(all[..n])); }

fn begin_layer(layer: gpu::Texture) { ngfx::begin_pass(layer, ngfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 0.0 }); }

// Ends the layer's pass, what it wrote made visible to the screen's pass that samples it.
fn end_layer() {
    ngfx::end_pass();
    ngfx::barrier(ngfx::TARGET_WRITE, ngfx::FRAGMENT_READ);
}

fn compose(g: Gpu&, layer: gpu::Texture, sampler: gpu::Sampler) {
    ngfx::bind(g.compose);
    ngfx::draw(ngfx::root(ComposeRoot { layer: ngfx::index(layer), pad0: 0, pad1: 0, pad2: 0 }), 3);
}

fn run(g: Gpu&, p: i64, first: i64, count: i64, s: scene::Scene&, t: theme::Theme, view: widgets::View,
       atlas: gpu::Texture, thumbs: gpu::Texture, badges: gpu::Texture) {
    ngfx::bind(g.pipelines[p]);
    ngfx::draw_instanced(ngfx::root(Root { quads: g.addr, glass: ngfx::index(s.glass), atlas: ngfx::index(atlas),
                                           thumbs: ngfx::index(thumbs), badges: ngfx::index(badges),
                                           smp: ngfx::index(s.sampler), first: first as u32, theme: t, view: view }),
                         6, count);
}
