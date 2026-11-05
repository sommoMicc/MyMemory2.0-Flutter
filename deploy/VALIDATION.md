# Sommonas deployment verification

Current release: **30009**, served only at <https://sommomemory.sommomi.cc>.
See the final section for current verification. Earlier sections preserve the
restoration history and contain superseded domains/builds.

Initial verification: 2026-11-05 at the former hostname.

- Current server release: `20261105T062528Z`.
- Runtime image: `mymemory:20261105T062528Z`.
- Image digest: `sha256:a289fabe12fe4b46a0be13212e100522f9684bf5f3e049cb1df193164685b331`.
- Container state: running, healthy; Node `24.22.1`, non-root user, read-only
  filesystem, private `127.0.0.1:8798` listener and persistent `mymemory-data` volume.
- HTTPS `/`, `/healthz`, `/privacy`, `/support`: HTTP 200 with valid TLS.
- Deployed `main.dart.js` SHA-256 matches local build:
  `cf9cc9270139d9594639fbf04cd14e1dbf730be0c5de9d54b57138b1bb3c540c`.
- Deployed privacy page SHA-256 matches the final local Bluetooth disclosure:
  `e06ce06caefbe094fd5e6ff6cacd2bbd623de25ea662ffb871765532a377b554`.

Two independent real WebSocket connections to the public WSS endpoint verified
room creation/joining, concealed card identities, turn enforcement, identical
revealed states, disconnected-player state and secure resume with unchanged
identity/board. Explicit departure cleaned the test room; `/healthz` reported
zero remaining rooms. The production browser origin connected and exchanged a
ping/pong; an unrelated origin was rejected with HTTP 403.

These tests exercised native-style protocol connections, not physical Android/iOS
devices. Physical Bluetooth interoperability remains a separate release check in
`docs/RELEASE.md`.

The ten backend tests also passed inside a packaged read-only runtime container
on Sommonas before deployment. Its installed dependency audit reported zero
vulnerabilities at that time.

The preexisting Caddyfile site definitions were preserved exactly: their trimmed
SHA-256 before and after adding the marked MyMemory block was
`924e2ec3bd5316af8900b93e992948b1cac2a7decf1d10a20d536af0641ed5b1`.
The route is persisted in `/etc/caddy/Caddyfile` and active in Caddy's runtime;
a repeated configuration check reports it already configured and active.

## Compact interface deployment — 5 November 2026

Release `20261105T072907Z` serves the compact UI and plain privacy/support headings. Browser QA verified the existing cached session updates after a normal reload; the bootstrap now loads `main.ae9ada890cc4da3d.dart.js`, and application runtime/configuration files require cache revalidation. `scripts/prepare-web.mjs` runs before deployment and in CI. A regression test simulates an existing cached release and verifies the new entrypoint.

Live browser QA at 390×844: no slogans, mode/configuration/game fit the viewport, invite link pre-fills the room code, two browser clients join and show identical revealed cards, and leaving returns to configuration. All test rooms were removed; `/healthz` reports healthy with zero rooms. Local visual QA also verified all 36 cards at 320×568 and 844×390. Core gameplay/protocol code and Caddy routes are unchanged.

## Illustrated flip release — 5 November 2026

Release `20261105T075152Z`, web entrypoint `main.c98ced8a0357e79e.dart.js`. The existing browser updated normally to the illustrated interface. All 54 Noto 2D PNG assets at 512×512 and attribution/license files are bundled; native AAB/APK/IPA embedded bytes match the frozen catalog in `artifacts/native-builds-30004.json`.

Public browser QA verifies new colored mode cards and deck previews, Animali/Spazio/Oceano selection, rendered animal artwork, live flip, and the 36-card Spazio board at 320×568 and 844×390. The last card is reachable and reveals its Italian semantic label. Rows are complete (6×6 portrait / 12×3 landscape). No main-page scrolling or slogans. Twenty-seven Flutter tests cover all supported card counts across four realistic iOS viewports, flip/reverse, reduced motion, asset decoding, licenses and persisted collection/difficulty. The 11 Node regression tests remain applicable; no gameplay/protocol code changed for image collections.

## Animated scenery release — 5 November 2026

Release `20261105T085506Z` publishes the final 30005 web build with entrypoint
`main.768137f334f6f4a7.dart.js`. Its downloaded public JavaScript SHA-256 is
`768137f334f6f4a7e389fb51af122a7350f9882ddad9629da984189df2c83c77`, matching
the local build. The public bootstrap selects that entrypoint; representative
Animali/Spazio/Oceano PNGs, the deck manifest and complete Apache license match
their local checksums. Public requests use normal TLS certificate verification.

Two independent public WSS clients created and joined a room, received identical
revealed-card state, and left successfully. The test room was removed;
`/healthz` reported healthy with zero rooms. The container and persisted Caddy
route are healthy. All 71 native frozen source/asset hashes remain unchanged.

