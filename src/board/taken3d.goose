// What each side has taken, lying on the table beside the 3D board (view3d::build_scene,
// on a board on its table): beside the board at the side of the one that took them, the
// kings apart from the men, each piece as the board's are. A layout places each piece by
// its number alone, so a capture adds one and leaves the rest where they lay; it is the
// same every time, laid out by a fixed hash.
//
// Each layout has its own values (TABLE_LAYOUTS), which tools/taken_tune puts on sliders.
namespace taken3d;
import std;
import math;
import vec;
import rules from "../rules";

// How the men lie: short askew stacks in two staggered columns; a loose row, a piece now
// and then dropped on the one before; a loose heap, a few flat and the rest piled on
// them; tall stacks like coins in a row.
let STACKS = 0;
let ROW = 1;
let HEAP = 2;
let TOWERS = 3;
let LAYOUTS = 4;
let NAMES = ["stacks", "row", "heap", "towers"];

// A layout (`kind`, STACKS..) and its values. `out` and `along` place the men's middle in world units: out
// from the board's side, along it toward the taker's end. `turn` turns the group (degrees);
// `spread` its spacing, in pieces across; `stack` the most pieces a stack holds; `askew`
// how far each piece lies off the one under it, of a radius; `kings_along` and `kings_out` where
// the kings lie from the men's middle, in pieces across, along (less toward the far end)
// and out; `seed` the hash's.
struct TableLayout {
    kind:        i64 = STACKS,
    out:         f32 = 1.4,
    along:       f32 = 1.6,
    turn:        f32 = 0.0,
    spread:      f32 = 1.0,
    stack:       i64 = 4,
    askew:       f32 = 0.12,
    kings_along: f32 = -3.2,
    kings_out:   f32 = 0.0,
    seed:        i64 = 1,
}

let TABLE_LAYOUTS: TableLayout[LAYOUTS] = [
    TableLayout { kind: STACKS, out: 1.4, along: 2.3, turn: 8.0, spread: 1.0, stack: 4, askew: 0.14, kings_along: 1.9, kings_out: 0.2, seed: 3 },
    TableLayout { kind: ROW, out: 0.9, along: 4.2, turn: -5.0, spread: 1.0, stack: 2, askew: 0.2, kings_along: -6.6, kings_out: 0.4, seed: 5 },
    TableLayout { kind: HEAP, out: 1.6, along: 1.6, turn: 0.0, spread: 1.0, stack: 3, askew: 0.3, kings_along: 2.8, kings_out: 0.0, seed: 7 },
    TableLayout { kind: TOWERS, out: 1.2, along: 2.7, turn: 4.0, spread: 1.0, stack: 5, askew: 0.06, kings_along: 1.6, kings_out: 0.4, seed: 2 },
];

// The layout the game shows: the tuner changes it.
var table_layout: TableLayout = TABLE_LAYOUTS[STACKS];

let EDGE: f32 = mesh::INNER + mesh::FRAME_W;    // the board's side, out from its middle
let MOST = 20;                                  // the most pieces of a kind a side can take
let ARC: f32 = 1.2;                             // how high a carried piece rises (world units)
let ROW_LONG = 6;                               // a row's most places before the next

// A number in 0..1 from a few integers, the same every time.
fn hash(a: i64, b: i64, seed: i64) -> f32 {
    var x = (a * 73856093) ^ (b * 19349663) ^ (seed * 83492791) ^ 0x5bd1e995;
    x = (x ^ (x >> 13)) * 0x2c1b3c6d;
    x = x ^ (x >> 16);
    return (x & 0xFFFFFF) / 16777216.0;
}
fn signed_hash(a: i64, b: i64, seed: i64) -> f32 { 2.0 * hash(a, b, seed) - 1.0 }

// Where the men lie: out, along (in pieces across, from the men's middle), and how many
// pieces lie under each; the first `n`, each placed by its number and the ones before.
type Spots = float3[..MOST];

