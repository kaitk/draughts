namespace shaders;

// The room's shell and floor: its materials' pipelines, the window's light map, and the box
// map.

// The room round the table (model3d::surfaces): the floor, the panelling, the wallpaper,
// one mesh, its world position, normal, uv (the floor's u and v in the room, or a piece's
// place in the wall's field), occlusion and material. The room's mesh is built in its own
// frame (u, height, v; surfaces.goose) and turned into the world here.
// The box's map's bake (BOX_MAP_BAKE): a triangle over the map, the room's varyings
// written so ROOM_HEAD's inputs are met (ROOM_FRAG's bake reads gl_FragCoord alone).
let BOX_MAP_VERT = """
    layout(location = 0) out vec3 v_world;
    layout(location = 1) out vec3 v_normal;
    layout(location = 2) out vec2 v_uv;
    layout(location = 3) out vec2 v_extra;
    layout(location = 4) out vec3 v_local;
    layout(location = 5) out vec2 v_corner;
    layout(location = 6) flat out vec2 v_box;
    void main() {
        vec2 p = vec2((gl_VertexIndex << 1) & 2, gl_VertexIndex & 2);
        v_world = vec3(0.0); v_normal = vec3(0.0, 1.0, 0.0); v_uv = p; v_extra = vec2(0.0);
        v_local = vec3(0.0); v_corner = vec2(0.0); v_box = vec2(0.0);
        gl_Position = vec4(p * 2.0 - 1.0, 0.0, 1.0);
    }
    """;

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
// The window's light map in place of shell_open's work a pixel (render3d::window_map_on,
// LIGHT_FN's shell_open with WINDOW_MAP): the phone's tier's shaders, which light no leaves
// of their own (the map holds them, or none); WINDOW_MAP_LEAVES the others', which light the
// tree's leaves a pixel while they move. Not the lace's group, which reads the lace's mask.
let WINDOW_MAP = "#define WINDOW_MAP 1\n#define WINDOW_MAP_PLACE 1\n";
let WINDOW_MAP_LEAVES = "#define WINDOW_MAP 1\n#define WINDOW_MAP_PLACE 1\n#define WINDOW_MAP_LEAVES 1\n";
// The map's bake (render3d_gpu::window_map_pass): WINDOW_MAP_HEAD, LIGHT_FN with
// SHELL_WINDOWS (the pixel's shell_open's parts), WINDOW_MAP_FRAG.
let WINDOW_MAP_BAKE = "#define WINDOW_MAP_PLACE 1\n";
let WINDOW_MAP_HEAD = """
    layout(location = 0) out vec4 result;
    layout(set = 2, binding = 0) uniform sampler2D tree_map;
    layout(set = 2, binding = 1) uniform sampler2D lace_mask;
    layout(set = 3, binding = 1) uniform Shell { vec4 axes; vec4 tile; vec4 shell; vec4 shell_mids; vec4 shell_niche;
                                                 vec4 shell_glass; vec4 shell_sun; vec4 window_view; };
    // x: 1 the tree's light baked in (render3d::window_map_tree).
    layout(set = 3, binding = 2) uniform WindowMapBake { vec4 map_tree; };
    """;