Deployment used the owner's existing SSH endpoint `michele@sommomi.cc:222`,
the existing local key and the NAS's previously trusted host-key alias
`192.168.0.164`, with strict verification before authentication. The deployment
script now accepts explicit port and host-key-alias settings, documented in
`deploy/README.md`. Global SSH configuration, router forwarding, firewall, DNS,
other Caddy sites and TLS trust settings were not changed. An earlier transient
network/TLS anomaly was no longer present at final public verification.

## Final mismatch-lock release — 5 November 2026

Release `20261105T091658Z`, web entrypoint `main.efe34b0b22b04a97.dart.js`. This retains the full-screen animated collection worlds and adds global input gating through the actual completion of both mismatch closing flips. Source controller callbacks, rather than an additional fixed timer, release that visual lock. A remote reveal cancels only the interrupted close, avoiding a stranded lock.

Thirty-three Flutter tests and static analysis pass: all viewport, image/license, no-scroll, full-row, flip, world-motion/lifecycle, keyboard and multiplayer tests remain; explicit local/online/Bluetooth regressions reject third-card input at mismatch display, conceal start, mid-conceal and 319ms, permitting it after full completion. Reduced motion and remote interruption are covered. Existing local/BLE engine tests were strengthened with a genuine third untouched card and 899ms checks. Eleven Node tests cover the unchanged authority/protocol.

Final native packages are 30006; frozen source and 71 file/asset fingerprints in `artifacts/native-builds-30006.json`. Android internal release 4 is live; Apple receipt `fa57fa4f-fae5-4353-a2b5-a2425871ea73` is COMPLETE/VALID/IN_BETA_TESTING after checksum-only recovery, with no duplicate binary transfer.

## Events after completed flips — 5 November 2026

Release `20261105T100402Z` publishes build 30007 with entrypoint
`main.9c06ff725d8f5182.dart.js`. Immutable client presentation snapshots defer
scores, matched styling and the final result until opening flips finish; turn
changes wait until mismatched cards have finished closing. Actual animation
callbacks release the visual gate. Remote card changes queue in order and
unchanged heartbeats are ignored. Authority and its 900ms deadline are unchanged.

All 37 Flutter tests and analysis pass, including local final-pair/result timing,
early online/Bluetooth reveal and hide, heartbeat deduplication, rotation during
reveal and stale callbacks after a new round. Independent review reproduced the
rotation issue before its fix and verified the same regression afterwards.

Public TLS, page/health responses, the prepared entrypoint hash, all 54 PNGs and
license/manifest bytes match the frozen artifacts. Two public WSS clients joined,
flipped and left successfully, leaving no test rooms. Browser QA reloaded the
existing public tab and verified the world, opening flip and complete 36-card
grid at 390×844. Temporary viewport overrides were reset. Proof:
`artifacts/game-world-live-30007.png`; deployment receipt:
`artifacts/web-deploy-30007.json`.

The signed AAB/APK/IPA match all 71 frozen source/asset hashes in
`artifacts/native-builds-30007.json`. Android internal release 5 is live. Apple
upload `e456678f-f659-402c-a6ba-251cd03aa967` is COMPLETE/VALID/IN_BETA_TESTING
and assigned to the existing internal group with its sole owner tester.

## SommoMemory and domain migration — 5 November 2026

Build 30008 uses the display name **SommoMemory** on Android, iOS and web while
retaining `cc.sommomi.mymemory`, the existing Apple/Play records, signing keys,
service names and persistent `mymemory-data` volume. The new primary endpoint is
`https://sommomemory.sommomi.cc`, with multiplayer at `/ws`.

Release `20261105T132117Z` serves `main.13a9a6272aab18dc.dart.js`, SHA-256
`13a9a6272aab18dc4ceae4f6762b1826455306ce7fcf885f8238d8e4a01a5900`.
Public checks with ordinary DNS and TLS verification confirm the title/PWA
manifest, privacy and support branding, the prepared entrypoint, all 54 PNGs,
manifest and license bytes. The final native packages have matching names,
version, signatures, assets and 79 frozen runtime/asset/identity/config hashes
in `artifacts/native-builds-30008.json`.

Migration first enabled both hosts in proxy mode while Caddy obtained the new
certificate. Only after normal DNS and HTTPS worked was the final legacy HTTP
redirect enabled. `mymemory.sommomi.cc/support?from=legacy&check=1` returns HTTP
301 with the complete path/query preserved on the new domain. The old `/ws`
endpoint remains proxied: a new-domain browser client and an old-domain native
client created/joined the same room, received identical revealed cards and left
successfully. An old-origin browser WebSocket also exchanged ping/pong. All test
rooms were removed; health reported zero rooms.

