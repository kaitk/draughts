// The two side chairs at the games table, one for each player (2026-11-24, task 107): a
// Neo-Rococo balloon-back side chair of the 1860s, as the style-01 room's suite has it, in
// the table's flame mahogany. Cabriole front legs from the corners of a bowed seat rail;
// the back legs rising through the rail into the back's uprights, which waist and swell
// into the balloon and meet over its top; a curved cross rail closing the balloon at the
// waist; a drop-in seat stuffed in grey-green velvet. Its measures in millimetres in the
// chair's own frame (x across, y up from the floor, z forward), turned and set on the floor
// where each player sits (CHAIRS). Built into the table's mesh after the table, only where
// the room shows (render3d::Gpu.chairs): MAT_CHAIR its wood, its grain along each piece
// (TABLE_FRAG's base), MAT_SEAT the velvet.
namespace mesh;
import std;
import vec;
import math;

let MAT_CHAIR: f32 = 5.0;
let MAT_SEAT:  f32 = 6.0;

// Where each chair stands round the games table in the board's world (units, the table's
// middle at (0, TABLE_Z)): its seat's middle (x, z), and the sine and cosine of its turn
// (its front, local +z, faces (sin, cos)). The players sit on the board's axis: the far
// one close in, its seat 6 cm off the top's rim, turned 6 degrees; the near one pulled 0.25 m out from the top's rim,
// turned 14 degrees the other way and 6 cm aside. ROOM_FRAG's floor (CHAIR_A, CHAIR_B)
// holds the same numbers for the feet's contact on the floor
// (test/model3d/geometry checks them).
let CHAIRS: float4[2] = [
    float4 { 0.0, -27.884, 0.104528, 0.994522 },
    float4 { 1.829, 24.64, -0.241922, -0.970296 },
];
let CHAIR_MM: f32 = 0.03048;     // world units a millimetre, as TABLE_MM

// The seat rail's middle line round the seat, a closed curve (x, z), its right half from
// the front's middle round to the back's (mirrored for the left), and its height.
let SEAT_HALF: float2[10] = [
    float2 { 0.0, 222.0 }, float2 { 105.0, 217.0 }, float2 { 190.0, 204.0 }, float2 { 218.0, 178.0 },
    float2 { 212.0, 70.0 }, float2 { 198.0, -60.0 }, float2 { 186.0, -168.0 }, float2 { 172.0, -190.0 },
    float2 { 92.0, -188.0 }, float2 { 0.0, -184.0 },
];
let RAIL_Y: f32 = 395.0;
let RAIL_HALF = float2 { 12.0, 36.0 };     // across the rail, up it
let RAIL_SAMPLES = 4;

// A front leg in its plane (out along the corner's diagonal, up from the floor) with its
// section's half sizes, from the knee block inside the rail down to the pad of its foot.
let FRONT_LEG: float4[10] = [
    float4 { 0.0, 430.0, 20.0, 20.0 }, float4 { 2.0, 372.0, 21.0, 21.0 }, float4 { 15.0, 328.0, 23.0, 23.0 },
    float4 { 11.0, 280.0, 20.0, 20.0 }, float4 { -2.0, 210.0, 15.0, 15.0 }, float4 { -10.0, 132.0, 12.0, 12.0 },
    float4 { -8.0, 70.0, 12.0, 12.0 }, float4 { 2.0, 30.0, 15.0, 15.0 }, float4 { 10.0, 10.0, 19.0, 19.0 },
    float4 { 12.0, 0.0, 19.0, 19.0 },
];
let FRONT_LEG_AT = float2 { 200.0, 185.0 };
let LEG_SPAN_SAMPLES = 3;

// The back: a back leg from its foot up through the rail and on up the upright, round the
// balloon to the middle of its top (x, y, z; w the section's half width, its half depth
// BACK_DEPTH of that), mirrored for the other side into one piece.
let BACK_HALF: float4[13] = [
    float4 { 178.0, 0.0, -265.0, 13.0 }, float4 { 180.0, 120.0, -240.0, 14.0 }, float4 { 182.0, 250.0, -215.0, 15.0 },
    float4 { 184.0, 360.0, -199.0, 16.0 }, float4 { 184.0, 431.0, -196.0, 16.0 }, float4 { 179.0, 515.0, -214.0, 14.0 },
    float4 { 164.0, 588.0, -230.0, 12.5 }, float4 { 170.0, 660.0, -246.0, 12.5 }, float4 { 191.0, 742.0, -264.0, 13.0 },
    float4 { 185.0, 822.0, -281.0, 13.5 }, float4 { 148.0, 882.0, -294.0, 14.0 }, float4 { 82.0, 913.0, -301.0, 14.5 },
    float4 { 0.0, 922.0, -303.0, 15.0 },
];
let BACK_DEPTH: f32 = 1.1;
// The cross rail closing the balloon at the waist, dipping and bowed back a little; w its
// half height, its half depth CROSS_DEPTH of that.
let CROSS: float4[5] = [
    float4 { -172.0, 590.0, -231.0, 21.0 }, float4 { -90.0, 579.0, -240.0, 23.0 }, float4 { 0.0, 575.0, -244.0, 25.0 },
    float4 { 90.0, 579.0, -240.0, 23.0 }, float4 { 172.0, 590.0, -231.0, 21.0 },
];
let CROSS_DEPTH: f32 = 0.5;

