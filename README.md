# Draughts

A calm draughts app for children and families, on an Android tablet. It plays
International (10 × 10), Russian, and Brazilian draughts, against a friend on the same
tablet or a computer player at three levels, with an optional clock, and has puzzles to
solve. No ads, no accounts, no tracking, and no network.

It is made for children of about 5 to 8: icons first, big touch targets, and help that
doesn't do the thinking for them ([docs/product.md](docs/product.md)).

Draughts is written in [Goose](https://github.com/aardappel/goose), compiled to C, and
drawn with SDL3's GPU API through Vulkan on Android and Metal on the Mac. No engine, no
allocation in the frame loop, and no frames drawn while idle.

## Status

Version 0.1.0. The MVP is done and runs on a Galaxy tablet and a Pixel phone; a Google
Play release is being prepared. Every screen fits phones and tablets in both
orientations. English is the default language, with Estonian as a translation.

## Build and run

On a Mac with Apple silicon, from a clone with its submodule and the pinned Goose release
in `build/` ([docs/development.md](docs/development.md#toolchain) sets these up):

```sh
cd app
../build/goose-v2026.4-macos-arm64/goose build -o ../build/draughts draughts.goose
../build/draughts
```

On an Android device with USB debugging on, with the Android SDK, NDK r29, and a JDK:

```sh
scripts/android.py app/draughts.goose --run     # build the APK, install it, start it
```

The build uses no Gradle. Tests run headless:

```sh
python3 test/run_tests.py
scripts/test.sh                 # also perft and a random-game check of the rules
```

[docs/development.md](docs/development.md) has the toolchain, the app's development
flags, the Android build step by step, and how to measure idle CPU and memory.

### The photographs

The app draws a photograph per season behind the board. The photographs are not in the
repository: they are local, and `design/backgrounds/README.md` says how they were made.
A build without them shows the board on the plain page color of the season's theme,
which is also what a GPU without ASTC shows on Android.

## Layout

```text
app/          the app's entry, draughts.goose, and its own C (photographs, locale, display)
rules/        the rules of each variant, pure functions with no graphics
ai/           the computer player
board/        the board's logic and drawing
gui/          the UI layer: layout, glass, buttons, text
game/         the game screen and its clock
shell/        home, settings, the puzzle picker, and which screen shows
puzzles/      the puzzles and their checks
strings/      the string tables, one file per language
assets/       the fonts
android/      the manifest, the activity, resources, and the native build
scripts/      the Android build, the icon, and device measurements
tools/        perft, computer-player benchmarks, a terminal player, the puzzle checker
test/         headless tests with expected output
patches/      patches to goose_gfx and SDL, applied to a copy at build time
third_party/  goose_gfx, as a submodule, with SDL and Nuklear
prototypes/   HTML prototypes of the UI
design/       how the photographs and the icon are made
docs/         product scope, architecture decisions, development
tasks/        one file per task, open and archived
poc/          the first programs that checked the stack
```

## Docs

- [docs/product.md](docs/product.md): what the app is for, the MVP, and what follows
- [docs/architecture/](docs/architecture/README.md): the decisions and why: rules, the
  computer player, puzzles, rendering
- [docs/development.md](docs/development.md): the toolchain, building, running, testing
- [docs/goose-findings.md](docs/goose-findings.md): gaps found in Goose and goose_gfx
- [tasks/](tasks/README.md): the work, one file per task

## Planned

- A Google Play release, for children under Google's Families Policy.
- Puzzles grouped by theme, from first captures to shots.
- Players, one per child, each with a picture and their own progress.
- A 3D board drawn from the same game state.
- Small seasonal effects over the background, such as falling snow.
- An announcement once it is on Play.

## Developed with AI coding agents

Most of the code and docs are written with AI coding agents, directed and reviewed by
the author. [AGENTS.md](AGENTS.md) and [agents/](agents/) hold the rules they follow;
they are kept in the repository because they record how the project is worked on.

## License

Licensed under either of the [Apache License, Version 2.0](LICENSE-APACHE) or the
[MIT license](LICENSE-MIT), at your option. Unless you state otherwise, any
contribution you submit for inclusion, as defined in the Apache-2.0 license, is
licensed the same way, without any additional terms or conditions.

Third-party parts keep their own licenses:

- [Goose](https://github.com/aardappel/goose), the language and runtime, and
  [goose_gfx](https://github.com/aardappel/goose_gfx): Apache 2.0.
- [SDL](https://github.com/libsdl-org/SDL) and Nuklear, through goose_gfx: zlib, and
  public domain or MIT. Nuklear's copy of `stb_image.h` (public domain or MIT) decodes
  the photographs on the Mac.
- The fonts in `assets/fonts/`, [Libertinus Sans](https://github.com/alerque/libertinus)
  and [Tenor Sans](https://fonts.google.com/specimen/Tenor+Sans): SIL Open Font License
  1.1, with the license beside each font.
