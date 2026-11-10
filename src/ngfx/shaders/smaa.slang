// SMAA 1x over the 3D board's pass drawn at 1x (render3d.goose's antialias, --aa smaa):
// edges from the colors' luma, the blending weights for them from SMAA's area and search
// tables, and each pixel blended with its neighbours by them. Three passes, each a
// full-screen triangle; the shader is SMAA's own (third_party/smaa/SMAA.hlsl), unchanged,
// through its porting macros. Gamma-space colors are blended as they are, as gfx's MSAA
// resolve of the same RGBA8 target averages them.
#include <NoGraphicsAPI/shader.slang>

// color: the pass; edges and weights: the passes' own targets; area and search: SMAA's
// tables; linear and point: clamped samplers; metrics: 1 / width, 1 / height, width,
// height.
struct Root {
    uint color; uint edges; uint weights; uint area; uint search; uint linear; uint point; uint pad0;
    float4 metrics;
};
GPU_ROOT(Root, root);

#define SMAA_CUSTOM_SL 1
#define SMAA_PRESET_HIGH 1
#define SMAA_RT_METRICS root.metrics
#define SMAATexture2D(tex) Texture2D tex
#define SMAATexturePass2D(tex) tex
#define SMAASampleLevelZero(tex, coord) tex.SampleLevel(gpu_sampler(root.linear), coord, 0)
#define SMAASampleLevelZeroPoint(tex, coord) tex.SampleLevel(gpu_sampler(root.point), coord, 0)
#define SMAASampleLevelZeroOffset(tex, coord, offset) tex.SampleLevel(gpu_sampler(root.linear), coord, 0, offset)
#define SMAASample(tex, coord) tex.Sample(gpu_sampler(root.linear), coord)
#define SMAASamplePoint(tex, coord) tex.Sample(gpu_sampler(root.point), coord)
#define SMAASampleOffset(tex, coord, offset) tex.Sample(gpu_sampler(root.linear), coord, offset)
#define SMAAGather(tex, coord) tex.Gather(gpu_sampler(root.linear), coord, int2(0, 0))
#define SMAA_FLATTEN [flatten]
#define SMAA_BRANCH [branch]
#include "SMAA.hlsl"

Texture2D smaa_texture(uint i) { return gpu_texture<Texture2D<float4>>(i); }

// A full-screen triangle; uv 0..2 down and right, as texture coordinates are.
struct Corner { float4 position : SV_Position; float2 uv : TEXCOORD0; };
Corner corner(uint i) {
    Corner o;
    float2 p = float2(float((i << 1) & 2), float(i & 2));
    o.uv = p;
    o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return o;
}

struct EdgesOut { float4 position : SV_Position; float2 uv : TEXCOORD0; float4 o0 : TEXCOORD1; float4 o1 : TEXCOORD2; float4 o2 : TEXCOORD3; };

[shader("vertex")]
EdgesOut edges_vertex(uint i : SV_VertexID) {
    Corner c = corner(i);
    EdgesOut o;
    o.position = c.position;
    o.uv = c.uv;
    float4 offset[3];
    SMAAEdgeDetectionVS(c.uv, offset);
    o.o0 = offset[0]; o.o1 = offset[1]; o.o2 = offset[2];
    return o;
}

[shader("fragment")]
float4 edges_fragment(EdgesOut v) : SV_Target0 {
    float4 offset[3] = { v.o0, v.o1, v.o2 };
    return float4(SMAALumaEdgeDetectionPS(v.uv, offset, smaa_texture(root.color)), 0.0, 0.0);
}

struct WeightsOut { float4 position : SV_Position; float2 uv : TEXCOORD0; float2 pix : TEXCOORD1; float4 o0 : TEXCOORD2; float4 o1 : TEXCOORD3; float4 o2 : TEXCOORD4; };

[shader("vertex")]
WeightsOut weights_vertex(uint i : SV_VertexID) {
    Corner c = corner(i);
    WeightsOut o;
    o.position = c.position;
    o.uv = c.uv;
    float4 offset[3];
    float2 pix;
    SMAABlendingWeightCalculationVS(c.uv, pix, offset);
    o.pix = pix; o.o0 = offset[0]; o.o1 = offset[1]; o.o2 = offset[2];
    return o;
}

[shader("fragment")]
float4 weights_fragment(WeightsOut v) : SV_Target0 {
    float4 offset[3] = { v.o0, v.o1, v.o2 };
    return SMAABlendingWeightCalculationPS(v.uv, v.pix, offset, smaa_texture(root.edges), smaa_texture(root.area),
                                           smaa_texture(root.search), float4(0.0, 0.0, 0.0, 0.0));
}

struct BlendOut { float4 position : SV_Position; float2 uv : TEXCOORD0; float4 o : TEXCOORD1; };

[shader("vertex")]
BlendOut blend_vertex(uint i : SV_VertexID) {
    Corner c = corner(i);
    BlendOut o;
    o.position = c.position;
    o.uv = c.uv;
    float4 offset;
    SMAANeighborhoodBlendingVS(c.uv, offset);
    o.o = offset;
    return o;
}

[shader("fragment")]
float4 blend_fragment(BlendOut v) : SV_Target0 {
    return SMAANeighborhoodBlendingPS(v.uv, v.o, smaa_texture(root.color), smaa_texture(root.weights));
}
