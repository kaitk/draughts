# Brief: review the Estonian strings of Draughts

You are reviewing the Estonian translation of a small app's user interface. Answer in
text only: you need no tools and no files, since everything is below. Write your answer
in the format at the end.

## The app and who uses it

Draughts is a draughts (checkers) app for a tablet, made for children in Estonia,
of about 5 to 8: they play against each other or the computer, and later solve puzzles.
The app is usable without reading: every control is an icon with a word beside it, so
the word helps a parent reading it aloud, or a child starting to read. English is the
default language; Estonian is a translation file with the same keys.

What the words should be:

- Short, warm, plain Estonian that a young child understands when it is read aloud, the
  way a parent would say it at a board game.
- No anglicisms where Estonian has its own word, and no technical words (no "režiim",
  no "seadistus" where a plainer word works).
- The same Estonian word for the same thing everywhere (one word for a king, one for a
  move, one for the pieces).
- The right draughts terms, as Estonian draughts players and clubs (Eesti Kabeliit) use
  them:
  - kabe: draughts (the game); kabelaud: the board
  - nupp, nupud: a man, the pieces; valged / mustad: the white / black pieces (as a
    side: "valged alustavad")
  - tamm, tammid: a king (gen. tammi); tammiks saama: to be crowned
  - lööma, löömine: to capture, capturing (lööb nupu); käik, käigud: a move; käima: to
    move ("valged käivad")
  - vene kabe (Russian draughts, 8 × 8), rahvusvaheline kabe (international, 10 × 10),
    Brasiilia kabe (Brazilian, 8 × 8)
  - välkkabe: blitz draughts; kiirkabe: rapid draughts

Keep a string as it is unless it is wrong, unnatural, or too long for its place. A good
string that you would merely phrase differently stays. Never change a key, and give
every key an answer.

## Where the strings show

