// The tree grown whole (tree_whole.goose) as the picture draws it (task 107's T2): its wood
// as meshes, lit by the crown's own shade from a grid of its leaves, and the bark's tile.
// Part of trees, in its namespace. Everything is in the tree's frame, world units; the
// shaders carry it into the room (shaders::TREE_FN). Made when the tree is grown, never in
// the frame loop.
//
// The wood: tubes for the trunk, the limbs and the branches (levels 0-2), 12, 9 and 6 sides
// round, and flat ribbons for the branchlets and twigs (levels 3-4), which the vertex shader
// turns to face the eye and keeps at least a pixel wide (shaders::TREE_WOOD_VERT).
//
// The crown's shade: each leaf's area put into a grid of GRID³ cells over the crown; a
// point's open share toward the sun is exp(-depth) along the sun's way through the grid
// (Beer-Lambert, the leaves' extinction half their area a volume), and toward the sky the
// mean over seven ways round the upper half.
namespace trees;
import std;
import vec;
import math;

// A vertex of the wood. pos a point on the branch's surface (a ribbon's: on its axis);
// normal the tube's outward (a ribbon's 0); along the branch's way; uv the bark's tile,
// x round the branch (a ribbon's: its side, -1 or 1) and y along it; light x the share of
// the sun reaching it through the crown, y of the sky, z the branch's radius there, w how
// far it bends with the wind, 0 the trunk's foot to 1 a twig's tip (the wind's, T4).
struct WoodVertex { pos: float3, normal: float3, along: float3, uv: float2, light: float4 }

// The bark's tile: TILE_ACROSS texels round a branch for BARK_ACROSS world units, and
// TILE_ALONG along it for BARK_ALONG; its ridges about three times as long as wide.
let BARK_W = 256;
let BARK_H = 512;
let BARK_ACROSS: f32 = 7.6;     // 25 cm
let BARK_ALONG:  f32 = 15.2;    // 50 cm

// The tubes' sides by level (the trunk, limbs, branches).
let TUBE_SIDES: i64[3] = [12, 9, 6];
let TUBE_LEVELS = 3;

// The crown's grid: cells a side, how far past the leaves its box reaches (world units),
// and the leaves' extinction against their area (half: leaves turned every way).
let GRID = 64;
let GRID_MARGIN:     f32 = 12.0;
let LEAF_EXTINCTION: f32 = 0.5;
// A blade's area against its length times its width (the lobes' share of their box).
let BLADE_FILL: f32 = 0.45;

// The sky's ways a point is open to: up, and six round at 35° over the horizon; up counts
// twice.
let SKY_WAYS = 7;

// The grid's box: its low corner and a cell's side.
struct Grid { low: float3, cell: f32 }

// The mesh's counts and the time its parts took (measuring).
struct WoodMesh { tube_indices: i64, ribbon_first: i64, ribbon_indices: i64, vertices: i64 }

// The grid of t's leaves into `density`, GRID³ cells: each cell the leaves' extinction a
// unit of length through it. Its box over the leaves and GRID_MARGIN round.
fn crown_grid(t: Tree&, density: f32[>..]&) -> Grid {
    var lo = float3 { 1e9, 1e9, 1e9 };
    var hi = float3 { -1e9, -1e9, -1e9 };
    for &c in t.cards {
        lo = float3 { min(lo.x, c.base.x), min(lo.y, c.base.y), min(lo.z, c.base.z) };
        hi = float3 { max(hi.x, c.base.x), max(hi.y, c.base.y), max(hi.z, c.base.z) };
    }
    density.clear();
    density.resize(GRID * GRID * GRID, 0.0);
    guard t.cards.len > 0 else { return Grid { float3_0, 1.0 }; }
    lo = lo - float3 { GRID_MARGIN, GRID_MARGIN, GRID_MARGIN };
    hi = hi + float3 { GRID_MARGIN, GRID_MARGIN, GRID_MARGIN };
    let span = hi - lo;
    let cell = max(span.x, max(span.y, span.z)) / GRID;
    let g = Grid { lo, cell };
    let per = LEAF_EXTINCTION / (cell * cell * cell);
    for &c in t.cards {
        let at = cell_of(g, c.base + c.along * (c.size * 0.5));
        guard at >= 0 else { continue; }
        density[at] += c.size * c.width * BLADE_FILL * per;
    }
    return g;
}

// The cell holding p, -1 outside the grid.
fn cell_of(g: Grid, p: float3) -> i64 {
    let q = (p - g.low) / g.cell;
    guard q.x >= 0.0 && q.y >= 0.0 && q.z >= 0.0 else { return -1; }
    let i = q.x as i64;
    let j = q.y as i64;
    let k = q.z as i64;
    guard i < GRID && j < GRID && k < GRID else { return -1; }
    return (k * GRID + j) * GRID + i;
}

