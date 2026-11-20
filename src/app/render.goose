// The renderer: every drawer and what it keeps on the GPU, behind one call a frame
// (docs/architecture/README.md, "A frame"). The drawers are renderer-free; each call here
// that reaches the GPU runs them in backend::with, with the backend chosen at start.
namespace render;
import std;
import vec;

import board from "../board";
import gui from "../gui";

struct Renderer {
    d:  draw::Drawer,
    d3: draw3d::Drawer,
    w:  widgets::Widgets,
    t:  text::Text,
}

// What a frame draws, as shell::Frame describes it.
struct Frame {
    board:     board::Board&,
    layout:    board::Layout,
    ui_pieces: const board::Piece[:],
    quads:     const gui::Quad[:],
    clip:      float4,
    raised:    bool,
    view:      view3d::View,
    which:     i64,
    hold:      bool,
    place:     float4,
    fade:      f32,
    blur:      f32,
    hole:      float4,
    tall:      f32,
    now:       f64,
    size:      int2,
}

fn new(kind: i64, plain: bool, f: flags::Flags&) -> Renderer { backend::with() { be => made(be, kind, plain, f) } }

fn made<B>(be: B&, kind: i64, plain: bool, f: flags::Flags&) -> Renderer {
    let aa = be.r3d.aa_named(f.aa[..]);
    var r = Renderer { d: draw::new(be, kind, plain, f.bench > 0),
                      d3: draw3d::Drawer { aa: if aa >= 0 { aa } else { render3d::AA }, wood: f.wood, marble: f.marble,
                                           summer: f.summer, autumn: f.autumn, winter: f.winter, spring: f.spring,
                                           live: !f.keep, table: f.table, .. },
                      w: widgets::new(be), t: text::Text {} };
    r.w.live = !f.keep;
    if f.bench > 0 {
        print("bench: the photograph loaded in ", floor(r.d.load_ms * 100.0 + 0.5) / 100.0,
              " ms (decoded or uploaded, shrunk, blurred, waited for)");
    }
    return r;
}

// The 3D board's antialiasing as settings' About shows it ("4× MSAA"), and whether the
// app lowered it for a slow device (draw3d::fewer_samples).
fn aa_shown(r: Renderer&) -> u8[..24], bool {
    let d .= r.d3;
    var out: u8[..24] = [];
    let msaa = d.aa == render3d::AA_MSAA;
    if msaa { format(out, d.samples, "× MSAA"); }
    else if d.aa == render3d::AA_OFF { out.append("off"); }
    else { backend::with() { be => out.append(upper(be.r3d.aa_name(d.aa))) } }
    return out, msaa && d.samples < render3d::SAMPLES;
}

// A name in capitals, "smaa" as SMAA.
fn upper(s: const u8[:]) -> u8[..8] {
    var out: u8[..8] = [];
    for c in s { if out.len < 8 { out.push(if c >= 'a' && c <= 'z' { c - 32 } else { c }); } }
    return out;
}

// The 3D board's shadow taps (render3d::SHADOW_4..16) and its surfaces' side.
fn shadow_taps(r: Renderer&) -> i64 {
    return if r.d3.look == render3d::SHADOW_16 { 16 } else if r.d3.look == render3d::SHADOW_4 { 4 } else { 9 };
}
fn surfaces_side(r: Renderer&) -> i64 { r.d3.side }

fn toggle_aa(r: Renderer&) { backend::with() { be => draw3d::toggle_aa(be, r.d3) } }

fn fewer_samples(r: Renderer&) { backend::with() { be => draw3d::fewer_samples(be, r.d3) } }

fn screen_shadow(r: Renderer&, look: i32) { backend::with() { be => draw3d::screen_shadow(be, r.d3, look) } }

fn screen_bake(r: Renderer&, small: bool) { draw3d::screen_bake(r.d3, small); }

fn shows_theme(r: Renderer&, kind: i64, plain: bool) -> bool { r.d.kind == kind && r.d.scene.plain == plain }

