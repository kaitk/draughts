# Layout decisions

Where the repository keeps the programs, their C, the renderers, the platforms, the build,
and the tools, dated, with their reasons. How the code is laid out now:
[Architecture: Code layout](../architecture/README.md#code-layout). The packages' own
split is in [the code's layout](README.md#the-codes-layout).

## The programs and their C (2026-11-18)

- The two programs' roots, and nothing else, are in `src/main/`: `draughts.goose`, the
  gfx build that ships, and `draughts_ngfx.goose`, the build holding goose-ngfx too. Each
  has its `.build` sidecar beside it. Before, the gfx root sat in `src/app/` as one of the
  app's files, and the ngfx root sat among the ngfx renderer's files, so neither program
  was where a reader would look for it.
- The program's own C and headers are in `src/native/`, from `src/app/` and `src/ngfx/`.
  `src/app/` had mixed the main loop with twelve C files; the C is the platform glue and
  the photograph's upload, which every build compiles.
- Both sidecars still list the C, and both roots still declare every package. A sidecar
  can't include another, and only a root declares packages, so the copies stay;
  `scripts/ngfx.py` checks that the ngfx root's C holds all of the gfx root's.
  Rejected: making `src/native/` a package with its own sidecar, which would share the
  list but change how the C is built and linked (as a package's native part, cached
  under `~/.goose/build`, and read from a second place by the Android and iOS scripts),
  more than a move.
- The roots pick their renderer's `backend` by importing it: `import gpu.backend;` in
  the gfx root, `import gpu_ngfx.backend;` in the ngfx one. The `run` both call stays in
  `src/app/app.goose`.

## The renderers (2026-11-18)

- gfx's backend moved from `src/app/` into `src/gfx/`, beside `src/ngfx/`: `gpu`,
  `draw_gpu`, `scene_gpu`, `widgets_gpu`, `host_gpu`, and the gfx build's `backend`. The
  drawers that are renderer-free (`draw`, `scene`, `widgets`, `draw3d`, `render`) stay in
  `src/app/`, as do `host` and `keys`, the window both renderers share.
- Each renderer's folder is a package whose entry is its backend's file: the roots
  declare `import gpu from "../gfx";` and `import gpu_ngfx from "../ngfx";`. A root in
  `src/main/` can reach another folder's files only through a package, and a package
  can't be named `gfx` or `ngfx`: those are goose_gfx's and goose-ngfx's names. So these
  two folders break Goose's convention of a folder holding `name.goose`, the only ones
  that do. Rejected: renaming the folders `gpu/` and `gpu_ngfx/`, which follows the
  convention but hides which renderer each is.
- The rule that only `app/` imports `gfx` or calls SDL and the platform
  ([the code's layout](README.md#the-codes-layout), 2026-11-08) now covers `app/`, the
  renderers' `gfx/` and `ngfx/`, and the C in `native/`.
- The move changed no code: the C that Goose writes for each root is the same, line for
  line, but for source line numbers in abort messages and one path in a shader's
  comment.

## The platforms (2026-11-18)

- Each platform's files the build takes are in `platform/`: `android/` (manifest,
  activity, resources, CMake), `ios/` (CMake, `main.c`, the icon), `mac/` (the disk
  image's background), `linux/` and `windows/` (the icons and the installer). Five
  folders at the root sat beside `src/`, `docs/`, and `design/` with nothing saying they
  were alike.

## Scripts and tools (2026-11-18)

- `scripts/` holds the build: one script per platform, `native.py` and `ngfx.py` and
  what they import (`icon.py` for the shipped icon's path, `ngfx_glsl.py` and the shader
  writers, `ngfx_shaders.goose.in`), `strings_keys.py` and `test.sh`, which the tests and
  CI run, `clean.py`, and `linux_release_docker.sh`, the Linux release's container
  build.
- `tools/` holds what a developer runs by hand, judged by what each does: the Goose
  programs (perft, the computer's benchmarks and matches, the terminal game, the puzzles,
  `board_shot`), `library.py`, `smaa_glsl.py`, and `android_cli.sh`, which runs one of
  them on a device. `tools/perf/` holds the measuring of a device or a build
  (`device_perf.sh`, `idle_cpu.sh`, `lifecycle_memory.sh`, `ios_perf.py`,
  `windows_perf.py`, `mac_gpu_time.py`, `shader_report.py`), and `tools/assets/` what
  makes an asset kept in git (`board_thumbs.py`, `badge_trace.py`, `sound_hits.py`,
  `dmg_background.sh`).
- `icon.py` stays in `scripts/`: it makes the icons, but `scripts/ios.py` imports it for
  the shipped icon's path.

## Building the two programs (2026-11-18)

- Each platform's script builds whichever root it is given: `scripts/mac.py
  src/main/draughts_ngfx.goose` builds the program holding goose-ngfx, as
  `windows.py`, `linux.py`, and `ios.py` do. A root that declares goose-ngfx from
  `build/ngfx/` gets that folder made first (`scripts/ngfx.py`, now a module the scripts
  call). This replaces two ways of asking for it: `scripts/ngfx.py`, which took the gfx
  root and swapped in its twin, and `scripts/ios.py --ngfx`. Android has no ngfx build,
  so `android.py` refuses that root, and every `--release` refuses it, as only the gfx
  build ships. Rejected: `--ngfx` on every script, which keeps a flag that only says
  which file to build, and a gfx root that can't be built alone.
- The app's ids come from the sidecar's `output = "draughts";`, which both roots set,
  not from the file's name: a program named `draughts` gets `io.github.kaitk.draughts` on
  Android and `io.github.kaitk.draughts.app` on iOS, and another program (`tools/pace.goose`)
  gets `<id>.<name>` as before (`scripts/native.py`, `app_id_of`). So the ngfx root keeps
  the gfx build's id on an iPhone, as `--ngfx` did (an iPhone wouldn't verify a new id of
  the team, 2026-11-11). `output` is a key Goose knows, the executable's name, and a
  sidecar can hold no key of our own. Build folders and executables are still named after
  the file (`build/draughts_ngfx`, `build/ios/draughts_ngfx/`), so the two builds don't
  overwrite each other. Rejected: a list of the app's roots in `scripts/native.py`,
  which keeps the id tied to file paths.
- The two roots' copies of the package imports, and the two sidecars' copies of the C and
  include lists, are checked, not shared: `scripts/check_roots.py`, run by
  `scripts/test.sh`, fails when the ngfx root lacks one of the gfx root's imports, adds
  one whose name doesn't hold `ngfx`, or its sidecar lacks one of the gfx sidecar's C
  files or include paths, or names another `output`. It replaces `scripts/ngfx.py`'s
  check of the C alone (above). Goose still gives no way to share them. Rejected: writing
  `draughts_ngfx.build` from `draughts.build` at build time, which leaves a file in
  `src/main/` that `goose check` needs but git doesn't hold.
- `scripts/test.sh` runs `goose check` on `src/main/draughts_ngfx.goose` when `NGFX` names
  a goose-ngfx checkout, and CI clones goose-ngfx for it. The check needs the shaders'
  blobs to exist: with `NGFX_SLANGC` it compiles them, and without it (CI) it writes empty
  ones dated 1970, which a real build sees as stale and compiles. Rejected: building the
  ngfx program in CI, which needs slangc and the Vulkan SDK there.
- `icon.py` moved to `tools/assets/`, with the other asset makers, replacing its place in
  `scripts/` (above): `scripts/ios.py` took only the shipped icon's path from it, which is
  now `IOS_ICON` in `scripts/native.py`.

## Rejected (2026-11-18)

- Dropping `src/` and putting the packages at the root: the root would mix the
  program's packages with `docs/`, `design/`, `store/`, and the rest, and every test
  imports `../../src/<package>`.
- The programs at the repository's root (`draughts.goose` beside `README.md`): a root
  declares its packages by relative paths, so the packages would follow it out of
  `src/`, and the root would hold Goose beside the docs.
- Go's `cmd/<program>/`, a folder per program: the two roots are two builds of one
  program, sharing the C and every package, so `src/main/` holds both in one place.
