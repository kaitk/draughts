// A path tracer of the library room on the CPU: the reference the room's light is checked
// against. Every triangle of the shell, the window's glass and lace, the games table and
// its two chairs, made by model3d as the light tuner makes them at its default placement
// (the sun at azimuth 0 and 15 degrees up, the window wall turned 12 degrees, the table 25,
// the chairs on the rug; the sun as --light physical's autumn, room_scene::sun_take). Lambertian surfaces with room_light's albedos; the sun by a
// shadow ray at every hit toward a point of its disc (0.53 degrees across, as Cycles'),
// through the panes and the lace; the sky's radiance for a ray leaving through a window's
// outer opening, past both casements (their panes, frames and bars); up to 10 bounces. The
// inputs are physical, as in tools/blender/scene.py's Cycles scene: no bounce gain, no caps,
// each pane passing 0.92, the lace a sheet passing 0.72 whose thread throws 0.4 of the light
// it stops on each side, from the light reaching both its sides; no tree. The casements'
// backs, which the room's mesh leaves out, are closed (room_scene::casement_backs; --backs off
// leaves them open).
// Light is "over pi", the shaders' units: the irradiance on a white surface divided by pi.
//
//   goose build -o build/path_trace tools/path_trace.goose          (from the repository's root)
//   build/path_trace points [--samples 4096] [--backs on|off] [--sun-clear] [--box-window on|off (task 127's
//       window; off window B)]
//   build/path_trace picture VIEW [--size 480x270] [--samples 64] [--light] [--exposure EV (1.4)] [--backs on|off]
//       [--out build/path_traced/VIEW] [--sun-clear]
// --sun-clear: the clear sky's sun at its own height's colour, as before the autumn haze.
//
// points: named points on the chairs and the table, each its height, the light without the
// sun's own (rgb) and the sun's own (rgb). picture: a view of tools/room_scene.goose's
// (close, low, front, ...) on all cores, as OUT.exr (linear, what the camera sees, or the
// light alone with --light) and OUT.png (times 2^EV, clipped, sRGB); and the light alone on
// the props' pixels by part and the way each faces, as tools/blender/scene.py gives Cycles'.
import std;
import os;
import vec;
import math;
import binary;
import model3d from "../src/model3d";
import .room_scene;

let M:   f32 = 30.48;        // surfaces::METRE
let EPS: f32 = 0.004;        // a ray's start off its surface, world units
let MAX_DEPTH = 10;
let PANE:      f32 = 0.92;
let LACE_LETS: f32 = 0.72;   // room_light::LACE_LETS

// The casements' backs, which the room's mesh leaves out (room_scene::casement_backs; --backs off).
var casement_backs = true;

// The room's placement and light (the tuner's defaults).
var table_at = float2 { 4.4, 5.8 };
var axes = float4_0;         // the room's frame in the board's world
var toward_sun = float3_0;
var sun_light = float3_0;
var sky = float3_0;          // the sky's radiance outside
// The windows' outer openings in the plan's metres, as the Cycles scene's box has them: the
// window wall's outer face (1 cm out), the three openings' middles, their half width, sill
// and top.
var outer_y: f32 = 0.0;
var opening_x = float3_0;
var opening = float3_0;

// Every triangle: its shape, its mesh (SHELL, GLASS, PROPS), its material (the mesh's
// mat), its corners' normals.
let SHELL = 0;
let GLASS = 1;
let PROPS = 2;
struct Tri { a: float3, ab: float3, ac: float3 }
var tris:   Tri[>..]    = [];
var kind:   i64[>..]    = [];
var mat:    f32[>..]    = [];
var nrm:    float3[>..] = [];   // 3 a triangle
var tested: u32[>..]    = [];   // the last ray that tested the triangle
var ray_id: u32         = 0;

// The props' vertices as made (the board's world), for choosing the points.
var pv_pos:      float3[>..] = [];
var pv_n:        float3[>..] = [];
var pv_mat:      f32[>..]    = [];
var pv_ao:       f32[>..]    = [];
var table_verts: i64         = 0;

// Two uniform grids of triangle lists: the props' fine, the room's coarse.
struct Grid { lo: float3, cell: f32, nx: i64, ny: i64, nz: i64, f0: i64, l0: i64 }
var firsts: u32[>..] = [];
var lists:  u32[>..] = [];
var grid_props = Grid { float3_0, 1.0, 0, 0, 0, 0, 0 };
var grid_room = Grid { float3_0, 1.0, 0, 0, 0, 0, 0 };

// The nearest hit's triangle (-1 none) and barycentrics.
var hit_tri:     i64 = -1;
var hit_u:       f32 = 0.0;
var hit_v:       f32 = 0.0;
var escapes:     i64 = 0;    // paths that left through a gap in the shell
var unknown_mat: i64 = 0;

var rng: u64 = 0x9E3779B97F4A7C15;
fn rnd() -> f32 {
    rng ^= rng << 13;
    rng ^= rng >> 7;
    rng ^= rng << 17;
    return (rng >> 40) / 16777216.0;
}
fn seed(n: u64) {
    rng = (n + 1) * 0x9E3779B97F4A7C15;
    for i in 4 { rnd(); }
}

// The room's frame (ROOM_VERT's v_local) and the board's world; the plan's metres.
fn to_world(p: float3) -> float3 { float3 { axes.x * p.x + axes.z * p.z, p.y, axes.y * p.x + axes.w * p.z } }
fn to_room(p: float3) -> float3 { float3 { axes.x * p.x + axes.y * p.z, p.y, axes.z * p.x + axes.w * p.z } }
fn from_plan(q: float3) -> float3 {
    to_world(float3 { (table_at.x - q.x) * M, surfaces::FLOOR_Y + q.z * M, (table_at.y - q.y) * M })
}
fn to_plan(p: float3) -> float3 {
    let r = to_room(p);
    return float3 { table_at.x - r.x / M, table_at.y - r.z / M, (r.y - surfaces::FLOOR_Y) / M };
}

