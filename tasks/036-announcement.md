# 036: Announce the app

Status: todo (after the Play release, task 029; the numbers after tasks 032 and 030)

What the user needs to announce Draughts once it is on Google Play: a tweet, a post in
the Goose Discord's demos channel, later a short video, and a Twitter thread on how it
is built, with a line on why it exists. Facts and angles, not finished prose. Wording
stays plain and concrete: numbers over adjectives, nothing claimed that isn't measured.

The facts below that won't change are written up now. The numbers that tasks 032
(memory, the blur) and 030 (screen sizes) will move are listed with how to measure them,
marked "measure after 032 and 030"; collect them then, not from the older tasks.

## Why it exists

- The user's reason: there was no similar app that was free, good, and modern. What
  that means here: no ads, IAP, or tracking; made for young children; the draughts
  Estonians play (Russian 8 × 8 and International 10 × 10); a calm, current look.
- And a reason for the Goose crowd: a real app, end to end, in Goose on Android.

### Checked against the stores (accessed 2026-11-08)

How: web search and the store pages. Google Play's app pages didn't load for the
research (only the title came back), so where marked "secondhand" the facts come from
AppGoblin (appgoblin.info) or a search snippet, not Play itself. Play's Data safety
pages loaded for two apps. Check the notable ones by hand on Play before quoting them.

- **lidraughts** (`org.lidraughts.mobileapp`; App Store id1485028698; open source,
  GPL-3.0, github.com/RoepStoep/lidrobile). The closest. Free, no ads, no in-app
  purchases ("100% free, without ads, and open source!" on the App Store). Play's Data
  safety: nothing shared; optional name, email, user IDs, in-app messages collected for
  the account. Apple 4+. All the variants, International 10 × 10 being lidraughts' main
  one, plus Russian, Brazilian, Frisian. Offline: games against the Scan engine, puzzles,
  over the board (lidraughts.org blog post on the app). Last update 2025-06-01 on Play,
  about 159 K installs (secondhand). The catch: an online club client first, with
  accounts, chat, and tournaments, and Lichess's plain adult interface; not made for a
  young child, no Estonian found.
  https://play.google.com/store/apps/details?id=org.lidraughts.mobileapp,
  https://play.google.com/store/apps/datasafety?id=org.lidraughts.mobileapp
- **Blidraughts** (F-Droid, `com.vovagorodok.blidraughts`), a lidraughts fork for
  Bluetooth boards: F-Droid flags Non-Free Assets and Tethered Network Services
  (needs lidraughts.org). Same catch.
  https://f-droid.org/en/packages/com.vovagorodok.blidraughts/
- **Draughts 10x10** (`mkisly.icheckers`, Miroslav Kisly). About 1.7 M downloads,
  updated 2026-07-22 (secondhand); offline computer and online play; International,
  Russian, English, Turkish, Spanish. Play's Data safety: device IDs, app activity,
  personal info shared with other companies for analytics and advertising; no way to
  ask for deletion. Ads reported by a review; Play's "Contains ads" label not checked.
  https://play.google.com/store/apps/details?id=mkisly.icheckers
- **Checkers - Offline** (`com.fooview.android.game.checkers`, foo Game Group). 3.4 M+
  installs, updated 2026-04-13; offline; American, International, Brazilian, Russian;
  ads are its whole income, no IAP (all secondhand). Data safety not checked. The
  catch: ads. https://appgoblin.info/apps/com.fooview.android.game.checkers
- **Checkers Online** (`com.rstgames.checkers`, Magic Board). 3.1 M installs, rated
  3.0; four ad SDKs found (Google, Unity, Yandex, ironSource) and IAP; Russian and
  International, online first with accounts (secondhand).
  https://appgoblin.info/apps/com.rstgames.checkers
- **Checkers & Draughts Board Game** (`com.dawikk.checkers`, Dawikk). Offline against
  the Scan and Cake engines, International, Russian, Brazilian and more; ads and IAP;
  under 1 K installs (secondhand). https://appgoblin.info/apps/com.dawikk.checkers
- **Draughts 10x10** on iOS (UAB Target Works, id531472336). Free with a $4.99
  "Remove Ads"; Apple's label lists Data Used to Track You (location, identifiers,
  usage); International only; last version 2024-01-02.
  https://apps.apple.com/us/app/draughts-10x10/id531472336
