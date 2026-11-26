// The painted joinery's quiet paint (build/notes/paint-research/, its "quiet" variant): old
// oil paint on pine, a few coats thick. Its arrises rounded by the coats (a fillet strip
// whose normals turn from one face's to the other's), the quirks a little shallower, each
// piece tilted a fraction of a degree and each panel cupped, so the pieces catch the
// light a little differently. Its vertices tell ROOM_FRAG's ROOM_PAINT where the joints'
// hairlines and the recesses' dirt are (their uv) and the piece's grain, tone and whether
// it is a window's (its material's fraction, paint_mat).
namespace room_shell;
import std;
import vec;
import math;

// The paint as made (quiet), or as before it (the light tuner's --paint old); its fillets,
// and its pieces' tilt and the panels' cup, each switched alone (--paint-off).
var paint_quiet = true;
var paint_fillets = true;
var paint_tilt = true;

// The paint's radius on an arris (metres): a door's coats, a window's thinner.
let FILLET_DOOR:   f32 = 0.0012;
let FILLET_WINDOW: f32 = 0.0009;
// A piece's tilt each way (radians, a standard deviation: 0.2°), and a panel's sag at its
// middle (metres) across its width.
let PAINT_TILT: f32 = 0.0035;
let PANEL_SAG:  f32 = 0.0008;
// A joint or a recess farther than any line (metres): none near.
let NO_LINE: f32 = 1.0;

// A painted piece's material: the paint's kind, its fraction a tenth of its own tone (0 to
// 1), a tenth more with its grain along the wall (else up), a fifth more on a window, a
// half more where the screen's occlusion stays off (the shutters' fronts).
fn paint_mat(tone: f32, along_wall: bool, window: bool, screen_ao: bool) -> f32 {
    return surfaces::MAT_PAINT + 0.099 * clamp(tone, 0.0, 1.0) + (if along_wall { 0.1 } else { 0.0 })
           + (if window { 0.2 } else { 0.0 }) + (if screen_ao { 0.0 } else { 0.5 });
}

// Whether a vertex's material is the quiet paint's (which reads its uv as lines' distances).
fn quiet_paint(mat: f32) -> bool {
    guard paint_quiet else { return false; }
    let kind = floor(mat + 0.001);
    return kind == surfaces::MAT_PAINT;
}

fn fillet(window: bool) -> f32 {
    guard paint_fillets else { return 0.0; }
    return if window { FILLET_WINDOW } else { FILLET_DOOR };
}

// A piece's tilt, a small turn about b's s and y axes (radians), from its seed: about normal,
// as the sum of two uniforms.
fn tilt_of(seed: i64) -> float2 {
    guard paint_tilt else { return float2_0; }
    return float2 { PAINT_TILT * 2.45 * (surfaces::hash(seed, 21) + surfaces::hash(seed, 22) - 1.0),
                    PAINT_TILT * 2.45 * (surfaces::hash(seed, 23) + surfaces::hash(seed, 24) - 1.0) };
}

// n turned by the small tilt t.
fn tilted(n: float3, t: float2) -> float3 { normalize(n + cross(float3 { t.x, t.y, 0.0 }, n)) }

// A quad of corners p (metres in b's frame) with a normal each (b's frame).
fn paint_quad(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, p: float3[4], n: float3[4],
              uv: float2[4], ao: f32, mat: f32) {
    let k = m();
    let base = verts.len as u32;
    for i in 4 {
        verts.push(mesh::Vertex { surfaces::world(b, p[i].x * k, p[i].y * k, p[i].z * k), surfaces::world_normal(b, n[i]), uv[i], ao, mat });
    }
    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
}

// The edges and faces of a box: its front face's left, right, bottom and top (b's -s, +s,
// down, up).
let LEFT = 1;
let RIGHT = 2;
let BOTTOM = 4;
let TOP = 8;
let EDGES = 15;

// A painted box's parts: its front edges rounded, its side faces drawn, the front's ends a
// joint's hairline runs along (where another piece meets it), the side faces with a recess
// `foot` metres out from their back (where dirt gathers), the grain along s or up, a
// window's or a door's, the side faces' occlusion, its seed (tone and tilt), and whether the
// screen's occlusion falls on it.
struct Piece {
    round:     i64  = 0,
    sides:     i64  = 0,
    joints:    i64  = 0,
    recess:    i64  = 0,
    foot:      f32  = 0.0,
    along:     bool = false,
    window:    bool = false,
    ao:        f32  = 1.0,
    seed:      i64  = 0,
    screen_ao: bool = true,
}

// The distance along a piece from a0 to a1 at a to the nearer of its ends that is a joint
// (lo, hi).
fn joint_at(a: f32, a0: f32, a1: f32, lo: bool, hi: bool) -> f32 {
    let d0 = if lo { a - a0 } else { NO_LINE };
    let d1 = if hi { a1 - a } else { NO_LINE };
    return min(d0, d1);
}

