# UI prototypes

Static HTML pages of the app's screens as they are built, a base to try a new idea on
before building it in Goose. Open a file directly in a browser (`file://`): no server and
no build step. Fonts load from the jsDelivr CDN, so they need internet access. Start at
[index.html](index.html).

| Page | Shows |
| --- | --- |
| `home.html` | Home: the title menu beside the board, the player's chip, the X; Puzzles' row shows today's dots (`?today=N` solved of 4), `?locked=1` the puzzles solved before Today opens |
| `setup.html` | Home's setup for a game against the computer |
| `game.html` | The game screen on move 20 of one game: the way out, the catch, whose turn with the lookout, the hint and undo, the moves panel (a line on a phone, the last move in portrait); `?view=kings\|no\|asked\|giveup\|lost\|drawn` a kings' ending with the draw tile, the computer's refusal and offer, start over's give-up card, and the end's cards (`&friend=1` a friend's game) |
| `loading.html` | The game screen while the board is set up: the board's spot empty with a loading bar in it, five takes (`?take=a\|b\|c\|d\|e`: bar with text, bar alone, full-width at the board's lower edge, rounded bar with text under, as built and the default, and e, a with a faint track); `?p=0.4` freezes the fill, else it loops over 2 s |
| `puzzles.html` | The puzzles' library: the draughts switch, a Today row heading it with today's puzzles as tiles (each its level's bars and stars; How to play a tile beside the title, the last row in portrait; the moon when all are solved), and a row per theme; `?today=N` solved of 4, `?locked=1` (How to play first, Today locked last) |
| `puzzle.html` | One puzzle in the game's layout; `?daily=1` one of today's as built, today's dots over next (at its left in portrait) and the warm-up's or the stretch's word under the goal (none for the middle ones); `&slot=0..n-1` the one playing (1), `&n=4\|10` puzzles a day, `&lang=et` in Estonian |
| `results.html` | The results: the rating per draughts, by level, the games played |
| `replay.html` | A past game at move 20, its steps working, with the whole list and the marks' legend; the move shown (a faded piece where it started, its way in dots, the squares it stood on shaded) and the best move ( on the board only when asked for); `?ply=60` a king's capture; a desktop's larger column |
| `players.html` | Who's playing, over home |
| `settings.html` | Settings beside the preview board: Look, Sound (the Volume row: a speaker and a slider), and Game, with About at its foot; one group at a time on a phone; `?about=mac\|tablet\|a33\|iphone\|flat` About's card open with a device's sample values |
| `tutorial.html` | How to play: a new player's question (`?view=ask`), the steps played on the board (`?view=step&step=N`, `&v=intl\|brazilian\|russian`), and the end's ways on (`?view=done`) |

Every page takes the same few parameters, none needed:

- `?season=winter|spring|summer|autumn`: the photograph and the board's theme (else by
  the date).
- `?device=tablet|pixel|iphone`, or with `-portrait` (`pixel-portrait`): the screen at
  that device's size in dp with its safe area's insets, scaled to fit the window;
  `mac|desktop|ultrawide`, a MacBook's, a 27" screen's, and a 34" ultrawide's full window
  in a desktop's dp. Without it the window is the screen. A desktop's large window
  (`min-width: 1700px` and `min-height: 1000px`) lays out no wider than 1.9 times its
  height, as `gui::safe` does.

Each page lays out by the size of its screen with container queries: landscape, a phone
in landscape (under 600 dp tall), and portrait. They are drawn from the app's screens and
`docs/architecture/rendering.md`; where the two differ, the app is right.

## Starting a new prototype

Copy the page nearest the idea to a new name (`game-clock.html`), change it, and add a row
to the table above. Keep a take as a URL parameter of that page only while it is being
chosen; once it is chosen and built, fold the page back into the slim set: what was
built goes into the screen's page, and the take's page is removed (git history keeps
it). A prompt for a new page can say: "copy `prototypes/game.html` to
`prototypes/NAME.html` and change ...; keep to `draughts.css` and `draughts.js`".

A page is a `<main class="screen">` (the safe area, 24 px margins; `--w` and `--h` are
the room inside them), its own `<style>`, and a script that draws its boards and calls
`Draughts.init()` last. `<body data-screen="board">` puts the blurred photograph behind a
board, as the game does.

## Shared parts

- `draughts.css`: the four themes, the screen, glass, tiles, marks, and and the board.
- `draughts.js`: the device, the scene and glass, icons (`Draughts.icon(name)`, or
  `data-icon` on an element), `Draughts.board(el, opts)` (squares `a1`..`h8`, or `j10`
  with `n: 10`; `white`, `black`, `kings`, `selected`, `forced`, `targets`, `via`,
  `last`, `error`, `marks`), `Draughts.start(n)`, and one International game's moves
  with their marks (`Draughts.PLIES`, `Draughts.game(24 or 39)`, `Draughts.mark(k)`).

The board and its pieces are plain CSS (gradients and shadows), close to the app's look
but not a copy of its shaders: the prototypes settle layout and controls, and the app is
the reference for how the board looks. There is no raised board and no plain
background; check those in the app.
The photograph is the season's master in `design/backgrounds/masters/`.

## Keeping them fast

Moving or resizing a page must stay smooth, so:

- No CSS `filter` or `backdrop-filter`. Glass and the blurred backdrop are blurred once
  per page into small canvases, as natively, and each glass copies its part into a
  canvas of its own only when it moves.
- Nothing is painted pixel by pixel in script: the board and pieces are CSS.

Use only what the native renderer can draw cheaply: rounded rects, SDF discs,
gradients, the pre-blurred photograph for glass, and baked text
([rendering](../docs/architecture/rendering.md#look)).

## Checking a page

With the `agent-browser` CLI, in a session of its own, at the tablet (1280 × 800), a
phone's landscape (1066 × 480), and its portrait (480 × 1066):

```sh
agent-browser --session draughts set viewport 1066 480
agent-browser --session draughts open "file://$PWD/prototypes/game.html"
agent-browser --session draughts screenshot /tmp/game.png
agent-browser --session draughts errors
```

When handing a page off, include its full absolute `file:///` URL. Design boards from an
image model are kept out of git; their prompt is in git history at fed389b.

Takes that settled a screen were removed once built; they are in git history at
086f47d, which the decisions naming them point to.
