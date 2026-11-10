// The game's end on screen (rendering.md, "Controls", A win, A draw): the win's cheer on
// the board and its card, the draw's card with why, and the timing of both. Part of the
// game's namespace: game.goose's frame starts them and calls them each frame.
namespace game;
import std;
import math;
import vec;

import rules from "../rules";
import board from "../board";
import gui from "../gui";
import strings from "../../strings";

// A win (rendering.md, "Controls", A win), in seconds since it: the winning piece lifts
// with its ring; a ring of glow passes across the winner's other pieces outward from it,
// each lifting a little with its square lit; the board dims under the winning piece; the
// card slides up as it fades in, and the crowned piece fades in on it. Then it is still.
let LIFT = 0.35;            // the winning piece lifts, easing out
let WAVE_AT = 0.15;         // the glow reaches a piece on the next square then,
let WAVE_STEP = 0.08;       // one a square farther this much later,
let WAVE = 0.6;             // and takes this long to pass it
let DIM_AT = 0.9;           // the board dims to DIM over 0.6 s
let DIM = 0.45;
let CARD_AT = 1.0;          // the card slides up SLIDE dp as it fades in over 0.7 s
let SLIDE = 28.0;
let CROWN_AT = 1.2;         // the crowned piece fades in over 0.5 s
let STILL = 1.7;            // still from here, or once the glow has passed the farthest piece
// A draw (rendering.md, "Controls", A draw), calm: the board dims as the win's does over
// 0.6 s, and the card with both pieces, "Draw", and why slides up as it fades in from
// DRAW_CARD; still from DRAW_STILL. Nothing lifts or glows.
let DRAW_DIM = 0.6;
let DRAW_CARD = 0.1;
let DRAW_STILL = 0.8;

// The celebration's moment at `now`: seconds since the win, or with no winning piece to
// lift (a flag during a move, a position set up already won) from where the board
// dims, so the dim and the card come at once.
fn moment(gm: Game&, now: f64) -> f64 {
    let skip = if gm.won_on < 0 { DIM_AT } else { 0.0 };
    return now - gm.won_at + skip;
}

// The win begins: the winning piece is the last move's, the winner's whichever way the
// game ended (the side that ran out of moves or time was to move after it), unless the
// move is still showing or there was none. The celebration is still once the card is in
// and the glow has passed the winner's farthest piece.
fn aim(gm: Game&, won: i64) {
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    gm.won_on = -1;
    gm.still = STILL;
    gm.stilled = false;
    guard b.has_last && !b.moving && b.pos.pieces[won] & rules::bit(b.last.to) != 0 else { return; }
    gm.won_on = b.last.to;
    var left = b.pos.pieces[won];
    while left != 0 {
        let sq = ctz(left);
        left &= left - 1;
        gm.still = max(gm.still, WAVE_AT + WAVE_STEP * apart(v, sq, gm.won_on) + WAVE);
    }
}

// How many squares apart two squares are, straight across the board.
fn apart(v: rules::Variant&, a: i64, b: i64) -> f64 {
    let dx = v.x_of[a] as f64 - v.x_of[b];
    let dy = v.y_of[a] as f64 - v.y_of[b];
    return sqrt(dx * dx + dy * dy);
}

// Where t is from a to b, 0..1; eased out; up and back down. Eased in and out is
// board::ease.
fn span(t: f64, a: f64, b: f64) -> f64 { clamp((t - a) / (b - a), 0.0, 1.0) }
fn ease_out(x: f64) -> f64 { 1.0 - (1.0 - x) * (1.0 - x) * (1.0 - x) }
fn bump(x: f64) -> f64 { if x <= 0.0 || x >= 1.0 { 0.0 } else { sin(PI * x) } }

