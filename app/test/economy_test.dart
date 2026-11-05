import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymemory/economy.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemorySecrets implements EconomySecrets {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

Map<String, dynamic> profile({
  String id = 'profile-one',
  int gems = 100,
  int revision = 1,
  bool activated = false,
}) => {
  'id': id,
  'displayName': '',
  'activated': activated,
  'gems': gems,
  'ownedDecks': ['garden', 'cosmos', 'ocean'],
  'revision': revision,
};
http.Response response(Map<String, dynamic> value, [int status = 200]) =>
    http.Response(
      jsonEncode(value),
      status,
      headers: {'content-type': 'application/json'},
    );
const token = 'this-is-a-long-private-profile-token-for-the-test';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test(
    'Credentials use secure storage; no optimistic unlock on server denial',
    () async {
      final secrets = MemorySecrets();
      final controller = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: MockClient((request) async {
          expect(request.followRedirects, isFalse);
          if (request.url.path.endsWith('/profiles')) {
            return response({'token': token, 'profile': profile()}, 201);
          }
          if (request.url.path.endsWith('/wallet/unlock')) {
            expect(request.headers['Authorization'], 'Bearer $token');
            return response({
              'error': {
                'code': 'INSUFFICIENT_GEMS',
                'message': 'Gemme insufficienti.',
              },
            }, 409);
          }
          return response({'profile': profile()});
        }),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(controller.gems, 100);
      await expectLater(
        controller.unlockDeck('food'),
        throwsA(isA<EconomyException>()),
      );
      expect(controller.gems, 100);
      expect(controller.ownsDeck('food'), isFalse);
      expect(secrets.values.values.join(), contains(token));
      expect(
        prefs.getKeys().map((key) => prefs.get(key)).join(),
        isNot(contains(token)),
      );
    },
  );

  test(
    'Preview does not replace a profile, failed restore preserves its session',
    () async {
      final secrets = MemorySecrets();
      var restoring = false;
      final controller = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/profiles')) {
            return response({'token': token, 'profile': profile()}, 201);
          }
          if (request.url.path.endsWith('/preview')) {
            return response({
              'profile': profile(id: 'another-profile', gems: 500),
            });
          }
          if (request.url.path.endsWith('/restore')) {
            restoring = true;
            return response({
              'error': {
                'code': 'INVALID_RECOVERY',
                'message': 'Codice non valido.',
              },
            }, 401);
          }
          return response({'profile': profile()});
        }),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final preview = await controller.previewRecovery('secret-code');
      expect(preview.id, 'another-profile');
      expect(controller.profile!.id, 'profile-one');
      await expectLater(
        controller.restoreRecovery('secret-code'),
        throwsA(isA<EconomyException>()),
      );
      expect(restoring, isTrue);
      expect(controller.profile!.id, 'profile-one');
      expect(controller.profileToken, token);
    },
  );

  test(
    'Restoring switches revision scope and keeps the code out of preferences',
    () async {
      final secrets = MemorySecrets();
      final controller = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/profiles')) {
            return response({
              'token': token,
              'profile': profile(revision: 25),
            }, 201);
          }
          if (request.url.path.endsWith('/restore')) {
            return response({
              'token': '$token-second',
              'profile': profile(
                id: 'second-profile',
                gems: 340,
                activated: true,
              ),
            });
          }
          return response({'profile': profile(revision: 25)});
        }),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.restoreRecovery('SMM-KEEP-THIS-CODE-PRIVATE');
      expect(controller.profile!.id, 'second-profile');
      expect(controller.profile!.revision, 1);
      expect(controller.gems, 340);
      expect(await controller.activateRecovery(), 'SMM-KEEP-THIS-CODE-PRIVATE');
      expect(
        prefs.getKeys().map((key) => prefs.get(key)).join(),
        isNot(contains('SMM-KEEP')),
      );
    },
  );

  test(
    'Offline proofs survive reopening; syncing accepts authoritative balance only',
    () async {
      final secrets = MemorySecrets();
      var connected = true;
      var rewarded = false;
      final client = MockClient((request) async {
        if (!connected) throw http.ClientException('offline');
        if (request.url.path.endsWith('/profiles')) {
          return response({'token': token, 'profile': profile()}, 201);
        }
        if (request.url.path.endsWith('/claims')) {
          final body = jsonDecode(request.body) as Map;
          expect(body['moves'], [0, 1]);
          expect(body.containsKey('gems'), isFalse);
          rewarded = true;
          return response({
            'profile': profile(gems: 120, revision: 2),
            'reward': {'gems': 20, 'granted': true},
          });
        }
        return response({
          'profile': profile(
            gems: rewarded ? 120 : 100,
            revision: rewarded ? 2 : 1,
          ),
        });
      });
      final first = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: client,
      );
      await first.initialize();
      connected = false;
      final result = await first.claimProof(
        ticketId: 'ticket-one',
        moves: [0, 1],
      );
      expect(result, isNull);
      expect(first.gems, 100);
      expect(first.pendingRewards, 1);
      first.dispose();
      connected = true;
      final reopened = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: client,
      );
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.gems, 120);
      expect(reopened.pendingRewards, 0);
      expect(rewarded, isTrue);
    },
  );

  test(
    'A response from the old profile cannot overwrite a restored wallet',
    () async {
      final secrets = MemorySecrets();
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final controller = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/profiles')) {
            return response({'token': token, 'profile': profile()}, 201);
          }
          if (request.url.path.endsWith('/claims')) {
            started.complete();
            return pending.future;
          }
          if (request.url.path.endsWith('/restore')) {
            return response({
              'token': '$token-second',
              'profile': profile(id: 'restored', gems: 600),
            });
          }
          return response({'profile': profile()});
        }),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final claim = controller.claimProof(ticketId: 'one', moves: [0, 1]);
      await started.future;
      await controller.restoreRecovery('code-for-restored');
      pending.complete(
        response({
          'profile': profile(gems: 120, revision: 9),
          'reward': {'gems': 20, 'granted': true},
        }),
      );
      await claim;
      expect(controller.profile!.id, 'restored');
      expect(controller.gems, 600);
    },
  );

  test(
    'A recovery code is invalidated when another device rotates it',
    () async {
      final secrets = MemorySecrets();
      var recoveryVersion = 0;
      var revision = 1;
      var activated = false;
      Map<String, dynamic> current() => {
        ...profile(revision: revision, activated: activated),
        'recoveryVersion': recoveryVersion,
      };
      final controller = EconomyController(
        prefs: prefs,
        secrets: secrets,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/profiles')) {
            return response({'token': token, 'profile': current()}, 201);
          }
          if (request.url.path.endsWith('/recovery')) {
            activated = true;
            recoveryVersion = 1;
            revision++;
            return response({
              'profile': current(),
              'recoveryCode': 'SMM-FIRST-CODE',
            });
          }
          return response({'profile': current()});
        }),
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(await controller.activateRecovery(), 'SMM-FIRST-CODE');
      revision++;
      await controller.refresh();
      expect(
        await controller.activateRecovery(),
        'SMM-FIRST-CODE',
        reason: 'Ordinary wallet changes do not rotate recovery',
      );
      recoveryVersion = 2;
      revision++;
      await controller.refresh();
      await expectLater(
        controller.activateRecovery(),
        throwsA(isA<EconomyException>()),
      );
      expect(secrets.values.values.join(), isNot(contains('SMM-FIRST-CODE')));
      expect(controller.profileToken, token);
      expect(controller.gems, 100);
    },
  );

  test('Server-issued board and expiry are preserved exactly', () {
    final ticket = GameTicket.fromJson({
      'id': 'ticket',
      'mode': 'solo',
      'theme': 'food',
      'pairs': 6,
      'board': ['1', '0', '2', '3', '4', '5', '1', '0', '2', '3', '4', '5'],
      'expiresAt': 1800000000000,
    });
    expect(ticket.board, [1, 0, 2, 3, 4, 5, 1, 0, 2, 3, 4, 5]);
    expect(ticket.expiresAt.millisecondsSinceEpoch, 1800000000000);
    expect(() => ticket.board[0] = 3, throwsUnsupportedError);
  });
}
