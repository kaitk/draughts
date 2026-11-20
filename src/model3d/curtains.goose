// The library's curtains (option A of build/notes/curtains/, the measures in shell.goose):
// over each window a brass rod on two brackets with ball finials, and a lace panel each
// side gathered on it, tied back with a cord to a hook on the pier. Built once with the
// shell, in metres from the window's middle (x along the wall, y up from the floor, z out
// of the wall), the right panel's numbers mirrored for the left.
//
// A panel is a strip of LACE_COLS × LACE_ROWS: its column s (0 at the inner edge, 1 at
// the outer) a place across the flat cloth, its row a height. Each row runs from the inner
// edge to the outer (LACE_INNER, LACE_OUTER), LACE_MIDDLE off the wall, and folds in and
// out about that line, so deep that the row still holds the cloth's 1.20 m (fold_depth);
// each fold its own depth, its phase wandering over the drop, its crests a little sharp.
// The folds run down into the hem, whose line rises toward the inner edge, as a tied
// curtain's does, and goes up and down a little with them. The lace's uv is the flat
// cloth's: u across it from the outer edge, v up it from the hem along the surface, so the
// pattern bunches on the folds as real lace does and the hem's border follows the hem.
namespace room_shell;
import std;
import vec;
import math;

let LACE_COLS = 37;    // 6 a fold
let LACE_ROWS = 17;
let LACE_VERTS = 629;  // LACE_COLS × LACE_ROWS
// The rows' heights, the last the hem's (hem_y).
let LACE_ROW_Y: f32[17] = [3.7, 3.66, 3.55, 3.4, 3.2, 2.9, 2.5, 2.1, 1.7, 1.4, 1.2, 1.06, 0.95, 0.83, 0.6, 0.32, 0.05];
// How much of the sky and park the lace sees through the niche behind it, where it hangs
// in front of the niche (the glass 0.4 m back in a 1.3 m opening, its frames and bars).
let LACE_SKY_VIEW: f32 = 0.6;
let CORD_RADIUS:   f32 = 0.004;
// How far the rod pocket's gathers stand off the rod's middle.
let POCKET: f32 = 0.016;

// The value at y of keys (y, value) sorted by y, a Catmull-Rom through them, clamped.
fn key_at(keys: float2[], y: f32) -> f32 {
    let n = keys.len;
    if y <= keys[0].x { return keys[0].y; }
    if y >= keys[n - 1].x { return keys[n - 1].y; }
    var i = 0;
    while keys[i + 1].x < y { i++; }
    let a = keys[i];
    let c = keys[i + 1];
    let t = (y - a.x) / (c.x - a.x);
    let before = if i > 0 { keys[i - 1].y } else { a.y - (c.y - a.y) };
    let after = if i + 2 < n { keys[i + 2].y } else { c.y + (c.y - a.y) };
    let m0 = 0.5 * (c.y - before);
    let m1 = 0.5 * (after - a.y);
    let t2 = t * t;
    let t3 = t2 * t;
    return (2.0 * t3 - 3.0 * t2 + 1.0) * a.y + (t3 - 2.0 * t2 + t) * m0 + (-2.0 * t3 + 3.0 * t2) * c.y + (t3 - t2) * m1;
}

// A fold's own depth (0.6 to 1.3 of the row's), and its phase at height y, a fraction of
// a fold up to ±0.3, wandering smoothly over about 0.8 m.
fn fold_depth(seed: i64, k: i64) -> f32 { 0.6 + 0.7 * surfaces::hash(seed, k) }
fn fold_phase(seed: i64, k: i64, y: f32) -> f32 {
    let at = y / 0.8;
    let i = floor(at) as i64;
    let f = at - i;
    let e = f * f * (3.0 - 2.0 * f);
    let a = surfaces::hash(seed, 100 + 37 * k + i) - 0.5;
    let c = surfaces::hash(seed, 101 + 37 * k + i) - 0.5;
    return 0.6 * (a + (c - a) * e);
}

