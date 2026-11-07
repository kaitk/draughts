# 003: UI prototypes

Status: todo

HTML prototypes of the MVP screens in `prototypes/`, in the spirit of Snowtime's: glass
panels over a calm scene, flat buttons, big touch targets. They settle the look before
it's built natively, and they use only what the native renderer can draw cheaply
(`prototypes/README.md`). Checked with `agent-browser` at 1280×800 and 800×1280.

Design boards from an image model, made with `prototypes/design-boards-prompt.md`, may
feed the choices; the HTML prototypes settle them.

## Acceptance criteria

- [ ] Screens: home, game (board, side panel with undo, hint, restart), puzzle picker
      (tiers, stars), puzzle solved
- [ ] Board and pieces: 2 or 3 variants side by side (wood, stone, flat), with king,
      selected piece, legal targets, and forced capture shown
- [ ] Glass from a pre-blurred background, with Snowtime's dark glass values as the start
- [ ] Font comparison: Libertinus Sans (the maintained fork of Linux Biolinum, the font of
      the reference the user liked, arXiv 2611.07289), Tenor Sans, Belleza, Marcellus, with
      Estonian text, licenses noted
- [ ] Optionally a seasonal scene under the glass, as Snowtime has, only if it stays cheap
      (a static picture, blurred once)
- [ ] Choices and their values recorded in `docs/architecture/rendering.md`
