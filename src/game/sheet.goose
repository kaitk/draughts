// The moves where the moves panel has no room, and the marks explained (task 078,
// prototypes/history.html's take d and its B; docs/architecture/rendering.md, "The moves
// panel"). On a phone the moves' line (panel::Layout.line): in landscape a tile at the
// left column's foot with the last moves' rows, in portrait the last move in the bar
// between what each side has taken; its tap opens the moves' sheet, every move two a row,
// each side's accuracy and the marks' legend at its foot. On the always-shown panel (a
// tablet's, a desktop's) a marked move explains itself in a tip, under the mouse or on a
// touch. Nothing allocates: words go through fixed buffers.
namespace game;
import std;
import vec;

let LINE_ID = gui::PANEL_IDS + 6;       // the moves' line, which opens the sheet
let SHEET_HEAD = gui::PANEL_IDS + 7;    // the sheet's head, which closes it,
let SHEET_DIM = gui::PANEL_IDS + 8;     // and the dim layer over the screen above it (portrait)
let SHEET_LIST = gui::PANEL_IDS + 9;    // its list's id (gui::scroll_begin)
let LINE_ROW = 31.0;        // dp a row in the landscape line
let LINE_NUMBER = 26.0;     // dp its numbers take
let LINE_CHEVRON = 20.0;    // dp: the line's chevron, in its top right corner
let LINE_OLDER: f32 = 0.6;  // the line's rows before the last, faded
let SHADE:      f32 = 0.38;   // the dim layer's black over what the portrait sheet leaves
let SHEET_R = 28.0;         // dp: the sheet's corners where it ends on the screen
let FOOT_H = 44.0;          // dp: the sheet's foot, each side's accuracy under a rule
let LEGEND_ROW = 24.0;      // dp: a line of the legend, two marks to it,
let LEGEND_TOP = 8.0;       // under a rule this far above it
let LEGEND_GLYPH = 26.0;    // dp a mark takes before its word

// Where a marked move showed in the moves panel (moves_list), for its tip: its words and
// its mark, and the note's index.
struct MarkAt {
    rect: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    ply:  i64    = -1,
}
let MAX_MARKS_AT = 64;

// The legend's marks, in its order.
let LEGEND: u8[4] = [ai::BEST, ai::INACCURACY, ai::MISTAKE, ai::BLUNDER];
let LEGEND_GAP = 18.0;      // dp after a mark's word where all four share a line

// Whether the legend's four marks and their words fit one line w pixels wide.
fn legend_one(g: gui::Gui&, w: f32) -> bool {
    let u = g.scale;
    var need: f32 = 0.0;
    for m in LEGEND { need += (LEGEND_GLYPH + LEGEND_GAP) * u + gui::text_width(g, gui::SMALL, legend_word(m)); }
    return need <= w;
}

fn legend_word(m: u8) -> const u8[:] { strings::get(strings::MARK_ONLY + 2 * (m as i64 - ai::ONLY)) }

// The legend's height in pixels in a room w pixels wide (legend): one line where its
// four marks fit it, else two.
fn legend_h(g: gui::Gui&, w: f32) -> f32 {
    let lines: f32 = if legend_one(g, w) { 1.0 } else { 2.0 };
    return (LEGEND_TOP + lines * LEGEND_ROW + (lines - 1.0) * 4.0 + 4.0) * g.scale;
}

// The marks explained (task 078's B, the user's choice of both): the best's star, ?!, ?,
// and ?? each with its word (strings::MARK_BEST..), dim, under a rule at the top of r, all
// four on one line where they fit r's width, else two to a line; legend_h(g, r.z) pixels
// tall. The moves' sheet has it at its foot, a past game's replay under its list.
fn legend(g: gui::Gui&, r: float4) {
    let u = g.scale;
    gui::fill(g, float4 { r.x, r.y, r.z, max(1.0, u) }, float4 { 1.0, 1.0, 1.0, 0.12 }, 0.0);
    let one = legend_one(g, r.z);
    let half = 0.5 * r.z;
    var x = r.x;
    for m, i in LEGEND {
        let word = legend_word(m);
        let ww = gui::text_width(g, gui::SMALL, word);
        let cell = if one { float4 { x, r.y + LEGEND_TOP * u, (LEGEND_GLYPH + LEGEND_GAP) * u + ww, LEGEND_ROW * u } }
                   else { float4 { r.x + (i % 2) * half, r.y + (LEGEND_TOP + (i / 2) * (LEGEND_ROW + 4.0)) * u, half, LEGEND_ROW * u } };
        mark_at(g, cell.x + 2.0 * u, cell, m, 0.9);
        let room = float4 { cell.x + LEGEND_GLYPH * u, cell.y, cell.z - (LEGEND_GLYPH + 6.0) * u, cell.w };
        gui::text(g, gui::SMALL, room, word, 0.7, 0.0, gui::LEFT);
        x += cell.z;
    }
}

