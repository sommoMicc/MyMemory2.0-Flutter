import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/economy.dart';
import 'package:mymemory/game.dart';
import 'package:mymemory/game_feedback.dart';
import 'package:mymemory/main.dart';
import 'package:mymemory/online.dart';
import 'package:mymemory/ui/deck_art.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RankedOnline extends OnlineGame {
  _RankedOnline(super.prefs) {
    playerId = 'host';
    connected = true;
  }
  int nextVotes = 0;
  void publish(Map<String, dynamic> snapshot) {
    state = snapshot;
    notifyListeners();
  }

  @override
  void nextRound() => nextVotes++;
}

class _RankedEconomy extends EconomyController {
  _RankedEconomy(SharedPreferences prefs) : super(prefs: prefs);
  int refreshes = 0;
  @override
  int get gems => 120;
  @override
  bool get offline => false;
  @override
  Future<void> refresh() async {
    refreshes++;
  }
}

class _QuietFeedback extends GameFeedback {
  _QuietFeedback(super.prefs);
  @override
  void play(GameFeedbackEvent event) {}
  @override
  void unlock() {}
  @override
  void setActive(bool value) {}
  @override
  void dispose() {}
}

const _themes = ['garden', 'farm', 'flora'];
Map<String, dynamic> _rankedFrame({
  int round = 1,
  String phase = 'playing',
  Map<String, dynamic>? receipt,
  List<String> ready = const [],
  int hostAttempts = 5,
  int guestAttempts = 7,
  bool hostComplete = false,
}) {
  final completed = phase == 'playing' ? round - 1 : round;
  final hostCurrent = phase == 'playing'
      ? (hostComplete ? 12 : 0)
      : round.isOdd
      ? 12
      : 0;
  final guestCurrent = phase == 'playing'
      ? 0
      : round.isOdd
      ? 0
      : 12;
  final results = [
    for (var index = 1; index <= completed; index++)
      {
        'round': index,
        'theme': _themes[index - 1],
        'scores': {'host': index.isOdd ? 12 : 0, 'guest': index.isOdd ? 0 : 12},
        'attempts': {'host': 20 + index, 'guest': 30 + index},
        'winnerId': index.isOdd ? 'host' : 'guest',
      },
  ];
  return {
    'code': 'ABC234',
    'pairs': 12,
    'matchType': 'ranked',
    'arenaId': 'wild_valley',
    'matchId': 'ranked-one',
    'roundId': 'round-$round',
    'roundIndex': round,
    'roundCount': 3,
    'roundDecks': _themes,
    'roundResults': results,
    'roundReady': ready,
    'phase': phase,
    'theme': _themes[round - 1],
    'cards': phase == 'playing' && !hostComplete
        ? List<int?>.filled(24, null)
        : List<int>.generate(24, (index) => index ~/ 2),
    'matched': phase == 'playing' && !hostComplete
        ? <int>[]
        : List<int>.generate(24, (i) => i),
    'selected': <int>[],
    'turn': phase == 'playing' ? (round.isOdd ? 'host' : 'guest') : null,
    'winnerId': phase == 'finished' ? 'host' : null,
    'finishReason': phase == 'finished' ? 'completed' : null,
    'lockedUntil': null,
    'rematch': <String>[],
    'rewards': {'host': ?receipt},
    'totalScores': {
      'host': results.fold<int>(
        0,
        (n, r) => n + ((r['scores'] as Map)['host'] as int),
      ),
      'guest': results.fold<int>(
        0,
        (n, r) => n + ((r['scores'] as Map)['guest'] as int),
      ),
    },
    'totalAttempts': {
      'host':
          results.fold<int>(
            0,
            (n, r) => n + ((r['attempts'] as Map)['host'] as int),
          ) +
          (phase == 'playing' ? hostAttempts : 0),
      'guest':
          results.fold<int>(
            0,
            (n, r) => n + ((r['attempts'] as Map)['guest'] as int),
          ) +
          (phase == 'playing' ? guestAttempts : 0),
    },
    'players': [
      {
        'id': 'host',
        'name': 'Tu',
        'score': hostCurrent,
        'attempts': hostAttempts,
        'roundComplete': hostComplete || phase != 'playing',
        'connected': true,
      },
      {
        'id': 'guest',
        'name': 'Amico',
        'score': guestCurrent,
        'attempts': guestAttempts,
        'roundComplete': phase != 'playing',
        'connected': true,
      },
    ],
  };
}