// A side face from its two front corners to its two back ones (q), its normal n, a recess
// foot metres out from the back (or none); cut at the foot so the dirt's distance is exact.
fn side_face(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, q: float3[4], n: float3, recess: bool,
             foot: f32, ao: f32, mat: f32) {
    let zf = q[0].z;
    let zb = q[2].z;
    let at = zb + foot;
    let ns: float3[4] = [n, n, n, n];
    if !recess {
        paint_quad(verts, indices, b, q, ns, [float2 { NO_LINE, NO_LINE }; 4], ao, mat);
        return;
    }
    let du = abs(zf - at);
    let db = abs(zb - at);
    if at > zb + 0.000001 && at < zf - 0.000001 {
        let t = (at - zb) / (zf - zb);
        let m0 = lerp(q[3], q[0], t);
        let m1 = lerp(q[2], q[1], t);
        paint_quad(verts, indices, b, [q[0], q[1], m1, m0], ns,
                   [float2 { NO_LINE, du }, float2 { NO_LINE, du }, float2 { NO_LINE, 0.0 }, float2 { NO_LINE, 0.0 }], ao, mat);
        paint_quad(verts, indices, b, [m0, m1, q[2], q[3]], ns,
                   [float2 { NO_LINE, 0.0 }, float2 { NO_LINE, 0.0 }, float2 { NO_LINE, db }, float2 { NO_LINE, db }], ao, mat);
        return;
    }
    paint_quad(verts, indices, b, q, ns, [float2 { NO_LINE, du }, float2 { NO_LINE, du }, float2 { NO_LINE, db }, float2 { NO_LINE, db }],
               ao, mat);
}

