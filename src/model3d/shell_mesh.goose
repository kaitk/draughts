// The library's shell built from its data (shell.goose), once, in the room's frame (u,
// height, v; surfaces.goose's Builder): the walls' wallpaper round their openings, the
// wainscot along them (option A of build/notes/wainscot/), the windows' niches with their
// bands, reveals, arches, sills, box windows, shutters and lace (window B of
// build/notes/windows/), the doors (door 1), the floor, the ceiling and its cornice
// (option B of build/notes/ceiling/). The glass and the lace go into a list of their own,
// drawn blended after the rest. A first pass: the casements' members are plain boxes, the
// shutters a box with three panels.
namespace room_shell;
import std;
import vec;
import math;

// Window B's casement, in metres from build/notes/windows/src/gen.py's frame_layout: the
// blind frame's face inside the daylight, a sash's outer stile, its meeting stile, the
// cover strip over the meeting, the lower sash's bottom rail, the other rails, the transom
// (two thirds up), the bars, the frame's head and sill; the panes a leaf above the
// transom and below it. shaders::ROOM_HEAD's casement() has the same.
let CASE_FRAME = 0.06;
let CASE_STILE = 0.055;
let CASE_MEET = 0.05;
let CASE_COVER = 0.035;
let CASE_RAIL_LOW = 0.08;
let CASE_RAIL = 0.055;
let CASE_TRANSOM = 0.09;
let CASE_BAR = 0.024;
let CASE_HEAD = 0.06;
let UPPER_ACROSS = 3;
let UPPER_UP = 3;
let LOWER_ACROSS = 1;
let LOWER_UP = 2;
// The box window's painted lining from 0.35 m into the niche.
let LINING_FROM = 0.35;

// The wainscot's profiles in centimetres, (out from the wall, up from the floor, the
// light's occlusion), bottom to top: the cap from build/notes/wainscot/make_page.py's
// option A (100.5 to 110 cm, 9 cm off the wall), raised CAP_LIFT; the plinth, a plain
// board 17 cm high and 4 cm off the wall on a 1 cm lip at the floor, its top edge rounded
// to catch the light, a dark recess under the panelling's bottom rail. The frame's face
// is 2.5 cm off the wall (surfaces::FRAME_Z).
let CAP_A: float3[20] = [
    float3 { 2.5, 100.5, 0.75 }, float3 { 3.0, 100.7, 0.8 }, float3 { 3.2, 101.2, 0.9 }, float3 { 3.0, 101.69, 0.9 },
    float3 { 2.5, 101.9, 0.75 }, float3 { 2.8, 101.9, 0.75 }, float3 { 3.0, 102.2, 0.8 }, float3 { 3.2, 103.44, 0.85 },
    float3 { 3.76, 104.55, 0.9 }, float3 { 4.65, 105.44, 0.92 }, float3 { 5.76, 106.0, 0.95 }, float3 { 7.0, 106.2, 0.95 },
    float3 { 7.4, 106.2, 0.95 }, float3 { 9.0, 106.2, 1.0 }, float3 { 9.0, 108.0, 1.0 }, float3 { 8.85, 108.77, 1.0 },
    float3 { 8.41, 109.41, 1.0 }, float3 { 7.76, 109.85, 1.0 }, float3 { 7.0, 110.0, 1.0 }, float3 { 0.0, 110.0, 0.85 },
];
let PLINTH_A: float3[11] = [
    float3 { 5.0, 0.0, 0.55 }, float3 { 5.0, 0.8, 0.8 }, float3 { 4.6, 1.2, 0.85 }, float3 { 4.0, 1.4, 0.9 },
    float3 { 4.0, 15.5, 0.95 }, float3 { 3.85, 16.3, 1.0 }, float3 { 3.4, 16.8, 1.0 }, float3 { 2.9, 17.0, 0.95 },
    float3 { 1.8, 17.0, 0.6 }, float3 { 1.8, 18.6, 0.45 }, float3 { 2.5, 19.0, 0.7 },
];
// The cap's lift over option A's 1.1 m, to WAINSCOT_TOP.
let CAP_LIFT: f32 = 10.0;
// The plinth's own tone, a touch darker than the panels' (the oak's own random, scaled).
let PLINTH_TONE: f32 = 0.3;
// The panel's ring (cm in from the frame's opening, out from the wall, occlusion): a stuck
// ovolo on the frame's edge, a 1 cm margin, a shallow bevel rising 0.6 cm, a fillet, the
// field 9 cm in.
let RING_IN: f32[8] = [0.0, 0.6, 1.04, 1.2, 1.2, 5.5, 5.7, 9.0];
let RING_Z:  f32[8] = [2.5, 2.34, 1.9, 1.3, 1.0, 1.6, 1.8, 1.8];
let RING_AO: f32[8] = [1.0, 0.97, 0.88, 0.72, 0.62, 0.9, 0.97, 1.0];
// The cornice (cm out on the ceiling, down from it, occlusion), from build/notes/ceiling/
// gen.py's CONCEPT, from the wall's foot to the ceiling: a bead and fillet, the long cove,
// a fillet and ovolo, two steps out on the ceiling.
let CORNICE_B: float3[31] = [
    float3 { 0.0, 26.0, 0.7 }, float3 { 2.0, 26.0, 0.85 }, float3 { 2.0, 24.5, 0.9 }, float3 { 3.15, 24.27, 1.0 },
    float3 { 4.12, 23.62, 1.0 }, float3 { 4.77, 22.65, 1.0 }, float3 { 5.0, 21.5, 0.95 }, float3 { 5.0, 20.5, 0.85 },
    float3 { 6.0, 20.5, 0.8 }, float3 { 6.23, 18.0, 0.85 }, float3 { 6.93, 15.56, 0.9 }, float3 { 8.07, 13.24, 0.93 },
    float3 { 9.63, 11.1, 0.95 }, float3 { 11.56, 9.19, 0.95 }, float3 { 13.83, 7.56, 0.93 }, float3 { 16.37, 6.24, 0.9 },
    float3 { 19.13, 5.28, 0.86 }, float3 { 22.03, 4.7, 0.82 }, float3 { 25.0, 4.5, 0.78 }, float3 { 27.0, 4.5, 0.85 },
    float3 { 27.0, 3.5, 0.95 }, float3 { 28.15, 3.37, 1.0 }, float3 { 29.12, 3.0, 1.0 }, float3 { 29.77, 2.45, 1.0 },
    float3 { 30.0, 1.8, 0.9 }, float3 { 38.0, 1.8, 0.88 }, float3 { 38.0, 1.0, 0.92 }, float3 { 44.0, 1.0, 0.92 },
    float3 { 45.0, 0.87, 0.95 }, float3 { 45.73, 0.5, 0.97 }, float3 { 46.0, 0.0, 1.0 },
];
// Door 1's architrave, (cm out from the opening's edge, out from the wall): a stepped
// moulding 14 cm wide, 5 cm deep.
let ARCHITRAVE_A: float2[7] = [
    float2 { 0.0, 0.0 }, float2 { 0.0, 2.5 }, float2 { 6.0, 3.2 }, float2 { 11.0, 3.8 }, float2 { 12.0, 5.0 },
    float2 { 14.0, 5.0 }, float2 { 14.0, 0.0 },
];

// How far a door's plinth block stands past the architrave's outer edge, and out of the
// wall (the architrave 5 cm, the skirting 5 cm).
let BLOCK_PAST: f32 = 0.02;
let BLOCK_DEEP: f32 = 0.065;

// How far the wainscot's cap returns into a window's reveal (metres): 6.5 cm, or with the
// shutters folded there to CAP_CLEAR short of their front edges, 1.5 cm (the user,
// 2026-11-21: a shorter return rather than none). Their hinges between the leaves stand
// 8 mm proud of those edges, but under the cap.
let CAP_CLEAR: f32 = 0.005;
fn cap_return() -> f32 { if shutters_on { SHUTTER_FROM - CAP_CLEAR } else { 0.065 } }

// What a run of wainscot is: along a wall or a pier, or under a window (to the sill
// board's foot).
let RUN_WALL = 0;
let RUN_SILL = 1;

let SIDES: f32[2] = [-1.0, 1.0];

// The metre in world units, and a centimetre out from the wall (the frame's face, 2.5 cm,
// at surfaces::FRAME_Z) and up.
fn m() -> f32 { surfaces::METRE }
fn cm_out() -> f32 { surfaces::FRAME_Z / 2.5 }
fn cm_up() -> f32 { surfaces::METRE / 100.0 }

// The builder of wall `w`'s inner face: s along it from a, z into the room.
fn wall_builder(s: Shell, w: Wall) -> surfaces::Builder {
    let o = room_of(s, w.a);
    let d = normalize(room_of(s, w.b) - o);
    let n = normalize(room_of(s, w.a + inward(w)) - o);
    return surfaces::Builder { o, d, n, 0.0, 1.0 };
}

