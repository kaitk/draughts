// The light tuner's reference for the room's baked light (--light-ref): the same light as
// model3d::room_light bakes (the sky through the windows, the sun's light thrown back, the
// lace, one bounce), worked out straight on the room's surfaces from cells of 12.5 cm and
// four times as many sun rays and sky samples, each cell taken as an area when it is near.
// Slow (ten seconds); it only judges the bake. `fixed`: the light thrown back as the bake
// throws it now (thrown_albedo, the lace's own share), else as it did at 496d6155. Its output: a line a surface point,
// "plane i j x y h" then the light over pi from the sky, the sun's patches, the room's
// sky-lit cells, the lace and the bounce, each r g b.
namespace light_ref;
import std;
import vec;
import math;
import os;

let S: f32 = 0.125;
let FX = 72;
let FY = 56;
let WH = 32;
let NA = 24;
let ND = 8;
let RU = 40;
let LB = 24;
let LA = 3;
let TG = 16;
let FLOOR0 = 0;
let CEIL0 = 4032;
let WIN0 = 8064;
let HALL0 = 10368;
let STOVE0 = 12672;
let FAR0 = 14464;
let NICHE0 = 16256;
let NICHE_N = 1024;        // sill NA × ND, head NA × ND, reveals 2 × RU × ND
let LACE0 = 19328;
let TABLE0 = 19760;
let CELLS = 20016;

struct RCell { at: float3, normal: float3, albedo: float3, area: f32, su: f32, sv: f32, niche: i64 }

var cells:    RCell[CELLS];
var sun_in:   float3[CELLS]; // the sun's power on each cell, its albedo in (the lace: what it throws on)
var from_sky: float3[CELLS]; // radiance from the sky's light on it
var lace_l:   float3[CELLS];
var thrown:   float3[CELLS]; // radiance of the sun's thrown light
var bounced:  float3[CELLS]; // radiance after one bounce

fn tangents(n: float3) -> float3[2] {
    if abs(n.z) > 0.5 { return [float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, 1.0, 0.0 }]; }
    if abs(n.x) > 0.5 { return [float3 { 0.0, 1.0, 0.0 }, float3 { 0.0, 0.0, 1.0 }]; }
    return [float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, 0.0, 1.0 }];
}

// A cell's A cos cos / (pi r²) toward point p with normal np, its area split 4 × 4 when near.
fn factor(c: RCell&, p: float3, np: float3) -> f32 {
    let v = p - c.at;
    let r2 = dot(v, v);
    let big = max(c.su, c.sv);
    if r2 > 9.0 * big * big {
        let cs = dot(c.normal, v);
        let cp = -dot(np, v);
        guard cs > 0.0 && cp > 0.0 else { return 0.0; }
        return c.area * cs * cp / (PI * r2 * r2);
    }
    let t = tangents(c.normal);
    var sum: f32 = 0.0;
    for j in 4 {
        for i in 4 {
            let q = c.at + t[0] * ((i + 0.5) / 4.0 - 0.5) * c.su + t[1] * ((j + 0.5) / 4.0 - 0.5) * c.sv;
            let w = p - q;
            let d2 = max(dot(w, w), 1e-4);
            let cs = dot(c.normal, w);
            let cp = -dot(np, w);
            guard cs > 0.0 && cp > 0.0 else { continue; }
            sum += (c.area / 16.0) * cs * cp / (PI * d2 * d2);
        }
    }
    return sum;
}

