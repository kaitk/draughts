// The library's shell (room_shell::build, the arrays the GPU gets) checked for cracks from
// its data, not by drawing it: a vertex inside another triangle's edge (a T-junction),
// which rasterizes as single pixels of whatever is behind; vertices a hair apart where
// faces meet; edges of one triangle (open) or of more than two; triangles of no area.
// Positions are the plan's metres (x along the window wall from the stove's end, y from the
// hall wall, h up from the floor).
import std;
import vec;
import math;
import os;
import model3d from "../../src/model3d";

let OFF = 1048576;
let MAX_CELLS = 20000;
let SHOWN = 8;
// CRACKS_ALL=1 prints every case, not the first few.
var shown_max = SHOWN;

fn unit() -> f64 { surfaces::METRE }
fn tol() -> f64 { 0.00001 * unit() }     // 0.01 mm: on an edge
fn gap() -> f64 { 0.0001 * unit() }      // 0.1 mm: a gap between two vertices
fn vcell() -> f64 { 0.01 * unit() }      // the vertices' grid
fn tcell() -> f64 { 0.05 * unit() }      // the triangles' grid

struct Item { key: i64, id: i32 }
struct Use { key: i64, exact: i64, tri: i32 }
struct Edge { a: i32, b: i32, first: i32, uses: i32 }
struct Junction { edge: i32, v: i32, partner: i32 }

fn d3(p: float3) -> double3 { double3 { p.x, p.y, p.z } }
fn same(a: double3, b: double3) -> bool { a.x == b.x && a.y == b.y && a.z == b.z }
fn less3(a: double3, b: double3) -> bool {
    if a.x != b.x { return a.x < b.x; }
    if a.y != b.y { return a.y < b.y; }
    return a.z < b.z;
}
fn key_of(ix: i64, iy: i64, iz: i64) -> i64 { ((ix + OFF) << 42) | ((iy + OFF) << 21) | (iz + OFF) }
fn cell_of(v: f64, c: f64) -> i64 { floor(v / c) as i64 }
fn pair_key(a: i32, b: i32) -> i64 {
    let lo = min(a, b) as i64;
    let hi = max(a, b) as i64;
    return (lo << 32) | hi;
}

fn mm(x: f64) -> f64 { floor(x * 1000.0 + 0.5) / 1000.0 }

// A world point in the plan's metres.
fn plan(p: double3, line: u8[>..]&) {
    let s = room_shell::LIBRARY;
    let x = s.table.x - p.x / unit();
    let y = s.table.y - p.z / unit();
    let h = (p.y - surfaces::FLOOR_Y) / unit();
    format(line, "(", mm(x), ", ", mm(y), ", ", mm(h), ")");
}

fn kind_name(mat: f32) -> const u8[:] {
    let k = floor(mat + 0.001) as i64;
    return match k {
        4 => "floor", 5 => "oak", 6 => "paper", 7 => "stone", 8 => "plaster", 9 => "paint", 10 => "glass",
        11 => "lace", 12 => "brass", 13 => "cord", 14 => "book", _ => "other",
    };
}
fn kind_of(mat: f32) -> i64 { clamp(floor(mat + 0.001) as i64, 0, 15) }

fn fill_grid(keys: i64[>..]&, ids: i32[>..]&, pts: double3[>..]&, c: f64) {
    var items: Item[>..] = [];
    for p, i in pts { items.push(Item { key_of(cell_of(p.x, c), cell_of(p.y, c), cell_of(p.z, c)), i as i32 }); }
    sort(items) { a, b => a.key < b.key };
    for it in items {
        keys.push(it.key);
        ids.push(it.id);
    }
}

fn cell_range(keys: i64[>..]&, k: i64) -> i64, i64 {
    let lo, found = binary_search(keys[..], k);
    guard found else { return lo, lo; }
    var hi = lo;
    while hi < keys.len && keys[hi] == k { hi++; }
    return lo, hi;
}

fn root_of(parent: i32[>..]&, i: i32) -> i32 {
    var x = i;
    while parent[x] != x {
        parent[x] = parent[parent[x]];
        x = parent[x];
    }
    return x;
}

