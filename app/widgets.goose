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
import badges from "../badges";

// width, height in pixels, z: 1 when there is a photograph; and the board's rect (x, y,
// size, corner radius) where a transition hides the UI, size 0 at rest.
struct View { screen: float4, hole: float4 }

let VERT = """
    layout(std430, set = 0, binding = 0) readonly buffer Quads { vec4 q[]; };
    layout(set = 1, binding = 0) uniform View { vec4 screen; vec4 hole; };
    layout(location = 0) out vec2 v_px;
    layout(location = 1) flat out vec4 v_rect;
    layout(location = 2) flat out vec4 v_color;
    layout(location = 3) flat out vec4 v_look;
    layout(location = 4) flat out vec4 v_extra;
    void main() {
        int i = gl_InstanceIndex * 4;
        vec4 rect = q[i];
        vec4 look = q[i + 2];
        vec4 extra = q[i + 3];
        // Room round the rect for the shadow: glass casts one 30 dp down, a tile 12 dp, a
        // face 12 dp and its glow 26 dp round it.
        int kind = int(look.x);
        // A glyph is drawn exactly over its rect, a texel to a pixel.
        float m = (kind == 0 ? 48.0 : kind == 1 ? 20.0 : kind == 8 ? 28.0 : kind == 4 ? 0.0 : 1.0) * extra.x;
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
    layout(set = 2, binding = 1) uniform sampler2D atlas;
    layout(set = 2, binding = 2) uniform sampler2D thumbs;   // four seasons, stacked
    layout(set = 2, binding = 3) uniform sampler2D badges;   // the animals' distances, stacked
    layout(set = 3, binding = 1) uniform View { vec4 screen; vec4 hole; };
    float cover(float d) { return clamp(0.5 - d, 0.0, 1.0); }
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
    // Eight rays from radius a to b round the origin: the four axes and the diagonals.
    float rays(vec2 q, float a, float b) {
        vec2 s = abs(q);
        float d = seg(vec2(max(s.x, s.y), min(s.x, s.y)), vec2(a, 0.0), vec2(b, 0.0));
        vec2 r = vec2(s.x + s.y, abs(s.x - s.y)) * 0.70710678;
        return min(d, seg(r, vec2(a, 0.0), vec2(b, 0.0)));
    }
    // The signed distance to Lucide's five-pointed star, negative inside.
    float star(vec2 p) {
        const vec2 v[10] = vec2[](vec2(12.0, 2.0), vec2(15.1, 8.3), vec2(22.0, 9.3), vec2(17.0, 14.1),
                                  vec2(18.2, 21.0), vec2(12.0, 17.8), vec2(5.8, 21.0), vec2(7.0, 14.1),
                                  vec2(2.0, 9.3), vec2(8.9, 8.3));
        float d = 1e9;
        float s = 1.0;
        for (int i = 0, j = 9; i < 10; j = i, i++) {
            vec2 e = v[j] - v[i];
            vec2 w = p - v[i];
            vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
            d = min(d, dot(b, b));
            bvec3 c = bvec3(p.y >= v[i].y, p.y < v[j].y, e.x * w.y > e.y * w.x);
            if (all(c) || all(not(c))) s = -s;
        }
        return s * sqrt(d);
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
        // Filled shapes give their signed distance plus half a stroke.
        if (k == 5) {           // move hints: four solid dots of radius 2.2
            vec2 q = vec2(p.x < 12.0 ? 7.0 : 17.0, p.y < 12.0 ? 7.0 : 17.0);
            return length(p - q) - 1.0;
        }
        if (k == 6) {           // next: an arrow right
            float d = seg(p, vec2(5.0, 12.0), vec2(19.0, 12.0));
            return min(d, min(seg(p, vec2(13.0, 6.0), vec2(19.0, 12.0)), seg(p, vec2(19.0, 12.0), vec2(13.0, 18.0))));
        }
        if (k == 7) {           // a friend: two figures, the second behind the first
            float s = length(p - vec2(8.5, 7.5)) - 3.6;
            s = min(s, max(length(p - vec2(8.5, 20.5)) - 7.0, p.y - 20.5));
            s = min(s, length(p - vec2(16.5, 8.3)) - 3.1);
            float back = max(length(p - vec2(16.22, 19.97)) - 6.3, 8.6 - length(p - vec2(8.75, 18.9)));
            return min(s, max(back, p.y - 20.5)) + 1.2;
        }
        if (k == 8) {           // the computer: a robot head
            float d = abs(box(p, vec2(12.0, 11.0), vec2(8.0, 5.0), 3.5));
            d = min(d, seg(p, vec2(12.0, 6.0), vec2(12.0, 3.5)));
            float s = length(p - vec2(12.0, 2.6)) - 1.3;
            s = min(s, min(length(p - vec2(9.0, 11.0)), length(p - vec2(15.0, 11.0))) - 1.4);
            return min(d, s + 1.2);
        }
        if (k == 9) {           // puzzles: a jigsaw piece
            float s = box(p, vec2(11.0, 14.0), vec2(7.0, 7.0), 0.0);
            s = min(s, min(length(p - vec2(11.0, 7.0)), length(p - vec2(18.0, 14.0))) - 2.8);
            s = max(s, 2.6 - length(p - vec2(4.0, 13.9)));
            return s + 1.2;
        }
        if (k == 10) {          // settings: a gear of two rings and eight spokes
            vec2 q = p - 12.0;
            return min(min(abs(length(q) - 3.2), abs(length(q) - 6.5)), rays(q, 6.5, 9.5));
        }
        if (k == 11) {          // the background: a sun
            vec2 q = p - 12.0;
            return min(abs(length(q) - 4.0), rays(q, 7.5, 10.0));
        }
        if (k == 12) {          // move hints: a target
            vec2 q = p - 12.0;
            float d = min(abs(length(q) - 7.0), length(q) - 0.8);
            vec2 a = abs(q);
            return min(d, seg(vec2(max(a.x, a.y), min(a.x, a.y)), vec2(6.0, 0.0), vec2(10.0, 0.0)));
        }
        if (k == 13) {          // the language: a globe
            vec2 q = p - 12.0;
            float d = min(abs(length(q) - 9.0), seg(p, vec2(3.0, 12.0), vec2(21.0, 12.0)));
            return min(d, abs(length(q / vec2(3.8, 9.0)) - 1.0) * 3.8);
        }
        if (k == 14) {          // home: a house with a door
            float d = min(seg(p, vec2(3.5, 10.5), vec2(12.0, 3.5)), seg(p, vec2(12.0, 3.5), vec2(20.5, 10.5)));
            d = min(d, min(seg(p, vec2(5.5, 9.0), vec2(5.5, 20.5)), seg(p, vec2(18.5, 9.0), vec2(18.5, 20.5))));
            d = min(d, seg(p, vec2(5.5, 20.5), vec2(18.5, 20.5)));
            d = min(d, min(seg(p, vec2(10.0, 20.5), vec2(10.0, 14.5)), seg(p, vec2(14.0, 20.5), vec2(14.0, 14.5))));
            return min(d, seg(p, vec2(10.0, 14.5), vec2(14.0, 14.5)));
        }
        if (k == 15) {          // no clock: a stopwatch
            float d = abs(length(p - vec2(12.0, 13.0)) - 8.0);
            d = min(d, min(seg(p, vec2(12.0, 9.0), vec2(12.0, 13.0)), seg(p, vec2(12.0, 13.0), vec2(14.5, 15.5))));
            return min(d, seg(p, vec2(9.5, 2.5), vec2(14.5, 2.5)));
        }
        if (k == 16 || k == 17) {   // a star, filled (won) or outlined (still at stake)
            float s = star(p);
            return k == 16 ? s + 1.2 : abs(s);
        }
        if (k == 18) {          // a shut theme: a padlock
            float d = abs(box(p, vec2(12.0, 16.0), vec2(7.0, 5.0), 2.0));
            d = min(d, min(seg(p, vec2(8.0, 11.0), vec2(8.0, 7.0)), seg(p, vec2(16.0, 7.0), vec2(16.0, 11.0))));
            return min(d, arc(p, vec2(12.0, 7.0), 4.0, 3.1415927, 3.1415927));
        }
        if (k == 19) {          // become a king: a crown on a line
            const vec2 c[7] = vec2[](vec2(3.0, 17.0), vec2(2.0, 7.0), vec2(7.0, 11.0), vec2(12.0, 4.0),
                                     vec2(17.0, 11.0), vec2(22.0, 7.0), vec2(21.0, 17.0));
            float d = seg(p, c[6], c[0]);
            for (int i = 0; i < 6; i++) d = min(d, seg(p, c[i], c[i + 1]));
            return min(d, seg(p, vec2(3.0, 20.5), vec2(21.0, 20.5)));
        }
        if (k == 20) {          // the only safe move: a shield, its curves as three segments each
            const vec2 c[11] = vec2[](vec2(12.0, 2.5), vec2(4.0, 5.5), vec2(4.0, 11.5), vec2(5.05, 16.0),
                                      vec2(7.88, 19.4), vec2(12.0, 21.5), vec2(16.12, 19.4), vec2(18.95, 16.0),
                                      vec2(20.0, 11.5), vec2(20.0, 5.5), vec2(12.0, 2.5));
            float d = 1e9;
            for (int i = 0; i < 10; i++) d = min(d, seg(p, c[i], c[i + 1]));
            return d;
        }
        if (k == 21) {          // home's way out: an X
            return min(seg(p, vec2(6.0, 6.0), vec2(18.0, 18.0)), seg(p, vec2(18.0, 6.0), vec2(6.0, 18.0)));
        }
        if (k == 22) {          // a new player: +
            return min(seg(p, vec2(12.0, 5.0), vec2(12.0, 19.0)), seg(p, vec2(5.0, 12.0), vec2(19.0, 12.0)));
        }
        if (k == 23) {          // editing: a pencil
            float d = min(seg(p, vec2(4.0, 20.0), vec2(5.0, 15.5)), seg(p, vec2(5.0, 15.5), vec2(15.5, 5.0)));
            d = min(d, arc(p, vec2(17.0, 6.5), 2.12, -2.3561945, 3.1415927));
            d = min(d, min(seg(p, vec2(18.5, 8.0), vec2(8.0, 18.5)), seg(p, vec2(8.0, 18.5), vec2(4.0, 20.0))));
            return min(d, seg(p, vec2(13.5, 7.0), vec2(16.5, 10.0)));
        }
        if (k == 24) {          // done: a check
            return min(seg(p, vec2(4.5, 12.5), vec2(9.5, 17.5)), seg(p, vec2(9.5, 17.5), vec2(19.5, 6.5)));
        }
        if (k == 25) {          // removing: a bin
            float d = seg(p, vec2(4.0, 7.0), vec2(20.0, 7.0));
            d = min(d, min(seg(p, vec2(9.5, 7.0), vec2(9.5, 4.5)), seg(p, vec2(9.5, 4.5), vec2(14.5, 4.5))));
            d = min(d, seg(p, vec2(14.5, 4.5), vec2(14.5, 7.0)));
            d = min(d, min(seg(p, vec2(6.0, 7.0), vec2(7.0, 20.0)), seg(p, vec2(7.0, 20.0), vec2(17.0, 20.0))));
            return min(d, seg(p, vec2(17.0, 20.0), vec2(18.0, 7.0)));
        }
        if (k == 26) {          // Learn: an open book, its pages' curves as two segments each
            const vec2 c[11] = vec2[](vec2(12.0, 6.5), vec2(7.5, 4.5), vec2(3.0, 4.8), vec2(3.0, 18.2),
                                      vec2(7.5, 18.2), vec2(12.0, 19.8), vec2(16.5, 18.2), vec2(21.0, 18.2),
                                      vec2(21.0, 4.8), vec2(16.5, 4.5), vec2(12.0, 6.5));
            float d = seg(p, vec2(12.0, 6.5), vec2(12.0, 19.8));
            for (int i = 0; i < 10; i++) d = min(d, seg(p, c[i], c[i + 1]));
            return d;
        }
        if (k == 27) {          // captures: two men, a double jump over them, and its arrowhead
            const vec2 c[9] = vec2[](vec2(2.5, 15.5), vec2(4.0, 11.0), vec2(7.2, 9.4), vec2(10.5, 11.0),
                                     vec2(12.0, 14.5), vec2(13.5, 11.0), vec2(16.8, 9.4), vec2(20.0, 11.0),
                                     vec2(21.5, 15.5));
            float d = min(abs(length(p - vec2(7.5, 18.0)) - 2.8), abs(length(p - vec2(16.5, 18.0)) - 2.8));
            for (int i = 0; i < 8; i++) d = min(d, seg(p, c[i], c[i + 1]));
            return min(d, min(seg(p, vec2(19.0, 14.2), vec2(21.5, 15.8)), seg(p, vec2(21.5, 15.8), vec2(22.8, 13.1))));
        }
        if (k == 28) {          // king shots: a crown in a ring
            const vec2 c[7] = vec2[](vec2(7.0, 16.2), vec2(6.3, 9.6), vec2(9.4, 12.1), vec2(12.0, 8.0),
                                     vec2(14.6, 12.1), vec2(17.7, 9.6), vec2(17.0, 16.2));
            float d = min(abs(length(p - 12.0) - 9.5), seg(p, c[6], c[0]));
            for (int i = 0; i < 6; i++) d = min(d, seg(p, c[i], c[i + 1]));
            return d;
        }
        if (k >= 29 && k <= 31) {   // a level: three rising bars, the first k - 28 filled
            float d = 1e9;
            for (int i = 0; i < 3; i++) {
                float top = 14.0 - 5.0 * float(i);
                float b = box(p, vec2(5.3 + 6.7 * float(i), 0.5 * (top + 21.0)), vec2(2.3, 0.5 * (21.0 - top)), 1.0);
                d = min(d, i < k - 28 ? b + 1.2 : abs(b));
            }
            return d;
        }
        return 1e9;
    }
    // A player's badge's animal (badges/badges.goose): its signed distance at f, in a
    // piece's radii, negative inside, 1 outside its cell. The cell (badges::CELL texels a
    // side, badges::SPREAD texels of distance either side of the edge, badges::COUNT
    // cells stacked) spans 2 BADGE_HALF radii, the crown's room on home's king.
    const float BADGE_CELL = 96.0;
    const float BADGE_SPREAD = 12.0;
    const float BADGE_COUNT = 6.0;
    const float BADGE_HALF = 0.56;
    float animal(int k, vec2 f) {
        vec2 t = f / (2.0 * BADGE_HALF) + 0.5;
        if (t.x < 0.0 || t.y < 0.0 || t.x > 1.0 || t.y > 1.0) return 1.0;
        t.y = clamp(t.y, 0.5 / BADGE_CELL, 1.0 - 0.5 / BADGE_CELL);
        float v = textureLod(badges, vec2(t.x, (float(k) + t.y) / BADGE_COUNT), 0.0).r;
        return (v * 255.0 - 128.0) / 127.0 * BADGE_SPREAD * 2.0 * BADGE_HALF / BADGE_CELL;
    }
    // A player's badge (task 038): home's king as the light pieces are now (draw's
    // man_top), the animal in the crown's place and colour, flat and bold as the crown is,
    // with only a faint shadow inside its upper edge, as if set a hair into the top. f in
    // the piece's radii, w a pixel in them. The one place the badge is drawn.
    vec3 badge(int k, vec2 f, float w) {
        float r = length(f);
        vec3 col = man_top(w_face.rgb, f, r, f / max(r, 0.001), false);
        float a = animal(k, f);
        if (a > 0.5) return col;
        float up = animal(k, f - vec2(0.0, 0.035));
        float lip = clamp(up / 0.035 + 1.0, 0.0, 1.0);
        vec3 mark = mix(crown_w.rgb, crown_w.rgb * crown_w.rgb * 0.85, 0.3 * lip);
        return mix(col, mark, clamp(0.5 - a / w, 0.0, 1.0));
    }
    // How far along a rounded rect's outline the point nearest q is, clockwise from its
    // top's middle (y down), the rect's inner half size a (its half size less r) and its
    // corners' radius r.
    float along(vec2 q, vec2 a, float r) {
        float qa = 1.5707963 * r;
        float total = 4.0 * (a.x + a.y + qa);
        vec2 d = q - clamp(q, -a, a);
        if (d.x == 0.0 && d.y == 0.0) {
            vec2 m = a - abs(q);
            if (m.y < m.x) d.y = q.y < 0.0 ? -1.0 : 1.0;
            else d.x = q.x < 0.0 ? -1.0 : 1.0;
        }
        if (d.x == 0.0 && d.y < 0.0) return q.x >= 0.0 ? q.x : total + q.x;
        if (d.x > 0.0 && d.y < 0.0) return a.x + r * atan(d.x, -d.y);
        if (d.x > 0.0 && d.y == 0.0) return a.x + qa + q.y + a.y;
        if (d.x > 0.0) return a.x + qa + 2.0 * a.y + r * atan(d.y, d.x);
        if (d.x == 0.0) return 2.0 * a.x + 2.0 * qa + 2.0 * a.y - q.x;
        if (d.y > 0.0) return 3.0 * a.x + 2.0 * qa + 2.0 * a.y + r * atan(-d.x, d.y);
        if (d.y == 0.0) return 3.0 * a.x + 3.0 * qa + 3.0 * a.y - q.y;
        return 3.0 * a.x + 3.0 * qa + 4.0 * a.y + r * atan(-d.y, -d.x);
    }
    void shade() {
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
        // plain, primary, toggle on, toggle off, quiet, row, primary row, choice on and
        // off, clock running, waiting, and low
        int style = int(v_extra.y);
        if (kind == 1) {
            // A glass tile: white at 10%, 14 points more pressed and scaled to 0.96; an
            // inset light border and top highlight; a small shadow. A primary tile is the
            // glow color at 22%. A toggle has no highlight: on, the glow color at 26%
            // with a glow border; off, white at 8% with a border at 18%; a quiet tile
            // too. A menu row has no border or shadow: clear, or the glow color at 24%. A
            // choice has no shadow either: on, the glow color at 22% with a 2 dp glow
            // border; off, white at 10% with a border at 12%. A clock has no shadow either:
            // running, the glow color at 18% with a 2 dp glow border; waiting, white at 6%
            // with a border at 12%; low, the forced-capture red at 16% with a 2 dp red
            // border. color.a dims a tile.
            float pr = v_look.w;
            bool flat = style >= 5;
            if (!flat) h *= 1.0 - 0.04 * pr;
            float d = box(p, c, h, r);
            if (!flat) over(vec3(0.0), 0.5 * shadow(p, c, h, r, 6.0 * u, 14.0 * u, -8.0 * u) * (1.0 - cover(d)));
            float a = cover(d) * (v_color.a > 0.0 ? v_color.a : 1.0);
            vec3 red = vec3(1.0, 0.353, 0.29);
            bool lit = style == 1 || style == 2 || style == 6 || style == 7 || style == 9;
            vec3 fc = style == 11 ? red : lit ? glow.rgb : vec3(1.0);
            bool bare = v_look.z > 0.5;         // a bare icon's press: white at 10%, a faint ring
            float fa = bare ? 0.10 * pr : (style == 1 ? 0.22 : style == 2 ? 0.26 : style == 3 || style == 4 ? 0.08
                        : style == 5 ? 0.0 : style == 6 ? 0.24 : style == 7 ? 0.22 : style == 9 ? 0.18
                        : style == 10 ? 0.06 : style == 11 ? 0.16 : 0.10) + 0.14 * pr);
            vec4 tile = vec4(fc * fa, fa);
            bool wide = style == 7 || style == 9 || style == 11;
            float ea = style == 5 || style == 6 ? 0.0 : style == 2 || wide ? 1.0 : style == 8 || style == 10 ? 0.12
                       : style >= 3 ? 0.18 : 0.2;
            if (bare) ea = 0.22 * pr;
            float edge = ea * (1.0 - cover(d + (wide ? 2.0 : 1.0) * u));
            vec3 ec = style == 11 ? red : style == 2 || style == 7 || style == 9 ? glow.rgb : vec3(1.0);
            tile = vec4(ec * edge, edge) + tile * (1.0 - edge);
            float hl = style >= 2 ? 0.0 : 0.18 * top_line(p, c, h, r, u);
            tile = vec4(vec3(hl), hl) + tile * (1.0 - hl);
            acc = tile * a + acc * (1.0 - tile.a * a);
            result = acc;
            return;
        }
        if (kind == 2) {
            // A line icon: strokes 2.4 units (look.y sets another) of its 24-unit grid wide, as the prototypes'
            // SVGs draw them, round caps, in the text color.
            vec2 q = (p - v_rect.xy) / v_rect.zw * 24.0;
            float px = 24.0 / v_rect.z;         // one pixel in grid units
            float d = icon(int(v_look.z), q) - (r > 0.0 ? 0.5 * r : 1.2);     // look.y: the stroke, if set
            float a = clamp(0.5 - d / px, 0.0, 1.0) * (style == 3 ? 0.45 : 1.0) * v_color.a;
            // CLOCK_LOW: the forced-capture red toward the text color (removing a player).
            vec3 ic = style == 2 ? glow.rgb : style == 11 ? mix(vec3(1.0, 0.353, 0.29), text.rgb, 0.45) : text.rgb;
            result = vec4(ic * a, a);
            return;
        }
        if (kind == 5) {
            // A picture: a season's thumbnail, cover-cropped; or for -1 the glow at 18%
            // mixed into white at 6% (CSS color-mix), which leaves it 23% opaque.
            float a = cover(box(p, c, h, r)) * v_color.a;
            int k = int(v_look.z);
            vec2 t = (p - v_rect.xy) / v_rect.zw;
            if (k < 0) a *= 0.23;
            vec3 pc = k >= 0 ? texture(thumbs, vec2(t.x, (float(k) + t.y) * 0.25)).rgb
                             : mix(vec3(1.0), glow.rgb, 0.78);
            result = vec4(pc * a, a);
            return;
        }
        if (kind == 4) {
            // A glyph: the atlas's coverage (R8) over the quad, in the text color.
            vec2 t = (p - v_rect.xy) / v_rect.zw;
            float a = texture(atlas, mix(v_look.yz, vec2(v_look.w, v_extra.y), t)).r * v_color.a;
            result = vec4((mod(v_extra.z, 2.0) > 0.5 ? v_color.rgb : text.rgb) * a, a);
            return;
        }
        if (kind == 7) {
            // A hold's ring: a 4 dp outline 2 dp inside the tile, filled clockwise from its
            // top's middle as far as look.z, in the glow color or the forced-capture red.
            float w = 4.0 * u;
            vec2 hh = h - 2.0 * u;
            float rr = max(r - 2.0 * u, 0.0);
            vec2 a = max(hh - rr, 0.0);
            float total = 4.0 * (a.x + a.y) + 6.2831853 * rr;
            float on = clamp((v_look.z * total - along(p - c, a, rr)) / u + 0.5, 0.0, 1.0);
            float al = cover(abs(box(p, c, hh, rr)) - 0.5 * w) * on;
            vec3 rc = v_extra.y > 0.5 ? vec3(1.0, 0.353, 0.29) : glow.rgb;
            result = vec4(rc * al, al);
            return;
        }
        if (kind == 8) {
            // A player's face: the badge (badge()), a man as on the board with its side
            // and short shadow, its top and side filling the disc. Lit, a 4 dp glow ring
            // and a 22 dp glow at 50% round the disc. The face for + is a faint disc with a
            // 2 dp border. color.a dims it (a picture another player has).
            float rad = 0.5 * min(v_rect.z, v_rect.w);
            float d = length(p - c) - rad;
            float fa = v_color.a;
            int k = int(v_look.z);
            if (v_look.w > 0.5) {
                over(glow.rgb, 0.5 * shadow(p, c, vec2(rad), rad, 0.0, 22.0 * u, 0.0) * fa);
                over(glow.rgb, cover(d - 4.0 * u) * fa);
            }
            if (k < 0) {
                over(vec3(1.0), 0.08 * cover(d) * fa);
                over(vec3(1.0), 0.35 * (cover(d) - cover(d + 2.0 * u)) * fa);
                result = acc;
                return;
            }
            // The man's side 0.12 of its radius deep, about a board piece's; its top
            // and side together the disc's height.
            float side = 0.12;
            float pr = rad / (1.0 + 0.5 * side);
            vec2 f = (p - c + vec2(0.0, 0.5 * side * pr)) / pr;
            float w = 1.0 / pr;
            float d0 = length(f - vec2(0.04, 0.25)) - 1.0;
            over(vec3(0.0), 0.4 * (1.0 - smoothstep(-0.32, 0.32, d0)) * fa);
            float d1 = length(f - vec2(0.0, 0.06 + side)) - 1.0;
            over(vec3(0.0), 0.3 * (1.0 - smoothstep(-0.08, 0.06, d1)) * fa);
            vec3 face = w_face.rgb;
            float sy = f.y - clamp(f.y, 0.0, side);
            float rim = sqrt(max(1.0 - f.x * f.x, 0.0));
            float foot = clamp((f.y - rim) / side, 0.0, 1.0);
            vec3 sc = face * face * 0.92 * (0.8 + 0.25 * rim) * (1.0 - 0.25 * foot);
            over(sc, clamp(0.5 - (length(vec2(f.x, sy)) - 1.0) / w, 0.0, 1.0) * fa);
            over(badge(k, f, w), clamp(0.5 - (length(f) - 1.0) / w, 0.0, 1.0) * fa);
            result = acc;
            return;
        }
        if (kind == 6) {
            // A small board at the start: the theme's squares, rounded corners, and
            // men on the first rows of each side, discs 76% of a square.
            float a = cover(box(p, c, h, r)) * v_color.a;
            float n = v_look.z;
            vec2 q = (p - v_rect.xy) / v_rect.zw * n;
            vec2 cell = floor(q);
            float row = n - 1.0 - cell.y;
            bool dk = mod(cell.x + row, 2.0) < 0.5;
            vec3 s = dk ? dark.rgb : light.rgb;
            if (dk && (row < v_look.w || row >= n - v_look.w)) {
                float d = (length(fract(q) - 0.5) - 0.38) * v_rect.z / n;
                s = mix(s, row < v_look.w ? w_face.rgb : b_face.rgb, cover(d));
            }
            result = vec4(s * a, a);
            return;
        }
        // A plain rounded rect, in its color or (look.z 1) the glow color.
        float a = cover(box(p, c, h, r)) * v_color.a;
        result = vec4((v_look.z > 0.5 ? glow.rgb : v_color.rgb) * a, a);
    }
    // Each quad as its kind draws it, faded with its layer (a screen in a transition), and
    // in a transition hidden where the board passes, unless it lies on the board (a win's
    // card, extra.z from 2).
    void main() {
        shade();
        result *= 1.0 - v_extra.w;
        if (hole.z > 0.0 && v_extra.z < 1.5) {
            float h = 0.5 * hole.z;
            result *= 1.0 - cover(box(v_px, hole.xy + h, vec2(h), hole.w));
        }
    }
    """;

