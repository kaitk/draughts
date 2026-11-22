// The library's shell (task 109's room, the choices in build/notes/plans/shell.md): its
// four walls with their thickness, the three windows in their niches and the two doors,
// the ceiling's height, and where the games table stands, as fixed data in plan metres.
// shell_mesh.goose builds the walls, wainscot, windows, doors, cornice, ceiling and floor
// from it once, in the room's frame, and the shaders turn it with the room.
//
// The plan: x along the window wall from the stove's end, 0 to 9 m; y from the hall wall
// into the room, 0 to 7 m, the window wall's inner face at y 7. A wall runs from a to b
// along its inner face with the room on its right, so its normal into the room is
// (d.y, -d.x) for its direction d.
namespace room_shell;
import std;
import vec;
import math;

struct Wall { a: float2, b: float2, thick: f32 }

// What an opening is: a window, a door, or an open bookcase built into the wall, which
// stops the wainscot and the wallpaper as a door does.
let WINDOW = 0;
let DOOR = 1;
let BOOKCASE = 2;

// An opening in a wall: its middle along the wall from a, its width (a window's niche, a
// door's clear opening), the sill's height (0 for a door), the height from the sill to the
// springing (a window's casement) or the head (a door) or the top (a bookcase), the arch's
// rise over it (0 flat), and for a window the two glass planes' depths into the wall from
// its inner face, the niche's depth to the outer opening and that opening's width; for a
// bookcase its base's depth out of the wall and its upper case's.
struct Opening {
    wall:   i64,
    mid:    f32,
    width:  f32,
    sill:   f32,
    height: f32,
    rise:   f32,
    glass:  float4,
    kind:   i64,
}

struct Shell {
    walls:    Wall[4],
    openings: Opening[8],
    count:    i64,
    ceiling:  f32,
    table:    float2,  // the games table's middle, the board's: the room's frame's origin
}

// Window B (build/notes/windows/, src/gen.py): the Estonian box window, its inner glass
// 0.4 m into the wall (it opens in), its outer 0.6 m (it opens out); the niche 1.3 m wide
// and 0.65 m deep to the 1.1 m outer opening; the casement 2.5 m over a 0.8 m sill; a
// segmental arch rising 0.25 m (radius 0.97) to 3.55 m.
let WINDOW_GLASS = float4 { 0.4, 0.6, 0.65, 1.1 };

fn window_at(mid: f32) -> Opening {
    Opening { 0, mid, 1.3, 0.8, 2.5, 0.25, WINDOW_GLASS, WINDOW }
}

// Doors 2.7 m high (the user, 2026-11-20): the hall's double door 1.4 m wide in the middle
// of the hall wall, facing the middle window; the salon's 1.3 m at y 1.65 to 2.95 on the
// stove's end wall, near the hall.
fn door_at(wall: i64, mid: f32, width: f32) -> Opening {
    Opening { wall, mid, width, 0.0, 2.7, 0.0, float4_0, DOOR }
}

// The windows' shutters (option A of build/notes/shutters/, 2026-11-21): two leaves a side,
// each SHUTTER_LEAF wide and as tall as the casement, folded flat against the reveal from
// SHUTTER_FROM to SHUTTER_TO (metres into the wall from its face, the lining's front): the
// front leaf, panelled toward the window's middle, hinged on the lining at its back edge,
// the back leaf hinged to its front edge and folded behind it, the stack
// SHUTTER_FRONT + SHUTTER_BACK thick off the reveal, inside the blind frame's 0.16 m, so the
// daylight stays 0.98 m. The middle window's right pair (seen from the room) stands
// SHUTTER_AJAR degrees open. shutters_on false leaves them out (the light tuner's --shutters off), the
// bake with them.
let SHUTTER_FROM:  f32 = 0.02;
let SHUTTER_TO:    f32 = 0.345;
let SHUTTER_LEAF:  f32 = 0.325;
let SHUTTER_FRONT: f32 = 0.030;
let SHUTTER_BACK:  f32 = 0.028;
let SHUTTER_AJAR:  f32 = 14.0;
var shutters_on = true;

// The window wall, the far end, the hall's, the stove's end.
let WINDOW_WALL = 0;
let FAR_WALL = 1;
let HALL_WALL = 2;
let STOVE_WALL = 3;