// The sheet's foot in r: a rule, then each side's piece and its accuracy over its judged
// moves ("84%"), or a dash while none is judged.
fn moves_foot(gm: Game&, g: gui::Gui&, r: float4, over: board::Overlay&) {
    let u = g.scale;
    gui::fill(g, float4 { r.x, r.y + 4.0 * u, r.z, max(1.0, u) }, float4 { 1.0, 1.0, 1.0, 0.12 }, 0.0);
    let t = tally(gm.notes);
    let row = float4 { r.x, r.y + 8.0 * u, r.z, r.w - 8.0 * u };
    let d = 20.0 * u;
    var x = row.x + 4.0 * u;
    var s: Line = [];
    for side in 2 {
        panel::piece(over, float4 { x, row.y + 0.5 * (row.w - d), d, d }, 0.5 * d, side, 0, 1.0, 0.0);
        x += d + 8.0 * u;
        s.clear();
        if t.accuracy[side] >= 0 {
            push_number(s, t.accuracy[side]);
            s.push('%');
        } else {
            s.push('-');
        }
        let w = gui::text_width(g, gui::BODY, s[..]);
        gui::text(g, gui::BODY, float4 { x, row.y, w, row.w }, s[..], 1.0, 0.0, gui::LEFT);
        x += w + 28.0 * u;
    }
}

// The moves' line where the layout has one and the setting shows the moves; true when
// tapped, which opens the sheet. A tile (landscape), or a bare tap round a pill (the
// portrait bar). Offered to the keys with the way out.
fn moves_line(gm: Game&, g: gui::Gui&, l: panel::Layout, over: board::Overlay&) -> bool {
    guard l.line_as != panel::LINE_NONE && gm.moves_shown != 0 else { return false; }
    let u = g.scale;
    gui::group(g, panel::GROUP_OUT);
    let clicked, p = gui::hold(g, LINE_ID, l.line_tap);
    if l.line_as == panel::LINE_BAR {
        gui::add(g, gui::Quad { rect: l.line_tap, look: float4 { gui::BUTTON, 22.0 * u, 0.0, p },
                                extra: float4 { u, gui::ROW, gui::hover(g, LINE_ID), 0.0 } });
        bar_line(gm, g, l);
        return clicked;
    }
    gui::add(g, gui::Quad { rect: l.line, look: float4 { gui::BUTTON, 22.0 * u, 0.0, p },
                            extra: float4 { u, gui::PLAIN, gui::hover(g, LINE_ID), 0.0 } });
    rows_line(gm, g, l, over);
    return clicked;
}

