# 019: Prototype the game screen's controls, a clock, and the first start

Status: in-progress

Prototypes only (`prototypes/`, checked with agent-browser), to settle before building:
the user finds home very readable but the game screen's four icon buttons confusing,
especially in landscape (2026-11-07).

## Work

- **The game panel**: in landscape, labels beside the icons, as home's rows have them;
  portrait is acceptable as it is but should follow. Revisit which controls belong
  there: perhaps no hint button, and settings reachable from the game. Show a few takes
  side by side in the prototype's usual way, against `game.html` as it is now.
- **A clock** for time-limited games (blitz, "välkkabe"): find the standard
  international time controls for blitz in draughts (FMJD for 10×10, and the 8×8
  federations' for Russian draughts) and record them with their sources; prototype how
  the two clocks show on the game screen in both orientations, and how a game with a
  clock is chosen.
- **The first start**: map the flow from the first launch: choosing which draughts to
  play, as side-by-side cards (10×10 international and 8×8), then an optional tutorial
  of the moves, the only place where move hints show moves by default. Draw the flow
  as pages linked in order.

## Time controls (found 2026-11-07)

Base time per player plus a Fischer increment per move, written `5+3` (minutes, seconds).

- **FMJD, 10×10** (Annexes, February 2018 edition, a mirror on the French federation's
  site: <https://www.ffjd.fr/fichiers/reglements/FMJD_Annexes_2018_en.pdf>; the 2024
  edition's URL on fmjd.org was dead). Annex 6: rapid is 15 to 30 minutes per player, blitz
  5 to 15, Fischer increment obligatory in official FMJD events; no category below blitz.
  Annex 3: classical is by default 80 minutes plus 1 minute a move. Events use rapid
  15+10 and blitz 5+3 (European rapid and blitz 2025, from a search summary of its score
  table, not read). Flag fall: the player whose time runs out loses (Annex 6, art. 7.1;
  Annex 3, art. 6.11), with no draw when the opponent couldn't win.
- **IDF, 8×8 "draughts-64"** (Regulations of official competitions, in force 1 January 2017:
  <https://idf64.org/wp-content/uploads/2016/09/IDF_Rules_of_Official_competitions_rus-01.01.2017.pdf>,
  art. 10.2). Classical: 45 minutes, or 45+30, 45+15, 45+10, 25+10, 25+5, 20+10, 20+5.
  Rapid ("быстрая игра"): 10 minutes, or 10, 7, 6, or 5 minutes plus 3 or 5 seconds.
  Lightning ("молниеносная игра", blitz): 3 minutes, or 3+2, 3+3. The Russian federation's
  own regulation wasn't found.
- **Lidraughts** (the main server for both): quick-pairing pools 1+0, 2+1, 3+0, 3+2, 5+0,
  5+3, 10+0, 15+15 (`modules/pool/src/main/PoolList.scala` in
  <https://github.com/RoepStoep/lidraughts>). Categories by estimated game length:
  bullet under 3 minutes, blitz 3 to 8, rapid 8 to 25, classical 25 and more
  (`Speed.scala` in <https://github.com/RoepStoep/scaladraughts>). The estimate's formula
  wasn't checked; Lichess, which Lidraughts forks, counts base plus 40 increments.
- Estonian blitz ("välkkabe") rules weren't found.

So "blitz" means 5+3 under FMJD and in events, and 3+2 under IDF for 8×8, where 5+3 counts
as rapid. Proposed presets for the app: no clock (the default), **5+3**, and **10+5**,
both in IDF's rapid list and FMJD's blitz range, and gentle enough for children; 3+2 only
if the older child asks for it.

## Settled (2026-11-07)

- The game screen is take d of four (`prototypes/game.html`, rendering.md "Game
  screen"): the board between the way out (home, settings, start over) and the play
  (whose turn or the clocks, take back), every control with its word. The hint button
  and the move-hints toggle are gone from the game; move hints stay in settings. The
  other takes and the old prototypes were removed.
- Clocks: no clock, 5+3, 10+5, against a friend and against the computer, chosen in a
  new game's setup on home (`prototypes/home.html?pick=computer`), which also picks the
  variant and the level.
- International 10×10 is the default variant once it exists (`docs/product.md`); the
  MVP stays Russian 8×8 until then.

## Acceptance criteria

- [x] Game panel takes in landscape and portrait, with labels, next to the current one
- [x] Blitz time controls recorded with sources; the clock prototyped on the game screen
- [x] The first start: variant cards and the tutorial's first pages, linked in order
  (`prototypes/first-start.html`, waiting for the user's review)
- [x] The chosen takes recorded in `docs/architecture/rendering.md` once the user picks
