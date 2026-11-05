# Invitations and native-app associations

Build 30008 could receive an invitation in the website but had no Android App
Links intent filters, no iOS Associated Domains entitlement, and no native link
listener. The public Apple association URL returned the Flutter HTML fallback,
and Android's association URL did not exist. A website-only change could not add
the missing capabilities to an already installed binary.

Build 30009 adds the native handlers and their HTTPS associations. Its signed
packages and exported entitlements have been verified; the current hostname
serves the association JSON over verified HTTPS before the native uploads. It preserves package/bundle `cc.sommomi.mymemory`, Apple app/SKU,
Google Play record, account-holder tester and multiplayer protocol. Installed-device opening behavior remains a physical release check; a valid
association file and signed package alone do not establish that OS behavior.

## Invitation routes

New invitations use `https://sommomemory.sommomi.cc/invite/ABC234`. The supported hostname is only `sommomemory.sommomi.cc`, which also accepts
`/?room=ABC234`. At the user’s explicit request, the former hostname is no longer
published or registered with either operating system. The parser can still
extract a room code from an old URL supplied directly to it; this does not make
that URL resolve or open the app through the operating system. It accepts
HTTP/HTTPS with their standard ports, a six-character
room code matching the server, and the invitation paths. It rejects credentials
in URLs, conflicting/duplicate room parameters, unrelated paths, misleading host
suffixes and invalid encodings. Privacy and support remain website routes.

`app/lib/invite_links.dart` captures the initial URL and URLs received while the
app is running. It retains a pending room until the UI can consume it, suppresses
duplicate cold-start delivery and does not let a delayed initial result replace
a newer invitation. It does not automatically leave a game or join a room. A
room code is an invitation, never an account credential.

The web invitation screen also offers an explicit **Apri nell’app** action using
`sommomemory://invite/ABC234`. This fallback is registered natively and parsed only
as one six-character room code under the `invite` host; query strings, fragments,
credentials, ports and other routes are rejected. It never carries a profile
token or recovery code. It is not the shared canonical URL: the website does not
auto-launch it, infer installation or redirect in a loop. If the app is absent
or the browser refuses to open it, the web invitation and its room code remain.
Custom schemes are not domain-verified and another app can register the same
scheme; HTTPS associations remain the preferred invitation mechanism.

