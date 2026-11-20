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
    // How soft the tree's shadows are against the sun's disc alone (1 as the sun makes
    // them; less is sharper than a real sun allows, for flecks as fine as the concept's).
    tree_blur: f32 = 0.3,
    // The window the key comes through, its shadow on the key (shaders::LIGHT_FN's
    // window_light; world units, a square is 1, about 3.3 cm): x how much of the key the
    // shade keeps out (0 no pattern), y how fast the penumbra widens with the distance
    // from the window (the sun's disc and the glass).
    pattern: float4 = float4 { 0.85, 0.012, 0.0, 0.0 },
    // x the wall's distance from the board's middle, y its turn from facing the sun
    // (degrees), z the sill's height over the board, w the opening's middle along the wall
    // from where the board's middle sees the sun.
    window: float4 = float4 { 36.0, 20.0, -2.0, 2.0 },
    // A pane's width and height, a bar's width.
    panes: float4 = float4 { 9.0, 11.0, 1.0, 0.0 },
    // x panes across, y panes up, z how far the curtain reaches in from the opening's
    // side (0 none), w how much of the sun its lace lets through.
    opening: float4 = float4 { 2.0, 4.0, 4.0, 0.45 },
    // The trees outside: x how much of the sky their leaves cover (0 none), y the leaves'
    // scale (clumps a unit), z how far beyond the window they stand, w how soft their
    // shadows are against the sun's disc alone.
    leaves: float4 = float4 { 0.5, 0.6, 100.0, 0.15 },
    // The single leaves within the clumps: x their scale against the clumps', y how few
    // gaps between them (0.4 many, 0.7 few), z how soft a fleck's edge, w how much their
    // own shadows show where the sky is open.
    twigs: float4 = float4 { 4.0, 0.55, 0.06, 0.35 },
    // The wind in the trees: x how far the leaves' shadows sway (in clumps; a tree's limbs
    // sway x world units, its leaves z times more), y how fast.
    wind: float4 = float4 { 0.12, 1.0, 3.0, 0.0 },
    // The tree outside, its shadow baked (task 105, trees.goose) in place of the leaves'
    // noise above: x 1 the tree, 0 the noise; y its seed; z its trunk's height; w how many
    // of its leaves it has (0 bare, 1 full).
    tree: float4 = float4 { 1.0, 4.0, 70.0, 1.8 },
    // x, y the trunk's foot along the wall and up from where the board's middle sees the
    // sun through it; z how crooked its limbs (0 straight, 1 an oak's); w how its twigs hang.
    crown: float4 = float4 { 0.0, -45.0, 0.5, 0.3 },
    // A leaf: x its length, y its width against it, z how much of the sun it lets through;
    // w how far beyond the window the trunk stands.
    foliage: float4 = float4 { 0.35, 0.7, 0.3, 30.0 },
}

// The library on the garden side, south-west, a mid-October afternoon
// (library-table-01, library-autumn-01 and -02): the low sun from the left and a little
// behind, deep amber, through the park's trees; dark panelling and wallpaper, so the
// shade is warm.
let AUTUMN = Room {
    key:        float4 { 30.0, 18.0, 6.5, 0.85 },
    key_color:  float4 { 1.0, 0.78, 0.56, 0.0 },
    fill:       float4 { 15.0, 25.0, 0.6, 0.6 },
    fill_color: float4 { 0.75, 0.82, 1.0, 0.0 },
    walls:      float4 { 0.45, 0.33, 0.24, 0.3 },
    ceiling:    float4 { 0.9, 0.85, 0.75, 0.12 },
    floor:      float4 { 0.4, 0.25, 0.15, 0.1 },
    lamp:       float4_0,
    lamp_color: float4_0,
    ..
};

// The upper hall, north-east, a January morning with no sun (hall-winter-table-01 and
// -02): the snowy balcony doors on the left a broad cool light with soft faint shadows,
// pale blue-grey plaster, a warm lamp far behind. No pattern: no sun casts one.
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
    pattern:    float4 { 0.0, 0.012, 0.0, 0.0 },
    tree:       float4 { 1.0, 6.0, 70.0, 0.0 },
    crown:      float4 { 0.0, -45.0, 1.0, 0.3 },
    ..
};

// The same hall on a clear January day: the sun at its winter height, about 8° (58.5° N),
// pale gold, long shadows; the snow outside a strong cold fill from the doors; a bare
// crooked oak, so only its branches cast shadows.
let WINTER_SUN = Room {
    key:        float4 { 25.0, 8.0, 6.0, 0.85 },
    key_color:  float4 { 1.0, 0.87, 0.72, 0.0 },
    fill:       float4 { 10.0, 12.0, 1.1, 0.7 },
    fill_color: float4 { 0.78, 0.86, 1.0, 0.0 },
    walls:      float4 { 0.62, 0.67, 0.72, 0.35 },
    ceiling:    float4 { 1.0, 1.0, 1.0, 0.2 },
    floor:      float4 { 0.35, 0.25, 0.18, 0.1 },
    lamp:       float4_0,
    lamp_color: float4_0,
    opening:    float4 { 2.0, 5.0, 3.0, 0.6 },
    leaves:     float4 { 0.35, 0.8, 150.0, 0.12 },
    tree:       float4 { 1.0, 6.0, 70.0, 0.0 },
    crown:      float4 { 0.0, -45.0, 1.0, 0.3 },
    ..
};

