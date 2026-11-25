// The two side chairs at the games table, one for each player (round 2, 2026-11-25, task
// 107): oval medallion side chairs of the 1860s as library-autumn-02 has them, measured off
// ChatGPT's two renders of that chair (design/manor/pieces/library-chair-01 and -02; the
// design and its drawings in build/notes/chairs-2/, made by build/chairs-2/geometry.py from
// these numbers). A carved frame round an upholstered back, padded in front and behind, a
// small crest on its top; the back's line curving from the back legs' sabre feet up through
// the seat into the back, leaning more the higher it goes; a plump domed seat over a
// serpentine apron of three bands; turned and fluted front legs under square rosette blocks;
// a gimp braid where the cloth meets the wood. Its measures in millimetres in the chair's own
// frame (x across, y up from the floor, z forward), turned and set on the floor where each
// player sits (CHAIRS). Built into the table's mesh after the table, only where the room
// shows (render3d::Gpu.chairs): MAT_CHAIR its wood, its grain along each piece (TABLE_FRAG's
// base), MAT_SEAT the tapestry, MAT_TRIM the braid.
namespace mesh;
import std;
import vec;
import math;

let MAT_CHAIR: f32 = 5.0;
let MAT_SEAT:  f32 = 6.0;
let MAT_TRIM:  f32 = 7.0;

// Where each chair stands round the games table in the board's world (units, the table's
// middle at (0, TABLE_Z)): its seat's middle (x, z), and the sine and cosine of its turn
// (its front, local +z, faces (sin, cos)). The players sit on the board's axis: the far
// one close in, its seat 5 cm off the top's rim, turned 6 degrees; the near one pulled 0.25 m
// out from the top's rim, turned 14 degrees the other way and 6 cm aside. ROOM_FRAG's floor
// (CHAIR_A, CHAIR_B) holds the same numbers for the feet's contact on the floor
// (test/model3d/geometry checks them).
let CHAIRS: float4[2] = [
    float4 { 0.0, -27.884, 0.104528, 0.994522 },
    float4 { 1.829, 24.64, -0.241922, -0.970296 },
];
let CHAIR_MM: f32 = 0.03048;     // world units a millimetre, as TABLE_MM

// The seat rail's middle line round the seat, a closed curve (x, z), its right half from
// the front's middle round to the back's (mirrored for the left): wider at the front (the
// blocks' outsides 496 apart) than at the back.
let SEAT_HALF: float2[12] = [
    float2 { 0.0, 226.0 }, float2 { 120.0, 222.0 }, float2 { 205.0, 210.0 }, float2 { 236.0, 184.0 },
    float2 { 232.0, 115.0 }, float2 { 214.0, 10.0 }, float2 { 192.0, -70.0 }, float2 { 178.0, -125.0 },
    float2 { 162.0, -155.0 }, float2 { 120.0, -172.0 }, float2 { 60.0, -178.0 }, float2 { 0.0, -180.0 },
];
let SEAT_SAMPLES = 4;
// The apron: its top under the seat's braid, its foot at the blocks and the back, and how
// much lower its foot waves in the middle of the front (the sides 0.7 of it).
let RAIL_TOP:   f32 = 376.0;
let APRON_FOOT: f32 = 350.0;
let APRON_DIP:  f32 = 22.0;
// Its section, three bands, out from the seat's line and up from its foot in millimetres
// of APRON_H, its height where the foot doesn't wave; a point given twice a crease. The
// sweep's heights are then stretched to the foot's wave.
let APRON_H: f32 = 26.0;
let APRON: float2[12] = [
    float2 { -9.0, 26.0 }, float2 { 14.0, 26.0 }, float2 { 14.0, 26.0 }, float2 { 16.0, 22.9 },
    float2 { 14.0, 19.8 }, float2 { 16.0, 16.1 }, float2 { 14.0, 12.5 }, float2 { 17.0, 8.3 },
    float2 { 15.0, 3.6 }, float2 { 12.0, 0.0 }, float2 { 12.0, 0.0 }, float2 { -9.0, 0.0 },
];
// The seat: rings outermost first, (share of the way from PAD_MID to the line, out past
// the line, height): standing on the rail's top inside the braid, bulging over the apron,
// rolled over to a dome 505 mm up.
let SEAT_PAD: float3[10] = [
    float3 { 1.0, 13.0, 378.0 }, float3 { 1.0, 19.0, 394.0 }, float3 { 1.0, 21.0, 414.0 },
    float3 { 1.0, 19.0, 436.0 }, float3 { 0.98, 10.0, 456.0 }, float3 { 0.9, 0.0, 474.0 },
    float3 { 0.75, 0.0, 488.0 }, float3 { 0.52, 0.0, 498.0 }, float3 { 0.26, 0.0, 503.0 },
    float3 { 0.0, 0.0, 505.0 },
];
let SEAT_MID = float2 { 0.0, 10.0 };
// The pads' rings smoothed, so many between two given; their edge darkened to EDGE_AO over
// EDGE_REACH of surface, the braids and the wood's hidden faces to HIDDEN_AO.
let CUSHION_PER = 4;
let CUSHION_EDGE_AO:    f32 = 0.45;
let CUSHION_EDGE_REACH: f32 = 40.0;
let HIDDEN_AO:          f32 = 0.6;

