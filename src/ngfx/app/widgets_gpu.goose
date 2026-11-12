// The UI's quads (widgets.goose) in the build that holds both renderers (scripts/ngfx.py
// lays this over src/app/widgets_gpu.goose): gfx's recorder (widgets_gfx) or goose-ngfx's
// (widgets_ngfx), as nx::ngfx_on says, each holding its own state.
namespace widgets_gpu;
import std;
import vec;

import gui from "../gui";

// The chosen renderer's half is made; the other stays empty.
struct Gpu {
    gfx_gpu:  widgets_gfx::Gpu,
    ngfx_gpu: widgets_ngfx::Gpu,
}

fn new() -> Gpu {
    if nx::ngfx_on { return Gpu { gfx_gpu: default<widgets_gfx::Gpu>(), ngfx_gpu: widgets_ngfx::new() }; }
    return Gpu { gfx_gpu: widgets_gfx::new(), ngfx_gpu: default<widgets_ngfx::Gpu>() };
}

fn buffers(g: Gpu&, all: const gui::Quad[:]) {
    if nx::ngfx_on { widgets_ngfx::buffers(g.ngfx_gpu, all); } else { widgets_gfx::buffers(g.gfx_gpu, all); }
}

fn quads(g: Gpu&, all: const gui::Quad[:], n: i64, changed: bool) {
    if nx::ngfx_on { widgets_ngfx::quads(g.ngfx_gpu, all, n, changed); } else { widgets_gfx::quads(g.gfx_gpu, all, n, changed); }
}

fn begin_layer(layer: gpu::Texture) { if nx::ngfx_on { widgets_ngfx::begin_layer(layer); } else { widgets_gfx::begin_layer(layer); } }
fn end_layer() { if nx::ngfx_on { widgets_ngfx::end_layer(); } else { widgets_gfx::end_layer(); } }

fn compose(g: Gpu&, layer: gpu::Texture, sampler: gpu::Sampler) {
    if nx::ngfx_on { widgets_ngfx::compose(g.ngfx_gpu, layer, sampler); } else { widgets_gfx::compose(g.gfx_gpu, layer, sampler); }
}

fn run(g: Gpu&, p: i64, first: i64, count: i64, s: scene::Scene&, t: theme::Theme, view: widgets::View,
       atlas: gpu::Texture, thumbs: gpu::Texture, badges: gpu::Texture) {
    if nx::ngfx_on {
        widgets_ngfx::run(g.ngfx_gpu, p, first, count, s, t, view, atlas, thumbs, badges);
    } else {
        widgets_gfx::run(g.gfx_gpu, p, first, count, s, t, view, atlas, thumbs, badges);
    }
}