// The landscape line's inside: the last rows of the moves as the sheet lists them, the
// newest at its foot, the earlier faded, the last move lit; a chevron in its top right
// corner; and where the layout has no room for what each side has taken, its counts at
// the head.
fn rows_line(gm: Game&, g: gui::Gui&, l: panel::Layout, over: board::Overlay&) {
    let u = g.scale;
    let r = l.line;
    let k = LINE_CHEVRON * u;
    gui::glyph_icon(g, float4 { r.x + r.z - 8.0 * u - k, r.y + 8.0 * u, k, k }, gui::FWD, gui::PLAIN, 0.0, 0.8);
    var inner = float4 { r.x + 12.0 * u, r.y + 8.0 * u, r.z - 24.0 * u, r.w - 16.0 * u };
    if l.counts {
        let head = gui::cut_top(inner, 26.0 * u);
        let d = 18.0 * u;
        let w = panel::count_at(g, over, gm.taken, rules::BLACK, head, d, false);
        panel::count_at(g, over, gm.taken, rules::WHITE, float4 { head.x + w + 14.0 * u, head.y, head.z - w - 14.0 * u, head.w },
                        d, false);
    }
    let ns .= gm.notes;
    guard ns.len > 0 else {
        let none = strings::get(strings::MOVES_NONE);
        let room = float4 { inner.x, inner.y + inner.w - LINE_ROW * u, inner.z - k, LINE_ROW * u };
        gui::text(g, gui::fitting(g, gui::BODY, none, room.z), room, none, 0.55, 0.0, gui::LEFT);
        return;
    }
    let v .= rules::VARIANTS[gm.b.variant];
    let marks = gm.moves_shown == 2;
    let off = first_ply(gm) % 2;
    let first_number = first_ply(gm) / 2 + 1;
    let rows = (ns.len + off + 1) / 2;
    let fit = max(1, (inner.w / (LINE_ROW * u)) as i64);
    let first = max(0, rows - fit);
    let half = 0.5 * (inner.z - LINE_NUMBER * u);
    var y = inner.y + inner.w - (rows - first) * LINE_ROW * u;
    var line: Line = [];
    for row in first..rows {
        let a = if row == rows - 1 { 1.0 } else { LINE_OLDER };
        line.clear();
        push_number(line, first_number + row);
        gui::text(g, gui::SMALL, float4 { inner.x, y, LINE_NUMBER * u, LINE_ROW * u }, line[..], 0.55 * a, 0.0, gui::LEFT);
        for side in 2 {
            let i = 2 * row + side - off;
            guard i >= 0 && i < ns.len else { continue; }
            let n .= ns[i];
            let cell = float4 { inner.x + LINE_NUMBER * u + side * half, y, half, LINE_ROW * u };
            notation(line, v, n.move);
            let w = gui::text_width(g, gui::BODY, line[..]);
            if i == ns.len - 1 {
                gui::glow_fill(g, float4 { cell.x - 5.0 * u, cell.y + 2.0 * u, w + 10.0 * u, cell.w - 4.0 * u }, 0.22, 8.0 * u);
            }
            gui::text(g, gui::BODY, cell, line[..], a, 0.0, gui::LEFT);
            if marks { mark_at(g, cell.x + w + MARK_GAP * u, cell, n.mark, a); }
        }
        y += LINE_ROW * u;
    }
}

// The portrait line's pill, centered in l.line, as wide as it holds: the last move's
// number ("23." for white's, "23…" for black's), the move, its mark where marks show, and
// a chevron up, down while the sheet is open; before the first move, the words saying so.
fn bar_line(gm: Game&, g: gui::Gui&, l: panel::Layout) {
    let u = g.scale;
    let ns .= gm.notes;
    let k = 24.0 * u;
    let edge = 14.0 * u;
    let marks = gm.moves_shown == 2;
    var number: Line = [];
    var move:   Line = [];
    var mark:   u8   = 0;
    if ns.len > 0 {
        let n, black = row_of(gm, ns.len - 1);
        push_number(number, n);
        if black {
            number.push(0xE2);
            number.push(0x80);
            number.push(0xA6);
        } else {
            number.push('.');
        }
        notation(move, rules::VARIANTS[gm.b.variant], ns[ns.len - 1].move);
        if marks { mark = ns[ns.len - 1].mark; }
    }
    let none = strings::get(strings::MOVES_NONE);
    let face = if ns.len > 0 { gui::BODY } else { gui::fitting(g, gui::BODY, none, l.line.z - 2.0 * edge - k - 12.0 * u) };
    let nw = if ns.len > 0 { gui::text_width(g, gui::SMALL, number[..]) + 6.0 * u } else { 0.0 };
    let mw = if ns.len > 0 { gui::text_width(g, gui::BODY, move[..]) } else { gui::text_width(g, face, none) };
    var kw: f32 = 0.0;
    if mark == ai::BEST { kw = 16.0 * u; }
    else if shows_mark(mark) {
        let t, c = mark_text(mark);
        kw = gui::text_width(g, gui::BODY, t);
    }
    let gap = if kw > 0.0 { MARK_GAP * u } else { 0.0 };
    let w = min(l.line.z, edge + nw + mw + gap + kw + 6.0 * u + k + 8.0 * u);
    let pill = gui::center(l.line, w, l.line.w);
    gui::fill(g, pill, float4 { 1.0, 1.0, 1.0, 0.1 }, 14.0 * u);
    var x = pill.x + edge;
    if ns.len > 0 {
        gui::text(g, gui::SMALL, float4 { x, pill.y, nw, pill.w }, number[..], 0.6, 0.0, gui::LEFT);
        x += nw;
        gui::text(g, gui::BODY, float4 { x, pill.y, mw, pill.w }, move[..], 1.0, 0.0, gui::LEFT);
        x += mw + gap;
        if kw > 0.0 { mark_at(g, x, pill, mark); }
    } else {
        gui::text(g, face, float4 { x, pill.y, mw, pill.w }, none, 0.6, 0.0, gui::LEFT);
    }
    let chevron = if gm.sheet { gui::CHEVRON_DOWN } else { gui::CHEVRON_UP };
    gui::glyph_icon(g, float4 { pill.x + pill.z - 8.0 * u - k, pill.y + 0.5 * (pill.w - k), k, k }, chevron, gui::PLAIN, 0.0, 0.8);
}

