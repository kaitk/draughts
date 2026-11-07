# 009: String table

Status: done

Every user-facing string is looked up by key from `strings/en.txt`, so another language
is a new file, not a code change.

## Acceptance criteria

- [x] No user-facing literals in game code
- [x] Language picked from the system locale, with English as the fallback
- [x] A test fails on keys missing from any language file

## Outcome (2026-11-07)

- `strings/strings.goose`: `key = text` files built in with `embed_file`; a constant per
  key (`strings::HOME_CONTINUE`), `strings::use(lang)` once at start, and
  `strings::get(key)` returns a view into the embedded file, so lookups allocate
  nothing. English fills in any key a translation lacks.
- `strings/en.txt` (the default) and `strings/et.txt` (Estonian, a translation), with the
  keys the home screen and settings need (from the prototypes); task 008 adds its own.
- The window title was the only user-facing literal in the app; it comes from the table.
  `abort` messages are for developers and stay literals.
- The language: `app/locale.c` reads SDL's preferred locales (`dlsym`, since the Mac
  links the program's C without SDL) and `strings::pick` takes the first with a file.
  On this Mac (`en-EE,et-EE`) it picks English; `--lang et` overrides it. The tablet is
  checked with task 008's first subtask, which builds the APK.
- `test/strings/strings.goose` checks every language file for missing, unknown, and
  doubled keys and malformed lines (exits 1 on any, checked by deleting a key from
  `et.txt`), shows the checker catching each on a broken copy, checks the constants
  against the key names, and picks languages from several locale lists.
