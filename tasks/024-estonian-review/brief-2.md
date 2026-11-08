# Brief: review the Estonian strings of Draughts, second pass

The second review (2026-11-08), after puzzles came in: the first (`brief.md`) read the
strings as they were at 01:55 that day. Strings added or changed since were never
reviewed, and two were found wrong in use ("Löö 2", "Ära anna nuppu"), so this pass
reads every key again with the new ones marked. What follows is the prompt as Gemini
got it.

---

You are reviewing the Estonian translation of a small app's user interface. Answer in
text only: you need no tools and no files, since everything is below. Write your answer
in the format at the end.

## The app and who uses it

Draughts is a draughts (checkers) app for a tablet, made for children in Estonia,
of about 5 to 8: they play against each other or the computer, and solve puzzles. The app
is usable without reading: every control is an icon with a word beside it, so the word
helps a parent reading it aloud, or a child starting to read. English is the default
language; Estonian is a translation file with the same keys.

What the words should be:

- Short, warm, plain Estonian that a young child understands when it is read aloud, the
  way a parent would say it at a board game at home.
- No anglicisms where Estonian has its own word, and no technical words (no "režiim",
  no "seadistus" where a plainer word works).
- The same Estonian word for the same thing everywhere (one word for a king, one for a
  move, one for the pieces, one for capturing).
- Positive instructions where they can be: a goal says what to do, not what to avoid.
- The draughts words as Estonians say them at home and teach children. The official
  rules of Eesti Kabeliit (2021) write kabend, kivi, kabe (the king), and lööma; the
  app keeps to the plainer words everyone knows, and these are settled:
  - kabe: draughts (the game); kabelaud: the board
  - nupp, nupud: a piece, the pieces; valged / mustad: the white / black side, always
    plural ("Valgete käik", "Valged võitsid")
  - tamm, tammid: a king (gen. tammi); tammiks saama: to be crowned
  - võtma: to capture ("võtab nupu", "Võta 2"). Not lööma: "Löö 2" was found bad in use
    (a child hears "hit"), and võtma is the everyday board-game word.
  - käik, käigud: a move; käima: to move
  - vene kabe (8 × 8), rahvusvaheline kabe (10 × 10), Brasiilia kabe (8 × 8)

Keep a string as it is unless it is wrong, unnatural, or too long for its place. A good
string that you would merely phrase differently stays. Never change a key, and give
every key an answer.

## Where the strings show

- **Home**, a title menu: the wordmark (the app's name, large), then rows with an icon
  and a word in 30 px: continue, a friend (play each other), the computer (with the kept
  level as a dim lowercase note at the row's right), puzzles (with the stars won as a dim
  note at the right, "12 / 90"), settings. The row's word has about 270 dp.
- **A new game's setup**, opened from home's "a friend" or "the computer": a title row
  (back, an icon, and the row's own word again), then groups of tiles, each group with a
  small dim name above it (17 px): which draughts (three tiles with a small board, the
  variant's name in 20 px and its size under it in 17 px), the level (three tiles,
  20 px), your pieces (white or black), the clock (a stopwatch over "no clock"; "5 min"
  over "+3 s a move"; "10 min" over "+5 s a move"), then a big play button (30 px).
- **The game screen**: the board between two panels. Left panel: tiles with an icon and
  a word in 24 px: home, settings, and start over, about 140 dp for the word. Right
  panel: whose turn it is (a piece over the words, 24 px, 200 dp), or two clocks, and
  take back, a tall tile (icon over word, 24 px). Once a side has won, the turn's words
  say who won.
- **Settings**: the title, the languages, then two groups: **Game** (which draughts a
  new game starts on; move hints: mistakes only or all moves; the tutorial: learn the
  moves) and **Look** (the background: a tile that picks the season's photograph from
  today's date, then the four seasons' photographs; the board, flat (2D) or raised
  (3D); kings, drawn as a crown or as a stack of two discs, or automatic: the crown on
  the flat board and the stack on the raised one). Each setting's name is a small dim
  word (17 px) in a 120 dp column at the left of its row of tiles. A tile's word is
  20 px; the whole row must fit on one line, so keep tile words near the English length.
- **The puzzle picker**: three tiers of ten puzzles, each tile with 0 to 3 stars. No
  words but the title.
- **A puzzle**: the game screen's layout. On the right, the goal: its icon (a target for
  capturing, a crown, a shield for the safe move) over its words in 30 px, which drop to
  24, 20, or 17 px when they don't fit about 200 dp (about 14 letters at 30 px). Under
  it the three stars at stake, and at the bottom a tall tile "next", dim until the
  puzzle is solved. A wrong move slides back and the goal's words give way for 2 s to
  "try again" in a red pill (24 px, about 128 dp for the words, else 20 px). Solved,
  the goal's words become "solved", the stars won pop in, and "next" lights.

### What each puzzle goal means

The child plays the side to move. The goal is all the child is told:

- **take N** ("Capture {}", `{}` is the number): capture so that, after the forced
  captures are played out, the child has taken N more pieces than it lost. A shot that
  gives one piece and then takes three is "Capture 2". Today's puzzles say 1 to 4.
- **crown** ("Become a king"): make a king (a piece reaches the far row) that the other
  side can't take straight away.
- **win** ("Win the game"): leave the other side no move, everything taken or blocked.
- **safe** ("Stay safe"): one of your pieces is attacked, and exactly one move saves it:
  after that move the other side can take nothing over the next reply and answer. Every
  other move loses a piece. The icon is a shield. The current Estonian "Ära anna nuppu"
  ("don't give a piece") was found bad in use.

## The strings

Room is how many characters fit, at the face's size, roughly (lowercase letters average
8 dp at 17 px, 9.4 at 20, 11.3 at 24, 14.1 at 30). "Grows" means the tile widens to fit,
within the row's limit. **New** marks a string never reviewed before (added or changed
after the first review); read those most carefully. The others were reviewed once; say
if they are wrong, but don't rephrase a good one.

