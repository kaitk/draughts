// The maple's leaves in plates (tree_leaves.goose, task 117's step two): only on the twigs'
// current shoots, within MAX_CARDS; the lower leaf of a pair larger on the longer stalk
// (Weisse 1895); the blades level without the tilt, and with it the measured medians by
// season and height (Raabe et al. 2015: the top flattest in summer, steeper in autumn); the
// bent shapes some cupped, some sagging, most flat; and the bent meshes the shader reads,
// as many float4s as the shader's TREE_SHAPE_VEC4S, the flat one flat, every normal unit.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn median_tilt(t: trees::Tree&, top: bool, w: trees::Whole) -> i64 {
    var tilts: f32[>..] = [];
    let middle = w.foot + w.middle;
    for &c in t.cards {
        let h = (c.base.y - (middle.y - w.crown.y)) / (2.0 * w.crown.y);
        guard (top && h > 0.8) || (!top && h < 0.3) else { continue; }
        tilts.push(degrees(acos(clamp(abs(c.face.y), 0.0, 1.0))));
    }
    guard tilts.len > 0 else { return -1; }
    sort(tilts) { a, b => a < b };
    return floor(tilts[tilts.len / 2] + 0.5) as i64;
}

fn main() {
    let r = rooms::get(rooms::LIBRARY);
    let s = room_shell::LIBRARY;
    let v = rooms::shell_tree_view(r, s);
    let sight = rooms::whole_sight(r, s);
    var w = rooms::whole_tree(r, s);
    w.growth.plates = float4 { 1.0, 2.0, 1.0, 0.0 };
    var t = trees::Tree { .. };
    trees::grow_whole(t, w, v, sight, false);
    var level = 0;
    for &c in t.cards { if abs(c.face.y) > cos(radians(5.5)) { level++; } }
    print("plates: ", t.cards.len, " leaves", if t.cards.len <= trees::MAX_CARDS { ", within the counts" } else { ", TOO MANY" },
          ", level blades ", floor(level * 100.0 / t.cards.len + 0.5), "%");
    // Pairs are pushed one after the other: of each pair standing one above the other, the lower one.
    var pairs = 0;
    var larger = 0;
    var longer = 0;
    for i in 0..t.cards.len - 1 {
        let a = t.cards[i];
        let b = t.cards[i + 1];
        guard a.foot.x == b.foot.x && a.foot.y == b.foot.y && a.foot.z == b.foot.z && i % 2 == 0 else { continue; }
        let up = a.base.y - b.base.y;
        guard abs(up) > a.size * 0.15 else { continue; }
        pairs++;
        let lo = if up < 0.0 { a } else { b };
        let hi = if up < 0.0 { b } else { a };
        if lo.size > hi.size { larger++; }
        if length(lo.base - lo.foot) > length(hi.base - hi.foot) { longer++; }
    }
    print("pairs one over the other: ", pairs, ", the lower larger in ", floor(larger * 100.0 / max(pairs, 1) + 0.5), "%, on the longer stalk in ",
          floor(longer * 100.0 / max(pairs, 1) + 0.5), "%");
    let seasons = ["summer", "mid-September", "October"];
    for name, k in seasons {
        w.growth.tilt = float4 { 1.0, k, 0.0, 0.0 };
        trees::grow_whole(t, w, v, sight, false);
        print(name, ": median tilt at the top ", median_tilt(t, true, w), " degrees, low ", median_tilt(t, false, w));
    }
    w.growth.bend = float2 { 1.0, 25.0 };
    trees::grow_whole(t, w, v, sight, false);
    var by_shape: i64[6] = [0; 6];
    for &c in t.cards { by_shape[c.shape]++; }
    print("shapes (flat, cup, droop, edges, tips, sag): ", by_shape[0], " ", by_shape[1], " ", by_shape[2], " ", by_shape[3], " ",
          by_shape[4], " ", by_shape[5]);
    var shapes: float4[>..] = [];
    trees::leaf_shapes(shapes);
    var bad = 0;
    var raised = 0;
    for i in shapes.len / 2 {
        let n = shapes[i * 2 + 1];
        if abs(length(float3 { n.x, n.y, n.z }) - 1.0) > 1e-3 { bad++; }
    }
    for kind in trees::LEAF_KINDS {
        for j in trees::LEAF_FAN_VERTICES {
            let p = shapes[trees::LEAF_ROW_VEC4S + (kind * trees::LEAF_SHAPES * trees::LEAF_FAN_VERTICES + j) * 2];
            if p.z != 0.0 { raised++; }
        }
    }
    print("leaf shapes: ", shapes.len, " float4s", if shapes.len == trees::LEAF_SHAPE_VEC4S { "" } else { " WRONG" }, ", ", bad,
          " normals not unit, ", raised, " flat vertices off the plane");
}
