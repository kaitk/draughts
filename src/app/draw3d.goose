// The game's 3D board, drawn by src/render3d/ from the scene the flat board's draw lists
// fill (view3d::build_scene). It is drawn into a kept image only when its scene, view,
// size, or theme changed; each frame lays that image under the UI, with the pulsing marks
// drawn over it (render3d::marks_over). It is made ready a step a frame (prepare), and a
// new theme shows the old image eased grey until done (docs/architecture/rendering.md).
namespace draw3d;
import std;
import vec;

struct Drawer {
    gpu:       render3d::Gpu                         = default<render3d::Gpu>(),
    ready:     bool                                  = false,
    aa:        i32                                   = render3d::AA, // --aa and the A key: render3d's AA_OFF..
    samples:   i32                                   = render3d::SAMPLES, // MSAA's, fewer on a slow device
    look:      i32                                   = render3d::SHADOW_9, // how the shadow is filtered (screen_shadow)
    side:      i64                                   = model3d::BAKE_SIDE, // the surfaces' side (screen_bake)
    kind:      i64                                   = -1, // the app's theme the board was set up with
    plain:     bool                                  = false, // and whether behind it the plain fade
    which:     i64                                   = -1, // the board drawn (the shell's which())
    n:         i64                                   = 0,
    wood:      i64                                   = -1, // --wood, --marble: -1 the renderer's own
    marble:    i64                                   = -1,
    summer:    i64                                   = -1, // --summer: summer's variant (looks::SUMMERS), -1 not given
    autumn:    i64                                   = -1, // --autumn, --winter: theirs (looks::AUTUMNS, WINTERS)
    winter:    i64                                   = -1,
    spring:    i64                                   = -1, // --spring: spring's look (looks::SPRINGS)
    want:      i64                                   = looks::MATERIAL_AUTO, // the material asked for (want_material)
    material:  i64                                   = looks::MATERIAL_AUTO, // and the one the board is set up with
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
    live:      bool                                  = false, // --keep off: the backdrop never kept (render3d's live)
    table:     i64                                   = -1,    // --table: the board on that table (tables::BOARD_WOOD..)
    themed:    i64                                   = 0,     // prepare()'s next theme step (THEME_STEPS: done)
    warmed:    i64                                   = 0,     // and its next pipeline (WARM_STEPS: done)
    prep_ms:   f64[..48]                             = [],    // each prepare() step's time
    fresh:     bool                                  = false, // just made ready: draw all again
    again:     bool                                  = false, // the image drawn again, its shadow map as it is (the bench)
    appear_at: f64                                   = -1.0,  // when its first image showed, -1 none yet
    grey_at:   f64                                   = -1.0,  // when the image began easing grey or back, -1 settled
    grey_from: f32                                   = 0.0,   // from how grey
    grey_to:   f32                                   = 0.0,   // to how grey: 1 while a new theme is prepared
}

// The look for the app's theme in the material asked for, unless a flag picks the
// season's variant (theme::WOOD.. number the seasons as looks::AUTUMN.. do).
fn look_of(kind: i64, d: Drawer&) -> i64 {
    if kind == theme::STONE && d.winter >= 0 { return looks::winter_look(d.winter); }
    if kind == theme::SUNSET && d.summer >= 0 { return looks::summer_look(d.summer); }
    if kind == theme::WOOD && d.autumn >= 0 { return looks::autumn_look(d.autumn); }
    if kind == theme::BIRCH && d.spring >= 0 { return looks::shown(looks::SPRING, d.spring); }
    return looks::of(kind, d.want);
}

// A new material prepares the board again, as a new theme does; the image shown turns
// grey at once, not when the steps start a frame or two later.
fn want_material(d: Drawer&, material: i64) {
    if material != d.want && material != d.material && shows(d) {
        d.grey_from = 1.0;
        d.grey_to = 1.0;
        d.grey_at = -1.0;
    }
    d.want = material;
}

fn set_up<B>(be: B&, d: Drawer&) {
    let t0 = clock();
    be.r3d.setup(d.gpu, render3d::SAMPLES, d.look);
    render3d::set_bake(d.gpu, d.side);
    be.r3d.set_aa(d.gpu, d.aa, d.samples);
    render3d::choose(d.gpu, d.wood, d.marble, d.spring);
    d.gpu.table = d.table >= 0;
    if d.table >= 0 { d.gpu.table_spec = tables::get(d.table); }
    d.ready = true;
    d.setup_ms = (clock() - t0) * 1000.0;
}

