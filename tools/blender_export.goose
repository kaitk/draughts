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
// --maps on also writes the table's wood maps as the app bakes them on the GPU
// (table_albedo.png, table_normal.png), so open no window: GOOSE_GFX_HEADLESS=1.
//
// The defaults are the tuner's at its default placement (less-turned).
import std;
import os;
import vec;
import math;
import gfx;
import model3d from "../src/model3d";
import render3d from "../src/render3d";
import .room_scene;

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

// The uv TABLE_FRAG reads the table's maps at, a vertex (unturned, the board's world), with
// v flipped for Blender (its pictures' rows bottom up): the top seen from above; the edge and
// the frieze unrolled round the table; the base its own way (render3d::base_wood x 1): the
// column's grain up its axis, each leg's along it; the chairs the plain base's.
fn table_uv(v: mesh::Vertex) -> float2 {
    let R = mesh::TABLE_MAP_R;
    let p = v.pos;
    let out_dir = float2 { p.x, p.z - mesh::TABLE_Z };
    let from_mid = max(length(out_dir), 0.001);
    let base = v.mat > 3.5;
    let chair = v.mat > 4.5;
    let top = v.normal.y > 0.999 && p.y > mesh::TABLE_TOP - 0.01 && !base;
    var uv = if top { out_dir / (2.0 * R) + float2 { 0.5, 0.5 } }
             else { float2 { 0.3 + (v.uv.y - R) / (2.0 * R), v.uv.x / (2.0 * PI * from_mid) * 3.0 } };
    if base { uv = float2 { 0.2, 0.15 } + v.uv / (2.0 * R); }
    let bw = render3d::base_wood;
    let bl = render3d::base_look;
    if base && !chair && bw.x > 0.5 {
        let up_mm = (p.y - surfaces::FLOOR_Y) / M * 1000.0;
        let out_mm = from_mid / M * 1000.0;
        let column = up_mm > 240.0 || out_mm < 72.5 || (up_mm > 212.0 && out_mm < 83.5);
        let r0 = 0.08 * M;
        let along = if column { p.y - surfaces::FLOOR_Y } else { v.uv.y };
        let angle = atan2(out_dir.y, out_dir.x);
        let across = if column { abs(angle) * r0 + bl.y * (from_mid - r0) + tan(radians(bl.x)) * along }
                     else { v.uv.x + 2.3 * floor(angle / (0.5 * PI)) };
        uv = float2 { bl.z + across / (2.0 * R), 0.15 + along / (2.0 * R * bw.w) };
    }
    return float2 { uv.x, 1.0 - uv.y };
}

