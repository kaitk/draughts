// The library's light baked once when the room turns on and again when the sun moves
// (task 107's light round): what reaches each point of the room besides the sun itself,
// on a grid of probes 0.3 m apart over the shell (room_shell::LIBRARY). Its sources: the
// sky seen through the three windows, only through each niche's outline and past the
// lace, the table's top shading what is under it; the sun's patches thrown back off the
// floor, the walls, the sills and the reveals, each patch's light from the sun's rays
// traced through the glass; and the light the room throws on after that, bounced
// BOUNCES times between the cells of a coarse grid over its surfaces (the sky's light
// landing on the floor, the sills and reveals, the lit ceiling, the backlit lace), which
// the probes gather on a grid of half their density. Each probe keeps, per colour, the
// light as a constant and a direction (the first two bands of spherical harmonics, the
// clamped cosine folded in), so ROOM_FRAG reads a surface's light for its normal from two
// texels a colour; the probes a wall, the floor or the ceiling reads give that surface's
// normal its light exactly (settle). tools/path_trace.goose traces the room to judge the
// bake against. No graphics: render3d puts the result on the GPU.
//
// The plan's metres (room_shell): x along the window wall, y from the hall wall, h up.
// The probes and their directions are in the room's frame (world units: x along u, y up,
// z along v, the table at 0), as ROOM_VERT's v_local is.
namespace room_light;
import std;
import vec;
import math;

// The probes' grid, half a step in from every wall, the floor and the ceiling, so none
// lies in a surface and a surface's lookup half a step out along its normal lands on the
// row in front of it: x from the far end (plan x 9) to the stove's end in NX steps, z
// from the window wall's niches (plan y 7.45) to the hall wall in NZ, up from the floor
// in NH.
let NX = 30;
let NZ = 26;
let NH = 13;
let CELL:    f32 = 0.3;       // metres between probes
let INSET:   f32 = 0.15;      // the first probe's distance in from the far end and the floor
let PLAN_Y0: f32 = 7.45;      // the probes' first row, in the niches (the wall's face at 7)
let PROBES = 10140;           // NX × NZ × NH

// The atlas the probes go into: the height's slices side by side (NX × NH across), the
// three colours' blocks one over the other (3 × NZ up), four floats a texel: the constant
// and the direction's x, y, z in the room's frame.
let ATLAS_W = 390;            // NX × NH
let ATLAS_H = 78;             // 3 × NZ
let ATLAS_FLOATS = 121680;    // ATLAS_W × ATLAS_H × 4
// The props' atlas (TABLE_FRAG's PROPS_LIGHT, the desktop's tiers): each probe's light as nine
// harmonics, the first three bands of the same light the room's atlas holds before its
// settle, their rgb one after another in PROPS_BLOCKS texels (27 floats in 28): the
// constant, the direction's x, y and z, then the second band's five (props_band). Its
// blocks as the room's atlas's colours, one over the other. Made only with nine_harmonics.
let PROPS_BLOCKS = 7;
let PROPS_H = 182;            // PROPS_BLOCKS × NZ
let PROPS_FLOATS = 283920;    // ATLAS_W × PROPS_H × 4
var nine_harmonics = false;

// The sun's rays traced through each window's glazing: RAYS_X across, RAYS_Y up.
let RAYS_X = 12;
let RAYS_Y = 30;
let RAYS = 1080;              // 3 windows × RAYS_X × RAYS_Y

// The sky's samples on each window's glass: SKY_X across, SKY_Y up.
let SKY_X = 4;
let SKY_Y = 10;

// The glazing at the inner glass: its half width and its edges over the sill and under
// the head (shaders::casement's blind frame), and what its bars and two panes let through
// on the whole.
let GLAZED_HALF: f32 = 0.49;
let GLAZED_LOW:  f32 = 0.03;
let GLAZED_HIGH: f32 = 0.06;
let GLAZING:     f32 = 0.78;
// What the bake takes for it (the tuner's --light physical: PHYSICAL_GLAZING, the two panes
// of 0.92 the path tracer takes in place of the 0.88 GLAZING was made with, the bars kept).
var glazing: f32 = GLAZING;
let PHYSICAL_GLAZING: f32 = 0.75;
// The sun's rays and the sky's samples (sky_through) traced through the casements' own
// members (room_shell::casement_members: the frames, sashes and bars with their depth, which
// at a low sun hide much of what is open square on) in place of the glazing's share; then
// only the two panes, PANES, stand for the glass (the tuner's --light physical). Each sun
// ray's cell is sampled MEMBER_SAMPLES² times.
var members_traced = false;
let PANES: f32 = 0.8464;
let MEMBER_SAMPLES = 8;
// What the lace lets through where it hangs before the niche (its thread lets 0.45 of the
// sun through where it covers, and it covers about half).
let LACE_LETS: f32 = 0.72;
// Where the panel hangs at 2× fullness (1.2 m of cloth on 0.55 m, its width at the rod)
// the lace lets LACE_LETS through; gathered narrower toward the tie, more layers of it lie
// in a ray's way, so less: LACE_LETS to the power of how many times narrower it is (about
// a third at the tie, 0.72 at the rod, 0.6 at the hem).
let LACE_FLAT_WIDTH: f32 = 0.55;
fn lace_lets(h: f32) -> f32 {
    let w = along_keys(room_shell::LACE_OUTER, h) - along_keys(room_shell::LACE_INNER, h);
    return pow(LACE_LETS, max(LACE_FLAT_WIDTH / max(w, 0.05), 1.0));
}

// The surfaces' mean albedo, linear: the herringbone's oak, the wallpaper, the wainscot,
// the white paint of the doors and joinery, the limewash of the reveals, the sills' stone,
// the table's mahogany (measured off the room's shots and surfaces::LOOK).
let FLOOR_ALBEDO = float3 { 0.078, 0.045, 0.022 };
let PAPER_ALBEDO = float3 { 0.064, 0.048, 0.034 };
let OAK_ALBEDO = float3 { 0.082, 0.046, 0.030 };
let PAINT_ALBEDO = float3 { 0.565, 0.515, 0.423 };
let PLASTER_ALBEDO = float3 { 0.55, 0.5, 0.43 };
let STONE_ALBEDO = float3 { 0.468, 0.445, 0.392 };
let TABLE_ALBEDO = float3 { 0.12, 0.06, 0.035 };
// The bookcases' fronts, their oak and the books' spines together (books::COVER's mean,
// darkened by the shelves' shadows), the oak about a third of it. The wainscot's and the
// cases' oak follow surfaces::WALL_OAK's tint: (0.034, 0.014, 0.005) and (0.05, 0.028,
// 0.014) before it (2026-11-21).
let CASE_ALBEDO = float3 { 0.066, 0.039, 0.022 };
// The stove's glaze in its corner (room_shell's stove): ROOM_FRAG's STOVE_GLAZE, linear,
// less its coat's reflection and its joints' and mouldings' shade; taken on the two walls'
// planes behind it, as the bookcases' fronts aren't (2026-11-24).
let STOVE_ALBEDO = float3 { 0.53, 0.58, 0.45 };
// The ceiling's and the cornice's limewash, surfaces::LOOK's two ends' mean, linear.
let CEILING_ALBEDO = float3 { 0.446, 0.383, 0.279 };
// The rug under the games table (ROOM_FRAG's rug): its half size along the window wall and
// across it, its middle RUG_IN from the table's toward the hall (metres), and its pile's
// albedo, design/materials/rug.png's mean in linear light. The bake takes it in the floor's
// cells and patches with rug_in_bake (the tuner's --light physical).
let RUG_HALF = float2 { 1.5, 1.0 };
let RUG_IN: f32 = 0.1;
let RUG_ALBEDO = float3 { 0.157, 0.075, 0.049 };
var rug_in_bake = false;

// The share of the floor's rectangle round `at`, `half` each way (the plan's metres), the
// rug covers, the table's middle at t (the plan's).
fn rug_cover(t: float2, at: float3, half: float2) -> f32 {
    let mid = float2 { t.x, t.y - RUG_IN };
    let x = max(min(at.x + half.x, mid.x + RUG_HALF.x) - max(at.x - half.x, mid.x - RUG_HALF.x), 0.0);
    let y = max(min(at.y + half.y, mid.y + RUG_HALF.y) - max(at.y - half.y, mid.y - RUG_HALF.y), 0.0);
    return x * y / (4.0 * half.x * half.y);
}

// The floor's albedo over that rectangle, the rug's share in with rug_in_bake.
fn floor_albedo(t: float2, at: float3, half: float2) -> float3 {
    guard rug_in_bake else { return FLOOR_ALBEDO; }
    return FLOOR_ALBEDO + (RUG_ALBEDO - FLOOR_ALBEDO) * rug_cover(t, at, half);
}

