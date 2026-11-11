// Drawing the UI layer's quads (gui/) through goose-ngfx (task 065; src/app/widgets.goose
// is gfx's, whose comments say what each part is for): the quads in this frame's memory
// and an instanced draw per run of one pipeline, each quad a signed-distance shape
// (src/ngfx/shaders/ui.slang); kept in a layer the screen's size while it stands still.
namespace widgets;
import std;
import vec;
import ngfx;

import gui from "../gui";
import .scene;
import .theme;
import badges from "../badges";

struct View { screen: float4, hole: float4, clip: float4 }

// ui.slang's and compose.slang's roots.
struct Root {
    quads: u64,
    glass: u32, atlas: u32, thumbs: u32, badges: u32, smp: u32, first: u32,
    theme: theme::Theme,
    view: View,
}
struct ComposeRoot { layer: u32, pad0: u32, pad1: u32, pad2: u32 }

struct Widgets {
    pipelines: ngfx::Pipeline[3],
    addr:      u64,              // this frame's quads in its memory
    upload:    gui::Quad[gui::MAX_QUADS],
    atlas:     ngfx::Texture,
    thumbs:    ngfx::Texture,
    badges:    ngfx::Texture,
    compose:   ngfx::Pipeline,
    layer:     ngfx::Texture,
    layer_w:   i64,
    layer_h:   i64,
    count:     i64,
    view:      View,
    theme:     theme::Theme,
    ids:       i64[4],
    kept:      bool,
    stale:     bool,
    live:      bool,
}

fn new() -> Widgets {
    let desc = ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED };
    var w = Widgets {
        pipelines: [ngfx::pipeline(embed_file("shaders/ui_base.blob"), desc),
                    ngfx::pipeline(embed_file("shaders/ui_icons.blob"), desc),
                    ngfx::pipeline(embed_file("shaders/ui_faces.blob"), desc)],
        addr:    0,
        upload:  [gui::Quad {}; gui::MAX_QUADS],
        atlas:   ngfx::Texture { 0 },
        thumbs:  ngfx::Texture { 0 },
        badges:  ngfx::Texture { 0 },
        compose: ngfx::pipeline(embed_file("shaders/compose.blob"), desc),
        layer:   ngfx::Texture { 0 },
        layer_w: 0,
        layer_h: 0,
        count:   -1,
        view:    default<View>(),
        theme:   default<theme::Theme>(),
        ids:     [0, 0, 0, 0],
        kept:    false,
        stale:   true,
        live:    false,
    };
    w.badges = bake_badges();
    return w;
}

fn bake_badges() -> ngfx::Texture {
    let px = badges::atlas();
    let t = ngfx::texture2d(badges::CELL, badges::COUNT * badges::CELL, ngfx::R8, ngfx::SAMPLED);
    ngfx::update_texture(t, px[..]);
    return t;
}

// Before the frame's passes: the quads copied when they changed, into this frame's memory
// whenever they are drawn as they come, or drawn once into the kept layer.
fn prepare(w: Widgets&, quads: const gui::Quad[:], clip: float4, s: scene::Scene&, t: theme::Theme, width: f32,
           height: f32, hole: float4, tall: f32 = 0.0) {
    let n = quads.len;
    let view = view_of(clip, s, width, height, hole, tall);
    let ids: i64[4] = [s.glass.id, w.atlas.id, w.thumbs.id, w.badges.id];
    var same = !w.stale && n == w.count && same_bytes(bytes_of([view]), bytes_of([w.view]))
               && same_bytes(bytes_of([t]), bytes_of([w.theme]));
    for i in 4 { if ids[i] != w.ids[i] { same = false; } }
    if same && n > 0 { same = same_bytes(bytes_of(quads[..n]), bytes_of(w.upload[..n])); }
    if !same {
        for i in n { w.upload[i] = quads[i]; }
        w.count = n;
        w.view = view;
        w.theme = t;
        w.ids = ids;
        w.stale = false;
        w.kept = false;
        if n > 0 { w.addr = ngfx::frame_data(bytes_of(w.upload[..n])); }
        return;
    }
    guard !w.kept && n > 0 else { return; }
    w.addr = ngfx::frame_data(bytes_of(w.upload[..n]));
    guard !w.live else { return; }
    let lw = width as i64;
    let lh = height as i64;
    if w.layer.id == 0 || w.layer_w != lw || w.layer_h != lh {
        if w.layer.id != 0 { ngfx::release(w.layer); }
        w.layer = ngfx::render_target(lw, lh, ngfx::RGBA8);
        w.layer_w = lw;
        w.layer_h = lh;
    }
    ngfx::begin_pass(w.layer, ngfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 0.0 });
    draw_quads(w, n, s, t, view);
    ngfx::end_pass();
    ngfx::barrier(ngfx::TARGET_WRITE, ngfx::FRAGMENT_READ);
    w.kept = true;
}

fn frame(w: Widgets&, quads: const gui::Quad[:], clip: float4, s: scene::Scene&, t: theme::Theme, width: f32,
         height: f32, hole: float4, tall: f32 = 0.0) {
    guard quads.len > 0 else { return; }
    if w.kept {
        ngfx::bind(w.compose);
        ngfx::draw(ngfx::root(ComposeRoot { layer: ngfx::index(w.layer), pad0: 0, pad1: 0, pad2: 0 }), 3);
        return;
    }
    draw_quads(w, quads.len, s, t, view_of(clip, s, width, height, hole, tall));
}

fn view_of(clip: float4, s: scene::Scene&, width: f32, height: f32, hole: float4, tall: f32) -> View {
    let behind: f32 = if s.plain { 2.0 } else if s.has { 1.0 } else { 0.0 };
    return View { screen: float4 { width, height, behind, tall }, hole: hole, clip: clip };
}

fn same_bytes(a: const u8[:], b: const u8[:]) -> bool {
    guard a.len == b.len else { return false; }
    for i in a.len { if a[i] != b[i] { return false; } }
    return true;
}

fn atlas(w: Widgets&, px: const u8[:], size: int2) {
    if w.atlas.id != 0 { ngfx::release(w.atlas); }
    w.atlas = ngfx::texture2d(size.x, size.y, ngfx::R8, ngfx::SAMPLED);
    ngfx::update_texture(w.atlas, px);
    w.stale = true;
}

fn draw_quads(w: Widgets&, n: i64, s: scene::Scene&, t: theme::Theme, view: View) {
    let glass = ngfx::index(s.glass);
    var r = Root { quads: w.addr, glass: glass,
                   atlas: if w.atlas.id != 0 { ngfx::index(w.atlas) } else { glass },
                   thumbs: if w.thumbs.id != 0 { ngfx::index(w.thumbs) } else { glass },
                   badges: ngfx::index(w.badges), smp: ngfx::index(s.sampler), first: 0, theme: t, view: view };
    var start = 0;
    while start < n {
        let p = pipeline_of(w.upload[start]);
        var end = start + 1;
        while end < n && pipeline_of(w.upload[end]) == p { end++; }
        ngfx::bind(w.pipelines[p]);
        r.first = start as u32;
        ngfx::draw_instanced(ngfx::root(r), 6, end - start);
        start = end;
    }
}

fn pipeline_of(q: gui::Quad) -> i64 {
    let kind = q.look.x as i64;
    return if kind == gui::ICON { 1 } else if kind == gui::FACE { 2 } else { 0 };
}
