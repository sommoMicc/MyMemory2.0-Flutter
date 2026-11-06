import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/bluetooth/bluetooth_controller.dart';
import 'package:mymemory/game.dart';
import 'package:mymemory/game_feedback.dart';
import 'package:mymemory/main.dart';
import 'package:mymemory/online.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding
        .instance
        .platformDispatcher
        .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
      disableAnimations: false,
    );
    SharedPreferences.setMockInitialValues({'ui.language': 'it'});
  });
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher
        .clearAccessibilityFeaturesTestValue();
  });

  Future<void> finishFlip(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 320));
    await tester.pump();
  }

  testWidgets('Local feedback follows accepted flips and settled outcomes', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final feedback = _RecordingFeedback(prefs);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        supportedLocales: const [Locale('it'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: GameScreen(
          prefs: prefs,
          pairs: 6,
          theme: 'garden',
          mode: PlayMode.local,
          feedback: feedback,
        ),
      ),
    );
    final dynamic screen = tester.state(find.byType(GameScreen));
    final game = screen.local as LocalGame;
    final first = 0;
    final partner = game.deck.lastIndexOf(game.deck[first]);
    await tester.tap(find.byKey(ValueKey('card-$first')));
    await tester.pump();
    expect(feedback.events, [GameFeedbackEvent.flip]);
    await finishFlip(tester);
    await tester.tap(find.byKey(ValueKey('card-$partner')));
    await tester.pump();
    expect(feedback.events, [GameFeedbackEvent.flip, GameFeedbackEvent.flip]);
    await tester.pump(const Duration(milliseconds: 319));
    expect(feedback.events.last, GameFeedbackEvent.flip);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(feedback.events.last, GameFeedbackEvent.match);
    final a = List.generate(
      12,
      (i) => i,
    ).firstWhere((i) => !game.matched.contains(i));
    final b = List.generate(12, (i) => i).firstWhere(
      (i) => !game.matched.contains(i) && game.deck[i] != game.deck[a],
    );
    await tester.tap(find.byKey(ValueKey('card-$a')));
    await tester.pump();
    await finishFlip(tester);
    await tester.tap(find.byKey(ValueKey('card-$b')));
    await tester.pump();
    expect(feedback.events.last, GameFeedbackEvent.flip);
    await finishFlip(tester);
    expect(feedback.events.last, GameFeedbackEvent.mismatch);
    await tester.pump(const Duration(milliseconds: 580));
    expect(feedback.events.last, GameFeedbackEvent.mismatch);
    await tester.pump(const Duration(milliseconds: 319));
    expect(feedback.events.last, GameFeedbackEvent.mismatch);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(feedback.events.last, GameFeedbackEvent.turn);
    expect(
      feedback.events.where((e) => e == GameFeedbackEvent.match).length,
      1,
    );
    expect(
      feedback.events.where((e) => e == GameFeedbackEvent.mismatch).length,
      1,
    );
    expect(feedback.events.where((e) => e == GameFeedbackEvent.turn).length, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final bluetooth in [false, true]) {
    testWidgets(
      '${bluetooth ? 'BLE' : 'Online'} feedback does not replay snapshots and waits for closing',
      (tester) async {
        final prefs = await SharedPreferences.getInstance();
        final feedback = _RecordingFeedback(prefs);
        final online = _Online(prefs);
        final ble = _Bluetooth();
        void publish(Map<String, dynamic> frame) =>
            bluetooth ? ble.publish(frame) : online.publish(frame);
        final empty = List<int?>.filled(12, null);
        publish(_frame(empty));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            supportedLocales: const [Locale('it'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: GameScreen(
              prefs: prefs,
              pairs: 6,
              theme: 'garden',
              mode: bluetooth ? PlayMode.bluetooth : PlayMode.online,
              online: bluetooth ? null : online,
              bluetooth: bluetooth ? ble : null,
              feedback: feedback,
            ),
          ),
        );
        expect(feedback.events, isEmpty);
        publish(_frame([0, ...empty.skip(1)]));
        await tester.pump();
        await finishFlip(tester);
        final mismatch = _frame([0, 1, ...empty.skip(2)]);
        publish(mismatch);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        publish(_frame(empty, turn: 'guest'));
        await tester.pump();
        expect(feedback.events, [
          GameFeedbackEvent.flip,
          GameFeedbackEvent.flip,
        ]);
        await tester.pump(const Duration(milliseconds: 220));
        await tester.pump();
        expect(feedback.events.last, GameFeedbackEvent.mismatch);
        await tester.pump(const Duration(milliseconds: 319));
        expect(feedback.events.last, GameFeedbackEvent.mismatch);
        await tester.pump(const Duration(milliseconds: 1));
        await tester.pump();
        expect(feedback.events.last, GameFeedbackEvent.turn);
        final settled = List.of(feedback.events);
        publish(_frame(empty, turn: 'guest'));
        await tester.pump();
        expect(feedback.events, settled);
        // Recreating the screen with an already-finished state is a silent baseline.
        await tester.pumpWidget(const SizedBox());
        publish(_frame([0, 0, ...empty.skip(2)], matched: [0, 1]));
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('it'),
            supportedLocales: const [Locale('it'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            home: GameScreen(
              prefs: prefs,
              pairs: 6,
              theme: 'garden',
              mode: bluetooth ? PlayMode.bluetooth : PlayMode.online,
              online: bluetooth ? null : online,
              bluetooth: bluetooth ? ble : null,
              feedback: feedback,
            ),
          ),
        );
        await tester.pump();
        expect(feedback.events, settled);
        await tester.pumpWidget(const SizedBox());
        online.dispose();
        ble.dispose();
      },
    );
  }

  testWidgets(
    'Background revisions stay silent and a fresh tap unlocks feedback',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final feedback = _RecordingFeedback(prefs);
      final online = _Online(prefs);
      final empty = List<int?>.filled(12, null);
      online.publish(_frame(empty));
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('it'),
          supportedLocales: const [Locale('it'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: GameScreen(
            prefs: prefs,
            pairs: 6,
            theme: 'garden',
            mode: PlayMode.online,
            online: online,
            feedback: feedback,
          ),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      online.publish(_frame([0, 0, ...empty.skip(2)], matched: [0, 1]));
      await tester.pump();
      await finishFlip(tester);
      expect(feedback.events, isEmpty);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byKey(const ValueKey('card-2')));
      expect(feedback.unlocks, 1);
      online.publish(_frame([0, 0, 1, ...empty.skip(3)], matched: [0, 1]));
      await tester.pump();
      await finishFlip(tester);
      expect(feedback.events, [GameFeedbackEvent.flip]);
      await tester.pumpWidget(const SizedBox());
      online.dispose();
    },
  );
}