// A front leg's lathe (radius, height) from under its block down: the collar rings, the
// bulb, a ring, the long tapered shaft (fluted), the rings, the inverted-pear knop, the foot.
let FRONT_LATHE: float2[33] = [
    float2 { 21.0, 328.0 }, float2 { 21.0, 322.0 }, float2 { 23.0, 320.0 }, float2 { 23.0, 313.0 },
    float2 { 18.0, 309.0 }, float2 { 19.0, 306.0 }, float2 { 24.0, 297.0 }, float2 { 26.0, 285.0 },
    float2 { 25.0, 273.0 }, float2 { 20.0, 265.0 }, float2 { 18.0, 262.0 }, float2 { 20.0, 260.0 },
    float2 { 20.0, 255.0 }, float2 { 22.0, 253.0 }, float2 { 22.0, 248.0 }, float2 { 15.0, 106.0 },
    float2 { 16.0, 104.0 }, float2 { 18.0, 102.0 }, float2 { 18.0, 96.0 }, float2 { 15.0, 93.0 },
    float2 { 17.0, 90.0 }, float2 { 17.0, 85.0 }, float2 { 14.0, 82.0 }, float2 { 16.0, 78.0 },
    float2 { 20.0, 66.0 }, float2 { 20.0, 58.0 }, float2 { 17.0, 48.0 }, float2 { 12.0, 41.0 },
    float2 { 12.0, 39.0 }, float2 { 11.0, 22.0 }, float2 { 10.0, 8.0 }, float2 { 8.0, 2.0 },
    float2 { 7.0, 0.0 },
];
let LATHE_SEGMENTS = 32;
// The shaft's flutes: how many, between which heights (each end faded over FLUTE_FADE), how
// deep.
let FLUTES = 8;
let FLUTE_FROM:  f32 = 114.0;
let FLUTE_TO:    f32 = 240.0;
let FLUTE_FADE:  f32 = 12.0;
let FLUTE_DEPTH: f32 = 1.6;
let FRONT_LEG_AT = float2 { 222.0, 192.0 };
// The square block over each front leg, under the seat (half its side, its foot, its top),
// a rosette on its front and its outer side.
let BLOCK = float3 { 26.0, 328.0, 380.0 };
let ROSETTE: float2[6] = [
    float2 { 0.5, 6.0 }, float2 { 4.0, 5.5 }, float2 { 8.0, 4.0 }, float2 { 11.0, 2.2 }, float2 { 12.0, 0.8 },
    float2 { 12.0, 0.0 },
];

// A back leg from its foot up through the rail and on into the frame's lower side
// (support_end), one piece, sweeping back to a sabre foot below the seat (x, y, z; w the
// section's half across, its half deep BACK_DEEP of that), measured off the side render.
let BACK_LEG: float4[8] = [
    float4 { 184.0, 0.0, -230.0, 11.0 }, float4 { 180.0, 82.0, -205.0, 12.0 }, float4 { 176.0, 161.0, -180.0, 14.0 },
    float4 { 172.0, 241.0, -165.0, 15.0 }, float4 { 168.0, 336.0, -157.0, 16.0 }, float4 { 166.0, 376.0, -158.0, 16.0 },
    float4 { 164.0, 429.0, -168.0, 15.0 }, float4 { 158.0, 470.0, -168.0, 14.0 },
];
let BACK_DEEP: f32 = 1.25;

