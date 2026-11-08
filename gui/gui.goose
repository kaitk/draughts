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

// The layout's shorter side in dp: 800, or what the development flag --dp sets, to try
// how a phone looks with fewer dp across (task 030).
var short_dp: f32 = 800.0;

// A floor on the scale in physical size, F × the display's scale (Android's density /
// 160): a phone's dp then stays at least F of Android's, where the short side / 800
// would make them smaller. F is 0.75 (picked 2026-11-08): the Pixel 7a lays out about 549
// dp across; 0 would keep the scale the short side's alone. The app sets display_scale on Android, and the development flags
// --density-floor F and --display-scale S try them (docs/development.md).
let DENSITY_FLOOR = 0.75;
var density_floor: f32 = DENSITY_FLOOR;
var display_scale: f32 = 0.0;

// The layout's scale, pixels a dp, on a screen width × height pixels: from the whole
// screen's shorter side, its insets included, so it is the same in both orientations.
fn scale_of(width: f32, height: f32) -> f32 { max(min(width, height) / short_dp, density_floor * display_scale) }

// What a quad is, as the UI shader draws it.
let GLASS = 0;              // a glass panel, with its shadow
let BUTTON = 1;             // a glass tile, with its shadow; look.w: how far it is pressed
let ICON = 2;               // a line icon on a 24-unit grid; look.z: which
let FILL = 3;               // a plain rounded rect in `color`
let TEXT = 4;               // a glyph from the font atlas in the text color; look.yzw, extra.y: its uv
let PICTURE = 5;            // a season's thumbnail (look.z: its theme), or the glow's tint for -1
let MINI = 6;               // a small board at the start; look.z: squares per side, look.w: rows of men
let RING = 7;               // a hold's ring round a tile, filled clockwise from the top; look.z: how far, 0..1
let FACE = 8;               // a player's badge on a disc; look.z: which, -1 for +; look.w: lit

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
let CLOCK_RUN = 9;          // the running clock: the glow color at 18%, a 2 dp glow border
let CLOCK_IDLE = 10;        // a clock that waits: white at 6%, a border at 12%
let CLOCK_LOW = 11;         // the running clock under ten seconds: the forced-capture red

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
let HOME = 14;              // the game's way home: a house
let CLOCK = 15;             // no clock: a stopwatch
let STAR = 16;              // a star won, filled
let STAR_OFF = 17;          // a star still at stake or lost, outlined
let LOCK = 18;              // a tier not yet open
let CROWN = 19;             // the puzzles' goals: become a king,
let SHIELD = 20;            // and the only safe move (TARGET for a capture)
let CLOSE = 21;             // home's way out: an X
let PLUS = 22;              // a new player
let PENCIL = 23;            // editing the players
let CHECK = 24;             // done
let TRASH = 25;             // removing a player
let BOOK = 26;              // the puzzles' themes: Learn, an open book,
let JUMPS = 27;             // captures, two men and a double jump,
let KING = 28;              // king shots, a crown in a ring (crowning is CROWN, shots TARGET)
let LEVEL = 29;             // a theme's levels, 29 to 31: three rising bars, 1 to 3 of them filled

// Text faces (rendering.md, "Fonts"): one size each, in dp, baked by the app at the
// screen's pixel size.
let TITLE = 0;              // the wordmark
let LABEL = 1;              // menu rows
let HEADING = 2;            // a settings group's title
let BODY = 3;               // a choice's word
let SMALL = 4;              // notes, a picture's label
let FIGURES = 5;            // a clock's time
let FACES = 6;
let FACE_DP = [64.0, 30.0, 24.0, 20.0, 17.0, 36.0];

// The forced-capture red (rendering.md, "States"), for a clock under ten seconds.
let RED = float4 { 1.0, 0.353, 0.29, 1.0 };

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

// The characters a face holds when it is baked with only those it draws (the title and
// the clock's figures, shell::face_chars), each once, in order. Characters the faces
// never hold aren't added: they are drawn as '?', which a set always holds.
let MAX_CHARS = 64;
type Chars = u32[..MAX_CHARS];

fn holds(set: Chars&, c: i64) -> bool {
    for x in set { if x == c { return true; } }
    return false;
}

// Adds s's characters to set.
fn add_chars(set: Chars&, s: const u8[:]) {
    if !holds(set, '?') { set.push('?'); }
    var i = 0;
    while i < s.len {
        let c, next = next_char(s, i);
        i = next;
        guard glyph_index(c) >= 0 && !holds(set, c) else { continue; }
        assert(set.len < MAX_CHARS);
        set.push(c as u32);
    }
    sort(set) { a, b => a < b };
}

