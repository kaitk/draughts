// The light the props hide from one another and from themselves, baked once per mesh
// (task 120): for each vertex of the games table and its chairs, rays over the hemisphere
// round its normal, cosine-weighted, against the props' own triangles within a reach;
// what is open of the hemisphere, and the mean open direction. The room's probe grid
// (room_light) holds the walls, the floor and everything farther than the reach, so the
// shell is no part of this: a vertex's light is the grid's toward its open direction,
// times how much is open. No graphics.
namespace prop_occlusion;
import std;
import vec;
import math;

// The triangles' grid: cubes of CELL_SIDE world units (about 1.6 cm) over the props'
// bounds, each listing the triangles whose bounds touch it.
let CELL_SIDE: f32 = 0.5;
let MAX_CELLS = 8000000;

// One triangle as the ray test reads it: its first corner and its two edges from it.
struct Triangle { a: float3, ab: float3, ac: float3 }

// A ray's nearest hit on one triangle at a distance under `far`, or `far` (Moller and
// Trumbore's test, both faces).
fn hit(t: Triangle&, o: float3, d: float3, far: f32) -> f32 {
    let p = cross(d, t.ac);
    let det = dot(t.ab, p);
    guard abs(det) > 1e-12 else { return far; }
    let inv = 1.0 / det;
    let s = o - t.a;
    let u = dot(s, p) * inv;
    guard u >= 0.0 && u <= 1.0 else { return far; }
    let q = cross(s, t.ab);
    let v = dot(d, q) * inv;
    guard v >= 0.0 && u + v <= 1.0 else { return far; }
    let at = dot(t.ac, q) * inv;
    return if at > 0.0 && at < far { at } else { far };
}

// An integer hash to a float in 0..1, for each vertex's turn of the ray set.
fn hash01(i: u32) -> f32 {
    var x = i * 0x9E3779B1;
    x = (x ^ (x >> 15)) * 0x85EBCA77;
    x = x ^ (x >> 13);
    return (x & 0xFFFFFF) / 16777216.0;
}

// What the bake gives each vertex: the mean open direction (unit, world) and the open
// part of the hemisphere, 0 to 1, cosine-weighted.
struct Open { dir: float3, open: f32 }

// The bake's counts, for the timing tool.
struct Stats { triangles: i64, cells: i64, listed: i64, rays: i64, tests: i64 }

// Bakes `out[i]` for each of `pos`/`normal`'s vertices from `rays` rays each, against the
// triangles of `indices`, hits farther than `reach` (world units) not counted and nearer
// ones counted less the farther they are, 1 - (t / reach)², so the bake fades into the
// probes' light at the reach rather than ending there.
fn bake(pos: const float3[:], normal: const float3[:], indices: const u32[:], rays: i64, reach: f32, out: Open[:],
        cell: f32 = CELL_SIDE) -> Stats {
    var st = Stats { 0, 0, 0, 0, 0 };
    let tris = indices.len / 3;
    st.triangles = tris;
    // The bounds, a reach past the vertices' on every side, and the grid over them.
    var lo = pos[0];
    var hi = pos[0];
    for p in pos {
        lo = float3 { min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z) };
        hi = float3 { max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z) };
    }
    lo = lo - float3 { cell, cell, cell };
    hi = hi + float3 { cell, cell, cell };
    let nx = (ceil((hi.x - lo.x) / cell)) as i64;
    let ny = (ceil((hi.y - lo.y) / cell)) as i64;
    let nz = (ceil((hi.z - lo.z) / cell)) as i64;
    let cells = nx * ny * nz;
    assert(cells <= MAX_CELLS);
    st.cells = cells;
    var shape:   Triangle[..] = [..tris];
    var lo_cell: i64[..]      = [..3 * tris];
    var hi_cell: i64[..]      = [..3 * tris];
    for k in tris {
        let a = pos[indices[3 * k] as i64];
        let b = pos[indices[3 * k + 1] as i64];
        let c = pos[indices[3 * k + 2] as i64];
        shape.push(Triangle { a, b - a, c - a });
        let tl = float3 { min(a.x, min(b.x, c.x)), min(a.y, min(b.y, c.y)), min(a.z, min(b.z, c.z)) } - lo;
        let th = float3 { max(a.x, max(b.x, c.x)), max(a.y, max(b.y, c.y)), max(a.z, max(b.z, c.z)) } - lo;
        lo_cell.push(clamp((tl.x / cell) as i64, 0, nx - 1));
        lo_cell.push(clamp((tl.y / cell) as i64, 0, ny - 1));
        lo_cell.push(clamp((tl.z / cell) as i64, 0, nz - 1));
        hi_cell.push(clamp((th.x / cell) as i64, 0, nx - 1));
        hi_cell.push(clamp((th.y / cell) as i64, 0, ny - 1));
        hi_cell.push(clamp((th.z / cell) as i64, 0, nz - 1));
    }
    // Each cell's list of triangles, one after another: first counted, then filled.
    var first: u32[..] = [..cells + 1];
    for i in cells + 1 { first.push(0); }
    for k in tris {
        for z in lo_cell[3 * k + 2]..hi_cell[3 * k + 2] + 1 {
            for y in lo_cell[3 * k + 1]..hi_cell[3 * k + 1] + 1 {
                for x in lo_cell[3 * k]..hi_cell[3 * k] + 1 { first[(z * ny + y) * nx + x + 1] += 1; }
            }
        }
    }
    for i in cells { first[i + 1] += first[i]; }
    let listed = first[cells] as i64;
    st.listed = listed;
    var filled: u32[..] = [..cells];
    for i in cells { filled.push(first[i]); }
    var list: u32[..] = [..listed];
    for i in listed { list.push(0); }
    for k in tris {
        for z in lo_cell[3 * k + 2]..hi_cell[3 * k + 2] + 1 {
            for y in lo_cell[3 * k + 1]..hi_cell[3 * k + 1] + 1 {
                for x in lo_cell[3 * k]..hi_cell[3 * k] + 1 {
                    let c = (z * ny + y) * nx + x;
                    list[filled[c] as i64] = k as u32;
                    filled[c] += 1;
                }
            }
        }
    }
    // The last ray that tested each triangle, so a triangle listed in several cells is
    // tested once a ray.
    var tested: u32[..] = [..tris];
    for k in tris { tested.push(0); }
    var ray_id: u32 = 0;
    let lift: f32 = 0.002;
    let n_rays = rays as f32;
    for p, i in pos {
        let n = normal[i];
        // A frame round the normal, turned by the vertex's hash.
        let side = if abs(n.y) < 0.9 { float3 { 0.0, 1.0, 0.0 } } else { float3 { 1.0, 0.0, 0.0 } };
        let tx = normalize(cross(side, n));
        let ty = cross(n, tx);
        let turn = hash01(i as u32);
        let o = p + n * lift;
        var open: f32 = 0.0;
        var dir = float3_0;
        for r in rays {
            // Cosine-weighted: uniform over the disc, lifted to the hemisphere.
            let u1 = (r + 0.5) / n_rays;
            let u2 = fract(r * 0.618034 + turn);
            let rad = sqrt(u1);
            let phi = TAU * u2;
            let d = tx * (rad * cos(phi)) + ty * (rad * sin(phi)) + n * sqrt(max(1.0 - u1, 0.0));
            ray_id += 1;
            let t = march(shape, first, list, tested, ray_id, lo, cell, nx, ny, nz, o, d, reach, st);
            let hidden = if t < reach { 1.0 - (t / reach) * (t / reach) } else { 0.0 };
            open += 1.0 - hidden;
            dir = dir + d * (1.0 - hidden);
        }
        st.rays += rays;
        let len = length(dir);
        out[i] = Open { if len > 1e-4 { dir / len } else { n }, open / n_rays };
    }
    return st;
}