// The moves' sheet, open: in landscape from the screen's left edge to the board's, the
// board left whole and playable; in portrait from the foot up to the board's middle, a dim
// layer over the screen above it. Its head (a chevron and "Move list") closes it, as does
// the dim layer, or back (close_sheet); under the head every move two a row, the last lit,
// and where marks show each side's accuracy and the legend at its foot. The head is the
// screen's first choice for the keys. True when closed.
fn moves_sheet(gm: Game&, g: gui::Gui&, l: panel::Layout, over: board::Overlay&) -> bool {
    let u = g.scale;
    let bottom = l.line_as == panel::LINE_BAR;
    var closed = false;
    gui::group(g, panel::GROUP_OUT);
    if bottom {
        let above = gui::bleed(g, float4 { l.area.x, l.area.y, l.area.z, l.sheet.y - l.area.y }, l.area);
        let tapped, unused = gui::hold(g, SHEET_DIM, above, false);
        gui::fill(g, above, float4 { 0.0, 0.0, 0.0, SHADE }, 0.0);
        if tapped { closed = true; }
    }
    // Its corners round only where it ends on the screen; the others run off it.
    var glass = gui::bleed(g, l.sheet, l.area);
    let off = SHEET_R * u;
    if bottom { glass.w += off; } else {
        glass.x -= off;
        glass.z += off;
    }
    gui::glass(g, glass, SHEET_R);
    var room = l.sheet_in;
    let head = gui::cut_top(room, gui::tap() * u);
    // Opened by the keys, the focus goes from the line to the head.
    if g.focus == LINE_ID { g.focus = SHEET_HEAD; }
    let clicked, p = gui::hold(g, SHEET_HEAD, head);
    gui::prefer(g, SHEET_HEAD);
    gui::add(g, gui::Quad { rect: head, look: float4 { gui::BUTTON, 22.0 * u, 0.0, p },
                            extra: float4 { u, gui::ROW, gui::hover(g, SHEET_HEAD), 0.0 } });
    let k = 30.0 * u;
    let chevron = if bottom { gui::CHEVRON_DOWN } else { gui::PREV };
    gui::glyph_icon(g, float4 { head.x + 8.0 * u, head.y + 0.5 * (head.w - k), k, k }, chevron, gui::PLAIN, p, 0.85);
    let word = strings::get(strings::SETTINGS_MOVES);
    let wx = head.x + 8.0 * u + k + 12.0 * u;
    gui::text(g, gui::fitting(g, gui::HEADING, word, head.x + head.z - wx), float4 { wx, head.y, head.x + head.z - wx, head.w },
              word, 1.0, 0.0, gui::LEFT);
    if clicked { closed = true; }
    if gm.moves_shown == 2 {
        legend(g, gui::cut_bottom(room, legend_h(g, room.z)));
        moves_foot(gm, g, gui::cut_bottom(room, FOOT_H * u), over);
    }
    moves_list(gm, g, room, SHEET_LIST, false);
    return closed;
}

