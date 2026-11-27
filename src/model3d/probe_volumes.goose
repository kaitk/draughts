// Probe volumes (the tuner's --light physical, volumes_on): boxes of probes at a spacing of
// their own over places the grid's 0.3 m can't hold, which ROOM_FRAG's PROBE_VOLUMES reads in
// place of the grid inside each box. The first are the box windows' spaces between their
// two panes, 0.2 m deep: the sky and the sun reach them through the outer casement alone,
// and the sunlit inner casement's back lights them, so the outer casement's frames read far
// more light than the probes before the wall hold.
//
// A volume's probes lie at the middles of its nx × ny × nh cells (the plan's x, its y, up);
// `fade` is how far in from its faces it blends into the grid (0 where each face is a pane or
// a wall, as a window's).
// They go into the atlas's rows after the grid's, each volume a block laid out as the grid
// is (its height's slices side by side, the three colours one over the other, its x and y
// falling as the grid's), the blocks packed in shelves from the row after the volumes'
// table (render3d writes the table: three texels a volume, in the room's frame).
namespace room_light;
import std;
import vec;
import math;

struct Volume { lo: float3, hi: float3, nx: i64, ny: i64, nh: i64, fade: f32, window: i64, column: i64, row: i64 }
let MAX_VOLUMES = 8;
let VOLUME_ROWS = 10;         // the table's row and the blocks' rows after ATLAS_H
let FULL_H = 88;              // ATLAS_H + VOLUME_ROWS
let FULL_FLOATS = 137280;     // ATLAS_W × FULL_H × 4
var volumes_on = false;
var volumes: Volume[..MAX_VOLUMES] = [];

// A window's volume: cavity_across probes across the niche, cavity_up from the sill to the
// lining's head, one deep at the middle between the panes. A pane lies room_shell::pane_in()
// past its casement's glass plane.
var cavity_across = 7;
var cavity_up = 20;
let PANE: f32 = 0.92;

// The volumes: each window's space between its panes. Their blocks packed in shelves of the
// atlas's width.
fn make_volumes() {
    volumes.clear();
    let wins = windows();
    let face = wall_face();
    var column = 0;
    var row = ATLAS_H + 1;
    var shelf = 0;
    for k in 3 {
        let o = wins[k];
        let w = 0.5 * o.width;
        var v = Volume { float3 { o.mid - w, face + o.glass.x + room_shell::pane_in(), o.sill },
                         float3 { o.mid + w, face + o.glass.y + room_shell::pane_in(), o.sill + o.height },
                         cavity_across, 1, cavity_up, 0.0, k, 0, 0 };
        if column + v.nx * v.nh > ATLAS_W {
            column = 0;
            row += shelf;
            shelf = 0;
        }
        v.column = column;
        v.row = row;
        column += v.nx * v.nh;
        shelf = max(shelf, 3 * v.ny);
        assert(row + shelf <= FULL_H);
        volumes.push(v);
    }
}

// Volume v's probe (ix, iy, ih) in the plan: ix along the room's x (the plan's x falling), iy
// along its z (the plan's y falling), ih up.
fn volume_probe(v: Volume, ix: i64, iy: i64, ih: i64) -> float3 {
    return float3 { v.hi.x - (ix + 0.5) * ((v.hi.x - v.lo.x) / v.nx), v.hi.y - (iy + 0.5) * ((v.hi.y - v.lo.y) / v.ny),
                    v.lo.z + (ih + 0.5) * ((v.hi.z - v.lo.z) / v.nh) };
}

// The surfaces in a window's space between the panes, a light each (lit by the sky and the
// sun through the outer casement, not bounced on): each of the inner casement's members'
// backs in pieces of about PIECE metres along it, the lining's two sides in LINING_UP each, the
// sill and the lining's head in LINING_ACROSS each. Where, its normal and albedo (the plan's),
// its two half sides, and the light leaving it (over pi, as Bounce.seen). The three windows
// have alike members, so each has cavity_count patches from k × MAX_CAVITY.
let PIECE: f32 = 0.25;
let LINING_UP = 10;
let LINING_ACROSS = 3;
let MAX_CAVITY = 256;
struct CavityPatch { at: float3, normal: float3, albedo: float3, half_a: float3, half_b: float3, leaves: float3 }
var cavity: CavityPatch[768];
var cavity_count = 0;
// Each inner member's first patch and how many it is cut into (along its longer side).
var member_first:  i64[..room_shell::MEMBERS] = [];
var member_pieces: i64[..room_shell::MEMBERS] = [];
// The sky's samples' share past the outer casement alone (as sky_lets for both), at the
// outer pane.
var outer_lets: f32[11560];
var outer_lets_made = false;

