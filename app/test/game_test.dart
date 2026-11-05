import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/game.dart';

void main() {
  test('deck has exactly two of each symbol at every difficulty', () {
    for (final pairs in [6, 8, 12, 18]) {
      final g = LocalGame(pairs: pairs, twoPlayers: false, random: Random(4));
      expect(g.deck.length, pairs * 2);
      for (var i = 0; i < pairs; i++) {
        expect(g.deck.where((v) => v == i).length, 2);
      }
      g.dispose();
    }
  });
  test('matches score once and keep turn; cannot select same card twice', () {
    final g = LocalGame(pairs: 6, twoPlayers: true, random: Random(4));
    final first = g.deck[0];
    final second = g.deck.lastIndexOf(first);
    expect(g.flip(0), true);
    expect(g.flip(0), false);
    expect(g.flip(second), true);
    expect(g.scores, [1, 0]);
    expect(g.turn, 0);
    expect(g.moves, 1);
    expect(g.flip(0), false);
    g.dispose();
  });
  testWidgets('mismatch locks, conceals then hands turn to opponent', (
    tester,
  ) async {
    final g = LocalGame(pairs: 6, twoPlayers: true, random: Random(4));
    final second = g.deck.indexWhere((v) => v != g.deck[0]);
    g.flip(0);
    g.flip(second);
    expect(g.locked, true);
    expect(g.flip(4), false);
    await tester.pump(const Duration(milliseconds: 901));
    expect(g.selected, isEmpty);
    expect(g.turn, 1);
    g.dispose();
  });
  test('completing board finishes and blocks further moves', () {
    final g = LocalGame(pairs: 6, twoPlayers: false, random: Random(4));
    for (var i = 0; i < 6; i++) {
      final indices = [
        for (var n = 0; n < g.deck.length; n++)
          if (g.deck[n] == i) n,
      ];
      g.flip(indices[0]);
      g.flip(indices[1]);
    }
    expect(g.finished, true);
    expect(g.moves, 6);
    expect(g.scores, [6, 0]);
    expect(g.flip(0), false);
    g.dispose();
  });
}
