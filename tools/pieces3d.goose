// What tools/board_shot.goose and tools/piece_tune.goose share: the 3D reference's
// position on the GPU, a season's look put on as the app puts it, and the pieces' values
// (task 094) that both override: the scattering, the wear, the colors and roughness, and
// the figure, read from flags or a panel and written into the frame's block over the
// look's, which the shaders read at the next draw with nothing baked again.
namespace pieces3d;
import std;
import vec;
import math;
import gfx;

// The position: the 3D reference's, dark pieces on the far rows and light on the near,
// one light king (a stack of two discs), one light piece selected. Each piece is (row,
// col, dark, king, selected); row 0 is the far side, and pieces stand on the dark squares.
let PIECES: i32[5][23] = [
    [0, 1, 1, 0, 0], [0, 3, 1, 0, 0], [0, 5, 1, 0, 0], [0, 7, 1, 0, 0],
    [1, 0, 1, 0, 0], [1, 2, 1, 0, 0], [1, 4, 1, 0, 0], [1, 6, 1, 0, 0],
    [2, 1, 1, 0, 0], [2, 3, 1, 0, 0], [2, 5, 1, 0, 0], [2, 7, 1, 0, 0],
    [3, 2, 1, 0, 0], [3, 6, 1, 0, 0],
    [5, 0, 0, 0, 0], [5, 6, 0, 0, 0],
    [6, 1, 0, 0, 0], [6, 3, 0, 0, 0], [6, 5, 0, 0, 1],
    [7, 0, 0, 0, 0], [7, 2, 0, 0, 0], [7, 4, 0, 1, 0], [7, 6, 0, 0, 0],
];

// Puts the position on the GPU: the instances (two float4s each: foot and scale; dark,
// 0.5 a stack's upper disc, 1 selected or 2 a stack's lower disc, seed), the squares the
// field's occlusion reads (top, foot, radius, occupied; then the piece's middle), no
// marks, and where the selected piece stands.
fn place(r3d: render3d::Own&, g: render3d::Gpu&) {
    var inst:    float4[..64] = [];
    var squares: float4[200]  = [float4_0; 200];
    var marks:   float4[100]  = [float4 { 0.0, 0.0, 0.0, -1.0 }; 100];
    var lit:     float4[100]  = [float4_0; 100];
    var fades:   f32[1]       = [0.0];
    var selected = float4_0;
    for p, i in PIECES {
        let x = p[1] as f32 - 3.5;
        let z = p[0] as f32 - 3.5;
        let dark: f32 = if p[2] == 1 { 1.0 } else { 0.0 };
        let sel = p[4] == 1;
        let lift:  f32 = if sel { view3d::LIFT } else { 0.0 };
        let scale: f32 = if sel { view3d::GROW } else { 1.0 };
        let seed = i as f32;
        var top = lift + view3d::HEIGHT * scale;
        if p[3] == 1 {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, 2.0, seed });
            inst.push(float4 { x, top, z, scale });
            inst.push(float4 { dark, 0.5, 0.0, seed + 0.5 });
            top += view3d::HEIGHT * scale;
        } else {
            inst.push(float4 { x, lift, z, scale });
            inst.push(float4 { dark, 0.0, if sel { 1.0 } else { 0.0 }, seed });
        }
        squares[2 * (p[0] * 8 + p[1])] = float4 { top, lift, view3d::RADIUS * scale, 1.0 };
        squares[2 * (p[0] * 8 + p[1]) + 1] = float4 { x, z, 0.0, 0.0 };
        if sel { selected = float4 { x, lift, z, view3d::RADIUS * scale }; }
    }
    render3d::place(r3d, g, inst[..inst.len], fades[..0], squares[..], marks[..], lit[..], selected, 0.0, true);
}

// Puts on the look the raised board shows in `season` made of `material`, as
// draw3d::choose_look does: spring's birch is spring's look 0 to the renderer, and each
// look takes its own wood's model and that model's finish. Returns the look shown, whose
// theme holds the pieces' values.
fn put_look(r3d: render3d::Own&, g: render3d::Gpu&, season: i64, material: i64) -> i64 {
    let look = looks::of(season, material);
    g.spring = if look == looks::SPRING { 0 } else { looks::SPRING_LOOK };
    let shown = looks::shown(look, g.spring);
    let own = looks::wood_for(shown);
    render3d::choose(g, if own >= 0 { own } else { model3d::WOOD_MODEL }, -1);
    g.finish = looks::finish_for(shown, g.wood);
    render3d::apply(r3d, g, look, 8);
    return shown;
}