// The casements' members split into the inner casement's and the outer's (with the lunette
// over them).
fn members_split(o: room_shell::Opening, inner: room_shell::Member[..room_shell::MEMBERS]&,
                 outer: room_shell::Member[..room_shell::MEMBERS]&) {
    let all = room_shell::casement_members(o);
    let mid = -0.5 * (o.glass.x + o.glass.y);
    for b in all {
        if 0.5 * (b.lo.z + b.hi.z) > mid { inner.push(b); } else { outer.push(b); }
    }
}

// Whether the line through p along v (the window's metres) meets one of `boxes`; inv: 1 / v.
fn line_blocked(boxes: room_shell::Member[..room_shell::MEMBERS]&, p: float3, inv: float3) -> bool {
    for b in boxes {
        let t0 = (b.lo - p) * inv;
        let t1 = (b.hi - p) * inv;
        let enter = max(min(t0.x, t1.x), max(min(t0.y, t1.y), min(t0.z, t1.z)));
        let leave = min(max(t0.x, t1.x), min(max(t0.y, t1.y), max(t0.z, t1.z)));
        if enter <= leave { return true; }
    }
    return false;
}

// The patches' places, normals, albedos and sizes in window o (from cavity[base]), their light 0.
fn cavity_layout(o: room_shell::Opening, inner: room_shell::Member[..room_shell::MEMBERS]&, base: i64) {
    let face = wall_face();
    let w = 0.5 * o.width;
    let lining = 0.5 * (o.glass.x + o.glass.y);    // the lining's exposed band's middle, between the frames
    let open = o.glass.y - o.glass.x - 0.1;
    let ax = float3 { 1.0, 0.0, 0.0 };
    let ay = float3 { 0.0, 1.0, 0.0 };
    let az = float3 { 0.0, 0.0, 1.0 };
    var n = 0;
    member_first.clear();
    member_pieces.clear();
    for b in inner {
        let size = b.hi - b.lo;
        let along_y = size.y > size.x;
        let pieces = max((max(size.x, size.y) / PIECE + 0.5) as i64, 1);
        member_first.push(n);
        member_pieces.push(pieces);
        let half = float2 { if along_y { 0.5 * size.x } else { 0.5 * size.x / pieces }, if along_y { 0.5 * size.y / pieces } else { 0.5 * size.y } };
        for i in pieces {
            let mid = float2 { if along_y { b.lo.x + half.x } else { b.lo.x + (2 * i + 1) * half.x },
                               if along_y { b.lo.y + (2 * i + 1) * half.y } else { b.lo.y + half.y } };
            cavity[base + n] = CavityPatch { float3 { o.mid + mid.x, face - b.lo.z, mid.y }, ay, PAINT_ALBEDO, ax * half.x, az * half.y, float3_0 };
            n++;
        }
    }
    let up = o.height / LINING_UP;
    for side in 2 {
        let x = if side == 0 { o.mid - w } else { o.mid + w };
        let nx = float3 { if side == 0 { 1.0 } else { -1.0 }, 0.0, 0.0 };
        for j in LINING_UP {
            cavity[base + n] = CavityPatch { float3 { x, face + lining, o.sill + (j + 0.5) * up }, nx, PAINT_ALBEDO, ay * (0.5 * open), az * (0.5 * up), float3_0 };
            n++;
        }
    }
    let across = o.width / LINING_ACROSS;
    for i in LINING_ACROSS {
        let x = o.mid - w + (i + 0.5) * across;
        cavity[base + n] = CavityPatch { float3 { x, face + lining, o.sill }, az, STONE_ALBEDO, ax * (0.5 * across), ay * (0.5 * open), float3_0 };
        cavity[base + n + LINING_ACROSS] = CavityPatch { float3 { x, face + lining, o.sill + o.height }, float3 { 0.0, 0.0, -1.0 }, PAINT_ALBEDO,
                                                         ax * (0.5 * across), ay * (0.5 * open), float3_0 };
        n++;
    }
    n += LINING_ACROSS;
    assert(n <= MAX_CAVITY);
    cavity_count = n;
}

