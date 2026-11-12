// The board's draws (draw.goose) in the build that holds both renderers (scripts/ngfx.py
// lays this over src/app/draw_gpu.goose): gfx's recorder (draw_gfx) or goose-ngfx's
// (draw_ngfx), as nx::ngfx_on says, each holding its own state; the widgets' shaders'
// blocks are gfx's.
namespace draw_gpu;
import std;
import vec;

import board from "../board";

let THEME_BLOCK = draw_gfx::THEME_BLOCK;
let SHARED_BLOCK = draw_gfx::SHARED_BLOCK;
let MAN_BLOCK = draw_gfx::MAN_BLOCK;

// The chosen renderer's half is made; the other stays empty.
struct Gpu {
    gfx_gpu:  draw_gfx::Gpu,
    ngfx_gpu: draw_ngfx::Gpu,
}

fn new() -> Gpu {
    if nx::ngfx_on { return Gpu { gfx_gpu: default<draw_gfx::Gpu>(), ngfx_gpu: draw_ngfx::new() }; }
    return Gpu { gfx_gpu: draw_gfx::new(), ngfx_gpu: default<draw_ngfx::Gpu>() };
}

fn buffers(g: Gpu&, all: const board::Piece[:], over: const board::Piece[:]) {
    if nx::ngfx_on { draw_ngfx::buffers(g.ngfx_gpu, all, over); } else { draw_gfx::buffers(g.gfx_gpu, all, over); }
}

fn pieces(g: Gpu&, all: const board::Piece[:], n: i64) {
    if nx::ngfx_on { draw_ngfx::pieces(g.ngfx_gpu, all, n); } else { draw_gfx::pieces(g.gfx_gpu, all, n); }
}

fn over(g: Gpu&, all: const board::Piece[:], n: i64) {
    if nx::ngfx_on { draw_ngfx::over(g.ngfx_gpu, all, n); } else { draw_gfx::over(g.gfx_gpu, all, n); }
}

fn board(g: Gpu&, sc: scene::Scene&, t: theme::Theme, u: draw::BoardUniforms) {
    if nx::ngfx_on { draw_ngfx::board(g.ngfx_gpu, sc, t, u); } else { draw_gfx::board(g.gfx_gpu, sc, t, u); }
}

fn men(g: Gpu&, over: bool, t: theme::Theme, view: draw::View, time: float4, hole: float4, n: i64) {
    if nx::ngfx_on { draw_ngfx::men(g.ngfx_gpu, over, t, view, time, hole, n); } else { draw_gfx::men(g.gfx_gpu, over, t, view, time, hole, n); }
}
