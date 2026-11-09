// The players' badges' animals (task 038; rendering.md, "Controls"): each a silhouette in
// an SVG file of its own, assets/badges/<animal>.svg, embedded when the app is built and
// baked at start into a signed distance field, one CELL × CELL texel cell per animal,
// that the UI shader carves into a piece's top. Swapping an animal's art is replacing
// its file and building again.
//
// What a file may hold: a viewBox on the svg element, square or not (its longer side
// spans the cell, centred), and one or more paths filled together even-odd, each `d`
// of M, L, H, V, C, S, Q, T, A, and Z in either case. Transforms on the paths and their
// groups (translate, scale, matrix, rotate) are applied, as a tracer such as potrace
// writes them. Fill and stroke attributes are ignored: everything is one filled shape.
// No other elements (circle, rect, text, use) are read, and nothing outside a path.
//
// Pure functions over bytes, with no graphics, so the bake is tested headless.
namespace badges;
import std;
import vec;
import math;

let COUNT = 6;
let CELL = 96;              // texels a side of an animal's cell
let SPREAD = 12.0;          // texels the distance runs either side of the edge, saturating past it
let MAX_SEGS = 4096;        // straight pieces an animal's outline is flattened into, at most
let MAX_DEPTH = 8;          // nested groups

// The animals in players::ANIMALS's order, which a player's badge indexes.
let NAMES = ["fox", "hare", "bear", "owl", "frog", "hedgehog"];

// Animal k's SVG file, as it was when the app was built.
fn svg(k: i64) -> const u8[:] {
    if k == 0 { return embed_file("../../assets/badges/fox.svg"); }
    if k == 1 { return embed_file("../../assets/badges/hare.svg"); }
    if k == 2 { return embed_file("../../assets/badges/bear.svg"); }
    if k == 3 { return embed_file("../../assets/badges/owl.svg"); }
    if k == 4 { return embed_file("../../assets/badges/frog.svg"); }
    return embed_file("../../assets/badges/hedgehog.svg");
}

// An affine map: x' = a x + c y + e, y' = b x + d y + f, as SVG's matrix().
struct Affine { a: f32 = 1.0, b: f32 = 0.0, c: f32 = 0.0, d: f32 = 1.0, e: f32 = 0.0, f: f32 = 0.0 }

fn apply(m: Affine, p: float2) -> float2 {
    float2 { m.a * p.x + m.c * p.y + m.e, m.b * p.x + m.d * p.y + m.f }
}

// m then n: n applied first.
fn times(m: Affine, n: Affine) -> Affine {
    Affine { a: m.a * n.a + m.c * n.b, b: m.b * n.a + m.d * n.b, c: m.a * n.c + m.c * n.d,
             d: m.b * n.c + m.d * n.d, e: m.a * n.e + m.c * n.f + m.e, f: m.b * n.e + m.d * n.f + m.f }
}

// A shape's outline as straight pieces (x0, y0, x1, y1) in the viewBox's units, and the
// viewBox.
struct Shape {
    segs: float4[..MAX_SEGS] = [],
    box:  float4             = float4 { 0.0, 0.0, 0.0, 0.0 },
    full: bool               = false,   // pieces were left out: more than MAX_SEGS
}

fn is_space(c: u8) -> bool { c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ',' }

// The number in s at i, skipping separators before it; i moves past it. False when there
// is none.
fn number(s: const u8[:], i: i64&) -> f32, bool {
    while i < s.len && is_space(s[i]) { i++; }
    let from = i;
    if i < s.len && (s[i] == '-' || s[i] == '+') { i++; }
    var digits = false;
    while i < s.len && s[i] >= '0' && s[i] <= '9' { i++; digits = true; }
    if i < s.len && s[i] == '.' {
        i++;
        while i < s.len && s[i] >= '0' && s[i] <= '9' { i++; digits = true; }
    }
    guard digits else {
        i = from;
        return 0.0, false;
    }
    if i < s.len && (s[i] == 'e' || s[i] == 'E') {
        var j = i + 1;
        if j < s.len && (s[j] == '-' || s[j] == '+') { j++; }
        if j < s.len && s[j] >= '0' && s[j] <= '9' {
            i = j;
            while i < s.len && s[i] >= '0' && s[i] <= '9' { i++; }
        }
    }
    let v, ok = parse_flt(s[from..i]);
    return v as f32, ok;
}

