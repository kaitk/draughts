// Settings' About (prototypes/settings.html?about=tablet): a small row at the list's foot,
// beside the privacy note, opens a glass card over the dimmed settings of what the app is
// built from and draws with, for a bug report: the build, the graphics, and what the 3D
// board uses now. The app fills About (app.goose) as it opens; Copy puts the lines on the
// clipboard (Frame.copy). No setting is here: the renderer is chosen at start and the 3D
// board's are the device's (docs/decisions/rendering.md).
namespace settings;
import std;
import vec;

import gui from "../gui";
import strings from "../../strings";

// What the card shows, filled by the app (app.goose's fill_about) when it opens: the
// version, commit, and its date (build/draughts_version.h; empty in a plain build), the
// system, the renderer ("gfx", "ngfx") and its graphics API, the GPU's name (empty where
// none is known), and the display's refresh rate in Hz (0 where unknown). Then the 3D
// board's: its antialiasing ("4× MSAA"), whether the app lowered it for a slow device, its
// shadow's taps, and its surfaces' side in pixels. The system's battery saver, 1 on, 0
// off, -1 unknown, and whether it caps the display at 60 Hz here (Android). `filled` once the app has filled it:
// till then the card shows only the dimmed screen. `copied` once Copy was tapped since
// it opened.
struct About {
    filled:   bool     = false,
    version:  u8[..24] = [],
    commit:   u8[..40] = [],
    date:     u8[..16] = [],
    system:   u8[..96] = [],
    renderer: u8[..16] = [],
    driver:   u8[..24] = [],
    gpu:      u8[..96] = [],
    refresh:  i64      = 0,
    aa:       u8[..24] = [],
    lowered:  bool     = false,
    taps:     i64      = 0,
    surfaces: i64      = 0,
    saver:    i64      = -1,
    capped:   bool     = false,
    copied:   bool     = false,
}

// The card's lines in order: a group's title (`title`, a strings key), or a line's name
// and value, with a note under it (`note`, a strings key, or -1). The 3D board's group is
// dim while the board is flat, with a note saying so.
struct Line {
    title: i64      = -1,
    name:  i64      = -1,
    value: u8[..96] = [],
    note:  i64      = -1,
    dim:   bool     = false,
}
let MAX_LINES = 16;
let GROUPS = 3;
let BOARD_GROUP = 2;        // the 3D board's, the second column's where there are two

fn add_line(out: Line[..MAX_LINES]&, name: i64, value: const u8[:], note: i64 = -1, dim: bool = false) {
    var l = Line { name: name, note: note, dim: dim, .. };
    l.value.append(value[..min(value.len, 96)]);
    out.push(l);
}

// The lines of `a` with the 3D board's in use or not (s's board), into out.
fn about_lines(s: Settings&, a: About&, out: Line[..MAX_LINES]&) {
    out.resize(0);
    out.push(Line { title: strings::ABOUT_BUILD, .. });
    add_line(out, strings::ABOUT_VERSION, a.version[..]);
    var commit: u8[..96] = [];
    commit.append(a.commit[..]);
    if a.date.len > 0 {
        commit.append(" · ");
        commit.append(a.date[..]);
    }
    if commit.len > 0 { add_line(out, strings::ABOUT_COMMIT, commit[..]); }
    add_line(out, strings::ABOUT_SYSTEM, a.system[..]);
    out.push(Line { title: strings::ABOUT_GRAPHICS, .. });
    add_line(out, strings::ABOUT_RENDERER, a.renderer[..]);
    add_line(out, strings::ABOUT_DRIVER, a.driver[..]);
    if a.gpu.len > 0 { add_line(out, strings::ABOUT_GPU, a.gpu[..]); }
    if a.refresh > 0 {
        var hz: u8[..16] = [];
        format(hz, a.refresh, " Hz");
        add_line(out, strings::ABOUT_DISPLAY, hz[..]);
    }
    if a.saver >= 0 {
        add_line(out, strings::ABOUT_SAVER, strings::get(if a.saver == 1 { strings::ABOUT_ON } else { strings::ABOUT_OFF }),
                 if a.saver == 1 && a.capped { strings::ABOUT_CAPPED } else { -1 });
    }
    let flat = !raised(s);
    out.push(Line { title: strings::ABOUT_BOARD_3D, note: if flat { strings::ABOUT_NOT_IN_USE } else { -1 }, dim: flat, .. });
    add_line(out, strings::ABOUT_ANTIALIASING, a.aa[..], if a.lowered { strings::ABOUT_LOWERED } else { -1 }, flat);
    var taps: u8[..64] = [];
    strings::fill_in(taps, strings::ABOUT_TAPS, [a.taps]);
    add_line(out, strings::ABOUT_SHADOWS, taps[..], -1, flat);
    var side: u8[..32] = [];
    format(side, a.surfaces, " × ", a.surfaces);
    add_line(out, strings::ABOUT_SURFACES, side[..], -1, flat);
}

