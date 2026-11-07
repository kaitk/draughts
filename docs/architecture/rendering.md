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
- `button(id, rect, icon)` returns true on release. A small fixed table holds per-id state
  for pressed and hover animation.
- Calls append quads (`rect`, `panel`, `text`, `icon`) to one vertex array, and one
  pipeline draws them.

Nuklear (`ui`) is only for developer tools, such as a puzzle editor, because restyling
its desktop widgets into the kid UI would fight it. If layout outgrows rect-cutting
(scrolling lists, wrapping text, menus like Snowtime's), we copy
[Clay](https://github.com/nicbarker/clay)'s model, a per-frame layout tree with
grow/fit/fixed sizing, rather than linking it. Its API is C macros, which Goose can't
call directly.

## Look

Reference: Snowtime's UI ([repo](https://github.com/Snowhound/snowtime), its
`prototypes/`): dark frosted glass panels over a scene, thin light borders, flat
buttons. The HTML prototypes in [`prototypes/`](../../prototypes/README.md) settled the
values below on 2026-11-07; they use only what this renderer draws cheaply.

### Scene and glass

- **The scene** is a calm Estonian landscape for the season, picked from the date, and
  the season picks the board too (overridable): autumn forest with the wood board,
  winter spruces with stone, spring birches with a birch board, summer coast with a sea
  board. Each scene is a photograph-like picture (`design/backgrounds/`, placeholders
  until task 014). The prototypes still paint the scene and soften it with a 6 px blur;
  task 012 brings them to the photographs and each theme's palette, glow, and glass
  tint, from the user's design boards.
- **Stored** as one JPEG per season, decoded with stb_image, cover-cropped to the
  screen. Only the current season is loaded. The glass copy is made from it on the GPU
  whenever the season or screen size changes, so nothing pre-blurred is stored. If
  graphics memory gets tight, ASTC at build time cuts a 2048² image from 16 MB to about
  2 MB. AVIF was ruled out: it needs libavif and an AV1 decoder on both platforms to save
  about 1 MB of APK. (Task 012 confirms this.)
- **Glass is a pre-blurred copy, not a live blur.** Snowtime measured live backdrop blur
  costing more than its weather animation, and switched to a copy of the background
  blurred once (its `docs/architecture/scene.md`). Here the scene is blurred once, when it
  changes, into a small texture (240 px wide, the blur a 24 px one would be at full width,
  saturation 1.3). A glass panel samples it at its screen position: one texture fetch per
  pixel, no blur per frame.
- **Glass layers**, bottom to top: the copy; black at 40% (the copy dimmed to 0.6); the
  card color `#142438` at 40%; a 1 px border of white at 14%; a 1 px top highlight of
  white at 12%; a shadow `0 12px 32px -14px` of black at 55%. Corner radius 28 px.
  These are Snowtime's dark glass values.
- **Text** is `#eef5fb`, and secondary text the same at 66%. The page color under
  everything is `#0b1622`.

### Controls

- **Buttons** are flat fills on the glass: white at 7%, 13% when hovered, 20% while
  pressed (and scaled to 0.96); radius 22 px; at least 88 × 88 px (dp) for small hands,
  icons 40 px with 2 px strokes. A primary button is the glow color at 22%.
- **Icons** are line icons on a 24 px grid, 2 px round strokes, in the Lucide style: back,
  undo, hint (a bulb), restart, next, a friend (two figures), the computer (a robot head,
  with three level dots under it), puzzles (a jigsaw piece), star, crown, lock.
- **Game screen**: in landscape the board fills the height less a 24 px margin, and a
  128 px glass panel stands to its right: back at the top, the side to move (a piece of
  its color with a glow ring, no text) in the middle, hint, undo, and restart at the
  bottom. In portrait the board fills the width and the panel is a 128 px row below it.
- **Home**: three large glass tiles (play a friend, play the computer, puzzles), in a
  row in landscape and a column in portrait. **Puzzle picker**: one glass row per tier,
  ten tiles of at least 64 px each with 0 to 3 stars; locked tiles show a lock, the next
  unsolved one a glow ring. **Solved**: three stars that pop in over the dimmed board, a
  few drifting sparks, and again or next.

### Board and pieces

- **Board**: wood. Light squares `#e8c99a`, dark `#9a6a45`, a frame `#5b3a24` 2.4% of the
  board's width with rounded corners. Stone (`#d7d4cd`, `#66707a`, frame `#3a4048`) and
  flat (`#dfe6d2`, `#6f9270`, frame `#3f5c48`) were compared and kept as later options.
- **Pieces** are SDF discs filling 78% of a square: a face, an inner ring at 45 to 52%
  of the radius, a rim from 80%, and a side under the disc 0.55% of the board deep, over a
  soft shadow. White: face `#f6ead6`, ring `#d9c3a0`, rim `#e6d3b3`, side `#b89c74`.
  Black: face `#4a2c1c`, ring `#6d4630`, rim `#3a2215`, side `#1e110a`.
- **Kings** are a setting: crown, stack, or auto (the default). Auto draws a gold crown
  on the face in the top-down board (`#c08a2c` on white, `#e9c46a` on black), which reads
  at a glance, and in a 3D board a stack of two discs with the crown on top, as kings are
  in Estonian play. Top down, a stack reads as a shadow at tablet size, so it's there
  for those who want it.
- **States**, all in the glow color `#ffd36e`: the selected piece lifts by 1.1% of the
  board and grows to 1.06 with a glow ring; a legal target is a glowing dot 30% of a
  square; a capture's stop on the way is a ring. A piece that must capture pulses a ring
  in `#ff9466` every 1.4 s. The last move's squares are tinted with the glow color at 16%.

## Fonts

**Libertinus Sans** (SIL OFL 1.1), the maintained fork of Linux Biolinum: a humanist sans
with flared strokes in the style of Optima, the face of the reference the user liked
(arXiv 2611.07289), with a regular and a bold. Tenor Sans, Belleza, and Marcellus were
compared in `prototypes/fonts.html`; all four have õ ä ö ü š ž. Tenor Sans, which the
proof of concept uses (`assets/fonts/`), is the runner-up: clean and wide, but one weight
only. Marcellus has small serifs, further from Optima. The atlas bakes Latin-1, Latin
Extended-A, and general punctuation. If titles want more character, Tenor Sans could set
them and Libertinus the rest; one face is the default, for one atlas.

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

Work that finishes on another thread, such as the computer's reply, is seen within the
second; while the computer thinks, the board shows a small animation, which keeps
frames coming. While Android has the app paused, SDL blocks the loop: it draws nothing
and submits no GPU work.