// A builder moved along its wall by `s` and out of it by `z` (world units).
fn moved(b: surfaces::Builder, s: f32, z: f32) -> surfaces::Builder {
    return surfaces::Builder { b.o + b.d * s + b.n * z, b.d, b.n, b.dy, b.deep };
}

// A builder of the plane square to b's wall at its s 0, running into the wall, its face
// toward +s of b (side 1) or -s (side -1).
fn reveal_builder(b: surfaces::Builder, side: f32) -> surfaces::Builder {
    return surfaces::Builder { b.o, b.n * -1.0, b.d * side, 0.0, 1.0 };
}

// A quad of corners in metres (s, y, z of b), its uv the corners' s and y in world units.
fn quad_m(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, p: float3[4], mat: f32,
          side: float3 = float3 { 0.0, 0.0, 1.0 }, ao: f32 = 1.0) {
    let k = m();
    var q:  float3[4] = [float3_0; 4];
    var uv: float2[4] = [float2_0; 4];
    let lines = quiet_paint(mat);
    for i in 4 {
        q[i] = p[i] * k;
        uv[i] = if lines { float2 { NO_LINE, NO_LINE } } else { float2 { q[i].x, q[i].y } };
    }
    surfaces::quad(verts, indices, b, q, uv, [ao, ao, ao, ao], mat, side);
}

// A box over x0..x1, y0..y1, z0..z1 (metres in b's frame), all but its face toward the
// wall (-z).
fn box_m(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, x0: f32, x1: f32, y0: f32, y1: f32,
         z0: f32, z1: f32, mat: f32) {
    quad_m(verts, indices, b, [float3 { x0, y0, z1 }, float3 { x1, y0, z1 }, float3 { x1, y1, z1 }, float3 { x0, y1, z1 }], mat);
    quad_m(verts, indices, b, [float3 { x0, y0, z0 }, float3 { x0, y0, z1 }, float3 { x0, y1, z1 }, float3 { x0, y1, z0 }], mat,
           float3 { -1.0, 0.0, 0.0 });
    quad_m(verts, indices, b, [float3 { x1, y0, z0 }, float3 { x1, y0, z1 }, float3 { x1, y1, z1 }, float3 { x1, y1, z0 }], mat,
           float3 { 1.0, 0.0, 0.0 });
    quad_m(verts, indices, b, [float3 { x0, y1, z0 }, float3 { x1, y1, z0 }, float3 { x1, y1, z1 }, float3 { x0, y1, z1 }], mat,
           float3 { 0.0, 1.0, 0.0 });
    quad_m(verts, indices, b, [float3 { x0, y0, z0 }, float3 { x1, y0, z0 }, float3 { x1, y0, z1 }, float3 { x0, y0, z1 }], mat,
           float3 { 0.0, -1.0, 0.0 });
}

// A profile in centimetres (out, up, occlusion; bottom to top) raised by `lift` cm,
// swept along b's wall from s0 to s1 (world units), each end cut square (k 0) or mitred
// round a corner: an inside corner shortens a point by its distance out (k0 1 at the
// start, k1 -1 at the end), an outside one lengthens it (k0 -1, k1 1). Oak takes its place
// in the wall's field as surfaces::strip does; plaster and paint keep s and the profile's
// length in uv. A point's normal is its two segments' mean where they turn less than
// surfaces::CREASE, so a cove, an ovolo or a bead shades as a curve; at a sharper turn (a
// fillet, a step) each segment keeps its own.
fn sweep(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, prof: float3[], lift: f32, s0: f32, s1: f32,
         k0: f32, k1: f32, mat: f32, seed: i64, out_scale: f32 = 0.0) {
    let none: f32[1] = [0.0];
    sweep_cut(verts, indices, b, prof[..], lift, s0, s1, k0, k1, mat, seed, out_scale, none[..0], 0, -1);
}

// sweep's, its profile's points `first` to `last` cut at `cuts` (world units along the wall,
// those inside every point's ends), the pieces sharing their vertices: where the stiles' and
// rails' corners lie on the profile's edge (the plinth's top, the cap's foot), an edge
// without them leaves pinholes (surfaces::board_cut). The points between are cut too, or
// the next segment's edge would lack them; the segment past the last cut point (the cap's
// top against the paper, the plinth's foot on the floor) is a fan, its far edge whole. Each
// segment stays one chart, its attributes affine along the wall.
fn sweep_cut(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, prof: float3[], lift: f32, s0: f32,
             s1: f32, k0: f32, k1: f32, mat: f32, seed: i64, out_scale: f32, cuts: f32[], first: i64, last: i64) {
    let kz = if out_scale > 0.0 { out_scale } else { cm_out() };
    let ky = cm_up();
    var pts: float3[..32] = [];
    for q in prof { pts.push(float3 { q.x * kz, (q.y + lift) * ky, q.z }); }
    var total: f32 = 0.0;
    for k in 1..pts.len { total += length(float2 { pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y }); }
    var flat: float3[..32] = [float3_0];
    for k in 1..pts.len {
        let d = float2 { pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y };
        flat.push(if length(d) > 0.000001 { normalize(float3 { 0.0, -d.x, d.y }) } else { float3_0 });
    }
    let oak = mat < surfaces::MAT_OAK + 0.5;
    let pm = surfaces::piece_map(seed, false, s0, 0.0, total, s1 - s0, true);
    let own = if oak { surfaces::MAT_OAK + 0.9 * surfaces::hash(seed, 9) } else { mat };
    var lo: f32 = s0;
    var hi: f32 = s1;
    for q in pts {
        lo = max(lo, s0 + k0 * q.x);
        hi = min(hi, s1 + k1 * q.x);
    }
    var inner: f32[..160] = [];
    for x in cuts {
        if x > lo && x < hi && inner.len < 160 { inner.push(x); }
    }
    var t: f32 = 0.0;
    for k in 1..pts.len {
        let a = pts[k - 1];
        let c = pts[k];
        let d = float2 { c.x - a.x, c.y - a.y };
        let t1 = t + length(d);
        let n = flat[k];
        let na = surfaces::world_normal(b, if k > 1 { surfaces::smooth_normal(n, flat[k - 1]) } else { n });
        let nc = surfaces::world_normal(b, if k + 1 < pts.len { surfaces::smooth_normal(n, flat[k + 1]) } else { n });
        let sa0 = s0 + k0 * a.x;
        let sa1 = s1 + k1 * a.x;
        let sc0 = s0 + k0 * c.x;
        let sc1 = s1 + k1 * c.x;
        let base = verts.len as u32;
        let cut_a = inner.len > 0 && k - 1 >= first && k - 1 <= last;
        let cut_c = inner.len > 0 && k >= first && k <= last;
        if cut_a || cut_c {
            // Each row's places along: its start, the cuts if it is cut, its end.
            let rows: float3[2] = [a, c];
            let ns: float3[2] = [na, nc];
            let ends: float2[2] = [float2 { sa0, sa1 }, float2 { sc0, sc1 }];
            let ts: f32[2] = [t, t1];
            let cut: bool[2] = [cut_a, cut_c];
            for r in 2 {
                let q = rows[r];
                let n_in = if cut[r] { inner.len } else { 0 };
                for i in n_in + 2 {
                    let x = if i == 0 { ends[r].x } else if i == n_in + 1 { ends[r].y } else { inner[i - 1] };
                    let uv = if oak { surfaces::place(pm, x, ts[r]) } else { float2 { x, ts[r] } };
                    verts.push(mesh::Vertex { surfaces::world(b, x, q.y, q.x), ns[r], uv, q.z, own });
                }
            }
            let cols = (inner.len + 2) as u32;
            if cut_a && cut_c {
                for i in inner.len + 1 {
                    let v = base + (i as u32);
                    indices.append([v, v + 1, v + cols + 1, v, v + cols + 1, v + cols]);
                }
            } else if cut_a {
                // Row a cut, c whole (c0 at base + cols, c1 after it): a fan from c0.
                let c0 = base + cols;
                for i in inner.len + 1 {
                    let v = base + (i as u32);
                    indices.append([v, v + 1, c0]);
                }
                indices.append([base + cols - 1, c0 + 1, c0]);
            } else {
                // Row a whole (a0, a1), c cut after them: a fan from a0.
                let c0 = base + 2;
                indices.append([base, base + 1, c0 + cols - 1]);
                for i in inner.len + 1 {
                    let v = c0 + (i as u32);
                    indices.append([base, v + 1, v]);
                }
            }
            t = t1;
            continue;
        }
        let uv: float2[4] = if oak { [surfaces::place(pm, sa0, t), surfaces::place(pm, sa1, t), surfaces::place(pm, sc1, t1),
                                     surfaces::place(pm, sc0, t1)] }
                            else { [float2 { sa0, t }, float2 { sa1, t }, float2 { sc1, t1 }, float2 { sc0, t1 }] };
        verts.push(mesh::Vertex { surfaces::world(b, sa0, a.y, a.x), na, uv[0], a.z, own });
        verts.push(mesh::Vertex { surfaces::world(b, sa1, a.y, a.x), na, uv[1], a.z, own });
        verts.push(mesh::Vertex { surfaces::world(b, sc1, c.y, c.x), nc, uv[2], c.z, own });
        verts.push(mesh::Vertex { surfaces::world(b, sc0, c.y, c.x), nc, uv[3], c.z, own });
        indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
        t = t1;
    }
}