// How far the sun's patches' thrown-back light is taken to grey (0 its own colour; the
// tuner's --bounce-grey): a quarter, as the light thrown off oak, paper and wax is warm.
var bounce_grey: f32 = 0.25;
// How much the backlit lace throws on in the first light (1 as made; the tuner's
// --lace-source), and the least squared distance the half grid's probes take to a cell
// (metres², 0.09 as made; the tuner's --gather-near): larger spreads a cell's light wider.
var lace_source: f32 = 1.0;
var gather_near: f32 = 0.09;
// The probes' gather exact near what they gather (the tuner's --light physical): a cell
// nearer than two of its sides taken as SPLIT × SPLIT small ones, so a probe 0.15 m over
// the floor gets the floor's light as a plane gives it, not as the nearest cells' middles
// happen to lie; and the table's own sun patch, which lies in its top's plane, not hidden
// by the top from the probes over it.
var gather_exact = false;
let SPLIT = 8;
// The niches' probes (the tuner's --light physical): they gather the cells' light themselves,
// as the half grid has no row in the niches (they took the room's light 0.3 m before the
// wall), and keep their light toward the room exactly (settle, as before a wall), so the
// casements' faces, which read them, don't take the sky's negative lobe; and the lace throws
// its light to both its sides, into its niche as into the room, as the path tracer's thread
// does.
var niche_faces = false;

// What the bake takes: the sun toward it in the plan's frame, its light on a plane facing
// it (linear, the room's sun gain in it), the sky's radiance through the windows (linear),
// the table's top (its middle in the plan, its radius and height, metres), and the two
// sources' strengths.
struct Sun {
    toward:      float3,
    light:       float3,
    sky:         float3,
    table:       float4,
    sky_gain:    f32,
    bounce_gain: f32,
}

// A patch the sun lights, thrown back: where, its normal (the plan's), its albedo, and the
// sun's light on it (watts, so to say: irradiance times area).
struct Patch { at: float3, normal: float3, albedo: float3, power: float3 }

// The bins the sun's rays fall into, a patch each: the floor's 0.25 m cells, the hall
// wall's and the end walls', and each window's sill and two reveals.
let BIN = 0.25;
let FLOOR_BINS_X = 36;
let FLOOR_BINS_Y = 28;
let WALL_BINS_H = 16;
let BINS = 2490;          // 36×28 + 36×16 + 2 × 28×16 + 3 × 3 + 1 (the table)

// The windows' middles along the plan's x, and the niche and its glass.
fn window_mids() -> float3 {
    let s = room_shell::LIBRARY;
    var m: f32[3] = [0.0; 3];
    var n = 0;
    for k in s.count {
        guard s.openings[k].kind == room_shell::WINDOW && n < 3 else { continue; }
        m[n] = s.openings[k].mid;
        n++;
    }
    return float3 { m[0], m[1], m[2] };
}
fn windows() -> room_shell::Opening[3] {
    let m = window_mids();
    return [room_shell::window_at(m.x), room_shell::window_at(m.y), room_shell::window_at(m.z)];
}

// The face of the window wall and the inner glass, in the plan's y.
fn wall_face() -> f32 { room_shell::LIBRARY.walls[room_shell::WINDOW_WALL].a.y }
fn glass_y() -> f32 { wall_face() + room_shell::WINDOW_GLASS.x }

// Ray (window k, column i, row j)'s point on the inner glass, the plan's metres.
fn ray_point(k: i64, i: i64, j: i64) -> float3 {
    let o = windows()[k];
    let low = o.sill + GLAZED_LOW;
    let high = o.sill + o.height + o.rise - GLAZED_HIGH;
    let x = o.mid - GLAZED_HALF + (i + 0.5) * (2.0 * GLAZED_HALF / RAYS_X);
    let h = low + (j + 0.5) * ((high - low) / RAYS_Y);
    return float3 { x, glass_y(), h };
}

// Whether q (the plan's metres) at the window wall's face is inside niche o's outline.
fn in_niche(o: room_shell::Opening, q: float3) -> bool {
    let x = q.x - o.mid;
    abs(x) < 0.5 * o.width && q.z > o.sill && q.z < room_shell::head_at(o, x)
}

// The half width of niche o's opening past its shutters, folded against the reveals from
// SHUTTER_FROM to SHUTTER_TO into the wall (room_shell's; the one leaf ajar taken as
// folded), or the niche's own without them.
fn open_half(o: room_shell::Opening) -> f32 {
    let w = 0.5 * o.width;
    return if room_shell::shutters_on { w - room_shell::SHUTTER_FRONT - room_shell::SHUTTER_BACK } else { w };
}

// Whether the segment from a (in the room, before the wall's face) toward b (into the
// niche) passes the shutters' front edges at SHUTTER_FROM within niche o's opening.
fn past_shutters(o: room_shell::Opening, a: float3, v: float3) -> bool {
    guard room_shell::shutters_on && v.y > 1e-4 else { return true; }
    let y = wall_face() + room_shell::SHUTTER_FROM;
    guard a.y < y else { return true; }
    let q = a + v * ((y - a.y) / v.y);
    return abs(q.x - o.mid) < open_half(o);
}

// Whether the lace hangs at q (the plan's metres at the lace's plane) before niche o.
fn in_lace(o: room_shell::Opening, q: float3) -> bool {
    let x = abs(q.x - o.mid);
    let h = q.z;
    guard h > room_shell::LACE_HEM && h < room_shell::LACE_TOP else { return false; }
    let inner = along_keys(room_shell::LACE_INNER, h);
    let outer = along_keys(room_shell::LACE_OUTER, h);
    x > inner && x < outer
}

// A line through keys (height, value) at height h, straight between them.
fn along_keys(keys: float2[6], h: f32) -> f32 {
    var v = keys[0].y;
    for i in 5 {
        if h > keys[i].x {
            let t = clamp((h - keys[i].x) / (keys[i + 1].x - keys[i].x), 0.0, 1.0);
            v = keys[i].y + (keys[i + 1].y - keys[i].y) * t;
        }
    }
    return v;
}

// The table's top's middle from the board's (the plan's metres): Sun.table's middle is the
// board's, the room's frame's origin, and the top lies mesh::TABLE_Z from it. 0 as made;
// render3d sets it with --light physical.
var table_off = float2_0;

// Whether the segment a to b crosses the table's top (a disc at its height).
fn under_table(t: float4, a: float3, b: float3) -> bool {
    guard (a.z - t.w) * (b.z - t.w) < (if gather_exact { -1e-6 } else { 0.0 }) else { return false; }
    let f = (t.w - a.z) / (b.z - a.z);
    let x = a.x + (b.x - a.x) * f - t.x - table_off.x;
    let y = a.y + (b.y - a.y) * f - t.y - table_off.y;
    return x * x + y * y < t.z * t.z;
}

// How far the bookcase on the hall wall at the plan's x stands out at height h (0 none).
fn case_depth(x: f32, h: f32) -> f32 {
    let s = room_shell::LIBRARY;
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::BOOKCASE && h < o.height else { continue; }
        let w = s.walls[o.wall];
        let mid = w.a.x + normalize(w.b - w.a).x * o.mid;
        if abs(x - mid) < 0.5 * o.width { return if h < room_shell::WAINSCOT_TOP { o.glass.x } else { o.glass.y }; }
    }
    return 0.0;
}

// A wall's albedo at a point of it: the doors painted, the bookcases, the wainscot to
// 1.2 m, the paper over it. along: the plan's x on the hall wall, its y on the end walls.
fn wall_albedo(wall: i64, along: f32, h: f32) -> float3 {
    let s = room_shell::LIBRARY;
    if wall == room_shell::HALL_WALL && case_depth(along, h) > 0.0 { return CASE_ALBEDO; }
    if room_shell::stove_on && room_shell::stove_reach(wall) > along && h < room_shell::STOVE_TOP { return STOVE_ALBEDO; }
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::DOOR && o.wall == wall else { continue; }
        let w = s.walls[wall];
        let d = normalize(w.b - w.a);
        let mid = if wall == room_shell::HALL_WALL { w.a.x + d.x * o.mid } else { w.a.y + d.y * o.mid };
        if abs(along - mid) < 0.5 * o.width + room_shell::ARCHITRAVE && h < o.height + room_shell::ARCHITRAVE {
            return PAINT_ALBEDO;
        }
    }
    if h < room_shell::WAINSCOT_TOP { OAK_ALBEDO } else { PAPER_ALBEDO }
}

