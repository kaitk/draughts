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
- `os::args()` for a program's arguments; `exit(code)`.

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
- A local named `fill` or `count` shadows the std function of that name.
- `goose run` (TinyCC) doesn't optimize and can't start threads; time things with
  `goose build`, which compiles the C at -O2.

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
