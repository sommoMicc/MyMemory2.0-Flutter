# SommoMemory release readiness

Verified 2026-11-05. This file records internal test distribution and remaining
production release readiness. No production release has been made.

The current signed release is **3.0.0 (30007)**. Final native artifacts are
`artifacts/MyMemory-Together-3.0.0-30007.{aab,apk,ipa}`; hashes, certificate and
source verification are recorded in `artifacts/native-builds-30007.json`.
The IPA SHA-256 is
`36621dcdd1e18054554f102de201d031bc8ca9cf197ac7490ad8adc47c990846`.

Apple upload **e456678f-f659-402c-a6ba-251cd03aa967** completed and the build is
**VALID / IN_BETA_TESTING**, attached to **SommoMemory Internal** with exactly one
account-holder tester. That tester's prior invitation is accepted (tester state
INSTALLED); this confirms app access, not installation of every new build.
`artifacts/testflight-upload.json` is the current API receipt.

The new Android app **cc.sommomi.mymemory** is live on its internal track with
versionCode **30007**, tester list restricted to the owner. The opt-in link is
https://play.google.com/apps/internaltest/4700857721365894827 . No production
release was made. See `ANDROID.md` for Console evidence and old-app deletion.

The UI was implemented with the explicitly requested Astra subagent. Full-viewport animated collection worlds extend behind safe areas, with original code-drawn scenery and bundled Noto characters. Motion stops in background and with reduced motion; reference research is documented in `DESIGN_REFERENCES.md` and `MEMORY_UI_REFERENCES.md`.
**37 Flutter tests** and analysis pass, including four viewports with realistic
iOS safe areas, all 36 cards visible and hit-testable, completion/rematch,
keyboard entry, settings, waiting rooms and Bluetooth lobby. The illustrated revision adds 320 ms 3D flips, reduced-motion behavior, persistent collection/difficulty, exact equal-length rows at all difficulties, and all 54 offline PNGs with bundled licenses. See `DECKS.md` for primary sources and pinned provenance. The game screens
do not scroll; Flutter's standard legal-license viewer retains its text scrolling.
**11 Node tests** pass, including the observed stale-browser-cache regression.
Native AAB/APK/IPA signatures and release identities were verified. The presentation layer captures immutable authority snapshots: card faces animate first, then scores, matched styling and results appear. Turn changes wait for both mismatch closing flips. Input remains locked during any flip and still checks the latest authority before sending a move. Early remote card changes queue in order; duplicate heartbeats are ignored. Reduced motion settles immediately. Regression tests cover the final pair, early reveal/hide, rotation during reveal and stale callbacks after a new round. Independent review reproduced and verified the rotation fix. Core engine timing and protocol remain unchanged.

## iOS

Bundle identifier: `cc.sommomi.mymemory`. Apple team: `L6CS7PYA4B`.
The bundle was registered through the configured App Store Connect API key
(resource `M5DK5NJ6KP`). An App Store distribution profile was generated and
installed locally through the API: `MyMemory App Store`, UUID
`10fd734b-e131-42ba-a75c-e62ff73105f2`, resource `AC9UG6997P`.
Its certificate `86762T444Q` matches a private-key-bearing identity already in the
local keychain and expires 2027-10-09. No new signing private key was created.

Runner Release/Profile use manual distribution signing. Debug keeps development
signing for simulator/device development. `app/ios/ExportOptions.plist` exports
for App Store Connect; the deployment target is iOS 15.

Use the configured API helper from the project root:

```sh
node scripts/asc.mjs status
```

The helper reads the existing local credentials configuration, signs five-minute
ES256 JWTs in process, follows no redirects, and sends bearer tokens only to the
official App Store Connect API. Credentials and tokens never enter project files.
Do not copy the private key into this repository.

To create a signed archive and IPA with the project's Flutter SDK:

```sh
cd app
flutter build ipa --release --export-options-plist=ios/ExportOptions.plist
```

