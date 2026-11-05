# Android — new app and historical listing

## New app requested by the user

On 5 November 2026 the user explicitly requested a **new Android app**, internal
testing, and deletion of the historical app. The new Console record is created:

| Field | Verified value |
| --- | --- |
| Name | MyMemory Together |
| Package/application ID | `cc.sommomi.mymemory` (Console availability verified) |
| Console app ID | `4972469070574777722` |
| Language/category/pricing | Italian `it-IT`, game, free |
| Internal track ID | `4700857721365894827` |
| Tester list | MyMemory test interno; selected and saved; one account owner tester |
| Release | 5, name `3.0.0 (30007) - Eventi dopo il flip`; **available to internal testers**, published 5 November 2026 at 11:02 as shown in Console |
| Binary | Final **3.0.0 (30007)** uploaded and accepted |
| Track status | **Attivo** |
| App signing | Releases signed by Google Play; no new terms prompt appeared |
| Production | No production release requested or performed |

[New app dashboard](https://play.google.com/console/u/0/developers/5468026965874523214/app/4972469070574777722/app-dashboard)
and [internal release details](https://play.google.com/console/u/0/developers/5468026965874523214/app/4972469070574777722/tracks/4700857721365894827/releases/5/details).
The **live internal opt-in link** is
[Join the internal test](https://play.google.com/apps/internaltest/4700857721365894827).
It was opened in the owner's signed-in browser and showed the invitation to test
`cc.sommomi.mymemory (unreviewed)` plus **Accept invite**. The invitation was not
accepted on the user's behalf. The tester must open it with the account included
in the selected tester list and accept the invitation before installation.

Google temporarily displays the unreviewed package name instead of the eventual
store name for this new internal app. This release is **internal only**, not a
production listing. Console accepted the binary with min API 24, target API 36,
three ABIs, and ReTrace mapping/native symbols attached.

Build 30007 replaces internal build 30006 with presentation synchronized to the
actual card animations. Scores, matched-pair styling and the final result appear
after the opening flip completes; turn changes appear after both cards finish
closing. Input stays locked during opening, closing and queued presentation
updates. Rapid remote snapshots preserve the visual sequence without replaying
heartbeat events. Rotation and new-round resets cannot strand an animation lock
or replay an old action. The authoritative local, Bluetooth and server engines
and their 900ms mismatch interval are unchanged.

Before packaging, Flutter analysis and **all 37 Flutter tests passed**, including
local final-pair events, online/Bluetooth snapshot ordering, complete closing,
reduced motion, rotation and round-reset regressions. Independent review first
reproduced the rotation lock and then verified its correction.

Full-screen animated scenery for Animals, Space and Ocean, floating characters,
reduced-motion and pause handling, illustrated collections, animated card flips,
complete uniform rows and non-scrolling screens remain. The upload and review
screens verified versionCode **30007**,
versionName **3.0.0**; Console reports **zero previously supported devices lost**.
The owner tester list and invitation link were unchanged.

Uploaded artifact:
`artifacts/MyMemory-Together-3.0.0-30007.aab`, SHA-256
`5d5089b6ee89e1d8227dc25fb010c699e9624ebe75bcad7e3efad77cf2d13a1a`.
The dedicated upload certificate SHA-256 is
`404D6F54025C024007E37F2A25352CB84471268A1C6C0D78C17A9565E12BED67`.
Private signing materials remain outside the repository.

Creation required ordinary program-policy compliance and US export-law
acknowledgments. No new signing-service contract was presented at creation.
There was no connected Play tool or configured Play Developer API credential;
the official [API resource reference](https://developers.google.com/android-publisher/api-ref/rest)
also exposes no create-app operation, so this work uses the signed-in Console UI.

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
deletion. The current presentation-synchronization update 30007 is recorded above.

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
`https://mymemory.sommomi.cc/privacy` and `/support`, but Console declarations still
need to reflect the final app behavior and the user's intended audience.

During the initial historical audit, no Android upload, production submission or
republishing action was performed. The subsequent replacement internal release
and authorized old-app deletion are recorded above.
