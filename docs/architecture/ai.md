# Computer player

The computer player is `ai/` (namespace `ai`): pure Goose over [`rules`](rules.md), with
no graphics, tested headless in `test/ai/`. It is made weaker the way a person is
weaker, not the way a crippled engine is: each level sees a fixed number of plies and
never past them, and picks among the moves it sees as good, more often the better ones.
Engines weakened by noise or an occasional second-best move hang a piece no person would
and then find a long combination a move later; that is what this avoids.

## Thinking in steps

```goose
var e = ai::Engine { .. };
ai::init(e);                                  // once: the table and the frames
ai::start(e, position, skill, seed);          // a move to find
while !ai::step(e, 10000) { /* a newer ask? */ }
let m = ai::reply(e);                         // one of position's legal moves
```

`step` searches for about the given number of nodes and returns whether the reply is
ready. The search is alpha-beta unrolled into one frame per ply (`Engine.plies`), so it
stops after any node and goes on at the next call.

The search counts nodes, never time, so the same position, skill, and seed give the same
move on every machine, however the thinking is cut into steps. Tests rely on that, and a
game can be replayed.

## Thinking on a worker

The app thinks on one worker thread (`src/app/think.goose`), so the frame loop never waits
for the search:

- The game says what it wants: on the computer's turn it opens an ask, `game::Ask`, a
  flat value holding an id, the position, the skill, and the seed; `game::answer` takes
  the move for an id and ignores one for an ask no longer open. Undo move, start over,
  leaving the game, or the app pausing closes the ask; the next turn opens a new one.
- Each frame the app puts the game's ask on the typed queue for `game::Ask` when it
  changed (id 0 for none) and polls the queue for `think::Thought`, the answer.
- The worker, a `thread_fn`, builds its own `ai::Engine` and calls `ai::init` once: a
  root can't cross to a thread. It waits on its queue (`qget`, blocking, no CPU), runs
  `ai::step` 10,000 nodes at a time, about 2 ms on the tablet's big cores, and between
  steps looks for a newer ask (`qpoll`). One that comes drops the search under way, so a
  take back never waits for a stale reply. The answer carries the move, the nodes, and
  the time it took.
- The worker starts at the first ask, so a game against a friend costs no thread and
  none of the engine's 6 MB; with the lookout on, its traps start the thread but not the
  engine, which is made at the first search. The hint and the lookout's traps are asks
  too (`game::open_ask`: the computer's move first, then the hint's, then the traps), and
  the answer says which it is for (`think::Thought.kind`).

