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

// What an opening is.
let WINDOW = 0;
let DOOR = 1;

// An opening in a wall: its middle along the wall from a, its width (a window's niche, a
// door's clear opening), the sill's height (0 for a door), the height from the sill to the
// springing (a window's casement) or the head (a door), the arch's rise over it (0 flat),
// and for a window the two glass planes' depths into the wall from its inner face, the
// niche's depth to the outer opening and that opening's width.
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
               window_at(0.0), window_at(0.0), window_at(0.0)],
    count:   5,
    ceiling: 4.0,
    table:   float2 { 4.5, 5.8 },
};

// The window wall, the far end, the hall's, the stove's end.
let WINDOW_WALL = 0;
let FAR_WALL = 1;
let HALL_WALL = 2;
let STOVE_WALL = 3;

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
// The lace (build/notes/windows/): on a brass rod 0.12 m off the wall at 3.68 m, out to
// 0.22 m past the band either side.
let LACE_ROD = 3.68;
let LACE_OFF = 0.12;
let LACE_PAST = 0.22;

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
// window's band, a door's architrave.
fn reach(o: Opening) -> f32 { 0.5 * o.width + (if o.kind == WINDOW { BAND } else { ARCHITRAVE }) }

// The top of the opening's surround: a window's band over the arch's crown, a door's
// architrave over its head.
fn surround_top(o: Opening) -> f32 {
    if o.kind == WINDOW { return o.sill + o.height + o.rise + BAND; }
    return o.height + ARCHITRAVE;
}
