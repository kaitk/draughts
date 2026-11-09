// The board's looks as data: one flat struct of colors, roughness and material
// parameters per theme, read by one bake and one set of shaders. Colors are sRGB (the
// shaders take them linear); a surface's color is about how it reads lit from above,
// tuned against the user's even-lit swatches (agents/design.md).
namespace looks;
import std;
import vec;

let AUTUMN = 0;
let WINTER = 1;
let COUNT = 2;

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
    // each side. y: the mitre joint's strength; z: 1 for stone (shaders::LIT_FRAG).
    build: float4,
}

fn get(which: i64) -> Theme {
    if which == WINTER { return winter(); }
    return autumn();
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
    };
}

// The wood's finish, per model of the wood (render3d::WOOD_MODEL..): what the prototype's
// tuning panel (P) sets, baked into the wood's surfaces only, never the stone. Neutral
// is varnish 0, sanding 0, grain 1, rings 1, warmth 0: the bake as the model has it.
struct Finish {
    varnish: f32,   // 0..1: the roughness lower (×0.55 at 1), the pores a little filled
    sanding: f32,   // 0..1: the grain's and the pores' relief shallower (×0.3 at 1)
    grain:   f32,   // the figure's contrast round the base color, 1 as baked
    rings:   f32,   // the rings' and the grain's spacing across, 1 as baked
    warmth:  f32,   // -1..1: the color toward grey-yellow (-) or red-orange (+)
}

let PLAIN = Finish { varnish: 0.0, sanding: 0.0, grain: 1.0, rings: 1.0, warmth: 0.0 };

// "The same wood, very slightly more varnish and sanded a tiny bit more" (the user,
// 2026-11-09), on the two woods kept for the game.
let VARNISHED = Finish { varnish: 0.2, sanding: 0.15, grain: 1.0, rings: 1.0, warmth: 0.0 };

fn finish(wood: i64) -> Finish {
    if wood == 2 || wood == 3 { return VARNISHED; }
    return PLAIN;
}

// The winter frame's marble (task 039), one solid block, its figure running one way:
// 0 the slate as before (Theme.frame and its clouding), the others polished marbles.
// Winter's frame is 2, as the user tuned it in the panel (2026-11-09).
let MARBLES = 5;
let MARBLE = 2;

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
    return Marble { base: float4_0, vein: float4_0, form: float4_0, veins: 1.0, wave: 1.0, polish: 0.5,
                    tint: 0.0 };
}
