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
// The light tuner's park on the ground (--park): the lawn, and the trees' cards from
// MAT_CARD up, one material each so the shader finds its tint and place.
let MAT_LAWN: f32 = 15.0;
let MAT_CARD: f32 = 16.0;

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
// How soft the oak is put on the GPU (render3d::soften): a Gaussian's sigma in its texels,
// as out of focus as the band's trees look from the room (task 107's light round).
let OAK_SOFT: f32 = 3.5;

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

// The park on the ground, a look test of the light tuner's (--park, task 109): a lawn
// that holds perspective, from LAWN_NEAR metres out of the middle window's inner face to
// LAWN_FAR, LAWN_AZ degrees either side of straight out; its uv the place in metres from
// the middle window (x to the right looking out, y into the room), which
// shaders::PARK_FN shades. It runs on under the band to near the horizon, for any gap
// between its trunks; the band's blurred foot is replaced by its trunks drawn on down.
let LAWN_NEAR: f32 = 1.5;
let LAWN_FAR:  f32 = 1200.0;
let LAWN_AZ:   f32 = 85.0;
let LAWN_COLUMNS = 48;
let LAWN_ROWS = 40;

// The trees on the lawn: the oak's picture as cards fixed in the world, each facing the
// middle window: x degrees right of straight out, y metres out, z tall in metres, w its
// tint (PARK_FN's CARD_TINT). Drawn farthest first. The same table is PARK_FN's CARDS:
// keep the two equal.
let PARK_CARDS = 7;
let PARK_TREES: float4[PARK_CARDS] = [
    float4 { 6.0, 100.0, 16.0, 2.0 },
    float4 { -18.0, 88.0, 18.0, 1.0 },
    float4 { 22.0, 70.0, 20.0, 0.0 },
    float4 { 40.0, 48.0, 16.0, 3.0 },
    float4 { -6.0, 50.0, 12.0, 4.0 },
    float4 { 30.0, 30.0, 10.0, 5.0 },
    float4 { -40.0, 18.0, 13.0, 6.0 },
];
// The oak's picture: its trunk's foot this share of its height over the picture's foot.
let CARD_SINK: f32 = 0.03;

// The three layers round `centre`, the middle window's middle on the wall's inner face
// (u, v); with `park` the lawn between the sky and the band, and the cards in place of
// the oak. Returns how many indices the far layers take (the sky, the lawn and the band),
// which the near trees' pictures follow: drawn alone where the maple is geometry.
fn build(verts: mesh::Vertex[>..]&, indices: u32[>..]&, centre: float2, park: bool = false) -> i64 {
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
    if park { lawn(verts, indices, centre); }
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
    let far = indices.len;
    if park {
        for t, k in PARK_TREES {
            card(verts, indices, centre, t.x, t.y, t.z, MAT_CARD + k);
        }
        return far;
    }
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
    return far;
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

// The lawn's grid: columns across LAWN_AZ either side, rows out from the wall's line to
// LAWN_FAR, spaced geometrically so the far rows are no thinner on screen than the near.
fn lawn(verts: mesh::Vertex[>..]&, indices: u32[>..]&, centre: float2) {
    let metre = surfaces::METRE;
    let first = verts.len;
    for j in LAWN_ROWS + 1 {
        let k = j as f32 / LAWN_ROWS;
        for i in LAWN_COLUMNS + 1 {
            let theta = -LAWN_AZ + 2.0 * LAWN_AZ * i / LAWN_COLUMNS;
            let d = toward(theta);
            let near = LAWN_NEAR / -d.y;
            let r = near * pow(LAWN_FAR / near, k);
            let at = d * r;
            put(verts, float3 { centre.x + at.x * metre, LAWN_Y, centre.y + at.y * metre }, at, MAT_LAWN);
        }
    }
    grid(indices, first, LAWN_COLUMNS + 1, LAWN_ROWS + 1);
}

// One tree's card `theta` degrees right of straight out, `out` metres, `tall` metres high,
// facing the middle window, its trunk's foot on the lawn.
fn card(verts: mesh::Vertex[>..]&, indices: u32[>..]&, centre: float2, theta: f32, out: f32, tall: f32, mat: f32) {
    let metre = surfaces::METRE;
    let first = verts.len;
    let foot = centre + toward(theta) * (out * metre);
    let side = toward(theta + 90.0) * (0.5 * tall * OAK_W / OAK_H * metre);
    for j in 2 {
        let y = LAWN_Y + ((if j == 0 { tall } else { 0.0 }) - CARD_SINK * tall) * metre;
        put(verts, float3 { foot.x - side.x, y, foot.y - side.y }, float2 { 0.0, j }, mat);
        put(verts, float3 { foot.x + side.x, y, foot.y + side.y }, float2 { 1.0, j }, mat);
    }
    grid(indices, first, 2, 2);
}
