// The library room as the light tuner shows it, for Blender (tools/blender/README.md):
// the shell with its joinery, bookcases, books, stove and curtains, the window's glass and
// lace, the rug, the games table and its two chairs, as an OBJ with an object a part and
// material, its uvs kept; and scene.json beside it with the sun, the sky, the albedos and
// the tuner's named views. All in one frame: metres, z up, the table's middle on the floor
// at the origin, x = the table's plan x less the plan's x, y = the plan's y less the
// table's (a turn of the room's frame, not a mirror; the plan's frame is mirrored).
//
//   goose build -o build/blender/export tools/blender_export.goose
//   build/blender/export [--out build/blender] [--table-at 4.4,5.8] [--sun AZ,HEIGHT (0,15)]
//       [--window-turn DEG (12)] [--table-turn DEG (25)] [--lace-hang M (0.15)] [--books on|off]
//       [--chairs on|off] [--rug on|off]
//
// The defaults are the tuner's at its default placement (less-turned).
import std;
import os;
import vec;
import math;
import model3d from "../src/model3d";

let M: f32 = 30.48;   // surfaces::METRE

var table_at = float2 { 4.4, 5.8 };
var axes = float4_0;  // the room's frame: along.x, along.y, into.x, into.y

// A plan point (metres) into the export's frame.
fn from_plan(p: float3) -> float3 { float3 { table_at.x - p.x, p.y - table_at.y, p.z } }
// A room-frame point (world units, ROOM_VERT's v_local) and direction into the export's frame.
fn from_room(p: float3) -> float3 { float3 { p.x / M, -p.z / M, (p.y - surfaces::FLOOR_Y) / M } }
fn dir_from_room(n: float3) -> float3 { float3 { n.x, -n.z, n.y } }
// The board's world into the room's frame (the inverse of ROOM_VERT's turn).
fn room_from_world(p: float3) -> float3 {
    float3 { axes.x * p.x + axes.y * p.z, p.y, axes.z * p.x + axes.w * p.z }
}

fn flag_value(argv: u8[:][>..]&, name: const u8[:]) -> i64 {
    for a, i in argv { if a == name && i + 1 < argv.len { return i + 1; } }
    return -1;
}
fn number(argv: u8[:][>..]&, name: const u8[:], otherwise: f32) -> f32 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    let v, ok = parse_flt(argv[at]);
    guard ok else { abort(str(name, ": a number")); }
    return v as f32;
}
fn two(argv: u8[:][>..]&, name: const u8[:], otherwise: float2) -> float2 {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    let a, b, more = split_once(argv[at], ",");
    let x, ok_x = parse_flt(a);
    let y, ok_y = parse_flt(b);
    guard more && ok_x && ok_y else { abort(str(name, ": two numbers, a,b")); }
    return float2 { x as f32, y as f32 };
}
fn switch(argv: u8[:][>..]&, name: const u8[:], otherwise: bool) -> bool {
    let at = flag_value(argv, name);
    guard at > 0 else { return otherwise; }
    return argv[at] == "on";
}

// One mesh in the export's frame: positions, normals, uvs as made, and each triangle's part.
struct Part { name: u8[..32], kind: f32 }
var pos:   float3[>..] = [];
var nrm:   float3[>..] = [];
var uvs:   float2[>..] = [];
var tris:  u32[>..]    = [];
var part:  i64[>..]    = [];  // a triangle's
var parts: Part[>..]   = [];

fn part_of(name: const u8[:], kind: f32) -> i64 {
    for p, i in parts { if p.name[..] == name { return i; } }
    var n: u8[..32] = [];
    n.append(name);
    parts.push(Part { n, kind });
    return parts.len - 1;
}

// The shell's material kinds (surfaces::MAT_*) by name; the plaster facing down is the ceiling.
fn shell_part(kind: i64, n: float3) -> i64 {
    return match kind {
        4 => part_of("floor", 4.0),
        5 => part_of("oak", 5.0),
        6 => part_of("paper", 6.0),
        7 => part_of("stone", 7.0),
        8 => if n.z < -0.7 { part_of("ceiling", 8.0) } else { part_of("plaster", 8.0) },
        9 => part_of("paint", 9.0),
        10 => part_of("glass", 10.0),
        11 => part_of("lace", 11.0),
        12 => part_of("brass", 12.0),
        13 => part_of("cord", 13.0),
        14 => part_of("books", 14.0),
        15 => part_of("stove_tile", 15.0),
        _ => part_of(str("shell_kind_", kind)[..], kind),
    };
}
fn prop_part(kind: i64) -> i64 {
    return match kind {
        3 => part_of("table_top", 3.0),
        4 => part_of("table_base", 4.0),
        5 => part_of("chair_wood", 5.0),
        6 => part_of("chair_seat", 6.0),
        7 => part_of("chair_trim", 7.0),
        _ => part_of(str("prop_kind_", kind)[..], kind),
    };
}