// The square end of a profile (as sweep's) at s, facing +s (side 1) or -s (-1): each
// segment down to the wall behind it.
fn profile_end(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, prof: float3[], lift: f32, s: f32,
               side: f32, seed: i64) {
    let kz = cm_out();
    let ky = cm_up();
    let own = surfaces::MAT_OAK + 0.9 * surfaces::hash(seed, 9);
    for k in 1..prof.len {
        let a = prof[k - 1];
        let c = prof[k];
        let p: float3[4] = [float3 { s, (a.y + lift) * ky, 0.0 }, float3 { s, (a.y + lift) * ky, a.x * kz },
                            float3 { s, (c.y + lift) * ky, c.x * kz }, float3 { s, (c.y + lift) * ky, 0.0 }];
        let uv: float2[4] = [float2 { 3.0, p[0].y }, float2 { 3.0 + p[1].z, p[1].y }, float2 { 3.0 + p[2].z, p[2].y },
                             float2 { 3.0, p[3].y }];
        surfaces::quad(verts, indices, b, p, uv, [0.8, 1.0, 1.0, 0.8], own, float3 { side, 0.0, 0.0 });
    }
}

// The oak sweep cut into lengths of at most about two metres, each its own piece of the
// field, the ends k0 and k1.
// Its points first to last cut at `cuts` (sweep_cut).
fn sweep_oak(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, prof: float3[], lift: f32, s0: f32,
             s1: f32, k0: f32, k1: f32, seed: i64&, cuts: f32[], first: i64, last: i64) {
    let pieces = max(1, ceil((s1 - s0) / (2.0 * m())) as i64);
    let step = (s1 - s0) / pieces;
    for i in pieces {
        seed++;
        let a = s0 + step * i;
        let e = if i == pieces - 1 { s1 } else { a + step };
        sweep_cut(verts, indices, b, prof[..], lift, a, e, if i == 0 { k0 } else { 0.0 }, if i == pieces - 1 { k1 } else { 0.0 },
                  surfaces::MAT_OAK, seed, 0.0, cuts[..], first, last);
    }
}

// The stiles' edges of panelling's run from s0 to s1, about `bay` metres a bay, worked out
// as panelling does, so they are the same floats.
fn stile_edges(s0: f32, s1: f32, bay: f32) -> f32[..128] {
    let k = cm_up();
    let stile = 9.0 * k;
    let bays = max(1, floor((s1 - s0 - stile) / (bay * m()) + 0.5) as i64);
    let w = (s1 - s0 - stile) / bays;
    var out: f32[..128] = [];
    for j in min(bays + 1, 64) {
        let x = s0 + w * j;
        out.push(x);
        out.push(x + stile);
    }
    return out;
}

// Where sweep_oak's lengths over s0..s1 join, as it works them out.
fn sweep_joints(s0: f32, s1: f32) -> f32[..16] {
    let pieces = max(1, ceil((s1 - s0) / (2.0 * m())) as i64);
    let step = (s1 - s0) / pieces;
    var out: f32[..16] = [];
    for i in 1..min(pieces, 17) { out.push(s0 + step * i); }
    return out;
}

// The places of `xs` strictly between lo and hi, in order.
fn inside(xs: f32[], lo: f32, hi: f32) -> f32[..16] {
    var out: f32[..16] = [];
    for x in xs {
        if x > lo && x < hi && out.len < 16 { out.push(x); }
    }
    return out;
}

// The panelling of a run from s0 to s1 (world units): its stiles, rails and raised
// panels between `low` and `top` cm, the panels in the registers `rows` (cm, bottom and
// top), about `bay` metres a panel and a stile.
fn panelling(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, s0: f32, s1: f32, low: f32, top: f32,
             rows: float2[], bay: f32, seed: i64&) {
    let k = cm_up();
    let stile = 9.0 * k;
    let bays = max(1, floor((s1 - s0 - stile) / (bay * m()) + 0.5) as i64);
    let w = (s1 - s0 - stile) / bays;
    var ring_in: f32[8] = [0.0; 8];
    var ring_z:  f32[8] = [0.0; 8];
    for i in 8 {
        ring_in[i] = RING_IN[i] * k;
        ring_z[i] = RING_Z[i] * cm_out();
    }
    // Each piece cut where another's corner lies on its edge (surfaces::board_cut): the
    // stiles up at the registers' heights, and the stiles and the first and last rails
    // along where the plinth's and the cap's lengths join (sweep_joints).
    var ys: f32[..16] = [];
    for r in rows {
        ys.push(r.x * k);
        ys.push(r.y * k);
    }
    let joints = sweep_joints(s0, s1);
    let none: f32[1] = [0.0];
    var left = surfaces::Map { float2_0, float4_0 };
    for j in bays + 1 {
        let x = s0 + w * j;
        seed++;
        let st = surfaces::piece_map(seed, true, x, low * k, stile, (top - low) * k, true);
        let across = inside(joints[..], x, x + stile);
        surfaces::board_cut(verts, indices, b, x, x + stile, low * k, top * k, true, seed, across[..], ys[..]);
        if j > 0 {
            let x0 = s0 + w * (j - 1) + stile;
            let x1 = x;
            let along = inside(joints[..], x0, x1);
            // The rails: under the first register, between them, over the last.
            var below = low;
            var maps: surfaces::Map[..8] = [];
            for r, i in rows {
                seed++;
                maps.push(surfaces::piece_map(seed, false, x0, below * k, (r.x - below) * k, x1 - x0, true));
                let cuts = if i == 0 { along[..] } else { none[..0] };
                surfaces::board_cut(verts, indices, b, x0, x1, below * k, r.x * k, false, seed, cuts, none[..0], 0.85);
                below = r.y;
            }
            seed++;
            maps.push(surfaces::piece_map(seed, false, x0, below * k, (top - below) * k, x1 - x0, true));
            surfaces::board_cut(verts, indices, b, x0, x1, below * k, top * k, false, seed, along[..], none[..0], 0.9);
            for r, i in rows {
                seed++;
                surfaces::panel_ring(verts, indices, b, x0, x1, r.x * k, r.y * k, seed, maps[i], maps[i + 1], left, st, ring_in,
                                     ring_z, RING_AO);
            }
        }
        left = st;
    }
}

// A run of wainscot from s0 to s1 (world units) of `kind`; `ends` how its cap meets
// what is past each end: 0 a wall at an inside corner (the plinth and cap mitred into
// it), 1 a window's niche (the cap wrapping into its reveal, cap_return), 2 a door's
// architrave (the cap's end returned, the plinth square against the plinth block). A run
// under a sill butts on the wall's runs either side.
fn wainscot_run(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, s0: f32, s1: f32, kind: i64,
                start_end: i64, finish_end: i64, seed: i64&) {
    let first = verts.len;
    let corner0 = kind == RUN_WALL && start_end == 0;
    let corner1 = kind == RUN_WALL && finish_end == 0;
    // The plinth's top and the cap's foot cut where the stiles' edges meet them.
    let bay: f32 = if kind == RUN_WALL { 0.34 } else { 0.4 };
    let edges = stile_edges(s0, s1, bay);
    sweep_oak(verts, indices, b, PLINTH_A[..], 0.0, s0, s1, if corner0 { 1.0 } else { 0.0 }, if corner1 { -1.0 } else { 0.0 },
              seed, edges[..], 1, PLINTH_A.len - 1);
    for i in first..verts.len {
        let v .= verts[i];
        v.mat = surfaces::MAT_OAK + PLINTH_TONE * (v.mat - floor(v.mat));
    }
    if kind == RUN_WALL {
        let rows: float2[1] = [float2 { 28.0, 98.0 }];
        panelling(verts, indices, b, s0, s1, 19.0, 100.5 + CAP_LIFT, rows[..], bay, seed);
    } else {
        let rows: float2[1] = [float2 { 28.0, 64.0 }];
        panelling(verts, indices, b, s0, s1, 19.0, 75.0, rows[..], bay, seed);
    }
    guard kind != RUN_SILL else { return; }
    let lift = CAP_LIFT;
    let k0: f32 = if start_end == 1 { -1.0 } else if corner0 { 1.0 } else { 0.0 };
    let k1: f32 = if finish_end == 1 { 1.0 } else if corner1 { -1.0 } else { 0.0 };
    sweep_oak(verts, indices, b, CAP_A[..], lift, s0, s1, k0, k1, seed, edges[..], 0, CAP_A.len - 2);
    let ends: i64[2] = [start_end, finish_end];
    let at:   f32[2] = [s0, s1];
    let side: f32[2] = [-1.0, 1.0];
    for e, i in ends {
        seed++;
        if e == 2 { profile_end(verts, indices, b, CAP_A[..], lift, at[i], side[i], seed); }
        guard e == 1 else { continue; }
        // Round the pier's corner and into the reveal, its end square; the frame's edge
        // under it.
        let r = reveal_builder(moved(b, at[i], 0.0), side[i]);
        sweep(verts, indices, r, CAP_A[..], lift, 0.0, cap_return() * m(), -1.0, 0.0, surfaces::MAT_OAK, seed);
        profile_end(verts, indices, r, CAP_A[..], lift, cap_return() * m(), 1.0, seed);
        let fz = surfaces::FRAME_Z;
        let k = cm_up();
        // The cap's underside behind its foot round the corner, where no panelling is under it.
        let foot = (lift + 100.5) * k;
        let back = cap_return() * m();
        let under:    float3[4] = [float3 { -fz, foot, 0.0 }, float3 { back, foot, 0.0 }, float3 { back, foot, fz }, float3 { -fz, foot, fz }];
        let under_uv: float2[4] = [float2 { -fz, 0.0 }, float2 { back, 0.0 }, float2 { back, fz }, float2 { -fz, fz }];
        surfaces::quad(verts, indices, r, under, under_uv, [0.8, 0.8, 0.8, 0.8], surfaces::MAT_OAK + 0.5, float3 { 0.0, -1.0, 0.0 });
        let p: float3[4] = [float3 { at[i], 75.0 * k, 0.0 }, float3 { at[i], 75.0 * k, fz }, float3 { at[i], (lift + 100.5) * k, fz },
                            float3 { at[i], (lift + 100.5) * k, 0.0 }];
        let uv: float2[4] = [float2 { 1.0, p[0].y }, float2 { 1.0 + fz, p[1].y }, float2 { 1.0 + fz, p[2].y }, float2 { 1.0, p[3].y }];
        surfaces::quad(verts, indices, b, p, uv, [0.8, 1.0, 1.0, 0.8], surfaces::MAT_OAK + 0.5, float3 { side[i], 0.0, 0.0 });
    }
}