let WINDOW_MAP_FRAG = """
    // The shell's windows' light at q0, a point of the inner face, for a point t0 past it
    // along the key (world units), as shell_open has it but for the niche's outline: x the
    // casements', y that through the lace, z the share the lace stops round its outline, for
    // what it scatters on (lace_shadow's y); summed over the windows.
    vec3 window_map_parts(vec3 q0, float t0, vec3 l, vec2 along, float toward, float metre, float widen) {
        vec3 sum = vec3(0.0);
        float tl = t0 - shell_glass.z / toward;
        float cone = window_view.y > 0.0 && tl > 0.5 ? LACE_CONE * tl / metre : 0.0;
        vec2 slope = vec2(dot(l.xz, along), l.y) * (panes.w / toward);
        for (int i = 0; i < 3; i++) {
            if (float(i) >= shell.x) break;
            float mid = shell_mids[i];
            float through = 1.0;
            for (int k = 0; k < 2; k++) {
                float depth = (k == 0 ? shell_glass.x : shell_glass.y) / toward;
                float tg = t0 + depth;
                if (tg <= 0.0) continue;
                vec3 g = q0 + l * depth;
                vec2 wg = vec2(dot(g.xz, along) - mid, g.y - shell.z) / metre;
                float soft_g = (0.03 + widen * tg) / metre;
                through *= casement(wg, soft_g, slope);
            }
            sum.x += through;
            if (tl > 0.5) {
                vec3 c = q0 - l * (shell_glass.z / toward);
                vec2 wl = vec2(dot(c.xz, along) - mid, c.y - shell.z) / metre;
                float soft_l = (0.03 + widen * tl) / metre + LACE_SOFT * tl / metre;
                vec2 lace = lace_shadow(wl, soft_l, cone > 0.0 ? soft_l + cone : 0.0);
                sum.y += through * lace.x;
                sum.z += lace.y;
            }
        }
        return sum;
    }

    // A texel of the map (shell_open with WINDOW_MAP reads it): r the light past the lace
    // as baked window_map_lace_t past the face, g the casements' at the face, b the tree's
    // at the face (1 none), a the share of the sun the lace stops round its outline (what it
    // scatters on, without the glazing's share), at r's distance.
    void main() {
        vec4 place = window_map_place();
        vec2 uv = gl_FragCoord.xy / WINDOW_MAP_SIZE;
        vec3 l = light_dir.xyz;
        vec2 nw = -axes.zw;
        vec2 along = axes.xy;
        float toward = dot(l.xz, nw);
        if (toward < 0.05) {
            result = vec4(0.0);
            return;
        }
        float metre = shell.w;
        float widen = shell_sun.x > 0.0 ? shell_sun.x : room.z;
        float u = place.x + uv.x * place.z;
        vec3 q0 = vec3(along.x * u + nw.x * shell.y, place.y + uv.y * place.w, along.y * u + nw.y * shell.y);
        float tr = window_map_lace_t(toward);
        float near = min(window_map_parts(q0, 0.0, l, along, toward, metre, widen).x, 1.0);
        vec3 far = window_map_parts(q0, tr, l, along, toward, metre, widen);
        float lit = min(far.y, 1.0);
        float scatter = min(far.z, 1.0);
        float leaves_lit = 1.0;
        if (map_tree.x > 0.5 && tree.x > 0.0) {
            vec2 at_face = tree_light(q0, l, nw, along, toward);
            leaves_lit = at_face.x * at_face.y;
        }
        result = vec4(lit, near, leaves_lit, scatter);
    }
    """;

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
    #ifdef WINDOW_MAP
    // The window's light map (render3d::window_map_pass) in the lace's place: these groups
    // read the lace only through shell_open, which the map holds.
    layout(set = 2, binding = 1) uniform sampler2D window_map;
    #else
    // The lace's coverage (design/materials/), R8 with its mips.
    layout(set = 2, binding = 1) uniform sampler2D lace_mask;
    #endif
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
    // The rug under the games table (render3d::put_rug): albedo at a 2.2 gamma, a 1.
    layout(set = 2, binding = 9) uniform sampler2D rug_map;
    #if defined(BOX_MAP) && defined(NO_SSAO)
    // The box's map (render3d::box_map), what the sharp reflection meets (room_seen).
    layout(set = 2, binding = 10) uniform sampler2D box_map;
    #endif
    #ifndef NO_SSAO
    layout(set = 2, binding = 10) uniform sampler2D ssao_map;
    layout(set = 2, binding = 11) uniform sampler2D pre_place;
    #endif
    #ifdef PLANAR_FLOOR
    // The room mirrored in the floor (render3d::planar_pass): its light in the room's units,
    // a the distance from the floor to what it shows along the reflection, with its mips.
    layout(set = 2, binding = 12) uniform sampler2D planar_map;
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
    // The stove's relief (room_shell::stove_relief): its slopes across and up, its height.
    layout(set = 2, binding = 6) uniform sampler2D stove_relief;
    #if defined(BOX_MAP) && defined(NO_SSAO)
    layout(set = 2, binding = 7) uniform sampler2D box_map;
    #endif
    #ifndef NO_SSAO
    layout(set = 2, binding = 7) uniform sampler2D ssao_map;
    layout(set = 2, binding = 8) uniform sampler2D pre_place;
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
    // wall's v, y the hall wall's, z the floor's field's size, w the wall's (world
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
    // ends: the end walls' u, x the stove's, y the far one's, z 1 where the window's light map holds the tree's light, w 1 with the rug (ROOM_FRAG's rug); brass: the curtains' (sRGB at
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
    // the quiet paint (surfaces::Look's); paint_steps: unused, kept so the block's layout
    // and room_fixed's constants stay; sill: the sills' limestone (surfaces::Look's);
    // sill_steps: unused as paint_steps; window_view: the window view's steps' strengths, 1 as made
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
    // The rug (tools/materials/rug.py's HALF and its picture's size, metres): its pile's half
    // length along the window wall and half width, the picture's size (the pile alone), its
    // middle this far into the room from the table's, and its thickness.
    const vec2 RUG_HALF = vec2(1.5, 1.0);
    const vec2 RUG_TEX = vec2(3.0, 2.0);
    const float RUG_IN = 0.1;
    const float RUG_THICK = 0.008;
    // The stove's glaze (room_shell's stove.goose and stove_relief.goose): the body's colour
    // under its clear coat and the lime grout's (sRGB), a tile (metres), a tile's tilt at most
    // (its tangent, 1.2°), how far in from a joint it rolls over, the coat's roughness, the
    // relief atlas's full-scale slope and its rows of the palmette.
    const vec3 STOVE_GLAZE = vec3(0.804, 0.835, 0.745);
    const vec3 STOVE_GROUT = vec3(0.659, 0.651, 0.596);
    const vec2 STOVE_TILE = vec2(0.22, 0.24);
    const float STOVE_TILT = 0.021;
    const float STOVE_ROLL = 0.010;
    const float STOVE_ROUGH = 0.08;
    const float STOVE_SLOPE = 1.5;
    const float STOVE_PALMETTE_ROWS = 176.0;
    // The table's base (mesh::table_base): its column's mean radius, and a leg's curve
    // from its root over the knee to the scroll's foot, out from the axis and up from the
    // floor (world units, mesh::LEG's and SCROLL_MID's), its half thickness.
    const float COLUMN_R = 2.6;
    const vec2 LEG0 = vec2(2.44, 5.36);
    const vec2 LEG1 = vec2(5.18, 4.45);
    const vec2 LEG2 = vec2(7.86, 2.13);
    const vec2 LEG3 = vec2(10.0, 0.7);
    const float LEG_HALF = 0.8;
    // The chairs at the table (mesh::CHAIRS): each seat's middle (x, z) and its turn's sine
    // and cosine; a foot's place from it across and forward (world units, chairs.goose's
    // legs' and back's feet), front and back, and the sphere at its foot that hides the sky.
    const vec4 CHAIR_A = vec4(0.0, -27.884, 0.104528, 0.994522);
    const vec4 CHAIR_B = vec4(1.829, 24.64, -0.241922, -0.970296);
    const vec2 CHAIR_FRONT_FOOT = vec2(6.767, 5.852);
    const vec2 CHAIR_BACK_FOOT = vec2(5.608, -7.010);

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
        vec2 size = vec2(textureSize(light_volume, 0));    // the probe volumes' rows after the grid's, if any
        return textureLod(light_volume, vec2(k * light_grid.x + g.x + 0.5, c * light_grid.y + g.y + 0.5) / size, 0.0);
    }

    // The room's baked light (model3d::room_light) at lp, in the room's frame, for the
    // normal n (the world's), over pi: the probes round lp, half a step out along n so a
    // wall reads the room's side of itself, the layers above and below mixed by hand, each
    // colour a constant and a direction.
    #ifndef PROBE_VOLUMES
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
    #else
    // With the probe volumes (model3d::room_light's Volume, render3d::volume_table): the atlas
    // has their rows after the grid's, so its size is its own. A block's probes at g (a block
    // at `at`: its first column and row, its probes across and along z), mixed between the
    // slices k0 and k1 by kf; the three colours' constant and direction, as baked_light's.
    vec3 block_light(vec4 at, vec3 g, float k0, float k1, float kf, vec3 ln) {
        vec2 size = vec2(textureSize(light_volume, 0));
        vec2 a = vec2(at.x + g.x + 0.5, at.y + g.z + 0.5);
        vec2 s0 = vec2(k0 * at.z, 0.0);
        vec2 s1 = vec2(k1 * at.z, 0.0);
        vec2 c1 = vec2(0.0, at.w);
        vec2 c2 = vec2(0.0, 2.0 * at.w);
        vec4 r = mix(textureLod(light_volume, (a + s0) / size, 0.0), textureLod(light_volume, (a + s1) / size, 0.0), kf);
        vec4 gr = mix(textureLod(light_volume, (a + s0 + c1) / size, 0.0), textureLod(light_volume, (a + s1 + c1) / size, 0.0), kf);
        vec4 b = mix(textureLod(light_volume, (a + s0 + c2) / size, 0.0), textureLod(light_volume, (a + s1 + c2) / size, 0.0), kf);
        return max(vec3(r.x + dot(r.yzw, ln), gr.x + dot(gr.yzw, ln), b.x + dot(b.yzw, ln)), vec3(0.0));
    }
    vec3 baked_light(vec3 lp, vec3 n) {
        vec3 ln = vec3(dot(n.xz, axes.xy), n.y, dot(n.xz, axes.zw));
        vec3 hi = vec3(light_grid.x, light_grid.z, light_grid.y) - 1.0;
        vec3 g = clamp((lp + ln * (0.5 * light_box.w) - light_box.xyz) / light_box.w, vec3(0.0), hi);
        float k0 = floor(g.y);
        vec3 baked = block_light(vec4(0.0, 0.0, light_grid.x, light_grid.y), g, k0, min(k0 + 1.0, hi.y), g.y - k0, ln);
        // Each volume whose box holds lp takes over from what is before it in the table by
        // how far in lp lies (its fade; a centimetre's slack for the table's half floats).
        int row = int(3.0 * light_grid.y);
        for (int v = 0; v < int(light_grid.w); v++) {
            vec4 low = texelFetch(light_volume, ivec2(3 * v, row), 0);
            vec4 extent = texelFetch(light_volume, ivec2(3 * v + 1, row), 0);
            vec3 q = lp - low.xyz;
            vec3 inside = min(q, extent.xyz - q);
            float d = min(inside.x, min(inside.y, inside.z));
            if (d < -0.3) continue;
            vec4 probes = texelFetch(light_volume, ivec2(3 * v + 2, row), 0);
            vec3 spacing = extent.xyz / probes.xyz;
            vec3 gv = clamp((q + ln * (0.5 * spacing)) / spacing - 0.5, vec3(0.0), probes.xyz - 1.0);
            float v0 = floor(gv.y);
            vec3 own = block_light(vec4(extent.w, probes.w, probes.x, probes.z), gv, v0, min(v0 + 1.0, probes.y - 1.0), gv.y - v0, ln);
            baked = mix(baked, own, low.w > 0.0 ? clamp(d / low.w, 0.0, 1.0) : 1.0);
        }
        return baked;
    }
    #endif

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

    #if defined(SHARP_BOX) || defined(BOX_MAP_BAKE)
    // The shell's box at h (the room's frame), a face whose inward normal in the room's frame
    // is nl: the surface there by where it is (the wainscot, the paper, the two doors' paint,
    // the bookcases, the plaster, the herringbone's mean). What room_seen meets, lit by
    // box_irradiance and box_sun.
    vec3 box_albedo(vec3 h, vec3 nl) {
        float up = (h.y - shell.z) / shell.w;
        vec3 wall = up < room_heights.z ? vec3(0.082, 0.046, 0.030) : mix(srgb(paper.rgb), srgb(gold.rgb), 0.3);
        if (nl.y != 0.0) return nl.y < 0.0 ? srgb(ceiling_light.rgb) : vec3(0.078, 0.045, 0.022);
        if (nl.x != 0.0) {
            bool door = nl.x < 0.0 && abs(h.z - room_doors.z) < room_doors.w && up < room_heights.y;
            return door ? srgb(paint.rgb) : wall;
        }
        bool door = nl.z < 0.0 && abs(h.x - room_doors.x) < room_doors.y && up < room_heights.y;
        bool cases = nl.z < 0.0 && abs(abs(h.x - room_doors.x) - book_cases.x) < book_cases.y && up < book_cases.z;
        return door ? srgb(paint.rgb) : (cases ? vec3(0.046, 0.029, 0.019) : wall);
    }
    // The world's normal of the box's face nl (the room's frame).
    vec3 box_normal(vec3 nl) { return vec3(axes.x * nl.x + axes.z * nl.z, nl.y, axes.y * nl.x + axes.w * nl.z); }
    // The room's baked light on the box at h for its face nl: smooth over the probes' spacing,
    // so the box's map holds it (BOX_MAP_BAKE).
    vec3 box_irradiance(vec3 h, vec3 nl) { return room_irradiance(h, box_normal(nl)); }
    // The sun through the windows on the box at hw (the world's) for its face nl: its patches'
    // edges as sharp as the window's light map's, so worked out where it is seen.
    vec3 box_sun(vec3 hw, vec3 nl) {
        vec3 n = box_normal(nl);
        vec3 l = light_dir.xyz;
        float nol = dot(n, l);
        if (nol <= 0.0) return vec3(0.0);
        return room_sun_color(room_sun.x) * light_dir.w * shell_sun.y * nol / PI * window_light(hw);
    }

    // The box's map (render3d::box_map, task 115): box_irradiance a texel each BOX_MAP_TEXEL
    // world units square, the floor and the ceiling in its first row of cells, the walls
    // across x (near, far), then across z (near, far) in the second, each cell on whole
    // texels. box_cell gives a face's cell: its first texel, its size in texels, and the
    // face's extent in world units; the bake and the reads share it.
    const float BOX_MAP_TEXEL = 1.2192;    // 4 cm
    void box_cell(vec3 nl, out vec2 at, out vec2 size, out vec2 extent) {
        vec3 e = vec3(room_box.y - room_box.x, room_heights.x - shell.z, room_box.w - room_box.z);
        // Half a texel more, so a face a whole number of texels long (the room is 9 by 7 by 4 m)
        // gives the same cells where its extent is folded as a constant and where it is not.
        vec3 c = ceil(e / BOX_MAP_TEXEL + 0.5);
        if (nl.y != 0.0) {
            at = vec2(nl.y < 0.0 ? c.x : 0.0, 0.0); size = c.xz; extent = e.xz;
        } else if (nl.x != 0.0) {
            at = vec2(nl.x < 0.0 ? c.z : 0.0, c.z); size = c.zy; extent = e.zy;
        } else {
            at = vec2(2.0 * c.z + (nl.z < 0.0 ? c.x : 0.0), c.z); size = c.xy; extent = e.xy;
        }
    }
    // h's place on its face, world units from the cell's corner.
    vec2 box_face_place(vec3 h, vec3 nl) {
        vec3 d = vec3(h.x - room_box.x, h.y - shell.z, h.z - room_box.z);
        return nl.y != 0.0 ? d.xz : (nl.x != 0.0 ? d.zy : d.xy);
    }
    #endif

    #ifdef SHARP_BOX
    #ifdef BOX_MAP
    // box_irradiance at h from the box's map: one tap, held half a texel inside the face's cell.
    vec3 box_map_at(vec3 h, vec3 nl) {
        vec2 at, size, extent;
        box_cell(nl, at, size, extent);
        vec2 q = at + clamp(box_face_place(h, nl) / BOX_MAP_TEXEL, vec2(0.5), size - 0.5);
        return textureLod(box_map, q / vec2(textureSize(box_map, 0)), 0.0).rgb;
    }
    #endif

    // The room's radiance seen along r from p (the world's; lp and lr the room's frame): the
    // shell's box met (its four walls, the ceiling, the floor), its surface (box_albedo) lit
    // by the baked light (box_irradiance, with BOX_MAP from its map) and the sun through the
    // windows (box_sun); on the window wall, its three windows as soft rectangles
    // under their arches, their bars at the inner glass, the view out's light (lace_light,
    // back in the room's units) between them, softer the farther and longer up the wall than
    // across it at a grazing look, as a waxed floor's streaks are. After the gilt and brass
    // study's proposal: no cube map.
    vec3 room_seen(vec3 p, vec3 lp, vec3 r, vec3 lr, float alpha, float nov, float px) {
        float big = 1e6;
        float tx = abs(lr.x) < 1e-4 ? big : ((lr.x > 0.0 ? room_box.y : room_box.x) - lp.x) / lr.x;
        float tz = abs(lr.z) < 1e-4 ? big : ((lr.z > 0.0 ? room_box.w : room_box.z) - lp.z) / lr.z;
        float ty = abs(lr.y) < 1e-4 ? big : ((lr.y > 0.0 ? room_heights.x : shell.z) - lp.y) / lr.y;
        float t = max(min(tx, min(ty, tz)), 0.0);
        vec3 h = lp + lr * t;
        vec3 hw = p + r * t;
        vec3 nl = t == ty ? vec3(0.0, lr.y > 0.0 ? -1.0 : 1.0, 0.0)
                : (t == tx ? vec3(lr.x > 0.0 ? -1.0 : 1.0, 0.0, 0.0) : vec3(0.0, 0.0, lr.z > 0.0 ? -1.0 : 1.0));
        #ifdef BOX_MAP
        vec3 c = box_albedo(h, nl) * (box_map_at(h, nl) + box_sun(hw, nl));
        #else
        vec3 c = box_albedo(h, nl) * (box_irradiance(h, nl) + box_sun(hw, nl));
        #endif
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
        // The window nearest where the ray meets the wall: a ray sharp enough to show one
        // (room_reflection) blurs its edges by less than the wall between two, so the others
        // add nothing.
        if (shell.x < 0.5) return c;
        float along = dot(hw.xz, axes.xy);
        float mid = shell_mids[0];
        for (int i = 1; i < 3; i++) {
            if (float(i) < shell.x && abs(along - shell_mids[i]) < abs(along - mid)) mid = shell_mids[i];
        }
        vec2 w = vec2(along - mid, hw.y - shell.z) / metre;
        float head = arch_mid + sqrt(max(radius * radius - w.x * w.x, 0.0));
        float rect = smoothstep(-soft.x, soft.x, half_w - abs(w.x))
                   * smoothstep(-soft.y, soft.y, min(w.y - shell_niche.y, head - w.y));
        if (rect < 0.001) return c;
        vec2 wg = vec2(dot(qg.xz, axes.xy) - mid, qg.y - shell.z) / metre;
        return mix(c, mix(bars, view, casement(wg, max(soft.x, soft.y), vec2(0.0))), rect);
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

    // How much of the sky the chair at c hides from p on the floor round its four feet, each
    // a sphere of 22 mm 40 mm up (as base_hides's).
    float chair_hides(vec3 p, vec4 c) {
        vec2 d = p.xz - c.xy;
        if (dot(d, d) > 400.0) return 0.0;
        vec2 q = vec2(abs(c.w * d.x - c.z * d.y), c.z * d.x + c.w * d.y);
        vec2 f = q - CHAIR_FRONT_FOOT;
        vec2 b = q - CHAIR_BACK_FOOT;
        float h = 1.22;
        float r2 = 0.45;
        return r2 * h / pow(dot(f, f) + h * h, 1.5) + r2 * h / pow(dot(b, b) + h * h, 1.5);
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

    #if !defined(MIRROR_CHEAP) && !defined(BOX_MAP_BAKE)
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
    #ifndef ROOM_FLOOR
        float screen_ao = ssao_at(p);
    #endif
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
        vec2 lp = lace_place(v_uv);
        vec2 gx = dFdx(v_uv) * lg;
        vec2 gy = dFdy(v_uv) * lg;
        // The hem's tips reach the mask's bottom edge, which the repeating sampler joins to
        // the pattern's dense top row: a footprint (mip or anisotropic taps) over that edge
        // drew a thin light line under the hem, and the cloth past the last row, held to it,
        // drew the tips on down. So the footprint is held inside the edge, and nothing past
        // the last row is drawn (2026-11-23).
        float edge = (1.0 - lp.y) * 1408.0;
        float reach = max(length(gx * vec2(1024.0, 1408.0)), length(gy * vec2(1024.0, 1408.0)));
        float hold = lp.y > 1024.0 / 1408.0 ? clamp(edge / max(reach, 1e-6), 0.0, 1.0) : 1.0;
        float cover = textureGrad(lace_mask, lp, gx * hold, gy * hold).r;
        if (cover < 0.02 || (0.375 * tile.z - v_uv.y) / tile.z > 0.3745) discard;
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
            // The rug under the games table (render3d::put_rug), lying along the window wall: where
            // the eye's ray meets its top (q lifted toward the eye by the thickness), its pile;
            // where the ray meets the floor under it, its side, darker; round it, its contact
            // on the floor.
            // The floor's light (the sun, the table's shadow, the probes, the corners) is the
            // rug's too, at the floor's height.
            vec2 q = uv / shell.w - vec2(0.0, RUG_IN);
            if (fract(0.5 * shell_ends.w) > 0.25 && max(abs(q.x) - RUG_HALF.x, abs(q.y) - RUG_HALF.y) < 0.05) {
                vec3 to_eye = eye.xyz - p;
                vec2 lift = vec2(dot(to_eye.xz, axes.xy), dot(to_eye.xz, axes.zw)) * (RUG_THICK / max(to_eye.y, 1e-3));
                vec2 out_top = abs(q + lift) - RUG_HALF;
                vec2 out_q = abs(q) - RUG_HALF;
                bool on_top = max(out_top.x, out_top.y) < 0.0;
                bool on_side = !on_top && max(out_q.x, out_q.y) < 0.0;
                vec2 at = on_top ? q + lift : q;
                vec4 r4 = textureGrad(rug_map, at / RUG_TEX + 0.5, dx / (shell.w * RUG_TEX), dy / (shell.w * RUG_TEX));
                float cover = on_top || on_side ? 1.0 : 0.0;
                // The pile rolls over at its edge, with a faint sheen of the wool toward
                // grazing; the side is in its own shade.
                float edge = on_top ? clamp(-max(out_top.x, out_top.y) / 0.004, 0.0, 1.0) : 0.0;
                float graze = 1.0 - to_eye.y * inversesqrt(dot(to_eye, to_eye));
                graze *= graze;
                vec3 pile = srgb(r4.rgb) * (on_top ? (0.7 + 0.3 * edge) * (1.0 + 0.25 * graze * graze) : 0.3);
                albedo = mix(albedo, pile, cover);
                rough = mix(rough, 1.0, cover);
                n = normalize(mix(n, ng, cover));
                fine = mix(fine, 1.0, cover);
            #ifdef PLANAR_FLOOR
                wax *= 1.0 - cover;
                n_film = normalize(mix(n_film, ng, cover));
            #endif
                if (!on_top && !on_side) {
                    float off = length(max(out_q, 0.0));
                    ao *= mix(0.4, 1.0, sqrt(smoothstep(0.0, 0.035, off)));
                }
            }
            // The table hides the sky under it, its scroll toes the floor they stand on,
            // and the walls along their feet. In the room the top's broad shade is the
            // probes' and the screen's: only the base's contact stays here.
            if (table_map[3].x < 0.5) ao *= mix(0.55, 1.0, smoothstep(0.5625 * table.x, 1.375 * table.x, r));
            ao *= 1.0 - base_hides(p);
            if (shell_ends.w > 1.5) ao *= 1.0 - clamp(chair_hides(p, CHAIR_A) + chair_hides(p, CHAIR_B), 0.0, 0.7);
            if (shell.x > 0.5) {
                // A dark contact line at the plinth's lip (5 cm out); the walls' broader shade
                // is the corners' map's.
                fine *= mix(0.4, 1.0, smoothstep(0.0, 0.015 * shell.w, to_wall - 0.05 * shell.w));
            } else {
                ao *= mix(0.6, 1.0, smoothstep(0.0, 8.0, place.y - uv.y)) * mix(0.7, 1.0, smoothstep(0.0, 8.0, uv.y + place.x));
            }
        }
    #ifdef SURFACE_OUT
        // The floor unlit, laid out in its uv, for Blender (tools/blender_export.goose): its
        // albedo and roughness, or with SURFACE_NORMAL its normal along u, v and up.
    #ifdef SURFACE_NORMAL
        result = vec4(vec3(dot(n, u_dir), dot(n, v_dir), n.y) * 0.5 + 0.5, 1.0);
    #else
        result = vec4(albedo, clamp(rough, 0.0, 1.0));
    #endif
        return;
    #endif
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
        // The shutters' fronts (own's half, joinery::paint_mat) keep the screen's occlusion off.
        float no_screen = step(0.495, own);
        float on_window = step(0.195, own - 0.5 * no_screen);
        float piece = own - 0.5 * no_screen - 0.2 * on_window;
        float along = step(0.095, piece);
        float tone = (piece - 0.1 * along) / 0.099;
        float dirt = 1.0 - smoothstep(0.3 * paint_quiet.z - 0.5 * fwidth(v_uv.y), paint_quiet.z + 0.5 * fwidth(v_uv.y), v_uv.y);
        float joint = line_cover(v_uv.x, 0.00015, fwidth(v_uv.x));
        // The doors' panels and architraves step by a few mm, under the screen's occlusion's
        // half-size texel, so its lines crawl along them as the eye moves: off within 2 cm of
        // a recess (all of a panel's ring), back by 4.5; the ring's own occlusion and the dirt
        // shade them. Kept on the windows, whose casements' inner corners it shades, but not on
        // the shutters' fronts, where it crawled the same way against the window.
        screen_ao = mix(1.0, screen_ao, (1.0 - no_screen) * max(on_window, smoothstep(0.02, 0.045, v_uv.y)));
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
        vec2 slope = (relief.xy * 255.0 - 128.0) / 127.0 * RELIEF_SLOPE * strength;
        n = normalize(n - t_across * slope.x - t_along * slope.y);
        float spread = relief.w * RELIEF_SLOPE * strength;
        albedo = srgb(paint.rgb) * (1.0 + 0.02 * (tone - 0.5));
        albedo *= 1.0 - 0.45 * dirt * (vec3(1.0) - vec3(0.80, 0.76, 0.68));
        albedo *= 1.0 - 0.5 * joint;
        rough = mix(paint_quiet.x, paint_quiet.y, on_window) + 0.1 * dirt + 0.1 * joint;
        rough += 0.04 * strength * (relief.z * 2.0 - 1.0);
        rough = sqrt(rough * rough + 2.0 * spread * spread);
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
            albedo = srgb(stone.rgb) * (0.4 + tile4.r);
            rough = stone.a + 0.06 * (tile4.a - 0.5) + 0.15 * tile4.g;
            // The band, 0.36 to 1 of sill.y back, its edge and strength in patches.
            float r = sill.x;
            float ft = max(fwidth(t), 1e-5);
            float back = max(t, 0.0) + 0.012 * (2.0 * tile4.b - 1.0);
            float polish = (1.0 - smoothstep(0.36 * sill.y, sill.y, back)) * smoothstep(-1.5 * r, -0.5 * r, t) * (0.7 + 0.3 * tile4.b);
            rough -= 0.22 * polish;
            // The arris: the normal turned toward it by up to 45° within r of it; under a
            // pixel, spread over the pixel and turned less. A chip in about one 5 cm of it in
            // seven: a flake broken off across it, paler and rougher, its face at an angle of
            // its own; faded as it falls under a pixel.
            float wide = max(r, ft);
            float ease = clamp(1.0 - abs(t) / wide, 0.0, 1.0) * r / wide * on_slab;
            float cell = floor(v_uv.x / 0.05);
            float fp = max(ft, fwidth(v_uv.x));
            float rad = mix(0.0008, 0.0025, h12(vec2(cell, 7.3)));
            vec2 off = vec2((v_uv.x - (cell + 0.15 + 0.7 * h12(vec2(cell, 5.1))) * 0.05) / 0.6, (t + (0.6 - h12(vec2(cell, 9.9))) * r) * 0.6);
            float chip = (1.0 - smoothstep(rad - 0.5 * fp, rad + 0.5 * fp, length(off))) * step(h12(vec2(cell, 3.7)), 0.15)
                       * min(1.0, rad * rad / (fp * fp)) * on_slab;
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
            albedo *= 1.0 - sill.z * smoothstep(0.0, 1.0, clamp(-t / SILL_BOARD, 0.0, 1.0)) * on_slab;
            // The dust, thickest against the casement's frame, in patches.
            float before = SILL_FRAME - t;
            float dust = exp(-max(before, 0.0) / sill.w) * step(0.0, before) * (0.55 + 0.45 * tile4.b);
            albedo = mix(albedo, srgb(vec3(0.45, 0.43, 0.4)), 0.6 * dust);
            rough = mix(rough, 0.85, dust);
        }
    #endif
    #ifdef ROOM_METALS
        if (kind > 14.5) {
            // The stove's glaze (room_shell::stove): its part in its fraction (stove.goose's
            // GLAZE_*), its uv metres along the face and up. Each tile is its own cell: tilted
            // a little, rolled over toward its joints within STOVE_ROLL, its glaze pooled
            // darker and greener in a band inside the roll and paler on its crest, its value
            // and hue a little its own, under a slow cloud; the joints lime grout, recessed,
            // faded to their share where they are under a pixel. The relief tiles (the waist's
            // rosettes, the frieze's palmettes) and the crest's plates take the atlas's slopes,
            // the glaze darker in the hollows. A clear coat over the body: it sees the room
            // sharp (SHARP_BOX's px), so the windows break tile by tile.
            vec2 gx = dFdx(v_uv);
            vec2 gy = dFdy(v_uv);
            float code = floor(own * 8.0);
            float pw = max(max(abs(gx.x), abs(gy.x)), max(abs(gx.y), abs(gy.y))) + 1e-6;
            vec2 size = vec2(STOVE_TILE.x, code < 2.5 ? STOVE_TILE.y : (code < 3.5 ? 0.08 : 0.16));
            vec2 q = v_uv / size;
            vec2 cell = floor(q);
            vec2 f = q - cell;
            vec2 e = min(f, 1.0 - f) * size;
            if (code < 0.5) e.y = 1.0;
            if (code > 4.5) e = vec2(1.0);
            float edge = min(e.x, e.y);
            vec3 tg = vec3(-ng.z, 0.0, ng.x);
            float tl = length(tg);
            tg = tl > 0.2 ? tg / tl : vec3(0.0);
            vec3 bt = tl > 0.2 ? normalize(vec3(0.0, 1.0, 0.0) - ng * ng.y) : vec3(0.0);
            vec2 id = cell + vec2(0.0, 61.0 * code);
            vec4 rnd = vec4(h12(id), h12(id + 17.31), h12(id + 41.7), h12(id + 73.1));
            float sharp = 1.0 - smoothstep(0.003, 0.012, pw);
            vec2 lean = vec2(0.0);
            vec3 body = srgb(STOVE_GLAZE) * (0.96 + 0.08 * rnd.z) * (0.97 + 0.06 * vnoise(v_uv * vec2(3.0, 2.5)));
            body *= mix(vec3(1.0), rnd.w > 0.5 ? vec3(0.98, 1.0, 1.035) : vec3(1.025, 1.0, 0.955), abs(rnd.w - 0.5) * 2.0);
            if (code < 4.5) {
                lean = (rnd.xy - 0.5) * (2.0 * STOVE_TILT);
                float roll = 1.0 - smoothstep(0.0, STOVE_ROLL, edge);
                vec2 toward = vec2(f.x > 0.5 ? 1.0 : -1.0, f.y > 0.5 ? 1.0 : -1.0);
                lean += (e.x < e.y ? vec2(toward.x, 0.0) : vec2(0.0, toward.y)) * (0.9 * roll * roll * sharp);
                float pooled = smoothstep(0.004, 0.009, edge) * (1.0 - smoothstep(0.014, 0.026, edge));
                float crest = smoothstep(0.0015, 0.003, edge) * (1.0 - smoothstep(0.003, 0.007, edge));
                body = mix(body, body * vec3(0.8, 0.87, 0.78), 0.5 * pooled) * (1.0 + 0.07 * crest * sharp);
            }
            if (code > 2.5 && code < 5.5) {
                vec2 at = code > 4.5 ? v_uv : f;
                vec2 sz = code > 4.5 ? vec2(1.0) : size;
                float rows = code < 3.5 ? 256.0 - STOVE_PALMETTE_ROWS : STOVE_PALMETTE_ROWS;
                float first = code < 3.5 ? STOVE_PALMETTE_ROWS : 0.0;
                vec2 k = vec2(1.0 / sz.x, -rows / 256.0 / sz.y);
                vec4 r = textureGrad(stove_relief, vec2(at.x, (first + (1.0 - at.y) * rows) / 256.0), gx * k, gy * k);
                vec2 slope = (r.rg * 2.0 - 1.0) * STOVE_SLOPE;
                lean -= slope;
                body *= (1.0 - 0.14 * clamp(length(slope), 0.0, 1.0) * (1.0 - r.b)) * (1.0 + 0.04 * r.b);
            }
            float gw = 0.0015;
            float grout = clamp((gw - edge) / pw + 0.5, 0.0, 1.0) * min(1.0, 2.0 * gw / pw);
            n = normalize(ng + (tg * lean.x + bt * lean.y) * (1.0 - grout));
            albedo = mix(body, srgb(STOVE_GROUT) * 0.7, grout);
            rough = mix(STOVE_ROUGH, 0.9, grout);
        } else if (kind > 13.5) {
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

        vec3 l = light_dir.xyz;
    #ifndef ROOM_FLOOR
        vec3 v = normalize(eye.xyz - p);
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
    #endif
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
    #ifdef ROOM_FLOOR
        // Trace the sun above before computing the view, light colour and occlusion.
        vec3 v = normalize(eye.xyz - p);
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
        float screen_ao = ssao_at(p);
        float corner = 1.0;
        if (kind < 13.5 && shell.x > 0.5) {
            vec2 size = vec2(textureSize(corner_map, 0));
            vec2 lo = vec2(mod(v_box.x, 4096.0), floor(v_box.x / 4096.0)) + 0.5;
            vec2 hi = vec2(mod(v_box.y, 4096.0), floor(v_box.y / 4096.0)) + 0.5;
            corner = texture(corner_map, clamp(v_corner * size, lo, hi) / size).r;
        }
        ao = metal > 0.9 ? ao : fine * min(ao * corner, ssao_kept(screen_ao));
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
        float px = metal > 0.5 ? (metal > 0.9 ? 0.5 : 0.25) * length(fwidth(rv)) : (kind > 14.5 ? 0.5 * length(fwidth(rv)) : 1.0);
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
        if (ssao.y > 2.5 && ssao.y < 3.5) result = vec4(to_srgb(tonemap(irr * 0.45 * params.x * shade.w)), 1.0);
        // The tuner's view of broken values: red where a term isn't finite (by its bits, which
        // fast math keeps), yellow where the light is absurd (over 64 exposed), the picture a
        // quarter as bright elsewhere.
        if (ssao.y > 3.5 && ssao.y < 4.5) {
            uvec4 e = (floatBitsToUint(vec4(color, length(n))) >> 23) & 255u;
            uvec4 f = (floatBitsToUint(vec4(env, spec.r + irr.r + base.r)) >> 23) & 255u;
            bool broken = any(equal(e, uvec4(255u))) || any(equal(f, uvec4(255u)));
            bool absurd = max(max(color.r, color.g), color.b) > 64.0;
            result = broken ? vec4(1.0, 0.0, 0.0, 1.0) : (absurd ? vec4(1.0, 1.0, 0.0, 1.0) : vec4(result.rgb * 0.25, 1.0));
        }
    #endif
    #endif
    }
    #elif defined(MIRROR_CHEAP)
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
        // The chairs' tapestry and braid by their means (tools/materials/tapestry.py's).
        vec3 albedo = v_mat > 6.5 ? vec3(0.38, 0.29, 0.15) : v_mat > 5.5 ? vec3(0.413, 0.272, 0.169) : textureLod(own_albedo, vec2(0.5), 20.0).rgb;
        if (v_mat > 3.5 && v_mat < 4.5) {
            float from_mid = length(p.xz - vec2(0.0, TABLE_Z));
            float e = (TABLE_TOP - p.y) / max(t_shape.x - from_mid, 0.5);
            ao *= 1.0 - (1.0 - t_pool.z) / (1.0 + e * e) * (0.6 + 0.4 * max(ng.y, 0.0));
        } else if (v_mat < 3.5) {
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
        } else if (kind > 14.5) {
            // The stove's glaze, its body's colour.
            albedo = srgb(vec3(0.804, 0.835, 0.745)) * 0.95;
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
    #else
    // The box's map (render3d::box_map_pass, BOX_MAP_BAKE): box_irradiance at each texel's
    // middle, by box_cell's layout; nothing past the cells. A triangle over the map
    // (BOX_MAP_VERT), gl_FragCoord its texel.
    void main() {
        vec2 q = gl_FragCoord.xy;
        vec3 faces[6] = vec3[6](vec3(0.0, 1.0, 0.0), vec3(0.0, -1.0, 0.0), vec3(1.0, 0.0, 0.0), vec3(-1.0, 0.0, 0.0),
                                vec3(0.0, 0.0, 1.0), vec3(0.0, 0.0, -1.0));
        result = vec4(0.0);
        for (int k = 0; k < 6; k++) {
            vec2 at, size, extent;
            box_cell(faces[k], at, size, extent);
            vec2 f = q - at;
            if (any(lessThan(f, vec2(0.0))) || any(greaterThanEqual(f, size))) continue;
            vec2 w = min(f * BOX_MAP_TEXEL, extent);
            vec3 nl = faces[k];
            vec3 h = nl.y != 0.0 ? vec3(room_box.x + w.x, nl.y > 0.0 ? shell.z : room_heights.x, room_box.z + w.y)
                   : (nl.x != 0.0 ? vec3(nl.x > 0.0 ? room_box.x : room_box.y, shell.z + w.y, room_box.z + w.x)
                                  : vec3(room_box.x + w.x, shell.z + w.y, nl.z > 0.0 ? room_box.z : room_box.w));
            result = vec4(box_irradiance(h, nl), 1.0);
        }
    }
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
// The probe volumes in the baked light (render3d::volumes_light: the light tuner's --light
// physical), on the desktop's HDR tier: the paint's, the sills' and the metals' groups, which
// the windows' spaces between the panes hold.
let PROBE_VOLUMES = "#define PROBE_VOLUMES 1\n";
// The sharp box's light from the box's map (render3d::box_map), on the phone's tier: the
// floor's and metals' pipelines with SHARP_BOX and NO_SSAO; the map's bake (BOX_MAP_BAKE,
// with no group's define, so ROOM_HEAD declares the opaque groups' shared textures alone).
let BOX_MAP = "#define BOX_MAP 1\n";
let BOX_MAP_BAKE = "#define BOX_MAP_BAKE 1\n";
// The light tuner's views of the room (render3d::room_views_on: the screen's occlusion, the
// indirect light, the sun's highlights, the floor's reflection alone), in pipelines of
// their own made while one is on: their code cost the room 0.55 ms at 3024 × 1890 where
// none was shown. With the screen's maps only, never in the mirror.
let ROOM_VIEWS = "#define ROOM_VIEWS 1\n";
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