// The back is built flat, in its own plane (u across, v up it, depth d toward the front,
// held as x, y = d, z = v), then bent into the chair along BACK_SPINE (bend_back).
// The medallion: its frame's middle line, right half from the top's middle round to the
// bottom's: broad and round over the shoulders, narrowing to a rounded foot.
let MEDALLION: float2[15] = [
    float2 { 0.0, 391.0 }, float2 { 75.0, 386.0 }, float2 { 130.0, 372.0 }, float2 { 166.0, 350.0 },
    float2 { 186.0, 320.0 }, float2 { 193.0, 284.0 }, float2 { 190.0, 244.0 }, float2 { 180.0, 198.0 },
    float2 { 164.0, 150.0 }, float2 { 148.0, 104.0 }, float2 { 134.0, 66.0 }, float2 { 122.0, 34.0 },
    float2 { 102.0, 10.0 }, float2 { 55.0, 0.0 }, float2 { 0.0, -2.0 },
];
let MEDALLION_SAMPLES = 3;
// The frame's section (out from the middle line, toward the front), round it so its faces
// point out: the inner face up to the lip, the lip, the inner bead, the channel, the outer
// bead, the outer face, the back; a point given twice a crease.
let FRAME: float2[17] = [
    float2 { -21.0, -13.0 }, float2 { -21.0, 4.0 }, float2 { -21.0, 4.0 }, float2 { -14.0, 5.0 },
    float2 { -11.0, 10.0 }, float2 { -7.0, 12.0 }, float2 { -3.0, 10.0 }, float2 { 1.0, 8.0 },
    float2 { 5.0, 9.0 }, float2 { 9.0, 13.0 }, float2 { 15.0, 14.0 }, float2 { 19.0, 11.0 },
    float2 { 21.0, 5.0 }, float2 { 21.0, 5.0 }, float2 { 21.0, -13.0 }, float2 { 21.0, -13.0 },
    float2 { -21.0, -13.0 },
];
// The back's pads as the seat's (share toward BACK_MID, out past the frame's middle line,
// depth): in front rising from the lip to 54 mm, highest 40 % up the back as the render's
// front curve; behind, 18 mm past the frame's back.
let BACK_FRONT: float3[8] = [
    float3 { 1.0, -21.0, 4.0 }, float3 { 1.0, -25.0, 16.0 }, float3 { 0.96, -25.0, 30.0 },
    float3 { 0.88, -25.0, 41.0 }, float3 { 0.72, -25.0, 49.0 }, float3 { 0.48, -25.0, 53.0 },
    float3 { 0.22, -25.0, 54.0 }, float3 { 0.0, 0.0, 54.0 },
];
let BACK_REAR: float3[6] = [
    float3 { 1.0, -21.0, -13.0 }, float3 { 1.0, -25.0, -20.0 }, float3 { 0.9, -25.0, -26.0 },
    float3 { 0.6, -25.0, -30.0 }, float3 { 0.25, -25.0, -31.0 }, float3 { 0.0, 0.0, -31.0 },
];
let BACK_MID = float2 { 0.0, 150.0 };
// The back's line in the side view (y, z): its middle (u 0, depth 0), from below the frame's
// foot over the crest, from library-chair-02's traced outline (its rear, the rear pad's
// depth added back), leaning about 10 degrees at its foot, 14 in its middle and 28 under the
// crest. v runs along it from SPINE_V0 at its first point; the sides wrap forward by WRAP
// at u = 200.
let BACK_SPINE: float2[10] = [
    float2 { 470.0, -165.0 }, float2 { 540.0, -176.0 }, float2 { 597.0, -186.0 }, float2 { 653.0, -198.0 },
    float2 { 710.0, -210.0 }, float2 { 766.0, -224.0 }, float2 { 822.0, -240.0 }, float2 { 878.0, -262.0 },
    float2 { 920.0, -284.0 }, float2 { 950.0, -304.0 },
];
let SPINE_V0: f32 = -70.0;
let SPINE_SAMPLES = 16;
// The back's line sampled: (y, z, length from its first point, 0).
type BackLine = float4[..192];
let WRAP: f32 = 10.0;
// The gimp braid, a cord of BRAID_R where the cloth meets the wood.
let BRAID_R: f32 = 3.5;
// The crest on the frame's top: a turned bud facing forward, two leaves curling out each
// side of it (u, d, v; w the leaf's half width).
let BUD: float2[6] = [
    float2 { 0.5, 14.0 }, float2 { 4.0, 13.0 }, float2 { 8.0, 10.0 }, float2 { 10.0, 6.0 }, float2 { 10.0, 3.0 },
    float2 { 8.0, 0.0 },
];
let BUD_AT = float3 { 0.0, 8.0, 404.0 };
let LEAF_UP: float4[6] = [
    float4 { 6.0, 12.0, 410.0, 5.0 }, float4 { 18.0, 13.0, 416.0, 5.0 }, float4 { 30.0, 12.0, 417.0, 4.0 },
    float4 { 40.0, 10.0, 412.0, 3.0 }, float4 { 42.0, 9.0, 405.0, 2.0 }, float4 { 36.0, 9.0, 402.0, 1.5 },
];
let LEAF_DOWN: float4[4] = [
    float4 { 8.0, 10.0, 398.0, 4.0 }, float4 { 22.0, 11.0, 394.0, 3.5 }, float4 { 34.0, 10.0, 393.0, 2.5 },
    float4 { 42.0, 9.0, 398.0, 1.5 },
];

// Both chairs on the floor at `floor_y` (world units), into verts and indices.
fn chairs(verts: Vertex[>..]&, indices: u32[>..]&, floor_y: f32) {
    var spine: BackLine = [];
    back_spine(spine);
    for c, k in CHAIRS { chair(verts, indices, spine, c, floor_y, k); }
}

