// widgets.goose's COMPOSE_FRAG: the kept UI layer laid over the screen texel for texel,
// premultiplied as the quads drew it.
#include "common.slang"

struct Root { uint layer; uint pad0; uint pad1; uint pad2; };
GPU_ROOT(Root, root);

[shader("vertex")]
FullOut compose_vertex(uint i : SV_VertexID) { return full_vertex(i); }

[shader("fragment")]
float4 compose_fragment(FullOut v) : SV_Target0 { return fetch(root.layer, ivec2(v.position.xy)); }
