# 092: About dialog, and the battery saver's frame cap

Status: in-progress (built 2026-11-17; the devices not yet checked)

A small About row at the foot of settings opens a card of what the app is built from and
draws with (`prototypes/settings.html?about=tablet`): the version and commit, the system,
the renderer, its driver and GPU, the display's rate, the battery saver, and what the 3D
board uses now (its antialiasing, shadow taps, and bake side), with a note under a value
the app lowered by itself. Copy puts it all on the clipboard, for bug reports. No
graphics settings (`docs/decisions/rendering.md`, "Settings").

The system's battery saver is read at start and whenever the app gets the focus back.
While it is on, Android asks for 60 Hz; iOS caps itself and a desktop isn't capped. The
3D board's quality stays: lowering it on phones and tablets only if a measurement shows
it saves enough.

## Done (2026-11-17)

1. Every build writes `build/draughts_version.h` (`scripts/native.py`, also the ngfx
   crash marker's key now): the version, the commit with `-dirty` for a changed tree, and
   the commit's date; a plain `goose build` says `dev`.
2. The About row and card (`src/shell/about.goose`), strings in English and Estonian,
   40 dp tiles each with a tap round it; `test/shell/settings` taps through it, and
   `settings_sizes` counts a small tile's tap.
3. The app fills it (`fill_about`, `src/native/about.c`); Copy through `gfx::set_clipboard`.
4. The battery saver read per platform (`draughts_battery_saver`), shown in the card, and
   Android's 60 Hz (`draughts_cap_60`).

Checked on the Mac: gfx and ngfx headless at the tablet's, a phone's landscape and
portrait sizes; a window showing 120 Hz and the saver off; Copy (Tab, Enter) put the
card's text on the clipboard. Android and the iOS simulator build.

## Acceptance criteria

- [x] The dialog shows the right values on the Mac (both renderers)
- [ ] And on the tablet, the A33 (2× MSAA's note), and the iPhone: the system, the GPU's
      name from Vulkan, the display's rate
- [x] Copy puts the dialog's text on the clipboard (the Mac)
- [x] The row and dialog fit every screen size (`test/shell/sizes`, `settings_sizes`)
- [ ] Battery saver on an Android device: the card says On, and a 90 or 120 Hz display
      presents at 60 (`dumpsys SurfaceFlinger --timestats`); off again on return
- [ ] The Estonian strings reviewed (`agents/writing.md`, "Reviewing a translation")
- [x] Decisions and architecture docs updated