// The bookcases by the hall door (option B of build/notes/bookcases/, 2026-11-21): two
// tall open oak cases built into the hall wall either side of the door, 1.2 m wide with
// 8 cm of wall to the architrave, a folio base 0.45 m deep whose ledge carries the
// wainscot cap's line at 1.20 m, an upper case 0.30 m deep to 2.84 m, the architrave's
// head (bookcases.goose).
let CASE_WIDTH: f32 = 1.2;
let CASE_TOP:   f32 = 2.84;
let CASE_BASE:  f32 = 0.45;
let CASE_UPPER: f32 = 0.30;

fn bookcase_at(mid: f32) -> Opening {
    Opening { HALL_WALL, mid, CASE_WIDTH, 0.0, CASE_TOP, 0.0, float4 { CASE_BASE, CASE_UPPER, 0.0, 0.0 }, BOOKCASE }
}

// The library: 9 by 7 m inside, the window wall 0.8 m thick, the hall wall 0.6 m, the end
// walls 0.5 m; the ceiling 4 m; the table 1.2 m from the window wall opposite the middle
// window (rooms::AUTUMN's window.x).
let LIBRARY = Shell {
    walls: [
        Wall { float2 { 0.0, 7.0 }, float2 { 9.0, 7.0 }, 0.8 },     // the window wall
        Wall { float2 { 9.0, 7.0 }, float2 { 9.0, 0.0 }, 0.5 },     // the far end
        Wall { float2 { 9.0, 0.0 }, float2 { 0.0, 0.0 }, 0.6 },     // the hall wall
        Wall { float2 { 0.0, 0.0 }, float2 { 0.0, 7.0 }, 0.5 },     // the stove's end
    ],
    openings: [window_at(1.5), window_at(4.5), window_at(7.5), door_at(2, 4.5, 1.4), door_at(3, 2.3, 1.3),
               bookcase_at(2.98), bookcase_at(6.02), window_at(0.0)],
    count:   7,
    ceiling: 4.0,
    table:   float2 { 4.5, 5.8 },
};

// The wainscot (option A of build/notes/wainscot/, at one height as every concept has
// it, 2026-11-21): 1.2 m with its cap on every wall and pier, and under the windows to the
// sill board's foot.
let WAINSCOT_TOP = 1.2;
let SILL_BOARD = 0.05;     // the stone sill's thickness, its top the opening's sill
let SILL_NOSE = 0.08;      // how far it stands out of the wall
let BAND = 0.08;           // the plaster band round the niche, on the wall's face
let BAND_PROUD = 0.015;
// The door's architrave (door 1 of build/notes/windows/doors.html) and its plinth block.
let ARCHITRAVE = 0.14;
let ARCHITRAVE_OUT = 0.05;
let PLINTH_BLOCK = 0.26;
// The cornice (option B of build/notes/ceiling/): 0.26 m down the wall, 0.46 m out on
// the ceiling.
let CORNICE_DROP = 0.26;
let CORNICE_OUT = 0.46;
// The curtains (option A of build/notes/curtains/, curtains.goose): over each window a
// 22 mm brass rod at 3.68 m, 0.12 m off the wall, 1.80 m long on brackets at ±0.82 m,
// 45 mm ball finials; a lace panel each side, 1.20 m of cloth gathered on 0.55 m of rod
// (a rod pocket, its top at 3.70 m), tied back at 0.95 m with a cream cord, knotted, its
// run hanging slack to a small hook at ±0.95 m, 1.0 m up (2026-11-21; at ±0.80 m beside
// the bundle before), its hem about 0.05 m off the floor.
let LACE_ROD = 3.68;
let LACE_OFF = 0.12;
let ROD_HALF = 0.90;
let ROD_RADIUS = 0.011;
let ROD_BRACKET = 0.82;
let FINIAL_RADIUS = 0.0225;
let LACE_TOP = 3.70;
let LACE_HEM = 0.05;
let LACE_FLAT = 1.20;
let LACE_FOLDS = 6;
let TIE_Y = 0.95;
let TIE_HOOK = 0.95;
let TIE_HOOK_Y = 1.0;
// The right panel's outline over its drop (y, metres from the window's middle), the
// left's mirrored: its inner edge, its outer edge, and its middle's distance off the wall,
// keys a Catmull-Rom runs through (curtains.goose). From the rod the inner edge sweeps out
// to the tie, then flares to the hem; the middle stands off the wainscot's cap (9 cm) over
// it. shaders::LIGHT_FN's lace_edges has the edges too, LACE_HUNG_AS_MADE's, its inner
// ones less lace_hang (render3d's shell_mids.w).
let LACE_HUNG_AS_MADE: float2[6] = [float2 { 0.05, 0.585 }, float2 { 0.5, 0.615 }, float2 { 0.95, 0.645 },
                                    float2 { 1.6, 0.58 }, float2 { 2.6, 0.45 }, float2 { 3.7, 0.35 }];