// Whether a ray from o along d that meets nothing leaves through a window's outer opening (to
// the sky) and not through a gap in the shell (dark).
fn to_sky(o: float3, d: float3) -> bool {
    let p = to_plan(o);
    guard p.y < outer_y else { return true; }
    let v = to_plan(o + d) - p;
    guard v.y > 1e-6 else { return false; }
    let q = p + v * ((outer_y - p.y) / v.y);
    guard q.z > opening.y && q.z < opening.z else { return false; }
    return abs(q.x - opening_x.x) < opening.x || abs(q.x - opening_x.y) < opening.x || abs(q.x - opening_x.z) < opening.x;
}

// ---- the scene

fn add_mesh(verts: mesh::Vertex[>..]&, indices: u32[>..]&, which: i64) {
    for k in indices.len / 3 {
        let v0 = verts[indices[3 * k] as i64];
        let v1 = verts[indices[3 * k + 1] as i64];
        let v2 = verts[indices[3 * k + 2] as i64];
        tris.push(Tri { v0.pos, v1.pos - v0.pos, v2.pos - v0.pos });
        kind.push(which);
        mat.push(v0.mat);
        nrm.push(v0.normal);
        nrm.push(v1.normal);
        nrm.push(v2.normal);
        tested.push(0);
    }
}

fn build_scene() {
    let light = room_scene::light_of(float2 { 0.0, 15.0 }, 12.0);
    axes = light.axes;
    toward_sun = light.toward;
    sun_light = light.sun;
    sky = light.sky * rooms::AUTUMN.baked.x;
    room_shell::hang_lace(room_shell::LACE_HANG);
    room_shell::LIBRARY.table = table_at;
    let wall = room_shell::LIBRARY.walls[room_shell::WINDOW_WALL];
    outer_y = wall.a.y + wall.thick + 0.01;
    opening_x = room_light::window_mids();
    let o = room_shell::window_at(opening_x.x);
    opening = float3 { 0.5 * room_shell::WINDOW_GLASS.w, o.sill, o.sill + o.height + o.rise };

    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    var glass:   mesh::Vertex[>..] = [];
    var gi:      u32[>..]          = [];
    room_shell::build(verts, indices, glass, gi, room_shell::LIBRARY, true);
    if casement_backs { room_scene::casement_backs(verts, indices); }
    for &v in verts {
        v.pos = to_world(v.pos);
        v.normal = to_world(v.normal);
    }
    for &v in glass {
        v.pos = to_world(v.pos);
        v.normal = to_world(v.normal);
    }
    add_mesh(verts, indices, SHELL);
    add_mesh(glass, gi, GLASS);

    // The table turned about its middle, the chairs on the rug (render3d::CHAIR_RUG_LIFT).
    var pv: mesh::Vertex[>..] = [];
    var pi: u32[>..]          = [];
    mesh::table(pv, pi, float4 { 3.0, 0.9, 0.38, 1.4 }, mesh::TABLE_R, surfaces::FLOOR_Y);
    let turn: f32 = 25.0;
    let a = radians(turn);
    let c = cos(a);
    let s = sin(a);
    for &v in pv {
        let x = v.pos.x;
        let z = v.pos.z - mesh::TABLE_Z;
        v.pos.x = c * x - s * z;
        v.pos.z = s * x + c * z + mesh::TABLE_Z;
        let nx = v.normal.x;
        v.normal.x = c * nx - s * v.normal.z;
        v.normal.z = s * nx + c * v.normal.z;
    }
    table_verts = pv.len;
    mesh::chairs(pv, pi, surfaces::FLOOR_Y + 0.008 * M);
    for v in pv {
        pv_pos.push(v.pos);
        pv_n.push(v.normal);
        pv_mat.push(v.mat);
        pv_ao.push(v.ao);
    }
    add_mesh(pv, pi, PROPS);

    fill_grid(grid_props, 0.5, true);
    fill_grid(grid_room, 4.0, false);
}

// The grid over the props' triangles (props) or the rest's, cells `cell` world units wide.
fn fill_grid(g: Grid&, cell: f32, props: bool) {
    var lo = float3 { 1e9, 1e9, 1e9 };
    var hi = float3 { -1e9, -1e9, -1e9 };
    for t, k in tris {
        guard (kind[k] == PROPS) == props else { continue; }
        for p in [t.a, t.a + t.ab, t.a + t.ac] {
            lo = float3 { min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z) };
            hi = float3 { max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z) };
        }
    }
    lo = lo - float3 { cell, cell, cell };
    hi = hi + float3 { cell, cell, cell };
    g.lo = lo;
    g.cell = cell;
    g.nx = ceil((hi.x - lo.x) / cell) as i64;
    g.ny = ceil((hi.y - lo.y) / cell) as i64;
    g.nz = ceil((hi.z - lo.z) / cell) as i64;
    let cells = g.nx * g.ny * g.nz;
    g.f0 = firsts.len;
    g.l0 = lists.len;
    for i in cells + 1 { firsts.push(0); }
    // Two passes: count each cell's triangles, then place them.
    var filled: u32[>..] = [];
    for pass in 2 {
        if pass == 1 {
            for i in cells { firsts[g.f0 + i + 1] += firsts[g.f0 + i]; }
            for i in firsts[g.f0 + cells] as i64 { lists.push(0); }
            for i in cells { filled.push(firsts[g.f0 + i]); }
        }
        for t, k in tris {
            guard (kind[k] == PROPS) == props else { continue; }
            let b = t.a + t.ab;
            let c = t.a + t.ac;
            let tl = (float3 { min(t.a.x, min(b.x, c.x)), min(t.a.y, min(b.y, c.y)), min(t.a.z, min(b.z, c.z)) } - lo) / cell;
            let th = (float3 { max(t.a.x, max(b.x, c.x)), max(t.a.y, max(b.y, c.y)), max(t.a.z, max(b.z, c.z)) } - lo) / cell;
            for z in clamp(tl.z as i64, 0, g.nz - 1)..clamp(th.z as i64, 0, g.nz - 1) + 1 {
                for y in clamp(tl.y as i64, 0, g.ny - 1)..clamp(th.y as i64, 0, g.ny - 1) + 1 {
                    for x in clamp(tl.x as i64, 0, g.nx - 1)..clamp(th.x as i64, 0, g.nx - 1) + 1 {
                        let ci = (z * g.ny + y) * g.nx + x;
                        if pass == 0 {
                            firsts[g.f0 + ci + 1] += 1;
                        } else {
                            lists[g.l0 + filled[ci]] = k as u32;
                            filled[ci] += 1;
                        }
                    }
                }
            }
        }
    }
}

