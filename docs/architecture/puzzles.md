# Puzzles

Puzzles are the package `puzzles/` (namespace `puzzles`): plain text read into a fixed
table at start, and an exact search over [`rules`](rules.md) that says whether a move
solves one. No graphics, tested headless in `test/puzzles/`. The screen that plays them
is in `shell/` ([rendering](rendering.md#controls)).

## The file

Each variant with puzzles has a file of its own: `src/puzzles/international.txt` holds the
International puzzles (International is the default game), `src/puzzles/russian.txt`
the Russian ones ([Russian's set](#russians-set)), and `src/puzzles/brazilian.txt` the
Brazilian ones ([Brazilian's set](#brazilians-set)). They are grouped by theme, each theme
a short curve of its own in three levels, easy to hardest. The
themes are a fixed list in code (`puzzles::THEME_NAMES`, their icons and names in
`src/shell/picker.goose` and `strings/`), in the library's order, International's:

| Theme | What it teaches | Levels 1, 2, 3 |
|---|---|---|
| Learn | The rules in action: the first capture, backward, which capture isn't taken back, the king's long move and where it lands, the majority capture, passing the far row uncrowned. White to move. | 4, 4, 4 |
| Captures | Finding the multi-capture: the double whose last stop is safe, the route that takes most and lands safe, four jumps, the landing a king picks. | 4, 3, 3 |
| Crowning | To the far row: a capture that ends there, the breakthrough sacrifice, the breakthrough then the race, two men given for a crown. | 4, 4, 4 |
| Shots | Give men, then take more: give one, take three or four (level 1, two moves); the double sacrifice, give two, take four or five (level 2, three moves). | 10, 10, 0 |
| King shots | The king as a weapon: its zigzag for three or four, a shot that opens the long diagonal for it, the double sacrifice for the king. | 4, 3, 3 |
| Safe move | The one move that doesn't lose to a shot: each threat a give-one-take-two the other side would play, every other move allowing it; levels by how many moves there are to weigh (three, five to seven, eight to twelve). White to move. | 2, 4, 4 |

That is 74. 18 of them are black to move: none in Learn or Safe move, and between a
quarter and a third of each other theme. Endgame and Opening traps come later, as do
Shots' level 3 (named shots and game finishes).

A puzzle is a block of `key value` lines, a blank line ending it; `#` starts a comment.

```text
variant international           the variant of the puzzles after it

# give one, take three
id 53                           stable, 1 to MAX_PUZZLES (150): stars are kept by it
theme shots                     learn, captures, crowning, shots, king-shots, safe-move
level 1                         1 to 3, easy to hardest
goal take 2                     take N, crown, win, or safe
position W:W21,27,30,31,35,41,45,46,47:B1,4,6,7,11,13,16,23,33
line 21-17 11x22 27x18x29x38    the solver's move, the reply, and so on
source own, motif: give one, take three; found by tools/puzzles.goose find ...
```

- **id** stays with a puzzle for good, and a new puzzle takes the next unused one, so a
  child's stars stay with the puzzle that won them. Learn's ids are below 31, the other
  themes' from 31 on.
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

`src/puzzles/russian.txt` is composed for Russian's own rules, not ported from
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
only the themes a set has, so a Russian player sees four rows. Russian's ids are its own,
from 1.

## Brazilian's set

`src/puzzles/brazilian.txt` is composed for Brazilian's rules, International's on the
8×8 board ([rules](rules.md#variants)): men capture backward, a capture must take the
most, so a choice is among captures of the same size, and a man that passes the far row
in a capture and ends elsewhere stays a man, which makes Brazilian's shots past the
crowning square. Russian's positions were each checked again under Brazilian rules
(`tools/puzzles.goose try --variant brazilian`) and kept where the shot still works and
there is still a choice; the rest are found by `find --variant brazilian` from game-like
camps. Squares and moves are written as Russian's.

| Theme | What it teaches | Levels 1, 2, 3 |
|---|---|---|
| Learn | Brazilian's rules in action: the first capture, the backward one, two men that can take and the one not taken back, the flying king's landing, the majority capture (the double where a single is there too, and two doubles where one leaves a man to be taken), a capture going on backward, a man passing the far row uncrowned, the king's zigzag landing safe, and a sacrifice that opens the way to crown. White to move. | 4, 4, 4 |
| Captures | Two captures of the most, the lesser not allowed: the one not taken back, the one that leaves no man to be taken; three jumps up and back down; four past the far row uncrowned; a king's three that lands safe. | 4, 3, 3 |
| Crowning | A capture that ends on the far row; the breakthrough sacrifice; two men given for a crown. | 4, 3, 3 |
| Shots | Give one, take three, onto the crowning square too (level 1, two moves); give one and take four past the crowning square uncrowned, give two in one capture and take five, and the free tempo (level 2); give two, then take four or five, past the far row and crowned, or after giving a king (level 3, three moves). | 6, 5, 3 |

That is 46, 13 of them black to move (38% of the 34 outside Learn); a Brazilian player
sees four rows. 26 of them are Russian's positions (Learn 9, Crowning 9, Shots 8, and
none of Captures, where majority's rule leaves Russian's choices a single legal move).
Brazilian's ids are its own, from 1. A variant with no set of its own (English, not
offered) is shown International's (`puzzles::set_of`).

## Goals

A move is right when it reaches the goal, or keeps it within reach of the moves left
whatever the other side replies; any line that does counts, listed or not. The search
counts pieces, nothing else, and plays out the captures that are due after a move, since
captures are forced.

- **take N**: the solver's move is a capture, and once the captures due after it are
  played out the solver has taken N more pieces than it has lost. The goal is the
  balance, so a shot that gives a man and takes three is "take 2", which the screen
  says as "Win 2 men" ("Win a man" for one). Every line ends quiet (Checks), so the
  balance is the men won, with nothing still to be taken back.
- **crown**: the move makes a king that the reply doesn't take.
- **win**: the other side is left with no move: everything taken or blocked. Leaving it
  no move reaches any goal.
- **safe**: nothing is lost over the next three plies (a reply, an answer, and the
  reply after it), the captures due after them played out: deep enough to see the
  other side's double sacrifice. A safe puzzle has one such move, and every other move
  loses to a shot (Checks).

The other side's reply, when the puzzle goes on, is the line's when the child has played
the line so far, and otherwise the reply after which the solver needs the most moves.
The piece the hint shows is the line's next move's, or the first right move's off the
lines.

The search keeps each position's moves on one fixed stack in a `puzzles::Solver` the
caller owns, so it allocates nothing and needs little native stack. The 74 puzzles cost
at most 3,545 positions to check (a safe move among eight, whose every other move is
searched for the shot it allows), 0.2 ms built;
the longest line is five plies, within `MAX_PLIES` (8). Russian's 46 cost at most 161
(a shot of three moves), their longest line five plies too.

## The screen

Home's puzzles opens the picker (`src/shell/picker.goose`): a library of the themes, a row
each with its count solved, and a row opens the theme's page, its puzzles as tiles in
its levels. A tile there opens the puzzle (`src/shell/puzzle.goose`), which the shell holds
with its own board and solver beside the game, so a game in progress is kept. A puzzle
for black is played on the turned board, as against the computer, and its panel says
whose puzzle it is. Their look is in [rendering](rendering.md#controls).

- **Stars**: three are at stake. Each miss puts one out, down to one: a wrong move, which
  plays and then slides back by itself, a tap the board flashes as a mistake, or a
  capture left partway (below). A puzzle solved keeps the most stars it has won. Start
  over begins the puzzle again with the misses kept, or afresh once it is solved.
- **A wrong move shows why**: when the other side answers it by
  taking something back, a capture back or a shot's first move, that answer plays on
  the board as a reply does, holds, and slides back, and then the wrong move slides back
  as any does; the child sees why it was wrong. A move that is wrong without such an
  answer (one that wins too little, or a quiet move that doesn't lead on) slides back
  0.35 s after it lands. The answer is `puzzles::answer`, the solver's
  search, not the computer player's, which lives on its worker: of the other side's
  replies, the one after which the solver ends worst over three plies and the captures
  due beyond, if that is less than the solver has after its move. It is a miss once, as
  any wrong move; the stars and the hint's glow are as for any miss.
- **Captures of many jumps** are made by hand, as children often make them jump by
  jump. A tap or a drop on a stop leaves the piece waiting there for
  the next jump; it never plays the rest of the way by itself, which would solve the
  puzzle for the child. A tap or a drop on the last square plays the capture when one
  way alone goes there (or it ends just after the stops made), so the capture can
  still be made in one go. Any of a capture's ways counts, and a square the piece only
  passes between stops is no tap at all, so a king's capture tapped square by square
  keeps every star. Stops aren't misses; the capture is judged once played
  ([rendering](rendering.md#board-and-pieces)). A capture must take every piece it can,
  so one left partway is no move: while the piece waits, next wakes (unlit), and
  pressed it is a miss, the piece sliding back from its stop with the red ring and "try
  again", as after a wrong move. Next is the one way to say a move is done, so it is
  where stopping short is caught; leaving for the puzzles, settings, or start over
  isn't an answer and costs nothing. A game makes captures stop by stop too, but shows
  the way ([board and pieces](rendering.md#board-and-pieces)).
- **Help**: after two misses the piece of the next right move glows; there is no hint
  tile. No puzzle shows a selected piece's targets, whatever the move hints setting: the
  child is to find the move ([product](../product.md)). The selection, the
  glow, and a wrong move's flash still show.
- **Themes**: Learn is open; the others open once half of Learn is solved, and Today
  ([daily puzzles](#daily-puzzles)) once all of it is,
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

## Daily puzzles

A few puzzles a day from a large library, at the player's level, once the player's
draughts' Learn is solved. The course above stays: it teaches the motifs in order, keeps
its stars by id, opens Today, and seeds the rating.

**The library** is a file per draughts, `src/puzzles/library-international.txt`,
`library-russian.txt`, and `library-brazilian.txt`, built into the program, one puzzle a
line, sorted by difficulty:

```text
variant international
732 | 737 | shots 1 | take 2 in 2 | B:W20,30,35,38,...:B1,2,K8,10,... | 28-33 38x29 23x34x25x14
```

the puzzle's id, the estimated difficulty, the theme and level, the goal in the solver's
moves, the position, and its one line. The id is given once and kept for good, under
`MAX_LIBRARY` (4,096): a player's file keeps the puzzles had and today's by id, so
puzzles added to a library, wherever their difficulty sorts them, move none of those.
`puzzles::load_library` reads only an index at start and when the player's draughts
change (`shell::sync_puzzles`): each line's id, difficulty, theme, and place, at most
`MAX_LIBRARY`, and a table from id to place; a day's puzzles are read from their lines
by id (`puzzles::entry_by_id`) into a fixed table of at most `MAX_DAILY` (10) when the
day, the set, or the player changes, never while a screen is drawn.

**Made offline**, every position our own: `tools/puzzles.goose batch` places men in
game-like camps for a table of kinds (a capture to find, shots of two to four moves, the
free tempo, crowning, a king's shots, the safe move, among 8 to 15 men a side), keeps
those with exactly one right move at each turn that pass every check above, keeps each
once by its position and by its line, the course's included, and turns a third for
black. Each puzzle's theme and level are read off its line: a safe move, a crown, a
king's capture, men given or a free tempo (shots), else a capture. Some are traps, made
by their own kinds (`batch --traps`): the move a player is used to making is there and
loses, and only a quieter one wins (below). `tools/puzzles.goose
games` takes positions from the computer's own games, where the material is even and the
side that just moved thought its move even, and the game then won men. `tools/puzzles.goose
rate` estimates each difficulty, and `tools/library.py` joins, dedups, and writes the file
([development](../development.md#daily-puzzles)).

**Traps** are some of the library, not most: puzzles where the move a player is used to
making is there and loses, and only a quieter one wins. `tools/puzzles.goose tempts`
reads a puzzle's first turn for a wrong move of a habit's kind that loses material with
best play over the puzzle's moves and two plies more: crowning at once (the king is
caught), the bigger of Russian's free choice of captures, a grab that wins a man at a
glance, a man run to the row before crowning and taken. `batch --traps` makes them as
it makes the rest, with kinds that place a man one or two steps from crowning, or black
men white can take, and keep a position only if such a move is there and loses (a cheap
look first, `lure`) and `tempts` finds the trap in the checked puzzle. They take the
themes their lines read as (shots, crowning, captures), so the pick mixes them in with
the rest at every level.

**The difficulty** is estimated on the rating's scale, with no play data: how many of the
computer's skills 0, 5, ..., 100 (searching as a hint does) miss the right first move,
the line's shape (the solver's moves, men given, the moves to weigh at the first turn, a
first move forced as a capture, moves that look as good to a shallow search, the pieces
on the board, and a line that lets the other side crown), and the motif's level. The
course rates 280 to about 1,300 and is the floor; the library reaches well past it.

**The day** is picked by `puzzles::pick` from the local day (days since the epoch by
the local date, which the app reads from the system and passes to the shell), the
player's number, the puzzle rating at the day's start, the themes opened (Captures, and
each theme with a puzzle solved in the course), and the puzzles already had: n puzzles
(the setting, 3, 4, 5, or 10; 4 by default), the first a warm-up 250 under the rating,
the last a stretch 250 over it, those between at it, a theme the day hasn't had yet taken first (within 200 of the target) so a hard day, mostly shots, still mixes; each one of the 60 nearest its
target within 75 of it, chosen by a hash of the day, player, and slot. The same day gives
the same set all day; a missed day's puzzles are gone. Picked puzzles are marked had, so
none comes again.

**The puzzle rating**, per player and draughts, is Elo's against the puzzle's difficulty:
stars are the score (3 = 1.0, 2 = 0.6, 1 = 0.3), the step 96 at first, falling by 6 a
puzzle to 24, so a child's rating climbs fast while it is new. It starts from the course,
350 plus 600 times the share of its stars won. Only a puzzle's first solve moves it; a
daily puzzle may be played again the same day for stars. It isn't shown on the puzzle
screen.

**Kept** in the player's file beside the stars: `puzzle_rating.international = 812 14`
(the rating and the puzzles that moved it), `seen.international = 0:3 5:80` (the
library's puzzles had by id, by word of 64), `daily.international = 20406 1203:3 877:0
...` (the day, and each of its puzzles' ids with the stars won, 0 unsolved), and `daily_count =
4`. Starting again clears them but the count.

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
  shows the child more to play than it let them. A safe move's replies may still give
  men, since the threat it answers starts with one: the sacrifice is still there to
  make, only no longer wins;
- a safe puzzle isn't one move, has a capture due at the start, or has a move other
  than the right one that loses without a shot: each wrong move must leave the other
  side no capture due and a sacrifice after which the solver ends down
  (`puzzles::shot`), so the puzzle is a threat to see, not a man left hanging; the
  right move leaving no shot is its being right (above);
- a take's line wins more or fewer than its count, or a crown's line ends without a
  king made (a goal reached only by leaving the other side no move);
- along a line, another legal move goes from and to the same squares, which a tap
  couldn't tell apart;
- it has no source.

A move is right by the goal within the puzzle's moves, so a take puzzle turns down a
move that wins as much only a move later, and a child sees a good move refused
([the report behind this](../decisions/puzzles.md#rivals)). `puzzles::rivals` reports those moves: at
each of the solver's turns along a line, a wrong move after which the solver still ends
the count up with best play over the moves left and two plies more, the captures due
beyond. The set tests and `tools/puzzles.goose` print them under their puzzle; they are
a report, not a refusal, until each is decided: a move that wins as much listed as a
line in its own right, or the position changed. A move whose capture is taken back, or
that wins less, is no rival: that is the lesson of Captures' first level, the double
whose last stop is safe. Both sets report none.

`tools/puzzles.goose` adds the computer player's view at full skill: its root scores,
whether the moves it rates best solve the puzzle, a second engine sharing only the
rules with the solver, and whether it scores a right first move as losing material
(under −50, half a man). It plays for material, so it is not asked about crowning.
`test/perft.py puzzles international src/puzzles/international.txt` (and `russian
src/puzzles/russian.txt`, `brazilian src/puzzles/brazilian.txt`) plays every line with
the independent generator, checking each move and each position's moves against
`build/perft`; for Russian, which has no published perft table, it is the only
independent check. `scripts/test.sh` runs it on all three files.

`tools/puzzles.goose try FEN GOAL MOVES [LINE]` shows the moves that are right, the line
the screen would play (after LINE's moves, when given, which shows where a rival leads),
and what the checks say of it. `find SIDE GOAL MOVES MINE THEIRS
COUNT [SEED [KINGS [CORE]]]` turns up positions to compose from: the solver's and the other
side's men placed in camps as in a game (each next man beside or behind one of its own,
on its own side of the board), some of the solver's made kings, with exactly one right
move at each of the solver's turns, every check passed, and the game going on after the
line; a take in more moves must be a shot, its first move answered by a capture, and a
safe move must answer a threat, a shot the other side would have were it to move. CORE
is a motif's skeleton for white, its men in every position and the camps filled round
them; the named shots were found that way. For black it finds the puzzle for white and turns the board round, checking it again. Both
take `--variant NAME` (International by default), and find `--rows N`, the rows from its
own back row a camp spans (the board's size less 3 by default), and `--tempo`, which
asks a take in more moves to start with a free tempo instead: a quiet move that no reply
captures after, every reply giving men.
