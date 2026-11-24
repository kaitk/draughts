// The library's corners and edges darkened (rooms::Room.corners), baked once into a map
// when the shell's mesh is made, for ROOM_FRAG's indirect light: the shade depends only on
// the shell's planes and a surface's place and normal, so it is the same every frame. The
// mesh is cut into charts, each a set of triangles sharing a plane and its vertices, laid
// flat into one R8 atlas, and the shade worked out once a texel at the
// nearest point of the chart's triangles, with their normal as the GPU interpolates it;
// ROOM_FRAG reads it with one bilinear tap at the vertex's place in the atlas, held inside
// the chart's texels (a pixel's middle can lie past its triangle's edge). A chart's first
// texel on each axis lies on its edge and its last past it, so a tap inside the chart needs
// no texel round it.
//
// The room's frame (ROOM_VERT's v_local, world units): x along u, y up, z along v.
namespace corner_map;
import std;
import vec;
import math;

// A vertex of the room's mesh: mesh::Vertex, its place in the atlas (0 to 1), and its
// chart's first and last texel (each x + y × WIDTH, whole numbers a float holds exactly).
struct RoomVertex { pos: float3, normal: float3, uv: float2, ao: f32, mat: f32, corner: float2, box: float2 }

fn room_vertex(v: mesh::Vertex, corner: float2, box: float2) -> RoomVertex {
    RoomVertex { v.pos, v.normal, v.uv, v.ao, v.mat, corner, box }
}

// The atlas: WIDTH texels across and as many rows as its charts take, at most MAX_ROWS. A
// texel is TEXEL metres at most, and a chart has ACROSS texels along each side down to
// FINEST a texel, so a narrow face (a door's jamb, a sill's nose) keeps its steep shade;
// larger on a chart over MAX_CHART texels. The first two texels are 1 (nothing hidden), for
// the triangles the shade isn't read on (the brass, the books).
let WIDTH = 4096;
let MAX_ROWS = 2048;
let TEXEL:  f32 = 0.02;
let FINEST: f32 = 0.0025;
let ACROSS: f32 = 16.0;
let MAX_CHART = 262144;
let MAX_CHARTS = 32768;
let MAX_TRIANGLES = 65536;

// The shell's planes and the shade's strength and reach, as ROOM_FRAG's block has them
// (render3d::SurfacesBlock).
struct Planes {
    shell:        float4,
    shell_mids:   float4,
    shell_niche:  float4,
    shell_glass:  float4,
    room_box:     float4,
    room_doors:   float4,
    room_heights: float4,
    book_cases:   float4,
    corners:      float4,
}

// A chart: its plane's axes, where it starts on them (world units), a texel's size on each, and its
// place and size in the atlas (texels).
struct Chart { u: float3, v: float3, low: float2, texel: float2, at: int2, size: int2 }

// Where p falls on a chart, in its texels (the first's middle at 0).
fn texel_at(ch: Chart&, p: float3) -> float2 {
    float2 { (dot(p, ch.u) - ch.low.x) / ch.texel.x, (dot(p, ch.v) - ch.low.y) / ch.texel.y }
}

// What the bake keeps between the mesh's charts and the atlas: fixed, sized at startup,
// touched only when the shell's mesh is made.
var charts:   Chart[MAX_CHARTS];
var chart_of: i32[MAX_TRIANGLES];          // each triangle's chart, -1 none
var atlas:    u8[WIDTH * MAX_ROWS];
var best:     f32[MAX_CHART];
var nearest:  i32[MAX_CHART];
var chart_count = 0;
var rows = 0;

// Whether ROOM_FRAG reads the shade on a material: not the brass (its own reflections) nor
// the books (the cases shade them).
fn shaded(mat: f32) -> bool { mat < 13.5 && !(mat > 11.5 && mat < 12.5) }

// --- The shade (ROOM_FRAG's before 2026-11-21, worked out here once a texel) -----------

// The share of the sky (cosine-weighted) a plane square to a surface hides from a point
// d from it (world units), counting what it meets within `reach`: through the
// hemisphere's projected disc, the segment beyond d / reach; a half on the plane itself.
fn plane_hides(d: f32, reach: f32) -> f32 {
    if d >= reach { return 0.0; }
    let k = clamp(d / reach, 0.0, 1.0);
    return (acos(k) - k * sqrt(1.0 - k * k)) / PI;
}

// A ledge `depth` deep (a cap, a sill, a moulding standing out) hides less the farther
// the point is from it.
fn ledge_hides(d: f32, depth: f32, reach: f32) -> f32 { plane_hides(d, reach) * depth / (depth + max(d, 0.0)) }

fn step_up(a: f32, b: f32, x: f32) -> f32 { smoothstep(a, b, x) }