Threads stay in `app/`: `game/`, `shell/`, and the tests run headless through TinyCC,
which can't start a thread, and tests answer an ask with `ai::think` at once. The app is
therefore built on the Mac too ([development](../development.md#run-on-the-mac)).

On a worker the frame loop draws as it would without the computer
([why not slices on the drawing thread](../decisions/ai.md#thinking-on-a-worker)).

## In the game

- **A person's pause.** The computer's move begins 0.8 s after its turn begins (the
  child's move has landed) on easy, 0.6 s on medium, and 0.45 s on hard, or when the
  search ends if that is later; then it plays through the board's move animation. Easy
  answers in under a millisecond, and a reply at once feels like a machine. Medium and
  hard pause less, as they take time of their own on the tablet.
- **Against the clock** it takes as long as a player of its level would
  (`src/game/pace.goose`): a share of what it could spend each move and keep its clock (the
  time left over 30 moves, plus the increment), 0.2 of it on easy, 0.3 on medium, 0.45
  on hard, for a quiet choice among three close moves. Its search's root scores say how
  close (`ai::close`: the moves within 0.15 of a man of the best, as far as its margin
  scores them exactly): one move standing out takes a third of that, five or more close
  ones five thirds; a single move only the pause. Medium and hard see a choice among
  captures at once and take half. Easy, like a weak player who has to look, takes 3.5
  times as long whenever a piece can be taken around its move (`pace::tense`): it must
  capture, the other side could capture were it its turn, or could once its move is
  played. That is two move generations into stack buffers, once a move, and catches the
  positions where a child's move most often goes wrong; the close moves already measure
  how hard the choice is. The first moves of a game come quickly, as a player knows them:
  the time grows over the first 12 plies. It never takes more than 12, 8, or 15 s by
  level, nor more than a tenth of its clock, so with the increment it can't lose on time.
  Easy's cap sits above medium's: a sharp position on a long clock is where easy looks
  longest. The time only decides when the move is played: the search still stops at its
  own depth, so its strength is the same. White's first move is untimed, so the computer
  playing white makes it after the pause.

- **While it thinks**, its piece on the panel pulses once: the glow ring fades from full
  to a third and back over 1.2 s, on its clock's piece when there are clocks, even before
  they start, then stays full. That keeps frames coming while the answer is on its way,
  so it is seen the next frame; an idle frame waits up to a second for an event
  ([rendering](rendering.md#frames-and-battery)). A longer think against the clock shows
  on its clock, which counts each second, and the app sets a timer for when the move is
  due rather than draw every frame for many seconds. Once its move has landed nothing
  animates and the app draws nothing. The child can't move the computer's pieces; home,
  settings, start over, and take back still work.
- **Undo move** takes back the child's last move and the computer's reply, so it is the
  child's turn again; while the computer thinks, it drops the search and takes back the
  child's move. Before the child's first move it does nothing.
- **Clocks**: the computer's clock runs while it thinks and pauses, from the start of the
  child's move as for any player, and its move adds the increment, as any move does.
- **The seed** of a move is the game's number times 1000 plus the ply: replies vary from
  one game to the next, and the same game replays the same. The number counts the games
  begun against the computer, kept per player in `player-N.txt` (`games`).
- **Skill**: each player's file keeps one skill per level (`skill_easy`, `skill_medium`,
  `skill_hard`, from the level's starting skill) and how many games ended on each
  (`played_easy`, ...), and a game plays at its level's skill as it began, kept with the
  saved game. A game that ends moves its level's skill with `ai::adapt`: up when the
  child won, down when the computer did, by the clock too. It counts once, when it first
  ends; taken back and ended again, it doesn't count again. A game started over or
  replaced before it ends doesn't count. A draw counts as 0 and leaves the skill. Play again on the end's card and start
  over during a game begin a new game at the level's skill as it is then, adapted by the
  game just ended, and count it for the seeds as home's play does.
- **The default level** for a new player, and for settings read fresh, is easy; a
  player's saved level stays.

## Search

- **Negamax alpha-beta**, fail-soft, with iterative deepening. Moves are tried in the
  order: the table's move, captures by how many pieces and kings they take, two killer
  moves per ply, then by a history table; at the root, by the last iteration's scores.
- **Depth.** A node searches `d` more plies of free moves and at most `h` more plies in
  all. At `d = 0` the search goes on only while the side to move must capture: captures
  are compulsory, so there is no standing pat on a capture. A forced move (the only legal
  one) costs no depth, as a person sees it at once. At `h = 0` the search stops wherever
  it is. `h` is how far a level sees.
- **Transposition table**: 2^18 entries of 16 bytes (4 MB), made once by `ai::init` and
  cleared at the start of each search, so a reply never depends on earlier searches.
  Zobrist keys are updated per move. An entry answers a node only when it was searched
  with the same `d` and `h`; an entry from another depth would make the result depend on
  what was searched first. The table then changes how many nodes a search takes, never
  a score (`test/ai/search.goose`). In draughts a transposition is nearly always
  reached at the same ply, so the exact match costs little
  ([why 4 MB](../decisions/ai.md#search)).
- **Root scores.** Every root move within the level's margin of the best gets an exact
  score: each is searched with alpha at the best so far less the margin. The rest have
  only an upper bound and are never played.
- **Node limit**: no new node is entered after 800,000 nodes once an iteration has
  finished; the iteration under way is dropped. It bounds hard's reply to about a fifth
  of a second on the tablet's big cores and 0.65 s on its little ones, and more nodes
  still made hard stronger on 10×10. Easy and medium finish their depth in a few thousand
  nodes.
- **Draws** score 0 (rules.md, "Draws"). Each frame carries the draw counts
  (`rules::draw_after` per move), and a node whose counts have ended is a draw unless its
  side to move has no move, which is a loss as in the game. A position met earlier on
  the way from the root is a draw, as the side that came back can come back again; one
  met at the root or in the game before it is a draw when that makes three times. The
  game hands the search its counts and its positions since the last man's move or
  capture (`rules::Past`, `ai::start_after`), whose keys the search compares only that
  far back. So the side behind steers into a draw and the side ahead clear of it
  (`test/ai/draws.goose`). A table entry may carry a draw from another way to the
  position; draughts engines accept that. The checks cost nothing measurable in
  middlegames and about 5–10% of the nodes a second in king endings.
- **Evaluation**, in hundredths of a man, for the side to move: a man 100, a king 300
  (150 in English, whose kings don't fly); a man gains as it advances, most near the far
  row; a man on its own back row 3 to 4, for keeping kings out; a man on a central square 3.
  The weights follow from the variant's fields: the king's from flying, the rows' from the
  board's size, so Brazilian has International's king on Russian's 8×8 rows.
  All of it is integer arithmetic on the bitboards.

Nothing allocates per node: the frames, their move buffers (`rules::Moves`, 512 moves),
and the table are made once, about 6 MB in all.

## Levels

Skill runs from 0 to 100; easy starts at 8, medium at 40, hard at 90
([tuning the levels](#tuning-the-levels)). One skill holds for a whole game. It sets:

| | Formula | Easy (8) | Medium (40) | Hard (90) |
| --- | --- | --- | --- | --- |
| Plies of free moves it sees | `1 + s / 12 + max(s − 60, 0) / 6` | 1 | 4 | 13 |
| Plies of forced captures past them | `2 + s / 8` | 3 | 7 | 13 |
| Temper: how much worse makes a move e times less likely | `2 + 60 (100 − s)² / 10000` | 52 | 23 | 2 |
| Margin: never a move this much worse than the best it sees | `min(60, 3 × temper)` | 60 | 60 | 6 |
| Chances left for the child, per thousand moves | `5 × max(25 − s, 0)` | 85 | 0 | 0 |
| Overlooks a capture of 1; 2; 3; 4+ pieces, per thousand, tense, next to the moved piece | `MISS × (max(SURE − s, 0) / SURE)²`, MISS 25; 240; 300; 450, SURE 15; 25; 65; 65 | 5; 110; 230; 346 | 0; 0; 44; 66 | 0 |

How each part plays like a person:

1. **It misses only what shows deep, or what a person overlooks.** A level never
   searches past what it sees, so it misses a shot or a threat only when the point lies
   beyond. From skill 15 on it sees its own move and every one-piece capture it allows,
   so it never hangs a piece to the reply that just takes one; from 25 every two-piece
   capture, from 65 every capture (`test/ai/blunders.goose`). Easy plays a sacrifice
   that fails only further on, as a child does.
2. **It sometimes overlooks a capture, as a person errs** (the table's last row). After
   each of its moves it may not see one of the child's captures: each capture is seen
   or not by its own chance, drawn from a hash of the move's seed and both moves
   (`ai::overlooked`), so the search meets the same answer each time and every machine
   agrees. The chance grows with how many pieces the capture takes (MISS) and with how
   far it starts from the piece just moved (times 1, 1.25, 1.5, and 2 for a step, 2, 3,
   and 4 or more squares away; a capture of the moved piece by one jump starts a step
   away), and is a tenth as large in a quiet position: one where neither side could
   capture before its move (`ai::notice`, the root's half of `pace::tense`). It fades
   with skill, each size by the square of the way left to its own sure skill: easy
   misses a one-piece capture now and then until 15 and a two-piece one until 25;
   medium only captures of three pieces or more, now and then (44 per thousand at 40,
   next to the moved piece); from 65 on, hard included, nothing. Where it sees none of
   the child's captures it takes the position as quiet. It still chooses as always among
   what it does see, so an overlooking move is a sensible move but for the capture, and
   it hangs a piece only where its best-looking move does. Its own captures stay
   compulsory, as the rules make them (`test/ai/overlook.goose`).


3. **Consistent strength.** It chooses among the moves within the margin with chances
   that fall off as e^(−δ / temper), δ being how much worse each is than the best it sees:
   Regan and Haworth's model of how players of a given strength choose. So there are no
   genius moves among random blunders. The margin, under 0.6 of a man, keeps positional
   terms from passing off a move that loses one. The chances use integer weights, so
   every machine agrees.
4. **No long combinations on easy**: it sees four plies in all at its start (8), six by 16. Depth rises evenly with
   skill, so 15 points more wins about three games in four against itself, and the
   small steps of adapting are felt.
5. **It adapts.** `ai::adapt` moves the skill 4 up after the child wins and 4 down after
   the child loses, within the level's band (easy 0 to 30, medium 25 to 60, hard 70 to
   100: `LEVEL_FLOOR`, `LEVEL_TOP`), so a child meets an opponent they beat about half
   the time ([in the game](#in-the-game)). Over a player's first three games on a level
   the steps are 8, so the skill finds the child sooner, and a win in the very first game
   moves it 16 (`FIRST_WIN`), so a grown-up's first win lifts easy from 8 to 24, clear of
   its plainest mistakes; the file counts the games that ended on each level. Easy starts
   at 8, a step above its floor, so a young child's first loss brings it to 0. A level no
   game has ended on starts where the level starts now. A file from before that count keeps its skills; one still at
   its level's old start (easy at 10) has had no game that moved it, and starts afresh at
   the new start with its first steps to come, while one moved from it has had them.
6. **It leaves chances to learn.** Below skill 25, now and then (the chances row),
   it looks among moves that cost it at most 1.2 men for one that leaves the child a
   combination: no capture to make, but a quiet move that wins at least 0.8 of a man on
   the position as it stands, which few of the child's other moves do. Captures are
   compulsory, so leaving a capture would only hang a piece, not leave something to find.

Played against itself, each level beats the one below it nearly every game, in each
variant. Self-play, 400 games a pair in each of Russian, International,
and Brazilian (`build/aimatch ... --overlooks`), wins, draws, losses for the first:

| Pair | Russian | International | Brazilian |
| --- | --- | --- | --- |
| Easy at its floor (0) against skill 10 without overlooks | 92, 79, 229 | 61, 83, 256 | 96, 82, 222 |
| Easy at its floor (0) against skill 0 without overlooks | 124, 73, 203 | 87, 85, 228 | 112, 86, 202 |
| Skill 15 against easy at its floor (0) | 323, 46, 31 | 344, 27, 29 | 337, 27, 36 |
| Medium (40) against easy at its floor (0) | 391, 5, 4 | 398, 1, 1 | 387, 11, 2 |
| Easy's start (8) against its floor (0) | 193, 72, 135 | 203, 66, 131 | 185, 78, 137 |
| Easy's start (8) against skill 10 | 173, 61, 166 | 148, 70, 182 | 161, 62, 177 |
| Skill 15 against easy's start (8) | 303, 51, 46 | 339, 33, 28 | 315, 41, 44 |
| Skill 24, after a first win, against easy's start (8) | 369, 19, 12 | 394, 6, 0 | 373, 16, 11 |
| Medium (40) against easy at its top (30) | 255, 84, 61 | 301, 57, 42 | 255, 93, 52 |

A simple child model, skill 0 overlooking three times as often (`--overlooks 300`),
loses to skill 0 without overlooks in 60 to 73% of games and to 15 in 87 to 92%. Easy's
top and medium's start are closer than the levels' starts: medium wins about 64 to 75%
there and loses 10 to 15%.


## Tuning the levels

For when stronger or older players find easy (or medium) too easy or too hard. Every
knob below is in `src/ai/ai.goose` but pace, and each is one constant or formula. The
score is a side's wins plus half its draws over the games; "a point" is 1% of it.

**First, if experienced players find easy too easy**: let easy climb to them faster
before touching the overlooks. Larger first steps (`FIRST_WIN`, `FIRST_STEP`,
`FIRST_GAMES`) reach a strong player within a few games and still let a young child's
losses take easy to its floor; a higher start (`LEVEL_SKILL[0]`) or floor
(`LEVEL_FLOOR[0]`) starts everyone higher. The overlooks set how easy plays at the bottom, which is where young children
meet it.

The knobs:

- **`MISS`**, per thousand by the capture's size (1, 2, 3, 4+ pieces): how often skill 0
  overlooks one of the person's captures in a tense position, next to the piece it
  moved. Lower is stronger. 60 per thousand on the two-piece capture moves easy at 0 by
  1.5 to 2 points against skill 10 (160 → 240 → 300 at 2000 games: 0.339, 0.326, 0.310
  in Russian, the other variants alike); the one-piece capture 25 → 75 by about 1 point,
  but it adds hangs in quiet positions, which look like a machine.
- **`SURE`**, by size: the skill from which each size is always seen (15, 25, 65, 65);
  the chance fades as the square of the way left to it. Lower is stronger for the
  skills below it. The two-piece's 25 is medium's floor, so above 25 medium starts
  missing double captures; the 65s are what medium overlooks (44 and 66 per thousand at
  40): lower them to make medium stronger, raise them to make it weaker. Not measured
  on its own: measure as for `MISS`, with the pairs below 65.
- **`FAR`**, in quarters by distance from the moved piece (4, 5, 6, 8: a step, 2, 3, 4+
  squares): a capture further from the piece just moved is missed more. Smaller is
  stronger. Not measured on its own; it moves where the misses fall more than how many.
- **`QUIET`**, percent (10, a tenth): the chance in a quiet position, one where neither
  side could capture before the move. Lower is stronger. A tenth keeps easy at 0's
  quiet hangs to about 6 per 100 games in Russian; raising it brings back the
  machine-like blunders ([measured](../decisions/ai.md#mistakes-by-tension-2026-11-09)),
  so prefer `MISS`.
- **`LEVEL_FLOOR`, `LEVEL_TOP`, `LEVEL_SKILL`**: each level's band (easy 0–30, medium
  25–60, hard 70–100) and start (0, 40, 90). Higher is stronger. Ten points of skill
  win about half and lose about a third against the lower (10 against 0: 0.59 to 0.6);
  fifteen win 80 to 97% at the bottom of the scale and 63 to 75% from 25 to 40. Medium
  at 40 scores about 0.74 to 0.82 against easy's top, 30.
- **`STEP`, `FIRST_STEP`, `FIRST_GAMES`**: how far a win or loss moves the skill (4;
  8 over a player's first 3 games on a level). Strength doesn't change, only how fast
  the skill finds the player: easy reaches 24 after three first wins. 4 is about a third
  of a ply, small enough to be felt as a step and not a wall.
- **Depth**, in `params`: `1 + s / 12 + max(s − 60, 0) / 6` plies of free moves and
  `2 + s / 8` of captures past them. More is stronger: one ply every 12 skill points
  (every 4 above 60) is most of what 15 points buy. It moves every level and the rule
  adapting relies on (15 points winning about three in four), so change a level's band
  before the formula.
- **Temper**, in `params`: `2 + 60 (100 − s)² / 10000`, with `MAX_MARGIN` 60. Lower is
  stronger (fewer second-best moves). At easy it is flat: 62 → 102 at 0 scored no
  weaker (about 1 point better, within noise), as within the margin it already chooses
  nearly evenly. It matters from medium up, where the margin follows it (3 × temper).
- **`GIFT_CHANCE`** (5 per thousand moves per point below `GIFT_SKILL`, 25: 125 at 0;
  `GIFT_COST` 120): how often easy leaves the person a combination. More is weaker only
  against a player who finds them: 125 → 200 measured nothing against skill 10, which
  doesn't look for them. Judge it by play, not aimatch.
- **Pace**, `src/game/pace.goose`: easy's share of its clock (`SHARE`, 0.2), its tension
  factor (`TENSE`, 3.5), the caps (`MOST` 12, 8, 15 s; `SPARE`, a tenth of the clock).
  It changes the feel, not the strength: the search stops at its own depth however long
  the move takes.

**What to measure** after a change, 400 games a pair in each of Russian, International,
and Brazilian (seconds for easy, many minutes with hard):

- Easy's strength against fixed yardsticks the overlooks don't touch:
  `build/aimatch VARIANT 0 10 400 --overlooks 100 0` (and `0 0 400 --overlooks 100 0`).
  At 400 games the score's noise is about 2 points either way: for a smaller step,
  2000 games.
- The ladder: `build/aimatch VARIANT 15 0 400` and `25 10 400`; for medium, `40 25`,
  `55 40`, and `40 30` (medium's start against easy's top).
- Where the mistakes fall: `--hangs` (quiet and tense hangs per side).
- A young child: `build/aimatch VARIANT 0 0 400 --overlooks 300 0` and
  `0 15 400 --overlooks 300 100`.

Put the before → after in [decisions](../decisions/ai.md), as the ones there.

**Tests to re-bless** (`test/run_tests.py --bless NAME ...`, after reading each diff):

- The overlooks (`MISS`, `SURE`, `FAR`, `QUIET`): `overlook`, `levels`, `blunders`, and
  `pace`, which every overlook change so far has moved.
- Bands, starts, and adapt steps: `levels`, and the tests that show the skill kept or
  moving (`adapt`, `players`, `settings`, `shell`, `computer`), and `pace` if a start
  moved.
- Depth, temper, and the chances: the whole `ai` area, `pace`, and the tests that play
  the computer (`computer`, `adapt`, `wait3d`). Run `scripts/test.sh` to see.
- Pace: `pace` only; widen a level's `LOW`/`HIGH` there only with a reason here.


## The lookout

The game's lookout (`docs/product.md`) marks the threats past the player's sight:
`src/ai/lookout.goose` (namespace `lookout`), pure functions over `rules`, tested
headless in `test/ai/lookout.goose`, and the game's `watch` (`src/game/game.goose`,
`test/game/watch.goose`).

- **What it sees.** `now`: the other side's legal moves were it its turn, each capture's
  whole chain and each crowning. `after`: the same once the side to move plays a move,
  the moved piece marked on the square it was taken from, as the player holds it there.
  Each threat is sorted by how plain it is: one piece taken by a piece next to it
  (`NEAR`), one taken from afar by a flying king (`FAR`), two pieces (`TWO`), three or
  more (`MANY`), a man crowning by a step (`STEP`) or through a capture (`JUMP`), a trap
  (`TRAP`).
- **Traps** (`traps`): a quiet move of the other side after which the player must
  capture, and whatever the player takes, the other side's best capture then takes more
  pieces than it gave. Three plies: its moves, the forced replies, its captures; none
  while it has a capture of its own. The pieces it would win are marked.
- **When.** Only on the side to move's turn, the board at rest, the game going on, no
  capture due (the must-capture ring says what to do then): the position's threats, or
  while a piece is dragged over a target (a finger's drag, or the mouse over a target of a
  piece selected by a tap) that move's. Against a friend it watches for whoever's turn it
  is. It works the threats out once a position or held target, never a frame: `now` and
  `after` are one move generation each, about 0.02 to 0.04 µs built on the Mac; traps go
  to the worker as an ask of their own (`game::TRAPS`), about 2 µs (2.5 at most) on the Mac
  (`tools/lookbench.goose`, Russian, International, and Brazilian middlegames).
- **The skill filter** (`lookout::UNTIL`, `shown`): a kind shows below its skill, the
  game's skill against the computer (adapted to the child, so the child's own) and the
  player's at their level against a friend:

  | Threat | Shown below skill | Why |
  | --- | --- | --- |
  | One piece, the attacker next to it | 15 | From 15 the computer sees every one-piece capture; a player matched to it does too |
  | A man crowning by a step | 15 | As plain: the man is one step from the far row |
  | One piece from afar (a flying king) | 25 | A capture at a distance is missed longer, as a two-piece one is |
  | Two pieces | 25 | From 25 the computer sees every two-piece capture |
  | Crowning through a capture | 40 | A small combination: left from medium's start |
  | Three pieces or more | 70 | Long captures are missed through medium (the computer sees them all from 65) |
  | Traps | 70 | The deepest: through medium |

  So easy at 0 to 14 shows everything; 15 to 24 drops the plain ones; medium (25 to 60)
  keeps long captures, crowning through a capture until 40, and traps; hard (70 and up)
  shows nothing. The thresholds follow the computer's own horizon by skill
  ([levels](#levels)), as the game matches the computer to the child.

## The hint

The hint's move is the computer's search for the side to move, asked of the worker as
the computer's moves are (`game::HINT`): at 15 above the skill of the side it plays
against (the computer's, or the player's at their level against a friend), at most 100,
with nothing overlooked and no chance left for the other side (`ai::helping`), and the
best move its main search scored rather than one the temper chooses (`ai::best`). It is
asked on the first press, answered in at most hard's time (a fifth of a second on the
tablet's big cores), and dropped if the position changes first; the loop looks for the
answer every 20 ms while it is on its way, drawing nothing meanwhile. Games with hints
count toward the skill as any other.
