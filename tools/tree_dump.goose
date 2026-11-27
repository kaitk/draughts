// The old maple (trees::grow_whole) and the leaf atlas (leaf_atlas) dumped for review on
// the CPU, no window and no GPU (task 107's T1 and T3): the tree whole and culled as flat
// little-endian f32 records, the frame's eyes, windows and sun as text, the atlas's two
// layers at level 0, and the shell's shadow baked from the culled tree; with the counts
// and how long each step took. Build it (C at -O2) for the times:
//
//   goose build -o build/tree_dump tools/tree_dump.goose && build/tree_dump OUT_DIR
//       [--elbows FEWEST,MOST,TURN_LO,TURN_HI] [--gravity STRENGTH] [--shed LIGHT,STUBS]
//       [--plates ON,SPURS,NUDGE] [--tilt ON,SEASON,SAG] [--bend SHARE,TWIST]
//       [--elbow-plane ON] [--limb-angle ON,DOWN,DOWN_V] [--hanging-twigs ON,ATTRACTION,LEVEL,TWIGS]
//       [--hangs N (the first N low limbs, 4)]
//
// The flags set the growth past the habit (trees::Growth, task 117; all off by default, as
// the light tuner's --tree-elbows, --tree-gravity, --tree-shed, --tree-plates, --tree-tilt,
// --tree-bend, --tree-elbow-plane, --tree-limb-angle and --tree-hanging-twigs).
//
// One tree-NAME-whole.bin and -culled.bin for each low limb (rooms::WHOLE_HANGS), its shadow
// shadow-NAME.grey and times in times.txt; the frame's eyes and windows for the default.
// tree.bin: "segments" n, then n × (a.xyz b.xyz ra rb level); "limbs" n × (first count
// level parent); "cards" n × (foot.xyz base.xyz along.xyz face.xyz size width kind tint);
// each count an f32 too; then the cards' bends, n × (shape amount twist). leaf-shapes.bin:
// trees::leaf_shapes' float4s.
import std;
import os;
import vec;
import math;
import binary;
import model3d from "../src/model3d";

fn put(out: u8[>..]&, x: f32) {
    let b = binary::bits_of_f32(x);
    out.push((b & 0xFF) as u8);
    out.push(((b >> 8) & 0xFF) as u8);
    out.push(((b >> 16) & 0xFF) as u8);
    out.push(((b >> 24) & 0xFF) as u8);
}

fn put3(out: u8[>..]&, v: float3) { put(out, v.x); put(out, v.y); put(out, v.z); }

fn write_tree(path: const u8[:], t: trees::Tree&) {
    var out: u8[>..] = [];
    put(out, t.segments.len as f32);
    for &s in t.segments { put3(out, s.a); put3(out, s.b); put(out, s.ra); put(out, s.rb); put(out, s.level as f32); }
    put(out, t.limbs.len as f32);
    for &l in t.limbs { put(out, l.first as f32); put(out, l.count as f32); put(out, l.level as f32); put(out, l.parent as f32); }
    put(out, t.cards.len as f32);
    for &c in t.cards {
        put3(out, c.foot); put3(out, c.base); put3(out, c.along); put3(out, c.face);
        put(out, c.size); put(out, c.width); put(out, c.kind as f32); put(out, c.tint);
    }
    for &c in t.cards { put(out, c.shape); put(out, c.shape_amount); put(out, c.twist); }
    guard write_file(path, out[..]) else { abort("could not write the tree"); }
}

// A map's four layers multiplied, one byte a texel.
fn write_grey(path: const u8[:], map: u8[>..]&, v: trees::View) {
    var grey: u8[>..] = [];
    for i in v.w * v.h {
        let o = i * 4;
        grey.push(((map[o] as i64) * (map[o + 1] as i64) / 255 * (map[o + 2] as i64) / 255 * (map[o + 3] as i64) / 255) as u8);
    }
    guard write_file(path, grey[..]) else { abort("could not write the shadow"); }
}

// The flag's numbers, comma-separated, over `v`'s first ones.
fn numbers(args: u8[:][>..]&, name: const u8[:], v: float4) -> float4 {
    var out: f32[4] = [v.x, v.y, v.z, v.w];
    for a, i in args {
        guard a == name && i + 1 < args.len else { continue; }
        var rest: const u8[:] = args[i + 1];
        for k in 4 {
            let part, after, more = split_once(rest, ",");
            let x, ok = parse_flt(part);
            guard ok else { abort(str(name, ": numbers, x,y,..")); }
            out[k] = x as f32;
            guard more else { break; }
            rest = after;
        }
    }
    return float4 { out[0], out[1], out[2], out[3] };
}

