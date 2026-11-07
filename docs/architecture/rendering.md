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
- **3D later** reuses the game state and the storage buffer, with a camera and lit meshes
  in place of the 2D pieces.

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
  `test/gui/`), and `app/widgets.goose` draws it: each quad pulls `{rect, color, kind,
  radius, icon, pressed, dp, look}` from one storage buffer, and its fragment shader works
  it out as a signed-distance shape: glass with its shadow, a tile with its shadow (plain,
  primary, or a toggle on or off), a line icon as distances to its strokes' segments and
  arcs, a spark. `game/` is the game screen with no graphics, tested headless in
  `test/game/`: it declares the panel (`game/panel.goose`) and the celebration, does what
  their buttons ask, and hands the pointer to the board only when a press didn't land on
  the UI. Pieces shown on the UI (the side to move, the winner) are drawn after it by the
  piece pipeline from a second small storage buffer, so they look exactly like the
  board's.

Nuklear (`ui`) is only for developer tools, such as a puzzle editor, because restyling
its desktop widgets into the kid UI would fight it. If layout outgrows rect-cutting
(scrolling lists, wrapping text, menus like Snowtime's), we copy
[Clay](https://github.com/nicbarker/clay)'s model, a per-frame layout tree with
grow/fit/fixed sizing, rather than linking it. Its API is C macros, which Goose can't
call directly.

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

| | Autumn: wood | Winter: stone | Spring: birch | Summer: sea |
| --- | --- | --- | --- | --- |
| Light square | `#e2b070` | `#d8dee7` | `#e8e2d3` | `#c7d5c6` |
| Dark square | `#7a4626` | `#5a6777` | `#6b7f6a` | `#2e5546` |
| Frame | `#3b2112` | `#2a3442` | `#3d4a3c` | `#1d3a30` |
| Light piece | `#f0d4a4` | `#f3eee2` | `#f6f3e7` | `#f6f1e4` |
| Dark piece | `#4a2918` | `#2b3440` | `#3a4a3f` | `#b56a57` (terracotta) |
| Glow | `#ffd75a` | `#a7d0fb` | `#8fd4ff` | `#86e7d3` |
| Glass tint | `#2b1e18` at 66% | `#1e2f45` at 40% | `#1e2f45` at 40% | `#1e4a4a` at 40% |
| Glass copy dimmed to | 0.9 | 0.75 | 0.75 | 0.75 |
| Text | `#f8f3e6` | `#e6f4ff` | `#e6f4ff` | `#f4f8f2` |
| Page under the scene | `#1c1410` | `#0b1622` | `#101a14` | `#0d1c1c` |
| Square surface | wood grain | soft mottling | faint fibre | plain sheen |

Secondary text is the text color at 66%. The surfaces are faint, never busy: a few sines
and value noise in the board shader. Wood is fine irregular streaks along the board and
a broad soft figure, never a regular stripe, which reads as bands from afar, with each
square its own tone; stone a paper-like mottling; birch a hint of fibre across;
sea almost flat.

### Scene and glass

- **The scene** is a calm Estonian landscape for the season: autumn forest, winter
  spruces, spring birches, summer coast. Each is a photograph-like picture
  (`design/backgrounds/`, placeholders until task 014), shown as it is, cover-cropped to
  the screen by its long side, sharp behind the title menu, the puzzle picker, settings, and the 3D
  board.
- **Behind the 2D game the scene is blurred** (a 14 px blur at 1280 px wide, dimmed to
  0.8), as on the design boards, so the flat board reads cleanly. Natively
  (`app/scene.goose`) the decoded image is scaled down to 512 × 512 and blurred once on
  the GPU when the season is picked, two passes of a Gaussian of sigma 5.6 texels: since
  a square image is cover-cropped by the screen's long side, that is the same blur at
  every screen size and orientation, so a new screen size needs no new blur. The board
  pass samples it, a 1 MB texture. Tried and set aside
  on 2026-11-07: the sharp photograph (busy behind the board), a plain painted tabletop,
  and generated tabletop pictures with a crafted board (task 016).
- **The 3D board floats in front of the scene**, with a soft shadow under it: no room or
  table to model. A painted backdrop with a real table comes later only if this falls
  short (task 015).
- **Stored** as one JPEG per season, 2048 × 2048 at quality 85 (0.46 to 0.70 MB each),
  in `assets/backgrounds/<season>.jpg` and built into the program with `embed_file`, as
  the font is: nothing to package in the APK's assets, and the same path on the Mac and
  Android. goose_gfx's `load_texture` reads only PNG and BMP from a file (through SDL),
  so the program decodes the JPEG itself: stb_image, JPEG only, in the program's own C
  (a `c_sources` entry in its `.build` sidecar), from the embedded bytes to RGBA, then
  `gfx::texture2d` and `update_texture`. stb_image's NEON loops are switched on for ARM
  (`STBI_NEON`; on x86 it uses SSE2 by itself, elsewhere its plain C), and it decodes to
  four channels, the only case its NEON color conversion handles. A season is picked
  by a settings tile, which lights in the frame after the tap; the photograph loads in
  the frame after that, once the lit tile is on screen. No goose_gfx patch is needed
  ([findings](../goose-findings.md)). Only the current season is decoded, once: into
  the sharp texture behind home, 2048 × 2048 as stored (16 MB of graphics memory), and
  the 512 px copy that is blurred. The pixels' data-stack pages are given back with
  `trim_memory()` after loading. Until the
  images are checked in, `app/background.c` embeds the local masters with C23 `#embed`
  under `__has_embed`, so a checkout without them builds and shows the page color; the
  four add 2.3 MB to the APK (5.0 MB). PNG was
  rejected at about 5 MB a season; AVIF needs libavif and an AV1 decoder on both
  platforms to save about 1 MB. If graphics memory gets tight, ASTC at build time cuts
  a 2048² image from 16 MB to about 2 MB.
- **Glass is a pre-blurred copy, not a live blur.** Snowtime measured live backdrop blur
  costing more than its weather animation, and switched to a copy of the background
  blurred once (its `docs/architecture/scene.md`). Here the scene is blurred on the GPU
  when the season is picked, into a small texture (the blur a 24 px one would be at
  1280 px wide, saturation 1.3), so nothing pre-blurred is stored. Natively
  (`app/scene.goose`) two more passes blur the 512 px copy into a 256 × 256 one (sigma
  3.9 texels, on the copy's 2.8), the same at every screen size for the same reason as
  the board's copy. A glass panel samples it at its screen position: one texture fetch
  per pixel, no blur per frame.
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

- **Buttons** are glass tiles: white at 10%, 16% when hovered, 24% while pressed (and
  scaled to 0.96), with an inset 1 px border of white at 20% and a top highlight; radius
  22 px; at least 88 × 88 px (dp) for small hands, icons half the tile with strokes 2.4
  units of their 24-unit grid. A primary button is the glow color at 22%.
- **Icons** are line icons on a 24-unit grid with round strokes, in the Lucide style:
  undo, hint (a bulb), restart, back (an arrow left), next, star, crown, lock, and the
  puzzle themes' target, crown, and shield. The home tiles' icons are filled shapes,
  which read better large: two figures, a robot head, a jigsaw piece.
- **Game screen**: in landscape the board fills the height less a 24 px margin, and a
  glass panel 272 px wide and as tall as the board stands to its right: the side to move
  on top (a 64 px piece of its color with a glow ring right round it, 4 px of the glow
  color at 80% and a 22 px glow, no text) with the move-hints toggle at the row's right,
  a 1 px rule, then undo, hint, restart, and back in a 2 × 2 grid of 104 px tiles. In
  portrait the board fills the width and the panel, 240 px tall, below it holds the
  same top row over the four buttons in a row of 88 px tiles. The toggle is a 52 px
  tile, radius 16 px, with four dots: on (hints show moves) the glow color at 26% with a
  glow border and glow dots; off, white at 8% with a border at 18% and the dots at 45%.
  Undo takes back one move, also one still animating; hint selects the piece of the
  capture that takes the most, if one is due, and marks its target whatever the hints
  are; restart goes back to where the game began; back goes home.
- **A win**: once the winning move has shown, the board dims to 55% and a glass card
  over it shows the winner's piece, crowned, popping in (0.6 s, from 0.3 past its size),
  over back and restart (primary), 112 × 88 px; fourteen sparks, 10 px discs of the glow
  color with a 12 px glow, drift 160 px up over the board twice each (2.4 s, fading in
  over the first fifth), then the screen is still. The panel's piece shows the winner.
- **Home** is a title menu (`prototypes/home-menu.html`, chosen 2026-11-07 over the
  icon tiles and two other takes): the scene and the 3D board, and one glass column
  with the wordmark, then continue, a friend, the computer with its level, and puzzles
  with stars, then settings, each an icon and a word. In portrait settings is instead
  a quiet button beside the wordmark, so the sheet leaves the board its room. The language is
  only in settings (2026-11-07): kids who can't read yet don't need it on home, and a
  tablet set to one language can still play in another. In portrait the column is a sheet below the
  board. **Settings** (`prototypes/settings.html`): back, then a glass group per
  setting (radius 24 px, its icon and title in 24 px), each choice a tile of 16 px
  radius, lit in the glow color at 22% with a 2 px glow border when on: the background
  as thumbnails of the four photographs (104 × 64 px, 88 × 56 in portrait) after a
  tile for by the date, the board (3D dimmed until task 015), move hints, and each
  language by its own name. A tile is as wide as its label needs. **Puzzle picker**: one glass row per theme (capture, become a king, the
  only safe move), its icon and ten tiles of at least 64 px with 0 to 3 stars in the
  glow color; locked tiles show a lock, the next unsolved one a glow ring.
  **Solved**: three stars that pop in over the dimmed board, a few drifting sparks, and
  again or next.

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
  discs with the crown on top, as kings are in Estonian play. Top down, a stack reads as
  a shadow at tablet size, so it's there for those who want it.
- **Native form** (`app/draw.goose`): the blurred photograph, the board's shadow, lip,
  squares, and marks are one full-screen fragment pass, worked out at `gl_FragCoord`
  (interpolated coordinates put a square's edge a pixel off on some rows); the pieces
  are one instanced draw of quads, each pulling `{center, radius, lift; black, king,
  selected, opacity; must capture, side to move}` from a storage buffer and drawing its shadows, side, face, light, crown, and rings in the fragment
  shader, blended premultiplied, top row first so a lower piece covers the shadow above
  it. The crown is a signed-distance polygon in that shader. The panel's line icons are
  to be drawn the same way, as distances to their strokes' segments and arcs, rather than
  baked into the font atlas: crisp at any size, no texture.
- **3D board**: the same board tilted (about 38°, in perspective) with a front edge,
  pieces as discs with height (one disc 1.7% of the board), and the selected piece
  lifted. `prototypes/boards.html` shows it for every theme.
- **States**, in the theme's glow color: the selected piece lifts by 0.8% of the board
  and grows to 1.05 with a glow ring a little out from it (at 1.13 of the radius); with move hints on, a legal target is a glowing
  dot 30% of a square and a capture's stop on the way is a ring. With hints on mistakes
  only (the default, `docs/product.md`), there are no dots: a wrong move flashes a red
  ring on its square twice (0.6 s each), and the piece that must capture pulses; the
piece stays selected. A tap or a drop on an empty square that isn't a move is wrong, as
is touching a piece that can't move because another must capture. A piece that must capture pulses a red ring
  `#ff5a4a` with a soft red glow every 1.4 s, in every theme. The last move's squares are
  tinted with the glow color at 16%.

## Fonts

**Libertinus Sans** (SIL OFL 1.1), the maintained fork of Linux Biolinum: a humanist sans
with flared strokes in the style of Optima, the face of the reference the user liked
(arXiv 2611.07289), with a regular and a bold. Tenor Sans, Belleza, and Marcellus were
compared in `prototypes/fonts.html`; all four have õ ä ö ü š ž. Tenor Sans, which the
proof of concept uses (`assets/fonts/`), is the runner-up: clean and wide, but one weight
only. Marcellus has small serifs, further from Optima. The atlas bakes Latin-1, Latin
Extended-A, and general punctuation. If titles want more character, Tenor Sans could set
them and Libertinus the rest; one face is the default, for one atlas.

Natively (`app/text.goose`) the regular weight (`assets/fonts/`, from the v7.051
release) is baked by `ui`'s atlas once per size the UI uses, at the screen's pixel size,
so a glyph is drawn a texel to a pixel: 64 dp for the wordmark, 30 for labels, 17 for
notes. The atlas sizes a font by its ascent less its descent, 1.14 em for Libertinus,
so each is baked at 1.14 times its size in ems to match the prototypes' CSS. The glyphs'
boxes and atlas places are copied into `gui`'s fixed tables, which lay text out headless,
the image into a texture, and the atlas is then destroyed. A glyph is one more quad kind
in the UI's one draw. Baked again only when the layout's scale changes.

## Frames and battery

The app draws only when something changed: input, a running animation, the AI's reply, or
a new screen size. Otherwise it draws nothing in that frame, and goose_gfx's `frame()`
then neither presents nor spins: it waits for the next event, up to a second. An idle
board costs about one wakeup a second and no GPU work. The loop is the same on every
platform:

```goose
while gfx::frame() {
    // read input, advance animations; set dirty if anything changed
    if dirty || animating { draw(); dirty = false; }
}
```

This is `patches/goose_gfx/0002-draw-on-demand.patch`, applied in the Android build
([findings](../goose-findings.md)). The Mac's built-in gfx still presents every frame at
the display's rate, which costs nothing that matters there. The patched `frame()`:

- presents only if something used the GPU since the last call, or the window needs the
  screen again (exposed, restored, back in the foreground, resized);
- after a frame with nothing drawn, waits in `SDL_WaitEventTimeout` for up to 1 s before
  reading events, so input wakes it at once and timers still run once a second;
- tries again for up to 8 frames when the window has no image to show, as on the first
  frames after Android recreates the surface on resume;
- leaves the wait out of `delta_time()`, so the first animation frame after idle doesn't
  jump.
- on Android, turns off SDL's poll sentinel, without which SDL's wait spins instead of
  blocking there.

An animation's last frame is not the resting state: the frame after a move or a pulse
ends is drawn too (`board::update` reports it), or the board would keep the move's last
in-between frame without its marks.

Work that finishes on another thread, such as the computer's reply, is seen within the
second; while the computer thinks, the board shows a small animation, which keeps
frames coming. While Android has the app paused, SDL blocks the loop: it draws nothing
and submits no GPU work.
