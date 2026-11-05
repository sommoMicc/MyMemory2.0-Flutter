# MyMemory recovery audit — 2026-11-05

## Recovered sources

- Original Java/Eclipse Android app: `../MyMemory/` (no Git metadata), package **com.michele.mymemory**, manifest versionCode 1/versionName 1, min SDK 5, target SDK 19.
- HTTP prototype: `../ProvaHTTPRequest/`, package com.michele.provahttprequest; useful only as historical reference.
- Artwork experiments: `../carte/`.
- [Flutter repository](https://github.com/sommoMicc/MyMemory2.0-Flutter), cloned here unchanged at `4911545` (master). `old/` contains playable singleplayer and online multiplayer. `new/` is an unfinished UI rewrite: its mode-selection Play button has no callback and no multiplayer networking dependency.
- [Node repository](https://github.com/sommoMicc/MyMemory2.0-Node), cloned here unchanged at `6cf9b7e` (master). Express 4, Socket.IO 2.0.3, MySQL, email links, old Babel/Mocha tests.

## Gameplay and multiplayer evidence

Original Java has singleplayer, local two-player on the same device, online player search/challenge/synchronization, stored scores and card themes. Easy is 12 cards, medium 20, hard 24, extreme uses triples. TimeAttack has menu/manifest references; some manifest Activities have no matching source file.

The original online app posts to PHP endpoints under `http://yottagroup.altervista.org/mymemory/`. The PHP backend is not in this workspace or either listed GitHub repository. The Flutter online client instead targets `https://tagliabuemichele.homepc.it` and works with the recovered Node service.

Flutter old + Node implement synchronous two-player matches: 12 cards/six pairs, colored alphabet symbols, initial memorization preview, challenge by username, matching pair scores and keeps the turn, mismatch changes turn, completion declares winner or draw. Node distributes the entire shuffled deck to both clients and trusts flip messages without validating turn/card range/matched-state, so it is unsuitable for direct public redeployment. Disconnect drops the match; there is no reliable resume.

No Bluetooth classes, socket APIs, dependencies, or Android Bluetooth permissions were found in the original Java or either Flutter tree. Therefore Bluetooth cannot be claimed recovered.

## App identities and signing

| Source | Android ID | iOS ID |
| --- | --- | --- |
| Original Java | com.michele.mymemory | none |
| Flutter old | com.micheletagliabue.letsmemory | com.example.prova |
| Flutter new | it.homepc.tagliabuemichele.lets_memory | it.homepc.tagliabuemichele.letsMemory |

The recovered `../MyMemory/bin/MyMemory.apk` confirms com.michele.mymemory/versionCode 1. It is signed with an **Android Debug** certificate (SHA-256 `4f3d9c2a3b95a139021da2e0752908dcb2c192d95308ab71b0c0676e68a9c275`), not evidence of the Play release key. Flutter old references `android/key.properties` for release signing; neither that file nor a release keystore is present in the recovered repo.

On 2026-11-05, public Google Play detail requests for all three Android IDs returned HTTP 404 with Italian locale/country; web searches returned no indexed matching result. This does **not** establish that there is no delisted/private/region-restricted Play Console record. The existing package, highest uploaded versionCode, and release/upload-key requirements must be confirmed in Play Console before an update upload.

## Reuse recommendation

Keep legacy trees unchanged as recovery evidence. Build one maintained Flutter client for Android/iOS/web with a shared game model; use the working old tree as behavior reference and the newer tree only for visual ideas. Preserve com.michele.mymemory provisionally to support restoration of the original listing if it is the matching Console record. Replace the backend with authoritative validated turns, private hidden-card state, invite rooms, and reconnection, hosted on Sommonas under mymemory.sommomi.cc.

Reuse game rules, alphabet/geometry themes, and conceptual UI navigation. Avoid shipping the unlicensed Pokémon artwork from the old app; new app-native icons/illustrations are easier to maintain and publish. Remove legacy boot polling, obsolete task permissions, login/passwordless email infrastructure and old unsupported socket plugins unless there is an explicit new product need.

## Useful code locations

- Original rules/themes: `../MyMemory/src/com/michele/mymemory/oggetti/CartaMemory.java`, `MemoryFrame.java`, `Inizio2.java`.
- Original online: `../MyMemory/src/com/michele/mymemory/online/`.
- Flutter complete game: `MyMemory2.0-Flutter/old/lib/pages/{singleplayer,multiplayer}/game_arena.dart`.
- Flutter network/protocol: `MyMemory2.0-Flutter/old/lib/utils/{network_helper,socket_helper,multiplayer_helper}.dart`.
- Flutter incomplete rewrite: `MyMemory2.0-Flutter/new/lib/UI/pages/singleplayer/seleziona_modalita.dart`.
- Node match engine: `MyMemory2.0-Node/model/game.js`; network handlers: `MyMemory2.0-Node/websocket.js`.

## Play Console verification (subsequent authenticated read-only check)

The actual original listing was found: **com.michele.mymemory**, Console app ID **4975576173768407729**, status **Non pubblicata**. The artifact list contains one uploaded APK: **versionCode 2 / versionName 0.9**, uploaded 16 October 2015. The app is **not enrolled in Play App Signing**, so recovery of the original release keystore is needed to update the same package. The local debug-signed version 1 is not its signing evidence. See `../docs/ANDROID.md` for the confirmed Console links and policy declarations still required.
