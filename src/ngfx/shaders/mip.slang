// A baked surface's next mip (render3d.goose's mips): each texel the average of the 2 × 2
// under it in the level above, drawn as a pass into the level, so an sRGB target averages
// in linear light, as SDL_GPU's mip blits do; ngfx's generate_mips takes no sRGB.
#include "common.slang"

// src: the texture; level: the one read.
struct Root { uint src; uint level; uint pad0; uint pad1; };
GPU_ROOT(Root, root);

[shader("vertex")]
FullOut mip_vertex(uint i : SV_VertexID) { return full_vertex(i); }

[shader("fragment")]
float4 mip_fragment(FullOut v) : SV_Target0 {
    Texture2D<float4> t = gpu_texture<Texture2D<float4>>(root.src);
    int2 p = int2(v.position.xy) * 2;
    int l = int(root.level);
    uint w, h, n;
    t.GetDimensions(root.level, w, h, n);
    int2 last = int2(int(w), int(h)) - 1;
    return 0.25 * (t.Load(int3(min(p, last), l)) + t.Load(int3(min(p + int2(1, 0), last), l))
                 + t.Load(int3(min(p + int2(0, 1), last), l)) + t.Load(int3(min(p + int2(1, 1), last), l)));
}