// The pieces' values of a look (looks::Theme's fields of the same names, sRGB).
struct Pieces {
    mineral: f32,
    light_piece:   float4,
    dark_piece:    float4,
    piece_fig:     float4,
    light_scatter: float4,
    dark_scatter:  float4,
    piece_wear:    float4,
}

fn of_look(shown: i64) -> Pieces {
    let t = looks::get(shown);
    return Pieces { mineral: t.mineral, light_piece: t.light_piece, dark_piece: t.dark_piece, piece_fig: t.piece_fig,
                    light_scatter: t.light_scatter, dark_scatter: t.dark_scatter, piece_wear: t.piece_wear };
}

// Profiles: sets of the pieces' values kept beside a look's own (profile 0), to compare
// and return to while tuning; the one chosen goes into looks.goose. How many a look has,
// its own counted.
fn profiles(shown: i64) -> i64 {
    if shown == looks::AUTUMN || shown == looks::SPRING_STONE || shown == looks::SPRING_ELVEN { return 2; }
    return 1;
}

// Profile k of the look shown (0 its own values, of_look).
fn profile(shown: i64, k: i64) -> Pieces {
    var p = of_look(shown);
    if (shown == looks::SPRING_STONE || shown == looks::SPRING_ELVEN) && k == 1 {
        p.mineral = 0.0;
        p.light_piece = float4 { 0.86, 0.81, 0.72, 0.42 };
        p.dark_piece = float4 { 0.37, 0.41, 0.26, 0.28 };
        p.light_scatter = looks::IVORY_SCATTER;
        p.light_scatter.w = 0.0;
        p.dark_scatter.w = 0.0;
        p.piece_wear = float4_0;
        p.piece_fig = float4 { 0.04, 0.25, 0.0, 0.55 };
    }
    if shown == looks::AUTUMN && k == 1 {
        // Autumn 1 (2026-11-17): a smoother cream, the dark walnut scattering strongly.
        p.light_piece = float4 { 0.97, 0.89, 0.76, 0.249 };
        p.dark_piece = float4 { 0.34, 0.235, 0.2, 0.36 };
        p.piece_fig = float4 { 0.04, 0.18, 0.3, 0.35 };
        p.light_scatter = float4 { 1.0, 0.7, 0.45, 0.565 };
        p.dark_scatter = float4 { 0.9, 0.45, 0.25, 1.25 };
        p.piece_wear = float4 { 0.3, 0.5, 0.04, 0.0 };
    }
    return p;
}

// The values with no scattering and no wear: the pieces as they were before task 094.
fn before(p: Pieces) -> Pieces {
    var b = p;
    b.light_scatter.w = 0.0;
    b.dark_scatter.w = 0.0;
    b.piece_wear = float4_0;
    return b;
}

// Writes the values into the frame's block as render3d::theme_end does, colors linear;
// the next draw shows them.
fn put(g: render3d::Gpu&, p: Pieces) {
    let f .= g.frame;
    f.frame_map.y = p.mineral;
    f.light_piece = model3d::linear4(p.light_piece);
    f.dark_piece = model3d::linear4(p.dark_piece);
    f.piece_fig = p.piece_fig;
    f.light_scatter = model3d::linear4(p.light_scatter);
    f.dark_scatter = model3d::linear4(p.dark_scatter);
    f.piece_wear = p.piece_wear;
}

// The camera at the rest angle (view3d's), turned `yaw` degrees round the board and
// `pitch` degrees more down, `near` times as far: its view and projection, and its eye.
fn camera(size: int2, yaw: f32 = 0.0, pitch: f32 = 0.0, near: f32 = 1.0) -> gfx::mat4, float3 {
    let a = (view3d::PITCH + pitch) * PI / 180.0;
    let b = yaw * PI / 180.0;
    let eye = view3d::TARGET + float3 { cos(a) * sin(b), sin(a), cos(a) * cos(b) } * (view3d::DISTANCE * near);
    let proj = gfx::perspective(view3d::FOV * PI / 180.0, size.x as f32 / size.y, view3d::NEAR, view3d::FAR);
    return gfx::mul(proj, gfx::look_at(eye, view3d::TARGET, float3 { 0.0, 1.0, 0.0 })), eye;
}

