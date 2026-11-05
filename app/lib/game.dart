import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

enum PlayMode { solo, local, online, bluetooth }

class LocalGame extends ChangeNotifier {
  LocalGame({
    required this.pairs,
    required this.twoPlayers,
    Random? random,
    List<int>? board,
  }) {
    if (board != null &&
        (board.length != pairs * 2 ||
            board.any((v) => v < 0 || v >= pairs) ||
            List.generate(
              pairs,
              (v) => board.where((card) => card == v).length,
            ).any((count) => count != 2))) {
      throw ArgumentError('Mazzo non valido');
    }
    deck = board != null
        ? List.of(board)
        : ([
            for (var i = 0; i < pairs; i++) ...[i, i],
          ]..shuffle(random ?? Random.secure()));
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!finished) {
        seconds++;
        notifyListeners();
      }
    });
  }
  final int pairs;
  final bool twoPlayers;
  late final List<int> deck;
  final Set<int> matched = {};
  final List<int> selected = [];
  final List<int> scores = [0, 0];
  int turn = 0, moves = 0, seconds = 0;
  bool locked = false;
  Timer? _clock, _conceal;
  bool get finished => matched.length == deck.length;
  bool flip(int index) {
    if (finished ||
        locked ||
        index < 0 ||
        index >= deck.length ||
        matched.contains(index) ||
        selected.contains(index)) {
      return false;
    }
    selected.add(index);
    if (selected.length == 2) {
      moves++;
      if (deck[selected[0]] == deck[index]) {
        matched.addAll(selected);
        scores[turn]++;
        selected.clear();
      } else {
        locked = true;
        _conceal = Timer(const Duration(milliseconds: 900), () {
          selected.clear();
          locked = false;
          if (twoPlayers) turn = 1 - turn;
          notifyListeners();
        });
      }
    }
    notifyListeners();
    return true;
  }

  @override
  void dispose() {
    _clock?.cancel();
    _conceal?.cancel();
    super.dispose();
  }
}

String clockText(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
