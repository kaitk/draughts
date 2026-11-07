# 009: String table

Status: todo

Every user-facing string is looked up by key from `strings/en.txt`, so Estonian later is
a new file, not a code change.

## Acceptance criteria

- [ ] No user-facing literals in game code
- [ ] Language picked from the system locale, with English as the fallback
- [ ] A test fails on keys missing from any language file