// One chair at `at` (CHAIRS'), its pieces' grain offset by `which` so the two differ.
fn chair(verts: Vertex[>..]&, indices: u32[>..]&, spine: BackLine&, at: float4, floor_y: f32, which: i64) {
    let first = verts.len;
    let first_index = indices.len;
    // The apron round the seat.
    var line: float4[..96] = [];
    closed_line(line, SEAT_HALF[..], SEAT_SAMPLES);
    var path: Path = [];
    line_path(path, line);
    var prof: Profile = [];
    turned(prof, APRON[..], 1.0, 0.0);
    let apron_from = verts.len;
    sweep(verts, indices, prof, path, MAT_CHAIR);
    for i in apron_from..verts.len {
        let v .= verts[i];
        let foot = apron_foot(v.pos.x, v.pos.z);
        let k = (RAIL_TOP - foot) / APRON_H;
        // Its lowest band and its inside in the seat's shade.
        let under = if v.normal.y < -0.5 || dot(float2 { v.normal.x, v.normal.z }, float2 { v.pos.x, v.pos.z - SEAT_MID.y }) < 0.0 { 1.0 } else { 0.0 };
        let lit_ao = HIDDEN_AO + (1.0 - HIDDEN_AO) * model3d::ease(0.0, 18.0, v.pos.y);
        v.ao = lit_ao + (HIDDEN_AO - lit_ao) * under;
        v.pos.y = foot + v.pos.y * k;
        v.normal = normalize(float3 { v.normal.x, v.normal.y / k, v.normal.z });
    }
    grain_along_path(verts, apron_from);
    shift_uv(verts, apron_from, float2 { 37.0 + 300.0 * which, 0.0 });
    // The seat and its braid.
    cushion(verts, indices, line, SEAT_PAD[..], SEAT_MID, 1.0);
    cord(verts, indices, line, 14.0, RAIL_TOP + 2.5, -PI / 3.0, PI * 2.0 / 3.0);
    // The front legs, turned and fluted, under their blocks with a rosette on two faces.
    for side in 2 {
        let sx: f32 = if side == 0 { 1.0 } else { -1.0 };
        let c = float2 { sx * FRONT_LEG_AT.x, FRONT_LEG_AT.y };
        let from = verts.len;
        var lp: Profile = [];
        turned(lp, FRONT_LATHE[..], 1.0, 0.0);
        var lpath: Path = [];
        lathe_path(lpath, LATHE_SEGMENTS, c);
        sweep(verts, indices, lp, lpath, MAT_CHAIR);
        flutes(verts, from, c, lpath.len);
        under_seat(verts, from);
        shift_uv(verts, from, float2 { 120.0 * side + 410.0 * which, 90.0 * side });
        var cap_block: Spine = [];
        cap_block.push(Rib { float3 { c.x, BLOCK.z, c.y }, float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, 0.0, 1.0 }, float2 { BLOCK.x, BLOCK.x }, 0.15, 1.0 });
        cap_block.push(Rib { float3 { c.x, BLOCK.y, c.y }, float3 { 1.0, 0.0, 0.0 }, float3 { 0.0, 0.0, 1.0 }, float2 { BLOCK.x, BLOCK.x }, 0.15, 0.7 });
        bar(verts, indices, cap_block, MAT_CHAIR);
        let mid_y = 0.5 * (BLOCK.y + BLOCK.z);
        rosette(verts, indices, float3 { c.x, mid_y, c.y + BLOCK.x }, float3 { 0.0, 0.0, 1.0 }, float3 { 1.0, 0.0, 0.0 });
        rosette(verts, indices, float3 { c.x + sx * BLOCK.x, mid_y, c.y }, float3 { sx, 0.0, 0.0 }, float3 { 0.0, 0.0, 1.0 });
    }
    // The back legs, each one piece from its foot into the frame.
    for side in 2 {
        let sx: f32 = if side == 0 { 1.0 } else { -1.0 };
        var pts: float4[..16] = [];
        for q in BACK_LEG { pts.push(float4 { sx * q.x, q.y, q.z, q.w }); }
        let end = back_point(spine, 150.0, 85.0, -2.0);
        pts.push(float4 { sx * end.x, end.y, end.z, 13.0 });
        var leg: float4[..96] = [];
        smooth_open(leg, pts[..], 3);
        var s: Spine = [];
        for k in leg.len { s.push(rib(leg[..], k, false, float3 { 0.0, 0.0, 1.0 }, float2 { leg[k].w, leg[k].w * BACK_DEEP }, 0.6)); }
        let from = verts.len;
        bar(verts, indices, s, MAT_CHAIR);
        under_seat(verts, from);
        shift_uv(verts, from, float2 { 210.0 + 170.0 * which + 60.0 * side, 0.0 });
    }
    // The back, flat: its frame, its pads and their braids, the crest; then bent.
    let back_from = verts.len;
    var med: float4[..96] = [];
    closed_line(med, MEDALLION[..], MEDALLION_SAMPLES);
    var mpath: Path = [];
    line_path(mpath, med);
    var fp: Profile = [];
    turned(fp, FRAME[..], 1.0, 0.0);
    sweep(verts, indices, fp, mpath, MAT_CHAIR);
    for i in back_from..verts.len {
        let v .= verts[i];
        let to_mid = float2 { BACK_MID.x - v.pos.x, BACK_MID.y - v.pos.z };
        let inward = clamp(dot(normalize(float2 { v.normal.x, v.normal.z } + float2 { 1e-6, 0.0 }), normalize(to_mid)), 0.0, 1.0);
        v.ao = 1.0 - (0.9 - HIDDEN_AO) * inward;
    }
    grain_along_path(verts, back_from);
    shift_uv(verts, back_from, float2 { 60.0 + 230.0 * which, 500.0 });
    cushion(verts, indices, med, BACK_FRONT[..], BACK_MID, 1.0);
    cushion(verts, indices, med, BACK_REAR[..], BACK_MID, -1.0);
    cord(verts, indices, med, -23.5, 4.0 + BRAID_R, 0.0, PI);
    cord(verts, indices, med, -23.5, -13.0 - BRAID_R, PI, 2.0 * PI);
    crest(verts, indices);
    bend_back(verts, back_from, spine);
    face_out(verts, indices, first_index);
    // Into the world: millimetres to world units, turned, set on the floor.
    let s = at.z;
    let c = at.w;
    for i in first..verts.len {
        let v .= verts[i];
        let p = v.pos * CHAIR_MM;
        v.pos = float3 { at.x + c * p.x + s * p.z, floor_y + p.y, at.y - s * p.x + c * p.z };
        v.normal = float3 { c * v.normal.x + s * v.normal.z, v.normal.y, -s * v.normal.x + c * v.normal.z };
        v.uv = v.uv * CHAIR_MM;
    }
}

