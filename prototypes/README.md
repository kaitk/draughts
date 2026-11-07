# UI prototypes

Static HTML prototypes for comparing designs before building them in Goose. Open each file
directly in a browser (`file://`): no server and no build step. Fonts load from the
jsDelivr CDN, so they need internet access. Start at [index.html](index.html).

| Page | Shows |
| --- | --- |
| `home-board.html` | Home, take A: the board first, with labelled buttons beside it |
| `home-cards.html` | Home, take B: three solid cards with scenes made of pieces |
| `home-menu.html` | Home, take C: a title menu over the photograph and a 3D board |
| `home.html` | Home, the first take: three glass tiles with icons only |
| `game.html` | The game: a selected piece and its capture, a forced capture, the side panel |
| `puzzles.html` | The puzzle picker: three theme rows of ten, with 0 to 3 stars |
| `solved.html` | A solved puzzle: stars over the dimmed board |
| `boards.html` | The four season boards in 2D and 3D, crowned and stacked kings, and 10×10 |
| `fonts.html` | The font candidates with Estonian text, and a check of their letters |

Shared parts: `kabe.css` (theme tokens, glass, buttons, board, pieces, light) and
`kabe.js` (the season's background and the glass over it, the board in 2D and 3D,
icons). Behind the 2D board is a flat tabletop in the theme's color, painted by
`kabe.js`. Behind the 3D board (and with `?bg=photo`) is the season's master from
`design/backgrounds/masters/`, which is local and out of git
([its README](../design/backgrounds/README.md) says how to make it); without it the
pages paint a stand-in. A switcher at the bottom right of every page
changes the season, board theme (auto follows the season), view, king style, background,
and font, also as URL parameters:
`game.html?season=winter&theme=sea&view=3d&king=stack&bg=photo&font=tenor`.

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
agent-browser --session kabe set viewport 1280 800
agent-browser --session kabe open "file://$PWD/prototypes/game.html"
agent-browser --session kabe screenshot /tmp/game.png
agent-browser --session kabe errors
```

Design boards from an image model are made with `design-boards-prompt.md` and kept out
of git. When handing a prototype off, include its full absolute `file:///` URL.
