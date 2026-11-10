// What every ngfx shader of the app shares (task 065): NoGraphicsAPI's helpers, the GLSL
// names the gfx shaders were written with (src/app/draw.goose and the others), so their
// bodies carry over as they are, and the blocks they share: the plain fade, the theme,
// the quad's corners and the rounded rect, and a man's top. Each module #includes this.
#pragma once
#include <NoGraphicsAPI/shader.slang>

typealias vec2 = float2;
typealias vec3 = float3;
typealias vec4 = float4;
typealias ivec2 = int2;
typealias ivec4 = int4;
typealias uvec4 = uint4;
typealias bvec3 = bool3;
#define mix lerp
#define fract frac

// GLSL's mod, x - y floor(x / y), which HLSL's fmod is not for negative x.
float mod(float x, float y) { return x - y * floor(x / y); }
// GLSL's two-argument atan.
float atan(float y, float x) { return atan2(y, x); }

// A sampled texture by its heap index, and the sampler by its.
float4 tex(uint t, uint s, float2 uv) {
    return gpu_texture<Texture2D<float4>>(t).Sample(gpu_sampler(s), uv);
}
float4 tex_lod(uint t, uint s, float2 uv, float lod) {
    return gpu_texture<Texture2D<float4>>(t).SampleLevel(gpu_sampler(s), uv, lod);
}
float4 fetch(uint t, int2 p) { return gpu_texture<Texture2D<float4>>(t).Load(int3(p, 0)); }
int2 tex_size(uint t) {
    uint w, h;
    gpu_texture<Texture2D<float4>>(t).GetDimensions(w, h);
    return int2(w, h);
}

// A full-screen triangle; uv 0..2 down and right.
struct FullOut { float4 position : SV_Position; float2 uv : TEXCOORD0; };
FullOut full_vertex(uint i) {
    FullOut o;
    vec2 p = vec2(float((i << 1) & 2), float(i & 2));
    o.uv = p;
    o.position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    return o;
}

// Pixels to clip space, y down as NoGraphicsAPI's is.
float4 clip_of(vec2 px, vec2 screen) {
    return vec4(px.x / screen.x * 2.0 - 1.0, px.y / screen.y * 2.0 - 1.0, 0.0, 1.0);
}

// src/render3d/shaders.goose's FADE_FN.
vec3 plain_fade(vec2 px, vec2 s, vec3 top, vec3 low, vec3 light) {
    vec2 q = px / s - 0.5;
    float m = max(s.x, s.y);
    vec3 c = mix(top, low, smoothstep(0.0, 1.0, px.y / s.y));
    float r = length(vec2(q.x * (s.x / m) / 0.62, (q.y - 0.04) * (s.y / m) / 0.5));
    c = mix(c, light, 0.22 * (1.0 - smoothstep(0.0, 1.0, r)));
    c *= 1.0 - 0.3 * smoothstep(0.15, 0.6, dot(q, q));
    float n = fract(sin(dot(floor(px), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    return pow(min(c, vec3(1.0)), vec3(1.0 / 2.2)) + n / 255.0;
}

// theme::Theme, as draw.goose's THEME_BLOCK names its fields; set from the root by
// use_theme() at the top of an entry point.
struct Theme {
    vec4 light; vec4 dark; vec4 frame; vec4 w_face; vec4 b_face; vec4 crown_w;
    vec4 glow; vec4 page; vec4 kind; vec4 glass; vec4 text;
    vec4 fade_top; vec4 fade_low; vec4 fade_light;
};
static vec4 light, dark, frame, w_face, b_face, crown_w, glow, page, kind, glass, text, fade_top, fade_low, fade_light;
void use_theme(Theme t) {
    light = t.light; dark = t.dark; frame = t.frame; w_face = t.w_face; b_face = t.b_face;
    crown_w = t.crown_w; glow = t.glow; page = t.page; kind = t.kind; glass = t.glass; text = t.text;
    fade_top = t.fade_top; fade_low = t.fade_low; fade_light = t.fade_light;
}
vec3 theme_fade(vec2 px, vec2 s) { return plain_fade(px, s, fade_top.rgb, fade_low.rgb, fade_light.rgb); }
int theme_index() { return int(kind.x); }

// draw.goose's SHARED_BLOCK.
static const vec2 CORNERS[6] = { vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
                                 vec2(0.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0) };
float box(vec2 p, vec2 c, vec2 h, float r) {
    vec2 q = abs(p - c) - h + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}
vec3 tint(vec3 c, float a) { return a > 0.0 ? mix(c, vec3(1.0), a) : mix(c, vec3(0.0), -a); }
static vec4 acc = vec4(0.0);
void over(vec3 c, float a) { acc = vec4(c * a, a) + acc * (1.0 - a); }

// draw.goose's MAN_BLOCK.
vec3 lit(vec3 c, float a) { return a > 0.0 ? mix(c, vec3(1.0), a) : mix(c, c * c * 0.85, -a); }
float shoulder(float r, float a, float b, float dy) {
    float th = 1.45 * clamp((r - a) / (b - a), 0.0, 1.0);
    return 0.7071 * (-dy * sin(th) + cos(th) - 1.0);
}
float groove(float r, float a, float b, float dy) {
    float t = (r - a) / (b - a);
    if (t <= 0.0 || t >= 1.0) return 0.0;
    return -dy * sin(6.2831853 * t);
}
vec3 man_top(vec3 face, vec2 f, float r, vec2 dir, bool black) {
    vec3 col = tint(face, -0.02 * f.y);
    float l = shoulder(r, 0.86, 1.0, dir.y);
    col = lit(col, l > 0.0 ? (black ? 1.0 : 1.2) * l : (black ? 0.28 : 0.4) * l);
    float g = groove(r, 0.63, 0.76, dir.y);
    col = lit(col, g > 0.0 ? (black ? 0.4 : 0.5) * g : (black ? 0.6 : 1.2) * g);
    return lit(col, -(black ? 0.3 : 0.45) * (1.0 - smoothstep(0.0, 0.05, abs(r - 0.695))));
}

// draw.goose's STACK_BLOCK.
static const float STACK = 2.3636;
