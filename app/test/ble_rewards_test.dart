import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/bluetooth/ble_game.dart';
import 'package:mymemory/bluetooth/framing.dart';

void main() {
  test(
    'Bluetooth never exposes ticket board or transcript before completion',
    () {
      final board = [
        for (var i = 0; i < 6; i++) ...[i, i],
      ];
      final game = BleGame(
        'Host',
        6,
        'food',
        'TEST',
        board: board,
        ticketId: 'ticket-1',
        guestClaimToken: 'game-only-capability',
      );
      game.join('Guest');
      final initial = game.snapshot();
      expect(initial['cards'], List.filled(12, null));
      expect(initial.containsKey('board'), isFalse);
      expect(initial.containsKey('seed'), isFalse);
      expect((initial['reward'] as Map).containsKey('moves'), isFalse);
      expect(initial.containsKey('profileToken'), isFalse);
      for (var index = 0; index < 12; index++) {
        expect(game.flip('host', index), isTrue);
      }
      final complete = game.snapshot();
      expect(complete['phase'], 'finished');
      expect((complete['reward'] as Map)['moves'], List.generate(12, (i) => i));
      expect((complete['reward'] as Map)['ticketId'], 'ticket-1');
      final encoded = const Utf8Encoder().convert(jsonEncode(complete));
      expect(encoded.length, lessThan(8192));
      expect(BleFraming().encode(complete, mtu: 20), isNotEmpty);
    },
  );

  test(
    'A rematch uses a fresh ticket; a practice rematch cannot replay the reward',
    () {
      final board = [
        for (var i = 0; i < 6; i++) ...[i, i],
      ];
      final game = BleGame(
        'Host',
        6,
        'sports',
        'TEST',
        board: board,
        ticketId: 'first',
      );
      game.join('Guest');
      for (var i = 0; i < 12; i++) {
        game.flip('host', i);
      }
      game.rematch('host', defer: true);
      game.rematch('guest', defer: true);
      expect(game.phase, 'finished');
      game.startRematch(board: board, ticketId: 'second');
      expect(game.snapshot()['roundId'], 'second');
      expect(game.phase, 'playing');
      expect((game.snapshot()['reward'] as Map).containsKey('moves'), isFalse);
      for (var i = 0; i < 12; i++) {
        game.flip('guest', i);
      }
      game.rematch('host');
      game.rematch('guest');
      expect(game.snapshot().containsKey('reward'), isFalse);
      expect(game.snapshot()['roundId'], isNot('first'));
      expect(game.snapshot()['roundId'], isNot('second'));
    },
  );

  test('Invalid supplied Bluetooth boards are rejected before play', () {
    expect(
      () => BleGame(
        'Host',
        6,
        'travel',
        'TEST',
        board: List.filled(12, 0),
        ticketId: 'x',
      ),
      throwsArgumentError,
    );
  });
}
