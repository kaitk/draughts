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
    // With both (tree.x 2): how many mips softer the tree's leaves are taken, so they give
    // the crown's shape and the noise's leaves its dapple.
    crown_blur: f32 = 3.0,
    // With both: how much of the crown's shade turns to the noise's dapple (its leaves'
    // shade times this, up to all).
    crown_fill: f32 = 3.0,
    // The tree's kind (trees::SPECIES_NAMES): how it branches, its leaves' size and shape.
    species: i64 = 0,
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
    // The wind in the trees, mild: x how strong (the leaves' sway in world units; the
    // limbs lean a tenth of it), y how fast, z how much more the leaves sway than the
    // noise's canopy, w how much the leaves ruffle in a gust.
    wind: float4 = float4 { 0.06, 1.0, 3.0, 0.5 },
    // The tree outside, its shadow baked (task 105, trees.goose) in place of the leaves'
    // noise above: x 1 the tree, 0 the noise, 2 both (its limbs, and the noise's leaves
    // where its crown has leaves, crown_blur); y its seed; z its trunk's height; w how many
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
    species:    1,
    // The maple close by, the window looking into its crown's outer leaves (task 105's
    // search: the board's part of the map lets through about 40% with the most fine
    // detail; a tall far tree blurs to blobs).
    tree:  float4 { 1.0, 4.0, 70.0, 1.5 },
    crown: float4 { 15.0, -50.0, 0.5, 0.3 },
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
    species:    3,
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
    species:    2,
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
    species:    2,
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
                         r.crown.x, r.crown.y, r.crown.z, r.crown.w, r.species };
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

// The wind in the trees at a moment (Room.wind), for shaders::LIGHT_FN: now x the whole
// tree's slow sway, -1..1; y the gust where the map's along is 0, 0..1; z the gust's
// change a unit along the wall, as its front crosses the crown. Each layer's shift (the
// limbs, the near, middle and far leaves) in the tree's map, a map of side `span`: xy in
// calm air, zw what a full gust adds.
struct Wind {
    now:   float4,
    shift: float4[4],
}

// The wind's noise (Zioma, GPU Gems 3, ch. 6): value noise of time, -1..1, a new random
// value each unit, eased between, so it never repeats.
fn wind_noise(x: f64) -> f64 {
    let i = floor(x);
    let f = x - i;
    let a = wind_hash(i);
    let b = wind_hash(i + 1.0);
    return (a + (b - a) * f * f * (3.0 - 2.0 * f)) * 2.0 - 1.0;
}

fn wind_hash(p: f64) -> f64 {
    var q = fract(p * 0.1031);
    q *= q + 33.33;
    q *= q + q;
    return fract(q);
}

fn eased(a: f64, b: f64, x: f64) -> f64 {
    let t = clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

// The gust at the seconds `front`, 0 mostly, toward 1 for about five seconds every
// twenty or so: a quick noise let through only while a slow one is high.
fn gust_at(front: f64) -> f64 {
    let quick = eased(0.0, 0.9, wind_noise(front * 0.3 + 3.7));
    return quick * eased(-0.4, 0.4, wind_noise(front * 0.05 + 8.1));
}

// The wind at `seconds` for a tree's map of side `span`. Two noises a layer, one along
// the wind and one across it (Zioma): the limbs follow the whole tree's slow sway alone,
// barely and as one piece; each leaf layer adds its own turbulence, quicker the farther
// out, as thin twigs move faster and more than thick limbs (Habel and others, 2009), and
// stronger in a gust, which pushes all along the wind. Each layer only shifts, whole.
fn wind_at(r: Room, seconds: f32, span: f32) -> Wind {
    let t = (seconds * r.wind.y) as f64;
    // Where the gust's front is a unit along the wall later: 0.015 s.
    let lag: f64 = 0.015;
    let gust = gust_at(t);
    let change = (gust_at(t - 10.0 * lag) - gust_at(t + 10.0 * lag)) / 20.0;
    // Each channel's rate and seed: the limbs, the near, middle and far leaves.
    let along_rate:  f64[4] = [0.22, 0.35, 0.42, 0.5];
    let across_rate: f64[4] = [0.17, 0.3, 0.37, 0.45];
    let along_seed:  f64[4] = [73.1, 0.0, 17.3, 41.9];
    let across_seed: f64[4] = [91.3, 29.7, 53.1, 7.9];
    // How far each layer sways in world units: the limbs a tenth of the leaves.
    let w = r.wind.x;
    let reach: f32[4] = [w * 0.1, w * r.wind.z, w * r.wind.z * 1.15, w * r.wind.z * 1.3];
    let sway = wind_noise(t * along_rate[0] + along_seed[0]) as f32;
    let sway_across = 0.3 * wind_noise(t * across_rate[0] + across_seed[0]) as f32;
    var out = Wind { float4 { sway, gust as f32, change as f32, 0.0 }, [float4_0; 4] };
    let dir = float2 { 1.0, 0.15 };
    let cross_dir = float2 { -0.15, 1.0 };
    let unit = if span > 0.0 { 1.0 / span } else { 0.0 };
    for i in 4 {
        // In calm air, and what a full gust adds (the turbulence up by 0.8, a push of 2).
        var calm = dir * sway + cross_dir * sway_across;
        var pushed = dir * 1.5;
        if i > 0 {
            let along = wind_noise(t * along_rate[i] + along_seed[i]) as f32;
            let across = wind_noise(t * across_rate[i] + across_seed[i]) as f32;
            calm = calm + dir * (0.6 * along) + cross_dir * (0.3 * across);
            pushed = dir * (2.0 + 0.8 * along) + cross_dir * (0.4 * across);
        }
        let k = reach[i] * unit;
        out.shift[i] = float4 { calm.x * k, calm.y * k, pushed.x * k, pushed.y * k };
    }
    return out;
}
