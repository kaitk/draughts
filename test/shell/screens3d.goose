// Every screen with a board on the 3D board (settings::raised, task 015), headless.
// Home's board and settings' preview fitted into the room each gives it: their bounds in
// dp at the tablet's size, a foldable, 4:3, and a 20:9 phone at 540 dp, in both
// orientations, inside the screen, clear of every tile (the column, the player's chip,
// the way out, the choices), and the flat square the board package plays on in their
// middle. A puzzle round it in the corners layout, every tile in the screen, turned for
// black to move; its right move tapped through the perspective (the piece's top, then
// the field), a wrong move's slide back with its fading ghost and flash, and after two
// misses the hint's glow ring round the piece to move, as the 3D scene carries them. A
// win: the board dimmed but the winning piece, and the card inside the 3D board's bounds
// on screen, clear of the winning piece where the perspective shows it. The transitions:
// home to the game and a puzzle's tile to the puzzle move one image, drawn once through
// the larger end's view, the flat layout steady while it moves, a tile crossfading it in.
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

fn whole(x: f32) -> i64 { floor(x + 0.5) as i64 }
fn dp(r: float4, u: f32) -> u8[>..] { str(whole(r.x / u), " ", whole(r.y / u), " ", whole(r.z / u), " x ", whole(r.w / u)) }

fn inside(r: float4, a: float4) -> bool {
    return r.x >= a.x - 0.5 && r.y >= a.y - 0.5 && r.x + r.z <= a.x + a.z + 0.5 && r.y + r.w <= a.y + a.w + 0.5;
}

fn raised(variant: u8) -> shell::Shell {
    var sh = shell::new(variant);
    sh.prefs.board = settings::RAISED;
    shell::apply_prefs(sh);
    return sh;
}

// The tiles the last frame declared that the board's outline comes within `gap` of.
fn touching(sh: shell::Shell&, g: gui::Gui&) -> i64 {
    var n = 0;
    for i in drive::tiles(g) { if view3d::touches(sh.out.view, drive::rect(g, i), 0.0) { n++; } }
    return n;
}

// The screen at `size` (and `short` dp across its shorter side), declared at rest: the
// 3D board's bounds and where they are.
fn screen_at(sh: shell::Shell&, g: gui::Gui&, size: float2, short: f32, what: const u8[:]) {
    gui::short_dp = short;
    drive::size = size;
    g.scale = gui::scale_of(size.x, size.y);
    gui::test_faces(g);
    drive::idle(sh, g, 0.0);
    drive::idle(sh, g, 1.0);
    let u = g.scale;
    let r = sh.out.view.rect;
    let sq = view3d::square(sh.out.view, u);
    let flat_mid = abs(sh.out.layout.board.x + 0.5 * sh.out.layout.board.z - (r.x + 0.5 * r.z)) < 0.5;
    print(what, " ", whole(size.x), " x ", whole(size.y), " at ", whole(short), " dp: raised ", sh.out.raised, ", bounds ",
          dp(r, u), " (", whole(100.0 * r.z / r.w), ":100), on screen ", inside(r, float4 { 0.0, 0.0, size.x, size.y }),
          ", tiles touched ", touching(sh, g), " of ", drive::tiles(g), ", flat square in the middle ",
          flat_mid && abs(sh.out.layout.board.z - sq.board.z) < 0.5, ", drawn as placed ", sh.out.place == r && sh.out.fade == 1.0 && !sh.out.hold);
    gui::short_dp = 800.0;
}

// The flat point of square `name` on the board's world, projected to the screen at height h.
fn on_screen(sh: shell::Shell&, v: rules::Variant&, name: const u8[:], h: f32) -> float2 {
    let c = view3d::to_world(sh.out.layout, board::center(sh.out.layout, v, drive::square(v, name)));
    let q = view3d::project(sh.out.view, float3 { c.x, h, c.y });
    return float2 { q.x, q.y };
}
fn sq_screen(sh: shell::Shell&, v: rules::Variant&, sq: i64, h: f32) -> float2 {
    let c = view3d::to_world(sh.out.layout, board::center(sh.out.layout, v, sq));
    let q = view3d::project(sh.out.view, float3 { c.x, h, c.y });
    return float2 { q.x, q.y };
}

