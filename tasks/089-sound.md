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
| A taken piece | A soft brush as it leaves the board, under the landing | Yes |
| Crowned | Two soft mallet notes after the landing | Yes. A real event, and a rare one |
| A puzzle solved | Three rising notes, or one per star as each pops in | Yes. Which version to pick is open |
| A game's end | A win: a soft rising arpeggio. A loss or a draw: a plain, warm close | Yes. A loss never sounds sad or punishing; a four-year-old losing to Medium should hear an ending, not a judgment |
| A wrong move | Two low soft knocks as the piece slides back | Try it in play. The red flash and "try again" may say enough. If it stays, it must never sound like a buzzer |
| A piece picked up | A faint tick | No. It is the sound of your own tap |
| Buttons, menus, tiles, scrolling | | No. UI clicks are the plainest bling, and a phone's own taps already make them where the user wants them |
| The hint, the lookout | | No. Help stays quiet; a sound would make it feel like a reward |
| Stars, dots, today's moon | Except as the solved notes | No extra sounds |
| The clock running low | A tick a second in the last ten | Not now; only if players with a clock ask |
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
- One moment at a time: a crowning that ends a game plays the end sound only.
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

## Where the sounds come from

The first synthesized knocks sounded like an 80s karate game, and the chimes were too
loud (the user, 2026-11-16). The knock is now modal (a few inharmonic modes, a contact
breath, a short thump of the board, no pitch glide), and the chimes are about 10 dB
quieter. Recorded hits are tried beside them:

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

## Building it

- Goose's `audio` module (goose_gfx) mixes PCM over SDL3 and has no file decoding, which
  suits this: the sounds are made once at startup with plain sample math into `f32`
  arrays (`audio::create_sound`). The prototype's `knock`, `note`, `brush`, and `phrase`
  port line for line. No asset files, and about 1 s of samples (≈200 KB).
- Open the device only while the level is above zero, and close it when the level is set
  to zero: a phone at its default never opens audio, so it takes no audio focus and uses
  no battery for it.
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

- [ ] The user picks: slider or steps; the move's and the take's sound (synthesized, a
      Freesound hit, or recorded; or by the board's material on the raised board); solved as one phrase or a note per star; the wrong move's
      knocks or silence
- [ ] The sounds in the table's "Yes" rows play in the app, from the board's events, in
      a game, a puzzle, How to play, and the settings' preview
- [x] Defaults decided (2026-11-16)
- [ ] Off by default on Android and iOS, half on macOS, Windows, and Linux; the level
      kept per device
- [ ] The audio device opened only while the level is above zero
- [ ] Checked on the Mac and on the tablet (and that the tablet's media volume and an
      iPhone's silent switch govern it)
- [ ] `docs/decisions/` and `docs/architecture/` updated; `prototypes/sound.html` folded
      into `settings.html` once built
