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
    // The gusts (gust_at): x how strong (1 as they were at first: the leaves pushed about
    // three times calm air's sway and the branches' clock 2.5 times as fast), y how long
    // one lasts and z the mean time from one to the next, in the wind's seconds; w how much
    // of the crown one reaches (1 all of it, less only some regions of branches).
    gust: float4 = float4 { 0.5, 1.75, 20.0, 0.4 },
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
    // The room round the table (model3d::surfaces) lit more than the board's ambient
    // alone gives it: the sun's patch and the window's sky thrown back off the floor, the
    // ceiling and the walls into the shade, sRGB, w its strength. The board keeps its
    // deep shade between the sun's flecks; the room's floor and panelling need this to read.
    bounce: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    // How much brighter the room's surfaces are exposed than the board, as a painter or
    // a photograph's local tonemapping lifts a dark room round a bright subject: the dark
    // oak in a low sun is otherwise all in the tonemap's toe.
    room_exposure: f32 = 1.0,
    // The view out of the library's windows (model3d::view_out), unlit, exposed on its own
    // and through the room's tonemap: 1.8 takes the sky into the shoulder, as the
    // concepts' bright windows do.
    outside: f32 = 1.8,
    // The library's shell (room_shell) lit as a room of its own (task 107's light round):
    // x how fast the sun's penumbra widens through its windows (world units a unit of
    // distance; 0 the pattern's, pattern.y; the sun's disc alone gives 0.0047), y the sun
    // on the room's surfaces over the board's.
    shell_sun: float4 = float4 { 0.0, 1.0, 0.0, 0.0 },
    // Its baked light (model3d::room_light): x the sky through the windows, y the sun's
    // patches thrown back once, z how much of the harmonics the room keeps beside them, w
    // how much of bounce; x and y 0, nothing baked and the harmonics and bounce as before.
    baked: float4 = float4 { 0.0, 0.0, 1.0, 1.0 },
    // The window's glow round its bright glass and lace (render3d::bloom_pass), no rays: x
    // how strong (0 none), y from what whiteness (the least channel, sRGB), z the knee
    // over it, w how wide (sigma in quarter pixels).
    bloom: float4 = float4_0,
    // The shell's corners and edges darkened (model3d::corner_map, baked with the shell's
    // mesh), its indirect light only: x how much (1 a corner's full share of the sky
    // hidden), y how far from a corner it reaches (metres); 0 none.
    corners: float4 = float4_0,
    // The room's ambient occlusion from what the screen shows (render3d::ssao_pass), its
    // indirect light only, where it finds more than the corners know: x how strong (1 all
    // it finds), y its reach (metres), z its bias (the cosine over a pixel's plane that
    // hides nothing, so a flat surface stays clear of its half floats' steps), w its gain
    // (a tap that hides all hides this many taps' share); x 0 none.
    ssao: float4 = float4_0,
    // The waxed floor's mirror of the room (render3d::planar_pass): x how strong (1 the wax's
    // Fresnel as it is; 0 none, the room's box reflected instead), y the wax film's roughness,
    // which sets its blur and Fresnel, as a share of the oak's, z how much each board's wax
    // differs from the next (a share), w how much brighter the view out is there than its
    // look through the tonemap (a clear sky's light over the room's; 1 as the look).
    planar: float4 = float4_0,
}

