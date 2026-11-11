// scene.goose's SHRINK_FRAG: a part of the source averaged into a part of the target,
// taps spread evenly across each target pixel's footprint.
#include "common.slang"

// from: the source's part in uv (origin, size); to: the target's in pixels.
struct Root { uint src; uint smp; uint pad0; uint pad1; vec4 from; vec4 to; };
GPU_ROOT(Root, root);

[shader("vertex")]
FullOut shrink_vertex(uint i : SV_VertexID) { return full_vertex(i); }

[shader("fragment")]
float4 shrink_fragment(FullOut v) : SV_Target0 {
    vec4 from = root.from;
    vec4 to = root.to;
    vec2 pixel = from.zw / to.zw;
    vec2 uv = from.xy + (v.position.xy - to.xy) * pixel;
    ivec2 n = max(ivec2(ceil(pixel * vec2(tex_size(root.src)) * 0.5)), ivec2(1));
    vec3 sum = vec3(0.0);
    for (int y = 0; y < n.y; y++) {
        for (int x = 0; x < n.x; x++) {
            sum += tex(root.src, root.smp, uv + ((vec2(float(x), float(y)) + 0.5) / vec2(n) - 0.5) * pixel).rgb;
        }
    }
    return vec4(sum / float(n.x * n.y), 1.0);
}
