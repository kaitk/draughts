// The 3D board's shaders, GLSL 450 that embed_shader compiles with the program. One
// forward pass draws everything lit: the field, the frame, and the pieces each with their
// own build of one fragment shader (LIT_FRAG; GGX after Filament, wrap diffuse, Filament's specular antialiasing, 9 weighted
// hardware-compared shadow taps over 5 × 5 texels, analytic occlusion, an ambient of nine spherical
// harmonics taken from the photograph, a mild tonemap). The wood is baked once at
// startup by the bake shader into textures with mips.
//
// The board's measures are repeated here from mesh.goose: keep them in step.
namespace shaders;

// The block every 3D shader reads: vertex set 1 or fragment set 3, binding 0. FRAME_SET
// is defined before it.
let FRAME = """
    layout(set = FRAME_SET, binding = 0) uniform Frame {
        mat4 view_proj;
        mat4 light_view_proj;
        vec4 eye;
        vec4 light_dir;      // toward the light; w: its intensity
        vec4 light_color;
        vec4 sh[9];          // the photograph's irradiance over pi, rgb
        vec4 params;         // x: exposure, y: unused, z: ambient scale,
                             // w: squares per side (a square is 8 / w)
        vec4 screen;         // xy: the target's size in pixels, z: the board dimmed by (a win)
        vec4 glow;           // rgb: the theme's glow color, w: its strength
        vec4 selected;       // xyz: the selected piece's foot, w: its radius (0: none)
        // The theme (looks::Theme), colors linear: the pieces' colors and roughness, their
        // figure, the crown, the frame's rounded edge and its line, the board's light on
        // the pieces' sides, the backdrop's grade and lift color.
        vec4 light_piece;
        vec4 dark_piece;
        vec4 piece_fig;
        vec4 crown_color;
        vec4 edge;
        vec4 edge_line;
        vec4 bounce;
        vec4 grade;
        vec4 tint;
        vec4 frame_build;    // x: 1 one solid block, 0 four mitred pieces; y: the joint
                             // line's strength; z: 1 for stone, its u leaning at the ends;
                             // w: 1 carved
        vec4 frame_surface;  // w: how much smoother the frame's rounded edge is
        vec4 frame_map;      // x: the frame map's height over its width
    };
    const float PI = 3.14159265;
    const float FIELD = 4.0;
    const float INNER = 4.1;
    const float FRAME_W = 0.5;
    const float FRAME_TOP = 0.05;
    const float BOTTOM = -0.7;
    const float RADIUS = 0.44;
    const float HEIGHT = 0.29;
    const float EDGE_AT = 0.89;
    // Along the frame's profile (mesh.goose's uv.y): where the bullnose starts and ends.
    const float BULL_START = 0.4546;
    const float BULL_END = 0.5960;
    vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }
    """;

let VS_SET = "#define FRAME_SET 1\n";
let FS_SET = "#define FRAME_SET 3\n";

// The board (one mesh) and the pieces (one lathe mesh, per instance from a storage
// buffer of two vec4s: the foot and scale; dark, crown, selected or stacked, seed).
// draw.z: how opaque (a fading piece is drawn alone, blended); draw.w: the first
// instance it draws. A seed of 1000 or more is a piece a win's dim leaves lit.
let LIT_VERT = """
    layout(location = 0) in vec3 a_pos;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    layout(location = 3) in vec2 a_extra;          // occlusion, material
    layout(std430, set = 0, binding = 0) readonly buffer Instances { vec4 inst[]; };
    layout(set = 1, binding = 1) uniform Draw { vec4 draw; };   // x: 1 for instances
    layout(location = 0) out vec3 v_world;
    layout(location = 6) flat out float v_alpha;
    layout(location = 1) out vec3 v_normal;
    layout(location = 2) out vec2 v_uv;
    layout(location = 3) out vec2 v_extra;
    layout(location = 4) out vec3 v_local;
    layout(location = 5) flat out vec4 v_kind;
    void main() {
        vec3 world = a_pos;
        vec4 kind = vec4(0.0);
        if (draw.x > 0.5) {
            int i = gl_InstanceIndex + int(draw.w);
            vec4 a = inst[i * 2];
            kind = inst[i * 2 + 1];
            world = a.xyz + a_pos * a.w;
        }
        v_world = world;
        v_normal = a_normal;
        v_uv = a_uv;
        v_extra = a_extra;
        v_local = a_pos;
        v_kind = kind;
        v_alpha = draw.z;
        gl_Position = (draw.y > 0.5 ? light_view_proj : view_proj) * vec4(world, 1.0);
    }
    """;

// A depth-only pass still needs a fragment shader.
let EMPTY_FRAG = """
    void main() { }
    """;

// The key light's shadow, from a point pushed off the surface along its normal: a
// 5 × 5 texel box with bilinear edges in 9 hardware-compared taps, their places and
// weights from where the point falls in its texel (Castaño's filter, as The Witness
// has it); the 16 taps 1.25 texels apart it replaced covered the same 5 texels. Wants
// `shadow_map` declared before it; left out of the field's lit shader, which reads its
// shadow from FIELD_LIGHT_FRAG's map.
let SHADOW_FN = """
    #ifndef LIT_FIELD
    float shadow(vec3 p, vec3 n) {
        float nl = clamp(dot(n, light_dir.xyz), 0.0, 1.0);
        vec3 q = p + n * (0.004 + 0.012 * (1.0 - nl));
        vec4 s = light_view_proj * vec4(q, 1.0);
        vec2 size = vec2(textureSize(shadow_map, 0));
        vec2 uv = vec2(s.x * 0.5 + 0.5, 0.5 - s.y * 0.5) * size;
        float z = s.z - 0.0005;
        vec2 base = floor(uv + 0.5);
        vec2 f = uv + 0.5 - base;
        base = (base - 0.5) / size;
        vec3 w0 = vec3(4.0 - 3.0 * f.x, 7.0, 1.0 + 3.0 * f.x);
        vec3 u = vec3((3.0 - 2.0 * f.x) / w0.x - 2.0, (3.0 + f.x) / 7.0, f.x / w0.z + 2.0) / size.x;
        vec3 w1 = vec3(4.0 - 3.0 * f.y, 7.0, 1.0 + 3.0 * f.y);
        vec3 v = vec3((3.0 - 2.0 * f.y) / w1.x - 2.0, (3.0 + f.y) / 7.0, f.y / w1.z + 2.0) / size.y;
        float sum = 0.0;
        for (int j = 0; j < 3; j++) {
            for (int i = 0; i < 3; i++) {
                sum += w0[i] * w1[j] * texture(shadow_map, vec3(base + vec2(u[i], v[j]), z));
            }
        }
        return sum * (1.0 / 144.0);
    }
    #endif
    """;

