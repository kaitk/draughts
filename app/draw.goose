// Drawing the board: one full-screen pass for the blurred photograph and the squares
// with their marks, worked out per pixel; then every piece in one instanced draw that
// pulls its piece from a storage buffer (docs/architecture/rendering.md, "Look"). The
// board is flat; only the pieces have a soft light.
namespace draw;
import std;
import vec;
import gfx;

import board from "../board";
import .scene;

// The board pass's uniforms, std140.
struct BoardUniforms {
    screen: float4,     // width, height in pixels, time, squares per side
    rect:   float4,     // the board: x, y, size, corner radius
    inner:  float4,     // the squares: x, y, size, one square
    scene:  float4,     // x: 1 when there is a photograph
    wrong:  float4,     // a wrong move's square (y * size + x, or -1), and how far its flash is, 0..1
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
        vec4 screen; vec4 rect; vec4 inner; vec4 scene; vec4 wrong;
        uvec4 last; uvec4 target; uvec4 via;
    };
    layout(set = 2, binding = 0) uniform sampler2D photo;
    float box(vec2 p, vec2 c, vec2 h, float r) {
        vec2 q = abs(p - c) - h + r;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    }
    bool has(uvec4 m, int n) {
        uint w = n < 32 ? m.x : n < 64 ? m.y : n < 96 ? m.z : m.w;
        return ((w >> uint(n & 31)) & 1u) != 0u;
    }
    float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
    float noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        f = f * f * (3.0 - 2.0 * f);
        return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
                   mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
    }
    vec3 tint(vec3 c, float a) { return a > 0.0 ? mix(c, vec3(1.0), a) : mix(c, vec3(0.0), -a); }
    // A ring of radius r and half width w around a point d pixels away, with a glow
    // that falls off over g pixels.
    vec3 ring(vec3 c, vec3 col, float d, float r, float w, float g, float a) {
        float rd = abs(d - r) - w;
        c = mix(c, col, a * 0.45 * exp(-max(rd, 0.0) / g));
        return mix(c, col, a * clamp(0.5 - rd, 0.0, 1.0));
    }
    void main() {
        vec2 px = gl_FragCoord.xy;              // pixels from the top left, exact
        float u = rect.z * 0.01;                // 1% of the board
        // The season's photograph, blurred, cover-cropped by the long side and dimmed to
        // 0.8; or the page color without one.
        float side = max(screen.x, screen.y);
        vec3 c = scene.x > 0.5
            ? 0.8 * texture(photo, (px - 0.5 * (screen.xy - side)) / side).rgb
            : page.rgb;
        vec2 bc = rect.xy + 0.5 * rect.z;
        vec2 bh = vec2(0.5 * rect.z);
        // A soft shadow under the board, a little down.
        float sd = box(px, bc + vec2(0.0, 1.4 * u), bh - u, rect.w);
        c *= 1.0 - 0.55 * (1.0 - smoothstep(-3.6 * u, 3.6 * u, sd));
        float fd = box(px, bc, bh, rect.w);
        // The lip: a thin raised edge round the squares, the dark square's color, with a
        // line of the light square's color along its outer edge (brightest on top) and a
        // dark seam where the squares sit below it.
        vec2 ic = inner.xy + 0.5 * inner.z;
        float id = box(px, ic, vec2(0.5 * inner.z), 0.5 * rect.w);
        if (fd < 1.0 && id > -1.0) {
            float lw = 0.5 * (rect.z - inner.z);
            float t = clamp(-fd / lw, 0.0, 1.0);    // 0 at the outer edge, 1 at the squares
            float ny = (px.y - bc.y) / bh.y;
            vec3 lip = tint(dark.rgb, 0.06 - 0.1 * ny);
            vec3 line = mix(light.rgb, vec3(1.0), 0.25);
            lip = mix(lip, line, (0.75 - 0.25 * ny) * (1.0 - smoothstep(0.1, 0.26, t)));
            lip = tint(lip, -0.35 * smoothstep(0.7, 1.0, t));
            c = mix(c, lip, clamp(0.5 - fd, 0.0, 1.0));
        }
        if (id < 1.0) {
            int n = int(screen.w);
            vec2 q = (px - inner.xy) / inner.w;
            ivec2 cell = clamp(ivec2(floor(q)), ivec2(0), ivec2(n - 1));
            int x = cell.x;
            int y = n - 1 - cell.y;
            vec2 fq = fract(q);
            bool dk = ((x + y) & 1) == 0;
            vec3 s = dk ? dark.rgb : light.rgb;
            // The square's faint surface: never busy.
            int k = int(kind.x);
            float h = hash(vec2(cell));
            float a = 0.0;
            if (k == 0) {
                // Wood: smooth, fine, nearly straight grain along the board's height,
                // barely there, and each square's own tone.
                float gx = px.x / u + 0.2 * sin(px.y / (9.0 * u) + 6.28 * h) + 37.0 * h;
                float g = 0.5 * sin(gx * 3.1) + 0.5 * (noise(vec2(gx * 2.2, px.y / (8.0 * u))) - 0.5);
                a += 0.016 * g + 0.025 * (h - 0.5);
            } else if (k == 1) {
                // Stone: faint paper-like mottling.
                vec2 m = px / u;
                float f = 0.6 * noise(m * 0.45 + 13.0 * h) + 0.4 * noise(m * 1.3);
                a += 0.07 * (f - 0.5);
            } else if (k == 2) {
                // Birch: a hint of fibre across.
                a += 0.03 * (noise(vec2(px.x / (3.0 * u), px.y / (0.35 * u))) - 0.5);
            } else {
                a += 0.02 * (noise(px / (2.0 * u)) - 0.5);
            }
            // Where squares meet: a hair of light on each square's top edge.
            float e = fq.y * inner.w;
            a += 0.04 * (1.0 - smoothstep(0.0, 0.18 * u, e));
            s = tint(s, a);
            int sq = y * n + x;
            if (has(last, sq)) s = mix(s, glow.rgb, 0.16);
            // A legal target: a glowing dot; a capture's stop: a ring.
            float r = length(fq - 0.5) * inner.w;
            if (has(target, sq)) {
                s += glow.rgb * 0.5 * exp(-max(r - 0.15 * inner.w, 0.0) / (1.2 * u));
                s = mix(s, glow.rgb, 0.9 * clamp(0.15 * inner.w - r + 0.5, 0.0, 1.0));
            }
            if (has(via, sq)) s = ring(s, glow.rgb, r, 0.18 * inner.w, 0.25 * u, u, 1.0);
            // A wrong move: a red ring on its square that flashes twice.
            if (int(wrong.x) == sq && wrong.y < 1.0) {
                float t = fract(wrong.y * 2.0);
                float op = t < 0.4 ? t / 0.4 : 1.0 - 0.4 * (t - 0.4) / 0.6;
                vec3 red = vec3(1.0, 0.353, 0.29);
                float sc = 0.8 + 0.2 * min(t / 0.4, 1.0);
                s = mix(s, red, op * 0.22 * clamp(0.42 * inner.w * sc - r + 0.5, 0.0, 1.0));
                s = ring(s, red, r, 0.42 * inner.w * sc, 0.25 * u, 1.2 * u, op);
            }
            c = mix(c, s, clamp(0.5 - id, 0.0, 1.0));
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
    vec3 tint(vec3 c, float a) { return a > 0.0 ? mix(c, vec3(1.0), a) : mix(c, vec3(0.0), -a); }
    // A raised round edge across radii a..b: the light from above catches its upper
    // side and misses its lower one, softly. -1 where its top faces away from the light,
    // 1 where it faces it; 0 off the edge. `dy` is the point's direction's y (down is +).
    float bead(float r, float a, float b, float dy) {
        float t = (r - a) / (b - a);
        if (t <= 0.0 || t >= 1.0) return 0.0;
        float th = (t - 0.5) * 3.0;             // the edge's slope, -1.5..1.5 radians
        return -dy * sin(th) * (1.0 - 0.3 * abs(th));
    }
    void main() {
        vec2 p = v_local;
        bool black = v_look.x > 0.5;
        float sel = v_look.z;
        float lift = v_extra.y;
        float side = v_extra.z;
        float scale = 1.0 + 0.05 * sel;
        float w = v_extra.w / scale;            // one pixel in the face's units
        vec3 face = black ? b_face.rgb : w_face.rgb;
        vec3 rim = black ? mix(face, vec3(0.0), 0.18) : mix(face, vec3(0.0), 0.06);
        vec3 sidec = black ? mix(face, vec3(0.0), 0.5) : mix(face, vec3(0.0), 0.32);
        // A short soft shadow, straight down and a touch right, that spreads as the
        // piece lifts, and a tight one where it touches the board.
        float d0 = length(p - vec2(0.04, 0.25 + 0.6 * lift)) - 1.0;
        float soft = 0.16 + 0.5 * lift;
        over(vec3(0.0), (0.4 - 0.1 * sel) * (1.0 - smoothstep(-2.0 * soft, 2.0 * soft, d0)));
        float d1 = length(p - vec2(0.0, 0.06 + side)) - 1.0;
        over(vec3(0.0), 0.3 * (1.0 - smoothstep(-0.08, 0.06, d1)) * (1.0 - smoothstep(0.0, 0.2, lift)));
        vec2 f = (p + vec2(0.0, lift)) / scale;
        float r = length(f);
        vec2 dir = f / max(r, 0.001);
        if (sel > 0.0) over(glow.rgb, sel * 0.4 * exp(-max(r - 1.0, 0.0) * 5.0));
        // The thin side under the face, rounder in the middle, darkest at its foot.
        float sy = f.y - clamp(f.y, 0.0, side / scale);
        float foot = clamp((f.y - sqrt(max(1.0 - f.x * f.x, 0.0))) / (side / scale), 0.0, 1.0);
        vec3 sc = sidec * (0.8 + 0.25 * sqrt(max(1.0 - f.x * f.x, 0.0))) * (1.0 - 0.25 * foot);
        over(sc, fill(length(vec2(f.x, sy)) - 1.0, w));
        // The face: flat and a little below one wide rounded rim, lit softly from above.
        vec3 col = mix(face, rim, smoothstep(0.64, 0.68, r));
        col = tint(col, -0.03 * f.y);
        float hi = black ? 0.4 : 0.55;
        float lo = black ? 0.4 : 0.24;
        float l = bead(r, 0.64, 1.0, dir.y);
        col = tint(col, l > 0.0 ? hi * l : lo * l);
        // The groove where the face sits below the rim.
        col = tint(col, -(black ? 0.3 : 0.14) * (1.0 - smoothstep(0.0, 0.03, abs(r - 0.655))));
        if (black) {
            // Dark pieces are a little glossy.
            col = tint(col, 0.07 * (1.0 - smoothstep(0.0, 0.6, length(f - vec2(-0.1, -0.4)))));
        }
        col = tint(col, -(black ? 0.25 : 0.18) * smoothstep(0.95, 1.0, r));
        if (v_look.y > 0.5) {
            vec3 cc = black ? vec3(0.914, 0.769, 0.416) : crown_w.rgb;
            col = mix(col, cc, fill(0.56 * crown(f / 0.56), w));
        }
        over(col, fill(r - 1.0, w));
        // Selected: a ring in the glow color a little out from the piece.
        if (sel > 0.0) {
            float rd = abs(r - 1.13) - 0.055;
            over(glow.rgb, sel * 0.6 * exp(-max(rd, 0.0) * 7.0));
            over(mix(glow.rgb, vec3(1.0), 0.25), sel * fill(rd, w));
        }
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
    scene:          scene::Scene,
    // What goes into the buffer: always the whole of it, so SDL can cycle it.
    upload: board::Piece[board::MAX_PIECES],
}

fn new(kind: i64) -> Drawer {
    let full = embed_shader("vert", FULL_VERT);
    let board_fs = embed_shader("frag", THEME_BLOCK, BOARD_FRAG);
    let piece_vs = embed_shader("vert", PIECE_VERT);
    let piece_fs = embed_shader("frag", THEME_BLOCK, PIECE_FRAG);
    var d = Drawer {
        board_pipeline: gfx::pipeline(full, board_fs, gfx::PipelineDesc {}),
        piece_pipeline: gfx::pipeline(piece_vs, piece_fs,
                                      gfx::PipelineDesc { blend: gfx::BLEND_PREMULTIPLIED }),
        pieces: gfx::Buffer { 0 },
        scene:  scene::load(kind, full),
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
        rect:   l.board, inner: l.inner,
        scene:  float4 { if d.scene.has { 1.0 } else { 0.0 }, 0.0, 0.0, 0.0 },
        wrong: b.flash, marks: b.marks });
    gfx::bind_texture(gfx::FRAGMENT, 0, d.scene.photo, d.scene.sampler);
    gfx::draw(3);
    gfx::bind(d.piece_pipeline);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, d.pieces);
    gfx::uniforms(gfx::VERTEX, 0, View { screen: float4 { width, height, 0.0055 * l.board.z, 0.0 } });
    gfx::uniforms(gfx::FRAGMENT, 0, t);
    gfx::uniforms(gfx::FRAGMENT, 1, Clock { time: float4 { now as f32, 0.0, 0.0, 0.0 } });
    gfx::draw_instanced(6, b.pieces.len);
    gfx::end_pass();
}