// A point on a boundary (a chart's edge texel in a corner, against a box's face, on the
// cap's top or under its foot) takes that face's shade: the comparisons give it TOUCH_M
// (metres; TOUCH of the reach, world units) for rounding. Strict, the edge row came out 1
// and the GPU's bilinear tap spread it a texel in, a light line into the corner (2026-11-24).
let TOUCH_M: f32 = 0.0001;
let TOUCH:   f32 = 0.0003;

// How square a plane with normal m stands to a surface with normal n: 1 square, 0 facing.
fn square_to(n: float3, m: float3) -> f32 { 1.0 - step_up(0.3, 0.7, abs(dot(n, m))) }

// atan(s / d) for d > 0, to about 0.005 radians, as the shader had it.
fn angle_of(s: f32, d: f32) -> f32 {
    let x = s / d;
    let u = min(abs(x), 1.0) / max(abs(x), 1.0);
    let a = u * (0.7854 + 0.273 * (1.0 - u));
    return sign(x) * (if abs(x) > 1.0 { 1.5708 - a } else { a });
}

// The share of a face's extent along one of its axes, lo to hi, that a point at q on that
// axis sees from a distance a in front of it, against an endless face: across the
// surface (c, the surface normal's part along the axis, near 0) the angle the span takes
// of the half turn; along the surface's normal only the side the surface faces counts
// (a quarter turn), so a surface at the face's edge still sees all of it. Past the span's
// end it falls off with the angle, so a box's shade wraps softly round its outside
// corners instead of running on as an endless plane's.
fn span_seen(q: f32, lo: f32, hi: f32, a: f32, c: f32) -> f32 {
    let d = max(a, 1e-3);
    let t1 = angle_of(q - lo, d);
    let t2 = angle_of(hi - q, d);
    let across = (t1 + t2) / PI;
    let facing = if c > 0.0 { t2 - angle_of(max(lo - q, 0.0), d) } else { t1 - angle_of(max(q - hi, 0.0), d) };
    let k = step_up(0.3, 0.7, abs(c));
    return across + (max(facing, 0.0) * 2.0 / PI - across) * k;
}

// What a box standing out of a wall hides from q, normal qn, both in the wall's frame
// (x along the wall, y up from the floor, z out of the wall; world units): x its front's
// share, which the caller weighs with the wall's own face (they face the same way, so the
// nearer counts, not both); y how much light its two ends and its top leave, each face a
// plane_hides at its distance by the share of it the point sees (span_seen). A point
// inside the box (a case's open shelves) takes none, and the shade fades out as the
// point's distance to the box nears reach.
fn box_hides(q: float3, qn: float3, lo: float3, hi: float3, s0: f32, reach: f32) -> float2 {
    let out_of = float3 { max(max(lo.x - q.x, q.x - hi.x), 0.0), max(max(lo.y - q.y, q.y - hi.y), 0.0),
                          max(max(lo.z - q.z, q.z - hi.z), 0.0) };
    let far = length(out_of);
    if far > reach { return float2 { 0.0, 1.0 }; }
    let fade = 1.0 - step_up(0.6 * reach, reach, far);
    let s = s0 * fade;
    // Each face only where it hides anything (plane_hides is 0 from reach on).
    var lit: f32 = 1.0;
    var a = lo.x - q.x;
    var square = square_to(qn, float3 { -1.0, 0.0, 0.0 });
    if a > -TOUCH * reach && a < reach && square > 0.0 {
        a = max(a, 0.0);
        lit *= 1.0 - s * square * plane_hides(a, reach) * span_seen(q.y, lo.y, hi.y, a, qn.y) * span_seen(q.z, lo.z, hi.z, a, qn.z);
    }
    a = q.x - hi.x;
    square = square_to(qn, float3 { 1.0, 0.0, 0.0 });
    if a > -TOUCH * reach && a < reach && square > 0.0 {
        a = max(a, 0.0);
        lit *= 1.0 - s * square * plane_hides(a, reach) * span_seen(q.y, lo.y, hi.y, a, qn.y) * span_seen(q.z, lo.z, hi.z, a, qn.z);
    }
    a = q.y - hi.y;
    square = square_to(qn, float3 { 0.0, 1.0, 0.0 });
    if a > -TOUCH * reach && a < reach && square > 0.0 {
        a = max(a, 0.0);
        lit *= 1.0 - s * square * plane_hides(a, reach) * span_seen(q.x, lo.x, hi.x, a, qn.x) * span_seen(q.z, lo.z, hi.z, a, qn.z);
    }
    a = q.z - hi.z;
    let touching = a > -TOUCH * reach && a < reach;
    a = max(a, 0.0);
    let front = if touching { fade * plane_hides(a, reach) * span_seen(q.x, lo.x, hi.x, a, qn.x) * span_seen(q.y, lo.y, hi.y, a, qn.y) } else { 0.0 };
    return float2 { front, lit };
}