// The share of ray (window o, column i, row j)'s cell on the inner glass whose line along d
// (the plan's, into the room) passes every box of `boxes` (room_shell::casement_members).
fn members_let(boxes: room_shell::Member[..room_shell::MEMBERS]&, o: room_shell::Opening, i: i64, j: i64, d: float3) -> f32 {
    let low = o.sill + GLAZED_LOW;
    let high = o.sill + o.height + o.rise - GLAZED_HIGH;
    let dx = 2.0 * GLAZED_HALF / RAYS_X;
    let dh = (high - low) / RAYS_Y;
    return members_let_rect(boxes, -GLAZED_HALF + i * dx, low + j * dh, dx, dh, d, MEMBER_SAMPLES, -room_shell::WINDOW_GLASS.x);
}
// The same for the rectangle (x0, y0) to (x0 + dx, y0 + dh) on the plane at z (the window's
// own metres: the inner glass at -WINDOW_GLASS.x), sampled samples² times. Only the boxes
// whose shadow along d on the plane overlaps the rectangle are tested.
fn members_let_rect(boxes: room_shell::Member[..room_shell::MEMBERS]&, x0: f32, y0: f32, dx: f32, dh: f32, d: float3,
                    samples: i64, z: f32) -> f32 {
    // The line in the window's own metres: x along the wall, y up, z out of the wall.
    let v = float3 { d.x, d.z, -d.y };
    let inv = float3 { 1.0 / v.x, 1.0 / v.y, 1.0 / v.z };
    // A point at depth zb meets the line through the plane's (x, y) at x + kx (zb - z).
    let kx = v.x / v.z;
    let ky = v.y / v.z;
    var near: i64[..room_shell::MEMBERS] = [];
    for b, n in boxes {
        let ax = kx * (b.lo.z - z);
        let bx = kx * (b.hi.z - z);
        let ay = ky * (b.lo.z - z);
        let by = ky * (b.hi.z - z);
        guard b.lo.x - max(ax, bx) < x0 + dx && b.hi.x - min(ax, bx) > x0 else { continue; }
        guard b.lo.y - max(ay, by) < y0 + dh && b.hi.y - min(ay, by) > y0 else { continue; }
        near.push(n);
    }
    var open = 0;
    for sj in samples {
        for si in samples {
            let p = float3 { x0 + (si + 0.5) * (dx / samples), y0 + (sj + 0.5) * (dh / samples), z };
            var hit = false;
            for n in near {
                let b = boxes[n];
                let t0 = (b.lo - p) * inv;
                let t1 = (b.hi - p) * inv;
                let enter = max(min(t0.x, t1.x), max(min(t0.y, t1.y), min(t0.z, t1.z)));
                let leave = min(max(t0.x, t1.x), min(max(t0.y, t1.y), max(t0.z, t1.z)));
                if enter <= leave { hit = true; break; }
            }
            if !hit { open++; }
        }
    }
    return open / (samples * samples * 1.0);
}

// The sky's samples through the casements' members (members_traced): each sample's share
// past them, by the slopes of its line into the room (along the wall and up, a metre into
// the room), SLOPES of each from -SLOPE_MOST to SLOPE_MOST, bilinear between. The three
// windows' members are alike; the table is made once.
let SLOPES = 17;
let SLOPE_MOST: f32 = 4.0;
var sky_lets: f32[11560];     // SKY_X × SKY_Y × SLOPES × SLOPES
var sky_lets_made = false;
fn make_sky_lets() {
    var boxes = room_shell::casement_members(windows()[0]);
    make_lets(sky_lets[..], boxes, -room_shell::WINDOW_GLASS.x);
    sky_lets_made = true;
}
// A table as sky_lets' for `boxes`, the samples on the plane at z (the window's metres).
fn make_lets(table: f32[:], boxes: room_shell::Member[..room_shell::MEMBERS]&, z: f32) {
    let o = windows()[0];
    let low = o.sill + GLAZED_LOW;
    let high = o.sill + o.height + o.rise - GLAZED_HIGH;
    let dx = 2.0 * GLAZED_HALF / SKY_X;
    let dh = (high - low) / SKY_Y;
    let step = 2.0 * SLOPE_MOST / (SLOPES - 1);
    for j in SKY_Y {
        for i in SKY_X {
            for b in SLOPES {
                for a in SLOPES {
                    let d = float3 { -SLOPE_MOST + a * step, -1.0, -SLOPE_MOST + b * step };
                    table[((j * SKY_X + i) * SLOPES + b) * SLOPES + a] =
                        members_let_rect(boxes, -GLAZED_HALF + i * dx, low + j * dh, dx, dh, d, 4, z);
                }
            }
        }
    }
}
// What sky sample (i, j) lets through along v (the plan's, from the room to the sample) in
// place of the glazing: its share past the members times the panes. 1 when the members
// aren't traced.
fn sky_through(i: i64, j: i64, v: float3) -> f32 {
    guard members_traced else { return 1.0; }
    return lets_at(sky_lets[..], i, j, v) * (PANES / glazing);
}
// Sample (i, j)'s share in `table` (as sky_lets) along v, bilinear between the slopes.
fn lets_at(table: const f32[:], i: i64, j: i64, v: float3) -> f32 {
    let g = float2 { (clamp(-v.x / v.y, -SLOPE_MOST, SLOPE_MOST) + SLOPE_MOST) / (2.0 * SLOPE_MOST) * (SLOPES - 1),
                     (clamp(-v.z / v.y, -SLOPE_MOST, SLOPE_MOST) + SLOPE_MOST) / (2.0 * SLOPE_MOST) * (SLOPES - 1) };
    let a0 = min(floor(g.x) as i64, SLOPES - 2);
    let b0 = min(floor(g.y) as i64, SLOPES - 2);
    let fa = g.x - a0;
    let fb = g.y - b0;
    let at = (j * SKY_X + i) * SLOPES * SLOPES;
    let l0 = table[at + b0 * SLOPES + a0] * (1.0 - fa) + table[at + b0 * SLOPES + a0 + 1] * fa;
    let l1 = table[at + (b0 + 1) * SLOPES + a0] * (1.0 - fa) + table[at + (b0 + 1) * SLOPES + a0 + 1] * fa;
    return l0 * (1.0 - fb) + l1 * fb;
}

// The sun's rays through the three windows into the patches they light, binned; how much
// of the sun each ray's glass point lets through the tree outside is `tree` (RAYS, from
// render3d, 1 where no tree). Returns how many patches are lit. Each ray's light also goes
// into the bounces' cells (bounce.sun: the cell it lands on, what the lace before the
// niche stops and throws on into the room).
fn sun_patches(sun: Sun, tree: const f32[:], out: Patch[BINS]&, bounce: Bounce&) -> i64 {
    var power:  float3[BINS] = [float3_0; BINS];
    var where:  float3[BINS] = [float3_0; BINS];
    var normal: float3[BINS] = [float3_0; BINS];
    var albedo: float3[BINS] = [float3_0; BINS];
    var lit:    f32[BINS]    = [0.0; BINS];
    for c in CELLS { bounce.sun[c] = float3_0; }
    let s = room_shell::LIBRARY;
    let wins = windows();
    let d = float3_0 - sun.toward;
    guard d.y < -0.02 && d.z < -0.02 else { return 0; }
    let face = wall_face();
    let gy = glass_y();
    let room_x = s.walls[room_shell::FAR_WALL].a.x;
    let lace_y = face - room_shell::LACE_OFF;
    var boxes = room_shell::casement_members(wins[0]);
    for k in 3 {
        let o = wins[k];
        let cell = (2.0 * GLAZED_HALF / RAYS_X) * ((o.height + o.rise - GLAZED_LOW - GLAZED_HIGH) / RAYS_Y);
        let each = sun.light * (cell * -d.y * (if members_traced { PANES } else { glazing }));
        for j in RAYS_Y {
            for i in RAYS_X {
                let q = ray_point(k, i, j);
                var p = each * tree[(k * RAYS_Y + j) * RAYS_X + i];
                if members_traced {
                    p = p * members_let(boxes, o, i, j, d);
                    guard p.x + p.y + p.z > 0.0 else { continue; }
                }
                // Through the niche to the wall's face: the sill, a reveal, or on.
                let t_face = (gy - face) / -d.y;
                let t_sill = (q.z - o.sill) / -d.z;
                // The reveal: the lining behind the shutters, or the shutters' face in front of
                // the lining, or their back edges between.
                let side = if d.x > 0.0 { 0.5 * o.width } else { -0.5 * o.width };
                var t_reveal = if abs(d.x) > 1e-4 { (o.mid + side - q.x) / d.x } else { 1e9 };
                var reveal_albedo = PLASTER_ALBEDO;
                if room_shell::shutters_on && abs(d.x) > 1e-4 && q.y + d.y * t_reveal - face < room_shell::SHUTTER_TO {
                    let inner = if d.x > 0.0 { open_half(o) } else { -open_half(o) };
                    let t_back = (face + room_shell::SHUTTER_TO - q.y) / d.y;
                    t_reveal = max((o.mid + inner - q.x) / d.x, t_back);
                    reveal_albedo = PAINT_ALBEDO;
                }
                var bin = -1;
                var cell = -1;
                var at = float3_0;
                var n = float3_0;
                var a = float3_0;
                if t_sill < t_face && t_sill < t_reveal {
                    bin = 1008 + 576 + 896 + 3 * k;
                    at = q + d * t_sill;
                    n = float3 { 0.0, 0.0, 1.0 };
                    a = STONE_ALBEDO;
                    cell = sill_cell(k, o, at);
                } else if t_reveal < t_face {
                    bin = 1008 + 576 + 896 + 3 * k + (if d.x > 0.0 { 1 } else { 2 });
                    at = q + d * t_reveal;
                    n = float3 { if d.x > 0.0 { -1.0 } else { 1.0 }, 0.0, 0.0 };
                    a = reveal_albedo;
                    cell = reveal_cell(k, o, at, if d.x > 0.0 { 1 } else { 0 });
                } else {
                    // Into the room, past the lace, to the floor, a wall, or the table.
                    let b = q + d * t_face;
                    guard in_niche(o, b) else { continue; }
                    let c = q + d * ((gy - lace_y) / -d.y);
                    if in_lace(o, c) {
                        let lc = lace_cell(k, o, c);
                        let lets = lace_lets(c.z);
                        bounce.sun[lc] = bounce.sun[lc] + p * ((1.0 - lets) * LACE_SCATTER);
                        p = p * lets;
                    }
                    var t = b.z / -d.z;
                    var hit = 0;
                    var t_hall = b.y / -d.y;
                    // A bookcase's front stands out of the hall wall: met there instead.
                    let on_wall = b + d * t_hall;
                    let out = case_depth(on_wall.x, on_wall.z);
                    if out > 0.0 {
                        let t_case = (b.y - out) / -d.y;
                        let e = b + d * t_case;
                        if case_depth(e.x, e.z) >= out - 1e-3 { t_hall = t_case; }
                    }
                    if t_hall < t { t = t_hall; hit = 1; }
                    if d.x < 0.0 && b.x / -d.x < t { t = b.x / -d.x; hit = 2; }
                    if d.x > 0.0 && (room_x - b.x) / d.x < t { t = (room_x - b.x) / d.x; hit = 3; }
                    let tt = (b.z - sun.table.w) / -d.z;
                    if tt > 0.0 && tt < t {
                        let e = b + d * tt;
                        let dx = e.x - sun.table.x - table_off.x;
                        let dy = e.y - sun.table.y - table_off.y;
                        if dx * dx + dy * dy < sun.table.z * sun.table.z { t = tt; hit = 4; }
                    }
                    at = b + d * t;
                    if hit == 0 {
                        let bx = clamp((at.x / BIN) as i64, 0, FLOOR_BINS_X - 1);
                        let by = clamp((at.y / BIN) as i64, 0, FLOOR_BINS_Y - 1);
                        bin = by * FLOOR_BINS_X + bx;
                        n = float3 { 0.0, 0.0, 1.0 };
                        a = floor_albedo(float2 { sun.table.x, sun.table.y }, at, float2 { 1e-4, 1e-4 });
                        cell = FLOOR_C0 + plane_cell(at.y, face, FLOOR_NY) * FLOOR_NX + plane_cell(at.x, room_x, FLOOR_NX);
                    } else if hit == 1 {
                        let bx = clamp((at.x / BIN) as i64, 0, FLOOR_BINS_X - 1);
                        let bh = clamp((at.z / BIN) as i64, 0, WALL_BINS_H - 1);
                        bin = 1008 + bh * FLOOR_BINS_X + bx;
                        n = float3 { 0.0, 1.0, 0.0 };
                        a = wall_albedo(room_shell::HALL_WALL, at.x, at.z);
                        cell = HALL_C0 + plane_cell(at.z, s.ceiling, WALL_NH) * FLOOR_NX + plane_cell(at.x, room_x, FLOOR_NX);
                    } else if hit < 4 {
                        let by = clamp((at.y / BIN) as i64, 0, FLOOR_BINS_Y - 1);
                        let bh = clamp((at.z / BIN) as i64, 0, WALL_BINS_H - 1);
                        bin = 1008 + 576 + (hit - 2) * 448 + bh * FLOOR_BINS_Y + by;
                        n = float3 { if hit == 2 { 1.0 } else { -1.0 }, 0.0, 0.0 };
                        a = wall_albedo(if hit == 2 { room_shell::STOVE_WALL } else { room_shell::FAR_WALL }, at.y, at.z);
                        cell = (if hit == 2 { STOVE_C0 } else { FAR_C0 }) + plane_cell(at.z, s.ceiling, WALL_NH) * FLOOR_NY
                               + plane_cell(at.y, face, FLOOR_NY);
                    } else {
                        bin = BINS - 1;
                        n = float3 { 0.0, 0.0, 1.0 };
                        a = TABLE_ALBEDO;
                        cell = TABLE_C;
                    }
                }
                a = thrown_albedo(a, sun.bounce_gain);
                bounce.sun[cell] = bounce.sun[cell] + p * a;
                let weight = p.x + p.y + p.z;
                power[bin] = power[bin] + p * a;
                where[bin] = where[bin] + at * weight;
                lit[bin] += weight;
                normal[bin] = n;
                albedo[bin] = a;
            }
        }
    }
    var count = 0;
    for b in BINS {
        guard lit[b] > 0.0 else { continue; }
        // Its colour taken part of the way to grey, as an eye or a photograph balances a
        // room's light: the amber sun off orange oak alone turns the ceiling peach.
        let c = power[b];
        let grey = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z;
        let balanced = c + (float3 { grey, grey, grey } - c) * bounce_grey;
        out[count] = Patch { where[b] / lit[b], normal[b], albedo[b], balanced };
        count++;
    }
    return count;
}

