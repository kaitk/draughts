# Writing Goose

What a session needs to write Goose here without rereading the language docs. The docs
are the pinned release's `build/goose-v2026.4-macos-arm64/docs/`: `tutorial.md` (read
once, fully, before the first Goose of a session that has none of this in mind),
`reference.md` (every feature with a compiling example), `goose_spec.md` (check before
assuming a feature exists), `stdlib.md`. Add to this file what you had to look up or
find out by compiling, so the next session doesn't.

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
- `let v .= table[i];` binds a reference (no copy); `=` would copy the element.
- A struct literal ending in `..` leaves the rest at defaults: `Move { from: f, .. }`.
- `guard cond else { continue; }` for early exits; `if` and `match` are expressions, no
  ternary.
- `for i in n`, `for i in a..b`, `for x, i in xs`, `for &x in xs` (by reference).
- A package is a directory with `name.goose`; its other files are `import .other;` from
  inside it. A program declares it once in its root file:
  `import rules from "../../rules";`. A test helper package (`test/check.goose`) is
  imported as `import check from "../";`.
- Strings: `u8[>..]` builders, `const u8[:]` views. `str(...)` makes one, `format(out,
  ...)` appends, `print(...)` writes a line. `split`, `split_once`, `trim`,
  `parse_int` are in `std`.
- Errors: a trailing `bool` result, or `return x from f` to unwind to a caller.
- Sortable strings: limited arrays in a resizable, `var lines: u8[..80][>..] = [];`, filled
  with `let l .= lines.push([]); l.append(text);` and sorted with
  `sort(lines) { a, b => compare(a, b) < 0 };` (`test/check.goose`).
- A fixed buffer the caller owns, passed by reference into a `recursive fn`, is how move
  generation fills moves without allocating (`rules::Moves`, `rules::jump`).
- `from_bytes` checks an image's shape (framing, lengths, links), not its data: a
  flipped byte in a value's middle still loads. Add a checksum (`shell::save` appends
  FNV-1a). A limited array in a struct is saved at its full capacity.
- A package's other files' namespaces come with it: after `import shell from
  "../shell";` the app calls `settings::parse` from `shell/settings.goose`. Importing
  the same directory again under another name is an error.
- A package's files see each other's namespaces without importing them: `panel.goose`
  uses `clock::` because `game.goose` imports `.clock`. From outside, a file's namespace
  is reached by its own name (`home::COMPUTER` after `import shell`), never
  `shell::home::COMPUTER`, which doesn't parse.
- A root file and a package it imports may both declare the same package by different
  relative paths (`"../../rules"` and `"../rules"`): they resolve to one directory.
- `os::args()` for a program's arguments; `exit(code)`. On Android they come from the
  intent's `args` extra (`android/java/.../DraughtsActivity.java`).