// The library on the garden side, south-west, a mid-October afternoon
// (library-table-01, library-autumn-01 and -02): the low sun from the left and a little
// behind, deep amber, through the park's trees; dark panelling and wallpaper, so the
// shade is warm.
let AUTUMN = Room {
    key:        float4 { 30.0, 18.0, 7.0, 0.85 },
    key_color:  float4 { 1.0, 0.78, 0.56, 0.0 },
    fill:       float4 { 15.0, 25.0, 0.45, 0.6 },
    fill_color: float4 { 0.75, 0.82, 1.0, 0.0 },
    walls:      float4 { 0.45, 0.33, 0.24, 0.22 },
    ceiling:    float4 { 0.9, 0.85, 0.75, 0.12 },
    floor:      float4 { 0.4, 0.25, 0.15, 0.1 },
    lamp:       float4_0,
    lamp_color: float4_0,
    species:    1,
    // The maple close by, the window looking into its crown's outer leaves, the board
    // and the table under even dapple, the shade deep between the flecks (task 105's
    // searches; a tall far tree blurs to blobs).
    pattern:   float4 { 0.9, 0.012, 0.0, 0.0 },
    tree:      float4 { 1.0, 11.0, 70.0, 1.0 },
    crown:     float4 { -10.0, -60.0, 0.5, 0.3 },
    foliage:   float4 { 0.4, 0.7, 0.15, 30.0 },
    tree_blur: 0.2,
    // The room round the table as style-01 has it: dim and warm, the panelling's detail
    // in the shade, the sun's patch bright.
    bounce:        float4 { 0.85, 0.78, 0.7, 0.2 },
    room_exposure: 1.8,
    shell_sun:     float4 { 0.0055, 4.4, 0.0, 0.0 },
    baked:         float4 { 7.0, 10.0, 0.2, 0.3 },
    bloom:         float4 { 0.45, 0.72, 0.15, 4.0 },
    corners:       float4 { 1.0, 0.4, 0.0, 0.0 },
    ssao:          float4 { 1.0, 0.35, 0.05, 3.0 },
    planar:        float4 { 0.85, 0.5, 0.12, 6.0 },
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

// The room with its tree as the library's shell shows it (task 107's quick pass): grown and
// moved so its crown's dapple falls through all three windows, the trunk 3 m out behind
// a pier, not across a window; the game's window keeps the room's own tree.
fn shell_tree(r: Room) -> Room {
    var t = r;
    t.tree = float4 { r.tree.x, 3.0, 330.0, r.tree.w * 3.0 };
    t.crown = float4 { -25.0, -290.0, r.crown.z, r.crown.w };
    t.foliage = float4 { r.foliage.x, r.foliage.y, r.foliage.z, 90.0 };
    return t;
}

// The shell's tree's trunk and limbs as its map draws them (trees::View.wood): their widths
// and their blur times these, so through the windows they are fine and soft as the oak
// outside is, not bold dark bars across the sun's patches (task 107's leftovers).
let SHELL_LIMBS = float2 { 0.5, 3.0 };

// How the sun sees the shell's tree (trees::View): over the shell's three windows' niches
// at the wall's inner face, as the key carries them out to the tree; `r` the room as lit,
// its tree the shell's (shell_tree). render3d::tree_view_of with the shell on.
fn shell_tree_view(r: Room, s: room_shell::Shell) -> trees::View {
    let metre = surfaces::METRE;
    let inner = (s.walls[room_shell::WINDOW_WALL].a.y - s.table.y) * metre;
    var u0: f32 = 1e9;
    var u1: f32 = -1e9;
    var y0: f32 = 1e9;
    var y1: f32 = -1e9;
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::WINDOW else { continue; }
        let u = (s.table.x - o.mid) * metre;
        u0 = min(u0, u - 0.5 * o.width * metre);
        u1 = max(u1, u + 0.5 * o.width * metre);
        y0 = min(y0, surfaces::FLOOR_Y + o.sill * metre);
        y1 = max(y1, surfaces::FLOOR_Y + room_shell::head_at(o, 0.0) * metre);
    }
    let shear = tree_shear(r);
    var v = tree_view_over(shell_tree(r), u0 - shear.x * inner, u1 - shear.x * inner, y0 - shear.y * inner,
                           y1 - shear.y * inner, trees::SHELL_W, trees::SHELL_H);
    v.wood = SHELL_LIMBS;
    // Each window's own rectangle, with the map's room for the blur and the sway.
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::WINDOW else { continue; }
        let u = (s.table.x - o.mid) * metre;
        let ux0 = u - 0.5 * o.width * metre - shear.x * inner;
        let ux1 = u + 0.5 * o.width * metre - shear.x * inner;
        let wy0 = surfaces::FLOOR_Y + o.sill * metre - shear.y * inner;
        let wy1 = surfaces::FLOOR_Y + room_shell::head_at(o, 0.0) * metre - shear.y * inner;
        if v.holes.len < 4 { v.holes.push(float4 { ux0 - 4.0, ux1 + 4.0, wy0 - 4.0, wy1 + 4.0 }); }
    }
    return v;
}

