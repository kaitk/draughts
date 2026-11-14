# Release notes

Each version's notes for the GitHub release (the desktop builds) and the stores' "What's
new": Play's in en-GB and et (500 characters each), the App Store's in en-GB alone (no
App Store localization yet, `app-store.md`). Newest first.

## 0.8.0 (2026-11-14)

The first release with the daily puzzles; the 0.7.8 pre-release's notes are folded in.
Android, iPhone, and the Mac come from 0.5.0, Windows and Linux from 0.5.1.

### GitHub release

```markdown
Daily puzzles at your level, a stronger computer, and a tidier game screen.

Draughts is open source, under the MIT or Apache 2.0 licence: the code is here, at [github.com/kaitk/draughts](https://github.com/kaitk/draughts). No ads, no tracking, no accounts; it works offline.

**New**

- **Daily puzzles.** Once Learn is solved in any draughts, a few puzzles a day in each (4 by default; 3, 5, or 10 in settings) at the player's own level: a warm-up, two at their level, and one a bit harder. They come from a library of over 7,000 puzzles for International, Russian, and Brazilian draughts, among them traps that punish a careless move, reaching well past the course to ones that make a grown-up think. Home shows today's puzzles as dots, and the library's Today's puzzles row holds them; a new set comes each day, and none repeats.
- **A puzzle rating** per player and draughts, started from the stars won in the course (or the best rating the player has in another draughts), moves fast at first and settles with time.

**Better**

- **The computer plays stronger:** it now weighs men running for the crown, kings on the main road, kings that are stuck, and how the men are spread across the board.
- **The replay shows each move** on the board, shaded at every stop with its start faded, and compares it with the best: the bulb, or the line saying what was best, shows the position before the move with the move played and the best one side by side, and play from here plays from there. Marks are closer to lidraughts'.
- On a phone held upright, what each side has taken sits on a card of its own beside the last move, in place of one wide bar.
- The game's move list is only as tall as its moves.
- Results show each game's blunders, and their list fits the games played.
- The puzzles' title sits beside back, and the library stays centred on a tablet's wide screen.
- The win's card says who won, and a long game's move list no longer hides it.
- Desktop windows get a larger replay and results and a layout capped for ultrawide screens, and a new player starts on the 3D board.
- The 3D board takes less memory on phones, and turns under a drag in settings as on the home screen.
- A finished game is no longer offered to continue.
- A puzzle solved with the keys or a controller puts the focus on next.

**Windows** (64-bit, Windows 10 or 11): download `Draughts-0.8.0-windows-x64.zip`, extract it, and run `Draughts.exe`. Nothing to install. Your graphics driver must support Vulkan, which current NVIDIA, AMD, and Intel drivers do. The app is not signed yet, so on the first run Windows shows "Windows protected your PC": choose **More info**, then **Run anyway**.

**macOS** (Apple silicon, macOS 13.3 or later): download `Draughts-0.8.0-macos-arm64.zip`, open it, and move Draughts to Applications. It is signed and notarized.

**Linux** (64-bit, glibc 2.35 or later: Ubuntu 22.04, Debian 12, Fedora 36, SteamOS, and their successors): download `Draughts-0.8.0-linux-x64.tar.gz`, extract it, and run `Draughts/draughts`. To add it to your applications menu, run `Draughts/install.sh` (`install.sh --remove` takes it away). Your graphics driver must support Vulkan, which Mesa and NVIDIA's driver do.

**Android and iPhone/iPad:** from Google Play and the App Store.

SHA-256:
- `Draughts-0.8.0-windows-x64.zip`: `aff4f5a35234418ec00ce4f24bff9f9804ebbf6a625113a7f60d56916ec56aad`
- `Draughts-0.8.0-macos-arm64.zip`: `ed6a19aa9bfb49447540c2aef4ad7e1a778f3f70646bf633d4c48adbcff977c4`
- `Draughts-0.8.0-linux-x64.tar.gz`: `02c0663f553163aaa3315e2d51c3056ad465488cebebe667aaed576e99a4c150`
```

### Play, en-GB (399 of 500)

```text
• Daily puzzles at your level once Learn is solved: a warm-up, two at your level, and one a bit harder
• Over 7,000 puzzles for International, Russian, and Brazilian draughts
• A puzzle rating that grows with you
• A stronger computer
• The replay shows each move and the best one when asked
• Results show each game's blunders
• Tidier game screen on phones
• Open source: github.com/kaitk/draughts
```

