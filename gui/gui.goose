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

let MAX_QUADS = 512;
let MAX_IDS = 32;
let PRESS = 0.12;           // seconds a button takes to go down or up

// What a quad is, as the UI shader draws it.
let GLASS = 0;              // a glass panel, with its shadow
let BUTTON = 1;             // a glass tile, with its shadow; look.w: how far it is pressed
let ICON = 2;               // a line icon on a 24-unit grid; look.z: which
let FILL = 3;               // a plain rounded rect in `color`
let SPARK = 4;              // a glowing disc in the glow color; color.a: its opacity
let TEXT = 5;               // a glyph from the font atlas in the text color; look.yzw, extra.y: its uv
let PICTURE = 6;            // a season's thumbnail (look.z: its theme), or the glow's tint for -1

// How a tile and its icon look (extra.y), in the theme's colors.
let PLAIN = 0;              // white at 10%
let PRIMARY = 1;            // the glow color at 22%
let ON = 2;                 // a toggle that is on: the glow color, with a glow border and icon
let OFF = 3;                // a toggle that is off: white at 8%, the icon faded
let QUIET = 4;              // white at 8% with a border at 18%, no highlight
let ROW = 5;                // a menu row: nothing until pressed, no border or shadow
let ROW_PRIMARY = 6;        // a menu row in the glow color at 24%
let CHOSEN = 7;             // a choice that is on: the glow color at 22%, a 2 dp glow border
let CHOICE = 8;             // a choice that is off: white at 10%, a border at 12%

// The line icons the shader knows (rendering.md, "Controls").
let NO_ICON = 0;
let UNDO = 1;
let HINT = 2;
let RESTART = 3;
let BACK = 4;
let DOTS = 5;               // move hints: four dots
let NEXT = 6;               // an arrow right
let FRIEND = 7;             // home's filled icons: two figures,
let COMPUTER = 8;           // a robot head,
let PUZZLE = 9;             // a jigsaw piece
let GEAR = 10;              // settings
let SUN = 11;               // settings' groups: the background,
let TARGET = 12;            // move hints,
let GLOBE = 13;             // the language

// Text faces (rendering.md, "Fonts"): one size each, in dp, baked by the app at the
// screen's pixel size.
let TITLE = 0;              // the wordmark
let LABEL = 1;              // menu rows
let HEADING = 2;            // a settings group's title
let BODY = 3;               // a choice's word
let SMALL = 4;              // notes, a picture's label
let FACES = 5;
let FACE_DP = [64.0, 30.0, 24.0, 20.0, 17.0];

// The characters the faces hold (the atlas's ranges): Latin-1 and Latin Extended-A from
// the space on, and general punctuation. Others are drawn as '?'.
let MAX_GLYPHS = 376;
let LATIN_END = 0x180;
let PUNCT = 0x2010;
let PUNCT_END = 0x2028;

// A glyph: its box from the pen at the line's top, in pixels; where it is in the atlas,
// 0..1; how far the pen moves after it.
struct Glyph {
    box:     float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x0, y0, x1, y1
    uv:      float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // u0, v0, u1, v1
    advance: f32    = 0.0,
}

// A face as baked: its size in pixels, ascent and descent (negative), and its glyphs.
struct Face {
    size:    f32               = 0.0,
    ascent:  f32               = 0.0,
    descent: f32               = 0.0,
    glyphs:  Glyph[MAX_GLYPHS] = [Glyph {}; MAX_GLYPHS],
}

// Where a character's glyph is in a face, or -1 for one the faces don't hold.
fn glyph_index(c: i64) -> i64 {
    if c >= 0x20 && c < LATIN_END { return c - 0x20; }
    if c >= PUNCT && c < PUNCT_END { return LATIN_END - 0x20 + c - PUNCT; }
    return -1;
}

// The character glyph i is, for the app filling a face.
fn glyph_char(i: i64) -> i64 { if i < LATIN_END - 0x20 { i + 0x20 } else { i - (LATIN_END - 0x20) + PUNCT } }