// An arc's flag, one character, which may run on into the next number ("01").
fn flag(s: const u8[:], i: i64&) -> bool, bool {
    while i < s.len && is_space(s[i]) { i++; }
    guard i < s.len && (s[i] == '0' || s[i] == '1') else { return false, false; }
    i++;
    return s[i - 1] == '1', true;
}

// The value of attribute `name` in the tag `tag`, and whether it has one.
fn attr(tag: const u8[:], name: const u8[:]) -> const u8[:], bool {
    var at = 0;
    while at < tag.len {
        let k = find(tag[at..], name);
        guard k >= 0 else { break; }
        let i = at + k;
        let j = i + name.len;
        let before = i == 0 || is_space(tag[i - 1]);
        if before && j + 1 < tag.len && tag[j] == '=' && (tag[j + 1] == '"' || tag[j + 1] == '\'') {
            let q = tag[j + 1];
            var e = j + 2;
            while e < tag.len && tag[e] != q { e++; }
            return tag[j + 2..e], true;
        }
        at = j;
    }
    return tag[0..0], false;
}

// A transform attribute's list, composed left to right.
fn transform(s: const u8[:]) -> Affine {
    var m = Affine {};
    var i = 0;
    while i < s.len {
        while i < s.len && (is_space(s[i]) || s[i] == ')') { i++; }
        let from = i;
        while i < s.len && s[i] != '(' { i++; }
        guard i < s.len else { break; }
        let name = trim(s[from..i]);
        i++;
        var v: f32[6] = [0.0; 6];
        var n = 0;
        while n < 6 {
            let x, ok = number(s, i);
            guard ok else { break; }
            v[n] = x;
            n++;
        }
        var t = Affine {};
        if name == "matrix" && n == 6 { t = Affine { a: v[0], b: v[1], c: v[2], d: v[3], e: v[4], f: v[5] }; }
        else if name == "translate" { t = Affine { e: v[0], f: if n > 1 { v[1] } else { 0.0 }, .. }; }
        else if name == "scale" { t = Affine { a: v[0], d: if n > 1 { v[1] } else { v[0] }, .. }; }
        else if name == "rotate" {
            let r = v[0] * 3.14159265 / 180.0;
            let co = cos(r);
            let si = sin(r);
            t = Affine { a: co, b: si, c: -si, d: co, .. };
            if n == 3 {
                t = times(times(Affine { e: v[1], f: v[2], .. }, t), Affine { e: -v[1], f: -v[2], .. });
            }
        }
        m = times(m, t);
    }
    return m;
}

fn line(sh: Shape&, m: Affine, a: float2, b: float2) {
    guard sh.segs.len < MAX_SEGS else {
        sh.full = true;
        return;
    }
    let p = apply(m, a);
    let q = apply(m, b);
    sh.segs.push(float4 { p.x, p.y, q.x, q.y });
}

// How many straight pieces a curve whose control points span `len` gets: about one per
// 1/64 of the viewBox.
fn pieces(sh: Shape&, len: f32) -> i64 {
    let side = max(max(sh.box.z, sh.box.w), 1.0e-6);
    return clamp(ceil(len / side * 64.0) as i64, 2, 32);
}