// A wall's face standing `proud` out (the skirting, the panelling) with an opening in it,
// half_w either side of x 0 from `low` to `high` (world units, the wall's frame as
// box_hides'), its back `back` behind the face (a door's leaf; below 0 open, a window):
// what the face hides, less the opening's share, or the back, whichever is nearer.
fn holed_wall(q: float3, qn: float3, proud: f32, half_w: f32, low: f32, high: f32, back: f32, reach: f32) -> f32 {
    if q.z - proud >= reach && q.z + back >= reach { return 0.0; }
    let a = max(q.z - proud, 0.0);
    var face: f32 = 0.0;
    if q.z - proud > -TOUCH * reach && a < reach {
        let hole = if half_w > 0.0 { span_seen(q.x, -half_w, half_w, a, qn.x) * span_seen(q.y, low, high, a, qn.y) } else { 0.0 };
        face = plane_hides(a, reach) * (1.0 - hole);
    }
    let ab = max(q.z + back, 0.0);
    var deep: f32 = 0.0;
    if half_w > 0.0 && back >= 0.0 && q.z + back > -TOUCH * reach && ab < reach {
        deep = plane_hides(ab, reach) * span_seen(q.x, -half_w, half_w, ab, qn.x) * span_seen(q.y, low, high, ab, qn.y);
    }
    return max(face, deep);
}

// What stands out of a wall with a door, in its frame (x from the door's middle, folded
// so both sides are one, as the door's trims and the bookcases are symmetric): the
// plinth blocks (2 cm past the architrave, 6.5 cm out, 0.26 m up), the architrave's leg
// over each (5 cm out) and its head, and with `cases` the bookcases' bases and upper
// cases. x of the result the fronts' share, y the rest's light.
fn wall_boxes(c: Planes&, q: float3, qn: float3, half_w: f32, cases: bool, s: f32, reach: f32) -> float2 {
    let m = c.shell.w;
    let arch = c.room_heights.w * m;
    let open_w = half_w - arch;
    let top = c.room_heights.y * m;
    let cap = c.room_heights.z * m;
    let bc = c.book_cases;
    let fq = float3 { abs(q.x), q.y, q.z };
    let fnormal = float3 { if q.x < 0.0 { -qn.x } else { qn.x }, qn.y, qn.z };
    var r = float2 { 0.0, 1.0 };
    let n = if cases { 5 } else { 3 };
    for i in n {
        var lo = float3 { open_w - 0.01 * m, 0.0, 0.0 };
        var hi = float3 { half_w + 0.02 * m, 0.26 * m, 0.065 * m };
        if i == 1 {
            lo = float3 { open_w, 0.26 * m, 0.0 };
            hi = float3 { half_w, top, 0.05 * m };
        } else if i == 2 {
            lo = float3 { 0.0, top - arch, 0.0 };
            hi = float3 { half_w, top, 0.05 * m };
        } else if i == 3 {
            lo = float3 { bc.x - bc.y, 0.0, 0.0 };
            hi = float3 { bc.x + bc.y, cap, 0.45 * m };
        } else if i == 4 {
            lo = float3 { bc.x - bc.y, cap, 0.0 };
            hi = float3 { bc.x + bc.y, bc.z * m, 0.30 * m };
        }
        let b = box_hides(fq, fnormal, lo, hi, s, reach);
        r = float2 { max(r.x, b.x), r.y * b.y };
    }
    return r;
}

