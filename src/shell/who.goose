// Who's playing (prototypes/profiles.html, take a; rendering.md, "Home"): home's face
// beside the wordmark opens a glass card over the dimmed home with a face per player, its
// name under it, the player playing lit with the glow ring, then + while there is room.
// A face switches to that player and closes the card. The pencil puts a badge on each
// face, and a face then opens its sheet; + opens the sheet for a new player.
//
// The sheet: back (to the card), the face and name or "New player", and done; the six
// pictures, those other players have dimmed; the name, a field a tap tall that brings up
// the keyboard; and for a player already there, start again and remove, each a hold of
// 1.5 s (remove only while there is another player). On a phone in landscape the
// pictures stand at the left, three by two, and the name and the holds at the right.
// While the name is typed the card stands at the top of the screen, clear of the
// keyboard.
namespace who;
import std;
import vec;

let CLOSED = 0;
let PICKING = 1;            // who's playing
let SHEET = 2;              // a player's sheet

// What the card asks the shell for.
let NOTHING = gui::ASK_NOTHING;
let CHANGED = gui::ASK_CHANGED; // only the card changed
let SWITCH = 2;             // to the player at the index given
let CREATE = 3;             // a new player with the sheet's picture and name
let SAVE = 4;               // the sheet's picture and name for its player
let AGAIN = 5;              // start the sheet's player again
let REMOVE = 6;             // remove the sheet's player

let HOLD = 1.5;             // seconds start again and remove are held

// The parts, in dp: the head, the name's field, and the holds are gui::TAP tall.
let EDGE = 16.0;            // the card keeps from the safe area's edges
let PAD = 24.0;             // the card's sides; 20 above, 24 below
let GAP = 14.0;             // between the head and the rest
let TILE_GAP = 12.0;        // between the faces
let WIDEST = 900.0;         // the faces' room at most
let PIC_GAP = 10.0;
let TITLE_H = 28.0;         // a dim name over the pictures and over the name
let ROW_GAP = 10.0;

struct Who {
    state:    i64           = CLOSED,
    editing:  bool          = false,    // the pencil: a face opens its sheet
    target:   i64           = -1,       // the player the sheet is for, or -1 for a new one
    picture:  i64           = 0,        // the sheet's picture and name as chosen so far
    name:     players::Name = [],
    typing:   bool          = false,    // the name takes the keyboard's characters
    keyboard: i64           = 0,        // the name's taps, so the app brings the keyboard up again
    first:    bool          = false,    // the first run's sheet, for the one player there is
}

// A fresh install's first run: the sheet for the one player there is, so the child picks
// their badge and perhaps a name; done or back closes it, and home shows.
fn first_run(w: Who&, ps: players::Players&) {
    sheet_for(w, ps, 0);
    w.first = true;
}

// Opens who's playing.
fn open(w: Who&) {
    w.state = PICKING;
    w.first = false;
    w.editing = false;
    w.typing = false;
}

// Android's back: the sheet goes back to the card, the card closes.
fn back(w: Who&) {
    w.typing = false;
    w.state = if w.state == SHEET && !w.first { PICKING } else { CLOSED };
}

// A face's tile on the card: its width in dp, and its height, the face 72% of the
// width over the name.
fn tile_w(area: float4, u: f32) -> f32 { if gui::phone(area, u) { 120.0 } else { 156.0 } }
fn tile_h(area: float4, u: f32) -> f32 { 0.72 * tile_w(area, u) + 58.0 }

// The faces' tiles: how many there are, how many a row holds, and how many rows, so
// four that don't fit in one row go two and two.
fn grid(ps: players::Players&, area: float4, u: f32) -> i64, i64, i64 {
    let count = ps.list.len + (if ps.list.len < players::MAX_PLAYERS { 1 } else { 0 });
    let t = tile_w(area, u);
    let room = min(area.z / u - 2.0 * EDGE - 2.0 * PAD, WIDEST);
    let fit = max(1, floor((room + TILE_GAP) / (t + TILE_GAP)) as i64);
    let per = if count <= fit { count } else { (count + (count + fit - 1) / fit - 1) / ((count + fit - 1) / fit) };
    return count, per, (count + per - 1) / per;
}

