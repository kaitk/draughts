// Text (docs/architecture/rendering.md, "Fonts"): Libertinus Sans baked by the `ui`
// package's atlas, one face per size gui uses, at the screen's pixel size, so a glyph is
// drawn a texel to a pixel. The glyphs' boxes and places go into gui's tables, and the
// atlas's image into a texture the UI shader samples, and the atlas is destroyed, its
// pixels with it; nothing else of `ui` is used. Baked at start, and again only when the
// layout's scale changes.
namespace text;
import std;
import vec;
import gfx;
import ui;

import gui from "../gui";

// Libertinus Sans's ascent less its descent, in ems (hhea 894 and -246 in 1000 units per
// em). The atlas sizes a font by that line, CSS and gui's faces by the em.
let LINE = 1.14;

struct Text {
    texture: gfx::Texture = gfx::Texture { 0 },
    scale:   f32          = 0.0,
}

// Bakes the faces at `scale` pixels per dp into g's glyph tables and t.texture, unless
// they are baked at that scale already; true when it baked.
fn bake(t: Text&, g: gui::Gui&, scale: f32) -> bool {
    guard scale != t.scale else { return false; }
    if t.texture.id != 0 { gfx::release(t.texture); }
    t.scale = scale;
    let atlas = ui::create_font_atlas();
    let ttf = embed_file("../assets/fonts/LibertinusSans-Regular.ttf");
    let ranges: u32[4] = [0x20, gui::LATIN_END - 1, gui::PUNCT, gui::PUNCT_END - 1];
    var fonts: ui::Font[gui::FACES] = [ui::Font { 0 }; gui::FACES];
    for face in gui::FACES {
        fonts[face] = ui::add_font_from_memory(atlas, ttf, (LINE * gui::FACE_DP[face]) as f32 * scale,
                                               ui::FontConfig {}, ranges);
    }
    guard ui::bake(atlas) else { abort(str("ui: ", ui::error())); }
    let size = ui::atlas_size(atlas);
    t.texture = gfx::texture2d(size.x, size.y);
    gfx::update_texture(t.texture, ui::atlas_pixels(atlas));
    for face in gui::FACES {
        let info = ui::info(fonts[face]);
        let f .= g.faces[face];
        f.size = info.height;
        f.ascent = info.ascent;
        f.descent = info.descent;
        for i in gui::MAX_GLYPHS {
            let gl, own = ui::find_glyph(fonts[face], gui::glyph_char(i) as u32);
            f.glyphs[i] = gui::Glyph { box: float4 { gl.x0, gl.y0, gl.x1, gl.y1 },
                                       uv: float4 { gl.u0, gl.v0, gl.u1, gl.v1 }, advance: gl.xadvance };
        }
    }
    ui::destroy(atlas);
    return true;
}
