// Drawing the UI layer's quads (gui/): one storage buffer of quads and one instanced
// draw, each quad worked out in the fragment shader as a signed-distance shape
// (docs/architecture/rendering.md, "UI layer", "Scene and glass", "Controls").
namespace widgets;
import std;
import vec;
import gfx;

import gui from "../gui";
import .scene;
import .theme;
import .draw;

struct View { screen: float4 }     // width, height in pixels; x: 1 when there is a photograph

let VERT = """
    layout(std430, set = 0, binding = 0) readonly buffer Quads { vec4 q[]; };
    layout(set = 1, binding = 0) uniform View { vec4 screen; };
    layout(location = 0) out vec2 v_px;
    layout(location = 1) flat out vec4 v_rect;
    layout(location = 2) flat out vec4 v_color;
    layout(location = 3) flat out vec4 v_look;
    layout(location = 4) flat out vec4 v_extra;
    const vec2 CORNERS[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
                                   vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));
    void main() {
        int i = gl_InstanceIndex * 4;
        vec4 rect = q[i];
        vec4 look = q[i + 2];
        vec4 extra = q[i + 3];
        // Room round the rect for the shadow: glass casts one 30 dp down, a tile 12 dp;
        // a spark's glow reaches 12 dp.
        int kind = int(look.x);
        float m = (kind == 0 ? 48.0 : kind == 1 ? 20.0 : kind == 4 ? 16.0 : 1.0) * extra.x;
        vec2 px = mix(rect.xy - m, rect.xy + rect.zw + m, CORNERS[gl_VertexIndex]);
        gl_Position = vec4(px.x / screen.x * 2.0 - 1.0, 1.0 - px.y / screen.y * 2.0, 0.0, 1.0);
        v_px = px;
        v_rect = rect;
        v_color = q[i + 1];
        v_look = look;
        v_extra = extra;
    }
    """;

