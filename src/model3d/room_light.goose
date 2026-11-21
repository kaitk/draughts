// The library's light baked once when the room turns on and again when the sun moves
// (task 107's light round): what reaches each point of the room besides the sun itself,
// on a grid of probes 0.3 m apart over the shell (room_shell::LIBRARY). Its sources: the
// sky seen through the three windows, only through each niche's outline and past the
// lace, the table's top shading what is under it; the sun's patches thrown back off the
// floor, the walls, the sills and the reveals, each patch's light from the sun's rays
// traced through the glass; and the light the room throws on after that, bounced
// BOUNCES times between the cells of a coarse grid over its surfaces (the sky's light
// landing on the floor, the sills and reveals, the lit ceiling, the backlit lace), which
// the probes gather on a grid of half their density. Each probe keeps, per colour, the light as a constant and
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
// The ceiling's and the cornice's limewash, surfaces::LOOK's two ends' mean, linear.
let CEILING_ALBEDO = float3 { 0.446, 0.383, 0.279 };

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
                    a = PLASTER_ALBEDO;
                    cell = reveal_cell(k, o, at, if d.x > 0.0 { 1 } else { 0 });
                } else {
                    // Into the room, past the lace, to the floor, a wall, or the table.
                    let b = q + d * t_face;
                    guard in_niche(o, b) else { continue; }
                    let c = q + d * ((gy - lace_y) / -d.y);
                    if in_lace(o, c) {
                        let lc = lace_cell(k, o, c);
                        bounce.sun[lc] = bounce.sun[lc] + p * ((1.0 - LACE_LETS) * LACE_SCATTER);
                        p = p * LACE_LETS;
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
        let balanced = c + (float3 { grey, grey, grey } - c) * BOUNCE_GREY;
        out[count] = Patch { where[b] / lit[b], normal[b], albedo[b], balanced };
        count++;
    }
    return count;
}

// A direction of the plan in the room's frame: x along u is the plan's -x, z along v its -y.
fn to_room(d: float3) -> float3 { float3 { -d.x, d.z, -d.y } }

