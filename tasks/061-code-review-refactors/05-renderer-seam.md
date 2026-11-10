# 05: Stage 4, the renderer seam

Status: todo

Stage 3 (`04-layout.md`) first. What the app shows doesn't change. This is the seam
that task 060 (shared blocks for chess) and a later goose-ngfx renderer build on. It is
worth having even without either.

The game packages are already clean. The flat structs that cross to the renderer are
laid out as the shaders read them:

- `gui::Quad`
- `board::Piece` and `board::Marks`
- `board::Layout`
- `theme::Theme`
- `view3d::Scene`

The app has no seam:

- gfx is both the platform layer (window, input, time, focus) and the renderer, and
  `main` calls both halves directly.
- `draw::frame` and `draw3d::frame` begin the screen pass (`draw.goose:523`), while
  `main` ends it (`draughts.goose:400`) and flushes it (`:406`).
- The draw sequence at `draughts.goose:383–400` is the real renderer, spread over five
  calls.
- gfx handles live in the app's state: `draw::Drawer`, `scene::Scene`,
  `text::Text.texture`, and `Widgets`, plus `w.atlas = t.texture` and
  `w.thumbs = scene::thumbs(…)`.
- `background.c` (48, 151–159) and `resize.c` (80, 94) call goose_gfx's C texture
  functions directly.

## Steps

1. **`app/host.goose`** (about half a day). Every platform call moves out of `main`:
   - open the window;
   - `frame`, `frame_count`, `time`, `screen_size`, `focused`;
   - the pointer and the events;
   - the keys and text input;
   - the screenshot.

   It wraps gfx as it is now. `wake.c`'s and `display.c`'s SDL calls stay as they are,
   since they work under any renderer.
2. **`app/render.goose`** (about a day). It holds every Drawer (`draw`, `draw3d`,
   `widgets`, `scene`, `text`'s texture) and has:
   - `render::new(kind, plain)` and `reload`;
   - `upload_text`, `upload_badges`, and `thumbs`;
   - `render::frame(FrameData)`, which owns the pass's begin and end;
   - `drop_3d` and `release`;
   - the lost device, which shows today as `frame()` returning false (goose_gfx patch
     0006).

   `FrameData` holds plain values, passed by reference:
   - the shown board's pieces, marks, and flash;
   - the `Layout` and the pieces over the UI;
   - the quads slice and the theme;
   - the 3D scene and its matrix;
   - blur, hole, tall, place, and fade;
   - now and the size.

   After this, `main` calls no gfx drawing function.
3. **Pixels from C** (about a day):
   - `background.c` returns pixels and their format, and the renderer uploads them.
   - `resize.c` takes pixels instead of reading a gfx texture back.
   - Text and badges hand over R8 bytes; `text.goose` already builds them.
   - **Watch the season photograph's load**, 80 to 95 ms on the tablet today. It must not
     gain a copy. Time it before and after on the tablet or the A33.
4. **Split `render3d`** (about half a day). Its gfx-free half moves to its own file or
   package:
   - `mesh`
   - `looks`
   - `harmonics`
   - the theme bake's planning

   The half that calls gfx keeps the rest.
5. **Docs.** Record the seam in `docs/architecture/README.md` ("Code layout", "A
   frame") and in `rendering.md`.

Leave alone:

- `view3d`'s matrix, which is column-major for SDL_GPU's clip space; a later renderer
  converts it on its own side;
- the GLSL;
- `render3d`'s internals beyond the split.

## Acceptance criteria

- [ ] `main` calls `host` and `render` only, no gfx directly
- [ ] One `render::frame(FrameData)` owns the pass; no gfx handle outside `render` and
      its Drawers
- [ ] The C decoders return pixels; `draughts_photo` declared once
- [ ] `render3d`'s gfx-free half separate
- [ ] Every expected output byte-identical; shots on the Mac match before and after
- [ ] The photograph's load time, idle CPU, and the 2D and 3D bench on the Mac and the
      A33 recorded here, none noticeably worse