// The nearest hit along o + d·t under `far`, walking the grid's cells in the ray's order
// (Amanatides and Woo) and stopping in the first cell whose nearest hit lies inside it.
fn march(shape: Triangle[..]&, first: u32[..]&, list: u32[..]&, tested: u32[..]&, ray_id: u32, lo: float3, cell: f32, nx: i64, ny: i64,
         nz: i64, o: float3, d: float3, far: f32, st: Stats&) -> f32 {
    let g = (o - lo) / cell;
    var x = clamp(floor(g.x) as i64, 0, nx - 1);
    var y = clamp(floor(g.y) as i64, 0, ny - 1);
    var z = clamp(floor(g.z) as i64, 0, nz - 1);
    let big: f32 = 1e30;
    let sx:  i64 = if d.x > 0.0 { 1 } else { -1 };
    let sy:  i64 = if d.y > 0.0 { 1 } else { -1 };
    let sz:  i64 = if d.z > 0.0 { 1 } else { -1 };
    let dx = if abs(d.x) > 1e-9 { cell / abs(d.x) } else { big };
    let dy = if abs(d.y) > 1e-9 { cell / abs(d.y) } else { big };
    let dz = if abs(d.z) > 1e-9 { cell / abs(d.z) } else { big };
    // The distances to the first cell walls crossed on each axis.
    var tx = if abs(d.x) > 1e-9 { ((if d.x > 0.0 { (x + 1) as f32 } else { x as f32 }) - g.x) * cell / d.x } else { big };
    var ty = if abs(d.y) > 1e-9 { ((if d.y > 0.0 { (y + 1) as f32 } else { y as f32 }) - g.y) * cell / d.y } else { big };
    var tz = if abs(d.z) > 1e-9 { ((if d.z > 0.0 { (z + 1) as f32 } else { z as f32 }) - g.z) * cell / d.z } else { big };
    var best = far;
    while true {
        let c = (z * ny + y) * nx + x;
        let j0 = first[c] as i64;
        let j1 = first[c + 1] as i64;
        for j in j0..j1 {
            let k = list[j] as i64;
            guard tested[k] != ray_id else { continue; }
            tested[k] = ray_id;
            st.tests += 1;
            best = hit(shape[k], o, d, best);
        }
        let exit = min(tx, min(ty, tz));
        guard best > exit && exit < far else { break; }
        if tx <= ty && tx <= tz {
            x += sx;
            tx += dx;
            guard x >= 0 && x < nx else { break; }
        } else if ty <= tz {
            y += sy;
            ty += dy;
            guard y >= 0 && y < ny else { break; }
        } else {
            z += sz;
            tz += dz;
            guard z >= 0 && z < nz else { break; }
        }
    }
    return best;
}
