// The keys' focus (task 072; rendering.md, "Keys"): the controls a frame offers it, in
// the order declared, and the next frame's begin moving it among them by their rects; Enter
// presses the focused one. A gamepad will feed the same moves through gui::Input. Part of
// gui, in its namespace; gui.goose's Gui keeps the state.
namespace gui;
import std;
import vec;

// A control a frame declared that the keys can focus: its id, its rect, whether it is the
// screen's first choice (`primary`, home's Continue), which the first key focuses, and the
// scrolling list it was declared in (`list`, scroll_begin's id), or 0.
struct Spot {
    id:      i64    = 0,
    rect:    float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    primary: bool   = false,
    list:    i64    = 0,
}

// The keys' focus at a frame's start: the mouse moving, a press, or the wheel lets it go,
// as the pointer leads again; an arrow key moves it from the control it is on to the
// nearest that way, or, from none, to the screen's primary control; a focused control the
// last frame didn't declare (the screen changed) hands it to the new screen's primary.
fn focus_keys(g: Gui&, input: Input) {
    let moved = input.at.x != g.pointer.at.x || input.at.y != g.pointer.at.y;
    if input.pressed || input.wheel != 0.0 || moved { g.focus = 0; }
    let n = g.spots.len;
    if n > 0 && input.step != STEP_NONE {
        g.focus = if spot_of(g, g.focus) < 0 { g.spots[primary_spot(g)].id } else { toward(g, input.step) };
    } else if n > 0 && g.focus != 0 && spot_of(g, g.focus) < 0 {
        g.focus = g.spots[primary_spot(g)].id;
    }
    let at = spot_of(g, g.focus);
    g.focused = if at >= 0 { g.spots[at] } else { Spot {} };
    g.spots.clear();
    g.deaf = false;
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
    g.spots.push(Spot { id: id, rect: r, primary: false, list: if g.scroll.open { g.scroll.id } else { 0 } });
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
