// The keys' focus (task 072; rendering.md, "Keys"): the controls a frame offers it, in
// the order declared, and the next frame's begin moving it among them by their rects; Enter
// presses the focused one. A gamepad will feed the same moves through gui::Input. Part of
// gui, in its namespace; gui.goose's Gui keeps the state.
namespace gui;
import std;
import vec;

// A control a frame declared that the keys can focus: its id, its rect, whether it is the
// screen's first choice (`primary`, home's Continue), which the first key focuses, and the
// scrolling list it was declared in (`list`, scroll_begin's id), or 0; the group it was
// offered in (`group`, gui::group), which Tab and a gamepad's shoulder buttons step
// between; and for a grid (gui::grid, the board) its cells a side and the cell the focus
// takes there when it comes by Tab or as the first key (`home`, y * cells + x).
struct Spot {
    id:      i64    = 0,
    rect:    float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    primary: bool   = false,
    list:    i64    = 0,
    group:   i64    = 0,
    cells:   i64    = 0,
    home:    i64    = 0,
}

// The keys' focus at a frame's start: the mouse moving, a press, or the wheel lets it go,
// as the pointer leads again; an arrow key moves it from the control it is on to the
// nearest that way, or, from none, to the screen's primary control; on a grid it moves
// the cell, leaving the grid for the nearest control that way past its edge; Tab moves it
// to the next group (`tab`); a focused control the last frame didn't declare (the screen
// changed) hands it to the new screen's primary. Enter with nothing focused focuses the
// primary and presses it in the same frame (on the board, its cursor's first square): a
// gamepad's first press is most often A (a PS5 pad's cross), and one that only showed the
// focus read as a press lost.
fn focus_keys(g: Gui&, input: Input) {
    let moved = input.at.x != g.pointer.at.x || input.at.y != g.pointer.at.y;
    if input.pressed || input.wheel != 0.0 || moved { g.focus = 0; }
    let n = g.spots.len;
    if n > 0 && input.tab != 0 {
        take_focus(g, next_group(g, input.tab), float4 { 0.0, 0.0, 0.0, 0.0 }, STEP_NONE);
    } else if n > 0 && input.step != STEP_NONE {
        let at = spot_of(g, g.focus);
        if at < 0 {
            take_focus(g, g.spots[primary_spot(g)].id, float4 { 0.0, 0.0, 0.0, 0.0 }, STEP_NONE);
        } else if !step_cell(g, at, input.step) {
            take_focus(g, toward(g, input.step), g.spots[at].rect, input.step);
        }
    } else if n > 0 && g.focus != 0 && spot_of(g, g.focus) < 0 {
        take_focus(g, g.spots[primary_spot(g)].id, float4 { 0.0, 0.0, 0.0, 0.0 }, STEP_NONE);
    }
    if n > 0 && input.confirm && g.focus == 0 {
        take_focus(g, g.spots[primary_spot(g)].id, float4 { 0.0, 0.0, 0.0, 0.0 }, STEP_NONE);
    }
    let at = spot_of(g, g.focus);
    g.focused = if at >= 0 { g.spots[at] } else { Spot {} };
    if at >= 0 && g.spots[at].group >= 0 && g.spots[at].group < MAX_GROUPS { g.group_focus[g.spots[at].group] = g.focus; }
    g.spots.clear();
    g.deaf = false;
    g.ring = false;
    g.group = 0;
}

// Gives the focus to control id. A grid it comes to from another control by an arrow
// (`step`, from the rect `from`) takes the cell on its near edge in line with where the
// focus was; by Tab or as the first key, the cell it had when last left, or its home
// cell if another grid had it since.
fn take_focus(g: Gui&, id: i64, from: float4, step: i64) {
    let was = g.focus;
    g.focus = id;
    let at = spot_of(g, id);
    guard at >= 0 && id != was else { return; }
    let s = g.spots[at];
    guard s.cells > 0 else { return; }
    let c = s.cells;
    if step != STEP_NONE && was != 0 {
        let w = s.rect.z / c;
        let h = s.rect.w / c;
        let mx = clamp(floor((from.x + 0.5 * from.z - s.rect.x) / w) as i64, 0, c - 1);
        let my = clamp(floor((from.y + 0.5 * from.w - s.rect.y) / h) as i64, 0, c - 1);
        g.cell = match step {
            STEP_UP => (c - 1) * c + mx,
            STEP_DOWN => mx,
            STEP_LEFT => my * c + c - 1,
            _ => my * c,
        };
    } else if g.cell_of != id {
        g.cell = s.home;
    }
    g.cell_of = id;
}

// On grid spot `at`, moves the focused cell one `step`: false, moving nothing, past the
// grid's edge or on a control that is no grid.
fn step_cell(g: Gui&, at: i64, step: i64) -> bool {
    let c = g.spots[at].cells;
    guard c > 0 && g.cell_of == g.spots[at].id else { return false; }
    var x = g.cell % c;
    var y = g.cell / c;
    match step {
        STEP_UP => { y -= 1; },
        STEP_DOWN => { y += 1; },
        STEP_LEFT => { x -= 1; },
        _ => { x += 1; },
    }
    guard x >= 0 && y >= 0 && x < c && y < c else { return false; }
    g.cell = y * c + x;
    return true;
}

