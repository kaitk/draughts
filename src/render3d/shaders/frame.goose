namespace shaders;

// The frame's block every 3D shader reads, the stages' sets, the full-screen and quad
// vertex shaders, the fade, and the output's defines.

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
        // their radius, zw their height range including the table. disc_bounds
        // covers their xz positions and the edges of their shadow and sky occlusion
        // before the light's sweep. Each disc stores xz, then foot and top heights.
        vec4 disc_n;
        vec4 disc_bounds;
        vec4 discs[48];
        // The room's frame (surfaces::Frame, render3d::put_room): u's direction in the
        // world's x and z, then v's; ROOM_VERT turns the room's mesh by it.
        vec4 room_axes;
        // The tonemaps' toes into the HDR target (HDR_OUT; render3d::tone_toe): x the room's
        // and the view out's way, y the table's, z the board's and the pieces' (0 on the
        // luminance, 1 on the least channel, Khronos PBR Neutral's, 2 none); w unused.
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

// A depth-only pass still needs a fragment shader.
let EMPTY_FRAG = """
    void main() { }
    """;

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
// The scenic views' HDR target (render3d::hdr_shown, the high tier's): the board, the
// pieces, the table, the room, the view out and the motes write their exposed light with
// only their tonemap's toe taken off (the room's on the luminance, the board's and the
// table's on the least channel; none where Frame's toe says 2, the light tuner's --light
// physical, HDR_TONE_FRAG's camera_curve taking the toe too), and HDR_TONE_FRAG takes it the
// rest of the way after the pass resolves.
let HDR_OUT = "#define HDR_OUT 1\n";
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
