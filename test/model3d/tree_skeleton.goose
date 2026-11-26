// The passes on the maple's grown skeleton (tree_skeleton.goose, task 117). The gravity
// layer on lone limbs 6 m long, as the study's test_gravity.py checks it: a level limb
// sags, a heavier one (side shoots) more, a thicker one less, a rising one less, an upright
// one not at all. Then the old-leader maple reshaped (broken leaders, gravity, shedding):
// the same tree each time, every leaf's frame still square, nothing nearer the house than
// the gap, and culled (grow_whole's own and cull_copy's alike) with the whole tree's
// shadow.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

// A limb of radius r0 at its foot, tapering to a fifth, rising `rise` degrees, with a side
// shoot either side of each joint of `load` its radius when load > 0; 25 cm segments.
fn limb(t: trees::Tree&, r0: f32, rise: f32, load: f32) {
    let m = surfaces::METRE;
    let n = 24;
    let dir = float3 { cos(radians(rise)), sin(radians(rise)), 0.0 };
    for k in n {
        let ra = r0 * (1.0 - 0.8 * k / n) * m;
        let rb = r0 * (1.0 - 0.8 * (k + 1) / n) * m;
        t.segments.push(trees::Segment { dir * (0.25 * k * m), dir * (0.25 * (k + 1) * m), ra, rb, 1 });
    }
    t.limbs.push(trees::Limb { 0, n as i32, 1, -1, -1 });
    guard load > 0.0 else { return; }
    for k in n {
        let at = t.segments[k].b;
        let r = t.segments[k].rb * load;
        for side in 2 {
            let out = float3 { 0.0, 0.0, if side == 0 { -0.6 } else { 0.6 } } * m;
            let first = t.segments.len;
            t.segments.push(trees::Segment { at, at + out, r, r * 0.5, 2 });
            t.limbs.push(trees::Limb { first as i32, 1, 2, 0, k as i32 });
        }
    }
}

// The limb's tip's angle under level, degrees.
fn drop_of(t: trees::Tree&) -> f32 {
    let e = t.segments[23].b;
    return degrees(atan2(-e.y, sqrt(e.x * e.x + e.z * e.z)));
}

fn show_limb(name: const u8[:], r0: f32, rise: f32, load: f32) {
    var t = trees::Tree { .. };
    limb(t, r0, rise, load);
    let before = drop_of(t);
    trees::bend_by_weight(t, 1.0);
    let tenths = floor((drop_of(t) - before) * 10.0 + 0.5) / 10.0;
    print(name, ": the tip ", tenths, " degrees lower");
}

fn main() {
    show_limb("level, 10 cm", 0.1, 0.0, 0.0);
    show_limb("level, 10 cm, side shoots", 0.1, 0.0, 0.6);
    show_limb("level, 20 cm", 0.2, 0.0, 0.0);
    show_limb("rising 45 degrees, 10 cm", 0.1, 45.0, 0.0);
    show_limb("upright, 10 cm", 0.1, 90.0, 0.0);

    let r = rooms::get(rooms::LIBRARY);
    let s = room_shell::LIBRARY;
    let sight = rooms::whole_sight(r, s);
    let v = rooms::shell_tree_view(r, s);
    var w = rooms::whole_tree(r, s);
    w.growth = trees::Growth { float4 { 1.0, 2.0, 30.0, 50.0 }, 1.0, float2 { 0.45, 0.5 } };

    var whole = trees::Tree { .. };
    trees::grow_whole(whole, w, v, sight, false);
    var line: u8[>..] = [];
    format(line, "reshaped: ", whole.segments.len, " segments, ", whole.limbs.len, " limbs (");
    for level in 5 { format(line, if level > 0 { " " } else { "" }, trees::limbs_at(whole, level)); }
    var stubs = 0;
    for &l in whole.limbs { if trees::is_stub(whole, l) { stubs++; } }
    format(line, "), ", stubs, " broken leaders' stubs, ", whole.cards.len, " leaves, ", whole.leaves.len, " casting");
    print(line);
    print(if whole.segments.len <= trees::MAX_WHOLE_SEGMENTS && whole.cards.len <= trees::MAX_CARDS { "within the counts" }
          else { "past the counts: WRONG" });
    var bad = 0;
    var near = 0;
    for &c in whole.cards {
        if abs(dot(c.face, c.along)) > 1e-3 || abs(length(c.face) - 1.0) > 1e-3 || abs(length(c.along) - 1.0) > 1e-3 { bad++; }
        if c.base.z - w.house < trees::WALL_GAP { near++; }
    }
    print(bad, " leaves with a bent frame, ", near, " nearer the house than the gap");
    // Every limb's foot on the segment it hangs on.
    var loose = 0;
    for &l in whole.limbs {
        guard l.attach >= 0 else { continue; }
        let on = whole.segments[l.attach as i64];
        let foot = whole.segments[l.first as i64].a;
        let ab = on.b - on.a;
        let h = clamp(dot(foot - on.a, ab) / max(dot(ab, ab), 1e-9), 0.0, 1.0);
        if length(foot - (on.a + ab * h)) > 0.01 { loose++; }
    }
    print(loose, " limbs off the segment they hang on");

    var again = trees::Tree { .. };
    trees::grow_whole(again, w, v, sight, false);
    var same = again.segments.len == whole.segments.len && again.cards.len == whole.cards.len;
    if same { for i in whole.segments.len { if again.segments[i].b.x != whole.segments[i].b.x { same = false; } } }
    print("grown again: ", if same { "the same tree" } else { "another tree: WRONG" });

    var culled = trees::Tree { .. };
    trees::grow_whole(culled, w, v, sight, true);
    var copied = trees::Tree { .. };
    trees::cull_copy(whole, copied, w, v, sight);
    print("culled: ", culled.segments.len, " segments, ", culled.limbs.len, " limbs, ", culled.cards.len, " leaves, ",
          culled.leaves.len, " casting");
    var alike = copied.segments.len == culled.segments.len && copied.cards.len == culled.cards.len
                && copied.leaves.len == culled.leaves.len && culled.leaves.len == whole.leaves.len;
    if alike { for i in culled.leaves.len { if culled.leaves[i].at.x != whole.leaves[i].at.x { alike = false; } } }
    print("culled by cull_copy alike, the shadow's leaves the whole tree's: ", if alike { "yes" } else { "no: WRONG" });
}
