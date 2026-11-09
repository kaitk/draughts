// The game's 3D board (task 015), drawn when the Board row's 3D is chosen
// (settings::raised): drawn by the renderer the prototype shares (src/render3d/) from the
// scene the flat board's draw lists fill (view3d::fill), so selection, targets, a move's
// hop, a capture's fade, and the must-capture ring follow the same state and timing as
// the flat board's.
//
// Draw on demand: the board is drawn into a kept image only when its scene changed
// (view3d::changes: the board, and the shadow map when the pieces stand differently or
// the board turns under the light), or the screen's size or the theme did; the camera
// moving (game/panel.goose's aim) changes the view, so it is drawn only while it moves.
// Each drawn frame then lays the image over the backdrop, under the UI. A frame that
// changes only the UI (a clock's second, a pressed tile) costs that copy, not the 3D
// pass. The marks that pulse (a must-capture ring, a wrong move's flash, a hint's ring)
// aren't in the image: each frame draws them over it from their phases
// (render3d::marks_over, against the board's depth kept with the image), so a ring
// pulsing costs the copy and a quad over the field, as on the flat board, not the 3D
// pass. In a transition between screens the image is drawn once, through the larger
// end's view, and only moved and scaled from one end's place to the other's (`hold`;
// docs/architecture/rendering.md, "Transitions"). The image holds the board alone on
// clear: behind it the game and a puzzle show the renderer's graded backdrop, home and
// settings the app's sharp photograph, and a transition between them crossfades the two.
// The renderer is made ready while settings show with the board flat (prepare, a step a
// frame, given back on leaving them flat: drop), else the first time the 3D board
// shows; its surfaces baked again on
// a theme or a board size change, never while drawing.
namespace draw3d;
import std;
import vec;
import gfx;

struct Drawer {
    gpu:      render3d::Gpu                         = default<render3d::Gpu>(),
    ready:    bool                                  = false,
    kind:     i64                                   = -1, // the app's theme the board was set up with
    which:    i64                                   = -1, // the board drawn (the shell's which())
    n:        i64                                   = 0,
    wood:     i64                                   = -1, // --wood, --marble: -1 the renderer's own
    marble:   i64                                   = -1,
    summer:   i64                                   = 0,  // --summer: summer's variant (looks::SUMMERS)
    spring:   i64                                   = -1, // --spring: spring's look, -1 the renderer's own
    size:     int2                                  = int2 { 0, 0 },
    scene:    view3d::Scene                         = view3d::Scene {}, // this frame's
    drawn:    view3d::Scene                         = view3d::Scene {}, // the last one drawn
    upload:   float4[..2 * render3d::MAX_INSTANCES] = [],
    alphas:   f32[..render3d::MAX_INSTANCES]        = [],    // the fading instances' opacity, last in upload
    redraw:   bool                                  = false, // this frame drew the 3D board,
    shadow:   bool                                  = false, // and the shadow map first
    frames:   i64                                   = 0,     // frames that showed the 3D board,
    draws:    i64                                   = 0,     // those that drew it,
    shadows:  i64                                   = 0,     // and the shadow map;
    pulses:   i64                                   = 0,     // those that changed only the pulsing marks
    setup_ms: f64                                   = 0.0,   // the renderer's setup,
    apply_ms: f64                                   = 0.0,   // and the theme's bake and photograph
    first_ms: f64                                   = 0.0,   // the first frame drawn, waited for
    timed:    bool                                  = false, // --bench: the first frame waited for and timed
    warm:     int2                                  = int2 { 0, 0 }, // the size prepare() drew at
    prep_ms:  f64[3]                                = [0.0; 3],      // prepare()'s steps: setup, theme, draw
    bench:    Bench                                 = Bench {},
}

// --bench N (measuring, task 015): N frames drawing the 3D board and its shadow map, as
// while a piece moves, each submitted and waited for; N drawing the board alone, waited
// for; N as the loop draws them, frame to frame; then N as a pulsing ring draws them, a
// ring round every piece: the kept depth's pass, waited for, and the screen's part (the
// backdrop, the image, the rings over it), waited for, and that part without the rings.
// Times in seconds.
struct Bench {
    n:     i64         = 0,
    i:     i64         = 0,
    cpu:   f64[..1024] = [],
    all:   f64[..1024] = [],
    pass:  f64[..1024] = [],
    gap:   f64[..1024] = [],
    depth: f64[..1024] = [],
    over:  f64[..1024] = [],
    plain: f64[..1024] = [],
    last:  f64         = 0.0,
}

let BENCH_PHASES = 4;

fn median(xs: f64[..1024]&) -> f64 {
    guard xs.len > 0 else { return 0.0; }
    sort(xs[..xs.len]);
    return xs[xs.len / 2] * 1000.0;
}

