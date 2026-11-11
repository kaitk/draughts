// Drawing the board: one full-screen pass for the blurred photograph and the squares
// with their marks, worked out per pixel; then every piece in one instanced draw that
// pulls its piece from GPU memory (docs/architecture/rendering.md, "Look"). The board is
// flat; only the pieces have a soft light. What is drawn is this file's; the shaders and
// GPU calls are the renderer's (draw_gpu.goose).
namespace draw;
import std;
import vec;

import board from "../board";
import .scene;

// The board pass's uniforms, std140.
struct BoardUniforms {
    screen: float4,     // width, height in pixels, time, squares per side
    rect:   float4,     // the board: x, y, size, corner radius
    inner:  float4,     // the squares: x, y, size, one square
    scene:  float4,     // x: the photograph's blur, 0 sharp..1, or -1 with none; y: how bright it is shown; z: the board dimmed by; w: 1 turned
    wrong:  float4,     // a wrong move's square (y * size + x, or -1), how far its flash is, 0..1, and how lit marks.next's dots are
    marks:  board::Marks,
}

struct View { screen: float4 }     // width, height, the disc's side depth in radii

// What a Mac window shows around its last frame while its edge is dragged (resize.c;
// rendering.md, "Window resizing"): whether it shows one at all (only the Mac does), and
// the pixels of a texture of the cover's side, RGBA8, or with none `page`'s color.
extern fn draughts_resize_covers() -> bool;
extern fn draughts_resize_cover(px: const u8[:], r: f32, g: f32, b: f32);

// The cover from texture t (its pixels read back), or with t 0 the page's color.
fn cover_with(t: gpu::Texture, page: float4) {
    guard draughts_resize_covers() else { return; }
    var px: u8[>..] = [];
    if t.id != 0 && !gpu::read_texture(t, px) { px.clear(); }
    draughts_resize_cover(px[..], page.x, page.y, page.z);
}

// The scene's blurred photograph when it has one, else the page color.
fn cover(d: Drawer&) {
    cover_with(if d.scene.has && !d.scene.plain { d.scene.photo } else { gpu::no_texture() }, d.colors.page);
}

struct Drawer {
    gpu:    draw_gpu::Gpu,
    scene:  scene::Scene,
    kind:   i64,             // the theme drawn (theme::WOOD..), whose scene is loaded
    colors: theme::Theme,
    // What goes to the GPU: always the whole of each on gfx, so SDL can cycle its buffers.
    upload:      board::Piece[board::MAX_PIECES],
    over_upload: board::Piece[board::OVER],     // the pieces drawn over the UI
    over_count:  i64,
    view:        View,
    load_ms:     f64,              // the photograph's load and blurs at new(), waited for when `timed`
}

// The drawer for theme `kind`, its photograph or with `plain` none; with `timed` the
// photograph's load waited for and timed (--bench), load_ms.
fn new(kind: i64, plain: bool, timed: bool = false) -> Drawer {
    let g = draw_gpu::new();
    let t0 = clock();
    let sc = scene::load(kind, plain);
    if timed { gpu::flush(); }
    var d = Drawer {
        gpu:         g,
        scene:       sc,
        kind:        kind,
        colors:      theme::get(kind),
        upload:      [board::Piece {}; board::MAX_PIECES],
        over_upload: [board::Piece {}; board::OVER],
        over_count:  0,
        view:        View { screen: float4 { 0.0, 0.0, 0.0, 0.0 } },
        load_ms:     (clock() - t0) * 1000.0,
    };
    draw_gpu::buffers(d.gpu, d.upload, d.over_upload);
    cover(d);
    return d;
}

// Copies the board's pieces (with `flat`; the 3D board draws its own) for board() to
// draw, and those in `over` for overlay() to draw over the UI, before the screen's pass.
fn upload(d: Drawer&, b: board::Board&, over: const board::Piece[:], l: board::Layout, width: f32, height: f32,
          flat: bool) {
    if flat {
        for i in b.pieces.len { d.upload[i] = b.pieces[i]; }
        draw_gpu::pieces(d.gpu, d.upload, b.pieces.len);
    }
    pieces_over(d, over, l, width, height);
}

