// The room round the table, for the light's tuner first (task 104): the library's
// herringbone oak floor and the panelled wall facing the window (task 109's room), as
// data and geometry. Their oak is baked once (shaders::BAKE_FRAG's room modes) into two
// fields of boards, sawn as a joiner would pick them; each plank and each piece of the
// panelling takes its own place in a field, turned or mirrored at random, so no
// stretch of wood shows twice side by side (shaders::ROOM_FRAG lays the herringbone).
//
// The room's frame: u along the window's wall, v into the room away from it, both from
// the board's middle, as window_light places the window (rooms::Room.window). The room is
// built in it once, (u, height, v) in world units, and shaders::ROOM_VERT turns it into
// the world by the frame (frame_of) as the key's direction moves. The table and its base
// stand in the world (mesh::table).
namespace surfaces;
import std;
import vec;
import math;

// World units a metre (a square is about 3.3 cm), and the floor 0.75 m under the table's
// top (mesh::TABLE_TOP).
let METRE:   f32 = 30.48;
let FLOOR_Y: f32 = -23.56;

// What a fragment of the room is (mesh::Vertex.mat's whole part; its fraction is the
// piece's own random): the floor, a piece of oak (its uv the place in the wall's field),
// the wallpaper; the shell's (room_shell) lime plaster (its
// fraction 0.5 on the cornice, whiter and smoother), the sills' stone, white painted wood,
// glass and lace, the last two drawn blended after the rest;
// the curtains' brass and their cord; a book (books.goose: its fraction the cover, label,
// gilt or ink and fade); the stove's glazed tile (stove.goose: its fraction the glaze's part,
// stove.goose's GLAZE_*, in eighths).
let MAT_FLOOR:   f32 = 4.0;
let MAT_OAK:     f32 = 5.0;
let MAT_PAPER:   f32 = 6.0;
let MAT_STONE:   f32 = 7.0;
let MAT_PLASTER: f32 = 8.0;
let MAT_PAINT:   f32 = 9.0;
let MAT_GLASS:   f32 = 10.0;
let MAT_LACE:    f32 = 11.0;
let MAT_BRASS:   f32 = 12.0;
let MAT_CORD:    f32 = 13.0;
let MAT_BOOK:    f32 = 14.0;
let MAT_TILE:    f32 = 15.0;

// The fields' sides in texels (a phone's half), and their sizes in world units: the
// floor's 20 strips a plank wide, 1.3 m long, a texel 0.7 mm; the wall's ten boards
// 24 cm wide, 2.6 m long, a texel 1.3 mm.
let FIELD_SIDE = 2048;
let PHONE_FIELD_SIDE = 1024;
let PLANK_W: f32 = 2.134;          // 7 cm
let PLANK_N: f32 = 6.0;            // its length in widths: 42 cm
let FLOOR_STRIPS = 20;
let FLOOR_FIELD: f32 = 42.68;      // FLOOR_STRIPS × PLANK_W
let BOARD_W:     f32 = 8.0;
let WALL_BOARDS = 10;
let WALL_FIELD: f32 = 80.0;        // WALL_BOARDS × BOARD_W

// The library (task 109): the table's middle 1.2 m from the window's wall (Room.window.x),
// the hall's wall facing the window 5.8 m beyond it, the wall 9 m long, the table in
// front of its middle window, at 4.5 m.
let HALF_LONG: f32 = 137.0;
let WALL_AWAY: f32 = 177.0;
let WALL_TOP:  f32 = 122.0;        // 4 m

// An oak's bake (BAKE_FRAG's oak_at and oak_finish), each in a slot of the Bake block.
struct Oak {
    base:   float4,    // the oak's own color (sRGB) and the wax's roughness
    figure: float4,    // looks::Theme.light_fig's: how far the grain wanders, the broad
    // figure's contrast, the fibres', 1
    ring: float4,      // a year's width (world units), how flat-sawn (set a board), the
    // late wood's darkening, the early wood's pores
    stain:   float4,   // the stain's color (sRGB, what it lets through) and strength
    wax:     float4,   // the dark wax packed in the pores (sRGB) and how much
    shellac: float4,   // the amber shellac or wax over all (sRGB) and how thick
    age:     float4,   // x the light's ambering, y blotches, z grime, w the rays' fleck
    boards:  float4,   // x a board's width (world units), y the share quarter-sawn, z the
    // trees' own tones, w the relief
    tint: float4,      // the finished oak made lighter (x) and greyer or more coloured (y)
    // about its luminance, as ROOM_FRAG's tinted() does
}

// The parquet: oak gone a warm mid-dark brown under a century of wax and light, fumed,
// the pores near black (style-01's floor; library-parquet-01 is redder). Shellac and the
// light's ambering kept pale: amber over amber turned it orange (2026-11-20).
let FLOOR_OAK = Oak {
    base:    float4 { 0.76, 0.65, 0.52, 0.42 },
    figure:  float4 { 0.25, 0.22, 0.2, 1.0 },
    ring:    float4 { 0.09, 0.0, 0.15, 0.6 },
    stain:   float4 { 0.68, 0.66, 0.66, 1.8 },
    wax:     float4 { 0.09, 0.055, 0.035, 0.3 },
    shellac: float4 { 0.95, 0.91, 0.84, 1.0 },
    age:     float4 { 0.4, 0.12, 0.35, 1.0 },
    boards:  float4 { 2.134, 0.45, 0.1, 1.0 },
    tint:    float4 { 1.0, 1.0, 0.0, 0.0 },
};

