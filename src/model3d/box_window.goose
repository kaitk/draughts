// The box window of task 127 (build/notes/window-reference/'s specification, fitted to the
// library's opening; the look kept as plain as a restored manor's new windows): at each of
// the two glass planes a casement of a frame (jambs, head, foot, transom, the upper lights'
// mullion), two fixed upper lights of 3 × 3 panes, two lower leaves of one bar each meeting
// under the left one's lip, all in one description that the mesh, the light's members
// (casement_members) and the shaders' casement read. In the window's own metres, as
// shell_mesh's builders take them: x along the wall from the window's middle (+x on the
// left seen from the room), y up from the floor, z out of the wall (into it negative).
// box_window_on picks it over window B's casement (the light tuner's --box-window).
namespace room_shell;
import std;
import vec;
import math;

var box_window_on = false;

// The measures (metres). The frame's face stays where window B's was, 5 cm before the
// glass plane (the sill's dust and the corners' shade are drawn to it); the leaves and the
// upper lights 15 mm behind it in its rebate; the glass 22 mm behind their face.
let BOX_FRAME_FACE: f32 = 0.05;
let BOX_FRAME_DEEP: f32 = 0.08;
let BOX_REBATE:     f32 = 0.015;
let BOX_GLASS_IN:   f32 = 0.022;
let BOX_SASH_DEEP:  f32 = 0.045;
let BOX_BAR_DEEP:   f32 = 0.04;
let BOX_WEB:        f32 = 0.008;
// The frame's foot over the sill (from 3 cm under it), its head, the transom two thirds
// up, the upper lights' mullion.
let BOX_FOOT_UNDER: f32 = 0.03;
let BOX_FOOT:       f32 = 0.04;
let BOX_HEAD:       f32 = 0.07;
let BOX_TRANSOM:    f32 = 0.09;
let BOX_MULLION:    f32 = 0.06;
// The leaves' stiles and rails, the upper lights' surround, the bars.
let BOX_STILE:     f32 = 0.06;
let BOX_RAIL_TOP:  f32 = 0.06;
let BOX_RAIL_LOW:  f32 = 0.085;
let BOX_SURROUND:  f32 = 0.04;
let BOX_BAR_UPPER: f32 = 0.024;
let BOX_BAR_LOWER: f32 = 0.032;
// The rounded step from a member's face down to the glass round every pane (its radius).
let BOX_STEP: f32 = 0.006;
// The active (left) leaf's lip over the meeting: how far it reaches over the other leaf,
// its width on its own leaf, its thickness.
let BOX_LIP_OVER: f32 = 0.013;
let BOX_LIP_ON:   f32 = 0.045;
let BOX_LIP_DEEP: f32 = 0.008;

// What a member is, for the mesh: the frame's, a light's edge, a bar, the lip, the
// lunette over the casements (the wall's, for the light only).
let PART_FRAME = 0;
let PART_EDGE = 1;
let PART_BAR = 2;
let PART_LIP = 3;
let PART_WALL = 4;

// How far past its glass plane (o.glass.x, .y) a casement's glass lies, metres into the
// wall: the box window's before it, in its leaves; window B's 18 mm behind it.
fn pane_in() -> f32 { if box_window_on { -(BOX_FRAME_FACE - BOX_REBATE - BOX_GLASS_IN) } else { 0.018 } }

// A light: where it meets the frame, the mullion or the other leaf (x0, y0, x1, y1), its
// members' widths round it (x0's side, x1's, the foot, the head), its panes across and up
// between bars `bar` wide, and its leaf (-1 fixed; the leaves hinge on their outer edge).
struct BoxLight {
    box:    float4,
    edges:  float4,
    across: i64,
    up:     i64,
    bar:    f32,
    leaf:   i64,
}

// One casement at the glass plane `g` metres into the wall: the jambs' inner edge (x) and
// the niche's half width, the foot's, head's and transom's heights (y0, y1), the mullion's
// half width, the faces' depths (z: the frame's face and back, the leaves' face and back,
// the glass), its four lights (the left leaf, the right, the upper left, the upper right).
struct BoxCasement {
    g:       f32,
    jamb:    float2,
    foot:    float2,
    head:    float2,
    transom: float2,
    mullion: f32,
    frame_z: float2,
    sash_z:  float2,
    glass_z: f32,
    lights:  BoxLight[4],
}

