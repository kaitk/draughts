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
| bundletool | `build/bundletool-1.18.3/`, from the [release](https://github.com/google/bundletool/releases/tag/1.18.3), fetched by `scripts/android.py --release` | 1.18.3 |
| Xcode | `/Applications/Xcode.app`, for the iOS SDKs, clang, `simctl`, and `devicectl` | 26.4, an iOS 18.3 simulator runtime |
| astcenc | `build/astcenc-5.7.0/bin/astcenc`, from the [release](https://github.com/ARM-software/astc-encoder/releases/tag/5.7.0) (Apache 2.0; not in Homebrew) | 5.7.0, macOS universal |

Set up from a fresh clone:

```sh
git submodule update --init --recursive --depth 1
mkdir -p build && cd build
gh release download v2026.4 -R aardappel/goose -p 'goose-v2026.4-macos-arm64.tar.gz'
tar -xzf goose-v2026.4-macos-arm64.tar.gz && rm goose-v2026.4-macos-arm64.tar.gz
gh release download 5.7.0 -R ARM-software/astc-encoder -p 'astcenc-5.7.0-macos-universal.zip'
unzip -q astcenc-5.7.0-macos-universal.zip -d astcenc-5.7.0 && rm astcenc-5.7.0-macos-universal.zip
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
cd src/app
../../build/goose-v2026.4-macos-arm64/goose build -o ../../build/draughts draughts.goose
../../build/draughts
../../build/draughts --theme sunset --size 800x1280
../../build/draughts --fen W:Wc3,e3,Kh2:Bd4,f6 --tap c3 --frames 30
```

The app is built, not run through `goose run`: the computer thinks on a worker thread
(`src/app/think.goose`), and `goose run` refuses a program that starts one. The build takes
about 3 s, and the flags follow the executable with no `--`. `src/app/draughts.goose` is the
app; its development flags (each a field of `Flags` in `src/app/flags.goose`, the one list
of them) pick the board theme (`wood`, `stone`, `birch`, `sunset`; the
season's by default, with its photograph), the window size, a starting position,
squares to tap on the first frames, move hints (`--hints moves` shows the targets;
mistakes only by default), the language (`--lang et`; the system's by default), the
layout's shorter side in dp (`--dp 540`; 800 by default, for trying phone scales;
`gui::scale_of`), a phone's insets (`--inset L,T,R,B`, in dp of the layout, left,
top, right, bottom; the window's own safe area by default, all of it on the Mac), the
scale's floor in physical size (`--density-floor F` with `--display-scale S`: the scale
becomes `max(short side / 800, F × S)`; off by default, and `--dp` turns it off unless
`--density-floor` is given too; the Mac's own display scale is left out, so without
`--display-scale` the floor does nothing there), and a frame to stop at and save as
`draughts.png`. The Pixel 7a in portrait at 540 dp, its 118 px cutout and its 84 px
gesture bar, 2 px a dp at that scale: `--size 450x1000 --dp 540 --inset 0,59,0,42`,
and in landscape `--size 1200x540 --dp 540 --inset 59,0,0,42` (or `0,0,59,42`, turned
the other way). What the Pixel would show at a floor of 0.75: `--size 1200x540
--density-floor 0.75 --display-scale 2.625` (1.97 px a dp, 548 dp across).
`src/app/draughts.build` adds the program's own C (`src/app/background.c`, the photographs, made
into textures through gfx's C API, and, on the Mac only, their JPEG decoder;
`src/app/locale.c`, the system's locales; `src/app/display.c`, the window's safe area and the
display's scale; `src/app/wake.c`, the timer a running clock wakes the
loop with; `src/app/memory.c`, which gives back on Android the memory malloc keeps for
what the launch freed; `src/app/launch.c`, which tells the activity the first frame is on screen, and
to close and leave recents after home's X), which `scripts/android.py` builds into the APK too. The photographs are
embedded from `design/backgrounds/masters/` when they are there (the JPEGs, and the ASTC
files `design/backgrounds/README.md` says how to make with astcenc); without them the
board sits on the page color. goose caches the program's C by its source, so after
adding or changing a master, touch `src/app/background.c`. The Mac's `goose build` links the
release's prebuilt gfx, which has no compressed formats, so the Mac decodes the JPEGs;
the Android build's gfx is patched and takes the ASTC files, and embeds only those, not
the JPEGs ([rendering](architecture/rendering.md#scene-and-glass)). To see the ASTC path on the
Mac, compile goose_gfx's `src/gfx/*.c` with `patches/goose_gfx/0004-*.patch` applied
(`clang -c -O2 -DNDEBUG -I third_party/goose_gfx/third_party/SDL/include`), archive them
as `pkg/gfx/lib/libgoose_gfx.a` in a copy of the release (the rest linked), and build
with that copy's `goose`. The
board's logic is the `board/` package, the UI layer `gui/`, the game screen `game/`, and
the screens around it `shell/` (home, and which screen shows), each tested headless
(`test/board/`, `test/gui/`, `test/game/`, `test/shell/`). The app opens at home; `--fen`,
`--tap` (`c3`, or `d10` on 10 × 10), or `--screen game` open the game screen,
`--screen settings` settings, `--screen friend` or `computer` home's setup, `--screen
puzzles` the puzzles to pick from, and `--puzzle ID` that puzzle, whose taps go to its
board (`--puzzle 21 --tap f4 --tap e5`). `--go settings` (or `home`, `game`, `play`,
`puzzles`, `puzzle`) switches there on the second frame through its transition, once
any `--tap`s have played out, and `--hold 0.4` keeps a transition at 40% of the way, for
a screenshot: `--go settings --hold 0.5 --frames 12`, or `--screen settings --go home
--hold 0.5 --frames 12` for the way back. `game` goes as continue does, `play` as the
setup's play (`--screen friend --variant russian --go play`; it leaves the player's file
alone), `puzzle` from the puzzles to pick from (`--screen puzzles --go puzzle --puzzle
21`), and `puzzles` back to them (`--puzzle 21 --go puzzles`). `--hold 1` ends the
transition at once, to shoot the screen reached through it. A won game's way home:
`--variant russian --fen W:Wa1,c1,g1,b2,h2,e3:Bf4 --tap e3 --tap g5 --win 3 --go home
--hold 0.5 --frames 3000`. `--win 1.2` keeps a win
at 1.2 s into its celebration: `--variant russian --fen W:Wa1,c1,g1,b2,h2,e3:Bf4 --tap
e3 --tap g5 --win 1.2 --frames 3000`. `--variant
international|brazilian|russian` starts a new game of that draughts (else the setup's
last choice), `--clock 5+3|10+5` with a clock, and `--computer white|black` against
the computer playing that side (the board turned when it plays white), at `--level
easy|medium|hard` (else the setup's last choice). With `--screen friend` or
`computer` those three set the setup's choices instead, the child playing the side
`--computer` doesn't, and leave the player's file alone unless a tap in the setup writes
it: `--screen computer --variant russian --computer white --frames 12` shows the
computer's setup for Russian with the child on black. A `--frames` run doesn't wait for the
display, so a screenshot of the computer's reply, which comes after a pause of under a
second, takes some thousands of frames: `--variant russian --computer black --tap c3
--tap d4 --frames 5000`. The settings are in the app's storage folder (on the Mac
`~/Library/Application Support/kaitk/draughts/`): `settings.txt` the device's (the
language, who plays), `player-N.txt` each player's ([players](architecture/README.md#players));
`--theme`, `--hints`, `--lang`, `--background`, `--board`, and `--lookout on|off` override them for a run
without changing them. `--board 3d` plays a run on the 3D board at once, as settings'
Board row's 3D does, and `--board flat` on the flat one; `--background plain` shows the
plain fade in place of the photograph, and `--background photo` the photograph. `--wood N`
(0 to 3) and `--marble N` (0 the slate, 1 to 4) pick the 3D board's wood and winter
frame's marble for the run, and `--summer N` (0 to 5) and `--spring N` (0 the
birch, 1 the carved stone, 2 the carved oak) summer's and spring's 3D looks.
`--reset-skill`, which takes no value, puts the playing player back to easy with the
computer's skill at every level at its start, and writes that to their file; stars and
games stay. Each player's game is kept in `game-N.bin` beside them; a
run with `--fen`, `--tap`, `--screen`, `--frames`, `--variant`, `--clock`, or
`--computer` neither reads nor writes it, so
screenshots don't depend on the last session. On the tablet, check a resume with
`adb shell input keyevent HOME`, `adb shell am kill io.github.kaitk.draughts`, and starting
the app again. The flags reach the tablet through the intent:
`adb shell am start -S -n io.github.kaitk.draughts/.DraughtsActivity --es args "'--clock 5+3'"`.
`-S` stops the app first: the activity is `singleInstance`, so a start that finds it
running only brings it back, with the flags it started with.
On Android a clock counts only while the app has focus; on the Mac, where a window
started from a terminal never has it, the clocks run while the window shows. `poc/` keeps
the first proofs of concept (Goose on Android, an idle frame that draws nothing) and the
3D board's prototype.

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

## Time the computer player

```sh
goose build -o build/aibench tools/aibench.goose && build/aibench   # each level's reply time
goose build -o build/lookbench tools/lookbench.goose && build/lookbench   # the lookout's threats and traps
goose build -o build/aimatch tools/aimatch.goose
build/aimatch russian 90 40 20      # skill 90 against 40, 20 games, colors swapped
goose build -o build/play tools/play.goose
build/play russian easy white       # play it yourself in the terminal
scripts/android_cli.sh tools/aibench.goose                          # the same on the tablet
```

`tools/aibench.goose` times each level in a few middlegames of Russian, International, and
Brazilian and prints its speed in nodes a second ([computer player](architecture/ai.md));
give it a variant and a FEN to time one position. `tools/aimatch.goose` plays the computer
against itself at two skills (`--nodes A B` gives each side its own node limit;
`--fens PLY` prints the positions games reach, for benchmarks; `--overlooks A B` scales
each side's overlooks in percent; `--hangs` counts each side's hung pieces in quiet and
tense positions). `tools/play.goose` lets you
play it in the terminal at a level or a skill (0 to 100) with either color: type a move
as its list shows it or its number, `u` to take back your move and its reply. `scripts/android_cli.sh`
builds any headless Goose program as a plain Android executable with the NDK's clang at
-O2, pushes it to `/data/local/tmp`, and runs it with the arguments given: no APK, no SDL.
`adb shell "taskset 0f /data/local/tmp/aibench"` keeps it on the tablet's four little
cores (`f0`, the big ones).

## Check the puzzles

```sh
goose build -o build/puzzles tools/puzzles.goose && build/puzzles    # every puzzle, and the engine's view
build/puzzles try 'W:W33,38,43,45,47,48:B3,11,21,23,24,29' 'take 2' 2  # what solves a position
build/puzzles find 'take 3' 2 7 7 6                                  # random shots to compose from
test/perft.py puzzles international src/puzzles/international.txt       # the lines, by the independent generator
build/puzzles --variant russian                                       # Russian's set, and the engine's view
build/puzzles try --variant russian 'W:Wh4,a5:Bg5,c7,e7,g7' 'take 3' 1
build/puzzles find black 'take 2' 2 7 7 6 --variant russian          # flags anywhere; --rows N, --tempo
test/perft.py puzzles russian src/puzzles/russian.txt                    # Russian's only independent check
test/perft.py puzzles brazilian src/puzzles/brazilian.txt
```

The app shows the set of the player's draughts; `--variant russian` picks Russian's for
a run (`--screen puzzles --variant russian`), the library's switch lit on it (in
memory: written to the player's file only if the run changes something, as a solved
puzzle's stars).

`test/puzzles/` runs the same checks on every puzzle without the engine
([puzzles](architecture/puzzles.md#checks)).

## Run on the tablet

The tablet needs Developer options with **USB debugging** on, and Samsung's **Auto
Blocker** off (Settings → Security and privacy), which otherwise blocks USB debugging
and sideloading. Use USB mode **Transferring files** and allow the Mac's key.
`adb devices` should list it.

```sh
scripts/android.py src/app/draughts.goose --run     # build, install, start
adb logcat -s goose:* SDL:*                 # the program's output and SDL's log
```

`scripts/android.py` builds without Gradle, into `build/android/<program>/`, with
`scripts/native.py`, which holds what it shares with `scripts/ios.py` (the app's id and
version, the Goose-to-C step, the patched copies, and the launcher's names):

1. Goose writes the program's C (`goose -o`) and the runtime's C (`goose --emit-runtime`).
2. goose_gfx's `src/` is copied, and `patches/goose_gfx/*.patch` applied to the copy.
   SDL is copied to `build/android/SDL_src/` and `patches/SDL/*.patch` applied, again only
   when SDL's commit or a patch changes.
3. CMake with the NDK toolchain builds `android/CMakeLists.txt`: `libSDL3.so` and
   `libmain.so` (the program, the runtime, goose_gfx's layers, and
   `android/stdio_to_logcat.c`). The program's `main` is compiled as `SDL_main`.
4. `javac` and `d8` compile SDL's Java from the patched copy
   (`SDL_src/android-project/.../org/libsdl/app`) and `android/java/`.
5. `aapt2` compiles `android/res` (the icon and the launch theme; `scripts/icon.py` makes
   the icon, `design/icon/README.md`) and links it with `android/AndroidManifest.xml`,
   giving the app its id, `versionCode`, and `versionName` from `APP_ID` and
   `VERSION_NAME` at the top of `scripts/native.py` (which iOS's build reads too) and
   `VERSION_CODE` at the top of the script, the one place each is set. The id is
   `io.github.kaitk.draughts`, the Java code's package too.
   The launcher's name follows the phone's language: the script writes
   `res/values/strings.xml` and `res/values-<lang>/strings.xml` into the build directory
   from each `strings/<lang>.txt`'s `app.name` key, and the manifest's label is
   `@string/app_name`.
   `zip` adds the dex and the stripped libraries, stored uncompressed. `zipalign -P 16`
   aligns them to 16 KB pages, and `apksigner` signs with `~/.android/debug.keystore`,
   which it creates if missing. The script checks that every library's ELF segments and
   its offset in the APK are on 16 KB pages, as Play requires.

The POC's APK is 2.8 MB: `libSDL3.so` 1.9 MB and `libmain.so` 0.9 MB stripped, SDL's dex
43 KB.

The CMake build directory is configured once. Delete `build/android/<program>/native`
after changing `android/CMakeLists.txt`.

On Android the program opens with `gfx::WINDOW_FULLSCREEN | gfx::WINDOW_RESIZABLE`,
which SDL turns into an immersive window with the system bars hidden. Resizable makes
SDL request `FULL_USER`, so the screen turns as the system's rotation lock allows
(Android turns the activity; SDL's own accelerometer, which `DraughtsActivity` keeps
off, plays no part);
without it SDL locks the activity to the orientation it started in, which phones obey
and large tablets ignore (found on the Pixel 7a, 2026-11-08). From Android 11 SDL lays
the window out under the camera's cutout too (`LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS`), so
the window is the whole display and the layout keeps its taps and words in the safe
area ([rendering](architecture/rendering.md#screen-sizes-and-the-safe-area)); on
Android 10, the app's lowest, the window keeps out of the cutout instead (the default
mode) and SDL reports no insets. It knows it's on Android from
`draughts_platform` (`src/app/launch.c`, [findings](goose-findings.md)). Act on taps with
`gfx::mouse_pressed` and `gfx::mouse_released`: a tap can press and release within one
frame, which `gfx::mouse_down` never sees. `adb shell input tap X Y` checks it.

Screens are checked at other sizes first on the Mac (`--size` at a device's proportions,
`--dp` and `--inset` for a phone, `test/shell/sizes` headless), then on two devices over
USB: the Galaxy Tab A11+ (1920 × 1200, three-button navigation) and a Pixel 7a (1080 ×
2400, Android 17, gesture navigation, a punch-hole camera), one attached at a time. A
Galaxy A33 5G (SM-A336B, 1080 × 2400 at 90 Hz, Android 16, Exynos 1280 with a Mali-G68
MP4, Vulkan 1.3, 5.5 GB) is the weakest phone tried (2026-11-09): 2D holds 90 Hz, the 3D
board ran at about 28 fps while it moved, about 39 since its frame cost's first cuts
([numbers](architecture/rendering.md#the-3d-board-on-devices)). On iOS an iPhone 13 mini
(A15 Bionic, iOS 26) runs the development build ("Run on iOS" below). The README's "Tested on" lists them all.
Larger tablets (2560 × 1600, 2880 × 1920, 4:3, a foldable's inner screen) are checked
only on the Mac (2026-11-08), as there is no such device.

## Run on iOS

```sh
scripts/ios.py src/app/draughts.goose --run                     # build, and run in the simulator
scripts/ios.py src/app/draughts.goose --shot build/ios/home.png # run, wait 3 s, save the screen
scripts/ios.py src/app/draughts.goose --console --args "--screen game --lang et"
scripts/ios.py src/app/draughts.goose --device --run            # on an attached iPhone or iPad
```

`scripts/ios.py` builds without an Xcode project, into `build/ios/<program>/sim/` or
`device/`, as `scripts/android.py` does for Android:

1. Goose writes the program's C (`goose -o`, with `--stack-reserve 128M`: an iOS process
   can't map Goose's default 2 GB for each of the app's 26 data stacks) and the runtime's
   C.
2. goose_gfx's `src/` is copied with `patches/goose_gfx/` applied, and SDL to
   `build/ios/SDL_src/` with `patches/SDL/` applied (`0005` lets SDL_GPU take the
   simulator's Metal device, `0006` keeps a rotation from stretching the picture).
3. CMake with Ninja and Xcode's clang builds `ios/CMakeLists.txt` for the simulator's or
   the device's SDK: one executable with the program, the runtime, goose_gfx's layers,
   and SDL, linked statically. `ios/main.c` hands the main thread to UIKit through
   `SDL_RunApp`, which calls the program's main back as `SDL_main`. SDL is built without
   HIDAPI (`SDL_HIDAPI OFF`): on iOS it links CoreBluetooth, and App Store Connect
   refuses a binary that references Bluetooth without a purpose string.
4. The bundle is the executable, an `Info.plist` the script writes (the id
   `io.github.kaitk.draughts`, the version from `native.py`'s `VERSION_NAME` and the
   script's `BUILD_NUMBER`, full screen, a `UILaunchScreen`, without which iOS
   letterboxes the app), and the
   launcher's name per language (`<lang>.lproj/InfoPlist.strings` from each
   `strings/<lang>.txt`'s `app.name`).
5. An asset catalog, written into `build/ios/<program>/<sim|device>/Assets.xcassets` and
   compiled by `actool` into the bundle's `Assets.car`: the icon (`AppIcon`, one 1024 px
   image; `CFBundleIconName` and actool's `CFBundleIcons` in the `Info.plist`) and the
   launch screen's colour (`LaunchBackground`, the launch screen's `UIColorName`), the
   icon's background read from `android/res/values/colors.xml`'s `icon_background`. The
   icon is `ios/icon-1024.png`, in git as Android's foregrounds are: `scripts/icon.py`
   writes it with them from the shipped season's master (`design/icon/README.md`).
6. The privacy manifest, `PrivacyInfo.xcprivacy`: no tracking, no tracking domains, no
   data collected, and a reason for each "required reason" API the binary imports
   (`ios.py`'s `PRIVACY_APIS`): `C617.1` for `stat` and `fstat`, `35F9.1` for
   `mach_absolute_time`. Check the list again after an SDL or Goose update:

   ```sh
   nm -u build/ios/draughts/device/Draughts.app/Draughts | grep -E \
     '^_(f?stat(at)?|lstat|f?getattrlist(bulk|at)?|f?statv?fs|mach_absolute_time)$'
   strings -a build/ios/draughts/device/Draughts.app/Draughts | grep -iE \
     'userdefaults|systemuptime|activeinputmodes|volumeavailable|filesystemfree'
   ```

   Any other API in Apple's list needs its category and reason added. To check a bundle:
   `xcrun assetutil --info .../Draughts.app/Assets.car` (the icon and the colour),
   `plutil -p .../Info.plist`, `plutil -lint .../PrivacyInfo.xcprivacy`.

The simulator is an iPhone 13 mini the script creates once (`Draughts iPhone 13 mini`;
`DRAUGHTS_IOS_SIM` names another), booted headless with `simctl`: no Simulator.app
window opens. `simctl` can't tap, so touch is checked on a device; the flags (`--screen`,
`--tap`, `--go`) reach the rest. `--console` prints the program's output until it ends.
To send the app to the background, start another (`xcrun simctl launch booted
com.apple.Preferences`), and `xcrun simctl launch booted io.github.kaitk.draughts` brings
it back. Its storage folder is `Library/Application Support/kaitk/draughts/` in `xcrun
simctl get_app_container booted io.github.kaitk.draughts data`. The simulator build embeds
the JPEGs beside the ASTC files, as the simulator's GPU may take no ASTC; a device build
embeds the ASTC files only, as Android does (11.7 MB).

A device build needs, once, on the device: pairing with the Mac (trust it) and
Developer Mode (Settings → Privacy & Security); on the Mac: an Apple ID in Xcode
(Settings → Accounts; a free one gives a personal team) and an Apple Development
certificate (Manage Certificates → +). The script then signs with that identity and a
development provisioning profile for the app's id on the device; when it finds none it
has Xcode make one, building an empty app of that id once
(`build/ios/provision/`, `xcodebuild -allowProvisioningUpdates`), which also registers
the device. A free team's profile lasts 7 days, after which the script makes another.
The team, the identity, and the device are read on the Mac at each build and never
written into the repo; `DRAUGHTS_IOS_DEVICE` picks a device when several are attached.
The first launch of an app from a free team waits for the phone to trust its developer
(Settings → General → VPN & Device Management). `devicectl` installs and starts it;
`--console` shows its output.

## Release builds

```sh
scripts/android.py src/app/draughts.goose --release   # draughts-release.apk and .aab
```

A release build is signed with the upload key instead of the debug key, and also makes
the Android App Bundle Play takes, both in `build/android/draughts/`:

- `draughts-release.apk`, the same APK as a debug build but for its signature, to install
  from a clean state and check before an upload. Android refuses it over a debug build,
  as their signatures differ: `adb uninstall io.github.kaitk.draughts` first.
- `draughts-release.aab`, for Play. `aapt2 link --proto-format` links the resources in
  the bundle's protobuf form; the script packs them, the dex, and the libraries into the
  base module's layout (`manifest/`, `dex/`, `lib/arm64-v8a/`, `res/`, `resources.pb`);
  bundletool builds the bundle with its native libraries uncompressed and aligned to
  16 KB pages (`PAGE_ALIGNMENT_16K` in the bundle's config); `jarsigner` signs it with the
  upload key; and `bundletool validate` checks it. The script then has bundletool make the
  APKs Play would serve an arm64 tablet from it and checks their libraries are on 16 KB
  pages too.

Build a release where `design/backgrounds/masters/` holds the `-6x6.astc` files, or it
ships without the photographs: `libmain.so` is about 9 MB with them, 7.5 MB of it the four
ASTC files.

bundletool is [1.18.3](https://github.com/google/bundletool/releases/tag/1.18.3), in
`build/bundletool-1.18.3/`; the script downloads it there when missing and checks it
against the SHA-256 it pins. It needs `java`.

The target SDK is 36: Play requires new apps and updates to target Android 16 (API 36)
from 2026-08-31 ([target API level](https://developer.android.com/google/play/requirements/target-sdk),
checked 2026-11-08). Raise `VERSION_CODE` for every upload; Play refuses one it has seen.

### The upload key

Play App Signing holds the key that signs the app on users' devices; the upload key only
proves an upload comes from the developer. Lost, it can be reset through Play Console's
support, which takes days, so keep a backup anyway. It is kept outside the repo, and
neither it nor its password is ever committed:

| File | What it is |
| --- | --- |
| `~/.config/draughts/upload-key.jks` | The keystore: PKCS12, alias `upload`, RSA 4096, `CN=Draughts`, valid until 2054-03-26 |
| `~/.config/draughts/upload-key.properties` | `storeFile`, `keyAlias`, `storePassword`, and `keyPassword` (the same password, as PKCS12 has one), mode 600 |

`DRAUGHTS_UPLOAD_KEY` points the script at another properties file. The script hands the
password to `apksigner` and `jarsigner` through the environment, never the command line.
Its certificate's SHA-256 is
`C4:F6:7B:CD:9E:DD:45:3F:5B:64:5F:AF:16:E6:F3:50:71:46:29:24:59:39:17:51:4B:3C:53:FC:25:1D:6F:4B`
(`keytool -list -v -keystore ~/.config/draughts/upload-key.jks`), which Play Console
shows once the first upload has registered it.

**Back it up before the first upload**, both files together, somewhere that survives the
Mac: a password manager's file attachment (1Password, Bitwarden) is the simplest, or an
encrypted disk image on a drive kept elsewhere:

```sh
hdiutil create -encryption AES-256 -srcfolder ~/.config/draughts -volname draughts-key \
    ~/Desktop/draughts-key.dmg            # asks for a passphrase; store it apart from the image
```

Check a backup by restoring it to a scratch folder and running `keytool -list -keystore
upload-key.jks` with the password from its properties file.

The key was made once (2026-11-08) with:

```sh
mkdir -p ~/.config/draughts && chmod 700 ~/.config/draughts
keytool -genkeypair -keystore ~/.config/draughts/upload-key.jks -storetype PKCS12 \
    -alias upload -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Draughts" \
    -storepass:env PASS -keypass:env PASS   # PASS: 40 random letters and digits
```

and the properties file written beside it with the same password, both `chmod 600`.

## Time the 3D board

```sh
adb shell am start -S -n io.github.kaitk.draughts/.DraughtsActivity \
    --es args "'--board 3d --screen game --theme wood --variant russian --bench 300'"
adb logcat -d | grep bench3d
```

On the flat board (`--board flat`) the same flag prints `bench2d:` instead: N whole
frames, from the shell's fill to the GPU done, each waited for, then N as the loop draws
them, frame to frame.
Both end with a summary: the waited frame's P50 and P99, and the presented frames'
average and 1% low (the rate of the 99th percentile's gap), both by the app's own clock,
which can't tell how long a frame stayed on screen: it put the tablet's flat board's 1% low
at 70 fps where the compositor counts no frame missed. The README's table takes its frames
from the compositor: `scripts/device_perf.sh` runs `--bench 1000` in a game (Russian,
wood) on each board once the device is cool, counts the presented frames with
SurfaceFlinger's timestats between the bench's `presenting` and `presented` lines, then
takes the idle CPU and memory. The bench's first phase waits for the GPU after every frame
and misses refreshes by design, so a count must not overlap it. `poc/pace.goose` draws
every frame with nothing else, or a set GPU load, to check the pacing alone.

Two seconds after the launch the app times 300 frames drawing the 3D board and its
shadow map, as while a piece moves, each submitted and waited for (`gfx::flush`); 300
drawing the board alone, waited for; 300 as the loop draws them, frame to frame; then
300 as a pulsing ring draws them, a ring round every piece (the kept depth's pass, and
the screen's part with the rings and without, each waited for), and quits. It prints those medians, the steps getting the board ready (their count, their
sum, the setup, and the longest), the first frame, and the bake again warm (`src/app/draw3d.goose`).
A waited frame includes the submit and the wait, about 5 ms on the Pixel 7a for an empty
pass, so it is an upper bound; the frame to frame time is held at the display's rate.
Let the device cool between series (`adb shell dumpsys thermalservice`, status 0):
warm, the Pixel 7a's frames slowed from 16.7 to 19.8 ms. [Rendering](architecture/rendering.md#the-3d-board-on-devices) has the numbers.

## Check idle CPU

```sh
adb shell svc power stayon true    # keep the screen on: Android pauses the app when it sleeps (not `usb`: the Pixel 7a charges as AC)
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
