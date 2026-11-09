// The 3D board's camera and picking (src/board/view3d.goose, task 015): the camera at
// rest and its bounds' proportions, its fit into a box, its matrix agreeing with the
// projection the picking inverts, and taps through the perspective: every dark square's
// middle and points just inside the field's corners and edges hit their squares, on 8 × 8
// and 10 × 10, with the camera at rest, turned within the inspection range, and turned
// round; just off the field is no square. A tap on a lifted piece's face or a stacked
// king's top picks its square, where the field under the same pixel is the square
// behind it.
import std;
import vec;
import math;
import rules from "../../src/rules";
import board from "../../src/board";
import gui from "../../src/gui";
import strings from "../../strings";
import game from "../../src/game";
import ai from "../../src/ai";
import shell from "../../src/shell";
import puzzles from "../../src/puzzles";
import drive from "../drive";

fn round2(x: f32) -> f64 { floor(x * 100.0 + 0.5) / 100.0 }

// A flat layout standing in for the board, as the game screen's is: a square of the
// fitted rect's height in its middle.
fn flat(v: view3d::View, n: i64) -> board::Layout {
    let r = v.rect;
    return board::layout_at(r.x + 0.5 * (r.z - r.w), r.y, r.w, 1.0, n);
}

// A board square's middle in the world.
fn middle(l: board::Layout, vr: rules::Variant&, sq: i64) -> float3 {
    let xz = view3d::to_world(l, board::center(l, vr, sq));
    return float3 { xz.x, 0.0, xz.y };
}

// The cell a flat point is on, dark or light, by column and rank, or "-" off the board.
fn cell(l: board::Layout, p: float2) -> u8[>..] {
    let x = floor((p.x - l.inner.x) / l.inner.w) as i64;
    let row = floor((p.y - l.inner.y) / l.inner.w) as i64;
    guard x >= 0 && row >= 0 && x < l.n && row < l.n else { return str("-"); }
    var s: u8[>..] = [];
    s.push((97 + x) as u8);
    format(s, l.n - row);
    if (x + l.n - 1 - row) % 2 == 1 { s.append(", a light square"); }
    return s;
}

fn px(v: view3d::View, p: float3) -> float2 {
    let q = view3d::project(v, p);
    return float2 { q.x, q.y };
}

// Taps every dark square's middle and the four points 0.45 of a square from it toward
// its corners on an empty board; returns how many of them hit their square.
fn sweep(v: view3d::View, b: board::Board&, l: board::Layout) -> i64 {
    let vr .= rules::VARIANTS[b.variant];
    let u = view3d::unit(l.n);
    var good = 0;
    var left = vr.mask;
    while left != 0 {
        let sq = ctz(left);
        left &= left - 1;
        let c = middle(l, vr, sq);
        for k in 5 {
            let d = if k == 0 { float3 { 0.0, 0.0, 0.0 } }
                    else { float3 { if k % 2 == 0 { 0.45 } else { -0.45 }, 0.0, if k < 3 { 0.45 } else { -0.45 } } * u };
            if board::hit(l, vr, view3d::pick(v, b, l, px(v, c + d))) == sq { good++; }
        }
    }
    return good;
}