// How much further over the opening the panels' inner edges hang than as made, metres,
// all along the drop and on all three windows, so the low sun reaches their inner folds
// (LACE_HANG; the light tuner's --lace-hang, 0 as made). The outer edges stay, so a panel
// hangs wider and less gathered.
let LACE_HANG: f32 = 0.15;
var lace_hang:  f32       = LACE_HANG;
var LACE_INNER: float2[6] = hung_lace(LACE_HANG);
fn hung_lace(m: f32) -> float2[6] {
    var keys = LACE_HUNG_AS_MADE;
    for i in 6 { keys[i].y -= m; }
    return keys;
}
fn hang_lace(m: f32) {
    lace_hang = m;
    LACE_INNER = hung_lace(m);
    tie_settled = false;
}
let LACE_OUTER: float2[6] = [float2 { 0.05, 0.955 }, float2 { 0.5, 0.89 }, float2 { 0.95, 0.8 }, float2 { 1.6, 0.85 },
                             float2 { 2.6, 0.89 }, float2 { 3.7, 0.9 }];
let LACE_MIDDLE: float2[8] = [float2 { 0.05, 0.135 }, float2 { 0.8, 0.135 }, float2 { 0.95, 0.11 }, float2 { 1.12, 0.15 },
                              float2 { 1.35, 0.155 }, float2 { 1.8, 0.14 }, float2 { 2.6, 0.125 }, float2 { 3.7, 0.12 }];

fn length_of(w: Wall) -> f32 { length(w.b - w.a) }
fn direction(w: Wall) -> float2 { normalize(w.b - w.a) }
fn inward(w: Wall) -> float2 {
    let d = direction(w);
    return float2 { d.y, -d.x };
}

// A point of the plan in the room's frame, world units (surfaces::METRE a metre): u along
// the window wall, growing toward the stove's end (on the right looking out), v into the
// room from the board's middle, as surfaces::Frame has them.
fn room_of(s: Shell, p: float2) -> float2 {
    return float2 { (s.table.x - p.x) * surfaces::METRE, (s.table.y - p.y) * surfaces::METRE }
}

// The arch's radius and its middle's height for an opening with a rise.
fn arch_radius(o: Opening) -> f32 {
    let c = 0.5 * o.width;
    return (c * c + o.rise * o.rise) / (2.0 * o.rise);
}
fn arch_middle(o: Opening) -> f32 { o.sill + o.height + o.rise - arch_radius(o) }

// The height of the opening's soffit at x from its middle (the arch's, or the flat head's).
fn head_at(o: Opening, x: f32) -> f32 {
    let springing = o.sill + o.height;
    guard o.rise > 0.0 && abs(x) < 0.5 * o.width else { return springing; }
    let r = arch_radius(o);
    return arch_middle(o) + sqrt(r * r - x * x);
}

// How far along the wall an opening's surround reaches either side of its middle: a
// window's band, a door's architrave, a bookcase's side.
fn reach(o: Opening) -> f32 {
    if o.kind == BOOKCASE { return 0.5 * o.width; }
    return 0.5 * o.width + (if o.kind == WINDOW { BAND } else { ARCHITRAVE });
}

// The top of the opening's surround: a window's band over the arch's crown, a door's
// architrave over its head.
fn surround_top(o: Opening) -> f32 {
    if o.kind == WINDOW { return o.sill + o.height + o.rise + BAND; }
    if o.kind == BOOKCASE { return o.height; }
    return o.height + ARCHITRAVE;
}