// ---- rays

// The distance to triangle k along d if nearer than far (hit_* set), else far.
fn hit(k: i64, o: float3, d: float3, far: f32) -> f32 {
    let t = tris[k];
    let p = cross(d, t.ac);
    let det = dot(t.ab, p);
    guard abs(det) > 1e-14 else { return far; }
    let inv = 1.0 / det;
    let s = o - t.a;
    let u = dot(s, p) * inv;
    guard u >= 0.0 && u <= 1.0 else { return far; }
    let q = cross(s, t.ab);
    let v = dot(d, q) * inv;
    guard v >= 0.0 && u + v <= 1.0 else { return far; }
    let at = dot(t.ac, q) * inv;
    guard at > 1e-5 && at < far else { return far; }
    hit_tri = k;
    hit_u = u;
    hit_v = v;
    return at;
}

// The nearest hit in one grid, walking its cells along the ray (3D DDA).
fn march(g: Grid&, o: float3, d: float3, far: f32) -> f32 {
    let hi = g.lo + float3 { g.nx, g.ny, g.nz } * g.cell;
    var t0: f32 = 0.0;
    var t1: f32 = far;
    for a in 3 {
        let oa = if a == 0 { o.x } else if a == 1 { o.y } else { o.z };
        let da = if a == 0 { d.x } else if a == 1 { d.y } else { d.z };
        let la = if a == 0 { g.lo.x } else if a == 1 { g.lo.y } else { g.lo.z };
        let ha = if a == 0 { hi.x } else if a == 1 { hi.y } else { hi.z };
        if abs(da) < 1e-12 {
            guard oa >= la && oa <= ha else { return far; }
        } else {
            var ta = (la - oa) / da;
            var tb = (ha - oa) / da;
            if ta > tb {
                let s = ta;
                ta = tb;
                tb = s;
            }
            t0 = max(t0, ta);
            t1 = min(t1, tb);
        }
    }
    guard t0 <= t1 else { return far; }
    let gp = (o + d * t0 - g.lo) / g.cell;
    var x = clamp(floor(gp.x) as i64, 0, g.nx - 1);
    var y = clamp(floor(gp.y) as i64, 0, g.ny - 1);
    var z = clamp(floor(gp.z) as i64, 0, g.nz - 1);
    let big: f32 = 1e30;
    let sx:  i64 = if d.x > 0.0 { 1 } else { -1 };
    let sy:  i64 = if d.y > 0.0 { 1 } else { -1 };
    let sz:  i64 = if d.z > 0.0 { 1 } else { -1 };
    let dx = if abs(d.x) > 1e-12 { g.cell / abs(d.x) } else { big };
    let dy = if abs(d.y) > 1e-12 { g.cell / abs(d.y) } else { big };
    let dz = if abs(d.z) > 1e-12 { g.cell / abs(d.z) } else { big };
    var tx = if abs(d.x) > 1e-12 { t0 + ((if d.x > 0.0 { (x + 1) as f32 } else { x as f32 }) - gp.x) * g.cell / d.x } else { big };
    var ty = if abs(d.y) > 1e-12 { t0 + ((if d.y > 0.0 { (y + 1) as f32 } else { y as f32 }) - gp.y) * g.cell / d.y } else { big };
    var tz = if abs(d.z) > 1e-12 { t0 + ((if d.z > 0.0 { (z + 1) as f32 } else { z as f32 }) - gp.z) * g.cell / d.z } else { big };
    ray_id += 1;
    var best = far;
    while true {
        let c = (z * g.ny + y) * g.nx + x;
        let j0 = firsts[g.f0 + c] as i64;
        let j1 = firsts[g.f0 + c + 1] as i64;
        for j in j0..j1 {
            let k = lists[g.l0 + j] as i64;
            guard tested[k] != ray_id else { continue; }
            tested[k] = ray_id;
            best = hit(k, o, d, best);
        }
        let exit = min(tx, min(ty, tz));
        guard best > exit && exit < far else { break; }
        if tx <= ty && tx <= tz {
            x += sx;
            tx += dx;
            guard x >= 0 && x < g.nx else { break; }
        } else if ty <= tz {
            y += sy;
            ty += dy;
            guard y >= 0 && y < g.ny else { break; }
        } else {
            z += sz;
            tz += dz;
            guard z >= 0 && z < g.nz else { break; }
        }
    }
    return best;
}

// The nearest hit in the scene, hit_tri set (-1 none).
fn nearest(o: float3, d: float3) -> f32 {
    hit_tri = -1;
    let t = march(grid_props, o, d, 1e9);
    let k = hit_tri;
    let u = hit_u;
    let v = hit_v;
    let t2 = march(grid_room, o, d, t);
    guard t2 < t else {
        hit_tri = k;
        hit_u = u;
        hit_v = v;
        return t;
    }
    return t2;
}

// ---- materials

// The chairs' are tools/blender/scene.py's: their wood the table's albedo a quarter toward
// grey times 0.6, the cloth's its picture's mean in linear light (the tapestry times 0.8),
// the braid times 0.85. The rug's is room_light's.
let CHAIR_WOOD = float3 { 0.0647, 0.0377, 0.0266 };
let TAPESTRY = float3 { 0.413, 0.272, 0.168 };
let BRAID = float3 { 0.323, 0.247, 0.128 };
let BRASS = float3 { 0.4, 0.3, 0.15 };        // a diffuse stand-in for the metal
let CORD = float3 { 0.5, 0.45, 0.4 };

