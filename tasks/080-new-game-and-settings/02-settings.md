# 02: Settings looked at afresh

Status: in-progress

Settings today: two glass groups, Game (move hints, the move list) and Look (theme with
its photograph or plain switch, board flat or raised with the turning, kings), the
language in the title row, the privacy note in the Game group's head, the preview board
beside them. Where both groups don't fit (a phone), two tabs show one at a time. With the
turning moved to the setup (01) and the board's material added (03), look at it again.

Takes in `prototypes/settings-takes.html`, each at the tablet's and the phones' sizes in
both orientations:

- **now**: today's screen with the material row added, for comparison.
- **a**: one list that scrolls, no tabs: Look first (what is changed most, beside the
  preview that shows it), then Game, then the language and the privacy note at the foot.
  On a phone in portrait the preview is a band at the top, smaller.
- **b**: the material folded into the Board row: Flat, Raised (the season's own), Wood,
  Stone, each with a picture of the board; no row that means nothing on a flat board.
- **c**: the preview leads: a large board, the Look rows on a sheet over its foot that
  scrolls up into Game and the rest.

## Acceptance criteria

- [ ] The takes; the user's pick
- [ ] Settings built to it, every tap 88 dp, the preview at least `board::SMALLEST`
- [ ] Checked on the Mac (tablet, Pixel 7a, iPhone 13 mini sizes, a small iPad window),
      then on the tablet
