# Play Console answers

The answers for Play Console's App content forms (Policy and programs → App content), and
the store settings. Drafted 2026-11-08 from the app as built, players added 2026-11-09, and
checked against Play Console Help on 2026-11-09 (each article linked where it is used); the
forms' questions change, so read each one as it stands and answer from the facts in "What
the answers rest on".

## What the answers rest on

- **No permissions.** `aapt2 dump permissions build/android/draughts/draughts-release.apk`
  lists none: no `INTERNET`, no `AD_ID`, no location, camera, microphone, or storage.
- **No network.** Without `INTERNET` the app cannot open a socket; nothing in it tries.
- **No third-party SDKs** that collect anything: the app is Goose, SDL3, goose_gfx, and
  Nuklear, all compiled in, none of which talks to a server.
- **On the device only:** `settings.txt`, and each player's `player-N.txt` and
  `game-N.bin`, in the app's internal storage. A player's file holds the optional name a
  child or parent types (up to 12 characters) and the badge; like the rest it never
  leaves the device, which is why Data safety counts it as not collected (Play counts
  data as collected only when it is sent off the device).
- **Android's backup:** `android:allowBackup="true"`, so Android's own Auto Backup may
  copy those files to the user's Google account if the user turned backup on. The
  answers below count that as not collected, since the developer never receives it.
  Play's Data safety help
  ([10787469](https://support.google.com/googleplay/android-developer/answer/10787469),
  read 2026-11-09) counts as collected only what leaves the device to the developer or a
  third party, and says nothing of Android's backup; it does say data a user uploads to
  their own Drive, which the developer never reaches, needs no declaring. Setting
  `allowBackup="false"` would remove the question at the cost of a child's progress
  surviving a new tablet (kept on: the user, 2026-11-09).

## Data safety

| Question | Answer |
| --- | --- |
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | Not asked once the answer above is No |
| Do you provide a way for users to request that their data is deleted? | Not asked; uninstalling or clearing the app's data deletes everything |
| Independent security review | No |
| Account creation | The app has no accounts |

What the listing then shows: "No data shared with third parties" and "No data
collected".

## Ads

| Question | Answer |
| --- | --- |
| Does your app contain ads? | **No** |
| Advertising ID: does your app use advertising ID? | **No** (no `AD_ID` permission; target SDK 36) |

## Content rating (IARC questionnaire)

Email for the certificate: `kaitkasak@proton.me`. Category: **Game** (not "Reference, news, or
educational": the app is played, and its puzzles are part of the game).

| Topic | Answer |
| --- | --- |
| Violence (cartoon, fantasy, realistic, blood, gore) | No |
| Fear, horror | No |
| Sexuality, nudity | No |
| Language (profanity, crude humour) | No |
| Controlled substances (drugs, alcohol, tobacco) | No |
| Gambling, simulated gambling, loot boxes | No |
| Users can interact or exchange content (chat, user-generated content) | No: pass-and-play is two people at one device |
| Shares the user's location with other users | No |
| Digital purchases, in-app purchases | No |
| Unrestricted internet access (a browser, search) | No |
| Is the app a web browser or search engine? | No |

Expected: the lowest rating everywhere (PEGI 3, ESRB Everyone, USK 0, IARC 3+).

## Target audience and content

| Question | Answer |
| --- | --- |
| Target age groups | **5 and under**, **6–8**. Not 9–12 or older: older children and adults may enjoy it, but adding them changes nothing here, and a game for 5 to 8 is what it is made for |
| Could your store listing unintentionally appeal to children? | Not asked: children are the target |
| Does the app appeal to children? | Yes |

Choosing an age group under 13 puts the app under the **Families Policy**. What it asks,
and where the app stands:

- **Privacy policy** at a public URL, linked in the listing and reachable from the app's
  store page: `store/privacy/index.html`, published at `https://kaitk.github.io/draughts/privacy/`.
- **Ads:** none, so the Families Self-Certified Ads SDK rule doesn't apply.
- **No collection of personal or device identifiers** from children, no `AD_ID`, no
  location: met, as above.
- **Content appropriate for children**, the listing included: met; the listing makes no
  claims of being "educational" or "approved" beyond what the app does.
- **Target API level** current: 36.
- **Sign-in:** none.
- **Augmented reality, camera, microphone:** none.
- **Teacher Approved:** still running; an app that meets the Families Policy can opt in to
  be rated by Play's teachers, with no promise of inclusion, and an approved app gets a
  badge and may show on the Kids tab
  ([9867159](https://support.google.com/googleplay/android-developer/answer/9867159), read
  2026-11-09). "Designed for Families" no longer exists as a program of its own; it is
  the Families Policy. Opt in once the app is published.
- **Several age groups** only if the app is made and fit for each; Google reviews the
  target audience, which can take 7 days or more
  ([9893335](https://support.google.com/googleplay/android-developer/answer/9893335), read
  2026-11-09).
- **Parental gate:** Play's Families pages ask for none (2026-11-09); the app has no links
  out and no purchases anyway.

## Other App content declarations

| Form | Answer |
| --- | --- |
| Privacy policy | `https://kaitk.github.io/draughts/privacy/` |
| App access | All functionality is available without special access (no login) |
| Government app | No |
| Financial features | None |
| Health apps | Not a health app |
| News app | No |
| Data deletion (accounts) | Not applicable: no accounts |
| Photo and video permissions, full-screen intent, foreground services, exact alarms | Not used |

Even with nothing collected, the Data safety form must be filled in and the privacy
policy linked ([10787469](https://support.google.com/googleplay/android-developer/answer/10787469)),
and the IARC questionnaire is mandatory: an unrated app isn't published
([9859655](https://support.google.com/googleplay/android-developer/answer/9859655), both
read 2026-11-09).

## Store settings

| Setting | Value |
| --- | --- |
| App or game | Game |
| Category | Board |
| Tags | Up to five of Play's list, in Store settings → App category → Manage tags ([9859673](https://support.google.com/googleplay/android-developer/answer/9859673), read 2026-11-09; the list shows only in the Console): pick Board, Casual, Offline, Single player, Family, if offered |
| Contact email | `kaitkasak@proton.me` (required, shown on the listing) |
| Website | `https://kaitk.github.io/draughts/` (optional; to confirm) |
| Phone | None |
| Price | Free (a free app can never become paid) |
| Countries | All, or Estonia and the EU first; the user decides |
| Developer name | `Gideonic` (the Play developer account's name) |
| Trader status (EU) | **Non-trader**, if the user agrees: free, no ads, no purchases, made as a hobby. A non-trader's listing shows only the email and the country, and EEA and UK users are told consumer law doesn't apply; a trader's shows a name, address, and phone, a personal trader's address included. New accounts declare it at creation ([17594752](https://support.google.com/googleplay/android-developer/answer/17594752), read 2026-11-09) |

## The account

What a personal developer account asks, from Play Console Help, read 2026-11-09:

- The legal name and address, a verified email and phone, and a developer website
  ([10840893](https://support.google.com/googleplay/android-developer/answer/10840893)). The
  developer email shows on the public profile; the phone shows only for organisations.
  No D-U-N-S number for a personal account.
- A closed test with at least 12 testers opted in for 14 days before production, for a
  personal account made after 2023-11-13
  ([14151465](https://support.google.com/googleplay/android-developer/answer/14151465)).
- Target API 36 for new apps and updates from 2026-08-31
  ([11926878](https://support.google.com/googleplay/android-developer/answer/11926878)); the
  app targets 36.
- The package name registered under Android developer verification; Play Console's home
  page says whether anything is left to do (secondhand, from Google's 2026 announcements;
  check in the Console).
