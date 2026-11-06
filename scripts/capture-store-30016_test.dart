// Run from an isolated copy of app/ as test/store_capture_test.dart.
// Captures the unmodified application widgets with an isolated local guest.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/economy.dart';
import 'package:mymemory/game.dart';
import 'package:mymemory/main.dart';
import 'package:mymemory/ui/arena_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

// A fresh guest with the same starter inventory as the application. Network
// synchronization is disabled so screenshots never create production profiles.
class _CaptureEconomy extends EconomyController {
  _CaptureEconomy(SharedPreferences prefs) : super(prefs: prefs);
  final data = ProfileData(
    id: 'store-preview-guest',
    displayName: '',
    activated: false,
    gems: 100,
    ownedDecks: ProfileData.freeDecks,
    revision: 1,
  );
  @override
  ProfileData get profile => data;
  @override
  int get gems => data.gems;
  @override
  Set<String> get ownedDecks => data.ownedDecks;
  @override
  bool get offline => true;
  @override
  Future<void> get localReady async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> sync() async {}
  @override
  Future<void> prefetchTicket({
    required String mode,
    required int pairs,
    required String theme,
  }) async {}
  @override
  Future<GameTicket?> takeTicket({
    required String mode,
    required int pairs,
    required String theme,
  }) async => GameTicket(
    id: 'store-preview-game',
    profileId: data.id,
    mode: mode,
    theme: theme,
    pairs: pairs,
    board: [
      for (var repeat = 0; repeat < 2; repeat++)
        for (var i = 0; i < pairs; i++) i,
    ],
    expiresAt: DateTime.utc(9999),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Apple Color Emoji')..addFont(
          File('/System/Library/Fonts/Apple Color Emoji.ttc')
              .readAsBytes()
              .then(ByteData.sublistView),
        ))
        .load();
    await (FontLoader(
      'Outfit',
    )..addFont(rootBundle.load('assets/fonts/Outfit.ttf'))).load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final target in [
    ('iphone', const Size(440, 956), 3.0, 59.0, 34.0, TargetPlatform.iOS),
    ('ipad', const Size(1032, 1376), 2.0, 24.0, 20.0, TargetPlatform.iOS),
    ('play', const Size(360, 640), 3.0, 24.0, 0.0, TargetPlatform.android),
  ]) {
    testWidgets('capture ${target.$1}', (tester) async {
      final root = Platform.environment['STORE_CAPTURE_DIR'];
      if (root == null)
        throw StateError(
          'Set STORE_CAPTURE_DIR to an absolute output directory.',
        );
      final out = Directory('$root/${target.$1}')..createSync(recursive: true);
      tester.view.physicalSize = target.$2;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = FakeViewPadding(top: target.$4, bottom: target.$5);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      debugDefaultTargetPlatformOverride = target.$6;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.view.resetPadding();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
        debugDefaultTargetPlatformOverride = null;
      });
      SharedPreferences.setMockInitialValues({
        'sound': false,
        'haptics': false,
        'game.pairs': 12,
        'game.collection': 'garden',
      });
      final prefs = await SharedPreferences.getInstance();
      final economy = _CaptureEconomy(prefs);
      const boundaryKey = ValueKey('store-capture');
      Future<void> boot() async {
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: Builder(
              key: UniqueKey(),
              builder: (context) {
                final app = MyMemory(
                  prefs: prefs,
                  economy: economy,
                ).build(context) as MaterialApp;
                final theme = app.theme!;
                // flutter_tester omits system font fallback. Preserve the app's
                // font and add the OS emoji fallback, without changing layout.
                return MaterialApp(
                  title: app.title,
                  debugShowCheckedModeBanner: app.debugShowCheckedModeBanner,
                  theme: theme.copyWith(
                    textTheme: theme.textTheme.apply(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Apple Color Emoji'],
                    ),
                    primaryTextTheme: theme.primaryTextTheme.apply(
                      fontFamily: 'Outfit',
                      fontFamilyFallback: const ['Apple Color Emoji'],
                    ),
                  ),
                  home: app.home,
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      Future<void> capture(String file) async {
        await tester.pumpAndSettle();
        // Finish normal asset decoding; image pixels come from bundled assets.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 150));
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(boundaryKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: target.$3);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('${out.path}/$file.png')
              .writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }

      await boot();
      await capture('01-home-pop');
      await tester.tap(find.text('Singolo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inizia partita'));
      await tester.pumpAndSettle();
      final dynamic gameState = tester.state(find.byType(GameScreen));
      final LocalGame game = gameState.local as LocalGame;
      final pairValue = game.deck.first;
      final indices = [
        for (var i = 0; i < game.deck.length; i++)
          if (game.deck[i] == pairValue) i,
      ];
      for (final index in indices) {
        await tester.tap(find.byType(MemoryCard).at(index));
        await tester.pumpAndSettle();
      }
      await capture('02-tabellone-pop');
      await boot();
      await tester.tap(find.text('Singolo'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ArenaJourneyTile));
      await tester.pumpAndSettle();
      await capture('03-viaggio');
      await boot();
      await tester.tap(find.text('Singolo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Collezione'));
      await tester.pumpAndSettle();
      await capture('04-collezioni');
      await tester.pumpWidget(const SizedBox.shrink());
      economy.dispose();
      await tester.pumpAndSettle();
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
