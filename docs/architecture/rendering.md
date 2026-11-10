# Rendering

## Drawing

NoGraphicsAPI's ideas, inside SDL_GPU:

- **Vertex pulling.** All pieces are one instanced draw. The vertex shader reads a
  storage buffer of `{pos, kind, color, lift, glow}`, so there is no vertex layout to keep
  in sync. The board is one pass, with the squares worked out in the shader.
- **One upload a frame.** All of a frame's per-draw data goes into one buffer region per
  frame in flight.
- **SDF shapes.** Pieces, highlights, rounded panels, and their soft shadows are signed
  distance shapes in fragment shaders, crisp at any resolution without textures.
- **One screen, no depth.** A frame draws into goose_gfx's screen, an RGBA8 texture the
  window's size that `frame()` blits into the swapchain. Nothing tests depth, so the pass
  has no depth target (`gfx::begin_pass` with `Texture { 0 }`, not `begin_screen`). In the
  Android build gfx makes the screen's depth target only when a program asks for it, and
  never cycles the screen (`patches/goose_gfx/0003-screen-without-depth-or-cycling.patch`,
  [findings](../goose-findings.md)): the GPU orders a frame's clear after the last
  frame's blit instead of SDL keeping a fresh copy for each frame in flight. Together
  they kept SDL from a second 64 MiB block after the first rotation, about 70 MB of
  graphics memory on the tablet, before SDL's blocks were sized to their resources
  ([GPU memory](#gpu-memory)).
- **The 3D board** reuses the game state and the flat board's draw lists, with a camera
  and lit meshes in place of the 2D pieces ("Board and pieces").

## UI layer

The UI is a small immediate-mode layer in Goose, drawn the way Goose's Mini Minecraft
draws its HUD:

- Each frame, screens are declared in code. Layout cuts rows, columns, and grids from
  the screen rect.
- `button(id, rect, icon)` returns true on release over the button it went down on. A
  small fixed table holds per-id state for the press animation (0.12 s). A press that
  lands on the UI is the UI's and never reaches the board.
- Calls append quads (`panel`, `button`, `icon`, `fill`; `text` with home) to one fixed
  array, reset each frame, and one pipeline draws them in one instanced draw.
- **Native form**: `gui/` holds the layer with no graphics (tested headless in
  `test/gui/`), and `src/app/widgets.goose` draws it: each quad pulls `{rect, color, kind,
  radius, icon, pressed, dp, look}` from one storage buffer, and its fragment shader works
  it out as a signed-distance shape: glass with its shadow, a tile with its shadow (plain,
  primary, or a toggle on or off), a line icon as distances to its strokes' segments and
  arcs. `game/` is the game screen with no graphics, tested headless in
  `test/game/`: it declares the panel (`src/game/panel.goose`) and the celebration, does what
  their buttons ask, and hands the pointer to the board only when a press didn't land on
  the UI. Pieces shown on the UI (the side to move, the winner) are drawn after it by the
  piece pipeline from a second small storage buffer, so they look exactly like the
  board's.
- **Kept while it stands still** (`widgets::prepare`, task 059): when a frame's quads,
  view, theme, and textures are the same as the last frame's, they are drawn once into
  a layer the screen's size, premultiplied, and each frame after lays it with a fetch a
  pixel until they change; while they change they are drawn as they come. The quads
  were a quarter of the 3D frame's GPU cycles on the Pixel 7a while only the board
  moved; the layer is 10 MB there.

### Screen sizes and the safe area

Layouts are in dp: the screen's shorter side is 800 dp (`gui::scale_of`, the one place the
scale is computed), so the tablet's 1200 px are 1.5 px a dp. The scale has room for a
floor in physical size, `max(short side / 800, F × display scale)`, the display scale
being Android's density / 160 (2.625 on the Pixel 7a, 1.5 on the tablet), so a phone's
dp stays at least F of Android's; F is 0.75 (`gui::DENSITY_FLOOR`, picked by the user on
2026-11-08), so the Pixel 7a lays out about 549 dp across and the tablet, whose 1.125
floor is under its 1.5, is unchanged. Without the floor a phone draws the tablet's
layout into its 64 mm short side: an 88 dp tap is 7.0 mm on the Pixel 7a against 16.3
on the tablet, the 17 dp notes 1.4 mm. At 0.75 an 88 dp tap is about 10.5 mm on any
phone, near a child's fingertip and over Android's 48 dp (7.6 mm), and the notes 2 mm.
Going further buys nothing on the board, whose size the phone's width fixes whatever the
scale, and at 1 every layout would have to work 360 dp across; going less (0.69) leaves
taps at 9.3 mm and still needs most of the same layout work. So the layouts are made for
a short side down to 480 dp (a 360 dp phone at 0.75). A larger tablet lays out
the same dp as a smaller screen of its proportions, only scaled; the photograph is
then stretched by long side / 2048 (1.25× at 2560 px, 1.41× at 2880), soft but fine
behind home. The Mac's display scale (2 on Retina, its
windows being in points) is left out: a Mac window stands for a screen of its size in
pixels, and the floor there would make shots depend on the Mac's screen.

