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
let BOX_HINGE_R:  f32 = 0.0055;
let BOX_HINGE_IN: f32 = 0.16;
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
// panes in their rings, the lip, the hardware (the inner casement's hinges; the
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
    // The head and the transom in three: square where the mullion meets them, else their
    // rounded edge runs on under its foot and shows as a bright crack along the joint.
    let m = c.mullion;
    let spans: float3[3] = [float3 { -gx, -m, LEFT as f32 }, float3 { -m, m, 0.0 }, float3 { m, gx, RIGHT as f32 }];
    seed++;
    for s in spans {
        let under = if s.z == 0.0 { 0 } else { BOTTOM };
        paint_box(verts, indices, b, s.x, s.y, c.head.x, c.head.y, f.y, f.x,
                  Piece { round: under, sides: under, joints: s.z as i64, recess: under, foot: at_sash, along: true, window: true,
                          seed: seed, .. });
    }
    seed++;
    paint_box(verts, indices, b, -gx, gx, c.foot.x, c.foot.y, f.y, f.x,
              Piece { round: TOP, sides: TOP, joints: LEFT | RIGHT, recess: TOP, foot: at_sash, along: true, window: true, seed: seed, .. });
    seed++;
    for s in spans {
        let over = if s.z == 0.0 { BOTTOM } else { TOP | BOTTOM };
        paint_box(verts, indices, b, s.x, s.y, c.transom.x, c.transom.y, f.y, f.x,
                  Piece { round: over, sides: over, joints: s.z as i64, recess: over, foot: at_sash, along: true, window: true,
                          seed: seed, .. });
    }
    seed++;
    paint_box(verts, indices, b, -m, m, c.transom.y, c.head.x, f.y, f.x,
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
// window's bronze (WINDOW_BRASS).
let WINDOW_HARDWARE: f32 = surfaces::MAT_BRASS + 0.5;

// The room's hinges (the shutters' and the doors') take the window's metal with the box window.
fn hinge_metal() -> f32 { if box_window_on { WINDOW_HARDWARE } else { surfaces::MAT_BRASS } }
// Its colour at normal incidence (sRGB) and roughness: ROOM_FRAG's WINDOW_BRASS (checked equal
// by test/model3d/geometry.goose), the Cycles export's window_metal.
let WINDOW_METAL = float4 { 0.34, 0.25, 0.17, 0.5 };
// Task 129's antique brass in its place (ROOM_FRAG's window metal, the Surfaces block's
// window_metal, the light tuner's --window-metal): x its tone's level, 1 to 5, continuous (under
// 1 the flat WINDOW_METAL); y how much of the colour's mottling shows (0.5); z added to its
// roughness; w how much of the niche's window light its reflection takes (WINDOW_NICHE's 0.3).
let WINDOW_METAL_OFF = float4 { 0.0, 0.5, 0.0, 0.3 };
var window_metal = WINDOW_METAL_OFF;
// The wear a hardware vertex carries in its material's fraction: 0.5 plus WEAR_SPAN times it,
// -1 (sheltered) to 1 (rubbed).
let WEAR_SPAN: f32 = 0.2;

// The crémone (build/notes/box-window/hardware.html, round 2; the brief
// cremone-modelling-brief.md), in metres out of the leaf's face: the lip's face, the rod's
// axis (in front of the frame's face, so it runs past the leaf's rails into its keepers),
// the housing's front, the grip's axis; the rod's radius, the housing's half width and half
// height, the spindle's radius, the travel the rod reaches into a socket.
let CREMONE_LIP:     f32    = BOX_LIP_DEEP;
let CREMONE_ROD:     f32    = 0.021;
let CREMONE_HOUSING: f32    = 0.026;
let CREMONE_GRIP:    f32    = 0.056;
let CREMONE_ROD_R:   f32    = 0.004;
let CREMONE_HALF:    float2 = float2 { 0.014, 0.07 };
let CREMONE_SPINDLE: f32    = 0.006;
let CREMONE_IN:      f32    = 0.012;
// The grip's half profile from its middle to an end (along, radius; mm): the brief's, its
// boss and ends drawn round; mirrored about the spindle.
let GRIP_HALF: float2[24] = [float2 { 0.0, 12.0 }, float2 { 3.5, 11.6 }, float2 { 6.5, 10.3 }, float2 { 8.8, 8.4 },
                             float2 { 10.5, 6.5 }, float2 { 12.0, 5.6 }, float2 { 16.0, 4.9 }, float2 { 23.0, 4.6 },
                             float2 { 30.0, 5.1 }, float2 { 35.0, 6.2 }, float2 { 38.5, 7.6 }, float2 { 40.0, 9.4 },
                             float2 { 43.5, 9.4 }, float2 { 44.5, 7.8 }, float2 { 45.5, 8.4 }, float2 { 47.5, 8.4 },
                             float2 { 48.5, 6.2 }, float2 { 50.5, 4.0 }, float2 { 52.0, 4.6 }, float2 { 53.5, 5.4 },
                             float2 { 55.5, 5.4 }, float2 { 57.5, 4.3 }, float2 { 59.2, 2.4 }, float2 { 60.0, 0.0 }];
// A guide's sleeve (radius, along; mm): three collars; a keeper's socket; a screw's head; a
// hinge's barrel, tapered at both ends with a seam at its middle.
let GUIDE_SLEEVE: float2[12] = [float2 { 8.0, 0.0 }, float2 { 9.5, 1.5 }, float2 { 9.5, 4.0 }, float2 { 8.0, 5.5 },
                                float2 { 8.0, 11.0 }, float2 { 9.5, 12.5 }, float2 { 9.5, 15.5 }, float2 { 8.0, 17.0 },
                                float2 { 8.0, 22.5 }, float2 { 9.5, 24.0 }, float2 { 9.5, 26.5 }, float2 { 8.0, 28.0 }];
let KEEPER_SOCKET: float2[4] = [float2 { 7.0, 0.0 }, float2 { 8.0, 1.0 }, float2 { 8.0, 13.0 }, float2 { 7.0, 14.0 }];
let SCREW_HEAD:    float2[4] = [float2 { 3.0, 0.0 }, float2 { 3.0, 0.6 }, float2 { 2.0, 1.3 }, float2 { 0.0, 1.5 }];
let HINGE_BARREL: float2[9] = [float2 { 0.0, 0.0 }, float2 { 2.0, 4.0 }, float2 { 5.5, 10.0 }, float2 { 5.5, 59.0 },
                               float2 { 5.0, 60.0 }, float2 { 5.5, 61.0 }, float2 { 5.5, 110.0 }, float2 { 2.0, 116.0 },
                               float2 { 0.0, 120.0 }];

// A profile of (radius, along) points (mm) turned `sides` round the axis from c (metres in
// b's frame) along the unit `axis`, as lathe turns about the upright: a point's normal its
// two segments' mean where they turn less than surfaces::CREASE, a segment's own at a sharper
// turn. `round_only` takes every point's normal off the axis (the rod: round by its normals
// on a few sides). `wear` (window hardware only, the hand's: 1 on the grip) rubs the whole a
// little, the profile's convex points more and darkens its hollows, by how much a point stands
// out of its neighbours' line (half a millimetre in full).
fn lathe_along(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: float3, axis: float3, prof: const float2[:],
        sides: i64, mat: f32, wear: f32 = 0.0) {
    let k = m();
    var mats: f32[..64] = [];
    for i in prof.len {
        let bulge = if i > 0 && i + 1 < prof.len { prof[i].x - 0.5 * (prof[i - 1].x + prof[i + 1].x) } else { 0.0 };
        mats.push(mat + WEAR_SPAN * clamp(wear * (0.3 + 2.0 * bulge), -1.0, 1.0));
    }
    let mm: f32 = 0.001;
    let ref = if abs(axis.z) > 0.9 { float3 { 0.0, 1.0, 0.0 } } else { float3 { 0.0, 0.0, -1.0 } };
    let u = normalize(cross(ref, axis));
    let v = cross(u, axis);
    var flat: float3[..64] = [float3_0];
    for i in 1..prof.len {
        let t = prof[i] - prof[i - 1];
        flat.push(if length(t) > 0.000001 { normalize(float3 { t.y, -t.x, 0.0 }) } else { float3_0 });
    }
    for i in 1..prof.len {
        let n = flat[i];
        guard length_sq(n) > 0.0 else { continue; }
        let na = if i > 1 { surfaces::smooth_normal(n, flat[i - 1]) } else { n };
        let nc = if i + 1 < prof.len { surfaces::smooth_normal(n, flat[i + 1]) } else { n };
        let ends: float2[2] = [prof[i - 1], prof[i]];
        let ns:   float3[2] = [na, nc];
        let ms:   f32[2]    = [mats[i - 1], mats[i]];
        let base = verts.len as u32;
        for e in 2 {
            for sd in sides + 1 {
                let ang: f32 = TAU * sd / sides;
                let out = u * cos(ang) + v * sin(ang);
                let p = (c + axis * (ends[e].y * mm) + out * (ends[e].x * mm)) * k;
                let q = out * ns[e].x + axis * ns[e].y;
                verts.push(mesh::Vertex { surfaces::world(b, p.x, p.y, p.z), surfaces::world_normal(b, q), float2_0, 1.0, ms[e] });
            }
        }
        let ring = (sides + 1) as u32;
        for sd in sides {
            let s0 = base + sd as u32;
            indices.append([s0, s0 + 1, s0 + ring + 1, s0, s0 + ring + 1, s0 + ring]);
        }
    }
}

// A round rod of radius r from y0 to y1 at (x, z): `sides` flat sides shading round, its
// normals off its axis.
fn round_rod(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, x: f32, z: f32, y0: f32, y1: f32, r: f32, sides: i64,
       mat: f32) {
    let k = m();
    let base = verts.len as u32;
    for e in 2 {
        for sd in sides + 1 {
            let ang: f32 = TAU * sd / sides;
            let out = float3 { cos(ang), 0.0, sin(ang) };
            let p = float3 { x + out.x * r, if e == 0 { y0 } else { y1 }, z + out.z * r } * k;
            verts.push(mesh::Vertex { surfaces::world(b, p.x, p.y, p.z), surfaces::world_normal(b, out), float2_0, 1.0, mat });
        }
    }
    let ring = (sides + 1) as u32;
    for sd in sides {
        let s0 = base + sd as u32;
        indices.append([s0, s0 + 1, s0 + ring + 1, s0, s0 + ring + 1, s0 + ring]);
    }
}

let TOWARD_ROOM = float3 { 0.0, 0.0, 1.0 };
let UPWARD = float3 { 0.0, 1.0, 0.0 };

// A slotted screw's head on a face at z (its axis toward the room).
fn screw_head(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, x: f32, y: f32, z: f32) {
    lathe_along(verts, indices, b, float3 { x, y, z }, TOWARD_ROOM, SCREW_HEAD[..], 6, WINDOW_HARDWARE);
}

// The upper keeper's plate: three round lobes (left, right, above) about a round middle,
// one outline (metres, about (cx, cy) on a face at z0, 3 mm deep); its rim rounded by its
// normals. KEEPER_LOBES: each lobe's middle (mm from the plate's) and radius; the middle's
// radius last.
let KEEPER_LOBES: float3[4] = [float3 { -11.0, -2.0, 7.0 }, float3 { 11.0, -2.0, 7.0 }, float3 { 0.0, 10.0, 7.0 },
                               float3 { 0.0, 0.0, 9.5 }];
fn keeper_plate(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, cx: f32, cy: f32, z0: f32, mat: f32) {
    let k = m();
    let n = 48;
    let deep: f32 = 0.003;
    let rim: f32 = 0.001;
    let base = verts.len as u32;
    let front = float3 { cx, cy, z0 + deep } * k;
    verts.push(mesh::Vertex { surfaces::world(b, front.x, front.y, front.z), surfaces::world_normal(b, TOWARD_ROOM), float2_0, 1.0, mat });
    for i in n {
        let ang: f32 = TAU * i / n;
        let d = float2 { cos(ang), sin(ang) };
        // How far the outline reaches along d: the farthest lobe's edge.
        var t: f32 = 0.0;
        for l in KEEPER_LOBES {
            let c = float2 { l.x, l.y } * 0.001;
            let r = l.z * 0.001;
            let a = dot(d, c);
            let q = r * r - (dot(c, c) - a * a);
            if q >= 0.0 { t = max(t, a + sqrt(q)); }
        }
        let out = float3 { d.x, d.y, 0.0 };
        let tilt = normalize(float3 { d.x, d.y, 1.0 });
        let edge = float2 { cx, cy } + d * t;
        let inner = float2 { cx, cy } + d * (t - rim);
        // Four rings: the face's edge, the rim's top and its side, the back.
        let rings: float3[4] = [float3 { inner.x, inner.y, z0 + deep }, float3 { edge.x, edge.y, z0 + deep - rim },
                                float3 { edge.x, edge.y, z0 + deep - rim }, float3 { edge.x, edge.y, z0 }];
        let normals: float3[4] = [TOWARD_ROOM, tilt, out, out];
        for e in 4 {
            let p = rings[e] * k;
            verts.push(mesh::Vertex { surfaces::world(b, p.x, p.y, p.z), surfaces::world_normal(b, normals[e]), float2_0, 1.0, mat });
        }
    }
    for i in n {
        let a = base + 1 + (i * 4) as u32;
        let c = base + 1 + (((i + 1) % n) * 4) as u32;
        indices.append([base, a, c]);
        indices.append([a, a + 1, c + 1, a, c + 1, c]);
        indices.append([a + 2, a + 3, c + 3, a + 2, c + 3, c + 2]);
    }
}

// Casement c's crémone on its active leaf (light 0's lip): the rod from the foot's keeper to
// the transom's, a guide at each run's middle, the housing at the leaf's bar with its ends,
// screws and bearing, the spindle and the turned grip, hanging locked; each keeper a plate on
// the frame's face with its socket on the rod's axis.
fn cremone(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: BoxCasement) {
    let mat = WINDOW_HARDWARE;
    let f = c.sash_z.x;
    let lo = c.lights[0];
    let x = cremone_x();
    let y = cremone_y(c);
    let zr = f + CREMONE_ROD;
    let lip = f + CREMONE_LIP;
    let face = c.frame_z.x;
    let hh = CREMONE_HALF;
    // The rod, into both sockets.
    round_rod(verts, indices, b, x, zr, lo.box.y - CREMONE_IN, lo.box.w + CREMONE_IN, CREMONE_ROD_R, 6, mat);
    // The housing, its stepped ends, screws, the spindle's bearing.
    box_m(verts, indices, b, x - hh.x, x + hh.x, y - hh.y, y + hh.y, lip, f + CREMONE_HOUSING, mat);
    for e in SIDES {
        let y0 = if e < 0.0 { y - hh.y - 0.006 } else { y + hh.y };
        box_m(verts, indices, b, x - hh.x - 0.002, x + hh.x + 0.002, y0, y0 + 0.006, lip, f + CREMONE_HOUSING + 0.002, mat);
        screw_head(verts, indices, b, x, y + e * (hh.y - 0.004), f + CREMONE_HOUSING);
    }
    let bearing: float2[4] = [float2 { 9.0, 0.0 }, float2 { 9.0, 2.0 }, float2 { 7.5, 3.0 }, float2 { 0.0, 3.0 }];
    lathe_along(verts, indices, b, float3 { x, y, f + CREMONE_HOUSING }, TOWARD_ROOM, bearing[..], 10, mat);
    let reach = (CREMONE_GRIP - CREMONE_HOUSING) * 1000.0;
    let spindle: float2[4] = [float2 { 6.0, 0.0 }, float2 { 6.0, reach - 8.0 }, float2 { 7.5, reach - 4.0 }, float2 { 7.5, reach }];
    lathe_along(verts, indices, b, float3 { x, y, f + CREMONE_HOUSING }, TOWARD_ROOM, spindle[..], 8, mat);
    var grip: float2[..48] = [];
    for i in GRIP_HALF.len { grip.push(float2 { GRIP_HALF[GRIP_HALF.len - 1 - i].y, 60.0 - GRIP_HALF[GRIP_HALF.len - 1 - i].x }); }
    for i in 1..GRIP_HALF.len { grip.push(float2 { GRIP_HALF[i].y, 60.0 + GRIP_HALF[i].x }); }
    lathe_along(verts, indices, b, float3 { x, y - 0.06, f + CREMONE_GRIP }, UPWARD, grip[..], 8, mat, 1.0);
    // A guide at each run's middle: its backplate on the lip with two screws, its sleeve.
    let runs: float2[2] = [float2 { lo.box.y, y - hh.y - 0.006 }, float2 { y + hh.y + 0.006, lo.box.w }];
    for r in runs {
        let gy = 0.5 * (r.x + r.y);
        box_m(verts, indices, b, x - 0.008, x + 0.008, gy - 0.021, gy + 0.021, lip, lip + 0.005, mat);
        screw_head(verts, indices, b, x, gy - 0.017, lip + 0.005);
        screw_head(verts, indices, b, x, gy + 0.017, lip + 0.005);
        lathe_along(verts, indices, b, float3 { x, gy - 0.014, zr }, UPWARD, GUIDE_SLEEVE[..], 8, mat);
    }
    // The keepers: the transom's three-lobed plate over the leaf's top, a screw in each lobe;
    // the foot's under the leaf, on what shows of the foot over the sill; each socket at the
    // leaf's edge.
    let ky = lo.box.w + 0.018;
    keeper_plate(verts, indices, b, x, ky, face, mat);
    for l in 3 {
        let at = KEEPER_LOBES[l];
        screw_head(verts, indices, b, x + 0.001 * at.x, ky + 0.001 * at.y, face + 0.003);
    }
    lathe_along(verts, indices, b, float3 { x, lo.box.w - 0.002, zr }, UPWARD, KEEPER_SOCKET[..], 8, mat);
    box_m(verts, indices, b, x - 0.014, x + 0.014, c.foot.y - BOX_FOOT + 0.004, c.foot.y - 0.002, face, face + 0.003, mat);
    for sx in SIDES { screw_head(verts, indices, b, x + sx * 0.008, c.foot.y - BOX_FOOT + 0.012, face + 0.003); }
    lathe_along(verts, indices, b, float3 { x, lo.box.y - 0.012, zr }, UPWARD, KEEPER_SOCKET[..], 8, mat);
}

// The hardware: the crémone on both casements (the outer's on its face toward the room, as
// the specification has it); on the inner casement each leaf's two hinges. The passive leaf's
// bolts sit in its edge, unseen with the window shut, as in the restored manor's photo.
fn box_hardware(verts: mesh::Vertex[>..]&, indices: u32[>..]&, b: surfaces::Builder, c: BoxCasement, inner: bool) {
    cremone(verts, indices, b, c);
    guard inner else { return; }
    let mat = WINDOW_HARDWARE;
    for l in c.lights {
        guard l.leaf >= 0 else { continue; }
        let ax = hinge_axis(c, l);
        let hy = hinge_heights(l);
        for hh in [hy.x, hy.y] { lathe_along(verts, indices, b, float3 { ax.x, hh - 0.06, ax.y }, UPWARD, HINGE_BARREL[..], 8, mat); }
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
