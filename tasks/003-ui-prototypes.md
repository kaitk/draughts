# 003: UI prototypes

Status: done

HTML prototypes of the MVP screens in `prototypes/`, in the spirit of Snowtime's: glass
panels over a calm scene, flat buttons, big touch targets. They settle the look before
it's built natively, and they use only what the native renderer can draw cheaply
(`prototypes/README.md`). Checked with `agent-browser` at 1280×800 and 800×1280.

Design boards from an image model, made with `prototypes/design-boards-prompt.md`, may
feed the choices; the HTML prototypes settle them.

## Acceptance criteria

- [x] Screens: home, game (board, side panel with undo, hint, restart), puzzle picker
      (tiers, stars), puzzle solved
- [x] Board and pieces: 2 or 3 variants side by side (wood, stone, flat), with king,
      selected piece, legal targets, and forced capture shown
- [x] Glass from a pre-blurred background, with Snowtime's dark glass values as the start
- [x] Font comparison: Libertinus Sans (the maintained fork of Linux Biolinum, the font of
      the reference the user liked, arXiv 2611.07289), Tenor Sans, Belleza, Marcellus, with
      Estonian text, licenses noted
- [x] Optionally a seasonal scene under the glass, as Snowtime has, only if it stays cheap
      (a static picture, blurred once)
- [x] Choices and their values recorded in `docs/architecture/rendering.md`

## Outcome (2026-11-07)

Seven pages in `prototypes/` (`index.html` lists them), sharing `kabe.css` and `kabe.js`,
each checked with `agent-browser` at 1280×800 and 800×1280 with no console errors. No
design boards had been dropped into `prototypes/boards/` by then, so the HTML settled the
look alone. The chosen values are in `docs/architecture/rendering.md` ("Look", "Fonts"):

- Glass: Snowtime's dark glass, as a copy of the scene blurred once and fixed to the
  viewport, never `backdrop-filter`.
- Board: wood, with crowned kings; stone and flat kept as options. A stacked king read as
  a shadow at tablet size.
- Font: Libertinus Sans, with Tenor Sans the runner-up. All four candidates have
  õ ä ö ü š ž, checked in the browser by measuring each letter against two fallbacks.
- Scene: a procedural seasonal landscape here; the app will use a static picture per
  season, blurred once into a 240 px texture.

Left for task 004: the icons need a native form, either SDF shapes drawn in a shader or
glyphs baked into the font atlas from their SVG paths.
