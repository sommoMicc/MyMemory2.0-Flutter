import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mymemory/account.dart';
import 'package:mymemory/economy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'economy_test.dart' as helpers;

class TestCredentials implements AccountCredentialProvider {
  AccountCredential? result = const AccountCredential(
    idToken: 'provider-token',
  );
  AccountAttempt? attempt;
  int calls = 0;
  @override
  Future<AccountCredential?> signIn(
    AccountProvider provider,
    AccountAttempt attempt,
  ) async {
    calls++;
    this.attempt = attempt;
    return result;
  }
}

Map<String, dynamic> accountProfile({
  String id = 'guest',
  int gems = 180,
  int revision = 1,
  bool linked = false,
}) => {
  ...helpers.profile(id: id, gems: gems, revision: revision),
  'avatarId': 'owl',
  'accentId': 'ocean',
  'linkedProviders': linked ? ['google'] : <String>[],
  'recoveryEnabled': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;
  late helpers.MemorySecrets secrets;
  late TestCredentials credentials;
  late List<http.Request> requests;
  late Map<String, dynamic> current;
  late bool confirmFails, claimsFail, deleted;
  late int createCount;
  const provider = AccountProvider(
    id: 'google',
    serverClientId: 'server-client',
  );
  late Map<String, dynamic> target;

  Future<http.Response> handler(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/profiles')) {
      createCount++;
      return helpers.response({
        'token': helpers.token,
        'profile': current,
      }, 201);
    }
    if (path.endsWith('/auth/providers')) {
      return helpers.response({
        'providers': [
          {'id': 'google', 'serverClientId': 'server-client'},
        ],
      });
    }
    if (path.endsWith('/auth/attempts')) {
      return helpers.response({
        'attemptId': 'attempt-id',
        'nonce': 'server-nonce',
        'state': 'server-state',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 10))
            .millisecondsSinceEpoch,
      });
    }
    if (path.endsWith('/auth/exchange')) {
      return helpers.response({
        'confirmationId': 'confirmation-id',
        'profile': target,
        'action': target['id'] == current['id'] ? 'link' : 'switch',
        'expiresAt': DateTime.now()
            .add(const Duration(minutes: 5))
            .millisecondsSinceEpoch,
      });
    }
    if (path.endsWith('/auth/confirm')) {
      if (confirmFails) {
        return helpers.response({
          'error': {'code': 'SERVER_ERROR', 'message': 'Riprova.'},
        }, 503);
      }
      final switched = target['id'] != current['id'];
      current = {
        ...target,
        'linkedProviders': ['google'],
        'revision': 2,
      };
      return helpers.response({
        'profile': current,
        if (switched) 'token': '${helpers.token}-account',
      });
    }
    if (path.endsWith('/games/claims')) {
      if (claimsFail) {
        return helpers.response({
          'error': {'code': 'SERVER_ERROR', 'message': 'Riprova.'},
        }, 503);
      }
      return helpers.response({
        'profile': current,
        'reward': {'gems': 20, 'granted': true},
      });
    }
    if (request.method == 'PATCH') {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      current = {...current, ...body, 'revision': 2};
      return helpers.response({'profile': current});
    }
    if (path.endsWith('/profile') && deleted) {
      return helpers.response({
        'error': {'code': 'PROFILE_DELETED', 'message': 'Profilo eliminato.'},
      }, 401);
    }
    if (path.endsWith('/auth/reauth/recovery')) {
      return helpers.response({
        'verified': true,
        'expiresAt': DateTime.now().millisecondsSinceEpoch,
      });
    }
    return helpers.response({'profile': current});
  }

  EconomyController make({
    Future<http.Response> Function(http.Request)? customHandler,
  }) => EconomyController(
    prefs: prefs,
    secrets: secrets,
    accountCredentials: credentials,
    client: MockClient(customHandler ?? handler),
  );

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    secrets = helpers.MemorySecrets();
    credentials = TestCredentials();
    requests = [];
    current = accountProfile();
    target = accountProfile();
    confirmFails = false;
    claimsFail = false;
    deleted = false;
    createCount = 0;
  });
  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test(
    'Legacy profile fields have compatible appearance and recovery defaults',
    () {
      final legacy = ProfileData.fromJson(helpers.profile(activated: true));
      expect(legacy.avatarId, 'fox');
      expect(legacy.accentId, 'forest');
      expect(legacy.recoveryEnabled, isTrue);
      expect(legacy.linkedProviders, isEmpty);
    },
  );

  test(
    'Appearance is accepted from server and cached without credentials',
    () async {
      final controller = make();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.setAppearance(avatarId: 'rocket', accentId: 'cosmos');
      expect(controller.profile!.avatarId, 'rocket');
      expect(controller.profile!.accentId, 'cosmos');
      expect(
        jsonDecode(prefs.getString('profile.cache.v1')!)['avatarId'],
        'rocket',
      );
      expect(
        prefs.getKeys().map(prefs.get).join(),
        isNot(contains(helpers.token)),
      );
    },
  );

  test(
    'Provider discovery uses platform and public unauthenticated request',
    () async {
      final controller = make();
      addTearDown(controller.dispose);
      final values = await controller.discoverAccountProviders();
      expect(values.single.id, 'google');
      expect(requests.single.url.queryParameters['platform'], 'android');
      expect(requests.single.headers['Authorization'], isNull);
      expect(credentials.calls, 0);
    },
  );

  test(
    'Cancelled native sign in leaves guest and credentials untouched',
    () async {
      credentials.result = null;
      final controller = make();
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(await controller.beginAccountSignIn(provider), isNull);
      expect(controller.profile!.id, 'guest');
      expect(controller.profileToken, helpers.token);
      expect(
        requests.any((r) => r.url.path.endsWith('/auth/exchange')),
        isFalse,
      );
      expect(credentials.attempt!.nonce, 'server-nonce');
    },
  );

  test(
    'Apple and Google button preparation can run concurrently without a wallet lock',
    () async {
      final bothStarted = Completer<void>();
      var attemptCount = 0;
      final controller = make(
        customHandler: (request) async {
          if (request.url.path.endsWith('/auth/attempts')) {
            attemptCount++;
            if (attemptCount == 2) bothStarted.complete();
            await bothStarted.future;
          }
          return handler(request);
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final result = await Future.wait([
        controller.prepareAccountSignIn(provider),
        controller.prepareAccountSignIn(const AccountProvider(id: 'apple')),
      ]);
      expect(result.length, 2);
      expect(attemptCount, 2);
      expect(controller.busy, isFalse);
      expect(controller.profile!.id, 'guest');
    },
  );

  test(
    'Guest link is applied only after confirmation and preserves wallet',
    () async {
      final controller = make();
      addTearDown(controller.dispose);
      await controller.initialize();
      final preview = (await controller.beginAccountSignIn(provider))!;
      expect(controller.hasAccount, isFalse);
      expect(preview.action, 'link');
      await controller.confirmAccountSignIn(preview);
      expect(controller.hasAccount, isTrue);
      expect(controller.profile!.id, 'guest');
      expect(controller.gems, 180);
      expect(controller.profileToken, helpers.token);
      expect(createCount, 1);
    },
  );

  test(
    'Preview and failed confirmation never replace the original session',
    () async {
      target = accountProfile(id: 'saved', gems: 700);
      confirmFails = true;
      final controller = make();
      addTearDown(controller.dispose);
      await controller.initialize();
      final preview = (await controller.beginAccountSignIn(provider))!;
      expect(preview.switchesProfile, isTrue);
      expect(preview.profile.gems, 700);
      expect(controller.gems, 180);
      await expectLater(
        controller.confirmAccountSignIn(preview),
        throwsA(isA<EconomyException>()),
      );
      expect(controller.profile!.id, 'guest');
      expect(controller.profileToken, helpers.token);
      expect(
        prefs.getKeys().map(prefs.get).join(),
        isNot(contains(helpers.token)),
      );
    },
  );

  test(
    'Switch isolates pending proofs and securely preserves prior profile',
    () async {
      target = accountProfile(id: 'saved', gems: 700);
      claimsFail = true;
      final controller = make();
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.claimProof(ticketId: 'unfinished-reward', moves: [0, 1]);
      expect(controller.pendingRewards, 1);
      final preview = (await controller.beginAccountSignIn(provider))!;
      await controller.confirmAccountSignIn(preview);
      expect(controller.profile!.id, 'saved');
      expect(controller.gems, 700);
      expect(controller.pendingRewards, 0);
      final queued = jsonDecode(prefs.getString('profile.claims.v1')!) as List;
      expect(queued.single['profileId'], 'guest');
      expect(secrets.values['profile.archive.guest'], contains(helpers.token));
      expect((await controller.archivedAccountProfiles()).single.id, 'guest');
      await expectLater(
        controller.confirmAccountSignIn(preview),
        throwsA(isA<EconomyException>()),
      );
    },
  );

  test('Repeated confirmation retry reuses its request ID', () async {
    final controller = make();
    addTearDown(controller.dispose);
    await controller.initialize();
    final preview = (await controller.beginAccountSignIn(provider))!;
    confirmFails = true;
    await expectLater(
      controller.confirmAccountSignIn(preview),
      throwsA(isA<EconomyException>()),
    );
    confirmFails = false;
    await controller.confirmAccountSignIn(preview);
    final ids = requests
        .where((r) => r.url.path.endsWith('/auth/confirm'))
        .map((r) => (jsonDecode(r.body) as Map)['requestId']);
    expect(ids.toSet().length, 1);
  });

  test(
    'Remote deletion purges only this profile and blocks automatic guest recreation',
    () async {
      final controller = make();
      await controller.initialize();
      await prefs.setString('name', 'Private player name');
      await prefs.setString('name.localProfile', 'guest');
      await prefs.setBool('name.localPending', true);
      claimsFail = true;
      await controller.claimProof(ticketId: 'pending', moves: [0, 1]);
      deleted = true;
      await controller.sync();
      expect(controller.sessionEnded, isTrue);
      expect(controller.profile, isNull);
      expect(controller.profileToken, isNull);
      expect(prefs.getString('name'), isNull);
      expect(prefs.getString('name.localProfile'), isNull);
      expect(prefs.getBool('name.localPending'), isNull);
      expect(jsonDecode(prefs.getString('profile.claims.v1')!), isEmpty);
      await controller.sync();
      expect(createCount, 1);
      controller.dispose();
      final reopened = make();
      addTearDown(reopened.dispose);
      await reopened.initialize();
      expect(reopened.sessionEnded, isTrue);
      expect(createCount, 1);
      deleted = false;
      await reopened.startGuestProfile();
      expect(createCount, 2);
    },
  );

  test(
    'Deleted archived profile is purged without touching the active different account',
    () async {
      target = accountProfile(id: 'saved', gems: 700);
      claimsFail = true;
      var archiveDeleted = false;
      final controller = make(
        customHandler: (request) async {
          if (archiveDeleted &&
              request.url.path.endsWith('/profile') &&
              request.headers['Authorization'] == 'Bearer ${helpers.token}') {
            return helpers.response({
              'error': {
                'code': 'PROFILE_DELETED',
                'message': 'Profilo eliminato.',
              },
            }, 401);
          }
          return handler(request);
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.claimProof(ticketId: 'old-pending', moves: [0, 1]);
      final preview = (await controller.beginAccountSignIn(provider))!;
      await controller.confirmAccountSignIn(preview);
      archiveDeleted = true;
      await expectLater(
        controller.restoreArchivedAccount('guest'),
        throwsA(isA<EconomyException>()),
      );
      expect(controller.profile!.id, 'saved');
      expect(controller.gems, 700);
      expect(controller.sessionEnded, isFalse);
      expect(await controller.archivedAccountProfiles(), isEmpty);
      expect(jsonDecode(prefs.getString('profile.claims.v1')!), isEmpty);
      expect(secrets.values['profile.archive.guest'], isNull);
    },
  );

  test(
    'Expired session recovers the same account through a provisional login context',
    () async {
      final saved = accountProfile(id: 'guest', gems: 740, linked: true);
      final controller = make(
        customHandler: (request) async {
          if (request.url.path.endsWith('/profiles') && createCount > 0) {
            createCount++;
            return helpers.response({
              'token': '${helpers.token}-provisional',
              'profile': accountProfile(id: 'provisional'),
            }, 201);
          }
          if (request.url.path.endsWith('/auth/attempts') &&
              request.headers['Authorization'] == 'Bearer ${helpers.token}') {
            return helpers.response({
              'error': {
                'code': 'INVALID_TOKEN',
                'message': 'Sessione scaduta.',
              },
            }, 401);
          }
          if (request.url.path.endsWith('/auth/exchange')) {
            expect(
              request.headers['Authorization'],
              'Bearer ${helpers.token}-provisional',
            );
            return helpers.response({
              'confirmationId': 'resume',
              'profile': saved,
              'action': 'switch',
              'expiresAt': DateTime.now()
                  .add(const Duration(minutes: 5))
                  .millisecondsSinceEpoch,
            });
          }
          if (request.url.path.endsWith('/auth/confirm')) {
            expect(
              request.headers['Authorization'],
              'Bearer ${helpers.token}-provisional',
            );
            return helpers.response({
              'token': '${helpers.token}-renewed',
              'profile': saved,
            });
          }
          return handler(request);
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final preview = (await controller.beginAccountSignIn(provider))!;
      expect(controller.profileToken, helpers.token);
      expect(controller.gems, 180);
      await controller.confirmAccountSignIn(preview);
      expect(controller.profile!.id, 'guest');
      expect(controller.profileToken, '${helpers.token}-renewed');
      expect(controller.gems, 740);
      expect(controller.hasAccount, isTrue);
    },
  );

  test(
    'Cancelling expired-session login keeps cached funded profile and original credential',
    () async {
      credentials.result = null;
      final controller = make(
        customHandler: (request) async {
          if (request.url.path.endsWith('/profiles') && createCount > 0) {
            return helpers.response({
              'token': '${helpers.token}-provisional',
              'profile': accountProfile(id: 'provisional'),
            }, 201);
          }
          if (request.url.path.endsWith('/auth/attempts') &&
              request.headers['Authorization'] == 'Bearer ${helpers.token}') {
            return helpers.response({
              'error': {
                'code': 'INVALID_TOKEN',
                'message': 'Sessione scaduta.',
              },
            }, 401);
          }
          return handler(request);
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      expect(await controller.beginAccountSignIn(provider), isNull);
      expect(controller.profile!.id, 'guest');
      expect(controller.gems, 180);
      expect(controller.profileToken, helpers.token);
      expect(
        secrets.values['sommomemory.profile.session.v1'],
        isNot(contains('provisional')),
      );
    },
  );

  test(
    'Explicit logout succeeds locally when its session has already been revoked',
    () async {
      final controller = make(
        customHandler: (request) async {
          if (request.url.path.endsWith('/profile/logout')) {
            return helpers.response({
              'error': {
                'code': 'INVALID_TOKEN',
                'message': 'Sessione scaduta.',
              },
            }, 401);
          }
          return handler(request);
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      await controller.logout();
      expect(controller.profileToken, isNull);
      expect(controller.profile, isNull);
    },
  );

  test(
    'Delayed deletion error from previous generation cannot purge new profile',
    () async {
      target = accountProfile(id: 'saved', gems: 700);
      final pending = Completer<http.Response>();
      final started = Completer<void>();
      final controller = make(
        customHandler: (request) async {
          if (request.url.path.endsWith('/games/claims')) {
            started.complete();
            return pending.future;
          }
          if (request.url.path.endsWith('/profiles/restore')) {
            current = target;
            return helpers.response({
              'token': '${helpers.token}-saved',
              'profile': target,
            });
          }
          return handler(request);
        },
      );
      addTearDown(controller.dispose);
      await controller.initialize();
      final delayed = controller.claimProof(
        ticketId: 'old-game',
        moves: [0, 1],
      );
      await started.future;
      await controller.restoreRecovery('another-profile-code');
      pending.complete(
        helpers.response({
          'error': {'code': 'PROFILE_DELETED', 'message': 'Profilo eliminato.'},
        }, 401),
      );
      await delayed;
      expect(controller.profile!.id, 'saved');
      expect(controller.gems, 700);
    },
  );
}
