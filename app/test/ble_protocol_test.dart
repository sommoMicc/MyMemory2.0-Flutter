import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/bluetooth/framing.dart';
import 'package:mymemory/bluetooth/ble_game.dart';
import 'package:mymemory/decks.dart';

void main() {
  test(
    'Every bundled deck can be hosted offline without revealing the board',
    () {
      for (final theme in deckNames.keys) {
        final game = BleGame('Host', 18, theme, 'ABCD', random: Random(5))
          ..join('Guest');
        final state = game.snapshot();
        expect(state['theme'], theme);
        expect(state['phase'], 'playing');
        expect(state['cards'], everyElement(isNull));
        expect((state['cards'] as List).length, 36);
      }
      expect(() => BleGame('Host', 8, 'unknown', 'ABCD'), throwsArgumentError);
    },
  );
  test('Minimum ATT MTU reassembles Unicode and full 36-card snapshots', () {
    final game = BleGame('Michéle 🌻', 18, 'garden', 'ABCD', random: Random(7))
      ..join('Amica');
    final sender = BleFraming(), receiver = BleFraming();
    final message = game.snapshot();
    final frames = sender.encode(message);
    expect(frames.length, greaterThan(1));
    expect(frames.every((f) => f.length <= 20), isTrue);
    Map<String, dynamic>? result;
    for (final frame in frames) {
      result = receiver.add(frame);
    }
    expect(result, message);
  });
  test(
    'Dropped packet rejects incomplete message and next snapshot recovers',
    () {
      final sender = BleFraming(), receiver = BleFraming();
      final first = sender.encode({'text': 'a' * 100});
      receiver.add(first[0]);
      expect(() => receiver.add(first[2]), throwsFormatException);
      final next = sender.encode({'text': 'recovered'});
      Map<String, dynamic>? result;
      for (final frame in next) {
        result = receiver.add(frame);
      }
      expect(result, {'text': 'recovered'});
      expect(
        () => receiver.add(Uint8List.fromList([1, 2])),
        throwsFormatException,
      );
      expect(() => sender.encode({'text': 'a' * 9000}), throwsFormatException);
    },
  );
  test(
    'Authority conceals deck, rejects wrong turn, bounds and duplicate flips',
    () {
      final game = BleGame('Host', 6, 'cosmos', 'ABCD', random: Random(1))
        ..join('Guest');
      expect(
        (game.snapshot()['cards'] as List).every((c) => c == null),
        isTrue,
      );
      expect(game.flip('guest', 0), isFalse);
      expect(game.flip('host', -1), isFalse);
      expect(game.flip('host', 12), isFalse);
      expect(game.flip('host', 0, now: 100), isTrue);
      expect(game.flip('host', 0, now: 100), isFalse);
      expect(
        (game.snapshot()['cards'] as List).where((c) => c != null).length,
        1,
      );
    },
  );
  test('Mismatch locks moves, then changes turn; both votes restart game', () {
    final game = BleGame('Host', 6, 'ocean', 'ABCD', random: Random(4))
      ..join('Guest');
    // Play by revealing only information the real clients receive.
    var now = 1000;
    var guard = 0;
    while (game.phase == 'playing' && guard++ < 500) {
      final state = game.snapshot();
      final turn = state['turn'] as String;
      final cards = state['cards'] as List;
      final matched = (state['matched'] as List).cast<int>();
      final first = List.generate(
        cards.length,
        (i) => i,
      ).firstWhere((i) => !matched.contains(i));
      game.flip(turn, first, now: now);
      final second = List.generate(cards.length, (i) => i)
          .where((i) => i != first && !matched.contains(i))
          .elementAt(guard % (cards.length - matched.length - 1));
      expect(game.flip(turn, second, now: now), isTrue);
      if (game.lockedUntil != null) {
        final lockedState = game.snapshot();
        final third = List.generate(
          cards.length,
          (i) => i,
        ).firstWhere((i) => i != first && i != second && !matched.contains(i));
        expect(game.flip(turn, third, now: now), isFalse);
        expect(game.snapshot(), lockedState);
        expect(game.flip(turn, third, now: now + 899), isFalse);
        expect(game.snapshot(), lockedState);
        expect(game.settle(now: now + 899), isFalse);
        expect(game.settle(now: now + 900), isTrue);
        expect(game.snapshot()['turn'], turn == 'host' ? 'guest' : 'host');
      }
      now += 1000;
    }
    expect(game.phase, 'finished');
    expect((game.snapshot()['matched'] as List).length, 12);
    game.rematch('host');
    expect(game.phase, 'finished');
    game.rematch('guest');
    expect(game.phase, 'playing');
    expect(game.snapshot()['turn'], 'guest');
    expect((game.snapshot()['matched'] as List), isEmpty);
  });
}