// A point of the library's plan (metres: x along the window wall, y toward it, z up from
// the floor) in the shell's tree's frame (trees.goose): the board's middle falls on the
// map's origin, the frame's z 0 the plane shell_tree's trunk stood in.
fn plan_to_tree(r: Room, s: room_shell::Shell, p: float3) -> float3 {
    let metre = surfaces::METRE;
    let shear = tree_shear(r);
    let board = -(r.window.x + shell_tree(r).foliage.w);
    let u = (s.table.x - p.x) * metre;
    let y = surfaces::FLOOR_Y + p.z * metre;
    return float3 { u + shear.x * board, y + shear.y * board, board + (p.y - s.table.y) * metre };
}

// The old maple outside the library (task 107's T1, library-home-01 and the Tartu
// photographs): about 22 m tall, its trunk a metre thick, standing WHOLE_OUT beyond the
// window wall's outer face at WHOLE_ALONG on the plan's x, its crown about 20 m across,
// reaching a little toward the sun, its near side kept off the house. The garden lies
// WHOLE_PLINTH under the library's floor.
let WHOLE_ALONG:  f32 = 4.1;
let WHOLE_OUT:    f32 = 6.0;
let WHOLE_PLINTH: f32 = 0.9;

// The maple's variants (task 107's prep 2): an upright oval crown on a trunk going on
// to near its top, its inner limbs showing through the leaves (the user's gold photograph);
// a full rounded dome (the orange one); the concept's old massive tree forking low into a
// few heavy limbs; and that old tree with its trunk going on, limbs all up it. Each with
// a low limb sweeping down and out across the windows' view.
let WHOLE_VARIANTS = ["oval", "dome", "old", "old-leader"];
let WHOLE_OVAL = 0;
let WHOLE_DOME = 1;
let WHOLE_OLD = 2;
let WHOLE_OLD_LEADER = 3;

// The low limb over the windows (task 107's prep 3): none (the default); a lighter one high up, 5.2 m
// over the ground, sagging a little and turning up; one between, at 4 m; and prep 2's
// heavy one sweeping down from 2.7 m.
let WHOLE_HANGS = ["none", "high", "middle", "low"];
let HANG_NONE = 0;
let HANG_HIGH = 1;
let HANG_MIDDLE = 2;
let HANG_LOW = 3;

fn whole_tree(r: Room, s: room_shell::Shell, variant: i64 = WHOLE_OLD_LEADER, hang: i64 = HANG_NONE) -> trees::Whole {
    let metre = surfaces::METRE;
    let outer = s.walls[room_shell::WINDOW_WALL].a.y + s.walls[room_shell::WINDOW_WALL].thick;
    let foot = plan_to_tree(r, s, float3 { WHOLE_ALONG, outer + WHOLE_OUT, -WHOLE_PLINTH });
    let house = plan_to_tree(r, s, float3 { WHOLE_ALONG, outer, 0.0 }).z;
    let toward_sun: f32 = if tree_shear(r).x < 0.0 { -1.0 } else { 1.0 };
    let near = (WHOLE_OUT - 0.4) * metre;
    var w = trees::Whole {
        seed:       r.tree.y,
        foot:       foot,
        height:     22.0 * metre,
        girth:      0.5 * metre,
        fork:       3.0 * metre,
        leader:     0.65,
        limbs:      float2 { 62.0, 28.0 },
        crown:      float4 { 10.0 * metre, 9.5 * metre, 9.0 * metre, near },
        middle:     float3 { toward_sun * 1.0 * metre, 12.5 * metre, 0.5 * metre },
        house:      house,
        leaf:       0.11 * metre,
        leafy:      0.55,
        autumn:     1.2,
        shell:      2.6 * metre,
        hang_at:    2.7 * metre,
        hang_dir:   float3 { toward_sun * 0.62, 0.22, -0.75 },
        hang:       6.4 * metre,
        hang_thick: 0.42,
        hang_sag:   0.16,
        habit:      trees::MAPLE_HABIT,
    };
    if variant == WHOLE_OVAL {
        w.height = 20.0 * metre;
        w.girth = 0.38 * metre;
        w.fork = 2.4 * metre;
        w.leader = 0.8;
        w.limbs = float2 { 55.0, 30.0 };
        w.crown = float4 { 7.0 * metre, 9.2 * metre, 7.0 * metre, near };
        w.middle = float3 { toward_sun * 0.5 * metre, 10.8 * metre, 0.3 * metre };
        w.habit.children[0] = 16;
        w.leafy = 0.5;
        w.autumn = 1.0;
        w.shell = 2.0 * metre;
        w.hang_at = 2.4 * metre;
        w.hang = 5.6 * metre;
    }
    if variant == WHOLE_DOME {
        w.height = 19.0 * metre;
        w.girth = 0.42 * metre;
        w.fork = 2.4 * metre;
        w.leader = 0.6;
        w.limbs = float2 { 68.0, 35.0 };
        w.crown = float4 { 9.0 * metre, 8.6 * metre, 8.5 * metre, near };
        w.middle = float3 { toward_sun * 0.5 * metre, 10.4 * metre, 0.5 * metre };
        w.habit.children[0] = 14;
        w.leafy = 0.6;
        w.autumn = 1.4;
        w.hang_at = 2.5 * metre;
    }
    if variant == WHOLE_OLD {
        w.fork = 3.4 * metre;
        w.leader = 0.2;
        w.limbs = float2 { 55.0, 22.0 };
        w.habit.children[0] = 7;
        w.habit.children[1] = 16;
        w.middle = float3 { toward_sun * 1.5 * metre, 12.5 * metre, 0.5 * metre };
    }
    if hang == HANG_NONE { w.hang = 0.0; }
    if hang == HANG_HIGH {
        w.hang_at = 5.2 * metre;
        w.hang_dir = float3 { toward_sun * 0.6, 0.38, -0.7 };
        w.hang = 4.2 * metre;
        w.hang_thick = 0.26;
        w.hang_sag = 0.09;
    }
    if hang == HANG_MIDDLE {
        w.hang_at = 4.0 * metre;
        w.hang_dir = float3 { toward_sun * 0.6, 0.3, -0.72 };
        w.hang = 5.0 * metre;
        w.hang_thick = 0.32;
        w.hang_sag = 0.12;
    }
    return w;
}

