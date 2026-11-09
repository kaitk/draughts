# 040: The coach and the hint

Status: todo (round 3 drawn, a choice pending)

One feature for help in a game against the computer: a coach that shows the player's
danger, and a hint that shows a move. A hint alone makes a player lazy, though lighting
the piece to move helps; the coach teaches to look, as help shouldn't do the thinking
(`docs/product.md`). Asked for 2026-11-09 after a young player tried the game, widened
the same day from a hint button into the coach and the hint together. When it is built,
`docs/product.md` loses "A game has no hint button" and says what the help is.

## What it shows

Two controls since round 3: the coach, a toggle named for now the lookout (the names
offered are below), and the hint, a button of its own.

- **The coach** shows danger, never the answer. While on, it shows it by itself, with
  nothing to press each turn. From the adaptive skill the app knows roughly how far the
  player sees (`docs/architecture/ai.md`, "Levels"), and the coach shows the threats
  just past that horizon:
  - the player's pieces in danger now: what the computer would take if it were its turn;
  - while the player holds a piece, what that move would leave open (the pieces the
    reply would take, a double jump's both);
  - a king square, only when crowning is a real threat within reach. The computer's
    deeper plan is not shown: it changes almost every move.
- The coach shows less as the skill climbs: a threat the player's depth already sees is
  left to them, and at hard's skills it shows next to nothing.
- **The hint** is its own button: the first press lights the piece to move and spends a
  hint, the second shows where it goes. A few a game (three in the takes), shown as pips
  on the button.
- Neither shows while the player must capture: the must-capture ring already says what
  to do. Neither shows in puzzles.

## The takes

### Round 3 (2026-11-09)

`prototypes/coach.html`. Two controls: the lookout, a toggle that while on shows the
danger by itself, and the hint, a tile beside undo in both takes (Hint; pressed, it
lights the piece, spends a pip, and asks Where to?; pressed again, it shows the square and
stays lit until the move; dim with none left). The danger is marked on the pieces, dark
and still; the hint is light and breathes: the piece to move pulses the puzzles' glow
ring, then a light, translucent ghost of it in the glow breathes on its square. Positions
and states as in rounds 1 and 2; the layouts as built: landscape, a phone's portrait, and
compact. In portrait the switcher folds under an Options button at the bottom left.

- **a, a round toggle.** The lookout is a disc like the 3D board's camera buttons (48 dp
  of shade with a hairline in a 56 dp target): on, lit in the glow with the open eye; off,
  the eye struck through and dim. It sits on whose turn's line: at its right end in
  portrait and compact, under the words with its name in the right column.
- **b, a tile.** The lookout is a tile among the way-out ones, lit as a pressed row while
  on: the bar's second of four in portrait (Alusta uuesti on two lines on a phone), under
  settings in the left panel, an icon tile in compact's bar.

Marks (`&mark=`), the same in both takes, for the piece in danger:

- `shade`, the piece darkened to under half;
- `drain`, its color drained and a little darker, still opaque, unlike round 2's dim;
- `shadow`, the threatening piece's shadow across it from where the jump comes.

A crowning (`&king=`): `square`, the crowning square shaded with a dark, still ghost of
the king; or `piece`, the man that would crown in the danger's mark with a crown line on
it. `&you=black` shows the same positions from black's side, to judge the marks on dark
pieces; `&lang=et` the Estonian; `&name=` each name offered.

Checked with `agent-browser` at 390 × 844, 499 × 645, and 1280 × 800, over the season's
photograph, in 2D and 3D.

What was seen:

- Every mark reads apart from the hint: dark and still against light and breathing,
  the hint's ghost translucent and ringed, the danger's pieces solid.
- `shade` is the strongest on light pieces; on dark ones (`&you=black`) it nearly goes
  black and reads less. `drain` turns a dark piece blue-grey and reads on both. `shadow`
  says where the jump comes from, but at a phone's board size it reads as a dent.
- The king's `piece` mark puts the danger's shade on the computer's man, so the shade
  would mean two things; `square` keeps it on the player's side.
- b's four tiles fit a phone, Estonian's Alusta uuesti on two lines; a's disc adds nothing to
  the bar and stays beside whose turn, where the eye is during play.

The user on round 2 (2026-11-09): the shaded pieces (a piece in danger shaded, a shaded
king) read better than the highlighted squares; the crack and the tilt are dropped. Not
sold on one control doing everything, least of all with a free first step: the coach
separate, a toggle that shows the danger by itself, and the hint its own button. The
working names (coach, warner, whistle blower) to be replaced.

#### Names offered

Short, clear to a child, one word in Estonian as strings/et.txt's labels are (Vihjed,
Tammid):

| English | Estonian | Icon | Why |
| --- | --- | --- | --- |
| Lookout | Valvur | eye | The one who watches for you; a child knows *valvur*. The pick |
| Guard | Kaitse | shield | Says what to do about it: *kaitse* is a defence in play too |
| Dangers | Ohud | warning | The plainest: a toggle for showing dangers, no persona |
| Eagle eye | Kotkasilm | eye | Playful; *kotkasilm* is a common Estonian idiom |

Watch (Valve) was left out: in English it reads as a clock.

#### Links