// The drop-in seat: rings out from its middle as a share of the rail's line and their
// heights, from its edge rolled over the rail's top to the dome.
let PAD: float2[9] = [
    float2 { 1.03, 428.0 }, float2 { 1.04, 442.0 }, float2 { 1.025, 456.0 }, float2 { 0.98, 466.0 },
    float2 { 0.88, 473.0 }, float2 { 0.7, 477.0 }, float2 { 0.45, 479.0 }, float2 { 0.2, 480.0 },
    float2 { 0.0, 480.0 },
];
let PAD_MID = float2 { 0.0, 10.0 };

// Both chairs on the floor at `floor_y` (world units), into verts and indices.
fn chairs(verts: Vertex[>..]&, indices: u32[>..]&, floor_y: f32) {
    for c, k in CHAIRS { chair(verts, indices, c, floor_y, k); }
}

// One chair at `at` (CHAIRS'), its pieces' grain offset by `which` so the two differ.
fn chair(verts: Vertex[>..]&, indices: u32[>..]&, at: float4, floor_y: f32, which: i64) {
    let first = verts.len;
    let first_index = indices.len;
    // The seat rail round the seat.
    var line: float4[..96] = [];
    seat_line(line);
    var spine: Spine = [];
    for k in line.len { spine.push(rib(line[..], k, true, float3 { 0.0, 1.0, 0.0 }, RAIL_HALF, 0.4)); }
    // Closed: its last rib on its first.
    spine.push(spine[0]);
    let rail_from = verts.len;
    bar(verts, indices, spine, MAT_CHAIR, false);
    shift_uv(verts, rail_from, float2 { 37.0 + 300.0 * which, 0.0 });
    // The front legs, each in the plane of its corner's diagonal.
    var leg: float4[..96] = [];
    smooth_open(leg, FRONT_LEG[..], LEG_SPAN_SAMPLES);
    for side in 2 {
        let sx: f32 = if side == 0 { 1.0 } else { -1.0 };
        var s: Spine = [];
        bent_spine(s, leg[..], float3 { sx * FRONT_LEG_AT.x, 0.0, FRONT_LEG_AT.y }, normalize(float3 { sx, 0.0, 1.0 }), 1.0, 0.85, 0.95);
        let from = verts.len;
        bar(verts, indices, s, MAT_CHAIR);
        shift_uv(verts, from, float2 { 120.0 * side + 410.0 * which, 90.0 * side });
    }
    // The back, one piece from foot to foot round the balloon.
    var back_pts: float4[..32] = [];
    for q in BACK_HALF { back_pts.push(q); }
    for i in 1..BACK_HALF.len {
        let q = BACK_HALF[BACK_HALF.len - 1 - i];
        back_pts.push(float4 { -q.x, q.y, q.z, q.w });
    }
    var back: float4[..96] = [];
    smooth_open(back, back_pts[..], 3);
    var bs: Spine = [];
    for k in back.len { bs.push(rib(back[..], k, false, float3 { 0.0, 0.0, 1.0 }, float2 { back[k].w, back[k].w * BACK_DEPTH }, 0.7)); }
    let back_from = verts.len;
    bar(verts, indices, bs, MAT_CHAIR);
    shift_uv(verts, back_from, float2 { 210.0 + 170.0 * which, 0.0 });
    // The cross rail.
    var cross: float4[..96] = [];
    smooth_open(cross, CROSS[..], 3);
    var cs: Spine = [];
    for k in cross.len { cs.push(rib(cross[..], k, false, float3 { 0.0, 0.0, 1.0 }, float2 { cross[k].w, cross[k].w * CROSS_DEPTH }, 0.6)); }
    let cross_from = verts.len;
    bar(verts, indices, cs, MAT_CHAIR);
    shift_uv(verts, cross_from, float2 { 60.0 + 230.0 * which, 500.0 });
    // The seat, its normals from its faces.
    seat_pad(verts, indices, line);
    face_out(verts, indices, first_index);
    // Into the world: millimetres to world units, turned, set on the floor.
    let s = at.z;
    let c = at.w;
    for i in first..verts.len {
        let v .= verts[i];
        let p = v.pos * CHAIR_MM;
        v.pos = float3 { at.x + c * p.x + s * p.z, floor_y + p.y, at.y - s * p.x + c * p.z };
        v.normal = float3 { c * v.normal.x + s * v.normal.z, v.normal.y, -s * v.normal.x + c * v.normal.z };
        v.uv = v.uv * CHAIR_MM;
    }
}

