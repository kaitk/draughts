# UI prototypes

Static HTML prototypes for comparing designs before building them in Goose. Open each file
directly in a browser (`file://`): no server and no build step. Fonts load from the
jsDelivr CDN, so they need internet access. Start at [index.html](index.html).

| Page | Shows |
| --- | --- |
| `home.html` | Home: a title menu over the photograph and a 3D board; `?pick=friend` or `computer` shows a new game's setup |
| `first-start.html` | The first start, pages in order (`?page=variant`, `learn`, `1` to `7`, `done`; `&v=russian`) |
| `settings.html` | Settings: background, board, move hints, language |
| `plain.html` | Takes on a plain background in place of the photograph, its fade matched to the season's board (task 044): where its on/off sits in settings (`?place=a`, a Picture row of its own; `b`, a switch under the Background row's name; `c`, one tile at the row's end; `&plain=on`, `&lang=et`), and the four seasons' fades behind home, the flat game, and the 3D game (`?view=grid`); `&grad=a`, the 3D backdrop's grade of the page color, or `b`, darker and calmer |
| `game.html` | The game: the board between the way out and the play, a selected piece and its capture, a forced capture; `?clock=on` or `low` for the clocks; `?count=a` or `b` (`&n=`) for takes on how many pieces a must-capture piece takes, on a child's position of 2026-11-09 (a, pips on the ring, built) |
| `coach.html` | Takes on the lookout and the hint as two controls (task 040), round 3 (`?take=a`, the lookout a round toggle on whose turn's line; `b`, a tile among the way-out ones; the hint a tile beside undo in both; `&mark=shade`, `drain`, `shadow` for the piece in danger; `&king=square`, `piece` for a crowning; `&state=calm`, `held`, `king`, `hint1`, `hint2`, `control`; `&lookout=on`, `off`; `&name=lookout`, `guard`, `danger`, `eagle`; `&lang=et`; `&you=black`; `&view=sheet`); in portrait the switcher folds under Options. Rounds 1 and 2 (`coach-1.html`, `coach-2.html`) were removed 2026-11-10 (in git history before that commit). Built from round 3 (2026-11-09): take a, the `drain` mark, the crowning `square`, the name Lookout |
| `game3d.html` | Takes on the game's UI round a WebGL 3D board with the native camera (`?take=now`, `steep`, `top`, `corners`, `bleed`, `&pitch=`, `&guides`): the current layout, a steeper camera, the board pushed up, the panels in the top corners beside the narrower far edge, the frame running off the screen; a drag turns the board. On `corners`, floating camera buttons (`&controls=a`, the default, a column at the right edge under the play panel; `b`, beside the board's near corners; `off`): the view (52.5° or 74° down), zoom (landscape only; the whole field fitted clear of the panels and buttons), and the showcase mode (a lit button; drags anywhere on the board turn and tip it, no spring back, the button or a move eases back in 0.6 s), the board refitting as it moves; `&pp=52.5`, `60`, `65` (default) for portrait's camera; the switcher's Move turns the board for the other player (task 015) |
| `game-captured.html` | Takes on what each side has captured (task 052) on the game screen as built, flat and raised, at every size (`?cap=a`, in the left side: a row in the left panel, under the bar's tiles, the compact bar's middle; `b`, on the table at the board's left: a slim tray, the corner under the left panel, strips over and under the board, a column in compact; `off`), `&look=row` (the app's pieces overlapping), `pile` (discs stacked, from the side), `count` (a piece and a number), `&state=early` (one each) or `late` (12, a king among them); `&flat=now`, `a`, `b` for task 054's flat screen, `&frame=a` or `b`, `&btns=raise` or `none`; `?grid=1` sets the tablet, a phone, and the smallest iPad window side by side, flat and raised |
| `puzzle-set.html` | Takes on choosing the draughts on the puzzles' library, and the library reworked (`?take=now`, `a`, `b`, `c`, `&v=intl`, `brazilian`, `russian`, `&tie=shared` or `own`, `&br=shown` or `hidden`, `&stars=some` or `none`, `&view=library` or `home`, `&open=1` for b's picker, `&lang=et`): today's library; a switch in the title row; the name under the title opening a picker, with Continue, stars, what's next, and locked themes as a path; a grid of cards with the setup's draughts tiles (task 037) |
| `puzzle.html` | Takes on playing one puzzle (`?take=a` to `c`, `&state=play`, `wrong`, `hint`, `solved`), waiting for a pick (task 007) |
| `profiles.html` | Takes on players, one per child (`?take=a` to `c`, `&state=home`, `pick`, `add`, `edit`, `hold`, `&n=1` to `4`, `&lang=et`): the face beside the name, who's playing on launch, faces on home; the player's sheet with its holds (task 038) |
| `history.html` | Takes on the games' history (tasks 074 and 078), one International game played out legally throughout: `?view=game`, the game screen as built with the moves panel (`&take=a`, under the play panel, built; portrait a strip of the last moves under the play row; a phone in landscape none but in `d`, a line of the last move under the left column opening a sheet of the moves over the screen's left part to the board's edge, `&open=1`, `&fit=row` (back and settings side by side, the line a full tap) or `slim` (the column as built, the line the room's height), `&device=pixel`, `a33`, `iphone`, `none` (by default from the window's size), `&board=flat` or `3d`, `&grid=1` both fits closed and open on the phones; a phone in portrait in `d`, the last move a tap opening a sheet from the foot, `&port=strip` under the play row or `bar` between the catches), `settings` (the Moves row: Off, List, Marks), `games` (the rating per draughts, by level, the games played), `replay` (a past game from its results row: the board beside the whole list, four steps, a move's tap jumping there, "Doesn't count" by the title, `&ply=0` to `110`), `entry` (a Games row on home); a mark's meaning as a tip on a touch or under the mouse (`&explain=pop`) or a legend at the list's foot (`legend`), `&tip=N`, `foot`, or `games` pinning one open; `&marks=on`, `off`, `hidden`, `&state=early`, `mid`, or `late`, `&lang=et`; a note at the bottom left gives each layout's room. Takes b and c on the game screen, the setting on the player's sheet (`&place=sheet`), and the entry as a tile on the player's sheet (`&entry=sheet`) were removed 2026-11-12 (in git history before that commit). Built: take a, the setting in settings, the entry from home |
| `new-game.html` | Takes on home with one New game row and the opponent chosen in the setup (task 080): `?view=home` or `setup`, `&take=a` (an Opponent row first, the column scrolling with Play pinned), `b` (the opponent a two-part switch beside back), `c` (one row: A friend, Easy, Medium, Hard; under it Your pieces or the friend's board turning, so both setups have the same rows), `&vs=computer` or `friend`, `&word=new` or `play`, `&note=on` or `off` (the last opponent at the row's end); a phone in landscape moves Play into the head row; `&device=tablet`, `pixel`, `iphone` (insets), `?grid=1` every device both ways |
| `settings-takes.html` | Takes on settings as one list that scrolls, Look first, then Game, the language, and the privacy note, with the raised board's material, Auto, Wood, Stone, or Carved (task 080): `&take=a` (a Material row under Board, shown while raised), `b` (Flat, Raised, Wood, Stone, Carved in the Board row), `c` (each season its own material, the theme's tiles showing each season's board); `&season=`, `&view=2d` or `3d`, `&mat=auto`, `wood`, `stone`, `carved` (`&mat_autumn=` and so on in c), `&plain=on`, `&langui=menu` (a globe and the code in the title row opening a list; `&open=1`), `seg` (EN and ET as two tiles there), or `foot` (a section at the list's foot), `&device=`, `?grid=1`; Background above Theme, the Kings' tiles with their king. The boards' pictures are `build/board3d --shot`s in `shots/` (local, out of git: `poc/3d$ ../../build/board3d --shot x.png --size 960x720 --theme autumn`, resized to 640 × 480 JPEG as `shots/<season>-<wood|stone|carved>.jpg`, the flags in task 080's 03); a missing one shows hatched |
| `badges.html` | Takes on a player's picture (task 038): five badge styles at 64 and 112 dp over the photograph and glass (carved pieces, nature tokens, animal lines, coloured rims, at dusk; `?disc=wood`, `?pieces=both`), the carved one placed on home four ways (`?home=1` to `4`) and the first start's pick (`?home=first`), with an image prompt for finer art |
| `issue-1.html` | Takes on two points of issue 1 (kaitk/draughts#1), side by side in a phone's portrait: what home's Continue continues (a, a note and the row dim with nothing to continue; b, no row on a first run; a's note with b's hidden row built; c, the last thing played, a puzzle too), and settings' Draughts row (a, removed, built; b, kept and named for new games and puzzles; c, shown read-only) |
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
move hints, and the plain background (`plain=on`, `grad=a` or `b`), also as URL parameters:
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
