// The board's looks as data: one flat struct of colors, roughness and material
// parameters per theme, read by one bake and one set of shaders. Colors are sRGB (the
// shaders take them linear); a surface's color is about how it reads lit from above,
// tuned against the user's even-lit swatches (agents/design.md).
namespace looks;
import std;
import vec;

let AUTUMN = 0;
let WINTER = 1;
let SPRING = 2;
let SUMMER = 3;
let COUNT = 4;
// Summer's variants (the user, 2026-11-09: summer clearly apart from autumn, the coast at
// sunset), looks after the seasons': 0 summer() itself, 1 SUMMER_OAK wood 3's crisp grain
// in summer's palette, 2 SUMMER_PICKLED limewashed oak, 3 SUMMER_TEAK a teak deck frame
// round sand and terracotta, 4 SUMMER_AMBER and 5 SUMMER_SERPENTINE a granite frame
// carved with sun signs and trees of life filled with amber (task 041). T cycles the
// seasons; --summer N and S pick the variant.
let SUMMERS = 7;
let SUMMER_OAK = 4;
let SUMMER_PICKLED = 5;
let SUMMER_TEAK = 6;
let SUMMER_AMBER = 7;
let SUMMER_SERPENTINE = 8;
// Spring's carved looks (task 041), shown for spring by Gpu.spring (shown()): 1 the elven
// stone, 2 the Baltic folk oak.
let SPRING_ELVEN = 9;
let SPRING_BALTIC = 10;
// Autumn's and winter's other material (task 080, 2026-11-13): autumn's stone and winter's
// wood beside the season's own, each its takes. Autumn's: 0 autumn() the wood, 1
// AUTUMN_STONE travertine and red jasper in a dark brown marble, 2 AUTUMN_CARVED the same
// field in a weathered stone frame carved with vines in rust leaves, 3 AUTUMN_PORPHYRY
// golden sandstone and porphyry in a speckled dark stone. Winter's: 0 winter() the slate,
// 1 WINTER_WOOD limed ash and smoked oak, 2 WINTER_CARVED the same in a smoked oak frame
// carved with a Nordic band, 3 WINTER_STAINED birch and blue-grey stained birch. --autumn
// N and --winter N pick them.
let AUTUMNS = 4;
let WINTERS = 4;
let AUTUMN_STONE = 11;
let AUTUMN_CARVED = 12;
let AUTUMN_PORPHYRY = 13;
let WINTER_WOOD = 14;
let WINTER_CARVED = 15;
let WINTER_STAINED = 16;
// The carved stones' plain siblings (task 080, the user 2026-11-13: each season a wood,
// a stone, and a carved board): spring's elven stone and summer's amber granite with no
// carving, their frames one solid block. --spring 3 and --summer 6.
let SPRING_STONE = 17;
let SUMMER_STONE = 18;

struct Theme {
    photo: i64,             // the season's photograph, src/app/background.c's kind
    // The bake: each surface's color and roughness, then its figure: how far the grain
    // wanders, the broad figure's contrast, the fine streaks' contrast, and how far it
    // is drawn out along the grain (1 wood; 0 stone, which mottles instead).
    light_sq:  float4,
    light_fig: float4,
    dark_sq:   float4,
    dark_fig:  float4,
    inlay:     float4,
    inlay_fig: float4,
    frame:     float4,
    frame_fig: float4,
    surface:   float4,      // x: each square's own tone, y: pores, z: seams, w: relief
    // The frame's wood: x its pores, y its relief, z the late wood's furrows along
    // the grain, w how much smoother (polished) its rounded edge is than its top.
    frame_surface: float4,
    // Stone (a figure drawn out 0): x its veins' contrast, y its clouding's, z how far the
    // roughness follows the figure.
    stone: float4,
    // The wood's growth rings (shaders::BAKE_FRAG's rings, board3d's --wood), per
    // surface, the inlay taking the dark squares': x a ring's width in world units (a
    // square is 1), y how flat-sawn the pieces are (0 quarter-sawn, straight lines; 1
    // flat-sawn, arches), z the late wood's darkening, w the pores' density.
    light_ring: float4,
    dark_ring:  float4,
    frame_ring: float4,
    // The shaders: the pieces' colors and roughness, the light piece's mottling (x),
    // the dark piece's figure (y) and how far it is drawn out (z), how dark its turned
    // side is against its face (w), the crown's color.
    light_piece: float4,
    dark_piece:  float4,
    piece_fig:   float4,
    crown:       float4,
    edge:        float4,    // the frame's rounded edge, w: how much of it
    line:        float4,    // a thin line along the frame's outer edge, w: how much
    key:         float4,    // toward the key light, w: its intensity
    key_color:   float4,
    bounce:      float4,    // the lit board's mean color on the pieces' sides, w: strength
    ambient:     float4,    // x: exposure, y: the ambient's scale, z: how far it goes to grey
    glow:        float4,    // the selection's ring, w: strength
    grade:       float4,    // the backdrop: x gain, y saturation, z bokeh, w the lift low down
    tint:        float4,    // the backdrop's lift color, w: its vignette
    // How the frame is made: x 1 one solid block with the field carved out, the figure
    // running one way over the whole board; 0 four pieces mitred at 45°, the grain along
    // each side. y: the mitre joint's strength; z: 1 for stone (shaders::LIT_FRAG); w: 1
    // the frame carved (Carving, task 041), its map's across along the profile.
    build: float4,
    // The frame's caulked seams, as a teak deck's (shaders::BAKE_FRAG's frame_map): x a
    // plank's width across the frame's top (world units; 0 none), y a seam's half width,
    // z how dark it is.
    seam: float4,
    // A carved frame's fill (sRGB; shaders::BAKE_FRAG's carving): the vines' leaves'
    // tint, the folk band's freshly cut wood, or the amber in the signs; w: how much.
    fill: float4,
}

fn get(which: i64) -> Theme {
    if which == WINTER { return winter(); }
    if which == SPRING { return spring(); }
    if which == SUMMER { return summer(); }
    if which == SUMMER_OAK { return summer_oak(); }
    if which == SUMMER_PICKLED { return summer_pickled(); }
    if which == SUMMER_TEAK { return summer_teak(); }
    if which == SUMMER_AMBER { return summer_amber(); }
    if which == SUMMER_SERPENTINE { return summer_serpentine(); }
    if which == SPRING_ELVEN { return elven(); }
    if which == SPRING_BALTIC { return baltic(); }
    if which == AUTUMN_STONE { return autumn_stone(); }
    if which == AUTUMN_CARVED { return autumn_carved(); }
    if which == AUTUMN_PORPHYRY { return autumn_porphyry(); }
    if which == WINTER_WOOD { return winter_wood(); }
    if which == WINTER_CARVED { return winter_carved(); }
    if which == WINTER_STAINED { return winter_stained(); }
    if which == SPRING_STONE {
        // The elven stone's ivory with finer, clearer veins than the carved one's.
        var t = plain(elven());
        t.stone = float4 { 0.2, t.stone.y, t.stone.z, t.stone.w };
        return t;
    }
    if which == SUMMER_STONE { return plain(summer_amber()); }
    return autumn();
}

