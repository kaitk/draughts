// The pieces, draw.goose's PIECE_VERT and PIECE_FRAG: every piece one instance of a
// quad, its piece pulled from the pieces' buffer, drawn as a signed-distance disc.
#include "common.slang"

// pieces: board::Piece's four float4s each; view: draw's View (width, height, the side's
// depth); time: draw's Clock.time; hole: Clock.hole.
struct Root { vec4* pieces; uint pad0; uint pad1; Theme theme; vec4 view; vec4 time; vec4 hole; };
GPU_ROOT(Root, root);

struct Varyings {
    float4 position : SV_Position;
    vec2 local : TEXCOORD0;
    nointerpolation vec4 look : TEXCOORD1;
    nointerpolation vec4 extra : TEXCOORD2;
    nointerpolation vec4 ring : TEXCOORD3;
    nointerpolation vec4 win : TEXCOORD4;
};

[shader("vertex")]
Varyings piece_vertex(uint vi : SV_VertexID, uint ii : SV_InstanceID) {
    vec4 screen = root.view;
    vec4* p = root.pieces;
    int i = int(ii) * 4;
    vec4 at = p[i];
    float r = at.z;
    float lift = at.w / r;
    float side = screen.z;
    float up = p[i + 1].y > 1.5 ? STACK * side : 0.0;
    vec2 l = mix(vec2(-1.9, -1.9 - lift - up), vec2(1.9, 2.1 + side), CORNERS[vi]);
    vec2 px = at.xy + l * r;
    Varyings o;
    o.position = clip_of(px, screen.xy);
    o.local = l;
    o.look = p[i + 1];
    o.extra = vec4(p[i + 2].x, lift, side, 1.0 / r);
    o.ring = p[i + 2];
    o.win = p[i + 3];
    return o;
}

static vec4 time, hole;
    float fill(float d, float w) { return clamp(0.5 - d / w, 0.0, 1.0); }
    // The crown: five points over a band, in units where it spans -1..1.
    static const vec2 CROWN[7] = {vec2(-0.72, 0.30), vec2(-0.88, -0.42), vec2(-0.40, 0.02),
                                 vec2(0.0, -0.62), vec2(0.40, 0.02), vec2(0.88, -0.42),
                                 vec2(0.72, 0.30) };
    float crown(vec2 p) {
        float d = dot(p - CROWN[0], p - CROWN[0]);
        float s = 1.0;
        for (int i = 0, j = 6; i < 7; j = i, i++) {
            vec2 e = CROWN[j] - CROWN[i];
            vec2 w = p - CROWN[i];
            vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
            d = min(d, dot(b, b));
            bvec3 c = bvec3(p.y >= CROWN[i].y, p.y < CROWN[j].y, e.x * w.y > e.y * w.x);
            if (all(c) || all(!c)) s = -s;
        }
        float poly = s * sqrt(d);
        vec2 q = abs(p - vec2(0.0, 0.47)) - vec2(0.72, 0.09);
        float band = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0);
        return min(poly, band);
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
    // How many pieces a piece that must capture takes (prototypes/game.html?count=a): one
    // pip per piece on its ring, 28 degrees apart and centred over the top, light with a
    // red rim; past five, one larger red pip with the number. Over everything of the
    // piece, so a stacked king's upper disc doesn't hide them.
    float seg(vec2 p, vec2 a, vec2 b) {
        vec2 pa = p - a, ba = b - a;
        return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
    }
    // A digit's strokes' distance at p, the digit spanning x -0.5..0.5 and y -1..1 (down).
    float digit(vec2 p, int d) {
        const int SEGS[10] = { 0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F };
        int m = SEGS[clamp(d, 0, 9)];
        float r = 1e5;
        if ((m & 1) != 0) r = min(r, seg(p, vec2(-0.5, -1.0), vec2(0.5, -1.0)));
        if ((m & 2) != 0) r = min(r, seg(p, vec2(0.5, -1.0), vec2(0.5, 0.0)));
        if ((m & 4) != 0) r = min(r, seg(p, vec2(0.5, 0.0), vec2(0.5, 1.0)));
        if ((m & 8) != 0) r = min(r, seg(p, vec2(-0.5, 1.0), vec2(0.5, 1.0)));
        if ((m & 16) != 0) r = min(r, seg(p, vec2(-0.5, 0.0), vec2(-0.5, 1.0)));
        if ((m & 32) != 0) r = min(r, seg(p, vec2(-0.5, -1.0), vec2(-0.5, 0.0)));
        if ((m & 64) != 0) r = min(r, seg(p, vec2(-0.5, 0.0), vec2(0.5, 0.0)));
        return r;
    }
    void pips(vec2 f, int n, float w) {
        vec3 red = vec3(1.0, 0.353, 0.29);
        vec3 light = vec3(1.0, 0.957, 0.925);
        if (n <= 5) {
            for (int i = 0; i < n; i++) {
                float a = radians((float(i) - 0.5 * float(n - 1)) * 28.0);
                float d = length(f - 1.24 * vec2(sin(a), -cos(a)));
                over(red, 0.55 * exp(-max(d - 0.22, 0.0) * 9.0));
                over(red, fill(d - 0.30, w));
                over(light, fill(d - 0.22, w));
            }
            return;
        }
        vec2 c = f - vec2(0.0, -1.24);
        float d = length(c);
        over(red, 0.55 * exp(-max(d - 0.40, 0.0) * 9.0));
        over(light, fill(d - 0.46, w));
        over(red, fill(d - 0.40, w));
        float s = 0.17;         // a digit's half height is 0.17 radii, its stroke 0.035
        float t = n < 10 ? digit(c / s, n) : min(digit((c - vec2(-0.12, 0.0)) / s, n / 10 % 10),
                                                 digit((c - vec2(0.12, 0.0)) / s, n % 10));
        over(light, fill(t * s - 0.035, w));
    }
    // The lookout's piece in danger, or its crowning ghost king (board::DRAINED): the color
    // drained, a little darker, and tinted red for danger (CSS grayscale(1)
    // brightness(0.66) contrast(0.85), prototypes/coach.html's `drain`, then the red); a
    // hint's ghost (board::LIGHT) lighter.
    vec3 marked(vec3 c, float k) {
        if (k > 0.5) {
            float grey = dot(c, vec3(0.2126, 0.7152, 0.0722)) * 0.66;
            return min(vec3((grey - 0.5) * 0.85 + 0.5) * vec3(1.45, 0.68, 0.62), 1.0);
        }
        return k < -0.5 ? mix(c, vec3(1.0), 0.2) : c;
    }