// The seat rail's middle line, closed, smooth through SEAT_HALF and its mirror (x, rail's
// height, z; w unused), counterclockwise seen from above.
fn seat_line(line: float4[..96]&) {
    var ring: float4[..24] = [];
    for q in SEAT_HALF { ring.push(float4 { q.x, RAIL_Y, q.y, 0.0 }); }
    for i in 1..SEAT_HALF.len - 1 {
        let q = SEAT_HALF[SEAT_HALF.len - 1 - i];
        ring.push(float4 { -q.x, RAIL_Y, q.y, 0.0 });
    }
    let n = ring.len;
    for i in n {
        let a = ring[(i + n - 1) % n];
        let b = ring[i];
        let c = ring[(i + 1) % n];
        let d = ring[(i + 2) % n];
        for s in RAIL_SAMPLES { line.push(catmull(a, b, c, d, s as f32 / RAIL_SAMPLES)); }
    }
}

// An open curve smooth through `pts`, `per` samples a span, its last point kept.
fn smooth_open(out: float4[..96]&, pts: const float4[:], per: i64) {
    let n = pts.len;
    for i in n - 1 {
        let a = pts[max(i - 1, 0)];
        let b = pts[i];
        let c = pts[i + 1];
        let d = pts[min(i + 2, n - 1)];
        for s in per { out.push(catmull(a, b, c, d, s as f32 / per)); }
    }
    out.push(pts[n - 1]);
}

// A rib at point k of a curve (round its ends where `closed`), its section's depth along
// `toward` turned square to the curve, half sizes `half` (in the curve's bend, along
// `toward`).
fn rib(curve: const float4[:], k: i64, closed: bool, toward: float3, half: float2, round: f32) -> Rib {
    let n = curve.len;
    let a = if closed { curve[(k + n - 1) % n] } else { curve[max(k - 1, 0)] };
    let b = if closed { curve[(k + 1) % n] } else { curve[min(k + 1, n - 1)] };
    let q = curve[k];
    let t = normalize(float3 { b.x - a.x, b.y - a.y, b.z - a.z });
    let across = normalize(toward - t * dot(toward, t));
    return Rib { float3 { q.x, q.y, q.z }, normalize(cross(across, t)), across, half, round, 1.0 };
}

// The pieces' grain moved along so no two show the same figure.
fn shift_uv(verts: Vertex[>..]&, from: i64, by: float2) {
    for i in from..verts.len { verts[i].uv = verts[i].uv + by; }
}

// The drop-in seat over the rail's line: PAD's rings, a fan to its middle; uv the seat's
// plan in millimetres. Its normals summed from its faces, turned up.
fn seat_pad(verts: Vertex[>..]&, indices: u32[>..]&, line: float4[..96]&) {
    let base = verts.len;
    let n = line.len + 1;
    for r in PAD {
        for j in n {
            let q = line[j % line.len];
            let x = PAD_MID.x + (q.x - PAD_MID.x) * r.x;
            let z = PAD_MID.y + (q.z - PAD_MID.y) * r.x;
            let ao: f32 = if r.x > 1.0 { 0.75 } else { 1.0 };
            verts.push(Vertex { float3 { x, r.y, z }, float3_0, float2 { x, z }, ao, MAT_SEAT });
        }
    }
    let first_index = indices.len;
    for k in PAD.len - 1 {
        for j in n - 1 {
            let a = (base + k * n + j) as u32;
            let b = a + n as u32;
            indices.append([a, a + 1, b + 1, a, b + 1, b]);
        }
    }
    // Summed face normals, each ring's seam (its first and last point, one place) shared.
    var i = first_index;
    while i < indices.len {
        let a = indices[i] as i64;
        let b = indices[i + 1] as i64;
        let c = indices[i + 2] as i64;
        let f = cross(verts[b].pos - verts[a].pos, verts[c].pos - verts[a].pos);
        verts[a].normal = verts[a].normal + f;
        verts[b].normal = verts[b].normal + f;
        verts[c].normal = verts[c].normal + f;
        i += 3;
    }
    for k in PAD.len {
        let s = base + k * n;
        let sum = verts[s].normal + verts[s + n - 1].normal;
        verts[s].normal = sum;
        verts[s + n - 1].normal = sum;
    }
    // The middle ring is one point: all its copies one normal, up.
    let up_side: f32 = if verts[base + (PAD.len - 2) * n].normal.y < 0.0 { -1.0 } else { 1.0 };
    for i in base..verts.len {
        let v .= verts[i];
        v.normal = if length(v.normal) > 1e-6 { normalize(v.normal) * up_side } else { float3 { 0.0, 1.0, 0.0 } };
        if i >= base + (PAD.len - 1) * n { v.normal = float3 { 0.0, 1.0, 0.0 }; }
    }
}

// Every triangle from `first_index` on turned to face where its vertices' normals point
// (counterclockwise seen from outside, as the table's pipeline culls), whichever way its
// piece's frame happened to run.
fn face_out(verts: Vertex[>..]&, indices: u32[>..]&, first_index: i64) {
    var i = first_index;
    while i < indices.len {
        let a = verts[indices[i] as i64];
        let b = verts[indices[i + 1] as i64];
        let c = verts[indices[i + 2] as i64];
        let f = cross(b.pos - a.pos, c.pos - a.pos);
        if dot(f, a.normal + b.normal + c.normal) < 0.0 {
            let t = indices[i + 1];
            indices[i + 1] = indices[i + 2];
            indices[i + 2] = t;
        }
        i += 3;
    }
}
