# 01: Stage 0, the failures saved in `sizes`

Status: done (2026-11-10)

`test/shell/sizes.goose` drives every screen across many sizes:

- foldable, 4:3, 20:9, and 9:16 shapes;
- 800, 540, and 480 dp;
- English and Estonian;
- Pixel insets on both sides, the tablet's navigation bar, the iPad's bars, the small
  window, and the handover.

For each run it lists what is wrong: tiles outside the safe area, tiles overlapping,
taps under 88 dp, or tiles over the board. `test/expected/sizes.out` (827 lines) is its
golden output.

The golden output has failures saved into it, and none of them is in a task or a doc:

- `home: … tiles 0 and 1 overlap;` on landscape phones with insets, 8 times (for example
  `sizes.out:437`, `:485`).
- `home's chip, named: 88 dp wide …; the pill wrong;`, 12 times (for example `:21`,
  `:53`).

A new failure looks the same as these in a diff, so a regression can hide among them.

## Steps

1. For each saved failure, find whether the layout is wrong or the check is stale. Look
   at the case on the Mac with the flags `sizes` uses (`--dp`, `--inset`, a size), and
   take a shot only where the numbers don't settle it.
2. Fix the layouts that are wrong (`src/shell/home.goose`, its `frame` at about
   153–275, and the who chip).
3. Fix the checks that are stale.
4. Make `sizes` exit non-zero when its "wrong" list has anything not on an explicit
   allow-list. Each allowed entry carries its reason in a comment.
5. Bless `sizes.out` again and read its diff line by line.

## Acceptance criteria

- [x] Every saved failure fixed, or allowed with its reason
- [x] `sizes` fails on a new failure (checked by breaking a layout on purpose, then
      reverting)
- [x] The fixed layouts checked on the Mac, landscape with insets; on a device only if
      the Mac can't tell

## Outcome

- **The overlaps were real.** Home's gear has an 88 dp tap that reaches 8 dp under the
  wordmark's row, but the gap under the row went down to 4 dp. On a landscape phone at
  480 dp less its gesture bar (the Pixel 7a), the tap reached about 3 dp into Continue's.
  A press there fired both. Fixed: the gap never goes under the gear's reach, and the
  rows close up from 2 dp apart to about 1 where that leaves too little room
  (`home::row_gap`). A small window's menu (compact) had the same overlap, 4 dp, which
  `sizes` didn't check. Its gap is now 12 dp instead of 8, and the board there is 187 dp
  instead of 191. `sizes` now checks home in the small window too.
- **The pill check was stale.** With a name too long to keep 16 dp from the X or the
  board, the chip is round on purpose: the badge alone, with no pill
  (`home::player_spot`). The check now expects a pill only on a chip wider than its
  badge, and the line says "round".
- **One more saved failure was already accepted:** the small window's 72 dp tiles (home's
  rows and the game's bar), accepted for compact only (the user, 2026-11-09). It is on
  the allow-list.
- **`sizes` exits 1 on any failure not on `ALLOWED`**, and prints how many lines failed.
  Checked by setting home's `ROW_GAP` to −6: exit 1, 51 lines. Reverted, it exits 0.
- **Mac shots:** `--size 1200x540 --dp 480 --inset 52,0,0,37` (the Pixel in landscape)
  and a 374 × 484 window. The gear sits clear of the first row in both. No device
  check: nothing here is beyond what the Mac shows.
- **Not measured:** the change is two sums in home's layout, with nothing added per
  frame. The task is measured once, at its end.