fn box_casement(o: Opening, g: f32) -> BoxCasement {
    let gx = 0.5 * o.glass.w - CASE_FRAME;
    let s = o.sill;
    let h = o.sill + o.height;
    let zt = s + (h - s) * 2.0 / 3.0;
    let foot = float2 { s - BOX_FOOT_UNDER, s + BOX_FOOT };
    let head = float2 { h - BOX_HEAD, h };
    let transom = float2 { zt - 0.5 * BOX_TRANSOM, zt + 0.5 * BOX_TRANSOM };
    let mh = 0.5 * BOX_MULLION;
    let face = -(g - BOX_FRAME_FACE);
    let sash = face - BOX_REBATE;
    let low = float4 { BOX_STILE, BOX_STILE, BOX_RAIL_LOW, BOX_RAIL_TOP };
    let up = float4 { BOX_SURROUND, BOX_SURROUND, BOX_SURROUND, BOX_SURROUND };
    return BoxCasement {
        g, float2 { gx, 0.5 * o.width }, foot, head, transom, mh, float2 { face, face - BOX_FRAME_DEEP },
        float2 { sash, sash - BOX_SASH_DEEP }, sash - BOX_GLASS_IN,
        [BoxLight { float4 { 0.0, foot.y, gx, transom.x }, low, 1, 2, BOX_BAR_LOWER, 0 },
         BoxLight { float4 { -gx, foot.y, 0.0, transom.x }, low, 1, 2, BOX_BAR_LOWER, 1 },
         BoxLight { float4 { mh, transom.y, gx, head.x }, up, 3, 3, BOX_BAR_UPPER, -1 },
         BoxLight { float4 { -gx, transom.y, -mh, head.x }, up, 3, 3, BOX_BAR_UPPER, -1 }],
    };
}

// A light's glazed area inside its members (x0, y0, x1, y1), and a pane's size.
fn glazed_of(l: BoxLight) -> float4 {
    return float4 { l.box.x + l.edges.x, l.box.y + l.edges.z, l.box.z - l.edges.y, l.box.w - l.edges.w };
}
fn pane_size(l: BoxLight) -> float2 {
    let a = glazed_of(l);
    return float2 { (a.z - a.x - (l.across - 1) * l.bar) / l.across, (a.w - a.y - (l.up - 1) * l.bar) / l.up };
}
// Pane (i, j)'s glass (x0, y0, x1, y1), and its cell: out to the light's edge or a bar's middle.
fn pane_of(l: BoxLight, i: i64, j: i64) -> float4 {
    let a = glazed_of(l);
    let p = pane_size(l);
    let x0 = a.x + i * (p.x + l.bar);
    let y0 = a.y + j * (p.y + l.bar);
    return float4 { x0, y0, x0 + p.x, y0 + p.y };
}
fn cell_of(l: BoxLight, i: i64, j: i64) -> float4 {
    let p = pane_of(l, i, j);
    let hb = 0.5 * l.bar;
    return float4 { if i == 0 { l.box.x } else { p.x - hb }, if j == 0 { l.box.y } else { p.y - hb },
                    if i == l.across - 1 { l.box.z } else { p.z + hb }, if j == l.up - 1 { l.box.w } else { p.w + hb } };
}

// A box of a window's casements, in the window's own metres: x along the wall from its
// middle, y up from the floor, z out of the wall (into it negative), as box_m takes them;
// its part and its light (-1 the frame's).
struct Member { lo: float3, hi: float3, part: i64 = PART_FRAME, light: i64 = -1 }
let MEMBERS = 96;

fn member(lo: float3, hi: float3, part: i64, light: i64) -> Member { Member { lo, hi, part, light } }

