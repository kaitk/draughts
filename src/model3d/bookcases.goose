// The open bookcases built into the hall wall either side of the door (option B of
// build/notes/bookcases/, shell.goose's bookcase_at), in the wainscot's oak: a folio base
// 0.45 m deep on the wainscot's plinth, its 35 mm ledge on the cap's line at 1.20 m, an
// upper case 0.30 m deep, its 140 mm cornice on the architrave head's band (2.70 to
// 2.84 m), two bays on a middle upright, pilaster strips with sunk panels on the ends,
// and the books on their shelves (books.goose). Built once with the shell.
namespace room_shell;
import std;
import vec;
import math;

// Heights (metres over the floor) from build/notes/bookcases/src/gen.py's layout of B: the
// plinth, the boards, the ledge's underside, the cornice's foot (the door's head); the
// clear heights of the base's two folio compartments and the upper case's five (a quarto,
// three octavo, a duodecimo) from the bottom up. The ends' width (the side board and the
// pilaster strip in front of it), the middle upright's, the back boards'.
let CASE_PLINTH:  f32    = 0.17;
let CASE_BOARD:   f32    = 0.022;
let LEDGE_LOW:    f32    = 1.165;
let CORNICE_FOOT: f32    = 2.70;
let CASE_END:     f32    = 0.06;
let CASE_UPRIGHT: f32    = 0.022;
let CASE_BACK:    f32    = 0.012;
let BASE_CLEAR:   f32[2] = [0.477, 0.474];
let UPPER_CLEAR:  f32[5] = [0.34, 0.275, 0.27, 0.265, 0.208];
// How far the shelves' fronts stand back from the case's.
let SHELF_BACK: f32 = 0.004;

// The case's profiles in centimetres (out from its face, up, the light's occlusion), from
// gen.py: the plinth as the wainscot's, 17 cm, 1.5 cm proud, its top edge rounded; the
// ledge, a 35 mm board 25 mm proud with a thumbnail ovolo on a cavetto bed (from 1.153 m);
// the cornice, a frieze in the face, a bead, a cavetto, the corona's soffit and an ovolo,
// 6 cm proud, from the door's head to 2.84 m.
let CASE_PLINTH_P: float3[6] = [
    float3 { 1.5, 0.0, 0.7 }, float3 { 1.5, 16.4, 0.95 }, float3 { 1.42, 16.7, 1.0 }, float3 { 1.2, 16.92, 1.0 },
    float3 { 0.9, 17.0, 1.0 }, float3 { 0.0, 17.0, 0.8 },
];
let LEDGE_P: float3[10] = [
    float3 { 0.0, -1.2, 0.7 }, float3 { 0.16, -0.6, 0.75 }, float3 { 0.6, -0.16, 0.8 }, float3 { 1.2, 0.0, 0.85 },
    float3 { 2.5, 0.0, 0.9 }, float3 { 2.5, 2.3, 1.0 }, float3 { 2.34, 2.9, 1.0 }, float3 { 1.9, 3.34, 1.0 },
    float3 { 1.3, 3.5, 1.0 }, float3 { 0.0, 3.5, 1.0 },
];
let CORNICE_P: float3[20] = [
    float3 { 0.0, 0.0, 0.9 }, float3 { 0.0, 6.2, 0.95 }, float3 { 0.35, 6.35, 1.0 }, float3 { 0.5, 6.7, 1.0 },
    float3 { 0.35, 7.05, 0.95 }, float3 { 0.0, 7.2, 0.85 }, float3 { 0.2, 7.2, 0.85 }, float3 { 0.37, 8.04, 0.85 },
    float3 { 0.84, 8.76, 0.9 }, float3 { 1.56, 9.23, 0.95 }, float3 { 2.4, 9.4, 1.0 }, float3 { 2.7, 9.4, 1.0 },
    float3 { 2.7, 10.0, 1.0 }, float3 { 4.8, 10.0, 0.8 }, float3 { 4.8, 12.4, 0.95 }, float3 { 5.4, 12.56, 1.0 },
    float3 { 5.84, 13.0, 1.0 }, float3 { 6.0, 13.6, 1.0 }, float3 { 6.0, 14.0, 1.0 }, float3 { 0.0, 14.0, 1.0 },
];
// The wainscot's plinth where only a strip of wall is left (between a case and the door's
// architrave): its board closed against the wall at its top, the paper over it.
let BARE_PLINTH: float3[9] = [
    float3 { 5.0, 0.0, 0.55 }, float3 { 5.0, 0.8, 0.8 }, float3 { 4.6, 1.2, 0.85 }, float3 { 4.0, 1.4, 0.9 },
    float3 { 4.0, 15.5, 0.95 }, float3 { 3.85, 16.3, 1.0 }, float3 { 3.4, 16.8, 1.0 }, float3 { 2.9, 17.0, 0.95 },
    float3 { 0.0, 17.0, 0.6 },
];