fn cubic(sh: Shape&, m: Affine, p0: float2, p1: float2, p2: float2, p3: float2) {
    let n = pieces(sh, length(p1 - p0) + length(p2 - p1) + length(p3 - p2));
    var prev = p0;
    for k in 1..n + 1 {
        let t = k as f32 / n;
        let s = 1.0 - t;
        let p = p0 * (s * s * s) + p1 * (3.0 * s * s * t) + p2 * (3.0 * s * t * t) + p3 * (t * t * t);
        line(sh, m, prev, p);
        prev = p;
    }
}

fn quad(sh: Shape&, m: Affine, p0: float2, p1: float2, p2: float2) {
    let n = pieces(sh, length(p1 - p0) + length(p2 - p1));
    var prev = p0;
    for k in 1..n + 1 {
        let t = k as f32 / n;
        let s = 1.0 - t;
        let p = p0 * (s * s) + p1 * (2.0 * s * t) + p2 * (t * t);
        line(sh, m, prev, p);
        prev = p;
    }
}

// An elliptical arc from p0 to p1 as SVG gives it (its implementation notes, F.6.5).
fn arc(sh: Shape&, m: Affine, p0: float2, radii: float2, angle: f32, large: bool, sweep: bool, p1: float2) {
    var rx = abs(radii.x);
    var ry = abs(radii.y);
    guard rx > 0.0 && ry > 0.0 && (p0.x != p1.x || p0.y != p1.y) else {
        line(sh, m, p0, p1);
        return;
    }
    let phi = angle * 3.14159265 / 180.0;
    let co = cos(phi);
    let si = sin(phi);
    let h = (p0 - p1) * 0.5;
    let x1 = co * h.x + si * h.y;
    let y1 = -si * h.x + co * h.y;
    let lam = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry);
    if lam > 1.0 {
        rx *= sqrt(lam);
        ry *= sqrt(lam);
    }
    let num = max(rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1, 0.0);
    var k = sqrt(num / (rx * rx * y1 * y1 + ry * ry * x1 * x1));
    if large == sweep { k = -k; }
    let cx1 = k * rx * y1 / ry;
    let cy1 = -k * ry * x1 / rx;
    let mid = (p0 + p1) * 0.5;
    let c = float2 { co * cx1 - si * cy1 + mid.x, si * cx1 + co * cy1 + mid.y };
    let t0 = atan2((y1 - cy1) / ry, (x1 - cx1) / rx);
    var dt = atan2((-y1 - cy1) / ry, (-x1 - cx1) / rx) - t0;
    let tau: f32 = 6.28318531;
    if sweep && dt < 0.0 { dt += tau; }
    if !sweep && dt > 0.0 { dt -= tau; }
    let n = pieces(sh, abs(dt) * max(rx, ry));
    var prev = p0;
    for i in 1..n + 1 {
        let t = t0 + dt * i / n;
        let e = float2 { rx * cos(t), ry * sin(t) };
        let p = if i == n { p1 } else { float2 { co * e.x - si * e.y + c.x, si * e.x + co * e.y + c.y } };
        line(sh, m, prev, p);
        prev = p;
    }
}

fn is_command(c: u8) -> bool {
    return c == 'M' || c == 'm' || c == 'L' || c == 'l' || c == 'H' || c == 'h' || c == 'V' || c == 'v'
           || c == 'C' || c == 'c' || c == 'S' || c == 's' || c == 'Q' || c == 'q' || c == 'T' || c == 't'
           || c == 'A' || c == 'a' || c == 'Z' || c == 'z';
}