// The boxes of casement c that stop the sun: the frame's, each light's edges and bars (the
// bars as their face to the glass and their web behind it), the lip.
fn box_members(c: BoxCasement, out: Member[..MEMBERS]&) {
    let f = c.frame_z;
    let w = c.jamb.y;
    out.push(member(float3 { -w, c.foot.x, f.y }, float3 { -c.jamb.x, c.head.y, f.x }, PART_FRAME, -1));
    out.push(member(float3 { c.jamb.x, c.foot.x, f.y }, float3 { w, c.head.y, f.x }, PART_FRAME, -1));
    out.push(member(float3 { -c.jamb.x, c.head.x, f.y }, float3 { c.jamb.x, c.head.y, f.x }, PART_FRAME, -1));
    out.push(member(float3 { -c.jamb.x, c.foot.x, f.y }, float3 { c.jamb.x, c.foot.y, f.x }, PART_FRAME, -1));
    out.push(member(float3 { -c.jamb.x, c.transom.x, f.y }, float3 { c.jamb.x, c.transom.y, f.x }, PART_FRAME, -1));
    out.push(member(float3 { -c.mullion, c.transom.y, f.y }, float3 { c.mullion, c.head.x, f.x }, PART_FRAME, -1));
    let z0 = c.sash_z.y;
    let z1 = c.sash_z.x;
    let zb = z1 - BOX_BAR_DEEP;
    for l, k in c.lights {
        let a = glazed_of(l);
        out.push(member(float3 { l.box.x, l.box.y, z0 }, float3 { a.x, l.box.w, z1 }, PART_EDGE, k));
        out.push(member(float3 { a.z, l.box.y, z0 }, float3 { l.box.z, l.box.w, z1 }, PART_EDGE, k));
        out.push(member(float3 { a.x, l.box.y, z0 }, float3 { a.z, a.y, z1 }, PART_EDGE, k));
        out.push(member(float3 { a.x, a.w, z0 }, float3 { a.z, l.box.w, z1 }, PART_EDGE, k));
        let p = pane_size(l);
        let hw = 0.5 * BOX_WEB;
        for i in 1..l.across {
            let x = a.x + i * (p.x + l.bar) - 0.5 * l.bar;
            out.push(member(float3 { x - 0.5 * l.bar, a.y, c.glass_z }, float3 { x + 0.5 * l.bar, a.w, z1 }, PART_BAR, k));
            out.push(member(float3 { x - hw, a.y, zb }, float3 { x + hw, a.w, c.glass_z }, PART_BAR, k));
        }
        for j in 1..l.up {
            let y = a.y + j * (p.y + l.bar) - 0.5 * l.bar;
            out.push(member(float3 { a.x, y - 0.5 * l.bar, c.glass_z }, float3 { a.z, y + 0.5 * l.bar, z1 }, PART_BAR, k));
            out.push(member(float3 { a.x, y - hw, zb }, float3 { a.z, y + hw, c.glass_z }, PART_BAR, k));
        }
    }
    let lo = c.lights[0];
    out.push(member(float3 { -BOX_LIP_OVER, lo.box.y, z1 }, float3 { BOX_LIP_ON, lo.box.w, z1 + BOX_LIP_DEEP }, PART_LIP, 0));
}

// A leaf's hinges' axis (x, z) and their middles' heights: two long barrels on its outer
// edge, at the frame's corner before the leaf's face (the axis an open sash would turn on).
let BOX_HINGE_R:    f32 = 0.0055;
let BOX_HINGE_HALF: f32 = 0.055;
let BOX_HINGE_IN:   f32 = 0.16;
fn hinge_axis(c: BoxCasement, l: BoxLight) -> float2 {
    let x = if l.leaf == 0 { l.box.z - BOX_HINGE_R } else { l.box.x + BOX_HINGE_R };
    return float2 { x, c.sash_z.x + BOX_HINGE_R };
}
fn hinge_heights(l: BoxLight) -> float2 { float2 { l.box.y + BOX_HINGE_IN, l.box.w - BOX_HINGE_IN } }

// The crémone on the active leaf's lip: its rod's middle along x, the housing's middle's
// height (at the leaf's bar, as the restored windows have it).
fn cremone_x() -> f32 { 0.5 * (BOX_LIP_ON - BOX_LIP_OVER) }
fn cremone_y(c: BoxCasement) -> f32 {
    let l = c.lights[0];
    let a = glazed_of(l);
    return 0.5 * (a.y + a.w);
}