// The look shown for `which` with spring's look `spring` (SPRING_LOOK..): spring's
// carved ones their own.
fn shown(which: i64, spring: i64) -> i64 {
    guard which == SPRING else { return which; }
    if spring == 1 { return SPRING_ELVEN; }
    if spring == 2 { return SPRING_BALTIC; }
    if spring == 3 { return SPRING_STONE; }
    return SPRING;
}

// The raised board's material, one for every season (settings' Board row, the player's
// `material`; task 080): the season's own (AUTO), or its wood, stone, or carved board.
// settings::MATERIAL_AUTO.. number them the same.
let MATERIAL_AUTO = 0;
let MATERIAL_WOOD = 1;
let MATERIAL_STONE = 2;
let MATERIAL_CARVED = 3;
let MATERIALS = 4;
// Each season's wood, stone, and carved look, by season (AUTUMN..SUMMER), the flags that
// pick them in 03's table: autumn's maple and walnut (--autumn 0), sandstone and porphyry
// (3), and rust vines in weathered stone (2); winter's limed ash (--winter 1), the slate
// (0), and the Nordic band (2); spring's birch (--spring 0), ivory and jade (3), and the
// elven stone (1); summer's sunset wood (--summer 0), the amber granite (6), and its signs
// carved (4).
let BY_MATERIAL = [[AUTUMN, AUTUMN_PORPHYRY, AUTUMN_CARVED], [WINTER_WOOD, WINTER, WINTER_CARVED],
                   [SPRING, SPRING_STONE, SPRING_ELVEN], [SUMMER, SUMMER_STONE, SUMMER_AMBER]];
// What Auto is in each season, its look before the choice: autumn's wood, winter's stone,
// spring's carved stone, summer's wood.
let OWN_MATERIAL = [MATERIAL_WOOD, MATERIAL_STONE, MATERIAL_CARVED, MATERIAL_WOOD];

// The look the raised board shows in `season` (AUTUMN..SUMMER) made of `material`
// (MATERIAL_AUTO..): one the renderer bakes as it is, spring's birch included (draw3d
// shows it with Gpu.spring 0).
fn of(season: i64, material: i64) -> i64 {
    let s = clamp(season, 0, COUNT - 1);
    let m = if material <= MATERIAL_AUTO || material >= MATERIALS { OWN_MATERIAL[s] } else { material };
    return BY_MATERIAL[s][m - 1];
}

// The look for summer's variant n (0 to SUMMERS - 1).
fn summer_look(n: i64) -> i64 {
    if n <= 0 { return SUMMER; }
    if n >= 6 { return SUMMER_STONE; }
    return COUNT + min(n, SUMMERS - 1) - 1;
}

// The look for autumn's variant n (0 to AUTUMNS - 1) and winter's (0 to WINTERS - 1).
fn autumn_look(n: i64) -> i64 { if n <= 0 { AUTUMN } else { AUTUMN_STONE + min(n, AUTUMNS - 1) - 1 } }
fn winter_look(n: i64) -> i64 { if n <= 0 { WINTER } else { WINTER_WOOD + min(n, WINTERS - 1) - 1 } }

// The wood's model a look is made with by default, -1 for any (the one chosen). The app's
// and the prototype's --wood overrides it. The user's values (2026-11-09): summer and its
// amber stone wood 2, spring's two carved looks wood 3.
fn wood_for(look: i64) -> i64 {
    if look == WINTER_WOOD || look == WINTER_CARVED || look == WINTER_STAINED { return 2; }
    if look == SUMMER_OAK || look == SPRING_ELVEN || look == SPRING_STONE || look == SPRING_BALTIC { return 3; }
    if look == SUMMER || look == SUMMER_AMBER || look == SUMMER_STONE || look == SUMMER_PICKLED || look == SUMMER_TEAK { return 2; }
    return -1;
}

// The finish of the wood's model `wood` on look `look`: a summer variant's own on its
// model, else the model's (finish()).
fn finish_for(look: i64, wood: i64) -> Finish {
    guard wood == wood_for(look) else { return finish(wood); }
    if look == SUMMER_PICKLED { return PICKLED; }
    if look == WINTER_WOOD || look == WINTER_CARVED { return LIMED; }
    if look == WINTER_STAINED { return COOL; }
    if look == SUMMER_TEAK { return OILED; }
    if look == SUMMER || look == SUMMER_AMBER || look == SUMMER_STONE { return TUNED; }
    if look == SPRING_ELVEN || look == SPRING_STONE || look == SPRING_BALTIC { return SPRING_FINISH; }
    return VARNISHED;
}

// Maple and walnut veneer in a fairly rough open-grained cherry frame whose polished
// rounded edge takes the sheen, cream and walnut pieces; the 3D reference (`ChatGPT
// Image Nov 7, 2026, 08_19_31 PM.png`) and its swatch. The key light comes from the
// upper left and behind, as the reference's shadows fall.
fn autumn() -> Theme {
    return Theme {
        photo:         0,
        light_sq:      float4 { 0.96, 0.79, 0.58, 0.5 },
        light_fig:     float4 { 0.3, 0.5, 0.45, 1.0 },
        dark_sq:       float4 { 0.41, 0.25, 0.18, 0.46 },
        dark_fig:      float4 { 0.7, 0.7, 0.6, 1.0 },
        inlay:         float4 { 0.26, 0.14, 0.08, 0.5 },
        inlay_fig:     float4 { 0.3, 0.3, 0.25, 1.0 },
        frame:         float4 { 0.6, 0.33, 0.18, 0.7 },
        frame_fig:     float4 { 0.2, 0.25, 0.45, 1.0 },
        surface:       float4 { 0.1, 1.0, 0.5, 1.0 },
        frame_surface: float4 { 1.0, 3.5, 1.2, 0.3 },
        stone:         float4 { 0.0, 0.0, 0.0, 0.0 },
        light_ring:    float4 { 0.05, 0.2, 0.5, 0.3 },
        dark_ring:     float4 { 0.06, 0.5, 0.4, 0.35 },
        frame_ring:    float4 { 0.05, 0.3, 0.6, 0.6 },
        light_piece:   float4 { 0.97, 0.89, 0.76, 0.55 },
        dark_piece:    float4 { 0.34, 0.235, 0.2, 0.36 },
        piece_fig:     float4 { 0.04, 0.18, 0.3, 0.35 },
        crown:         float4 { 0.29, 0.16, 0.094, 0.0 },
        edge:          float4 { 0.0, 0.0, 0.0, 0.0 },
        line:          float4 { 0.0, 0.0, 0.0, 0.0 },
        key:           float4 { -0.5, 0.85, -0.4, 3.4 },
        key_color:     float4 { 1.0, 0.92, 0.8, 0.0 },
        bounce:        float4 { 0.8, 0.7, 0.6, 0.8 },
        ambient:       float4 { 1.45, 1.25, 0.5, 0.0 },
        glow:          float4 { 1.0, 0.843, 0.353, 0.55 },
        grade:         float4 { 2.6, 1.0, 1.5, 0.85 },
        tint:          float4 { 0.72, 0.5, 0.34, 0.45 },
        build:         float4 { 0.0, 1.0, 0.0, 0.0 },
        seam:          float4_0,
        fill:          float4_0,
    };
}

