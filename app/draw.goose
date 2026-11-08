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
    scene:  float4,     // x: the photograph's blur, 0 sharp..1, or -1 with none; y: how bright it is shown; z: the board dimmed by; w: 1 turned
    wrong:  float4,     // a wrong move's square (y * size + x, or -1), and how far its flash is, 0..1
    marks:  board::Marks,
}

struct View { screen: float4 }     // width, height, the disc's side depth in radii

// Seconds; and for the pieces over the UI, the board's rect where a transition hides
// them, as it does the UI (widgets.goose), size 0 at rest and for the board's own.
struct Clock { time: float4, hole: float4 }

let THEME_BLOCK = """
    layout(set = 3, binding = 0) uniform Theme {
        vec4 light; vec4 dark; vec4 frame; vec4 w_face; vec4 b_face; vec4 crown_w;
        vec4 glow; vec4 page; vec4 kind; vec4 glass; vec4 text;
    };
    """;

// What the board's, the pieces', and the UI's shaders share: a quad's corners as two
// triangles; a rounded rect's distance at p (center c, half size h, corner radius r);
// a color taken toward white (a > 0) or black (a < 0); and a color laid over what a
// pixel has so far, premultiplied, in acc.
let SHARED_BLOCK = """
    const vec2 CORNERS[6] = vec2[](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
                                   vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));
    float box(vec2 p, vec2 c, vec2 h, float r) {
        vec2 q = abs(p - c) - h + r;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    }
    vec3 tint(vec3 c, float a) { return a > 0.0 ? mix(c, vec3(1.0), a) : mix(c, vec3(0.0), -a); }
    vec4 acc = vec4(0.0);
    void over(vec3 c, float a) { acc = vec4(c * a, a) + acc * (1.0 - a); }
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
    layout(set = 2, binding = 0) uniform sampler2D photo;       // blurred
    layout(set = 2, binding = 1) uniform sampler2D sharp_photo;
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
        // The season's photograph, cover-cropped by the long side: blurred and dimmed to
        // 0.8 behind the game, sharp behind home, the two mixed in a transition between
        // them; or the page color without one.
        float side = max(screen.x, screen.y);
        vec2 puv = (px - 0.5 * (screen.xy - side)) / side;
        vec3 c = page.rgb;
        if (scene.x >= 1.0) c = scene.y * texture(photo, puv).rgb;
        else if (scene.x <= 0.0 && scene.x > -0.5) c = scene.y * texture(sharp_photo, puv).rgb;
        else if (scene.x > 0.0) c = scene.y * mix(texture(sharp_photo, puv).rgb, texture(photo, puv).rgb, scene.x);
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
            bool turned = scene.w > 0.5;
            int x = turned ? n - 1 - cell.x : cell.x;
            int y = turned ? cell.y : n - 1 - cell.y;
            vec2 fq = fract(q);
            bool dk = ((x + y) & 1) == 0;
            vec3 s = dk ? dark.rgb : light.rgb;
            // The square's faint surface: never busy.
            int k = int(kind.x);
            float h = hash(vec2(cell));
            float a = 0.0;
            if (k == 0) {
                // Wood: no regular stripes, which read as bands from afar; fine
                // irregular streaks along the board's height, a broad soft figure, and
                // each square's own tone, all barely there.
                vec2 m = px / u + 41.0 * h;
                float fine = noise(vec2(m.x * 2.6, m.y * 0.08)) - 0.5;
                float broad = noise(m * vec2(0.35, 0.06)) - 0.5;
                a += 0.022 * fine + 0.03 * broad + 0.02 * (h - 0.5);
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
        // A win dims the board, as a black fill over it would.
        c *= 1.0 - scene.z * clamp(0.5 - fd, 0.0, 1.0);
        result = vec4(c, 1.0);
    }
    """;

