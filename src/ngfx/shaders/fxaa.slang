// FXAA over the 3D board's pass drawn at 1x (render3d.goose's antialias, --aa fxaa): FXAA
// 3.11's quality algorithm (Timothy Lottes, 2011), written here. Where the luma's local
// contrast is high, it finds the edge's direction and searches along it both ways for
// its ends, then samples the pass shifted across the edge by how far the pixel is from
// the nearer end, or by the subpixel blur where that is more. Luma from gamma-space
// colors, as FXAA wants; one pass, a full-screen triangle.
#include <NoGraphicsAPI/shader.slang>

// color: the pass; linear: a clamped linear sampler; metrics: 1 / width, 1 / height,
// width, height.
struct Root { uint color; uint linear; uint pad0; uint pad1; float4 metrics; };
GPU_ROOT(Root, root);

// FXAA 3.11's "high quality" thresholds and its preset 39's twelve search steps.
static const float EDGE_MIN = 0.0312;   // contrast under this is left alone (dark areas)
static const float EDGE_MAX = 0.125;    // ... and under this share of the local maximum
static const float SUBPIX = 0.75;       // how much of the subpixel blur to apply
static const int STEPS = 12;
static const float STEP[12] = { 1.0, 1.0, 1.0, 1.0, 1.0, 1.5, 2.0, 2.0, 2.0, 2.0, 4.0, 8.0 };

float4 at(float2 uv) { return gpu_texture<Texture2D<float4>>(root.color).SampleLevel(gpu_sampler(root.linear), uv, 0); }
float luma(float4 c) { return dot(c.rgb, float3(0.299, 0.587, 0.114)); }
float luma_at(float2 uv) { return luma(at(uv)); }

struct Corner { float4 position : SV_Position; float2 uv : TEXCOORD0; };

[shader("vertex")]
Corner fxaa_vertex(uint i : SV_VertexID) {
    Corner o;
    float2 p = float2(float((i << 1) & 2), float(i & 2));
    o.uv = p;
    o.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
    return o;
}

[shader("fragment")]
float4 fxaa_fragment(Corner v) : SV_Target0 {
    float2 px = root.metrics.xy;
    float2 uv = v.uv;
    float4 center = at(uv);
    float m = luma(center);
    // y down: n above, s below.
    float n = luma_at(uv + float2(0.0, -px.y));
    float s = luma_at(uv + float2(0.0, px.y));
    float w = luma_at(uv + float2(-px.x, 0.0));
    float e = luma_at(uv + float2(px.x, 0.0));
    float hi = max(m, max(max(n, s), max(w, e)));
    float lo = min(m, min(min(n, s), min(w, e)));
    float range = hi - lo;
    if (range < max(EDGE_MIN, hi * EDGE_MAX)) return center;

    float nw = luma_at(uv + float2(-px.x, -px.y));
    float ne = luma_at(uv + float2(px.x, -px.y));
    float sw = luma_at(uv + float2(-px.x, px.y));
    float se = luma_at(uv + float2(px.x, px.y));
    float ns = n + s;
    float we = w + e;
    float west = nw + sw;
    float east = ne + se;
    float north = nw + ne;
    float south = sw + se;

    // A horizontal edge changes most from row to row.
    float across_rows = abs(west - 2.0 * w) + 2.0 * abs(ns - 2.0 * m) + abs(east - 2.0 * e);
    float across_cols = abs(north - 2.0 * n) + 2.0 * abs(we - 2.0 * m) + abs(south - 2.0 * s);
    bool horizontal = across_rows >= across_cols;

    // The side of the edge the pixel is on: the neighbour across it with the larger step.
    float before = horizontal ? n : w;
    float after = horizontal ? s : e;
    float g_before = before - m;
    float g_after = after - m;
    bool to_before = abs(g_before) >= abs(g_after);
    float gradient = 0.25 * max(abs(g_before), abs(g_after));
    float step = horizontal ? px.y : px.x;
    float mid;
    if (to_before) { step = -step; mid = 0.5 * (before + m); } else { mid = 0.5 * (after + m); }

    // Along the edge, half a pixel across it, both ways until the luma leaves the edge's.
    float2 on = uv;
    if (horizontal) on.y += 0.5 * step; else on.x += 0.5 * step;
    float2 along = horizontal ? float2(px.x, 0.0) : float2(0.0, px.y);
    float2 uv1 = on - along * STEP[0];
    float2 uv2 = on + along * STEP[0];
    float end1 = luma_at(uv1) - mid;
    float end2 = luma_at(uv2) - mid;
    bool done1 = abs(end1) >= gradient;
    bool done2 = abs(end2) >= gradient;
    if (!done1) uv1 -= along * STEP[1];
    if (!done2) uv2 += along * STEP[1];
    for (int i = 2; i < STEPS && !(done1 && done2); i++) {
        if (!done1) { end1 = luma_at(uv1) - mid; done1 = abs(end1) >= gradient; }
        if (!done2) { end2 = luma_at(uv2) - mid; done2 = abs(end2) >= gradient; }
        if (!done1) uv1 -= along * STEP[i];
        if (!done2) uv2 += along * STEP[i];
    }

    float d1 = horizontal ? uv.x - uv1.x : uv.y - uv1.y;
    float d2 = horizontal ? uv2.x - uv.x : uv2.y - uv.y;
    bool nearer1 = d1 < d2;
    float shift = 0.5 - min(d1, d2) / (d1 + d2);
    // Only where the nearer end's luma goes the other way from the pixel's.
    bool darker = m < mid;
    bool right_way = ((nearer1 ? end1 : end2) < 0.0) != darker;
    shift = right_way ? shift : 0.0;

    // The subpixel part: how far the pixel stands out of its 3 x 3's average.
    float average = (2.0 * (ns + we) + west + east) / 12.0;
    float sub = saturate(abs(average - m) / range);
    sub = (-2.0 * sub + 3.0) * sub * sub;
    shift = max(shift, sub * sub * SUBPIX);

    float2 to = uv;
    if (horizontal) to.y += shift * step; else to.x += shift * step;
    return at(to);
}
