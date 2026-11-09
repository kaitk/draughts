// The 3D board as plain math, with no graphics (task 015): its camera, the camera's fit
// into a rectangle of the screen, a tap turned into a square by a ray through the
// perspective, and each frame's instance data, filled from the same draw lists the flat
// board draws (board::fill), so both views follow one state and one animation. The app
// draws what `Scene` holds; tests run all of it headless.
//
// World units are the renderer's (src/render3d/mesh.goose): the playing field spans -4..4 in x and
// z whatever the draughts, so a square is 8 / n; y is up, the field's top y = 0; +z is
// the near side, the bottom of the screen. The world is laid out as the flat board shows
// it: x and z follow the flat layout's x and y (`to_world`, `to_flat`), so a turned board
// (board::Layout.flip) turns the 3D one too, and the light keeps its place on screen.
//
// The camera's image is fitted into a screen rectangle by a scale and a shift in clip
// space, as prototypes/game3d.html does, so the perspective stays the native one at every
// size. A `View` holds the camera and that fit, in pixels: a point at view-space x, y and
// depth d lands at c + k (x / d, -y / d).
//
// Nothing here allocates: the outline's points and a frame's instances are fixed arrays.
namespace view3d;
import std;
import math;
import vec;
import rules from "../rules";

// The camera (poc/3d/board3d.goose): 52.5° down, a 31° field of view, 14.75 away from a
// point a little in front of the field's middle, fitted there to the 3D reference's field
// corners. NEAR and FAR are its depth range.
let FOV:      f32 = 31.0;
let DISTANCE: f32 = 14.75;
let PITCH:    f32 = 52.5;
let TARGET = float3 { 0.0, -0.15, 1.1 };
let NEAR: f32 = 2.0;
let FAR:  f32 = 40.0;

// The board: the field's half width, the dark inlay round it, the frame round that, its
// top above the field, and the board's underside. Kept in step with
// src/render3d/mesh.goose's and src/render3d/shaders.goose's constants of these names.
let FIELD:     f32 = 4.0;
let INNER:     f32 = 4.1;
let FRAME_W:   f32 = 0.5;
let FRAME_TOP: f32 = 0.05;
let BOTTOM:    f32 = -0.7;

// A piece on 8 × 8, where a square is 1: 88% of a square across, its height 33% of its
// diameter; a 10 × 10 board's pieces are scaled by its smaller square (`unit`). The
// selected piece lifts LIFT and grows to GROW: the 2D board's lift of 1.1% of the board
// (board::fill) is LIFT here, so any 2D lift maps by the same ratio (`lift_of`).
let RADIUS:    f32 = 0.44;
let HEIGHT:    f32 = 0.29;
let LIFT:      f32 = 0.07;
let GROW:      f32 = 1.05;
let FLAT_LIFT: f32 = 0.011;   // the 2D board's selected lift, of the board's side
let FLAT_DRAG: f32 = 0.016;   // and a dragged piece's (board::fill)
let FLAT_DISC: f32 = 0.39;    // the 2D disc's radius, of a square

// The camera's angles, in degrees: pitch down from level, yaw round the board (0 seen
// from the near side, 180 from the far one), both about TARGET; and the board's turn
// about its own middle under a camera and a light that keep their place on screen (a
// hot-seat game's, 180 facing the far side), which turns the camera the other way round
// the field's middle (`spin`).
struct Camera {
    pitch: f32 = PITCH,
    yaw:   f32 = 0.0,
    turn:  f32 = 0.0,
}

// The camera fitted into the screen: its eye and axes, k pixels per unit of x / depth,
// and c, the pixel the view's axis goes through. `rect` is the board's bounds on screen
// at the camera's angles before any turn; `n` its squares per side; `turn` the board's
// (Camera.turn), by which the renderer turns its light too.
struct View {
    eye:   float3 = float3 { 0.0, 0.0, 0.0 },
    right: float3 = float3 { 1.0, 0.0, 0.0 },
    up:    float3 = float3 { 0.0, 1.0, 0.0 },
    ahead: float3 = float3 { 0.0, 0.0, -1.0 },
    k:     f32    = 1.0,
    c:     float2 = float2 { 0.0, 0.0 },
    rect:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    n:     i64    = 8,
    turn:  f32    = 0.0,
}