// Back (Android's, Escape) on the game screen: closes the moves' sheet, or a mark's tip a
// touch opened, before it leaves the screen. True when it closed one.
fn close_sheet(gm: Game&) -> bool {
    guard gm.sheet || (gm.tip >= 0 && !gm.tip_hover) else { return false; }
    gm.sheet = false;
    gm.tip = -1;
    return true;
}

// The pieces over the UI as the portrait sheet leaves them: those under its top `top`
// gone, as it covers them; those above it kept whole, as pieces over the UI draw over the
// dim layer too, and faded they showed the pieces they overlap through them.
fn dim_under(over: board::Overlay&, top: f32) {
    var k = 0;
    for i in over.len {
        let p = over[i];
        guard p.at.y < top else { continue; }
        over[k] = p;
        k += 1;
    }
    while over.len > k { over.pop(); }
}

// The pieces over the UI that a tip in r covers, gone.
fn clear_under(over: board::Overlay&, r: float4) {
    var k = 0;
    for i in over.len {
        let p = over[i];
        let d = p.at.z;
        guard p.at.x + d <= r.x || p.at.x - d >= r.x + r.z || p.at.y + d <= r.y || p.at.y - d >= r.y + r.w else { continue; }
        over[k] = p;
        k += 1;
    }
    while over.len > k { over.pop(); }
}

// The marked move under p as the moves panel last showed it, or -1.
fn mark_under(gm: Game&, p: float2) -> i64 {
    for m in gm.marks_at { if gui::inside(m.rect, p) { return m.ply; } }
    return -1;
}

// A mark's tip, before anything else this frame takes the pointer (task 078's B,
// prototypes/history.html's `explain=pop`): on the moves panel, where marks show. Under the
// mouse (a desktop) it shows while the pointer is on a marked move. On a touch, a tap on a
// marked move shows it; the next tap anywhere only closes it, going no further, unless it
// is on another marked move, which the tip moves to. Returns whether the tip changed.
fn tips(gm: Game&, g: gui::Gui&, l: panel::Layout) -> bool {
    let was = gm.tip;
    guard l.moves.z > 0.0 && gm.moves_shown == 2 && l.line_as == panel::LINE_NONE else {
        gm.tip = -1;
        gm.tip_press = -1;
        gm.tip_took = false;
        return was >= 0;
    }
    let i = g.input;
    if gui::desktop_scale > 0.0 {
        let at = mark_under(gm, i.at);
        if at >= 0 {
            gm.tip = at;
            gm.tip_hover = true;
        } else if gm.tip_hover {
            gm.tip = -1;
        }
        return gm.tip != was;
    }
    if i.pressed {
        gm.tip_press = mark_under(gm, i.at);
        gm.tip_took = gm.tip >= 0;
        if gm.tip_took {
            g.input.pressed = false;
            g.pointer.pressed = false;
            g.took = true;
        }
    }
    if i.released {
        let at = mark_under(gm, i.at);
        let same = at >= 0 && at == gm.tip_press;
        if gm.tip_took {
            gm.tip = if same && at != gm.tip { at } else { -1 };
        } else if same && !g.scroll.dragging {
            gm.tip = at;
        }
        gm.tip_hover = false;
        gm.tip_press = -1;
        gm.tip_took = false;
    }
    return gm.tip != was;
}

