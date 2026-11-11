// SMAA 1x over the 3D board's pass drawn at 1x (render3d.goose's antialias, --aa smaa;
// task 071): edges from the colors' luma, the blending weights for them from SMAA's area
// and search tables, and each pixel blended with its neighbours by them. Three passes,
// each a full-screen triangle. The shader is SMAA's own (third_party/smaa/SMAA.hlsl,
// through tools/smaa_glsl.py's smaa.glsl, two conversions rewritten) with its porting
// macros, as the ngfx build's smaa.slang has them. Gamma-space colors are blended as
// they are, as the MSAA resolve of the same RGBA8 target averages them.
//
// One linear sampler for every texture, gfx's samplers going with their textures: SMAA's
// point samples all fall on texel centres, where linear reads the same.
namespace smaa;

// SMAA_RT_METRICS: 1 / width, 1 / height, width, height; a uniform of each stage. Each
// stage takes only its own half of SMAA's functions.
let VS_METRICS = """
    #define SMAA_INCLUDE_PS 0
    layout(set = 1, binding = 0) uniform Metrics { vec4 metrics; };
    """;
let FS_METRICS = """
    #define SMAA_INCLUDE_VS 0
    layout(set = 3, binding = 0) uniform Metrics { vec4 metrics; };
    """;

let DEFS = """
    #define SMAA_CUSTOM_SL 1
    #define SMAA_PRESET_HIGH 1
    #define SMAA_RT_METRICS metrics
    #define SMAATexture2D(tex) sampler2D tex
    #define SMAATexturePass2D(tex) tex
    #define SMAASampleLevelZero(tex, coord) textureLod(tex, coord, 0.0)
    #define SMAASampleLevelZeroPoint(tex, coord) textureLod(tex, coord, 0.0)
    #define SMAASampleLevelZeroOffset(tex, coord, offset) textureLod(tex, coord + vec2(offset) * SMAA_RT_METRICS.xy, 0.0)
    #define SMAASample(tex, coord) texture(tex, coord)
    #define SMAASamplePoint(tex, coord) texture(tex, coord)
    #define SMAASampleOffset(tex, coord, offset) texture(tex, coord + vec2(offset) * SMAA_RT_METRICS.xy)
    #define SMAA_FLATTEN
    #define SMAA_BRANCH
    #define lerp(a, b, t) mix(a, b, t)
    #define saturate(a) clamp(a, 0.0, 1.0)
    #define mad(a, b, c) (a * b + c)
    #define float2 vec2
    #define float3 vec3
    #define float4 vec4
    #define int2 ivec2
    #define int3 ivec3
    #define int4 ivec4
    #define bool2 bvec2
    #define bool3 bvec3
    #define bool4 bvec4
    #include "smaa.glsl"
    """;

// A full-screen triangle; uv 0..2 from the top left, down and right, as SMAA's offsets
// and tables take texture coordinates. (shaders::FULL_VERT's uv runs up from the bottom,
// which its copies and blurs don't see.)
let CORNER = """
    vec2 corner() {
        vec2 p = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
        gl_Position = vec4(p.x * 2.0 - 1.0, 1.0 - p.y * 2.0, 0.0, 1.0);
        return p;
    }
    """;

let EDGES_VERT = """
    layout(location = 0) out vec2 v_uv;
    layout(location = 1) out vec4 v_o0;
    layout(location = 2) out vec4 v_o1;
    layout(location = 3) out vec4 v_o2;
    void main() {
        v_uv = corner();
        vec4 offset[3];
        SMAAEdgeDetectionVS(v_uv, offset);
        v_o0 = offset[0];
        v_o1 = offset[1];
        v_o2 = offset[2];
    }
    """;
let EDGES_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 1) in vec4 v_o0;
    layout(location = 2) in vec4 v_o1;
    layout(location = 3) in vec4 v_o2;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D color_tex;
    void main() {
        vec4 offset[3] = vec4[3](v_o0, v_o1, v_o2);
        result = vec4(SMAALumaEdgeDetectionPS(v_uv, offset, color_tex), 0.0, 0.0);
    }
    """;

let WEIGHTS_VERT = """
    layout(location = 0) out vec2 v_uv;
    layout(location = 1) out vec2 v_pix;
    layout(location = 2) out vec4 v_o0;
    layout(location = 3) out vec4 v_o1;
    layout(location = 4) out vec4 v_o2;
    void main() {
        v_uv = corner();
        vec4 offset[3];
        vec2 pix;
        SMAABlendingWeightCalculationVS(v_uv, pix, offset);
        v_pix = pix;
        v_o0 = offset[0];
        v_o1 = offset[1];
        v_o2 = offset[2];
    }
    """;
let WEIGHTS_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 1) in vec2 v_pix;
    layout(location = 2) in vec4 v_o0;
    layout(location = 3) in vec4 v_o1;
    layout(location = 4) in vec4 v_o2;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D edges_tex;
    layout(set = 2, binding = 1) uniform sampler2D area_tex;
    layout(set = 2, binding = 2) uniform sampler2D search_tex;
    void main() {
        vec4 offset[3] = vec4[3](v_o0, v_o1, v_o2);
        result = SMAABlendingWeightCalculationPS(v_uv, v_pix, offset, edges_tex, area_tex, search_tex, vec4(0.0));
    }
    """;

let BLEND_VERT = """
    layout(location = 0) out vec2 v_uv;
    layout(location = 1) out vec4 v_offset;
    void main() {
        v_uv = corner();
        vec4 offset;
        SMAANeighborhoodBlendingVS(v_uv, offset);
        v_offset = offset;
    }
    """;
let BLEND_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 1) in vec4 v_offset;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D color_tex;
    layout(set = 2, binding = 1) uniform sampler2D blend_tex;
    void main() {
        result = SMAANeighborhoodBlendingPS(v_uv, v_offset, color_tex, blend_tex);
    }
    """;