// The field's light, baked into an RG8 map over the field and its inlay (the plan's
// extent) whenever the shadow map is drawn or the pieces' occlusion changes, so the
// field's pixels read one texel instead of 9 shadow taps and the 3 × 3 squares: r the
// key light's shadow (the field's normal taken as up), g the occlusion.
let FIELD_LIGHT_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2DShadow shadow_map;
    // Per square: the top of what stands there, its foot, its radius, 1 if a piece.
    layout(std430, set = 2, binding = 1) readonly buffer Squares { vec4 squares[]; };
    layout(set = 3, binding = 1) uniform Draw { vec4 draw; };   // x: 1 over the map's side
    """;

// The field's occlusion, analytic: each piece in the 3 × 3 squares round as a cylinder
// (the share of the cosine-weighted sky its angle across and its height take), and the
// frame's short inner wall as a long wall. FIELD_LIGHT_FRAG's, after SHADOW_FN.
let FIELD_LIGHT_MAIN = """
    float field_occlusion(vec3 p) {
        float vis = 1.0;
        int n = int(params.w + 0.5);
        float u = 2.0 * FIELD / params.w;
        ivec2 c = ivec2(floor((p.xz + FIELD) / u));
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                ivec2 q = c + ivec2(dx, dy);
                if (q.x < 0 || q.y < 0 || q.x >= n || q.y >= n) continue;
                vec4 s = squares[q.y * n + q.x];
                if (s.w < 0.5) continue;
                float rho = length(p.xz - ((vec2(q) + 0.5) * u - FIELD));
                float r = s.z;
                float occ;
                if (rho > r) {
                    float gap = rho - r + 0.01;
                    float top = s.x * s.x / (s.x * s.x + gap * gap);
                    float foot = s.y * s.y / (s.y * s.y + gap * gap);
                    occ = asin(r / rho) / PI * (top - foot);
                } else {
                    float foot = s.y * s.y / (s.y * s.y + r * r);
                    occ = (0.5 + 0.45 * (1.0 - rho / r)) * (1.0 - foot);
                }
                vis *= 1.0 - occ;
            }
        }
        vec2 d = max(INNER - abs(p.xz), vec2(0.0));
        float h = FRAME_TOP;
        vis *= 1.0 - 0.5 * (1.0 - d.x / sqrt(d.x * d.x + h * h));
        vis *= 1.0 - 0.5 * (1.0 - d.y / sqrt(d.y * d.y + h * h));
        return vis;
    }
    void main() {
        vec2 uv = gl_FragCoord.xy * draw.x;
        vec3 p = vec3(uv.x * 2.0 * INNER - INNER, 0.0, uv.y * 2.0 * INNER - INNER);
        result = vec4(shadow(p, vec3(0.0, 1.0, 0.0)), field_occlusion(p), 0.0, 1.0);
    }
    """;

// The lit shader, one per material (LIT_FIELD, LIT_FRAME, LIT_PIECE defined first), each
// with only the bindings and the work its material takes: the field the baked plan and
// its light, the frame its map and the shadow, a piece the shadow alone (its figure,
// crown, and top from functions of its position). SHADOW_FN goes after it.
let LIT_FIELD = "#define LIT_FIELD 1\n";
let LIT_FRAME = "#define LIT_FRAME 1\n";
let LIT_PIECE = "#define LIT_PIECE 1\n";
let LIT_DECL = """
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in vec2 v_extra;
    layout(location = 4) in vec3 v_local;
    layout(location = 5) flat in vec4 v_kind;
    layout(location = 6) flat in float v_alpha;
    layout(location = 0) out vec4 result;
    #ifdef LIT_FIELD
    layout(set = 2, binding = 0) uniform sampler2D plan_albedo;
    layout(set = 2, binding = 1) uniform sampler2D plan_normal;
    layout(set = 2, binding = 2) uniform sampler2D field_light;
    #endif
    #ifdef LIT_FRAME
    layout(set = 2, binding = 0) uniform sampler2D frame_albedo;
    layout(set = 2, binding = 1) uniform sampler2D frame_normal;
    layout(set = 2, binding = 2) uniform sampler2DShadow shadow_map;
    #endif
    #ifdef LIT_PIECE
    layout(set = 2, binding = 0) uniform sampler2DShadow shadow_map;
    #endif
    """;

let LIT_FRAG = """
    const float FRAME_SPAN = 10.4;   // the frame map's side in world units

    float hash13(vec3 p) {
        p = fract(p * 0.1031);
        p += dot(p, p.zyx + 31.32);
        return fract((p.x + p.y) * p.z);
    }
    float noise3(vec3 p) {
        vec3 i = floor(p);
        vec3 f = fract(p);
        vec3 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(mix(hash13(i), hash13(i + vec3(1, 0, 0)), u.x),
                       mix(hash13(i + vec3(0, 1, 0)), hash13(i + vec3(1, 1, 0)), u.x), u.y),
                   mix(mix(hash13(i + vec3(0, 0, 1)), hash13(i + vec3(1, 0, 1)), u.x),
                       mix(hash13(i + vec3(0, 1, 1)), hash13(i + vec3(1, 1, 1)), u.x), u.y),
                   u.z);
    }

    // Filament's GGX, its height-correlated Smith visibility, Schlick's Fresnel.
    float d_ggx(float noh, float a) {
        float a2 = a * a;
        float f = (noh * a2 - noh) * noh + 1.0;
        return a2 / (PI * f * f);
    }
    float v_smith(float nov, float nol, float a) {
        float a2 = a * a;
        float l = nov * sqrt((-nol * a2 + nol) * nol + a2);
        float v = nol * sqrt((-nov * a2 + nov) * nov + a2);
        return 0.5 / (l + v);
    }
    vec3 f_schlick(vec3 f0, float voh) {
        float f = pow(1.0 - voh, 5.0);
        return f0 + (1.0 - f0) * f;
    }
    // Karis's fit of the split-sum's DFG for mobile.
    vec3 env_brdf(vec3 f0, float rough, float nov) {
        vec4 c0 = vec4(-1.0, -0.0275, -0.572, 0.022);
        vec4 c1 = vec4(1.0, 0.0425, 1.04, -0.04);
        vec4 r = rough * c0 + c1;
        float a004 = min(r.x * r.x, exp2(-9.28 * nov)) * r.x + r.y;
        vec2 ab = vec2(-1.04, 1.04) * a004 + r.zw;
        return f0 * ab.x + ab.y;
    }
    vec3 sh_eval(vec3 n) {
        vec3 r = sh[0].rgb * 0.282095
               + sh[1].rgb * (0.488603 * n.y) + sh[2].rgb * (0.488603 * n.z)
               + sh[3].rgb * (0.488603 * n.x)
               + sh[4].rgb * (1.092548 * n.x * n.y) + sh[5].rgb * (1.092548 * n.y * n.z)
               + sh[6].rgb * (0.315392 * (3.0 * n.y * n.y - 1.0))
               + sh[7].rgb * (1.092548 * n.x * n.z)
               + sh[8].rgb * (0.546274 * (n.x * n.x - n.z * n.z));
        return max(r, vec3(0.0));
    }

    // The crown on a king's face, in units of the piece's radius, traced from the 3D
    // reference's king: a body with three points, the side ones reaching out, its edges
    // between them bowed in, a ball on each point, and a bar under it; 1.06 of the radius
    // across and 0.86 tall, centred in the recess.
    const vec2 CROWN[11] = vec2[11](vec2(-0.35, -0.29), vec2(-0.45, 0.11),
                                    vec2(-0.31, 0.055), vec2(-0.19, 0.04),
                                    vec2(-0.075, 0.18), vec2(0.0, 0.33), vec2(0.075, 0.18),
                                    vec2(0.19, 0.04), vec2(0.31, 0.055),
                                    vec2(0.45, 0.11), vec2(0.35, -0.29));
    float crown(vec2 p) {
        float d = dot(p - CROWN[0], p - CROWN[0]);
        float s = 1.0;
        for (int i = 0, j = 10; i < 11; j = i, i++) {
            vec2 e = CROWN[j] - CROWN[i];
            vec2 w = p - CROWN[i];
            vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
            d = min(d, dot(b, b));
            bvec3 c = bvec3(p.y >= CROWN[i].y, p.y < CROWN[j].y, e.x * w.y > e.y * w.x);
            if (all(c) || all(not(c))) s = -s;
        }
        d = s * sqrt(d);
        d = min(d, length(p - vec2(-0.47, 0.15)) - 0.062);
        d = min(d, length(p - vec2(0.0, 0.37)) - 0.062);
        d = min(d, length(p - vec2(0.47, 0.15)) - 0.062);
        vec2 q = abs(p - vec2(0.0, -0.36)) - vec2(0.34, 0.03);
        d = min(d, length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 0.01);
        return d;
    }

    // The piece's top as mesh::top_height and mesh::top_ao have it: keep them in step.
    float top_height(float u) {
        float t = clamp((u - 0.63) / 0.06, 0.0, 1.0);
        float c = (u - 0.636) / 0.022;
        return -0.02 * (1.0 - t * t * (2.4 - 1.4 * t)) - 0.008 * exp(-c * c);
    }
    float top_ao(float u) {
        float c = (u - 0.634) / 0.026;
        return 1.0 - 0.05 * (1.0 - u) - 0.3 * exp(-c * c);
    }

    vec3 tonemap(vec3 c) {
        // Khronos PBR Neutral: hue kept, highlights eased; its toe halved, as the
        // references' darks keep their color.
        float x = min(c.r, min(c.g, c.b));
        float offset = x < 0.04 ? x - 12.5 * x * x : 0.02;
        c -= offset;
        float peak = max(c.r, max(c.g, c.b));
        const float start = 0.76;
        if (peak < start) return c;
        const float d = 1.0 - start;
        float np = 1.0 - d * d / (peak + d - start);
        c *= np / peak;
        float g = 1.0 - 1.0 / (0.15 * (peak - np) + 1.0);
        return mix(c, vec3(np), g);
    }
    vec3 to_srgb(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }

    void main() {
        vec3 p = v_world;
        vec3 n = normalize(v_normal);
        float ao = clamp(v_extra.x, 0.0, 1.0);
        vec3 albedo;
        float rough;
        float top_var = 0.0;     // the spread of a shader-made normal over the pixel
    #ifdef LIT_FIELD
        // The field: the baked plan, seen from above, and its light baked with the
        // shadow map (FIELD_LIGHT_FRAG): the key's shadow and the occlusion.
        vec2 baked;
        {
            vec2 uv = (p.xz + INNER) / (2.0 * INNER);
            vec4 a = texture(plan_albedo, uv);
            vec2 t = texture(plan_normal, uv).xy * 2.0 - 1.0;
            baked = texture(field_light, uv).rg;
            albedo = a.rgb;
            rough = a.a;
            n = normalize(vec3(t.x, sqrt(max(1.0 - dot(t, t), 0.0)), t.y));
            ao *= baked.g;
        }
    #endif
    #ifdef LIT_FRAME
        {
            // The frame, mapped from where the point is, so the figure runs on unbroken
            // over the top, the rounded edge and the side, round the corners too, as in
            // a real piece cut from a plank. The frame map holds the theme's wood or
            // stone with its grain along u. A solid block (frame_build.x 1) has its
            // grain along x over the whole board, across = how far in plus how far down;
            // stone also leans u with the height near the ends, so the end faces aren't
            // smeared. Mitred (0): four pieces, each with the grain along its own side and
            // its own band of the map, a thin joint on each diagonal.
            vec2 a2 = abs(p.xz);
            float down = FRAME_TOP - p.y;
            vec2 solid_uv = vec2(p.x + down * clamp(p.x, -1.0, 1.0) * frame_build.z,
                                 p.z - down);
            vec2 fuv = solid_uv;
            vec3 grain = vec3(1.0, 0.0, 0.0);
            vec2 gx = dFdx(solid_uv) / FRAME_SPAN;
            vec2 gy = dFdy(solid_uv) / FRAME_SPAN;
            if (frame_build.x < 0.5) {
                bool along_x = a2.y > a2.x;
                float band = along_x ? (p.z > 0.0 ? 0.0 : 1.0) : (p.x > 0.0 ? 2.0 : 3.0);
                // Both pieces' mappings and their derivatives, so the filter's footprint
                // follows the piece's own axes (the sides' grain runs along z) and a pixel
                // quad straddling a mitre doesn't see the jump between them.
                // A carved frame (frame_build.w) takes across along the profile, so its
                // band keeps its place over the rounded corners (BAKE_FRAG's carving).
                bool carved = frame_build.w > 0.5;
                vec2 on_x = vec2(p.x, carved ? v_uv.y : a2.y - INNER + down);
                vec2 on_z = vec2(p.z, carved ? v_uv.y : a2.x - INNER + down);
                vec2 own = along_x ? on_x : on_z;
                fuv = vec2(own.x, own.y + band * 1.4 - 5.0);
                gx = (along_x ? dFdx(on_x) : dFdx(on_z)) / FRAME_SPAN;
                gy = (along_x ? dFdy(on_x) : dFdy(on_z)) / FRAME_SPAN;
                grain = along_x ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0);
            }
            fuv = fuv / FRAME_SPAN + 0.5;
            // A mitred frame's map holds only its bands, the lower frame_map.x of it.
            fuv.y /= frame_map.x;
            gx.y /= frame_map.x;
            gy.y /= frame_map.x;
            vec4 a = textureGrad(frame_albedo, fuv, gx, gy);
            vec4 tn = textureGrad(frame_normal, fuv, gx, gy);
            vec2 t = tn.xy * 2.0 - 1.0;
            albedo = a.rgb;
            rough = a.a;
            ao *= tn.z;
            // The mips' averaged normal is shorter where the grooves blur: Toksvig's
            // 1 - r over r widens the roughness there, so far furrows don't sparkle.
            float r = length(vec3(t, tn.w));
            top_var = max((1.0 - r) / max(r, 1e-3), 0.0);
            vec3 tan = grain - n * dot(n, grain);
            tan = dot(tan, tan) > 0.01 ? normalize(tan) : normalize(cross(n, vec3(0.0, 0.0, 1.0)));
            vec3 bit = cross(n, tan);
            // The carving's relief wants bit along the map's across as the bake has it:
            // cross(n, tan) turns it the other way on the -z and +x pieces (raised vines
            // shaded as if cut in, against the key light).
            if (frame_build.w > 0.5 && frame_build.x < 0.5) {
                bool along_x = a2.y > a2.x;
                if ((along_x && p.z < 0.0) || (!along_x && p.x > 0.0)) bit = -bit;
            }
            n = normalize(n * sqrt(max(1.0 - dot(t, t), 0.0)) + tan * t.x + bit * t.y);
            if (frame_build.x < 0.5) {
                // The glued mitre: a thin dark joint on the diagonal, through the top,
                // the rounded edge and the side.
                float d = abs(a2.x - a2.y) * 0.7071;
                float jw = fwidth(d);
                float joint = (1.0 - smoothstep(0.0012, 0.0012 + 1.5 * jw, d)) * frame_build.y;
                albedo *= 1.0 - 0.45 * joint;
                rough = mix(rough, 0.8, joint);
                ao *= 1.0 - 0.3 * joint;
            }
            // The rounded edge in its own color (winter's steel blue), fading down the
            // side, and a thin line along the top's outer edge where the round starts.
            float along = v_uv.y;
            float round_part = smoothstep(BULL_START - 0.02, BULL_START + 0.04, along)
                             * (1.0 - smoothstep(BULL_END, BULL_END + 0.2, along));
            albedo = mix(albedo, edge.rgb, round_part * edge.a);
            // Hands polish the rounded edge: smoother than the top, so the sheen gathers
            // on the curve instead of spreading over the flat.
            rough = max(rough - frame_surface.w * round_part, min(rough, 0.2));
            float lw = max(fwidth(along), 0.004);
            float line = 1.0 - smoothstep(0.5 * lw, 1.5 * lw, abs(along - BULL_START - 0.006));
            albedo = mix(albedo, edge_line.rgb, line * edge_line.a);
            rough = mix(rough, 0.4, line * edge_line.a);
            // Darker toward the underside, where the board's own shade gathers.
            ao *= mix(0.4, 1.0, smoothstep(BOTTOM, FRAME_TOP - 0.1, p.y));
        }
    #endif
    #ifdef LIT_PIECE
        {
            vec3 lp = v_local;
            bool dark = v_kind.x > 0.5;
            vec4 m = dark ? dark_piece : light_piece;
            rough = m.a;
            if (dark) {
                // Smooth satin with a faint figure, drawn out a little across the disc.
                vec3 g = lp + mod(v_kind.w, 1000.0) * 3.17;
                float st = 1.0 + 6.0 * piece_fig.z;
                float w = noise3(vec3(g.x * 5.0, g.y * 5.0, g.z * 5.0 * st)) * 0.65
                        + noise3(vec3(g.x * 13.0, g.y * 13.0, g.z * 13.0 * st)) * 0.35;
                albedo = m.rgb * (1.0 + piece_fig.y * (w - 0.5));
                // The turned side, across the grain, takes the finish darker than the face:
                // the references' dark pieces have near-black sides under a lit top.
                albedo *= mix(piece_fig.w, 1.0, smoothstep(0.2, 0.6, abs(n.y)));
            } else {
                float w = noise3(lp * 24.0 + mod(v_kind.w, 1000.0) * 3.17);
                albedo = m.rgb * (1.0 + piece_fig.x * (w - 0.5));
            }
            // The top, from its height function at this point's distance from the axis
            // (mesh::top_height): the normal and the cove's occlusion come from the
            // object-space position, never from interpolants a multisampled pixel can
            // extrapolate past a small triangle.
            // MSAA shades once per pixel and triangle, so a step narrower than a pixel
            // aliases inside the triangles: the height is filtered over the pixel's
            // footprint in u (the 2D board's coverage idea), its slope averaged over four
            // pieces of it, and how far their normals spread widens the roughness below.
            float rho = length(lp.xz);
            float u = rho / RADIUS;
            float span = max(1.5 * length(vec2(dFdx(u), dFdy(u))), 0.004);
            if (u < EDGE_AT && lp.y > 0.5 * HEIGHT) {
                vec2 radial = rho > 1e-5 ? lp.xz / rho : vec2(0.0);
                float q = 0.25 * span;
                float h0 = top_height(u - 2.0 * q);
                vec3 sum = vec3(0.0);
                ao = 0.5 * top_ao(u - 2.0 * q);
                for (int i = -1; i <= 2; i++) {
                    float h1 = top_height(u + float(i) * q);
                    float slope = (h1 - h0) / (q * RADIUS);
                    sum += normalize(vec3(-slope * radial.x, 1.0, -slope * radial.y));
                    ao += (i == 2 ? 0.5 : 1.0) * top_ao(u + float(i) * q);
                    h0 = h1;
                }
                ao *= 0.25;
                float r = length(sum) * 0.25;
                n = sum / max(r * 4.0, 1e-5);
                top_var = (1.0 - r) / max(r, 1e-3);
            }
            if (v_kind.y > 0.75 && lp.y > 0.5 * HEIGHT) {
                // The crown debossed in a crowned king's face, filled with the crown's
                // color, its walls sloping in, crisp by its distance's screen derivative
                // (taken over the whole top: a branch on the radius left specks where a
                // pixel quad straddled it).
                float k = RADIUS;
                vec2 c = vec2(lp.x, -lp.z) / k;
                float d = crown(c) * k;
                float e = 0.002;
                vec2 grad = vec2(crown(c + vec2(e / k, 0.0)) * k - d,
                                 crown(c + vec2(0.0, e / k)) * k - d) / e;
                float w = fwidth(d);
                float inside = (1.0 - smoothstep(-w, w, d)) * step(u, 0.6);
                float wall = inside * smoothstep(-0.012 - w, -0.012 + w, d);
                // A wall narrower than the pixel tilts only its share of it, and its
                // edges' spread over the pixel widens the roughness, as the step's does.
                float share = min(1.0, 0.006 / max(w, 1e-5));
                n = normalize(n - vec3(grad.x, 0.0, -grad.y) * wall * 1.6 * share);
                top_var += wall * (1.0 - wall) * share;
                albedo = mix(albedo, crown_color.rgb, inside);
                rough = mix(rough, 0.7, inside);
                ao *= 1.0 - 0.35 * inside;
                // The face's edge round the deboss catches the light: a thin lighter lip.
                float lip = smoothstep(-w, w, d) * (1.0 - smoothstep(0.0, 0.005 + w, d));
                albedo *= 1.0 + 0.18 * lip * step(u, 0.6);
            }
            // Contact: the foot darkens near what it stands on; a stack's lower disc
            // darkens under the upper.
            float h = v_kind.y > 0.25 ? lp.y : p.y;
            ao *= mix(0.6, 1.0, smoothstep(0.0, 0.035, h));
            if (v_kind.z > 1.5) ao *= mix(1.0, 0.65, smoothstep(HEIGHT - 0.05, HEIGHT, lp.y));
        }
    #endif

        vec3 v = normalize(eye.xyz - p);
        vec3 l = light_dir.xyz;
        float nov = max(dot(n, v), 1e-4);
        float nol = dot(n, l);
        float nl = clamp(nol, 0.0, 1.0);
        vec3 hv = normalize(v + l);
        float noh = clamp(dot(n, hv), 0.0, 1.0);
        float voh = clamp(dot(v, hv), 0.0, 1.0);
        // Specular antialiasing (Kaplanyan and Tokuyoshi, as Filament has it): roughness
        // widened by the normal's screen-space variance, and by the spread of the normals
        // a shader-made step averaged over the pixel (Toksvig's 1 - r over r).
        vec3 du = dFdx(n);
        vec3 dv = dFdy(n);
        float variance = 0.15 * (dot(du, du) + dot(dv, dv));
        float a = rough * rough;
        a = sqrt(clamp(a * a + min(2.0 * variance + top_var, 0.3), 0.0, 1.0));
        a = max(a, 0.0079);
        vec3 f0 = vec3(0.04);
        vec3 spec = d_ggx(noh, a) * v_smith(nov, nl, a) * f_schlick(f0, voh) * nl;
        float wrap = 0.2;
        float diff = clamp((nol + wrap) / (1.0 + wrap), 0.0, 1.0) / (1.0 + wrap);
        // Filament's micro-shadowing from the occlusion, on the field only: on the
        // pieces' grooves, tiny triangles near the terminator turned it into specks.
    #ifdef LIT_FIELD
        float micro = clamp(nl * inversesqrt(1.0 - min(ao, 0.9999)), 0.0, 1.0);
        float vis = baked.r * (nol > 0.0 ? micro * micro : 1.0);
    #endif
    #ifdef LIT_FRAME
        float vis = shadow(p, n);
    #endif
    #ifdef LIT_PIECE
        // A piece's lip and groove are finer than a shadow texel: its lookups start a
        // little toward the light, so they leave them to the baked occlusion.
        float vis = shadow(p + l * 0.03, n);
    #endif
        vec3 light = light_color.rgb * light_dir.w;
        vec3 direct = (albedo * (diff / PI) + spec) * light * vis;
        // The photograph's light: diffuse from the harmonics, specular from them along
        // the reflection, through the DFG fit, under the occlusion.
        vec3 irr = sh_eval(n) * params.z;
        vec3 env = sh_eval(reflect(-v, n)) * params.z;
        float spec_ao = clamp(pow(nov + ao, exp2(-16.0 * a - 1.0)) - 1.0 + ao, 0.0, 1.0);
        vec3 ambient = albedo * irr * ao + env * env_brdf(f0, rough, nov) * spec_ao;
    #ifdef LIT_PIECE
        // The lit board's light on a piece's side: what faces down and out sees the
        // board round it, lit by the key from above.
        float down = clamp(0.5 - 0.5 * n.y, 0.0, 1.0);
        ambient += albedo * bounce.rgb * (light * l.y / PI) * bounce.a * down * ao;
    #endif
        vec3 color = (direct + ambient) * params.x;
        color = tonemap(color) * vec3(1.02, 1.0, 0.97);
        // A win dims the board and the pieces but the winning one, as the flat board's
        // black fill over them does.
        float dim = v_kind.w >= 1000.0 ? 0.0 : screen.z;
        result = vec4(to_srgb(color) * (1.0 - dim), v_alpha);
    }
    """;

// One triangle over the target.
let FULL_VERT = """
    layout(location = 0) out vec2 v_uv;
    void main() {
        vec2 p = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
        v_uv = p;
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """;

// The plain background in place of the photograph (task 044; prototypes/draughts.js's
// paintPlain, take b): the page at the top to a deep tone of the frame at the foot, a
// faint light of the dark square behind the middle, wider than tall, and the corners a
// little darker. `px` is in pixels from the screen's top left, `s` the screen's size,
// the colors in linear light; the result in sRGB, dithered by under half a level so the
// dark fade shows no bands. The app's board pass, its glass, the settings' thumbnails,
// and the 3D backdrop all draw it from here; fade() in render3d.goose is its port for the
// 3D board's ambient light.
let FADE_FN = """
    vec3 plain_fade(vec2 px, vec2 s, vec3 top, vec3 low, vec3 light) {
        vec2 q = px / s - 0.5;
        float m = max(s.x, s.y);
        vec3 c = mix(top, low, smoothstep(0.0, 1.0, px.y / s.y));
        float r = length(vec2(q.x * (s.x / m) / 0.62, (q.y - 0.04) * (s.y / m) / 0.5));
        c = mix(c, light, 0.22 * (1.0 - smoothstep(0.0, 1.0, r)));
        c *= 1.0 - 0.3 * smoothstep(0.15, 0.6, dot(q, q));
        float n = fract(sin(dot(floor(px), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
        return pow(min(c, vec3(1.0)), vec3(1.0 / 2.2)) + n / 255.0;
    }
    """;

// The backdrop: the blurred photograph cover-cropped by the screen's long side, graded
// to sit as the 3D reference's background does: lighter, a little more saturated, its
// bright patches lifted into warm bokeh, and lifted toward the theme's tint low down,
// where the reference has a surface under the board, darkened toward the edges. With the
// plain background (draw.y over 0) the fade instead, dimmed to draw.y as the flat game
// dims what is behind it.
let BACKDROP_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D photo;
    // x: how opaque; y: the plain fade's brightness, 0 for the photograph; its colors.
    layout(set = 3, binding = 1) uniform Backdrop { vec4 draw; vec4 fade_top; vec4 fade_low; vec4 fade_light; };
    void main() {
        vec2 s = screen.xy;
        if (draw.y > 0.0) {
            vec3 f = plain_fade(gl_FragCoord.xy, s, fade_top.rgb, fade_low.rgb, fade_light.rgb);
            result = vec4(draw.y * f, draw.x);
            return;
        }
        vec2 uv = (gl_FragCoord.xy - 0.5 * s) / max(s.x, s.y) + 0.5;
        vec3 c = srgb(texture(photo, uv).rgb) * grade.x;
        float luma = dot(c, vec3(0.2126, 0.7152, 0.0722));
        c = max(mix(vec3(luma), c, grade.y), vec3(0.0));
        c *= 1.0 + grade.z * smoothstep(0.08, 0.5, luma);
        float low = smoothstep(0.45, 1.0, gl_FragCoord.y / s.y);
        c = c / (1.0 + 0.15 * c * c);
        // A soft vignette (tint.w), so the lit board stands out from the scene round it,
        // under the lift low down.
        vec2 q = gl_FragCoord.xy / s - 0.5;
        c *= 1.0 - tint.w * smoothstep(0.1, 0.55, dot(q, q));
        c = mix(c, tint.rgb, low * grade.w);
        result = vec4(pow(c, vec3(1.0 / 2.2)), draw.x);
    }
    """;

// A quad on a plane: the shadow catcher under the board (draw.x 0), the selected
// piece's glow on the field (draw.x 1), or the field's marks over all of it (draw.x 2).
let QUAD_VERT = """
    layout(set = 1, binding = 1) uniform Draw { vec4 draw; };
    layout(location = 0) out vec3 v_pos;
    void main() {
        const vec2 corners[6] = vec2[6](vec2(-1, -1), vec2(1, -1), vec2(1, 1),
                                        vec2(-1, -1), vec2(1, 1), vec2(-1, 1));
        vec2 c = corners[gl_VertexIndex];
        // The catcher reaches only as far as its shadow does (SHADOW_CATCHER_FRAG): the
        // contact 0.3 out from the board, the soft one 1.6 out from it moved by `off`.
        vec2 off = -light_dir.xz / light_dir.y * (FRAME_TOP - BOTTOM) * 0.6;
        vec2 lo = min(vec2(-INNER - FRAME_W - 0.3), off - (INNER + FRAME_W + 1.6));
        vec2 hi = max(vec2(INNER + FRAME_W + 0.3), off + (INNER + FRAME_W + 1.6));
        vec2 at = mix(lo, hi, c * 0.5 + 0.5);
        vec3 pos = draw.x > 1.5 ? vec3(c.x * FIELD, 0.004, c.y * FIELD)
                 : draw.x > 0.5 ? vec3(selected.x + c.x * selected.w * 2.0, 0.004,
                                       selected.z + c.y * selected.w * 2.0)
                                : vec3(at.x, BOTTOM, at.y);
        v_pos = pos;
        gl_Position = view_proj * vec4(pos, 1.0);
    }
    """;

// The board's soft shadow on nothing: a tight one round its foot and a wide one cast
// along the key light, as distances to its rounded outline.
let SHADOW_CATCHER_FRAG = """
    layout(location = 0) in vec3 v_pos;
    layout(location = 0) out vec4 result;
    float round_box(vec2 p, vec2 b, float r) {
        vec2 q = abs(p) - b + r;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    }
    void main() {
        vec3 l = light_dir.xyz;
        vec2 off = -l.xz / l.y * (FRAME_TOP - BOTTOM) * 0.6;
        vec2 b = vec2(INNER + FRAME_W);
        float d0 = round_box(v_pos.xz, b, FRAME_W);
        float d1 = round_box(v_pos.xz - off, b, FRAME_W);
        float contact = 1.0 - smoothstep(-0.05, 0.3, d0);
        float soft = 1.0 - smoothstep(-0.8, 1.6, d1);
        result = vec4(0.0, 0.0, 0.0, clamp(0.5 * contact + 0.5 * soft, 0.0, 0.85));
    }
    """;

// The board's surfaces, baked once per theme into two targets: albedo and roughness
// (sRGB), and the normal's x and z. mode.x 0 bakes the plan of the field and its inlay,
// seen from above; 1 the frame map, its grain along u. mode.y: the wood's model (task
// 039, board3d's --wood): 0 noise drawn out along the grain, 1 growth rings, 2 growth
// rings with pores and a fibre relief, 3 the first with thin lines and pores laid over
// it. size: the target in texels, then in world units. The rest is the theme's
// (looks::Theme): each surface's color and roughness and its figure.
let BAKE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 out_albedo;
    layout(location = 1) out vec4 out_normal;
    layout(set = 3, binding = 0) uniform Bake {
        vec4 mode;
        vec4 size;
        vec4 light_sq;
        vec4 light_fig;
        vec4 dark_sq;
        vec4 dark_fig;
        vec4 inlay;
        vec4 inlay_fig;
        vec4 frame;
        vec4 frame_fig;
        vec4 surface;    // x: each square's own tone, y: pores, z: seams, w: relief
        vec4 frame_surface;  // the frame's wood: x pores, y relief, z late-wood furrows
        vec4 stone;      // x: veins, y: clouding, z: the roughness following the figure
        // The growth rings (wood::rings), per surface: x a ring's width in world units,
        // y how flat-sawn the pieces are (0 quarter-sawn, 1 flat), z the late wood's
        // darkening, w the pores' density.
        vec4 light_ring;
        vec4 dark_ring;
        vec4 frame_ring;
        vec4 finish;     // the wood's (looks::Finish): varnish, sanding, grain, rings
        vec4 tone;       // x: its warmth, y: pickle, z: caulk
        vec4 marble;     // looks::Marble: veins, wave, polish, tint; mode.w the variant
        vec4 marble_base;
        vec4 marble_vein;
        vec4 marble_form;
        vec4 seam;       // the frame's caulked seams: x a plank's width, y half width, z dark
        vec4 carve;      // looks::Carving: depth, repeats per side, moss; w 1 carved
        vec4 moss;       // the moss's color (sRGB), w: how patchy
        vec4 carve_more; // looks::Carving: x the motif, y amber, z lichen
        vec4 fill;       // the carving's fill (looks::Theme.fill, sRGB), w: how much
        vec4 lichen;     // the lichen's color (sRGB)
    };
    const float FIELD = 4.0;
    vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }

    float h12(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }
    float vnoise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(h12(i), h12(i + vec2(1, 0)), u.x),
                   mix(h12(i + vec2(0, 1)), h12(i + vec2(1, 1)), u.x), u.y);
    }
    float fbm(vec2 p) {
        float s = 0.0;
        float a = 0.5;
        for (int i = 0; i < 5; i++) {
            s += a * vnoise(p);
            p = p * 2.03 + vec2(17.1, 9.2);
            a *= 0.5;
        }
        return s / 0.97;
    }
    // Three octaves, for the figures that don't need five.
    float fbm3(vec2 p) {
        float s = 0.0;
        float a = 0.5;
        for (int i = 0; i < 3; i++) {
            s += a * vnoise(p);
            p = p * 2.03 + vec2(17.1, 9.2);
            a *= 0.5;
        }
        return s / 0.875;
    }

    // Grooves along the grain at y: two contours of a noise drawn out along it,
    // irregularly spaced and ending where it flattens, each a groove of about half_w
    // either side, its distance from the contour by the noise's slope, broken into
    // lengths of about 1 / pieces.
    float furrows(float x, float y, float freq, float half_w, float pieces) {
        vec2 lq = vec2(x * freq + 3.1, y * 0.3);
        float e = 0.002 * freq;
        float slope = abs(vnoise(lq + vec2(e, 0.0)) - vnoise(lq - vec2(e, 0.0))) / 0.004;
        float dist = abs(fract(vnoise(lq) * 2.0) - 0.5) / max(2.0 * slope, 1e-3);
        float w = half_w * (0.75 + 0.5 * vnoise(vec2(x * 4.0, y * 0.9)));
        // Its edges a texel soft at least, so the bake doesn't alias them.
        float texel = size.z / size.x;
        float groove = 1.0 - smoothstep(0.3 * w, w + 0.7 * texel, dist);
        return groove * smoothstep(0.25, 0.45, vnoise(vec2(x * 20.0, y * pieces)));
    }

    struct Wood { vec3 albedo; float rough; float height; float cavity; };

    float h1(float seed, float k) { return h12(vec2(seed, k)); }

    // Vessels cut along their length: short dark dashes along the grain, scattered in
    // columns across it (the column's rows shifted at random so they never line up),
    // their width tapering to the ends, the edges a texel soft. x across, y along, in
    // world units; dens the share of cells holding one, early 0 to 1 (bigger in the
    // early wood); the cell's hash, for its roughness and depth.
    float vessels(float x, float y, float seed, float dens, float early) {
        const float ACROSS = 0.012;
        const float ALONG = 0.032;
        float texel = size.z / size.x;
        float col = floor(x / ACROSS);
        float yy = y / ALONG + h1(col, seed + 3.3) * 17.0;
        vec2 id = vec2(col, floor(yy));
        if (h12(id + seed * 0.37) >= dens) return 0.0;
        float cx = (col + 0.3 + 0.4 * h12(id + 1.3)) * ACROSS;
        float sy = (yy - id.y - 0.5) / (0.25 + 0.2 * h12(id + 2.1));
        float hw = (0.0012 + 0.0014 * h12(id + 5.7)) * mix(0.75, 1.25, early)
                 * sqrt(max(1.0 - sy * sy, 0.0));
        return 1.0 - smoothstep(-0.5 * texel, 0.6 * texel, abs(x - cx) - hw);
    }

    // Rays seen on a face near the radial plane: thin dark flecks across the grain, a
    // texel or so wide, 0.04 to 0.15 long, far apart, leaning a little. x across, y
    // along; dens scales how many.
    float flecks(float x, float y, float seed, float dens) {
        const float STEP = 0.18;
        const float ACROSS = 0.25;
        float texel = size.z / size.x;
        vec2 id = floor(vec2(x / ACROSS, y / STEP));
        if (h12(id + seed * 0.71 + 3.1) >= 0.5 * dens) return 0.0;
        vec2 c = (id + vec2(0.2, 0.2) + 0.6 * vec2(h12(id + 4.4), h12(id + 6.6)))
               * vec2(ACROSS, STEP);
        float half_len = 0.02 + 0.055 * h12(id + 7.7);
        vec2 d = vec2(x, y) - c;
        float tilt = (h12(id + 8.8) - 0.5) * 0.4;
        float along = d.x;
        float off = abs(d.y - tilt * d.x);
        float taper = max(1.0 - (along / half_len) * (along / half_len), 0.0);
        return taper * (1.0 - smoothstep(0.3 * texel, 1.0 * texel, off));
    }

    // Growth rings: each piece sawn from a log whose pith runs roughly along its grain,
    // the rings the distance from that axis (Liu et al.'s time volume, the classic
    // solid-texture wood). q.x across the face, q.y along the grain, in world units. The
    // piece's cut is its own: quarter-sawn faces pass near the pith with it far to one
    // side, so the rings show as nearly straight lines; flat-sawn ones lie above it, and
    // the axis leaning out of the face and wandering draws arches where they cut the
    // rings. The rings' radius wobbles, the years are uneven, each year's late wood its
    // own strength: an asymmetric profile, the early wood light, darkening through the
    // year to a sharp edge where the next year's early wood starts. Fibres are fine
    // streaks along the grain, which crosses the ring lines at a slant where the axis
    // leans. The color darkens by Beer's law (base^(1 + a)), so the late wood and the
    // stained pores are deeper and more saturated, as stained wood is. detail adds the
    // pores and a fibre relief into the normal.
    Wood rings(vec2 q, float seed, vec4 base, vec4 k, vec4 ring, bool detail) {
        float rw = ring.x * finish.w;
        float texel = size.z / size.x;
        vec2 o = vec2(h1(seed, 1.7), h1(seed, 9.3)) * 97.0;
        float flatness = clamp(ring.y + (h1(seed, 2.1) - 0.5) * 0.6, 0.0, 1.0);
        float side = h1(seed, 3.7) > 0.5 ? 1.0 : -1.0;
        float d = mix(0.1, 1.6, flatness) * (0.6 + 0.8 * h1(seed, 5.3));
        float c = side * mix(3.0 + 3.0 * h1(seed, 6.1), 0.8 * (h1(seed, 6.1) - 0.5), flatness);
        float axis = fbm(vec2(q.y * 0.12, 0.5) + o) - 0.5;
        float lean = (h1(seed, 8.8) - 0.5) * 0.12 * flatness;
        float dd = max(d + lean * q.y + axis * 0.5 * flatness, 0.02);
        float r = length(vec2(q.x - c - axis * 0.8, dd));
        r += rw * k.x * 3.0 * (fbm(vec2(q.x * 1.1, q.y * 0.18) + o) - 0.5);
        r += rw * k.x * 0.8 * (vnoise(vec2(q.x * 6.0, q.y * 0.9) + o) - 0.5);
        r += rw * k.x * 0.7 * (vnoise(vec2(q.x * 14.0, q.y * 4.0) + o) - 0.5);
        float t = r / rw;
        t += 1.2 * (vnoise(vec2(t * 0.3, seed)) - 0.5);
        float year = floor(t);
        float ph = t - year;
        float e = max(0.06, 1.5 * texel / rw);
        float late = smoothstep(0.72, 1.0 - e, ph);
        late *= late * (1.0 - smoothstep(1.0 - e, 1.0, ph));
        late *= 0.5 + h1(year + seed * 13.0, 4.4);
        float early = 1.0 - smoothstep(0.0, 0.5, ph);
        // Fibres along the grain, a little wandering.
        float x = q.x + 0.004 * (vnoise(vec2(q.x * 20.0, q.y * 3.0) + o) - 0.5);
        float fibre = 0.45 * vnoise(vec2(x * 150.0, q.y * 2.0) + o)
                    + 0.3 * vnoise(vec2(x * 55.0, q.y * 0.7) + o)
                    + 0.25 * vnoise(vec2(x * 380.0, q.y * 30.0) + o);
        float broad = fbm(vec2(q.x * 1.2, q.y * 0.25) + o);
        float pore = 0.0;
        if (detail && ring.w > 0.0) {
            // Semi-ring-porous: more and bigger vessels in the early wood.
            pore = vessels(x + o.x, q.y, seed, ring.w * mix(0.6, 1.4, early), early);
            // Rays cut across: sparse thin flecks across the grain, as on the frame.
            pore = max(pore, 0.6 * flecks(x, q.y + o.y, seed, ring.w));
        }
        float a = ring.z * (late - 0.08) + k.z * (fibre - 0.5) * 1.2 + k.y * (broad - 0.5) * 1.5
                + 0.4 * pore;
        Wood w;
        w.albedo = pow(srgb(base.rgb), vec3(1.0 + a));
        w.rough = base.a + 0.06 * (1.0 - late) - 0.04 + 0.25 * pore;
        w.height = 0.15 * late + (detail ? 0.5 : 0.1) * (fibre - 0.5) - 1.2 * pore;
        w.cavity = 1.0 - 0.4 * pore;
        return w;
    }

    // A surface with its grain along y, from noise drawn out along the grain, never a
    // regular stripe: a broad soft figure, fine streaks, pores. k: how far the grain
    // wanders, the broad figure's contrast, the fine streaks' contrast, and how far the
    // noise is drawn out along y (1 wood; 0 stone: the same noise round, a clouding with
    // faint veins). base: the color (sRGB) and roughness. f: the pores' strength, the
    // open pores' (dense fine dashes), the fine dark late-wood lines', all following the
    // grain, roughest in them; the late wood as furrows.
    Wood figure(vec2 q, float seed, vec4 base, vec4 k, vec3 f, vec4 ring) {
        float s = k.w;
        if (s > 0.5 && mode.y > 0.5 && mode.y < 2.5) return rings(q, seed, base, k, ring, mode.y > 1.5);
        if (s > 0.5) q.x /= finish.w;
        q += vec2(h12(vec2(seed, 1.7)), h12(vec2(seed, 9.3))) * 97.0;
        float wander = (fbm(q * vec2(0.45, mix(0.45, 0.16, s))) - 0.5) * k.x;
        float x = q.x + wander;
        float broad = fbm(vec2(x * mix(1.3, 2.4, s), q.y * mix(1.3, 0.22, s)));
        float fine = fbm(vec2(x * 26.0, q.y * mix(26.0, 0.7, s)));
        float pores = smoothstep(0.6, 0.9, vnoise(vec2(x * 70.0, q.y * mix(70.0, 1.6, s))));
        // Open pores, dense fine dashes along the grain, and late wood: thin darker lines,
        // both near the screen's pixel at the default view, so the wood reads rough.
        float dash = smoothstep(0.55, 0.8, vnoise(vec2(x * 55.0, q.y * 5.0)))
                   * (0.6 + 0.4 * vnoise(vec2(x * 6.0, q.y * 0.8)));
        // Late wood as furrows, coarser grooves that catch the light, about 0.012 to
        // 0.022 across (2 to 4 pixels at the default view), and finer, shallower ones
        // between them.
        float furrow = (furrows(x, q.y, 16.0, 0.008, 2.5)
                      + 0.6 * furrows(x + 0.37, q.y, 30.0, 0.005, 5.0)) * f.z * s;
        float open = dash * f.y * s;
        pores *= f.x;
        Wood w;
        w.albedo = srgb(base.rgb) * (1.0 + k.y * (broad - 0.5)) * (1.0 + k.z * (fine - 0.5))
                 * (1.0 - 0.12 * pores) * (1.0 - 0.15 * open) * (1.0 - 0.45 * min(furrow, 1.0));
        pores = max(pores, open);
        w.rough = base.a + 0.16 * pores + 0.22 * furrow - 0.08 * (fine - 0.5);
        w.height = (fine - 0.5) * 0.5 - pores * 0.5 - furrow * 2.0;
        w.cavity = 1.0 - 0.15 * open - 0.5 * furrow;
        if (mode.y > 2.5 && s > 0.5) {
            // Laid over the noise: thin straight dark lines, a texel or two across,
            // broken into lengths, and a scatter of pores.
            float texel = size.z / size.x;
            float lines = furrows(x + 0.11, q.y, 40.0, 0.7 * texel, 1.5)
                        + 0.6 * furrows(x + 0.53, q.y, 75.0, 0.5 * texel, 3.0);
            float pore = ring.w > 0.0 ? vessels(x, q.y, seed, 0.6 * ring.w, 0.5) : 0.0;
            float m = min(lines, 1.0);
            w.albedo *= (1.0 - 0.35 * m) * (1.0 - 0.45 * pore);
            w.rough += 0.12 * m + 0.25 * pore;
            w.height -= 0.6 * m + 1.2 * pore;
            w.cavity -= 0.4 * pore;
        }
        if (s < 0.5) {
            // Stone: a soft clouding and a few thin, faint veins, the roughness lowest in
            // the clear stone between them; veins lighter in dark stone, darker in pale.
            float cloud = fbm(q * 0.55 + 4.7);
            float r = abs(fbm(q * vec2(0.35, 0.5) + vec2(fbm(q * 0.8) * 1.4, 0.0)) - 0.5);
            float vein = 1.0 - smoothstep(0.0, 0.02, r);
            float pale = dot(base.rgb, vec3(0.33)) > 0.5 ? -1.0 : 1.0;
            w.albedo *= (1.0 + stone.y * (cloud - 0.5) * 2.0) * (1.0 + pale * stone.x * vein);
            w.rough += stone.z * ((cloud - 0.5) * 2.0 + 0.5 * vein);
            if (ring.x > 0.0) {
                // A finer mottling (a stone surface's ring.x, ring.y its features a unit),
                // and paler veins winding through it (ring.z), as jade and serpentine have.
                vec2 mq = q * ring.y;
                float mot = fbm3(mq + vec2(vnoise(mq * 0.7 + 3.3), 0.0) * 1.2 + 21.0);
                float ridge = ring.z > 0.0 ? 1.0 - smoothstep(0.0, 0.07, abs(fbm3(mq * 0.6 + 41.0) - 0.5)) : 0.0;
                w.albedo *= (1.0 + ring.x * (mot - 0.5) * 2.0) * (1.0 + ring.z * ridge);
                w.rough += 0.1 * ring.x * (0.5 - mot);
            }
            if (stone.w > 0.0 && mode.x > 0.5) {
                // Granite on the frame: dark and pale grains a texel or two across.
                float dk = smoothstep(0.6, 0.85, vnoise(q * 120.0));
                float lt = smoothstep(0.68, 0.88, vnoise(q * 95.0 + 31.0));
                w.albedo *= (1.0 - 0.4 * stone.w * dk) * (1.0 + 0.35 * stone.w * lt);
                w.rough += 0.08 * stone.w * (dk - lt);
                w.height += 0.3 * stone.w * (lt - dk);
                // Coarse: the mottling raised a little, the stone's bumpy grain.
                if (ring.x > 0.0) w.height += 2.0 * ring.x * (fbm3(q * ring.y * 1.5 + 61.0) - 0.5);
            }
        }
        return w;
    }

    // The wood's finish (looks::Finish), on wood only: grain scales the figure's
    // contrast round the base color (in the exponent, as Beer's law has it), warmth
    // shifts the color, varnish lowers the roughness and fills the pores a little,
    // sanding makes the relief shallower. Pickling (tone.y, limewash) turns the grain
    // round, paler than the wood where it was darker, and fills the pores and grooves
    // (the cavity) with matte white, level with the surface.
    Wood wood(vec2 q, float seed, vec4 base, vec4 k, vec3 f, vec4 ring) {
        Wood w = figure(q, seed, base, k, f, ring);
        if (k.w < 0.5) return w;
        vec3 b = srgb(base.rgb);
        w.albedo = b * pow(max(w.albedo / b, vec3(1e-3)), vec3(finish.z * (1.0 - 1.6 * tone.y)));
        if (tone.y > 0.0) {
            float fill = tone.y * clamp((1.0 - w.cavity) * 2.5, 0.0, 1.0);
            w.albedo = mix(w.albedo, vec3(0.8, 0.79, 0.75), fill);
            w.rough += 0.12 * fill;
            w.height += 0.8 * fill;
            w.cavity = mix(w.cavity, 1.0, fill);
        }
        w.albedo *= vec3(1.0 + 0.1 * tone.x, 1.0 + 0.02 * tone.x, 1.0 - 0.14 * tone.x);
        w.rough = mix(w.rough, 0.55 * w.rough, finish.x);
        w.cavity = mix(w.cavity, 1.0, 0.3 * finish.x + 0.5 * finish.y);
        w.height *= 1.0 - 0.7 * finish.y;
        return w;
    }

    // Marble, polished, one solid block whose figure runs one way (a stone frame with
    // mode.w > 0; task 039). Perlin's turbulent marble without the sine: the veins are
    // contours of a ramp across the flow plus a domain-warped noise (Quilez's warp,
    // noise of the point moved by noise of noise), so they run long and one way,
    // wander, merge and part, never close into rings as contours of noise alone do.
    // Each contour has its own strength and fades in and out along its length; its
    // width is kept even by dividing the distance by the field's slope (fwidth: the
    // bake is a fragment shader), with a soft cloudy halo by the softness. Finer,
    // fainter veins of a second such field, cracks joining them (the edges of warped
    // cells, Worley's), and bundles of thin threads (close contours of a third) by the
    // form. q: x across the frame map's grain, y along it (world x on the block), in
    // world units. Flat: polished stone has no relief. The colors drawn toward the
    // board's steel blue by the tint, their lightness kept.
    vec2 cells(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        float d1 = 8.0;
        float d2 = 8.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 o = vec2(float(x), float(y));
                vec2 c = o + vec2(h12(i + o), h12(i + o + 19.7)) * 0.9 + 0.05 - f;
                float d = dot(c, c);
                if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
            }
        }
        return vec2(sqrt(d1), sqrt(d2));
    }
    vec3 steel(vec3 c, float t) {
        const vec3 STEEL = vec3(0.36, 0.42, 0.48);
        float l = dot(c, vec3(0.3, 0.55, 0.15));
        return mix(c, STEEL * (l / dot(STEEL, vec3(0.3, 0.55, 0.15))), t);
    }
    // A contour of g at each whole number: its strength (some faint, some none) fading
    // along sw, a crisp core `width` across (world units) with a halo by `soft`.
    float vein(float g, float width, float soft, float seed, vec2 sw, float share) {
        float texel = size.z / size.x;
        float level = floor(g + 0.5);
        float dist = abs(g - level) / max(fwidth(g), 1e-5) * texel;
        float strength = smoothstep(1.0 - share, 1.0 - share + 0.35, h12(vec2(level, seed)))
                       * smoothstep(0.3, 0.6, fbm3(vec2(sw.x * 1.2, sw.y * 0.8) + level * 7.1 + seed));
        float w = width * (0.4 + 1.2 * vnoise(sw * vec2(2.0, 3.0) + level + seed));
        float core = 1.0 - smoothstep(w * (1.0 - 0.8 * soft), w + texel, dist);
        float halo = exp(-dist / (0.015 + 0.1 * soft)) * (0.2 + 0.8 * soft);
        return strength * max(core, 0.6 * halo);
    }
    Wood marble_at(vec2 q) {
        float texel = size.z / size.x;
        float veins = marble.x;
        float wave = marble.y;
        float soft = marble_form.y;
        // One way: leaning about 24 degrees off the board's x.
        const float C = 0.913;
        const float S = 0.407;
        vec2 r = vec2(C * q.x + S * q.y, -S * q.x + C * q.y);
        vec2 s = vec2(r.x, r.y * 0.4);
        vec2 w1 = vec2(fbm3(s * 0.5 + vec2(3.1, 7.7)), fbm3(s * 0.5 + vec2(8.4, 1.9))) - 0.5;
        vec2 w2 = vec2(fbm3(s * 0.7 + 2.0 * wave * w1 + vec2(5.5, 2.2)),
                       fbm3(s * 0.7 + 2.0 * wave * w1 + vec2(1.1, 6.6))) - 0.5;
        vec2 sw = s + wave * (1.2 * w1 + 0.5 * w2);
        // The main veins, about 1.3 contours a unit across the flow, half of them shown.
        float g = r.x * 1.3 + wave * 2.2 * (fbm3(sw * 0.5 + 11.3) - 0.5)
                + 0.03 * (vnoise(sw * 5.0) - 0.5);
        float v = vein(g, marble_form.x, soft, 3.7, sw, 0.5);
        // Finer, fainter veins between them, and cracks joining them, in places.
        if (marble_form.z > 0.0) {
            float g2 = r.x * 3.7 + wave * 3.2 * (fbm3(sw * 0.9 + 23.0) - 0.5)
                     + 0.04 * (vnoise(sw * 8.0) - 0.5);
            v = max(v, 0.55 * marble_form.z * vein(g2, 0.4 * marble_form.x, 0.5 * soft, 8.1, sw, 0.6));
            vec2 cp = sw * vec2(1.1, 0.9) + 2.5 * w2;
            vec2 c = cells(cp);
            // The width from the cells' coordinate, which runs on across their edges
            // (fwidth of the edge distance jumps there and broke the cracks into dashes).
            float e = (c.y - c.x) * 0.5;
            float crack = 1.0 - smoothstep(0.4, 1.3, e / max(length(fwidth(cp)), 1e-5));
            crack *= smoothstep(0.55, 0.75, fbm3(sw * 0.9 + 21.0));
            v = max(v, 0.6 * marble_form.z * crack);
        }
        // Bundles of thin wavy threads along the flow.
        float threads = 0.0;
        if (marble_form.w > 0.0) {
            float h = r.x * 14.0 + wave * 9.0 * (fbm3(sw * 0.8 + 31.0) - 0.5) + 3.0 * w2.x
                    + 2.0 * (vnoise(vec2(r.x * 3.0, sw.y * 0.5)) - 0.5);
            float d = abs(h - floor(h + 0.5)) / max(fwidth(h), 1e-5);
            float t = 1.0 - smoothstep(0.3, 1.1, d);
            // In bundles that follow the flow (across it, g), some threads missing.
            float bundle = vnoise(vec2(g * 0.9 + 41.0, sw.y * 0.25));
            t *= smoothstep(0.58, 0.72, bundle) * step(0.3, h12(vec2(floor(h + 0.5), 9.1)))
               * (0.4 + 0.6 * h12(vec2(floor(h + 0.5), 5.3)));
            threads = t * marble_form.w;
        }
        float cloud = fbm(sw * 1.6 + 51.0) - 0.5;
        vec3 base = srgb(steel(marble_base.rgb, marble.w));
        vec3 vein_c = srgb(steel(marble_vein.rgb, marble.w));
        vec3 thread_c = mix(vein_c, vec3(0.8), marble_vein.w);
        base *= 1.0 + marble_base.w * 2.0 * cloud;
        float vv = clamp(v * veins, 0.0, 1.0);
        Wood m;
        m.albedo = mix(base, vein_c, vv);
        m.albedo = mix(m.albedo, thread_c, clamp(threads * veins, 0.0, 1.0));
        m.rough = mix(0.5, 0.06, marble.z) + 0.03 * vv + 0.04 * cloud;
        m.height = 0.0;
        m.cavity = 1.0;
        return m;
    }

    // What wood() is given for a point, and what is laid over its result: the albedo
    // scaled, the height lowered, the roughness toward a seam's.
    struct Cut { vec2 q; float seed; vec4 base; vec4 k; vec3 f; vec4 ring;
                 float shade; float dip; float seam; };

    // The field: light and dark squares, each its own stretch of the surface and its own
    // tone, thin dark seams between them; round them a dark inlay, its grain along each
    // side, a fine dark line where it meets the squares.
    Cut plan(vec2 p) {
        Cut c;
        vec2 a = abs(p);
        float m = max(a.x, a.y);
        c.f = vec3(surface.y, 0.0, 0.0);
        c.seam = 0.0;
        if (m > FIELD) {
            bool along_x = a.y > a.x;
            c.q = along_x ? p.yx : p;
            // The growth rings give each of the four sides its own piece.
            c.seed = along_x ? 71.0 : 83.0;
            if (mode.y > 0.5 && inlay_fig.w > 0.5) c.seed += (along_x ? p.y : p.x) > 0.0 ? 0.0 : 2.0;
            c.base = inlay;
            c.k = inlay_fig;
            c.ring = dark_ring;
            float line = 1.0 - smoothstep(0.004, 0.010, m - FIELD);
            c.shade = 1.0 - 0.6 * line;
            c.dip = line;
            return c;
        }
        // mode.z squares per side (8 or 10), each 8 / mode.z across.
        float n = mode.z;
        vec2 g = (p + FIELD) * (n / (2.0 * FIELD));
        ivec2 sq = clamp(ivec2(floor(g)), ivec2(0), ivec2(int(n) - 1));
        bool dark = ((sq.x + sq.y) & 1) == 1;
        c.q = p;
        c.seed = float(sq.y * int(n) + sq.x) + 1.0;
        c.base = dark ? dark_sq : light_sq;
        c.k = dark ? dark_fig : light_fig;
        c.ring = dark ? dark_ring : light_ring;
        vec2 fr = fract(g);
        float edge = min(min(fr.x, 1.0 - fr.x), min(fr.y, 1.0 - fr.y)) * (2.0 * FIELD / n);
        c.seam = 1.0 - smoothstep(0.002, 0.007, edge);
        c.shade = (1.0 + surface.x * (h12(vec2(c.seed, 4.2)) - 0.5)) * (1.0 - surface.z * c.seam);
        c.dip = c.seam;
        return c;
    }

    // The carved frame (task 041, carve.w), its motif carve_more.x: 0 two thin vines in
    // low relief on the frame's top and outer face, interlaced over and under, slender
    // leaves in the eyes between their crossings and a pair at each crossing, a leaf knot
    // (a boss, a ring, four leaves) on each corner's diagonal, a shallow outline cut round
    // them and the stone beyond it left whole; 1 the Baltic folk band cut into the top
    // between two lines, diamonds with a cross in each and between them zigzags and a
    // running meander by turns, a sun wheel (a ring, eight spokes) on each corner's
    // diagonal and a tree of life mid-side on the far and near sides; 2 signs cut into the
    // top, for amber: sun signs and small runic marks by turns, a tree of life mid-side on
    // the far and near sides, a sun on each corner. A height field the bake's normal
    // takes, the cuts a cavity for the occlusion, the moss and the fill (Theme.fill: the
    // leaves' tint, the cut wood's color, the amber). Every edge at least a texel soft, so
    // the mips average it and the frame's Toksvig term widens the roughness where they
    // do. Signed distances in world units: the stems as offset curves, the leaves
    // vesicas, the cut strokes segments, rings and wedges.
    // The map is the mitred frame's (LIT_FRAG): each piece its own band of the map,
    // along it the world's x or z, across the length along the profile (v_uv.y). Two
    // pieces meet on each corner's diagonal, the one at +along and the other at -along
    // in its own band, so the pattern is laid out by |along| near the corners (the cut
    // motifs everywhere, mirrored about each side's middle): the knot or the medallion
    // centred on the diagonal, symmetric, hides the mirror's seam. Along the corners'
    // quarter round the band runs on an arc, at a length along of the band's middle.
    const float PI = 3.14159265;
    const float C_INNER = 4.1;
    const float TOP_AT = 0.0449;     // v_uv.y less the distance out on the frame's top
    const float TOP_MID = 0.256;     // the top band's middle across (v_uv.y)
    const float SIDE_MID = 0.86;     // the outer face's band's
    const float BAND = 0.17;         // the vines' band's half width
    const float STRAND_W = 0.016;    // a vine's half width
    const float SWAY = 0.1;          // how far a vine sways from the band's middle
    const float OUTLINE = 0.011;     // the outline cut round the vines, its width
    const float CUT_W = 0.0135;      // a cut stroke's half width
    const float FOLK_LINE = 0.182;   // the folk band's lines, from its middle
    float vesica(vec2 p, float r, float d) {
        p = abs(p);
        float b = sqrt(r * r - d * d);
        return ((p.y - b) * d > p.x * b) ? length(p - vec2(0.0, b)) : length(p - vec2(-d, 0.0)) - r;
    }
    // A slender leaf from its base `at` along `dir`, `len` long and 0.28 of that wide, its
    // tip bent sideways by `bend` (a share of its length): the Art Nouveau curl.
    float leaf(vec2 p, vec2 at, vec2 dir, float len, float bend) {
        vec2 q = p - at;
        q = vec2(dot(q, vec2(dir.y, -dir.x)), dot(q, dir));
        q.x -= bend * q.y * q.y / len;
        q.y -= 0.5 * len;
        float b = 0.5 * len;
        float h = 0.16 * len;
        float s = b * b / h;
        return vesica(q, 0.5 * (s + h), 0.5 * (s - h));
    }
    // A motif's dome from its signed distance: 0 outside, rounding up to 1 over `round`.
    float dome(float d, float round) {
        float texel = size.z / size.x;
        float m = clamp((-d + 0.5 * texel) / (round + texel), 0.0, 1.0);
        return m * (2.0 - m);
    }
    // The vines' band at x along (signed, by its middle's length), y across from its
    // middle, its corner's arc of radius rc: the motifs' height (0..1), the cut's mask
    // (the outline round them), the leaves' share, how near the motifs (where moss
    // clings).
    vec4 vines(float x, float y, float rc) {
        float texel = size.z / size.x;
        float band = 1.0 - smoothstep(BAND - 0.004, BAND + 0.004 + texel, abs(y));
        if (band <= 0.0) return vec4(0.0);
        float xc = C_INNER + rc * 0.25 * PI;
        float m = max(floor((carve.y - 1.0) * 0.5 + 0.5), 1.0);
        float k = PI * (m + 0.5) / xc;
        // Two vines crossing at each kx = (j + 0.5) pi and at the knot: the j-th
        // crossing's over vine alternates along each.
        float c = cos(k * x);
        float slope = SWAY * k * sin(k * x);
        float norm = inversesqrt(1.0 + slope * slope);
        float d1 = abs(y - SWAY * c) * norm - STRAND_W;
        float d2 = abs(y + SWAY * c) * norm - STRAND_W;
        float j = floor(k * x / PI);
        float xj = (j + 0.5) * PI / k;
        float near = 1.0 - smoothstep(0.02, 0.09, abs(x - xj));
        bool first = mod(j, 2.0) < 0.5;
        float d_over = first ? d1 : d2;
        float d_under = first ? d2 : d1;
        float under = dome(d_under, 0.6 * STRAND_W) * (1.0 - 0.45 * near)
                    * mix(1.0, smoothstep(0.004, 0.011 + texel, d_over), near);
        float h = max(dome(d_over, STRAND_W), under);
        float dm = min(d1, d2);
        // Leaves: one from each vine into each eye, the two turned half round each other
        // (the upper one from right of the middle reaching down and on, the lower from
        // left of it reaching up and back), curling; a pair at each crossing reaching
        // out, leaning one way at even crossings and the other at odd ones.
        float e = floor(k * x / PI + 0.5);
        float xe = e * PI / k;
        float half_eye = 0.5 * PI / k;
        float lf = 1e3;
        for (int s = -1; s <= 1; s += 2) {
            float side = float(s) * (mod(e, 2.0) < 0.5 ? 1.0 : -1.0);   // +1: on the eye's +y
            float xb = xe + side * 0.42 * half_eye;
            float yb = float(s) * SWAY * cos(k * xb);
            vec2 dir = normalize(vec2(-side * 0.88, -side * 0.48));
            lf = min(lf, leaf(vec2(x, y), vec2(xb, yb) - dir * 0.045, dir, 0.28, 0.25));
        }
        float lean = mod(j, 2.0) < 0.5 ? 1.0 : -1.0;
        for (int s = -1; s <= 1; s += 2) {
            vec2 dir = normalize(vec2(0.5 * lean, float(s)));
            lf = min(lf, leaf(vec2(x, y), vec2(xj, 0.0) + dir * 0.025, dir, 0.12, -0.25 * lean * float(s)));
        }
        float stems = dome(dm - 0.003, 0.004);
        h = max(h, 0.85 * dome(lf, 0.02) * (1.0 - stems));
        float leaves = (1.0 - smoothstep(-texel, texel, lf)) * (1.0 - stems);
        dm = min(dm, lf);
        // The knot on the corner's diagonal: the vines pass under a ring, a boss over
        // their crossing, four leaves out from the ring.
        vec2 kp = vec2(abs(x) - xc, y);
        float kr = length(kp);
        if (kr < 0.25) {
            float ring = abs(kr - 0.08) - 0.011;
            h *= smoothstep(0.003, 0.010 + texel, ring);
            leaves *= smoothstep(0.003, 0.010 + texel, ring);
            h = max(h, dome(ring, 0.011));
            float boss = kr - 0.035;
            h = max(h, dome(boss, 0.03));
            float kl = 1e3;
            for (int i = 0; i < 4; i++) {
                float a = radians(i < 2 ? 40.0 : 140.0) * (i % 2 == 0 ? 1.0 : -1.0);
                vec2 dir = vec2(cos(a), sin(a));
                kl = min(kl, leaf(kp, dir * 0.08, dir, 0.1, 0.2 * (i % 2 == 0 ? 1.0 : -1.0)));
            }
            float out_ring = smoothstep(0.0, 0.006, ring);
            h = max(h, 0.9 * dome(kl, 0.02) * out_ring);
            leaves = max(leaves, (1.0 - smoothstep(-texel, texel, kl)) * out_ring);
            dm = min(dm, min(min(ring, boss), kl));
        }
        // The cut: an outline of OUTLINE round the motifs, its outer edge a texel soft.
        float cut = band * (1.0 - smoothstep(OUTLINE, OUTLINE + texel, dm));
        return vec4(h, cut, leaves, band * (1.0 - smoothstep(OUTLINE, 0.045, dm)));
    }

    float seg(vec2 p, vec2 a, vec2 b) {
        vec2 pa = p - a;
        vec2 ba = b - a;
        return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
    }
    // The angle of p off the nearest of n spokes (one along +x), turned by `turn` spokes.
    float spoke(vec2 p, float n, float turn) {
        float k = 2.0 * PI / n;
        float a = atan(p.y, p.x + 1e-7) - turn * k;
        return a - k * floor(a / k + 0.5);
    }
    // A tree of life `s` from its middle to its top, upright along +y: a trunk, three
    // pairs of branches rising out, a twig up from each, two pairs of roots. The
    // distance to its strokes' middles.
    float tree(vec2 p, float s) {
        p /= s;
        vec2 q = vec2(abs(p.x), p.y);
        float d = seg(q, vec2(0.0, -0.75), vec2(0.0, 0.98));
        for (int i = 0; i < 3; i++) {
            float y0 = -0.38 + 0.34 * float(i);
            vec2 tip = vec2(0.95 - 0.2 * float(i), y0 + 0.62);
            d = min(d, seg(q, vec2(0.0, y0), tip));
            vec2 mid = mix(vec2(0.0, y0), tip, 0.5);
            d = min(d, seg(q, mid, mid + vec2(0.02, 0.34)));
            d = min(d, seg(q, tip, tip + vec2(0.16, -0.12)));
        }
        d = min(d, seg(q, vec2(0.0, -0.55), vec2(0.55, -0.95)));
        d = min(d, seg(q, vec2(0.0, -0.75), vec2(0.22, -1.0)));
        return d * s;
    }
    // A sun wheel of radius r: a ring and eight spokes from the hub, widening out.
    float sun_wheel(vec2 p, float r) {
        float l = length(p);
        float ad = spoke(p, 8.0, 0.0);
        float spokes = max(abs(l * sin(ad)) - CUT_W * (0.4 + 1.3 * l / r), l - 0.78 * r);
        return min(abs(l - r) - CUT_W, spokes);
    }
    // Two diamonds one in the other, `r` the outer's half diagonal, a cross in the inner.
    float diamond(vec2 p, float r) {
        vec2 a = abs(p);
        float outer = abs(a.x + a.y - r) * 0.7071 - CUT_W;
        float inner = abs(a.x + a.y - 0.56 * r) * 0.7071 - 0.85 * CUT_W;
        float cross = max(min(a.x, a.y) - 0.8 * CUT_W, max(a.x, a.y) - 0.27 * r);
        return min(min(outer, inner), cross);
    }
    // A zigzag along t (from its start), y across, a its sway, len a wavelength, a small
    // cross in each bay it leaves, above and below by turns.
    float zigzag(float t, float y, float a, float len) {
        float f = fract(t / len);
        float z = a * (4.0 * abs(f - 0.5) - 1.0);
        float norm = inversesqrt(1.0 + 16.0 * a * a / (len * len));
        float d = abs(y - z) * norm - CUT_W;
        vec2 up = abs(vec2((f - 0.5) * len, y - 0.45 * a));
        vec2 dn = abs(vec2((f - floor(f + 0.5)) * len, y + 0.45 * a));
        float c_up = max(min(up.x, up.y) - 0.75 * CUT_W, max(up.x, up.y) - 0.4 * a);
        float c_dn = max(min(dn.x, dn.y) - 0.75 * CUT_W, max(dn.x, dn.y) - 0.4 * a);
        return min(d, min(c_up, c_dn));
    }
    // A running meander along t: a line stepping between ±a, len a step and back.
    float meander(float t, float y, float a, float len) {
        float u = t - len * floor(t / len);
        float d = abs(y - (u < 0.5 * len ? a : -a));
        float yc = clamp(y, -a, a);
        d = min(d, length(vec2(u, y - yc)));
        d = min(d, length(vec2(u - 0.5 * len, y - yc)));
        d = min(d, length(vec2(u - len, y - yc)));
        return d - 0.9 * CUT_W;
    }
    // The folk band at x along (signed, by its middle's length), y across from its middle,
    // on band `side` (0 the near side, 1 the far, 2 and 3 those along z), its corner's arc
    // of radius rc: the cut strokes' signed distance. Diamonds at n steps from the side's
    // middle to the corner's medallion (n from the repeats per side), a tree there on the
    // far and near sides; zigzags and a meander between them by turns.
    float folk(float x, float y, float rc, float side) {
        float xc = C_INNER + rc * 0.25 * PI;
        float n = max(floor(carve.y * 0.5 + 0.5), 2.0);
        float step_ = xc / n;
        float u = abs(x);
        float j = clamp(floor(u / step_ + 0.5), 0.0, n);
        vec2 e = vec2(u - j * step_, y);
        bool trees = side < 1.5;
        float up = side < 0.5 ? -1.0 : 1.0;
        float d = abs(abs(y) - FOLK_LINE) - 0.8 * CUT_W;
        float m = j > n - 0.5 ? sun_wheel(e, 0.155)
                : (j < 0.5 && trees ? tree(vec2(e.x, e.y * up), 0.165) - CUT_W : diamond(e, 0.15));
        d = min(d, m);
        float g = min(floor(u / step_), n - 1.0);
        float lo = g * step_ + (g < 0.5 && trees ? 0.2 : 0.175);
        float hi = (g + 1.0) * step_ - (g > n - 1.5 ? 0.2 : 0.175);
        float span = hi - lo;
        if (span > 0.05) {
            float t = u - lo;
            float pat = mod(g, 2.0) < 0.5 ? zigzag(t, y, 0.08, span / max(floor(span / 0.17 + 0.5), 1.0))
                                          : meander(t, y, 0.078, span / max(floor(span / 0.2 + 0.5), 1.0));
            d = min(d, max(pat, max(lo - u, u - hi)));
        }
        return d;
    }
    // A sun sign of radius r: a disc and eight rays round it, eight shorter between.
    float sun_sign(vec2 p, float r) {
        float l = length(p);
        float disc = l - 0.34 * r;
        float t = clamp((l - 0.48 * r) / (0.52 * r), 0.0, 1.0);
        float ray = max(abs(l * sin(spoke(p, 8.0, 0.0))) - 0.15 * r * (1.0 - t) - 0.25 * CUT_W,
                        max(0.48 * r - l, l - r));
        float t2 = clamp((l - 0.48 * r) / (0.3 * r), 0.0, 1.0);
        float ray2 = max(abs(l * sin(spoke(p, 8.0, 0.5))) - 0.1 * r * (1.0 - t2) - 0.25 * CUT_W,
                         max(0.48 * r - l, l - 0.78 * r));
        return min(disc, min(ray, ray2));
    }
    // A runic mark `s` from its middle to its top, upright along +y, symmetric: kind 0 a
    // stave with a chevron at its top, 1 a diamond on a stave, 2 two chevrons one over the
    // other, 3 a stave crossed by two diagonals. The cut's signed distance.
    float rune(vec2 p, float kind, float s) {
        p /= s;
        vec2 q = vec2(abs(p.x), p.y);
        float d;
        if (kind < 0.5) {
            d = min(seg(q, vec2(0.0, -1.0), vec2(0.0, 1.0)), seg(q, vec2(0.0, 1.0), vec2(0.55, 0.42)));
        } else if (kind < 1.5) {
            d = abs(q.x + abs(p.y) - 0.55) * 0.7071;
            d = min(d, seg(vec2(q.x, abs(p.y)), vec2(0.0, 0.55), vec2(0.0, 1.0)));
        } else if (kind < 2.5) {
            d = min(seg(q, vec2(0.0, 0.85), vec2(0.62, 0.25)), seg(q, vec2(0.0, 0.0), vec2(0.62, -0.6)));
        } else {
            d = min(seg(q, vec2(0.0, -1.0), vec2(0.0, 1.0)), seg(abs(p), vec2(0.0), vec2(0.55, 0.55)));
        }
        return d * s - 0.85 * CUT_W;
    }
    // The signs at x along, y across, on band `side`, its corner's arc of radius rc: suns
    // and runic marks by turns at 2n steps from the side's middle to the corner, a tree
    // of life in the middle of the far and near sides, a sun on the corner.
    float signs(float x, float y, float rc, float side) {
        float xc = C_INNER + rc * 0.25 * PI;
        float n = 2.0 * max(floor(carve.y * 0.25 + 0.5), 1.0);
        const float W = 1.45;   // the signs' strokes wider than the folk band's
        float step_ = xc / n;
        float u = abs(x);
        float j = clamp(floor(u / step_ + 0.5), 0.0, n);
        vec2 e = vec2(u - j * step_, y);
        vec2 eu = vec2(e.x, side < 0.5 ? -e.y : e.y);
        if (j < 0.5 && side < 1.5) return tree(eu, 0.185) - W * CUT_W;
        if (mod(j, 2.0) < 0.5) return sun_sign(e, 0.16);
        return rune(eu, mod(floor(j * 0.5) + side, 4.0), 0.11) - (W - 1.0) * CUT_W;
    }

    // What the carving gives a point of the frame map: its height (world units, 0 the
    // surface), how far it is in the cut ground (0..1), how near a motif's foot (where
    // moss gathers), the fill's share (Theme.fill), and how deep the amber is over the
    // cut there (0..1, its glow).
    struct Carve { float h; float hollow; float foot; float fill; float glow; };
    // q: x across from the band's start, y along; band: the mitred piece (0 the near
    // side, 1 the far, 2 and 3 the sides along z).
    Carve carving(vec2 q, float band) {
        Carve r = Carve(0.0, 0.0, 0.0, 0.0, 0.0);
        float across = q.x - 0.2;
        float along = q.y - 5.2;
        bool top = across < 0.55;
        float motif = carve_more.x;
        if (!top && motif > 0.5) return r;
        float mid = top ? TOP_MID : SIDE_MID;
        float rc = top ? TOP_MID - TOP_AT : 0.5;
        float rr = top ? max(across - TOP_AT, 0.01) : 0.5;
        float a = abs(along);
        float x = a;
        if (a > C_INNER) x = C_INNER + rc * (0.5 * PI - acos(clamp((a - C_INNER) / rr, 0.0, 1.0)));
        float y = across - mid;
        if (motif < 0.5) {
            vec4 v = vines(sign(along) * x, y, rc);
            r.hollow = v.y * (1.0 - v.x);
            r.h = -carve.x * r.hollow;
            r.foot = max(v.y * (1.0 - smoothstep(0.0, 0.5, v.x)) * smoothstep(0.0, 0.15, v.x + 0.02),
                         0.6 * v.w * (1.0 - v.x));
            r.fill = v.z;
            return r;
        }
        // A rounded groove from the strokes' signed distance, deepest along their middle;
        // the amber filling it to `level` below the surface, level and glossy.
        float d = motif < 1.5 ? folk(x, y, rc, band) : signs(x, y, rc, band);
        float cut = dome(d, motif < 1.5 ? CUT_W : 1.45 * CUT_W);
        float level = 1.0 - carve_more.y;
        r.h = -carve.x * min(cut, level);
        r.hollow = cut;
        r.foot = smoothstep(0.0, 0.3, cut) * (1.0 - smoothstep(0.3, 0.8, cut));
        r.fill = carve_more.y > 0.0 ? smoothstep(level - 0.02, level + 0.1, cut) : smoothstep(0.0, 0.45, cut);
        r.glow = clamp((cut - level) / max(carve_more.y, 1e-3), 0.0, 1.0);
        return r;
    }

    // The frame map: the frame's wood or stone over a square, its grain along u.
    // The growth rings give each band of the map (each mitred piece, LIT_FRAG) its own
    // log and cut, across measured from the band's start.
    Cut frame_map(vec2 p) {
        Cut c;
        c.f = frame_surface.xxz * vec3(0.3, 1.0, 1.0);
        c.q = p.yx;
        c.seed = 7.0;
        if ((mode.y > 0.5 && mode.y < 2.5 && frame_fig.w > 0.5) || carve.w > 0.5) {
            // Each band 1.4 apart, its profile from 0.2 to 1.46 into it: split them in the
            // gap between, so the foot of a piece's face keeps its own band.
            float band = floor((c.q.x - 0.13) / 1.4);
            c.q.x -= band * 1.4;
            c.seed = 7.0 + 5.0 * band;
        }
        c.base = frame;
        c.k = frame_fig;
        c.ring = frame_ring;
        c.shade = 1.0;
        c.dip = 0.0;
        c.seam = 0.0;
        return c;
    }

    // What the frame map lays over its wood: summer's caulked seams, the carving and its
    // moss.
    Wood frame_over(Wood w, Cut c, vec2 p) {
        vec2 q = c.q;
        float seed = c.seed;
        if (seam.x > 0.0 && frame_fig.w > 0.5) {
            // Caulked seams along each mitred piece (LIT_FRAG's bands of 1.4, the top's
            // inner edge 0.2 into its band), a plank's width apart over the top only.
            float across = p.y - floor(p.y / 1.4) * 1.4 - 0.2;
            float k = across / seam.x;
            float d = abs(k - floor(k + 0.5)) * seam.x;
            float texel = size.z / size.x;
            float line = (1.0 - smoothstep(seam.y, seam.y + texel, d))
                       * step(0.5 * seam.x, across) * step(across, 0.47) * min(tone.z, 1.0);
            w.albedo = mix(w.albedo, srgb(vec3(0.07, 0.06, 0.055)), clamp(line * seam.z * max(tone.z, 1.0), 0.0, 1.0));
            w.rough = mix(w.rough, 0.6, line);
            w.height -= 0.6 * line;
            w.cavity -= 0.3 * line;
        }
        if (carve.w > 0.5) {
            Carve cv = carving(q, floor((seed - 7.0) / 5.0 + 0.5));
            float across = q.x - 0.2;
            // The cut ground a little darker and rougher, moss settling in it in patches,
            // most at the motifs' feet, and along the frame's edges: its inner lip, its
            // rounded edge, the foot of its face.
            float patch = smoothstep(0.4, 0.75, mix(0.5, fbm(q * vec2(4.0, 1.6) + seed), moss.w));
            float edges = max(max(1.0 - smoothstep(0.02, 0.075, across), smoothstep(1.08, 1.24, across)),
                              0.6 * (1.0 - smoothstep(0.0, 0.06, abs(across - 0.5))));
            float edge_moss = edges * smoothstep(0.42, 0.78, fbm(q * vec2(5.0, 1.4) + seed + 3.0));
            float m = clamp(carve.z * ((1.2 * cv.hollow + 1.2 * cv.foot) * patch + edge_moss), 0.0, 1.0);
            float shade = 0.85 + 0.3 * vnoise(q * 40.0);
            // The cut's walls in their own shade where nothing fills them, a little
            // grime round the motifs' feet.
            w.albedo *= (1.0 - 0.45 * cv.hollow * (1.0 - cv.fill)) * (1.0 - 0.1 * cv.foot);
            w.albedo = mix(w.albedo, srgb(moss.rgb) * shade, m);
            w.rough = mix(w.rough + 0.15 * cv.hollow, 0.75, m);
            w.cavity *= 1.0 - 0.3 * cv.hollow - 0.3 * cv.foot;
            if (carve_more.z > 0.0) {
                // Lichen: small round rosettes scattered over the stone, more on the outer
                // face than on the top, out of the cuts, their rims frilled, paler toward
                // the rim; matte and a little raised.
                vec2 cq = q * 4.5 + seed * 3.1;
                vec2 ci = floor(cq);
                float share = 0.4 * carve_more.z * mix(0.5, 1.0, smoothstep(0.4, 0.7, across));
                float lich = 0.0;
                float rim = 0.0;
                for (int k = 0; k < 9; k++) {
                    vec2 id = ci + vec2(float(k % 3) - 1.0, float(k / 3) - 1.0);
                    float h = h12(id + 7.7);
                    if (h < share) {
                        vec2 c = id + 0.2 + 0.6 * vec2(h12(id + 1.9), h12(id + 4.3)) - cq;
                        float r = (0.2 + 0.22 * h12(id + 3.1)) * (0.88 + 0.24 * vnoise(cq * 9.0 + id));
                        float l = length(c);
                        float in_ = 1.0 - smoothstep(r - 0.06, r, l);
                        lich = max(lich, in_);
                        rim = max(rim, in_ * smoothstep(0.4 * r, r, l));
                    }
                }
                lich *= 1.0 - cv.hollow;
                vec3 lc = srgb(lichen.rgb) * (0.75 + 0.2 * vnoise(q * 90.0) + 0.25 * rim);
                w.albedo = mix(w.albedo, lc, 0.85 * lich);
                w.rough = mix(w.rough, 0.85, lich);
                w.height += 0.5 * lich;
            }
            // The fill: the leaves' tint, the cut's lighter wood (its grain kept), or the
            // amber: warm and glossy, level, darker where thin over the cut's walls and
            // brighter where it lies deep (the light it scatters back), catching the light.
            float f = cv.fill * fill.w;
            if (carve_more.y > 0.0) {
                vec3 deep = srgb(mix(fill.rgb, vec3(1.0, 0.9, 0.55), 0.4));
                w.albedo = mix(w.albedo, mix(srgb(fill.rgb) * 0.3, deep * 1.15, pow(cv.glow, 0.6)), f);
                w.rough = mix(w.rough, 0.08, f);
                w.cavity = mix(w.cavity, 1.0, 0.8 * f);
            } else {
                vec3 fig = sqrt(max(w.albedo / srgb(frame.rgb), vec3(0.0)));
                w.albedo = mix(w.albedo, srgb(fill.rgb) * fig, f);
                w.rough = mix(w.rough, w.rough + 0.1, f);
            }
            w.height += cv.h / (0.0015 * max(frame_surface.y, 1e-3));
        }
        return w;
    }

    // What the plan lays over its wood: the inlay's line and the squares' tone and seams
    // (the Cut's), and the carved look's engraved line round the field.
    Wood plan_over(Wood w, Cut c, vec2 p) {
        w.albedo *= c.shade;
        w.rough = mix(w.rough, 0.8, c.seam);
        w.height -= c.dip;
        float m = max(abs(p.x), abs(p.y));
        if (carve.w > 0.5 && carve_more.x < 0.5 && m > FIELD) {
            // The carved look's fine engraved line round the field, down the inlay's
            // middle, a texel soft.
            float texel = size.z / size.x;
            float cut = 1.0 - smoothstep(0.003, 0.006 + texel, abs(m - FIELD - 0.05));
            w.albedo *= 1.0 - 0.35 * cut;
            w.height -= 3.0 * cut;
        }
        return w;
    }

    // One call of wood() for every surface: each call site was compiled in full, and
    // the pipeline took seconds to make on a phone.
    Wood at(vec2 p) {
        Cut c = mode.x < 0.5 ? plan(p) : frame_map(p);
        Wood w = wood(c.q, c.seed, c.base, c.k, c.f, c.ring);
        return mode.x < 0.5 ? plan_over(w, c, p) : frame_over(w, c, p);
    }

    void main() {
        vec2 texel = size.zw / size.xy;
        vec2 p = gl_FragCoord.xy * texel - (mode.x < 0.5 ? 0.5 * size.zw : vec2(0.0));
        if (mode.x > 0.5 && mode.w > 0.5 && frame_fig.w < 0.5 && carve.w < 0.5) {
            // A marble frame, flat: once a texel, no relief to take the normal from.
            Wood m = marble_at(p.yx);
            out_albedo = vec4(m.albedo, m.rough);
            out_normal = vec4(0.5, 0.5, 1.0, 1.0);
            return;
        }
        // The texel and its neighbours along x and y, for the normal, in a loop the
        // compiler can't unroll (its count comes from the block): unrolled, the whole
        // wood was compiled three times over, and the pipeline took 2.5 s to make on the
        // Pixel 7a.
        Wood w;
        vec2 hn = vec2(0.0);
        int taps = mode.x > 9.0 ? 4 : 3;
        for (int k = 0; k < taps; k++) {
            vec2 o = k == 1 ? vec2(texel.x, 0.0) : (k == 2 ? vec2(0.0, texel.y) : vec2(0.0));
            Wood s = at(p + o);
            if (k == 0) w = s;
            else if (k == 1) hn.x = s.height;
            else hn.y = s.height;
        }
        vec2 grad = (hn - w.height) / texel;
        float relief = 0.0015 * (mode.x < 0.5 ? surface.w : frame_surface.y);
        vec3 n = normalize(vec3(-grad.x * relief, 1.0, -grad.y * relief));
        out_albedo = vec4(w.albedo, w.rough);
        // The normal's x and z, the cavity's occlusion, the normal's y: what the mips
        // average shortens the normal, which widens the roughness where they blur.
        out_normal = vec4(n.x * 0.5 + 0.5, n.z * 0.5 + 0.5, w.cavity, n.y);
    }
    """;

// The photograph shrunk to a small copy, and blurred: as src/app/scene.goose does it
// behind the 2D game (docs/architecture/rendering.md, "Scene and glass").
let SHRINK_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform Shrink { vec4 to; };
    void main() {
        vec2 pixel = 1.0 / to.xy;
        vec2 uv = gl_FragCoord.xy * pixel;
        ivec2 n = max(ivec2(ceil(pixel * vec2(textureSize(src, 0)) * 0.5)), ivec2(1));
        vec3 sum = vec3(0.0);
        for (int y = 0; y < n.y; y++) {
            for (int x = 0; x < n.x; x++) {
                sum += texture(src, uv + ((vec2(x, y) + 0.5) / vec2(n) - 0.5) * pixel).rgb;
            }
        }
        result = vec4(sum / float(n.x * n.y), 1.0);
    }
    """;

