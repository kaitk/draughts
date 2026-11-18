# App Store Connect: listing and answers

What App Store Connect asks for Draughts on iPhone and iPad, and the answers, drafted
2026-11-09 and first submitted with 0.2.0 on 2026-11-12. Apple's rules were read on
2026-11-09 from Apple's own pages, linked where each is used; check them again before submitting.
The counts are Python's `len`, and bytes for the keywords, as Apple counts them;
`store/preview/build.py` checks them.

## Where the listing differs from Play's

- **No Estonian listing.** Estonian is not an App Store localization; Estonia's storefront
  shows English (U.K.)
  ([App Store localizations](https://developer.apple.com/help/app-store-connect/reference/app-information/app-store-localizations),
  read 2026-11-09). The listing is English (U.K.) only; the app itself still follows the
  device's language. The Estonian text below is kept for when Apple adds the language,
  and for the user's own pages.
- **No other platform named** (Review Guideline 2.3.10), so the text says iPhone and iPad,
  never Android, and the screenshots come from the simulator.
- **Not in the Kids category** (2026-11-09): Games → Puzzle at 4+, Made for Kids No.
  Made for Kids can't be undone and binds every later version to its rules (Guideline
  1.3). Outside Kids, the name, subtitle, icon, screenshots, and description may not imply
  that children are the main audience (5.1.4(b)), and "For Kids" in metadata is reserved
  for Kids (2.3.8), so the text speaks to all ages.
- **The name is "Draughts"**, as on Play (2026-11-09). App Store names
  are unique: if "Draughts" is taken, App Store Connect refuses it at the app record, and a
  fallback such as "Draughts: Play and Learn" is needed.

## App information

| Field | Limit | Answer |
| --- | --- | --- |
| Name | 30 | `Draughts` (8), the launcher's name; unique on the store, so check it's free |
| Subtitle | 30 | `Play, learn, and solve puzzles` (30) |
| Primary category | | Games, subcategory Puzzle (Board as the second subcategory, if offered) |
| Secondary category | | None |
| Age rating | | 4+ (below) |
| Content rights | | No third-party content: the pictures (made with AI, ChatGPT) are the app's own, and the fonts are under the OFL |
| Copyright | | `2026 Gideonic` (Apple adds the ©); for an individual account the seller shown is the legal name |
| Privacy Policy URL | required | `https://kaitk.github.io/draughts/privacy/` |
| Support URL | required | `https://kaitk.github.io/draughts/` (a support page with the contact email, live 2026-11-09) |
| Marketing URL | optional | None, or the same site |