fn write_wood(path: const u8[:], verts: trees::WoodVertex[>..]&, indices: u32[>..]&, tube_indices: i64) {
    var out: u8[>..] = [];
    put(out, verts.len as f32);
    for &x in verts {
        put3(out, x.pos); put3(out, x.normal); put3(out, x.along);
        put(out, x.uv.x); put(out, x.uv.y);
        put(out, x.light.x); put(out, x.light.y); put(out, x.light.z); put(out, x.light.w);
    }
    put(out, tube_indices as f32);
    for i in tube_indices { put(out, indices[i] as f32); }
    guard write_file(path, out[..]) else { abort("could not write the wood"); }
}

fn has_flag(args: u8[:][>..]&, name: const u8[:]) -> bool {
    for a in args { if a == name { return true; } }
    return false;
}

fn line3(out: u8[>..]&, name: const u8[:], v: float3) { format(out, name, " ", v.x, " ", v.y, " ", v.z, "\n"); }

fn main() {
    let args = args();
    guard args.len >= 2 else { abort("tree_dump OUT_DIR"); }
    let dir = args[1];
    let r = rooms::get(rooms::LIBRARY);
    let s = room_shell::LIBRARY;
    let sight = rooms::whole_sight(r, s);
    let v = rooms::shell_tree_view(r, s);
    let spec = rooms::tree_spec(rooms::shell_tree(r));
    let w = rooms::whole_tree(r, s);
    var growth = trees::Growth { .. };
    growth.elbows = numbers(args, "--elbows", growth.elbows);
    growth.gravity = numbers(args, "--gravity", float4 { growth.gravity, 0.0, 0.0, 0.0 }).x;
    let shed = numbers(args, "--shed", float4 { growth.shed.x, growth.shed.y, 0.0, 0.0 });
    growth.shed = float2 { shed.x, shed.y };
    growth.plates = numbers(args, "--plates", growth.plates);
    growth.tilt = numbers(args, "--tilt", growth.tilt);
    let bend = numbers(args, "--bend", float4 { growth.bend.x, growth.bend.y, 0.0, 0.0 });
    growth.bend = float2 { bend.x, bend.y };
    growth.elbow_plane = numbers(args, "--elbow-plane", float4 { growth.elbow_plane, 0.0, 0.0, 0.0 }).x;
    growth.limb_angle = numbers(args, "--limb-angle", growth.limb_angle);
    growth.hanging_twigs = numbers(args, "--hanging-twigs", growth.hanging_twigs);
    let hangs = numbers(args, "--hangs", float4 { 4.0, 0.0, 0.0, 0.0 }).x as i64;
    var times: u8[>..] = [];
    // old-leader, the user's pick, with each of its low limbs (rooms::WHOLE_HANGS).
    for name, k in rooms::WHOLE_HANGS {
        guard k < hangs else { break; }
        var wk = rooms::whole_tree(r, s, rooms::WHOLE_OLD_LEADER, k);
        wk.growth = growth;
        var t = trees::Tree { .. };
        var t0 = clock();
        trees::grow_whole(t, wk, v, sight, false);
        let whole_ms = (clock() - t0) * 1000.0;
        print(name, " whole: ", t.segments.len, " segments, ", t.limbs.len, " limbs (", trees::limbs_at(t, 0), " ",
              trees::limbs_at(t, 1), " ", trees::limbs_at(t, 2), " ", trees::limbs_at(t, 3), " ", trees::limbs_at(t, 4), "), ",
              t.cards.len, " leaves, ", whole_ms, " ms");
        write_tree(str(dir, "/tree-", name, "-whole.bin")[..], t);
        var c = trees::Tree { .. };
        t0 = clock();
        trees::grow_whole(c, wk, v, sight, true);
        let culled_ms = (clock() - t0) * 1000.0;
        print(name, " culled: ", c.segments.len, " segments, ", c.limbs.len, " limbs, ", c.cards.len, " leaves, ", c.leaves.len,
              " casting, ", c.left_out, " left out, ", culled_ms, " ms");
        write_tree(str(dir, "/tree-", name, "-culled.bin")[..], c);
        // Its shadow through the shell's windows, the leaves cast by the atlas's outlines.
        var map: u8[>..] = [];
        t0 = clock();
        trees::draw_map(c, spec, v, map);
        let map_ms = (clock() - t0) * 1000.0;
        print(name, " shadow: passing ", trees::passing(map, -1, v), " in ", map_ms, " ms");
        format(times, name, " ", whole_ms, " ", culled_ms, " ", map_ms, " ", trees::passing(map, -1, v), "\n");
        write_grey(str(dir, "/shadow-", name, ".grey")[..], map, v);
        if k == rooms::HANG_HIGH {
            // The same leaves cast as the species' palmate outline, for the comparison.
            for &lf in c.leaves { lf.kind = -1; }
            var plain: u8[>..] = [];
            t0 = clock();
            trees::draw_map(c, spec, v, plain);
            print(name, " shadow, plain outlines: passing ", trees::passing(plain, -1, v), " in ", (clock() - t0) * 1000.0, " ms");
            write_grey(str(dir, "/shadow-", name, "-plain.grey")[..], plain, v);
        }
    }
    guard write_file(str(dir, "/times.txt")[..], times[..]) else { abort("could not write the times"); }

    // The bent leaves' meshes, as the leaves' vertex shader reads them.
    var shapes: float4[>..] = [];
    var t_shapes = clock();
    trees::leaf_shapes(shapes);
    print("leaf shapes: ", shapes.len, " float4s in ", (clock() - t_shapes) * 1000.0, " ms");
    var shape_bytes: u8[>..] = [];
    for &x in shapes { put(shape_bytes, x.x); put(shape_bytes, x.y); put(shape_bytes, x.z); put(shape_bytes, x.w); }
    guard write_file(str(dir, "/leaf-shapes.bin")[..], shape_bytes[..]) else { abort("could not write the shapes"); }

    // Today's tree's shadow for comparison.
    var today = trees::Tree { .. };
    var today_map: u8[>..] = [];
    var t0 = clock();
    trees::grow(today, spec, v);
    trees::draw_map(today, spec, v, today_map);
    let today_ms = (clock() - t0) * 1000.0;
    print("today's tree: ", today.segments.len, " segments, ", today.leaves.len, " leaves, passing ", trees::passing(today_map, -1, v),
          " in ", today_ms, " ms");
    write_grey(str(dir, "/shadow-today.grey")[..], today_map, v);

    // The frame: where the eyes, windows, sun and tree are.
    var info: u8[>..] = [];
    format(info, "metre ", surfaces::METRE, "\n");
    format(info, "shear ", v.shear.x, " ", v.shear.y, "\n");
    format(info, "map ", v.middle.x, " ", v.middle.y, " ", v.size.x, " ", v.size.y, " ", v.w, " ", v.h, "\n");
    line3(info, "foot", w.foot);
    format(info, "house ", w.house, "\nplane ", sight.plane, "\n");
    line3(info, "crown_middle", w.foot + w.middle);
    format(info, "crown ", w.crown.x, " ", w.crown.y, " ", w.crown.z, " ", w.crown.w, "\n");
    for &o in sight.windows { format(info, "window ", o.x, " ", o.y, " ", o.z, " ", o.w, "\n"); }
    // The light tuner's table-window eye and target at its default placement (less-turned).
    line3(info, "eye", rooms::plan_to_tree(r, s, float3 { 4.037, 3.75, 1.6 }));
    line3(info, "at", rooms::plan_to_tree(r, s, float3 { 4.245, 6.737, 1.426 }));
    line3(info, "floor", rooms::plan_to_tree(r, s, float3 { 4.5, 7.0, 0.0 }));
    format(info, "today_ms ", today_ms, "\n");
    guard write_file(str(dir, "/frame.txt")[..], info[..]) else { abort("could not write the frame"); }

    // The atlas.
    var shape: u8[>..] = [];
    var marks: u8[>..] = [];
    t0 = clock();
    leaf_atlas::make(shape, marks);
    let atlas_ms = (clock() - t0) * 1000.0;
    print("atlas: ", leaf_atlas::ATLAS_W, " x ", leaf_atlas::ATLAS_H, ", two layers of ", leaf_atlas::atlas_bytes(),
          " bytes with mips, ", atlas_ms, " ms");
    let n = leaf_atlas::ATLAS_W * leaf_atlas::ATLAS_H * 4;
    guard write_file(str(dir, "/atlas-shape.rgba")[..], shape[0..n]) && write_file(str(dir, "/atlas-marks.rgba")[..], marks[0..n])
        else { abort("could not write the atlas"); }
    // Its colours, linear f32 RGB, front and backlit, at five tints.
    let tints: f32[5] = [0.2, 0.6, 1.0, 1.4, 1.8];
    for tint, ti in tints {
        for side in 2 {
            var rgb: u8[>..] = [];
            for i in leaf_atlas::ATLAS_W * leaf_atlas::ATLAS_H {
                let o = i * 4;
                let sv: u8[4] = [shape[o], shape[o + 1], shape[o + 2], shape[o + 3]];
                let mv: u8[4] = [marks[o], marks[o + 1], marks[o + 2], marks[o + 3]];
                let col = leaf_atlas::texel_color(sv, mv, tint, side == 1);
                put3(rgb, col);
            }
            guard write_file(str(dir, "/atlas-", if side == 1 { "back" } else { "front" }, "-", ti, ".f32")[..], rgb[..])
                else { abort("could not write the colours"); }
        }
    }
    // The coverage at each mip, for the check that leaves don't thin away.
    var at = 0;
    var mw = leaf_atlas::ATLAS_W;
    var mh = leaf_atlas::ATLAS_H;
    var cover: u8[>..] = [];
    for level in leaf_atlas::mips_of(mw, mh) {
        var over = 0;
        for i in mw * mh { if shape[at + i * 4 + 3] > 127 { over++; } }
        format(cover, level, " ", over as f32 / (mw * mh) as f32, "\n");
        at += mw * mh * 4;
        mw /= 2;
        mh /= 2;
    }
    guard write_file(str(dir, "/atlas-coverage.txt")[..], cover[..]) else { abort("could not write the coverage"); }

    // The wood's mesh from the default tree (trees::wood_mesh), plain and shaped as the flags
    // say (--junctions, --roots, --tier 0 high, 1 standard, 2 phone; task 117): wood.bin holds
    // the vertex count, then each WoodVertex's 15 floats, the tube index count and the indices
    // (as f32), all little-endian f32.
    {
        var shape = trees::WoodShape { .. };
        shape.junctions = has_flag(args, "--junctions");
        shape.roots = has_flag(args, "--roots");
        shape.tier = numbers(args, "--tier", float4 { 0.0, 0.0, 0.0, 0.0 }).x as i64;
        var wd = rooms::whole_tree(r, s, rooms::WHOLE_OLD_LEADER, 0);
        wd.growth = growth;
        var all = trees::Tree { .. };
        trees::grow_whole(all, wd, v, sight, false);
        var density: f32[>..] = [];
        let grid = trees::crown_grid(all, density);
        var c = trees::Tree { .. };
        if trees::reshaped(wd.growth) { trees::cull_copy(all, c, wd, v, sight); } else { trees::grow_whole(c, wd, v, sight, true); }
        var verts:   trees::WoodVertex[>..] = [];
        var indices: u32[>..]               = [];
        t0 = clock();
        let plain = trees::wood_mesh(c, density, grid, trees::toward_sun(v), verts, indices);
        let plain_ms = (clock() - t0) * 1000.0;
        print("wood, plain: ", plain.tube_indices / 3, " tube triangles, ", plain.ribbon_indices / 3, " ribbon triangles, ", plain.vertices,
              " vertices, ", plain_ms, " ms");
        write_wood(str(dir, "/wood-plain.bin")[..], verts, indices, plain.tube_indices);
        t0 = clock();
        let m = trees::wood_mesh(c, density, grid, trees::toward_sun(v), verts, indices, shape);
        let shaped_ms = (clock() - t0) * 1000.0;
        print("wood, shaped: ", m.tube_indices / 3, " tube triangles, ", m.ribbon_indices / 3, " ribbon triangles, ", m.vertices, " vertices, ",
              shaped_ms, " ms");
        write_wood(str(dir, "/wood.bin")[..], verts, indices, m.tube_indices);
    }

    // The bark's age layers (trees::bark_layers, task 117), level 0 of each texture.
    var heights:  u8[>..] = [];
    var cavities: u8[>..] = [];
    var best_ms:  f64     = 1e9;
    for k in 5 {
        t0 = clock();
        trees::bark_layers(heights, cavities);
        best_ms = min(best_ms, (clock() - t0) * 1000.0);
    }
    print("bark layers: ", trees::BARK_W, " x ", trees::BARK_H, ", ", trees::BARK_LAYERS, " ages, ", best_ms, " ms (best of 5)");
    let bn = trees::BARK_W * trees::BARK_H * 4;
    guard write_file(str(dir, "/bark-height.rgba")[..], heights[0..bn]) && write_file(str(dir, "/bark-cavity.rgba")[..], cavities[0..bn])
        else { abort("could not write the bark"); }
}
