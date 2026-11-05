import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/main.dart';
import 'package:mymemory/game.dart';
import 'package:mymemory/online.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('Outfit')
      ..addFont(rootBundle.load('assets/fonts/Outfit.ttf'));
    await loader.load();
  });

  final viewports = [
    (const Size(320, 568), const FakeViewPadding(top: 20)),
    (const Size(390, 844), const FakeViewPadding(top: 59, bottom: 34)),
    (
      const Size(844, 390),
      const FakeViewPadding(left: 44, right: 44, bottom: 21),
    ),
    (const Size(1024, 768), const FakeViewPadding(top: 24, bottom: 20)),
  ];
  for (final viewport in viewports) {
    testWidgets('Setup and all 36 cards fit ${viewport.$1}', (tester) async {
      configureView(tester, viewport.$1, viewport.$2);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(MyMemory(prefs: prefs));
      await tester.pumpAndSettle();
      expect(find.byType(ModeTile), findsNWidgets(4));
      expect(find.byType(SingleChildScrollView), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Singolo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coppie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('18 coppie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Carte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sotto il mare'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inizia partita'));
      await tester.pumpAndSettle();
      expect(find.byType(MemoryCard), findsNWidgets(36));
      expect(find.byType(SingleChildScrollView), findsNothing);
      final safeRect = Rect.fromLTRB(
        viewport.$2.left,
        viewport.$2.top,
        viewport.$1.width - viewport.$2.right,
        viewport.$1.height - viewport.$2.bottom,
      );
      for (var i = 0; i < 36; i++) {
        final card = find.byKey(ValueKey('card-$i'));
        final bounds = tester.getRect(card);
        expect(
          safeRect.contains(bounds.topLeft),
          isTrue,
          reason: 'Card $i starts outside safe viewport',
        );
        expect(
          safeRect.contains(bounds.bottomRight),
          isTrue,
          reason: 'Card $i ends outside safe viewport',
        );
        expect(card.hitTestable(), findsOneWidget);
        expect(bounds.shortestSide, greaterThanOrEqualTo(40));
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('card-35')));
      await tester.pump();
      expect(
        tester.widget<MemoryCard>(find.byKey(const ValueKey('card-35'))).value,
        isNotNull,
      );
      await tester.tap(find.byTooltip('Torna alla home'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Abbandona'));
      await tester.pumpAndSettle();
      expect(find.byType(GameScreen), findsNothing);
      await tester.tap(find.byTooltip('Scegli modalità'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online'));
      await tester.pumpAndSettle();
      expect(find.text('Crea stanza').hitTestable(), findsOneWidget);
      expect(find.text('Entra con un codice').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Nome'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(
        bottom: viewport.$1.height < 500 ? 170 : 270,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Michele');
      expect(find.text('Salva').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Salva'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(find.text('Michele'), findsOneWidget);
      await tester.tap(find.text('Entra con un codice'));
      await tester.pumpAndSettle();
      tester.view.viewInsets = FakeViewPadding(
        bottom: viewport.$1.height < 500 ? 170 : 270,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'ABC123');
      expect(find.text('Entra').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Annulla'));
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Come si gioca e impostazioni'));
      await tester.pumpAndSettle();
      for (final tab in ['Regole', 'Info', 'Preferenze']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.tap(find.byTooltip('Chiudi'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Scegli modalità'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bluetooth'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continua'));
      await tester.pumpAndSettle();
      expect(find.text('Ospita partita').hitTestable(), findsOneWidget);
      expect(find.text('Cerca partita').hitTestable(), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing);
      expect(tester.takeException(), isNull);
      final online = OnlineGame(prefs)
        ..connected = true
        ..playerId = 'host'
        ..state = {
          'phase': 'waiting',
          'code': 'ABC123',
          'theme': 'garden',
          'players': [
            {'id': 'host', 'name': 'Michele', 'connected': true, 'score': 0},
          ],
        };
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            prefs: prefs,
            pairs: 18,
            theme: 'garden',
            mode: PlayMode.online,
            online: online,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('ABC123'), findsOneWidget);
      expect(find.text('Copia invito').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      online.dispose();
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets('A complete game shows results and starts a fresh board', (
    tester,
  ) async {
    configureView(tester, const Size(320, 568), const FakeViewPadding(top: 20));
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MyMemory(prefs: prefs));
    await tester.tap(find.text('Singolo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coppie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('6 coppie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Inizia partita'));
    await tester.pumpAndSettle();
    final seen = <int, List<int>>{};
    for (var i = 0; i < 12; i += 2) {
      for (final index in [i, i + 1]) {
        final card = find.byKey(ValueKey('card-$index'));
        await tester.tap(card);
        await tester.pump();
        final value = tester.widget<MemoryCard>(card).value!;
        seen.putIfAbsent(value, () => []).add(index);
      }
      await tester.pump(const Duration(seconds: 1));
    }
    for (final indices in seen.values) {
      for (final index in indices) {
        final card = find.byKey(ValueKey('card-$index'));
        if (!tester.widget<MemoryCard>(card).matched) {
          await tester.tap(card);
          await tester.pump();
        }
      }
    }
    await tester.pumpAndSettle();
    expect(find.text('Partita completata'), findsOneWidget);
    expect(prefs.getInt('best.6'), isNotNull);
    expect(find.text('Un’altra partita').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Un’altra partita'));
    await tester.pumpAndSettle();
    expect(find.text('Partita completata'), findsNothing);
    expect(
      tester
          .widgetList<MemoryCard>(find.byType(MemoryCard))
          .every((card) => card.value == null && !card.matched),
      isTrue,
    );
    await tester.pumpWidget(const SizedBox());
    debugDefaultTargetPlatformOverride = null;
  });
}

void configureView(WidgetTester tester, Size size, FakeViewPadding padding) {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = padding;
  addTearDown(() {
    debugDefaultTargetPlatformOverride = null;
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    tester.view.resetPadding();
    tester.view.resetViewInsets();
  });
}