fn make(t: float4) {
    let s = room_shell::LIBRARY;
    let wins = room_light::windows();
    let face = room_light::wall_face();
    let depth = room_light::glass_y() - face;
    let up = float3 { 0.0, 0.0, 1.0 };
    let down = float3 { 0.0, 0.0, -1.0 };
    for j in FY {
        for i in FX {
            let at = float3 { (i + 0.5) * S, (j + 0.5) * S, 0.0 };
            cells[FLOOR0 + j * FX + i] = RCell { at, up, room_light::FLOOR_ALBEDO, S * S, S, S, -1 };
            cells[CEIL0 + j * FX + i] = RCell { float3 { at.x, at.y, s.ceiling }, down, room_light::CEILING_ALBEDO, S * S, S, S, -1 };
        }
    }
    for k in WH {
        for i in FX {
            let a = room_light::wall_cell(room_shell::WINDOW_WALL, i * S, k * S, S, S);
            cells[WIN0 + k * FX + i] = RCell { a.at, a.normal, a.albedo, a.area, S, S, -1 };
            let b = room_light::wall_cell(room_shell::HALL_WALL, i * S, k * S, S, S);
            cells[HALL0 + k * FX + i] = RCell { b.at, b.normal, b.albedo, b.area, S, S, -1 };
        }
        for i in FY {
            let a = room_light::wall_cell(room_shell::STOVE_WALL, i * S, k * S, S, S);
            cells[STOVE0 + k * FY + i] = RCell { a.at, a.normal, a.albedo, a.area, S, S, -1 };
            let b = room_light::wall_cell(room_shell::FAR_WALL, i * S, k * S, S, S);
            cells[FAR0 + k * FY + i] = RCell { b.at, b.normal, b.albedo, b.area, S, S, -1 };
        }
    }
    for k in 3 {
        let o = wins[k];
        let base = NICHE0 + k * NICHE_N;
        let x0 = o.mid - 0.5 * o.width;
        let across = o.width / NA;
        let deep = depth / ND;
        let rise = (room_light::reveal_top(o) - o.sill) / RU;
        for i in NA {
            for j in ND {
                let x = x0 + (i + 0.5) * across;
                let y = face + (j + 0.5) * deep;
                cells[base + i * ND + j] = RCell { float3 { x, y, o.sill }, up, room_light::STONE_ALBEDO, across * deep, across, deep, k };
                cells[base + NA * ND + i * ND + j] =
                    RCell { float3 { x, y, room_shell::head_at(o, x - o.mid) }, down, room_light::PLASTER_ALBEDO, across * deep, across, deep, k };
            }
        }
        for side in 2 {
            let x = if side == 0 { x0 } else { x0 + o.width };
            let n = float3 { if side == 0 { 1.0 } else { -1.0 }, 0.0, 0.0 };
            for u in RU {
                for j in ND {
                    let at = float3 { x, face + (j + 0.5) * deep, o.sill + (u + 0.5) * rise };
                    cells[base + 2 * NA * ND + side * RU * ND + u * ND + j] = RCell { at, n, room_light::PLASTER_ALBEDO, rise * deep, deep, rise, k };
                }
            }
        }
        let band = (room_shell::LACE_TOP - room_shell::LACE_HEM) / LB;
        for side in 2 {
            for b in LB {
                let h = room_shell::LACE_HEM + (b + 0.5) * band;
                let inner = room_light::along_keys(room_shell::LACE_INNER, h);
                let outer = room_light::along_keys(room_shell::LACE_OUTER, h);
                for a in LA {
                    let x = o.mid + (if side == 0 { -1.0 } else { 1.0 }) * (inner + (a + 0.5) / LA * (outer - inner));
                    cells[LACE0 + ((k * 2 + side) * LB + b) * LA + a] =
                        RCell { float3 { x, face - room_shell::LACE_OFF, h }, float3 { 0.0, -1.0, 0.0 }, float3_0,
                                (outer - inner) / LA * band, (outer - inner) / LA, band, -1 };
                }
            }
        }
    }
    let ts = 2.0 * t.z / TG;
    for j in TG {
        for i in TG {
            let x = t.x - t.z + (i + 0.5) * ts;
            let y = t.y - t.z + (j + 0.5) * ts;
            let inside = (x - t.x) * (x - t.x) + (y - t.y) * (y - t.y) < t.z * t.z;
            cells[TABLE0 + j * TG + i] = RCell { float3 { x, y, t.w }, up, room_light::TABLE_ALBEDO, if inside { ts * ts } else { 0.0 }, ts, ts, -1 };
        }
    }
}

fn pc(x: f32, size: f32, n: i64) -> i64 { clamp((x / size * n) as i64, 0, n - 1) }

