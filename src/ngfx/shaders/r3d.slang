// What the 3D board's modules share (task 065; written by scripts/ngfx_3d_shaders.py from
// src/render3d/shaders.goose): one root for all of them, the textures as GLSL's samplers,
// and gfx's column-major matrices. Not a module of its own.
#pragma once
#include "glsl.slang"

typealias ivec3 = int3;
typealias bvec2 = bool2;
typealias bvec4 = bool4;
bool2 glsl_not(bool2 c) { return !c; }
bool3 glsl_not(bool3 c) { return !c; }
bool4 glsl_not(bool4 c) { return !c; }
vec2 mod(vec2 x, float y) { return x - y * floor(x / y); }
vec3 mod(vec3 x, float y) { return x - y * floor(x / y); }
vec2 mod(vec2 x, vec2 y) { return x - y * floor(x / y); }
vec3 mod(vec3 x, vec3 y) { return x - y * floor(x / y); }

// gfx's mat4: four columns, multiplied as GLSL's m * v.
struct Mat { vec4 c0; vec4 c1; vec4 c2; vec4 c3; };
vec4 xf(Mat m, vec4 v) { return m.c0 * v.x + m.c1 * v.y + m.c2 * v.z + m.c3 * v.w; }

#include "r3d_frame.slang"

// Every 3D module's root (render3d.goose's Root): the frame's block, the uniform
// blocks' float4s in the order each module's header lists, up to three storage buffers,
// the vertices (mesh::Vertex, ten floats), and eight texture and sampler slots.
struct Root {
    Frame* frame;
    vec4* u;
    vec4* buf0;
    vec4* buf1;
    vec4* buf2;
    float* verts;
    uint4 tex0; uint4 tex1;
    uint4 smp0; uint4 smp1;
};
GPU_ROOT(Root, root);

// sampler2D: a texture and its sampler.
struct Tex {
    uint t; uint s;
    __init(uint t_, uint s_) { t = t_; s = s_; }
};
vec4 glsl_texture(Tex t, vec2 uv) { return gpu_texture<Texture2D<float4>>(t.t).Sample(gpu_sampler(t.s), uv); }
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