Each screen lays out its taps and words inside the window's **safe area**: the window less
its insets, a phone's camera cutout and its gesture bar at the bottom. SDL reports them
(`SDL_GetWindowSafeArea`; the program's own C, `src/app/display.c`, reads them each frame with
the display scale, since goose_gfx has neither). The app draws behind the cutout (SDL
sets `LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS`), so the photograph, the blurred page, and
glass that runs off the screen's edge (home's column and sheet, `gui::bleed`) reach the
screen's edges; everything else is placed in the safe rect as it would be in a whole
window of that size (`gui::safe`, `shell::frame`). The scale stays the whole short
side's: the same in both orientations, where the cutout falls on the long side in one and
the short side in the other, so turning the screen doesn't rebake the text or change the
size of a tap. The layouts hold down to a safe area 443 × 801 dp (a 9:16 phone at 480 dp
less its cutout at a side and an 84 px gesture bar). SDL would also take out of the safe
area the back gesture's strips down both sides (`systemGestures`) and, with the system
bars hidden, the strip at the top a swipe pulls them down from (`mandatorySystemGestures`'
top, and on a Samsung tablet `tappableElement`'s top too), though taps in both still
reach the window; `patches/SDL/0002` keeps them in, so the safe area is the cutout, the
bars while shown, the system's tappable elements at the sides and the bottom (a
navigation bar, shown or hidden), and the gesture bar at the bottom (on the Pixel 7a 0,
118, 0, 84 px in portrait; on the Galaxy Tab A11+ 0, 0, 0, 72, its hidden
navigation bar). Settings in landscape lets its two groups run over a bottom inset: the
fit counts up to 38 dp of it (the page's foot and the look group's bottom pad), the
look's glass ending below its tiles there (not running on to the screen's bottom edge,
which left it mostly empty below, the user 2026-11-09), its tiles still above the inset
and as far from the screen's edge as with none; so the tablet keeps both groups
beside the board rather than the Game and Look tabs. Under a top inset in landscape (an
iPad's status bar) the page's top padding gives up to 12 dp of its 24, the bar already
keeping the head from the edge, so the 13" and 11" iPad keep both groups too, 1 and 5 dp
short with the full padding (2026-11-09). A
change of the insets or the scale counts as a change, as a new size does, and the screen
is laid out and drawn again (see "Frames and battery"). When the screen turns, the new
insets and the new size arrive a frame or two apart, the insets first; the layout
follows each, so a screen left open while turning shows the new orientation's layout at
once.

Nuklear (`ui`) is only for developer tools, such as a puzzle editor, because restyling
its desktop widgets into the kid UI would fight it; its scroll offsets
(`ui::window_get_scroll`) are its windows', so the kid UI keeps its own ("Small windows").
If layout outgrows rect-cutting (wrapping text, menus like Snowtime's), we copy
[Clay](https://github.com/nicbarker/clay)'s model, a per-frame layout tree with
grow/fit/fixed sizing, rather than linking it. Its API is C macros, which Goose can't
call directly.

### Small windows

iPadOS 26 resizes any app's window, down to about 374 × 484 pt on an 11" iPad Pro, a
499 × 645 dp layout at the density floor (task 050, 2026-11-09). Every size works; the
extremes aren't polished. The tallest window is about 380 × 1190 pt (507 × 1587 dp), the
widest about 1210 × 480 pt (1613 × 640 dp); both keep the usual layouts. Headless at 2 px
a point with the density floor (`agents/testing.md`), the smallest window's 3D game board
is about 350 dp wide (from about 200 before the compact layout), home's board about 160
dp (from none).

- **Compact** (`gui::compact`): a portrait safe area under 760 dp tall. Every phone's is
  taller (801 dp at least), so only a small window takes it. The game's bar is three
  icon-only tiles 72 × 64 dp (back at the left, settings and start over at the right) in
  an 88 dp bar, the play one 112 dp row (the piece and whose turn, or the two clocks with
  the countdown's short form between, at the left; undo move at the right), the margins
  16 dp: the board goes from about a third of the width to nearly all of it. The bar's
  middle holds what each side has taken ("What each side has taken"). Home's menu
  rows are 72 dp, the wordmark's row 64 with 12 under it (the gear's reach, so its 88 dp
  tap keeps off Continue's; 8 until 2026-11-10), the sheet's rim 20, which leaves
  the board about 240 dp above the sheet. Settings' theme tiles are slim
  (`settings::SLIM_H`, `gui::choice`'s `beside`): 48 dp tall, a 40 × 26 dp thumbnail with
  its word beside it, the switch's halves 88 × 48 beside the name, so the Look tab shows
  Theme and Board whole and the top of Kings without scrolling (Board's foot had been 33 dp
  under the glass's; `test/shell/sizes`' last line). All under the 88 dp floor, accepted
  for compact only (the user, 2026-11-09). A single puzzle keeps its layout
  (`small: false`) for now.
- **Scrolling** (`gui::scroll_begin`, `scroll_end`): one vertical list a frame, its offset
  kept in `gui::Gui` by the list's id, so another list starts at its top. A press in the
  list's view is a tap until it moves 10 dp up or down (`gui::SLOP`); then it is a drag
  that takes the pointer (`g.active`), so the tile it went down on rises and clicks
  nothing. The wheel (`gfx::mouse_wheel`, 40 dp a step) scrolls it on the Mac and a
  trackpad. No fling (the user, 2026-11-09). The list's quads are marked (`gui::CLIP` in
  extra.z) and the UI shader keeps them inside the view, one more uniform and still one
  draw; the pointer reaches the list only inside it. The puzzle library's rows scroll under
  the switch, in either orientation, and a theme's levels under the title row in
  portrait, down to the screen's foot; a switch of draughts puts the library at its top;
  settings' shown group scrolls inside its glass where the tabs leave it too little room.
  `test/gui/scroll` checks a tap, a wobble under the slop, a drag, the ends, the wheel, and
  a press outside the view.
- **The window control** (iPadOS 26's three dots at a window's top left, about 22 to 60
  pt across and 22 to 42 pt down) may sit over the corner of whatever control is there:
  back, the player's chip, the game's back tile. No screen moves out of its way (the user,
  2026-11-09): back and the chip are large and still easy to tap beside the dots, and a
  control that steps aside in a window only is one that moves. A margin clear of the dots
  was built and taken out (task 050); UIKit's corner-adapted safe area
  (`edgeInsetsForLayoutRegion:` with `safeAreaLayoutRegionWithCornerAdaptation:`) is what
  reports the dots' reach, should a screen ever need it.

### Window resizing

While a Mac window's edge is dragged, Cocoa holds the main thread in its own loop until
the mouse comes up: the frame loop doesn't run, and the Metal layer would stretch the
last frame to the window. Instead (`src/app/resize.c`, set once at launch) the Metal
layer keeps that frame's shape, scaled to fit, and the window's content view under it
shows the backdrop, cover-cropped as the app crops it: the flat game's blurred
photograph or the page color, or with the 3D board its graded backdrop, drawn once at
512 px when the board is ready (`draw3d::cover`). Both are read back to the CPU once, at
a season change or when the board changes, never per frame; Core Animation does the
rest while the loop is held. On mouse-up the frame at the new size takes the window's
whole area again, with no layer to take off and nothing to flicker. Idle stays at 0.08%
of a core (2026-11-10).

Drawing live during the drag was set aside (task 058): it needs the loop's body run from
SDL's 60 Hz expose in an event watch, from inside gfx's own `frame()`, which Goose may
not allow, and Metal's frame lags the window's size by one, so the edges wobble. A cover
over the stretched frame, taken off after the next frame, flickered on mouse-up and
switched too suddenly. Android and iOS don't hold the loop while a window resizes: an
iPad's window (the 11" iPad Pro simulator, iOS 26.4) lays out live. Windows' modal size
loop holds it as the Mac's does, and shows the last frame unscaled, black where the
window grew, which is kept (the user, 2026-11-10): the Mac's look there would need a gfx
patch presenting the backdrop and the last frame from SDL's 60 Hz expose, the swapchain
made again each tick.

## Look

Reference: Snowtime's UI ([repo](https://github.com/Snowhound/snowtime), its
`prototypes/`): frosted glass panels over a scene, thin light borders, flat buttons;
and the seasonal design boards made with `prototypes/design-boards-prompt.md`, which set
each season's palette. The HTML
prototypes in [`prototypes/`](../../prototypes/README.md) settled the values below on
2026-11-07; they use only what this renderer draws cheaply.

### Seasons and themes

The season, picked from the date, chooses the background and the board theme together;
the theme can be overridden in settings. Values from the design boards (2026-11-07):

| | Autumn: wood | Winter: stone | Spring: birch | Summer: sunset |
| --- | --- | --- | --- | --- |
| Light square | `#e2b070` | `#d8dee7` | `#e8e2d3` | `#efd9c3` |
| Dark square | `#7a4626` | `#5a6777` | `#6b7f6a` | `#9a6655` |
| Frame | `#3b2112` | `#2a3442` | `#3d4a3c` | `#4a2c26` |
| Light piece | `#f0d4a4` | `#f3eee2` | `#f6f3e7` | `#fbf3e8` |
| Dark piece | `#4a2918` | `#2b3440` | `#3a4a3f` | `#4a2f35` (plum) |
| Glow | `#ffd75a` | `#a7d0fb` | `#8fd4ff` | `#ffb08a` (coral) |
| Glass tint | `#2b1e18` at 66% | `#1e2f45` at 40% | `#1e2f45` at 40% | `#462828` at 45% |
| Glass copy dimmed to | 0.9 | 0.75 | 0.75 | 0.8 |
| Text | `#f8f3e6` | `#e6f4ff` | `#e6f4ff` | `#fff3ea` |
| Page under the scene | `#1c1410` | `#0b1622` | `#101a14` | `#20140f` |
| Square surface | wood grain | soft mottling | faint fibre | plain sheen |

Summer's sunset (chosen 2026-11-07) takes the summer photograph's evening sky, peach and
dusky rose, where the design boards' sea greens were cold against it and close to
spring's sage. The crown on a light piece is the dark piece's color.

Secondary text is the text color at 66%. The surfaces are faint, never busy: a few sines
and value noise in the board shader. Wood is fine irregular streaks along the board and
a broad soft figure, never a regular stripe, which reads as bands from afar, with each
square its own tone; stone a paper-like mottling; birch a hint of fibre across;
sunset almost flat.

#### Themes kept for later

Set aside, not rejected: candidates for another season's photograph, a theme setting, or
a later board. Values as in the table above.

| | Sand and pine (2026-11-07) | Sea (the design boards' summer, until 2026-11-07) |
| --- | --- | --- |
| Light square | `#e6cfa6` | `#c7d5c6` |
| Dark square | `#56603f` | `#2e5546` |
| Frame | `#33361f` | `#1d3a30` |
| Light piece | `#f7efdf` | `#f6f1e4` |
| Dark piece | `#b5603f` (terracotta) | `#b56a57` (terracotta) |
| Crown on a light piece | `#56603f` | `#2e5546` |
| Glow | `#ffc67a` | `#86e7d3` |
| Glass tint | `#3a2a1e` at 50% | `#1e4a4a` at 40% |
| Glass copy dimmed to | 0.8 | 0.75 |
| Text | `#fbf3e6` | `#f4f8f2` |
| Page under the scene | `#1e1a12` | `#0d1c1c` |
| Square surface | soft mottling, like sand | plain sheen |

Sand and pine is warm sand with olive pine squares; it suits the summer photograph too,
but its olive sits nearer spring's greens than the sunset does.

### Scene and glass

- **The scene** is a calm Estonian landscape for the season: autumn forest, winter
  spruces, spring birches, summer coast. Each is a photograph-like picture
  (`design/backgrounds/`, placeholders until they are upscaled with real detail), shown as it is, cover-cropped to
  the screen by its long side, sharp behind the title menu, the puzzle picker, settings, and the 3D
  board.
- **Behind the 2D game the scene is blurred** (a 14 px blur at 1280 px wide, dimmed to
  0.8), as on the design boards, so the flat board reads cleanly. Natively
  (`src/app/scene.goose`) the sharp texture is averaged down to 512 × 512 on the GPU (a box of
  4 × 4 texels from 2 × 2 bilinear taps) and blurred once when the season is picked, two
  passes of a Gaussian of sigma 5.6 texels: since a square image is cover-cropped by the
  screen's long side, that is the same blur at every screen size and orientation, so a
  new screen size needs no new blur. The board pass samples it, a 1 MB texture. Tried and
  set aside on 2026-11-07: the sharp photograph (busy behind the board), a plain painted tabletop,
  and generated tabletop pictures with a crafted board.
- **The 3D board floats in front of the scene**, with a soft shadow under it: no room or
  table to model. A painted backdrop with a real table comes later only if this falls
  short.
- **Stored** twice per season, 2048 × 2048, built into the program (C23 `#embed` in its
  C): nothing to package in the APK's assets, and the same path on the Mac and Android.
  As **ASTC in 6 × 6 blocks** (1.87 MB each, from the lossless masters with
  `astcenc`, `design/backgrounds/README.md`), which the GPU samples as it is stored, with
  nothing decoded; and as **JPEG at quality 85** (0.46 to 0.70 MB each), the fallback for
  a GPU without ASTC: an Intel Mac, a desktop GPU with only BC, and the Mac's `goose`,
  whose built-in gfx lacks compressed formats (below). Chosen on 2026-11-08: 6 × 6
  looks the same as the JPEG and 4 × 4 side by side at the tablet's and a phone's size,
  sharp behind home and blurred, and is nearer the master than the JPEG (44 to 45 dB
  against 40 to 41, summer 40 against 37.5); 4 × 4 (4 MB) buys nothing visible.
- **Loading** (`src/app/background.c`, the program's own C, a `c_sources` entry in its
  `.build` sidecar): gfx has no compressed formats, so
  `patches/goose_gfx/0004-compressed-textures.patch` adds them and
  `gs_gfx_format_supported` ([findings](../goose-findings.md)); the Goose side compiles
  against the built-in `gfx.goose`, so the C calls gfx's C API itself (`gfx_api.h`), which
  also uploads the embedded bytes with no copy on the data stack. Where gfx and the GPU
  take ASTC 6 × 6 (Android, whose gfx is patched at build time), the texture is made from
  the embedded blocks; elsewhere, or where a weak stand-in answers for an unpatched gfx
  (the Mac's `goose build`, which links the release's prebuilt `libgoose_gfx.a`), the
  JPEG is decoded with stb_image to RGBA (its NEON loops on for ARM, `STBI_NEON`; SSE2 on
  x86 by itself), into a texture of 16 MB. goose_gfx's `load_texture` reads only PNG and
  BMP from a file. A season is picked by a settings tile, which lights in the frame after
  the tap; the photograph loads in the frame after that, once the lit tile is on screen,
  after a `gfx::flush()` that lets the GPU finish with the old scene so the new one takes
  its place in SDL's shared block. On the tablet a season change's longest frame went
  from 54 to 66 ms to 22 ms (one frame late at 90 Hz). Only the current season is
  resident: the sharp texture behind home and the blurred copies; nothing passes through
  the data stack, and the embedded file's pages are given back once read
  (`madvise(MADV_DONTNEED)`: clean pages of the APK, but counted while resident).
  Settings' thumbnails shrink each season's photograph on the GPU in turn (the JPEG path
  decodes and scales to 512 first), waiting for the GPU after each so only one is alive
  at a time. The JPEG and ASTC masters are in git (2026-11-10), and
  `src/app/background.c` embeds them with C23 `#embed` under `__has_embed`, so a checkout
  that lacks them still builds and shows the page color, and one without the ASTC files
  decodes the JPEGs everywhere. Android embeds only the ASTC files and compiles no stb_image
  (`#ifndef __ANDROID__` in `background.c`): every Vulkan GPU the app targets samples ASTC
  LDR, and an Android GPU without it would show the page color, no photograph, as a
  checkout without the images does. The ASTC files add 7.5 MB to `libmain.so` (the JPEGs
  2.2, the Mac's only), which the APK stores uncompressed (11.4 MB with the ASTC alone;
  13.7 with the JPEGs too, 6.0 without the ASTC): ASTC hardly compresses (3 to 5%). PNG was rejected at about 5 MB a season; AVIF
  needs libavif and an AV1 decoder on both platforms to save about 1 MB.
- **One size for every screen** (2026-11-08): at 1.87 MB as ASTC, the sharp image
  sits in SDL's shared 16 MiB block; sizing it by the screen's density (1024 to 1536 on
  a dense phone) would save at most 1 MB there and needs several encodings or a choice
  at load, so it stays 2048 everywhere. Larger tablets stretch it 1.25 to 1.41×, as
  before.
- **The plain background** (2026-11-09, `prototypes/plain.html`, fade b): in place of
  the photograph, a fade matched to the season's board, chosen in settings (the Theme
  row's switch, below; the player's file's `background = photo|plain`, photo by default).
  The season still picks the board, by the date or as chosen; only the photograph goes.
  From the theme's page color at the top to a deep tone of its frame at the foot, with a
  faint light of its dark square behind the middle (wider than tall, as the board sits
  there) and the corners 30% darker, mixed in linear light and dithered by under half a
  level so the dark fade shows no bands. Its colors, top and foot:

  | | Autumn: wood | Winter: stone | Spring: birch | Summer: sunset |
  | --- | --- | --- | --- | --- |
  | Top | `#1e1510` | `#0c1724` | `#101b15` | `#21150f` |
  | Foot | `#4a2c1a` | `#2c3a4c` | `#2f3d30` | `#4f2e28` |
  | Light (the dark square) | `#7a4626` | `#5a6777` | `#6b7f6a` | `#9a6655` |

  It is a function of the pixel's place on the screen, drawn where the photograph would
  be sampled (`FADE_FN` in `src/render3d/shaders.goose`): by the board pass (sharp
  behind home and settings, dimmed to 0.8 behind the flat game as the blurred photograph
  is), by the glass (in place of the glass copy), and by the 3D board's backdrop (dimmed
  to 0.8, as the flat game's). With it no photograph is decoded, uploaded, or held, and no
  blurred copies are made: the scene is 1 × 1 stand-ins, and choosing it loads in the
  frame after the lit tile as a season does. Settings' thumbnails still shrink each
  photograph once (the switch's photograph half shows the season's), with the four fades
  drawn under them in the same texture. Where the photograph is decoded (the Mac) the
  fade saves its 16 MB texture and copies; where it is ASTC (Android) they sit in SDL's
  shared block, so the fade saves about 3 MB inside that block and the photograph's
  upload and blur on a theme change (on the Mac, home's graphics 52 → 34 MB).
- **Glass is a pre-blurred copy, not a live blur.** Snowtime measured live backdrop blur
  costing more than its weather animation, and switched to a copy of the background
  blurred once (its `docs/architecture/scene.md`). Here the scene is blurred on the GPU
  when the season is picked, into a small texture (the blur a 24 px one would be at
  1280 px wide, saturation 1.3), so nothing pre-blurred is stored. Natively
  (`src/app/scene.goose`) two more passes blur the 512 px copy into a 256 × 256 one (sigma
  3.9 texels, on the copy's 2.8), the same at every screen size for the same reason as
  the board's copy. A glass panel samples it at its screen position: one texture fetch
  per pixel, no blur per frame.
- **The blurred copies stay as they are** (2026-11-08): smaller copies (a sigma-5.6
  blur at 512 keeps its look at 256 or 128), a dual-filter (Kawase) chain, sampling a
  mip of the photograph, and copies blurred offline and shipped compressed were weighed
  and dropped. The two copies are 1.25 MiB together inside SDL's shared 16 MiB block
  ([GPU memory](#gpu-memory)), so none would save measurable memory, and the blur runs
  only on a season change. The thumbnails as ASTC (0.4 MB) were dropped the same way.
- **Glass layers**, bottom to top: the copy, dimmed as the table says; the theme's
  glass tint; a 1 px border of white at 14%; a 1 px top highlight of white at 12%; a
  shadow `0 12px 32px -14px` of black at 55%. Corner radius 28 px.

### Light

The 2D board is kept simple: flat squares with no light pool, as on the design boards.
The pieces have a soft, diffuse light from above the board and toward its top
(2026-11-07): the rounded outer edge catches it on its upper side, most halfway round,
and is in shade on its lower side; in the groove the wall facing the light is lit and
the other in shade. Nothing else: no glossy spot, the face matte. Shade darkens toward a
deeper tone of the piece's own color, which keeps a cream warm where black would grey it. A strong light pool
and, with the tabletops, a crafted board with a soft light were tried on 2026-11-07 and
set aside. The 3D board has one key light from the top left,
as in the design boards, a few terms in its shaders with no lighting pass. The terms
the prototype tried, kept for 3D:

- **Board**: a pool of light toward the top left (warm white at 22%) falling off to
  black at 40% in the bottom-right corner, over the squares; a soft inner shadow where
  the squares meet the frame; the frame bevelled, lit on its top-left edge and shaded
  on its bottom-right.
- **Pieces**: a specular spot at 32%, 28% of the disc (white at 60% on light pieces,
  30% on dark), the face darkening toward the bottom right (black at 18%, 30% on dark),
  a lit upper rim and a shaded lower one, and a soft shadow cast down and to the right:
  a tight contact shadow and a wider one. The disc's side is 0.8% of the board deep.
- **3D**: the same light on lit meshes; the side of a disc lit on the left and dark on
  the right.

### Controls

The prototypes named below by file alone (`back.html`, `win.html`, `draw.html`,
`gear.html`, `exit.html`, `puzzles.html`, `chip.html`) were removed on 2026-11-10 once
built or superseded; they are in git history before that day.

- **Buttons** are glass tiles: white at 10%, 16% when hovered, 24% while pressed (and
  scaled to 0.96), with an inset 1 px border of white at 20% and a top highlight; radius
  22 px; at least 88 × 88 px (dp: the screen's shorter side is 800, `gui::scale_of`) for
  small hands, icons half the tile with strokes 2.4 units of their 24-unit grid. A
  primary button is the glow color at 22%.
- **Icons** are line icons on a 24-unit grid with round strokes, in the Lucide style:
  undo, hint (a bulb), restart, back (an arrow left), next, star, crown, lock, and the
  puzzle themes' target, crown, and shield; the 3D camera's buttons' board from above, board
  in perspective, magnifier with + or -, and board on an orbit. The home tiles' icons are filled shapes,
  which read better large: two figures, a robot head, a jigsaw piece.
- **Game screen** (`prototypes/game.html`, chosen 2026-11-07 over three other takes):
  the board in the middle, leaving the game on its left and playing it on its right,
  each control a glass tile with an icon and a word, as on home, since icons alone (three
  arrows for undo, restart, and back) confused. The landscape layout is taken only where
  its flat board fills at least about 2/3 of the height less the margins
  (`panel::landscape`); a wider-than-tall window short of that, near square, keeps the
  portrait layout, the bar above the board and the play below it, as does the 3D board
  (the user, 2026-11-09: a near-square window's landscape had a small board between
  square-ish panels). At 800 dp tall the hand-over is at about 981 dp across; every
  device's landscape passes, the foldable's closest at 69%. **The game's controls are the
  3D screen's** (task 054, the user 2026-11-09: the UI round the board only, the boards
  untouched): in landscape the flat board between the 3D screen's short corner panels
  (`panel::flat_corners`; "Board and pieces", 3D board, the game screen round it), back
  and a panel of settings and start over in the top left, whose turn, the eye, the hint
  beside undo move, or the clocks, in the top right, 232 × 352 dp (192 on a phone), the
  same tiles in the same places as round the 3D board; the board as it was, a square of
  the height less the margins centered across, which the corner panels leave the same
  room (they free none it could grow into). Near square (4:3, a foldable) the flat
  screen's corner panels are no wider than the old ones, 192 dp, and the play panel 368
  dp tall as a phone's, so the board keeps its 587 and 519 dp; the 3D screen's stay 232
  there. The flat screen has no round buttons (the 3D board's view, zoom, and showcase).
  In portrait the game's bar and play are as wide as the 3D screen's, the screen less the
  margins, where the board is narrower (4:3 and a foldable in portrait). A puzzle keeps
  the panels below. In landscape the board fills the height
  less a 24 px margin, between two glass panels 232 px wide and as tall as it (where
  that leaves the board under 720 px, the tablet's at 16:10, the panels narrow down to
  192 px for it: 587 px at 4:3, 520 on a foldable; 2026-11-08; where the width holds the
  board under 372 dp, a 16:9 phone less its cutout at a side, the panels stay 372 dp tall,
  centered beside it): on the
  left back (see "The way back" below) on its own glass tile, 88 px tall, over a panel
  12 px under it holding settings and at the bottom start over, the column as tall as
  the right panel; 88 px rows (the floor for
  small hands, 2026-11-08) with 34 px icons and 24 px words (in a narrowed panel, where a word doesn't fit beside its icon,
  both icons over their words in 96 px rows); on the right whose turn it is (a 72 px piece of its color with
  the glow ring, 4 px of the glow color at 80% and a 22 px glow, over "White's turn"),
  or the two clocks, and at the bottom undo move, a tall 132 px tile with a 48 px icon
  over its word, on two lines where one is too wide ("Võta käik / tagasi" in a narrowed
  panel), else in a smaller face (96 px in a panel under 420 px tall, a phone's, as a puzzle's next). In portrait the left side is a bar above the board, its three tiles in
  a row, back first, 88 px tall, thirds of it while each word fits, else each as wide as its word and
  an even share of the rest (2026-11-08); where a third would be under 170 px (a phone),
  the bar is 8 px taller and each icon stands over its word, which needs less width. The
  right side is below it: whose turn, or the clocks side by side, over undo move across
  the width, 88 px tall. Start over sits far from undo move so it isn't hit for
  it. There is no move-hints toggle: help that does the thinking doesn't belong a tap
  away, and move hints are a setting, reached through settings. The lookout's eye and the
  hint's tile are on the play panel ("The lookout and the hint", below).
  Undo move takes back one move, also one still animating; start over goes back to where
  the game began; back goes home; settings opens settings, whose back returns to the
  game. Against the computer the child's pieces are at the bottom: when the child plays
  black the board is turned, black playing up the screen (2026-11-08). While the
  computer thinks its piece's glow ring pulses once, and its move comes after a short
  pause, or against the clock after the time a player of its level would take;
  undo move then takes back the child's move and the computer's reply
  ([computer player](ai.md#in-the-game)).
  The words are 24 px; the turn's words say who has won once a side has.
- **The way back** (`back.html`'s take b, chosen 2026-11-09 over a, the arrow alone): one
  control on every screen that leaves, a glass tile with the arrow and "Back" side by side
  (34 px icon, 24 px word, 20 px either side, 88 px tall and at least as wide), in the
  top-left corner: over the left panel on the game and a puzzle in
  landscape, first in the bar above the board in portrait, beside the title on the
  puzzles' library and a theme's page (at the left in landscape, in the head in
  portrait), and at the start of settings' title row. It goes where the screen's way out
  goes: the game home, a puzzle to its theme's page, a theme's page to the library, the
  library home, and settings where it was opened from; Android's back and Escape do the
  same. It replaced buttons named for where they went ("Home" on the game, "Puzzles" on
  a puzzle), which children read as different controls, and a bare arrow on the
  puzzles and settings; take back became "Undo move" ("Võta käik tagasi") so it says
  it is about the move, not the screen. On a theme's page in landscape where the levels
  wouldn't fit the height beside a worded back (Shots on a phone with its insets), back
  is 88 px square with the arrow over the word. On a phone in landscape settings' title
  row (back, the tabs, the language) is wider for it, so the preview board beside it is
  smaller (431 to 400 dp at 540 dp; 285 to 219 in Estonian at 480 with the Pixel's
  insets). Home's setups and who's playing keep their square arrow.
- **Clocks**: each side's piece and its time, m:ss in 36 px tabular figures, in a tile
  of radius 20 px; black's on top, as black's side of the board is (white's on a turned
  board, so the child's clock is the nearer one). The running clock is
  the glow color at 18% with a 2 px glow border and its piece has the glow ring; the
  other is white at 6% with its text and piece dimmed. Under a minute shown (0:59) the
  running clock turns autumn's glow gold (#ffd75a) in every season, and at 0:20 and under
  the forced-capture red: the tile at 16% with a 2 px border and the figures in that
  color (2026-11-09). The waiting clock and a stopped one never do. The hue changes
  with the second shown, so it adds no frame. A running clock redraws once a second,
  when the time it shows changes; a stopped one draws nothing. The time shown is rounded up, so
  0:00 shows only once the time is out. The player whose time runs out loses, as FMJD's
  rules say, and the win card shows the other. The clocks start with the first move:
  white's first move is untimed, then black's clock runs (2026-11-08), so a child can
  settle before anything counts. A move adds the increment to the clock that ran; take
  back runs the clock of the side to move again, the time taken staying taken, and none
  back at the start; start over sets both full again. Only time with the game on screen
  counts: not while Android has the app paused or it is in the background, nor while
  home or settings shows. A clock is the value `src/game/clock.goose`, no graphics, saved
  with the game. The choices are no clock, 5+3, and
  10+5 (five minutes plus three seconds a move, ten plus five): 5+3 is FMJD's usual
  blitz and both are in IDF's 8×8 rapid list, gentle enough for children.
- **A win** (`win.html`'s take a): once the winning move has shown, the
  winner's pieces answer, with no particles. Every moment is a function of the time
  since the win. The winning piece, the last move's, lifts on its square with its glow
  ring (0.35 s, easing out), and stays so. A ring of glow passes across the winner's
  other pieces outward from it: each lifts with its ring and its square lit in the glow
  color at 40% for 0.6 s, from 0.15 s plus 0.08 s per square of distance (straight
  across the board). A lifted piece rises 6% of its size and grows 5%. From 0.9 s the
  board and its pieces dim to 55% over 0.6 s, under the winning piece, which is drawn
  last and stays lit above the dim; from 1.0 s a glass card over the board (356 × 300
  px; on a board under 720 px all but the buttons' height shrink with it, the buttons
  no narrower than 88 px, so it stays near half the board; where it would cover the
  winning piece, as on a phone's board, it moves into the half away from it) slides up 28 px as it fades in (0.7 s, easing out), back and restart (primary,
  112 × 88 px) on it, and from 1.2 s the winner's piece, crowned, with its ring fades in
  above them (0.5 s). The screen is still from 1.7 s, or once the glow has passed the
  winner's farthest piece (up to 1.77 s on 10 × 10); the frame then is drawn at rest,
  and none after. A win with no winning piece to lift (a flag while the last move still
  shows, a position set up already won) starts at the dim, still from 0.8 s. The dim is
  the board pass's and the piece shader's, not a fill over them, so the winning piece
  can stay out of it while the card, in the UI's draw, is over it; the lit square is the
  piece shader's too, drawn under the piece. The panel's piece shows the winner.
- **A draw** (`draw.html`'s take a, chosen 2026-11-09; the rules in
  [rules](rules.md#draws)) is calm: once the drawing move has shown, the clock stops,
  the board and its pieces dim to 55% over 0.6 s, nothing lifts or glows, and a card
  like the win's slides up 28 px as it fades in from 0.1 s to 0.8 s, still from then:
  both pieces side by side, just touching (88 px, overlapping 8), "Draw" in the label
  face, and why in the body face at 66% (broken into two lines where it doesn't fit),
  over back and play again. It is sized as the win's card (taller by the words) and
  keeps off the piece that made the last move as the win's keeps off the winning piece;
  on a board under 540 px the pieces are left out and the words say it. The play panel
  shows both pieces and "Draw" where the winner's piece and words go. Undo move takes
  the draw back. Against the computer a draw counts as 0 (computer player, "In the
  game").
- **The countdown** before a draw (take a): once a count is in its last five moves, a
  line under whose turn says it, "Draw in 3 moves", or for a count only the strong side
  can end, "White must win in 3 moves", naming the side; a position come twice says
  "Same position twice" over "A third time is a draw", dimmer. In landscape a row of
  dots (14 px, 9 apart, in the glow color) stands between them, five with one going out
  a move, or three with two lit for the repetition, and the line is in the body face,
  broken in two where the panel is narrow; in portrait the line, in the small face, goes
  under the turn's words beside the piece, with no dots. In landscape with clocks it
  goes under the clocks. A 3D board's short corner panel closes the gaps round the
  piece, leaves the dots out, and takes the small face. Where clocks leave no room for
  the line (`draw.html`'s `fit=b`), a short form stands between them: "Draw in
  3", or "Repeat 2/3" for the position come twice, whichever side's count it is. In a
  portrait panel the word in the small face is over the figure in the label face, the
  clocks narrowing for it with 12 px either side; in the corner panel it is one line in
  the small face in a 36 px gap between the clocks, undo move giving up what the panel
  lacks (120 px on a tablet). Two lines are made as even as they can be, as the
  prototypes' balanced wrap. The strong side's count shows on a tie with another, so the words don't swap
  from one move to the next.
- **Home** is a title menu (`prototypes/home.html`, chosen 2026-11-07 over the
  icon tiles and two other takes): the scene and the 3D board, and one glass column
  with the wordmark, then continue, a friend, the computer with its level, and puzzles
  with stars, then settings, each an icon and a word, in rows 88 dp tall, 2 dp apart. In
  portrait settings is instead a gear beside the wordmark, so the sheet leaves the board
  its room: the gear alone, 40 dp at 85%, with no tile, in an 88 dp tap reaching 8 dp over
  and under the row, clear until pressed and then lit round as a pressed row is
  (`gear.html`'s take a, chosen 2026-11-08 over the 88 dp quiet tile, which
  looked too big beside the wordmark, and the X's round glass button, which the X itself later left); the name may run
  under the tap's clear side, up to 12 dp from the gear; so too in a landscape too
  short for the menu with settings as a row (a phone under about 590 dp tall), where the
  column widens to 440 dp for the wordmark and the gear. Under the wordmark it keeps
  14 dp, less on a short screen, but never less than the gear's reach, so its tap never
  meets the first row's: where even that doesn't fit (the Pixel 7a in landscape at 480 dp
  less its gesture bar, 3 dp short), the rows close up from 2 dp apart to about 1
  (2026-11-10; it had overlapped Continue's tap). The wordmark's letters close up
  where the gear leaves them too little room (2026-11-08). In the
  screen's top right, 24 dp from both edges of its safe area, a bare X, 34 dp with strokes of 2.8 grid units at
  80%, in a round 88 dp tap, closes the app at once, asking nothing, since the game is kept anyway; on the
  menu and in a setup, in both orientations (`exit.html`'s take b, chosen
  2026-11-08 over a quiet last row and a door, as a round glass button; made a bare X,
  `gear.html`'s `x=d`, the user, 2026-11-09, to match the bare gear). One place in both orientations, it
  costs the menu nothing (a last row would take the portrait board's room and lengthen
  the sheet phones can't fit), it is far from where children tap and hold a tablet, and
  an X is what closes things in the apps children know; a door reads less surely at
  34 dp, and a power sign suggests turning the tablet off. At rest it is the X alone, no
  disc, sized to the bare gear's weight; pressed, it lights round in its tap (white at 10%
  and a faint 1 px ring) and goes down to 0.96 (`gui::bare_x`). In landscape it sits above the photograph,
  clear of the board (28 dp right of its edge, 8 dp above its top; on a phone, where the
  board would reach it, the board moves down to 8 dp under it or narrows to 16 dp left of it,
  whichever leaves it larger); in portrait, where
  it would reach the board, the board moves down to 16 dp under it and shrinks to keep
  24 dp above the sheet (640 to 620 dp on the tablet). The board keeps 40 dp above and
  below it, down to 24 where a setup's tall sheet near square would leave it under 40%
  of the width (2026-11-08). A board under 128 dp isn't shown (a setup on a short phone;
  `board::SMALLEST`, the same for settings' preview): its squares would be under 13 dp
  on 10 × 10. The pieces on its tiles still are. A friend
  and the computer open a new game's setup in the same column: back (88 dp) and the title, then
  a row of tiles per choice, lit as in settings, each with its dim name above it: which
  draughts (international 10 × 10, the default, Brazilian 8 × 8, or Russian 8 × 8, each
  with a small board at the start), the level against the computer (easy, the default for a new player, the user's call
  of 2026-11-09, medium, hard, with one to three pips), the child's pieces against the computer (white, the default,
  or black, each tile showing its piece; 2026-11-08), and the clock (none with a
  stopwatch, 5 min +3 s a move, 10 min +5 s a move); then play, a primary row. Every tile
  is 88 dp tall at least (2026-11-08). In a
  landscape too short for the column (a phone), it becomes two columns of 330 dp side by
  side: back, the title, the draughts, and the level in the first; the child's pieces,
  the clock, and play in the second, the title in a smaller face if it needs it, play at
  the second's bottom, level with the first's last tile so both columns end on one line
  (2026-11-08); down to
  290 dp each where the second would reach the X (a 16:9 phone less its cutout at a
  side). In portrait, where the sheet would reach the X (the computer's on a 9:16 phone
  at 480 dp), the sheet takes the height, 8 dp under its top at least, its margins above
  and below the content shrinking from 32 dp to fit, and back, the title (in a smaller
  face where it needs one), and the X share its first row; no board shows. The
  choices are kept for next time in the player's file, and play replaces a saved game
  without asking. Beside a setup the board is the game play will start: the chosen
  draughts at its start, 10 × 10 or 8 × 8, turned when the child plays black against
  the computer, changing as the choices change; back to the menu shows the game in
  progress again, and play starts the game as the board shows it, so nothing on it
  jumps. The board switches at once, rather than crossfading its pieces as home and
  settings do: it stays in place, so a crossfade between 10 × 10 and 8 × 8 would switch
  the squares halfway under half-faded pieces, and the column beside it, opening the
  setup or lighting a tile, changes in one frame too (2026-11-08). Natively the setup's
  board is a board of its own (`Shell.next`), set to `rules::start` when the draughts
  chosen differs from it; a tap's frame still shows what it declared, and the next
  shows the board and the column changed together. The draughts' tiles are thirds of their row while each name fits a
  third with 16 dp either side; else, as in landscape, each takes its name's width and
  an even share of the rest (2026-11-08), each at least 88 dp wide; thirds again where
  the names leave nothing to share. A tile's word still too wide for it, as a
  translation's may be, takes the small face. Home's computer row notes the kept level. The language is
  only in settings (2026-11-07): kids who can't read yet don't need it on home, and a
  tablet set to one language can still play in another. In portrait the column is a sheet below the
  board. **Settings** (`prototypes/settings.html`, regrouped 2026-11-07): back and the
  title, with the language at the title row's right end on glass, each named in itself;
  the choices as words in two glass groups (radius 24 px, icon and title in 24 px) by
  what they change; and beside them one preview of what they make. In landscape the
  choices take the width they need at the left, as home's menu does, and the board the
  rest, about two thirds, so from home the board only moves a little; in portrait the board is
  on top, as large as the rest leaves, and the two groups stand side by side under it.
  **Game**: the draughts a new game starts on (international, Brazilian, Russian; the
  setup can still change it) and move hints; the tutorial's row (one tile, learn the
  moves) comes with the tutorial, taken out until then so the tablet's
  landscape shows both groups (the user, 2026-11-09). Last, the privacy note
  (`settings.privacy`, App Review Guideline 5.1.1(i)): the policy in one sentence, dim
  in the small face, with no link out, as the app has none. It sits at the group's title row's right end where it fits there in two lines
  at most (the stacked landscapes, which have no height to spare: one line in both
  languages on the tablet and the iPad), else at the glass's foot, wrapped, where the
  game's group is as tall as the look's (portrait, a phone's tabs), so it moves no
  layout (2026-11-09).
  **Look**: the theme (the row's name, "Theme") as
  thumbnails of the four photographs (62 × 40 px), or of their plain fades when the
  plain background is chosen, and, last, a tile for by the date, so on a phone in
  portrait, where the row wraps, the four seasons keep one row and by the date goes
  under them, in the same order at every size (2026-11-08). With the theme's name, a
  two-part switch, the season's photograph or its plain fade, the one chosen lit
  (`settings::switch`, `prototypes/plain.html` place b): where the names are above the
  tiles (portrait, near square, a phone), beside the name at the line's right end, each
  half 88 dp square, the line 92 dp tall; where the names are at the tiles' left (most
  landscapes), under the name in its 120 dp column, within the row's 88 dp: each half
  58 × 68 dp, under the 88 dp floor. Two 88 dp halves need 180 dp across, and a taller
  row leaves the tablet's landscape, which has 8 dp to spare over its navigation bar,
  one group at a time (`test/shell/sizes` gives the halves on their own). Where the
  choices' 55% of the page has 60 dp more than they want (16:9 and wider: the Play
  tablet shot at 2560 × 1440), every name's column widens to the switch's 180 dp, so
  each half is 88 × 68 dp; the rows keep their height, and the board beside them is 56
  dp smaller there (639 to 583 dp) (2026-11-09); and kings (auto, crown, or stack, the last two each with its
  king drawn on the tile). Between them the Board row, flat or raised (the file's
  `board = 2d|3d`): its 3D tile plays the game on the 3D board (`settings::raised`,
  `src/shell/prefs.goose`; the game screen round it is under "Board and pieces"), and
  shows it on every screen with a board: home, the preview here (its kings' auto a
  stack), and a puzzle. Each
  setting is a dim 18 px name at the left of its tiles (above them in portrait); a tile
  has radius 16 px and is lit in the glow color at 22% with a 2 px glow border when on.
  Every tile, the language's and the seasons' too, is 88 px tall and wide at least
  (2026-11-08); the title row is 100 px,
  the language's glass round its 88 px tiles.
  The preview is the board as the choices make it: its size, the kings,
  and what the move hints show (all moves: the selected piece's capture; mistakes only:
  a wrong move's red ring and the piece that must capture pulsing), over the season's
  photograph. It is home's board: opening settings moves it aside, and back moves it
  home (see "Transitions").
  Natively (`src/shell/settings.goose`) the preview is a board of its own on one fixed
  position, the same on every board size and a square in from the corner on 10 × 10:
  white must capture two, with the man on d4 or the king on h6. With all moves d4 is
  selected and its capture shown, target and stop; with mistakes only, a wrong move to
  c5 flashes and both capturing pieces pulse as in a game, then the ring and the pulse
  stay lit and still, so the screen draws nothing more until the next tap. Each tap
  sets the preview up again. The choices take the width their words want, at most 55% of
  the page, and wrap beyond it; near square (4:3, a foldable), where the wrapped rows
  would run past the page's foot, each setting's name goes above its tiles, as in
  portrait, and the column narrows to its widest row (2026-11-08); where that runs past
  the foot too, the names go back to the left and the rows take the width they want,
  unwrapped (a foldable), as long as the board keeps 128 dp beside them (a phone: the
  choices at most 70% of the page). Where that doesn't fit, the board goes on top and the
  groups side by side under it, as in portrait, so a window that widens goes from portrait
  to landscape without tabs between (task 050, the user 2026-11-09): the hand-over is at
  about 870 × 800 dp, and from about 800 × 930 dp to square the groups leave the board
  under 128 dp, and none shows. Where even that doesn't fit (a phone, a small window), one group shows at a time:
  two tiles, the game's and the look's icon and title, each on glass as back is (a plain
  tile alone was hard to read over a bright photograph, 2026-11-09), the shown one lit, choose which,
  in the title row in place of the title in landscape and in a row under it in portrait
  (on a phone, its shorter side under 600 dp, where the groups side by side would leave
  the board under 45% of the width, or under 220 dp, 45% of a 553 dp phone's; a larger
  screen keeps them side by side as long as they fit under the title row, so the
  foldable's and 4:3's portraits show both with a 206 and 269 dp board, task 050), and the
  group's glass, without its title row, is as tall as the taller of the two so the board
  stays put; in portrait it is its own group's height and the board takes the rest, larger
  on the game's tab (the game's glass as tall as the look's ended in empty glass under its
  rows, 2026-11-09); where the group is taller than the room under the tabs (a small
  window), its glass takes the room down to the foot, no board, and its rows scroll inside
  it ("Small windows"). Side by side, each group is as wide as it wants unwrapped where
  both fit the page, centered, else they share the width in proportion to what each
  wants. Where the theme's five wrap, they are an even grid three across (two where three
  don't fit), not a ragged wrap; in a small window slim tiles ("Small windows"). A board under 128 dp isn't shown, as on home (a 9:16 phone at 480 dp). In
  portrait, where the title doesn't fit beside the worded back and the language in the
  row labels' 30 dp face (a phone: at 548 dp "Settings" had 61 dp, "Seaded" 45 and was
  left out), back is the arrow over the word in an 88 dp square, which leaves 107 dp; at
  480 dp, where that leaves under the headings' 24 dp face, the language's glass also
  leaves out its globe, which leaves 87 dp, "Settings" 80 in that face. A title still too
  wide takes a smaller face, or none (2026-11-08, 2026-11-09). The tiles' notes and the thumbnails' labels are in the 17 px
  face, which makes them a little wider than the prototype's 13 px, so the landscape
  board is about 550 px where the prototype's is 590.
  **Puzzle picker** (`puzzles.html`'s take a, a library list, chosen
  2026-11-09; rejected: b's large theme tiles, which shrink long Estonian names and hold
  the fewest themes a screen, and c's library beside the theme, which needs two
  scrolling panes): two views, a library of the themes and a theme's page. The library
  is back, the title, the draughts switch, and one glass row per theme (the glass panel a
  level's row on a theme's page is, lit only while pressed: a plain tile barely showed
  over the photograph, 2026-11-09), 124 dp tall on the tablet and 96 on a phone: its
  mark (the theme's icon, a book, two men and a jump, a crown, a target, a crowned ring,
  on a disc of the glow color at 20%), its name, its stars as home counts them, a star in
  the glow color before "n / total" (three a puzzle), and a bar of them in the glow color
  over a faint track (`prototypes/puzzle-set.html`'s take b, the user 2026-11-09; its
  Continue row and "Next: Easy 3" were left out). Learn is open; the others open once
  half of Learn is solved, and until then each mark is plain with a lock badge, the name
  dim, and "Solve n more in Learn" in place of the bar, and a tap on it does nothing.
  **The draughts switch** (`prototypes/puzzle-set.html`, take a, the user 2026-11-09;
  rejected: b's name under the title opening a list, and c's setup tiles with the themes
  as a grid) is settings' draughts tiles, International 10 × 10, Brazilian 8 × 8, Russian
  8 × 8 (each its name over its size, 88 dp tall, as wide as settings' tile would be,
  widened in proportion to fill a row), joined on one glass 4 dp round them and between,
  the player's draughts lit. It is settings' draughts choice, one setting: a tap sets
  new games' draughts too, saved as settings saves them, reads that draughts' set at
  once (`shell::load_set`), puts the list back at its top, and home's count follows; the
  lit tile takes a tap and changes nothing. It stands at the title row's right in
  landscape where the title, its note, and the switch fit the width beside back, else
  (portrait, the compact window) in a row of its own under the title. A draughts with no
  set of its own (as Brazilian was until 2026-11-10; now none of the three) shows
  International's with "International's puzzles for now"
  ("Esialgu rahvusvahelise kabe ülesanded") under the title in the small face, over one
  dark copy 1.5 dp down (`gui::shaded`: the halo's nine quads a glyph would take the
  frame past `gui::MAX_QUADS`, 512), broken onto two lines where one doesn't fit (the
  test faces at 480 dp; the real font's 271 dp fits the 278 left beside back). The title
  "Puzzles" stands in the title row (beside back in portrait), bare on the photograph
  over a soft dark halo (`gui::shadowed`: eight dark copies 2 dp round it at 20% and one
  2 dp down at 35%), as it sat partly over spring's and autumn's birch bark at the
  tablet's and iPad's sizes (2026-11-09); until the switch it was left out in landscape
  under 600 dp tall. The rows are one column at most 600 dp wide in portrait, and two in
  landscape where two columns of 420 dp fit beside back (the tablet, a wide window) or
  one doesn't fit the height (phones); in portrait under the switch's row they give up
  height to fit the page (a foldable, a 9:16 phone), down to 88 dp, and where even that
  doesn't fit (a small window, a 9:16 phone with its insets) they keep it and scroll, in
  either orientation. They center on the screen:
  in a tablet's landscape the title and the rows start below back, so they take the
  whole width (until 2026-11-09 they kept clear of back's column too, which pushed them
  against the right edge: 183 dp left of them, 27 right at 16:9); in a phone's, where
  the rows reach back's height, they center as far as clearing back allows. A row opens the theme's
  page: back (at the left in landscape, in the head in portrait), the theme's mark,
  name, and count, over its levels as glass rows, each its level's mark (three rising
  bars, one to three filled) and name beside its tiles, 96 dp on the tablet and 88 on a
  phone, in rows as even as they go (ten go five and five); where four tiles don't fit
  beside the label (a phone in portrait) the label stands over them. Each tile shows 0
  to 3 stars in the glow color, outlined for those not won, and the theme's first
  puzzle without stars is lit as a chosen tile. Where the page would be taller than the
  safe area (Shots' two levels of ten on a phone with its gesture bar), in landscape
  the theme's mark and count stand under back in place of the head, and in portrait each
  level's label is its mark alone, the spacing as on a phone in landscape. Back on a
  page (and Android's back) goes to the library, and from the library home; next on a
  puzzle goes on inside its theme and after its last back to the library. Behind it the
  sharp photograph and no board. **A puzzle** (`prototypes/puzzle.html`, take c, chosen
  2026-11-08): the game screen's layout, the left side the game's, its back going to the
  theme's page; on the right whose puzzle it is as the game's turn piece (72 px, its
  side's color, the glow ring while it is the child's turn, none once solved), so a child
  who can't read knows the side they play, then the goal's icon in the glow color over its
  words ("Win 2
  men", "Win a man", "Become a king", "Stay safe") and under them, in the small face,
  whose puzzle it is ("White to move", "Black to move"), the three stars at stake, 44 px, and at
  the bottom next, the tall tile, at 35% and taking no tap until the puzzle is solved,
  then lit as a chosen tile. While a piece waits partway through a capture, next is at
  full strength, unlit, and pressed then it is a miss: the capture is left unfinished,
  which is no move, and the piece slides back from its stop as a wrong move does. There is no hint tile, as in a game. A wrong move plays,
  then 0.35 s after it lands slides back along its way, the pieces it took fading back
  in, while its square flashes the red ring over a ghost of the piece fading from 80%;
  the goal gives way for 2 s to "try again" in a pill of the forced-capture red at 16%,
  and a star goes out. When the other side would answer the wrong move by taking
  something back ([puzzles](puzzles.md#the-screen)), that answer plays first, 0.4 s
  after the move lands, animated as a reply is; it holds 0.8 s after it lands, slides
  back along its way without the red ring, and the wrong move then slides back as
  above (`puzzle::SHOW`, `SHOWN`, `UNSHOW`, timed by `SHOW_PAUSE` and `SHOW_HOLD`). A tap the board flashes as a mistake is a miss too, without the
  must-capture pulse, which would show the answer. A selected piece's targets never
  show, whatever the move hints (2026-11-08). After two misses the piece to move
  has the glow ring, pulsing twice, then still. A right move that leaves the goal ahead
  is answered 0.5 s after it lands. Solved, the words say so, the stars won pop in one
  after another (56 px, 0.6 s each, 0.15 s apart), and next lights; nothing covers the
  board. In portrait the goal and the stars share a row under the board, over next
  across the width, the turn piece at 52 px leading the goal. Where a landscape panel is
  too short for the piece over the goal (a phone's), it stands beside the goal's icon, up
  to 20 px apart, the words under both (`prototypes/puzzle.html?take=c&turn=a`, chosen
  2026-11-09 over `turn=b`, beside everywhere, since over the goal the tablet shows it as
  the game does).

- **Players** (`prototypes/profiles.html`, take a, chosen 2026-11-09; what a player
  holds and the files: [players](README.md#players)). On home's menu the player's chip
  opens who's playing: their badge (64 dp, centred in the first 88 dp) and their name
  beside it in the row labels' 30 dp face on a small glass pill (`gui::glass`, 22 dp
  corners, 16 dp either side of the name, 49 dp tall, the name 12 dp past the badge's
  88 dp; the user, 2026-11-09, `chip.html`'s take d, so the name reads on a
  bright photograph), the badge bare as the X and the gear are; no name, no pill; the tap
  ends 40 dp past the name and covers both; pressed, the tap lights as the X's does (white at 10% and a faint 1 px ring,
  a pill round badge and name, 88 dp tall; `gui::bare`). It mirrors the X (the user,
  2026-11-09, after the tablet): 24 dp from the top and from the left of the board's
  side of the screen, the safe area's left in portrait, the column's right edge in
  landscape, so it is never on the column and its badge is level with the X. The board
  clears the badge as it clears the X: in portrait the centred board's room from the X
  covers it; in landscape a board that would come within 16 dp of the badge's 88 dp in
  that row moves down to 8 dp under the row or narrows, as for the X. A board still in
  the row under the name steps down below it (8 dp in landscape, 16 in portrait) where
  that costs it no size, as on the tablet with its navigation bar in landscape; a name
  that would still come within 16 dp of the X or of the board leaves the chip round,
  the badge alone (with twelve characters: the foldable's and 4:3's portrait, a 9:16
  phone's landscape at 480 dp and its portrait with the Pixel 7a's insets). This gave back the room first kept
  above the board for the chip (2026-11-09, `badges.html?home=2`, where it stood above
  the board's top left corner): the tablet's landscape board is back at 120 dp from the
  top, the foldable's portrait 339 to 411 dp, 4:3's portrait 407 to 479, a 20:9 phone's
  landscape at 480 dp 328 to 336 (291 to 299 with the Pixel 7a's insets, 346 to 349 at
  540 dp). The wordmark keeps its king; `home::player_spot` alone places the chip, and
  `test/shell/sizes` checks it at every size. Who's playing is a glass card over the home
  dimmed by black at 42%: back, the title, and a pencil; then a tile per player, 156 dp
  wide (120 on a phone, under 600 dp across), the badge 72% of it over the name, the
  player playing lit with the glow ring (4 dp, and a 22 dp glow at 50%); then + while
  there are under four. Four that don't fit a row go two and two. A badge switches to
  that player and closes the card; a tap outside the card closes it. The pencil, lit
  while on, puts a pencil badge on each tile, and a tile then opens its sheet, three
  taps from home and out of a child's way; + opens the sheet for a new player with the
  first free badge. The sheet: back (to the card), the badge and name or "New player",
  and done (a primary tile, a check); the six badges 88 to 112 dp in a row of six where
  they fit, else three by two, those other players have at 30%; the name in a field
  88 dp tall that brings up the keyboard (SDL's text input) and takes up to 12
  characters the faces draw, a steady caret while typing; and for a player already
  there, start again and, while there is another player, remove. On a phone in
  landscape the badges stand at the left, three by two, and the name and the holds at
  the right. While the name is typed the card stands 16 dp from the top, clear of the
  keyboard. Done adds a new player and switches to them, every setting at its default,
  or saves the badge and name. Start again and remove are **holds** of 1.5 s: a 4 dp
  ring 2 dp inside the tile fills clockwise from its top's middle (the glow color for
  start again, the forced-capture red for remove, whose icon and word are that red
  toward the text color), frames running only while it is held; let go early and
  nothing happens, and no dialog asks, since a dialog needs reading and a hold is what a
  child doesn't do in passing. Back goes from the sheet to the card and closes the card.
  **A badge** (chosen 2026-11-09, `badges.html` direction 1) is home's king as the light
  pieces are drawn now, its animal in the crown's place and colour: a man with its side
  and short shadow filling the face's disc, its top from `draw::MAN_BLOCK`'s `man_top`
  (the board's pieces share it, so a new piece style reaches the badges with it), the
  animal flat and bold as the crown is, with only a faint shadow inside its upper edge
  (the distance 0.035 radii above, darkening the mark by up to 30%). `badge()` in
  `src/app/widgets.goose` draws every badge. The animals are data: one SVG per animal,
  `assets/badges/<animal>.svg` (fox, hare, bear, owl, frog, hedgehog, in
  `players::ANIMALS`'s order), embedded when the app is built and baked at start by
  `src/badges/badges.goose` into a signed distance field, a 96 × 96 cell per animal (an R8
  texture of 96 × 576, 54 KB; the distance in texels, ±12 over the byte's range), in
  well under a millisecond on the Mac. The bake flattens the outline into straight
  pieces, each reaching only the texels within 12 of it, and takes inside and out from
  crossings along each row (even-odd). The shader samples it (bilinear) over a square
  of ±0.56 radii, the crown's room; a shape should keep inside the circle that square
  inscribes. Swapping an animal is replacing its file and building again. An SVG must
  have a viewBox on its svg element (the longer side spans the cell, centred) and one
  or more paths, filled together even-odd, their `d` of M, L, H, V, C, S, Q, T, A, Z in
  either case; transforms on paths and groups (matrix, translate, scale, rotate) are
  applied, as potrace writes them; fills and strokes are ignored, and no other element
  is read. A file that can't be read leaves a plain man and a line on stdout.
  `test/badges` bakes each file and draws it coarsely.

### The lookout and the hint

`prototypes/coach.html`, round 3, take a, chosen 2026-11-09; what they show is in
`docs/product.md` and [ai](ai.md#the-lookout).

- **The eye** (`panel::eye`): the lookout's toggle, a floating disc as the 3D board's
  camera buttons are (`gui::floating`, a 48 dp disc in a 56 dp target), lit in the glow
  with the open eye while on, the eye struck through and its icon at 55% while off (icons
  37 and 38, Lucide's eye as two arcs and a circle). It sits at the end of whose turn's
  line: in landscape's column under "White's turn" with its name (Lookout, *Valvur*) beside
  it, dim while off; in portrait, compact, and the short landscape panels (a phone's, a 3D
  board's corner) at the right end of the turn's row, the piece kept centered over the
  words where the panel is wide enough, or beside the clocks, which then take a smaller
  face for their time where it doesn't fit (`panel::clock_of`).
- **The hint's tile** (`panel::hint_tile`): the bulb, its word (Hint, or Where to? once the
  piece is lit; *Vihje*, *Kuhu?*), and three 12 dp pips 7 dp apart, lit in the glow for
  each hint left, faint for each spent. Lit as a chosen tile while a hint shows, dim at
  35% and taking no tap with none left or none to give (the computer's turn, a capture
  due, the game over). Landscape's column puts it over undo move, its icon beside its word;
  the 3D tablet's corner panel beside undo move, each half the width, icon over word; the
  phone's narrow panels over undo move (two halves would be under 88 dp; the 3D phone's
  corner play panel is 368 dp tall for it, `panel::CORNER_PLAY`, the gaps round the piece
  closed up where the panel is short); portrait halves of the row under whose turn, hint
  at the left; compact between the eye and undo move, each icon over its word, or icons
  alone with clocks and where the words would leave whose turn too little room for its
  own in the small face (Estonian's undo move, 2026-11-10). It is declared after undo move, so the controls' order in tests is
  back, settings, start over, undo move, the hint.
- **The marks**, on the board (`board::fill`): a piece in danger is drained, its color
  greyed, a little darker, and tinted red, solid and still (`Piece.ring.w`, `board::DRAINED`: CSS
  `grayscale(1) brightness(0.66) contrast(0.85)` on its face and side in the piece shader,
  `draw.goose`'s `marked`); a crowning square is shaded toward a deep red, darkest along its edges as an
  inset shadow (`Marks.shade` in the board pass), under the other side's king as a dark,
  still ghost (drained, at 62%). The hint's piece takes the puzzles' glow ring
  (`board::glow_on`); its square, a light ghost of the piece at 50%, lightened 20%, with
  the same ring (`board::ghost_on`, `Board.hint_to`). Only the hint pulses, two cycles of
  1.4 s as the puzzles' hint does, then holds; one ring pulses at a time (the ghost's
  stops the piece's), `Board.pulsed` saying which. A move clears them all
  (`start_move`, `show`); the game sets them again once the board is at rest.
- **On the 3D board** the same state: a drained piece's seed is below 0 (`view3d::fill`),
  which the lit shader takes as the mark and drains its color after tone mapping; the
  ghost king and the hint's ghost are fading instances, blended, casting no shadow; the
  shaded square is the field's `w` 1 in the still marks' pass (`shaders::MARKS_FRAG`,
  painted over the field as the pips are); the pulsing ring goes over the kept image as a
  puzzle hint's does (`Scene.pulse`). The drained pieces and the shade are part of the
  scene, so they draw the board once when they change and nothing per frame.

### What each side has taken

Task 052, `prototypes/game-captured.html`'s take a in its `row` look, chosen 2026-11-09.

- **Counts** (`game::taken`): the variant's start pieces of each color less those on the
  board, men and kings apart; a piece of the side not moving that was a king before a
  move and gone after it counts as a king taken, from the undo history (saved with the
  game, `board::MAX_HISTORY` moves back). Counted once a move has shown, and after undo
  and start over (`game::count_taken`), never per frame.
- **Drawn** as more instances of the pieces' quad over the UI (`panel::taken`, into the
  overlay, `board::OVER` 96): the app's men and crowned kings, 32 dp on a tablet, 26 on a
  phone, 22 compact, each a step of 0.52 of a piece after the one before, the kings after
  a gap of 0.3; a row too long for its room takes smaller pieces, to 70%, then closes up.
- **Placed** by the game's layouts (`Layout.taken`, `taken_as`): flat landscape, on
  glass under the left corner panel, black's catch (the white pieces) over white's, the
  other way on a turned board, one line where a short phone has no height for two; 3D
  landscape, one line on glass as wide as it holds above the board, at the top between
  the corner panels, white's catch at the left, black's at the right, where the board at
  rest clears it (it then clears it too in the top view and the zoom, which are a few %
  smaller on the tablet), else under the left panel as on the flat screen (a phone, whose
  board reaches the top margin), the board never smaller at rest; portrait, a row under
  the bar's tiles, the bar 52 dp taller (`panel::TAKEN_BAR_ROW`), white's catch at the
  left, black's at the right; compact, the bar's middle between back and settings, two
  rows. A catch's own glass shows once something is taken. A puzzle shows none.

### Transitions

Three switches take 0.25 s each way, eased (smoothstep), rather than switching at once:
home and settings, home and the game (continue, a setup's play, and the game's home), and
the puzzles to pick from and a puzzle. The board slides and resizes from one screen's
place to the other's. To settings it moves right in landscape; in portrait it goes down a
little as it shrinks under settings' title row. Into the game it grows into the game's
place, left in landscape and down in portrait. A puzzle's board grows out of its tile on
the puzzles to pick from, and shrinks back into it; at rest there the board isn't shown.
The screen left fades out and the one come to fades in, both drifting 40 dp the way the
board moves. Neither shows where the board is while it moves: it passes over the panels,
rows, titles, and their pieces rather than under them, so nothing of either screen lies
on its squares. A won game's card lies on the board and keeps showing as it fades. The
photograph goes from sharp to blurred and dimmed on the way into the game or a puzzle,
and back on the way out; between home and settings it stays sharp.

Between home and settings the board is home's all the way. Settings' preview is its own
fixed position, so it shows once the board has arrived, its wrong move flashing then,
and home's board shows from the first frame back: one set of pieces is ever on screen,
and when the game and the preview differ (in size too, 8 × 8 and 10 × 10) the board
changes once, at settings' place, at rest. Home and the game show one board, so nothing
changes on it: a setup already shows the game its play starts, and the column leaving
is the setup as it was. On the way
home from a won game, its dim, the winning piece's lift, and the card fade out with the
game's panels. A tap during a transition lands on the screen come to. Back, during one,
turns it round where it is. The game's clock counts no time and the computer is asked for
nothing until the transition into the game is over; the clock counts from the frame after.

Natively the shell keeps one transition: the screen left and when it began
(`shell::go_to`). Each frame it declares the screen left as it stands, with no pointer
(`gui::listen`; the game through `game::still`, which counts nothing), then the screen
come to, the game with its clock and the computer frozen. It fades and moves each one's
quads (`gui::fade`; a quad's `extra.w`, which the UI shader multiplies its result by, so
a win's card fading in fades further) and its pieces over the UI, and gives the board's
rect this frame as `shell.hole` (size 0 at rest): the UI shader and the piece shader's
pieces over the UI multiply by the outside coverage of the board's rounded rect there,
but for what is marked as lying on the board (`gui::on_board`, a quad's `extra.z` from
2; a piece's `win.w`), the win's card and its piece. It eases the board's
rect between the two layouts, and the photograph's blur between the two screens': the
board pass takes it in one uniform (`scene.x`, 0 sharp to 1 blurred, the brightness 1.0 to
0.8 in `scene.y`) and mixes the sharp texture and the blurred one, both bound; at either
end it samples only one, so a screen at rest draws as it did before. The glass copy is
the same throughout. The app fills the board of the screen `shell.shows` names (home's
between home and settings) through `shell::fill`, which scales the game's win by how much
of the game shows (`game::cheer`). While a transition runs, `shell::animating`
is true. The frame after it ends is drawn at rest, and then nothing more. A landscape
frame between home and the game declares about 130 of the 512 quads (home 77, the game
53), between home and settings about 350.

With the 3D board the same three transitions move one image instead of a
board drawn each frame. The 3D board is drawn once, through the view of the end that
shows it larger (the game's against home's; the board of the screen `shell.shows`
names, as above), into its kept image with nothing but the board and its shadow on clear;
then each frame lays that image over the backdrop moved and scaled from one end's bounds
to the other's (`shell.place`). Both ends see the board through the same camera, so the
image at one fit is the image at the other scaled and shifted. A puzzle's tile has no 3D
board: the image starts or ends at the bounds fitted into the tile's square, fading in or
out there (`shell.fade`). The flat layout the scene is filled on follows the drawn view,
so it stays the same while the image moves, and the board isn't drawn again
(`draw3d::frame`'s `hold`) unless the view or the board changes; at the end it is drawn
at rest through its own view, once. The hole is the image's bounds, square-cornered
(`shell.tall` its height; the UI and piece shaders take it in `screen.w` and `time.y`).
Behind the image the game and a puzzle show the renderer's graded backdrop, home and
settings the sharp photograph; a transition between them draws the photograph as the flat
board's does and the backdrop over it as opaque as the blur.

### Board and pieces

- **Board** in 2D: the theme's squares in a thin raised lip 1.1% of the board's width,
  corners rounded 1.6%, and a soft shadow under it (down 1.4%, 3.6% soft, black at 55%).
  The lip is the dark square's color, with a line of the light square's color on its
  outer edge (gold on wood, pale blue on stone), brightest on top, and a dark seam where
  the squares sit below it. The lip, the pieces' flat tops with one groove, and the wood
  theme's warm tones and calm grain follow the close-up boards chosen on 2026-11-07,
  which read better than the first design boards' frameless board and two-ringed pieces. The 3D board has a
  frame 2.4% of the board's width. 10 × 10 uses the same.
- **Pieces** are SDF discs filling 78% of a square, flat-topped and matte like turned
  discs, as the 3D close-up shows them: one color and one height across the top, with
  a groove cut into it at 70% of the radius (13% of the radius wide, its floor in soft
  shade, so it reads as a ring on light pieces too), only the
  outer edge rounded (from 86%), and the side under the disc (0.55% of the board deep).
  A short soft shadow falls straight down and a touch right (a quarter of the radius
  down, softened over a third of it), with a tight one where it touches. Each side has
  one color in the theme; the rest is worked out from it. The edge's highlight is
  clearer on dark pieces than on light ones. Light pieces: the side the face's color
  squared, at 92%. Dark pieces: the side 50% toward black.
- **Kings** are a setting: crown, stack, or auto (the default). Auto draws a crown on
  the face in the top-down board (the theme's dark piece color on a light piece, gold
  `#e9c46a` on a dark one), which reads at a glance, and in a 3D board a stack of two
  plain discs, no crown, as kings are in Estonian play (2026-11-07). Top down, a stack reads as
  a shadow at tablet size, so it's there for those who want it. The stack's upper disc
  sits 1.3% of the board above the lower one, its side as deep, so the lower disc's rim
  shows under it. A selected or must-capture ring goes round the lower disc, the stack's
  foot, with the upper disc hiding its back (2026-11-08). The setting applies to the game's board, the winner's piece,
  and the preview; home's wordmark keeps its crown.
- **Native form** (`src/app/draw.goose`): the blurred photograph, the board's shadow, lip,
  squares, and marks are one full-screen fragment pass, worked out at `gl_FragCoord`
  (interpolated coordinates put a square's edge a pixel off on some rows); the pieces
  are one instanced draw of quads, each pulling `{center, radius, lift; black, king (none,
  crown, or stack), selected, opacity; must capture (pulsing or still), side to move}`
  from a storage buffer and drawing its shadows, side, face, light, crown or second disc,
  and rings in the fragment shader, blended premultiplied, top row first so a lower
  piece covers the shadow above it. The crown is a signed-distance polygon in that shader. The panel's line icons are
  to be drawn the same way, as distances to their strokes' segments and arcs, rather than
  baked into the font atlas: crisp at any size, no texture.
- **3D board** (prototyped in `poc/3d/`): the board in perspective, 52.5° down with a 31°
  field of view, its image fitted into a rectangle of the screen by a scale and a shift
  in clip space, so the perspective is the native one at every size. Its bounds are
  about 1.46 times as wide as tall, the far edge 69% of the near one. Natively
  (`src/board/view3d.goose`, plain math in `board/` as the code layout says): the camera
  and its fit (`view3d::View`), a tap turned into a square by a ray through the
  perspective onto the field, a piece's top or side picking that piece's square, and each
  frame's instances filled from the flat board's draw lists (`board::fill`), so the two
  views follow one state and one animation. The world follows the flat layout the board
  package plays on, so a turned board turns the 3D one. **The game screen round it**
  (`panel::corners_in`, `prototypes/game3d.html`'s `corners`, chosen 2026-11-09): in
  landscape the two panels are short glass panels in the top corners, 232 × 352 dp (192
  wide on a phone, under 600 dp), on the left back on its own tile over a panel of
  settings and start over (the column's bounds the panel's were, so the board's fit is
  unchanged), the turn or the clocks and undo move on the right; the board as large as clears them by 12 dp, its
  near edge on the bottom margin (898 × 616 dp on the tablet). The flat game screen takes
  the same panels (task 054, "Game screen"); `Layout.corners` marks them, flat or 3D. In portrait the flat
  board's order, the bar, the board as wide as the screen less the margins, the camera
  buttons, the play; its camera 65° down (`panel::PITCH_PORTRAIT`, the user, 2026-11-09),
  which fills more of the height (752 × 604 dp on the tablet).
  **The camera buttons** (the user, 2026-11-09; `prototypes/game3d.html`'s placement `a`):
  round floating buttons at the right edge, a column under the play panel in landscape
  (a row on a phone, where a column runs past the bottom margin) and above it in
  portrait (a row where a column would shrink the board): a shaded disc with a hairline
  and a line icon at the 2.4-unit stroke, no panel (`gui::floating`, the UI shader's
  `FLOAT` quad and its icons). A 56 dp touch area and a 44 dp disc on a tablet (its
  shorter side 600 dp or more), 48/40 on a phone in landscape, 52/42 in portrait. The
  board at rest clears them as it clears the panels. **View** cycles the rest angle and
  the top view (74°), eased over 0.6 s; off the rest angle (a showcase drag left it so) a
  small gold dot sits on it and its tap eases back to rest first. **Zoom** (landscape
  only) frames the playing field, every square and the pieces' tops, as large as fits
  the area clear of the panels and the buttons by a quarter gap (about 1.15 times the
  board's scale; in the top view too), eased 0.6 s. **Showcase** toggles a mode, lit
  while on, in which a drag anywhere off the UI turns the board ±35° and tips it 35° to
  80° down instead of moving pieces; off keeps the angle, and play goes on through it.
  **Against a friend** the board turns 180° after each move to face the side to move
  (0.7 s, eased, once the move has shown), the light keeping its place on screen (the
  renderer turns it with the board, `render3d::turn_light`, and draws the shadow map
  again) and the board shrinking a little mid-turn to clear the panels; against the
  computer it stays turned to the child. A new game or a hot-seat turn puts the showcase's
  angle back. The camera is plain data with its eases in `board/rig.goose` (`rig::Rig`);
  `panel::aim` fits it each frame (at rest, the rest view as it is), while the flat square
  the board package plays on stays the rest view's, and picking goes through whatever
  camera is drawn. A puzzle has the same buttons.
  **Every screen with a board** shows it when it is chosen: home's board and settings'
  preview are fitted, as large as they fit, into the room each screen gives them (home:
  across its stage less 40 dp each side, 24 in portrait, as tall as the flat board below
  the chip's and the way out's row, 760 × 521 dp on the tablet; settings: 94% of the page
  beside the choices), with the flat square the board package plays on in the middle of
  the bounds (`view3d::square`). **On home** a drag that starts on the board (inside its
  outline on screen, `view3d::on_board`, off the UI) moves the showcase's camera, its rate
  and range (`rig::drive`: 0.3° a dp, ±35° round, 35° to 80° down), no button needed; the
  board stays in the middle of its room, shrinking where its bounds at that angle would
  leave it (to about 64% at the top end), the light fixed to the world as in the showcase.
  Let go, the angle stays while home is open; leaving home eases it back to rest over the
  transition (`shell::home_view`, `test/shell/home_turn`). A puzzle takes the game's corners layout, next the shorter
  tile in a corner panel, turned so the side to move plays from the bottom, its taps and
  drags through the perspective as the game's (`board::touch`). **The win** dims the board
  and the pieces but the winning one (its seed `view3d::SEED_LIT` more, the dim in the
  frame's `screen.z`), lights the squares the glow passes and rings the pieces it lifts;
  its card is centered in the 3D board's bounds on screen and keeps clear of the winning
  piece's top where the perspective shows it (`game::card_area`, `game::winning_spot`).
  **Drawn** by `src/render3d/` (the prototype's renderer, shared with `poc/3d/`) from
  `src/app/draw3d.goose`: the shadow map only when the pieces move, and the pieces'
  occlusion of the field (each piece a cylinder over the 3 × 3 squares round it) into a
  512² map only where squares changed, a moving piece about 3 × 3 squares of it (task
  059: a texel a field pixel reads instead of the loop; the dropped bake above drew
  shadow and occlusion with every shadow map); a crowned king's crown read from its
  signed distance drawn once at setup into a 256² map (`shaders::CROWN_FRAG`, task 059:
  evaluated three times a pixel for its slope, it was a third of a frame with 16 kings
  on the Pixel 7a); one 4× multisampled
  forward pass (the board's shadow, the lit board and pieces, the fading ones blended
  after, the field's marks that hold still added) into a kept image the screen's size,
  clear but for the board, drawn only when the 3D board's scene changed
  (`view3d::changes`); each drawn frame lays the image over the backdrop (the renderer's
  blurred and graded photograph behind the game and a puzzle, the app's sharp one behind
  home and settings; or the plain fade, dimmed to 0.8 behind the game), under the UI.
  The renderer's backdrop is kept too, drawn at full opacity into its own image the
  screen's size when its size, photograph, look, or fade changed, and laid with a fetch
  a pixel (`render3d::keep_backdrop`, task 059: its grade each frame was 7% of the
  Pixel 7a's GPU cycles); between a change and the next 3D draw it is graded live.
  The board's ambient light (nine spherical harmonics) comes from the blurred
  photograph; with the plain fade, from the fade painted 64 texels square on the CPU,
  scaled so its brightness is the dim ambient a theme without a photograph had (the
  look the Galaxy A33's build without photographs showed, which the plain background
  comes from): the fade tints the board's shade by season, a fade's own light being far
  too dark to light it (`render3d::fade_harmonics`). Switching between the photograph
  and the fade takes only the theme's photograph steps again, not its bake. **Getting
  ready** (`draw3d::prepare`, task 042) takes a step a frame: the setup, the theme's 28
  steps (the bake in bands, the photograph), the pass's 11 pipelines; meanwhile a still
  mark shows in the board's place, and once ready the board fades in over 0.3 s. A new
  season or board size takes the theme's steps again with the old image still shown:
  while they run it eases over 0.2 s towards grey and dimmer (saturation 0.15 of its own,
  brightness 0.8, the user's plan, 2026-11-09), so the old board on the new photograph
  reads as changing, and the new theme's first image eases back to full color from there
  over 0.3 s. It costs a uniform of the shader that lays the image on screen
  (`shaders::SHOW_FRAG`: a dot product and a mix), never a drawing of the board again;
  the frames go on only while it eases. The photograph and the fade switched alone
  aren't greyed (four short steps). The marks that pulse (a must-capture ring, a wrong
  move's flash, a hint's ring) stay out of the image: each frame draws them over it in
  one additive quad from their phases, a uniform (`render3d::marks_over`), tested against
  a 1x depth of the board the pass keeps with the image while marks pulse (a 16-bit
  target the screen's size, made the first time), so a pulse runs the 3D pass once, not
  on every frame. The marks are the flat board's: the last move tinted, targets' dots, stops' rings,
  the must-capture ring pulsing, a capture's count as pips, a wrong move's red flash, the selected piece's glow
  ring, the glow ring tight round a hint's piece or a win's, a win's lit squares
  (`view3d::Scene.lit`). A captured piece and a wrong move's ghost fade, drawn blended
  one by one after the opaque pieces, casting no shadow. The four seasons have looks as
  data (`src/render3d/looks.goose`): autumn's maple and walnut in cherry, winter's stone,
  spring's pale birch with sage-stained squares in a green-stained frame, and summer's
  peach and dusky rose under a satin lacquer in a red-brown frame, from the theme table.
  Spring's default is ivory stone with a carved vine band on the frame and jade dark
  squares (`looks::elven`, `--spring 1`, chosen on the tablet 2026-11-09); the Baltic
  carved oak is `--spring 2`, the birch `--spring 0`. Summer keeps its default wood look.
  **The wood and the stone are baked** once into 2048² maps (the plan and the frame map,
  with mips; `shaders::BAKE_FRAG`) at getting ready and on a theme change, never a frame.
  The wood is growth rings round a wandering pith axis with pores along the fibres and a
  fibre relief (Liu, Dong, Hašan and Marschner, 2016), colored by Beer's law, under a
  finish per look (`looks::Finish`: varnish, sanding, pickling, caulking); winter's
  frame is a black marble, contours of a warped ramp with fine cracks (`looks::MARBLE`,
  2). `--wood N`, `--marble N` (0 the slate), and `--summer N` show the other models and
  variants kept beside the defaults (task 039; the user settled on the defaults,
  2026-11-09). Warm, the bake takes 37 ms on the M1 Pro and 0.27 to 0.30 s on the
  tablet; its pipeline's first compile there about 1 s.
- **States**, in the theme's glow color: the selected piece lifts by 0.8% of the board
  and grows to 1.05 with a glow ring a little out from it (at 1.13 of the radius); with move hints on, a legal target is a glowing
  dot 30% of a square and a capture's stop on the way is a ring. With hints on mistakes
  only (the default, `docs/product.md`), there are no dots: a wrong move flashes a red
  ring on its square twice (0.6 s each), and the piece that must capture pulses; the
piece stays selected. A tap or a drop on an empty square that isn't a move is wrong, as
is touching a piece that can't move because another must capture. Every piece with a
legal capture pulses, never one of several. Under the majority rule a piece that could
take, but fewer than another, can't move: touching it is wrong, and the pieces the legal
captures take pulse too, beside the piece that takes them, so a child sees the other piece
takes more (`board::outnumbered`). The pulse belongs to the position the mistake was made
in and ends once a move is played: it used to run on through the move and ring the next
side's capturers, so after a child's capture on the turned board the computer's man
beside the child's pieces pulsed red as if it were the child's to move (reported
2026-11-09, two pieces each taking one; the rings, taps, and moves agree under the turn,
`test/board/several`). A piece that must capture shows how many pieces its
capture takes, at most (`board::takes`, `Piece.ring.z`), when `board::counting`: with
move hints always; on mistakes only from a mistake while a capture is due (`mistake`
sets `Board.counted`) to the next right move or jump (`start_move`, `kept`), so a
second mistake partway through shows what is left (2026-11-09, `test/game/pips`; it
showed whatever the hints before, which gave the capture away). One pip per piece on its ring, 28° apart and centred
over the top, light with a red rim (22% and 30% of the radius, on the ring at 1.24
radii), and past five one larger red pip with the number (`prototypes/game.html?count=a`;
take b, a badge with the number, needs a child who reads digits; the pips are counted).
It counts pieces, not stops or the squares a flying king could land on; under the
majority rule every piece that takes the most shows it, and in Russian each piece its own
most. Partway through a capture only the piece making it shows what is left; the
computer's pieces on its turn show none (`Board.quiet`), and a puzzle none. The 3D
board shows the same pips (`view3d::Scene.lit`'s z, the square's count), drawn on the
field by the still marks' pass (`shaders::MARKS_FRAG`'s `count_pips`), 22° apart at 0.6
of a square round the piece on the side toward the eye, as the piece hides its far side;
painted over the field (that pass blends premultiplied, the other marks adding with alpha
0), as added light washed out on a light square. They change only with the count, so they
cost a draw of the board then and nothing per frame. Until 2026-11-09 the 3D board drew
no pips: its scene never read `ring.z`. Before
(reported 2026-11-09, a child's lone king on the turned board with a capture of four),
nothing said how far a capture went. A capture of many jumps is tapped or dropped by its
last square, when one capture alone goes there, or stop by stop (`board::follow`): a tap
or a drop on the next stop of the selected piece's captures leaves the piece waiting
there, lifted and selected, the pieces it jumped still on the board as the rules leave
them until the capture ends, the stops behind it ringed whatever the hints, and narrows
the targets shown to the ways through it. The rest is never played by itself, in a game
as in a puzzle: each next jump is the child's, by tap or by drag from the stop, and the
move, once its last stop is reached, is shown from there. A last square several captures
reach waits for the stops. Until 2026-11-09 a game played a capture once only one went
on from the stops made, so a child whose first jump played the whole of it never learned
the way. Before that (reported 2026-11-09, International, a black man's capture over a
far-row square it only passes, the board turned), the piece went back to its square with
the stop ringed, and picked up again it forgot the stop: dropped, such a capture was made
only by its last square. In a game, a wrong square for a piece that must capture is a
miss that leaves a waiting piece on its stop (`board::missed`): the first in a turn
pulses the pieces its captures have still to take, so a far-row square that a shorter
capture would crown on, which the majority rule forbids, shows what to take instead
(`test/board/stuck`); the second lights the next stops with the target's dot, pulsing
as the hint's ring does for two cycles and then lit, and so on to the capture's end
(`test/board/count`). The 3D board lights the same stops with its target's dot
(`view3d::Scene.lit`'s w): while they pulse they are drawn over the kept image at
`Scene.next`, a uniform of `render3d::marks_over`, and once lit by the still marks' pass,
so a pulse costs the marks' quad a frame and a draw of the board at its start and end.
Until 2026-11-09 the 3D board never showed them (`test/game/pips`). With move hints, the next stops of a waiting piece show from the
first jump. Undo move while a piece waits takes the capture back to its start, the
piece on its square, and takes back no move (`board::unwind`). A puzzle
(`Board.by_hand`, 2026-11-08) shows none of these: a wrong square there forgets the
stops, and its own hint is a glow after two misses. A piece that must
capture pulses a red ring
  `#ff5a4a` with a soft red glow every 1.4 s, in every theme. The last move's squares are
  tinted with the glow color at 16%.

## Fonts

**Libertinus Sans** (SIL OFL 1.1), the maintained fork of Linux Biolinum: a humanist sans
with flared strokes in the style of Optima, the face of the reference the user liked
(arXiv 2611.07289), with a regular and a bold. Tenor Sans, Belleza, and Marcellus were
compared with it in Estonian text; all four have õ ä ö ü š ž. Tenor Sans, which the
proof of concept uses (`assets/fonts/`), is the runner-up: clean and wide, but one weight
only. Marcellus has small serifs, further from Optima. The atlas bakes Latin-1, Latin
Extended-A, and general punctuation. If titles want more character, Tenor Sans could set
them and Libertinus the rest; one face is the default, for one atlas.

Natively (`src/app/text.goose`) the regular weight (`assets/fonts/`, from the v7.051
release) is baked by `ui`'s atlas once per size the UI uses, at the screen's pixel size,
so a glyph is drawn a texel to a pixel: 64 dp for the wordmark, 30 for labels, 17 for
notes. The atlas sizes a font by its ascent less its descent, 1.14 em for Libertinus,
so each is baked at 1.14 times its size in ems to match the prototypes' CSS. The glyphs'
boxes and atlas places are copied into `gui`'s fixed tables, which lay text out headless,
the image into a texture, and the atlas is then destroyed. A glyph is one more quad kind
in the UI's one draw. Baked again only when the layout's scale changes.

The texture holds only what is drawn:

- **The title and the figures hold only their characters** (`shell::face_chars`): the
  64 dp title the app's name in every language in `strings/` (home's wordmark), the 36
  dp figures the clock's digits and colon, and both '?', the glyph a missing character
  is drawn as. Those two faces were 71% of the atlas's area with every glyph. A
  translation's name is taken from its file at the bake, so nothing else changes for
  a new language; `test/shell/faces` fails if a string drawn in either face has a
  character outside its set. The other four faces keep every glyph, as any string may
  use them.
- **One byte a texel, only the rows used.** `ui` bakes RGBA (white, coverage in alpha)
  with its height rounded up to a power of two ([findings](../goose-findings.md)); the
  app moves the alpha to the front of the same buffer and uploads the rows down to the
  lowest glyph and one empty row as an R8 texture, its v remapped from whole rows, and
  the UI shader reads `.r`. The text is drawn byte for byte as from the whole RGBA atlas.

At 1024 texels wide, the texture's size by scale:

| Screen (scale) | Before: every glyph, RGBA, power of two | R8, the rows used |
| --- | --- | --- |
| A 720 × 1280 phone at low density (0.9) | 1024 rows, 4 MiB | 261 rows, 0.25 MiB |
| The Galaxy tablet; a 720 × 1280 phone at xhdpi (1.5) | 2048 rows, 8 MiB | 630 rows, 0.62 MiB |
| The Pixel 7a (1.97) | 4096 rows, 16 MiB | 1023 rows, 1.0 MiB |
| 2880 × 1920 (2.4) | 8192 rows, 32 MiB | 1482 rows, 1.45 MiB |

Under 2 MiB at every size, so it lives in SDL's shared small blocks ([GPU
memory](#gpu-memory)), and its upload's transfer buffer is as small. Nuklear's own bake
buffers are still power-of-two RGBA, but of the smaller atlas, and freed with it.

## GPU memory

On Android all of the app's GPU memory comes from SDL_GPU's Vulkan allocator, as patched
by `patches/SDL/0003-large-allocations-at-their-size.patch`
([findings](../goose-findings.md)). The Mac uses Metal, whose allocation SDL leaves to
the driver. How the patched allocator works:

- **Up to 2 MiB** (`SMALL_ALLOCATION_THRESHOLD`, by the driver's memory requirements, not
  the pixels): shared 16 MiB blocks, as upstream. The storage buffers, the text atlas,
  the photograph as ASTC, the blurred copies, the thumbnails, and SDL's uniform buffers
  live there, one block on the tablet.
  A block that empties goes back to the driver.
- **Over 2 MiB**: a `VkDeviceMemory` of the resource's own size, nothing else ever placed
  in it, given back to the driver at a submit soon after the resource is released.
  Upstream rounds these up to 64 MiB blocks that later large resources share: on the
  tablet the screen (9.6 MiB) and the photograph (16.3) would take a whole 64 MiB block.
- **Transfer buffers** are their own exact allocations at any size, upstream too. Each
  drawn frame allocates and frees three small ones (gfx's `update_buffer`: 32 KB, 3 KB,
  256 B); a persistent upload buffer in gfx would end that.
- **When:** on the tablet large allocations happen at launch and on a resize or
  rotation (the new screen, then the old one freed); never in a frame that only draws.
  The photograph as ASTC (1.87 MB) and its transfer are small; where the JPEG is decoded
  instead, a season change makes the new photograph (16 MiB) and its transfer.
- **Short-lived small resources** wait for the GPU: a released texture is freed only
  after the submit that used it completes, so making several in a row (settings'
  thumbnails, four photographs) or a new scene beside the old one fills the shared block
  and opens another, which a later resident resource can keep alive. The app calls
  `gfx::flush()` between them (on the tablet GL mtrack at home 60.7 → 36.4 MB, after
  three season changes 57.3 → 40.9).
- **Exact, not rounded to 4 or 8 MiB** (2026-11-08): the count of allocations is
  the same either way, one per large resource, and rounding wastes half a step each on
  average (about 10 or 22 MiB on the tablet). It would pay only if a freed block were
  kept and taken by a later resource of nearly its size, but SDL makes the new screen or
  photograph before it releases the old one, so the old block is still in use when the
  new one wants it; and keeping freed blocks for reuse is how a large block stays alive
  for a small tenant, the 64 MiB blocks' trouble. A smaller fixed block shared as
  upstream does (16 or 32 MiB) still needs its own for anything larger (the largest
  tablet's screen, a 3D MSAA target) and stays alive while any tenant lives; SDL has no
  `VK_KHR_dedicated_allocation` plumbing, and an exact plain allocation already gives
  the memory back.

What the memory is, on the tablet (1920 × 1200) at home: GL mtrack about 36 MB (the
screen, 9.6 MiB, in its own allocation; one shared 16 MiB block with everything else;
about 10 MB of the driver's pipelines and pools), EGL mtrack about 55 to 60 MB, and a
native heap of about 27 MB. Two parts are out of the app's reach:

- **The swapchain is the driver's minimum.** SDL asks for 2 images, but the Mali-G615's
  `minImageCount` is 6 (about seven screen-sized images on the Pixel 7a), so it is 58 MiB
  at 1920 × 1200, 21 at 720 × 1280, and 127 at 2880 × 1920: most of what is left at
  every size. Drawing straight into the swapchain, dropping gfx's screen copy, would save
  only the screen's 9.6 MiB for a large gfx patch; not done.
- **The driver's own** about 10 MB.

On the CPU side, Android's malloc (Scudo) keeps freed pages resident: small blocks' until
Android purges them as the app goes to the background, freed large blocks (100 KB to
1 MB) in a secondary cache that purge leaves. The launch frees about 16 MB of both, so
the app calls `mallopt(M_PURGE_ALL, 0)` once, in the first idle frame after the launch
(`src/app/memory.c`, 2 ms; [Frames and battery](#frames-and-battery)): native heap at home
42.6 → 26.7 MB. Goose packs structs, so large tables carry no padding. The computer's
worker's tables (about 5 MB, [ai](ai.md)) take memory only once it first plays; halving
them would save about 3 MB, not worth checking what it costs in strength.

What to watch when adding large resources (the 3D board: an MSAA target, a
depth target, a shadow map, albedo, normal, and roughness atlases with mips):

- Each one over 2 MiB costs one `vkAllocateMemory` when made and one `vkFreeMemory` after
  it is released. Make and release them at load, a season change, or a resize, never
  per frame. Vulkan guarantees at least 4096 live allocations
  (`maxMemoryAllocationCount`); a dozen large resources are far from it.
- A large target SDL cycles (cleared or written with `cycle` while the GPU still reads
  it) keeps a second or third copy for good, each its own allocation, as the screen did
  before gfx stopped cycling it. Clear without cycling where the GPU can wait instead.
  A target cleared by its first pass right after it is made is cycled too: the 3D
  board's four baked surfaces each kept a second copy, 85 MB on the Pixel 7a, until the
  bake stopped clearing (it writes every texel anyway; 2026-11-09).
- A pipeline is made once per set of target formats it draws into, each a full compile
  of its shaders: on the Pixel 7a the 3D bake's takes about 0.4 s, so the plan's normal
  map stays RGBA8 like the frame's (RG8 would save 11 MB and cost a second compile).
- Uploading a large buffer each frame through a new transfer buffer would allocate and
  free that much each frame; keep one transfer buffer and reuse it.
- Graphics memory now follows the resources' bytes: GL mtrack is their sum, plus the
  16 MiB small block, plus about 10 MB that is the driver's own; EGL mtrack is the
  swapchain. A 4× MSAA target costs four times the screen's bytes, since SDL doesn't use
  Mali's lazily allocated (tile-only) memory for transient targets.
  `patches/goose_gfx/0005-msaa-resolve-without-store.patch` keeps the samples and the
  multisampled depth from being written out each frame, which saves bandwidth, not
  memory ([findings](../goose-findings.md)).

## The 3D board on devices

Measured with the app's `--bench 300` ([development](../development.md#time-the-3d-board)),
idle with `scripts/idle_cpu.sh`, memory with `dumpsys meminfo` at rest (2026-11-09; the
three Android devices again 2026-11-10 with `scripts/device_perf.sh`, the release built
from 1aaf406; the iPhone with `scripts/ios_perf.py`, its development build from 1c25f33, the
same app code with `--rest`, which counts its own CPU time and footprint). The tablet
again from 4d50eb2's release, after task 059 (its 3D memory 30 MB more: the kept
backdrop and UI layers, 9 MB each, and the occlusion and crown maps).

The release at rest, idle 20 to 30 s:

| Device | Board | Idle program thread | GL mtrack | EGL mtrack | Total PSS |
| --- | --- | --- | --- | --- | --- |
| Galaxy Tab A11+, 1920 × 1200 | 2D, a game | 0.04 to 0.08% | 37 MB | 55 to 60 MB | 133 to 141 MB |
| Galaxy Tab A11+ | 3D, a game | 0.28 to 0.32% | 210 MB | 32 MB | 295 MB |
| Pixel 7a, 2400 × 1080 | 2D, a game | 0.08% | 45 MB | 73 MB | 159 MB |
| Pixel 7a | 3D, a game | 0.04% | 215 MB | 73 MB | 324 MB |
| Galaxy A33 5G, 2400 × 1080 | 2D, a game | 0.04% | 35 MB | 43 MB | 116 MB |
| Galaxy A33 5G | 3D, a game | 0.04% | 197 MB | 29 MB | 275 MB |
| iPhone 13 mini, 2340 × 1080 | 2D, a game | 0.08% | | | 59 MB footprint |
| iPhone 13 mini | 3D, a game | 0.08% | | | 204 MB footprint |

- **The tablet's frame** while the board moves (the first baseline, 1920 × 1200 at 90 Hz):
  the forward pass alone 10.9 ms at 1×, the whole budget; MSAA 4× adds 3.2 ms (6.3 ms
  and 72 MB more without `patches/goose_gfx/0005`, which keeps the samples and the depth
  from being stored); the shadow map 2 ms on the frames that draw it; the CPU's part
  about 0.4 ms. It renders as the Mac does. After task 042's cuts (2026-11-10): the
  frame with the shadow map, as while a piece moves, 10.5 ms waited, the pass alone
  (the camera turning) 9.9, presented 12.8 ms frame to frame; 90 Hz kept. The release, 2026-11-10, 1000 frames: waited P50
  10.6 / P99 12.7 ms, the pass alone 10.0; the compositor counts 17% of the frames on
  screen for two refreshes, 78 fps on average, 45 at the 1% low (task 055). The flat board's
  whole frame (`bench2d`) 10.2 ms waited, and no frame dropped (`scripts/device_perf.sh`).
  After task 059's four changes (2026-11-10, debuggable test builds of fab1757 and c7d23bf
  beside the app, two runs each): waited P50 10.6 to 10.9 → 9.2 to 9.4 / P99 12.8 to 12.9
  → 10.9 to 11.2 ms, the pass alone 10.0 to 10.3 → 9.0 to 9.1, presented 12.9 → 11.0 ms
  frame to frame; the compositor counts 90 fps at the 1% low and no frame dropped (17%
  before). With 16 crowned kings 12.2 → 9.0 ms waited, 31% dropped → none. The release
  from 4d50eb2, 1000 frames: waited P50 9.22 / P99 12.13 ms, the pass alone 8.96, 90 fps
  on average and at the 1% low, none dropped; the flat board's 9.39 ms waited, none dropped. The GPU's clock
  stays near its top (1047 MHz) in both, so the frame times show the work. Baking the
  field's shadow and occlusion into a map with the shadow map was dropped (the user,
  2026-11-09): it took the camera's turn to 8.4 ms but every frame that draws the
  shadow map to 11.5.
- **The Pixel 7a** (60 Hz): the pass 14.0 ms waited for International, 13.0 for Russian,
  presented every 16.6 ms; 2026-11-10, 1000 frames: waited P50 13.5 / P99 16.0 ms, and the
  compositor counts 1 of 995 frames on screen for two refreshes (the flat board's none, its
  frame 11.8 ms waited); the theme applied at launch in 0.76 s (the bake, its
  pipeline made), the first frame 0.31 s.
- **The Galaxy A33** (90 Hz, thermal status 3): the pass 36 ms waited at first, about
  28 fps while the board moves; after the frame cost's first cuts the pass 19.3 ms and
  about 39 fps (25.7 ms frame to frame); the theme applied in 1.66 s, the first frame 0.35 s. Its Mali-G68 lost the device
  on a texture's mip level 0 pixels high ([findings](../goose-findings.md)); the bake's
  mips now end at the shorter side's 1 pixel (`render3d::baked`). 2026-11-10, 1000
  frames: the 3D frame waited P50 23.2 / P99 26.0 ms (the pass alone 17.1), on screen for
  two refreshes every other frame, a steady 60 fps; the flat board's 15.6 ms waited, and
  no frame dropped.
- **60 Hz for a slow 3D board** (task 056): on Android, once 60 frames of the ready 3D
  board average over 1.25 refreshes of a display faster than 60 Hz, the app asks for 60
  Hz on its surface (`ANativeWindow_setFrameRate`, `src/app/display.c`) whenever the 3D
  board draws, and for the display's own rate otherwise: 60 frames on a 90 Hz display
  show two refreshes and one in turn. A device that holds its display's rate keeps it.
  The Galaxy A33 ignores it: its "High" motion smoothness holds 90 Hz whatever an app asks.
  The tablet's frames fit its 90 Hz since task 059 (they averaged about 1.15 refreshes
  before, and it kept 90, the user's choice over an even 60); the Pixel 7a's display is at 60 already.
- **Where the moving 3D frame goes** (task 059, Streamline on the Pixel 7a, after its
  four changes): GPU active 7.01M → 4.70M cycles a frame, fragment-bound (the tiler 3%
  of the GPU's time), not bandwidth-bound (0.6 GB/s), little overdraw. The lit fragment
  shader still holds 64 registers (half occupancy on the G615), and the UI's
  uber-shader 64 for every UI pixel: its live cost is 1.45M cycles a frame, 24%, paid
  only when the UI changes now that it is kept (`widgets::prepare`), and the backdrop's
  grade 0.43M when it changes. Ranked and not yet tried: the UI's shader made fast by
  itself, measured with the caches off (the user prefers fast work to cached slow work);
  the pieces' shadows on the field analytic (a disc's stadium along the light) in place
  of the shadow map's pass and its 9 taps on every lit pixel; fp16 for colors, the
  harmonics, the tonemap, and the varyings (no shader uses 16-bit yet); MSAA 4× read
  again at 2,208 triangles a piece; a lower render scale for the 3D pass, last.
- **Open:** at rest the tablet's 3D board spends about 2.7 ms CPU a wakeup against the
  flat board's 0.3, outside the app's own work, as the Mac shows no draw at rest.

### The release's frames

The release in a game (Russian, wood, the start), on the 2D and the 3D board, 2026-11-10:
idle 25 s at rest, and while it draws every frame (`--bench 1000`). The frames as the
screen showed them, counted by Android's compositor: frames per second on average and at
the 1% low (the slowest 1% of frames), and how long a frame stayed on screen, the median
and the 99th percentile, against the display's 11.1 ms at 90 Hz or 16.7 ms at 60 Hz
([development](../development.md#time-the-3d-board)).

| Device | Board | Idle CPU (one core) | Memory (PSS) | FPS (avg / 1% low) | Frame time (P50 / P99) |
| --- | --- | --- | --- | --- | --- |
| Galaxy Tab A11+, 1920 × 1200, 90 Hz | 2D | 0.08% | 137 MB | 90 / 90 | 11.1 / 11.1 ms |
| Galaxy Tab A11+ | 3D | 0.32% | 295 MB | 90 / 90 | 11.1 / 11.1 ms |
| Pixel 7a, 2400 × 1080, 60 Hz | 2D | 0.08% | 159 MB | 60 / 60 | 16.7 / 16.7 ms |
| Pixel 7a | 3D | 0.04% | 324 MB | 60 / 60 | 16.7 / 16.7 ms |
| Galaxy A33 5G, 2400 × 1080, 90 Hz | 2D | 0.04% | 116 MB | 90 / 90 | 11.1 / 11.1 ms |
| Galaxy A33 5G | 3D | 0.04% | 275 MB | 60 / 45 | 22.2 / 22.2 ms |
| iPhone 13 mini, 2340 × 1080, 60 Hz | 2D | 0.08% | 59 MB | 60 / 60 | 16.7 / 16.7 ms |
| iPhone 13 mini | 3D | 0.08% | 204 MB | 60 / 60 | 16.7 / 16.7 ms |
| Windows PC, 2560 × 1440, 165 Hz | 2D | 0.00% | 258 MB | 165 / 165 | 6.1 / 6.1 ms |
| Windows PC | 3D | 0.12% | 477 MB | 165 / 165 | 6.1 / 6.1 ms |

The 2D board draws in one full-screen pass, the UI's glass over it, and holds the
display's rate. The 3D board's frame takes about 9.2 ms of GPU work on the tablet and
holds its 90 Hz; the Galaxy A33's 23 ms holds a steady 60 on its 90 Hz display. The 3D
board's extra memory is GPU memory: 180 to 230 MB against about 36 MB in 2D. On the
iPhone, Instruments' Animation Hitches counts the frames in place of Android's
compositor, and the app counts its own CPU time and memory footprint. On Windows, full
screen (`--size full`), PresentMon counts the frames the display showed (none dropped;
each flipped straight to the screen, 6 ms from present to display), and the app counts
its CPU time and its memory as the private bytes.

### When a frame reaches the screen

goose_gfx records a frame and its blit into the window's image in one command buffer,
committed once SDL has that image (`SDL_WaitAndAcquireGPUSwapchainTexture`, 2 frames in
flight). On Metal the whole command buffer then waits on the GPU until the image's
surface is free, the refresh after the commit, so a frame's GPU work must end about 7.5 ms
after a refresh at 120 Hz, not 8.3, and the compositor shares the GPU. On the M1 Pro
in a 2560 × 1600 px window the moving 3D board's frame takes 6.2 ms there (the 3D pass's
fragments 4.1 ms, the screen's pass 1.3), and about 1 frame in 200 is late.
Submitting the frame before the wait and the blit apart
was measured worse: the window has 3 surfaces and the compositor holds two, so the blit
waits for one and the frame after it for the blit.

## Frames and battery

The app draws only when something changed: input, a running animation, the AI's reply, or
a new screen size, safe area, or scale. Otherwise it draws nothing in that frame, and goose_gfx's `frame()`
then neither presents nor spins: it waits for the next event, up to a second. An idle
board costs about one wakeup a second and no GPU work. On Android `DraughtsActivity`
also keeps SDL's Java from listening to the accelerometer at 50 Hz, which nothing here
uses and which woke the activity's thread 52 times a second
([findings](../goose-findings.md)). The loop is the same on every platform:

```goose
while gfx::frame() {
    // read input, advance animations; set dirty if anything changed
    if dirty || animating { draw(); dirty = false; }
}
```

This is `patches/goose_gfx/0002-draw-on-demand.patch` ([findings](../goose-findings.md)),
applied in every build: `scripts/android.py`, `ios.py`, `mac.py`, and `windows.py` each
build goose_gfx from its patched sources. The release's own gfx (a plain `goose build`)
presents every frame at the display's rate. The patched `frame()`:

- presents only if something used the GPU since the last call, or the window needs the
  screen again (exposed, restored, back in the foreground, resized);
- after a frame with nothing drawn, waits in `SDL_WaitEventTimeout` for up to 1 s before
  reading events, so input wakes it at once and timers still run once a second;
- tries again for up to 8 frames when the window has no image to show, as on the first
  frames after Android recreates the surface on resume;
- leaves the wait out of `delta_time()`, so the first animation frame after idle doesn't
  jump.
- on Android, turns off SDL's poll sentinel, without which SDL's wait spins instead of
  blocking there;
- on iOS, waits in the main run loop itself (`CFRunLoopRunInMode`), as UIKit's SDL has no
  real wait and polls every millisecond; an event pushed from another thread (the wake
  timer's) signals a run loop source of gfx's own, which ends the wait
  (`patches/goose_gfx/0007-wait-in-the-ios-run-loop.patch`). The Mac's and Windows' SDL
  block in their system's event wait and wake it on a push themselves.

At rest, the board drawn and nothing changing, over 25 s (`--rest 25`, 2026-11-10):

| Where | Process CPU | `frame()` returns, draws |
| --- | --- | --- |
| Android, the Galaxy Tab A11+ | 0.04 to 0.3% of a core (`scripts/idle_cpu.sh`) | about 1 a second, none |
| iPhone 13 mini, home | 0.09% | 26, none |
| iPhone 13 mini, flat board, a game | 0.08% | 26, none |
| iPhone 13 mini, 3D board, a game | 0.08% | 26, none |
| iPhone 13 mini, a clock running | 0.52% | 51, 26 |
| Mac (M-series), home | 0.03% (8.2% with the release's gfx, presenting at 120 Hz) | 27, none |
| Mac, a clock running | 0.17% | 51, 26 |
| Windows (Ryzen 7 5800X3D, RTX 4090), home | 0.06% | 27, none |
| Windows, full screen, flat board, a game | 0.18% | 27, none |
| Windows, full screen, 3D board, a game | 0.06% | 27, none |
| Windows, a clock running (10 s) | 0.16% | 22, 11 |

A running clock costs a frame and its present each second, the timer's wake and the
idle wait's end. With the release's gfx the Mac's footprint was 414 MB, with the
patched one 321 MB, which also samples the photographs as ASTC instead of decoded JPEGs.
On Windows, full screen at 2560 × 1440, the private bytes are 253 MB on the flat board
and 476 MB on the 3D one.

The 3D board's camera (the view, the zoom, the showcase's way back, a hot-seat turn) is an
animation like a move: the 3D pass runs on each of its frames, about 36 for a 0.6 s ease
at 60 Hz, and on none once it has settled (`test/game/camera`); a showcase drag, and a drag
on home's board, draws only on the frames the finger moves. A pulse, a flash, or a hint's ring is not: while one runs
each frame copies the kept image and adds the marks over it from their phases, and the 3D
pass runs only where it starts and ends (`view3d::changes`' MARKS, `test/board/scene3d`;
"Board and pieces").

The hint's answer comes from the worker with no animation waiting on it: while the ask is
open the loop sets its wake timer 20 ms ahead (`HINT_POLL`) and looks, drawing nothing;
the answer marks the frame and the one after it to be drawn (`think::frame`). The
lookout's traps come the same way. The lookout's marks are still, so they add no frames.

An animation's last frame is not the resting state: the frame after a move or a pulse
ends is drawn too (`board::update` reports it), or the board would keep the move's last
in-between frame without its marks.

A screen declares its tiles before the board takes the pointer, so a tile whose look
follows the board is a frame behind it. When the board's input changes such a look, the
frame after is drawn too (`gui::Gui.acted`, as after a click): a puzzle's next wakes when a
drop leaves a piece waiting partway through a capture, and a drop is a finger's last
event, after which nothing would be drawn (seen on the Pixel 7a, 2026-11-08).

A running clock must show its next second on time, which the wait doesn't: after a drawn
frame the next wait ends a second and a frame later, so the clock was drawn 6 ms later
each second, up to a second late, and skipped a second every two and a half minutes
(measured on the tablet, 2026-11-08). So while a clock runs the app sets an SDL timer for
when the time shown changes (`src/app/wake.c`), which pushes an event of the program's own
type and ends the wait; the second is then drawn within 5 ms. Every platform takes it
(on the Mac SDL's functions are looked up with dlsym, `src/app/platform.h`). A `--frames`
run, which counts frames rather than seconds, ends every wait at once with an event pushed
each frame (`draughts_wake_now`).

Work that finishes on another thread, such as the computer's reply, would be seen only
when the wait ends; so as the computer begins to think its piece on the panel pulses,
which keeps frames coming until the reply has come, and it is seen the next frame. A
longer think against the clock draws only the clock's seconds after the pulse: the
timer is also set for when the computer's move is due (`game::due`). Once its move has
landed nothing animates and the app draws nothing. While Android has the app paused, SDL blocks
the loop: it draws nothing and submits no GPU work. iOS doesn't block it, and ends an app
that submits GPU work in the background, so there the loop draws nothing while the app
hasn't focus, which it loses before it goes to the background, and draws the screen
again when focus returns.

Work too long for a frame stays off the frames that move. Settings' season thumbnails
make all four photographs, one after another with a wait for the GPU after each (where
the JPEGs are decoded, about 125 ms on the tablet and 55 ms on the Mac), so they load in
the first frame after the launch's first that draws nothing; that frame presents the
unchanged screen once more, and settings opening for the first time moves as smoothly as
later. Settings opened at launch load them before their first frame. That idle frame also gives back to
the system the memory malloc keeps for what the launch freed (`src/app/memory.c`, about 16
MB of native heap on the tablet, 2 ms). A settings change
the tap starting a transition made (the computer's play counting a game) is written once
the transition is over, since the write flushes to disk, 13 to 17 ms on the tablet.
