# 05: Stage 4, the renderer seam

Status: todo

Stage 3 (`04-layout.md`) first. What the app shows doesn't change. This is the seam
that task 060 (shared blocks for chess) and a later goose-ngfx renderer build on. It is
worth having even without either.

## First: review stage 3's departures

Stage 3 (`04-layout.md`, "Outcome") left five places where it didn't do what its file
asked. The user wants each one reviewed before this stage starts. For each, read the
code and decide whether the choice holds or an alternative is better. Ask the user
before changing an expected output or what the app shows. Record each verdict here.

1. **`shell::still` still runs the screen's frame.** The file said it declared the
   screen left only to learn where the board goes; in fact `shell::blend` fades those
   quads out, so the screen left is drawn. The transition's frame time wasn't measured
   for that reason; the shell's frame was timed headless instead. The alternatives: a
   cheaper still declaration (the layout plus only what shows faded), or dropping the
   fade-out, which changes what the app shows.
2. **The rects that change with the game aren't in `panel::Layout`.** The layout holds
   what doesn't change (the bar's tiles' room, `stacked`, what each side has taken); the
   clocks, the eye, the hint, and undo move come per frame from `way_out` and the three
   `*_play` functions, as `Out` and `Play`. The alternative: fill them into the layout
   each frame before `game()`, which needs the game's state and the faces where the
   shell builds the layout.
3. **`game()` was split by layout, not by declaring.** One function per mode works out
   the regions; one declaring sequence serves all three, with `turn_words` choosing the
   words' look by mode. The alternative: a declaring function per mode as well, repeating
   the clocks, the piece, and the controls three times.
4. **`gui::stack` is used in fewer places than listed.** Home's menu and settings'
   landscape column use it. Settings' side-by-side groups keep their cuts (the stack
   changed a printed position in its last decimals), one group at a time keeps them (a
   cut clamps a glass taller than its room), and the rows, the cards, and the picker's
   grid don't use it. The alternatives: re-bless the outputs the stack moves by a last
   bit, or give the stack a cut's clamp.
5. **`settings::layout` writes `s.name_w` and `s.slim`.** It is pure but for those two,
   which the rows read through `s`. The alternative: return them in the `Page` and pass
   them down to `rows_at`, `group_width`, `group_height`, and the tiles.

### Verdicts

(to fill in)

## The seam

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
     gain a copy. It is timed with the task's end measurement (`README.md`).
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
- [ ] The task's end measurement, with the photograph's load (`README.md`)