// The shell's corners and edges, for its indirect light only: the room is a box of known
// planes, so a point's distance to each plane square to its surface says how much of the
// room's light that plane hides (plane_hides): the floor along the walls, the walls into
// the inside corners, along the floor and under the cornice, the ceiling along the
// cornice; the wall over the wainscot's cap and under it and under the sills; in the
// windows' niches the reveals, the sill, the casements' frames and the head; at the doors
// the jambs, the leaf and the architrave. What stands out of a wall and ends (the
// bookcases, the doors' architraves and plinth blocks, the sills' noses, the piers either
// side of a niche) is a finite box, its faces' shade falling off past their edges
// (box_hides), and an opening is a hole in its wall's face (holed_wall), so no shade runs
// on past an outside corner. lp and ln in the room's frame; what stands out of a wall by
// its height (the plinth 4.5 cm, the panelling 2.5 cm, the cornice 0.46 m on the ceiling,
// a cove, so half as dark). 1 nothing hidden.
fn shade(c: Planes&, lp: float3, ln: float3) -> f32 {
    if c.corners.x <= 0.0 || c.shell.x < 0.5 { return 1.0; }
    let m = c.shell.w;
    let reach = c.corners.y;
    let s = c.corners.x;
    let heights = c.room_heights;
    let doors = c.room_doors;
    let box = c.room_box;
    let niche_at = c.shell_niche;
    let bc = c.book_cases;
    let up = (lp.y - c.shell.z) / m;
    let cornice = (heights.x - c.shell.z) / m - 0.26;
    let proud = (if up < 0.19 { 0.045 } else if up < heights.z { 0.025 } else if up < cornice { 0.0 } else { 0.46 }) * m;
    var cove: f32 = if up < cornice { 1.0 } else { 0.5 };
    // The four walls' faces from p, into the room.
    let d_far = lp.x - box.x;
    let d_stove = box.y - lp.x;
    let d_window = lp.z - box.z;
    let d_hall = box.w - lp.z;
    var lit: f32 = 1.0;
    // The hall door, the salon's, their openings' half widths and height (metres).
    let arch = heights.w * m;
    let door_top = heights.y - heights.w;
    let hx = lp.x - doors.x;
    let sz = lp.z - doors.z;
    let hall_door = doors.y > 0.0 && abs(hx) < doors.y - arch && up < door_top;
    let salon_door = doors.w > 0.0 && abs(sz) < doors.w - arch && up < door_top;
    // A door with its architrave, which stops the wainscot.
    let hall_trim = doors.y > 0.0 && abs(hx) < doors.y + 0.01 * m && up < heights.y;
    let salon_trim = doors.w > 0.0 && abs(sz) < doors.w + 0.01 * m && up < heights.y;
    // The bookcases either side of the hall door: p's place across the nearer.
    let cx = abs(hx) - bc.x;
    let cases = bc.y > 0.0 && up < bc.z;
    let before_case = cases && abs(cx) < bc.y;
    // The window's niche p is in or before.
    var wx: f32 = 1e6;
    let mids: f32[3] = [c.shell_mids.x, c.shell_mids.y, c.shell_mids.z];
    for i in 3 {
        if (i as f32) >= c.shell.x { break; }
        let x = lp.x - mids[i];
        if abs(x) < abs(wx) { wx = x; }
    }
    let half_w = niche_at.x * m;
    let spring = niche_at.y + niche_at.z;
    let niche = abs(wx) < half_w && up > niche_at.y - 0.01 && up < spring + niche_at.w;
    let in_niche = niche && d_window < 0.01 * m;
    let floor_up = lp.y - c.shell.z;
    // The hall wall and the stove's end in their own frames (x along from the door's
    // middle, y up, z out): the face with the door's opening as a hole to its leaf; the
    // architrave, its plinth blocks and the bookcases as boxes, their fronts against the
    // face by the nearer, their ends and tops into lit.
    let hq = float3 { hx, floor_up, d_hall };
    let hn = float3 { ln.x, ln.y, -ln.z };
    var hall_hides = holed_wall(hq, hn, proud, doors.y - arch, 0.0, door_top * m, 0.015 * m, reach);
    let cases_near = bc.y > 0.0 && d_hall < 0.45 * m + reach;
    if doors.y > 0.0 && (cases_near || (abs(hx) < doors.y + reach && d_hall < reach + 0.07 * m)) {
        let b = wall_boxes(c, hq, hn, doors.y, cases_near, s, reach);
        hall_hides = max(hall_hides, b.x);
        lit *= b.y;
    }
    let sq = float3 { sz, floor_up, d_stove };
    let sn = float3 { ln.z, ln.y, -ln.x };
    var stove_hides = holed_wall(sq, sn, proud, doors.w - arch, 0.0, door_top * m, 0.015 * m, reach);
    if doors.w > 0.0 && abs(sz) < doors.w + reach && d_stove < reach + 0.07 * m {
        let b = wall_boxes(c, sq, sn, doors.w, false, s, reach);
        stove_hides = max(stove_hides, b.x);
        lit *= b.y;
    }
    // The window wall: the nearest niche a hole in its face, open to the sky.
    let window_hides = holed_wall(float3 { wx, floor_up, d_window }, ln, proud, half_w, niche_at.y * m,
                                  (spring + niche_at.w) * m, -1.0, reach);
    // The cornice keeps its own shade (its profile's, per vertex): its cove stands out of
    // the wall by its height, which no plane here follows. The ceiling past it takes the
    // walls' shade from nothing at the cornice's edge, so no line shows there.
    if up > cornice {
        let past = min(min(d_far, d_stove), min(d_window, d_hall)) - 0.46 * m;
        cove = if ln.y < -0.7 { 0.5 * step_up(0.0, 0.12 * m, past) } else { 0.0 };
    }
    if !in_niche && cove > 0.0 {
        lit *= 1.0 - s * cove * square_to(ln, float3 { 0.0, 0.0, 1.0 }) * window_hides;
        lit *= 1.0 - s * cove * square_to(ln, float3 { 0.0, 0.0, -1.0 }) * hall_hides;
        lit *= 1.0 - s * cove * square_to(ln, float3 { 1.0, 0.0, 0.0 }) * plane_hides(d_far - proud, reach);
        lit *= 1.0 - s * cove * square_to(ln, float3 { -1.0, 0.0, 0.0 }) * stove_hides;
    }
    // The floor, and the cornice's foot over a wall, a cove.
    let upright = square_to(ln, float3 { 0.0, 1.0, 0.0 });
    lit *= 1.0 - s * upright * plane_hides(up * m, reach);
    if up < cornice { lit *= 1.0 - 0.5 * s * upright * plane_hides((cornice - up) * m, reach); }
    // On a wall: over the wainscot's cap and under it (its underside at 1.105 m, 6.5 cm
    // out of the panelling), under a window's sill (its nose 8 cm out of the wall and
    // 5 cm past the niche each side, its underside at the sill less 5 cm, a box).
    let on_wall = min(min(d_far, d_stove), min(d_window, d_hall));
    if on_wall < 0.12 * m && !in_niche {
        let cap = heights.z;
        let under_sill = d_window < 0.12 * m && abs(wx) < half_w + 0.05 * m;
        if d_window < 0.12 * m && up < niche_at.y - 0.05 {
            let a = (niche_at.y - 0.05 - up) * m;
            lit *= 1.0 - s * upright * plane_hides(a, reach) * span_seen(wx, -half_w - 0.05 * m, half_w + 0.05 * m, a, ln.x)
                       * span_seen(d_window, 0.0, 0.08 * m, a, ln.z);
        }
        if !under_sill && !(hall_trim && d_hall < 0.12 * m) && !(salon_trim && d_stove < 0.12 * m)
           && !(before_case && d_hall < 0.12 * m) {
            if up > cap - TOUCH_M { lit *= 1.0 - s * upright * ledge_hides((up - cap) * m, 0.09 * m, reach); }
            else if up < cap - 0.095 + TOUCH_M { lit *= 1.0 - s * upright * ledge_hides((cap - 0.095 - up) * m, 0.065 * m, reach); }
        }
    }
    // In a window's niche: its reveals (the piers' sides, from the wall's face to the
    // glass, so their shade ends at the niche's mouth), the sill, the inner casement's
    // frame (6 cm), the head.
    if in_niche {
        let into = -d_window;
        let rev = half_w - abs(wx);
        lit *= 1.0 - s * square_to(ln, float3 { 1.0, 0.0, 0.0 }) * plane_hides(rev, reach)
                   * span_seen(into, 0.0, c.shell_glass.x, rev, -ln.z)
                   * span_seen(up * m, niche_at.y * m, (spring + niche_at.w) * m, rev, ln.y);
        lit *= 1.0 - s * upright * plane_hides((up - niche_at.y) * m, reach);
        lit *= 1.0 - s * square_to(ln, float3 { 0.0, 0.0, 1.0 }) * ledge_hides(c.shell_glass.x - into, 0.06 * m, reach);
        lit *= 1.0 - s * upright * plane_hides((spring - up) * m, reach) * (if spring < up { 0.0 } else { 1.0 });
    }
    // At a door: in its opening, the jambs and head round the leaf (its face 1.5 cm
    // deep), the leaf behind a jamb.
    if hall_door && d_hall < 0.01 * m {
        lit *= 1.0 - s * square_to(ln, float3 { 1.0, 0.0, 0.0 }) * ledge_hides(doors.y - arch - abs(hx), 0.015 * m, reach);
        lit *= 1.0 - s * upright * ledge_hides((door_top - up) * m, 0.015 * m, reach);
        lit *= 1.0 - s * square_to(ln, float3 { 0.0, 0.0, 1.0 }) * plane_hides(0.015 * m + d_hall, reach);
    }
    if salon_door && d_stove < 0.01 * m {
        lit *= 1.0 - s * square_to(ln, float3 { 0.0, 0.0, 1.0 }) * ledge_hides(doors.w - arch - abs(sz), 0.015 * m, reach);
        lit *= 1.0 - s * upright * ledge_hides((door_top - up) * m, 0.015 * m, reach);
        lit *= 1.0 - s * square_to(ln, float3 { 1.0, 0.0, 0.0 }) * plane_hides(0.015 * m + d_stove, reach);
    }
    return lit;
}

