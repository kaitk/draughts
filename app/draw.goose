// Drawing the board: one full-screen pass for the page, the frame, and the squares with
// their marks, worked out per pixel; then every piece in one instanced draw that pulls
// its piece from a storage buffer (docs/architecture/rendering.md). Both light the scene
// with one key light from the top left ("Light").
namespace draw;
import std;
import vec;
import gfx;

import board from "../board";

// The board pass's uniforms, std140.
struct BoardUniforms {
    screen: float4,     // width, height in pixels, time, squares per side
    rect:   float4,     // the board with its frame: x, y, size, corner radius
    inner:  float4,     // the squares: x, y, size, one square
    marks:  board::Marks,
}

struct View { screen: float4 }     // width, height, the disc's side depth in pixels
struct Clock { time: float4 }      // seconds

let THEME_BLOCK = """
    layout(set = 3, binding = 0) uniform Theme {
        vec4 light; vec4 dark; vec4 frame; vec4 w_face; vec4 b_face; vec4 crown_w;
        vec4 glow; vec4 page; vec4 kind;
    };
    """;

let FULL_VERT = """
    layout(location = 0) out vec2 v_uv;
    void main() {
        vec2 p = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
        v_uv = p;
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """;

let BOARD_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 3, binding = 1) uniform BoardUniforms {
        vec4 screen; vec4 rect; vec4 inner; uvec4 last; uvec4 target; uvec4 via;
    };
    float box(vec2 p, vec2 c, vec2 h, float r) {
        vec2 q = abs(p - c) - h + r;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    }
    bool has(uvec4 m, int n) {
        uint w = n < 32 ? m.x : n < 64 ? m.y : n < 96 ? m.z : m.w;
        return ((w >> uint(n & 31)) & 1u) != 0u;
    }
    float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    vec3 tint(vec3 c, float a) { return a > 0.0 ? mix(c, vec3(1.0), a) : mix(c, vec3(0.0), -a); }
    void main() {
        vec2 px = vec2(v_uv.x, 1.0 - v_uv.y) * screen.xy;
        float u = rect.z * 0.01;                // 1% of the board
        vec2 uv = px / screen.xy;
        // The page, lighter toward the light; the season's photograph goes here.
        vec3 c = page.rgb * (1.6 - 0.9 * length(uv - vec2(0.25, 0.15)));
        vec2 bc = rect.xy + 0.5 * rect.z;
        vec2 bh = vec2(0.5 * rect.z);
        // The board's shadow falls down and to the right, away from the light.
        float sd = box(px, bc + vec2(1.2, 2.4) * u, bh - u, rect.w);
        c *= 1.0 - 0.7 * (1.0 - smoothstep(-2.0 * u, 3.0 * u, sd));
        float fd = box(px, bc, bh, rect.w);
        if (fd < 1.0) {
            // The frame: lighter toward the light, bevelled at its outer edge.
            vec2 f = (px - rect.xy) / rect.z;
            float diag = 0.5 * (f.x + f.y);
            vec3 fr = mix(tint(frame.rgb, 0.14), frame.rgb, smoothstep(0.0, 0.4, diag));
            fr = mix(fr, frame.rgb * 0.75, smoothstep(0.4, 1.0, diag));
            vec2 dir = normalize(px - bc + 0.001);
            float lit = dot(dir, vec2(-0.7071));
            float edge = 1.0 - smoothstep(0.0, 0.6 * u, -fd);
            fr = tint(fr, edge * (lit > 0.0 ? 0.22 * lit : 0.35 * lit));
            vec3 col = fr;
            vec2 ic = inner.xy + 0.5 * inner.z;
            float id = box(px, ic, vec2(0.5 * inner.z), u);
            if (id < 1.0) {
                int n = int(screen.w);
                vec2 q = (px - inner.xy) / inner.w;
                ivec2 cell = clamp(ivec2(floor(q)), ivec2(0), ivec2(n - 1));
                int x = cell.x;
                int y = n - 1 - cell.y;
                vec2 fq = fract(q);
                vec3 s = ((x + y) & 1) == 0 ? dark.rgb : light.rgb;
                // The square's surface.
                int k = int(kind.x);
                float a = 0.0;
                if (k == 0) {
                    // Wood: fine grain that wanders, a light-to-dark sweep across.
                    float g = fract((px.x + 1.6 * u * sin(px.y / (9.0 * u) + float(x * 7 + y * 3)))
                                    / (0.75 * u) + hash(vec2(cell)));
                    a += g < 0.24 ? -0.07 : (g > 0.62 && g < 0.78 ? 0.04 : 0.0);
                    a += mix(0.05, -0.07, fq.x);
                } else if (k == 1) {
                    // Stone: two soft patches.
                    a += 0.09 * (1.0 - smoothstep(0.0, 0.55, length(fq - vec2(0.3, 0.25))));
                    a -= 0.07 * (1.0 - smoothstep(0.0, 0.5, length(fq - vec2(0.75, 0.8))));
                } else if (k == 2) {
                    // Birch: faint fibre across, and the sheen.
                    a += fract(px.y / (0.9 * u)) < 0.13 ? 0.05 : 0.0;
                    a += mix(0.06, -0.05, 0.5 * (fq.x + fq.y));
                } else {
                    a += mix(0.06, -0.05, 0.5 * (fq.x + fq.y));
                }
                s = tint(s, a);
                int sq = y * n + x;
                if (has(last, sq)) s = mix(s, glow.rgb, 0.16);
                // The pool of light, warm toward the top left, dark in the far corner.
                vec2 g2 = (px - inner.xy) / inner.z;
                float t = length((g2 - vec2(0.22, 0.18)) / 1.3);
                s = mix(s, vec3(1.0, 0.97, 0.9), 0.22 * (1.0 - smoothstep(0.0, 0.45, t)));
                s *= 1.0 - 0.4 * smoothstep(0.45, 1.0, t);
                // A soft shadow where the squares meet the frame.
                s *= 1.0 - 0.35 * exp(-max(-id, 0.0) / (0.7 * u));
                // A legal target: a glowing dot; a capture's stop: a ring.
                float r = length(fq - 0.5) * inner.w;
                if (has(target, sq)) {
                    s += glow.rgb * 0.6 * exp(-max(r - 0.15 * inner.w, 0.0) / (1.2 * u));
                    s = mix(s, glow.rgb, 0.9 * clamp(0.15 * inner.w - r + 0.5, 0.0, 1.0));
                }
                if (has(via, sq)) {
                    float rd = abs(r - 0.18 * inner.w) - 0.25 * u;
                    s += glow.rgb * 0.4 * exp(-max(rd, 0.0) / u);
                    s = mix(s, glow.rgb, clamp(0.5 - rd, 0.0, 1.0));
                }
                col = mix(fr, s, clamp(0.5 - id, 0.0, 1.0));
            }
            c = mix(c, col, clamp(0.5 - fd, 0.0, 1.0));
        }
        result = vec4(c, 1.0);
    }
    """;

let PIECE_VERT = """
    layout(std430, set = 0, binding = 0) readonly buffer Pieces { vec4 p[]; };
    layout(set = 1, binding = 0) uniform View { vec4 screen; };
    layout(location = 0) out vec2 v_local;
    layout(location = 1) flat out vec4 v_look;
    layout(location = 2) flat out vec4 v_extra;
    const vec2 CORNERS[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
                                   vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));
    void main() {
        int i = gl_InstanceIndex * 3;
        vec4 at = p[i];
        float r = at.z;
        float lift = at.w / r;
        float side = screen.z / r;
        // A quad around the disc in units of its radius, room for the lift, the
        // side, the rings, and the shadow.
        vec2 l = mix(vec2(-1.9, -1.9 - lift), vec2(1.9, 2.1 + side), CORNERS[gl_VertexIndex]);
        vec2 px = at.xy + l * r;
        gl_Position = vec4(px.x / screen.x * 2.0 - 1.0, 1.0 - px.y / screen.y * 2.0, 0.0, 1.0);
        v_local = l;
        v_look = p[i + 1];
        v_extra = vec4(p[i + 2].x, lift, side, 1.0 / r);
    }
    """;

let PIECE_FRAG = """
    layout(location = 0) in vec2 v_local;
    layout(location = 1) flat in vec4 v_look;     // black, king, selected, opacity
    layout(location = 2) flat in vec4 v_extra;    // must capture, lift, side, one pixel
    layout(location = 0) out vec4 result;
    layout(set = 3, binding = 1) uniform Clock { vec4 time; };
    vec4 acc = vec4(0.0);
    void over(vec3 c, float a) { acc = vec4(c * a, a) + acc * (1.0 - a); }
    float fill(float d, float w) { return clamp(0.5 - d / w, 0.0, 1.0); }
    // The crown: five points over a band, in units where it spans -1..1.
    const vec2 CROWN[7] = vec2[](vec2(-0.72, 0.30), vec2(-0.88, -0.42), vec2(-0.40, 0.02),
                                 vec2(0.0, -0.62), vec2(0.40, 0.02), vec2(0.88, -0.42),
                                 vec2(0.72, 0.30));
    float crown(vec2 p) {
        float d = dot(p - CROWN[0], p - CROWN[0]);
        float s = 1.0;
        for (int i = 0, j = 6; i < 7; j = i, i++) {
            vec2 e = CROWN[j] - CROWN[i];
            vec2 w = p - CROWN[i];
            vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
            d = min(d, dot(b, b));
            bvec3 c = bvec3(p.y >= CROWN[i].y, p.y < CROWN[j].y, e.x * w.y > e.y * w.x);
            if (all(c) || all(not(c))) s = -s;
        }
        float poly = s * sqrt(d);
        vec2 q = abs(p - vec2(0.0, 0.47)) - vec2(0.72, 0.09);
        float band = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
        return min(poly, band);
    }
    void main() {
        vec2 p = v_local;
        bool black = v_look.x > 0.5;
        float sel = v_look.z;
        float lift = v_extra.y;
        float side = v_extra.z;
        float scale = 1.0 + 0.06 * sel;
        float w = v_extra.w / scale;            // one pixel in the face's units
        vec3 face = black ? b_face.rgb : w_face.rgb;
        vec3 ring = black ? mix(face, vec3(1.0), 0.16) : mix(face, vec3(0.0), 0.13);
        vec3 rim = black ? mix(face, vec3(0.0), 0.18) : mix(face, vec3(0.0), 0.06);
        vec3 sidec = black ? mix(face, vec3(0.0), 0.5) : mix(face, vec3(0.0), 0.32);
        float spec = black ? 0.3 : 0.6;
        float shade = black ? 0.3 : 0.18;
        // Shadows on the board, away from the light: a wide soft one that spreads as the
        // piece lifts, and a tight one where it touches.
        float d0 = length(p - vec2(0.1, 0.22 + 0.5 * lift)) - 1.0;
        over(vec3(0.0), 0.35 * (1.0 - smoothstep(-0.3, 0.5 + lift, d0)));
        float d1 = length(p - vec2(0.04, 0.1)) - 0.98;
        over(vec3(0.0), 0.4 * (1.0 - smoothstep(-0.1, 0.15, d1)) * (1.0 - smoothstep(0.0, 0.3, lift)));
        vec2 f = (p + vec2(0.0, lift)) / scale;
        float r = length(f);
        if (sel > 0.0) over(glow.rgb, sel * 0.5 * exp(-max(r - 1.0, 0.0) * 4.0));
        // The side under the face, darker away from the light.
        float sy = f.y - clamp(f.y, 0.0, side / scale);
        over(sidec * (1.05 - 0.2 * f.x), fill(length(vec2(f.x, sy)) - 1.0, w));
        // The face: inner ring, rim, then the light on it.
        vec3 col = face;
        col = mix(col, ring, clamp((r - 0.45) / w + 0.5, 0.0, 1.0) * clamp((0.52 - r) / w + 0.5, 0.0, 1.0));
        col = mix(col, rim, clamp((r - 0.80) / w + 0.5, 0.0, 1.0));
        float diag = dot(f, vec2(0.7071));
        col = mix(col, vec3(1.0), 0.1 * clamp(-diag, 0.0, 1.0));
        col = mix(col, vec3(0.0), shade * smoothstep(-0.1, 1.0, diag));
        float edge = smoothstep(0.84, 0.98, r);
        float lit = -diag / max(r, 0.001);
        col = mix(col, lit > 0.0 ? vec3(1.0) : vec3(0.0), edge * (lit > 0.0 ? 0.25 : 0.22) * abs(lit));
        if (v_look.y > 0.5) {
            vec3 cc = black ? vec3(0.914, 0.769, 0.416) : crown_w.rgb;
            col = mix(col, cc, fill(0.5 * crown(f / 0.5), w));
        }
        col = mix(col, vec3(1.0), spec * (1.0 - smoothstep(0.0, 0.42, length(f - vec2(-0.36, -0.44)))));
        over(col, fill(r - 1.0, w));
        if (sel > 0.0) over(glow.rgb, sel * fill(abs(r - 1.08) - 0.05, w));
        // Must capture: a red ring that pulses every 1.4 s.
        if (v_extra.x > 0.5) {
            float ph = 0.5 - 0.5 * cos(time.x * 6.2831853 / 1.4);
            float rr = 1.15 * (0.94 + 0.14 * ph);
            float op = 0.95 - 0.55 * ph;
            vec3 red = vec3(1.0, 0.353, 0.29);
            over(red, op * 0.45 * exp(-abs(r - rr) * 7.0));
            over(red, op * fill(abs(r - rr) - 0.06, w));
        }
        result = acc * v_look.w;
    }
    """;

struct Drawer {
    board_pipeline: gfx::Pipeline,
    piece_pipeline: gfx::Pipeline,
    pieces:         gfx::Buffer,
    // What goes into the buffer: always the whole of it, so SDL can cycle it.
    upload: board::Piece[board::MAX_PIECES],
}

fn new() -> Drawer {
    let full = embed_shader("vert", FULL_VERT);
    let board_fs = embed_shader("frag", THEME_BLOCK, BOARD_FRAG);
    let piece_vs = embed_shader("vert", PIECE_VERT);
    let piece_fs = embed_shader("frag", THEME_BLOCK, PIECE_FRAG);
    var d = Drawer {
        board_pipeline: gfx::pipeline(full, board_fs, gfx::PipelineDesc {}),
        piece_pipeline: gfx::pipeline(piece_vs, piece_fs,
                                      gfx::PipelineDesc { blend: gfx::BLEND_PREMULTIPLIED }),
        pieces: gfx::Buffer { 0 },
        upload: [board::Piece {}; board::MAX_PIECES],
    };
    d.pieces = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(d.upload));
    return d;
}

// Draws one frame of the board as fill() left it.
fn frame(d: Drawer&, b: board::Board&, l: board::Layout, t: theme::Theme, now: f64,
         width: f32, height: f32) {
    for i in b.pieces.len { d.upload[i] = b.pieces[i]; }
    gfx::update_buffer(d.pieces, bytes_of(d.upload));
    gfx::begin_screen(t.page);
    gfx::bind(d.board_pipeline);
    gfx::uniforms(gfx::FRAGMENT, 0, t);
    gfx::uniforms(gfx::FRAGMENT, 1, BoardUniforms {
        screen: float4 { width, height, now as f32, l.n },
        rect: l.board, inner: l.inner, marks: b.marks });
    gfx::draw(3);
    gfx::bind(d.piece_pipeline);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, d.pieces);
    gfx::uniforms(gfx::VERTEX, 0, View { screen: float4 { width, height, 0.008 * l.board.z, 0.0 } });
    gfx::uniforms(gfx::FRAGMENT, 0, t);
    gfx::uniforms(gfx::FRAGMENT, 1, Clock { time: float4 { now as f32, 0.0, 0.0, 0.0 } });
    gfx::draw_instanced(6, b.pieces.len);
    gfx::end_pass();
}