// The most of the light falling on a surface that the bake throws back off it.
let MOST_THROWN: f32 = 0.85;
// A surface's albedo for the sun's light thrown back off it, so that the sun's patches'
// gain (Sun.bounce_gain, which lifts the dark oak and paper) never has a surface throw back
// more than MOST_THROWN of the light on it: the limewashed reveals, the stone sills and the
// white paint would otherwise throw back three times what falls on them.
fn thrown_albedo(a: float3, gain: f32) -> float3 {
    let most = MOST_THROWN / max(gain, 1e-3);
    return float3 { min(a.x, most), min(a.y, most), min(a.z, most) };
}

// Where probe point p (the plan's metres) lies: -1 in the room, k in niche k's air (over
// its sill, under its head and before its inner glass), -2 inside a wall, past the inner
// glass or behind the hall wall, where no surface reads it and it takes the light of the
// row before it (fill_walled).
fn probe_place(wins: room_shell::Opening[3]&, p: float3) -> i64 {
    guard p.y >= 0.0 else { return -2; }
    guard p.y > wall_face() else { return -1; }
    guard p.y < glass_y() else { return -2; }
    for k in 3 {
        let o = wins[k];
        let x = p.x - o.mid;
        if abs(x) < 0.5 * o.width && p.z > o.sill && p.z < room_shell::head_at(o, x) { return k; }
    }
    return -2;
}

// What a probe gathers: per colour the light as a constant and a direction (the clamped
// cosine's first two bands, a light's 0.25 and 0.5 of it), and, for the walls, floor or
// ceiling a probe stands before (near_faces), their own light: the exact clamped cosine
// sum for their normals, to which settle turns the direction. The two bands alone give a
// wall a quarter of each light along it or behind it, and a floor a quarter of each low
// light across the room: the floor read up to twice the light it gets, a wall's own sun
// patch rang dark round itself, and the corners took what lay behind them.
//
// With nine_harmonics also the second band (q*, rgb each): the sum of each light times its
// direction's xx, yy (less a third), xy, xz, yz; zz is -(xx + yy) (props_band).
struct Gathered { c: float3, dr: float3, dg: float3, db: float3, ex: float3, ey: float3, ez: float3,
                  qxx: float3, qyy: float3, qxy: float3, qxz: float3, qyz: float3 }
let GATHERED = 36;            // its floats in the half grid: c, dr, dg, db as the atlas's, ex, ey, ez, the q's

// How far before a plane the probes that its surface reads stand (0.15 m, and 0.25 m under
// the ceiling and before the hall wall), and no others.
let NEAR_PLANE: f32 = 0.35;

// The normals (the plan's, each axis -1, 1 or 0 for none) of the room's planes that probe
// point p stands before: the end walls, the window wall's face, the hall wall, the floor
// and the ceiling. A niche's probes take none.
fn near_faces(p: float3) -> float3 {
    let s = room_shell::LIBRARY;
    let face = wall_face();
    guard p.y <= face else { return if niche_faces { float3 { 0.0, -1.0, 0.0 } } else { float3_0 }; }
    let x_end = s.walls[room_shell::FAR_WALL].a.x;
    let x: f32 = if p.x < NEAR_PLANE { 1.0 } else if p.x > x_end - NEAR_PLANE { -1.0 } else { 0.0 };
    let y: f32 = if p.y > face - NEAR_PLANE { -1.0 } else if p.y < NEAR_PLANE { 1.0 } else { 0.0 };
    let z: f32 = if p.z < NEAR_PLANE { 1.0 } else if p.z > s.ceiling - NEAR_PLANE { -1.0 } else { 0.0 };
    return float3 { x, y, z };
}

// A light w (per colour) from direction d (the plan's, from the probe toward it, as long as
// the direction it is taken in) into g; f: near_faces.
fn take(g: Gathered&, f: float3, w: float3, d: float3) {
    let dir = to_room(d);
    g.c = g.c + w * 0.25;
    g.dr = g.dr + dir * (0.5 * w.x);
    g.dg = g.dg + dir * (0.5 * w.y);
    g.db = g.db + dir * (0.5 * w.z);
    if f.x != 0.0 { g.ex = g.ex + w * max(d.x * f.x, 0.0); }
    if f.y != 0.0 { g.ey = g.ey + w * max(d.y * f.y, 0.0); }
    if f.z != 0.0 { g.ez = g.ez + w * max(d.z * f.z, 0.0); }
    if nine_harmonics {
        g.qxx = g.qxx + w * (dir.x * dir.x - 1.0 / 3.0);
        g.qyy = g.qyy + w * (dir.y * dir.y - 1.0 / 3.0);
        g.qxy = g.qxy + w * (dir.x * dir.y);
        g.qxz = g.qxz + w * (dir.x * dir.z);
        g.qyz = g.qyz + w * (dir.y * dir.z);
    }
}