// Adds a mesh: room: the shell's frame (else the board's world).
fn add(verts: mesh::Vertex[>..]&, indices: u32[>..]&, room: bool, props: bool) {
    let first = pos.len;
    for v in verts {
        let p = if room { v.pos } else { room_from_world(v.pos) };
        let n = if room { v.normal } else { room_from_world(v.normal) };
        pos.push(from_room(p));
        nrm.push(normalize(dir_from_room(n)));
        uvs.push(v.uv);
    }
    for t in indices.len / 3 {
        let a = indices[3 * t];
        let v = verts[a as i64];
        let kind = floor(v.mat + 0.001) as i64;
        part.push(if props { prop_part(kind) } else { shell_part(kind, nrm[first + a]) });
        // Wound to face its normals: the app draws both sides and its winding varies, but a
        // path tracer flips the normal on a back face, which turns a lit surface black.
        let i0 = first + indices[3 * t];
        var i1 = first + indices[3 * t + 1];
        var i2 = first + indices[3 * t + 2];
        let face = cross(pos[i1] - pos[i0], pos[i2] - pos[i0]);
        if dot(face, nrm[i0] + nrm[i1] + nrm[i2]) < 0.0 {
            let k = i1;
            i1 = i2;
            i2 = k;
        }
        tris.append([i0 as u32, i1 as u32, i2 as u32]);
    }
}

// A box on the floor, its top's uv 0..1 (the rug, x along the window wall).
fn add_rug(mid: float3, half: float2, thick: f32) {
    let k = part_of("rug", 20.0);
    let x0 = mid.x - half.x;
    let x1 = mid.x + half.x;
    let y0 = mid.y - half.y;
    let y1 = mid.y + half.y;
    let faces: float3[6] = [float3 { 0.0, 0.0, 1.0 }, float3 { 0.0, 0.0, -1.0 }, float3 { 1.0, 0.0, 0.0 },
                            float3 { -1.0, 0.0, 0.0 }, float3 { 0.0, 1.0, 0.0 }, float3 { 0.0, -1.0, 0.0 }];
    for n in faces {
        // Four corners of the face, counter-clockwise seen from outside.
        var c: float3[4] = [float3_0; 4];
        let lo = float3 { x0, y0, 0.0 };
        let hi = float3 { x1, y1, thick };
        if n.z != 0.0 {
            let z = if n.z > 0.0 { thick } else { 0.0 };
            c = [float3 { x0, y0, z }, float3 { x1, y0, z }, float3 { x1, y1, z }, float3 { x0, y1, z }];
        } else if n.x != 0.0 {
            let x = if n.x > 0.0 { hi.x } else { lo.x };
            c = [float3 { x, y0, 0.0 }, float3 { x, y1, 0.0 }, float3 { x, y1, thick }, float3 { x, y0, thick }];
        } else {
            let y = if n.y > 0.0 { hi.y } else { lo.y };
            c = [float3 { x0, y, 0.0 }, float3 { x1, y, 0.0 }, float3 { x1, y, thick }, float3 { x0, y, thick }];
        }
        // Wind them to face n.
        let wound = dot(cross(c[1] - c[0], c[2] - c[0]), n) > 0.0;
        let first = pos.len;
        for q in c {
            pos.push(q);
            nrm.push(n);
            uvs.push(float2 { (q.x - x0) / (x1 - x0), (q.y - y0) / (y1 - y0) });
        }
        let order: i64[6] = if wound { [0, 1, 2, 0, 2, 3] } else { [0, 2, 1, 0, 3, 2] };
        for e in 6 { tris.push((first + order[e]) as u32); }
        part.push(k);
        part.push(k);
    }
}

