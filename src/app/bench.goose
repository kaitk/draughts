// --bench N (docs/development.md, "Time the 3D board"): the loop calls frame() here in
// place of render::frame, so the drawing holds nothing of the measuring. The 3D board,
// once drawn 2 s after the launch, times N frames with its shadow map, N without, N as
// the loop draws them, and N with a pulsing ring round every piece; the flat board N
// whole frames, then N as the loop draws them. tools/perf/device_perf.sh, ios_perf.py,
// windows_perf.py, and mac_gpu_time.py read the lines it prints.
namespace bench;
import std;
import vec;

// One board's frames' times, in seconds.
struct Times {
    n:     i64          = 0,
    i:     i64          = 0,
    cpu:   f64[..1024]  = [],
    all:   f64[..1024]  = [],
    pass:  f64[..1024]  = [],
    gap:   f64[..1024]  = [],
    depth: f64[..1024]  = [],
    over:  f64[..1024]  = [],
    plain: f64[..1024]  = [],
    last:  f64          = 0.0,
    into:  gpu::Texture = gpu::Texture { 0 },  // where the pulse phase draws (be.bench_target)
}

let PHASES = 4;

struct Bench {
    d3:       Times = Times {},
    flat:     Times = Times {},
    flat_on:  bool  = false,    // this frame is one of the flat board's bench
    first_ms: f64   = 0.0,      // the 3D board's first frame, waited for
}

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

// Starts the bench once it is due; true while it times frames, which the loop then draws
// whether or not anything changed.
fn start(b: Bench&, f: flags::Flags&, raised: bool, draws3d: i64, now: f64) -> bool {
    if f.bench > 0 && raised && draws3d > 0 && now > 2.0 && b.d3.n == 0 { b.d3.n = f.bench; }
    b.flat_on = f.bench > 0 && !raised && now > 2.0 && b.flat.i < 2 * f.bench;
    return b.d3.n > 0 || b.flat_on;
}

// Whether the 3D bench waits for each frame now: its first two phases do, and aren't paced.
fn waited3d(b: Bench&) -> bool { b.d3.n > 0 && b.d3.i < 2 * b.d3.n }

fn draw3d_now(r: render::Renderer&, fr: render::Frame&) {
    backend::with() { be => draw3d::frame(be, r.d3, fr.board, fr.layout, fr.view, fr.now, fr.size, r.d.kind, r.d.scene.plain, fr.which, fr.hold) }
}

// render::frame, the bench's phase timed around it or ahead of it.
fn frame(b: Bench&, f: flags::Flags&, r: render::Renderer&, fr: render::Frame&) {
    let d3 .= r.d3;
    let bn .= b.d3;
    let ready = fr.raised && draw3d::ready(d3, r.d.kind, fr.layout.n, r.d.scene.plain);
    if ready && d3.draws == 0 {
        let t0 = clock();
        draw3d_now(r, fr);
        render::wait();
        b.first_ms = (clock() - t0) * 1000.0;
    }
    let phase = if ready && bn.n > 0 && bn.i < PHASES * bn.n { bn.i / bn.n } else { -1 };
    if phase == 0 || phase == 1 {
        let t0 = clock();
        if phase == 0 { d3.fresh = true; } else { d3.again = true; }
        draw3d_now(r, fr);
        let t1 = clock();
        render::wait();
        if phase == 0 {
            bn.cpu.push(t1 - t0);
            bn.all.push(clock() - t0);
        } else {
            bn.pass.push(clock() - t0);
        }
        bn.i++;
    } else if phase == 2 {
        // The presented frames' start and end, for tools/perf/device_perf.sh.
        let t0 = clock();
        if bn.i == 2 * bn.n { print("bench3d: presenting"); }
        if bn.i > 2 * bn.n { bn.gap.push(t0 - bn.last); }
        bn.last = t0;
        d3.fresh = true;
        bn.i++;
    } else if phase == 3 {
        if bn.i == 3 * bn.n { print("bench3d: presented"); }
        pulse(b, r, fr);
        // The image the pulse drew stays as it is: the frame only shows it.
        fr.hold = true;
    }
    guard b.flat_on && !fr.raised else {
        render::frame(r, fr);
        return;
    }
    let t0 = clock();
    render::frame(r, fr);
    let fl .= b.flat;
    if fl.i < f.bench {
        fl.cpu.push(clock() - t0);
        render::wait();
        fl.all.push(clock() - t0);
    } else {
        if fl.i == f.bench { print("bench2d: presenting"); }
        if fl.i > f.bench { fl.gap.push(t0 - fl.last); }
        fl.last = t0;
    }
    fl.i++;
}