// The control Tab goes to, `dir` 1 forward and -1 back: in the next group that way
// (by number, round from the last to the first), the one focused there last if it is
// still offered, else the group's primary or first. A screen of one group steps through
// its controls in the order declared.
fn next_group(g: Gui&, dir: i64) -> i64 {
    let at = spot_of(g, g.focus);
    var lo = g.spots[0].group;
    var hi = lo;
    for s in g.spots {
        lo = min(lo, s.group);
        hi = max(hi, s.group);
    }
    if lo == hi {
        guard at >= 0 else { return g.spots[primary_spot(g)].id; }
        return g.spots[(at + dir) % g.spots.len].id;
    }
    // The nearest group number that way that has a control, wrapping round.
    let from = if at >= 0 { g.spots[at].group } else if dir > 0 { lo - 1 } else { hi + 1 };
    var to = from;
    var best = -1;
    for s in g.spots {
        let ahead = if dir > 0 { s.group > from } else { s.group < from };
        guard ahead else { continue; }
        if best < 0 || (dir > 0 && s.group < to) || (dir < 0 && s.group > to) {
            to = s.group;
            best = 0;
        }
    }
    if best < 0 { to = if dir > 0 { lo } else { hi }; }
    if to >= 0 && to < MAX_GROUPS {
        let last = spot_of(g, g.group_focus[to]);
        if last >= 0 && g.spots[last].group == to { return g.spots[last].id; }
    }
    var first = -1;
    for s, i in g.spots {
        guard s.group == to else { continue; }
        if s.primary { return s.id; }
        if first < 0 { first = i; }
    }
    return g.spots[first].id;
}

// Spot i of the control id the last frame offered, or -1.
fn spot_of(g: Gui&, id: i64) -> i64 {
    guard id != 0 else { return -1; }
    for s, i in g.spots { if s.id == id { return i; } }
    return -1;
}

// The spot the first key focuses: the first marked primary, else the first declared.
fn primary_spot(g: Gui&) -> i64 {
    for s, i in g.spots { if s.primary { return i; } }
    return 0;
}

// The control nearest the focused one in direction `step`: of those whose middle lies
// that way, the least gap that way plus twice the gap across, so a control in line wins
// over a nearer one off to the side; the focus stays where none lies that way.
fn toward(g: Gui&, step: i64) -> i64 {
    let a = g.spots[spot_of(g, g.focus)].rect;
    let vertical = step == STEP_UP || step == STEP_DOWN;
    var best = g.focus;
    var least: f32 = 1.0e30;
    for s in g.spots {
        guard s.id != g.focus else { continue; }
        let r = s.rect;
        let ahead = match step {
            STEP_UP => a.y - (r.y + r.w),
            STEP_DOWN => r.y - (a.y + a.w),
            STEP_LEFT => a.x - (r.x + r.z),
            _ => r.x - (a.x + a.z),
        };
        let mid = match step {
            STEP_UP => r.y + 0.5 * r.w < a.y + 0.5 * a.w,
            STEP_DOWN => r.y + 0.5 * r.w > a.y + 0.5 * a.w,
            STEP_LEFT => r.x + 0.5 * r.z < a.x + 0.5 * a.z,
            _ => r.x + 0.5 * r.z > a.x + 0.5 * a.z,
        };
        guard mid else { continue; }
        let side = if vertical { max(0.0, max(a.x, r.x) - min(a.x + a.z, r.x + r.z)) }
                   else { max(0.0, max(a.y, r.y) - min(a.y + a.w, r.y + r.w)) };
        let score = max(0.0, ahead) + 2.0 * side;
        if score < least {
            least = score;
            best = s.id;
        }
    }
    return best;
}

// Offers control id over r to the keys' focus, unless a screen a transition leaves is
// being declared.
fn offer(g: Gui&, id: i64, r: float4) {
    guard !g.deaf && g.spots.len < MAX_SPOTS else { return; }
    g.spots.push(Spot { id: id, rect: r, primary: false, list: if g.scroll.open { g.scroll.id } else { 0 }, group: g.group, .. });
}

// The controls offered from here on, to the frame's end or the next call, are group k
// (0 up to MAX_GROUPS, a panel's or the board's): Tab, and a gamepad's shoulder buttons,
// step between groups by their numbers, coming back to the control last focused in each.
fn group(g: Gui&, k: i64) { g.group = k; }

// A grid of `cells` × `cells` over r that takes the keys' focus as one control (the
// board): while it has it, the arrows move a cell in it, row 0 at r's top, and an arrow
// past its edge leaves it for the nearest control that way. `home` (y * cells + x) is the
// cell the focus takes when it comes by Tab or the first key. Returns the focused cell or
// -1, and whether Enter pressed it this frame. It draws nothing: the caller shows the cell.
fn grid(g: Gui&, id: i64, r: float4, cells: i64, home: i64) -> i64, bool {
    guard !g.deaf else { return -1, false; }
    if g.spots.len < MAX_SPOTS {
        g.spots.push(Spot { id: id, rect: r, primary: false, list: 0, group: g.group, cells: cells,
                            home: clamp(home, 0, cells * cells - 1) });
    }
    guard g.focus == id && g.cell_of == id else { return -1, false; }
    return clamp(g.cell, 0, cells * cells - 1), g.pointer.confirm;
}

// Marks control id, just offered, as the screen's primary one (its first choice).
fn prefer(g: Gui&, id: i64) {
    let n = g.spots.len;
    if n > 0 && g.spots[n - 1].id == id { g.spots[n - 1].primary = true; }
}

// Whether Enter pressed control id this frame: it has the keys' focus.
fn keyed(g: Gui&, id: i64) -> bool { !g.deaf && g.focus == id && g.pointer.confirm }

// Whether Enter holds control id down (a hold tile): it has the keys' focus and Enter is
// down, pressed this frame or held since it went down on it. A press the hold let go of
// (its ring full) stays up until Enter is pressed again.
fn key_held(g: Gui&, id: i64) -> bool {
    guard !g.deaf && g.focus == id && g.pointer.held else { return false; }
    return g.pointer.confirm || g.slots[slot(g, id)].down;
}
