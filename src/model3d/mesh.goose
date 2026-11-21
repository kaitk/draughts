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
// field, its bullnose's radius, and the board's underside. The one source:
// src/board/view3d.goose (the taps' geometry) takes them from here, and the shaders'
// copies in src/render3d/shaders.goose are checked against them (test/model3d/geometry).
let FIELD:     f32 = 4.0;
let INLAY:     f32 = 0.1;
let INNER:     f32 = 4.1;
let FRAME_W:   f32 = 0.5;
let FRAME_TOP: f32 = 0.05;
let BULLNOSE:  f32 = 0.09;
let BOTTOM:    f32 = -0.7;

// A piece: 88% of a square across and its height 33% of its diameter, as measured on
// the 3D reference at the same framing (the 2D board's are 78%).
let RADIUS: f32 = 0.44;
let HEIGHT: f32 = 0.29;

// What a fragment is made of, the vertex's material.
let MAT_FIELD: f32 = 0.0;
let MAT_FRAME: f32 = 1.0;
let MAT_PIECE: f32 = 2.0;
let MAT_TABLE: f32 = 3.0;

// The round table the board stands on: its top's radius, a little under the board's
// foot, its middle behind the board's, as a board stands toward the player on a table,
// and the top's thickness. The board's thick frame makes it a small one, about 30 cm
// with squares of about 3.3 cm (surfaces::METRE 30.48 units), so a games table 0.95 m
// across, between a period one's 0.80 m and the 1.05 m it was, is 14.48 in radius. Its
// wood's map keeps the 1.05 m top's half side, TABLE_MAP_R, so the figure keeps its scale
// whatever the top's size.
let TABLE_R:     f32 = 14.48;
let TABLE_MAP_R: f32 = 16.0;
let TABLE_TOP: f32 = -0.703;
let TABLE_Z:   f32 = -4.5;
let TABLE_SEGMENTS = 128;

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

// The piece's top, a smooth function of the distance from the axis over the radius, as
// the 3D reference has it: a flat band from where the edge rounds (89%) in to 69%, one
// step down, crisper at its top, with a narrow cove at its foot (the reference's dark
// and light lines round the inner disc), and the flat inner disc inside 63%.
// The mesh samples it and the shader repeats it (shaders::LIT_FRAG's top_height and
// top_ao) for the normal and the occlusion at each pixel, so the step shades the same
// however the triangles fall.
let EDGE_AT:    f32 = 0.89;
let STEP_IN:    f32 = 0.63;
let STEP_OUT:   f32 = 0.69;
let STEP_DEPTH: f32 = 0.02;
let COVE_DEPTH: f32 = 0.008;
fn top_height(u: f32) -> f32 {
    let t = clamp((u - STEP_IN) / (STEP_OUT - STEP_IN), 0.0, 1.0);
    let c = (u - STEP_IN - 0.006) / 0.022;
    return -STEP_DEPTH * (1.0 - t * t * (2.4 - 1.4 * t)) - COVE_DEPTH * exp(-c * c);
}
fn top_ao(u: f32) -> f32 {
    let c = (u - STEP_IN - 0.004) / 0.026;
    return 1.0 - 0.05 * (1.0 - u) - 0.3 * exp(-c * c);
}