// Reads the flags over `p`: --profile K (profile(shown, K)) first, then --light-scatter and --dark-scatter R,G,B,S (the tint sRGB and
// the strength), --light and --dark R,G,B,ROUGH, --figure and --wear as four or three
// numbers, each overriding as many of the float4's components as it lists; --before
// drops the scattering and the wear.
fn read_flags(argv: u8[:][>..]&, p: Pieces&, shown: i64) {
    for a, i in argv {
        guard a == "--profile" && i + 1 < argv.len else { continue; }
        let k, ok = parse_int(argv[i + 1]);
        guard ok && k >= 0 && k < profiles(shown) else { abort(str("--profile: 0 to ", profiles(shown) - 1)); }
        p = profile(shown, k);
    }
    for a, i in argv {
        guard i + 1 < argv.len || a == "--before" else { continue; }
        if a == "--light-scatter" { p.light_scatter = numbers(argv[i + 1], p.light_scatter); }
        if a == "--dark-scatter" { p.dark_scatter = numbers(argv[i + 1], p.dark_scatter); }
        if a == "--light" { p.light_piece = numbers(argv[i + 1], p.light_piece); }
        if a == "--dark" { p.dark_piece = numbers(argv[i + 1], p.dark_piece); }
        if a == "--figure" { p.piece_fig = numbers(argv[i + 1], p.piece_fig); }
        if a == "--wear" { p.piece_wear = numbers(argv[i + 1], p.piece_wear); }
        if a == "--before" { p = before(p); }
    }
}

// Up to four comma-separated numbers over `v`'s components, in order.
fn numbers(text: const u8[:], v: float4) -> float4 {
    var c:    f32[4]      = [v.x, v.y, v.z, v.w];
    var rest: const u8[:] = text;
    for k in 4 {
        guard rest.len > 0 else { break; }
        let head, after, more = split_once(rest, ",");
        let x, ok = parse_flt(trim(head));
        guard ok else { abort(str("not a number: ", head)); }
        c[k] = x as f32;
        rest = if more { after } else { "" };
    }
    return float4 { c[0], c[1], c[2], c[3] };
}

// x with up to three decimals, at least one.
fn num(out: u8[>..]&, x: f32) {
    let v = (abs(x) * 1000.0 + 0.5) as i64;
    if x < 0.0 && v > 0 { out.push('-'); }
    format(out, v / 1000);
    out.push('.');
    let f = v % 1000;
    out.push(('0' + f / 100) as u8);
    if f % 100 != 0 { out.push(('0' + f / 10 % 10) as u8); }
    if f % 10 != 0 { out.push(('0' + f % 10) as u8); }
}

fn line4(out: u8[>..]&, name: const u8[:], v: float4) {
    format(out, "    t.", name, " = float4 { ");
    num(out, v.x);
    out.append(", ");
    num(out, v.y);
    out.append(", ");
    num(out, v.z);
    out.append(", ");
    num(out, v.w);
    out.append(" };\n");
}

// The values as Goose lines for the look's function in looks.goose, and as the flags
// that give them to board_shot.
fn print_values(p: Pieces, shown: i64) {
    var a: u8[>..] = [];
    format(a, "// look ", shown, "\n");
    line4(a, "light_piece", p.light_piece);
    line4(a, "dark_piece", p.dark_piece);
    line4(a, "piece_fig", p.piece_fig);
    line4(a, "light_scatter", p.light_scatter);
    line4(a, "dark_scatter", p.dark_scatter);
    line4(a, "piece_wear", p.piece_wear);
    a.append("// board_shot");
    flag4(a, "--light", p.light_piece);
    flag4(a, "--dark", p.dark_piece);
    flag4(a, "--figure", p.piece_fig);
    flag4(a, "--light-scatter", p.light_scatter);
    flag4(a, "--dark-scatter", p.dark_scatter);
    flag4(a, "--wear", p.piece_wear);
    print(a);
}

fn flag4(out: u8[>..]&, name: const u8[:], v: float4) {
    format(out, " ", name, " ");
    num(out, v.x);
    out.push(',');
    num(out, v.y);
    out.push(',');
    num(out, v.z);
    out.push(',');
    num(out, v.w);
}