// The look for theme `kind`, with its wood: --wood's if given, else the look's own, else
// the renderer's.
fn choose_look(d: Drawer&, kind: i64) -> i64 {
    let look = look_of(kind, d);
    // Spring's birch is spring's look 0 to the renderer, whose own is the elven stone
    // (looks::shown); every other look is shown as it is.
    if look == looks::SPRING { d.gpu.spring = 0; }
    let shown = looks::shown(look, d.gpu.spring);
    let own = looks::wood_for(shown);
    let wood = if d.wood >= 0 { d.wood } else if own >= 0 { own } else { model3d::WOOD_MODEL };
    render3d::choose(d.gpu, wood, -1);
    d.gpu.finish = looks::finish_for(shown, d.gpu.wood);
    return look;
}

// Set up, baked for theme `kind` on n squares and the background, its pipelines made;
// only the screen-sized targets are left for its first frame.
fn ready(d: Drawer&, kind: i64, n: i64, plain: bool) -> bool {
    return d.ready && d.kind == kind && d.material == d.want && d.n == n && d.plain == plain
           && d.themed == model3d::THEME_STEPS && d.warmed == render3d::WARM_STEPS;
}

// The theme's steps up to and with its photograph's: what switching to or from the plain
// fade takes again.
fn photo_steps() -> i64 { return 2 + model3d::PLAN_BANDS + model3d::FRAME_BANDS + model3d::TABLE_BANDS; }

// Whether an image of the board shows; without one the shell shows a still mark.
fn shows(d: Drawer&) -> bool { d.appear_at >= 0.0 }

let APPEAR = 0.3;   // seconds the first image fades in
fn appearing(d: Drawer&, now: f64) -> bool { d.appear_at >= 0.0 && now < d.appear_at + APPEAR }

// How grey the image shows: easing to 1 over GREY while a new theme is prepared, and
// back to 0 over APPEAR from its first image.
let GREY = 0.2;
fn grey_span(d: Drawer&) -> f64 { if d.grey_to > d.grey_from { GREY } else { APPEAR } }
fn grey(d: Drawer&, now: f64) -> f32 {
    guard d.grey_at >= 0.0 else { return d.grey_to; }
    let k = model3d::ease(0.0, 1.0, clamp((now - d.grey_at) / grey_span(d), 0.0, 1.0) as f32);
    return d.grey_from + (d.grey_to - d.grey_from) * k;
}
fn grey_towards(d: Drawer&, to: f32, now: f64) {
    d.grey_from = grey(d, now);
    d.grey_to = to;
    d.grey_at = now;
}

// show() settles it once a frame has drawn its end.
fn greying(d: Drawer&) -> bool { d.grey_at >= 0.0 }

// One step of getting the 3D board ready, a frame each so the screen keeps answering:
// the setup, the theme's model3d::THEME_STEPS, the pass's render3d::WARM_STEPS. Each step
// is waited for, so its GPU work stays in its own frame.
fn prepare<B>(be: B&, d: Drawer&, kind: i64, n: i64, plain: bool, now: f64) {
    guard !ready(d, kind, n, plain) else { return; }
    let t0 = clock();
    if !d.ready {
        set_up(be, d);
    } else if d.kind != kind || d.material != d.want || d.n != n || d.plain != plain || d.themed < model3d::THEME_STEPS {
        if d.kind != kind || d.material != d.want || d.n != n {
            if shows(d) && d.grey_to < 1.0 { grey_towards(d, 1.0, now); }
            d.kind = kind;
            d.material = d.want;
            d.n = n;
            d.themed = 0;
        }
        if d.plain != plain {
            d.plain = plain;
            d.themed = min(d.themed, photo_steps());
        }
        let t = theme::get(kind);
        d.gpu.plain = plain;
        d.gpu.fade = [t.fade_top, t.fade_low, t.fade_light];
        let look = if d.themed == 0 { choose_look(d, kind) } else { d.gpu.look };
        render3d::theme_step(be.r3d, d.gpu, look, n, kind, d.themed);
        d.themed++;
    } else {
        be.r3d.warm(d.gpu, d.warmed);
        d.warmed++;
    }
    be.flush();
    let ms = (clock() - t0) * 1000.0;
    d.apply_ms += ms;
    if d.prep_ms.len < 48 { d.prep_ms.push(ms); }
    if ready(d, kind, n, plain) {
        d.fresh = true;
        cover(be, d);
    }
}

