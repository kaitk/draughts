// The maple grown whole as the picture draws it (tree_mesh.goose, task 107's T2): the crown's
// grid, the wood's tubes and ribbons from the culled tree, each vertex's light within 0..1
// and its normal unit long, the same mesh twice from the same tree; and the bark's tile.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn main() {
    let r = rooms::get(rooms::LIBRARY);
    let s = room_shell::LIBRARY;
    let v = rooms::shell_tree_view(r, s);
    let sight = rooms::whole_sight(r, s);
    let w = rooms::whole_tree(r, s);
    var all = trees::Tree { .. };
    trees::grow_whole(all, w, v, sight, false);
    var density: f32[>..] = [];
    let grid = trees::crown_grid(all, density);
    var filled = 0;
    for x in density { if x > 0.0 { filled++; } }
    print("grid: ", density.len, " cells, ", filled, " with leaves");
    var t = trees::Tree { .. };
    trees::grow_whole(t, w, v, sight, true);
    var verts:   trees::WoodVertex[>..] = [];
    var indices: u32[>..]               = [];
    let m = trees::wood_mesh(t, density, grid, trees::toward_sun(v), verts, indices);
    print("wood: ", m.tube_indices / 3, " tube triangles, ", m.ribbon_indices / 3, " ribbon triangles, ", m.vertices, " vertices");
    var bad = 0;
    var unlit = 0;
    for &x in verts {
        if x.light.x < 0.0 || x.light.x > 1.0 || x.light.y < 0.0 || x.light.y > 1.0 { unlit++; }
        if x.uv.x > -1.5 && length(x.normal) > 0.0 && abs(length(x.normal) - 1.0) > 1e-3 { bad++; }
    }
    var past = 0;
    for i in indices { if i as i64 >= verts.len { past++; } }
    print(bad, " bent normals, ", unlit, " lights out of 0..1, ", past, " indices past the vertices");
    var again:         trees::WoodVertex[>..] = [];
    var again_indices: u32[>..]               = [];
    trees::wood_mesh(t, density, grid, trees::toward_sun(v), again, again_indices);
    var same = again.len == verts.len && again_indices.len == indices.len;
    if same { for x, i in verts { if x.pos.x != again[i].pos.x || x.light.x != again[i].light.x { same = false; } } }
    print("made again: ", if same { "the same" } else { "DIFFERENT" });
    var bark: u8[>..] = [];
    trees::bark_tile(bark);
    print("bark: ", bark.len, " bytes, ", trees::mips_of(trees::BARK_W, trees::BARK_H), " levels");
}
