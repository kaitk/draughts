# Proposals for the Estonian strings

Gemini's answers to `brief.md`, run headless with no tools (`agy -p --sandbox`, the
brief as the prompt, the answer as text on stdout), 2026-11-08, and the verdict on each
proposal. A key Gemini kept has no verdict: it stays.

Widths are measured with the app's font (Libertinus Sans advances at the face's size, as
`gui::text_width` sums them) and checked in screenshots.

## Gemini 3.8 Flash (high)

```
language.name | Eesti | keep | Standard endonym for Estonian in a language picker.
app.name | Kabe | keep | Plain, correct Estonian word for draughts.
home.continue | Jätka | keep | Natural and friendly imperative understood by children and parents.
home.friend | Sõbraga | keep | Natural conversational phrasing meaning "with a friend".
home.computer | Arvutiga | keep | Natural conversational phrasing meaning "with the computer".
home.puzzles | Ülesanded | keep | Standard draughts term for tactical problems and exercises.
home.settings | Seaded | keep | Short, standard UI word that fits within 12 characters.
level.easy | kerge | keep | Plain and clear word for easy difficulty.
level.medium | keskmine | keep | Standard Estonian word for medium difficulty.
level.hard | raske | keep | Plain and clear word for hard difficulty.
settings.game | Mäng | keep | Warm, plain section title for game settings.
settings.look | Välimus | keep | Standard, natural Estonian word for visual appearance.
settings.tutorial | Õpetus | keep | Warm, child-friendly word for tutorial.
settings.background | Taust | keep | Simple, standard word for visual background.
settings.by_date | Kuupäeva järgi | keep | Natural and accurate phrasing for date-based automatic selection.
settings.board | Laud | keep | Plain, standard word for the draughts board.
settings.hints | Vihjed | keep | Short, friendly word for move hints.
settings.kings | Tammid | keep | The official Estonian draughts term for crowned pieces.
season.winter | Talv | keep | Standard season name.
season.spring | Kevad | keep | Standard season name.
season.summer | Suvi | keep | Standard season name.
season.autumn | Sügis | keep | Standard season name.
hints.mistakes | Ainult vead | keep | Concise and easy for young children to understand.
hints.moves | Kõik käigud | keep | Natural phrasing using the proper draughts term "käigud".
board.flat | Lame | keep | Short and clearly paired with the "2D" note below it.
board.flat_note | 2D | keep | Standard universal abbreviation.
board.raised | Ruumiline | keep | Natural Estonian term for three-dimensional visual rendering.
board.raised_note | 3D | keep | Standard universal abbreviation.
kings.auto | Automaatne | keep | Standard setting term that fits comfortably.
kings.auto_note | 2D kroon, 3D virn | keep | Compact, informative note explaining king display per board style.
kings.crown | Kroon | keep | Simple, visual word matching the crown icon.
kings.stack | Virn | keep | Clear, concise description of two stacked pieces.
tutorial.learn | Õpi käike | keep | Warm, active invitation using the correct term "käigud".
game.home | Koju | keep | Warm, natural directional word ("go home") for children.
game.start_over | Alusta uuesti | keep | Clear, natural phrasing that fits within the 140 dp tile.
game.take_back | Võta tagasi | keep | Warm and intuitive imperative for undoing a move.
turn.white | Valge käik | Valgete käik | In draughts the side is plural ("valged"), so the turn is "Valgete käik".
turn.black | Musta käik | Mustade käik | In draughts the side is plural ("mustad"), so the turn is "Mustade käik".
won.white | Valge võitis | Valged võitsid | In draughts the side is plural ("valged"), so the winning side is "Valged võitsid".
won.black | Must võitis | Mustad võitsid | In draughts the side is plural ("mustad"), so the winning side is "Mustad võitsid".
setup.draughts | Kabe | keep | Standard Estonian name for draughts.
setup.level | Tase | keep | Clear and concise heading for difficulty level.
setup.color | Sinu nupud | keep | Warm heading using the correct draughts term "nupud".
setup.clock | Kell | keep | Standard game clock term.
setup.play | Mängi | keep | Inviting imperative button label immediately recognizable to children.
variant.international | Rahvusvaheline | keep | Official variant name; fallback to 17 px fits the tile.
variant.brazilian | Brasiilia | keep | Correct official variant name fitting comfortably.
variant.russian | Vene | keep | Correct official variant name fitting comfortably.
size.10 | 10 × 10 | keep | Universal dimension format.
size.8 | 8 × 8 | keep | Universal dimension format.
pick.easy | Kerge | keep | Clear, standard word for easy level.
pick.medium | Keskmine | keep | Standard word for medium level.
pick.hard | Raske | keep | Clear, standard word for hard level.
color.white | Valged | keep | Correct plural term for the white pieces/side in draughts.
color.black | Mustad | keep | Correct plural term for the black pieces/side in draughts.
clock.none | Kellata | keep | Natural and concise abessive form for "without a clock".
clock.blitz | 5 min | keep | Standard time notation.
clock.blitz_note | +3 s käigu eest | +3 s käigule | "käigu eest" is 15 chars and exceeds room (13 chars); "käigule" (12 chars) fits and is natural for clock increment.
clock.rapid | 10 min | keep | Standard time notation.
clock.rapid_note | +5 s käigu eest | +5 s käigule | "käigu eest" is 15 chars and exceeds room (13 chars); "käigule" (12 chars) fits and is natural for clock increment.

Notes:
1. `turn.white` / `turn.black`: Plural genitive "Valgete käik" / "Mustade käik" follows official draughts rules and matches `color.white`/`color.black` ("Valged"/"Mustad"); conversational "Valgete kord" / "Mustade kord" is an equally warm alternative for children.
2. `clock.blitz_note` / `clock.rapid_note`: "+3 s käigu eest" is 15 characters and overflows the 13-character room (~113 dp tile width); "+3 s käigule" (12 characters) fits cleanly, or "+3 s / käik" (11 characters) if a slash is preferred.
3. `board.flat` vs `board.raised`: "Lame" (4 characters) is concise and unambiguous over "2D", but "Tasapinnaline" is the more standard Estonian counterpart to "Ruumiline" if tile expansion permits 13 characters.
4. `game.start_over`: "Alusta uuesti" fits the 140 dp tile with only 10 dp to spare; if font rendering variations risk clipping on some displays, single-word "Uuesti" is a safe 6-character alternative.
5. `kings.auto`: "Automaatne" is standard UI terminology, but if you want an even simpler, warmer tone for a young child, "Valib ise" ("picks itself") is child-friendly.
```

