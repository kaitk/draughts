// What the shaders ngfx alone has share (down.slang and mip.slang; task 065): a
// full-screen triangle and a texel read by the texture's heap index. The shaders written
// from gfx's GLSL include glsl.slang instead.
#pragma once
#include <NoGraphicsAPI/shader.slang>

// A full-screen triangle; uv 0..2 down and right.
struct FullOut { float4 position : SV_Position; float2 uv : TEXCOORD0; };
FullOut full_vertex(uint i) {
    FullOut o;
    float2 p = float2(float((i << 1) & 2), float(i & 2));
    o.uv = p;
    o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return o;
}

float4 fetch(uint t, int2 p) { return gpu_texture<Texture2D<float4>>(t).Load(int3(p, 0)); }
