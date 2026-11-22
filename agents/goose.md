# Writing Goose

What a session needs to write Goose here without rereading the language docs. The docs
are the pinned release's `build/goose-v2026.4-macos-arm64/docs/`: `tutorial.md` (read
once, fully, before the first Goose of a session that has none of this in mind),
`reference.md` (every feature with a compiling example), `goose_spec.md` (check before
assuming a feature exists), `stdlib.md`. Add to this file what you had to look up or
find out by compiling, so the next session doesn't.

Run `goose format` on Goose files before committing (`--verify` checks only that
formatting is stable). The compiler prints nothing on success; `--stats` gives a summary.

## Memory model in five lines

- No heap. Values live on the native stack (fixed-size ones) or on bump-pointer data
  stacks; a scope's end frees everything it pushed. No GC, no destructors, no `free`.
- At most one resizable (`T[>..]` grow-only, `T[>..<]` grow-shrink) per data stack, and
  the compiler assigns stacks. Growing never moves, so references into a growing array
  stay valid.
- Fixed-size values (scalars, structs of them, `T[k]`, limited `T[..k]`) copy on
  assignment like C. Non-fixed ones never copy implicitly: `copy(x)`.
- `f(xs)` passes arrays by reference whatever the parameter says. A limited array
  `T[..k]` is fixed-size: it can live in a struct, on the native stack, and in a
  recursive function.
- `recursive fn` marks a cycle's entry. No function in the cycle may hold a growable
  local across a call back into it; pass buffers in by reference instead.

## Idioms used here

- Named constants are untyped `let`s at top level: `let MAX_MOVES = 512;`. They adapt to
  any integer type, size arrays, and match in `match` arms. A typed `let X: u8 = 1;` is
  an ordinary value and doesn't adapt.
- `x.f(a)` is `f(x, a)` (UFCS). Several results: `fn f() -> i64, bool`, `let a, ok = f();`.
- `let v .= table[i];` binds a reference (no copy); `=` would copy the element. A
  function can return a reference (`fn shown(sh: Shell&) -> board::Board&`) for `.=`;
  `.=` can't bind an `if` choosing between two fields.
- Trailing parameters can take defaults, `a: f32 = 1.0`.
- A struct literal ending in `..` leaves the rest at defaults, wherever the skipped
  fields are, so a root's `padN` fields stay out of every literal.
- `type Name = T;` names a type. An alias of another package's struct builds it by
  literal (`gpu::Texture { 0 }`), and overloads on aliases of different structs resolve
  (`src/gfx/gpu.goose`).
- A test file may hold its helpers' shared state in a top-level `var`.
- `guard cond else { continue; }` for early exits; `if` and `match` are expressions, no
  ternary.
- `for i in n`, `for i in a..b`, `for x, i in xs`, `for &x in xs` (by reference).
- Strings: `u8[>..]` builders, `const u8[:]` views. `str(...)` makes one, `format(out,
  ...)` appends, `print(...)` writes a line. `split`, `split_once`, `trim`, `parse_int`,
  `parse_uint`, and `parse_flt` (not `parse_float`) are in `std`. `split_once` on a
  `const u8[:]` returns read-only slices: `var rest: const u8[:] = ...`.
- Errors: a trailing `bool` result, or `return x from f` to unwind to a caller.
- Sortable strings: `var lines: u8[..80][>..] = [];`, filled with
  `let l .= lines.push([]); l.append(text);`, sorted with
  `sort(lines) { a, b => compare(a, b) < 0 };` (`test/check.goose`).
- A fixed buffer the caller owns, passed by reference into a `recursive fn`, is how move
  generation fills moves without allocating (`rules::Moves`, `rules::jump`).
- `from_bytes` checks an image's shape, not its data: add a checksum (`shell::save`
  appends FNV-1a). A limited array in a struct is saved at its full capacity.
- State with several large buffers is a `root struct` owned by a local, each buffer a
  resizable field filled once; functions take `Engine&` (`src/ai/ai.goose`). A root
  can't be copied, passed by value, held in another struct, or sent to a worker.
- A deep recursion that must stop and resume is a loop over an explicit array of frames
  with ENTER/RETURN modes (`src/ai/search.goose`).
- A struct of handles with no defaults is made with `var g = default<Gpu>();` (`var g:
  Gpu;` is "used before assigned" when passed by reference); a fixed array likewise,
  `[default<gfx::Event>(); 64]`. `gfx::events_into` fills one without allocating.