### Verdicts

| Key | Now | Proposal | Verdict |
| --- | --- | --- | --- |
| `turn.white` | Valge käik | Valgete käik | **Taken.** Estonian draughts names a side in the plural (valged alustavad, valgete käik), as `color.white` already does ("Valged"); 123 dp in 200. |
| `turn.black` | Musta käik | Mustade käik | **Taken.** As `turn.white`; matches `color.black` ("Mustad"); 135 dp in 200. |
| `won.white` | Valge võitis | Valged võitsid | **Taken.** The side in the plural, as above; "Valge võitis" reads as "the white one won". 140 dp in 200. |
| `won.black` | Must võitis | Mustad võitsid | **Taken.** As `won.white`; 148 dp in 200. |
| `clock.blitz_note` | +3 s käigu eest | +3 s käigule | **Taken, on another reason.** Gemini's count is off: "käigu eest" fits (103 dp at 17 px in the 113 dp tile), but only with about 5 dp a side, the tightest note in the setup. "käigule" is the usual Estonian way to state an increment ("90 min + 30 s käigule") and is 83 dp; the meaning (three seconds added per move) is the same. |
| `clock.rapid_note` | +5 s käigu eest | +5 s käigule | **Taken.** As `clock.blitz_note`. |

Gemini's notes, and what came of them:

- "Valgete kord" / "Mustade kord" for the turn: declined. "käik" is the draughts word and
  the one `hints.moves` and `tutorial.learn` use; "kord" is not wrong, so it goes to the
  user as an option.
- "Tasapinnaline" for `board.flat`: declined. It is longer (115 dp against 45) and harder
  for a child; "Lame" with "2D" under it is clear.
- "Uuesti" for `game.start_over`: declined. It drops "start"; "Alusta uuesti" fits its
  140 dp (130 dp) and shows whole in both orientations.
- "Valib ise" for `kings.auto`: declined for now and left to the user: warmer, but the
  tile then says who picks without saying what, and the note under it already explains.

## Gemini 4 Argon (high), for comparison

Run the same way on the same brief, since 3.8 changed only six keys: a second reading
to catch what one model misses. It took about 15 minutes against 3.8's two.