// Whether the bench has timed all its frames; it prints them then.
fn bench_done(d: Drawer&) -> bool {
    let b .= d.bench;
    guard b.n > 0 && b.i >= BENCH_PHASES * b.n else { return false; }
    // The bake again, warm: its pipeline made.
    for k in 2 {
        let t0 = clock();
        render3d::bake_surfaces(d.gpu, k == 0, k == 1);
        print("bench3d: bake warm, ", if k == 0 { "plan" } else { "frame map" }, " ", (clock() - t0) * 1000.0, " ms");
    }
    print("bench3d: setup ", d.setup_ms, " ms, theme applied ", d.apply_ms, " ms (bake ", d.gpu.bake_ms,
          " ms, photograph ", d.gpu.photo_ms, " ms), first frame ", d.first_ms, " ms");
    print("bench3d: ", d.size.x, "x", d.size.y, " with the shadow map: cpu ", median(b.cpu),
          " ms, cpu+gpu waited ", median(b.all), " ms; the pass alone waited ", median(b.pass),
          " ms; presented frame to frame ", median(b.gap), " ms (", b.n, " frames each)");
    print("bench3d: pulsing, a ring round every piece: the kept depth ", median(b.depth),
          " ms waited; the screen's part with the rings ", median(b.over), " ms waited, without ", median(b.plain),
          " ms");
    return true;
}

// The look for the app's theme, the season's: autumn's wood, winter's stone, spring's
// birch, summer's sunset (its variant `summer`); the photograph is the theme's own.
fn look_of(kind: i64, summer: i64) -> i64 {
    return if kind == theme::STONE { looks::WINTER } else if kind == theme::BIRCH { looks::SPRING }
           else if kind == theme::SUNSET { looks::summer_look(summer) } else { looks::AUTUMN };
}

// The renderer set up: its meshes, buffers, pipelines, and the baked surfaces' targets.
fn set_up(d: Drawer&) {
    let t0 = clock();
    render3d::setup(d.gpu);
    render3d::choose(d.gpu, d.wood, d.marble, d.spring);
    d.ready = true;
    d.setup_ms = (clock() - t0) * 1000.0;
}

// The look for the app's theme `kind` put on the board of n squares a side: its
// surfaces baked (their pipeline made the first time), its photograph blurred.
fn put_theme(d: Drawer&, kind: i64, n: i64) {
    let t0 = clock();
    d.kind = kind;
    d.n = n;
    let look = look_of(kind, d.summer);
    // --wood's model if given, else the look's own, else the renderer's; each look's
    // finish for its model (looks::finish_for).
    let shown = looks::shown(look, d.gpu.spring);
    let own = looks::wood_for(shown);
    let wood = if d.wood >= 0 { d.wood } else if own >= 0 { own } else { render3d::WOOD_MODEL };
    render3d::choose(d.gpu, wood, -1);
    d.gpu.finish = looks::finish_for(shown, d.gpu.wood);
    render3d::apply(d.gpu, look, n, kind);
    d.apply_ms = (clock() - t0) * 1000.0;
}

// Whether the 3D board is ready to draw for the app's theme `kind` on n squares a side
// at `size`, with nothing left to set up, bake, or make.
fn prepared(d: Drawer&, kind: i64, n: i64, size: int2) -> bool {
    let drawn = (d.warm.x == size.x && d.warm.y == size.y) || (d.size.x == size.x && d.size.y == size.y);
    return d.ready && d.kind == kind && d.n == n && drawn;
}

// One step of getting the 3D board ready before it is chosen (settings, where the Board
// row is): the setup, then the theme (the bake, its pipeline made, and the photograph),
// then a draw of the bare board into the kept image at `size`, which makes the pass's
// targets and pipelines. Each a frame of its own, so the screen keeps drawing between
// them; what the first frame on the 3D board would otherwise do at once (about 1.1 s on
// the Pixel 7a by task 015's numbers). Times each step (prep_ms).
fn prepare(d: Drawer&, kind: i64, n: i64, size: int2) {
    guard !prepared(d, kind, n, size) else { return; }
    if !d.ready {
        set_up(d);
        d.prep_ms[0] = d.setup_ms;
        return;
    }
    if d.kind != kind || d.n != n {
        put_theme(d, kind, n);
        d.prep_ms[1] = d.apply_ms;
        return;
    }
    let t0 = clock();
    render3d::draw(d.gpu, gfx::mat4_identity, float3 { 0.0, 1.0, 0.0 }, gfx::Texture { 0 }, size, false, false);
    d.warm = size;
    d.prep_ms[2] = (clock() - t0) * 1000.0;
}

// Everything the 3D board holds on the GPU given back (leaving settings with the board
// still flat), the flags kept; prepare() or frame() sets it up again.
fn drop(d: Drawer&) {
    guard d.ready else { return; }
    render3d::release(d.gpu);
    d = Drawer { wood: d.wood, marble: d.marble, summer: d.summer, spring: d.spring, timed: d.timed, .. };
}