fn write_obj(path: const u8[:]) {
    var out: u8[>..] = [];
    format(out, "# Draughts' library room (tools/blender_export.goose): metres, z up, the table at the origin\n");
    var local: i64[>..] = [];
    for i in pos.len { local.push(-1); }
    var base: i64 = 0;
    for p, k in parts {
        format(out, "o ", p.name[..], "\nusemtl ", p.name[..], "\n");
        var count: i64      = 0;
        var order: u32[>..] = [];
        for t in part.len {
            guard part[t] == k else { continue; }
            for e in 3 {
                let v = tris[3 * t + e] as i64;
                if local[v] < 0 {
                    local[v] = base + count;
                    count += 1;
                    order.push(v as u32);
                }
            }
        }
        for v in order {
            let q = pos[v as i64];
            format(out, "v ", q.x, " ", q.y, " ", q.z, "\n");
        }
        for v in order {
            let t = uvs[v as i64];
            format(out, "vt ", t.x, " ", t.y, "\n");
        }
        for v in order {
            let n = nrm[v as i64];
            format(out, "vn ", n.x, " ", n.y, " ", n.z, "\n");
        }
        for t in part.len {
            guard part[t] == k else { continue; }
            format(out, "f");
            for e in 3 {
                let i = local[tris[3 * t + e] as i64] + 1;
                format(out, " ", i, "/", i, "/", i);
            }
            format(out, "\n");
        }
        for v in order { local[v as i64] = -1; }
        base += count;
        print(p.name[..], ": ", count, " vertices");
    }
    guard write_file(path, out[..]) else { abort(str("could not write ", path)); }
}

fn put3(out: u8[>..]&, v: float3) { format(out, "[", v.x, ", ", v.y, ", ", v.z, "]"); }

// The tuner's named views (light_tune's VIEW_EYES, PLACE_EYE at less-turned, and the
// shots' --plan-eye framings in agents/perf.md and build/props-light/shots.sh), each its
// eye, its target (plan metres) and vertical field of view.
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

fn sh_at(sh: float4[9], d: float3) -> float3 {
    let b: f32[9] = [0.282095, 0.488603 * d.y, 0.488603 * d.z, 0.488603 * d.x, 1.092548 * d.x * d.y, 1.092548 * d.y * d.z,
                     0.315392 * (3.0 * d.y * d.y - 1.0), 1.092548 * d.x * d.z, 0.546274 * (d.x * d.x - d.z * d.z)];
    var c = float3_0;
    for i in 9 { c = c + float3 { sh[i].x, sh[i].y, sh[i].z } * b[i]; }
    return float3 { max(c.x, 0.0), max(c.y, 0.0), max(c.z, 0.0) };
}