// A painted box over x0..x1, y0..y1, z0..z1 (metres in b's frame, its back toward -z not
// drawn): its front face in two halves along the grain (so a joint's distance at both ends
// is exact), the fillets of p.round mitred where two meet, the side faces of p.sides, all
// tilted a little.
fn paint_box(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, x0: f32, x1: f32, y0: f32, y1: f32,
             z0: f32, z1: f32, p: Piece) {
    let r = fillet(p.window);
    let rl = if (p.round & LEFT) != 0 { r } else { 0.0 };
    let rr = if (p.round & RIGHT) != 0 { r } else { 0.0 };
    let rb = if (p.round & BOTTOM) != 0 { r } else { 0.0 };
    let rt = if (p.round & TOP) != 0 { r } else { 0.0 };
    let t = tilt_of(p.seed);
    let mat = paint_mat(surfaces::hash(p.seed, 25), p.along, p.window, p.screen_ao);
    let nf = tilted(float3 { 0.0, 0.0, 1.0 }, t);
    let nl = tilted(float3 { -1.0, 0.0, 0.0 }, t);
    let nr = tilted(float3 { 1.0, 0.0, 0.0 }, t);
    let nb = tilted(float3 { 0.0, -1.0, 0.0 }, t);
    let nt = tilted(float3 { 0.0, 1.0, 0.0 }, t);
    // The joint's distance at a point of the front: along s for a piece along the wall.
    let lo = if p.along { (p.joints & LEFT) != 0 } else { (p.joints & BOTTOM) != 0 };
    let hi = if p.along { (p.joints & RIGHT) != 0 } else { (p.joints & TOP) != 0 };
    let a0 = if p.along { x0 } else { y0 };
    let a1 = if p.along { x1 } else { y1 };
    // The front, in two halves along the grain.
    let fx0 = x0 + rl;
    let fx1 = x1 - rr;
    let fy0 = y0 + rb;
    let fy1 = y1 - rt;
    let nfs: float3[4] = [nf, nf, nf, nf];
    for h in 2 {
        let lo_t: f32 = 0.5 * h;
        let hi_t: f32 = 0.5 * (h + 1);
        var q: float3[4] = [float3_0; 4];
        if p.along {
            let xa = lerp(fx0, fx1, lo_t);
            let xb = lerp(fx0, fx1, hi_t);
            q = [float3 { xa, fy0, z1 }, float3 { xb, fy0, z1 }, float3 { xb, fy1, z1 }, float3 { xa, fy1, z1 }];
        } else {
            let ya = lerp(fy0, fy1, lo_t);
            let yb = lerp(fy0, fy1, hi_t);
            q = [float3 { fx0, ya, z1 }, float3 { fx1, ya, z1 }, float3 { fx1, yb, z1 }, float3 { fx0, yb, z1 }];
        }
        var uv: float2[4] = [float2_0; 4];
        for i in 4 { uv[i] = float2 { joint_at(if p.along { q[i].x } else { q[i].y }, a0, a1, lo, hi), NO_LINE }; }
        paint_quad(verts, indices, b, q, nfs, uv, 1.0, mat);
    }
    // The fillets: from the front's edge (front normal) to the side's (its normal), each in
    // two halves along its length, mitred into the next where both are rounded.
    for e in 4 {
        let bit = 1 << e;
        guard (p.round & bit) != 0 && r > 0.0 else { continue; }
        // Front line f0..f1 and back line g0..g1, and the side's normal.
        var f0 = float3_0;
        var f1 = float3_0;
        var g0 = float3_0;
        var g1 = float3_0;
        var ns = nf;
        if bit == LEFT {
            f0 = float3 { x0 + r, y0 + rb, z1 };
            f1 = float3 { x0 + r, y1 - rt, z1 };
            g0 = float3 { x0, y0, z1 - r };
            g1 = float3 { x0, y1, z1 - r };
            ns = nl;
        } else if bit == RIGHT {
            f0 = float3 { x1 - r, y0 + rb, z1 };
            f1 = float3 { x1 - r, y1 - rt, z1 };
            g0 = float3 { x1, y0, z1 - r };
            g1 = float3 { x1, y1, z1 - r };
            ns = nr;
        } else if bit == BOTTOM {
            f0 = float3 { x0 + rl, y0 + r, z1 };
            f1 = float3 { x1 - rr, y0 + r, z1 };
            g0 = float3 { x0, y0, z1 - r };
            g1 = float3 { x1, y0, z1 - r };
            ns = nb;
        } else {
            f0 = float3 { x0 + rl, y1 - r, z1 };
            f1 = float3 { x1 - rr, y1 - r, z1 };
            g0 = float3 { x0, y1, z1 - r };
            g1 = float3 { x1, y1, z1 - r };
            ns = nt;
        }
        // In two halves along the grain, as the front's edge beside it; across it whole.
        let along_y = bit == LEFT || bit == RIGHT;
        let along_grain = along_y != p.along;
        let step: f32 = if along_grain { 0.5 } else { 1.0 };
        for h in (if along_grain { 2 } else { 1 }) {
            let ta: f32       = step * h;
            let tb: f32       = step * (h + 1);
            let q:  float3[4] = [lerp(f0, f1, ta), lerp(f0, f1, tb), lerp(g0, g1, tb), lerp(g0, g1, ta)];
            var uv: float2[4] = [float2_0; 4];
            for i in 4 { uv[i] = float2 { joint_at(if p.along { q[i].x } else { q[i].y }, a0, a1, lo, hi), NO_LINE }; }
            paint_quad(verts, indices, b, q, [nf, nf, ns, ns], uv, 1.0, mat);
        }
        // Its ends where no rounded edge meets it: the fillet's cut closed out to the box's
        // corner, facing along the edge into the cut. Open, the piece beside it (its end not
        // drawn) shows the glass through, a dot under a pixel.
        let ends: bool[2]   = [(p.round & (if along_y { BOTTOM } else { LEFT })) == 0, (p.round & (if along_y { TOP } else { RIGHT })) == 0];
        let into: float3[2] = [if along_y { nt } else { nr }, if along_y { nb } else { nl }];
        for k in 2 {
            guard ends[k] else { continue; }
            let f = if k == 0 { f0 } else { f1 };
            let g = if k == 0 { g0 } else { g1 };
            let q: float3[4] = [f, g, float3 { g.x, g.y, f.z }, f];
            var uv: float2[4] = [float2_0; 4];
            for i in 4 { uv[i] = float2 { joint_at(if p.along { q[i].x } else { q[i].y }, a0, a1, lo, hi), NO_LINE }; }
            paint_quad(verts, indices, b, q, [into[k]; 4], uv, 1.0, mat);
        }
    }
    // The side faces, from the fillet's back line (or the front's edge) to the back; along
    // the grain in two halves, as the front's edge and the fillet beside them.
    if (p.sides & LEFT) != 0 {
        side_halves(verts, indices, b, [float3 { x0, y0, z1 - rl }, float3 { x0, y1, z1 - rl }, float3 { x0, y1, z0 }, float3 { x0, y0, z0 }],
                    nl, (p.recess & LEFT) != 0, p.foot, p.ao, mat, !p.along);
    }
    if (p.sides & RIGHT) != 0 {
        side_halves(verts, indices, b, [float3 { x1, y0, z1 - rr }, float3 { x1, y1, z1 - rr }, float3 { x1, y1, z0 }, float3 { x1, y0, z0 }],
                    nr, (p.recess & RIGHT) != 0, p.foot, p.ao, mat, !p.along);
    }
    if (p.sides & BOTTOM) != 0 {
        side_halves(verts, indices, b, [float3 { x0, y0, z1 - rb }, float3 { x1, y0, z1 - rb }, float3 { x1, y0, z0 }, float3 { x0, y0, z0 }],
                    nb, (p.recess & BOTTOM) != 0, p.foot, p.ao, mat, p.along);
    }
    if (p.sides & TOP) != 0 {
        side_halves(verts, indices, b, [float3 { x0, y1, z1 - rt }, float3 { x1, y1, z1 - rt }, float3 { x1, y1, z0 }, float3 { x0, y1, z0 }],
                    nt, (p.recess & TOP) != 0, p.foot, p.ao, mat, p.along);
    }
}

// A side face (as side_face) whole, or in two halves along its front edge: a vertex of the
// front's or the fillet's on its edge and none of its own there is a T-junction, whose crack
// shows the glass through as a dot.
fn side_halves(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, q: float3[4], n: float3, recess: bool,
               foot: f32, ao: f32, mat: f32, halves: bool) {
    if !halves {
        side_face(verts, indices, b, q, n, recess, foot, ao, mat);
        return;
    }
    let mf = lerp(q[0], q[1], 0.5);
    let mb = lerp(q[3], q[2], 0.5);
    side_face(verts, indices, b, [q[0], mf, mb, q[3]], n, recess, foot, ao, mat);
    side_face(verts, indices, b, [mf, q[1], q[2], mb], n, recess, foot, ao, mat);
}

// The quiet panel's ring (world units, as surfaces::PANEL_IN and PANEL_Z): the stuck
// moulding, the quirk 40 % shallower than before (filled by the coats), the bevel (a point
// 8 mm up from its foot and 8 mm short of its top, so the dirt's distance stays exact over
// it), the riser, and the field's arris rounded in three steps; the quirk and the riser's
// foot gather dirt. Without fillets, the ring as before (surfaces::PANEL_IN).
let QUIRK_Z:  f32 = 0.26;
let BEVEL_IN: f32 = 0.0262;     // 8 mm

