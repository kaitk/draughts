// The board's looks as data: one flat struct of colors, roughness and material
// parameters per theme, read by one bake and one set of shaders. Colors are sRGB (the
// shaders take them linear); a surface's color is about how it reads lit from above,
// tuned against the user's even-lit swatches (agents/design.md).
namespace theme;
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
    // The frame's wood: x its pores, y its relief, z the fine dark late-wood streaks along
    // the grain, w how much smoother (polished) its rounded edge is than its top.
    frame_surface: float4,
    // Stone (a figure drawn out 0): x its veins' contrast, y its clouding's, z how far the
    // roughness follows the figure.
    stone: float4,
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
