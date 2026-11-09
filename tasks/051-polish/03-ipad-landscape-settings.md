# 03: Both settings groups in an iPad's landscape

Status: done

On a 13" iPad in landscape, settings shows tabs: with the status bar's and the home
indicator's insets (19 and 16 dp) both groups need 620 dp and have 619 (2026-11-09,
`e2e7baa`). The top padding under a top inset is the likely place to find it.

## Acceptance criteria

- [x] Both groups side by side in a 13" and an 11" iPad's landscape; phones unchanged

## Done (2026-11-09)

In landscape under a top inset the page's top padding gives up to 12 dp (`TOP_RISE`),
the status bar already keeping the head from the screen's edge. Measured with the real
font in the headless copy: the groups need 620 dp; the 13" (insets 18.6 and 15.5 dp) had
619.4 and now 631.4, the 11" (23.0 and 19.2 dp) had 615.0 and now 627.0. Phones and the
Galaxy tablet have no top inset in landscape, so nothing else moves: `sizes` gained the
two iPads' landscape (both groups, in both languages; one group each without the
change), its other lines unchanged.
