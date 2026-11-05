# Sommonas deployment verification

Verified 2026-11-05. Public endpoint: <https://mymemory.sommomi.cc>.

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