class _RecordingFeedback extends GameFeedback {
  _RecordingFeedback(super.prefs);
  final events = <GameFeedbackEvent>[];
  int unlocks = 0;
  bool active = true;
  @override
  void play(GameFeedbackEvent event) {
    if (active) events.add(event);
  }

  @override
  void unlock() {
    unlocks++;
  }

  @override
  void setActive(bool value) {
    active = value;
  }

  @override
  void dispose() {}
}

class _Online extends OnlineGame {
  _Online(super.prefs) {
    playerId = 'host';
    connected = true;
  }
  void publish(Map<String, dynamic> frame) {
    state = frame;
    notifyListeners();
  }

  @override
  void flip(int index) {}
}

class _Bluetooth extends BluetoothController {
  _Bluetooth() {
    playerId = 'host';
  }
  @override
  bool get connected => true;
  void publish(Map<String, dynamic> frame) {
    state = frame;
    notifyListeners();
  }
}

Map<String, dynamic> _frame(
  List<int?> cards, {
  String turn = 'host',
  List<int> matched = const [],
}) => {
  'phase': 'playing',
  'roundId': 'one',
  'theme': 'garden',
  'cards': cards,
  'matched': matched,
  'turn': turn,
  'players': [
    {
      'id': 'host',
      'name': 'Tu',
      'score': matched.length ~/ 2,
      'connected': true,
    },
    {'id': 'guest', 'name': 'Amico', 'score': 0, 'connected': true},
  ],
};
