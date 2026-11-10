# Draughts

A calm draughts game for tablets and phones, on a flat 2D or a 3D board. Play the
computer or a friend, or solve puzzles. No ads, no accounts, no tracking, and no network.

<p align="center">
  <img src="docs/images/home-winter.webp" alt="Home on a tablet over the winter photograph: continue, a friend, the computer, puzzles, and settings beside the 3D stone board" width="49%" />
  <img src="docs/images/game-autumn.webp" alt="A game on the flat board over the autumn photograph: a selected piece that must capture two, and the squares of its capture" width="49%" />
</p>

## Features

- A flat 2D board, or a 3D one with light and shadow, its camera turned by hand on home
- International draughts on the 10 × 10 board, and Brazilian and Russian on 8 × 8
- Play the computer at three levels, or a friend on the same device; with no clock, or
  5 or 10 minutes each
- 166 puzzles in themes, from the rules in action to multi-piece shots, with stars
- Up to four players on one device, each with an animal badge, their own look, hints,
  stars, and saved game
- Move hints that wait until a move is wrong, then show the square and why
- Four seasonal looks, each a photograph with its own board: autumn wood, winter stone,
  spring carved stone, and summer sunset
- No ads and no in-app purchases; nothing leaves the device
- English and Estonian

## Tested on

Every phone and tablet below is arm64. The app needs Android 10 (API 29) or later with
Vulkan, or iOS 16 or later with Metal.

| Device | Chip (CPU) | GPU, API | System | Status |
| --- | --- | --- | --- | --- |
| Galaxy Tab A11+ (SM-X230) | MediaTek MT6878 | Mali-G615 MC2, Vulkan 1.3 | Android 16 | Plays in 2D and 3D; the main test device |
| Pixel 7a | Google Tensor G2 | Mali-G710 MC7, Vulkan | Android 17 | Plays in 2D and 3D |
| Galaxy A33 5G (SM-A336B) | Samsung Exynos 1280 | Mali-G68 MP4, Vulkan 1.3 | Android 16 | Plays in 2D at 90 Hz and 3D at 60 while it moves; the weakest tried |
| iPhone 13 mini | Apple A15 Bionic | Apple GPU, Metal | iOS 26 | Runs, a development build |
| iPad Pro 11-inch (M5), in the Simulator | The Mac's M1 Pro | Apple GPU, Metal | iPadOS 26.4 | Runs full screen and in resized windows, both orientations; the smallest windows still to fit |
| Mac with Apple silicon (M1 Pro) | Apple M1 Pro | Apple GPU, Metal | macOS | Runs in 2D and 3D; development and headless tests |
| Windows PC | AMD Ryzen 7 5800X3D | NVIDIA GeForce RTX 4090, Vulkan | Windows 11 | Runs in 2D and 3D; development, headless tests, and Android builds |

## Implementation

### Performance

Release builds in a game, 2026-11-10, frames as they reached the screen:

| Device | Display | 2D board | 3D board | Memory (2D / 3D) |
| --- | --- | --- | --- | --- |
| Galaxy Tab A11+ | 1920 × 1200, 90 Hz | locked 90 fps | locked 90 fps | 137 / 295 MB |
| Pixel 7a | 2400 × 1080, 60 Hz | locked 60 fps | locked 60 fps | 159 / 324 MB |
| Galaxy A33 5G | 2400 × 1080, 90 Hz | locked 90 fps | 60 fps (45 fps 1% low) | 116 / 275 MB |
| iPhone 13 mini | 2340 × 1080, 60 Hz | locked 60 fps | locked 60 fps | 59 / 204 MB |
| Windows PC | 2560 × 1440, 165 Hz | locked 165 fps | locked 165 fps | 258 / 477 MB |