// --- The charts and the atlas ----------------------------------------------------------

fn find(parent: i32[>..]&, i: i32) -> i32 {
    var r = i;
    while parent[r as i64] != r { r = parent[r as i64]; }
    var k = i;
    while parent[k as i64] != r {
        let next = parent[k as i64];
        parent[k as i64] = r;
        k = next;
    }
    return r;
}

// A plane's two axes, square to each other and to n.
fn plane_axes(n: float3) -> float3, float3 {
    let ax = abs(n.x);
    let ay = abs(n.y);
    let az = abs(n.z);
    let a = if ax <= ay && ax <= az { float3 { 1.0, 0.0, 0.0 } } else if ay <= az { float3 { 0.0, 1.0, 0.0 } } else { float3 { 0.0, 0.0, 1.0 } };
    let u = normalize(cross(n, a));
    return u, cross(n, u);
}

struct Shelf { h: i32, w: i32, chart: i32 }

// The room's mesh with each vertex's place in the atlas, its vertices copied where charts
// meet; the charts laid out in the atlas (charts, chart_count, rows). `metre` world units a
// metre. Triangles keep their order. Once, when the shell's mesh is made.
fn lay_out(verts: mesh::Vertex[>..]&, indices: u32[>..]&, metre: f32, out: RoomVertex[>..]&, out_indices: u32[>..]&) {
    let nt = indices.len / 3;
    assert(nt <= MAX_TRIANGLES);
    // Each triangle's plane, and the triangles that meet at a vertex and share it, joined.
    var normal: float3[>..] = [];
    var offset: f32[>..]    = [];
    var parent: i32[>..]    = [];
    for t in nt {
        let a = verts[indices[3 * t] as i64].pos;
        let b = verts[indices[3 * t + 1] as i64].pos;
        let c = verts[indices[3 * t + 2] as i64].pos;
        let n = cross(b - a, c - a);
        let len = length(n);
        let ok = len > 1e-9 && shaded(verts[indices[3 * t] as i64].mat);
        let nn = if len > 1e-9 { n / len } else { float3 { 0.0, 1.0, 0.0 } };
        normal.push(nn);
        offset.push(dot(nn, a));
        parent.push(if ok { t as i32 } else { -1 });
    }
    // The triangles at each vertex, by a count and a fill.
    let nv = verts.len;
    var first: i32[>..] = [];
    for i in nv + 1 { first.push(0); }
    for k in indices.len { first[indices[k] as i64 + 1] += 1; }
    for i in nv { first[i + 1] += first[i]; }
    var fill: i32[>..] = [];
    for i in nv { fill.push(first[i]); }
    var at_vertex: i32[>..] = [];
    for k in indices.len { at_vertex.push(0); }
    for k in indices.len {
        let v = indices[k] as i64;
        at_vertex[fill[v] as i64] = (k / 3) as i32;
        fill[v] += 1;
    }
    let same_plane = 0.001 * metre;
    for v in nv {
        for i in (first[v] as i64)..(first[v + 1] as i64) {
            let a = at_vertex[i];
            guard parent[a as i64] >= 0 else { continue; }
            for j in i + 1..(first[v + 1] as i64) {
                let b = at_vertex[j];
                guard parent[b as i64] >= 0 && a != b else { continue; }
                guard dot(normal[a as i64], normal[b as i64]) > 0.99999 && abs(offset[a as i64] - offset[b as i64]) < same_plane else { continue; }
                let ra = find(parent, a);
                let rb = find(parent, b);
                if ra != rb { parent[rb as i64] = ra; }
            }
        }
    }
    // A chart a root: its axes and its extent on them.
    chart_count = 0;
    var root_chart: i32[>..] = [];
    for t in nt { root_chart.push(-1); }
    var high: float2[>..] = [];
    for t in nt {
        chart_of[t] = -1;
        guard parent[t] >= 0 else { continue; }
        let r = find(parent, t as i32) as i64;
        if root_chart[r] < 0 {
            assert(chart_count < MAX_CHARTS);
            root_chart[r] = chart_count as i32;
            let u, w = plane_axes(normal[r]);
            charts[chart_count] = Chart { u, w, float2 { 1e30, 1e30 }, float2_0, int2 { 0, 0 }, int2 { 0, 0 } };
            high.push(float2 { -1e30, -1e30 });
            chart_count++;
        }
        let k = root_chart[r] as i64;
        chart_of[t] = k as i32;
        let ch .= charts[k];
        for j in 3 {
            let p = verts[indices[3 * t + j] as i64].pos;
            let q = float2 { dot(p, ch.u), dot(p, ch.v) };
            ch.low = float2 { min(ch.low.x, q.x), min(ch.low.y, q.y) };
            high[k] = float2 { max(high[k].x, q.x), max(high[k].y, q.y) };
        }
    }
    // Each chart's size: a texel on its low edge and one past its high one.
    var shelves: Shelf[>..] = [];
    for k in chart_count {
        let ch .= charts[k];
        let span = high[k] - ch.low;
        ch.texel = float2 { clamp(span.x / ACROSS, FINEST * metre, TEXEL * metre), clamp(span.y / ACROSS, FINEST * metre, TEXEL * metre) };
        var nx = ceil(span.x / ch.texel.x) as i64 + 1;
        var ny = ceil(span.y / ch.texel.y) as i64 + 1;
        while nx * ny > MAX_CHART {
            ch.texel = ch.texel * 1.25;
            nx = ceil(span.x / ch.texel.x) as i64 + 1;
            ny = ceil(span.y / ch.texel.y) as i64 + 1;
        }
        ch.size = int2 { nx as i32, ny as i32 };
        shelves.push(Shelf { ch.size.y, ch.size.x, k as i32 });
    }
    // Laid in rows, the tallest first; the two 1s first in the first row.
    sort(shelves) { a, b => a.h > b.h || (a.h == b.h && a.w > b.w) };
    var x = 2;
    var y = 0;
    var row_h = 1;
    for s in shelves {
        if x + s.w > WIDTH {
            y += row_h;
            x = 0;
            row_h = 0;
        }
        charts[s.chart as i64].at = int2 { x as i32, y as i32 };
        x += s.w as i64;
        row_h = max(row_h, s.h as i64);
    }
    rows = y + row_h;
    assert(rows <= MAX_ROWS);
    // The vertices, copied once for each chart they are in.
    var head:      i32[>..] = [];
    var node_next: i32[>..] = [];
    var node_key:  i32[>..] = [];
    var node_at:   i32[>..] = [];
    for v in nv { head.push(-1); }
    let white = float2 { 1.0 / (WIDTH as f32), 0.5 / (rows as f32) };
    for t in nt {
        let k = chart_of[t];
        for j in 3 {
            let v = indices[3 * t + j] as i64;
            var n = head[v];
            while n >= 0 && node_key[n as i64] != k { n = node_next[n as i64]; }
            if n < 0 {
                n = node_key.len as i32;
                node_key.push(k);
                node_at.push(out.len as i32);
                node_next.push(head[v]);
                head[v] = n;
                var place = white;
                var box = float2 { 0.0, 1.0 };
                if k >= 0 {
                    let ch = charts[k as i64];
                    let f = texel_at(ch, verts[v].pos);
                    place = float2 { ((ch.at.x as f32) + f.x + 0.5) / (WIDTH as f32), ((ch.at.y as f32) + f.y + 0.5) / (rows as f32) };
                    let last = ch.at + ch.size - int2 { 1, 1 };
                    box = float2 { (ch.at.x as f32) + (ch.at.y as f32) * (WIDTH as f32), (last.x as f32) + (last.y as f32) * (WIDTH as f32) };
                }
                out.push(room_vertex(verts[v], place, box));
            }
            out_indices.push(node_at[n as i64] as u32);
        }
    }
}

