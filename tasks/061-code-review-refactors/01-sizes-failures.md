# 01: Stage 0, the failures saved in `sizes`

Status: todo

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

- [ ] Every saved failure fixed, or allowed with its reason
- [ ] `sizes` fails on a new failure (checked by breaking a layout on purpose, then
      reverting)
- [ ] The fixed layouts checked on the Mac, landscape with insets; on a device only if
      the Mac can't tell
