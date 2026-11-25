// The props' occlusion bake (model3d::prop_occlusion, task 120) timed on the CPU, no window
// and no GPU: the games table and its two chairs as the room builds them, baked at several
// ray counts and reaches, each against a bake of 1024 rays: the mean and largest
// error of the open part and of the open direction (degrees), the chairs' and the table's
// vertices apart. Build it (C at -O2) for the times:
//
//   goose build -o build/prop_bake tools/prop_bake.goose && build/prop_bake [quick]
//
// `quick` takes a reference of 64 rays and one reach, to check it runs through TinyCC.
import std;
import os;
import vec;
import math;
import model3d from "../src/model3d";

fn main() {
    let quick = args().len > 1;
    let reference_rays: i64 = if quick { 64 } else { 1024 };
    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    let edge = float4 { 3.0, 0.9, 0.38, 1.4 };
    mesh::table(verts, indices, edge, mesh::TABLE_R, surfaces::FLOOR_Y);
    let table_verts = verts.len;
    let table_tris = indices.len / 3;
    mesh::chairs(verts, indices, surfaces::FLOOR_Y + 0.008 * surfaces::METRE);
    print("vertices ", verts.len, " (table ", table_verts, ", chairs ", verts.len - table_verts, "), triangles ",
          indices.len / 3, " (table ", table_tris, ")");
    var pos:    float3[>..] = [];
    var normal: float3[>..] = [];
    for v in verts {
        pos.push(v.pos);
        normal.push(v.normal);
    }
    let metre = surfaces::METRE;
    var reference: prop_occlusion::Open[>..] = [];
    for v in verts { reference.push(prop_occlusion::Open { float3_0, 0.0 }); }
    var result: prop_occlusion::Open[>..] = [];
    for v in verts { result.push(prop_occlusion::Open { float3_0, 0.0 }); }
    let reaches: f32[3] = [0.25, 0.5, 1.0];
    let counts:  i64[5] = [8, 16, 32, 64, 128];
    let cells:   f32[4] = [0.25, 0.35, 0.5, 1.0];
    for reach_m, ri in reaches {
        guard !quick || ri == 1 else { continue; }
        let reach = reach_m * metre;
        var at = clock();
        let rs = prop_occlusion::bake(pos[..], normal[..], indices[..], reference_rays, reach, reference[..]);
        print("reach ", reach_m, " m: reference ", reference_rays, " rays ", (clock() - at) * 1000.0, " ms, grid ",
              rs.cells, " cells, ", rs.listed, " listed, ", rs.tests / rs.rays, " tests a ray");
        var mean_open_chairs = 0.0;
        for k in table_verts..verts.len { mean_open_chairs += reference[k].open; }
        print("  chairs' mean open ", mean_open_chairs / (verts.len - table_verts));
        var dark = 0;
        for o in reference { if o.open < 0.1 { dark += 1; } }
        print("  vertices under 0.1 open ", dark);
        for cell in cells {
            guard !quick || cell == 1.0 else { continue; }
            at = clock();
            let cs = prop_occlusion::bake(pos[..], normal[..], indices[..], 32, reach, result[..], cell);
            print("  32 rays, cells of ", cell, ": ", (clock() - at) * 1000.0, " ms, ", cs.cells, " cells, ", cs.tests / cs.rays,
                  " tests a ray");
        }
        for n in counts {
            guard !quick || n <= 16 else { continue; }
            at = clock();
            let st = prop_occlusion::bake(pos[..], normal[..], indices[..], n, reach, result[..]);
            let ms = (clock() - at) * 1000.0;
            var e_open = [0.0, 0.0];
            var e_max = [0.0, 0.0];
            var e_deg = [0.0, 0.0];
            var e_deg_max = [0.0, 0.0];
            for i in verts.len {
                let w: i64 = if i < table_verts { 0 } else { 1 };
                let e = abs(result[i].open - reference[i].open);
                e_open[w] += e;
                e_max[w] = max(e_max[w], e);
                let deg = acos(clamp(dot(result[i].dir, reference[i].dir), -1.0, 1.0)) * 57.2958;
                e_deg[w] += deg;
                e_deg_max[w] = max(e_deg_max[w], deg);
            }
            let tn = table_verts as f32;
            let cn = (verts.len - table_verts) as f32;
            print("  ", n, " rays: ", ms, " ms, ", st.tests / st.rays, " tests a ray; open's error chairs ",
                  e_open[1] / cn, " (max ", e_max[1], "), table ", e_open[0] / tn, " (max ", e_max[0], "); direction's chairs ",
                  e_deg[1] / cn, " deg (max ", e_deg_max[1], "), table ", e_deg[0] / tn, " (max ", e_deg_max[0], ")");
        }
    }
}