fn albedo(k: i64, p: float3, n: float3) -> float3 {
    let m = floor(mat[k] + 0.001);
    if kind[k] == PROPS {
        if m < mesh::MAT_CHAIR - 0.5 { return room_light::TABLE_ALBEDO; }
        if m < mesh::MAT_SEAT - 0.5 { return CHAIR_WOOD; }
        if m < mesh::MAT_TRIM - 0.5 { return TAPESTRY; }
        return BRAID;
    }
    if m == surfaces::MAT_FLOOR {
        // The rug (room_light::RUG_HALF), along the window wall round the table.
        let r = to_room(p) / M;
        if abs(r.x) < room_light::RUG_HALF.x && abs(r.z - room_light::RUG_IN) < room_light::RUG_HALF.y { return room_light::RUG_ALBEDO; }
        return room_light::FLOOR_ALBEDO;
    }
    if m == surfaces::MAT_OAK { return room_light::OAK_ALBEDO; }
    if m == surfaces::MAT_PAPER { return room_light::PAPER_ALBEDO; }
    if m == surfaces::MAT_STONE { return room_light::STONE_ALBEDO; }
    if m == surfaces::MAT_PLASTER || m == surfaces::MAT_PAINT {
        // The ceiling: facing down, high up.
        if n.y < -0.9 && (p.y - surfaces::FLOOR_Y) / M > 2.5 { return room_light::CEILING_ALBEDO; }
        return if m == surfaces::MAT_PAINT { room_light::PAINT_ALBEDO } else { room_light::PLASTER_ALBEDO };
    }
    if m == surfaces::MAT_TILE { return room_light::STOVE_ALBEDO; }
    if m == surfaces::MAT_BOOK { return room_light::CASE_ALBEDO; }
    if m == surfaces::MAT_BRASS { return BRASS; }
    if m == surfaces::MAT_CORD { return CORD; }
    unknown_mat += 1;
    return float3 { 0.2, 0.2, 0.2 };
}
fn is_lace(k: i64) -> bool { kind[k] == GLASS && floor(mat[k] + 0.001) == surfaces::MAT_LACE }

fn face_normal(k: i64) -> float3 { normalize(cross(tris[k].ab, tris[k].ac)) }
fn smooth_normal(k: i64) -> float3 {
    normalize(nrm[3 * k] * (1.0 - hit_u - hit_v) + nrm[3 * k + 1] * hit_u + nrm[3 * k + 2] * hit_v)
}

// ---- light

// The share of the sun reaching o through the panes and the lace; 0 where anything opaque
// is in the way, or where the ray leaves through a gap in the shell.
fn sun_through(o0: float3) -> f32 {
    var o = o0;
    var through: f32 = 1.0;
    let d = sun_ray();
    for step in 24 {
        let t = nearest(o, d);
        guard hit_tri >= 0 else { return if to_sky(o, d) { through } else { 0.0 }; }
        guard kind[hit_tri] == GLASS else { return 0.0; }
        through *= if is_lace(hit_tri) { LACE_LETS } else { PANE };
        o = o + d * (t + EPS);
    }
    return 0.0;
}

// The sun's angular radius (0.2666 degrees): a shadow ray goes to a point of its disc,
// uniformly, so the edges of a shadow are as soft as the real sun's.
let SUN_RADIUS: f32 = 0.004653;
fn sun_ray() -> float3 {
    let side = if abs(toward_sun.y) < 0.9 { float3 { 0.0, 1.0, 0.0 } } else { float3 { 1.0, 0.0, 0.0 } };
    let tx = normalize(cross(side, toward_sun));
    let ty = cross(toward_sun, tx);
    let r = SUN_RADIUS * sqrt(rnd());
    let phi = TAU * rnd();
    return normalize(toward_sun + tx * (r * cos(phi)) + ty * (r * sin(phi)));
}

// The sun's own light on a surface at p facing n, over pi.
fn sun_direct(p: float3, n: float3) -> float3 {
    let c = dot(n, toward_sun);
    guard c > 0.0 else { return float3_0; }
    return sun_light * (c * sun_through(p + n * EPS) / PI);
}

// A ray meeting the lace passes its open part (LACE_LETS of the sheet) or meets its thread,
// picked at random by those shares. The thread, as Cycles' lace, throws LACE_SCATTER of the
// light reaching either side on through it and as much back, so the light off it at p is the
// same toward both sides. The light reaching it: the sun's, and one traced ray to a side
// picked at random, counted twice.
recursive fn off_thread(p: float3, k: i64, depth: i64) -> float3 {
    let n = face_normal(k);
    let c = abs(dot(n, toward_sun));
    var e = sun_light * (c * sun_through(p + toward_sun * EPS) / PI);
    if depth < MAX_DEPTH {
        let side = if rnd() < 0.5 { n } else { float3_0 - n };
        e = e + radiance(p + side * EPS, cosine_dir(side), depth + 1) * 2.0;
    }
    return e * room_light::LACE_SCATTER;
}

fn cosine_dir(n: float3) -> float3 {
    let u1 = rnd();
    let u2 = rnd();
    let r = sqrt(u1);
    let phi = TAU * u2;
    let side = if abs(n.y) < 0.9 { float3 { 0.0, 1.0, 0.0 } } else { float3 { 1.0, 0.0, 0.0 } };
    let tx = normalize(cross(side, n));
    let ty = cross(n, tx);
    return tx * (r * cos(phi)) + ty * (r * sin(phi)) + n * sqrt(max(1.0 - u1, 0.0));
}

