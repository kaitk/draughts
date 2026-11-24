// The shell's mesh closed where its pieces meet (docs/decisions/rendering.md, "The mesh is
// closed where it cracked"): vertices a hair apart (under 0.1 mm, where two builders
// work a mitre out each its own way) moved onto one place, and every vertex lying inside
// another triangle's edge (a T-junction, whose crack under rasterization shows what is
// behind as single bright pixels) made a corner of that triangle, the triangle fanned from
// its opposite corner. Run once on the built mesh; test/model3d/cracks.goose checks it.
namespace mesh_close;
import std;
import vec;
import math;

let OFF = 1048576;
let EMPTY: i64 = -1;

fn key_of(ix: i64, iy: i64, iz: i64) -> i64 { ((ix + OFF) << 42) | ((iy + OFF) << 21) | (iz + OFF) }
fn cell_of(v: f32, c: f32) -> i64 { floor(v / c) as i64 }

// An open-addressed table from a cell's key to its run in a list sorted by key.
struct Slot { key: i64, first: i32, count: i32 }

fn slot_of(table: Slot[>..]&, key: i64) -> i64 {
    let mask = table.len - 1;
    var h = (((key as u64 * 0x9E3779B97F4A7C15) >> 20) as i64) & mask;
    while table[h].key != EMPTY && table[h].key != key { h = (h + 1) & mask; }
    return h;
}

// The points of `pos` in cells of side c: `order` the ids sorted by cell, `table` each
// cell's run in it.
fn grid(pos: float3[>..]&, c: f32, order: i32[>..]&, table: Slot[>..]&) {
    var keys: i64[>..] = [];
    for p in pos { keys.push(key_of(cell_of(p.x, c), cell_of(p.y, c), cell_of(p.z, c))); }
    for i in pos.len { order.push(i as i32); }
    sort(order) { a, b => keys[a] < keys[b] };
    var size = 16;
    while size < 2 * pos.len { size *= 2; }
    for i in size { table.push(Slot { EMPTY, 0, 0 }); }
    for k, i in order {
        let h = slot_of(table, keys[k]);
        if table[h].key == EMPTY { table[h] = Slot { keys[k], i as i32, 0 }; }
        table[h].count += 1;
    }
}

