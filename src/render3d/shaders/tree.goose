namespace shaders;

// The maple outside: its wood, leaves, ribbons and cards, and their light.

// The tree outside drawn as geometry (task 107's T2, model3d's tree_mesh.goose), after the
// room's opaque groups and before its glass, with the depth test, so only what shows through
// the windows pays. Its own pipelines by these defines, nothing in the room's shaders:
// TREE_RIBBON the branchlets' and twigs' ribbons in place of the tubes, HDR_OUT the HDR
// target's.
let TREE_RIBBON = "#define TREE_RIBBON 1\n";
// The leaves cut by alpha-to-coverage where the pass has samples (TREE_LEAF_FRAG), gfx's alone.
let TREE_COVERAGE = "#define TREE_COVERAGE 1\n";
// The wind on the tree (TREE_FN's tree_moved, WIND_FN): the shadow's field on the
// geometry, in the standard tier and the high; TREE_FLUTTER each leaf turning about its
// stalk too, the high tier's alone (render3d::tree_wind).
let TREE_WIND = "#define TREE_WIND 1\n";
let TREE_FLUTTER = "#define TREE_WIND 1\n#define TREE_FLUTTER 1\n";

// The tree's block (render3d::TreeBlock), in both stages after FRAME: tree_origin xyz the
// tree's frame's origin in the room's (rooms::tree_origin), w the pass's samples; tree_light
// x the sun's light on a white surface facing it against the sky's, y the sky's, z how much
// of the sun a leaf lets through against its back colour, w the forward lobe's share;
// tree_look x the view out's exposure, y the power the crown's shade is taken to (1 as
// baked), z each leaf's own tint's spread, w the twigs' least width in pixels; tree_depth
// x the depth (0..1) past which the far crown is squeezed in, y how much (the far plane
// stays past it), z how far a leaf turns about its stalk in the room's mild wind (radians,
// TREE_FLUTTER), w how fast (radians a second of the wind); tree_tint x the leaves' tint
// added, y their colour's strength, z the bark's, w how much deeper the sun turns behind
// other leaves; tree_layers xy the key's slant onto the shadow's map (trees::View.shear),
// zw the depths between its near and middle and its middle and far layers (trees::depths).
let TREE_HEAD = """
    layout(set = FRAME_SET, binding = 1) uniform Tree {
        vec4 tree_origin;
        vec4 tree_light;
        vec4 tree_look;
        vec4 tree_depth;
        vec4 tree_tint;
        vec4 tree_layers;
    };
    """;