Round 3 (the layout follows the window's size: resize for portrait or compact):

- Take a: file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=a
- Take b: file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=b
- The lookout off: file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=a&lookout=off,
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=b&lookout=off
- States: calm file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=a&state=calm,
  held file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=a&state=held,
  king file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=a&state=king,
  hint1 file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=a&state=hint1,
  hint2 file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=a&state=hint2,
  control (both controls in every state, and the names)
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?state=control
- Marks: shade file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?mark=shade&state=held,
  drain file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?mark=drain&state=held,
  shadow file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?mark=shadow&state=held
- Crowning: square file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?state=king&king=square,
  piece file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?state=king&king=piece
- Every mark and state: file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?view=sheet,
  from black's side file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?view=sheet&you=black
- In Estonian: file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach.html?take=b&lang=et&state=held
- Round 2: file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach-2.html?take=a,
  file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach-2.html?view=sheet
- Round 1: file:///Users/kaitkasak/projects/personal/draughts/prototypes/coach-1.html

### Round 2 (2026-11-09)

`prototypes/coach-2.html` (or `coach.html?round=2`; `?take=a` or `b`, `&mark=` for the
coach's color or treatment, `&state=calm`, `ask`, `held`, `king`, `hint1`, `hint2`,
`control`; `&view=sheet` for every take, mark, and state side by side). Both takes are one
feature: one control, its word the next step (Help shows the danger, free; Which piece
lights the piece to move and spends a hint; Where to shows its square), and one language
of marks for the danger and the hint. The coach takes no new hue: the danger is still, in
the app's red, cream, or shade, or on the pieces themselves; the hint breathes in the
glow, as the puzzles' does. A setting under move hints says whether the coach shows Always
or When asked (`control`); `ask` is the game before Help is pressed. Positions and states
as in round 1, the layouts as built: landscape, a phone's portrait, and the compact small
window (task 050).

- **a, corners.** The control is a tile with the bulb, its word, and the pips: beside
  undo move in portrait (halves of the row), over it in the right column, and between
  whose turn and undo in compact. The marks are four corner brackets on a square, which
  nothing else on the board draws: the danger's still, in the coach's color; the hint's
  breathing in the glow, round the piece to move and then round its square with a move
  dot. A crowning: corners and a crown on the square. Three colors (`&mark=`): `red`, the
  wrong move's red, never pulsing (must capture never shows with the coach); `cream`,
  the light piece's cream lightened; `shade`, dark corners on a darkened square.
- **b, the pieces.** No new tile: whose turn becomes the control, a glass tile with the
  piece and the words over a line with the bulb, the next step, and the pips; undo move
  stays as built. The marks are on the pieces, so nothing new is drawn over the board: a
  piece in danger is (`&mark=`) `crack`ed, a line across its face in its own shade;
  `dim`, half gone and drained of color; or `tilt`ed toward where the jump would land,
  after one shake. A crowning is the computer's king as a ghost on its square. The hint
  rings the piece to move with the puzzles' pulsing glow ring and puts its ghost where it
  goes.

Checked with `agent-browser` at 390 × 844 (a phone's portrait), 499 × 645 (compact),
and 1280 × 800 (the tablet's landscape).

### Round 1 (2026-11-09)

`prototypes/coach-1.html` (or `coach.html?round=1`; same parameters, takes `a` to `c`).
Every take gave the coach a soft violet (`#c7a6ff`): a, dashed rings, the hint a tile,
the coach a setting; b, the computer's jump as a dashed line, the coach a tile beside the
hint; c, small "!" badges and one Help tile for danger, piece, and move.

The user on round 1 (2026-11-09): the idea is OK; not sold on the violet (yet); the coach
looks rather different from the hint and feels bolted on, most of all in portrait.

## Open choices

1. Which take: the lookout a round toggle on whose turn's line (a) or a tile among the
   way-out ones (b).
2. The danger's mark: shade, drain, or shadow; and whether it holds on dark pieces (seen
   so far: drain does, shade less).
3. A crowning: the shaded square with a dark ghost king, or the man that would crown
   marked.
4. The name: Lookout (Valvur), Guard (Kaitse), Dangers (Ohud), or Eagle eye (Kotkasilm).
5. The lookout's default: on for a new player and remembered per player, or off until
   turned on; and whether settings also hold it.
6. The lookout's window over the player's horizon: one ply past it, or two; and whether
   at hard it shows nothing at all.
7. When a held piece shows what it leaves open: while dragged over a square (as the
   takes show), or on selecting it, for every target at once.
8. How many hints a game (three in the takes), whether the second press costs another,
   and whether a game with hints used counts toward the skill the same.
9. A game against a friend: the hint for whoever moves, the lookout for both or neither.

## The engine

One threat search on the worker thread (`src/app/think.goose`), as the computer's move
is: on the player's turn, and while a piece is held over a square, the game opens an ask
for the position with the other side to move. The search lists the captures and crownings
the opponent has within reach, each with its depth, and the app keeps those just past
the player's depth from skill (the free plies of the formula in `ai.md`, at the player's
level). The hint is the search's best move at a skill above the opponent's. Nothing runs
on the drawing thread, and an answer for a position no longer on the board is dropped.

## Acceptance criteria

- [ ] A take chosen and this file updated with it
- [ ] The coach's marks and the hint on the game screen in every layout, 2D and 3D, their
  strings in `strings/`
- [ ] The coach shows the threats past the player's depth and less as the skill climbs;
  tested headless on fixed positions
- [ ] The hint: first press the piece, second the move, the hints left shown
- [ ] Both searches run off the drawing thread
- [ ] `docs/product.md` and `docs/architecture/ai.md` say what is built
