# Development

Built on macOS (Apple silicon). The tablet is a Galaxy Tab A11+ (SM-X230, Android 16,
MediaTek MT6878 with a Mali-G615 MC2, Vulkan 1.3).

## Toolchain

Tested 2026-11-07 on macOS 26.3.1:

| Tool | Where | Version |
| --- | --- | --- |
| Goose | `build/goose-v2026.4-macos-arm64/`, from the [release](https://github.com/aardappel/goose/releases/tag/v2026.4); `GOOSE` overrides it | v2026.4, with gfx, ui, and audio built in |
| goose_gfx | `third_party/goose_gfx` submodule, with SDL and Nuklear as its submodules | `6cfa3de`, the commit v2026.4's gfx package matches |
| Android SDK | `~/Library/Android/sdk`; `ANDROID_HOME` overrides it | platform 36, build-tools 36.0.0, platform-tools |
| Android NDK | `$ANDROID_HOME/ndk/29.0.14206865`; `ANDROID_NDK` overrides it | r29 |
| JDK | `javac` on `PATH` | OpenJDK 21 |
| CMake, Ninja | Homebrew | CMake 4.4.4 |
| Python | `python3` | 3.x |

Set up from a fresh clone:

```sh
git submodule update --init --recursive --depth 1
mkdir -p build && cd build
gh release download v2026.4 -R aardappel/goose -p 'goose-v2026.4-macos-arm64.tar.gz'
tar -xzf goose-v2026.4-macos-arm64.tar.gz && rm goose-v2026.4-macos-arm64.tar.gz
cd ..
$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager --install \
    "ndk;29.0.14206865" "platforms;android-36" "build-tools;36.0.0" "platform-tools"
brew install ninja
```

When the Goose release changes, pin goose_gfx to the commit whose `src/`, `gfx.goose`, and
`CMakeLists.txt` match the release's `pkg/gfx/`, so Android and desktop compile the same
gfx layer.

## Run on the Mac

```sh
cd app && ../build/goose-v2026.4-macos-arm64/goose kabe.goose
../build/goose-v2026.4-macos-arm64/goose kabe.goose -- --theme sea --size 800x1280
../build/goose-v2026.4-macos-arm64/goose kabe.goose -- --fen W:Wc3,e3,Kh2:Bd4,f6 --tap c3 --frames 30
```

`app/kabe.goose` is the app; its development flags pick the board theme (`wood`,
`stone`, `birch`, `sea`; the season's by default, with its photograph), the window size, a
starting position, squares to tap on the first frames, move hints (`--hints moves` shows
the targets; mistakes only by default), and a frame to stop at and save as `kabe.png`.
`app/kabe.build` adds the program's own C (`app/background.c`, the photographs and their
JPEG decoder), which `scripts/android.py` builds into the APK too. The photographs are
embedded from `design/backgrounds/masters/` when they are there; without them the board
sits on the page color. goose caches the program's C by its source, so after adding or
changing a master, touch `app/background.c`. The
board's logic is the `board/` package, tested headless (`test/board/`). `poc/` keeps
task 001's and task 005's small programs.

## Test the rules

```sh
test/run_tests.py           # test/<area>/*.goose against test/expected/, through TinyCC
test/run_tests.py --build   # the same, each built natively at -O2
test/run_tests.py --bless   # write each test's output as its expected output
scripts/test.sh             # all of the above, then perft and the random-game check
```

`scripts/test.sh` also builds `tools/perft.goose` into `build/perft`, which counts moves
from a position (`build/perft russian 9`, `build/perft international 8 FEN --divide`), and
runs `test/perft.py compare`: random games, with every position's legal moves checked
against an independent Python generator. It takes about 20 seconds. On an M-series Mac
the native perft runs at 12 to 16 million positions a second.

## Run on the tablet

The tablet needs Developer options with **USB debugging** on, and Samsung's **Auto
Blocker** off (Settings → Security and privacy), which otherwise blocks USB debugging
and sideloading. Use USB mode **Transferring files** and allow the Mac's key.
`adb devices` should list it.

```sh
scripts/android.py app/kabe.goose --run     # build, install, start
adb logcat -s goose:* SDL:*                 # the program's output and SDL's log
```

`scripts/android.py` builds without Gradle, into `build/android/<program>/`:

1. Goose writes the program's C (`goose -o`) and the runtime's C (`goose --emit-runtime`).
2. goose_gfx's `src/` is copied, and `patches/goose_gfx/*.patch` applied to the copy.
   SDL is copied to `build/android/SDL_src/` and `patches/SDL/*.patch` applied, again only
   when SDL's commit or a patch changes.
3. CMake with the NDK toolchain builds `android/CMakeLists.txt`: `libSDL3.so` and
   `libmain.so` (the program, the runtime, goose_gfx's layers, and
   `android/stdio_to_logcat.c`). The program's `main` is compiled as `SDL_main`.
4. `javac` and `d8` compile SDL's stock Java (`SDL/android-project/.../org/libsdl/app`).
5. `aapt2` links `android/AndroidManifest.xml`. `zip` adds the dex and the stripped
   libraries, stored uncompressed. `zipalign -P 16` aligns them to 16 KB pages, and
   `apksigner` signs with `~/.android/debug.keystore`, which it creates if missing.

The POC's APK is 2.8 MB: `libSDL3.so` 1.9 MB and `libmain.so` 0.9 MB stripped, SDL's dex
43 KB.

The CMake build directory is configured once. Delete `build/android/<program>/native`
after changing `android/CMakeLists.txt`.

On Android the program opens with `gfx::WINDOW_FULLSCREEN`, which SDL turns into an
immersive window with the system bars hidden. It knows it's on Android from
`ANDROID_ROOT` in the environment ([findings](goose-findings.md)). Act on taps with
`gfx::mouse_pressed` and `gfx::mouse_released`: a tap can press and release within one
frame, which `gfx::mouse_down` never sees. `adb shell input tap X Y` checks it.

## Check idle CPU

```sh
adb shell svc power stayon usb     # keep the screen on: Android pauses the app when it sleeps
scripts/idle_cpu.sh 60             # with the app running on the tablet, untouched
adb shell svc power stayon false
```

It prints the CPU time of the thread running the program and of the whole process, and
how many times the program's thread went to sleep. An idle board should use a fraction
of a percent of a core with about one wakeup a second
([rendering](architecture/rendering.md#frames-and-battery)).

## Check memory over the Android lifecycle

```sh
scripts/lifecycle_memory.sh 20     # with the app running on the tablet
```

Each cycle goes home and back, then rotates to portrait and back. It prints PSS, native
heap, and graphics memory per cycle and any errors in logcat, then restores the rotation
settings. Graphics memory should stay flat apart from short driver spikes. On 2026-11-07,
`poc/poc.goose` held it at 112 to 114 MB over 20 cycles, with the native heap at 25 MB
and the same process throughout.
