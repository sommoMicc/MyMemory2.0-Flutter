# Illustrated deck collections

Researched and downloaded on 5 November 2026. Three collections are bundled in
the app: **Animali**, **Spazio**, **Oceano**, each with 18 distinct illustrations.
They use local PNG files rather than system emoji characters or Material icons,
so Android, iOS and web render the same artwork and work offline.

## Sources compared

| Source | Official licensing information | Fit for these collections |
| --- | --- | --- |
| [Google Noto Emoji 2D](https://github.com/googlefonts/noto-emoji) | The project distinguishes image resources under Apache 2.0 from font files under OFL. The [2D image notice at the pinned commit](https://github.com/googlefonts/noto-emoji/blob/99701e07d3d1fe1bdbcdb14964547f0fd592966f/2D/svg/LICENSE) identifies the Apache 2.0 terms and Google copyright. | Selected: consistent color illustrations across animals, space and sea objects, with original transparent PNG exports. |
| [Kenney Animal Pack](https://kenney.nl/assets/animal-pack) and [Animal Pack Remastered](https://kenney.nl/assets/animal-pack-remastered) | The official asset pages list Creative Commons CC0. | Suitable animal illustrations, but these packs do not supply all three themes in one visual system. |
| [OpenMoji](https://github.com/hfg-gmuend/openmoji#license) | Graphics use CC BY-SA 4.0. The official project provides an attribution statement and describes its graphics/code licensing separately. | A complete alternative with a different outline style and share-alike requirements for the graphics. |

The selected assets come only from Noto's **2D** directory; no Noto 3D artwork,
font files, flags or third-party character packs are included. The downloaded
images are unchanged. MyMemory selects and orders them into collections.

## Pinned provenance and reproduction

Upstream repository: `googlefonts/noto-emoji`.
Pinned commit: `99701e07d3d1fe1bdbcdb14964547f0fd592966f`.
Upstream image path: `2D/png/512/emoji_u<codepoint>.png`.

`app/assets/decks/manifest.json` records all 54 original URLs, source paths, local
paths, Italian labels, dimensions, byte counts and SHA-256 fingerprints. Every
download was checked for HTTP 200, PNG signature and 512×512 dimensions. The
54 images total approximately 1.30 MiB compressed. The original resolution
supports the large cards on Retina displays; decoded image caches can choose a
smaller render size where appropriate.

To reproduce the exact bundle from the pinned source:

```sh
node scripts/fetch-decks.mjs
```

The script also regenerates the ordered catalog. Preserve its card order: IDs
`garden`, `cosmos`, `ocean` and values 0–17 remain the multiplayer protocol's
stable mapping. No server or Bluetooth protocol changes are required.

## Files and application interface

Images live under `app/assets/decks/{garden,cosmos,ocean}/`. The Flutter assets
section includes those folders and the accompanying documents. `app/lib/decks.dart`
exports `deckNames`, `deckAssets`, `deckLabels`, `deckAsset(theme, value)`,
`deckCover(theme)` and `deckLabel(theme, value)`. Labels provide Italian names
for accessibility. The UI calls `registerDeckLicenses()` at startup.

The bundle contains:

- `LICENSE-APACHE-2.0.txt`: complete [Apache 2.0 license text](https://www.apache.org/licenses/LICENSE-2.0.txt).
- `UPSTREAM-NOTICE.txt`: retained Google image copyright and license notice.
- `NOTICE.txt`: project attribution, pinned source and scope of this selection.

`registerDeckLicenses()` makes these documents available in Flutter's license
registry without duplicating registrations. The deck tests load and decode every
bundled card, check all 18 protocol values per theme, and verify the complete
license is accessible through that registry.
