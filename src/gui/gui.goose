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
import .focus;

let MAX_QUADS = 512;
let MAX_IDS = 32;
let MAX_SPOTS = 128;        // the controls a frame offers the keys' focus (Spot)
let MAX_GROUPS = 8;         // the groups they come in (gui::group)
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

// On a desktop (the Mac, Windows), a ceiling on the scale in physical size: DESKTOP_DP
// points a dp, the display's scale × DESKTOP_DP pixels, so a large window or a full
// screen gives its room to the board and keeps the controls the size a mouse wants,
// where the short side / 800 would grow them as for a hand. 0.75 (2026-11-11): an 88 dp
// row is 66 points, a 17 dp note about 13. The ceiling grows with the window's shorter
// side, from DESKTOP_DP at DESKTOP_SMALL points to DESKTOP_DP_LARGE at DESKTOP_LARGE (a
// 27" screen's full window), as the board's frame does (panel::framed_in): at 0.75 the
// controls looked too small on a 27" screen, seen from further away (task 068, the user
// 2026-11-11). The app sets desktop_scale on a desktop unless --touch asks for a touch
// screen's sizes; 0 is no ceiling (a phone, a tablet, the tests).
let DESKTOP_DP = 0.75;
let DESKTOP_DP_LARGE = 0.9;
let DESKTOP_SMALL = 1000.0;
let DESKTOP_LARGE = 1440.0;
var desktop_scale: f32 = 0.0;

// The layout's scale, pixels a dp, on a screen width × height pixels: from the whole
// screen's shorter side, its insets included, so it is the same in both orientations.
fn scale_of(width: f32, height: f32) -> f32 {
    let s = max(min(width, height) / short_dp, density_floor * display_scale);
    guard desktop_scale > 0.0 else { return s; }
    let k = clamp((min(width, height) / desktop_scale - DESKTOP_SMALL) / (DESKTOP_LARGE - DESKTOP_SMALL), 0.0, 1.0);
    return min(s, (DESKTOP_DP + (DESKTOP_DP_LARGE - DESKTOP_DP) * k) * desktop_scale);
}

// What a quad is, as the UI shader draws it.
let GLASS = 0;              // a glass panel, with its shadow
let BUTTON = 1;             // a glass tile, with its shadow; look.w: how far it is pressed
let ICON = 2;               // a line icon on a 24-unit grid; look.z: which
let FILL = 3;               // a plain rounded rect in `color`
let TEXT = 4;               // a glyph from the font atlas in the text color; look.yzw, extra.y: its uv
let PICTURE = 5;            // a thumbnail (look.z: a season's, its fade's, the theme's; widgets.goose), or the glow's tint for -1
let MINI = 6;               // a small board at the start; look.z: squares per side, look.w: rows of men
let RING = 7;               // a hold's ring round a tile, filled clockwise from the top; look.z: how far, 0..1, look.w: its width in dp (0: 4)
let FACE = 8;               // a player's badge on a disc; look.z: which, -1 for +; look.w: lit
let FLOAT = 9;              // a floating button's disc (the 3D board's camera); look.z: 1 lit, + 2 a dot; look.w: pressed

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
let CLOCK_LOW = 11;         // the running clock at 20 seconds or under: the forced-capture red
let CLOCK_WARN = 12;        // the running clock under a minute: autumn's gold
let ROW_OUTLINE = 13;       // a menu row with a 1 dp border at 25% (home's new game beside continue)

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
let VIEW_TOP = 32;          // the 3D board's camera: the top view, a board from above,
let VIEW_LOW = 33;          // the rest angle, a board in perspective,
let ZOOM_IN = 34;           // the zoom, a magnifier with + or -,
let ZOOM_OUT = 35;
let SHOWCASE = 36;          // and the showcase, a board on an orbit
let EYE = 37;               // the lookout on: an open eye
let EYE_OFF = 38;           // and off: the eye struck through
let FIRST = 39;             // a replay's steps (task 078): to the start, a chevron at a bar,
let PREV = 40;              // back one, a chevron left,
let FWD = 41;               // on one, a chevron right,
let LAST = 42;              // and to the end, a chevron at a bar
let CHEVRON_UP = 43;        // the moves' line and sheet (task 078): a chevron up, and down;
let CHEVRON_DOWN = 44;      // FWD and PREV, the replay's, point right and left
let NEW_GAME = 45;          // home's new game: a plus in a ring
let TURNS = 46;             // the setup's board turning to who plays: two arcs chasing round,
let STAYS = 47;             // and staying: a board with an arrow up it

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

// The forced-capture red (rendering.md, "States"), for a clock at 20 seconds or under,
// and autumn's glow gold (0xffd75a), for one under a minute.
let RED = float4 { 1.0, 0.353, 0.29, 1.0 };
let GOLD = float4 { 1.0, 0.843, 0.353, 1.0 };

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
    extra: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },  // x: pixels per dp; y: PLAIN..CLOCK_WARN; z: text in `color` (1), + ON_BOARD; w: faded out, 0..1
}

