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
| Release | 1, name `3.0.0 - Primo test interno`; **available to internal testers**, published 5 November 2026 at 08:27 as shown in Console |
| Binary | Final **3.0.0 (30003)** uploaded and accepted; preliminary 30002 never uploaded |
| Track status | **Attivo** |
| App signing | Releases signed by Google Play; no new terms prompt appeared |
| Production | No production release requested or performed |

[New app dashboard](https://play.google.com/console/u/0/developers/5468026965874523214/app/4972469070574777722/app-dashboard)
and [internal release details](https://play.google.com/console/u/0/developers/5468026965874523214/app/4972469070574777722/tracks/4700857721365894827/releases/1/details).
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

Uploaded artifact:
`artifacts/MyMemory-Together-3.0.0-30003.aab`, SHA-256
`bac88b841f8d5616faf909635c8ac8c43b3d917918c7647411192d3dc745e923`.
The dedicated upload certificate SHA-256 is
`404D6F54025C024007E37F2A25352CB84471268A1C6C0D78C17A9565E12BED67`.
Private signing materials remain outside the repository.

Creation required ordinary program-policy compliance and US export-law
acknowledgments. No new signing-service contract was presented at creation.
There was no connected Play tool or configured Play Developer API credential;
the official [API resource reference](https://developers.google.com/android-publisher/api-ref/rest)
also exposes no create-app operation, so this work uses the signed-in Console UI.

## Old app deletion readiness

The historical app's Advanced settings > App availability page shows **Elimina
app**, and explicitly states that a deleted app can be recovered for **7 days**,
then is permanently deleted. Opening this dialog is read-only; it requires the
**developer account registration transaction ID** and old package
`com.michele.mymemory` before proceeding. No deletion has yet been submitted.
The new internal release is now ready; deletion is held pending the user's
specific authorization to enter the private registration-payment identifier into
Google's deletion form. The identifier was located privately by the parent agent
and is not recorded in this document or repository.

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

No Android upload, production submission or republishing action was performed.