The other Caddy site definitions were unchanged, confirmed before and after the
final route update with SHA-256
`5ed20e19f4bb909c615da391e05a47c5b8b04d29aff0fd19d487591a4aad1e21`.
No router, firewall, TLS trust or resolver settings were changed by deployment.
Root browser QA confirmed the new-domain SommoMemory home at 320×568 without
overflow; its viewport was reset afterwards. Proof:
`artifacts/sommomemory-live-30008.png`. Public verification receipt:
`artifacts/web-deploy-30008.json`.


## Profiles, collections and invitations — build 30009

Final release `20261105T154100Z`, runtime `main.ce4250bf8376bded.dart.js`, SHA-256
`ce4250bf8376bded8dd1a201365e2d759c0efdfa3c2dccc1a6c819a5506209fb`.
The web client was rebuilt with explicit production profile/WebSocket endpoints;
the QA `localhost:8787` endpoints are absent. All 108 PNGs, the catalog manifest
and deck license/notice files were downloaded over verified public HTTPS and
compared byte-for-byte. The catalog has six illustrated collections plus the
free Paola collection of 18 text syllables. Native packages contain the same
assets and have 203 frozen source/configuration/asset fingerprints.

At the user's explicit request, **only `sommomemory.sommomi.cc` is supported**.
The former hostname was removed from the game's Caddy block, origin allowlist,
Android verified intent filters and iOS associated-domain entitlement. Native
30009 packages were rebuilt after that change, before any store reservation or
upload. The primary hostname has HSTS `max-age=15552000` without
`includeSubDomains`. Parent-domain and unrelated-site TLS policy is unchanged.

The AASA well-known route, its root alias and Android Asset Links all returned
HTTP 200 `application/json`, without redirects and byte-identical to source,
before the store upload agents were released. Android uses the Google Play App
Signing fingerprint, not the upload certificate. The exported IPA has the sole
current associated domain and only `L6CS7PYA4B.cc.sommomi.mymemory` as its Keychain
access group. The explicit `sommomemory://invite/CODE` fallback contains only a
room code. Physical OS routing, Safari user preferences and physical Bluetooth
interoperability remain manual checks; see `docs/DEEP_LINKS.md`.

The public profile API verified seven decks/four free, recovery-version metadata,
100 initial gems, a completed Paola ticket paying 20 exactly once, replay-safe
claim retries, preview/recovery on a second session with the same 120-gem wallet
and no second welcome grant, and deletion/revocation of the disposable test
profile and recovery code. Tokens/codes were held only in the test process and
are absent from receipts. The final origin-only server adjustment retained the
same economy implementation; the removed browser origin returns HTTP 403.

Two real public WebSocket clients (native-style and production browser origin)
created/joined a Paola 36-card room, synchronized the revealed card and explicitly
left. An older client lacking Paola support received `UPDATE_REQUIRED` before
joining. The test room was removed. The preexisting room count was one before
and after these checks; no unrelated room was removed.

The container is healthy, Node 24.22.1, non-root, read-only except for the existing
`mymemory-data` volume and temporary directory, with only the private
127.0.0.1:8798 listener. Existing data was not reset. SQLite, its WAL/SHM and the
capability key are mode 0600 and persisted across the final deployment. Local
`server/data` was excluded from transfer. Backups must preserve a consistent
SQLite snapshot/WAL together with its capability key; never copy only a live
SQLite file. The Caddy source outside this game's marked block retained SHA-256
`3f5beb947168dcf9baede9d1f90eca2bea7c7f6c42ed21244d8470e4e44d9936`
before and after the change. Full evidence: `artifacts/web-deploy-30009.json`.

All 71 Flutter tests and 28 Node tests passed before packaging, with five targeted
server association/origin/protocol tests passing after the final hostname-only
configuration change. No additional gameplay or UI changes were made during
packaging or deployment.

### Final browser and regression checks — 30009

After the final new-domain-only deploy, the public website was checked at
390×844. Paola was selected before starting a solo game; all 36 cards fit in
nine complete rows of four, with no page scrolling. A card revealed a real
syllable after its flip; the covered cards use a distinct book back. Safe public
proof: `artifacts/paola-live-30009.png`. The `/invite/ABC234` route opened the
online setup with that code prefilled and an explicit **Apri nell’app** action.
This browser check does not establish native OS handoff on a physical phone.
The viewport override was reset afterward.

The final frozen sources passed Flutter analysis, all **71 Flutter tests** and
all **28 Node tests**. All **203 source fingerprints** still match the final
native build receipt. Local browser QA separately completed a valid game
(100→120 gems), activated recovery, previewed and restored the same 120-gem
profile in a separate browser origin without merging balances, and verified
persistence after reload. Its isolated test database and recovery credentials
were removed; no recovery code is stored in the repository.