// The card's lines as text for the clipboard: the heading, then a line each, a group's
// title alone, a name and its value after a colon, a note in brackets.
fn about_text(s: Settings&, a: About&, out: u8[..2048]&) {
    var lines: Line[..MAX_LINES] = [];
    about_lines(s, a, lines);
    out.resize(0);
    out.append(strings::get(strings::APP_NAME));
    out.append(" ");
    out.append(a.version[..]);
    out.append("\n");
    for l in lines {
        if l.title >= 0 {
            out.append("\n");
            out.append(strings::get(l.title));
            if l.note >= 0 {
                out.append(" (");
                out.append(strings::get(l.note));
                out.append(")");
            }
        } else {
            out.append(strings::get(l.name));
            out.append(": ");
            out.append(l.value[..]);
            if l.note >= 0 {
                out.append(" (");
                out.append(strings::get(l.note));
                out.append(")");
            }
        }
        out.append("\n");
    }
}

// The small tiles (the About row, Copy, the card's close), smaller than a tap to look at
// as a rare choice should, but taking a tap round them: SMALL_H dp tall, a word or icon
// with SMALL_IN either side.
let SMALL_H = 40.0;
let SMALL_IN = 12.0;
let SMALL_ICON = 20.0;

// How wide a small tile is with `label` and `note` (a dimmer word after it).
fn small_width(g: gui::Gui&, label: const u8[:], note: const u8[:], icon: i64) -> f32 {
    let u = g.scale;
    var w = 2.0 * SMALL_IN * u;
    if icon != gui::NO_ICON { w += SMALL_ICON * u; }
    if label.len > 0 { w += gui::text_width(g, gui::SMALL, label); }
    if note.len > 0 { w += 6.0 * u + gui::text_width(g, gui::SMALL, note); }
    return max(w, SMALL_H * u);
}

// A small tile in r with `label`, `note` dimmer after it, or an icon; its tap a tap tall
// and wide round it. True when tapped.
fn small_tile(g: gui::Gui&, id: i64, r: float4, label: const u8[:], note: const u8[:], icon: i64) -> bool {
    let u = g.scale;
    let t = gui::tap_size() * u;
    let tap = gui::center(r, max(r.z, t), max(r.w, t));
    let tapped, p = gui::press_widget(g, id, tap);
    gui::add(g, gui::Quad { rect: r, look: float4 { gui::BUTTON, 12.0 * u, 0.0, p },
                            extra: float4 { u, gui::PLAIN, gui::hover(g, id), 0.0 } });
    if icon != gui::NO_ICON {
        let s = SMALL_ICON * u;
        gui::glyph_icon(g, gui::center(r, s, s), icon, gui::PLAIN, p, 1.0);
        return tapped;
    }
    let lw = gui::text_width(g, gui::SMALL, label);
    let nw = if note.len > 0 { 6.0 * u + gui::text_width(g, gui::SMALL, note) } else { 0.0 };
    var c = gui::center(r, lw + nw, r.w);
    gui::text(g, gui::SMALL, gui::cut_left(c, lw), label, 1.0, 0.0, gui::LEFT);
    if note.len > 0 {
        gui::cut_left(c, 6.0 * u);
        gui::text(g, gui::SMALL, c, note, NOTE_A, 0.0, gui::LEFT);
    }
    return tapped;
}