struct Widgets {
    pipeline: gfx::Pipeline,
    quads:    gfx::Buffer,
    upload:   gui::Quad[gui::MAX_QUADS],
    atlas:    gfx::Texture,     // the text's glyphs (text.goose), or 0 before they're baked
    thumbs:   gfx::Texture,     // the seasons' thumbnails (scene.goose), or 0 until loaded
    badges:   gfx::Texture,     // the badges' animals' distances, baked at start
}

fn new() -> Widgets {
    var w = Widgets {
        pipeline: gfx::pipeline(embed_shader("vert", draw::SHARED_BLOCK, VERT),
                                embed_shader("frag", draw::THEME_BLOCK, draw::SHARED_BLOCK, draw::MAN_BLOCK, FRAG),
                                gfx::PipelineDesc { blend: gfx::BLEND_PREMULTIPLIED }),
        quads:  gfx::Buffer { 0 },
        upload: [gui::Quad {}; gui::MAX_QUADS],
        atlas:  gfx::Texture { 0 },
        thumbs: gfx::Texture { 0 },
        badges: gfx::Texture { 0 },
    };
    w.quads = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(w.upload));
    w.badges = bake_badges();
    return w;
}

// The badges' animals from their SVG files (badges.goose), each baked into its cell of a
// distance texture the shader carves from, once at start (about 54 KB, a few ms). A file
// that can't be read leaves its cell empty, so that badge is a plain man, and says so.
fn bake_badges() -> gfx::Texture {
    let n = badges::CELL * badges::CELL;
    var px: u8[>..] = [];
    for i in badges::COUNT * n { px.push(255); }
    var shapes: badges::Shape[>..] = [];
    let sh .= shapes.push(badges::Shape {});
    for k in badges::COUNT {
        guard badges::read(badges::svg(k), sh) else {
            print("badges: ", badges::NAMES[k], ".svg can't be read");
            continue;
        }
        if sh.full { print("badges: ", badges::NAMES[k], ".svg has more than ", badges::MAX_SEGS, " pieces"); }
        badges::bake(sh, px[k * n..(k + 1) * n]);
    }
    let t = gfx::texture2d(badges::CELL, badges::COUNT * badges::CELL, gfx::R8, gfx::SAMPLED);
    gfx::update_texture(t, px[..]);
    return t;
}