// Honed, softly polished stone: pale grey-blue and dark slate squares with a calm
// clouding and a few faint veins, a darker slate frame with a steel-blue rounded edge
// (the reference's pale line left out: the user, 2026-11-09), ivory and dark slate
// pieces, darker than the reference's as the 2D board's are; `Winter Slate Checkers
// Board.png` and `Cool Stone and Cream Texture Grid.png`.
fn winter() -> Theme {
    return Theme {
        photo:         1,
        light_sq:      float4 { 0.74, 0.75, 0.765, 0.34 },
        light_fig:     float4 { 0.6, 0.14, 0.08, 0.0 },
        dark_sq:       float4 { 0.17, 0.215, 0.275, 0.32 },
        dark_fig:      float4 { 0.6, 0.18, 0.1, 0.0 },
        inlay:         float4 { 0.16, 0.2, 0.26, 0.42 },
        inlay_fig:     float4 { 0.6, 0.12, 0.1, 0.0 },
        frame:         float4 { 0.22, 0.27, 0.33, 0.45 },
        frame_fig:     float4 { 0.6, 0.15, 0.35, 0.0 },
        surface:       float4 { 0.04, 0.3, 0.45, 0.5 },
        frame_surface: float4 { 0.0, 0.5, 0.0, 0.1 },
        stone:         float4 { 0.05, 0.08, 0.12, 0.0 },
        light_ring:    float4_0,
        dark_ring:     float4_0,
        frame_ring:    float4_0,
        light_piece:   float4 { 0.86, 0.82, 0.76, 0.52 },
        dark_piece:    float4 { 0.205, 0.225, 0.255, 0.3 },
        piece_fig:     float4 { 0.03, 0.05, 0.0, 0.4 },
        crown:         float4 { 0.2, 0.22, 0.27, 0.0 },
        edge:          float4 { 0.36, 0.42, 0.48, 0.6 },
        line:          float4 { 0.82, 0.88, 0.95, 0.0 },
        key:           float4 { -0.45, 0.8, -0.55, 3.2 },
        key_color:     float4 { 0.96, 0.97, 1.0, 0.0 },
        bounce:        float4 { 0.75, 0.72, 0.68, 2.0 },
        ambient:       float4 { 1.35, 1.35, 0.6, 0.0 },
        glow:          float4 { 0.655, 0.816, 0.984, 0.55 },
        grade:         float4 { 2.2, 1.0, 1.0, 0.85 },
        tint:          float4 { 0.72, 0.76, 0.86, 0.35 },
        build:         float4 { 1.0, 0.0, 1.0, 0.0 },
        seam:          float4_0,
        fill:          float4_0,
    };
}

// Birch, pale and fine, its dark squares the same birch stained sage, in a deep green
// stained frame, cream and dark green pieces: the theme table's spring (rendering.md,
// "Seasons and themes") and prototypes/boards.html's 3D board. Birch is diffuse-porous:
// its rings barely show, its pores are fine and few, its figure a soft silky shimmer,
// so the faint fibre the flat board has is most of what reads. The key light is cooler
// than autumn's, a spring morning's.
fn spring() -> Theme {
    return Theme {
        photo:         2,
        light_sq:      float4 { 0.9, 0.85, 0.74, 0.46 },
        light_fig:     float4 { 0.15, 0.35, 0.4, 1.0 },
        dark_sq:       float4 { 0.42, 0.5, 0.41, 0.44 },
        dark_fig:      float4 { 0.15, 0.3, 0.35, 1.0 },
        inlay:         float4 { 0.18, 0.22, 0.17, 0.5 },
        inlay_fig:     float4 { 0.2, 0.25, 0.2, 1.0 },
        frame:         float4 { 0.27, 0.33, 0.26, 0.6 },
        frame_fig:     float4 { 0.2, 0.25, 0.35, 1.0 },
        surface:       float4 { 0.06, 0.4, 0.45, 0.6 },
        frame_surface: float4 { 0.4, 1.5, 0.4, 0.3 },
        stone:         float4 { 0.0, 0.0, 0.0, 0.0 },
        light_ring:    float4 { 0.09, 0.35, 0.18, 0.08 },
        dark_ring:     float4 { 0.09, 0.35, 0.22, 0.08 },
        frame_ring:    float4 { 0.08, 0.35, 0.3, 0.15 },
        light_piece:   float4 { 0.96, 0.94, 0.88, 0.55 },
        dark_piece:    float4 { 0.23, 0.29, 0.25, 0.36 },
        piece_fig:     float4 { 0.03, 0.15, 0.3, 0.4 },
        crown:         float4 { 0.23, 0.29, 0.25, 0.0 },
        edge:          float4 { 0.0, 0.0, 0.0, 0.0 },
        line:          float4 { 0.0, 0.0, 0.0, 0.0 },
        key:           float4 { -0.5, 0.85, -0.45, 3.3 },
        key_color:     float4 { 1.0, 0.97, 0.92, 0.0 },
        bounce:        float4 { 0.8, 0.8, 0.72, 0.8 },
        ambient:       float4 { 1.4, 1.3, 0.55, 0.0 },
        glow:          float4 { 0.56, 0.83, 1.0, 0.55 },
        grade:         float4 { 2.3, 1.0, 1.2, 0.85 },
        tint:          float4 { 0.7, 0.74, 0.62, 0.4 },
        build:         float4 { 0.0, 1.0, 0.0, 0.0 },
        seam:          float4_0,
        fill:          float4_0,
    };
}

// Summer's sunset: peach and dusky rose squares under a satin lacquer, almost flat as
// the flat board's plain sheen is, in a deep red-brown frame, cream and plum pieces: the
// theme table's summer and prototypes/boards.html's 3D board. Close-grained wood whose
// figure the colour mostly hides; a warm low evening key.
fn summer() -> Theme {
    return Theme {
        photo:         3,
        light_sq:      float4 { 0.96, 0.85, 0.74, 0.36 },
        light_fig:     float4 { 0.1, 0.12, 0.15, 1.0 },
        dark_sq:       float4 { 0.58, 0.36, 0.3, 0.34 },
        dark_fig:      float4 { 0.1, 0.15, 0.18, 1.0 },
        inlay:         float4 { 0.24, 0.13, 0.11, 0.45 },
        inlay_fig:     float4 { 0.15, 0.2, 0.15, 1.0 },
        frame:         float4 { 0.33, 0.18, 0.15, 0.5 },
        frame_fig:     float4 { 0.15, 0.2, 0.3, 1.0 },
        surface:       float4 { 0.05, 0.2, 0.4, 0.35 },
        frame_surface: float4 { 0.3, 1.0, 0.3, 0.3 },
        stone:         float4 { 0.0, 0.0, 0.0, 0.0 },
        light_ring:    float4 { 0.07, 0.3, 0.12, 0.05 },
        dark_ring:     float4 { 0.07, 0.3, 0.14, 0.05 },
        frame_ring:    float4 { 0.06, 0.3, 0.25, 0.1 },
        light_piece:   float4 { 0.98, 0.95, 0.9, 0.5 },
        dark_piece:    float4 { 0.29, 0.18, 0.21, 0.32 },
        piece_fig:     float4 { 0.03, 0.12, 0.3, 0.4 },
        crown:         float4 { 0.29, 0.18, 0.21, 0.0 },
        edge:          float4 { 0.0, 0.0, 0.0, 0.0 },
        line:          float4 { 0.0, 0.0, 0.0, 0.0 },
        key:           float4 { -0.6, 0.7, -0.4, 3.3 },
        key_color:     float4 { 1.0, 0.88, 0.76, 0.0 },
        bounce:        float4 { 0.85, 0.7, 0.62, 0.8 },
        ambient:       float4 { 1.4, 1.25, 0.5, 0.0 },
        glow:          float4 { 1.0, 0.69, 0.54, 0.55 },
        grade:         float4 { 2.4, 1.0, 1.4, 0.85 },
        tint:          float4 { 0.78, 0.56, 0.48, 0.42 },
        build:         float4 { 0.0, 1.0, 0.0, 0.0 },
        seam:          float4_0,
        fill:          float4_0,
    };
}

