// The library's light baked once when the room turns on and again when the sun moves
// (task 107's light round): what reaches each point of the room besides the sun itself,
// on a grid of probes 0.3 m apart over the shell (room_shell::LIBRARY). Two sources: the
// sky seen through the three windows, only through each niche's outline and past the
// lace, the table's top shading what is under it; and the sun's patches thrown back once
// off the floor, the walls, the sills and the reveals, each patch's light from the sun's
// rays traced through the glass. Each probe keeps, per colour, the light as a constant and
// a direction (the first two bands of spherical harmonics, the clamped cosine folded in),
// so ROOM_FRAG reads a surface's light for its normal from two texels a colour. No
// graphics: render3d puts the result on the GPU.
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
let OWN_ROW: f32 = 0.2;       // how far out from a surface the row that reads it reaches
let PROBES = 10140;           // NX × NZ × NH

// The atlas the probes go into: the height's slices side by side (NX × NH across), the
// three colours' blocks one over the other (3 × NZ up), four floats a texel: the constant
// and the direction's x, y, z in the room's frame.
let ATLAS_W = 390;            // NX × NH
let ATLAS_H = 78;             // 3 × NZ
let ATLAS_FLOATS = 121680;    // ATLAS_W × ATLAS_H × 4

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
// What the lace lets through where it hangs before the niche (its thread lets 0.45 of the
// sun through where it covers, and it covers about half).
let LACE_LETS: f32 = 0.72;

// The surfaces' mean albedo, linear: the herringbone's oak, the wallpaper, the wainscot,
// the white paint of the doors and joinery, the limewash of the reveals, the sills' stone,
// the table's mahogany (measured off the room's shots and surfaces::LOOK).
let FLOOR_ALBEDO = float3 { 0.078, 0.045, 0.022 };
let PAPER_ALBEDO = float3 { 0.064, 0.048, 0.034 };
let OAK_ALBEDO = float3 { 0.034, 0.014, 0.005 };
let PAINT_ALBEDO = float3 { 0.565, 0.515, 0.423 };
let PLASTER_ALBEDO = float3 { 0.55, 0.5, 0.43 };
let STONE_ALBEDO = float3 { 0.468, 0.445, 0.392 };
let TABLE_ALBEDO = float3 { 0.12, 0.06, 0.035 };

// How far the sun's patches' thrown-back light is taken to grey (0 its own colour).
let BOUNCE_GREY: f32 = 0.6;

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

// Whether the segment a to b crosses the table's top (a disc at its height).
fn under_table(t: float4, a: float3, b: float3) -> bool {
    guard (a.z - t.w) * (b.z - t.w) < 0.0 else { return false; }
    let f = (t.w - a.z) / (b.z - a.z);
    let x = a.x + (b.x - a.x) * f - t.x;
    let y = a.y + (b.y - a.y) * f - t.y;
    return x * x + y * y < t.z * t.z;
}