// A closed line smooth through `half` (x, z) and its mirror, `per` samples a span (x, 0, z;
// w unused), counterclockwise seen from above.
fn closed_line(line: float4[..96]&, half: const float2[:], per: i64) {
    var ring: float4[..32] = [];
    for q in half { ring.push(float4 { q.x, 0.0, q.y, 0.0 }); }
    for i in 1..half.len - 1 {
        let q = half[half.len - 1 - i];
        ring.push(float4 { -q.x, 0.0, q.y, 0.0 });
    }
    let n = ring.len;
    for i in n {
        let a = ring[(i + n - 1) % n];
        let b = ring[i];
        let c = ring[(i + 1) % n];
        let d = ring[(i + 2) % n];
        for s in per { line.push(catmull(a, b, c, d, s as f32 / per)); }
    }
}

// The direction out from a closed line (its x, z) at point k, square to it in its plane.
fn outward(line: float4[..96]&, k: i64) -> float2 {
    let n = line.len;
    let a = line[(k + n - 1) % n];
    let b = line[(k + 1) % n];
    let t = normalize(float2 { b.x - a.x, b.z - a.z });
    let o = float2 { t.y, -t.x };
    // Away from the line's middle (the lines here are round enough for its mean).
    var m = float2_0;
    for q in line { m = m + float2 { q.x, q.z }; }
    m = m * (1.0 / (n as f32));
    let q = line[k];
    return if dot(o, float2 { q.x, q.z } - m) < 0.0 { o * -1.0 } else { o };
}

// A sweep's path along a closed line, each sample's direction out from it, closed.
fn line_path(path: Path&, line: float4[..96]&) {
    for q, k in line { path.push(Sample { float2 { q.x, q.z }, outward(line, k) }); }
    path.push(path[0]);
}

// The apron's foot at (x, z): lower in the middle of the front and of each side.
fn apron_foot(x: f32, z: f32) -> f32 {
    let front = exp(-(x / 120.0) * (x / 120.0)) * model3d::ease(100.0, 180.0, z);
    let side = 0.7 * exp(-((z - 20.0) / 110.0) * ((z - 20.0) / 110.0)) * model3d::ease(150.0, 200.0, abs(x));
    return APRON_FOOT - APRON_DIP * max(front, side);
}

// A sweep's uv turned so the grain (the wood's v) runs along its path, not across it.
fn grain_along_path(verts: Vertex[>..]&, from: i64) {
    for i in from..verts.len { verts[i].uv = float2 { verts[i].uv.y, verts[i].uv.x }; }
}

// The legs' wood from `from` darker in the seat's shade under it, and a little at the floor.
fn under_seat(verts: Vertex[>..]&, from: i64) {
    for i in from..verts.len {
        let v .= verts[i];
        let y = v.pos.y;
        let seat = model3d::ease(180.0, 340.0, y) * (1.0 - model3d::ease(RAIL_TOP, RAIL_TOP + 40.0, y));
        let floor = 1.0 - model3d::ease(0.0, 70.0, y);
        v.ao = v.ao * (1.0 - (1.0 - HIDDEN_AO) * seat) * (1.0 - 0.25 * floor);
    }
}

// A front leg's flutes: the shaft's vertices from `from` (a lathe of `n` samples round,
// its last the first again, about c) pushed in by a rounded groove each, faded at both ends;
// the normals tilted by the groove's slope round the leg.
fn flutes(verts: Vertex[>..]&, from: i64, c: float2, n: i64) {
    let seg = n - 1;
    for i in from..verts.len {
        let v .= verts[i];
        guard v.pos.y > FLUTE_FROM && v.pos.y < FLUTE_TO else { continue; }
        let fade = model3d::ease(FLUTE_FROM, FLUTE_FROM + FLUTE_FADE, v.pos.y) * (1.0 - model3d::ease(FLUTE_TO - FLUTE_FADE, FLUTE_TO, v.pos.y));
        let j = (i - from) % n;
        let a = TAU * ((j % seg) as f32) / (seg as f32);
        let w = 0.5 + 0.5 * cos(FLUTES as f32 * a);
        let h = FLUTE_DEPTH * fade * w * w;
        let dh = FLUTE_DEPTH * fade * 2.0 * w * (-0.5 * FLUTES as f32 * sin(FLUTES as f32 * a));
        let dir = float2 { cos(a), sin(a) };
        let r = length(float2 { v.pos.x - c.x, v.pos.z - c.y });
        let rr = r - h;
        v.pos.x = c.x + dir.x * rr;
        v.pos.z = c.y + dir.y * rr;
        let t = float3 { -dir.y, 0.0, dir.x };
        v.normal = normalize(v.normal + t * (dh / max(r, 1.0)));
    }
}

