// The renderer: all the app draws, behind one call a frame (docs/architecture/README.md,
// "A frame"). It holds every drawer and what they keep on the GPU: the flat board, its
// pieces, and the season's photograph with its blurred copies (draw, scene), the 3D
// board (draw3d over render3d), the UI's quads with the text's and the badges' textures
// and the seasons' thumbnails (widgets). The app hands it plain values (Frame) and the
// bytes it builds (the glyphs, the badges), and holds no gfx handle of its own. A second
// renderer replaces this file and the drawers under it; what the packages fill stays as
// it is. This is the goose-ngfx build's (task 065, scripts/ngfx.py).
namespace render;
import std;
import vec;
import ngfx;

import board from "../board";
import gui from "../gui";

struct Renderer {
    d:  draw::Drawer,
    d3: draw3d::Drawer,
    w:  widgets::Widgets,
    t:  text::Text,
}

// What a frame draws, all of it the app's: the board the screen shows as board::fill left
// it (its pieces, the squares' marks, the flash, a win's dim), where it goes, the pieces
// over the UI, and the UI's quads, with the scrolling list's view (gui's scroll.view);
// the 3D board when `raised`, through `view`, `which` board it is (the shell's which()),
// held as drawn while `hold` (a transition), its bounds put at `place` as opaque as
// `fade`; the photograph's blur, the hole the board leaves in the UI in a transition
// (`tall` pixels tall, 0 as tall as wide); the time and the screen's size.
struct Frame {
    board:  board::Board&,
    layout: board::Layout,
    over:   const board::Piece[:],
    quads:  const gui::Quad[:],
    clip:   float4,
    raised: bool,
    view:   view3d::View,
    which:  i64,
    hold:   bool,
    place:  float4,
    fade:   f32,
    blur:   f32,
    hole:   float4,
    tall:   f32,
    now:    f64,
    size:   int2,
}

// The renderer for the app's theme `kind`, with its photograph or the `plain` fade
// behind, the 3D board's looks as the development flags pick them (`f`, flags.goose).
// With --bench, the photograph's load is timed and printed.
fn new(kind: i64, plain: bool, f: flags::Flags&) -> Renderer {
    var r = Renderer { d: draw::new(kind, plain, f.bench > 0),
                      d3: draw3d::Drawer { wood: f.wood, marble: f.marble, summer: f.summer, spring: f.spring,
                                           timed: f.bench > 0, live: !f.keep, .. },
                      w: widgets::new(), t: text::Text {} };
    r.w.live = !f.keep;
    if f.bench > 0 {
        print("bench: the photograph loaded in ", floor(r.d.load_ms * 100.0 + 0.5) / 100.0,
              " ms (decoded or uploaded, shrunk, blurred, waited for)");
    }
    return r;
}

// Whether it draws theme `kind` with its photograph, or with `plain` the fade.
fn shows_theme(r: Renderer&, kind: i64, plain: bool) -> bool { r.d.kind == kind && r.d.scene.plain == plain }

// Swaps the theme and its photograph for `kind`'s, or with `plain` none.
fn reload(r: Renderer&, kind: i64, plain: bool) { draw::reload(r.d, kind, plain); }

// Bakes the text's faces at `scale` pixels per dp into g's glyph tables and their
// texture, unless they are baked at that scale; true when it baked.
fn upload_text(r: Renderer&, g: gui::Gui&, scale: f32) -> bool {
    guard text::stale(r.t, scale) else { return false; }
    let px, size = text::bake(r.t, g, scale);
    widgets::atlas(r.w, px[..size.x * size.y], size);
    return true;
}

// The seasons' thumbnails for settings (scene::thumbs), made once; whether they are.
fn thumbs(r: Renderer&) { if r.w.thumbs.id == 0 { r.w.thumbs = scene::thumbs(); } }
fn has_thumbs(r: Renderer&) -> bool { r.w.thumbs.id != 0 }

// Submits what is drawn and waits for the GPU (the benches).
fn wait() { ngfx::flush(); }

// The 3D board: whether it is ready on n squares for the theme and background drawn (it
// gets ready a step a frame as it is drawn, draw3d::prepare), whether an image of it
// shows, whether it is fading in at `now`, and whether it asks for the next frame (just
// made ready, or easing grey or back).
fn ready3d(r: Renderer&, n: i64) -> bool { draw3d::ready(r.d3, r.d.kind, n, r.d.scene.plain) }
fn shown3d(r: Renderer&) -> bool { draw3d::shows(r.d3) }
fn appearing3d(r: Renderer&, now: f64) -> bool { draw3d::appearing(r.d3, now) }
fn moving3d(r: Renderer&) -> bool { r.d3.fresh || draw3d::greying(r.d3) }

// Gives back all the 3D board holds, if anything, and puts the flat game's cover back
// under a resizing window (resize.c).
fn drop3d(r: Renderer&) {
    guard r.d3.ready else { return; }
    draw3d::drop(r.d3);
    draw::cover(r.d);
}

// Draws the frame and ends its pass; frame() presents it (host.goose). The copies and
// the passes into textures come first, as none may run inside the screen's pass: the
// UI's quads (and its kept layer), the 3D board's image, the pieces. Then the screen's
// pass: the photograph and the board's squares, the pieces, the UI, and the pieces over
// the UI; on the 3D board, the photograph, its image laid over it, and the UI likewise.
fn frame(r: Renderer&, f: Frame&) {
    let width:  f32 = f.size.x;
    let height: f32 = f.size.y;
    widgets::prepare(r.w, f.quads, f.clip, r.d.scene, r.d.colors, width, height, f.hole, f.tall);
    if f.raised {
        draw3d::frame(r.d3, f.board, f.layout, f.view, f.now, f.size, r.d.kind, r.d.scene.plain, f.which, f.hold);
    }
    draw::upload(r.d, f.board, f.over, f.layout, width, height, !f.raised);
    // No depth target: nothing tests depth.
    ngfx::begin_pass(ngfx::screen(), ngfx::Texture { 0 }, r.d.colors.page);
    if f.raised {
        draw::photo(r.d, f.blur, f.now, width, height, draw3d::shows(r.d3) && !draw3d::appearing(r.d3, f.now));
        draw3d::show(r.d3, f.blur, f.place, f.fade, f.size, f.now);
    } else {
        draw::board(r.d, f.board, f.layout, f.blur, f.now, width, height);
    }
    widgets::frame(r.w, f.quads, f.clip, r.d.scene, r.d.colors, width, height, f.hole, f.tall);
    draw::overlay(r.d, f.now, f.hole, f.tall);
    ngfx::end_pass();
}
