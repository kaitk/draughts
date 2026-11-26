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
let VIEWS: View[11] = [
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

// sun_at: the sun's azimuth and height in degrees; window_turn: the window wall's turn.
fn light_of(sun_at: float2, window_turn: f32) -> Light {
    let r = rooms::AUTUMN;
    let l = rooms::toward(sun_at.x, sun_at.y);
    let f = surfaces::frame_of(l, window_turn);
    let room_sun_sat: f32 = 0.6;   // render3d::room_sun.x
    let key = rooms::color_of(r.key_color);
    let y = 0.2126 * key.x + 0.7152 * key.y + 0.0722 * key.z;
    let sun = (float3 { y, y, y } + (key - float3 { y, y, y }) * room_sun_sat) * (r.key.z * r.shell_sun.y);
    let out = float3 { -f.into.x * 0.94, 0.342, -f.into.y * 0.94 };
    return Light { l, sun, sh_at(rooms::harmonics(r), out), float4 { f.along.x, f.along.y, f.into.x, f.into.y } };
}