struct Ring { at: float2[..16], ao: f32[..16], dirt: f32[..16] }

fn quiet_ring(window: bool) -> Ring {
    var g = Ring { [], [], [] };
    let r = fillet(window) * surfaces::METRE;
    let quirk = if r > 0.0 { QUIRK_Z } else { surfaces::PANEL_Z[4] };
    let ins: f32[5] = [0.0, 0.1, 0.22, 0.32, 0.34];
    let zs:  f32[5] = [0.75, 0.71, 0.56, 0.32, quirk];
    let aos: f32[5] = [1.0, 0.97, 0.85, 0.62, 0.55];
    for i in 5 {
        g.at.push(float2 { ins[i], zs[i] });
        g.ao.push(aos[i]);
        g.dirt.push(0.0);
    }
    g.dirt[4] = 1.0;
    // The bevel to the riser's foot.
    let foot = float2 { 1.5, 0.48 };
    let start = g.at[4];
    let len = length(foot - start);
    g.at.push(lerp(start, foot, BEVEL_IN / len));
    g.ao.push(0.93);
    g.dirt.push(0.0);
    g.at.push(lerp(start, foot, 1.0 - BEVEL_IN / len));
    g.ao.push(0.93);
    g.dirt.push(0.0);
    g.at.push(foot);
    g.ao.push(0.93);
    g.dirt.push(1.0);
    // The riser and the field's arris.
    if r > 0.0 {
        let c = float2 { 1.5, 0.56 };
        let a = float2 { 1.5, 0.56 - r };
        let e = float2 { 1.5 + r, 0.56 };
        for j in 4 {
            let t: f32 = j / 3.0;
            g.at.push(a * ((1.0 - t) * (1.0 - t)) + c * (2.0 * t * (1.0 - t)) + e * (t * t));
            g.ao.push(0.97 + 0.01 * j);
            g.dirt.push(0.0);
        }
    } else {
        g.at.push(float2 { 1.5, 0.56 });
        g.ao.push(0.97);
        g.dirt.push(0.0);
    }
    return g;
}

// The distance (metres) along a ring from each point to the nearest that gathers dirt.
fn dirt_distances(g: Ring&) -> f32[..16] {
    var arc: f32[..16] = [0.0];
    for i in 1..g.at.len { arc.push(arc[i - 1] + length(g.at[i] - g.at[i - 1]) / surfaces::METRE); }
    var d: f32[..16] = [];
    for i in g.at.len {
        var best = NO_LINE;
        for j in g.at.len {
            if g.dirt[j] > 0.5 { best = min(best, abs(arc[i] - arc[j])); }
        }
        d.push(best);
    }
    return d;
}