### Play, et (392 of 500)

```text
• Iga päev ülesanded sinu tasemel, kui õppimine on läbi: soojendus, kaks sinu tasemel ja üks veidi raskem
• Üle 7000 ülesande rahvusvahelises, vene ja brasiilia kabes
• Ülesannete reiting, mis kasvab koos sinuga
• Tugevam arvuti
• Kordus näitab iga käiku ja soovi korral parimat
• Tulemustes iga mängu suured vead
• Telefonis selgem mänguvaade
• Avatud lähtekoodiga: github.com/kaitk/draughts
```

### App Store, en-GB (657 of 4,000)

```text
• Daily puzzles at your level once Learn is solved: a warm-up, two at your level, and one a bit harder, new each day
• Over 7,000 puzzles for International, Russian, and Brazilian draughts, among them traps that punish a careless move
• A puzzle rating per player and draughts that grows with you
• A stronger computer
• The replay shows each move on the board, and the best move when asked
• Results show each game's blunders
• On an iPhone held upright, what each side has taken sits on its own card beside the last move
• The win's card says who won
• The 3D board takes less memory

Draughts is open source (MIT or Apache 2.0): github.com/kaitk/draughts
```

## 0.5.1 (2026-11-14, pre-release, Windows and Linux)

### GitHub release

```markdown
A pre-release for Windows and Linux: the replay shows more, and a few fixes.

**Better**

- **The replay shows each move** on the board, shaded at every stop with its start faded, in dots and numbers.
- **The best move, when asked.** The bulb shows the move that was best from that position; tap the line saying what was best to see it there.
- **Marks closer to lidraughts'**, from its curve and cut-offs, with the judge's best move as the hint.
- **Desktop windows** get a larger replay and results, the replay's back in its own row over the board, and a layout capped for ultrawide screens.
- The win's card says who won.
- A long game's move list no longer hides the win's card.
- A desktop's player sheet stays in place while a name is typed, and Return does what done does.

**Windows** (64-bit, Windows 10 or 11): download `Draughts-0.5.1-windows-x64.zip`, extract it, and run `Draughts.exe`. Nothing to install. Your graphics driver must support Vulkan, which current NVIDIA, AMD, and Intel drivers do. The app is not signed yet, so on the first run Windows shows "Windows protected your PC": choose **More info**, then **Run anyway**.

**Linux** (64-bit, glibc 2.35 or later: Ubuntu 22.04, Debian 12, Fedora 36, SteamOS, and their successors): download `Draughts-0.5.1-linux-x64.tar.gz`, extract it, and run `Draughts/draughts`. To add it to your applications menu, run `Draughts/install.sh` (`install.sh --remove` takes it away). Your graphics driver must support Vulkan, which Mesa and NVIDIA's driver do.

**macOS, Android, iPhone/iPad:** 0.5.0 for now.

SHA-256:
- `Draughts-0.5.1-windows-x64.zip`: `07b18cb52fee172e6deb53098aedefc1ed37f2b9cd18735d46fbf572c10fe763`
- `Draughts-0.5.1-linux-x64.tar.gz`: `3a971b04bf8656f338b2a1259767b7a0964fb9a36ac4cb392ebcd6d3faa3cb39`
```

## 0.5.0 (2026-11-13)

### GitHub release

