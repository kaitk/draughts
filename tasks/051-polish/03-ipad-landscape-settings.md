# 03: Both settings groups in an iPad's landscape

Status: todo

On a 13" iPad in landscape, settings shows tabs: with the status bar's and the home
indicator's insets (19 and 16 dp) both groups need 620 dp and have 619 (2026-11-09,
`e2e7baa`). The top padding under a top inset is the likely place to find it.

## Acceptance criteria

- [ ] Both groups side by side in a 13" and an 11" iPad's landscape; phones unchanged
