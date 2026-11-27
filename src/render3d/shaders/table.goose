namespace shaders;

// The games table and its chairs.

// TABLE_FRAG in the room with its light baked: the room's probes round the table in place
// of the look's harmonics (render3d::table_in_room); the game's table never carries it.
let TABLE_ROOM = "#define TABLE_ROOM 1\n";
// TABLE_VERT and TABLE_FRAG in the room lit from the room's probe grid where each pixel is,
// through the props' baked occlusion (render3d::props_light, task 120), in place of the four
// samples on the table's axis; the probes' light as nine harmonics (the props' atlas). With
// TABLE_ROOM, in both stages; the desktop's tiers only (render3d_gpu::make_room_tier).
let PROPS_LIGHT = "#define PROPS_LIGHT 1\n";

let TABLE_SHELL = """
    #ifdef NO_SSAO
    layout(set = 2, binding = 9) uniform sampler2D lace_mask;
    #else
    layout(set = 2, binding = 10) uniform sampler2D lace_mask;
    #endif
    layout(set = 3, binding = 2) uniform Shell { vec4 axes; vec4 tile; vec4 shell; vec4 shell_mids; vec4 shell_niche;
                                                 vec4 shell_glass; vec4 shell_sun; vec4 window_view; };
    #ifdef PROPS_LIGHT
    // The room's baked light (model3d::room_light) for the props: its probes' light as nine
    // harmonics, in room_light::PROPS_BLOCKS blocks laid out as ROOM_FRAG's atlas's colours.
    #ifdef NO_SSAO
    layout(set = 2, binding = 10) uniform sampler2D props_probes;
    #else
    layout(set = 2, binding = 11) uniform sampler2D props_probes;
    #endif
    // render3d::PropsLightBlock: the probes' grid as ROOM_HEAD's light_box and light_grid;
    // props_look x 1 where the table keeps its own shade terms beside the bake, y how far
    // past its terminator the sun's light wraps, z 1 where the table's profile's occlusion
    // gives way to the bake's.
    layout(set = 3, binding = 3) uniform PropsLight { vec4 light_box; vec4 light_grid; vec4 props_look; };
    #endif
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
    #ifdef PROPS_LIGHT
    // The props' baked occlusion (render3d::props_open): each vertex's open direction and
    // open part (model3d::prop_occlusion).
    layout(std430, set = 0, binding = 0) readonly buffer PropsOpen { vec4 props_open[]; };
    layout(location = 5) out vec4 v_open;
    #endif
    void main() {
        vec3 pos = a_pos;
        v_world = pos;
        v_normal = a_normal;
        v_uv = a_uv;
        v_ao = a_extra.x;
        v_mat = a_extra.y;
    #ifdef PROPS_LIGHT
        v_open = props_open[gl_VertexIndex];
    #endif
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
    #ifdef PROPS_LIGHT
    layout(location = 5) in vec4 v_open;
    #endif
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
    // The chairs' tapestry (render3d::put_tapestry, tools/materials/tapestry.py): its tile's
    // albedo at a 2.2 gamma.
    layout(set = 2, binding = 8) uniform sampler2D tapestry_map;
    #ifndef NO_SSAO
    // The room's ambient occlusion at half size (SSAO_FN).
    layout(set = 2, binding = 9) uniform sampler2D ssao_map;
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
    // (SSAO_FN); base_wood and base_look how the base reads its wood (render3d::base_wood); wood
    // the table's and chairs' finish (render3d::Wood, the light tuner's --woods).
    layout(set = 3, binding = 1) uniform Table { vec4 pool; vec4 coat; vec4 polish; vec4 worn; vec4 shape; vec4 table_map[4];
                                                 vec4 room_light[12]; vec4 room_mix; vec4 room_shade; vec4 ssao; vec4 base_wood; vec4 base_look;
                                                 vec4 wood_finish[5]; };
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
    // The chairs' tapestry's tile, 240 mm (world units), and their braid's colour.
    const float TAPESTRY_TILE = 7.3152;
    const vec3 BRAID = vec3(0.38, 0.29, 0.15);
    const float CHAIR_WOOD = 0.6;
    const float CHAIR_CLOTH = 0.8;   // the tapestry a little darker in the room than its swatch

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
    // `in_room` takes the room's at every height: the chairs, whose backs rise past the top.
    vec3 room_light_at(float y, vec3 n, vec3 harmonics, bool in_room) {
        float k = clamp(((y - shape.y) / room_shade.w - 0.15) / 0.3, 0.0, 3.0);
        int i = int(min(floor(k), 2.0));
        float f = k - float(i);
        vec3 a = vec3(room_light[3 * i].x + dot(room_light[3 * i].yzw, n), room_light[3 * i + 1].x + dot(room_light[3 * i + 1].yzw, n),
                      room_light[3 * i + 2].x + dot(room_light[3 * i + 2].yzw, n));
        int j = i + 1;
        vec3 b = vec3(room_light[3 * j].x + dot(room_light[3 * j].yzw, n), room_light[3 * j + 1].x + dot(room_light[3 * j + 1].yzw, n),
                      room_light[3 * j + 2].x + dot(room_light[3 * j + 2].yzw, n));
        float over = in_room ? 0.0 : smoothstep(TABLE_TOP - 0.5, TABLE_TOP, y);
        return (max(mix(a, b, f), vec3(0.0)) + harmonics * room_mix.y + room_shade.rgb) * mix(room_mix.z, 1.0, over);
    }
    #ifdef PROPS_LIGHT
    // One probe's texel of the props' atlas: block t, the height's slice k, at g (the grid's
    // x and along v), the slices k0 and k1 mixed by kf.
    vec4 grid_probe(float t, float k0, float k1, float kf, vec2 g) {
        vec2 size = vec2(light_grid.x * light_grid.z, 7.0 * light_grid.y);
        vec2 at = vec2(g.x + 0.5, t * light_grid.y + g.y + 0.5);
        return mix(textureLod(props_probes, (at + vec2(k0 * light_grid.x, 0.0)) / size, 0.0),
                   textureLod(props_probes, (at + vec2(k1 * light_grid.x, 0.0)) / size, 0.0), kf);
    }
    // The room's baked light at q toward d (both the world's), over pi, as ROOM_FRAG's
    // baked_light but with the second band: q turned into the room's frame, the probes half a
    // step out along d. The nine harmonics' rgb one after another in seven texels: the
    // constant, the direction's x, y, z, then (nx² - nz²), (ny² - nz²), nx ny, nx nz, ny nz.
    vec3 grid_light(vec3 q, vec3 d) {
        vec3 lq = vec3(dot(q.xz, axes.xy), q.y, dot(q.xz, axes.zw));
        vec3 ld = vec3(dot(d.xz, axes.xy), d.y, dot(d.xz, axes.zw));
        vec3 hi = vec3(light_grid.x, light_grid.z, light_grid.y) - 1.0;
        vec3 g = clamp((lq + ld * (0.5 * light_box.w) - light_box.xyz) / light_box.w, vec3(0.0), hi);
        float k0 = floor(g.y);
        float k1 = min(k0 + 1.0, hi.y);
        float kf = g.y - k0;
        vec4 t0 = grid_probe(0.0, k0, k1, kf, g.xz);
        vec4 t1 = grid_probe(1.0, k0, k1, kf, g.xz);
        vec4 t2 = grid_probe(2.0, k0, k1, kf, g.xz);
        vec4 t3 = grid_probe(3.0, k0, k1, kf, g.xz);
        vec4 t4 = grid_probe(4.0, k0, k1, kf, g.xz);
        vec4 t5 = grid_probe(5.0, k0, k1, kf, g.xz);
        vec4 t6 = grid_probe(6.0, k0, k1, kf, g.xz);
        vec3 e = t0.xyz + vec3(t0.w, t1.xy) * ld.x + vec3(t1.zw, t2.x) * ld.y + t2.yzw * ld.z
               + t3.xyz * (ld.x * ld.x - ld.z * ld.z) + vec3(t3.w, t4.xy) * (ld.y * ld.y - ld.z * ld.z)
               + vec3(t4.zw, t5.x) * (ld.x * ld.y) + t5.yzw * (ld.x * ld.z) + t6.xyz * (ld.y * ld.z);
        return max(e, vec3(0.0));
    }
    // room_light_at with the grid at q (world) in place of the samples on the table's axis.
    vec3 props_light_at(vec3 q, vec3 d, vec3 harmonics, bool in_room) {
        float over = in_room ? 0.0 : smoothstep(TABLE_TOP - 0.5, TABLE_TOP, q.y);
        return (grid_light(q, d) + harmonics * room_mix.y + room_shade.rgb) * mix(room_mix.z, 1.0, over);
    }
    #endif
    #endif

    vec3 tonemap(vec3 c) {
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
        vec2 a_bound = off * disc_n.z;
        vec2 b_bound = off * disc_n.w;
        vec2 lo = disc_bounds.xy + min(a_bound, b_bound);
        vec2 hi = disc_bounds.zw + max(a_bound, b_bound);
        if (p.x < lo.x || p.y < lo.y || p.x > hi.x || p.y > hi.y) return vec2(1.0);
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
    vec4 board_seen(vec3 p, vec3 d, vec3 l, float foot) {
        vec2 b = vec2(INNER + FRAME_W);
        float across = length(d.xz);
        if (across < 1e-4) return vec4(0.0);
        // The ray gains d.y * t in height and can close at most across * t
        // of the distance to the board. The blur grows by 0.06 * t.
        // Leave another 0.01 world units around both limits for rounding.
        if (d.y > 0.06 && (foot - 0.03) * (d.y - 0.06) >
            (FRAME_TOP + 0.03 - p.y) * (across + 0.06)) return vec4(0.0);
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

    // A wood stained by its luminance (render3d::Wood, as ROOM_FRAG's wood_stained).
    vec3 wood_stained(vec3 a, vec4 w0, vec4 w1, vec4 w2) {
        float t = clamp((dot(a, vec3(0.2126, 0.7152, 0.0722)) - w0.w) / max(w1.w - w0.w, 1e-4), 0.0, 1.0);
        return t < 0.5 ? mix(w0.rgb, w1.rgb, 2.0 * t) : mix(w1.rgb, w2.rgb, 2.0 * t - 1.0);
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
        // The chairs (mesh::MAT_CHAIR, MAT_SEAT, MAT_TRIM): their wood as the base's, their
        // seats and backs tapestry, a braid where it meets the wood.
        bool chair = v_mat > 4.5;
        bool seat = v_mat > 5.5;
        // On the top's height: the board's foot and shadow there. Not the chairs, whose
        // backs rise past it.
        bool at_top = p.y > TABLE_TOP - 0.01 && !chair;
        bool top = v_normal.y > 0.999 && at_top && !base;
        vec2 out_dir = p.xz - vec2(0.0, TABLE_Z);
        float from_mid = max(length(out_dir), 1e-3);
        vec2 uv = top ? out_dir / (2.0 * TABLE_MAP_R) + 0.5
                      : vec2(0.3 + (v_uv.y - TABLE_MAP_R) / (2.0 * TABLE_MAP_R), v_uv.x / (2.0 * PI * from_mid) * 3.0);
    #ifdef TABLE_ROOM
        if (top) uv = vec2(shape.w * out_dir.x + shape.z * out_dir.y, shape.w * out_dir.y - shape.z * out_dir.x) / (2.0 * TABLE_MAP_R) + 0.5;
    #endif
        if (base) uv = vec2(0.2, 0.15) + v_uv / (2.0 * TABLE_MAP_R);
        // The base's own wood (render3d::base_wood x 1): a turned column and bent legs are
        // cut from straight blanks, so the grain runs along the column's axis and along each
        // leg, the map's figure drawn out along it base_wood.w times, with no rings round the
        // beads. The column's u is its angle round from its side, at 80 mm out, mirrored as
        // the mesh's (the map doesn't meet itself across), with base_look.x degrees of slant
        // and base_look.y of how far out the cut is (the rings it crosses on the urn); the
        // column is what stands over the drum's top (212 mm) or inside it (72 mm), the legs
        // coming out of it below 240 mm. Each leg (mesh::table_base, toward the board's
        // corners) reads its own part of the map.
        float up_mm = (p.y - shape.y) / room_shade.w * 1000.0;
        float out_mm = from_mid / room_shade.w * 1000.0;
        bool column = base && !chair && (up_mm > 240.0 || out_mm < 72.5 || (up_mm > 212.0 && out_mm < 83.5));
        bool own_base = base && !chair && base_wood.x > 0.5;
        if (own_base) {
            vec2 q = vec2(shape.w * out_dir.x + shape.z * out_dir.y, shape.w * out_dir.y - shape.z * out_dir.x);
            float r0 = 0.08 * room_shade.w;
            float along = column ? p.y - shape.y : v_uv.y;
            float across = column ? abs(atan(q.y, q.x)) * r0 + base_look.y * (from_mid - r0)
                                    + tan(radians(base_look.x)) * along
                                  : v_uv.x + 2.3 * floor(atan(q.y, q.x) / (0.5 * PI));
            uv = vec2(base_look.z + across / (2.0 * TABLE_MAP_R), 0.15 + along / (2.0 * TABLE_MAP_R * base_wood.w));
        }
        // A picture of its own (render3d::Wood's way 2): the map's places at its size.
        if (wood_finish[2].w > 1.5) uv *= 2.0 * TABLE_MAP_R / wood_finish[4].x;
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
        // Its colour: the lightness the map's mean times base_wood.y, the figure round it
        // base_wood.z of the map's, the colour's strength base_look.w of the map's.
        // With the wood's own finish (render3d::Wood) one wood for the top, the base and the
        // chairs, stained as the docx says.
        bool finished = wood_finish[2].w > 0.5;
        if (finished) albedo = wood_stained(albedo, wood_finish[0], wood_finish[1], wood_finish[2]);
        if (own_base && !finished) {
            float mean = dot(textureLod(table_albedo, vec2(0.5), 20.0).rgb, vec3(0.2126, 0.7152, 0.0722));
            float l = max(dot(albedo, vec3(0.2126, 0.7152, 0.0722)), 1e-4);
            albedo = mix(vec3(l), albedo, base_look.w) * (mean * base_wood.y + (l - mean) * base_wood.z) / l;
        }
        float ao = clamp(v_ao, 0.0, 1.0);
    #ifdef PROPS_LIGHT
        // The bake's open part: the chairs' in place of their own shade (mesh::chairs'), the
        // table's beside its profile's, or in place of it with props_look.z.
        float open_part = clamp(v_open.w, 0.0, 1.0);
        ao = chair || props_look.z > 0.5 ? open_part : ao * open_part;
    #endif
    #ifdef TABLE_ROOM
        // The chairs' wood is the base's, darker and less red: the top beside it, under its
        // polish, reads browner, and the same wood read lighter and redder on the chairs.
        if (chair && !seat && !finished) albedo = mix(vec3(dot(albedo, vec3(0.2126, 0.7152, 0.0722))), albedo, 0.75) * CHAIR_WOOD;
        // The cloth's tile by its uv (the pads' unrolled millimetres, mesh::cushion), its
        // derivatives taken before the branch. Matte; the braid a twisted cord, its strands
        // slanting along it every 3 mm.
        vec2 tq = v_uv / TAPESTRY_TILE;
        vec2 tgx = dFdx(tq);
        vec2 tgy = dFdy(tq);
        if (seat) {
            albedo = CHAIR_CLOTH * pow(textureGrad(tapestry_map, tq, tgx, tgy).rgb, vec3(2.2));
            rough = 0.9;
            if (v_mat > 6.5) {
                float twist = 0.5 + 0.5 * sin(68.7 * (v_uv.x + v_uv.y));
                albedo = BRAID * (0.7 + 0.3 * twist);
                rough = 0.8;
            }
        }
    #endif

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
        float on_table = at_top ? 1.0 : 0.0;
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
    #ifdef PROPS_LIGHT
            // With the bake, only where props_look.x keeps it; the base's sky likewise.
            if (props_look.x > 0.5)
    #endif
            ao *= mix(1.0 - pool.z, 1.0, smoothstep(TABLE_TOP - 0.6, TABLE_TOP, p.y));
        } else if (!chair) {
            // The base sees the sky round the top: the share of it the top hides, the
            // cone up to its rim, more for what faces up.
            float e = (TABLE_TOP - p.y) / max(shape.x - from_mid, 0.5);
            float hidden_sky = 1.0 / (1.0 + e * e);
    #ifdef PROPS_LIGHT
            if (props_look.x > 0.5)
    #endif
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
    #ifdef PROPS_LIGHT
        float wrap = props_look.y;
    #else
        float wrap = 0.2;
    #endif
        float diff = clamp((nol + wrap) / (1.0 + wrap), 0.0, 1.0) / (1.0 + wrap);
        // The light's pool round the board.
        float d = length(p.xz) / max(pool.x, 1e-3);
        float lit = chair ? 1.0 : mix(pool.y, 1.0, exp(-d * d));
        vec3 light = light_color.rgb * light_dir.w * lit;
        float vis = 1.0;
        float hidden = 1.0;
        if (at_top) {
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
    #ifdef PROPS_LIGHT
        // The grid where the pixel is, seen through the bake's open direction, turned as far
        // as the pixel's normal turns from the mesh's (the top's map).
        vec3 vn0 = normalize(v_normal);
        float bent_len = length(v_open.xyz);
        vec3 bent = bent_len > 1e-4 ? v_open.xyz / bent_len : vn0;
        vec3 open_dir = normalize(bent + n - vn0);
        irr = props_light_at(p, open_dir, sh_eval(open_dir) * params.z, chair);
    #else
        irr = room_light_at(p.y, n, sh_eval(n) * params.z, chair);
    #endif
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
        float strength = seat ? 0.0 : coat.y * clamp(1.0 - 2.0 * polish.y * blot, 0.0, 2.0) * (1.0 - 0.6 * polish.w * rim);
        // The wood's own finish: the polish the docx's coat, at its weight and roughness, worn
        // as the polish is, the wood matt under it (scene.py's finished_wood, the base's
        // specular 0).
        finished = finished && !seat;
        float worn_rough = rough - a.a;
        if (finished) {
            cr = (top ? wood_finish[3].w + worn_rough + 0.3 * polish.w * scratch : wood_finish[3].w + 0.25 * polish.w * rim) * (1.0 + 2.0 * polish.x * blot);
            strength = wood_finish[3].z * clamp(1.0 - 2.0 * polish.y * blot, 0.0, 2.0) * (1.0 - 0.6 * polish.w * rim);
        }
        float ar = cr * cr;
        ar = sqrt(clamp(ar * ar + min(2.0 * variance + 0.3 * top_var, 0.3), 0.0, 1.0));
        ar = max(ar, 0.0079);
        vec3 f0 = vec3(0.04);
    #ifdef PROPS_LIGHT
        // The sun's disc, 0.53 degrees across, widens the polish's lobe by half its angular
        // radius (Karis's widening for a disc light).
        float ak = ar + 0.0023;
    #else
        // The key light is a window, not a point: its highlight in the polish is as broad
        // as coat.w's roughness, not the sun's pinpoint.
        float ak = max(ar, coat.w * coat.w);
    #endif
        vec3 spec = d_ggx(noh, ak) * v_smith(nov, nl, ak) * f_schlick(f0, voh) * nl * light * spec_vis;
    #ifdef PROPS_LIGHT
        // The polish reflects its Fresnel share of the sun before it reaches the wood, as a
        // clear coat does: a quarter of a low sun on the top.
        wood -= albedo * (diff / PI * light * vis) * strength * f_schlick(f0, nl);
    #endif
        vec3 r = reflect(-v, nc);
        vec3 env = sh_eval(r) * params.z * mix(1.0, lit, 0.5);
    #ifdef TABLE_ROOM
    #ifdef PROPS_LIGHT
        // The polish sees the light arriving from r's side, as the probes hold it: the room's
        // surfaces' light and the windows', no albedo on it again.
        env = props_light_at(p, r, sh_eval(r) * params.z, chair);
    #else
        // In the room the polish sees the room's surfaces: the light on them toward r by
        // their mean albedo (0.2), as ROOM_FRAG's rough reflections take it.
        env = 0.2 * room_light_at(p.y, r, sh_eval(r) * params.z, chair);
    #endif
    #endif
        // Near the board the polish shows the board's side in place of the room.
        if (top && r.y > 0.0) {
            vec4 side = board_seen(p, r, l, foot);
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
        // Into the scenic views' HDR target: the light with tonemap's toe alone taken off,
        // none where Frame's toe.y says 2 (the camera's curve takes it).
        float least = min(color.r, min(color.g, color.b));
        if (toe.y < 1.5) color -= least < 0.04 ? least - 12.5 * least * least : 0.02;
        result = vec4(color, 1.0);
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

let CHEAP_TABLE = "#define CHEAP_TABLE 1\n";