// Summer 1: wood 3's crisper grain, its thin lines and pores over the noise, in peach and
// dusky rose, in a deeper rose-brown frame with open pores and furrows, varnished.
fn summer_oak() -> Theme {
    var t = summer();
    t.light_sq = float4 { 0.97, 0.8, 0.66, 0.42 };
    t.light_fig = float4 { 0.3, 0.3, 0.4, 1.0 };
    t.dark_sq = float4 { 0.62, 0.38, 0.36, 0.4 };
    t.dark_fig = float4 { 0.35, 0.35, 0.45, 1.0 };
    t.inlay = float4 { 0.3, 0.15, 0.14, 0.45 };
    t.inlay_fig = float4 { 0.25, 0.25, 0.3, 1.0 };
    t.frame = float4 { 0.56, 0.34, 0.31, 0.55 };
    t.frame_fig = float4 { 0.2, 0.25, 0.45, 1.0 };
    t.surface = float4 { 0.06, 0.6, 0.45, 0.8 };
    t.frame_surface = float4 { 0.8, 3.0, 1.0, 0.3 };
    t.light_ring = float4 { 0.06, 0.3, 0.3, 0.3 };
    t.dark_ring = float4 { 0.06, 0.3, 0.3, 0.35 };
    t.frame_ring = float4 { 0.05, 0.3, 0.5, 0.5 };
    t.dark_piece = float4 { 0.27, 0.16, 0.19, 0.32 };
    t.crown = float4 { 0.27, 0.16, 0.19, 0.0 };
    return t;
}

// Summer 2: pickled (limewashed) oak, sun-bleached and coastal. Ring-porous oak whose open
// pores and grain are filled with white (Finish.pickle), so the grain reads paler than
// the wood round it: bleached oak light squares, the dark ones oak under a soft rose wash
// (the theme's dark tone), a weathered grey-beige driftwood frame pickled the same, all
// a satin matte. Off-white and dusky plum pieces.
fn summer_pickled() -> Theme {
    var t = summer();
    t.light_sq = float4 { 0.86, 0.81, 0.75, 0.52 };
    t.light_fig = float4 { 0.3, 0.35, 0.4, 1.0 };
    t.dark_sq = float4 { 0.6, 0.4, 0.36, 0.52 };
    t.dark_fig = float4 { 0.3, 0.35, 0.4, 1.0 };
    t.inlay = float4 { 0.4, 0.33, 0.3, 0.55 };
    t.inlay_fig = float4 { 0.3, 0.3, 0.3, 1.0 };
    t.frame = float4 { 0.6, 0.56, 0.5, 0.6 };
    t.frame_fig = float4 { 0.3, 0.35, 0.5, 1.0 };
    t.surface = float4 { 0.06, 1.0, 0.4, 0.9 };
    t.frame_surface = float4 { 1.0, 3.0, 1.0, 0.05 };
    t.light_ring = float4 { 0.07, 0.4, 0.6, 0.5 };
    t.dark_ring = float4 { 0.07, 0.4, 0.5, 0.4 };
    t.frame_ring = float4 { 0.07, 0.4, 0.7, 0.9 };
    t.light_piece = float4 { 0.97, 0.95, 0.91, 0.5 };
    t.dark_piece = float4 { 0.32, 0.2, 0.23, 0.34 };
    t.crown = float4 { 0.32, 0.2, 0.23, 0.0 };
    return t;
}

// Summer 3: teak and sand. An oiled teak frame, straight-grained and golden like a boat's
// deck, its planks parted by fine dark caulking seams along it, round pale sand and
// terracotta squares of a calm close grain; all satin.
fn summer_teak() -> Theme {
    var t = summer();
    t.light_sq = float4 { 0.93, 0.84, 0.69, 0.42 };
    t.light_fig = float4 { 0.15, 0.15, 0.2, 1.0 };
    t.dark_sq = float4 { 0.72, 0.42, 0.33, 0.42 };
    t.dark_fig = float4 { 0.15, 0.2, 0.25, 1.0 };
    t.inlay = float4 { 0.28, 0.17, 0.1, 0.45 };
    t.inlay_fig = float4 { 0.2, 0.25, 0.3, 1.0 };
    t.frame = float4 { 0.56, 0.35, 0.18, 0.45 };
    t.frame_fig = float4 { 0.15, 0.2, 0.4, 1.0 };
    t.surface = float4 { 0.05, 0.3, 0.4, 0.4 };
    t.frame_surface = float4 { 0.6, 2.0, 0.8, 0.3 };
    t.light_ring = float4 { 0.07, 0.2, 0.15, 0.08 };
    t.dark_ring = float4 { 0.07, 0.2, 0.18, 0.08 };
    t.frame_ring = float4 { 0.045, 0.1, 0.45, 0.45 };
    t.dark_piece = float4 { 0.27, 0.17, 0.16, 0.32 };
    t.crown = float4 { 0.27, 0.17, 0.16, 0.0 };
    t.seam = float4 { 0.17, 0.005, 0.9, 0.0 };
    return t;
}

// The wood's finish, per model of the wood (model3d::WOOD_MODEL..): what the prototype's
// tuning panel (P) sets, baked into the wood's surfaces only, never the stone. Neutral
// is varnish 0, sanding 0, grain 1, rings 1, warmth 0: the bake as the model has it.
struct Finish {
    varnish: f32,   // 0..1: the roughness lower (×0.55 at 1), the pores a little filled
    sanding: f32,   // 0..1: the grain's and the pores' relief shallower (×0.3 at 1)
    grain:   f32,   // the figure's contrast round the base color, 1 as baked
    rings:   f32,   // the rings' and the grain's spacing across, 1 as baked
    warmth:  f32,   // -1..1: the color toward grey-yellow (-) or red-orange (+)
    // 0..1: limewashed: white fills the pores and grooves and the grain turns paler than
    // the wood round it, the fill matte (summer's pickled oak)
    pickle: f32,
    caulk:  f32,    // the frame's caulked seams' strength (Theme.seam), 1 as made
}

let PLAIN = Finish { varnish: 0.0, sanding: 0.0, grain: 1.0, rings: 1.0, warmth: 0.0, pickle: 0.0, caulk: 1.0 };

// "The same wood, very slightly more varnish and sanded a tiny bit more" (the user,
// 2026-11-09), on the two woods kept for the game.
let VARNISHED = Finish { varnish: 0.2, sanding: 0.15, grain: 1.0, rings: 1.0, warmth: 0.0, pickle: 0.0,
                         caulk: 1.0 };