fn main() {
    var argv = args();
    let at = flag_value(argv, "--out");
    let out_dir: const u8[:] = if at > 0 { argv[at][..] } else { "build/blender" };
    table_at = two(argv, "--table-at", table_at);
    let sun_at = two(argv, "--sun", float2 { 0.0, 15.0 });
    let window_turn = number(argv, "--window-turn", 12.0);
    let table_turn = number(argv, "--table-turn", 25.0);
    let books = switch(argv, "--books", true);
    let chairs = switch(argv, "--chairs", true);
    let rug = switch(argv, "--rug", true);
    room_shell::hang_lace(number(argv, "--lace-hang", room_shell::LACE_HANG));
    room_shell::LIBRARY.table = table_at;
    guard make_dir(out_dir) else { abort(str("could not make ", out_dir)); }

    // The room as the tuner lights it (rooms::AUTUMN with the placement's sun): the key
    // toward the sun in the board's world, the room's frame from it and the window's turn.
    let r = rooms::AUTUMN;
    let l = rooms::toward(sun_at.x, sun_at.y);
    let f = surfaces::frame_of(l, window_turn);
    axes = float4 { f.along.x, f.along.y, f.into.x, f.into.y };

    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    var glass:   mesh::Vertex[>..] = [];
    var gi:      u32[>..]          = [];
    room_shell::build(verts, indices, glass, gi, room_shell::LIBRARY, books);
    add(verts, indices, true, false);
    add(glass, gi, true, false);

    var pv: mesh::Vertex[>..] = [];
    var pi: u32[>..]          = [];
    mesh::table(pv, pi, float4 { 3.0, 0.9, 0.38, 1.4 }, mesh::TABLE_R, surfaces::FLOOR_Y);
    let a = radians(table_turn);
    let c = cos(a);
    let s = sin(a);
    for &v in pv {
        let x = v.pos.x;
        let z = v.pos.z - mesh::TABLE_Z;
        v.pos.x = c * x - s * z;
        v.pos.z = s * x + c * z + mesh::TABLE_Z;
        let nx = v.normal.x;
        v.normal.x = c * nx - s * v.normal.z;
        v.normal.z = s * nx + c * v.normal.z;
    }
    // The chairs stand on the rug's top (render3d::CHAIR_RUG_LIFT, ROOM_FRAG's RUG_THICK).
    let rug_thick: f32 = 0.008;
    if chairs { mesh::chairs(pv, pi, surfaces::FLOOR_Y + (if rug { rug_thick * M } else { 0.0 })); }
    add(pv, pi, false, true);
    // The rug (ROOM_FRAG's RUG_HALF, RUG_IN): 3 by 2 m along the window wall, its middle
    // 0.1 m from the table's into the room.
    if rug { add_rug(from_plan(float3 { table_at.x, table_at.y - 0.1, 0.0 }), float2 { 1.5, 1.0 }, rug_thick); }

    write_obj(str(out_dir, "/room.obj")[..]);

    // The light (render3d::bake_room_light): the sun toward it, its light on a plane facing
    // it (irradiance; the shaders divide by pi), the sky's radiance through the windows (the
    // room's harmonics toward the window 20 degrees up) before the bake's gain.
    let room_sun_sat: f32 = 0.6;   // render3d::room_sun.x
    let key = rooms::color_of(r.key_color);
    let y = 0.2126 * key.x + 0.7152 * key.y + 0.0722 * key.z;
    let sun_light = (float3 { y, y, y } + (key - float3 { y, y, y }) * room_sun_sat) * (r.key.z * r.shell_sun.y);
    let toward_room = float3 { l.x * f.along.x + l.z * f.along.y, l.y, l.x * f.into.x + l.z * f.into.y };
    let out = float3 { -f.into.x * 0.94, 0.342, -f.into.y * 0.94 };
    let sky = sh_at(rooms::harmonics(r), out);

    var j: u8[>..] = [];
    format(j, "{\n  \"frame\": \"metres, z up, the table's middle on the floor at the origin; x = table x - plan x, y = plan y - table y\",\n");
    format(j, "  \"table_at\": [", table_at.x, ", ", table_at.y, "],\n");
    format(j, "  \"sun_toward\": ");
    put3(j, normalize(dir_from_room(toward_room)));
    format(j, ",\n  \"sun_irradiance\": ");
    put3(j, sun_light);
    format(j, ",\n  \"sky_radiance\": ");
    put3(j, sky);
    format(j, ",\n  \"sky_gain\": ", r.baked.x, ",\n  \"bounce_gain\": ", r.baked.y, ",\n");
    // The shell's walls and the windows' outer openings (room_shell::WINDOW_GLASS), for a
    // closed box round the room that lets light in only through the windows.
    let lib = room_shell::LIBRARY;
    let mids = room_light::window_mids();
    let wall = lib.walls[room_shell::WINDOW_WALL];
    format(j, "  \"ceiling\": ", lib.ceiling, ",\n  \"window_wall_outer_y\": ", wall.a.y + wall.thick - table_at.y, ",\n");
    let o = room_shell::window_at(mids.x);
    format(j, "  \"windows\": {\"x\": [", table_at.x - mids.x, ", ", table_at.x - mids.y, ", ", table_at.x - mids.z,
           "], \"width\": ", room_shell::WINDOW_GLASS.w, ", \"sill\": ", o.sill, ", \"top\": ", o.sill + o.height + o.rise, "},\n");
    format(j, "  \"glazing\": ", room_light::GLAZING, ",\n  \"lace_lets\": ", room_light::LACE_LETS, ",\n");
    format(j, "  \"lace_scatter\": ", room_light::LACE_SCATTER, ",\n");
    format(j, "  \"albedo\": {\n");
    let albedos: float3[9] = [room_light::FLOOR_ALBEDO, room_light::OAK_ALBEDO, room_light::PAPER_ALBEDO,
                              room_light::STONE_ALBEDO, room_light::PLASTER_ALBEDO, room_light::CEILING_ALBEDO,
                              room_light::PAINT_ALBEDO, room_light::CASE_ALBEDO, room_light::STOVE_ALBEDO];
    let names = ["floor", "oak", "paper", "stone", "plaster", "ceiling", "paint", "books", "stove_tile"];
    for n, i in names {
        format(j, "    \"", n, "\": ");
        put3(j, albedos[i]);
        format(j, ",\n");
    }
    format(j, "    \"table\": ");
    put3(j, room_light::TABLE_ALBEDO);
    format(j, "\n  },\n  \"views\": {\n");
    for v, i in VIEWS {
        format(j, "    \"", v.name[..], "\": {\"eye\": ");
        put3(j, from_plan(v.eye));
        format(j, ", \"at\": ");
        put3(j, from_plan(v.at));
        format(j, ", \"fov\": ", v.fov, "}", if i + 1 < VIEWS.len { "," } else { "" }, "\n");
    }
    format(j, "  }\n}\n");
    guard write_file(str(out_dir, "/scene.json")[..], j[..]) else { abort("could not write scene.json"); }
    print("sun toward (room) ", toward_room.x, " ", toward_room.y, " ", toward_room.z, "; light ", sun_light.x, " ",
          sun_light.y, " ", sun_light.z, "; sky ", sky.x, " ", sky.y, " ", sky.z);
    print("wrote ", out_dir, "/room.obj and scene.json");
}