// The nearest point of the triangle a, b, c to p (all on the plane), as its weights.
fn nearest_weights(p: float2, a: float2, b: float2, c: float2) -> float3 {
    let ab = b - a;
    let ac = c - a;
    let ap = p - a;
    let d1 = dot(ab, ap);
    let d2 = dot(ac, ap);
    if d1 <= 0.0 && d2 <= 0.0 { return float3 { 1.0, 0.0, 0.0 }; }
    let bp = p - b;
    let d3 = dot(ab, bp);
    let d4 = dot(ac, bp);
    if d3 >= 0.0 && d4 <= d3 { return float3 { 0.0, 1.0, 0.0 }; }
    let vc = d1 * d4 - d3 * d2;
    if vc <= 0.0 && d1 >= 0.0 && d3 <= 0.0 {
        let w = d1 / (d1 - d3);
        return float3 { 1.0 - w, w, 0.0 };
    }
    let cp = p - c;
    let d5 = dot(ab, cp);
    let d6 = dot(ac, cp);
    if d6 >= 0.0 && d5 <= d6 { return float3 { 0.0, 0.0, 1.0 }; }
    let vb = d5 * d2 - d1 * d6;
    if vb <= 0.0 && d2 >= 0.0 && d6 <= 0.0 {
        let w = d2 / (d2 - d6);
        return float3 { 1.0 - w, 0.0, w };
    }
    let va = d3 * d6 - d5 * d4;
    if va <= 0.0 && (d4 - d3) >= 0.0 && (d5 - d6) >= 0.0 {
        let w = (d4 - d3) / ((d4 - d3) + (d5 - d6));
        return float3 { 0.0, 1.0 - w, w };
    }
    let den = 1.0 / (va + vb + vc);
    let v = vb * den;
    let w = vc * den;
    return float3 { 1.0 - v - w, v, w };
}