// The faces of a box, a bit each.
let FACE_FRONT = 1;
let FACE_LEFT = 2;
let FACE_RIGHT = 4;
let FACE_TOP = 8;
let FACE_BOTTOM = 16;

// The light's occlusion inside the case: the back, the shelves' tops and undersides, the
// ends' and the upright's sides.
let AO_BACK:  f32 = 0.22;
let AO_SHELF: f32 = 0.5;
let AO_UNDER: f32 = 0.3;
let AO_SIDE:  f32 = 0.5;

// A vector's x, y or z by number.
fn axis(v: float3, i: i64) -> f32 { if i == 0 { v.x } else if i == 1 { v.y } else { v.z } }

// An oak box over lo..hi (metres: s along b's wall, y up, z out of it), the faces in
// `faces`, each its own piece of the wall's field with the grain along the box's longest
// side; `front` the front's occlusion, `ao` the others'.
fn oak_box(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, lo: float3, hi: float3, faces: i64,
           front: f32, ao: f32, seed: i64&) {
    let k = m();
    let a = lo * k;
    let c = hi * k;
    let e = c - a;
    // 0 the grain along s, 1 up, 2 out.
    let grain = if e.x >= e.y && e.x >= e.z { 0 } else if e.y >= e.z { 1 } else { 2 };
    seed++;
    let mat = surfaces::MAT_OAK + 0.9 * surfaces::hash(seed, 9);
    for f in 5 {
        guard faces & (1 << f) != 0 else { continue; }
        var p: float3[4] = [float3_0; 4];
        var side = float3 { 0.0, 0.0, 1.0 };
        // Each face's two axes in the box's frame (0 s, 1 y, 2 z): across and along the grain.
        var across = 0;
        var along = 1;
        if f == 0 {
            p = [float3 { a.x, a.y, c.z }, float3 { c.x, a.y, c.z }, float3 { c.x, c.y, c.z }, float3 { a.x, c.y, c.z }];
            if grain == 0 { across = 1; along = 0; }
        } else if f < 3 {
            let x = if f == 1 { a.x } else { c.x };
            p = [float3 { x, a.y, a.z }, float3 { x, a.y, c.z }, float3 { x, c.y, c.z }, float3 { x, c.y, a.z }];
            side = float3 { if f == 1 { -1.0 } else { 1.0 }, 0.0, 0.0 };
            across = 2;
            if grain == 2 { across = 1; along = 2; }
        } else {
            let y = if f == 3 { c.y } else { a.y };
            p = [float3 { a.x, y, a.z }, float3 { c.x, y, a.z }, float3 { c.x, y, c.z }, float3 { a.x, y, c.z }];
            side = float3 { 0.0, if f == 3 { 1.0 } else { -1.0 }, 0.0 };
            across = 2;
            along = 0;
            if grain == 2 { across = 0; along = 2; }
        }
        seed++;
        let pm = surfaces::piece_map(seed, true, axis(a, across), axis(a, along), axis(e, across), axis(e, along), true);
        var uv: float2[4] = [float2_0; 4];
        for i in 4 { uv[i] = surfaces::place(pm, axis(p[i], across), axis(p[i], along)); }
        let o = if f == 0 { front } else { ao };
        surfaces::quad(verts, indices, b, p, uv, [o, o, o, o], mat, side);
    }
}

