// The GLSL names the gfx shaders were written with, so their bodies carry over to Slang
// as they are (task 065): its vector types, mix, fract, mod, not, and two-argument atan;
// and its samplers, a texture and a sampler by their heap indices. Included by the
// modules scripts/ngfx_2d_shaders.py writes, by r3d.slang, and by common.slang.
#pragma once
#include <NoGraphicsAPI/shader.slang>

typealias vec2 = float2;
typealias vec3 = float3;
typealias vec4 = float4;
typealias ivec2 = int2;
typealias ivec3 = int3;
typealias ivec4 = int4;
typealias uvec4 = uint4;
typealias bvec2 = bool2;
typealias bvec3 = bool3;
typealias bvec4 = bool4;
#define mix lerp
#define fract frac

// GLSL's mod, x - y floor(x / y), which HLSL's fmod is not for negative x.
float mod(float x, float y) { return x - y * floor(x / y); }
vec2 mod(vec2 x, float y) { return x - y * floor(x / y); }
vec3 mod(vec3 x, float y) { return x - y * floor(x / y); }
vec2 mod(vec2 x, vec2 y) { return x - y * floor(x / y); }
vec3 mod(vec3 x, vec3 y) { return x - y * floor(x / y); }
// GLSL's not(), which the generators write as glsl_not.
bool2 glsl_not(bool2 c) { return !c; }
bool3 glsl_not(bool3 c) { return !c; }
bool4 glsl_not(bool4 c) { return !c; }
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

// sampler2D: a texture and its sampler.
struct Tex {
    uint t; uint s;
    __init(uint t_, uint s_) { t = t_; s = s_; }
};
vec4 glsl_texture(Tex t, vec2 uv) { return gpu_texture<Texture2D<float4>>(t.t).Sample(gpu_sampler(t.s), uv); }
vec4 glsl_texture_lod(Tex t, vec2 uv, float lod) {
    return gpu_texture<Texture2D<float4>>(t.t).SampleLevel(gpu_sampler(t.s), uv, lod);
}
vec4 glsl_texture_grad(Tex t, vec2 uv, vec2 dx, vec2 dy) {
    return gpu_texture<Texture2D<float4>>(t.t).SampleGrad(gpu_sampler(t.s), uv, dx, dy);
}
vec4 glsl_texel_fetch(Tex t, ivec2 p, int lod) { return gpu_texture<Texture2D<float4>>(t.t).Load(int3(p, lod)); }
ivec2 glsl_texture_size(Tex t, int lod) {
    uint w, h;
    gpu_texture<Texture2D<float4>>(t.t).GetDimensions(w, h);
    return ivec2(int(w), int(h));
}

// sampler2DShadow: a depth texture and a comparison sampler.
struct ShadowTex {
    uint t; uint s;
    __init(uint t_, uint s_) { t = t_; s = s_; }
};
float glsl_texture(ShadowTex t, vec3 p) {
    return gpu_texture<Texture2D<float>>(t.t).SampleCmpLevelZero(gpu_sampler<SamplerComparisonState>(t.s), p.xy, p.z);
}
ivec2 glsl_texture_size(ShadowTex t, int lod) {
    uint w, h;
    gpu_texture<Texture2D<float>>(t.t).GetDimensions(w, h);
    return ivec2(int(w), int(h));
}