// The openings of wall `wall`, in order along it.
fn openings_on(s: Shell, wall: i64) -> Opening[..8] {
    var out: Opening[..8] = [];
    for k in s.count {
        guard s.openings[k].wall == wall else { continue; }
        out.push(s.openings[k]);
    }
    sort(out) { a, c => a.mid < c.mid };
    return out;
}

// The wallpaper over wall b of `length` metres from `low` to the cornice's foot, round its
// openings: whole between them, over a door's architrave or a bookcase, and over a
// window's band, its arch in segments.
fn wallpaper(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell, b: surfaces::Builder, length: f32, low: f32,
             ops: Opening[..8]&) {
    let top = s.ceiling - CORNICE_DROP;
    let paper = surfaces::MAT_PAPER;
    var at: f32 = 0.0;
    for o in ops {
        let half = reach(o);
        let a = o.mid - half;
        if a > at { quad_m(verts, indices, b, [float3 { at, low, 0.0 }, float3 { a, low, 0.0 }, float3 { a, top, 0.0 },
                                               float3 { at, top, 0.0 }], paper); }
        if o.kind != WINDOW {
            let y = surround_top(o);
            quad_m(verts, indices, b, [float3 { a, y, 0.0 }, float3 { o.mid + half, y, 0.0 }, float3 { o.mid + half, top, 0.0 },
                                       float3 { a, top, 0.0 }], paper);
        } else {
            let segs = 16;
            for i in segs {
                let x0 = -half + 2.0 * half * i / segs;
                let x1 = -half + 2.0 * half * (i + 1) / segs;
                quad_m(verts, indices, b, [float3 { o.mid + x0, band_outer(o, x0), 0.0 }, float3 { o.mid + x1, band_outer(o, x1), 0.0 },
                                           float3 { o.mid + x1, top, 0.0 }, float3 { o.mid + x0, top, 0.0 }], paper);
            }
        }
        at = o.mid + half;
    }
    if length > at { quad_m(verts, indices, b, [float3 { at, low, 0.0 }, float3 { length, low, 0.0 }, float3 { length, top, 0.0 },
                                                float3 { at, top, 0.0 }], paper); }
}

// The band's outer edge over a window's arch at x from its middle (metres): concentric
// with the arch, BAND wider.
fn band_outer(o: Opening, x: f32) -> f32 {
    let r = arch_radius(o) + BAND;
    return arch_middle(o) + sqrt(max(r * r - x * x, 0.0));
}

// The arch's segments: the soffit's edge at t of -1..1 across the niche, and the band's
// outer edge with it.
let ARCH_SEGMENTS = 12;

// The sill (window's): a pale limestone slab SILL_BOARD thick, its nose SILL_NOSE out in the
// room and 5 cm past the niche each side, over the niche's floor to its back, depth into
// the wall. Its uv carries the profile ROOM_FRAG's stone reads: x metres along the wall, y
// the distance from the nose's top arris (metres), back over the top and down the nose and
// under it below 0; its ends SILL_END.
let SILL_END: f32 = 9.0;
fn sill_slab(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, o: Opening, w: f32, depth: f32) {
    let k = m();
    let x0 = -w - 0.05;
    let x1 = w + 0.05;
    let y0 = o.sill - SILL_BOARD;
    let y1 = o.sill;
    let z1 = SILL_NOSE;
    let under = -SILL_BOARD - SILL_NOSE;
    let faces: float3[4][6] = [
        [float3 { x0, y0, z1 }, float3 { x1, y0, z1 }, float3 { x1, y1, z1 }, float3 { x0, y1, z1 }],
        [float3 { x0, y0, 0.0 }, float3 { x0, y0, z1 }, float3 { x0, y1, z1 }, float3 { x0, y1, 0.0 }],
        [float3 { x1, y0, 0.0 }, float3 { x1, y0, z1 }, float3 { x1, y1, z1 }, float3 { x1, y1, 0.0 }],
        [float3 { x0, y1, 0.0 }, float3 { x1, y1, 0.0 }, float3 { x1, y1, z1 }, float3 { x0, y1, z1 }],
        [float3 { x0, y0, 0.0 }, float3 { x1, y0, 0.0 }, float3 { x1, y0, z1 }, float3 { x0, y0, z1 }],
        [float3 { -w, y1, -depth }, float3 { w, y1, -depth }, float3 { w, y1, 0.0 }, float3 { -w, y1, 0.0 }],
    ];
    let sides: float3[6] = [float3 { 0.0, 0.0, 1.0 }, float3 { -1.0, 0.0, 0.0 }, float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, 1.0, 0.0 },
                            float3 { 0.0, -1.0, 0.0 }, float3 { 0.0, 1.0, 0.0 }];
    for f, i in faces {
        var q:  float3[4] = [float3_0; 4];
        var uv: float2[4] = [float2_0; 4];
        for j in 4 {
            let p = f[j];
            q[j] = p * k;
            let t = if i == 0 { p.y - y1 } else if i == 1 || i == 2 { SILL_END } else if i == 4 { under + p.z } else { z1 - p.z };
            uv[j] = float2 { o.mid + p.x, t };
        }
        surfaces::quad(verts, indices, b, q, uv, [1.0, 1.0, 1.0, 1.0], surfaces::MAT_STONE, sides[i]);
    }
}