// The tip, over the marked move it explains as the panel showed it this frame (above it,
// or under it where the safe area's top is too near): the mark in its colored disc, its
// name (the tip's words before their colon), the move ("20. 33-29"), and the tip's line
// (strings::MARK_*_TIP) under them, wrapped. Pieces over the UI under it go. Returns
// whether it went, its move no longer in view.
let TIP_W = 320.0;
let TIP_PAD = 14.0;
let TIP_DISC = 46.0;
fn tip(gm: Game&, g: gui::Gui&, l: panel::Layout, over: board::Overlay&) -> bool {
    guard gm.tip >= 0 else { return false; }
    var at = float4 { 0.0, 0.0, 0.0, 0.0 };
    for m in gm.marks_at { if m.ply == gm.tip { at = m.rect; } }
    guard at.z > 0.0 && gm.tip < gm.notes.len && shows_mark(gm.notes[gm.tip].mark) else {
        gm.tip = -1;
        return true;
    }
    let u = g.scale;
    let n .= gm.notes[gm.tip];
    let a = l.area;
    let tw = min(TIP_W * u, a.z - 24.0 * u);
    // The name, and the line with its first letter a capital.
    let s = strings::get(strings::MARK_ONLY_TIP + 2 * (n.mark as i64 - ai::ONLY));
    var cut = -1;
    for c, i in s { if c == ':' && cut < 0 { cut = i; } }
    let name = if cut >= 0 { s[..cut] } else { s };
    var said: u8[..160] = [];
    if cut >= 0 { said.append(trim(s[cut + 1..])); }
    if said.len > 0 && said[0] >= 'a' && said[0] <= 'z' { said[0] = said[0] - 32; }
    // Broken greedily into lines of the words' room, four at most.
    let cw = tw - (3.0 * TIP_PAD + TIP_DISC) * u;
    var starts: i64[4] = [0, 0, 0, 0];
    var ends:   i64[4] = [0, 0, 0, 0];
    var lines = 0;
    var from = 0;
    while from < said.len && lines < 4 {
        var to = said.len;
        if gui::text_width(g, gui::BODY, said[from..said.len]) > cw {
            var best = -1;
            for i in from..said.len {
                guard said[i] == 32 else { continue; }
                if gui::text_width(g, gui::BODY, said[from..i]) <= cw { best = i; } else { break; }
            }
            if best > from { to = best; }
        }
        starts[lines] = from;
        ends[lines] = to;
        lines += 1;
        from = to + 1;
    }
    let title = g.faces[gui::HEADING].ascent - g.faces[gui::HEADING].descent;
    let lh = g.faces[gui::BODY].ascent - g.faces[gui::BODY].descent + 5.0 * u;
    let th = 2.0 * TIP_PAD * u + max(TIP_DISC * u, title + 6.0 * u + lines * lh);
    let x = clamp(at.x + 0.5 * at.z - 0.5 * tw, a.x + 12.0 * u, a.x + a.z - tw - 12.0 * u);
    var y = at.y - th - 10.0 * u;
    if y < a.y + 8.0 * u { y = at.y + at.w + 10.0 * u; }
    let box = float4 { x, y, tw, th };
    gui::glass(g, box, 20.0);
    clear_under(over, box);
    // The mark in its disc: the best's star on faint white, the others' glyphs on their color.
    let disc = float4 { x + TIP_PAD * u, y + TIP_PAD * u, TIP_DISC * u, TIP_DISC * u };
    if n.mark == ai::BEST {
        gui::fill(g, disc, float4 { 1.0, 1.0, 1.0, 0.12 }, 0.5 * disc.z);
        let k = 26.0 * u;
        gui::glyph_icon(g, gui::center(disc, k, k), gui::STAR, gui::PLAIN, 0.0, 1.0);
    } else {
        let t, c = mark_text(n.mark);
        gui::fill(g, disc, c, 0.5 * disc.z);
        let ink = if n.mark == ai::BLUNDER { float4 { 1.0, 1.0, 1.0, 1.0 } } else { float4 { 0.1, 0.07, 0.03, 1.0 } };
        gui::colored(g, gui::HEADING, disc, t, ink, gui::CENTER);
    }
    // The name, the move at the right, and the line under them.
    let wx = disc.x + disc.z + TIP_PAD * u;
    let row = float4 { wx, y + TIP_PAD * u, cw, title };
    var move: Line = [];
    let number, black = row_of(gm, gm.tip);
    push_number(move, number);
    if black {
        move.push(0xE2);
        move.push(0x80);
        move.push(0xA6);
    } else {
        move.push('.');
    }
    move.push(' ');
    var played: Line = [];
    notation(played, rules::VARIANTS[gm.b.variant], n.move);
    move.append(played[..]);
    let mw = gui::text_width(g, gui::SMALL, move[..]);
    gui::text(g, gui::SMALL, row, move[..], 0.66, 0.0, gui::RIGHT);
    gui::text(g, gui::fitting(g, gui::HEADING, name, cw - mw - 10.0 * u), row, name, 1.0, 0.0, gui::LEFT);
    var ly = row.y + title + 6.0 * u;
    for k in lines {
        gui::text(g, gui::BODY, float4 { wx, ly, cw, lh }, said[starts[k]..ends[k]], 1.0, 0.0, gui::LEFT);
        ly += lh;
    }
    return false;
}
