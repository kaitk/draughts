// Libertinus Sans baked by `ui`'s atlas, one face per size gui uses, at the screen's
// pixel size so a glyph is drawn a texel to a pixel (docs/architecture/rendering.md,
// "Fonts"). Baked again only when the layout's scale changes.
namespace text;
import std;
import vec;
import ui;

import gui from "../gui";

// Libertinus Sans's ascent less its descent, in ems (hhea 894 and -246 in 1000 units per
// em). The atlas sizes a font by that line, CSS and gui's faces by the em.
let LINE = 1.14;

struct Text { scale: f32 = 0.0 }

fn stale(t: Text&, scale: f32) -> bool { scale != t.scale }

// Bakes the faces at `scale` pixels per dp into g's glyph tables. Returns the coverage,
// one byte a texel, the first width × height of it the texture's.
fn bake(t: Text&, g: gui::Gui&, scale: f32) -> u8[>..], int2 {
    t.scale = scale;
    let atlas = ui::create_font_atlas();
    let ttf = embed_file("../../assets/fonts/LibertinusSans-Regular.ttf");
    let all: u32[4] = [0x20, gui::LATIN_END - 1, gui::PUNCT, gui::PUNCT_END - 1];
    var fonts: ui::Font[gui::FACES] = [ui::Font { 0 }; gui::FACES];
    for face in gui::FACES {
        let height = (LINE * gui::FACE_DP[face]) as f32 * scale;
        var set: gui::Chars = [];
        guard shell::face_chars(face, set) else {
            fonts[face] = ui::add_font_from_memory(atlas, ttf, height, ui::FontConfig {}, all);
            continue;
        }
        var runs: u32[..2 * gui::MAX_CHARS] = [];
        for c in set {
            if runs.len > 0 && runs[runs.len - 1] + 1 == c { runs[runs.len - 1] = c; }
            else {
                runs.push(c);
                runs.push(c);
            }
        }
        fonts[face] = ui::add_font_from_memory(atlas, ttf, height, ui::FontConfig {}, runs);
    }
    guard ui::bake(atlas) else { abort(str("ui: ", ui::error())); }
    let size = ui::atlas_size(atlas);
    // The atlas's v is a texel row over its height, which Nuklear rounds up to a power of
    // two; the glyphs' rows are kept whole, and the texture cut below the lowest.
    var rows = 0;
    for face in gui::FACES {
        let info = ui::info(fonts[face]);
        let f .= g.faces[face];
        f.size = info.height;
        f.ascent = info.ascent;
        f.descent = info.descent;
        for i in gui::MAX_GLYPHS {
            // A character a face doesn't hold comes back as its fallback, '?'.
            let gl, own = ui::find_glyph(fonts[face], gui::glyph_char(i) as u32);
            let v0 = floor(gl.v0 * size.y + 0.5);
            let v1 = floor(gl.v1 * size.y + 0.5);
            rows = max(rows, v1 as i64);
            f.glyphs[i] = gui::Glyph { box: float4 { gl.x0, gl.y0, gl.x1, gl.y1 },
                                       uv: float4 { gl.u0, v0, gl.u1, v1 }, advance: gl.xadvance };
        }
    }
    // One more row, empty as the packer's padding left it, so filtering at the lowest
    // glyph's edge reads what it read in the whole atlas.
    let h = min(rows + 1, size.y);
    for face in gui::FACES {
        for &gl in g.faces[face].glyphs {
            gl.uv.y = gl.uv.y / h;
            gl.uv.w = gl.uv.w / h;
        }
    }
    // The coverage is the RGBA image's alpha (Nuklear bakes white glyphs), packed in place.
    var px = ui::atlas_pixels(atlas);
    let n = size.x * h;
    for i in n { px[i] = px[4 * i + 3]; }
    ui::destroy(atlas);
    return px, int2 { size.x, h as i32 };
}