// A rosette on a block's face at `at`, facing `face`, `ex` across it: a small turned boss
// with eight petals, turned about its own axis and set on the face.
fn rosette(verts: Vertex[>..]&, indices: u32[>..]&, at: float3, face: float3, ex: float3) {
    let from = verts.len;
    var p: Profile = [];
    turned(p, ROSETTE[..], 1.0, 0.0);
    var path: Path = [];
    lathe_path(path, 16);
    sweep(verts, indices, p, path, MAT_CHAIR);
    petals(verts, from, path.len, 8, 0.3);
    place(verts, from, at, ex, face);
}

// A turned piece's outer points (out past 3 mm) pulled in between `count` petals round its
// axis, by up to `depth` of their radius; a lathe of `n` samples round from `from`.
fn petals(verts: Vertex[>..]&, from: i64, n: i64, count: i64, depth: f32) {
    let seg = n - 1;
    for i in from..verts.len {
        let v .= verts[i];
        let r = length(float2 { v.pos.x, v.pos.z });
        guard r > 3.0 else { continue; }
        let a = TAU * (((i - from) % n % seg) as f32) / (seg as f32);
        let k = 1.0 - depth * (0.5 - 0.5 * cos(count as f32 * a)) * model3d::ease(3.0, 8.0, r);
        v.pos.x = v.pos.x * k;
        v.pos.z = v.pos.z * k;
    }
}

// Vertices from `from`, made about the origin with their axis up (y), set at `at` with
// that axis along `ey` and their x along `ex`.
fn place(verts: Vertex[>..]&, from: i64, at: float3, ex: float3, ey: float3) {
    let ez = cross(ex, ey);
    for i in from..verts.len {
        let v .= verts[i];
        let p = v.pos;
        let n = v.normal;
        v.pos = at + ex * p.x + ey * p.y + ez * p.z;
        v.normal = ex * n.x + ey * n.y + ez * n.z;
    }
}

// The crest on the back's top, in its flat plane: the bud, a turned boss with five petals
// facing forward, and two leaves each side curling out from it.
fn crest(verts: Vertex[>..]&, indices: u32[>..]&) {
    let from = verts.len;
    var p: Profile = [];
    turned(p, BUD[..], 1.0, 0.0);
    var path: Path = [];
    lathe_path(path, 12);
    sweep(verts, indices, p, path, MAT_CHAIR);
    petals(verts, from, path.len, 5, 0.35);
    for i in from..verts.len { verts[i].pos = verts[i].pos + BUD_AT; }
    for side in 2 {
        let sx: f32 = if side == 0 { 1.0 } else { -1.0 };
        leaf(verts, indices, LEAF_UP[..], sx);
        leaf(verts, indices, LEAF_DOWN[..], sx);
    }
}

// A carved leaf, a flat bar through `pts` (u, d, v; w its half width), on the side `sx`.
fn leaf(verts: Vertex[>..]&, indices: u32[>..]&, pts: const float4[:], sx: f32) {
    var q: float4[..16] = [];
    for a in pts { q.push(float4 { sx * a.x, a.y, a.z, a.w }); }
    var curve: float4[..96] = [];
    smooth_open(curve, q[..], 2);
    var s: Spine = [];
    for k in curve.len { s.push(rib(curve[..], k, false, float3 { 0.0, 1.0, 0.0 }, float2 { curve[k].w, 0.45 * curve[k].w + 0.6 }, 0.8)); }
    bar(verts, indices, s, MAT_CHAIR);
}

// The back's line (BACK_SPINE) sampled smooth: (y, z, its length from the first point, 0).
fn back_spine(out: BackLine&) {
    var pts: float4[..16] = [];
    for q in BACK_SPINE { pts.push(float4 { q.x, q.y, 0.0, 0.0 }); }
    var curve: BackLine = [];
    let n = pts.len;
    for i in n - 1 {
        let a = pts[max(i - 1, 0)];
        let b = pts[i];
        let c = pts[i + 1];
        let d = pts[min(i + 2, n - 1)];
        for k in SPINE_SAMPLES { curve.push(catmull(a, b, c, d, k as f32 / SPINE_SAMPLES)); }
    }
    curve.push(pts[n - 1]);
    var s: f32 = 0.0;
    for q, k in curve {
        if k > 0 { s += length(float2 { q.x - curve[k - 1].x, q.y - curve[k - 1].y }); }
        out.push(float4 { q.x, q.y, s, 0.0 });
    }
}

// The piece of the back's line that v falls on: the index of its upper end.
fn spine_index(spine: BackLine&, v: f32) -> i64 {
    let s = v - SPINE_V0;
    var i = 1;
    while i < spine.len - 1 && spine[i].z < s { i += 1; }
    return i;
}