// Where the old maple is seen from: eyes over the library's floor, seated and standing,
// and the windows' outer openings.
fn whole_sight(r: Room, s: room_shell::Shell) -> trees::Sight {
    var sight = trees::Sight { .. };
    let wall = s.walls[room_shell::WINDOW_WALL];
    let outer = wall.a.y + wall.thick;
    sight.plane = plan_to_tree(r, s, float3 { 0.0, outer, 0.0 }).z;
    let xs: f32[5] = [0.6, 2.5, 4.5, 6.5, 8.4];
    let ys: f32[4] = [0.6, 2.5, 4.5, 6.4];
    let hs: f32[2] = [1.1, 1.75];
    for x in xs { for y in ys { for z in hs { sight.eyes.push(plan_to_tree(r, s, float3 { x, y, z })); } } }
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::WINDOW && o.wall == room_shell::WINDOW_WALL else { continue; }
        let half = 0.5 * o.glass.w;
        let a = plan_to_tree(r, s, float3 { o.mid - half, outer, o.sill });
        let b = plan_to_tree(r, s, float3 { o.mid + half, outer, room_shell::head_at(o, 0.0) });
        sight.windows.push(float4 { min(a.x, b.x), max(a.x, b.x), min(a.y, b.y), max(a.y, b.y) });
    }
    return sight;
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
// board, the light and the wall together), and the map over the opening as the key
// carries it out to the tree, with room for the blur and the sway. The game's map is cut
// to what reaches the table, SIDE² texels; with `whole` (the room shown) it covers the
// whole opening, trees::ROOM_W × ROOM_H.
fn tree_view(r: Room, whole: bool = false) -> trees::View {
    let shear = tree_shear(r);
    let size = float2 { r.opening.x * r.panes.x, r.opening.y * r.panes.y };
    let y0 = r.window.z - shear.y * r.window.x;
    var x0 = r.window.w - size.x * 0.5;
    var x1 = r.window.w + size.x * 0.5;
    var ya = y0;
    var y1 = y0 + size.y;
    if whole { return tree_view_over(r, x0, x1, ya, y1, trees::ROOM_W, trees::ROOM_H); }
    // The opening cut to what reaches the table.
    let reach_x = TABLE_REACH * sqrt(1.0 + shear.x * shear.x);
    let reach_y = 2.0 + abs(shear.y) * TABLE_REACH;
    x0 = max(x0, -reach_x);
    x1 = min(x1, reach_x);
    y1 = min(y1, reach_y);
    ya = max(y0, -reach_y);
    if x1 <= x0 || y1 <= ya {
        x0 = r.window.w - size.x * 0.5;
        x1 = r.window.w + size.x * 0.5;
        ya = y0;
        y1 = y0 + size.y;
    }
    let middle = float2 { (x0 + x1) * 0.5, (ya + y1) * 0.5 };
    let span = max(x1 - x0, y1 - ya) + 8.0;
    return made_view(r, shear, middle, float2 { span, span }, trees::SIDE, trees::SIDE);
}

