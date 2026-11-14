# 02: Settings looked at afresh

Status: in-progress

With the turning moved to the setup (01) and the board's material added (03), settings
looked at again: it had two glass groups and, on a phone, tabs.

The user picked take b of `prototypes/settings-takes.html` (the material folded into the
Board row), with changes (2026-11-13): one list for every size, Background
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

Measured headless (`test/shell/settings_sizes`): every tile 88 × 88 dp at least at every
size `test/shell/sizes` checks, the preview at least `board::SMALLEST` (182 dp in the iPad's
smallest window), the Board row's pictures on one line at every phone size (7 dp apart on
the iPhone 13 mini in portrait, Estonian 5).
