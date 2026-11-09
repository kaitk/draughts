// The board's and the pieces' meshes, built once at startup into flat arrays: a piece is
// a profile turned on a lathe, the frame a profile swept round the playing field. Both
// sweep a profile along a path of samples, each a center and an outward direction, so
// one function builds them. The profile carries its normals and the occlusion baked
// into it (the groove, the lip).
//
// World units: a square is 1, the playing field spans -4..4 in x and z, y is up, the
// field's top is y = 0. The near side (light pieces) is +z.
namespace mesh;
import std;
import vec;
import math;

// The playing field's half width with its dark inlay round it, and the frame round that
// (about 1/18 of the board's width, as the 3D reference has it), its top above the
// field, its bullnose's radius, and the board's underside.
let FIELD:     f32 = 4.0;
let INLAY:     f32 = 0.1;
let INNER:     f32 = 4.1;
let FRAME_W:   f32 = 0.5;
let FRAME_TOP: f32 = 0.05;
let BULLNOSE:  f32 = 0.2;
let BOTTOM:    f32 = -0.5;

// A piece: 82% of a square across (the 3D reference's; the 2D board's are 78%), its height 22% of its diameter.
let RADIUS: f32 = 0.41;
let HEIGHT: f32 = 0.172;

// What a fragment is made of, the vertex's material.
let MAT_FIELD: f32 = 0.0;
let MAT_FRAME: f32 = 1.0;
let MAT_PIECE: f32 = 2.0;

// Laid out as the shaders read it: four locations of 32-bit floats.
struct Vertex { pos: float3, normal: float3, uv: float2, ao: f32, mat: f32 }

// A profile point: how far out from the path (a lathe's radius, the frame's distance
// from the field's edge), its height, its normal in that plane, its occlusion.
struct Point { out: f32, y: f32, nout: f32, ny: f32, ao: f32 }
type Profile = Point[..128];

// A path sample: a center and an outward direction in the xz plane.
struct Sample { center: float2, dir: float2 }
type Path = Sample[..320];

fn point(p: Profile&, out: f32, y: f32, nout: f32, ny: f32, ao: f32) {
    p.push(Point { out, y, nout, ny, ao });
}

// A straight segment's two ends, its normal at both: a crease where it meets another.
fn line(p: Profile&, o0: f32, y0: f32, o1: f32, y1: f32, ao0: f32, ao1: f32) {
    let t = normalize(float2 { o1 - o0, y1 - y0 });
    p.point(o0, y0, -t.y, t.x, ao0);
    p.point(o1, y1, -t.y, t.x, ao1);
}

// An arc round (co, cy) from angle a0 to a1 (radians, 0 outward, PI/2 up), convex (its
// normals point away from the center) or concave, in `steps` pieces.
fn arc(p: Profile&, co: f32, cy: f32, r: f32, a0: f32, a1: f32, steps: i64, convex: bool,
       ao0: f32, ao1: f32) {
    let sign: f32 = if convex { 1.0 } else { -1.0 };
    for i in steps + 1 {
        let k = i as f32 / steps;
        let a = a0 + (a1 - a0) * k;
        p.point(co + r * cos(a), cy + r * sin(a), sign * cos(a), sign * sin(a),
                ao0 + (ao1 - ao0) * k);
    }
}

// The piece's profile from its axis out over the face and down the side, in world units
// at scale 1: a recessed inner disc to 62% of the radius, a groove at 66% with its
// floor in shade, a raised lip at 71%, a flat ring, the outer edge rounded from 86%,
// the side, a small round at the foot, and the underside.
fn piece_profile(p: Profile&) {
    let r = RADIUS;
    let h = HEIGHT;
    let face = h - 0.004;        // the flat ring between the lip and the edge
    let inner = h - 0.010;       // the inner disc, recessed
    // The groove: a concave half round, its floor in shade.
    let gc = 0.635 * r;
    let gr = 0.06 * r;
    p.line(0.0, inner, gc - gr, inner, 1.0, 0.9);
    p.arc(gc, inner, gr, PI, PI * 2.0, 10, false, 0.85, 0.75);
    // The lip: its inner wall up from the groove, a convex half round crest, down to
    // the flat ring.
    let lw = gc + gr;
    let cr = 0.03 * r;
    p.line(lw, inner, lw, h - cr, 0.75, 0.85);
    p.arc(lw + cr, h - cr, cr, PI, 0.0, 8, true, 0.85, 1.0);
    p.line(lw + 2.0 * cr, h - cr, 0.78 * r, face, 1.0, 1.0);
    p.line(0.78 * r, face, 0.86 * r, face, 1.0, 1.0);
    // The outer edge, rounded from 86% of the radius into the side.
    let er = r - 0.86 * r;
    p.arc(0.86 * r, face - er, er, PI * 0.5, 0.0, 10, true, 1.0, 1.0);
    p.line(r, face - er, r, 0.018, 1.0, 0.9);
    p.arc(r - 0.018, 0.018, 0.018, 0.0, -PI * 0.5, 4, true, 0.9, 0.7);
    p.line(r - 0.018, 0.0, 0.0, 0.0, 0.6, 0.5);
}