// The ring of pane `pane` in its cell (x0, y0, x1, y1, metres in b's frame), each of its
// four sides (left, right, foot, head) a band from the cell's edge to the glass and on
// past it: the member's flat face at z `face`, a rounded step BOX_STEP down to the pane's
// edge, its side to the glass, and behind the glass the member's back to `backs` (a bar's
// web on a side that is a bar). The corners mitred, the step's normals the circle's.
let RING_POINTS = 8;
fn pane_ring(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, cell: float4, pane: float4, bar_sides: bool[4],
             face: f32, back: float2, tone: f32) {
    let r = BOX_STEP;
    let past = BOX_GLASS_IN + 0.0005;
    let margins: f32[4]    = [pane.x - cell.x, cell.z - pane.z, pane.y - cell.y, cell.w - pane.w];
    let outs:    float2[4] = [float2 { -1.0, 0.0 }, float2 { 1.0, 0.0 }, float2 { 0.0, -1.0 }, float2 { 0.0, 1.0 }];
    // Each point's inset out from the pane's edge and depth behind the face, by side; the
    // step's angle (0 facing the room, a quarter turn facing the pane).
    var inset: f32[RING_POINTS][4] = [[0.0; RING_POINTS]; 4];
    var depth: f32[RING_POINTS][4] = [[0.0; RING_POINTS]; 4];
    let turn: f32[RING_POINTS] = [0.0, 0.0, PI / 6.0, PI / 3.0, 0.5 * PI, 0.5 * PI, 0.5 * PI, 0.5 * PI];
    for s in 4 {
        let web = if bar_sides[s] { margins[s] - 0.5 * BOX_WEB } else { 0.0 };
        inset[s] = [margins[s], r, r * (1.0 - sin(turn[2])), r * (1.0 - sin(turn[3])), 0.0, 0.0, web, web];
        depth[s] = [0.0, 0.0, r * (1.0 - cos(turn[2])), r * (1.0 - cos(turn[3])), r, past, past,
                    if bar_sides[s] { back.y } else { back.x }];
    }
    // The bands: the face, the step's three, the side to the glass; behind it the back.
    let bands: int2[6] = [int2 { 0, 1 }, int2 { 1, 2 }, int2 { 2, 3 }, int2 { 3, 4 }, int2 { 4, 5 }, int2 { 6, 7 }];
    for s in 4 {
        let o = outs[s];
        let along = s >= 2;
        let mat = paint_mat(tone, along, true, true);
        for band in bands {
            let k0 = band.x as i64;
            let k1 = band.y as i64;
            guard !(k0 == 6 && depth[s][7] <= past) else { continue; }
            var p:  float3[4] = [float3_0; 4];
            var n:  float3[4] = [float3_0; 4];
            var uv: float2[4] = [float2_0; 4];
            let ks: i64[4] = [k0, k0, k1, k1];
            for c in 4 {
                let k = ks[c];
                let x0 = pane.x - inset[0][k];
                let x1 = pane.z + inset[1][k];
                let y0 = pane.y - inset[2][k];
                let y1 = pane.w + inset[3][k];
                // Going round the pane anticlockwise seen from the room: the side's start
                // and end corners, outer then inner.
                let start = c == 0 || c == 3;
                var q = float2_0;
                if s == 2 { q = if start { float2 { x0, y0 } } else { float2 { x1, y0 } }; }
                if s == 1 { q = if start { float2 { x1, y0 } } else { float2 { x1, y1 } }; }
                if s == 3 { q = if start { float2 { x1, y1 } } else { float2 { x0, y1 } }; }
                if s == 0 { q = if start { float2 { x0, y1 } } else { float2 { x0, y0 } }; }
                p[c] = float3 { q.x, q.y, face - depth[s][k] };
                let a = turn[k];
                n[c] = normalize(float3 { -o.x * sin(a), -o.y * sin(a), cos(a) });
                uv[c] = float2 { NO_LINE, if k >= 6 { NO_LINE } else { past - depth[s][k] + inset[s][k] } };
            }
            // The quad's corners in order: outer start, outer end, inner end, inner start.
            paint_quad(verts, indices, b, [p[0], p[1], p[2], p[3]], [n[0], n[1], n[2], n[3]], [uv[0], uv[1], uv[2], uv[3]], 1.0, mat);
        }
    }
}