// A profile swept along the case's front (its face `depth` out of the wall) from s 0 to
// `width`, mitred round both front corners, and returned along both sides to the wall.
fn profiled(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, width: f32, depth: f32, prof: float3[],
            lift: f32, seed: i64&) {
    let k = m();
    seed++;
    sweep(verts, indices, moved(b, 0.0, depth * k), prof[..], lift, 0.0, width * k, -1.0, 1.0, surfaces::MAT_OAK, seed, cm_up());
    for side in SIDES {
        let s = if side < 0.0 { 0.0 } else { width * k };
        let r = surfaces::Builder { b.o + b.d * s, b.n, b.d * side };
        seed++;
        sweep(verts, indices, r, prof[..], lift, 0.0, depth * k, 0.0, 1.0, surfaces::MAT_OAK, seed, cm_up());
    }
}

// A pilaster strip's front over s0..s1, y0..y1 at z: a frame `rim` wide round a panel sunk
// 6 mm, its four reveals.
fn sunk_front(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, s0: f32, s1: f32, y0: f32, y1: f32,
              z: f32, seed: i64&) {
    let rim:  f32 = 0.012;
    let sink: f32 = 0.006;
    let ends: f32 = 0.05;
    let a = s0 + rim;
    let c = s1 - rim;
    let lo = y0 + ends;
    let hi = y1 - ends;
    let front = FACE_FRONT;
    oak_box(verts, indices, b, float3 { s0, y0, z - 0.01 }, float3 { s1, lo, z }, front, 1.0, 1.0, seed);
    oak_box(verts, indices, b, float3 { s0, hi, z - 0.01 }, float3 { s1, y1, z }, front, 1.0, 1.0, seed);
    oak_box(verts, indices, b, float3 { s0, lo, z - 0.01 }, float3 { a, hi, z }, front | FACE_RIGHT, 1.0, 0.8, seed);
    oak_box(verts, indices, b, float3 { c, lo, z - 0.01 }, float3 { s1, hi, z }, front | FACE_LEFT, 1.0, 0.8, seed);
    oak_box(verts, indices, b, float3 { a, lo, z - sink - 0.01 }, float3 { c, hi, z - sink }, front, 0.9, 0.9, seed);
    // The reveals over and under the sunk panel.
    oak_box(verts, indices, b, float3 { a, hi, z - sink }, float3 { c, hi + 0.001, z }, FACE_BOTTOM, 1.0, 0.7, seed);
    oak_box(verts, indices, b, float3 { a, lo - 0.001, z - sink }, float3 { c, lo, z }, FACE_TOP, 1.0, 0.85, seed);
}

// A flat face facing up (`up` 1) or down (-1) at height y over s0..s1, z0..z1.
fn flat(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, s0: f32, s1: f32, y: f32, z0: f32, z1: f32,
        up: f32, ao: f32, seed: i64&) {
    let face = if up > 0.0 { FACE_TOP } else { FACE_BOTTOM };
    let lo = if up > 0.0 { y - 0.001 } else { y };
    oak_box(verts, indices, b, float3 { s0, lo, z0 }, float3 { s1, lo + 0.001, z1 }, face, ao, ao, seed);
}

// The back of a stage over s0..s1, y0..y1: the back boards at CASE_BACK.
fn back(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, s0: f32, s1: f32, y0: f32, y1: f32, seed: i64&) {
    oak_box(verts, indices, b, float3 { s0, y0, 0.0 }, float3 { s1, y1, CASE_BACK }, FACE_FRONT, AO_BACK, AO_BACK, seed);
}