```
language.name | Eesti | keep | Standard self-name for Estonian on a language switcher beside "English".
app.name | Kabe | keep | Exact Estonian name for draughts and fits the wordmark easily.
home.continue | Jätka | keep | Short, natural imperative for continuing a saved game.
home.friend | Sõbraga | keep | Idiomatic comitative ("with a friend") that works on both Home and the setup title.
home.computer | Arvutiga | keep | Idiomatic comitative matching "Sõbraga" and short enough to leave room for the level note.
home.puzzles | Ülesanded | keep | Exact Estonian draughts term for tactical puzzles ("kabeülesanded"), unlike "pusled" or "mõistatused".
home.settings | Seaded | keep | Plain, standard Estonian tablet word that avoids heavy "Seadistused" and fits all three places.
level.easy | kerge | keep | Natural Estonian difficulty word in lowercase, consistent with "pick.easy".
level.medium | keskmine | keep | Natural Estonian difficulty word in lowercase, consistent with "pick.medium" and within room.
level.hard | raske | keep | Natural pairing with "kerge" in lowercase, consistent with "pick.hard".
settings.game | Mäng | keep | Plain, exact Estonian title for the game settings group.
settings.look | Välimus | keep | Plain, everyday Estonian word for how the app looks.
settings.tutorial | Õpetus | keep | Warm, child-friendly Estonian word for a tutorial.
settings.background | Taust | keep | Short, plain Estonian word for the background photo.
settings.by_date | Kuupäeva järgi | keep | Idiomatic Estonian for picking the season by today's date, close to the English length.
settings.board | Laud | Kabelaud | Alone, "Laud" primarily means a table; "Kabelaud" is the Eesti Kabeliit term for the board, anchors "Tammid" below it, and fits 15 chars easily.
settings.hints | Vihjed | keep | Short, plain label whose meaning is immediately clear beside "Ainult vead" and "Kõik käigud".
settings.kings | Tammid | keep | Exact Estonian draughts plural for kings (tamm, gen. tammi, pl. tammid).
season.winter | Talv | keep | Plain Estonian season name well within 7 chars.
season.spring | Kevad | keep | Plain Estonian season name well within 7 chars.
season.summer | Suvi | keep | Plain Estonian season name well within 7 chars.
season.autumn | Sügis | keep | Plain Estonian season name well within 7 chars.
hints.mistakes | Ainult vead | keep | Short, plain Estonian that contrasts clearly with "Kõik käigud".
hints.moves | Kõik käigud | keep | Natural Estonian using the consistent word "käigud" for moves.
board.flat | Lame | keep | Short, plain word for a flat surface, unambiguously 2D next to "2D" and "Ruumiline".
board.flat_note | 2D | keep | Standard notation matching the English note and "kings.auto_note".
board.raised | Ruumiline | keep | Natural everyday Estonian for 3D, much clearer than translating "Raised" literally.
board.raised_note | 3D | keep | Standard notation matching the English note and "kings.auto_note".
kings.auto | Automaatne | keep | Standard Estonian ("Auto" alone means car) and narrower than the note beneath it.
kings.auto_note | 2D kroon, 3D virn | keep | Compact, clear reference to the "2D" and "3D" board notes above without widening the row.
kings.crown | Kroon | keep | Plain Estonian word a young child knows, consistent with "kings.auto_note".
kings.stack | Virn | keep | Exact plain word for neatly stacked discs, consistent with "kings.auto_note".
tutorial.learn | Õpi käike | keep | Short, grammatical imperative ("Õpi" + partitive plural, like "Õpi tähti") using the consistent word for moves.
game.home | Koju | keep | Warm, idiomatic illative ("go home") beside the house icon.
game.start_over | Alusta uuesti | keep | Natural imperative for restarting from move one (unlike "Uus mäng") and fits within 140 dp.
game.take_back | Võta tagasi | keep | Authentic board-game Estonian ("käiku tagasi võtma") rather than technical "Tühista".
turn.white | Valge käik | Valgete käik | Wrong number and inconsistent with "Valged": sides in Estonian draughts are plural, and "Valge käik" also reads as "a white move".
turn.black | Musta käik | Mustade käik | Wrong number and inconsistent with "Mustad": Estonian draughts uses plural "mustad" for the side, so genitive plural "Mustade käik".
won.white | Valge võitis | Valged võitsid | Wrong number and inconsistent with "Valged": Estonian draughts states results in the plural ("Valged võitsid", 14 chars).
won.black | Must võitis | Mustad võitsid | Wrong number and inconsistent with "Mustad": Estonian draughts states results in the plural ("Mustad võitsid", 14 chars).
setup.draughts | Kabe | keep | Plain heading over the variants and in Settings without technical words like "režiim" or "variant".
setup.level | Tase | keep | Plain, standard Estonian game term for difficulty level.
setup.color | Sinu nupud | keep | Warm, child-friendly phrasing using the right draughts term "nupud".
setup.clock | Kell | keep | Plain board-game Estonian ("kabekell" / "kell") avoiding technical "ajakontroll".
setup.play | Mängi | keep | Short, warm imperative consistent with the app's other action buttons.
variant.international | Rahvusvaheline | keep | Official Eesti Kabeliit name for 10 × 10 draughts; no shorter form exists and the 17 px fallback fits.
variant.brazilian | Brasiilia | keep | Official Eesti Kabeliit name for Brazilian draughts and fits at 20 px.
variant.russian | Vene | keep | Official Eesti Kabeliit name for Russian draughts, capitalized as a standalone tile label.
size.10 | 10 × 10 | keep | Proper multiplication sign and spacing for Estonian.
size.8 | 8 × 8 | keep | Proper multiplication sign and spacing for Estonian.
pick.easy | Kerge | keep | Natural difficulty label matching "level.easy".
pick.medium | Keskmine | keep | Natural difficulty label matching "level.medium" and fitting 11 chars.
pick.hard | Raske | keep | Natural difficulty label matching "level.hard".
color.white | Valged | keep | Right Estonian draughts plural for the white side, matching "Sinu nupud".
color.black | Mustad | keep | Right Estonian draughts plural for the black side, matching "Sinu nupud".
clock.none | Kellata | keep | Concise, natural abessive ("without a clock") matching the heading "Kell".
clock.blitz | 5 min | keep | Standard Estonian abbreviation for minutes, without a period.
clock.blitz_note | +3 s käigu eest | keep | Authentic Estonian tournament phrasing for Fischer increment per move made and fits at 17 px.
clock.rapid | 10 min | keep | Standard Estonian abbreviation for minutes, without a period.
clock.rapid_note | +5 s käigu eest | keep | Authentic Estonian tournament phrasing for Fischer increment per move made and fits at 17 px.
```