// Casement c's mesh into verts and indices, its glass into its own: the frame, each light's
// panes in their rings, the lip, the hardware (the inner casement's hinges and bolts; the
// crémone on both, the outer's on its face toward the room, as the specification has it).
fn box_casement_mesh(verts: mesh::Vertex[>..]&, indices: u32[>..]&, glass: mesh::Vertex[>..]&, glass_indices: u32[>..]&,
                     b: surfaces::Builder, c: BoxCasement, inner: bool, seed: i64&) {
    let f = c.frame_z;
    let w = c.jamb.y;
    let gx = c.jamb.x;
    let at_sash = c.sash_z.x - f.y;
    seed++;
    paint_box(verts, indices, b, -w, -gx, c.foot.x, c.head.y, f.y, f.x,
              Piece { round: RIGHT, sides: RIGHT, recess: RIGHT, foot: at_sash, window: true, seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, gx, w, c.foot.x, c.head.y, f.y, f.x,
              Piece { round: LEFT, sides: LEFT, recess: LEFT, foot: at_sash, window: true, seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, -gx, gx, c.head.x, c.head.y, f.y, f.x,
              Piece { round: BOTTOM, sides: BOTTOM, joints: LEFT | RIGHT, recess: BOTTOM, foot: at_sash, along: true, window: true,
                      seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, -gx, gx, c.foot.x, c.foot.y, f.y, f.x,
              Piece { round: TOP, sides: TOP, joints: LEFT | RIGHT, recess: TOP, foot: at_sash, along: true, window: true, seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, -gx, gx, c.transom.x, c.transom.y, f.y, f.x,
              Piece { round: TOP | BOTTOM, sides: TOP | BOTTOM, joints: LEFT | RIGHT, recess: TOP | BOTTOM, foot: at_sash, along: true,
                      window: true, seed: seed, .. });
    seed++;
    paint_box(verts, indices, b, -c.mullion, c.mullion, c.transom.y, c.head.x, f.y, f.x,
              Piece { round: LEFT | RIGHT, sides: LEFT | RIGHT, joints: BOTTOM | TOP, recess: LEFT | RIGHT, foot: at_sash, window: true,
                      seed: seed, .. });
    // The lights' panes, each in its ring; a light's tone its own.
    for l in c.lights {
        seed++;
        let tone = surfaces::hash(seed, 25);
        for j in l.up {
            for i in l.across {
                let bars: bool[4] = [i > 0, i < l.across - 1, j > 0, j < l.up - 1];
                pane_ring(verts, indices, b, cell_of(l, i, j), pane_of(l, i, j), bars, c.sash_z.x,
                          float2 { BOX_SASH_DEEP, BOX_BAR_DEEP }, tone);
            }
        }
    }
    // The active leaf's lip over the meeting.
    let lo = c.lights[0];
    let lip = c.sash_z.x + BOX_LIP_DEEP;
    seed++;
    paint_box(verts, indices, b, -BOX_LIP_OVER, BOX_LIP_ON, lo.box.y, lo.box.w, c.sash_z.x - 0.002, lip,
              Piece { round: EDGES, sides: EDGES, window: true, seed: seed, .. });
    quad_m(glass, glass_indices, b, [float3 { -gx, c.foot.y, c.glass_z }, float3 { gx, c.foot.y, c.glass_z },
                                     float3 { gx, c.head.x, c.glass_z }, float3 { -gx, c.head.x, c.glass_z }], surfaces::MAT_GLASS);
    box_hardware(verts, indices, b, c, inner);
}

// The hardware's material: the brass with a half's fraction, which ROOM_FRAG shades as the
// specification's dark brass (WINDOW_BRASS).
let WINDOW_HARDWARE: f32 = surfaces::MAT_BRASS + 0.5;

// The brass: the crémone's rod in its guides into the transom, its housing and handle at the
// leaf's bar; on the inner casement each leaf's two hinges and the passive leaf's two bolts.
fn box_hardware(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: BoxCasement, inner: bool) {
    let brass = WINDOW_HARDWARE;
    let lo = c.lights[0];
    let z = c.sash_z.x + BOX_LIP_DEEP;
    let x = cremone_x();
    let y = cremone_y(c);
    let r0 = lo.box.y + 0.012;
    let r1 = lo.box.w + 0.02;
    box_m(verts, indices, b, x - 0.003, x + 0.003, r0, r1, z, z + 0.006, brass);
    let guides: f32[4] = [0.1, 0.32, 0.68, 0.9];
    for t in guides {
        let gy = r0 + (r1 - r0) * t;
        box_m(verts, indices, b, x - 0.008, x + 0.008, gy - 0.012, gy + 0.012, z, z + 0.009, brass);
    }
    box_m(verts, indices, b, x - 0.015, x + 0.015, y - 0.055, y + 0.055, z, z + 0.014, brass);
    box_m(verts, indices, b, x - 0.008, x + 0.008, y + 0.012, y + 0.028, z + 0.014, z + 0.026, brass);
    box_m(verts, indices, b, x - 0.006, x + 0.006, y - 0.052, y + 0.024, z + 0.026, z + 0.034, brass);
    box_m(verts, indices, b, x - 0.008, x + 0.008, y - 0.062, y - 0.048, z + 0.022, z + 0.036, brass);
    guard inner else { return; }
    for l in c.lights {
        guard l.leaf >= 0 else { continue; }
        let ax = hinge_axis(c, l);
        let hy = hinge_heights(l);
        let into = if l.leaf == 0 { -1.0 } else { 1.0 };
        for hh in [hy.x, hy.y] {
            knuckle(verts, indices, b, float3 { ax.x, hh, ax.y }, BOX_HINGE_R, BOX_HINGE_HALF, 8, true, brass);
            let x0 = min(ax.x, ax.x + into * 0.024);
            let x1 = max(ax.x, ax.x + into * 0.024);
            box_m(verts, indices, b, x0, x1, hh - 0.045, hh + 0.045, c.sash_z.x, c.sash_z.x + 0.0025, brass);
        }
    }
    let p = c.lights[1];
    let bx = -(BOX_LIP_OVER + 0.5 * (BOX_STILE - BOX_LIP_OVER));
    for by in [p.box.y + 0.12, p.box.w - 0.1] {
        box_m(verts, indices, b, bx - 0.01, bx + 0.01, by - 0.0325, by + 0.0325, c.sash_z.x, c.sash_z.x + 0.01, brass);
        box_m(verts, indices, b, bx - 0.005, bx + 0.005, by - 0.005, by + 0.005, c.sash_z.x + 0.01, c.sash_z.x + 0.02, brass);
    }
}

// The panes of window o's sashes above the transom (upper) or below it, at its glass plane:
// their columns over both lights, left to right in x, into xs; their rows, upward, into ys;
// how many of each (render3d's haze takes them so).
fn box_panes(o: Opening, upper: bool, xs: float2[12]&, ys: float2[12]&) -> int2 {
    let c = box_casement(o, o.glass.x);
    let right = c.lights[if upper { 3 } else { 1 }];
    let left = c.lights[if upper { 2 } else { 0 }];
    var n = 0;
    for l in [right, left] {
        for i in l.across {
            let p = pane_of(l, i, 0);
            xs[n] = float2 { p.x, p.z };
            n++;
        }
    }
    for j in left.up {
        let p = pane_of(left, 0, j);
        ys[j] = float2 { p.y, p.w };
    }
    return int2 { n as i32, left.up as i32 };
}

// At (x, y) of casement c's plane (the window's metres), how far inside the frame's and the
// lights' edges the point is, and inside the bars too (both negative on wood), as
// LIGHT_FN's box_casement has it with no depth.
fn box_open_at(c: BoxCasement, x: f32, y: f32) -> f32, f32 {
    var frame = min(c.jamb.x - abs(x), min(y - c.foot.y, c.head.x - y));
    frame = min(frame, max(c.transom.x - y, y - c.transom.y));
    if y > c.transom.y { frame = min(frame, abs(x) - c.mullion); }
    var open = frame;
    for l in c.lights {
        guard x >= l.box.x && x <= l.box.z && y >= l.box.y && y <= l.box.w else { continue; }
        let a = glazed_of(l);
        open = min(open, min(min(x - a.x, a.z - x), min(y - a.y, a.w - y)));
        frame = open;
        // On the glazed area: inside the nearest pane, or on a bar (negative).
        var best: f32 = -1.0;
        for j in l.up {
            for i in l.across {
                let p = pane_of(l, i, j);
                best = max(best, min(min(x - p.x, p.z - x), min(y - p.y, p.w - y)));
            }
        }
        open = min(open, best);
    }
    return frame, open;
}
