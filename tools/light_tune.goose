// Tunes the light of the room the 3D board stands in on its table (task 104): a room's take
// (rooms::LIBRARY..) and its values on sliders: the sun's direction, height, color and
// strength, how dark its shadow is, the window's sky, the walls, and the window's pattern
// with its bars, curtain, and the trees' leaves. Drag to orbit, scroll to zoom, R resets
// the camera, W switches the pattern (its leaves swaying in the wind), T the leaves between
// the tree's baked shadow and the noise, K the wind's kind (rooms::WIND_KINDS: sines,
// noise, still, branches), D the dust in the sunbeam (the room round the table is the
// library's shell, room_shell::LIBRARY: its walls, wainscot, windows, doors, cornice and
// ceiling), V the views in turn (the board, then the room's: room, window, hall, stove,
// VIEWS), U the view out of the shell's windows (model3d::view_out) or the plain sky behind
// them as before, B the bookcases' books (model3d::books) in or out, H the windows'
// shutters, L the wallpaper's tile round a real paper's 0.65 m, the default 0.9 m and style-01's 1.4 m, F the frame counter in the corner (frames a
// second, the frame's time and its worst over half a second, the time in the loop before
// the submit; SDL's GPU has no timer queries, so no GPU time), G waits for the GPU each
// frame so the loop's time is the CPU's and the GPU's, N the 3D scene's scale (the high
// tier's budget of pixels, or 1, 0.85, 0.75, 0.67 of the screen's side) and M its upscale
// (Catmull-Rom or bilinear; the panel stays at the screen's pixels), P prints the room as Goose and the
// flags that show the same again (and saves them in build/light-tune.txt). Tab walks round
// the room (Walk: WASD and the mouse, Esc back to the panel); the camera stays where the
// walk left it, and P prints it as --plan-eye and --plan-at, till R or V.
// A cycles the sun's and the table's verified placements (PLACE_NAMES; the Table section's
// sliders move the table, turn it under the board and turn the board, the room built again
// when the slider is let go).
//
// The panel is in sections that open and close (SECTIONS, kept for the session; Keys
// lists the keys). A drag that starts on the panel holds the tree's and the probes' bakes
// till it is let go, so a slider bakes once, not each step.
//
//   scripts/mac.py tools/light_tune.goose
//   cd tools && ../build/light_tune [--season autumn|winter|spring|summer (the season's room, rooms::for_season)]
//       [--material auto|wood|stone|carved]
//       [--table board|flame] [--window on|off] [--leaves tree|noise|both] [--seed N] [--wind-time S]
//       [--wind-kind sines|noise|still|branches]
//       [--gust X,Y,Z,W | --gust-strength K --gust-length S --gust-every S --gust-reach K (rooms::Room's gust)]
//       [--tree|--crown|--foliage|--trees|--wind X,Y,Z,W (rooms::Room's tree, crown, foliage, leaves, wind)]
//       [--wall|--panes|--opening X,Y,Z,W (the window's)] [--key|--fill|--walls|--pattern|--bounce X,Y,Z,W]
//       [--dump-map out.pgm] [--tree-grow shadow|whole (the shell's tree's shadow from the old maple grown whole)]
//       [--tree-draw off|wood|all (the tree outside drawn as geometry, render3d::TREE_DRAWS; off; on, its shadow grown whole too)
//       --tree-light SUN,SKY,THROUGH,FORWARD (2.5,1,0.35,0.6) --tree-look SHADE,TWIG_PX,SPREAD (1,1,0.15)
//       --tree-tint TINT,LEAVES,BARK,DEEPER (0.2,1,1,0.6)
//       --tree-elbows FEWEST,MOST,TURN_LO,TURN_HI (0,0,30,50) --tree-gravity S (0) --tree-shed LIGHT,STUBS (0,0.5)
//       --tree-plates ON,SPURS,NUDGE (0,2,0) --tree-tilt ON,SEASON,SAG (0,2,8) --tree-bend SHARE,TWIST (0,25)
//       --tree-leaf-mesh tier|card|rows|fan (the leaves' meshes; tier)
//       --tree-wind off|on (the shadow's wind on the geometry, the leaves fluttering in HDR; off) --tree-flutter DEG,RATE (6,9)
//       --tree-card off|on|main (the tree drawn once into a card: in the floor's mirror, or the main view too; off)
//       --tree-bark off|on (the bark's age layers; off) --tree-relief K (1) --tree-scatter W (0) --tree-rough S (0)
//       --tree-junctions off|on --tree-roots off|on (the wood's junctions, the flare's roots; off) --tree-wood-tier high|standard|phone]
//       [--azimuth DEG] [--sun-height DEG]
//       [--table-at X,Y (the games table's middle in the plan, metres; 4.5,5.8 as made)]
//       [--table-turn DEG (the table turned under the board, its top's figure with it; 0 as the game's)]
//       [--base-wood today|own (the table's base: the map as the top's, or its own wood, the grain along the
//       column and the legs, as the chairs'; own)] [--base-light K (its lightness, a share of the map's; 0.57)]
//       [--base-figure K (its figure's contrast, a share of the map's; 0.6)] [--base-streaks K (how far the figure
//       is drawn out along the grain; 3)] [--base-slant DEG (the grain's slant round the column; 0)]
//       [--base-rings K (the rings the column's cut crosses, 0 none; 0)] [--base-place U (where across the map it
//       reads, 0 to 1; 0.5)] [--base-colour K (the colour's strength, 1 the map's; 0.75)]
//       [--board-turn DEG (the board's own z, the players' axis, from the window wall's line in the plan; sets the key's azimuth)]
//       [--place free|concept|concept-high|along-wall|less-turned|concept-pier|more-turned (PLACE_NAMES: a verified sun, table and
//       board together, the table-window view's eye with them; less-turned without the flag, free the other flags' own;
//       A cycles them, the Table section shows the sun-check)]
//       [--place-then NAME (that placement taken on the third frame, as A takes it: a check of the room built again)]
//       [--sun-check (prints where the sun's ray from the board and the table leaves the room: a window's
//       glass, a bar, its frame, or the wall; then quits unless --shot)]
//       [--dust off|points (in the table-window view only: real dust's points in the sunbeam,
//       energy-conserving: DUST_WAYS; points the default)]
//       [--mote-fibres SHARE (0 no fibres)] [--fibre-width K (the fibres' width across, a share of a point's; 0.5)]
//       [--motes N] [--mote-bright K] [--exposure K]
//       [--point-px SIGMA (the points' footprint, 0.75)] [--glints K (the flakes' glints, 1 as real, 0 off)]
//       [--air DRIFT,RISE,SWIRL,SIZE (cm a second, the swirls' size in cm; 1.2,1,1.5,12)] [--near K (denser round the board, 0 even)]
//       [--haze off|menu|game (the sunbeam's haze with HDR, render3d::Haze: menu the main menu's scene's level, 3e-3 a
//       metre with its stripes softer; game the game's own scene's, 4e-4; off)] [--haze-sigma S (a metre, over the preset)]
//       [--haze-look G,EVEN,TAPS,SOFT (0.7,0.2,12,1; SOFT the stripes' softness, 0 sharp, 1 the sun's disc; menu 4)] [--haze-res half|full (half)]
//       [--haze-toward K (the stripes K times softer again looking toward the sun)]
//       [--halo K --halo-reach K (the pieces' darkening of the field round them: its strength, and its reach
//       as a share; 0 or none the shader's own, shaders::OCC_FRAG's HALO and HALO_REACH, 1 and 1 today)]
//       [--room-exposure K]
//       [--outside on|off] [--outside-exposure K (rooms::Room's outside)]
//       [--park off|ground|no-shading|no-leaves|no-grounding|no-shadows (the lawn and trees on the ground outside, PARK_NAMES)]
//       [--eye X,Y,Z --at X,Y,Z (a camera of its own, world units)]
//       [--plan-eye X,Y,H --plan-at X,Y,H (one in the room's plan, metres: x along the window wall
//       from the stove's end, y from the hall wall, H up from the floor)] [--fov DEG]
//       [--wallpaper-tile M (the wall a tile of the wallpaper covers, metres)]
//       [--oak-tint L,S | --ceiling-tint L,S (the panelling oak's, the ceiling's lightness and saturation, 1,1 as made)]
//       [--books on|off] [--book-fade K (how much of the books' fade shows, 1 as made)] [--shutters on|off]
//       [--rug on|off (the rug under the games table)] [--chairs on|off (the two chairs at it)]
//       [--props-light off|on|kept (the table and the chairs lit from the room's probes where each pixel is, through
//       their occlusion baked per vertex, render3d::props_light; kept: the table's own shade terms kept beside the bake)]
//       [--light today|physical (the room's light from physical inputs, physical_light; today as made)]
//       [--camera-toe room|neutral|none|agx (--light physical's one curve after the HDR pass: the shoulder after
//       that toe, or AgX at the metered exposure, the default)] [--camera-ev EV (AgX's exposure over the meter's; 0)]
//       [--props-wrap K (--light physical: how far past its terminator the sun wraps on the table and chairs; 0)]
//       [--casement-depth on|off (--light physical: the sun through the casements' members with their depth, in the bake
//       and on every surface, rooms::Room's panes.w; on)] [--stove on|off]
//       [--paint-relief K (the painted wood's relief tile's strength, 1 as made)]
//       [--lace-hang M (the lace panels' inner edges further over the opening, metres, on all three windows;
//       0.15 by default, 0 as made; Y switches 0.15 and 0)]
//       [--dump-glass-tile PREFIX (the glass's wiping tile and its previews; then quits)]
//       [--sun-look made|veil (the sun's looks, SUN_LOOK_NAMES; then each part over it:)
//       --sun-disc R,LIMB,EDGE,BRIGHT --sun-glare CORE,WIDTH,GLOW,WIDTH --sun-tree DENSITY,REACH,BACKLIGHT,SHARP
//       --sun-eye STRENGTH,HALF_DEG,END_DEG,AMBER (the eye's veil round the sun, HDR; 0 off)
//       --glow STRENGTH,THRESHOLD,KNEE,REACH --glow-levels N]
//       [--view-nudge DX,DY,DZ (the table-window view's eye and target moved, metres in the plan)]
//       [--tone-probe K (HDR: the picture's linear light times K as grey levels, no tonemap; -K the sun's open share)]
//       [--lace-sun K] [--lace-scatter K] [--glass-film K] [--scratches K] [--sun-veil K] (the window view's
//       steps, render3d::window_view and sun_veil: each a strength, 1 as made, 0 off; Z switches them, the
//       lace's hang and the dust all off and back)
//       [--lace-shade-fill K (the lace's room-side fill where neither sun nor sky reaches it, 0.5)]
//       [--lace-fold-ao K (how much the folds' valleys darken that fill, 1.5, the deepest to 0.4)]
//       [--panel-ao STRENGTH,WIDTH_CM,CREASE,BEVEL (the panels' rings' occlusion, crease and bevel's width; 0.6,0.4,0.85,1; at the start)]
//       [--bounces N (1)] [--bounce-grey K (0.25)] [--lace-source K] [--gather-near M2 (the probes' least distance², 0.09; 0.02 with --light physical)]
//       [--dump-light PATH (the probes' atlas, a float a line, with --shot; with the props' light their nine harmonics' atlas
//       too, PATH.props)] [--print (the command line printed on the first frame, as P)]
//       [--dump-room-block PATH (the room's Surfaces block as its raw bytes, with --shot; scripts/room_fixed.py)]
//       [--ssao-view off|alone|kept|light|broken (light: the indirect light alone on grey; broken: red where a
//       term isn't finite, yellow where the light is over 64)]
//       [--contact STRENGTH,LENGTH,STEPS,THICKNESS (the sun's contact shadows, world units; 0.8,3,12,1.5; 0 off)]
//       [--room-sun K (the sun's saturation on the room, 0.6; 1 as the key)]
//       [--oak-sun SHARE,SAT,SHEEN (the panelling oak's share of the room's sun, its saturation and share of the sheen)]
//       [--sheen STRENGTH,ROUGHNESS,PAPER,VIEW (the sun's broad sheen; 2,0.8,1,0; 0 off; VIEW 1 the highlights alone)]
//       [--sections all|NAME,NAME.. (SECTION_NAMES open at the start)] [--shot-panel (the panel in a --shot)]
//       [--view board|room|window|hall|stove|table-window] [--dump-oak PREFIX (the oak's fields as PREFIX-floor.ppm, -wall.ppm)]
//       [--hdr on|off (the scenic views drawn into the HDR target and tonemapped after, render3d::hdr_shown; on; X
//       switches it)] [--dof on|off (the lens, render3d::Lens; off)] [--focus M (0 the view's target)]
//       [--aperture PCT (a disc's radius at infinity, % of the width)] [--dof-caps NEAR,FAR (%)]
//       [--lens-view off|depth|coc (the depth of field's depth over the picture, or the lens's disc; 1)]
//       [--size 1600x1000] [--distance K] [--height DEG] [--yaw DEG] [--shot out.png]
//       [--gpu-capture ABSOLUTE.gputrace (one Metal frame; set MTL_CAPTURE_ENABLED=1)]
//       [--fps on|off] [--fps-wait (wait for the GPU each frame, G)]
//       [--no-vsync (present without waiting for the display, to measure frames uncapped)]
//       [--fps-seconds S (print the counter each half second, quit after S)]
//       [--walk-test N (the walk driven by injected input for N frames, WALK_TEST_END all; with --shot)]
//       [--planar-size K (the floor mirror's scale, 3 a third, 2 half) --planar-wide TEXELS (its least width, 1600)]
//       [--mirror-cheap on|off (the floor mirror's cheap world, a trial: large shapes at their mean colours, off)]
//       [--gtao on|off (the screen's occlusion by GTAO in place of SSAO, on; off for SSAO) --gtao-power K (its visibility
//       raised to K, 1.5)]
//       [--scene-scale K (the 3D scene at K of the screen's side; 1, native, the default; 0 its budget)]
//       [--scene-pixels MP (the budget, render3d::HIGH_SCENE_PIXELS)] [--upscale cubic|bilinear]
//       [--walk-frames DIR --walk-path strafe|turn|forward --walk-count N --walk-turn PX (a walk from --plan-eye
//       looking at --plan-at: D or W held, or the mouse PX a frame to the right, N frames at 1/60 s, each
//       saved as DIR/NNN.png; with --shot)]
//       [--touch on|off (the touch walk, on by default on Android and iOS: the walk from the start, no panel, the
//       screen's left half a stick to walk, its right half a drag to look, Up and Down at the right edge;
//       with the phone's tier: no screen-space occlusion, no floor mirror, no HDR, 4 shadow taps, unless
//       --tier full)] [--tier phone|full] [--aa off|smaa|msaa (the scene's antialiasing; smaa by default, msaa 4×; the 2 key switches MSAA and SMAA live)]
//       [--box on|off (the phone tier's floor and metals reflecting the room's box sharply; on)]
//       [--room-fixed on|off (the phone tier's room shaders with the room's block as constants,
//       src/render3d/room_fixed.goose; on)] [--box-map on|off (the phone tier's sharp box reading the
//       box's map, render3d::box_map; on)]
//       [--window-map on|off (the shell's windows' pattern from the window's light map, render3d::window_map_on;
//       off traces it a pixel as before; on)] [--phone-leaves static|off (the phone's tier's leaves baked into the
//       map at one phase of the wind, or none; static)] [--leaves-moving on (the desktop's leaves lit a pixel, not
//       baked, in a shot too)]
//   On a tablet: scripts/android.py tools/light_tune.goose --run (its own app id, beside the app's);
//   flags by adb shell am start -n io.github.kaitk.draughts.light_tune/.DraughtsActivity --es args '"--scene-scale 0.75"'
//   On an iPhone: scripts/ios.py --device tools/light_tune.goose --console --args "--fps-seconds 30"

import std;
import vec;
import math;
import os;
import gfx;
import ui;
import rules from "../src/rules";
import gui from "../src/gui";
import strings from "../strings";
import board from "../src/board";
import model3d from "../src/model3d";
import render3d from "../src/render3d";

// Asks SDL for the app's GPU driver before the window opens (src/native/display.c).
extern fn draughts_choose_gpu();
extern fn tuner_capture_start(path: const u8[:]) -> bool;
extern fn tuner_capture_stop();
// src/native/launch.c's: 1 on Android, 2 on iOS; the first frame shown, so the activity lifts its cover.
extern fn draughts_platform() -> i64;
extern fn draughts_first_frame();
// src/native/tuner_landscape.c's: landscape alone on Android and iOS, as the benches frame their views.
extern fn tuner_landscape();
// The goose_gfx fork's fullscreen (src/app/host.goose's set_fullscreen): on a phone, SDL's
// immersive mode, the system's bars hidden until a swipe brings them back a moment.
extern fn set_fullscreen(on: bool) -> bool = "gs_gfx_set_fullscreen";

