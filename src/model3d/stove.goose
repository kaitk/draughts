// The library's tiled stove (option A of build/notes/stove/, 2026-11-24): a pale celadon
// corner stove in the corner of the hall wall and the stove's end wall, fired from the hall,
// STOVE_GAP off both walls, its front corner cut. From the floor up: a tiled plinth with a
// torus; a lower body 3 cm proud with the warming niche's brass door on face A (toward the
// room's length); a band of rosette tiles under a cyma at the waist; the upper body, six rows
// of 22 × 24 cm tiles; a frieze of palmette tiles; the cornice; and the crown, a part of its
// own: A's crest of three palmettes.
// The tiles are not geometry: each face carries uv in metres along it and up, its tiles
// centred, and ROOM_FRAG's glaze (MAT_TILE) draws the joints, each tile's tilt and roll, and
// the relief from room_shell::stove_relief's atlas. Built once with the shell.
//
// Plan metres as shell.goose: x along the window wall from the stove's end, y from the hall
// wall. The stove's outline at an offset d out of its upper body runs from the hall wall's
// gap up face A (x = STOVE_SIDE + d), across the cut, and back along face B (y = STOVE_SIDE +
// d) to the end wall's gap, its two corners at the cut rounded STOVE_ROUND (a tile's roll).
namespace room_shell;
import std;
import vec;
import math;

let STOVE_GAP:     f32 = 0.06;
let STOVE_TILE_W:  f32 = 0.22;
let STOVE_TILE_H:  f32 = 0.24;
let STOVE_FACE:    f32 = 0.66;        // three tiles a side face
let STOVE_CHAMFER: f32 = 0.44;        // two across the cut
let STOVE_CUT:     f32 = 0.311127;    // the cut off each side, STOVE_CHAMFER / √2
let STOVE_SIDE:    f32 = 1.031127;    // the upper body's faces, STOVE_GAP + STOVE_FACE + STOVE_CUT
let STOVE_ROUND:   f32 = 0.015;
// Where the wainscot stops on both walls: 2 cm past the plinth's torus (its widest).
let STOVE_STOP: f32 = 1.13;
let STOVE_TOP:  f32 = 3.42;
// How far apart the faces' uv start, a whole number of tiles, so each face's tiles hash apart.
let STOVE_FACE_U: f32 = 11.0;

// The glaze's parts (ROOM_FRAG's MAT_TILE, the code in its material's fraction, eighths):
// a moulding (its vertical joints only), the lower and upper bodies' tiles, the rosette
// band's and the palmette frieze's tiles, a crest's palmette face, and bare glaze.
let GLAZE_MOULDING = 0;
let GLAZE_LOWER = 1;
let GLAZE_UPPER = 2;
let GLAZE_ROSETTE = 3;
let GLAZE_PALMETTE = 4;
let GLAZE_CREST = 5;
let GLAZE_BARE = 6;
fn glaze(code: i64) -> f32 { surfaces::MAT_TILE + (code + 0.5) / 8.0 }

// stove_on false leaves the stove out (the tuner's --stove off); the wainscot stops for it
// either way.
var stove_on = true;

// The profiles (metres out of the upper body's face, up from the floor), from
// build/notes/stove/src/gen.py: the plinth's torus, the waist's bead and cyma recta with its
// wash back to the upper body, the cornice's bead, cavetto, corona and cyma, and the crown's
// band.
let PLINTH_S: float2[13] = [
    float2 { 0.06, 0.0 }, float2 { 0.06, 0.07 }, float2 { 0.068, 0.075 }, float2 { 0.069, 0.0794 }, float2 { 0.0747, 0.0847 },
    float2 { 0.0777, 0.0919 }, float2 { 0.0774, 0.0997 }, float2 { 0.0738, 0.1066 }, float2 { 0.0676, 0.1113 },
    float2 { 0.06, 0.113 }, float2 { 0.045, 0.113 }, float2 { 0.045, 0.12 }, float2 { 0.03, 0.12 },
];
let CORNICE_S: float2[17] = [
    float2 { 0.01, 2.84 }, float2 { 0.025, 2.848 }, float2 { 0.025, 2.86 }, float2 { 0.0406, 2.8617 }, float2 { 0.0556, 2.8669 },
    float2 { 0.0694, 2.8752 }, float2 { 0.0816, 2.8864 }, float2 { 0.0915, 2.9 }, float2 { 0.0989, 2.9156 },
    float2 { 0.1035, 2.9324 }, float2 { 0.105, 2.95 }, float2 { 0.12, 2.955 }, float2 { 0.12, 3.0 }, float2 { 0.11, 3.01 },
    float2 { 0.09, 3.02 }, float2 { 0.03, 3.04 }, float2 { 0.02, 3.04 },
];