let BLUR_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform Blur { vec4 dir; };
    void main() {
        vec2 uv = gl_FragCoord.xy * dir.w;
        vec3 sum = vec3(0.0);
        float total = 0.0;
        for (int i = -17; i <= 17; i++) {
            float w = exp(-0.5 * float(i * i) / (dir.z * dir.z));
            sum += w * texture(src, uv + float(i) * dir.xy).rgb;
            total += w;
        }
        result = vec4(sum / total, 1.0);
    }
    """;

// The field's marks, added over it on a quad covering the field (QUAD_VERT, draw.x 2),
// tested against the depth so pieces hide them: per square of the world's grid
// (row * n + column, row 0 the far side), x the last move's tint (1), y a legal target's
// dot (1) or a capture's stop's ring (2), z the must-capture ring (1 pulsing, 2 still), w
// 0 where a wrong move's flash is (else -1); and the selected piece's glow ring round
// Frame.selected, wherever the piece is (a drag). Beside them `lit`, per square: x the
// glow ring tight round the piece there (a hint, a win's wave), y the square lit by a
// win's glow passing. A win's dim (screen.z) dims them all but the glow rings. draw.y:
// squares per side. As the flat board draws them (src/app/draw.goose).
//
// Two shaders: without PULSE, in the board's pass, everything that holds still; with
// PULSE (MARKS_PULSE first), what moves while nothing else does, drawn each frame over
// the kept image in the screen's pass (render3d::marks_over): the pulsing must-capture
// rings, the flash, the hint's pulsing ring, their phases from the Pulse block. That pass
// has no depth target, so the shader tests the kept depth (a 1x copy of the board's,
// made with it) itself, at the pixel's middle. Against the 4x pass's own test the rings
// differ only along the pieces' outlines, by fewer pixels than four taps mixed as the
// samples gave (task 015).
let MARKS_PULSE = "#define PULSE 1\n";
let MARKS_FRAG = """
    layout(location = 0) in vec3 v_pos;
    layout(location = 0) out vec4 result;
    #ifdef PULSE
    layout(set = 2, binding = 0) uniform sampler2D kept_depth;
    layout(std430, set = 2, binding = 1) readonly buffer Marks { vec4 marks[]; };
    layout(std430, set = 2, binding = 2) readonly buffer Lit { vec4 lit[]; };
    // pulse: x the must-capture rings' phase, y the flash (0 to 1), z the hint ring's
    // square (-1 none), w its strength; place: the kept image's top left on the target,
    // its texels per pixel, and how opaque it is laid.
    layout(set = 3, binding = 2) uniform Pulse { vec4 pulse; vec4 place; };
    #else
    layout(std430, set = 2, binding = 0) readonly buffer Marks { vec4 marks[]; };
    layout(std430, set = 2, binding = 1) readonly buffer Lit { vec4 lit[]; };
    #endif
    layout(set = 3, binding = 1) uniform Draw { vec4 draw; };
    float line(float d, float w) { return exp(-pow(d / (0.6 * w + 0.008), 2.0)); }
    #ifdef PULSE
    // Whether the board's depth leaves the quad here: its kept texel under the pixel.
    bool seen() {
        ivec2 t = ivec2(floor((gl_FragCoord.xy - place.xy) * place.z));
        return gl_FragCoord.z < texelFetch(kept_depth, clamp(t, ivec2(0), textureSize(kept_depth, 0) - 1), 0).r;
    }
    #endif
    void main() {
        vec3 c = vec3(0.0);
        float n = draw.y;
        float u = 2.0 * FIELD / n;
        vec2 g = (v_pos.xz + FIELD) / u;
        ivec2 q = ivec2(floor(g));
        // A pixel in squares, from g, which runs on across the squares' edges.
        float wg = max(length(fwidth(g)) * 0.7, 0.002);
    #ifndef PULSE
        // The selected piece's ring, a little out from it, and a soft halo.
        if (selected.w > 0.0) {
            float r = length(v_pos.xz - selected.xz);
            float ring = 1.08 * selected.w;
            float w = max(fwidth(r), 0.01);
            float halo = exp(-max(r - ring, 0.0) / 0.07) * smoothstep(ring - 0.04, ring, r);
            c += glow.rgb * glow.w * (0.85 * line(r - ring, w) + 0.3 * halo);
        }
        if (q.x >= 0 && q.y >= 0 && q.x < int(n) && q.y < int(n)) {
            vec4 m = marks[q.y * int(n) + q.x];
            float r = length(fract(g) - 0.5);       // in squares from its middle
            float w = wg;
            if (m.x > 0.5) c += glow.rgb * 0.10;
            if (m.y > 0.5 && m.y < 1.5) {
                c += glow.rgb * (0.9 * (1.0 - smoothstep(0.15 - w, 0.15 + w, r))
                                 + 0.35 * exp(-max(r - 0.15, 0.0) / 0.05));
            }
            if (m.y > 1.5) c += glow.rgb * 0.9 * line(r - 0.18, w);
            // A win's glow passing lights the square, as the last move's tint does more.
            c += glow.rgb * 0.3 * lit[q.y * int(n) + q.x].y;
        }
    #endif
        vec3 rings = vec3(0.0);
        // The red rings go a little out from a piece (0.44 of a square), past its square's
        // edge, so each pixel looks at the squares round it too.
        vec3 red = vec3(1.0, 0.353, 0.29);
        vec3 reds = vec3(0.0);
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                ivec2 k = q + ivec2(dx, dy);
                if (k.x < 0 || k.y < 0 || k.x >= int(n) || k.y >= int(n)) continue;
                int at = k.y * int(n) + k.x;
                vec4 m = marks[at];
                float r = length(g - (vec2(k) + 0.5));
                float w = wg;
                // The glow ring tight round a piece (0.44 of a square), with a soft halo.
    #ifdef PULSE
                float k_ring = float(at) == pulse.z ? pulse.w : 0.0;
    #else
                float k_ring = lit[at].x;
    #endif
                if (k_ring > 0.0) {
                    float rr = 0.47;
                    float halo = exp(-max(r - rr, 0.0) / 0.06) * smoothstep(rr - 0.04, rr, r);
                    rings += glow.rgb * glow.w * k_ring * (1.1 * line(r - rr, w) + 0.45 * halo);
                }
                // The must-capture ring: brightest still, fading to 0.4 and back pulsing.
    #ifdef PULSE
                float strength = m.z > 0.5 && m.z < 1.5 ? 0.95 - 0.55 * pulse.x : 0.0;
    #else
                float strength = m.z > 1.5 ? 0.95 : 0.0;
    #endif
                if (strength > 0.0) {
                    float rr = 0.52;
                    reds += red * strength * (0.9 * line(r - rr, w) + 0.35 * exp(-abs(r - rr) / 0.04));
                }
    #ifdef PULSE
                if (m.w >= 0.0 && pulse.y < 1.0) {
                    float t = fract(pulse.y * 2.0);
                    float op = t < 0.4 ? t / 0.4 : 1.0 - 0.4 * (t - 0.4) / 0.6;
                    float rr = 0.5 * (0.8 + 0.2 * min(t / 0.4, 1.0));
                    reds += red * op * (0.9 * line(r - rr, w) + 0.25 * (1.0 - smoothstep(rr - w, rr + w, r)));
                }
    #endif
            }
        }
        // A win's dim dims the still marks, not the rings round pieces.
        c = c * (1.0 - screen.z) + reds + rings;
    #ifdef PULSE
        // The depth is read only where there is something to add.
        result = c.r + c.g + c.b > 0.0 && seen() ? vec4(c, place.w) : vec4(0.0);
    #else
        result = vec4(c, 1.0);
    #endif
    }
    """;

// A texture drawn over the whole target as it is: the 3D board's image kept from the
// last frame that drew it, under the UI.
let COPY_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    void main() { result = vec4(texelFetch(src, ivec2(gl_FragCoord.xy), 0).rgb, 1.0); }
    """;