// The tree's vertex stages' helpers: its frame into the world (the room's frame mirrored in
// depth, then turned as ROOM_VERT turns the room), and its clip position with the crown past
// the far plane squeezed in front of it, which leaves its order and the room's depths as
// they are.
let TREE_FN = """
    vec3 tree_turned(vec3 a) {
        vec2 xz = room_axes.xy * a.x + room_axes.zw * a.z;
        return vec3(xz.x, a.y, xz.y);
    }
    vec3 tree_world(vec3 p) { return tree_turned(vec3(p.x - tree_origin.x, p.y - tree_origin.y, tree_origin.z - p.z)); }
    vec3 tree_way(vec3 d) { return tree_turned(vec3(d.x, d.y, -d.z)); }
    #ifdef TREE_WIND
    // How far the shadow's lookup at m (a point of the map, LIGHT_FN's tree_light) moves
    // `layer` of the map (0 the limbs, 1 the near leaves, 2 the middle, 3 the far), in the
    // map's units: its whole shift and, with the branches, its region's sway.
    vec2 tree_lookup_shift(vec2 m, int layer) {
        if (tree.x <= 0.0) return vec2(0.0);
        float gust = wind_at(m).y;
        vec2 s = tree_shift[layer].xy + gust * tree_shift[layer].zw;
        if (wind_now.w > 1.5 && layer > 0) s += branch_sway(m, float(layer - 1), gust);
        return s * tree.xy;
    }
    // How far the wind moves a part of `layer` whose map point is m, in the map's plane: the
    // shadow at a point m' shows the map from m' plus the lookup's shift there, so the part
    // moves to where m' plus that shift is m. One step from m's own shift finds it to well
    // under a millimetre, as the field changes by less than 0.13 a unit.
    vec2 tree_layer_move(vec2 m, int layer) {
        vec2 d = -tree_lookup_shift(m, layer);
        return -tree_lookup_shift(m + d, layer);
    }
    // A point of the tree's frame on the map (trees::on_map).
    vec2 tree_on_map(vec3 p) { return p.xy - tree_layers.xy * p.z; }
    // The map's leaf layer of a point at depth z (trees::layer_of_depth).
    int tree_layer_of(float z) { return z < tree_layers.z ? 1 : (z > tree_layers.w ? 3 : 2); }
    #endif
    // Where the wind moves a point of the tree's frame that bends `flex` (0 the trunk's foot,
    // 1 a twig's tip), as its shadow moves (TREE_WIND; else it stands still): the limbs' shift
    // toward the leaf layers' at its depth by its flex, the layers blended over a band round
    // their bounds so no limb tears where the map's layers part.
    vec3 tree_moved(vec3 p, float flex) {
    #ifdef TREE_WIND
        vec2 m = tree_on_map(p);
        vec2 wood = tree_layer_move(m, 0);
        float band = max(tree_layers.w - tree_layers.z, 1.0) * 0.15;
        vec2 near = tree_layer_move(m, 1);
        vec2 middle = tree_layer_move(m, 2);
        vec2 far = tree_layer_move(m, 3);
        vec2 leafy = mix(mix(near, middle, smoothstep(tree_layers.z - band, tree_layers.z + band, p.z)), far,
                         smoothstep(tree_layers.w - band, tree_layers.w + band, p.z));
        vec2 d = mix(wood, leafy, smoothstep(0.2, 0.8, flex));
        return vec3(p.xy + d, p.z);
    #else
        return p;
    #endif
    }
    // Where the wind moves a leaf whose blade's middle is at `mid`: the whole card by its
    // layer's move at its middle's map point, exactly as its shadow on the map moves.
    vec3 tree_leaf_move(vec3 mid) {
    #ifdef TREE_WIND
        return vec3(tree_layer_move(tree_on_map(mid), tree_layer_of(mid.z)), 0.0);
    #else
        return vec3(0.0);
    #endif
    }
    vec4 tree_clip(vec3 pos) {
        vec4 c = view_proj * vec4(pos, 1.0);
        float z = c.z / c.w;
        c.z = min(z, tree_depth.x + (z - tree_depth.x) * tree_depth.y) * c.w;
        return c;
    }
    """;

// The tree's fragment stages' helpers, after TONE_FN: the sky's light on a surface facing n
// (its mean over the upper half of OUTSIDE_FRAG's sky, the lawn's below, linear), and the
// light out as the view out's (exposed, the toe taken off into the HDR target, or
// tonemapped and dithered).
let TREE_LIGHT_FN = """
    const vec3 TREE_SKY = vec3(0.526, 0.601, 0.716);
    const vec3 TREE_GROUND = vec3(0.17, 0.12, 0.02);
    vec3 tree_sky(vec3 n) { return mix(TREE_GROUND, TREE_SKY, 0.5 + 0.5 * n.y); }
    float tree_hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
    vec3 tree_encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    vec4 tree_out(vec3 c) {
        c *= tree_look.x;
    #ifdef TREE_CARD
        return vec4(c, 1.0);
    #else
    #ifdef HDR_OUT
        return vec4(room_toe(c), 1.0);
    #else
        c = tonemap(c) * vec3(1.02, 1.0, 0.97);
        float n = tree_hash(floor(gl_FragCoord.xy)) - 0.5;
        return vec4((tree_encode(c) + n / 255.0) * (1.0 - screen.z), 1.0);
    #endif
    #endif
    }
    """;

// The tree's card (task 107's T5, render3d::tree_card): the geometry drawn once, still, into
// an RGBA16F picture from one eye (render3d::TREE_CARD_EYE), its light exposed with no toe
// and premultiplied by its coverage (TREE_CARD in tree_out), multisampled and resolved; then
// one quad at the crown's middle depth drawn in the view out's place in the pass, for the
// floor's mirror and a phone's view. CARD_VERT puts the quad's corners (render3d's
// TreeCardBlock, the room's frame turned as now) an eighth of the way from the eye, as the
// view out's band and oak, so it lands where it is and the room hides it. CARD_FRAG gives
// its light out as OUTSIDE_MAIN gives the view out's: in the mirror the light itself, in HDR
// with the toe taken off, else tonemapped and dithered.
let TREE_CARD = "#define TREE_CARD 1\n";
let CARD_VERT = """
    layout(set = 1, binding = 1) uniform TreeCard { vec4 card_corners[4]; };
    layout(location = 0) out vec2 v_uv;
    const int CARD_CORNER[6] = int[6](0, 1, 2, 0, 2, 3);
    const vec2 CARD_UV[4] = vec2[4](vec2(0.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0), vec2(0.0, 1.0));
    void main() {
        int k = CARD_CORNER[gl_VertexIndex];
        vec3 w = card_corners[k].xyz;
        v_uv = CARD_UV[k];
        vec3 pos = eye.xyz + (w - eye.xyz) * 0.125;
        gl_Position = view_proj * vec4(pos, 1.0);
    }
    """;