// The key's slant past the window wall's normal: a point at depth z falls on the tree's
// map z × shear from its own place.
fn tree_shear(r: Room) -> float2 {
    let l = toward(r.key.x, r.key.y);
    let h = normalize(float2 { l.x, l.z });
    let a = radians(r.window.y);
    let nw = float2 { cos(a) * h.x - sin(a) * h.y, sin(a) * h.x + cos(a) * h.y };
    let along = float2 { -nw.y, nw.x };
    let lw = float2 { l.x, l.z };
    let facing = max(dot(lw, nw), 0.05);
    return float2 { dot(lw, along) / facing, l.y / facing };
}

fn tree_facing(r: Room) -> f32 {
    let l = toward(r.key.x, r.key.y);
    let h = normalize(float2 { l.x, l.z });
    let a = radians(r.window.y);
    let nw = float2 { cos(a) * h.x - sin(a) * h.y, sin(a) * h.x + cos(a) * h.y };
    return max(dot(float2 { l.x, l.z }, nw), 0.05);
}

// The map over x0..x1, y0..y1 of the tree's frame and 8 units round it, w × h square
// texels, the rectangle grown on its shorter way to fit them.
fn tree_view_over(r: Room, x0: f32, x1: f32, y0: f32, y1: f32, w: i64, h: i64) -> trees::View {
    let texel = max((x1 - x0 + 8.0) / w, (y1 - y0 + 8.0) / h);
    let middle = float2 { (x0 + x1) * 0.5, (y0 + y1) * 0.5 };
    return made_view(r, tree_shear(r), middle, float2 { texel * w, texel * h }, w, h);
}

fn made_view(r: Room, shear: float2, middle: float2, size: float2, w: i64, h: i64) -> trees::View {
    let facing = tree_facing(r);
    let sun: f32 = 0.0093;
    return trees::View { shear, middle, size, w, h, (r.window.x + r.foliage.w) / facing, facing, sun * r.tree_blur,
                         -r.foliage.w, .. };
}