// The point of triangle abc nearest p (Ericson, Real-Time Collision Detection 5.1.5).
fn nearest_on(p: double3, a: double3, b: double3, c: double3) -> double3 {
    let ab = b - a;
    let ac = c - a;
    let ap = p - a;
    let d1 = dot(ab, ap);
    let d2 = dot(ac, ap);
    if d1 <= 0.0 && d2 <= 0.0 { return a; }
    let bp = p - b;
    let d3v = dot(ab, bp);
    let d4 = dot(ac, bp);
    if d3v >= 0.0 && d4 <= d3v { return b; }
    let vc = d1 * d4 - d3v * d2;
    if vc <= 0.0 && d1 >= 0.0 && d3v <= 0.0 { return a + ab * (d1 / (d1 - d3v)); }
    let cp = p - c;
    let d5 = dot(ab, cp);
    let d6 = dot(ac, cp);
    if d6 >= 0.0 && d5 <= d6 { return c; }
    let vb = d5 * d2 - d1 * d6;
    if vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0 { return a + ac * (d2 / (d2 - d6)); }
    let va = d3v * d6 - d5 * d4;
    if va <= 0.0 && (d4 - d3v) >= 0.0 && (d5 - d6) >= 0.0 { return b + (c - b) * ((d4 - d3v) / ((d4 - d3v) + (d5 - d6))); }
    let den = 1.0 / (va + vb + vc);
    return a + ab * (vb * den) + ac * (vc * den);
}

// The ray o + t dir's hit on triangle abc, or -1.
fn hit(o: double3, dir: double3, a: double3, b: double3, c: double3) -> f64 {
    let e1 = b - a;
    let e2 = c - a;
    let p = cross(dir, e2);
    let det = dot(e1, p);
    guard abs(det) > 1e-18 else { return -1.0; }
    let inv = 1.0 / det;
    let s = o - a;
    let u = dot(s, p) * inv;
    guard u >= -1e-9 && u <= 1.0 + 1e-9 else { return -1.0; }
    let q = cross(s, e1);
    let v = dot(dir, q) * inv;
    guard v >= -1e-9 && u + v <= 1.0 + 1e-9 else { return -1.0; }
    return dot(e2, q) * inv;
}

// The scene the rays meet: the shell's triangles and the glass's, in a grid of cells.
var sp:     double3[>..] = [];
var smat:   f32[>..]     = [];
var tkeys:  i64[>..]     = [];
var tids:   i32[>..]     = [];
var tstamp: i32[>..]     = [];
var tmark:  i32          = 0;

fn add_scene(verts: mesh::Vertex[>..]&, indices: u32[>..]&) {
    for t in indices.len / 3 {
        for k in 3 { sp.push(d3(verts[indices[3 * t + k] as i64].pos)); }
        smat.push(verts[indices[3 * t] as i64].mat);
    }
}

fn scene_grid() {
    var items: Item[>..] = [];
    let c = tcell();
    let margin = tol() * 2.0;
    for t in sp.len / 3 {
        let a = sp[3 * t];
        let b = sp[3 * t + 1];
        let e = sp[3 * t + 2];
        let x0 = cell_of(min(min(a.x, b.x), e.x) - margin, c);
        let x1 = cell_of(max(max(a.x, b.x), e.x) + margin, c);
        let y0 = cell_of(min(min(a.y, b.y), e.y) - margin, c);
        let y1 = cell_of(max(max(a.y, b.y), e.y) + margin, c);
        let z0 = cell_of(min(min(a.z, b.z), e.z) - margin, c);
        let z1 = cell_of(max(max(a.z, b.z), e.z) + margin, c);
        for ix in x0..x1 + 1 {
            for iy in y0..y1 + 1 {
                for iz in z0..z1 + 1 { items.push(Item { key_of(ix, iy, iz), t as i32 }); }
            }
        }
        tstamp.push(-1);
    }
    sort(items) { a, b => a.key < b.key };
    for it in items {
        tkeys.push(it.key);
        tids.push(it.id);
    }
}

// The nearest triangle the ray from o along dir meets past `near` and within `far` (world
// units), and its distance; -1 for none.
fn cast(o: double3, dir: double3, near: f64, far: f64) -> i32, f64 {
    let c = tcell();
    let e = o + dir * far;
    let x0 = cell_of(min(o.x, e.x), c);
    let x1 = cell_of(max(o.x, e.x), c);
    let y0 = cell_of(min(o.y, e.y), c);
    let y1 = cell_of(max(o.y, e.y), c);
    let z0 = cell_of(min(o.z, e.z), c);
    let z1 = cell_of(max(o.z, e.z), c);
    tmark++;
    var best: i32 = -1;
    var best_t = far;
    for ix in x0..x1 + 1 {
        for iy in y0..y1 + 1 {
            for iz in z0..z1 + 1 {
                let lo, hi = cell_range(tkeys, key_of(ix, iy, iz));
                for j in lo..hi {
                    let t = tids[j];
                    guard tstamp[t] != tmark else { continue; }
                    tstamp[t] = tmark;
                    let d = hit(o, dir, sp[3 * t], sp[3 * t + 1], sp[3 * t + 2]);
                    if d > near && d < best_t {
                        best_t = d;
                        best = t;
                    }
                }
            }
        }
    }
    return best, best_t;
}

