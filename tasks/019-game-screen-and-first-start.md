# 019: Prototype the game screen's controls, a clock, and the first start

Status: todo

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

## Open with the user

- Which variant is the go-to: the user named 10×10 international and 8×8; the MVP in
  `docs/product.md` is Russian 8×8 with International after it. Settle the order before
  changing the product scope.

## Acceptance criteria

- [ ] Game panel takes in landscape and portrait, with labels, next to the current one
- [ ] Blitz time controls recorded with sources; the clock prototyped on the game screen
- [ ] The first start: variant cards and the tutorial's first pages, linked in order
- [ ] The chosen takes recorded in `docs/architecture/rendering.md` once the user picks
