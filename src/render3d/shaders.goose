// The 3D board's shaders, GLSL 450 that embed_shader compiles with the program. One
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
        vec4 params;         // x: exposure, y: a shadow texel in uv, z: ambient scale,
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
                             // line's strength; z: 1 for stone, its u leaning at the ends
        vec4 frame_surface;  // w: how much smoother the frame's rounded edge is
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

let LIT_FRAG = """
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in vec2 v_extra;
    layout(location = 4) in vec3 v_local;
    layout(location = 5) flat in vec4 v_kind;
    layout(location = 6) flat in float v_alpha;
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
        float mat = v_extra.y;
        vec3 p = v_world;
        vec3 n = normalize(v_normal);
        float ao = clamp(v_extra.x, 0.0, 1.0);
        vec3 albedo;
        float rough;
        float top_var = 0.0;     // the spread of a shader-made normal over the pixel
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
            vec2 gx = dFdx(solid_uv) / FRAME_SPAN;
            vec2 gy = dFdy(solid_uv) / FRAME_SPAN;
            if (frame_build.x < 0.5) {
                bool along_x = a2.y > a2.x;
                float band = along_x ? (p.z > 0.0 ? 0.0 : 1.0) : (p.x > 0.0 ? 2.0 : 3.0);
                // Both pieces' mappings and their derivatives, so the filter's footprint
                // follows the piece's own axes (the sides' grain runs along z) and a pixel
                // quad straddling a mitre doesn't see the jump between them.
                vec2 on_x = vec2(p.x, a2.y - INNER + down);
                vec2 on_z = vec2(p.z, a2.x - INNER + down);
                vec2 own = along_x ? on_x : on_z;
                fuv = vec2(own.x, own.y + band * 1.4 - 5.0);
                gx = (along_x ? dFdx(on_x) : dFdx(on_z)) / FRAME_SPAN;
                gy = (along_x ? dFdy(on_x) : dFdy(on_z)) / FRAME_SPAN;
                grain = along_x ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 0.0, 1.0);
            }
            fuv = fuv / FRAME_SPAN + 0.5;
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
        } else {
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

// The backdrop: the blurred photograph cover-cropped by the screen's long side, graded
// to sit as the 3D reference's background does: lighter, a little more saturated, its
// bright patches lifted into warm bokeh, and lifted toward the theme's tint low down,
// where the reference has a surface under the board, darkened toward the edges.
let BACKDROP_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D photo;
    layout(set = 3, binding = 1) uniform Draw { vec4 draw; };    // x: how opaque
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
        vec3 pos = draw.x > 1.5 ? vec3(c.x * FIELD, 0.004, c.y * FIELD)
                 : draw.x > 0.5 ? vec3(selected.x + c.x * selected.w * 2.0, 0.004,
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

    // The field: light and dark squares, each its own stretch of the surface and its own
    // tone, thin dark seams between them; round them a dark inlay, its grain along each
    // side, a fine dark line where it meets the squares.
    Wood plan(vec2 p) {
        vec2 a = abs(p);
        float m = max(a.x, a.y);
        if (m > FIELD) {
            bool along_x = a.y > a.x;
            vec2 q = along_x ? p.yx : p;
            // The growth rings give each of the four sides its own piece.
            float iseed = along_x ? 71.0 : 83.0;
            if (mode.y > 0.5 && inlay_fig.w > 0.5) iseed += (along_x ? p.y : p.x) > 0.0 ? 0.0 : 2.0;
            Wood w = wood(q, iseed, inlay, inlay_fig, vec3(surface.y, 0.0, 0.0), dark_ring);
            float line = 1.0 - smoothstep(0.004, 0.010, m - FIELD);
            w.albedo *= 1.0 - 0.6 * line;
            w.height -= line;
            return w;
        }
        // mode.z squares per side (8 or 10), each 8 / mode.z across.
        float n = mode.z;
        vec2 g = (p + FIELD) * (n / (2.0 * FIELD));
        ivec2 sq = clamp(ivec2(floor(g)), ivec2(0), ivec2(int(n) - 1));
        bool dark = ((sq.x + sq.y) & 1) == 1;
        float seed = float(sq.y * int(n) + sq.x) + 1.0;
        vec3 f = vec3(surface.y, 0.0, 0.0);
        Wood w = dark ? wood(p, seed, dark_sq, dark_fig, f, dark_ring)
                      : wood(p, seed, light_sq, light_fig, f, light_ring);
        w.albedo *= 1.0 + surface.x * (h12(vec2(seed, 4.2)) - 0.5);
        vec2 fr = fract(g);
        float edge = min(min(fr.x, 1.0 - fr.x), min(fr.y, 1.0 - fr.y)) * (2.0 * FIELD / n);
        float seam = 1.0 - smoothstep(0.002, 0.007, edge);
        w.albedo *= 1.0 - surface.z * seam;
        w.rough = mix(w.rough, 0.8, seam);
        w.height -= seam;
        return w;
    }

    // The frame map: the frame's wood or stone over a square, its grain along u.
    // The growth rings give each band of the map (each mitred piece, LIT_FRAG) its own
    // log and cut, across measured from the band's start.
    Wood frame_map(vec2 p) {
        vec3 f = frame_surface.xxz * vec3(0.3, 1.0, 1.0);
        vec2 q = p.yx;
        float seed = 7.0;
        if (mode.y > 0.5 && mode.y < 2.5 && frame_fig.w > 0.5) {
            float band = floor(q.x / 1.4);
            q.x -= band * 1.4;
            seed = 7.0 + 5.0 * band;
        }
        Wood w = wood(q, seed, frame, frame_fig, f, frame_ring);
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
        return w;
    }

    Wood at(vec2 p) { return mode.x < 0.5 ? plan(p) : frame_map(p); }

    void main() {
        vec2 texel = size.zw / size.xy;
        vec2 p = gl_FragCoord.xy * texel - (mode.x < 0.5 ? 0.5 * size.zw : vec2(0.0));
        if (mode.x > 0.5 && mode.w > 0.5 && frame_fig.w < 0.5) {
            // A marble frame, flat: once a texel, no relief to take the normal from.
            Wood m = marble_at(p.yx);
            out_albedo = vec4(m.albedo, m.rough);
            out_normal = vec4(0.5, 0.5, 1.0, 1.0);
            return;
        }
        Wood w = at(p);
        Wood wx = at(p + vec2(texel.x, 0.0));
        Wood wy = at(p + vec2(0.0, texel.y));
        vec2 grad = vec2(wx.height - w.height, wy.height - w.height) / texel;
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
// dot (1) or a capture's stop's ring (2), z the must-capture ring's strength (0 to 1,
// pulsing on the CPU), w a wrong move's flash, 0 to 1 over its two flashes (or -1); and
// the selected piece's glow ring round Frame.selected, wherever the piece is (a drag).
// Beside them `lit`, per square: x the glow ring tight round the piece there (a hint, a
// win's wave), y the square lit by a win's glow. A win's dim (screen.z) dims them all but
// the glow rings. draw.y: squares per side. As the flat board draws them
// (src/app/draw.goose).
let MARKS_FRAG = """
    layout(location = 0) in vec3 v_pos;
    layout(location = 0) out vec4 result;
    layout(std430, set = 2, binding = 0) readonly buffer Marks { vec4 marks[]; };
    layout(std430, set = 2, binding = 1) readonly buffer Lit { vec4 lit[]; };
    layout(set = 3, binding = 1) uniform Draw { vec4 draw; };
    float line(float d, float w) { return exp(-pow(d / (0.6 * w + 0.008), 2.0)); }
    void main() {
        vec3 c = vec3(0.0);
        // The selected piece's ring, a little out from it, and a soft halo.
        if (selected.w > 0.0) {
            float r = length(v_pos.xz - selected.xz);
            float ring = 1.08 * selected.w;
            float w = max(fwidth(r), 0.01);
            float halo = exp(-max(r - ring, 0.0) / 0.07) * smoothstep(ring - 0.04, ring, r);
            c += glow.rgb * glow.w * (0.85 * line(r - ring, w) + 0.3 * halo);
        }
        float n = draw.y;
        float u = 2.0 * FIELD / n;
        vec2 g = (v_pos.xz + FIELD) / u;
        ivec2 q = ivec2(floor(g));
        // A pixel in squares, from g, which runs on across the squares' edges.
        float wg = max(length(fwidth(g)) * 0.7, 0.002);
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
        c *= 1.0 - screen.z;
        vec3 rings = vec3(0.0);
        // The red rings go a little out from a piece (0.44 of a square), past its square's
        // edge, so each pixel looks at the squares round it too.
        vec3 red = vec3(1.0, 0.353, 0.29);
        for (int dy = -1; dy <= 1; dy++) {
            for (int dx = -1; dx <= 1; dx++) {
                ivec2 k = q + ivec2(dx, dy);
                if (k.x < 0 || k.y < 0 || k.x >= int(n) || k.y >= int(n)) continue;
                vec4 m = marks[k.y * int(n) + k.x];
                float r = length(g - (vec2(k) + 0.5));
                float w = wg;
                // The glow ring tight round a piece (0.44 of a square), with a soft halo.
                float k_ring = lit[k.y * int(n) + k.x].x;
                if (k_ring > 0.0) {
                    float rr = 0.47;
                    float halo = exp(-max(r - rr, 0.0) / 0.06) * smoothstep(rr - 0.04, rr, r);
                    rings += glow.rgb * glow.w * k_ring * (1.1 * line(r - rr, w) + 0.45 * halo);
                }
                if (m.z > 0.0) {
                    float rr = 0.52;
                    c += red * m.z * (0.9 * line(r - rr, w) + 0.35 * exp(-abs(r - rr) / 0.04));
                }
                if (m.w >= 0.0 && m.w < 1.0) {
                    float t = fract(m.w * 2.0);
                    float op = t < 0.4 ? t / 0.4 : 1.0 - 0.4 * (t - 0.4) / 0.6;
                    float rr = 0.5 * (0.8 + 0.2 * min(t / 0.4, 1.0));
                    c += red * op * (0.9 * line(r - rr, w) + 0.25 * (1.0 - smoothstep(rr - w, rr + w, r)));
                }
            }
        }
        result = vec4(c + rings, 1.0);
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