// The sun's rays, RX × RY a window (4 × 4 the bake's), into sun_in, as room_light::sun_patches.
let RX = 48;
let RY = 120;
fn trace_sun(sun: room_light::Sun, tree: const f32[:], fixed: bool) {
    for c in CELLS { sun_in[c] = float3_0; }
    let s = room_shell::LIBRARY;
    let wins = room_light::windows();
    let d = float3_0 - sun.toward;
    guard d.y < -0.02 && d.z < -0.02 else { return; }
    let face = room_light::wall_face();
    let gy = room_light::glass_y();
    let depth = gy - face;
    let room_x = s.walls[room_shell::FAR_WALL].a.x;
    let lace_y = face - room_shell::LACE_OFF;
    for k in 3 {
        let o = wins[k];
        let low = o.sill + room_light::GLAZED_LOW;
        let high = o.sill + o.height + o.rise - room_light::GLAZED_HIGH;
        let area = (2.0 * room_light::GLAZED_HALF / RX) * ((high - low) / RY);
        let each = sun.light * (area * -d.y * room_light::GLAZING);
        for j in RY {
            for i in RX {
                let q = float3 { o.mid - room_light::GLAZED_HALF + (i + 0.5) * (2.0 * room_light::GLAZED_HALF / RX), gy, low + (j + 0.5) * ((high - low) / RY) };
                var p = each * tree[(k * room_light::RAYS_Y + j / 4) * room_light::RAYS_X + i / 4];
                let t_face = (gy - face) / -d.y;
                let t_sill = (q.z - o.sill) / -d.z;
                let side = if d.x > 0.0 { 0.5 * o.width } else { -0.5 * o.width };
                let t_reveal = if abs(d.x) > 1e-4 { (o.mid + side - q.x) / d.x } else { 1e9 };
                var cell = -1;
                var a = float3_0;
                let base = NICHE0 + k * NICHE_N;
                if t_sill < t_face && t_sill < t_reveal {
                    let at = q + d * t_sill;
                    a = room_light::STONE_ALBEDO;
                    cell = base + pc(at.x - (o.mid - 0.5 * o.width), o.width, NA) * ND + pc(at.y - face, depth, ND);
                } else if t_reveal < t_face {
                    let at = q + d * t_reveal;
                    a = room_light::PLASTER_ALBEDO;
                    let sd = if d.x > 0.0 { 1 } else { 0 };
                    cell = base + 2 * NA * ND + sd * RU * ND + pc(at.z - o.sill, room_light::reveal_top(o) - o.sill, RU) * ND + pc(at.y - face, depth, ND);
                } else {
                    let b = q + d * t_face;
                    guard room_light::in_niche(o, b) else { continue; }
                    let c = q + d * ((gy - lace_y) / -d.y);
                    if room_light::in_lace(o, c) {
                        let lets = room_light::lace_lets(c.z);
                        let ax = abs(c.x - o.mid);
                        let inner = room_light::along_keys(room_shell::LACE_INNER, c.z);
                        let outer = room_light::along_keys(room_shell::LACE_OUTER, c.z);
                        let sd = if c.x > o.mid { 1 } else { 0 };
                        let lc = LACE0 + ((k * 2 + sd) * LB + pc(c.z - room_shell::LACE_HEM, room_shell::LACE_TOP - room_shell::LACE_HEM, LB)) * LA
                                 + pc(ax - inner, outer - inner, LA);
                        sun_in[lc] = sun_in[lc] + p * ((1.0 - lets) * room_light::LACE_SCATTER);
                        p = p * lets;
                    }
                    var t = b.z / -d.z;
                    var hit = 0;
                    var t_hall = b.y / -d.y;
                    let on_wall = b + d * t_hall;
                    let out = room_light::case_depth(on_wall.x, on_wall.z);
                    if out > 0.0 {
                        let t_case = (b.y - out) / -d.y;
                        let e = b + d * t_case;
                        if room_light::case_depth(e.x, e.z) >= out - 1e-3 { t_hall = t_case; }
                    }
                    if t_hall < t { t = t_hall; hit = 1; }
                    if d.x < 0.0 && b.x / -d.x < t { t = b.x / -d.x; hit = 2; }
                    if d.x > 0.0 && (room_x - b.x) / d.x < t { t = (room_x - b.x) / d.x; hit = 3; }
                    let tt = (b.z - sun.table.w) / -d.z;
                    if tt > 0.0 && tt < t {
                        let e = b + d * tt;
                        let dx = e.x - sun.table.x;
                        let dy = e.y - sun.table.y;
                        if dx * dx + dy * dy < sun.table.z * sun.table.z { t = tt; hit = 4; }
                    }
                    let at = b + d * t;
                    if hit == 0 {
                        a = room_light::FLOOR_ALBEDO;
                        cell = FLOOR0 + pc(at.y, 7.0, FY) * FX + pc(at.x, 9.0, FX);
                    } else if hit == 1 {
                        a = room_light::wall_albedo(room_shell::HALL_WALL, at.x, at.z);
                        cell = HALL0 + pc(at.z, s.ceiling, WH) * FX + pc(at.x, 9.0, FX);
                    } else if hit < 4 {
                        a = room_light::wall_albedo(if hit == 2 { room_shell::STOVE_WALL } else { room_shell::FAR_WALL }, at.y, at.z);
                        cell = (if hit == 2 { STOVE0 } else { FAR0 }) + pc(at.z, s.ceiling, WH) * FY + pc(at.y, 7.0, FY);
                    } else {
                        a = room_light::TABLE_ALBEDO;
                        cell = TABLE0 + pc(at.y - (sun.table.y - sun.table.z), 2.0 * sun.table.z, TG) * TG
                               + pc(at.x - (sun.table.x - sun.table.z), 2.0 * sun.table.z, TG);
                    }
                }
                if fixed { a = room_light::thrown_albedo(a, sun.bounce_gain); }
                sun_in[cell] = sun_in[cell] + p * a;
            }
        }
    }
}