// The wainscot: the same oak darker, brown with a little red, a heavier stain and older
// wax (style-01's back wall, crop-wainscot-01), then three times lighter and greyer (0.6
// of its colour), the references' lighter, greyer panelling (2026-11-21; it was the stain's
// dark red-brown, sRGB about 14, 5, 2 in style-01's shade).
let WALL_OAK = Oak {
    base:    float4 { 0.74, 0.57, 0.42, 0.4 },
    figure:  float4 { 0.25, 0.2, 0.2, 1.0 },
    ring:    float4 { 0.1, 0.0, 0.15, 0.55 },
    stain:   float4 { 0.64, 0.62, 0.62, 2.25 },
    wax:     float4 { 0.07, 0.035, 0.02, 0.4 },
    shellac: float4 { 0.93, 0.88, 0.80, 1.1 },
    age:     float4 { 0.45, 0.1, 0.4, 1.0 },
    boards:  float4 { 8.0, 0.5, 0.06, 1.0 },
    tint:    float4 { 3.0, 0.6, 0.0, 0.0 },
};

// How ROOM_FRAG lays and wears the floor and lights the wall, in its Surfaces block.
struct Look {
    plank:  float4,    // a plank's width, length in widths, the joint's half width, the cup
    planks: float4,    // x each plank's own tone, y the share patched, z its tilt, w scratches
    worn:   float4,    // x the paths' wear, y the walls' darker wax, z the path's reach
    // round the table (world units), w the path along the room
    paper: float4,     // the wallpaper's ground (sRGB) and roughness, where its mask is 0
    gold:  float4,     // its gold print (sRGB) and roughness, where the mask is 1
    // The shell's (room_shell): the limewash at its plaster tone's 0 and 1 (sRGB, and
    // roughness), the white paint, the lace's thread (and the tie-back's cord), the sills'
    // stone.
    plaster_shade: float4,
    plaster_light: float4,
    // The ceiling's and its cornice's limewash, the same two ends.
    ceiling_shade: float4,
    ceiling_light: float4,
    paint:         float4,
    // The quiet paint (room_shell's joinery): x the doors' roughness, y the windows', z the
    // recesses' dirt band (metres), w the relief tile's strength (1 the research's heights).
    paint_quiet: float4,
    lace_thread: float4,
    stone:       float4,
    // The sills' limestone (ROOM_FRAG's ROOM_SILL, its colour the stone's): x the nose's
    // arris's radius, y how far back the polished band reaches, z how much darker the nose
    // is at its foot, w the dust line's width (metres but z).
    sill: float4,
    // The curtains' brass (rod, finials, brackets, hooks): its colour at normal incidence
    // (sRGB) and roughness, all in this one place so another brass swaps in here.
    brass: float4,
    // The light of the window behind the lace, the sky and the park through the niche
    // averaged, sRGB as the view out's sky has it (shaders::OUTSIDE_FRAG), exposed as the
    // view out is (rooms::Room.outside) and lifted with the room's own exposure as the
    // room's surfaces are; w how strongly the lace's thin parts scatter the sun forward,
    // toward an eye looking through them at it.
    lace_light: float4,
}

// The wallpaper: a dark warm brown-grey paper, matte, and a muted gold print with a little
// sheen, #423831 and #58503b, as light as style-01's wall measures under the room's light;
// the ground was an olive #3d3b32 until the quick pass (2026-11-21), the baker's first
// guesses, #575d63 and #a28e6a, twice as light and bluer (2026-11-20).
let LOOK = Look {
    plank:  float4 { PLANK_W, PLANK_N, 0.016, 0.012 },
    planks: float4 { 0.2, 0.03, 0.01, 0.6 },
    worn:   float4 { 0.7, 0.5, 34.0, 0.5 },
    paper:  float4 { 0.259, 0.22, 0.192, 0.66 },
    gold:   float4 { 0.345, 0.314, 0.231, 0.52 },
    // Aged lime plaster, #beb4a3 to #d0c8b8, no brighter than an old limewash (sRGB about
    // 200 to 215, task 107's quick pass); the windows' and doors' old paint a touch greyer,
    // #c6beae; lace.py's thread, #ddd3bf, cotton; the sills a pale limestone, #b6b2a8.
    plaster_shade: float4 { 0.745, 0.706, 0.639, 0.92 },
    plaster_light: float4 { 0.816, 0.784, 0.722, 0.86 },
    // The ceiling's darker and warmer, #aa9e86 to #baaf9a: the walls' limewash at 0.75 of
    // its light and 1.5 times its colour (2026-11-21), toward library-autumn-02's amber.
    ceiling_shade: float4 { 0.6684, 0.6177, 0.5262, 0.92 },
    ceiling_light: float4 { 0.7284, 0.6867, 0.6027, 0.86 },
    paint:         float4 { 0.776, 0.745, 0.682, 0.38 },
    // Eggshell to satin, doors 0.36 and the window joinery a little duller (build/notes/
    // paint-research/), the dirt in a 3 mm band, the relief twice the research's quiet
    // heights (its brush 5 µm, its lived variant's): at those alone it reads as nothing even
    // close up in the room's light.
    paint_quiet: float4 { 0.36, 0.42, 0.003, 2.0 },
    lace_thread: float4 { 0.867, 0.827, 0.749, 0.9 },
    stone:       float4 { 0.714, 0.698, 0.659, 0.55 },
    // A Vasalemma-type limestone (build/notes/paint-research/), honed: the arris eased to
    // 4 mm, the band polished by hands 25 to 70 mm back, the nose 6 % darker at its foot (in
    // sRGB; 13 % of its linear albedo), dust before the inner casement fading over 2 cm.
    sill: float4 { 0.004, 0.07, 0.13, 0.02 },
    // A plain brass, a placeholder until the gilt and brass study's material lands: its
    // reflectance at normal incidence linear (0.91, 0.778, 0.423), #f5e4ae, 0.28 rough (a
    // polished one reads as brown felt while the room reflects only its harmonics), no wear.
    brass:      float4 { 0.959, 0.895, 0.682, 0.28 },
    lace_light: float4 { 0.86, 0.84, 0.78, 0.5 },
};

