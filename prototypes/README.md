# UI prototypes

Static HTML prototypes for comparing designs before building them in Goose. Open each file
directly in a browser (`file://`): no server and no build step. Fonts load from the
jsDelivr CDN, so they need internet access. Start at [index.html](index.html).

| Page | Shows |
| --- | --- |
| `home.html` | Home: play a friend, play the computer (three levels), puzzles |
| `game.html` | The game: a selected piece and its capture, a forced capture, the side panel |
| `puzzles.html` | The puzzle picker: three tiers of ten, with stars |
| `solved.html` | A solved puzzle: stars over the dimmed board |
| `boards.html` | Wood, stone, and flat boards, crowned and stacked kings, and 10×10 |
| `fonts.html` | The font candidates with Estonian text, and a check of their letters |

Shared parts: `kabe.css` (tokens, glass, buttons, board, pieces) and `kabe.js` (the
seasonal scene and its pre-blurred copy, the board, icons). A switcher at the bottom right
of every page changes the board theme, font, season, and king style, also as URL
parameters: `game.html?theme=stone&font=tenor&season=winter&king=stack`.

Prototypes only use what the native renderer can draw cheaply: rounded rects, SDF
circles, gradients, one pre-blurred background for glass (see
[rendering](../docs/architecture/rendering.md#look)), and baked text. No live
`backdrop-filter` blur: glass shows a copy of the scene blurred once, fixed to the
viewport. The chosen values (colors, radii, opacities, sizes) are in
`docs/architecture/rendering.md`.

Check a prototype with the `agent-browser` CLI at tablet sizes, 1280×800 landscape and
800×1280 portrait:

```sh
agent-browser --session kabe set viewport 1280 800
agent-browser --session kabe open "file://$PWD/prototypes/game.html"
agent-browser --session kabe screenshot /tmp/game.png
agent-browser --session kabe errors
```

Design boards from an image model, made with `design-boards-prompt.md`, go in `boards/`
as PNGs. When handing a prototype off, include its full absolute `file:///` URL.