// The pointer this frame, and what was typed while text input is on. A quick tap can be
// pressed and released in one frame. The keys' moves (focus) come in `step`, one of
// STEP_NONE..STEP_RIGHT, `confirm`, Enter pressing the focused control, and `held`, Enter
// down, which fills a focused hold tile as a held press does.
let MAX_TYPED = 16;
let ERASE = 8;              // in typed: Backspace
let ENTER = 13;             // and Return
let STEP_NONE = 0;
let STEP_UP = 1;
let STEP_DOWN = 2;
let STEP_LEFT = 3;
let STEP_RIGHT = 4;
struct Input {
    at:       float2           = float2 { 0.0, 0.0 },
    down:     bool             = false,
    pressed:  bool             = false,
    released: bool             = false,
    typed:    u32[..MAX_TYPED] = [],    // characters in order, ERASE and ENTER among them
    wheel:    f32              = 0.0,   // a mouse wheel's or trackpad's turn this frame, up positive
    step:     i64              = STEP_NONE, // an arrow key pressed this frame
    confirm:  bool             = false, // Enter or Space pressed this frame
    held:     bool             = false, // Enter or Space down this frame
    tab:      i64              = 0,     // Tab pressed this frame, 1, or with Shift, -1: the next group (gui::group)
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
    // The mouse's hover on a desktop (desktop_scale > 0, hover): the tile lit under the
    // pointer, fading in from hover_at over PRESS, and the one it left, fading out from
    // left_at; `under` is the topmost tile the pointer is over as this frame declares
    // them, which the next frame's begin makes the hovered one.
    hovered:  i64 = 0,
    hover_at: f64 = -1.0,
    left:     i64 = 0,
    left_at:  f64 = -1.0,
    under:    i64 = 0,
    // The screen's edges outside its safe area, in pixels: left, top, right, bottom (a
    // phone's camera cutout and gesture bar). Taps and words stay inside (safe); the
    // photograph, and glass that runs off the screen (bleed), reach the edges.
    insets: float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    // The screen's one vertical scroll (scroll_begin): which list, its offset in pixels,
    // the press it may become a drag from, and whether it has.
    scroll: Scroll = Scroll {},
    // The keys' focus (rendering.md, "Keys"): the control an arrow key moved to, lit as
    // the mouse's hover lights one, which Enter presses; 0 while the mouse or a touch
    // leads. `spots` are the controls this frame offers it, in the order declared, which
    // the next frame's begin moves the focus among; `deaf` while a screen a transition
    // leaves is declared (listen), whose controls offer none. `focused` is the focused
    // control's spot as the last frame laid it out, which its list scrolls into view.
    focus:   i64               = 0,
    spots:   Spot[..MAX_SPOTS] = [],
    focused: Spot              = Spot {},
    deaf:    bool              = false,
    ring:    bool              = false, // the focused control was just held: its next quad gets the ring
    // The group controls are offered in now (gui::group), and the control each group had
    // the focus on last, which Tab comes back to; the focused cell of a grid (gui::grid),
    // y * cells + x, and the grid it is of.
    group:       i64             = 0,
    group_focus: i64[MAX_GROUPS] = [0; MAX_GROUPS],
    cell:        i64             = 0,
    cell_of:     i64             = 0,
    // Left and Right taken by the screen for its own (claim_sideways, a replay's steps):
    // set by the frame that declares it, read by the next frame's begin, which then moves
    // no focus for them and leaves them in `pointer.step`.
    sideways: bool = false,
}

// The keys' focus ring (rendering.md, "Controls"): RING_W dp in the glow color, RING_GAP
// dp outside the focused control's own shape.
let RING_W = 2.0;
let RING_GAP = 3.0;

// What a screen's frame asks for (gui is what every screen imports): the asks the screens
// share, numbered once, here. They are negative: a screen's own asks are 0 and up, as is
// the index of a puzzle the puzzles to pick from return.
let ASK_NOTHING = -1;
let ASK_BACK = -2;          // the screen's back: home, the menu, the puzzles, where it came from
let ASK_SETTINGS = -3;
let ASK_CHANGED = -4;       // a choice changed, to write
let ASK_SHOWN = -5;         // a part of the screen shown or hidden: drawn again, nothing kept
let ASK_RESTART = -6;

// Widget ids (slot keeps a widget's press by its id, scroll_begin a list's offset): each
// screen numbers its widgets from its base, inside its own range, so two screens declared
// in one frame (a transition) never share an id. IDS, under SCROLL_ID below, lists the
// bases in order, IDS_SPAN how many ids each range holds; test/gui/ids checks no range
// runs into the next.
let PANEL_IDS = 110;        // the game's and a puzzle's panels: the bar, the play, the camera's buttons
let CARD_IDS = 200;         // the game's end cards
let HOME_IDS = 300;         // home's menu and a new game's setup
let SETTINGS_IDS = 400;
let WHO_IDS = 500;          // who's playing, and a player's sheet
let PICKER_IDS = 600;       // the puzzles to pick from: the library, a theme's page, its puzzles
let RESULTS_IDS = 1300;     // the games played (task 074), a row a game from 11 past the base
let REPLAY_IDS = 1600;      // a past game's replay (task 078), a move a tap from 10 past the base

// One scrolling list a frame (task 050; rendering.md, "Scrolling"): what scroll_begin
// keeps across frames. A plain drag and the wheel, no fling.
let SCROLL_ID = 9000;       // the drag's id while it holds the pointer
let IDS = [PANEL_IDS, CARD_IDS, HOME_IDS, SETTINGS_IDS, WHO_IDS, PICKER_IDS, RESULTS_IDS, REPLAY_IDS, SCROLL_ID];
let IDS_SPAN = [20, 2, 71, 72, 43, 600, 211, 522, 1];
let SLOP = 10.0;            // dp a press moves before it is a drag, not a tap
let CLIP = 4.0;             // added to a quad's extra.z: drawn only inside the list's view
let WHEEL = 40.0;           // dp a wheel's step scrolls
struct Scroll {
    id:       i64    = 0,     // the list the offset is of; another list starts at its top
    offset:   f32    = 0.0,
    max:      f32    = 0.0,
    view:     float4 = float4 { 0.0, 0.0, 0.0, 0.0 },
    from:     float2 = float2 { 0.0, 0.0 },
    start:    f32    = 0.0,
    armed:    bool   = false,
    dragging: bool   = false,
    first:    i64    = 0,
    saved:    Input  = Input {},
    open:     bool   = false, // between scroll_begin and scroll_end: the controls offered are in the list
}

