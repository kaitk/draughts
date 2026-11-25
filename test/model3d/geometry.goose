// The shaders' GLSL repeats the 3D board's measures from src/model3d/mesh.goose as
// `const float NAME = value;` (embed_shader takes only a literal); each must equal the
// mesh's, or the lit shader's field, frame, and pieces stop where the meshes don't; the
// room's floor its strips' count (src/model3d/surfaces.goose), and where the chairs stand
// (mesh::CHAIRS, the floor's CHAIR_A and CHAIR_B as `const vec4 NAME = vec4(...);`).
import std;
import vec;
import model3d from "../../src/model3d";

// The value of `const float NAME = X;` in the text, and whether there is one.
fn constant(text: const u8[:], name: const u8[:]) -> f64, bool {
    let key = str("const float ", name, " = ");
    var rest: const u8[:] = text;
    while rest.len > 0 {
        let line, after, more = split_once(rest, "\n");
        let t = trim(line);
        if t.len > key.len && t[..key.len] == key[..] {
            let v, end, found = split_once(t[key.len..], ";");
            let x, ok = parse_flt(v);
            return x, found && ok;
        }
        rest = if more { after } else { "" };
    }
    return 0.0, false;
}

// The four values of `const vec4 NAME = vec4(a, b, c, d);` in the text, and whether there is one.
fn vec4_constant(text: const u8[:], name: const u8[:]) -> float4, bool {
    let key = str("const vec4 ", name, " = vec4(");
    var rest: const u8[:] = text;
    while rest.len > 0 {
        let line, after, more = split_once(rest, "\n");
        let t = trim(line);
        if t.len > key.len && t[..key.len] == key[..] {
            var v:  const u8[:] = t[key.len..];
            var xs: f32[4]      = [0.0; 4];
            for i in 4 {
                let part, next, found = split_once(v, if i < 3 { "," } else { ")" });
                let x, ok = parse_flt(trim(part));
                guard found && ok else { return float4_0, false; }
                xs[i] = x as f32;
                v = next;
            }
            return float4 { xs[0], xs[1], xs[2], xs[3] }, true;
        }
        rest = if more { after } else { "" };
    }
    return float4_0, false;
}

fn main() {
    // The measures' files: FRAME's board, TABLE_FRAG's table, ROOM_FRAG's floor.
    let text = str(embed_file("../../src/render3d/shaders/frame.goose"), embed_file("../../src/render3d/shaders/table.goose"),
                   embed_file("../../src/render3d/shaders/room.goose"));
    let names = ["FIELD", "INNER", "FRAME_W", "FRAME_TOP", "BOTTOM", "RADIUS", "HEIGHT", "EDGE_AT", "TABLE_MAP_R",
                 "TABLE_TOP", "TABLE_Z", "FLOOR_STRIPS", "FLOOR_NOISE_SIDE", "SCRATCH_TILE"];
    let mesh_values: f32[14] = [mesh::FIELD, mesh::INNER, mesh::FRAME_W, mesh::FRAME_TOP, mesh::BOTTOM, mesh::RADIUS,
                                mesh::HEIGHT, mesh::EDGE_AT, mesh::TABLE_MAP_R, mesh::TABLE_TOP, mesh::TABLE_Z,
                                surfaces::FLOOR_STRIPS, surfaces::FLOOR_NOISE_SIDE, surfaces::SCRATCH_TILE];
    var bad = 0;
    for name, i in names {
        let x, ok = constant(text, name);
        let same = ok && (x as f32) == mesh_values[i];
        print(name, ": mesh ", mesh_values[i], ", shaders ", if ok { str(x) } else { str("missing") }, if same { "" } else { "  DIFFERS" });
        if !same { bad++; }
    }
    let chair_names = ["CHAIR_A", "CHAIR_B"];
    for name, i in chair_names {
        let c, ok = vec4_constant(text, name);
        let m = mesh::CHAIRS[i];
        let same = ok && c.x == m.x && c.y == m.y && c.z == m.z && c.w == m.w;
        print(name, ": mesh ", m.x, " ", m.y, " ", m.z, " ", m.w, if same { "" } else { "  DIFFERS" });
        if !same { bad++; }
    }
    if bad > 0 { exit(1); }
}