// What a Mac window shows around its last frame while its edge is dragged (resize.c):
// this board's backdrop.
let COVER = 512;    // resize.c's SIDE
fn cover<B>(be: B&, d: Drawer&) {
    guard draw::draughts_resize_covers() else { return; }
    let t = be.target(COVER, COVER);
    let screen = d.gpu.frame.screen;
    be.begin_pass(t, float4 { 0.0, 0.0, 0.0, 1.0 });
    be.r3d.backdrop(d.gpu, 1.0, int2 { COVER, COVER });
    be.end_pass();
    d.gpu.frame.screen = screen;
    draw::cover_with(be, t, float4 { 0.0, 0.0, 0.0, 1.0 });
    be.release(t);
}

// Gives back all the 3D board holds on the GPU, keeping the flags.
fn drop<B>(be: B&, d: Drawer&) {
    guard d.ready else { return; }
    be.r3d.release(d.gpu);
    d = Drawer { aa: d.aa, samples: d.samples, look: d.look, side: d.side, wood: d.wood, marble: d.marble, summer: d.summer, autumn: d.autumn, winter: d.winter,
                spring: d.spring, want: d.want, table: d.table, .. };
}

// The A key: the renderer's next antialiasing.
fn toggle_aa<B>(be: B&, d: Drawer&) {
    d.aa = be.r3d.aa_next(d.aa);
    print("3D board: antialiasing ", be.r3d.aa_name(d.aa));
    guard d.ready else { return; }
    be.r3d.set_aa(d.gpu, d.aa, d.samples);
    d.fresh = true;
}

// The 3D board can't keep up with the display (display.c): fewer MSAA samples from now on.
fn fewer_samples<B>(be: B&, d: Drawer&) {
    guard d.samples > render3d::FEW_SAMPLES else { return; }
    d.samples = render3d::FEW_SAMPLES;
    print("3D board: too slow for the display, ", d.samples, "x MSAA");
    guard d.ready && d.aa == render3d::AA_MSAA else { return; }
    be.r3d.set_aa(d.gpu, d.aa, d.samples);
    d.fresh = true;
}

// The shadow's filter taps for the device (render3d::SHADOW_4..16): fewer on Android,
// whose GPUs are slower, but 9 on a tablet, whose larger pieces show the 4's steps.
fn screen_shadow<B>(be: B&, d: Drawer&, look: i32) {
    guard look != d.look else { return; }
    d.look = look;
    guard d.ready else { return; }
    be.r3d.set_shadow(d.gpu, look);
    d.fresh = true;
}

// The surfaces' bake side: smaller on a phone, whose field spans at most about a thousand
// pixels. A change once ready (a foldable opened) bakes the theme again in its steps.
fn screen_bake(d: Drawer&, small: bool) {
    let side = if small { model3d::PHONE_BAKE_SIDE } else { model3d::BAKE_SIDE };
    guard side != d.side else { return; }
    d.side = side;
    guard d.ready else { return; }
    render3d::set_bake(d.gpu, side);
    d.themed = 0;
}

// What only drawing needs (the pass's targets, the kept backdrop and depth) is kept while
// the board is on screen, so a move after a pause draws at once, and given back once it
// isn't. The next draw makes them again.
fn release_targets_unless_shown<B>(be: B&, d: Drawer&, shown: bool) {
    guard d.ready && !shown && !render3d::resting(d.gpu) else { return; }
    render3d::release_targets(be.r3d, d.gpu);
}

// v seen from where its bounds are put at `place` (x, y, width; the height follows), as
// show() moves the image drawn through v: its scale and its center moved with them.
fn moved(v: view3d::View, place: float4) -> view3d::View {
    guard v.rect.z > 0.0 && place.z > 0.0 else { return v; }
    let k = place.z / v.rect.z;
    var m = v;
    m.k = v.k * k;
    m.c = float2 { place.x + (v.c.x - v.rect.x) * k, place.y + (v.c.y - v.rect.y) * k };
    m.rect = float4 { place.x, place.y, place.z, v.rect.w * k };
    return m;
}