// The back's line at v: its point (y, z) and its tangent, the tangents at the samples
// blended along each piece so the bend's shading has no steps.
fn spine_tangent(spine: BackLine&, i: i64) -> float2 {
    let a = spine[max(i - 1, 0)];
    let b = spine[min(i + 1, spine.len - 1)];
    return normalize(float2 { b.x - a.x, b.y - a.y });
}
fn spine_frame(spine: BackLine&, v: f32) -> float4 {
    let i = spine_index(spine, v);
    let a = spine[i - 1];
    let b = spine[i];
    let t = clamp((v - SPINE_V0 - a.z) / (b.z - a.z), 0.0, 1.0);
    let tan = normalize(spine_tangent(spine, i - 1) * (1.0 - t) + spine_tangent(spine, i) * t);
    let tu = (v - SPINE_V0 - a.z) / (b.z - a.z);
    return float4 { a.x + (b.x - a.x) * tu, a.y + (b.y - a.y) * tu, tan.x, tan.y };
}

// A point of the back's flat plane (u across, v up it, d toward the front) in the chair:
// v along the back's line, d along its normal toward the front, the sides wrapped forward.
fn back_point(spine: BackLine&, u: f32, v: f32, d: f32) -> float3 {
    let f = spine_frame(spine, v);
    let fwd = float2 { -f.w, f.z };
    let dd = d + WRAP * (u / 200.0) * (u / 200.0);
    return float3 { u, f.x + fwd.x * dd, f.y + fwd.y * dd };
}

// The back's vertices from `from`, built flat (x = u, y = d, z = v), bent into the chair
// (back_point); their normals through the same map: the wrap's slope across, then turned
// with the line.
fn bend_back(verts: Vertex[>..]&, from: i64, spine: BackLine&) {
    for i in from..verts.len {
        let v .= verts[i];
        let u = v.pos.x;
        let f = spine_frame(spine, v.pos.z);
        let tan = float2 { f.z, f.w };
        let fwd = float2 { -tan.y, tan.x };
        let p = back_point(spine, u, v.pos.z, v.pos.y);
        // n in the flat frame (across, along the line, forward), the wrap's shear undone.
        let nu = v.normal.x - WRAP * 2.0 * u / (200.0 * 200.0) * v.normal.y;
        let nv = v.normal.z;
        let nd = v.normal.y;
        v.pos = p;
        v.normal = normalize(float3 { nu, tan.x * nv + fwd.x * nd, tan.y * nv + fwd.y * nd });
    }
}

// A cushion over a closed line, its rings `rings` (share of the way from `mid` to the line, out
// past the line, height) outermost first, its middle one point: the seat's in the chair,
// the back's in its flat plane (height its depth). Its normals summed from its faces,
// turned to `facing` (1 up, -1 down); its uv unrolled from the middle by the distance over
// its surface, so the cloth's pattern keeps its size down a rolled edge.
fn cushion(verts: Vertex[>..]&, indices: u32[>..]&, line: float4[..96]&, given: const float3[:], mid: float2, facing: f32) {
    let base = verts.len;
    let n = line.len + 1;
    // The given rings smooth, CUSHION_PER between each two, so the pad's shading has no
    // creases at them.
    var rings: float3[..48] = [];
    for i in given.len - 1 {
        let a = given[max(i - 1, 0)];
        let b = given[i];
        let c = given[i + 1];
        let d = given[min(i + 2, given.len - 1)];
        for k in CUSHION_PER {
            let q = catmull(float4 { a.x, a.y, a.z, 0.0 }, float4 { b.x, b.y, b.z, 0.0 }, float4 { c.x, c.y, c.z, 0.0 }, float4 { d.x, d.y, d.z, 0.0 }, k as f32 / CUSHION_PER);
            rings.push(float3 { clamp(q.x, 0.0, 1.0), q.y, q.z });
        }
    }
    rings.push(given[given.len - 1]);
    for r in rings {
        for j in n {
            let q = line[j % line.len];
            let o = outward(line, j % line.len);
            // Out past the line by its own share, so the small rings near the middle keep
            // their shape instead of folding where the middle is near the line.
            let x = mid.x + (q.x - mid.x) * r.x + o.x * r.y * r.x;
            let z = mid.y + (q.z - mid.y) * r.x + o.y * r.y * r.x;
            verts.push(Vertex { float3 { x, r.z, z }, float3_0, float2_0, 1.0, MAT_SEAT });
        }
    }
    // uv: out from the middle along each column, by the surface's length.
    for j in n {
        var dist: f32 = 0.0;
        var k = rings.len - 1;
        while k >= 0 {
            let v .= verts[base + k * n + j];
            if k < rings.len - 1 { dist += length(v.pos - verts[base + (k + 1) * n + j].pos); }
            let q = line[j % line.len];
            let dir = normalize(float2 { q.x - mid.x, q.z - mid.y });
            v.uv = mid + dir * dist;
            k -= 1;
        }
        // Darker toward the edge, where the pad rolls under into the braid and the frame: the
        // light the room throws at it is cut off there (what the probes can't see).
        k = 0;
        var from_edge: f32 = 0.0;
        while k < rings.len {
            let v .= verts[base + k * n + j];
            if k > 0 { from_edge += length(v.pos - verts[base + (k - 1) * n + j].pos); }
            v.ao = CUSHION_EDGE_AO + (1.0 - CUSHION_EDGE_AO) * model3d::ease(0.0, CUSHION_EDGE_REACH, from_edge);
            k += 1;
        }
    }
    let first_index = indices.len;
    for k in rings.len - 1 {
        for j in n - 1 {
            let a = (base + k * n + j) as u32;
            let b = a + n as u32;
            indices.append([a, a + 1, b + 1, a, b + 1, b]);
        }
    }
    // Summed face normals, each ring's seam (its first and last point, one place) shared.
    var i = first_index;
    while i < indices.len {
        let a = indices[i] as i64;
        let b = indices[i + 1] as i64;
        let c = indices[i + 2] as i64;
        let f = cross(verts[b].pos - verts[a].pos, verts[c].pos - verts[a].pos);
        verts[a].normal = verts[a].normal + f;
        verts[b].normal = verts[b].normal + f;
        verts[c].normal = verts[c].normal + f;
        i += 3;
    }
    for k in rings.len {
        let s = base + k * n;
        let sum = verts[s].normal + verts[s + n - 1].normal;
        verts[s].normal = sum;
        verts[s + n - 1].normal = sum;
    }
    // Turned to face `facing`, judged by the ring next to the middle.
    let side: f32 = if verts[base + (rings.len - 2) * n].normal.y * facing < 0.0 { -1.0 } else { 1.0 };
    for i in base..verts.len {
        let v .= verts[i];
        v.normal = if length(v.normal) > 1e-6 { normalize(v.normal) * side } else { float3 { 0.0, facing, 0.0 } };
    }
    // The middle, one point: all its copies the mean of theirs.
    let m0 = base + (rings.len - 1) * n;
    var mean = float3_0;
    for i in m0..verts.len { mean = mean + verts[i].normal; }
    for i in m0..verts.len { verts[i].normal = normalize(mean); }
}