// Whether p lies within tol of a scene triangle other than `own` (scene index).
fn on_a_face(p: double3, own: i64) -> bool {
    let c = tcell();
    let lo, hi = cell_range(tkeys, key_of(cell_of(p.x, c), cell_of(p.y, c), cell_of(p.z, c)));
    for j in lo..hi {
        let t = tids[j] as i64;
        guard t != own else { continue; }
        let q = nearest_on(p, sp[3 * t], sp[3 * t + 1], sp[3 * t + 2]);
        if length(q - p) < tol() { return true; }
    }
    return false;
}

// What a crack at p shows looking in along -n: the triangle behind and how far, in words.
fn behind(p: double3, n: double3, line: u8[>..]&) -> bool {
    let eps = 0.001;
    let t, d = cast(p + n * eps, n * -1.0, eps + 3.0 * tol(), 2.0 * unit());
    if t < 0 {
        line.append("nothing behind within 2 m");
        return false;
    }
    format(line, kind_name(smat[t]), " ", mm(d / unit() * 1000.0), " mm behind");
    return true;
}

// Whether something stands in front of p along n within 5 mm (the crack hidden).
fn covered(p: double3, n: double3) -> bool {
    let eps = 0.001;
    let t, d = cast(p + n * eps, n, 3.0 * tol(), 0.005 * unit());
    return t >= 0;
}

// The counts a mesh's check found, of each kind; `visible_cracks` the T-junctions and gaps
// with nothing behind them and nothing in front.
struct Report { junctions: i64, seams: i64, visible: i64, gaps: i64, open: i64, many: i64, flat: i64 }

