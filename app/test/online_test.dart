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
        expect(online.hasSession, isFalse);
        expect(prefs.getString('room.token'), isNull);
        await online.open(null);
        await until(() => online.state != null);
        expect(creates, 2);
        expect(online.hasSession, isTrue);
        expect(online.code, 'ABC234');
        expect(online.playerId, 'alice');
        expect(online.error, isNull);
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
        await online.open(null);
        expect(online.error, contains('Torna alla home'));
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