// The radiance arriving at o from direction d; depth 1 is the first bounce.
recursive fn radiance(o0: float3, d: float3, depth: i64) -> float3 {
    var o = o0;
    var through: f32 = 1.0;
    for step in 24 {
        let t = nearest(o, d);
        guard hit_tri >= 0 else {
            if to_sky(o, d) { return sky * through; }
            escapes += 1;
            return float3_0;
        }
        let k = hit_tri;
        let p = o + d * t;
        if kind[k] == GLASS {
            if !is_lace(k) {
                through *= PANE;
            } else if rnd() >= LACE_LETS {
                return off_thread(p, k, depth) * through;
            }
            o = p + d * EPS;
            continue;
        }
        var n = face_normal(k);
        if dot(n, d) > 0.0 { n = float3_0 - n; }
        let a = albedo(k, p, n);
        let lit = a * sun_direct(p, n);
        guard depth < MAX_DEPTH else { return lit * through; }
        // Russian roulette from the third bounce.
        var keep: f32 = 1.0;
        if depth >= 3 {
            keep = clamp(max(a.x, max(a.y, a.z)), 0.05, 0.95);
            if rnd() > keep { return lit * through; }
        }
        let more = radiance(p + n * EPS, cosine_dir(n), depth + 1);
        return (lit + a * more * (1.0 / keep)) * through;
    }
    return float3_0;
}

// The light on p facing n without the sun's own, over pi: the mean radiance over a
// cosine-weighted hemisphere.
fn light_at(p: float3, n: float3, samples: i64) -> float3 {
    var sum = float3_0;
    for s in samples { sum = sum + radiance(p + n * EPS, cosine_dir(n), 1); }
    return sum * (1.0 / samples);
}

fn lum(v: float3) -> f32 { 0.2126 * v.x + 0.7152 * v.y + 0.0722 * v.z }
fn put3(out: u8[>..]&, v: float3) { format(out, v.x, " ", v.y, " ", v.z); }

// ---- points

struct Point { name: u8[..64], v: i64 }
var points:     Point[>..] = [];
var best_v:     i64        = -1;
var best_score: f32        = -1e9;

// The props' vertex with the best score offered is the point `name`.
fn offer(i: i64, score: f32) {
    if score > best_score {
        best_score = score;
        best_v = i;
    }
}
fn take(name: const u8[:]) {
    if best_v >= 0 {
        var nm: u8[..64] = [];
        nm.append(name);
        points.push(Point { nm, best_v });
    } else {
        print("no vertex for ", name);
    }
    best_v = -1;
    best_score = -1e9;
}

// A world point in chair k's own frame (millimetres, +z its front), and a direction.
fn chair_local(k: i64, p: float3) -> float3 {
    let at = mesh::CHAIRS[k];
    let dx = p.x - at.x;
    let dz = p.z - at.y;
    return float3 { (at.w * dx - at.z * dz) / mesh::CHAIR_MM, (p.y - surfaces::FLOOR_Y) / mesh::CHAIR_MM, (at.z * dx + at.w * dz) / mesh::CHAIR_MM };
}
fn chair_dir(k: i64, n: float3) -> float3 {
    let at = mesh::CHAIRS[k];
    return float3 { at.w * n.x - at.z * n.z, n.y, at.z * n.x + at.w * n.z };
}

