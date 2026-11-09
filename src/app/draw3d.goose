// The game's 3D board (task 015), behind the `--3d` flag with the Board row's 3D chosen
// (settings::raised): drawn by the renderer the prototype shares (src/render3d/) from the
// scene the flat board's draw lists fill (view3d::fill), so selection, targets, a move's
// hop, a capture's fade, and the must-capture ring follow the same state and timing as
// the flat board's.
//
// Draw on demand: the board is drawn into a kept image only when its scene changed
// (view3d::changes: the board, and the shadow map when the pieces stand differently), or
// the screen's size or the theme did; each drawn frame then copies the image under the
// UI. A frame that changes only the UI (a clock's second, a pressed tile) costs the copy,
// not the 3D pass. The renderer is set up the first time the 3D board shows, its
// surfaces baked again on a theme or a board size change, never while drawing.
namespace draw3d;
import std;
import vec;
import gfx;

struct Drawer {
    gpu:     render3d::Gpu                         = default<render3d::Gpu>(),
    ready:   bool                                  = false,
    kind:    i64                                   = -1, // the app's theme the board was set up with
    n:       i64                                   = 0,
    wood:    i64                                   = -1, // --wood, --marble: -1 the renderer's own
    marble:  i64                                   = -1,
    size:    int2                                  = int2 { 0, 0 },
    scene:   view3d::Scene                         = view3d::Scene {}, // this frame's
    drawn:   view3d::Scene                         = view3d::Scene {}, // the last one drawn
    upload:  float4[..2 * render3d::MAX_INSTANCES] = [],
    redraw:  bool                                  = false, // this frame drew the 3D board,
    shadow:  bool                                  = false, // and the shadow map first
    frames:  i64                                   = 0,     // frames that showed the 3D board,
    draws:   i64                                   = 0,     // those that drew it,
    shadows: i64                                   = 0,     // and the shadow map
}

// The look for the app's theme: the winter stone for stone, else the autumn wood (the
// other seasons have no 3D look of their own yet); the photograph is the theme's own.
fn look_of(kind: i64) -> i64 { if kind == theme::STONE { looks::WINTER } else { looks::AUTUMN } }

// Draws the frame board::fill left in b, on the flat layout l, seen through v, into the
// kept image if anything it shows changed; the app's theme `kind`, the screen `size`.
fn frame(d: Drawer&, b: board::Board&, l: board::Layout, v: view3d::View, now: f64, size: int2, kind: i64) {
    var force = false;
    if !d.ready {
        render3d::setup(d.gpu);
        render3d::choose(d.gpu, d.wood, d.marble);
        d.ready = true;
        force = true;
    }
    if kind != d.kind || l.n != d.n {
        d.kind = kind;
        d.n = l.n;
        render3d::apply(d.gpu, look_of(kind), l.n, kind);
        force = true;
    }
    if size.x != d.size.x || size.y != d.size.y {
        d.size = size;
        force = true;
    }
    view3d::fill(d.scene, b, l, v, now);
    let c = view3d::changes(d.drawn, d.scene);
    d.redraw = force || c & view3d::DRAW != 0;
    d.shadow = force || c & view3d::SHADOW != 0;
    d.frames++;
    guard d.redraw else { return; }
    d.draws++;
    if d.shadow { d.shadows++; }
    // A captured piece fading shrinks into its square instead: the pass is opaque.
    let s .= d.scene;
    d.upload.clear();
    var i = 0;
    while i + 1 < s.inst.len {
        let a = s.state[i].x;
        var foot = s.inst[i];
        if a < 1.0 { foot = float4 { foot.x, foot.y * a, foot.z, foot.w * a }; }
        d.upload.push(foot);
        d.upload.push(s.inst[i + 1]);
        i += 2;
    }
    render3d::place(d.gpu, d.upload[..d.upload.len], s.squares[..], s.field[..], s.selected, d.shadow);
    let m = view3d::matrix(v, size.x, size.y);
    let vp = gfx::mat4 { c0: m.c0, c1: m.c1, c2: m.c2, c3: m.c3 };
    render3d::draw(d.gpu, vp, v.eye, gfx::Texture { 0 }, size);
    d.drawn = d.scene;
}

// Opens the screen's pass with the kept image in it, for the UI to be drawn over; the
// caller ends it.
fn begin(d: Drawer&) {
    gfx::begin_pass(gfx::screen(), gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
    render3d::show(d.gpu);
}
