# 05: Settings' Game and Look tabs readable

Status: done

On a phone in portrait (the iPhone 13 mini, 2026-11-09), settings' Game and Look tabs
are light, clear glass over the photograph, so their words and icons are hard to read
over a bright background (autumn's sunlit trees). Give them the darker glass the panels
and the other buttons use, the selected tab still told apart as now.

## Acceptance criteria

- [x] The tabs readable over every season's photograph at the phones' sizes, both languages

## Done (2026-11-09)

Each tab sits on glass as back does (`gui::glass` under the tile, in `settings::tabs`), in
every layout that shows the tabs: the row under the title in a phone's portrait and the
title row in landscape. The chosen tab keeps its glow border and tint. Checked headless
on the iPhone 13 mini (500 dp, its insets) in autumn, English and Estonian, portrait and
landscape; no expected output changed.