- State with several large buffers (the computer player's 4 MB table and its frames) is
  a `root struct` owned by a local, each buffer a resizable field filled once; functions
  take `Engine&` (`ai/ai.goose`). A root can't be copied, passed by value, or held in
  another struct, and a worker can't receive one, only build its own.
- A deep recursion that must stop and resume (a search sliced across frames) is a loop
  over an explicit array of frames, one per level, with ENTER/RETURN modes
  (`ai/search.goose`); no coroutines are needed.
- A program's own C goes in `c_sources` in its `.build` sidecar (`app/draughts.build`).
  `goose run` and `goose build` both compile it with the system clang, so C23 `#embed`
  and `__has_embed` work (with `-Wc23-extensions` silenced); a slice arrives in C as
  `struct { uint8_t *data; int64_t len; }` by value (`app/background.c`). The compiled C
  is cached by its source: touch the `.c` after a file it embeds appears or changes.
- A missing `embed_file` path is a compile error; embed optional files from the C side.
- The program's C is linked on the Mac as its own dylib with no undefined symbols, so it
  can't call SDL directly though the goose binary carries SDL: look the function up with
  `dlsym(RTLD_DEFAULT, ...)` there; on Android the program links libSDL3.so and calls
  it directly (`app/locale.c`).

## Traps

- Shifts mask the count to the width: `x >> 64` is `x`, not 0. Never shift by a computed
  count that can reach the width (`rules/rules.goose` keeps every count under 64).
- `1 << n` takes its destination's type; in a `u64` context write `(1 as u64) << n` or
  return it from a `-> u64` function, or it is an `i64` shift.
- Arithmetic is at the operands' width: `u8 + u8` wraps at 256. `u32 + i32` is an error;
  cast one. `u64` meets a signed value only through a cast (or a literal, `.len`).
- `%` is Euclidean (never negative); `/` truncates. Signed overflow aborts in `--debug`
  only.
- A cast that changes nothing is a warning; casts that narrow need `as` (checked in
  debug) or `as!` (never).
- A local named `fill` or `count` shadows the std function of that name. `in` and `pad`
  can't name a local at all (both are reserved).
- Adjacent string literals don't join: `f("a" "b")` doesn't parse; write one literal.
- A struct literal's fields must come in declaration order, or it doesn't compile.
- `match` arms with block bodies are separated by commas: `A => { f(); },`.
- An `if` expression can't be an operand: `x + if c { 1 } else { 0 }` and
  `t[(a + if k { 1 } else { 0 }) * 64]` don't parse. Bind it to a `let` first.
- A type on a `for` binder is only for an integer count or range: `for v: u8 in 3` works,
  `for v: u8 in [a, b]` doesn't.
- There is no `size_of`; work a struct's size out from its fields.
- `float4` has no swizzles (`.xy`); build the `float2` from `.x` and `.y`.
- `as` binds looser than `&`: write `(x as i64) & 0x3F`; `x as i64 & 0x3F` doesn't parse.
- An array of untyped float literals (`let FACE_DP = [64.0, 30.0]`) holds `f64`s; cast an
  element `as f32` to use it with `f32`s. Typed arrays from untyped integer constants
  work (`let r: u32[2] = [0x20, END - 1]`), from an untyped constant array they don't.
- A large temporary on a data stack (a 16 MB image) stays resident after its scope ends;
  call `trim_memory()` (`os`) from a caller once the scope is over to give the pages
  back. Inside the scope it frees nothing, since the value is still live.
- `gl_InstanceIndex` doesn't count a draw's `first_instance`, so a second group of
  instances drawn at another time (pieces over the UI) gets its own storage buffer.
- `goose run` refuses a program that starts a thread at all, so the app is built on the
  Mac too (`docs/development.md`), and its one thread stays in `app/think.goose`: the
  packages and tests stay thread-free and run through TinyCC.
- Packages are declared by the root file only. A file of the app can't `import ai from
  "../ai"`; the root declares it and the file uses `ai::`. When a package starts
  importing another (`shell` importing `ai`), every root that imports it must declare
  the new one too: each test in `test/shell/`.
- `goose run` (TinyCC) doesn't optimize and can't start threads; time things with
  `goose build`, which compiles the C at -O2. TinyCC is still quick to start: the eight
  rules tests run in a fraction of a second through one `goose --multi-test`.
- The `goose` binary exports SDL's and gfx's symbols, so a desktop run sees the built-in
  gfx and nothing patched. A gfx patch that adds a function can't be called from code
  that also runs on the Mac; change behavior inside existing functions instead
  (`patches/goose_gfx/0002-draw-on-demand.patch`).

## Threads

What `app/think.goose` needed, from `reference.md` section 22 and spec 11.2:

- A `thread_fn` and all it calls compile as a separate program with its own data stacks
  and its own copies of the globals it reaches, taken at `thread_spawn`. Nothing is
  shared; no locks exist. Only flat values cross: the arguments and queue elements. A
  root struct can't, so the worker builds and `ai::init`s its own `ai::Engine`.
- Queues are typed and global, one per element type: `qput(v)` never blocks (it fails
  only past a `qlimit`), `qget<T>()` blocks, `qpoll<T>() -> T, bool` doesn't,
  `qget<T>(ms)` waits at most that long. Any flat struct is a queue type, also one from a
  package (`game::Ask`). Queues allocate in the runtime, outside the data stacks.
- `goose build --stacks` lists each worker's data stacks: the computer's worker uses 8,
  each a 2 GB reservation committed only as it is used.
- Workers still running when `main` returns are killed; the app never stops its worker.
- Threads work on Android as on the Mac: the NDK's clang compiles the runtime's thread
  locals, and `scripts/android_cli.sh` runs a threaded headless program as is.
- A built program takes its flags right after the executable, with no `--`.
- std has no `sleep`. `qget<T>(ms)` on a queue nothing puts to waits that long without
  spinning.

## Speed

- Measure with `goose build` (-O2 C). `--stats` shows how many bounds checks were
  removed and `--bce-lines` which remain, per line.
- An `assert(xs.len == N)` before a loop lets the compiler drop the loop's bounds
  checks; `%` by an array's length needs no check.
- Keep hot data fixed-size and flat: bitboards in `u64`, moves in a limited array the
  caller owns, no resizables in the search.
- `popcount`, `clz`, `ctz` (from `std`, `u64`, 64 for 0) are single instructions in a
  build and loops under TinyCC. Iterate set bits with `ctz(x)` and `x &= x - 1`.
- Passing a large struct by value copies it; take `T&` for anything over a few words
  read in a hot loop.
- The computer player's search runs at about 9 million nodes a second built on an M-series
  Mac, 1 million through `goose run`, and 4 million on the tablet's big cores, 1.5 million
  on its little ones (`tools/aibench.goose`, `scripts/android_cli.sh`). A larger table
  isn't always faster: clearing it each search and cache misses cost.

## New in v2026.4 (2026-11-06)

From the release notes, the parts this project can use:

- `goose format file|dir...` rewrites files in the standard layout, keeping line breaks
  and lining up runs of declarations. Run it on Goose files before committing.
  `--verify` checks only that formatting is stable, not that a file is formatted.
- The compiler prints nothing of its own on success; `--stats` gives the summary. The
  release notes also list a `-q` flag, but this release rejects it.
- `split_once`, `parse_uint`, `ascii::` character classes, `read_stdin(out, max)` in
  std; `math` gained `mul_add`, `hypot`, `cbrt`, `smoothstep`, `wrap_angle`, and f32
  forms of `radians`, `degrees`, `is_nan`, `is_inf`; `binary` reads and writes every
  width in both byte orders.
- `trim_memory()` in `os` returns unused data-stack pages to the OS.
- `extern "lib" { ... }` blocks bind a shared library's functions by name at run time.
- Package sidecars take `c_headers`.
- std's scalar functions are `checkfree`, so `checkfree` code can call them.
- Elementwise float arithmetic on structs and fixed arrays compiles to vector
  operations.

## Recording what Goose lacks

- When the compiler rejects something it should accept, miscompiles, or the stdlib
  lacks something, reduce it to a minimal program and record it in
  `docs/goose-findings.md`, naming the release it was found on, and work around it
  here. A gap that blocks us gets a patch in `patches/<package>/` (`AGENTS.md`).