// The second band of the clamped cosine's light, as TABLE_FRAG's props_light adds it for a
// normal n: k (nx² - nz²), (ny² - nz²), nx ny, nx nz, ny nz, each rgb (the gathered q's
// times 15/32: a light's clamped cosine is 1/4 + cos/2 + 15/32 (cos² - 1/3) to this band).
fn props_band(g: Gathered&) -> float3[5] {
    let k: f32 = 15.0 / 32.0;
    return [g.qxx * k, g.qyy * k, g.qxy * (2.0 * k), g.qxz * (2.0 * k), g.qyz * (2.0 * k)];
}

// Probe (iz, x: the atlas's column) of the props' atlas from g, before its settle.
fn put_props(props: f32[:], iz: i64, x: i64, g: Gathered&) {
    let band = props_band(g);
    let all: float3[9] = [g.c, float3 { g.dr.x, g.dg.x, g.db.x }, float3 { g.dr.y, g.dg.y, g.db.y },
                          float3 { g.dr.z, g.dg.z, g.db.z }, band[0], band[1], band[2], band[3], band[4]];
    for k in 9 {
        for ch in 3 {
            let f = 3 * k + ch;
            props[4 * ((f / 4 * NZ + iz) * ATLAS_W + x) + f % 4] = if ch == 0 { all[k].x } else if ch == 1 { all[k].y } else { all[k].z };
        }
    }
}

// The direction turned along each near face's normal so that the constant and the
// direction give that face exactly its own light; the faces are square to each other, so
// each turn leaves the others' light as it is, and every other normal as the bands give it.
fn settle(g: Gathered&, f: float3) {
    for a in 3 {
        let s = if a == 0 { f.x } else if a == 1 { f.y } else { f.z };
        guard s != 0.0 else { continue; }
        let e = if a == 0 { g.ex } else if a == 1 { g.ey } else { g.ez };
        let n = to_room(if a == 0 { float3 { s, 0.0, 0.0 } } else if a == 1 { float3 { 0.0, s, 0.0 } } else { float3 { 0.0, 0.0, s } });
        g.dr = g.dr + n * (e.x - g.c.x - dot(g.dr, n));
        g.dg = g.dg + n * (e.y - g.c.y - dot(g.dg, n));
        g.db = g.db + n * (e.z - g.c.z - dot(g.db, n));
    }
}

// A direction of the plan in the room's frame: x along u is the plan's -x, z along v its -y.
fn to_room(d: float3) -> float3 { float3 { -d.x, d.z, -d.y } }

// The bake: every probe's light into `atlas` (ATLAS_FLOATS, the layout above), light over
// pi as the shaders' harmonics are. `patches` and `count` from sun_patches; the bounced
// light from bounce.half (gather_half), spread over the whole grid. A probe in a niche sees
// only its own window and the room through the niche's outline; one inside a wall takes
// its neighbour's light (fill_walled).
fn bake(sun: Sun, patches: Patch[BINS]&, count: i64, bounce: Bounce&, atlas: f32[:], props: f32[:]) {
    assert(atlas.len == ATLAS_FLOATS);
    assert(props.len == PROPS_FLOATS);
    let face = wall_face();
    let gy = glass_y();
    let lace_y = face - room_shell::LACE_OFF;
    let x0 = room_shell::LIBRARY.walls[room_shell::FAR_WALL].a.x;
    var wins = windows();
    // The sky's samples: on each window's glazing, each its share of the glass's area.
    var sky_at:     float3[120] = [float3_0; 120];
    var sky_area:   f32[120]    = [0.0; 120];
    var sky_window: i64[120]    = [0; 120];
    var sky_ij:     i64[120]    = [0; 120];
    var sky_n = 0;
    for k in 3 {
        let o = wins[k];
        let low = o.sill + GLAZED_LOW;
        let high = o.sill + o.height + o.rise - GLAZED_HIGH;
        for j in SKY_Y {
            for i in SKY_X {
                let x = o.mid - GLAZED_HALF + (i + 0.5) * (2.0 * GLAZED_HALF / SKY_X);
                let h = low + (j + 0.5) * ((high - low) / SKY_Y);
                guard h < room_shell::head_at(o, x - o.mid) else { continue; }
                sky_at[sky_n] = float3 { x, gy, h };
                sky_area[sky_n] = (2.0 * GLAZED_HALF / SKY_X) * ((high - low) / SKY_Y);
                sky_window[sky_n] = k;
                sky_ij[sky_n] = j * SKY_X + i;
                sky_n++;
            }
        }
    }
    let sky = sun.sky * (sun.sky_gain * glazing / PI);
    if members_traced && !sky_lets_made { make_sky_lets(); }
    let inv_pi2 = sun.bounce_gain / (PI * PI);
    // The probes' near limit, so a patch's light doesn't spike at the probes beside it:
    // about a bin's size.
    let near2: f32 = gather_near;
    // The niche each patch lies in (-1 the room): a sill's or a reveal's light leaves its
    // niche only through the niche's outline.
    var patch_niche: i64[BINS] = [-1; BINS];
    for pi in count {
        patch_niche[pi] = niche_of(patches[pi].at + patches[pi].normal * 0.01);
    }
    for ih in NH {
        for iz in NZ {
            for ix in NX {
                let p = float3 { x0 - INSET - ix * CELL, PLAN_Y0 - iz * CELL, INSET + ih * CELL };
                let kp = probe_place(wins, p);
                guard kp > -2 else { continue; }
                let f = near_faces(p);
                // The bounced light, gathered on the half grid; a niche's own probes (the half
                // grid has none in the niches) gather it themselves with niche_faces.
                let hp = half_probe(bounce.half, ix, iz, ih);
                var got = if niche_faces && kp >= 0 { gather_cells(sun, bounce, wins, p, kp, f) } else { Gathered {
                    float3 { hp[0], hp[4], hp[8] }, float3 { hp[1], hp[2], hp[3] }, float3 { hp[5], hp[6], hp[7] },
                    float3 { hp[9], hp[10], hp[11] }, float3 { hp[12], hp[13], hp[14] }, float3 { hp[15], hp[16], hp[17] },
                    float3 { hp[18], hp[19], hp[20] }, float3 { hp[21], hp[22], hp[23] }, float3 { hp[24], hp[25], hp[26] },
                    float3 { hp[27], hp[28], hp[29] }, float3 { hp[30], hp[31], hp[32] }, float3 { hp[33], hp[34], hp[35] } } };
                // The sky, seen through the niche's outline at the wall's face and past
                // the lace.
                for si in sky_n {
                    let s = sky_at[si];
                    let v = s - p;
                    guard v.y > 1e-3 else { continue; }
                    let o = wins[sky_window[si]];
                    guard kp < 0 || sky_window[si] == kp else { continue; }
                    var lets: f32 = 1.0;
                    if p.y <= face + 1e-4 {
                        let f = max(face - p.y, 0.0) / v.y;
                        guard in_niche(o, p + v * f) && past_shutters(o, p, v) else { continue; }
                        let c = p + v * ((lace_y - p.y) / v.y);
                        if p.y < lace_y && in_lace(o, c) { lets = lace_lets(c.z); }
                    }
                    guard !under_table(sun.table, p, s) else { continue; }
                    lets = lets * sky_through(sky_ij[si] % SKY_X, sky_ij[si] / SKY_X, v);
                    let r2 = max(dot(v, v), near2);
                    let r = sqrt(r2);
                    take(got, f, sky * (lets * sky_area[si] * (v.y / r) / r2), v / r);
                }
                // The sun's patches, each a small lambertian light facing its normal.
                for pi in count {
                    let pt .= patches[pi];
                    let v = pt.at - p;
                    let r2 = max(dot(v, v), near2);
                    let r = sqrt(r2);
                    let off = -dot(pt.normal, v);
                    guard off > 0.0 else { continue; }
                    let facing = off / r;
                    let lets = seen_through(sun.table, wins, p, kp, pt.at, patch_niche[pi]);
                    guard lets > 0.0 else { continue; }
                    take(got, f, pt.power * (lets * facing * inv_pi2 / r2), v / r);
                }
                let x = ih * NX + ix;
                if nine_harmonics { put_props(props, iz, x, got); }
                settle(got, f);
                let c = got.c;
                let dr = got.dr;
                let dg = got.dg;
                let db = got.db;
                let a = 4 * (iz * ATLAS_W + x);
                let g = 4 * ((NZ + iz) * ATLAS_W + x);
                let b = 4 * ((2 * NZ + iz) * ATLAS_W + x);
                atlas[a] = c.x;
                atlas[a + 1] = dr.x;
                atlas[a + 2] = dr.y;
                atlas[a + 3] = dr.z;
                atlas[g] = c.y;
                atlas[g + 1] = dg.x;
                atlas[g + 2] = dg.y;
                atlas[g + 3] = dg.z;
                atlas[b] = c.z;
                atlas[b + 1] = db.x;
                atlas[b + 2] = db.y;
                atlas[b + 3] = db.z;
            }
        }
    }
    fill_walled(wins, atlas, 3);
    if nine_harmonics { fill_walled(wins, props, PROPS_BLOCKS); }
}

