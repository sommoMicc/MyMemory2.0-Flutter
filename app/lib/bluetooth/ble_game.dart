import 'dart:math';

/// The advertising phone alone owns the hidden deck and validates both players.
class BleGame {
  final int pairs;
  final String theme;
  final String code;
  final List<Map<String, dynamic>> players;
  final Random _random;
  List<String> _deck = [];
  final Set<int> _matched = {};
  final List<int> _selected = [];
  final Set<String> _rematch = {};
  String phase = 'waiting';
  int _turn = 0;
  int _starter = 0;
  int revision = 0;
  int? lockedUntil;
  String? winnerId;
  String? finishReason;

  BleGame(String hostName, this.pairs, this.theme, this.code, {Random? random})
    : _random = random ?? Random.secure(),
      players = [
        {
          'id': 'host',
          'name': cleanName(hostName),
          'score': 0,
          'connected': true,
        },
      ] {
    if (![6, 8, 12, 18].contains(pairs) ||
        !['garden', 'cosmos', 'ocean'].contains(theme)) {
      throw ArgumentError('Configurazione della partita non valida.');
    }
  }

  static String cleanName(String value) {
    final result = String.fromCharCodes(value.trim().runes.take(24));
    return result.isEmpty ? 'Giocatore' : result;
  }

  void join(String name) {
    if (players.length != 1 || phase != 'waiting') {
      throw StateError('Partita già occupata.');
    }
    players.add({
      'id': 'guest',
      'name': cleanName(name),
      'score': 0,
      'connected': true,
    });
    _begin();
  }

  void _begin() {
    _deck = [
      for (var i = 0; i < pairs; i++) ...['$i', '$i'],
    ]..shuffle(_random);
    _matched.clear();
    _selected.clear();
    _rematch.clear();
    for (final player in players) {
      player['score'] = 0;
    }
    _turn = _starter;
    phase = 'playing';
    lockedUntil = null;
    winnerId = null;
    finishReason = null;
    revision++;
  }

  bool flip(String player, int index, {int? now}) {
    settle(now: now);
    if (phase != 'playing' ||
        players[_turn]['id'] != player ||
        players.any((p) => p['connected'] != true) ||
        lockedUntil != null ||
        index < 0 ||
        index >= _deck.length ||
        _matched.contains(index) ||
        _selected.contains(index)) {
      return false;
    }
    _selected.add(index);
    if (_selected.length == 2) {
      final first = _selected[0], second = _selected[1];
      if (_deck[first] == _deck[second]) {
        _matched.addAll(_selected);
        _selected.clear();
        players[_turn]['score'] = (players[_turn]['score'] as int) + 1;
        if (_matched.length == _deck.length) {
          phase = 'finished';
          finishReason = 'completed';
          final a = players[0]['score'] as int, b = players[1]['score'] as int;
          winnerId = a == b ? null : players[a > b ? 0 : 1]['id'] as String;
        }
      } else {
        lockedUntil = (now ?? DateTime.now().millisecondsSinceEpoch) + 900;
      }
    }
    revision++;
    return true;
  }

  bool settle({int? now}) {
    if (lockedUntil == null ||
        (now ?? DateTime.now().millisecondsSinceEpoch) < lockedUntil!) {
      return false;
    }
    lockedUntil = null;
    _selected.clear();
    _turn = 1 - _turn;
    revision++;
    return true;
  }

  void rematch(String player) {
    if (phase != 'finished' ||
        finishReason != 'completed' ||
        !players.any((p) => p['id'] == player) ||
        players.any((p) => p['connected'] != true)) {
      return;
    }
    _rematch.add(player);
    revision++;
    if (_rematch.length == 2) {
      _starter = 1 - _starter;
      _begin();
    }
  }

  void disconnect(String player) {
    for (final p in players) {
      if (p['id'] == player) p['connected'] = false;
    }
    if (phase == 'playing') {
      phase = 'finished';
      finishReason = 'forfeit';
      winnerId = player == 'host' ? 'guest' : 'host';
    }
    lockedUntil = null;
    _selected.clear();
    revision++;
  }

  Map<String, dynamic> snapshot() => {
    'type': 'state',
    'code': code,
    'pairs': pairs,
    'theme': theme,
    'phase': phase,
    'turn': phase == 'playing' ? players[_turn]['id'] : null,
    'cards': [
      for (var i = 0; i < _deck.length; i++)
        _matched.contains(i) || _selected.contains(i) ? _deck[i] : null,
    ],
    'matched': _matched.toList(),
    'selected': List<int>.from(_selected),
    'players': players.map((p) => Map<String, dynamic>.from(p)).toList(),
    'revision': revision,
    'rematch': _rematch.toList(),
    'lockedUntil': lockedUntil,
    'winnerId': winnerId,
    'finishReason': finishReason,
  };
}