let FRAG = """
    layout(location = 0) in vec2 v_px;
    layout(location = 1) flat in vec4 v_rect;
    layout(location = 2) flat in vec4 v_color;
    layout(location = 3) flat in vec4 v_look;
    layout(location = 4) flat in vec4 v_extra;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D glass_copy;
    layout(set = 3, binding = 1) uniform View { vec4 screen; };
    vec4 acc = vec4(0.0);
    void over(vec3 c, float a) { acc = vec4(c * a, a) + acc * (1.0 - a); }
    float cover(float d) { return clamp(0.5 - d, 0.0, 1.0); }
    float box(vec2 p, vec2 c, vec2 h, float r) {
        vec2 q = abs(p - c) - h + r;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    }
    // A CSS box-shadow under a rounded rect: offset y, blur, spread, all in pixels.
    float shadow(vec2 p, vec2 c, vec2 h, float r, float y, float blur, float spread) {
        float d = box(p, c + vec2(0.0, y), h + spread, max(r + spread, 0.0));
        return 1.0 - smoothstep(-blur, blur, d);
    }
    // A CSS `inset 0 2px 0 -1px` highlight: a band along the top edge, thinning down the
    // sides.
    float top_line(vec2 p, vec2 c, vec2 h, float r, float u) {
        return cover(box(p, c, h, r)) * (1.0 - cover(box(p, c + vec2(0.0, 2.0 * u), h - u, max(r - u, 0.0))));
    }
    // Distances to an icon's strokes, on Lucide's 24-unit grid.
    float seg(vec2 p, vec2 a, vec2 b) {
        vec2 pa = p - a, ba = b - a;
        return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
    }
    // An arc of radius r round c from angle a0 through `sweep` radians, angles as atan
    // gives them with y down.
    float arc(vec2 p, vec2 c, float r, float a0, float sweep) {
        vec2 d = p - c;
        float t = mod(atan(d.y, d.x) - a0, 6.2831853);
        if (t <= sweep) return abs(length(d) - r);
        vec2 e0 = c + r * vec2(cos(a0), sin(a0));
        vec2 e1 = c + r * vec2(cos(a0 + sweep), sin(a0 + sweep));
        return min(length(p - e0), length(p - e1));
    }
    float icon(int k, vec2 p) {
        if (k == 1) {           // undo
            float d = min(seg(p, vec2(9.0, 14.0), vec2(4.0, 9.0)), seg(p, vec2(4.0, 9.0), vec2(9.0, 4.0)));
            d = min(d, seg(p, vec2(4.0, 9.0), vec2(14.5, 9.0)));
            d = min(d, arc(p, vec2(14.5, 14.5), 5.5, -1.5707963, 3.1415927));
            return min(d, seg(p, vec2(14.5, 20.0), vec2(11.0, 20.0)));
        }
        if (k == 2) {           // hint: a bulb
            float d = arc(p, vec2(12.0, 9.0), 7.0, 2.1816616, 5.0614548);
            d = min(d, min(seg(p, vec2(8.0, 14.7), vec2(9.0, 17.0)), seg(p, vec2(16.0, 14.7), vec2(15.0, 17.0))));
            d = min(d, seg(p, vec2(9.0, 17.0), vec2(15.0, 17.0)));
            d = min(d, seg(p, vec2(9.0, 18.0), vec2(15.0, 18.0)));
            return min(d, seg(p, vec2(10.0, 22.0), vec2(14.0, 22.0)));
        }
        if (k == 3) {           // restart
            float d = arc(p, vec2(12.0, 12.0), 9.0, 3.9828, 5.4420);
            d = min(d, seg(p, vec2(6.0, 5.3), vec2(3.0, 8.0)));
            return min(d, min(seg(p, vec2(3.0, 3.0), vec2(3.0, 8.0)), seg(p, vec2(3.0, 8.0), vec2(8.0, 8.0))));
        }
        if (k == 4) {           // back
            float d = seg(p, vec2(19.0, 12.0), vec2(5.0, 12.0));
            return min(d, min(seg(p, vec2(11.0, 18.0), vec2(5.0, 12.0)), seg(p, vec2(5.0, 12.0), vec2(11.0, 6.0))));
        }
        if (k == 5) {           // move hints: four solid dots of radius 2.2
            vec2 q = vec2(p.x < 12.0 ? 7.0 : 17.0, p.y < 12.0 ? 7.0 : 17.0);
            return length(p - q) - 1.0;
        }
        return 1e9;
    }
    void main() {
        int kind = int(v_look.x);
        float u = v_extra.x;                    // one dp in pixels
        vec2 p = v_px;
        vec2 h = 0.5 * v_rect.zw;
        vec2 c = v_rect.xy + h;
        float r = v_look.y;
        if (kind == 0) {
            // Glass: the scene's glass copy at this place on screen, dimmed and
            // saturated, under the theme's tint, with a light border and top highlight,
            // and a soft shadow outside it.
            float d = box(p, c, h, r);
            float side = max(screen.x, screen.y);
            vec3 g = screen.z > 0.5
                ? texture(glass_copy, (p - 0.5 * (screen.xy - side)) / side).rgb
                : page.rgb;
            float l = dot(g, vec3(0.2126, 0.7152, 0.0722));
            g = max(mix(vec3(l), g, 1.3), 0.0) * text.w;
            g = mix(g, glass.rgb, glass.a);
            g = mix(g, vec3(1.0), 0.12 * top_line(p, c, h, r, u));
            g = mix(g, vec3(1.0), 0.14 * (1.0 - cover(d + u)));
            float a = cover(d);
            float s = 0.55 * shadow(p, c, h, r, 12.0 * u, 32.0 * u, -14.0 * u) * (1.0 - a);
            result = vec4(g * a, a + s);
            return;
        }
        int style = int(v_extra.y);             // plain, primary, toggle on, toggle off
        if (kind == 1) {
            // A glass tile: white at 10%, 14 points more pressed and scaled to 0.96; an
            // inset light border and top highlight; a small shadow. A primary tile is the
            // glow color at 22%. A toggle has no highlight: on, the glow color at 26%
            // with a glow border; off, white at 8% with a border at 18%.
            float pr = v_look.w;
            h *= 1.0 - 0.04 * pr;
            float d = box(p, c, h, r);
            over(vec3(0.0), 0.5 * shadow(p, c, h, r, 6.0 * u, 14.0 * u, -8.0 * u) * (1.0 - cover(d)));
            float a = cover(d);
            vec3 fc = style == 1 || style == 2 ? glow.rgb : vec3(1.0);
            float fa = (style == 1 ? 0.22 : style == 2 ? 0.26 : style == 3 ? 0.08 : 0.10) + 0.14 * pr;
            vec4 tile = vec4(fc * fa, fa);
            float edge = (style == 2 ? 1.0 : style == 3 ? 0.18 : 0.2) * (1.0 - cover(d + u));
            tile = vec4((style == 2 ? glow.rgb : vec3(1.0)) * edge, edge) + tile * (1.0 - edge);
            float hl = style >= 2 ? 0.0 : 0.18 * top_line(p, c, h, r, u);
            tile = vec4(vec3(hl), hl) + tile * (1.0 - hl);
            acc = tile * a + acc * (1.0 - tile.a * a);
            result = acc;
            return;
        }
        if (kind == 2) {
            // A line icon: strokes 2.4 units of its 24-unit grid wide, as the prototypes'
            // SVGs draw them, round caps, in the text color.
            vec2 q = (p - v_rect.xy) / v_rect.zw * 24.0;
            float px = 24.0 / v_rect.z;         // one pixel in grid units
            float d = icon(int(v_look.z), q) - 1.2;
            float a = clamp(0.5 - d / px, 0.0, 1.0) * (style == 3 ? 0.45 : 1.0);
            vec3 ic = style == 2 ? glow.rgb : text.rgb;
            result = vec4(ic * a, a);
            return;
        }
        if (kind == 4) {
            // A spark: a disc in the glow color with a 12 dp glow round it.
            float d = length(p - c) - r;
            over(glow.rgb, 0.8 * (1.0 - smoothstep(-12.0 * u, 12.0 * u, d)));
            over(glow.rgb, cover(d));
            result = acc * v_color.a;
            return;
        }
        // A plain rounded rect.
        float a = cover(box(p, c, h, r)) * v_color.a;
        result = vec4(v_color.rgb * a, a);
    }
    """;