Its notes, as it wrote them:

> - **`turn.white` / `turn.black`**: `Valgete käik` / `Mustade käik` parallels spoken *"Sinu käik!"* at a family board game and keeps the noun `käik`; `Valged käivad` / `Mustad käivad` is equally authentic club/diagram Estonian and keeps nominative `Valged` / `Mustad` identical across setup, turn, and win.
> - **`settings.board`**: `Kabelaud` matches Eesti Kabeliit rule headings and prevents a child hearing `Laud` as "table" (while also anchoring `Tammid` below it as draughts kings), though `Laud` is still understandable in context if brevity is preferred.
> - **`kings.auto`**: `Automaatne` is familiar on Estonian tablets, while `Laua järgi` ("by the board", same length) avoids a technical word and echoes `Kuupäeva järgi` two rows above.
> - **`tutorial.learn`**: `Õpi käike` works like children's *"Õpi tähti"* and keeps `käik`, whereas `Õpi mängima` ("Learn to play") sounds slightly warmer and less calqued from English *"Learn the moves"*.

### Verdicts

| Key | Now | Proposal | Verdict |
| --- | --- | --- | --- |
| `settings.board` | Laud | Kabelaud | **Taken.** Alone, "laud" is first a table, and a child hears it so; "kabelaud" is the board's own word, already in the brief's terms. 66 dp at 17 px in the 120 dp name column. |
| `turn.white`, `turn.black`, `won.white`, `won.black` | | as 3.8 | Taken above; both models proposed the same four strings independently. |
| `clock.blitz_note`, `clock.rapid_note` | +3 s käigu eest | keep | **Overruled.** Argon keeps "käigu eest" as the tournament phrasing, which it is too; "käigule" stays taken for the room (above). Left to the user. |

Argon's notes:

- "Valged käivad" / "Mustad käivad" for the turn: declined. Good Estonian, but "Valgete
  käik" keeps the noun, as English "White's turn" does, and is the shorter (123 dp
  against 140).
- "Kabelaud" for `settings.board`: taken (above).
- "Laua järgi" ("by the board") for `kings.auto`: not taken, left to the user. It avoids
  the technical "Automaatne" and echoes "Kuupäeva järgi", the other automatic tile, but
  "Automaatne" isn't wrong, and the note under it ("2D kroon, 3D virn") already says
  what it does.
- "Õpi mängima" for `tutorial.learn`: declined. "Learn to play" is wider than "Learn the
  moves", the tutorial's actual content; "Õpi käike" is grammatical and keeps "käik".

## Summary

Seven keys changed in `strings/et.txt`: `turn.white`, `turn.black`, `won.white`,
`won.black` (both models), `clock.blitz_note`, `clock.rapid_note` (3.8; Argon would
keep), `settings.board` (Argon). Every other key stays as it was; no error either model
missed was found.
