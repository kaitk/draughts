# 046: Release on the App Store

Status: in-progress (the listing and answers prepared, and the app meets the bundle's
rules, 2026-11-09; the account's enrolment pending on a new personal Apple ID,
2026-11-10; nothing submitted)

Everything between task 043's development build and Draughts on the App Store for iPhone
and iPad, in Games → Puzzle at 4+ (not the Kids category): no ads, no tracking, no
accounts, no network, as on Play (task 029). The listing and App Store Connect's answers are in `store/app-store.md`, the
page's preview in `store/preview/app-store.html`. Apple's rules change; check each against
Apple's pages when doing this, as `store/app-store.md` was on 2026-11-09.

## Prepared (2026-11-09)

- **The listing** (approved by the user 2026-11-09): name "Draughts" (a fallback in
  `store/app-store.md` if it's taken), subtitle "Play, learn, and solve puzzles"
  (30 of 30), promotional text (160 of 170), keywords (93 of 100 bytes), and the
  description (2,381 of 4,000): Play's text with the devices named as iPhone and iPad, as
  Apple bars other platforms' names.
- **No Estonian listing:** Estonian is not an App Store localization, and Estonia's
  storefront shows English (U.K.). The Estonian text is in `store/app-store.md` for when
  it is.
- **The answers:** App Privacy "Data Not Collected"; the age questionnaire all None, 4+,
  Made for Kids No; export compliance already answered by the Info.plist's
  `ITSAppUsesNonExemptEncryption` false; review notes.
- **The privacy policy** covers iPhone and iPad and their backup (`store/privacy/`).
- **Screenshots** from headless simulators (iOS 26.4, no Simulator.app window), seven
  scenes in English and Estonian, in `~/Downloads/draughts-store/screenshots/app-store-0.2/`:
  `iphone-6.9/` (1320 × 2868, an iPhone 16 Pro Max; the Dynamic Island the simulator draws
  painted out) and `ipad-13/` (2064 × 2752, an iPad Pro 13-inch); portrait only, as
  `simctl` can't turn the simulator.

## What the app needs before submitting

Each is a store rule the app doesn't meet yet:

- [x] **The privacy policy inside the app** (Guideline 5.1.1(i)), 2026-11-09: one
      sentence in settings' Game group, no link (`settings.privacy`): "Privacy: Draughts
      collects nothing. Everything stays on this device." / "Privaatsus: Kabe ei kogu
      midagi. Kõik jääb sellesse seadmesse." Beside the group's title where it fits in two
      lines at most (the stacked landscapes, one line on the Android tablet and the 13"
      iPad), else at the glass's foot (portrait, a phone's tabs), so no layout moved
      (`test/shell/sizes`, `screens3d`, `shell` unchanged; `transition` only counts the
      note's glyphs). Shot headless on the Mac at an iPhone 13 mini portrait, an iPhone 16
      Pro Max landscape, the 13" iPad in both, and the tablet's landscape, both languages.
- [x] **A privacy manifest**, 2026-11-09: `scripts/ios.py` writes `PrivacyInfo.xcprivacy`
      (`PRIVACY_APIS`): `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`) for
      `stat`/`fstat`, `NSPrivacyAccessedAPICategorySystemBootTime` (`35F9.1`) for
      `mach_absolute_time`; tracking false, no domains, no collected data. `nm -u` and the
      selectors' strings on the simulator and device builds found no other API in Apple's
      list (no `statfs`, `getattrlist`, `NSUserDefaults`, `systemUptime`,
      `activeInputModes`).
- [x] **No Bluetooth**, found 2026-11-09: SDL's HIDAPI linked CoreBluetooth
      (`CBCentralManager`), which App Store Connect rejects without
      `NSBluetoothAlwaysUsageDescription` (ITMS-90683, secondhand). The app opens no
      joystick; `ios/CMakeLists.txt` sets `SDL_HIDAPI OFF`, and the binary links no
      CoreBluetooth. CoreMotion and GameController stay (SDL's joystick and sensors,
      never started), which need no purpose string.
- [x] **The icon**, 2026-11-09: an asset catalog with autumn's 1024 px icon (no alpha),
      compiled by `actool` into `Assets.car` with `CFBundleIconName` and `CFBundleIcons`
      (`assetutil --info` lists `AppIcon` at 1024 and the colour). The PNG is
      `ios/icon-1024.png`, in git, written by `icon.py` with Android's foregrounds. A dark
      and a tinted variant are optional and left out.