// The table's maps baked as the tuner bakes them (its put_look at autumn, the flame
// mahogany, tables::for_look) and saved as PNG: the albedo sRGB with the polish's roughness
// in alpha, the normal's x and z in r and g (0.5 flat), the wear's patches in b.
fn write_maps(out_dir: const u8[:]) {
    guard gfx::open("Draughts: the table's maps", 64, 64, 0) else { abort(str("gfx: ", gfx::error())); }
    defer gfx::close();
    var g = default<render3d::Gpu>();
    var r3d = default<render3d::Own>();
    render3d::setup(r3d, g, render3d::SAMPLES, render3d::SHADOW_16);
    render3d::choose(g, -1, looks::MARBLE, looks::SPRING_LOOK);
    g.table = true;
    g.table_spec = tables::get(tables::for_look(looks::AUTUMN));
    let look = looks::of(looks::AUTUMN, looks::MATERIAL_AUTO);
    let shown = looks::shown(look, g.spring);
    let own = looks::wood_for(shown);
    render3d::choose(g, if own >= 0 { own } else { model3d::WOOD_MODEL }, -1);
    g.finish = looks::finish_for(shown, g.wood);
    g.look = -1;
    render3d::apply(r3d, g, look, 8);
    guard gfx::save_png(g.table_albedo, str(out_dir, "/table_albedo.png")[..]) &&
          gfx::save_png(g.table_normal, str(out_dir, "/table_normal.png")[..]) else { abort(str("could not save the maps: ", gfx::error())); }
    print("wrote ", out_dir, "/table_albedo.png and table_normal.png");
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
fn put4(out: u8[>..]&, v: float4) { format(out, "[", v.x, ", ", v.y, ", ", v.z, ", ", v.w, "]"); }

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
    if switch(argv, "--maps", false) { write_maps(out_dir); }

    // The room as the tuner lights it (room_scene::light_of).
    let r = rooms::AUTUMN;
    let light = room_scene::light_of(sun_at, window_turn);
    axes = light.axes;

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
    // The maps' uv where TABLE_FRAG reads them, before the turn (it reads the top turned back).
    for &v in pv { v.uv = table_uv(v); }
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
    let table_count = pv.len;
    if chairs { mesh::chairs(pv, pi, surfaces::FLOOR_Y + (if rug { rug_thick * M } else { 0.0 })); }
    // The chairs' wood reads the table's maps as the base did (TABLE_FRAG); their cloth keeps
    // its uv (world units, the tapestry's tile).
    for i in pv.len - table_count {
        let k = table_count + i;
        if pv[k].mat < 5.5 { pv[k].uv = table_uv(pv[k]); }
    }
    add(pv, pi, false, true);
    // The rug (ROOM_FRAG's RUG_HALF, RUG_IN): 3 by 2 m along the window wall, its middle
    // 0.1 m from the table's into the room.
    if rug { add_rug(from_plan(float3 { table_at.x, table_at.y - 0.1, 0.0 }), float2 { 1.5, 1.0 }, rug_thick); }

    write_obj(str(out_dir, "/room.obj")[..]);

    let sun_light = light.sun;
    let toward_room = room_from_world(light.toward);
    let sky = light.sky;

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
    format(j, "\n  },\n");
    // The gloss as the shaders take it (ROOM_FRAG, TABLE_FRAG), each a roughness (squared
    // for GGX's alpha) or a colour at normal incidence (sRGB).
    let look = surfaces::LOOK;
    let t = tables::get(tables::for_look(looks::AUTUMN));
    format(j, "  \"gloss\": {\n");
    format(j, "    \"floor_rough\": ", surfaces::FLOOR_OAK.base.w, ",\n    \"floor_wax\": ", r.planar.x,
           ",\n    \"floor_wax_rough\": ", surfaces::FLOOR_OAK.base.w * r.planar.y, ",\n");
    format(j, "    \"oak_rough\": ", surfaces::WALL_OAK.base.w, ",\n    \"paper_rough\": ", look.paper.w,
           ",\n    \"gold_rough\": ", look.gold.w, ",\n");
    format(j, "    \"plaster_rough\": ", 0.5 * (look.plaster_shade.w + look.plaster_light.w), ",\n    \"ceiling_rough\": ",
           0.5 * (look.ceiling_shade.w + look.ceiling_light.w), ",\n");
    format(j, "    \"paint_rough\": ", look.paint_quiet.x, ",\n    \"window_paint_rough\": ", look.paint_quiet.y,
           ",\n    \"stone_rough\": ", look.stone.w, ",\n");
    format(j, "    \"brass\": ");
    put4(j, look.brass);
    format(j, ",\n    \"table_top_rough\": ", t.wood.w, ",\n    \"table_coat\": ");
    put4(j, t.coat);
    format(j, ",\n    \"table_polish\": ");
    put4(j, t.polish);
    format(j, ",\n    \"base_wood\": ");
    put4(j, render3d::base_wood);
    format(j, ",\n    \"base_look\": ");
    put4(j, render3d::base_look);
    format(j, "\n  },\n  \"views\": {\n");
    for v, i in room_scene::VIEWS {
        format(j, "    \"", v.name[..], "\": {\"eye\": ");
        put3(j, from_plan(v.eye));
        format(j, ", \"at\": ");
        put3(j, from_plan(v.at));
        format(j, ", \"fov\": ", v.fov, "}", if i + 1 < room_scene::VIEWS.len { "," } else { "" }, "\n");
    }
    format(j, "  }\n}\n");
    guard write_file(str(out_dir, "/scene.json")[..], j[..]) else { abort("could not write scene.json"); }
    print("sun toward (room) ", toward_room.x, " ", toward_room.y, " ", toward_room.z, "; light ", sun_light.x, " ",
          sun_light.y, " ", sun_light.z, "; sky ", sky.x, " ", sky.y, " ", sky.z);
    print("wrote ", out_dir, "/room.obj and scene.json");
}