- **Home**, a title menu: the wordmark (the app's name, large), then rows with an icon
  and a word in 30 px: continue, a friend (play each other), the computer (with the kept
  level as a dim lowercase note at the row's right), puzzles, settings. The row's word
  has about 270 dp; on the computer's row the level note takes part of that.
- **A new game's setup**, opened from home's "a friend" or "the computer": a title row
  (back, an icon, and the row's own word again), then groups of tiles, each group with a
  small dim name above it (17 px): which draughts (three tiles with a small board, the
  variant's name in 20 px and its size under it in 17 px), the level (three tiles,
  20 px, with one to three dots), your pieces (two tiles, white or black, each showing a
  piece), the clock (three tiles: a stopwatch over "no clock" in 17 px; "5 min" in
  20 px over "+3 s a move" in 17 px; "10 min" over "+5 s a move"), then a big play
  button (30 px). In landscape a tile three across is 113 dp wide; a word wider than
  105 dp at 20 px falls back to 17 px.
- **The game screen**: the board between two panels. Left panel (landscape): tiles with
  an icon and a word in 24 px: home, settings, and start over, with about 140 dp for the
  word. Right panel: whose turn it is (a piece over the words, 24 px, 200 dp), or two
  clocks, and take back, a tall tile (icon over word, 24 px, 200 dp). Once a side has
  won, the turn's words say who won. In portrait the left panel is a bar of three tiles
  above the board (each about 225 dp) and the right panel is below it.
- **Settings**: back and the title "Settings" (30 px), and the languages, each named in
  itself. Then two glass groups, each with an icon and a title in 24 px: **Game** (which
  draughts a new game starts on; move hints: mistakes only or all moves; the tutorial:
  one tile, learn the moves, not yet working) and **Look** (the background: a tile "by
  the date" that picks the season's photograph from today's date, then the four seasons'
  photographs, each a 62 × 40 thumbnail with its name under it in 17 px; the board, flat
  (2D) or raised (3D); kings, drawn as a crown (on a flat board) or as a stack of two
  discs (raised), or automatic: crown on the flat board, stack on the raised one). Each
  setting's name is a small dim word (17 px) in a 120 dp column at the left of its
  tiles. A tile's word is 20 px, and the tile grows to fit it, but the whole group must
  fit 55% of the screen, so a long word makes the rows wrap: keep these near the
  English's length.

Move hints: "all moves" shows where the selected piece can go; "mistakes only" shows
nothing until a move is wrong, then marks it and why (the piece that must capture
pulses).

## The strings

Room is how many characters fit, at the face's size, roughly (lowercase letters average
8 dp at 17 px, 9.4 at 20, 11.3 at 24, 14.1 at 30). "Grows" means the tile widens to fit,
within the soft limit above.

| Key | English | Estonian now | Where | Face | Room (chars) |
| --- | --- | --- | --- | --- | --- |
| `language.name` | English | Eesti | Settings title row: this language's own name | 20 px | grows |
| `app.name` | Draughts | Kabe | Home's wordmark; the window title | 64 px | about 7 |
| `home.continue` | Continue | Jätka | Home row: continue the saved game | 30 px | about 19 |
| `home.friend` | A friend | Sõbraga | Home row: play a friend on one tablet; the setup's title | 30 px | about 17 |
| `home.computer` | The computer | Arvutiga | Home row: play the computer, level note at right; the setup's title | 30 px | about 12 |
| `home.puzzles` | Puzzles | Ülesanded | Home row: the puzzles | 30 px | about 19 |
| `home.settings` | Settings | Seaded | Home row (30 px); game panel tile (24 px, 140 dp); settings title | 24 px | about 12 |
| `level.easy` | easy | kerge | Home: dim note at the computer row's right, lowercase | 17 px | about 11 |
| `level.medium` | medium | keskmine | as above | 17 px | about 11 |
| `level.hard` | hard | raske | as above | 17 px | about 11 |
| `settings.game` | Game | Mäng | Settings: the game group's title | 24 px | about 20 |
| `settings.look` | Look | Välimus | Settings: the look group's title | 24 px | about 20 |
| `settings.tutorial` | Tutorial | Õpetus | Settings: a setting's name (the tutorial) | 17 px | about 15 |
| `settings.background` | Background | Taust | Settings: a setting's name (the photograph behind the board) | 17 px | about 15 |
| `settings.by_date` | By the date | Kuupäeva järgi | Settings: background tile, the season from today's date | 17 px | grows |
| `settings.board` | Board | Laud | Settings: a setting's name (flat or raised board) | 17 px | about 15 |
| `settings.hints` | Move hints | Vihjed | Settings: a setting's name (the move hints) | 17 px | about 15 |
| `settings.kings` | Kings | Tammid | Settings: a setting's name (how kings are drawn) | 17 px | about 15 |
| `season.winter` | Winter | Talv | Settings: background thumbnail's name | 17 px | grows (7 fit) |
| `season.spring` | Spring | Kevad | as above | 17 px | grows (7 fit) |
| `season.summer` | Summer | Suvi | as above | 17 px | grows (7 fit) |
| `season.autumn` | Autumn | Sügis | as above | 17 px | grows (7 fit) |
| `hints.mistakes` | Mistakes only | Ainult vead | Settings tile: hints show only a wrong move | 20 px | grows |
| `hints.moves` | All moves | Kõik käigud | Settings tile: hints show every move of the selected piece | 20 px | grows |
| `board.flat` | Flat | Lame | Settings tile: the flat board | 20 px | grows |
| `board.flat_note` | 2D | 2D | Settings tile's note under "flat" | 17 px | grows |
| `board.raised` | Raised | Ruumiline | Settings tile: the 3D board | 20 px | grows |
| `board.raised_note` | 3D | 3D | Settings tile's note under "raised" | 17 px | grows |
| `kings.auto` | Auto | Automaatne | Settings tile: kings chosen by the board | 20 px | grows |
| `kings.auto_note` | crown flat, stack raised | 2D kroon, 3D virn | Settings tile's note under "auto": a crown on the flat board, a stack on the raised | 17 px | grows |
| `kings.crown` | Crown | Kroon | Settings tile: kings drawn with a crown | 20 px | grows |
| `kings.stack` | Stack | Virn | Settings tile: kings drawn as two discs stacked | 20 px | grows |
| `tutorial.learn` | Learn the moves | Õpi käike | Settings tile beside a bulb: start the tutorial | 20 px | grows |
| `game.home` | Home | Koju | Game panel tile with a house: go home | 24 px | about 12 |
| `game.start_over` | Start over | Alusta uuesti | Game panel tile: restart this game from its start | 24 px | about 12 |
| `game.take_back` | Take back | Võta tagasi | Game panel tall tile with an undo arrow: take back a move | 24 px | about 17 |
| `turn.white` | White's turn | Valge käik | Game panel, under the piece to move | 24 px | about 17 |
| `turn.black` | Black's turn | Musta käik | as above | 24 px | about 17 |
| `won.white` | White wins | Valge võitis | Game panel, under the winner's piece, once the game is won | 24 px | about 17 |
| `won.black` | Black wins | Must võitis | as above | 24 px | about 17 |
| `setup.draughts` | Draughts | Kabe | Setup group name over the variants; also a setting's name in Settings (which draughts a new game starts on) | 17 px | about 15 |
| `setup.level` | Level | Tase | Setup group name over the levels | 17 px | about 40 |
| `setup.color` | Your pieces | Sinu nupud | Setup group name over white and black, against the computer | 17 px | about 40 |
| `setup.clock` | Clock | Kell | Setup group name over the clock choices | 17 px | about 40 |
| `setup.play` | Play | Mängi | Setup's big button: start the game | 30 px | about 20 |
| `variant.international` | International | Rahvusvaheline | Setup tile and Settings tile: international draughts, 10 × 10 | 20 px | about 11 (17 px fallback: 13) |
| `variant.brazilian` | Brazilian | Brasiilia | as above: Brazilian draughts, 8 × 8 | 20 px | about 11 |
| `variant.russian` | Russian | Vene | as above: Russian draughts, 8 × 8 | 20 px | about 11 |
| `size.10` | 10 × 10 | 10 × 10 | Note under the variant | 17 px | about 13 |
| `size.8` | 8 × 8 | 8 × 8 | Note under the variant | 17 px | about 13 |
| `pick.easy` | Easy | Kerge | Setup level tile | 20 px | about 11 |
| `pick.medium` | Medium | Keskmine | Setup level tile | 20 px | about 11 |
| `pick.hard` | Hard | Raske | Setup level tile | 20 px | about 11 |
| `color.white` | White | Valged | Setup tile under "your pieces": play the white pieces | 20 px | about 17 |
| `color.black` | Black | Mustad | as above: play the black pieces | 20 px | about 17 |
| `clock.none` | No clock | Kellata | Setup clock tile, under a stopwatch: no time limit | 17 px | about 13 |
| `clock.blitz` | 5 min | 5 min | Setup clock tile: five minutes each | 20 px | about 11 |
| `clock.blitz_note` | +3 s a move | +3 s käigu eest | Note under it: three seconds added per move | 17 px | about 13 |
| `clock.rapid` | 10 min | 10 min | Setup clock tile: ten minutes each | 20 px | about 11 |
| `clock.rapid_note` | +5 s a move | +5 s käigu eest | Note under it: five seconds added per move | 17 px | about 13 |

Measured now, only `variant.international` ("Rahvusvaheline", 14 letters) is over its
room at 20 px: it falls back to 17 px and just fits. `game.start_over` ("Alusta
uuesti") fills its 140 dp to within 10 dp.

## Your answer

For every key, in the table's order, one line:

```
key | Estonian now | proposal or "keep" | reason in one line
```

The reason says what is wrong (wrong meaning, wrong term, unnatural, too long for its
room, inconsistent with another key) or, for "keep", why it is right. After the lines,
add at most five short notes on anything a native speaker should decide (two good
options, a term you are unsure of). Write nothing else.