| Key | English | Estonian now | New | Where | Face | Room (chars) |
| --- | --- | --- | --- | --- | --- | --- |
| `language.name` | English | Eesti | | Settings: this language's own name | 20 px | grows |
| `app.name` | Draughts | Kabe | | Home's wordmark; the window title | 64 px | about 7 |
| `home.continue` | Continue | Jätka | | Home row: continue the saved game | 30 px | about 19 |
| `home.friend` | A friend | Sõbraga | | Home row: play a friend on one tablet; the setup's title | 30 px | about 17 |
| `home.computer` | The computer | Arvutiga | | Home row: play the computer, level note at right; the setup's title | 30 px | about 12 |
| `home.puzzles` | Puzzles | Ülesanded | | Home row: the puzzles; the picker's title; the puzzle's left panel tile that goes back to the picker (24 px, 140 dp) | 30 px | about 12 |
| `home.settings` | Settings | Seaded | | Home row; game panel tile; settings title | 24 px | about 12 |
| `level.easy` | easy | kerge | | Home: dim note at the computer row's right, lowercase | 17 px | about 11 |
| `level.medium` | medium | keskmine | | as above | 17 px | about 11 |
| `level.hard` | hard | raske | | as above | 17 px | about 11 |
| `settings.game` | Game | Mäng | | Settings: the game group's title | 24 px | about 20 |
| `settings.look` | Look | Välimus | | Settings: the look group's title | 24 px | about 20 |
| `settings.tutorial` | Tutorial | Õpetus | | Settings: a setting's name (the tutorial) | 17 px | about 15 |
| `settings.background` | Background | Taust | | Settings: a setting's name (the photograph behind the board) | 17 px | about 15 |
| `settings.by_date` | By date | Kuupäev | new | Settings: the background's first tile, the season picked from today's date | 20 px | grows (keep near 7) |
| `settings.board` | Board | Kabelaud | | Settings: a setting's name (flat or raised board) | 17 px | about 15 |
| `settings.hints` | Move hints | Vihjed | | Settings: a setting's name (the move hints) | 17 px | about 15 |
| `settings.kings` | Kings | Tammi kuju | new | Settings: a setting's name: how kings are drawn (crown, stack, or by the board) | 17 px | about 15 |
| `season.winter` | Winter | Talv | | Settings: background thumbnail's name | 17 px | about 7 |
| `season.spring` | Spring | Kevad | | as above | 17 px | about 7 |
| `season.summer` | Summer | Suvi | | as above | 17 px | about 7 |
| `season.autumn` | Autumn | Sügis | | as above | 17 px | about 7 |
| `hints.mistakes` | Mistakes only | Ainult vead | | Settings tile: hints show only a wrong move | 20 px | grows |
| `hints.moves` | All moves | Kõik käigud | | Settings tile: hints show every move of the selected piece | 20 px | grows |
| `board.flat` | Flat | Lame | | Settings tile: the flat board | 20 px | grows |
| `board.flat_note` | 2D | 2D | | Note under "flat" | 17 px | grows |
| `board.raised` | Raised | Ruumiline | | Settings tile: the 3D board | 20 px | grows |
| `board.raised_note` | 3D | 3D | | Note under "raised" | 17 px | grows |
| `kings.auto` | Auto | Laua järgi | new | Settings tile: kings drawn by the board (crown on flat, stack on raised); beside "Kroon" and "Virn" | 20 px | grows (keep near 10; the row must fit one line) |
| `kings.crown` | Crown | Kroon | | Settings tile: kings drawn with a crown | 20 px | grows |
| `kings.stack` | Stack | Virn | | Settings tile: kings drawn as two discs stacked | 20 px | grows |
| `tutorial.learn` | Learn the moves | Õpi käike | | Settings tile beside a bulb: start the tutorial | 20 px | grows |
| `game.home` | Home | Koju | | Game panel tile with a house: go home | 24 px | about 12 |
| `game.start_over` | Start over | Alusta uuesti | | Game and puzzle panel tile: restart from the start | 24 px | about 12 |
| `game.take_back` | Take back | Võta tagasi | | Game panel tall tile with an undo arrow: take back a move | 24 px | about 17 |
| `turn.white` | White's turn | Valgete käik | | Game panel, under the piece to move | 24 px | about 17 |
| `turn.black` | Black's turn | Mustade käik | | as above | 24 px | about 17 |
| `won.white` | White wins | Valged võitsid | | Game panel, under the winner's piece | 24 px | about 17 |
| `won.black` | Black wins | Mustad võitsid | | as above | 24 px | about 17 |
| `setup.draughts` | Draughts | Kabe | | Setup group name over the variants; a setting's name in Settings (which draughts a new game starts on) | 17 px | about 15 |
| `setup.level` | Level | Tase | | Setup group name over the levels | 17 px | about 40 |
| `setup.color` | Your pieces | Sinu nupud | | Setup group name over white and black, against the computer | 17 px | about 40 |
| `setup.clock` | Clock | Kell | | Setup group name over the clock choices | 17 px | about 40 |
| `setup.play` | Play | Mängi | | Setup's big button: start the game | 30 px | about 20 |
| `variant.international` | International | Rahvusvaheline | | Setup and Settings tile: international draughts, 10 × 10 | 20 px | 14 fits |
| `variant.brazilian` | Brazilian | Brasiilia | | as above: Brazilian draughts, 8 × 8 | 20 px | about 11 |
| `variant.russian` | Russian | Vene | | as above: Russian draughts, 8 × 8 | 20 px | about 11 |
| `size.10` | 10 × 10 | 10 × 10 | | Note under the variant | 17 px | about 13 |
| `size.8` | 8 × 8 | 8 × 8 | | Note under the variant | 17 px | about 13 |
| `pick.easy` | Easy | Kerge | | Setup level tile | 20 px | about 11 |
| `pick.medium` | Medium | Keskmine | | Setup level tile | 20 px | about 11 |
| `pick.hard` | Hard | Raske | | Setup level tile | 20 px | about 11 |
| `color.white` | White | Valged | | Setup tile under "your pieces": play the white pieces | 20 px | about 17 |
| `color.black` | Black | Mustad | | as above: play the black pieces | 20 px | about 17 |
| `clock.none` | No clock | Kellata | | Setup clock tile, under a stopwatch: no time limit | 17 px | about 13 |
| `clock.blitz` | 5 min | 5 min | | Setup clock tile: five minutes each | 20 px | about 11 |
| `clock.blitz_note` | +3 s a move | +3 s käigule | | Note under it: three seconds added per move | 17 px | about 13 |
| `clock.rapid` | 10 min | 10 min | | Setup clock tile: ten minutes each | 20 px | about 11 |
| `clock.rapid_note` | +5 s a move | +5 s käigule | | Note under it: five seconds added per move | 17 px | about 13 |
| `puzzles.stars` | {} / {} | {} / {} | new | Home: dim note at the puzzles row's right, stars won of all ("12 / 90") | 17 px | about 9 |
| `puzzle.next` | Next | Edasi | new | Puzzle: the tall tile under an arrow, opens the next puzzle once this one is solved | 24 px | about 17 |
| `puzzle.try_again` | Try again | Proovi uuesti | new | Puzzle: in a red pill for 2 s after a wrong move, which slid back | 24 px | about 11 (else 20 px: 13) |
| `puzzle.solved` | Solved | Lahendatud | new | Puzzle: replaces the goal's words once solved, as the stars pop in | 30 px | about 14 |
| `goal.take` | Capture {} | Võta {} | new | Puzzle goal: capture N more than you lose (see the goals above); {} is a digit | 30 px | about 14 |
| `goal.crown` | Become a king | Saa tammiks | new | Puzzle goal: make a king the other side can't take at once | 30 px | about 14 |
| `goal.win` | Win the game | Võida mäng | new | Puzzle goal: leave the other side no move | 30 px | about 14 |
| `goal.safe` | Stay safe | Ära anna nuppu | new | Puzzle goal: one of your pieces is attacked; find the one move after which you lose nothing. Found bad in use. | 30 px | about 14 |

## Your answer

For every key, in the table's order, one line:

```
key | Estonian now | proposal or "keep" | reason in one line
```

The reason says what is wrong (wrong meaning, wrong term, unnatural, too long for its
room, inconsistent with another key) or, for "keep", why it is right. For `goal.safe`
give your best proposal and, in the notes, two or three others with what each says to a
child. After the lines, add at most five short notes on anything a native speaker
should decide (two good options, a term you are unsure of). Write nothing else.