// A stacked king's upper disc sits 1.3% of the board above the lower one, as deep as
// that: the side's 0.55% times this.
let STACK_BLOCK = """
    const float STACK = 2.3636;
    """;

let PIECE_VERT = """
    layout(std430, set = 0, binding = 0) readonly buffer Pieces { vec4 p[]; };
    layout(set = 1, binding = 0) uniform View { vec4 screen; };
    layout(location = 0) out vec2 v_local;
    layout(location = 1) flat out vec4 v_look;
    layout(location = 2) flat out vec4 v_extra;
    layout(location = 3) flat out vec4 v_ring;
    layout(location = 4) flat out vec4 v_win;
    void main() {
        int i = gl_InstanceIndex * 4;
        vec4 at = p[i];
        float r = at.z;
        float lift = at.w / r;
        float side = screen.z;
        // A quad around the disc in units of its radius, room for the lift, a stacked
        // king's upper disc, the side, the rings, and the shadow.
        float up = p[i + 1].y > 1.5 ? STACK * side : 0.0;
        vec2 l = mix(vec2(-1.9, -1.9 - lift - up), vec2(1.9, 2.1 + side), CORNERS[gl_VertexIndex]);
        vec2 px = at.xy + l * r;
        gl_Position = vec4(px.x / screen.x * 2.0 - 1.0, 1.0 - px.y / screen.y * 2.0, 0.0, 1.0);
        v_local = l;
        v_look = p[i + 1];
        v_extra = vec4(p[i + 2].x, lift, side, 1.0 / r);
        v_ring = p[i + 2];
        v_win = p[i + 3];
    }
    """;