// List `id` (any nonzero number, unique to the list), `content` pixels tall, shown in
// `view` and scrolled by a drag that starts in it or by the wheel over it: returns the
// offset to lay it out by (its rows at y - offset), whole pixels. A press becomes a drag
// once it moves SLOP dp up or down; until then it is a tap on what is under it, and once it
// is, the widget it went down on lets go without clicking. What is declared up to
// scroll_end is drawn only inside `view` and takes the pointer only there. A list other
// than the last one declared starts at its top. A control in it with the keys' focus that
// lies outside the view, by its rect the last frame, is scrolled into it, PAD dp clear of
// its edge.
fn scroll_begin(g: Gui&, id: i64, view: float4, content: f32) -> f32 {
    let s .= g.scroll;
    let i = g.input;
    if s.id != id {
        s.id = id;
        s.offset = 0.0;
        s.armed = false;
        s.dragging = false;
    }
    s.view = view;
    s.max = max(0.0, content - view.w);
    if i.pressed && inside(view, i.at) {
        s.armed = true;
        s.from = i.at;
        s.start = s.offset;
    }
    if s.armed && i.down && !s.dragging && abs(i.at.y - s.from.y) > SLOP * g.scale && s.max > 0.0 {
        s.dragging = true;
        g.active = SCROLL_ID;
        g.took = true;
    }
    if s.dragging && i.down { s.offset = s.start - (i.at.y - s.from.y); }
    if !i.down {
        s.armed = false;
        s.dragging = false;
    }
    if inside(view, i.at) { s.offset -= i.wheel * WHEEL * g.scale; }
    let f = g.focused;
    if g.focus != 0 && f.id == g.focus && f.list == id {
        let m = min(PAD * g.scale, max(0.0, 0.5 * (view.w - f.rect.w)));
        if f.rect.y < view.y + m { s.offset -= view.y + m - f.rect.y; }
        else if f.rect.y + f.rect.w > view.y + view.w - m { s.offset += f.rect.y + f.rect.w - (view.y + view.w - m); }
    }
    s.offset = clamp(s.offset, 0.0, s.max);
    s.open = true;
    s.first = g.quads.len;
    s.saved = g.input;
    if s.dragging || !inside(view, i.at) { g.input = Input { at: float2 { -1.0e9, -1.0e9 }, .. }; }
    return floor(s.offset + 0.5);
}

// Ends the list scroll_begin started: its quads clipped to its view, the pointer back.
fn scroll_end(g: Gui&) {
    let s .= g.scroll;
    for k in s.first..g.quads.len { g.quads[k].extra.z += CLIP; }
    g.input = s.saved;
    s.open = false;
}

// Fades the quads from `first` (as g.quads.len counted them) near a scrolling list's
// edges, to show there are rows past them: those whose middle lies in the lower 60% of a
// `band` pixels deep at the view's top, while `above` pixels of rows lie above it, and
// likewise at its foot for `below`, each eased in over the first 16 dp of those rows.
fn fade_edges(g: Gui&, first: i64, view: float4, above: f32, below: f32, band: f32) {
    let u = g.scale;
    let top = clamp(above / (16.0 * u), 0.0, 1.0);
    let foot = clamp(below / (16.0 * u), 0.0, 1.0);
    guard top > 0.0 || foot > 0.0 else { return; }
    for k in first..g.quads.len {
        let q = g.quads[k];
        let mid = q.rect.y + 0.5 * q.rect.w;
        let a = top * clamp((view.y + band - mid) / (0.6 * band), 0.0, 1.0);
        let b = foot * clamp((mid - (view.y + view.w - band)) / (0.6 * band), 0.0, 1.0);
        g.quads[k].extra.w = max(q.extra.w, 0.85 * max(a, b));
    }
}

// Sets the offset of list `id` (a screenshot's), clamped as it is declared.
fn scroll_set(g: Gui&, id: i64, px: f32) {
    g.scroll.id = id;
    g.scroll.offset = px;
}

// Whether a portrait safe area is short enough for the compact layouts (a small iPad
// window, about 499 x 645 dp): under COMPACT dp tall, where every phone is taller.
let COMPACT = 760.0;
fn compact(g: Gui&, area: float4) -> bool { area.z < area.w && area.w < COMPACT * g.scale }

// The two paddings the screens put between and round their parts, in dp: PAD between
// two tiles in a row or a glass and round the tiles inside one, PAD_WIDE at a row's ends
// and between a page's blocks.
let PAD = 12.0;
let PAD_WIDE = 16.0;

// The tap's size in dp, tap(): a tile's or a row's height, and the least a tap is
// across (rendering.md, "Controls"); every screen's tiles and the panels' heights follow
// it. TAP on a touch screen, the floor for small hands; on a desktop (desktop_scale above
// 0) DESKTOP_TAP, the size a mouse wants (task 069, the user 2026-11-11).
let TAP = 88.0;
let DESKTOP_TAP = 64.0;
fn tap() -> f32 { if desktop_scale > 0.0 { DESKTOP_TAP } else { TAP } }

// A tile with its icon or picture over its word is at least STACKED_TAP tall, stacked():
// under it a word on two lines, a picture, or the hint's pips crowd it (task 069, the
// user 2026-11-11). A touch screen's tap is over it already.
let STACKED_TAP = 72.0;
fn stacked() -> f32 { max(tap(), STACKED_TAP) }

// The room in dp a tile sized to its words keeps either side of them, side(): settings'
// tiles and languages, the setup's draughts, the puzzles' draughts switch, and back, which
// keeps 4 dp more for its arrow. WORD_SIDE on a touch screen, DESKTOP_SIDE on a desktop.
let WORD_SIDE = 16.0;
let DESKTOP_SIDE = 12.0;
fn side() -> f32 { if desktop_scale > 0.0 { DESKTOP_SIDE } else { WORD_SIDE } }

// Whether an area at s pixels a dp is a phone's: under PHONE dp across its shorter side.
// A tablet's, a foldable's, and an iPad window's are wider.
let PHONE = 600.0;
fn phone(area: float4, s: f32) -> bool { min(area.z, area.w) < PHONE * s }

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