// A path's `d` through m into sh, every subpath closed (a fill closes them). False on
// data it can't read.
fn path(sh: Shape&, m: Affine, d: const u8[:]) -> bool {
    var i = 0;
    var cmd: u8 = ' ';
    var cur = float2 { 0.0, 0.0 };
    var start = cur;
    var ctrl = cur;             // the last curve's second control point, for S and T
    var open = false;
    while true {
        while i < d.len && is_space(d[i]) { i++; }
        guard i < d.len else { break; }
        if is_command(d[i]) {
            cmd = d[i];
            i++;
        } else if cmd == ' ' || cmd == 'Z' || cmd == 'z' {
            return false;
        }
        let rel = cmd >= 'a';
        let base = if rel { cur } else { float2 { 0.0, 0.0 } };
        let up = cmd & 0xDF;     // upper case
        var v: f32[7] = [0.0; 7];
        let want = if up == 'M' || up == 'L' || up == 'T' { 2 } else if up == 'H' || up == 'V' { 1 }
                   else if up == 'C' { 6 } else if up == 'S' || up == 'Q' { 4 } else if up == 'A' { 7 } else { 0 };
        for k in want {
            if up == 'A' && (k == 3 || k == 4) {
                let f, ok = flag(d, i);
                guard ok else { return false; }
                v[k] = if f { 1.0 } else { 0.0 };
                continue;
            }
            let x, ok = number(d, i);
            guard ok else { return false; }
            v[k] = x;
        }
        if up == 'M' {
            if open && (cur.x != start.x || cur.y != start.y) { line(sh, m, cur, start); }
            cur = base + float2 { v[0], v[1] };
            start = cur;
            ctrl = cur;
            open = true;
            cmd = if rel { 'l' } else { 'L' };
        } else if up == 'Z' {
            if cur.x != start.x || cur.y != start.y { line(sh, m, cur, start); }
            cur = start;
            ctrl = cur;
            open = false;
        } else if up == 'L' || up == 'H' || up == 'V' {
            var p = base + float2 { v[0], v[1] };
            if up == 'H' { p = float2 { base.x + v[0], cur.y }; }
            if up == 'V' { p = float2 { cur.x, base.y + v[0] }; }
            line(sh, m, cur, p);
            cur = p;
            ctrl = cur;
        } else if up == 'C' || up == 'S' {
            var c1 = cur * 2.0 - ctrl;
            var k = 0;
            if up == 'C' {
                c1 = base + float2 { v[0], v[1] };
                k = 2;
            }
            let c2 = base + float2 { v[k], v[k + 1] };
            let p = base + float2 { v[k + 2], v[k + 3] };
            cubic(sh, m, cur, c1, c2, p);
            ctrl = c2;
            cur = p;
        } else if up == 'Q' || up == 'T' {
            var c1 = cur * 2.0 - ctrl;
            var k = 0;
            if up == 'Q' {
                c1 = base + float2 { v[0], v[1] };
                k = 2;
            }
            let p = base + float2 { v[k], v[k + 1] };
            quad(sh, m, cur, c1, p);
            ctrl = c1;
            cur = p;
        } else if up == 'A' {
            let p = base + float2 { v[5], v[6] };
            arc(sh, m, cur, float2 { v[0], v[1] }, v[2], v[3] > 0.5, v[4] > 0.5, p);
            cur = p;
            ctrl = cur;
        }
        open = open || up != 'Z';
    }
    if open && (cur.x != start.x || cur.y != start.y) { line(sh, m, cur, start); }
    return true;
}