let PIECE_FRAG = """
    layout(location = 0) in vec2 v_local;
    layout(location = 1) flat in vec4 v_look;     // black, king (0, 1 crown, 2 stack), selected, opacity
    layout(location = 2) flat in vec4 v_extra;    // must capture (1 pulsing, 2 still), lift, side, one pixel
    layout(location = 3) flat in vec4 v_ring;     // y: a glow ring tight round it, 0 to 1
    layout(location = 4) flat in vec4 v_win;      // a win: x dimmed by; y its square lit; z the square's half side; w 1 on the board
    layout(location = 0) out vec4 result;
    layout(set = 3, binding = 1) uniform Clock { vec4 time; vec4 hole; };
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
    // Light toward white, shade toward a deeper tone of the same color, which keeps a
    // cream warm where black would turn it grey.
    vec3 lit(vec3 c, float a) { return a > 0.0 ? mix(c, vec3(1.0), a) : mix(c, c * c * 0.85, -a); }
    // A rounded outer edge across radii a..b, flat at a and turning down to the side at
    // b, under a soft light from above the board and toward its top: lit on its upper
    // side, most halfway round, and in shade on its lower side, most at the bottom.
    // 0 on the flat top; `dy` is the point's direction's y (down is +).
    float shoulder(float r, float a, float b, float dy) {
        float th = 1.45 * clamp((r - a) / (b - a), 0.0, 1.0);
        return 0.7071 * (-dy * sin(th) + cos(th) - 1.0);
    }
    // A groove cut into a flat top across radii a..b: concave, so lit the other way
    // round from a bead, and smooth to nothing at both of its edges.
    float groove(float r, float a, float b, float dy) {
        float t = (r - a) / (b - a);
        if (t <= 0.0 || t >= 1.0) return 0.0;
        return -dy * sin(6.2831853 * t);
    }
    // Selected: a ring in the glow color a little out from the piece. Must capture: a red
    // ring that pulses every 1.4 s, or stays at its brightest. Both round the piece's
    // foot: drawn after its lower disc, so a stacked king's upper disc hides their part
    // behind it.
    void rings(float r, float sel, float must, float w) {
        if (sel > 0.0) {
            float rd = abs(r - 1.13) - 0.055;
            over(glow.rgb, sel * 0.6 * exp(-max(rd, 0.0) * 7.0));
            over(mix(glow.rgb, vec3(1.0), 0.25), sel * fill(rd, w));
        }
        if (must > 0.5) {
            float ph = must > 1.5 ? 0.0 : 0.5 - 0.5 * cos(time.x * 6.2831853 / 1.4);
            float rr = 1.15 * (0.94 + 0.14 * ph);
            float op = 0.95 - 0.55 * ph;
            vec3 red = vec3(1.0, 0.353, 0.29);
            over(red, op * 0.45 * exp(-abs(r - rr) * 7.0));
            over(red, op * fill(abs(r - rr) - 0.06, w));
        }
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
        vec3 sidec = black ? mix(face, vec3(0.0), 0.5) : face * face * 0.92;
        // A win's glow passing: its square lit in the glow color at 40%, as the last
        // move's squares are at 16%, under everything of the piece.
        if (v_win.y > 0.0) {
            vec2 q = abs(p) - v_win.z;
            over(glow.rgb, 0.4 * v_win.y * fill(max(q.x, q.y), w));
        }
        // The side to move: a ring an eighth of the radius wide in the glow color at 80%
        // right round the disc, and a soft glow, under the piece and its shadow (CSS
        // `0 0 0 4px` and `0 0 22px 4px` on a 64 px disc); fainter as y falls, which
        // pulses it while the computer thinks.
        if (v_ring.y > 0.0) {
            float rr = length(p);
            over(glow.rgb, v_ring.y * 0.45 * (1.0 - smoothstep(-0.34, 0.34, rr - 1.125)));
            over(glow.rgb, v_ring.y * 0.8 * fill(abs(rr - 1.0625) - 0.0625, w));
        }
        // A short soft shadow, straight down and a touch right, that spreads as the
        // piece lifts, and a tight one where it touches the board.
        float d0 = length(p - vec2(0.04, 0.25 + 0.6 * lift)) - 1.0;
        float soft = 0.16 + 0.5 * lift;
        over(vec3(0.0), (0.4 - 0.1 * sel) * (1.0 - smoothstep(-2.0 * soft, 2.0 * soft, d0)));
        float d1 = length(p - vec2(0.0, 0.06 + side)) - 1.0;
        over(vec3(0.0), 0.3 * (1.0 - smoothstep(-0.08, 0.06, d1)) * (1.0 - smoothstep(0.0, 0.2, lift)));
        vec2 f = (p + vec2(0.0, lift)) / scale;
        float r = length(f);
        if (sel > 0.0) over(glow.rgb, sel * 0.4 * exp(-max(r - 1.0, 0.0) * 5.0));
        // A man or a crowned king is one disc; a stacked king two plain ones, the upper
        // one as deep as it sits above the lower.
        bool stack = v_look.y > 1.5;
        for (int k = 0; k < 2; k++) {
            if (k == 1 && !stack) break;
            float up = k == 1 ? STACK * side : 0.0;
            float depth = (k == 1 ? up : side) / scale;
            f = (p + vec2(0.0, lift + up)) / scale;
            r = length(f);
            vec2 dir = f / max(r, 0.001);
            // The thin side under the face, rounder in the middle, darkest at its foot.
            float sy = f.y - clamp(f.y, 0.0, depth);
            float foot = clamp((f.y - sqrt(max(1.0 - f.x * f.x, 0.0))) / depth, 0.0, 1.0);
            vec3 sc = sidec * (0.8 + 0.25 * sqrt(max(1.0 - f.x * f.x, 0.0))) * (1.0 - 0.25 * foot);
            over(sc, fill(length(vec2(f.x, sy)) - 1.0, w));
            // The top is flat and matte, as a turned disc's is: one color and one height,
            // with a narrow groove cut into it at 70% of the radius and only the outer
            // edge rounded. The light from above catches the outer edge's upper side
            // softly; in the groove, which is concave, it catches the wall that faces it,
            // nearer the center on the top half, and leaves the far wall in shade.
            vec3 col = tint(face, -0.02 * f.y);
            float l = shoulder(r, 0.86, 1.0, dir.y);
            col = lit(col, l > 0.0 ? (black ? 1.0 : 1.2) * l : (black ? 0.28 : 0.4) * l);
            float g = groove(r, 0.63, 0.76, dir.y);
            col = lit(col, g > 0.0 ? (black ? 0.4 : 0.5) * g : (black ? 0.6 : 1.2) * g);
            col = lit(col, -(black ? 0.3 : 0.45) * (1.0 - smoothstep(0.0, 0.05, abs(r - 0.695))));
            if (v_look.y > 0.5 && !stack) {
                vec3 cc = black ? vec3(0.914, 0.769, 0.416) : crown_w.rgb;
                col = mix(col, cc, fill(0.56 * crown(f / 0.56), w));
            }
            over(col, fill(r - 1.0, w));
            if (k == 0) rings(r, sel, v_extra.x, w);
        }
        // Dimmed with the board under a win, as a black fill over both would.
        result = vec4(acc.rgb * (1.0 - v_win.x), acc.a) * v_look.w;
        // Over the UI in a transition, hidden where the board passes unless it lies on it.
        if (hole.z > 0.0 && v_win.w < 0.5) {
            float h = 0.5 * hole.z;
            result *= clamp(0.5 + box(gl_FragCoord.xy, hole.xy + h, vec2(h), hole.w), 0.0, 1.0);
        }
    }
    """;

