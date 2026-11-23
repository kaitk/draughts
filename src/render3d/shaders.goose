// The 3D board's shaders, GLSL 450 that embed_shader compiles with the program. One
// forward pass draws everything lit: the board and the pieces share one fragment shader
// (GGX after Filament, wrap diffuse, Filament's specular antialiasing, 9 weighted
// hardware-compared shadow taps over 5 × 5 texels on a tablet, 16 over 7 × 7 on iOS and a
// desktop, 4 over 3 × 3 on a phone, analytic occlusion, an ambient of nine spherical
// harmonics taken from the photograph, a mild tonemap). The wood is baked once at
// startup by the bake shader into textures with mips.
//
// The board's measures are repeated here from mesh.goose, as embed_shader takes only a
// literal: test/model3d/geometry checks each against the mesh's.
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
        vec4 params;         // x: exposure, y: the board scattering's color depth
                             // (body_color), z: ambient scale,
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
        vec4 frame_map;      // x: map height / width, y: piece mineral
        vec4 frame_wax;      // the frame's wax coat (looks::Theme.frame_wax)
        // The pieces' scattering, light and dark (looks::Theme): rgb its tint, linear, w
        // its strength; their wear: x the roughness's unevenness, y the worn edges'
        // dullness, z each piece's own tone.
        vec4 light_scatter;
        vec4 dark_scatter;
        vec4 piece_wear;
        // The room's light (render3d::put_room, rooms::Room): x how dark the key's
        // shadow is, y how much of the key the window's shade keeps out (0 no pattern),
        // z the penumbra's widening with distance; the window, its panes, its opening
        // and curtain, the trees' leaves outside.
        vec4 room;
        vec4 window;
        vec4 panes;
        vec4 opening;
        vec4 leaves;
        // The single leaves: x their scale against the clumps, y how few gaps (a
        // threshold), z how soft each fleck's edge, w how much their shadows show in the open.
        vec4 twigs;
        vec4 wind;           // x how strong, y how fast, z the seconds, w the leaves' ruffle in a gust
        // The tree outside, its shadow baked into tree_map (render3d::put_tree): x the
        // map's width and height in world units (0 no tree: the leaves' noise), zw its middle; x the
        // blur's texels a unit of distance, y the board middle's distance from the
        // trunk's plane.
        vec4 tree;
        vec4 tree_blur;
        // The wind this frame (rooms::wind_at): x the whole tree's slow sway, y the gust
        // at 0 along the wall, z its change a unit along, w 1 for the sines' gust
        // (rooms::wind_sines), 2 for the branches; each layer's shift in the map (the
        // limbs, the near, middle and far leaves), xy in calm air, zw a full gust's; the
        // branches' field (rooms::branch_field); where the gust reaches
        // (rooms::gust_regions).
        vec4 wind_now;
        vec4 tree_shift[4];
        vec4 branches;
        vec4 gust_reach;
        // The pieces lying on the table (render3d::table_discs): disc_n x how many, y
        // their radius; each disc x, z, its foot's and its top's height over the table.
        vec4 disc_n;
        vec4 discs[48];
        // The room's frame (surfaces::Frame, render3d::put_room): u's direction in the
        // world's x and z, then v's; ROOM_VERT turns the room's mesh by it.
        vec4 room_axes;
        // The tonemaps' toes as the light tuner switches them (TOE_FN; render3d::tone_toe):
        // x the room's and the view out's way, y the table's, z the board's and the pieces'
        // (0 on the luminance, 1 on the least channel, Khronos PBR Neutral's, 2 none); w what
        // a toe takes off above its knee.
        vec4 toe;
    };
    const float PI = 3.14159265;
    // The board's sizes, mesh.goose's (test/model3d/geometry checks them).
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

// LIT_FRAG's and TABLE_FRAG's shadow in 4 taps or in 16, not 9 (SHADOW_FN): a phone's
// and a desktop's (render3d::set_shadow).
let SHADOW_FEW = "#define SHADOW_FEW 1\n";
let SHADOW_MANY = "#define SHADOW_MANY 1\n";
// TABLE_FRAG in the room with its light baked: the room's probes round the table in place
// of the look's harmonics (render3d::table_in_room); the game's table never carries it.
let TABLE_ROOM = "#define TABLE_ROOM 1\n";

// The light tuner's shaders (render3d::tuned_frags), after FRAME: each tonemap's toe
// switched by Frame's toe (its --toe, --table-toe, --board-toe, --toe-off). The app's never
// take it: a uniform switch cost the room 0.7 ms a frame on the Mac, and any change to the
// lit shader's text moves a few pixels of the game's picture there.
let TOE_FN = """
    #define TOE_SWITCH 1
    // The toe of the way `way` taking toe.w off (Frame's toe).
    vec3 toe_off(vec3 c, float way) {
        float f = toe.w;
        if (way < 0.5) {
            float y = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-6);
            return c * ((y < 2.0 * f ? y * y / (4.0 * f) : y - f) / y);
        }
        if (way < 1.5) {
            float x = min(c.r, min(c.g, c.b));
            return c - (x < 2.0 * f ? x - x * x / (4.0 * f) : f);
        }
        return c;
    }
    """;

// LIT_FRAG's pieces in one material (render3d::PIECES_..), none of them classic: a
// phone compiles every branch a shader has, so each material is a shader of its own.
let PIECES_WOOD = "#define PIECES_WOOD 1\n";
let PIECES_WINTER = "#define PIECES_WINTER 1\n";
let PIECES_MINERAL = "#define PIECES_MINERAL 1\n";

// The board (one mesh) and the pieces (one lathe mesh, per instance from a storage
// buffer of two vec4s: the foot and scale; dark, crown, selected or stacked, seed).
// draw.z: how opaque (a fading piece is drawn alone, blended); draw.w: the first
// instance it draws. A seed of 1000 or more is a piece a win's dim leaves lit; one below
// 0 a piece the lookout drains (view3d::build_scene), its figure from the seed's size.
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
    layout(location = 6) flat out float v_alpha;
    layout(location = 7) out vec2 v_wear;
    layout(location = 8) out vec3 v_scatter;
    void main() {
        vec3 world = a_pos;
        vec4 kind = vec4(0.0);
        bool beside = false;      // lying on the table beside the board
        v_wear = vec2(1.0);
        v_scatter = vec3(0.0);
        if (draw.x > 0.5) {
            int i = gl_InstanceIndex + int(draw.w);
            vec4 a = inst[i * 2];
            beside = max(abs(a.x), abs(a.z)) > INNER + FRAME_W;
            kind = inst[i * 2 + 1];
            world = a.xyz + a_pos * a.w;
            float seed = mod(abs(kind.w), 1000.0);
            float patchiness = 0.25 * (sin(a_pos.x * 9.0 + a_pos.y * 5.0 + seed * 2.3)
                                     + sin(a_pos.z * 11.0 - a_pos.y * 4.0 + seed * 1.7));
            // Distance down the rounded shoulder in units of its profile radius.
            float shoulder = clamp(1.0 - (HEIGHT - a_pos.y) / (RADIUS * (1.0 - EDGE_AT)), 0.0, 1.0);
            float side = 1.0 - max(a_normal.y, 0.0);
            v_wear.x = 1.0 + piece_wear.x * patchiness + 0.15 * piece_wear.y * shoulder * side;
            v_wear.y = 1.0 + piece_wear.z * (2.0 * fract(sin(seed * 12.9898 + 4.1) * 43758.5453) - 1.0);
            // Trace from just under the surface toward the key to the first
            // entry through the cylinder wall or cap. A short path from an
            // adjacent surface supplies more light than one across the body.
            vec4 scatter = kind.x > 0.5 ? dark_scatter : light_scatter;
            vec3 l = light_dir.xyz;
            vec3 q = a_pos - 0.035 * a_normal;
            float lateral = max(dot(l.xz, l.xz), 0.0001);
            float along = dot(q.xz, l.xz);
            float wall = (sqrt(max(0.0, along * along + lateral *
                          (RADIUS * RADIUS - dot(q.xz, q.xz)))) - along) / lateral;
            float cap = (HEIGHT - q.y) / max(l.y, 0.001);
            vec2 entry = (q.xz + wall * l.xz) / RADIUS;
            float incidence = wall < cap ? dot(entry, l.xz) : l.y;
            float path = max(0.0, min(wall, cap));
            float contact = smoothstep(0.0, 0.035, a_pos.y);
            if (kind.z == 2.0) contact *= smoothstep(0.0, 0.035, HEIGHT - a_pos.y);
            v_scatter = scatter.rgb * (scatter.w * max(incidence, 0.0) *
                        exp2(-path * 12.0) * contact);
        }
        v_world = world;
        v_normal = a_normal;
        v_uv = a_uv;
        v_extra = a_extra;
        v_local = a_pos;
        v_kind = kind;
        v_alpha = draw.z;
        gl_Position = (draw.y > 0.5 ? light_view_proj : view_proj) * vec4(world, 1.0);
        // The pieces lying on the table stay out of the shadow map, whose edge would cut
        // their shadows: LIT_FRAG traces them (discs_shadow).
        if (draw.y > 0.5 && beside) gl_Position = vec4(0.0, 0.0, -2.0, 1.0);
    }
    """;

// A depth-only pass still needs a fragment shader.
let EMPTY_FRAG = """
    void main() { }
    """;

// The crown on a king's face as a signed distance, drawn once into its map (CROWN_FRAG,
// render3d::crown_map) rather than in every king's pixel, three times for its slope.
let CROWN_FN = """
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
    """;

// The crown's distance into its map: CROWN_SIZE texels over ±CROWN_SPAN of the radius.
let CROWN_FRAG = """
    layout(location = 0) out vec4 result;
    const float CROWN_SPAN = 0.6;       // render3d::crown_map
    const float CROWN_SIZE = 256.0;
    void main() { result = vec4(crown((gl_FragCoord.xy / CROWN_SIZE - 0.5) * (2.0 * CROWN_SPAN)), 0.0, 0.0, 1.0); }
    """;

// The light's functions LIT_FRAG and TABLE_FRAG share: GGX, its visibility and Fresnel,
// the split sum's fit, the room's harmonics, and the sRGB curve.
let LIGHT_FN = """
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

    float window_hash(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }
    float window_noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(window_hash(i), window_hash(i + vec2(1.0, 0.0)), u.x),
                   mix(window_hash(i + vec2(0.0, 1.0)), window_hash(i + vec2(1.0, 1.0)), u.x), u.y);
    }

    // The wind at m, a point of the tree's plane (rooms::wind_at, after Zioma's noise of
    // time a layer): x the whole tree's slow sway, -1..1; y the gust, its front crossing
    // the crown along the wall, only in some regions of branches (rooms::gust_regions: a
    // slow noise a branch's reach across, drifting along the wind). With the sines
    // (wind_now.w 1, the tuner's), the gust is their product's peaks, all over the crown.
    vec2 wind_at(vec2 m) {
        if (abs(wind_now.w - 1.0) < 0.5) {
            float front = wind.z * wind.y - m.x * 0.015;
            float sines = (0.5 + 0.5 * sin(front * 0.21)) * (0.6 + 0.4 * sin(front * 0.53 + 2.0));
            return vec2(wind_now.x, smoothstep(0.55, 1.0, sines));
        }
        float g = clamp(wind_now.y + wind_now.z * m.x, 0.0, 1.0);
        if (gust_reach.w > 0.0 && g > 0.0) {
            float n = window_noise(m * (1.0 / 6.0) - vec2(1.0, 0.15) * gust_reach.x);
            g *= smoothstep(gust_reach.z, gust_reach.z + gust_reach.w, n);
        }
        return vec2(wind_now.x, g);
    }

    // Leaves turning in a gust: how far each small patch has turned, 0..1, on a phase of
    // its own, fast. A weight to blend a leaf layer with itself nudged as a whole, so
    // patches flip between two places and nothing is warped.
    float ruffle_at(vec2 m, float gust, float size) {
        float t = wind.z * wind.y;
        float phase = window_noise(m / size) * 6.2832;
        return gust * min(wind.w, 1.0) * (0.5 + 0.5 * sin(t * 7.3 + phase));
    }

    // The branches swaying apart (rooms::WIND_BRANCHES): how far a leaf layer's lookup at
    // m moves in the map, by a slow field a branch's reach across, at most a leaf's width,
    // so neighbouring regions sway a little differently and no shape smears. Two value
    // noises, along and across the wind, each scrolled along it at its own pace, so the
    // field changes its shape as it goes; the farther layers move more and quicker, and
    // quicker still where a gust reaches (its clock run ahead, rooms::gust_clock).
    vec2 branch_sway(vec2 m, float layer, float gusted) {
        vec2 p = m * branches.w + vec2(37.1, 11.7) * layer;
        float c = (branches.x + gusted * gust_reach.y) * (0.3 + 0.06 * layer);
        float along = window_noise(p - vec2(1.0, 0.15) * c);
        float across = window_noise(p.yx + vec2(5.3, 2.9) - vec2(0.4, 0.9) * (1.3 * c));
        float a = (branches.y + gusted * branches.z) * (0.8 + 0.1 * layer);
        return a * vec2(2.0 * along - 1.0, 0.7 * (2.0 * across - 1.0)) / tree.xy;
    }

    // How much of the key the tree outside lets through to p (trees.goose): p carried
    // along the key onto the map, which holds the tree as the sun sees it, blurred by the
    // sun's disc at each layer's distance, so its gaps are round flecks. Farther from the
    // window than the board's middle, its mips blur it more. Each layer sways on its own.
    // x the limbs' light, y the leaves', the leaves blurred tree_blur.z mips more (with
    // the noise's leaves inside the crown, its shape alone).
    vec2 tree_light(vec3 p, vec3 l, vec2 nw, vec2 along, float toward) {
        float back = dot(p.xz, nw) / toward;
        vec2 m = vec2(dot(p.xz, along) - dot(l.xz, along) * back, p.y - l.y * back);
        vec2 uv = (m - tree.zw) / tree.xy + 0.5;
        float more = max(back * back - 2.0 * tree_blur.y * back, 0.0);
        float lod = 0.5 * log2(max(more * tree_blur.x * tree_blur.x, 1.0));
        // Each layer shifts as a whole, by its own noises along and across the wind
        // (rooms::wind_at), the gust's share as its front reaches m. Nothing bends a limb.
        float gust = wind_at(m).y;
        float t = wind.z * wind.y;
        // The ruffle: the near and middle leaves blended with themselves nudged a leaf's
        // width, patch by patch; its noise worked out only where it may turn a patch 5% or more
        // (less moved a still shot by at most a level).
        float turn = gust * min(wind.w, 1.0) > 0.05 && wind_now.w < 1.5 ? ruffle_at(m, gust, 1.5) : 0.0;
        vec2 nudge = vec2(cos(t * 5.1), sin(t * 4.3)) * (0.35 / tree.xy);
        float wood = textureLod(tree_map, uv + tree_shift[0].xy + gust * tree_shift[0].zw, lod).a;
        float leafy = lod + tree_blur.z;
        vec2 at_near = uv + tree_shift[1].xy + gust * tree_shift[1].zw;
        vec2 at_mid = uv + tree_shift[2].xy + gust * tree_shift[2].zw;
        vec2 at_far = uv + tree_shift[3].xy + gust * tree_shift[3].zw;
        // The branches: each layer moved by region, never blended with itself.
        if (wind_now.w > 1.5) {
            at_near += branch_sway(m, 0.0, gust);
            at_mid += branch_sway(m, 1.0, gust);
            at_far += branch_sway(m, 2.0, gust);
            turn = 0.0;
        }
        float near = textureLod(tree_map, at_near, leafy).r;
        float middle = textureLod(tree_map, at_mid, leafy).g;
        if (turn > 0.001) {
            near = mix(near, textureLod(tree_map, at_near + nudge, leafy).r, turn);
            middle = mix(middle, textureLod(tree_map, at_mid - nudge.yx, leafy).g, turn);
        }
        float far = textureLod(tree_map, at_far, leafy).b;
        return vec2(wood, near * middle * far);
    }

    // The noise's leaves at p, t along the key from the window's wall: clumps rounder
    // and softer the farther they are, and single leaves within them.
    float noise_leaves(vec3 p, vec3 l, vec2 along, float toward, float t) {
        float tl = t + leaves.z / toward;
        vec3 ql = p + l * tl;
        vec2 lw = vec2(dot(ql.xz, along), ql.y) * leaves.y;
        // The wind: the canopy shifts with the sway, and in a gust warps a little, each
        // clump out of step.
        vec2 wa = wind_at(vec2(dot(ql.xz, along), ql.y));
        float tw = wind.z * wind.y;
        float warp = 0.3 + 0.7 * wa.y;
        lw += wind.x * (vec2(1.0, 0.15) * (wa.x + 1.5 * wa.y)
                        + warp * vec2(sin(tw * 0.9 + lw.y * 0.7), 0.6 * cos(tw * 0.7 + lw.x * 0.5)));
        float n = 0.55 * window_noise(lw) + 0.3 * window_noise(lw * 2.03 + 7.1)
                + 0.15 * window_noise(lw * 4.1 + 3.7);
        float ls = 0.02 + room.z * tl * leaves.y * leaves.w;
        float open_sky = smoothstep(leaves.x - ls, leaves.x + ls, n);
        // The single leaves within: under a clump only their gaps let the sun through,
        // small round flecks; in the open their own small shadows, fainter. They
        // flutter faster than the branches sway.
        if (twigs.x > 0.0) {
            vec2 lf = lw * twigs.x;
            float m = 0.65 * window_noise(lf) + 0.35 * window_noise(lf * 2.13 + 5.3);
            float gaps = smoothstep(twigs.y - twigs.z, twigs.y + twigs.z, m);
            open_sky = mix(gaps, mix(1.0, gaps, twigs.w), open_sky);
        }
        return open_sky;
    }

    #ifdef SHELL_WINDOWS
    // The shell's box windows (room_shell, shell_mesh.goose's casement, metres): how much
    // of the sun the casement at a glass plane lets through at w (along from the window's
    // middle, up from the floor): the blind frame's opening, the transom, the meeting
    // stiles, each sash's stiles and rails, and its bars, each edge `soft` wide.
    float casement(vec2 w, float soft) {
        const float BAR = 0.024;
        float s = shell_niche.y;
        float h = shell_niche.y + shell_niche.z;
        float zt = s + (h - s) * 2.0 / 3.0;
        float gx = 0.49;
        float x = abs(w.x);
        float open = min(gx - x, min(w.y - (s + 0.03), (h - 0.06) - w.y));
        open = min(open, min(abs(w.y - zt) - 0.045, x - (0.0175 + 0.05)));
        bool upper = w.y > zt;
        float y0 = upper ? zt + 0.045 : s + 0.03;
        float y1 = upper ? h - 0.06 : zt - 0.045;
        float ax0 = 0.0175 + 0.05;
        float ax1 = gx - 0.055;
        float ay0 = y0 + (upper ? 0.055 : 0.08);
        float ay1 = y1 - 0.055;
        open = min(open, min(ax1 - x, min(w.y - ay0, ay1 - w.y)));
        float across = upper ? 3.0 : 1.0;
        float up = upper ? 3.0 : 2.0;
        float pitch_x = (ax1 - ax0 + BAR) / across;
        float pitch_y = (ay1 - ay0 + BAR) / up;
        // The bars: each the width BAR, its far edge at a whole pitch from the leaf's edge.
        float u = x - ax0 + 0.5 * BAR;
        float v = w.y - ay0 + 0.5 * BAR;
        if (across > 1.5 && u > 0.5 * pitch_x && u < (across - 0.5) * pitch_x)
            open = min(open, abs(u - pitch_x * floor(u / pitch_x + 0.5)) - 0.5 * BAR);
        if (v > 0.5 * pitch_y && v < (up - 0.5) * pitch_y)
            open = min(open, abs(v - pitch_y * floor(v / pitch_y + 0.5)) - 0.5 * BAR);
        return smoothstep(-soft, soft, open);
    }

    // How much of the casement's glazed opening (the blind frame's, its sashes and bars
    // taken as LACE_GLAZED on average) is at w, its edge `soft` wide: where the sun through
    // the glass can light the lace, so what the lace scatters on starts there, never at the
    // frame or the plaster round it.
    float glazing(vec2 w, float soft) {
        float s = shell_niche.y;
        float h = shell_niche.y + shell_niche.z;
        return smoothstep(-soft, soft, min(0.49 - abs(w.x), min(w.y - (s + 0.03), (h - 0.06) - w.y)));
    }

    // The curtains' lace panels (model3d's curtains.goose): a panel's height, inner edge and
    // outer edge (metres from the window's middle) at its outline's keys, shell.goose's
    // LACE_HUNG_AS_MADE and LACE_OUTER, taken straight between them here; the inner edge
    // hung shell_mids.w further over the opening (room_shell::lace_hang).
    const vec3 LACE_EDGES[6] = vec3[6](vec3(0.05, 0.585, 0.955), vec3(0.5, 0.615, 0.89), vec3(0.95, 0.645, 0.8),
                                       vec3(1.6, 0.58, 0.85), vec3(2.6, 0.45, 0.89), vec3(3.7, 0.35, 0.9));
    vec2 lace_edges(float y) {
        vec2 e = LACE_EDGES[0].yz;
        for (int i = 0; i < 5; i++) {
            if (y > LACE_EDGES[i].x) {
                float t = clamp((y - LACE_EDGES[i].x) / (LACE_EDGES[i + 1].x - LACE_EDGES[i].x), 0.0, 1.0);
                e = mix(LACE_EDGES[i].yz, LACE_EDGES[i + 1].yz, t);
            }
        }
        return e - vec2(shell_mids.w, 0.0);
    }

    // Where uv (world units: across the cloth from its outer edge, up it from the hem) falls
    // in the lace's mask: the field's tile (its first 1024 rows) repeating, on down into
    // the hem's strip (its last 384 rows, 0.21 m) at the cloth's foot, at one scale.
    vec2 lace_place(vec2 uv) {
        float k = (0.375 * tile.z - uv.y) / tile.z;
        float row = k > 0.0 ? 1.0 + min(k, 0.3745) : fract(k);
        return vec2(uv.x / tile.z, row * (1024.0 / 1408.0));
    }

    // How much of the sun the lace in front of a niche lets on at w (metres from the
    // window's middle, up from the floor, at its plane): its thread keeps out all but
    // shell_glass.w where it covers, about a quarter of the sun where the panel hangs at its
    // 2× fullness (0.55 m wide), more where it is gathered narrower toward the tie (as
    // model3d's room_light::lace_lets); its pattern half washed out, since the lace scatters
    // on forward much of what it doesn't let straight through, blurred to the shadow's
    // softness, a little denser on the folds' flanks.
    // A machine lace's net ground stops about a fifth of the sun, its motifs as much as the
    // thread does (1 - shell_glass.w); the pattern shows at LACE_PATTERN_SHOWN of its
    // contrast, the rest scattered on.
    const float LACE_NET_STOPS = 0.2;
    const float LACE_PATTERN_SHOWN = 0.75;
    // y: with wide over 0, the share of the sun the lace stops on average round w (its
    // outline blurred wide, the pattern's mean), for its light below; else 0.
    vec2 lace_shadow(vec2 w, float soft, float wide) {
        vec2 e = lace_edges(w.y);
        float x = abs(w.x);
        float edge = min(min(x - e.x, e.y - x), min(w.y - 0.07, 3.7 - w.y));
        float scattered = 0.0;
        if (wide > 0.0) {
            float mean_lets = 1.0 - mix(LACE_NET_STOPS, 1.0 - shell_glass.w, 0.5);
            scattered = smoothstep(-wide, wide, edge) * (1.0 - pow(mean_lets, max(0.55 / max(e.y - e.x, 0.05), 1.0)));
        }
        float inside = smoothstep(-soft, soft, edge);
        if (inside < 0.001) return vec2(1.0, scattered);
        float s = clamp((x - e.x) / (e.y - e.x), 0.0, 1.0);
        vec2 uv = vec2((1.0 - s) * 1.2, w.y - 0.07) * shell.w;
        float cover = textureLod(lace_mask, lace_place(uv), log2(max(soft * 1024.0 / 0.56, 1.0))).r;
        cover = mix(0.5, cover, LACE_PATTERN_SHOWN);
        float folds = 0.8 + 0.4 * (0.5 + 0.5 * sin(6.2831853 * 6.0 * s));
        float flat_lets = 1.0 - clamp(mix(LACE_NET_STOPS, 1.0 - shell_glass.w, cover) * folds, 0.0, 0.9);
        return vec2(mix(1.0, pow(flat_lets, max(0.55 / max(e.y - e.x, 0.05), 1.0)), inside), scattered);
    }

    // The share of the sun the lace stops that it scatters on forward into a broad cone
    // (thin cloth, as a lit lace glows), and that cone's widening a metre: about 25° across.
    // The casement's glazing lets through about LACE_GLAZED of the sun on average, which the
    // cone's light, blurred past the bars, takes.
    const float LACE_FORWARD = 0.35;
    const float LACE_CONE = 0.22;
    const float LACE_SOFT = 0.006;
    const float LACE_GLAZED = 0.7;

    // How much of the key reaches p through the shell's windows, 0 to 1: p traced along the
    // key to the window wall's inner face (the niche's arched outline: or where p is, if it
    // is in the niche), on to the two glass planes with their bars, and back to the lace in
    // front, which lets on the scattered share of what it stops softly round its shadow
    // (window_view.y, 0 none); summed over the windows, then the tree outside.
    float shell_open(vec3 p) {
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        if (toward < 0.05) return 0.0;
        float metre = shell.w;
        // The penumbra's widening with distance: the shell's own, sharper than the game's
        // window takes it.
        float widen = shell_sun.x > 0.0 ? shell_sun.x : room.z;
        float d = dot(p.xz, nw);
        float half_w = shell_niche.x;
        float rise = shell_niche.w;
        float radius = (half_w * half_w + rise * rise) / (2.0 * rise);
        float spring = shell_niche.y + shell_niche.z;
        float arch_mid = spring + rise - radius;
        float lit = 0.0;
        for (int i = 0; i < 3; i++) {
            if (float(i) >= shell.x) break;
            float mid = shell_mids[i];
            // The niche's outline at the inner face, or at p within the niche.
            float t = max((shell.y - d) / toward, 0.0);
            vec3 q = p + l * t;
            vec2 w = vec2(dot(q.xz, along) - mid, q.y - shell.z) / metre;
            float soft = (0.03 + widen * t) / metre;
            float head = arch_mid + sqrt(max(radius * radius - w.x * w.x, 0.0));
            float through = smoothstep(-soft, soft, min(half_w - abs(w.x), min(w.y - shell_niche.y, head - w.y)));
            if (through < 0.001) continue;
            // The lace in front of the niche, for what is behind it in the room: its shadow a
            // little softer than the bars' (LACE_SOFT a metre, its threads' own scatter), and
            // what it scatters on from a cone LACE_CONE wide, lit only where the glass is.
            float tl = (shell.y - shell_glass.z - d) / toward;
            float cone = window_view.y > 0.0 && tl > 0.5 ? LACE_CONE * tl / metre : 0.0;
            // The two casements, and their glazed opening as the lace's cone sees it.
            float glazed = 1.0;
            for (int k = 0; k < 2; k++) {
                float tg = (shell.y + (k == 0 ? shell_glass.x : shell_glass.y) - d) / toward;
                if (tg <= 0.0) continue;
                vec3 g = p + l * tg;
                vec2 wg = vec2(dot(g.xz, along) - mid, g.y - shell.z) / metre;
                float soft_g = (0.03 + widen * tg) / metre;
                through *= casement(wg, soft_g);
                if (cone > 0.0) glazed *= glazing(wg, soft_g + cone);
            }
            if (tl > 0.5) {
                vec3 c = p + l * tl;
                vec2 wl = vec2(dot(c.xz, along) - mid, c.y - shell.z) / metre;
                float soft_l = (0.03 + widen * tl) / metre + LACE_SOFT * tl / metre;
                vec2 lace = lace_shadow(wl, soft_l, cone > 0.0 ? soft_l + cone : 0.0);
                through = through * lace.x + window_view.y * LACE_FORWARD * LACE_GLAZED * glazed * lace.y;
            }
            lit += through;
        }
        lit = min(lit, 1.0);
        if (tree.x > 0.0 && lit > 0.001) {
            vec2 tr = tree_light(p, l, nw, along, toward);
            lit *= tr.x * tr.y;
        }
        return lit;
    }
    #endif

    // How much of the key reaches p through the window (rooms::Room's pattern), 0 to 1: p
    // traced along the key to the window's wall, where the opening, its bars, and the
    // curtain say whether the sun came through, and on to the trees beyond, whose leaves
    // dapple it; each edge softer the farther it is from p. 1 with no pattern. A wall keeps
    // all of the sun out: a highlight takes this.
    float window_open(vec3 p) {
        if (room.y <= 0.0) return 1.0;
    #ifdef SHELL_WINDOWS
        if (shell.x > 0.5) return shell_open(p);
    #endif
        vec3 l = light_dir.xyz;
        vec2 h = normalize(l.xz);
        float a = radians(window.y);
        vec2 nw = vec2(cos(a) * h.x - sin(a) * h.y, sin(a) * h.x + cos(a) * h.y);
        vec2 along = vec2(-nw.y, nw.x);
        float toward = dot(l.xz, nw);
        if (toward < 0.05) return 0.0;
        float t = (window.x - dot(p.xz, nw)) / toward;
        vec3 q = p + l * t;
        // Along the wall from where the board's middle sees the sun, up from the sill.
        vec2 w = vec2(dot(q.xz - l.xz * (window.x / toward), along) - window.w, q.y - window.z);
        float soft = 0.03 + room.z * t;
        vec2 size = opening.xy * panes.xy;
        float inside = min(size.x * 0.5 - abs(w.x), min(w.y, size.y - w.y));
        float lit = smoothstep(-soft, soft, inside);
        // The bars between the panes.
        vec2 f = abs(fract(vec2(w.x / panes.x + opening.x * 0.5, w.y / panes.y) + 0.5) - 0.5) * panes.xy;
        lit *= smoothstep(-soft, soft, min(f.x, f.y) - panes.z * 0.5);
        // The lace curtain drawn in from the opening's far side, its edge in folds.
        if (opening.z > 0.0) {
            float edge = size.x * 0.5 - opening.z + 0.6 * sin(w.y * 0.35) + 0.3 * sin(w.y * 0.9 + 1.3);
            lit *= mix(1.0, opening.w, smoothstep(edge - 2.0 * soft, edge + 2.0 * soft, w.x));
        }
        // The leaves outside: the tree's baked shadow, or clumps of noise, rounder and
        // softer the farther they are.
        if (tree.x > 0.0) {
            vec2 tr = tree_light(p, l, nw, along, toward);
            // With the noise's leaves inside the tree's crown: its limbs, and the dapple
            // where it has leaves; a bare tree's crown has none.
            float crown = clamp((1.0 - tr.y) * tree_blur.w, 0.0, 1.0);
            float leaves_lit = tree_blur.z > 0.0 ? mix(1.0, noise_leaves(p, l, along, toward, t), crown) : tr.y;
            lit *= tr.x * leaves_lit;
        } else if (leaves.x > 0.0) {
            lit *= noise_leaves(p, l, along, toward, t);
        }
        return lit;
    }

    // The key's light through the window as the diffuse takes it: the shade keeps out
    // room.y of it, the rest standing for the light the room throws back (the game's room
    // has no other).
    float window_light(vec3 p) {
        if (room.y <= 0.0) return 1.0;
        return mix(1.0 - room.y, 1.0, window_open(p));
    }

    vec3 to_srgb(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    """;

// LIT_FRAG's inputs and textures, before LIGHT_FN, which reads the tree's map.
let LIT_HEAD = """
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in vec2 v_extra;
    layout(location = 4) in vec3 v_local;
    layout(location = 5) flat in vec4 v_kind;
    layout(location = 6) flat in float v_alpha;
    layout(location = 7) in vec2 v_wear;
    layout(location = 8) in vec3 v_scatter;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D plan_albedo;
    layout(set = 2, binding = 1) uniform sampler2D plan_normal;
    layout(set = 2, binding = 2) uniform sampler2D frame_albedo;
    layout(set = 2, binding = 3) uniform sampler2D frame_normal;
    layout(set = 2, binding = 4) uniform sampler2DShadow shadow_map;
    // The pieces' occlusion of the field (OCC_FRAG), over the plan's extent.
    layout(set = 2, binding = 5) uniform sampler2D field_occ;
    // The crown's distance over ±CROWN_SPAN of the piece's radius (CROWN_FRAG).
    layout(set = 2, binding = 6) uniform sampler2D crown_map;
    // The tree outside as the sun sees it (trees::draw_map).
    layout(set = 2, binding = 7) uniform sampler2D tree_map;
    """;

// The shell's windows for the board and the table in the room (SHELL_WINDOWS before them):
// LIGHT_FN's window_open then traces the sun through the shell's own windows (shell_open),
// as the room's surfaces take it, not through the game's window, whose opening stands on
// the line from the board's middle to the sun wherever the shell's walls are. The fields
// of ROOM_HEAD's Surfaces that shell_open reads, by the same names (render3d::ShellBlock),
// and the lace's mask, after LIT_HEAD's or TABLE_HEAD's own.
let LIT_SHELL = """
    layout(set = 2, binding = 8) uniform sampler2D lace_mask;
    layout(set = 3, binding = 1) uniform Shell { vec4 axes; vec4 tile; vec4 shell; vec4 shell_mids; vec4 shell_niche;
                                                 vec4 shell_glass; vec4 shell_sun; vec4 window_view; };
    """;
let TABLE_SHELL = """
    #ifdef NO_SSAO
    layout(set = 2, binding = 8) uniform sampler2D lace_mask;
    #else
    layout(set = 2, binding = 9) uniform sampler2D lace_mask;
    #endif
    layout(set = 3, binding = 2) uniform Shell { vec4 axes; vec4 tile; vec4 shell; vec4 shell_mids; vec4 shell_niche;
                                                 vec4 shell_glass; vec4 shell_sun; vec4 window_view; };
    """;

// The key light's shadow map filtered (map_shadow_at), which LIT_FRAG and TABLE_FRAG
// share: after their heads, which bind shadow_map. SHADOW_FEW or SHADOW_MANY first picks
// the taps.
let SHADOW_FN = """
    // The key light's shadow at q, a point already off its surface: a 5 × 5 texel box
    // with bilinear edges in 9 hardware-compared taps, their places and weights from where
    // the point falls in its texel (Castaño's filter, as The Witness has it). On a phone (SHADOW_FEW first) a 3 × 3 box in 4 taps, its edges stepped where
    // larger pieces would show them. On a desktop (SHADOW_MANY) a 7 × 7 box in 16 taps, softer.
    float map_shadow_at(vec3 q) {
        vec4 s = light_view_proj * vec4(q, 1.0);
        // Past the map, beside the board on its table: lit by the map.
        if (abs(s.x) > 1.0 || abs(s.y) > 1.0) return 1.0;
        vec2 size = vec2(textureSize(shadow_map, 0));
        vec2 uv = vec2(s.x * 0.5 + 0.5, 0.5 - s.y * 0.5) * size;
        float z = s.z - 0.0005;
        vec2 base = floor(uv + 0.5);
        vec2 f = uv + 0.5 - base;
        base = (base - 0.5) / size;
    #ifdef SHADOW_FEW
        vec2 w0 = 3.0 - 2.0 * f;
        vec2 w1 = 1.0 + 2.0 * f;
        vec2 o0 = ((2.0 - f) / w0 - 1.0) / size;
        vec2 o1 = (f / w1 + 1.0) / size;
        float sum = w0.x * w0.y * texture(shadow_map, vec3(base + vec2(o0.x, o0.y), z))
                  + w1.x * w0.y * texture(shadow_map, vec3(base + vec2(o1.x, o0.y), z))
                  + w0.x * w1.y * texture(shadow_map, vec3(base + vec2(o0.x, o1.y), z))
                  + w1.x * w1.y * texture(shadow_map, vec3(base + vec2(o1.x, o1.y), z));
        return sum * (1.0 / 16.0);
    #else
    #ifdef SHADOW_MANY
        // A desktop's: a 7 × 7 box in 16 taps.
        vec4 w0 = vec4(5.0 * f.x - 6.0, 11.0 * f.x - 28.0, -(11.0 * f.x + 17.0), -(5.0 * f.x + 1.0));
        vec4 u = vec4((4.0 * f.x - 5.0) / w0.x - 3.0, (4.0 * f.x - 16.0) / w0.y - 1.0,
                      -(7.0 * f.x + 5.0) / w0.z + 1.0, -f.x / w0.w + 3.0) / size.x;
        vec4 w1 = vec4(5.0 * f.y - 6.0, 11.0 * f.y - 28.0, -(11.0 * f.y + 17.0), -(5.0 * f.y + 1.0));
        vec4 v = vec4((4.0 * f.y - 5.0) / w1.x - 3.0, (4.0 * f.y - 16.0) / w1.y - 1.0,
                      -(7.0 * f.y + 5.0) / w1.z + 1.0, -f.y / w1.w + 3.0) / size.y;
        float sum = 0.0;
        for (int j = 0; j < 4; j++) {
            for (int i = 0; i < 4; i++) {
                sum += w0[i] * w1[j] * texture(shadow_map, vec3(base + vec2(u[i], v[j]), z));
            }
        }
        return sum * (1.0 / 2704.0);
    #else
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
    #endif
    #endif
    }
    """;

let LIT_FRAG = """
    const float CROWN_SPAN = 0.6;       // render3d::crown_map

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

    // The key light's shadow at p, on or by a piece lying on the table, from the others:
    // the ray from q (p moved off its surface) to the light against each upright disc, the
    // nearest it passes its side, softer the farther along it was cast. A piece's own
    // shades it by its normal alone: traced, its top's edge cut a line across its side.
    const float TABLE_Y = -0.703;   // mesh::TABLE_TOP
    float discs_shadow(vec3 p, vec3 q) {
        vec3 l = light_dir.xyz;
        if (l.y < 0.01) return 1.0;
        vec2 lxz = l.xz;
        float ll = max(dot(lxz, lxz), 1e-6);
        float r = disc_n.y;
        float lit = 1.0;
        int count = int(disc_n.x);
        for (int i = 0; i < 48; i++) {
            if (i >= count) break;
            vec4 c = discs[i];
            float own_x = length(p.xz - c.xy) - r;
            float own_y = max(TABLE_Y + c.z - p.y, p.y - TABLE_Y - c.w);
            if (own_y < 0.004 && own_x < 0.02) continue;
            float ta = max((TABLE_Y + c.z - q.y) / l.y, 0.0);
            float tb = (TABLE_Y + c.w - q.y) / l.y;
            if (tb <= 0.0) continue;
            float t = clamp(dot(c.xy - q.xz, lxz) / ll, ta, tb);
            float d = length(q.xz + lxz * t - c.xy) - r;
            // The penumbra inside the occluder's edge only: one flush over another
            // shades it only where it overhangs.
            float w = 0.008 + 0.05 * t;
            lit = min(lit, smoothstep(-w, 0.0, d));
        }
        return lit;
    }

    // How much of the sky the pieces lying on the table hide from p, on one of them: the
    // nearer another, the darker, as where two in a stack meet. Its own is left out.
    float discs_occlusion(vec3 p) {
        float r = disc_n.y;
        float occ = 1.0;
        int count = int(disc_n.x);
        for (int i = 0; i < 48; i++) {
            if (i >= count) break;
            vec4 c = discs[i];
            float dx = length(p.xz - c.xy) - r;
            float dy = max(TABLE_Y + c.z - p.y, p.y - TABLE_Y - c.w);
            if (dy < 0.004 && dx < 0.02) continue;
            float d = length(max(vec2(dx, dy), 0.0)) + min(max(dx, dy), 0.0);
            occ = min(occ, mix(0.5, 1.0, smoothstep(0.0, 0.12, d)));
        }
        return occ;
    }

    // The key light's shadow from the map, from a point pushed off the surface along its
    // normal, the farther the more the surface turns from the light.
    float map_shadow(vec3 p, vec3 n) {
        float nl = clamp(dot(n, light_dir.xyz), 0.0, 1.0);
        return map_shadow_at(p + n * (0.004 + 0.012 * (1.0 - nl)));
    }

    // The key light's shadow: the map's, and outside the field (the frame, the pieces
    // beside the board) the pieces lying on the table's, which the map leaves out.
    float shadow(vec3 p, vec3 n) {
        float s = map_shadow(p, n);
        if (disc_n.x > 0.5 && max(abs(p.x), abs(p.z)) > FIELD) {
            // Faded out over the terminator, where the side turning away is dark by its
            // normal: traced there, the piece above cut an edge across it.
            float facing = smoothstep(-0.05, 0.2, dot(n, light_dir.xyz));
            s = min(s, mix(1.0, discs_shadow(p, p + n * 0.01), facing));
        }
        // A broad key (winter's snowy doors) casts a fainter shadow.
        return mix(1.0, s, room.x) * window_light(p);
    }

    // One hardware-compared tap of the key's shadow at q (its bilinear edge only).
    float shadow_tap(vec3 q) {
        vec4 s = light_view_proj * vec4(q, 1.0);
        return texture(shadow_map, vec3(s.x * 0.5 + 0.5, 0.5 - s.y * 0.5, s.z - 0.0015));
    }

    // The board's scattering (frame_map.w its fraction, z its radius in world units):
    // the key's light that entered the stone round p, from 16 taps on a golden-angle
    // disc in the surface's plane (a Vogel disc: no ring of copies where a shadow's edge
    // crosses it), each channel weighting a tap by exp(-r / reach), its reach 0.35 to 1
    // of 0.45 the radius by how little the body absorbs it. `center` is the shadow at p.
    // Each pixel of a 2 × 2 quad turns the disc its own quarter (and each quad by a hash
    // of where it is on screen, still while nothing moves), and the quad's pixels share
    // their results through the derivatives: three discs' taps a pixel, so what copies of
    // a shadow's edge remain blur into a faint grain. Called where every pixel of a
    // triangle takes the same branch (the board's scattering is on or off for it).
    vec3 scatter_spread(vec3 p, vec3 ng, float radius, vec3 k, float center) {
        vec3 t1 = abs(ng.y) > 0.9 ? vec3(1.0, 0.0, 0.0) : normalize(cross(vec3(0.0, 1.0, 0.0), ng));
        vec3 t2 = cross(ng, t1);
        vec3 q = p + ng * 0.006;
        vec3 reach = 0.45 * radius * k;
        vec3 sum = vec3(center);
        vec3 weight = vec3(1.0);
        vec2 corner = mod(floor(gl_FragCoord.xy), 2.0);
        float turn = 6.2832 * hash13(vec3(floor(gl_FragCoord.xy * 0.5), 1.0)) + 1.5708 * (corner.x + 2.0 * corner.y);
        for (int i = 0; i < 16; i++) {
            float r = radius * sqrt((float(i) + 0.5) / 16.0);
            float a = float(i) * 2.39996 + turn;
            float s = shadow_tap(q + (t1 * cos(a) + t2 * sin(a)) * r);
            vec3 w = exp(-r / reach);
            sum += w * s;
            weight += w;
        }
        vec3 v = sum / weight;
        vec2 side = 1.0 - 2.0 * corner;
        return (3.0 * v + side.x * dFdx(v) + side.y * dFdy(v)) / 3.0;
    }

    // A painted line's pigment over the body: the surface over its blur, fully where
    // it clearly differs (a dark or a pale vein), 0.4 of it in the fine mottling.
    vec3 pigment_of(vec3 surface, vec3 blur) {
        vec3 ratio = surface / max(blur, vec3(1e-3));
        float apart = abs(1.0 - dot(ratio, vec3(0.2126, 0.7152, 0.0722)));
        return mix(vec3(1.0), ratio, 0.4 + 0.6 * smoothstep(0.1, 0.3, apart));
    }

    // The color light takes on a long path through the body: the body's color to the
    // power 1 + params.y (the board scattering's color depth), its luminance kept, so
    // the cream warms and the olive deepens.
    vec3 body_color(vec3 c) {
        vec3 lum = vec3(0.2126, 0.7152, 0.0722);
        vec3 d = pow(max(c, vec3(1e-4)), vec3(1.0 + params.y));
        return d * (dot(c, lum) / max(dot(d, lum), 1e-4));
    }

    // The frame's short inner wall's occlusion of the field, as a long wall: too sharp
    // (FRAME_TOP across) for the pieces' map, and two square roots.
    float wall_occlusion(vec3 p) {
        vec2 d = max(INNER - abs(p.xz), vec2(0.0));
        float h = FRAME_TOP;
        return (1.0 - 0.5 * (1.0 - d.x / sqrt(d.x * d.x + h * h)))
             * (1.0 - 0.5 * (1.0 - d.y / sqrt(d.y * d.y + h * h)));
    }

    // The crown's signed distance (CROWN_FN), from its map (CROWN_FRAG).
    float crown(vec2 p) { return texture(crown_map, p * (0.5 / CROWN_SPAN) + 0.5).r; }

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

    float hash_of(float seed, float k) { return hash13(vec3(seed, k, 7.31)); }

    #ifdef PIECES_WOOD
    // Turned wood (frame_map.y -1), the board's growth rings (BAKE_FRAG's rings()) in
    // the disc's own 3D space, so a ring is one surface through the face, the lip and
    // the turned side. The disc is cut from a plank, its grain along `along` at the
    // piece's own angle; the log's pith runs along the grain below the face, d deep and
    // c to one side: quarter-sawn cuts (flatness 0) put it far aside and draw near
    // straight lines, flat-sawn ones (1) put it under the face, leaning, and draw arches.
    // The radius wobbles, the years are uneven, each late wood its own strength (a few
    // years dark); fibres
    // and pores run along the grain; the color darkens by Beer's law. On the turned side
    // the end grain, where the surface faces along the grain, soaks the finish darker.
    // Anything finer than a pixel fades to its mean (fwidth). base linear, figure 1 the
    // board's strength; maple light, walnut dark (the autumn look's square values).
    vec3 piece_wood(vec3 lp, vec3 ng, float seed, vec3 base, float figure, bool dark, inout float rough,
                    out float relief) {
        vec3 o = vec3(hash_of(seed, 1.7), hash_of(seed, 9.3), hash_of(seed, 4.1)) * 37.0;
        float turn = hash_of(seed, 0.5) * PI;
        vec2 dir = vec2(cos(turn), sin(turn));
        float along = dot(lp.xz, dir);
        float across = dot(lp.xz, vec2(-dir.y, dir.x));
        float rw = dark ? 0.06 : 0.05;                       // a year's width
        vec3 k = dark ? vec3(0.7, 0.7, 0.6) : vec3(0.3, 0.5, 0.45);   // wander, broad, fibre
        float late_dark = dark ? 0.3 : 0.4;
        float late_start = dark ? 0.8 : 0.6;             // walnut's rings are faint and thin
        float pores = dark ? 0.35 : 0.3;
        float flatness = clamp((dark ? 0.5 : 0.25) + (hash_of(seed, 2.1) - 0.5) * 0.9, 0.0, 1.0);
        float side = hash_of(seed, 3.7) > 0.5 ? 1.0 : -1.0;
        float d = mix(0.1, 1.2, flatness) * (0.6 + 0.8 * hash_of(seed, 5.3));
        float c = side * mix(2.0 + 2.0 * hash_of(seed, 6.1), 0.5 * (hash_of(seed, 6.1) - 0.5), flatness);
        float axis = noise3(vec3(along * 0.6, 0.5, 0.5) + o) - 0.5;
        float lean = (hash_of(seed, 8.8) - 0.5) * 0.5 * flatness;
        float dd = max(d + lean * along + axis * 0.3 * flatness + (HEIGHT - lp.y), 0.02);
        float r = length(vec2(across - c - axis * 0.4, dd));
        r += rw * k.x * 3.0 * (noise3(vec3(across * 1.6, lp.y * 1.6, along * 0.5) + o) - 0.5);
        r += rw * k.x * 0.8 * (noise3(vec3(across * 6.0, lp.y * 6.0, along * 0.9) + o) - 0.5);
        r += rw * 0.25 * (noise3(vec3(across * 14.0, lp.y * 14.0, along * 4.0) + o.yzx) - 0.5);
        float t = r / rw;
        t += 1.2 * (noise3(vec3(t * 0.3, seed, 0.5)) - 0.5);
        float year = floor(t);
        float ph = t - year;
        float ft = fwidth(t);
        float e = max(0.06, 1.5 * ft);
        // Its rise kept before its edge (smoothstep's edges reversed are undefined).
        float late = smoothstep(min(late_start, 1.0 - 2.0 * e), 1.0 - e, ph);
        late *= mix(late, 1.0, 0.3) * (1.0 - smoothstep(1.0 - e, 1.0, ph));
        // Each year's late wood its own strength, now and then a dark year that can be
        // followed over the lip and down the side.
        float strength = hash_of(year + seed * 13.0, 4.4);
        late *= 0.5 + strength + 0.5 * smoothstep(0.9, 0.98, strength);
        float ring_seen = 1.0 - smoothstep(0.15, 0.4, ft);
        late = mix(0.12, late, ring_seen);
        float early = 1.0 - smoothstep(0.0, 0.5, ph);
        // Fibres along the grain as the board's (BAKE_FRAG's rings()): fine across it
        // (in across and the height), long along, three widths, each fading to its mean
        // where it is finer than a pixel; at playing size the middle one is the streaks
        // the squares show.
        vec3 fq = vec3(across * 150.0, lp.y * 150.0, along * 2.0);
        float fine = 1.0 - smoothstep(0.5, 1.2, fwidth(fq.x) + fwidth(fq.y));
        float fibre = 0.5 + fine * (0.6 * noise3(fq + o) + 0.4 * noise3(fq * vec3(0.37, 0.37, 0.35) + o.yzx) - 0.5);
        // Walnut's streaks are denser, as on its squares.
        float sf = dark ? 80.0 : 40.0;
        vec3 sq = vec3(across * sf, lp.y * sf, along * 0.6 * sf / 40.0) + o.zxy;
        float streak = noise3(sq);
        streak = mix(0.5, streak, 1.0 - smoothstep(0.4, 1.0, fwidth(sq.x) + fwidth(sq.y)));
        // Pores, filled by the varnish: faint darker dashes along the grain, more in the
        // early wood, never rough.
        vec3 pq = vec3(across * 110.0, lp.y * 110.0, along * 9.0);
        float pore = smoothstep(0.8, 0.92, noise3(pq + o.zxy)) * pores * mix(0.6, 1.4, early);
        pore *= 1.0 - smoothstep(0.6, 1.4, fwidth(pq.x) + fwidth(pq.y));
        float broad = noise3(vec3(across * 1.2, lp.y * 1.2, along * 0.25) + o);
        // End grain: where the turned side faces along the grain, soaking the finish.
        float end = abs(dot(ng.xz, dir)) * (1.0 - abs(ng.y));
        float a = figure * (late_dark * (late - 0.08) + k.z * ((fibre - 0.5) * 0.7 + (streak - 0.5) * 1.1)
                            + k.y * (broad - 0.5) * 1.5 + 0.25 * pore) + 0.3 * end * end;
        // Under the varnish the wood is satin and its figure slightly sunk: the late
        // wood, the streaks and the pores take a little relief (world units), which
        // breaks up the sheen as the squares' baked relief does.
        relief = -0.0012 * late * ring_seen - 0.0005 * (streak - 0.5) - 0.0004 * (fibre - 0.5) - 0.0006 * pore;
        rough += 0.04 * (0.5 - streak) + 0.06 * (1.0 - min(late, 1.0)) * ring_seen + 0.1 * end;
        return pow(base, vec3(1.0 + a));
    }
    #endif

    #ifdef PIECES_WINTER
    // The nearest and second nearest of jittered cells (Worley's): their distances.
    vec2 piece_cells(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        float d1 = 8.0;
        float d2 = 8.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 o = vec2(float(x), float(y));
                vec2 c = o + vec2(hash13(vec3(i + o, 1.0)), hash13(vec3(i + o, 2.0))) * 0.9 + 0.05 - f;
                float d = dot(c, c);
                if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
            }
        }
        return vec2(sqrt(d1), sqrt(d2));
    }

    // Winter's stones in the disc's own 3D space (frame_map.y -2 honed slate, -3
    // polished black marble, the light men satin ivory with either). base linear.
    vec3 piece_winter(vec3 lp, vec3 ng, vec3 to_eye, float seed, vec3 base, float figure, bool dark,
                      bool onyx, inout float rough) {
        vec3 o = vec3(hash_of(seed, 2.3), hash_of(seed, 5.9), hash_of(seed, 8.1)) * 41.0;
        if (!dark) {
            // Satin ivory: warm cream, a fine growth figure along the tusk the slab was
            // cut from (close uneven lines, drawn out along it), warmer where darker as
            // Beer's law has it, and a faint broad cloud. Lines finer than a pixel fade.
            float turn = hash_of(seed, 0.5) * PI;
            vec2 dir = vec2(cos(turn), sin(turn));
            float along = dot(lp.xz, dir);
            float across = dot(lp.xz, vec2(-dir.y, dir.x)) + 0.03 * noise3(lp * 4.0 + o);
            vec3 q = vec3(across * 90.0, lp.y * 90.0, along * 5.0);
            float line = 0.65 * noise3(q + o) + 0.35 * noise3(q * vec3(2.3, 2.3, 1.7) + o.zxy);
            line = mix(0.5, line, 1.0 - smoothstep(0.4, 1.0, fwidth(q.x) + fwidth(q.y)));
            float cloud = noise3(lp * 5.0 + o.yzx);
            float a = figure * (2.0 * (line - 0.5) + 1.2 * (cloud - 0.5));
            rough += 0.06 * (cloud - 0.5);
            return base * max(vec3(0.0), 1.0 - a * vec3(0.55, 0.75, 1.25));
        }
        if (!onyx) {
            // Honed slate: cleavage layers at 20 to 35 degrees to the face, each piece
            // its own way, so the face cuts several as soft tide marks and the turned
            // side shows them as slanting strata, never level rings; finer laminae and a fine grain, the lighter
            // layers a little bluer and smoother.
            float lean = 0.35 + 0.35 * hash_of(seed, 1.1);
            float way = hash_of(seed, 3.3) * 2.0 * PI;
            vec3 tilt = normalize(vec3(cos(way) * lean, 1.0, sin(way) * lean));
            float h = dot(lp, tilt) + 0.02 * noise3(lp * 5.0 + o);
            float layer = noise3(vec3(h * 55.0, 0.5, seed));
            float lam = noise3(vec3(h * 240.0, 1.5, seed + 0.5));
            lam = mix(0.5, lam, 1.0 - smoothstep(0.4, 1.0, fwidth(h * 240.0)));
            float grain = noise3(lp * 280.0 + o);
            grain = mix(0.5, grain, 1.0 - smoothstep(0.4, 1.0, fwidth(lp.x * 280.0) + fwidth(lp.z * 280.0)));
            float a = figure * (1.6 * (layer - 0.5) + 0.7 * (lam - 0.5) + 0.6 * (grain - 0.5));
            rough -= 0.5 * a;
            return base * max(vec3(0.0), 1.0 + a * vec3(0.85, 1.0, 1.2));
        }
        // Polished black marble, fracture veins as in the black marbles sold as black
        // granite: white veins along cracks that branch and meet, lying in the stone
        // (a soft halo round each), a few broken finer ones near them, a faint cloud.
        // A vein is a sheet through the stone, so the pattern on the face runs on
        // straight down the side (the face's plan, leaning a little). Each piece its own
        // cut and its own share of veins, some nearly clear. Lines at least a pixel
        // wide, fainter where narrower.
        vec2 pp = lp.xz + lp.y * vec2(0.35, 0.2) + o.xy;
        vec2 r = vec2(0.866 * pp.x + 0.5 * pp.y, -0.5 * pp.x + 0.866 * pp.y);
        vec2 w1 = vec2(noise3(vec3(pp * 0.9, 1.0)), noise3(vec3(pp * 0.9, 5.0))) - 0.5;
        vec2 p = vec2(r.x * 0.45, r.y) * 2.0 + 0.9 * w1;
        float texel = max(length(fwidth(p)), 1e-4);
        float share = 0.35 + 0.9 * hash_of(seed, 6.2);
        vec2 j1 = p + 0.05 * (vec2(noise3(vec3(p * 4.0, 2.0)), noise3(vec3(p * 4.0, 7.0))) - 0.5);
        vec2 c1 = piece_cells(j1 * 0.9);
        float d1 = (c1.y - c1.x) * 0.5 / 0.9;
        float n1 = noise3(vec3(p * 1.7, 4.0));
        float wide = 0.008 * (0.2 + 1.8 * n1 * n1);
        float shown = smoothstep(0.5, 0.62, noise3(vec3(p * 0.6, 13.0)) + 0.15 * (share - 0.8));
        float core = (1.0 - smoothstep(0.5 * wide, wide + texel, d1)) * min(wide / texel, 1.0);
        float halo = exp(-d1 / 0.02) * 0.12;
        float v = max(core, halo) * shown;
        // The finer ones only near a shown main vein, broken into short lengths.
        vec2 c2 = piece_cells(j1 * 4.0 + 17.0);
        float d2 = (c2.y - c2.x) * 0.5 / 4.0;
        float near_main = shown * exp(-d1 / 0.08);
        float some = near_main * smoothstep(0.5, 0.65, noise3(vec3(p * 5.0, 3.0)));
        v = max(v, 0.4 * some * (1.0 - smoothstep(0.0015, 0.003 + texel, d2)) * min(0.003 / texel, 1.0));
        float cloud = noise3(vec3(p * 1.3, 51.0)) - 0.5;
        v = clamp(v * figure * 2.0 * share, 0.0, 1.0);
        rough += 0.04 * v;
        return mix(base * (1.0 + 0.5 * figure * cloud), vec3(0.8, 0.8, 0.79), v);
    }
    #endif

    // A height h (world units) as a normal's tilt, from its screen derivatives
    // (Mikkelsen's bump mapping of unparametrized surfaces): no tangents needed.
    vec3 bumped(vec3 n, vec3 p, float h) {
        vec3 dpx = dFdx(p);
        vec3 dpy = dFdy(p);
        vec3 r1 = cross(dpy, n);
        vec3 r2 = cross(n, dpx);
        float det = dot(dpx, r1);
        vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
        return normalize(abs(det) * n - grad);
    }

    vec3 tonemap(vec3 c) {
        // Khronos PBR Neutral: hue kept, highlights eased; its toe halved, as the
        // references' darks keep their color. The tuner's shaders switch it (TOE_FN).
    #ifdef TOE_SWITCH
        c = toe_off(c, toe.z);
    #else
        float x = min(c.r, min(c.g, c.b));
        float offset = x < 0.04 ? x - 12.5 * x * x : 0.02;
        c -= offset;
    #endif
        float peak = max(c.r, max(c.g, c.b));
        const float start = 0.76;
        if (peak < start) return c;
        const float d = 1.0 - start;
        float np = 1.0 - d * d / (peak + d - start);
        c *= np / peak;
        float g = 1.0 - 1.0 / (0.15 * (peak - np) + 1.0);
        return mix(c, vec3(np), g);
    }

    void main() {
        float mat = v_extra.y;
        vec3 p = v_world;
        vec3 n = normalize(v_normal);
        float ao = clamp(v_extra.x, 0.0, 1.0);
        float pieces_occ = 1.0;     // the pieces' share of the field's occlusion
        vec3 albedo;
        float rough;
        float top_var = 0.0;     // the spread of a shader-made normal over the pixel
        // The board's scattering (frame_map.w > 0): the fraction leaving the body, its
        // color, how far it spreads, and what came in through the frame's top (colored).
        vec3 ng = n;
        float sss_f = 0.0;
        vec3 body = vec3(0.0);
        vec3 travelled = vec3(0.0);
        float sss_radius = 0.0;
        vec3 through = vec3(0.0);
        // A wood piece's varnish (frame_map.y -1): the figure's relief under it, and the
        // coat's strength (piece_fig.z) over the satin wood; or the frame's wax. The
        // coat's roughness.
        float relief = 0.0;
        float coat = 0.0;
        float coat_rough = 0.16;
        if (mat < 0.5) {
            // The field: the baked plan, seen from above.
            vec2 uv = (p.xz + INNER) / (2.0 * INNER);
            vec4 a = texture(plan_albedo, uv);
            vec2 t = texture(plan_normal, uv).xy * 2.0 - 1.0;
            albedo = a.rgb;
            rough = a.a;
            n = normalize(vec3(t.x, sqrt(max(1.0 - dot(t, t), 0.0)), t.y));
            pieces_occ = texture(field_occ, uv).r;
            ao *= pieces_occ * wall_occlusion(p);
            #ifdef SHADOW_MANY
            if (frame_map.w > 0.0) {
                // The light that leaves the body: the albedo blurred over half the
                // radius and seen a little below the surface, at half the radius deep
                // along the view refracted into the stone (index 1.55: at a grazing
                // view it leans at most 40 degrees, 0.85 of the depth aside), so the
                // figure lies under a clear skin. The deep point stays in its own
                // square. A painted vein keeps its pigment where the light leaves
                // (pigment_of).
                float radius = frame_map.z;
                vec3 to_eye = normalize(eye.xyz - p);
                float lod = log2(max(0.5 * radius * float(textureSize(plan_albedo, 0).x) / (2.0 * INNER), 1.0));
                vec3 blur = textureLod(plan_albedo, uv, lod).rgb;
                float side = 2.0 * FIELD / params.w;
                vec2 local = mod(p.xz + FIELD, side);
                float lean = length(to_eye.xz) / 1.55;
                vec2 away = -to_eye.xz / max(length(to_eye.xz), 1e-4);
                vec2 deep_xz = p.xz + away * (0.5 * radius * lean / sqrt(1.0 - lean * lean));
                float margin = min(0.5 * radius, 0.45 * side);
                vec2 cell = p.xz - local;
                deep_xz = clamp(deep_xz, cell + margin, cell + side - margin);
                vec3 deep = textureLod(plan_albedo, (deep_xz + INNER) / (2.0 * INNER), lod).rgb;
                vec3 pigment = pigment_of(albedo, blur);
                // Each square is its own stone: within the blur's reach of its seam
                // (and on the inlay round the field) the body is the surface's own.
                float seam = min(min(local.x, local.y), side - max(local.x, local.y));
                float inside = max(abs(p.x), abs(p.z)) < FIELD ? smoothstep(0.3 * radius, 0.9 * radius, seam) : 0.0;
                body = mix(albedo, deep * pigment, inside);
                travelled = body_color(body);
                // Sparse translucent inclusions through the volume carry light further.
                float pocket = smoothstep(0.62, 0.8, noise3(p * vec3(4.0, 4.0, 6.0) + 7.3));
                sss_f = clamp(frame_map.w * (1.0 + 0.6 * pocket), 0.0, 1.0);
                sss_radius = radius * (1.0 + 0.8 * pocket);
            }
            #endif
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
            // On the end faces down runs along u alone (the lean), on the long sides along
            // v alone, blended round the corners: down along both sheared the figure into
            // diagonal streaks.
            float lean = frame_build.z * smoothstep(-0.3, 0.3, a2.x - a2.y);
            vec2 solid_uv = vec2(p.x + down * clamp(p.x, -1.0, 1.0) * lean, p.z - down * (1.0 - lean));
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
            #ifdef SHADOW_MANY
            if (frame_map.w > 0.0) {
                // The frame's body as the field's (its thin cracks are painted: they
                // keep their pigment and carry no light of their own). Light that
                // entered the top leaves lower down the rounded edge and the side,
                // each channel fading by its own reach.
                float radius = frame_map.z;
                float lod = log2(max(0.5 * radius * float(textureSize(frame_albedo, 0).x) / FRAME_SPAN, 1.0));
                vec3 blur = textureLod(frame_albedo, fuv, lod).rgb;
                vec3 pigment = pigment_of(albedo, blur);
                body = blur * pigment;
                travelled = body_color(blur) * pigment;
                sss_f = clamp(frame_map.w, 0.0, 1.0);
                sss_radius = radius;
                // It fades in over the rounded edge (no line where the top ends), in
                // the body's own color near the top, the deeper tint lower down.
                float turned = 1.0 - smoothstep(0.55, 0.98, ng.y);
                if (turned > 0.0) {
                    vec2 outward = normalize(ng.xz + vec2(1e-4));
                    vec3 top = vec3(p.x - outward.x * 0.06, FRAME_TOP + 0.006, p.z - outward.y * 0.06);
                    float depth = max(FRAME_TOP - p.y, 0.0);
                    vec3 reach = radius * (0.35 + 0.65 * travelled / max(max(travelled.r, travelled.g), max(travelled.b, 1e-4)));
                    through = turned * 0.5 * shadow_tap(top) * max(light_dir.y, 0.0) * exp(-depth / reach)
                            * mix(body, travelled, clamp(depth / radius, 0.0, 1.0));
                }
            }
            #endif
            // The wax (frame_wax): a clear coat over the smooth shape, fading in on the
            // sides as far as w says; the sides' relief softened under it, as wax fills
            // the grain.
            float sides = 1.0 - smoothstep(0.55, 0.98, ng.y);
            coat = frame_wax.x * mix(1.0, sides, frame_wax.w);
            coat_rough = frame_wax.y;
            t *= mix(1.0, frame_wax.z, sides * step(0.001, frame_wax.x));
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
            float scribe = 1.0 - smoothstep(0.5 * lw, 1.5 * lw, abs(along - BULL_START - 0.006));
            albedo = mix(albedo, edge_line.rgb, scribe * edge_line.a);
            rough = mix(rough, 0.4, scribe * edge_line.a);
            // Darker toward the underside, where the board's own shade gathers.
            ao *= mix(0.4, 1.0, smoothstep(BOTTOM, FRAME_TOP - 0.1, p.y));
        } else {
            vec3 lp = v_local;
            bool dark = v_kind.x > 0.5;
            vec4 m = dark ? dark_piece : light_piece;
            rough = m.a;
            #ifdef PIECES_WOOD
            {
                albedo = piece_wood(lp, normalize(v_normal), mod(abs(v_kind.w), 1000.0), m.rgb,
                                    3.0 * (dark ? piece_fig.y : piece_fig.x), dark, rough, relief);
                relief *= piece_fig.w;
                coat = piece_fig.z;
            }
            #else
            #ifdef PIECES_WINTER
            {
                albedo = piece_winter(lp, normalize(v_normal), normalize(eye.xyz - p), mod(abs(v_kind.w), 1000.0),
                                      m.rgb, dark ? piece_fig.y : piece_fig.x, dark, frame_map.y < -2.5, rough);
            }
            #else
            #ifdef PIECES_MINERAL
            {
                // One continuous cut through the disc, including its side. Shift
                // the stone for each piece so adjacent men have different cuts.
                float seed = mod(v_kind.w < 0.0 ? -1.0 - v_kind.w : v_kind.w, 1000.0);
                vec3 cut = lp + seed * 1.73;
                float cloud = noise3(cut * 5.5);
                float body = cloud - 0.5;
                if (frame_map.y > 2.5 && dark) {
                    // Cloudy inclusions and folded pale bands in polished green jade.
                    vec3 grain = vec3(cut.x * 1.6 + cut.z, cut.y, cut.z * 0.55);
                    float folds = noise3(grain * 7.0 + 1.8 * body);
                    float flecks = noise3(cut * 34.0);
                    float milk = smoothstep(0.20, 0.90, folds + 0.30 * body + 0.16 * (flecks - 0.5));
                    vec3 inclusion = mix(m.rgb * vec3(0.60, 0.64, 0.53),
                                         m.rgb + vec3(0.11, 0.14, 0.07), milk);
                    albedo = max(vec3(0.0), mix(m.rgb, inclusion, piece_fig.y * (1.6 + 1.7 * fract(seed * 0.382))));
                    rough += piece_fig.y * (flecks - 0.5) * 0.16;
                } else if (frame_map.y > 2.5) {
                    // Milky pockets in a warm cream body, in the board's palette: each cut
                    // its own balance of warm cream and a faint olive cloud. Texture past
                    // 0.3 adds the pale squares' thin olive-grey veins.
                    float milk = smoothstep(0.24, 0.76, cloud + 0.3 * (fract(seed * 0.618) - 0.5)
                                           + 0.16 * (noise3(cut * 15.0) - 0.5));
                    vec3 inclusion = mix(m.rgb * vec3(0.84, 0.83, 0.72),
                                         m.rgb + vec3(0.07, 0.05, 0.02), milk);
                    albedo = mix(m.rgb, inclusion, min(piece_fig.x * (0.3 + 3.7 * fract(seed * 0.382)), 1.0));
                    float wave = abs(noise3(cut * 3.5 + 0.8 * body) - 0.5);
                    float vein = 1.0 - smoothstep(0.0, 0.025 + 0.6 * fwidth(wave), wave);
                    float veins = smoothstep(0.3, 0.9, piece_fig.x) * (0.5 + fract(seed * 0.73));
                    albedo *= 1.0 - veins * vein * vec3(0.22, 0.2, 0.32);
                } else {
                    if (frame_map.y > 1.5) {
                        // A bent mineral seam crossing the broad cloudy inclusions.
                        float offset = fract(seed * 0.618) - 0.5;
                        float seam = abs(dot(lp, vec3(1.3, 0.6, 0.8)) + 0.95 * body + offset);
                        float width = max(fwidth(seam), 0.015);
                        float vein = 1.0 - smoothstep(0.018, 0.018 + width, seam);
                        body += (dark ? 0.55 : -0.8) * vein;
                    } else {
                        body += noise3(cut * 27.0) - 0.5;
                    }
                    float figure = dark ? piece_fig.y : piece_fig.x;
                    albedo = m.rgb * max(0.1, 1.0 + 2.0 * figure * body);
                    rough += 0.12 * figure * body;
                }
            }
            #else
            if (dark) {
                // Smooth satin with a faint figure, drawn out a little across the disc.
                vec3 g = lp + mod(abs(v_kind.w), 1000.0) * 3.17;
                float st = 1.0 + 6.0 * piece_fig.z;
                float w = noise3(vec3(g.x * 5.0, g.y * 5.0, g.z * 5.0 * st)) * 0.65
                        + noise3(vec3(g.x * 13.0, g.y * 13.0, g.z * 13.0 * st)) * 0.35;
                albedo = m.rgb * (1.0 + piece_fig.y * (w - 0.5));
                // The turned side, across the grain, takes the finish darker than the face:
                // the references' dark pieces have near-black sides under a lit top.
                albedo *= mix(piece_fig.w, 1.0, smoothstep(0.2, 0.6, abs(n.y)));
            } else {
                float w = noise3(lp * 24.0 + mod(abs(v_kind.w), 1000.0) * 3.17);
                albedo = m.rgb * (1.0 + piece_fig.x * (w - 0.5));
            }
            #endif
            #endif
            #endif
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
            albedo *= v_wear.y;
            rough = clamp(rough * v_wear.x, 0.05, 1.0);
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
                // A dark king's crown is the 2D piece's gold (#e9c46a, linear), a little
                // glossy as gilt; a light king's the look's crown color.
                vec3 fill = dark ? vec3(0.815, 0.552, 0.144) : crown_color.rgb;
                albedo = mix(albedo, fill, inside);
                rough = mix(rough, dark ? 0.45 : 0.7, inside);
                ao *= 1.0 - 0.35 * inside;
                // The face's edge round the deboss catches the light: a thin lighter lip.
                float lip = smoothstep(-w, w, d) * (1.0 - smoothstep(0.0, 0.005 + w, d));
                albedo *= 1.0 + 0.18 * lip * step(u, 0.6);
            }
            // Contact: the foot darkens near what it stands on, the field (its height 0,
            // so a lifted piece doesn't) or, for a king and a piece on the table, its own
            // foot; a stack's lower disc darkens under the upper.
            float foot = p.y - lp.y * (8.0 / params.w);
            float h = v_kind.y > 0.25 || foot < -0.5 ? lp.y : p.y;
            ao *= mix(0.6, 1.0, smoothstep(0.0, 0.035, h));
            if (v_kind.z > 1.5) ao *= mix(1.0, 0.65, smoothstep(HEIGHT - 0.05, HEIGHT, lp.y));
        }

        // The coat lies smooth over the shape; the wood under it takes the relief: a
        // piece's shape as worked out above, the frame's mesh normal.
        // Derivatives outside the branch: a quad straddling a piece's edge stays defined.
        bool on_frame = mat > 0.5 && mat < 1.5;
        vec3 n_coat = on_frame ? ng : n;
        vec3 cu = dFdx(n_coat);
        vec3 cv = dFdy(n_coat);
        vec3 n_bump = bumped(n, p, relief);
        if (relief != 0.0) n = n_bump;
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
        // Under a varnish the wood's own sheen is the softer one (the coat's below).
        spec *= 1.0 - 0.6 * coat;
        float wrap = 0.2;
        float diff = clamp((nol + wrap) / (1.0 + wrap), 0.0, 1.0) / (1.0 + wrap);
        // Filament's micro-shadowing from the occlusion, on the field only: on the
        // pieces' grooves, tiny triangles near the terminator turned it into specks. Not
        // from the pieces' occlusion of the field: the shadow map shades where they block
        // the sun, and a low sun darkened a halo on their lit side.
        if (mat > 1.5 && disc_n.x > 0.5) ao *= discs_occlusion(p);
        float micro = clamp(nl * inversesqrt(1.0 - min(ao / max(pieces_occ, 0.01), 0.9999)), 0.0, 1.0);
        micro = nol > 0.0 && mat < 0.5 ? micro * micro : 1.0;
        // A piece's lip and groove are finer than a shadow texel: its lookups start a
        // little toward the light, so they leave them to the baked occlusion.
        float center = shadow(mat > 1.5 ? p + l * 0.03 : p, n);
        float vis = center * micro;
        vec3 light = light_color.rgb * light_dir.w;
        vec3 direct;
        // The photograph's light: diffuse from the harmonics, specular from them along
        // the reflection, through the DFG fit, under the occlusion.
        vec3 irr = sh_eval(n) * params.z;
        vec3 env = sh_eval(reflect(-v, n)) * params.z;
        float spec_ao = clamp(pow(nov + ao, exp2(-16.0 * a - 1.0)) - 1.0 + ao, 0.0, 1.0);
        vec3 ambient;
        #ifdef SHADOW_MANY
        if (sss_f > 0.0) {
            // The board's scattering: a fraction of the diffuse leaves the body in its
            // color, lit over the geometric normal (the relief softened) with the
            // surface's wrap, so lit flat stone keeps its brightness. What left near where it entered keeps the body's
            // color; what the spread brought from farther (scatter_spread's excess over
            // the shadow here) and what came through the frame's top takes the deeper
            // tint of the longer path. Only deep occlusion darkens it (a piece's contact,
            // a crack's inside): the open field's, 0.85 or so, would dim the lit stone.
            vec3 k = 0.35 + 0.65 * travelled / max(max(travelled.r, travelled.g), max(travelled.b, 1e-4));
            vec3 spread = scatter_spread(p, ng, sss_radius, k, center);
            float flat_diff = clamp((dot(ng, l) + 0.2) / 1.2, 0.0, 1.0) / 1.2;
            vec3 body_light = (flat_diff * (center * body + max(spread - center, 0.0) * travelled) + through)
                            * clamp((ao - 0.45) / 0.4, 0.0, 1.0);
            direct = ((albedo * (diff * (1.0 - sss_f) / PI) + spec) * vis + sss_f * body_light / PI) * light;
            ambient = mix(albedo * irr, body * sh_eval(ng) * params.z, sss_f) * ao
                    + env * env_brdf(f0, rough, nov) * spec_ao;
        } else
        #endif
        {
            direct = (albedo * ((diff + v_scatter) / PI) + spec) * light * vis;
            ambient = albedo * irr * ao + env * env_brdf(f0, rough, nov) * spec_ao;
        }
        if (coat > 0.0) {
            // The varnish or the frame's wax: a thin clear coat (index 1.5) over the smooth
            // shape, its own sharper lobe; what it reflects doesn't reach the wood under it.
            float nlc = clamp(dot(n_coat, l), 0.0, 1.0);
            float novc = max(dot(n_coat, v), 1e-4);
            float nohc = clamp(dot(n_coat, hv), 0.0, 1.0);
            // A piece's step spreads the coat's normals too; the frame's relief is under it.
            float ac = coat_rough * coat_rough;
            ac = sqrt(clamp(ac * ac + min(0.3 * (dot(cu, cu) + dot(cv, cv)) + (on_frame ? 0.0 : top_var), 0.3), 0.0, 1.0));
            float fc = coat * f_schlick(vec3(0.04), voh).x;
            float fe = coat * env_brdf(vec3(0.04), coat_rough, novc).x;
            vec3 spec_c = vec3(d_ggx(nohc, ac) * v_smith(novc, nlc, ac) * fc * nlc);
            direct = direct * (1.0 - fc) + spec_c * light * vis;
            ambient = ambient * (1.0 - fe) + sh_eval(reflect(-v, n_coat)) * params.z * fe * spec_ao;
        }
        if (mat > 1.5) {
            // The lit board's light on a piece's side: what faces down and out sees the
            // board round it, lit by the key from above.
            float down = clamp(0.5 - 0.5 * n.y, 0.0, 1.0);
            ambient += albedo * bounce.rgb * (light * l.y / PI) * bounce.a * down * ao;
        }
        vec3 color = (direct + ambient) * params.x;
    #ifdef HDR_OUT
        // Into the scenic views' HDR target: the light with tonemap's toe alone taken off.
        float least = min(color.r, min(color.g, color.b));
        result = vec4(color - (least < 0.04 ? least - 12.5 * least * least : 0.02), v_alpha);
    #else
        color = tonemap(color) * vec3(1.02, 1.0, 0.97);
        // A win dims the board and the pieces but the winning one, as the flat board's
        // black fill over them does.
        float dim = abs(v_kind.w) >= 1000.0 ? 0.0 : screen.z;
        result = vec4(to_srgb(color) * (1.0 - dim), v_alpha);
        // The lookout's drained piece (a seed below 0): its color drained, a little
        // darker, and tinted red, as the flat board's (src/app/draw.goose's `marked`).
        if (v_kind.w < 0.0) {
            float grey = dot(result.rgb, vec3(0.2126, 0.7152, 0.0722)) * 0.66;
            result.rgb = min(vec3((grey - 0.5) * 0.85 + 0.5) * vec3(1.45, 0.68, 0.62), 1.0);
        }
    #endif
    }
    """;

// The pieces' occlusion of the field into its map (render3d::occlusion), over the plan's
// extent as the plan is laid (BAKE_FRAG's mode 0), OCC_SIZE texels a side: each piece
// over the 5 × 5 squares round, where it is, as a cylinder, the share of the cosine-weighted sky its
// angle across and its height take, times HALO (its strength), the gap to it over
// HALO_REACH (under 1 a tighter halo). Only the texels whose squares changed are drawn
// again (a scissor), so a moving piece redraws a few squares' worth, not the field.
let OCC_FRAG = """
    layout(location = 0) out vec4 result;
    // Two a square: the top of what stands over it, its foot, its radius, 1 if a piece;
    // then its middle's x and z, wherever over the square it is (a moving piece), and the
    // light tuner's halo and reach for it (0: HALO's, HALO_REACH's).
    layout(std430, set = 2, binding = 0) readonly buffer Squares { vec4 squares[]; };
    const float OCC_SIZE = 512.0;   // render3d::OCC_SIZE
    const float HALO = 1.0;
    const float HALO_REACH = 1.0;
    void main() {
        vec2 xz = gl_FragCoord.xy / OCC_SIZE * (2.0 * INNER) - INNER;
        float vis = 1.0;
        int n = int(params.w + 0.5);
        float u = 2.0 * FIELD / params.w;
        ivec2 c = ivec2(floor((xz + FIELD) / u));
        // Two squares round (render3d::OCC_REACH): a piece at its square's edge darkens
        // the field more than a square past it.
        for (int dy = -2; dy <= 2; dy++) {
            for (int dx = -2; dx <= 2; dx++) {
                ivec2 q = c + ivec2(dx, dy);
                if (q.x < 0 || q.y < 0 || q.x >= n || q.y >= n) continue;
                vec4 s = squares[2 * (q.y * n + q.x)];
                if (s.w < 0.5) continue;
                vec4 o = squares[2 * (q.y * n + q.x) + 1];
                float rho = length(xz - o.xy);
                float r = s.z;
                float halo = o.z > 0.0 ? o.z : HALO;
                float reach = o.w > 0.0 ? o.w : HALO_REACH;
                float occ;
                if (rho > r) {
                    float gap = (rho - r) / reach + 0.01;
                    float top = s.x * s.x / (s.x * s.x + gap * gap);
                    float foot = s.y * s.y / (s.y * s.y + gap * gap);
                    occ = asin(r / rho) / PI * (top - foot);
                } else {
                    float foot = s.y * s.y / (s.y * s.y + r * r);
                    occ = (0.5 + 0.45 * (1.0 - rho / r)) * (1.0 - foot);
                }
                vis *= 1.0 - halo * occ;
            }
        }
        result = vec4(vis, 0.0, 0.0, 1.0);
    }
    """;

// The table under the board (mesh::table), one mesh at its place, its top and its base:
// its world position, normal, where along its profile (uv.y), and its material.
let TABLE_VERT = """
    layout(location = 0) in vec3 a_pos;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    layout(location = 3) in vec2 a_extra;          // occlusion, material
    layout(location = 0) out vec3 v_world;
    layout(location = 1) out vec3 v_normal;
    layout(location = 2) out vec2 v_uv;
    layout(location = 3) out float v_ao;
    layout(location = 4) out float v_mat;
    void main() {
        vec3 pos = a_pos;
        v_world = pos;
        v_normal = a_normal;
        v_uv = a_uv;
        v_ao = a_extra.x;
        v_mat = a_extra.y;
        gl_Position = view_proj * vec4(pos, 1.0);
    }
    """;

// The table lit as the board is (LIT_FRAG's light, its functions repeated here till the
// two share them), its wood baked (BAKE_FRAG's mode 2) over its top seen from above. The
// board's and its pieces' shadow on it come from the key's shadow map (SHADOW_FN) and the
// board's outline, its occlusion near the board's foot from the outline (no catcher over
// it); its light falls off away from the board (Table.pool), as a lamp's or a window's
// would.
// TABLE_FRAG's inputs and textures, before LIGHT_FN, which reads the tree's map.
let TABLE_HEAD = """
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in float v_ao;
    layout(location = 4) in float v_mat;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D table_albedo;
    layout(set = 2, binding = 1) uniform sampler2D table_normal;
    // The board's frame map, its last mip the frame's mean color, for its reflection.
    layout(set = 2, binding = 2) uniform sampler2D frame_albedo;
    // The wear's tile (BAKE_FRAG's wear_at): scratches, crazing, dents; the scratches'
    // normal's x and z, the dents'.
    layout(set = 2, binding = 3) uniform sampler2D wear_map;
    layout(set = 2, binding = 4) uniform sampler2D wear_normal;
    layout(set = 2, binding = 5) uniform sampler2D tree_map;
    // The key light's shadow map (SHADOW_FN): the board and the pieces on it.
    layout(set = 2, binding = 6) uniform sampler2DShadow shadow_map;
    // The table's own map in the room (TABLE_MAP_FN).
    layout(set = 2, binding = 7) uniform sampler2DShadow table_depth;
    #ifdef TABLE_ROOM
    #ifndef NO_SSAO
    // The room's ambient occlusion at half size (SSAO_FN).
    layout(set = 2, binding = 8) uniform sampler2D ssao_map;
    #endif
    #endif
    // tables::Table's. pool: x the light's reach round the board (world units), y how dim
    // it is beyond, z how dark the edge's underside goes, w how strong the board's
    // reflection; coat: x the polish's roughness on the edge (the top's is baked), y how
    // strong it is, z how far it follows the wood's relief, w how broad the key light's
    // highlight in it (a roughness); polish: x how much its roughness varies, y its
    // strength, z the blotches' size (world units), w how much the wear shows in it;
    // worn: the rim's wear, x how much, y how wide. The pieces lying on it are FRAME's
    // discs. shape: x the top's radius (world units), y the floor's height, zw in the room
    // (TABLE_ROOM) the sine and cosine of the table's turn under the board (its mesh turned
    // with it, render3d::Gpu.table_turn), its top's figure read turned back. table_map: the
    // table's own map's rows (TABLE_MAP_FN). In the room with its light baked (TABLE_ROOM,
    // render3d::TableBlock): room_light the probes on the table's axis, four heights of
    // three colours' constant and direction; room_mix x 1 there, y the harmonics the room
    // keeps, z the room's exposure over the board's, w the shade's floor of the key kept;
    // room_shade the room's even bounce kept, w a metre; ssao the room's ambient occlusion
    // (SSAO_FN).
    layout(set = 3, binding = 1) uniform Table { vec4 pool; vec4 coat; vec4 polish; vec4 worn; vec4 shape; vec4 table_map[4];
                                                 vec4 room_light[12]; vec4 room_mix; vec4 room_shade; vec4 ssao; };
    """;

// The table's own shadow from its map (render3d::table_map), which TABLE_FRAG and ROOM_FRAG
// share, after their heads (table_depth, the block's table_map): q's place in the map by
// the rows 0 to 2, row 3's x 1 where the map is drawn; a 5 × 5 texel box in 9 taps, as
// SHADOW_FN's. 1 where the map isn't drawn or doesn't reach.
let TABLE_MAP_FN = """
    float table_map_at(vec3 q) {
        if (table_map[3].x < 0.5) return 1.0;
        vec4 h = vec4(q, 1.0);
        vec3 s = vec3(dot(table_map[0], h), dot(table_map[1], h), dot(table_map[2], h));
        if (abs(s.x) > 0.995 || abs(s.y) > 0.995) return 1.0;
        vec2 size = vec2(textureSize(table_depth, 0));
        vec2 uv = vec2(s.x * 0.5 + 0.5, 0.5 - s.y * 0.5) * size;
        float z = min(s.z, 0.9999);
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
                sum += w0[i] * w1[j] * texture(table_depth, vec3(base + vec2(u[i], v[j]), z));
            }
        }
        return sum * (1.0 / 144.0);
    }
    """;

let TABLE_FRAG = """
    // mesh.goose's (test/model3d/geometry checks them): TABLE_MAP_R the half side its
    // wood's map covers whatever the top's radius (the 1.05 m top's).
    const float TABLE_MAP_R = 16.0;
    const float TABLE_TOP = -0.703;
    const float TABLE_Z = -4.5;
    const float SIDE_STREAK = 0.008;   // how far the sides' figure is drawn out (map units)
    // The top's underside under the frieze, and how far in the frieze is set
    // (mesh::table_profile's, with tables::FLAME's edge); the column's mean radius.
    const float FRIEZE_FOOT = -4.043;
    const float FRIEZE_IN = 1.4;
    const float COLUMN_R = 2.3;
    const float WEAR_TILE = 2.0;       // model3d::WEAR_TILE
    // The wear's second layer: its tile turned by 0.5 radians (cos, sin) and 1 / 0.73
    // times as large, so the two never repeat together.
    const vec2 TURN = vec2(0.87758, 0.47943);
    const float GROW = 0.73;

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
    // A vector in the second layer's tile turned back into the world's.
    vec2 turn_back(vec2 v) { return vec2(TURN.x * v.x + TURN.y * v.y, TURN.x * v.y - TURN.y * v.x); }

    #ifdef TABLE_ROOM
    // The room's baked light round the table at height y for the normal n (world), over pi:
    // its four samples on the table's axis 0.15 m and then 0.3 m apart up from the floor,
    // straight between them, each colour a constant and a direction; with the harmonics and
    // the even bounce the room keeps, at the room's exposure under the top (the base, the
    // frieze, which stand in the room) and the board's over it (the top and its board, as
    // tuned in the game: the room's lifts their shade grey and drowns the sun's dapple).
    vec3 room_light_at(float y, vec3 n, vec3 harmonics) {
        float k = clamp(((y - shape.y) / room_shade.w - 0.15) / 0.3, 0.0, 3.0);
        int i = int(min(floor(k), 2.0));
        float f = k - float(i);
        vec3 a = vec3(room_light[3 * i].x + dot(room_light[3 * i].yzw, n), room_light[3 * i + 1].x + dot(room_light[3 * i + 1].yzw, n),
                      room_light[3 * i + 2].x + dot(room_light[3 * i + 2].yzw, n));
        int j = i + 1;
        vec3 b = vec3(room_light[3 * j].x + dot(room_light[3 * j].yzw, n), room_light[3 * j + 1].x + dot(room_light[3 * j + 1].yzw, n),
                      room_light[3 * j + 2].x + dot(room_light[3 * j + 2].yzw, n));
        float over = smoothstep(TABLE_TOP - 0.5, TABLE_TOP, y);
        return (max(mix(a, b, f), vec3(0.0)) + harmonics * room_mix.y + room_shade.rgb) * mix(room_mix.z, 1.0, over);
    }
    #endif

    vec3 tonemap(vec3 c) {
    #ifdef TOE_SWITCH
        c = toe_off(c, toe.y);
    #else
        float x = min(c.r, min(c.g, c.b));
        float offset = x < 0.04 ? x - 12.5 * x * x : 0.02;
        c -= offset;
    #endif
        float peak = max(c.r, max(c.g, c.b));
        const float start = 0.76;
        if (peak < start) return c;
        const float d = 1.0 - start;
        float np = 1.0 - d * d / (peak + d - start);
        c *= np / peak;
        float g = 1.0 - 1.0 / (0.15 * (peak - np) + 1.0);
        return mix(c, vec3(np), g);
    }

    float round_box(vec2 p, vec2 b, float r) {
        vec2 q = abs(p) - b + r;
        return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
    }

    // The board's shadow on the table from the key light: its rounded outline swept
    // along the light from its foot to its top's height, the edge softer the farther up
    // it was cast from.
    float board_shadow(vec2 p) {
        vec3 l = light_dir.xyz;
        vec2 off = -l.xz / max(l.y, 0.05) * (FRAME_TOP - TABLE_TOP);
        vec2 b = vec2(INNER + FRAME_W);
        float lit = 1.0;
        for (int i = 0; i <= 4; i++) {
            float t = float(i) * 0.25;
            float d = round_box(p - off * t, b, FRAME_W);
            float w = 0.04 + 0.35 * t;
            lit = min(lit, smoothstep(-w, w, d));
        }
        return lit;
    }

    // The pieces' shadow on the table from the key light, and how much of the sky they hide
    // round their feet: each a disc swept along the light from its foot's height to its
    // top's, its shadow a capsule, softer the higher it was cast from.
    vec2 discs_shadow(vec2 p) {
        vec3 l = light_dir.xyz;
        vec2 off = -l.xz / max(l.y, 0.05);
        float r = disc_n.y;
        float lit = 1.0;
        float occ = 1.0;
        int n = int(disc_n.x);
        for (int i = 0; i < 48; i++) {
            if (i >= n) break;
            vec4 c = discs[i];
            vec2 a = c.xy + off * c.z;
            vec2 ba = off * (c.w - c.z);
            vec2 pa = p - a;
            float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
            float d = length(pa - ba * h) - r;
            float w = 0.015 + 0.1 * c.w;
            lit = min(lit, smoothstep(-w, w, d));
            if (c.z < 0.01) occ = min(occ, mix(0.45, 1.0, smoothstep(-0.02, 0.35 * r, length(p - c.xy) - r)));
        }
        return vec2(lit, occ);
    }

    // The board's side seen along the ray from p (on the table) in direction d (going up):
    // rgb its color lit, a how much of it (0 the ray passes it), its edge softer the
    // farther the ray went (the polish blurs what is far). The board is its rounded outline
    // stood up from the table to its top.
    vec4 board_seen(vec3 p, vec3 d, vec3 l) {
        vec2 b = vec2(INNER + FRAME_W);
        float across = length(d.xz);
        if (across < 1e-4) return vec4(0.0);
        float t = 0.0;
        float dist = 0.0;
        for (int i = 0; i < 10; i++) {
            dist = round_box(p.xz + d.xz * t, b, FRAME_W);
            if (dist < 0.002) break;
            t += dist / across;
        }
        float y = p.y + d.y * t;
        float h = FRAME_TOP - TABLE_TOP;
        float blur = 0.02 + 0.06 * t;
        float hit = (1.0 - smoothstep(0.0, blur, dist)) * (1.0 - smoothstep(FRAME_TOP - blur, FRAME_TOP + blur, y));
        if (hit <= 0.0) return vec4(0.0);
        vec2 q = p.xz + d.xz * t;
        vec2 e = vec2(0.01, 0.0);
        vec2 g = vec2(round_box(q + e.xy, b, FRAME_W) - round_box(q - e.xy, b, FRAME_W),
                      round_box(q + e.yx, b, FRAME_W) - round_box(q - e.yx, b, FRAME_W));
        vec3 ns = normalize(vec3(g.x, 0.0, g.y));
        vec3 albedo = textureLod(frame_albedo, vec2(0.5), 20.0).rgb;
        float ao = mix(0.35, 1.0, smoothstep(0.0, h, y - TABLE_TOP));
        float wrap = 0.2;
        float diff = clamp((dot(ns, l) + wrap) / (1.0 + wrap), 0.0, 1.0) / (1.0 + wrap);
        vec3 c = albedo * (diff / PI * light_color.rgb * light_dir.w + sh_eval(ns) * params.z * ao);
        return vec4(c, hit);
    }

    // The key kept off the base by the top over it, solid (the slab, and the frieze at
    // its foot), and off a leg by the column, each edge softer the farther it was cast
    // from.
    float under_top(vec3 p, vec3 l) {
        vec2 mid = vec2(0.0, TABLE_Z);
        float ly = max(l.y, 0.05);
        float t0 = (TABLE_TOP - 0.9 - p.y) / ly;
        float t1 = (FRIEZE_FOOT - p.y) / ly;
        float w0 = 0.1 + 2.0 * room.z * t0;
        float w1 = 0.1 + 2.0 * room.z * t1;
        float lit = min(smoothstep(-w0, w0, length(p.xz + l.xz * t0 - mid) - shape.x),
                        smoothstep(-w1, w1, length(p.xz + l.xz * t1 - mid) - (shape.x - FRIEZE_IN)));
        vec2 a = p.xz - mid;
        if (length(a) < COLUMN_R + 1.0) return lit;
        vec2 ba = l.xz * t1;
        float h = clamp(-dot(a, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
        float wc = 0.1 + 2.0 * room.z * h * t1;
        return min(lit, smoothstep(-wc, wc, length(a + ba * h) - COLUMN_R));
    }

    void main() {
        vec3 p = v_world;
        vec3 n = normalize(v_normal);
        // The top seen from above; the edge, the frieze and what is under them unrolled,
        // their grain running round the table (a bent rim's) as the profile goes down
        // across it, a whole number of the map's repeats round, so it meets itself. The
        // base (mesh::MAT_TABLE_BASE) cut from the same wood, its grain along the column
        // and the legs (its v).
        bool base = v_mat > 3.5;
        bool top = v_normal.y > 0.999 && p.y > TABLE_TOP - 0.01;
        vec2 out_dir = p.xz - vec2(0.0, TABLE_Z);
        float from_mid = max(length(out_dir), 1e-3);
        vec2 uv = top ? out_dir / (2.0 * TABLE_MAP_R) + 0.5
                      : vec2(0.3 + (v_uv.y - TABLE_MAP_R) / (2.0 * TABLE_MAP_R), v_uv.x / (2.0 * PI * from_mid) * 3.0);
    #ifdef TABLE_ROOM
        if (top) uv = vec2(shape.w * out_dir.x + shape.z * out_dir.y, shape.w * out_dir.y - shape.z * out_dir.x) / (2.0 * TABLE_MAP_R) + 0.5;
    #endif
        if (base) uv = vec2(0.2, 0.15) + v_uv / (2.0 * TABLE_MAP_R);
        // On the sides and the base the figure is drawn out along the grain (their v)
        // into straight streaks, as an edge's and a frieze's wood is: the filter's
        // footprint lengthened along it, the anisotropic filter blurring that way only.
        vec2 gx = dFdx(uv);
        vec2 gy = dFdy(uv);
        if (!top) {
            gx.y = sign(gx.y + 1e-9) * max(abs(gx.y), SIDE_STREAK);
            gy.y = sign(gy.y + 1e-9) * max(abs(gy.y), SIDE_STREAK);
        }
        vec4 a = textureGrad(table_albedo, uv, gx, gy);
        vec4 tn = textureGrad(table_normal, uv, gx, gy);
        vec3 albedo = a.rgb;
        float rough = a.a;
        float ao = clamp(v_ao, 0.0, 1.0);

        // The top's wear, finer than its map: the wear's tile laid twice, the second turned
        // and larger, where the map's patches (tn.z) say. Scratches and dents where the top
        // was used, crazing where it was left alone; the dents anywhere.
        vec2 wa_uv = p.xz / WEAR_TILE + 0.13;
        vec2 wq = p.xz * (GROW / WEAR_TILE);
        vec2 wb_uv = vec2(TURN.x * wq.x - TURN.y * wq.y, TURN.y * wq.x + TURN.x * wq.y) + vec2(0.41, 0.77);
        vec4 wa = texture(wear_map, wa_uv);
        vec4 wb = texture(wear_map, wb_uv);
        vec4 na = texture(wear_normal, wa_uv) * 2.0 - 1.0;
        vec4 nb = texture(wear_normal, wb_uv) * 2.0 - 1.0;
        nb = vec4(turn_back(nb.xy), turn_back(nb.zw)) * GROW;
        float on_top = top ? 1.0 : 0.0;
        float used = smoothstep(0.3, 0.6, tn.z) * on_top;
        float left = (1.0 - smoothstep(0.3, 0.45, tn.z)) * on_top;
        float scratch = max(wa.x, wb.x) * used;
        float craze = max(wa.y, wb.y) * left;
        float dent = max(wa.z, wb.z) * on_top;
        vec2 bump = ((na.xy + nb.xy) * used + (na.zw + nb.zw)) * on_top;
        albedo *= (1.0 + 0.5 * scratch) * (1.0 - 0.35 * craze);
        rough += 0.25 * scratch + 0.15 * craze + 0.1 * dent;
        ao *= 1.0 - 0.15 * (craze + dent);
        // The board standing on it hides the sky near its foot.
        float foot = round_box(p.xz, vec2(INNER + FRAME_W), FRAME_W);
        float on_table = step(TABLE_TOP - 0.01, p.y);
        ao *= 1.0 - 0.6 * (1.0 - smoothstep(0.0, 1.4, foot)) * on_table;
        // The crease where it meets the table, tight: the sky and the polish's reflection
        // (spec_ao, the board's side in it too) dim at the foot.
        ao *= mix(1.0, mix(0.35, 1.0, smoothstep(0.0, 0.12, foot)), on_table);
        float top_var = 0.0;
        // The top takes the baked normal; the edge and what is under keep the mesh's.
        if (top) {
            vec2 t = tn.xy * 2.0 - 1.0;
            float r = length(vec3(t, tn.w));
            top_var = max((1.0 - r) / max(r, 1e-3), 0.0);
    #ifdef TABLE_ROOM
            t = vec2(shape.w * t.x - shape.z * t.y, shape.z * t.x + shape.w * t.y);
    #endif
            n = normalize(vec3(t.x + bump.x, sqrt(max(1.0 - dot(t, t), 0.0)), t.y + bump.y));
        } else if (!base) {
            // The edge and the apron in the shade of the top, darker the lower.
            ao *= mix(1.0 - pool.z, 1.0, smoothstep(TABLE_TOP - 0.6, TABLE_TOP, p.y));
        } else {
            // The base sees the sky round the top: the share of it the top hides, the
            // cone up to its rim, more for what faces up.
            float e = (TABLE_TOP - p.y) / max(shape.x - from_mid, 0.5);
            float hidden_sky = 1.0 / (1.0 + e * e);
            ao *= 1.0 - (1.0 - pool.z) * hidden_sky * (0.6 + 0.4 * max(n.y, 0.0));
        }

        // Two layers: the wood under the polish, lit with its grain's relief, and the
        // polish over it, smooth as the mesh is, which takes the key light's highlight and
        // the room's (or the board's) reflection.
        vec3 v = normalize(eye.xyz - p);
        vec3 l = light_dir.xyz;
        // The polish lies over the wood's figure as far as coat.z says (sanded), and over
        // the dents and scratches in it as far as polish.w: they catch the light.
        vec3 vn = normalize(v_normal);
        vec3 nc = top ? normalize(mix(vn, n, coat.z) + polish.w * vec3(bump.x, 0.0, bump.y)) : vn;
        float nol = dot(n, l);
        float wrap = 0.2;
        float diff = clamp((nol + wrap) / (1.0 + wrap), 0.0, 1.0) / (1.0 + wrap);
        // The light's pool round the board.
        float d = length(p.xz) / max(pool.x, 1e-3);
        float lit = mix(pool.y, 1.0, exp(-d * d));
        vec3 light = light_color.rgb * light_dir.w * lit;
        float vis = 1.0;
        float hidden = 1.0;
        if (p.y > TABLE_TOP - 0.01) {
            // The board's and its pieces' shadow from the map, crisp, where the point is on
            // it; the board's outline swept along the light past it and for the far
            // edge's softness. The table isn't in the map, so the point is lifted only
            // a little.
            vis = min(map_shadow_at(p + vec3(0.0, 0.002, 0.0)), board_shadow(p.xz));
            vec2 ds = discs_shadow(p.xz);
            vis *= ds.x;
            ao *= ds.y;
            hidden = vis;
            vis = mix(1.0, vis, room.x);
        }
        // Diffuse and the polish share the same ray through the windows and tree.
        float open = window_open(p);
        float pattern = room.y <= 0.0 ? 1.0 : mix(1.0 - room.y, 1.0, open);
        float sun_in = pattern;
        if (table_map[3].x > 0.5) {
            // In the room the table's own map shades all but the top: the base and the
            // frieze under the top, the legs one another; the highlight takes the sun only
            // where it comes through the window (window_open), as the room's does.
            float own = top ? 1.0 : table_map_at(p + vn * (0.03 + 0.1 * (1.0 - clamp(dot(vn, l), 0.0, 1.0))));
            pattern *= own;
            sun_in = open * own;
        #ifdef TABLE_ROOM
            // With the room's light baked, the shade's floor of the key only as far as
            // room_mix.w keeps it; the table's own shadow takes the sun alone, as the bars'.
            pattern = mix(sun_in, mix(1.0 - room.y, 1.0, sun_in), room_mix.w);
        #endif
        } else if (base) {
            pattern *= under_top(p, l);
            sun_in = pattern;
        }
        vis *= pattern;
        // A broad key's shadow is fainter (room.x) for the wood's light, but the key's own
        // image in the polish is hidden wherever the board or a piece hides the key: let
        // through, its sheen showed under the board, which then floated.
        float spec_vis = hidden * sun_in;
        vec3 irr = sh_eval(n) * params.z * mix(1.0, lit, 0.5);
    #ifdef TABLE_ROOM
        irr = room_light_at(p.y, n, sh_eval(n) * params.z);
        // The room's screen occlusion where it finds more than the table's own terms (the
        // board's foot, the top over the base) know.
        float screen_ao = ssao_at(p);
        ao = min(ao, ssao_kept(screen_ao));
    #endif
        vec3 wood = albedo * (diff / PI * light * vis + irr * ao);

        float nov = max(dot(nc, v), 1e-4);
        float nl = clamp(dot(nc, l), 0.0, 1.0);
        vec3 hv = normalize(v + l);
        float noh = clamp(dot(nc, hv), 0.0, 1.0);
        float voh = clamp(dot(v, hv), 0.0, 1.0);
        vec3 du = dFdx(nc);
        vec3 dv = dFdy(nc);
        float variance = 0.15 * (dot(du, du) + dot(dv, dv));
        // Old varnish is blotchy: thinner here, rougher and duller, thicker there, by a
        // noise polish.z across. The rim, which hands wore, duller still, down its edge.
        vec2 bq = p.xz / max(polish.z, 0.1);
        float blot = 0.65 * vnoise(bq) + 0.35 * vnoise(bq * 2.03 + 5.1) - 0.5;
        float rim = worn.x * (top ? smoothstep(shape.x - worn.y, shape.x - 0.05, from_mid)
                                  : smoothstep(TABLE_TOP - 0.5, TABLE_TOP, p.y));
        float cr = (top ? rough + 0.3 * polish.w * scratch : coat.x + 0.25 * polish.w * rim)
                 * (1.0 + 2.0 * polish.x * blot);
        float strength = coat.y * clamp(1.0 - 2.0 * polish.y * blot, 0.0, 2.0) * (1.0 - 0.6 * polish.w * rim);
        float ar = cr * cr;
        ar = sqrt(clamp(ar * ar + min(2.0 * variance + 0.3 * top_var, 0.3), 0.0, 1.0));
        ar = max(ar, 0.0079);
        vec3 f0 = vec3(0.04);
        // The key light is a window, not a point: its highlight in the polish is as broad
        // as coat.w's roughness, not the sun's pinpoint.
        float ak = max(ar, coat.w * coat.w);
        vec3 spec = d_ggx(noh, ak) * v_smith(nov, nl, ak) * f_schlick(f0, voh) * nl * light * spec_vis;
        vec3 r = reflect(-v, nc);
        vec3 env = sh_eval(r) * params.z * mix(1.0, lit, 0.5);
    #ifdef TABLE_ROOM
        // In the room the polish sees the room's surfaces: the light on them toward r by
        // their mean albedo (0.2), as ROOM_FRAG's rough reflections take it.
        env = 0.2 * room_light_at(p.y, r, sh_eval(r) * params.z);
    #endif
        // Near the board the polish shows the board's side in place of the room.
        if (top && r.y > 0.0) {
            vec4 side = board_seen(p, r, l);
            env = mix(env, side.rgb * pool.w, side.a);
        }
        float spec_ao = clamp(pow(nov + ao, exp2(-16.0 * ar - 1.0)) - 1.0 + ao, 0.0, 1.0);
        vec3 fc = env_brdf(f0, sqrt(ar), nov) * strength;
        vec3 color = (wood * (1.0 - fc) + spec * strength + env * fc * spec_ao) * params.x;
    #ifdef LINEAR_OUT
        // In the floor's mirror (shaders::MIRROR_PASS): the light itself, as the room's there,
        // before the board's tonemap.
        float peak = max(color.r, max(color.g, color.b));
        result = vec4(peak > 16.0 ? color * (16.0 / peak) : color, 1.0);
    #else
    #ifdef HDR_OUT
        // Into the scenic views' HDR target: the light with tonemap's toe alone taken off.
        float least = min(color.r, min(color.g, color.b));
        result = vec4(color - (least < 0.04 ? least - 12.5 * least * least : 0.02), 1.0);
    #else
        color = tonemap(color) * vec3(1.02, 1.0, 0.97);
        result = vec4(to_srgb(color) * (1.0 - screen.z), 1.0);
    #ifdef TABLE_ROOM
    #ifndef NO_SSAO
        if (ssao.y > 0.5 && ssao.y < 2.5) result = vec4(vec3(ssao.y > 1.5 ? ao : screen_ao), 1.0);
    #endif
    #endif
    #endif
    #endif
    }
    """;

// The room round the table (model3d::surfaces): the floor, the panelling, the wallpaper,
// one mesh, its world position, normal, uv (the floor's u and v in the room, or a piece's
// place in the wall's field), occlusion and material. The room's mesh is built in its own
// frame (u, height, v; surfaces.goose) and turned into the world here.
let ROOM_VERT = """
    layout(location = 0) in vec3 a_pos;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    layout(location = 3) in vec2 a_extra;          // occlusion, material
    layout(location = 4) in vec2 a_corner;         // its place in the corners' map
    layout(location = 5) in vec2 a_box;            // its chart's first and last texel there
    layout(location = 0) out vec3 v_world;
    layout(location = 1) out vec3 v_normal;
    layout(location = 2) out vec2 v_uv;
    layout(location = 3) out vec2 v_extra;
    layout(location = 4) out vec3 v_local;
    layout(location = 5) out vec2 v_corner;
    layout(location = 6) flat out vec2 v_box;
    vec3 turned(vec3 a) {
        vec2 xz = room_axes.xy * a.x + room_axes.zw * a.z;
        return vec3(xz.x, a.y, xz.y);
    }
    void main() {
        vec3 pos = turned(a_pos);
        v_world = pos;
        v_normal = turned(a_normal);
        v_uv = a_uv;
        v_extra = a_extra;
        v_local = a_pos;
        v_corner = a_corner;
        v_box = a_box;
        gl_Position = view_proj * vec4(pos, 1.0);
    }
    """;

// ROOM_FRAG's inputs, textures and block, before LIGHT_FN, which reads the tree's map and,
// with SHELL_WINDOWS, the shell's windows and the lace's shadow.
let SHELL_WINDOWS = "#define SHELL_WINDOWS 1\n";
let ROOM_HEAD = """
    #ifdef MIRROR_CHEAP
    // The floor's cheap mirror world (MIRROR_CHEAP_MAIN): the room's mesh, or with
    // CHEAP_TABLE the table's (TABLE_VERT), and the few textures it reads: the tree's and
    // the lace's maps, the baked light, the corners' shade, and the surfaces' own maps
    // whose last mip gives their mean colour (the panelling's oak, or the table's wood;
    // the paper's mask, the plaster's tone, the sills' stone).
    #ifdef CHEAP_TABLE
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in float v_ao;
    layout(location = 4) in float v_mat;
    #else
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in vec2 v_extra;
    layout(location = 4) in vec3 v_local;
    layout(location = 5) in vec2 v_corner;
    layout(location = 6) flat in vec2 v_box;
    #endif
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D tree_map;
    layout(set = 2, binding = 1) uniform sampler2D lace_mask;
    layout(set = 2, binding = 2) uniform sampler2D light_volume;
    layout(set = 2, binding = 3) uniform sampler2D corner_map;
    layout(set = 2, binding = 4) uniform sampler2D own_albedo;
    layout(set = 2, binding = 5) uniform sampler2D paper_mask;
    layout(set = 2, binding = 6) uniform sampler2D plaster_tone;
    layout(set = 2, binding = 7) uniform sampler2D stone_tile;
    #ifdef CHEAP_TABLE
    // TABLE_HEAD's block (render3d::TableBlock) after the room's, its names with t_, as
    // the room's block has some of them (embed_shader takes no array in a named block).
    layout(set = 3, binding = 2) uniform Table { vec4 t_pool; vec4 t_coat; vec4 t_polish; vec4 t_worn; vec4 t_shape; vec4 t_map[4];
                                                 vec4 t_light[12]; vec4 t_mix; vec4 t_shade; vec4 t_ssao; };
    #endif
    #else
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in vec2 v_extra;
    layout(location = 4) in vec3 v_local;
    layout(location = 5) in vec2 v_corner;
    layout(location = 6) flat in vec2 v_box;
    layout(location = 0) out vec4 result;
    // Each group's shader (ROOM_FRAG's ROOM_FLOOR, ROOM_WALLS, ROOM_PAINT, ROOM_SILL,
    // ROOM_METALS, ROOM_GLASS, ROOM_LACE) declares the textures in the order
    // render3d::room_textures binds them: the tree and lace maps for window light, the
    // light maps for opaque surfaces, and any material textures. The screen maps follow
    // unless NO_SSAO leaves them out. The floor's mirror comes last (PLANAR_FLOOR).
    layout(set = 2, binding = 0) uniform sampler2D tree_map;
    // The lace's coverage (design/materials/), R8 with its mips.
    layout(set = 2, binding = 1) uniform sampler2D lace_mask;
    #ifndef ROOM_WINDOW
    // The room's baked light (model3d::room_light): its probes' atlas, RGBA16F.
    layout(set = 2, binding = 2) uniform sampler2D light_volume;
    // The table's own map (TABLE_MAP_FN).
    layout(set = 2, binding = 3) uniform sampler2DShadow table_depth;
    // The shell's corners' shade (model3d::corner_map), R8, at v_corner, held inside its
    // chart's texels (v_box, each x + y × 4096), as a pixel's middle past a triangle's edge
    // would read another chart.
    layout(set = 2, binding = 4) uniform sampler2D corner_map;
    #endif
    #ifdef ROOM_FLOOR
    // The floor's oak (BAKE_FRAG's mode 4), albedo and roughness, and the normal.
    layout(set = 2, binding = 5) uniform sampler2D floor_albedo;
    layout(set = 2, binding = 6) uniform sampler2D floor_normal;
    // Its slow noises (surfaces::floor_noise): the wear's patchiness, the wax's patches.
    layout(set = 2, binding = 7) uniform sampler2D floor_noise;
    // Its scratches' repeating tile (surfaces::scratch_tile), R8 with its mips.
    layout(set = 2, binding = 8) uniform sampler2D scratch_tile;
    #ifndef NO_SSAO
    layout(set = 2, binding = 9) uniform sampler2D ssao_map;
    layout(set = 2, binding = 10) uniform sampler2D pre_place;
    #endif
    #ifdef PLANAR_FLOOR
    // The room mirrored in the floor (render3d::planar_pass): its light in the room's units,
    // a the distance from the floor to what it shows along the reflection, with its mips.
    layout(set = 2, binding = 11) uniform sampler2D planar_map;
    #endif
    #endif
    #ifdef ROOM_WALLS
    // The panelling's oak (BAKE_FRAG's mode 5) as the floor's; the wallpaper's mask, the
    // plaster's tone (design/materials/).
    layout(set = 2, binding = 5) uniform sampler2D wall_albedo;
    layout(set = 2, binding = 6) uniform sampler2D wall_normal;
    layout(set = 2, binding = 7) uniform sampler2D paper_mask;
    layout(set = 2, binding = 8) uniform sampler2D plaster_tone;
    #ifndef NO_SSAO
    layout(set = 2, binding = 9) uniform sampler2D ssao_map;
    layout(set = 2, binding = 10) uniform sampler2D pre_place;
    #endif
    #endif
    #ifdef ROOM_PAINT
    // The quiet paint's relief (room_shell::relief_tile): its slopes, the sheen's
    // unevenness, the slopes' spread under a texel.
    layout(set = 2, binding = 5) uniform sampler2D paint_tile;
    #ifndef NO_SSAO
    layout(set = 2, binding = 6) uniform sampler2D ssao_map;
    layout(set = 2, binding = 7) uniform sampler2D pre_place;
    #endif
    #endif
    #ifdef ROOM_SILL
    // The sills' limestone (room_shell::stone_tile): its albedo over the stone's, pores,
    // the polished band's patches, the honed roughness's unevenness.
    layout(set = 2, binding = 5) uniform sampler2D stone_tile;
    #ifndef NO_SSAO
    layout(set = 2, binding = 6) uniform sampler2D ssao_map;
    layout(set = 2, binding = 7) uniform sampler2D pre_place;
    #endif
    #endif
    #ifdef ROOM_METALS
    // The books' spines (model3d::books): tone, gilt or ink, label, wear.
    layout(set = 2, binding = 5) uniform sampler2D book_atlas;
    #ifndef NO_SSAO
    layout(set = 2, binding = 6) uniform sampler2D ssao_map;
    layout(set = 2, binding = 7) uniform sampler2D pre_place;
    #endif
    #endif
    #ifdef ROOM_GLASS
    // The glass's wiping tile (model3d's glass_tile): the scratches' direction (their doubled
    // angle times their depth), their depth, the film's thickness.
    layout(set = 2, binding = 2) uniform sampler2D glass_tile;
    #ifndef NO_SSAO
    layout(set = 2, binding = 3) uniform sampler2D ssao_map;
    #endif
    #endif
    #ifdef ROOM_LACE
    #ifndef NO_SSAO
    layout(set = 2, binding = 2) uniform sampler2D ssao_map;
    #endif
    #endif
    #endif
    // ssao_map: the room's ambient occlusion at half size (SSAO_FN); pre_place: where each
    // half-size pixel is from the eye (SSAO's PRE_FRAG), for the sun's contact shadows.
    // surfaces::Look and the room's frame. plank: x a plank's width, y its length in
    // widths, z the joint's half width, w the cup (its slope at the edges); planks: x each
    // one's own tone, y the share patched, z its tilt, w the scratches; worn: x the paths'
    // wear, y the walls' darker wax, z the path's reach round the table, w the path's
    // along the room; paper and gold: the wallpaper's ground and gold print (sRGB) and
    // their roughness; axes: u's direction in x and z, then v's; place: x the window's
    // wall's v, y the panelled wall's, z the floor's field's size, w the wall's (world
    // units); shade: the light thrown back into the room's shade (rooms::Room.bounce),
    // linear, and w the room's exposure over the board's (rooms::Room.room_exposure);
    // tile: the wall a tile of the wallpaper's mask covers, x, of the plaster's tone, y, of
    // the lace, z (world units); the shell's limewash at its tone's 0 and 1, the ceiling's
    // (its cornice's too) likewise, its paint and
    // the lace's thread (sRGB, and roughness). The shell's windows (room_shell, the room's
    // view; shell.x 0 the game's window, Room.window): shell x how many, y the window wall's
    // inner face's distance from the board along the wall's normal toward the sun, z the
    // floor's y, w a metre (world units); mids: their middles along u; niche: half the
    // niche's width, the sill's height, the springing's, the arch's rise (metres); glass:
    // the glass planes' depths into the wall, the lace's distance out of it (world units), w
    // how much of the sun the lace lets through; stone: the sills' (sRGB, and roughness);
    // ends: the end walls' u, x the stove's, y the far one's; brass: the curtains' (sRGB at
    // normal incidence, and roughness); lace_light: the window's light behind the lace
    // (linear, exposed as the view out, lifted with the room), w how strongly its thin parts scatter the sun
    // forward; table: x the table's top's radius, y the floor's height (world units), z and
    // w the panelling oak's lightness and saturation (factors, 0 untouched; a tuner's);
    // shell_sun: x how fast the sun's penumbra widens through the shell's windows (0 the
    // pattern's, room.z), y the sun on the room's surfaces over the board's
    // (rooms::Room.shell_sun), z and w the ceiling's lightness and saturation as the oak's;
    // room_baked: x 1 the baked light on, z how much of the harmonics and w of the shade the
    // room keeps beside it (rooms::Room.baked); light_box:
    // the probes' first corner in the room's frame and, w, the step between them (world
    // units); light_grid: how many across, along v, and up (model3d::room_light); room_box:
    // the shell's walls in the room's frame, x the far end's u, y the stove's end's, z the
    // window wall's v, w the hall wall's; room_doors: the hall door's middle along u and half
    // width, the salon door's along v and half width (with their architraves); room_heights:
    // the ceiling's y, the doors' tops and the wainscot's over the floor and the
    // architrave's width (metres). books: x how much of the books' fade shows (a tuner's, 1 as
    // made), y a step of fade, z the steps of a book's code (books::CODES); book_cases: the
    // bookcases' middles' distance from the hall door's along u, their half width (world
    // units), their top (metres); corners: the corners' and edges' darkening (rooms::Room's,
    // y its reach in world units), baked into corner_map, not read here; ssao: the room's ambient occlusion (SSAO_FN); planar: the
    // floor's mirror (render3d::planar_block): x how strong (0 none, the room's box seen
    // instead), y the tuner's views, z the map's texels a world unit spans at w 1, w its
    // last mip; planar_look: x the boards' own wax, y the blur over the wax's lobe; contact:
    // the sun's contact shadows (render3d::contact_look); sheen: the sun's broad sheen
    // (render3d::sheen_look); room_sun: the sun's saturation on the room, the panelling oak's
    // share of it, its saturation and share of the sheen (render3d::room_sun); paint_quiet:
    // the quiet paint (surfaces::Look's); paint_steps: the tuner's switches of it
    // (render3d::paint_steps, read only with PAINT_STEPS); sill: the sills' limestone
    // (surfaces::Look's); sill_steps: the tuner's switches of it (render3d::sill_steps, read
    // only with SILL_STEPS); window_view: the window view's steps' strengths, 1 as made
    // (render3d::window_view: the lace's sun, its scattered light below, the glass's film,
    // its scratches); lace_shade: the lace's room-side fill, x what is left of it where
    // neither the sun nor the sky behind the niche reaches the cloth (1 as made), y how much
    // the folds beside it hide (render3d::lace_shade); table_map:
    // the table's own map's rows (TABLE_MAP_FN);
    // book_cover and book_label: books::COVER and books::LABEL (sRGB), the label's table
    // ending in gilt, ink, the page edges plain and sprinkled.
    layout(set = 3, binding = 1) uniform Surfaces {
        vec4 plank;
        vec4 planks;
        vec4 worn;
        vec4 paper;
        vec4 gold;
        vec4 axes;
        vec4 place;
        vec4 shade;
        vec4 tile;
        vec4 plaster_shade;
        vec4 plaster_light;
        vec4 ceiling_shade;
        vec4 ceiling_light;
        vec4 paint;
        vec4 lace_thread;
        vec4 shell;
        vec4 shell_mids;
        vec4 shell_niche;
        vec4 shell_glass;
        vec4 stone;
        vec4 shell_ends;
        vec4 brass;
        vec4 lace_light;
        vec4 table;
        vec4 shell_sun;
        vec4 room_baked;
        vec4 light_box;
        vec4 light_grid;
        vec4 room_box;
        vec4 room_doors;
        vec4 room_heights;
        vec4 books;
        vec4 book_cases;
        vec4 corners;
        vec4 ssao;
        vec4 planar;
        vec4 planar_look;
        vec4 contact;
        vec4 sheen;
        vec4 room_sun;
        vec4 paint_quiet;
        vec4 paint_steps;
        vec4 sill;
        vec4 sill_steps[2];
        vec4 window_view;
        vec4 lace_shade;
        vec4 table_map[4];
        vec4 book_cover[32];
        vec4 book_label[8];
    };
    """;

// The room's tonemap, which the room (ROOM_FRAG) and the view out of its windows
// (OUTSIDE_FRAG) share, so the window and the room sit on one curve: the board's curve,
// its toe taken on the luminance and scaled into every channel: taking the least channel
// off, as the board does, turns the room's dim oak orange.
let TONE_FN = """
    vec3 tonemap(vec3 c) {
    #ifdef TOE_SWITCH
        c = toe_off(c, toe.x);
    #else
        float y = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-6);
        c *= (y < 0.04 ? 12.5 * y * y : y - 0.02) / y;
    #endif
        float peak = max(c.r, max(c.g, c.b));
        const float start = 0.76;
        if (peak < start) return c;
        const float d = 1.0 - start;
        float np = 1.0 - d * d / (peak + d - start);
        c *= np / peak;
        float g = 1.0 - 1.0 / (0.15 * (peak - np) + 1.0);
        return mix(c, vec3(np), g);
    }
    // The floor's mirror keeps the light as it is, before the tonemap (exposed, linear), so
    // the sky through the glass stays as far over the backlit lace as it is; only the sun's
    // disc and its halo are held to MIRROR_PEAK, which the floor's blur spreads anyway.
    const float MIRROR_PEAK = 16.0;
    vec3 mirror_light(vec3 c) {
        float peak = max(c.r, max(c.g, c.b));
        return peak > MIRROR_PEAK ? c * (MIRROR_PEAK / peak) : c;
    }
    #ifdef HDR_OUT
    // The scenic views' HDR target takes the light with tonemap's toe alone taken off; the
    // shoulder and the grade are HDR_TONE_FRAG's.
    vec3 room_toe(vec3 c) {
        float y = max(dot(c, vec3(0.2126, 0.7152, 0.0722)), 1e-6);
        return c * ((y < 0.04 ? 12.5 * y * y : y - 0.02) / y);
    }
    #endif
    """;

// The view out of the library's windows (model3d::view_out), turned with the room as
// ROOM_VERT turns it: the sky's vertices are directions, put round the eye so it shows no
// parallax; the band and the oak drawn eight times nearer the eye, inside the far plane,
// which leaves the picture as it is. Depth is neither tested nor written.
let OUTSIDE_VERT = """
    layout(location = 0) in vec3 a_pos;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec2 a_uv;
    layout(location = 3) in vec2 a_extra;          // occlusion, material
    layout(location = 0) out vec3 v_dir;
    layout(location = 1) out vec2 v_uv;
    layout(location = 2) out float v_mat;
    vec3 turned(vec3 a) {
        vec2 xz = room_axes.xy * a.x + room_axes.zw * a.z;
        return vec3(xz.x, a.y, xz.y);
    }
    void main() {
        bool sky = a_extra.y < 12.5;
        // The normal is zero: read so the attributes keep mesh::Vertex's layout.
        vec3 w = turned(a_pos + a_normal);
        vec3 pos = sky ? eye.xyz + w * 200.0 : eye.xyz + (w - eye.xyz) * 0.125;
        v_dir = sky ? w : w - eye.xyz;
        v_uv = a_uv;
        v_mat = a_extra.y;
        gl_Position = view_proj * vec4(pos, 1.0);
    }
    """;

// The view out's textures, before LIGHT_FN, which reads the tree's map (OUTSIDE_FRAG's
// tree_seen): the band, the oak, the tree as the sun sees it.
let OUTSIDE_HEAD = """
    layout(set = 2, binding = 0) uniform sampler2D band;
    layout(set = 2, binding = 1) uniform sampler2D oak;
    layout(set = 2, binding = 2) uniform sampler2D tree_map;
    """;

// The view out, unlit, its own exposure (Outside.exposure.x, rooms::Room.outside) through
// the room's tonemap and grade, dimmed with the board (screen.z). The sky is
// design/manor/outside/park.py's, worked out here round the sun (light_dir): a zenith blue
// paling to the horizon, warmer toward the sun, its glow, then the sun's disc and the
// haze's halo round it; below the horizon a plain lawn, darker toward the house, which the
// band's own lawn covers but under its foot. The band and the oak are premultiplied in
// linear light and sampled as sRGB, so their crowns blend with no dark fringe. A level of
// noise breaks the sky's bands.
let OUTSIDE_FRAG = """
    layout(location = 0) in vec3 v_dir;
    layout(location = 1) in vec2 v_uv;
    layout(location = 2) in float v_mat;
    layout(location = 0) out vec4 result;
    // exposure: x the exposure; y the sun disc's brightness over the sky's, linear; z in the
    // floor's mirror, its exposure; w the sun's veil's strength (render3d::sun_veil, 1 as
    // made). The sun's look (render3d::SunLook): sun_disc x the disc's radius (degrees), y
    // its limb's darkening (the linear law's u), z its edge's softness (degrees, over a
    // pixel); sun_glare the haze's halo, x and y its tight core's strength and width
    // (degrees), z and w its wider glow's; sun_tree x the tree outside against the sky, the
    // power its light through is taken to (0 none, 1 as the map, more denser), y how far
    // from the sun (degrees), z its leaves' back light, w
    // how sharp: the distance along the view it is looked up from (world units).
    layout(set = 3, binding = 1) uniform Outside { vec4 exposure; vec4 sun_disc; vec4 sun_glare; vec4 sun_tree; };
    // The haze's broad veil round the sun, some 10° (the forward scattering a low autumn
    // sun shows through the air), over the halo's two narrower terms.
    const float SUN_VEIL = 0.5;
    const vec3 ZENITH = vec3(0.6235, 0.7020, 0.8118);
    const vec3 HOR_COOL = vec3(0.8392, 0.8667, 0.9020);
    const vec3 HOR_WARM = vec3(0.9529, 0.8392, 0.6667);
    const vec3 CORE = vec3(1.0, 0.9529, 0.8392);
    const vec3 LAWN = vec3(0.505, 0.413, 0.122);
    vec3 decode(vec3 c) {
        return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
    }
    vec3 encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    // The sky toward d, linear.
    vec3 sky(vec3 d) {
        vec3 s = normalize(light_dir.xyz);
        float el = degrees(asin(clamp(d.y, -1.0, 1.0)));
        float ang = degrees(acos(clamp(dot(d, s), -1.0, 1.0)));
        float warm = exp(-(ang / 45.0) * (ang / 45.0));
        vec3 c = mix(mix(HOR_COOL, HOR_WARM, warm), ZENITH, clamp(el / 40.0, 0.0, 1.0));
        c += (CORE - c) * exp(-(ang / 7.0) * (ang / 7.0));
        vec3 ground = LAWN * (1.0 - 0.35 * clamp(-el / 30.0, 0.0, 1.0));
        c = mix(c, ground, clamp(-el, 0.0, 1.0));
        c = decode(c);
        // The sun's disc, darker toward its limb, its edge over a pixel or softer, and the
        // haze's halo round it: a tight core, a wider glow, the broad veil.
        float px = max(fwidth(ang), 1e-3);
        float edge = max(px, sun_disc.z);
        float r = sun_disc.x;
        float disc = 1.0 - smoothstep(r - 0.5 * edge, r + 0.5 * edge, ang);
        float mu = sqrt(max(1.0 - (ang / r) * (ang / r), 0.0));
        disc *= 1.0 - sun_disc.y * (1.0 - mu);
        float core = sun_glare.x * exp(-(ang / sun_glare.y) * (ang / sun_glare.y));
        float glow = sun_glare.z * exp(-(ang / sun_glare.w) * (ang / sun_glare.w));
        float halo = core + glow + exposure.w * SUN_VEIL * exp(-(ang / 10.0) * (ang / 10.0));
        return c + (disc * exposure.y + halo) * decode(CORE) * step(0.0, el);
    }
    // The tree outside (trees.goose's, its map as the sun sees it) seen against the sky from
    // the eye along d, near the sun only (sun_tree.y degrees, fading over the last third), where
    // the map's view is the sun's: how much of the sky shows through (1 all), and the leaves'
    // light where they cover it, backlit toward the sun.
    vec4 tree_seen(vec3 d) {
        vec3 s = normalize(light_dir.xyz);
        float ang = degrees(acos(clamp(dot(d, s), -1.0, 1.0)));
        float near = 1.0 - smoothstep(0.67 * sun_tree.y, sun_tree.y, ang);
        vec2 nw = -room_axes.zw;
        float toward = dot(d.xz, nw);
        if (sun_tree.x <= 0.0 || near <= 0.0 || tree.x <= 0.0 || toward < 0.05) return vec4(0.0, 0.0, 0.0, 1.0);
        // Taken from sun_tree.w along the view (world units), which leaves where it lands in
        // the map as it is and blurs it less, as the map blurs with the distance from the tree.
        vec2 tr = tree_light(eye.xyz + d * sun_tree.w, d, nw, room_axes.xy, toward);
        float open = mix(1.0, pow(max(tr.x * tr.y, 1e-4), sun_tree.x), near);
        // Lit through from behind: the leaves' share of the sun forward, warm; the limbs dark.
        float leafy = (1.0 - tr.y) / max(2.0 - tr.x - tr.y, 1e-3);
        vec3 back = decode(vec3(0.62, 0.42, 0.12)) * (0.12 + sun_tree.z * exp(-(ang / 5.0) * (ang / 5.0)));
        vec3 wood = decode(vec3(0.16, 0.12, 0.09)) * 0.4;
        return vec4(mix(wood, back, leafy) * (1.0 - open), open);
    }
    """;

// OUTSIDE_FRAG's main, apart so the light tuner's park (PARK_FN) goes between.
let OUTSIDE_MAIN = """
    void main() {
    #ifdef PARK
        vec2 park_fw = fwidth(v_uv);
    #endif
        vec4 t;
        if (v_mat < 12.5) t = vec4(sky(normalize(v_dir)), 1.0);
        else if (v_mat < 13.5) {
            // The band's ends faded over 2°, for the views along the wall.
            t = texture(band, v_uv) * smoothstep(0.0, 0.0156, min(v_uv.x, 1.0 - v_uv.x));
    #ifdef PARK
            t = park_band_foot(t, v_uv);
    #endif
        }
    #ifdef PARK
        else if (v_mat > 14.5) t = park_ground(v_uv, normalize(v_dir), length(v_dir), max(park_fw.x, park_fw.y), v_mat);
    #endif
        else t = texture(oak, v_uv);
        vec3 c = t.rgb / max(t.a, 1e-4) * exposure.x;
        if (sun_tree.x > 0.0 && exposure.z <= 0.0) {
            vec4 leaves_seen = tree_seen(normalize(v_dir));
            c = c * leaves_seen.a + leaves_seen.rgb * exposure.x;
        }
        if (exposure.z > 0.0) {
            // In the floor's mirror: the light itself (TONE_FN's mirror_light), z times
            // the look's, whose exposure is set through the tonemap's shoulder, where the
            // sky reads white whatever it is: a clear sky by a low sun is some 13 times a
            // sunlit dark oak floor, the look's about 3.
            result = vec4(mirror_light(c * exposure.z) * t.a, t.a);
            return;
        }
    #ifdef HDR_OUT
        result = vec4(room_toe(c) * t.a, t.a);
    #else
        c = tonemap(c) * vec3(1.02, 1.0, 0.97);
        float n = fract(sin(dot(floor(gl_FragCoord.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
        result = vec4((encode(c) + n / 255.0) * t.a * (1.0 - screen.z), t.a);
    #endif
    }
    """;

// The light tuner's park on the ground (render3d::park_ground; task 109's look test),
// between OUTSIDE_FRAG and OUTSIDE_MAIN, which calls it under PARK. The lawn
// (model3d::view_out's, its uv the place in metres from the middle window, y into the
// room) shaded with no blades, which are under a pixel from the room: one plain colour, its
// glow looking toward the low sun, its paler tips at a grazing angle; autumn's
// fallen leaves over it, thicker under the crowns; lit by the key's sun and the sky in the
// band's own units, so the view out's exposure and tonemap take it as they take the band.
// The trees' cards (view_out::PARK_TREES) are the oak's picture tinted, each darkening the
// lawn under its crown and round its trunk's foot and casting its own picture's shadow
// along the sun; the band casts its trees' shadow too. The park's frame: x to the right
// looking out, y up from the lawn, z into the room, metres. Its parts switched off one at a
// time by PARK_NO_SHADING, PARK_NO_LEAVES, PARK_NO_GROUNDING, PARK_NO_SHADOWS.
let PARK_FN = """
    // view_out's measures: a metre in world units; the band's cylinder (metres round the
    // middle window, degrees either side), its rows' heights over the lawn, and the rows
    // its foot (BAND_FOOT: x the trunks' row 1.6 m up, above the blur that smeared the
    // foot into the lawn, y the lawn's level) and how dark its woods are at their foot; the
    // oak's picture's width over its
    // height and its trunk's foot over the picture's foot as a share of its height.
    const float PARK_METRE = 30.48;
    const float BAND_R = 110.0;
    const float BAND_HALF = 64.0;
    const float BAND_LOW = -14.05;
    const float BAND_TOP = 26.26;
    const vec2 BAND_FOOT = vec2(0.611, 0.650);
    const float WOODS_FOOT = 0.8;
    const float OAK_ASPECT = 1.49;
    const float OAK_SINK = 0.03;
    // The trees' cards (view_out::PARK_TREES, kept equal): x degrees right of straight
    // out, y metres out, z tall in metres, w its tint in CARD_TINT.
    const int CARDS = 7;
    const vec4 CARD[7] = vec4[7](vec4(6.0, 100.0, 16.0, 2.0), vec4(-18.0, 88.0, 18.0, 1.0), vec4(22.0, 70.0, 20.0, 0.0),
                                 vec4(40.0, 48.0, 16.0, 3.0), vec4(-6.0, 50.0, 12.0, 4.0), vec4(30.0, 30.0, 10.0, 5.0),
                                 vec4(-40.0, 18.0, 13.0, 6.0));
    const vec3 CARD_TINT[7] = vec3[7](vec3(1.0, 1.0, 1.0), vec3(0.78, 0.86, 0.66), vec3(0.95, 0.78, 0.60),
                                      vec3(1.04, 0.96, 0.72), vec3(0.86, 0.90, 0.70), vec3(0.98, 0.84, 0.62),
                                      vec3(0.90, 0.88, 0.76));
    // The light on the lawn in the band's units (its painted lawn's linear colour as lit):
    // the low sun's colour and strength, the sky's from straight up; the sun wrapped round
    // the blades; the glow through them looking toward the sun (its strength, how tight,
    // its tint); the tips' share seen at a grazing angle.
    const vec3 SUN_LIGHT = vec3(1.0, 0.78, 0.48);
    const float SUN_K = 1.5;
    const float SKY_K = 0.45;
    const float WRAP = 0.6;
    const float GLOW_K = 0.45;
    const float GLOW_POW = 4.0;
    const vec3 GLOW_TINT = vec3(1.3, 1.25, 0.45);
    const float GRAZE_K = 0.45;
    // The haze toward the horizon's sky with distance: metres to its 63%, its most, and
    // the sky's share as its colour (the band's own haze is darker than the sky).
    const float HAZE_M = 400.0;
    const float HAZE_MAX = 0.4;
    const float HAZE_SKY = 0.6;
    // The grass (sRGB): the band's lit lawn, a greener hue of about its brightness it
    // drifts toward (at most HUE_DRIFT, over HUE_M metres), the tips.
    const vec3 LAWN_PLAIN = vec3(0.45, 0.43, 0.16);
    const vec3 LAWN_GREENER = vec3(0.42, 0.43, 0.16);
    const float HUE_DRIFT = 0.25;
    const float HUE_M = 60.0;
    const vec3 GRASS_TIPS = vec3(0.66, 0.62, 0.36);
    // Grounding: the sky light kept under a crown (its radius a share of the card's width),
    // and the darker ring round a trunk's foot (its radius a share of the tree's height).
    const float CROWN_R = 0.34;
    const float UNDER = 0.7;
    const float RING_R = 0.08;
    const float RING_K = 0.6;
    // The shadows: how dense a crown is, and the penumbra's spread a metre along the ray
    // (the sun's disc and the leaves' scatter, radians).
    const float CROWN_DENSITY = 0.88;
    const float PENUMBRA = 0.012;
    // The band's shadow: how many shafts of light come through the tree line across the
    // band, and how dense it is in a shaft.
    const float BAND_SHAFTS = 140.0;
    const float BAND_OPEN = 0.35;
    // The leaves: their cover in the open, more under the crowns, near the house (blown
    // against it, and the near tree's: most of the grass hidden out to LEAF_NEAR metres,
    // thinning to the open's by LEAF_FAR, that distance itself varying by LEAF_WARP over
    // some 25 m so the edge is no line) and toward the band's foot; drifts thicker and
    // thinner by LEAF_DRIFT, long along the house (LEAF_DRIFT_M metres across and out); a
    // leaf's cell (metres) and its oval's share of it, three layers of them; their colours
    // (sRGB).
    const float LEAF_BASE = 0.12;
    const float LEAF_UNDER = 0.9;
    const float LEAF_HOUSE = 0.9;
    const float LEAF_NEAR = 8.0;
    const float LEAF_FAR = 70.0;
    const float LEAF_WARP = 0.45;
    const float LEAF_DRIFT = 0.6;
    const vec2 LEAF_DRIFT_M = vec2(16.0, 7.0);
    const float LEAF_CELL = 0.07;
    const float LEAF_SHARE = 0.42;
    // The leaves' relief: their tilt (its slope at most), how much of the tilt's light
    // shows, the rim's light in the glow, and the grass's shade beside them (how far off
    // away from the sun, in cells, and how dark at most; it fades out with the leaves).
    const float LEAF_TILT = 0.5;
    const float LEAF_RELIEF = 0.6;
    const float LEAF_RIM = 1.5;
    const float LEAF_SHADE_OFF = 0.12;
    const float LEAF_CONTACT = 0.3;
    const vec3 LEAF_ORANGE = vec3(0.72, 0.45, 0.16);
    const vec3 LEAF_YELLOW = vec3(0.78, 0.64, 0.26);
    const vec3 LEAF_BROWN = vec3(0.46, 0.32, 0.16);
    const vec3 LEAF_RED = vec3(0.56, 0.28, 0.13);

    vec3 to_park(vec3 w) { return vec3(dot(w.xz, room_axes.xy), w.y, dot(w.xz, room_axes.zw)); }
    vec2 park_toward(float deg) {
        float a = radians(deg);
        return vec2(sin(a), -cos(a));
    }
    float park_hash(vec2 p) {
        vec3 p3 = fract(vec3(p.xyx) * 0.1031);
        p3 += dot(p3, p3.yzx + 33.33);
        return fract((p3.x + p3.y) * p3.z);
    }
    float park_noise(vec2 p) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(park_hash(i), park_hash(i + vec2(1.0, 0.0)), u.x),
                   mix(park_hash(i + vec2(0.0, 1.0)), park_hash(i + vec2(1.0, 1.0)), u.x), u.y);
    }
    // Noise of `freq` cycles a metre, faded to its mean where a pixel's footprint `fw`
    // (metres) covers a cycle.
    float park_octave(vec2 at, float freq, float fw, float seed) {
        float n = park_noise(at * freq + seed);
        return mix(n, 0.5, smoothstep(0.3, 0.9, fw * freq));
    }

    // The band's foot: below the trunks' row the picture's blurred foot and painted lawn
    // are replaced by that row drawn on down (the trunks, sharp in height), a little darker
    // toward the ground, ending sharp on our lawn.
    vec4 park_band_foot(vec4 t, vec2 uv) {
        if (uv.y > BAND_FOOT.x) {
            t = textureLod(band, vec2(uv.x, BAND_FOOT.x), 0.0) * smoothstep(0.0, 0.0156, min(uv.x, 1.0 - uv.x));
            t.rgb *= mix(1.0, WOODS_FOOT, smoothstep(BAND_FOOT.x, BAND_FOOT.y, uv.y));
        }
        return t * (1.0 - smoothstep(BAND_FOOT.y, BAND_FOOT.y + 0.002, uv.y));
    }

    // How much of the sun s reaches the lawn at p: the cards' pictures cast along the ray,
    // each read over its penumbra, and the band's trees where the ray meets its cylinder.
    float park_sun(vec3 p, vec3 s) {
        if (s.y <= 0.0) return 0.0;
        float lit = 1.0;
    #ifndef PARK_NO_SHADOWS
        for (int k = 0; k < CARDS; k++) {
            vec4 c = CARD[k];
            vec2 n = park_toward(c.x);
            vec2 side = park_toward(c.x + 90.0);
            float sn = dot(s.xz, n);
            if (abs(sn) < 1e-3) continue;
            float along = dot(n * c.y - p.xz, n) / sn;
            if (along <= 0.0) continue;
            vec3 q = p + s * along;
            float w = c.z * OAK_ASPECT;
            vec2 uv = vec2(dot(q.xz - n * c.y, side) / w + 0.5, 1.0 - q.y / c.z - OAK_SINK);
            if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) continue;
            vec2 r = along * PENUMBRA / vec2(w, c.z);
            float a = 0.25 * (textureLod(oak, uv + r * vec2(0.7, 0.3), 0.0).a + textureLod(oak, uv - r * vec2(0.7, 0.3), 0.0).a
                            + textureLod(oak, uv + r * vec2(-0.3, 0.7), 0.0).a + textureLod(oak, uv - r * vec2(-0.3, 0.7), 0.0).a);
            lit *= 1.0 - CROWN_DENSITY * a;
        }
        float hh = max(dot(s.xz, s.xz), 1e-6);
        float b = dot(p.xz, s.xz);
        float cc = dot(p.xz, p.xz) - BAND_R * BAND_R;
        float along = (-b + sqrt(max(b * b - hh * cc, 0.0))) / hh;
        vec3 q = p + s * along;
        vec2 uv = vec2((degrees(atan(q.x, -q.z)) + BAND_HALF) / (2.0 * BAND_HALF), (BAND_TOP - q.y) / (BAND_TOP - BAND_LOW));
        if (along > 0.0 && uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0) {
            vec2 r = vec2(along * PENUMBRA / (BAND_R * radians(2.0 * BAND_HALF)), 0.0);
            float a = 0.5 * (textureLod(band, uv + r, 0.0).a + textureLod(band, uv - r, 0.0).a);
            // The tree line is no wall: light comes through between its trunks in shafts.
            float gaps = smoothstep(0.35, 0.75, park_noise(vec2(uv.x * BAND_SHAFTS, 3.7)));
            lit *= 1.0 - mix(CROWN_DENSITY, BAND_OPEN, gaps) * a;
        }
        // Behind the band the lawn runs on under its trees, in their shade with the same
        // shafts.
        float u = (degrees(atan(p.x, -p.z)) + BAND_HALF) / (2.0 * BAND_HALF);
        float gaps = smoothstep(0.35, 0.75, park_noise(vec2(u * BAND_SHAFTS, 3.7)));
        lit *= 1.0 - mix(CROWN_DENSITY, BAND_OPEN, gaps) * smoothstep(BAND_R - 1.5, BAND_R, length(p.xz));
    #endif
        return lit;
    }

    // One layer of leaves at q (in cells): a leaf in a cell where its hash is under the
    // field, an oval in it, its colour one of four, each tilted up to LEAF_TILT so the low
    // sun s (the layer's frame) catches some and leaves others darker, its rim lit by the
    // glow toward the sun; rgb the colour, a the cover.
    vec4 park_leaf(vec2 q, float field, vec3 s, float glow) {
        vec2 cell = floor(q);
        vec2 f = fract(q);
        float h1 = park_hash(cell);
        float h2 = park_hash(cell + 19.1);
        float h3 = park_hash(cell + 37.7);
        vec2 at = vec2(h2, h3) * 0.1 + 0.45;
        float a = h3 * 6.2832;
        vec2 o = mat2(cos(a), sin(a), -sin(a), cos(a)) * (f - at);
        float d = length(o * vec2(1.0, 1.5));
        float oval = 1.0 - smoothstep(0.38, 0.45, d);
        vec3 c = h2 < 0.25 ? LEAF_ORANGE : (h2 < 0.65 ? LEAF_YELLOW : (h2 < 0.88 ? LEAF_BROWN : LEAF_RED));
        vec2 tilt = (vec2(park_hash(cell + 53.1), park_hash(cell + 71.3)) - 0.5) * 2.0 * LEAF_TILT;
        float lit = clamp(dot(normalize(vec3(tilt.x, 1.0, tilt.y)), s) / max(s.y, 0.05), 0.3, 2.0);
        float rim = smoothstep(0.26, 0.40, d) * glow * LEAF_RIM;
        return vec4(decode(c) * (0.82 + 0.28 * fract(h1 * 7.0)) * mix(1.0, lit, LEAF_RELIEF) * (1.0 + rim),
                    oval * step(h1, field));
    }
    // The faint shade a layer's leaves cast on the grass beside them, away from the sun
    // (off, in cells).
    float park_leaf_shade(vec2 q, float field, vec2 off) {
        vec2 cell = floor(q);
        float h1 = park_hash(cell);
        float h2 = park_hash(cell + 19.1);
        float h3 = park_hash(cell + 37.7);
        vec2 at = vec2(h2, h3) * 0.1 + 0.45 + off;
        float a = h3 * 6.2832;
        vec2 o = mat2(cos(a), sin(a), -sin(a), cos(a)) * (fract(q) - at);
        return (1.0 - smoothstep(0.36, 0.5, length(o * vec2(1.0, 1.5)))) * step(h1, field);
    }

    vec4 park_ground(vec2 uv, vec3 dw, float dist_w, float fw, float mat) {
        float dist = dist_w / PARK_METRE;
        float haze = HAZE_MAX * (1.0 - exp(-dist / HAZE_M));
        vec3 haze_c = HAZE_SKY * sky(normalize(vec3(dw.x, 0.0, dw.z)));
        if (mat > 15.5) {
            int k = int(CARD[int(mat - 15.5)].w + 0.5);
            vec4 t = texture(oak, uv);
            t.rgb *= CARD_TINT[k];
            t.rgb = mix(t.rgb, haze_c * t.a, haze);
            return t;
        }
        vec2 at = uv;
        vec3 p = vec3(at.x, 0.0, at.y);
        vec3 s = normalize(to_park(normalize(light_dir.xyz)));
        vec3 d = to_park(dw);
        // Under the crowns and round the trunks' feet.
        float sky_kept = 1.0;
        float ring = 1.0;
        float under = 0.0;
        for (int k = 0; k < CARDS; k++) {
            vec4 c = CARD[k];
            float dk = distance(at, park_toward(c.x) * c.y);
            float crown = exp(-pow(dk / (CROWN_R * OAK_ASPECT * c.z), 2.0));
            under = max(under, crown);
    #ifndef PARK_NO_GROUNDING
            sky_kept *= 1.0 - UNDER * crown;
            ring *= 1.0 - RING_K * exp(-pow(dk / (RING_R * c.z), 2.0));
    #endif
        }
        float sun = park_sun(p, s);
        // The grass.
    #ifdef PARK_NO_SHADING
        vec3 grass = decode(LAWN);
        float glow = 0.0;
        float wrap = max(s.y, 0.0);
    #else
        // One plain colour, the band's lit lawn, its hue drifting a little toward green over
        // HUE_M metres; never darker: patches seen at a few degrees read as shadows.
        vec3 grass = mix(decode(LAWN_PLAIN), decode(LAWN_GREENER), HUE_DRIFT * park_noise(at / HUE_M));
        float graze = pow(1.0 - abs(d.y), 3.0);
        grass = mix(grass, decode(GRASS_TIPS), GRAZE_K * graze);
        float glow = GLOW_K * pow(max(dot(d, s), 0.0), GLOW_POW);
        float wrap = (max(s.y, 0.0) + WRAP) / (1.0 + WRAP);
    #endif
        // The sky's light: half from straight up, half from the horizon under the sun.
        vec3 l = normalize(light_dir.xyz);
        vec3 sky_light = 0.5 * (sky(vec3(0.0, 1.0, 0.0)) + sky(normalize(vec3(l.x, 0.0, l.z)))) * SKY_K * sky_kept;
        vec3 sun_light = SUN_LIGHT * SUN_K * sun;
        vec3 c = grass * (sun_light * wrap + sky_light) + grass * sun_light * glow * GLOW_TINT;
        // Autumn's leaves over it.
    #ifndef PARK_NO_LEAVES
        float r = length(at);
        float field = LEAF_BASE + LEAF_UNDER * under + 0.35 * smoothstep(80.0, 108.0, r) * (1.0 - smoothstep(112.0, 130.0, r)) + LEAF_HOUSE * (1.0 - smoothstep(LEAF_NEAR, LEAF_FAR, r * (1.0 + LEAF_WARP * (2.0 * park_noise(at / 25.0 + 5.0) - 1.0))))
                    + LEAF_DRIFT * (park_noise(at / LEAF_DRIFT_M + 61.0) - 0.5)
                    + 0.5 * (park_octave(at, 0.25, fw, 41.0) - 0.5) + 0.3 * (park_octave(at, 1.1, fw, 53.0) - 0.5);
        field = clamp(field, 0.0, 1.0);
        mat2 turn = mat2(0.8, 0.6, -0.6, 0.8);
        vec3 s3 = vec3(turn * s.xz, s.y).xzy;
        vec4 l1 = park_leaf(at / LEAF_CELL, field, s, glow);
        vec4 l2 = park_leaf(at / LEAF_CELL + vec2(0.5, 0.5) + 71.0, field, s, glow);
        vec4 l3 = park_leaf(turn * at / LEAF_CELL + 137.0, field, s3, glow);
        vec2 off = -normalize(s.xz + 1e-4) * LEAF_SHADE_OFF;
        float shade = max(max(park_leaf_shade(at / LEAF_CELL, field, off),
                              park_leaf_shade(at / LEAF_CELL + vec2(0.5, 0.5) + 71.0, field, off)),
                          park_leaf_shade(turn * at / LEAF_CELL + 137.0, field, turn * off));
        vec3 one = mix(mix(l3.rgb, l2.rgb, l2.a), l1.rgb, l1.a);
        float here = 1.0 - (1.0 - l1.a) * (1.0 - l2.a) * (1.0 - l3.a);
        vec3 mean = 0.25 * decode(LEAF_ORANGE) + 0.4 * decode(LEAF_YELLOW) + 0.23 * decode(LEAF_BROWN) + 0.12 * decode(LEAF_RED);
        // Single leaves give way to their mean where a pixel covers a cell, the change
        // spread and broken by a noise so it draws no line across the lawn.
        float far = smoothstep(0.2 * LEAF_CELL, LEAF_CELL, fw * (0.65 + 0.7 * park_noise(at / 5.0 + 23.0)));
        float open = 1.0 - LEAF_SHARE * field;
        float cover = mix(here, 1.0 - open * open * open, far);
        c *= 1.0 - LEAF_CONTACT * shade * (1.0 - far);
        vec3 leaf = mix(one, mean, far);
        vec3 lc = leaf * (sun_light * (0.5 + 0.5 * max(s.y, 0.0)) * 0.8 + sky_light);
        c = mix(c, lc, cover);
    #endif
        c *= ring;
        return vec4(mix(c, haze_c, haze), 1.0);
    }
    """;

// The room lit as the table is (TABLE_FRAG's light, its functions repeated here): the
// window's key with its pattern and the trees' dapple, the table's shadow, the room's
// harmonics, a GGX highlight in the wax. The floor is laid here: a herringbone of
// planks, each its own place in the floor's field (a strip, a place along it, mirrored
// either way), its own tone, a few patched, each a little tilted and cupped so the
// window's highlight breaks plank by plank, the joints dark with wax and fading to
// their share of the floor far off, worn lighter and duller on the paths round the
// table and along the room, darker and waxier along the walls, finely scratched.
let ROOM_FRAG = """
    // The light out (exposed, linear), a its coverage: tonemapped and graded into sRGB and
    // dimmed with the board, for today's 8-bit targets; with LINEAR_OUT the light itself, its
    // peak held to MIRROR_PEAK (TONE_FN's mirror_light), as the floor's mirror keeps it; with
    // HDR_OUT the light with the toe alone taken off (room_toe).
    vec4 room_out(vec3 c, float a) {
    #ifdef LINEAR_OUT
        return vec4(mirror_light(c) * a, a);
    #else
    #ifdef HDR_OUT
        return vec4(room_toe(c) * a, a);
    #else
        return vec4(to_srgb(tonemap(c) * vec3(1.02, 1.0, 0.97)) * a * (1.0 - screen.z), a);
    #endif
    #endif
    }

    // mesh.goose's and surfaces.goose's (test/model3d/geometry checks them).
    const float TABLE_TOP = -0.703;
    const float TABLE_Z = -4.5;
    const float FLOOR_STRIPS = 20.0;
    const float FLOOR_NOISE_SIDE = 1024.0;
    const float SCRATCH_TILE = 48.0;
    // The table's base (mesh::table_base): its column's mean radius, and a leg's curve
    // from its root over the knee to the scroll's foot, out from the axis and up from the
    // floor (world units, mesh::LEG's and SCROLL_MID's), its half thickness.
    const float COLUMN_R = 2.6;
    const vec2 LEG0 = vec2(2.44, 5.36);
    const vec2 LEG1 = vec2(5.18, 4.45);
    const vec2 LEG2 = vec2(7.86, 2.13);
    const vec2 LEG3 = vec2(10.0, 0.7);
    const float LEG_HALF = 0.8;

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

    // How much of a line `half_w` either side of 0 a pixel `fp` wide at distance d covers
    // (a box filter): far off a joint or a scratch fades to its share of the floor.
    float line_cover(float d, float half_w, float fp) {
        return clamp((min(d + 0.5 * fp, half_w) - max(d - 0.5 * fp, -half_w)) / max(fp, 1e-5), 0.0, 1.0);
    }

    // How far p is from the segment a to b (2D).
    float to_segment(vec2 p, vec2 a, vec2 b) {
        vec2 ab = b - a;
        float h = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-6), 0.0, 1.0);
        return length(p - a - ab * h);
    }

    // The table keeping the key off p: its top a disc at TABLE_TOP (table.x across), its
    // column under it, and its four legs each three pieces cast along the light, each
    // edge softer the farther it was cast from.
    float table_shade(vec3 p, vec3 l) {
        if (p.y > TABLE_TOP - 0.5) return 1.0;
        vec2 mid = vec2(0.0, TABLE_Z);
        float ly = max(l.y, 0.05);
        float t = (TABLE_TOP - 0.5 - p.y) / ly;
        vec2 q = p.xz + l.xz * t;
        float w = 0.1 + 2.0 * room.z * t;
        float lit = smoothstep(-w, w, length(q - mid) - table.x);
        vec2 a = p.xz - mid;
        vec2 ba = q - p.xz;
        float h = clamp(-dot(a, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
        float wc = 0.2 + 2.0 * room.z * h * t;
        lit = min(lit, smoothstep(-wc, wc, length(a + ba * h) - COLUMN_R));
        // The legs, low: only on what is lower than their knees, near enough.
        float above = p.y - table.y;
        if (above > LEG0.y || length(a) > 12.0 + (LEG0.y - above) / ly) return lit;
        vec2 run = l.xz / ly;
        for (int k = 0; k < 4; k++) {
            float ang = 3.14159265 * (0.25 + 0.5 * float(k));
            vec2 dir = vec2(cos(ang), sin(ang));
            vec2 p0 = dir * LEG0.x - run * max(LEG0.y - above, 0.0);
            vec2 p1 = dir * LEG1.x - run * max(LEG1.y - above, 0.0);
            vec2 p2 = dir * LEG2.x - run * max(LEG2.y - above, 0.0);
            vec2 p3 = dir * LEG3.x - run * max(LEG3.y - above, 0.0);
            float d = min(min(to_segment(a, p0, p1), to_segment(a, p1, p2)), to_segment(a, p2, p3));
            float wl = 0.08 + room.z * (LEG0.y - above) / ly;
            lit = min(lit, smoothstep(-wl, wl, d - LEG_HALF));
        }
        return lit;
    }

    // The herringbone's plank at f (the floor's u and v in plank widths), its rows along
    // u. In a frame turned 45°, planks n widths long lie across, [k, k + n] × [k, k + 1],
    // and up, [k, k + 1] × [k + 1, k + 1 + n], repeated by (n, -n): b is the repeat. id:
    // k and b; up 1 for the planks up; along and across in plank widths.
    struct Plank { vec2 id; float up; float along; float across; };
    Plank plank_at(vec2 f) {
        float n = plank.y;
        vec2 a = vec2(f.x - f.y, f.x + f.y) * 0.70710678;
        float b0 = floor((a.x - a.y) / (2.0 * n));
        Plank pk;
        pk.id = vec2(0.0);
        pk.up = 0.0;
        pk.along = 0.0;
        pk.across = 0.5;
        for (int j = 0; j < 2; j++) {
            float b = b0 + float(j);
            vec2 q = a - b * vec2(n, -n);
            float k = floor(q.y);
            if (q.x >= k && q.x < k + n) {
                pk.id = vec2(k, b);
                pk.along = q.x - k;
                pk.across = q.y - k;
                return pk;
            }
            k = floor(q.x);
            if (q.y >= k + 1.0 && q.y < k + 1.0 + n) {
                pk.id = vec2(k, b);
                pk.up = 1.0;
                pk.along = q.y - k - 1.0;
                pk.across = q.x - k;
                return pk;
            }
        }
        return pk;
    }

    #ifndef ROOM_WINDOW
    // One probe's texel of the baked light: colour c's block, the height's slice k, at g
    // (the grid's x and along v).
    vec4 probe_at(float c, float k, vec2 g) {
        vec2 size = vec2(light_grid.x * light_grid.z, 3.0 * light_grid.y);
        return textureLod(light_volume, vec2(k * light_grid.x + g.x + 0.5, c * light_grid.y + g.y + 0.5) / size, 0.0);
    }

    // The room's baked light (model3d::room_light) at lp, in the room's frame, for the
    // normal n (the world's), over pi: the probes round lp, half a step out along n so a
    // wall reads the room's side of itself, the layers above and below mixed by hand, each
    // colour a constant and a direction.
    vec3 baked_light(vec3 lp, vec3 n) {
        vec3 ln = vec3(dot(n.xz, axes.xy), n.y, dot(n.xz, axes.zw));
        vec3 hi = vec3(light_grid.x, light_grid.z, light_grid.y) - 1.0;
        vec3 g = clamp((lp + ln * (0.5 * light_box.w) - light_box.xyz) / light_box.w, vec3(0.0), hi);
        float k0 = floor(g.y);
        float k1 = min(k0 + 1.0, hi.y);
        float kf = g.y - k0;
        vec4 r = mix(probe_at(0.0, k0, g.xz), probe_at(0.0, k1, g.xz), kf);
        vec4 gr = mix(probe_at(1.0, k0, g.xz), probe_at(1.0, k1, g.xz), kf);
        vec4 b = mix(probe_at(2.0, k0, g.xz), probe_at(2.0, k1, g.xz), kf);
        return max(vec3(r.x + dot(r.yzw, ln), gr.x + dot(gr.yzw, ln), b.x + dot(b.yzw, ln)), vec3(0.0));
    }

    // The light in the room's shade for the normal n at lp (the room's frame), over pi:
    // the harmonics and the shade's even light, or with the light baked, that beside what
    // the harmonics and the shade keep.
    vec3 room_irradiance(vec3 lp, vec3 n) {
        vec3 ambient = sh_eval(n) * params.z;
        if (room_baked.x < 0.5) return ambient + shade.rgb;
        return baked_light(lp, n) + ambient * room_baked.z + shade.rgb * room_baked.w;
    }
    #endif

    // The sun's colour on the room's surfaces: the key's, its saturation about its luminance
    // scaled by `sat` (1 as it is; render3d::room_sun).
    vec3 room_sun_color(float sat) {
        float y = dot(light_color.rgb, vec3(0.2126, 0.7152, 0.0722));
        return max(mix(vec3(y), light_color.rgb, sat), vec3(0.0));
    }

    #ifndef ROOM_WINDOW
    // The room's light the way r looks by its mean albedo there: the floor's below, the
    // walls' across, the plaster's above: what a rough surface sees through its GGX lobe.
    vec3 room_wide(vec3 lp, vec3 r) {
        float albedo = r.y > 0.0 ? mix(0.12, 0.41, r.y * r.y) : mix(0.12, 0.06, -r.y);
        return room_irradiance(lp, r) * albedo;
    }
    #endif

    #ifdef SHARP_BOX
    // The room's radiance seen along r from p (the world's; lp and lr the room's frame): the
    // shell's box met (its four walls, the ceiling, the floor), the surface there by where it
    // is (the wainscot, the paper, the two doors' paint, the plaster, the herringbone's
    // mean), lit by the baked light and the sun through the windows; on the window wall, its
    // three windows as soft rectangles under their arches, their bars at the inner glass, the
    // view out's light (lace_light, back in the room's units) between them, softer the
    // farther and longer up the wall than across it at a grazing look, as a waxed floor's
    // streaks are. After the gilt and brass study's proposal: no cube map, nothing baked.
    vec3 room_seen(vec3 p, vec3 lp, vec3 r, vec3 lr, float alpha, float nov, float px) {
        float big = 1e6;
        float tx = abs(lr.x) < 1e-4 ? big : ((lr.x > 0.0 ? room_box.y : room_box.x) - lp.x) / lr.x;
        float tz = abs(lr.z) < 1e-4 ? big : ((lr.z > 0.0 ? room_box.w : room_box.z) - lp.z) / lr.z;
        float ty = abs(lr.y) < 1e-4 ? big : ((lr.y > 0.0 ? room_heights.x : shell.z) - lp.y) / lr.y;
        float t = max(min(tx, min(ty, tz)), 0.0);
        vec3 h = lp + lr * t;
        vec3 hw = p + r * t;
        vec3 nl;
        vec3 alb;
        float up = (h.y - shell.z) / shell.w;
        vec3 wall = up < room_heights.z ? vec3(0.082, 0.046, 0.030) : mix(srgb(paper.rgb), srgb(gold.rgb), 0.3);
        if (t == ty) {
            nl = vec3(0.0, lr.y > 0.0 ? -1.0 : 1.0, 0.0);
            alb = lr.y > 0.0 ? srgb(ceiling_light.rgb) : vec3(0.078, 0.045, 0.022);
        } else if (t == tx) {
            nl = vec3(lr.x > 0.0 ? -1.0 : 1.0, 0.0, 0.0);
            bool door = lr.x > 0.0 && abs(h.z - room_doors.z) < room_doors.w && up < room_heights.y;
            alb = door ? srgb(paint.rgb) : wall;
        } else {
            nl = vec3(0.0, 0.0, lr.z > 0.0 ? -1.0 : 1.0);
            bool door = lr.z > 0.0 && abs(h.x - room_doors.x) < room_doors.y && up < room_heights.y;
            bool cases = lr.z > 0.0 && abs(abs(h.x - room_doors.x) - book_cases.x) < book_cases.y && up < book_cases.z;
            alb = door ? srgb(paint.rgb) : (cases ? vec3(0.046, 0.029, 0.019) : wall);
        }
        vec3 n = vec3(axes.x * nl.x + axes.z * nl.z, nl.y, axes.y * nl.x + axes.w * nl.z);
        vec3 l = light_dir.xyz;
        vec3 sun = room_sun_color(room_sun.x) * light_dir.w * shell_sun.y * max(dot(n, l), 0.0) / PI;
        vec3 c = alb * (room_irradiance(h, n) + (dot(n, l) > 0.0 ? sun * window_light(hw) : vec3(0.0)));
        // The windows, on the window wall.
        if (t != tz || lr.z > 0.0) return c;
        float metre = shell.w;
        // The lobe's widening with distance, and the pixel's own spread of directions (a
        // grooved panel's normals turn fast), so the windows' edges never alias.
        float spread = 0.01 + 1.2 * alpha + 2.0 * px;
        vec2 soft = vec2(1.0, 1.0 + 3.0 * (1.0 - nov)) * (0.01 * metre + t * spread) / metre;
        float half_w = shell_niche.x;
        float rise = shell_niche.w;
        float radius = (half_w * half_w + rise * rise) / (2.0 * rise);
        float arch_mid = shell_niche.y + shell_niche.z + rise - radius;
        vec2 nw = -axes.zw;
        float toward = max(dot(r.xz, nw), 1e-3);
        vec3 qg = p + r * ((shell.y + shell_glass.x - dot(p.xz, nw)) / toward);
        vec3 view = lace_light.rgb / max(params.x * shade.w, 1e-3);
        vec3 bars = srgb(paint.rgb) * 0.12;
        float cover = 0.0;
        vec3 win = vec3(0.0);
        for (int i = 0; i < 3; i++) {
            if (float(i) >= shell.x) break;
            float mid = shell_mids[i];
            vec2 w = vec2(dot(hw.xz, axes.xy) - mid, hw.y - shell.z) / metre;
            float head = arch_mid + sqrt(max(radius * radius - w.x * w.x, 0.0));
            float rect = smoothstep(-soft.x, soft.x, half_w - abs(w.x))
                       * smoothstep(-soft.y, soft.y, min(w.y - shell_niche.y, head - w.y));
            if (rect < 0.001) continue;
            vec2 wg = vec2(dot(qg.xz, axes.xy) - mid, qg.y - shell.z) / metre;
            win += rect * mix(bars, view, casement(wg, max(soft.x, soft.y)));
            cover += rect;
        }
        return mix(c, win / max(cover, 1e-4), min(cover, 1.0));
    }

    // What a glossy surface sees along r through a GGX lobe alpha wide: the room seen
    // (room_seen) while the lobe is narrow, toward the room's light that way (room_wide) as
    // the lobe widens. Only the metals and, without the mirror, the floor (SHARP_BOX): a
    // surface not a metal has px 1, so the rest take room_wide, which this is for them.
    vec3 room_reflection(vec3 p, vec3 lp, vec3 r, float alpha, float nov, float px) {
        vec3 wide = room_wide(lp, r);
        float sharp = (1.0 - smoothstep(0.08, 0.45, alpha)) * (1.0 - smoothstep(0.05, 0.2, px));
        if (sharp < 0.001) return wide;
        vec3 lr = vec3(dot(r.xz, axes.xy), r.y, dot(r.xz, axes.zw));
        return mix(wide, room_seen(p, lp, r, lr, alpha, nov, px), sharp);
    }
    #endif

    #ifdef PLANAR_FLOOR
    // The floor's mirror (planar_map) along r from p on the floor, a GGX lobe alpha wide, at
    // nov: what the flat floor shows here says how far along the reflection it stands; that
    // point seen along r (each board's own tilt) is mirrored under the floor and found in the
    // map, blurred as wide as the lobe is there (contact sharp, a door's head smeared) and
    // drawn out down the screen by 1 / nov, as a grazing look stretches a waxed floor's
    // reflections into streaks. The blur is five taps down the screen of one mip, the mip
    // chosen from the widths alone, so it grows smoothly with the distance and never jumps
    // as the eye moves (no screen derivatives, no anisotropic filter picking its own taps).
    // a: how much of it lies in the map (the mirror shows only what the screen frames; its
    // edge held a little way past).
    const float PLANAR_LEAST_ACROSS = 3.0;
    const float PLANAR_LEAST_DOWN = 6.0;
    vec4 planar_seen(vec3 p, vec3 r, float alpha, float nov) {
        vec2 uv0 = gl_FragCoord.xy / screen.xy;
        // The distance from a mip over the pixel's neighbours, so the point found doesn't jump
        // where the map's distances do (a door's foot over the wall behind it).
        float t = textureLod(planar_map, uv0, 2.0).a;
        vec3 q = p + r * t;
        vec3 under = vec3(q.x, 2.0 * table.y - q.y, q.z);
        vec4 c = view_proj * vec4(under, 1.0);
        vec2 uv = vec2(0.5, -0.5) * c.xy / max(c.w, 1e-3) + 0.5;
        // The lobe's width where it meets what it shows, in the map's texels.
        float across = 4.0 * alpha * t * planar.z / max(c.w, 1e-3);
        // At least PLANAR_LEAST_ACROSS of the map's texels across and PLANAR_LEAST_DOWN down
        // the screen: it is drawn without antialiasing, so a window's bars a texel or two
        // wide step and flicker as the eye moves under a sharper read. Its texels may be
        // narrower than tall (render3d::planar_size_of): the width down is taken in its own.
        vec2 texel = 1.0 / vec2(textureSize(planar_map, 0));
        float wide = max(across * max(nov, 0.06), PLANAR_LEAST_ACROSS);
        float down = max(across * screen.x * texel.x / (screen.y * texel.y), PLANAR_LEAST_DOWN);
        // A mip whose texel is half the width across and a quarter of the streak's step.
        float lod = clamp(log2(max(wide * 0.5, down * 0.25)), 0.0, planar.w);
        vec3 seen = vec3(0.0);
        for (int k = 0; k < 5; k++) {
            float w = k == 2 ? 3.0 : (k == 1 || k == 3 ? 2.0 : 1.0);
            vec2 at = uv + vec2(0.0, (float(k) - 2.0) * 0.25 * down * texel.y);
            seen += w * textureLod(planar_map, clamp(at, 0.0, 1.0), lod).rgb;
        }
        seen /= 9.0;
        vec2 out_of = max(max(-uv, uv - 1.0), vec2(0.0));
        float a = 1.0 - smoothstep(0.0, 0.1, max(out_of.x, out_of.y));
        // A map read gone wrong never shows as black: the room's box takes its place.
        float y = dot(seen, vec3(0.2126, 0.7152, 0.0722));
        return y >= 0.0 && y <= 1e4 ? vec4(seen, a) : vec4(0.0);
    }
    #endif

    // An albedo made lighter or darker by t.x and greyer or more coloured by t.y about its
    // luminance (a tuner's tint).
    vec3 tinted(vec3 a, vec2 t) {
        float l = dot(a, vec3(0.2126, 0.7152, 0.0722));
        return max(mix(vec3(l), a, t.y), vec3(0.0)) * t.x;
    }

    // The bookcases' own shade on the sun (model3d's bookcases.goose): a point inside a
    // case (lp, the room's frame) sees the sun only where the ray to it leaves by the open
    // front, between the case's ends and either side of its middle upright, under the
    // shelf over it, and over the books: a block from the shelf's front back over 55% of
    // its depth, up to 6 cm under the shelf over it (the books' own tops and spines are in
    // it and see the sun as before). The compartments' tops (metres over the
    // floor) and the base's and upper case's depths are bookcases.goose's; a centimetre's
    // penumbra, two over the books' ragged tops.
    const float CASE_TOPS[7] = float[7](0.669, 1.165, 1.562, 1.859, 2.151, 2.438, 2.668);
    float case_shade(vec3 lp, vec3 l) {
        float m = shell.w;
        float up = (lp.y - shell.z) / m;
        float out_of = (room_box.w - lp.z) / m;
        float depth = up < 1.165 ? 0.45 : 0.30;
        if (book_cases.y <= 0.0 || up > book_cases.z || out_of > depth) return 1.0;
        float d = lp.x - room_doors.x;
        float off = (d - sign(d) * book_cases.x) / m;
        float half_w = book_cases.y / m;
        if (abs(off) > half_w) return 1.0;
        vec2 lh = vec2(dot(l.xz, axes.xy), dot(l.xz, axes.zw));
        if (lh.y > -1e-3) return 0.0;
        float s = (depth - out_of) / -lh.y;
        float x = off + lh.x * s;
        float y = up + l.y * s;
        int k = 6;
        for (int i = 5; i >= 0; i--) if (up < CASE_TOPS[i]) k = i;
        float top = CASE_TOPS[k];
        float lit = smoothstep(0.0, 0.01, top - y) * smoothstep(0.0, 0.01, half_w - 0.06 - abs(x));
        float books_back = 0.45 * depth;
        if (out_of < books_back) lit *= smoothstep(-0.02, 0.0, up + l.y * (books_back - out_of) / -lh.y - (top - 0.06));
        if (abs(off) > 0.011) lit *= smoothstep(-0.01, 0.0, x * sign(off) - 0.011);
        return lit;
    }

    #ifndef NO_SSAO
    #ifndef ROOM_WINDOW
    // The sun's contact shadow at p (the world's; ng its face's normal, l toward the sun):
    // a short ray toward the sun marched over the half-size map of where the screen's
    // surfaces are (pre_place); a step behind what is drawn there, by more than a bias and
    // less than contact.w, is in shade: a moulding's or a frame's thin shadow, which the
    // window's pattern can't cast. Counted by a uniform (contact.z), so it isn't unrolled.
    // slope: how fast the distance from the eye changes over a pixel here (fwidth), which a
    // half-size texel doubles: a floor seen at a slant needs that much more bias.
    float contact_lit(vec3 p, vec3 ng, vec3 l, float slope) {
        vec2 size = vec2(textureSize(pre_place, 0));
        int steps = int(contact.z);
        // contact.z's fraction over 0.25: the map read bilinear, its stairs smoothed.
        bool contact_smooth = fract(contact.z) > 0.25;
        float dt = contact.y / contact.z;
        float j = fract(dot(floor(gl_FragCoord.xy), vec2(0.375, 0.6875)));
        vec3 o = p + ng * 0.03;
        for (int i = 0; i < steps; i++) {
            vec3 q = o + l * (dt * (float(i) + 0.5 + 0.5 * j));
            vec4 c = view_proj * vec4(q, 1.0);
            if (c.w <= 0.0) break;
            vec2 uv = vec2(0.5, -0.5) * c.xy / c.w + 0.5;
            if (uv.x < 0.0 || uv.y < 0.0 || uv.x >= 1.0 || uv.y >= 1.0) break;
            vec4 s = contact_smooth ? textureLod(pre_place, uv, 0.0) : texelFetch(pre_place, ivec2(uv * size), 0);
            if (s.w <= 0.0) continue;
            float dq = length(q - eye.xyz);
            float behind = dq - length(s.xyz);
            if (behind > max(max(0.002 * dq, 0.03), 3.0 * slope) && behind < contact.w) return 1.0 - contact.x * s.w;
        }
        return 1.0;
    }
    #endif
    #endif

    // How much of the sky the table's base hides from p on the floor: its drum and each leg
    // as spheres along it (Quilez's sphere occlusion: a sphere of radius r at distance d,
    // as high over p as h, hides r² h / d³ of it), the nearest point of each leg's three
    // pieces taken, so the scroll standing on the floor darkens it most, tight round its toe.
    float base_hides(vec3 p) {
        vec3 a = vec3(p.x, p.y - table.y, p.z - TABLE_Z);
        if (dot(a.xz, a.xz) > 196.0 || a.y > 6.0) return 0.0;
        vec3 drum = vec3(0.0, 4.9, 0.0) - a;
        float hidden = 4.8 * max(drum.y, 0.0) / pow(max(dot(drum, drum), 0.25), 1.5);
        for (int k = 0; k < 4; k++) {
            float ang = 3.14159265 * (0.25 + 0.5 * float(k));
            vec2 dir = vec2(cos(ang), sin(ang));
            vec3 p0 = vec3(dir.x * LEG1.x, LEG1.y, dir.y * LEG1.x);
            vec3 p1 = vec3(dir.x * LEG2.x, LEG2.y, dir.y * LEG2.x);
            vec3 p2 = vec3(dir.x * LEG3.x, LEG3.y, dir.y * LEG3.x);
            float t0 = clamp(dot(a - p0, p1 - p0) / dot(p1 - p0, p1 - p0), 0.0, 1.0);
            float t1 = clamp(dot(a - p1, p2 - p1) / dot(p2 - p1, p2 - p1), 0.0, 1.0);
            vec3 c0 = p0 + (p1 - p0) * t0 - a;
            vec3 c1 = p1 + (p2 - p1) * t1 - a;
            vec3 c = dot(c0, c0) < dot(c1, c1) ? c0 : c1;
            hidden += LEG_HALF * LEG_HALF * max(c.y, 0.0) / pow(max(dot(c, c), 0.36), 1.5);
        }
        return clamp(hidden, 0.0, 0.8);
    }

    #ifdef ROOM_LACE
    // How much more of the sun the lit lace lets through where it falls on it (window_view.x).
    const float LACE_GLOW = 0.6;
    // The most of the sky the lace sees behind it (room_shell::LACE_SKY_VIEW, its ao).
    const float LACE_SKY_VIEW = 0.6;
    #endif
    #ifdef ROOM_GLASS
    // A kept house's glass, wiped with a cloth: its film, a faint haze of what the cloth left
    // (GLASS_FILM of the sun through it a steradian toward the sun at its mean thickness,
    // more where the tile's wipes left more), scattered forward (Henyey-Greenstein, g 0.75),
    // so it shows only toward the sun; and the fine scratches grit in the cloth drew, each
    // glinting where the sun's light through the glass leaves along the cone round its groove,
    // s = t · (l + v) near 0 (Raymond et al., transmitted), within GLASS_GLINT_REACH radians
    // of the sun, none past about 35° (GLASS_GLINT_FAR, its cosine). Strengths window_view.z and .w; the tile half a millimetre a texel, offset per
    // window and sheet.
    const float GLASS_FILM = 0.0015;
    const float GLASS_GLINT = 0.6;
    const float GLASS_GLINT_WIDTH = 0.02;
    const float GLASS_GLINT_REACH = 0.25;
    const float GLASS_GLINT_FAR = 0.82;
    const float GLASS_TILE_M = 0.512;
    vec3 glass_sun(vec3 p, vec3 v) {
        vec3 l = light_dir.xyz;
        float metre = shell.w;
        float along = dot(p.xz, axes.xy);
        float into = dot(p.xz, axes.zw);
        float k = 0.0;
        for (int i = 1; i < 3; i++) if (abs(along - shell_mids[i]) < abs(along - shell_mids[int(k)])) k = float(i);
        vec2 at = vec2(along, p.y - shell.z) / (metre * GLASS_TILE_M)
                + vec2(window_hash(vec2(k, floor(into * 8.0 / metre))), window_hash(vec2(floor(into * 8.0 / metre), k + 3.0)));
        // Derivatives before the returns below: the tile's, and the view's turn over the pixel,
        // which widens a glint.
        vec2 at_x = dFdx(at);
        vec2 at_y = dFdy(at);
        float turn = length(fwidth(v));
        // Nothing of either shows past GLASS_GLINT_FAR from the sun: skipped there.
        float ahead = clamp(dot(v, -l), -1.0, 1.0);
        float near_sun = smoothstep(GLASS_GLINT_FAR, GLASS_GLINT_FAR + 0.08, ahead);
        if (near_sun <= 0.0) return vec3(0.0);
        float sun = window_open(p) * near_sun;
        if (sun < 0.001) return vec3(0.0);
        vec4 tl = textureGrad(glass_tile, at, at_x, at_y);
        float hg = 0.4375 / pow(1.5625 - 1.5 * ahead, 1.5);
        float film = window_view.z * GLASS_FILM * 2.0 * tl.a * hg / (4.0 * PI);
        // The groove's direction in the glass's plane (along the wall, up), from its doubled angle.
        // atan(0, 0) is NaN on the Mac where no groove is: there any angle does (tl.b is 0).
        vec2 doubled = tl.rg * 2.0 - 1.0;
        float half_a = 0.5 * atan(doubled.y, abs(doubled.x) + abs(doubled.y) > 1e-4 ? doubled.x : 1.0);
        vec3 t = cos(half_a) * vec3(axes.x, 0.0, axes.y) + sin(half_a) * vec3(0.0, 1.0, 0.0);
        float s = dot(t, l + v);
        float w = GLASS_GLINT_WIDTH + turn;
        float glint = window_view.w * GLASS_GLINT * tl.b * exp(-(s / w) * (s / w)) * (GLASS_GLINT_WIDTH / w)
                    * exp(-acos(ahead) / GLASS_GLINT_REACH);
        return room_sun_color(room_sun.x) * light_dir.w * sun * (film + glint / PI);
    }
    // Light added over what the glass shows, in the picture's units: linear in the mirror and
    // the HDR target, else the sRGB curve's slope over a bright sky, about a half.
    vec3 added_light(vec3 c) {
    #ifdef LINEAR_OUT
        return c;
    #else
    #ifdef HDR_OUT
        return c;
    #else
        return 0.5 * c * (1.0 - screen.z);
    #endif
    #endif
    }
    #endif

    #ifndef MIRROR_CHEAP
    void main() {
        vec3 p = v_world;
        vec3 ng = normalize(v_normal);
        float kind = floor(v_extra.y + 0.001);
        float own = v_extra.y - kind;
        // ao: what the mesh and the analytic terms know of the indirect light hidden; fine:
        // the surface's own narrow lines (the floor's joints, the plinth's lip), which the
        // half-size occlusion can't see; screen_ao: the screen's occlusion (SSAO_FN).
        float ao = clamp(v_extra.x, 0.0, 1.0);
        float fine = 1.0;
        float screen_ao = ssao_at(p);
    #ifndef NO_SSAO
        float eye_slope = fwidth(length(p - eye.xyz));
    #endif
    #ifdef PLANAR_FLOOR
        // The floor's mirror on this board: its own wax, none in the joints.
        float wax = 1.0;
        // The wax's film over the boards: it follows each board's tilt and cup, and only a
        // little of the grain's relief, which it fills.
        vec3 n_film = ng;
        float dull = 0.0;
    #endif
    #ifdef ROOM_WINDOW
        // Blend over the scene using premultiplied colour.
        vec3 v = normalize(eye.xyz - p);
        vec3 nf = dot(ng, v) >= 0.0 ? ng : -ng;
        vec3 c;
        float a;
    #ifdef ROOM_GLASS
        // Light the glass adds over what is behind it, its coverage unchanged.
        vec3 added = vec3(0.0);
        // The glass: the room's light reflected, by Fresnel; two sheets, each faint,
        // so the window stays clear close up.
        float fres = 0.04 + 0.96 * pow(1.0 - clamp(dot(nf, v), 0.0, 1.0), 5.0);
        c = sh_eval(reflect(-v, nf)) * params.z;
        a = clamp(0.6 * fres, 0.0, 0.5);
        if (window_view.z + window_view.w > 0.0) added = glass_sun(p, v);
    #else
        // The lace: its coverage, denser where the eye looks through it at a slant (the
        // folds' flanks); lit from the room's side, and through from the window's: the
        // sun on its back with the bars' and leaves' shadows, scattered forward where
        // its thin parts stand between the eye and the sun (Henyey-Greenstein, g 0.5,
        // over even scattering), and the sky and park behind the niche, as much of
        // them as it sees (v_extra.x).
        vec2 lg = vec2(1.0, -1024.0 / 1408.0) / tile.z;
        float cover = textureGrad(lace_mask, lace_place(v_uv), dFdx(v_uv) * lg, dFdy(v_uv) * lg).r;
        if (cover < 0.02) discard;
        a = 1.0 - pow(1.0 - 0.8 * cover, 1.0 / max(abs(dot(nf, v)), 0.5));
        vec3 l = light_dir.xyz;
        vec3 light = room_sun_color(room_sun.x) * light_dir.w;
        // The sun on its back, the bars' and leaves' shadows on it: as the room's shade
        // lifts them, or with window_view.x their own, full, and the lit cloth glowing
        // (LACE_GLOW more of the sun through where it falls).
        float open = room.y > 0.0 ? window_open(p) : 1.0;
        float sun = mix(mix(1.0 - room.y, 1.0, open), open, window_view.x);
        float glow = 1.0 + window_view.x * LACE_GLOW * open;
        float ahead = clamp(dot(v, -l), -1.0, 1.0);
        float hg = 0.75 / pow(1.25 - ahead, 1.5);
        vec3 through = shell_glass.w * (max(-dot(nf, l), 0.0) * sun * glow * light / PI * (1.0 + lace_light.w * (1.0 - cover) * hg)
                                        + lace_light.rgb * ao);
        // The room's fill, less in the shade, where neither the sun nor the sky behind
        // the niche (ao over its most, LACE_SKY_VIEW) reaches it, and less in the folds'
        // valleys (v_corner.x: what the folds beside it hide, room_shell::fold_hidden).
        float reached = max(open, clamp(ao / LACE_SKY_VIEW, 0.0, 1.0));
        float fill = mix(lace_shade.x, 1.0, reached) * (1.0 - lace_shade.y * clamp(v_corner.x, 0.0, 1.0));
        vec3 front = max(dot(nf, l), 0.0) * sun * light / PI + (sh_eval(nf) * params.z + shade.rgb) * fill * ssao_kept(screen_ao);
        c = srgb(lace_thread.rgb) * (front + through);
    #endif
        result = room_out(c * params.x * shade.w, a);
    #ifdef ROOM_GLASS
        result.rgb += added_light(added * params.x * shade.w);
    #endif
    #ifdef ROOM_VIEWS
        if (ssao.y > 0.5 && ssao.y < 2.5) result = vec4(vec3(ssao.y > 1.5 ? ssao_kept(screen_ao) : screen_ao) * a, a);
    #endif
    #else
        vec3 albedo;
        float rough;
        float metal = 0.0;
        vec3 n = ng;
        vec3 u_dir = vec3(axes.x, 0.0, axes.y);
        vec3 v_dir = vec3(axes.z, 0.0, axes.w);
    #ifdef ROOM_FLOOR
        {
            // The floor.
            vec2 uv = v_uv;
            float w = plank.x;
            Plank pk = plank_at(uv / w);
            vec2 id = pk.id + vec2(0.0, 977.0 * pk.up);
            float flip_a = h12(id * 1.7 + 1.2) < 0.5 ? 1.0 : -1.0;
            float flip_l = h12(id * 2.3 + 7.7) < 0.5 ? 1.0 : -1.0;
            // Its place in the floor's field: a strip, a place along it, mirrored.
            float len = plank.y * w;
            float strip = floor(h12(id + 3.1) * FLOOR_STRIPS);
            float fa = flip_a > 0.0 ? pk.across : 1.0 - pk.across;
            float fl = flip_l > 0.0 ? pk.along : plank.y - pk.along;
            vec2 fp = vec2((strip + fa) * w, 0.1 + h12(id + 9.4) * (place.z - len - 0.2) + fl * w);
            // The field's gradients from the floor's, turned into the plank's frame, so the
            // filter has no seam where one plank meets the next.
            vec2 dx = dFdx(uv);
            vec2 dy = dFdy(uv);
            vec2 ax = vec2(dx.x - dx.y, dx.x + dx.y) * 0.70710678;
            vec2 ay = vec2(dy.x - dy.y, dy.x + dy.y) * 0.70710678;
            vec2 sgn = vec2(flip_a, flip_l);
            vec2 gx = (pk.up > 0.5 ? ax : ax.yx) * sgn / place.z;
            vec2 gy = (pk.up > 0.5 ? ay : ay.yx) * sgn / place.z;
            vec4 a4 = textureGrad(floor_albedo, fp / place.z, gx, gy);
            vec4 n4 = textureGrad(floor_normal, fp / place.z, gx, gy);
            albedo = a4.rgb;
            rough = a4.a;
            // Each plank from its own tree: lighter or darker, warmer or greyer; a few
            // patched with newer oak, paler, less ambered.
            float tone = (h12(id + 5.5) - 0.5) * 2.0 * planks.x;
            float warm = h12(id + 8.8) - 0.5;
            albedo *= exp(tone) * vec3(1.0 + 0.1 * warm, 1.0, 1.0 - 0.14 * warm);
            float patched = step(h12(id + 12.3), planks.y);
            albedo *= mix(vec3(1.0), vec3(1.3, 1.2, 1.02), patched);
            rough += 0.06 * patched;
            // The plank's directions in the room: along and across, in u and v.
            vec2 dir_l = pk.up > 0.5 ? vec2(0.70710678, 0.70710678) : vec2(0.70710678, -0.70710678);
            vec2 dir_a = pk.up > 0.5 ? vec2(0.70710678, -0.70710678) : vec2(0.70710678, 0.70710678);
            // The normal: the field's relief (x across, z along, mirrored as the plank is),
            // the plank's tilt, and its cup, the edges higher than the middle.
            vec2 t = (n4.xy * 2.0 - 1.0) * sgn;
            float cup = -plank.w * (2.0 * pk.across - 1.0);
            vec2 tilt = planks.z * (vec2(h12(id + 14.1), h12(id + 15.7)) * 2.0 - 1.0);
            vec2 s = vec2(t.x + cup + tilt.x, t.y + tilt.y);
            vec2 suv = dir_a * s.x + dir_l * s.y;
            n = normalize(vec3(0.0, 1.0, 0.0) + u_dir * suv.x + v_dir * suv.y);
        #ifdef PLANAR_FLOOR
            vec2 sf = vec2(0.25 * t.x + cup + tilt.x, 0.25 * t.y + tilt.y);
            vec2 sfuv = dir_a * sf.x + dir_l * sf.y;
            n_film = normalize(vec3(0.0, 1.0, 0.0) + u_dir * sfuv.x + v_dir * sfuv.y);
        #endif
            // The joints, open a little and dark with old wax.
            float fpw = max(length(dx), length(dy));
            float d_a = min(pk.across, 1.0 - pk.across) * w;
            float d_l = min(pk.along, plank.y - pk.along) * w;
            float joint = max(line_cover(d_a, plank.z, fpw), line_cover(d_l, plank.z, fpw));
            // Worn: the paths round the table and along the room lighter and duller, the
            // floor along the walls darker under more wax.
            float r = length(p.xz - vec2(0.0, TABLE_Z));
            float around = smoothstep(table.x + 1.0, table.x + 6.0, r)
                         * (1.0 - smoothstep(table.x + 0.4 * worn.z, table.x + worn.z, r));
            float lane = worn.w * (1.0 - smoothstep(6.0, 22.0, abs(uv.y - 0.55 * place.y)));
            float wall = max(1.0 - smoothstep(4.0, 20.0, place.y - uv.y), 1.0 - smoothstep(4.0, 16.0, uv.y + place.x));
            // The shell's floor: darker along the nearest of its four walls, doorways too.
            float to_wall = min(min(place.y - uv.y, uv.x - shell_ends.y), min(uv.y + place.x, shell_ends.x - uv.x));
            if (shell.x > 0.5) wall = 1.0 - smoothstep(4.0, 20.0, to_wall);
            // The slow noises, a world unit a texel round the board's middle.
            vec2 slow = textureLod(floor_noise, uv / FLOOR_NOISE_SIDE + 0.5, 0.0).rg;
            float patchy = slow.r;
            float wear = clamp(max(around, lane) * (0.3 + 1.2 * patchy), 0.0, 1.0) * worn.x * (1.0 - wall);
            albedo *= mix(vec3(1.0), vec3(1.6, 1.45, 1.25), wear);
            rough += 0.25 * wear;
            albedo *= 1.0 - 0.22 * wall * worn.y;
            rough -= 0.08 * wall * worn.y;
            // The scratches: short straight hairlines, most along the room (the way people
            // walk), from their repeating tile (surfaces::scratch_tile).
            float sc = textureGrad(scratch_tile, uv / SCRATCH_TILE, dx / SCRATCH_TILE, dy / SCRATCH_TILE).r * planks.w * (0.35 + wear);
            albedo *= 1.0 + 0.4 * sc;
            rough += 0.3 * sc;
            albedo = mix(albedo, albedo * vec3(0.22, 0.18, 0.16), joint);
            rough = mix(rough, 0.6, joint);
            fine *= 1.0 - 0.5 * joint;
        #ifdef PLANAR_FLOOR
            // Each board waxed and worn a little its own way: its mirror stronger or weaker,
            // and sharper or softer, so the reflection steps from board to board.
            float own_wax = (h12(id + 21.7) * 2.0 - 1.0) * planar_look.x;
            // The film worn thin where feet go (the paths, the scratches), in slow patches
            // waxed less, and over the grain's open pores: there the oak's own rough sheen
            // shows through it (planar_floor's blur), a little weaker, so the window's
            // bright sheen shows the floor's surface.
            float pores = clamp(length(t) * 3.0, 0.0, 1.0);
            float patches = smoothstep(0.35, 0.75, slow.g);
            dull = clamp(0.6 * wear + 0.4 * sc + 0.35 * pores + 0.4 * patches, 0.0, 1.0);
            wax = (1.0 + own_wax) * (1.0 - joint) * (1.0 - 0.3 * dull);
            rough *= 1.0 - 0.4 * own_wax;
        #endif
            // The table hides the sky under it, its scroll toes the floor they stand on,
            // and the walls along their feet. In the room the top's broad shade is the
            // probes' and the screen's: only the base's contact stays here.
            if (table_map[3].x < 0.5) ao *= mix(0.55, 1.0, smoothstep(0.5625 * table.x, 1.375 * table.x, r));
            ao *= 1.0 - base_hides(p);
            if (shell.x > 0.5) {
                // A dark contact line at the plinth's lip (5 cm out); the walls' broader shade
                // is the corners' map's.
                fine *= mix(0.4, 1.0, smoothstep(0.0, 0.015 * shell.w, to_wall - 0.05 * shell.w));
            } else {
                ao *= mix(0.6, 1.0, smoothstep(0.0, 8.0, place.y - uv.y)) * mix(0.7, 1.0, smoothstep(0.0, 8.0, uv.y + place.x));
            }
        }
    #endif
    #ifdef ROOM_WALLS
        if (kind < 5.5) {
            // The panelling: the wall's field at the piece's place,
            // the normal by the field's frame worked out from the derivatives.
            vec2 fuv = v_uv / place.w;
            vec4 a4 = texture(wall_albedo, fuv);
            vec4 n4 = texture(wall_normal, fuv);
            albedo = a4.rgb * (1.0 + 0.16 * (own - 0.5));
            if (table.z > 0.0) albedo = tinted(albedo, table.zw);
            rough = a4.a;
            // A door's threshold (shell_mesh's THRESHOLD_OWN): oak worn paler than the
            // stained panelling, and polished smoother by feet.
            if (own > 0.925) {
                albedo *= vec3(1.45, 1.38, 1.25);
                rough *= 0.8;
            }
            vec3 dpx = dFdx(p);
            vec3 dpy = dFdy(p);
            vec2 dux = dFdx(v_uv);
            vec2 duy = dFdy(v_uv);
            vec3 c2 = cross(dpy, ng);
            vec3 c1 = cross(ng, dpx);
            vec3 tx = c2 * dux.x + c1 * duy.x;
            vec3 ty = c2 * dux.y + c1 * duy.y;
            float k = inversesqrt(max(max(dot(tx, tx), dot(ty, ty)), 1e-12));
            vec2 t = n4.xy * 2.0 - 1.0;
            n = normalize(ng * sqrt(max(1.0 - dot(t, t), 0.0)) + (tx * t.x + ty * t.y) * k);
            // Grime where the pieces meet, in the corners and grooves.
            albedo *= mix(0.55, 1.0, smoothstep(0.5, 1.0, ao));
            rough += 0.15 * (1.0 - ao);
        } else if (kind < 6.5) {
            // The wallpaper: its mask, tiled along the wall and up it (the image's top up),
            // from the ground to the gold print.
            float m = texture(paper_mask, vec2(v_uv.x, -v_uv.y) / tile.x).r;
            albedo = mix(srgb(paper.rgb), srgb(gold.rgb), m);
            rough = mix(paper.a, gold.a, m);
        } else if (kind < 8.5) {
            // The shell's lime plaster: its tone laid on the face's plane in the room's frame,
            // a slow noise over it so the 4 m tile's patches don't repeat; the cornice (own
            // 0.5) a little whiter and smoother.
            vec3 ln = abs(vec3(dot(ng.xz, axes.xy), ng.y, dot(ng.xz, axes.zw)));
            vec2 pl = ln.y > max(ln.x, ln.z) ? v_local.xz : (ln.x > ln.z ? v_local.zy : v_local.xy);
            float slow = 0.6 * vnoise(pl / 52.0 + 1.7) + 0.4 * vnoise(pl / 23.0 + 8.3);
            float tone = clamp(texture(plaster_tone, pl / tile.y).r + 0.25 * (slow - 0.5), 0.0, 1.0);
            float cornice = step(0.25, own);
            tone = mix(tone, 1.0, 0.35 * cornice);
            // The ceiling and its cornice, from the cornice's foot up (shell::CORNICE_DROP),
            // their own limewash.
            bool above = p.y > room_heights.x - 0.27 * shell.w;
            vec4 lime_shade = above ? ceiling_shade : plaster_shade;
            vec4 lime_light = above ? ceiling_light : plaster_light;
            albedo = mix(srgb(lime_shade.rgb), srgb(lime_light.rgb), tone);
            rough = mix(lime_shade.a, lime_light.a, tone) - 0.05 * cornice;
            if (shell_sun.z > 0.0 && above) albedo = tinted(albedo, shell_sun.zw);
        } else {
            // The curtains' cotton cord.
            // Its three strands twisted round it (v_uv: round it, metres along
            // it), the tassels' threads straight down (own 0.5); faded out where a
            // strand is under a pixel or two, to the strands' mean (0.91). Its colour the
            // lace's thread a shade deeper, half its linear albedo: opaque, at three
            // quarters it read white beside the lace, which shows only as much of its
            // thread as it covers.
            float twist = own > 0.25 ? 16.0 * v_uv.x : 3.0 * v_uv.x + v_uv.y / 0.03;
            float f = fract(twist);
            float strand = smoothstep(0.0, 0.3, f) * (1.0 - smoothstep(0.7, 1.0, f));
            float seen = 1.0 - smoothstep(0.25, 0.6, fwidth(twist));
            albedo = srgb(lace_thread.rgb) * 0.5 * mix(0.91, 0.7 + 0.3 * strand, seen);
            rough = 0.9;
        }
    #endif
    #ifdef ROOM_PAINT
        // Old white oil paint on pine (room_shell's joinery, quiet): flat in colour, each
        // piece's own tone a percent either way (its fraction: a tenth the tone, a tenth
        // more with the grain along the wall, a fifth more on a window), eggshell on the
        // doors and a little duller on the windows; grey-brown dirt in a band along the
        // recesses (v_uv.y, the distance to the nearest, metres) and a hairline where two
        // pieces meet (v_uv.x), both filtered over the pixel.
        // A fillet's normal turns through 90° over a millimetre, so read at a pixel's middle
        // past the strip's edge it runs on far beyond: held within 46° of the strip's own
        // plane, or the arrises shade in dashes.
        vec3 flat_n = normalize(cross(dFdx(p), dFdy(p)));
        flat_n = dot(flat_n, ng) < 0.0 ? -flat_n : flat_n;
        float held = dot(ng, flat_n);
        if (held < 0.7) n = normalize(flat_n * 0.7 + normalize(ng - flat_n * held) * 0.714);
        // Under a pixel or two (the mesh's normal turning most of a fillet's 90°, 1.41, within
        // a pixel) the strip is a few of the pixel's samples, each shaded at the pixel's middle:
        // lit, it dashes and crawls along the edge as the eye moves. There it takes the normal
        // of the face of the two that faces the eye more, the same all along the edge, so the
        // edge resolves as a sharp one does; over three pixels or more it is shaded as it is.
        vec3 nx = dFdx(v_normal);
        vec3 ny = dFdy(v_normal);
        float under = smoothstep(0.8, 2.2, length(nx) + length(ny));
        if (under > 0.0) {
            vec3 dn = dot(nx, nx) > dot(ny, ny) ? nx : ny;
            vec3 across = normalize(dn - flat_n * dot(dn, flat_n));
            vec3 eye_dir = normalize(eye.xyz - p);
            vec3 face_n = normalize(flat_n + (dot(across, eye_dir) > 0.0 ? across : -across));
            n = normalize(mix(n, face_n, under));
        }
        float on_window = step(0.195, own);
        float piece = own - 0.2 * on_window;
        float along = step(0.095, piece);
        float tone = (piece - 0.1 * along) / 0.099;
        float dirt = 1.0 - smoothstep(0.3 * paint_quiet.z - 0.5 * fwidth(v_uv.y), paint_quiet.z + 0.5 * fwidth(v_uv.y), v_uv.y);
        float joint = line_cover(v_uv.x, 0.00015, fwidth(v_uv.x));
        // The doors' panels and architraves step by a few mm, under the screen's occlusion's
        // half-size texel, so its lines crawl along them as the eye moves: off within 2 cm of
        // a recess (all of a panel's ring), back by 4.5; the ring's own occlusion and the dirt
        // shade them. Kept on the windows, whose casements' inner corners it shades.
        screen_ao = mix(1.0, screen_ao, max(on_window, smoothstep(0.02, 0.045, v_uv.y)));
    #ifdef PAINT_STEPS
        dirt *= paint_steps.x;
        joint *= paint_steps.y;
    #endif
        // The relief tile, laid on the face's plane in the room's frame with its grain the
        // piece's (up, or along the wall), a place of its own a piece: its slopes tilt the
        // normal (half as much on a window), its spread widens the sheen, its B makes the
        // sheen uneven over tens of centimetres.
        vec3 ln = abs(vec3(dot(ng.xz, axes.xy), ng.y, dot(ng.xz, axes.zw)));
        bool level_face = ln.y > max(ln.x, ln.z);
        bool on_x = ln.x > ln.z;
        vec2 pl = level_face ? v_local.xz : (on_x ? v_local.zy : v_local.xy);
        vec3 t_h = level_face ? u_dir : (on_x ? v_dir : u_dir);
        vec3 t_v = level_face ? v_dir : vec3(0.0, 1.0, 0.0);
        // room_shell::RELIEF_TILE and RELIEF_SLOPE.
        const float RELIEF_TILE = 0.256;
        const float RELIEF_SLOPE = 0.02;
        vec2 tile_uv = (along > 0.5 ? pl.yx : pl) / (RELIEF_TILE * shell.w) + tone * vec2(0.37, 0.61);
        vec3 t_across = along > 0.5 ? t_v : t_h;
        vec3 t_along = along > 0.5 ? t_h : t_v;
        vec4 relief = texture(paint_tile, tile_uv);
        float strength = abs(paint_quiet.w) * (1.0 - 0.5 * on_window);
    #ifdef PAINT_STEPS
        strength *= paint_steps.z * (1.0 - paint_steps.w);
    #endif
        vec2 slope = (relief.xy * 255.0 - 128.0) / 127.0 * RELIEF_SLOPE * strength;
        n = normalize(n - t_across * slope.x - t_along * slope.y);
        float spread = relief.w * RELIEF_SLOPE * strength;
        albedo = srgb(paint.rgb) * (1.0 + 0.02 * (tone - 0.5));
        albedo *= 1.0 - 0.45 * dirt * (vec3(1.0) - vec3(0.80, 0.76, 0.68));
        albedo *= 1.0 - 0.5 * joint;
        rough = mix(paint_quiet.x, paint_quiet.y, on_window) + 0.1 * dirt + 0.1 * joint;
        rough += 0.04 * strength * (relief.z * 2.0 - 1.0);
        rough = sqrt(rough * rough + 2.0 * spread * spread);
    #ifdef PAINT_STEPS
        if (paint_steps.w > 0.5) {
            // The old paint, as before the quiet one: a little uneven, its normals the mesh's.
            n = ng;
            float m = vnoise(v_local.xz * 0.4 + v_local.y * 0.31);
            albedo = srgb(paint.rgb) * (0.96 + 0.06 * m);
            rough = paint.a + 0.1 * m;
        }
    #endif
    #endif
    #ifdef ROOM_SILL
        {
            // A Vasalemma-type limestone, honed: its speckle (stone_tile) over the stone's
            // colour, worn as a sill wears: polished by hands in a patchy band behind the nose,
            // the nose's top arris eased round (sill.x) with a few small pale chips, the nose
            // darker toward its foot, a line of dust before the inner casement. v_uv: x metres
            // along the wall, y the distance from the arris (metres, back over the top, down
            // the nose and under it below 0; the ends room_shell::SILL_END). The tile lies on
            // the top and the nose unfolded, on the ends on their plane.
            // room_shell's SILL_BOARD and STONE_TILE, and the inner casement's face back from
            // the arris (SILL_NOSE and WINDOW_GLASS.x less the frame's 5 cm).
            const float SILL_BOARD = 0.05;
            const float STONE_TILE = 0.256;
            const float SILL_FRAME = 0.43;
            float t = v_uv.y;
            float on_slab = step(t, 5.0);
            vec3 ln = abs(vec3(dot(ng.xz, axes.xy), ng.y, dot(ng.xz, axes.zw)));
            vec2 at = on_slab > 0.5 ? vec2(v_uv.x, t) : (ln.x > ln.z ? v_local.zy : v_local.xy) / shell.w;
            vec4 tile4 = texture(stone_tile, at / STONE_TILE);
            vec4 on = vec4(1.0);
            float dust_on = 1.0;
        #ifdef SILL_STEPS
            on = sill_steps[0];
            dust_on = sill_steps[1].x;
        #endif
            albedo = srgb(stone.rgb) * mix(1.0, 0.4 + tile4.r, on.x);
            rough = stone.a + on.x * (0.06 * (tile4.a - 0.5) + 0.15 * tile4.g);
            // The band, 0.36 to 1 of sill.y back, its edge and strength in patches.
            float r = sill.x;
            float ft = max(fwidth(t), 1e-5);
            float back = max(t, 0.0) + 0.012 * (2.0 * tile4.b - 1.0);
            float polish = (1.0 - smoothstep(0.36 * sill.y, sill.y, back)) * smoothstep(-1.5 * r, -0.5 * r, t) * (0.7 + 0.3 * tile4.b);
            rough -= 0.22 * polish * on.y;
            // The arris: the normal turned toward it by up to 45° within r of it; under a
            // pixel, spread over the pixel and turned less. A chip in about one 5 cm of it in
            // seven: a flake broken off across it, paler and rougher, its face at an angle of
            // its own; faded as it falls under a pixel.
            float wide = max(r, ft);
            float ease = clamp(1.0 - abs(t) / wide, 0.0, 1.0) * r / wide * on.z * on_slab;
            float cell = floor(v_uv.x / 0.05);
            float fp = max(ft, fwidth(v_uv.x));
            float rad = mix(0.0008, 0.0025, h12(vec2(cell, 7.3)));
            vec2 off = vec2((v_uv.x - (cell + 0.15 + 0.7 * h12(vec2(cell, 5.1))) * 0.05) / 0.6, (t + (0.6 - h12(vec2(cell, 9.9))) * r) * 0.6);
            float chip = (1.0 - smoothstep(rad - 0.5 * fp, rad + 0.5 * fp, length(off))) * step(h12(vec2(cell, 3.7)), 0.15)
                       * min(1.0, rad * rad / (fp * fp)) * on.z * on_slab;
            albedo *= 1.0 + 0.18 * chip;
            rough += 0.2 * chip;
            vec3 dpx = dFdx(p);
            vec3 dpy = dFdy(p);
            vec3 grad = (cross(dpy, ng) * dFdx(t) + cross(ng, dpx) * dFdy(t)) * sign(dot(ng, cross(dpx, dpy)));
            float glen = length(grad);
            if (ease + chip > 0.0 && glen > 1e-8) {
                // Back over the top t grows away from the arris, down the nose toward it (by the
                // face, not t's sign: a pixel's middle past the face's edge reads t past 0).
                vec3 toward = grad * ((ng.y > 0.7 ? -1.0 : 1.0) / glen);
                float angle = mix(0.785 * ease, 0.35 + 0.8 * h12(vec2(cell, 11.3)), chip);
                n = normalize(ng * cos(angle) + toward * sin(angle));
            }
            // The nose darker toward its foot, and under it.
            albedo *= 1.0 - sill.z * smoothstep(0.0, 1.0, clamp(-t / SILL_BOARD, 0.0, 1.0)) * on.w * on_slab;
            // The dust, thickest against the casement's frame, in patches.
            float before = SILL_FRAME - t;
            float dust = exp(-max(before, 0.0) / sill.w) * step(0.0, before) * (0.55 + 0.45 * tile4.b) * dust_on;
            albedo = mix(albedo, srgb(vec3(0.45, 0.43, 0.4)), 0.6 * dust);
            rough = mix(rough, 0.85, dust);
        #ifdef SILL_STEPS
            if (sill_steps[1].y > 0.5) {
                // The old stone, as before the limestone: mottled, its normals the mesh's.
                n = ng;
                float mo = 0.6 * vnoise(v_local.xz * 1.3 + v_local.y * 0.7) + 0.4 * vnoise(v_local.xz * 4.1 + 2.7);
                albedo = srgb(stone.rgb) * (0.93 + 0.12 * mo);
                rough = stone.a + 0.15 * mo;
            }
        #endif
        }
    #endif
    #ifdef ROOM_METALS
        if (kind > 13.5) {
            // A book (model3d::books): its code in its fraction, the cover (32), the label
            // (4), ink rather than gilt, its fade. The spine's mask colours it as
            // tools/materials/books.py's colour() does, in sRGB: the label over the cover,
            // the tone, the wear rubbed lighter, the gilt or ink over all; the boards' sides
            // the cover; the page edges plain or sprinkled. The sun fades leather and cloth
            // toward a dull brown, the gilt less.
            float code = floor(own * books.z);
            vec3 cover = book_cover[int(mod(code, 32.0))].rgb;
            float ink = mod(floor(code / 128.0), 2.0);
            float fade = floor(code / 256.0) * books.y * books.x;
            vec3 c;
            float g = 0.0;
            if (v_uv.x >= 0.0) {
                vec4 m = texture(book_atlas, v_uv);
                c = mix(cover, book_label[int(mod(floor(code / 32.0), 4.0))].rgb, m.b);
                c *= 0.4 + 1.0 * m.r;
                c = mix(c, c * 0.75 + vec3(0.105, 0.0825, 0.06), 0.6 * m.a);
                g = m.g;
                c = mix(c, book_label[4 + int(ink)].rgb * (0.85 + 0.3 * m.r), g);
                rough = mix(0.62, ink > 0.5 ? 0.75 : 0.38, g) + 0.12 * m.a;
                metal = ink > 0.5 ? 0.0 : 0.8 * g;
            } else if (v_uv.y > -1.5) {
                c = cover * 0.8;
                rough = 0.65;
            } else {
                c = book_label[v_uv.y < -2.5 ? 7 : 6].rgb;
                rough = 0.85;
            }
            float lum = dot(c, vec3(0.3, 0.59, 0.11));
            c = mix(c, lum * vec3(1.08, 0.98, 0.82) + 0.06, fade * (1.0 - 0.6 * g));
            albedo = srgb(clamp(c, 0.0, 1.0));
        } else {
            // The curtains' brass, a metal.
            albedo = srgb(brass.rgb);
            rough = brass.a;
            metal = 1.0;
        }
    #endif

        vec3 v = normalize(eye.xyz - p);
        vec3 l = light_dir.xyz;
        float nol = dot(n, l);
        float diff = clamp(nol, 0.0, 1.0);
        // The panelling oak takes its own share of the sun, at its own saturation
        // (render3d::room_sun).
    #ifdef ROOM_WALLS
        bool oak = kind < 5.5;
    #else
        bool oak = false;
    #endif
        vec3 light = oak ? room_sun_color(room_sun.z) * (light_dir.w * shell_sun.y * room_sun.y)
                         : room_sun_color(room_sun.x) * (light_dir.w * shell_sun.y);
        // The room's corners and edges, its indirect light only (not the books, which the
        // cases shade themselves), baked into its map (model3d::corner_map). The screen's
        // occlusion only where it finds more than these know, so the box's planes and the
        // cases' shelves aren't darkened twice.
        float corner = 1.0;
        if (kind < 13.5 && shell.x > 0.5) {
            vec2 size = vec2(textureSize(corner_map, 0));
            vec2 lo = vec2(mod(v_box.x, 4096.0), floor(v_box.x / 4096.0)) + 0.5;
            vec2 hi = vec2(mod(v_box.y, 4096.0), floor(v_box.y / 4096.0)) + 0.5;
            corner = texture(corner_map, clamp(v_corner * size, lo, hi) / size).r;
        }
        ao = metal > 0.9 ? ao : fine * min(ao * corner, ssao_kept(screen_ao));
        // The table's top is solid: its shadow keeps all the key out, unlike the board's
        // softened ones (room.x). The sun reaches p only through a window (open), and only
        // that takes the highlight; the shade's floor (window_light's, 1 - room.y where the
        // sun doesn't reach) stands for light the room throws back, so it takes the
        // occlusion as the room's other indirect light does.
    #ifdef FLOOR_NO_TABLE
        float table_kept = 1.0;
    #else
        float table_kept = table_map[3].x > 0.5 ? table_map_at(p + ng * 0.06) : table_shade(p, l);
    #endif
        float kept = dot(ng, l) > 0.0 ? table_kept * case_shade(v_local, l) : 0.0;
    #ifdef FLOOR_SHADE
        float open = 0.0;
    #else
        float open = kept > 0.0 ? window_open(p) : 0.0;
    #endif
    #ifndef NO_SSAO
    #ifndef ROOM_FLOOR
        // Not on the floor, where it showed nothing and cost the most.
        if (contact.x > 0.0 && open * kept > 0.0 && nol > 0.0) open *= contact_lit(p, ng, l, eye_slope);
    #endif
    #endif
        float fill = room_baked.x > 0.5 ? room_baked.y : 1.0;
        float vis = (room.y > 0.0 ? open + fill * (1.0 - room.y) * (1.0 - open) * ao : 1.0) * kept;
        // In the room a shadow inside the sun's patch takes the sun alone, the table's as
        // the bars': the light thrown back there is the same either side of its edge.
        if (table_map[3].x > 0.5 && room.y > 0.0 && dot(ng, l) > 0.0) {
            float sun_in = open * kept;
            vis = sun_in + fill * (1.0 - room.y) * (1.0 - sun_in) * ao;
        }
        vec3 irr = room_irradiance(v_local, n) * ao;
        vec3 base = albedo * (1.0 - metal) * (diff / PI * light * vis + irr);

        float nov = max(dot(n, v), 1e-4);
        float nl = clamp(nol, 0.0, 1.0);
        vec3 hv = normalize(v + l);
        float noh = clamp(dot(n, hv), 0.0, 1.0);
        float voh = clamp(dot(v, hv), 0.0, 1.0);
        vec3 du = dFdx(n);
        vec3 dv = dFdy(n);
        float variance = 0.15 * (dot(du, du) + dot(dv, dv));
        float ar = clamp(rough, 0.05, 1.0);
        ar = ar * ar;
    #ifdef ROOM_METALS
        // The brass's hinges and levers turn their normals within a few pixels: the lobe
        // widened by the normals' spread over the pixel (Tokuyoshi and Kaplanyan's kernel,
        // its variance half a pixel, at most 0.5), or the highlights break into dashes as the
        // eye moves; the books' gilt as the rest.
        ar = sqrt(clamp(ar * ar + (metal > 0.9 ? min(dot(du, du) + dot(dv, dv), 0.5) : min(2.0 * variance, 0.3)), 0.0, 1.0));
    #else
        ar = sqrt(clamp(ar * ar + min(2.0 * variance, 0.3), 0.0, 1.0));
    #endif
        vec3 f0 = mix(vec3(0.04), albedo, metal);
        // The key is a window, not a point: its highlight no sharper than 0.25's.
        float ak = max(ar, 0.06);
        float lobes = d_ggx(noh, ak) * v_smith(nov, nl, ak);
    #ifdef ROOM_WALLS
        // The sun's broad sheen (sheen): a second, rougher lobe on the painted wood, the
        // paper (sheen.z of it) and the panelling's oak (room_sun.w of it), one Fresnel and
        // one light for both lobes.
        float on = kind > 5.5 && kind < 6.5 ? sheen.z : (oak ? room_sun.w : 0.0);
        float as = max(sheen.y * sheen.y, 0.06);
        lobes += on * sheen.x * d_ggx(noh, as) * v_smith(nov, nl, as);
    #endif
    #ifdef ROOM_PAINT
        float as = max(sheen.y * sheen.y, 0.06);
        lobes += sheen.x * d_ggx(noh, as) * v_smith(nov, nl, as);
    #endif
        vec3 spec = lobes * f_schlick(f0, voh) * nl * light * open * kept;
        // The room's reflection, with the room baked; the harmonics alone before. Only the
        // floor and the metals see the room sharply (SHARP_BOX): the panelling's grain turns
        // its normals too fast for a window's edge to hold.
        vec3 rv = reflect(-v, n);
        float spec_ao = clamp(pow(nov + ao, exp2(-16.0 * ar - 1.0)) - 1.0 + ao, 0.0, 1.0);
    #ifdef PLANAR_FLOOR
        // The floor sees the mirror, through the wax's film over the oak, smoother than the
        // oak's own sheen (planar_look.y of its roughness), blurred by the film's lobe, not by
        // the pixel's spread of normals: a board's tilt moves its image whole. The mirror shows
        // what stands there and hides itself, so no occlusion of its own goes on top; past the
        // screen's edge it fades to the room's light that way.
        float film = clamp(mix(rough * planar_look.y, rough, dull), 0.03, 1.0);
        vec4 seen = planar_seen(p, reflect(-v, n_film), film * film, nov);
        // The room's box only where the mirror doesn't hold all of it (near the screen's edge),
        // so its probes' taps are left out where the mirror covers.
        vec3 env = (seen.a < 1.0 ? mix(room_wide(v_local, rv) * spec_ao, seen.rgb, seen.a) : seen.rgb) * planar.x * wax;
        spec_ao = 1.0;
    #ifdef ROOM_VIEWS
        // The tuner's view of the floor's reflection alone.
        if (planar.y > 0.5) {
            result = vec4(to_srgb(tonemap(env * params.x * shade.w)), 1.0);
            return;
        }
    #endif
        vec3 fc = env_brdf(f0, film, nov);
    #else
    #ifdef SHARP_BOX
    #ifdef ROOM_FLOOR
        float px = length(fwidth(rv));
    #else
        // The brass sees the room sharp over half its pixel's spread of directions (a
        // quarter sparkled on the hinges: the sun's leaves on the walls it shows), the gilt
        // over a quarter.
        float px = metal > 0.5 ? (metal > 0.9 ? 0.5 : 0.25) * length(fwidth(rv)) : 1.0;
    #endif
        vec3 env = room_baked.x > 0.5 ? room_reflection(p, v_local, rv, ar, nov, px) : sh_eval(rv) * params.z;
    #else
        vec3 env = room_baked.x > 0.5 ? room_wide(v_local, rv) : sh_eval(rv) * params.z;
    #endif
        vec3 fc = env_brdf(f0, sqrt(ar), nov);
    #endif
    #ifdef ROOM_METALS
        // Brass in a window's niche (the shutters' hinges) sees the window and the lit reveals
        // the way it faces out, not the room's box behind the glass.
        if (metal > 0.9 && v_local.z < room_box.z)
            env = mix(env, lace_light.rgb / max(params.x * shade.w, 1e-3), clamp(0.6 - dot(rv.xz, axes.zw), 0.15, 1.0));
    #endif
        vec3 color = (base * (1.0 - fc) + spec + env * fc * spec_ao) * params.x * shade.w;
    #ifdef ROOM_VIEWS
        // The tuner's view of the sun's highlights alone, ×4.
        if (sheen.w > 0.5) color = spec * 4.0 * params.x * shade.w;
    #endif
        result = room_out(color, 1.0);
    #ifdef ROOM_VIEWS
        // The tuner's views: the screen's occlusion alone, or all the indirect light keeps.
        if (ssao.y > 0.5) result = vec4(vec3(ssao.y > 1.5 ? ao : screen_ao), 1.0);
        // The tuner's view of the indirect light alone, on a grey of 0.45.
        if (ssao.y > 2.5) result = vec4(to_srgb(tonemap(irr * 0.45 * params.x * shade.w)), 1.0);
    #endif
    #endif
    }
    #else
    // The floor's cheap mirror world (render3d::mirror_cheap, the light tuner's
    // --mirror-cheap): what the wax blurs and fades needs no detail of its own. Each surface
    // at its mean colour (its map's last mip, or its look's colours mixed by their mask's
    // mean), the brass one tint, lit by the baked light and the corners' shade and by the sun
    // through the windows' outlines at the casements' and the lace's mean share
    // (cheap_open); no highlights, no reflections, nothing small (the cord) drawn.
    // How much of a sash its stiles, rails and bars let through (casement's mean over it,
    // two planes' share each): the lower sash's, the upper's, which has more bars.
    const float CHEAP_LOWER_SASH = 0.84;
    const float CHEAP_UPPER_SASH = 0.6;
    // A casement as its blind frame's opening less the transom and the meeting stiles (as
    // casement has them), each sash at its mean.
    float cheap_casement(vec2 w, float soft, float transom) {
        float x = abs(w.x);
        float open = min(0.49 - x, min(w.y - (shell_niche.y + 0.03), (shell_niche.y + shell_niche.z - 0.06) - w.y));
        open = min(open, min(abs(w.y - transom) - 0.045, x - 0.0675));
        return smoothstep(-soft, soft, open) * mix(CHEAP_LOWER_SASH, CHEAP_UPPER_SASH, step(transom, w.y));
    }
    float cheap_open(vec3 p) {
        if (room.y <= 0.0) return 1.0;
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        if (toward < 0.05) return 0.0;
        float metre = shell.w;
        float widen = shell_sun.x > 0.0 ? shell_sun.x : room.z;
        float d = dot(p.xz, nw);
        float half_w = shell_niche.x;
        float rise = shell_niche.w;
        float radius = (half_w * half_w + rise * rise) / (2.0 * rise);
        float arch_mid = shell_niche.y + shell_niche.z + rise - radius;
        float t = max((shell.y - d) / toward, 0.0);
        float tl = (shell.y - shell_glass.z - d) / toward;
        // The transom between the sashes (casement's zt).
        float transom = shell_niche.y + shell_niche.z * 2.0 / 3.0;
        // The lace's mean cover (its mask's last mip), as lace_shadow takes it.
        float cover = mix(0.5, textureLod(lace_mask, vec2(0.5), 20.0).r, LACE_PATTERN_SHOWN);
        float flat_lets = 1.0 - clamp(mix(LACE_NET_STOPS, 1.0 - shell_glass.w, cover), 0.0, 0.9);
        float lit = 0.0;
        for (int i = 0; i < 3; i++) {
            if (float(i) >= shell.x) break;
            float mid = shell_mids[i];
            vec3 q = p + l * t;
            vec2 w = vec2(dot(q.xz, along) - mid, q.y - shell.z) / metre;
            float soft = (0.03 + widen * t) / metre;
            float head = arch_mid + sqrt(max(radius * radius - w.x * w.x, 0.0));
            float through = smoothstep(-soft, soft, min(half_w - abs(w.x), min(w.y - shell_niche.y, head - w.y)));
            if (through < 0.001) continue;
            // The two casements, each its glazed opening at its sash's mean.
            float glazed = 1.0;
            for (int k = 0; k < 2; k++) {
                float tk = (shell.y + (k == 0 ? shell_glass.x : shell_glass.y) - d) / toward;
                if (tk <= 0.0) continue;
                vec3 g = p + l * tk;
                vec2 wg = vec2(dot(g.xz, along) - mid, g.y - shell.z) / metre;
                float soft_g = (0.03 + widen * tk) / metre;
                glazed *= glazing(wg, soft_g);
                through *= cheap_casement(wg, soft_g, transom);
            }
            if (tl > 0.5) {
                vec3 c = p + l * tl;
                vec2 wl = vec2(dot(c.xz, along) - mid, c.y - shell.z) / metre;
                vec2 e = lace_edges(wl.y);
                float x = abs(wl.x);
                float soft_l = (0.03 + widen * tl) / metre + LACE_SOFT * tl / metre;
                float edge = min(min(x - e.x, e.y - x), min(wl.y - 0.07, 3.7 - wl.y));
                float lets = pow(flat_lets, max(0.55 / max(e.y - e.x, 0.05), 1.0));
                float inside = smoothstep(-soft_l, soft_l, edge);
                through = through * mix(1.0, lets, inside)
                        + window_view.y * LACE_FORWARD * LACE_GLAZED * glazed * inside * (1.0 - lets);
            }
            lit += through;
        }
        lit = min(lit, 1.0);
        if (tree.x > 0.0 && lit > 0.001) {
            // The tree's limbs and leaves as one blurred tap of its map.
            float back = d / toward;
            vec2 m = vec2(dot(p.xz, along) - dot(l.xz, along) * back, p.y - l.y * back);
            vec4 tm = textureLod(tree_map, (m - tree.zw) / tree.xy + 0.5, 3.0 + tree_blur.z);
            lit *= tm.a * tm.r * tm.g * tm.b;
        }
        return lit;
    }

    void main() {
        vec3 p = v_world;
        vec3 ng = normalize(v_normal);
    #ifdef CHEAP_TABLE
        // The table: its wood's mean, lit by its own probes on its axis (TABLE_FRAG's
        // room_light_at), the top's shade on the edge and the base, the top's and the
        // column's and legs' on the sun (table_shade).
        vec3 l = light_dir.xyz;
        float ao = clamp(v_ao, 0.0, 1.0);
        vec3 albedo = textureLod(own_albedo, vec2(0.5), 20.0).rgb;
        if (v_mat > 3.5) {
            float from_mid = length(p.xz - vec2(0.0, TABLE_Z));
            float e = (TABLE_TOP - p.y) / max(t_shape.x - from_mid, 0.5);
            ao *= 1.0 - (1.0 - t_pool.z) / (1.0 + e * e) * (0.6 + 0.4 * max(ng.y, 0.0));
        } else {
            ao *= mix(1.0 - t_pool.z, 1.0, smoothstep(TABLE_TOP - 0.6, TABLE_TOP, p.y));
        }
        float k = clamp(((p.y - t_shape.y) / t_shade.w - 0.15) / 0.3, 0.0, 3.0);
        int i = int(min(floor(k), 2.0));
        float f = k - float(i);
        vec3 a = vec3(t_light[3 * i].x + dot(t_light[3 * i].yzw, ng), t_light[3 * i + 1].x + dot(t_light[3 * i + 1].yzw, ng),
                      t_light[3 * i + 2].x + dot(t_light[3 * i + 2].yzw, ng));
        int j = i + 1;
        vec3 b = vec3(t_light[3 * j].x + dot(t_light[3 * j].yzw, ng), t_light[3 * j + 1].x + dot(t_light[3 * j + 1].yzw, ng),
                      t_light[3 * j + 2].x + dot(t_light[3 * j + 2].yzw, ng));
        float over = smoothstep(TABLE_TOP - 0.5, TABLE_TOP, p.y);
        vec3 irr = (max(mix(a, b, f), vec3(0.0)) + sh_eval(ng) * params.z * t_mix.y + t_shade.rgb) * mix(t_mix.z, 1.0, over);
        float nol = dot(ng, l);
        float sun_in = nol > 0.0 ? cheap_open(p) * table_shade(p, l) : 0.0;
        float pattern = mix(sun_in, mix(1.0 - room.y, 1.0, sun_in), t_mix.w);
        vec3 c = albedo * (clamp(nol, 0.0, 1.0) / PI * light_color.rgb * light_dir.w * pattern + irr * ao);
        result = room_out(c * params.x, 1.0);
    #else
        vec3 lp = v_local;
        float kind = floor(v_extra.y + 0.001);
        float own = v_extra.y - kind;
        float ao = clamp(v_extra.x, 0.0, 1.0);
        vec3 albedo;
        bool oak = kind < 5.5;
        if (oak) {
            // The panelling's oak, each piece its own tone, the thresholds paler; its grime.
            albedo = textureLod(own_albedo, vec2(0.5), 20.0).rgb * (1.0 + 0.16 * (own - 0.5));
            if (table.z > 0.0) albedo = tinted(albedo, table.zw);
            if (own > 0.925) albedo *= vec3(1.45, 1.38, 1.25);
            albedo *= mix(0.55, 1.0, smoothstep(0.5, 1.0, ao));
        } else if (kind < 6.5) {
            albedo = mix(srgb(paper.rgb), srgb(gold.rgb), textureLod(paper_mask, vec2(0.5), 20.0).r);
        } else if (kind < 7.5) {
            albedo = srgb(stone.rgb) * (0.4 + textureLod(stone_tile, vec2(0.5), 20.0).r);
        } else if (kind < 8.5) {
            float tone = textureLod(plaster_tone, vec2(0.5), 20.0).r;
            tone = mix(tone, 1.0, 0.35 * step(0.25, own));
            bool above = p.y > room_heights.x - 0.27 * shell.w;
            albedo = above ? mix(srgb(ceiling_shade.rgb), srgb(ceiling_light.rgb), tone)
                           : mix(srgb(plaster_shade.rgb), srgb(plaster_light.rgb), tone);
            if (shell_sun.z > 0.0 && above) albedo = tinted(albedo, shell_sun.zw);
        } else if (kind < 9.5) {
            albedo = srgb(paint.rgb);
        } else if (kind < 13.5) {
            albedo = srgb(brass.rgb);
        } else {
            // A book: its cover, faded as the room's shader fades it.
            float code = floor(own * books.z);
            vec3 c = book_cover[int(mod(code, 32.0))].rgb * 0.8;
            float fade = floor(code / 256.0) * books.y * books.x;
            float lum = dot(c, vec3(0.3, 0.59, 0.11));
            albedo = srgb(clamp(mix(c, lum * vec3(1.08, 0.98, 0.82) + 0.06, fade), 0.0, 1.0));
        }
        if (kind < 13.5 && shell.x > 0.5) {
            vec2 size = vec2(textureSize(corner_map, 0));
            vec2 lo = vec2(mod(v_box.x, 4096.0), floor(v_box.x / 4096.0)) + 0.5;
            vec2 hi = vec2(mod(v_box.y, 4096.0), floor(v_box.y / 4096.0)) + 0.5;
            ao *= texture(corner_map, clamp(v_corner * size, lo, hi) / size).r;
        }
        vec3 l = light_dir.xyz;
        vec3 light = oak ? room_sun_color(room_sun.z) * (light_dir.w * shell_sun.y * room_sun.y)
                         : room_sun_color(room_sun.x) * (light_dir.w * shell_sun.y);
        float nol = dot(ng, l);
        float open = nol > 0.0 ? cheap_open(p) : 0.0;
        float fill = room_baked.x > 0.5 ? room_baked.y : 1.0;
        float vis = room.y > 0.0 ? open + fill * (1.0 - room.y) * (1.0 - open) * ao : 1.0;
        vec3 c = albedo * (max(nol, 0.0) / PI * light * vis + room_irradiance(lp, ng) * ao);
        result = room_out(c * params.x * shade.w, 1.0);
    #endif
    }
    #endif
    """;

// The window's glow (render3d::bloom_pass), no rays: the room's image shrunk to a quarter,
// a 4 × 4 block a pixel from four bilinear taps, only what is brighter than a threshold
// kept, in linear light; blurred across and down (GLOW_BLUR_FRAG); added back over the
// image in linear light (GLOW_ADD_FRAG). Glow: x the threshold (the least channel, sRGB,
// so only near-white glows: the glass, the sky, the backlit lace, not the board's sunlit
// maple), y the knee over it, zw a source texel in uv.
let GLOW_PICK_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform Glow { vec4 glow_pick; };
    void main() {
        vec2 at = floor(gl_FragCoord.xy) * 4.0;
        vec3 c = texture(src, (at + vec2(1.0, 1.0)) * glow_pick.zw).rgb + texture(src, (at + vec2(3.0, 1.0)) * glow_pick.zw).rgb
               + texture(src, (at + vec2(1.0, 3.0)) * glow_pick.zw).rgb + texture(src, (at + vec2(3.0, 3.0)) * glow_pick.zw).rgb;
        c *= 0.25;
        float bright = min(c.r, min(c.g, c.b));
        result = vec4(pow(c, vec3(2.2)) * smoothstep(glow_pick.x, glow_pick.x + glow_pick.y, bright), 1.0);
    }
    """;

// The glow blurred one way: x and y a texel's step in uv, z sigma in texels; w unused; then
// one target pixel in uv.
let GLOW_BLUR_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform GlowBlur { vec4 glow_dir; vec4 glow_px; };
    void main() {
        vec2 uv = gl_FragCoord.xy * glow_px.xy;
        vec3 sum = vec3(0.0);
        float total = 0.0;
        for (int i = -12; i <= 12; i++) {
            float w = exp(-0.5 * float(i * i) / (glow_dir.z * glow_dir.z));
            sum += w * texture(src, uv + float(i) * glow_dir.xy).rgb;
            total += w;
        }
        result = vec4(sum / total, 1.0);
    }
    """;

// The room's ambient occlusion (render3d::ssao_pass): what the screen shows of the room, the
// table and the board drawn at half size into where each pixel is and which way it faces
// (PRE_FRAG); each pixel's share of the sky hidden by what it shows within a reach
// (SSAO_FRAG), blurred over 4 × 4 by distance (SSAO_BLUR_FRAG); read back in ROOM_FRAG and
// TABLE_FRAG's room variant (SSAO_FN) for their indirect light only.

// Where each pixel is from the eye (world units) and how much it hides (w: 1, the lace
// LACE_HIDES, 0 nothing drawn), and its normal toward the eye. With PRE_ROOM the room's
// mesh, whose glass hides nothing.
let PRE_ROOM = "#define PRE_ROOM 1\n";
let PRE_FRAG = """
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    #ifdef PRE_ROOM
    layout(location = 3) in vec2 v_extra;
    #endif
    layout(location = 0) out vec4 pre_place;
    layout(location = 1) out vec4 pre_facing;
    // The lace lets about three quarters through where it hangs flat.
    const float LACE_HIDES = 0.4;
    void main() {
        float hides = 1.0;
    #ifdef PRE_ROOM
        float kind = floor(v_extra.y + 0.001);
        if (kind > 9.5 && kind < 10.5) discard;
        if (kind > 10.5 && kind < 11.5) hides = LACE_HIDES;
    #endif
        vec3 rel = v_world - eye.xyz;
        vec3 n = normalize(v_normal);
        if (dot(n, rel) > 0.0) n = -n;
        pre_place = vec4(rel, hides);
        pre_facing = vec4(n * 0.5 + 0.5, 1.0);
    }
    """;

// Each half-size pixel's occlusion, after McGuire's Alchemy obscurance: SSAO_TAPS points of
// a spiral round it on the screen, out to the reach's size there; each hides as much as it
// stands over the pixel's plane (the cosine of its angle above it, less a bias that keeps a
// flat surface clear), fading to nothing at the reach. Each pixel of a 4 × 4 block turns
// the spiral its own way, so the blur's 4 × 4 takes all sixteen turns and no noise is left.
// ssao_fwd: xyz the clip's w along the view (row 3 of view_proj), w half-size pixels a
// world unit spans at w 1; ssao_look: x the reach (world units), y the bias, z the
// largest spiral (pixels), w the gain. result: r the light kept (1 all), g the distance from
// the eye (0 nothing drawn).
let SSAO_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D pre_place;
    layout(set = 2, binding = 1) uniform sampler2D pre_facing;
    layout(set = 3, binding = 0) uniform Ssao { vec4 ssao_fwd; vec4 ssao_look; };
    const int SSAO_TAPS = 8;
    void main() {
        ivec2 px = ivec2(gl_FragCoord.xy);
        ivec2 size = textureSize(pre_place, 0);
        vec4 c = texelFetch(pre_place, px, 0);
        if (c.w <= 0.0) {
            result = vec4(1.0, 0.0, 0.0, 1.0);
            return;
        }
        float dist = length(c.xyz);
        vec3 n = normalize(texelFetch(pre_facing, px, 0).xyz * 2.0 - 1.0);
        float reach = ssao_look.x;
        float spiral = min(reach * ssao_fwd.w / max(dot(ssao_fwd.xyz, c.xyz), 1e-3), ssao_look.z);
        if (spiral < 1.0) {
            result = vec4(1.0, dist, 0.0, 1.0);
            return;
        }
        int cell = (px.x % 4) + 4 * (px.y % 4);
        float turn = 6.2832 * float(cell) / 16.0;
        float jitter = fract(float(cell) * 0.618034);
        float hidden = 0.0;
        for (int i = 0; i < SSAO_TAPS; i++) {
            float t = (float(i) + jitter) / float(SSAO_TAPS);
            float a = turn + 2.39996 * float(i);
            ivec2 q = px + ivec2(floor(vec2(cos(a), sin(a)) * (t * spiral) + 0.5));
            if (q.x < 0 || q.y < 0 || q.x >= size.x || q.y >= size.y) continue;
            vec4 s = texelFetch(pre_place, q, 0);
            vec3 v = s.xyz - c.xyz;
            float vv = dot(v, v);
            float up = dot(v, n) * inversesqrt(vv + 1e-4);
            hidden += s.w * max(up - ssao_look.y, 0.0) * max(1.0 - vv / (reach * reach), 0.0);
        }
        float kept = clamp(1.0 - ssao_look.w * hidden / float(SSAO_TAPS), 0.0, 1.0);
        result = vec4(kept, dist, 0.0, 1.0);
    }
    """;

// The occlusion blurred over the 4 × 4 block round each pixel (the spiral's sixteen turns),
// each texel by how near its distance from the eye is to the middle's, so an edge keeps
// its sides apart. The block runs from -2 to 1, so texel i holds the occlusion at i, not
// i + 0.5 (SSAO_FN reads it so).
let SSAO_BLUR_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D ssao_raw;
    void main() {
        ivec2 px = ivec2(gl_FragCoord.xy);
        ivec2 last = textureSize(ssao_raw, 0) - 1;
        vec2 c = texelFetch(ssao_raw, px, 0).rg;
        if (c.y <= 0.0) {
            result = vec4(1.0, 0.0, 0.0, 1.0);
            return;
        }
        float sum = 0.0;
        float total = 0.0;
        for (int k = 0; k < 16; k++) {
            ivec2 at = clamp(px + ivec2(k % 4 - 2, k / 4 - 2), ivec2(0), last);
            vec2 s = texelFetch(ssao_raw, at, 0).rg;
            float w = max(1.0 - abs(s.y - c.y) / (0.03 * c.y), 0.0);
            sum += w * s.x;
            total += w;
        }
        result = vec4(sum / max(total, 1e-4), c.y, 0.0, 1.0);
    }
    """;

// The room's occlusion at this pixel, from the half-size map (ssao_map, the block's ssao: x
// how strong, 0 none; y the tuner's views, 1 the occlusion alone, 2 all the indirect light
// keeps; zw the map's texels a pixel): its four texels round the pixel, each by its bilinear
// weight over how far its distance from the eye is from p's, so an edge takes its own side;
// 1 where none is within 5%, as behind the lace. ssao_kept: the light kept at the strength.
// With NO_SSAO (the phone's tier, and the floor's mirror, which draws no map of its own)
// both 1, the map not read.
let SSAO_FN = """
    #ifdef NO_SSAO
    float ssao_at(vec3 p) { return 1.0; }
    float ssao_kept(float raw) { return 1.0; }
    #else
    float ssao_at(vec3 p) {
        if (ssao.x <= 0.0) return 1.0;
        vec2 at = gl_FragCoord.xy * ssao.zw;
        vec2 f = at - floor(at);
        ivec2 i0 = ivec2(floor(at));
        ivec2 last = textureSize(ssao_map, 0) - 1;
        float d = length(p - eye.xyz);
        float sum = 0.0;
        float total = 0.0;
        float nearest = 1.0;
        for (int k = 0; k < 4; k++) {
            ivec2 o = ivec2(k % 2, k / 2);
            vec2 s = texelFetch(ssao_map, clamp(i0 + o, ivec2(0), last), 0).rg;
            float gap = abs(s.y - d) / d;
            nearest = min(nearest, gap);
            float w = ((o.x == 1 ? f.x : 1.0 - f.x) * (o.y == 1 ? f.y : 1.0 - f.y) + 1e-3) / (0.002 + gap);
            sum += w * s.x;
            total += w;
        }
        return nearest > 0.05 ? 1.0 : sum / total;
    }
    float ssao_kept(float raw) { return clamp(1.0 - ssao.x * (1.0 - raw), 0.0, 1.0); }
    #endif
    """;

// ROOM_FRAG's groups, one pipeline each (render3d::room_group), each holding only its
// materials' code: the floor; the walls' surfaces (the panelling oak, the paper, the plaster
// and the ceiling, the cord); the painted wood (the doors and the windows' joinery); the
// sills' stone; the metals (the brass, the books with their gilt); the glass and the lace, a
// mesh of their own, blended.
let ROOM_FLOOR = "#define ROOM_FLOOR 1\n";
let ROOM_WALLS = "#define ROOM_WALLS 1\n";
let ROOM_PAINT = "#define ROOM_PAINT 1\n";
let ROOM_SILL = "#define ROOM_SILL 1\n";
// The sills' shader with the light tuner's switches (render3d::sill_steps).
let SILL_STEPS = "#define SILL_STEPS 1\n";
// The painted wood's shader with the light tuner's switches (render3d::paint_steps).
let PAINT_STEPS = "#define PAINT_STEPS 1\n";
let ROOM_METALS = "#define ROOM_METALS 1\n";
let ROOM_GLASS = "#define ROOM_WINDOW 1\n#define ROOM_GLASS 1\n";
let ROOM_LACE = "#define ROOM_WINDOW 1\n#define ROOM_LACE 1\n";
// The floor that sees the mirror (render3d::planar_shown), the standard and high tiers';
// without it the floor sees the room's box.
let PLANAR_FLOOR = "#define PLANAR_FLOOR 1\n";
// The floor's pieces where the table's map doesn't reach, and of those the ones the sun
// can't reach through the shell's windows (render3d::SunDerived, the latter with both
// defines): without the table's taps and the sun's trace, which the bake proved give nothing
// there.
let FLOOR_SHADE = "#define FLOOR_SHADE 1\n";
let FLOOR_NO_TABLE = "#define FLOOR_NO_TABLE 1\n";
// The room's box seen sharply (room_reflection): the metals outside the mirror, and the
// floor without the mirror. The rest takes room_wide, which room_reflection is for them (a
// surface not a metal has px 1, so sharp 0).
let SHARP_BOX = "#define SHARP_BOX 1\n";
// Without the screen's maps (SSAO_FN's ssao_map and the contact shadows' pre_place): the
// phone's tier, which draws neither (render3d::ssao_allowed).
let NO_SSAO = "#define NO_SSAO 1\n";
// The light out linear (exposed, its peak held to MIRROR_PEAK) in place of tonemapped
// sRGB: ROOM_FRAG's room_out and TABLE_FRAG's end. The floor's mirror's, whose target is
// RGBA16F.
let LINEAR_OUT = "#define LINEAR_OUT 1\n";
// The floor's mirror (render3d::planar_pass): the room seen from under the floor, its light
// linear, without the screen's maps (its block's ssao and contact are 0) and with nothing
// seen sharply (no SHARP_BOX); the floor, under the clip plane, isn't drawn.
let MIRROR_PASS = "#define LINEAR_OUT 1\n#define NO_SSAO 1\n";
// The floor's cheap mirror world (ROOM_FRAG's MIRROR_CHEAP main, render3d::mirror_cheap):
// the room's large shapes, and with CHEAP_TABLE the table, in one cheap shader.
let MIRROR_CHEAP_PASS = "#define MIRROR_CHEAP 1\n#define LINEAR_OUT 1\n#define NO_SSAO 1\n";
let CHEAP_TABLE = "#define CHEAP_TABLE 1\n";
// The light tuner's views of the room (render3d::room_views_on: the screen's occlusion, the
// indirect light, the sun's highlights, the floor's reflection alone), in pipelines of
// their own made while one is on: their code cost the room 0.55 ms at 3024 × 1890 where
// none was shown. With the screen's maps only, never in the mirror.
let ROOM_VIEWS = "#define ROOM_VIEWS 1\n";
// The scenic views' HDR target (render3d::hdr_shown, the high tier's): the board, the
// pieces, the table, the room, the view out and the motes write their exposed light with
// only their tonemap's toe taken off (the room's on the luminance, the board's and the
// table's on the least channel), and HDR_TONE_FRAG takes it the rest of the way after the
// pass resolves.
let HDR_OUT = "#define HDR_OUT 1\n";
// The light tuner's park on the ground (PARK_FN) and its parts off one at a time.
let PARK = "#define PARK 1\n";
let PARK_NO_SHADING = "#define PARK 1\n#define PARK_NO_SHADING 1\n";
let PARK_NO_LEAVES = "#define PARK 1\n#define PARK_NO_LEAVES 1\n";
let PARK_NO_GROUNDING = "#define PARK 1\n#define PARK_NO_GROUNDING 1\n";
let PARK_NO_SHADOWS = "#define PARK 1\n#define PARK_NO_SHADOWS 1\n";

// The depth of field's depth (render3d::depth_pass) through the glass and lace's mesh: the
// glass leaves the view out behind it as far as it is (nothing written), the lace writes its
// depth where its thread covers half the pixel or more, its coverage as ROOM_FRAG's lace
// takes it (lace_place is LIGHT_FN's); tile the room block's (render3d::LaceDepth).
let LACE_DEPTH_FRAG = """
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in vec2 v_extra;
    layout(set = 2, binding = 0) uniform sampler2D lace_mask;
    layout(set = 3, binding = 1) uniform LaceDepth { vec4 tile; };
    vec2 lace_place(vec2 uv) {
        float k = (0.375 * tile.z - uv.y) / tile.z;
        float row = k > 0.0 ? 1.0 + min(k, 0.3745) : fract(k);
        return vec2(uv.x / tile.z, row * (1024.0 / 1408.0));
    }
    void main() {
        vec2 lg = vec2(1.0, -1024.0 / 1408.0) / tile.z;
        vec2 ux = dFdx(v_uv) * lg;
        vec2 uy = dFdy(v_uv) * lg;
        if (floor(v_extra.y + 0.001) < 10.5) discard;
        float cover = textureGrad(lace_mask, lace_place(v_uv), ux, uy).r;
        vec3 v = normalize(eye.xyz - v_world);
        float a = 1.0 - pow(1.0 - 0.8 * cover, 1.0 / max(abs(dot(normalize(v_normal), v)), 0.5));
        if (a < 0.5) discard;
    }
    """;

// The light tuner's view of the depth of field's depth (render3d::depth_show_pass) over the
// picture: view.x 1 the distance along the view, from 0.5 m white to 16 m black on a log
// scale, the view out deep blue; 2 the lens's signed disc (render3d::Lens), blue in focus
// to yellow at the far cap behind it and magenta at the near cap before it, green where
// it is under a pixel across. to_w: the depth's d to the distance along the view, b / (d -
// a), and the metres a world unit; lens: the focus (world units), the aperture and the near
// and far caps (shares of the width); view: y the picture's width in pixels.
let DEPTH_SHOW_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D scene_depth;
    layout(set = 3, binding = 0) uniform DepthShow { vec4 to_w; vec4 lens; vec4 view; };
    void main() {
        float d = texelFetch(scene_depth, ivec2(gl_FragCoord.xy), 0).r;
        bool out_there = d >= 1.0;
        float w = out_there ? 1e9 : to_w.y / (d - to_w.x);
        if (view.x < 1.5) {
            float k = clamp(log2(w * to_w.z / 0.5) / 5.0, 0.0, 1.0);
            result = vec4(out_there ? vec3(0.05, 0.08, 0.3) : vec3(1.0 - k), 1.0);
            return;
        }
        float coc = lens.y * (1.0 - lens.x / w);
        float t = coc >= 0.0 ? clamp(coc / max(lens.w, 1e-4), 0.0, 1.0) : clamp(-coc / max(lens.z, 1e-4), 0.0, 1.0);
        vec3 c = mix(vec3(0.1, 0.2, 0.6), coc >= 0.0 ? vec3(1.0, 0.85, 0.1) : vec3(0.9, 0.1, 0.8), t);
        if (abs(coc) * view.y < 0.5) c = vec3(0.2, 0.8, 0.3);
        result = vec4(c, 1.0);
    }
    """;

// The HDR target made the picture (render3d::tone_pass): the tonemaps' shoulder and grade,
// sRGB, and a dither of under half a level against the 8-bit target's bands. Before the
// shoulder, the glow and the sun's glare in the eye (render3d::SunLook's veil, off as made):
// a veil round the sun falling as 1 / (1 + (θ / θ0)²), white to amber, scaled by the share
// of the sun open: the glow's smallest level at the sun (glow_wide), which holds the sun's
// light blurred over some 5°, so it counts every leaf and bar in front of it.
let HDR_TONE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D scene_light;
    layout(set = 2, binding = 1) uniform sampler2D glow_light;
    layout(set = 2, binding = 2) uniform sampler2D glow_wide;
    // tone_glow: x the glow's strength (render3d::glow_pass; 0 none), yz a pixel in the
    // glow's uv, w the light tuner's probe (over 0 the light itself times it, under 0 the
    // sun's open share times minus it, both as grey levels); tone_sun: the sun on the picture
    // (pixels), the pixels a degree, w what turns glow_wide's light there into the share
    // open (0 all open); tone_veil: render3d::SunLook's veil; tone_disc: x the disc's radius
    // (pixels), y what turns the picture's light on the disc into its share open (0 none).
    layout(set = 3, binding = 0) uniform HdrTone { vec4 tone_glow; vec4 tone_sun; vec4 tone_veil; vec4 tone_disc; };
    // The disc's own pixels, five of them, so a bar thinner than the glow's level still hides it.
    float disc_open() {
        if (tone_disc.y <= 0.0) return 1.0;
        ivec2 top = ivec2(1.0 / tone_glow.yz) - 1;
        float h = 0.5 * tone_disc.x, s = 0.0;
        vec2 o[5] = vec2[5](vec2(0.0), vec2(h, 0.0), vec2(-h, 0.0), vec2(0.0, h), vec2(0.0, -h));
        for (int i = 0; i < 5; i++) {
            vec3 c = texelFetch(scene_light, clamp(ivec2(tone_sun.xy + o[i]), ivec2(0), top), 0).rgb;
            s += clamp(max(c.r, max(c.g, c.b)) * tone_disc.y, 0.0, 1.0);
        }
        return s * 0.2;
    }
    float sun_open() {
        float d = disc_open();
        if (tone_sun.w <= 0.0) return d;
        vec3 w = texture(glow_wide, tone_sun.xy * tone_glow.yz).rgb;
        return min(d, clamp(max(w.r, max(w.g, w.b)) * tone_sun.w, 0.0, 1.0));
    }
    vec3 sun_glare(vec2 px, float open) {
        vec2 d = px - tone_sun.xy;
        float ang = length(d) / max(tone_sun.z, 1e-3);
        float t = ang / max(tone_veil.y, 1e-3);
        float veil = tone_veil.x * open / (1.0 + t * t) * (1.0 - smoothstep(0.5 * tone_veil.z, tone_veil.z, ang));
        return veil * pow(vec3(1.0, 0.82, 0.6), vec3(tone_veil.w * min(ang / 10.0, 2.0)));
    }
    vec3 shoulder(vec3 c) {
        float peak = max(c.r, max(c.g, c.b));
        const float start = 0.76;
        if (peak < start) return c;
        const float d = 1.0 - start;
        float np = 1.0 - d * d / (peak + d - start);
        c *= np / peak;
        float g = 1.0 - 1.0 / (0.15 * (peak - np) + 1.0);
        return mix(c, vec3(np), g);
    }
    vec3 encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    void main() {
        vec3 c = max(texelFetch(scene_light, ivec2(gl_FragCoord.xy), 0).rgb, vec3(0.0));
        if (tone_glow.w != 0.0) {
            result = vec4(encode(tone_glow.w > 0.0 ? c * tone_glow.w : vec3(-tone_glow.w * sun_open())), 1.0);
            return;
        }
        if (tone_glow.x > 0.0) c += tone_glow.x * max(texture(glow_light, gl_FragCoord.xy * tone_glow.yz).rgb, vec3(0.0));
        if (tone_veil.x > 0.0) c += sun_glare(gl_FragCoord.xy, sun_open());
        c = shoulder(c) * vec3(1.02, 1.0, 0.97);
        float n = fract(sin(dot(floor(gl_FragCoord.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
        result = vec4(encode(c) + n / 255.0, 1.0);
    }
    """;

// The scenic views' glow (render3d::glow_pass), in the HDR target's linear light before the
// tonemap, so the sun's disc and the sky bleed over the leaves, the bars and the frame in
// front of them: the light over a threshold (a soft knee) picked into a quarter of the
// picture, a 4 × 4 block a texel from four bilinear taps, then halved level by level
// (GLOW_DOWN_FRAG, Bjorge's dual filter: five taps) and widened back up (GLOW_UP_FRAG, eight
// taps), each level blended over the one above it by the reach, so the levels' shares sum to
// one; HDR_TONE_FRAG adds the top level times the strength. glow_step: xy a source texel in
// uv, zw a target pixel in uv; glow_look: x the threshold, y the knee, z the brightest a
// channel is taken at (against a single pixel's spark), w the reach (each coarser level's
// share).
let GLOW_FIRST = "#define GLOW_FIRST 1\n";
let GLOW_DOWN_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform GlowStep { vec4 glow_step; vec4 glow_look; };
    vec3 tap(vec2 uv) { return min(max(texture(src, uv).rgb, vec3(0.0)), vec3(glow_look.z)); }
    void main() {
        vec2 uv = gl_FragCoord.xy * glow_step.zw;
        vec2 h = glow_step.xy;
    #ifdef GLOW_FIRST
        vec3 c = 0.25 * (tap(uv + vec2(-h.x, -h.y)) + tap(uv + vec2(h.x, -h.y)) + tap(uv + vec2(-h.x, h.y)) + tap(uv + h));
        float bright = max(c.r, max(c.g, c.b));
        float knee = max(glow_look.y, 1e-4);
        float soft = clamp(bright - glow_look.x + knee, 0.0, 2.0 * knee);
        soft = soft * soft / (4.0 * knee);
        c *= max(soft, bright - glow_look.x) / max(bright, 1e-4);
    #else
        vec3 c = (4.0 * tap(uv) + tap(uv - h) + tap(uv + h) + tap(uv + vec2(h.x, -h.y)) + tap(uv - vec2(h.x, -h.y))) * 0.125;
    #endif
        result = vec4(c, 1.0);
    }
    """;
let GLOW_UP_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform GlowStep { vec4 glow_step; vec4 glow_look; };
    void main() {
        vec2 uv = gl_FragCoord.xy * glow_step.zw;
        vec2 h = glow_step.xy;
        vec3 c = texture(src, uv + vec2(-2.0 * h.x, 0.0)).rgb + texture(src, uv + vec2(2.0 * h.x, 0.0)).rgb
               + texture(src, uv + vec2(0.0, -2.0 * h.y)).rgb + texture(src, uv + vec2(0.0, 2.0 * h.y)).rgb
               + 2.0 * (texture(src, uv + vec2(-h.x, h.y)).rgb + texture(src, uv + h).rgb
                        + texture(src, uv + vec2(h.x, -h.y)).rgb + texture(src, uv - h).rgb);
        result = vec4(c / 12.0, glow_look.w);
    }
    """;

// The mirror's picture made the room's light again, with how far each texel stands from the
// floor along the reflection: the pass drew the room, the table and the view out as their
// light before the tonemap (mirror_light), exposed, so the room's exposure's inverse
// (planar_tone.x) takes it back. The depth places the point: planar_back
// is the inverse of the pass's view_proj (columns), planar_eye the eye and, w, the floor's
// y; the point's height over the floor and the eye's give its distance from where the
// reflection leaves the floor, at most planar_tone.y. Where the pass drew nothing of the room
// (past the floor's far edge), the nearest texel below that it did, so the mips and the
// floor's wide blurs never take in black.
let PLANAR_RESOLVE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D planar_color;
    layout(set = 2, binding = 1) uniform sampler2D planar_depth;
    layout(set = 3, binding = 0) uniform PlanarResolve { vec4 planar_back[4]; vec4 planar_eye; vec4 planar_tone; };
    const int PLANAR_REACH = 8;
    // A texel's light made safe for the mips: a NaN, an infinity or a negative channel from
    // anything drawn into the mirror would spread through them into black blotches on the
    // floor; the brightest (the sun's disc) held to MIRROR_PEAK's luminance, its hue kept.
    vec3 kept_light(vec3 c) {
        float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
        if (!(y >= 0.0 && y <= 1e4)) return vec3(0.0);
        c = clamp(c, vec3(0.0), vec3(1e4));
        return y > 16.0 ? c * (16.0 / y) : c;
    }
    void main() {
        ivec2 px = ivec2(gl_FragCoord.xy);
        ivec2 size = textureSize(planar_color, 0);
        // Over the floor's far edge the mirror draws nothing of the room (the view out
        // drawn first shows there): take the wall's foot a few texels down, so the floor's
        // reflection at the wall never reaches past it into the sky; farther up, the
        // nearest texel below that was drawn, found in doubling steps.
        float depth = texelFetch(planar_depth, px, 0).r;
        for (int k = 1; k <= PLANAR_REACH && depth >= 1.0; k++) {
            ivec2 at = ivec2(px.x, min(px.y + k, size.y - 1));
            float d = texelFetch(planar_depth, at, 0).r;
            if (d < 1.0) {
                px = at;
                depth = d;
            }
        }
        for (int k = 2 * PLANAR_REACH; k <= 1024 && depth >= 1.0; k *= 2) {
            ivec2 at = ivec2(px.x, min(px.y + k, size.y - 1));
            float d = texelFetch(planar_depth, at, 0).r;
            if (d < 1.0) {
                px = at;
                depth = d;
            }
        }
        vec2 uv = (vec2(px) + 0.5) / vec2(size);
        // A 3 × 3 tent over what the pass drew: the half size has no antialiasing, and its
        // steps along a nearly level edge (a threshold's, a moulding's) crawl as the eye moves.
        vec3 c = vec3(0.0);
        float total = 0.0;
        for (int k = 0; k < 9; k++) {
            ivec2 at = clamp(px + ivec2(k % 3 - 1, k / 3 - 1), ivec2(0), size - 1);
            if (texelFetch(planar_depth, at, 0).r >= 1.0) continue;
            float w = (k % 3 == 1 ? 2.0 : 1.0) * (k / 3 == 1 ? 2.0 : 1.0);
            c += w * kept_light(texelFetch(planar_color, at, 0).rgb);
            total += w;
        }
        c /= max(total, 1e-4);
        vec4 h = planar_back[0] * (2.0 * uv.x - 1.0) + planar_back[1] * (1.0 - 2.0 * uv.y)
               + planar_back[2] * depth + planar_back[3];
        vec3 q = h.xyz / h.w;
        float floor_y = planar_eye.w;
        float high = max(q.y - floor_y, 0.0);
        vec3 under = vec3(q.x, 2.0 * floor_y - q.y, q.z);
        float t = length(under - planar_eye.xyz) * high / max(high + planar_eye.y - floor_y, 1e-3);
        t = t >= 0.0 ? min(t, planar_tone.y) : 0.0;
        result = depth < 1.0 ? vec4(c * planar_tone.x, t) : vec4(0.0);
    }
    """;

// The mirror's next mip from the one above (planar_mip.x), each texel a 4 × 4 tent [1 3 3 1]
// of the level above in four bilinear reads, not a 2 × 2 box: a box's mips are tied to their
// texels, so a window's bar over the floor slid by the eye fell into one texel or across two
// and its reflection pulsed as it moved; a tent's change much less with where the bar falls.
let PLANAR_MIP_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D planar_map;
    layout(set = 3, binding = 0) uniform PlanarMip { vec4 planar_mip; };
    void main() {
        float lod = planar_mip.x;
        vec2 texel = 1.0 / vec2(textureSize(planar_map, int(lod)));
        vec2 uv = gl_FragCoord.xy * 2.0 * texel;
        vec2 d = 0.75 * texel;
        result = 0.25 * (textureLod(planar_map, uv + vec2(-d.x, -d.y), lod) + textureLod(planar_map, uv + vec2(d.x, -d.y), lod)
                       + textureLod(planar_map, uv + vec2(-d.x, d.y), lod) + textureLod(planar_map, uv + vec2(d.x, d.y), lod));
    }
    """;

// The tuner's view of the floor's mirror over the whole picture: planar_show x the room's
// exposure, y 1 its light, 2 its distances (white planar_show.z away); planar_px.xy a pixel
// in uv.
let PLANAR_SHOW_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D planar_map;
    layout(set = 3, binding = 0) uniform PlanarShow { vec4 planar_show; vec4 planar_px; };
    vec3 encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    void main() {
        vec4 m = textureLod(planar_map, gl_FragCoord.xy * planar_px.xy, 0.0);
        vec3 c = planar_show.y > 1.5 ? vec3(sqrt(clamp(m.a / planar_show.z, 0.0, 1.0)))
                                     : encode(tonemap(m.rgb * planar_show.x) * vec3(1.02, 1.0, 0.97));
        result = vec4(c, 1.0);
    }
    """;

// The image with its glow added in linear light, into the target: x the glow's strength, yz
// a target pixel in the glow's uv.
let GLOW_ADD_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 2, binding = 1) uniform sampler2D glow;
    layout(set = 3, binding = 0) uniform GlowAdd { vec4 glow_add; };
    vec3 decode(vec3 c) {
        return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c));
    }
    vec3 encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    void main() {
        vec4 c = texelFetch(src, ivec2(gl_FragCoord.xy), 0);
        vec3 g = texture(glow, gl_FragCoord.xy * glow_add.yz).rgb;
        result = vec4(encode(decode(c.rgb) + g * glow_add.x), c.a);
    }
    """;

// The 3D scene drawn under the screen's size scaled up to it (render3d::upscale_pass):
// upscale.xy a screen pixel in the scene's texels, zw a scene texel in uv. Bilinear, or with
// UPSCALE_CUBIC Catmull-Rom from five bilinear taps: each side's two middle weights, both
// positive, taken by one tap between their texels, and the four corners' small weights
// left out (Jimenez's; the nine taps' look within a level, 0.30 ms against 0.44 at
// 3024 × 1890 on an M1 Pro).
let UPSCALE_CUBIC = "#define UPSCALE_CUBIC 1\n";
let UPSCALE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    layout(set = 3, binding = 0) uniform Upscale { vec4 upscale; };
    void main() {
        vec2 at = gl_FragCoord.xy * upscale.xy;
    #ifdef UPSCALE_CUBIC
        vec2 mid = floor(at - 0.5) + 0.5;
        vec2 f = at - mid;
        vec2 w0 = f * (-0.5 + f * (1.0 - 0.5 * f));
        vec2 w1 = 1.0 + f * f * (-2.5 + 1.5 * f);
        vec2 w2 = f * (0.5 + f * (2.0 - 1.5 * f));
        vec2 w3 = f * f * (-0.5 + 0.5 * f);
        vec2 w12 = w1 + w2;
        vec2 a = (mid - 1.0) * upscale.zw;
        vec2 b = (mid + w2 / w12) * upscale.zw;
        vec2 c = (mid + 2.0) * upscale.zw;
        vec4 sum = texture(src, vec2(b.x, a.y)) * (w12.x * w0.y) + texture(src, vec2(a.x, b.y)) * (w0.x * w12.y)
                 + texture(src, vec2(b.x, b.y)) * (w12.x * w12.y) + texture(src, vec2(c.x, b.y)) * (w3.x * w12.y)
                 + texture(src, vec2(b.x, c.y)) * (w12.x * w3.y);
        float kept = w12.x * w0.y + w0.x * w12.y + w12.x * w12.y + w3.x * w12.y + w12.x * w3.y;
        result = clamp(sum / kept, 0.0, 1.0);
    #else
        result = texture(src, at * upscale.zw);
    #endif
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

// The plain background in place of the photograph (prototypes/draughts.js's paintPlain):
// the page at the top to a deep tone of the frame at the foot, a
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

// BAKE_FRAG with the black marble slab (render3d::BAKE_SLAB), the table's alone
// (BAKE_TABLE), or the room's oak alone (BAKE_ROOM); without any the rest of the board's.
let BAKE_SLAB = "#define BAKE_SLAB 1\n";
let BAKE_TABLE = "#define BAKE_TABLE 1\n";
let BAKE_ROOM = "#define BAKE_ROOM 1\n";

// The board's surfaces, baked once per theme into two targets: albedo and roughness
// (sRGB), and the normal's x and z. mode.x 0 bakes the plan of the field and its inlay,
// seen from above; 1 the frame map, its grain along u; 2 the table's top seen from
// above, its wood in the light squares' slots (table_cut); 3 the table's wear (wear_at);
// 4 and 5 the room's oak, the floor's field and the wall's (oak_at, in the slots
// surfaces::Oak names). mode.y: the wood's model
// (--wood): 0 noise drawn out along the grain, 1 growth rings, 2 growth
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
        vec4 tone;       // x: its warmth, y: pickle, z: caulk; w: samples a side a texel
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

    struct Wood {
        vec3 albedo;
        float rough;
        float height;
        float cavity;
        #ifdef BAKE_ROOM
        float pore;      // the open pores' share, for the finish to fill
        float fleck;     // the rays' flakes'
        #endif
    };

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

    #ifdef BAKE_ROOM
    // Oak's rays, sheets of cells running out from the pith, a few centimetres high along
    // the grain. On a face near the radial plane (slant small) they lie
    // almost in the face and show as broad satiny flakes across the grain, the longer the
    // closer the cut, soft-edged, the finish (oak_finish) leaving them a little lighter and
    // glossier, tone on tone; on a face across them (flat-sawn) as short dark lenses along it.
    // slant is the sine of the angle. x across, y along, in world units. x the flakes,
    // y the lenses.
    vec2 oak_rays(float x, float y, float seed, float slant) {
        float texel = size.z / size.x;
        float quarter = 1.0 - smoothstep(0.12, 0.5, slant);
        float flake = 0.0;
        if (quarter > 0.0) {
            const vec2 CELL = vec2(1.1, 1.8);
            vec2 id0 = floor(vec2(x, y) / CELL);
            for (int k = 0; k < 9; k++) {
                vec2 id = id0 + vec2(float(k % 3) - 1.0, float(k / 3) - 1.0);
                if (h12(id + seed * 0.61) > 0.35 * inlay_fig.w) continue;
                vec2 c = (id + vec2(0.2 + 0.6 * h12(id + 1.3), 0.1 + 0.8 * h12(id + 2.7))) * CELL;
                float len = min((0.5 + 1.0 * h12(id + 3.9)) / (0.5 + 3.0 * slant), 1.5);
                float high = 0.15 + 0.4 * h12(id + 5.1);
                vec2 d = vec2(x, y) - c;
                d.y -= (h12(id + 7.7) - 0.5) * 0.4 * d.x;
                d.y += 0.3 * high * (vnoise(vec2(x * 4.0, seed + id.y)) - 0.5);
                float u = d.x / len;
                // Rounded, ragged at the ends, broken into a few flakes: a soft ribbon
                // across the grain, never a stroke.
                float lens = high * sqrt(max(1.0 - u * u, 0.0)) * (0.7 + 0.3 * vnoise(vec2(x * 3.0, id.y + 3.0)));
                float inside = (1.0 - smoothstep(0.2 * lens, lens, abs(d.y))) * smoothstep(texel, 3.0 * texel, lens);
                inside *= smoothstep(0.25, 0.6, vnoise(vec2(x * 2.5, y * 1.5) + id * 3.1));
                flake = max(flake, inside * (0.5 + 0.5 * h12(id + 9.1)));
            }
        }
        float lines = 0.0;
        float across = smoothstep(0.3, 0.8, slant);
        if (across > 0.0) {
            const vec2 TC = vec2(0.1, 0.8);
            vec2 id = floor(vec2(x, y) / TC);
            if (h12(id + seed * 0.43 + 11.0) < 0.2 * inlay_fig.w) {
                vec2 c = (id + vec2(0.3 + 0.4 * h12(id + 1.1), 0.5)) * TC;
                vec2 d = vec2(x, y) - c;
                float u = d.y / (0.08 + 0.25 * h12(id + 2.2));
                float w = 0.012 * max(1.0 - u * u, 0.0);
                lines = (1.0 - smoothstep(0.0, texel, abs(d.x) - w)) * step(abs(u), 1.0) * across;
            }
        }
        return vec2(flake * quarter, lines);
    }
    #endif

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
        #ifdef BAKE_ROOM
        // A board as wide as surface.x from a log of its own: a quarter-sawn one with the
        // pith well off its side, a flat-sawn one from 1 to 3 widths over it; the axis
        // leaning about the board's middle, so its arches change along it.
        float d = mix(0.1, 0.8 + 0.6 * surface.x, flatness) * (0.5 + h1(seed, 5.3));
        float c = side * mix(0.5 * surface.x + 1.5 + 4.0 * h1(seed, 6.1), 0.25 * surface.x * (h1(seed, 6.1) - 0.5), flatness);
        float axis = fbm(vec2(q.y * 0.05, 0.5) + o) - 0.5;
        float lean = (h1(seed, 8.8) > 0.5 ? 1.0 : -1.0) * (0.008 + 0.022 * h1(seed, 8.1)) * flatness;
        float dd = max(d + lean * (q.y - 0.5 * size.w) + axis * 0.3 * flatness, 0.3);
        #else
        float d = mix(0.1, 1.6, flatness) * (0.6 + 0.8 * h1(seed, 5.3));
        float c = side * mix(3.0 + 3.0 * h1(seed, 6.1), 0.8 * (h1(seed, 6.1) - 0.5), flatness);
        float axis = fbm(vec2(q.y * 0.12, 0.5) + o) - 0.5;
        float lean = (h1(seed, 8.8) - 0.5) * 0.12 * flatness;
        float dd = max(d + lean * q.y + axis * 0.5 * flatness, 0.02);
        #endif
        float r = length(vec2(q.x - c - axis * 0.8, dd));
        #ifdef BAKE_ROOM
        // Oak's years wander broadly and smoothly: its arches are calm curves, not wiggles.
        r += rw * k.x * 4.0 * (fbm(vec2(q.x * 0.7, q.y * 0.1) + o) - 0.5);
        r += rw * k.x * 0.6 * (vnoise(vec2(q.x * 3.0, q.y * 0.35) + o) - 0.5);
        #else
        r += rw * k.x * 3.0 * (fbm(vec2(q.x * 1.1, q.y * 0.18) + o) - 0.5);
        r += rw * k.x * 0.8 * (vnoise(vec2(q.x * 6.0, q.y * 0.9) + o) - 0.5);
        r += rw * k.x * 0.7 * (vnoise(vec2(q.x * 14.0, q.y * 4.0) + o) - 0.5);
        #endif
        #ifdef BAKE_ROOM
        // A pin knot in one board of three: the rings swept round it, its heart dark.
        float knot = 0.0;
        if (h1(seed, 12.1) < 0.35) {
            vec2 kc = vec2((h1(seed, 12.7) - 0.5) * 0.6 * surface.x, h1(seed, 13.3) * size.w);
            float rk = 0.05 + 0.1 * h1(seed, 13.9);
            float dist = length((q - kc) / vec2(1.0, 2.2));
            r -= rw * 5.0 * exp(-dist * dist / (9.0 * rk * rk));
            knot = 1.0 - smoothstep(0.6 * rk, rk, dist);
        }
        #endif
        float t = r / rw;
        t += 1.2 * (vnoise(vec2(t * 0.3, seed)) - 0.5);
        #ifdef BAKE_ROOM
        // Runs of narrow years and wide ones, as an oak's good and lean decades.
        t += 2.5 * (fbm3(vec2(t * 0.12, seed + 0.5)) - 0.5);
        #endif
        float year = floor(t);
        float ph = t - year;
        #ifdef BAKE_ROOM
        // The ring's edge a texel and a half soft on the face: the years' spacing there is
        // the ring's width over the slope of the distance from the pith (wide on a
        // flat-sawn face), so a cathedral's bands stay crisp and a quarter-sawn face's
        // close lines don't alias.
        float slope = length(vec2(q.x - c - axis * 0.8, abs(lean) * dd)) / max(r, 1e-3);
        float e = clamp(1.5 * texel * slope / rw, 0.03, 0.45);
        #else
        float e = max(0.06, 1.5 * texel / rw);
        #endif
        float late = smoothstep(0.72, 1.0 - e, ph);
        late *= late * (1.0 - smoothstep(1.0 - e, 1.0, ph));
        late *= 0.5 + h1(year + seed * 13.0, 4.4);
        float early = 1.0 - smoothstep(0.0, 0.5, ph);
        // Fibres along the grain, a little wandering.
        float x = q.x + 0.004 * (vnoise(vec2(q.x * 20.0, q.y * 3.0) + o) - 0.5);
        #ifdef BAKE_ROOM
        // No fibre finer than two texels: finer ones alias into streaks.
        float fibre = 0.6 * vnoise(vec2(x * min(55.0, 0.5 / texel), q.y * 0.7) + o)
                    + 0.4 * vnoise(vec2(x * 20.0, q.y * 0.3) + o);
        #else
        float fibre = 0.45 * vnoise(vec2(x * 150.0, q.y * 2.0) + o)
                    + 0.3 * vnoise(vec2(x * 55.0, q.y * 0.7) + o)
                    + 0.25 * vnoise(vec2(x * 380.0, q.y * 30.0) + o);
        #endif
        float broad = fbm(vec2(q.x * 1.2, q.y * 0.25) + o);
        float pore = 0.0;
        #ifdef BAKE_ROOM
        // Ring-porous oak: each year starts with a band of large open pores, short dashes
        // along the grain, wide where a flat-sawn face cuts the year at a slant; a few
        // small ones in the late wood. The rays as oak_rays has them, no pores in a flake.
        float slant = dd / length(vec2(q.x - c - axis * 0.8, dd));   // the sine of the face's angle to the rays
        vec2 rays = oak_rays(x, q.y + o.y, seed, slant);
        float wide = 0.22 + 0.2 * h1(year + seed * 5.0, 3.4);
        float band = smoothstep(0.0, 0.5 * e, ph) * (1.0 - smoothstep(wide - 0.08, wide + 0.08 + e, ph));
        vec2 pq = vec2(x / max(0.03, 1.5 * texel), q.y / 0.5) + o;
        float dash = 0.45 + 0.55 * smoothstep(0.25, 0.7, vnoise(pq));
        pore = ring.w * (band * dash + 0.2 * smoothstep(0.82, 0.96, vnoise(pq * vec2(1.3, 2.0) + 9.0)));
        // Each year's pores as open as its own: some years' bands faint, some heavy.
        pore *= 0.45 + 0.9 * h1(year + seed * 7.0, 2.6);
        pore = max(pore * (1.0 - 0.6 * rays.x), 0.3 * rays.y);
        float a = ring.z * (late - 0.08) + k.z * (fibre - 0.5) * 1.2 + k.y * (broad - 0.5) * 1.5
                + 0.3 * pore + 1.6 * knot;
        Wood w;
        w.albedo = pow(srgb(base.rgb), vec3(1.0 + a));
        w.rough = base.a;
        w.height = 0.15 * late + 0.5 * (fibre - 0.5) - 1.2 * pore + 0.08 * rays.x;
        w.cavity = 1.0 - 0.5 * pore;
        w.pore = pore;
        w.fleck = rays.x;
        return w;
        #else
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
        #endif
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
            // A plain stone's own figure: its seed (looks::Carving.scale, 1 for the first)
            // moves the field, so two stones don't share their veins.
            vec2 qs = q + (carve_more.x > 2.5 ? (carve.y - 1.0) * vec2(17.3, 9.1) : vec2(0.0));
            float cloud = fbm(qs * 0.55 + 4.7);
            float r = abs(fbm(qs * vec2(0.35, 0.5) + vec2(fbm(qs * 0.8) * 1.4, 0.0)) - 0.5);
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
    // mode.w > 0). Perlin's turbulent marble without the sine: the veins are
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
    // Coverage of a mineral ribbon averaged across one bake texel.
    float ribbon(float d, float w, float pixel) {
        return clamp((min(d + pixel, w) - max(d - pixel, -w)) / (2.0 * pixel), 0.0, 1.0);
    }
    // One family of seams. Each changes heading at irregular knots. A daughter
    // opens from the same trace, then dies out or rejoins it at the next knot.
    float calcite(vec2 q, float spacing, float width, float pockets, float pixel) {
        float row = floor(q.y / spacing + 0.5);
        float t = q.x / spacing + 13.7 * row;
        float k = floor(t);
        float u = fract(t);
        vec2 knot = vec2(k, row);
        float a = h12(knot);
        float b = h12(knot + vec2(1.0, 0.0));
        float fork = min(u * 2.7, (1.0 - u) * 1.6);
        float grit = fbm3(q * 21.0);
        float jog = (vnoise(vec2(t * 8.0, row)) - 0.5) * 0.08 + (grit - 0.5) * 0.05;
        float d = q.y - spacing * (row + (mix(a, b, u) - 0.5) * 0.57 + jog);
        float milk = smoothstep(0.42, 0.78, fbm3(q * 3.2));
        float w = width * (0.09 + milk * milk * (1.0 + 3.6 * pockets)) * (0.45 + grit);
        float spread = (h12(knot + 4.6) - 0.5) * spacing * 0.53 * fork;
        float daughter = d - spread - fork * (vnoise(q * 14.0) - 0.5) * 0.05;
        float life = smoothstep(0.17, 0.68, vnoise(vec2(t * 1.35, row + 9.3)));
        float core = ribbon(d, w, pixel);
        float twig = ribbon(daughter, width * (0.07 + 0.44 * milk), pixel);
        float cloud = exp(-abs(d + w) / (0.009 + w * 2.6)) * milk * pockets;
        // Dark host rock caught inside a thick seam, in broken slivers along the cut.
        float inclusion = fbm3(vec2(q.x * 37.0, q.y * 108.0));
        float grains = mix(1.0, 0.16 + 0.84 * smoothstep(0.29, 0.68, inclusion),
                           smoothstep(0.003, 0.025, w));
        return life * (max(core * grains, twig * (0.35 + 0.5 * a)) * (0.30 + grit) + cloud * 0.30);
    }

    vec4 black_slab(vec2 p, float pixel) {
        vec2 q = vec2(dot(p, vec2(0.86, 0.51)), dot(p, vec2(-0.51, 0.86)));
        q.y += (fbm3(q * 1.4) - 0.5) * 0.24;
        float v = calcite(q, marble_form.x, marble_form.y, marble_form.w, pixel);
        vec2 crosscut = vec2(q.y + q.x * 0.31, q.x - q.y * 0.31) + 8.2;
        float fine = calcite(crosscut, marble_form.x * 0.68, marble_form.y * 0.47, 0.5, pixel);
        float haze = fbm3(p * 3.7);
        vec3 ground = srgb(marble_base.rgb) * (0.55 + 1.1 * haze);
        return vec4(mix(ground, srgb(marble_vein.rgb), clamp(marble.x * max(v, fine * marble_form.z), 0.0, 1.0)),
                    mix(0.5, 0.06, marble.z) + 0.035 * haze);
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
            float scribe = 1.0 - smoothstep(0.004, 0.010, m - FIELD);
            c.shade = 1.0 - 0.6 * scribe;
            c.dip = scribe;
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

    // The carved frame (carve.w), its motif carve_more.x: 0 two thin vines in
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
    // far and near sides; between them the runs carve_more.w picks (looks::Carving.pattern):
    // 0 zigzags and a meander by turns, 1 zigzags only, 2 the meander only, 3 none. A
    // zigzag starts and ends on the band's middle, a whole number of its periods, so it
    // runs into the diamonds' points as one chain.
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
        float kind = carve_more.w;
        bool zig = kind < 0.5 ? mod(g, 2.0) < 0.5 : kind < 1.5;
        // A zigzag meets a diamond at its point (0.15 out); a meander, a tree, or the
        // corner's wheel keeps a gap.
        float lo = g * step_ + (g < 0.5 && trees ? 0.2 : zig ? 0.15 : 0.175);
        float hi = (g + 1.0) * step_ - (g > n - 1.5 ? 0.2 : zig ? 0.15 : 0.175);
        float span = hi - lo;
        if (span > 0.05 && kind < 2.5) {
            float t = u - lo;
            float len = span / max(floor(span / (zig ? 0.17 : 0.2) + 0.5), 1.0);
            float pat = zig ? zigzag(t + 0.25 * len, y, 0.08, len) : meander(t, y, 0.078, len);
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
    // A plain stone's weathering (motif 3): a sparse network of hairline cracks, the
    // edges of a warped cell field shown only where a broad noise lets them through, so
    // they run and stop as real ones do. x: the crack (0..1), every edge a texel soft for
    // the mips; y: near it, where moss settles.
    vec2 cracks(vec2 q, float seed) {
        const float CELLS = 1.7;      // cells a world unit (a square is 1)
        vec2 p = q * CELLS + 0.4 * vec2(fbm(q * 2.0 + seed), fbm(q * 2.0 + seed + 5.2));
        vec2 i = floor(p);
        float f1 = 9.0;
        float f2 = 9.0;
        for (int k = 0; k < 9; k++) {
            vec2 id = i + vec2(float(k % 3) - 1.0, float(k / 3) - 1.0);
            vec2 c = id + vec2(h12(id + seed), h12(id + seed + 2.7)) - p;
            float d = dot(c, c);
            if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
        }
        float e = sqrt(f2) - sqrt(f1);
        float texel = CELLS * size.z / size.x;
        float w = 0.008 + 0.012 * vnoise(p * 3.0);
        float show = smoothstep(0.58, 0.68, fbm(q * 0.9 + seed + 9.0));
        float line = 1.0 - smoothstep(w, w + 1.5 * texel, e);
        float near = 1.0 - smoothstep(w, 0.12, e);
        return vec2(line, near) * show;
    }

    // q: x across from the band's start, y along; band: the mitred piece (0 the near
    // side, 1 the far, 2 and 3 the sides along z).
    Carve carving(vec2 q, float band) {
        Carve r = Carve(0.0, 0.0, 0.0, 0.0, 0.0);
        float across = q.x - 0.2;
        float along = q.y - 5.2;
        bool top = across < 0.55;
        float motif = carve_more.x;
        if (motif > 2.5) {
            // 3: no motif, a plain stone weathered: its cracks, moss gathering in and
            // along them, laid out by its seed (carve.y, looks::Carving.scale).
            vec2 c = cracks(q, 7.3 * band + carve.y);
            r.hollow = 0.6 * c.x;
            r.h = -carve.x * c.x;
            r.foot = 0.7 * c.y;
            return r;
        }
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
            float scribe = (1.0 - smoothstep(seam.y, seam.y + texel, d))
                       * step(0.5 * seam.x, across) * step(across, 0.47) * min(tone.z, 1.0);
            w.albedo = mix(w.albedo, srgb(vec3(0.07, 0.06, 0.055)), clamp(scribe * seam.z * max(tone.z, 1.0), 0.0, 1.0));
            w.rough = mix(w.rough, 0.6, scribe);
            w.height -= 0.6 * scribe;
            w.cavity -= 0.3 * scribe;
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

    // The table's top (mode.x 2), round its middle: planks seam.x wide with the grain
    // along y, each its own piece of the wood (the light squares' slots hold the table's:
    // tables::Table) and its own tone.
    Cut table_cut(vec2 p) {
        Cut c;
        float plank = floor(p.x / seam.x + 0.5);
        c.q = vec2(p.x - plank * seam.x, p.y);
        c.seed = 31.0 + 7.0 * plank;
        c.base = light_sq;
        c.k = light_fig;
        c.ring = light_ring;
        c.f = inlay.xyz;
        float edge = abs(abs(c.q.x) - 0.5 * seam.x);
        c.seam = 1.0 - smoothstep(seam.y, seam.y + 0.004, edge);
        c.shade = (1.0 + surface.x * (h12(vec2(c.seed, 4.2)) - 0.5)) * (1.0 - surface.z * c.seam);
        c.dip = 0.3 * c.seam;
        return c;
    }

    // The wear's hashes and noise over a tile that repeats every `per` cells.
    float hw(vec2 c, float per) { return h12(mod(c, per)); }
    float wnoise(vec2 p, float per) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        vec2 u = f * f * (3.0 - 2.0 * f);
        return mix(mix(hw(i, per), hw(i + vec2(1, 0), per), u.x),
                   mix(hw(i + vec2(0, 1), per), hw(i + vec2(1, 1), per), u.x), u.y);
    }
    // cells() over a tile `per` cells across: the nearest two feature points' distances.
    vec2 wcells(vec2 p, float per) {
        vec2 i = floor(p);
        vec2 f = fract(p);
        float d1 = 8.0;
        float d2 = 8.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 o = vec2(float(x), float(y));
                vec2 c = o + vec2(hw(i + o, per), hw(i + o + 19.7, per)) * 0.9 + 0.05 - f;
                float d = dot(c, c);
                if (d < d1) { d2 = d1; d1 = d; } else if (d < d2) { d2 = d; }
            }
        }
        return vec2(sqrt(d1), sqrt(d2));
    }

    // Scratches over the tile: in cells `size` across (`per` of them to the tile), up to
    // two straight scratches each, `keep` of them drawn, of random lengths, angles round
    // `dir`, widths about w and depths: how much of one there is at p.
    float scratches(vec2 p, float size, float per, float keep, float seed, vec2 dir, float w) {
        vec2 i = floor(p / size);
        float best = 0.0;
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                vec2 c = i + vec2(float(x), float(y));
                for (int k = 0; k < 2; k++) {
                    vec2 kk = vec2(float(k) * 7.1 + seed);
                    if (hw(c + kk + 0.3, per) > keep) continue;
                    vec2 m = (c + vec2(hw(c + kk + 1.1, per), hw(c + kk + 2.3, per))) * size;
                    float ang = (hw(c + kk + 3.7, per) - 0.5) * 2.4;
                    vec2 d = vec2(cos(ang) * dir.x - sin(ang) * dir.y, sin(ang) * dir.x + cos(ang) * dir.y);
                    float half_len = size * (0.15 + 0.6 * hw(c + kk + 4.9, per));
                    vec2 q = p - m;
                    float t = clamp(dot(q, d), -half_len, half_len);
                    // Thinner and fainter toward its ends, as a dragged grit lifts.
                    float along = max(1.0 - abs(t) / half_len, 0.0);
                    float sw = w * (0.5 + hw(c + kk + 5.3, per)) * (0.5 + 0.5 * sqrt(along));
                    float depth = 0.5 + 0.5 * hw(c + kk + 6.1, per);
                    best = max(best, depth * (1.0 - smoothstep(0.3 * sw, sw, length(q - d * t))));
                }
            }
        }
        return best;
    }

    // The table's wear (mode.x 3) on a tile size.zw across that repeats, which TABLE_FRAG
    // lays twice over the top, turned and scaled the second time so it never shows, and
    // masks by the patches the top's map holds (table_over's cavity): x scratches, y the
    // varnish's crazing, z dents and nicks, as strong as tables::Table.patina says, each
    // half as many as the top has, as the two layers add.
    vec4 wear_at(vec2 p) {
        float tile = size.z;
        float texel = size.z / size.x;
        float sw = max(texel * 1.5, 0.01);
        float s1 = scratches(p, 1.0, tile, 0.37, 1.0, vec2(0.0, 1.0), sw);
        float s2 = scratches(p, 0.5, 2.0 * tile, 0.3, 5.0, vec2(1.0, 0.0), sw);
        // Hairlines, which the top's map was too coarse for.
        float s3 = scratches(p, 0.4, 2.5 * tile, 0.12, 9.0, vec2(0.0, 1.0), 0.5 * sw);
        float scratch = max(max(s1, 0.6 * s2), 0.35 * s3) * dark_sq.z;
        vec2 wq = p * 2.0;
        vec2 warp = vec2(wnoise(wq, 2.0 * tile) + 0.5 * wnoise(wq * 2.0, 4.0 * tile),
                         wnoise(wq + 7.0, 2.0 * tile) + 0.5 * wnoise(wq * 2.0 + 7.0, 4.0 * tile));
        vec2 cl = wcells(p * 7.0 + warp * 0.4, 7.0 * tile);
        float craze = (1.0 - smoothstep(0.0, max(0.05, 8.4 * texel), cl.y - cl.x)) * dark_sq.y;
        vec2 dg = p * 2.5;
        vec2 dc = wcells(dg, 2.5 * tile);
        // A soft bowl, its size and depth its own.
        float r = 0.04 + 0.07 * hw(floor(dg) + 3.3, 2.5 * tile);
        float bowl = max(1.0 - dc.x * dc.x / (r * r), 0.0);
        float dent = bowl * bowl * (0.4 + 0.6 * hw(floor(dg) + 8.9, 2.5 * tile))
                   * step(0.91, hw(floor(dg), 2.5 * tile)) * dark_sq.w;
        return vec4(scratch, craze, dent, 0.0);
    }

    // What the table lays over its wood (dark_sq: tables::Table.patina, dark_fig its wear):
    // its age under a thick varnish. The varnish's blotches, darker and lighter by turns;
    // the rim worn lighter where hands rest. Its finer wear, the crazing, scratches, and
    // dents, is wear_at's, on a tile of its own: here only the patches where the top was
    // used (scratched, dented) and where it was left alone (crazed), in the cavity's
    // channel. The roughness baked is the polish's, which TABLE_FRAG takes on the top.
    Wood table_over(Wood w, Cut c, vec2 p) {
        float blot = fbm(p * 0.35 + 3.1) - 0.5;
        float fine = fbm(p * 1.7 + 8.3) - 0.5;
        w.albedo *= (1.0 + dark_sq.x * (1.6 * blot + 0.6 * fine)) * c.shade;
        // Flame mahogany (dark_ring: tables::Table.flame): the figure swept into flames and
        // swirls, the point warped twice by noise (Quilez's warp) across a flow along the
        // grain; dark where the bands run, golden between, darkened by Beer's law as stain
        // gathers. Book-matched (w over 0), two leaves mirrored about a seam down the
        // middle, as alike as w: the broad flow shared, the finer warp, the bands and the
        // streaks each leaf's own the more as w falls (two cuts of one log, not a mirror).
        if (dark_ring.x > 0.0) {
            bool matched = dark_ring.w > 0.0;
            vec2 f = (matched ? vec2(abs(p.x), p.y) : p) * dark_ring.y;
            vec2 own = (matched && p.x < 0.0 ? 1.0 - dark_ring.w : 0.0) * vec2(13.7, 5.3);
            vec2 w1 = vec2(fbm(f * 0.35 + 1.7 + 0.3 * own), fbm(f * 0.35 + 9.2 + 0.3 * own));
            vec2 w2 = vec2(fbm(f * 0.7 + w1 * 2.0 + 4.1 + own), fbm(f * 0.7 + w1 * 2.0 + 7.3 + own));
            float flow = f.x + dark_ring.z * 2.0 * (w2.x - 0.5) + 0.6 * dark_ring.z * (w1.y - 0.5) * f.y * 0.2;
            float band = fbm(vec2(flow * 1.6, f.y * 0.18 + 1.5 * w2.y) + own);
            float streak = vnoise(vec2(flow * 22.0, f.y * 1.4) + own) - 0.5;
            float a = 2.4 * (band - 0.5) + 0.5 * streak;
            // The light bands lighten half as far as the dark ones darken: golden, not pale.
            a = a > 0.0 ? a : 0.5 * a;
            w.albedo = pow(max(w.albedo, vec3(1e-4)), vec3(1.0 + dark_ring.x * a));
            w.height += 0.3 * streak * dark_ring.x;
        }
        float r = length(p);
        float rim = smoothstep(0.5 * size.z - dark_fig.y, 0.5 * size.z - 0.05, r)
                  * (0.5 + fbm(p * 1.3 + 31.0)) * dark_fig.x;
        w.albedo *= 1.0 + 0.8 * rim;
        w.rough = light_sq.a * (1.0 + 0.6 * blot) + 0.25 * rim;
        w.cavity = fbm(p * 0.4 + 11.0);
        return w;
    }

    #ifdef BAKE_ROOM
    // The finish on the room's oak, laid as a joiner and a century laid it: the oak's own
    // color (w, rings' with the pores and rays), a stain (dark_sq) that goes deepest into
    // the open pores, dark wax (dark_fig) packed into them, an amber shellac or wax
    // (inlay) over everything, then age (inlay_fig): the light's ambering, uneven,
    // blotches, and grime in the pores and low fibres. The roughness is the wax's
    // (light_sq.a), rougher in the pores, smoother on the rays' flakes.
    Wood oak_finish(Wood w, vec2 p, float seed) {
        vec3 c = w.albedo;
        c *= pow(srgb(dark_sq.rgb), vec3(dark_sq.a * (1.0 + 0.6 * w.pore)));
        c = mix(c, srgb(dark_fig.rgb), dark_fig.a * w.pore);
        c *= pow(srgb(inlay.rgb), vec3(inlay.a));
        float blot = fbm(p * vec2(0.08, 0.03) + seed) - 0.5;
        float fine = fbm(p * vec2(0.9, 0.25) + seed * 1.3) - 0.5;
        c *= pow(vec3(0.97, 0.88, 0.7), vec3(inlay_fig.x * (1.0 + blot)));
        c *= 1.0 + inlay_fig.y * (1.4 * blot + 0.6 * fine);
        c *= 1.0 - inlay_fig.z * clamp((1.0 - w.cavity) * 2.0, 0.0, 1.0);
        // The rays' flakes: their cells take less stain and shine, a shade lighter and
        // greyer than the wood round them, the rest in their gloss.
        float y = dot(c, vec3(0.2126, 0.7152, 0.0722));
        c = mix(c, mix(c, vec3(y), 0.15) * 1.15, w.fleck);
        // Its tint (surfaces::Oak.tint, in the frame's slot): lighter by x, greyer or more
        // coloured by y about its luminance.
        y = dot(c, vec3(0.2126, 0.7152, 0.0722));
        w.albedo = max(mix(vec3(y), c, frame.y), vec3(0.0)) * frame.x;
        w.rough = light_sq.a + 0.2 * w.pore - 0.05 * w.fleck + 0.08 * fine + 0.05 * blot;
        return w;
    }

    // The room's oak (model3d::surfaces): boards side by side across x, each surface.x wide
    // and from a tree of its own, a little lighter or darker (surface.z), quarter-sawn
    // (on the floor a share surface.y of them, on the wall every other) or flat-sawn,
    // their grain along y. p from the field's corner.
    Wood oak_at(vec2 p) {
        float i = floor(p.x / surface.x);
        float seed = 17.0 + i * 7.31 + mode.x * 31.7;
        bool quarter = mode.x < 4.5 ? h1(seed, 0.77) < surface.y : mod(i, 2.0) < 0.5;
        vec4 ring = light_ring;
        ring.y = quarter ? 0.0 : 1.0;
        vec2 q = vec2(p.x - (i + 0.5) * surface.x, p.y);
        Wood w = rings(q, seed, light_sq, light_fig, ring, true);
        float tone = (h1(seed, 4.2) - 0.5) * 2.0 * surface.z;
        w.albedo *= vec3(1.0 + tone, 1.0 + 0.85 * tone, 1.0 + 0.6 * tone);
        return oak_finish(w, p, seed);
    }
    #endif

    // One call of wood() for every surface: each call site compiles in full, and a phone
    // makes the pipeline slowly.
    Wood at(vec2 p) {
        #ifdef BAKE_ROOM
        return oak_at(p + 0.5 * size.zw);
        #else
        #ifdef BAKE_TABLE
        Cut c = table_cut(p);
        Wood w = wood(c.q, c.seed, c.base, c.k, c.f, c.ring);
        return table_over(w, c, p);
        #else
        Cut c = mode.x < 0.5 ? plan(p) : frame_map(p);
        Wood w = wood(c.q, c.seed, c.base, c.k, c.f, c.ring);
        return mode.x < 0.5 ? plan_over(w, c, p) : frame_over(w, c, p);
        #endif
        #endif
    }

    // size is the full bake's (model3d::BAKE_SIDE); a phone's half-size target takes
    // tone.w 2 samples a side a texel at the full bake's texels, averaged as its first mip
    // would be, so the wood's fine detail (its furrows and pores a texel or two across)
    // looks as it does on a larger screen instead of twice as coarse.
    void main() {
        vec2 texel = size.zw / size.xy;
        vec2 origin = mode.x < 0.5 || mode.x > 1.5 ? 0.5 * size.zw : vec2(0.0);
        int n = int(tone.w + 0.5);
        vec2 p = (floor(gl_FragCoord.xy) * float(n) + 0.5 * float(n)) * texel - origin;
        #ifdef BAKE_TABLE
        if (mode.x > 2.5) {
            // The table's wear: x scratches, y crazing, z dents into the first target; the
            // scratches' normal (x, z) and the dents' into the second, apart, as TABLE_FRAG
            // masks them apart.
            float relief = 0.0015 * surface.w;
            vec4 sum = vec4(0.0);
            vec4 bump = vec4(0.0);
            vec4 here = vec4(0.0);
            vec4 dx = vec4(0.0);
            for (int k = 0; k < 3 * n * n; k++) {
                int j = k % 3;
                int s = k / 3;
                vec2 q = (floor(gl_FragCoord.xy) * float(n) + vec2(float(s % n), float(s / n)) + 0.5) * texel - origin;
                vec2 o = j == 1 ? vec2(texel.x, 0.0) : (j == 2 ? vec2(0.0, texel.y) : vec2(0.0));
                vec4 t = wear_at(q + o);
                if (j == 0) here = t;
                else if (j == 1) dx = t;
                else {
                    // Scratches 1.5 deep, dents 3, in the bake's relief units: shallower
                    // than the top's map had them, as they are 4 times as steep here.
                    vec2 gs = -1.5 * (vec2(dx.x, t.x) - here.x) / texel;
                    vec2 gd = -3.0 * (vec2(dx.z, t.z) - here.z) / texel;
                    vec3 ns = normalize(vec3(-gs.x * relief, 1.0, -gs.y * relief));
                    vec3 nd = normalize(vec3(-gd.x * relief, 1.0, -gd.y * relief));
                    bump += vec4(ns.xz, nd.xz);
                    sum += vec4(here.xyz, 1.0);
                }
            }
            float share = 1.0 / float(n * n);
            out_albedo = sum * share;
            out_normal = bump * share * 0.5 + 0.5;
            return;
        }
        #endif
        #ifdef BAKE_SLAB
        if (mode.x < 1.5 && mode.w >= 5.0 && mode.w < 9.0) {
            bool frame_cut = mode.x > 0.5;
            vec2 sq = floor((p + FIELD) * (mode.z / (2.0 * FIELD)));
            if (frame_cut || (max(abs(p.x), abs(p.y)) < FIELD && mod(sq.x + sq.y, 2.0) > 0.5)) {
                vec2 q = p.yx;
                float shade = 1.0;
                if (!frame_cut) {
                    Cut c = plan(p);
                    float angle = 6.283 * h12(sq);
                    vec2 axis = vec2(cos(angle), sin(angle));
                    q = vec2(dot(p, axis), dot(p, vec2(-axis.y, axis.x))) + c.seed * 2.3;
                    shade = c.shade;
                }
                out_albedo = black_slab(q, 0.55 * float(n) * max(texel.x, texel.y));
                out_albedo.rgb *= shade;
                out_normal = vec4(0.5, 0.5, 1.0, 1.0);
                return;
            }
        }
        #endif
        #ifndef BAKE_TABLE
        #ifndef BAKE_ROOM
        if (mode.x > 0.5 && mode.x < 1.5 && mode.w > 0.5 && frame_fig.w < 0.5 && carve.w < 0.5) {
            // A marble frame, flat: once a texel, no relief to take the normal from.
            Wood m = marble_at(p.yx);
            out_albedo = vec4(m.albedo, m.rough);
            out_normal = vec4(0.5, 0.5, 1.0, 1.0);
            return;
        }
        #endif
        #endif
        // Each sample and its neighbours along x and y, for the normal, in a loop the
        // compiler can't unroll (its count comes from the block): unrolled, the whole
        // wood compiles three times over.
        float relief = 0.0015 * (mode.x < 0.5 || mode.x > 1.5 ? surface.w : frame_surface.y);
        Wood w;
        vec2 hn = vec2(0.0);
        vec4 albedo = vec4(0.0);
        vec3 normal = vec3(0.0);
        float cavity = 0.0;
        int taps = mode.x > 9.0 ? 4 : 3;
        for (int k = 0; k < taps * n * n; k++) {
            int j = k % taps;
            int s = k / taps;
            vec2 q = (floor(gl_FragCoord.xy) * float(n) + vec2(float(s % n), float(s / n)) + 0.5) * texel - origin;
            vec2 o = j == 1 ? vec2(texel.x, 0.0) : (j == 2 ? vec2(0.0, texel.y) : vec2(0.0));
            Wood t = at(q + o);
            if (j == 0) w = t;
            else if (j == 1) hn.x = t.height;
            else hn.y = t.height;
            if (j == 2) {
                vec2 grad = (hn - w.height) / texel;
                normal += normalize(vec3(-grad.x * relief, 1.0, -grad.y * relief));
                albedo += vec4(w.albedo, w.rough);
                cavity += w.cavity;
            }
        }
        float share = 1.0 / float(n * n);
        out_albedo = albedo * share;
        // The normal's x and z, the cavity's occlusion, the normal's y: what the samples
        // and the mips average shortens the normal, which widens the roughness where they
        // blur.
        vec3 m = normal * share;
        out_normal = vec4(m.x * 0.5 + 0.5, m.z * 0.5 + 0.5, cavity * share, m.y);
    }
    """;

// The photograph shrunk to a small copy, and blurred: the 3D board's backdrop and
// src/app/scene.goose's behind the 2D game, which draws with these two texts as they are
// (docs/architecture/rendering.md, "Scene and glass").
//
// SHRINK_FRAG averages a part of the source into a part of the target. Each target pixel
// takes taps spread evenly across its footprint, about two source texels apart, each a
// bilinear average of four texels: shrinking 4×, 2 × 2 taps on the texels' corners are an
// exact box of 4 × 4 texels.
let SHRINK_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D src;
    // The source's part in uv (origin, size), the target's in pixels (origin, size).
    layout(set = 3, binding = 0) uniform Shrink { vec4 from; vec4 to; };
    void main() {
        vec2 pixel = from.zw / to.zw;
        vec2 uv = from.xy + (gl_FragCoord.xy - to.xy) * pixel;
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
    // One texel's step in the source, sigma in source texels, one target pixel in uv.
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
// win's glow passing, z how many pieces the piece there takes, as pips (`count_pips`).
// marks' w 1 shades a lookout's crowning square.
// A win's dim (screen.z) dims them all but the glow rings. draw.y:
// squares per side. As the flat board draws them (src/app/draw.goose).
//
// Two shaders: without PULSE, in the board's pass, everything that holds still; with
// PULSE (MARKS_PULSE first), what moves while nothing else does, drawn each frame over
// the kept image in the screen's pass (render3d::marks_over): the pulsing must-capture
// rings, the flash, the hint's pulsing ring, their phases from the Pulse block. That pass
// has no depth target, so the shader tests the kept depth (a 1x copy of the board's,
// made with it) itself, at the pixel's middle.
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
    // its texels per pixel, and how opaque it is laid; more: x how lit a capture's next
    // stops' dots are while they pulse, y the keys' cursor's square, or -1.
    layout(set = 3, binding = 2) uniform Pulse { vec4 pulse; vec4 place; vec4 more; };
    #else
    layout(std430, set = 2, binding = 0) readonly buffer Marks { vec4 marks[]; };
    layout(std430, set = 2, binding = 1) readonly buffer Lit { vec4 lit[]; };
    #endif
    layout(set = 3, binding = 1) uniform Draw { vec4 draw; };
    float thin_ring(float d, float w) { return exp(-pow(d / (0.6 * w + 0.008), 2.0)); }
    // A legal target's glowing dot, r from its square's middle and w a pixel, in squares.
    float dot_at(float r, float w) {
        return 0.9 * (1.0 - smoothstep(0.15 - w, 0.15 + w, r)) + 0.35 * exp(-max(r - 0.15, 0.0) / 0.05);
    }
    #ifndef PULSE
    float seg(vec2 p, vec2 a, vec2 b) {
        vec2 pa = p - a, ba = b - a;
        return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
    }
    // A digit's strokes' distance at p, the digit spanning x -0.5..0.5 and y -1..1 (down),
    // as src/app/draw.goose's.
    float digit(vec2 p, int d) {
        const int SEGS[10] = int[](0x3F, 0x06, 0x5B, 0x4F, 0x66, 0x6D, 0x7D, 0x07, 0x7F, 0x6F);
        int m = SEGS[clamp(d, 0, 9)];
        float r = 1e5;
        if ((m & 1) != 0) r = min(r, seg(p, vec2(-0.5, -1.0), vec2(0.5, -1.0)));
        if ((m & 2) != 0) r = min(r, seg(p, vec2(0.5, -1.0), vec2(0.5, 0.0)));
        if ((m & 4) != 0) r = min(r, seg(p, vec2(0.5, 0.0), vec2(0.5, 1.0)));
        if ((m & 8) != 0) r = min(r, seg(p, vec2(-0.5, 1.0), vec2(0.5, 1.0)));
        if ((m & 16) != 0) r = min(r, seg(p, vec2(-0.5, 0.0), vec2(-0.5, 1.0)));
        if ((m & 32) != 0) r = min(r, seg(p, vec2(-0.5, -1.0), vec2(-0.5, 0.0)));
        if ((m & 64) != 0) r = min(r, seg(p, vec2(-0.5, 0.0), vec2(0.5, 0.0)));
        return r;
    }
    // Paints col at coverage a over acc, premultiplied.
    void over(inout vec4 acc, vec3 col, float a) { acc = vec4(col * a, a) + acc * (1.0 - a); }
    // How many pieces a piece takes (lit.z), as the flat board's pips: one per piece, light
    // with a red rim, 22 degrees apart round the piece at 0.6 of a square, on the must-
    // capture ring, centred on the side toward the eye, which the piece doesn't hide (its
    // far side it does); past five, one larger red pip with the number. f is the pixel
    // from the piece's middle and t the way toward the eye, both on the field in squares;
    // w a pixel in squares. Painted over acc, premultiplied: added light alone would wash
    // out on a light square.
    void count_pips(inout vec4 acc, vec2 f, vec2 t, int n, float w) {
        vec3 red = vec3(1.0, 0.353, 0.29);
        vec3 light = vec3(1.0, 0.957, 0.925);
        vec2 p = vec2(dot(f, vec2(t.y, -t.x)), dot(f, t));    // x right, y toward the eye
        if (n <= 5) {
            for (int i = 0; i < n; i++) {
                float a = radians((float(i) - 0.5 * float(n - 1)) * 22.0);
                float d = length(p - 0.6 * vec2(sin(a), cos(a)));
                over(acc, red, 0.4 * exp(-max(d - 0.085, 0.0) / 0.03));
                over(acc, red, 1.0 - smoothstep(0.115 - w, 0.115 + w, d));
                over(acc, light, 1.0 - smoothstep(0.085 - w, 0.085 + w, d));
            }
            return;
        }
        vec2 q = p - vec2(0.0, 0.66);
        float d = length(q);
        over(acc, red, 0.4 * exp(-max(d - 0.156, 0.0) / 0.03));
        over(acc, light, 1.0 - smoothstep(0.18 - w, 0.18 + w, d));
        over(acc, red, 1.0 - smoothstep(0.156 - w, 0.156 + w, d));
        float s = 0.066;        // a digit's half height, its stroke 0.014
        float k = n < 10 ? digit(q / s, n) : min(digit((q - vec2(-0.047, 0.0)) / s, n / 10 % 10),
                                                 digit((q - vec2(0.047, 0.0)) / s, n % 10));
        over(acc, light, 1.0 - smoothstep(0.014 - w, 0.014 + w, k * s));
    }
    #endif
    #ifdef PULSE
    // Whether the board's depth leaves the quad here: its kept texel under the pixel.
    bool seen() {
        ivec2 t = ivec2(floor((gl_FragCoord.xy - place.xy) * place.z));
        return gl_FragCoord.z < texelFetch(kept_depth, clamp(t, ivec2(0), textureSize(kept_depth, 0) - 1), 0).r;
    }
    #endif
    void main() {
        vec3 c = vec3(0.0);
        vec4 shade = vec4(0.0);
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
            c += glow.rgb * glow.w * (0.85 * thin_ring(r - ring, w) + 0.3 * halo);
        }
        if (q.x >= 0 && q.y >= 0 && q.x < int(n) && q.y < int(n)) {
            vec4 m = marks[q.y * int(n) + q.x];
            float r = length(fract(g) - 0.5);       // in squares from its middle
            float w = wg;
            if (m.x > 0.5) c += glow.rgb * 0.10;
            // The lookout's crowning square (w 1): shaded toward a deep red for danger,
            // darkest along its edges, as an inset shadow, under the dark ghost king on it.
            if (m.w > 0.5) {
                vec2 e2 = min(fract(g), 1.0 - fract(g));
                over(shade, vec3(0.3, 0.03, 0.02), 0.3 + 0.32 * (1.0 - smoothstep(0.0, 0.25, min(e2.x, e2.y))));
            }
            if (m.y > 0.5 && m.y < 1.5) c += glow.rgb * dot_at(r, w);
            if (m.y > 1.5) c += glow.rgb * 0.9 * thin_ring(r - 0.18, w);
            // Where a piece waiting on a capture's stop goes on: the target's dot, lit
            // still here once its pulse is over (lit.w 1), over the image while it pulses.
            if (lit[q.y * int(n) + q.x].w > 0.5 && lit[q.y * int(n) + q.x].w < 1.5) c += glow.rgb * dot_at(r, w);
            // A win's glow passing lights the square, as the last move's tint does more.
            c += glow.rgb * 0.3 * lit[q.y * int(n) + q.x].y;
        }
    #endif
    #ifdef PULSE
        if (q.x >= 0 && q.y >= 0 && q.x < int(n) && q.y < int(n) && lit[q.y * int(n) + q.x].w > 1.5) {
            c += glow.rgb * more.x * dot_at(length(fract(g) - 0.5), wg);
        }
        // The keys' cursor: a glow line round its square just inside the edge, its corners
        // rounded, as the flat board's (src/gfx/draw_gpu.goose).
        if (q.x >= 0 && q.y >= 0 && q.x < int(n) && q.y < int(n) && float(q.y * int(n) + q.x) == more.y) {
            vec2 e = abs(fract(g) - 0.5);
            vec2 dd = e - vec2(0.43 - 0.12);
            float bd = abs(length(max(dd, vec2(0.0))) + min(max(dd.x, dd.y), 0.0) - 0.12);
            c += glow.rgb * (0.95 * (1.0 - smoothstep(0.014 - wg, 0.014 + wg, bd)) + 0.3 * exp(-bd / 0.035));
        }
    #endif
        vec3 rings = vec3(0.0);
        // The red rings go a little out from a piece (0.44 of a square), past its square's
        // edge, so each pixel looks at the squares round it too.
        vec3 red = vec3(1.0, 0.353, 0.29);
        vec3 reds = vec3(0.0);
        vec4 pips = vec4(0.0);
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
                    rings += glow.rgb * glow.w * k_ring * (1.1 * thin_ring(r - rr, w) + 0.45 * halo);
                }
                // The must-capture ring: brightest still, fading to 0.4 and back pulsing.
    #ifdef PULSE
                float strength = m.z > 0.5 && m.z < 1.5 ? 0.95 - 0.55 * pulse.x : 0.0;
    #else
                float strength = m.z > 1.5 ? 0.95 : 0.0;
    #endif
                if (strength > 0.0) {
                    float rr = 0.52;
                    reds += red * strength * (0.9 * thin_ring(r - rr, w) + 0.35 * exp(-abs(r - rr) / 0.04));
                }
    #ifndef PULSE
                if (lit[at].z > 0.5) {
                    vec2 mid = vec2(k) + 0.5;
                    vec2 toward = normalize(eye.xz - (mid * u - FIELD));
                    count_pips(pips, g - mid, toward, int(lit[at].z + 0.5), w);
                }
    #endif
    #ifdef PULSE
                if (m.w > -0.5 && m.w < 0.5 && pulse.y < 1.0) {
                    float t = fract(pulse.y * 2.0);
                    float op = t < 0.4 ? t / 0.4 : 1.0 - 0.4 * (t - 0.4) / 0.6;
                    float rr = 0.5 * (0.8 + 0.2 * min(t / 0.4, 1.0));
                    reds += red * op * (0.9 * thin_ring(r - rr, w) + 0.25 * (1.0 - smoothstep(rr - w, rr + w, r)));
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
        // Blended premultiplied: the marks add, alpha 0, and the pips and the shade cover
        // what is under.
        pips = pips + shade * (1.0 - pips.a);
        result = vec4(pips.rgb + c * (1.0 - pips.a), pips.a);
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

// The kept backdrop (render3d::keep_backdrop: BACKDROP_FRAG at full opacity, the
// screen's size) laid texel for texel at opacity draw.x: a fetch a pixel rather than the
// backdrop's grade, vignette, and fade.
let KEPT_FRAG = """
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D kept;
    layout(set = 3, binding = 0) uniform Kept { vec4 draw; };
    void main() { result = vec4(texelFetch(kept, ivec2(gl_FragCoord.xy), 0).rgb, draw.x); }
    """;

// The kept image (premultiplied, clear where no board is) drawn over what is there: its
// rect `from` (pixels of the image) into the rect `to` (pixels of the target), at
// opacity screen.z; the same rect texel for texel at rest, moved and scaled in a
// transition. screen.w greys it (a new theme being prepared over it, draw3d's grey):
// at 1 its saturation GREY_SAT of its own and its brightness GREY_BRIGHT.
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
    const float GREY_SAT = 0.15;
    const float GREY_BRIGHT = 0.8;
    void main() {
        vec4 c = texture(src, v_uv);
        float luma = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
        c.rgb = mix(c.rgb, vec3(luma), screen.w * (1.0 - GREY_SAT)) * (1.0 - screen.w * (1.0 - GREY_BRIGHT));
        result = c * screen.z;
    }
    """;

// Dust in the sunbeam (render3d::Dust), the main menu's scene only: points drifting in the
// sunbeam's own volume over the table, one camera-facing quad each, drawn as instances after
// the scene and added to it. Each point's light is the sun through the shell's windows where
// it is (shell_open's direct light, LIGHT_FN before DUST_VERT), worked out once in the vertex
// shader, so the beam has the pattern's shape and none is drawn where none is lit. Where a
// point is comes from its seed (`motes`, filled once) and the seconds, so nothing is
// uploaded a frame. dust_box: the volume's low corner, w the seconds; dust_span: its size
// along dust_u (the window wall), dust_v (up) and dust_w (into the room along the beam),
// each a world vector; dust_look: y the lens's blur (the disc's radius in pixels at 1000
// high where the distance is twice the focus's), z how bright, w the focus's distance from
// the eye; dust_lens: y the forward scattering's g, w the largest disc's radius in those
// pixels (0 none; the lens's near cap, render3d::Lens). The shell's windows after them, as
// ROOM_HEAD's block has them (render3d::dust_block), with the lace's mask, for LIGHT_FN's
// shell_open, which the dust is compiled with (SHELL_WINDOWS). dust_shape: z the share of
// fibres, w their width across as a share of a point's.
// The points (build/notes/window-view/refs/research-haze-motes.md): every flake is far under
// a pixel, so it is a point of a fixed footprint, a Gaussian dust_point.x pixels wide (sigma)
// at any resolution and distance, carrying the light it really scatters: the sun's
// irradiance × its cross-section × its phase × the pixels a metre squared there, summed over
// the footprint. Sizes log-normal (a median 25 µm flake), fibres 10 µm thick and 0.5-3 mm
// long as lines of that length on the screen, dust_shape.w of a point's width across with
// the same light (sub-pixel, so they don't read as stripes). Flakes glint as they tumble
// (0.1-1 turn a second): a lobe 2-6° round the mirror direction, 5-15 times as bright,
// dust_point.y of it (0 none). They move in world centimetres a second (dust_move: x the
// air's drift along the wall, y the rise over the sun's patch, slower higher up, z the
// swirls' speed, w their size in cm), settling by their size; no step is random a frame.
// dust_point.z: the sun on the room's surfaces over the board's (Room.shell_sun.y ×
// room_exposure), so a point is lit as the wall behind it; w a metre in world units.
// dust_near: x the board's share along dust_w, y how much denser the points are round it
// (0 even). With the lens on, a point becomes the lens's disc with its light spread over it.
let DUST_HEAD = """
    layout(set = 0, binding = 0) uniform sampler2D tree_map;
    layout(set = 0, binding = 1) uniform sampler2D lace_mask;
    layout(std430, set = 0, binding = 2) readonly buffer Motes { vec4 motes[]; };
    layout(set = 1, binding = 1) uniform Dust {
        vec4 dust_box;
        vec4 dust_span;
        vec4 dust_look;
        vec4 dust_lens;
        vec4 axes;
        vec4 tile;
        vec4 shell;
        vec4 shell_mids;
        vec4 shell_niche;
        vec4 shell_glass;
        vec4 shell_sun;
        vec4 window_view;
        vec4 dust_u;
        vec4 dust_v;
        vec4 dust_w;
        vec4 dust_shape;
        vec4 dust_move;
        vec4 dust_point;
        vec4 dust_near;
    };
    """;
let DUST_VERT = """
    layout(location = 0) out vec2 v_at;
    layout(location = 1) flat out vec4 v_glow;
    layout(location = 2) flat out vec4 v_shape;

    // A unit vector from two numbers 0..1.
    vec3 sphere_dir(vec2 r) {
        float z = 2.0 * r.x - 1.0;
        float a = 6.2832 * r.y;
        float q = sqrt(max(1.0 - z * z, 0.0));
        return vec3(q * cos(a), z, q * sin(a));
    }

    // v turned by angle a about the unit axis k (Rodrigues).
    vec3 turned_about(vec3 v, vec3 k, float a) {
        float c = cos(a);
        return v * c + cross(k, v) * sin(a) + k * dot(k, v) * (1.0 - c);
    }

    // The screen's direction (pixels) of a world vector d at pos, and its length there.
    vec2 on_screen(vec3 pos, vec3 d, vec4 clip) {
        vec4 c2 = view_proj * vec4(pos + d, 1.0);
        return (c2.xy / c2.w - clip.xy / clip.w) * 0.5 * screen.xy;
    }

    // The air's swirls at p (world units) after t seconds, as a displacement: four slow
    // transverse waves, each 5-20 cm long (dust_move.w its middle) and turning over in 2-6
    // s, so motes a few centimetres apart move together and their paths curl; the sum's
    // speed about dust_move.z cm a second. Free of divergence, so the dust neither bunches
    // nor thins.
    const vec3 SWIRL_K[4] = vec3[4](vec3(0.6, 0.0, 0.8), vec3(0.0, 0.6, 0.8), vec3(0.8, 0.6, 0.0), vec3(0.48, -0.6, 0.64));
    const vec3 SWIRL_B[4] = vec3[4](vec3(0.0, 1.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(0.0, 0.0, 1.0), vec3(0.8, 0.0, -0.6));
    const float SWIRL_LONG[4] = float[4](0.55, 0.8, 1.15, 1.6);
    const float SWIRL_TURN[4] = float[4](2.3, 3.4, 4.6, 5.9);
    const float SWIRL_SHARE[4] = float[4](0.45, 0.4, 0.35, 0.3);
    vec3 swirl(vec3 p, float t, float cm) {
        vec3 d = vec3(0.0);
        for (int j = 0; j < 4; j++) {
            float k = 6.2832 / (SWIRL_LONG[j] * dust_move.w * cm);
            float w = 6.2832 / SWIRL_TURN[j];
            float a = SWIRL_SHARE[j] * dust_move.z * cm / w;
            d += SWIRL_B[j] * (a * cos(k * dot(SWIRL_K[j], p) + w * t + 1.7 * float(j)));
        }
        return d;
    }

    void main() {
        const vec2 corners[6] = vec2[6](vec2(-1, -1), vec2(1, -1), vec2(1, 1),
                                        vec2(-1, -1), vec2(1, 1), vec2(-1, 1));
        vec2 c = corners[gl_VertexIndex];
        vec4 s = motes[gl_InstanceIndex % 1024];
        vec4 s2 = motes[(gl_InstanceIndex + 517) % 1024];
        vec4 s3 = motes[(gl_InstanceIndex + 263) % 1024];
        float t = dust_box.w;
        bool fibre = fract(s.w * 53.1 + s.x * 3.7) < dust_shape.z;
        float cm = 0.01 * dust_point.w;
        // A point's size against the median (log-normal, a sigma of 0.55: a third of them
        // past 1.7 times as large or small).
        float grain = exp(0.55 * clamp(sqrt(-2.0 * log(max(s2.x, 1e-4))) * cos(6.2832 * s2.y), -2.5, 2.5));
        // Carried by the air along the wall at 0.5-1.5 times its drift, a little across,
        // risen over the sun's patch and settling by size (a fibre's drag slows it), the
        // height eased so the rise is quicker low down than high.
        float settle = (fibre ? 0.6 : 1.0) * clamp(0.45 * grain * grain, 0.2, 1.5) * cm;
        vec2 dir = normalize(vec2(1.0, 0.8 * (s3.y - 0.5)));
        float drift = dust_move.x * (0.5 + s3.x) * cm;
        vec3 rate = vec3(drift * dir.x, dust_move.y * cm - settle, drift * dir.y) / dust_span.xyz;
        vec3 f = fract(s.xyz + rate * t);
        float h = f.y + 0.35 * f.y * (1.0 - f.y);
        vec3 pos = dust_box.xyz + f.x * dust_u.xyz + h * dust_v.xyz + f.z * dust_w.xyz;
        pos += swirl(pos, t, cm);
        // Faded near the box's faces, so a point wrapping round doesn't pop; none inside
        // the board.
        vec3 e = min(f, 1.0 - f) * 12.0;
        float fade = clamp(min(e.x, min(e.y, e.z)), 0.0, 1.0);
        if (max(abs(pos.x), abs(pos.z)) < INNER + FRAME_W && pos.y < FRAME_TOP + 0.02) fade = 0.0;
        // Denser round the board: each kept where its own number is under the density
        // there, fading in and out as it drifts.
        if (dust_near.y > 0.0) {
            vec2 off = vec2((f.x - 0.5) / 0.32, (f.z - dust_near.x) / 0.38);
            float dense = 0.35 + 0.65 * exp(-dot(off, off)) * (1.0 - 0.45 * f.y);
            fade *= smoothstep(0.0, 0.2, mix(1.0, dense, dust_near.y) - 0.8 * fract(s.w * 91.7));
        }

        // The sun through the window where it is, 0..1; all of it with no pattern.
        float sun = room.y > 0.0 ? clamp((window_light(pos) - 1.0 + room.y) / room.y, 0.0, 1.0) : 1.0;
        vec3 to_eye = eye.xyz - pos;
        float d = length(to_eye);
        vec3 v = to_eye / d;
        float g = dust_lens.y;
        float mu = dot(v, -light_dir.xyz);
        vec4 clip = view_proj * vec4(pos, 1.0);
        float px = screen.y / 1000.0;
        float coc = dust_look.y * px * abs(d - dust_look.w) / max(d, 0.01);
        if (dust_lens.w > 0.0) coc = min(coc, dust_lens.w * px);
        // Unlit, it is not drawn at all.
        if (sun * fade < 0.003) fade = 0.0;

        vec2 ax = vec2(1.0, 0.0);
        // The light it scatters, the sun's irradiance where it is (as the room's surfaces
        // take it) x its cross-section in m^2 x its phase (1/sr: Henyey-Greenstein at g with
        // a fifth even, and a narrow peak a few degrees round the sun's line, the diffraction
        // of a particle many wavelengths across) x the pixels a metre there squared: the sum
        // of its pixels, which the fragment's footprint keeps.
        float hg = (1.0 - g * g) / (12.566 * pow(1.0 + g * g - 2.0 * g * mu, 1.5));
        float angle = acos(clamp(mu, -1.0, 1.0));
        float p = 0.8 * hg + 0.2 / 12.566 + 30.0 * exp(-angle * angle / 0.0027);
        float fibre_long = 0.0005 * pow(6.0, fract(s3.z * 3.1 + s.y));
        float area = fibre ? fibre_long * 1.0e-5 : 3.1416 * pow(12.5e-6 * grain, 2.0);
        vec3 side = normalize(cross(v, vec3(0.0, 1.0, 0.0)) + vec3(1e-4, 0.0, 0.0));
        float per_metre = length(on_screen(pos, side * cm, clip)) * 100.0;
        vec3 glow = light_color.rgb * (light_dir.w * params.x * dust_point.z * sun * dust_look.z * area * p * per_metre * per_metre);
        // A faint tint of its own, a few percent.
        glow *= 1.0 + 0.06 * (s3.xyz - 0.5);
        float sigma = dust_point.x;
        float across = sigma;
        float along = 0.0;
        if (fibre) {
            // Lint: its length across the view at the screen, tumbling slowly, thinner than
            // a point across.
            vec3 spin = sphere_dir(vec2(fract(s.w * 7.31 + s.y * 3.1), fract(s.w * 17.9 + s.z * 5.3)));
            vec3 axis = normalize(turned_about(sphere_dir(s2.zw), spin, t * 0.4 * (0.3 + fract(s3.w * 5.7)) + 6.2832 * s.z));
            vec2 long_px = on_screen(pos, (axis - v * dot(axis, v)) * (fibre_long * 100.0 * cm), clip);
            along = length(long_px);
            ax = along > 1e-4 ? long_px / along : vec2(1.0, 0.0);
            across = sigma * dust_shape.w;
        } else if (dust_point.y > 0.0) {
            // A flake's glint: its face tumbling at 0.1-1 turn a second, flashing as it
            // passes the mirror direction between the sun and the eye; the lobe wider for the
            // quick ones, so each flash lasts a few frames.
            vec3 spin = sphere_dir(vec2(fract(s.w * 7.31 + s.y * 3.1), fract(s.w * 17.9 + s.z * 5.3)));
            float turn = 6.2832 * 0.1 * pow(10.0, fract(s3.z * 7.7 + s.x));
            vec3 face = normalize(turned_about(sphere_dir(s2.zw), spin, t * turn + 6.2832 * s.z));
            vec3 hv = normalize(light_dir.xyz + v);
            float off_mirror = acos(min(abs(dot(face, hv)), 1.0));
            float lobe = clamp(turn * 0.03, 0.035, 0.105);
            glow *= 1.0 + dust_point.y * (5.0 + 10.0 * s3.w) * exp(-off_mirror * off_mirror / (lobe * lobe));
        }
        float reach = 3.0 * sigma + coc;
        vec2 half_px = vec2(0.5 * along + reach, reach);
        v_shape = vec4(sigma, coc, along, across);
        v_glow = vec4(glow * fade, 0.0);
        vec2 outer = half_px + 1.0;
        vec2 side_ax = vec2(-ax.y, ax.x);
        v_at = c * outer;
        vec2 off = ax * (c.x * outer.x) + side_ax * (c.y * outer.y);
        clip.xy += off * 2.0 / screen.xy * clip.w;
        gl_Position = clip.w > 0.1 && fade > 0.0 ? clip : vec4(0.0, 0.0, -2.0, 1.0);
    }
    """;
let DUST_FRAG = """
    layout(location = 0) in vec2 v_at;
    layout(location = 1) flat in vec4 v_glow;
    layout(location = 2) flat in vec4 v_shape;
    layout(location = 0) out vec4 result;
    void main() {
        // A point's footprint, its sum over the pixels 1: a Gaussian sigma v_shape.x pixels
        // round a line v_shape.z long (0 a flake), v_shape.w across it; with the lens's disc
        // v_shape.y round, that disc's even light, its edge as soft as the point.
        float sigma = v_shape.x;
        float r_lens = v_shape.y;
        float line = v_shape.z;
        float lens2 = 0.25 * r_lens * r_lens;
        float wide = sigma * sigma + lens2;
        float thin = v_shape.w * v_shape.w + lens2;
        float dx = max(abs(v_at.x) - 0.5 * line, 0.0);
        float spot = exp(-0.5 * (dx * dx / wide + v_at.y * v_at.y / thin)) / (6.2832 * sqrt(wide * thin) + 2.5066 * sqrt(thin) * line);
        float r = length(vec2(dx, v_at.y));
        float disc = (1.0 - smoothstep(r_lens - sigma, r_lens + sigma, r)) / (3.1416 * r_lens * r_lens + 2.0 * r_lens * line + 1e-4);
        float k = mix(spot, disc, smoothstep(1.5 * sigma, 4.0 * sigma, r_lens));
    #ifdef HDR_OUT
        result = vec4(v_glow.rgb * k, 1.0);
    #else
        result = vec4(pow(v_glow.rgb * k, vec3(1.0 / 2.2)), 1.0);
    #endif
    }
    """;
// The haze in the sunbeam (render3d::haze_pass, Haze). The sun is one direction and the
// window's glass flat, so every point of the room maps along the sun onto the outer glass's
// plane, and how much sun reaches it is what passes there: the panes (render3d::haze_panes),
// the lace and the tree outside all as seen in that plane. HAZE_CROSS_FRAG draws that
// cross-section of the beam each frame into a small atlas, a slot each window: x the panes'
// coverage of the texel exactly (each a product set, so its share of a box is the columns'
// share times the rows'), times the lace and the tree; y the same blurred by haze_blur_most.
// HAZE_FRAG then takes each pixel's view from the eye to what the pre-pass drew there
// (pre_place) onto that plane, where it is a straight segment, and averages the atlas over
// haze_look.z jittered taps along its part in each window's slot: the beam's lit length on
// the view. Each tap's blur is the sun's disc's widening of the bars' shadows at its depth
// from the glass, times haze_look.w (1 as the disc does it, more a softer beam), and times
// 1 + haze_pixel.z more looking toward the sun, where the stripes converge on it; a mix of
// x and y by it. Then sigma × the phase (Henyey-Greenstein at g, haze_look.y of it even)
// × the sun as the room's surfaces take it (haze_light), the room's linear light a pixel.
// haze_plane: x the outer glass's depth along the wall's normal, y and z how far along u
// and up the sun moves a unit of that depth, w the windows; haze_pixel: xy a pixel of the
// target in uv; haze_box0..2 the windows' panes' boxes in the plane.
let HAZE_BLOCK = """
    layout(set = 3, binding = 1) uniform Haze {
        vec4 axes;
        vec4 tile;
        vec4 shell;
        vec4 shell_mids;
        vec4 shell_niche;
        vec4 shell_glass;
        vec4 shell_sun;
        vec4 window_view;
        vec4 haze_light;
        vec4 haze_look;
        vec4 haze_plane;
        vec4 haze_ranges;
        vec4 haze_pixel;
        vec4 haze_box0;
        vec4 haze_box1;
        vec4 haze_box2;
    };
    // The atlas's slot's size in texels; the depth from the glass (metres) whose blur its y
    // holds, the deepest the beam reaches across the room.
    const vec2 HAZE_SLOT = vec2(192.0, 384.0);
    const float HAZE_DEEPEST = 5.0;
    float haze_widen() { return shell_sun.x > 0.0 ? shell_sun.x : room.z; }
    // The stripes' blur (world units, a half width) at depth from the glass, times soft.
    float haze_blur(float depth, float soft) { return 0.5 * soft * (0.03 + haze_widen() * max(depth, 0.0)); }
    float haze_blur_most() { return haze_blur(HAZE_DEEPEST * shell.w, haze_look.w * (1.0 + haze_pixel.z)); }
    // Window w's slot: its panes' box grown by the blur and a few texels.
    vec4 haze_slot(int w) {
        vec4 b = w == 0 ? haze_box0 : (w == 1 ? haze_box1 : haze_box2);
        float m = haze_blur_most() + 0.02 * shell.w;
        return b + vec4(-m, -m, m, m);
    }
    """;
// HAZE_CROSS_FRAG's inputs, before LIGHT_FN (its lace_shadow and tree_light).
let HAZE_CROSS_HEAD = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D tree_map;
    layout(set = 2, binding = 1) uniform sampler2D lace_mask;
    layout(std430, set = 2, binding = 2) readonly buffer BeamPanes { vec4 beam_panes[]; };
    """;
let HAZE_CROSS_FRAG = """
    // The share of x0..x1 (r) that the intervals lo..hi cover.
    float covered(vec2 r, float lo, float hi) { return max(min(r.y, hi) - max(r.x, lo), 0.0); }

    // The share of the box q ± h the panes of the windows' range first..last cover: each product
    // set's columns' share of its width times its rows' of its height.
    float panes_cover(vec2 q, vec2 h, int first, int last) {
        float sum = 0.0;
        int i = first;
        for (int k = 0; k < 8 && i < last; k++) {
            vec4 b = beam_panes[i];
            int nx = int(beam_panes[i + 1].x);
            int ny = int(beam_panes[i + 1].y);
            if (q.x + h.x > b.x && q.x - h.x < b.z && q.y + h.y > b.y && q.y - h.y < b.w) {
                float cx = 0.0;
                for (int j = 0; j < nx; j++) cx += covered(beam_panes[i + 2 + j].xy, q.x - h.x, q.x + h.x);
                float cy = 0.0;
                for (int j = 0; j < ny; j++) cy += covered(beam_panes[i + 2 + nx + j].xy, q.y - h.y, q.y + h.y);
                sum += cx * cy;
            }
            i += 2 + nx + ny;
        }
        return sum / (4.0 * h.x * h.y);
    }

    // What the lace in front of window w lets through at the outer glass's point p, its pattern
    // blurred as at `far` (world units) past it, and the tree outside.
    float lace_tree(vec3 p, int w, float far) {
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        float m = 1.0;
        float tl = (shell.y - shell_glass.z - dot(p.xz, nw)) / toward;
        vec3 c = p + l * tl;
        float mid = w == 0 ? shell_mids.x : (w == 1 ? shell_mids.y : shell_mids.z);
        vec2 wl = vec2(dot(c.xz, along) - mid, c.y - shell.z) / shell.w;
        float soft_l = (0.03 + haze_widen() * far) / shell.w + LACE_SOFT * far / shell.w;
        m *= lace_shadow(wl, soft_l, 0.0).x;
        if (tree.x > 0.0) {
            vec2 tr = tree_light(p, l, nw, along, toward);
            m *= tr.x * tr.y;
        }
        return m;
    }

    void main() {
        vec2 f = gl_FragCoord.xy / (HAZE_SLOT * vec2(3.0, 1.0));
        int w = int(f.x * 3.0);
        result = vec4(0.0, 0.0, 0.0, 1.0);
        if (float(w) >= haze_plane.w) return;
        vec4 s = haze_slot(w);
        vec2 at = vec2(fract(f.x * 3.0), f.y);
        vec2 q = mix(s.xy, s.zw, at);
        vec2 texel = (s.zw - s.xy) / HAZE_SLOT;
        int first = w == 0 ? 3 : int(haze_ranges[w - 1]);
        int last = int(haze_ranges[w]);
        float sharp = panes_cover(q, 0.5 * texel, first, last);
        float blurred = panes_cover(q, 0.5 * texel + haze_blur_most(), first, last);
        if (sharp + blurred <= 0.0) return;
        vec3 p = vec3(0.0, q.y, 0.0);
        p.xz = axes.xy * q.x - axes.zw * haze_plane.x;
        float far = HAZE_DEEPEST * shell.w;
        result = vec4(sharp * lace_tree(p, w, 0.2 * far), blurred * lace_tree(p, w, far), 0.0, 1.0);
    }
    """;
let HAZE_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D cross_map;
    layout(set = 2, binding = 1) uniform sampler2D pre_place;

    // The part (0..1) of the segment a + s d inside the box r (x0, y0, x1, y1), inv 1 / d: its
    // first and last s.
    vec2 box_span(vec4 r, vec2 a, vec2 inv) {
        vec4 t = (r - a.xyxy) * inv.xyxy;
        vec2 lo = min(t.xy, t.zw);
        vec2 hi = max(t.xy, t.zw);
        return vec2(max(max(lo.x, lo.y), 0.0), min(min(hi.x, hi.y), 1.0));
    }

    // Where p is carried along the sun onto the outer glass's plane.
    vec2 on_glass(vec3 p, vec2 nw, vec2 along) {
        float back = haze_plane.x - dot(p.xz, nw);
        return vec2(dot(p.xz, along) + haze_plane.y * back, p.y + haze_plane.z * back);
    }

    void main() {
        vec4 at = textureLod(pre_place, gl_FragCoord.xy * haze_pixel.xy, 0.0);
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        result = vec4(0.0, 0.0, 0.0, 1.0);
        if (at.w <= 0.0 || toward < 0.05) return;
        vec3 p0 = eye.xyz;
        vec3 p1 = eye.xyz + at.xyz;
        vec2 a = on_glass(p0, nw, along);
        vec2 d = on_glass(p1, nw, along) - a;
        vec2 inv = 1.0 / vec2(d.x >= 0.0 ? max(d.x, 1e-6) : min(d.x, -1e-6), d.y >= 0.0 ? max(d.y, 1e-6) : min(d.y, -1e-6));
        float depth0 = (haze_plane.x - dot(p0.xz, nw)) / toward;
        float depth1 = (haze_plane.x - dot(p1.xz, nw)) / toward;
        float mu = dot(normalize(at.xyz), l);
        float soft = haze_look.w * (1.0 + haze_pixel.z * smoothstep(0.5, 1.0, mu));
        float most = haze_blur_most();
        // A tap's place along the span, jittered pixel by pixel (interleaved gradient noise).
        float jitter = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715))));
        int taps = max(int(haze_look.z), 1);
        float lit = 0.0;
        for (int w = 0; w < 3; w++) {
            if (float(w) >= haze_plane.w) break;
            vec4 s = haze_slot(w);
            vec2 sb = box_span(s, a, inv);
            if (sb.y <= sb.x) continue;
            float step = (sb.y - sb.x) / float(taps);
            // A tap stands for its step: blurred at least as far as half of it reaches.
            float reach = 0.5 * step * length(d);
            float sum = 0.0;
            for (int k = 0; k < taps; k++) {
                float t = sb.x + (float(k) + jitter) * step;
                vec2 uv = (a + d * t - s.xy) / (s.zw - s.xy);
                vec2 c = textureLod(cross_map, vec2((float(w) + uv.x) / 3.0, uv.y), 0.0).xy;
                float blur = max(haze_blur(mix(depth0, depth1, t), soft), reach);
                sum += mix(c.x, c.y, clamp(blur / most, 0.0, 1.0));
            }
            lit += sum * step;
        }
        if (lit <= 0.0) return;
        float g = haze_look.x;
        float hg = (1.0 - g * g) / (12.566 * pow(max(1.0 + g * g - 2.0 * g * mu, 1e-4), 1.5));
        float phase = (1.0 - haze_look.y) * hg + haze_look.y / 12.566;
        float metres = lit * length(at.xyz) / shell.w;
        result = vec4(haze_light.rgb * (haze_light.w * phase * metres), 1.0);
    }
    """;
// The haze's light at half size (HAZE_FRAG) added bilinear over the picture.
let HAZE_ADD_FRAG = """
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D haze_image;
    layout(set = 3, binding = 0) uniform HazeAdd { vec4 haze_add; };
    void main() { result = vec4(texture(haze_image, gl_FragCoord.xy * haze_add.xy).rgb, 1.0); }
    """;
