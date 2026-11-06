import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mymemory/economy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemorySecrets implements EconomySecrets {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _Connection {
  bool online = false;
}

class _SwitchableClient extends http.BaseClient {
  _SwitchableClient(this.connection);

  final _Connection connection;
  final _delegate = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (!connection.online) throw http.ClientException('Offline');
    return _delegate.send(request);
  }

  @override
  void close() => _delegate.close();
}

List<int> _solution(List<int> board) => [
  for (final value in board.toSet())
    for (var index = 0; index < board.length; index++)
      if (board[index] == value) index,
];

Future<void> _waitForSync(EconomyController controller) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  while (controller.syncing) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Profile synchronization did not finish.');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // This test intentionally exercises the actual local HTTP service.
  HttpOverrides.global = null;

  test(
    'offline solo journal survives restart and reconciles with real server',
    () async {
      final serverDirectory = Directory.current.path.endsWith('/app')
          ? Directory('${Directory.current.parent.path}/server')
          : Directory('${Directory.current.path}/server');
      final dataDirectory = await Directory.systemTemp.createTemp(
        'sommomemory-solo-sync-',
      );
      final process = await Process.start('node', [
        '--input-type=module',
        '-e',
        '''
import { startServer } from './src/server.mjs';
import { once } from 'node:events';
const server = startServer({ port: 0, dataDir: process.argv[1] });
await once(server.http, 'listening');
console.log(JSON.stringify({ port: server.http.address().port }));
process.once('SIGTERM', async () => { await server.close(); process.exit(0); });
''',
        dataDirectory.path,
      ], workingDirectory: serverDirectory.path);
      final diagnostics = StringBuffer();
      final errors = process.stderr
          .transform(utf8.decoder)
          .listen(diagnostics.write);
      addTearDown(() async {
        process.kill(ProcessSignal.sigterm);
        try {
          await process.exitCode.timeout(const Duration(seconds: 5));
        } on TimeoutException {
          process.kill(ProcessSignal.sigkill);
          await process.exitCode;
        }
        await errors.cancel();
        await dataDirectory.delete(recursive: true);
      });
      final startup = await process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .first
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              fail('Local service did not start: $diagnostics');
            },
          );
      final port = (jsonDecode(startup) as Map<String, dynamic>)['port'] as int;
      final baseUrl = 'http://127.0.0.1:$port/api/v1';
      final secrets = _MemorySecrets();
      final connection = _Connection();
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      var controller = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: _SwitchableClient(connection),
        baseUrl: baseUrl,
      );
      final controllers = <EconomyController>[controller];
      addTearDown(() {
        for (final value in controllers) {
          value.dispose();
        }
      });
      await controller.initialize();
      final localId = controller.profile!.id;
      expect(localId, startsWith('offline_'));
      expect(controller.gems, 100);
      GameTicket? completedTicket;
      for (var game = 0; game < 6; game++) {
        final ticket = (await controller.takeTicket(
          mode: 'solo',
          pairs: 6,
          theme: 'garden',
        ))!;
        completedTicket = ticket;
        final reward = await controller.claimGame(
          ticket: ticket,
          moves: _solution(ticket.board),
        );
        expect(reward!.granted, isTrue);
        expect(reward.gems, 20);
      }
      expect(controller.gems, 220);
      expect((await controller.unlockDeck('insects')).unlocked, isTrue);
      expect(controller.gems, 20);
      expect(controller.ownsDeck('insects'), isTrue);
      expect(controller.pendingChanges, 7);
      expect(prefs.getInt('best.6'), 6);
      await _waitForSync(controller);
      final persistedPreferences = {
        for (final key in prefs.getKeys()) key: prefs.get(key)!,
      };
      controller.dispose();
      controllers.remove(controller);

      // Start again using only committed local preferences and secure credentials.
      SharedPreferences.setMockInitialValues(persistedPreferences);
      prefs = await SharedPreferences.getInstance();
      controller = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: _SwitchableClient(connection),
        baseUrl: baseUrl,
      );
      controllers.add(controller);
      await controller.initialize();
      expect(controller.profile!.id, localId);
      expect(controller.gems, 20);
      expect(controller.ownsDeck('insects'), isTrue);
      expect(controller.pendingChanges, 7);

      connection.online = true;
      await controller.sync();
      expect(controller.lastError, isNull);
      expect(controller.pendingChanges, 0);
      expect(controller.profile!.id, isNot(localId));
      expect(controller.gems, 20);
      expect(controller.ownsDeck('insects'), isTrue);
      expect(controller.profile!.soloBestAttempts, {'6': 6});
      expect(controller.profile!.crowns, 0);
      expect(controller.profile!.peakCrowns, 0);
      final profileId = controller.profile!.id;
      final token = controller.profileToken!;

      final duplicate = await controller.claimGame(
        ticket: completedTicket!,
        moves: _solution(completedTicket.board),
      );
      expect(duplicate!.granted, isFalse);
      await controller.sync();
      expect(controller.gems, 20);
      expect(controller.pendingChanges, 0);

      // Another installation restoring the same credential sees the server result.
      final otherSecrets = _MemorySecrets();
      otherSecrets.values['sommomemory.profile.session.v1'] = jsonEncode({
        'token': token,
        'profileId': profileId,
      });
      SharedPreferences.setMockInitialValues({});
      final otherPrefs = await SharedPreferences.getInstance();
      final otherController = EconomyController(
        prefs: otherPrefs,
        secrets: otherSecrets,
        client: _SwitchableClient(connection),
        baseUrl: baseUrl,
      );
      controllers.add(otherController);
      await otherController.initialize();
      expect(otherController.lastError, isNull);
      expect(otherController.profile!.id, profileId);
      expect(otherController.gems, 20);
      expect(otherController.ownsDeck('insects'), isTrue);
      expect(otherController.profile!.soloBestAttempts, {'6': 6});
      expect(otherPrefs.getInt('best.6'), 6);
      expect(otherController.profile!.crowns, 0);

      final httpClient = http.Client();
      try {
        final response = await httpClient.get(
          Uri.parse('$baseUrl/profile/ledger'),
          headers: {'Authorization': 'Bearer $token'},
        );
        expect(response.statusCode, 200);
        final entries =
            ((jsonDecode(response.body) as Map<String, dynamic>)['entries']
                    as List)
                .cast<Map>();
        expect(
          entries.where((entry) => entry['source'] == 'welcome'),
          hasLength(1),
        );
        expect(
          entries.where(
            (entry) => (entry['source'] as String).startsWith('solo:'),
          ),
          hasLength(6),
        );
        expect(
          entries.where((entry) => entry['source'] == 'unlock:insects'),
          hasLength(1),
        );
      } finally {
        httpClient.close();
      }
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
