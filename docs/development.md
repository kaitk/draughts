# Development

The app builds from a Mac (Apple silicon), from Windows (x64), and from Linux (x64):

| Build | From | Command | Section |
| --- | --- | --- | --- |
| macOS app | Mac | `scripts/mac.py` | [Run on the Mac](#run-on-the-mac) |
| Windows app | Windows | `python scripts/windows.py` | [Run on Windows](#run-on-windows) |
| Linux app | Linux | `scripts/linux.py` | [Run on Linux](#run-on-linux) |
| Android APK | Mac, Windows | `scripts/android.py --run` | [Run on Android](#run-on-android) |
| Android release (APK and AAB for Play) | Mac, Windows, with an upload key | `scripts/android.py --release` | [Release builds](#release-builds) |
| macOS release (signed, notarized disk image) | Mac, with a Developer ID | `scripts/mac.py --release` | [Desktop releases](#desktop-releases) |
| Windows release (zip and installer) | Windows | `python scripts/windows.py --release` | [Desktop releases](#desktop-releases) |
| Linux release (tar.gz) | Linux, in an Ubuntu 22.04 container | `CC=clang-20 scripts/linux.py --release` | [Desktop releases](#desktop-releases) |
| iOS simulator, iPhone, iPad | Mac (Xcode) | `scripts/ios.py --run`, `--device --run` | [Run on iOS](#run-on-ios) |
| Rules tests | Mac, Windows, Linux | `scripts/test.sh` | [Test the rules](#test-the-rules) |

With no program, each script builds the app as it ships on its platform: both renderers
(`src/main/draughts_ngfx.goose`) on macOS, iOS, and Windows, gfx alone
(`src/main/draughts.goose`) on Android, Linux, and the iOS Simulator. `--gfx-only` builds
gfx alone, and a program path builds that program (`scripts/mac.py tools/pace.goose`).

## Toolchain

On the Mac:

| Tool | Where | Version |
| --- | --- | --- |
| Goose | `build/goose-v2026.4-macos-arm64/`, from the [release](https://github.com/aardappel/goose/releases/tag/v2026.4); `GOOSE` overrides it | v2026.4, with gfx, ui, and audio built in |
| goose_gfx | `third_party/goose_gfx` submodule (the fork `kaitk/goose_gfx`), with SDL and Nuklear as its submodules | its `main` |
| Android SDK | `~/Library/Android/sdk`; `ANDROID_HOME` overrides it | platform 36, build-tools 36.0.0, platform-tools |
| Android NDK | `$ANDROID_HOME/ndk/29.0.14206865`; `ANDROID_NDK` overrides it | r29 |
| JDK | `javac` on `PATH` | OpenJDK 21 |
| CMake, Ninja | Homebrew | |
| Python | `python3` | 3.x |
| bundletool | `build/bundletool-1.18.3/`, fetched by `scripts/android.py --release` | 1.18.3 |
| Xcode | `/Applications/Xcode.app`, for the iOS SDKs, clang, `simctl`, and `devicectl` | 26.4 |
| goose-ngfx | a checkout beside this repository (`../goose-ngfx`); `NGFX` overrides it | its `main` |
| slangc | `NGFX_SLANGC` names it | 2026.18.2 or later |
| astcenc | `build/astcenc-5.7.0/bin/astcenc`, from the [release](https://github.com/ARM-software/astc-encoder/releases/tag/5.7.0) (not in Homebrew) | 5.7.0 |

Set up from a fresh clone:

```sh
git submodule update --init --recursive --depth 1
mkdir -p build && cd build
gh release download v2026.4 -R aardappel/goose -p 'goose-v2026.4-macos-arm64.tar.gz'
tar -xzf goose-v2026.4-macos-arm64.tar.gz && rm goose-v2026.4-macos-arm64.tar.gz
gh release download 5.7.0 -R ARM-software/astc-encoder -p 'astcenc-5.7.0-macos-universal.zip'
unzip -q astcenc-5.7.0-macos-universal.zip -d astcenc-5.7.0 && rm astcenc-5.7.0-macos-universal.zip
cd ..
brew install cmake ninja     # for iOS and Android
```

Android's SDK, NDK, and JDK: [Run on Android](#run-on-android).

`scripts/clean.py` deletes what builds, tests, and shots left in `build/` (`-n` lists it
first, with sizes), keeping what is slow to get again: the fetched releases, `build/notes/`,
SDL as Linux builds it, and iOS's provisioning project.

When the Goose release changes, bring the fork's `main` to the upstream commit whose
`src/`, `gfx.goose`, and `CMakeLists.txt` match the release's `pkg/gfx/`, merge its
branches again, and move the submodule to it, so every platform compiles the same gfx
layer with the same changes.

## Run on the Mac

```sh
scripts/mac.py                             # build/draughts_ngfx
cd src/main
../../build/draughts_ngfx
../../build/draughts_ngfx --theme sunset --size 800x1280
../../build/draughts_ngfx --fen W:Wc3,e3,Kh2:Bd4,f6 --tap c3 --frames 30
```

The app is built, not run through `goose run`, which refuses a program that starts a
thread (the computer thinks on one, `src/app/think.goose`). `scripts/mac.py` builds
goose_gfx from the submodule into a copy of the release (`build/mac/goose/`), as every
platform's script does, then the program with that copy's `goose`, in about 13 s; the gfx sources are compiled
again only when they, SDL's version, or their flags change. A plain
`goose build` works too, but the release's gfx presents every frame, so at rest it spins
at the display's rate ([rendering](architecture/rendering.md#frames-and-battery)).

`src/main/draughts.build` adds the program's own C (`src/native/*.c`: the photographs, the
locales, the safe area, the clock's wake timer, and the platform glue), which the mobile
builds compile too. The photographs are embedded from `design/backgrounds/masters/` when
they are there (`design/backgrounds/README.md`); without them the board sits on the page
color. goose caches the program's C by its source, so after changing a master, touch
`src/native/background.c`.

### Development flags

Run the app from `src/main`; the flags follow the executable with no `--`. Each is a
field of `Flags` in `src/app/flags.goose`, the one list of them, with its values. The
common ones:

| Flag | What it does |
| --- | --- |
| `--size WxH`, `--size full` | the window, in points on the Mac; `full` fills the screen |
| `--dp N`, `--inset L,T,R,B` | a phone's layout: its shorter side in dp, its safe area in dp |
| `--touch on\|off`, `--mouse X,Y`, `--keys down,enter` | a desktop laid out as touch or not, the pointer held, keys pressed one a frame |
| `--theme`, `--lang`, `--hints`, `--background photo\|plain\|table`, `--pieces matching\|classic`, `--board 3d\|flat`, `--material`, `--moves` | override the settings for the run without writing them |
| `--fen POS`, `--tap c3` | a game from a position, squares tapped on the first frames |
| `--variant`, `--clock 5+3`, `--computer white\|black`, `--level` | a new game of that kind |
| `--screen NAME` | open a screen: `game`, `settings`, `setup`, `friend`, `computer`, `puzzles`, `results`, `tutorial` (`--step N`), `ask`, `replay` (`--ply N`, `--history FILE`, `--best on`) |
| `--puzzle ID` | open a puzzle; its taps go to its board |
| `--go NAME`, `--hold 0.4` | switch screens through the transition on the second frame; hold it part of the way |
| `--win 1.2` | hold a win's celebration at that time |
| `--frames N` | stop after N frames and save `draughts.png` |
| `--bench N`, `--rest S`, `--no-vsync` | time frames, count CPU at rest, present uncapped |

A phone, the Pixel 7a in portrait: `--size 450x1000 --dp 540 --inset 0,59,0,42`. A
`--frames` run doesn't wait for the display nor for events, so a shot of the computer's
reply takes some thousands of frames (`--computer black --tap c3 --tap d4 --frames 5000`).

The settings are in the app's storage folder (on the Mac
`~/Library/Application Support/kaitk/draughts/`): `settings.txt` the device's,
`player-N.txt` each player's ([players](architecture/README.md#players)), and
`game-N.bin` each player's game. A run with `--fen`, `--tap`, `--screen`, `--frames`,
`--variant`, `--clock`, or `--computer` neither reads nor writes the game, so shots don't
depend on the last session. `--reset-skill` puts the playing player back to easy.
A game against the computer that ends in such a run still moves the playing player's
rating, skill, and games played in `player-N.txt`: for a shot of an ended game, a
friend's (no `--computer`) moves nothing but `--history`'s file.

On Android the flags go through the intent; `-S` stops the app first, since the
`singleInstance` activity would otherwise come back with its old flags:

```sh
adb shell am start -S -n io.github.kaitk.draughts/.DraughtsActivity --es args "'--clock 5+3'"
```


## Run on Windows

Needs Visual Studio's Build Tools (`clang-cl`), Python, Git Bash (for `patch`), the Vulkan
SDK, goose-ngfx and slangc as on the Mac, and for a release's installer Inno Setup 6 (`winget install JRSoftware.InnoSetup`). The
submodules go in recursively, as on the Mac: goose_gfx's own SDL submodule is needed too,
or goose_gfx's build stops at a missing `SDL_version.h`.

```sh
git submodule update --init --recursive --depth 1
mkdir -p build && cd build
curl -sLO https://github.com/aardappel/goose/releases/download/v2026.4/goose-v2026.4-windows-x64.zip
unzip -q goose-v2026.4-windows-x64.zip && rm goose-v2026.4-windows-x64.zip
cd ..
python scripts/windows.py                 # build/windows/draughts_ngfx.exe
python scripts/windows.py --run -- --board 3d --screen game
```

The script builds goose_gfx into `build/windows/goose/` (delete it after the release
changes); SDL is the release's, linked statically. The app draws through Vulkan; Direct3D
12 needs a patched Goose, built as the `direct3d12` branch's copy of this section says
([decision](decisions/README.md#the-stack)). `--rest`
leaves the app running after its line, so close it; a `--bench` run quits by itself. The
settings are in `%APPDATA%\kaitk\draughts\`. `test/run_tests.py` takes the Windows
release there.

## Run on Linux

Needs a C compiler with `#embed` (GCC 15 or Clang 19 and later), Python 3, Vulkan's
loader, and, for SDL, CMake and the Wayland and X11 headers:

```sh
git submodule update --init --recursive
mkdir -p build && cd build
curl -sLO https://github.com/aardappel/goose/releases/download/v2026.4/goose-v2026.4-linux-x64.tar.gz
tar xzf goose-v2026.4-linux-x64.tar.gz && rm goose-v2026.4-linux-x64.tar.gz
cd ..
scripts/linux.py                # build/linux/draughts
scripts/linux.py --run -- --board 3d --screen game
```

The script builds goose_gfx into `build/linux/goose/` and SDL from the submodule with
`patches/SDL` applied, statically, with Wayland and X11 (the release's `libSDL3.a` has no
Wayland, [findings](goose-findings.md)). SDL opens Wayland where there is one
(`SDL_VIDEO_DRIVER=x11` forces XWayland). `CC` picks the compiler. The settings are in
`~/.local/share/kaitk/draughts/`.

On an immutable host without the headers (Fedora Atomic, Bazzite), build SDL once in the
`draughts-jammy` box ([Desktop releases](#desktop-releases)); the host's builds then link
the `build/linux/SDL/libSDL3.a` it left. SELinux there refuses TinyCC's code in memory,
so run `test/run_tests.py --build`.

```sh
distrobox enter draughts-jammy -- env CC=clang-20 scripts/linux.py
scripts/linux.py               # then on the host
```

`scripts/linux.py src/main/draughts_ngfx.goose` builds the ngfx renderer
(`build/linux/draughts_ngfx`; slangc in `NGFX_SLANGC`, a Mesa with `VK_EXT_descriptor_heap`).

## Test the rules

```sh
test/run_tests.py           # test/<area>/*.goose against test/expected/<area>/: about 20 s
test/run_tests.py --build   # the same, each built natively at -O2: about 90 s
test/run_tests.py --tinycc  # the same, each through TinyCC: about 60 s
test/run_tests.py --bless   # write each test's output as its expected output
scripts/test.sh             # the app's shaders, the tests, then perft and the random-game check
```

By default the tests run in batches through TinyCC, but the few whose search is slow
there (`SLOW` in `test/run_tests.py`) build at -O2 beside the batches. The times are a
10-core M-series Mac's. GitHub Actions runs `scripts/test.sh` on every push and pull
request (`.github/workflows/test.yml`) on Ubuntu 22.04, then builds the app with
`scripts/linux.py` and Clang 20, so a C error in the program's own C fails it too. With
`NGFX` naming a goose-ngfx checkout, `scripts/test.sh` also checks
`src/main/draughts_ngfx.goose`; CI clones goose-ngfx for it.

`scripts/test.sh` also builds `tools/perft.goose` into `build/perft`, which counts moves
from a position (`build/perft russian 9`, `build/perft international 8 FEN --divide`), and
runs `test/perft.py compare`: random games, every position's legal moves checked against
an independent Python generator. All of `scripts/test.sh` takes about 50 seconds.

## Time the computer player

```sh
goose build -o build/aibench tools/aibench.goose && build/aibench   # each level's reply time
goose build -o build/lookbench tools/lookbench.goose && build/lookbench   # the lookout's threats and traps
goose build -o build/aimatch tools/aimatch.goose
build/aimatch russian 90 40 20      # skill 90 against 40, 20 games, colors swapped
goose build -o build/play tools/play.goose
build/play russian easy white       # play it yourself in the terminal
tools/android_cli.py tools/aibench.goose                          # the same on a device
```

Each tool's header lists its options ([computer player](architecture/ai.md));
`tools/android_cli.py` runs any headless Goose program on a device, no APK.

## Check the puzzles

```sh
goose build -o build/puzzles tools/puzzles.goose && build/puzzles    # every puzzle, and the engine's view
build/puzzles try 'W:W33,38,43,45,47,48:B3,11,21,23,24,29' 'take 2' 2  # what solves a position
build/puzzles find 'take 3' 2 7 7 6                                  # random shots to compose from
build/puzzles --variant russian                                      # Russian's set
test/perft.py puzzles international src/puzzles/international.txt  # the lines, by the independent generator
```

`test/puzzles/` runs the same checks on every puzzle without the engine
([puzzles](architecture/puzzles.md#checks)).

The kings check scores every first move with the computer player where a line makes a
king, about a second a puzzle; it prints a line for each puzzle it checks, `DISAGREES`
on those that fail, and the counts by theme last. The three libraries take about ten
minutes on ten processes:

```sh
build/puzzles kings src/puzzles/russian.txt                          # a built-in set
for i in 0 1 2 3 4 5 6 7 8 9; do                                     # a library, a tenth each
  build/puzzles kings src/puzzles/library-international.txt $i 10 > kings-$i.txt &
done; wait
grep -h DISAGREES kings-*.txt
```

`--every` checks every puzzle, kings made or not, marks with `*` the moves that make
one, and `PREFERS` on a puzzle where the computer player scores a wrong first move 50 or
more above a right one (crowning and forced wins aside).

## Daily puzzles

The daily libraries are generated, rated, and assembled per draughts
([puzzles](architecture/puzzles.md#daily-puzzles)); about an hour for International on
ten processes:

```sh
goose build -o build/puzzles tools/puzzles.goose
for s in 100 101 102 103 104 105 106 107 108 109; do               # PER a kind, SECONDS a kind
  build/puzzles --variant international batch $s 12 120 > find-$s.txt 2> find-$s.log &
done; wait
tools/library.py merge merged.txt find-*.txt                       # each puzzle once
tools/library.py split merged.txt 10 rate-in
for i in 0 1 2 3 4 5 6 7 8 9; do build/puzzles rate rate-in-$i.txt > rate-out-$i.txt & done; wait
tools/library.py candidates cand.txt src/puzzles/library-international.txt rate-out-*.txt
for i in 0 1 2 3 4 5 6 7 8 9; do build/puzzles kings cand.txt $i 10 --every > kings-$i.txt & done; wait
tools/library.py passed passed.txt cand.txt kings-*.txt             # the kings check, the engine agreeing
tools/library.py assemble src/puzzles/library-international.txt international passed.txt
build/puzzles rate tools/calibration/adult_beginners.txt           # the estimate's calibration
```

`batch --kinds NAME,NAME` runs only those kinds, to refill a theme. A candidates file
holds at most 4,096 puzzles, so a larger batch goes through `candidates`, `kings`, and
`passed` in parts, and `assemble` takes every part's `passed` file. A new puzzle
passes the kings check and the engine's agreement (`PREFERS`, under "Check the
puzzles"); `assemble` leaves out a capture rated 500 or more without a real choice
([puzzles](architecture/puzzles.md#daily-puzzles)). Trap puzzles come from `batch ...
--traps`, added the same way; `assemble` keeps a
library's puzzles and their ids. When `rate` changes, `tools/library.py rerate
src/puzzles/library-V.txt rate-out-*.txt` gives the puzzles rated again their new
difficulty, ids kept, and sorts the file again. In the app, `--library N` opens a library's puzzle (id
N - 1), and `--puzzler NAME:RATING` sets up a player at that rating for the day's puzzles.

## Run on Android

A device needs Developer options with **USB debugging** on; a Samsung, also **Auto
Blocker** off (Settings → Security and privacy). Use USB mode **Transferring files** and
allow the computer's key; `adb devices` should list it.

```sh
scripts/android.py --run     # build, install, start
adb logcat -s goose:* SDL:*                 # the program's output and SDL's log
```

### Set up on the Mac

With Android Studio, install the Toolchain table's packages through its SDK Manager.
Without it, unpack Google's
[command-line tools](https://developer.android.com/studio#command-line-tools-only):

```sh
brew install openjdk@21 cmake ninja
export PATH="$(brew --prefix openjdk@21)/bin:$PATH"   # keg-only; in the shell's profile
sdk=~/Library/Android/sdk
mkdir -p $sdk/cmdline-tools
unzip -q ~/Downloads/commandlinetools-mac-*_latest.zip -d $sdk/cmdline-tools
mv $sdk/cmdline-tools/cmdline-tools $sdk/cmdline-tools/latest
$sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$sdk \
    "ndk;29.0.14206865" "platforms;android-36" "build-tools;36.0.0" "platform-tools"
```

### Set up on Windows

The same SDK packages, in `%LOCALAPPDATA%\Android\Sdk` (`ANDROID_HOME` overrides it); a
JDK 17 or newer (`javac`, `java`, `keytool`) on `PATH`; CMake and Ninja from winget;
Git Bash's `patch`:

```sh
sdk="$LOCALAPPDATA/Android/Sdk"
"$sdk/cmdline-tools/latest/bin/sdkmanager.bat" --sdk_root="$sdk" \
    "ndk;29.0.14206865" "platforms;android-36" "build-tools;36.0.0" "platform-tools" \
    "extras;google;usb_driver"
winget install -e --id Kitware.CMake --scope user
winget install -e --id Ninja-build.Ninja
python scripts/android.py --run
```

A device Windows doesn't list at all is on a charge-only cable.

### The debug key

Each computer has its own debug key (`~/.android/debug.keystore`, made when missing), and
Android refuses to install over an app signed with another key. Never uninstall to get
past that where the saved games matter: copy the key from the computer that installed the
app, or install beside it:

```sh
scripts/android.py --run --id-suffix test   # io.github.kaitk.draughts.test
```

The script never uninstalls. `--debuggable` marks the APK for a GPU profiler on a device
that isn't rooted (not with `--release`).

### The build

`scripts/android.py` builds without Gradle, into `build/android/<program>/`: Goose writes
the C, CMake with the NDK builds `libSDL3.so` and `libmain.so` (SDL copied to
`build/android/SDL_src/` with `patches/SDL/*.patch` applied), `javac` and `d8` compile the
Java, `aapt2` links the resources, and `zipalign -P 16` and `apksigner` finish the APK,
whose libraries the script checks are on 16 KB pages. The id is `io.github.kaitk.draughts`; `APP_ID` and `VERSION_NAME` are set at the top of
`scripts/native.py`, `VERSION_CODE` at the top of `scripts/android.py`. Delete
`build/android/<program>/native` after changing `platform/android/CMakeLists.txt`.

Check screens at other sizes on the Mac first (`--size`, `--dp`, `--inset`,
`test/shell/sizes`), then on devices over USB; the README's "Tested on" lists them. Act
on taps with `gfx::mouse_pressed` and `gfx::mouse_released`: a tap can press and release
within one frame, which `gfx::mouse_down` never sees.

## Run on iOS

```sh
scripts/ios.py --run                     # build, and run in the simulator
scripts/ios.py --shot build/ios/home.png # run, wait 3 s, save the screen
scripts/ios.py --console --args "--screen game --lang et"
scripts/ios.py --device --run            # on an attached iPhone or iPad
```

The simulator's build is gfx alone, as the Simulator's SDK lacks Metal 4's types; a device
build holds both renderers and takes goose-ngfx's `goose.h` from its Mac build, so run
`scripts/mac.py` once first.

`scripts/ios.py` builds without an Xcode project, into `build/ios/<program>/sim/` or
`device/`: one static executable (SDL without HIDAPI, whose CoreBluetooth App Store Connect
refuses without a purpose string) and the bundle around it, the icon and the launch
screen's colour compiled by `actool` from an asset catalog the script writes. Each data
stack is reserved at 128 MB (`--stack-reserve 128M`): a stack that outgrows it stops the
program.

The privacy manifest declares a reason for each "required reason" API the binary imports
(`ios.py`'s `PRIVACY_APIS`). Check the list again after an SDL or Goose update:

```sh
nm -u build/ios/draughts/device/Draughts.app/Draughts | grep -E \
  '^_(f?stat(at)?|lstat|f?getattrlist(bulk|at)?|f?statv?fs|mach_absolute_time)$'
```

The simulator is one the script creates once (`DRAUGHTS_IOS_SIM` names another), booted
headless; `simctl` can't tap, so touch is checked on a device.

A device build needs, once: the device paired with the Mac and in Developer Mode, and on
the Mac an Apple ID in Xcode with an Apple Development certificate. The script signs with
that identity and has Xcode make a development profile when there is none (registering the
device). `DRAUGHTS_IOS_DEVICE` picks a device; with several development identities,
`DRAUGHTS_IOS_TEAM` (a team id or an Apple ID) picks one. A free team's first launch
waits for the phone to trust the developer (Settings → General → VPN & Device
Management).

## Release builds

```sh
scripts/android.py --release   # draughts-release.apk and .aab
```

A release is signed with the upload key and also makes the bundle Play takes, both in
`build/android/draughts/`: `draughts-release.apk`, to install and check before an upload
(Android refuses it over a debug build), and `draughts-release.aab`, built and validated
by bundletool with its libraries on 16 KB pages. Build where
`design/backgrounds/masters/` holds the `-6x6.astc` files, or it ships without the
photographs. The target SDK is 36, as Play requires; raise `VERSION_CODE` for every
upload.

### The upload key

Play App Signing holds the key users' devices see; the upload key only proves an upload
comes from the developer. Whoever publishes, a fork included, makes their own, outside the
repo:

| File | What it is |
| --- | --- |
| `~/.config/draughts/upload-key.jks` | The keystore: PKCS12, alias `upload`, RSA 4096 |
| `~/.config/draughts/upload-key.properties` | `storeFile`, `keyAlias`, `storePassword`, `keyPassword` (the same), readable only by its owner |

`DRAUGHTS_UPLOAD_KEY` points at another properties file. Make one with:

```sh
mkdir -p ~/.config/draughts && chmod 700 ~/.config/draughts
keytool -genkeypair -keystore ~/.config/draughts/upload-key.jks -storetype PKCS12 \
    -alias upload -keyalg RSA -keysize 4096 -validity 10000 -dname "CN=Draughts" \
    -storepass:env PASS -keypass:env PASS   # PASS: 40 random letters and digits
```

and write the properties file beside it, both `chmod 600`. **Back both up before the
first upload**, somewhere that survives the computer (a password manager, or an encrypted
disk image), and check the backup with `keytool -list -keystore upload-key.jks`.

### The App Store build

```sh
scripts/ios.py --release            # build/ios/draughts_ngfx/Draughts.ipa
scripts/ios.py --release --upload   # and upload it to App Store Connect
```

The device build signed with the App Store profile's Apple Distribution identity. Raise
`BUILD_NUMBER` in `scripts/ios.py` for every upload. Nothing of the signing is in the
repo:

| File | What it is |
| --- | --- |
| `~/.config/draughts/draughts-app-store.mobileprovision` | An App Store distribution profile for the bundle id; `DRAUGHTS_IOS_PROFILE` overrides it |
| `~/.config/draughts/app-store-connect.properties` | `key_id=` and `issuer_id=` of an App Store Connect API key; `DRAUGHTS_ASC_PROPERTIES` overrides it |
| `~/.private_keys/AuthKey_<key id>.p8` | The key itself, where `altool` looks for it |

## Desktop releases

The Mac, Windows, and Linux apps go out as files on a GitHub release, built locally.

**macOS.** `scripts/mac.py --release` builds
`build/mac/release/Draughts.app` for macOS 13.3, Apple silicon only, signs it with the
hardened runtime, and puts it in `Draughts-VERSION-macos-arm64.dmg`: the window where the
app is dragged onto a link to Applications, on a card like the app's glass over a close
render of the board's corner (`platform/mac/dmg-background.tiff`, made by `tools/assets/dmg_background.sh`
from the local render in `~/Downloads/draughts-store/dmg-0.1/`), with the app's icon as
the volume's. Finder lays the window out by AppleScript,
so the first build asks to let the terminal control Finder. The image is signed,
notarized, and stapled; the ticket covers the app inside it, as Zeiger's does
(2026-11-16). `--no-notarize` stops before sending it to Apple. It needs, once per Mac:

1. A **Developer ID Application** certificate in the login keychain, which only the
   team's Account Holder can create (Xcode → Settings → Accounts → Manage Certificates,
   or developer.apple.com with a signing request from Keychain Access). Back up its
   private key as a `.p12`.
2. A **notarytool profile**: `xcrun notarytool store-credentials draughts-notary
   --apple-id APPLE_ID --team-id TEAM`, with an app-specific password.

`DRAUGHTS_MAC_IDENTITY` and `DRAUGHTS_NOTARY_PROFILE` override them. Without the identity
the script signs ad hoc and stops before notarizing.

**Windows.** `python scripts/windows.py --release` zips the
executable alone into `build/windows/release/Draughts-VERSION-windows-x64.zip`: SDL and
the C runtime are linked in, the icon `platform/windows/draughts.ico` embedded, and it is marked a
GUI program. Beside it, Inno Setup 6 (`winget install JRSoftware.InnoSetup`) builds
`Draughts-VERSION-windows-x64-setup.exe` from `platform/windows/draughts.iss`: per user, so no
administrator is asked for, with a Start menu entry and an uninstaller. Both are unsigned
(2026-11-16): SmartScreen warns once, at the installer, or at the zip's first run, and the
installed game then starts without a warning. A code-signing certificate isn't worth its
yearly cost for a free game; Steam (task 064) is the signed-free Windows path, where
downloads carry no mark of the web and SmartScreen doesn't ask.

**Linux.** `scripts/linux.py --release` writes
`build/linux/release/Draughts-VERSION-linux-x64.tar.gz`: the stripped executable, a
`.desktop` file, the icon, and `install.sh` (`--remove` undoes it). The executable needs a
glibc as new as the one it was built against, so build it in an Ubuntu 22.04 container
(glibc 2.35) with Clang 20:

```sh
distrobox create -n draughts-jammy -i ubuntu:22.04     # once
distrobox enter draughts-jammy
sudo apt-get install -y curl gnupg python3 git cmake ninja-build pkg-config binutils
sudo apt-get install -y libwayland-dev libxkbcommon-dev libdecor-0-dev wayland-protocols \
    libegl-dev libx11-dev libxext-dev libxrandr-dev libxcursor-dev libxfixes-dev libxi-dev \
    libxss-dev libxtst-dev libasound2-dev libpulse-dev libpipewire-0.3-dev libjack-dev \
    libsndio-dev libdbus-1-dev libibus-1.0-dev libudev-dev liburing-dev
curl -s https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/llvm.gpg >/dev/null
echo "deb http://apt.llvm.org/jammy/ llvm-toolchain-jammy-20 main" | sudo tee /etc/apt/sources.list.d/llvm.list
sudo apt-get update && sudo apt-get install -y clang-20
CC=clang-20 scripts/linux.py --release
```

A Docker `ubuntu:22.04` container does as well (as root, without `sudo`): build in a
`git clone` of the mounted repo, not the mount itself. `objdump -T
build/linux/release/Draughts/draughts | grep -o 'GLIBC_[0-9.]*' | sort -Vu | tail -1`
should say `GLIBC_2.35`.

On the Mac, Docker builds it as x64 under emulation in about ten minutes (0.9.0,
2026-11-16), with `scripts/linux_release_docker.sh` doing all of the above inside the
container and leaving the archive in `/out`:

```sh
docker run --rm --platform linux/amd64 -v "$PWD":/src:ro -v "$PWD/build/linux/release":/out \
    -v "$PWD/scripts/linux_release_docker.sh":/build.sh:ro ubuntu:22.04 /build.sh
```

**The release.** Tagged as the shared version (`native.VERSION_NAME`):

```sh
gh release create v0.2.0 build/mac/release/Draughts-0.2.0-macos-arm64.dmg \
    Draughts-0.2.0-windows-x64.zip Draughts-0.2.0-windows-x64-setup.exe \
    Draughts-0.2.0-linux-x64.tar.gz --title "Draughts 0.2.0" --notes "..."
```

## Time the 3D board

```sh
adb shell am start -S -n io.github.kaitk.draughts/.DraughtsActivity \
    --es args "'--board 3d --screen game --theme wood --variant russian --bench 300'"
adb logcat -d | grep bench3d
```

`--bench N` times N waited frames, then N as the loop draws them, and prints the waited
frame's P50 and P99 and the presented frames' average and 1% low (`bench2d:` on the flat
board). The app's own clock can't tell how long a frame stayed on screen, so the release
table's frames ([rendering](architecture/rendering.md#the-releases-frames)) come from
the platform's counter, each by its script:

- `tools/perf/device_perf.sh`: Android, SurfaceFlinger's timestats between the bench's
  `presenting` and `presented` lines, then idle CPU and memory.
- `tools/perf/ios_perf.py`: the iPhone, Instruments' Animation Hitches, and `--rest 25`'s
  CPU and footprint at rest.
- `python tools/perf/windows_perf.py`: Windows full screen, PresentMon's console exe in
  `build/presentmon/`.

The bench's first phase drops frames by design, so a count must not overlap it. Let a
device cool between series (`adb shell dumpsys thermalservice`, status 0). `tools/pace.goose`
checks the pacing alone. [Rendering](architecture/rendering.md#the-3d-board-on-devices)
has the numbers.

## Check idle CPU

```sh
adb shell svc power stayon true    # Android pauses the app when the screen sleeps
tools/perf/idle_cpu.sh 60             # with the app running on the device, untouched
adb shell svc power stayon false
```

It prints the CPU time of the program's thread and the process, and the thread's wakeups.
An idle board should use a fraction of a percent of a core with about one wakeup a second
([rendering](architecture/rendering.md#frames-and-battery)).

## Check memory over the Android lifecycle

```sh
tools/perf/lifecycle_memory.sh 20     # with the app running on the device
```

Each cycle goes home and back, then rotates to portrait and back, printing PSS, native
heap, and graphics memory and any errors in logcat. Graphics memory should stay flat apart
from short driver spikes.
