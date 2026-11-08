# Proposals for the Estonian strings, second pass

Gemini's answers to `brief-2.md`, run headless with no tools (`agy --sandbox -p`, the
brief's prompt as the argument, the answer as text on stdout), 2026-11-08, and the
verdict on each proposal. The user took four changes into `strings/et.txt` on
2026-11-08 (the summary's last column). A key both models kept has no verdict, unless
this session found something they missed.

Two runs of the same brief: agy's default, which this config resolves to Gemini 4 Argon
(Medium), in 49 s, and Gemini 4 Argon (High) (`--model gemini-4-argon-high`) in 172 s.
Gemini 3.8 Flash, the first pass's model, wasn't offered by this config. Widths are the
app's font (Libertinus Sans advances at the face's size, as `gui::text_width` sums them),
measured, not checked on screen.

## Summary

Both models keep 66 of 68 keys and propose the same two changes, `goal.safe` and
`settings.by_date`; Medium adds `settings.kings`. This session recommends one of them and
adds one of its own:

| Key | English | Was | Proposed | Verdict | Taken (2026-11-08) |
| --- | --- | --- | --- | --- | --- |
| `goal.safe` | Stay safe | Ära anna nuppu | Päästa nupp | **Recommend** (both models) | Päästa nupp |
| `puzzle.try_again` | Try again | Proovi uuesti | Proovi veel | **Recommend, Claude's own**; both models keep | Proovi veel, for now |
| `settings.by_date` | By date | Kuupäev | Praegune | Decline; the user's choice, with "Tänane" as an option | Tänane |
| `settings.kings` | Kings | Tammi kuju | Tammid | Decline (Medium only); renamed on purpose that day | Tammid |

The capture verb: Eesti Kabeliit's official rules (EKL100 Osa 1, 2021, the international
game) write *lööma*, *löömine*, *löömiskäik*, and call the pieces *kabend*, a man *kivi*,
and a king *kabe* ("Kivi saab kabeks, kui ta jõuab viimasele reale"); Estonian Wikipedia's
*Kabe* does the same and gives *tamm* as the colloquial name for a king. No Estonian
children's material on draughts was found online, so which verb it uses stays open. The
app keeps its plainer words (nupp, tamm, võtma), as the user prefers: *võtma* is the
general board-game word for taking a piece, and EKL's own rules use it for taking the
pieces off the board ("kabendite võtmisel", 4.12). The models were told this and kept
"Võta {}" and "Saa tammiks".

## Verdicts

| Key | Was | Proposal | Verdict |
| --- | --- | --- | --- |
| `goal.safe` | Ära anna nuppu | Päästa nupp | **Recommend.** Both models, independently. "Ära anna nuppu" is a prohibition, and *nuppu andma* is how a player says giving a man on purpose, which tier 3's other puzzles ask for; to a child it reads "don't hand over a piece". "Päästa nupp" ("save the piece") says what to do, as the other goals do, and is exactly what each of the three safe puzzles is (the file's comment on each: "the man on … is in danger", one move saves it). Nothing added: the goal is that one move after which nothing is lost, and the piece at risk is the reason. 153 dp at 30 px in about 200 (the old was 200, at the edge of dropping a face). "Kaitse nuppu" (164 dp) matches the shield icon but reads as guarding in place; left in the notes. |
| `puzzle.try_again` | Proovi uuesti | Proovi veel | **Recommend, Claude's own.** The pill leaves the words 128 dp in landscape (the 200 dp goal less 72); "Proovi uuesti" is 130 dp at 24 px, so it drops to 20 px (108), while English "Try again" stays at 24 px (94). "Proovi veel" is 108 dp at 24 px, fits, and is what a parent says at the board ("proovi veel!"), same meaning. Both models keep "Proovi uuesti" and accept the drop; it isn't wrong, so this is a small fix for the user to weigh. |
| `settings.by_date` | Kuupäev | Praegune | **Decline, left to the user.** Both models say bare "Kuupäev" reads "Date", not "By date", which is fair: it names the input without saying it picks. But the user chose "Kuupäev" for this tile on 2026-11-08 after trying "Kuupäeva järgi" (124 dp) and others there, and "Praegune" ("current", 78 dp) says no more about how the season is picked. If the user wants a change, "Tänane" ("today's", 61 dp) says it best, read with the season photographs beside it. |
| `settings.kings` | Tammi kuju | Tammid | **Decline.** Argon (Medium) only; Argon (High) keeps "Tammi kuju". "Tammid" was the string until it was renamed "Tammi kuju" on purpose (2026-11-08, 17:59): "Tammid" beside "Kroon" and "Virn" names the pieces, "Tammi kuju" what the tiles choose. Both fit the 120 dp column (58 and 85 dp). |