// The About row's width, the word and the version.
fn about_row_width(g: gui::Gui&, a: About&) -> f32 {
    return small_width(g, strings::get(strings::ABOUT_ROW), a.version[..], gui::NO_ICON);
}

// The card's parts, in dp.
let CARD_W = 560.0;         // one column's card at most,
let CARD_W2 = 860.0;        // two columns'
let CARD_PAD = 22.0;        // its sides
let CARD_MARGIN = 16.0;     // round it in the safe area at least
let NAME_GAP = 18.0;        // between a line's name and its value
let COLUMN_GAP = 28.0;
let GROUP_GAP = 14.0;       // above a group's title, but the first
let STEP: f32 = 1.3;        // a line's height, in the small face's lines

// The column's lines from `from` to `to` laid from c's top, names `name_w` wide; drawn when
// `draw`. Returns how tall they are.
fn about_column(g: gui::Gui&, lines: Line[..MAX_LINES]&, from: i64, to: i64, c: float4, name_w: f32, draw: bool) -> f32 {
    let u = g.scale;
    let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    let title_h = g.faces[gui::BODY].ascent - g.faces[gui::BODY].descent;
    var y = c.y;
    for i in from..to {
        let l .= lines[i];
        let a: f32 = if l.dim { 0.45 } else { 1.0 };
        if l.title >= 0 {
            if i > from { y += GROUP_GAP * u; }
            if draw { gui::text(g, gui::BODY, float4 { c.x, y, c.z, title_h }, strings::get(l.title), 0.85, 0.0, gui::LEFT); }
            y += title_h + 0.3 * line;
            if l.note >= 0 {
                y += gui::wrapped(g, gui::SMALL, float4 { c.x, y, c.z, 0.0 }, strings::get(l.note), NOTE_A, gui::LEFT, 1.15, draw);
                y += 0.3 * line;
            }
            continue;
        }
        let v = float4 { c.x + name_w + NAME_GAP * u, y, c.z - name_w - NAME_GAP * u, 0.0 };
        if draw { gui::text(g, gui::SMALL, float4 { c.x, y, name_w, line }, strings::get(l.name), NOTE_A * a, 0.0, gui::LEFT); }
        var h = max(line * STEP, gui::wrapped(g, gui::SMALL, v, l.value[..], a, gui::LEFT, 1.15, draw));
        if l.note >= 0 {
            h += gui::wrapped(g, gui::SMALL, float4 { v.x, v.y + h - 0.2 * line, v.z, 0.0 }, strings::get(l.note), NOTE_A * a,
                              gui::LEFT, 1.15, draw) + 0.1 * line;
        }
        y += h;
    }
    return y - c.y;
}

