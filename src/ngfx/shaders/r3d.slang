// What the 3D board's modules share (task 065; written by scripts/ngfx_3d_shaders.py from
// src/render3d/shaders.goose): one root for all of them and gfx's column-major matrices.
// Not a module of its own.
#pragma once
#include "glsl.slang"

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