Taken by the user, 2026-11-08: "Päästa nupp", "Proovi veel" (fine for now), "Tänane"
for by the date, and "Tammid" for the kings' setting. "Tammid" names the pieces the
setting's tiles change (Laua järgi, Kroon, Virn), as "Vihjed" and "Taust" name theirs;
no clearly better name was found ("Tamm", the singular, reads as one piece; "Tammi kuju"
is the one replaced). On the Mac at the Pixel 7a's 540 dp and the tablet's sizes, all
four show whole: "Päästa nupp" and the "Proovi veel" pill in both orientations, "Tänane"
inside its 88 dp tile, "Tammid" in the setting's name column.

The models' notes, and what came of them:

- `goal.safe` alternatives: "Kaitse nuppu" ("protect the piece", ties to the shield),
  "Hoia nuppe", "Hoia nupp alles", "Mine pakku". Declined in favour of "Päästa nupp":
  "Hoia nuppu" can be heard as "hold the piece, don't move it"; "Hoia nupp alles" is
  209 dp, past the 200 dp room; "Mine pakku" ("run away") fits only when the piece itself
  moves.
- `settings.by_date` "Tänane" / "Aja järgi" (70 dp): above.
- `puzzle.solved` "Tehtud!" or "Tubli!": declined. They add praise or turn "solved" into
  "done"; "Lahendatud" is the exact word for an *ülesanne* solved and fits (149 dp in
  200). The stars popping in are the praise.
- `game.start_over` "Algusest" or "Uuesti": declined, as in the first pass: "Alusta
  uuesti" fits its 140 dp (130 dp) and showed whole on the tablet.