fn men_spots(h: TableLayout, n: i64, out: Spots&) {
    out.clear();
    let s = h.spread;
    let k = h.askew * 0.5;      // a radius is half a piece across
    let per = max(h.stack, 1);
    for i in min(n, MOST) {
        if h.kind == STACKS || h.kind == TOWERS {
            let j = i / per;
            let level = i % per;
            var base = float2 { 0.0, 0.0 };
            if h.kind == STACKS {
                // Two staggered columns, the second half a stack farther along.
                let col = j % 2;
                let row = j / 2;
                base = float2 { (col - 0.5) * 1.06 * s, -(row + 0.5 * col) * 1.08 * s };
                base += float2 { signed_hash(j, 1, h.seed), signed_hash(j, 2, h.seed) } * 0.1 * s;
            } else {
                base = float2 { signed_hash(j, 1, h.seed) * 0.08 * s, -(j as f32) * 1.1 * s };
            }
            let p = base + float2 { signed_hash(i, 3, h.seed), signed_hash(i, 4, h.seed) } * k;
            out.push(float3 { p.x, p.y, level });
        } else if h.kind == ROW {
            // A loose row, wavy, a piece now and then dropped on the one before; past
            // ROW_LONG places a second row starts farther out.
            let last = if i > 0 { out[i - 1] } else { float3 { 0.0, 0.0, -1.0 } };
            let lower = if i > 0 { (last.z as i64) + 1 } else { 0 };
            if i > 0 && lower < per && hash(i, 5, h.seed) < 0.35 {
                let p = float2 { last.x, last.y } + float2 { signed_hash(i, 3, h.seed), signed_hash(i, 4, h.seed) } * k;
                out.push(float3 { p.x, p.y, lower });
            } else {
                var flat = 0;
                for q in out { if q.z < 0.5 { flat++; } }
                let row = flat / ROW_LONG;
                let at = flat % ROW_LONG;
                let along = -(at * 1.12 + 0.5 * row + 0.2 * signed_hash(i, 6, h.seed)) * s;
                let across = (row * 1.15 + 0.3 * sin(0.8 * along + h.seed)) * s + signed_hash(i, 7, h.seed) * 0.16 * s;
                out.push(float3 { across, along, 0.0 });
            }
        } else {
            // A heap: seven flat, as a hexagon round one, the rest piled on them.
            let ground = 7;
            if i < ground {
                var p = float2 { 0.0, 0.0 };
                if i > 0 {
                    let a = (i - 1) * (PI / 3.0) + 0.4 * signed_hash(i, 8, h.seed);
                    p = float2 { cos(a), sin(a) } * (1.06 + 0.12 * hash(i, 9, h.seed)) * s;
                }
                out.push(float3 { p.x, p.y, 0.0 });
            } else {
                let on = (i * 3 + h.seed) % ground;
                var level: i64 = 1;
                let at = float2 { out[on].x, out[on].y };
                for q in out {
                    let d = float2 { q.x, q.y } - at;
                    if dot(d, d) < 0.25 && q.z as i64 >= level { level = (q.z as i64) + 1; }
                }
                let p = at + float2 { signed_hash(i, 3, h.seed), signed_hash(i, 4, h.seed) } * k;
                out.push(float3 { p.x, p.y, level });
            }
        }
    }
}

// Where the kings lie: apart, flat, in a short staggered pair of rows, each alone so its
// crown shows (a stacked king is two pieces of its own).
fn king_spots(h: TableLayout, n: i64, out: Spots&) {
    out.clear();
    let s = h.spread;
    for i in min(n, MOST) {
        let col = i % 2;
        let row = i / 2;
        let p = float2 { h.kings_out + (col - 0.5) * 1.08 * s, h.kings_along - (row + 0.5 * col) * 1.1 * s }
        + float2 { signed_hash(i, 11, h.seed), signed_hash(i, 12, h.seed) } * 0.08 * s;
        out.push(float3 { p.x, p.y, 0.0 });
    }
}

// A spot of the side that took (`taker`) in the world, its foot's x, y, z: white's catch
// at the board's right as white sees it, black's at its left, mirrored, both on the near
// half where the game's landscape panels leave the table in view; a turned board
// (`flip`) swaps them. r is the piece's radius and `height` its own.
fn world_spot(h: TableLayout, taker: i64, flip: bool, spot: float3, r: f32, height: f32) -> float3 {
    let a = radians(h.turn);
    let c = cos(a);
    let s = sin(a);
    let p = float2 { spot.x, spot.y } * (2.0 * r);
    let q = float2 { c * p.x - s * p.y, s * p.x + c * p.y };
    let local = float2 { EDGE + h.out + q.x, h.along + q.y };
    let sign: f32 = if (taker == rules::WHITE) != flip { 1.0 } else { -1.0 };
    return float3 { sign * local.x, mesh::TABLE_TOP + spot.z * height, local.y };
}

