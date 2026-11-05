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
      expect(deckAssets.keys.toSet(), {
        'garden',
        'cosmos',
        'ocean',
        'food',
        'sports',
        'travel',
      });
      expect(records.length, 108);
      expect(records.map((record) => record['sha256']).toSet().length, 108);
      for (final theme in deckAssets.keys) {
        expect(deckAssets[theme]!.length, 18);
        expect(deckAssets[theme]!.toSet().length, 18);
        expect(deckLabels[theme]!.length, 18);
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
      }
      expect(deckAsset('garden', -1), isNull);
      expect(deckAsset('garden', 18), isNull);
      expect(deckAsset('unknown', 0), isNull);
    },
  );

  test('Complete artwork license is bundled and registered once', () async {
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
  });
}