fn reload(r: Renderer&, kind: i64, plain: bool) { backend::with() { be => draw::reload(be, r.d, kind, plain) } }

// Bakes the text's faces at `scale` pixels per dp, unless baked at it; true when it baked.
fn upload_text(r: Renderer&, g: gui::Gui&, scale: f32) -> bool {
    guard text::stale(r.t, scale) else { return false; }
    let px, size = text::bake(r.t, g, scale);
    backend::with() { be => widgets::atlas(be, r.w, px[..size.x * size.y], size) }
    return true;
}

// The seasons' thumbnails for settings, made once.
fn thumbs(r: Renderer&) { if r.w.thumbs.id == 0 { r.w.thumbs = backend::with() { be => scene::thumbs(be) }; } }
fn has_thumbs(r: Renderer&) -> bool { r.w.thumbs.id != 0 }

// Submits what is drawn and waits for the GPU.
fn wait() { backend::with() { be => be.flush() } }

// The player's 3D board: its material (settings::MATERIAL_AUTO..), the table under it, and
// Smooth pieces; a change prepares what it takes again (draw3d::want_look).
fn look3d(r: Renderer&, m: i64, table: bool, smooth: bool) { draw3d::want_look(r.d3, m, table, smooth); }

// moving3d: just made ready, or easing grey or back, so the next frame draws too.
fn ready3d(r: Renderer&, n: i64) -> bool { draw3d::ready(r.d3, r.d.kind, n, r.d.scene.plain) }
fn shown3d(r: Renderer&) -> bool { draw3d::shows(r.d3) }
fn appearing3d(r: Renderer&, now: f64) -> bool { draw3d::appearing(r.d3, now) }
fn moving3d(r: Renderer&) -> bool { r.d3.fresh || draw3d::greying(r.d3) }

// At a frame's end: the 3D pass gives back its targets unless the board is `shown`.
fn release_targets_unless_shown(r: Renderer&, shown: bool) { backend::with() { be => draw3d::release_targets_unless_shown(be, r.d3, shown) } }

// Gives back all the 3D board holds, and puts the flat game's cover back under a
// resizing window (resize.c).
fn drop3d(r: Renderer&) {
    guard r.d3.ready else { return; }
    backend::with() { be => dropped(be, r) }
}

fn dropped<B>(be: B&, r: Renderer&) {
    draw3d::drop(be, r.d3);
    draw::cover(be, r.d);
}

// Draws the frame and ends its pass; host::frame presents it. Copies and passes into
// textures come first, as none may run inside the screen's pass.
fn frame(r: Renderer&, f: Frame&) { backend::with() { be => draw_frame(be, r, f) } }

fn draw_frame<B>(be: B&, r: Renderer&, f: Frame&) {
    let width:  f32 = f.size.x;
    let height: f32 = f.size.y;
    widgets::prepare(be, r.w, f.quads, f.clip, r.d.scene, r.d.colors, width, height, f.hole, f.tall);
    if f.raised {
        draw3d::frame(be, r.d3, f.board, f.layout, f.view, f.now, f.size, r.d.kind, r.d.scene.plain, f.which, f.hold,
                      f.place);
    }
    draw::upload(be, r.d, f.board, f.ui_pieces, f.layout, width, height, !f.raised);
    // No depth target: nothing tests depth, and asking would make gfx keep a window-sized one.
    be.begin_pass(be.screen(), r.d.colors.page);
    if f.raised {
        draw::photo(be, r.d, f.blur, f.now, width, height, draw3d::shows(r.d3) && !draw3d::appearing(r.d3, f.now));
        draw3d::show(be, r.d3, f.blur, f.place, f.fade, f.size, f.now);
    } else {
        draw::board(be, r.d, f.board, f.layout, f.blur, f.now, width, height);
    }
    widgets::frame(be, r.w, f.quads, f.clip, r.d.scene, r.d.colors, width, height, f.hole, f.tall);
    draw::overlay(be, r.d, f.now, f.hole, f.tall);
    be.end_pass();
}
