// The 3D board's model, all it is but drawing: meshes, the themes as data, the
// photograph's light, and the plan of a theme's bake in steps. No graphics, so either
// renderer draws it from data and it is tested headless.
namespace model3d;
import std;
import vec;
import math;
import .mesh;
import .looks;
import .tables;

// The baked surfaces' targets: the plan (the field and the frame's top seen from above),
// `side` texels square, and the frame map, `side` wide. BAKE_SIDE, or PHONE_BAKE_SIDE on
// a phone (render3d::set_bake), whose field spans at most about a thousand pixels. A
// mitred frame's map holds only its four bands (LIT_FRAG: 0.2 to 5.65 of the map's 10.4
// world units across), its rows at the same density.
let BAKE_SIDE = 2048;
let PHONE_BAKE_SIDE = 1024;
let FRAME_MITRED_ROWS = 1152;   // at BAKE_SIDE, and in proportion at another side

// The wood's model: 0 noise drawn out along the grain, 1 growth rings, 2
// growth rings with pores and a fibre relief, 3 the first with thin lines and pores laid
// over it.
let WOOD_MODELS = 4;
let WOOD_MODEL = 2;

fn f4(v: float3, w: f32) -> float4 { float4 { v.x, v.y, v.z, w } }

// sRGB to linear, as the shaders take colors.
fn linear(c: f32) -> f32 {
    if c <= 0.04045 { return c / 12.92; }
    let e: f32 = 2.4;
    pow((c + 0.055) / 1.055, e)
}

fn linear4(c: float4) -> float4 { float4 { linear(c.x), linear(c.y), linear(c.z), c.w } }

// The dark pieces' brightness: jade's 0.65, turned walnut's 0.6 (task 094), else 1.
fn dark_brightness(mineral: f32) -> f32 { if mineral == looks::MINERAL_JADE { 0.65 } else if mineral == looks::MINERAL_TURNED_WOOD { 0.6 } else { 1.0 } }

fn dark_piece_color(c: float4, brightness: f32) -> float4 {
    let rgb = linear4(c);
    return float4 { rgb.x * brightness, rgb.y * brightness, rgb.z * brightness, rgb.w };
}

// Nine spherical harmonics of the photograph's light, convolved with the cosine and over
// pi, so the shader's sum is the irradiance a white Lambert surface sends back. The
// photograph is laid over the sphere as a latitude-longitude map, its middle straight
// behind the board (-z), its top up.
fn harmonics(px: const u8[:], size: i64, toward_grey: f32) -> float4[9] {
    var sh: float3[9] = [float3_0; 9];
    let step = 8;
    var total: f32 = 0.0;
    var y = step / 2;
    while y < size {
        let el = (0.5 - (y as f32 + 0.5) / size) * PI;
        let w = cos(el);
        var x = step / 2;
        while x < size {
            let az = ((x as f32 + 0.5) / size - 0.5) * TAU;
            let d = float3 { cos(el) * sin(az), sin(el), -cos(el) * cos(az) };
            let o = (y * size + x) * 4;
            let c = float3 { linear(px[o] / 255.0), linear(px[o + 1] / 255.0),
                             linear(px[o + 2] / 255.0) } * w;
            let b: f32[9] = [0.282095, 0.488603 * d.y, 0.488603 * d.z, 0.488603 * d.x,
                             1.092548 * d.x * d.y, 1.092548 * d.y * d.z,
                             0.315392 * (3.0 * d.y * d.y - 1.0), 1.092548 * d.x * d.z,
                             0.546274 * (d.x * d.x - d.z * d.z)];
            for k in 9 { sh[k] += c * b[k]; }
            total += w;
            x += step;
        }
        y += step;
    }
    // Each sample stands for 4 pi / total of the sphere; the bands' cosine lobes are
    // pi, 2 pi / 3 and pi / 4, and the result is over pi.
    let band: f32[3] = [1.0, 2.0 / 3.0, 0.25];
    var out: float4[9] = [float4_0; 9];
    // Part way to grey (the theme's), so a strongly colored photograph doesn't tint everything.
    for k in 9 {
        let l = if k == 0 { 0 } else { if k < 4 { 1 } else { 2 } };
        let c = sh[k] * (4.0 * PI / total * band[l]);
        let grey = (c.x + c.y + c.z) / 3.0;
        out[k] = f4(lerp(c, float3 { grey, grey, grey }, toward_grey), 0.0);
    }
    return out;
}