// Task 120's points: on each chair the back's pads, the seat and the apron; on the table
// the column, a foot and the top's underside. The rims' points are where the chairs' own
// darkening at the rim (the vertex's ao) has a given value.
fn choose_points() {
    let window = float3_0 - to_world(float3 { 0.0, 0.0, 1.0 });   // the room's -z
    let per_chair = (pv_pos.len - table_verts) / 2;
    for ch in 2 {
        let from = table_verts + ch * per_chair;
        let to = from + per_chair;
        let tag = if ch == 0 { "chair0 " } else { "chair1 " };
        for i in from..to {
            guard pv_mat[i] == mesh::MAT_SEAT else { continue; }
            let q = chair_local(ch, pv_pos[i]);
            let n = chair_dir(ch, pv_n[i]);
            if q.y > 650.0 && n.z > 0.0 { offer(i, n.z * 2.0 - abs(q.x) / 100.0 - abs(q.y - 760.0) / 100.0); }
        }
        take(str(tag, "back front pad, centre")[..]);
        for i in from..to {
            guard pv_mat[i] == mesh::MAT_SEAT else { continue; }
            let q = chair_local(ch, pv_pos[i]);
            let n = chair_dir(ch, pv_n[i]);
            if q.y > 650.0 && q.y < 850.0 && n.z > 0.2 && pv_ao[i] > 0.55 && pv_ao[i] < 0.62 { offer(i, q.x); }
        }
        take(str(tag, "back front pad, 15 mm from its rim (side)")[..]);
        for i in from..to {
            guard pv_mat[i] == mesh::MAT_SEAT else { continue; }
            let q = chair_local(ch, pv_pos[i]);
            let n = chair_dir(ch, pv_n[i]);
            if q.y > 650.0 && n.z < 0.0 { offer(i, -n.z * 2.0 - abs(q.x) / 100.0 - abs(q.y - 760.0) / 100.0); }
        }
        take(str(tag, "back rear pad, centre")[..]);
        for i in from..to {
            guard pv_mat[i] == mesh::MAT_SEAT else { continue; }
            let q = chair_local(ch, pv_pos[i]);
            let n = chair_dir(ch, pv_n[i]);
            if q.y > 650.0 && q.y < 850.0 && n.z < -0.2 && pv_ao[i] > 0.55 && pv_ao[i] < 0.65 { offer(i, q.x); }
        }
        take(str(tag, "back rear pad, 12 mm from its rim (side)")[..]);
        for i in from..to {
            guard pv_mat[i] == mesh::MAT_SEAT else { continue; }
            let q = chair_local(ch, pv_pos[i]);
            let n = chair_dir(ch, pv_n[i]);
            if q.y < 520.0 && n.y > 0.9 { offer(i, -q.z - abs(q.x)); }
        }
        take(str(tag, "seat top, under the back")[..]);
        for i in from..to {
            guard pv_mat[i] == mesh::MAT_SEAT else { continue; }
            let q = chair_local(ch, pv_pos[i]);
            let n = chair_dir(ch, pv_n[i]);
            if q.y < 520.0 && n.y > 0.9 { offer(i, -abs(q.z - 40.0) - abs(q.x)); }
        }
        take(str(tag, "seat top, middle")[..]);
        for i in from..to {
            guard pv_mat[i] == mesh::MAT_SEAT else { continue; }
            let q = chair_local(ch, pv_pos[i]);
            let n = chair_dir(ch, pv_n[i]);
            if q.y < 520.0 && n.z > 0.8 && abs(q.x) < 60.0 { offer(i, n.z - abs(q.y - 420.0) / 50.0); }
        }
        take(str(tag, "seat front roll")[..]);
        for i in from..to {
            guard pv_mat[i] == mesh::MAT_CHAIR else { continue; }
            let q = chair_local(ch, pv_pos[i]);
            if q.y > 330.0 && q.y < 365.0 && q.z > 150.0 && abs(q.x) < 120.0 { offer(i, -pv_n[i].y); }
        }
        take(str(tag, "apron's underside, front")[..]);
    }
    let mid = float2 { 0.0, mesh::TABLE_Z };
    let r_top = mesh::TABLE_R;
    for i in table_verts {
        let h = (pv_pos[i].y - surfaces::FLOOR_Y) / M;
        let r = length(float2 { pv_pos[i].x, pv_pos[i].z } - mid);
        if pv_mat[i] == mesh::MAT_TABLE_BASE && h > 0.3 && h < 0.5 && r < 4.0 { offer(i, dot(pv_n[i], window) - abs(pv_n[i].y)); }
    }
    take("table base (column) facing the window");
    for i in table_verts {
        let h = (pv_pos[i].y - surfaces::FLOOR_Y) / M;
        let r = length(float2 { pv_pos[i].x, pv_pos[i].z } - mid);
        if pv_mat[i] == mesh::MAT_TABLE_BASE && h > 0.3 && h < 0.5 && r < 4.0 { offer(i, -dot(pv_n[i], window) - abs(pv_n[i].y)); }
    }
    take("table base (column) facing the room");
    for i in table_verts {
        let h = (pv_pos[i].y - surfaces::FLOOR_Y) / M;
        let r = length(float2 { pv_pos[i].x, pv_pos[i].z } - mid);
        if pv_mat[i] == mesh::MAT_TABLE_BASE && h > 0.08 && h < 0.6 && pv_n[i].y > 0.85 { offer(i, r * 0.01 - abs(h - 0.15)); }
    }
    take("table base facing up (a foot's top)");
    for i in table_verts {
        let r = length(float2 { pv_pos[i].x, pv_pos[i].z } - mid);
        if pv_mat[i] == mesh::MAT_TABLE && pv_n[i].y < -0.95 && pv_pos[i].y < mesh::TABLE_TOP { offer(i, -abs(r - 0.6 * r_top)); }
    }
    take("top's underside, halfway out");
    for i in table_verts {
        let r = length(float2 { pv_pos[i].x, pv_pos[i].z } - mid);
        if pv_mat[i] == mesh::MAT_TABLE && pv_n[i].y < -0.5 && r > r_top - 2.0 { offer(i, r - abs(dot(pv_n[i], window) + 1.0)); }
    }
    take("edge's underside, window side");
    for i in table_verts {
        let r = length(float2 { pv_pos[i].x, pv_pos[i].z } - mid);
        if pv_mat[i] == mesh::MAT_TABLE && pv_n[i].y < -0.5 && r > r_top - 2.0 { offer(i, r - abs(dot(pv_n[i], window) - 1.0)); }
    }
    take("edge's underside, room side");
}

fn points_mode(samples: i64) {
    choose_points();
    let t0 = clock();
    var out: u8[>..] = [];
    format(out, "name|h_m|light rgb (no sun)|sun rgb\n");
    for pt in points {
        let p = pv_pos[pt.v];
        let n = pv_n[pt.v];
        format(out, pt.name[..], "|", (p.y - surfaces::FLOOR_Y) / M, "|");
        put3(out, light_at(p, n, samples));
        format(out, "|");
        put3(out, sun_direct(p, n));
        format(out, "\n");
    }
    format(out, points.len, " points × ", samples, " paths in ", (clock() - t0) * 1000.0, " ms; escapes ", escapes,
           ", unknown materials ", unknown_mat);
    print(out[..]);
}

// ---- the picture

// The props' parts (mesh's MAT_TABLE to MAT_TRIM, the braid with the cloth) and the ways a
// normal faces in the room's frame, by its largest axis, as tools/blender/scene.py's.
let PARTS = 4;
let WAYS = 6;
fn part_of(m: f32) -> i64 { if m < 3.5 { 0 } else if m < 4.5 { 1 } else if m < 5.5 { 2 } else { 3 } }
fn way_of(n: float3) -> i64 {
    let r = to_room(n);
    let a = float3 { abs(r.x), abs(r.y), abs(r.z) };
    if a.y >= a.x && a.y >= a.z { return if r.y > 0.0 { 2 } else { 3 }; }
    if a.z >= a.x { return if r.z < 0.0 { 0 } else { 1 }; }
    return if r.x > 0.0 { 4 } else { 5 };
}

struct Camera { eye: float3, fwd: float3, right: float3, up: float3, half: f32, w: i64, h: i64, samples: i64, light_only: bool }

// A row of the picture and its props' light, summed by part and way.
struct Row { y: i64, sums: f32[24], counts: f32[24], rgb: float3[] }
struct Job { y: i64 }   // -1: no more rows

