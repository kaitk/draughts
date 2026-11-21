// The library's books (option B of build/notes/books/, 2026-11-21): each book a box with a
// rounded spine whose face samples a cell of the mask atlas (design/materials/
// books_atlas.png, book_cells.goose), coloured per book by the room's shader from a small
// table (COVER, LABEL) the vertex's material picks: the cover by its binding, the label,
// gilt or ink, how faded. A shelf is filled as a library's is: by size, the shelf's own
// formats first, sets together and in order (a long one in runs of a few volumes), 85 to
// 92% full, now and then a book leaning into a gap or against the side, and a small pile
// lying flat. Built once with the room's shell (bookcases.goose), in the room's frame.
namespace books;
import std;
import vec;
import math;

// A design of the atlas (book_cells.goose): its cell in texels, the head at y; its height
// and thickness in mm; its format (F Q O D S), binding (calf, half leather, the house's,
// cloth, vellum, paper boards, wrappers), set (a title), volume, and whether it has a label.
struct Cell {
    x:       i32,
    y:       i32,
    w:       i32,
    h:       i32,
    height:  f32,
    thick:   f32,
    format:  i32,
    binding: i32,
    set:     i32,
    vol:     i32,
    label:   i32,
}

let F = 0;
let Q = 1;
let O = 2;
let D = 3;
let S = 4;
let VELLUM = 4;
let BOARDS = 5;
let WRAPS = 6;

// What a book's material carries (surfaces::MAT_BOOK's fraction, CODES steps): the cover
// (32), the label (4), ink rather than gilt, and its fade (8 steps up to FADE_MAX).
let CODES: f32 = 2304.0;
let FADE_STEPS = 7;
let FADE_MAX: f32 = 0.6;

// A shelf to fill: along its builder's wall from s0 to s1 (metres), its top at y, the
// clear height over it, its front's distance out of the wall and its depth to the back;
// the formats it takes first and those it takes besides (a bit each, 1 << F ...), its
// seed, how faded its books are at s0 and at s1, and whether s runs to the left of someone
// facing the shelf (reads_reversed), so the books are put from s1, volume 1 on the left.
struct Shelf {
    s0:       f32,
    s1:       f32,
    y:        f32,
    clear:    f32,
    front:    f32,
    depth:    f32,
    first:    i64,
    also:     i64,
    seed:     i64,
    fade:     float2,
    reversed: bool,
}

// A book put on a shelf: its design, where along the shelf its foot starts (metres), how
// far it leans (radians: over 0 its top toward -s, turned about its foot's +s corner, under
// 0 toward +s about the -s corner), whether it lies flat at height `lift` over the shelf,
// how far its spine stands back from the shelf's front, and its material's code.
struct Placed {
    cell: i64,
    s:    f32,
    lean: f32,
    flat: bool,
    lift: f32,
    back: f32,
    code: i64,
}

let MAX_ON_SHELF = 64;
type Row = Placed[..64];

// How often each set has been put in the room so far: a set used again comes as another
// copy, in other colours.
let MAX_SETS = 64;
type Uses = i64[64];

fn hash(a: i64, b: i64) -> f32 { surfaces::hash(a, b) }

// The first design of each set and how many volumes it has.
fn set_range(set: i64) -> i64, i64 {
    var first = -1;
    var n = 0;
    for c, i in CELL {
        guard c.set == set else { continue; }
        if first < 0 { first = i; }
        n++;
    }
    return first, n;
}

// A board's width, the book's depth on the shelf (metres).
fn depth_of(c: Cell) -> f32 { c.height * (if c.format <= Q { 0.75 } else { 0.68 }) / 1000.0 }

// The material's code of a copy of `set` (its `copy`th use in the room) of binding
// `binding`, labelled or not, faded `fade` (0 to FADE_MAX).
fn code_of(set: i64, copy: i64, binding: i64, label: bool, fade: f32) -> i64 {
    let cover = COVER_FIRST[binding] + ((hash(set * 7 + copy, 31) * COVER_COUNT[binding]) as i64) % COVER_COUNT[binding];
    var lab = 0;
    let choices = LABELS_OF[binding];
    if label && choices != 0 {
        // One of the binding's labels, picked among its bits.
        let n = popcount(choices as u64);
        var k = ((hash(set * 7 + copy, 37) * n) as i64) % n;
        for b in 4 {
            guard (choices >> b) & 1 != 0 else { continue; }
            if k == 0 {
                lab = b;
                break;
            }
            k--;
        }
    }
    let ink = binding == BOARDS || binding == WRAPS || (binding == VELLUM && !label);
    let f = clamp((fade / FADE_MAX * FADE_STEPS + 0.5) as i64, 0, FADE_STEPS);
    return cover + 32 * lab + 128 * (if ink { 1 } else { 0 }) + 256 * f;
}

