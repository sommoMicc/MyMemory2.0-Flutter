import 'dart:math';

/// The advertising phone alone owns the hidden deck and validates both players.
class BleGame {
  final int pairs;
  final String theme;
  final String code;
  final List<Map<String, dynamic>> players;
  final Random _random;
  List<int>? _preparedBoard;
  String? _rewardTicketId, _guestClaimToken;
  final List<int> _rewardMoves = [];
  bool _proofOverflow = false;
  int _round = 0;
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

  BleGame(
    String hostName,
    this.pairs,
    this.theme,
    this.code, {
    Random? random,
    List<int>? board,
    String? ticketId,
    String? guestClaimToken,
  }) : _random = random ?? Random.secure(),
       players = [
         {
           'id': 'host',
           'name': cleanName(hostName),
           'score': 0,
           'connected': true,
         },
       ] {
    if (![6, 8, 12, 18].contains(pairs) ||
        ![
          'garden',
          'cosmos',
          'ocean',
          'food',
          'sports',
          'travel',
          'paola',
        ].contains(theme)) {
      throw ArgumentError('Configurazione della partita non valida.');
    }
    _setTicket(board, ticketId, guestClaimToken);
  }

  void _setTicket(List<int>? board, String? ticketId, String? guestClaimToken) {
    if (board != null) {
      if (board.length != pairs * 2 ||
          board.any((value) => value < 0 || value >= pairs) ||
          List.generate(
            pairs,
            (value) => board.where((v) => v == value).length,
          ).any((n) => n != 2)) {
        throw ArgumentError('Tabellone Bluetooth non valido.');
      }
      _preparedBoard = List<int>.from(board);
    } else {
      _preparedBoard = null;
    }
    _rewardTicketId = board == null ? null : ticketId;
    _guestClaimToken = board == null ? null : guestClaimToken;
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
    _deck =
        _preparedBoard?.map((value) => '$value').toList() ??
        ([
          for (var i = 0; i < pairs; i++) ...['$i', '$i'],
        ]..shuffle(_random));
    _preparedBoard = null;
    _round++;
    _rewardMoves.clear();
    _proofOverflow = false;
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
    if (!_proofOverflow) {
      if (_rewardMoves.length >= 1600) {
        // Keep the final proof below the bounded 8 KiB BLE message size.
        _proofOverflow = true;
        _rewardMoves.clear();
      } else {
        _rewardMoves.add(index);
      }
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

  bool get rematchReady =>
      _rematch.length == 2 &&
      phase == 'finished' &&
      finishReason == 'completed';

  void rematch(String player, {bool defer = false}) {
    if (phase != 'finished' ||
        finishReason != 'completed' ||
        !players.any((p) => p['id'] == player) ||
        players.any((p) => p['connected'] != true)) {
      return;
    }
    _rematch.add(player);
    revision++;
    if (rematchReady && !defer) startRematch();
  }

  void startRematch({
    List<int>? board,
    String? ticketId,
    String? guestClaimToken,
  }) {
    if (!rematchReady || players.any((player) => player['connected'] != true)) {
      return;
    }
    _setTicket(board, ticketId, guestClaimToken);
    _starter = 1 - _starter;
    _begin();
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
    'roundId': _rewardTicketId ?? '$code-$_round',
    if (_rewardTicketId != null && !_proofOverflow)
      'reward': {
        'ticketId': _rewardTicketId,
        if (_guestClaimToken != null) 'guestClaimToken': _guestClaimToken,
        if (phase == 'finished' && finishReason == 'completed')
          'moves': List<int>.from(_rewardMoves),
      },
    'rematch': _rematch.toList(),
    'lockedUntil': lockedUntil,
    'winnerId': winnerId,
    'finishReason': finishReason,
  };
}