// The shape an SVG file holds: its viewBox, and every path's outline through its
// transforms. False when it has no viewBox or no path, or a path it can't read.
fn read(svg: const u8[:], sh: Shape&) -> bool {
    sh.segs.clear();
    sh.full = false;
    var stack: Affine[MAX_DEPTH + 1] = [Affine {}; MAX_DEPTH + 1];
    var depth = 0;
    var paths = 0;
    var i = 0;
    while i < svg.len {
        guard svg[i] == '<' else { i++; continue; }
        if starts_with(svg[i..], "<!--") {
            let e = find(svg[i..], "-->");
            guard e >= 0 else { break; }
            i += e + 3;
            continue;
        }
        var e = i;
        while e < svg.len && svg[e] != '>' { e++; }
        let tag = svg[i..min(e + 1, svg.len)];
        i = e + 1;
        let closed = tag.len >= 2 && tag[tag.len - 2] == '/';
        if starts_with(tag, "</g") {
            if depth > 0 { depth--; }
            continue;
        }
        let t, has_t = attr(tag, "transform");
        let m = if has_t { times(stack[depth], transform(t)) } else { stack[depth] };
        if starts_with(tag, "<svg") {
            let vb, ok = attr(tag, "viewBox");
            guard ok else { return false; }
            var j = 0;
            var v: f32[4] = [0.0; 4];
            for k in 4 {
                let x, got = number(vb, j);
                guard got else { return false; }
                v[k] = x;
            }
            sh.box = float4 { v[0], v[1], v[2], v[3] };
        } else if starts_with(tag, "<g") && (tag.len == 2 || is_space(tag[2]) || tag[2] == '>') {
            if !closed && depth < MAX_DEPTH {
                depth++;
                stack[depth] = m;
            }
        } else if starts_with(tag, "<path") {
            let d, ok = attr(tag, "d");
            guard ok else { continue; }
            guard sh.box.z > 0.0 && path(sh, m, d) else { return false; }
            paths++;
        }
    }
    return sh.box.z > 0.0 && sh.box.w > 0.0 && paths > 0 && sh.segs.len > 0;
}

// The distance from p to the piece s.
fn dist(p: float2, s: float4) -> f32 {
    let a = float2 { s.x, s.y };
    let ba = float2 { s.z, s.w } - a;
    let pa = p - a;
    let l = dot(ba, ba);
    let t = if l > 0.0 { clamp(dot(pa, ba) / l, 0.0, 1.0) } else { 0.0 };
    return length(pa - ba * t);
}

// Bakes sh into `out`, CELL × CELL bytes, row by row from the top: the signed distance to
// its outline in texels, negative inside, as 128 + d × 127 / SPREAD clamped to 0..255. The
// viewBox's longer side spans the cell, centred. Each piece reaches only the texels within
// SPREAD of it; inside and out come from crossings along each row (even-odd).
fn bake(sh: Shape&, out: u8[:]) {
    assert(out.len == CELL * CELL);
    let side = max(sh.box.z, sh.box.w);
    let k = CELL / side;
    let o = float2 { sh.box.x - 0.5 * (side - sh.box.z), sh.box.y - 0.5 * (side - sh.box.w) };
    var d: f32[>..] = [];
    for n in CELL * CELL { d.push(SPREAD); }
    var segs: float4[>..] = [];
    for s in sh.segs {
        segs.push(float4 { (s.x - o.x) * k, (s.y - o.y) * k, (s.z - o.x) * k, (s.w - o.y) * k });
    }
    for s in segs {
        let x0 = max(floor(min(s.x, s.z) - SPREAD) as i64, 0);
        let x1 = min(ceil(max(s.x, s.z) + SPREAD) as i64, CELL - 1);
        let y0 = max(floor(min(s.y, s.w) - SPREAD) as i64, 0);
        let y1 = min(ceil(max(s.y, s.w) + SPREAD) as i64, CELL - 1);
        for y in y0..y1 + 1 {
            for x in x0..x1 + 1 {
                let v = dist(float2 { x + 0.5, y + 0.5 }, s);
                let at = y * CELL + x;
                if v < d[at] { d[at] = v; }
            }
        }
    }
    var cross: f32[..MAX_SEGS] = [];
    for y in CELL {
        let py = y as f32 + 0.5;
        cross.clear();
        for s in segs {
            guard (s.y <= py) != (s.w <= py) else { continue; }
            cross.push(s.x + (py - s.y) * (s.z - s.x) / (s.w - s.y));
        }
        sort(cross) { a, b => a < b };
        var c = 0;
        for x in CELL {
            let px = x as f32 + 0.5;
            while c < cross.len && cross[c] < px { c++; }
            let at = y * CELL + x;
            let v = if c % 2 == 1 { -d[at] } else { d[at] };
            out[at] = clamp(128.0 + v * 127.0 / SPREAD + 0.5, 0.0, 255.0) as u8;
        }
    }
}