// A book's material from its code (surfaces::MAT_BOOK and the code in its fraction).
fn material(code: i64) -> f32 { surfaces::MAT_BOOK + (code + 0.5) / CODES }

// The shelf's fade at s, counted from the reader's left (the row's own s before fill puts
// it in place).
fn fade_at(sh: Shelf, s: f32, k: i64) -> f32 {
    let along = clamp((s - sh.s0) / max(sh.s1 - sh.s0, 1e-3), 0.0, 1.0);
    let t = if sh.reversed { 1.0 - along } else { along };
    return clamp(sh.fade.x + (sh.fade.y - sh.fade.x) * t + 0.08 * (hash(sh.seed, k) - 0.5), 0.0, FADE_MAX);
}

// The shelf filled from the atlas's sets, `uses` counting each set's copies in the room:
// on some shelves a small pile lying flat first set aside; sets, the shelf's own formats
// first, the least used first, their heights mixed, a long one as a run of two to eight
// of its volumes (now and then whole, running on as far as it goes); then odd volumes to
// the shelf's fill; now and then a book
// out and its neighbour leaning into the gap. What is left at the end: the last book
// leaning on the side, or the row pushed to the other side, or a plain gap.
fn fill(sh: Shelf, uses: Uses&) -> Row {
    var row: Row = [];
    let width = sh.s1 - sh.s0;
    var target = width * (0.88 + 0.06 * hash(sh.seed, 1));
    // The pile: two to four quartos, octavos or duodecimos that fit lying flat.
    var pile:   i64[..4] = [];
    var pile_w: f32      = 0.0;
    if hash(sh.seed, 5) < 0.12 {
        let want = 2 + ((hash(sh.seed, 6) * 3.0) as i64) % 3;
        var lift: f32 = 0.0;
        let start = ((hash(sh.seed, 7) * CELLS) as i64) % CELLS;
        for n in CELLS {
            guard pile.len < want else { break; }
            let i = (start + 7 * n) % CELLS;
            let c = CELL[i];
            let h = c.height / 1000.0;
            guard c.format >= O && c.format <= D && h < 0.42 * width && depth_of(c) < sh.depth - 0.01 else { continue; }
            guard lift + c.thick / 1000.0 < min(sh.clear - 0.03, 0.12) else { continue; }
            pile.push(i);
            lift += c.thick / 1000.0;
            pile_w = max(pile_w, h + 0.012);
        }
        target -= pile_w;
    }
    var order: float2[..64] = [];
    for set in SETS {
        let first, _n = set_range(set);
        guard first >= 0 else { continue; }
        let c = CELL[first];
        let bit = 1 << c.format;
        let own = sh.first & bit != 0;
        guard own || sh.also & bit != 0 else { continue; }
        guard c.height / 1000.0 <= sh.clear - 0.015 else { continue; }
        let key = (if own { 0.0 } else { 2500.0 }) + 1000.0 * uses[set] - 0.3 * c.height + 120.0 * hash(sh.seed + set, 2);
        order.push(float2 { key, set });
    }
    sort(order) { a, b => a.x < b.x };
    var x: f32 = 0.0;
    var gap_done = false;
    for pass in 2 {
        for e in order {
            let set = e.y as i64;
            let first, vols = set_range(set);
            // A long set comes as a run of two to eight of its volumes, now and then whole.
            var v0 = 0;
            var v1 = vols;
            let most = 2 + ((hash(sh.seed + set, 11) * 7.0) as i64) % 7;
            if vols > most && hash(sh.seed + set, 12) > 0.15 {
                v0 = ((hash(sh.seed + set, 13) * (vols - most + 1)) as i64) % (vols - most + 1);
                v1 = v0 + most;
            }
            var run: f32 = 0.0;
            for v in v0..v1 { run += CELL[first + v].thick / 1000.0 + 0.0008; }
            // The second pass: one odd volume a set, where it fits.
            if pass == 1 {
                v0 = ((hash(sh.seed + set, 8) * vols) as i64) % vols;
                v1 = v0 + 1;
                guard x + CELL[first + v0].thick / 1000.0 <= target else { continue; }
            } else {
                guard x + run <= target || (v1 - v0 > 3 && target - x > 0.15) else { continue; }
            }
            let copy = uses[set];
            uses[set] = copy + 1;
            for v in v0..v1 {
                let i = first + v;
                let c = CELL[i];
                let t = c.thick / 1000.0;
                guard x + t <= target + 0.01 && row.len < MAX_ON_SHELF - 4 else { break; }
                var lean: f32 = 0.0;
                var at = x;
                if !gap_done && row.len > 3 && hash(sh.seed * 31 + i, 3) < 0.025 {
                    let a = 0.12 + 0.12 * hash(sh.seed + i, 4);
                    let h = c.height / 1000.0;
                    let foot = t * cos(a) + h * sin(a);
                    if x + foot < target {
                        lean = a;
                        at = x + foot - t;
                        gap_done = true;
                    }
                }
                row.push(Placed { i, at, lean, false, 0.0, 0.002 + 0.01 * hash(sh.seed, 100 + i),
                                  code_of(set, copy, c.binding, c.label != 0, fade_at(sh, sh.s0 + at, i)) });
                x = at + t + 0.0004 + 0.0008 * hash(sh.seed, 200 + i);
            }
        }
    }
    // The pile after the row.
    var lift: f32 = 0.0;
    for i in pile {
        let c = CELL[i];
        let set: i64 = c.set;
        let at = x + 0.008 + 0.004 * (hash(sh.seed, 300 + i) - 0.5);
        row.push(Placed { i, at, 0.0, true, lift, 0.004 + 0.012 * hash(sh.seed, 400 + i),
                          code_of(set, uses[set] + 3, c.binding, c.label != 0, fade_at(sh, sh.s0 + at, i)) });
        lift += c.thick / 1000.0;
    }
    if pile.len > 0 { x += pile_w; }
    let left = width - x;
    let end = hash(sh.seed, 9);
    if pile.len == 0 && left > 0.02 && row.len > 0 && end < 0.3 {
        // The last book leans on the side, about its foot's corner away from it.
        let p .= row[row.len - 1];
        let c = CELL[p.cell];
        let h = c.height / 1000.0;
        let t = c.thick / 1000.0;
        let reach = min(width - p.s - t * 0.9, h * 0.42);
        if p.lean == 0.0 && reach > 0.01 { p.lean = -asin(reach / h); }
    } else if end > 0.65 {
        for &p in row { p.s += left - 0.002; }
    }
    for &p in row {
        if sh.reversed {
            let c = CELL[p.cell];
            p.s = width - p.s - (if p.flat { c.height } else { c.thick }) / 1000.0;
            p.lean = -p.lean;
        }
        p.s += sh.s0;
    }
    return row;
}

