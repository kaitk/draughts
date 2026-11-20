// The view out of the library's windows (model3d::view_out): the middle window's middle on
// the wall's inner face is the layers' centre; the band's corner vertices stand 110 m from
// it at ±64° from straight out, between 14.05 m under the lawn and 26.26 m over it; the
// oak's quad stands 70 m out at 22° right of straight out and faces the centre; the sky
// comes first, then the band, then the oak, as the draw blends them in that order.
import std;
import vec;
import math;
import model3d from "../../src/model3d";

fn metres(v: f32) -> f32 { floor(v / surfaces::METRE * 100.0 + 0.5) / 100.0 }

fn main() {
    var verts:   mesh::Vertex[>..] = [];
    var indices: u32[>..]          = [];
    let c = view_out::centre_of(room_shell::LIBRARY);
    view_out::build(verts, indices, c);
    print("centre ", metres(c.x), ", ", metres(c.y), " m in the room's frame");
    var order: u8[>..] = [];
    var last:  f32     = -1.0;
    for i in indices.len / 3 {
        let m = verts[indices[3 * i]].mat;
        if m != last { format(order, " ", m); }
        last = m;
    }
    print(indices.len / 3, " triangles, their materials in order:", order[..]);
    let sky = (view_out::SKY_ROWS + 1) * (view_out::SKY_COLUMNS + 1);
    let across = view_out::BAND_SEGMENTS + 1;
    let corners = [sky, sky + across - 1, sky + across, sky + 2 * across - 1];
    for k in corners {
        let v = verts[k];
        let d = float2 { v.pos.x - c.x, v.pos.z - c.y };
        let theta = degrees(atan2(d.x, -d.y));
        print("band corner uv ", v.uv.x, ",", v.uv.y, ": ", metres(length(d)), " m out at ",
              floor(theta * 100.0 + 0.5) / 100.0, " deg, ", metres(v.pos.y - view_out::LAWN_Y), " m over the lawn");
    }
    let o = sky + 2 * across;
    let a = verts[o].pos;   // the top's left and right as seen from the room, then the foot's
    let b = verts[o + 1].pos;
    let low = verts[o + 2].pos;
    let foot = float2 { 0.5 * (low.x + verts[o + 3].pos.x), 0.5 * (low.z + verts[o + 3].pos.z) };
    let d = foot - c;
    let side = float2 { b.x - a.x, b.z - a.z };
    let normal = normalize(float2 { -side.y, side.x });
    print("oak: ", metres(length(d)), " m out at ", floor(degrees(atan2(d.x, -d.y)) * 100.0 + 0.5) / 100.0, " deg, ",
          metres(length(side)), " m wide, ", metres(a.y - low.y), " m tall, its foot ",
          metres(low.y - view_out::LAWN_Y), " m over the lawn; facing the centre ",
          floor(abs(dot(normal, normalize(c - foot))) * 1000.0 + 0.5) / 1000.0,
          "; u 0 on its left as seen from the room: ", verts[o].uv.x == 0.0 && dot(side, float2 { -d.y, d.x }) > 0.0);
}