// A raised and fielded panel in the frame's opening x0..x1, y0..y1 (world units, on b's
// plane at surfaces::FRAME_Z), with the quiet ring, its occlusion scaled as the wainscot's
// (surfaces::panel_ao_scale), tilted, its field cupped across its width.
fn paint_panel(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, x0: f32, x1: f32, y0: f32, y1: f32,
               window: bool, screen_ao: bool, seed: i64) {
    var g = quiet_ring(window);
    let dirt = dirt_distances(g);
    let t = tilt_of(seed);
    let tone = surfaces::hash(seed, 25);
    let up = paint_mat(tone, false, window, screen_ao);
    let across = paint_mat(tone, true, window, screen_ao);
    let rings = g.at.len;
    let last = rings - 1;
    let outs: float3[4] = [float3 { 0.0, -1.0, 0.0 }, float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, 1.0, 0.0 }, float3 { -1.0, 0.0, 0.0 }];
    var flat: float3[4][16] = [[float3_0; 4]; 16];
    for k in last {
        let d = g.at[k + 1] - g.at[k];
        for o, i in outs {
            if length(d) > 0.000001 { flat[k][i] = normalize(float3 { o.x * d.y, o.y * d.y, d.x }); }
        }
    }
    for i in 4 { flat[last][i] = float3 { 0.0, 0.0, 1.0 }; }
    let k_m = 1.0 / surfaces::METRE;
    for k in last {
        let a = g.at[k].x;
        let c = g.at[k + 1].x;
        let za = g.at[k].y;
        let zc = g.at[k + 1].y;
        let oa = 1.0 - surfaces::panel_ao_scale * (1.0 - g.ao[k]);
        let oc = 1.0 - surfaces::panel_ao_scale * (1.0 - g.ao[k + 1]);
        let sides: float3[4][4] = [
            [float3 { x0 + a, y0 + a, za }, float3 { x1 - a, y0 + a, za }, float3 { x1 - c, y0 + c, zc }, float3 { x0 + c, y0 + c, zc }],
            [float3 { x1 - a, y0 + a, za }, float3 { x1 - a, y1 - a, za }, float3 { x1 - c, y1 - c, zc }, float3 { x1 - c, y0 + c, zc }],
            [float3 { x1 - a, y1 - a, za }, float3 { x0 + a, y1 - a, za }, float3 { x0 + c, y1 - c, zc }, float3 { x1 - c, y1 - c, zc }],
            [float3 { x0 + a, y1 - a, za }, float3 { x0 + a, y0 + a, za }, float3 { x0 + c, y0 + c, zc }, float3 { x0 + c, y1 - c, zc }],
        ];
        for q, i in sides {
            let n = flat[k][i];
            guard length_sq(n) > 0.0 else { continue; }
            let next = if k + 2 <= last && length_sq(flat[k + 1][i]) == 0.0 { flat[k + 2][i] } else { flat[k + 1][i] };
            let na = tilted(if k > 0 { surfaces::smooth_normal(n, flat[k - 1][i], surfaces::panel_crease) } else { n }, t);
            let nc = tilted(surfaces::smooth_normal(n, next, surfaces::panel_crease), t);
            // The moulding belongs to the rails above and below, their grain along the wall.
            let mat = if k < 4 && (i == 0 || i == 2) { across } else { up };
            let base = verts.len as u32;
            let ns: float3[4] = [na, na, nc, nc];
            let ao: f32[4]    = [oa, oa, oc, oc];
            let dd: f32[4]    = [dirt[k], dirt[k], dirt[k + 1], dirt[k + 1]];
            for j in 4 {
                verts.push(mesh::Vertex { surfaces::world(b, q[j].x, q[j].y, q[j].z), surfaces::world_normal(b, ns[j]),
                                          float2 { NO_LINE, dd[j] }, ao[j], mat });
            }
            indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
        }
    }
    // The field, cupped: its normals at the sides turned in toward the middle (or out, as
    // the panel was cut from the tree).
    let f = g.at[last].x;
    let z = g.at[last].y;
    let w = (x1 - x0 - 2.0 * f) * k_m;
    let way: f32 = if surfaces::hash(seed, 26) < 0.5 { 1.0 } else { -1.0 };
    let s = if paint_tilt && w > 0.0 { way * 4.0 * PANEL_SAG / w } else { 0.0 };
    let p: float3[4] = [float3 { x0 + f, y0 + f, z }, float3 { x1 - f, y0 + f, z }, float3 { x1 - f, y1 - f, z }, float3 { x0 + f, y1 - f, z }];
    let ns: float3[4] = [tilted(normalize(float3 { s, 0.0, 1.0 }), t), tilted(normalize(float3 { -s, 0.0, 1.0 }), t),
                         tilted(normalize(float3 { -s, 0.0, 1.0 }), t), tilted(normalize(float3 { s, 0.0, 1.0 }), t)];
    let base = verts.len as u32;
    for j in 4 {
        verts.push(mesh::Vertex { surfaces::world(b, p[j].x, p[j].y, p[j].z), surfaces::world_normal(b, ns[j]),
                                  float2 { NO_LINE, dirt[last] }, 1.0, up });
    }
    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
}

// Panelled painted wood (a door's leaf, a shutter's face) with the quiet paint, as painted:
// on b's plane from x0 to x1 (world units) and y0 to y1 (metres), stiles `stile` metres
// wide, rails between the panels in `rows`; the leaf `depth` metres thick behind its face,
// the edges in `round` rounded and those in `sides` drawn (the leaf's own edges); the
// rails' ends meeting the stiles at a joint; the screen's occlusion on it with `screen_ao`.
fn painted_quiet(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, x0: f32, x1: f32, y0: f32, y1: f32,
                 stile: f32, rows: float2[], depth: f32, round: i64, sides: i64, window: bool, ao: f32, screen_ao: bool,
                 seed: i64&) {
    let k = m();
    let a0 = x0 / k;
    let a1 = x1 / k;
    let z1 = surfaces::FRAME_Z / k;
    let z0 = z1 - depth;
    let ends = BOTTOM | TOP;
    seed++;
    paint_box(verts, indices, b, a0, a0 + stile, y0, y1, z0, z1,
              Piece { round: round & (LEFT | ends), sides: sides & (LEFT | ends), window: window, ao: ao, seed: seed, screen_ao: screen_ao, .. });
    seed++;
    paint_box(verts, indices, b, a1 - stile, a1, y0, y1, z0, z1,
              Piece { round: round & (RIGHT | ends), sides: sides & (RIGHT | ends), window: window, ao: ao, seed: seed, screen_ao: screen_ao, .. });
    var below = y0;
    for r, i in rows {
        seed++;
        let edge = if i == 0 { BOTTOM } else { 0 };
        paint_box(verts, indices, b, a0 + stile, a1 - stile, below, r.x, z0, z1,
                  Piece { round: round & edge, sides: sides & edge, joints: LEFT | RIGHT, along: true, window: window, ao: ao,
                          seed: seed, screen_ao: screen_ao, .. });
        below = r.y;
    }
    seed++;
    paint_box(verts, indices, b, a0 + stile, a1 - stile, below, y1, z0, z1,
              Piece { round: round & TOP, sides: sides & TOP, joints: LEFT | RIGHT, along: true, window: window, ao: ao, seed: seed, screen_ao: screen_ao, .. });
    for r in rows {
        seed++;
        paint_panel(verts, indices, b, x0 + stile * k, x1 - stile * k, r.x * k, r.y * k, window, screen_ao, seed);
    }
}

