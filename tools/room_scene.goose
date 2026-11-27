// The library room's light and the tuner's named views, for the tools that rebuild the room
// outside the app: tools/blender_export.goose and tools/path_trace.goose.
namespace room_scene;
import std;
import vec;
import math;

// The tuner's named views (light_tune's VIEW_EYES, PLACE_EYE at less-turned, and the
// shots' --plan-eye framings in agents/perf.md), each its eye, its target (plan metres) and
// vertical field of view.
struct View { name: u8[..16], eye: float3, at: float3, fov: f32 }
let VIEWS: View[15] = [
    View { "down", float3 { 6.0, 3.0, 1.7 }, float3 { 6.0, 3.05, 0.0 }, 55.0 },
    View { "corner", float3 { 8.4, 0.6, 1.6 }, float3 { 2.0, 5.0, 0.5 }, 55.0 },
    View { "room", float3 { 8.4, 0.6, 1.7 }, float3 { 2.6, 5.8, 1.3 }, 60.0 },
    View { "window", float3 { 4.5, 1.0, 1.6 }, float3 { 4.5, 7.0, 1.8 }, 60.0 },
    View { "hall", float3 { 4.5, 6.3, 1.6 }, float3 { 4.5, 0.0, 1.3 }, 60.0 },
    View { "stove", float3 { 8.3, 3.5, 1.6 }, float3 { 0.0, 3.0, 1.4 }, 60.0 },
    View { "menu", float3 { 4.037, 3.75, 1.6 }, float3 { 4.245, 6.737, 1.426 }, 60.0 },
    View { "front", float3 { 4.4, 3.6, 1.4 }, float3 { 4.4, 5.8, 0.5 }, 55.0 },
    View { "close", float3 { 2.9, 4.8, 1.15 }, float3 { 3.55, 5.75, 0.55 }, 55.0 },
    View { "low", float3 { 6.3, 4.6, 0.35 }, float3 { 5.3, 5.8, 0.45 }, 55.0 },
    View { "base", float3 { 5.75, 4.75, 0.62 }, float3 { 4.5, 5.8, 0.36 }, 42.0 },
    View { "joint", float3 { 4.9, 4.9, 0.45 }, float3 { 4.254, 5.83, 0.62 }, 40.0 },
    View { "casement", float3 { 4.2, 6.15, 1.3 }, float3 { 4.75, 7.6, 1.55 }, 50.0 },
    View { "reference", float3 { 6.5, 4.3, 1.4 }, float3 { 2.655, 5.403, 1.4 }, 73.0 },
    View { "niche", float3 { 4.3, 6.8, 2.2 }, float3 { 4.5, 7.4, 2.42 }, 22.0 },
];

// The view of that name; false if there is none.
fn view_named(name: const u8[:]) -> View, bool {
    for v in VIEWS { if v.name[..] == name { return v, true; } }
    return VIEWS[0], false;
}

// The room's light as the tuner bakes it (render3d::bake_room_light, rooms::AUTUMN with the
// placement's sun): toward the sun in the board's world, the sun's light on a plane facing
// it (the shaders' sun.light, irradiance), the sky's radiance through the windows (the
// room's harmonics toward the window 20 degrees up) before the bake's sky gain, and the
// room's frame (along.x, along.y, into.x, into.y).
struct Light { toward: float3, sun: float3, sky: float3, axes: float4 }

fn sh_at(sh: float4[9], d: float3) -> float3 {
    let b: f32[9] = [0.282095, 0.488603 * d.y, 0.488603 * d.z, 0.488603 * d.x, 1.092548 * d.x * d.y, 1.092548 * d.y * d.z,
                     0.315392 * (3.0 * d.y * d.y - 1.0), 1.092548 * d.x * d.z, 0.546274 * (d.x * d.x - d.z * d.z)];
    var c = float3_0;
    for i in 9 { c = c + float3 { sh[i].x, sh[i].y, sh[i].z } * b[i]; }
    return float3 { max(c.x, 0.0), max(c.y, 0.0), max(c.z, 0.0) };
}

// The sun's colour as the tuner's --light physical takes it (its --sun-color): by its height
// through a clear sky (rooms::sun_color_at), or the key's at 0.6 of its saturation; either at
// the key's luminance.
var sun_by_height = true;
// The sun as the tuner's --light physical has it in autumn (light_tune's PHYSICAL_SUN): x its
// strength over the clear sky's, y the height in degrees its colour is taken as (below 0 the
// sun's own height).
var sun_take = float2 { 0.25, 8.0 };

// sun_at: the sun's azimuth and height in degrees; window_turn: the window wall's turn.
fn light_of(sun_at: float2, window_turn: f32) -> Light {
    let r = rooms::AUTUMN;
    let l = rooms::toward(sun_at.x, sun_at.y);
    let f = surfaces::frame_of(l, window_turn);
    let room_sun_sat: f32 = 0.6;   // render3d::ROOM_SUN_AS_MADE.x
    let key = rooms::color_of(r.key_color);
    let y = 0.2126 * key.x + 0.7152 * key.y + 0.0722 * key.z;
    let grey = float3 { y, y, y };
    let height = if sun_take.y >= 0.0 { sun_take.y } else { sun_at.y };
    let color = if sun_by_height { rooms::sun_color_at(height) * y } else { grey + (key - grey) * room_sun_sat };
    let sun = color * (r.key.z * r.shell_sun.y * sun_take.x);
    let out = float3 { -f.into.x * 0.94, 0.342, -f.into.y * 0.94 };
    return Light { l, sun, sh_at(rooms::harmonics(r), out), float4 { f.along.x, f.along.y, f.into.x, f.into.y } };
}

// The backs of the windows' casements (room_shell::casement_members' outward faces), as paint
// in the room's frame, into verts and indices: the room's mesh draws only the faces that show
// from the room, which leaves each member's box open toward the outside, and the space between
// the panes too dark (task 122). The lunette, the last member, is the wall's own.
fn casement_backs(verts: mesh::Vertex[>..]&, indices: u32[>..]&) {
    let s = room_shell::LIBRARY;
    let face = s.walls[room_shell::WINDOW_WALL].a.y;
    let out = float3 { 0.0, 0.0, -1.0 };    // the plan's +y in the room's frame
    for o in room_light::windows() {
        let boxes = room_shell::casement_members(o);
        for b, n in boxes {
            guard n < boxes.len - 1 else { continue; }
            let y = face - b.lo.z;
            let first = verts.len as u32;
            for c in 4 {
                let x = if c == 1 || c == 2 { b.hi.x } else { b.lo.x };
                let h = if c >= 2 { b.hi.y } else { b.lo.y };
                let p = float3 { (s.table.x - (o.mid + x)) * surfaces::METRE, surfaces::FLOOR_Y + h * surfaces::METRE, (s.table.y - y) * surfaces::METRE };
                verts.push(mesh::Vertex { p, out, float2_0, 1.0, surfaces::MAT_PAINT + 0.2 });
            }
            indices.append([first, first + 1, first + 2, first, first + 2, first + 3]);
        }
    }
}