// The fold's offset at s across and y up, -1.3 to 1.3 of the row's depth: the folds'
// sine with sharpened crests, rounding toward the hem where the cloth hangs free, each
// fold its own depth and phase, faded to the line over the last half fold at each edge so
// the edges hang clean.
fn fold_at(seed: i64, s: f32, y: f32) -> f32 {
    let n = LACE_FOLDS as f32;
    let k = min(floor(s * n) as i64, LACE_FOLDS - 1);
    let f = s * n - k;
    let depth = fold_depth(seed, k) * (1.0 - f) + fold_depth(seed, k + 1) * f;
    let phase = fold_phase(seed, k, y) * (1.0 - f) + fold_phase(seed, k + 1, y) * f;
    let v = sin(TAU * (s * n + phase));
    let sharp: f32 = 0.75 + 0.25 * clamp((0.7 - y) / 0.6, 0.0, 1.0);
    let shaped = if v < 0.0 { -pow(-v, sharp) } else { pow(v, sharp) };
    let edge = min(1.0, min(s * n * 2.0, (1.0 - s) * n * 2.0));
    return depth * shaped * edge;
}

// The row's fold depth at y: a zigzag of LACE_FOLDS folds across w holds the flat cloth
// when its half depth is w / 4n × √(r² − 1), r the gather.
fn fold_amplitude(y: f32) -> f32 {
    let w = key_at(LACE_OUTER[..], y) - key_at(LACE_INNER[..], y);
    let r = LACE_FLAT / w;
    let a = 0.25 * w / LACE_FOLDS * sqrt(max(r * r - 1.0, 0.0));
    // The rod pocket: the cloth bunched round the rod, the folds opening below it.
    let open = clamp((LACE_ROD - 0.02 - y) / 0.28, 0.0, 1.0);
    // The cord squeezes the bundle at the tie to about half its depth.
    let t = (y - TIE_Y) / 0.07;
    let pinch = 1.0 - 0.45 * exp(-t * t);
    return POCKET + (a * pinch - POCKET) * open * open * (3.0 - 2.0 * open);
}

// The right panel's point at s across and y up.
fn drape_at(seed: i64, s: f32, y: f32) -> float3 {
    let x0 = key_at(LACE_INNER[..], y);
    let x1 = key_at(LACE_OUTER[..], y);
    return float3 { x0 + s * (x1 - x0), y, key_at(LACE_MIDDLE[..], y) + fold_amplitude(y) * fold_at(seed, s, y) };
}

// The hem's height at s: about LACE_HEM, rising 3.5 cm toward the inner edge where the
// tie pulls the cloth up, the folds' crests curling a little higher than their backs,
// and a slow wave along it.
fn hem_y(seed: i64, s: f32) -> f32 {
    let rise = 0.035 * (1.0 - s) * (1.0 - s);
    let wave = 0.01 * sin(TAU * (1.3 * s + surfaces::hash(seed, 7)));
    return LACE_HEM + 0.01 + rise + 0.004 * fold_at(seed, s, LACE_HEM) + wave;
}

// How much of the window behind the niche the lace sees at x, y (its distance from the
// window's middle, its height): all of LACE_SKY_VIEW in front of the niche, none in front
// of the pier, soft over 5 cm.
fn sky_behind(o: Opening, x: f32, y: f32) -> f32 {
    let soft: f32 = 0.05;
    let across = clamp((0.5 * o.width - abs(x)) / soft + 0.5, 0.0, 1.0);
    let up = clamp((y - o.sill) / soft + 0.5, 0.0, 1.0) * clamp((head_at(o, x) - y) / soft + 0.5, 0.0, 1.0);
    return LACE_SKY_VIEW * across * up;
}

