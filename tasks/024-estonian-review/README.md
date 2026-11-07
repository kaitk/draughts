# 024: Review the Estonian translation

Status: in-progress (the tablet check is open)

Once the MVP's prototypes have their text mostly in (2026-11-07): a Gemini agent (agy;
Gemini 3.8 writes the best Estonian of the models, given the right context) reads
`strings/et.txt` and the prototypes' text, and a Claude session then checks what it
changed against the English and the context before anything is taken.

- `brief.md`: what Gemini was given: the app and its users, every key with its English,
  Estonian, place, face, and room in characters, the draughts terms, and the answer's
  format.
- `proposals.md`: both models' answers as they wrote them, and the verdict on each
  proposal.

## Work

- Brief the agent with: `strings/en.txt` and `strings/et.txt` side by side, what the app
  is and who uses it (`docs/product.md`: children of about 5 to 8), where each string shows
  (key names, prototypes), the draughts terms in Estonian use (kabe, tamm, lööma,
  käik), and the limits of each tile's width (rendering.md).
- Take a change only with a reason: wrong, unnatural, or too long for its tile. Keep
  the keys; every language file has every key (`test/strings/`).
- Check the longer labels on the Mac and the tablet in both orientations with `--lang et`.

## Acceptance criteria

- [x] Every Estonian string read by the agent, its changes reviewed and taken or declined
- [ ] Screens checked in Estonian in both orientations (the Mac is done; the tablet was
  locked on 2026-11-08)

## Settled while scoping (2026-11-08)

- A Claude session runs the Gemini agent itself (`agy -p`, headless), once the MVP's new
  strings from tasks 021 and 025 are in. The brief goes to a file in `tasks/024-*`
  and Gemini writes its proposals to a file there, never to `strings/et.txt`. The session
  then checks each proposal against the English (no meaning lost, nothing added, the
  tile's width) before taking it.

## Done (2026-11-08)

Gemini 3.8 Flash (high) read all 60 keys and proposed 6 changes; it kept the rest, so
Gemini 4 Argon (high) read the same brief as a second opinion and proposed 5, 4 of them
the same as 3.8's. `agy` takes the prompt only as an argument to `-p`, not on stdin; it
was run with `--sandbox` and no tools, the answer on stdout. 3.8 answered in about two
minutes, Argon in about fifteen.

Taken, 7 keys:

- `turn.white`, `turn.black`, `won.white`, `won.black`: "Valge käik" → "Valgete käik",
  "Musta käik" → "Mustade käik", "Valge võitis" → "Valged võitsid", "Must võitis" →
  "Mustad võitsid". Estonian draughts names a side in the plural, as `color.*`
  ("Valged", "Mustad") already did; both models proposed it.
- `settings.board`: "Laud" → "Kabelaud" (Argon): "laud" alone is first a table.
- `clock.blitz_note`, `clock.rapid_note`: "+3 s käigu eest" → "+3 s käigule" (3.8). The
  old note fit its 113 dp setup tile with 5 dp a side (103 dp); the new is 83 dp, same
  meaning. Argon would keep the old.

Declined: the models' alternatives "Valgete kord", "Valged käivad", "Tasapinnaline",
"Uuesti", and "Õpi mängima" (reasons in `proposals.md`). No error both models missed
was found.

Widths (Libertinus advances at the face's size, as `gui::text_width` sums them; dp):

| String | Face | Width | Room |
| --- | --- | --- | --- |
| Rahvusvaheline | 20 px, falls back to 17 | 130, 110 | 105 (setup tile, 113 wide) |
| Alusta uuesti | 24 px | 130 | 140 (game panel, landscape) |
| Mustad võitsid | 24 px | 148 | 200 |
| +3 s käigule (was käigu eest) | 17 px | 83 (103) | 113 |
| Kabelaud | 17 px | 66 | 120 |

Checked on the Mac at 960 × 600 and 600 × 960 with `--lang et`: home, the computer's
setup, the game, a clocked game, a win, and settings. Every string shows whole.

## Open for the user

- `kings.auto`: "Automaatne" stays. Argon offered "Laua järgi" ("by the board", like
  "Kuupäeva järgi" two rows up) and 3.8 "Valib ise": plainer for a child; your call.
- `clock.*_note`: "käigule" or "käigu eest"? Both are used for an increment; "käigule"
  was taken for the room. Argon would keep "käigu eest".
- `variant.international`: "Rahvusvaheline" is the right term and has no shorter form,
  but in the setup's 113 dp tile it takes the small face and still runs edge to edge
  (110 dp). A layout fix (a smaller fallback, or that row's tiles sized by their words)
  would help more than a different word.
- The tablet check in both orientations, once it is unlocked.