// The sky's light over pi on point p with normal np (own: the niche it lies in, -1 the
// room, -3 the lace, which sees its own window's glass straight from behind).
let SKX = 12;
let SKY_ = 30;
fn sky_on(sun: room_light::Sun, wins: room_shell::Opening[3]&, p: float3, np: float3, own: i64, lace_k: i64) -> float3 {
    let gy = room_light::glass_y();
    let sky = sun.sky * (sun.sky_gain * room_light::GLAZING / PI);
    var e = float3_0;
    for k in 3 {
        guard (own < 0 && lace_k < 0) || own == k || lace_k == k else { continue; }
        let o = wins[k];
        let low = o.sill + room_light::GLAZED_LOW;
        let high = o.sill + o.height + o.rise - room_light::GLAZED_HIGH;
        let area = (2.0 * room_light::GLAZED_HALF / SKX) * ((high - low) / SKY_);
        for j in SKY_ {
            for i in SKX {
                let x = o.mid - room_light::GLAZED_HALF + (i + 0.5) * (2.0 * room_light::GLAZED_HALF / SKX);
                let h = low + (j + 0.5) * ((high - low) / SKY_);
                guard h < room_shell::head_at(o, x - o.mid) else { continue; }
                let v = float3 { x, gy, h } - p;
                guard v.y > 1e-3 else { continue; }
                let r2 = max(dot(v, v), 1e-4);
                let r = sqrt(r2);
                let facing = if lace_k >= 0 { v.y / r } else { dot(np, v) / r };
                guard facing > 0.0 else { continue; }
                let lets = if lace_k >= 0 || own >= 0 { 1.0 } else { room_light::seen_through(sun.table, wins, p, -1, float3 { x, gy, h }, k) };
                guard lets > 0.0 else { continue; }
                e = e + sky * (lets * area * (v.y / r) * facing / r2);
            }
        }
    }
    return e;
}

fn solve(sun: room_light::Sun, fixed: bool) {
    var wins = room_light::windows();
    let gain = sun.bounce_gain / PI;
    for c in CELLS {
        let cell .= cells[c];
        from_sky[c] = float3_0;
        lace_l[c] = float3_0;
        thrown[c] = float3_0;
        bounced[c] = float3_0;
        guard cell.area > 0.0 else { continue; }
        if c >= LACE0 && c < TABLE0 {
            let k = (c - LACE0) / (2 * LB * LA);
            let e = sky_on(sun, wins, cell.at, cell.normal, -1, k);
            let fs = room_light::balanced(e * ((1.0 - room_light::lace_lets(cell.at.z)) * room_light::LACE_SCATTER));
            lace_l[c] = (fs + room_light::balanced(sun_in[c] * ((if fixed { 1.0 / PI } else { gain }) / cell.area))) * room_light::lace_source;
        } else {
            let e = sky_on(sun, wins, cell.at, cell.normal, cell.niche, -1);
            from_sky[c] = room_light::balanced(e * cell.albedo);
            thrown[c] = room_light::balanced(sun_in[c] * (gain / cell.area));
        }
    }
    // One bounce: every room cell gathers the light leaving the others.
    for i in CELLS {
        let a .= cells[i];
        guard a.area > 0.0 && !(i >= LACE0 && i < TABLE0) else { continue; }
        var g = float3_0;
        for j in CELLS {
            guard j != i else { continue; }
            let b .= cells[j];
            let l = from_sky[j] + thrown[j] + lace_l[j];
            guard b.area > 0.0 && l.x + l.y + l.z > 0.0 else { continue; }
            let f = factor(b, a.at, a.normal);
            guard f > 0.0 else { continue; }
            let lets = room_light::seen_through(sun.table, wins, a.at, a.niche, b.at, b.niche);
            guard lets > 0.0 else { continue; }
            g = g + l * (f * lets);
        }
        bounced[i] = room_light::balanced(g * a.albedo);
    }
}