// The plaster's tone map (design/materials/plaster_tone.png) covers 4 m of wall a tile,
// the lace's 0.56 m.
let PLASTER_TILE: f32 = 4.0 * METRE;
let LACE_TILE:    f32 = 0.56 * METRE;

// The curtains' lace (design/materials/lace_*.png): the field's tile, 1024 rows over
// LACE_TILE, over the hem's strip, 384 rows (0.21 m), R8 with 8 mips (to 8 × 11); way f3
// first, the one drawn, then f2, f and d, kept for the tuner to switch to (--lace, C).
let LACE_TEXELS = int2 { 1024, 1408 };
let LACE_MIPS = 8;
let LACE_WAYS = ["f3", "f2", "f", "d"];

// The wallpaper's mask (design/materials/wallpaper_mask.png): its side in texels, and the
// square of wall one tile covers, 0.9 m, its flowers finer than style-01's 1.4 m and still
// readable (a real paper of the period repeats every 0.5 to 0.65 m, where the mask's
// flowers lose their contrast).
let PAPER_SIDE = 1024;
let PAPER_TILE: f32 = 0.9 * METRE;

// The room's frame from the key's direction toward the light and the window's wall's
// turn (shaders::LIGHT_FN's window_light): u along the wall, v into the room.
struct Frame { along: float2, into: float2 }

fn frame_of(toward: float3, turn_deg: f32) -> Frame {
    let h = normalize(float2 { toward.x, toward.z });
    let a = radians(turn_deg);
    let nw = float2 { cos(a) * h.x - sin(a) * h.y, sin(a) * h.x + cos(a) * h.y };
    return Frame { along: float2 { -nw.y, nw.x }, into: float2 { -nw.x, -nw.y } };
}

// A small hash, 0..1, of a piece's number and a key.
fn hash(i: i64, k: i64) -> f32 {
    var x = (i * 374761393 + k * 668265263) as u64;
    x = (x ^ (x >> 13)) * 1274126177;
    x = x ^ (x >> 16);
    return (x & 0xFFFFFF) / 16777216.0;
}

// Where a piece lies in the wall's field: fx = o.x + m.x s + m.y t, fy = o.y + m.z s + m.w t,
// s along the wall and t up (or out, on a top face), the field's y along the grain.
struct Map { o: float2, m: float4 }

// The map of a piece `across` wide and `along` long whose corner is at (s0, t0), its
// grain up (vertical) or along the wall: a board of the field picked by `seed` (a
// quarter-sawn one, even, where `quarter`), a place in it, and mirrored either way.
fn piece_map(seed: i64, vertical: bool, s0: f32, t0: f32, across: f32, along: f32, quarter: bool) -> Map {
    var fx: f32 = 0.0;
    if across < BOARD_W - 0.5 {
        var b = (hash(seed, 1) * WALL_BOARDS) as i64 % WALL_BOARDS;
        if quarter { b = b - b % 2; }
        fx = b * BOARD_W + 0.2 + hash(seed, 2) * (BOARD_W - across - 0.4);
    } else {
        fx = hash(seed, 2) * (WALL_FIELD - across - 0.2);
    }
    let fy = hash(seed, 3) * (WALL_FIELD - along - 0.2);
    let sa: f32 = if hash(seed, 4) < 0.5 { 1.0 } else { -1.0 };
    let sl: f32 = if hash(seed, 5) < 0.5 { 1.0 } else { -1.0 };
    let ox = if sa > 0.0 { fx } else { fx + across };
    let oy = if sl > 0.0 { fy } else { fy + along };
    if vertical {
        // across = s - s0, along = t - t0
        return Map { float2 { ox - sa * s0, oy - sl * t0 }, float4 { sa, 0.0, 0.0, sl } };
    }
    return Map { float2 { ox - sa * t0, oy - sl * s0 }, float4 { 0.0, sa, sl, 0.0 } };
}

fn place(m: Map, s: f32, t: f32) -> float2 {
    float2 { m.o.x + m.m.x * s + m.m.y * t, m.o.y + m.m.z * s + m.m.w * t }
}

// The wall's sizes in world units, its local frame: s along it, y up from the floor, z
// out from the wall's plane into the room.
let PLINTH_H:  f32 = 4.6;          // the skirting, 15 cm
let PLINTH_Z:  f32 = 1.05;
let FRAME_Z:   f32 = 0.75;         // the stiles' and rails' face
let RAIL_LOW:  f32 = 8.3;          // the bottom rail's top
let RAIL_HIGH: f32 = 28.0;         // the top rail's foot
let CAP_LOW:   f32 = 31.4;
let CAP_TOP:   f32 = 32.0;         // 1.05 m
let CAP_Z:     f32 = 1.7;
let STILE_W:   f32 = 3.0;          // 9 cm
let BAY:       f32 = 18.0;         // a panel and a stile, about 55 cm

// The geometry's corners: the wall's local s, y, z, s along it from `o` (the room's u and
// v) in the direction `d`, z out of it into the room along `n`; its panelling's top, the
// cap's (the sill's on the window's wall), dy over CAP_TOP, its cap `deep` times as deep.
struct Builder {
    o:    float2,
    d:    float2,
    n:    float2,
    dy:   f32,
    deep: f32,
}