// Whether builder b's s runs to the left of someone facing its wall.
fn reads_reversed(b: surfaces::Builder) -> bool {
    let right = cross(float3 { -b.n.x, 0.0, -b.n.y }, float3 { 0.0, 1.0, 0.0 });
    return dot(float3 { b.d.x, 0.0, b.d.y }, right) < 0.0;
}

// The row's books into the mesh, on builder b's wall (world units a metre: surfaces::METRE).
// A spine reads left to right to someone facing the wall: its cell is mirrored across
// where the wall's s runs to their left.
fn put(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, sh: Shelf, row: Row&) {
    let mirrored = reads_reversed(b);
    for p in row {
        if p.flat { flat_book(verts, indices, b, sh, p, mirrored); } else { upright(verts, indices, b, sh, p, mirrored); }
    }
}

// The atlas's uv of a cell's point: across 0..1 from its left edge, along 0 (the head) to 1.
fn atlas_uv(c: Cell, across_in: f32, along: f32, mirrored: bool) -> float2 {
    let across = if mirrored { 1.0 - across_in } else { across_in };
    return float2 { (c.x + across * c.w) / ATLAS_W, (c.y + along * c.h) / ATLAS_H };
}

// A corner (s, y, z metres in the shelf's builder) into the world.
fn at(b: surfaces::Builder, p: float3) -> float3 {
    let k = surfaces::METRE;
    return surfaces::world(b, p.x * k, p.y * k, p.z * k);
}

fn push4(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, p: float3[4], n: float3, uv: float2[4],
         ao: f32[4], mat: f32) {
    let base = verts.len as u32;
    let wn = surfaces::world_normal(b, n);
    for i in 4 { verts.push(mesh::Vertex { at(b, p[i]), wn, uv[i], ao[i], mat }); }
    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
}

