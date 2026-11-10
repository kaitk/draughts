// The 3D board's place in the goose-ngfx build (task 065): not drawn yet. Its renderer
// (src/render3d/) is ported in a later step; until then the board is never ready, so the
// shell shows its still mark in the board's place, and this keeps src/app/draw3d.goose's
// API that the renderer and the development flags (dev.goose) use.
namespace draw3d;
import std;
import vec;

struct Drawer {
    ready:     bool    = false,
    wood:      i64     = -1,
    marble:    i64     = -1,
    summer:    i64     = 0,
    spring:    i64     = -1,
    frames:    i64     = 0,
    draws:     i64     = 0,
    shadows:   i64     = 0,
    pulses:    i64     = 0,
    timed:     bool    = false,
    live:      bool    = false,
    prep_ms:   f64[..48] = [],
    fresh:     bool    = false,
    bench:     Bench   = Bench {},
}

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

fn bench_done(d: Drawer&) -> bool { false }
fn ready(d: Drawer&, kind: i64, n: i64, plain: bool) -> bool { false }
fn shows(d: Drawer&) -> bool { false }
fn appearing(d: Drawer&, now: f64) -> bool { false }
fn greying(d: Drawer&) -> bool { false }
fn prepare(d: Drawer&, kind: i64, n: i64, plain: bool, now: f64) {}
fn drop(d: Drawer&) {}
fn frame(d: Drawer&, b: board::Board&, l: board::Layout, v: view3d::View, now: f64, size: int2, kind: i64,
         plain: bool, which: i64 = 0, hold: bool = false) {
    d.frames++;
}
fn show(d: Drawer&, blur: f32, place: float4, fade0: f32, size: int2, now: f64) {}
