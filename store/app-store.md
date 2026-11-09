# App Store Connect: listing and answers

What App Store Connect asks for Draughts on iPhone and iPad, and the answers, drafted
2026-11-09 for a submission not yet made (task 046). Apple's rules were read that day
from Apple's own pages, linked where each is used; check them again before submitting.
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
- **The name is "Draughts"**, as on Play, with no "for Kids" (2026-11-09). App Store names
  are unique: if "Draughts" is taken, App Store Connect refuses it at the app record, and a
  fallback such as "Draughts: Play and Learn" is needed.

## App information

| Field | Limit | Answer |
| --- | --- | --- |
| Name | 30 | `Draughts` (8), the launcher's name; unique on the store, so check it's free |
| Subtitle | 30 | `Play, learn, and solve puzzles` (30) |
| Primary category | | Games, subcategory Board |
| Secondary category | | Kids (age band below); or Education, if Kids is left out |
| Age rating | | 4+ (below) |
| Content rights | | No third-party content: the photographs and fonts are the app's own or under the OFL |
| Copyright | | `2026 Gideonic` (Apple adds the ©); for an individual account the seller shown is the legal name |
| Privacy Policy URL | required | `{PRIVACY_URL}` |
| Support URL | required | `{SUPPORT_URL}`: a page with a way to reach the developer; the privacy page's site, `https://kaitk.github.io/draughts/`, with the contact email, would do |
| Marketing URL | optional | None, or the same site |

Fields and limits: [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information)
and [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information),
read 2026-11-09: name 2 to 30 characters, subtitle 30, promotional text 170 (changed
without a new version), description 4000, keywords 100 bytes with each keyword over 2
characters, What's New 4000 (from the second version), review notes 4000 bytes.

### Promotional text (160 of 170)

```text
Play draughts on a 2D or 3D board against the computer or a friend on one device, and solve 120 puzzles. International, Brazilian, and Russian. No ads, offline.
```

### Keywords (93 of 100 bytes)

```text
checkers,board game,international,russian,brazilian,puzzles,kids,offline,family,strategy,kabe
```

Not repeated: the name's word (draughts), which Apple indexes anyway. "kids" stands for
the audience the name no longer names. No other app's name. "kabe" for people in Estonia
searching the English storefront.

### Description (2,381 of 4,000)

```text
A calm draughts game to play and learn: big pieces, a flat 2D or a 3D board, and nothing to distract from the game.

PLAY
• Play the computer at three levels: easy, medium, and hard. It adjusts a little after each game, so it stays a fair match.
• Or play a friend on the same iPhone or iPad, taking turns (on one device, not online).
• Three kinds of draughts: International on the 10 × 10 board, and Brazilian and Russian on 8 × 8.
• Move by tapping a piece and its square, or by dragging it. Undo a move, or start over.
• Play without a clock, or with 5 or 10 minutes each, plus 3 or 5 seconds a move.

PUZZLES
• 120 puzzles: 74 for International draughts in six themes (Learn, Captures, Crowning, Shots, King shots, and Safe move), and 46 for Russian draughts in four. Brazilian players get the International set.
• Each theme goes from easy to harder, and some puzzles are played with black.
• Learn comes first and shows the rules in action; the other themes open once half of it is solved.
• Up to three stars a puzzle, one fewer for each mistake; a solved puzzle can be played again for all three.

PLAYERS
• Up to four players on one device, each with an animal picture and a name if they want one.
• Each player keeps their own look, move hints, stars, computer level, and saved game.
• Switching player takes two taps from the home screen.

MOVE HINTS
• Hints that help without doing the thinking: by default the game says nothing until a move is wrong, then shows the square and why. Showing every possible move can be turned on for the very first games.
• Capturing is compulsory: the piece that must capture is marked, with a dot for each piece it will take.

THE BOARD
• A flat board, or a 3D one with light and shadow, which you can turn by hand on the home screen.
• Four seasons, each a photograph with its own board: autumn wood, winter stone, spring carved stone, and summer sunset.
• The season follows the date, or stays on the one you choose; or a plain background in the colours of the board.

FOR EVERYONE
• Large buttons and pictures, so even a child who can't read yet finds their way.
• Simple enough for a first game, while the hard level and the hardest puzzles test grown-ups too.
• In English and Estonian, following the device's language.
• No ads, no purchases, and no internet needed.

Draughts runs on iPhone and iPad, in portrait and landscape.
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
| Made for Kids | Yes (below) |

Expected: **4+**. Made for Kids is offered only at 4+ or 9+, and is locked once the app is
approved.

## Kids category

The app is for children of about 5 to 8, so it goes in Kids. What Apple asks
([Guidelines](https://developer.apple.com/app-store/review/guidelines/) 1.3 and 5.1.4,
[Kids apps](https://developer.apple.com/app-store/kids-apps/), read 2026-11-09), and where
the app stands:

| Rule | The app |
| --- | --- |
| One age band: 5 and under, 6–8, or 9–11 | **6–8** (proposed: the app's 5 to 8 straddles two bands, and 6–8 holds most of it; the user decides) |
| No links out, purchases, or other distractions unless behind a parental gate | None: the app opens no URL (no `SDL_OpenURL` or `http` in `src/` or `ios/`, 2026-11-09), has no purchases, no rating prompt, no share sheet. No gate is needed while that holds |
| No third-party analytics or advertising; no personal or device information sent to third parties | None: no SDK besides SDL and goose_gfx, compiled in, and no network |
| A privacy policy | `{PRIVACY_URL}` |
| Stays under these rules even if the category is later dropped | Accepted: the app means to keep them anyway |

A parental gate, if one is ever needed, is an adult task (Apple's examples: a sum, a
question) in front of the link or purchase, with a spoken prompt for a child who can't
read.

## Privacy policy inside the app

Guideline 5.1.1(i) asks for the policy's link in the metadata **and** inside the app,
easy to reach (read 2026-11-09). The app has none. In the Kids category a link out needs a
parental gate, so the simplest is the policy's text inside the app (settings, behind a
quiet "Privacy" row: "Draughts collects nothing; everything stays on this device"), or a
link behind a gate. To build before submitting (task 046).

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
empty. `scripts/ios.py` doesn't write it yet (task 046). Check `nm -u` again on the
release build.

## App Review information

| Field | Answer |
| --- | --- |
| Sign-in required | No |
| Contact | The user's name, `kaitkasak@gmail.com`, and a phone with its country code (required, not shown publicly) |
| Notes | Below |

```text
Draughts is a board game for children of about 5 to 8. It has no network code, no accounts, no ads, no purchases, no links out of the app, and no third-party SDKs; everything a player makes (an optional name, settings, stars, a saved game) stays in the app's container. The 3D board is chosen in Settings → Board. Puzzles open from the home screen; solving half of Learn opens the other themes.
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
- **iPad:** the Info.plist offers iPhone and iPad (`UIDeviceFamily` 1, 2), so iPad
  screenshots are required. `UIRequiresFullScreen`, which it sets, is deprecated in
  iPadOS 26 and will be ignored, so the app must also draw right in a resized window
  (secondhand, from WWDC25; check TN3192 before submitting).