```markdown
A big step from 0.2.0: learn the game in the app, look back over your games, and a 3D board in wood, stone, or carved for every season.

Draughts is open source, under the MIT or Apache 2.0 licence: the code is here, at [github.com/kaitk/draughts](https://github.com/kaitk/draughts). No ads, no tracking, no accounts; it works offline.

**New**

- **How to play.** New players are asked whether they know the game; if not, short steps played on the board teach it, for the draughts you chose (International, Brazilian, or Russian), and lead on to the puzzles or a first game. It is on home and in the puzzles' library too.
- **Replay your games.** Open a past game from Results to step through it beside its move list, each move marked from best to mistake, with a legend for the marks. Tap a move to jump to it, or **Play from here** to try another line: such a game isn't saved and doesn't change your rating.
- **One New game.** Home has a single New game row; its setup chooses the opponent (the computer or a friend) and, for a friend, whether the board turns to whoever plays.
- **Wood, stone, or carved.** Every season's 3D board now comes in three materials, among them weathered stone and a folk-carved frame. Settings shows them as pictures.
- **Settings in one list,** with the board's material, the language, and the move list explained.

**Better**

- Softer, steadier shadows on the 3D board that no longer crawl as a piece moves.
- The 3D board runs smoother on slower phones.
- Phones show the moves as one line that opens into the whole list.
- Layouts fit 4:3 tablets and foldables, and the 3D camera's buttons sit under the board in portrait.
- Dates follow the language: 13 Nov 2026 in English, 13.11.2026 in Estonian.
- The name you type for a player stays above a phone's keyboard.
- The Mac app's icon shows properly on macOS 26.

**Windows** (64-bit, Windows 10 or 11): download `Draughts-0.5.0-windows-x64.zip`, extract it, and run `Draughts.exe`. Nothing to install. Your graphics driver must support Vulkan, which current NVIDIA, AMD, and Intel drivers do. The app is not signed yet, so on the first run Windows shows "Windows protected your PC": choose **More info**, then **Run anyway**.

**macOS** (Apple silicon, macOS 13.3 or later): download `Draughts-0.5.0-macos-arm64.zip`, open it, and move Draughts to Applications. It is signed and notarized.

**Linux** (64-bit, glibc 2.35 or later: Ubuntu 22.04, Debian 12, Fedora 36, SteamOS, and their successors): download `Draughts-0.5.0-linux-x64.tar.gz`, extract it, and run `Draughts/draughts`. To add it to your applications menu, run `Draughts/install.sh` (it copies the app to `~/.local/bin` and adds the menu entry and icon; `install.sh --remove` takes them away). Your graphics driver must support Vulkan, which Mesa and NVIDIA's driver do. It opens a Wayland window where there is one, and an X11 window otherwise.

**Android and iPhone/iPad:** from Google Play and the App Store.

SHA-256:
- `Draughts-0.5.0-windows-x64.zip`: `28727f176106a5e7a3ba3c5fe497d13c6de616ac30baa6c01c7c10a6987053ad`
- `Draughts-0.5.0-macos-arm64.zip`: `7d6c08fa249a773a2eafa429fdfb348307fb67c8f6f0796e342c750314c91d1f`
- `Draughts-0.5.0-linux-x64.tar.gz`: `2c7db053ad3c526d4ba7a06dcacf10df648718970507fe080cd99b037a7a05c4`
```

### Play, en-GB (469 of 500)

```text
• How to play: short steps on the board teach new players each draughts
• Replay past games from Results, every move marked, and play on from any move
• One New game: choose the computer or a friend, and whether the board turns
• Wood, stone, or carved 3D boards for every season
• Softer 3D shadows, smoother on slower phones
• Moves on phones as one line that opens the whole list
• Better layouts on 4:3 tablets and foldables
• Open source: github.com/kaitk/draughts
```

### Play, et (475 of 500)

```text
• Kuidas mängida: lühikesed sammud laual õpetavad algajale iga kabet
• Vaata tulemustest vanu mänge, iga käik hinnatud, ja mängi siit edasi
• Üks uus mäng: vali arvuti või sõber ja kas laud pöörab
• Ruumiline laud igal aastaajal puidust, kivist või nikerdatud
• Pehmemad varjud ruumilisel laual, sujuvam aeglasemal telefonil
• Telefonis käigud ühel real, mis avab kogu loendi
• Paremad paigutused 4:3 tahvlitel ja volditavatel
• Avatud lähtekoodiga: github.com/kaitk/draughts
```

### App Store, en-GB (689 of 4,000)

```text
• How to play: short steps on the board teach new players each draughts, and lead on to the puzzles or a first game
• Replay past games from Results, every move marked from best to mistake, and play on from any move
• One New game: choose the computer or a friend, and whether the board turns
• Wood, stone, or carved 3D boards for every season
• Settings in one list, with the board's material and the language
• Softer, steadier 3D shadows
• Moves on phones as one line that opens the whole list
• Better layouts on iPad and in landscape
• Dates in your language's style
• The name you type stays above the keyboard

Draughts is open source (MIT or Apache 2.0): github.com/kaitk/draughts
```