// A stack: children in a column (DOWN) or a row (ALONG) of `area`, laid out in one pass
// into out[i] for items[i], with no tree and nothing kept, so taps test this frame's
// rects. Each child is `size` pixels along the stack (fixed, or a text's width measured
// first), plus a share by `grow` weight of what the sized ones and the gaps leave (none
// where they leave nothing), `gap` pixels after the one before it. Across, it takes the
// whole stack, or `across` pixels placed by `align` (LEFT, CENTER, RIGHT: the top, the
// middle, the bottom in a row). Where nothing grows, `justify` puts the children at the
// stack's start, middle, or end. Children past the stack's end run on past it.
let DOWN = 0;
let ALONG = 1;
struct Item {
    size:   f32 = 0.0,
    grow:   f32 = 0.0,
    gap:    f32 = 0.0,
    across: f32 = 0.0,
    align:  i64 = LEFT,
}
fn stack(area: float4, items: const Item[:], out: float4[:], dir: i64 = DOWN, justify: i64 = LEFT) {
    assert(out.len >= items.len);
    let down = dir == DOWN;
    let length = if down { area.w } else { area.z };
    let breadth = if down { area.z } else { area.w };
    var sized:  f32 = 0.0;
    var weight: f32 = 0.0;
    for it in items {
        sized += it.gap + it.size;
        weight += it.grow;
    }
    let spare = max(length - sized, 0.0);
    let lead = if weight > 0.0 || justify == LEFT { 0.0 } else if justify == CENTER { 0.5 * spare } else { spare };
    // Positions run on from the stack's start as rect cuts do, each gap and child added in
    // turn.
    var at = (if down { area.y } else { area.x }) + lead;
    for it, i in items {
        at += it.gap;
        var len = it.size;
        if it.grow > 0.0 { len += spare * it.grow / weight; }
        let wide = if it.across > 0.0 { it.across } else { breadth };
        let off = if it.align == CENTER { 0.5 * (breadth - wide) } else if it.align == RIGHT { breadth - wide } else { 0.0 };
        out[i] = if down { float4 { area.x + off, at, wide, len } } else { float4 { at, area.y + off, len, wide } };
        at += len;
    }
}

fn inside(r: float4, p: float2) -> bool { p.x >= r.x && p.x < r.x + r.z && p.y >= r.y && p.y < r.y + r.w }

// Starts a frame: no quads yet, this frame's pointer and time, and the keys' focus moved
// among the controls the last frame offered.
fn begin(g: Gui&, input: Input, scale: f32, now: f64) {
    focus_keys(g, input);
    if !g.pointer.down && !g.pointer.pressed { g.active = 0; }
    // A press on the UI is the UI's until the frame after its release: kept no longer,
    // or the board's keys, which need the pointer off it, stayed shut after a tap on a
    // button until the next press (a gamepad's A on the board after a tap on settings).
    if input.pressed || (!input.down && !input.released) { g.took = false; }
    g.acted = false;
    g.holding = false;
    g.input = input;
    g.pointer = input;
    g.scale = scale;
    g.now = now;
    g.quads.clear();
    // The tile the last frame found under the pointer is lit from now. One coming back
    // while it fades out, and the one it leaves, turn from where they are, so a sweep
    // to and fro never jumps.
    if g.under != g.hovered {
        let back = g.under != 0 && g.under == g.left;
        let from = if back { turned(g, g.left_at) } else { now };
        if g.hovered != 0 {
            g.left = g.hovered;
            g.left_at = turned(g, g.hover_at);
        } else if back {
            g.left = 0;
        }
        g.hovered = g.under;
        g.hover_at = from;
    }
    g.under = 0;
}

// Whether what is declared from here on takes the pointer: not a screen a transition
// leaves, which is declared with no pointer at all.
fn listen(g: Gui&, on: bool) {
    g.input = if on { g.pointer } else { Input { at: float2 { -1.0e9, -1.0e9 }, .. } };
    g.deaf = !on;
}

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
    // The focused control's first quad, its tile or disc, is its shape: the ring follows
    // it, RING_GAP outside it with the corners grown to match.
    guard g.ring && g.quads.len < MAX_QUADS else { return; }
    g.ring = false;
    let out = (RING_GAP + RING_W) * g.scale;
    let r = float4 { q.rect.x - out, q.rect.y - out, q.rect.z + 2.0 * out, q.rect.w + 2.0 * out };
    g.quads.push(Quad { rect: r, look: float4 { RING, q.look.y + out, 1.0, RING_W }, extra: float4 { g.scale, 0.0, 0.0, 0.0 } });
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

// How far widget id is lit by the mouse over it (task 066, rendering.md, "Controls"),
// 0..1, eased as a press is; 0 for any but the hovered tile and the one it left.
fn hover(g: Gui&, id: i64) -> f32 {
    guard id != 0 else { return 0.0; }
    if id == g.hovered { return eased(g, g.hover_at); }
    if id == g.left { return 1.0 - eased(g, g.left_at); }
    return 0.0;
}

// A fade over PRESS begun at `since`, eased, 0..1 at g.now.
fn eased(g: Gui&, since: f64) -> f32 {
    let t = clamp((g.now - since) / PRESS, 0.0, 1.0);
    return (t * t * (3.0 - 2.0 * t)) as f32;
}

// When the opposite fade would have begun to stand now where the one begun at `since`
// stands: the ease is symmetric, so 1 - e(1 - t) is e(t).
fn turned(g: Gui&, since: f64) -> f64 {
    let t = clamp((g.now - since) / PRESS, 0.0, 1.0);
    return g.now - (1.0 - t) * PRESS;
}