// A braid along a closed line, out past it by `off` at `height`: a cord of BRAID_R from
// angle a0 to a1 round its middle (0 out from the line, PI / 2 up); uv along it and round.
fn cord(verts: Vertex[>..]&, indices: u32[>..]&, line: float4[..96]&, off: f32, height: f32, a0: f32, a1: f32) {
    let base = verts.len;
    let n = line.len + 1;
    let steps = 3;
    for k in steps + 1 {
        let a = a0 + (a1 - a0) * k as f32 / steps;
        var along: f32 = 0.0;
        for j in n {
            let q = line[j % line.len];
            let o = outward(line, j % line.len);
            if j > 0 {
                let p = line[(j - 1) % line.len];
                along += length(float2 { q.x - p.x, q.z - p.z });
            }
            let out = off + BRAID_R * cos(a);
            let pos = float3 { q.x + o.x * out, height + BRAID_R * sin(a), q.z + o.y * out };
            let nrm = float3 { o.x * cos(a), sin(a), o.y * cos(a) };
            verts.push(Vertex { pos, nrm, float2 { along, a * BRAID_R }, HIDDEN_AO + 0.2, MAT_TRIM });
        }
    }
    for k in steps {
        for j in n - 1 {
            let a = (base + k * n + j) as u32;
            let b = a + n as u32;
            indices.append([a, a + 1, b + 1, a, b + 1, b]);
        }
    }
}

// An open curve smooth through `pts`, `per` samples a span, its last point kept.
fn smooth_open(out: float4[..96]&, pts: const float4[:], per: i64) {
    let n = pts.len;
    for i in n - 1 {
        let a = pts[max(i - 1, 0)];
        let b = pts[i];
        let c = pts[i + 1];
        let d = pts[min(i + 2, n - 1)];
        for s in per { out.push(catmull(a, b, c, d, s as f32 / per)); }
    }
    out.push(pts[n - 1]);
}

// A rib at point k of a curve (round its ends where `closed`), its section's depth along
// `toward` turned square to the curve, half sizes `half` (in the curve's bend, along
// `toward`).
fn rib(curve: const float4[:], k: i64, closed: bool, toward: float3, half: float2, round: f32) -> Rib {
    let n = curve.len;
    let a = if closed { curve[(k + n - 1) % n] } else { curve[max(k - 1, 0)] };
    let b = if closed { curve[(k + 1) % n] } else { curve[min(k + 1, n - 1)] };
    let q = curve[k];
    let t = normalize(float3 { b.x - a.x, b.y - a.y, b.z - a.z });
    let across = normalize(toward - t * dot(toward, t));
    return Rib { float3 { q.x, q.y, q.z }, normalize(cross(across, t)), across, half, round, 1.0 };
}

// The pieces' grain moved along so no two show the same figure.
fn shift_uv(verts: Vertex[>..]&, from: i64, by: float2) {
    for i in from..verts.len { verts[i].uv = verts[i].uv + by; }
}

// Every triangle from `first_index` on turned to face where its vertices' normals point
// (counterclockwise seen from outside, as the table's pipeline culls), whichever way its
// piece's frame happened to run.
fn face_out(verts: Vertex[>..]&, indices: u32[>..]&, first_index: i64) {
    var i = first_index;
    while i < indices.len {
        let a = verts[indices[i] as i64];
        let b = verts[indices[i + 1] as i64];
        let c = verts[indices[i + 2] as i64];
        let f = cross(b.pos - a.pos, c.pos - a.pos);
        if dot(f, a.normal + b.normal + c.normal) < 0.0 {
            let t = indices[i + 1];
            indices[i + 1] = indices[i + 2];
            indices[i + 2] = t;
        }
        i += 3;
    }
}