// A window's curtains in wall b (b's s at its middle): the lace into the glass list, the
// rod, brackets, finials, cords and hooks into the room's.
fn curtains(verts: mesh::Vertex[>..]&, indices: u32[>..]&, glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&,
            b: surfaces::Builder, o: Opening, seed: i64&) {
    let brass = surfaces::MAT_BRASS;
    let rod: float3[2] = [float3 { -ROD_HALF, LACE_ROD, LACE_OFF }, float3 { ROD_HALF, LACE_ROD, LACE_OFF }];
    tube(verts, indices, b, rod[..], ROD_RADIUS, 10, false, brass);
    for sx in SIDES {
        seed++;
        lace_panel(glass, glass_indices, b, o, sx, seed);
        tie_back(verts, indices, b, sx, seed);
        // The finial, a ball on a short neck; the bracket, a rosette on the wall, an arm
        // out to a cup under the rod.
        let end = sx * ROD_HALF;
        let neck: float3[2] = [float3 { end, LACE_ROD, LACE_OFF }, float3 { end + sx * 0.012, LACE_ROD, LACE_OFF }];
        tube(verts, indices, b, neck[..], 0.008, 8, false, brass);
        ball(verts, indices, b, float3 { end + sx * (0.010 + FINIAL_RADIUS), LACE_ROD, LACE_OFF }, FINIAL_RADIUS, brass);
        let x = sx * ROD_BRACKET;
        let arm_y = LACE_ROD - ROD_RADIUS - 0.006;
        let rosette: float3[2] = [float3 { x, arm_y, 0.0 }, float3 { x, arm_y, 0.01 }];
        tube(verts, indices, b, rosette[..], 0.025, 12, false, brass);
        disc(verts, indices, b, float3 { x, arm_y, 0.01 }, 0.025, 12, brass);
        let arm: float3[2] = [float3 { x, arm_y, 0.01 }, float3 { x, arm_y, LACE_OFF }];
        tube(verts, indices, b, arm[..], 0.006, 8, false, brass);
        ball(verts, indices, b, float3 { x, arm_y + 0.002, LACE_OFF }, 0.011, brass);
    }
}

// One panel, side sx (1 the right, -1 the left), into the glass list.
fn lace_panel(glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&, b: surfaces::Builder, o: Opening, sx: f32, seed: i64) {
    let k = m();
    var pos:    float3[LACE_VERTS] = [float3_0; LACE_VERTS];
    var across: f32[LACE_COLS]     = [0.0; LACE_COLS];
    for i in LACE_COLS { across[i] = (i as f32) / (LACE_COLS - 1); }
    for j in LACE_ROWS {
        for i in LACE_COLS {
            let s = across[i];
            let y = if j == LACE_ROWS - 1 { hem_y(seed, s) } else { LACE_ROW_Y[j] };
            pos[j * LACE_COLS + i] = drape_at(seed, s, y);
        }
    }
    // v: up the cloth from the hem, along the surface.
    var up: f32[LACE_VERTS] = [0.0; LACE_VERTS];
    for i in LACE_COLS {
        var j = LACE_ROWS - 2;
        while j >= 0 {
            let a = j * LACE_COLS + i;
            up[a] = up[a + LACE_COLS] + length(pos[a] - pos[a + LACE_COLS]);
            j--;
        }
    }
    let base = glass.len as u32;
    for j in LACE_ROWS {
        for i in LACE_COLS {
            let s = across[i];
            let p = pos[j * LACE_COLS + i];
            let e: f32 = 0.002;
            let ds = drape_at(seed, min(s + e, 1.0), p.y) - drape_at(seed, max(s - e, 0.0), p.y);
            let dy = drape_at(seed, s, p.y + 0.01) - drape_at(seed, s, p.y - 0.01);
            let n = normalize(cross(ds, dy));
            let q = float3 { sx * p.x, p.y, p.z } * k;
            glass.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), surfaces::world_normal(b, float3 { sx * n.x, n.y, n.z }),
                                      float2 { (1.0 - s) * LACE_FLAT * k, up[j * LACE_COLS + i] * k }, sky_behind(o, p.x, p.y),
                                      surfaces::MAT_LACE });
        }
    }
    for j in LACE_ROWS - 1 {
        for i in LACE_COLS - 1 {
            let a = base + (j * LACE_COLS + i) as u32;
            let c = a + LACE_COLS;
            glass_indices.append([a, a + 1, c + 1, a, c + 1, c]);
        }
    }
}