// Whether any widget is still going down or up, a hold filling, or the mouse's hover
// moving to another tile or fading; the app draws while one is.
fn animating(g: Gui&) -> bool {
    if g.holding || g.scroll.dragging { return true; }
    if g.under != g.hovered { return true; }
    if g.hovered != 0 && g.now < g.hover_at + PRESS { return true; }
    if g.left != 0 && g.now < g.left_at + PRESS { return true; }
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
// after going down on it, or Enter is pressed while it has the keys' focus, and how far
// it is pressed, 0..1. A `focusable` widget is offered to the keys' focus. A `keyhold`
// one (hold_tile) is never clicked by Enter: Enter pressed on it goes down and stays down
// while Enter is held, as the pointer held on it does.
fn hold(g: Gui&, id: i64, r: float4, focusable: bool = true, keyhold: bool = false) -> bool, f32 {
    let over = inside(r, g.input.at);
    g.ring = false;
    if focusable { offer(g, id, r); }
    if g.input.pressed && over {
        g.active = id;
        g.took = true;
    }
    let key = focusable && !keyhold && keyed(g, id);
    let held = (g.active == id && g.input.down && over) || (focusable && keyhold && key_held(g, id));
    let clicked = (g.active == id && g.input.released && over) || key;
    if clicked { g.acted = true; }
    // The keys' focus is lit as the mouse's hover is. Without it, the mouse over it on a
    // desktop, unless it is down on another widget or the board. Android leaves the
    // pointer where the last touch was, so a phone never hovers.
    if g.focus != 0 {
        if g.focus == id && !g.deaf {
            g.under = id;
            g.ring = true;
        }
    } else if desktop_scale > 0.0 && over && (!g.input.down || g.active == id) {
        g.under = id;
    }
    set_down(g, id, held || key);
    return clicked, pressed(g, id);
}

// As hold for a widget that is on; one that is off takes a press but never goes down.
fn hold_if(g: Gui&, id: i64, r: float4, on: bool) -> bool, f32 {
    guard on else {
        take(g, r);
        // Dimmed, it is never lit: one turned off under the mouse goes dark at once.
        if g.hovered == id { g.hovered = 0; }
        if g.left == id { g.left = 0; }
        return false, 0.0;
    }
    return hold(g, id, r);
}

// A tile in one of the looks PLAIN..ROW_PRIMARY with corner radius `radius` dp;
// otherwise as button.
fn tile(g: Gui&, id: i64, r: float4, icon: i64, style: i64, radius: f32) -> bool {
    let clicked, p = hold(g, id, r);
    add(g, Quad { rect: r, look: float4 { BUTTON, radius * g.scale, 0.0, p },
                  extra: float4 { g.scale, style, hover(g, id), 0.0 } });
    if icon != NO_ICON {
        // Icons are half the tile (44 dp in an 88 dp one), scaled with it and with the press.
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
    add(g, Quad { rect: r, look: float4 { BUTTON, 0.5 * min(r.z, r.w), 0.0, p }, extra: float4 { g.scale, ROW, hover(g, id), 0.0 } });
    let s = size * g.scale * (1.0 - 0.04 * p);
    glyph_icon(g, center(r, s, s), icon, ROW, p, 0.85);
    return clicked;
}

// A floating button (rendering.md, "Controls"; the 3D board's camera): its touch area r
// holding a shaded disc `disc` pixels across with a hairline and a line icon, no panel
// behind; lit in the glow color while `on`, a small gold dot on its rim with `dot`,
// shrinking 8% and darkening with the press; its icon at `a` (the lookout's struck-through
// eye, dim while off). True when it is tapped.
fn floating(g: Gui&, id: i64, r: float4, disc: f32, icon: i64, on: bool, dot: bool, a: f32 = 1.0) -> bool {
    let clicked, p = hold(g, id, r);
    let d = disc * (1.0 - 0.08 * p);
    let flags = (if on { 1.0 } else { 0.0 }) + (if dot { 2.0 } else { 0.0 });
    add(g, Quad { rect: center(r, d, d), look: float4 { FLOAT, 0.5 * d, flags, p }, extra: float4 { g.scale, 0.0, hover(g, id), 0.0 } });
    let s = 26.0 / 40.0 * d;
    glyph_icon(g, center(r, s, s), icon, PLAIN, p, a);
    return clicked;
}

// A still mark in the middle of r saying something is getting ready (the 3D board): the
// words s alone, with no glass, as it shows only a moment. Nothing in it moves, so it
// needs no frames of its own.
fn waiting(g: Gui&, r: float4, s: const u8[:]) {
    let u = g.scale;
    let m = center(r, text_width(g, BODY, s) + 48.0 * u, 52.0 * u);
    text(g, BODY, m, s, 0.9, 0.0, CENTER);
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
// go early and nothing happens, a release being no tap. Enter held while it has the keys'
// focus fills it too. Returns true on the frame the ring is full, after which the press
// does nothing more until the pointer is lifted or Enter let go and pressed again, and
// how far the ring is, 0..1. The caller draws the tile's face over it.
fn hold_tile(g: Gui&, id: i64, r: float4, radius: f32, seconds: f64, red: bool) -> bool, f32 {
    let key = key_held(g, id);
    let unused, p = hold(g, id, r, true, true);
    let s .= g.slots[slot(g, id)];
    let held = ((g.active == id && g.input.down && inside(r, g.input.at)) || key) && s.down;
    let k = if held { clamp((g.now - s.since) / seconds, 0.0, 1.0) as f32 } else { 0.0 };
    add(g, Quad { rect: r, look: float4 { BUTTON, radius * g.scale, 0.0, p }, extra: float4 { g.scale, PLAIN, hover(g, id), 0.0 } });
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

// A bare tap r, round or a pill (rendering.md, "Home"): nothing drawn until pressed, then
// white at 10% and a faint 1 px ring round it, shrinking 4% with the press. True when it
// is tapped, and how far it is pressed, 0..1. The caller draws what is in it.
fn bare(g: Gui&, id: i64, r: float4) -> bool, f32 {
    let clicked, p = hold(g, id, r);
    let k = 1.0 - 0.04 * p;
    let d = 0.5 * min(r.z, r.w);
    add(g, Quad { rect: center(r, r.z * k, r.w * k), look: float4 { BUTTON, d * k, 1.0, p },
                  extra: float4 { g.scale, ROW, hover(g, id), 0.0 } });
    return clicked, p;
}

// An X alone in its round tap r (home's way out, rendering.md, "Home"), `size` dp across
// at 80% with strokes of 2.8 grid units, bare. True when it is tapped.
fn bare_x(g: Gui&, id: i64, r: float4, icon: i64, size: f32) -> bool {
    let clicked, p = bare(g, id, r);
    let k = 1.0 - 0.04 * p;
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
// the dimmer small face, in a 20 dp rounded row that lights while pressed, `outlined`
// with a faint border; the note may have an icon before its word (`note_icon`). A row
// that is off is drawn at 40% and can't be pressed. True when it is tapped.
fn row(g: Gui&, id: i64, r: float4, icon: i64, label: const u8[:], note: const u8[:], primary: bool,
       on: bool, outlined: bool = false, note_icon: i64 = NO_ICON) -> bool {
    let u = g.scale;
    let clicked, p = hold_if(g, id, r, on);
    if primary { prefer(g, id); }
    let style = if primary { ROW_PRIMARY } else if outlined { ROW_OUTLINE } else { ROW };
    add(g, Quad { rect: r, look: float4 { BUTTON, 20.0 * u, 0.0, p }, extra: float4 { u, style, hover(g, id), 0.0 } });
    let a: f32 = if on { 1.0 } else { 0.4 };
    var c = r;
    cut_left(c, 18.0 * u);
    cut_right(c, 18.0 * u);
    glyph_icon(g, center(cut_left(c, 34.0 * u), 34.0 * u, 34.0 * u), icon, style, 0.0, 0.85 * a);
    cut_left(c, 18.0 * u);
    text(g, LABEL, c, label, a, 0.0, LEFT);
    text(g, SMALL, c, note, 0.66 * a, 0.0, RIGHT);
    if note_icon != NO_ICON {
        // The note's icon, NOTE_ICON dp, NOTE_ICON_GAP left of its word (or alone).
        let w = text_width(g, SMALL, note);
        let x = c.x + c.z - w - (if note.len > 0 { NOTE_ICON_GAP * u } else { 0.0 }) - NOTE_ICON * u;
        glyph_icon(g, float4 { x, c.y + 0.5 * (c.w - NOTE_ICON * u), NOTE_ICON * u, NOTE_ICON * u }, note_icon, style, 0.0,
                   0.66 * a, 2.0);
    }
    return clicked;
}
let NOTE_ICON = 20.0;
let NOTE_ICON_GAP = 6.0;

// A choice tile (prototypes/settings.html): a picture of size `pic` (centered across)
// with a label under it, lit in the glow color when on. The picture is a season's
// thumbnail (kind, a theme; 4 more its plain fade), or for -1 the glow's tint with a sun. A choice that isn't
// `enabled` is dimmed and takes no tap. With `beside`, a slim tile: the picture at the
// left and the label after it, centered down the tile (settings' theme in a small window,
// task 050). True when it is tapped.
let BESIDE_GAP = 8.0;       // dp between a slim choice's picture and its label
fn choice(g: Gui&, id: i64, r: float4, kind: i64, pic: float2, label: const u8[:], on: bool, enabled: bool,
          beside: bool = false) -> bool {
    let u = g.scale;
    let clicked, unused = hold_if(g, id, r, enabled);
    let a: f32 = if enabled { 1.0 } else { 0.4 };
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { BUTTON, (if beside { 14.0 } else { 16.0 }) * u, 0.0, 0.0 },
                  extra: float4 { u, if on { CHOSEN } else { CHOICE }, hover(g, id), 0.0 } });
    var c = inset(r, 6.0 * u);
    if beside {
        // The pair centered across the tile.
        let w = min(c.z, pic.x + BESIDE_GAP * u + text_width(g, SMALL, label));
        c = center(c, w, c.w);
    }
    let picture = if beside { center(cut_left(c, pic.x), pic.x, pic.y) } else { center(cut_top(c, pic.y), pic.x, pic.y) };
    add(g, Quad { rect: picture, color: float4 { 1.0, 1.0, 1.0, a },
                  look: float4 { PICTURE, (if beside { 7.0 } else { 11.0 }) * u, kind, 0.0 },
                  extra: float4 { u, 0.0, 0.0, 0.0 } });
    let sun = min(30.0 * u, pic.y - 4.0 * u);
    if kind == -1 { glyph_icon(g, center(picture, sun, sun), SUN, PLAIN, 0.0, a); }
    if beside {
        cut_left(c, BESIDE_GAP * u);
        text(g, SMALL, c, label, a, 0.0, LEFT);
        return clicked;
    }
    text(g, SMALL, c, label, a, 0.0, CENTER);
    return clicked;
}

// Where choice puts its picture of size `pic` in a tile r (not `beside`): at the top of
// the tile less 6 dp round, centered across.
fn choice_picture(g: Gui&, r: float4, pic: float2) -> float4 {
    var c = inset(r, 6.0 * g.scale);
    return center(cut_top(c, pic.y), pic.x, pic.y);
}

// A small tag in a picture's bottom right corner (settings' raised board's "auto"):
// the word in the small face scaled to TAG_FACE dp, white on a dark pill TAG_H dp tall,
// TAG_IN dp in from the picture's edges.
let TAG_FACE = 10.5;
let TAG_H = 14.0;
let TAG_IN = 3.0;
let TAG_SIDE = 4.0;
fn tag(g: Gui&, picture: float4, word: const u8[:]) {
    let u = g.scale;
    let k = TAG_FACE / FACE_DP[SMALL] as f32;
    let w = k * text_width(g, SMALL, word) + 2.0 * TAG_SIDE * u;
    let r = float4 { picture.x + picture.z - TAG_IN * u - w, picture.y + picture.w - (TAG_IN + TAG_H) * u, w, TAG_H * u };
    fill(g, r, float4 { 0.0, 0.0, 0.0, 0.55 }, 5.0 * u);
    write(g, SMALL, r, word, float4 { 1.0, 1.0, 1.0, 1.0 }, true, 0.0, CENTER, false, k);
}

// How wide a slim choice (`beside`) wants to be for its picture and label.
fn choice_beside_width(g: Gui&, pic: float2, label: const u8[:]) -> f32 {
    return pic.x + (BESIDE_GAP + 12.0) * g.scale + text_width(g, SMALL, label);
}

// A choice that is a picture alone, `pic` in dp's pixels in its middle (look.z `kind`,
// as choice's): the theme's switch, photograph or plain (shell/settings.goose). True
// when it is tapped.
fn picture(g: Gui&, id: i64, r: float4, kind: i64, pic: float2, on: bool) -> bool {
    let u = g.scale;
    let clicked, unused = hold_if(g, id, r, true);
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, 1.0 }, look: float4 { BUTTON, 16.0 * u, 0.0, 0.0 },
                  extra: float4 { u, if on { CHOSEN } else { CHOICE }, hover(g, id), 0.0 } });
    add(g, Quad { rect: center(r, pic.x, pic.y), color: float4 { 1.0, 1.0, 1.0, 1.0 },
                  look: float4 { PICTURE, 9.0 * u, kind, 0.0 }, extra: float4 { u, 0.0, 0.0, 0.0 } });
    return clicked;
}