// The light over pi at surface point p (normal np) from the cells and the sky, by part.
fn at_point(sun: room_light::Sun, wins: room_shell::Opening[3]&, p: float3, np: float3) -> float3[5] {
    var r: float3[5] = [float3_0; 5];
    r[0] = sky_on(sun, wins, p, np, -1, -1);
    for j in CELLS {
        let b .= cells[j];
        guard b.area > 0.0 else { continue; }
        let f = factor(b, p, np);
        guard f > 0.0 else { continue; }
        let lets = room_light::seen_through(sun.table, wins, p, -1, b.at, b.niche);
        guard lets > 0.0 else { continue; }
        let w = f * lets;
        r[1] = r[1] + thrown[j] * w;
        r[2] = r[2] + from_sky[j] * w;
        r[3] = r[3] + lace_l[j] * w;
        r[4] = r[4] + bounced[j] * w;
    }
    return r;
}

let STEP: f32 = 0.1;
fn put(out: u8[>..]&, plane: i64, i: i64, j: i64, p: float3, r: float3[5]) {
    format(out, plane, " ", i, " ", j, " ", p.x, " ", p.y, " ", p.z);
    for k in 5 { format(out, " ", r[k].x, " ", r[k].y, " ", r[k].z); }
    format(out, "\n");
}

// Planes: 0 the floor, 1 the ceiling, 2 the window wall, 3 the hall wall, 4 the stove's
// end, 5 the far end.
fn run(sun: room_light::Sun, tree: const f32[:], path: const u8[:], stride: i64, fixed: bool) {
    make(sun.table);
    trace_sun(sun, tree, fixed);
    solve(sun, fixed);
    var wins = room_light::windows();
    var out: u8[>..] = [];
    let s = room_shell::LIBRARY;
    for plane in 6 {
        let nu = if plane < 4 { 90 } else { 70 };
        let nv = if plane < 2 { 70 } else { 40 };
        var j = 0;
        while j < nv {
            var i = 0;
            while i < nu {
                let u = (i + 0.5) * STEP;
                let v = (j + 0.5) * STEP;
                var p = float3_0;
                var n = float3_0;
                var ok = true;
                if plane == 0 { p = float3 { u, v, 0.0 }; n = float3 { 0.0, 0.0, 1.0 }; }
                else if plane == 1 { p = float3 { u, v, s.ceiling }; n = float3 { 0.0, 0.0, -1.0 }; }
                else if plane == 2 {
                    p = float3 { u, room_light::wall_face(), v };
                    n = float3 { 0.0, -1.0, 0.0 };
                    for k in 3 { if room_light::in_niche(wins[k], p) { ok = false; } }
                } else if plane == 3 { p = float3 { u, room_light::case_depth(u, v), v }; n = float3 { 0.0, 1.0, 0.0 }; }
                else if plane == 4 { p = float3 { 0.0, u, v }; n = float3 { 1.0, 0.0, 0.0 }; }
                else { p = float3 { 9.0, u, v }; n = float3 { -1.0, 0.0, 0.0 }; }
                if ok { put(out, plane, i, j, p, at_point(sun, wins, p, n)); }
                i += stride;
            }
            j += stride;
        }
    }
    guard write_file(path, out[..]) else { abort(str("could not write ", path)); }
}