// Declares the card over home for this frame: the screen dimmed (`screen`, the whole
// window), the card in the safe area `area`. Returns what it asks for and, for SWITCH,
// the player's place in the list.
fn frame(w: Who&, ps: players::Players&, g: gui::Gui&, area: float4, screen: float4) -> i64, i64 {
    gui::fill(g, screen, float4 { 0.0, 0.0, 0.0, 0.42 }, 0.0);
    // A tap on the dimmed home outside the card closes it.
    let outside, unused = gui::hold(g, gui::WHO_IDS, screen);
    var ask = NOTHING;
    var index = -1;
    if w.state == SHEET {
        ask, index = sheet(w, ps, g, area);
    } else {
        ask, index = picker(w, ps, g, area);
    }
    if ask == NOTHING && outside {
        w.state = CLOSED;
        w.typing = false;
        return CHANGED, -1;
    }
    return ask, index;
}

// The card's glass in r, which takes a press on it so it never reaches the dimmed home.
fn card(g: gui::Gui&, r: float4) {
    gui::glass(g, r, 32.0);
    gui::hold(g, gui::WHO_IDS + 1, r);
}

// A glass round tile a tap across with an icon, as settings' back: true when tapped.
fn glass_tile(g: gui::Gui&, id: i64, r: float4, icon: i64, style: i64) -> bool {
    gui::glass(g, r, 22.0);
    return gui::tile(g, id, r, icon, style, 22.0);
}

// Who's playing: back, the title, the pencil; the faces.
fn picker(w: Who&, ps: players::Players&, g: gui::Gui&, area: float4) -> i64, i64 {
    let u = g.scale;
    let count, per, rows = grid(ps, area, u);
    let t = tile_w(area, u);
    let th = tile_h(area, u);
    let title = strings::get(strings::PLAYERS_WHO);
    let room = area.z - 2.0 * (EDGE + PAD) * u;
    let tiles = per * t + (per - 1) * TILE_GAP;
    let head = (2.0 * gui::TAP + 32.0) * u + gui::text_width(g, gui::LABEL, title);
    let width = min(max(tiles * u, head), room) + 2.0 * PAD * u;
    let height = (20.0 + gui::TAP + GAP + rows * th + (rows - 1) * TILE_GAP + 24.0) * u;
    let r = gui::center(area, width, height);
    card(g, r);
    var c = float4 { r.x + PAD * u, r.y + 20.0 * u, r.z - 2.0 * PAD * u, r.w - 44.0 * u };
    var ask = NOTHING;
    var row = gui::cut_top(c, gui::TAP * u);
    gui::cut_top(c, GAP * u);
    if glass_tile(g, gui::WHO_IDS + 2, gui::cut_left(row, gui::TAP * u), gui::BACK, gui::PLAIN) {
        w.state = CLOSED;
        ask = CHANGED;
    }
    if glass_tile(g, gui::WHO_IDS + 3, gui::cut_right(row, gui::TAP * u), gui::PENCIL, if w.editing { gui::ON } else { gui::PLAIN }) {
        w.editing = !w.editing;
        ask = CHANGED;
    }
    gui::cut_left(row, gui::PAD_WIDE * u);
    gui::cut_right(row, gui::PAD_WIDE * u);
    let face = gui::fitting(g, gui::LABEL, title, row.z);
    if gui::text_width(g, face, title) <= row.z { gui::text(g, face, row, title, 1.0, 0.0, gui::LEFT); }
    // The faces, row by row, each row centered.
    for i in count {
        let line = i / per;
        let in_line = min(per, count - line * per);
        let x0 = c.x + 0.5 * (c.z - (in_line * t + (in_line - 1) * TILE_GAP) * u);
        let tr = float4 { x0 + (i % per) * (t + TILE_GAP) * u, c.y + line * (th + TILE_GAP) * u, t * u, th * u };
        let add = i == ps.list.len;
        let tapped = gui::tile(g, gui::WHO_IDS + 10 + i, tr, gui::NO_ICON, if w.editing && !add { gui::QUIET } else { gui::ROW }, 24.0);
        var inner = gui::inset(tr, gui::PAD * u);
        let fs = 0.72 * t * u;
        let fr = gui::center(gui::cut_top(inner, fs), fs, fs);
        gui::cut_top(inner, 8.0 * u);
        if add {
            gui::face(g, fr, -1, 1.0, false);
        } else {
            let p .= ps.list[i];
            gui::face(g, fr, p.picture, 1.0, i == ps.playing);
            let nf = gui::fitting(g, gui::BODY, p.name[..], inner.z);
            gui::text(g, nf, inner, p.name[..], 1.0, 0.0, gui::CENTER);
            if w.editing {
                // A dark disc with a light rim under the pencil: over the face's light
                // picture a faint white disc left the pencil hard to see.
                let b = float4 { tr.x + tr.z - 48.0 * u, tr.y + 8.0 * u, 40.0 * u, 40.0 * u };
                gui::fill(g, b, float4 { 1.0, 1.0, 1.0, 0.85 }, 20.0 * u);
                gui::fill(g, gui::inset(b, 2.0 * u), float4 { 0.16, 0.12, 0.10, 0.95 }, 18.0 * u);
                gui::glyph_icon(g, gui::center(b, 22.0 * u, 22.0 * u), gui::PENCIL, gui::PLAIN, 0.0, 1.0);
            }
        }
        guard tapped else { continue; }
        if add {
            sheet_for(w, ps, -1);
            ask = CHANGED;
        } else if w.editing {
            sheet_for(w, ps, i);
            ask = CHANGED;
        } else {
            w.state = CLOSED;
            guard i != ps.playing else { return CHANGED, i; }
            return SWITCH, i;
        }
    }
    return ask, -1;
}