// A profile (metres, (out from the opening's edge, out from the wall)) with the corners
// flagged in `round` rounded by r: each a quadratic arc from r tan(θ/2) before the corner
// to as far after it, in three steps; its points that gather dirt carried over (`dirt`).
struct Profile2 { at: float2[..32], dirt: bool[..32] }
fn rounded_profile(prof: float2[7], round: bool[7], dirt: bool[7], r: f32) -> Profile2 {
    var out = Profile2 { [], [] };
    for p, i in prof {
        if r > 0.0 && round[i] && i > 0 && i + 1 < prof.len {
            let u = normalize(p - prof[i - 1]);
            let v = normalize(prof[i + 1] - p);
            let turn = acos(clamp(dot(u, v), -1.0, 1.0));
            let t = r * tan(0.5 * turn);
            let a = p - u * t;
            let e = p + v * t;
            for j in 4 {
                let s: f32 = j / 3.0;
                out.at.push(a * ((1.0 - s) * (1.0 - s)) + p * (2.0 * s * (1.0 - s)) + e * (s * s));
                out.dirt.push(false);
            }
        } else {
            out.at.push(p);
            out.dirt.push(dirt[i]);
        }
    }
    return out;
}

// The architrave with the quiet paint (as architrave): its convex arrises rounded, its
// normals smoothed where the profile turns gently (the fillets), dirt at its inner step and
// at its outer foot on the wall, each strip in two halves along it with a joint's hairline
// at both ends (the mitres, the plinth block), the piece tilted a little.
fn architrave_quiet(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, prof: float2[], p0: float2, p1: float2,
                    side: float2, e0: f32, e1: f32, seed: i64) {
    let round: bool[7] = [false, true, false, false, true, true, false];
    let dirt:  bool[7] = [false, false, false, true, false, false, true];
    var p7: float2[7] = [float2_0; 7];
    for q, i in prof { p7[i] = q; }
    let g = rounded_profile(p7, round, dirt, fillet(false));
    let n_pts = g.at.len;
    var arc: f32[..32] = [0.0];
    for i in 1..n_pts { arc.push(arc[i - 1] + length(g.at[i] - g.at[i - 1])); }
    var dd: f32[..32] = [];
    for i in n_pts {
        var best = NO_LINE;
        for j in n_pts {
            if g.dirt[j] { best = min(best, abs(arc[i] - arc[j])); }
        }
        dd.push(best);
    }
    // Each segment's normal (in the profile's plane: out along `side`, out of the wall), and
    // each point's, smoothed across a gentle turn.
    var flat: float2[..32] = [];
    for i in 1..n_pts {
        let d = g.at[i] - g.at[i - 1];
        flat.push(if length(d) > 0.000001 { normalize(float2 { -d.y, d.x }) } else { float2_0 });
    }
    let t = tilt_of(seed);
    let along_wall = abs(side.y) > 0.5;
    let mat = paint_mat(surfaces::hash(seed, 25), along_wall, false, true);
    let dir = normalize(p1 - p0);
    for k in 1..n_pts {
        let n = flat[k - 1];
        guard length_sq(n) > 0.0 else { continue; }
        let n3 = float3 { n.x, 0.0, n.y };
        let pa = if k > 1 { flat[k - 2] } else { n };
        let pc = if k + 1 < n_pts { flat[k] } else { n };
        let sa = surfaces::smooth_normal(n3, float3 { pa.x, 0.0, pa.y }, surfaces::panel_crease);
        let sc = surfaces::smooth_normal(n3, float3 { pc.x, 0.0, pc.y }, surfaces::panel_crease);
        let na = tilted(float3 { side.x * sa.x, side.y * sa.x, sa.z }, t);
        let nc = tilted(float3 { side.x * sc.x, side.y * sc.x, sc.z }, t);
        let a = g.at[k - 1];
        let c = g.at[k];
        let sa0 = p0 + side * a.x - dir * (e0 * a.x);
        let ea0 = p1 + side * a.x + dir * (e1 * a.x);
        let sc0 = p0 + side * c.x - dir * (e0 * c.x);
        let ec0 = p1 + side * c.x + dir * (e1 * c.x);
        let ma = lerp(sa0, ea0, 0.5);
        let mc = lerp(sc0, ec0, 0.5);
        let ha = 0.5 * length(ea0 - sa0);
        let hc = 0.5 * length(ec0 - sc0);
        let halves: float2[4][2] = [[sa0, ma, mc, sc0], [ma, ea0, ec0, mc]];
        let joints: f32[4][2]    = [[0.0, ha, hc, 0.0], [ha, 0.0, 0.0, hc]];
        for h in 2 {
            let q = halves[h];
            paint_quad(verts, indices, b, [float3 { q[0].x, q[0].y, a.y }, float3 { q[1].x, q[1].y, a.y }, float3 { q[2].x, q[2].y, c.y },
                                           float3 { q[3].x, q[3].y, c.y }], [na, na, nc, nc],
                       [float2 { joints[h][0], dd[k - 1] }, float2 { joints[h][1], dd[k - 1] }, float2 { joints[h][2], dd[k] },
                        float2 { joints[h][3], dd[k] }], 1.0, mat);
        }
    }
}