// The win on the board, after board::fill (shell::fill): the board dims under the winning
// piece, which lifts with its ring and is drawn last, over the others; the glow passes
// the winner's other pieces, each lifting a little with its ring and its square lit. A
// piece lifts 6% of its size and grows 5%. The pieces are on their squares: the win
// waits for the move to show. `share` scales it all, the dim, the lifts, and the glow,
// as the game screen fades out or in through a transition.
fn cheer(gm: Game&, l: board::Layout, now: f64, share: f32 = 1.0) {
    if gm.drawn_at >= 0.0 {
        let b .= gm.b;
        b.dim = (DIM * board::ease(span(now - gm.drawn_at, 0.0, DRAW_DIM))) as f32 * share;
        for &p in b.pieces { p.win.x = b.dim; }
        return;
    }
    guard gm.won_at >= 0.0 else { return; }
    let b .= gm.b;
    let v .= rules::VARIANTS[b.variant];
    let t = moment(gm, now);
    let won = winner(gm);
    b.dim = (DIM * board::ease(span(t, DIM_AT, DIM_AT + 0.6))) as f32 * share;
    var top = -1;
    for i in b.pieces.len {
        let p .= b.pieces[i];
        p.win.x = b.dim;
        let sq = board::hit(l, v, float2 { p.at.x, p.at.y });
        guard gm.won_on >= 0 && won >= 0 && sq >= 0 && b.pos.pieces[won] & rules::bit(sq) != 0 else { continue; }
        var k = 0.0;
        if sq == gm.won_on {
            k = ease_out(span(t, 0.0, LIFT));
            p.win.x = 0.0;
            top = i;
        } else {
            let at = WAVE_AT + WAVE_STEP * apart(v, sq, gm.won_on);
            k = bump(span(t, at, at + WAVE));
            p.win.y = k as f32;
        }
        let f = k as f32 * share;
        p.win.y *= share;
        let r = p.at.z;
        p.at.z = r * (1.0 + 0.05 * f);
        p.at.w += 0.12 * r * f;
        p.ring.y = max(p.ring.y, f);
        p.win.z = 0.5 * l.inner.w / p.at.z;
    }
    guard top >= 0 else { return; }
    let p = b.pieces[top];
    for i in top..b.pieces.len - 1 { b.pieces[i] = b.pieces[i + 1]; }
    b.pieces[b.pieces.len - 1] = p;
}

// Where the win's card is centered, and which it keeps inside: the flat board, or the 3D
// board's bounds on screen.
fn card_area(pl: panel::Layout) -> float4 {
    let l = pl.board;
    return if pl.three { pl.view.rect } else { float4 { l.board.x, l.board.y, l.board.z, l.board.z } };
}

// The winning piece on screen, its middle and its radius in pixels, for the card to keep
// clear of: on the flat board the disc as board::fill draws it, on the 3D board its top
// as the perspective shows it.
fn winning_spot(gm: Game&, pl: panel::Layout) -> float2, f32 { return spot_of(gm, pl, gm.won_on); }

// The piece on square `sq` on screen, its middle and its radius in pixels.
fn spot_of(gm: Game&, pl: panel::Layout, sq: i64) -> float2, f32 {
    let l = pl.board;
    let at = board::center(l, rules::VARIANTS[gm.b.variant], sq);
    guard pl.three else { return at, 0.39 * l.inner.w; }
    let s = view3d::on_screen(pl.view, l, at);
    return float2 { s.x, s.y }, s.z;
}