// The sky's light (over pi) on a surface at q with normal n (the plan's) in window o's space,
// through the outer casement and pane: the sky's samples on the outer pane, each split 3 × 3
// as they lie near.
fn outer_sky(sun: Sun, o: room_shell::Opening, q: float3, n: float3) -> float3 {
    let low = o.sill + GLAZED_LOW;
    let high = o.sill + o.height + o.rise - GLAZED_HIGH;
    let dx = 2.0 * GLAZED_HALF / SKY_X;
    let dh = (high - low) / SKY_Y;
    let gy = wall_face() + o.glass.y + room_shell::pane_in();
    let sky = sun.sky * (sun.sky_gain / PI);
    var e = float3_0;
    for j in SKY_Y {
        for i in SKY_X {
            for s in 9 {
                let x = o.mid - GLAZED_HALF + (i + ((s % 3) + 0.5) / 3.0) * dx;
                let h = low + (j + ((s / 3) + 0.5) / 3.0) * dh;
                guard h < o.sill + o.height else { continue; }
                let v = float3 { x, gy, h } - q;
                guard v.y > 1e-3 else { continue; }
                let r2 = max(dot(v, v), 1e-4);
                let r = sqrt(r2);
                let facing = dot(n, v) / r;
                guard facing > 0.0 else { continue; }
                let lets = lets_at(outer_lets[..], i, j, v) * PANE;
                e = e + sky * (lets * (dx * dh / 9.0) * (v.y / r) * facing / r2);
            }
        }
    }
    return e;
}

// The light leaving each window's space's surfaces (cavity): the sky's through the outer
// casement, and the sun's rays traced from the outer pane past the outer casement's members
// to the first of the inner casement's members, the lining, or the sill (MEMBER_SAMPLES / 2
// squared rays a sun ray's cell; those that reach the inner pane go on into the niche, as
// sun_patches has them). `tree`: as sun_patches'.
fn cavity_light(sun: Sun, tree: const f32[:]) {
    let wins = windows();
    var inner: room_shell::Member[..room_shell::MEMBERS] = [];
    var outer: room_shell::Member[..room_shell::MEMBERS] = [];
    members_split(wins[0], inner, outer);
    if !outer_lets_made {
        make_lets(outer_lets[..], outer, -(wins[0].glass.y + room_shell::pane_in()));
        outer_lets_made = true;
    }
    let d = float3_0 - sun.toward;
    let sun_in = d.y < -0.02 && d.z < -0.02;
    // The sun's line in the window's own metres: x along the wall, y up, z out of the wall.
    let v = float3 { d.x, d.z, -d.y };
    let inv = float3 { 1.0 / v.x, 1.0 / v.y, 1.0 / v.z };
    let s = MEMBER_SAMPLES / 2;
    for k in 3 {
        let o = wins[k];
        let base = k * MAX_CAVITY;
        cavity_layout(o, inner, base);
        let lining0 = cavity_count - 2 * LINING_UP - 2 * LINING_ACROSS;
        var power: float3[MAX_CAVITY] = [float3_0; MAX_CAVITY];
        if sun_in {
            let w = 0.5 * o.width;
            let low = o.sill + GLAZED_LOW;
            let high = o.sill + o.height + o.rise - GLAZED_HIGH;
            let dx = 2.0 * GLAZED_HALF / RAYS_X;
            let dh = (high - low) / RAYS_Y;
            let z_out = -(o.glass.y + room_shell::pane_in());
            let t_pane = (-(o.glass.x + room_shell::pane_in()) - z_out) / v.z;
            let each = sun.light * ((dx * dh / (s * s)) * -d.y * PANE);
            for j in RAYS_Y {
                for i in RAYS_X {
                    let p_ray = each * tree[(k * RAYS_Y + j) * RAYS_X + i];
                    for sj in s {
                        for si in s {
                            let p = float3 { -GLAZED_HALF + (i + (si + 0.5) / s) * dx, low + (j + (sj + 0.5) / s) * dh, z_out };
                            guard p.y < o.sill + o.height && !line_blocked(outer, p, inv) else { continue; }
                            var t = t_pane;
                            var hit = -1;
                            for b, m in inner {
                                let t0 = (b.lo - p) * inv;
                                let t1 = (b.hi - p) * inv;
                                let enter = max(min(t0.x, t1.x), max(min(t0.y, t1.y), min(t0.z, t1.z)));
                                let leave = min(max(t0.x, t1.x), min(max(t0.y, t1.y), max(t0.z, t1.z)));
                                if enter <= leave && enter > 0.0 && enter < t { t = enter; hit = m; }
                            }
                            var at = -1;
                            if hit >= 0 {
                                let b = inner[hit];
                                let q = p + v * t;
                                let along_y = b.hi.y - b.lo.y > b.hi.x - b.lo.x;
                                let f = if along_y { (q.y - b.lo.y) / (b.hi.y - b.lo.y) } else { (q.x - b.lo.x) / (b.hi.x - b.lo.x) };
                                at = member_first[hit] + clamp((f * member_pieces[hit]) as i64, 0, member_pieces[hit] - 1);
                            }
                            if abs(v.x) > 1e-4 {
                                let tx = ((if v.x > 0.0 { w } else { -w }) - p.x) / v.x;
                                if tx > 0.0 && tx < t {
                                    t = tx;
                                    let up = clamp(((p.y + v.y * t - o.sill) / o.height * LINING_UP) as i64, 0, LINING_UP - 1);
                                    at = lining0 + (if v.x > 0.0 { LINING_UP } else { 0 }) + up;
                                }
                            }
                            if v.y < 0.0 {
                                let ty = (o.sill - p.y) / v.y;
                                if ty > 0.0 && ty < t {
                                    t = ty;
                                    let across = clamp(((p.x + v.x * t + w) / o.width * LINING_ACROSS) as i64, 0, LINING_ACROSS - 1);
                                    at = lining0 + 2 * LINING_UP + across;
                                }
                            }
                            guard at >= 0 else { continue; }
                            power[at] = power[at] + p_ray;
                        }
                    }
                }
            }
        }
        for c in cavity_count {
            let cp .= cavity[base + c];
            let area = 4.0 * length(cp.half_a) * length(cp.half_b);
            let sky = outer_sky(sun, o, cp.at + cp.normal * 0.005, cp.normal);
            cp.leaves = (sky + power[c] * (1.0 / (PI * area))) * cp.albedo;
        }
    }
}