[shader("fragment")]
float4 piece_fragment(Varyings v) : SV_Target0 {
    use_theme(root.theme);
    time = root.time;
    hole = root.hole;
        vec2 p = v.local;
        bool black = v.look.x > 0.5;
        float sel = v.look.z;
        float lift = v.extra.y;
        float side = v.extra.z;
        float scale = 1.0 + 0.05 * sel;
        float w = v.extra.w / scale;            // one pixel in the face's units
        vec3 face = black ? b_face.rgb : w_face.rgb;
        vec3 sidec = black ? mix(face, vec3(0.0), 0.5) : face * face * 0.92;
        // A win's glow passing: its square lit in the glow color at 40%, as the last
        // move's squares are at 16%, under everything of the piece.
        if (v.win.y > 0.0) {
            vec2 q = abs(p) - v.win.z;
            over(glow.rgb, 0.4 * v.win.y * fill(max(q.x, q.y), w));
        }
        // The side to move: a ring an eighth of the radius wide in the glow color at 80%
        // right round the disc, and a soft glow, under the piece and its shadow (CSS
        // `0 0 0 4px` and `0 0 22px 4px` on a 64 px disc); fainter as y falls, which
        // pulses it while the computer thinks.
        if (v.ring.y > 0.0) {
            float rr = length(p);
            over(glow.rgb, v.ring.y * 0.45 * (1.0 - smoothstep(-0.34, 0.34, rr - 1.125)));
            over(glow.rgb, v.ring.y * 0.8 * fill(abs(rr - 1.0625) - 0.0625, w));
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
        bool stack = v.look.y > 1.5;
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
            over(marked(sc, v.ring.w), fill(length(vec2(f.x, sy)) - 1.0, w));
            // The top is flat and matte, as a turned disc's is: one color and one height,
            // with a narrow groove cut into it at 70% of the radius and only the outer
            // edge rounded. The light from above catches the outer edge's upper side
            // softly; in the groove, which is concave, it catches the wall that faces it,
            // nearer the center on the top half, and leaves the far wall in shade.
            vec3 col = man_top(face, f, r, dir, black);
            if (v.look.y > 0.5 && !stack) {
                vec3 cc = black ? vec3(0.914, 0.769, 0.416) : crown_w.rgb;
                col = mix(col, cc, fill(0.56 * crown(f / 0.56), w));
            }
            over(marked(col, v.ring.w), fill(r - 1.0, w));
            if (k == 0) rings(r, sel, v.extra.x, w);
        }
        if (v.ring.z > 0.5) pips((p + vec2(0.0, lift)) / scale, int(v.ring.z + 0.5), w);
        // Dimmed with the board under a win, as a black fill over both would.
        vec4 result = vec4(acc.rgb * (1.0 - v.win.x), acc.a) * v.look.w;
        // Over the UI in a transition, hidden where the board passes unless it lies on it.
        if (hole.z > 0.0 && v.win.w < 0.5) {
            vec2 h = 0.5 * vec2(hole.z, time.y > 0.0 ? time.y : hole.z);
            result *= clamp(0.5 + box(v.position.xy, hole.xy + h, h, hole.w), 0.0, 1.0);
        }
        return result;
}