// The last phase: the first frame draws a pulsing ring round every piece and keeps its
// depth; each frame then times the kept depth's pass, and the screen's part with the
// rings and without, each waited for, drawn where be.bench_target says.
fn pulse(b: Bench&, r: render::Renderer&, fr: render::Frame&) { backend::with() { be => pulse_on(be, b, r, fr) } }

fn pulse_on<B>(be: B&, b: Bench&, r: render::Renderer&, fr: render::Frame&) {
    let d .= r.d3;
    let bn .= b.d3;
    let size = fr.size;
    if bn.i == 3 * bn.n {
        view3d::build_scene(d.scene, fr.board, fr.layout, fr.view, fr.now);
        let s .= d.scene;
        for i in 100 { if s.squares[2 * i].w > 0.5 { s.field[i].z = 1.0; } }
        s.pulsing = true;
        d.upload.clear();
        for x in s.inst { d.upload.push(x); }
        render3d::place(be.r3d, d.gpu, d.upload[..d.upload.len], d.alphas[..0], s.squares[..], s.field[..], s.lit[..],
                        s.selected, s.dim, true);
        let m = view3d::matrix(fr.view, size.x, size.y);
        render3d::draw(be.r3d, d.gpu, render3d::Mat { c0: m.c0, c1: m.c1, c2: m.c2, c3: m.c3 }, fr.view.eye, gpu::no_texture(),
                       size, false, false, true);
        d.drawn = d.scene;
        d.draws++;
        d.redraw = true;
        be.flush();
    }
    let into = be.bench_target(bn.into, size);
    let t0 = clock();
    be.r3d.draw_depth(d.gpu);
    be.flush();
    let t1 = clock();
    for rings in 2 {
        let t2 = clock();
        be.begin_pass(into, float4 { 0.0, 0.0, 0.0, 1.0 });
        be.r3d.backdrop(d.gpu, 1.0, size);
        be.r3d.show(d.gpu, float4 { 0.0, 0.0, size.x, size.y }, float4 { 0.0, 0.0, size.x, size.y }, 1.0, size);
        if rings == 0 {
            be.r3d.marks_over(d.gpu, d.scene.pulse, d.scene.next, -1.0, float4 { 0.0, 0.0, size.x, size.y }, 1.0, size);
        }
        be.end_pass();
        be.flush();
        if rings == 0 { bn.over.push(clock() - t2); } else { bn.plain.push(clock() - t2); }
    }
    bn.depth.push(t1 - t0);
    bn.i++;
}

// Whether a bench has timed all its frames, printed then, and the loop should end.
fn done(b: Bench&, f: flags::Flags&, r: render::Renderer&, size: int2) -> bool {
    let bn .= b.d3;
    if bn.n > 0 && bn.i >= PHASES * bn.n {
        let d .= r.d3;
        // The bake again, warm: its pipeline made.
        for k in 2 {
            let t0 = clock();
            backend::with() { be => render3d::bake_surfaces(be.r3d, d.gpu, k == 0, k == 1) }
            print("bench3d: bake warm, ", if k == 0 { "plan" } else { "frame map" }, " ", (clock() - t0) * 1000.0, " ms");
        }
        var longest = 0.0;
        for ms in d.prep_ms { longest = max(longest, ms); }
        print("bench3d: prepared in ", d.prep_ms.len, " steps, ", d.apply_ms, " ms in all (setup ", d.setup_ms,
              " ms, the longest step ", longest, " ms), first frame ", b.first_ms, " ms");
        print("bench3d: ", d.size.x, "x", d.size.y, " with the shadow map: cpu ", median(bn.cpu),
              " ms, cpu+gpu waited ", median(bn.all), " ms; the pass alone waited ", median(bn.pass),
              " ms; presented frame to frame ", median(bn.gap), " ms (", bn.n, " frames each)");
        var line: u8[>..] = [];
        format(line, "bench3d: summary, waited with the shadow map ");
        spread(line, bn.all);
        format(line, "; presented ");
        rates(line, bn.gap);
        print(line);
        print("bench3d: pulsing, a ring round every piece: the kept depth ", median(bn.depth),
              " ms waited; the screen's part with the rings ", median(bn.over), " ms waited, without ",
              median(bn.plain), " ms");
        return true;
    }
    let fl .= b.flat;
    guard f.bench > 0 && fl.i >= 2 * f.bench else { return false; }
    print("bench2d: presented");
    var line: u8[>..] = [];
    format(line, "bench2d: summary, ", size.x, "x", size.y, ", ", f.bench, " frames each: cpu ", median(fl.cpu),
           " ms; waited ");
    spread(line, fl.all);
    format(line, "; presented ");
    rates(line, fl.gap);
    print(line);
    return true;
}