// The probes inside a wall, past the glass or behind the hall wall (probe_place) take the
// light of the nearest probe toward the room along z, so the surfaces beside them (the
// window wall's corners, the floor and the ceiling along it, the hall wall) don't read
// light seen through the wall. `blocks`: the atlas's blocks of NZ rows (3, or PROPS_BLOCKS).
fn fill_walled(wins: room_shell::Opening[3]&, atlas: f32[:], blocks: i64) {
    let x0 = room_shell::LIBRARY.walls[room_shell::FAR_WALL].a.x;
    for ih in NH {
        for iz in NZ {
            for ix in NX {
                let p = float3 { x0 - INSET - ix * CELL, PLAN_Y0 - iz * CELL, INSET + ih * CELL };
                guard probe_place(wins, p) == -2 else { continue; }
                let step = if iz < NZ / 2 { 1 } else { -1 };
                var from = iz + step;
                while from > 0 && from < NZ - 1 &&
                      probe_place(wins, float3 { p.x, PLAN_Y0 - from * CELL, p.z }) == -2 { from += step; }
                let x = ih * NX + ix;
                for c in blocks {
                    let to = 4 * ((c * NZ + iz) * ATLAS_W + x);
                    let at = 4 * ((c * NZ + from) * ATLAS_W + x);
                    for f in 4 { atlas[to + f] = atlas[at + f]; }
                }
            }
        }
    }
}

// The bounces. The room's surfaces as cells, about half a metre a side on the floor, the
// ceiling and the four walls (a door's leaf, a bookcase's front, the paper, the wainscot
// and the cornice each by its share of the cell), a fifth of a metre in the niches (their
// sills, reveals and heads), the table's top one more, and the lace before each niche in
// four bands a panel, a source only. The probes read the bounced light at 0.3 m and half
// a step out, so finer cells would change nothing they show and cost the square.
let FLOOR_NX = 18;
let FLOOR_NY = 14;
let WALL_NH = 8;
let NICHE_ACROSS = 6;
let NICHE_DEEP = 2;
let REVEAL_UP = 10;
let NICHE_CELLS = 64;      // the sill 6 × 2, the two reveals 10 × 2 each, the head 6 × 2
let LACE_BANDS = 4;
let FLOOR_C0 = 0;
let CEIL_C0 = 252;         // FLOOR_NX × FLOOR_NY
let WIN_C0 = 504;
let HALL_C0 = 648;         // + FLOOR_NX × WALL_NH
let STOVE_C0 = 792;
let FAR_C0 = 904;          // + FLOOR_NY × WALL_NH
let NICHE_C0 = 1016;
let TABLE_C = 1208;        // + 3 × NICHE_CELLS
let LACE_C0 = 1209;
let CELLS = 1233;          // + 3 windows × 2 panels × LACE_BANDS
// How many times the room throws its light on after the first: one, as two and three
// change no patch by more than a level (build/notes/panels-shade/) and cost the bake's time.
let BOUNCES = 1;
// Of the light the lace stops, the share it throws on into the room, diffusely: its thread
// is near white (0.8), and about half of what it scatters goes forward.
let LACE_SCATTER: f32 = 0.4;
// The probes' grid at half its density (every other probe each way), where the bounced
// light is gathered before it is spread over the whole grid.
let HALF_X = 16;           // every other probe and the last, the stove's end's own row
let HALF_Z = 13;
let HALF_H = 7;
let HALF_FLOATS = 52416;   // HALF_X × HALF_Z × HALF_H × GATHERED

// The whole grid's x index of the half grid's column ix.
fn half_column(ix: i64) -> i64 { if ix == HALF_X - 1 { NX - 1 } else { 2 * ix } }

// A cell: its middle (the plan's metres), its normal, its albedo, its area (0 a hole, the
// windows' openings), and the niche it lies in (-1 the room).
struct Cell { at: float3, normal: float3, albedo: float3, area: f32, niche: i64 }

// The bounces' buffers, fixed: the cells (made once, and again when the shutters are
// switched), the sun's light thrown back off each
// (from sun_patches: what each cell's rays bring, its albedo in), the light leaving each in
// this bounce and what it gathers for the next (over pi), the share of the room each cell
// sees (its form factors' sum, capped at 1), what the probes gather (the light leaving
// each cell but the sun's first, which the patches carry), and the half grid's probes.
struct Bounce {
    cells:         Cell[CELLS],
    made:          bool,
    made_shutters: bool,
    made_hang:     f32,
    sun:           float3[CELLS],
    leaves:        float3[CELLS],
    gather:        float3[CELLS],
    seen:          float3[CELLS],
    norm:          f32[CELLS],
    half:          f32[HALF_FLOATS],
}

// Cell k of n along a plane `size` long that point x lies in.
fn plane_cell(x: f32, size: f32, n: i64) -> i64 { clamp((x / size * n) as i64, 0, n - 1) }

// The cells in niche k (window o) at a point of its sill, a reveal (side 0 its left, 1 its
// right), and the lace panel before it at its plane.
fn sill_cell(k: i64, o: room_shell::Opening, at: float3) -> i64 {
    let i = plane_cell(at.x - (o.mid - 0.5 * o.width), o.width, NICHE_ACROSS);
    let j = plane_cell(at.y - wall_face(), glass_y() - wall_face(), NICHE_DEEP);
    NICHE_C0 + k * NICHE_CELLS + i * NICHE_DEEP + j
}
fn reveal_cell(k: i64, o: room_shell::Opening, at: float3, side: i64) -> i64 {
    let up = plane_cell(at.z - o.sill, reveal_top(o) - o.sill, REVEAL_UP);
    let j = plane_cell(at.y - wall_face(), glass_y() - wall_face(), NICHE_DEEP);
    NICHE_C0 + k * NICHE_CELLS + 12 + side * 20 + up * NICHE_DEEP + j
}
fn lace_cell(k: i64, o: room_shell::Opening, at: float3) -> i64 {
    let side = if at.x > o.mid { 1 } else { 0 };
    let band = plane_cell(at.z - room_shell::LACE_HEM, room_shell::LACE_TOP - room_shell::LACE_HEM, LACE_BANDS);
    LACE_C0 + (k * 2 + side) * LACE_BANDS + band
}
fn reveal_top(o: room_shell::Opening) -> f32 { room_shell::head_at(o, 0.5 * o.width) }

// A wall's cell, along from a0 for `wide` and up from h0 for `high`, from 5 × 5 points of
// it: its middle, albedo and area those that aren't a window's opening make.
fn wall_cell(wall: i64, a0: f32, h0: f32, wide: f32, high: f32) -> Cell {
    let s = room_shell::LIBRARY;
    let wins = windows();
    let face = wall_face();
    let x_end = s.walls[room_shell::FAR_WALL].a.x;
    let cornice = s.ceiling - room_shell::CORNICE_DROP;
    var at = float3_0;
    var albedo = float3_0;
    var count = 0;
    for j in 5 {
        for i in 5 {
            let a = a0 + (i + 0.5) * wide / 5.0;
            let h = h0 + (j + 0.5) * high / 5.0;
            var q = float3_0;
            var c = float3_0;
            if wall == room_shell::WINDOW_WALL {
                q = float3 { a, face, h };
                var hole = false;
                for k in 3 { if in_niche(wins[k], q) { hole = true; } }
                guard !hole else { continue; }
                c = if h < room_shell::WAINSCOT_TOP { OAK_ALBEDO } else { PAPER_ALBEDO };
            } else if wall == room_shell::HALL_WALL {
                q = float3 { a, case_depth(a, h), h };
                c = wall_albedo(wall, a, h);
            } else {
                q = float3 { if wall == room_shell::STOVE_WALL { 0.0 } else { x_end }, a, h };
                c = wall_albedo(wall, a, h);
            }
            if h > cornice { c = CEILING_ALBEDO; }
            at = at + q;
            albedo = albedo + c;
            count++;
        }
    }
    let normal = if wall == room_shell::WINDOW_WALL { float3 { 0.0, -1.0, 0.0 } }
                 else if wall == room_shell::HALL_WALL { float3 { 0.0, 1.0, 0.0 } }
                 else if wall == room_shell::STOVE_WALL { float3 { 1.0, 0.0, 0.0 } }
                 else { float3 { -1.0, 0.0, 0.0 } };
    guard count > 0 else { return Cell { float3 { a0, face, h0 }, normal, float3_0, 0.0, -1 }; }
    return Cell { at / count, normal, albedo / count, wide * high * count / 25.0, -1 };
}