// The shade baked into the atlas (atlas, WIDTH × rows) for the charts lay_out made of the
// same mesh: each texel the shade at the nearest point of its chart's triangles, the
// texels no tap reaches 1.
fn bake(c: Planes&, verts: mesh::Vertex[>..]&, indices: u32[>..]&) {
    for i in WIDTH * rows { atlas[i] = 255; }
    let nt = indices.len / 3;
    // The triangles of each chart, by a count and a fill.
    var first: i32[>..] = [];
    for k in chart_count + 1 { first.push(0); }
    for t in nt { if chart_of[t] >= 0 { first[chart_of[t] as i64 + 1] += 1; } }
    for k in chart_count { first[k + 1] += first[k]; }
    var fill: i32[>..] = [];
    for k in chart_count { fill.push(first[k]); }
    var tris: i32[>..] = [];
    for t in nt { tris.push(0); }
    for t in nt {
        let k = chart_of[t];
        guard k >= 0 else { continue; }
        tris[fill[k as i64] as i64] = t as i32;
        fill[k as i64] += 1;
    }
    for k in chart_count {
        let ch = charts[k];
        let w = ch.size.x as i64;
        let h = ch.size.y as i64;
        for i in w * h {
            best[i] = 1e30;
            nearest[i] = -1;
        }
        // Each texel's nearest triangle among those within a texel of it.
        for i in (first[k] as i64)..(first[k + 1] as i64) {
            let t = tris[i] as i64;
            var q: float2[3] = [float2_0; 3];
            for j in 3 {
                let p = verts[indices[3 * t + j] as i64].pos;
                q[j] = texel_at(ch, p);
            }
            let x0 = max(ceil(min(q[0].x, min(q[1].x, q[2].x)) - 1.0) as i64, 0);
            let x1 = min(floor(max(q[0].x, max(q[1].x, q[2].x)) + 1.0) as i64, w - 1);
            let y0 = max(ceil(min(q[0].y, min(q[1].y, q[2].y)) - 1.0) as i64, 0);
            let y1 = min(floor(max(q[0].y, max(q[1].y, q[2].y)) + 1.0) as i64, h - 1);
            for y in y0..y1 + 1 {
                for x in x0..x1 + 1 {
                    let p = float2 { x as f32, y as f32 };
                    let b = nearest_weights(p, q[0], q[1], q[2]);
                    let d = p - (q[0] * b.x + q[1] * b.y + q[2] * b.z);
                    let dd = dot(d, d);
                    let at = y * w + x;
                    if dd < best[at] {
                        best[at] = dd;
                        nearest[at] = t as i32;
                    }
                }
            }
        }
        // The shade at that point, with the normal the GPU interpolates there.
        for y in h {
            for x in w {
                let t = nearest[y * w + x] as i64;
                guard t >= 0 else { continue; }
                let va = verts[indices[3 * t] as i64];
                let vb = verts[indices[3 * t + 1] as i64];
                let vc = verts[indices[3 * t + 2] as i64];
                let qa = texel_at(ch, va.pos);
                let qb = texel_at(ch, vb.pos);
                let qc = texel_at(ch, vc.pos);
                let b = nearest_weights(float2 { x as f32, y as f32 }, qa, qb, qc);
                let p = va.pos * b.x + vb.pos * b.y + vc.pos * b.z;
                let n = normalize(va.normal * b.x + vb.normal * b.y + vc.normal * b.z);
                let v = shade(c, p, n);
                atlas[(ch.at.y as i64 + y) * WIDTH + ch.at.x as i64 + x] = (clamp(v, 0.0, 1.0) * 255.0 + 0.5) as u8;
            }
        }
        fill_gaps(ch, w, h);
    }
}