// The tie-back of side sx: a cream cord from the hook on the pier behind the bundle's inner
// side, round its front, sagging a little, and back past its outer side to the hook; the
// hook a brass pin with a ball on the wainscot's frame.
fn tie_back(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, sx: f32, seed: i64) {
    let y = TIE_Y;
    let x0 = key_at(LACE_INNER[..], y);
    let x1 = key_at(LACE_OUTER[..], y);
    let zc = key_at(LACE_MIDDLE[..], y);
    let front = zc + 1.15 * fold_amplitude(y) + CORD_RADIUS;
    let hook = float3 { TIE_HOOK, y, 0.045 };
    var pts: float3[..16] = [];
    pts.push(hook);
    pts.push(float3 { x0 - 0.004, y + 0.004, zc - 0.03 });
    pts.push(float3 { x0 - 0.01, y, zc + 0.02 });
    for i in 7 {
        let t = (i as f32 + 0.5) / 7.0;
        pts.push(float3 { x0 + (x1 - x0) * t, y - 0.012 * sin(PI * t), front + 0.004 * sin(PI * t) });
    }
    pts.push(float3 { x1 + 0.012, y, zc + 0.02 });
    pts.push(float3 { x1 + 0.006, y + 0.004, zc - 0.03 });
    for &p in pts { p.x *= sx; }
    tube(verts, indices, b, pts[..], CORD_RADIUS, 6, true, surfaces::MAT_CORD);
    let pin: float3[2] = [float3 { sx * TIE_HOOK, y, 0.02 }, float3 { sx * TIE_HOOK, y, 0.05 }];
    tube(verts, indices, b, pin[..], 0.003, 6, false, surfaces::MAT_BRASS);
    ball(verts, indices, b, float3 { sx * TIE_HOOK, y + 0.003, 0.05 }, 0.006, surfaces::MAT_BRASS);
    disc(verts, indices, b, float3 { sx * TIE_HOOK, y, 0.026 }, 0.011, 8, surfaces::MAT_BRASS);
}

// A tube of radius r round the polyline pts (metres in b's frame), `sides` round,
// closed into a loop or open.
fn tube(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, pts: float3[], r: f32, sides: i64, closed: bool,
        mat: f32) {
    let k = m();
    let n = pts.len;
    let base = verts.len as u32;
    for p, i in pts {
        let prev = if i > 0 { pts[i - 1] } else { if closed { pts[n - 1] } else { p } };
        let next = if i + 1 < n { pts[i + 1] } else { if closed { pts[0] } else { p } };
        let t = normalize(next - prev);
        let lift = if abs(t.y) > 0.9 { float3 { 1.0, 0.0, 0.0 } } else { float3 { 0.0, 1.0, 0.0 } };
        let a = normalize(cross(t, lift));
        let c = cross(a, t);
        for j in sides {
            let ang: f32 = TAU * j / sides;
            let d = a * cos(ang) + c * sin(ang);
            let q = (p + d * r) * k;
            verts.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), surfaces::world_normal(b, d), float2 { j, i },
                                      1.0, mat });
        }
    }
    let rings = if closed { n } else { n - 1 };
    for i in rings {
        let r0 = base + (i * sides) as u32;
        let r1 = base + (((i + 1) % n) * sides) as u32;
        for j in sides {
            let j1 = (j + 1) % sides;
            indices.append([r0 + j as u32, r0 + j1 as u32, r1 + j1 as u32, r0 + j as u32, r1 + j1 as u32, r1 + j as u32]);
        }
    }
}

// A ball of radius r at c (metres in b's frame), 8 round and 6 up.
fn ball(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: float3, r: f32, mat: f32) {
    let k = m();
    let round = 8;
    let rows = 6;
    let base = verts.len as u32;
    for i in rows + 1 {
        let lat: f32 = PI * i / rows;
        for j in round {
            let lon: f32 = TAU * j / round;
            let d = float3 { sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon) };
            let q = (c + d * r) * k;
            verts.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), surfaces::world_normal(b, d), float2 { j, i },
                                      1.0, mat });
        }
    }
    for i in rows {
        let r0 = base + (i * round) as u32;
        let r1 = r0 + round as u32;
        for j in round {
            let j1 = (j + 1) % round;
            indices.append([r0 + j as u32, r0 + j1 as u32, r1 + j1 as u32, r0 + j as u32, r1 + j1 as u32, r1 + j as u32]);
        }
    }
}

// A disc of radius r at c facing out of the wall (+z), `sides` round.
fn disc(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: float3, r: f32, sides: i64, mat: f32) {
    let k = m();
    let n = surfaces::world_normal(b, float3 { 0.0, 0.0, 1.0 });
    let base = verts.len as u32;
    let q = c * k;
    verts.push(mesh::Vertex { surfaces::world(b, q.x, q.y, q.z), n, float2_0, 1.0, mat });
    for j in sides {
        let ang: f32 = TAU * j / sides;
        let p = (c + float3 { cos(ang), sin(ang), 0.0 } * r) * k;
        verts.push(mesh::Vertex { surfaces::world(b, p.x, p.y, p.z), n, float2_0, 1.0, mat });
    }
    for j in sides { indices.append([base, base + 1 + j as u32, base + 1 + ((j + 1) % sides) as u32]); }
}
