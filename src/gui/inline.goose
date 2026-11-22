// A line of text with an icon in it (rendering.md, "Controls"): the marker ICON_MARK in
// the string stands where the icon goes, so each language puts it where its grammar
// wants ("@ wants to play on."). Part of the gui's namespace.
namespace gui;
import std;

let ICON_MARK:   u8  = '@';
let INLINE_ICON: f32 = 1.4;     // the icon's side, of the face's height

// The inline icon's side in face `face`, in pixels.
fn inline_icon_side(g: Gui&, face: i64) -> f32 {
    let f .= g.faces[face];
    return floor(INLINE_ICON * (f.ascent - f.descent) + 0.5);
}

// Where the marker is in s, or -1.
fn icon_mark_at(s: const u8[:]) -> i64 {
    for c, i in s { if c == ICON_MARK { return i; } }
    return -1;
}

// How wide s is in face `face`, the marker as wide as the icon.
fn icon_text_width(g: Gui&, face: i64, s: const u8[:]) -> f32 {
    let k = icon_mark_at(s);
    guard k >= 0 else { return text_width(g, face, s); }
    return text_width(g, face, s[..k]) + inline_icon_side(g, face) + text_width(g, face, s[k + 1..]);
}

// Text s as text() lays it, on one line in r lined up by `align`, with `icon` drawn at
// full opacity where the marker is, centered down r.
fn icon_text(g: Gui&, face: i64, r: float4, s: const u8[:], icon: i64, a: f32, align: i64) {
    let k = icon_mark_at(s);
    guard k >= 0 else {
        text(g, face, r, s, a, 0.0, align);
        return;
    }
    let side = inline_icon_side(g, face);
    let before = text_width(g, face, s[..k]);
    let w = before + side + text_width(g, face, s[k + 1..]);
    let x = floor((if align == LEFT { r.x } else if align == CENTER { r.x + 0.5 * (r.z - w) } else { r.x + r.z - w }) + 0.5);
    if k > 0 { text(g, face, float4 { x, r.y, before, r.w }, s[..k], a, 0.0, LEFT); }
    glyph_icon(g, float4 { x + before, floor(r.y + 0.5 * (r.w - side) + 0.5), side, side }, icon, PLAIN, 0.0, 1.0);
    if k + 1 < s.len { text(g, face, float4 { x + before + side, r.y, w - before - side, r.w }, s[k + 1..], a, 0.0, LEFT); }
}
