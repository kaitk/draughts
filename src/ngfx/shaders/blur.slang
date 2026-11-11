// scene.goose's BLUR_FRAG: one pass of a Gaussian, across or down.
#include "common.slang"

// dir: one texel's step in the source, sigma in source texels, one target pixel in uv.
struct Root { uint src; uint smp; uint pad0; uint pad1; vec4 dir; };
GPU_ROOT(Root, root);

[shader("vertex")]
FullOut blur_vertex(uint i : SV_VertexID) { return full_vertex(i); }

[shader("fragment")]
float4 blur_fragment(FullOut v) : SV_Target0 {
    vec4 dir = root.dir;
    vec2 uv = v.position.xy * dir.w;
    vec3 sum = vec3(0.0);
    float total = 0.0;
    for (int i = -17; i <= 17; i++) {
        float w = exp(-0.5 * float(i * i) / (dir.z * dir.z));
        sum += w * tex(root.src, root.smp, uv + float(i) * dir.xy).rgb;
        total += w;
    }
    return vec4(sum / total, 1.0);
}