// A column-major 4 × 4 matrix, laid out as gfx::mat4 and GLSL's mat4.
struct Mat { c0: float4, c1: float4, c2: float4, c3: float4 }

// World units per square.
fn unit(n: i64) -> f32 { 2.0 * FIELD / n }

// Where the camera's eye is, and its axes, for `cam`.
fn place(v: View&, cam: Camera) {
    let yaw = radians(cam.yaw);
    let pitch = radians(cam.pitch);
    let eye = TARGET + float3 { sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch) } * DISTANCE;
    let ahead = normalize(TARGET - eye);
    let right = normalize(cross(ahead, float3 { 0.0, 1.0, 0.0 }));
    v.eye = spin(eye, cam.turn);
    v.ahead = spin(ahead, cam.turn);
    v.right = spin(right, cam.turn);
    v.up = cross(v.right, v.ahead);
    v.turn = cam.turn;
}

// p turned `degrees` about the y axis through the field's middle: the camera's part of
// the board's turn (Camera.turn), and the light's in the renderer (render3d::light). At
// 0 it is p exactly.
fn spin(p: float3, degrees: f32) -> float3 {
    let a = radians(degrees);
    let c = cos(a);
    let s = sin(a);
    return float3 { c * p.x + s * p.z, p.y, c * p.z - s * p.x };
}

// The view of `cam` with the fit k, c (as fit() made it for the camera's angles at rest;
// a turn keeps the fit, as the prototype's inspection does).
fn turned(fitted: View, cam: Camera) -> View {
    var v = fitted;
    place(v, cam);
    return v;
}

// Where a world point lands on screen: x, y in pixels and its depth along the view.
fn project(v: View, p: float3) -> float3 {
    let d = p - v.eye;
    let depth = dot(d, v.ahead);
    return float3 { v.c.x + v.k * dot(d, v.right) / depth, v.c.y - v.k * dot(d, v.up) / depth, depth };
}

// The direction of the ray from the eye through pixel p (not normalized: its length
// along the view's axis is 1).
fn ray(v: View, p: float2) -> float3 {
    return v.ahead + v.right * ((p.x - v.c.x) / v.k) - v.up * ((p.y - v.c.y) / v.k);
}

// Where the ray through pixel p meets the plane y = h, as world x and z; false when it
// doesn't (looking up from under it, or along it).
fn on_plane(v: View, p: float2, h: f32) -> float2, bool {
    let d = ray(v, p);
    guard d.y < -0.000001 else { return float2 { 0.0, 0.0 }, false; }
    let t = (h - v.eye.y) / d.y;
    guard t > 0.0 else { return float2 { 0.0, 0.0 }, false; }
    return float2 { v.eye.x + d.x * t, v.eye.z + d.z * t }, true;
}

// The view's matrix for a screen `width` × `height` pixels: the camera's view and its
// perspective with the fit in it, to SDL_GPU's clip space (depth 0 at NEAR, 1 at FAR,
// y up), as gfx::perspective times gfx::look_at, scaled and shifted in clip space.
fn matrix(v: View, width: f32, height: f32) -> Mat {
    // The view: right, up, and back (-ahead) as rows, the eye at the origin.
    let s = v.right;
    let u = v.up;
    let f = v.ahead;
    let view = Mat { c0: float4 { s.x, u.x, -f.x, 0.0 }, c1: float4 { s.y, u.y, -f.y, 0.0 },
                     c2: float4 { s.z, u.z, -f.z, 0.0 },
                     c3: float4 { -dot(s, v.eye), -dot(u, v.eye), dot(f, v.eye), 1.0 } };
    // x_clip = 2k/W x + (2 c.x / W - 1) d, y_clip = 2k/H y + (1 - 2 c.y / H) d, w = d,
    // with d = -z the depth.
    let proj = Mat { c0: float4 { 2.0 * v.k / width, 0.0, 0.0, 0.0 }, c1: float4 { 0.0, 2.0 * v.k / height, 0.0, 0.0 },
                     c2: float4 { 1.0 - 2.0 * v.c.x / width, 2.0 * v.c.y / height - 1.0, FAR / (NEAR - FAR), -1.0 },
                     c3: float4 { 0.0, 0.0, NEAR * FAR / (NEAR - FAR), 0.0 } };
    return mul(proj, view);
}