let CARD_FRAG = """
    layout(set = 2, binding = 0) uniform sampler2D tree_card;
    layout(set = 3, binding = 1) uniform Outside { vec4 exposure; vec4 sun_disc; vec4 sun_glare; vec4 sun_tree; };
    layout(location = 0) in vec2 v_uv;
    layout(location = 0) out vec4 result;
    vec3 card_encode(vec3 c) {
        c = clamp(c, 0.0, 1.0);
        return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
    }
    void main() {
        vec4 t = texture(tree_card, v_uv);
        vec3 c = t.rgb / max(t.a, 1e-4);
        if (exposure.z > 0.0) {
            result = vec4(mirror_light(c * exposure.z) * t.a, t.a);
            return;
        }
    #ifdef HDR_OUT
        result = vec4(room_toe(c) * t.a, t.a);
    #else
        c = tonemap(c) * vec3(1.02, 1.0, 0.97);
        float n = fract(sin(dot(floor(gl_FragCoord.xy), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
        result = vec4((card_encode(c) + n / 255.0) * t.a * (1.0 - screen.z), t.a);
    #endif
    }
    """;

// The wood: a tube's vertex as made, a ribbon's turned to face the eye and kept at least
// tree_look.w pixels wide, its coverage the share of that its true width is (Persson's
// phone-wire antialiasing), so a twig thinner than a pixel fades rather than breaks up. The
// ribbons blend by that coverage, drawn last with the depth test and writing none.
let TREE_WOOD_VERT = """
    layout(location = 0) in vec3 a_pos;
    layout(location = 1) in vec3 a_normal;
    layout(location = 2) in vec3 a_along;
    layout(location = 3) in vec2 a_uv;
    layout(location = 4) in vec4 a_light;
    layout(location = 0) out vec3 v_world;
    layout(location = 1) out vec3 v_normal;
    layout(location = 2) out vec3 v_along;
    layout(location = 3) out vec2 v_uv;
    layout(location = 4) out vec3 v_light;
    void main() {
        vec3 pos = tree_world(tree_moved(a_pos, a_light.w));
        vec3 along = tree_way(a_along);
        float cover = 1.0;
    #ifdef TREE_RIBBON
        vec3 side = normalize(cross(along, eye.xyz - pos));
        vec4 clip = view_proj * vec4(pos, 1.0);
        vec3 d = side * a_light.z;
        vec4 c2 = view_proj * vec4(pos + d, 1.0);
        float half_px = length((c2.xy / c2.w - clip.xy / clip.w) * 0.5 * screen.xy);
        float wide = max(half_px, 0.5 * tree_look.w);
        cover = half_px / wide;
        pos += side * (a_uv.x * a_light.z * wide / max(half_px, 1e-4));
        v_normal = side;
    #else
        v_normal = tree_way(a_normal);
    #endif
        v_world = pos;
        v_along = along;
        v_uv = a_uv;
        v_light = vec3(a_light.x, a_light.y, cover);
        gl_Position = tree_clip(pos);
    }
    """;

