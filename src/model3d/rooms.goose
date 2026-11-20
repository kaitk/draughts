// The light of the room the 3D board stands in on its table, one per season (task 104),
// after the manor's concept frames (task 093): the key through the window, the window's
// sky as a broad fill, and the walls', ceiling's and floor's light. The fill and the
// rest become the nine harmonics the shaders read as their ambient (harmonics()), so
// only the key costs anything a pixel. Tuned in tools/light_tune.
namespace rooms;
import std;
import vec;
import math;

struct Room {
    // The key, toward the light: x its azimuth in degrees (0 from the screen's left, 90
    // from behind the board, 180 from the right), y its height in degrees, z its
    // strength, w how dark its shadow is (1 full, less where the light is broad).
    key:       float4,
    key_color: float4,      // sRGB
    // The window's sky: x azimuth, y height, z strength, w how broad (0 a direction, 1
    // a hemisphere).
    fill:       float4,
    fill_color: float4,     // sRGB
    walls:      float4,     // sRGB, w: the light all round
    ceiling:    float4,     // sRGB, w: the light from above
    floor:      float4,     // sRGB, w: the light from below
    // A lamp or another window: x azimuth, y height, z strength; its color sRGB.
    lamp:       float4,
    lamp_color: float4,
    exposure:   f32 = 1.0,
}

// The library on the garden side, south-west, a mid-October afternoon
// (library-table-01, library-autumn-01 and -02): the low sun from the left and a little
// behind, deep amber; dark panelling and wallpaper, so the shade is deep and warm.
let AUTUMN = Room {
    key:        float4 { 30.0, 18.0, 6.5, 1.0 },
    key_color:  float4 { 1.0, 0.78, 0.56, 0.0 },
    fill:       float4 { 15.0, 25.0, 0.5, 0.6 },
    fill_color: float4 { 0.75, 0.82, 1.0, 0.0 },
    walls:      float4 { 0.45, 0.33, 0.24, 0.22 },
    ceiling:    float4 { 0.9, 0.85, 0.75, 0.1 },
    floor:      float4 { 0.4, 0.25, 0.15, 0.1 },
    lamp:       float4_0,
    lamp_color: float4_0,
};

// The upper hall, north-east, a January morning with no sun (hall-winter-table-01 and
// -02): the snowy balcony doors on the left a broad cool light with soft faint shadows,
// pale blue-grey plaster, a warm lamp far behind.
let WINTER = Room {
    key:        float4 { 15.0, 35.0, 2.6, 0.6 },
    key_color:  float4 { 0.86, 0.91, 1.0, 0.0 },
    fill:       float4 { 10.0, 20.0, 1.2, 0.7 },
    fill_color: float4 { 0.8, 0.88, 1.0, 0.0 },
    walls:      float4 { 0.62, 0.67, 0.72, 0.35 },
    ceiling:    float4 { 1.0, 1.0, 1.0, 0.2 },
    floor:      float4 { 0.35, 0.25, 0.18, 0.1 },
    lamp:       float4 { 120.0, 15.0, 0.15, 0.0 },
    lamp_color: float4 { 1.0, 0.7, 0.4, 0.0 },
};

// The upper hall on a May morning (prompts.txt's 7): low clear sun slanting in from the
// left, near white; a cool sky, a little green from the trees, pale walls.
let SPRING = Room {
    key:        float4 { 35.0, 25.0, 5.0, 1.0 },
    key_color:  float4 { 1.0, 0.96, 0.88, 0.0 },
    fill:       float4 { 20.0, 30.0, 1.0, 0.6 },
    fill_color: float4 { 0.75, 0.85, 1.0, 0.0 },
    walls:      float4 { 0.68, 0.74, 0.68, 0.4 },
    ceiling:    float4 { 1.0, 1.0, 1.0, 0.25 },
    floor:      float4 { 0.45, 0.35, 0.25, 0.12 },
    lamp:       float4_0,
    lamp_color: float4_0,
};