fn mul(m: Mat, x: float4) -> float4 { m.c0 * x.x + m.c1 * x.y + m.c2 * x.z + m.c3 * x.w }
fn mul(a: Mat, b: Mat) -> Mat { Mat { c0: mul(a, b.c0), c1: mul(a, b.c1), c2: mul(a, b.c2), c3: mul(a, b.c3) } }

// What bounds the board on screen: the frame's outline at its top and its foot, round
// its corners (a quarter circle of FRAME_W each), and a lifted king's top over each
// corner square, so a piece on the far row never pokes past the bounds. With `field`,
// the playing field alone, what the zoom frames: its corners, and a lifted king's top
// over each of them, so every square and every piece's top is inside.
type Outline = float3[..80];

fn outline(n: i64, pts: Outline&, field: bool = false) {
    pts.clear();
    if field {
        let top = LIFT + 2.0 * HEIGHT * unit(n) * GROW;
        for y in [0.0, top] {
            for s in [float2 { FIELD, FIELD }, float2 { -FIELD, FIELD }, float2 { -FIELD, -FIELD }, float2 { FIELD, -FIELD }] {
                pts.push(float3 { s.x, y as f32, s.y });
            }
        }
        return;
    }
    let corners: float2[4] = [float2 { INNER, INNER }, float2 { -INNER, INNER }, float2 { -INNER, -INNER },
                              float2 { INNER, -INNER }];
    for c, k in corners {
        for i in 9 {
            let a = 0.5 * PI * (k + i as f32 / 8.0);
            let o = c + float2 { cos(a), sin(a) } * FRAME_W;
            pts.push(float3 { o.x, FRAME_TOP, o.y });
            pts.push(float3 { o.x, BOTTOM, o.y });
        }
    }
    let u = unit(n);
    let top = LIFT + 2.0 * HEIGHT * u * GROW;
    let m = FIELD - 0.5 * u;
    for s in [float2 { m, m }, float2 { -m, m }, float2 { -m, -m }, float2 { m, -m }] {
        pts.push(float3 { s.x, top, s.y });
    }
}

// The board's bounds seen by `cam` with k 1 and c 0: x, y of the top left, width, height;
// with `field` the playing field's (outline).
fn bounds(cam: Camera, n: i64, field: bool = false) -> float4 {
    var v = View { n: n, .. };
    place(v, cam);
    var pts: Outline = [];
    outline(n, pts, field);
    var lo = float2 { 1.0e9, 1.0e9 };
    var hi = float2 { -1.0e9, -1.0e9 };
    for p in pts {
        let q = project(v, p);
        lo = float2 { min(lo.x, q.x), min(lo.y, q.y) };
        hi = float2 { max(hi.x, q.x), max(hi.y, q.y) };
    }
    return float4 { lo.x, lo.y, hi.x - lo.x, hi.y - lo.y };
}

// How the bounds sit in a box they don't fill: at its top, in its middle, at its bottom.
let TOP = 0;
let MIDDLE = 1;
let BOTTOM_EDGE = 2;

// `cam`'s view fitted into `box` (x, y, width, height in pixels): as large as fits, k
// `most` at most, centered across, placed down the box by `align`.
fn fit(cam: Camera, n: i64, box: float4, align: i64, most: f32 = 1.0e9) -> View {
    let b = bounds(cam, n);
    let k = min(min(box.z / b.z, box.w / b.w), most);
    let w = b.z * k;
    let h = b.w * k;
    let x = box.x + 0.5 * (box.z - w);
    let y = if align == TOP { box.y } else if align == MIDDLE { box.y + 0.5 * (box.w - h) } else { box.y + box.w - h };
    var v = View { k: k, c: float2 { x - b.x * k, y - b.y * k }, rect: float4 { x, y, w, h }, n: n, .. };
    place(v, cam);
    return v;
}