// The share of light reaching p along `way` (a unit vector) through the grid, from a cell
// on, so a leaf doesn't shade itself.
fn open_along(density: f32[>..]&, g: Grid, p: float3, way: float3) -> f32 {
    var depth: f32 = 0.0;
    var s = g.cell;
    let most = g.cell * GRID * 1.8;
    while s < most {
        let at = cell_of(g, p + way * s);
        guard at >= 0 else { break; }
        depth += density[at] * g.cell;
        s += g.cell;
    }
    return exp(-depth);
}

fn sky_ways() -> float3[SKY_WAYS] {
    var ways: float3[SKY_WAYS] = [float3 { 0.0, 1.0, 0.0 }; SKY_WAYS];
    let rise: f32 = 35.0;
    let up = sin(radians(rise));
    let out = cos(radians(rise));
    for k in 1..SKY_WAYS {
        let a = ((k - 1) as f32) * TAU / (SKY_WAYS - 1) + 0.3;
        ways[k] = float3 { cos(a) * out, up, sin(a) * out };
    }
    return ways;
}

// The share of the sun (toward `sun`) and of the sky reaching p.
fn crown_light(density: f32[>..]&, g: Grid, p: float3, sun: float3, ways: float3[SKY_WAYS]&) -> float2 {
    let to_sun = open_along(density, g, p, sun);
    var sky: f32 = 2.0 * open_along(density, g, p, ways[0]);
    for k in 1..SKY_WAYS { sky += open_along(density, g, p, ways[k]); }
    return float2 { to_sun, sky / (SKY_WAYS + 1) };
}

// How far a point bends with the wind: the trunk's foot not at all, up to 1 at a twig's
// tip, rising along each level (`share` how far along its branch).
fn flex_at(level: i64, share: f32) -> f32 { clamp((level + share) / LEVELS, 0.0, 1.0) }

// The wood of t (its limbs, each a chain of segments) as one mesh: the tubes' triangles
// first, then the ribbons' (the counts in the result), lit by the crown's grid (`density`
// over `g`, crown_grid) toward `sun`.
// Wound outward as the room's frame sees them (the tree's frame is the room's mirrored in
// depth, rooms::tree_origin).
fn wood_mesh(t: Tree&, density: f32[>..]&, g: Grid, sun: float3, verts: WoodVertex[>..]&, indices: u32[>..]&) -> WoodMesh {
    verts.clear();
    indices.clear();
    let ways = sky_ways();
    for &l in t.limbs {
        guard l.level < TUBE_LEVELS && l.count > 0 else { continue; }
        tube(t, density, g, sun, ways, l, verts, indices);
    }
    let ribbon_first = indices.len;
    for &l in t.limbs {
        guard l.level >= TUBE_LEVELS && l.count > 0 else { continue; }
        ribbon(t, density, g, sun, ways, l, verts, indices);
    }
    return WoodMesh { ribbon_first, ribbon_first, indices.len - ribbon_first, verts.len };
}

// A branch's way at joint i of its chain (0 its foot, count its tip): the mean of the
// segments either side.
fn joint_way(t: Tree&, l: Limb, i: i64) -> float3 {
    let first = l.first as i64;
    let last = first + l.count as i64 - 1;
    let before = t.segments[max(first + i - 1, first)];
    let after = t.segments[min(first + i, last)];
    return normalize(normalize(before.b - before.a) + normalize(after.b - after.a));
}

fn joint_at(t: Tree&, l: Limb, i: i64) -> float3 {
    if i == 0 { return t.segments[l.first as i64].a; }
    return t.segments[l.first as i64 + i - 1].b;
}

fn joint_radius(t: Tree&, l: Limb, i: i64) -> f32 {
    if i == 0 { return t.segments[l.first as i64].ra; }
    return t.segments[l.first as i64 + i - 1].rb;
}

