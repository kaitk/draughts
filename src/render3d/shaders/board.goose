namespace shaders;

// The board and the pieces: one lit shader for both, the crowns, the occlusion and shadow
// catchers under them, and the marks on the fields.

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
                                                 vec4 shell_glass; vec4 shell_sun; vec4 window_view;
                                                 vec4 shell_case; };
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
        // Into the scenic views' HDR target: the light with tonemap's toe alone taken off,
        // none where Frame's toe.z says 2 (the camera's curve takes it).
        float least = min(color.r, min(color.g, color.b));
        if (toe.z < 1.5) color -= least < 0.04 ? least - 12.5 * least * least : 0.02;
        result = vec4(color, v_alpha);
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