// The flat layout the board package plays on under a 3D board seen through v: a square of
// the bounds' height in their middle, at s pixels a dp (the game screen's, home's,
// settings', and a puzzle's), which taps reach through the perspective (pick) and which
// the world follows (to_world).
fn square(v: View, s: f32) -> board::Layout {
    let r = v.rect;
    let size = min(r.z, r.w);
    return board::layout_at(r.x + 0.5 * (r.z - size), r.y + 0.5 * (r.w - size), size, s, v.n);
}

// Where the top of a piece standing at flat point p (on l) lands on screen: x, y in
// pixels, and the disc's radius there, in pixels across.
fn on_screen(v: View, l: board::Layout, p: float2) -> float3 {
    let xz = to_world(l, p);
    let u = unit(l.n);
    let q = project(v, float3 { xz.x, HEIGHT * u, xz.y });
    return float3 { q.x, q.y, v.k * RADIUS * u / q.z };
}

// The board's outline on screen as a convex polygon, counterclockwise on screen; with
// `field` the playing field's (outline).
type Hull = float2[..80];

fn hull(v: View, out: Hull&, field: bool = false) {
    var pts: Outline = [];
    outline(v.n, pts, field);
    var p: Hull = [];
    for q in pts {
        let s = project(v, q);
        p.push(float2 { s.x, s.y });
    }
    sort(p[..p.len]) { a, b => a.x < b.x || (a.x == b.x && a.y < b.y) };
    // Andrew's monotone chain: the lower chain left to right, the upper right to left.
    out.clear();
    for q in p {
        while out.len >= 2 && turn(out[out.len - 2], out[out.len - 1], q) <= 0.0 { out.pop(); }
        out.push(q);
    }
    let lower = out.len + 1;
    var i = p.len - 2;
    while i >= 0 {
        let q = p[i];
        while out.len >= lower && turn(out[out.len - 2], out[out.len - 1], q) <= 0.0 { out.pop(); }
        out.push(q);
        i -= 1;
    }
    out.pop();
}

fn turn(o: float2, a: float2, b: float2) -> f32 { (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x) }

// Whether pixel p is on the board v places: inside its outline on screen (hull), the
// frame and a lifted king's top over the corners included.
fn on_board(v: View, p: float2) -> bool {
    var h: Hull = [];
    hull(v, h);
    guard h.len >= 3 else { return false; }
    for a, i in h { if turn(a, h[(i + 1) % h.len], p) < 0.0 { return false; } }
    return true;
}

// Whether the board v places comes within `gap` pixels of rect r (x, y, width, height):
// the polygon and the grown rect overlap unless one of their edges separates them. With
// `field`, the playing field alone.
fn touches(v: View, r: float4, gap: f32, field: bool = false) -> bool {
    guard r.z > 0.0 && r.w > 0.0 else { return false; }
    var h: Hull = [];
    hull(v, h, field);
    let x0 = r.x - gap;
    let y0 = r.y - gap;
    let x1 = r.x + r.z + gap;
    let y1 = r.y + r.w + gap;
    var lo = float2 { 1.0e9, 1.0e9 };
    var hi = float2 { -1.0e9, -1.0e9 };
    for q in h {
        lo = float2 { min(lo.x, q.x), min(lo.y, q.y) };
        hi = float2 { max(hi.x, q.x), max(hi.y, q.y) };
    }
    guard hi.x > x0 && lo.x < x1 && hi.y > y0 && lo.y < y1 else { return false; }
    let corners: float2[4] = [float2 { x0, y0 }, float2 { x1, y0 }, float2 { x1, y1 }, float2 { x0, y1 }];
    for a, i in h {
        let b = h[(i + 1) % h.len];
        var outside = 0;
        for c in corners { if turn(a, b, c) <= 0.0 { outside++; } }
        if outside == 4 { return false; }
    }
    return true;
}