fn close(verts: mesh::Vertex[>..]&, indices: u32[>..]&) {
    let metre = surfaces::METRE;
    let gap: f32 = 0.0001 * metre;
    let on:  f32 = 0.00001 * metre;
    // Weld: each vertex onto the first one within `gap` of it.
    var pos: float3[>..] = [];
    for v in verts { pos.push(v.pos); }
    var order: i32[>..]  = [];
    var table: Slot[>..] = [];
    let wc: f32 = 0.001 * metre;
    grid(pos, wc, order, table);
    for i in pos.len {
        let p = pos[i];
        let cx = cell_of(p.x, wc);
        let cy = cell_of(p.y, wc);
        let cz = cell_of(p.z, wc);
        var best = i;
        for d in 27 {
            let h = slot_of(table, key_of(cx + d % 3 - 1, cy + d / 3 % 3 - 1, cz + d / 9 - 1));
            guard table[h].key != EMPTY else { continue; }
            for m in (table[h].first as i64)..((table[h].first + table[h].count) as i64) {
                let j = order[m] as i64;
                if j < best && length(verts[j].pos - p) <= gap { best = j; }
            }
        }
        if best != i { verts[i].pos = verts[best].pos; }
    }
    // The distinct places, in cells.
    var places: float3[>..] = [];
    {
        var all: float3[>..] = [];
        for v in verts { all.push(v.pos); }
        var o: i32[>..] = [];
        for i in all.len { o.push(i as i32); }
        sort(o) { a, b => all[a].x < all[b].x || (all[a].x == all[b].x && (all[a].y < all[b].y || (all[a].y == all[b].y && all[a].z < all[b].z))) };
        for k in o.len {
            let p = all[o[k]];
            if k == 0 || !same(p, all[o[k - 1]]) { places.push(p); }
        }
    }
    let c: f32 = 0.02 * metre;
    var porder: i32[>..]  = [];
    var ptable: Slot[>..] = [];
    grid(places, c, porder, ptable);
    var stamp: i64[>..] = [];
    for i in places.len { stamp.push(-1); }
    var mark: i64 = 0;
    // Each triangle's edges, the new ones too: a place inside one splits its triangle.
    var t = 0;
    while t < indices.len / 3 {
        var split = false;
        for e in 3 {
            let ia = indices[3 * t + e] as i64;
            let ib = indices[3 * t + (e + 1) % 3] as i64;
            let ic = indices[3 * t + (e + 2) % 3] as i64;
            let a = verts[ia].pos;
            let b = verts[ib].pos;
            let d = b - a;
            let l2 = dot(d, d);
            guard l2 > 4.0 * on * on else { continue; }
            let l = sqrt(l2);
            mark++;
            var inside: float2[..64] = [];   // (t along, place)
            // The cells to look in: the edge's box, or along a long slanting edge.
            let x0 = cell_of(min(a.x, b.x) - on, c);
            let x1 = cell_of(max(a.x, b.x) + on, c);
            let y0 = cell_of(min(a.y, b.y) - on, c);
            let y1 = cell_of(max(a.y, b.y) + on, c);
            let z0 = cell_of(min(a.z, b.z) - on, c);
            let z1 = cell_of(max(a.z, b.z) + on, c);
            var cells: i64[>..] = [];
            if (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1) <= 512 {
                for ix in x0..x1 + 1 {
                    for iy in y0..y1 + 1 {
                        for iz in z0..z1 + 1 { cells.push(key_of(ix, iy, iz)); }
                    }
                }
            } else {
                let steps = max(1, ceil(l / (0.5 * c)) as i64);
                for s in steps + 1 {
                    let at = a + d * ((s as f32) / (steps as f32));
                    let cx = cell_of(at.x, c);
                    let cy = cell_of(at.y, c);
                    let cz = cell_of(at.z, c);
                    for q in 27 { cells.push(key_of(cx + q % 3 - 1, cy + q / 3 % 3 - 1, cz + q / 9 - 1)); }
                }
            }
            for key in cells {
                {
                    let h = slot_of(ptable, key);
                    guard ptable[h].key != EMPTY else { continue; }
                    for m in (ptable[h].first as i64)..((ptable[h].first + ptable[h].count) as i64) {
                        let r = porder[m] as i64;
                        guard stamp[r] != mark else { continue; }
                        stamp[r] = mark;
                        let w = places[r] - a;
                        let u = dot(w, d) / l2;
                        guard u * l > on && (1.0 - u) * l > on else { continue; }
                        guard length(w - d * u) < on else { continue; }
                        if inside.len < 64 { inside.push(float2 { u, r as f32 }); }
                    }
                }
            }
            guard inside.len > 0 else { continue; }
            sort(inside) { p, q => p.x < q.x };
            // The fan from the opposite corner: a, the places in order, b.
            let va = verts[ia];
            let vb = verts[ib];
            var prev = ia;
            for k in inside.len + 1 {
                var next = ib;
                if k < inside.len {
                    let u = inside[k].x;
                    let nv = normalize(lerp(va.normal, vb.normal, u));
                    verts.push(mesh::Vertex { places[inside[k].y as i64], nv, lerp(va.uv, vb.uv, u), va.ao + (vb.ao - va.ao) * u, va.mat });
                    next = verts.len - 1;
                }
                let tri: u32[3] = [prev as u32, next as u32, ic as u32];
                if k == 0 {
                    indices[3 * t + e] = tri[0];
                    indices[3 * t + (e + 1) % 3] = tri[1];
                    indices[3 * t + (e + 2) % 3] = tri[2];
                } else {
                    // The same turn as the triangle's: its corners in its own order.
                    var out: u32[3] = [0; 3];
                    out[e] = tri[0];
                    out[(e + 1) % 3] = tri[1];
                    out[(e + 2) % 3] = tri[2];
                    indices.append(out);
                }
                prev = next;
            }
            split = true;
            break;
        }
        if !split { t++; }
    }
}

fn same(a: float3, b: float3) -> bool { a.x == b.x && a.y == b.y && a.z == b.z }
