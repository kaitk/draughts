// Recording the board's draws (draw.goose) through goose-ngfx, in place of
// src/app/draw_gpu.goose (scripts/ngfx.py): its shaders, written from that file's GLSL
// (scripts/ngfx_2d_shaders.py) and built ahead, and the pieces copied into each frame's
// memory, which their draw pulls them from.
namespace draw_gpu;
import std;
import vec;
import ngfx;

import board from "../board";

// The board's and the pieces' roots, as their shaders' headers lay them out.
struct BoardRoot { photo: u32, sharp: u32, smp: u32, unused: u32, theme: theme::Theme, u: draw::BoardUniforms }
struct PieceRoot { pieces: u64, pad0: u32, pad1: u32, view: draw::View, theme: theme::Theme, time: float4, hole: float4 }

struct Gpu {
    board_pipeline: ngfx::Pipeline,
    piece_pipeline: ngfx::Pipeline,
    pieces:         u64,             // this frame's pieces, and those over the UI, in its memory
    overlay:        u64,
}

fn new() -> Gpu {
    return Gpu { board_pipeline: ngfx::pipeline(embed_file("shaders/board.blob")),
                 piece_pipeline: ngfx::pipeline(embed_file("shaders/pieces.blob"),
                                                ngfx::PipelineDesc { blend: ngfx::BLEND_PREMULTIPLIED }),
                 pieces: 0, overlay: 0 };
}

// Nothing: the pieces go into each frame's memory.
fn buffers(g: Gpu&, all: const board::Piece[:], over: const board::Piece[:]) {}

// The first n of `all` into this frame's memory, the board's or those over the UI.
fn pieces(g: Gpu&, all: const board::Piece[:], n: i64) {
    if n > 0 { g.pieces = ngfx::frame_data(bytes_of(all[..n])); }
}
fn over(g: Gpu&, all: const board::Piece[:], n: i64) { g.overlay = ngfx::frame_data(bytes_of(all[..n])); }

fn board(g: Gpu&, sc: scene::Scene&, t: theme::Theme, u: draw::BoardUniforms) {
    ngfx::bind(g.board_pipeline);
    ngfx::draw(ngfx::root(BoardRoot { photo: ngfx::index(sc.photo), sharp: ngfx::index(sc.sharp),
                                      smp: ngfx::index(sc.sampler), unused: 0, theme: t, u: u }), 3);
}

fn men(g: Gpu&, over: bool, t: theme::Theme, view: draw::View, time: float4, hole: float4, n: i64) {
    guard n > 0 else { return; }
    ngfx::bind(g.piece_pipeline);
    ngfx::draw_instanced(ngfx::root(PieceRoot { pieces: if over { g.overlay } else { g.pieces }, pad0: 0, pad1: 0,
                                                view: view, theme: t, time: time, hole: hole }), 6, n);
}