// The squares' flat layout and the world: a flat point (pixels on the board::Layout the
// board package plays on) and the world's x, z on the field's plane.
fn to_world(l: board::Layout, p: float2) -> float2 {
    let u = unit(l.n);
    return float2 { (p.x - l.inner.x) / l.inner.w * u - FIELD, (p.y - l.inner.y) / l.inner.w * u - FIELD };
}

fn to_flat(l: board::Layout, xz: float2) -> float2 {
    let u = unit(l.n);
    return float2 { l.inner.x + (xz.x + FIELD) / u * l.inner.w, l.inner.y + (xz.y + FIELD) / u * l.inner.w };
}

// A lift in pixels on the flat layout as the 3D board lifts it.
fn lift_of(l: board::Layout, lift: f32) -> f32 { lift / (FLAT_LIFT * l.board.z) * LIFT }

// Where the ray from o along d first meets a piece standing at xz, its foot at y0 and
// its top at y1, radius r: the distance along d, or -1 for none. Its top face or its side.
fn hit_piece(o: float3, d: float3, xz: float2, y0: f32, y1: f32, r: f32) -> f32 {
    var best: f32 = -1.0;
    if d.y < 0.0 {
        let t = (y1 - o.y) / d.y;
        let q = float2 { o.x + d.x * t - xz.x, o.z + d.z * t - xz.y };
        if t > 0.0 && dot(q, q) <= r * r { best = t; }
    }
    // The side: |o.xz + t d.xz - xz| = r, the nearer root, between the foot and the top.
    let m = float2 { o.x - xz.x, o.z - xz.y };
    let e = float2 { d.x, d.z };
    let a = dot(e, e);
    let b = dot(m, e);
    let c = dot(m, m) - r * r;
    let disc = b * b - a * c;
    if a > 0.0 && disc >= 0.0 {
        let t = (-b - sqrt(disc)) / a;
        let y = o.y + d.y * t;
        if t > 0.0 && y >= y0 && y <= y1 && (best < 0.0 || t < best) { best = t; }
    }
    return best;
}

// A tap at pixel p on the 3D board, as a point on the flat layout l for the board
// package's press, drag, and release (board::press): on a piece's top or side, its
// square's center, so a tap on a piece's face picks its square and not the one behind
// it; else where the ray meets the field. While a piece is held (pressed or dragged), the
// plane of the dragged piece's top, so the piece stays under the finger. The pieces are
// the board's at rest: the selected one lifted and grown, a stacked king two discs high,
// a piece waiting partway through a capture on its stop.
fn pick(v: View, b: board::Board&, l: board::Layout, p: float2) -> float2 {
    let vr .= rules::VARIANTS[b.variant];
    let u = unit(l.n);
    let o = v.eye;
    let d = ray(v, p);
    if b.pressed >= 0 {
        let king = b.pos.kings & rules::bit(b.pressed) != 0;
        let discs: f32 = if king && b.king_look == board::STACK { 2.0 } else { 1.0 };
        let h = lift_of(l, FLAT_DRAG * l.board.z) + discs * HEIGHT * u * GROW;
        let xz, ok = on_plane(v, p, h);
        if ok { return to_flat(l, xz); }
    }
    let waits = board::waiting(b);
    var best: f32 = -1.0;
    var at = float2 { 0.0, 0.0 };
    var all = b.pos.pieces[rules::WHITE] | b.pos.pieces[rules::BLACK];
    while all != 0 {
        let sq = ctz(all);
        all &= all - 1;
        let selected = sq == b.selected;
        let spot = if selected && waits >= 0 { board::center(l, vr, waits) } else { board::center(l, vr, sq) };
        let xz = to_world(l, spot);
        let lift:  f32 = if selected { LIFT } else { 0.0 };
        let scale: f32 = if selected { u * GROW } else { u };
        let king = b.pos.kings & rules::bit(sq) != 0;
        let discs: f32 = if king && b.king_look == board::STACK { 2.0 } else { 1.0 };
        let t = hit_piece(o, d, xz, lift, lift + discs * HEIGHT * scale, RADIUS * scale);
        if t > 0.0 && (best < 0.0 || t < best) {
            best = t;
            at = spot;
        }
    }
    if best > 0.0 { return at; }
    let xz, ok = on_plane(v, p, 0.0);
    guard ok else { return float2 { -1.0e6, -1.0e6 }; }
    return to_flat(l, xz);
}