fn world(b: Builder, s: f32, y: f32, z: f32) -> float3 {
    let uv = b.o + b.d * s + b.n * z;
    return float3 { uv.x, FLOOR_Y + y, uv.y };
}

fn world_normal(b: Builder, n: float3) -> float3 {
    let uv = b.d * n.x + b.n * n.z;
    return normalize(float3 { uv.x, n.y, uv.y });
}

// A quad of the wall's corners p (s, y, z), facing out of the wall (or toward `side`
// where it stands square to the wall), its field places, occlusion, and material.
fn quad(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: Builder, p: float3[4], uv: float2[4], ao: f32[4], mat: f32,
        side: float3 = float3 { 0.0, 0.0, 1.0 }) {
    var n = normalize(cross(p[1] - p[0], p[3] - p[0]));
    let facing = if abs(n.z) > 0.01 { n.z } else { dot(n, side) };
    if facing < 0.0 { n = n * -1.0; }
    let base = verts.len as u32;
    let wn = world_normal(b, n);
    for i in 4 { verts.push(mesh::Vertex { world(b, p[i].x, p[i].y, p[i].z), wn, uv[i], ao[i], mat }); }
    indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
}

// Profiles shade as curves (agents/design.md): a point's normal is its two segments' mean
// where they turn by less than CREASE's angle, and a segment's own at a sharper turn.
let CREASE: f32 = 0.8;  // cos 37°

// The normal at a profile's point between segments of normals a and c (zero for a segment
// of no length): their mean where they turn less than CREASE, else a, the segment's own.
fn smooth_normal(a: float3, c: float3, crease: f32 = CREASE) -> float3 {
    guard length_sq(a) > 0.0 && length_sq(c) > 0.0 && dot(a, c) > crease else { return a; }
    return normalize(a + c);
}

// A profile (z, y, occlusion, top to bottom over its front) swept along the wall from s0
// to s1, the grain along the wall: each strip a quad, its field across the profile's length.
// The profile is raised by dy and drawn `deep` times as deep where it stands out past the
// frame (the cap's nose).
fn strip(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: Builder, prof: float3[], s0: f32, s1: f32, seed: i64,
         dy: f32 = 0.0, deep: f32 = 1.0) {
    var pts: float3[..32] = [];
    for q in prof { pts.push(float3 { if q.x > FRAME_Z { FRAME_Z + (q.x - FRAME_Z) * deep } else { q.x }, q.y + dy, q.z }); }
    var total: f32 = 0.0;
    for k in 1..pts.len { total += length(float2 { pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y }); }
    let m = piece_map(seed, false, s0, 0.0, total, s1 - s0, true);
    let own = MAT_OAK + 0.9 * hash(seed, 9);
    // Each segment's normal out of the wall, (-t.y, t.x) in (z, y).
    var flat: float3[..32] = [float3_0];
    for k in 1..pts.len {
        let d = float2 { pts[k].x - pts[k - 1].x, pts[k].y - pts[k - 1].y };
        flat.push(if length(d) > 0.000001 { normalize(float3 { 0.0, d.x, -d.y }) } else { float3_0 });
    }
    var t: f32 = 0.0;
    for k in 1..pts.len {
        let a = pts[k - 1];
        let c = pts[k];
        let t1 = t + length(float2 { c.x - a.x, c.y - a.y });
        let n = flat[k];
        let na = world_normal(b, if k > 1 { smooth_normal(n, flat[k - 1]) } else { n });
        let nc = world_normal(b, if k + 1 < pts.len { smooth_normal(n, flat[k + 1]) } else { n });
        let base = verts.len as u32;
        verts.push(mesh::Vertex { world(b, s0, a.y, a.x), na, place(m, s0, t), a.z, own });
        verts.push(mesh::Vertex { world(b, s1, a.y, a.x), na, place(m, s1, t), a.z, own });
        verts.push(mesh::Vertex { world(b, s1, c.y, c.x), nc, place(m, s1, t1), c.z, own });
        verts.push(mesh::Vertex { world(b, s0, c.y, c.x), nc, place(m, s0, t1), c.z, own });
        indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
        t = t1;
    }
}

// A flat piece of the frame (a stile or a rail) over s0..s1, y0..y1 at FRAME_Z.
fn board(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: Builder, s0: f32, s1: f32, y0: f32, y1: f32,
         vertical: bool, seed: i64, ao_low: f32 = 1.0) {
    let m = if vertical { piece_map(seed, true, s0, y0, s1 - s0, y1 - y0, true) }
            else { piece_map(seed, false, s0, y0, y1 - y0, s1 - s0, true) };
    let p:  float3[4] = [float3 { s0, y0, FRAME_Z }, float3 { s1, y0, FRAME_Z }, float3 { s1, y1, FRAME_Z }, float3 { s0, y1, FRAME_Z }];
    let uv: float2[4] = [place(m, s0, y0), place(m, s1, y0), place(m, s1, y1), place(m, s0, y1)];
    quad(verts, indices, b, p, uv, [ao_low, ao_low, 1.0, 1.0], MAT_OAK + 0.9 * hash(seed, 9));
}