// One quad for the UI shader.
struct Quad {
    rect:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x, y, width, height in pixels
    color: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // straight alpha
    look:  float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // kind, corner radius in pixels, icon, pressed 0..1
    extra: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x: pixels per dp; y: PLAIN..CLOCK_LOW; z: text in `color` (1), + ON_BOARD; w: faded out, 0..1
}

// The pointer this frame, and what was typed while text input is on. A quick tap can be
// pressed and released in one frame.
let MAX_TYPED = 16;
let ERASE = 8;              // in typed: Backspace
let ENTER = 13;             // and Return
struct Input {
    at:       float2           = float2 { 0.0, 0.0 },
    down:     bool             = false,
    pressed:  bool             = false,
    released: bool             = false,
    typed:    u32[..MAX_TYPED] = [],    // characters in order, ERASE and ENTER among them
}

// A widget's state across frames: whether it is down and when that last changed.
struct Slot {
    id:    i64  = 0,
    down:  bool = false,
    since: f64  = -1.0,
}

struct Gui {
    scale:   f32               = 1.0,
    now:     f64               = 0.0,
    input:   Input             = Input {},
    active:  i64               = 0,     // the widget the pointer went down on, or 0
    took:    bool              = false, // whether this press landed on the UI, not the board
    acted:   bool              = false, // whether a widget was clicked this frame
    holding: bool              = false, // whether a hold (hold_tile) is filling this frame
    quads:   Quad[..MAX_QUADS] = [],
    slots:   Slot[MAX_IDS]     = [Slot {}; MAX_IDS],
    faces:   Face[FACES]       = [Face {}; FACES],
    pointer: Input             = Input {}, // the frame's pointer, kept while input is off (listen)
    // The screen's edges outside its safe area, in pixels: left, top, right, bottom (a
    // phone's camera cutout and gesture bar). Taps and words stay inside (safe); the
    // photograph, and glass that runs off the screen (bleed), reach the edges.
    insets: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
}

// The safe area of a screen width × height pixels: where the screens lay out.
fn safe(g: Gui&, width: f32, height: f32) -> float4 {
    let e = g.insets;
    return float4 { e.x, e.y, width - e.x - e.z, height - e.y - e.w };
}

// r, laid out in the safe area `area`, carried on to the screen's edges on each side
// where it reaches the area's: a glass column or sheet that runs off the screen.
fn bleed(g: Gui&, r: float4, area: float4) -> float4 {
    let e = g.insets;
    var b = r;
    if r.x <= area.x + 0.5 {
        b.x -= e.x;
        b.z += e.x;
    }
    if r.y <= area.y + 0.5 {
        b.y -= e.y;
        b.w += e.y;
    }
    if r.x + r.z >= area.x + area.z - 0.5 { b.z += e.z; }
    if r.y + r.w >= area.y + area.w - 0.5 { b.w += e.w; }
    return b;
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
    if !g.pointer.down && !g.pointer.pressed { g.active = 0; }
    if input.pressed { g.took = false; }
    g.acted = false;
    g.holding = false;
    g.input = input;
    g.pointer = input;
    g.scale = scale;
    g.now = now;
    g.quads.clear();
}

// Whether what is declared from here on takes the pointer: not a screen a transition
// leaves, which is declared with no pointer at all.
fn listen(g: Gui&, on: bool) { g.input = if on { g.pointer } else { Input { at: float2 { -1.0e9, -1.0e9 }, .. } }; }

// Fades quads first..last (as g.quads.len counted them) to `opacity` and moves them by
// `offset` pixels, whole ones, so glyphs stay a texel to a pixel: a screen in a
// transition. Its taps stay where it is at rest. A quad faded already (a win's card
// coming in) fades further.
fn fade(g: Gui&, first: i64, last: i64, opacity: f32, offset: float2) {
    let d = float2 { floor(offset.x + 0.5), floor(offset.y + 0.5) };
    for i in first..last {
        let q .= g.quads[i];
        q.rect.x += d.x;
        q.rect.y += d.y;
        q.extra.w = 1.0 - (1.0 - q.extra.w) * opacity;
    }
}

// Marks quads first..last as lying on the board, as a win's card does: the hole a
// transition makes in the UI where the board passes leaves them (app/widgets.goose).
let ON_BOARD = 2.0;         // added to a quad's extra.z
fn on_board(g: Gui&, first: i64, last: i64) { for i in first..last { g.quads[i].extra.z += ON_BOARD; } }

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