fn main() {
    strings::use(strings::EN);
    let cam = view3d::Camera {};
    var v0 = view3d::View {};
    view3d::place(v0, cam);
    print("eye ", round2(v0.eye.x), " ", round2(v0.eye.y), " ", round2(v0.eye.z));
    // The bounds' proportions, and the frame's far edge against its near edge.
    let b = view3d::bounds(cam, 8);
    let e = view3d::INNER + view3d::FRAME_W;
    let far = px(v0, float3 { e, view3d::FRAME_TOP, -e }).x - px(v0, float3 { -e, view3d::FRAME_TOP, -e }).x;
    let near = px(v0, float3 { e, view3d::FRAME_TOP, e }).x - px(v0, float3 { -e, view3d::FRAME_TOP, e }).x;
    print("bounds ", round2(b.z / b.w), ":1, far edge ", round2(far / near), " of the near edge");
    for p in [60.0, 65.0] {
        let s = view3d::bounds(view3d::Camera { pitch: p as f32, .. }, 8);
        print("  at ", p, "° down: ", round2(s.z / s.w), ":1");
    }

    // Fitted into a box at its bottom, and the matrix: a world point through it lands
    // where project() puts it.
    let v = view3d::fit(cam, 8, float4 { 24.0, 24.0, 1232.0, 752.0 }, view3d::BOTTOM_EDGE);
    print("fit into 1232 × 752 at its bottom: rect ", round2(v.rect.x), " ", round2(v.rect.y), " ", round2(v.rect.z), " ",
          round2(v.rect.w));
    let m = view3d::matrix(v, 1280.0, 800.0);
    var worst: f32             = 0.0;
    var pts:   view3d::Outline = [];
    view3d::outline(8, pts);
    for p in pts {
        let c = view3d::mul(m, float4 { p.x, p.y, p.z, 1.0 });
        let q = float2 { (c.x / c.w + 1.0) * 0.5 * 1280.0, (1.0 - c.y / c.w) * 0.5 * 800.0 };
        worst = max(worst, length(q - px(v, p)));
        guard c.z / c.w > 0.0 && c.z / c.w < 1.0 else { print("outside the depth range"); }
    }
    print("matrix against project: ", worst < 0.01);

    // Taps on an empty board: five points a dark square, each on its square.
    for n in [8, 10] {
        let variant: u8 = if n == 8 { rules::RUSSIAN } else { rules::INTERNATIONAL };
        var bd = board::new(variant);
        board::show(bd, rules::Position { pieces: [0, 0], kings: 0, side: 0, variant: variant });
        let vr .= rules::VARIANTS[variant];
        for c in [view3d::Camera {}, view3d::Camera { pitch: 52.5, yaw: 20.0 }, view3d::Camera { pitch: 75.0, yaw: -35.0 },
                  view3d::Camera { pitch: 52.5, yaw: 180.0 }] {
            let fv = view3d::fit(view3d::Camera {}, n, float4 { 24.0, 24.0, 1232.0, 752.0 }, view3d::BOTTOM_EDGE);
            let tv = view3d::turned(fv, c);
            let l = flat(fv, n);
            print(n, " × ", n, " at ", c.pitch, "° down, turned ", c.yaw, "°: ", sweep(tv, bd, l), " of ", 5 * popcount(vr.mask),
                  " taps on their square");
        }
        // Just inside the field's corners and its edges, on the dark squares there (0.03
        // from the field's edge), and just off the field, in the inlay beside a corner.
        let fv = view3d::fit(view3d::Camera {}, n, float4 { 24.0, 24.0, 1232.0, 752.0 }, view3d::BOTTOM_EDGE);
        let l = flat(fv, n);
        let f = view3d::FIELD;
        let u = view3d::unit(n);
        let edge = f - 0.03;
        var line: u8[>..] = [];
        let names = if n == 8 { ["a1", "h8", "a5", "h4", "d8", "e1"] } else { ["a1", "j10", "a5", "j6", "f10", "e1"] };
        for name in names {
            let c = middle(l, vr, drive::square(vr, name));
            var q = c;
            if abs(c.x) + 0.6 * u > f { q.x = if c.x > 0.0 { edge } else { -edge }; }
            if abs(c.z) + 0.6 * u > f { q.z = if c.z > 0.0 { edge } else { -edge }; }
            line.append(name);
            line.append(" ");
            line.append(drive::name(vr, board::hit(l, vr, view3d::pick(fv, bd, l, px(fv, q)))));
            line.append(", ");
        }
        for q in [float2 { -f - 0.04, f - 0.3 * u }, float2 { f - 0.3 * u, -f - 0.04 }] {
            line.append("off ");
            line.append(drive::name(vr, board::hit(l, vr, view3d::pick(fv, bd, l, px(fv, float3 { q.x, 0.0, q.y })))));
            line.append(" ");
        }
        print(n, " × ", n, " corners and edges: ", line);
    }

    // A lifted piece: c3 selected, and a pixel on its top face near its far edge. The
    // field under that pixel is c4, a light square behind it, which is no square; the
    // pick gives c3. Then a stacked king on c3, not selected, and its top's far edge.
    var bd = board::new(rules::RUSSIAN);
    let vr .= rules::VARIANTS[rules::RUSSIAN];
    let l = flat(v, 8);
    let c3 = drive::square(vr, "c3");
    board::press(bd, l, board::center(l, vr, c3), 0.0);
    board::release(bd, l, board::center(l, vr, c3), 0.0);
    print("selected ", drive::name(vr, bd.selected));
    let u = view3d::unit(8);
    let top = view3d::LIFT + view3d::HEIGHT * u * view3d::GROW;
    let face = middle(l, vr, c3) + float3 { 0.0, top, -0.9 * view3d::RADIUS * u * view3d::GROW };
    let p = px(v, face);
    let under, ok = view3d::on_plane(v, p, 0.0);
    print("lifted c3's face: the field under it ", cell(l, view3d::to_flat(l, under)),
          " (", ok, ", at ", round2((under.y - middle(l, vr, c3).z) / u), " squares behind), picked ",
          drive::name(vr, board::hit(l, vr, view3d::pick(v, bd, l, p))));
    // Its side, low down at the front: the field under it is c3's near neighbour row.
    let side = middle(l, vr, c3) + float3 { 0.0, view3d::LIFT + 0.02, view3d::RADIUS * u * view3d::GROW };
    print("lifted c3's front side: picked ", drive::name(vr, board::hit(l, vr, view3d::pick(v, bd, l, px(v, side)))));

    var kb = board::new(rules::RUSSIAN);
    kb.king_look = board::STACK;
    board::show(kb, rules::Position { pieces: [rules::bit(c3), 0], kings: rules::bit(c3), side: 0, variant: rules::RUSSIAN });
    let crown = middle(l, vr, c3) + float3 { 0.0, 2.0 * view3d::HEIGHT * u, -0.9 * view3d::RADIUS * u };
    let kp = px(v, crown);
    let below, ok2 = view3d::on_plane(v, kp, 0.0);
    print("stacked king on c3, its top's far edge: the field under it ",
          cell(l, view3d::to_flat(l, below)), " (", round2((below.y - middle(l, vr, c3).z) / u),
          " squares behind), picked ", drive::name(vr, board::hit(l, vr, view3d::pick(v, kb, l, kp))));
    // The same, turned round (yaw 180): c3's far edge from the other side.
    let tv = view3d::turned(v, view3d::Camera { pitch: 52.5, yaw: 180.0 });
    let back = middle(l, vr, c3) + float3 { 0.0, 2.0 * view3d::HEIGHT * u, 0.9 * view3d::RADIUS * u };
    let bp = px(tv, back);
    let behind, ok3 = view3d::on_plane(tv, bp, 0.0);
    print("turned round, the king's top's far edge: the field under it ",
          cell(l, view3d::to_flat(l, behind)), ", picked ",
          drive::name(vr, board::hit(l, vr, view3d::pick(tv, kb, l, bp))));
}