// The wood lit by the sky and the sun, each through the crown's shade at the vertex (the
// grid's, model3d's crown_light): dark against the light with a rim where the sun grazes it.
// A tube's bark from its tile (model3d's bark_tile: the normal across and along, light and
// dark, lichen); a ribbon round across its width, plain.
let TREE_WOOD_FRAG = """
    #ifndef TREE_RIBBON
    layout(set = 2, binding = 0) uniform sampler2D bark;
    #endif
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec3 v_along;
    layout(location = 3) in vec2 v_uv;
    layout(location = 4) in vec3 v_light;
    layout(location = 0) out vec4 result;
    const vec3 BARK = vec3(0.16, 0.14, 0.12);
    const vec3 LICHEN = vec3(0.2, 0.23, 0.15);
    void main() {
        vec3 l = normalize(light_dir.xyz);
        vec3 v = normalize(eye.xyz - v_world);
        float sun = pow(max(v_light.x, 1e-4), tree_look.y);
        float sky = pow(max(v_light.y, 1e-4), tree_look.y);
    #ifdef TREE_RIBBON
        float u = clamp(v_uv.x, -1.0, 1.0);
        vec3 n = normalize(normalize(v_normal) * u + v * sqrt(max(1.0 - u * u, 0.0)));
        vec3 albedo = BARK * 0.8 * tree_tint.z;
    #else
        vec4 b = texture(bark, v_uv);
        vec3 n0 = normalize(v_normal);
        vec3 t = normalize(v_along);
        vec3 round_way = cross(n0, t);
        vec3 n = normalize(n0 + round_way * (b.r * 2.0 - 1.0) + t * (b.g * 2.0 - 1.0));
        vec3 albedo = mix(BARK * b.b, LICHEN * (0.6 + 0.4 * b.b), b.a * 0.7) * tree_tint.z;
    #endif
        float ndl = dot(n, l);
        vec3 c = albedo * (tree_sky(n) * (sky * tree_light.y) + vec3(max(ndl, 0.0) * sun * tree_light.x));
        result = tree_out(c);
    #ifdef TREE_RIBBON
        result *= v_light.z;
    #endif
    }
    """;

// The leaves: each a card (trees::leaf_cards, LEAF_VEC4S vec4s an instance), two triangles
// over leaf_atlas::QUAD in the leaf's frame, its blade's base at the foot, y along its axis
// a blade length a unit, x across it the card's half width a unit; the atlas's texel from
// the cell's foot and SCALE (leaf_atlas). The wind moves the whole card as its shadow moves
// (tree_leaf_move); with TREE_FLUTTER it also turns about its stalk's axis, a few degrees,
// fast, each leaf on its own phase and rate, which the shadow doesn't follow (its middle
// stays where it was). Still air (the wind's seconds held at 0) turns nothing.
let TREE_LEAF_VERT = """
    layout(std430, set = 0, binding = 0) readonly buffer TreeCards { vec4 tree_cards[]; };
    layout(location = 0) out vec3 v_world;
    layout(location = 1) out vec3 v_normal;
    layout(location = 2) out vec2 v_uv;
    layout(location = 3) out vec4 v_leaf;
    const vec2 LEAF_CORNERS[6] = vec2[6](vec2(-1.0, 0.0), vec2(1.0, 0.0), vec2(1.0, 1.0),
                                         vec2(-1.0, 0.0), vec2(1.0, 1.0), vec2(-1.0, 1.0));
    void main() {
        int at = gl_InstanceIndex * 4;
        vec4 base = tree_cards[at];
        vec4 along = tree_cards[at + 1];
        vec4 face = tree_cards[at + 2];
        vec2 k = LEAF_CORNERS[gl_VertexIndex];
        float lx = k.x * 0.853;
        float ly = mix(-0.573, 1.133, k.y);
        vec3 n = face.xyz;
        vec3 across = cross(n, along.xyz);
        vec4 light = tree_cards[at + 3];
    #ifdef TREE_FLUTTER
        float seed = light.w;
        float rate = tree_depth.w * (0.8 + 0.4 * fract(seed * 7.13));
        float phase = seed * 6.2832;
        float t = wind.z * wind.y;
        float turn = tree_depth.z * clamp(wind.x / 0.06, 0.0, 2.0) * (sin(t * rate + phase) - sin(phase));
        float c = cos(turn);
        float s = sin(turn);
        vec3 turned_across = across * c + n * s;
        n = n * c - across * s;
        across = turned_across;
    #endif
        vec3 mid = base.xyz + along.xyz * (0.5 * base.w);
        vec3 p = base.xyz + across * (lx * along.w) + along.xyz * (ly * base.w) + tree_leaf_move(mid);
        vec3 pos = tree_world(p);
        int kind = int(face.w + 0.5);
        vec2 cell = vec2(float(kind % 4), float(kind / 4)) * 256.0;
        v_uv = (cell + vec2(128.0 + lx * 150.0, 170.0 - ly * 150.0)) / vec2(1024.0, 512.0);
        v_world = pos;
        v_normal = tree_way(n);
        v_leaf = light;
        gl_Position = tree_clip(pos);
    }
    """;