// What the camera sees along d (or the light alone at the first surface, with
// light_only); a hit on the props adds its light to sums and counts.
fn shade(cam: Camera, d: float3, sums: f32[24]&, counts: f32[24]&) -> float3 {
    var o = cam.eye;
    var through: f32 = 1.0;
    for step in 24 {
        let t = nearest(o, d);
        guard hit_tri >= 0 else { return if to_sky(o, d) { sky * through } else { float3_0 }; }
        let k = hit_tri;
        let p = o + d * t;
        if kind[k] == GLASS {
            if !is_lace(k) {
                through *= PANE;
            } else if rnd() >= LACE_LETS {
                return off_thread(p, k, 1) * through;
            }
            o = p + d * EPS;
            continue;
        }
        var ng = face_normal(k);
        if dot(ng, d) > 0.0 { ng = float3_0 - ng; }
        var ns = smooth_normal(k);
        if dot(ns, ng) < 0.0 { ns = float3_0 - ns; }
        let a = albedo(k, p, ng);
        let q = p + ng * EPS;
        let light = sun_direct(q, ns) + radiance(q, cosine_dir(ns), 1);
        if kind[k] == PROPS {
            let i = part_of(mat[k]) * WAYS + way_of(ns);
            sums[i] += lum(light);
            counts[i] += 1.0;
        }
        return (if cam.light_only { light } else { a * light }) * through;
    }
    return float3_0;
}

fn picture_row(cam: Camera, y: i64) -> Row {
    seed(y as u64);
    var sums:   f32[24]     = [0.0; 24];
    var counts: f32[24]     = [0.0; 24];
    var rgb:    float3[>..] = [];
    let aspect = cam.w as f32 / cam.h;
    for x in cam.w {
        var sum = float3_0;
        for s in cam.samples {
            let sx = (2.0 * (x + rnd()) / cam.w - 1.0) * cam.half * aspect;
            let sy = (1.0 - 2.0 * (y + rnd()) / cam.h) * cam.half;
            sum = sum + shade(cam, normalize(cam.fwd + cam.right * sx + cam.up * sy), sums, counts);
        }
        rgb.push(sum * (1.0 / cam.samples));
    }
    return Row { y, sums, counts, rgb };
}

thread_fn picture_worker(cam: Camera) {
    loop {
        let job = qget<Job>();
        guard job.y >= 0 else { break; }
        qput(picture_row(cam, job.y));
    }
}

fn picture_mode(view: room_scene::View, w: i64, h: i64, samples: i64, light_only: bool, exposure: f32, out: const u8[:]) {
    let eye = from_plan(view.eye);
    let fwd = normalize(from_plan(view.at) - eye);
    let right = normalize(cross(fwd, float3 { 0.0, 1.0, 0.0 }));
    let cam = Camera { eye, fwd, right, cross(right, fwd), tan(radians(view.fov) * 0.5), w, h, samples, light_only };
    let t0 = clock();
    let workers = max(1, hardware_threads());
    for y in h { qput(Job { y }); }
    for i in workers { qput(Job { -1 }); }
    var ids: i64[>..] = [];
    for i in workers { ids.push(thread_spawn(picture_worker, cam)); }
    var pixels: float3[>..] = [];
    for i in w * h { pixels.push(float3_0); }
    var sums:   f32[24] = [0.0; 24];
    var counts: f32[24] = [0.0; 24];
    for done in h {
        let row = qget<Row>();
        for x in w { pixels[row.y * w + x] = row.rgb[x]; }
        for i in 24 {
            sums[i] += row.sums[i];
            counts[i] += row.counts[i];
        }
    }
    for id in ids { thread_wait(id); }
    let took = clock() - t0;

    write_exr(str(out, ".exr")[..], pixels[..], w, h);
    write_png(str(out, ".png")[..], pixels[..], w, h, exp2(exposure));
    let parts = ["table_top", "table_base", "chair_wood", "chair_seat"];
    let ways = ["window", "away", "up", "down", "x+", "x-"];
    var text: u8[>..] = [];
    format(text, "the light alone on the props' pixels (over pi, luminance), by the way each faces:\n");
    for p in PARTS {
        format(text, parts[p], ":");
        for k in WAYS {
            let i = p * WAYS + k;
            if counts[i] >= 8.0 * samples { format(text, " ", ways[k], " ", sums[i] / counts[i], " (", (counts[i] / samples) as i64, ")"); }
        }
        format(text, "\n");
    }
    format(text, view.name[..], " ", w, "x", h, " at ", samples, " paths a pixel in ", took, " s on ", workers, " threads; wrote ",
           out, ".exr and .png");
    print(text[..]);
}

// ---- files

// An uncompressed scanline OpenEXR of 32-bit float B, G, R.
fn write_exr(path: const u8[:], px: const float3[:], w: i64, h: i64) {
    var o: u8[>..] = [];
    binary::write_u32le(o, 20000630);
    binary::write_u32le(o, 2);
    exr_attribute(o, "channels", "chlist", 3 * 18 + 1);
    for name in ["B", "G", "R"] {
        o.append(name);
        o.push(0);
        binary::write_u32le(o, 2);   // FLOAT
        binary::write_u32le(o, 0);   // pLinear and reserved
        binary::write_u32le(o, 1);
        binary::write_u32le(o, 1);
    }
    o.push(0);
    exr_attribute(o, "compression", "compression", 1);
    o.push(0);
    for name in ["dataWindow", "displayWindow"] {
        exr_attribute(o, name, "box2i", 16);
        binary::write_u32le(o, 0);
        binary::write_u32le(o, 0);
        binary::write_u32le(o, (w - 1) as u32);
        binary::write_u32le(o, (h - 1) as u32);
    }
    exr_attribute(o, "lineOrder", "lineOrder", 1);
    o.push(0);
    exr_attribute(o, "pixelAspectRatio", "float", 4);
    binary::write_f32le(o, 1.0);
    exr_attribute(o, "screenWindowCenter", "v2f", 8);
    binary::write_f32le(o, 0.0);
    binary::write_f32le(o, 0.0);
    exr_attribute(o, "screenWindowWidth", "float", 4);
    binary::write_f32le(o, 1.0);
    o.push(0);
    let row_bytes = 8 + 12 * w;
    let first = o.len + 8 * h;
    for y in h { binary::write_u64le(o, (first + y * row_bytes) as u64); }
    for y in h {
        binary::write_u32le(o, y as u32);
        binary::write_u32le(o, (12 * w) as u32);
        for x in w { binary::write_f32le(o, px[y * w + x].z); }
        for x in w { binary::write_f32le(o, px[y * w + x].y); }
        for x in w { binary::write_f32le(o, px[y * w + x].x); }
    }
    guard write_file(path, o[..]) else { abort(str("could not write ", path)); }
}
fn exr_attribute(o: u8[>..]&, name: const u8[:], kind_name: const u8[:], size: i64) {
    o.append(name);
    o.push(0);
    o.append(kind_name);
    o.push(0);
    binary::write_u32le(o, size as u32);
}