let PANEL_W: f32 = 380.0;
let ROW:     f32 = 20.0;
// looks::AUTUMN.. and MATERIAL_AUTO.. in this order.
let SEASONS = ["autumn", "winter", "spring", "summer"];
let MATERIALS = ["auto", "wood", "stone", "carved"];
let SQUARES = ["8", "10"];
// The park on the ground outside (--park, task 109's look test; render3d::park_ground):
// off as today, the whole of it, or one part off: the grass's shading, autumn's leaves
// (off too in the other seasons), the trees' grounding (the darker lawn under the crowns
// and round the trunks), their shadows. Chosen at the start only.
let PARK_NAMES = ["off", "ground", "no-shading", "no-leaves", "no-grounding", "no-shadows"];
let PARK_NO_LEAVES = 3;
fn park_frag(part: i64, hdr: bool) -> const u8[:] {
    if hdr {
        return match part {
            2 => embed_shader("frag", shaders::PARK_NO_SHADING, shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
            3 => embed_shader("frag", shaders::PARK_NO_LEAVES, shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
            4 => embed_shader("frag", shaders::PARK_NO_GROUNDING, shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
            5 => embed_shader("frag", shaders::PARK_NO_SHADOWS, shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
            _ => embed_shader("frag", shaders::PARK, shaders::HDR_OUT, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
        };
    }
    return match part {
        2 => embed_shader("frag", shaders::PARK_NO_SHADING, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
        3 => embed_shader("frag", shaders::PARK_NO_LEAVES, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
        4 => embed_shader("frag", shaders::PARK_NO_GROUNDING, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
        5 => embed_shader("frag", shaders::PARK_NO_SHADOWS, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
        _ => embed_shader("frag", shaders::PARK, shaders::FS_SET, shaders::FRAME, shaders::OUTSIDE_HEAD, shaders::WIND_FN, shaders::LIGHT_FN, shaders::TONE_FN, shaders::OUTSIDE_FRAG, shaders::PARK_FN, shaders::OUTSIDE_MAIN),
    };
}
let BASE_WOODS = ["today", "own"];
let PROPS_WAYS = ["off", "on", "kept"];
let LIGHT_WAYS = ["today", "physical"];

// The two panes' share of the sun (0.92 each), as tools/path_trace.goose takes them.
let PANES: f32 = 0.8464;
// --light physical's least squared distance (metres²) from a probe to a light it gathers.
let PHYSICAL_GATHER_NEAR: f32 = 0.02;
// --light physical's sun through the casements' members with their depth (--casement-depth).
var casement_depth = true;

fn srgb_of(c: f32) -> f32 {
    if c <= 0.0031308 { return c * 12.92; }
    let e: f32 = 1.0 / 2.4;
    return 1.055 * pow(c, e) - 0.055;
}

// The room's light from physical inputs (task 122), as the path tracer takes them: one sun on
// every surface, the room's (its strength and saturation), through the panes; the bake's
// sun thrown on at its albedo (gain 1, no grey); no light added blind to direction (the
// shade's floor of the key, the kept harmonics and bounce); one exposure for the view, the
// room's sunlit surfaces where today's are. Each value is set from `made`, the room as
// made, never scaled from what `r0` holds, so the command line the tuner prints gives the
// same light again: the sun's strength unless `key_given` (--key's is the physical sun's),
// the exposure unless `exposure_given`.
fn physical_light(r0: rooms::Room, made: rooms::Room, key_given: bool, exposure_given: bool) -> rooms::Room {
    var r = r0;
    let key = rooms::color_of(made.key_color);
    let y = 0.2126 * key.x + 0.7152 * key.y + 0.0722 * key.z;
    let sun = float3 { y, y, y } + (key - float3 { y, y, y }) * render3d::ROOM_SUN_AS_MADE.x;
    r.key_color = float4 { srgb_of(sun.x), srgb_of(sun.y), srgb_of(sun.z), made.key_color.w };
    if !key_given { r.key.z = made.key.z * made.shell_sun.y * PANES; }
    r.shell_sun.y = 1.0;
    r.panes.w = if casement_depth { 1.0 } else { 0.0 };
    render3d::room_sun = float4 { 1.0, 1.0, 1.0, render3d::ROOM_SUN_AS_MADE.w };
    render3d::sun_panes = PANES;
    room_light::glazing = room_light::PHYSICAL_GLAZING;
    room_light::bounce_grey = 0.0;
    r.baked = float4 { r.baked.x, 1.0, 0.0, 0.0 };
    render3d::shade_fill = 0.0;
    if !exposure_given { r.exposure = made.exposure * made.room_exposure / PANES; }
    r.room_exposure = 1.0;
    return r;
}
let TREE_GROWS = ["shadow", "whole"];

// The views (V cycles them): the board's orbit, then the room's from a person's eyes, in
// the plan's metres (room_shell): the whole room from the far corner by the hall; the
// window wall from the hall door; the hall wall from the window; the stove's end from the
// far end; table-window from a chair behind the games table into the middle window, the
// low sun in its upper left pane (library-home-01's framing, mirrored: the sun stays where
// it is, the eye moved).
let VIEWS = ["board", "room", "window", "hall", "stove", "table-window"];
let OFF_ON = ["off", "on"];
let WOOD_TIERS = ["high", "standard", "phone"];
let TABLE_WINDOW = 5;
// What the room shows (render3d::ssao_view): itself, its screen occlusion alone, or all its
// indirect light keeps, or the indirect light alone on grey, or its broken values marked.
let SSAO_VIEWS = ["off", "alone", "kept", "light", "broken"];
// The camera's curves (render3d::camera_toe): the shoulder after a toe on the luminance,
// Khronos PBR Neutral's toe on the least channel, or none; AgX.
let TOES = ["room", "neutral", "none", "agx"];
// The lace's ways (C, --lace): f3 the app's, f2, f and d spare ones in design/materials/,
// read into spare_laces at the start.
let LACE_WAYS = ["f3", "f2", "f", "d"];
var spare_laces: u8[>..] = [];
// --light physical's camera curve (render3d::camera_toe): AgX, as Cycles takes it.
let CAMERA_TOE = render3d::CAMERA_AGX;
// The depth of field's depth shown over the picture (render3d::depth_view): none, the
// distance, the lens's disc.
let LENS_VIEWS = ["off", "depth", "coc"];
// What the floor's mirror shows (render3d::planar_view): the room, the floor's reflection
// alone, the mirror's map over the whole picture, its distances.
let PLANAR_VIEWS = ["off", "floor", "map", "distance"];
// The 3D scene's scales N cycles (render3d::scene_size_of): 0 the high tier's budget of
// pixels (--scene-pixels, render3d::HIGH_SCENE_PIXELS), else that share of the screen's
// side; and its upscale (M).
let SCENE_SCALES: f32[5] = [0.0, 1.0, 0.85, 0.75, 0.67];
let UPSCALES = ["cubic", "bilinear"];
let AA_NAMES = ["off", "smaa", "msaa"];
let AA_WAYS: i32[3] = [render3d::AA_OFF, render3d::AA_SMAA, render3d::AA_MSAA];
let VIEW_EYES: float3[6] = [float3_0, float3 { 8.4, 0.6, 1.7 }, float3 { 4.5, 1.0, 1.6 }, float3 { 4.5, 6.3, 1.6 },
                            float3 { 8.3, 3.5, 1.6 }, float3 { 3.75, 4.5, 1.15 }];
let VIEW_ATS: float3[6] = [float3_0, float3 { 2.6, 5.8, 1.3 }, float3 { 4.5, 7.0, 1.8 }, float3 { 4.5, 0.0, 1.3 },
                           float3 { 0.0, 3.0, 1.4 }, float3 { 4.0, 7.4, 1.42 }];

// The games table's middle in the plan as made (room_shell::LIBRARY's), and a view's point
// moved with the table where --table-at moves it: the table-window view keeps its chair.
let TABLE_AS_MADE = float2 { 4.5, 5.8 };
fn view_point(p: float3, view: i64) -> float3 {
    guard view == TABLE_WINDOW else { return p; }
    let t = room_shell::LIBRARY.table;
    return float3 { p.x + t.x - TABLE_AS_MADE.x, p.y + t.y - TABLE_AS_MADE.y, p.z };
}

// The sun's and the table's placements to compare (build/notes/builder-30/), each verified
// by --sun-check: A cycles them, --place NAME picks one. Each sets the sun's turn across
// the window wall and its height, the games table's middle in the plan, the board's turn
// to the wall (the players' axis, the board's own z, PLACE_SUN.z degrees from the window
// wall's line, its far-end seat swung toward the window), the table's turn under the board
// (PLACE_SUN.w), and the table-window view's eye and target (the sun in the middle window's
// left leaf, as library-home-01 has it). 0 is "free": the flags' own. Without --place the
// tuner starts at PLACE_DEFAULT, less-turned (2026-11-22).
// The sun's looks in the view out (--sun-look; render3d::SunLook's disc, glare, tree and
// veil): "made" the default, its HDR glow alone showing where the sun is (2026-11-22); "veil"
// the sun research's look b (build/notes/window-view/refs/research-sun.html,
// build/notes/builder-34/), kept to retry behind the new maple's thicker leaves: the true
// disc with its edge hidden in its glow and the leaves' gaps sharper, 8000 over the sky,
// and the eye's veil round the sun, which looked overdone against open sky.
let SUN_LOOK_NAMES = ["made", "veil"];
// The haze in the sunbeam's strengths (render3d::Haze.sigma, a metre), the user's levels
// (2026-11-22): off; menu, the main menu's scene with its motes, the ChatGPT library
// study's soft wide beam; game, the game's own scene, a room just dusted (the user's slider
// at about 4.5e-4 at most). Off by default; nothing of it is in the app yet.
let HAZE_NAMES = ["off", "menu", "game"];
let HAZE_SIGMAS: f32[3] = [0.0, 3.0e-3, 4.0e-4];
// Each its stripes' softness (Haze.soft): the sun's disc's, the menu's a wide diffuse beam.
let HAZE_SOFTS: f32[3] = [1.0, 4.0, 1.0];
// Each its stripes softened more looking toward the sun (Haze.toward), where they converge on it.
let HAZE_TOWARDS: f32[3] = [0.0, 4.0, 0.0];
let SUN_LOOKS: render3d::SunLook[2] = [
    render3d::SunLook {},
    render3d::SunLook { float4 { 0.27, 0.0, 0.27, 8000.0 }, float4 { 0.4, 0.8, 0.25, 4.0 }, float4 { 2.0, 180.0, 0.45, 6.0 },
                        float4 { 3.0, 1.5, 20.0, 1.0 } }];
// Each look's glow (render3d::HdrGlow.look: strength, threshold, knee, reach).
let SUN_GLOWS: float4[2] = [float4 { 0.06, 1.0, 0.5, 0.65 }, float4 { 0.06, 1.0, 0.5, 0.65 }];
// --light physical's glow under AgX, its threshold and knee in the picture's light after the
// camera's exposure (render3d::glow_exposure): about AgX's white (0.18 × 2^6.5 is 16), so
// the window wall's glow in the room view adds about what today's does (task 122, step 5).
let AGX_GLOW = float4 { 0.006, 16.0, 8.0, 0.65 };

let PLACE_NAMES = ["free", "concept", "concept-high", "along-wall", "less-turned", "concept-pier", "more-turned"];
let PLACE_DEFAULT = 4;
let PLACE_SUN: float4[7] = [float4_0, float4 { 20.0, 12.0, -20.0, 25.0 }, float4 { 20.0, 29.0, -20.0, 25.0 },
                            float4 { 20.0, 12.0, 0.0, 25.0 }, float4 { 12.0, 15.0, -12.0, 25.0 },
                            float4 { 20.0, 12.0, -20.0, 25.0 }, float4 { 25.0, 12.0, -25.0, 25.0 }];
let PLACE_TABLE: float2[7] = [float2_0, float2 { 4.125, 5.8 }, float2 { 4.125, 5.8 }, float2 { 4.125, 5.8 },
                              float2 { 4.4, 5.8 }, float2 { 3.625, 5.8 }, float2 { 3.975, 5.8 }];
// build/b30/eyes.py: the eye on the line back from the sun's point in the left leaf (2.6 m
// up, the upper sash's lowest panes; 2.86 m for the high sun), standing (1.6 m) unless
// that is nearer the window than 4.5 m from the hall wall; the target 8 degrees right of
// the sun, pitched half-way between the sun and the board.
let PLACE_EYE: float3[7] = [float3_0, float3 { 3.203, 2.979, 1.6 }, float3 { 3.757, 4.5, 1.15 }, float3 { 3.203, 2.979, 1.6 },
                            float3 { 4.037, 3.75, 1.6 }, float3 { 3.203, 2.979, 1.6 }, float3 { 2.824, 3.136, 1.6 }];
let PLACE_AT: float3[7] = [float3_0, float3 { 3.827, 5.912, 1.507 }, float3 { 4.376, 7.414, 1.5 }, float3 { 3.827, 5.912, 1.507 },
                           float3 { 4.245, 6.737, 1.426 }, float3 { 3.827, 5.912, 1.491 }, float3 { 3.701, 6.003, 1.498 }];

// The table-window view's eye and target with placement `place` (0 free: the view's own,
// moved with the table), each moved with the table from where the placement put it.
fn view_eye(view: i64, place: i64) -> float3 {
    guard view == TABLE_WINDOW && place > 0 else { return view_point(VIEW_EYES[view], view) + view_nudge(view); }
    return PLACE_EYE[place] + table_moved_from(place) + view_nudge(view);
}
fn view_at(view: i64, place: i64) -> float3 {
    guard view == TABLE_WINDOW && place > 0 else { return view_point(VIEW_ATS[view], view) + view_nudge(view); }
    return PLACE_AT[place] + table_moved_from(place) + view_nudge(view);
}
// The table-window view's eye and target moved together (--view-nudge, metres in the plan),
// which moves the window's bars past the sun.
var table_window_nudge = float3_0;
fn view_nudge(view: i64) -> float3 { if view == TABLE_WINDOW { table_window_nudge } else { float3_0 } }
fn table_moved_from(place: i64) -> float3 {
    let t = room_shell::LIBRARY.table;
    return float3 { t.x - PLACE_TABLE[place].x, t.y - PLACE_TABLE[place].y, 0.0 };
}

// A placement's sun, table and board into the tuner's values.
fn put_place(place: i64, room: rooms::Room&, table: float2&, board: f32&, board_set: bool&, g: render3d::Gpu&) {
    guard place > 0 else { return; }
    let p = PLACE_SUN[place];
    room.window.y = p.x;
    room.key.y = p.y;
    table = PLACE_TABLE[place];
    board = p.z;
    board_set = true;
    g.table_turn = p.w;
}

// The flags that show a placement's sun, table and board again.
fn place_flags(r: rooms::Room, table: float2, board: f32, top: f32) -> u8[>..] {
    return str("--wall ", r.window.x, ",", r.window.y, ",", r.window.z, ",", r.window.w, " --sun-height ", r.key.y, " --table-at ",
               table.x, ",", table.y, " --board-turn ", board, " --table-turn ", top);
}

// The key's azimuth (rooms::Room.key.x) that puts the board's own z, the players' axis,
// `board` degrees from the window wall's line in the plan with the sun `turn` degrees
// across the wall: the room's frame turns with the key (surfaces::frame_of), so the board
// turns in the plan by the key's azimuth, -azimuth - turn degrees from the plan's x.
fn azimuth_for(board: f32, turn: f32) -> f32 {
    var a = -board - turn;
    while a > 180.0 { a -= 360.0; }
    while a <= -180.0 { a += 360.0; }
    return a;
}

// The board's own z in the plan as the room is turned now, degrees from the plan's x
// toward its y (the window).
fn board_in_plan(g: render3d::Gpu&) -> f32 {
    let f = g.room_frame;
    return degrees(atan2(-f.into.y, -f.along.y));
}

// The dust in the sunbeam (D, --dust), in the table-window view only, the main menu's scene
// (never the game's): off, or points: real dust as a camera sees it
// (builder 33, build/notes/window-view/refs/research-haze-motes.md): points of a fixed small
// footprint at any resolution carrying the light each really scatters, a few fibres as short
// sub-pixel lines, the flakes' brief glints, drifting, rising and swirling in centimetres a
// second in the beam's own volume over the table near the board (beam_box), lit only by the
// sun straight through the glass. Builder 29's round points in a box and its flakes and lint
// were taken out (2026-11-22).
let DUST_WAYS = ["off", "points"];
let DUST_OFF = 0;
let DUST_POINTS = 1;
// Each way's points.
let POINTS_COUNTS: i64[2] = [0, 500];
// The points' light over what a 25 µm flake really scatters (the camera's exposure set for
// the window, the motes that show the larger ones), their forward scattering's g, and their
// fibres' share.
let POINTS_BRIGHT: f32 = 40.0;
let POINTS_AHEAD:  f32 = 0.7;
let POINTS_FIBRES: f32 = 0.15;

// --sun-check: from the board's middle, its field's corners and a ring on the table's top,
// along the key toward the sun, what the ray leaves the room through: a window's niche at
// the wall's inner face, then both casements' glass planes (glass, a bar, or the sash and
// frame), or the wall; as shaders::LIGHT_FN's shell_open traces it. And what the game's
// window (its window_open without the shell) says there: its opening is placed on the line
// from the board's middle to the sun, so it lets the sun on wherever the shell's walls are.
fn casement_at(o: room_shell::Opening, x: f32, y: f32) -> f32, f32 {
    let bar: f32 = 0.024;
    let s = o.sill;
    let h = o.sill + o.height;
    let zt = s + (h - s) * 2.0 / 3.0;
    let gx: f32 = 0.49;
    let ax = abs(x);
    var open = min(gx - ax, min(y - (s + 0.03), (h - 0.06) - y));
    open = min(open, min(abs(y - zt) - 0.045, ax - (0.0175 + 0.05)));
    let upper = y > zt;
    let y0 = if upper { zt + 0.045 } else { s + 0.03 };
    let y1 = if upper { h - 0.06 } else { zt - 0.045 };
    let ax0: f32 = 0.0175 + 0.05;
    let ax1 = gx - 0.055;
    let ay0 = y0 + (if upper { 0.055 } else { 0.08 });
    let ay1 = y1 - 0.055;
    open = min(open, min(ax1 - ax, min(y - ay0, ay1 - y)));
    let frame = open;
    let across: f32 = if upper { 3.0 } else { 1.0 };
    let up:     f32 = if upper { 3.0 } else { 2.0 };
    let pitch_x = (ax1 - ax0 + bar) / across;
    let pitch_y = (ay1 - ay0 + bar) / up;
    let u = ax - ax0 + 0.5 * bar;
    let v = y - ay0 + 0.5 * bar;
    if across > 1.5 && u > 0.5 * pitch_x && u < (across - 0.5) * pitch_x {
        open = min(open, abs(u - pitch_x * floor(u / pitch_x + 0.5)) - 0.5 * bar);
    }
    if v > 0.5 * pitch_y && v < (up - 0.5) * pitch_y { open = min(open, abs(v - pitch_y * floor(v / pitch_y + 0.5)) - 0.5 * bar); }
    return frame, open;
}

// Where the ray from p (the plan's metres, z up from the floor) along d leaves the room:
// the window's number among the shell's (0 the stove's end, 1 the middle, 2 the far end) and
// 0 glass, 1 a bar, 2 the sash or the frame in the niche, 3 the wall, 4 the sun behind the
// wall; and the ray's x along the wall at its inner face.
fn exit_of(p: float3, d: float3) -> i64, i64, f32 {
    let s = room_shell::LIBRARY;
    let face = s.walls[room_shell::WINDOW_WALL].a.y;
    guard d.y > 0.02 else { return -1, 4, 0.0; }
    let t = (face - p.y) / d.y;
    let q = p + d * t;
    var n = 0;
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::WINDOW else { continue; }
        let x = q.x - o.mid;
        if abs(x) < 0.5 * o.width && q.z > o.sill && q.z < room_shell::head_at(o, x) {
            var worst = 0;
            for depth in [o.glass.x, o.glass.y] {
                let g = p + d * ((face + depth - p.y) / d.y);
                let frame, open = casement_at(o, g.x - o.mid, g.z);
                if frame < 0.0 { worst = 2; } else if open < 0.0 && worst < 1 { worst = 1; }
            }
            return n, worst, q.x;
        }
        n++;
    }
    return -1, 3, q.x;
}

// The game's window at p (world units): whether its opening (no bars, no curtain) lets the
// sun on, as window_open without the shell has it.
fn game_window_lets(f: render3d::Frame, p: float3) -> bool {
    let l = float3 { f.light_dir.x, f.light_dir.y, f.light_dir.z };
    let h = normalize(float2 { l.x, l.z });
    let a = radians(f.window.y);
    let nw = float2 { cos(a) * h.x - sin(a) * h.y, sin(a) * h.x + cos(a) * h.y };
    let along = float2 { -nw.y, nw.x };
    let toward = l.x * nw.x + l.z * nw.y;
    guard toward >= 0.05 else { return false; }
    let t = (f.window.x - (p.x * nw.x + p.z * nw.y)) / toward;
    let q = p + l * t;
    let back = f.window.x / toward;
    let wx = (q.x - l.x * back) * along.x + (q.z - l.z * back) * along.y - f.window.w;
    let wy = q.y - f.window.z;
    let size = float2 { f.opening.x * f.panes.x, f.opening.y * f.panes.y };
    return min(size.x * 0.5 - abs(wx), min(wy, size.y - wy)) > 0.0;
}

let EXITS = ["glass", "a bar", "the sash or frame", "the wall", "nothing: the sun is behind the wall"];

fn sun_check(g: render3d::Gpu&, turn: f32, height: f32, loud: bool = true) -> i64, i64 {
    let s = room_shell::LIBRARY;
    let m = surfaces::METRE;
    let f = g.room_frame;
    let l = g.frame.light_dir;
    // The key in the plan: the world's u along the wall and v into the room, both falling
    // as the plan's x and y grow (room_shell::room_of).
    let d = normalize(float3 { -(l.x * f.along.x + l.z * f.along.y), -(l.x * f.into.x + l.z * f.into.y), l.y });
    if loud {
        print("sun-check: the sun ", turn, " degrees across the window wall, ", height, " up; the table's middle at ", s.table.x, ",",
              s.table.y, "; toward the sun in the plan ", d.x, ",", d.y, ",", d.z, "; the board's own z ", board_in_plan(g),
              " degrees from the window wall, the table turned ", g.table_turn, " under it");
    }
    let names = ["the board's middle", "the field's corner -,-", "the field's corner +,-", "the field's corner -,+",
                 "the field's corner +,+"];
    let k = mesh::FIELD;
    let points: float3[5] = [float3_0, float3 { -k, 0.0, -k }, float3 { k, 0.0, -k }, float3 { -k, 0.0, k }, float3 { k, 0.0, k }];
    var board_lit = 0;
    for w, i in points {
        let p = float3 { s.table.x - (w.x * f.along.x + w.z * f.along.y) / m, s.table.y - (w.x * f.into.x + w.z * f.into.y) / m,
                         (w.y - surfaces::FLOOR_Y) / m };
        let n, way, x = exit_of(p, d);
        if way <= 1 && n == 1 { board_lit++; }
        guard loud else { continue; }
        let window: u8[>..] = if n >= 0 { str("window ", n, "'s ") } else { "" };
        print("  ", names[i], " (", p.x, ",", p.y, "): ", window, EXITS[way], " at x ", x, " on the wall's face; the game's window: ",
              if game_window_lets(g.frame, w) { "lets the sun on" } else { "shades it" });
    }
    // The field in 9 × 9 points, lit through the middle window's glass (or a bar's shadow).
    var field = 0;
    for j in 9 {
        for i in 9 {
            let w = float3 { k * (i / 4.0 - 1.0), 0.0, k * (j / 4.0 - 1.0) };
            let p = float3 { s.table.x - (w.x * f.along.x + w.z * f.along.y) / m, s.table.y - (w.x * f.into.x + w.z * f.into.y) / m,
                             (w.y - surfaces::FLOOR_Y) / m };
            let n, way, x = exit_of(p, d);
            if way <= 1 && n == 1 { field++; }
        }
    }
    // A ring on the table's top, each 15 degrees, at three radii.
    var counts:  i64[6] = [0; 6];
    var through: i64[3] = [0; 3];
    var total = 0;
    for ring in 3 {
        let r = mesh::TABLE_R * (0.45 + 0.25 * ring);
        for step in 24 {
            let a: f32 = radians((step as f32) * 15.0);
            let w = float3 { r * cos(a), mesh::TABLE_TOP, r * sin(a) };
            let p = float3 { s.table.x - (w.x * f.along.x + w.z * f.along.y) / m, s.table.y - (w.x * f.into.x + w.z * f.into.y) / m,
                             (w.y - surfaces::FLOOR_Y) / m };
            let n, way, x = exit_of(p, d);
            counts[way]++;
            if way == 0 && n >= 0 { through[n]++; }
            total++;
        }
    }
    guard loud else { return field, counts[0] + counts[1]; }
    print("  the table's top, ", total, " points: through glass ", counts[0], " (windows ", through[0], ", ", through[1], ", ",
          through[2], "), a bar ", counts[1], ", the sash or frame ", counts[2], ", the wall ", counts[3], ", behind ", counts[4]);
    print("sun-check: the board ", board_lit, " of 5 points lit through the middle window (its glass or a bar's shadow); its field ",
          field, " of 81");
    return field, counts[0] + counts[1];
}

// The dust's flags over its preset's settings (the first time a way is shown): its motes
// (returned), and each look.
fn dust_flags(argv: u8[:][>..]&, motes: i64) -> i64 {
    render3d::dust.fibres = number(argv, "--mote-fibres", render3d::dust.fibres);
    render3d::dust.fibre_width = number(argv, "--fibre-width", render3d::dust.fibre_width);
    render3d::dust.bright = number(argv, "--mote-bright", render3d::dust.bright);
    render3d::dust.point_px = number(argv, "--point-px", render3d::dust.point_px);
    render3d::dust.glints = number(argv, "--glints", render3d::dust.glints);
    render3d::dust.air = four(argv, "--air", render3d::dust.air);
    render3d::dust.near = number(argv, "--near", render3d::dust.near);
    return whole(argv, "--motes", motes);
}

// The sunbeam's volume over the table (the new motes' box): from the middle window's
// light toward the board, BEAM_WIDE along the wall, BEAM_HIGH up from the table's top, and
// along the beam BEAM_NEAR short of the board's middle to BEAM_FAR past it (metres),
// sheared as the sun comes in, so a mote at any height is where the sun through the window
// falls. Its low corner and the three axes in the world, and their lengths.
let BEAM_WIDE: f32 = 1.0;
let BEAM_HIGH: f32 = 0.6;
let BEAM_NEAR: f32 = 0.6;
let BEAM_FAR:  f32 = 0.35;
fn beam_box(g: render3d::Gpu&) -> float3, float3, float3, float3 {
    let s = room_shell::LIBRARY;
    let m = surfaces::METRE;
    let f = g.room_frame;
    let l = g.frame.light_dir;
    let d = float2 { -(l.x * f.along.x + l.z * f.along.y), -(l.x * f.into.x + l.z * f.into.y) };
    let e = normalize(float2 { -d.x, -d.y });
    let face = s.walls[room_shell::WINDOW_WALL].a.y;
    let board = (s.table.y - face) / min(e.y, -0.05);
    let r0 = board - BEAM_NEAR;
    var mid:  f32 = s.table.x;
    var best: f32 = 1e9;
    for k in s.count {
        let o = s.openings[k];
        guard o.kind == room_shell::WINDOW else { continue; }
        let x = o.mid + e.x * board;
        if abs(x - s.table.x) < best {
            best = abs(x - s.table.x);
            mid = o.mid;
        }
    }
    let top = (mesh::TABLE_TOP - surfaces::FLOOR_Y) / m + 0.02;
    let o = float3 { mid - 0.5 * BEAM_WIDE + e.x * r0, face + e.y * r0, top };
    let at = plan_point(g, o);
    let u = plan_point(g, o + float3 { BEAM_WIDE, 0.0, 0.0 }) - at;
    let v = plan_point(g, o + float3 { 0.0, 0.0, BEAM_HIGH }) - at;
    let w = plan_point(g, o + float3 { e.x, e.y, 0.0 } * (BEAM_NEAR + BEAM_FAR)) - at;
    return at, u, v, w;
}

// The sky behind the shell's windows, linear: a mid-October afternoon's blue overhead,
// paler and warmer to the horizon, the sun's side lighter.
let SKY_TOP = float4 { 0.36, 0.52, 0.8, 1.0 };
let SKY_LOW = float4 { 0.85, 0.84, 0.8, 1.0 };
let SKY_LIGHT = float4 { 1.0, 0.86, 0.66, 1.0 };

// A point of the room's plan (metres, h up from the floor) in the world, as the room is
// turned now.
fn plan_point(g: render3d::Gpu&, p: float3) -> float3 {
    let r = room_shell::room_of(room_shell::LIBRARY, float2 { p.x, p.y });
    let f = g.room_frame;
    let xz = f.along * r.x + f.into * r.y;
    return float3 { xz.x, surfaces::FLOOR_Y + p.z * surfaces::METRE, xz.y };
}

// The walk round the room (Tab, or the button under Camera and views): WASD and the mouse,
// captured, from a person's eyes 1.6 m up (seated 1.2 m, C); Shift faster; Q goes down and E
// up, flying free; Esc back to the panel. The eye keeps WALL_MARGIN off the plan's walls and
// stays where it is when the walk ends, till R or another view.
let WALK_EYE:   f32 = 1.6;
let SEATED_EYE: f32 = 1.2;
let WALK_SPEED: f32 = 1.4;      // metres a second
let WALK_FAST:  f32 = 2.5;      // times as fast with Shift
let RISE_SPEED: f32 = 1.0;      // metres a second up or down
let LOOK_DEG:   f32 = 0.1;      // degrees a pixel of the mouse
let PITCH_MAX:  f32 = 85.0;
// The views' near plane, 0.39 m out (16-bit depth), reaches 0.58 m at its corners: an eye
// nearer a wall would see through it.
let WALL_MARGIN:  f32 = 0.6;
let LOWEST:       f32 = 0.2;    // the eye's lowest and its highest under the ceiling
let WALK_FOV:     f32 = 60.0;   // the room's views'
let LOOK_AHEAD:   f32 = 2.0;    // metres to the point looked at, for --plan-at
let LONGEST_STEP: f32 = 0.1;    // seconds: a stalled frame doesn't jump

struct Walk {
    on:     bool   = false,
    placed: bool   = false,     // the camera is the walk's, on or off
    eye:    float3 = float3_0,  // the plan's metres, z up from the floor
    yaw:    f32    = 0.0,       // degrees in the plan, 0 along x
    pitch:  f32    = 0.0,
    seated: bool   = false,
}

// The point the walk looks at, in the plan.
fn walk_at(k: Walk) -> float3 {
    let a = radians(k.pitch);
    let b = radians(k.yaw);
    return k.eye + float3 { cos(a) * cos(b), cos(a) * sin(b), sin(a) } * LOOK_AHEAD;
}

// The walk put at a plan view's eye, looking where it looks, a person's eyes high.
fn walk_from(k: Walk&, eye: float3, at: float3) {
    let d = at - eye;
    k.eye = float3 { eye.x, eye.y, if k.seated { SEATED_EYE } else { WALK_EYE } };
    k.yaw = degrees(atan2(d.y, d.x));
    k.pitch = clamp(degrees(atan2(d.z, length(float2 { d.x, d.y }))), -PITCH_MAX, PITCH_MAX);
}

// The walk's one step: the mouse's delta in pixels, the keys held, dt seconds. `hand` is
// +1 when the plan's x and y turn the world's way (screen right is the plan's (-y, x) of
// forward), -1 when mirrored.
fn walk_step(k: Walk&, look: float2, dt: f32, hand: f32, stick: float3 = float3_0) {
    k.yaw -= hand * look.x * LOOK_DEG;
    if k.yaw > 180.0 { k.yaw -= 360.0; }
    if k.yaw < -180.0 { k.yaw += 360.0; }
    k.pitch = clamp(k.pitch - look.y * LOOK_DEG, -PITCH_MAX, PITCH_MAX);
    let b = radians(k.yaw);
    let ahead = float2 { cos(b), sin(b) };
    let right = float2 { ahead.y, -ahead.x } * hand;
    var move = float2_0;
    if gfx::key_down("W") { move += ahead; }
    if gfx::key_down("S") { move -= ahead; }
    if gfx::key_down("D") { move += right; }
    if gfx::key_down("A") { move -= right; }
    move += ahead * stick.y + right * stick.x;
    let fast = gfx::key_down("Left Shift") || gfx::key_down("Right Shift");
    let speed = WALK_SPEED * (if fast { WALK_FAST } else { 1.0 });
    // Two keys at once go no faster than one; a stick part way goes part speed.
    if length(move) > 1.0 { move = normalize(move); }
    move *= speed * dt;
    let s = room_shell::LIBRARY;
    k.eye.x = clamp(k.eye.x + move.x, WALL_MARGIN, s.walls[0].b.x - WALL_MARGIN);
    k.eye.y = clamp(k.eye.y + move.y, WALL_MARGIN, s.walls[0].a.y - WALL_MARGIN);
    var up: f32 = 0.0;
    if gfx::key_down("E") { up += 1.0; }
    if gfx::key_down("Q") { up -= 1.0; }
    up += stick.z;
    k.eye.z = clamp(k.eye.z + up * RISE_SPEED * (if fast { WALK_FAST } else { 1.0 }) * dt, LOWEST, s.ceiling - LOWEST);
}

// The startup's mark while the first bakes run, a frame each (the tree, then the room's
// surfaces, mesh and light; the first frame's pipelines after, under the last mark), so the
// screen isn't black meanwhile: as the app's gui::loading_bar, a thin white bar filled
// `done` from the left over a faint track, without the words, in the middle of a dark screen.
let LOAD_STEPS = 3;
let LOAD_BAR_W: f32 = 216.0;    // ui units, or 60% of the screen where that is less
let LOAD_BAR_H: f32 = 4.0;

fn loading_frame(c: ui::Context, scale: f32, done: f32) {
    let s = gfx::screen_size();
    let r = ui::rect(0.0, 0.0, s.x / scale, s.y / scale);
    // The window past the screen's edges, so its own padding and border don't show.
    if ui::begin(c, "loading", ui::rect(-16.0, -16.0, r.w + 32.0, r.h + 32.0), ui::WINDOW_NO_INPUT | ui::WINDOW_NO_SCROLLBAR) {
        ui::fill_rect(c, r, 0.0, ui::Color { 12, 12, 12, 255 });
        let w = floor(min(LOAD_BAR_W, 0.6 * r.w));
        let x = floor(0.5 * (r.w - w));
        let y = floor(0.5 * (r.h - LOAD_BAR_H));
        ui::fill_rect(c, ui::rect(x, y, w, LOAD_BAR_H), 0.5 * LOAD_BAR_H, ui::Color { 255, 255, 255, 46 });
        if done > 0.0 { ui::fill_rect(c, ui::rect(x, y, max(floor(w * done + 0.5), LOAD_BAR_H), LOAD_BAR_H), 0.5 * LOAD_BAR_H, ui::Color { 255, 255, 255, 230 }); }
    }
    ui::end(c);
    ui::render(c);
}

// The touch walk (--touch): one finger at a time, as gfx gives touches as the mouse. A
// finger put down on the left half is a stick from where it went down; on the right half a
// drag that looks; on Up or Down, at the right edge, it rises or sinks while held.
let TOUCH_NONE = 0;
let TOUCH_MOVE = 1;
let TOUCH_LOOK = 2;
let TOUCH_UP = 3;
let TOUCH_DOWN = 4;
let STICK_REACH: f32 = 0.15;    // of the screen's height, the stick's full speed
let BUTTON_SIDE: f32 = 0.14;    // of the screen's height, Up's and Down's

struct Touch {
    zone:  i64    = 0,          // TOUCH_NONE..
    start: float2 = float2_0,   // where the finger went down, pixels
}

// Up's and Down's boxes in pixels: x, y, side.
fn touch_buttons(size: int2) -> float3, float3 {
    let side = size.y * BUTTON_SIDE;
    let x = size.x - side * 1.2;
    let mid = size.y * 0.5;
    return float3 { x, mid - side * 1.1, side }, float3 { x, mid + side * 0.1, side };
}

fn inside(p: float2, b: float3) -> bool { p.x >= b.x && p.x < b.x + b.z && p.y >= b.y && p.y < b.y + b.z }

// This frame's look (pixels, as the mouse's delta) and stick.
fn touch_step(t: Touch&, size: int2) -> float2, float3 {
    let p = gfx::mouse_pos();
    let up, down = touch_buttons(size);
    if gfx::mouse_pressed(gfx::MOUSE_LEFT) {
        t.zone = if inside(p, up) { TOUCH_UP } else if inside(p, down) { TOUCH_DOWN }
                 else if p.x < size.x * 0.5 { TOUCH_MOVE } else { TOUCH_LOOK };
        t.start = p;
        return float2_0, float3_0;   // the finger's jump from the last place isn't a look
    }
    if !gfx::mouse_down(gfx::MOUSE_LEFT) { t.zone = TOUCH_NONE; }
    if t.zone == TOUCH_LOOK { return gfx::mouse_delta(), float3_0; }
    if t.zone == TOUCH_UP { return float2_0, float3 { 0.0, 0.0, 1.0 }; }
    if t.zone == TOUCH_DOWN { return float2_0, float3 { 0.0, 0.0, -1.0 }; }
    if t.zone == TOUCH_MOVE {
        var d = (p - t.start) / (size.y * STICK_REACH);
        if length(d) > 1.0 { d = normalize(d); }
        return float2_0, float3 { d.x, -d.y, 0.0 };
    }
    return float2_0, float3_0;
}

// A mid-game position, dark on the far rows: (row, col, dark), row 0 the far side.
let PIECES: i32[3][12] = [
    [0, 1, 1], [0, 5, 1], [1, 2, 1], [1, 6, 1], [2, 3, 1], [3, 4, 1],
    [4, 1, 0], [5, 2, 0], [5, 6, 0], [6, 3, 0], [7, 0, 0], [7, 4, 0],
];

// What the tuner shows besides the layout.
struct Setup {
    taken: panel::Taken = panel::Taken { men: [9, 7], kings: [1, 2] },
    n:     i64          = 0,    // SQUARES's
    flip:  bool         = false,
    look:  i64          = 0,    // KING_LOOKS's
    // The pieces' halo on the field (shaders::OCC_FRAG): its strength and reach, 0 the
    // shader's HALO and HALO_REACH (--halo, --halo-reach, the Table section).
    halo: float2 = float2_0,
}

// The frame counter (F): frames a second, the frame's time from one frame to the next,
// its mean and worst, and the time in the loop before the frame is submitted (the CPU's
// work and any wait for the GPU in it; with G all the GPU's work, waited for), each over
// half a second. The tuner draws every frame; a gap of over half a second (the window
// hidden) shows as idle until a new half second is measured.
let METER_WINDOW: f64 = 0.5;

struct Meter {
    on:       bool = true,
    wait:     bool = false, // each frame waited for, as --bench's first phase: CPU and GPU
    start:    f64  = 0.0,   // the window's start
    last:     f64  = 0.0,   // the last frame's start
    frames:   i64  = 0,
    sum:      f64  = 0.0,   // seconds, frame to frame
    worst:    f64  = 0.0,
    in_loop:  f64  = 0.0,   // seconds in the loop before the submit
    idle_for: f64  = 0.0,   // the last gap, while no window is measured since
    fps:      f64  = 0.0,   // the last window's
    mean_ms:  f64  = 0.0,
    worst_ms: f64  = 0.0,
    loop_ms:  f64  = 0.0,
    measured: bool = false,
}

// A new frame begins at `now`: false when it closed a half second's window.
fn meter_frame(m: Meter&, now: f64) -> bool {
    let dt = now - m.last;
    let first = m.last == 0.0;
    m.last = now;
    if first || dt > METER_WINDOW {
        if !first { m.idle_for = dt; }
        m.measured = false;
        m.start = now;
        m.frames = 0;
        m.sum = 0.0;
        m.worst = 0.0;
        m.in_loop = 0.0;
        return false;
    }
    m.frames += 1;
    m.sum += dt;
    m.worst = max(m.worst, dt);
    guard now - m.start >= METER_WINDOW else { return false; }
    m.fps = m.frames as f64 / (now - m.start);
    m.mean_ms = 1000.0 * m.sum / m.frames as f64;
    m.worst_ms = 1000.0 * m.worst;
    m.loop_ms = 1000.0 * m.in_loop / m.frames as f64;
    m.measured = true;
    m.start = now;
    m.frames = 0;
    m.sum = 0.0;
    m.worst = 0.0;
    m.in_loop = 0.0;
    return true;
}

fn tenths(out: u8[..96]&, v: f64) { format(out, floor(v * 10.0 + 0.5) / 10.0); }

// The counter's two lines into `a` and `b`, which the caller owns.
fn meter_text(m: Meter&, a: u8[..96]&, b: u8[..96]&, still: bool) {
    a.clear();
    b.clear();
    if !m.measured {
        if m.idle_for > 0.0 {
            format(a, "idle: nothing drawn for ");
            tenths(a, m.idle_for);
            a.append(" s");
        } else { a.append("measuring"); }
        return;
    }
    tenths(a, m.fps);
    a.append(" fps, ");
    tenths(a, m.mean_ms);
    a.append(" ms a frame, worst ");
    tenths(a, m.worst_ms);
    b.append("in the loop ");
    tenths(b, m.loop_ms);
    b.append(if m.wait { " ms, the GPU waited for" } else { " ms, waits too; no GPU timer" });
    if still { b.append(", the scene still"); }
}

fn squares_of(st: Setup) -> i64 { if st.n == 1 { 10 } else { 8 } }

// The board's pieces and the table's, put on the GPU.
fn place(r3d: render3d::Own&, g: render3d::Gpu&, st: Setup) {
    var s = view3d::Scene {};
    var squares: float4[200] = [float4_0; 200];
    var marks:   float4[100] = [float4 { 0.0, 0.0, 0.0, -1.0 }; 100];
    var lit:     float4[100] = [float4_0; 100];
    var fades:   f32[1]      = [0.0];
    let n = squares_of(st);
    let u = view3d::unit(n);
    for p, i in PIECES {
        let x = (p[1] + 0.5) * u - view3d::FIELD;
        let z = (p[0] + 0.5) * u - view3d::FIELD;
        let dark: f32 = if (p[2] == 1) != st.flip { 1.0 } else { 0.0 };
        s.inst.push(float4 { x, 0.0, z, u });
        s.inst.push(float4 { dark, 0.0, 0.0, i });
        squares[2 * (p[0] * n + p[1])] = float4 { view3d::HEIGHT * u, 0.0, view3d::RADIUS * u, 1.0 };
        squares[2 * (p[0] * n + p[1]) + 1] = float4 { x, z, st.halo.x, st.halo.y };
    }
    taken3d::lay_counts(s, st.taken, n, st.flip, if st.look == 1 { board::STACK } else { board::CROWN });
    render3d::place(r3d, g, s.inst[..s.inst.len], fades[..0], squares[..], marks[..], lit[..], float4_0, 0.0, true);
    render3d::table_discs(g, s.discs[..], s.disc_r);
}

// place(), for main, where `place` is the placement's number.
fn place_pieces(r3d: render3d::Own&, g: render3d::Gpu&, st: Setup) { place(r3d, g, st); }

// The season's look in the material, its wood and finish as the app picks them
// (draw3d::choose_look), baked with the table.
fn put_look(r3d: render3d::Own&, g: render3d::Gpu&, season: i64, material: i64, st: Setup) {
    let look = looks::of(season, material);
    if look == looks::SPRING { g.spring = 0; }
    let shown = looks::shown(look, g.spring);
    let own = looks::wood_for(shown);
    render3d::choose(g, if own >= 0 { own } else { model3d::WOOD_MODEL }, -1);
    g.finish = looks::finish_for(shown, g.wood);
    g.look = -1;
    render3d::apply(r3d, g, look, squares_of(st));
    place(r3d, g, st);
}

fn num(out: u8[>..]&, v: f32) {
    let k = floor(v * 1000.0 + 0.5) / 1000.0;
    format(out, k);
}

// The command that shows the same again, and the layout as a Goose literal for

fn slider(c: ui::Context, name: const u8[:], v: f32&, lo: f32, hi: f32) {
    let ratios: f32[2] = [0.5, 0.5];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    var text: u8[>..] = [];
    text.append(name);
    text.push(' ');
    num(text, v);
    ui::label(c, text, ui::TEXT_LEFT);
    ui::slider_float(c, lo, v, hi, (hi - lo) / 400.0);
}

fn count(c: ui::Context, name: const u8[:], v: i64&, lo: i64, hi: i64) {
    let ratios: f32[2] = [0.5, 0.5];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    ui::label(c, str(name, " ", v), ui::TEXT_LEFT);
    ui::slider_int(c, lo, v, hi, 1);
}

fn choice(c: ui::Context, name: const u8[:], v: i64&, names: const u8[:][]) {
    let ratios: f32[2] = [0.5, 0.5];
    ui::layout_row(c, ui::DYNAMIC, ROW, ratios);
    ui::label(c, str(name, " ", names[v]), ui::TEXT_LEFT);
    ui::slider_int(c, 0, v, names.len - 1, 1);
}

fn flag_value(argv: u8[:][>..]&, name: const u8[:]) -> i64 {
    for a, i in argv { if a == name && i + 1 < argv.len { return i + 1; } }
    return -1;
}

fn has(argv: u8[:][>..]&, name: const u8[:]) -> bool {
    for a in argv { if a == name { return true; } }
    return false;
}

fn pick(argv: u8[:][>..]&, name: const u8[:], names: const u8[:][], otherwise: i64) -> i64 {
    let at = flag_value(argv, name);
    if at < 0 { return otherwise; }
    for n, i in names { if argv[at] == n { return i; } }
    abort(str(name, ": no ", argv[at]));
    return otherwise;
}

// The flag's four numbers, `x,y,z,w`, or `otherwise`.
fn four(argv: u8[:][>..]&, name: const u8[:], otherwise: float4) -> float4 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    var v:    f32[4]      = [otherwise.x, otherwise.y, otherwise.z, otherwise.w];
    var rest: const u8[:] = argv[at];
    for i in 4 {
        let part, after, more = split_once(rest, ",");
        let x, ok = parse_flt(part);
        guard ok else { abort(str(name, ": four numbers, x,y,z,w")); }
        v[i] = x as f32;
        guard more else { break; }
        rest = after;
    }
    return float4 { v[0], v[1], v[2], v[3] };
}

// The flag's number, or `otherwise`.
fn number(argv: u8[:][>..]&, name: const u8[:], otherwise: f32) -> f32 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    let v, ok = parse_flt(argv[at]);
    guard ok else { abort(str(name, ": a number")); }
    return v as f32;
}

fn whole(argv: u8[:][>..]&, name: const u8[:], otherwise: i64) -> i64 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    let v, ok = parse_int(argv[at]);
    guard ok else { abort(str(name, ": a whole number")); }
    return v;
}

// --white-took MEN,KINGS: the men and kings of color c taken, into t.

fn room_line(out: u8[>..]&, name: const u8[:], v: float4) {
    out.append("    ");
    out.append(name);
    out.append(": float4 { ");
    num(out, v.x);
    out.append(", ");
    num(out, v.y);
    out.append(", ");
    num(out, v.z);
    out.append(", ");
    num(out, v.w);
    out.append(" },\n");
}

// The room as a Goose literal for rooms.goose.
fn report(r: rooms::Room, take: i64, flags: const u8[:]) {
    var out: u8[>..] = [];
    format(out, "// ", rooms::NAMES[take], ", the wind's kind ", rooms::WIND_KINDS[render3d::wind_kind], "\nRoom {\n");
    room_line(out, "key:       ", r.key);
    room_line(out, "key_color: ", r.key_color);
    room_line(out, "fill:      ", r.fill);
    room_line(out, "fill_color:", r.fill_color);
    room_line(out, "walls:     ", r.walls);
    room_line(out, "ceiling:   ", r.ceiling);
    room_line(out, "floor:     ", r.floor);
    room_line(out, "lamp:      ", r.lamp);
    room_line(out, "lamp_color:", r.lamp_color);
    out.append("    exposure:   ");
    num(out, r.exposure);
    out.append(",\n    tree_blur:  ");
    num(out, r.tree_blur);
    out.append(",\n    crown_blur: ");
    num(out, r.crown_blur);
    out.append(",\n    crown_fill: ");
    num(out, r.crown_fill);
    format(out, ",\n    species:    ", r.species, ", // ", trees::SPECIES_NAMES[r.species], "\n");
    room_line(out, "pattern:   ", r.pattern);
    room_line(out, "window:    ", r.window);
    room_line(out, "panes:     ", r.panes);
    room_line(out, "opening:   ", r.opening);
    room_line(out, "leaves:    ", r.leaves);
    room_line(out, "twigs:     ", r.twigs);
    room_line(out, "wind:      ", r.wind);
    room_line(out, "gust:      ", r.gust);
    room_line(out, "tree:      ", r.tree);
    room_line(out, "crown:     ", r.crown);
    room_line(out, "foliage:   ", r.foliage);
    room_line(out, "bounce:    ", r.bounce);
    out.append("    room_exposure: ");
    num(out, r.room_exposure);
    out.append(",\n    outside:       ");
    num(out, r.outside);
    out.append(",\n");
    room_line(out, "shell_sun: ", r.shell_sun);
    room_line(out, "baked:     ", r.baked);
    room_line(out, "bloom:     ", r.bloom);
    room_line(out, "corners:   ", r.corners);
    room_line(out, "ssao:      ", r.ssao);
    room_line(out, "planar:    ", r.planar);
    out.append("};\n// The flags that show the same again (the room's colours, twigs, species and crown in\n");
    out.append("// the literal above):\n");
    out.append(flags);
    print(out);
    // Also kept in a file, as a window's tool has no terminal to read.
    if write_file("../build/light-tune.txt", out[..]) { print("saved in build/light-tune.txt"); }
}

// A square texture's first level as a binary PPM, its alpha left out.
fn dump_rgb(t: gfx::Texture, side: i64, path: const u8[:]) {
    let px = gfx::read_pixels(t);
    var out: u8[>..] = [];
    format(out, "P6\n", side, " ", side, "\n255\n");
    for i in side * side {
        out.push(px[4 * i]);
        out.push(px[4 * i + 1]);
        out.push(px[4 * i + 2]);
    }
    guard write_file(path, out[..]) else { abort(str("could not write ", path)); }
}

fn on_off(v: bool) -> const u8[:] { if v { "on" } else { "off" } }

fn flag_four(out: u8[>..]&, name: const u8[:], v: float4) {
    format(out, " ", name, " ");
    format(out, v.x);
    out.push(',');
    format(out, v.y);
    out.push(',');
    format(out, v.z);
    out.push(',');
    format(out, v.w);
}

fn flag_pair(out: u8[>..]&, name: const u8[:], v: float2) {
    format(out, " ", name, " ");
    format(out, v.x);
    out.push(',');
    format(out, v.y);
}

fn flag_one(out: u8[>..]&, name: const u8[:], v: f32) {
    format(out, " ", name, " ");
    format(out, v);
}

// The room's values that have flags.
fn room_flags(out: u8[>..]&, r: rooms::Room) {
    flag_four(out, "--key", r.key);
    flag_four(out, "--fill", r.fill);
    flag_four(out, "--walls", r.walls);
    flag_four(out, "--pattern", r.pattern);
    flag_four(out, "--bounce", r.bounce);
    flag_four(out, "--wall", r.window);
    flag_four(out, "--panes", r.panes);
    flag_four(out, "--opening", r.opening);
    flag_four(out, "--tree", r.tree);
    flag_four(out, "--crown", r.crown);
    flag_four(out, "--foliage", r.foliage);
    flag_four(out, "--trees", r.leaves);
    flag_four(out, "--wind", r.wind);
    flag_four(out, "--gust", r.gust);
    flag_four(out, "--shell-sun", r.shell_sun);
    flag_four(out, "--baked", r.baked);
    flag_four(out, "--bloom", r.bloom);
    flag_four(out, "--corners", r.corners);
    flag_four(out, "--ssao", r.ssao);
    flag_four(out, "--planar", r.planar);
    flag_one(out, "--exposure", r.exposure);
    flag_one(out, "--room-exposure", r.room_exposure);
    flag_one(out, "--outside-exposure", r.outside);
    flag_one(out, "--tree-blur", r.tree_blur);
}

// The panel's sections, each a tab that opens and closes (its state kept for the session),
// and the parts inside Light and Sun and tree; their names for --sections, and which are
// open at the start.
let SECTIONS = ["Scene", "Light", "Sun and tree", "Wallpaper", "Wainscot and panelling", "Ceiling", "Curtains and lace",
                "Bookcases and books", "Table", "Outside", "Dust in the sunbeam (D)", "Camera and views", "Debug", "Keys",
                "Lens and depth of field", "Light in detail (the board's)", "The sun", "The tree", "Wind", "The board's window", "Noise leaves"];
let SECTION_NAMES = ["scene", "light", "sun", "wallpaper", "wainscot", "ceiling", "curtains", "books", "table", "outside", "dust",
                     "camera", "debug", "keys", "lens", "detail", "sun-itself", "tree", "wind", "window", "noise"];
let OPEN_AT_START: i64[21] = [1, 1, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0];
let PARTS_FROM = 15;
let SCENE = 0;
let LIGHT = 1;
let SUN = 2;
let WALLPAPER = 3;
let WAINSCOT = 4;
let CEILING = 5;
let CURTAINS = 6;
let BOOKS = 7;
let TABLE = 8;
let OUTSIDE = 9;
let DUST = 10;
let CAMERA = 11;
let DEBUG = 12;
let KEYS = 13;
let LENS = 14;
let DETAIL = 15;
let SUN_ITSELF = 16;
let TREE = 17;
let WIND = 18;
let WINDOW = 19;
let NOISE = 20;

let KEY_HELP = ["drag: orbit, scroll: zoom", "R: reset the orbit and the view", "P: print the room and its flags",
                "V: the views in turn", "U: the park or a plain sky outside",
                "L: the wallpaper's tile, 0.65, 0.9 or 1.4 m", "C: the lace's way; B: the books; H: the shutters", "W: the window's pattern; T: leaves by",
                "K: the wind's kind; D: the dust's way", "Y: the lace's hang, 0.15 or 0 m", "Z: the window view's steps off or on", "F: the frame counter; G: wait for the GPU",
                "N: the scene's scale; M: its upscale", "X: HDR or 8 bits; 1: the lens's views; 2: MSAA or SMAA",
                "A: the sun's and table's placements in turn (Table)",
                "Tab: walk; Esc: back to the panel", "walking: WASD, the mouse, Shift faster",
                "walking: C seated, Q down, E up", "R: back to the view, P: the walk's camera"];

// The sections open at the start: OPEN_AT_START, or --sections NAME,NAME.. (or all).
fn open_sections(argv: u8[:][>..]&) -> i64[21] {
    var open = OPEN_AT_START;
    let at = flag_value(argv, "--sections");
    guard at > 0 else { return open; }
    let all = argv[at] == "all";
    for i in 21 { open[i] = if all { ui::MAXIMIZED } else { ui::MINIMIZED }; }
    guard !all else { return open; }
    var rest: const u8[:] = argv[at];
    while rest.len > 0 {
        let part, after, more = split_once(rest, ",");
        var found = false;
        for n, i in SECTION_NAMES {
            if n == part {
                open[i] = ui::MAXIMIZED;
                found = true;
            }
        }
        guard found else { abort(str("--sections: no ", part)); }
        guard more else { break; }
        rest = after;
    }
    return open;
}

// A section's tab (or a part's node inside one): true while open, when tree_state_pop follows.
fn section(c: ui::Context, open: i64[21]&, i: i64) -> bool {
    let kind = if i >= PARTS_FROM { ui::TREE_NODE } else { ui::TREE_TAB };
    return ui::tree_state_push(c, kind, SECTIONS[i], open[i]);
}

fn switch(c: ui::Context, name: const u8[:], v: bool&, names: const u8[:][2]) {
    var k: i64 = if v { 1 } else { 0 };
    choice(c, name, k, names);
    v = k == 1;
}

fn note(c: ui::Context, text: const u8[:]) {
    ui::layout_row_dynamic(c, ROW, 1);
    ui::label(c, text, ui::TEXT_LEFT);
}

fn color_sliders(c: ui::Context, name: const u8[:], v: float4&) {
    slider(c, str(name, " r"), v.x, 0.0, 1.0);
    slider(c, str(name, " g"), v.y, 0.0, 1.0);
    slider(c, str(name, " b"), v.z, 0.0, 1.0);
}

// --walk-test N: the walk driven by injected input for N frames (WALK_TEST_END the whole
// path), each step 1/60 s, and a --shot taken where it ends: into the walk (Tab), W for a
// second, the mouse turned right and down, D with E (up), Shift and W for 2.4
// seconds into the stove's end, C, out (Esc), and P.
let WALK_TEST_END = 265;

fn walk_test_input(frame: i64) {
    match frame {
        2 => { gfx::inject_mouse(400.0, 300.0, 0, false); },
        3 => { gfx::inject_key("Tab", true); },
        4 => { gfx::inject_key("Tab", false); },
        6 => { gfx::inject_key("W", true); },
        66 => { gfx::inject_key("W", false); },
        70 => { gfx::inject_mouse(700.0, 350.0, 0, false); },
        72 => {
            gfx::inject_key("D", true);
            gfx::inject_key("E", true);
        },
        102 => {
            gfx::inject_key("D", false);
            gfx::inject_key("E", false);
        },
        105 => {
            gfx::inject_key("Left Shift", true);
            gfx::inject_key("W", true);
        },
        250 => {
            gfx::inject_key("Left Shift", false);
            gfx::inject_key("W", false);
        },
        253 => { gfx::inject_key("C", true); },
        254 => { gfx::inject_key("C", false); },
        257 => { gfx::inject_key("Escape", true); },
        258 => { gfx::inject_key("Escape", false); },
        261 => { gfx::inject_key("P", true); },
        262 => { gfx::inject_key("P", false); },
        _ => {},
    }
}

// --walk-frames: the walk begun at frame 3 (Tab), the path from WALK_PATH_START, each
// frame after it saved.
let WALK_PATHS = ["strafe", "turn", "forward"];
let WALK_PATH_START = 8;
fn walk_path_input(frame: i64, path: i64, turn: i64) {
    if frame == 2 { gfx::inject_mouse(400.0, 300.0, 0, false); }
    if frame == 3 { gfx::inject_key("Tab", true); }
    if frame == 4 { gfx::inject_key("Tab", false); }
    guard frame >= WALK_PATH_START else { return; }
    if path == 0 && frame == WALK_PATH_START { gfx::inject_key("D", true); }
    if path == 2 && frame == WALK_PATH_START { gfx::inject_key("W", true); }
    if path == 1 { gfx::inject_mouse((400 + turn * (frame - WALK_PATH_START + 1)) as f32, 300.0, 0, false); }
}

// --dump-glass-tile PREFIX (the window view's W8 and W9, no window opened): the glass's
// wiping tile (model3d's glass_tile) as PREFIX-film.pgm (the film's thickness),
// PREFIX-scratches.pgm (their depth), and PREFIX-lit.ppm, a 36 × 52 cm pane seen toward
// the sun three times over a warm ground, the sun's image low left, upper right and far
// off, the film and the glints about three times as strong as meant.
fn dump_glass_tile(prefix: const u8[:]) {
    var tile: u8[>..] = [];
    glass_tile::make(7, glass_tile::Strokes {}, tile);
    let n = glass_tile::SIDE;
    var film:  u8[>..] = [];
    var marks: u8[>..] = [];
    format(film, "P5\n", n, " ", n, "\n255\n");
    format(marks, "P5\n", n, " ", n, "\n255\n");
    for i in n * n {
        film.push(tile[i * 4 + 3]);
        marks.push(tile[i * 4 + 2]);
    }
    guard write_file(str(prefix, "-film.pgm"), film[..]) && write_file(str(prefix, "-scratches.pgm"), marks[..]) else {
        abort("could not write the tile");
    }
    let w = 360;
    let h = 520;
    let suns: float2[3] = [float2 { -150.0, 200.0 }, float2 { 250.0, 350.0 }, float2 { 0.0, -2000.0 }];
    var lit: u8[>..] = [];
    format(lit, "P6\n", 3 * w, " ", h, "\n255\n");
    for j in h {
        for k in 3 {
            for i in w {
                let x = glass_tile::lit_at(tile, i, j, w, h, suns[k], 0.25, 1.5);
                let c:     f32[3] = [0.55 + x, 0.45 + 0.95 * x, 0.25 + 0.85 * x];
                let gamma: f32    = 1.0 / 2.2;
                for e in 3 { lit.push((pow(clamp(c[e], 0.0, 1.0), gamma) * 255.0 + 0.5) as u8); }
            }
        }
    }
    guard write_file(str(prefix, "-lit.ppm"), lit[..]) else { abort("could not write the preview"); }
}

fn main() {
    let argv = args();
    let capture = flag_value(argv, "--gpu-capture");
    let capturing = capture > 0;
    if has(argv, "--gpu-capture") {
        guard capturing && starts_with(argv[capture], "/") && ends_with(argv[capture], ".gputrace") else {
            abort("--gpu-capture needs an absolute .gputrace path");
        }
        guard !has(argv, "--shot") && !has(argv, "--fps-seconds") else {
            abort("--gpu-capture runs on its own, without --shot or --fps-seconds");
        }
    }
    let tile_at = flag_value(argv, "--dump-glass-tile");
    if tile_at > 0 {
        dump_glass_tile(argv[tile_at]);
        return;
    }
    let on_phone = draughts_platform() != 0;   // Android or iOS
    let touch = if has(argv, "--touch") { argv[flag_value(argv, "--touch")] == "on" } else { on_phone };
    let phone_tier = has(argv, "--phone-tier") || (touch && !(has(argv, "--tier") && argv[flag_value(argv, "--tier")] == "full"));
    var w = 1600;
    var h = 1000;
    let si = flag_value(argv, "--size");
    if si > 0 {
        let a, b, ok = split_once(argv[si], "x");
        let x, okx = parse_int(a);
        let y, oky = parse_int(b);
        guard ok && okx && oky else { abort("--size: WxH"); }
        w = x;
        h = y;
    }
    var season = pick(argv, "--season", SEASONS, looks::AUTUMN);
    var material = pick(argv, "--material", MATERIALS, looks::MATERIAL_AUTO);
    var take = pick(argv, "--table", tables::NAMES, tables::FLAME);
    var room_take = rooms::for_season(season);
    var pattern: i64 = if flag_value(argv, "--window") > 0 && argv[flag_value(argv, "--window")] == "off" { 0 } else { 1 };
    var st = Setup {};
    st.halo = float2 { number(argv, "--halo", 0.0), number(argv, "--halo-reach", 0.0) };
    var shown_halo = st.halo;
    taken3d::table_layout = taken3d::TABLE_LAYOUTS[taken3d::TOWERS];
    draughts_choose_gpu();   // Vulkan on Windows, as the app draws
    tuner_landscape();
    let vsync = if has(argv, "--no-vsync") { gfx::NO_VSYNC } else { 0 };
    guard gfx::open("Draughts: the room's light", w, h, gfx::WINDOW_RESIZABLE | vsync) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();
    // On a phone the whole screen, the status and navigation bars hidden, as the benches
    // frame it; the app itself keeps the bars (platform/android/res's theme).
    if on_phone { set_fullscreen(true); }
    if capturing {
        guard gfx::driver() == "metal" else { abort("--gpu-capture requires the Metal backend"); }
    }

    var g = default<render3d::Gpu>();
    var r3d = default<render3d::Own>();
    // The park on the ground outside (--park): the view out's mesh with the lawn and the
    // trees' cards, its shaders the park's; autumn's leaves only in autumn.
    let park = pick(argv, "--park", PARK_NAMES, 0);
    if park > 0 {
        let part = if season != looks::AUTUMN && park == 1 { PARK_NO_LEAVES } else { park };
        render3d::park_ground = true;
        render3d::tuned_frags[render3d::TUNED_OUTSIDE] = park_frag(part, false);
        render3d::tuned_frags[render3d::TUNED_OUTSIDE_HDR] = park_frag(part, true);
    }
    render3d::setup(r3d, g, render3d::SAMPLES, if phone_tier { render3d::SHADOW_4 } else { render3d::SHADOW_16 });
    // --aa off|smaa|msaa: the scene's antialiasing, SMAA by default in the room (task 115:
    // cheaper on the tablet, the Pixel and the 4090; the app's board alone keeps 4× MSAA,
    // render3d::AA).
    let aa_way = pick(argv, "--aa", AA_NAMES, 1);
    render3d::set_aa(r3d, g, AA_WAYS[aa_way]);
    render3d::choose(g, -1, looks::MARBLE, looks::SPRING_LOOK);
    render3d::scatter_allowed = true;
    g.table = true;
    // --light physical: the table's sun the same all over (no pool round the board).
    let physical = pick(argv, "--light", LIGHT_WAYS, 0) == 1;
    casement_depth = !(flag_value(argv, "--casement-depth") > 0 && argv[flag_value(argv, "--casement-depth")] == "off");
    g.table_spec = tables::get(take);
    if physical { g.table_spec.light.y = 1.0; }
    // --light physical: one camera curve for the whole picture after the HDR pass, the
    // surfaces writing their light linear: --camera-toe's, AgX at the metered exposure
    // compensated by --camera-ev unless it names a toe.
    if physical {
        render3d::tone_toe = float4 { 2.0, 2.0, 2.0, render3d::tone_toe.w };
        render3d::camera_toe = pick(argv, "--camera-toe", TOES, CAMERA_TOE) as f32;
        render3d::camera_ev = number(argv, "--camera-ev", 0.0);
    }
    var room = rooms::get(room_take);
    room.key.x = number(argv, "--azimuth", room.key.x);
    room.key.y = number(argv, "--sun-height", room.key.y);
    let shade_at = flag_value(argv, "--leaves");
    if shade_at > 0 { room.tree.x = if argv[shade_at] == "noise" { 0.0 } else if argv[shade_at] == "both" { 2.0 } else { 1.0 }; }
    room.tree.y = number(argv, "--seed", room.tree.y);
    room.tree = four(argv, "--tree", room.tree);
    room.crown = four(argv, "--crown", room.crown);
    room.foliage = four(argv, "--foliage", room.foliage);
    room.leaves = four(argv, "--trees", room.leaves);
    room.window = four(argv, "--wall", room.window);
    room.panes = four(argv, "--panes", room.panes);
    room.opening = four(argv, "--opening", room.opening);
    room.wind = four(argv, "--wind", room.wind);
    room.gust = four(argv, "--gust", room.gust);
    room.gust.x = number(argv, "--gust-strength", room.gust.x);
    room.gust.y = number(argv, "--gust-length", room.gust.y);
    room.gust.z = number(argv, "--gust-every", room.gust.z);
    room.gust.w = number(argv, "--gust-reach", room.gust.w);
    room.key = four(argv, "--key", room.key);
    room.fill = four(argv, "--fill", room.fill);
    room.walls = four(argv, "--walls", room.walls);
    room.pattern = four(argv, "--pattern", room.pattern);
    room.bounce = four(argv, "--bounce", room.bounce);
    room.room_exposure = number(argv, "--room-exposure", room.room_exposure);
    room.shell_sun = four(argv, "--shell-sun", room.shell_sun);
    room.baked = four(argv, "--baked", room.baked);
    room.bloom = four(argv, "--bloom", room.bloom);
    room.corners = four(argv, "--corners", room.corners);
    room.ssao = four(argv, "--ssao", room.ssao);
    render3d::ssao_view = pick(argv, "--ssao-view", SSAO_VIEWS, 0);
    // A phone's tier (the app's): the room's pipelines without the screen's maps, no mirror.
    render3d::sharp_box_allowed = !(has(argv, "--box") && argv[flag_value(argv, "--box")] == "off");
    // The window's light map (render3d::window_map_on), or the windows traced a pixel as before;
    // the phone's tier's leaves baked into it still, or none.
    render3d::window_map_on = !(has(argv, "--window-map") && argv[flag_value(argv, "--window-map")] == "off");
    // The phone's tier's room shaders with the room's block as constants (render3d::room_fixed_on).
    render3d::room_fixed_on = !(has(argv, "--room-fixed") && argv[flag_value(argv, "--room-fixed")] == "off");
    // The phone tier's sharp box from the box's map (render3d::box_map_on).
    render3d::box_map_on = !(has(argv, "--box-map") && argv[flag_value(argv, "--box-map")] == "off");
    render3d::phone_leaves = if has(argv, "--phone-leaves") && argv[flag_value(argv, "--phone-leaves")] == "off" { render3d::LEAVES_OFF }
                             else { render3d::LEAVES_STATIC };
    let leaves_moving_flag = has(argv, "--leaves-moving") && argv[flag_value(argv, "--leaves-moving")] == "on";
    if phone_tier {
        render3d::ssao_allowed = false;
        render3d::planar_allowed = false;
    }
    room.planar = four(argv, "--planar", room.planar);
    render3d::planar_view = pick(argv, "--planar-view", PLANAR_VIEWS, 0);
    render3d::planar_scale = whole(argv, "--planar-size", 3) as i32;
    render3d::planar_least_wide = whole(argv, "--planar-wide", 1600) as i32;
    render3d::mirror_cheap = flag_value(argv, "--mirror-cheap") > 0 && argv[flag_value(argv, "--mirror-cheap")] == "on";
    render3d::ssao_gtao = !(flag_value(argv, "--gtao") > 0 && argv[flag_value(argv, "--gtao")] == "off");
    render3d::gtao_power = number(argv, "--gtao-power", 1.5);
    // Native unless --scene-scale or --scene-pixels asks for less (N cycles them).
    var scene_k = number(argv, "--scene-scale", if has(argv, "--scene-pixels") { 0.0 } else { 1.0 });
    let scene_budget = number(argv, "--scene-pixels", render3d::HIGH_SCENE_PIXELS / 1.0e6) * 1.0e6;
    var upscale = pick(argv, "--upscale", UPSCALES, 0);
    room.outside = number(argv, "--outside-exposure", room.outside);
    room.tree_blur = number(argv, "--tree-blur", room.tree_blur);
    room.exposure = number(argv, "--exposure", room.exposure);
    var motes = whole(argv, "--motes", 500);
    render3d::light_bounces = whole(argv, "--bounces", room_light::BOUNCES);
    // The panels' rings (at the start only: the mesh): their occlusion's strength, the dip's
    // width in cm up the bevel (0 across it), the crease, the bevel's width ×; the bounce's
    // greying, the lace as a source, the probes' spread; the sun's contact shadows, broad
    // sheen, saturation on the room and the panelling oak's own share of it.
    let panel_ao = four(argv, "--panel-ao", float4 { surfaces::panel_ao_scale, surfaces::panel_ao_width * 100.0 / surfaces::METRE,
                                                     surfaces::panel_crease, surfaces::panel_bevel });
    surfaces::panel_ao_scale = panel_ao.x;
    surfaces::panel_ao_width = panel_ao.y * surfaces::METRE / 100.0;
    surfaces::panel_crease = panel_ao.z;
    surfaces::panel_bevel = if panel_ao.w > 0.0 { panel_ao.w } else { 1.0 };
    room_light::bounce_grey = number(argv, "--bounce-grey", room_light::bounce_grey);
    room_light::lace_source = number(argv, "--lace-source", room_light::lace_source);
    room_light::gather_near = number(argv, "--gather-near", if physical { PHYSICAL_GATHER_NEAR } else { room_light::gather_near });
    room_light::gather_exact = physical;
    room_light::niche_faces = physical;
    render3d::contact_look = four(argv, "--contact", render3d::contact_look);
    render3d::sheen_look = four(argv, "--sheen", render3d::sheen_look);
    render3d::room_sun.x = number(argv, "--room-sun", render3d::room_sun.x);
    let oak_sun = four(argv, "--oak-sun", float4 { render3d::room_sun.y, render3d::room_sun.z, render3d::room_sun.w, 0.0 });
    render3d::room_sun = float4 { render3d::room_sun.x, oak_sun.x, oak_sun.y, oak_sun.z };
    render3d::shade_fill = number(argv, "--shade-fill", render3d::shade_fill);
    var lace_hang = number(argv, "--lace-hang", room_shell::LACE_HANG);
    var dust_way = pick(argv, "--dust", DUST_WAYS, DUST_POINTS);
    var shown_dust = -1;
    render3d::window_view = float4 { number(argv, "--lace-sun", 1.0), number(argv, "--lace-scatter", 1.0), number(argv, "--glass-film", 1.0),
                                     number(argv, "--scratches", 1.0) };
    render3d::lace_shade = float4 { number(argv, "--lace-shade-fill", 0.5), number(argv, "--lace-fold-ao", 1.5), 0.0, 0.0 };
    render3d::sun_veil = number(argv, "--sun-veil", 1.0);
    // The sun's look in the view out (render3d::SunLook): a preset, then each part's flag over it.
    // The haze in the sunbeam (render3d::Haze): a strength, sigma over it; its look; half size or full.
    let haze_way = pick(argv, "--haze", HAZE_NAMES, 0);
    render3d::haze.sigma = number(argv, "--haze-sigma", HAZE_SIGMAS[haze_way]);
    let haze_look = four(argv, "--haze-look", float4 { render3d::haze.g, render3d::haze.even, render3d::haze.taps, HAZE_SOFTS[haze_way] });
    render3d::haze.g = haze_look.x;
    render3d::haze.even = haze_look.y;
    render3d::haze.taps = haze_look.z as i64;
    render3d::haze.soft = haze_look.w;
    render3d::haze.toward = number(argv, "--haze-toward", HAZE_TOWARDS[haze_way]);
    render3d::haze.half = !(flag_value(argv, "--haze-res") > 0 && argv[flag_value(argv, "--haze-res")] == "full");
    var haze_e4 = render3d::haze.sigma * 1.0e4;
    let sun_look = pick(argv, "--sun-look", SUN_LOOK_NAMES, 0);
    render3d::sun_look = SUN_LOOKS[sun_look];
    render3d::sun_look.disc = four(argv, "--sun-disc", render3d::sun_look.disc);
    render3d::sun_look.glare = four(argv, "--sun-glare", render3d::sun_look.glare);
    render3d::sun_look.tree = four(argv, "--sun-tree", render3d::sun_look.tree);
    render3d::sun_look.veil = four(argv, "--sun-eye", render3d::sun_look.veil);
    render3d::tone_probe = number(argv, "--tone-probe", 0.0);
    let nudge = four(argv, "--view-nudge", float4_0);
    table_window_nudge = float3 { nudge.x, nudge.y, nudge.z };
    // The HDR target's glow (render3d::HdrGlow): strength, threshold, knee, reach; its levels.
    render3d::hdr_glow.look = four(argv, "--glow", if physical && render3d::camera_toe > 2.5 { AGX_GLOW } else { SUN_GLOWS[sun_look] });
    render3d::hdr_glow.levels = number(argv, "--glow-levels", render3d::hdr_glow.levels as f32) as i64;
    var sun_bright_log = log10(max(render3d::sun_look.disc.w, 1.0));
    // The lens (render3d::Lens): on or off, its focus in metres (0 the view's target, kept
    // on it as the camera moves), its aperture and caps in percent of the width.
    render3d::lens.on = flag_value(argv, "--dof") > 0 && argv[flag_value(argv, "--dof")] == "on";
    // The scenic views' HDR target (render3d::hdr_shown), on unless --hdr off; X switches it.
    render3d::hdr_allowed = if has(argv, "--hdr") { argv[flag_value(argv, "--hdr")] == "on" } else { !phone_tier };
    render3d::depth_view = pick(argv, "--lens-view", LENS_VIEWS, 0);
    let focus_m = number(argv, "--focus", 0.0);
    var focus_on_target = focus_m <= 0.0;
    var focus_log = log2(if focus_on_target { render3d::lens.focus } else { focus_m });
    var aperture = number(argv, "--aperture", render3d::lens.aperture * 100.0);
    let caps = four(argv, "--dof-caps", float4 { render3d::lens.near_cap * 100.0, render3d::lens.far_cap * 100.0, 0.0, 0.0 });
    var near_cap = caps.x;
    var far_cap = caps.y;
    render3d::wind_time = number(argv, "--wind-time", 0.0);
    render3d::wind_kind = pick(argv, "--wind-kind", rooms::WIND_KINDS, rooms::WIND_NOISE);
    if physical { room = physical_light(room, rooms::get(room_take), has(argv, "--key"), has(argv, "--exposure")); }
    g.room = room;
    g.room_tuned = true;
    render3d::window_pattern = pattern == 1;
    var outside_on = !(flag_value(argv, "--outside") > 0 && argv[flag_value(argv, "--outside")] == "off");
    // The games table moved in the plan (metres), the room built round it there; the
    // table-window view's chair moves with it.
    let table_at = four(argv, "--table-at", float4 { TABLE_AS_MADE.x, TABLE_AS_MADE.y, 0.0, 0.0 });
    // The table's place on the panel's sliders, taken into the plan (and the room built
    // round it again) once no slider is held; its turn under the board; the board's turn to
    // the window wall, which sets the key's azimuth once given (--board-turn or a
    // placement); and the placement (A, --place), which sets them all, the flags after it.
    var table_place = float2 { table_at.x, table_at.y };
    var board_set = has(argv, "--board-turn");
    var board_turn = number(argv, "--board-turn", 0.0);
    var place = pick(argv, "--place", PLACE_NAMES, PLACE_DEFAULT);
    put_place(place, room, table_place, board_turn, board_set, g);
    var shown_place = place;
    // --place-then NAME: that placement taken on the third frame, as A would, so a shot
    // shows the room built again round the moved table (a check of the live path).
    let place_then = pick(argv, "--place-then", PLACE_NAMES, -1);
    if has(argv, "--table-at") { table_place = float2 { table_at.x, table_at.y }; }
    if has(argv, "--wall") { room.window = four(argv, "--wall", room.window); }
    if has(argv, "--sun-height") { room.key.y = number(argv, "--sun-height", room.key.y); }
    if has(argv, "--board-turn") { board_turn = number(argv, "--board-turn", 0.0); }
    g.table_turn = number(argv, "--table-turn", g.table_turn);
    var base_way = pick(argv, "--base-wood", BASE_WOODS, 1);
    var base_wood = render3d::base_wood;
    var base_look = render3d::base_look;
    base_wood.y = number(argv, "--base-light", base_wood.y);
    base_wood.z = number(argv, "--base-figure", base_wood.z);
    base_wood.w = number(argv, "--base-streaks", base_wood.w);
    base_look.x = number(argv, "--base-slant", base_look.x);
    base_look.y = number(argv, "--base-rings", base_look.y);
    base_look.z = number(argv, "--base-place", base_look.z);
    base_look.w = number(argv, "--base-colour", base_look.w);
    room_shell::LIBRARY.table = table_place;
    render3d::show_room(g, true);
    var paper_m = number(argv, "--wallpaper-tile", surfaces::PAPER_TILE / surfaces::METRE);
    g.paper_tile = paper_m * surfaces::METRE;
    // The panelling oak's and the ceiling's tint (lightness, saturation; 1,1 as they are).
    let oak4 = four(argv, "--oak-tint", float4 { 1.0, 1.0, 0.0, 0.0 });
    var oak = float2 { oak4.x, oak4.y };
    let ceiling4 = four(argv, "--ceiling-tint", float4 { 1.0, 1.0, 0.0, 0.0 });
    var ceiling = float2 { ceiling4.x, ceiling4.y };
    // The lace's ways (C, --lace): f3 built in, the spare ones read from design/materials/
    // where they are there (not on a phone).
    var lace_at: i64[5] = [0; 5];
    for w in 1..LACE_WAYS.len {
        read_file(str("../design/materials/lace_", LACE_WAYS[w], ".png")[..], spare_laces);
        lace_at[w + 1] = spare_laces.len;
    }
    g.lace_way = pick(argv, "--lace", LACE_WAYS, 0);
    // The bookcases' books in or out, and how much of their fade shows (1 as made).
    var books_on = !(flag_value(argv, "--books") > 0 && argv[flag_value(argv, "--books")] == "off");
    var rug_on = !(flag_value(argv, "--rug") > 0 && argv[flag_value(argv, "--rug")] == "off");
    var chairs_on = !(flag_value(argv, "--chairs") > 0 && argv[flag_value(argv, "--chairs")] == "off");
    g.chairs = chairs_on;
    // The props' light (render3d::props_light), and the table's own shade terms kept beside it.
    let props_way = pick(argv, "--props-light", PROPS_WAYS, 0);
    var props_on = props_way > 0;
    var props_shade = props_way == 2;
    if physical {
        props_on = true;
        props_shade = false;
        render3d::props_wrap = number(argv, "--props-wrap", 0.0);
        render3d::props_profile_ao = false;
    }
    var shutters_on = !(flag_value(argv, "--shutters") > 0 && argv[flag_value(argv, "--shutters")] == "off");
    room_shell::shutters_on = shutters_on;
    // The stove in its corner.
    room_shell::stove_on = !(flag_value(argv, "--stove") > 0 && argv[flag_value(argv, "--stove")] == "off");
    render3d::paint_relief = number(argv, "--paint-relief", 1.0);
    var book_fade = number(argv, "--book-fade", 1.0);
    // --tree-grow shadow|whole: the shell's tree's shadow from the first tree or the old
    // maple grown whole (render3d::tree_grown_whole).
    // --tree-draw off|wood|all: the tree outside drawn as geometry (render3d::tree_draw, task 107's
    // T2 and T3), off by default; on, the shadow comes from the same tree unless --tree-grow
    // says otherwise. --tree-light SUN,SKY,THROUGH,FORWARD, --tree-look SHADE,TWIG_PX,SPREAD and
    // --tree-tint TINT,LEAVES,BARK,DEEPER (render3d::tree_light..).
    render3d::tree_draw = pick(argv, "--tree-draw", render3d::TREE_DRAWS, render3d::TREE_OFF);
    render3d::tree_light = four(argv, "--tree-light", render3d::tree_light);
    let tree_look = four(argv, "--tree-look", float4 { render3d::tree_shade, render3d::tree_twig_px, render3d::tree_spread, 0.0 });
    render3d::tree_shade = tree_look.x;
    render3d::tree_twig_px = tree_look.y;
    render3d::tree_spread = tree_look.z;
    render3d::tree_tint = four(argv, "--tree-tint", render3d::tree_tint);
    // --tree-elbows FEWEST,MOST,TURN_LO,TURN_HI: broken leaders a hero limb, the side shoot
    // turned TURN_LO..TURN_HI degrees (0,0,30,50: none); --tree-gravity S: the gravity layer
    // in place of the habit's sag, S its strength (0 off, 1 the study's); --tree-shed
    // LIGHT,STUBS: thin wood whose twigs' sky share is under LIGHT dies back, STUBS of it left
    // as stubs (0,0.5: none). trees::Growth, task 117; the tree as grown by tools/tree_dump.
    render3d::tree_growth.elbows = four(argv, "--tree-elbows", render3d::tree_growth.elbows);
    render3d::tree_growth.gravity = number(argv, "--tree-gravity", render3d::tree_growth.gravity);
    let shed = four(argv, "--tree-shed", float4 { render3d::tree_growth.shed.x, render3d::tree_growth.shed.y, 0.0, 0.0 });
    render3d::tree_growth.shed = float2 { shed.x, shed.y };
    // --tree-plates ON,SPURS,NUDGE: the leaves only on each twig's current shoots, the tip's
    // two pairs and SPURS short shoots of one pair, Weisse's ratios, nudged apart in plan by
    // NUDGE (0,2,0: the habit's pairs along the twig); --tree-tilt ON,SEASON,SAG: the plates'
    // blades tilted by the measured tilts of SEASON (0 summer, 1 mid-September, 2 October) at
    // their height, SAG degrees more inside and low (0,2,8: level). trees::Growth, task 117.
    render3d::tree_growth.plates = four(argv, "--tree-plates", render3d::tree_growth.plates);
    render3d::tree_growth.tilt = four(argv, "--tree-tilt", render3d::tree_growth.tilt);
    // --tree-bend SHARE,TWIST: the plates' blades bent (cupped, drooping, tented, tips down,
    // sagging and twisted) by SHARE of the study's chances, twisted TWIST degrees at most at
    // the tip (0,25: flat); --tree-leaf-mesh tier|card|rows|fan: the leaves' meshes, by the
    // tier (the high tier's fan, the standard's rows, with the bend on) or one for all.
    let bend = four(argv, "--tree-bend", float4 { render3d::tree_growth.bend.x, render3d::tree_growth.bend.y, 0.0, 0.0 });
    render3d::tree_growth.bend = float2 { bend.x, bend.y };
    render3d::tree_leaf_mesh = pick(argv, "--tree-leaf-mesh", render3d::TREE_LEAF_MESHES, render3d::tree_leaf_mesh);
    // --tree-wind off|on: the shadow's wind on the tree's geometry, each leaf turning about
    // its stalk too in HDR (render3d::tree_wind, task 107's T4); --tree-flutter DEG,RATE how
    // far a leaf turns in the room's mild wind and how fast (radians a second of the wind).
    render3d::tree_wind = pick(argv, "--tree-wind", render3d::TREE_WINDS, 0) == 1;
    let flutter = four(argv, "--tree-flutter", float4 { render3d::tree_flutter.x, render3d::tree_flutter.y, 0.0, 0.0 });
    render3d::tree_flutter = float2 { flutter.x, flutter.y };
    // The maple's wood (task 117's step three), each off by default: --tree-bark off|on the
    // bark's age layers grown at startup in place of the first tile, --tree-relief K their
    // relief (1 true slopes); --tree-scatter W the light wrapped past the terminator as if
    // scattered under the bark, --tree-rough S Oren-Nayar's roughness (0 each: off);
    // --tree-junctions off|on the collars, swells, ridges, grain round the feet and caps,
    // --tree-roots off|on the flare's roots; --tree-wood-tier high|standard|phone their mesh.
    render3d::tree_bark = pick(argv, "--tree-bark", OFF_ON, 0) == 1;
    render3d::tree_relief = number(argv, "--tree-relief", render3d::tree_relief);
    render3d::tree_scatter = number(argv, "--tree-scatter", render3d::tree_scatter);
    render3d::tree_rough = number(argv, "--tree-rough", render3d::tree_rough);
    render3d::tree_wood.junctions = pick(argv, "--tree-junctions", OFF_ON, 0) == 1;
    render3d::tree_wood.roots = pick(argv, "--tree-roots", OFF_ON, 0) == 1;
    render3d::tree_wood.tier = pick(argv, "--tree-wood-tier", WOOD_TIERS, 0);
    // --tree-card off|on|main: the tree's card (render3d::tree_card, T5), drawn once from the
    // geometry: on in the floor's mirror (and a phone's view), main in the main view too in
    // place of the geometry, to compare. It is drawn from the tree, so it grows it all.
    render3d::tree_card = pick(argv, "--tree-card", render3d::TREE_CARDS, render3d::CARD_OFF);
    if render3d::tree_card != render3d::CARD_OFF && render3d::tree_draw == render3d::TREE_OFF { render3d::tree_draw = render3d::TREE_ALL; }
    let grown = if render3d::tree_draw != render3d::TREE_OFF { 1 } else { 0 };
    render3d::tree_grown_whole = pick(argv, "--tree-grow", TREE_GROWS, grown) == 1;
    // --dump-map out.pgm: the tree's map as the sun sees it, all layers' light multiplied, as
    // the renderer bakes it (the room's on or off).
    let dump = flag_value(argv, "--dump-map");
    if dump > 0 {
        var t = trees::Tree { .. };
        let sp = rooms::tree_spec(render3d::tree_room(g));
        let v = render3d::tree_view_of(g);
        if render3d::tree_grown_whole {
            let s = room_shell::LIBRARY;
            trees::grow_whole(t, render3d::whole_tree_of(g), v, rooms::whole_sight(g.room, s), true);
        } else {
            trees::grow(t, sp, v);
        }
        var map: u8[>..] = [];
        trees::draw_map(t, sp, v, map);
        var out: u8[>..] = [];
        format(out, "P5\n", v.w, " ", v.h, "\n255\n");
        for i in v.w * v.h {
            let o = i * 4;
            let k = (map[o] as i64) * (map[o + 1] as i64) / 255 * (map[o + 2] as i64) / 255 * (map[o + 3] as i64) / 255;
            out.push(k as u8);
        }
        guard write_file(argv[dump], out[..]) else { abort("could not write the map"); }
        print("map ", v.size.x, " by ", v.size.y, " middle ", v.middle.x, ",", v.middle.y);
    }

    put_look(r3d, g, season, material, st);

    // A touch screen's panel text sized by its height, as its window is the whole screen.
    let scale = if touch { max(gfx::screen_size().y as f32 / 700.0, 1.0) } else { max(gfx::screen_size().x as f32 / w, 1.0) };
    let c = ui::create(13.0, scale);
    guard c.id != 0 else { abort(str("ui: ", ui::error())); }
    var shown_season = season;
    var shown_material = material;
    var shown_take = take;
    var shown_room = room_take;
    var yaw:   f32 = number(argv, "--yaw", 0.0);
    var pitch: f32 = number(argv, "--height", view3d::PITCH);
    var far:   f32 = number(argv, "--distance", 1.3);
    var at = float2 { view3d::TARGET.x, view3d::TARGET.z };
    // A camera of its own (--eye, --at), or the room seen from the window's side (V).
    let own_eye = flag_value(argv, "--eye") > 0;
    var eye_at = four(argv, "--eye", float4_0);
    var look_at = four(argv, "--at", float4 { view3d::TARGET.x, view3d::TARGET.y, view3d::TARGET.z, 0.0 });
    var view = pick(argv, "--view", VIEWS, 0);
    let plan_eye = flag_value(argv, "--plan-eye") > 0;
    let plan_eye_at = four(argv, "--plan-eye", float4_0);
    let plan_look_at = four(argv, "--plan-at", float4 { 4.5, 5.8, 0.8, 0.0 });
    let fov_flag = number(argv, "--fov", 0.0);
    let shot = flag_value(argv, "--shot");
    let sun_checked = has(argv, "--sun-check");
    var meter = Meter { on: !(has(argv, "--fps") && argv[flag_value(argv, "--fps")] == "off"), wait: has(argv, "--fps-wait"), .. };
    let meter_for = number(argv, "--fps-seconds", 0.0) as f64;
    var meter_a: u8[..96] = [];
    var meter_b: u8[..96] = [];
    var frames = 0;
    var open = open_sections(argv);
    var drag_on_panel = false;
    var reset_orbit = false;
    // --shot-panel: the panel drawn in a shot too.
    let panel_in_shot = has(argv, "--shot-panel");
    var walk = Walk {};
    var finger = Touch {};
    var shown_view = view;
    var walk_text: u8[..96] = [];
    let walk_test = whole(argv, "--walk-test", 0);
    let walk_frames = flag_value(argv, "--walk-frames");
    let walk_path = pick(argv, "--walk-path", WALK_PATHS, 0);
    let walk_count = whole(argv, "--walk-count", 60);
    let walk_turn = whole(argv, "--walk-turn", 1);
    let shot_frame = if walk_test > 0 { walk_test } else if walk_frames > 0 { WALK_PATH_START + walk_count + 2 } else { 6 };
    var bakes_walking = 0;
    var last_tree_ms = 0.0;
    var last_light_ms = 0.0;
    // The first frames bake a step each under loading_frame's bar, with the frame's state as
    // the loop sets it, so draw finds them done; not in a shot, a walk's frames, a capture, or
    // a timed run, which keep their frames as they were.
    let loading = !(shot > 0 || walk_frames > 0 || walk_test > 0 || capturing || meter_for > 0.0);
    var load_step = if loading { 0 } else { LOAD_STEPS };
    while gfx::frame() {
        frames++;
        let frame_at = gfx::time();
        let still = pattern == 0 || render3d::wind_kind == rooms::WIND_STILL || room.wind.y == 0.0;
        if meter_frame(meter, frame_at) {
            meter_text(meter, meter_a, meter_b, still);
            if meter_for > 0.0 || touch { print("light_tune: ", meter_a[..], "; ", meter_b[..]); }
        } else if !meter.measured {
            meter_text(meter, meter_a, meter_b, still);
        }
        if meter_for > 0.0 && frame_at > meter_for { break; }
        let capture_frame = capturing && frames == 5;
        if capture_frame {
            gfx::flush();
            guard tuner_capture_start(argv[capture]) else { abort("could not start Metal capture"); }
        }
        if walk_test > 0 { walk_test_input(frames); }
        if walk_frames > 0 {
            walk_path_input(frames, walk_path, walk_turn);
            // The frame drawn last time round, the path's step k.
            let k = frames - WALK_PATH_START - 2;
            if k >= 0 && k < walk_count {
                let name = str(argv[walk_frames], "/", if k < 10 { "00" } else if k < 100 { "0" } else { "" }, k, ".png");
                guard gfx::screenshot(name) else { abort(str("could not save ", name)); }
            }
        }
        if shot > 0 && frames == shot_frame {
            guard gfx::screenshot(argv[shot]) else { abort(str("could not save ", argv[shot])); }
            if g.tree_ms > 0.0 { print("the tree baked in ", g.tree_ms, " ms"); }
            if g.tree.ms > 0.0 { print("the tree's geometry made in ", g.tree.ms, " ms"); }
            if g.tree.card_ms > 0.0 { print("the tree's card drawn in ", g.tree.card_ms, " ms (the GPU waited for)"); }
            let oak = flag_value(argv, "--dump-oak");
            if oak > 0 && g.room_baked {
                dump_rgb(g.floor_albedo, g.room_side, str(argv[oak], "-floor.ppm"));
                dump_rgb(g.wall_albedo, g.room_side, str(argv[oak], "-wall.ppm"));
                dump_rgb(g.floor_normal, g.room_side, str(argv[oak], "-floor-normal.ppm"));
            }
            if g.room_ms > 0.0 {
                print("the room's oak baked in ", g.room_ms, " ms, ", g.room_side, " texels a side, ",
                      render3d::room_bytes(g) / 1048576, " MiB; its mesh made in ", g.mesh_ms, " ms, ",
                      g.room_count / 3, " triangles and ", g.window_count / 3, " of glass and lace");
                print("the paint's relief tile made in ", g.paint_tile_ms, " ms, ", room_shell::relief_bytes(), " bytes");
                print("the sills' limestone tile made in ", g.stone_tile_ms, " ms, ", room_shell::stone_bytes(), " bytes");
                print("the glass's tile made in ", g.glass_tile_ms, " ms, ", glass_tile::bytes(), " bytes");
            }
            if g.corner_ms > 0.0 {
                print("the corners' map baked in ", g.corner_ms, " ms, ", corner_map::chart_count, " charts in ",
                      corner_map::WIDTH, " x ", corner_map::rows, " texels");
            }
            let dump_light = flag_value(argv, "--dump-light");
            if dump_light > 0 && g.light_ms > 0.0 {
                var out: u8[>..] = [];
                for i in room_light::ATLAS_FLOATS { format(out, render3d::light_atlas[i], "\n"); }
                guard write_file(argv[dump_light], out[..]) else { abort("could not write the probes"); }
                if render3d::props_light {
                    var props: u8[>..] = [];
                    for i in room_light::PROPS_FLOATS { format(props, render3d::light_props[i], "\n"); }
                    guard write_file(str(argv[dump_light], ".props"), props[..]) else { abort("could not write the props' probes"); }
                }
            }
            if render3d::room_fixed_stale.len > 0 {
                print("the room's constants are stale at ", render3d::room_fixed_stale, ": the uniform shaders drew it (scripts/room_fixed.py)");
            }
            let dump_block = flag_value(argv, "--dump-room-block");
            if dump_block > 0 {
                let one: render3d::SurfacesBlock[1] = [render3d::surfaces_block(g)];
                guard write_file(argv[dump_block], bytes_of(one)) else { abort("could not write the room's block"); }
            }
            if g.light_ms > 0.0 {
                let st = render3d::light_steps;
                print("the room's light baked in ", g.light_ms, " ms, ", g.light_patches, " sun patches; the sun's rays ", st[0],
                      " ms, the first light ", st[1], ", the bounces ", st[2], ", ", st[3], ", ", st[4], ", the half grid ", st[5],
                      ", the probes ", st[6]);
                if render3d::camera_toe > 2.5 {
                    let k = render3d::camera_exposure(g);
                    print("the camera's meter ", render3d::meter_light, ", its exposure ", k, " over Frame's ", g.frame.params.x,
                          ": EV ", log2(k * g.frame.params.x * g.room.room_exposure));
                }
            }
            if g.props_baked { print("the props' occlusion baked in ", g.props_ms, " ms, ", g.table_count / 3, " triangles"); }
            if walk_test > 0 {
                print("walked to ", walk.eye.x, ",", walk.eye.y, ",", walk.eye.z, " yaw ", walk.yaw, " pitch ", walk.pitch,
                      "; walking ", walk.on, ", seated ", walk.seated, ", the mouse relative ", gfx::mouse_relative(),
                      ", the cursor shown ", gfx::cursor_visible(), "; bakes while walking ", bakes_walking);
            }
            break;
        }
        // ui's input from gfx turns gfx's text input on, and on Android and iOS that opens the keyboard
        // over half the screen: the touch walk, which has no panel, gives ui an empty frame.
        if touch {
            ui::input_begin(c);
            ui::input_end(c);
            ui::set_delta_time(c, gfx::delta_time() as f32);
        } else {
            ui::input_from_gfx(c);
        }
        // --print: the command line printed on the first frame too, as P prints it.
        var print_it = gfx::key_pressed("P") || (frames == 1 && has(argv, "--print"));
        // Tab begins the walk; Esc or Tab ends it, and so does losing focus, which lets the mouse go.
        var walk_now = !walk.on && (gfx::key_pressed("Tab") || touch);
        if walk.on && !touch && (gfx::key_pressed("Escape") || gfx::key_pressed("Tab") || !gfx::mouse_relative()) {
            walk.on = false;
            gfx::set_mouse_relative(false);
        }
        if walk.on {
            if gfx::key_pressed("C") {
                walk.seated = !walk.seated;
                walk.eye.z = if walk.seated { SEATED_EYE } else { WALK_EYE };
            }
        } else {
            if gfx::key_pressed("W") { pattern = 1 - pattern; }
            if gfx::key_pressed("T") { room.tree.x = (room.tree.x as i64 + 1) % 3; }
            if gfx::key_pressed("D") { dust_way = (dust_way + 1) % DUST_WAYS.len; }
            if gfx::key_pressed("V") { view = (view + 1) % VIEWS.len; }
            if gfx::key_pressed("U") { outside_on = !outside_on; }
            if gfx::key_pressed("K") { render3d::wind_kind = (render3d::wind_kind + 1) % rooms::WIND_KINDS.len; }
            if gfx::key_pressed("F") { meter.on = !meter.on; }
            if gfx::key_pressed("G") { meter.wait = !meter.wait; }
            if gfx::key_pressed("C") { g.lace_way = (g.lace_way + 1) % LACE_WAYS.len; }
            if gfx::key_pressed("B") { books_on = !books_on; }
            if gfx::key_pressed("H") { shutters_on = !shutters_on; }
            if gfx::key_pressed("A") { place = place % (PLACE_NAMES.len - 1) + 1; }
            if gfx::key_pressed("Z") {
                // The window view's steps all off, or all as made.
                let on = lace_hang > 0.0 || dust_way != DUST_OFF || render3d::sun_veil > 0.0
                    || length(render3d::window_view) > 0.0;
                let k: f32 = if on { 0.0 } else { 1.0 };
                render3d::window_view = float4 { k, k, k, k };
                render3d::sun_veil = k;
                lace_hang = k * room_shell::LACE_HANG;
                dust_way = if on { DUST_OFF } else { DUST_POINTS };
            }
            if gfx::key_pressed("Y") { lace_hang = if lace_hang > 0.0 { 0.0 } else { room_shell::LACE_HANG }; }
            if gfx::key_pressed("L") { paper_m = if paper_m > 1.0 { 0.65 } else if paper_m > 0.7 { 1.4 } else { 0.9 }; }
            if gfx::key_pressed("N") {
                var next = 0;
                for k, i in SCENE_SCALES { if k == scene_k { next = (i + 1) % SCENE_SCALES.len; } }
                scene_k = SCENE_SCALES[next];
            }
            if gfx::key_pressed("M") { upscale = 1 - upscale; }
            if gfx::key_pressed("X") { render3d::hdr_allowed = !render3d::hdr_allowed; }
            if gfx::key_pressed("2") { render3d::set_aa(r3d, g, render3d::aa_next(r3d, g.aa)); }
            if gfx::key_pressed("1") { render3d::depth_view = (render3d::depth_view + 1) % LENS_VIEWS.len; }
        }
        let flags = ui::WINDOW_BORDER | ui::WINDOW_TITLE | ui::WINDOW_MOVABLE | ui::WINDOW_SCALABLE;
        let panel_h = gfx::screen_size().y / scale - 20.0;
        let panel_on = !walk.on && load_step >= LOAD_STEPS;
        if panel_on && ui::begin(c, "Room light", ui::rect(10.0, 10.0, PANEL_W, panel_h), flags) {
            ui::layout_row_dynamic(c, ROW + 4.0, 2);
            if ui::button_label(c, "Print (P)") { print_it = true; }
            if ui::button_label(c, "Reset room") { shown_room = -1; }
            if section(c, open, SCENE) {
                choice(c, "Season", season, SEASONS);
                choice(c, "Board", material, MATERIALS);
                ui::tree_state_pop(c);
            }
            if section(c, open, LIGHT) {
                slider(c, "Room's exposure", room.room_exposure, 0.5, 4.0);
                slider(c, "Bounce", room.bounce.w, 0.0, 2.0);
                color_sliders(c, "Bounce", room.bounce);
                slider(c, "Sun on the room", room.shell_sun.y, 0.0, 5.0);
                slider(c, "Penumbra", room.shell_sun.x, 0.0, 0.02);
                slider(c, "Probes' sky", room.baked.x, 0.0, 20.0);
                slider(c, "Probes' bounce", room.baked.y, 0.0, 30.0);
                slider(c, "Harmonics kept", room.baked.z, 0.0, 1.0);
                slider(c, "Shade kept", room.baked.w, 0.0, 1.0);
                slider(c, "Glow", room.bloom.x, 0.0, 2.0);
                slider(c, "Glow white", room.bloom.y, 0.0, 1.0);
                slider(c, "Glow knee", room.bloom.z, 0.0, 1.0);
                slider(c, "Glow spread", room.bloom.w, 0.5, 12.0);
                slider(c, "Corners' shade", room.corners.x, 0.0, 2.0);
                slider(c, "Corners' reach", room.corners.y, 0.05, 1.0);
                slider(c, "SSAO", room.ssao.x, 0.0, 2.0);
                slider(c, "SSAO's reach", room.ssao.y, 0.05, 1.0);
                slider(c, "SSAO's bias", room.ssao.z, 0.0, 0.5);
                slider(c, "SSAO's gain", room.ssao.w, 0.5, 6.0);
                choice(c, "SSAO view", render3d::ssao_view, SSAO_VIEWS);
                count(c, "Bounces", render3d::light_bounces, 0, 3);
                slider(c, "Bounce's grey", room_light::bounce_grey, 0.0, 1.0);
                slider(c, "Lace as a source", room_light::lace_source, 0.0, 1.0);
                slider(c, "Probes' spread", room_light::gather_near, 0.02, 0.5);
                slider(c, "Contact shadow", render3d::contact_look.x, 0.0, 1.0);
                slider(c, "Contact's length", render3d::contact_look.y, 0.5, 8.0);
                slider(c, "Contact's steps", render3d::contact_look.z, 2.0, 24.0);
                slider(c, "Contact's thickness", render3d::contact_look.w, 0.1, 4.0);
                slider(c, "Sun's saturation", render3d::room_sun.x, 0.0, 1.5);
                slider(c, "Oak's share of the sun", render3d::room_sun.y, 0.0, 1.5);
                slider(c, "Oak's sun saturation", render3d::room_sun.z, 0.0, 1.5);
                slider(c, "Oak's sheen", render3d::room_sun.w, 0.0, 1.0);
                slider(c, "Sun's sheen", render3d::sheen_look.x, 0.0, 4.0);
                slider(c, "Sheen's roughness", render3d::sheen_look.y, 0.2, 1.0);
                slider(c, "Sheen on paper", render3d::sheen_look.z, 0.0, 1.0);
                slider(c, "Floor's mirror", room.planar.x, 0.0, 2.0);
                slider(c, "Mirror's blur", room.planar.y, 0.0, 4.0);
                slider(c, "Boards' wax", room.planar.z, 0.0, 1.0);
                slider(c, "Sky in mirror", room.planar.w, 1.0, 12.0);
                choice(c, "Mirror view", render3d::planar_view, PLANAR_VIEWS);
                if g.light_ms > 0.0 {
                    note(c, str("probes baked in ", floor(g.light_ms + 0.5) as i64, " ms, ", g.light_patches, " sun patches"));
                }
                if section(c, open, DETAIL) {
                    color_sliders(c, "Sun", room.key_color);
                    slider(c, "Exposure", room.exposure, 0.5, 2.0);
                    if physical && render3d::camera_toe > 2.5 { slider(c, "Camera EV", render3d::camera_ev, -4.0, 4.0); }
                    slider(c, "Sky round", room.fill.x, -30.0, 150.0);
                    slider(c, "Sky height", room.fill.y, 0.0, 80.0);
                    slider(c, "Sky strength", room.fill.z, 0.0, 3.0);
                    slider(c, "Sky broad", room.fill.w, 0.0, 1.0);
                    color_sliders(c, "Sky", room.fill_color);
                    slider(c, "Walls", room.walls.w, 0.0, 1.0);
                    color_sliders(c, "Walls", room.walls);
                    slider(c, "Ceiling", room.ceiling.w, 0.0, 1.0);
                    slider(c, "Floor", room.floor.w, 0.0, 1.0);
                    slider(c, "Lamp", room.lamp.z, 0.0, 1.0);
                    ui::tree_state_pop(c);
                }
                ui::tree_state_pop(c);
            }
            if section(c, open, SUN) {
                choice(c, "Pattern (W)", pattern, ["off", "on"]);
                var shade = clamp(room.tree.x as i64, 0, 2);
                choice(c, "Leaves by (T)", shade, ["noise", "tree", "both"]);
                room.tree.x = shade;
                if section(c, open, SUN_ITSELF) {
                    slider(c, "Across the wall", room.window.y, -60.0, 60.0);
                    slider(c, "Height", room.key.y, 3.0, 70.0);
                    slider(c, "Round (turns the room)", room.key.x, -180.0, 180.0);
                    slider(c, "Strength", room.key.z, 0.0, 12.0);
                    slider(c, "Shadow", room.key.w, 0.0, 1.0);
                    ui::tree_state_pop(c);
                }
                if section(c, open, TREE) {
                    choice(c, "Kind", room.species, trees::SPECIES_NAMES);
                    var seed = room.tree.y as i64;
                    count(c, "Seed", seed, 0, 99);
                    room.tree.y = seed;
                    slider(c, "Leafy", room.tree.w, 0.0, 2.0);
                    slider(c, "Leaf long", room.foliage.x, 0.1, 4.0);
                    slider(c, "Leaf wide", room.foliage.y, 0.2, 1.2);
                    slider(c, "Leaf lets", room.foliage.z, 0.0, 1.0);
                    slider(c, "Tree blur", room.tree_blur, 0.1, 3.0);
                    slider(c, "Trunk along", room.crown.x, -100.0, 100.0);
                    slider(c, "Trunk foot", room.crown.y, -400.0, 0.0);
                    slider(c, "Trunk high", room.tree.z, 40.0, 600.0);
                    slider(c, "Trunk away", room.foliage.w, 5.0, 300.0);
                    slider(c, "Crooked", room.crown.z, 0.0, 1.5);
                    slider(c, "Twigs hang", room.crown.w, 0.0, 1.0);
                    if g.tree_ms > 0.0 { note(c, str("baked in ", floor(g.tree_ms + 0.5) as i64, " ms")); }
                    ui::tree_state_pop(c);
                }
                if section(c, open, WIND) {
                    choice(c, "Kind (K)", render3d::wind_kind, rooms::WIND_KINDS);
                    slider(c, "Wind", room.wind.x, 0.0, 0.3);
                    slider(c, "Wind speed", room.wind.y, 0.0, 4.0);
                    slider(c, "Leaves sway", room.wind.z, 0.0, 8.0);
                    slider(c, "Ruffle", room.wind.w, 0.0, 2.0);
                    slider(c, "Gust strength", room.gust.x, 0.0, 2.0);
                    slider(c, "Gust length", room.gust.y, 0.3, 8.0);
                    slider(c, "Gust every", room.gust.z, 3.0, 60.0);
                    slider(c, "Gust reach", room.gust.w, 0.0, 1.0);
                    ui::tree_state_pop(c);
                }
                if section(c, open, WINDOW) {
                    slider(c, "Shade", room.pattern.x, 0.0, 1.0);
                    slider(c, "Softness", room.pattern.y, 0.0, 0.05);
                    slider(c, "Wall away", room.window.x, 10.0, 80.0);
                    slider(c, "Sun's turn across the wall", room.window.y, -60.0, 60.0);
                    slider(c, "Sill", room.window.z, -30.0, 30.0);
                    slider(c, "Sideways", room.window.w, -30.0, 30.0);
                    slider(c, "Pane wide", room.panes.x, 2.0, 20.0);
                    slider(c, "Pane high", room.panes.y, 2.0, 20.0);
                    slider(c, "Bar", room.panes.z, 0.0, 3.0);
                    slider(c, "Panes across", room.opening.x, 1.0, 4.0);
                    slider(c, "Panes up", room.opening.y, 1.0, 6.0);
                    ui::tree_state_pop(c);
                }
                if section(c, open, NOISE) {
                    slider(c, "Leaves", room.leaves.x, 0.0, 1.0);
                    slider(c, "Leaf size", room.leaves.y, 0.02, 1.0);
                    slider(c, "Trees away", room.leaves.z, 0.0, 400.0);
                    slider(c, "Leaf blur", room.leaves.w, 0.0, 2.0);
                    slider(c, "Single leaves", room.twigs.x, 0.0, 12.0);
                    slider(c, "Leaf gaps few", room.twigs.y, 0.2, 0.9);
                    slider(c, "Fleck blur", room.twigs.z, 0.005, 0.3);
                    slider(c, "In the open", room.twigs.w, 0.0, 1.0);
                    slider(c, "Crown blur", room.crown_blur, 0.0, 6.0);
                    slider(c, "Crown fill", room.crown_fill, 0.0, 10.0);
                    ui::tree_state_pop(c);
                }
                ui::tree_state_pop(c);
            }
            if section(c, open, WALLPAPER) {
                slider(c, "Tile (m)", paper_m, 0.65, 1.4);
                let thirds: f32[4] = [0.25, 0.25, 0.25, 0.25];
                ui::layout_row(c, ui::DYNAMIC, ROW, thirds);
                ui::label(c, "L flips", ui::TEXT_LEFT);
                if ui::button_label(c, "0.65") { paper_m = 0.65; }
                if ui::button_label(c, "0.9") { paper_m = 0.9; }
                if ui::button_label(c, "1.4") { paper_m = 1.4; }
                ui::tree_state_pop(c);
            }
            if section(c, open, WAINSCOT) {
                slider(c, "Oak light", oak.x, 0.25, 8.0);
                slider(c, "Oak colour", oak.y, 0.0, 1.5);
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "As baked") { oak = float2 { 1.0, 1.0 }; }
                slider(c, "Paint's relief", render3d::paint_relief, 0.0, 6.0);
                if g.room_ms > 0.0 {
                    note(c, str("oak baked in ", floor(g.room_ms + 0.5) as i64, " ms, ", render3d::room_bytes(g) / 1048576, " MiB"));
                }
                ui::tree_state_pop(c);
            }
            if section(c, open, CEILING) {
                slider(c, "Ceiling light", ceiling.x, 0.3, 1.5);
                slider(c, "Ceiling colour", ceiling.y, 0.0, 3.0);
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "As it is") { ceiling = float2 { 1.0, 1.0 }; }
                ui::tree_state_pop(c);
            }
            if section(c, open, CURTAINS) {
                choice(c, "Lace (C)", g.lace_way, LACE_WAYS);
                switch(c, "Shutters (H)", shutters_on, ["off", "on"]);
                slider(c, "Lace hangs over (Y)", lace_hang, 0.0, 0.2);
                slider(c, "Lace's sun", render3d::window_view.x, 0.0, 3.0);
                slider(c, "Lace's light below", render3d::window_view.y, 0.0, 3.0);
                slider(c, "Glass's film", render3d::window_view.z, 0.0, 10.0);
                slider(c, "Glass's scratches", render3d::window_view.w, 0.0, 10.0);
                slider(c, "Lace's fill in shade", render3d::lace_shade.x, 0.2, 1.0);
                slider(c, "Lace's folds' shade", render3d::lace_shade.y, 0.0, 2.0);
                slider(c, "Curtain in", room.opening.z, 0.0, 20.0);
                slider(c, "Lace lets", room.opening.w, 0.0, 1.0);
                ui::tree_state_pop(c);
            }
            if section(c, open, BOOKS) {
                switch(c, "Books (B)", books_on, ["off", "on"]);
                slider(c, "Their fade", book_fade, 0.0, 3.0);
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "As made") { book_fade = 1.0; }
                ui::tree_state_pop(c);
            }
            if section(c, open, TABLE) {
                choice(c, "Table", take, tables::NAMES);
                choice(c, "Placement (A)", place, PLACE_NAMES);
                switch(c, "Rug", rug_on, ["off", "on"]);
                switch(c, "Chairs", chairs_on, ["off", "on"]);
                switch(c, "Light per pixel", props_on, ["off", "on"]);
                switch(c, "  the table's own shade", props_shade, ["off", "on"]);
                if props_on && g.props_baked { note(c, str("  occlusion baked in ", floor(g.props_ms + 0.5) as i64, " ms")); }
                slider(c, "Along the wall (m)", table_place.x, 2.5, 6.5);
                slider(c, "From the hall wall (m)", table_place.y, 4.5, 6.2);
                slider(c, "Its turn under the board", g.table_turn, -60.0, 60.0);
                choice(c, "Base's wood", base_way, BASE_WOODS);
                slider(c, "  its lightness (of the map's)", base_wood.y, 0.2, 1.2);
                slider(c, "  its figure's contrast (of the map's)", base_wood.z, 0.0, 1.5);
                slider(c, "  the figure drawn out along the grain", base_wood.w, 1.0, 16.0);
                slider(c, "  the grain's slant round the column", base_look.x, -30.0, 30.0);
                slider(c, "  the rings the column's cut crosses", base_look.y, 0.0, 3.0);
                slider(c, "  where across the map it reads", base_look.z, 0.0, 1.0);
                slider(c, "  its colour's strength (of the map's)", base_look.w, 0.0, 1.5);
                let board_was = board_turn;
                slider(c, "Board's turn to the wall", board_turn, -90.0, 90.0);
                if board_turn != board_was { board_set = true; }
                note(c, str("  the board's own z ", floor(board_in_plan(g) * 10.0 + 0.5) / 10.0, " degrees in the plan"));
                let lit, table_lit = sun_check(g, room.window.y, room.key.y, false);
                note(c, str("  sun-check: the field ", lit, " of 81, the table ", table_lit, " of 72 lit"));
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "Print the sun-check") { sun_check(g, room.window.y, room.key.y); }
                slider(c, "Pieces' halo (0 as made)", st.halo.x, 0.0, 1.5);
                slider(c, "Its reach (0 as made)", st.halo.y, 0.0, 1.5);
                ui::tree_state_pop(c);
            }
            if section(c, open, OUTSIDE) {
                switch(c, "Outside (U)", outside_on, ["plain", "park"]);
                slider(c, "Outside's exposure", room.outside, 0.3, 2.5);
                slider(c, "Sun's veil", render3d::sun_veil, 0.0, 4.0);
                slider(c, "Sun's radius (deg)", render3d::sun_look.disc.x, 0.1, 3.0);
                slider(c, "Its limb's darkening", render3d::sun_look.disc.y, 0.0, 1.0);
                slider(c, "Its edge (deg)", render3d::sun_look.disc.z, 0.0, 1.0);
                slider(c, "Its brightness (log10)", sun_bright_log, 0.0, 5.0);
                render3d::sun_look.disc.w = exp2(sun_bright_log * 3.3219281);
                slider(c, "Core halo", render3d::sun_look.glare.x, 0.0, 3.0);
                slider(c, "Core's width (deg)", render3d::sun_look.glare.y, 0.2, 5.0);
                slider(c, "Wide glow", render3d::sun_look.glare.z, 0.0, 2.0);
                slider(c, "Its width (deg)", render3d::sun_look.glare.w, 1.0, 20.0);
                slider(c, "Tree round the sun", render3d::sun_look.tree.x, 0.0, 1.0);
                slider(c, "Its reach (deg)", render3d::sun_look.tree.y, 5.0, 180.0);
                slider(c, "Leaves' back light", render3d::sun_look.tree.z, 0.0, 4.0);
                slider(c, "Its sharpness (m)", render3d::sun_look.tree.w, 0.0, 12.0);
                note(c, "  The eye's glare round the sun (HDR):");
                slider(c, "Veil", render3d::sun_look.veil.x, 0.0, 12.0);
                slider(c, "Its half width (deg)", render3d::sun_look.veil.y, 0.3, 6.0);
                slider(c, "Its end (deg)", render3d::sun_look.veil.z, 2.0, 45.0);
                slider(c, "Its amber", render3d::sun_look.veil.w, 0.0, 2.0);
                note(c, if render3d::hdr_shown(g) { "  HDR glow:" } else { "  HDR glow (shown with HDR only):" });
                slider(c, "Glow", render3d::hdr_glow.look.x, 0.0, 0.5);
                slider(c, "Its threshold", render3d::hdr_glow.look.y, 0.0, 8.0);
                slider(c, "Its knee", render3d::hdr_glow.look.z, 0.0, 4.0);
                slider(c, "Its reach", render3d::hdr_glow.look.w, 0.0, 1.0);
                count(c, "Its levels", render3d::hdr_glow.levels, 1, render3d::GLOW_LEVELS);
                ui::tree_state_pop(c);
            }
            if section(c, open, DUST) {
                choice(c, "Dust (D)", dust_way, DUST_WAYS);
                count(c, "Motes", motes, 0, render3d::MAX_MOTES);
                slider(c, "Bright", render3d::dust.bright, 0.0, 80.0);
                slider(c, "Toward sun", render3d::dust.ahead, 0.0, 0.9);
                slider(c, "Fibres", render3d::dust.fibres, 0.0, 1.0);
                slider(c, "Fibres' width (of a point's)", render3d::dust.fibre_width, 0.25, 1.0);
                slider(c, "Point's footprint px", render3d::dust.point_px, 0.4, 2.0);
                slider(c, "Glints", render3d::dust.glints, 0.0, 3.0);
                slider(c, "Drift cm/s", render3d::dust.air.x, 0.0, 6.0);
                slider(c, "Rise cm/s", render3d::dust.air.y, 0.0, 4.0);
                slider(c, "Swirls cm/s", render3d::dust.air.z, 0.0, 6.0);
                slider(c, "Swirls' size cm", render3d::dust.air.w, 3.0, 40.0);
                slider(c, "Round the board", render3d::dust.near, 0.0, 1.0);
                slider(c, "Haze, sigma 1e-4/m (HDR)", haze_e4, 0.0, 40.0);
                slider(c, "Haze's g", render3d::haze.g, 0.0, 0.95);
                slider(c, "Haze's even share", render3d::haze.even, 0.0, 1.0);
                slider(c, "Haze's soft stripes", render3d::haze.soft, 0.0, 8.0);
                slider(c, "Haze's softer toward the sun", render3d::haze.toward, 0.0, 8.0);
                switch(c, "Haze's size", render3d::haze.half, ["full", "half"]);
                ui::tree_state_pop(c);
            }
            if section(c, open, CAMERA) {
                choice(c, "View (V)", view, VIEWS);
                slider(c, "Distance", far, 0.4, 4.0);
                slider(c, "Height", pitch, 10.0, 89.0);
                slider(c, "Round", yaw, -180.0, 180.0);
                ui::layout_row_dynamic(c, ROW + 4.0, 1);
                if ui::button_label(c, "Reset the orbit and the view (R)") { reset_orbit = true; }
                if ui::button_label(c, "Walk round the room (Tab)") { walk_now = true; }
                switch(c, "Seated (C)", walk.seated, ["no", "yes"]);
                note(c, "  walking: Q down, E up");
                if walk.placed {
                    note(c, str("walked to ", floor(walk.eye.x * 100.0 + 0.5) / 100.0, ", ", floor(walk.eye.y * 100.0 + 0.5) / 100.0,
                                ", ", floor(walk.eye.z * 100.0 + 0.5) / 100.0, " m; P prints it"));
                }
                ui::tree_state_pop(c);
            }
            if section(c, open, DEBUG) {
                switch(c, "Frames (F)", meter.on, ["off", "on"]);
                switch(c, "Wait GPU (G)", meter.wait, ["off", "on"]);
                let scene = render3d::scene_size_of(gfx::screen_size());
                note(c, str("the scene ", scene.x, " x ", scene.y, if scene_k > 0.0 { str(" at ", scene_k) } else { str(", at most ", scene_budget / 1.0e6, " MP") }, " (N)"));
                choice(c, "Upscale (M)", upscale, UPSCALES);
                note(c, if g.bake_held { "bakes held till the slider's let go" } else { "bakes when let go of a slider" });
                if g.tree_ms > 0.0 { note(c, str("the tree baked in ", floor(g.tree_ms + 0.5) as i64, " ms")); }
                if g.light_ms > 0.0 { note(c, str("the probes baked in ", floor(g.light_ms + 0.5) as i64, " ms")); }
                if g.room_ms > 0.0 { note(c, str("the oak baked in ", floor(g.room_ms + 0.5) as i64, " ms")); }
                ui::tree_state_pop(c);
            }
            if section(c, open, KEYS) {
                for k in KEY_HELP { note(c, k); }
                ui::tree_state_pop(c);
            }
            if section(c, open, LENS) {
                switch(c, "HDR (X)", render3d::hdr_allowed, ["off", "on"]);
                note(c, str("Antialiasing (2): ", render3d::aa_name(r3d, g.aa)));
                note(c, if render3d::hdr_shown(g) { "  drawn in HDR" } else { "  drawn in 8 bits (the view or a tuner's view)" });
                switch(c, "Depth of field", render3d::lens.on, ["off", "on"]);
                switch(c, "Focus on the target", focus_on_target, ["no", "yes"]);
                slider(c, "Focus (log2 m)", focus_log, -1.5, 6.0);
                note(c, str("  the focus at ", floor(exp2(focus_log) * 100.0 + 0.5) / 100.0, " m"));
                slider(c, "Aperture (% wide)", aperture, 0.0, 8.0);
                slider(c, "Near cap (%)", near_cap, 0.0, 12.0);
                slider(c, "Far cap (%)", far_cap, 0.0, 12.0);
                choice(c, "Lens view (1)", render3d::depth_view, LENS_VIEWS);
                if render3d::depth_view > 0 && !render3d::hdr_shown(g) { note(c, "  the view needs HDR"); }
                ui::tree_state_pop(c);
            }
        }
        if panel_on { ui::end(c); }
        // A drag that began on the panel holds the tree's and the probes' bakes till it is let go.
        if gfx::mouse_pressed(gfx::MOUSE_LEFT) { drag_on_panel = ui::wants_mouse(c); }
        g.bake_held = drag_on_panel && gfx::mouse_down(gfx::MOUSE_LEFT);
        g.paper_tile = paper_m * surfaces::METRE;
        g.books_off = !books_on;
        g.rug_off = !rug_on;
        room_light::rug_in_bake = physical && rug_on;
        g.chairs = chairs_on;
        render3d::props_light = props_on;
        render3d::props_table_shade = props_shade;
        room_shell::shutters_on = shutters_on;
        render3d::lace_png = spare_laces[lace_at[g.lace_way]..lace_at[g.lace_way + 1]];
        if lace_hang != room_shell::lace_hang { room_shell::hang_lace(lace_hang); }
        g.book_fade = max(book_fade, 0.001);
        g.room_tint = float4_0;
        if oak.x != 1.0 || oak.y != 1.0 {
            g.room_tint.x = oak.x;
            g.room_tint.y = oak.y;
        }
        if ceiling.x != 1.0 || ceiling.y != 1.0 {
            g.room_tint.z = ceiling.x;
            g.room_tint.w = ceiling.y;
        }
        if room_take != shown_room {
            shown_room = room_take;
            room = rooms::get(room_take);
            if physical { room = physical_light(room, room, false, false); }
        }
        if season != shown_season || material != shown_material || take != shown_take {
            if season != shown_season {
                room_take = rooms::for_season(season);
                shown_room = room_take;
                room = rooms::get(room_take);
                if physical { room = physical_light(room, room, false, false); }
            }
            shown_season = season;
            shown_material = material;
            shown_take = take;
            g.table_spec = tables::get(take);
            if physical { g.table_spec.light.y = 1.0; }
            render3d::tune_table(r3d, g, g.table_spec);
            g.room = room;
            put_look(r3d, g, season, material, st);
        }
        if st.halo.x != shown_halo.x || st.halo.y != shown_halo.y {
            shown_halo = st.halo;
            place_pieces(r3d, g, st);
        }
        if place_then >= 0 && frames == 3 { place = place_then; }
        // A placement picked (A, the panel): its sun, table and board, and its name printed.
        if place != shown_place {
            shown_place = place;
            put_place(place, room, table_place, board_turn, board_set, g);
            if place > 0 { print("placement ", PLACE_NAMES[place], ": ", place_flags(room, table_place, board_turn, g.table_turn)); }
        }
        // The table's place into the plan once no slider is held: the room is built round it
        // again then, and its light baked again.
        if !g.bake_held && (table_place.x != room_shell::LIBRARY.table.x || table_place.y != room_shell::LIBRARY.table.y) {
            room_shell::LIBRARY.table = table_place;
        }
        // The board's turn to the window wall: the key's azimuth for it, the sky's and the
        // lamp's turned with it.
        if board_set {
            let a = azimuth_for(board_turn, room.window.y);
            let turned = a - room.key.x;
            room.key.x = a;
            room.fill.x += turned;
            room.lamp.x += turned;
        }
        // Cheap enough to do each frame: the harmonics on the CPU and the shadow map.
        g.room = room;
        render3d::window_pattern = pattern == 1;
        // A shot is taken at --wind-time itself.
        if shot < 0 && !capturing { render3d::wind_time += gfx::delta_time() as f32; }
        // The desktop's map leaves the tree out while its leaves move (a shot's keep still,
        // unless --leaves-moving on).
        render3d::leaves_moving = leaves_moving_flag
            || (shot < 0 && !capturing && !(pattern == 0 || render3d::wind_kind == rooms::WIND_STILL || room.wind.y == 0.0));
        render3d::put_room(g);
        if sun_checked && frames == 2 {
            sun_check(g, room.window.y, room.key.y);
            if shot < 0 { break; }
        }
        // The walk: begun where the view is (or the room's view from the board's orbit);
        // another view ends its camera.
        if view != shown_view {
            shown_view = view;
            walk.placed = false;
        }
        let from_view = if view > 0 { view } else { 1 };
        var start_eye = view_eye(from_view, place);
        var start_at = view_at(from_view, place);
        if plan_eye && !own_eye {
            start_eye = float3 { plan_eye_at.x, plan_eye_at.y, plan_eye_at.z };
            start_at = float3 { plan_look_at.x, plan_look_at.y, plan_look_at.z };
        }
        if walk_now && (touch || gfx::set_mouse_relative(true)) {
            if !walk.placed { walk_from(walk, start_eye, start_at); }
            walk.on = true;
            walk.placed = true;
        }
        if gfx::key_pressed("R") || reset_orbit {
            if walk.on { walk_from(walk, start_eye, start_at); } else { walk.placed = false; }
        }
        if walk.on {
            let o = plan_point(g, float3_0);
            let px = plan_point(g, float3 { 1.0, 0.0, 0.0 }) - o;
            let py = plan_point(g, float3 { 0.0, 1.0, 0.0 }) - o;
            let hand: f32 = if py.x * px.z - py.z * px.x >= 0.0 { 1.0 } else { -1.0 };
            let dt = if walk_test > 0 || walk_frames > 0 { 1.0 / 60.0 } else { min(gfx::delta_time() as f32, LONGEST_STEP) };
            if touch {
                let look, stick = touch_step(finger, gfx::screen_size());
                walk_step(walk, look, dt, hand, stick);
            } else {
                walk_step(walk, gfx::mouse_delta(), dt, hand);
            }
        }
        if print_it {
            var line: u8[>..] = [];
            format(line, "--light ", LIGHT_WAYS[if physical { 1 } else { 0 }]);
            if physical {
                format(line, " --camera-toe ", TOES[render3d::camera_toe as i64], " --camera-ev ", render3d::camera_ev, " --props-wrap ",
                       render3d::props_wrap, " --casement-depth ",
                       if casement_depth { "on" } else { "off" });
            }
            format(line, " --season ", SEASONS[season], " --material ", MATERIALS[material], " --table ", tables::NAMES[take],
                   " --lace ", LACE_WAYS[g.lace_way]);
            format(line, " --outside ", on_off(outside_on),
                   " --window ", on_off(pattern == 1), " --dust ", DUST_WAYS[dust_way], " --wind-kind ",
                   rooms::WIND_KINDS[render3d::wind_kind], " --view ", VIEWS[view]);
            format(line, " --wallpaper-tile ", paper_m);
            let tm = room_shell::LIBRARY.table;
            format(line, " --place ", PLACE_NAMES[place]);
            if tm.x != TABLE_AS_MADE.x || tm.y != TABLE_AS_MADE.y { format(line, " --table-at ", tm.x, ",", tm.y); }
            if board_set { format(line, " --board-turn ", board_turn); }
            if g.table_turn != 0.0 { format(line, " --table-turn ", g.table_turn); }
            if dust_way != DUST_OFF {
                format(line, " --motes ", motes, " --mote-bright ", render3d::dust.bright, " --mote-fibres ", render3d::dust.fibres,
                       " --fibre-width ", render3d::dust.fibre_width, " --point-px ", render3d::dust.point_px, " --glints ",
                       render3d::dust.glints, " --near ", render3d::dust.near);
                flag_four(line, "--air", render3d::dust.air);
            }
            format(line, " --haze-sigma ", haze_e4 * 1.0e-4, " --haze-toward ", render3d::haze.toward, " --haze-res ",
                   if render3d::haze.half { "half" } else { "full" });
            flag_four(line, "--haze-look", float4 { render3d::haze.g, render3d::haze.even, render3d::haze.taps, render3d::haze.soft });
            format(line, " --books ", on_off(books_on), " --rug ", on_off(rug_on), " --chairs ", on_off(chairs_on), " --props-light ",
                   (if !props_on { "off" } else if props_shade { "kept" } else { "on" }), " --book-fade ", book_fade, " --shutters ", on_off(shutters_on), " --lace-hang ", lace_hang);
            if st.halo.x > 0.0 || st.halo.y > 0.0 { format(line, " --halo ", st.halo.x, " --halo-reach ", st.halo.y); }
            let wv = render3d::window_view;
            format(line, " --lace-sun ", wv.x, " --lace-scatter ", wv.y, " --glass-film ", wv.z, " --scratches ", wv.w, " --sun-veil ",
                   render3d::sun_veil);
            format(line, " --lace-shade-fill ", render3d::lace_shade.x, " --lace-fold-ao ", render3d::lace_shade.y);
            flag_four(line, "--sun-disc", render3d::sun_look.disc);
            flag_four(line, "--sun-glare", render3d::sun_look.glare);
            flag_four(line, "--sun-tree", render3d::sun_look.tree);
            flag_four(line, "--sun-eye", render3d::sun_look.veil);
            flag_four(line, "--glow", render3d::hdr_glow.look);
            format(line, " --glow-levels ", render3d::hdr_glow.levels);
            format(line, " --aa ", render3d::aa_name(r3d, g.aa), " --hdr ", on_off(render3d::hdr_allowed), " --lens-view ", LENS_VIEWS[render3d::depth_view], " --dof ", on_off(render3d::lens.on), " --focus ", if focus_on_target { 0.0 } else { exp2(focus_log) },
                   " --aperture ", aperture);
            flag_pair(line, "--dof-caps", float2 { near_cap, far_cap });
            if render3d::paint_relief != 1.0 { format(line, " --paint-relief ", render3d::paint_relief); }
            flag_pair(line, "--oak-tint", oak);
            flag_pair(line, "--ceiling-tint", ceiling);
            room_flags(line, room);
            format(line, " --bounces ", render3d::light_bounces, " --bounce-grey ", room_light::bounce_grey, " --lace-source ",
                   room_light::lace_source, " --gather-near ", room_light::gather_near);
            flag_four(line, "--contact", render3d::contact_look);
            flag_four(line, "--sheen", render3d::sheen_look);
            format(line, " --room-sun ", render3d::room_sun.x);
            flag_four(line, "--oak-sun", float4 { render3d::room_sun.y, render3d::room_sun.z, render3d::room_sun.w, 0.0 });
            flag_four(line, "--panel-ao", float4 { surfaces::panel_ao_scale, surfaces::panel_ao_width * 100.0 / surfaces::METRE,
                                                   surfaces::panel_crease, surfaces::panel_bevel });
            if walk.placed {
                let at = walk_at(walk);
                flag_four(line, "--plan-eye", float4 { walk.eye.x, walk.eye.y, walk.eye.z, 0.0 });
                flag_four(line, "--plan-at", float4 { at.x, at.y, at.z, 0.0 });
                format(line, " --fov ", if fov_flag > 0.0 { fov_flag } else { WALK_FOV });
            } else if own_eye {
                flag_four(line, "--eye", eye_at);
                flag_four(line, "--at", look_at);
            } else if plan_eye {
                flag_four(line, "--plan-eye", plan_eye_at);
                flag_four(line, "--plan-at", plan_look_at);
            } else {
                format(line, " --yaw ", yaw, " --height ", pitch, " --distance ", far);
            }
            if fov_flag > 0.0 && !walk.placed { format(line, " --fov ", fov_flag); }
            report(room, room_take, line[..]);
        }
        if gfx::key_pressed("R") || reset_orbit {
            reset_orbit = false;
            yaw = 0.0;
            pitch = view3d::PITCH;
            far = 1.3;
        }
        if !walk.on && !ui::wants_mouse(c) {
            if gfx::mouse_down(gfx::MOUSE_LEFT) {
                let d = gfx::mouse_delta();
                yaw -= d.x * 0.25;
                pitch = clamp(pitch + d.y * 0.25, 10.0, 89.0);
            }
            far = clamp(far * pow(0.9 as f32, gfx::mouse_wheel()), 0.4, 4.0);
        }
        let size = gfx::screen_size();
        let a = radians(pitch);
        let b = radians(yaw);
        var target = float3 { at.x, view3d::TARGET.y, at.y };
        var eye = target + float3 { sin(b) * cos(a), sin(a), cos(b) * cos(a) } * (view3d::DISTANCE * far);
        var fov = view3d::FOV;
        if walk.placed {
            eye = plan_point(g, walk.eye);
            target = plan_point(g, walk_at(walk));
            fov = WALK_FOV;
        } else if own_eye {
            eye = float3 { eye_at.x, eye_at.y, eye_at.z };
            target = float3 { look_at.x, look_at.y, look_at.z };
        } else if plan_eye {
            eye = plan_point(g, float3 { plan_eye_at.x, plan_eye_at.y, plan_eye_at.z });
            target = plan_point(g, float3 { plan_look_at.x, plan_look_at.y, plan_look_at.z });
            fov = 55.0;
        } else if view > 0 {
            eye = plan_point(g, view_eye(view, place));
            target = plan_point(g, view_at(view, place));
            fov = 60.0;
        }
        // Behind the shell's windows the park (model3d::view_out), or with U a plain sky of
        // ours (render3d's plain fade), not the season's photograph; the fade gives the
        // board's ambient either way.
        g.plain = true;
        g.outside_on = outside_on;
        g.fade = [SKY_TOP, SKY_LOW, SKY_LIGHT];
        // A preset's settings once when it is picked, the sliders free after; its box in the
        // sunbeam each frame (the key may move).
        if dust_way != shown_dust {
            let first = shown_dust < 0;
            shown_dust = dust_way;
            render3d::dust = render3d::Dust {};
            motes = POINTS_COUNTS[dust_way];
            render3d::dust.bright = POINTS_BRIGHT;
            render3d::dust.ahead = POINTS_AHEAD;
            render3d::dust.fibres = POINTS_FIBRES;
            // The flags over the first preset.
            if first { motes = dust_flags(argv, motes); }
        }
        render3d::dust.shell = true;
        render3d::dust.board_at = BEAM_NEAR / (BEAM_NEAR + BEAM_FAR);
        render3d::haze.sigma = haze_e4 * 1.0e-4;
        let at, u, v, w = beam_box(g);
        render3d::dust.low = at;
        render3d::dust.u = u;
        render3d::dust.v = v;
        render3d::dust.w = w;
        render3d::dust.span = float3 { length(u), length(v), length(w) };
        let dust_here = dust_way != DUST_OFF && view == TABLE_WINDOW;
        render3d::dust.count = if dust_here { motes } else { 0 };
        render3d::dust.focus = length(eye - target);
        if focus_on_target { focus_log = log2(length(eye - target) / surfaces::METRE); }
        render3d::lens.focus = exp2(focus_log);
        render3d::lens.aperture = aperture / 100.0;
        render3d::lens.near_cap = near_cap / 100.0;
        render3d::lens.far_cap = far_cap / 100.0;
        if fov_flag > 0.0 { fov = fov_flag; }
        // The near plane farther with the room, so 16-bit depth keeps its panels apart.
        let near: f32 = clamp(0.2 * length(eye - target), 1.0, 12.0);
        let proj = gfx::perspective(fov * PI / 180.0, size.x as f32 / size.y, near, 600.0);
        render3d::scene_pixels = if scene_k > 0.0 { 0.0 } else { scene_budget };
        render3d::scene_scale = if scene_k > 0.0 { scene_k } else { 1.0 };
        render3d::scene_cubic = upscale == 0;
        if load_step < LOAD_STEPS {
            if load_step == 1 { render3d::bake_tree(r3d, g); }
            if load_step == 2 { render3d::room_surfaces(r3d, g); }
            loading_frame(c, scale, load_step as f32 / LOAD_STEPS);
            load_step++;
            if frames == 1 { draughts_first_frame(); }
            continue;
        }
        render3d::base_wood = float4 { base_way as f32, base_wood.y, base_wood.z, base_wood.w };
        render3d::base_look = base_look;
        render3d::draw(r3d, g, gfx::mul(proj, gfx::look_at(eye, target, float3 { 0.0, 1.0, 0.0 })), eye,
                       gfx::screen(), size);
        if walk.on {
            if g.tree_ms != last_tree_ms || g.light_ms != last_light_ms { bakes_walking += 1; }
            if shot < 0 || panel_in_shot {
                walk_text.clear();
                walk_text.append("walking at ");
                tenths(walk_text, walk.eye.x as f64);
                walk_text.append(", ");
                tenths(walk_text, walk.eye.y as f64);
                walk_text.append(", ");
                tenths(walk_text, walk.eye.z as f64);
                walk_text.append(" m");
                if ui::begin(c, "Walk", ui::rect(10.0, 10.0, PANEL_W, 5.0 * ROW + 16.0), ui::WINDOW_NO_INPUT | ui::WINDOW_NO_SCROLLBAR) {
                    note(c, walk_text[..]);
                    if touch {
                        note(c, "left half: walk, from where the finger goes down");
                        note(c, "right half: look");
                        note(c, "Up and Down at the right edge");
                    } else {
                        note(c, "WASD, the mouse; Shift faster; C seated");
                        note(c, "Q down, E up");
                        note(c, "R back to the view; Esc the panel");
                    }
                }
                ui::end(c);
                if touch {
                    let up, down = touch_buttons(gfx::screen_size());
                    let boxed = ui::WINDOW_NO_INPUT | ui::WINDOW_NO_SCROLLBAR | ui::WINDOW_TITLE | ui::WINDOW_BORDER;
                    if ui::begin(c, "Up", ui::rect(up.x / scale, up.y / scale, up.z / scale, up.z / scale), boxed) {}
                    ui::end(c);
                    if ui::begin(c, "Down", ui::rect(down.x / scale, down.y / scale, down.z / scale, down.z / scale), boxed) {}
                    ui::end(c);
                }
            }
        }
        last_tree_ms = g.tree_ms;
        last_light_ms = g.light_ms;
        if meter.on && shot < 0 && !capturing {
            let box_w: f32 = 420.0;
            let at_x = gfx::screen_size().x / scale - box_w - 10.0;
            if ui::begin(c, "Frames (F)", ui::rect(at_x, 10.0, box_w, 2.0 * ROW + 16.0),
                         ui::WINDOW_NO_INPUT | ui::WINDOW_NO_SCROLLBAR) {
                ui::layout_row_dynamic(c, ROW, 1);
                ui::label(c, meter_a[..], ui::TEXT_LEFT);
                ui::layout_row_dynamic(c, ROW, 1);
                ui::label(c, meter_b[..], ui::TEXT_LEFT);
            }
            ui::end(c);
        }
        if !capturing && (shot < 0 || panel_in_shot) { ui::render(c); }
        if capture_frame {
            // Metal records command buffers created and submitted within the capture.
            gfx::flush();
            tuner_capture_stop();
            break;
        }
        if meter.wait { gfx::flush(); }
        if frames == 1 { draughts_first_frame(); }
        meter.in_loop += gfx::time() - frame_at;
    }
}
