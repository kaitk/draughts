// The GLSL names the gfx shaders were written with, so their bodies carry over to Slang
// as they are (task 065): its vector types, mix, fract, mod, and two-argument atan; and
// textures by their heap index. Included by common.slang and r3d.slang.
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