// The card over the dimmed board once the pieces have answered: the winner's piece,
// crowned, fading in over restart or back; it slides up as it fades in, its taps where
// it is at rest. On the 3D board it is placed by the board's bounds on screen and the
// winning piece where the perspective shows it. Returns panel::RESTART, panel::BACK, or
// panel::NOTHING.
fn celebrate(gm: Game&, g: gui::Gui&, pl: panel::Layout, won: i64, now: f64, over: board::Overlay&) -> i64 {
    let t = moment(gm, now);
    guard t >= CARD_AT else { return panel::NOTHING; }
    let l = pl.board;
    let u = l.scale;
    let area = card_area(pl);
    // The card: 40 dp above and below, 56 dp at the sides; the piece, a 28 dp gap, the
    // buttons, 112 × 88 dp. On a board under panel::BOARD all but the buttons' height
    // shrink with it, the buttons' width down to 88 dp: 356 × 300 dp, 49% of the
    // tablet's board, comes to 52% of the smallest (the foldable's 520 dp) where it
    // would be 68%.
    let fit: f32 = min(1.0, l.board.z / (panel::BOARD * u));
    let button = max(88.0, 112.0 * fit);
    let first = g.quads.len;
    var card = gui::center(area, (112.0 * fit + 2.0 * button + 20.0 * fit) * u,
                           ((40.0 + 40.0 + 104.0 + 28.0) * fit + 88.0) * u);
    // Centered on the board, unless it would cover the winning piece (a phone's board):
    // then in the half away from it, as near the middle as clears the piece.
    if gm.won_on >= 0 {
        let at, r = winning_spot(gm, pl);
        if at.x + r > card.x && at.x - r < card.x + card.z && at.y + r > card.y && at.y - r < card.y + card.w {
            let middle = area.y + 0.5 * area.w;
            card.y = if at.y >= middle { max(area.y, min(middle, at.y - r) - card.w) }
                     else { min(area.y + area.w - card.w, max(middle, at.y + r)) };
        }
    }
    gui::panel(g, card);
    var c = gui::inset(card, 40.0 * fit * u);
    var spot = gui::cut_top(c, 104.0 * fit * u);
    gui::cut_top(c, 28.0 * fit * u);
    let row = gui::cut_top(c, 88.0 * u);
    var ask = panel::NOTHING;
    let gap = 20.0 * fit * u;
    if gui::button(g, gui::CARD_IDS, gui::cell(row, 2, 1, button * u, 88.0 * u, gap, 0), gui::BACK) { ask = panel::BACK; }
    if gui::tile(g, gui::CARD_IDS + 1, gui::cell(row, 2, 1, button * u, 88.0 * u, gap, 1), gui::RESTART, gui::PRIMARY, 22.0) {
        ask = panel::RESTART;
    }
    let k = ease_out(span(t, CARD_AT, CARD_AT + 0.7));
    let drop = floor((1.0 - k) * SLIDE * u + 0.5) as f32;
    gui::fade(g, first, g.quads.len, k as f32, float2 { 0.0, drop });
    gui::on_board(g, first, g.quads.len);
    spot.y += drop;
    let a = board::ease(span(t, CROWN_AT, STILL)) as f32;
    let n = over.len;
    panel::piece(over, spot, 44.0 * fit * u, won, gm.b.king_look, a, a);
    if over.len > n { over[n].win.w = 1.0; }   // on the board, as the card is
    return ask;
}

// Why the game was drawn, in words, into out.
fn reason(gm: Game&, draw: i64, out: u8[..64]&) {
    let key = match draw {
        rules::DRAW_REPEAT => strings::DRAW_REPEAT,
        rules::DRAW_KINGS => strings::DRAW_KINGS,
        rules::DRAW_BALANCE => strings::DRAW_BALANCE,
        _ => strings::DRAW_LONE,
    };
    strings::fill_in(out, key, [rules::draw_moves(gm.b.pos, draw)]);
}