fn check(name: const u8[:], verts: mesh::Vertex[>..]&, indices: u32[>..]&, scene_first: i64) -> Report {
    var rep = Report { 0, 0, 0, 0, 0, 0, 0 };
    let nv = verts.len;
    let nt = indices.len / 3;
    var pos: double3[>..] = [];
    for v in verts { pos.push(d3(v.pos)); }
    // Vertices at exactly one place share an id; ids within `gap` of each other a group.
    var order: i32[>..] = [];
    for i in nv { order.push(i as i32); }
    sort(order) { a, b => less3(pos[a], pos[b]) };
    var exact: i32[>..]     = [];
    var reps:  double3[>..] = [];
    for i in nv { exact.push(0); }
    for k in nv {
        let i = order[k];
        if k == 0 || !same(pos[i], pos[order[k - 1]]) { reps.push(pos[i]); }
        exact[i] = (reps.len - 1) as i32;
    }
    var rkeys: i64[>..] = [];
    var rids:  i32[>..] = [];
    fill_grid(rkeys, rids, reps, vcell());
    var parent: i32[>..] = [];
    for e in reps.len { parent.push(e as i32); }
    var gaps = 0;
    var worst_gap: f64 = 0.0;
    for p, e in reps {
        let cx = cell_of(p.x, vcell());
        let cy = cell_of(p.y, vcell());
        let cz = cell_of(p.z, vcell());
        for dx in 3 {
            for dy in 3 {
                for dz in 3 {
                    let lo, hi = cell_range(rkeys, key_of(cx + dx - 1, cy + dy - 1, cz + dz - 1));
                    for j in lo..hi {
                        let f = rids[j];
                        guard f as i64 > e else { continue; }
                        let d = length(reps[f] - p);
                        guard d <= gap() else { continue; }
                        gaps++;
                        worst_gap = max(worst_gap, d);
                        let ra = root_of(parent, e as i32);
                        let rb = root_of(parent, f);
                        if ra != rb { parent[max(ra, rb)] = min(ra, rb); }
                    }
                }
            }
        }
    }
    var group_of: i32[>..]     = [];
    var gpos:     double3[>..] = [];
    for e in reps.len { group_of.push(-1); }
    var rep_group: i32[>..] = [];
    for e in reps.len {
        let r = root_of(parent, e as i32);
        if group_of[r] < 0 {
            group_of[r] = gpos.len as i32;
            gpos.push(reps[r]);
        }
        rep_group.push(group_of[r]);
    }
    var g: i32[>..] = [];
    for i in nv { g.push(rep_group[exact[i]]); }
    // The triangles: their normals and materials; those of no area.
    var tn:   double3[>..] = [];
    var tmat: f32[>..]     = [];
    var uses: Use[>..]     = [];
    var flat = 0;
    var first_flat: u8[>..] = [];
    for t in nt {
        let ia = indices[3 * t] as i64;
        let ib = indices[3 * t + 1] as i64;
        let ic = indices[3 * t + 2] as i64;
        let c = cross(pos[ib] - pos[ia], pos[ic] - pos[ia]);
        let area2 = length(c);
        let longest = max(max(length(pos[ib] - pos[ia]), length(pos[ic] - pos[ib])), length(pos[ia] - pos[ic]));
        // Facing as its vertices' normals do (the winding doesn't say: quad() keeps one order).
        let shading = d3(verts[ia].normal) + d3(verts[ib].normal) + d3(verts[ic].normal);
        let toward: f64 = if dot(c, shading) < 0.0 { -1.0 } else { 1.0 };
        tn.push(if area2 > 0.0 { c * (toward / area2) } else { double3_0 });
        tmat.push(verts[ia].mat);
        let collapsed = g[ia] == g[ib] || g[ib] == g[ic] || g[ic] == g[ia];
        if collapsed || longest == 0.0 || area2 / longest < tol() {
            flat++;
            if first_flat.len == 0 {
                format(first_flat, kind_name(verts[ia].mat), " at ");
                plan(pos[ia], first_flat);
            }
        }
        guard !collapsed else { continue; }
        let ids: i64[3] = [ia, ib, ic];
        for k in 3 {
            let a = ids[k];
            let b = ids[(k + 1) % 3];
            uses.push(Use { pair_key(g[a], g[b]), pair_key(exact[a], exact[b]), t as i32 });
        }
    }
    sort(uses) { a, b => a.key < b.key || (a.key == b.key && a.exact < b.exact) };
    // The edges, by their groups' pair.
    var edges: Edge[>..] = [];
    var k = 0;
    var unwelded = 0;
    var unwelded_at: u8[>..]        = [];
    var gap_lines:   u8[..160][>..] = [];
    while k < uses.len {
        var e = k + 1;
        while e < uses.len && uses[e].key == uses[k].key { e++; }
        let a = (uses[k].key >> 32) as i32;
        let b = (uses[k].key & 0xFFFFFFFF) as i32;
        edges.push(Edge { a, b, k as i32, (e - k) as i32 });
        if e - k == 2 && uses[k].exact != uses[k + 1].exact {
            unwelded++;
            if gap_lines.len < 4000 {
                var s: u8[>..] = [];
                format(s, kind_name(tmat[uses[k].tri]), " and ", kind_name(tmat[uses[k + 1].tri]), " from ");
                plan(gpos[a], s);
                s.append(" to ");
                plan(gpos[b], s);
                let l .= gap_lines.push([]);
                l.append(s[..min(s.len, 160)]);
            }
            if unwelded_at.len == 0 {
                format(unwelded_at, kind_name(tmat[uses[k].tri]), " and ", kind_name(tmat[uses[k + 1].tri]), " at ");
                plan(gpos[a], unwelded_at);
            }
        }
        k = e;
    }
    // Each group's edges.
    var efirst: i32[>..] = [];
    for i in gpos.len + 1 { efirst.push(0); }
    for ed in edges {
        efirst[ed.a + 1] += 1;
        efirst[ed.b + 1] += 1;
    }
    for i in gpos.len { efirst[i + 1] += efirst[i]; }
    var efill: i32[>..] = [];
    for i in gpos.len { efill.push(efirst[i]); }
    var eadj: i32[>..] = [];
    for i in edges.len * 2 { eadj.push(0); }
    for ed, i in edges {
        eadj[efill[ed.a]] = i as i32;
        efill[ed.a] += 1;
        eadj[efill[ed.b]] = i as i32;
        efill[ed.b] += 1;
    }
    // T-junctions: a group inside an edge, not its end.
    var gkeys: i64[>..] = [];
    var gids:  i32[>..] = [];
    fill_grid(gkeys, gids, gpos, vcell());
    var stamp: i32[>..] = [];
    for i in gpos.len { stamp.push(-1); }
    var junctions: Junction[>..] = [];
    let c = vcell();
    for ed, ei in edges {
        let p = gpos[ed.a];
        let q = gpos[ed.b];
        let d = q - p;
        let l2 = dot(d, d);
        let l = sqrt(l2);
        guard l > 2.0 * tol() else { continue; }
        let x0 = cell_of(min(p.x, q.x) - tol(), c);
        let x1 = cell_of(max(p.x, q.x) + tol(), c);
        let y0 = cell_of(min(p.y, q.y) - tol(), c);
        let y1 = cell_of(max(p.y, q.y) + tol(), c);
        let z0 = cell_of(min(p.z, q.z) - tol(), c);
        let z1 = cell_of(max(p.z, q.z) + tol(), c);
        let box = (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1);
        // The cells to look in: the edge's box, or for a long slanting edge the cells along it.
        var cells: i64[>..] = [];
        if box <= MAX_CELLS {
            for ix in x0..x1 + 1 {
                for iy in y0..y1 + 1 {
                    for iz in z0..z1 + 1 { cells.push(key_of(ix, iy, iz)); }
                }
            }
        } else {
            let steps = ceil(l / (0.5 * c)) as i64;
            for s in steps + 1 {
                let at = p + d * ((s as f64) / (steps as f64));
                let cx = cell_of(at.x, c);
                let cy = cell_of(at.y, c);
                let cz = cell_of(at.z, c);
                for dx in 3 {
                    for dy in 3 {
                        for dz in 3 { cells.push(key_of(cx + dx - 1, cy + dy - 1, cz + dz - 1)); }
                    }
                }
            }
        }
        for key in cells {
            let lo, hi = cell_range(gkeys, key);
            for j in lo..hi {
                let r = gids[j];
                guard stamp[r] != ei as i32 else { continue; }
                stamp[r] = ei as i32;
                guard r != ed.a && r != ed.b else { continue; }
                let w = gpos[r] - p;
                let t = dot(w, d) / l2;
                let along = t * l;
                guard along > tol() && along < l - tol() else { continue; }
                guard length(w - d * t) < tol() else { continue; }
                // A seam: an edge of r's along the same line, its triangles across from the edge's.
                var partner: i32 = -1;
                for m in (efirst[r] as i64)..(efirst[r + 1] as i64) {
                    let e2 = edges[eadj[m]];
                    let x = if e2.a == r { e2.b } else { e2.a };
                    let wx = gpos[x] - p;
                    if length(wx - d * (dot(wx, d) / l2)) < tol() {
                        partner = eadj[m];
                        break;
                    }
                }
                junctions.push(Junction { ei as i32, r, partner });
            }
        }
    }
    // The junctions by what they join, and whether their crack would show: a seam with nothing
    // in front of it within 5 mm, looking in through it.
    var on_seam: bool[>..] = [];
    for i in edges.len { on_seam.push(false); }
    var by_kind: i64[16][16] = [[0; 16]; 16];
    var through: i64[16]     = [0; 16];
    var shown = 0;
    var lines: u8[..160][>..] = [];
    var touching = 0;
    for jn in junctions {
        guard jn.partner >= 0 else {
            touching++;
            continue;
        }
        rep.seams++;
        on_seam[jn.edge] = true;
        on_seam[jn.partner] = true;
        let t1 = uses[edges[jn.edge].first].tri;
        let t2 = uses[edges[jn.partner].first].tri;
        let ka = kind_of(tmat[t1]);
        let kb = kind_of(tmat[t2]);
        by_kind[min(ka, kb)][max(ka, kb)] += 1;
        var n = tn[t1] + tn[t2];
        if length(n) < 1e-6 { n = tn[t1]; }
        n = normalize(n);
        let p = gpos[jn.v];
        guard !covered(p, n) else { continue; }
        var what: u8[>..] = [];
        let backed = behind(p, n, what);
        if backed { continue; }
        rep.visible++;
        through[min(ka, kb)] += 1;
        if lines.len < 4000 {
            var s: u8[>..] = [];
            format(s, kind_name(tmat[t1]), " edge, ", kind_name(tmat[t2]), " vertex", if dot(tn[t1], tn[t2]) > 0.999 { ", flat" } else { ", at a crease" },
                   " at ");
            plan(p, s);
            format(s, ": ", what);
            let l .= lines.push([]);
            l.append(s[..min(s.len, 160)]);
        }
    }
    rep.junctions = junctions.len;
    // Open edges: of one triangle and not a seam's; on another face (against a wall, the
    // floor), or free: then whether anything is behind just past the edge.
    var open_on = 0;
    var open_free = 0;
    var open_through: i64[16]        = [0; 16];
    var open_lines:   u8[..160][>..] = [];
    var many = 0;
    for ed, ei in edges {
        if ed.uses > 2 { many++; }
        guard ed.uses == 1 && !on_seam[ei] else { continue; }
        rep.open++;
        let t = uses[ed.first].tri as i64;
        let p = gpos[ed.a];
        let q = gpos[ed.b];
        let mid = (p + q) * 0.5;
        if on_a_face(mid, scene_first + t) {
            open_on++;
            continue;
        }
        open_free++;
        // In the face's plane, away from its third corner.
        let n = tn[t];
        guard length(n) > 0.0 else { continue; }
        let third = (pos[indices[3 * t] as i64] + pos[indices[3 * t + 1] as i64] + pos[indices[3 * t + 2] as i64]) * (1.0 / 3.0);
        var out = cross(q - p, n);
        guard length(out) > 0.0 else { continue; }
        out = normalize(out);
        if dot(out, third - mid) > 0.0 { out = out * -1.0; }
        let past = mid + out * (0.0005 * unit());
        var what: u8[>..] = [];
        guard !covered(past, n) else { continue; }
        guard !behind(past, n, what) else { continue; }
        open_through[kind_of(tmat[t])] += 1;
        if open_lines.len < 4000 {
            var s: u8[>..] = [];
            format(s, kind_name(tmat[t]), " ", mm(length(q - p) / unit() * 1000.0), " mm from ");
            plan(p, s);
            s.append(" to ");
            plan(q, s);
            let l .= open_lines.push([]);
            l.append(s[..min(s.len, 160)]);
        }
    }
    rep.many = many;
    rep.flat = flat;
    rep.gaps = unwelded;
    print(name, ": ", nv, " vertices, ", nt, " triangles; ", reps.len, " places, ", gpos.len, " after welding within 0.1 mm");
    print("  vertex pairs 0 to 0.1 mm apart: ", gaps, if gaps > 0 { str(", the widest ", mm(worst_gap / unit() * 1000.0), " mm") } else { str("") });
    print("  edges shared only once welded (gaps where faces meet): ", unwelded, if unwelded > 0 { str(", the first ", unwelded_at) } else { str("") });
    sort(gap_lines) { a, b => compare(a, b) < 0 };
    for l, i in gap_lines {
        guard i < shown_max else { break; }
        print("      ", l);
    }
    print("  triangles of no area: ", flat, if flat > 0 { str(", the first ", first_flat) } else { str("") });
    print("  edges of more than two triangles: ", many);
    print("  T-junctions: ", junctions.len, ", ", rep.seams, " where edges run on along the same line (seams), ", touching, " a vertex only touching");
    for a in 16 {
        for b in 16 {
            guard by_kind[a][b] > 0 else { continue; }
            print("    seams ", kind_name(a as f32), " with ", kind_name(b as f32), ": ", by_kind[a][b],
                  if through[a] > 0 && a == min(a, b) { "" } else { "" });
        }
    }
    print("    seams open in front with nothing behind: ", rep.visible);
    for a in 16 {
        guard through[a] > 0 else { continue; }
        print("      of ", kind_name(a as f32), " with the same or a later kind: ", through[a]);
    }
    sort(lines) { a, b => compare(a, b) < 0 };
    for l, i in lines {
        guard i < shown_max else { break; }
        print("      ", l);
    }
    print("  open edges (not seams): ", rep.open, ", ", open_on, " on another face, ", open_free, " free");
    for a in 16 {
        guard open_through[a] > 0 else { continue; }
        print("    free and open in front with nothing behind, ", kind_name(a as f32), ": ", open_through[a]);
    }
    sort(open_lines) { a, b => compare(a, b) < 0 };
    for l, i in open_lines {
        guard i < shown_max else { break; }
        print("      ", l);
    }
    return rep;
}

fn main() {
    var all: u8[>..] = [];
    if env("CRACKS_ALL", all) { shown_max = 1000000; }
    var verts:         mesh::Vertex[>..] = [];
    var indices:       u32[>..]          = [];
    var glass:         mesh::Vertex[>..] = [];
    var glass_indices: u32[>..]          = [];
    room_shell::build(verts, indices, glass, glass_indices, room_shell::LIBRARY, true);
    add_scene(verts, indices);
    add_scene(glass, glass_indices);
    scene_grid();
    let shell = check("the shell", verts, indices, 0);
    let panes = check("the glass and lace", glass, glass_indices, indices.len / 3);
    print(shell.visible + panes.visible);
}