// The bake: every probe's light into `atlas` (ATLAS_FLOATS, the layout above), light over
// pi as the shaders' harmonics are. `patches` and `count` from sun_patches; the bounced
// light from bounce.half (gather_half), spread over the whole grid.
fn bake(sun: Sun, patches: Patch[BINS]&, count: i64, bounce: Bounce&, atlas: f32[:]) {
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
                let hp = half_probe(bounce.half, ix, iz, ih);
                c = c + float3 { hp[0], hp[4], hp[8] };
                dr = dr + float3 { hp[1], hp[2], hp[3] };
                dg = dg + float3 { hp[5], hp[6], hp[7] };
                db = db + float3 { hp[9], hp[10], hp[11] };
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
// How many times the room throws its light on after the first.
let BOUNCES = 3;
// Of the light the lace stops, the share it throws on into the room, diffusely: its thread
// is near white (0.8), and about half of what it scatters goes forward.
let LACE_SCATTER: f32 = 0.4;
// The probes' grid at half its density (every other probe each way), where the bounced
// light is gathered before it is spread over the whole grid.
let HALF_X = 15;
let HALF_Z = 13;
let HALF_H = 7;
let HALF_FLOATS = 16380;   // HALF_X × HALF_Z × HALF_H × 12

// A cell: its middle (the plan's metres), its normal, its albedo, its area (0 a hole, the
// windows' openings), and the niche it lies in (-1 the room).
struct Cell { at: float3, normal: float3, albedo: float3, area: f32, niche: i64 }

// The bounces' buffers, fixed: the cells (made once), the sun's light thrown back off each
// (from sun_patches: what each cell's rays bring, its albedo in), the light leaving each in
// this bounce and what it gathers for the next (over pi), the share of the room each cell
// sees (its form factors' sum, capped at 1), what the probes gather (the light leaving
// each cell but the sun's first, which the patches carry), and the half grid's probes.
struct Bounce {
    cells:  Cell[CELLS],
    made:   bool,
    sun:    float3[CELLS],
    leaves: float3[CELLS],
    gather: float3[CELLS],
    seen:   float3[CELLS],
    norm:   f32[CELLS],
    half:   f32[HALF_FLOATS],
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
        for side in 2 {
            let x = if side == 0 { x0 } else { x0 + o.width };
            let n = float3 { if side == 0 { 1.0 } else { -1.0 }, 0.0, 0.0 };
            for u in REVEAL_UP {
                for j in NICHE_DEEP {
                    let at = float3 { x, face + (j + 0.5) * deep, o.sill + (u + 0.5) * rise };
                    bounce.cells[base + 12 + side * 20 + u * NICHE_DEEP + j] = Cell { at, n, PLASTER_ALBEDO, rise * deep, k };
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
        guard in_niche(o, room + v * ((face - room.y) / v.y)) else { return 0.0; }
        let lace_y = face - room_shell::LACE_OFF;
        if room.y < lace_y && in_lace(o, room + v * ((lace_y - room.y) / v.y)) { lets = LACE_LETS; }
    }
    guard !under_table(t, a, b) else { return 0.0; }
    return lets;
}

// A colour taken part of the way to grey, as the sun's patches are (BOUNCE_GREY).
fn balanced(c: float3) -> float3 {
    let grey = 0.2126 * c.x + 0.7152 * c.y + 0.0722 * c.z;
    return c + (float3 { grey, grey, grey } - c) * BOUNCE_GREY;
}

// The light the room first throws on, besides the sun's patches: each cell's sky (seen
// through the niches' outlines and past the lace, as the probes see it; a niche's own cells
// see their own window's glass straight) by its albedo, and the sun's light thrown back
// off it (from sun_patches), both taken toward grey; the lace's bands, lit on their backs by
// the sun (sun_patches) and the sky through their window, throw on what they stop. Into
// bounce.leaves; bounce.seen starts with all of it but the sun's, which the patches carry.
fn first_light(sun: Sun, bounce: Bounce&) {
    if !bounce.made { make_cells(bounce); }
    bounce.cells[TABLE_C] = Cell { float3 { sun.table.x, sun.table.y, sun.table.w }, float3 { 0.0, 0.0, 1.0 }, TABLE_ALBEDO,
                                   PI * sun.table.z * sun.table.z, -1 };
    var wins = windows();
    let gy = glass_y();
    let sky = sun.sky * (sun.sky_gain * GLAZING / PI);
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
                    e = e + sky * (lets * area * (v.y / r) * facing / r2);
                }
            }
        }
        let thrown = bounce.sun[c] * (gain / cell.area);
        if lace {
            let from_sky = balanced(e * ((1.0 - LACE_LETS) * LACE_SCATTER));
            bounce.leaves[c] = from_sky + balanced(thrown);
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
            let cb = -dot(b.normal, v);
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
// the sun's patches are (OWN_ROW, near2), through the niches' outlines, the lace, and past
// the table's top; into bounce.half, a probe's three colours' constant and direction.
fn gather_half(sun: Sun, bounce: Bounce&) {
    var wins = windows();
    let x0 = room_shell::LIBRARY.walls[room_shell::FAR_WALL].a.x;
    let near2: f32 = 0.09;
    for ih in HALF_H {
        for iz in HALF_Z {
            for ix in HALF_X {
                let p = float3 { x0 - INSET - 2 * ix * CELL, PLAN_Y0 - 2 * iz * CELL, INSET + 2 * ih * CELL };
                let kp = niche_of(p);
                var c = float3_0;
                var dr = float3_0;
                var dg = float3_0;
                var db = float3_0;
                for j in CELLS {
                    let b .= bounce.cells[j];
                    let l = bounce.seen[j];
                    guard b.area > 0.0 && l.x + l.y + l.z > 0.0 else { continue; }
                    let v = b.at - p;
                    let off = -dot(b.normal, v);
                    guard off > OWN_ROW else { continue; }
                    let lets = seen_through(sun.table, wins, p, kp, b.at, b.niche);
                    guard lets > 0.0 else { continue; }
                    let r2 = max(dot(v, v), near2);
                    let r = sqrt(r2);
                    let w = l * (lets * b.area * off / (PI * r * r2));
                    let dir = to_room(v / r);
                    c = c + w * 0.25;
                    dr = dr + dir * (0.5 * w.x);
                    dg = dg + dir * (0.5 * w.y);
                    db = db + dir * (0.5 * w.z);
                }
                let at = 12 * ((ih * HALF_Z + iz) * HALF_X + ix);
                let q: f32[12] = [c.x, dr.x, dr.y, dr.z, c.y, dg.x, dg.y, dg.z, c.z, db.x, db.y, db.z];
                for i in 12 { bounce.half[at + i] = q[i]; }
            }
        }
    }
}

// The half grid's twelve values at the whole grid's probe (ix, iz, ih), trilinear.
fn half_probe(half: f32[HALF_FLOATS]&, ix: i64, iz: i64, ih: i64) -> f32[12] {
    let gx: f32 = min(ix * 0.5, HALF_X - 1.0);
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
    var v: f32[12] = [0.0; 12];
    for k in 8 {
        let x = if (k & 1) != 0 { x1 } else { x0 };
        let z = if (k & 2) != 0 { z1 } else { z0 };
        let h = if (k & 4) != 0 { h1 } else { h0 };
        let w = (if (k & 1) != 0 { fx } else { 1.0 - fx }) * (if (k & 2) != 0 { fz } else { 1.0 - fz })
                * (if (k & 4) != 0 { fh } else { 1.0 - fh });
        guard w > 0.0 else { continue; }
        let at = 12 * ((h * HALF_Z + z) * HALF_X + x);
        for f in 12 { v[f] += w * half[at + f]; }
    }
    return v;
}