struct Widgets {
    pipeline: gfx::Pipeline,
    quads:    gfx::Buffer,
    upload:   gui::Quad[gui::MAX_QUADS],
}

fn new() -> Widgets {
    var w = Widgets {
        pipeline: gfx::pipeline(embed_shader("vert", VERT), embed_shader("frag", draw::THEME_BLOCK, FRAG),
                                gfx::PipelineDesc { blend: gfx::BLEND_PREMULTIPLIED }),
        quads:  gfx::Buffer { 0 },
        upload: [gui::Quad {}; gui::MAX_QUADS],
    };
    w.quads = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(w.upload));
    return w;
}

// Copies the frame's quads to the GPU: before the pass, as copies happen between passes.
fn upload(w: Widgets&, g: gui::Gui&) {
    for i in g.quads.len { w.upload[i] = g.quads[i]; }
    gfx::update_buffer(w.quads, bytes_of(w.upload));
}

// Draws the frame's quads in the open pass, over what is there.
fn frame(w: Widgets&, g: gui::Gui&, s: scene::Scene&, t: theme::Theme, width: f32, height: f32) {
    guard g.quads.len > 0 else { return; }
    let view = View { screen: float4 { width, height, if s.has { 1.0 } else { 0.0 }, 0.0 } };
    gfx::bind(w.pipeline);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, w.quads);
    gfx::uniforms(gfx::VERTEX, 0, view);
    gfx::uniforms(gfx::FRAGMENT, 0, t);
    gfx::uniforms(gfx::FRAGMENT, 1, view);
    gfx::bind_texture(gfx::FRAGMENT, 0, s.glass, s.sampler);
    gfx::draw_instanced(6, g.quads.len);
}