// board's piece cut along at `xs` and up at `ys` (the places inside its edges, in order),
// where another piece's corner lies on its edges: the library's stiles where the rails and
// panels meet them, its rails and stiles where the plinth's and cap's lengths join over
// them. An edge without a vertex where another piece's corner lies on it rasterizes apart
// from that piece's and leaves pinholes, the view out shining through them on the dark
// oak (2026-11-23). The cells share their vertices, so the corners' map takes the piece as
// one chart as before, and its places, occlusion and normal are affine across it, so they
// interpolate as board's do.
fn board_cut(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: Builder, s0: f32, s1: f32, y0: f32, y1: f32,
             vertical: bool, seed: i64, xs: f32[], ys: f32[], ao_low: f32 = 1.0) {
    let m = if vertical { piece_map(seed, true, s0, y0, s1 - s0, y1 - y0, true) }
            else { piece_map(seed, false, s0, y0, y1 - y0, s1 - s0, true) };
    let n = normalize(cross(float3 { s1 - s0, 0.0, 0.0 }, float3 { 0.0, y1 - y0, 0.0 }));
    let wn = world_normal(b, n);
    let own = MAT_OAK + 0.9 * hash(seed, 9);
    let base = verts.len as u32;
    let across = xs.len + 2;
    for j in ys.len + 2 {
        let y = if j == 0 { y0 } else if j == ys.len + 1 { y1 } else { ys[j - 1] };
        let ao = if j == 0 { ao_low } else if j == ys.len + 1 { 1.0 } else { ao_low + (1.0 - ao_low) * (y - y0) / (y1 - y0) };
        for i in across {
            let s = if i == 0 { s0 } else if i == xs.len + 1 { s1 } else { xs[i - 1] };
            verts.push(mesh::Vertex { world(b, s, y, FRAME_Z), wn, place(m, s, y), ao, own });
        }
    }
    let row = across as u32;
    for j in ys.len + 1 {
        for i in across - 1 {
            let a = base + ((j * across + i) as u32);
            indices.append([a, a + 1, a + row + 1, a, a + row + 1, a + row]);
        }
    }
}

// The raised and fielded panel in an opening x0..x1, y0..y1 of the frame: the frame's
// stuck ovolo moulding round it, the panel's bevel rising from its thin edge, a fillet,
// and the flat field. Each ring of the profile is four mitred strips.
let PANEL_IN: f32[8] = [0.0, 0.1, 0.22, 0.32, 0.34, 1.5, 1.5, 1.5];
let PANEL_Z:  f32[8] = [0.75, 0.71, 0.56, 0.32, 0.22, 0.48, 0.56, 0.56];
let PANEL_AO: f32[8] = [1.0, 0.97, 0.85, 0.62, 0.55, 0.93, 0.97, 1.0];
fn panel(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: Builder, x0: f32, x1: f32, y0: f32, y1: f32,
         seed: i64, rail_low: Map, rail_high: Map, stile_left: Map, stile_right: Map) {
    panel_ring(verts, indices, b, x0, x1, y0, y1, seed, rail_low, rail_high, stile_left, stile_right, PANEL_IN, PANEL_Z,
               PANEL_AO);
}

// The panels' rings (the tuner's --panel-ao): `panel_ao_scale` of what each ring point's
// occlusion takes off, the groove's dip held to `panel_ao_width` (world units) up the bevel,
// where a point of the bevel's top occlusion is put in, so the dip is a thin line, not a
// ramp across the whole bevel (0: across it); `panel_crease`, the rings' crease (cos 32°:
// the wainscot's bevel a flat facet, the ovolo's 30° turns still smooth; over 1 every facet
// flat); the bevel's width times `panel_bevel`, the field growing by what it loses.
var panel_ao_scale: f32 = 0.6;
var panel_ao_width: f32 = 0.004 * METRE;
var panel_crease:   f32 = 0.85;
var panel_bevel:    f32 = 1.0;
// A ring's step narrower than this (world units, 5 mm) shades as its neighbours do.
let THIN_STEP: f32 = 0.005 * METRE;