// The uv the shader reads as not the spine: the boards' sides (cover), the page edges
// plain or sprinkled.
let SIDE_UV = float2 { -1.0, -1.0 };
let PAGES_UV = float2 { -1.0, -2.0 };
let SPRINKLED_UV = float2 { -1.0, -3.0 };

fn pages_uv(c: Cell, p: Placed) -> float2 {
    if c.binding <= 2 && hash(p.cell, 500 + p.code) < 0.7 { SPRINKLED_UV } else { PAGES_UV }
}

// How much a rounded spine's edges stand back and turn: bound books are rounded,
// boards and wrappers flat.
fn bulge(c: Cell) -> float2 {
    if c.binding >= BOARDS { float2 { 0.0, 0.2 } } else { float2 { 0.12, 0.75 } }
}

// A point of a book standing (s along, y up) turned by its lean `r` (the pivot's s and y,
// the lean's cosine and sine) into place; and a normal.
fn turned(r: float4, q: float3) -> float3 {
    float3 { r.x + (q.x - r.x) * r.z - (q.y - r.y) * r.w, r.y + (q.x - r.x) * r.w + (q.y - r.y) * r.z, q.z }
}
fn turned_normal(r: float4, n: float3) -> float3 { float3 { n.x * r.z - n.y * r.w, n.x * r.w + n.y * r.z, n.z } }

