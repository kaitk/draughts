# UI prototypes

Static HTML prototypes for comparing designs before building them in Goose. Open each file
directly in a browser (`file://`): no server and no build step. Fonts load from the
jsDelivr CDN, so they need internet access. Start at [index.html](index.html).

| Page | Shows |
| --- | --- |
| `home.html` | Home: a title menu over the photograph and a 3D board; `?pick=friend` or `computer` shows a new game's setup |
| `first-start.html` | The first start, pages in order (`?page=variant`, `learn`, `1` to `7`, `done`; `&v=russian`) |
| `settings.html` | Settings: background, board, move hints, language |
| `game.html` | The game: the board between the way out and the play, a selected piece and its capture, a forced capture; `?clock=on` or `low` for the clocks; `?count=a` or `b` (`&n=`) for takes on how many pieces a must-capture piece takes, on a child's position of 2026-11-09 (a, pips on the ring, built) |
| `game3d.html` | Takes on the game's UI round a WebGL 3D board with the native camera (`?take=now`, `steep`, `top`, `corners`, `bleed`, `&pitch=`, `&guides`): the current layout, a steeper camera, the board pushed up, the panels in the top corners beside the narrower far edge, the frame running off the screen; a drag turns the board. On `corners`, floating camera buttons (`&controls=a`, the default, a column at the right edge under the play panel; `b`, beside the board's near corners; `off`): the view (52.5° or 74° down), zoom (landscape only; the whole field fitted clear of the panels and buttons), and the showcase mode (a lit button; drags anywhere on the board turn and tip it, no spring back, the button or a move eases back in 0.6 s), the board refitting as it moves; `&pp=52.5`, `60`, `65` (default) for portrait's camera; the switcher's Move turns the board for the other player (task 015) |
| `puzzles.html` | Takes on the puzzle picker by theme (`?take=a` to `c`, `now` for the tiers of ten, `&view=library`, `theme`, `&theme=`, `&themes=first`, `all`, `&solved=0` to `12`, `&lang=et`): a library of themes and a theme's three levels (task 037) |
| `puzzle.html` | Takes on playing one puzzle (`?take=a` to `c`, `&state=play`, `wrong`, `hint`, `solved`), waiting for a pick (task 007) |
| `solved.html` | A solved puzzle: stars over the dimmed board |
| `win.html` | Takes on a win (`?take=a` to `c`, `&t=` seconds to hold a moment; a click plays it again), take a built (task 031, archived) |
| `exit.html` | Takes on a way to close the app from home (`?take=a` to `c`, `&lang=et`), take b built (task 035, archived), later the bare X of `gear.html?x=d` |
| `gear.html` | Takes on home's settings in portrait (`?take=now`, `a`, `b`, `&lang=et`, `&guides`): the quiet tile as it was, the gear alone, the X's round glass; take a built; `&x=a` to `d` for takes on the X beside the bare gear, d built |
| `profiles.html` | Takes on players, one per child (`?take=a` to `c`, `&state=home`, `pick`, `add`, `edit`, `hold`, `&n=1` to `4`, `&lang=et`): the face beside the name, who's playing on launch, faces on home; the player's sheet with its holds (task 038) |
| `badges.html` | Takes on a player's picture (task 038): five badge styles at 64 and 112 dp over the photograph and glass (carved pieces, nature tokens, animal lines, coloured rims, at dusk; `?disc=wood`, `?pieces=both`), the carved one placed on home four ways (`?home=1` to `4`) and the first start's pick (`?home=first`), with an image prompt for finer art |
| `chip.html` | Takes on keeping the bare player's chip's name readable on bright photographs in landscape (`?take=a` to `e`: bare, a soft shadow, a top scrim, a glass pill, a short dark shadow; `&season=` for one, else the four at half size) |
| `boards.html` | The four season boards in 2D and 3D, crowned and stacked kings, and 10×10 |

Shared parts: `draughts.css` (theme tokens, glass, buttons, board, pieces, light) and
`draughts.js` (the season's background and the glass over it, the board in 2D and 3D,
icons). The 2D board and its pieces are painted by a port of the native shaders
(`src/app/draw.goose`) in `draughts.js`, into images at their size on screen, so they look as
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
lit meshes, except in `game3d.html`, where plain WebGL2 draws it for layout work. The chosen values (colors, radii, opacities, sizes) are in
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