// The panel with a ring of its own: eight points in from the opening's edge, out from
// the wall, and their occlusion, the first four segments the frame's moulding, the last
// point the field's corner.
fn panel_ring(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: Builder, x0: f32, x1: f32, y0: f32, y1: f32,
              seed: i64, rail_low: Map, rail_high: Map, stile_left: Map, stile_right: Map, ring_in8: f32[8], ring_z8: f32[8],
              ring_ao8: f32[8]) {
    let pm = piece_map(seed, true, x0, y0, x1 - x0, y1 - y0, hash(seed, 7) < 0.5);
    let own = MAT_OAK + 0.9 * hash(seed, 9);
    // The ring, with a point put in up the bevel (segment 4, from the groove's foot) where
    // the occlusion's dip is narrowed.
    var ring_in: f32[..12] = [];
    var ring_z:  f32[..12] = [];
    var ring_ao: f32[..12] = [];
    let shift = (panel_bevel - 1.0) * (ring_in8[5] - ring_in8[4]);
    for i in 8 {
        ring_in.push(ring_in8[i] + (if i >= 5 { shift } else { 0.0 }));
        ring_z.push(ring_z8[i]);
        ring_ao.push(1.0 - panel_ao_scale * (1.0 - ring_ao8[i]));
        let wide = ring_in8[5] + shift - ring_in8[4];
        if i == 4 && panel_ao_width > 0.0 && wide > panel_ao_width {
            let t = panel_ao_width / wide;
            ring_in.push(ring_in8[4] + wide * t);
            ring_z.push(ring_z8[4] + (ring_z8[5] - ring_z8[4]) * t);
            ring_ao.push(1.0 - panel_ao_scale * (1.0 - ring_ao8[5]));
        }
    }
    let rings = ring_in.len;
    let last = rings - 1;
    // Each ring's normal on each side, as quad() works it out, then smoothed across the
    // rings where they turn gently: the moulding's ovolo and bead shade as curves.
    let outs: float3[4] = [float3 { 0.0, -1.0, 0.0 }, float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, 1.0, 0.0 }, float3 { -1.0, 0.0, 0.0 }];
    var flat: float3[4][12] = [[float3_0; 4]; 12];
    for k in last {
        let a = ring_in[k];
        let c = ring_in[k + 1];
        let za = ring_z[k];
        let zc = ring_z[k + 1];
        // Each side's profile across: in by (c - a) from the side, out of the wall by (zc - za).
        for o, i in outs {
            let d = float2 { c - a, zc - za };
            if length(d) > 0.000001 { flat[k][i] = normalize(float3 { o.x * d.y, o.y * d.y, d.x }); }
        }
    }
    for i in 4 { flat[last][i] = float3 { 0.0, 0.0, 1.0 }; }
    for k in last {
        let a = ring_in[k];
        let c = ring_in[k + 1];
        let za = ring_z[k];
        let zc = ring_z[k + 1];
        let oa = ring_ao[k];
        let oc = ring_ao[k + 1];
        let moulding = k < 4;
        // bottom, right, top, left
        let sides: float3[4][4] = [
            [float3 { x0 + a, y0 + a, za }, float3 { x1 - a, y0 + a, za }, float3 { x1 - c, y0 + c, zc }, float3 { x0 + c, y0 + c, zc }],
            [float3 { x1 - a, y0 + a, za }, float3 { x1 - a, y1 - a, za }, float3 { x1 - c, y1 - c, zc }, float3 { x1 - c, y0 + c, zc }],
            [float3 { x1 - a, y1 - a, za }, float3 { x0 + a, y1 - a, za }, float3 { x0 + c, y1 - c, zc }, float3 { x1 - c, y1 - c, zc }],
            [float3 { x0 + a, y1 - a, za }, float3 { x0 + a, y0 + a, za }, float3 { x0 + c, y0 + c, zc }, float3 { x0 + c, y1 - c, zc }],
        ];
        for q, i in sides {
            let m = if !moulding { pm } else if i == 0 { rail_low } else if i == 2 { rail_high }
                    else if i == 1 { stile_right } else { stile_left };
            var uv: float2[4] = [float2_0; 4];
            for j in 4 { uv[j] = place(m, q[j].x, q[j].y); }
            let n = flat[k][i];
            if length_sq(n) == 0.0 {
                quad(verts, indices, b, q, uv, [oa, oa, oc, oc], own, outs[i]);
                continue;
            }
            // The next facet with a length (past a step's zero one, the wainscot's field).
            let next = if k + 2 <= last && length_sq(flat[k + 1][i]) == 0.0 { flat[k + 2][i] } else { flat[k + 1][i] };
            var na = world_normal(b, if k > 0 { smooth_normal(n, flat[k - 1][i], panel_crease) } else { n });
            var nc = world_normal(b, smooth_normal(n, next, panel_crease));
            // A step narrower than THIN_STEP with a crease each side (the doors' fillet, the
            // wainscot's riser into the field) shades from the facet before it to the one after:
            // its own sharp normal, a fraction of a pixel wide, rasterized as a dashed line.
            let wide = length(float2 { c - a, zc - za });
            if k > 0 && wide < THIN_STEP && length_sq(next) > 0.0 && dot(n, flat[k - 1][i]) <= panel_crease
               && dot(n, next) <= panel_crease {
                na = world_normal(b, flat[k - 1][i]);
                nc = world_normal(b, next);
            }
            let base = verts.len as u32;
            let ns: float3[4] = [na, na, nc, nc];
            let ao: f32[4]    = [oa, oa, oc, oc];
            for j in 4 { verts.push(mesh::Vertex { world(b, q[j].x, q[j].y, q[j].z), ns[j], uv[j], ao[j], own }); }
            indices.append([base, base + 1, base + 2, base, base + 2, base + 3]);
        }
    }
    let f = ring_in[last];
    let z = ring_z[last];
    let p: float3[4] = [float3 { x0 + f, y0 + f, z }, float3 { x1 - f, y0 + f, z }, float3 { x1 - f, y1 - f, z }, float3 { x0 + f, y1 - f, z }];
    var uv: float2[4] = [float2_0; 4];
    for j in 4 { uv[j] = place(pm, p[j].x, p[j].y); }
    quad(verts, indices, b, p, uv, [1.0, 1.0, 1.0, 1.0], own);
}

// The skirting's profile and the cap's, (z, y, occlusion) over their fronts.
let PLINTH: float3[4] = [float3 { 0.75, 4.6, 0.8 }, float3 { 0.95, 4.45, 0.95 }, float3 { 1.05, 4.1, 1.0 }, float3 { 1.05, 0.0, 0.7 }];
let CAP: float3[9] = [
    float3 { 0.0, 32.0, 0.9 }, float3 { 1.4, 32.0, 1.0 }, float3 { 1.61, 31.91, 1.0 }, float3 { 1.7, 31.7, 1.0 },
    float3 { 1.61, 31.49, 0.95 }, float3 { 1.4, 31.4, 0.85 }, float3 { 1.0, 31.4, 0.75 },
    float3 { 0.88, 31.25, 0.7 }, float3 { 0.75, 31.1, 0.65 },
];

