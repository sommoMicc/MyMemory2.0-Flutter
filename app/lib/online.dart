import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class OnlineGame extends ChangeNotifier {
  OnlineGame(this.prefs, {String? serverUrl})
    : _serverUrl = serverUrl ?? endpoint,
      _roomCode = prefs.getString('room.code'),
      _token = prefs.getString('room.token');

  final SharedPreferences prefs;
  final String _serverUrl;
  static const endpoint = String.fromEnvironment(
    'MULTIPLAYER_URL',
    defaultValue: 'wss://sommomemory.sommomi.cc/ws',
  );
  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _retry, _heartbeat, _handshake;
  Future<void> _storage = Future.value();
  Map<String, dynamic>? _pendingAction;
  String? _roomCode, _token;
  DateTime? _lastSeen;
  Map<String, dynamic>? state;
  String? playerId, error;
  String status = 'Connessione…';
  bool connected = false, _closed = false, _connecting = false;
  int _attempt = 0, _generation = 0;
  String? get code => _roomCode;
  bool get hasSession => _roomCode != null && _token != null;

  bool _current(int generation) => !_closed && generation == _generation;

  Future<void> open(Map<String, dynamic>? action) async {
    if (_connecting || _closed) return;
    _connecting = true;
    final generation = ++_generation;
    if (action != null) {
      _pendingAction = Map<String, dynamic>.from(action);
      // A new game must never fall back to an older saved seat on reconnect.
      await _clearSession();
      if (!_current(generation)) return;
      state = null;
      playerId = null;
    }
    if (_pendingAction == null && !hasSession) {
      error = 'Torna alla home per creare o raggiungere una stanza.';
      status = 'Nessuna partita da riprendere';
      _connecting = false;
      _changed();
      return;
    }
    _retry?.cancel();
    _heartbeat?.cancel();
    _handshake?.cancel();
    connected = false;
    status = 'Connessione…';
    error = null;
    _changed();
    await _detachChannel();
    if (!_current(generation)) return;
    try {
      final channel = WebSocketChannel.connect(Uri.parse(_serverUrl));
      _channel = channel;
      await channel.ready.timeout(const Duration(seconds: 12));
      if (!_current(generation)) {
        unawaited(_close(channel));
        return;
      }
      connected = true;
      _lastSeen = DateTime.now();
      status = hasSession
          ? 'Riprendiamo la partita…'
          : 'Prepariamo la partita…';
      _subscription = channel.stream.listen(
        (raw) {
          if (!_current(generation)) return;
          _lastSeen = DateTime.now();
          try {
            final msg = jsonDecode(raw as String) as Map<String, dynamic>;
            switch (msg['type']) {
              case 'session':
                final id = msg['playerId'],
                    room = msg['code'],
                    token = msg['token'];
                if (id is! String || room is! String || token is! String) {
                  throw const FormatException('Invalid session');
                }
                playerId = id;
                _roomCode = room;
                _token = token;
                _pendingAction = null;
                _handshake?.cancel();
                unawaited(_saveSession());
                status = 'Online';
                break;
              case 'state':
                state = msg;
                error = null;
                status = 'Online';
                _attempt = 0;
                break;
              case 'error':
                error = msg['message'] as String? ?? 'Operazione non riuscita';
                if ([
                      'ROOM_NOT_FOUND',
                      'INVALID_TOKEN',
                      'ROOM_EXPIRED',
                      'INVALID_SESSION',
                      'NO_SESSION',
                    ].contains(msg['code']) ||
                    !hasSession) {
                  _endSession(error!);
                  return;
                }
                break;
              case 'left':
                _endSession(error ?? 'Hai lasciato la stanza.');
                return;
            }
            _changed();
          } catch (_) {
            _endSession(
              'Risposta del servizio non valida. Riprova dalla home.',
            );
          }
        },
        onError: (_) => _lost(generation),
        onDone: () {
          if (!_current(generation)) return;
          if (channel.closeCode == 4001) {
            _pendingAction = null;
            _endSession(
              'Partita aperta in un’altra scheda o su un altro dispositivo.',
              clearStoredSession: false,
            );
          } else {
            _lost(generation);
          }
        },
      );
      _handshake = Timer(const Duration(seconds: 12), () {
        if (!_current(generation)) return;
        _lost(generation);
        unawaited(_close(channel));
      });
      _heartbeat = Timer.periodic(const Duration(seconds: 10), (_) {
        if (!_current(generation) || !connected) return;
        if (DateTime.now().difference(_lastSeen!).inSeconds > 35) {
          _lost(generation);
          unawaited(_close(channel));
        } else {
          send({'type': 'ping'});
        }
      });
      send(_pendingAction ?? {'type': 'resume', 'code': code, 'token': _token});
      _changed();
    } catch (_) {
      _lost(generation);
    } finally {
      if (_current(generation)) _connecting = false;
    }
  }

  void _lost(int generation) {
    if (!_current(generation)) return;
    connected = false;
    _handshake?.cancel();
    _heartbeat?.cancel();
    if (hasSession) {
      status = 'Riconnessione…';
      error = null;
      if (_retry?.isActive != true) {
        final delay = [1, 2, 4, 8, 15][_attempt.clamp(0, 4)];
        _attempt++;
        _retry = Timer(Duration(seconds: delay), () => open(null));
      }
    } else {
      status = 'Connessione non riuscita';
      error =
          'Impossibile raggiungere il servizio. Controlla Internet e riprova.';
    }
    _changed();
  }

  void send(Map<String, dynamic> action) {
    if (!connected || _channel == null) {
      error = 'Attendi la connessione';
      _changed();
      return;
    }
    try {
      _channel!.sink.add(jsonEncode(action));
    } catch (_) {
      _lost(_generation);
    }
  }

  void flip(int index) => send({'type': 'flip', 'index': index});
  void rematch() => send({'type': 'rematch'});

  Future<void> _saveSession() {
    final room = _roomCode, token = _token;
    _storage = _storage
        .then((_) async {
          if (room == null || token == null) {
            await prefs.remove('room.code');
            await prefs.remove('room.token');
          } else {
            await prefs.setString('room.code', room);
            await prefs.setString('room.token', token);
          }
        })
        .catchError((Object _) {
          // The in-memory seat can still reconnect if local storage is unavailable.
        });
    return _storage;
  }

  Future<void> _clearSession() {
    _roomCode = null;
    _token = null;
    return _saveSession();
  }

  void _endSession(String reason, {bool clearStoredSession = true}) {
    ++_generation;
    _connecting = false;
    _retry?.cancel();
    _heartbeat?.cancel();
    _handshake?.cancel();
    connected = false;
    state = null;
    playerId = null;
    error = reason;
    status = 'Partita non disponibile';
    if (clearStoredSession) {
      unawaited(_clearSession());
    } else {
      // Another browser tab owns this same saved token now.
      _roomCode = null;
      _token = null;
    }
    unawaited(_detachChannel());
    _changed();
  }

  Future<void> _close(WebSocketChannel channel) async {
    try {
      await channel.sink.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
  }

  Future<void> _detachChannel() async {
    final subscription = _subscription, channel = _channel;
    _subscription = null;
    _channel = null;
    await subscription?.cancel();
    if (channel != null) await _close(channel);
  }

  Future<void> leave() async {
    if (connected) send({'type': 'leave'});
    ++_generation;
    _connecting = false;
    _pendingAction = null;
    _retry?.cancel();
    _heartbeat?.cancel();
    _handshake?.cancel();
    connected = false;
    state = null;
    playerId = null;
    error = null;
    status = 'Disconnesso';
    await _clearSession();
    await _detachChannel();
    _changed();
  }

  void _changed() {
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    ++_generation;
    _retry?.cancel();
    _heartbeat?.cancel();
    _handshake?.cancel();
    unawaited(_detachChannel());
    super.dispose();
  }
}