// A frame of the 3D board, filled from the flat board's draw lists (fill below).
//
// `inst` is the renderer's storage buffer (src/render3d/), two float4s an instance: the foot (x, y, z) and the
// scale; then dark (0 or 1), 1 for a crowned disc or 0.5 a stack's upper disc, 1 for the
// selected piece or 2 a stack's lower disc, and a seed for its figure. A stacked king is
// two instances. `state` runs beside it, two float4s an instance, what the 2D pieces
// carry that the prototype's position didn't: opacity (a captured piece fading), the
// must-capture ring (1 pulsing, 2 still), the glow ring tight round it (0 to 1), the
// selected glow (0 to 1); then board::Piece.win as it is (a win's dim, its lit square).
// `squares` is the prototype's for the field's occlusion, one float4 a square of the
// world's grid, row * n + column, row 0 the far side: the top, the foot, the radius,
// and 1 when a piece stands there. `marks` and `flash` are board::fill's, numbered by the
// world's grid too; `selected` the selected piece's foot and radius (w 0 for none), as
// the prototype's glow ring takes it; `dim` the board's under a win. `field` is the
// marks as the renderer's field pass reads them (shaders::MARKS_FRAG), a float4 a square
// of the world's grid: x the last move's tint (1), y a target's dot (1) or a stop's ring
// (2), z the must-capture ring, 1 pulsing or 2 still, w 0 on a wrong move's flashing
// square, else -1. `lit` runs beside it, a float4 a square too: x the glow ring tight
// round the piece standing there (a puzzle's hint, a win's wave), 0 to 1; y the square
// lit by a win's glow passing, 0 to 1; z how many pieces the piece standing there takes,
// shown as pips on the field (board::Piece.ring.z), 0 for none. Under a win's dim the winning piece alone stays
// lit: its seed (kind's w) is SEED_LIT more, which the shaders take off again for its
// figure.
//
// What moves while nothing else does, `pulse`, is drawn over the kept image each frame
// rather than with the board (render3d::marks_over): x the must-capture rings' phase at
// `now` (0 brightest, 1 dimmest; they pulse every 1.4 s, as the flat board's do), y the
// wrong move's flash, 0 to 1 (1 none), z the square of the hint's glow ring while it
// pulses (-1 none) and w its strength. `pulsing` says whether any of them shows; the
// scene's other parts then stay the same from frame to frame (`changes` gives MARKS).
let MAX_INSTANCES = 96;     // two for each of board::MAX_PIECES, as a stack takes
let SEED_LIT: f32 = 1000.0;

struct Scene {
    view:     View                        = View {},
    inst:     float4[..2 * MAX_INSTANCES] = [],
    state:    float4[..2 * MAX_INSTANCES] = [],
    squares:  float4[100]                 = [float4 { 0.0, 0.0, 0.0, 0.0 }; 100],
    marks:    board::Marks                = board::Marks {},
    flash:    float4                      = float4 { -1.0, 0.0, 0.0, 0.0 },
    selected: float4                      = float4 { 0.0, 0.0, 0.0, 0.0 },
    dim:      f32                         = 0.0,
    field:    float4[100]                 = [float4 { 0.0, 0.0, 0.0, -1.0 }; 100],
    lit:      float4[100]                 = [float4 { 0.0, 0.0, 0.0, 0.0 }; 100],
    pulse:    float4                      = float4 { 0.0, 1.0, -1.0, 0.0 },
    pulsing:  bool                        = false,
}

// A board square's number (y * size + x, as board::Marks numbers it) in the world's grid
// (row * n + column, row 0 the far side): the flat layout's turn is the world's.
fn world_square(l: board::Layout, s: i64) -> i64 {
    let n = l.n;
    let x = s % n;
    let y = s / n;
    return if l.flip { y * n + (n - 1 - x) } else { (n - 1 - y) * n + x };
}