// A casement with the quiet paint (as casement, at the glass plane `g` metres into the wall):
// the blind frame's members rounded and dirty where they meet the sashes' face, the sashes'
// stiles, rails and bars rounded and dirty along the glass, their ends meeting at joints;
// only the faces that show. The bars across stand 0.2 mm behind those up, which they cross.
fn casement_quiet(verts: mesh::Vertex[>..]&, indices: u32[>..]&, glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&,
                  b: surfaces::Builder, o: Opening, g: f32, seed: i64&) {
    let w = 0.5 * o.width;
    let gx = 0.5 * o.glass.w - CASE_FRAME;
    let s = o.sill;
    let h = o.sill + o.height;
    let zt = s + (h - s) * 2.0 / 3.0;
    let f0 = -(g + 0.05);
    let f1 = -(g - 0.05);
    let z0 = -(g + 0.025);
    let z1 = -(g - 0.02);
    let gz = -(g + 0.018);
    // The frame, dirty where the sashes' face meets its sides.
    let at_sash = z1 - f0;
    seed++;
    paint_box(verts, indices, b, -w, -gx, s - 0.03, h, f0, f1,
              Piece { round: RIGHT, sides: RIGHT, recess: RIGHT, foot: at_sash, window: true, seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, gx, w, s - 0.03, h, f0, f1,
              Piece { round: LEFT, sides: LEFT, recess: LEFT, foot: at_sash, window: true, seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, -gx, gx, h - CASE_HEAD, h, f0, f1,
              Piece { round: BOTTOM, sides: BOTTOM, joints: LEFT | RIGHT, recess: BOTTOM, foot: at_sash, along: true, window: true,
                      seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, -gx, gx, s - 0.03, s + 0.03, f0, f1,
              Piece { round: TOP, sides: TOP, joints: LEFT | RIGHT, recess: TOP, foot: at_sash, along: true, window: true, seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, -gx, gx, zt - 0.5 * CASE_TRANSOM, zt + 0.5 * CASE_TRANSOM, f0, f1,
              Piece { round: TOP | BOTTOM, sides: TOP | BOTTOM, joints: LEFT | RIGHT, recess: TOP | BOTTOM, foot: at_sash, along: true,
                      window: true, seed: seed, .. });
    // The cover strip over the meeting stiles, dirty where it meets their face.
    let c = 0.5 * CASE_COVER;
    let cz0 = -(g + 0.03);
    seed++;
    paint_box(verts, indices, b, -c, c, s + 0.03, h - CASE_HEAD, cz0, -(g - 0.025),
              Piece { round: LEFT | RIGHT, sides: LEFT | RIGHT, joints: BOTTOM | TOP, recess: LEFT | RIGHT, foot: z1 - cz0, window: true,
                      seed: seed, .. });
    // The sashes: above the transom and below it, a leaf each side of the meeting; the glass's
    // line on their sides toward it.
    let at_glass = gz - z0;
    for part in 2 {
        let y0 = if part == 0 { zt + 0.5 * CASE_TRANSOM } else { s + 0.03 };
        let y1 = if part == 0 { h - CASE_HEAD } else { zt - 0.5 * CASE_TRANSOM };
        let rail_low = if part == 0 { CASE_RAIL } else { CASE_RAIL_LOW };
        let across = if part == 0 { UPPER_ACROSS } else { LOWER_ACROSS };
        let up = if part == 0 { UPPER_UP } else { LOWER_UP };
        for side in SIDES {
            let outer = side * gx;
            let meet = side * c;
            let lo = min(outer, meet);
            let hi = max(outer, meet);
            let ax0 = if side < 0.0 { lo + CASE_STILE } else { lo + CASE_MEET };
            let ax1 = if side < 0.0 { hi - CASE_MEET } else { hi - CASE_STILE };
            let ay0 = y0 + rail_low;
            let ay1 = y1 - CASE_RAIL;
            // The stiles in three lengths: beside the rails, square; between them, rounded
            // toward the glass.
            let stiles: float2[2] = [float2 { lo, ax0 }, float2 { ax1, hi }];
            let toward: i64[2]    = [RIGHT, LEFT];
            for st, i in stiles {
                seed++;
                paint_box(verts, indices, b, st.x, st.y, y0, ay0, z0, z1, Piece { window: true, seed: seed, .. });
                paint_box(verts, indices, b, st.x, st.y, ay0, ay1, z0, z1,
                          Piece { round: toward[i], sides: toward[i], recess: toward[i], foot: at_glass, window: true, seed: seed, .. });
                paint_box(verts, indices, b, st.x, st.y, ay1, y1, z0, z1, Piece { window: true, seed: seed, .. });
            }
            seed++;
            paint_box(verts, indices, b, ax0, ax1, y0, ay0, z0, z1,
                      Piece { round: TOP, sides: TOP, joints: LEFT | RIGHT, recess: TOP, foot: at_glass, along: true, window: true,
                              seed: seed, .. });
            seed++;
            paint_box(verts, indices, b, ax0, ax1, ay1, y1, z0, z1,
                      Piece { round: BOTTOM, sides: BOTTOM, joints: LEFT | RIGHT, recess: BOTTOM, foot: at_glass, along: true, window: true,
                              seed: seed, .. });
            let pw = (ax1 - ax0 - (across - 1) * CASE_BAR) / across;
            let ph = (ay1 - ay0 - (up - 1) * CASE_BAR) / up;
            let bz0 = -(g + 0.021);
            let bz1 = -(g - 0.015);
            for i in 1..across {
                let x = ax0 + i * (pw + CASE_BAR);
                seed++;
                paint_box(verts, indices, b, x - CASE_BAR, x, ay0, ay1, bz0, bz1,
                          Piece { round: LEFT | RIGHT, sides: LEFT | RIGHT, joints: BOTTOM | TOP, recess: LEFT | RIGHT, foot: gz - bz0,
                                  window: true, seed: seed, .. });
            }
            for j in 1..up {
                let y = ay0 + j * (ph + CASE_BAR);
                seed++;
                paint_box(verts, indices, b, ax0, ax1, y - CASE_BAR, y, bz0, bz1 - 0.0002,
                          Piece { round: BOTTOM | TOP, sides: BOTTOM | TOP, joints: LEFT | RIGHT, recess: BOTTOM | TOP, foot: gz - bz0,
                                  along: true, window: true, seed: seed, .. });
            }
        }
    }
    let gzz = -(g + 0.018);
    quad_m(glass, glass_indices, b, [float3 { -gx, s + 0.03, gzz }, float3 { gx, s + 0.03, gzz }, float3 { gx, h - CASE_HEAD, gzz },
                                     float3 { -gx, h - CASE_HEAD, gzz }], surfaces::MAT_GLASS);
}

// A box of a window's casements, in the window's own metres: x along the wall from its
// middle, y up from the floor, z out of the wall (into it negative), as box_m takes them.
struct Member { lo: float3, hi: float3 }
let MEMBERS = 66;

// The boxes the sun meets in window o's opening (room_light's bake traces its rays through
// them): each casement's blind frame, its cover strip, its sashes' stiles and rails and its
// bars, as casement and casement_quiet build them at o.glass.x and o.glass.y, and the
// lunette over them at the niche's back with the wall over it (2 m up: a line past it is
// in the wall).
fn casement_members(o: Opening) -> Member[..MEMBERS] {
    var out: Member[..MEMBERS] = [];
    let w = 0.5 * o.width;
    let gx = 0.5 * o.glass.w - CASE_FRAME;
    let s = o.sill;
    let h = o.sill + o.height;
    let zt = s + (h - s) * 2.0 / 3.0;
    let c = 0.5 * CASE_COVER;
    for g in [o.glass.x, o.glass.y] {
        let f0 = -(g + 0.05);
        let f1 = -(g - 0.05);
        out.push(Member { float3 { -w, s - 0.03, f0 }, float3 { -gx, h, f1 } });
        out.push(Member { float3 { gx, s - 0.03, f0 }, float3 { w, h, f1 } });
        out.push(Member { float3 { -gx, h - CASE_HEAD, f0 }, float3 { gx, h, f1 } });
        out.push(Member { float3 { -gx, s - 0.03, f0 }, float3 { gx, s + 0.03, f1 } });
        out.push(Member { float3 { -gx, zt - 0.5 * CASE_TRANSOM, f0 }, float3 { gx, zt + 0.5 * CASE_TRANSOM, f1 } });
        out.push(Member { float3 { -c, s + 0.03, -(g + 0.03) }, float3 { c, h - CASE_HEAD, -(g - 0.025) } });
        let z0 = -(g + 0.025);
        let z1 = -(g - 0.02);
        for part in 2 {
            let y0 = if part == 0 { zt + 0.5 * CASE_TRANSOM } else { s + 0.03 };
            let y1 = if part == 0 { h - CASE_HEAD } else { zt - 0.5 * CASE_TRANSOM };
            let rail_low = if part == 0 { CASE_RAIL } else { CASE_RAIL_LOW };
            let across = if part == 0 { UPPER_ACROSS } else { LOWER_ACROSS };
            let up = if part == 0 { UPPER_UP } else { LOWER_UP };
            for side in SIDES {
                let lo = min(side * gx, side * c);
                let hi = max(side * gx, side * c);
                let ax0 = if side < 0.0 { lo + CASE_STILE } else { lo + CASE_MEET };
                let ax1 = if side < 0.0 { hi - CASE_MEET } else { hi - CASE_STILE };
                let ay0 = y0 + rail_low;
                let ay1 = y1 - CASE_RAIL;
                out.push(Member { float3 { lo, y0, z0 }, float3 { ax0, y1, z1 } });
                out.push(Member { float3 { ax1, y0, z0 }, float3 { hi, y1, z1 } });
                out.push(Member { float3 { ax0, y0, z0 }, float3 { ax1, ay0, z1 } });
                out.push(Member { float3 { ax0, ay1, z0 }, float3 { ax1, y1, z1 } });
                let pw = (ax1 - ax0 - (across - 1) * CASE_BAR) / across;
                let ph = (ay1 - ay0 - (up - 1) * CASE_BAR) / up;
                for i in 1..across {
                    let x = ax0 + i * (pw + CASE_BAR);
                    out.push(Member { float3 { x - CASE_BAR, ay0, -(g + 0.021) }, float3 { x, ay1, -(g - 0.015) } });
                }
                for j in 1..up {
                    let y = ay0 + j * (ph + CASE_BAR);
                    out.push(Member { float3 { ax0, y - CASE_BAR, -(g + 0.021) }, float3 { ax1, y, -(g - 0.015) } });
                }
            }
        }
    }
    out.push(Member { float3 { -w, h, -(o.glass.z + 0.01) }, float3 { w, h + 2.0, -o.glass.z } });
    return out;
}