struct Drawer {
    full:           const u8[:],     // the full-screen vertex shader, for reloading the scene
    board_pipeline: gfx::Pipeline,
    piece_pipeline: gfx::Pipeline,
    pieces:         gfx::Buffer,
    overlay:        gfx::Buffer,
    scene:          scene::Scene,
    kind:           i64,             // the theme drawn (theme::WOOD..), whose scene is loaded
    colors:         theme::Theme,
    // What goes into the buffers: always the whole of each, so SDL can cycle them.
    upload:      board::Piece[board::MAX_PIECES],
    over_upload: board::Piece[panel::OVER],     // the pieces drawn over the UI
    over_count:  i64,
    view:        View,
}

fn new(kind: i64) -> Drawer {
    let full = embed_shader("vert", FULL_VERT);
    let board_fs = embed_shader("frag", THEME_BLOCK, SHARED_BLOCK, BOARD_FRAG);
    let piece_vs = embed_shader("vert", SHARED_BLOCK, STACK_BLOCK, PIECE_VERT);
    let piece_fs = embed_shader("frag", THEME_BLOCK, SHARED_BLOCK, STACK_BLOCK, PIECE_FRAG);
    var d = Drawer {
        full:           full,
        board_pipeline: gfx::pipeline(full, board_fs, gfx::PipelineDesc {}),
        piece_pipeline: gfx::pipeline(piece_vs, piece_fs,
                                      gfx::PipelineDesc { blend: gfx::BLEND_PREMULTIPLIED }),
        pieces:      gfx::Buffer { 0 },
        overlay:     gfx::Buffer { 0 },
        scene:       scene::load(kind, full),
        kind:        kind,
        colors:      theme::get(kind),
        upload:      [board::Piece {}; board::MAX_PIECES],
        over_upload: [board::Piece {}; panel::OVER],
        over_count:  0,
        view:        View { screen: float4 { 0.0, 0.0, 0.0, 0.0 } },
    };
    d.pieces = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(d.upload));
    d.overlay = gfx::buffer(gfx::BUFFER_STORAGE, bytes_of(d.over_upload));
    return d;
}