// The wind in the trees at a moment (Room.wind), for shaders::LIGHT_FN: now x the whole
// tree's slow sway, -1..1; y the gust where the map's along is 0, 0..1; z the gust's
// change a unit along the wall, as its front crosses the crown. Each layer's shift (the
// limbs, the near, middle and far leaves) in the tree's map, a map of `size` (world units): xy in
// calm air, zw what a full gust adds. With the branches (WIND_BRANCHES), their field:
// x its clock, y its sway in calm air and z what a full gust adds, in the map, w its
// noise's cells a unit. The gust's regions (gust_regions): x where its noise is along
// the wind, in cells, y how far the branches' clock has run ahead in this gust, z and w
// the noise's value where the gust starts to reach and how much more it takes to reach
// fully (w 0: the whole crown).
struct Wind {
    now:      float4,
    shift:    float4[4],
    branches: float4 = float4_0,
    regions:  float4 = float4_0,
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

// The gusts (Room.gust) at the seconds `front`: one in each stretch of gust.z seconds, at
// a random moment in it and of a random size, rising quickly and falling slower over
// gust.y seconds, 0 between; at least GUST_GAP from the stretch's ends, so a gust is over
// all along the wall before the next stretch begins. The stretch `front` is in, and the
// gust's start in it and its size.
let GUST_GAP: f64 = 1.0;

fn gust_length(g: float4) -> f64 { max(g.y as f64, 0.1) }
fn gust_every(g: float4) -> f64 { max(g.z as f64, gust_length(g) + 2.0 * GUST_GAP + 0.5) }

fn gust_stretch(g: float4, front: f64) -> f64, f64, f64 {
    let every = gust_every(g);
    let k = floor(front / every);
    let start = k * every + GUST_GAP + wind_hash(k * 1.37 + 5.1) * (every - gust_length(g) - 2.0 * GUST_GAP);
    return k, start, 0.6 + 0.4 * wind_hash(k * 2.71 + 19.3);
}

fn gust_at(g: float4, front: f64) -> f64 {
    let k, start, size = gust_stretch(g, front);
    let u = (front - start) / gust_length(g);
    guard u > 0.0 && u < 1.0 else { return 0.0; }
    return size * eased(0.0, 0.3, u) * (1.0 - eased(0.3, 1.0, u));
}

// How far the branches' clock has run ahead in the gust at `front`, in the wind's seconds:
// a full gust of strength 1 runs it 2.5 times as fast, as the branches sway quicker then.
// It goes back to 0 between gusts, where the gust is 0 all along the wall, and the shader
// takes it only times the gust where it reaches, so nothing jumps.
fn gust_clock(g: float4, front: f64) -> f64 {
    let k, start, size = gust_stretch(g, front);
    let end = min(front, start + gust_length(g));
    guard end > start else { return 0.0; }
    let steps = 16;
    let dt = (end - start) / steps;
    var sum = 0.0;
    var a = gust_at(g, start);
    for i in steps {
        let b = gust_at(g, start + (i + 1) * dt);
        sum += 0.5 * (a + b) * dt;
        a = b;
    }
    return 1.5 * (g.x as f64) * sum;
}

// A branch's reach across, in world units: the cells of the branches' field and of the
// gust's regions.
let BRANCH_CELL: f32 = 6.0;

// Where the gust at the wind's seconds `t` reaches (Wind.regions; shaders::LIGHT_FN's
// wind_at): a slow noise over the tree's plane, BRANCH_CELL cells, drifting along the wind
// and a new part of it each gust. Its edge is soft enough that, with the strongest
// layer's push `push` (world units) over it, the shift changes by about a tenth of a unit
// a unit at most, so no leaf's shape smears (branch_field's rule).
fn gust_regions(g: float4, t: f64, push: f32) -> float4 {
    guard g.w < 1.0 else { return float4 { 0.0, gust_clock(g, t) as f32, 0.0, 0.0 }; }
    let k, start, size = gust_stretch(g, t);
    let along = (k * 7.31) % 977.0 + 0.3 * (t - k * gust_every(g));
    let soft = clamp(2.5 * push, 0.5, 1.2);
    let middle = 0.5 + 0.5 * (0.5 - clamp(g.w, 0.0, 1.0));
    return float4 { along as f32, gust_clock(g, t) as f32, middle - 0.5 * soft, soft };
}

// The wind at `seconds` for a tree's map of `size`. Two noises a layer, one along
// the wind and one across it (Zioma): the limbs follow the whole tree's slow sway alone,
// barely and as one piece; each leaf layer adds its own turbulence, quicker the farther
// out, as thin twigs move faster and more than thick limbs (Habel and others, 2009), and
// stronger in a gust, which pushes all along the wind. Each layer only shifts, whole.
fn wind_at(r: Room, seconds: f32, size: float2) -> Wind {
    let t = (seconds * r.wind.y) as f64;
    // Where the gust's front is a unit along the wall later: 0.015 s.
    let lag: f64 = 0.015;
    let gust = gust_at(r.gust, t);
    let change = (gust_at(r.gust, t - 10.0 * lag) - gust_at(r.gust, t + 10.0 * lag)) / 20.0;
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
    var out = Wind { float4 { sway, gust as f32, change as f32, 0.0 }, [float4_0; 4], .. };
    let dir = float2 { 1.0, 0.15 };
    let cross_dir = float2 { -0.15, 1.0 };
    let unit_x = if size.x > 0.0 { 1.0 / size.x } else { 0.0 };
    let unit_y = if size.y > 0.0 { 1.0 / size.y } else { 0.0 };
    let strength = r.gust.x;
    for i in 4 {
        // In calm air, and what a full gust of strength 1 adds (the turbulence up by 0.8, a
        // push of 2).
        var calm = dir * sway + cross_dir * sway_across;
        var pushed = dir * 1.5;
        if i > 0 {
            let along = wind_noise(t * along_rate[i] + along_seed[i]) as f32;
            let across = wind_noise(t * across_rate[i] + across_seed[i]) as f32;
            calm = calm + dir * (0.6 * along) + cross_dir * (0.3 * across);
            pushed = dir * (2.0 + 0.8 * along) + cross_dir * (0.4 * across);
        }
        let kx = reach[i] * unit_x;
        let ky = reach[i] * unit_y;
        out.shift[i] = float4 { calm.x * kx, calm.y * ky, pushed.x * (kx * strength), pushed.y * (ky * strength) };
    }
    // The farthest leaves' push at most: along 2.8, across 0.4.
    out.regions = gust_regions(r.gust, t, 2.83 * reach[3] * strength);
    return out;
}

// The wind's kinds, to compare in the tuner (tools/light_tune's K): the sines it was
// before the noises (wind_sines), the noises (wind_at), none, and the noises with the
// branches swaying apart (branch_field).
let WIND_SINES = 0;
let WIND_NOISE = 1;
let WIND_STILL = 2;
let WIND_BRANCHES = 3;
let WIND_KINDS = ["sines", "noise", "still", "branches"];

// The wind of a kind (WIND_KINDS) at `seconds` for a tree's map of `size`.
fn wind_of(r: Room, kind: i64, seconds: f32, size: float2) -> Wind {
    if kind == WIND_SINES { return wind_sines(r, seconds, size); }
    if kind == WIND_STILL { return Wind { float4_0, [float4_0; 4], .. }; }
    var out = wind_at(r, seconds, size);
    if kind == WIND_BRANCHES {
        out.now.w = 2.0;
        out.branches = branch_field(r, seconds * r.wind.y);
    }
    return out;
}

// The branches' field (shaders::LIGHT_FN's branch_sway): each leaf layer's lookup moved
// by a slow noise over the tree's plane, its cells a branch's reach across (BRANCH_CELL),
// at most two thirds of a leaf's width (0.25), so neighbouring regions sway apart and the
// field's gradient stays under 0.13: no shape smears. Its clock is the wind's time `t`;
// where a gust reaches, it runs ahead (gust_clock) and the sway grows by the gust's
// strength. Its sway in world units (the shader divides it by the map's size).
fn branch_field(r: Room, t: f64) -> float4 {
    let most: f32 = 0.25;
    let reach = r.wind.x * r.wind.z;
    let calm = min(0.25 * reach, most);
    let gusty = min(0.9 * reach, most);
    return float4 { t as f32, calm, (gusty - calm) * r.gust.x, 1.0 / BRANCH_CELL };
}

// The wind as sines (after Crysis's vegetation and SpeedTree's wind): the whole tree's
// slow sway, two sines; each leaf layer a little more and on its own phase across the
// wind. The gust, peaks of two sines' product, its front crossing the crown, is made by
// shaders::LIGHT_FN's wind_at (now.w 1).
fn wind_sines(r: Room, seconds: f32, size: float2) -> Wind {
    let t = seconds * r.wind.y;
    let slow = 0.7 * sin(t * 0.55) + 0.3 * sin(t * 1.37 + 1.1);
    let w = r.wind.x;
    let reach: f32[4] = [w * 0.1, w * r.wind.z, w * r.wind.z * 1.15, w * r.wind.z * 1.3];
    // The limbs, the near, middle and far leaves: their share of the sway, their push in
    // a gust, and their sway across.
    let share:  f32[4] = [1.0, 1.0, 0.8, 0.6];
    let push:   f32[4] = [1.5, 2.0, 2.0, 2.0];
    let across: f32[4] = [0.0, 0.4 * sin(t * 1.9 + 0.7), 0.4 * sin(t * 1.6 + 2.3), 0.4 * sin(t * 1.3 + 4.1)];
    var out = Wind { float4 { slow, 0.0, 0.0, 1.0 }, [float4_0; 4], .. };
    let unit_x = if size.x > 0.0 { 1.0 / size.x } else { 0.0 };
    let unit_y = if size.y > 0.0 { 1.0 / size.y } else { 0.0 };
    for i in 4 {
        let kx = reach[i] * unit_x;
        let ky = reach[i] * unit_y;
        out.shift[i] = float4 { share[i] * slow * kx, (0.15 * share[i] * slow + across[i]) * ky,
                                push[i] * kx, 0.15 * push[i] * ky };
    }
    return out;
}