// Whether any widget is still going down or up, or a hold filling; the app draws while
// one is.
fn animating(g: Gui&) -> bool {
    if g.holding { return true; }
    for s in g.slots { if s.id != 0 && s.since >= 0.0 && g.now < s.since + PRESS { return true; } }
    return false;
}

// A glass panel. A press on it belongs to the UI.
fn panel(g: Gui&, r: float4) { glass(g, r, 28.0); }

// A press that lands on r belongs to the UI and never reaches the board.
fn take(g: Gui&, r: float4) { if g.input.pressed && inside(r, g.input.at) { g.took = true; } }

// A glass panel with corners of `radius` dp.
fn glass(g: Gui&, r: float4, radius: f32) {
    take(g, r);
    add(g, Quad { rect: r, look: float4 { GLASS, radius * g.scale, 0.0, 0.0 },
                  extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
}

// A plain rounded rect, such as a rule; `radius` in pixels.
fn fill(g: Gui&, r: float4, color: float4, radius: f32) {
    add(g, Quad { rect: r, color: color, look: float4 { FILL, radius, 0.0, 0.0 },
                  extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
}

// A rounded rect in the theme's glow color at opacity a, such as a progress bar.
fn glow_fill(g: Gui&, r: float4, a: f32, radius: f32) {
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { FILL, radius, 1.0, 0.0 },
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

// As hold for a widget that is on; one that is off takes a press but never goes down.
fn hold_if(g: Gui&, id: i64, r: float4, on: bool) -> bool, f32 {
    guard on else {
        take(g, r);
        return false, 0.0;
    }
    return hold(g, id, r);
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

// An icon alone, `size` dp across at 85% as a row's, centered in its tap r (home's gear
// in portrait, rendering.md, "Home"): clear until pressed, then lit round as a pressed
// row is. True when it is tapped.
fn icon_button(g: Gui&, id: i64, r: float4, icon: i64, size: f32) -> bool {
    let clicked, p = hold(g, id, r);
    add(g, Quad { rect: r, look: float4 { BUTTON, 0.5 * min(r.z, r.w), 0.0, p }, extra: float4 { g.scale, ROW, 0.0, 0.0 } });
    let s = size * g.scale * (1.0 - 0.04 * p);
    glyph_icon(g, center(r, s, s), icon, ROW, p, 0.85);
    return clicked;
}

// A player's face in r (their badge, players.goose's ANIMALS by index, drawn by
// app/widgets.goose's badge(); or -1 for +, a faint disc), at opacity a, with the glow
// ring when `lit`.
fn face(g: Gui&, r: float4, animal: i64, a: f32, lit: bool) {
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { FACE, 0.0, animal, if lit { 1.0 } else { 0.0 } },
                  extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
    if animal < 0 {
        let s = 0.44 * min(r.z, r.w);
        glyph_icon(g, center(r, s, s), PLUS, PLAIN, 0.0, a);
    }
}

// A tile that does its thing when held `seconds` (rendering.md, "Controls"): a ring fills
// round it while it is held, in the glow color or, `red`, the forced-capture red; let
// go early and nothing happens, a release being no tap. Returns true on the frame the
// ring is full, after which the press does nothing more until the pointer is lifted, and
// how far the ring is, 0..1. The caller draws the tile's face over it.
fn hold_tile(g: Gui&, id: i64, r: float4, radius: f32, seconds: f64, red: bool) -> bool, f32 {
    let unused, p = hold(g, id, r);
    let s .= g.slots[slot(g, id)];
    let held = g.active == id && g.input.down && inside(r, g.input.at) && s.down;
    let k = if held { clamp((g.now - s.since) / seconds, 0.0, 1.0) as f32 } else { 0.0 };
    add(g, Quad { rect: r, look: float4 { BUTTON, radius * g.scale, 0.0, p }, extra: float4 { g.scale, PLAIN, 0.0, 0.0 } });
    guard held else { return false, 0.0; }
    if k >= 1.0 {
        g.active = 0;
        g.acted = true;
        set_down(g, id, false);
        return true, 1.0;
    }
    g.holding = true;
    add(g, Quad { rect: r, look: float4 { RING, radius * g.scale, k, 0.0 },
                  extra: float4 { g.scale, if red { 1.0 } else { 0.0 }, 0.0, 0.0 } });
    return false, k;
}

// Text s in face `face` in `color`, lined up in r and centered down it.
fn colored(g: Gui&, face: i64, r: float4, s: const u8[:], color: float4, align: i64) {
    write(g, face, r, s, color, true, 0.0, align, false);
}

// An X alone in its round tap r (home's way out, rendering.md, "Home"), `size` dp across
// at 80% with strokes of 2.8 grid units: nothing drawn round it until pressed, then white
// at 10% and a faint 1 px ring. True when it is tapped.
fn bare_x(g: Gui&, id: i64, r: float4, icon: i64, size: f32) -> bool {
    let clicked, p = hold(g, id, r);
    let k = 1.0 - 0.04 * p;
    let d = 0.5 * min(r.z, r.w);
    add(g, Quad { rect: center(r, r.z * k, r.w * k), look: float4 { BUTTON, d * k, 1.0, p },
                  extra: float4 { g.scale, ROW, 0.0, 0.0 } });
    let s = size * g.scale * k;
    glyph_icon(g, center(r, s, s), icon, ROW, p, 0.8, 2.8);
    return clicked;
}

// A line or filled icon in r, in the text color at opacity a (the glow color for ON).
fn glyph_icon(g: Gui&, r: float4, icon: i64, style: i64, p: f32, a: f32, stroke: f32 = 0.0) {
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { ICON, stroke, icon, p },
                  extra: float4 { g.scale, style, 0.0, 0.0 } });
}

// A menu row (prototypes/home.html): an icon, a label, and a note at the right in
// the dimmer small face, in a 20 dp rounded row that lights while pressed. A row that
// is off is drawn at 40% and can't be pressed. True when it is tapped.
fn row(g: Gui&, id: i64, r: float4, icon: i64, label: const u8[:], note: const u8[:], primary: bool,
       on: bool) -> bool {
    let u = g.scale;
    let clicked, p = hold_if(g, id, r, on);
    let style = if primary { ROW_PRIMARY } else { ROW };
    add(g, Quad { rect: r, look: float4 { BUTTON, 20.0 * u, 0.0, p }, extra: float4 { u, style, 0.0, 0.0 } });
    let a: f32 = if on { 1.0 } else { 0.4 };
    var c = r;
    cut_left(c, 18.0 * u);
    cut_right(c, 18.0 * u);
    glyph_icon(g, center(cut_left(c, 34.0 * u), 34.0 * u, 34.0 * u), icon, style, 0.0, 0.85 * a);
    cut_left(c, 18.0 * u);
    text(g, LABEL, c, label, a, 0.0, LEFT);
    text(g, SMALL, c, note, 0.66 * a, 0.0, RIGHT);
    return clicked;
}

// A choice tile (prototypes/settings.html): a picture of size `pic` (centered across)
// with a label under it, lit in the glow color when on. The picture is a season's
// thumbnail (kind, a theme), or for -1 the glow's tint with a sun. A choice that isn't
// `enabled` is dimmed and takes no tap. True when it is tapped.
fn choice(g: Gui&, id: i64, r: float4, kind: i64, pic: float2, label: const u8[:], on: bool, enabled: bool) -> bool {
    let u = g.scale;
    let clicked, unused = hold_if(g, id, r, enabled);
    let a: f32 = if enabled { 1.0 } else { 0.4 };
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { BUTTON, 16.0 * u, 0.0, 0.0 },
                  extra: float4 { u, if on { CHOSEN } else { CHOICE }, 0.0, 0.0 } });
    var c = inset(r, 6.0 * u);
    let picture = center(cut_top(c, pic.y), pic.x, pic.y);
    add(g, Quad { rect: picture, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { PICTURE, 11.0 * u, kind, 0.0 },
                  extra: float4 { u, 0.0, 0.0, 0.0 } });
    if kind == -1 { glyph_icon(g, center(picture, 30.0 * u, 30.0 * u), SUN, PLAIN, 0.0, a); }
    text(g, SMALL, c, label, a, 0.0, CENTER);
    return clicked;
}

// How a labelled tile lays out its icon and word.
let BESIDE = 0;             // the icon, then the word, from the left
let MIDDLE = 1;             // the icon and the word side by side, centered
let STACKED = 2;            // the icon over the word, centered
let LABEL_PAD = 8.0;        // dp a labelled tile's word keeps from its sides at least
let INDENT = 14.0;          // dp before the icon BESIDE

// A glass tile with an icon `size` dp across and a word in face `face`
// (prototypes/game.html): true when it is tapped. `style` lights it (CHOSEN, a puzzle's
// next once it is solved); one that isn't `on` is drawn at 35% and takes no tap.
fn labelled(g: Gui&, id: i64, r: float4, icon: i64, size: f32, label: const u8[:], face: i64,
            arrange: i64, style: i64 = PLAIN, on: bool = true) -> bool {
    let u = g.scale;
    let clicked, p = hold_if(g, id, r, on);
    let a: f32 = if on { 1.0 } else { 0.35 };
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { BUTTON, 22.0 * u, 0.0, p },
                  extra: float4 { u, style, 0.0, 0.0 } });
    let s = size * u;
    // The word keeps LABEL_PAD from the tile's sides, in a smaller face where it is too
    // wide for its own.
    if arrange == STACKED {
        let f .= g.faces[face];
        let line = f.ascent - f.descent;
        let gap = 8.0 * u;
        var c = center(r, r.z, s + gap + line);
        glyph_icon(g, center(cut_top(c, s), s, s), icon, PLAIN, p, a);
        cut_top(c, gap);
        text(g, fitting(g, face, label, r.z - 2.0 * LABEL_PAD * u), c, label, a, 0.0, CENTER);
        return clicked;
    }
    let gap = 12.0 * u;
    let shown = fitting(g, face, label, r.z - labelled_width(g, size, "", face, arrange));
    var c = r;
    if arrange == BESIDE {
        cut_left(c, INDENT * u);
    } else {
        let w = s + gap + text_width(g, shown, label);
        c = center(r, w, r.w);
    }
    glyph_icon(g, center(cut_left(c, s), s, s), icon, PLAIN, p, a);
    cut_left(c, gap);
    text(g, shown, c, label, a, 0.0, LEFT);
    return clicked;
}