// A bookcase in wall wb (o: its middle and width along it, its base's and upper case's
// depths), with its books unless `books_on` is false; `door` the hall door's middle along
// the wall, the side its books face the windows most squarely from, so fade most.
fn bookcase(verts: mesh::Vertex[>..]&, indices: u32[>..]&, wb: surfaces::Builder, o: Opening, door: f32, books_on: bool,
            uses: books::Uses&, seed: i64&) {
    let w = o.width;
    let b = moved(wb, (o.mid - 0.5 * w) * m(), 0.0);
    let base = o.glass.x;
    let upper = o.glass.y;
    let ledge_top = WAINSCOT_TOP;
    let floor_in = CASE_PLINTH + CASE_BOARD;
    let upper_in = ledge_top + CASE_BOARD;
    let top_in = CORNICE_FOOT - 0.032;
    // The plinth, the ledge and the cornice, and their tops.
    profiled(verts, indices, b, w, base, CASE_PLINTH_P[..], 0.0, seed);
    profiled(verts, indices, b, w, base, LEDGE_P[..], LEDGE_LOW * 100.0, seed);
    profiled(verts, indices, b, w, upper, CORNICE_P[..], CORNICE_FOOT * 100.0, seed);
    flat(verts, indices, b, 0.0, w, ledge_top, upper, base, 1.0, 1.0, seed);
    flat(verts, indices, b, 0.0, w, o.height, 0.0, upper, 1.0, 1.0, seed);
    // The ends: the side boards with their pilaster strips, inside and out.
    let ins: float2[2] = [float2 { 0.0, CASE_END }, float2 { w - CASE_END, w }];
    for e, i in ins {
        let out_face = if i == 0 { FACE_LEFT } else { FACE_RIGHT };
        let in_face = if i == 0 { FACE_RIGHT } else { FACE_LEFT };
        oak_box(verts, indices, b, float3 { e.x, CASE_PLINTH, 0.0 }, float3 { e.y, LEDGE_LOW, base }, out_face, 0.9, 0.9, seed);
        oak_box(verts, indices, b, float3 { e.x, floor_in, 0.0 }, float3 { e.y, LEDGE_LOW, base - 0.01 }, in_face, AO_SIDE, AO_SIDE, seed);
        sunk_front(verts, indices, b, e.x, e.y, CASE_PLINTH, LEDGE_LOW - 0.012, base, seed);
        oak_box(verts, indices, b, float3 { e.x, ledge_top, 0.0 }, float3 { e.y, CORNICE_FOOT, upper }, out_face, 0.9, 0.9, seed);
        oak_box(verts, indices, b, float3 { e.x, upper_in, 0.0 }, float3 { e.y, top_in, upper - 0.01 }, in_face, AO_SIDE, AO_SIDE, seed);
        sunk_front(verts, indices, b, e.x, e.y, ledge_top, CORNICE_FOOT, upper, seed);
    }
    let in0 = CASE_END;
    let in1 = w - CASE_END;
    let mid = 0.5 * w;
    let bays: float2[2] = [float2 { in0, mid - 0.5 * CASE_UPRIGHT }, float2 { mid + 0.5 * CASE_UPRIGHT, in1 }];
    let sides = FACE_LEFT | FACE_RIGHT;
    // The base: its bottom board, the upright, the shelf between the folios, the ledge's
    // underside, the back.
    oak_box(verts, indices, b, float3 { in0, CASE_PLINTH, 0.0 }, float3 { in1, floor_in, base }, FACE_TOP | FACE_FRONT, 1.0, AO_SHELF,
            seed);
    oak_box(verts, indices, b, float3 { bays[0].y, floor_in, CASE_BACK }, float3 { bays[1].x, LEDGE_LOW, base - SHELF_BACK },
            sides | FACE_FRONT, 1.0, AO_SIDE, seed);
    flat(verts, indices, b, in0, in1, LEDGE_LOW, CASE_BACK, base, -1.0, AO_UNDER, seed);
    back(verts, indices, b, in0, in1, floor_in, LEDGE_LOW, seed);
    // The upper case: its bottom board on the ledge, the upright, the top rail, the back.
    oak_box(verts, indices, b, float3 { in0, ledge_top, 0.0 }, float3 { in1, upper_in, upper }, FACE_TOP | FACE_FRONT, 1.0, AO_SHELF,
            seed);
    oak_box(verts, indices, b, float3 { bays[0].y, upper_in, CASE_BACK }, float3 { bays[1].x, top_in, upper - SHELF_BACK },
            sides | FACE_FRONT, 1.0, AO_SIDE, seed);
    oak_box(verts, indices, b, float3 { in0, top_in, 0.0 }, float3 { in1, CORNICE_FOOT, upper }, FACE_BOTTOM | FACE_FRONT, 1.0, AO_UNDER,
            seed);
    back(verts, indices, b, in0, in1, upper_in, top_in, seed);
    // The shelf boards, each bay's but under the base's and the upper case's first, and
    // the books on them.
    let shs = shelves(o, door);
    for sh, i in shs {
        let k = i / 2;
        if k != 0 && k != 2 {
            oak_box(verts, indices, b, float3 { sh.s0 - 0.003, sh.y - CASE_BOARD, CASE_BACK },
                    float3 { sh.s1 + 0.003, sh.y, sh.front }, FACE_TOP | FACE_BOTTOM | FACE_FRONT, 1.0, AO_SHELF, seed);
        }
        guard books_on else { continue; }
        var on = sh;
        on.reversed = books::reads_reversed(b);
        var row = books::fill(on, uses);
        books::put(verts, indices, b, on, row);
    }
}