// An 8-bit RGB PNG of px times `scale`, clipped, sRGB; stored, not compressed.
fn write_png(path: const u8[:], px: const float3[:], w: i64, h: i64, scale: f32) {
    var raw: u8[>..] = [];
    for y in h {
        raw.push(0);
        for x in w {
            let c = px[y * w + x] * scale;
            raw.push(srgb_byte(c.x));
            raw.push(srgb_byte(c.y));
            raw.push(srgb_byte(c.z));
        }
    }
    var z: u8[>..] = [];
    z.push(0x78);
    z.push(0x01);
    var at = 0;
    while true {
        let n = min(raw.len - at, 65535);
        z.push(if at + n == raw.len { 1 } else { 0 });
        binary::write_u16le(z, n as u16);
        binary::write_u16le(z, (0xFFFF - n) as u16);
        z.append(raw[at..at + n]);
        at += n;
        guard at < raw.len else { break; }
    }
    var a: u32 = 1;
    var b: u32 = 0;
    for v in raw {
        a = (a + v) % 65521;
        b = (b + a) % 65521;
    }
    binary::write_u32be(z, (b << 16) | a);

    var o: u8[>..] = [];
    for v in [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A] { o.push(v as u8); }
    var head: u8[>..] = [];
    binary::write_u32be(head, w as u32);
    binary::write_u32be(head, h as u32);
    for v in [8, 2, 0, 0, 0] { head.push(v as u8); }
    png_chunk(o, "IHDR", head[..]);
    png_chunk(o, "IDAT", z[..]);
    png_chunk(o, "IEND", raw[..0]);
    guard write_file(path, o[..]) else { abort(str("could not write ", path)); }
}
fn srgb_byte(c: f32) -> u8 {
    let x = clamp(c, 0.0, 1.0);
    let e: f32 = 1.0 / 2.4;
    let s = if x <= 0.0031308 { 12.92 * x } else { 1.055 * pow(x, e) - 0.055 };
    return (s * 255.0 + 0.5) as u8;
}
fn png_chunk(o: u8[>..]&, name: const u8[:], data: const u8[:]) {
    binary::write_u32be(o, data.len as u32);
    let from = o.len;
    o.append(name);
    o.append(data);
    var crc: u32 = 0xFFFFFFFF;
    for v in o[from..] {
        crc ^= v;
        for i in 8 { crc = if (crc & 1) != 0 { (crc >> 1) ^ 0xEDB88320 } else { crc >> 1 }; }
    }
    binary::write_u32be(o, crc ^ 0xFFFFFFFF);
}

// ---- main

fn flag_at(argv: u8[:][>..]&, name: const u8[:]) -> i64 {
    for a, i in argv { if a == name && i + 1 < argv.len { return i + 1; } }
    return -1;
}
fn int_flag(argv: u8[:][>..]&, name: const u8[:], otherwise: i64) -> i64 {
    let at = flag_at(argv, name);
    guard at > 0 else { return otherwise; }
    let v, ok = parse_int(argv[at]);
    guard ok else { abort(str(name, ": a whole number")); }
    return v;
}

fn main() {
    var argv = args();
    let mode: const u8[:] = if argv.len > 1 { argv[1][..] } else { "" };
    let t0 = clock();
    let backs_at = flag_at(argv, "--backs");
    casement_backs = !(backs_at > 0 && argv[backs_at] == "off");
    for a in argv { if a == "--sun-clear" { room_scene::sun_take = float2 { 1.0, -1.0 }; } }
    let box_at = flag_at(argv, "--box-window");
    room_shell::box_window_on = box_at > 0 && argv[box_at] == "on";
    build_scene();
    print(tris.len, " triangles in ", (clock() - t0) * 1000.0, " ms");
    if mode == "points" {
        points_mode(int_flag(argv, "--samples", 4096));
        return;
    }
    guard mode == "picture" && argv.len > 2 else {
        abort("usage: path_trace points [--samples N] | picture VIEW [--size WxH] [--samples N] [--light] [--exposure EV] [--out PATH]");
    }
    let view, found = room_scene::view_named(argv[2]);
    guard found else { abort(str("no view ", argv[2])); }
    var w = 480;
    var h = 270;
    let size_at = flag_at(argv, "--size");
    if size_at > 0 {
        let a, b, both = split_once(argv[size_at], 'x');
        let x, ok_x = parse_int(a);
        let y, ok_y = parse_int(b);
        guard both && ok_x && ok_y else { abort("--size: WxH"); }
        w = x;
        h = y;
    }
    var exposure: f32 = 1.4;
    let ev_at = flag_at(argv, "--exposure");
    if ev_at > 0 {
        let v, ok = parse_flt(argv[ev_at]);
        guard ok else { abort("--exposure: a number"); }
        exposure = v as f32;
    }
    var light_only = false;
    for a in argv { if a == "--light" { light_only = true; } }
    let out_at = flag_at(argv, "--out");
    var out: u8[>..] = [];
    if out_at > 0 {
        out.append(argv[out_at]);
    } else {
        guard make_dir("build/path_traced") else { abort("could not make build/path_traced"); }
        format(out, "build/path_traced/", view.name[..], if light_only { "-light" } else { "" });
    }
    picture_mode(view, w, h, int_flag(argv, "--samples", 64), light_only, exposure, out[..]);
}