// Opens the sheet for the player at `index`, or -1 for a new one with the first free
// picture.
fn sheet_for(w: Who&, ps: players::Players&, index: i64) {
    w.state = SHEET;
    w.target = index;
    w.typing = false;
    w.name.clear();
    if index >= 0 {
        w.picture = ps.list[index].picture;
        w.name = ps.list[index].name;
    } else {
        w.picture = players::free_picture(ps, -1);
    }
}

// The pictures' size in dp and how many to a row, in a card whose content may be `room`
// dp wide: six in a row, a tap to 112 dp; else three; three of a tap at the side (`wide`).
fn pictures(room: f32, wide: bool) -> f32, i64 {
    guard !wide else { return gui::TAP, 3; }
    let six = min(112.0, floor((min(room, 760.0 - 2.0 * PAD) - 5.0 * PIC_GAP) / 6.0));
    guard six < gui::TAP else { return six, 6; }
    return min(112.0, floor((room - 2.0 * PIC_GAP) / 3.0)), 3;
}

// How wide a hold's tile wants to be: its icon, its word, and "hold" under it.
fn hold_width(g: gui::Gui&, key: i64) -> f32 {
    let u = g.scale;
    let words = max(gui::text_width(g, gui::BODY, strings::get(key)),
                    gui::text_width(g, gui::SMALL, strings::get(strings::PLAYERS_HOLD)));
    return (16.0 + 30.0 + 12.0 + 16.0) * u + words;
}