// The upper hall on a May morning (prompts.txt's 7): low clear sun slanting in from the
// left, near white; a cool sky, a little green from the trees, pale walls; the tree's
// young leaves small and sparse, letting more of the sun through.
let SPRING = Room {
    key:        float4 { 35.0, 25.0, 5.0, 0.85 },
    key_color:  float4 { 1.0, 0.96, 0.88, 0.0 },
    fill:       float4 { 20.0, 30.0, 1.0, 0.6 },
    fill_color: float4 { 0.75, 0.85, 1.0, 0.0 },
    walls:      float4 { 0.68, 0.74, 0.68, 0.4 },
    ceiling:    float4 { 1.0, 1.0, 1.0, 0.25 },
    floor:      float4 { 0.45, 0.35, 0.25, 0.12 },
    lamp:       float4_0,
    lamp_color: float4_0,
    leaves:     float4 { 0.4, 0.6, 100.0, 0.15 },
    tree:       float4 { 1.0, 4.0, 70.0, 0.9 },
    crown:      float4 { 0.0, -60.0, 0.5, 0.3 },
    foliage:    float4 { 0.3, 0.6, 0.3, 30.0 },
    ..
};

// The season's photograph, an evening by the sea: a low rose-gold sun from the left and
// behind, a violet-blue sky, warm walls; brighter in the shade than autumn's library; the
// tree in full leaf.
let SUMMER = Room {
    key:        float4 { 40.0, 14.0, 7.0, 0.85 },
    key_color:  float4 { 1.0, 0.82, 0.68, 0.0 },
    fill:       float4 { 30.0, 25.0, 0.9, 0.6 },
    fill_color: float4 { 0.7, 0.72, 1.0, 0.0 },
    walls:      float4 { 0.75, 0.6, 0.5, 0.35 },
    ceiling:    float4 { 1.0, 0.95, 0.9, 0.2 },
    floor:      float4 { 0.45, 0.3, 0.22, 0.12 },
    lamp:       float4_0,
    lamp_color: float4_0,
    tree:       float4 { 1.0, 4.0, 70.0, 2.4 },
    foliage:    float4 { 0.4, 0.7, 0.2, 30.0 },
    ..
};

// The takes, for the tuner and a season's choice: each season's room, and winter's sunny
// one beside its snow light.
let LIBRARY = 0;
let HALL_SNOW = 1;
let HALL_SUN = 2;
let HALL_SPRING = 3;
let SEA_EVENING = 4;
let COUNT = 5;
let NAMES = ["library", "hall-snow", "hall-sun", "hall-spring", "evening"];

fn get(take: i64) -> Room {
    if take == HALL_SNOW { return WINTER; }
    if take == HALL_SUN { return WINTER_SUN; }
    if take == HALL_SPRING { return SPRING; }
    if take == SEA_EVENING { return SUMMER; }
    return AUTUMN;
}

// The take season `season` (looks::AUTUMN..SUMMER, the photograph's kind) shows.
fn for_season(season: i64) -> i64 {
    if season == 1 { return HALL_SNOW; }
    if season == 2 { return HALL_SPRING; }
    if season == 3 { return SEA_EVENING; }
    return LIBRARY;
}

fn of(season: i64) -> Room { get(for_season(season)) }

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

// The tree's make (trees::Spec) from the room's tree, crown and foliage.
fn tree_spec(r: Room) -> trees::Spec {
    return trees::Spec { r.tree.y, r.tree.z, r.tree.w, r.foliage.x, r.foliage.y, r.foliage.z,
                         r.crown.x, r.crown.y, r.crown.z, r.crown.w };
}

// How far from the board's middle the table, the board and the pieces reach (mesh's
// table, TABLE_R about TABLE_Z): the tree's map covers only what falls on them.
let TABLE_REACH: f32 = 21.0;

// How the sun sees the tree through the window (trees::View), as shaders::LIGHT_FN's
// window_light traces it: the key's slant in the window's frame (which turns with the
// board, the light and the wall together), and the map's square over the opening as the
// key carries it out to the tree, with room for the blur and the sway.
fn tree_view(r: Room) -> trees::View {
    let l = toward(r.key.x, r.key.y);
    let h = normalize(float2 { l.x, l.z });
    let a = radians(r.window.y);
    let nw = float2 { cos(a) * h.x - sin(a) * h.y, sin(a) * h.x + cos(a) * h.y };
    let along = float2 { -nw.y, nw.x };
    let lw = float2 { l.x, l.z };
    let facing = max(dot(lw, nw), 0.05);
    let shear = float2 { dot(lw, along) / facing, l.y / facing };
    // The opening as the key carries it out to the tree, cut to what reaches the table.
    let size = float2 { r.opening.x * r.panes.x, r.opening.y * r.panes.y };
    let y0 = r.window.z - shear.y * r.window.x;
    let reach_x = TABLE_REACH * sqrt(1.0 + shear.x * shear.x);
    let reach_y = 2.0 + abs(shear.y) * TABLE_REACH;
    var x0 = max(r.window.w - size.x * 0.5, -reach_x);
    var x1 = min(r.window.w + size.x * 0.5, reach_x);
    var y1 = min(y0 + size.y, reach_y);
    var ya = max(y0, -reach_y);
    if x1 <= x0 || y1 <= ya {
        x0 = r.window.w - size.x * 0.5;
        x1 = r.window.w + size.x * 0.5;
        ya = y0;
        y1 = y0 + size.y;
    }
    let middle = float2 { (x0 + x1) * 0.5, (ya + y1) * 0.5 };
    let span = max(x1 - x0, y1 - ya) + 8.0;
    let sun: f32 = 0.0093;
    return trees::View { shear, middle, span, (r.window.x + r.foliage.w) / facing, facing,
                         sun * r.tree_blur, -r.foliage.w };
}