// One quad for the UI shader.
struct Quad {
    rect:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x, y, width, height in pixels
    color: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // straight alpha
    look:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // kind, corner radius in pixels, icon, pressed 0..1
    extra: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x: pixels per dp; y: PLAIN..OFF
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
    acted:  bool              = false, // whether a widget was clicked this frame
    quads:  Quad[..MAX_QUADS] = [],
    slots:  Slot[MAX_IDS]     = [Slot {}; MAX_IDS],
    faces:  Face[FACES]       = [Face {}; FACES],
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
    g.acted = false;
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
fn panel(g: Gui&, r: float4) { glass(g, r, 28.0); }

// A glass panel with corners of `radius` dp.
fn glass(g: Gui&, r: float4, radius: f32) {
    if g.input.pressed && inside(r, g.input.at) { g.took = true; }
    add(g, Quad { rect: r, look: float4 { GLASS, radius * g.scale, 0.0, 0.0 },
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
fn button(g: Gui&, id: i64, r: float4, icon: i64) -> bool { tile(g, id, r, icon, PLAIN, 22.0) }

// The press of widget id over r: true on the frame the pointer is released over r
// after going down on it, and how far it is pressed, 0..1.
fn hold(g: Gui&, id: i64, r: float4) -> bool, f32 {
    let over = inside(r, g.input.at);
    if g.input.pressed && over {
        g.active = id;
        g.took = true;
    }
    let held = g.active == id && g.input.down && over;
    let clicked = g.active == id && g.input.released && over;
    if clicked { g.acted = true; }
    set_down(g, id, held);
    return clicked, pressed(g, id);
}

// A tile in one of the looks PLAIN..ROW_PRIMARY with corner radius `radius` dp;
// otherwise as button.
fn tile(g: Gui&, id: i64, r: float4, icon: i64, style: i64, radius: f32) -> bool {
    let clicked, p = hold(g, id, r);
    add(g, Quad { rect: r, look: float4 { BUTTON, radius * g.scale, 0.0, p },
                  extra: float4 { g.scale, style, 0.0, 0.0 } });
    if icon != NO_ICON {
        // Icons are 44 dp in an 88 dp tile, scaled with it and with the press.
        let s = 0.5 * min(r.z, r.w) * (1.0 - 0.04 * p);
        glyph_icon(g, center(r, s, s), icon, style, p, 1.0);
    }
    return clicked;
}

// A line or filled icon in r, in the text color at opacity a (the glow color for ON).
fn glyph_icon(g: Gui&, r: float4, icon: i64, style: i64, p: f32, a: f32) {
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { ICON, 0.0, icon, p },
                  extra: float4 { g.scale, style, 0.0, 0.0 } });
}

// A menu row (prototypes/home.html): an icon, a label, and a note at the right in
// the dimmer small face, in a 20 dp rounded row that lights while pressed. A row that
// is off is drawn at 40% and can't be pressed. True when it is tapped.
fn row(g: Gui&, id: i64, r: float4, icon: i64, label: const u8[:], note: const u8[:], primary: bool,
       on: bool) -> bool {
    let u = g.scale;
    var clicked = false;
    var p: f32 = 0.0;
    if on {
        clicked, p = hold(g, id, r);
    } else if g.input.pressed && inside(r, g.input.at) {
        g.took = true;
    }
    let style = if primary { ROW_PRIMARY } else { ROW };
    add(g, Quad { rect: r, look: float4 { BUTTON, 20.0 * u, 0.0, p }, extra: float4 { u, style, 0.0, 0.0 } });
    let a: f32 = if on { 1.0 } else { 0.4 };
    var c = inset(r, 0.0);
    cut_left(c, 18.0 * u);
    cut_right(c, 18.0 * u);
    glyph_icon(g, center(cut_left(c, 34.0 * u), 34.0 * u, 34.0 * u), icon, style, 0.0, 0.85 * a);
    cut_left(c, 18.0 * u);
    text(g, LABEL, c, label, a, 0.0, LEFT);
    text(g, SMALL, c, note, 0.66 * a, 0.0, RIGHT);
    return clicked;
}

// A choice tile (prototypes/settings.html): a picture of size `pic` (centered across)
// with a label under it, or for kind -2 a word; lit in the glow color when on. A picture is a season's
// thumbnail (pic, a theme), or for -1 the glow's tint with a sun. A choice that isn't
// `enabled` is dimmed and takes no tap. True when it is tapped.
fn choice(g: Gui&, id: i64, r: float4, kind: i64, pic: float2, label: const u8[:], on: bool, enabled: bool) -> bool {
    let u = g.scale;
    var clicked = false;
    if enabled {
        let c, p = hold(g, id, r);
        clicked = c;
    } else if g.input.pressed && inside(r, g.input.at) {
        g.took = true;
    }
    let a: f32 = if enabled { 1.0 } else { 0.4 };
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { BUTTON, 16.0 * u, 0.0, 0.0 },
                  extra: float4 { u, if on { CHOSEN } else { CHOICE }, 0.0, 0.0 } });
    if kind == -2 {
        text(g, BODY, r, label, a, 0.0, CENTER);
        return clicked;
    }
    var c = inset(r, 6.0 * u);
    let picture = center(cut_top(c, pic.y), pic.x, pic.y);
    add(g, Quad { rect: picture, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { PICTURE, 11.0 * u, kind, 0.0 },
                  extra: float4 { u, 0.0, 0.0, 0.0 } });
    if kind == -1 { glyph_icon(g, center(picture, 30.0 * u, 30.0 * u), SUN, PLAIN, 0.0, a); }
    text(g, SMALL, c, label, a, 0.0, CENTER);
    return clicked;
}