// What probe p (the plan's metres) in window k's space between the panes gathers, as the
// grid's probes do: the room's and the niche's light (its cells and the sun's patches, as
// niche k's probes gather them) through the inner pane and casement (`inner_lets` of it),
// the sky through the outer casement and pane, and the space's own surfaces (cavity), each
// split SPLIT × SPLIT as they lie near. Its light settled exactly toward the faces f it
// stands before: the room (the outer casement's fronts face it), and on the edges the lining,
// the sill or the head (the inner casement's backs face away from the room, unseen).
fn cavity_probe(sun: Sun, bounce: Bounce&, patches: Patch[BINS]&, count: i64, patch_niche: i64[BINS]&,
                wins: room_shell::Opening[3]&, p: float3, k: i64, inner_lets: f32, f: float3) -> Gathered {
    var g = gather_cells(sun, bounce, wins, p, k, f);
    let inv_pi2 = sun.bounce_gain / (PI * PI);
    for pi in count {
        let pt .= patches[pi];
        let v = pt.at - p;
        let r2 = max(dot(v, v), gather_near);
        let r = sqrt(r2);
        let off = -dot(pt.normal, v);
        guard off > 0.0 else { continue; }
        let lets = seen_through(sun.table, wins, p, k, pt.at, patch_niche[pi]);
        guard lets > 0.0 else { continue; }
        take(g, f, pt.power * (lets * (off / r) * inv_pi2 / r2), v / r);
    }
    g = scaled(g, inner_lets);
    // The sky through the outer casement.
    let o = wins[k];
    let low = o.sill + GLAZED_LOW;
    let high = o.sill + o.height + o.rise - GLAZED_HIGH;
    let dx = 2.0 * GLAZED_HALF / SKY_X;
    let dh = (high - low) / SKY_Y;
    let gy = wall_face() + o.glass.y + room_shell::pane_in();
    let sky = sun.sky * (sun.sky_gain / PI);
    for j in SKY_Y {
        for i in SKY_X {
            for s in 9 {
                let x = o.mid - GLAZED_HALF + (i + ((s % 3) + 0.5) / 3.0) * dx;
                let h = low + (j + ((s / 3) + 0.5) / 3.0) * dh;
                guard h < o.sill + o.height else { continue; }
                let v = float3 { x, gy, h } - p;
                guard v.y > 1e-3 else { continue; }
                let r2 = max(dot(v, v), 1e-4);
                let r = sqrt(r2);
                let lets = lets_at(outer_lets[..], i, j, v) * PANE;
                take(g, f, sky * (lets * (dx * dh / 9.0) * (v.y / r) / r2), v / r);
            }
        }
    }
    // The space's own surfaces, split where near.
    for c in cavity_count {
        let cp .= cavity[k * MAX_CAVITY + c];
        let area = 4.0 * length(cp.half_a) * length(cp.half_b);
        let side = 2.0 * max(length(cp.half_a), length(cp.half_b));
        let vc = cp.at - p;
        if dot(vc, vc) > 4.0 * side * side {
            let off = -dot(cp.normal, vc);
            guard off > 0.0 else { continue; }
            let r2 = dot(vc, vc);
            let r = sqrt(r2);
            take(g, f, cp.leaves * (area * off / (PI * r * r2)), vc / r);
            continue;
        }
        let each = area / (SPLIT * SPLIT);
        for sj in SPLIT {
            for si in SPLIT {
                let q = cp.at + cp.half_a * ((2.0 * si + 1.0) / SPLIT - 1.0) + cp.half_b * ((2.0 * sj + 1.0) / SPLIT - 1.0);
                let v = q - p;
                let off = -dot(cp.normal, v);
                guard off > 0.0 else { continue; }
                let r2 = max(dot(v, v), 1e-4);
                let r = sqrt(r2);
                take(g, f, cp.leaves * (each * off / (PI * r * r2)), v / r);
            }
        }
    }
    settle(g, f);
    return g;
}

