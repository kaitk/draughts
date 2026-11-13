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

The user picked take b, with changes (2026-11-13): one list for every size, Background
before Theme, the Board row's Raised the season's own board whole with an "auto" tag and
its materials each a picture of the board's near left corner, Carved a third material,
and the language a button in the title row (a wireframe globe, the code, a chevron)
opening a small list, its section at the list's foot gone.

## Acceptance criteria

- [x] The takes; the user's pick
- [x] Settings built to it, every tap 88 dp, the preview at least `board::SMALLEST`
- [x] Checked on the Mac (tablet, Pixel 7a, iPhone 13 mini sizes; the small iPad window
      headless only)
- [ ] Checked on the tablet

## Built (2026-11-13)

`src/shell/settings.goose` rewritten: one list on one glass under the title row, the
fade at its foot, a 480 dp column in landscape (544 dp with its glass) and a sheet under
the preview's band in portrait. The Board row's pictures are an atlas of `build/board3d`
shots (`scripts/board_thumbs.py`, `design/boards/`, 640 × 420: 81 KB as JPEG, 117 KB as
ASTC) copied into the seasons' thumbnail texture, now 160 × 2520 (1.6 MB, from 0.5). The
language list's rows are 88 dp, not the prototype's 72, for the tap floor. Back keeps its
word beside the arrow where it fits, as on every screen, where the prototype has the bare
arrow.

Measured headless (`test/shell/settings_sizes`, the test faces' words, wider than the
real font's), the Raised board's 3D bounds with its flat square:

| Size | The list | View, scrolls | Preview: flat, 3D | Picture rows |
| --- | --- | --- | --- | --- |
| Tablet 1280 × 800 dp | column, 544 dp | 688 dp, 267 | 692 dp, 692 × 474 | one line, 10 dp apart (Estonian's board row 8) |
| Tablet 800 × 1280 dp | sheet from 512 dp | 656 dp, 282 | 481 dp, 702 × 481 | one line, 10 apart |
| Pixel 7a 1200 × 540 dp, insets 59, 0, 0, 42 | column | 428 dp, 569 | 468 dp, 561 × 385 | one line, 10 apart (8) |
| Pixel 7a 540 × 1200 dp, insets 0, 59, 0, 42 | sheet from 330 dp | 700 dp, 298 | 310 dp, 452 × 310 | one line, 10 apart |
| iPhone 13 mini 1083 × 500 dp, insets 67, 0, 67, 28 | column | 388 dp, 595 | 381 dp, 381 × 261 | one line, 10 apart (8) |
| iPhone 13 mini 500 × 1083 dp, insets 0, 67, 0, 45 | sheet from 291 dp | 613 dp, 387 | 274 dp, 399 × 274 | one line, 7 apart (Estonian 5) |
| iPad's smallest window 499 × 645 dp | sheet | 340 dp, 616 | 182 dp | |

Every tile is 88 × 88 dp at least at every size `test/shell/sizes` checks, the language
list's rows 208 × 88 dp. Shots (Mac, `--frames`): every material raised in autumn and
winter, the tablet both ways, the Pixel 7a and the iPhone 13 mini both ways, the list
scrolled to Game, Estonian, and the language list open (the session's scratchpad,
`settings/`).