// How a labelled tile lays out its icon and word.
let MIDDLE = 1;             // the icon and the word side by side, centered
let STACKED = 2;            // the icon over the word, centered
let LABEL_PAD = 8.0;        // dp a labelled tile's word keeps from its sides at least

// A glass tile with an icon `size` dp across and a word in face `face`
// (prototypes/game.html): true when it is tapped. `style` lights it (CHOSEN, a puzzle's
// next once it is solved); one that isn't `on` is drawn at 35% and takes no tap.
fn labelled(g: Gui&, id: i64, r: float4, icon: i64, size: f32, label: const u8[:], face: i64,
            arrange: i64, style: i64 = PLAIN, on: bool = true) -> bool {
    let u = g.scale;
    let clicked, p = hold_if(g, id, r, on);
    let a: f32 = if on { 1.0 } else { 0.35 };
    add(g, Quad { rect: r, color: float4 { 1.0, 1.0, 1.0, a }, look: float4 { BUTTON, 22.0 * u, 0.0, p },
                  extra: float4 { u, style, hover(g, id), 0.0 } });
    let s = size * u;
    // The word keeps LABEL_PAD from the tile's sides, in a smaller face where it is too
    // wide for its own. With NO_ICON the word stands alone.
    if arrange == STACKED {
        let gap = if icon == NO_ICON { 0.0 } else { 8.0 * u };
        let room = r.z - 2.0 * LABEL_PAD * u;
        // A word too wide for one line goes on two where the tile is tall enough for them,
        // broken at a space ("Undo move" in a narrow tile); else it takes a smaller face;
        // where none holds it on one line, two in the largest smaller face that holds
        // them ("Võta käik tagasi" in half a corner panel).
        var two = face;
        var cut = if text_width(g, face, label) > room { lines_at(g, face, label, room, r.w - s - gap) } else { -1 };
        if cut < 0 && text_width(g, fitting(g, face, label, room), label) > room {
            while two < SMALL && cut < 0 {
                two++;
                cut = lines_at(g, two, label, room, r.w - s - gap);
            }
        }
        let shown = if cut >= 0 { two } else { fitting(g, face, label, room) };
        let line = g.faces[shown].ascent - g.faces[shown].descent;
        let lines: f32 = if cut >= 0 { 2.0 } else { 1.0 };
        var c = center(r, r.z, s + gap + lines * line);
        if icon != NO_ICON { glyph_icon(g, center(cut_top(c, s), s, s), icon, PLAIN, p, a); }
        cut_top(c, gap);
        if cut >= 0 {
            text(g, shown, cut_top(c, line), label[..cut], a, 0.0, CENTER);
            text(g, shown, c, label[cut + 1..], a, 0.0, CENTER);
            return clicked;
        }
        text(g, shown, c, label, a, 0.0, CENTER);
        return clicked;
    }
    let gap = PAD * u;
    let shown = fitting(g, face, label, r.z - labelled_width(g, size, "", face));
    var c = center(r, s + gap + text_width(g, shown, label), r.w);
    glyph_icon(g, center(cut_left(c, s), s, s), icon, PLAIN, p, a);
    cut_left(c, gap);
    text(g, shown, c, label, a, 0.0, LEFT);
    return clicked;
}

