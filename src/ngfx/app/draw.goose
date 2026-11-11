// Drawing the board through goose-ngfx (task 065; src/app/draw.goose is gfx's, whose
// comments say what each part is for): one full-screen pass for the photograph and the
// squares with their marks, then every piece in one instanced draw that pulls its piece
// from this frame's memory. Shaders: src/ngfx/shaders/board.slang and pieces.slang.
namespace draw;
import std;
import vec;
import ngfx;

import board from "../board";
import .scene;

struct BoardUniforms {
    screen: float4,
    rect:   float4,
    inner:  float4,
    scene:  float4,
    wrong:  float4,
    marks:  board::Marks,
}

struct View { screen: float4 }

// board.slang's and pieces.slang's roots.
struct BoardRoot { photo: u32, sharp: u32, smp: u32, unused: u32, theme: theme::Theme, u: BoardUniforms }
struct PieceRoot { pieces: u64, pad0: u32, pad1: u32, theme: theme::Theme, view: float4, time: float4, hole: float4 }

extern fn draughts_resize_covers() -> bool;
extern fn draughts_resize_cover(px: const u8[:], r: f32, g: f32, b: f32);

fn cover_with(t: ngfx::Texture, page: float4) {
    guard draughts_resize_covers() else { return; }
    var px: u8[>..] = [];
    if t.id != 0 && !ngfx::read_texture(t, px) { px.clear(); }
    draughts_resize_cover(px[..], page.x, page.y, page.z);
}

fn cover(d: Drawer&) {
    cover_with(if d.scene.has && !d.scene.plain { d.scene.photo } else { ngfx::Texture { 0 } }, d.colors.page);
}

struct Drawer {
    board_pipeline: ngfx::Pipeline,
    piece_pipeline: ngfx::Pipeline,
    pieces:         u64,             // this frame's pieces, and those over the UI, in its memory
    overlay:        u64,
    scene:          scene::Scene,
    kind:           i64,
    colors:         theme::Theme,
    upload:         board::Piece[board::MAX_PIECES],
    over_upload:    board::Piece[board::OVER],
    over_count:     i64,
    view:           View,
    load_ms:        f64,
}

fn new(kind: i64, plain: bool, timed: bool = false) -> Drawer {
    let board_pipeline = ngfx::pipeline(embed_file("shaders/board.blob"));
    let piece_pipeline = ngfx::pipeline(embed_file("shaders/pieces.blob"), ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED });
    let t0 = clock();
    let sc = scene::load(kind, plain);
    if timed { ngfx::flush(); }
    var d = Drawer {
        board_pipeline: board_pipeline,
        piece_pipeline: piece_pipeline,
        pieces:         0,
        overlay:        0,
        scene:          sc,
        kind:           kind,
        colors:         theme::get(kind),
        upload:         [board::Piece {}; board::MAX_PIECES],
        over_upload:    [board::Piece {}; board::OVER],
        over_count:     0,
        view:           View { screen: float4 { 0.0, 0.0, 0.0, 0.0 } },
        load_ms:        (clock() - t0) * 1000.0,
    };
    cover(d);
    return d;
}

// Copies the board's pieces (with `flat`) and those over the UI into this frame's memory.
fn upload(d: Drawer&, b: board::Board&, over: const board::Piece[:], l: board::Layout, width: f32, height: f32,
          flat: bool) {
    if flat && b.pieces.len > 0 {
        for i in b.pieces.len { d.upload[i] = b.pieces[i]; }
        d.pieces = ngfx::frame_data(bytes_of(d.upload[..b.pieces.len]));
    }
    pieces_over(d, over, l, width, height);
}

fn pieces_over(d: Drawer&, over: const board::Piece[:], l: board::Layout, width: f32, height: f32) {
    d.over_count = min(over.len, board::OVER);
    for i in d.over_count { d.over_upload[i] = over[i]; }
    if d.over_count > 0 { d.overlay = ngfx::frame_data(bytes_of(d.over_upload[..d.over_count])); }
    let across = if l.inner.w > 0.0 { l.board.z / l.inner.w } else { l.n / 0.978 };
    d.view = View { screen: float4 { width, height, 0.0055 * across / 0.39, 0.0 } };
}

fn board_root(d: Drawer&, u: BoardUniforms) -> u64 {
    return ngfx::root(BoardRoot { photo: ngfx::index(d.scene.photo), sharp: ngfx::index(d.scene.sharp),
                                  smp: ngfx::index(d.scene.sampler), unused: 0, theme: d.colors, u: u });
}

fn board(d: Drawer&, b: board::Board&, l: board::Layout, blur: f32, now: f64, width: f32, height: f32) {
    ngfx::bind(d.board_pipeline);
    let k = clamp(blur, 0.0, 1.0);
    let bright: f32 = if k <= 0.0 { 1.0 } else if k >= 1.0 { 0.8 } else { 1.0 - 0.2 * k };
    ngfx::draw(board_root(d, BoardUniforms {
        screen: float4 { width, height, now as f32, l.n },
        rect:   l.board, inner: l.inner,
        scene:  float4 { backdrop(d, k), bright, b.dim, if l.flip { 1.0 } else { 0.0 } },
        wrong: b.flash, marks: b.marks }), 3);
    guard b.pieces.len > 0 else { return; }
    ngfx::bind(d.piece_pipeline);
    ngfx::draw_instanced(ngfx::root(PieceRoot { pieces: d.pieces, pad0: 0, pad1: 0, theme: d.colors, view: d.view.screen,
                                                time: float4 { now as f32, 0.0, 0.0, 0.0 },
                                                hole: float4 { 0.0, 0.0, 0.0, 0.0 } }), 6, b.pieces.len);
}

fn photo(d: Drawer&, blur: f32, now: f64, width: f32, height: f32, covered: bool = true) {
    guard blur < 1.0 || !covered else { return; }
    ngfx::bind(d.board_pipeline);
    let k = clamp(blur, 0.0, 1.0);
    let bright: f32 = 1.0 - 0.2 * k;
    let away = float4 { -4.0 * width, -4.0 * height, width, 0.0 };
    var none = board::Marks {};
    ngfx::draw(board_root(d, BoardUniforms {
        screen: float4 { width, height, now as f32, 8.0 }, rect: away, inner: away,
        scene:  float4 { backdrop(d, k), bright, 0.0, 0.0 }, wrong: float4 { -1.0, 0.0, 0.0, 0.0 },
        marks: none }), 3);
}

fn backdrop(d: Drawer&, k: f32) -> f32 {
    if d.scene.plain { return -2.0; }
    return if d.scene.has { k } else { -1.0 };
}

fn reload(d: Drawer&, kind: i64, plain: bool) {
    scene::release(d.scene);
    d.scene = scene::load(kind, plain);
    d.kind = kind;
    d.colors = theme::get(kind);
    cover(d);
}

fn overlay(d: Drawer&, now: f64, hole: float4, tall: f32 = 0.0) {
    guard d.over_count > 0 else { return; }
    ngfx::bind(d.piece_pipeline);
    ngfx::draw_instanced(ngfx::root(PieceRoot { pieces: d.overlay, pad0: 0, pad1: 0, theme: d.colors, view: d.view.screen,
                                                time: float4 { now as f32, tall, 0.0, 0.0 }, hole: hole }),
                         6, d.over_count);
}