App Store Connect record **6831015201** was created through the website as
**MyMemory Together** (the name MyMemory was already occupied), with Italian
primary locale, SKU `mymemory-ios`, iOS and unrestricted existing-team access.
On 5 November 2026, the existing record’s Italian public name was changed through
the API to **SommoMemory** and the Italian beta description was updated. The app
ID, SKU `mymemory-ios` and bundle identifier `cc.sommomi.mymemory` are unchanged.
The existing internal group was renamed **SommoMemory Internal**; its ID, sole
account-holder tester and build relationships were verified unchanged. No new
app record or tester was created. The signed 30007 artifact above retains its
original native display name; a later build will carry the updated app name.
Beta and App Store metadata now point to `https://sommomemory.sommomi.cc`,
with `/privacy` and `/support` for their respective URLs. The updates were
verified through the API after public DNS and strict TLS validation of the new
site. No production submission was made.
Apple's
[Apps API documentation](https://developer.apple.com/documentation/appstoreconnectapi/apps)
states that creating a new app record requires the App Store Connect website.
The [Build Upload API introduced in 4.1](https://developer.apple.com/documentation/appstoreconnectapi/build-uploads)
does support direct binary uploads; that newer resource supersedes the older
Apps overview's Transporter-only upload statement. Use:

```sh
node scripts/testflight-upload.mjs app/build/ios/ipa/SommoMemory.ipa
```

The uploader supports `--commit-only` to validate the existing receipt/native SHA-256 and resume only its checksum confirmation after completed binary transmission. It creates no new upload reservation and sends no binary parts in this mode; new uploads persist successful-part markers before confirming the checksum. Build 30006 used this recovery after an API connect timeout, and then completed VALID/internal testing.

The uploader verifies the IPA bundle identifier, reads the actual version/build,
creates the build-upload reservation and sends the binary in Apple's prescribed
chunks. It commits the MD5 delivery checksum Apple accepts and records a SHA-256
artifact fingerprint plus only nonsecret receipt/status
identifiers under `artifacts/testflight-upload.json`. The ASC bearer token is
sent only to the official API; the binary upload request uses separate headers
returned by Apple's reservation. The user authorized TestFlight upload during
this work; no production App Review submission is authorized.

Italian beta description and marketing/privacy URLs have been saved through the
API, along with the App Store privacy/support URLs. An updated Paid Applications
Schedule banner is present in the account; no binding agreements were accepted.

Before external testing: complete privacy declarations, age rating, support and
privacy URLs, store screenshots, review contact details, and required agreements.
The app has ordinary HTTPS and BLE networking; it declares no nonexempt encryption.

## Android

The user's requested replacement is a **new** app, **cc.sommomi.mymemory**,
Console app ID **4972469070574777722**. Release **3.0.0 (30007)** is available to
internal testers; Google Play App Signing is active. A new dedicated upload key
is stored outside source control. There is no dependency on recovering the old
app's signing key for this new package.

The old **com.michele.mymemory** listing (historical versionCode2/version0.9, no
Play App Signing) was deleted on **2026-11-05**, following the user's explicit
confirmation to delete it and use the registration-receipt identifier in Google's
official form. Console confirms it can be recovered until **2026-11-12** and
offers **Recupera app**. The private identifier is not stored in this repository.
The new app's internal track was refreshed after deletion and remains **Attivo**.
Full evidence: `ANDROID.md`.

## Offline Bluetooth

BLE uses `bluetooth_low_energy` 6.2.1 in central/peripheral roles. The advertising
phone is authoritative: it stores the hidden deck, validates both players' turns,
scores matches, and distributes only visible cards. Service discovery filters on
the MyMemory service UUID. Hosts advertise a short random label to choose the
correct nearby game. The first subscribed peer starts the invited match.

Commands use writes with response; snapshots use indications. Messages are
fragmented for the minimum 20-byte ATT payload, bounded to 8KiB and reassembled
with ordered message/fragment identifiers. A two-second heartbeat republishes
full state to recover after an interrupted snapshot. Disconnection ends the game;
create a new match to reconnect. Both players must keep the app open and nearby.
The mode requires neither an account nor Internet.

Android 12+ asks for Nearby devices. Android 11 and earlier requires the location
permission for BLE scans; those permissions are capped at API 30. BLE hardware is
optional for installing the app. Devices without peripheral advertising support
can try joining a match hosted by the other phone. iOS includes the Bluetooth
purpose string. No Bluetooth background execution entitlement is requested.

The package's [official documentation](https://pub.dev/packages/bluetooth_low_energy)
requires physical BLE devices; simulators cannot validate radio interoperability.
Automated tests cover MTU fragmentation, malformed/dropped packet recovery,
concealed state, illegal turns and indices, mismatch timing and rematch voting.
Hardware validation still needs this matrix before claiming Bluetooth certified:

| Host | Guest | Checks |
| --- | --- | --- |
| iPhone | Android | Discover, join, complete a game, rematch, disconnect |
| Android | iPhone | Same; include Android advertising capability |
| iPhone | iPhone | Same; decline then grant Bluetooth permission |
| Android | Android | Same; API 30 location and API 31+ Nearby devices |

For every row, disable Wi-Fi and mobile data while leaving Bluetooth enabled,
then verify full play and matching scores. Also test radio off, permissions
denied, app background/foreground, two hosts nearby, and an interrupted connection.

## Recovery provenance

See `legacy/AUDIT.md` for source identities, original behavior, signing findings
and source paths. Legacy trees are preserved unchanged. The original Pokémon
artwork is retained as historical evidence and is not used by the new app.