// How wide a labelled tile must be for its icon `size` dp across and its word in face
// `face` side by side, centered, keeping LABEL_PAD at the sides.
fn labelled_width(g: Gui&, size: f32, label: const u8[:], face: i64) -> f32 {
    return (2.0 * LABEL_PAD + size + 12.0) * g.scale + text_width(g, face, label);
}

// The way back (rendering.md, "Controls", The way back): one control on
// every screen, the arrow and the word `label` ("Back") side by side on a glass tile,
// a tap tall. back_width is how wide it is: its icon and word with side() and 4 dp at
// either side, a tap at least.
let BACK_ICON = 34.0;
fn back_width(g: Gui&, label: const u8[:]) -> f32 {
    return max(tap() * g.scale, (2.0 * (side() + 4.0) + BACK_ICON + 12.0) * g.scale + text_width(g, HEADING, label));
}

// The way back in r, on its own glass, or with `stacked` the arrow over the word in a
// tap's square where a page has no room for it wider; true when tapped.
fn back(g: Gui&, id: i64, r: float4, label: const u8[:], stacked: bool = false) -> bool {
    glass(g, r, 22.0);
    return labelled(g, id, r, BACK, BACK_ICON, label, HEADING, if stacked { STACKED } else { MIDDLE });
}

// Where to break `text` into two lines of face `face` each at most w pixels wide: the
// space that leaves the first line longest, or -1 where none does.
fn break_at(g: Gui&, face: i64, text: const u8[:], w: f32) -> i64 {
    var best = -1;
    for c, i in text {
        guard c == 32 else { continue; }
        if text_width(g, face, text[..i]) <= w && text_width(g, face, text[i + 1..]) <= w { best = i; }
    }
    return best;
}