fn mark_world(l: board::Layout, from: u32[4]&, to: u32[4]&) {
    to = [0; 4];
    for s in l.n * l.n {
        guard (from[s / 32] >> (s % 32)) & 1 != 0 else { continue; }
        let w = world_square(l, s);
        to[w / 32] |= (1 as u32) << (w % 32);
    }
}

// Fills s for the frame board::fill left in b, on the flat layout l, seen through v.
// Each 2D piece becomes one instance, or two for a stacked king, at its place, lift,
// and size as the 2D board animates them: a move along its stops with its hop, a drag,
// a captured piece fading, a win's lift and growth; the must-capture ring's pulse at
// `now`.
fn fill(s: Scene&, b: board::Board&, l: board::Layout, v: View, now: f64) {
    s.view = v;
    s.inst.clear();
    s.state.clear();
    for i in 100 {
        s.squares[i] = float4 { 0.0, 0.0, 0.0, 0.0 };
        s.field[i] = float4 { 0.0, 0.0, 0.0, -1.0 };
        s.lit[i] = float4 { 0.0, 0.0, 0.0, 0.0 };
    }
    // The must-capture ring: brightest still, fading to 0.4 and back while it pulses.
    let phase = (0.5 - 0.5 * cos(2.0 * PI * now / 1.4)) as f32;
    s.pulse = float4 { phase, 1.0, -1.0, 0.0 };
    s.pulsing = false;
    // The hint's glow ring pulses for its first PULSE, round the one piece it lights.
    let hint = b.glow >= 0 && b.glow_at >= 0.0 && now < b.glow_at + board::PULSE;
    s.selected = float4 { 0.0, 0.0, 0.0, 0.0 };
    let n = l.n;
    let u = unit(n);
    let r0 = FLAT_DISC * l.inner.w;
    for p, i in b.pieces {
        guard s.inst.len + 4 <= 2 * MAX_INSTANCES else { break; }
        let xz = to_world(l, float2 { p.at.x, p.at.y });
        let glow = p.look.z;
        let scale = u * (p.at.z / r0) * (1.0 + (GROW - 1.0) * glow);
        let lift = lift_of(l, p.at.w);
        let dark = p.look.x;
        let seed = i + (if b.dim > 0.0 && p.win.x <= 0.0 { SEED_LIT } else { 0.0 });
        // The hint's pulsing ring is left out of the state, so its pulse alone draws only
        // the marks over the image.
        let ring_y = if hint && p.ring.y > 0.0 { 1.0 } else { p.ring.y };
        let fx = float4 { p.look.w, p.ring.x, ring_y, glow };
        var top = lift + HEIGHT * scale;
        let king = p.look.y;
        if king == board::STACK {
            s.inst.push(float4 { xz.x, lift, xz.y, scale });
            s.inst.push(float4 { dark, 0.0, 2.0, seed });
            s.inst.push(float4 { xz.x, top, xz.y, scale });
            s.inst.push(float4 { dark, 0.5, 0.0, seed + 0.5 });
            for k in 2 {
                s.state.push(fx);
                s.state.push(p.win);
            }
            top += HEIGHT * scale;
        } else {
            let crown: f32 = if king == board::CROWN { 1.0 } else { 0.0 };
            let sel:   f32 = if glow > 0.0 { 1.0 } else { 0.0 };
            s.inst.push(float4 { xz.x, lift, xz.y, scale });
            s.inst.push(float4 { dark, crown, sel, seed });
            s.state.push(fx);
            s.state.push(p.win);
        }
        // The field's occlusion under it, once it is more there than gone.
        let col = floor((xz.x + FIELD) / u) as i64;
        let row = floor((xz.y + FIELD) / u) as i64;
        if p.look.w > 0.5 && col >= 0 && row >= 0 && col < n && row < n {
            s.squares[row * n + col] = float4 { top, lift, RADIUS * scale, 1.0 };
        }
        if glow > 0.0 { s.selected = float4 { xz.x, lift, xz.y, RADIUS * scale }; }
        if p.ring.x > 0.5 && col >= 0 && row >= 0 && col < n && row < n {
            let still = p.ring.x > 1.5;
            s.field[row * n + col].z = if still { 2.0 } else { 1.0 };
            if !still { s.pulsing = true; }
        }
        if hint && p.ring.y > 0.0 && col >= 0 && row >= 0 && col < n && row < n {
            s.pulse.z = row * n + col;
            s.pulse.w = p.ring.y * p.look.w;
            s.pulsing = true;
        } else if (p.ring.y > 0.0 || p.win.y > 0.0) && col >= 0 && row >= 0 && col < n && row < n {
            let o .= s.lit[row * n + col];
            o.x = max(o.x, p.ring.y * p.look.w);
            o.y = max(o.y, p.win.y);
        }
        if p.ring.z > 0.5 && col >= 0 && row >= 0 && col < n && row < n { s.lit[row * n + col].z = p.ring.z; }
    }
    mark_world(l, b.marks.last, s.marks.last);
    mark_world(l, b.marks.target, s.marks.target);
    mark_world(l, b.marks.via, s.marks.via);
    s.flash = b.flash;
    if b.flash.x >= 0.0 { s.flash.x = world_square(l, b.flash.x as i64); }
    s.dim = b.dim;
    for i in n * n {
        let w = i / 32;
        let bit = (1 as u32) << (i % 32);
        if s.marks.last[w] & bit != 0 { s.field[i].x = 1.0; }
        if s.marks.target[w] & bit != 0 { s.field[i].y = 1.0; }
        if s.marks.via[w] & bit != 0 { s.field[i].y = 2.0; }
    }
    if s.flash.x >= 0.0 && s.flash.y < 1.0 {
        s.field[s.flash.x as i64].w = 0.0;
        s.pulse.y = s.flash.y;
        s.pulsing = true;
    }
    // Nothing pulsing: the phase stays put, so time alone changes nothing.
    if !s.pulsing { s.pulse.x = 0.0; }
}

