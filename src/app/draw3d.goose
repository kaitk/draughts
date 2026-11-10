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
// The renderer is made ready only when the 3D board is needed, a step a frame (prepare:
// its setup, the theme's bake in bands and its photograph, its pipelines), so the screen
// keeps drawing and answering; meanwhile the shell shows a still mark in the board's place
// and leaves taps on it alone (shell's ready3d), and once ready the board fades in. A new
// theme or board size takes the theme's steps again, the old image shown until they are
// done, eased towards grey and dimmer meanwhile so it reads as changing, and the new
// one's first image eased back from there (grey: a uniform of the shader that lays the
// image, no drawing again). The board back to flat gives all of it back (drop).
namespace draw3d;
import std;
import vec;
import gfx;

struct Drawer {
    gpu:       render3d::Gpu                         = default<render3d::Gpu>(),
    ready:     bool                                  = false,
    kind:      i64                                   = -1, // the app's theme the board was set up with
    plain:     bool                                  = false, // and whether behind it the plain fade
    which:     i64                                   = -1, // the board drawn (the shell's which())
    n:         i64                                   = 0,
    wood:      i64                                   = -1, // --wood, --marble: -1 the renderer's own
    marble:    i64                                   = -1,
    summer:    i64                                   = 0,  // --summer: summer's variant (looks::SUMMERS)
    spring:    i64                                   = -1, // --spring: spring's look, -1 the renderer's own
    size:      int2                                  = int2 { 0, 0 },
    scene:     view3d::Scene                         = view3d::Scene {}, // this frame's
    drawn:     view3d::Scene                         = view3d::Scene {}, // the last one drawn
    upload:    float4[..2 * render3d::MAX_INSTANCES] = [],
    alphas:    f32[..render3d::MAX_INSTANCES]        = [],    // the fading instances' opacity, last in upload
    redraw:    bool                                  = false, // this frame drew the 3D board,
    shadow:    bool                                  = false, // and the shadow map first
    frames:    i64                                   = 0,     // frames that showed the 3D board,
    draws:     i64                                   = 0,     // those that drew it,
    shadows:   i64                                   = 0,     // and the shadow map;
    pulses:    i64                                   = 0,     // those that changed only the pulsing marks
    setup_ms:  f64                                   = 0.0,   // the renderer's setup,
    apply_ms:  f64                                   = 0.0,   // and prepare()'s steps in all, waited
    first_ms:  f64                                   = 0.0,   // the first frame drawn, waited for
    timed:     bool                                  = false, // --bench: the first frame waited for and timed
    themed:    i64                                   = 0,     // prepare()'s next theme step (THEME_STEPS: done)
    warmed:    i64                                   = 0,     // and its next pipeline (WARM_STEPS: done)
    prep_ms:   f64[..48]                             = [],    // each prepare() step's time
    fresh:     bool                                  = false, // just made ready: draw all again
    appear_at: f64                                   = -1.0,  // when its first image showed, -1 none yet
    grey_at:   f64                                   = -1.0,  // when the image began easing grey or back, -1 settled
    grey_from: f32                                   = 0.0,   // from how grey
    grey_to:   f32                                   = 0.0,   // to how grey: 1 while a new theme is prepared
    bench:     Bench                                 = Bench {},
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

fn median(xs: f64[..1024]&) -> f64 { return percentile(xs, 50); }

// The time p percent of xs take at most, in ms (sorts xs).
fn percentile(xs: f64[..1024]&, p: i64) -> f64 {
    guard xs.len > 0 else { return 0.0; }
    sort(xs[..xs.len]);
    return xs[min(xs.len * p / 100, xs.len - 1)] * 1000.0;
}

// Frames presented frame to frame, gaps in seconds: "avg A / 1% low L fps", the average
// over their whole time and the rate of the 99th percentile's gap.
fn rates(line: u8[>..]&, gaps: f64[..1024]&) {
    var sum = 0.0;
    for x in gaps { sum += x; }
    let avg = if sum > 0.0 { gaps.len / sum } else { 0.0 };
    let p99 = percentile(gaps, 99);
    format(line, "avg ", floor(avg * 10.0 + 0.5) / 10.0, " / 1% low ",
           floor((if p99 > 0.0 { 1000.0 / p99 } else { 0.0 }) * 10.0 + 0.5) / 10.0, " fps");
}

// A frame's times waited, in seconds: "P50 a / P99 b ms".
fn spread(line: u8[>..]&, xs: f64[..1024]&) {
    format(line, "P50 ", floor(percentile(xs, 50) * 100.0 + 0.5) / 100.0, " / P99 ",
           floor(percentile(xs, 99) * 100.0 + 0.5) / 100.0, " ms");
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
    var longest = 0.0;
    for ms in d.prep_ms { longest = max(longest, ms); }
    print("bench3d: prepared in ", d.prep_ms.len, " steps, ", d.apply_ms, " ms in all (setup ", d.setup_ms,
          " ms, the longest step ", longest, " ms), first frame ", d.first_ms, " ms");
    print("bench3d: ", d.size.x, "x", d.size.y, " with the shadow map: cpu ", median(b.cpu),
          " ms, cpu+gpu waited ", median(b.all), " ms; the pass alone waited ", median(b.pass),
          " ms; presented frame to frame ", median(b.gap), " ms (", b.n, " frames each)");
    var line: u8[>..] = [];
    format(line, "bench3d: summary, waited with the shadow map ");
    spread(line, b.all);
    format(line, "; presented ");
    rates(line, b.gap);
    print(line);
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

// The look for the app's theme `kind`, with its wood: --wood's model if given, else the
// look's own, else the renderer's; each look's finish for its model (looks::finish_for).
fn choose_look(d: Drawer&, kind: i64) -> i64 {
    let look = look_of(kind, d.summer);
    let shown = looks::shown(look, d.gpu.spring);
    let own = looks::wood_for(shown);
    let wood = if d.wood >= 0 { d.wood } else if own >= 0 { own } else { render3d::WOOD_MODEL };
    render3d::choose(d.gpu, wood, -1);
    d.gpu.finish = looks::finish_for(shown, d.gpu.wood);
    return look;
}

// Whether the 3D board is ready to draw for the app's theme `kind` on n squares a side,
// with the photograph or the `plain` fade behind it: set up, baked for them, its
// pipelines made. Only the targets the size of the screen are left for its first frame
// (render3d::targets).
fn ready(d: Drawer&, kind: i64, n: i64, plain: bool) -> bool {
    return d.ready && d.kind == kind && d.n == n && d.plain == plain && d.themed == render3d::THEME_STEPS
           && d.warmed == render3d::WARM_STEPS;
}

// The theme's steps that put its photograph on (render3d::photo_part), from the first:
// all a change between the photograph and the plain fade takes again.
fn photo_steps() -> i64 { return 2 + render3d::PLAN_BANDS + render3d::FRAME_BANDS; }

// Whether an image of the board shows (drawn since it was set up): while a new theme is
// prepared it stays; with none, the board's place shows the shell's still mark.
fn shows(d: Drawer&) -> bool { d.appear_at >= 0.0 }

// Whether the board is fading in at `now`, so the app draws on.
let APPEAR = 0.3;
fn appearing(d: Drawer&, now: f64) -> bool { d.appear_at >= 0.0 && now < d.appear_at + APPEAR }

// How grey the image shows at `now` (render3d::show's grey): it eases to 1 over GREY once a
// new theme's steps start over it, and back to 0 over APPEAR from the new theme's first
// image, from wherever it was.
let GREY = 0.2;
fn grey_span(d: Drawer&) -> f64 { if d.grey_to > d.grey_from { GREY } else { APPEAR } }
fn grey(d: Drawer&, now: f64) -> f32 {
    guard d.grey_at >= 0.0 else { return d.grey_to; }
    let k = render3d::ease(0.0, 1.0, clamp((now - d.grey_at) / grey_span(d), 0.0, 1.0) as f32);
    return d.grey_from + (d.grey_to - d.grey_from) * k;
}
fn grey_towards(d: Drawer&, to: f32, now: f64) {
    d.grey_from = grey(d, now);
    d.grey_to = to;
    d.grey_at = now;
}

// Whether the image is easing grey or back, so the app draws on; show() settles it once
// a frame has drawn its end.
fn greying(d: Drawer&) -> bool { d.grey_at >= 0.0 }

// One step of getting the 3D board ready, each a frame of its own so the screen keeps
// drawing and answering: the setup; the theme in render3d::THEME_STEPS (the bake's
// pipeline made, the bake in bands, the photograph's pipelines, the photograph in three
// parts); the pass's pipelines in render3d::WARM_STEPS. What the first frame on the 3D
// board did at once before (about 1.1 s on the Pixel 7a by task 015's numbers). A new
// theme or size takes the theme's steps again. Each step is waited for (gfx::flush), so
// its GPU work stays in its own frame, and timed (prep_ms).
fn prepare(d: Drawer&, kind: i64, n: i64, plain: bool, now: f64) {
    guard !ready(d, kind, n, plain) else { return; }
    let t0 = clock();
    if !d.ready {
        set_up(d);
    } else if d.kind != kind || d.n != n || d.plain != plain || d.themed < render3d::THEME_STEPS {
        if d.kind != kind || d.n != n {
            // A new theme (or one changed partway) starts its steps again, the image
            // shown meanwhile easing grey.
            if shows(d) && d.grey_to < 1.0 { grey_towards(d, 1.0, now); }
            d.kind = kind;
            d.n = n;
            d.themed = 0;
        }
        if d.plain != plain {
            // The photograph or the plain fade behind the same board: only the
            // photograph's steps again, unless a theme's are under way.
            d.plain = plain;
            d.themed = min(d.themed, photo_steps());
        }
        let t = theme::get(kind);
        d.gpu.plain = plain;
        d.gpu.fade = [t.fade_top, t.fade_low, t.fade_light];
        let look = if d.themed == 0 { choose_look(d, kind) } else { d.gpu.look };
        render3d::theme_step(d.gpu, look, n, kind, d.themed);
        d.themed++;
    } else {
        render3d::warm(d.gpu, d.warmed);
        d.warmed++;
    }
    gfx::flush();
    let ms = (clock() - t0) * 1000.0;
    d.apply_ms += ms;
    if d.prep_ms.len < 48 { d.prep_ms.push(ms); }
    // Done: the next frame draws the board, its shadow map too.
    if ready(d, kind, n, plain) { d.fresh = true; }
}

// Everything the 3D board holds on the GPU given back (the board back to flat), the
// flags kept; the next frame that needs it prepares it again.
fn drop(d: Drawer&) {
    guard d.ready else { return; }
    render3d::release(d.gpu);
    d = Drawer { wood: d.wood, marble: d.marble, summer: d.summer, spring: d.spring, timed: d.timed, .. };
}

// Draws the frame board::fill left in b, on the flat layout l, seen through v, into the
// kept image if anything it shows changed; the app's theme `kind` with the photograph or
// the `plain` fade behind it, the screen `size`. `which` tells the boards apart (the
// game's, a puzzle's, settings' preview). While `hold` (a transition) the image is drawn
// again only for another view or board.
fn frame(d: Drawer&, b: board::Board&, l: board::Layout, v: view3d::View, now: f64, size: int2, kind: i64,
         plain: bool, which: i64 = 0, hold: bool = false) {
    let t0 = clock();
    d.redraw = false;
    d.shadow = false;
    if !ready(d, kind, l.n, plain) {
        // A step of getting ready instead; the image already shown (a theme changing)
        // stays, else the shell's still mark shows.
        prepare(d, kind, l.n, plain, now);
        d.frames++;
        return;
    }
    var force = d.fresh;
    d.fresh = false;
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
            d.drawn.next = d.scene.next;
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
    if d.appear_at < 0.0 { d.appear_at = now; }
    // A new theme's first image: back from grey.
    if d.grey_to > 0.0 { grey_towards(d, 0.0, now); }
    if phase == 0 || phase == 1 {
        let t2 = clock();
        gfx::flush();
        if phase == 0 { bn.cpu.push(t2 - t0); bn.all.push(clock() - t0); }
        else { bn.pass.push(clock() - t0); }
    }
    if phase >= 0 { bn.i++; }
    if d.draws == 1 && d.timed {
        gfx::flush();
        d.first_ms = (clock() - t0) * 1000.0;
    }
}

// Lays the kept image over the screen's open pass (the app's photograph drawn in it, or
// cleared): the renderer's backdrop first, as opaque as `blur` (1 behind the game and a
// puzzle, 0 behind home and settings, between in a transition), then the board, the
// bounds it was drawn at (the view's rect) put at `place`, as opaque as `fade`. Both
// fade in over APPEAR from the board's first image at `now`; with none yet, nothing.
fn show(d: Drawer&, blur: f32, place: float4, fade0: f32, size: int2, now: f64) {
    guard shows(d) else { return; }
    let k0 = clamp((now - d.appear_at) / APPEAR, 0.0, 1.0) as f32;
    let grey = grey(d, now);
    if d.grey_at >= 0.0 && now >= d.grey_at + grey_span(d) { d.grey_at = -1.0; }
    let fade = fade0 * k0;
    if blur > 0.0 { render3d::backdrop(d.gpu, min(blur, 1.0) * k0, size); }
    guard fade > 0.0 else { return; }
    // The whole image, the board's soft shadow round it too, moved and scaled as its
    // bounds are: at rest exactly as drawn.
    let r = d.drawn.view.rect;
    guard r.z > 0.0 else { return; }
    let k = place.z / r.z;
    let whole = float4 { place.x - r.x * k, place.y - r.y * k, size.x * k, size.y * k };
    render3d::show(d.gpu, float4 { 0.0, 0.0, size.x, size.y }, whole, min(fade, 1.0), size, grey);
    if d.drawn.pulsing { render3d::marks_over(d.gpu, d.drawn.pulse, d.drawn.next, whole, min(fade, 1.0), size); }
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
            render3d::marks_over(d.gpu, d.scene.pulse, d.scene.next, float4 { 0.0, 0.0, size.x, size.y }, 1.0, size);
        }
        gfx::end_pass();
        gfx::flush();
        if rings == 0 { bn.over.push(clock() - t2); } else { bn.plain.push(clock() - t2); }
    }
    bn.depth.push(t1 - t0);
    bn.i++;
}