// The season's photograph, an evening by the sea: a low rose-gold sun from the left and
// behind, a violet-blue sky, warm walls; brighter in the shade than autumn's library.
let SUMMER = Room {
    key:        float4 { 40.0, 14.0, 7.0, 1.0 },
    key_color:  float4 { 1.0, 0.82, 0.68, 0.0 },
    fill:       float4 { 30.0, 25.0, 0.9, 0.6 },
    fill_color: float4 { 0.7, 0.72, 1.0, 0.0 },
    walls:      float4 { 0.75, 0.6, 0.5, 0.35 },
    ceiling:    float4 { 1.0, 0.95, 0.9, 0.2 },
    floor:      float4 { 0.45, 0.3, 0.22, 0.12 },
    lamp:       float4_0,
    lamp_color: float4_0,
};

// The room of season `season` (looks::AUTUMN..SUMMER, the photograph's kind).
fn of(season: i64) -> Room {
    if season == 1 { return WINTER; }
    if season == 2 { return SPRING; }
    if season == 3 { return SUMMER; }
    return AUTUMN;
}

// Toward a light at `azimuth` and `height` degrees, as Room.key has them.
fn toward(azimuth: f32, height: f32) -> float3 {
    let a = radians(azimuth);
    let h = radians(height);
    return float3 { -cos(a) * cos(h), sin(h), -sin(a) * cos(h) };
}

fn srgb_linear(c: f32) -> f32 {
    if c <= 0.04045 { return c / 12.92; }
    let e: f32 = 2.4;
    pow((c + 0.055) / 1.055, e)
}

fn color_of(c: float4) -> float3 { float3 { srgb_linear(c.x), srgb_linear(c.y), srgb_linear(c.z) } }

// The key's color times its strength, linear: the shaders' light_color with w 1.
fn key_light(r: Room) -> float3 { color_of(r.key_color) }

// Adds to `sh` a light from `d` sending `strength` × `c` onto a white surface facing it,
// over pi as the shaders' sum is, its lobe widened by `broad` (0 a direction, 1 about a
// hemisphere: the second band gone and the first lowered).
fn add_lobe(sh: float4[9]&, d: float3, c: float3, strength: f32, broad: f32) {
    let a1 = 2.0 / 3.0 * (1.0 - 0.35 * broad);
    let a2 = 0.25 * (1.0 - broad);
    let b: f32[9] = [0.282095, 0.488603 * d.y * a1, 0.488603 * d.z * a1, 0.488603 * d.x * a1,
                     1.092548 * d.x * d.y * a2, 1.092548 * d.y * d.z * a2,
                     0.315392 * (3.0 * d.y * d.y - 1.0) * a2, 1.092548 * d.x * d.z * a2,
                     0.546274 * (d.x * d.x - d.z * d.z) * a2];
    for k in 9 {
        let v = c * (strength * b[k]);
        sh[k] = float4 { sh[k].x + v.x, sh[k].y + v.y, sh[k].z + v.z, 0.0 };
    }
}

// The room's ambient as nine harmonics, as model3d::harmonics gives a photograph's: the
// walls all round, the ceiling from above, the floor from below, the window's sky and the
// lamp as lobes.
fn harmonics(r: Room) -> float4[9] {
    var sh: float4[9] = [float4 { 0.0, 0.0, 0.0, 0.0 }; 9];
    let walls = color_of(r.walls) * r.walls.w;
    // The light all round: the band 0 alone, its sum the walls' color.
    sh[0] = float4 { walls.x / 0.282095, walls.y / 0.282095, walls.z / 0.282095, 0.0 };
    add_lobe(sh, float3 { 0.0, 1.0, 0.0 }, color_of(r.ceiling), r.ceiling.w, 1.0);
    add_lobe(sh, float3 { 0.0, -1.0, 0.0 }, color_of(r.floor), r.floor.w, 1.0);
    add_lobe(sh, toward(r.fill.x, r.fill.y), color_of(r.fill_color), r.fill.z, r.fill.w);
    if r.lamp.z > 0.0 { add_lobe(sh, toward(r.lamp.x, r.lamp.y), color_of(r.lamp_color), r.lamp.z, 0.3); }
    return sh;
}