fn ease(a: f32, b: f32, x: f32) -> f32 { smoothstep(a, b, x) }

// The plain fade (shaders::FADE_FN) at (x, y) of a w × h screen, both 0..1 across it, in
// linear light: the backdrop's colors before they are encoded.
fn fade(f: float4[3]&, x: f32, y: f32, w: f32, h: f32) -> float3 {
    let qx = x - 0.5;
    let qy = y - 0.5;
    let m = max(w, h);
    let top = float3 { f[0].x, f[0].y, f[0].z };
    let low = float3 { f[1].x, f[1].y, f[1].z };
    let light = float3 { f[2].x, f[2].y, f[2].z };
    var c = lerp(top, low, ease(0.0, 1.0, y));
    let r = hypot(qx * (w / m) / 0.62, (qy - 0.04) * (h / m) / 0.5);
    c = lerp(c, light, 0.22 * (1.0 - ease(0.0, 1.0, r)));
    return c * (1.0 - 0.3 * ease(0.15, 0.6, qx * qx + qy * qy));
}

// The ambient light of the plain fade, as harmonics() takes a photograph's: the fade
// painted 64 texels square, laid round the board as the photograph is. A fade is far
// darker than a photograph, so the result is scaled to no_photo_ambient's brightness: the
// fade only tints the board's shadows.
fn fade_harmonics(f: float4[3]&, grey: f32) -> float4[9] {
    let n = 64;
    var px: u8[64 * 64 * 4] = [0; 64 * 64 * 4];
    for y in n {
        for x in n {
            let c = fade(f, (x + 0.5) / n, (y + 0.5) / n, 1.0, 1.0);
            let o = (y * n + x) * 4;
            px[o] = encode(c.x);
            px[o + 1] = encode(c.y);
            px[o + 2] = encode(c.z);
            px[o + 3] = 255;
        }
    }
    var sh = harmonics(px[..], n, grey);
    let luma = 0.2126 * sh[0].x + 0.7152 * sh[0].y + 0.0722 * sh[0].z;
    let a = no_photo_ambient();
    let k = (0.2126 * a.x + 0.7152 * a.y + 0.0722 * a.z) / max(luma, 1.0e-4);
    for i in 9 { sh[i] = sh[i] * k; }
    return sh;
}

// The ambient of a theme whose photograph isn't built in.
fn no_photo_ambient() -> float4 { float4 { 0.25, 0.17, 0.1, 0.0 } }

// A linear value in sRGB, 0..255, as linear() reads it back.
fn encode(c: f32) -> u8 {
    let v = clamp(c, 0.0, 1.0);
    let e: f32 = 1.0 / 2.4;
    let s = if v <= 0.0031308 { 12.92 * v } else { 1.055 * pow(v, e) - 0.055 };
    return (255.0 * s + 0.5) as u8;
}

// p turned `degrees` about the y axis, as view3d::spin turns the camera.
fn spin(p: float3, degrees: f32) -> float3 {
    let a = radians(degrees);
    let c = cos(a);
    let s = sin(a);
    return float3 { c * p.x + s * p.z, p.y, c * p.z - s * p.x };
}

// The steps a theme is put on in (render3d::theme_step), each small enough for a frame:
// the start; the bake's pipeline made, drawing one row (its compile can't be
// split: the largest step); the plan in PLAN_BANDS bands, the frame map in FRAME_BANDS,
// and the table in TABLE_BANDS (nothing without one), each surface's mips with its last;
// the photograph's two pipelines made; the photograph in its three parts
// (render3d::photo_part), the end with the last.
let PLAN_BANDS = 16;
let FRAME_BANDS = 6;
let TABLE_BANDS = 16;
let THEME_STEPS = 6 + PLAN_BANDS + FRAME_BANDS + TABLE_BANDS;