// The panelling along a wall (b): stiles the whole height between the skirting and the
// cap, the rails between them, a panel in each bay; the skirting and the cap in lengths
// of two bays, their joints between each other's. seed is the wall's first piece's.
fn wainscot(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: Builder, first: i64) {
    let bays = floor(2.0 * HALF_LONG / BAY) as i64;
    let bay = 2.0 * HALF_LONG / bays;
    let half = 0.5 * STILE_W;
    let cap_low = CAP_LOW + b.dy;
    let rail_high = RAIL_HIGH + b.dy;
    var seed = first;
    var prev_right = Map { float2_0, float4_0 };
    for k in bays + 1 {
        let s = -HALF_LONG + bay * k;
        let s0 = max(s - half, -HALF_LONG);
        let s1 = min(s + half, HALF_LONG);
        seed++;
        let stile = piece_map(seed, true, s0, PLINTH_H, s1 - s0, cap_low - PLINTH_H, true);
        board(verts, indices, b, s0, s1, PLINTH_H, cap_low, true, seed);
        if k > 0 {
            let x0 = -HALF_LONG + bay * (k - 1) + half;
            let x1 = s - half;
            seed++;
            let low = piece_map(seed, false, x0, PLINTH_H, RAIL_LOW - PLINTH_H, x1 - x0, true);
            board(verts, indices, b, x0, x1, PLINTH_H, RAIL_LOW, false, seed, 0.8);
            seed++;
            let high = piece_map(seed, false, x0, rail_high, cap_low - rail_high, x1 - x0, true);
            board(verts, indices, b, x0, x1, rail_high, cap_low, false, seed, 0.9);
            seed++;
            panel(verts, indices, b, x0, x1, RAIL_LOW, rail_high, seed, low, high, prev_right, stile);
        }
        prev_right = stile;
    }
    var s = -HALF_LONG;
    var at = 0;
    while s < HALF_LONG {
        let e = min(-HALF_LONG + bay * (2 * at + 1) + 0.5 * bay, HALF_LONG);
        seed++;
        strip(verts, indices, b, PLINTH[..], s, e, seed);
        s = e;
        at++;
    }
    s = -HALF_LONG;
    at = 0;
    while s < HALF_LONG {
        let e = min(-HALF_LONG + bay * (2 * at + 2), HALF_LONG);
        seed++;
        strip(verts, indices, b, CAP[..], s, e, seed, b.dy, b.deep);
        s = e;
        at++;
    }
}

// The floor, the panelled wall facing the window `away` into the room with the wallpaper
// over it to WALL_TOP, the window's wall at v = -window_v panelled up to the sill
// (`sill`, over the board's top, rooms::Room.window.z) and open above, as if all window.
fn build(verts: mesh::Vertex[>..]&, indices: u32[>..]&, away: f32, window_v: f32, sill: f32) {
    // The floor: one quad, its uv the room's u and v (ROOM_FRAG lays the planks).
    floor_quad(verts, indices, float2 { -HALF_LONG, -window_v }, float2 { HALF_LONG, away });
    let hall = Builder { float2 { 0.0, away }, float2 { 1.0, 0.0 }, float2 { 0.0, -1.0 }, 0.0, 1.0 };
    wainscot(verts, indices, hall, 100);
    let window = Builder { float2 { 0.0, -window_v }, float2 { 1.0, 0.0 }, float2 { 0.0, 1.0 },
                           clamp(sill - FLOOR_Y, 16.0, CAP_TOP) - CAP_TOP, 2.5 };
    wainscot(verts, indices, window, 500);
    // The wallpaper, its uv along the wall and up it (ROOM_FRAG tiles its mask).
    let pp: float3[4] = [float3 { -HALF_LONG, CAP_TOP, 0.0 }, float3 { HALF_LONG, CAP_TOP, 0.0 },
                         float3 { HALF_LONG, WALL_TOP, 0.0 }, float3 { -HALF_LONG, WALL_TOP, 0.0 }];
    let puv: float2[4] = [float2 { -HALF_LONG, CAP_TOP }, float2 { HALF_LONG, CAP_TOP },
                          float2 { HALF_LONG, WALL_TOP }, float2 { -HALF_LONG, WALL_TOP }];
    quad(verts, indices, hall, pp, puv, [0.8, 0.8, 1.0, 1.0], MAT_PAPER);
}

// The floor over the room's u and v from `low` to `high`, one quad, its uv the room's u
// and v (ROOM_FRAG lays the planks).
fn floor_quad(verts: mesh::Vertex[>..]&, indices: u32[>..]&, low: float2, high: float2) {
    let fb = verts.len as u32;
    let corners: float2[4] = [low, float2 { high.x, low.y }, high, float2 { low.x, high.y }];
    for c in corners { verts.push(mesh::Vertex { float3 { c.x, FLOOR_Y, c.y }, float3 { 0.0, 1.0, 0.0 }, c, 1.0, MAT_FLOOR }); }
    indices.append([fb, fb + 1, fb + 2, fb, fb + 2, fb + 3]);
}

// The floor's slow noises (shaders::ROOM_FRAG's floor_noise), a world unit a texel over
// FLOOR_NOISE_SIDE units round the board's middle, RG8: r the wear's patchiness, two value
// noises, g the wax's patches, one; made once so the floor reads them rather than working
// out three noises a pixel. The noises are the shader's (h12, vnoise), at each texel's middle.
let FLOOR_NOISE_SIDE = 1024;

// The shader's h12 at the lattice point (x, y).
fn floor_hash(x: f32, y: f32) -> f32 {
    let a = fract(x * 0.1031);
    let b = fract(y * 0.1031);
    let d = a * (b + 33.33) + b * (a + 33.33) + a * (a + 33.33);
    return fract((a + d + b + d) * (a + d));
}

// The shader's vnoise at (x, y), the lattice's hashes from `lat` (its corner at (x0, y0),
// `w` across).
fn floor_vnoise(lat: f32[:], x0: f32, y0: f32, w: i64, x: f32, y: f32) -> f32 {
    let ix = floor(x);
    let iy = floor(y);
    let fx = x - ix;
    let fy = y - iy;
    let ux = fx * fx * (3.0 - 2.0 * fx);
    let uy = fy * fy * (3.0 - 2.0 * fy);
    let k = ((iy - y0) as i64) * w + (ix - x0) as i64;
    let a = lat[k];
    let b = lat[k + 1];
    let c = lat[k + w];
    let d = lat[k + w + 1];
    let low = a + (b - a) * ux;
    return low + (c + (d - c) * ux - low) * uy;
}