// Adds what each side has taken to s, on the table: its pieces as instances (as
// view3d::build_scene's), and each piece over the table as a disc for the table's shadow
// (Scene.discs). A capture's pieces are carried from their squares to their places
// (board::carried), an undone one's back, rising ARC on the way.
fn lay(s: view3d::Scene&, b: board::Board&, l: board::Layout, now: f64) {
    let v .= rules::VARIANTS[b.variant];
    let u = view3d::unit(l.n);
    let r = mesh::RADIUS * u;
    let height = mesh::HEIGHT * u;
    var t = board::taken(b);
    let carry = board::carried(b, now);
    let mv .= b.move;
    let mover = b.before.side as i64;
    let caught = 1 - mover;
    if b.moving && !b.back {
        // Forward the position counted is after the move: its pieces are on their way.
        let m = mv.captured;
        t.kings[caught] -= popcount(m & b.before.kings);
        t.men[caught] -= popcount(m & ~b.before.kings);
    }
    lay_counts(s, t, l.n, l.flip, b.king_look);
    // On the board till its last hop; then carried.
    guard carry > 0.0 else { return; }
    var spots: Spots = [];
    // The carried pieces in the order they were taken, each to the next place of its kind.
    let k = carry * carry * (3.0 - 2.0 * carry);
    let alpha = board::TAKEN + (1.0 - board::TAKEN) * min(carry / 0.35, 1.0);
    var men_n = t.men[caught];
    var kings_n = t.kings[caught];
    for i in mv.path.len - 1 {
        var m = board::between(v, mv.path[i], mv.path[i + 1]) & mv.captured;
        while m != 0 {
            let sq = ctz(m);
            m &= m - 1;
            let king = b.before.kings & rules::bit(sq) != 0;
            let n = if king { kings_n } else { men_n };
            if king { king_spots(table_layout, n + 1, spots); } else { men_spots(table_layout, n + 1, spots); }
            let to = world_spot(table_layout, mover, l.flip, spots[n], r, height);
            let from2 = view3d::to_world(l, board::center(l, v, sq));
            let from = float3 { from2.x, 0.0, from2.y };
            var p = from + (to - from) * k;
            p.y += ARC * sin(PI * k);
            put(s, p, u, caught, king, b.king_look, seed_of(king, mover, n), alpha);
            if king { kings_n++; } else { men_n++; }
        }
    }
}

// The figure's seed of the i-th man or king the side `taker` has taken: past the board's
// pieces' (view3d::build_scene numbers them from 0), apart for each side and kind.
fn seed_of(king: bool, taker: i64, i: i64) -> i64 { 400 + (if king { 40 } else { 0 }) + 64 * taker + i }

// One piece of color c (rules::WHITE..) at foot p, scale u: an instance, two for a
// stacked king, and its disc over the table.
fn put(s: view3d::Scene&, p: float3, u: f32, c: i64, king: bool, look: i64, seed: i64, alpha: f32) {
    guard s.inst.len + 4 <= 2 * view3d::MAX_INSTANCES else { return; }
    let dark: f32 = if c == rules::BLACK { 1.0 } else { 0.0 };
    let height = mesh::HEIGHT * u;
    let fx = float4 { alpha, 0.0, 0.0, 0.0 };
    let none = float4 { 0.0, 0.0, 0.0, 0.0 };
    var top = p.y + height;
    if king && look == board::STACK {
        s.inst.push(float4 { p.x, p.y, p.z, u });
        s.inst.push(float4 { dark, 0.0, 2.0, seed });
        s.inst.push(float4 { p.x, top, p.z, u });
        s.inst.push(float4 { dark, 0.5, 0.0, seed + 0.5 });
        for k in 2 {
            s.state.push(fx);
            s.state.push(none);
        }
        top += height;
    } else {
        s.inst.push(float4 { p.x, p.y, p.z, u });
        s.inst.push(float4 { dark, if king { 1.0 } else { 0.0 }, 0.0, seed });
        s.state.push(fx);
        s.state.push(none);
    }
    if s.discs.len < view3d::MAX_DISCS {
        s.discs.push(float4 { p.x, p.z, p.y - mesh::TABLE_TOP, top - mesh::TABLE_TOP });
    }
}

// Adds t's pieces to s where they lie at rest, on n squares, the board turned (`flip`),
// kings as `king_look` (board::CROWN or STACK); s's discs start over.
fn lay_counts(s: view3d::Scene&, t: panel::Taken, n: i64, flip: bool, king_look: i64) {
    s.discs.clear();
    let u = view3d::unit(n);
    let r = mesh::RADIUS * u;
    let height = mesh::HEIGHT * u;
    s.disc_r = r;
    var spots: Spots = [];
    for taker in 2 {
        let c = 1 - taker;
        men_spots(table_layout, t.men[c], spots);
        for q, i in spots { put(s, world_spot(table_layout, taker, flip, q, r, height), u, c, false, king_look, seed_of(false, taker, i), 1.0); }
        king_spots(table_layout, t.kings[c], spots);
        for q, i in spots { put(s, world_spot(table_layout, taker, flip, q, r, height), u, c, true, king_look, seed_of(true, taker, i), 1.0); }
    }
}
