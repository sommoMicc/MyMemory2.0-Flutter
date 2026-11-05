import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mymemory/online.dart';

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for condition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

Map<String, dynamic> previewFrame({bool finished = false}) => {
  'code': 'ABC234',
  'phase': finished ? 'finished' : 'playing',
  'players': [
    {
      'id': 'alice',
      'name': 'Alice',
      'score': finished ? 6 : 3,
      'connected': true,
      'token': 'must-be-discarded',
    },
    {'id': 'bob', 'name': 'Bob', 'score': finished ? 0 : 2, 'connected': false},
  ],
  'winnerId': finished ? 'alice' : null,
  'finishReason': finished ? 'completed' : null,
  'cards': ['must-be-discarded'],
  'profileId': 'must-be-discarded',
};

class PeerServer {
  late final HttpServer server;
  final List<WebSocket> sockets = [];
  final List<Map<String, dynamic>> actions = [];
  Future<void> start(
    void Function(WebSocket, Map<String, dynamic>) handler,
  ) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final socket = await WebSocketTransformer.upgrade(request);
      sockets.add(socket);
      socket.listen((raw) {
        final action = jsonDecode(raw as String) as Map<String, dynamic>;
        actions.add(action);
        handler(socket, action);
      });
    });
  }

  String get url => 'ws://127.0.0.1:${server.port}/ws';
  Future<void> close() async {
    for (final socket in sockets) {
      await socket.close();
    }
    await server.close(force: true);
  }

  static void accepted(WebSocket socket) {
    socket.add(
      jsonEncode({
        'type': 'session',
        'code': 'ABC234',
        'token': 'secret-session-token',
        'playerId': 'alice',
      }),
    );
    socket.add(
      jsonEncode({
        'type': 'state',
        'code': 'ABC234',
        'phase': 'waiting',
        'revision': 1,
        'players': [
          {'id': 'alice', 'name': 'Alice', 'score': 0, 'connected': true},
        ],
        'cards': List<dynamic>.filled(12, null),
      }),
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'public preview model whitelists fields and keeps old frames immutable',
    () {
      final source = previewFrame();
      final model = RoomPreview.fromJson(source);
      (source['players'] as List).first['score'] = 18;
      expect(model.players.first['score'], 3);
      expect(
        model.players.first.keys,
        unorderedEquals(['id', 'name', 'score', 'connected']),
      );
      expect(() => model.players.add({}), throwsUnsupportedError);
      expect(() => model.players.first['score'] = 9, throwsUnsupportedError);
      expect(
        () => RoomPreview.fromJson({...previewFrame(), 'players': []}),
        throwsFormatException,
      );
      expect(
        () => RoomPreview.fromJson({
          ...previewFrame(finished: true),
          'winnerId': 'stranger',
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'full room has no session and manual preview refresh is read-only, final and immutable',
    () async {
      SharedPreferences.setMockInitialValues({
        'room.code': 'OLD234',
        'room.token': 'old-token',
      });
      final prefs = await SharedPreferences.getInstance();
      final server = PeerServer();
      await server.start((socket, action) {
        if (action['type'] == 'join') {
          socket.add(
            jsonEncode({
              'type': 'error',
              'code': 'ROOM_FULL',
              'message': 'La stanza è già al completo.',
              'roomPreview': previewFrame(),
            }),
          );
          // Already queued responses on a refused/old generation cannot restore a seat.
          PeerServer.accepted(socket);
        } else if (action['type'] == 'preview') {
          socket.add(
            jsonEncode({
              'type': 'roomPreview',
              'roomPreview': previewFrame(finished: true),
            }),
          );
        }
      });
      final online = OnlineGame(prefs, serverUrl: server.url);
      try {
        await online.open({
          'type': 'join',
          'code': 'ABC234',
          'name': 'Third',
          'profileToken': 'profile-secret',
        });
        await until(() => online.roomPreview != null);
        final first = online.roomPreview!;
        expect(first.players.map((p) => p['score']), [3, 2]);
        expect(online.errorCode, 'ROOM_FULL');
        expect(online.terminalError, isTrue);
        expect(online.canRetry, isFalse);
        expect(online.canRefreshPreview, isTrue);
        expect(online.connected, isFalse);
        expect(online.hasSession, isFalse);
        expect(online.state, isNull);
        expect(online.playerId, isNull);
        await until(() => prefs.getString('room.token') == null);
        await online.open(null);
        online.flip(0);
        online.rematch();
        expect(server.actions.length, 1);
        await online.refreshPreview();
        await until(() => online.roomPreview?.finished == true);
        expect(online.roomPreview!.players.map((p) => p['score']), [6, 0]);
        expect(online.roomPreview!.winnerId, 'alice');
        expect(first.players.map((p) => p['score']), [3, 2]);
        expect(server.actions.map((a) => a['type']), ['join', 'preview']);
        expect(server.actions.last.containsKey('profileToken'), isFalse);
        expect(server.actions.last.containsKey('token'), isFalse);
        expect(online.hasSession, isFalse);
        expect(online.state, isNull);
        await online.leave();
        expect(online.roomPreview, isNull);
        expect(online.terminalError, isFalse);
        expect(online.errorCode, isNull);
      } finally {
        online.dispose();
        await server.close();
      }
    },
  );

  test(
    'terminal denials never retry, discard malformed preview and allow a new explicit action',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final server = PeerServer();
      await server.start((socket, action) {
        if (action['type'] == 'create') {
          PeerServer.accepted(socket);
          return;
        }
        final update = action['code'] == 'UPD234';
        socket.add(
          jsonEncode({
            'type': 'error',
            'code': update ? 'UPDATE_REQUIRED' : 'ROOM_FULL',
            'message': update
                ? 'Aggiorna SommoMemory.'
                : 'La stanza è già al completo.',
            'roomPreview': {
              'code': 'ABC234',
              'cards': ['not-a-game'],
            },
          }),
        );
      });
      final online = OnlineGame(prefs, serverUrl: server.url);
      try {
        await online.open({'type': 'join', 'code': 'UPD234', 'name': 'Third'});
        await until(() => online.terminalError);
        expect(online.errorCode, 'UPDATE_REQUIRED');
        expect(online.canRetry, isFalse);
        await online.open(null);
        expect(server.actions.length, 1);
        await online.open({'type': 'join', 'code': 'ABC234', 'name': 'Third'});
        await until(() => online.errorCode == 'ROOM_FULL');
        expect(online.roomPreview, isNull);
        expect(online.canRefreshPreview, isFalse);
        expect(online.state, isNull);
        expect(online.hasSession, isFalse);
        await online.open({
          'type': 'create',
          'name': 'Alice',
          'theme': 'garden',
        });
        await until(() => online.state != null);
        expect(online.errorCode, isNull);
        expect(online.terminalError, isFalse);
      } finally {
        online.dispose();
        await server.close();
      }
    },
  );

  test(
    'rejected create displays server error and manual retry retains action',
    () async {
      SharedPreferences.setMockInitialValues({
        'room.code': 'OLD234',
        'room.token': 'old-token',
      });
      final prefs = await SharedPreferences.getInstance();
      final server = PeerServer();
      var creates = 0;
      await server.start((socket, action) {
        if (action['type'] == 'create') {
          creates++;
          if (creates == 1) {
            socket.add(
              jsonEncode({
                'type': 'error',
                'code': 'SERVER_FULL',
                'message': 'Il servizio è occupato.',
              }),
            );
          } else {
            PeerServer.accepted(socket);
          }
        }
      });
      final online = OnlineGame(prefs, serverUrl: server.url);
      try {
        await online.open({
          'type': 'create',
          'name': 'Alice',
          'pairs': 6,
          'theme': 'garden',
        });
        await until(() => online.error == 'Il servizio è occupato.');
        expect(online.connected, isFalse);
        expect(online.canRetry, isTrue);
        expect(online.terminalError, isFalse);
        expect(online.errorCode, 'SERVER_FULL');
        expect(online.hasSession, isFalse);
        expect(prefs.getString('room.token'), isNull);
        await online.open(null);
        await until(() => online.state != null);
        expect(creates, 2);
        expect(online.hasSession, isTrue);
        expect(online.code, 'ABC234');
        expect(online.playerId, 'alice');
        expect(online.error, isNull);
        expect(server.actions.first['supportedDecks'], contains('cosmos'));
      } finally {
        online.dispose();
        await server.close();
      }
    },
  );

  test(
    'invalid resume clears stale credentials and does not reconnect forever',
    () async {
      SharedPreferences.setMockInitialValues({
        'room.code': 'ABC234',
        'room.token': 'expired-token',
      });
      final prefs = await SharedPreferences.getInstance();
      final server = PeerServer();
      await server.start((socket, action) {
        socket.add(
          jsonEncode({
            'type': 'error',
            'code': 'INVALID_SESSION',
            'message': 'La sessione è scaduta.',
          }),
        );
      });
      final online = OnlineGame(prefs, serverUrl: server.url);
      try {
        await online.open(null);
        await until(() => online.error == 'La sessione è scaduta.');
        await until(() => prefs.getString('room.token') == null);
        expect(online.hasSession, isFalse);
        expect(online.state, isNull);
        expect(online.terminalError, isTrue);
        expect(online.canRetry, isFalse);
        await online.open(null);
        expect(online.error, 'La sessione è scaduta.');
        expect(server.actions.length, 1);
        expect(server.actions.single['type'], 'resume');
      } finally {
        online.dispose();
        await server.close();
      }
    },
  );

  test(
    'transport loss resumes the same seat and stale socket closure is ignored',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final server = PeerServer();
      await server.start((socket, action) {
        if (action['type'] == 'create' || action['type'] == 'resume') {
          PeerServer.accepted(socket);
        }
      });
      final online = OnlineGame(prefs, serverUrl: server.url);
      try {
        await online.open({
          'type': 'create',
          'name': 'Alice',
          'pairs': 6,
          'theme': 'garden',
        });
        await until(() => online.state != null);
        await server.sockets.single.close(1001, 'restart');
        await until(() => server.actions.any((a) => a['type'] == 'resume'));
        await until(() => online.connected && online.status == 'Online');
        expect(server.actions.last['token'], 'secret-session-token');
        expect(online.playerId, 'alice');
        expect(online.hasSession, isTrue);
        expect(server.actions.where((a) => a['type'] == 'create').length, 1);
        await online.leave();
        expect(online.hasSession, isFalse);
        expect(online.connected, isFalse);
        expect(online.state, isNull);
        expect(online.terminalError, isFalse);
        expect(prefs.getString('room.token'), isNull);
        await until(() => server.actions.any((a) => a['type'] == 'leave'));
      } finally {
        online.dispose();
        await server.close();
      }
    },
  );

  test(
    'session transfer stops retry without erasing the new tab’s saved token',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final server = PeerServer();
      await server.start((socket, action) => PeerServer.accepted(socket));
      final online = OnlineGame(prefs, serverUrl: server.url);
      try {
        await online.open({'type': 'create', 'name': 'Alice'});
        await until(() => online.state != null);
        await server.sockets.single.close(
          4001,
          'Session resumed on another connection',
        );
        await until(() => online.error?.contains('altra scheda') == true);
        expect(online.connected, isFalse);
        expect(online.hasSession, isFalse);
        expect(online.state, isNull);
        expect(online.terminalError, isTrue);
        expect(prefs.getString('room.token'), 'secret-session-token');
        await online.open(null);
        expect(server.actions.length, 1);
      } finally {
        online.dispose();
        await server.close();
      }
    },
  );

  test(
    'initial connection failure is actionable and dispose cancels pending connection',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final reserved = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
      final port = reserved.port;
      await reserved.close();
      final online = OnlineGame(prefs, serverUrl: 'ws://127.0.0.1:$port/ws');
      try {
        await online.open({'type': 'create', 'name': 'Alice'});
        expect(online.connected, isFalse);
        expect(online.error, contains('Controlla Internet'));
        expect(online.canRetry, isTrue);
        expect(online.terminalError, isFalse);
      } finally {
        online.dispose();
      }
      final disposed = OnlineGame(prefs, serverUrl: 'ws://127.0.0.1:$port/ws');
      final opening = disposed.open({'type': 'create', 'name': 'Alice'});
      disposed.dispose();
      await opening;
    },
  );
}