// The draw's card over the dimmed board (rendering.md, "Controls", A draw): both pieces side
// by side, "Draw", and why, over back and play again, sliding up as it fades in, its
// taps where it is at rest. Sized and placed as the win's card, kept off the piece that
// made the last move; on a board under 540 dp the words say it, and the pieces are left
// out. Returns panel::RESTART, panel::BACK, or panel::NOTHING.
fn settle(gm: Game&, g: gui::Gui&, pl: panel::Layout, draw: i64, now: f64, over: board::Overlay&) -> i64 {
    let t = now - gm.drawn_at;
    guard t >= DRAW_CARD else { return panel::NOTHING; }
    let l = pl.board;
    let u = l.scale;
    let area = card_area(pl);
    let fit: f32 = min(1.0, l.board.z / (panel::BOARD * u));
    let button = max(88.0, 112.0 * fit);
    let pieces = l.board.z >= 540.0 * u;
    let width = (112.0 * fit + 2.0 * button + 20.0 * fit) * u;
    let room = width - 112.0 * fit * u;
    var why: u8[..64] = [];
    reason(gm, draw, why);
    let head .= g.faces[gui::LABEL];
    let small .= g.faces[gui::BODY];
    let line = small.ascent - small.descent;
    let cut = panel::note_break(g, gui::BODY, why, room);
    let lines: f32 = if cut >= 0 { 2.0 } else { 1.0 };
    let say = head.ascent - head.descent + 6.0 * u + lines * line;
    let spot_h: f32 = if pieces { (104.0 + 28.0 - 10.0) * fit * u } else { 0.0 };
    let first = g.quads.len;
    var card = gui::center(area, width, (80.0 + 28.0) * fit * u + spot_h + say + 88.0 * u);
    if gm.b.has_last {
        let at, r = spot_of(gm, pl, gm.b.last.to);
        if at.x + r > card.x && at.x - r < card.x + card.z && at.y + r > card.y && at.y - r < card.y + card.w {
            let middle = area.y + 0.5 * area.w;
            card.y = if at.y >= middle { max(area.y, min(middle, at.y - r) - card.w) }
                     else { min(area.y + area.w - card.w, max(middle, at.y + r)) };
        }
    }
    gui::panel(g, card);
    var c = gui::inset(card, 40.0 * fit * u);
    var spot = float4 { 0.0, 0.0, 0.0, 0.0 };
    if pieces {
        spot = gui::cut_top(c, 104.0 * fit * u);
        gui::cut_top(c, (28.0 - 10.0) * fit * u);
    }
    let words = strings::get(strings::DRAW);
    gui::text(g, gui::LABEL, gui::cut_top(c, head.ascent - head.descent), words, 1.0, 0.0, gui::CENTER);
    gui::cut_top(c, 6.0 * u);
    if cut >= 0 {
        gui::text(g, gui::BODY, gui::cut_top(c, line), why[..cut], 0.66, 0.0, gui::CENTER);
        gui::text(g, gui::BODY, gui::cut_top(c, line), why[cut + 1..], 0.66, 0.0, gui::CENTER);
    } else {
        gui::text(g, gui::BODY, gui::cut_top(c, line), why, 0.66, 0.0, gui::CENTER);
    }
    gui::cut_top(c, 28.0 * fit * u);
    let row = gui::cut_top(c, 88.0 * u);
    var ask = panel::NOTHING;
    let gap = 20.0 * fit * u;
    if gui::button(g, gui::CARD_IDS, gui::cell(row, 2, 1, button * u, 88.0 * u, gap, 0), gui::BACK) { ask = panel::BACK; }
    if gui::tile(g, gui::CARD_IDS + 1, gui::cell(row, 2, 1, button * u, 88.0 * u, gap, 1), gui::RESTART, gui::PRIMARY, 22.0) {
        ask = panel::RESTART;
    }
    let k = ease_out(span(t, DRAW_CARD, DRAW_STILL));
    let drop = floor((1.0 - k) * SLIDE * u + 0.5) as f32;
    gui::fade(g, first, g.quads.len, k as f32, float2 { 0.0, drop });
    gui::on_board(g, first, g.quads.len);
    guard pieces else { return ask; }
    spot.y += drop;
    let n = over.len;
    panel::pair(over, spot, 44.0 * fit * u, 4.0 * fit * u, k as f32);
    for i in n..over.len { over[i].win.w = 1.0; }   // on the board, as the card is
    return ask;
}