fn main() {
    var g = gui::Gui {};
    gui::test_faces(g);
    strings::use(strings::EN);
    puzzles::load();
    let sizes = [float2 { 1280.0, 800.0 }, float2 { 800.0, 1280.0 }, float2 { 1768.0, 2208.0 }, float2 { 2208.0, 1768.0 },
                 float2 { 1024.0, 768.0 }, float2 { 768.0, 1024.0 }, float2 { 2400.0, 1080.0 }, float2 { 1080.0, 2400.0 }];
    let shorts = [800.0, 800.0, 800.0, 800.0, 800.0, 800.0, 540.0, 540.0];

    // Home's board and settings' preview.
    for s, i in sizes {
        var sh = raised(rules::INTERNATIONAL);
        sh.screen = shell::HOME;
        screen_at(sh, g, s, shorts[i] as f32, "home");
    }
    for s, i in sizes {
        var sh = raised(rules::RUSSIAN);
        sh.screen = shell::SETTINGS;
        screen_at(sh, g, s, shorts[i] as f32, "settings");
    }
    // Flat, nothing of it.
    var flat = shell::new(rules::INTERNATIONAL);
    drive::size = float2 { 1280.0, 800.0 };
    drive::idle(flat, g, 0.0);
    print("flat home: raised ", flat.out.raised);

    // A puzzle: Learn's first, then one with black to move.
    drive::size = float2 { 1280.0, 800.0 };
    g.scale = gui::scale_of(1280.0, 800.0);
    gui::test_faces(g);
    var sh = raised(rules::INTERNATIONAL);
    shell::play_puzzle(sh, 0);
    drive::idle(sh, g, 0.0);
    let u = g.scale;
    var all_in = true;
    for i in drive::tiles(g) { if !inside(drive::rect(g, i), float4 { 0.0, 0.0, 1280.0, 800.0 }) { all_in = false; } }
    print("puzzle: raised ", sh.out.raised, ", bounds ", dp(sh.out.view.rect, u), ", tiles ", drive::tiles(g), " on screen ", all_in,
          ", touched ", touching(sh, g), ", kings drawn as ", sh.puzzle.b.king_look);
    let pl .= sh.puzzle;
    let vr .= rules::VARIANTS[pl.b.variant];
    let un = view3d::unit(sh.out.layout.n);
    let ply, on = puzzle::line_next(pl);
    assert(on);
    var now = 1.0;
    drive::tap(sh, g, sq_screen(sh, vr, ply.from, view3d::HEIGHT * un), now);
    print("  tapped the piece's top on ", drive::name(vr, ply.from), ": selected ", drive::name(vr, pl.b.selected));
    drive::tap(sh, g, sq_screen(sh, vr, ply.to, 0.0), now + 0.1);
    print("  tapped ", drive::name(vr, ply.to), " on the field: moves played ", pl.path.len, ", moving ", pl.b.moving);

    // A wrong move, in the first puzzle with a legal move off its line: played, then slid
    // back.
    var wrong = -1;
    var at = 0;
    while wrong < 0 && at < puzzles::all.list.len {
        shell::play_puzzle(sh, at);
        drive::idle(sh, g, 2.0);
        let right, has = puzzle::line_next(pl);
        for m, k in pl.b.moves {
            if has && m.captured == 0 && (m.from != right.from || m.to != right.to) { wrong = k; break; }
        }
        if wrong < 0 { at++; }
    }
    print("  a wrong move in puzzle ", at, " of ", puzzles::all.list.len);
    if wrong >= 0 {
        let m = pl.b.moves[wrong];
        drive::tap(sh, g, sq_screen(sh, vr, m.from, view3d::HEIGHT * un), 3.0);
        drive::tap(sh, g, sq_screen(sh, vr, m.to, 0.0), 3.1);
        var t = 3.2;
        while t < 6.0 && pl.state != puzzle::PLAYING { drive::idle(sh, g, t); t += 0.05; }
        drive::idle(sh, g, t + 0.1);
        var scene = view3d::Scene {};
        let b .= shell::fill(sh, t + 0.1);
        view3d::fill(scene, b, sh.out.layout, sh.out.view, t + 0.1);
        var fading = 0;
        var i = 0;
        while i < scene.state.len {
            if scene.state[i].x > 0.0 && scene.state[i].x < 1.0 { fading++; }
            i += 2;
        }
        var flash = false;
        for f in scene.field { if f.w >= 0.0 && f.w < 1.0 { flash = true; } }
        print("  wrong move ", drive::name(vr, m.from), "-", drive::name(vr, m.to), " slid back: misses ", pl.misses,
              ", fading instances ", fading, ", flash ", flash);
        // A second miss: the same wrong move again, slid back.
        drive::tap(sh, g, sq_screen(sh, vr, m.from, view3d::HEIGHT * un), t + 0.3);
        drive::tap(sh, g, sq_screen(sh, vr, m.to, 0.0), t + 0.4);
        t += 0.5;
        let until = t + 3.0;
        while t < until && (pl.state != puzzle::PLAYING || pl.b.moving) { drive::idle(sh, g, t); t += 0.05; }
        drive::idle(sh, g, t + 0.1);
        let b2 .= shell::fill(sh, t + 4.0);
        view3d::fill(scene, b2, sh.out.layout, sh.out.view, t + 4.0);
        var glows: u8[>..] = [];
        for k in sh.out.layout.n * sh.out.layout.n { if scene.lit[k].x > 0.0 { format(glows, k / sh.out.layout.n, ".", k % sh.out.layout.n, " "); } }
        print("  misses ", pl.misses, ", hint on ", drive::name(vr, pl.b.glow), ", glow rings in the world's grid at ", glows);
    }

    // A black puzzle turns the board.
    var black = -1;
    for p, k in puzzles::all.list { if p.start.side == rules::BLACK { black = k; break; } }
    if black >= 0 {
        shell::play_puzzle(sh, black);
        drive::idle(sh, g, 10.0);
        print("black to move: turned ", sh.out.layout.flip, ", raised ", sh.out.raised);
    }

    // A win on the 3D board: white takes f4 and the game is won.
    var w = raised(rules::RUSSIAN);
    w.screen = shell::GAME;
    let rv .= rules::VARIANTS[rules::RUSSIAN];
    let p, ok = rules::parse_fen("W:Wa1,e3:Bf4", rules::RUSSIAN);
    assert(ok);
    board::set(w.game.b, p);
    drive::idle(w, g, 0.0);
    let u8x = view3d::unit(8);
    drive::tap(w, g, on_screen(w, rv, "e3", view3d::HEIGHT * u8x), 1.0);
    drive::tap(w, g, on_screen(w, rv, "g5", 0.0), 1.1);
    var t = 1.2;
    while t < 8.0 { drive::idle(w, g, t); t += 0.1; }
    var card = float4 { 1.0e9, 1.0e9, -1.0e9, -1.0e9 };
    for q in g.quads {
        guard q.extra.z >= gui::ON_BOARD else { continue; }
        card = float4 { min(card.x, q.rect.x), min(card.y, q.rect.y), max(card.z, q.rect.x + q.rect.z), max(card.w, q.rect.y + q.rect.w) };
    }
    card = float4 { card.x, card.y, card.z - card.x, card.w - card.y };
    let spot = view3d::on_screen(w.out.view, w.out.layout, board::center(w.out.layout, rv, w.game.won_on));
    let clear = spot.x + spot.z <= card.x || spot.x - spot.z >= card.x + card.z || spot.y + spot.z <= card.y
                || spot.y - spot.z >= card.y + card.w;
    print("won: ", rules::fen(w.game.b.pos), ", winning piece on ", drive::name(rv, w.game.won_on), ", card ", dp(card, u),
          " inside the 3D bounds ", inside(card, w.out.view.rect), ", centered across them ",
          abs(card.x + 0.5 * card.z - (w.out.view.rect.x + 0.5 * w.out.view.rect.z)) < 1.0, ", clear of the winning piece ", clear);
    var ws = view3d::Scene {};
    let wb .= shell::fill(w, t);
    view3d::fill(ws, wb, w.out.layout, w.out.view, t);
    var lit = 0;
    var i = 1;
    while i < ws.inst.len {
        if ws.inst[i].w >= view3d::SEED_LIT { lit++; }
        i += 2;
    }
    print("  dim ", floor(ws.dim * 100.0 + 0.5) / 100.0, ", instances left lit ", lit, " of ", ws.inst.len / 2);

    // Home to the game: the game's view is the larger, the image drawn once through it.
    var tr = raised(rules::INTERNATIONAL);
    tr.screen = shell::HOME;
    drive::idle(tr, g, 0.0);
    let home_rect = tr.out.view.rect;
    shell::go_to(tr, shell::GAME, 1.0);
    var views = 0;
    var steady = true;
    var last_view = view3d::View {};
    var first = tr.out.layout;
    for k in 0..6 {
        let at = 1.0 + 0.05 * k;
        drive::idle(tr, g, at);
        if k == 0 { first = tr.out.layout; }
        if !view3d::same_view(tr.out.view, last_view) { views++; last_view = tr.out.view; }
        if tr.from >= 0 && tr.out.layout != first { steady = false; }
        print("  home to the game ", at, ": raised ", tr.out.raised, ", hold ", tr.out.hold, ", placed ", dp(tr.out.place, u), ", fade ",
              tr.out.fade);
    }
    print("  views drawn through ", views, ", the flat layout steady ", steady, ", at rest placed at the game's bounds ",
          tr.out.place == tr.out.view.rect, ", the game's larger than home's ", tr.out.view.rect.z > home_rect.z);

    // The puzzles' tile to a puzzle: the image fades in as it grows from the tile.
    var pk = raised(rules::INTERNATIONAL);
    pk.screen = shell::PICKER;
    pk.theme = puzzles::LEARN;
    drive::idle(pk, g, 0.0);
    print("picker: raised ", pk.out.raised);
    drive::frame(pk, g, drive::tile(g, 1), true, true, false, 1.0);
    drive::frame(pk, g, drive::tile(g, 1), false, false, true, 1.02);
    for k in 1..6 {
        let at = 1.02 + 0.05 * k;
        drive::idle(pk, g, at);
        print("  tile to the puzzle ", at, ": raised ", pk.out.raised, ", placed ", dp(pk.out.place, u), ", fade ",
              floor(pk.out.fade * 100.0 + 0.5) / 100.0, ", hole as tall as the image ", pk.from < 0 || pk.out.tall == pk.out.place.w);
    }
}
