# Android — new app and historical listing

## New app requested by the user

On 5 November 2026 the user explicitly requested a **new Android app**, internal
testing, and deletion of the historical app. The new Console record is created:

| Field | Verified value |
| --- | --- |
| Installed app display name | SommoMemory |
| Console record name | MyMemory Together; SommoMemory is the installed app display name |
| Package/application ID | `cc.sommomi.mymemory` (Console availability verified) |
| Console app ID | `4972469070574777722` |
| Language/category/pricing | Italian `it-IT`, game, free |
| Internal track ID | `4700857721365894827` |
| Tester list | MyMemory test interno; selected and saved; one account owner tester |
| Release | 11, version `3.1.0 (30013)`; **active on internal track** |
| Binary | **3.1.0 (30013)** uploaded and accepted |
| Track status | **Attivo** |
| App signing | Releases signed by Google Play; no new terms prompt appeared |
| Production | No production release requested or performed |

[New app dashboard](https://play.google.com/console/u/0/developers/5468026965874523214/app/4972469070574777722/app-dashboard)
and [internal release details](https://play.google.com/console/u/0/developers/5468026965874523214/app/4972469070574777722/tracks/4700857721365894827/releases/11/details).
The **live internal opt-in link** is
[Join the internal test](https://play.google.com/apps/internaltest/4700857721365894827).
It was opened in the owner's signed-in browser and showed the invitation to test
`cc.sommomi.mymemory (unreviewed)` plus **Accept invite**. The invitation was not
accepted on the user's behalf. The tester must open it with the account included
in the selected tester list and accept the invitation before installation.

The current AAB is `artifacts/SommoMemory-3.1.0-30013.aab` (90,032,282 bytes;
SHA-256 `70629b0f64a282d6595321c92d643334d9610a44d7b8435a969e3f87eda6f273`).
Its local JAR signature check reports verified; Play release 11 is active on the
existing internal track. The signed artifacts, deployment and data-preservation
summary are recorded in `artifacts/native-builds-30013.json`. The Italian Play
listing text and two 1080×1920 phone screenshots are saved. Console confirms
“Modifica salvata”; the publishing overview lists the Italian listing among the
changes not yet sent for review. Its submission button is disabled until required
initial app dashboard steps are complete. Internal testing remains active.
No production release was created.

Google temporarily displays the unreviewed package name instead of the eventual
store name for this new internal app. This release is **internal only**, not a
production listing. Console accepted the binary with min API 24, target API 36,
three ABIs, and ReTrace mapping/native symbols attached.

Build **30013** is the current internal binary. The feature and package details
below document the preceding 30011 build and remain as release history. Build
**30011** replaced the intermediate internal build 30010. That binary uses
`wss://sommomemory.sommomi.cc/ws`; the public service is
`https://sommomemory.sommomi.cc`. Only this new domain is associated with native
invites; legacy-host intent filters were removed before the final rebuild, as the
user requested. API, domain associations and TLS were verified live before upload.
Package, signing identity, internal track and owner-only tester
list are unchanged. Proof of the active release:
`artifacts/play-internal-live-30011.jpg`.

This version includes optional original sound cues and haptic feedback for card
flips, matches, mismatches and turns, with saved sound/haptics preferences. The
audio is bundled PCM WAV; lifecycle changes stop pending feedback and iOS uses
the ambient audio category. The generator is kept outside the app under
`scripts/synthesize-feedback.py`: only the WAV and NOTICE are bundled. The final
archive and AssetManifest contain **zero `.py`/`.pyc` files**. Android 30010 was
briefly active as release 8 at 18:01 and has now been superseded by 30011, with no
rollback or tester changes.

A full room now returns a public snapshot of its two players, current scores and
final result if available. Manual refresh uses a separate read-only request: it
cannot claim a seat or reveal cards, profile data, balances or session tokens.
Full-room status precedes theme compatibility, while actual entry still checks
supported decks. Terminal entry/session errors cancel retry loops and discard
pending entry actions; transport failures remain retryable. Snapshot immutability,
late socket messages, refresh without joining, and unchanged frame/rate limits
are covered by server and client tests.

The current release also includes game-only gems (100 once per new profile, 20 per verified complete
game), permanent deck unlocks and optional cross-device profiles via a recovery
code. There are no payments, real-money purchases or account-balance merges.
Four decks are free: Animals, Space, Ocean and **Paola**, whose 18 syllables are
bundled as text. Food costs 200 gems, Sports 300 and Travel 400; the six illustrated
collections contain 108 bundled licensed PNGs. The deck is selected before play.
Only the multiplayer host needs to own a paid deck. Offline rewards require a
prepared server ticket and synchronize after reconnection; practice without a
ticket does not award gems. See [ECONOMY_PROTOCOL.md](ECONOMY_PROTOCOL.md).

Invites use verified Android App Links on `sommomemory.sommomi.cc` and the explicit
`sommomemory` app scheme. The association uses the verified **Google Play App
Signing** certificate SHA-256
`CF88459A498AE9C368EE97B9BFDCC74BEABF6C1AA73140CFF3931CAD85A97313`, distinct
from the upload certificate below. Older clients are rejected with an update
message before receiving a deck they cannot render. All **31 Node tests passed**,
including economy concurrency, restart/recovery, credentials, paid-host access
and old/new WebSocket compatibility. Native package, signatures, all 108 PNGs,
syllables, licenses and the final new-domain configuration were verified against
the frozen source; see local `artifacts/native-builds-30011.json`.

The presentation synchronization introduced in build 30007 remains. Scores,
matched-pair styling and the final result follow the actual card animations and appear
after the opening flip completes; turn changes appear after both cards finish
closing. Input stays locked during opening, closing and queued presentation
updates. Rapid remote snapshots preserve the visual sequence without replaying
heartbeat events. Rotation and new-round resets cannot strand an animation lock
or replay an old action. The authoritative local, Bluetooth and server engines
and their 900ms mismatch interval are unchanged.

At the final runtime freeze, Flutter analysis and **all 91 Flutter tests passed**, including
local final-pair events, online/Bluetooth snapshot ordering, complete closing,
reduced motion, rotation and round-reset regressions. Independent review first
reproduced the rotation lock and then verified its correction.
The final packaging regression verifies that the audio AssetManifest contains
only WAV and NOTICE, with no Python files. Live public-preview verification also
confirmed a read-only refresh from an in-progress 0–1 score to a final 5–1 result.

Full-screen animated scenery for Animals, Space and Ocean, floating characters,
reduced-motion and pause handling, illustrated collections, animated card flips,
complete uniform rows and non-scrolling screens remain. The upload and review
screens verified versionCode **30011**,
versionName **3.0.0**; Console reports **zero previously supported devices lost**.
The owner tester list and invitation link were unchanged.

Uploaded artifact:
`artifacts/SommoMemory-3.0.0-30011.aab`, SHA-256
`08f1b10f936c710a123d96829b897970ab18141543f4beb05e9a32c2408884e9`.
The dedicated upload certificate SHA-256 is
`404D6F54025C024007E37F2A25352CB84471268A1C6C0D78C17A9565E12BED67`.
Private signing materials remain outside the repository.

Creation required ordinary program-policy compliance and US export-law
acknowledgments. No new signing-service contract was presented at creation.
At creation there was no connected Play tool or configured Play Developer API credential;
the official [API resource reference](https://developers.google.com/android-publisher/api-ref/rest)
also exposes no create-app operation, so this work uses the signed-in Console UI.
For release 30009, the subsequently available generic service-account credential
authenticated successfully (OAuth HTTP200), but the read-only generated-APKs
request for this app's existing build 30008 returned HTTP403 `PERMISSION_DENIED`.
No grants were changed and no API edit/upload was created. The authorized
signed-in Console was used for internal distribution.

## SommoMemory rename — historical Store draft status

On 5 November 2026 the user requested the display name **SommoMemory**, preserving
the existing package and app record. The default Italian Store listing did not
previously exist. Its **Nome app** is now **SommoMemory**, saved as a draft and
verified after reloading the editor. No identifiers or tester settings changed.
Local evidence, excluded from Git: `artifacts/play-sommomemory-name-draft.jpg`.

At the time of this earlier snapshot, the name was a saved draft and the listing
description and screenshots were absent. For 3.1.0, the Italian listing text was
still pending a save and screenshot uploads were in progress when the current
receipt was prepared. Console continues to show **MyMemory Together** and the
temporary name **cc.sommomi.mymemory (unreviewed)**. Google's
[internal-testing guidance](https://support.google.com/googleplay/android-developer/answer/9845334)
explains that testers see a temporary name before the app's first review. A
complete Store listing and review are separate from the internal binary release;
neither production publication nor a first-review submission was performed.

Build **30011 was the live internal version** before release 30013, with
SommoMemory as its installed launcher name. The Store draft status below is
historical; the 3.1.0 listing update is tracked above. No production release was
created.

## Old app deleted — recoverable until 12 November 2026

The historical **com.michele.mymemory** app (Console ID
`4975576173768407729`) was deleted on **5 November 2026**, after the replacement
internal release was available. The user explicitly authorized both deletion and
transmitting the private registration-receipt identifier to the official Google
Play deletion form. That identifier is not recorded in this document or repository.

Console confirms **Hai tempo fino al giorno 12 nov 2026 per recuperare questa app
eliminata** and offers **Recupera app** under Advanced settings > App availability.
The deletion is recoverable until that displayed deadline; after it, Google makes
the deletion permanent. No additional irreversible deletion action was requested.

Immediately after deletion, the replacement **cc.sommomi.mymemory** app was
refreshed and verified separately: its then-current 30003 internal release
remained **Attivo**, with the owner tester list selected and the opt-in link
enabled. The replacement app and its signing settings were not modified during
deletion. The current SommoMemory update 30013 is recorded above.

The [current official deletion guide](https://support.google.com/googleplay/android-developer/answer/16483176)
requires an unpublished app, fewer than 1000 active devices, no unresolved review,
and an eligible account owner. An app with any historical installs retains its old
package permanently, so deleting it does **not** make `com.michele.mymemory`
reusable. The new package above is independent of the old signing key.

The following sections preserve the original read-only audit for historical
reference; they describe updating the old listing, a route the user superseded.

## Historical Play Console audit

Verified read-only on **5 November 2026**, in the user's existing signed-in Google
Play Console browser session. No Console fields, releases, declarations or signing
settings were modified. No Play Developer API credential or connected Play tool
was available in this task, so these facts were read directly from Console UI.

### Existing app

| Field | Verified value |
| --- | --- |
| App name | MyMemory |
| Package/application ID | `com.michele.mymemory` |
| Console app ID | `4975576173768407729` |
| Developer account ID | `5468026965874523214` |
| App-level publication status | **Non pubblicata** (Unpublished) |
| Home-page last update | 26 November 2018 |
| Latest and only uploaded artifact | APK, **versionCode 2**, **versionName 0.9** |
| Artifact upload time shown in Console | 16 October 2015, 13:59 |
| Production release | 0.9; historical rollout 100%; release details show 16 October 2015 |

The **Tutti gli app bundle** page showed one row only and disabled next-page
navigation, so the highest observed uploaded versionCode is **2**. The release
overview labels the old production release as available on Google Play; the
account home explicitly marks the app **unpublished**. The release label does not
establish that the listing is currently visible to new users. The 2018 home-page
update should not be interpreted as a newer binary release.

Authoritative Console pages:

- [App dashboard](https://play.google.com/console/u/0/developers/5468026965874523214/app/4975576173768407729/app-dashboard)
- [All uploaded artifacts](https://play.google.com/console/u/0/developers/5468026965874523214/app/4975576173768407729/bundle-explorer-selector)
- [Release overview](https://play.google.com/console/u/0/developers/5468026965874523214/app/4975576173768407729/releases/overview)
- [Signing management](https://play.google.com/console/u/0/developers/5468026965874523214/app/4975576173768407729/keymanagement)

### Signing requirement for the historical listing

The **Protetto con Play** overview explicitly states **Release non firmate da
Google Play**. Signing management presents an enrollment flow headed **Consenti a
Google Play di gestire la chiave di firma dell'app**, with the unselected option
**Usa chiave di firma dell'app esistente dell'archivio chiavi Java**. Therefore this
existing app is **not enrolled in Play App Signing**.

Updating this listing requires the original release signing key. A newly created
key or an Android debug key cannot update installations signed with the original
key. No enrollment option was selected and no signing key was uploaded. The old
local versionCode-1 APK's debug certificate is not proof of the versionCode-2 Play
release certificate; see `legacy/AUDIT.md`.

The modern project's earlier restoration build preserved
`applicationId = "com.michele.mymemory"`, but the user now requested a new app with
`cc.sommomi.mymemory`. Updating the historical listing would have required locating
and verifying the original keystore and its password/alias; these credentials
must stay outside source control. The new app uses its own upload key.

### Historical Console requirements visible for the next release

The **Testa e rilascia** page listed these required incomplete declarations:

- Privacy policy.
- Target audience and content.
- Data safety.
- Financial features.
- Health apps.

These were observed only; they were not completed or submitted. Public privacy
and support pages for the restored service are available at
`https://sommomemory.sommomi.cc/privacy` and `/support`, but Console declarations still
need to reflect the final app behavior and the user's intended audience.

During the initial historical audit, no Android upload, production submission or
republishing action was performed. The subsequent replacement internal release
and authorized old-app deletion are recorded above.
