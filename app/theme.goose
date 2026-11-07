// The four board themes and the season that picks one, with the values of
// docs/architecture/rendering.md ("Seasons and themes"). The shaders take a theme as
// one uniform block.
namespace theme;
import std;
import vec;

let WOOD = 0;
let STONE = 1;
let BIRCH = 2;
let SEA = 3;

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
    kind:    float4,    // x: the square surface (WOOD..SEA)
}

fn rgb(hex: i64) -> float4 {
    return float4 { ((hex >> 16) & 255) / 255.0, ((hex >> 8) & 255) / 255.0,
                    (hex & 255) / 255.0, 1.0 };
}

fn get(kind: i64) -> Theme {
    let k = float4 { kind, 0.0, 0.0, 0.0 };
    return match kind {
        WOOD => Theme { light: rgb(0xe2b070), dark: rgb(0x7a4626), frame: rgb(0x3b2112),
                        w_face: rgb(0xf0d4a4), b_face: rgb(0x4a2918), crown_w: rgb(0x4a2918),
                        glow: rgb(0xffd75a), page: rgb(0x1c1410), kind: k },
        STONE => Theme { light: rgb(0xd8dee7), dark: rgb(0x5a6777), frame: rgb(0x2a3442),
                         w_face: rgb(0xf3eee2), b_face: rgb(0x2b3440), crown_w: rgb(0x2b3440),
                         glow: rgb(0xa7d0fb), page: rgb(0x0b1622), kind: k },
        BIRCH => Theme { light: rgb(0xe8e2d3), dark: rgb(0x6b7f6a), frame: rgb(0x3d4a3c),
                         w_face: rgb(0xf6f3e7), b_face: rgb(0x3a4a3f), crown_w: rgb(0x3a4a3f),
                         glow: rgb(0x8fd4ff), page: rgb(0x101a14), kind: k },
        _ => Theme { light: rgb(0xc7d5c6), dark: rgb(0x2e5546), frame: rgb(0x1d3a30),
                     w_face: rgb(0xf6f1e4), b_face: rgb(0xb56a57), crown_w: rgb(0x2e5546),
                     glow: rgb(0x86e7d3), page: rgb(0x0d1c1c), kind: k },
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

// The season picks the board: autumn wood, winter stone, spring birch, summer sea.
fn for_month(m: i64) -> i64 {
    return if m == 12 || m <= 2 { STONE } else if m <= 5 { BIRCH } else if m <= 8 { SEA } else { WOOD };
}

fn by_name(name: const u8[:]) -> i64 {
    return if name == "wood" { WOOD } else if name == "stone" { STONE } else if name == "birch" { BIRCH }
           else if name == "sea" { SEA } else { -1 };
}