// One noise's lattice over the texels' span: scale and offset as the shader takes uv.
fn floor_lattice(lat: f32[>..]&, scale: f32, offset: f32) -> f32, i64 {
    let half: f32 = FLOOR_NOISE_SIDE / 2;
    let x0 = floor(-half * scale + offset) - 1.0;
    let w = (FLOOR_NOISE_SIDE * scale) as i64 + 4;
    lat.resize(w * w, 0.0);
    for j in w {
        for i in w { lat[j * w + i] = floor_hash(x0 + i, x0 + j); }
    }
    return x0, w;
}

fn floor_noise(out: u8[>..]&) {
    let n = FLOOR_NOISE_SIDE;
    out.resize(2 * n * n, 0);
    var a: f32[>..] = [];
    var b: f32[>..] = [];
    var c: f32[>..] = [];
    let a0, aw = floor_lattice(a, 0.05, 3.3);
    let b0, bw = floor_lattice(b, 0.19, 7.1);
    let c0, cw = floor_lattice(c, 0.045, 17.0);
    for y in n {
        let v: f32 = y + 0.5 - n / 2;
        for x in n {
            let u: f32 = x + 0.5 - n / 2;
            let patchy = 0.6 * floor_vnoise(a, a0, a0, aw, u * 0.05 + 3.3, v * 0.05 + 3.3)
                       + 0.4 * floor_vnoise(b, b0, b0, bw, u * 0.19 + 7.1, v * 0.19 + 7.1);
            let patches = floor_vnoise(c, c0, c0, cw, u * 0.045 + 17.0, v * 0.045 + 17.0);
            out[2 * (y * n + x)] = (clamp(patchy, 0.0, 1.0) * 255.0 + 0.5) as u8;
            out[2 * (y * n + x) + 1] = (clamp(patches, 0.0, 1.0) * 255.0 + 0.5) as u8;
        }
    }
}

// The floor's scratches as a repeating tile (shaders::ROOM_FRAG reads it):
// SCRATCH_TILE world units square (1.57 m), the shader's scratches (shaders::ROOM_FRAG's
// scratches, 1.5 units a cell, its hashes of the cell taken round the tile) drawn as how much
// of each texel they cover, then the mips, each texel the mean of four, R8.
let SCRATCH_SIDE = 2048;
let SCRATCH_MIPS = 12;
let SCRATCH_TILE: f32 = 48.0;
let SCRATCH_CELL: f32 = 1.5;

// How much of a texel `t` wide at distance d a line `half_w` either side of 0 covers.
fn line_cover(d: f32, half_w: f32, t: f32) -> f32 {
    return clamp((min(d + 0.5 * t, half_w) - max(d - 0.5 * t, -half_w)) / t, 0.0, 1.0);
}

fn scratch_tile(out: u8[>..]&) {
    let n = SCRATCH_SIDE;
    let t = SCRATCH_TILE / n;
    let cells = (SCRATCH_TILE / SCRATCH_CELL) as i64;
    var cover: f32[>..] = [];
    cover.resize(n * n, 0.0);
    for cy in cells {
        for cx in cells {
            let ix: f32 = cx;
            let iy: f32 = cy;
            let c = float2 { (ix + floor_hash(ix + 0.3, iy + 0.3)) * SCRATCH_CELL, (iy + floor_hash(ix + 5.9, iy + 5.9)) * SCRATCH_CELL };
            let ang = (floor_hash(ix + 2.1, iy + 2.1) - 0.5) * (if floor_hash(ix + 8.4, iy + 8.4) < 0.7 { 0.8 } else { 3.1 });
            let dir = float2 { cos(ang), sin(ang) };
            let half_len = 0.2 + 0.7 * floor_hash(ix + 4.6, iy + 4.6);
            let half_w = 0.004 + 0.004 * floor_hash(ix + 6.2, iy + 6.2);
            let reach = half_len + half_w + t;
            let x0 = floor((c.x - reach) / t) as i64;
            let x1 = floor((c.x + reach) / t) as i64;
            let y0 = floor((c.y - reach) / t) as i64;
            let y1 = floor((c.y + reach) / t) as i64;
            for y in y0..y1 + 1 {
                for x in x0..x1 + 1 {
                    let px: f32 = x;
                    let py: f32 = y;
                    let d = float2 { (px + 0.5) * t - c.x, (py + 0.5) * t - c.y };
                    let along = clamp(d.x * dir.x + d.y * dir.y, -half_len, half_len);
                    let off = float2 { d.x - dir.x * along, d.y - dir.y * along };
                    let k = ((y % n + n) % n) * n + (x % n + n) % n;
                    cover[k] = max(cover[k], line_cover(sqrt(off.x * off.x + off.y * off.y), half_w, t));
                }
            }
        }
    }
    var size = 0;
    for level in SCRATCH_MIPS { size += (n >> level) * (n >> level); }
    out.resize(size, 0);
    var at = 0;
    var w = n;
    for level in SCRATCH_MIPS {
        if level > 0 {
            // Each texel the mean of four of the level above, in place.
            let up = w;
            w = w / 2;
            for y in w {
                for x in w {
                    cover[y * w + x] = 0.25 * (cover[2 * y * up + 2 * x] + cover[2 * y * up + 2 * x + 1]
                                               + cover[(2 * y + 1) * up + 2 * x] + cover[(2 * y + 1) * up + 2 * x + 1]);
                }
            }
        }
        for i in w * w { out[at + i] = (cover[i] * 255.0 + 0.5) as u8; }
        at += w * w;
    }
}