Checked by this session and kept, with no model proposing otherwise: "Võta {}" (the
user's fix, 2026-11-08; "Võta 2" is 80 dp), "Saa tammiks" (*tammiks saama* is the settled
phrase; 159 dp), "Võida mäng" (149 dp), "Edasi" (natural for going on to the next; 53 dp
at 24 px in the tall tile), "Lahendatud", "{} / {}", "Laua järgi" (the user's), and every
string the first pass reviewed.

## Gemini 4 Argon (Medium), agy's default

As it wrote it, its code fences removed.

````text
language.name | Eesti | keep | Natural self-name for the language selector.
app.name | Kabe | keep | The settled everyday Estonian name for draughts, short and fits 64 px.
home.continue | Jätka | keep | Short, natural imperative for continuing a saved game.
home.friend | Sõbraga | keep | Warm, natural comitative ("with a friend") that works both on the home row and as the setup title.
home.computer | Arvutiga | keep | Matches "Sõbraga" in form ("with the computer") and fits the 12-character room.
home.puzzles | Ülesanded | keep | The natural Estonian word for game puzzles/problems; fits both the home row and the 24 px panel tile.
home.settings | Seaded | keep | Standard, plain Estonian word for settings (avoids the heavier "seadistus") and fits 12 characters.
level.easy | kerge | keep | Plain, child-friendly word for an easy level, lowercase as needed.
level.medium | keskmine | keep | Standard, clear word for the middle difficulty, fits 11 characters.
level.hard | raske | keep | Plain, natural opposite of "kerge".
settings.game | Mäng | keep | Short, plain heading for gameplay settings.
settings.look | Välimus | keep | Natural Estonian heading for visual settings.
settings.tutorial | Õpetus | keep | Plain, clear word for how-to/tutorial.
settings.background | Taust | keep | Short, everyday word for the background picture.
settings.by_date | Kuupäev | Praegune | "Kuupäev" means a calendar date itself (like a date field), whereas "Praegune" ("current", 8 chars) or "Tänane" ("today's", 6 chars) says which season is shown without overflowing the row.
settings.board | Kabelaud | keep | Uses the settled compound for the draughts board and fits the 15-character column.
settings.hints | Vihjed | keep | Short, natural plural noun for move hints.
settings.kings | Tammi kuju | Tammid | "Tammi kuju" is understandable, but plural "Tammid" (6 chars) is shorter and matches the plain noun style of "Vihjed", "Taust", and "Kabelaud".
season.winter | Talv | keep | Standard Estonian season name, short.
season.spring | Kevad | keep | Standard Estonian season name, short.
season.summer | Suvi | keep | Standard Estonian season name, short.
season.autumn | Sügis | keep | Standard Estonian season name, short.
hints.mistakes | Ainult vead | keep | Plain and concise translation of "Mistakes only".
hints.moves | Kõik käigud | keep | Uses the settled word "käigud" and pairs naturally with "Ainult vead".
board.flat | Lame | keep | Plain everyday adjective for a flat 2D board.
board.flat_note | 2D | keep | Universal notation, matches English.
board.raised | Ruumiline | keep | Natural Estonian word for 3D/raised without sounding overly technical.
board.raised_note | 3D | keep | Universal notation, matches English.
kings.auto | Laua järgi | keep | Avoids the anglicism "Auto" / "Automaatne" and explains clearly in 10 characters that the king matches the board style.
kings.crown | Kroon | keep | Short, concrete word a young child knows.
kings.stack | Virn | keep | Short, concrete everyday word for a stack of two pieces.
tutorial.learn | Õpi käike | keep | Warm imperative using the settled word "käik".
game.home | Koju | keep | Warm, natural directional form ("to home") that pairs well with the house icon.
game.start_over | Alusta uuesti | keep | The natural way to say "start over" at a game; at 13 characters with narrow letters (l, i, t) it just fits 140 dp.
game.take_back | Võta tagasi | keep | Everyday board-game phrase for undoing a move, fits 17 characters.
turn.white | Valgete käik | keep | Uses the settled plural genitive "valgete" and "käik".
turn.black | Mustade käik | keep | Uses the settled plural genitive "mustade" and "käik".
won.white | Valged võitsid | keep | Uses the settled plural "valged" and natural past tense.
won.black | Mustad võitsid | keep | Uses the settled plural "mustad" and natural past tense.
setup.draughts | Kabe | keep | Consistent with `app.name` and fits both setup and settings labels.
setup.level | Tase | keep | Plain, short word for difficulty level.
setup.color | Sinu nupud | keep | Warm, direct phrase using the settled word "nupud".
setup.clock | Kell | keep | Plain everyday word for the game clock.
setup.play | Mängi | keep | Clear, inviting imperative on the main start button.
variant.international | Rahvusvaheline | keep | The settled Estonian name for 10 × 10 draughts and fits the 14-character allowance.
variant.brazilian | Brasiilia | keep | The settled Estonian name for Brazilian draughts, fits 11 characters.
variant.russian | Vene | keep | The settled Estonian name for Russian draughts, short.
size.10 | 10 × 10 | keep | Universal board-size notation.
size.8 | 8 × 8 | keep | Universal board-size notation.
pick.easy | Kerge | keep | Consistent with `level.easy`.
pick.medium | Keskmine | keep | Consistent with `level.medium`.
pick.hard | Raske | keep | Consistent with `level.hard`.
color.white | Valged | keep | Uses the settled plural for the white pieces.
color.black | Mustad | keep | Uses the settled plural for the black pieces.
clock.none | Kellata | keep | Concise abessive form ("without a clock") that fits well under the stopwatch icon.
clock.blitz | 5 min | keep | Standard Estonian abbreviation without a period.
clock.blitz_note | +3 s käigule | keep | Clear, concise way to express increment per move using the settled word "käik".
clock.rapid | 10 min | keep | Standard Estonian abbreviation without a period.
clock.rapid_note | +5 s käigule | keep | Matches `clock.blitz_note` and fits 13 characters.
puzzles.stars | {} / {} | keep | Number format needs no translation.
puzzle.next | Edasi | keep | Short, natural word children know for moving to the next step or puzzle.
puzzle.try_again | Proovi uuesti | keep | Encouraging and natural phrasing; drops cleanly to 20 px where 13 characters fit.
puzzle.solved | Lahendatud | keep | Natural completion word matching "Ülesanded" ("the puzzle is solved") and fits 14 characters at 30 px.
goal.take | Võta {} | keep | Uses the settled verb "võtma" in a short, positive imperative.
goal.crown | Saa tammiks | keep | Uses the settled phrase "tammiks saama" in a clear imperative that fits 14 characters.
goal.win | Võida mäng | keep | Direct, positive imperative that fits 30 px.
goal.safe | Ära anna nuppu | Päästa nupp | Replaces the negative "don't give a piece" with a positive, concrete action ("Save the piece", 11 chars) that matches the imperative style of the other three goals.

### Notes

1. **`goal.safe` alternatives**:
   - **Päästa nupp** (11 chars, "Save the piece"): most vivid and immediate for a young child when a piece is under attack; best if the child mostly moves the endangered piece away or rescues it.
   - **Kaitse nuppu** (12 chars, "Protect/defend the piece"): ties directly to the shield icon and feels especially natural when the saving move backs up the threatened piece or blocks the attacker rather than running away.
   - **Hoia nuppe** (10 chars, "Keep your pieces safe"): accurate even if the threat is indirect, though less urgent and concrete than *Päästa* or *Kaitse*.
2. **`settings.by_date` ("Kuupäev" vs "Praegune" / "Tänane")**: Alone on a tile next to *Talv, Kevad, Suvi, Sügis*, the noun *Kuupäev* reads as "Date" rather than "By date" (*Kuupäeva järgi* is 14 chars, too wide for the 5-tile row). *Praegune* ("Current", 8 chars) or *Tänane* ("Today's", 6 chars) fits the tile width and tells a parent at a glance that the app picks the current season.
3. **`puzzle.solved` ("Lahendatud" vs "Tehtud!")**: *Lahendatud* is accurate and pairs with *Ülesanded*, but it is an impersonal passive participle; if you want a warmer voice for a young child when the stars pop in, *Tehtud!* ("Done!", 7 chars) or *Korras!* ("All set!", 7 chars) is how a parent praises a child aloud.
4. **`game.start_over` ("Alusta uuesti" vs "Algusest")**: *Alusta uuesti* (13 chars) is the most natural phrase and should just fit 140 dp because of its narrow letters (`l`, `i`, `t`), but if it wraps or clips on the 24 px game tile, *Algusest* ("From the start", 8 chars) is the cleanest short replacement.
````

## Gemini 4 Argon (High)

````text
language.name | Eesti | keep | Standard, concise self-name for Estonian on a language selector tile.
app.name | Kabe | keep | Settled everyday Estonian name for draughts; short and fits the wordmark.
home.continue | Jätka | keep | Natural, plain imperative for continuing a saved game; fits easily.
home.friend | Sõbraga | keep | Idiomatic comitative ("with a friend") that a child immediately understands.
home.computer | Arvutiga | keep | Parallel with "Sõbraga" ("with the computer") and fits the 12-character room.
home.puzzles | Ülesanded | keep | Standard Estonian word for board-game puzzles; fits both home and the 140 dp panel tile.
home.settings | Seaded | keep | Plain, everyday plural noun for settings without the technical suffix "-seadistus".
level.easy | kerge | keep | Plain lowercase adjective matching `pick.easy` and fitting the note space.
level.medium | keskmine | keep | Plain lowercase adjective matching `pick.medium` and fitting the note space.
level.hard | raske | keep | Plain lowercase adjective matching `pick.hard` and fitting the note space.
settings.game | Mäng | keep | Simple, natural section title for game rules and help.
settings.look | Välimus | keep | Natural Estonian word for how the game looks.
settings.tutorial | Õpetus | keep | Plain Estonian word for a tutorial or guide; fits the left column.
settings.background | Taust | keep | Short, everyday word for the background photo.
settings.by_date | Kuupäev | Praegune | Bare nominative "Kuupäev" means "date", not "by date", while "Kuupäeva järgi" (14 chars) is too long; "Praegune" ("current", 8 chars) or "Tänane" ("today's", 6 chars) fits the 5-tile row and makes sense beside the four seasons.
settings.board | Kabelaud | keep | Settled term for the draughts board; fits the setting column.
settings.hints | Vihjed | keep | Short, natural word for move hints.
settings.kings | Tammi kuju | keep | Uses the settled draughts genitive "tammi" and clearly names what "Kroon" and "Virn" choose inside the 15-character limit.
season.winter | Talv | keep | Plain Estonian name for winter; fits the thumbnail label.
season.spring | Kevad | keep | Plain Estonian name for spring; fits the thumbnail label.
season.summer | Suvi | keep | Plain Estonian name for summer; fits the thumbnail label.
season.autumn | Sügis | keep | Plain Estonian name for autumn; fits the thumbnail label.
hints.mistakes | Ainult vead | keep | Clear, concise phrase ("mistakes only") in plain Estonian.
hints.moves | Kõik käigud | keep | Uses the settled word "käigud" and clearly states that all moves are shown.
board.flat | Lame | keep | Plain everyday word for a flat board.
board.flat_note | 2D | keep | Standard short notation under "Lame".
board.raised | Ruumiline | keep | Natural Estonian word for a 3D/raised view without technical jargon.
board.raised_note | 3D | keep | Standard short notation under "Ruumiline".
kings.auto | Laua järgi | keep | Avoids technical "Automaatne", explains in plain Estonian that the king style follows the board, and stays at 10 characters so the row fits one line.
kings.crown | Kroon | keep | Plain, short word for a crown.
kings.stack | Virn | keep | Plain, short Estonian word for a stack of two pieces.
tutorial.learn | Õpi käike | keep | Warm imperative using the settled word "käik".
game.home | Koju | keep | Warm, idiomatic directional noun ("(go) home") beside the house icon.
game.start_over | Alusta uuesti | keep | Natural phrase for restarting from the beginning; narrow letters help its 13 characters fit 140 dp.
game.take_back | Võta tagasi | keep | Everyday Estonian board-game phrase for undoing a move.
turn.white | Valgete käik | keep | Settled phrasing with plural genitive "valgete" and "käik".
turn.black | Mustade käik | keep | Settled phrasing parallel to "Valgete käik".
won.white | Valged võitsid | keep | Settled phrasing with plural "valged".
won.black | Mustad võitsid | keep | Settled phrasing parallel to "Valged võitsid".
setup.draughts | Kabe | keep | Settled game name; consistent with `app.name` and fits the setting column.
setup.level | Tase | keep | Short, plain word for difficulty level.
setup.color | Sinu nupud | keep | Warm, child-friendly phrasing using the settled plural "nupud".
setup.clock | Kell | keep | Plain, short word for the game clock.
setup.play | Mängi | keep | Clear, inviting imperative on the start button.
variant.international | Rahvusvaheline | keep | Settled variant name ("rahvusvaheline kabe"); 14 characters fit the tile.
variant.brazilian | Brasiilia | keep | Settled variant name ("Brasiilia kabe"); fits the tile.
variant.russian | Vene | keep | Settled variant name ("vene kabe"), capitalized as a tile label.
size.10 | 10 × 10 | keep | Clear board-size notation with a proper multiplication sign.
size.8 | 8 × 8 | keep | Clear board-size notation with a proper multiplication sign.
pick.easy | Kerge | keep | Consistent with `level.easy`, capitalized for the tile.
pick.medium | Keskmine | keep | Consistent with `level.medium`, capitalized for the tile.
pick.hard | Raske | keep | Consistent with `level.hard`, capitalized for the tile.
color.white | Valged | keep | Settled plural for the white pieces, matching "Sinu nupud".
color.black | Mustad | keep | Settled plural for the black pieces, matching "Sinu nupud".
clock.none | Kellata | keep | Concise, natural abessive ("without a clock") that fits under the stopwatch.
clock.blitz | 5 min | keep | Standard Estonian abbreviation (no period) for minutes.
clock.blitz_note | +3 s käigule | keep | Clear, compact note using the settled word "käik" and fitting 13 characters.
clock.rapid | 10 min | keep | Standard Estonian abbreviation for minutes.
clock.rapid_note | +5 s käigule | keep | Parallel to `clock.blitz_note` and fits 13 characters.
puzzles.stars | {} / {} | keep | Clear numeric counter that fits the 9-character note space.
puzzle.next | Edasi | keep | Warm, natural word ("onward/next") with a forward arrow that a young child knows well.
puzzle.try_again | Proovi uuesti | keep | Encouraging, everyday phrase a parent says after a mistake; 13 characters fit at the 20 px fallback.
puzzle.solved | Lahendatud | keep | Natural match for "Ülesanded" ("ülesanne on lahendatud") and fits 14 characters at 30 px.
goal.take | Võta {} | keep | Settled verb "võtma" in a short, positive imperative.
goal.crown | Saa tammiks | keep | Settled phrase "tammiks saama" in a positive imperative; 11 characters fit at 30 px.
goal.win | Võida mäng | keep | Direct, positive imperative that fits 14 characters at 30 px.
goal.safe | Ära anna nuppu | Päästa nupp | "Ära anna nuppu" is a negative instruction ("don't give a piece") that confused children; "Päästa nupp" ("Save the piece", 11 chars) is positive, uses settled "nupp", fits at 30 px, and works whether the move runs away or backs the piece up.

1. **`goal.safe` options for a child**: **Päästa nupp** (11 chars, "Save the piece") tells the child a piece is in danger and this move rescues it, whether by moving it away or plugging the square behind it. **Kaitse nuppu** (12 chars, "Protect the piece") matches the shield icon directly, though to a child it can sound more like guarding the piece in place than escaping with it. **Hoia nuppu** (10 chars, "Keep/guard the piece") or **Hoia nupp alles** (15 chars, "Keep the piece unlost") is warm, but a young child can hear bare *Hoia nuppu* literally as "hold onto the piece / don't move it". **Mine pakku** (10 chars, "Run to safety!") is playful children's Estonian, but only fits when the threatened piece itself moves away.
2. **`settings.by_date` (`Praegune` vs `Tänane` vs `Aja järgi`)**: Bare *Kuupäev* sounds like a noun label ("Date") rather than "by date", while *Kuupäeva järgi* (14 chars) is too wide for a five-tile row. A native speaker should pick between **Praegune** (8 chars, "Current [season]"), **Tänane** (6 chars, "Today's"), and **Aja järgi** (9 chars, "By time/season", parallel to *Laua järgi*).
3. **`settings.kings` (`Tammi kuju` vs `Tammid`)**: **Tammi kuju** (10 chars) is natural and specific ("shape of the king"), while **Tammid** (6 chars, "Kings") would match the simple noun style of the sibling labels *Taust* and *Kabelaud*.
4. **`puzzle.solved` (`Lahendatud` vs `Tehtud!`)**: **Lahendatud** (10 chars) is the exact word for a solved *ülesanne*, but if it feels too school-like when read aloud to a young child, **Tehtud!** (7 chars, "Done!") or **Tubli!** (6 chars, "Well done!") is warmer at home.
5. **`game.start_over` (`Alusta uuesti` vs `Algusest`)**: **Alusta uuesti** (13 chars) is the most natural phrase; only if it looks cramped on the 140 dp tile in the chosen font should it be shortened to **Algusest** (8 chars, "From the start") or **Uuesti** (6 chars, "Again").
````
