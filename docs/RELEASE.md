# MyMemory release readiness

Verified 2026-11-05. This file records preparation, not store publication.

The final signed iOS artifact is `app/build/ios/ipa/MyMemory.ipa`, version
**3.0.0 (30001)**, SHA-256
`60ba4eeecf5a0e511898520bdbe71b74938ee80767ffd012d70c41fd68f3dbeb`.
All 16 Flutter tests and static analysis passed; Android debug build and native
iOS IPA/signing/icon/launch validation succeeded. The IPA was uploaded through
the Build Upload API, binary delivery and Apple upload processing are `COMPLETE`. The processed build
is `VALID`, with internal TestFlight state `READY_FOR_BETA_TESTING`, under upload
and build ID `b8837758-5b6f-48a1-acb0-c508db210729`.
The receipt in `artifacts/testflight-upload.json` contains the latest status.

Internal TestFlight group `MyMemory Internal`
(`d811d09d-3800-4275-b5c3-8a9773439b1d`) contains only the account holder and has no
public link. Build 30001 is attached and Italian test notes include the required
physical-device Bluetooth validation. No external testers were added.

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
Apple's
[Apps API documentation](https://developer.apple.com/documentation/appstoreconnectapi/apps)
states that creating a new app record requires the App Store Connect website.
The [Build Upload API introduced in 4.1](https://developer.apple.com/documentation/appstoreconnectapi/build-uploads)
does support direct binary uploads; that newer resource supersedes the older
Apps overview's Transporter-only upload statement. Use:

```sh
node scripts/testflight-upload.mjs app/build/ios/ipa/MyMemory.ipa
```

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

Play Console directly confirms the original ID **com.michele.mymemory**, an
**unpublished** listing, and highest uploaded **versionCode 2 / versionName 0.9**.
The modern project preserves the ID and uses versionCode 30001. See
[ANDROID.md](ANDROID.md) for authoritative Console URLs and full findings.

The app is **not enrolled in Play App Signing**, so updating the existing listing
requires the **original release signing key**. No original release keystore was
found in the recovered source or Flutter repository; the local old APK is
debug-signed. A new key or ordinary upload-key reset is insufficient to preserve
updates for this record. Android release upload remains dependent on recovering
the original signing key and completing the outstanding Console declarations.

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
