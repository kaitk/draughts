# 010: Propose our goose_gfx changes upstream

Status: todo

Each workaround in `docs/goose-findings.md` that belongs in goose_gfx goes upstream, so our
patches shrink to nothing and the Android build can drop its copy of goose_gfx's sources.
The user contributes to goose_gfx; prepare each change as a small, tested patch and
description, and let the user send it.

## Acceptance criteria

- [ ] Clip distance off at device creation (`patches/goose_gfx/0001-no-clip-distance.patch`),
      checked on macOS too
- [ ] `ui::input_from_gfx` starts SDL text input only while a text field has focus
- [ ] A way to wait for events instead of polling, once task 005 has one that works
- [ ] Possibly an Android path in goose_gfx's CMake (shared SDL), if upstream wants it
- [ ] Not ours to send: the SDL swapchain leak (`patches/SDL/`). SDL takes no
      AI-written reports or code, so the user reports it in their own words, or a newer
      SDL with a fix arrives through a goose_gfx pin bump
- [ ] After each lands: bump the Goose release and the goose_gfx pin together
      (`docs/development.md`), delete the patch, update `docs/goose-findings.md`
