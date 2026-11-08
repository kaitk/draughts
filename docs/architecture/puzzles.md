# Puzzles

Puzzles are the package `puzzles/` (namespace `puzzles`): plain text read into a fixed
table at start, and an exact search over [`rules`](rules.md) that says whether a move
solves one. No graphics, tested headless in `test/puzzles/`. The screen that plays them
is in `shell/` ([rendering](rendering.md#controls)).

## The file

Each variant with puzzles has a file of its own: `puzzles/international.txt` holds the
International puzzles (International is the default game), and `puzzles/russian.txt`
the Russian ones ([Russian's set](#russians-set)). They are grouped by theme, each theme
a short curve of its own in three levels, easy to hardest (chosen 2026-11-09). The
themes are a fixed list in code (`puzzles::THEME_NAMES`, their icons and names in
`shell/picker.goose` and `strings/`), in the library's order, International's:

| Theme | What it teaches | Levels 1, 2, 3 |
|---|---|---|
| Learn | The rules in action: the first capture, backward, which capture isn't taken back, the king's long move and where it lands, the majority capture, passing the far row uncrowned. White to move. | 4, 4, 4 |
| Captures | Finding the multi-capture: the double whose last stop is safe, the route that takes most and lands safe, four jumps, the landing a king picks. | 4, 3, 3 |
| Crowning | To the far row: a capture that ends there, the breakthrough sacrifice, the breakthrough then the race, two men given for a crown. | 4, 4, 4 |
| Shots | Give men, then take more: give one, take three or four (level 1, two moves); the double sacrifice, give two, take four or five (level 2, three moves). | 10, 10, 0 |
| King shots | The king as a weapon: its zigzag for three or four, a shot that opens the long diagonal for it, the double sacrifice for the king. | 4, 3, 3 |

That is 64. 18 of them are black to move: none in Learn, where the child learns on
white, and between a quarter and a third of each other theme. Safe move, Endgame, and
Opening traps come later, as do Shots' level 3 (named shots and game finishes).

A puzzle is a block of `key value` lines, a blank line ending it; `#` starts a comment.

```text
variant international           the variant of the puzzles after it

# give one, take three
id 53                           stable, 1 to MAX_PUZZLES (150): stars are kept by it
theme shots                     learn, captures, crowning, shots, king-shots
level 1                         1 to 3, easy to hardest
goal take 2                     take N, crown, win, or safe
position W:W21,27,30,31,35,41,45,46,47:B1,4,6,7,11,13,16,23,33
line 21-17 11x22 27x18x29x38    the solver's move, the reply, and so on
source own, motif: give one, take three; found by tools/puzzles.goose find ...
```

- **id** stays with a puzzle for good, and a new puzzle takes the next unused one, so a
  child's stars stay with the puzzle that won them. Learn keeps the ids it had when the
  set was three tiers of ten; the new puzzles start at 31.
- **position** is PDN's FEN, as `rules::parse_fen` reads it; the side to move solves the
  puzzle.
- **line** is a solving line in PDN: moves `32-28`, captures by their stops `28x19x10`
  or only their ends `28x10` when that names one capture. A puzzle lists every move
  that is right at each of the solver's turns along its lines, each its own line, up to
  four. Its moves are the solver's moves in its longest line.
- **source** names the motif or the game. Every position is our own, none copied from
  a collection, so none carries another's license: Learn's composed by hand, the
  others found by `tools/puzzles.goose find` from game-like camps for the motif wanted
  and each verified by the solver, the computer player, and `test/perft.py`. The motifs
  and their order come from the courses that teach them (FMJD's courses, GoDraughts'
  course order, the named shots).

The files are built into the program (`embed_file`). The set of the player's draughts
(`puzzles::set_of`) is read at start into `puzzles::all`, a fixed table, and read again
only when the player's draughts change to another set, on home (below); nothing is read
or allocated while puzzles are shown.

## Russian's set

`puzzles/russian.txt` is composed for Russian's own rules, not ported from
International's ([rules](rules.md#variants)): men capture backward, no capture has to
take the most, so the child picks among captures, and a man crowned mid-capture goes on
capturing as a king, which makes the Russian school's shots through the crowning square.
The motifs come from the Russian school's programmes for juniors (the shot onto and
through the crowning square, the free tempo); every position is our own, found by
`tools/puzzles.goose find --variant russian` from game-like camps but the first, made by
hand. Squares are written a1..h8, moves `c3-d4`, captures by their stops `c3:e5:g3`.

| Theme | What it teaches | Levels 1, 2, 3 |
|---|---|---|
| Learn | Russian's rules in action: the first capture, the backward one, two men that can take and the one not taken back, the flying king's landing, the free choice of capture (the double where one is wanted, the single where the double is answered by a double), a capture going on backward, a man crowned mid-capture going on as a king and on with a king's long jump, the king's zigzag, and a sacrifice that opens the way to crown. White to move. | 4, 4, 4 |
| Captures | The double, not the single, among several captures; the route of three that lands safe, among up to five; four jumps, and a man crowned on the far row taking two more as a king. | 4, 3, 3 |
| Crowning | A capture that ends on the far row, or crowns on the way and goes on; the breakthrough sacrifice; two men given for a crown. | 4, 3, 3 |
| Shots | Give one, take three, onto the crowning square too (level 1, two moves); give one and take four through the crowning square, and the free tempo, a quiet move after which every move the other side has gives a man (level 2); give two, then take four or five through the crowning square (level 3, three moves). | 6, 5, 3 |

That is 46, 12 of them black to move (35% of the 34 outside Learn). The library shows
only the themes a set has, so a Russian player sees four rows. A Brazilian player is
shown International's set. Russian's ids are its own, from 1.

## Goals

A move is right when it reaches the goal, or keeps it within reach of the moves left
whatever the other side replies; any line that does counts, listed or not. The search
counts pieces, nothing else, and plays out the captures that are due after a move, since
captures are forced.

- **take N**: the solver's move is a capture, and once the captures due after it are
  played out the solver has taken N more pieces than it has lost. The goal is the
  balance, so a shot that gives a man and takes three is "take 2", which the screen
  says as "Win 2 men" ("Win a man" for one; chosen 2026-11-09 over "Capture 2", which
  a child counting the three taken reads wrong). Every line ends quiet (Checks), so the
  balance is the men won, with nothing still to be taken back.
- **crown**: the move makes a king that the reply doesn't take.
- **win**: the other side is left with no move: everything taken or blocked. Leaving it
  no move reaches any goal.
- **safe**: nothing is lost over the next two plies (a reply and an answer), the
  captures due after them played out. A safe puzzle has one such move.

The other side's reply, when the puzzle goes on, is the line's when the child has played
the line so far, and otherwise the reply after which the solver needs the most moves.
The piece the hint shows is the line's next move's, or the first right move's off the
lines.

The search keeps each position's moves on one fixed stack in a `puzzles::Solver` the
caller owns, so it allocates nothing and needs little native stack. The 64 puzzles cost
at most 415 positions to check (a king shot of three moves), 0.2 ms built;
the longest line is five plies, within `MAX_PLIES` (8). Russian's 46 cost at most 161
(a shot of three moves), their longest line five plies too.

## The screen

Home's puzzles opens the picker (`shell/picker.goose`): a library of the themes, a row
each with its count solved, and a row opens the theme's page, its puzzles as tiles in
its levels. A tile there opens the puzzle (`shell/puzzle.goose`), which the shell holds
with its own board and solver beside the game, so a game in progress is kept. A puzzle
for black is played on the turned board, as against the computer, and its panel says
whose puzzle it is. Their look is in [rendering](rendering.md#controls).

- **Stars**: three are at stake. Each miss puts one out, down to one: a wrong move, which
  plays and then slides back by itself, a tap the board flashes as a mistake, or a
  capture left partway (below). A puzzle solved keeps the most stars it has won. Start
  over begins the puzzle again with the misses kept, or afresh once it is solved.
- **Captures of many jumps** are made by hand (2026-11-08, the user: children often
  make them jump by jump). A tap or a drop on a stop leaves the piece waiting there for
  the next jump; it never plays the rest of the way by itself, which would solve the
  puzzle for the child. A tap or a drop on the last square plays the capture when one
  capture alone goes there (or it ends just after the stops made), so the capture can
  still be made in one go. Stops aren't misses; the capture is judged once played
  ([rendering](rendering.md#board-and-pieces)). A capture must take every piece it can,
  so one left partway is no move: while the piece waits, next wakes (unlit), and
  pressed it is a miss, the piece sliding back from its stop with the red ring and "try
  again", as after a wrong move. Next is the one way to say a move is done, so it is
  where stopping short is caught; leaving for the puzzles, settings, or start over
  isn't an answer and costs nothing. A game keeps its quicker way: a stop that only one
  capture goes on through plays it whole, since nothing there is judged.
- **Help**: after two misses the piece of the next right move glows; there is no hint
  tile. No puzzle shows a selected piece's targets, whatever the move hints setting: the
  child is to find the move ([product](../product.md), 2026-11-08). The selection, the
  glow, and a wrong move's flash still show.
- **Themes**: Learn is open; the others open once half of Learn is solved (2026-11-08),
  and inside a theme everything is open. A theme's page lights its first puzzle without
  stars.
- **Next** opens the puzzle after it in its theme, and after the theme's last the
  library. Until the puzzle is solved it is dim and takes no tap, except while a
  capture waits partway, above. Back on a theme's page goes to the library.
- **Kept**: the stars in the player's file (`player-N.txt`,
  [players](README.md#players)), `stars.international = 1:3 4:2` by puzzle id, written
  when a puzzle is solved; each player has their own. Ids are a variant's own, so the key
  names the variant (`stars.russian` for Russian's set, beside International's); a
  file's older `stars` is read as International's. Home's count is over the set: the
  stars of an id no longer in the file aren't counted. A puzzle under way isn't saved
  with the game: when the app is paused on one, it comes back on the picker.
- **The set** is that of the player's draughts, the setup's choice (`puzzles::set_of`).
  The draughts change in home's setup, in settings, or with the player; home, where
  every way to the puzzles starts, reads the other set then (`shell::sync_puzzles`), and
  the picker starts at its library. A puzzle or the picker reached from settings keeps
  the set it had until home.

## Checks

`puzzles::check` (run by `test/puzzles/set.goose` and `russian_set.goose` on every
puzzle, and by `tools/puzzles.goose`) refuses a puzzle when:

- a line's move isn't right, or a line's last move doesn't reach the goal, or an earlier
  one does;
- the goal can't be forced within the puzzle's moves, or can be in fewer;
- at any of the solver's turns along a line, a move that is right there isn't a line's
  move there: the file lists every way in and every way on, so the screen's hint and
  replies follow a line whichever right move the child finds;
- a line doesn't end quiet: the other side has a capture due after it, or one of its
  replies gives the solver a capture. A puzzle that stops with a capture on the board
  shows the child more to play than it let them (2026-11-08);
- a take's line wins more or fewer than its count, or a crown's line ends without a
  king made (a goal reached only by leaving the other side no move);
- along a line, another legal move goes from and to the same squares, which a tap
  couldn't tell apart;
- it has no source.

`tools/puzzles.goose` adds the computer player's view at full skill: its root scores,
whether the moves it rates best solve the puzzle, a second engine sharing only the
rules with the solver, and whether it scores a right first move as losing material
(under −50, half a man). It plays for material, so it is not asked about crowning.
`test/perft.py puzzles international puzzles/international.txt` (and `russian
puzzles/russian.txt`) plays every line with the independent generator, checking each
move and each position's moves against `build/perft`; for Russian, which has no
published perft table, it is the only independent check. `scripts/test.sh` runs it on
both files.

`tools/puzzles.goose try FEN GOAL MOVES` shows the moves that are right, the line the
screen would play, and what the checks say of it. `find SIDE GOAL MOVES MINE THEIRS
COUNT [SEED [KINGS]]` turns up positions to compose from: the solver's and the other
side's men placed in camps as in a game (each next man beside or behind one of its own,
on its own side of the board), some of the solver's made kings, with exactly one right
move at each of the solver's turns, every check passed, and the game going on after the
line; a take in more moves must be a shot, its first move answered by a capture. For
black it finds the puzzle for white and turns the board round, checking it again. Both
take `--variant NAME` (International by default), and find `--rows N`, the rows from its
own back row a camp spans (the board's size less 3 by default), and `--tempo`, which
asks a take in more moves to start with a free tempo instead: a quiet move that no reply
captures after, every reply giving men.