Fields and limits: [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
and [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information),
read 2026-11-09: name 2 to 30 characters, subtitle 30, promotional text 170 (changed
without a new version), description 4000, keywords 100 bytes with each keyword over 2
characters, What's New 4000 (from the second version), review notes 4000 bytes.

### Promotional text (158 of 170)

```text
Play draughts on a 2D or 3D board against the computer or a friend, and solve puzzles: a course of 216, then new ones each day at your level. No ads, offline.
```

### Keywords (88 of 100 bytes)

```text
checkers,board game,international,russian,brazilian,puzzles,offline,family,strategy,kabe
```

Not repeated: the name's word (draughts), which Apple indexes anyway. No "kids", which
outside the Kids category would imply the audience (5.1.4(b)). No other app's name.
"kabe" for people in Estonia searching the English storefront.

### Description (3,659 of 4,000)

```text
A calm draughts game to play and learn: big pieces, a flat 2D or a 3D board, and nothing to distract from the game.

LEARN
• New to draughts? How to play teaches it in short steps played on the board, for each kind of draughts, then leads on to the puzzles or a first game.

PLAY
• Play the computer at three levels: easy, medium, and hard. It adjusts a little after each game, so it stays a fair match.
• Or play a friend on the same iPhone or iPad, taking turns (on one device, not online), the board turning to whoever plays or staying put.
• Three kinds of draughts: International on the 10 × 10 board, and Brazilian and Russian on 8 × 8.
• Move by tapping a piece and its square, or by dragging it. Undo a move, or start over.
• Play without a clock, or with 5 or 10 minutes each, plus 3 or 5 seconds a move.

YOUR GAMES
• Results keeps your past games and a rating against the computer.
• Replay any of them move by move, each move marked from best to mistake, and play on from any move to try another line.
• Once a game has ended, Replay on the home screen opens it where it turned: at your worst move, or where a lost game slipped away, with the best move shown.

PUZZLES
• Daily puzzles: once Learn is solved, a few puzzles a day at your level (4 by default; 3, 6, or 8 in settings): a warm-up, puzzles at your level, and one a bit harder. They come from nearly 8,000 for International, Russian, and Brazilian draughts, among them traps that punish a careless move, and none repeats.
• A puzzle rating for each player and kind of draughts, which moves fast at first and settles with time.
• The course: 216 puzzles in six themes (Learn, Captures, Crowning, Shots, King shots, and Safe move) for each kind of draughts: 84 for International, among them the Haarlem shot and a coup Philippe, and 66 each for Russian and Brazilian.
• Each theme goes from easy to harder, and some puzzles are played with black.
• Learn comes first and shows the rules in action; the other themes open once half of it is solved, and the daily puzzles once all of it is.
• Up to three stars a puzzle, one fewer for each mistake; a solved puzzle can be played again for all three.

PLAYERS
• Up to four players on one device, each with an animal picture and a name if they want one.
• Each player keeps their own look, move hints, stars, computer level, and saved game.
• Switching player takes two taps from the home screen.

MOVE HINTS
• Hints that help without doing the thinking: by default the game says nothing until a move is wrong, then shows the square and why. Showing every possible move can be turned on for the very first games.
• Capturing is compulsory: the piece that must capture is marked, with a dot for each piece it will take.

THE BOARD
• A flat board, or a 3D one with light and soft shadows, which you can turn by hand.
• Four seasons, each a picture with its own board in wood, stone, or carved.
• The season follows the date, or stays on the one you choose; or a plain background in the colours of the board.

SOUND
• A few calm sounds: a wooden knock for a move, a kannel's notes for a crowning and a win, and low mallet notes for a solved puzzle. Off until you turn them on in Settings.

FOR EVERYONE
• Large buttons and pictures, so even players who can't read yet find their way.
• Simple enough for a first game, while the hard level and the hardest puzzles test grown-ups too.
• In English and Estonian, following the device's language.
• No ads, no purchases, and no internet needed.

Draughts runs on iPhone and iPad, in portrait and landscape.

Draughts is open source, under the MIT or Apache 2.0 licence: github.com/kaitk/draughts
```

Play's text (`listing-en.md`) with the devices named, and what the app leaves out cut
to one line under "For everyone": the store's privacy label ("Data Not Collected") says
the rest.

## App Privacy

| Question | Answer |
| --- | --- |
| Do you or your third-party partners collect data from this app? | **No**: "Data Not Collected" |

Apple counts as collected only data sent off the device where the developer or a partner
can reach it beyond the request at hand; data processed only on the device isn't
([App privacy details](https://developer.apple.com/app-store/app-privacy-details/), read
2026-11-09). The app has no network code. iOS backs up `Library/Application Support/` to
the user's own iCloud or computer, which the developer never reaches; Apple's page doesn't
name backup, and the policy says it as Android's does (`privacy/index.html`).

## Age rating

The questionnaire of 2025 (ratings 4+, 9+, 13+, 16+, 18+;
[values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions),
read 2026-11-09). Answer each as it stands; the facts:

| Group | Answer |
| --- | --- |
| In-app controls: parental controls, age assurance | None |
| Capabilities: unrestricted web access, user-generated content, social media, messaging and chat, advertising | None of them |
| Mature or suggestive themes, horror or fear, profanity, crude humour | None |
| Medical or treatment information, health or wellness topics | None |
| Alcohol, tobacco, or drugs | None |
| Sexual content, nudity | None |
| Cartoon, fantasy, or realistic violence; guns or weapons | None |
| Simulated gambling, contests, gambling, loot boxes | None / No |
| Made for Kids | No |

Expected: **4+**.

**No links out** stays a rule though the app isn't in Kids: it opens no URL (no
`SDL_OpenURL` or `http` in `src/` or `platform/ios/`, 2026-11-09), and has no purchases, rating
prompt, or share sheet.

## Privacy policy inside the app

Guideline 5.1.1(i) asks for the policy's link in the metadata **and** inside the app,
easy to reach (read 2026-11-09). The app has no links out, so it shows the policy in one
sentence instead: in settings' Game group
(beside its title, or at its foot on a phone and in portrait), "Privacy: Draughts collects
nothing. Everything stays on this device." (`settings.privacy` in `strings/<lang>.txt`).

## Export compliance

`ITSAppUsesNonExemptEncryption` is `false` in the Info.plist `scripts/ios.py` writes: the
app uses no encryption at all, so App Store Connect asks no export questions per build
([Complying with encryption export regulations](https://developer.apple.com/documentation/Security/complying-with-encryption-export-regulations),
read 2026-11-09).

## Privacy manifest

Apple refuses an upload that uses a "required reason" API without a privacy manifest
giving the reason (since 2024-05-01,
[news](https://developer.apple.com/news/?id=3d8a9yyh)). The device binary imports, from
SDL and Goose's runtime: `stat` and `fstat` (file timestamp APIs) and
`mach_absolute_time` (system boot time APIs), and nothing from the disk space, active
keyboard, or user defaults groups (`nm -u` on the simulator build, 2026-11-09). So the
bundle needs a `PrivacyInfo.xcprivacy` with
([reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons),
read 2026-11-09):

| `NSPrivacyAccessedAPIType` | Reason | Why |
| --- | --- | --- |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | Metadata of files inside the app's container (the players' files) |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` | Time elapsed between events in the app: frames, animations, clocks |

and `NSPrivacyTracking` false, `NSPrivacyTrackingDomains` and `NSPrivacyCollectedDataTypes`
empty. `scripts/ios.py` writes it into the bundle (`PRIVACY_APIS`); `nm -u` on the
simulator and device builds of 2026-11-09 found the same three APIs. Check again on the
release build (`docs/development.md`, "Run on iOS").

## App Review information

| Field | Answer |
| --- | --- |
| Sign-in required | No |
| Contact | The user's name, `kaitkasak@proton.me`, and a phone with its country code (required, not shown publicly) |
| Notes | Below |

```text
Draughts is a board game for all ages, simple enough for young children. It is open source (MIT or Apache 2.0), written by one developer in Goose, a small systems language, with the code at https://github.com/kaitk/draughts.

It has no network code, no accounts, no ads, no purchases, no links out of the app, and no third-party SDKs; everything a player makes (an optional name, settings, stars, saved and past games) stays in the app's container. Nothing is switched on remotely and nothing is hidden: every part is reached from the home screen, as below.

- First start: the app asks "Do you know how to play?"; "Show me" starts a short lesson played on the board. It is also under Puzzles, "How to play".
- New game: the computer at three levels, or a friend on the same device; the kind of draughts, your pieces, and a clock.
- Continue: the game in progress. Once a game has ended, "Replay" takes its place.
- Results: past games and a rating against the computer; each game replays move by move.
- Puzzles: "Learn" is open from the start, 12 short puzzles of one or two moves for each kind of draughts. The other themes open once half of Learn is solved, and "Today's puzzles" (the daily puzzles) once all 12 are solved in any one kind of draughts.
- Settings (the gear on the home screen): the 3D board (Board), the picture (Theme), Sound, move hints, and the language.

Two things change by design. The background's season follows the date unless a season is chosen in Settings, Theme, so the picture depends on the day. Sound is off until turned up in Settings, Sound.
```

## Builds and the account

- **Xcode 26 and the iOS 26 SDK** for every upload since 2026-04-28
  ([upcoming requirements](https://developer.apple.com/news/upcoming-requirements/), read
  2026-11-09). `scripts/ios.py` builds with Xcode's SDK (26.4 here), so it meets it; the
  SDK it names in the Info.plist must be the real one.
- **Uploading without Xcode:** Transporter, or `xcrun altool --upload-app -t ios`, with an
  `.ipa` (the bundle in `Payload/`, zipped) signed with an App Store distribution
  certificate and profile.
- **The Apple Developer Program:** 99 USD a year; an individual's legal name is shown as
  the seller ([what's included](https://developer.apple.com/programs/whats-included/),
  read 2026-11-09).
- **EU trader status:** declared for the account and per app even outside the EU; a hobby
  app with no income is "unlikely" a trader, and a non-trader shows no contact details
  ([DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements),
  read 2026-11-09).
- **iPhone and iPad** (2026-11-09): the Info.plist offers both (`UIDeviceFamily` 1, 2),
  so iPad screenshots are required. `UIRequiresFullScreen` is deprecated in iPadOS 26
  and will be ignored, so the app follows a resized window instead.
- **The account:** a separate personal Apple ID made for the store, enrolled as an
  individual. No Apple ID, team id, or device identifier is written here (the repo is
  public).
- **The account's enrolment** (read 2026-11-09): an Apple Account with two-factor
  authentication and the legal name as first and last name; enrolled on the web, as the
  Apple Developer app bills the phone's own Apple Account. A free app needs no Paid Apps
  Agreement, so no tax or banking forms. The trader status is set in App Store Connect →
  Business → Agreements → Compliance → Digital Services Act, and per app under App
  Information → App Store Regulations and Permits.
- **Signing stays out of git:** the team, the distribution certificate (in the Mac's
  Keychain), and the App Store profile are read on the Mac at build time, as for
  development builds; an upload's app-specific password or API key stays in the
  Keychain.

## Screenshots

From [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications),
read 2026-11-09: 1 to 10 per size, PNG or JPEG, no alpha. A set at the largest iPhone
size is scaled down for the smaller ones, as is the 13" iPad's.

| Set | Size, portrait | Required | Taken |
| --- | --- | --- | --- |
| iPhone 6.9" (Dynamic Island, large) | 1320 × 2868 (also 1290 × 2796, 1260 × 2736) | Yes, one iPhone set | iPhone 16 Pro Max simulator, 1320 × 2868 |
| iPad 13" | 2064 × 2752 (or 2048 × 2732) | Yes, since the app runs on iPad | iPad Pro 13-inch (M4) simulator, 2064 × 2752 |

Taken from headless simulators (`simctl`, no Simulator.app window), the status bar hidden
by the app; the sets, their scenes, and how they were made are in `README.md`,
"Screenshots and the feature graphic". Landscape needs the simulator turned, which
`simctl` can't do headless, so simulator shots are portrait only.

Search results usually show an app's first three portrait screenshots, so those carry the board.
**The iPhone slot changed** (seen 2026-11-12): App Store Connect's version page now asks
for "iPhone with Dynamic Island (medium display)", 6.1" and 6.3", at 1206 × 2622 or
1179 × 2556 (landscape the same turned), and refuses 1320 × 2868 there; it showed no
6.9" slot. The 6.9" shots scaled to 1206 × 2622 (1207 wide, a pixel cropped) went in from
`upload/app-store-0.3/iphone-6.3/`.

## Estonian text (not entered: no App Store localization)

| Field | Text |
| --- | --- |
| Name | `Kabe` |
| Subtitle | `Mängi ja lahenda ülesandeid` (27) |
| Promotional text | `Mängi kabet 2D- või 3D-laual arvuti või sõbraga ühes seadmes ja lahenda 166 ülesannet. Rahvusvaheline, Brasiilia ja vene kabe. Reklaamideta, töötab internetita.` (160) |
| Description | `listing-et.md`'s, with "tahvelarvutis või telefonis" as "iPhone'is või iPadis", the section "Mitte midagi liigset" replaced by a last bullet under "Kõigile", "Reklaamide ja ostudeta, töötab internetita.", and the last line "Kabe töötab iPhone'is ja iPadis, nii püst- kui ka rõhtpaigutuses." |
