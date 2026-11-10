// The four board themes and the season that picks one, with the values of
// docs/architecture/rendering.md ("Seasons and themes"). The shaders take a theme as
// one uniform block.
namespace theme;
import std;
import vec;

let WOOD = 0;
let STONE = 1;
let BIRCH = 2;
let SUNSET = 3;

// The shaders' uniform block, std140: vec4s, colors in sRGB 0..1.
struct Theme {
    light:   float4,    // squares
    dark:    float4,
    frame:   float4,
    w_face:  float4,    // pieces: the face; ring, rim, and side are worked out from it
    b_face:  float4,
    crown_w: float4,    // the crown on a light piece; on a dark one it is gold
    glow:    float4,
    page:    float4,    // the color under everything
    kind:    float4,    // x: the square surface (WOOD..SUNSET)
    glass:   float4,    // the glass tint, w: its opacity
    text:    float4,    // the text and icons; w: how much the glass copy is dimmed to
    // The plain background in place of the photograph (task 044), in linear light: the
    // page at the top, a deep tone of the frame at the foot, and a faint light of the
    // dark square behind the middle (src/render3d/shaders.goose, FADE_FN).
    fade_top:   float4,
    fade_low:   float4,
    fade_light: float4,
}

fn rgb(hex: i64) -> float4 { rgba(hex, 1.0) }
fn rgba(hex: i64, w: f32) -> float4 {
    return float4 { ((hex >> 16) & 255) / 255.0, ((hex >> 8) & 255) / 255.0,
                    (hex & 255) / 255.0, w };
}

// An sRGB color in linear light, as the fade mixes them.
fn linear(hex: i64) -> float4 {
    let c = rgb(hex);
    return float4 { model3d::linear(c.x), model3d::linear(c.y), model3d::linear(c.z), 1.0 };
}

// The plain background's colors, by theme: prototypes/draughts.js's PLAIN, take b
// (the user's choice, 2026-11-09).
let FADE_TOP = [0x1e1510, 0x0c1724, 0x101b15, 0x21150f];
let FADE_LOW = [0x4a2c1a, 0x2c3a4c, 0x2f3d30, 0x4f2e28];

fn get(kind: i64) -> Theme {
    var t = colors(kind);
    let k = clamp(kind, WOOD, SUNSET);
    t.fade_top = linear(FADE_TOP[k]);
    t.fade_low = linear(FADE_LOW[k]);
    t.fade_light = float4 { model3d::linear(t.dark.x), model3d::linear(t.dark.y), model3d::linear(t.dark.z), 1.0 };
    return t;
}

fn colors(kind: i64) -> Theme {
    let k = float4 { kind, 0.0, 0.0, 0.0 };
    let none = float4 { 0.0, 0.0, 0.0, 0.0 };
    return match kind {
        WOOD => Theme { light: rgb(0xe2b070), dark: rgb(0x7a4626), frame: rgb(0x3b2112),
                        w_face: rgb(0xf0d4a4), b_face: rgb(0x4a2918), crown_w: rgb(0x4a2918),
                        glow:   rgb(0xffd75a), page: rgb(0x1c1410), kind: k,
                        glass:  rgba(0x2b1e18, 0.66), text: rgba(0xf8f3e6, 0.9),
                        fade_top: none, fade_low: none, fade_light: none },
        STONE => Theme { light: rgb(0xd8dee7), dark: rgb(0x5a6777), frame: rgb(0x2a3442),
                         w_face: rgb(0xf3eee2), b_face: rgb(0x2b3440), crown_w: rgb(0x2b3440),
                         glow:   rgb(0xa7d0fb), page: rgb(0x0b1622), kind: k,
                         glass:  rgba(0x1e2f45, 0.4), text: rgba(0xe6f4ff, 0.75),
                        fade_top: none, fade_low: none, fade_light: none },
        BIRCH => Theme { light: rgb(0xe8e2d3), dark: rgb(0x6b7f6a), frame: rgb(0x3d4a3c),
                         w_face: rgb(0xf6f3e7), b_face: rgb(0x3a4a3f), crown_w: rgb(0x3a4a3f),
                         glow:   rgb(0x8fd4ff), page: rgb(0x101a14), kind: k,
                         glass:  rgba(0x1e2f45, 0.4), text: rgba(0xe6f4ff, 0.75),
                        fade_top: none, fade_low: none, fade_light: none },
        _ => Theme { light: rgb(0xefd9c3), dark: rgb(0x9a6655), frame: rgb(0x4a2c26),
                     w_face: rgb(0xfbf3e8), b_face: rgb(0x4a2f35), crown_w: rgb(0x4a2f35),
                     glow:   rgb(0xffb08a), page: rgb(0x20140f), kind: k,
                     glass:  rgba(0x462828, 0.45), text: rgba(0xfff3ea, 0.8),
                        fade_top: none, fade_low: none, fade_light: none },
    };
}

// The month (1..12) of a time in seconds since the epoch, in UTC: Howard Hinnant's
// days-to-civil, enough for the season.
fn month(epoch: f64) -> i64 {
    let z = (epoch / 86400.0) as i64 + 719468;
    let era = div_euclid(z, 146097);
    let doe = z - era * 146097;
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    return if mp < 10 { mp + 3 } else { mp - 9 };
}

// The season picks the board: autumn wood, winter stone, spring birch, summer sunset.
fn for_month(m: i64) -> i64 {
    return if m == 12 || m <= 2 { STONE } else if m <= 5 { BIRCH } else if m <= 8 { SUNSET } else { WOOD };
}

fn by_name(name: const u8[:]) -> i64 {
    return if name == "wood" { WOOD } else if name == "stone" { STONE } else if name == "birch" { BIRCH }
           else if name == "sunset" { SUNSET } else { -1 };
}