// The piece's profile from its axis out over the face and down the side, in world units
// at scale 1: the top sampled from top_height at TOP_ROWS, the outer edge rounded from
// 89% of the radius into the side, the side, a small round at the foot, and the
// underside. The top's rows only place it: the lit shader shades the top from
// top_height at each pixel, so a few rows round the step do.
let TOP_ROWS = [0.0, 0.6, 0.625, 0.64, 0.655, 0.67, 0.69, 0.79, 0.89];
let SEGMENTS = 48;
fn piece_profile(p: Profile&) {
    let r = RADIUS;
    let h = HEIGHT;
    for row in TOP_ROWS {
        let u = row as f32;
        let e: f32 = 0.002;
        let slope = (top_height(u + e) - top_height(u - e)) / (2.0 * e * r);
        let n = normalize(float2 { -slope, 1.0 });
        p.point(u * r, h + top_height(u), n.x, n.y, top_ao(u));
    }
    let er = r - EDGE_AT * r;
    p.arc(EDGE_AT * r, h - er, er, PI * 0.5, 0.0, 6, true, 1.0, 1.0);
    p.line(r, h - er, r, 0.025, 1.0, 0.92);
    p.arc(r - 0.025, 0.025, 0.025, 0.0, -PI * 0.5, 3, true, 0.92, 0.75);
    p.line(r - 0.025, 0.0, 0.0, 0.0, 0.6, 0.5);
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

// The table's edge profiles (tables::Table.edge.x), the period's (1890 to 1910, late
// Historicism) beside a plain one: a bullnose, rounded over above and under a flat band;
// a thumbnail, an ovolo over a fillet and a cove back in under; a reverse ogee, the
// convex curve over the concave stepping out to a fillet, a cove under; a stepped edge,
// an ovolo, a fillet, a bead, and a cove under. Each over a frieze set back under the
// top with a bead at its foot (none under the bullnose).
let EDGE_BULLNOSE = 0;
let EDGE_THUMBNAIL = 1;
let EDGE_OGEE = 2;
let EDGE_STEPPED = 3;
let EDGES = 4;

// The table's top from its middle out, as `edge` says (tables::Table.edge): x the
// profile, y the top's thickness, z the moulding's size, w how far in the frieze is set;
// `r` its radius. Its underside closed under the frieze.
fn table_profile(p: Profile&, edge: float4, r: f32 = TABLE_R) {
    let y = TABLE_TOP;
    let t = max(edge.y, 0.3);
    let m = clamp(edge.z, 0.08, 0.45 * t);
    let low = y - t;
    let kind = edge.x as i64;
    if kind == EDGE_THUMBNAIL {
        p.line(0.0, y, r - m, y, 1.0, 1.0);
        p.arc(r - m, y - m, m, PI * 0.5, 0.0, 8, true, 1.0, 1.0);
        let f = 0.25 * m;
        p.line(r, y - m, r, y - m - f, 1.0, 0.95);
        let c = t - m - f;
        p.arc(r, y - m - f - c, c, PI * 0.5, PI, 8, false, 0.9, 0.7);
        p.line(r - c, low, r - edge.w, low, 0.6, 0.45);
    } else if kind == EDGE_OGEE {
        let a = 0.5 * m;
        p.line(0.0, y, r - 2.0 * a, y, 1.0, 1.0);
        p.arc(r - 2.0 * a, y - a, a, PI * 0.5, 0.0, 6, true, 1.0, 1.0);
        p.arc(r, y - a, a, PI, PI * 1.5, 6, false, 0.95, 0.9);
        let f = 0.35 * m;
        p.line(r, y - 2.0 * a, r, y - 2.0 * a - f, 1.0, 0.95);
        let c = t - 2.0 * a - f;
        p.arc(r, y - 2.0 * a - f - c, c, PI * 0.5, PI, 8, false, 0.9, 0.7);
        p.line(r - c, low, r - edge.w, low, 0.6, 0.45);
    } else if kind == EDGE_STEPPED {
        let o = 0.6 * m;
        p.line(0.0, y, r - o, y, 1.0, 1.0);
        p.arc(r - o, y - o, o, PI * 0.5, 0.0, 6, true, 1.0, 1.0);
        let f = 0.2 * m;
        p.line(r, y - o, r, y - o - f, 1.0, 0.85);
        // The bead, a half round under the fillet, set in a little.
        let b = 0.22 * m;
        p.line(r, y - o - f, r - 0.15 * m, y - o - f, 0.8, 0.8);
        p.arc(r - 0.15 * m, y - o - f - b, b, PI * 0.5, -PI * 0.5, 8, true, 0.85, 0.75);
        let top_c = y - o - f - 2.0 * b;
        let c = max(top_c - low, 0.05);
        p.arc(r - 0.15 * m, top_c - c, c, PI * 0.5, PI, 8, false, 0.85, 0.65);
        p.line(r - 0.15 * m - c, low, r - edge.w, low, 0.6, 0.45);
    } else {
        let over = 0.33 * t;
        let band = 0.2 * t;
        let under = t - over - band;
        p.line(0.0, y, r - over, y, 1.0, 1.0);
        p.arc(r - over, y - over, over, PI * 0.5, 0.0, 8, true, 1.0, 1.0);
        p.line(r, y - over, r, y - over - band, 1.0, 0.95);
        p.arc(r - under, low + under, under, 0.0, -PI * 0.5, 8, true, 0.95, 0.7);
        p.line(r - under, low, r - edge.w, low, 0.6, 0.4);
        p.line(r - edge.w, low, r - edge.w, low - 2.4, 0.5, 0.6);
        p.line(r - edge.w, low - 2.4, 0.0, low - 2.4, 0.4, 0.3);
        return;
    }
    // The frieze under the top, a bead at its foot.
    let fr = r - edge.w;
    let fh = 2.2;
    let bead = 0.12;
    p.line(fr, low, fr, low - fh, 0.45, 0.8);
    p.arc(fr, low - fh - bead, bead, PI * 0.5, -PI * 0.5, 8, true, 0.85, 0.7);
    p.line(fr, low - fh - 2.0 * bead, fr - 0.3, low - fh - 2.0 * bead, 0.6, 0.5);
    p.line(fr - 0.3, low - fh - 2.0 * bead, 0.0, low - fh - 2.0 * bead, 0.5, 0.3);
}

// The lathe's path: `n` steps round the axis at `center`, closed by repeating the first.
fn lathe_path(path: Path&, n: i64, center: float2 = float2_0) {
    for i in n + 1 {
        let a = TAU * i as f32 / n;
        path.push(Sample { center, float2 { cos(a), sin(a) } });
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

// The table under the board with its `edge` (tables::Table.edge) and its top's radius,
// standing on its base (table_base) on the floor at `floor_y`, one mesh.
fn table(verts: Vertex[>..]&, indices: u32[>..]&, edge: float4, radius: f32, floor_y: f32) {
    var prof: Profile = [];
    table_profile(prof, edge, radius);
    var path: Path = [];
    lathe_path(path, TABLE_SEGMENTS, float2 { 0.0, TABLE_Z });
    sweep(verts, indices, prof, path, MAT_TABLE);
    table_base(verts, indices, floor_y);
}

// A point on a Catmull-Rom curve through b and c, t from 0 at b to 1 at c.
fn catmull(a: float4, b: float4, c: float4, d: float4, t: f32) -> float4 {
    let t2 = t * t;
    let t3 = t2 * t;
    return (b * 2.0 + (c - a) * t + (a * 2.0 - b * 5.0 + c * 4.0 - d) * t2 + (b * 3.0 - a - c * 3.0 + d) * t3) * 0.5;
}

// A turned outline, `pts` (radius, height) in millimetres from its top down, at `mm`
// world units a millimetre over `y0`: its normals smooth along it, a point given twice a
// crease where each copy takes its own side's; a groove (a point inside its neighbours)
// darker, by how deep it sits.
fn turned(p: Profile&, pts: const float2[:], mm: f32, y0: f32) {
    for q, i in pts {
        let crease_before = i > 0 && pts[i - 1].x == q.x && pts[i - 1].y == q.y;
        let crease_after = i + 1 < pts.len && pts[i + 1].x == q.x && pts[i + 1].y == q.y;
        let a = if i > 0 && !crease_before { pts[i - 1] } else { q };
        let b = if i + 1 < pts.len && !crease_after { pts[i + 1] } else { q };
        // A crease's copy takes the one segment on its side.
        var t = b - a;
        if crease_before && i + 1 < pts.len { t = pts[i + 1] - q; }
        if crease_after && i > 0 { t = q - pts[i - 1]; }
        let d = normalize(t);
        let groove = max(0.5 * (a.x + b.x) - q.x, 0.0);
        p.point(q.x * mm, y0 + q.y * mm, -d.y, d.x, 1.0 - min(0.04 * groove, 0.35));
    }
}

// A bar's rib: a point on its spine, the section's axes there (up, in the bend's plane,
// and across it, with the spine's direction a right-handed frame), its half sizes along
// them, how round its corners are (0 square, 1 a full round of the smaller half), and its
// occlusion. A bar sweeps a rounded rectangle along its spine, as a band-sawn piece is
// shaped and its edges moulded: a cabriole leg, a rail, a bracket foot.
struct Rib { at: float3, up: float3, across: float3, half: float2, round: f32, ao: f32 }
type Spine = Rib[..96];

// Each corner of a bar's section in this many pieces: a ring of 4 × 3 points.
let CORNER_STEPS = 2;

// A spine's ribs through `pts` (x, y in the bend's plane, z and w the section's half
// sizes, in millimetres), the plane through `origin` along `dir` (x) and up (y), at `mm`
// world units a millimetre; each rib's section turned square to the spine.
fn bent_spine(spine: Spine&, pts: const float4[:], origin: float3, dir: float3, mm: f32, round: f32, ao: f32) {
    let side = normalize(cross(dir, float3 { 0.0, 1.0, 0.0 }));
    for q, i in pts {
        let a = pts[max(i - 1, 0)];
        let b = pts[min(i + 1, pts.len - 1)];
        let t = normalize(dir * (b.x - a.x) + float3 { 0.0, b.y - a.y, 0.0 });
        let at = origin + dir * (q.x * mm) + float3 { 0.0, q.y * mm, 0.0 };
        spine.push(Rib { at, normalize(cross(side, t)), side, float2 { q.z * mm, q.w * mm }, round, ao });
    }
}

// Sweeps a bar's section along its spine into verts and indices, its end closed with
// `cap`. uv is (round the section, mirrored so it meets itself; along the spine).
fn bar(verts: Vertex[>..]&, indices: u32[>..]&, spine: Spine&, mat: f32, cap: bool = true) {
    let ring = 4 * (CORNER_STEPS + 1);
    let base = verts.len as u32;
    var along: f32 = 0.0;
    for rb, k in spine {
        if k > 0 { along += length(rb.at - spine[k - 1].at); }
        let r = rb.round * min(rb.half.x, rb.half.y);
        let c = rb.half - float2 { r, r };
        let perimeter = 4.0 * (c.x + c.y) + TAU * r;
        var s: f32 = 0.0;
        var prev = float2_0;
        for j in ring + 1 {
            let corner = (j / (CORNER_STEPS + 1)) % 4;
            let step = j % (CORNER_STEPS + 1);
            let a = PI * 0.5 * (corner + step as f32 / CORNER_STEPS);
            let n = float2 { cos(a), sin(a) };
            let sx: f32 = if corner == 0 || corner == 3 { 1.0 } else { -1.0 };
            let sy: f32 = if corner < 2 { 1.0 } else { -1.0 };
            let q = float2 { sx * c.x, sy * c.y } + n * r;
            if j > 0 { s += length(q - prev); }
            prev = q;
            let at = rb.at + rb.up * q.x + rb.across * q.y;
            let normal = rb.up * n.x + rb.across * n.y;
            verts.push(Vertex { at, normal, float2 { abs(s - 0.5 * perimeter), along }, rb.ao, mat });
        }
    }
    let n = (ring + 1) as u32;
    for k in spine.len - 1 {
        for j in ring {
            let a = base + k as u32 * n + j as u32;
            let b = a + n;
            indices.append([a, a + 1, b + 1, a, b + 1, b]);
        }
    }
    guard cap && spine.len > 1 else { return; }
    // The end, flat across the last rib, facing on along the spine.
    let last = spine[spine.len - 1];
    let t = normalize(last.at - spine[spine.len - 2].at);
    let mid = verts.len as u32;
    verts.push(Vertex { last.at, t, float2 { 0.0, along }, last.ao, mat });
    let first = base + (spine.len - 1) as u32 * n;
    for j in ring + 1 {
        let v = verts[(first + j as u32) as i64];
        verts.push(Vertex { v.pos, t, v.uv, v.ao, mat });
    }
    for j in ring { indices.append([mid, mid + 1 + j as u32, mid + 2 + j as u32]); }
}

// The table's base, as style-01's games table (build/notes/games-table, option A):
// a turned column from under the top to a drum 100 mm off the floor, ringed under the
// top, a large urn over a beaded neck, and four cabriole legs from the drum, their knees
// high by it, sweeping down to scroll toes on the floor 0.36 m out. Its measures in
// millimetres up from the floor (a top 750 mm high); MAT_TABLE_BASE, its grain along
// the column and the legs (shaders::TABLE_FRAG).
let MAT_TABLE_BASE: f32 = 4.0;
let BASE_SEGMENTS = 24;          // round the column: its silhouette's chord under 1 mm
let LEG_SAMPLES = 4;             // the leg's curve, each span between its points
let SCROLL_SAMPLES = 12;
let TABLE_MM: f32 = 0.03048;     // world units a millimetre (surfaces::METRE / 1000)
let COLUMN: float2[55] = [
    // Under the top, inside the frieze, and its collar.
    float2 { 80.0, 660.0 }, float2 { 80.0, 640.0 }, float2 { 76.0, 632.0 }, float2 { 66.0, 625.0 },
    float2 { 56.0, 619.0 }, float2 { 55.0, 613.0 },
    // Four rings.
    float2 { 58.0, 606.0 }, float2 { 60.0, 600.0 }, float2 { 57.0, 593.0 }, float2 { 49.0, 587.0 },
    float2 { 55.0, 579.0 }, float2 { 58.0, 572.0 }, float2 { 55.0, 565.0 }, float2 { 48.0, 559.0 },
    float2 { 54.0, 551.0 }, float2 { 57.0, 544.0 }, float2 { 54.0, 537.0 }, float2 { 47.0, 531.0 },
    float2 { 53.0, 523.0 }, float2 { 56.0, 516.0 }, float2 { 53.0, 509.0 }, float2 { 46.0, 503.0 },
    // The neck over the urn, a bead.
    float2 { 45.0, 494.0 }, float2 { 48.0, 486.0 }, float2 { 55.0, 482.0 }, float2 { 57.0, 477.0 },
    float2 { 52.0, 472.0 }, float2 { 47.0, 468.0 },
    // The urn.
    float2 { 50.0, 458.0 }, float2 { 60.0, 445.0 }, float2 { 74.0, 428.0 }, float2 { 88.0, 410.0 },
    float2 { 99.0, 392.0 }, float2 { 105.0, 372.0 }, float2 { 106.0, 354.0 }, float2 { 103.0, 336.0 },
    float2 { 95.0, 320.0 }, float2 { 82.0, 306.0 }, float2 { 68.0, 296.0 },
    // The neck under it, a bead, and the collar over the drum.
    float2 { 60.0, 290.0 }, float2 { 64.0, 282.0 }, float2 { 66.0, 275.0 }, float2 { 62.0, 268.0 },
    float2 { 54.0, 262.0 }, float2 { 52.0, 252.0 }, float2 { 58.0, 244.0 }, float2 { 70.0, 238.0 },
    float2 { 80.0, 232.0 }, float2 { 82.0, 226.0 }, float2 { 80.0, 220.0 },
    // The drum the legs come out of, its foot rounded, its underside flat.
    float2 { 72.0, 212.0 }, float2 { 72.0, 108.0 }, float2 { 66.0, 100.0 }, float2 { 66.0, 100.0 }, float2 { 0.0, 100.0 },
];
// A leg's curve in its plane (out from the column's axis, up from the floor) and its
// section's half height and half width, from its root inside the drum over the knee
// down to where the scroll begins.
let LEG: float4[7] = [
    float4 { 30.0, 176.0, 50.0, 26.0 }, float4 { 80.0, 188.0, 50.0, 26.0 }, float4 { 125.0, 184.0, 48.0, 25.0 },
    float4 { 170.0, 156.0, 42.0, 23.0 }, float4 { 215.0, 112.0, 34.0, 21.0 }, float4 { 258.0, 72.0, 27.0, 20.0 },
    float4 { 292.0, 47.0, 22.0, 19.0 },
];
// The scroll: round its middle (out, up) from an angle (degrees, 0 out, 90 up) on
// through a turn, under the toe, out and up and back over, its radius and the section's
// half height shrinking from the first to the second, the half width from 20 to 22.
let SCROLL_MID = float2 { 328.0, 38.0 };
let SCROLL_TURN = float2 { -150.0, 310.0 };
let SCROLL_RADIUS = float2 { 22.0, 9.0 };
let SCROLL_HALF = float2 { 17.0, 7.0 };

fn table_base(verts: Vertex[>..]&, indices: u32[>..]&, floor_y: f32) {
    let mm = TABLE_MM;
    var prof: Profile = [];
    turned(prof, COLUMN[..], mm, floor_y);
    var path: Path = [];
    lathe_path(path, BASE_SEGMENTS, float2 { 0.0, TABLE_Z });
    let first = verts.len;
    sweep(verts, indices, prof, path, MAT_TABLE_BASE);
    // Round the column mirrored about its back, so the grain meets itself there.
    for i in first..verts.len {
        let v .= verts[i];
        v.uv.x = abs(v.uv.x - PI * length(float2 { v.pos.x, v.pos.z - TABLE_Z }));
    }
    // The legs, toward the board's corners, each a curve through LEG and on round the
    // scroll.
    var curve: float4[..64] = [];
    let n = LEG.len;
    for i in n {
        let a = LEG[max(i - 1, 0)];
        let b = LEG[i];
        guard i + 1 < n else { break; }
        let c = LEG[i + 1];
        let d = if i + 2 < n { LEG[i + 2] } else { scroll_at(0.0) };
        for s in LEG_SAMPLES { curve.push(catmull(a, b, c, d, s as f32 / LEG_SAMPLES)); }
    }
    // The last span from the leg's last point into the scroll's first.
    for s in LEG_SAMPLES {
        curve.push(catmull(LEG[n - 2], LEG[n - 1], scroll_at(0.0), scroll_at(1.0 / SCROLL_SAMPLES), s as f32 / LEG_SAMPLES));
    }
    for s in SCROLL_SAMPLES + 1 { curve.push(scroll_at(s as f32 / SCROLL_SAMPLES)); }
    for k in 4 {
        let a = PI * (0.25 + 0.5 * k as f32);
        let dir = float3 { cos(a), 0.0, sin(a) };
        var spine: Spine = [];
        bent_spine(spine, curve[..], float3 { 0.0, floor_y, TABLE_Z }, dir, mm, 0.55, 0.9);
        bar(verts, indices, spine, MAT_TABLE_BASE);
    }
}

// The scroll's point a share t along it (as LEG's: out, up, half height, half width).
fn scroll_at(t: f32) -> float4 {
    let a = radians(SCROLL_TURN.x + SCROLL_TURN.y * t);
    let r = lerp(SCROLL_RADIUS.x, SCROLL_RADIUS.y, t);
    return float4 { SCROLL_MID.x + r * cos(a), SCROLL_MID.y + r * sin(a), lerp(SCROLL_HALF.x, SCROLL_HALF.y, t),
                    20.0 + 2.0 * t };
}

// A piece at scale 1, standing on y = 0 round the origin.
fn piece(verts: Vertex[>..]&, indices: u32[>..]&) {
    var prof: Profile = [];
    piece_profile(prof);
    var path: Path = [];
    lathe_path(path, SEGMENTS);
    sweep(verts, indices, prof, path, MAT_PIECE);
}