// The width `text` needs in `face` on two lines at most: its widest line where it breaks
// at the space that makes that least, or its whole width with no space.
fn two_lines(g: Gui&, face: i64, text: const u8[:]) -> f32 {
    var best = text_width(g, face, text);
    for c, i in text {
        guard c == 32 else { continue; }
        best = min(best, max(text_width(g, face, text[..i]), text_width(g, face, text[i + 1..])));
    }
    return best;
}

// Where `text` breaks onto two lines of `face` each fitting w pixels, with h pixels high
// enough for both and 16 dp round them, or -1.
fn lines_at(g: Gui&, face: i64, text: const u8[:], w: f32, h: f32) -> i64 {
    let f .= g.faces[face];
    guard h >= 2.0 * (f.ascent - f.descent) + 16.0 * g.scale else { return -1; }
    return break_at(g, face, text, w);
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
                  extra: float4 { u, if on { CHOSEN } else { CHOICE }, hover(g, id), 0.0 } });
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
// runs, gold under a minute, red when low, faint while it waits. It takes a press, so a
// press on it never reaches the board.
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

// Text as text() draws it at full opacity, over a soft dark halo, for a title bare on the
// photograph (the library's): the coverage atlas has no blur, so the halo is eight dark
// copies in a ring 2 dp out at 20% each and one 2 dp down at 35% (the player's chip's
// takes b and e, rendering.md, "Controls", Players; 3 dp at 10% left spring's birch bark
// too bright round the letters). Nine more quads a glyph.
fn shadowed(g: Gui&, face: i64, r: float4, s: const u8[:], align: i64) {
    let d = 2.0 * g.scale;
    let ring = float4 { 0.0, 0.0, 0.0, 0.2 };
    for k in 8 {
        let t = k as f32 * 0.785398;
        write(g, face, float4 { r.x + d * cos(t), r.y + d * sin(t), r.z, r.w }, s, ring, true, 0.0, align, false);
    }
    write(g, face, float4 { r.x, r.y + 2.0 * g.scale, r.z, r.w }, s, float4 { 0.0, 0.0, 0.0, 0.35 }, true, 0.0, align,
          false);
    text(g, face, r, s, 1.0, 0.0, align);
}

// Text at opacity a over one dark copy 1.5 dp down at 45%, for a line too long for
// shadowed's nine copies a glyph within the frame's quads (the library's note): two quads
// a glyph.
fn shaded(g: Gui&, face: i64, r: float4, s: const u8[:], a: f32, align: i64) {
    write(g, face, float4 { r.x, r.y + 1.5 * g.scale, r.z, r.w }, s, float4 { 0.0, 0.0, 0.0, 0.45 }, true, 0.0, align,
          false);
    text(g, face, r, s, a, 0.0, align);
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
// opacity a, or in a low clock's red or gold (`style`, CLOCK_LOW or CLOCK_WARN).
fn figures(g: Gui&, face: i64, r: float4, s: const u8[:], a: f32, style: i64, align: i64) {
    let c = if style == CLOCK_LOW { RED } else if style == CLOCK_WARN { GOLD } else { float4 { 1.0, 1.0, 1.0, 1.0 } };
    let own = style == CLOCK_LOW || style == CLOCK_WARN;
    write(g, face, r, s, float4 { c.x, c.y, c.z, a }, own, 0.0, align, true);
}

// Text as the functions above draw it; `k` scales the face's glyphs down for a tag
// smaller than any face (tag), the atlas's glyphs drawn smaller.
fn write(g: Gui&, face: i64, r: float4, s: const u8[:], color: float4, own: bool, spacing: f32, align: i64,
         tabular: bool, k: f32 = 1.0) {
    let f .= g.faces[face];
    let cell = if tabular { figure_width(g, face) } else { 0.0 };
    var w: f32 = 0.0;
    var i = 0;
    while i < s.len {
        let c, next = next_char(s, i);
        let adv = k * f.glyphs[glyph_of(f, c)].advance;
        w += (if tabular && c >= '0' && c <= '9' { cell } else { adv }) + spacing;
        i = next;
    }
    w -= spacing;
    var x = if align == LEFT { r.x } else if align == CENTER { r.x + 0.5 * (r.z - w) } else { r.x + r.z - w };
    let top = floor(r.y + 0.5 * (r.w - k * (f.ascent - f.descent)) + 0.5);
    let tint: f32 = if own { 1.0 } else { 0.0 };
    i = 0;
    while i < s.len {
        let c, next = next_char(s, i);
        let gl .= f.glyphs[glyph_of(f, c)];
        let digit = tabular && c >= '0' && c <= '9';
        let step = if digit { cell } else { k * gl.advance };
        let shift = if digit { 0.5 * (cell - gl.advance) } else { 0.0 };
        let at = if k == 1.0 { floor(x + shift + 0.5) } else { x + shift };
        if gl.box.z > gl.box.x {
            add(g, Quad { rect: float4 { at + k * gl.box.x, top + k * gl.box.y, k * (gl.box.z - gl.box.x), k * (gl.box.w - gl.box.y) },
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
