// The immediate-mode UI layer (docs/architecture/rendering.md, "UI layer"), with no
// graphics: screens are declared in code each frame, layout cuts rects from the screen,
// and each call appends quads to one fixed array that the app copies into one storage
// buffer and draws with one pipeline. A small fixed table keeps per-id state for the
// press animation. Nothing here allocates; tests run it headless.
//
// Rects are float4 { x, y, width, height } in pixels; sizes given in dp are multiplied by
// the layout's scale.
namespace gui;
import std;
import vec;

let MAX_QUADS = 128;
let MAX_IDS = 32;
let PRESS = 0.12;           // seconds a button takes to go down or up

// What a quad is, as the UI shader draws it.
let GLASS = 0;              // a glass panel, with its shadow
let BUTTON = 1;             // a glass tile, with its shadow; look.w: how far it is pressed
let ICON = 2;               // a line icon on a 24-unit grid; look.z: which
let FILL = 3;               // a plain rounded rect in `color`

// The line icons the shader knows (rendering.md, "Controls").
let NO_ICON = 0;
let UNDO = 1;
let HINT = 2;
let RESTART = 3;
let BACK = 4;

// One quad for the UI shader.
struct Quad {
    rect:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x, y, width, height in pixels
    color: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // straight alpha
    look:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // kind, corner radius in pixels, icon, pressed 0..1
    extra: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x: pixels per dp
}

// The pointer this frame. A quick tap can be pressed and released in one frame.
struct Input {
    at:       float2 = float2 { 0.0, 0.0 },
    down:     bool   = false,
    pressed:  bool   = false,
    released: bool   = false,
}

// A widget's state across frames: whether it is down and when that last changed.
struct Slot {
    id:    i64  = 0,
    down:  bool = false,
    since: f64  = -1.0,
}

struct Gui {
    scale:  f32               = 1.0,
    now:    f64               = 0.0,
    input:  Input             = Input {},
    active: i64               = 0,     // the widget the pointer went down on, or 0
    took:   bool              = false, // whether this press landed on the UI, not the board
    quads:  Quad[..MAX_QUADS] = [],
    slots:  Slot[MAX_IDS]     = [Slot {}; MAX_IDS],
}

// Rect cuts: each takes a strip off r and returns it.
fn cut_top(r: float4&, h: f32) -> float4 {
    let s = float4 { r.x, r.y, r.z, min(h, r.w) };
    r.y += s.w;
    r.w -= s.w;
    return s;
}
fn cut_bottom(r: float4&, h: f32) -> float4 {
    let s = float4 { r.x, r.y + r.w - min(h, r.w), r.z, min(h, r.w) };
    r.w -= s.w;
    return s;
}
fn cut_left(r: float4&, w: f32) -> float4 {
    let s = float4 { r.x, r.y, min(w, r.z), r.w };
    r.x += s.z;
    r.z -= s.z;
    return s;
}
fn cut_right(r: float4&, w: f32) -> float4 {
    let s = float4 { r.x + r.z - min(w, r.z), r.y, min(w, r.z), r.w };
    r.z -= s.z;
    return s;
}
fn inset(r: float4, d: f32) -> float4 { float4 { r.x + d, r.y + d, r.z - 2.0 * d, r.w - 2.0 * d } }

// A w × h rect centered in r.
fn center(r: float4, w: f32, h: f32) -> float4 {
    float4 { r.x + 0.5 * (r.z - w), r.y + 0.5 * (r.w - h), w, h }
}

// Cell i of a grid of cells w × h with gap between them, row by row, centered in r.
fn cell(r: float4, cols: i64, rows: i64, w: f32, h: f32, gap: f32, i: i64) -> float4 {
    let all = center(r, cols * w + (cols - 1) * gap, rows * h + (rows - 1) * gap);
    return float4 { all.x + (i % cols) * (w + gap), all.y + (i / cols) * (h + gap), w, h };
}

fn inside(r: float4, p: float2) -> bool { p.x >= r.x && p.x < r.x + r.z && p.y >= r.y && p.y < r.y + r.w }

// Starts a frame: no quads yet, this frame's pointer and time.
fn begin(g: Gui&, input: Input, scale: f32, now: f64) {
    if !g.input.down && !g.input.pressed { g.active = 0; }
    if input.pressed { g.took = false; }
    g.input = input;
    g.scale = scale;
    g.now = now;
    g.quads.clear();
}

fn add(g: Gui&, q: Quad) {
    guard g.quads.len < MAX_QUADS else { return; }
    g.quads.push(q);
}

// The slot of widget id, taking a free or the oldest one for a new id.
fn slot(g: Gui&, id: i64) -> i64 {
    var oldest = 0;
    for s, i in g.slots {
        if s.id == id { return i; }
        if s.since < g.slots[oldest].since { oldest = i; }
    }
    g.slots[oldest] = Slot { id: id, .. };
    return oldest;
}

// How far widget id is pressed, 0..1, eased.
fn pressed(g: Gui&, id: i64) -> f32 {
    let s .= g.slots[slot(g, id)];
    let t = if s.since < 0.0 { 1.0 } else { clamp((g.now - s.since) / PRESS, 0.0, 1.0) };
    let e = t * t * (3.0 - 2.0 * t);
    return (if s.down { e } else { 1.0 - e }) as f32;
}

fn set_down(g: Gui&, id: i64, down: bool) {
    let s .= g.slots[slot(g, id)];
    if s.down != down {
        s.down = down;
        s.since = g.now;
    }
}

// Whether any widget is still going down or up; the app draws while one is.
fn animating(g: Gui&) -> bool {
    for s in g.slots { if s.id != 0 && s.since >= 0.0 && g.now < s.since + PRESS { return true; } }
    return false;
}

// A glass panel. A press on it belongs to the UI.
fn panel(g: Gui&, r: float4) {
    if g.input.pressed && inside(r, g.input.at) { g.took = true; }
    add(g, Quad { rect: r, look: float4 { GLASS, 28.0 * g.scale, 0.0, 0.0 },
                  extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
}

// A plain rounded rect, such as a rule.
fn fill(g: Gui&, r: float4, color: float4, radius: f32) {
    add(g, Quad { rect: r, color: color, look: float4 { FILL, radius, 0.0, 0.0 },
                  extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
}

// A glass tile with a line icon (rendering.md, "Controls"), true on the frame the
// pointer is released over it after going down on it. id is any nonzero number unique
// on the screen.
fn button(g: Gui&, id: i64, r: float4, icon: i64) -> bool {
    let over = inside(r, g.input.at);
    if g.input.pressed && over {
        g.active = id;
        g.took = true;
    }
    let held = g.active == id && g.input.down && over;
    let clicked = g.active == id && g.input.released && over;
    set_down(g, id, held);
    let p = pressed(g, id);
    add(g, Quad { rect: r, look: float4 { BUTTON, 22.0 * g.scale, 0.0, p },
                  extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
    if icon != NO_ICON {
        // Icons are 44 dp in an 88 dp tile, scaled with it and with the press.
        let s = 0.5 * r.z * (1.0 - 0.04 * p);
        add(g, Quad { rect: center(r, s, s), color: float4 { 1.0, 1.0, 1.0, 1.0 },
                      look: float4 { ICON, 0.0, icon, p }, extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
    }
    return clicked;
}