// How wide a labelled tile must be for its icon `size` dp across and its word in face
// `face` side by side, BESIDE or MIDDLE, keeping LABEL_PAD at the sides.
fn labelled_width(g: Gui&, size: f32, label: const u8[:], face: i64, arrange: i64) -> f32 {
    let lead = if arrange == BESIDE { INDENT } else { LABEL_PAD };
    return (lead + size + 12.0 + LABEL_PAD) * g.scale + text_width(g, face, label);
}

// The largest of the faces from `face` down to SMALL that fits `text` in w pixels.
fn fitting(g: Gui&, face: i64, text: const u8[:], w: f32) -> i64 {
    var f = face;
    while f < SMALL && text_width(g, f, text) > w { f++; }
    return f;
}

// A setup tile (prototypes/home.html): a picture `pic` dp tall over its label, and a
// note under that in the small face, centered; lit as a choice when on, dimmed and
// taking no tap when not enabled. Returns whether it was tapped and where the picture
// goes, for the caller to draw.
fn pick(g: Gui&, id: i64, r: float4, pic: f32, label: const u8[:], note: const u8[:], on: bool,
        enabled: bool) -> bool, float4 {
    let u = g.scale;
    let clicked, unused = hold_if(g, id, r, enabled);
    let a: f32 = if enabled { 1.0 } else { 0.4 };
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { BUTTON, 16.0 * u, 0.0, 0.0 },
                  extra: float4 { u, if on { CHOSEN } else { CHOICE }, 0.0, 0.0 } });
    let body = g.faces[BODY].ascent - g.faces[BODY].descent;
    let small = g.faces[SMALL].ascent - g.faces[SMALL].descent;
    let p = pic * u;
    let gap = 4.0 * u;
    var h: f32 = 0.0;
    if p > 0.0 { h += p + gap; }
    if label.len > 0 { h += body; }
    if note.len > 0 { h += small + (if label.len > 0 { gap } else { 0.0 }); }
    var c = center(r, r.z, h);
    var picture = c;
    if p > 0.0 {
        picture = cut_top(c, p);
        cut_top(c, gap);
    }
    if label.len > 0 {
        // A word too wide for the tile, as a translation's may be, takes the small face.
        let face = if text_width(g, BODY, label) > r.z - 8.0 * u { SMALL } else { BODY };
        text(g, face, cut_top(c, body), label, a, 0.0, CENTER);
        cut_top(c, gap);
    }
    if note.len > 0 { text(g, SMALL, cut_top(c, small), note, 0.66 * a, 0.0, CENTER); }
    return clicked, picture;
}

