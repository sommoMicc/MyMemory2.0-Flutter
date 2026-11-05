import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/decks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Every multiplayer card has a unique bundled, decodable illustration',
    () async {
      final manifest =
          jsonDecode(await rootBundle.loadString('assets/decks/manifest.json'))
              as Map<String, dynamic>;
      final records = (manifest['assets'] as List).cast<Map<String, dynamic>>();
      expect(deckAssets.length, 21);
      expect(
        deckAssets.keys.toSet(),
        deckNames.keys.where((id) => id != 'paola').toSet(),
      );
      expect(deckNames.keys, contains('paola'));
      expect(deckLabels['paola']!.length, 18);
      expect(records.length, deckAssets.length * 18);
      expect((manifest['sources'] as Map)['noto']['assetCount'], 12 * 18);
      expect((manifest['sources'] as Map)['original']['assetCount'], 9 * 18);
      expect(
        records
            .map((record) => record['sha256'])
            .every((hash) => (hash as String).length == 64),
        isTrue,
      );
      expect(
        (manifest['collections'] as Map).keys.toSet(),
        deckNames.keys.toSet(),
      );
      for (final theme in deckAssets.keys) {
        expect(deckAssets[theme]!.length, 18);
        expect(deckAssets[theme]!.toSet().length, 18);
        expect(deckLabels[theme]!.length, 18);
        expect(
          deckLabels[theme]!.toSet().length,
          18,
          reason: '$theme labels must be distinct',
        );
        expect(deckCover(theme), deckAsset(theme, 0));
        for (var value = 0; value < 18; value++) {
          final path = deckAsset(theme, value)!;
          final record = records.singleWhere(
            (record) => record['theme'] == theme && record['value'] == value,
          );
          expect(record['asset'], path);
          expect(record['label'], deckLabel(theme, value));
          final bytes = await rootBundle.load(path);
          final codec = await ui.instantiateImageCodec(
            bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          final frame = await codec.getNextFrame();
          expect(frame.image.width, 512, reason: path);
          expect(frame.image.height, 512, reason: path);
          frame.image.dispose();
          codec.dispose();
        }
        final deckRecords = records
            .where((record) => record['theme'] == theme)
            .toList();
        expect(deckRecords.length, 18, reason: '$theme manifest entry count');
        expect(
          deckRecords.map((record) => record['asset']).toSet().length,
          18,
          reason: '$theme artwork paths must be distinct',
        );
        expect(
          deckRecords.map((record) => record['sha256']).toSet().length,
          18,
          reason: '$theme artwork must not repeat an image',
        );
        for (final record in deckRecords) {
          if (record['source'] == 'OpenAI ImageGen built-in') {
            expect(record['atlasSha256'], hasLength(64));
            expect(record['prompt'], isNotEmpty);
            expect(record['crop'], isA<Map<String, dynamic>>());
            expect(record.containsKey('license'), isFalse);
          } else {
            expect(record['source'], 'Google Noto Emoji 2D');
            expect(record['license'], 'Apache-2.0');
          }
        }
      }
      final collectionMetadata =
          manifest['collections'] as Map<String, dynamic>;
      final seenByArena = <String, Map<String, String>>{};
      for (final theme in deckAssets.keys) {
        final arena = collectionMetadata[theme]['arenaId'] as String;
        final seen = seenByArena.putIfAbsent(arena, () => {});
        for (final record in records.where(
          (record) => record['theme'] == theme,
        )) {
          final hash = record['sha256'] as String;
          expect(
            seen[hash],
            isNull,
            reason:
                'Duplicate art within arena $arena: ${seen[hash]} and $theme',
          );
          seen[hash] = theme;
        }
      }
      expect(deckAsset('garden', -1), isNull);
      expect(deckAsset('garden', 18), isNull);
      expect(deckAsset('unknown', 0), isNull);
    },
  );

  test(
    'Artwork licenses and original-art disclosure are registered once',
    () async {
      await registerDeckLicenses();
      await registerDeckLicenses();
      final entries = await LicenseRegistry.licenses
          .where(
            (entry) =>
                entry.packages.contains('Noto Emoji 2D — deck illustrations'),
          )
          .toList();
      expect(entries.length, 1);
      final text = entries.single.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n');
      expect(text, contains('Copyright 2013 Google, Inc.'));
      expect(text, contains('Apache License'));
      expect(text, contains('END OF TERMS AND CONDITIONS'));
      expect(text, contains('99701e07d3d1fe1bdbcdb14964547f0fd592966f'));
      expect(text, isNot(contains('ORIGINAL SOMMOMEMORY DECK ART')));
      final originalEntries = await LicenseRegistry.licenses
          .where(
            (entry) => entry.packages.contains(
              'SommoMemory original artwork disclosure',
            ),
          )
          .toList();
      expect(originalEntries.length, 1);
      final originalText = originalEntries.single.paragraphs
          .map((paragraph) => paragraph.text)
          .join('\n');
      expect(originalText, contains('OpenAI ImageGen built-in'));
      expect(originalText, contains('No third-party SPDX license is asserted'));
    },
  );
}
