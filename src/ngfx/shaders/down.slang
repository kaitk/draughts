// The 3D board's pass, drawn at twice the size, shrunk into its target (render3d.goose's
// draw): each pixel the average of its 2 × 2, in place of gfx's 4× MSAA resolve, which
// NoGraphicsAPI has no way to do.
#include "common.slang"

struct Root { uint src; uint pad0; uint pad1; uint pad2; };
GPU_ROOT(Root, root);

[shader("vertex")]
FullOut down_vertex(uint i : SV_VertexID) { return full_vertex(i); }

[shader("fragment")]
float4 down_fragment(FullOut v) : SV_Target0 {
    int2 p = int2(v.position.xy) * 2;
    return 0.25 * (fetch(root.src, p) + fetch(root.src, p + int2(1, 0)) + fetch(root.src, p + int2(0, 1))
                 + fetch(root.src, p + int2(1, 1)));
}