let BEGIN = 0;              // the look and size taken, the frame map's targets
let PIPELINE = 1;           // the bake's pipeline made, drawing the plan's first row
let PLAN = 2;               // a band of the plan
let FRAME = 3;              // a band of the frame map
let PHOTO_PIPELINES = 4;    // the photograph's shrink and blur made
let PHOTO = 5;              // a part of the photograph
let TABLE = 6;              // a band of the table's map

// What a step does, on which rows of its surface (y1 -1 all of them), whether the
// surface's mips follow, and which part of the photograph.
struct Step {
    what: i64  = BEGIN,
    y0:   i64  = 0,
    y1:   i64  = -1,
    mips: bool = false,
    part: i64  = 0,
}

// Step k, 0 to THEME_STEPS - 1, with the plan `side` square and a frame map `rows` high.
fn step(k: i64, rows: i64, side: i64 = BAKE_SIDE) -> Step {
    if k == 0 { return Step { what: BEGIN, .. }; }
    if k == 1 { return Step { what: PIPELINE, y0: 0, y1: 1, .. }; }
    if k < 2 + PLAN_BANDS {
        let b = k - 2;
        return Step { what: PLAN, y0: side * b / PLAN_BANDS, y1: side * (b + 1) / PLAN_BANDS,
                      mips: b == PLAN_BANDS - 1, .. };
    }
    if k < 2 + PLAN_BANDS + FRAME_BANDS {
        let b = k - 2 - PLAN_BANDS;
        return Step { what: FRAME, y0: rows * b / FRAME_BANDS, y1: rows * (b + 1) / FRAME_BANDS,
                      mips: b == FRAME_BANDS - 1, .. };
    }
    if k < 2 + PLAN_BANDS + FRAME_BANDS + TABLE_BANDS {
        let b = k - 2 - PLAN_BANDS - FRAME_BANDS;
        let h = table_size(side).y;
        return Step { what: TABLE, y0: h * b / TABLE_BANDS, y1: h * (b + 1) / TABLE_BANDS,
                      mips: b == TABLE_BANDS - 1, .. };
    }
    let photo = 2 + PLAN_BANDS + FRAME_BANDS + TABLE_BANDS;
    if k == photo { return Step { what: PHOTO_PIPELINES, .. }; }
    return Step { what: PHOTO, part: k - photo - 1, .. };
}

// The frame map's rows for a look at `side` texels wide: the mitred bands' where its
// frame is mitred.
fn frame_rows(t: looks::Theme&, side: i64 = BAKE_SIDE) -> i64 {
    if t.build.x < 0.5 { FRAME_MITRED_ROWS * side / BAKE_SIDE } else { side }
}

// The surfaces' extents in world units: the plan over the field and the frame's top, the
// frame map 10.4 across and as much down as its rows, of `side` across.
fn plan_extent() -> float2 { float2 { 2.0 * mesh::INNER, 2.0 * mesh::INNER } }
fn frame_extent(rows: i64, side: i64 = BAKE_SIDE) -> float2 { float2 { 10.4, 10.4 * rows / side } }
// The table's map over its top, `side` square.
fn table_size(side: i64 = BAKE_SIDE) -> int2 { int2 { side as i32, side as i32 } }
fn table_extent() -> float2 { float2 { 2.0 * mesh::TABLE_R, 2.0 * mesh::TABLE_R } }
// The table's wear (shaders::BAKE_FRAG's wear_at): a tile WEAR_TILE world units square
// that repeats, WEAR_SIDE texels a side at BAKE_SIDE (256 a unit, the top's map 64), in
// proportion at another side.
let WEAR_TILE: f32 = 2.0;
let WEAR_SIDE = 512;
fn wear_side(side: i64 = BAKE_SIDE) -> i64 { WEAR_SIDE * side / BAKE_SIDE }