- `trim_memory()` (`os`) returns a finished scope's data-stack pages; a 16 MB temporary
  stays resident until a caller calls it.
- `os::args()` for a program's arguments (on Android from the intent's `args` extra);
  `exit(code)`. A built program takes its flags right after the executable, no `--`.

## Names

A name says literally what a thing is or does, for a reader of English as a second
language (a Finnish or Estonian programmer), who should never need the body to know it.

- Plain compound words pass: `sound_event`, `add_sound_events`, `put_in_list`,
  `press_on_ui`, `ai_request_id`, `tap_size()`. Even `sound_cue` passes; a bare `cue`
  does not.
- Figurative or idiomatic single words fail: `deaf` (now `input_off`), `took`
  (`press_on_ui`), `settle` (`ease_to_rest`, `fit_view`), `quiet` (`hide_counts`), and
  so do bare adjectives or participles for a value (`fitting`, `still`, `seen`).
- One name never does two jobs: `over` was a game's end, the square under the pointer,
  and the pieces over the UI (`ended_for_history`, `target_under_pointer`, `ui_pieces`).
  Grep a new name first: a field and a function of the same word (`side()` and `g.side`)
  count as two jobs.
- A function that returns a size or a value is named for it (`stacked_tile_height()`),
  not a verb; one that acts is named for its action (`claim_press`, `release_targets`).