// Draws the frame board::fill left in b, on the flat layout l, seen through v, into the
// kept image if anything it shows changed; the app's theme `kind`, the screen `size`.
// `which` tells the boards apart (the game's, a puzzle's, settings' preview). While
// `hold` (a transition) the image is drawn again only for another view or board.
fn frame(d: Drawer&, b: board::Board&, l: board::Layout, v: view3d::View, now: f64, size: int2, kind: i64,
         which: i64 = 0, hold: bool = false) {
    var force = false;
    let t0 = clock();
    if !d.ready {
        set_up(d);
        force = true;
    }
    if kind != d.kind || l.n != d.n {
        put_theme(d, kind, l.n);
        force = true;
    }
    let bn .= d.bench;
    let phase = if bn.n > 0 && bn.i < BENCH_PHASES * bn.n { bn.i / bn.n } else { -1 };
    if phase == 2 {
        if bn.i > 2 * bn.n { bn.gap.push(t0 - bn.last); }
        bn.last = t0;
    }
    if size.x != d.size.x || size.y != d.size.y {
        d.size = size;
        force = true;
    }
    d.frames++;
    d.redraw = false;
    d.shadow = false;
    if phase == 3 {
        bench_pulse(d, b, l, v, now, size);
        return;
    }
    guard force || phase >= 0 || !hold || which != d.which || !view3d::same_view(d.drawn.view, v) else { return; }
    d.which = which;
    view3d::fill(d.scene, b, l, v, now);
    let c = view3d::changes(d.drawn, d.scene);
    // The board turned under the light (a hot-seat turn): the light turns with it, so it
    // keeps its place on screen, and the shadows are drawn again.
    let turned = v.turn != d.gpu.turn;
    d.redraw = force || phase >= 0 || c & view3d::DRAW != 0 || turned;
    d.shadow = force || phase == 0 || phase == 2 || c & view3d::SHADOW != 0 || turned;
    if !d.redraw {
        // Only the pulsing marks moved: show() draws them at their new phase.
        if c & view3d::MARKS != 0 {
            d.drawn.pulse = d.scene.pulse;
            d.pulses++;
        }
        return;
    }
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
    render3d::draw(d.gpu, vp, v.eye, gfx::Texture { 0 }, size, false, false, s.pulsing);
    d.drawn = d.scene;
    if phase == 0 || phase == 1 {
        let t2 = clock();
        gfx::flush();
        if phase == 0 { bn.cpu.push(t2 - t0); bn.all.push(clock() - t0); }
        else { bn.pass.push(clock() - t0); }
    }
    if phase >= 0 { bn.i++; }
    if d.draws == 1 && d.timed {
        gfx::flush();
        d.first_ms = (clock() - t0) * 1000.0 - d.setup_ms - d.apply_ms;
    }
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
    if d.drawn.pulsing { render3d::marks_over(d.gpu, d.drawn.pulse, whole, min(fade, 1.0), size); }
}

// The bench's last phase: its first frame draws the board with a pulsing ring round every
// piece and keeps its depth; each frame then times the kept depth's pass, and the
// screen's part of a pulsing frame with the rings and without, each waited for.
fn bench_pulse(d: Drawer&, b: board::Board&, l: board::Layout, v: view3d::View, now: f64, size: int2) {
    let bn .= d.bench;
    if bn.i == 3 * bn.n {
        view3d::fill(d.scene, b, l, v, now);
        let s .= d.scene;
        for i in 100 { if s.squares[i].w > 0.5 { s.field[i].z = 1.0; } }
        s.pulsing = true;
        d.upload.clear();
        for x in s.inst { d.upload.push(x); }
        render3d::place(d.gpu, d.upload[..d.upload.len], d.alphas[..0], s.squares[..], s.field[..], s.lit[..],
                        s.selected, s.dim, true);
        let m = view3d::matrix(v, size.x, size.y);
        render3d::draw(d.gpu, gfx::mat4 { c0: m.c0, c1: m.c1, c2: m.c2, c3: m.c3 }, v.eye, gfx::Texture { 0 }, size,
                       false, false, true);
        d.drawn = d.scene;
        d.draws++;
        d.redraw = true;
        gfx::flush();
    }
    let t0 = clock();
    render3d::draw_depth(d.gpu);
    gfx::flush();
    let t1 = clock();
    for rings in 2 {
        let t2 = clock();
        gfx::begin_pass(gfx::screen(), gfx::Texture { 0 }, float4 { 0.0, 0.0, 0.0, 1.0 });
        render3d::backdrop(d.gpu, 1.0, size);
        render3d::show(d.gpu, float4 { 0.0, 0.0, size.x, size.y }, float4 { 0.0, 0.0, size.x, size.y }, 1.0, size);
        if rings == 0 {
            render3d::marks_over(d.gpu, d.scene.pulse, float4 { 0.0, 0.0, size.x, size.y }, 1.0, size);
        }
        gfx::end_pass();
        gfx::flush();
        if rings == 0 { bn.over.push(clock() - t2); } else { bn.plain.push(clock() - t2); }
    }
    bn.depth.push(t1 - t0);
    bn.i++;
}
