# 089: Sound, calm and few

Status: todo

Draughts makes no sound. That was chosen for children on touch devices, and testers
say it feels odd, most of all on a desktop. This task adds a few quiet sounds. They are
off at first on a phone or tablet and on, at half, on a desktop (decided 2026-11-16),
and a Volume row in settings controls them. The sounds follow the same rule as the look: calm, few, no bling.

Prototyped in `prototypes/sound.html`, where every sound below plays as the app would
make it.

## What makes a sound, and what doesn't

The rule: **a sound tells you something happened on the board that you might not have
seen.** It does not reward you, and it does not echo your own tap. A board game in the
real world sounds like this: pieces set down and taken off, and nothing else. Most
children's apps add a sound to every tap, a fanfare to every success, and a buzzer to
every mistake. That trains a child to play for the noise (a variable-reward loop), and
it makes the app tiring to have on in a room. This app's quiet look already says no to
that.

| Sound | When | Take |
| --- | --- | --- |
| A piece set down | When it lands, not at the tap; yours, the computer's, a friend's | Yes. The core sound. The computer's move tells a player who looked away that it's their turn |
| A capture's landings | Each landing a whole tone above the last | Yes. A long capture climbs, and a child hears how many pieces it took without counting |
| The taken pieces | Once, in place of the last landing's knock, as the jumped pieces come off together | Yes. Once a capture, never once a jump: a sound per jump made a capture too busy (2026-11-16) |
| Crowned | A kannel's two plucks up a fifth, in place of the landing's knock | Yes (the kannel chosen 2026-11-16). A real event, and a rare one |
| A puzzle solved | Three rising notes, or one per star as each pops in | Yes. Which version to pick is open |
| A game's end | A win: a soft rising arpeggio. A loss: a plain, warm close. A draw: its own close, the kannel's two low strings (2026-11-16) | Yes. A loss never sounds sad or punishing; a four-year-old losing to Medium should hear an ending, not a judgment |
| A wrong move | Two low soft knocks as the piece slides back | Yes (2026-11-16). Never a buzzer |
| A capture due elsewhere | A piece or square chosen while another piece must capture: the wrong move's two knocks with the second pitched up, a warning but another one | Yes (2026-11-16) |
| A piece picked up | A faint tick | No. It is the sound of your own tap |
| Buttons, menus, tiles, scrolling | | No. UI clicks are the plainest bling, and a phone's own taps already make them where the user wants them |
| The hint, the lookout | | No. Help stays quiet; a sound would make it feel like a reward |
| Stars, dots, today's moon | Except as the solved notes | No extra sounds |
| The clock turns gold | One soft note as a player's clock goes under a minute, when it turns gold | Yes (2026-11-16) |
| The clock turns red | The same note as ri-tai (a sixteenth and a dotted eighth: short, long) at 0:20, when it turns red (2026-11-16, in place of three in a row) | Yes (2026-11-16). Nothing more after it, no flag sound (the end's sound says it) |
| A tick every second | | No. A tick a second makes a player more anxious, not more careful |
| Music, ambience (wind, birds by season) | | No. Maybe never. The seasons' photographs already set the mood, and loops grate after ten minutes |
| Voice | | Not in this task. Lessons may want it (`docs/product.md`), and that is its own decision |

How they sound:

- Muted: the energy sits under about 1.5 kHz. No sharp transient: a 4 ms rise, then a
  one-pole low-pass. Felt or a soft wooden knock, never a hard click on wood.
- Short: a move about 0.1 s; the moments, 0.5 to 1 s. A move never waits for its sound
  to finish.
- Under one another: the moments are mixed well below the move (`GAIN` in the
  prototype), so the loudest sound is the one heard most.
- Never the same twice in a row: the move has three takes, picked at random.
- One sound a move (2026-11-16): a move's most important event plays in place of the
  others, never with them. The game's end, else a crowning, else the taken pieces, else
  the piece set down. A capture's stops before its last keep their rising knocks, each
  a step the player taps; the last landing plays the take (or the crowning, or the end)
  instead of its knock. The clock's sounds and a wrong move are events of their own.
- Tuned together: the notes are on one pentatonic scale (D), so any two that overlap
  sound fine.

## The setting

A **Sound** section between Look and Game, with one **Volume** row. There are two takes
(`&control=` on the page):

- `slider`: a speaker tile that mutes and unmutes, keeping the level, and a slider whose
  thumb is a white piece, its 88 dp strip the touch area. A move's sound plays on
  release, at the new level.
- `steps`: four tiles, off and a speaker with one, two, or three arcs. No words, so a
  child who can't read can use it, and the row is the same widget as every other row.

The level is a gain from -36 dB to 0 dB, so the slider changes evenly along its length.
On a phone it follows the media volume and, on iOS, the silent switch (the ambient
session category, which also keeps the player's own music playing). The level belongs to
the device, not the player, so it goes in the device's settings rather than a player's
file.

## Chosen so far (2026-11-16)

- A move: MattyCauldron's "Chess Pieces" (Freesound 765866, CC0), any of its hits at
  random; a capture's taken pieces: JJTaynos's "Chess Pieces Move (Close)" (733927,
  CC0), the closer sound. Both download at full quality from Freesound, and each needs
  three or more good hits cut from it. No credit is owed (CC0).
- Crowned: the kannel's two plucks (`pluck`, Karplus-Strong).
- A capture due: the wrong move's knocks, the second up (`warn`).
- The first version ships with the prototype's defaults for the rest (2026-11-16): the
  win's three marimba notes, a loss's two low ones, a draw's two low kannel strings, the solved puzzle as one phrase of
  three, the clock's note at gold and as ri-tai at red, and the Volume row as a slider with
  the speaker that mutes.

`prototypes/sound-set.html` plays the whole set, and has takes on the six set by
default (the solved puzzle, the win, a loss, a draw, the clock's gold and red): the mallet
notes against a small calm orchestra (harp, lute, pizzicato strings, soft horns,
celesta, strings held, a bell), in the spirit of Heroes of Might and Magic II's score,
never its tunes, besides the kannel and kalimba.

## The moments' takes

The first win and crowning (marimba) were too much, and something else was wanted,
perhaps a flute or another wooden instrument (2026-11-16). The Moments view
(`&view=moments`) plays takes on each, synthesized, all on D major's pentatonic scale,
and puts any one in the game (`&crown=`, `&win=`, `&end=`, `&must=`, `&take=`):

- Crowned: a piece clicked onto a piece (crowning by hand, the board's own sound), a
  kannel's two plucks, kalimba, a flute's slur up, an ocarina's cuckoo, temple blocks,
  a tongue drum, a music box.
- Won: a kannel strummed or plucked slowly (Estonia's instrument, Karplus-Strong), a
  wooden flute's three notes, a recorder's ta-da, a pan flute, kalimba, a tongue drum,
  temple blocks, a music box, bamboo chimes stirred once, ocarina over a kannel, a
  blackbird (and perhaps each season its own: spring's blackbird, winter's...).
- Lost or drawn: the kannel's low strings, a flute's low note, a tongue drum, kalimba.
- The taken pieces: the clicks, or a pick-up that counts them, one note a piece
  (kalimba or music box) or the pieces gathered into the hand one click each. Heroes
  of Might and Magic II and III, calm games otherwise, gave picking things up on the map
  a lot of sound (2026-11-16): taking pieces is this game's picking up, and counting
  them tells a child how many.
- Music: those games' calm soundtracks are a reference if music ever comes, off by
  default with a slider of its own. Not in this task.

## Where the sounds come from

The first synthesized knocks sounded like an 80s karate game, and the chimes were too
loud (the user, 2026-11-16). The knock is now modal (a few inharmonic modes, a contact
breath, a short thump of the board, no pitch glide), and the chimes are about 14 dB
quieter, the win three notes. The preview is a game to play (tap or drag, wrong squares,
the computer at random), so the sounds are judged in play, not in a scripted demo.
Stone tries Freesound's 351518 (a chess move on alabaster) and 646781 (a piece's
bounce) as the move and the take. Recorded hits are tried beside them:

- `tools/sound_samples.py` fetches about 30 Freesound candidates' public previews (no
  login), cuts each into single hits, matches their loudness, and writes
  `prototypes/samples/samples.js` (local, out of git). The page's **Samples** view plays
  them (127 hits) and makes any one the move's or the take's sound (`&move=ID.K`), so the
  demo and the list use it.
- The candidates: pieces set down (chess, a crokinole disc, Scrabble tiles, board game
  counters), go stones on a wooden board, and slides. Most are CC0; the CC BY ones need
  a credit (the about box or the store listing).
- The one chosen is then downloaded at full quality from its page (a free Freesound
  account), trimmed, faded, low-passed, and embedded as raw PCM
  (`ffmpeg -i in.wav -f f32le -ac 1 -ar 48000 out.raw`); Goose's `audio` reads no files.
- Sonniss's GDC bundles (free, royalty-free) are large archives with no search: browse
  them by hand if Freesound has nothing that fits.
- Recording our own (a piece set down on the real board, a phone 10 to 20 cm away, 30
  takes) remains the surest way to get the sound right.

## The recordings to download

A free Freesound account (freesound.org, "Join"; an email and a password) downloads
the originals. Into `design/sounds/` (local, out of git, as the backgrounds' originals):

- `765866.wav`: MattyCauldron, "Chess Pieces", <https://freesound.org/people/MattyCauldron/sounds/765866/>,
  WAV 48 kHz 24-bit stereo, 51.8 s, 14.2 MB, CC0. The move.
- `733927.wav`: JJTaynos, "Chess Pieces Move (Close)", <https://freesound.org/people/JJTaynos/sounds/733927/>,
  WAV 48 kHz 24-bit mono, 49.0 s, 6.8 MB, CC0. The take.

The hits are cut from them with a script (as `tools/sound_samples.py` cut the previews),
picked by ear, and only the cut hits go into git: a few short mono clips, tens of KB.

## Building it

- Goose's `audio` module (goose_gfx) mixes PCM over SDL3 and has no file decoding, which
  suits this: the sounds are made once at startup with plain sample math into `f32`
  arrays (`audio::create_sound`). The prototype's `knock`, `note`, `brush`, and `phrase`
  port line for line. No asset files, and about 1 s of samples (≈200 KB).
- Open the device only while the level is above zero, and close it when the level is set
  to zero: a phone at its default never opens audio, so it takes no audio focus and uses
  no battery for it.
- The clock's two sounds play for a person's clock only (both against a friend, never
  the computer's), once each a game per side: an increment that lifts the time back
  over a line doesn't arm it again.
- Hits from a recording: the move's three takes are one hit at three pitches unless the
  chosen recording has three good ones; a capture's landings are the same hit a tone up
  each.
- Play from the board's animation events (a piece landing, a piece removed, crowned),
  not from input, so a sound always lines up with what you see, whoever moved.
- Nothing allocates in the frame loop: the voices are the mixer's, and a play is one call.
- The strings `settings.sound` and `settings.volume`, and the steps' accessible names, go
  into every `strings/<lang>.txt`.
- Record the decision in `docs/decisions/` and how it works in `docs/architecture/`.

## Acceptance criteria

- [x] The move's and the take's sound, the crowning, and the capture due (2026-11-16)
- [x] The rest: the prototype's defaults for the first version (2026-11-16)
- [ ] The sounds in the table's "Yes" rows play in the app, from the board's events, in
      a game, a puzzle, How to play, and the settings' preview
- [x] Defaults decided (2026-11-16)
- [ ] Off by default on Android and iOS, half on macOS, Windows, and Linux; the level
      kept per device
- [ ] The audio device opened only while the level is above zero
- [ ] Checked on the Mac and on the tablet (and that the tablet's media volume and an
      iPhone's silent switch govern it)
- [ ] `docs/decisions/` and `docs/architecture/` updated; the Volume row folded into
      `prototypes/settings.html`, and `sound.html`, `sound-set.html`, `sound.js`, and
      `tools/sound_samples.py` removed, the decision naming the commit that last has them