// Copies the frame's quads to the GPU: before the pass, as copies happen between passes.
fn upload(w: Widgets&, g: gui::Gui&) {
    for i in g.quads.len { w.upload[i] = g.quads[i]; }
    gfx::update_buffer(w.quads, bytes_of(w.upload));
}

// Draws the frame's quads in the open pass, over what is there, none inside `hole` but
// those on the board (gui::on_board).
fn frame(w: Widgets&, g: gui::Gui&, s: scene::Scene&, t: theme::Theme, width: f32, height: f32, hole: float4) {
    guard g.quads.len > 0 else { return; }
    let view = View { screen: float4 { width, height, if s.has { 1.0 } else { 0.0 }, 0.0 }, hole: hole };
    gfx::bind(w.pipeline);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, w.quads);
    gfx::uniforms(gfx::VERTEX, 0, view);
    gfx::uniforms(gfx::FRAGMENT, 0, t);
    gfx::uniforms(gfx::FRAGMENT, 1, view);
    gfx::bind_texture(gfx::FRAGMENT, 0, s.glass, s.sampler);
    gfx::bind_texture(gfx::FRAGMENT, 1, if w.atlas.id != 0 { w.atlas } else { s.glass }, s.sampler);
    gfx::bind_texture(gfx::FRAGMENT, 2, if w.thumbs.id != 0 { w.thumbs } else { s.glass }, s.sampler);
    gfx::bind_texture(gfx::FRAGMENT, 3, w.badges, s.sampler);
    gfx::draw_instanced(6, g.quads.len);
}
