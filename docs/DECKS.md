# Illustrated deck collections

The app bundles **21 illustrated collections** with 18 distinct cards each
(378 card PNGs total). Twelve decks use unchanged Noto Emoji 2D images; nine
specialist decks use original illustrations generated for SommoMemory and
sliced from transparent atlases. **Paola** is an additional free collection
with 18 Italian syllables rendered as scalable text. Local assets render
consistently on Android, iOS and web and work offline.

| Arena | Free collections | Gem collections |
| --- | --- | --- |
| Valle Selvaggia | Animali, Fattoria, Fiori e piante | Insetti, Dinosauri |
| Baia Corallina | Oceano, Spiaggia, Navigazione | Pirati, Abissi |
| Grande Città | Veicoli, Mestieri, Strumenti musicali | Cibo, Sport, Viaggi |
| Frontiera Spaziale | Spazio, Laboratorio, Base spaziale | Alieni, Robot |

Specialist collections include relevant equipment and environments: Dinosauri
covers prehistory and excavation, Abissi contains deep-sea life, Insetti covers
small invertebrates, and Robot contains distinct mechanical characters.
Labels describe the pictured subject. Within each deck all 18 image files and
labels are distinct. Artwork hashes are also checked for reuse between decks
in the same arena. The collections do not use recolored duplicates or
system-font emoji.

## Artwork sources

| Source | Provenance and license handling | Decks |
| --- | --- | --- |
| Google [Noto Emoji 2D](https://github.com/googlefonts/noto-emoji) | 216 unchanged PNGs from a pinned upstream commit. Noto's image notice and Apache 2.0 license are retained in the bundle; font licensing is not applicable because no font files are included. | Animali, Spazio, Oceano, Cibo, Sport, Viaggi, Fattoria, Fiori e piante, Veicoli, Mestieri, Strumenti musicali, Laboratorio |
| OpenAI ImageGen built-in | 162 original generated illustrations. Prompts, atlas hashes, grid cells and crop metadata are recorded. No third-party SPDX license is asserted for these images. | Insetti, Dinosauri, Spiaggia, Navigazione, Pirati, Abissi, Base spaziale, Alieni, Robot |

The Noto images come from the **2D** directory only. No Noto 3D artwork, font
files, flags, or third-party character packs are included. The Noto source image
copyright and Apache license notice are retained separately from the disclosure
for generated artwork.

## Pinned provenance and reproduction

Noto repository: `googlefonts/noto-emoji`
Pinned commit: `99701e07d3d1fe1bdbcdb14964547f0fd592966f`
Image path: `2D/png/512/emoji_u<codepoint>.png`

The curated Noto mappings are stored in `scripts/arena-decks.json`. Original
subjects and prompts are stored in `scripts/arena-original-art.json`; source
atlases are kept under `artifacts/arenas/source-art/`. The deterministic crop
tool is `scripts/slice-arena-atlases.py`. It cuts 6×3 atlases using recorded row
boundaries, trims to the visible alpha silhouette, preserves transparency,
centers the subject, and pads each result to 512×512.

To reproduce the bundle, use Node 22.13+, Python 3.9+ with Pillow 10.3, and all
nine source atlases, then run:

```sh
node scripts/fetch-decks.mjs
```

The script uses `python3` by default. Set `PYTHON3` to a different interpreter
when Pillow is installed in a separate environment.

The script downloads Noto images from the pinned commit, verifies PNG signatures
and dimensions, slices original atlases, checks each deck and arena for repeated
artwork, writes separate source notices, and regenerates `app/lib/decks.dart`.
It removes only superseded PNG drafts from the nine replaced deck folders and
preserves all six legacy collections and their value ordering.

`app/assets/decks/manifest.json` records all 378 local assets, Italian labels,
dimensions, byte counts, and SHA-256 hashes. Each Noto record also includes the
source URL, path, commit, and Apache 2.0 license. Each generated-art record
includes its source atlas, atlas hash, prompt, cell, crop bounds, and tool. The
app contains 21 illustrated decks plus Paola; deck IDs and prices match
`server/catalog/arenas.v1.json`.
Ranked sessions require both `ranked-v1` and `ranked-attempts-v1`; see
`server/PROTOCOL.md`.

## Files and application interface

Images live under `app/assets/decks/<deckId>/`. The Flutter assets section
includes these folders and their notices. `app/lib/decks.dart` exports
`deckNames`, `deckPrices`, `deckAssets`, `deckLabels`, `deckAsset(theme, value)`,
`deckCover(theme)`, and `deckLabel(theme, value)`.

The bundle contains:

- `LICENSE-APACHE-2.0.txt` and `UPSTREAM-NOTICE.txt` for Noto assets.
- `NOTICE.txt` with Noto attribution and scope.
- `ORIGINAL-ART-NOTICE.txt` as a separate generated-art disclosure. It does not
  assert a third-party license.

`registerDeckLicenses()` registers the Noto license and original-art disclosure
as separate entries. Artwork tests decode all 378 PNGs, verify the 18 labels
and images per deck, check that hashes are unique within each deck and arena,
and validate provenance for both sources.

## Paola syllable collection

Paola is free for every profile, including profiles created before this release.
Its stable labels are `PA PE PI PO PU LA LE LI LO LU MA ME MI MO MU SA SE SI`.
Each chosen label appears twice on a board, using the same card-value protocol
as illustrated decks. Text is rendered in the bundled Outfit font. `deckAsset`
and `deckCover` intentionally return null for Paola; `DeckArtwork` renders each
syllable. The background is an original code-drawn notebook and the back uses a
book symbol. Paola remains outside ranked draws and available in non-ranked
play.