- Terms of the trade stay (`lerp`, `quad`, `uv`, `rig`, GLSL's `over`), and so do the
  app's feature names (`lookout`, `glass`).

## Packages and files

- A package is a directory with `name.goose`. A program declares each package once, in
  its root file only (`import rules from "../../rules";`); a file of the app uses `ai::`
  without importing it. When a package starts importing another, every root that imports
  it must declare the new one too (each test in `test/shell/`). Two roots' different
  relative paths to one directory resolve to it.
- A package's other files are `import .other;` and start with `namespace other;` plus the
  std modules they use. Without the `namespace` line their functions are unknown from the
  importer, with no error in the file itself.
- A file may share the package's namespace (`src/gui/focus.goose` is `namespace gui;`),
  so a big file splits with no call site changed; two such files call each other
  unqualified (`render3d.goose` and `render3d_gpu.goose`).
- A package's files see each other's namespaces without importing them. From outside, a
  file's namespace is reached by its own name (`home::COMPUTER`), never
  `shell::home::COMPUTER`. A package's namespaces come into every program that imports
  it, so keep them apart from the program's own. Importing one directory twice under
  two names is an error.
- A root reaches files outside its own folder only through a package: `src/main/`'s
  roots declare `import gpu from "../gfx";` and pick one more of its files with
  `import gpu.backend;`. A package can't take a blessed or declared package's name, so
  `src/gfx/`'s entry is `gpu.goose` and `src/ngfx/`'s is `gpu_ngfx.goose`
  (`docs/decisions/layout.md`). Files of a package's folder that nothing imports aren't
  compiled: `src/gfx/backend.goose` stays out of the ngfx build.
- File functions (`read_file`, `write_file_atomic`, `file_exists`, `delete_file`,
  `rename_file`, `list_dir`) need `import os;` in every file that calls them.

## The program's C

- It is in `src/native/` and goes in `c_sources` in both roots' `.build` sidecars
  (`src/main/draughts.build`, `draughts_ngfx.build`; `scripts/check_roots.py` checks), compiled by
  the system clang, so C23 `#embed` works. A slice arrives as `struct { T *data; int64_t
  len; }` by value. The compiled C is cached by its source: touch the `.c` after a file
  it embeds changes (included headers are tracked). A missing `embed_file` path is a
  compile error; embed optional files from the C side.
- On the Mac it links as its own dylib with no undefined symbols, so it can't call SDL
  directly: look functions up with `dlsym(RTLD_DEFAULT, ...)`. On Android it links
  libSDL3.so directly (`src/native/locale.c`).
- iOS-only Objective-C goes in `platform/ios/` on `platform/ios/CMakeLists.txt`'s executable, never in
  `c_sources`; the C calls it under `#if DRAUGHTS_IOS`. SDL's `UIWindow` comes from
  `SDL_PROP_WINDOW_UIKIT_WINDOW_POINTER`.
- Java: `SDL_GetAndroidJNIEnv()` and `SDL_GetAndroidActivity()`, then `GetObjectClass`
  on the activity; `FindClass` from the program's thread doesn't find the app's classes
  (`src/native/launch.c`).
- goose_gfx's window: `SDL_GetWindows` (one, cached) for the safe area and display scale
  (`src/native/display.c`); the safe area is in window coordinates, points on the Mac.
- It can call goose_gfx's C API (`gfx_api.h`) and return a `gs_gfx_texture` to an
  `extern fn ... -> gfx::Texture` (`src/native/background.c`).
- A new C file goes in every sidecar that compiles the renderer (both roots' and
  `tools/*.build`). A second stb_image in a file of its own is `STB_IMAGE_STATIC` with
  its own `STBI_ONLY_*`, apart from background.c's JPEG-only one, which ASTC-only builds
  leave out (`src/native/materials.c`, PNG).
- A gfx function only the fork adds: an `extern fn ... = "gs_gfx_..."` of the program's
  (`src/app/keys.goose`) plus a `__attribute__((weak))` stand-in in the C
  (`src/native/gfx_fork.c`), so a plain `goose build` against the release's gfx still links;
  the build scripts link the fork's gfx C. A constant gfx adds is a `let` of the
  program's.
- The `goose` binary exports SDL's and gfx's symbols, so a `goose run` on the desktop
  uses the built-in gfx and nothing patched: a fork function can't be called from code
  that runs that way; change behavior inside existing functions instead.

## Traps

- Shifts mask the count to the width: `x >> 64` is `x`. Never shift by a computed count
  that can reach the width.
- `1 << n` takes its destination's type; in a `u64` context write `(1 as u64) << n`.
- Arithmetic is at the operands' width: `u8 + u8` wraps. `u32 + i32` is an error; `u64`
  meets a signed value only through a cast.
- `%` is Euclidean; `/` truncates. Signed overflow aborts in `--debug` only. An integer
  over an integer is integer division even where an `f32` is wanted:
  `(rows as f32) / side`.
- A cast that changes nothing is a warning (an `i64` already converts to `f32` where one
  is wanted); narrowing needs `as` (checked in debug) or `as!`. `as` binds looser than
  `&`: `(x as i64) & 0x3F`.
- An array of untyped float literals, or a `let` of untyped float constants alone, is
  `f64`: type it (`let head: f32 = ...`) to mix with `f32`s. Typed arrays from untyped
  integer constants work, from an untyped constant array they don't.
- `smoothstep(0.0, 1.0, x)` and `pow(x, 2.4)` with untyped literals are ambiguous between
  f32 and f64 even with `x: f32`: bind the literals to `f32`s or wrap them
  (`model3d::ease`). `PI` and `TAU` adapt.
- A local named `fill` or `count` shadows std's. `in`, `pad`, and `block` are reserved
  and can't name a parameter, local, or field; a root's padding is `pad0`, `pad1`.
- A `let` may rebind a name earlier in the same function, of any type; the error then
  lands far from the cause.
- Adjacent string literals don't join. A struct literal's fields must come in
  declaration order. `match` arms with block bodies are separated by commas.
- A `T&` parameter takes no temporary: bind it to a `var` first.
- An array literal passed to a `const u8[:][]` parameter can't be passed on from there to
  another function ("is not fixed-size and is not copied implicitly"): give the
  in-between parameter a size, `const u8[:][2]` (`tools/light_tune.goose`'s `switch`).
- An `if` expression can't be an operand unless parenthesized, can't be returned or bound
  alongside another value (`return if a { X } else { Y }, i;`), and an assignment isn't
  an expression.
- A type on a `for` binder is only for an integer count or range.
- There is no `size_of`.
- Globals initialize in import order: a top-level `let` that takes another file's global
  is "used before it is assigned" unless that file is imported first. Within a file, in
  declaration order, even an untyped constant read through a function: `LIBRARY`'s
  `bookcase_at` needs `HALL_WALL` declared above it (`src/model3d/shell.goose`). A top-level `let`
  built from a `var` is computed once before `main`: anything that changes at run time
  (`gui::tap_size()`) is a function.
- One choice at run time over code compiled per type, the renderer's seam
  (`src/ngfx/backend.goose`): `fn with<F>() { if on { F(&a) } else { F(&b) } }` runs a
  block `{ be => f(be) }` checked once per argument's type, so `f` and all it calls are
  generic and call `be`'s functions directly. A HOF needs its `<F>` and returns the
  block's value as that `if` expression (`return F(x)` of a valueless block is "cannot
  return a valueless expression"). `&` passes a fixed-size global by reference into an
  untyped block parameter; a generic function takes it as `<B>(be: B&)`, or it copies.
  `x.f()` looks for `f` in the namespace of x's type first, so `be.draw.board(...)`
  reaches `draw_gpu::board` or `draw_ngfx::board`; a field of the same name hides the
  function (`field compose is not callable`).
- A second root can run the same program: the program in a package's entry
  (`src/app/app.goose`, `fn run()`), which another directory's root imports
  (`import app from "../app";`); `fn main` stays in each root, as an imported file's
  `main` is ignored.
- `x.f()` finds `f` in the namespace of x's type: on another package's alias
  (`mesh::Profile`) write `mesh::line(prof, ...)`, `prof.line(...)` is unknown. A
  struct literal is all positional or all named, never mixed.
- A struct field can't default to `T {}` where T has a field with no default; give it a
  built value.
- A rect from a sum can differ in the last bit from the same rect cut piece by piece, and
  the tests print floats: keep cuts where an output must stay byte-identical.
- Text with backslashes (`'\\'`) goes through the Write or Edit tool: the Bash tool
  collapses `\\` to `\`.
- `goose run` (TinyCC) doesn't optimize and refuses a program that starts a thread, so
  the app is built (`goose build`) and its one thread stays in `src/app/think.goose`;
  packages and tests stay thread-free.

## Graphics traps

- A non-square texture gets mips only down to its shorter side's 1 pixel
  (`render3d::baked`): a full chain's 0-pixel levels lose the device on the A33's Mali.
  A lost device shows only at a fence wait; the Khronos validation layer in a test APK
  logs under `VALIDATION`.
- A released texture is freed after the submit that used it; making several in a row can
  open another 16 MiB SDL block that stays: `gfx::flush()` between them.
- `gfx::frame()` presents what the pass before it drew: the first frame is on screen once
  the second `frame()` returns.
- `gfx::uniforms` takes its block by value: bind it with `=`, not `.=`.
- `gfx::BLEND_ADD` weights the source by its alpha: an additive glow writes alpha 1.
- `gl_InstanceIndex` doesn't count `first_instance`: a second group of instances gets its
  own storage buffer.
- A storage buffer block holds one runtime-sized array (`vec4 squares[];`).
- A GLSL local named like a uniform block's member hides it; read the member through a
  function declared beside the block.
- `float4` has no swizzles.
- A shader's big function is compiled once per call site (unrolled loops too): one call
  site in a uniform-counted loop took a Mali pipeline from 2.5 s to 0.6 s. The size costs
  at run time too, even where the code returns at once: nine unrolled boxes in the
  library's `corner_shade` made the room 157 ms a frame on the Mac; one loop counted by
  a uniform (`+ int(corners.z)`) brought it back to 6.
- Without `centroid`, a varying is read at the pixel's middle even past the triangle's
  edge: an atlas looked up by a varying reads the next chart there, far at a grazing angle.
  Hold the tap inside the chart with a flat varying of its texels (`corner_map`'s `box`).
- A Mali compiles every branch, even one a uniform never takes: split what a look never
  uses into variants by a define (`shaders::PIECES_WOOD`, `BAKE_TABLE`), one embedded
  shader each, and make a variant's pipeline outside a pass.
- The library's `ROOM_FRAG` is near the Mac's register limit: code that never runs still
  costs (a uniform-off contact shadow 0.5 ms, a second sheen lobe 0.5, a toe switch 0.7 at
  1600 × 1000), and not additively. Weigh a feature by a build without its code, not by its
  uniform. Any change to `LIT_FRAG`'s text, even a branch never taken, moved two pixels of
  the game's shot by 7 levels: a tuner-only switch goes in shaders the tuner embeds itself
  (`render3d_gpu::tuned_frags`, `shaders::TOE_FN`).
  Moving code about in it (one call site in a loop, work done earlier) made it slower, not
  faster; what paid was drawing the triangles that need a path with a pipeline of their
  own. The room is now one pipeline a material group (`render3d::room_group`: floor, walls,
  paint, sills, metals, glass), each shader with only its group's code by defines (`shaders::ROOM_FLOOR`
  ..), its mesh sorted into the groups' index ranges. A new material goes in a group, or a
  group of its own: its define and branch in `ROOM_FRAG`, `room_group`, its textures in
  `ROOM_HEAD` and `room_textures` (the same order), `room_frag` and `make_room_tier` in
  both renderers, `scripts/ngfx_3d_shaders.py`'s `ROOMS`, the tuner's `tuned_frags`; and the mirror's
  pipeline (`planar_*`) in both renderers. A material gets a kind of its own
  (`surfaces::MAT_STONE`, 7) rather than a fraction of another's. A tuner-only variant of a
  group's shader (`PAINT_STEPS`, `SILL_STEPS`) is chosen in `room_frag` and its pipeline made
  again when it comes or goes (`make_room_tier`'s `room_steps`, `sill_steps`); for the
  mirror too, give it a `MIRROR_PASS` variant of its own (`TUNED_SILL_MIRROR`), or the
  floor reflects the app's look in the tuner's old mode. A split group drawn in another
  order than before moves pixels where two groups' faces tie in depth: draw it where its
  triangles were drawn before (the sills before the paint, as in the walls' draw).
- gfx counts a shader's samplers from slot 0 and wants every one bound: a variant that
  drops a texture declares the rest without a gap (`ROOM_HEAD`'s per-group slots); ngfx's
  root takes them in declaration order, so both follow one list.
- `scripts/ngfx_glsl.py` preprocesses only `#ifdef`, `#ifndef`, `#else` and `#endif`: a
  condition over several defines is a define string of its own in the pipeline's parts
  (`shaders::SHARP_BOX`), and one string may hold several `#define`s (`MIRROR_PASS`).
- embed_shader takes no `centroid`, no `##`, and no unnamed parameters; `#ifdef` lines in
  a multi-line string take the string's indentation. A define string put first makes two
  shaders from one text (`shaders::MARKS_PULSE`).
- MSAA antialiases only coverage: filter detail made from position over the pixel's
  footprint (`fwidth`), and take `fwidth` of a value continuous across cell edges (the
  grid coordinate), never one that jumps there.
- A `sampler2D` as a function parameter crashes the Pixel 7a's Mali pipeline build: read
  textures as globals.
- A mesh's millimetre fillet (a normal turning 90° across a strip) is read at a pixel's
  middle past the strip's edge, its normal extrapolated far beyond the side's: hold it
  near the strip's own plane from `cross(dFdx(p), dFdy(p))` (`ROOM_PAINT`).
- Mesh builders that take the shell's `seed` by reference feed the curtains and books after
  them: a new builder keeps the count of `seed++` as before or seeds from its own copy.
- A bevel in the shader instead of the mesh (the sills' eased arris): carry the distance to
  the edge in the uv, turn the normal toward it from the surface gradient of that distance
  (`cross(dFdy(p), n) * dFdx(t) + cross(n, dFdx(p)) * dFdy(t)`, times the sign of
  `dot(n, cross(dFdx(p), dFdy(p)))`), and take which way is "toward" from the face, not
  from the distance's sign: at a pixel's middle past the edge the distance reads past 0
  and the normal turns away, a dashed dark line. Under a pixel, spread the turn over the
  pixel and turn it less (`ROOM_SILL`). Derivatives before any branch.
- A tile made in Goose: `room_shell::tile_noise` takes the tile's side (`relief.goose`);
  grains stamped by hash into a wrapped float mask, the mips averaged as floats before
  packing to RGBA8 (`limestone.goose`, 1024² in about 70 ms).
- A second call site of `LIGHT_FN`'s `lace_shadow` in `shell_open` (the lace's light below,
  its outline blurred wider) cost 0.39 ms of the room's main pass at 3024 × 1890 with its
  uniform at 0, 1.05 ms more on: `shell_open` runs for every room pixel. One call
  returning both (a `vec2`), the wide part analytic (the outline's smoothstep times the
  pattern's mean), brought them to 0.13 and 0.70; what is left is the wider lit area
  (every pixel it reaches shades the sun). Keeping that light apart from the tree's look
  (a second sum, `min` at the end) made the all-off shader 0.37 ms slower again: measure a
  restructure of `shell_open`, don't assume. No GLSL here takes an `out` parameter;
  return a vector instead.
- A shader that adds light only near the sun (`ROOM_GLASS`'s `glass_sun`) returns early by
  the view's angle to the sun before `window_open`; take its derivatives (`dFdx` of the
  tile's uv, `fwidth(v)`) before that return and read the tile by `textureGrad`.
- The Mac's shaders run with fast math: `atan(0.0, 0.0)` is NaN (the glass's scratches
  where no groove is), and a NaN test like `!(x >= 0.0)` is compiled away. An 8-bit target
  drops a NaN without a trace, a float one (RG11B10F, RGBA16F) keeps it and the tonemap
  makes it black: guard `atan`'s two zeros, and look for black pixels after moving a
  pass to HDR.
- gfx makes a pipeline's variant per set of target formats, so one pipeline draws into
  RGBA8 or RG11B10F; but what a shader writes differs (tonemapped sRGB or linear light),
  so the HDR target has pipelines of its own (`shaders::HDR_OUT`, `render3d::HdrPipelines`).
  SDL can't sample a multisampled texture: a depth to read is a 1× pass of its own
  (`render3d_gpu::depth_pass`), and an HDR resolve is the hardware's box in linear light.
- The release's gfx module lacks `format_supported` (the fork has it): call it as an
  `extern fn ... = "gs_gfx_format_supported"` with `gfx_fork.c`'s weak stand-in, which says
  no (`render3d_gpu::hdr_format`). gfx has no query for a format's sample counts.
- The dust's vertex stage reads `shell_open` (`SHELL_WINDOWS`): its own block carries the
  fields of `ROOM_HEAD`'s Surfaces that `LIGHT_FN` reads (`axes`, `tile`, `shell*`,
  `window_view`) by the same names, and its storage buffer's binding follows the samplers
  (the lace's mask made it binding 2). ngfx's dust root takes the lace in slot 1.
- `smoothstep(a, b, x)` with `a > b` is undefined: write `1.0 - smoothstep(b, a, x)`.
- Metal keywords (`thread`, `device`, `constant`, `kernel`) as GLSL names fail only on
  the Mac's pipeline build.
- A GLSL change in `src/gfx/*_gpu.goose` or `src/render3d/shaders.goose` reaches the
  ngfx build through `scripts/ngfx_2d_shaders.py` and `ngfx_3d_shaders.py`. A GLSL
  built-in no shader used before gets a rename in `ngfx_glsl.py`'s `Stage.parse` and a
  `glsl_` function in `src/ngfx/shaders/glsl.slang`; a new 2D pipeline a row in
  `MODULES`; a new uniform, texture, or buffer moves its root, whose order
  `build/ngfx/shaders/<module>.slang`'s header lists and the recorder's `*Root` follows.
  2D roots take `vec4`-sized fields only. A new `mat * vec4(...)` in GLSL needs its
  replacement in `ngfx_3d_shaders.py`'s `products()` (it asserts on one left). The 3D
  root holds 16 texture slots. Build the ngfx build after any shader change.
- A hidden window ignores injected mouse input until `gfx::inject_focus(true)`;
  `gfx::open_headless` draws with no window. Nuklear's slider drags only from its knob.

## Threads

What `src/app/think.goose` needed (`reference.md` section 22, spec 11.2):

- A `thread_fn` and all it calls compile as a separate program with its own data stacks
  and its own copies of the globals, taken at `thread_spawn`. Nothing is shared; only
  flat values cross. The worker builds its own `ai::Engine`.
- Queues are typed and global: `qput(v)` never blocks (fails past a `qlimit`),
  `qget<T>()` blocks, `qpoll<T>() -> T, bool` doesn't, `qget<T>(ms)` waits at most that
  long (std has no `sleep`: this is it). Any flat struct is a queue type.
- Workers still running when `main` returns are killed.
- Each data stack reserves 2 GB of address space (`goose build --stacks` lists them); iOS
  maps far less, so its build passes `--stack-reserve 128M` (`scripts/ios.py`).
- Threads work on Android as on the Mac (`tools/android_cli.py`).

## Speed

- Measure with `goose build` (-O2 C). `--stats` shows how many bounds checks were removed
  and `--bce-lines` which remain.
- An `assert(xs.len == N)` before a loop drops its bounds checks; `%` by an array's
  length needs none.
- Keep hot data fixed-size and flat; take `T&` for large structs read in a hot loop.
- `popcount`, `clz`, `ctz` (64 for 0) are single instructions in a build. Iterate set
  bits with `ctz(x)` and `x &= x - 1`.
- The search runs at about 9 million nodes a second built on an M-series Mac, 1 million
  through `goose run`, 4 million on the tablet's big cores (`tools/aibench.goose`). A
  larger table isn't always faster: cache misses cost. The table is never cleared between
  searches; a generation byte per entry makes earlier searches' entries misses. perft
  runs at about 45 M positions a second in International built on the Mac, a move being
  16 bytes (`rules::Move` without its stops).

## Recording what Goose lacks

When the compiler rejects something it should accept, miscompiles, or the stdlib lacks
something, reduce it to a minimal program and record it in `docs/goose-findings.md`,
naming the release, and work around it here. A gap that blocks us is fixed as
`AGENTS.md` says.