Future<void> _mount(
  WidgetTester tester,
  SharedPreferences prefs,
  _RankedOnline online, {
  _RankedEconomy? economy,
}) => tester.pumpWidget(
  MaterialApp(
    home: GameScreen(
      prefs: prefs,
      pairs: 12,
      theme: 'garden',
      mode: PlayMode.online,
      online: online,
      economy: economy,
      feedback: _QuietFeedback(prefs),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('round continuation votes once and awards no intermediate gems', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final online = _RankedOnline(prefs)
      ..publish(_rankedFrame(phase: 'roundFinished'));
    final economy = _RankedEconomy(prefs);
    await _mount(tester, prefs, online, economy: economy);
    await tester.pump();
    expect(find.text('Prossimo round'), findsOneWidget);
    expect(find.text('Hai vinto!'), findsNothing);
    expect(economy.refreshes, 0);
    await tester.tap(find.text('Prossimo round'));
    expect(online.nextVotes, 1);
    online.publish(_rankedFrame(phase: 'roundFinished', ready: ['host']));
    await tester.pump();
    expect(find.text('In attesa…'), findsOneWidget);
    expect(find.textContaining('Tentativi totali: 21 – 31'), findsOneWidget);
    expect(economy.refreshes, 0);
    await tester.pumpWidget(const SizedBox());
    online.dispose();
    economy.dispose();
  });

  testWidgets(
    'ranked UI shows attempt totals and waits on own completed board',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final online = _RankedOnline(prefs)
        ..publish(
          _rankedFrame(hostAttempts: 17, guestAttempts: 12, hostComplete: true),
        );
      await _mount(tester, prefs, online);
      await tester.pump();
      expect(find.textContaining('Attesa avversario'), findsOneWidget);
      expect(find.textContaining('17'), findsWidgets);
      expect(find.textContaining('12 coppie · 17 tentativi'), findsOneWidget);
      final firstCard = tester.widget<MemoryCard>(
        find.byKey(const ValueKey('card-0')),
      );
      expect(firstCard.onTap, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      online.dispose();
    },
  );

  testWidgets(
    'a fast next-round snapshot cannot replace the unfinished final flip',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final before = {
        ..._rankedFrame(),
        'cards': List<int?>.generate(24, (i) => i == 23 ? null : i ~/ 2),
        'matched': List<int>.generate(22, (i) => i),
        'totalScores': {'host': 11, 'guest': 0},
        'players': [
          {'id': 'host', 'name': 'Tu', 'score': 11, 'connected': true},
          {'id': 'guest', 'name': 'Amico', 'score': 0, 'connected': true},
        ],
      };
      final online = _RankedOnline(prefs)..publish(before);
      await _mount(tester, prefs, online);
      online.publish(_rankedFrame(phase: 'roundFinished'));
      await tester.pump();
      online.publish(_rankedFrame(round: 2));
      await tester.pump(const Duration(milliseconds: 319));
      expect(find.text('Prossimo round'), findsNothing);
      expect(find.textContaining('Round 2 di 3'), findsNothing);
      expect(
        tester.widget<MemoryCard>(find.byKey(const ValueKey('card-23'))).theme,
        'garden',
      );
      await tester.pump(const Duration(milliseconds: 1));
      for (var frame = 0; frame < 6; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final dynamic screen = tester.state(find.byType(GameScreen));
      expect(
        find.textContaining('Round 2 di 3'),
        findsOneWidget,
        reason:
            'target=${screen.targetFrame.roundIndex}, '
            'displayed=${screen.displayedEvents.roundIndex}, '
            'turning=${screen.turningCards}, queued=${screen.pendingFrames.length}',
      );
      expect(
        tester
            .widgetList<MemoryCard>(find.byType(MemoryCard))
            .every(
              (card) =>
                  card.theme == 'farm' && card.value == null && !card.matched,
            ),
        isTrue,
      );
      expect(
        find.descendant(
          of: find.byType(MemoryCard),
          matching: find.byType(DeckArtwork),
        ),
        findsNothing,
        reason:
            'The new covered board must not retain faces from the old deck.',
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      online.dispose();
    },
  );

  testWidgets(
    'a late final receipt refreshes once and presents crowns with gems',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final online = _RankedOnline(prefs)
        ..publish(_rankedFrame(round: 3, phase: 'finished'));
      final economy = _RankedEconomy(prefs);
      await _mount(tester, prefs, online, economy: economy);
      await tester.pump();
      expect(find.text('Hai vinto!'), findsOneWidget);
      expect(economy.refreshes, 0);
      final paid = _rankedFrame(
        round: 3,
        phase: 'finished',
        receipt: {'gems': 20, 'granted': true, 'crownsDelta': 20},
      );
      online.publish(paid);
      await tester.pump();
      await tester.pump();
      expect(economy.refreshes, 1);
      expect(find.text('+20 corone · +20 gemme'), findsOneWidget);
      online.publish(paid);
      await tester.pump();
      expect(economy.refreshes, 1);
      await tester.pumpWidget(const SizedBox());
      online.dispose();
      economy.dispose();
    },
  );

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    for (final phase in ['roundFinished', 'finished']) {
      testWidgets('$phase fits $size without overflowing', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final prefs = await SharedPreferences.getInstance();
        final online = _RankedOnline(prefs)
          ..publish(
            _rankedFrame(round: phase == 'finished' ? 3 : 2, phase: phase),
          );
        await _mount(tester, prefs, online);
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            phase == 'finished' ? 'Un’altra partita' : 'Prossimo round',
          ),
          findsOneWidget,
        );
        await tester.pumpWidget(const SizedBox());
        online.dispose();
      });
    }
  }
}
