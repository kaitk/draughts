// The game's 3D board (task 015), behind the `--3d` flag with the Board row's 3D chosen
// (settings::raised): drawn by the renderer the prototype shares (src/render3d/) from the
// scene the flat board's draw lists fill (view3d::fill), so selection, targets, a move's
// hop, a capture's fade, and the must-capture ring follow the same state and timing as
// the flat board's.
//
// Draw on demand: the board is drawn into a kept image only when its scene changed
// (view3d::changes: the board, and the shadow map when the pieces stand differently or
// the board turns under the light), or the screen's size or the theme did; the camera
// moving (game/panel.goose's aim) changes the view, so it is drawn only while it moves.
// Each drawn frame then lays the image over the backdrop, under the UI. A frame that changes only the UI (a clock's second, a pressed
// tile) costs that copy, not the 3D pass. In a transition between screens the image is
// drawn once, through the larger end's view, and only moved and scaled from one end's
// place to the other's (`hold`; docs/architecture/rendering.md, "Transitions"). The
// image holds the board alone on clear: behind it the game and a puzzle show the
// renderer's graded backdrop, home and settings the app's sharp photograph, and a
// transition between them crossfades the two. The renderer is set up the first time the
// 3D board shows, its surfaces baked again on a theme or a board size change, never while
// drawing.
namespace draw3d;
import std;
import vec;
import gfx;

struct Drawer {
    gpu:     render3d::Gpu                         = default<render3d::Gpu>(),
    ready:   bool                                  = false,
    kind:    i64                                   = -1, // the app's theme the board was set up with
    which:   i64                                   = -1, // the board drawn (the shell's which())
    n:       i64                                   = 0,
    wood:    i64                                   = -1, // --wood, --marble: -1 the renderer's own
    marble:  i64                                   = -1,
    summer:  i64                                   = 0,  // --summer: summer's variant (looks::SUMMERS)
    spring:  i64                                   = -1, // --spring: spring's look, -1 the renderer's own
    size:    int2                                  = int2 { 0, 0 },
    scene:   view3d::Scene                         = view3d::Scene {}, // this frame's
    drawn:   view3d::Scene                         = view3d::Scene {}, // the last one drawn
    upload:  float4[..2 * render3d::MAX_INSTANCES] = [],
    alphas:  f32[..render3d::MAX_INSTANCES]        = [],    // the fading instances' opacity, last in upload
    redraw:  bool                                  = false, // this frame drew the 3D board,
    shadow:  bool                                  = false, // and the shadow map first
    frames:  i64                                   = 0,     // frames that showed the 3D board,
    draws:   i64                                   = 0,     // those that drew it,
    shadows: i64                                   = 0,     // and the shadow map
}

// The look for the app's theme, the season's: autumn's wood, winter's stone, spring's
// birch, summer's sunset (its variant `summer`); the photograph is the theme's own.
fn look_of(kind: i64, summer: i64) -> i64 {
    return if kind == theme::STONE { looks::WINTER } else if kind == theme::BIRCH { looks::SPRING }
           else if kind == theme::SUNSET { looks::summer_look(summer) } else { looks::AUTUMN };
}

// Draws the frame board::fill left in b, on the flat layout l, seen through v, into the
// kept image if anything it shows changed; the app's theme `kind`, the screen `size`.
// `which` tells the boards apart (the game's, a puzzle's, settings' preview). While
// `hold` (a transition) the image is drawn again only for another view or board.
fn frame(d: Drawer&, b: board::Board&, l: board::Layout, v: view3d::View, now: f64, size: int2, kind: i64,
         which: i64 = 0, hold: bool = false) {
    var force = false;
    if !d.ready {
        render3d::setup(d.gpu);
        render3d::choose(d.gpu, d.wood, d.marble, d.spring);
        d.ready = true;
        force = true;
    }
    if kind != d.kind || l.n != d.n {
        d.kind = kind;
        d.n = l.n;
        let look = look_of(kind, d.summer);
        // A summer variant's own wood and finish; else --wood's, or the renderer's own.
        let own = looks::wood_for(look);
        let wood = if own >= 0 { own } else if d.wood >= 0 { d.wood } else { render3d::WOOD_MODEL };
        render3d::choose(d.gpu, wood, -1);
        d.gpu.finish = looks::finish_for(look, d.gpu.wood);
        render3d::apply(d.gpu, look, l.n, kind);
        force = true;
    }
    if size.x != d.size.x || size.y != d.size.y {
        d.size = size;
        force = true;
    }
    d.frames++;
    d.redraw = false;
    d.shadow = false;
    guard force || !hold || which != d.which || !view3d::same_view(d.drawn.view, v) else { return; }
    d.which = which;
    view3d::fill(d.scene, b, l, v, now);
    let c = view3d::changes(d.drawn, d.scene);
    // The board turned under the light (a hot-seat turn): the light turns with it, so it
    // keeps its place on screen, and the shadows are drawn again.
    let turned = v.turn != d.gpu.turn;
    d.redraw = force || c & view3d::DRAW != 0 || turned;
    d.shadow = force || c & view3d::SHADOW != 0 || turned;
    guard d.redraw else { return; }
    d.draws++;
    if d.shadow { d.shadows++; }
    // The opaque instances first, then the fading ones (a captured piece, a wrong move's
    // ghost), which the renderer draws blended after them.
    let s .= d.scene;
    d.upload.clear();
    d.alphas.clear();
    for pass in 2 {
        var i = 0;
        while i + 1 < s.inst.len {
            let a = s.state[i].x;
            if (pass == 0) == (a >= 1.0) {
                d.upload.push(s.inst[i]);
                d.upload.push(s.inst[i + 1]);
                if pass == 1 { d.alphas.push(max(a, 0.0)); }
            }
            i += 2;
        }
    }
    render3d::turn_light(d.gpu, v.turn);
    render3d::place(d.gpu, d.upload[..d.upload.len], d.alphas[..d.alphas.len], s.squares[..], s.field[..], s.lit[..],
                    s.selected, s.dim, d.shadow);
    let m = view3d::matrix(v, size.x, size.y);
    let vp = gfx::mat4 { c0: m.c0, c1: m.c1, c2: m.c2, c3: m.c3 };
    render3d::draw(d.gpu, vp, v.eye, gfx::Texture { 0 }, size, false, false);
    d.drawn = d.scene;
}

// Lays the kept image over the screen's open pass (the app's photograph drawn in it, or
// cleared): the renderer's backdrop first, as opaque as `blur` (1 behind the game and a
// puzzle, 0 behind home and settings, between in a transition), then the board, the
// bounds it was drawn at (the view's rect) put at `place`, as opaque as `fade`.
fn show(d: Drawer&, blur: f32, place: float4, fade: f32, size: int2) {
    if blur > 0.0 { render3d::backdrop(d.gpu, min(blur, 1.0), size); }
    guard fade > 0.0 else { return; }
    // The whole image, the board's soft shadow round it too, moved and scaled as its
    // bounds are: at rest exactly as drawn.
    let r = d.drawn.view.rect;
    guard r.z > 0.0 else { return; }
    let k = place.z / r.z;
    let whole = float4 { place.x - r.x * k, place.y - r.y * k, size.x * k, size.y * k };
    render3d::show(d.gpu, float4 { 0.0, 0.0, size.x, size.y }, whole, min(fade, 1.0), size);
}