// A point of the outline: where it is in the plan, its normal there, and its u (metres
// along the face, scaled so the face holds its whole tiles, STOVE_FACE_U a face apart).
struct StovePoint { at: float2, normal: float2, u: f32 }

// The outline at offset d: ten points, the cut's two rounded corners each split at their
// middle, where one face's u ends and the next one's starts (STOVE_SEGMENTS joins them).
let STOVE_SEGMENTS: int2[7] = [int2 { 0, 1 }, int2 { 1, 2 }, int2 { 3, 4 }, int2 { 4, 5 }, int2 { 5, 6 }, int2 { 7, 8 }, int2 { 8, 9 }];
fn stove_outline(d: f32) -> StovePoint[10] {
    let side = STOVE_SIDE + d;
    let yc = STOVE_SIDE - STOVE_CUT + d * 0.414214;
    let len_a = yc - STOVE_GAP;
    let len_c = (side - yc) * 1.414214;
    let ka = STOVE_FACE / len_a;
    let kc = STOVE_CHAMFER / len_c;
    let r = STOVE_ROUND;
    let tp = r * 0.414214;
    let na = float2 { 1.0, 0.0 };
    let nc = float2 { 0.707107, 0.707107 };
    let nb = float2 { 0.0, 1.0 };
    let m1 = float2 { 0.92388, 0.382683 };
    let m2 = float2 { 0.382683, 0.92388 };
    let c1 = float2 { side, yc } - m1 * (r * 1.082392);
    let c2 = float2 { yc, side } - m2 * (r * 1.082392);
    return [
        StovePoint { float2 { side, STOVE_GAP }, na, 0.0 },
        StovePoint { c1 + na * r, na, (len_a - tp) * ka },
        StovePoint { c1 + m1 * r, m1, STOVE_FACE },
        StovePoint { c1 + m1 * r, m1, STOVE_FACE_U },
        StovePoint { c1 + nc * r, nc, STOVE_FACE_U + tp * kc },
        StovePoint { c2 + nc * r, nc, STOVE_FACE_U + (len_c - tp) * kc },
        StovePoint { c2 + m2 * r, m2, STOVE_FACE_U + STOVE_CHAMFER },
        StovePoint { c2 + m2 * r, m2, 2.0 * STOVE_FACE_U },
        StovePoint { c2 + nb * r, nb, 2.0 * STOVE_FACE_U + tp * ka },
        StovePoint { float2 { STOVE_GAP, side }, nb, 2.0 * STOVE_FACE_U + STOVE_FACE },
    ];
}

// A plan point at height h (metres) in the room's frame, and a plan normal turned up by
// `up` (its out and up parts).
fn stove_world(s: Shell, p: float2, h: f32) -> float3 {
    let r = room_of(s, p);
    return float3 { r.x, surfaces::FLOOR_Y + h * m(), r.y };
}
fn stove_normal(n: float2, out_up: float2) -> float3 { normalize(float3 { -n.x * out_up.x, out_up.y, -n.y * out_up.x }) }