fn tube(t: Tree&, density: f32[>..]&, g: Grid, sun: float3, ways: float3[SKY_WAYS]&, l: Limb, verts: WoodVertex[>..]&, indices: u32[>..]&) {
    let sides = TUBE_SIDES[l.level as i64];
    let joints = l.count as i64 + 1;
    // The bark's tiles round it, whole, from its foot's girth.
    let least: f32 = 1.0;
    let rounds = max(floor(TAU * joint_radius(t, l, 0) / BARK_ACROSS + 0.5), least);
    // A ring's frame carried along the branch without twisting (parallel transport).
    let way0 = joint_way(t, l, 0);
    let other = if abs(way0.y) < 0.9 { float3 { 0.0, 1.0, 0.0 } } else { float3 { 1.0, 0.0, 0.0 } };
    var side = normalize(cross(way0, other));
    var run: f32 = 0.0;
    let first = verts.len as u32;
    for i in joints {
        let p = joint_at(t, l, i);
        let r = joint_radius(t, l, i);
        let way = joint_way(t, l, i);
        side = normalize(side - way * dot(side, way));
        let up = cross(way, side);
        if i > 0 { run += length(p - joint_at(t, l, i - 1)); }
        let lit = crown_light(density, g, p, sun, ways);
        let flex = flex_at(l.level as i64, i / (joints - 1) as f32);
        for k in sides + 1 {
            let a = (k as f32) * TAU / sides;
            let n = side * cos(a) + up * sin(a);
            verts.push(WoodVertex { p + n * r, n, way, float2 { k * rounds / sides, run / BARK_ALONG },
                                    float4 { lit.x, lit.y, r, flex } });
        }
    }
    // Two triangles a side between rings, wound clockwise seen from outside in the tree's
    // frame: counterclockwise in the room's.
    let ring = (sides + 1) as u32;
    for i in joints - 1 {
        for k in sides {
            let a = first + i as u32 * ring + k as u32;
            let b = a + 1;
            let c = a + ring;
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

fn ribbon(t: Tree&, density: f32[>..]&, g: Grid, sun: float3, ways: float3[SKY_WAYS]&, l: Limb, verts: WoodVertex[>..]&, indices: u32[>..]&) {
    let joints = l.count as i64 + 1;
    // One light for the whole twig, at its middle: the grid's cells are as long.
    let lit = crown_light(density, g, joint_at(t, l, joints / 2), sun, ways);
    var run: f32 = 0.0;
    let first = verts.len as u32;
    for i in joints {
        let p = joint_at(t, l, i);
        let r = joint_radius(t, l, i);
        let way = joint_way(t, l, i);
        if i > 0 { run += length(p - joint_at(t, l, i - 1)); }
        let flex = flex_at(l.level as i64, i / (joints - 1) as f32);
        verts.push(WoodVertex { p, float3_0, way, float2 { -1.0, run / BARK_ALONG }, float4 { lit.x, lit.y, r, flex } });
        verts.push(WoodVertex { p, float3_0, way, float2 { 1.0, run / BARK_ALONG }, float4 { lit.x, lit.y, r, flex } });
    }
    for i in joints - 1 {
        let a = first + (2 * i) as u32;
        indices.push(a);
        indices.push(a + 2);
        indices.push(a + 1);
        indices.push(a + 1);
        indices.push(a + 2);
        indices.push(a + 3);
    }
}

// The leaves of t as the cards' instances (shaders::TREE_LEAF_VERT), LEAF_VEC4S float4 each:
// the blade's base and length; its axis and the card's half width against the atlas's
// (trees::Card.width over 1.15, as the atlas's leaf is that much wider than long); its face
// and which of the atlas's leaves; its tint, the sun's and the sky's share through the crown
// at its middle, and a seed of its own (0..1). Nearest the house first (z up), so a view out
// draws the near leaves before the far ones it hides.
let LEAF_VEC4S = 4;
fn leaf_cards(t: Tree&, density: f32[>..]&, g: Grid, sun: float3, out: float4[>..]&) -> i64 {
    out.clear();
    let ways = sky_ways();
    // A counting sort by the grid's z cell.
    var counts: i64[GRID + 1] = [0; GRID + 1];
    for &c in t.cards { counts[z_cell(g, c.base) + 1]++; }
    for k in 1..GRID + 1 { counts[k] += counts[k - 1]; }
    out.resize(t.cards.len * LEAF_VEC4S, float4 { 0.0, 0.0, 0.0, 0.0 });
    for &c, i in t.cards {
        let mid = c.base + c.along * (c.size * 0.5);
        let open = crown_light(density, g, mid, sun, ways);
        let seed = (((i as u64) * 2654435761) & 0xFFFF) as f32 / 65535.0;
        let at = counts[z_cell(g, c.base)] * LEAF_VEC4S;
        counts[z_cell(g, c.base)]++;
        out[at] = float4 { c.base.x, c.base.y, c.base.z, c.size };
        out[at + 1] = float4 { c.along.x, c.along.y, c.along.z, c.width / 1.15 };
        out[at + 2] = float4 { c.face.x, c.face.y, c.face.z, c.kind as f32 };
        out[at + 3] = float4 { c.tint, open.x, open.y, seed };
    }
    return t.cards.len;
}

fn z_cell(g: Grid, p: float3) -> i64 { clamp(floor((p.z - g.low.z) / g.cell) as i64, 0, GRID - 1) }

// The sun's way in the tree's frame from the map's view: a point and its shadow on the map
// lie along (shear.x, shear.y, 1) (on_map).
fn toward_sun(v: View&) -> float3 { normalize(float3 { v.shear.x, v.shear.y, 1.0 }) }

// The bark's tile, RGBA8 with its mips (bark_bytes()): RG the surface's normal across and
// along (0.5 flat), B its light and dark (the furrows dark), A where lichen grows. Shallow
// narrow ridges along the stem that part and join again (a Norway maple's), from ridged
// value noise drawn out three times along, wrapping both ways.
fn bark_tile(out: u8[>..]&) {
    out.clear();
    out.resize(bark_bytes(), 0);
    var height: f32[>..] = [];
    height.resize(BARK_W * BARK_H, 0.0);
    for j in BARK_H {
        for i in BARK_W {
            let u = (i + 0.5) / BARK_W;
            let v = (j + 0.5) / BARK_H;
            // The ridges' way wanders: a slow noise shifts them across.
            let warp = 0.08 * (wrapped_noise(17, u, v, 3, 4) - 0.5);
            let ridges = ridged(wrapped_noise(3, u + warp, v, 14, 6));
            let fine = ridged(wrapped_noise(5, u + warp * 1.5, v, 28, 14));
            height[j * BARK_W + i] = 0.7 * ridges + 0.3 * fine;
        }
    }
    for j in BARK_H {
        for i in BARK_W {
            let h = height[j * BARK_W + i];
            let dx = height[j * BARK_W + (i + 1) % BARK_W] - height[j * BARK_W + (i + BARK_W - 1) % BARK_W];
            let dy = height[((j + 1) % BARK_H) * BARK_W + i] - height[((j + BARK_H - 1) % BARK_H) * BARK_W + i];
            let u = (i + 0.5) / BARK_W;
            let v = (j + 0.5) / BARK_H;
            let blotch = wrapped_noise(23, u, v, 5, 4) * 0.7 + wrapped_noise(29, u, v, 16, 12) * 0.3;
            let lichen = clamp((blotch - 0.62) / 0.12, 0.0, 1.0) * clamp(h * 1.6, 0.0, 1.0);
            let o = (j * BARK_W + i) * 4;
            out[o] = bark_byte(0.5 - dx * 2.2);
            out[o + 1] = bark_byte(0.5 - dy * 2.2);
            out[o + 2] = bark_byte(0.35 + 0.65 * h);
            out[o + 3] = bark_byte(lichen);
        }
    }
    var from = 0;
    var w = BARK_W;
    var h = BARK_H;
    for level in 1..mips_of(BARK_W, BARK_H) {
        let to = from + w * h * 4;
        halve(out, from, to, w, h);
        w /= 2;
        h /= 2;
        from = to;
    }
}

fn bark_bytes() -> i64 { map_bytes(BARK_W, BARK_H) }

fn bark_byte(x: f32) -> u8 { (clamp(x, 0.0, 1.0) * 255.0 + 0.5) as u8 }

// A ridge where the noise crosses its middle: 1 on the ridge, 0 in the furrow between.
fn ridged(n: f32) -> f32 {
    let r = 1.0 - abs(2.0 * n - 1.0);
    return r * r;
}

// Value noise over the tile, `across` cells round and `along` along, wrapping both ways,
// 0..1, eased between the lattice's values.
fn wrapped_noise(seed: u64, u: f32, v: f32, across: i64, along: i64) -> f32 {
    let x = u * across;
    let y = v * along;
    let i = floor(x) as i64;
    let j = floor(y) as i64;
    let fx = x - i;
    let fy = y - j;
    let sx = fx * fx * (3.0 - 2.0 * fx);
    let sy = fy * fy * (3.0 - 2.0 * fy);
    let a = lattice_value(seed, i % across, j % along);
    let b = lattice_value(seed, (i + 1) % across, j % along);
    let c = lattice_value(seed, i % across, (j + 1) % along);
    let d = lattice_value(seed, (i + 1) % across, (j + 1) % along);
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy;
}

fn lattice_value(seed: u64, i: i64, j: i64) -> f32 {
    let h = mixed(seed * 0x9E3779B97F4A7C15 + (i as u64) * 0x632BE59BD9B4E019 + (j as u64) * 0x8CB92BA72F3D8DD7);
    return (h >> 40) / 16777216.0;
}

// Level `from` (w × h RGBA8 texels) averaged two by two into the next at `to`.
fn halve(out: u8[>..]&, from: i64, to: i64, w: i64, h: i64) {
    let hw = w / 2;
    let hh = h / 2;
    for y in hh {
        for x in hw {
            for c in 4 {
                let a = out[from + ((2 * y) * w + 2 * x) * 4 + c] as i64;
                let b = out[from + ((2 * y) * w + 2 * x + 1) * 4 + c] as i64;
                let e = out[from + ((2 * y + 1) * w + 2 * x) * 4 + c] as i64;
                let f = out[from + ((2 * y + 1) * w + 2 * x + 1) * 4 + c] as i64;
                out[to + (y * hw + x) * 4 + c] = ((a + b + e + f + 2) / 4) as u8;
            }
        }
    }
}