// A bookcase's shelves, two a compartment (its bays), bottom up (metres along the case
// from its side at s 0): folios in the base (quartos and octavos besides), a quarto shelf,
// three octavo shelves, the duodecimos at the top; their books faded most toward the door
// (`door`, its middle along the wall), whose side faces the windows most squarely, and a
// little more up high.
fn shelves(o: Opening, door: f32) -> books::Shelf[14] {
    let w = o.width;
    let mid = 0.5 * w;
    let bays: float2[2] = [float2 { CASE_END, mid - 0.5 * CASE_UPRIGHT }, float2 { mid + 0.5 * CASE_UPRIGHT, w - CASE_END }];
    let door_side = if door > o.mid { w } else { 0.0 };
    let seed = (o.mid * 1000.0) as i64;
    var out: books::Shelf[14] = [default<books::Shelf>(); 14];
    var y = CASE_PLINTH + CASE_BOARD;
    for k in 7 {
        let in_base = k < 2;
        let clear = if in_base { BASE_CLEAR[k] } else { UPPER_CLEAR[k - 2] };
        let depth = if in_base { o.glass.x } else { o.glass.y };
        let first = if in_base { 1 << books::F } else if k == 2 { 1 << books::Q } else if k < 6 { 1 << books::O } else { 1 << books::D };
        let also = if in_base { (1 << books::Q) | (1 << books::O) } else if k == 2 { 1 << books::O } else if k < 6 { 1 << books::D }
                   else { 1 << books::S };
        let high: f32 = if in_base { 0.0 } else { 0.04 };
        for bay, j in bays {
            let near0 = 1.0 - abs(bay.x - door_side) / w;
            let near1 = 1.0 - abs(bay.y - door_side) / w;
            out[2 * k + j] = books::Shelf { bay.x + 0.003, bay.y - 0.003, y, clear, depth - SHELF_BACK, depth - CASE_BACK - SHELF_BACK,
                                            first, also, seed + 17 * k + 5 * j,
                                            float2 { 0.04 + high + 0.3 * near0 * near0, 0.04 + high + 0.3 * near1 * near1 }, false };
        }
        y += clear + CASE_BOARD;
        if k == 1 { y = WAINSCOT_TOP + CASE_BOARD; }
    }
    return out;
}

// A strip of wall too narrow for a panel (between a case and the door's architrave),
// s0..s1 along b (metres): the plinth with its top closed, the paper over it to the cap's
// line.
fn bare_strip(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, s0: f32, s1: f32, seed: i64&) {
    let k = m();
    seed++;
    let first = verts.len;
    sweep(verts, indices, b, BARE_PLINTH[..], 0.0, s0 * k, s1 * k, 0.0, 0.0, surfaces::MAT_OAK, seed);
    for i in first..verts.len {
        let v .= verts[i];
        v.mat = surfaces::MAT_OAK + PLINTH_TONE * (v.mat - floor(v.mat));
    }
    quad_m(verts, indices, b, [float3 { s0, 0.17, 0.0 }, float3 { s1, 0.17, 0.0 }, float3 { s1, WAINSCOT_TOP, 0.0 },
                               float3 { s0, WAINSCOT_TOP, 0.0 }], surfaces::MAT_PAPER);
}