// Draws one frame of the board as fill() left it, into the screen's pass, which it
// leaves open for the UI; the caller ends it. The pieces in `over` are copied now and
// drawn by overlay(), after the UI. `blur` 0 shows the photograph as it is (home,
// settings), 1 blurred and dimmed (the game), and between mixes the two (a transition).
fn frame(d: Drawer&, b: board::Board&, over: const board::Piece[:], l: board::Layout, blur: f32, now: f64,
         width: f32, height: f32) {
    let t = d.colors;
    for i in b.pieces.len { d.upload[i] = b.pieces[i]; }
    gfx::update_buffer(d.pieces, bytes_of(d.upload));
    d.over_count = min(over.len, panel::OVER);
    for i in d.over_count { d.over_upload[i] = over[i]; }
    if d.over_count > 0 { gfx::update_buffer(d.overlay, bytes_of(d.over_upload)); }
    // The disc's side is 0.55% of the board deep, whatever a piece's size; the same for
    // the pieces over the UI where no board shows (a setup on a short phone).
    let across = if l.inner.w > 0.0 { l.board.z / l.inner.w } else { l.n / 0.978 };
    d.view = View { screen: float4 { width, height, 0.0055 * across / 0.39, 0.0 } };
    // No depth target: nothing tests depth, and asking for the screen's would make gfx
    // keep a window-sized one (patches/goose_gfx/0003).
    gfx::begin_pass(gfx::screen(), gfx::Texture { 0 }, t.page);
    gfx::bind(d.board_pipeline);
    gfx::uniforms(gfx::FRAGMENT, 0, t);
    // Dimmed to 0.8 blurred; the ends exact, so a screen at rest draws as it always has.
    let k = clamp(blur, 0.0, 1.0);
    let bright: f32 = if k <= 0.0 { 1.0 } else if k >= 1.0 { 0.8 } else { 1.0 - 0.2 * k };
    gfx::uniforms(gfx::FRAGMENT, 1, BoardUniforms {
        screen: float4 { width, height, now as f32, l.n },
        rect:   l.board, inner: l.inner,
        scene:  float4 { if d.scene.has { k } else { -1.0 }, bright, b.dim, if l.flip { 1.0 } else { 0.0 } },
        wrong: b.flash, marks: b.marks });
    gfx::bind_texture(gfx::FRAGMENT, 0, d.scene.photo, d.scene.sampler);
    gfx::bind_texture(gfx::FRAGMENT, 1, d.scene.sharp, d.scene.sampler);
    gfx::draw(3);
    gfx::bind(d.piece_pipeline);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, d.pieces);
    gfx::uniforms(gfx::VERTEX, 0, d.view);
    gfx::uniforms(gfx::FRAGMENT, 0, t);
    gfx::uniforms(gfx::FRAGMENT, 1, Clock { time: float4 { now as f32, 0.0, 0.0, 0.0 }, hole: float4 { 0.0, 0.0, 0.0, 0.0 } });
    gfx::draw_instanced(6, b.pieces.len);
}

// Swaps the theme and its scene for theme `kind`'s.
fn reload(d: Drawer&, kind: i64) {
    scene::release(d.scene);
    // The old scene is freed once the GPU is done with it; waiting (about a frame) lets
    // the new one take its place in SDL's shared block rather than open another.
    gfx::flush();
    d.scene = scene::load(kind, d.full);
    d.kind = kind;
    d.colors = theme::get(kind);
}

// Draws the pieces frame() was given for over the UI, in the open pass, none inside
// `hole` but those on the board.
fn overlay(d: Drawer&, now: f64, hole: float4) {
    guard d.over_count > 0 else { return; }
    let t = d.colors;
    gfx::bind(d.piece_pipeline);
    gfx::bind_storage_buffer(gfx::VERTEX, 0, d.overlay);
    gfx::uniforms(gfx::VERTEX, 0, d.view);
    gfx::uniforms(gfx::FRAGMENT, 0, t);
    gfx::uniforms(gfx::FRAGMENT, 1, Clock { time: float4 { now as f32, 0.0, 0.0, 0.0 }, hole: hole });
    gfx::draw_instanced(6, d.over_count);
}