// A window in wall b (metres, b's s at its middle): the band round the niche, the
// reveals, the arch's soffit and the lunette over the casement, the sill board, the two
// casements with their glass, the folded shutters, and the curtains (curtains.goose).
fn window(verts: mesh::Vertex[>..]&, indices: u32[>..]&, glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&,
          wb: surfaces::Builder, o: Opening, seed: i64&) {
    let b = moved(wb, o.mid * m(), 0.0);
    let plaster = surfaces::MAT_PLASTER;
    let paint = if paint_quiet { paint_mat(0.5, false, true) } else { surfaces::MAT_PAINT };
    let w = 0.5 * o.width;
    let wo = w + BAND;
    let sill = o.sill;
    let spring = o.sill + o.height;
    let depth = o.glass.z;
    let top_out = band_outer(o, wo);
    let bz = BAND_PROUD;
    // The band: up each side from the pier's cap, round the arch; its edges back to the wall.
    for sx in SIDES {
        let a = sx * w;
        let c = sx * wo;
        quad_m(verts, indices, b, [float3 { a, WAINSCOT_TOP, bz }, float3 { c, WAINSCOT_TOP, bz }, float3 { c, top_out, bz },
                                   float3 { a, spring, bz }], plaster);
        quad_m(verts, indices, b, [float3 { c, WAINSCOT_TOP, 0.0 }, float3 { c, WAINSCOT_TOP, bz }, float3 { c, top_out, bz },
                                   float3 { c, top_out, 0.0 }], plaster, float3 { sx, 0.0, 0.0 });
        quad_m(verts, indices, b, [float3 { a, WAINSCOT_TOP, 0.0 }, float3 { a, WAINSCOT_TOP, bz }, float3 { a, spring, bz },
                                   float3 { a, spring, 0.0 }], plaster, float3 { -sx, 0.0, 0.0 });
    }
    for i in ARCH_SEGMENTS {
        let t0 = -1.0 + 2.0 * i / ARCH_SEGMENTS;
        let t1 = -1.0 + 2.0 * (i + 1) / ARCH_SEGMENTS;
        let i0 = float2 { w * t0, head_at(o, w * t0) };
        let i1 = float2 { w * t1, head_at(o, w * t1) };
        let o0 = float2 { wo * t0, band_outer(o, wo * t0) };
        let o1 = float2 { wo * t1, band_outer(o, wo * t1) };
        quad_m(verts, indices, b, [float3 { i0.x, i0.y, bz }, float3 { i1.x, i1.y, bz }, float3 { o1.x, o1.y, bz },
                                   float3 { o0.x, o0.y, bz }], plaster);
        quad_m(verts, indices, b, [float3 { o0.x, o0.y, 0.0 }, float3 { o1.x, o1.y, 0.0 }, float3 { o1.x, o1.y, bz },
                                   float3 { o0.x, o0.y, bz }], plaster, float3 { 0.0, 1.0, 0.0 });
        quad_m(verts, indices, b, [float3 { i0.x, i0.y, 0.0 }, float3 { i1.x, i1.y, 0.0 }, float3 { i1.x, i1.y, bz },
                                   float3 { i0.x, i0.y, bz }], plaster, float3 { 0.0, -1.0, 0.0 });
        // The soffit into the wall, and the lunette at the niche's back over the casement.
        quad_m(verts, indices, b, [float3 { i0.x, i0.y, 0.0 }, float3 { i1.x, i1.y, 0.0 }, float3 { i1.x, i1.y, -depth },
                                   float3 { i0.x, i0.y, -depth }], plaster, float3 { 0.0, -1.0, 0.0 }, 0.9);
        quad_m(verts, indices, b, [float3 { i0.x, spring, -depth }, float3 { i1.x, spring, -depth }, float3 { i1.x, i1.y, -depth },
                                   float3 { i0.x, i0.y, -depth }], plaster, float3 { 0.0, 0.0, 1.0 }, 0.85);
    }
    // The reveals, plaster to the box window's lining, painted beyond; the lining's head.
    for sx in SIDES {
        let x = sx * w;
        quad_m(verts, indices, b, [float3 { x, sill, 0.0 }, float3 { x, sill, -LINING_FROM }, float3 { x, spring, -LINING_FROM },
                                   float3 { x, spring, 0.0 }], plaster, float3 { -sx, 0.0, 0.0 }, 0.92);
        quad_m(verts, indices, b, [float3 { x, sill, -LINING_FROM }, float3 { x, sill, -depth }, float3 { x, spring, -depth },
                                   float3 { x, spring, -LINING_FROM }], paint, float3 { -sx, 0.0, 0.0 }, 0.85);
    }
    quad_m(verts, indices, b, [float3 { -w, spring, -LINING_FROM }, float3 { w, spring, -LINING_FROM }, float3 { w, spring, -depth },
                               float3 { -w, spring, -depth }], paint, float3 { 0.0, -1.0, 0.0 }, 0.8);
    sill_slab(verts, indices, b, o, w, depth);
    // The casements, the inner glass and the outer.
    if paint_quiet {
        // Their pieces' seeds apart from the shell's, which the curtains and books go on with.
        var own = 7919 * seed + 17;
        casement_quiet(verts, indices, glass, glass_indices, b, o, o.glass.x, own);
        casement_quiet(verts, indices, glass, glass_indices, b, o, o.glass.y, own);
    } else {
        casement(verts, indices, glass, glass_indices, b, o, o.glass.x);
        casement(verts, indices, glass, glass_indices, b, o, o.glass.y);
    }
    // The shutters, two leaves a side folded against the reveal; one stands ajar.
    if shutters_on {
        for sx in SIDES {
            let ajar = if sx < 0.0 && abs(o.mid - AJAR_WINDOW) < 0.01 { SHUTTER_AJAR } else { 0.0 };
            shutters(verts, indices, b, o, sx, ajar, seed);
        }
    }
    curtains(verts, indices, glass, glass_indices, b, o, seed);
}

// The window whose right shutters (seen from the room, b's -s, toward the stove's end)
// stand ajar, the plan's x of its middle: the middle one, near in style-01's view.
let AJAR_WINDOW: f32 = 4.5;
// The shutters' brass knuckle hinges (metres): the barrel's radius and half length; three a
// side on the lining at the front leaf's back edge, two between the leaves at their front
// edges, each SHUTTER_HINGE_IN from the leaf's foot and head, and at its middle.
let SHUTTER_KNUCKLE:      f32 = 0.005;
let SHUTTER_KNUCKLE_HALF: f32 = 0.035;
let SHUTTER_HINGE_IN:     f32 = 0.22;
// The joint between the folded leaves, seen at their front edges.
let SHUTTER_JOINT: f32 = 0.003;

// Window o's shutters on side sx (b's s at the window's middle, metres): the front leaf with
// its three raised panels toward the middle, the back leaf behind it against the reveal,
// their front edges with the joint between them, and their hinges, the pair turned `ajar`
// degrees about the lining's hinges toward the middle. Built on a builder of the leaves'
// own: s from the back edge toward the room, z from the reveal toward the middle.
fn shutters(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, o: Opening, sx: f32, ajar: f32,
            seed: i64&) {
    let k = m();
    let w = 0.5 * o.width;
    let paint = if paint_quiet { paint_mat(0.5, false, true) } else { surfaces::MAT_PAINT };
    let stack = SHUTTER_FRONT + SHUTTER_BACK;
    let y0 = o.sill + 0.005;
    let y1 = o.sill + o.height - CASE_HEAD;
    // The leaves' frame folded flat, and the lining's hinges' axis in it.
    let along = b.n;
    let out = b.d * -sx;
    let flat_o = b.o + b.d * (sx * w * k) + b.n * (-SHUTTER_TO * k);
    let hinge = float2 { -0.002, stack + 0.004 };
    let pivot = flat_o + along * (hinge.x * k) + out * (hinge.y * k);
    let a = ajar * PI / 180.0;
    let d = along * cos(a) + out * sin(a);
    let n = out * cos(a) - along * sin(a);
    let l = surfaces::Builder { pivot - d * (hinge.x * k) - n * (hinge.y * k), d, n, 0.0, 1.0 };
    let leaf = SHUTTER_LEAF;
    let j = 0.5 * SHUTTER_JOINT;
    // The front edges, the front leaf's, the joint, the back leaf's; the back leaf's back,
    // seen when the pair stands ajar.
    if !paint_quiet {
        quad_m(verts, indices, l, [float3 { leaf, y0, SHUTTER_BACK + j }, float3 { leaf, y0, stack }, float3 { leaf, y1, stack },
                                   float3 { leaf, y1, SHUTTER_BACK + j }], paint, float3 { 1.0, 0.0, 0.0 });
    }
    quad_m(verts, indices, l, [float3 { leaf, y0, SHUTTER_BACK - j }, float3 { leaf, y0, SHUTTER_BACK + j },
                               float3 { leaf, y1, SHUTTER_BACK + j }, float3 { leaf, y1, SHUTTER_BACK - j }], paint,
           float3 { 1.0, 0.0, 0.0 }, 0.3);
    quad_m(verts, indices, l, [float3 { leaf, y0, 0.0 }, float3 { leaf, y0, SHUTTER_BACK - j }, float3 { leaf, y1, SHUTTER_BACK - j },
                               float3 { leaf, y1, 0.0 }], paint, float3 { 1.0, 0.0, 0.0 });
    if ajar > 0.0 {
        let back = surfaces::Builder { l.o, l.d, l.n * -1.0, 0.0, 1.0 };
        quad_m(verts, indices, back, [float3 { 0.0, y0, 0.0 }, float3 { leaf, y0, 0.0 }, float3 { leaf, y1, 0.0 },
                                      float3 { 0.0, y1, 0.0 }], paint, float3 { 0.0, 0.0, 1.0 }, 0.8);
        quad_m(verts, indices, l, [float3 { 0.0, y1, 0.0 }, float3 { leaf, y1, 0.0 }, float3 { leaf, y1, stack }, float3 { 0.0, y1, stack }],
               paint, float3 { 0.0, 1.0, 0.0 });
    }
    // The front leaf's face: its stiles' and rails' face at the stack's, the panels sunk in it.
    let face = moved(l, 0.0, (stack * k) - surfaces::FRAME_Z);
    let rows: float2[3] = [float2 { 0.9, 1.62 }, float2 { 1.72, 2.62 }, float2 { 2.72, 3.16 }];
    if paint_quiet {
        painted_quiet(verts, indices, face, 0.0, leaf * k, y0, y1, 0.06, rows[..], SHUTTER_FRONT - j, RIGHT | TOP | BOTTOM, RIGHT, true,
                      1.0, seed);
    } else { painted(verts, indices, face, 0.0, leaf * k, y0, y1, 0.06, rows[..], seed); }
    // The hinges: on the lining at the front leaf's back edge, and between the leaves.
    let mid = 0.5 * (y0 + y1);
    let heights: f32[3] = [y0 + SHUTTER_HINGE_IN, mid, y1 - SHUTTER_HINGE_IN];
    for y in heights {
        knuckle(verts, indices, l, float3 { hinge.x, y, hinge.y }, SHUTTER_KNUCKLE, SHUTTER_KNUCKLE_HALF, 6, false);
    }
    for y in [heights[0], heights[2]] {
        knuckle(verts, indices, l, float3 { leaf + 0.003, y, SHUTTER_BACK }, SHUTTER_KNUCKLE, SHUTTER_KNUCKLE_HALF, 6, false);
    }
}