// A chart's texels no triangle lies within a texel of (where its outline leaves its box
// short), each its neighbour's, so a pixel's middle past a triangle's edge, held inside the
// box, reads the nearest edge's shade.
fn fill_gaps(ch: Chart&, w: i64, h: i64) {
    let x0 = ch.at.x as i64;
    let y0 = ch.at.y as i64;
    var open = false;
    for i in w * h { if nearest[i] < 0 { open = true; } }
    while open {
        open = false;
        for y in h {
            for x in w {
                guard nearest[y * w + x] < 0 else { continue; }
                var from = -1;
                if x > 0 && nearest[y * w + x - 1] >= 0 { from = y * w + x - 1; }
                else if y > 0 && nearest[(y - 1) * w + x] >= 0 { from = (y - 1) * w + x; }
                if from < 0 {
                    open = true;
                    continue;
                }
                nearest[y * w + x] = nearest[from];
                atlas[(y0 + y) * WIDTH + x0 + x] = atlas[(y0 + from / w) * WIDTH + x0 + from % w];
            }
        }
        for k in w * h {
            let y = h - 1 - k / w;
            let x = w - 1 - k % w;
            guard nearest[y * w + x] < 0 else { continue; }
            var from = -1;
            if x < w - 1 && nearest[y * w + x + 1] >= 0 { from = y * w + x + 1; }
            else if y < h - 1 && nearest[(y + 1) * w + x] >= 0 { from = (y + 1) * w + x; }
            guard from >= 0 else { continue; }
            nearest[y * w + x] = nearest[from];
            atlas[(y0 + y) * WIDTH + x0 + x] = atlas[(y0 + from / w) * WIDTH + x0 + from % w];
        }
    }
}