// Wood 2's finish as the user tuned it in the panel (2026-11-09), the default wood's.
let TUNED = Finish { varnish: 0.68, sanding: 0.835, grain: 1.01, rings: 1.002, warmth: 0.36, pickle: 0.0,
                     caulk: 1.0 };

// Summer's pickled oak: limewashed, lightly sanded, a satin matte with no varnish.
let PICKLED = Finish { varnish: 0.0, sanding: 0.25, grain: 1.0, rings: 1.0, warmth: 0.0, pickle: 0.8, caulk: 1.0 };

// Summer's teak: oiled, a satin sheen, the relief a little softened.
let OILED = Finish { varnish: 0.3, sanding: 0.3, grain: 1.0, rings: 1.0, warmth: 0.1, pickle: 0.0, caulk: 1.0 };

// Spring's two carved looks, wood 3 as the user tuned it in the panel (2026-11-09).
let SPRING_FINISH = Finish { varnish: 0.335, sanding: 1.0, grain: 1.0, rings: 1.0, warmth: 0.0, pickle: 0.0,
                             caulk: 1.0 };

// Winter's limed ash: white in the pores and the grain, as frost in it, the color cooled,
// a satin matte; and its stained birch, cooled, a little varnished.
let LIMED = Finish { varnish: 0.1, sanding: 0.3, grain: 1.0, rings: 1.0, warmth: -0.3, pickle: 0.3, caulk: 1.0 };
let COOL = Finish { varnish: 0.4, sanding: 0.6, grain: 1.0, rings: 1.0, warmth: -0.4, pickle: 0.0, caulk: 1.0 };

fn finish(wood: i64) -> Finish {
    if wood == 2 { return TUNED; }
    if wood == 3 { return VARNISHED; }
    return PLAIN;
}

// The winter frame's marble (task 039), one solid block, its figure running one way:
// 0 the slate as before (Theme.frame and its clouding), the others polished marbles.
// Winter's frame is 2, as the user tuned it in the panel (2026-11-09).
let MARBLES = 5;
let MARBLE = 2;
// Autumn's stone frame's own marble, past the ones M cycles (marble_for).
let EMPERADOR = 5;

struct Marble {
    base: float4,   // the stone (sRGB), w: its clouding
    vein: float4,   // the veins (sRGB), w: how much the thin threads go toward white
    // x: the main veins' width (world units, a square is 1), y: their softness (0 crisp,
    // 1 cloudy bands), z: the network of fine cracks between them, w: thin wavy threads
    form:   float4,
    veins:  f32,    // the veins' contrast, 1 as made
    wave:   f32,    // how far the flow is warped: 0 straight, 1 as made, 2 very wavy
    polish: f32,    // 0 honed (roughness 0.5) to 1 polished (0.06)
    tint:   f32,    // 0..1: the colors toward the board's steel blue, their lightness kept
}

fn marble(which: i64) -> Marble {
    // Nero Marquina: black with crisp white veins and a fine network of cracks.
    if which == 1 {
        return Marble { base: float4 { 0.075, 0.075, 0.08, 0.25 }, vein: float4 { 0.88, 0.88, 0.86, 0.6 },
                        form: float4 { 0.012, 0.15, 0.8, 0.15 },
                        veins: 1.0, wave: 1.0, polish: 0.8, tint: 0.0 };
    }
    // Dark grey with soft, wavy, cloudy veining, toward the board's steel blue: the user's
    // values from the panel (2026-11-09).
    if which == 2 {
        return Marble { base: float4 { 0.2, 0.205, 0.215, 0.5 }, vein: float4 { 0.46, 0.47, 0.48, 0.3 },
                        form: float4 { 0.04, 1.0, 0.3, 0.0 },
                        veins: 0.94, wave: 2.5, polish: 0.84, tint: 0.88 };
    }
    // Blue-black with steel-blue veins, the board's palette.
    if which == 3 {
        return Marble { base: float4 { 0.075, 0.09, 0.12, 0.3 }, vein: float4 { 0.45, 0.55, 0.67, 0.5 },
                        form: float4 { 0.016, 0.45, 0.5, 0.25 },
                        veins: 1.0, wave: 1.0, polish: 0.75, tint: 0.0 };
    }
    // Black with bundles of thin wavy white threads flowing one way, as in flow-banded
    // black marbles (Nero Ondulato, Port Laurent's threads without the gold).
    if which == 4 {
        return Marble { base: float4 { 0.08, 0.085, 0.095, 0.3 }, vein: float4 { 0.78, 0.8, 0.82, 0.7 },
                        form: float4 { 0.008, 0.25, 0.2, 1.0 },
                        veins: 1.0, wave: 1.2, polish: 0.8, tint: 0.0 };
    }
    // Dark brown with golden cream veins and a network of fine cracks, as Emperador
    // Dark is: autumn's stone frame.
    if which == EMPERADOR {
        return Marble { base: float4 { 0.2, 0.125, 0.085, 0.4 }, vein: float4 { 0.62, 0.48, 0.32, 0.2 },
                        form: float4 { 0.014, 0.6, 0.4, 0.0 },
                        veins: 0.85, wave: 1.4, polish: 0.75, tint: 0.0 };
    }
    return Marble { base: float4_0, vein: float4_0, form: float4_0, veins: 1.0, wave: 1.0, polish: 0.5,
                    tint: 0.0 };
}

// The marble a look's stone frame is made of: its own (autumn's: EMPERADOR, or 0 its own
// figure), else the one chosen (--marble, M), winter's.
fn marble_for(look: i64, chosen: i64) -> i64 {
    if look == AUTUMN_STONE { return EMPERADOR; }
    if look == AUTUMN_CARVED || look == AUTUMN_PORPHYRY || look == SPRING_STONE || look == SUMMER_STONE { return 0; }
    return chosen;
}

// Spring's looks (task 041, the app's and the prototype's --spring): 0 the birch, 1 the
// elven carved stone, 2 the Baltic folk carved oak.
let SPRINGS = 4;
// The look spring shows by default is the elven stone (chosen on the tablet, 2026-11-09,
// over the Baltic oak); --spring 0 is still the birch, 2 the Baltic oak.
let SPRING_LOOK = 1;