// A profile of (across, out) points (metres, from x0 along b's s and from z0 out of the
// wall) swept up from y0 to y1, its normals smoothed as lathe's.
fn upright_sweep(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, prof: float2[], x0: f32, z0: f32, y0: f32,
                 y1: f32, mat: f32) {
    let k = m();
    let lines = quiet_paint(mat);
    var flat: float3[..16] = [float3_0];
    for i in 1..prof.len {
        let t = prof[i] - prof[i - 1];
        flat.push(if length(t) > 0.000001 { normalize(float3 { -t.y, 0.0, t.x }) } else { float3_0 });
    }
    for i in 1..prof.len {
        let n = flat[i];
        guard length_sq(n) > 0.0 else { continue; }
        let na = surfaces::world_normal(b, if i > 1 { surfaces::smooth_normal(n, flat[i - 1]) } else { n });
        let nc = surfaces::world_normal(b, if i + 1 < prof.len { surfaces::smooth_normal(n, flat[i + 1]) } else { n });
        let a = prof[i - 1];
        let c = prof[i];
        let base = verts.len as u32;
        let line = float2 { NO_LINE, NO_LINE };
        verts.push(mesh::Vertex { surfaces::world(b, (x0 + a.x) * k, y0 * k, (z0 + a.y) * k), na,
                                  if lines { line } else { float2 { (x0 + a.x) * k, y0 * k } }, 1.0, mat });
        verts.push(mesh::Vertex { surfaces::world(b, (x0 + a.x) * k, y1 * k, (z0 + a.y) * k), na,
                                  if lines { line } else { float2 { (x0 + a.x) * k, y1 * k } }, 1.0, mat });
        verts.push(mesh::Vertex { surfaces::world(b, (x0 + c.x) * k, y1 * k, (z0 + c.y) * k), nc,
                                  if lines { line } else { float2 { (x0 + c.x) * k, y1 * k } }, 1.0, mat });
        verts.push(mesh::Vertex { surfaces::world(b, (x0 + c.x) * k, y0 * k, (z0 + c.y) * k), nc,
                                  if lines { line } else { float2 { (x0 + c.x) * k, y0 * k } }, 1.0, mat });
        indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
}

// A brass knuckle hinge's barrel standing upright at c (metres in b's frame), its radius r
// and half length `half`, `sides` round: with `finials` a small ball at each end (the
// doors'), else a short point (the shutters', a pixel or two in every view).
fn knuckle(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: float3, r: f32, half: f32, sides: i64,
           finials: bool) {
    if finials {
        let f = 0.8 * r;
        let prof: float2[6] = [float2 { 0.0, -half - 1.75 * f }, float2 { 0.8 * f, -half - 0.85 * f }, float2 { r, -half },
                               float2 { r, half }, float2 { 0.8 * f, half + 0.85 * f }, float2 { 0.0, half + 1.75 * f }];
        lathe(verts, indices, b, c, prof[..], sides, surfaces::MAT_BRASS);
    } else {
        let prof: float2[4] = [float2 { 0.0, -half - 0.8 * r }, float2 { r, -half }, float2 { r, half }, float2 { 0.0, half + 0.8 * r }];
        lathe(verts, indices, b, c, prof[..], sides, surfaces::MAT_BRASS);
    }
}

// A profile of (radius, height) points (metres, bottom to top) turned about the upright
// axis through c (metres in b's frame), `sides` round. A point's normal is its two
// segments' mean where they turn less than surfaces::CREASE, so a ball or a bead shades
// round, and a segment's own at a sharper turn (a barrel's square end).
fn lathe(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: float3, prof: float2[], sides: i64, mat: f32) {
    let k = m();
    var flat: float3[..16] = [float3_0];
    for i in 1..prof.len {
        let t = prof[i] - prof[i - 1];
        flat.push(if length(t) > 0.000001 { normalize(float3 { t.y, -t.x, 0.0 }) } else { float3_0 });
    }
    for i in 1..prof.len {
        let n = flat[i];
        guard length_sq(n) > 0.0 else { continue; }
        let na = if i > 1 { surfaces::smooth_normal(n, flat[i - 1]) } else { n };
        let nc = if i + 1 < prof.len { surfaces::smooth_normal(n, flat[i + 1]) } else { n };
        let ends: float2[2] = [prof[i - 1], prof[i]];
        let ns:   float3[2] = [na, nc];
        let base = verts.len as u32;
        for e in 2 {
            for s in sides + 1 {
                let ang: f32 = TAU * s / sides;
                let ca = cos(ang);
                let sa = sin(ang);
                let p = (c + float3 { ca * ends[e].x, ends[e].y, sa * ends[e].x }) * k;
                let q = float3 { ca * ns[e].x, ns[e].y, sa * ns[e].x };
                verts.push(mesh::Vertex { surfaces::world(b, p.x, p.y, p.z), surfaces::world_normal(b, q), float2_0, 1.0, mat });
            }
        }
        let ring = (sides + 1) as u32;
        for s in sides {
            let s0 = base + s as u32;
            indices.append([s0, s0 + 1, s0 + ring + 1, s0, s0 + ring + 1, s0 + ring]);
        }
    }
}

// The two halves of a casement at the glass plane `g` metres into the wall from b's face:
// the blind frame (jambs, head, sill, transom), each sash's stiles and rails, the cover
// strip over the meeting, the bars, and one sheet of glass behind them.
fn casement(verts: mesh::Vertex[>..]&, indices: u32[>..]&, glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&,
            b: surfaces::Builder, o: Opening, g: f32) {
    let paint = surfaces::MAT_PAINT;
    let w = 0.5 * o.width;
    let gx = 0.5 * o.glass.w - CASE_FRAME;
    let s = o.sill;
    let h = o.sill + o.height;
    let zt = s + (h - s) * 2.0 / 3.0;
    // The blind frame, 0.1 m deep about the glass.
    let f0 = -(g + 0.05);
    let f1 = -(g - 0.05);
    box_m(verts, indices, b, -w, -gx, s - 0.03, h, f0, f1, paint);
    box_m(verts, indices, b, gx, w, s - 0.03, h, f0, f1, paint);
    box_m(verts, indices, b, -gx, gx, h - CASE_HEAD, h, f0, f1, paint);
    box_m(verts, indices, b, -gx, gx, s - 0.03, s + 0.03, f0, f1, paint);
    box_m(verts, indices, b, -gx, gx, zt - 0.5 * CASE_TRANSOM, zt + 0.5 * CASE_TRANSOM, f0, f1, paint);
    // The sashes: above the transom and below it, a leaf each side of the meeting.
    let z0 = -(g + 0.025);
    let z1 = -(g - 0.02);
    let c = 0.5 * CASE_COVER;
    box_m(verts, indices, b, -c, c, s + 0.03, h - CASE_HEAD, -(g + 0.03), -(g - 0.025), paint);
    for part in 2 {
        let y0 = if part == 0 { zt + 0.5 * CASE_TRANSOM } else { s + 0.03 };
        let y1 = if part == 0 { h - CASE_HEAD } else { zt - 0.5 * CASE_TRANSOM };
        let rail_low = if part == 0 { CASE_RAIL } else { CASE_RAIL_LOW };
        let across = if part == 0 { UPPER_ACROSS } else { LOWER_ACROSS };
        let up = if part == 0 { UPPER_UP } else { LOWER_UP };
        for side in SIDES {
            // The leaf from its outer edge (at the frame) to its meeting edge.
            let outer = side * gx;
            let meet = side * c;
            let lo = min(outer, meet);
            let hi = max(outer, meet);
            let ax0 = if side < 0.0 { lo + CASE_STILE } else { lo + CASE_MEET };
            let ax1 = if side < 0.0 { hi - CASE_MEET } else { hi - CASE_STILE };
            box_m(verts, indices, b, lo, ax0, y0, y1, z0, z1, paint);
            box_m(verts, indices, b, ax1, hi, y0, y1, z0, z1, paint);
            box_m(verts, indices, b, ax0, ax1, y0, y0 + rail_low, z0, z1, paint);
            box_m(verts, indices, b, ax0, ax1, y1 - CASE_RAIL, y1, z0, z1, paint);
            let ay0 = y0 + rail_low;
            let ay1 = y1 - CASE_RAIL;
            let pw = (ax1 - ax0 - (across - 1) * CASE_BAR) / across;
            let ph = (ay1 - ay0 - (up - 1) * CASE_BAR) / up;
            for i in 1..across {
                let x = ax0 + i * (pw + CASE_BAR);
                box_m(verts, indices, b, x - CASE_BAR, x, ay0, ay1, -(g + 0.021), -(g - 0.015), paint);
            }
            for j in 1..up {
                let y = ay0 + j * (ph + CASE_BAR);
                box_m(verts, indices, b, ax0, ax1, y - CASE_BAR, y, -(g + 0.021), -(g - 0.015), paint);
            }
        }
    }
    let gz = -(g + 0.018);
    quad_m(glass, glass_indices, b, [float3 { -gx, s + 0.03, gz }, float3 { gx, s + 0.03, gz }, float3 { gx, h - CASE_HEAD, gz },
                                     float3 { -gx, h - CASE_HEAD, gz }], surfaces::MAT_GLASS);
}

// Panelled painted wood (a door's leaf, a shutter's face) on b's plane from x0 to x1
// (world units) and y0 to y1 (metres): stiles `stile` metres wide, rails between the
// panels in `rows` (metres up from y0's floor, as y0 and y1), the panels raised.
fn painted(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, x0: f32, x1: f32, y0: f32, y1: f32,
           stile: f32, rows: float2[], seed: i64&) {
    let k = m();
    let first = verts.len;
    let st = stile * k;
    seed++;
    let left = surfaces::piece_map(seed, true, x0, y0 * k, st, (y1 - y0) * k, true);
    surfaces::board(verts, indices, b, x0, x0 + st, y0 * k, y1 * k, true, seed);
    seed++;
    let right = surfaces::piece_map(seed, true, x1 - st, y0 * k, st, (y1 - y0) * k, true);
    surfaces::board(verts, indices, b, x1 - st, x1, y0 * k, y1 * k, true, seed);
    var below = y0;
    var maps: surfaces::Map[..8] = [];
    for r in rows {
        seed++;
        maps.push(surfaces::piece_map(seed, false, x0 + st, below * k, (r.x - below) * k, x1 - x0 - 2.0 * st, true));
        surfaces::board(verts, indices, b, x0 + st, x1 - st, below * k, r.x * k, false, seed);
        below = r.y;
    }
    seed++;
    maps.push(surfaces::piece_map(seed, false, x0 + st, below * k, (y1 - below) * k, x1 - x0 - 2.0 * st, true));
    surfaces::board(verts, indices, b, x0 + st, x1 - st, below * k, y1 * k, false, seed);
    for r, i in rows {
        seed++;
        surfaces::panel(verts, indices, b, x0 + st, x1 - st, r.x * k, r.y * k, seed, maps[i], maps[i + 1], left, right);
    }
    for i in first..verts.len {
        let v .= verts[i];
        v.mat = surfaces::MAT_PAINT + 0.3 * (v.mat - floor(v.mat));
    }
}

// The threshold's oak: past every other piece's own tone (surfaces' 0.9 * hash), which
// ROOM_FRAG shades paler and smoother.
let THRESHOLD_OWN: f32 = 0.95;

// The doors' leaves (part 2 of build/notes/shutters/, 2026-11-21): their face DOOR_FACE
// behind the wall's, in the frame's rebate on the room's side they open to, DOOR_LEAF
// thick, a DOOR_JOINT round each and between the pair; the right leaf's meeting bead
// (DOOR_BEAD, across and proud); three brass knuckle hinges a leaf on the outer jambs at
// DOOR_HINGES, their barrels DOOR_KNUCKLE round and twice DOOR_KNUCKLE_HALF long, the axis
// 7 mm before the face; the right leaf's lever on a long escutcheon, DOOR_LEVER from the
// meeting at the lock rail's height.
let DOOR_FACE:  f32 = 0.015;
let DOOR_LEAF:  f32 = 0.04;
let DOOR_JOINT: f32 = 0.003;
let DOOR_BEAD = float2 { 0.028, 0.008 };
let DOOR_HINGES:       f32[3] = [0.30, 1.35, 2.40];
let DOOR_KNUCKLE:      f32    = 0.007;
let DOOR_KNUCKLE_HALF: f32    = 0.06;
let DOOR_LEVER = float2 { 0.06, 1.05 };

// A door in wall b of `thick` metres (b's s at its middle): its lining through the wall's
// face to the leaves' back, the rebate's stop behind the joints, the oak threshold, the two
// closed leaves with three panels each (door 1) and their edges, the meeting bead, the
// hinges and the lever, the architrave round it on its plinth blocks.
fn door(verts: mesh::Vertex[>..]&, indices: u32[>..]&, wb: surfaces::Builder, o: Opening, thick: f32, seed: i64&) {
    let b = moved(wb, o.mid * m(), 0.0);
    let paint = if paint_quiet { paint_mat(0.5, false, false) } else { surfaces::MAT_PAINT };
    let w = 0.5 * o.width;
    let h = o.height;
    let back = DOOR_FACE + DOOR_LEAF;
    for sx in SIDES {
        quad_m(verts, indices, b, [float3 { sx * w, 0.0, 0.0 }, float3 { sx * w, 0.0, -back }, float3 { sx * w, h, -back },
                                   float3 { sx * w, h, 0.0 }], paint, float3 { -sx, 0.0, 0.0 }, 0.85);
    }
    quad_m(verts, indices, b, [float3 { -w, h, 0.0 }, float3 { w, h, 0.0 }, float3 { w, h, -back }, float3 { -w, h, -back }],
           paint, float3 { 0.0, -1.0, 0.0 }, 0.85);
    quad_m(verts, indices, b, [float3 { -w, 0.0, -back }, float3 { w, 0.0, -back }, float3 { w, h, -back }, float3 { -w, h, -back }],
           paint, float3 { 0.0, 0.0, 1.0 }, 0.3);
    // The threshold, an oak board 2 cm proud of the floor through the wall, its grain along
    // it, its room side a rounded nose 3 cm out; its ends run under the plinth blocks.
    seed++;
    let sill: float3[7] = [float3 { 3.0, 0.0, 0.6 }, float3 { 3.0, 0.7, 0.8 }, float3 { 2.87, 1.3, 0.9 },
                           float3 { 2.5, 1.77, 1.0 }, float3 { 2.0, 2.0, 1.0 }, float3 { 1.0, 2.0, 1.0 },
                           float3 { -100.0 * thick, 2.0, 1.0 }];
    let first = verts.len;
    sweep(verts, indices, b, sill[..], 0.0, -w * m(), w * m(), 0.0, 0.0, surfaces::MAT_OAK, seed, cm_up());
    for i in first..verts.len { verts[i].mat = surfaces::MAT_OAK + THRESHOLD_OWN; }
    // The leaves, their stiles' face DOOR_FACE behind the wall's, a joint round each over
    // the threshold's 2 cm; their edges back to the rebate.
    let k = m();
    let j = DOOR_JOINT;
    let lb = moved(b, 0.0, -DOOR_FACE * k - surfaces::FRAME_Z);
    let rows: float2[3] = [float2 { 0.22, 0.98 }, float2 { 1.16, 2.08 }, float2 { 2.2, 2.58 }];
    let y0 = 0.02 + j;
    let y1 = h - j;
    let spans: float2[2] = [float2 { -w + j, -0.5 * j }, float2 { 0.5 * j, w - j }];
    for x in spans {
        if paint_quiet {
            painted_quiet(verts, indices, lb, x.x * k, x.y * k, y0, y1, 0.12, rows[..], DOOR_LEAF, EDGES, LEFT | RIGHT | TOP, false,
                          0.6, seed);
            continue;
        }
        painted(verts, indices, lb, x.x * k, x.y * k, y0, y1, 0.12, rows[..], seed);
        for e in 2 {
            let at = if e == 0 { x.x } else { x.y };
            quad_m(verts, indices, b, [float3 { at, y0, -DOOR_FACE }, float3 { at, y0, -back }, float3 { at, y1, -back },
                                       float3 { at, y1, -DOOR_FACE }], paint, float3 { if e == 0 { -1.0 } else { 1.0 }, 0.0, 0.0 }, 0.6);
        }
        quad_m(verts, indices, b, [float3 { x.x, y1, -DOOR_FACE }, float3 { x.y, y1, -DOOR_FACE }, float3 { x.y, y1, -back },
                                   float3 { x.x, y1, -back }], paint, float3 { 0.0, 1.0, 0.0 }, 0.6);
    }
    // The meeting bead on the right leaf, a flattened half round over the joint.
    var bead: float2[7] = [float2_0; 7];
    for i in 7 {
        let t: f32 = PI * i / 6.0;
        bead[i] = float2 { -0.5 * DOOR_BEAD.x * cos(t), DOOR_BEAD.y * sin(t) };
    }
    upright_sweep(verts, indices, b, bead[..], 0.0, -DOOR_FACE, y0, y1, paint);
    // The hinges on the outer jambs, the lever and its escutcheon on the right leaf.
    for sx in SIDES {
        for y in DOOR_HINGES {
            knuckle(verts, indices, b, float3 { sx * (w - 0.5 * j), y, -DOOR_FACE + 0.007 }, DOOR_KNUCKLE, DOOR_KNUCKLE_HALF, 8, true);
        }
    }
    // The right leaf seen from the room is b's -s (a wall's s runs leftward from inside).
    let brass = surfaces::MAT_BRASS;
    let lx = -DOOR_LEVER.x;
    let ly = DOOR_LEVER.y;
    let z0 = -DOOR_FACE;
    box_m(verts, indices, b, lx - 0.0175, lx + 0.0175, ly - 0.15, ly + 0.07, z0, z0 + 0.003, brass);
    let collar: float3[2] = [float3 { lx, ly, z0 + 0.003 }, float3 { lx, ly, z0 + 0.012 }];
    tube(verts, indices, b, collar[..], 0.011, 8, false, brass);
    disc(verts, indices, b, float3 { lx, ly, z0 + 0.012 }, 0.011, 8, brass);
    let lever: float3[3] = [float3 { lx, ly, z0 + 0.012 }, float3 { lx, ly, z0 + 0.05 }, float3 { lx - 0.11, ly - 0.004, z0 + 0.056 }];
    tube(verts, indices, b, lever[..], 0.0065, 8, false, brass);
    ball(verts, indices, b, float3 { lx - 0.11, ly - 0.004, z0 + 0.056 }, 0.0085, brass);
    // The architrave up each side from its plinth block and over the head, mitred.
    var prof: float2[7] = [float2_0; 7];
    for q, i in ARCHITRAVE_A { prof[i] = float2 { q.x / 100.0, q.y / 100.0 }; }
    if paint_quiet {
        // Their seeds apart from the shell's, which the books go on with.
        architrave_quiet(verts, indices, b, prof[..], float2 { -w, PLINTH_BLOCK }, float2 { -w, h }, float2 { -1.0, 0.0 }, 0.0, 1.0,
                         7919 * seed + 1);
        architrave_quiet(verts, indices, b, prof[..], float2 { w, PLINTH_BLOCK }, float2 { w, h }, float2 { 1.0, 0.0 }, 0.0, 1.0,
                         7919 * seed + 2);
        architrave_quiet(verts, indices, b, prof[..], float2 { -w, h }, float2 { w, h }, float2 { 0.0, 1.0 }, 1.0, 1.0, 7919 * seed + 3);
    } else {
        architrave(verts, indices, b, prof[..], float2 { -w, PLINTH_BLOCK }, float2 { -w, h }, float2 { -1.0, 0.0 }, 0.0, 1.0);
        architrave(verts, indices, b, prof[..], float2 { w, PLINTH_BLOCK }, float2 { w, h }, float2 { 1.0, 0.0 }, 0.0, 1.0);
        architrave(verts, indices, b, prof[..], float2 { -w, h }, float2 { w, h }, float2 { 0.0, 1.0 }, 1.0, 1.0);
    }
    // The plinth blocks the architrave stands on, a little wider and deeper than it, over
    // the wainscot's skirting where it stops.
    for sx in SIDES {
        let a = sx * (w - 0.01);
        let c = sx * (w + ARCHITRAVE + BLOCK_PAST);
        if paint_quiet {
            paint_box(verts, indices, b, min(a, c), max(a, c), 0.0, PLINTH_BLOCK, 0.0, BLOCK_DEEP,
                      Piece { round: LEFT | RIGHT | TOP, sides: LEFT | RIGHT | TOP, recess: LEFT | RIGHT, seed: 7919 * seed + 5 + (if sx > 0.0 { 1 } else { 0 }), .. });
        } else { box_m(verts, indices, b, min(a, c), max(a, c), 0.0, PLINTH_BLOCK, 0.0, BLOCK_DEEP, paint); }
    }
}

// A profile (metres out from the opening's edge in the wall's plane, out from the wall)
// swept from p0 to p1 (s, y of b, metres), `side` the way out from the opening; each end
// mitred where it turns a corner (e 1: the point a metres out runs a metres farther).
fn architrave(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, prof: float2[], p0: float2, p1: float2,
              side: float2, e0: f32, e1: f32) {
    let dir = normalize(p1 - p0);
    for k in 1..prof.len {
        let a = prof[k - 1];
        let c = prof[k];
        let sa = p0 + side * a.x - dir * (e0 * a.x);
        let ea = p1 + side * a.x + dir * (e1 * a.x);
        let sc = p0 + side * c.x - dir * (e0 * c.x);
        let ec = p1 + side * c.x + dir * (e1 * c.x);
        let n = float3 { side.x * -(c.y - a.y), side.y * -(c.y - a.y), c.x - a.x };
        quad_m(verts, indices, b, [float3 { sa.x, sa.y, a.y }, float3 { ea.x, ea.y, a.y }, float3 { ec.x, ec.y, c.y },
                                   float3 { sc.x, sc.y, c.y }], surfaces::MAT_PAINT + 0.1, n);
    }
}

// The middle of wall `wall`'s door along it, or the wall's middle without one.
fn door_mid(s: Shell, wall: i64) -> f32 {
    for k in s.count {
        let o = s.openings[k];
        if o.kind == DOOR && o.wall == wall { return o.mid; }
    }
    return 0.5 * length_of(s.walls[wall]);
}

fn floor_diagonal(s: Shell) -> float2, float2 {
    return room_of(s, float2 { 9.0, 7.0 }), room_of(s, float2 { 0.0, 0.0 });
}

// The shell's mesh into verts and indices, its glass and lace into their own: the floor,
// each wall's wallpaper, wainscot, openings (the bookcases with their books unless
// `books_on` is false) and cornice, and the ceiling.
fn build(verts: mesh::Vertex[>..]&, indices: u32[>..]&, glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&, s: Shell,
         books_on: bool = true) {
    let k = m();
    let low, high = floor_diagonal(s);
    surfaces::floor_quad(verts, indices, float2 { min(low.x, high.x), min(low.y, high.y) },
                         float2 { max(low.x, high.x), max(low.y, high.y) });
    var seed: i64         = 1000;
    var uses: books::Uses = [0; books::MAX_SETS];
    for w, wi in s.walls {
        let b = wall_builder(s, w);
        let length = length_of(w);
        let ops = openings_on(s, wi);
        wallpaper(verts, indices, s, b, length, WAINSCOT_TOP, ops);
        // The wainscot's runs between the openings.
        var at: f32 = 0.0;
        var at_end = 0;
        var edge: f32 = 0.0;
        for o in ops {
            if o.kind == WINDOW {
                let a = o.mid - 0.5 * o.width;
                if a > at + 0.01 { wainscot_run(verts, indices, b, at * k, a * k, RUN_WALL, at_end, 1, seed); }
                wainscot_run(verts, indices, b, a * k, (o.mid + 0.5 * o.width) * k, RUN_SILL, 0, 0, seed);
                window(verts, indices, glass, glass_indices, b, o, seed);
                at = o.mid + 0.5 * o.width;
                at_end = 1;
            } else {
                // A door or a bookcase: the wainscot stopped square against the architrave's
                // side (its skirting under the plinth block) or returned into a case's
                // ledge, or where too little wall is left for a panel, a bare strip.
                let gap = if o.kind == BOOKCASE { 0.002 } else { 0.0 };
                let a = o.mid - reach(o) - gap;
                if a > at + 0.25 || (a > at + 0.01 && at_end != 2) {
                    wainscot_run(verts, indices, b, at * k, a * k, RUN_WALL, at_end, 2, seed);
                } else if o.mid - reach(o) > edge + 0.005 { bare_strip(verts, indices, b, edge, o.mid - reach(o), seed); }
                if o.kind == DOOR { door(verts, indices, b, o, w.thick, seed); }
                else { bookcase(verts, indices, b, o, door_mid(s, wi), books_on, uses, seed); }
                at = o.mid + reach(o) + gap;
                at_end = 2;
            }
            edge = o.mid + reach(o);
        }
        if length > at + 0.01 { wainscot_run(verts, indices, b, at * k, length * k, RUN_WALL, at_end, 0, seed); }
        // The cornice, mitred into the corners at both ends.
        var flipped: float3[31] = [float3_0; 31];
        for q, i in CORNICE_B { flipped[i] = float3 { q.x, (s.ceiling * 100.0 - q.y), q.z }; }
        sweep(verts, indices, b, flipped[..], 0.0, 0.0, length * k, 1.0, -1.0, surfaces::MAT_PLASTER + 0.5, seed, cm_up());
    }
    // The ceiling, one plaster field over the room, facing down.
    let y = s.ceiling;
    let c0 = float2 { min(low.x, high.x), min(low.y, high.y) };
    let c1 = float2 { max(low.x, high.x), max(low.y, high.y) };
    let base = verts.len as u32;
    let corners: float2[4] = [c0, float2 { c1.x, c0.y }, c1, float2 { c0.x, c1.y }];
    for c in corners {
        verts.push(mesh::Vertex { float3 { c.x, surfaces::FLOOR_Y + y * k, c.y }, float3 { 0.0, -1.0, 0.0 }, c, 1.0,
                                  surfaces::MAT_PLASTER });
    }
    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
}