// The sheet: back, the face and name or the title, done; the pictures, the name, and
// for a player already there the holds.
fn sheet(w: Who&, ps: players::Players&, g: gui::Gui&, area: float4) -> i64, i64 {
    let u = g.scale;
    var ask = NOTHING;
    // The characters typed this frame go into the name before the head shows it.
    if typed(w, g) { ask = CHANGED; }
    let edit = w.target >= 0 && !w.first;
    let holds = if !edit { 0 } else if ps.list.len > 1 { 2 } else { 1 };
    let wide = area.z > area.w && area.w < gui::PHONE * u;
    let room = area.z / u - 2.0 * (EDGE + PAD);
    let pic, cols = pictures(room, wide);
    let grid_w = cols * pic + (cols - 1) * PIC_GAP;
    let grid_h = (6 / cols) * pic + (6 / cols - 1) * PIC_GAP;
    // The holds side by side where both fit, else one over the other.
    var both = hold_width(g, strings::PLAYERS_START_AGAIN) + gui::PAD * u;
    if holds == 2 { both += hold_width(g, strings::PLAYERS_REMOVE); }
    // The head: back, the face (editing) and the name or the title, done.
    let title = if edit { w.name[..] } else { strings::get(strings::PLAYERS_NEW) };
    let head = (2.0 * gui::TAP + 32.0 + (if edit { 72.0 } else { 0.0 })) * u + gui::text_width(g, gui::LABEL, title);
    var content: f32 = 0.0;
    var right:   f32 = 0.0;   // wide: the right column's width
    if wide {
        right = clamp(both, 300.0 * u, room * u - (grid_w + 24.0) * u);
        content = max((grid_w + 24.0) * u + right, head);
    } else {
        content = clamp(max(head, both), grid_w * u, room * u);
    }
    let stacked = holds > 0 && both > (if wide { right } else { content }) + 0.5;
    let holds_h = if holds == 0 { 0.0 } else if stacked && holds == 2 { 2.0 * gui::TAP + ROW_GAP } else { gui::TAP };
    let name_h = TITLE_H + ROW_GAP + gui::TAP + (if holds > 0 { ROW_GAP + holds_h } else { 0.0 });
    let pics_h = TITLE_H + ROW_GAP + grid_h;
    let body = if wide { max(pics_h, name_h) } else { pics_h + GAP + name_h };
    let height = (20.0 + gui::TAP + GAP + body + 24.0) * u;
    var r = gui::center(area, content + 2.0 * PAD * u, height);
    // Clear of the keyboard while the name is typed.
    if w.typing { r.y = min(r.y, area.y + EDGE * u); }
    card(g, r);
    var c = float4 { r.x + PAD * u, r.y + 20.0 * u, r.z - 2.0 * PAD * u, r.w - 44.0 * u };

    var row = gui::cut_top(c, gui::TAP * u);
    gui::cut_top(c, GAP * u);
    if glass_tile(g, gui::WHO_IDS + 20, gui::cut_left(row, gui::TAP * u), gui::BACK, gui::PLAIN) {
        w.state = if w.first { CLOSED } else { PICKING };
        w.typing = false;
        ask = CHANGED;
    }
    let done = glass_tile(g, gui::WHO_IDS + 21, gui::cut_right(row, gui::TAP * u), gui::CHECK, gui::PRIMARY);
    gui::cut_left(row, gui::PAD_WIDE * u);
    gui::cut_right(row, gui::PAD_WIDE * u);
    if edit {
        gui::face(g, gui::center(gui::cut_left(row, 56.0 * u), 56.0 * u, 56.0 * u), w.picture, 1.0, false);
        gui::cut_left(row, gui::PAD_WIDE * u);
    }
    let tf = gui::fitting(g, gui::LABEL, title, row.z);
    if gui::text_width(g, tf, title) <= row.z { gui::text(g, tf, row, title, 1.0, 0.0, gui::LEFT); }

    // The pictures, and the name with the holds: one over the other, or side by side.
    var left = c;
    var rest = c;
    if wide {
        left = gui::cut_left(rest, grid_w * u);
        gui::cut_left(rest, 24.0 * u);
    } else {
        left = gui::cut_top(rest, pics_h * u);
        gui::cut_top(rest, GAP * u);
    }
    heading(g, left, strings::PLAYERS_PICTURE);
    let cells = gui::cut_top(left, grid_h * u);
    for a in players::ANIMALS.len {
        let cell = float4 { cells.x + (a % cols) * (pic + PIC_GAP) * u, cells.y + (a / cols) * (pic + PIC_GAP) * u,
                            pic * u, pic * u };
        let free = !players::taken(ps, a, w.target);
        let tapped, unused = gui::pick(g, gui::WHO_IDS + 30 + a, cell, 0.0, "", "", a == w.picture, free);
        let s = (pic - 22.0) * u;
        gui::face(g, gui::center(cell, s, s), a, if free { 1.0 } else { 0.3 }, false);
        if tapped && a != w.picture {
            w.picture = a;
            ask = CHANGED;
        }
    }

    heading(g, rest, strings::PLAYERS_NAME);
    if field(w, g, gui::cut_top(rest, gui::TAP * u)) { ask = CHANGED; }
    if holds > 0 {
        gui::cut_top(rest, ROW_GAP * u);
        var hr = gui::cut_top(rest, holds_h * u);
        let first = if stacked || holds == 1 { gui::cut_top(hr, gui::TAP * u) } else { gui::cut_left(hr, 0.5 * (hr.z - gui::PAD * u)) };
        if stacked { gui::cut_top(hr, ROW_GAP * u); } else { gui::cut_left(hr, gui::PAD * u); }
        if hold(g, gui::WHO_IDS + 41, first, gui::RESTART, strings::PLAYERS_START_AGAIN, false) { ask = AGAIN; }
        if holds == 2 && hold(g, gui::WHO_IDS + 42, hr, gui::TRASH, strings::PLAYERS_REMOVE, true) {
            w.state = PICKING;
            w.typing = false;
            return REMOVE, w.target;
        }
    }
    if done {
        players::trimmed(w.name);
        w.typing = false;
        w.state = if edit { PICKING } else { CLOSED };
        guard w.target >= 0 else { return CREATE, -1; }
        return SAVE, w.target;
    }
    return ask, w.target;
}