// The cells, made once.
fn make_cells(bounce: Bounce&) {
    let s = room_shell::LIBRARY;
    let wins = windows();
    let face = wall_face();
    let depth = glass_y() - face;
    let x_end = s.walls[room_shell::FAR_WALL].a.x;
    let fw = x_end / FLOOR_NX;
    let fd = face / FLOOR_NY;
    let wh = s.ceiling / WALL_NH;
    let up = float3 { 0.0, 0.0, 1.0 };
    let down = float3 { 0.0, 0.0, -1.0 };
    for j in FLOOR_NY {
        for i in FLOOR_NX {
            let at = float3 { (i + 0.5) * fw, (j + 0.5) * fd, 0.0 };
            bounce.cells[FLOOR_C0 + j * FLOOR_NX + i] = Cell { at, up, FLOOR_ALBEDO, fw * fd, -1 };
            bounce.cells[CEIL_C0 + j * FLOOR_NX + i] = Cell { float3 { at.x, at.y, s.ceiling }, down, CEILING_ALBEDO, fw * fd, -1 };
        }
    }
    for k in WALL_NH {
        for i in FLOOR_NX {
            bounce.cells[WIN_C0 + k * FLOOR_NX + i] = wall_cell(room_shell::WINDOW_WALL, i * fw, k * wh, fw, wh);
            bounce.cells[HALL_C0 + k * FLOOR_NX + i] = wall_cell(room_shell::HALL_WALL, i * fw, k * wh, fw, wh);
        }
        for i in FLOOR_NY {
            bounce.cells[STOVE_C0 + k * FLOOR_NY + i] = wall_cell(room_shell::STOVE_WALL, i * fd, k * wh, fd, wh);
            bounce.cells[FAR_C0 + k * FLOOR_NY + i] = wall_cell(room_shell::FAR_WALL, i * fd, k * wh, fd, wh);
        }
    }
    for k in 3 {
        let o = wins[k];
        let base = NICHE_C0 + k * NICHE_CELLS;
        let x0 = o.mid - 0.5 * o.width;
        let across = o.width / NICHE_ACROSS;
        let deep = depth / NICHE_DEEP;
        let rise = (reveal_top(o) - o.sill) / REVEAL_UP;
        for i in NICHE_ACROSS {
            for j in NICHE_DEEP {
                let x = x0 + (i + 0.5) * across;
                let y = face + (j + 0.5) * deep;
                bounce.cells[base + i * NICHE_DEEP + j] = Cell { float3 { x, y, o.sill }, up, STONE_ALBEDO, across * deep, k };
                bounce.cells[base + 52 + i * NICHE_DEEP + j] =
                    Cell { float3 { x, y, room_shell::head_at(o, x - o.mid) }, down, PLASTER_ALBEDO, across * deep, k };
            }
        }
        // The reveals, or the shutters' faces folded before them.
        for side in 2 {
            let n = float3 { if side == 0 { 1.0 } else { -1.0 }, 0.0, 0.0 };
            for u in REVEAL_UP {
                for j in NICHE_DEEP {
                    let y = face + (j + 0.5) * deep;
                    let shut = room_shell::shutters_on && y - face < room_shell::SHUTTER_TO;
                    let half = if shut { open_half(o) } else { 0.5 * o.width };
                    let x = if side == 0 { o.mid - half } else { o.mid + half };
                    let at = float3 { x, y, o.sill + (u + 0.5) * rise };
                    bounce.cells[base + 12 + side * 20 + u * NICHE_DEEP + j] =
                        Cell { at, n, if shut { PAINT_ALBEDO } else { PLASTER_ALBEDO }, rise * deep, k };
                }
            }
        }
        // The lace before it: each panel's bands, between its inner and outer edge at the
        // band's middle, facing the room.
        let band = (room_shell::LACE_TOP - room_shell::LACE_HEM) / LACE_BANDS;
        for side in 2 {
            for b in LACE_BANDS {
                let h = room_shell::LACE_HEM + (b + 0.5) * band;
                let inner = along_keys(room_shell::LACE_INNER, h);
                let outer = along_keys(room_shell::LACE_OUTER, h);
                let x = o.mid + (if side == 0 { -1.0 } else { 1.0 }) * 0.5 * (inner + outer);
                bounce.cells[LACE_C0 + (k * 2 + side) * LACE_BANDS + b] =
                    Cell { float3 { x, face - room_shell::LACE_OFF, h }, float3 { 0.0, -1.0, 0.0 }, float3_0, (outer - inner) * band, -1 };
            }
        }
    }
    bounce.cells[TABLE_C] = Cell { float3_0, up, TABLE_ALBEDO, 0.0, -1 };
    bounce.made = true;
    bounce.made_shutters = room_shell::shutters_on;
    bounce.made_hang = room_shell::lace_hang;
}

// The niche a point behind the window wall's face lies in: -1 before the face, -2 inside the
// wall (a pier).
fn niche_of(p: float3) -> i64 {
    guard p.y > wall_face() else { return -1; }
    let wins = windows();
    for k in 3 { if abs(p.x - wins[k].mid) < 0.5 * wins[k].width { return k; } }
    return -2;
}

// How much of the light from b reaches a (each in niche ka, kb, as niche_of): none between
// two niches or through a wall, between the room and a niche only through the niche's
// outline at the wall's face and past the lace hanging before it, none through the
// table's top.
fn seen_through(t: float4, wins: room_shell::Opening[3]&, a: float3, ka: i64, b: float3, kb: i64) -> f32 {
    guard ka > -2 && kb > -2 else { return 0.0; }
    var lets: f32 = 1.0;
    if ka != kb {
        guard ka < 0 || kb < 0 else { return 0.0; }
        let room = if ka < 0 { a } else { b };
        let deep = if ka < 0 { b } else { a };
        let o = wins[if ka < 0 { kb } else { ka }];
        let v = deep - room;
        guard v.y > 1e-4 else { return 0.0; }
        let face = wall_face();
        guard in_niche(o, room + v * ((face - room.y) / v.y)) && past_shutters(o, room, v) else { return 0.0; }
        let lace_y = face - room_shell::LACE_OFF;
        let c = room + v * ((lace_y - room.y) / v.y);
        if room.y < lace_y && in_lace(o, c) { lets = lace_lets(c.z); }
    }
    guard !under_table(t, a, b) else { return 0.0; }
    return lets;
}

// A colour taken part of the way to grey, as the sun's patches are (bounce_grey).
fn balanced(c: float3) -> float3 {
    let grey = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z;
    return c + (float3 { grey, grey, grey } - c) * bounce_grey;
}

// The light the room first throws on, besides the sun's patches: each cell's sky (seen
// through the niches' outlines and past the lace, as the probes see it; a niche's own cells
// see their own window's glass straight) by its albedo, and the sun's light thrown back
// off it (from sun_patches), both taken toward grey; the lace's bands, lit on their backs by
// the sun (sun_patches) and the sky through their window, throw on what they stop. Into
// bounce.leaves; bounce.seen starts with all of it but the sun's, which the patches carry.
fn first_light(sun: Sun, bounce: Bounce&) {
    if !bounce.made || bounce.made_shutters != room_shell::shutters_on || bounce.made_hang != room_shell::lace_hang {
        make_cells(bounce);
    }
    bounce.cells[TABLE_C] = Cell { float3 { sun.table.x + table_off.x, sun.table.y + table_off.y, sun.table.w }, float3 { 0.0, 0.0, 1.0 }, TABLE_ALBEDO,
                                   PI * sun.table.z * sun.table.z, -1 };
    // The floor's cells under the rug.
    let fw = room_shell::LIBRARY.walls[room_shell::FAR_WALL].a.x / FLOOR_NX;
    let fd = wall_face() / FLOOR_NY;
    for c in FLOOR_NX * FLOOR_NY {
        let at = bounce.cells[FLOOR_C0 + c].at;
        bounce.cells[FLOOR_C0 + c].albedo = floor_albedo(float2 { sun.table.x, sun.table.y }, at, float2 { 0.5 * fw, 0.5 * fd });
    }
    var wins = windows();
    let gy = glass_y();
    let sky = sun.sky * (sun.sky_gain * glazing / PI);
    if members_traced && !sky_lets_made { make_sky_lets(); }
    let gain = sun.bounce_gain / PI;
    for c in CELLS {
        let cell = bounce.cells[c];
        bounce.leaves[c] = float3_0;
        bounce.seen[c] = float3_0;
        guard cell.area > 0.0 else { continue; }
        let lace = c >= LACE_C0;
        let own = if lace { (c - LACE_C0) / (2 * LACE_BANDS) } else { cell.niche };
        // The sky on it: from each window's glass in SKY_X × SKY_Y samples.
        var e = float3_0;
        for k in 3 {
            guard own < 0 || own == k else { continue; }
            let o = wins[k];
            let low = o.sill + GLAZED_LOW;
            let high = o.sill + o.height + o.rise - GLAZED_HIGH;
            let area = (2.0 * GLAZED_HALF / SKY_X) * ((high - low) / SKY_Y);
            for j in SKY_Y {
                for i in SKY_X {
                    let x = o.mid - GLAZED_HALF + (i + 0.5) * (2.0 * GLAZED_HALF / SKY_X);
                    let h = low + (j + 0.5) * ((high - low) / SKY_Y);
                    guard h < room_shell::head_at(o, x - o.mid) else { continue; }
                    let v = float3 { x, gy, h } - cell.at;
                    guard v.y > 1e-3 else { continue; }
                    let r2 = max(dot(v, v), 0.01);
                    let r = sqrt(r2);
                    let facing = if lace { v.y / r } else { dot(cell.normal, v) / r };
                    guard facing > 0.0 else { continue; }
                    let lets = if lace || own >= 0 { 1.0 } else { seen_through(sun.table, wins, cell.at, -1, float3 { x, gy, h }, k) };
                    guard lets > 0.0 else { continue; }
                    e = e + sky * (lets * sky_through(i, j, v) * area * (v.y / r) * facing / r2);
                }
            }
        }
        let thrown = bounce.sun[c] * (gain / cell.area);
        if lace {
            // The lace's share of the sun it stops is its own (LACE_SCATTER), not lifted by
            // the patches' gain: lifted, it threw on more than the sun brings it.
            let from_sky = balanced(e * ((1.0 - lace_lets(cell.at.z)) * LACE_SCATTER));
            let from_sun = bounce.sun[c] * (1.0 / (PI * cell.area));
            bounce.leaves[c] = (from_sky + balanced(from_sun)) * lace_source;
            bounce.seen[c] = bounce.leaves[c];
        } else {
            let from_sky = balanced(e * cell.albedo);
            bounce.leaves[c] = from_sky + balanced(thrown);
            bounce.seen[c] = from_sky;
        }
    }
}