Sources: [Apple custom URL schemes](https://developer.apple.com/documentation/xcode/defining-a-custom-url-scheme-for-your-app),
[Android custom deep links](https://developer.android.com/training/app-links/create-deeplinks).

Without the app installed, the same route loads the website and preserves the
room. With the updated app installed, a verified external link can open it.
Android's manifest cannot filter the legacy root URL by query parameters on all
supported versions, so the root path may also open the app; the parser only
acts when it contains a valid room code.

## Apple

The AASA file uses app identifier `L6CS7PYA4B.cc.sommomi.mymemory`, with components
for `/invite/*` and the legacy root URL containing a six-character `room` query.
The server exposes both `/.well-known/apple-app-site-association` and
`/apple-app-site-association` as HTTP 200 JSON. The associated hostname must serve its
association without redirects. Only the current hostname is served.

The Runner entitlement contains only `applinks:sommomemory.sommomi.cc`. Flutter's built-in deep-link routing is disabled
so the `app_links` listener handles invitations once. Its iOS 7.x implementation
supports the existing Flutter SceneDelegate lifecycle.

Associated Domains was enabled through the configured App Store Connect API for
bundle resource `M5DK5NJ6KP`. A new distribution profile was created with the
existing certificate, installed outside the repository, and selected in the
Xcode Release/Profile configurations and export options:

| Item | Value |
| --- | --- |
| Profile | SommoMemory App Store Links |
| Profile ID | `66Z2SB723S` |
| Profile UUID | `f4f89090-799a-486e-b289-1e0546b0df6f` |
| Certificate ID | `86762T444Q` |
| State when created | ACTIVE |
| Expiry | 9 October 2027 |

Apple automatically invalidated the previous `MyMemory App Store` profile after
the capability change. Its API record and local file were preserved; existing
published builds remain unaffected. A rollback of signing configuration would
require regenerating a compatible profile, not selecting that invalid profile.
The public receipt `artifacts/associated-domains-profile.json` contains no
certificate private key, provisioning payload or API token.

iOS 14 and later normally fetch the association through Apple's CDN. Updating
the website does not guarantee an immediate refresh on a device. A tap between
pages on the same domain in Safari may intentionally remain in Safari; typing a
URL into the address bar is not a universal-link launch test. User choices to
stay in the browser also affect routing. Test an external link in Notes or
Messages after installing the new TestFlight build.

Sources: [Apple Associated Domains](https://developer.apple.com/documentation/xcode/supporting-associated-domains),
[Apple universal-link diagnostics](https://developer.apple.com/documentation/technotes/tn3155-debugging-universal-links),
[App Store Connect bundle capabilities](https://developer.apple.com/documentation/appstoreconnectapi/bundle-id-capabilities),
[app_links iOS lifecycle](https://github.com/llfbandit/app_links/blob/main/doc/README_ios.md).

## Android

Runner has one `android:autoVerify="true"` filter for the current hostname, with
VIEW, DEFAULT and BROWSABLE, HTTP/HTTPS, `/invite/` and the root query route.
Flutter's built-in link routing is disabled. The removed hostname is deliberately
absent from the manifest: older supported Android versions can require all
declared hosts to verify, so a retired DNS record must not block the current
hostname's verification.

The certificate below was read from the **Google Play App Signing** page's
official Digital Asset Links JSON on 5 November 2026. It is the certificate
Google uses for installed Play releases; it is **not** the upload certificate.

`CF:88:45:9A:49:8A:E9:C3:68:EE:97:B9:BF:DC:C7:4B:EA:BF:6C:1A:A7:31:40:CF:F3:93:1C:AD:85:A9:73:13`

`assetlinks.json` associates only this certificate and `cc.sommomi.mymemory` with
`delegate_permission/common.handle_all_urls`. Locally built APKs signed with the
upload key are intentionally not trusted by that public association; install
from the existing internal Play track for a real verification test. A future
Play signing-key upgrade requires checking Google's association snippet again.

Sources: [Android App Links filters](https://developer.android.com/training/app-links/add-applinks),
[Digital Asset Links configuration](https://developer.android.com/training/app-links/configure-assetlinks),
[Android verification commands](https://developer.android.com/training/app-links/verify-android-applinks),
[Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756).

## Profile storage

Browser storage and installed-app storage are separate sandboxes. Opening a room
link cannot copy a browser's local profile, guest record or sign-in state into
the app. Optional authenticated server sync is the way to recover a profile on
another device or platform; the account holder must sign in there. Invitations
contain no bearer tokens, passwords or profile-transfer secret.

The native default `FlutterSecureStorage` configuration keeps account secrets in
the iOS Keychain or Android encrypted storage. iOS grants only the app's own
Keychain access group, with no cross-app group or iCloud Keychain sharing. On
Android, both pre-31 full-backup rules and Android 12+ cloud/device-transfer rules
exclude the default secure-data, wrapped-key and configuration preference files.
Android Keystore keys cannot be moved to another device, so restoring those
encrypted files would otherwise leave credentials unreadable. Ordinary game
preferences remain eligible for backup. Custom secure-storage namespaces would
require corresponding explicit exclusions; these rules cover the default
configuration used by the app.

Sources: [flutter_secure_storage setup](https://pub.dev/packages/flutter_secure_storage),
[Android backup rules](https://developer.android.com/identity/data/autobackup).

## Verification

The focused parser/lifecycle suite has **9 passing tests**, covering trusted
hosts, invalid routes and encodings, duplicate delivery, pending consumption,
out-of-order initial delivery, platform errors, disposal and strict custom-scheme
fallback validation. XML/plist syntax,
JSON syntax and app-only Keychain settings were checked. The three public association routes returned HTTP 200 JSON with byte-identical
contents on the current hostname. The exported IPA contains only the current
applinks domain and its app-only Keychain group; the AAB contains only the current
verified host plus the explicit invitation scheme. See
`artifacts/native-builds-30009.json` and `artifacts/web-deploy-30009.json`.

Before claiming installed-device support, verify:

1. The current HTTPS host returns each association as HTTP 200 JSON without redirects.
2. The exported IPA entitlements match the selected provisioned capability and
   the current domain; the Play-installed Android app shows verified domain ownership.
3. External invitation taps start a terminated app, reach a running app, and
   preserve the room when the app is absent. Existing-game confirmation must not
   silently discard a match. Verify both new paths and legacy query invitations.
4. Privacy/support stay in the website, and the same-domain Safari behavior is
   distinguished from a failed external universal link.
5. Account sign-in and credentials survive an app update but are not copied by a
   room link or Android device backup. Physical restore and real iOS/Android
   opening behavior remain manual checks until tested on those devices.