// The About card over the screen `screen` (the whole window, dimmed), centered in the
// safe area `area`: its heading, the app's name over its version, Copy and close at its
// right; the lines under it, in two columns where one would be taller than the room (a
// phone in landscape), the 3D board's in the second. A tap outside closes it, as does
// back (shell's). Returns BACK when closed, COPY when Copy was tapped, or NOTHING.
let COPY = 1;
fn about_card(s: Settings&, a: About&, g: gui::Gui&, area: float4, screen: float4) -> i64 {
    let u = g.scale;
    gui::rounded_rect(g, screen, float4 { 0.0, 0.0, 0.0, 0.42 }, 0.0);
    let outside, unused_o = gui::press_widget(g, ABOUT_OUTSIDE_ID, screen, false);
    guard a.filled else { return if outside { BACK } else { NOTHING }; }
    var lines: Line[..MAX_LINES] = [];
    about_lines(s, a, lines);
    var name_w: f32 = 0.0;
    for l in lines { if l.name >= 0 { name_w = max(name_w, gui::text_width(g, gui::SMALL, strings::get(l.name))); } }
    // The second column's lines: from the 3D board's title.
    var split = lines.len;
    var group = 0;
    for l, i in lines {
        if l.title >= 0 {
            if group == BOARD_GROUP { split = i; }
            group++;
        }
    }
    let head_h = g.faces[gui::HEADING].ascent - g.faces[gui::HEADING].descent;
    let line = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    let top = max(head_h + line, SMALL_H * u) + GROUP_GAP * u;
    let room = gui::inset(area, CARD_MARGIN * u);
    var w = min(CARD_W * u, room.z);
    let inner = w - 2.0 * CARD_PAD * u;
    var body = about_column(g, lines, 0, lines.len, float4 { 0.0, 0.0, inner, 0.0 }, name_w, false);
    let two = top + body + 2.0 * CARD_PAD * u > room.w && room.z > room.w;
    var col_w = inner;
    if two {
        w = min(CARD_W2 * u, room.z);
        col_w = 0.5 * (w - 2.0 * CARD_PAD * u - COLUMN_GAP * u);
        body = max(about_column(g, lines, 0, split, float4 { 0.0, 0.0, col_w, 0.0 }, name_w, false),
                   about_column(g, lines, split, lines.len, float4 { 0.0, 0.0, col_w, 0.0 }, name_w, false));
    }
    let r = gui::center(area, w, min(top + body + 2.0 * CARD_PAD * u, room.w));
    gui::glass(g, r, 24.0);
    gui::press_widget(g, ABOUT_CARD_ID, r, false);
    var c = gui::inset(r, CARD_PAD * u);
    var head = gui::cut_top(c, top - GROUP_GAP * u);
    gui::cut_top(c, GROUP_GAP * u);
    var ask = NOTHING;
    // Copy, then close at the right end, far enough apart that their taps don't meet: Copy
    // first for the keys' focus.
    let t = gui::tap_size() * u;
    let copy_word = strings::get(if a.copied { strings::ABOUT_COPIED } else { strings::ABOUT_COPY });
    let copy_w = small_width(g, copy_word, "", gui::NO_ICON);
    let close = gui::cut_right(head, SMALL_H * u);
    gui::cut_right(head, max(10.0 * u, 0.5 * (t - SMALL_H * u) + 0.5 * max(0.0, t - copy_w)));
    let copy = gui::cut_right(head, copy_w);
    gui::cut_right(head, 10.0 * u);
    if small_tile(g, ABOUT_COPY_ID, float4 { copy.x, copy.y, copy.z, SMALL_H * u }, copy_word, "", gui::NO_ICON) { ask = COPY; }
    if small_tile(g, ABOUT_CLOSE_ID, float4 { close.x, close.y, close.z, SMALL_H * u }, "", "", gui::CLOSE) { ask = BACK; }
    gui::text(g, gui::HEADING, gui::cut_top(head, head_h), strings::get(strings::APP_NAME), 1.0, 0.0, gui::LEFT);
    var version: u8[..96] = [];
    version.append(a.version[..]);
    if a.commit.len > 0 {
        version.append(" (");
        version.append(a.commit[..]);
        version.append(")");
    }
    gui::text(g, gui::SMALL, gui::cut_top(head, line), version[..], NOTE_A, 0.0, gui::LEFT);
    if two {
        about_column(g, lines, 0, split, float4 { c.x, c.y, col_w, 0.0 }, name_w, true);
        about_column(g, lines, split, lines.len, float4 { c.x + col_w + COLUMN_GAP * u, c.y, col_w, 0.0 }, name_w, true);
    } else {
        about_column(g, lines, 0, lines.len, float4 { c.x, c.y, c.z, 0.0 }, name_w, true);
    }
    if ask == NOTHING && outside { ask = BACK; }
    return ask;
}