// Pale stone with a fine vine line carved along the frame, as in overgrown elven ruins
// (the user's idea, 2026-11-09, toned down to their image `Mossy Elven Checkers in
// Birchwood.png`, our own motifs): a soft, slightly weathered ivory stone frame, two thin
// vines flowing along its top and outer face in a shallow cut outline, crossing over and
// under, sage-tinted leaves, a leaf knot at each corner, moss in the hollows and along
// the frame's edges; ivory stone light squares with faint veins and cloudy olive jade
// dark ones, a fine engraved line round the field; ivory and deep jade pieces. Colors
// measured from the image; the carving's own values are Carving's; spring's light.
fn elven() -> Theme {
    return Theme {
        photo:         2,
        light_sq:      float4 { 0.875, 0.82, 0.77, 0.32 },
        light_fig:     float4 { 0.6, 0.12, 0.06, 0.0 },
        dark_sq:       float4 { 0.385, 0.44, 0.27, 0.22 },
        dark_fig:      float4 { 0.8, 0.5, 0.15, 0.0 },
        inlay:         float4 { 0.28, 0.33, 0.19, 0.25 },
        inlay_fig:     float4 { 0.6, 0.2, 0.08, 0.0 },
        frame:         float4 { 0.85, 0.81, 0.73, 0.45 },
        frame_fig:     float4 { 0.6, 0.16, 0.08, 0.0 },
        surface:       float4 { 0.03, 0.0, 0.35, 0.5 },
        frame_surface: float4 { 0.0, 1.0, 0.0, 0.1 },
        stone:         float4 { 0.07, 0.12, 0.12, 0.0 },
        light_ring:    float4 { 0.05, 5.0, 0.03, 0.0 },
        dark_ring:     float4 { 0.6, 4.5, 0.15, 0.0 },
        frame_ring:    float4 { 0.06, 4.0, 0.0, 0.0 },
        light_piece:   float4 { 0.86, 0.81, 0.72, 0.42 },
        dark_piece:    float4 { 0.37, 0.41, 0.26, 0.28 },
        piece_fig:     float4 { 0.04, 0.25, 0.0, 0.55 },
        crown:         float4 { 0.37, 0.41, 0.26, 0.0 },
        edge:          float4 { 0.0, 0.0, 0.0, 0.0 },
        line:          float4 { 0.0, 0.0, 0.0, 0.0 },
        key:           float4 { -0.5, 0.85, -0.45, 3.3 },
        key_color:     float4 { 1.0, 0.97, 0.92, 0.0 },
        bounce:        float4 { 0.8, 0.8, 0.72, 0.8 },
        ambient:       float4 { 1.4, 1.3, 0.55, 0.0 },
        glow:          float4 { 0.56, 0.83, 1.0, 0.55 },
        grade:         float4 { 2.3, 1.0, 1.2, 0.85 },
        tint:          float4 { 0.7, 0.74, 0.62, 0.4 },
        build:         float4 { 0.0, 0.0, 0.0, 1.0 },
        seam:          float4_0,
        fill:          float4 { 0.52, 0.6, 0.38, 0.75 },
    };
}

// Baltic folk: a dark oiled oak frame, mitred, carved along its top with a band of
// geometric ornament (diamonds with a cross in each, zigzags, a running meander between
// two lines), a sun wheel in each corner and a tree of life in the middle of the far and
// near sides, the cut showing the lighter wood under the oil; pale birch light squares
// and green-stained dark ones, dark oak and pale birch pieces (the user's image `Baltic
// Folk Carved Checkers Board.png`, colors measured from it, our own forms). Spring's
// light; wood 2, oiled (wood_for, finish_for).
fn baltic() -> Theme {
    var t = spring();
    t.light_sq = float4 { 0.91, 0.75, 0.55, 0.45 };
    t.light_fig = float4 { 0.15, 0.35, 0.4, 1.0 };
    t.dark_sq = float4 { 0.3, 0.3, 0.09, 0.45 };
    t.dark_fig = float4 { 0.15, 0.3, 0.35, 1.0 };
    t.inlay = float4 { 0.2, 0.12, 0.07, 0.5 };
    t.inlay_fig = float4 { 0.2, 0.25, 0.25, 1.0 };
    t.frame = float4 { 0.36, 0.22, 0.12, 0.55 };
    t.frame_fig = float4 { 0.2, 0.25, 0.45, 1.0 };
    t.surface = float4 { 0.06, 0.4, 0.45, 0.6 };
    t.frame_surface = float4 { 0.8, 2.5, 0.8, 0.3 };
    t.light_ring = float4 { 0.09, 0.35, 0.18, 0.08 };
    t.dark_ring = float4 { 0.09, 0.35, 0.22, 0.08 };
    t.frame_ring = float4 { 0.06, 0.4, 0.6, 0.7 };
    t.light_piece = float4 { 0.87, 0.68, 0.45, 0.5 };
    t.dark_piece = float4 { 0.42, 0.25, 0.13, 0.4 };
    t.piece_fig = float4 { 0.04, 0.22, 0.35, 0.45 };
    t.crown = float4 { 0.42, 0.26, 0.15, 0.0 };
    t.build = float4 { 0.0, 1.0, 0.0, 1.0 };
    t.fill = float4 { 0.78, 0.55, 0.32, 1.0 };
    return t;
}

// Summer 4, amber stone: a grey-green granite frame, speckled, with soft lichen patches,
// carved along its top with sun signs, a tree of life in the middle of the far and near
// sides and small runic marks between (our own strokes), the cuts filled with amber;
// summer's warmth in honed stone squares, warm sandstone and a deep reddish stone, pale
// limestone and reddish pieces (the user's image `Amber-Carved Stone Checkers in the
// Forest.png` but its squares). Summer's light.
fn summer_amber() -> Theme {
    var t = summer();
    t.light_sq = float4 { 0.88, 0.75, 0.59, 0.45 };
    t.light_fig = float4 { 0.6, 0.12, 0.12, 0.0 };
    t.dark_sq = float4 { 0.43, 0.21, 0.16, 0.42 };
    t.dark_fig = float4 { 0.7, 0.3, 0.14, 0.0 };
    t.inlay = float4 { 0.3, 0.15, 0.11, 0.45 };
    t.inlay_fig = float4 { 0.6, 0.2, 0.1, 0.0 };
    t.frame = float4 { 0.5, 0.51, 0.46, 0.62 };
    t.frame_fig = float4 { 0.8, 0.6, 0.4, 0.0 };
    t.surface = float4 { 0.04, 0.0, 0.4, 0.5 };
    t.frame_surface = float4 { 0.0, 2.5, 0.0, 0.1 };
    t.stone = float4 { 0.03, 0.12, 0.15, 1.0 };
    t.light_ring = float4 { 0.06, 8.0, 0.0, 0.0 };
    t.dark_ring = float4 { 0.3, 6.0, 0.08, 0.0 };
    t.frame_ring = float4 { 0.4, 9.0, 0.0, 0.0 };
    t.light_piece = float4 { 0.88, 0.83, 0.72, 0.45 };
    t.dark_piece = float4 { 0.36, 0.17, 0.13, 0.35 };
    t.piece_fig = float4 { 0.05, 0.18, 0.0, 0.5 };
    t.crown = float4 { 0.36, 0.17, 0.13, 0.0 };
    t.build = float4 { 0.0, 0.5, 0.0, 1.0 };
    t.fill = float4 { 0.95, 0.64, 0.16, 1.0 };
    return t;
}

// Summer 5: the amber stone with the image's squares, pale limestone and deep green
// serpentine with a mottled figure, limestone and serpentine pieces.
fn summer_serpentine() -> Theme {
    var t = summer_amber();
    t.light_sq = float4 { 0.82, 0.79, 0.73, 0.45 };
    t.dark_sq = float4 { 0.27, 0.3, 0.19, 0.32 };
    t.dark_fig = float4 { 0.8, 0.4, 0.2, 0.0 };
    t.dark_ring = float4 { 0.55, 7.0, 0.3, 0.0 };
    t.inlay = float4 { 0.18, 0.21, 0.14, 0.4 };
    t.light_piece = float4 { 0.82, 0.78, 0.7, 0.45 };
    t.dark_piece = float4 { 0.26, 0.29, 0.2, 0.32 };
    t.crown = float4 { 0.26, 0.29, 0.2, 0.0 };
    t.key_color = float4 { 1.0, 0.95, 0.88, 0.0 };
    return t;
}