- [x] **The launch screen's colour**, 2026-11-09: `UILaunchScreen`'s `UIColorName` is
      the catalog's `LaunchBackground`, #140c09, read from Android's `icon_background`.
- [x] **iPad windows** (iPhone and iPad kept, 2026-11-09): `UIRequiresFullScreen` is
      deprecated in iPadOS 26 and will be ignored, so `scripts/ios.py` drops it (done
      2026-11-09; with it the window kept a large minimum) and the app follows a resized
      window. Tried 2026-11-09 on an iPad Pro 11-inch (M5)
      simulator, iOS 26.4, in Windowed Apps, with a copy of the bundle without the key:
      resizing, the 3D board while resized, both orientations in a window and full screen,
      taps after a resize, and leaving and coming back all work. Small windows waste or
      lose room on three screens and the puzzles: task 050, done 2026-11-09 (archived),
      checked by the user in the simulator at the smallest window.
- [ ] **A distribution build:** an `.ipa` signed with an App Store distribution
      certificate and profile, uploaded with Transporter or `xcrun altool --upload-app`;
      built with Xcode 26 and the iOS 26 SDK (required since 2026-04-28).
- [x] **No links out stays true:** no `SDL_OpenURL`, no rating prompt, no share sheet
      (checked 2026-11-09: none of `OpenURL`, `openURL`, `SKStoreReview`, `requestReview`,
      `UIActivityViewController`, `ACTION_SEND`, `ACTION_VIEW` in `src/`, `ios/`, `android/`,
      `scripts/`; check again before the submission, task 040's build included).

## Decided (2026-11-09)

- **Not the Kids category:** Games → Puzzle, rated 4+, Made for Kids No, no age band. The
  listing speaks to all ages, as Guideline 5.1.4(b) requires outside Kids
  (`store/app-store.md`).
- **iPhone and iPad.**
- **The account** (corrected 2026-11-10): the Apple Developer Program as an individual
  on a separate personal Apple ID made for the store, enrolled on the web; the enrolment
  on it is pending (2026-11-10). A first enrolment, started on the Apple ID whose free
  Personal Team signed the development builds and left before paying, ended when Apple
  locked that Apple ID; its reinstatement was refused (2026-11-10). That team's profile
  for the app expires 2026-11-16, after which device builds need another team (a
  personal one: the store's paid team, or another Apple ID's Personal Team). That team
  also holds the app's bundle id, so the paid team may find `io.github.kaitk.draughts`
  taken; a new id is cheap before release. No Apple ID, team id, or device identifier
  goes into the repo.
- **Signing with the paid team:** once its team shows in Xcode (Settings → Accounts),
  `DRAUGHTS_IOS_TEAM` picks it for `scripts/ios.py`, whose development profiles then
  last a year, not 7 days. With several identities on the Mac the script stops rather
  than take one, so the app is never signed into a company's team.
- **EU trader status:** non-trader, for the account and the app.
- **The support URL** `https://kaitk.github.io/draughts/`, the privacy URL
  `https://kaitk.github.io/draughts/privacy/`.

## What remains for the user

- **Enrol** the new personal Apple ID as an individual (pending, 2026-11-10). If it's
  refused or stalls, tell Apple Developer Support about the locked Apple ID, which never
  paid, rather than make another.

Once the account is active:

- **App Store Connect:** register the bundle id `io.github.kaitk.draughts` (Certificates,
  Identifiers & Profiles), then the app record: name "Draughts" (or the fallback),
  English (U.K.), a SKU; App Information (category, URLs, content rights, the trader
  status); the listing and answers pasted from `store/app-store.md`; the screenshots; the
  review contact (a phone, not shown publicly).
- **Signing:** an Apple Distribution certificate (Xcode → Settings → Accounts → Manage
  Certificates) and an App Store provisioning profile for the bundle id, both on the Mac,
  never in git.
- **TestFlight** on the iPhone 13 mini (an internal tester, no beta review) before
  submitting.

## Acceptance criteria

- [x] The listing, the answers, and the screenshots prepared, and a preview of the page
      (2026-11-09)
- [x] The privacy text in the app, the privacy manifest, the icon, and the launch screen
      (2026-11-09; the bundle built for the simulator and the device and checked, not yet
      run with them)
- [x] The iPad layout in a resized window, or the app offered for iPhone only (task 050)
- [ ] A distribution build uploaded and tried through TestFlight on a device
- [ ] Submitted and approved, in Games → Puzzle at 4+
