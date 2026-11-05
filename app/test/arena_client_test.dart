import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/game.dart';
import 'package:mymemory/game_feedback.dart';
import 'package:mymemory/main.dart';
import 'package:mymemory/online.dart';
import 'package:mymemory/economy.dart';
import 'package:mymemory/ui/arena_picker.dart';
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

  for (final size in [const Size(320, 568), const Size(390, 844)]) {
    testWidgets('online friendly arena picker and grouped shop fit $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'sound': false,
        'haptics': false,
      });
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(MyMemory(prefs: prefs));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online'));
      await tester.pumpAndSettle();
      expect(find.text('Amichevole'), findsOneWidget);
      expect(find.text('Classificata'), findsOneWidget);
      expect(find.text('Arena amichevole'), findsOneWidget);
      expect(
        find.text('3 round · 12 coppie · sfida con codice invito'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Arena amichevole'));
      await tester.pumpAndSettle();
      expect(find.byType(ArenaPicker), findsOneWidget);
      for (final name in [
        'Valle Selvaggia',
        'Baia Corallina',
        'Grande Città',
        'Frontiera Spaziale',
      ]) {
        await tester.scrollUntilVisible(
          find.text(name),
          120,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(name), findsOneWidget);
      }
      expect(
        find.text('Arena bloccata: raggiungi la soglia con le corone.'),
        findsNWidgets(3),
      );
      expect(tester.takeException(), isNull);
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Selezionata'));
      await tester.pumpAndSettle();
      expect(find.text('Arena amichevole'), findsOneWidget);

      await tester.tap(find.text('Collezione'));
      await tester.pumpAndSettle();
      for (final name in [
        'Valle Selvaggia',
        'Baia Corallina',
        'Grande Città',
        'Frontiera Spaziale',
      ]) {
        await tester.scrollUntilVisible(
          find.text(name),
          140,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text(name), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('an active ranked seat blocks creating a different room', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'sound': false,
      'haptics': false,
      'room.activeRanked': true,
      'room.code': 'ABC234',
      'room.token': 'saved-ranked-seat',
    });
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MyMemory(prefs: prefs));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Crea stanza'));
    await tester.pumpAndSettle();
    expect(find.byType(GameScreen), findsNothing);
    expect(
      find.text(
        'Riprendi o abbandona la classificata in corso prima di entrare in un’altra stanza.',
      ),
      findsOneWidget,
    );
    expect(find.text('Riprendi'), findsOneWidget);
    expect(prefs.getString('room.code'), 'ABC234');
    expect(prefs.getString('room.token'), 'saved-ranked-seat');
    expect(prefs.getBool('room.activeRanked'), isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    for (final scenario in [
      ('host', 'host', 'Chiudi lobby', <String>[]),
      ('guest', 'guest', 'Esci dalla lobby', <String>['guest']),
    ]) {
      testWidgets(
        'lobby ${scenario.$1} sees readiness and can leave at $size',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({
            'sound': false,
            'haptics': false,
          });
          final prefs = await SharedPreferences.getInstance();
          final online = _TestOnline(prefs)
            ..connected = true
            ..playerId = scenario.$2
            ..state = {
              'type': 'state',
              'code': 'ABC234',
              'phase': 'waiting',
              'lobbyMode': true,
              'lobbyReady': scenario.$4,
              'matchType': 'friendly',
              'players': [
                {'id': 'host', 'name': 'Ada', 'score': 0, 'connected': true},
                {'id': 'guest', 'name': 'Luca', 'score': 0, 'connected': true},
              ],
              'cards': <int?>[],
              'matched': <int>[],
            };
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(
                          prefs: prefs,
                          pairs: 6,
                          theme: 'garden',
                          mode: PlayMode.online,
                          online: online,
                        ),
                      ),
                    ),
                    child: const Text('Apri lobby'),
                  ),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Apri lobby'));
          await tester.pumpAndSettle();
          expect(find.text('Lobby della stanza'), findsOneWidget);
          expect(find.text('Ada · Host'), findsOneWidget);
          expect(find.text('Luca · Ospite'), findsOneWidget);
          expect(find.text('ABC234'), findsOneWidget);
          if (scenario.$1 == 'host') {
            expect(find.text('Pronto'), findsOneWidget);
            await tester.tap(find.text('Pronto'));
            expect(online.readyVotes, [true]);
          } else {
            final ready = tester.widget<FilledButton>(
              find.widgetWithText(FilledButton, 'In attesa…'),
            );
            expect(ready.onPressed, isNull);
          }
          if (scenario.$1 == 'host' && size.width > size.height) {
            await tester.tap(find.byTooltip('Torna alla home'));
          } else {
            await tester.tap(find.text(scenario.$3));
          }
          await tester.pumpAndSettle();
          expect(find.byType(GameScreen), findsNothing);
          expect(find.text('Una pausa?'), findsNothing);
          expect(online.leaveCalls, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          online.dispose();
        },
      );
    }
  }

  testWidgets('friendly arena and collection choices stay synchronized', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({
      'sound': false,
      'haptics': false,
      'game.friendlyArena': 'wild_valley',
      'game.collection': 'garden',
    });
    final prefs = await SharedPreferences.getInstance();
    final economy = _ArenaFixtureEconomy(prefs);
    await tester.pumpWidget(MyMemory(prefs: prefs, economy: economy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arena amichevole'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Grande Città'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    final cityCard = find
        .ancestor(of: find.text('Grande Città'), matching: find.byType(Card))
        .first;
    final citySelect = find.descendant(
      of: cityCard,
      matching: find.text('Scegli arena'),
    );
    expect(citySelect, findsOneWidget);
    await tester.ensureVisible(citySelect);
    await tester.pumpAndSettle();
    await tester.tap(citySelect);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Arena amichevole'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Baia Corallina'),
      120,
      scrollable: find.byType(Scrollable).first,
    );
    final bay = find
        .ancestor(of: find.text('Baia Corallina'), matching: find.byType(Card))
        .first;
    final chooseBay = find.descendant(
      of: bay,
      matching: find.text('Scegli arena'),
    );
    expect(chooseBay, findsOneWidget);
    await tester.ensureVisible(chooseBay);
    await tester.pumpAndSettle();
    await tester.tap(chooseBay);
    await tester.pumpAndSettle();
    expect(find.byType(ArenaPicker), findsNothing);
    final dynamic homeAfterArena = tester.state(find.byType(Home));
    expect(homeAfterArena.arenaId, 'coral_bay');
    expect(homeAfterArena.theme, 'ocean');
    expect(prefs.getString('game.friendlyArena'), 'coral_bay');
    expect(prefs.getString('game.collection'), 'ocean');
    expect(find.text('Baia Corallina'), findsOneWidget);
    expect(find.text('Oceano'), findsOneWidget);

    await tester.tap(find.text('Collezione'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Cibo'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Cibo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cibo'));
    await tester.pumpAndSettle();
    expect(find.text('Grande Città'), findsOneWidget);
    expect(prefs.getString('game.friendlyArena'), 'grand_city');
    expect(prefs.getString('game.collection'), 'food');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(MyMemory(prefs: prefs, economy: economy));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Online'));
    await tester.pumpAndSettle();
    expect(find.text('Grande Città'), findsOneWidget);
    expect(find.text('Cibo'), findsOneWidget);

    await tester.tap(find.text('Classificata'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        '3 round · 12 coppie. Tabelloni identici per i due giocatori: vince chi usa meno tentativi totali.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Amichevole'));
    await tester.pumpAndSettle();
    expect(find.text('Grande Città'), findsOneWidget);
    expect(find.text('Cibo'), findsOneWidget);
    expect(prefs.getString('game.friendlyArena'), 'grand_city');

    await tester.tap(find.text('Collezione'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Paola'),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Paola'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paola'));
    await tester.pumpAndSettle();
    expect(prefs.getString('game.friendlyArena'), 'grand_city');
    expect(prefs.getString('game.collection'), 'paola');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    economy.dispose();
  });

  for (final scenario in [
    ('p1', 'p1', 'Vittoria per abbandono dell’avversario.'),
    ('p2', 'p1', 'Sconfitta per abbandono.'),
  ]) {
    testWidgets('ranked forfeit explains ${scenario.$3}', (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'sound': false,
        'haptics': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final online = _TestOnline(prefs)
        ..connected = true
        ..playerId = scenario.$1
        ..state = _rankedState(
          phase: 'finished',
          round: 2,
          roundId: 'forfeit-round',
          theme: 'food',
          matchedCount: 24,
          scores: {'p1': 12, 'p2': 5},
          totals: {'p1': 17, 'p2': 10},
          results: [
            {
              'round': 1,
              'theme': 'garden',
              'scores': {'p1': 12, 'p2': 5},
              'winnerId': 'p1',
            },
          ],
          winnerId: scenario.$2,
          finishReason: 'forfeit',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            prefs: prefs,
            pairs: 12,
            theme: 'food',
            mode: PlayMode.online,
            online: online,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(scenario.$1 == scenario.$2 ? 'Hai vinto!' : 'Hai perso'),
        findsOneWidget,
      );
      expect(find.text(scenario.$3), findsOneWidget);
      expect(find.textContaining('Totale:'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      online.dispose();
    });
  }

  testWidgets(
    'ranked last pair settles before intermission and next round theme',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TestWidgetsFlutterBinding
          .instance
          .platformDispatcher
          .accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(
        disableAnimations: false,
      );
      addTearDown(
        () => TestWidgetsFlutterBinding.instance.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );
      SharedPreferences.setMockInitialValues({'sound': true, 'haptics': false});
      final prefs = await SharedPreferences.getInstance();
      final audio = _RecordingAudio();
      final feedback = GameFeedback(
        prefs,
        audio: audio,
        haptics: _RecordingHaptics(),
      );
      final online = _TestOnline(prefs)
        ..connected = true
        ..playerId = 'p1'
        ..state = _rankedState(
          phase: 'playing',
          round: 1,
          roundId: 'r1',
          theme: 'garden',
          matchedCount: 22,
          scores: {'p1': 11, 'p2': 8},
          totals: {'p1': 11, 'p2': 8},
          results: const [],
        );
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            prefs: prefs,
            pairs: 12,
            theme: 'garden',
            mode: PlayMode.online,
            online: online,
            feedback: feedback,
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('Round 1 di 3'), findsOneWidget);
      expect(find.text('Animali'), findsOneWidget);

      online.state = _rankedState(
        phase: 'roundFinished',
        round: 1,
        roundId: 'r1',
        theme: 'garden',
        matchedCount: 24,
        scores: {'p1': 12, 'p2': 8},
        totals: {'p1': 12, 'p2': 8},
        results: [
          {
            'round': 1,
            'theme': 'garden',
            'scores': {'p1': 12, 'p2': 8},
            'winnerId': 'p1',
          },
        ],
      );
      online.pushState(online.state!);
      await tester.pump();
      expect(find.text('Round 1 completato'), findsNothing);

      // The opponent has already voted, so the next round arrives before this
      // device finishes the last pair's flip animation.
      online.state = _rankedState(
        phase: 'playing',
        round: 2,
        roundId: 'r2',
        theme: 'food',
        matchedCount: 0,
        scores: {'p1': 0, 'p2': 0},
        totals: {'p1': 12, 'p2': 8},
        results: [
          {
            'round': 1,
            'theme': 'garden',
            'scores': {'p1': 12, 'p2': 8},
            'winnerId': 'p1',
          },
        ],
      );
      online.pushState(online.state!);
      await tester.pump();
      expect(find.text('Animali'), findsOneWidget);
      expect(find.text('Cibo'), findsNothing);
      await tester.pump(const Duration(milliseconds: 120));
      expect(find.text('Round 1 completato'), findsNothing);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump();
      expect(find.text('Round 1 completato'), findsNWidgets(2));
      expect(find.textContaining('Tentativi totali: 34 – 31'), findsOneWidget);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Round 2 di 3'), findsOneWidget);
      expect(find.text('Cibo'), findsOneWidget);
      expect(find.text('Round 1 completato'), findsNothing);
      await feedback.settled;
      expect(audio.events, contains(GameFeedbackEvent.flip));
      expect(audio.events, contains(GameFeedbackEvent.match));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      feedback.dispose();
      online.dispose();
    },
  );

  testWidgets(
    'ranked final screen uses aggregate winner, rounds, and receipt',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({
        'sound': false,
        'haptics': false,
      });
      final prefs = await SharedPreferences.getInstance();
      final online = _TestOnline(prefs)
        ..connected = true
        ..playerId = 'p1'
        ..state = _rankedState(
          phase: 'finished',
          round: 3,
          roundId: 'r3',
          theme: 'sports',
          matchedCount: 24,
          scores: {'p1': 7, 'p2': 5},
          totals: {'p1': 34, 'p2': 31},
          results: [
            {
              'round': 1,
              'theme': 'garden',
              'scores': {'p1': 12, 'p2': 8},
              'winnerId': 'p1',
            },
            {
              'round': 2,
              'theme': 'food',
              'scores': {'p1': 15, 'p2': 18},
              'winnerId': 'p2',
            },
            {
              'round': 3,
              'theme': 'sports',
              'scores': {'p1': 7, 'p2': 5},
              'winnerId': 'p1',
            },
          ],
          rewards: {
            'p1': {'gems': 20, 'granted': true, 'crownsDelta': 20},
          },
          winnerId: 'p1',
        );
      await tester.pumpWidget(
        MaterialApp(
          home: GameScreen(
            prefs: prefs,
            pairs: 12,
            theme: 'sports',
            mode: PlayMode.online,
            online: online,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hai vinto!'), findsOneWidget);
      expect(find.textContaining('Tentativi totali: 34 – 31'), findsOneWidget);
      expect(find.textContaining('Round 3 · Sport ·'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      online.dispose();
    },
  );
}

class _TestOnline extends OnlineGame {
  _TestOnline(super.prefs);
  final List<bool> readyVotes = [];
  int leaveCalls = 0;
  @override
  void ready(bool value) => readyVotes.add(value);
  @override
  Future<void> leave() async => leaveCalls++;
  void pushState(Map<String, dynamic> value) {
    state = value;
    notifyListeners();
  }
}

Map<String, dynamic> _rankedState({
  required String phase,
  required int round,
  required String roundId,
  required String theme,
  required int matchedCount,
  required Map<String, int> scores,
  required Map<String, int> totals,
  required List<Map<String, dynamic>> results,
  Map<String, dynamic> rewards = const {},
  String? winnerId,
  String? finishReason,
}) {
  final matched = List.generate(matchedCount, (index) => index);
  final cards = List<int?>.generate(
    24,
    (index) => index < matchedCount ? index ~/ 2 : null,
  );
  return {
    'type': 'state',
    'code': 'ABC234',
    'phase': phase,
    'pairs': 12,
    'theme': theme,
    'roundId': roundId,
    'matchId': 'match-1',
    'matchType': 'ranked',
    'arenaId': 'wild_valley',
    'roundIndex': round,
    'roundCount': 3,
    'roundDecks': ['garden', 'food', 'sports'],
    'roundResults': results,
    'totalScores': totals,
    'totalAttempts': {'p1': 34, 'p2': 31},
    'roundReady': phase == 'roundFinished' ? ['p2'] : <String>[],
    'rewards': rewards,
    'cards': cards,
    'matched': matched,
    'selected': <int>[],
    'turn': phase == 'playing' ? 'p1' : null,
    'winnerId': winnerId,
    'finishReason': phase == 'finished' ? finishReason ?? 'completed' : null,
    'lockedUntil': null,
    'rematch': <String>[],
    'players': [
      {
        'id': 'p1',
        'name': 'Michele',
        'score': scores['p1'],
        'attempts': 12,
        'roundComplete': phase != 'playing',
        'connected': true,
      },
      {
        'id': 'p2',
        'name': 'Paola',
        'score': scores['p2'],
        'attempts': 12,
        'roundComplete': phase != 'playing',
        'connected': true,
      },
    ],
  };
}

class _RecordingAudio implements GameFeedbackAudio {
  final List<GameFeedbackEvent> events = [];
  @override
  Future<void> unlock() async {}
  @override
  Future<void> play(GameFeedbackEvent event) async => events.add(event);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _RecordingHaptics implements GameFeedbackHaptics {
  @override
  Future<void> play(GameFeedbackEvent event) async {}
}

class _ArenaFixtureEconomy extends EconomyController {
  _ArenaFixtureEconomy(SharedPreferences prefs) : super(prefs: prefs);

  final fixture = ProfileData(
    id: 'arena-fixture',
    displayName: 'Michele',
    activated: false,
    gems: 500,
    ownedDecks: {
      ...ProfileData.freeDecks,
      'ocean',
      'beach',
      'navigation',
      'vehicles',
      'professions',
      'instruments',
      'food',
    },
    revision: 1,
    crowns: 100,
    peakCrowns: 300,
  );

  @override
  ProfileData? get profile => fixture;
  @override
  int get gems => fixture.gems;
  @override
  Set<String> get ownedDecks => fixture.ownedDecks;
  @override
  String? get profileToken => 'arena-fixture-token';
  @override
  bool get offline => false;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> refresh() async {}
}
