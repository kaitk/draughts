namespace shaders;

// The view out of the library's windows: the sky, the park's band, and the oak.

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

// The light tuner's park on the ground (PARK_FN) and its parts off one at a time.
let PARK = "#define PARK 1\n";
let PARK_NO_SHADING = "#define PARK 1\n#define PARK_NO_SHADING 1\n";
let PARK_NO_LEAVES = "#define PARK 1\n#define PARK_NO_LEAVES 1\n";
let PARK_NO_GROUNDING = "#define PARK 1\n#define PARK_NO_GROUNDING 1\n";
let PARK_NO_SHADOWS = "#define PARK 1\n#define PARK_NO_SHADOWS 1\n";
