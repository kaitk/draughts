// The flat board's pass, draw.goose's BOARD_FRAG over the full-screen triangle: the
// photograph, the board, and its squares with their marks, worked out per pixel.
#include "common.slang"

struct BoardU {
    vec4 screen; vec4 rect; vec4 inner; vec4 scene; vec4 wrong;
    uvec4 last; uvec4 target; uvec4 via; uvec4 next; uvec4 shade;
};
// photo: the blurred copy; sharp: the photograph as it is.
struct Root { uint photo; uint sharp; uint smp; uint pad; Theme theme; BoardU u; };
GPU_ROOT(Root, root);

static vec4 screen, rect, inner, scene, wrong;
static uvec4 last, target, via, next, shade;

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
vec3 ring(vec3 c, vec3 col, float d, float r, float w, float g, float a) {
    float rd = abs(d - r) - w;
    c = mix(c, col, a * 0.45 * exp(-max(rd, 0.0) / g));
    return mix(c, col, a * clamp(0.5 - rd, 0.0, 1.0));
}

[shader("vertex")]
FullOut board_vertex(uint i : SV_VertexID) { return full_vertex(i); }

[shader("fragment")]
float4 board_fragment(FullOut v) : SV_Target0 {
    use_theme(root.theme);
    screen = root.u.screen; rect = root.u.rect; inner = root.u.inner; scene = root.u.scene; wrong = root.u.wrong;
    last = root.u.last; target = root.u.target; via = root.u.via; next = root.u.next; shade = root.u.shade;
    vec2 px = v.position.xy;
    float u = rect.z * 0.01;
    float side = max(screen.x, screen.y);
    vec2 puv = (px - 0.5 * (screen.xy - side)) / side;
    vec3 c = page.rgb;
    if (scene.x < -1.5) c = scene.y * theme_fade(px, screen.xy);
    else if (scene.x >= 1.0) c = scene.y * tex(root.photo, root.smp, puv).rgb;
    else if (scene.x <= 0.0 && scene.x > -0.5) c = scene.y * tex(root.sharp, root.smp, puv).rgb;
    else if (scene.x > 0.0) c = scene.y * mix(tex(root.sharp, root.smp, puv).rgb, tex(root.photo, root.smp, puv).rgb, scene.x);
    vec2 bc = rect.xy + 0.5 * rect.z;
    vec2 bh = vec2(0.5 * rect.z);
    float sd = box(px, bc + vec2(0.0, 1.4 * u), bh - u, rect.w);
    c *= 1.0 - 0.55 * (1.0 - smoothstep(-3.6 * u, 3.6 * u, sd));
    float fd = box(px, bc, bh, rect.w);
    vec2 ic = inner.xy + 0.5 * inner.z;
    float id = box(px, ic, vec2(0.5 * inner.z), 0.5 * rect.w);
    if (fd < 1.0 && id > -1.0) {
        float lw = 0.5 * (rect.z - inner.z);
        float t = clamp(-fd / lw, 0.0, 1.0);
        float ny = (px.y - bc.y) / bh.y;
        vec3 lip = tint(dark.rgb, 0.06 - 0.1 * ny);
        vec3 rim_tint = mix(light.rgb, vec3(1.0), 0.25);
        lip = mix(lip, rim_tint, (0.75 - 0.25 * ny) * (1.0 - smoothstep(0.1, 0.26, t)));
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
        int k = int(kind.x);
        float h = hash(vec2(cell));
        float a = 0.0;
        if (k == 0) {
            vec2 m = px / u + 41.0 * h;
            float fine = noise(vec2(m.x * 2.6, m.y * 0.08)) - 0.5;
            float broad = noise(m * vec2(0.35, 0.06)) - 0.5;
            a += 0.022 * fine + 0.03 * broad + 0.02 * (h - 0.5);
        } else if (k == 1) {
            vec2 m = px / u;
            float f = 0.6 * noise(m * 0.45 + 13.0 * h) + 0.4 * noise(m * 1.3);
            a += 0.07 * (f - 0.5);
        } else if (k == 2) {
            a += 0.03 * (noise(vec2(px.x / (3.0 * u), px.y / (0.35 * u))) - 0.5);
        } else {
            a += 0.02 * (noise(px / (2.0 * u)) - 0.5);
        }
        float e = fq.y * inner.w;
        a += 0.04 * (1.0 - smoothstep(0.0, 0.18 * u, e));
        s = tint(s, a);
        int sq = y * n + x;
        if (has(last, sq)) s = mix(s, glow.rgb, 0.16);
        if (has(shade, sq)) {
            vec2 e2 = min(fq, 1.0 - fq);
            s = mix(s, vec3(0.3, 0.03, 0.02), 0.3 + 0.32 * (1.0 - smoothstep(0.0, 0.25, min(e2.x, e2.y))));
        }
        float r = length(fq - 0.5) * inner.w;
        if (has(target, sq)) {
            s += glow.rgb * 0.5 * exp(-max(r - 0.15 * inner.w, 0.0) / (1.2 * u));
            s = mix(s, glow.rgb, 0.9 * clamp(0.15 * inner.w - r + 0.5, 0.0, 1.0));
        }
        if (has(via, sq)) s = ring(s, glow.rgb, r, 0.18 * inner.w, 0.25 * u, u, 1.0);
        if (has(next, sq)) {
            s += glow.rgb * 0.5 * wrong.z * exp(-max(r - 0.15 * inner.w, 0.0) / (1.2 * u));
            s = mix(s, glow.rgb, 0.9 * wrong.z * clamp(0.15 * inner.w - r + 0.5, 0.0, 1.0));
        }
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
    c *= 1.0 - scene.z * clamp(0.5 - fd, 0.0, 1.0);
    return vec4(c, 1.0);
}