// One bounce: every cell gathers what the others' light (bounce.leaves) brings it, as a
// small lambertian light each, its distance kept to about the cells' size so neighbours
// across a corner don't flare; the first bounce also sums each cell's form factors, so no
// cell takes more than the whole room's light. Then what it throws on by its albedo,
// toward grey, into leaves (the lace's none after the first) and added to seen.
fn bounce_once(sun: Sun, bounce: Bounce&, first: bool) {
    var wins = windows();
    for c in CELLS { bounce.gather[c] = float3_0; }
    if first { for c in CELLS { bounce.norm[c] = 0.0; } }
    for i in LACE_C0 {
        let a .= bounce.cells[i];
        guard a.area > 0.0 else { continue; }
        for j in i + 1..CELLS {
            let b .= bounce.cells[j];
            guard b.area > 0.0 else { continue; }
            let v = b.at - a.at;
            let ca = dot(a.normal, v);
            guard ca > 0.0 else { continue; }
            let cb = if niche_faces && j >= LACE_C0 { abs(dot(b.normal, v)) } else { -dot(b.normal, v) };
            guard cb > 0.0 else { continue; }
            let r2 = max(dot(v, v), 0.5 * (a.area + b.area));
            let lets = seen_through(sun.table, wins, a.at, a.niche, b.at, b.niche);
            guard lets > 0.0 else { continue; }
            let g = lets * ca * cb / (PI * r2 * r2);
            bounce.gather[i] = bounce.gather[i] + bounce.leaves[j] * (b.area * g);
            if j < LACE_C0 { bounce.gather[j] = bounce.gather[j] + bounce.leaves[i] * (a.area * g); }
            if first {
                bounce.norm[i] += b.area * g;
                if j < LACE_C0 { bounce.norm[j] += a.area * g; }
            }
        }
    }
    if first { for c in CELLS { bounce.norm[c] = 1.0 / max(bounce.norm[c], 1.0); } }
    for c in CELLS {
        guard c < LACE_C0 else { bounce.leaves[c] = float3_0; continue; }
        let cell .= bounce.cells[c];
        let out = balanced(bounce.gather[c] * cell.albedo * bounce.norm[c]);
        bounce.leaves[c] = out;
        bounce.seen[c] = bounce.seen[c] + out;
    }
}

// The probes at half density gather bounce.seen: each cell as a small lambertian light, as
// the sun's patches are (near2), through the niches' outlines, the lace, and past the
// table's top; into bounce.half, a probe's Gathered.
fn gather_half(sun: Sun, bounce: Bounce&) {
    var wins = windows();
    let x0 = room_shell::LIBRARY.walls[room_shell::FAR_WALL].a.x;
    for ih in HALF_H {
        for iz in HALF_Z {
            for ix in HALF_X {
                let p = float3 { x0 - INSET - half_column(ix) * CELL, PLAN_Y0 - 2 * iz * CELL, INSET + 2 * ih * CELL };
                let kp = probe_place(wins, p);
                guard kp > -2 else { continue; }
                let g = gather_cells(sun, bounce, wins, p, kp, near_faces(p));
                let at = GATHERED * ((ih * HALF_Z + iz) * HALF_X + ix);
                let q: f32[GATHERED] = [g.c.x, g.dr.x, g.dr.y, g.dr.z, g.c.y, g.dg.x, g.dg.y, g.dg.z, g.c.z, g.db.x, g.db.y, g.db.z,
                                        g.ex.x, g.ex.y, g.ex.z, g.ey.x, g.ey.y, g.ey.z, g.ez.x, g.ez.y, g.ez.z, g.qxx.x, g.qxx.y,
                                        g.qxx.z, g.qyy.x, g.qyy.y, g.qyy.z, g.qxy.x, g.qxy.y, g.qxy.z, g.qxz.x, g.qxz.y, g.qxz.z,
                                        g.qyz.x, g.qyz.y, g.qyz.z];
                for i in GATHERED { bounce.half[at + i] = q[i]; }
            }
        }
    }
    // The walled ones take the light of the nearest toward the room, as fill_walled.
    for ih in HALF_H {
        for iz in HALF_Z {
            for ix in HALF_X {
                let p = float3 { x0 - INSET - half_column(ix) * CELL, PLAN_Y0 - 2 * iz * CELL, INSET + 2 * ih * CELL };
                guard probe_place(wins, p) == -2 else { continue; }
                let step = if iz < HALF_Z / 2 { 1 } else { -1 };
                var from = iz + step;
                while from > 0 && from < HALF_Z - 1 &&
                      probe_place(wins, float3 { p.x, PLAN_Y0 - 2 * from * CELL, p.z }) == -2 { from += step; }
                let to = GATHERED * ((ih * HALF_Z + iz) * HALF_X + ix);
                let at = GATHERED * ((ih * HALF_Z + from) * HALF_X + ix);
                for i in GATHERED { bounce.half[to + i] = bounce.half[at + i]; }
            }
        }
    }
}

// What probe p (in niche kp, -1 the room) gathers of the cells' light (bounce.seen): each cell
// as a small lambertian light, as the sun's patches are (near2), through the niches' outlines,
// the lace, and past the table's top; a near cell split (gather_exact). f: the faces it
// stands before (near_faces).
fn gather_cells(sun: Sun, bounce: Bounce&, wins: room_shell::Opening[3]&, p: float3, kp: i64, f: float3) -> Gathered {
    let near2: f32 = gather_near;
    var g = Gathered { float3_0, float3_0, float3_0, float3_0, float3_0, float3_0, float3_0, float3_0, float3_0, float3_0, float3_0, float3_0 };
    for j in CELLS {
        let b .= bounce.cells[j];
        let l = bounce.seen[j];
        guard b.area > 0.0 && l.x + l.y + l.z > 0.0 else { continue; }
        let v = b.at - p;
        let off = if niche_faces && j >= LACE_C0 { abs(dot(b.normal, v)) } else { -dot(b.normal, v) };
        guard off > 0.0 else { continue; }
        let lets = seen_through(sun.table, wins, p, kp, b.at, b.niche);
        guard lets > 0.0 else { continue; }
        let side = sqrt(b.area);
        if gather_exact && dot(v, v) < 4.0 * side * side {
            // Split in its plane, along the plan's axes it lies across.
            let ta = if abs(b.normal.z) > 0.5 { float3 { 1.0, 0.0, 0.0 } } else { float3 { 0.0, 0.0, 1.0 } };
            let tb = cross(b.normal, ta);
            let each = b.area / (SPLIT * SPLIT);
            for sj in SPLIT {
                for si in SPLIT {
                    let q = b.at + ta * (side * ((si + 0.5) / SPLIT - 0.5)) + tb * (side * ((sj + 0.5) / SPLIT - 0.5));
                    let vq = q - p;
                    let off_q = if niche_faces && j >= LACE_C0 { abs(dot(b.normal, vq)) } else { -dot(b.normal, vq) };
                    guard off_q > 0.0 else { continue; }
                    let r2 = max(dot(vq, vq), 1e-4);
                    let r = sqrt(r2);
                    take(g, f, l * (lets * each * off_q / (PI * r * r2)), vq / r);
                }
            }
            continue;
        }
        let r2 = max(dot(v, v), near2);
        let r = sqrt(r2);
        take(g, f, l * (lets * b.area * off / (PI * r * r2)), v / r);
    }
    return g;
}

// The half grid's values (Gathered's) at the whole grid's probe (ix, iz, ih), trilinear.
fn half_probe(half: f32[HALF_FLOATS]&, ix: i64, iz: i64, ih: i64) -> f32[GATHERED] {
    let gx: f32 = if ix == NX - 1 { HALF_X - 1.0 } else { min(ix * 0.5, HALF_X - 2.0) };
    let gz: f32 = min(iz * 0.5, HALF_Z - 1.0);
    let gh: f32 = min(ih * 0.5, HALF_H - 1.0);
    let x0 = floor(gx) as i64;
    let z0 = floor(gz) as i64;
    let h0 = floor(gh) as i64;
    let x1 = min(x0 + 1, HALF_X - 1);
    let z1 = min(z0 + 1, HALF_Z - 1);
    let h1 = min(h0 + 1, HALF_H - 1);
    let fx = gx - x0;
    let fz = gz - z0;
    let fh = gh - h0;
    var v: f32[GATHERED] = [0.0; GATHERED];
    for k in 8 {
        let x = if (k & 1) != 0 { x1 } else { x0 };
        let z = if (k & 2) != 0 { z1 } else { z0 };
        let h = if (k & 4) != 0 { h1 } else { h0 };
        let w = (if (k & 1) != 0 { fx } else { 1.0 - fx }) * (if (k & 2) != 0 { fz } else { 1.0 - fz })
                * (if (k & 4) != 0 { fh } else { 1.0 - fh });
        guard w > 0.0 else { continue; }
        let at = GATHERED * ((h * HALF_Z + z) * HALF_X + x);
        for f in GATHERED { v[f] += w * half[at + f]; }
    }
    return v;
}