// An upright book: its rounded spine in two strips (the atlas cell across it), its top
// (the page edges), its two sides (the boards); leaning about the foot's corner away from
// where its top goes.
fn upright(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, sh: Shelf, p: Placed, mirrored: bool) {
    let c = CELL[p.cell];
    let h = c.height / 1000.0;
    let t = c.thick / 1000.0;
    let d = min(depth_of(c), sh.depth - p.back - 0.01);
    let zf = sh.front - p.back;
    let bg = bulge(c);
    let ze = zf - bg.x * t;
    let mat = material(p.code);
    // Turned about the foot: the right corner when leaning left (lean > 0), the left one else.
    let pivot = if p.lean > 0.0 { p.s + t } else { p.s };
    let ca = cos(p.lean);
    let sa = sin(p.lean);
    let y0 = sh.y;
    let r = float4 { pivot, y0, ca, sa };
    let s0 = p.s;
    let s1 = p.s + t;
    let sm = p.s + 0.5 * t;
    // Inside the case the spine sees the room through the shelves' gap: the shelf above
    // shades its head, the more the less room is left over it, and the case's side the
    // books near it.
    let room_over = sh.clear - h * ca;
    let by_side = 0.7 + 0.3 * smoothstep(0.0 as f32, 0.15 as f32, min(sm - sh.s0, sh.s1 - sm));
    let foot_ao = 0.75 * by_side;
    let top_ao = (0.25 + 0.3 * clamp(room_over / 0.15, 0.0, 1.0)) * by_side;
    let edge = normalize(float3 { -sin(bg.y), 0.0, cos(bg.y) });
    let edge_r = float3 { -edge.x, 0.0, edge.z };
    let cols: float3[3] = [float3 { s0, 0.0, ze }, float3 { sm, 0.0, zf }, float3 { s1, 0.0, ze }];
    let ns:   float3[3] = [edge, float3 { 0.0, 0.0, 1.0 }, edge_r];
    for k in 2 {
        let a = cols[k];
        let e = cols[k + 1];
        let base = verts.len as u32;
        let pts:    float3[4] = [float3 { a.x, y0, a.z }, float3 { e.x, y0, e.z }, float3 { e.x, y0 + h, e.z }, float3 { a.x, y0 + h, a.z }];
        let nn:     float3[4] = [ns[k], ns[k + 1], ns[k + 1], ns[k]];
        let across: f32[4]    = [0.5 * k, 0.5 * (k + 1), 0.5 * (k + 1), 0.5 * k];
        let along:  f32[4]    = [1.0, 1.0, 0.0, 0.0];
        let ao:     f32[4]    = [foot_ao, foot_ao, top_ao, top_ao];
        for i in 4 {
            verts.push(mesh::Vertex { at(b, turned(r, pts[i])), surfaces::world_normal(b, turned_normal(r, nn[i])), atlas_uv(c, across[i], along[i], mirrored),
                                      ao[i], mat });
        }
        indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
    // The top: the page edges between the boards.
    let yt = y0 + h;
    let pu = pages_uv(c, p);
    let top: float3[4] = [turned(r, float3 { s0, yt, ze }), turned(r, float3 { s1, yt, ze }), turned(r, float3 { s1, yt, zf - d }),
                          turned(r, float3 { s0, yt, zf - d })];
    push4(verts, indices, b, top, turned_normal(r, float3 { 0.0, 1.0, 0.0 }), [pu, pu, pu, pu], [0.6 * top_ao, 0.6 * top_ao, 0.3 * top_ao, 0.3 * top_ao], mat);
    // The sides, the boards' faces: hidden but where a gap or a lean shows them.
    let sides: f32[2] = [s0, s1];
    let outs:  f32[2] = [-1.0, 1.0];
    for sx, i in sides {
        let q: float3[4] = [turned(r, float3 { sx, y0, zf - d }), turned(r, float3 { sx, y0, ze }), turned(r, float3 { sx, yt, ze }),
                            turned(r, float3 { sx, yt, zf - d })];
        push4(verts, indices, b, q, turned_normal(r, float3 { outs[i], 0.0, 0.0 }), [SIDE_UV, SIDE_UV, SIDE_UV, SIDE_UV],
              [0.25 * by_side, foot_ao * 0.6, top_ao * 0.7, 0.2 * by_side], mat);
    }
}

// A book lying flat with its spine out: the spine in two strips along it, the cover on
// top, the page edges at both ends.
fn flat_book(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, sh: Shelf, p: Placed, mirrored: bool) {
    let c = CELL[p.cell];
    let h = c.height / 1000.0;
    let t = c.thick / 1000.0;
    let d = min(depth_of(c), sh.depth - p.back - 0.01);
    let zf = sh.front - p.back;
    let bg = bulge(c);
    let ze = zf - bg.x * t;
    let mat = material(p.code);
    let y0 = sh.y + p.lift;
    let s0 = p.s;
    let s1 = p.s + h;
    // The head at s1 or s0, as it was laid.
    let head_right = hash(p.cell, 600 + p.code) < 0.5;
    // The cell's across up the pile or down it, so the spine reads unmirrored either way.
    let flip = head_right != mirrored;
    let low = normalize(float3 { 0.0, -sin(bg.y), cos(bg.y) });
    let high = float3 { 0.0, -low.y, low.z };
    let rows: float3[3] = [float3 { 0.0, y0, ze }, float3 { 0.0, y0 + 0.5 * t, zf }, float3 { 0.0, y0 + t, ze }];
    let ns:   float3[3] = [low, float3 { 0.0, 0.0, 1.0 }, high];
    for k in 2 {
        let a = rows[k];
        let e = rows[k + 1];
        let base = verts.len as u32;
        let pts:    float3[4] = [float3 { s0, a.y, a.z }, float3 { s1, a.y, a.z }, float3 { s1, e.y, e.z }, float3 { s0, e.y, e.z }];
        let nn:     float3[4] = [ns[k], ns[k], ns[k + 1], ns[k + 1]];
        let across: f32[4]    = [0.5 * k, 0.5 * k, 0.5 * (k + 1), 0.5 * (k + 1)];
        let along:  f32[4]    = if head_right { [1.0, 0.0, 0.0, 1.0] } else { [0.0, 1.0, 1.0, 0.0] };
        for i in 4 {
            verts.push(mesh::Vertex { at(b, pts[i]), surfaces::world_normal(b, nn[i]), atlas_uv(c, across[i], along[i], flip), 0.65, mat });
        }
        indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
    let yt = y0 + t;
    let cover: float3[4] = [float3 { s0, yt, ze }, float3 { s1, yt, ze }, float3 { s1, yt, zf - d }, float3 { s0, yt, zf - d }];
    push4(verts, indices, b, cover, float3 { 0.0, 1.0, 0.0 }, [SIDE_UV, SIDE_UV, SIDE_UV, SIDE_UV], [0.6, 0.6, 0.35, 0.35], mat);
    let pu = pages_uv(c, p);
    let ends: f32[2] = [s0, s1];
    let outs: f32[2] = [-1.0, 1.0];
    for sx, i in ends {
        let q: float3[4] = [float3 { sx, y0, zf - d }, float3 { sx, y0, ze }, float3 { sx, yt, ze }, float3 { sx, yt, zf - d }];
        push4(verts, indices, b, q, float3 { outs[i], 0.0, 0.0 }, [pu, pu, pu, pu], [0.5, 0.7, 0.7, 0.5], mat);
    }
}
