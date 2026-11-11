// scene.goose's FADE_FRAG: the plain fade in a pass's part `to` (pixels: origin, size).
#include "common.slang"

struct Root { vec4 to; vec4 top; vec4 low; vec4 light; };
GPU_ROOT(Root, root);

[shader("vertex")]
FullOut fade_vertex(uint i : SV_VertexID) { return full_vertex(i); }

[shader("fragment")]
float4 fade_fragment(FullOut v) : SV_Target0 {
    return vec4(plain_fade(v.position.xy - root.to.xy, root.to.zw, root.top.rgb, root.low.rgb, root.light.rgb), 1.0);
}
