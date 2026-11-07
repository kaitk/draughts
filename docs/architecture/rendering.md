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
buttons. Prototypes in `prototypes/` (task 003) settle the look before it is built.

- **Glass is a pre-blurred copy, not a live blur.** Snowtime measured live backdrop blur
  costing more than its weather animation, and switched to a copy of the background
  blurred once (its `docs/architecture/scene.md`, task 069). Here, the background is
  blurred once into a texture when it changes, and a glass panel samples that texture
  at its screen position, then adds tint, a border, and a highlight. One texture fetch
  per pixel, no blur per frame.
- Snowtime's dark glass is 40% card color over the scene dimmed to 0.6 brightness at 1.3
  saturation. That's our starting point.

## Fonts

Wanted: a humanist sans with flared strokes, in the style of Optima. Optima itself is a
commercial font, so the app needs an open-licensed font in that style. The reference the
user liked (arXiv 2611.07289) is set in Linux Biolinum, whose maintained fork is
Libertinus Sans (SIL OFL). Candidates to compare in a prototype: Libertinus Sans, Tenor
Sans, Belleza, Marcellus. Each must have õ ä ö ü š ž and allow embedding (SIL OFL or
similar). The atlas bakes Latin-1, Latin Extended-A, and general punctuation. Task 001
uses Tenor Sans (`assets/fonts/`, OFL), which has all the Estonian letters.

## Frames and battery

The app draws only when something changed: input, a running animation, or the AI's reply.
Otherwise it blocks in `SDL_WaitEvent`. goose_gfx polls events each frame, so this needs
a wait variant in goose_gfx (task 005). While Android has the app paused, it draws
nothing and submits no GPU work.
