// The prototype's shaders, GLSL 450 that embed_shader compiles with the program. One
// forward pass draws everything lit: the board and the pieces share one fragment shader
// (GGX after Filament, wrap diffuse, Filament's specular antialiasing, a 4 × 4 grid of
// hardware-compared shadow taps, analytic occlusion, an ambient of nine spherical
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
        vec4 params;         // x: exposure, y: a shadow texel in uv, z: ambient scale
        vec4 screen;         // xy: the target's size in pixels
        vec4 glow;           // rgb: the theme's glow color, w: its strength
        vec4 selected;       // xyz: the selected piece's foot, w: its radius (0: none)
        // The theme (theme::Theme), colors linear: the pieces' colors and roughness, their
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
                             // line's strength; z: 1 for stone, its u leaning at the ends
    };
    const float PI = 3.14159265;
    const float FIELD = 4.0;
    const float INNER = 4.1;
    const float FRAME_W = 0.5;
    const float FRAME_TOP = 0.05;
    const float BOTTOM = -0.7;
    const float RADIUS = 0.44;
    const float HEIGHT = 0.24;
    const float EDGE_AT = 0.86;
    // Along the frame's profile (mesh.goose's uv.y): where the bullnose starts and ends.
    const float BULL_START = 0.4546;
    const float BULL_END = 0.5960;
    vec3 srgb(vec3 c) { return pow(c, vec3(2.2)); }
    """;

let VS_SET = "#define FRAME_SET 1\n";
let FS_SET = "#define FRAME_SET 3\n";

// The board (one mesh) and the pieces (one lathe mesh, per instance from a storage
// buffer of two vec4s: the foot and scale; dark, crown, selected or stacked, seed).
let LIT_VERT = """
    layout(location = 0) in vec3 a_pos;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    layout(location = 3) in vec2 a_extra;          // occlusion, material
    layout(std430, set = 0, binding = 0) readonly buffer Instances { vec4 inst[]; };
    layout(set = 1, binding = 1) uniform Draw { vec4 draw; };   // x: 1 for instances
    layout(location = 0) out vec3 v_world;
    layout(location = 1) out vec3 v_normal;
    layout(location = 2) out vec2 v_uv;
    layout(location = 3) out vec2 v_extra;
    layout(location = 4) out vec3 v_local;
    layout(location = 5) flat out vec4 v_kind;
    void main() {
        vec3 world = a_pos;
        vec4 kind = vec4(0.0);
        if (draw.x > 0.5) {
            vec4 a = inst[gl_InstanceIndex * 2];
            kind = inst[gl_InstanceIndex * 2 + 1];
            world = a.xyz + a_pos * a.w;
        }
        v_world = world;
        v_normal = a_normal;
        v_uv = a_uv;
        v_extra = a_extra;
        v_local = a_pos;
        v_kind = kind;
        gl_Position = (draw.y > 0.5 ? light_view_proj : view_proj) * vec4(world, 1.0);
    }
    """;

// A depth-only pass still needs a fragment shader.
let EMPTY_FRAG = """
    void main() { }
    """;

let LIT_FRAG = """
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in vec2 v_extra;
    layout(location = 4) in vec3 v_local;
    layout(location = 5) flat in vec4 v_kind;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D plan_albedo;
    layout(set = 2, binding = 1) uniform sampler2D plan_normal;
    layout(set = 2, binding = 2) uniform sampler2D frame_albedo;
    layout(set = 2, binding = 3) uniform sampler2D frame_normal;
    layout(set = 2, binding = 4) uniform sampler2DShadow shadow_map;
    // Per square: the top of what stands there, its foot, its radius, 1 if a piece.
    layout(std430, set = 2, binding = 5) readonly buffer Squares { vec4 squares[]; };

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

    // The key light's shadow: 16 hardware-compared bilinear taps on a fixed grid, from a
    // point pushed off the surface along its normal.
    float shadow(vec3 p, vec3 n) {
        float nl = clamp(dot(n, light_dir.xyz), 0.0, 1.0);
        vec3 q = p + n * (0.004 + 0.012 * (1.0 - nl));
        vec4 s = light_view_proj * vec4(q, 1.0);
        vec2 uv = vec2(s.x * 0.5 + 0.5, 0.5 - s.y * 0.5);
        float z = s.z - 0.0005;
        float t = params.y * 2.5;
        float sum = 0.0;
        for (int y = 0; y < 4; y++) {
            for (int x = 0; x < 4; x++) {
                sum += texture(shadow_map, vec3(uv + (vec2(x, y) - 1.5) * t, z));
            }
        }
        return sum * (1.0 / 16.0);
    }

    // The field's occlusion, analytic: each piece in the 3 × 3 squares round as a
    // cylinder (the share of the cosine-weighted sky its angle across and its height
    // take), and the frame's short inner wall as a long wall.
    float field_occlusion(vec3 p) {
        float vis = 1.0;
        ivec2 c = ivec2(floor(p.xz + FIELD));
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                ivec2 q = c + ivec2(dx, dy);
                if (q.x < 0 || q.y < 0 || q.x > 7 || q.y > 7) continue;
                vec4 s = squares[q.y * 8 + q.x];
                if (s.w < 0.5) continue;
                float rho = length(p.xz - (vec2(q) - 3.5));
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

    // The crown on a king's face, in units of half the piece's radius: a body with three
    // points, a ball on each, and a bar under it.
    const vec2 CROWN[7] = vec2[7](vec2(-0.55, -0.12), vec2(-0.66, 0.34), vec2(-0.27, 0.10),
                                  vec2(0.0, 0.46), vec2(0.27, 0.10), vec2(0.66, 0.34),
                                  vec2(0.55, -0.12));
    float crown(vec2 p) {
        float d = dot(p - CROWN[0], p - CROWN[0]);
        float s = 1.0;
        for (int i = 0, j = 6; i < 7; j = i, i++) {
            vec2 e = CROWN[j] - CROWN[i];
            vec2 w = p - CROWN[i];
            vec2 b = w - e * clamp(dot(w, e) / dot(e, e), 0.0, 1.0);
            d = min(d, dot(b, b));
            bvec3 c = bvec3(p.y >= CROWN[i].y, p.y < CROWN[j].y, e.x * w.y > e.y * w.x);
            if (all(c) || all(not(c))) s = -s;
        }
        d = s * sqrt(d);
        d = min(d, length(p - vec2(-0.68, 0.40)) - 0.1);
        d = min(d, length(p - vec2(0.0, 0.53)) - 0.1);
        d = min(d, length(p - vec2(0.68, 0.40)) - 0.1);
        vec2 q = abs(p - vec2(0.0, -0.27)) - vec2(0.55, 0.055);
        d = min(d, length(max(q, 0.0)) + min(max(q.x, q.y), 0.0));
        return d;
    }

    // The piece's top as mesh::top_height and mesh::top_ao have it: keep them in step.
    float top_height(float u) {
        float c = (u - 0.705) / 0.028;
        return -0.022 * (1.0 - smoothstep(0.6, 0.67, u)) + 0.006 * exp(-c * c);
    }
    float top_ao(float u) {
        float c = (u - 0.63) / 0.04;
        return 1.0 - 0.06 * (1.0 - u) - 0.35 * exp(-c * c);
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
        float mat = v_extra.y;
        vec3 p = v_world;
        vec3 n = normalize(v_normal);
        float ao = clamp(v_extra.x, 0.0, 1.0);
        vec3 albedo;
        float rough;
        if (mat < 0.5) {
            // The field: the baked plan, seen from above.
            vec2 uv = (p.xz + INNER) / (2.0 * INNER);
            vec4 a = texture(plan_albedo, uv);
            vec2 t = texture(plan_normal, uv).xy * 2.0 - 1.0;
            albedo = a.rgb;
            rough = a.a;
            n = normalize(vec3(t.x, sqrt(max(1.0 - dot(t, t), 0.0)), t.y));
            ao *= field_occlusion(p);
        } else if (mat < 1.5) {
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
            if (frame_build.x < 0.5) {
                bool along_x = a2.y > a2.x;
                float band = along_x ? (p.z > 0.0 ? 0.0 : 1.0) : (p.x > 0.0 ? 2.0 : 3.0);
                float out_by = (along_x ? a2.y : a2.x) - INNER + down;
                fuv = vec2(along_x ? p.x : p.z, out_by + band * 1.4 - 5.0);
                grain = along_x ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0);
            }
            fuv = fuv / FRAME_SPAN + 0.5;
            // The mip from the solid mapping, which has the same scale and no break at
            // the mitres.
            vec2 gx = dFdx(solid_uv) / FRAME_SPAN;
            vec2 gy = dFdy(solid_uv) / FRAME_SPAN;
            vec4 a = textureGrad(frame_albedo, fuv, gx, gy);
            vec2 t = textureGrad(frame_normal, fuv, gx, gy).xy * 2.0 - 1.0;
            albedo = a.rgb;
            rough = a.a;
            vec3 tan = grain - n * dot(n, grain);
            tan = dot(tan, tan) > 0.01 ? normalize(tan) : normalize(cross(n, vec3(0.0, 0.0, 1.0)));
            vec3 bit = cross(n, tan);
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
            float lw = max(fwidth(along), 0.004);
            float line = 1.0 - smoothstep(0.5 * lw, 1.5 * lw, abs(along - BULL_START - 0.006));
            albedo = mix(albedo, edge_line.rgb, line * edge_line.a);
            rough = mix(rough, 0.4, line * edge_line.a);
            // Darker toward the underside, where the board's own shade gathers.
            ao *= mix(0.4, 1.0, smoothstep(BOTTOM, FRAME_TOP - 0.1, p.y));
        } else {
            vec3 lp = v_local;
            bool dark = v_kind.x > 0.5;
            vec4 m = dark ? dark_piece : light_piece;
            rough = m.a;
            if (dark) {
                // Smooth satin with a faint figure, drawn out a little across the disc.
                vec3 g = lp + v_kind.w * 3.17;
                float st = 1.0 + 6.0 * piece_fig.z;
                float w = noise3(vec3(g.x * 5.0, g.y * 5.0, g.z * 5.0 * st)) * 0.65
                        + noise3(vec3(g.x * 13.0, g.y * 13.0, g.z * 13.0 * st)) * 0.35;
                albedo = m.rgb * (1.0 + piece_fig.y * (w - 0.5));
                // The turned side, across the grain, takes the finish darker than the face:
                // the references' dark pieces have near-black sides under a lit top.
                albedo *= mix(piece_fig.w, 1.0, smoothstep(0.2, 0.6, abs(n.y)));
            } else {
                float w = noise3(lp * 24.0 + v_kind.w * 3.17);
                albedo = m.rgb * (1.0 + piece_fig.x * (w - 0.5));
            }
            // The top, from its height function at this point's distance from the axis
            // (mesh::top_height): the normal and the cove's occlusion come from the
            // object-space position, never from interpolants a multisampled pixel can
            // extrapolate past a small triangle.
            float rho = length(lp.xz);
            float u = rho / RADIUS;
            if (u < EDGE_AT && lp.y > 0.5 * HEIGHT) {
                float e = 0.002;
                float slope = (top_height(u + e) - top_height(u - e)) / (2.0 * e * RADIUS);
                vec2 radial = rho > 1e-5 ? lp.xz / rho : vec2(0.0);
                n = normalize(vec3(-slope * radial.x, 1.0, -slope * radial.y));
                ao = top_ao(u);
            }
            if (v_kind.y > 0.5 && u < 0.66 && lp.y > 0.5 * HEIGHT) {
                // The crown debossed in a king's face, filled with the crown's color, its
                // walls sloping in, crisp by its distance's screen derivative.
                float k = 0.72 * RADIUS;
                vec2 c = vec2(lp.x, -lp.z) / k;
                float d = crown(c) * k;
                float e = 0.002;
                vec2 grad = vec2(crown(c + vec2(e / k, 0.0)) * k - d,
                                 crown(c + vec2(0.0, e / k)) * k - d) / e;
                float w = fwidth(d);
                float inside = 1.0 - smoothstep(-w, w, d);
                float wall = inside * smoothstep(-0.012 - w, -0.012 + w, d);
                n = normalize(n - vec3(grad.x, 0.0, -grad.y) * wall * 1.6);
                albedo = mix(albedo, crown_color.rgb, inside);
                rough = mix(rough, 0.7, inside);
                ao *= 1.0 - 0.35 * inside;
            }
            // Contact: the foot darkens near what it stands on; a stack's lower disc
            // darkens under the upper.
            float h = v_kind.y > 0.5 ? lp.y : p.y;
            ao *= mix(0.6, 1.0, smoothstep(0.0, 0.035, h));
            if (v_kind.z > 1.5) ao *= mix(1.0, 0.65, smoothstep(HEIGHT - 0.05, HEIGHT, lp.y));
        }

        vec3 v = normalize(eye.xyz - p);
        vec3 l = light_dir.xyz;
        float nov = max(dot(n, v), 1e-4);
        float nol = dot(n, l);
        float nl = clamp(nol, 0.0, 1.0);
        vec3 hv = normalize(v + l);
        float noh = clamp(dot(n, hv), 0.0, 1.0);
        float voh = clamp(dot(v, hv), 0.0, 1.0);
        // Filament's specular antialiasing: roughness widened by the normal's variance.
        vec3 du = dFdx(n);
        vec3 dv = dFdy(n);
        float variance = 0.15 * (dot(du, du) + dot(dv, dv));
        float a = rough * rough;
        a = sqrt(clamp(a * a + min(2.0 * variance, 0.2), 0.0, 1.0));
        a = max(a, 0.0079);
        vec3 f0 = vec3(0.04);
        vec3 spec = d_ggx(noh, a) * v_smith(nov, nl, a) * f_schlick(f0, voh) * nl;
        float wrap = 0.2;
        float diff = clamp((nol + wrap) / (1.0 + wrap), 0.0, 1.0) / (1.0 + wrap);
        // Filament's micro-shadowing from the occlusion, on the field only: on the
        // pieces' grooves, tiny triangles near the terminator turned it into specks.
        float micro = clamp(nl * inversesqrt(1.0 - min(ao, 0.9999)), 0.0, 1.0);
        micro = nol > 0.0 && mat < 0.5 ? micro * micro : 1.0;
        // A piece's lip and groove are finer than a shadow texel: its lookups start a
        // little toward the light, so they leave them to the baked occlusion.
        float vis = shadow(mat > 1.5 ? p + l * 0.03 : p, n) * micro;
        vec3 light = light_color.rgb * light_dir.w;
        vec3 direct = (albedo * (diff / PI) + spec) * light * vis;
        // The photograph's light: diffuse from the harmonics, specular from them along
        // the reflection, through the DFG fit, under the occlusion.
        vec3 irr = sh_eval(n) * params.z;
        vec3 env = sh_eval(reflect(-v, n)) * params.z;
        float spec_ao = clamp(pow(nov + ao, exp2(-16.0 * a - 1.0)) - 1.0 + ao, 0.0, 1.0);
        vec3 ambient = albedo * irr * ao + env * env_brdf(f0, rough, nov) * spec_ao;
        if (mat > 1.5) {
            // The lit board's light on a piece's side: what faces down and out sees the
            // board round it, lit by the key from above.
            float down = clamp(0.5 - 0.5 * n.y, 0.0, 1.0);
            ambient += albedo * bounce.rgb * (light * l.y / PI) * bounce.a * down * ao;
        }
        vec3 color = (direct + ambient) * params.x;
        color = tonemap(color) * vec3(1.02, 1.0, 0.97);
        result = vec4(to_srgb(color), 1.0);
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

// The backdrop: the blurred photograph cover-cropped by the screen's long side, graded
// to sit as the 3D reference's background does: lighter, a little more saturated, its
// bright patches lifted into warm bokeh, and lifted toward the theme's tint low down,
// where the reference has a surface under the board, darkened toward the edges.
let BACKDROP_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D photo;
    void main() {
        vec2 s = screen.xy;
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
        result = vec4(pow(c, vec3(1.0 / 2.2)), 1.0);
    }
    """;

// A quad on a plane: the shadow catcher under the board (draw.x 0) or the selected
// piece's glow on the field (draw.x 1).
let QUAD_VERT = """
    layout(set = 1, binding = 1) uniform Draw { vec4 draw; };
    layout(location = 0) out vec3 v_pos;
    void main() {
        const vec2 corners[6] = vec2[6](vec2(-1, -1), vec2(1, -1), vec2(1, 1),
                                        vec2(-1, -1), vec2(1, 1), vec2(-1, 1));
        vec2 c = corners[gl_VertexIndex];
        vec3 pos = draw.x > 0.5 ? vec3(selected.x + c.x * selected.w * 2.0, 0.004,
                                       selected.z + c.y * selected.w * 2.0)
                                : vec3(c.x * 16.0, BOTTOM, c.y * 16.0);
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

// The selected piece's glow ring on the field, added: a ring a little out from the piece
// (1.13 of its radius) and a soft halo outside it.
let GLOW_FRAG = """
    layout(location = 0) in vec3 v_pos;
    layout(location = 0) out vec4 result;
    void main() {
        float r = length(v_pos.xz - selected.xz);
        float ring = 1.08 * selected.w;
        float w = max(fwidth(r), 0.01);
        float line = exp(-pow((r - ring) / (0.6 * w + 0.012), 2.0));
        float halo = exp(-max(r - ring, 0.0) / 0.07) * smoothstep(ring - 0.04, ring, r);
        result = vec4(glow.rgb * glow.w * (0.85 * line + 0.3 * halo), 1.0);
    }
    """;

// The board's surfaces, baked once per theme into two targets: albedo and roughness
// (sRGB), and the normal's x and z. mode.x 0 bakes the plan of the field and its inlay,
// seen from above; 1 the frame map, its grain along u. size: the target in texels,
// then in world units. The rest is the theme's (theme::Theme): each surface's color and
// roughness and its figure.
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

    struct Wood { vec3 albedo; float rough; float height; };

    // A surface with its grain along y, from noise drawn out along the grain, never a
    // regular stripe: a broad soft figure, fine streaks, pores. k: how far the grain
    // wanders, the broad figure's contrast, the fine streaks' contrast, and how far the
    // noise is drawn out along y (1 wood; 0 stone: the same noise round, a mottling with
    // no veins). base: the color (sRGB) and roughness.
    Wood wood(vec2 q, float seed, vec4 base, vec4 k) {
        float s = k.w;
        q += vec2(h12(vec2(seed, 1.7)), h12(vec2(seed, 9.3))) * 97.0;
        float wander = (fbm(q * vec2(0.45, mix(0.45, 0.16, s))) - 0.5) * k.x;
        float x = q.x + wander;
        float broad = fbm(vec2(x * mix(1.3, 2.4, s), q.y * mix(1.3, 0.22, s)));
        float fine = fbm(vec2(x * 26.0, q.y * mix(26.0, 0.7, s)));
        float pores = smoothstep(0.6, 0.9, vnoise(vec2(x * 70.0, q.y * mix(70.0, 1.6, s))))
                    * surface.y;
        Wood w;
        w.albedo = srgb(base.rgb) * (1.0 + k.y * (broad - 0.5)) * (1.0 + k.z * (fine - 0.5))
                 * (1.0 - 0.12 * pores);
        w.rough = base.a + 0.14 * pores - 0.06 * (fine - 0.5);
        w.height = (fine - 0.5) * 0.4 - pores * 0.5;
        return w;
    }

    // The field: light and dark squares, each its own stretch of the surface and its own
    // tone, thin dark seams between them; round them a dark inlay, its grain along each
    // side, a fine dark line where it meets the squares.
    Wood plan(vec2 p) {
        vec2 a = abs(p);
        float m = max(a.x, a.y);
        if (m > FIELD) {
            bool along_x = a.y > a.x;
            vec2 q = along_x ? p.yx : p;
            Wood w = wood(q, along_x ? 71.0 : 83.0, inlay, inlay_fig);
            float line = 1.0 - smoothstep(0.004, 0.010, m - FIELD);
            w.albedo *= 1.0 - 0.6 * line;
            w.height -= line;
            return w;
        }
        vec2 g = p + FIELD;
        ivec2 sq = clamp(ivec2(floor(g)), ivec2(0), ivec2(7));
        bool dark = ((sq.x + sq.y) & 1) == 1;
        float seed = float(sq.y * 8 + sq.x) + 1.0;
        Wood w = dark ? wood(p, seed, dark_sq, dark_fig) : wood(p, seed, light_sq, light_fig);
        w.albedo *= 1.0 + surface.x * (h12(vec2(seed, 4.2)) - 0.5);
        vec2 f = fract(g);
        float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
        float seam = 1.0 - smoothstep(0.002, 0.007, edge);
        w.albedo *= 1.0 - surface.z * seam;
        w.rough = mix(w.rough, 0.8, seam);
        w.height -= seam;
        return w;
    }

    // The frame map: the frame's wood or stone over a square, its grain along u.
    Wood frame_map(vec2 p) { return wood(p.yx, 7.0, frame, frame_fig); }

    Wood at(vec2 p) { return mode.x < 0.5 ? plan(p) : frame_map(p); }

    void main() {
        vec2 texel = size.zw / size.xy;
        vec2 p = gl_FragCoord.xy * texel - (mode.x < 0.5 ? 0.5 * size.zw : vec2(0.0));
        Wood w = at(p);
        Wood wx = at(p + vec2(texel.x, 0.0));
        Wood wy = at(p + vec2(0.0, texel.y));
        vec2 grad = vec2(wx.height - w.height, wy.height - w.height) / texel;
        vec3 n = normalize(vec3(-grad.x * 0.0015 * surface.w, 1.0, -grad.y * 0.0015 * surface.w));
        out_albedo = vec4(w.albedo, w.rough);
        out_normal = vec4(n.x * 0.5 + 0.5, n.z * 0.5 + 0.5, 0.5, 1.0);
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
