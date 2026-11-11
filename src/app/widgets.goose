// Drawing the UI layer's quads (gui/): one storage buffer of quads and one instanced
// draw, each quad worked out in the fragment shader as a signed-distance shape
// (docs/architecture/rendering.md, "UI layer", "Scene and glass", "Controls"). What is
// drawn and when is this file's; the shaders and GPU calls are the renderer's
// (widgets_gpu.goose).
namespace widgets;
import std;
import vec;

import gui from "../gui";
import .scene;
import .theme;
import badges from "../badges";

// width, height in pixels, z: 1 when there is a photograph, w: the hole's height (0 as
// tall as wide); and the board's rect (x, y, size, corner radius) where a transition
// hides the UI, size 0 at rest.
// clip: the scrolling list's view (gui::scroll_begin), where quads marked gui::CLIP show.
struct View { screen: float4, hole: float4, clip: float4 }

struct Widgets {
    gpu:    widgets_gpu::Gpu,  // the pipelines (FRAG's three: the base kinds, the icons, the faces) and the quads on the GPU
    upload: gui::Quad[gui::MAX_QUADS],
    atlas:  gpu::Texture,     // the text's glyphs (text.goose), or 0 before they're baked
    thumbs: gpu::Texture,     // the seasons' thumbnails (scene.goose), or 0 until loaded
    badges: gpu::Texture,     // the badges' animals' distances, baked at start
    // The UI kept while it stands still (prepare()): the last frame's quads (upload, count),
    // view, theme, and textures; the layer they were drawn into, and whether it holds them.
    layer:   gpu::Texture,
    layer_w: i64,
    layer_h: i64,
    count:   i64,
    view:    View,
    theme:   theme::Theme,
    ids:     i64[4],
    kept:    bool,
    stale:   bool,              // something the quads don't show changed (the glyphs baked again)
    live:    bool,              // the app's --keep off: drawn as they come each frame, never kept
}

fn new() -> Widgets {
    var w = Widgets {
        gpu:     widgets_gpu::new(),
        upload:  [gui::Quad {}; gui::MAX_QUADS],
        atlas:   gpu::no_texture(),
        thumbs:  gpu::no_texture(),
        badges:  gpu::no_texture(),
        layer:   gpu::no_texture(),
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
    widgets_gpu::buffers(w.gpu, w.upload);
    w.badges = bake_badges();
    return w;
}

// The badges' animals as badges::atlas bakes them (about 54 KB, a few ms), the distance
// texture the shader carves from, made once at start.
fn bake_badges() -> gpu::Texture {
    let px = badges::atlas();
    return gpu::texture_r8(badges::CELL, badges::COUNT * badges::CELL, px[..]);
}

// Before the frame's passes (copies and passes can't run inside one), with what frame()
// will take: the quads copied to the GPU when they changed. The UI stands still on most
// frames that draw (the board moving, a pulse), and its quads cost a quarter of the 3D
// frame on the Pixel 7a (task 059): once they, the view, the theme, and the textures are
// the same as the last frame's, they are drawn once into a layer the screen's size,
// which frame() then lays with a fetch a pixel. While they change, frame() draws them as
// they come, so a moving UI pays no layer.
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
        if n > 0 { widgets_gpu::quads(w.gpu, w.upload, n, true); }
        w.count = n;
        w.view = view;
        w.theme = t;
        w.ids = ids;
        w.stale = false;
        w.kept = false;
        return;
    }
    guard !w.kept && n > 0 else { return; }
    widgets_gpu::quads(w.gpu, w.upload, n, false);
    guard !w.live else { return; }
    let lw = width as i64;
    let lh = height as i64;
    if w.layer.id == 0 || w.layer_w != lw || w.layer_h != lh {
        if w.layer.id != 0 { gpu::release(w.layer); }
        w.layer = gpu::target(lw, lh);
        w.layer_w = lw;
        w.layer_h = lh;
    }
    widgets_gpu::begin_layer(w.layer);
    draw_quads(w, n, s, t, view);
    widgets_gpu::end_layer();
    w.kept = true;
}

// Draws the frame's quads in the open pass, over what is there, none inside `hole` but
// those on the board (gui::on_board), `tall` pixels tall (0: as tall as wide): the kept
// layer when prepare() drew them into it.
fn frame(w: Widgets&, quads: const gui::Quad[:], clip: float4, s: scene::Scene&, t: theme::Theme, width: f32,
         height: f32, hole: float4, tall: f32 = 0.0) {
    guard quads.len > 0 else { return; }
    if w.kept {
        widgets_gpu::compose(w.gpu, w.layer, s.sampler);
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

// The text's coverage, R8, `size` texels, as the UI's glyph texture in place of the last
// (text::bake): the quads drawn again.
fn atlas(w: Widgets&, px: const u8[:], size: int2) {
    if w.atlas.id != 0 { gpu::release(w.atlas); }
    w.atlas = gpu::texture_r8(size.x, size.y, px);
    w.stale = true;
}

// The `n` uploaded quads in the open pass, in runs of one pipeline (FRAG), in order; the
// glyphs and the thumbnails the glass copy until there are any.
fn draw_quads(w: Widgets&, n: i64, s: scene::Scene&, t: theme::Theme, view: View) {
    let atlas = if w.atlas.id != 0 { w.atlas } else { s.glass };
    let thumbs = if w.thumbs.id != 0 { w.thumbs } else { s.glass };
    var start = 0;
    while start < n {
        let p = pipeline_of(w.upload[start]);
        var end = start + 1;
        while end < n && pipeline_of(w.upload[end]) == p { end++; }
        widgets_gpu::run(w.gpu, p, start, end - start, s, t, view, atlas, thumbs, w.badges);
        start = end;
    }
}

// Which of the three pipelines draws quad `q`.
fn pipeline_of(q: gui::Quad) -> i64 {
    let kind = q.look.x as i64;
    return if kind == gui::ICON { 1 } else if kind == gui::FACE { 2 } else { 0 };
}