fn pieces_over(d: Drawer&, over: const board::Piece[:], l: board::Layout, width: f32, height: f32) {
    d.over_count = min(over.len, board::OVER);
    for i in d.over_count { d.over_upload[i] = over[i]; }
    if d.over_count > 0 { draw_gpu::over(d.gpu, d.over_upload, d.over_count); }
    // The disc's side is 0.55% of the board deep, whatever a piece's size; the same for
    // the pieces over the UI where no board shows (a setup on a short phone).
    let across = if l.inner.w > 0.0 { l.board.z / l.inner.w } else { l.n / 0.978 };
    d.view = View { screen: float4 { width, height, 0.0055 * across / 0.39, 0.0 } };
}

// Draws the board as fill() left it, its pieces as upload() copied them, into the
// screen's open pass. `blur` 0 shows the photograph as it is (home, settings), 1 blurred
// and dimmed (the game), and between mixes the two (a transition).
fn board(d: Drawer&, b: board::Board&, l: board::Layout, blur: f32, now: f64, width: f32, height: f32) {
    // Dimmed to 0.8 blurred; the ends exact, so a screen at rest draws as it always has.
    let k = clamp(blur, 0.0, 1.0);
    let bright: f32 = if k <= 0.0 { 1.0 } else if k >= 1.0 { 0.8 } else { 1.0 - 0.2 * k };
    draw_gpu::board(d.gpu, d.scene, d.colors, BoardUniforms {
        screen: float4 { width, height, now as f32, l.n },
        rect:   l.board, inner: l.inner,
        scene:  float4 { backdrop(d, k), bright, b.dim, if l.flip { 1.0 } else { 0.0 } },
        wrong: b.flash, marks: b.marks });
    draw_gpu::men(d.gpu, false, d.colors, d.view, float4 { now as f32, 0.0, 0.0, 0.0 }, float4 { 0.0, 0.0, 0.0, 0.0 },
                  b.pieces.len);
}

// The photograph alone behind a 3D board (draw3d.goose), in the screen's open pass,
// `blur` as board() takes it; with blur 1 and `covered` (the renderer's own backdrop
// fully shown over it) nothing, the pass only cleared. While the 3D board gets ready or
// fades in, the photograph shows as on the flat board, so only the board appears.
fn photo(d: Drawer&, blur: f32, now: f64, width: f32, height: f32, covered: bool = true) {
    guard blur < 1.0 || !covered else { return; }
    let k = clamp(blur, 0.0, 1.0);
    let bright: f32 = 1.0 - 0.2 * k;
    // The board far off the screen: only the photograph shows.
    let away = float4 { -4.0 * width, -4.0 * height, width, 0.0 };
    var none = board::Marks {};
    draw_gpu::board(d.gpu, d.scene, d.colors, BoardUniforms {
        screen: float4 { width, height, now as f32, 8.0 }, rect: away, inner: away,
        scene:  float4 { backdrop(d, k), bright, 0.0, 0.0 }, wrong: float4 { -1.0, 0.0, 0.0, 0.0 },
        marks: none });
}

// What the board pass shows behind the board (BoardUniforms.scene.x): the photograph
// blurred `k` of the way, the page color (-1) without one, or the plain fade (-2).
fn backdrop(d: Drawer&, k: f32) -> f32 {
    if d.scene.plain { return -2.0; }
    return if d.scene.has { k } else { -1.0 };
}

// Swaps the theme and its scene for theme `kind`'s, its photograph or with `plain` none.
fn reload(d: Drawer&, kind: i64, plain: bool) {
    scene::release(d.scene);
    // The old scene is freed once the GPU is done with it; waiting (about a frame) lets
    // the new one take its place in SDL's shared block rather than open another.
    gpu::flush();
    d.scene = scene::load(kind, plain);
    d.kind = kind;
    d.colors = theme::get(kind);
    cover(d);
}

// Draws the pieces upload() was given for over the UI, in the open pass, none inside
// `hole` (`tall` pixels tall, 0 as tall as wide) but those on the board.
fn overlay(d: Drawer&, now: f64, hole: float4, tall: f32 = 0.0) {
    guard d.over_count > 0 else { return; }
    draw_gpu::men(d.gpu, true, d.colors, d.view, float4 { now as f32, tall, 0.0, 0.0 }, hole, d.over_count);
}