- **Checkers/Draughts & Variants** on iOS (Jocly, id522064154). International,
  Brazilian, and a Kids 6 × 6 among many variants, offline; free with a $0.99 "Remove
  ads"; last version 2015-02-15, so dated. https://apps.apple.com/app/id522064154
- **Checkers (Privacy Friendly)** (F-Droid, `org.secuso.privacyfriendlydame`, SECUSO at
  KIT). No ads, no anti-features, offline, against the computer or two players; updated
  2025-09-08. The catch: plain checkers, apparently 8 × 8 only (variants not listed);
  no 10 × 10 or Russian, not made for children.
  https://f-droid.org/en/packages/org.secuso.privacyfriendlydame/
- **AI Factory Checkers** (`uk.co.aifactory.checkers`) and **Dalmax Checkers**: the
  well-known ones; AI Factory's free version has ads (a paid Pro has none); neither's
  Data safety could be checked.
- **For children**: no checkers app on Play made for young children (Teacher Approved
  or Designed for Families) turned up; a roundup found 7 of 8 offline checkers apps on
  Play marked "Contains ads".
- **GoDraughts** (`net.devdad.internationaldraughts`,
  https://play.google.com/store/apps/details?id=net.devdad.internationaldraughts, and a
  free website, https://godraughts.com/en; pointed out by the user 2026-11-08): "free",
  International only, accounts synced across web, Android and iOS, online play, tactics
  puzzles, an interactive rules tutorial, training courses, coaching from the player's
  own mistakes, six computer levels. A good, modern app; ads and data collection not
  stated on its site, so check Play's Data safety. Its catch for this claim: an online,
  account-based trainer for adult players, International only, not made for young
  children. Worth naming as a good one alongside lidraughts.
- **Estonian**: no draughts app with Estonian text found (a search absence, not proof;
  Play's own search for "kabe" wasn't possible from here).

### Verdict

- The claim holds with caveats. No app found is at once free with no ads, IAP, or
  tracking, offline, made for young children, modern-looking, and has International,
  Russian, and Brazilian, let alone Estonian. Apps with the variants offline carry ads
  or share data (foo Game, Dawikk, Magic Board, Draughts 10x10).
- The closest counterexamples are lidraughts and GoDraughts. lidraughts: free, open source, no ads or tracking, every
  variant, offline play against Scan. It is not "nothing like it exists"; it is an
  adult online club app, not one for a young child.
- So don't say "no such app exists". Plain phrasings to start from:
  - "I couldn't find a draughts app for young kids that is free with no ads or
    tracking and has International and Russian draughts, so I made one."
  - "lidraughts is great and free, but it's an online club app, not one for a
    young child."
  - In Estonian contexts: "I found none in Estonian."
- Check again the week of the announcement; stores change.

## What it is

For the tweet and the Discord post:

- A draughts (checkers) app for children of about 5 to 8, on an Android tablet first,
  free on Google Play.
- Three draughts: International 10 × 10 (the default), Brazilian 8 × 8 (International's
  rules on 8 × 8), and Russian 8 × 8 (what Estonians play as kabe). The engine also
  plays English checkers, not offered yet (`docs/architecture/rules.md`).
- Play a friend on one tablet, or the computer at three levels that make mistakes the
  way a person does, not the way a weakened engine does: each level sees a fixed number
  of plies and picks among the moves it sees as good. It adapts: 4 skill points up
  after the child wins, 4 down after a loss, within 20 of the level's start
  (`docs/architecture/ai.md`).
- Optional clocks, 5 min + 3 s and 10 min + 5 s; against the clock the computer takes
  as long as a player of its level would, never enough to lose on time.
- 30 International puzzles in three tiers (find the capture; many jumps and crowning;
  shots and the only safe move), all composed for the app and checked by the engine and
  an independent Python move generator (task 007).
- Help that doesn't do the thinking: by default no legal-move dots; a wrong move flashes
  and the piece that must capture pulses. Puzzles never show targets.
- Usable without reading: icons and big tiles, 88 dp at least.
- Four seasons, picked from the date: a calm Estonian landscape behind each (autumn
  forest, winter spruces, spring birches, summer coast) and a board to match (wood,
  stone, birch, sunset).
- English and Estonian, from the system's language; a new language is one text file.
- No ads, no in-app purchases, no tracking, no analytics, no accounts, no network
  (`docs/product.md`, "Not planned"). The game is kept on the device and comes back
  where it was.
- Plain wording to start from: "Draughts for young children: International, Brazilian
  and Russian, a computer that plays like a person, 30 puzzles. Free, no ads, no
  tracking, no network."

## The stack and methods

For the thread and the Discord post. Each with where it is written down; the numbers
are in "Numbers to gather" below.

- **Goose, compiled to C.** No GC, no heap: values on the stack or on bump-pointer data
  stacks freed at scope end. On the Mac, packages and tests run in the compiler's
  process through TinyCC with no build step; the app is built with `goose build` (-O2
  C) since it starts a thread (`docs/architecture/README.md`, `agents/goose.md`).
- **goose_gfx on SDL3's GPU API**: Vulkan on Android, Metal on the Mac; GLSL compiled
  to SPIR-V and MSL at compile time and embedded (`embed_shader`). No engine.
- **No Gradle.** `scripts/android.py` (about 200 lines of Python) builds the APK: Goose
  writes C, the NDK's clang and CMake build `libSDL3.so` and `libmain.so`, `javac` and
  `d8` compile the Java (SDL's, plus a tiny splash class of ours), `aapt2`,
  `zipalign -P 16`, `apksigner` (`docs/development.md`).
- **Draws only when something changed.** goose_gfx's `frame()` patched to skip the
  present when nothing drew and to wait for an event up to 1 s; idle is one wakeup a
  second and no GPU work. A running clock sets an SDL timer for its next second instead
  of drawing every frame, and a computer's move due later sets one too
  (`docs/architecture/rendering.md`, "Frames and battery").
- **No allocation in the frame loop.** Per-frame arrays reset each frame, fixed tables
  sized at startup (the UI's quads: one fixed array of 512; the pieces: one storage
  buffer). The computer's queues allocate once a turn, never per frame
  (`docs/architecture/README.md`, "Rules every part keeps").
- **NoGraphicsAPI's ideas inside SDL_GPU**: vertex pulling from storage buffers (no
  vertex layouts), one upload per frame in flight, all pieces in one instanced draw,
  the whole UI in one instanced draw (`docs/architecture/rendering.md`, "Drawing").
- **SDF everything**: pieces (flat matte discs with a groove, a rounded shoulder, soft
  light from above), the crown, rings, rounded glass panels and their shadows, and the
  line icons as distances to their strokes, all in fragment shaders; crisp at any size
  with no textures.
- **The board pass**: the blurred photograph, the board's shadow, lip, squares, wood or
  stone surface (a few sines and value noise), and the marks are one full-screen
  fragment pass, worked out at `gl_FragCoord`.
- **Glass without a live blur**: the season's photograph is blurred once on the GPU when
  the season is picked (two Gaussian passes into 512 × 512 for behind the board, two
  more into 256 × 256 for the glass), square so the same blur serves every screen size
  and orientation; a glass panel is one texture fetch per pixel. Idea from Snowtime,
  which measured live backdrop blur costing more than its weather animation. (Sizes may
  change in task 032.)
- **Photographs embedded as JPEG** (`embed_file`), decoded with stb_image (NEON on ARM)
  in the program's own C, since goose_gfx's `load_texture` reads only PNG and BMP from
  files; nothing read from Android's asset manager. Fonts, strings, and puzzles are
  embedded the same way.
- **Text**: Libertinus Sans baked by goose_gfx's `ui` atlas once per size at the
  screen's pixel size, glyph boxes copied into `gui`'s fixed tables (so text lays out
  headless in tests), then the atlas destroyed; a glyph is one more quad kind in the
  UI's one draw.
- **An immediate-mode UI of our own** (`gui/`, about 580 lines): rect cuts, widgets with
  press state, quads appended to one fixed array; tested headless.
- **The rules as pure functions over values**: bitboards with ghost bits, so every
  diagonal step is a fixed shift; a position is a few `u64`s and the side to move; the
  variant is data (board size, flying kings, majority rule, crowning mid-capture).
  Perft matches published counts: International to depth 10 (258,895,763), English to 11,
  Brazilian to 11; Russian agrees with an independent Python generator to depth 10
  (`docs/architecture/rules.md`).
- **Only `app/` imports graphics.** `rules`, `ai`, `puzzles`, `board`, `gui`, `game`,
  `shell` are tested headless; a second renderer would rewrite only `app/`.
- **The computer**: negamax alpha-beta with iterative deepening, a transposition table
  of 2^18 entries (4 MB) made once, killer moves and history; it counts nodes, never
  time, so the same position, skill, and seed give the same move on every machine; the
  search is unrolled into one frame per ply so it can stop after any node. It runs on
  one worker thread with Goose's typed queues; a newer ask (take back) drops the search
  under way. Levels from Regan and Haworth's model of how players of a strength choose
  among moves (`docs/architecture/ai.md`).
- **Pacing its clock**: a share of what it could spend each move, more when several
  moves are close, less for a lone capture, quick in the opening; capped at 4, 8, 15 s
  by level and a tenth of its clock (`game/pace.goose`, task 027).
- **Animations as pure functions of time**: the win (the winning piece lifts, a ring of
  glow passes outward across the winner's pieces, the board dims, a card slides up)
  and the home-to-settings transition are each computed from the time since they began,
  so a test can sample any moment, and each ends still, after which nothing is drawn
  (tasks 031, 022).
- **Saving**: the game is one flat value written with Goose's `to_bytes` and an FNV-1a
  checksum, about 15 KB, when the app pauses (Android may kill it).
- **Patches, applied at build time to copies**, never to the submodules: goose_gfx
  `0001-no-clip-distance` (Mali GPUs lack `shaderClipDistance`, so SDL_GPU wouldn't
  start), `0002-draw-on-demand`; SDL `0001-destroy-swapchain-on-surface-recreate` (a
  swapchain leaked on every Android resume, three 1920 × 1200 images each time). Plus
  SDL's poll sentinel off on Android, without which `SDL_WaitEventTimeout` spins a whole
  core (`docs/goose-findings.md`). goose_gfx changes are being prepared for upstream
  (task 010); the SDL ones are the user's to report in their own words, as SDL takes no
  AI-written reports.
- **Measured, not guessed**: `scripts/idle_cpu.sh`, `scripts/lifecycle_memory.sh`,
  `screenrecord` frame times, `tools/aibench.goose` on the tablet through
  `scripts/android_cli.sh` (a headless Goose program as a plain Android executable).

## Numbers to gather (measure after 032 and 030)

Take each on the release build, on the Galaxy Tab A11+ (SM-X230, Mali-G615, 90 Hz) and
on the Pixel 7a, and record them here with the date and commit. The older tasks' values
are only to show the scale; don't quote them.

- **Idle CPU**, measure after 032 and 030: `scripts/idle_cpu.sh 60` (and 300 once task
  011 is in) on the game at rest, settings, a puzzle, and a running clock; the program's
  thread and the whole process, and wakeups. Earlier: the program's thread 0.02 to
  0.03% of a core, the process about 1.5 s a minute (tasks 007, 025, 032), 0.5% with a
  clock running (task 021).
- **Memory**, measure after 032 and 030: `scripts/lifecycle_memory.sh 20` for PSS,
  native heap, graphics, flat over cycles; and task 032's table of where it goes.
  Earlier: PSS 261 to 274 MB, graphics 206 to 215 MB (task 032).
- **Frame times**, measure after 032 and 030: `adb shell screenrecord` during a move, a
  win, a transition, a puzzle's slide back; median and max frame interval. Earlier:
  median 11.0 ms, max 12.4 ms in the win (task 031).
- **APK size**, measure after 032 and 030: `ls -l build/android/draughts/*.apk`, and the
  AAB's download size from Play Console; split into `libSDL3.so`, `libmain.so`, the
  photographs, the icon. Earlier: 5.9 MB (task 028).
- **Textures and blur**, measure after 032: each texture's size and format and the time
  a season change takes (task 032's table).
- **Launch**: `adb shell am start -S -W` cold `TotalTime`, and icon-to-first-frame from
  `screenrecord`. Earlier: 197 to 241 ms, the splash 400 to 460 ms (task 028).
- **The computer**: `scripts/android_cli.sh tools/aibench.goose` (hard's slowest reply,
  nodes a second, big and little cores). These won't move with 032 and 030, but take
  them on the release commit. Earlier: hard at most 207 ms on the big cores, 4.3 M
  nodes/s (task 006).
- **Code**: `git ls-files '*.goose' | xargs wc -l`, by top-level directory; the tests
  (`ls test/expected | wc -l`, `test/run_tests.py`); `scripts/test.sh`'s time; `goose
  build` of the app (`time`) and a clean `scripts/android.py` build.
- **Project time**: first commit 2026-11-07 (`git log --reverse`), commits to the
  release (`git rev-list --count HEAD`).

## Goose angles

For the demos channel, where people know Goose:

- **What Goose made easy**:
  - Data stacks: no `malloc` or `free` anywhere in the game, yet no GC; per-frame data
    is freed by leaving the scope.
  - TinyCC: packages and 34 headless tests run straight from source; editing the rules
    and rerunning is instant.
  - `embed_shader` and `embed_file`: GLSL compiled to SPIR-V and MSL at compile time;
    shaders, fonts, photographs, strings, and puzzles inside the binary.
  - Threads with typed queues: the computer's worker is about 75 lines
    (`app/think.goose`); nothing shared, no locks.
  - `to_bytes` / `from_bytes` for the saved game, with a shape check.
  - Goose ran on Android through Vulkan with no change to the compiler or runtime
    (task 001); it took one goose_gfx patch, one SDL patch, a logcat shim,
    and a shared SDL build.
  - The program's own C beside it (`c_sources`): stb_image, SDL timers, JNI calls.
- **What was missing** (`docs/goose-findings.md`): no way to ask the platform (used
  `ANDROID_ROOT`); stdout goes nowhere on Android (a logcat shim); goose_gfx's
  `frame()` always presents (patched to draw on demand); SDL_GPU's default features
  need clip distances Mali lacks (patched); `ui::input_from_gfx` opens the keyboard;
  goose_gfx builds SDL static where SDL's Java loads it shared; `load_texture` reads no
  JPEG and nothing from memory. Each with a proposal for upstream (task 010).
- **Lines of Goose** (2026-11-08, `wc -l` over tracked `.goose` files, blank and
  comment lines included, GLSL inside the `.goose` files counted; recount at release):

  | Directory | Lines | What |
  | --- | --- | --- |
  | `rules/` | 455 | the rules, four variants |
  | `ai/` | 754 | the computer |
  | `puzzles/` | 529 | puzzle file and exact search |
  | `board/` | 555 | the board on screen, taps, animation |
  | `gui/` | 576 | the UI layer |
  | `game/` | 753 | the game screen, clocks, pacing, the win |
  | `shell/` | 1706 | home, setups, settings, puzzles, saving |
  | `strings/` | 241 | the string table |
  | `app/` | 1492 | main loop, GPU drawing and shaders, worker |
  | `tools/` | 652 | perft, benchmarks, terminal game, puzzle checks |
  | `test/` | 3147 | 34 tests and helpers |
  | `poc/` | 223 | task 001's and 005's small programs |
  | All | 11,083 | |

  The game without tools, tests, and poc: 7,061. Besides Goose: about 340 lines of C in
  `app/` and `android/`, one 106-line Java activity, three patches (158 lines), and
  Python scripts (`scripts/android.py` 203, `scripts/icon.py` 112, `test/perft.py` 334).
- **Build times**: `goose build` of the app about 3 s on the Mac (`docs/development.md`);
  the full test script about 20 s. Remeasure at release.
- **The tablet**: a Galaxy Tab A11+ with a MediaTek chip and a Mali-G615 MC2, an entry
  tablet, not a flagship.
- An angle for both channels: Goose's own Mini Minecraft HUD was the model for the UI
  layer.

## Tweet

- One tweet, a screenshot or a 10 s clip, the Play link. Angles to choose from:
  - What it is and the catch it doesn't have (free, no ads, no tracking, no network).
  - "Made for young children" as the reason.
  - The tech in one line: "Goose compiled to C, SDL_GPU on Vulkan, no engine; it draws
    nothing while idle."
- A draft to cut from: "I made a draughts app for young children: International,
  Brazilian and Russian, a computer that plays like a person, 30 puzzles, four seasons.
  Free on Android, no ads, no tracking, no network. [link]"
- Avoid: "beautiful", "the best", "blazing fast", emoji runs, hashtags beyond one.

## Discord post (Goose demos)

- Lead with a clip or two screenshots (landscape game, a puzzle) and the Play link.
- Then the Goose angles above: what it is, the stack, lines per area, what was missing
  and the patches, the link to the repo if it is public.
- Offer the goose_gfx patches as PRs, or link them if already sent (task 010).

## Thread on the methods

An outline, one tweet each, each with a number or an image:

1. Why it exists and what it is (the tweet above).
2. The stack: Goose → C, goose_gfx, SDL_GPU on Vulkan and Metal; no engine, no Gradle.
3. Draws only on change: the patched `frame()`, the idle CPU, the clock's timer.
4. No allocation in the frame loop: data stacks, fixed buffers.
5. Rendering: SDF pieces, one board pass, one instanced draw per layer; a screenshot
   of the pieces up close.
6. Glass: the photograph blurred once on the GPU, square so one blur fits every screen.
7. The rules as pure functions on bitboards; perft against published counts.
8. The computer: plays like a person (sees N plies, chooses like a human of a
   strength), on a worker, deterministic by nodes; how it spends its clock.
9. Animations as functions of time, ending still: the win.
10. Memory and APK size, with what task 032 cut.
11. Android without Gradle; the SDL and goose_gfx bugs found by measuring (the
    swapchain leak, the spinning wait).
12. Links: Play, the repo if public, Goose.

## Video

About 30 to 60 s, no voice; captions in the corner at most.

- **Shot list**, in order:
  1. The icon on the tablet's home screen, a tap, the launch straight to home (3 s).
  2. Home with the sharp season photograph and the board; open settings, the board
     sliding aside (the transition), change the season, back (8 s).
  3. A new game against the computer: the setup's board switching 10 × 10 to 8 × 8,
     play (5 s).
  4. A few moves, a multi-jump capture, the computer's pulse and its reply (10 s).
  5. A wrong move flashing and the piece that must capture pulsing (4 s).
  6. A puzzle: a miss sliding back, then solved, the stars popping in (8 s).
  7. A win: the glow passing across the pieces, the card (4 s).
  8. Rotate to portrait mid-game (4 s).
  9. The four seasons in quick cuts (4 s).
  10. End card: the name, "free, no ads, no tracking", the Play badge (3 s).
- **Capture**: `adb shell screenrecord --bit-rate 20M` on the tablet at its 90 Hz
  (it records up to 180 s a clip), both orientations; the Pixel 7a for one phone shot.
  Start with flags (`--screen`, `--puzzle`, `--fen`, `--computer`) so each shot starts
  where it should and `game.bin` stays untouched (`docs/development.md`). Hands on
  screen only if filmed with a camera; taps from `adb shell input tap` look unnatural.
- **Edit**: cut to 60 fps or keep 90; check Twitter's and Discord's current video
  length and size limits when posting.

## Before announcing

- [ ] The app live on Google Play (task 029), in English and Estonian; its link checked
      from a phone and a tablet.
- [ ] Screenshots for posts, taken on the final layouts (after 030), both orientations,
      a season each.
- [ ] The numbers above measured after 032 and 030, recorded here.
- [ ] The repo: public or not (ask the user). If public: a license (none is in the repo
      now; the fonts are OFL, goose_gfx and SDL keep theirs), a short `README.md` for
      visitors (what it is, a screenshot, the Play link, how to build; the present one
      still says "checkers" and describes the state of task 002), and a check that no
      local paths, keys, or design masters are in the history.
- [ ] The privacy policy URL from task 029 works.
- [x] `docs/product.md`'s "no Java/Kotlin of our own" reworded to one small Java class
      (2026-11-08).
- [ ] The goose_gfx patches proposed upstream or linked (task 010).
- [ ] The video cut and checked on a phone.

## Open questions for the user

- Public repo, and under which license?
- Announce under the user's name and account, or the app's?
- Post the Estonian side too (an Estonian tweet, Estonian forums or draughts clubs)?
- iOS later: say so in the post, or not until it exists?
- Which channel first: Discord demos (friendlier, technical) before Twitter?

## Acceptance criteria

- [ ] The "why" claim checked again against the stores in the week of the announcement
- [ ] The numbers gathered after tasks 032 and 030, each with date, commit, and method
- [ ] Tweet, Discord post, and thread written from this file and approved by the user
- [ ] The video cut, 30 to 60 s
- [ ] Posted, with links working