// g with every sum times s.
fn scaled(g: Gathered, s: f32) -> Gathered {
    return Gathered { g.c * s, g.dr * s, g.dg * s, g.db * s, g.ex * s, g.ey * s, g.ez * s, g.qxx * s, g.qyy * s, g.qxy * s,
                      g.qxz * s, g.qyz * s, g.lace * s };
}

// The volumes' probes into the atlas's rows after the grid's (atlas: FULL_FLOATS). The sun's
// patches and the bounces as bake had them; `tree` as sun_patches'.
fn bake_volumes(sun: Sun, tree: const f32[:], patches: Patch[BINS]&, count: i64, bounce: Bounce&, atlas: f32[:]) {
    assert(atlas.len == FULL_FLOATS);
    make_volumes();
    cavity_light(sun, tree);
    var wins = windows();
    var patch_niche: i64[BINS] = [-1; BINS];
    for pi in count { patch_niche[pi] = niche_of(patches[pi].at + patches[pi].normal * 0.01); }
    // What the inner casement and its pane let through, square on.
    var inner: room_shell::Member[..room_shell::MEMBERS] = [];
    var outer: room_shell::Member[..room_shell::MEMBERS] = [];
    members_split(wins[0], inner, outer);
    let o = wins[0];
    let low = o.sill + GLAZED_LOW;
    let high = o.sill + o.height - GLAZED_HIGH;
    let inner_lets = PANE * members_let_rect(inner, -GLAZED_HALF, low, 2.0 * GLAZED_HALF, high - low, float3 { 0.0, -1.0, 0.0 },
                                             32, -(o.glass.x + room_shell::pane_in()));
    for v in volumes {
        for ih in v.nh {
            for iy in v.ny {
                for ix in v.nx {
                    let p = volume_probe(v, ix, iy, ih);
                    // The faces before it: the room; the lining on the edges along x (ix 0 lies
                    // at the plan's largest x), the sill under the first row, the head over the last.
                    let fx: f32 = if ix == 0 { -1.0 } else if ix == v.nx - 1 { 1.0 } else { 0.0 };
                    let fz: f32 = if ih == 0 { 1.0 } else if ih == v.nh - 1 { -1.0 } else { 0.0 };
                    let g = cavity_probe(sun, bounce, patches, count, patch_niche, wins, p, v.window, inner_lets,
                                         float3 { fx, -1.0, fz });
                    let x = v.column + ih * v.nx + ix;
                    let all: float4[3] = [float4 { g.c.x, g.dr.x, g.dr.y, g.dr.z }, float4 { g.c.y, g.dg.x, g.dg.y, g.dg.z },
                                          float4 { g.c.z, g.db.x, g.db.y, g.db.z }];
                    for c in 3 {
                        let a = 4 * ((v.row + c * v.ny + iy) * ATLAS_W + x);
                        atlas[a] = all[c].x;
                        atlas[a + 1] = all[c].y;
                        atlas[a + 2] = all[c].z;
                        atlas[a + 3] = all[c].w;
                    }
                }
            }
        }
    }
}