## Screenshots

From [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications),
read 2026-11-09: 1 to 10 per size, PNG or JPEG, no alpha. A set at the largest iPhone
size is scaled down for the smaller ones, as is the 13" iPad's.

| Set | Size, portrait | Required | Taken |
| --- | --- | --- | --- |
| iPhone 6.9" (Dynamic Island, large) | 1320 × 2868 (also 1290 × 2796, 1260 × 2736) | Yes, one iPhone set | iPhone 16 Pro Max simulator, 1320 × 2868 |
| iPad 13" | 2064 × 2752 (or 2048 × 2732) | Yes, since the app runs on iPad | iPad Pro 13-inch (M4) simulator, 2064 × 2752 |

Taken 2026-11-09 from headless simulators (`simctl`, no Simulator.app window), iOS 26.4,
the status bar hidden by the app, into
`~/Downloads/draughts-store/screenshots/app-store-0.2/iphone-6.9/` and `ipad-13/`, outside
git; each in English and Estonian, though the listing takes only the English:

1. `01-home-3d-winter`: home on the 3D board, winter, with the player's chip (Mia the fox)
2. `02-game-autumn`: International on the flat board, a capture of two shown, move hints on
3. `03-game-3d-summer`: the same position on the 3D board, summer
4. `04-puzzles-spring`: the library of six themes, some solved
5. `05-puzzle-winter`: a Shots puzzle, black to move, mid-solve
6. `06-settings-autumn`: settings (on the iPhone the Game tab, as no flag opens Look)
7. `07-computer-summer`: the computer's setup

Search results usually show an app's first three portrait screenshots, so those carry the board.
Landscape needs the simulator turned, which `simctl` can't do headless; portrait only.

## Estonian text (not entered: no App Store localization)

| Field | Text |
| --- | --- |
| Name | `Kabe` |
| Subtitle | `Mängi ja lahenda ülesandeid` (27) |
| Promotional text | `Mängi kabet 2D- või 3D-laual arvuti või sõbraga ühes seadmes ja lahenda 120 ülesannet. Rahvusvaheline, Brasiilia ja vene kabe. Reklaamideta, töötab internetita.` (160) |
| Description | `listing-et.md`'s, with "tahvelarvutis või telefonis" as "iPhone'is või iPadis", the section "Mitte midagi liigset" replaced by a last bullet under "Kõigile", "Reklaamide ja ostudeta, töötab internetita.", and the last line "Kabe töötab iPhone'is ja iPadis, nii püst- kui ka rõhtpaigutuses." |