At rest: under 0.35% of one core, no GPU work. The 3D board's extra memory is on the GPU.
[Full numbers and method](docs/architecture/rendering.md#the-releases-frames).

### How it works

- **Goose compiled to C**, on [goose_gfx](https://github.com/aardappel/goose_gfx) and
  SDL3's GPU API: Vulkan on Android and Windows, Metal on Apple. No engine, no Gradle, no
  Xcode project; one Python script per platform.
- **Draws only on change.** A touch, a moving piece, or a clock's tick draws a frame;
  otherwise the app sleeps in the system's event wait
  ([frames and battery](docs/architecture/rendering.md#frames-and-battery)).
- **Immediate-mode UI.** Screens are declared in code each frame, no widget tree. Every
  panel, icon, and glyph is a quad in one fixed array, drawn in one instanced call
  ([UI layer](docs/architecture/rendering.md#ui-layer)).
- **One layout code for every screen size.** Rows and grids are cut from the screen in
  dp, fitted to the safe area, and compacted in small windows; checked headless at each
  device's size ([screen sizes](docs/architecture/rendering.md#screen-sizes-and-the-safe-area)).
- **Shapes in shaders.** The flat board is one full-screen pass; pieces, rings, and glass
  are signed distance shapes, crisp at any size. Text is a Libertinus Sans atlas baked at
  the screen's pixel size.
- **No allocation in the frame loop:** fixed arrays reset each frame.
- **Rules as pure functions** over bitboards, checked against published perft counts.
  Rules, computer, puzzles, and UI are tested headless.
- **A computer that plays like a person** of its level, on its own thread, not an engine
  with noise added.

More in [docs/architecture/](docs/architecture/README.md): [rendering](docs/architecture/rendering.md),
[rules](docs/architecture/rules.md), [computer player](docs/architecture/ai.md),
[puzzles](docs/architecture/puzzles.md).

## Building and running

On a Mac with Apple silicon, from a clone with its submodule and the pinned Goose release
in `build/` ([docs/development.md](docs/development.md#toolchain) sets these up):

```sh
scripts/mac.py src/app/draughts.goose    # build build/draughts with the patched gfx
build/draughts
```

On Windows, `python scripts/windows.py src/app/draughts.goose` builds the same app
([development](docs/development.md#run-on-windows)).

On an Android device with USB debugging on, with the Android SDK, NDK r29, and a JDK:

```sh
scripts/android.py src/app/draughts.goose --run     # build the APK, install it, start it
```

For iOS, with Xcode (the Simulator, or an iPhone with a signing identity):

```sh
scripts/ios.py src/app/draughts.goose --run             # the Simulator
scripts/ios.py src/app/draughts.goose --device --run    # an iPhone
```

The tests run headless:

```sh
python3 test/run_tests.py
scripts/test.sh                 # also perft and a random-game check of the rules
```

The season photographs are not in the repository (`design/backgrounds/README.md` says how
they were made); a build without them shows the board on the season's plain color.
[docs/development.md](docs/development.md) has the rest: the toolchain, development
flags, the Android and release builds, and how to measure idle CPU and memory.

## Layout

```text
src/          the program: one directory per package, and the app
  rules/        the rules of each variant, pure functions with no graphics
  ai/           the computer player
  puzzles/      the puzzles and their checks
  board/        the board's logic and draw lists
  render3d/     the 3D board's renderer: meshes, shaders, and its looks
  gui/          the UI layer: layout, glass, buttons, text
  game/         the game screen and its clock
  shell/        home, settings, puzzles, players, and which screen shows
  badges/       the players' animal badges
  app/          the main loop, the GPU drawing, and the platform's C
strings/      the text, one file per language
assets/       the fonts and the badges
android/      the manifest, the activity, resources, and the native build
ios/          the iOS entry point and its native build
scripts/      the Android and iOS builds, the icon, and device measurements
tools/        perft, computer-player benchmarks, a terminal player, the puzzle checker
test/         headless tests with expected output
patches/      patches to goose_gfx and SDL, applied to a copy at build time
third_party/  goose_gfx, as a submodule, with SDL and Nuklear
store/        the Play and App Store listings, their previews, and the privacy policy
design/       the icon's, backgrounds', and tabletops' sources and how they were made
prototypes/   HTML prototypes of the UI, compared before building in Goose
poc/          small programs that tried one thing, such as frame pacing
docs/         product scope, architecture decisions, development
tasks/        the work, one file per task
```

## Documentation

- [Product](docs/product.md): what the app is for, the MVP, and what follows
- [Architecture](docs/architecture/README.md): the decisions and their reasons
- [Development](docs/development.md): the toolchain, building, running, and testing
- [Goose findings](docs/goose-findings.md): gaps found in Goose and goose_gfx, and the
  patches for them
- [Store](store/README.md): the Play and App Store listings and the privacy policy
- [Tasks](tasks/README.md): the work, one file per task

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