// Autumn 1, stone: honed travertine light squares, warm honey with a soft clouding, and
// polished red jasper dark ones, mottled with pale veins, a deep brown inlay, in a solid
// block of dark brown marble with golden veins (EMPERADOR, marble_for); cream travertine
// and rust-brown stone pieces. Autumn's light, its forest's rust and amber in stone.
fn autumn_stone() -> Theme {
    var t = autumn();
    t.light_sq = float4 { 0.9, 0.79, 0.62, 0.4 };
    t.light_fig = float4 { 0.6, 0.16, 0.08, 0.0 };
    t.dark_sq = float4 { 0.52, 0.24, 0.13, 0.28 };
    t.dark_fig = float4 { 0.7, 0.28, 0.12, 0.0 };
    t.inlay = float4 { 0.22, 0.12, 0.08, 0.35 };
    t.inlay_fig = float4 { 0.6, 0.2, 0.1, 0.0 };
    t.frame = float4 { 0.3, 0.19, 0.13, 0.4 };
    t.frame_fig = float4 { 0.6, 0.2, 0.2, 0.0 };
    t.surface = float4 { 0.04, 0.0, 0.4, 0.5 };
    t.frame_surface = float4 { 0.0, 0.5, 0.0, 0.1 };
    t.stone = float4 { 0.1, 0.16, 0.12, 0.0 };
    t.light_ring = float4 { 0.2, 4.0, 0.0, 0.0 };
    t.dark_ring = float4 { 0.3, 6.0, 0.12, 0.0 };
    t.frame_ring = float4_0;
    t.light_piece = float4 { 0.92, 0.85, 0.72, 0.5 };
    t.dark_piece = float4 { 0.34, 0.17, 0.11, 0.36 };
    t.piece_fig = float4 { 0.04, 0.2, 0.0, 0.45 };
    t.crown = float4 { 0.34, 0.17, 0.11, 0.0 };
    t.build = float4 { 1.0, 0.0, 1.0, 0.0 };
    return t;
}

// Autumn 2: the same field in a weathered brown stone frame, mitred, speckled and
// coarse, the elven vines carved along it (AUTUMN_VINES) with their leaves turned rust
// and gold, a little moss in the cuts.
fn autumn_carved() -> Theme {
    var t = autumn_stone();
    t.frame = float4 { 0.4, 0.3, 0.23, 0.55 };
    t.frame_fig = float4 { 0.8, 0.4, 0.2, 0.0 };
    t.frame_surface = float4 { 0.0, 2.0, 0.0, 0.1 };
    t.stone = float4 { 0.06, 0.12, 0.15, 0.6 };
    t.frame_ring = float4 { 0.3, 8.0, 0.0, 0.0 };
    // Mitred for the carving's bands, but no joint drawn: a stone frame shows no seam at
    // its corners (the user, 2026-11-13), as the elven one.
    t.build = float4 { 0.0, 0.0, 0.0, 1.0 };
    t.fill = float4 { 0.72, 0.38, 0.14, 0.7 };
    return t;
}

// Autumn 3: golden sandstone and deep red-brown porphyry, a speckled dark stone frame,
// one block, with its own clouding (no marble); sandstone and porphyry pieces.
fn autumn_porphyry() -> Theme {
    var t = autumn_stone();
    t.light_sq = float4 { 0.88, 0.73, 0.5, 0.48 };
    t.light_fig = float4 { 0.6, 0.2, 0.14, 0.0 };
    t.light_ring = float4 { 0.1, 9.0, 0.0, 0.0 };
    t.dark_sq = float4 { 0.4, 0.17, 0.15, 0.3 };
    t.dark_fig = float4 { 0.6, 0.2, 0.2, 0.0 };
    t.dark_ring = float4 { 0.25, 14.0, 0.0, 0.0 };
    t.frame = float4 { 0.3, 0.22, 0.17, 0.5 };
    t.frame_fig = float4 { 0.7, 0.3, 0.3, 0.0 };
    t.frame_surface = float4 { 0.0, 1.5, 0.0, 0.2 };
    t.stone = float4 { 0.04, 0.16, 0.15, 1.0 };
    t.frame_ring = float4 { 0.2, 8.0, 0.0, 0.0 };
    // One solid block with the field cut out: a stone frame shows no seam at its corners
    // (the user, 2026-11-13).
    t.build = float4 { 1.0, 0.0, 0.0, 0.0 };
    t.light_piece = float4 { 0.9, 0.8, 0.64, 0.5 };
    t.dark_piece = float4 { 0.3, 0.14, 0.13, 0.36 };
    t.crown = float4 { 0.3, 0.14, 0.13, 0.0 };
    return t;
}

// Winter 1, wood: limed ash light squares, pale and cool, their open grain filled white
// as frost (LIMED), smoked oak dark ones, grey with the same white in their grain, a
// mitred frame of dark blue-grey stained oak limed the same; ivory and smoked dark pieces.
// Winter's light; wood 2's rings (wood_for).
fn winter_wood() -> Theme {
    var t = winter();
    t.light_sq = float4 { 0.8, 0.77, 0.72, 0.5 };
    t.light_fig = float4 { 0.3, 0.3, 0.35, 1.0 };
    t.dark_sq = float4 { 0.36, 0.33, 0.31, 0.5 };
    t.dark_fig = float4 { 0.3, 0.35, 0.4, 1.0 };
    t.inlay = float4 { 0.16, 0.17, 0.2, 0.5 };
    t.inlay_fig = float4 { 0.3, 0.3, 0.3, 1.0 };
    t.frame = float4 { 0.3, 0.31, 0.34, 0.55 };
    t.frame_fig = float4 { 0.3, 0.35, 0.5, 1.0 };
    t.surface = float4 { 0.06, 0.7, 0.4, 0.9 };
    t.frame_surface = float4 { 1.0, 3.0, 1.0, 0.1 };
    t.stone = float4_0;
    t.light_ring = float4 { 0.07, 0.4, 0.5, 0.45 };
    t.dark_ring = float4 { 0.07, 0.4, 0.5, 0.4 };
    t.frame_ring = float4 { 0.07, 0.4, 0.7, 0.8 };
    t.light_piece = float4 { 0.88, 0.86, 0.82, 0.52 };
    t.dark_piece = float4 { 0.22, 0.23, 0.25, 0.34 };
    t.piece_fig = float4 { 0.03, 0.15, 0.3, 0.4 };
    t.crown = float4 { 0.22, 0.23, 0.25, 0.0 };
    t.edge = float4_0;
    t.build = float4 { 0.0, 1.0, 0.0, 0.0 };
    return t;
}

// Winter 2: the same field in a smoked oak frame carved along its top with a Nordic band
// (NORDIC: the folk band, its sun wheels read as snowflakes), the cut showing pale wood.
fn winter_carved() -> Theme {
    var t = winter_wood();
    t.frame = float4 { 0.2, 0.2, 0.22, 0.55 };
    t.build = float4 { 0.0, 1.0, 0.0, 1.0 };
    t.fill = float4 { 0.86, 0.86, 0.84, 1.0 };
    return t;
}

