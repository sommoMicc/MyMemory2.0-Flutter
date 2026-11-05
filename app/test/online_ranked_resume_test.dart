import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymemory/online.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> until(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out');
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'ranked session survives pause and transfer, blocks new seats, clears on settlement and leave',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[], actions = <String>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((raw) {
          final action = jsonDecode(raw as String) as Map<String, dynamic>;
          actions.add(action['type'] as String);
          if (action['type'] == 'create' || action['type'] == 'resume') {
            socket.add(
              jsonEncode({
                'type': 'session',
                'code': 'ABC234',
                'token': 'saved-token',
                'playerId': 'alice',
              }),
            );
            socket.add(
              jsonEncode({
                'type': 'state',
                'matchType': 'ranked',
                'phase': 'playing',
                'rewards': {},
              }),
            );
          }
        });
      });
      final url = 'ws://127.0.0.1:${server.port}/ws';
      final first = OnlineGame(prefs, serverUrl: url);
      OnlineGame? next;
      try {
        await first.open({
          'type': 'create',
          'matchType': 'ranked',
          'name': 'A',
        });
        await until(
          () =>
              prefs.getBool('room.activeRanked') == true &&
              prefs.getString('room.token') == 'saved-token',
        );
        first.dispose();
        next = OnlineGame(prefs, serverUrl: url);
        await next.open({'type': 'join', 'code': 'NEW234', 'name': 'A'});
        expect(next.errorCode, 'RANKED_SESSION_ACTIVE');
        expect(actions, ['create']);
        expect(prefs.getString('room.token'), 'saved-token');
        await next.open(null);
        await until(
          () =>
              actions.contains('resume') && next!.state?['phase'] == 'playing',
        );
        sockets.last.add(
          jsonEncode({
            'type': 'state',
            'matchType': 'ranked',
            'phase': 'finished',
            'finishReason': 'completed',
            'rewards': {},
          }),
        );
        await until(() => next!.state?['phase'] == 'finished');
        expect(prefs.getBool('room.activeRanked'), isTrue);
        sockets.last.add(
          jsonEncode({
            'type': 'state',
            'matchType': 'ranked',
            'phase': 'finished',
            'finishReason': 'completed',
            'rewards': {
              'alice': {'crownsDelta': 20},
            },
          }),
        );
        await until(() => prefs.getBool('room.activeRanked') == false);
        await next.leave();
        expect(prefs.getString('room.token'), isNull);
        expect(prefs.getBool('room.activeRanked'), isNull);
      } finally {
        next?.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      }
    },
  );

  test(
    'transferred session remains intact; cancellation and terminal error clear flag',
    () async {
      SharedPreferences.setMockInitialValues({
        'room.code': 'ABC234',
        'room.token': 'saved-token',
        'room.activeRanked': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      server.listen((request) async {
        final socket = await WebSocketTransformer.upgrade(request);
        sockets.add(socket);
        socket.listen((raw) {
          socket.add(
            jsonEncode({
              'type': 'session',
              'code': 'ABC234',
              'token': 'saved-token',
              'playerId': 'alice',
            }),
          );
          socket.add(
            jsonEncode({
              'type': 'state',
              'matchType': 'ranked',
              'phase': 'playing',
              'rewards': {},
            }),
          );
        });
      });
      final url = 'ws://127.0.0.1:${server.port}/ws';
      final old = OnlineGame(prefs, serverUrl: url);
      OnlineGame? next;
      try {
        await old.open(null);
        await until(() => old.state?['phase'] == 'playing');
        await sockets.last.close(4001, 'transferred');
        await until(() => old.errorCode == 'SESSION_TRANSFERRED');
        await old.leave();
        expect(prefs.getString('room.token'), 'saved-token');
        expect(prefs.getBool('room.activeRanked'), isTrue);
        next = OnlineGame(prefs, serverUrl: url);
        await next.open(null);
        await until(() => next!.state?['phase'] == 'playing');
        sockets.last.add(
          jsonEncode({
            'type': 'state',
            'matchType': 'ranked',
            'phase': 'finished',
            'finishReason': 'cancelled',
            'rewards': {},
          }),
        );
        await until(() => prefs.getBool('room.activeRanked') == false);
        sockets.last.add(
          jsonEncode({
            'type': 'error',
            'code': 'INVALID_SESSION',
            'message': 'expired',
          }),
        );
        await until(() => prefs.getString('room.token') == null);
        expect(prefs.getBool('room.activeRanked'), isNull);
      } finally {
        old.dispose();
        next?.dispose();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
      }
    },
  );
}