// What a new frame's scene changes against the last one drawn: DRAW when anything the 3D
// board shows differs, so it is drawn again; SHADOW when the pieces stand or lift
// differently, so the shadow map is drawn again too; MARKS when only `pulse` does (a ring
// pulsing, a flash), so only the marks over the kept image are drawn with it. Nothing for
// the same scene: the board isn't drawn, though the UI over it may be.
let DRAW = 1;
let SHADOW = 2;
let MARKS = 4;

fn same(a: float4, b: float4) -> bool { a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w }
fn same3(a: float3, b: float3) -> bool { a.x == b.x && a.y == b.y && a.z == b.z }

fn same_list(a: float4[..2 * MAX_INSTANCES]&, b: float4[..2 * MAX_INSTANCES]&) -> bool {
    guard a.len == b.len else { return false; }
    for i in a.len { if !same(a[i], b[i]) { return false; } }
    return true;
}

fn same_bits(a: u32[4]&, b: u32[4]&) -> bool { a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3] }

// Whether two views draw the board alike: the same eye, direction, and fit.
fn same_view(a: View, b: View) -> bool {
    return same3(a.eye, b.eye) && same3(a.ahead, b.ahead) && a.k == b.k && a.c.x == b.c.x && a.c.y == b.c.y && a.n == b.n
           && a.turn == b.turn;
}

fn changes(was: Scene&, now: Scene&) -> i64 {
    guard same_list(was.inst, now.inst) else { return DRAW | SHADOW; }
    var rest = same_view(was.view, now.view) && same_list(was.state, now.state)
               && same(was.selected, now.selected) && was.dim == now.dim && same_bits(was.marks.last, now.marks.last)
               && same_bits(was.marks.target, now.marks.target) && same_bits(was.marks.via, now.marks.via);
    for i in 100 {
        if rest && (!same(was.squares[i], now.squares[i]) || !same(was.field[i], now.field[i]) || !same(was.lit[i], now.lit[i])) {
            rest = false;
        }
    }
    guard rest else { return DRAW; }
    return if same(was.pulse, now.pulse) { 0 } else { MARKS };
}