// Winter 3: pale birch light squares and birch stained a slate blue-grey, the winter
// board's own colors in wood, in a deep blue-grey stained frame; satin (COOL).
fn winter_stained() -> Theme {
    var t = winter_wood();
    t.light_sq = float4 { 0.84, 0.81, 0.74, 0.45 };
    t.light_fig = float4 { 0.15, 0.35, 0.4, 1.0 };
    t.dark_sq = float4 { 0.4, 0.44, 0.5, 0.45 };
    t.dark_fig = float4 { 0.15, 0.3, 0.35, 1.0 };
    t.inlay = float4 { 0.15, 0.18, 0.24, 0.5 };
    t.frame = float4 { 0.22, 0.26, 0.32, 0.55 };
    t.frame_fig = float4 { 0.2, 0.25, 0.35, 1.0 };
    t.surface = float4 { 0.06, 0.4, 0.45, 0.6 };
    t.frame_surface = float4 { 0.4, 1.5, 0.4, 0.3 };
    t.light_ring = float4 { 0.09, 0.35, 0.18, 0.08 };
    t.dark_ring = float4 { 0.09, 0.35, 0.22, 0.08 };
    t.frame_ring = float4 { 0.08, 0.35, 0.3, 0.15 };
    t.dark_piece = float4 { 0.2, 0.235, 0.28, 0.34 };
    t.crown = float4 { 0.2, 0.235, 0.28, 0.0 };
    return t;
}

// A carved frame's carving and the look's tints (the prototype's tuning panel, P): what
// a carved look (Theme.build.w) bakes into its frame and how it tints its surfaces.
struct Carving {
    // The motif (shaders::BAKE_FRAG's carving): 0 vines in relief, a shallow outline cut
    // round them, on the top and the outer face; 1 the folk band cut in (diamonds,
    // zigzags, a meander, a sun wheel in the corners, a tree of life mid-side); 2 signs
    // cut in (sun signs, trees of life, runic marks), for amber; 3 none, only the moss
    // along the edges and the lichen (a plain stone weathered, task 080)
    motif:  i64,
    depth:  f32,    // how deep the cut is, world units (a square is 1)
    scale:  f32,    // the motifs' repeats per side
    moss:   f32,    // 0..1: how much moss settles in the hollows and along the edges
    amber:  f32,    // 0..1: how full of amber the cuts are (Theme.fill)
    lichen: f32,    // 0..1: lichen patches on the stone
    warmth: f32,    // -1..1: the light stone or wood toward grey-white (-) or warm (+)
    jade:   f32,    // 0..1: the dark squares pale (0) to deep (1), 0.5 as the look has it
}

// The user's values for the carved looks (2026-11-09): spring's elven stone and Baltic oak,
// summer's amber stone.
let ELVEN = Carving { motif: 0, depth: 0.023, scale: 23.685, moss: 0.49, amber: 0.0, lichen: 0.0, warmth: 0.52,
                      jade: 0.64 };
let BALTIC = Carving { motif: 2, depth: 0.015, scale: 3.0, moss: 0.0, amber: 0.655, lichen: 0.0, warmth: 0.0,
                       jade: 0.62 };
let AMBER_TUNED = Carving { motif: 2, depth: 0.02, scale: 3.0, moss: 0.5, amber: 0.55, lichen: 0.085, warmth: 0.0,
                            jade: 0.5 };
// The plain stones' weathering (motif 3, nothing cut; the user 2026-11-13: moss and
// lichen so the plain stone isn't bare, then better as a whole, cracks and veins): hairline
// cracks with moss in them, spring's mossier, summer's with a little lichen.
let MOSSY = Carving { motif: 3, depth: 0.006, scale: 1.0, moss: 0.8, amber: 0.0, lichen: 0.0, warmth: 0.52,
                      jade: 0.64 };
let WEATHERED = Carving { motif: 3, depth: 0.006, scale: 1.0, moss: 0.5, amber: 0.0, lichen: 0.08, warmth: 0.0,
                          jade: 0.5 };
let AMBER = Carving { motif: 2, depth: 0.02, scale: 12.0, moss: 0.5, amber: 0.55, lichen: 0.5, warmth: 0.0,
                      jade: 0.5 };

// Autumn's carved stone: the elven vines, little moss, the leaves rust (Theme.fill);
// winter's Nordic band: the folk band cut into smoked oak, its sun wheels as snowflakes.
let AUTUMN_VINES = Carving { motif: 0, depth: 0.023, scale: 23.685, moss: 0.15, amber: 0.0, lichen: 0.0, warmth: 0.0,
                             jade: 0.5 };
let NORDIC = Carving { motif: 1, depth: 0.015, scale: 6.0, moss: 0.0, amber: 0.0, lichen: 0.0, warmth: 0.0,
                       jade: 0.5 };

// A carved look's own carving (shown()'s look), ELVEN for one that isn't carved.
fn carving_for(look: i64) -> Carving {
    if look == SPRING_BALTIC { return BALTIC; }
    if look == SUMMER_AMBER { return AMBER_TUNED; }
    if look == SPRING_STONE { return MOSSY; }
    if look == SUMMER_STONE { return WEATHERED; }
    if look == SUMMER_SERPENTINE { return AMBER; }
    if look == AUTUMN_CARVED { return AUTUMN_VINES; }
    if look == WINTER_CARVED { return NORDIC; }
    return ELVEN;
}

// The moss in the carving's hollows (sRGB), w: how patchy; the lichen on stone.
let MOSS = float4 { 0.45, 0.5, 0.17, 0.6 };
let LICHEN = float4 { 0.72, 0.74, 0.58, 0.0 };

// The theme for `which` with spring's look `spring` (SPRING_LOOK..) and, for a carved
// look, its carving's tints: what the renderer bakes and lights.
fn variant(which: i64, spring: i64, c: Carving) -> Theme {
    let look = shown(which, spring);
    var t = get(look);
    // The plain stones keep their carved siblings' tints, so the two differ only in the
    // carving.
    guard t.build.w > 0.5 || look == SPRING_STONE || look == SUMMER_STONE else { return t; }
    let warm = float4 { 1.0 + 0.05 * c.warmth, 1.0 + 0.005 * c.warmth, 1.0 - 0.07 * c.warmth, 1.0 };
    t.light_sq *= warm;
    t.frame *= warm;
    t.light_piece *= warm;
    let e: f32 = 0.5 + c.jade;
    t.dark_sq = deepen(t.dark_sq, e);
    t.inlay = deepen(t.inlay, e);
    t.dark_piece = deepen(t.dark_piece, e);
    t.crown = deepen(t.crown, e);
    return t;
}

// A carved stone look without its carving: no band cut, only its weathering.
fn plain(t_in: Theme) -> Theme {
    var t = t_in;
    // Mitred bands with no joint drawn, as the carved frame, so its moss and lichen
    // (carving_for: motif 3) follow the profile; nothing cut.
    t.build = float4 { 0.0, 0.0, t.build.z, 1.0 };
    return t;
}

// A color to the power e, its w kept: deeper is also more saturated, as Beer's law has it.
fn deepen(c: float4, e: f32) -> float4 { float4 { pow(c.x, e), pow(c.y, e), pow(c.z, e), c.w } }