// A wall's albedo at a point of it: the doors painted, the wainscot to 1.2 m, the paper
// over it. along: the plan's x on the hall wall, its y on the end walls.
fn wall_albedo(wall: i64, along: f32, h: f32) -> float3 {
    let s = room_shell::LIBRARY;
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

// The sun's rays through the three windows into the patches they light, binned; how much
// of the sun each ray's glass point lets through the tree outside is `tree` (RAYS, from
// render3d, 1 where no tree). Returns how many patches are lit.
fn sun_patches(sun: Sun, tree: const f32[:], out: Patch[BINS]&) -> i64 {
    var power:  float3[BINS] = [float3_0; BINS];
    var where:  float3[BINS] = [float3_0; BINS];
    var normal: float3[BINS] = [float3_0; BINS];
    var albedo: float3[BINS] = [float3_0; BINS];
    var lit:    f32[BINS]    = [0.0; BINS];
    let s = room_shell::LIBRARY;
    let wins = windows();
    let d = float3_0 - sun.toward;
    guard d.y < -0.02 && d.z < -0.02 else { return 0; }
    let face = wall_face();
    let gy = glass_y();
    let room_x = s.walls[room_shell::FAR_WALL].a.x;
    let lace_y = face - room_shell::LACE_OFF;
    for k in 3 {
        let o = wins[k];
        let cell = (2.0 * GLAZED_HALF / RAYS_X) * ((o.height + o.rise - GLAZED_LOW - GLAZED_HIGH) / RAYS_Y);
        let each = sun.light * (cell * -d.y * GLAZING);
        for j in RAYS_Y {
            for i in RAYS_X {
                let q = ray_point(k, i, j);
                var p = each * tree[(k * RAYS_Y + j) * RAYS_X + i];
                // Through the niche to the wall's face: the sill, a reveal, or on.
                let t_face = (gy - face) / -d.y;
                let t_sill = (q.z - o.sill) / -d.z;
                let side = if d.x > 0.0 { 0.5 * o.width } else { -0.5 * o.width };
                let t_reveal = if abs(d.x) > 1e-4 { (o.mid + side - q.x) / d.x } else { 1e9 };
                var bin = -1;
                var at = float3_0;
                var n = float3_0;
                var a = float3_0;
                if t_sill < t_face && t_sill < t_reveal {
                    bin = 1008 + 576 + 896 + 3 * k;
                    at = q + d * t_sill;
                    n = float3 { 0.0, 0.0, 1.0 };
                    a = STONE_ALBEDO;
                } else if t_reveal < t_face {
                    bin = 1008 + 576 + 896 + 3 * k + (if d.x > 0.0 { 1 } else { 2 });
                    at = q + d * t_reveal;
                    n = float3 { if d.x > 0.0 { -1.0 } else { 1.0 }, 0.0, 0.0 };
                    a = PLASTER_ALBEDO;
                } else {
                    // Into the room, past the lace, to the floor, a wall, or the table.
                    let b = q + d * t_face;
                    guard in_niche(o, b) else { continue; }
                    let c = q + d * ((gy - lace_y) / -d.y);
                    if in_lace(o, c) { p = p * LACE_LETS; }
                    var t = b.z / -d.z;
                    var hit = 0;
                    let t_hall = b.y / -d.y;
                    if t_hall < t { t = t_hall; hit = 1; }
                    if d.x < 0.0 && b.x / -d.x < t { t = b.x / -d.x; hit = 2; }
                    if d.x > 0.0 && (room_x - b.x) / d.x < t { t = (room_x - b.x) / d.x; hit = 3; }
                    let tt = (b.z - sun.table.w) / -d.z;
                    if tt > 0.0 && tt < t {
                        let e = b + d * tt;
                        let dx = e.x - sun.table.x;
                        let dy = e.y - sun.table.y;
                        if dx * dx + dy * dy < sun.table.z * sun.table.z { t = tt; hit = 4; }
                    }
                    at = b + d * t;
                    if hit == 0 {
                        let bx = clamp((at.x / BIN) as i64, 0, FLOOR_BINS_X - 1);
                        let by = clamp((at.y / BIN) as i64, 0, FLOOR_BINS_Y - 1);
                        bin = by * FLOOR_BINS_X + bx;
                        n = float3 { 0.0, 0.0, 1.0 };
                        a = FLOOR_ALBEDO;
                    } else if hit == 1 {
                        let bx = clamp((at.x / BIN) as i64, 0, FLOOR_BINS_X - 1);
                        let bh = clamp((at.z / BIN) as i64, 0, WALL_BINS_H - 1);
                        bin = 1008 + bh * FLOOR_BINS_X + bx;
                        n = float3 { 0.0, 1.0, 0.0 };
                        a = wall_albedo(room_shell::HALL_WALL, at.x, at.z);
                    } else if hit < 4 {
                        let by = clamp((at.y / BIN) as i64, 0, FLOOR_BINS_Y - 1);
                        let bh = clamp((at.z / BIN) as i64, 0, WALL_BINS_H - 1);
                        bin = 1008 + 576 + (hit - 2) * 448 + bh * FLOOR_BINS_Y + by;
                        n = float3 { if hit == 2 { 1.0 } else { -1.0 }, 0.0, 0.0 };
                        a = wall_albedo(if hit == 2 { room_shell::STOVE_WALL } else { room_shell::FAR_WALL }, at.y, at.z);
                    } else {
                        bin = BINS - 1;
                        n = float3 { 0.0, 0.0, 1.0 };
                        a = TABLE_ALBEDO;
                    }
                }
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
        let balanced = c + (float3 { grey, grey, grey } - c) * BOUNCE_GREY;
        out[count] = Patch { where[b] / lit[b], normal[b], albedo[b], balanced };
        count++;
    }
    return count;
}

// A direction of the plan in the room's frame: x along u is the plan's -x, z along v its -y.
fn to_room(d: float3) -> float3 { float3 { -d.x, d.z, -d.y } }

// The bake: every probe's light into `atlas` (ATLAS_FLOATS, the layout above), light over
// pi as the shaders' harmonics are. `patches` and `count` from sun_patches.
fn bake(sun: Sun, patches: Patch[BINS]&, count: i64, atlas: f32[:]) {
    assert(atlas.len == ATLAS_FLOATS);
    let face = wall_face();
    let gy = glass_y();
    let lace_y = face - room_shell::LACE_OFF;
    let x0 = room_shell::LIBRARY.walls[room_shell::FAR_WALL].a.x;
    let wins = windows();
    // The sky's samples: on each window's glazing, each its share of the glass's area.
    var sky_at:     float3[120] = [float3_0; 120];
    var sky_area:   f32[120]    = [0.0; 120];
    var sky_window: i64[120]    = [0; 120];
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
                sky_n++;
            }
        }
    }
    let sky = sun.sky * (sun.sky_gain * GLAZING / PI);
    let inv_pi2 = sun.bounce_gain / (PI * PI);
    // The probes' near limit, so a patch's light doesn't spike at the probes beside it:
    // about a bin's size.
    let near2: f32 = 0.09;
    for ih in NH {
        for iz in NZ {
            for ix in NX {
                let p = float3 { x0 - INSET - ix * CELL, PLAN_Y0 - iz * CELL, INSET + ih * CELL };
                var c = float3_0;
                var dr = float3_0;
                var dg = float3_0;
                var db = float3_0;
                // The sky, seen through the niche's outline at the wall's face and past
                // the lace.
                for si in sky_n {
                    let s = sky_at[si];
                    let v = s - p;
                    guard v.y > 1e-3 else { continue; }
                    let o = wins[sky_window[si]];
                    var lets: f32 = 1.0;
                    if p.y <= face + 1e-4 {
                        let f = max(face - p.y, 0.0) / v.y;
                        guard in_niche(o, p + v * f) else { continue; }
                        if p.y < lace_y && in_lace(o, p + v * ((lace_y - p.y) / v.y)) { lets = LACE_LETS; }
                    }
                    guard !under_table(sun.table, p, s) else { continue; }
                    let r2 = max(dot(v, v), near2);
                    let r = sqrt(r2);
                    let w = sky * (lets * sky_area[si] * (v.y / r) / r2);
                    let dir = to_room(v / r);
                    c = c + w * 0.25;
                    dr = dr + dir * (0.5 * w.x);
                    dg = dg + dir * (0.5 * w.y);
                    db = db + dir * (0.5 * w.z);
                }
                // The sun's patches, each a small lambertian light facing its normal.
                for pi in count {
                    let pt .= patches[pi];
                    let v = pt.at - p;
                    let r2 = max(dot(v, v), near2);
                    let r = sqrt(r2);
                    // A probe in the row before the patch's own surface (half a step out)
                    // takes none of it: that surface reads this row, and a flat surface
                    // doesn't light itself; with the patch behind it, the constant and the
                    // direction would ring dark across the wall (the hall door's band).
                    let off = -dot(pt.normal, v);
                    guard off > OWN_ROW else { continue; }
                    let facing = off / r;
                    guard !under_table(sun.table, p, pt.at) else { continue; }
                    let w = pt.power * (facing * inv_pi2 / r2);
                    let dir = to_room(v / r);
                    c = c + w * 0.25;
                    dr = dr + dir * (0.5 * w.x);
                    dg = dg + dir * (0.5 * w.y);
                    db = db + dir * (0.5 * w.z);
                }
                let x = ih * NX + ix;
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
}
