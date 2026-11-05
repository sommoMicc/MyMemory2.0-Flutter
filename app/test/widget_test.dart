import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/main.dart';
import 'package:mymemory/game.dart';
import 'package:mymemory/bluetooth/bluetooth_controller.dart';
import 'package:mymemory/online.dart';
import 'package:mymemory/ui/game_world.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: true,
    );
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });
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
      await tester.tap(find.text('Collezione'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oceano'));
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

  for (final viewport in viewports) {
    testWidgets('Every difficulty uses complete rows at ${viewport.$1}', (
      tester,
    ) async {
      configureView(tester, viewport.$1, viewport.$2);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      for (final pairs in [6, 8, 12, 18]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Outfit'),
            home: GameScreen(
              key: ValueKey(pairs),
              prefs: prefs,
              pairs: pairs,
              theme: 'garden',
              mode: PlayMode.solo,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final rows = <int, int>{};
        for (var i = 0; i < pairs * 2; i++) {
          final card = find.byKey(ValueKey('card-$i'));
          final rect = tester.getRect(card);
          rows.update(rect.top.round(), (n) => n + 1, ifAbsent: () => 1);
          expect(card.hitTestable(), findsOneWidget);
          expect(rect.shortestSide, greaterThanOrEqualTo(40));
          expect(
            rect.bottom,
            lessThanOrEqualTo(viewport.$1.height - viewport.$2.bottom),
          );
        }
        expect(
          rows.values.toSet().length,
          1,
          reason:
              '$pairs pairs must have the same number of cards in every row',
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    });
  }

  testWidgets(
    'Cards turn in 3D, keep their face while closing, and ignore repeat taps',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      int? value;
      var taps = 0;
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return Center(
                child: SizedBox(
                  width: 100,
                  height: 112,
                  child: MemoryCard(
                    index: 0,
                    value: value,
                    theme: 'garden',
                    matched: false,
                    onTap: () {
                      taps++;
                      change(() => value = 0);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.byType(MemoryCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      final transform = tester
          .widget<Transform>(find.byKey(const ValueKey('flip-0')))
          .transform;
      expect(transform.entry(0, 0), greaterThan(-1));
      expect(transform.entry(0, 0), lessThan(1));
      expect(transform.entry(3, 2), isNot(0));
      expect(find.byType(Image), findsNothing);
      await tester.tap(find.byType(MemoryCard));
      expect(taps, 1);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsOneWidget);
      change(() => value = null);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(find.byType(Image), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.byType(Image), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Reduced motion reveals the card without a flip', (tester) async {
    int? value;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: StatefulBuilder(
            builder: (context, change) => Center(
              child: SizedBox(
                width: 100,
                height: 112,
                child: MemoryCard(
                  index: 0,
                  value: value,
                  theme: 'garden',
                  matched: false,
                  onTap: () => change(() => value = 0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(MemoryCard));
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(
      tester
          .widget<Transform>(find.byKey(const ValueKey('flip-0')))
          .transform
          .entry(0, 0),
      closeTo(-1, .001),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'World fills the viewport and stops motion when paused or reduced',
    (tester) async {
      configureView(
        tester,
        const Size(390, 844),
        const FakeViewPadding(top: 59, bottom: 34),
      );
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      await tester.pumpWidget(
        const MaterialApp(
          home: GameWorld(collection: 'ocean', child: SizedBox.expand()),
        ),
      );
      final world = find.byType(GameWorld);
      expect(tester.getRect(world), const Rect.fromLTWH(0, 0, 390, 844));
      double floatOffset() => tester
          .widget<Transform>(find.byKey(const ValueKey('world-float')))
          .transform
          .entry(1, 3);
      final before = floatOffset();
      await tester.pump(const Duration(seconds: 1));
      expect(floatOffset(), isNot(before));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      final paused = floatOffset();
      await tester.pump(const Duration(seconds: 1));
      expect(floatOffset(), paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(floatOffset(), isNot(paused));
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();
      final reduced = floatOffset();
      await tester.pump(const Duration(seconds: 1));
      expect(floatOffset(), reduced);
      await tester.pumpWidget(const SizedBox());
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'A local mismatch blocks the whole board through the closing flip',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Outfit'),
          home: GameScreen(
            prefs: prefs,
            pairs: 6,
            theme: 'garden',
            mode: PlayMode.solo,
          ),
        ),
      );
      final dynamic screen = tester.state(find.byType(GameScreen));
      final game = screen.local as LocalGame;
      // Choose a deterministic mismatch from the shuffled deck; all input remains UI taps.
      final second = game.deck.indexWhere((value) => value != game.deck[0]);
      final third = List.generate(
        12,
        (i) => i,
      ).firstWhere((i) => i != 0 && i != second);
      final thirdCard = find.byKey(ValueKey('card-$third'));
      final queuedTap = tester.widget<MemoryCard>(thirdCard).onTap!;
      await tester.tap(find.byKey(const ValueKey('card-0')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('card-$second')));
      await tester.pump();
      await tester.tap(thirdCard);
      queuedTap();
      expect(game.moves, 1);
      expect(game.selected, [0, second]);
      expect(tester.widget<MemoryCard>(thirdCard).onTap, isNull);
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      expect(game.locked, isFalse);
      expect(game.selected, isEmpty);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('card-0')),
          matching: find.byType(Image),
        ),
        findsOneWidget,
      );
      queuedTap();
      expect(
        game.selected,
        isEmpty,
        reason: 'A queued callback must not bypass the closing animation gate',
      );
      await tester.pump(const Duration(milliseconds: 160));
      await tester.tap(thirdCard);
      queuedTap();
      expect(game.selected, isEmpty);
      expect(game.moves, 1);
      await tester.pump(const Duration(milliseconds: 159));
      queuedTap();
      expect(game.selected, isEmpty);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(tester.widget<MemoryCard>(thirdCard).onTap, isNotNull);
      await tester.tap(thirdCard);
      await tester.pump();
      expect(game.selected, [third]);
      expect(tester.widget<MemoryCard>(thirdCard).value, isNotNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Reduced motion releases a mismatch as soon as its faces are hidden',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Outfit'),
          home: GameScreen(
            prefs: prefs,
            pairs: 6,
            theme: 'garden',
            mode: PlayMode.solo,
          ),
        ),
      );
      final dynamic screen = tester.state(find.byType(GameScreen));
      final game = screen.local as LocalGame;
      final second = game.deck.indexWhere((value) => value != game.deck[0]);
      final third = List.generate(
        12,
        (i) => i,
      ).firstWhere((i) => i != 0 && i != second);
      await tester.tap(find.byKey(const ValueKey('card-0')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('card-$second')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('card-$third')));
      await tester.pump();
      expect(game.selected, [third]);
      expect(game.moves, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final bluetooth in [false, true]) {
    testWidgets(
      '${bluetooth ? 'Bluetooth' : 'Online'} sends no third flip until both cards finish closing',
      (tester) async {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final online = _RecordingOnline(prefs);
        final ble = _RecordingBluetooth();
        final attempts = bluetooth ? ble.attempts : online.attempts;
        void publish(List<int?> cards, {bool locked = false}) {
          final state = <String, dynamic>{
            'phase': 'playing',
            'theme': 'garden',
            'cards': cards,
            'matched': <int>[],
            'turn': 'host',
            'lockedUntil': locked ? 999999 : null,
            'players': [
              {'id': 'host', 'name': 'Tu', 'score': 0, 'connected': true},
              {'id': 'guest', 'name': 'Ospite', 'score': 0, 'connected': true},
            ],
          };
          if (bluetooth) {
            ble.publish(state);
          } else {
            online.publish(state);
          }
        }

        publish(List<int?>.filled(12, null));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Outfit'),
            home: GameScreen(
              prefs: prefs,
              pairs: 6,
              theme: 'garden',
              mode: bluetooth ? PlayMode.bluetooth : PlayMode.online,
              online: bluetooth ? null : online,
              bluetooth: bluetooth ? ble : null,
            ),
          ),
        );
        final third = find.byKey(const ValueKey('card-2'));
        final queuedTap = tester.widget<MemoryCard>(third).onTap!;
        await tester.tap(find.byKey(const ValueKey('card-0')));
        publish([0, ...List<int?>.filled(11, null)]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 320));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('card-1')));
        publish([0, 1, ...List<int?>.filled(10, null)], locked: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        await tester.tap(third);
        queuedTap();
        expect(attempts, [0, 1]);
        publish(List<int?>.filled(12, null));
        await tester.pump();
        queuedTap();
        expect(attempts, [0, 1]);
        await tester.pump(const Duration(milliseconds: 160));
        expect(tester.widget<MemoryCard>(third).onTap, isNull);
        await tester.tap(third);
        queuedTap();
        expect(attempts, [0, 1]);
        await tester.pump(const Duration(milliseconds: 159));
        queuedTap();
        expect(attempts, [0, 1]);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(tester.widget<MemoryCard>(third).onTap, isNotNull);
        await tester.tap(third);
        expect(attempts, [0, 1, 2]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        online.dispose();
        ble.dispose();
      },
    );
  }

  testWidgets(
    'A remote reveal waits for the closing cards and finishes before the board unlocks',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final online = _RecordingOnline(prefs);
      void publish(List<int?> cards, {bool locked = false}) => online.publish({
        'phase': 'playing',
        'theme': 'garden',
        'cards': cards,
        'matched': <int>[],
        'turn': 'host',
        'lockedUntil': locked ? 999999 : null,
        'players': [
          {'id': 'host', 'name': 'Tu', 'score': 0, 'connected': true},
          {'id': 'guest', 'name': 'Ospite', 'score': 0, 'connected': true},
        ],
      });
      publish([0, 1, ...List<int?>.filled(10, null)], locked: true);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Outfit'),
          home: GameScreen(
            prefs: prefs,
            pairs: 6,
            theme: 'garden',
            mode: PlayMode.online,
            online: online,
          ),
        ),
      );
      publish(List<int?>.filled(12, null));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // The other device can already have reduced-motion cards hidden and act.
      publish([0, ...List<int?>.filled(11, null)]);
      await tester.pump();
      await tester.pump();
      final third = find.byKey(const ValueKey('card-2'));
      expect(
        tester.widget<MemoryCard>(third).onTap,
        isNull,
        reason: 'The second mismatch card is still closing',
      );
      await tester.tap(third);
      expect(online.attempts, isEmpty);
      await tester.pump(const Duration(milliseconds: 219));
      expect(tester.widget<MemoryCard>(third).onTap, isNull);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(
        tester.widget<MemoryCard>(third).onTap,
        isNull,
        reason: 'The queued reveal must complete its own opening',
      );
      await tester.pump(const Duration(milliseconds: 320));
      await tester.pump();
      expect(tester.widget<MemoryCard>(third).onTap, isNotNull);
      await tester.tap(third);
      expect(online.attempts, [2]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      online.dispose();
    },
  );

  testWidgets(
    'Local match, score and final result wait for the last opening flip',
    (tester) async {
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Outfit'),
          home: GameScreen(
            prefs: prefs,
            pairs: 6,
            theme: 'garden',
            mode: PlayMode.local,
          ),
        ),
      );
      final dynamic screen = tester.state(find.byType(GameScreen));
      final game = screen.local as LocalGame;
      final pairs = <int, List<int>>{};
      for (var i = 0; i < game.deck.length; i++) {
        pairs.putIfAbsent(game.deck[i], () => []).add(i);
      }
      var completed = 0;
      for (final indices in pairs.values) {
        await tester.tap(find.byKey(ValueKey('card-${indices[0]}')));
        await tester.pump();
        expect(
          tester
              .widget<MemoryCard>(find.byKey(ValueKey('card-${indices[1]}')))
              .onTap,
          isNull,
          reason: 'A new action waits until the first card is fully open',
        );
        await tester.pump(const Duration(milliseconds: 320));
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('card-${indices[1]}')));
        await tester.pump();
        expect(game.scores[0], completed + 1); // Authority is unchanged.
        expect(playerScore(tester, 'GIOCATORE 1'), '$completed');
        expect(
          tester
              .widget<MemoryCard>(find.byKey(ValueKey('card-${indices[0]}')))
              .matched,
          isFalse,
        );
        expect(
          tester
              .widget<MemoryCard>(find.byKey(ValueKey('card-${indices[1]}')))
              .matched,
          isFalse,
        );
        expect(find.text('Vince Giocatore 1!'), findsNothing);
        await tester.pump(const Duration(milliseconds: 319));
        expect(playerScore(tester, 'GIOCATORE 1'), '$completed');
        expect(find.text('Vince Giocatore 1!'), findsNothing);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        completed++;
        expect(playerScore(tester, 'GIOCATORE 1'), '$completed');
        expect(
          tester
              .widget<MemoryCard>(find.byKey(ValueKey('card-${indices[1]}')))
              .matched,
          isTrue,
        );
      }
      expect(find.text('Vince Giocatore 1!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final bluetooth in [false, true]) {
    testWidgets(
      '${bluetooth ? 'Bluetooth' : 'Online'} queues early revisions and applies events only after the corresponding flip',
      (tester) async {
        tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
            const FakeAccessibilityFeatures(disableAnimations: false);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final online = _RecordingOnline(prefs);
        final ble = _RecordingBluetooth();
        void publish(Map<String, dynamic> frame) {
          if (bluetooth) {
            ble.publish(frame);
          } else {
            online.publish(frame);
          }
        }

        final empty = List<int?>.filled(12, null);
        publish(presentationFrame(empty));
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(fontFamily: 'Outfit'),
            home: GameScreen(
              prefs: prefs,
              pairs: 6,
              theme: 'garden',
              mode: bluetooth ? PlayMode.bluetooth : PlayMode.online,
              online: bluetooth ? null : online,
              bluetooth: bluetooth ? ble : null,
            ),
          ),
        );
        publish(presentationFrame([0, ...empty.skip(1)]));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final matched = [0, 0, ...empty.skip(2)];
        final matchRevision = presentationFrame(
          matched,
          matched: [0, 1],
          score: 1,
        );
        publish(matchRevision);
        publish(
          matchRevision,
        ); // Repeated Bluetooth/network heartbeat must not replay events.
        await tester.pump();
        expect(
          tester.widget<MemoryCard>(find.byKey(const ValueKey('card-1'))).value,
          isNull,
        );
        expect(playerScore(tester, 'Tu · TU'), '0');
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pump();
        expect(
          tester.widget<MemoryCard>(find.byKey(const ValueKey('card-1'))).value,
          0,
        );
        expect(playerScore(tester, 'Tu · TU'), '0');
        await tester.pump(const Duration(milliseconds: 319));
        expect(playerScore(tester, 'Tu · TU'), '0');
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(playerScore(tester, 'Tu · TU'), '1');
        expect(
          tester
              .widget<MemoryCard>(find.byKey(const ValueKey('card-1')))
              .matched,
          isTrue,
        );
        // Incoming conceal precedes the end of even the first opening animation.
        publish(
          presentationFrame(
            [0, 0, 1, ...empty.skip(3)],
            matched: [0, 1],
            score: 1,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        publish(
          presentationFrame(
            [0, 0, 1, 2, ...empty.skip(4)],
            matched: [0, 1],
            score: 1,
            locked: true,
          ),
        );
        publish(
          presentationFrame(matched, matched: [0, 1], score: 1, turn: 'guest'),
        );
        publish(
          presentationFrame(matched, matched: [0, 1], score: 1, turn: 'guest'),
        );
        await tester.pump();
        expect(
          tester.widget<MemoryCard>(find.byKey(const ValueKey('card-2'))).value,
          1,
        );
        expect(find.text('Il tuo turno'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pump();
        expect(
          tester.widget<MemoryCard>(find.byKey(const ValueKey('card-3'))).value,
          2,
        );
        expect(find.text('Il tuo turno'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 320));
        await tester.pump();
        expect(
          tester.widget<MemoryCard>(find.byKey(const ValueKey('card-2'))).value,
          isNull,
        );
        expect(
          find.text('Il tuo turno'),
          findsOneWidget,
          reason: 'Turn change waits for both reverse flips',
        );
        await tester.pump(const Duration(milliseconds: 319));
        expect(find.text('Il tuo turno'), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(find.text('Turno di Ospite'), findsOneWidget);
        publish(presentationFrame(matched, matched: [0, 1], score: 1));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('card-4')));
        expect(bluetooth ? ble.attempts : online.attempts, [4]);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        online.dispose();
        ble.dispose();
      },
    );
  }

  testWidgets(
    'Rotation plus reveal and a new round cannot strand presentation or replay stale actions',
    (tester) async {
      configureView(
        tester,
        const Size(390, 844),
        const FakeViewPadding(top: 59, bottom: 34),
      );
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: false);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final online = _RecordingOnline(prefs);
      final cards = List<int?>.filled(36, null);
      online.publish(presentationFrame(cards));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Outfit'),
          home: GameScreen(
            prefs: prefs,
            pairs: 18,
            theme: 'garden',
            mode: PlayMode.online,
            online: online,
          ),
        ),
      );
      final staleTap = tester
          .widget<MemoryCard>(find.byKey(const ValueKey('card-0')))
          .onTap!;
      cards[20] = 0;
      online.publish(presentationFrame(cards));
      tester.view.physicalSize = const Size(844, 390);
      tester.view.padding = const FakeViewPadding(
        left: 44,
        right: 44,
        bottom: 21,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 640));
      await tester.pump();
      expect(
        tester.widget<MemoryCard>(find.byKey(const ValueKey('card-0'))).onTap,
        isNotNull,
      );
      await tester.tap(find.byKey(const ValueKey('card-0')));
      expect(online.attempts, [0]);
      cards[21] = 0;
      online.publish(
        presentationFrame(cards, matched: [20, 21], score: 1, finished: true),
      );
      await tester.pump();
      online.publish(presentationFrame(List<int?>.filled(36, null)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 640));
      await tester.pump();
      expect(find.text('Hai vinto!'), findsNothing);
      expect(playerScore(tester, 'Tu · TU'), '0');
      staleTap();
      expect(
        online.attempts,
        [0],
        reason:
            'An action captured before round reset must not reach the new round',
      );
      await tester.tap(find.byKey(const ValueKey('card-0')));
      expect(online.attempts, [0, 0]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      online.dispose();
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('Collection and difficulty survive reopening the app', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MyMemory(prefs: prefs));
    await tester.tap(find.text('Singolo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coppie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('12 coppie'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Collezione'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Spazio'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MyMemory(prefs: prefs));
    await tester.tap(find.text('Singolo'));
    await tester.pumpAndSettle();
    expect(find.text('12'), findsOneWidget);
    expect(find.text('Spazio'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

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
      await tester.pumpAndSettle();
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

class _RecordingOnline extends OnlineGame {
  _RecordingOnline(super.prefs) {
    playerId = 'host';
    connected = true;
  }
  final attempts = <int>[];
  @override
  void flip(int index) => attempts.add(index);
  void publish(Map<String, dynamic> value) {
    state = value;
    notifyListeners();
  }
}

class _RecordingBluetooth extends BluetoothController {
  _RecordingBluetooth() {
    playerId = 'host';
  }
  final attempts = <int>[];
  @override
  bool get connected => true;
  @override
  Future<void> flip(int index) async {
    attempts.add(index);
  }

  void publish(Map<String, dynamic> value) {
    state = value;
    notifyListeners();
  }
}

String playerScore(WidgetTester tester, String label) => tester
    .widgetList<StatBox>(find.byType(StatBox))
    .singleWhere((box) => box.label == label)
    .value;

Map<String, dynamic> presentationFrame(
  List<int?> cards, {
  List<int> matched = const [],
  int score = 0,
  String turn = 'host',
  bool locked = false,
  bool finished = false,
}) => {
  'phase': finished ? 'finished' : 'playing',
  'theme': 'garden',
  'cards': cards,
  'matched': matched,
  'turn': turn,
  'lockedUntil': locked ? 999999 : null,
  'winnerId': finished ? 'host' : null,
  'players': [
    {'id': 'host', 'name': 'Tu', 'score': score, 'connected': true},
    {'id': 'guest', 'name': 'Ospite', 'score': 0, 'connected': true},
  ],
};
