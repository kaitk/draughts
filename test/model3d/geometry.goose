// The shaders' GLSL repeats the 3D board's measures from src/model3d/mesh.goose as
// `const float NAME = value;` (embed_shader takes only a literal); each must equal the
// mesh's, or the lit shader's field, frame, and pieces stop where the meshes don't.
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

fn main() {
    let text = embed_file("../../src/render3d/shaders.goose");
    let names = ["FIELD", "INNER", "FRAME_W", "FRAME_TOP", "BOTTOM", "RADIUS", "HEIGHT", "EDGE_AT"];
    let mesh_values: f32[8] = [mesh::FIELD, mesh::INNER, mesh::FRAME_W, mesh::FRAME_TOP, mesh::BOTTOM, mesh::RADIUS,
                               mesh::HEIGHT, mesh::EDGE_AT];
    var bad = 0;
    for name, i in names {
        let x, ok = constant(text, name);
        let same = ok && (x as f32) == mesh_values[i];
        print(name, ": mesh ", mesh_values[i], ", shaders ", if ok { str(x) } else { str("missing") }, if same { "" } else { "  DIFFERS" });
        if !same { bad++; }
    }
    if bad > 0 { exit(1); }
}