// How text lines up in its rect.
let LEFT = 0;
let CENTER = 1;
let RIGHT = 2;

// The character at byte i of UTF-8 text s, and the byte after it; a byte that starts no
// character is taken as itself.
fn next_char(s: const u8[:], i: i64) -> i64, i64 {
    let b = s[i] as i64;
    var n = if b >= 0xF0 { 3 } else if b >= 0xE0 { 2 } else if b >= 0xC0 { 1 } else { 0 };
    guard i + n < s.len else { return b, i + 1; }
    var c = if n == 3 { b & 0x07 } else if n == 2 { b & 0x0F } else if n == 1 { b & 0x1F } else { b };
    for k in 1..n + 1 { c = (c << 6) | ((s[i + k] as i64) & 0x3F); }
    return c, i + n + 1;
}

fn glyph_of(f: Face&, c: i64) -> i64 {
    let k = glyph_index(c);
    return if k >= 0 { k } else { glyph_index(63) };
}

// How wide s is in face `face`, in pixels, with `spacing` pixels after each character.
fn text_width(g: Gui&, face: i64, s: const u8[:], spacing: f32) -> f32 {
    let f .= g.faces[face];
    var w: f32 = 0.0;
    var i = 0;
    while i < s.len {
        let c, next = next_char(s, i);
        w += f.glyphs[glyph_of(f, c)].advance + spacing;
        i = next;
    }
    return w;
}

// Text s in face `face` at opacity a, lined up in r and centered down it, `spacing`
// pixels after each character. Glyphs land on whole pixels.
fn text(g: Gui&, face: i64, r: float4, s: const u8[:], a: f32, spacing: f32, align: i64) {
    let f .= g.faces[face];
    let w = text_width(g, face, s, spacing) - spacing;
    var x = if align == LEFT { r.x } else if align == CENTER { r.x + 0.5 * (r.z - w) } else { r.x + r.z - w };
    let top = floor(r.y + 0.5 * (r.w - (f.ascent - f.descent)) + 0.5);
    var i = 0;
    while i < s.len {
        let c, next = next_char(s, i);
        let gl .= f.glyphs[glyph_of(f, c)];
        let at = floor(x + 0.5);
        if gl.box.z > gl.box.x {
            add(g, Quad { rect: float4 { at + gl.box.x, top + gl.box.y, gl.box.z - gl.box.x, gl.box.w - gl.box.y },
                          color: float4 { 1.0, 1.0, 1.0, a },
                          look:  float4 { TEXT, gl.uv.x, gl.uv.y, gl.uv.z },
                          extra: float4 { g.scale, gl.uv.w, 0.0, 0.0 } });
        }
        x += gl.advance + spacing;
        i = next;
    }
}

// Faces for tests, with no atlas: every glyph half the size wide.
fn test_faces(g: Gui&) {
    for face in FACES {
        let size = FACE_DP[face] as f32 * g.scale;
        let f .= g.faces[face];
        f.size = size;
        f.ascent = 0.8 * size;
        f.descent = -0.2 * size;
        for i in MAX_GLYPHS {
            f.glyphs[i] = Glyph { box: float4 { 0.0, 0.1 * size, 0.5 * size, 0.9 * size }, advance: 0.5 * size, .. };
        }
    }
}

// A spark: a disc of diameter d centered at c, in the glow color at opacity a, with a
// soft glow round it.
fn spark(g: Gui&, c: float2, d: f32, a: f32) {
    add(g, Quad { rect: float4 { c.x - 0.5 * d, c.y - 0.5 * d, d, d }, color: float4 { 1.0, 1.0, 1.0, a },
                  look: float4 { SPARK, 0.5 * d, 0.0, 0.0 }, extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
}