// Draws b, seen through v, into the kept image if anything it shows changed. `which` tells
// the boards apart (the game's, a puzzle's, settings' preview). While `hold` (a
// transition) the image is drawn again only for another view or board, and show() moves
// it to `place`; but a board on the table is drawn again each frame through v moved there,
// as the table fills the screen round it wherever the board goes.
fn frame<B>(be: B&, d: Drawer&, b: board::Board&, l: board::Layout, v0: view3d::View, now: f64, size: int2, kind: i64,
         plain: bool, which: i64 = 0, hold0: bool = false, place: float4 = float4_0) {
    let on_table = d.gpu.table && hold0;
    let v = if on_table { moved(v0, place) } else { v0 };
    let hold = hold0 && !on_table;
    d.gpu.live = d.live;
    d.redraw = false;
    d.shadow = false;
    if !ready(d, kind, l.n, plain) {
        prepare(be, d, kind, l.n, plain, now);
        d.frames++;
        return;
    }
    // Back on screen after release_targets() with marks pulsing: the depth they test is
    // drawn again.
    var force = d.fresh || (d.drawn.pulsing && render3d::resting(d.gpu));
    let again = d.again;
    d.fresh = false;
    d.again = false;
    if size.x != d.size.x || size.y != d.size.y {
        d.size = size;
        force = true;
    }
    d.frames++;
    guard force || again || !hold || which != d.which || !view3d::same_view(d.drawn.view, v) else { return; }
    d.which = which;
    view3d::build_scene(d.scene, b, l, v, now);
    let c = view3d::changes(d.drawn, d.scene);
    // The board turned under the light (a hot-seat turn): the light turns with it, so it
    // keeps its place on screen, and the shadows are drawn again.
    let turned = v.turn != d.gpu.turn;
    d.redraw = force || again || c & view3d::DRAW != 0 || turned;
    d.shadow = force || c & view3d::SHADOW != 0 || turned;
    if !d.redraw {
        // Only the pulsing marks moved: show() draws them at their new phase.
        if c & view3d::MARKS != 0 {
            d.drawn.pulse = d.scene.pulse;
            d.drawn.next = d.scene.next;
            d.drawn.cursor = d.scene.cursor;
            d.pulses++;
        }
        return;
    }
    d.draws++;
    if d.shadow { d.shadows++; }
    // The opaque instances first, then the fading ones, which are drawn blended after.
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
    render3d::place(be.r3d, d.gpu, d.upload[..d.upload.len], d.alphas[..d.alphas.len], s.squares[..], s.field[..],
                    s.lit[..], s.selected, s.dim, d.shadow);
    let m = view3d::matrix(v, size.x, size.y);
    let vp = render3d::Mat { c0: m.c0, c1: m.c1, c2: m.c2, c3: m.c3 };
    render3d::draw(be.r3d, d.gpu, vp, v.eye, gpu::no_texture(), size, false, false, s.pulsing);
    d.drawn = d.scene;
    if d.appear_at < 0.0 { d.appear_at = now; }
    if d.grey_to > 0.0 { grey_towards(d, 0.0, now); }
}

// Lays the kept image in the screen's open pass: the backdrop as opaque as `blur` (1 in
// the game, 0 over home's photograph), then the board, its drawn bounds put at `place`,
// as opaque as `fade`. Both fade in over APPEAR from the first image.
fn show<B>(be: B&, d: Drawer&, blur: f32, place: float4, fade0: f32, size: int2, now: f64) {
    guard shows(d) else { return; }
    let k0 = clamp((now - d.appear_at) / APPEAR, 0.0, 1.0) as f32;
    let grey = grey(d, now);
    if d.grey_at >= 0.0 && now >= d.grey_at + grey_span(d) { d.grey_at = -1.0; }
    let fade = fade0 * k0;
    if blur > 0.0 { be.r3d.backdrop(d.gpu, min(blur, 1.0) * k0, size); }
    guard fade > 0.0 else { return; }
    // The whole image moved and scaled as its bounds are: at rest exactly as drawn.
    let r = d.drawn.view.rect;
    guard r.z > 0.0 else { return; }
    let k = place.z / r.z;
    let whole = float4 { place.x - r.x * k, place.y - r.y * k, size.x * k, size.y * k };
    be.r3d.show(d.gpu, float4 { 0.0, 0.0, size.x, size.y }, whole, min(fade, 1.0), size, grey);
    if d.drawn.pulsing { be.r3d.marks_over(d.gpu, d.drawn.pulse, d.drawn.next, d.drawn.cursor, whole, min(fade, 1.0), size); }
}
