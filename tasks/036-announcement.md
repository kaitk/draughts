# 036: Announce the app

Status: todo (after the Play release, task 029)

What the user needs to announce Draughts once it is on Google Play: a tweet, a post in
the Goose Discord's demos channel, later a short video, and a thread on how it is built.
Facts and angles, not finished prose; numbers over adjectives, nothing claimed that
isn't measured. What the app is comes from `store/listing-en.md` and `README.md`; how
it is built from `docs/architecture/`. The full first draft of this file (store survey,
stack notes, outlines) is in git at 314c3b5.

## Why it exists

The user's reason: no draughts app was free, good, and modern: no ads, IAP, or tracking,
made for children too, with the draughts Estonians play, and a calm, current look. For
the Goose crowd: a real app, end to end, in Goose on Android and iOS.

Checked against the stores 2026-11-08 (recheck the week of the announcement):

- lidraughts (`org.lidraughts.mobileapp`, open source) is free, ad-free, offline against
  Scan, with every variant, but an adult online club app first. GoDraughts is a good
  modern trainer, International only, account-based.
- The offline apps with the variants carry ads or share data (Draughts 10x10
  `mkisly.icheckers`, Checkers - Offline, Checkers Online, Dawikk). No checkers app made
  for children turned up on Play, and none in Estonian.
- So never "no such app exists". Start from: "I couldn't find a draughts app that is free
  with no ads or tracking, made for kids too, with International and Russian draughts, so
  I made one." and "lidraughts is great, but it's an online club app."

## Numbers to gather

On the release build, on the tablet and the Pixel 7a, each with date and commit:

- Idle CPU (`tools/perf/idle_cpu.sh 60`) at rest, in settings, a puzzle, a running clock
- Memory (`tools/perf/lifecycle_memory.sh 20`): PSS, native heap, graphics
- Frame times during a move, a win, a transition
- APK and AAB download size, split into `libSDL3.so`, `libmain.so`, the photographs
- Cold launch (`adb shell am start -S -W`)
- The computer's slowest hard reply (`tools/android_cli.sh tools/aibench.goose`)
- Lines of Goose by directory, the tests' count and time, build times, commits

## Angles

- Tweet: a clip or screenshot and the Play link; what it is and the catch it doesn't
  have; or the tech in one line ("Goose compiled to C, SDL_GPU on Vulkan, no engine; it
  draws nothing while idle"). No "beautiful", "best", "blazing fast", emoji runs.
- Discord: what Goose made easy (data stacks and no `malloc`, TinyCC tests from source,
  `embed_shader`/`embed_file`, typed queues for the computer's worker, `to_bytes`), what
  was missing (`docs/goose-findings.md`), lines per area, the patches offered upstream
  (task 010).
- Thread, one number or image each: why; the stack; drawing only on change; no
  allocation in the frame loop; SDF pieces and one-draw UI; glass from a blur done once;
  bitboard rules and perft; a computer that errs like a person; animations as functions
  of time; memory and size; Android without Gradle and the bugs found by measuring.
- Video, 30 to 60 s, no voice: launch, home and settings' transition, a game with a
  multi-jump, a wrong move's flash, a puzzle solved, a win, a rotation, the seasons, an
  end card. `adb shell screenrecord --bit-rate 20M`, started with `--screen`/`--puzzle`/
  `--fen` flags so each shot starts where it should.

## Open questions for the user

- The license; whether to post under the user's account or the app's; Estonian posts and
  clubs; which channel first.

## Acceptance criteria

- [ ] The app live on Play in English and Estonian, the link checked from a phone and a
      tablet; the privacy policy URL works
- [ ] The "why" claim checked again against the stores that week
- [ ] The numbers gathered, each with date, commit, and method
- [ ] Tweet, Discord post, and thread written and approved by the user
- [ ] The video cut, 30 to 60 s
- [ ] Posted, with links working
