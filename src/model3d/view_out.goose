// The view out of the library's windows (task 109's layers, tools/materials/outside.py),
// built once in the room's frame (u along the window wall, right looking out; v into the
// room; surfaces.goose's): the sky, a sphere of directions round the eye, its colour
// worked out in the shader; the far tree line on a cylinder round the middle window; the
// oak, one quad facing it. One mesh in that order, as blending follows it
// (shaders::OUTSIDE_VERT and OUTSIDE_FRAG).
namespace view_out;
import std;
import vec;
import math;

let MAT_SKY:  f32 = 12.0;
let MAT_BAND: f32 = 13.0;
let MAT_OAK:  f32 = 14.0;

// The lawn a metre under the floor (task 109).
let LAWN_Y: f32 = surfaces::FLOOR_Y - surfaces::METRE;

// The sky's sphere: columns of 11.25° all round, rows of 15° from the nadir to the zenith.
let SKY_COLUMNS = 32;
let SKY_ROWS = 12;

// The tree line: a cylinder BAND_M round the middle window over ±BAND_AZ degrees, its
// picture's rows linear in height from BAND_LOW to BAND_TOP metres over the lawn (the
// baker's outside.txt).
let BAND_M:  f32 = 110.0;
let BAND_AZ: f32 = 64.0;
let BAND_SEGMENTS = 64;
let BAND_LOW: f32 = -14.05;
let BAND_TOP: f32 = 26.26;

// The oak: OAK_M out at OAK_AZ degrees right of straight out, OAK_W wide and OAK_H tall.
let OAK_M:  f32 = 70.0;
let OAK_AZ: f32 = 22.0;
let OAK_W:  f32 = 29.80;
let OAK_H:  f32 = 20.0;

// The pictures' sizes in texels (design/materials/outside_band.png, outside_oak.png).
let BAND_TEXELS = int2 { 2048, 336 };
let OAK_TEXELS = int2 { 584, 392 };

// The direction θ degrees right of straight out, in the room's u and v.
fn toward(theta: f32) -> float2 {
    let a = radians(theta);
    return float2 { sin(a), -cos(a) };
}

fn put(verts: mesh::Vertex[>..]&, p: float3, uv: float2, mat: f32) {
    verts.push(mesh::Vertex { p, float3_0, uv, 1.0, mat });
}

// The grid of `across` by `up` vertices from `first` as triangles.
fn grid(indices: u32[>..]&, first: i64, across: i64, up: i64) {
    for j in up - 1 {
        for i in across - 1 {
            let a = (first + j * across + i) as u32;
            let b = a + 1;
            let c = a + across as u32;
            let d = c + 1;
            indices.push(a);
            indices.push(c);
            indices.push(b);
            indices.push(b);
            indices.push(c);
            indices.push(d);
        }
    }
}

// The three layers round `centre`, the middle window's middle on the wall's inner face
// (u, v).
fn build(verts: mesh::Vertex[>..]&, indices: u32[>..]&, centre: float2) {
    let metre = surfaces::METRE;
    // The sky: each vertex its direction, which the vertex shader puts round the eye.
    var first = verts.len;
    for j in SKY_ROWS + 1 {
        let el = radians(-90.0 + 180.0 * (j as f32) / SKY_ROWS);
        for i in SKY_COLUMNS + 1 {
            let d = toward(-180.0 + 360.0 * i / SKY_COLUMNS);
            put(verts, float3 { d.x * cos(el), sin(el), d.y * cos(el) }, float2_0, MAT_SKY);
        }
    }
    grid(indices, first, SKY_COLUMNS + 1, SKY_ROWS + 1);
    // The tree line, its picture's top row first.
    first = verts.len;
    let r = BAND_M * metre;
    for j in 2 {
        let y = LAWN_Y + (if j == 0 { BAND_TOP } else { BAND_LOW }) * metre;
        for i in BAND_SEGMENTS + 1 {
            let k = i as f32 / BAND_SEGMENTS;
            let d = toward(-BAND_AZ + 2.0 * BAND_AZ * k);
            put(verts, float3 { centre.x + d.x * r, y, centre.y + d.y * r }, float2 { k, j }, MAT_BAND);
        }
    }
    grid(indices, first, BAND_SEGMENTS + 1, 2);
    // The oak, facing the window: its left as seen from the room at u 0.
    first = verts.len;
    let foot = centre + toward(OAK_AZ) * (OAK_M * metre);
    let side = toward(OAK_AZ + 90.0) * (0.5 * OAK_W * metre);
    for j in 2 {
        let y = LAWN_Y + (if j == 0 { OAK_H * metre } else { 0.0 });
        put(verts, float3 { foot.x - side.x, y, foot.y - side.y }, float2 { 0.0, j }, MAT_OAK);
        put(verts, float3 { foot.x + side.x, y, foot.y + side.y }, float2 { 1.0, j }, MAT_OAK);
    }
    grid(indices, first, 2, 2);
}

// The middle window's middle on the window wall's inner face in the room's frame.
fn centre_of(s: room_shell::Shell) -> float2 {
    var n = 0;
    var mid: f32 = s.table.x;
    for k in s.count {
        guard s.openings[k].kind == room_shell::WINDOW else { continue; }
        n++;
        if n == 2 { mid = s.openings[k].mid; }
    }
    return room_shell::room_of(s, float2 { mid, s.walls[room_shell::WINDOW_WALL].a.y });
}