// A dim name over a part of the sheet, cut from the top of c.
fn heading(g: gui::Gui&, c: float4&, key: i64) {
    let u = g.scale;
    var r = gui::cut_top(c, TITLE_H * u);
    gui::cut_top(c, ROW_GAP * u);
    gui::cut_left(r, 4.0 * u);
    gui::text(g, gui::SMALL, r, strings::get(key), 0.66, 0.03 * gui::FACE_DP[gui::SMALL] as f32 * u, gui::LEFT);
}

// While the keyboard is up the characters typed go into the name, Return closing it.
// True when any came.
fn typed(w: Who&, g: gui::Gui&) -> bool {
    var changed = false;
    for c in g.input.typed {
        guard w.typing else { break; }
        if c == gui::ERASE { players::erase_char(w.name); }
        else if c == gui::ENTER { w.typing = false; }
        else { players::add_char(w.name, c); }
        changed = true;
    }
    return changed;
}

// The name's field in r: a pencil, then the name, or "Name" faint while there is none and
// it isn't typed; a caret after it while it is. A tap brings up the keyboard (`typed`,
// above, takes what it types). True when the tap came.
fn field(w: Who&, g: gui::Gui&, r: float4) -> bool {
    let u = g.scale;
    var changed = false;
    gui::fill(g, r, float4 { 0.0, 0.0, 0.0, 0.18 }, 20.0 * u);
    if gui::tile(g, gui::WHO_IDS + 40, r, gui::NO_ICON, if w.typing { gui::CHOSEN } else { gui::QUIET }, 20.0) {
        w.typing = true;
        w.keyboard++;
        changed = true;
    }
    var c = r;
    gui::cut_left(c, 20.0 * u);
    gui::cut_right(c, 20.0 * u);
    gui::glyph_icon(g, gui::center(gui::cut_left(c, 28.0 * u), 28.0 * u, 28.0 * u), gui::PENCIL, gui::PLAIN, 0.0, 0.6);
    gui::cut_left(c, 14.0 * u);
    if w.name.len == 0 && !w.typing {
        gui::text(g, gui::LABEL, c, strings::get(strings::PLAYERS_NAME), 0.45, 0.0, gui::LEFT);
    } else {
        gui::text(g, gui::LABEL, c, w.name[..], 1.0, 0.0, gui::LEFT);
    }
    if w.typing {
        let f .= g.faces[gui::LABEL];
        let x = c.x + gui::text_width(g, gui::LABEL, w.name[..]) + 2.0 * u;
        let h = f.ascent - f.descent;
        gui::fill(g, float4 { floor(x + 0.5), c.y + 0.5 * (c.w - h), 2.0 * u, h }, float4 { 1.0, 1.0, 1.0, 0.85 }, 1.0 * u);
    }
    return changed;
}

// A hold's tile in r: its icon, its word, and "hold" under it; removing's in the
// forced-capture red toward the text color. True on the frame its ring is full.
fn hold(g: gui::Gui&, id: i64, r: float4, icon: i64, key: i64, red: bool) -> bool {
    let u = g.scale;
    let fired, k = gui::hold_tile(g, id, r, 20.0, HOLD, red);
    let word = strings::get(key);
    let note = strings::get(strings::PLAYERS_HOLD);
    let body = g.faces[gui::BODY].ascent - g.faces[gui::BODY].descent;
    let small = g.faces[gui::SMALL].ascent - g.faces[gui::SMALL].descent;
    let words = max(gui::text_width(g, gui::BODY, word), gui::text_width(g, gui::SMALL, note));
    var c = gui::center(r, min((30.0 + 12.0) * u + words, r.z - gui::PAD_WIDE * u), r.w);
    gui::glyph_icon(g, gui::center(gui::cut_left(c, 30.0 * u), 30.0 * u, 30.0 * u), icon,
                    if red { gui::CLOCK_LOW } else { gui::PLAIN }, 0.0, 0.85);
    gui::cut_left(c, gui::PAD * u);
    var t = gui::center(c, c.z, body + small);
    let color = if red { float4 { 1.0, 0.644, 0.610, 1.0 } } else { float4 { 1.0, 1.0, 1.0, 1.0 } };
    if red { gui::colored(g, gui::BODY, gui::cut_top(t, body), word, color, gui::LEFT); }
    else { gui::text(g, gui::BODY, gui::cut_top(t, body), word, 1.0, 0.0, gui::LEFT); }
    gui::text(g, gui::SMALL, t, note, 0.66, 0.0, gui::LEFT);
    return fired;
}