// The frame's profile from the field's edge outward: the inlay's short inner wall up to
// the frame's top, the top, the bullnose, and the side down to the underside.
fn frame_profile(p: Profile&) {
    let w = FRAME_W;
    let t = FRAME_TOP;
    let e = 0.012;               // the inner edge's small round
    p.line(0.0, 0.0, 0.0, t - e, 0.75, 0.95);
    p.arc(e, t - e, e, PI, PI * 0.5, 3, true, 0.95, 1.0);
    p.line(e, t, w - BULLNOSE, t, 1.0, 1.0);
    p.arc(w - BULLNOSE, t - BULLNOSE, BULLNOSE, PI * 0.5, 0.0, 12, true, 1.0, 1.0);
    p.line(w, t - BULLNOSE, w, BOTTOM, 1.0, 0.8);
}

// The lathe's path: `n` steps round the axis, closed by repeating the first.
fn lathe_path(path: Path&, n: i64) {
    for i in n + 1 {
        let a = TAU * i as f32 / n;
        path.push(Sample { float2_0, float2 { cos(a), sin(a) } });
    }
}

// The frame's path: round the field's corners, each a quarter in `n` steps, in the
// order that keeps faces counterclockwise from outside (as the lathe goes), closed.
fn frame_path(path: Path&, n: i64) {
    let corners: float2[4] = [float2 { INNER, INNER }, float2 { -INNER, INNER },
                              float2 { -INNER, -INNER }, float2 { INNER, -INNER }];
    for c, k in corners {
        for i in n + 1 {
            let a = PI * 0.5 * (k + i as f32 / n);
            path.push(Sample { c, float2 { cos(a), sin(a) } });
        }
    }
    path.push(path[0]);
}

// Sweeps the profile along the path into verts and indices. uv is (the length along the
// path at the point's own distance out, the length along the profile).
fn sweep(verts: Vertex[>..]&, indices: u32[>..]&, prof: Profile&, path: Path&, mat: f32) {
    let base = verts.len as u32;
    var along: f32 = 0.0;
    for q, k in prof {
        if k > 0 {
            let d = float2 { q.out - prof[k - 1].out, q.y - prof[k - 1].y };
            along += length(d);
        }
        var s: f32 = 0.0;
        for smp, j in path {
            let pos2 = smp.center + smp.dir * q.out;
            if j > 0 {
                let prev = path[j - 1].center + path[j - 1].dir * q.out;
                s += length(pos2 - prev);
            }
            verts.push(Vertex { float3 { pos2.x, q.y, pos2.y },
                                float3 { smp.dir.x * q.nout, q.ny, smp.dir.y * q.nout },
                                float2 { s, along }, q.ao, mat });
        }
    }
    let n = path.len as u32;
    for k in prof.len - 1 {
        for j in path.len - 1 {
            let a = base + k as u32 * n + j as u32;
            let b = a + n;
            indices.append([a, a + 1, b + 1, a, b + 1, b]);
        }
    }
}

// The playing field: one quad at y = 0 over the field and its inlay.
fn field(verts: Vertex[>..]&, indices: u32[>..]&) {
    let base = verts.len as u32;
    let up = float3 { 0.0, 1.0, 0.0 };
    let c: float2[4] = [float2 { -INNER, -INNER }, float2 { -INNER, INNER },
                        float2 { INNER, INNER }, float2 { INNER, -INNER }];
    for p in c { verts.push(Vertex { float3 { p.x, 0.0, p.y }, up, p, 1.0, MAT_FIELD }); }
    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
}

// The board: field and frame, one mesh.
fn board(verts: Vertex[>..]&, indices: u32[>..]&) {
    field(verts, indices);
    var prof: Profile = [];
    frame_profile(prof);
    var path: Path = [];
    frame_path(path, 16);
    sweep(verts, indices, prof, path, MAT_FRAME);
}

// A piece at scale 1, standing on y = 0 round the origin.
fn piece(verts: Vertex[>..]&, indices: u32[>..]&) {
    var prof: Profile = [];
    piece_profile(prof);
    var path: Path = [];
    lathe_path(path, 72);
    sweep(verts, indices, prof, path, MAT_PIECE);
}