// The kept image (premultiplied, clear where no board is) drawn over what is there: its
// rect `from` (pixels of the image) into the rect `to` (pixels of the target), at
// opacity screen.z; the same rect texel for texel at rest, moved and scaled in a
// transition.
let SHOW_VS = "#define SHOW_SET 1\n";
let SHOW_FS = "#define SHOW_SET 3\n";
let SHOW_BLOCK = """
    layout(set = SHOW_SET, binding = 0) uniform Show { vec4 from_rect; vec4 to_rect; vec4 screen; };
    """;
let SHOW_VERT = """
    layout(location = 0) out vec2 v_uv;
    void main() {
        const vec2 corners[6] = vec2[6](vec2(0, 0), vec2(1, 0), vec2(1, 1), vec2(0, 0), vec2(1, 1), vec2(0, 1));
        vec2 c = corners[gl_VertexIndex];
        vec2 px = to_rect.xy + c * to_rect.zw;
        v_uv = (from_rect.xy + c * from_rect.zw) / screen.xy;
        gl_Position = vec4(px.x / screen.x * 2.0 - 1.0, 1.0 - px.y / screen.y * 2.0, 0.0, 1.0);
    }
    """;
let SHOW_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    void main() { result = texture(src, v_uv) * screen.z; }
    """;
