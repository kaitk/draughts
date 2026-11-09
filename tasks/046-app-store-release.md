# 046: Release on the App Store

Status: todo (the listing and answers prepared, 2026-11-09; nothing submitted, no account)

Everything between task 043's development build and Draughts on the App Store for iPhone
and iPad, in the Kids category: no ads, no tracking, no accounts, no network, as on Play
(task 029). The listing and App Store Connect's answers are in `store/app-store.md`, the
page's preview in `store/preview/app-store.html`. Apple's rules change; check each against
Apple's pages when doing this, as `store/app-store.md` was on 2026-11-09.

## Prepared (2026-11-09)

- **The listing:** name "Draughts for Kids", subtitle "Play, learn, and solve puzzles"
  (30 of 30), promotional text (159 of 170), keywords (97 of 100 bytes), and the
  description (2,593 of 4,000): Play's text with the devices named as iPhone and iPad, as
  Apple bars other platforms' names.
- **No Estonian listing:** Estonian is not an App Store localization, and Estonia's
  storefront shows English (U.K.). The Estonian text is in `store/app-store.md` for when
  it is.
- **The answers:** App Privacy "Data Not Collected"; the age questionnaire all None, 4+;
  Kids, age band 6–8 proposed; export compliance already answered by the Info.plist's
  `ITSAppUsesNonExemptEncryption` false; review notes.
- **The privacy policy** covers iPhone and iPad and their backup (`store/privacy/`).
- **Screenshots** from headless simulators (iOS 26.4, no Simulator.app window), seven
  scenes in English and Estonian, in `~/Downloads/draughts-store/screenshots/app-store-0.2/`:
  `iphone-6.9/` (1320 × 2868, an iPhone 16 Pro Max; the Dynamic Island the simulator draws
  painted out) and `ipad-13/` (2064 × 2752, an iPad Pro 13-inch); portrait only, as
  `simctl` can't turn the simulator.

## What the app needs before submitting

Each is a store rule the app doesn't meet yet:

- [ ] **The privacy policy inside the app** (Guideline 5.1.1(i)): a link or the text,
      easy to reach. In Kids a link out needs a parental gate, so the simplest is a short
      text in settings ("Draughts collects nothing; everything stays on this device"),
      its strings in `strings/<lang>.txt`.
- [ ] **A privacy manifest:** `scripts/ios.py` writes `PrivacyInfo.xcprivacy` into the
      bundle, declaring `NSPrivacyAccessedAPICategoryFileTimestamp` (`C617.1`) for
      `stat`/`fstat` and `NSPrivacyAccessedAPICategorySystemBootTime` (`35F9.1`) for
      `mach_absolute_time`, which SDL and Goose's runtime import (`nm -u`, 2026-11-09);
      tracking false, no domains, no collected data. Apple refuses an upload without it.
- [ ] **The icon:** an asset catalog with the 1024 px icon (`scripts/icon.py --store`
      makes `apple-1024.png`), compiled with `actool` into `Assets.car` and
      `CFBundleIcons` (task 043); a dark and a tinted variant optional.
- [ ] **The launch screen's colour:** `UILaunchScreen` with the icon's background
      (task 043).
- [ ] **iPad windows:** `UIRequiresFullScreen` is deprecated in iPadOS 26 and will be
      ignored, so the layout must follow a resized window on iPad (secondhand; read
      TN3192 first). Or offer iPhone only, which drops the iPad screenshots too.
- [ ] **A distribution build:** an `.ipa` signed with an App Store distribution
      certificate and profile, uploaded with Transporter or `xcrun altool --upload-app`;
      built with Xcode 26 and the iOS 26 SDK (required since 2026-04-28).
- [ ] **No links out stays true:** no `SDL_OpenURL`, no rating prompt, no share sheet; a
      future one needs a parental gate.

## What remains for the user

- **The Apple Developer Program,** 99 USD a year, as an individual: the legal name is the
  seller shown on the App Store (`{DEVELOPER}` there is that name), and the EU trader
  status (non-trader proposed, as on Play).
- **Decide:** the Kids age band (5 and under, 6–8, or 9–11: one only, and Made for Kids
  can't be undone after approval), iPad or iPhone only, and the support URL
  (`{SUPPORT_URL}`).
- **App Store Connect:** the app record (bundle id `io.github.kaitk.draughts`), the
  listing and answers pasted from `store/app-store.md`, the screenshots, the review
  contact (a phone, not shown publicly).
- **TestFlight** on the iPhone 13 mini before review.

## Acceptance criteria

- [x] The listing, the answers, and the screenshots prepared, and a preview of the page
      (2026-11-09)
- [ ] The privacy text in the app, the privacy manifest, the icon, and the launch screen
- [ ] The iPad layout in a resized window, or the app offered for iPhone only
- [ ] A distribution build uploaded and tried through TestFlight on a device
- [ ] Submitted and approved, in the Kids category