// A leaf's texel (leaf_atlas's two layers): its outline cut where it crosses a half, the
// edge sharpened to a pixel; with TREE_COVERAGE in a multisampled pass (gfx's, whose
// pipeline turns alpha-to-coverage on) that edge is the alpha the hardware turns into the
// samples covered, else the cut is dithered across it (ngfx, which has no
// alpha-to-coverage: docs/goose-findings.md, and a pass of one sample); its colour as
// leaf_atlas::texel_color makes it, from the front and through it. Lit from the front by
// the sky and the sun, or seen against the sun by the light through it: the back colour
// times the sun on its face, more toward the sun's own way (a Henyey-Greenstein lobe, g
// 0.3, its share tree_light.w), and the sun deeper and redder in the crown's shade.
let TREE_LEAF_FRAG = """
    layout(set = 2, binding = 0) uniform sampler2D leaf_shape;
    layout(set = 2, binding = 1) uniform sampler2D leaf_marks;
    layout(location = 0) in vec3 v_world;
    layout(location = 1) in vec3 v_normal;
    layout(location = 2) in vec2 v_uv;
    layout(location = 3) in vec4 v_leaf;
    layout(location = 0) out vec4 result;
    const vec3 STALK = vec3(0.2, 0.035, 0.015);
    const vec3 TAR = vec3(0.012, 0.01, 0.008);
    vec3 leaf_tint_color(float t) {
        vec3 green = vec3(0.045, 0.11, 0.012);
        vec3 lime = vec3(0.3, 0.33, 0.02);
        vec3 gold = vec3(0.62, 0.34, 0.01);
        vec3 orange = vec3(0.6, 0.14, 0.008);
        vec3 red = vec3(0.42, 0.045, 0.006);
        if (t < 0.7) { return mix(green, lime, t / 0.7); }
        if (t < 1.0) { return mix(lime, gold, (t - 0.7) / 0.3); }
        if (t < 1.5) { return mix(gold, orange, (t - 1.0) / 0.5); }
        return mix(orange, red, clamp((t - 1.5) / 0.5, 0.0, 1.0));
    }
    void main() {
        vec4 s = texture(leaf_shape, v_uv);
        float a = (s.a - 0.5) / max(fwidth(s.a), 1e-4) + 0.5;
    #ifdef TREE_COVERAGE
        bool cover = tree_origin.w > 1.5;
        if (cover ? a <= 0.0 : a < tree_hash(floor(gl_FragCoord.xy)) * 0.98 + 0.01) { discard; }
    #else
        if (a < tree_hash(floor(gl_FragCoord.xy)) * 0.98 + 0.01) { discard; }
    #endif
        vec4 m = texture(leaf_marks, v_uv);
        float tint = clamp(v_leaf.x + tree_tint.x + (v_leaf.w - 0.5) * tree_look.z, 0.0, 2.0);
        float t = clamp(tint + (s.g - 0.5) * 0.7 - m.a * 0.6, 0.0, 2.0);
        vec3 c0 = leaf_tint_color(t) * s.r;
        float grey = dot(c0, vec3(0.2126, 0.7152, 0.0722));
        c0 = mix(vec3(grey), c0, tree_tint.y);
        vec3 front = mix(c0, c0 * 1.25 + vec3(0.03, 0.03, 0.01), s.b * 0.6);
        front = mix(mix(front, STALK, m.b), TAR, m.g);
        vec3 back = pow(c0, vec3(1.35)) * 2.4 * (1.0 - 0.55 * m.r);
        back = mix(mix(back, STALK * 0.25, m.b), TAR, m.g);
        vec3 l = normalize(light_dir.xyz);
        vec3 v = normalize(eye.xyz - v_world);
        vec3 n = normalize(v_normal);
        float nv = dot(n, v);
        vec3 nf = nv < 0.0 ? -n : n;
        float nl = dot(nf, l);
        float sun = pow(max(v_leaf.y, 1e-4), tree_look.y);
        float sky = pow(max(v_leaf.z, 1e-4), tree_look.y);
        vec3 sun_color = mix(vec3(1.0), vec3(1.0, 0.72, 0.42), (1.0 - sun) * tree_tint.w) * tree_light.x;
        vec3 c = front * tree_sky(nf) * (sky * tree_light.y);
        if (nl >= 0.0) {
            c += front * sun_color * (nl * sun);
        } else {
            float g = 0.3;
            float hg = (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * dot(-l, v), 1.5);
            c += back * sun_color * (-nl * sun * tree_light.z * mix(1.0, hg, tree_light.w));
        }
        result = tree_out(c);
    #ifdef TREE_COVERAGE
        if (cover) { result.a = clamp(a, 0.0, 1.0); }
    #endif
    }
    """;
