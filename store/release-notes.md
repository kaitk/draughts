# Release notes

Each version's notes for the GitHub release (the desktop builds) and the stores' "What's
new": Play's in en-GB and et (500 characters each), the App Store's in en-GB alone (no
App Store localization yet, `app-store.md`). Newest first.

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
- `Draughts-0.5.0-linux-x64.tar.gz`: `01222033915f49242af1b26f2adc6a046176fc75fd28c160bd537dea6d1355b8`
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
