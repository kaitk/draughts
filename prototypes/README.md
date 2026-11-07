# UI prototypes

Static HTML prototypes for comparing designs before building them in Goose. Open each file
directly in a browser (`file://`): no server and no build step. Fonts load from the
jsDelivr CDN, so they need internet access. Start at [index.html](index.html).

| Page | Shows |
| --- | --- |
| `home.html` | Home: a title menu over the photograph and a 3D board; `?pick=friend` or `computer` shows a new game's setup |
| `first-start.html` | The first start, pages in order (`?page=variant`, `learn`, `1` to `7`, `done`; `&v=russian`) |
| `settings.html` | Settings: background, board, move hints, language |
| `game.html` | The game: the board between the way out and the play, a selected piece and its capture, a forced capture; `?clock=on` or `low` for the clocks |
| `puzzles.html` | The puzzle picker: three theme rows of ten, with 0 to 3 stars |
| `solved.html` | A solved puzzle: stars over the dimmed board |
| `boards.html` | The four season boards in 2D and 3D, crowned and stacked kings, and 10×10 |

Shared parts: `draughts.css` (theme tokens, glass, buttons, board, pieces, light) and
`draughts.js` (the season's background and the glass over it, the board in 2D and 3D,
icons). The 2D board and its pieces are painted by a port of the native shaders
(`app/draw.goose`) in `draughts.js`, into images at their size on screen, so they look as
the app does: the lip, the squares' faint surface, the pieces' groove and rounded edge.
Change that port with the shaders. The background is the season's master from `design/backgrounds/masters/`,
blurred behind the 2D board and sharp elsewhere (`?bg=blur` or `photo`), which is local and out of git
([its README](../design/backgrounds/README.md) says how to make it); without it the
pages paint a stand-in. A switcher at the bottom right of every page
changes the season, board theme (auto follows the season), view, king style, background,
and move hints, also as URL parameters:
`game.html?season=winter&theme=sunset&view=3d&king=stack&bg=photo`.

Prototypes only use what the native renderer can draw cheaply: rounded rects, SDF
circles, gradients, one pre-blurred background for glass (see
[rendering](../docs/architecture/rendering.md#look)), and baked text. No live
`backdrop-filter` blur: glass shows a blurred copy of the scene placed at the panel's
screen position, as the shader will sample it. The 3D board is CSS 3D standing in for
lit meshes. The chosen values (colors, radii, opacities, sizes) are in
`docs/architecture/rendering.md`.

Check a prototype with the `agent-browser` CLI at tablet sizes, 1280×800 landscape and
800×1280 portrait:

```sh
agent-browser --session draughts set viewport 1280 800
agent-browser --session draughts open "file://$PWD/prototypes/game.html"
agent-browser --session draughts screenshot /tmp/game.png
agent-browser --session draughts errors
```

Design boards from an image model are made with `design-boards-prompt.md` and kept out
of git. When handing a prototype off, include its full absolute `file:///` URL.