// A small board of n × n squares at the start of a game, `rows` rows of men a side,
// centered in r at `size` pixels, at opacity a.
fn mini(g: Gui&, r: float4, size: f32, n: i64, rows: i64, a: f32) {
    add(g, Quad { rect: center(r, size, size), color: float4 { 1.0, 1.0, 1.0, a },
                  look: float4 { MINI, 2.0 * g.scale, n, rows }, extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
}

// A level's pips: three dots 10 dp across, `full` of them lit, centered in r.
fn pips(g: Gui&, r: float4, full: i64, a: f32) {
    let u = g.scale;
    for i in 3 {
        let o: f32 = if i < full { 0.9 } else { 0.25 };
        fill(g, cell(r, 3, 1, 10.0 * u, 10.0 * u, 5.0 * u, i), float4 { 1.0, 1.0, 1.0, o * a }, 5.0 * u);
    }
}

// A clock's tile (rendering.md, "Clocks"): radius 20 dp, lit in the glow color while it
// runs, red when low, faint while it waits. It takes a press, so a press on it never
// reaches the board.
fn clock_tile(g: Gui&, r: float4, style: i64) {
    take(g, r);
    add(g, Quad { rect: r, look: float4 { BUTTON, 20.0 * g.scale, 0.0, 0.0 }, extra: float4 { g.scale, style, 0.0, 0.0 } });
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

// How wide s is in face `face`, in pixels.
fn text_width(g: Gui&, face: i64, s: const u8[:]) -> f32 {
    let f .= g.faces[face];
    var w: f32 = 0.0;
    var i = 0;
    while i < s.len {
        let c, next = next_char(s, i);
        w += f.glyphs[glyph_of(f, c)].advance;
        i = next;
    }
    return w;
}

// Text s in face `face` at opacity a, lined up in r and centered down it, `spacing`
// pixels after each character. Glyphs land on whole pixels.
fn text(g: Gui&, face: i64, r: float4, s: const u8[:], a: f32, spacing: f32, align: i64) {
    write(g, face, r, s, float4 { 1.0, 1.0, 1.0, a }, false, spacing, align, false);
}

// The widest digit's advance in a face, the cell each digit takes in tabular figures.
fn figure_width(g: Gui&, face: i64) -> f32 {
    let f .= g.faces[face];
    var w: f32 = 0.0;
    for d in 10 { w = max(w, f.glyphs[glyph_of(f, '0' + d)].advance); }
    return w;
}

// Figures, such as a clock's m:ss, in tabular form: each digit centered in a cell as
// wide as the widest, so the time doesn't shift as it counts. In the text color at
// opacity a, or in the forced-capture red.
fn figures(g: Gui&, face: i64, r: float4, s: const u8[:], a: f32, red: bool, align: i64) {
    let color = if red { float4 { RED.x, RED.y, RED.z, a } } else { float4 { 1.0, 1.0, 1.0, a } };
    write(g, face, r, s, color, red, 0.0, align, true);
}

fn write(g: Gui&, face: i64, r: float4, s: const u8[:], color: float4, own: bool, spacing: f32, align: i64,
         tabular: bool) {
    let f .= g.faces[face];
    let cell = if tabular { figure_width(g, face) } else { 0.0 };
    var w: f32 = 0.0;
    var i = 0;
    while i < s.len {
        let c, next = next_char(s, i);
        let adv = f.glyphs[glyph_of(f, c)].advance;
        w += (if tabular && c >= '0' && c <= '9' { cell } else { adv }) + spacing;
        i = next;
    }
    w -= spacing;
    var x = if align == LEFT { r.x } else if align == CENTER { r.x + 0.5 * (r.z - w) } else { r.x + r.z - w };
    let top = floor(r.y + 0.5 * (r.w - (f.ascent - f.descent)) + 0.5);
    let tint: f32 = if own { 1.0 } else { 0.0 };
    i = 0;
    while i < s.len {
        let c, next = next_char(s, i);
        let gl .= f.glyphs[glyph_of(f, c)];
        let digit = tabular && c >= '0' && c <= '9';
        let step = if digit { cell } else { gl.advance };
        let shift = if digit { 0.5 * (cell - gl.advance) } else { 0.0 };
        let at = floor(x + shift + 0.5);
        if gl.box.z > gl.box.x {
            add(g, Quad { rect: float4 { at + gl.box.x, top + gl.box.y, gl.box.z - gl.box.x, gl.box.w - gl.box.y },
                          color: color,
                          look:  float4 { TEXT, gl.uv.x, gl.uv.y, gl.uv.z },
                          extra: float4 { g.scale, gl.uv.w, tint, 0.0 } });
        }
        x += step + spacing;
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