// A band round the outline from offset da at height ha to dc at hc, each row's normal (out,
// up), occlusion and v (metres).
fn stove_band(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell, da: f32, ha: f32, na: float2, ao_a: f32, va: f32,
              dc: f32, hc: f32, nc: float2, ao_c: f32, vc: f32, mat: f32) {
    let pa = stove_outline(da);
    let pc = stove_outline(dc);
    for seg in STOVE_SEGMENTS {
        let base = verts.len as u32;
        let ends: i64[2] = [seg.x, seg.y];
        for e in ends {
            verts.push(mesh::Vertex { stove_world(s, pa[e].at, ha), stove_normal(pa[e].normal, na), float2 { pa[e].u, va }, ao_a, mat });
        }
        for k in 2 {
            let e = ends[1 - k];
            verts.push(mesh::Vertex { stove_world(s, pc[e].at, hc), stove_normal(pc[e].normal, nc), float2 { pc[e].u, vc }, ao_c, mat });
        }
        indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
}

// A tiled stage: the outline at d from h0 to h1, its v from 0 at h0, so its rows are whole.
fn stove_tiles(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell, d: f32, h0: f32, h1: f32, code: i64) {
    let out = float2 { 1.0, 0.0 };
    stove_band(verts, indices, s, d, h0, out, 0.95, 0.0, d, h1, out, 0.95, h1 - h0, glaze(code));
}

// A level ledge at h from offset d0 to d1, facing up (`up` 1) or down (-1).
fn stove_ledge(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell, d0: f32, d1: f32, h: f32, up: f32) {
    let n = float2 { 0.0, up };
    let ao: f32 = if up > 0.0 { 1.0 } else { 0.75 };
    stove_band(verts, indices, s, d0, h, n, ao, h, d1, h, n, ao, h, glaze(GLAZE_MOULDING));
}

// A profile's normal (out, up) on the segment from a to c.
fn profile_normal(a: float2, c: float2) -> float2 {
    let t = c - a;
    guard length(t) > 0.000001 else { return float2_0; }
    return normalize(float2 { t.y, -t.x });
}

// What a profile point's surface hides of the indirect light: under a soffit, near the floor.
fn stove_ao(n: float2, h: f32) -> f32 { (1.0 - 0.25 * max(-n.y, 0.0)) * (if h < 0.05 { 0.7 + 6.0 * h } else { 1.0 }) }

// A moulding: the profile swept round the outline, a point's normal its two segments' mean
// where they turn less than surfaces::CREASE (a torus, a cyma, a cavetto shade as curves).
fn stove_moulding(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell, prof: float2[]) {
    var flat: float2[..32] = [float2_0];
    for k in 1..prof.len { flat.push(profile_normal(prof[k - 1], prof[k])); }
    for k in 1..prof.len {
        let n = flat[k];
        guard length_sq(n) > 0.0 else { continue; }
        let na = if k > 1 { smooth2(n, flat[k - 1]) } else { n };
        let nc = if k + 1 < prof.len { smooth2(n, flat[k + 1]) } else { n };
        let a = prof[k - 1];
        let c = prof[k];
        stove_band(verts, indices, s, a.x, a.y, na, stove_ao(na, a.y), a.y, c.x, c.y, nc, stove_ao(nc, c.y), c.y,
                   glaze(GLAZE_MOULDING));
    }
}
fn smooth2(a: float2, c: float2) -> float2 {
    guard length_sq(c) > 0.0 && dot(a, c) > surfaces::CREASE else { return a; }
    return normalize(a + c);
}

// The waist: a bead and fillet over the rosette band, a cyma recta out to 7 cm, a fillet,
// its wash back to the upper body at `top` (gen.py's waist).
fn waist_profile(top: f32) -> float2[..24] {
    let z = top - 0.16;
    var out: float2[..24] = [float2 { 0.035, z + 0.08 }];
    for i in 5 {
        let a: f32 = (-90.0 + 45.0 * i) * PI / 180.0;
        out.push(float2 { 0.035 + 0.006 * cos(a), z + 0.086 + 0.006 * sin(a) });
    }
    out.push(float2 { 0.045, z + 0.092 });
    for t in 1..9 {
        let f: f32 = t / 8.0;
        out.push(float2 { 0.045 + 0.025 * (0.5 - 0.5 * cos(PI * f)), z + 0.092 + 0.043 * f });
    }
    out.push(float2 { 0.07, z + 0.148 });
    out.push(float2 { 0.06, z + 0.15 });
    out.push(float2 { 0.0, top });
    return out;
}

// A level cap over the outline at offset d at height h, to the walls' corner behind it.
fn stove_cap(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell, d: f32, h: f32) {
    let pts = stove_outline(d);
    let base = verts.len as u32;
    let up = float3 { 0.0, 1.0, 0.0 };
    let mat = glaze(GLAZE_BARE);
    verts.push(mesh::Vertex { stove_world(s, float2 { STOVE_GAP, STOVE_GAP }, h), up, float2_0, 1.0, mat });
    for p in pts { verts.push(mesh::Vertex { stove_world(s, p.at, h), up, float2 { p.u, 0.0 }, 1.0, mat }); }
    for i in 9 { indices.append([base, base + 1 + (i as u32), base + 2 + (i as u32)]); }
}

// A builder on the plan's point p, s along `along` and z out along `out` (plan directions).
fn plan_builder(s: Shell, p: float2, along: float2, out: float2) -> surfaces::Builder {
    return surfaces::Builder { room_of(s, p), float2 { -along.x, -along.y }, float2 { -out.x, -out.y } };
}

// A palmette plate of the crest standing on the outline's face at p (its middle, the
// upper body's face), `w` wide and `high` tall from h, 2 cm thick: gen.py's crest outline,
// five lobes, its front face the atlas's palmette (GLAZE_CREST, uv over its box), its edge
// round it. Not pierced yet.
fn crest_plate(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell, p: float2, along: float2, out: float2, h: f32,
               w: f32, high: f32) {
    let thick: f32 = 0.02;
    var outline: float2[17] = [float2_0; 17];
    for i in 17 {
        let a: f32 = PI * i / 16.0;
        let lobe = 0.55 + 0.45 * pow(abs(cos(4.5 * a)), 0.6 as f32);
        outline[i] = float2 { -cos(a) * 0.5 * w * (0.6 + 0.4 * lobe), sin(a) * high * lobe };
    }
    let front = p + out * thick;
    let n_front = stove_normal(out, float2 { 1.0, 0.0 });
    let face = glaze(GLAZE_CREST);
    let base = verts.len as u32;
    verts.push(mesh::Vertex { stove_world(s, front, h), n_front, float2 { 0.5, 0.0 }, 0.9, face });
    for q in outline {
        verts.push(mesh::Vertex { stove_world(s, front + along * q.x, h + q.y), n_front, float2 { q.x / w + 0.5, q.y / high }, 1.0, face });
    }
    for i in 16 { indices.append([base, base + 1 + (i as u32), base + 2 + (i as u32)]); }
    // The edge: each point's normal the mean of its two segments' in the plate's plane.
    let bare = glaze(GLAZE_BARE);
    for i in 16 {
        let a = outline[i];
        let c = outline[i + 1];
        let na = edge_normal(outline, i);
        let nc = edge_normal(outline, i + 1);
        let e = verts.len as u32;
        let ends: float2[2] = [a, c];
        let ns:   float2[2] = [na, nc];
        for k in 2 {
            let wn = stove_normal(along, float2 { ns[k].x, ns[k].y });
            verts.push(mesh::Vertex { stove_world(s, p + along * ends[k].x, h + ends[k].y), wn, float2 { ends[k].x, ends[k].y }, 0.9, bare });
            verts.push(mesh::Vertex { stove_world(s, front + along * ends[k].x, h + ends[k].y), wn, float2 { ends[k].x, ends[k].y }, 1.0, bare });
        }
        indices.append([e, e + 1, e + 3, e, e + 3, e + 2]);
    }
}
// The outward normal (along, up) of a plate's outline at its point i.
fn edge_normal(o: float2[17], i: i64) -> float2 {
    let a = o[max(i - 1, 0)];
    let c = o[min(i + 1, 16)];
    let t = c - a;
    guard length(t) > 0.000001 else { return float2 { 0.0, 1.0 }; }
    return normalize(float2 { -t.y, t.x });
}

// The crown over the cornice: the band (d 0.02, to 3.14 m) with its cap, then A's three
// palmette plates (the largest over the cut, 0.30 by 0.30 m, smaller ones over the side
// faces' middles; not yet pierced).
fn stove_crown_on(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell) {
    let top:  f32       = 3.14;
    let band: float2[2] = [float2 { 0.02, 3.04 }, float2 { 0.02, top }];
    stove_moulding(verts, indices, s, band[..]);
    stove_cap(verts, indices, s, 0.02, top);
    let side = STOVE_SIDE;
    let yc = STOVE_SIDE - STOVE_CUT;
    let mid_a = 0.5 * (STOVE_GAP + yc);
    crest_plate(verts, indices, s, float2 { 0.5 * (side + yc), 0.5 * (side + yc) }, float2 { -0.707107, 0.707107 },
                float2 { 0.707107, 0.707107 }, top, 0.30, 0.30);
    crest_plate(verts, indices, s, float2 { side, mid_a }, float2 { 0.0, 1.0 }, float2 { 1.0, 0.0 }, top, 0.16, 0.186);
    crest_plate(verts, indices, s, float2 { mid_a, side }, float2 { -1.0, 0.0 }, float2 { 0.0, 1.0 }, top, 0.16, 0.186);
}

// The warming niche's door on face A of the lower body, 0.30 m square from 0.36 m: a brass
// frame 1 cm proud round a plate, two hinge knuckles on the corner's side, a knob.
fn stove_door(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell) {
    let d: f32 = 0.03;
    let yc = STOVE_SIDE - STOVE_CUT + d * 0.414214;
    let b = plan_builder(s, float2 { STOVE_SIDE + d, STOVE_GAP }, float2 { 0.0, 1.0 }, float2 { 1.0, 0.0 });
    let mid = 0.5 * (yc - STOVE_GAP);
    let x0 = mid - 0.15;
    let x1 = mid + 0.15;
    let y0:  f32 = 0.36;
    let y1:  f32 = 0.66;
    let rim: f32 = 0.022;
    let brass = surfaces::MAT_BRASS;
    box_m(verts, indices, b, x0, x1, y0, y0 + rim, 0.0, 0.01, brass);
    box_m(verts, indices, b, x0, x1, y1 - rim, y1, 0.0, 0.01, brass);
    box_m(verts, indices, b, x0, x0 + rim, y0 + rim, y1 - rim, 0.0, 0.01, brass);
    box_m(verts, indices, b, x1 - rim, x1, y0 + rim, y1 - rim, 0.0, 0.01, brass);
    box_m(verts, indices, b, x0 + rim, x1 - rim, y0 + rim, y1 - rim, 0.0, 0.006, brass);
    // The hinges on the corner's side (+s), the knob toward the wall.
    knuckle(verts, indices, b, float3 { x1 + 0.004, y0 + 0.06, 0.008 }, 0.0055, 0.022, 8, true);
    knuckle(verts, indices, b, float3 { x1 + 0.004, y1 - 0.06, 0.008 }, 0.0055, 0.022, 8, true);
    box_m(verts, indices, b, x0 + 0.042, x0 + 0.05, 0.506, 0.514, 0.006, 0.02, brass);
    let knob: float2[5] = [float2 { 0.0, -0.011 }, float2 { 0.008, -0.008 }, float2 { 0.011, 0.0 }, float2 { 0.008, 0.008 },
                           float2 { 0.0, 0.011 }];
    lathe(verts, indices, b, float3 { x0 + 0.046, 0.51, 0.028 }, knob[..], 10, brass);
}

// The whole stove into the shell's mesh.
fn stove(verts: mesh::Vertex[>..]&, indices: u32[>..]&, s: Shell) {
    guard stove_on else { return; }
    stove_moulding(verts, indices, s, PLINTH_S[..]);
    stove_tiles(verts, indices, s, 0.03, 0.12, 1.08, GLAZE_LOWER);
    stove_ledge(verts, indices, s, 0.03, 0.035, 1.08, -1.0);
    stove_tiles(verts, indices, s, 0.035, 1.08, 1.16, GLAZE_ROSETTE);
    let waist = waist_profile(1.24);
    stove_moulding(verts, indices, s, waist[..]);
    stove_tiles(verts, indices, s, 0.0, 1.24, 2.68, GLAZE_UPPER);
    stove_ledge(verts, indices, s, 0.0, 0.01, 2.68, -1.0);
    stove_tiles(verts, indices, s, 0.01, 2.68, 2.84, GLAZE_PALMETTE);
    stove_moulding(verts, indices, s, CORNICE_S[..]);
    stove_crown_on(verts, indices, s);
    stove_door(verts, indices, s);
}

// The stove's reach along wall `wall` from its corner (metres): where the wainscot stops on
// the hall wall and the end wall, 0 on the others.
fn stove_reach(wall: i64) -> f32 { if wall == HALL_WALL || wall == STOVE_WALL { STOVE_STOP } else { 0.0 } }
